import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

/// Exception thrown when the Telegram Bot API returns an error.
class BotApiException implements Exception {
  final String message;
  BotApiException(this.message);
  @override
  String toString() => 'BotApiException: $message';
}

/// Telegram Bot API implementation of [BotPlatformService].
///
/// Uses Bot API 9.5+ features including `sendMessageDraft` for streaming.
class TelegramBotService implements BotPlatformService {
  final String token;
  final String _baseUrl;
  final http.Client _client;
  final http.Client Function() _clientFactory;

  int _updateOffset = 0;
  bool _polling = false;
  http.Client? _pollClient;

  TelegramBotService({
    required this.token,
    http.Client? client,
    http.Client Function()? clientFactory,
  })  : _baseUrl = 'https://api.telegram.org/bot$token',
        _client = client ?? http.Client(),
        _clientFactory = clientFactory ?? (() => http.Client());

  // ------------------------------------------------------------------
  // BotPlatformService
  // ------------------------------------------------------------------

  @override
  Future<BotConnectionStatus> testConnection() async {
    try {
      final resp = await _get('getMe');
      if (resp.statusCode != 200) {
        return BotConnectionStatus.failure('HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['ok'] != true) {
        return BotConnectionStatus.failure(
          json['description']?.toString() ?? 'Unknown error',
        );
      }
      final username =
          json['result']['username']?.toString() ?? 'unknown';
      return BotConnectionStatus.success(username);
    } catch (e) {
      return BotConnectionStatus.failure(e.toString());
    }
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    // Telegram limits message length to 4096 chars; split if needed.
    // Send as plain text to avoid Markdown injection from user content.
    final chunks = _splitText(text, 4096);
    for (final chunk in chunks) {
      await _post('sendMessage', {
        'chat_id': chatId,
        'text': chunk,
      });
    }
  }

  /// Send a chat action (e.g. 'typing') to indicate the bot is processing.
  Future<void> sendChatAction(String chatId, {String action = 'typing'}) async {
    await _post('sendChatAction', {
      'chat_id': chatId,
      'action': action,
    });
  }

  @override
  Future<void> sendMessageStreaming(
    String chatId,
    Stream<String> textStream,
  ) async {
    final buffer = StringBuffer();
    var lastSent = DateTime.now();
    const minInterval = Duration(milliseconds: 150);

    await for (final delta in textStream) {
      buffer.write(delta);

      final now = DateTime.now();
      if (now.difference(lastSent) >= minInterval) {
        await _sendDraft(chatId, buffer.toString());
        lastSent = now;
      }
    }

    // Publish the final message.
    final finalText = buffer.toString().trim();
    if (finalText.isNotEmpty) {
      await _publishDraft(chatId, finalText);
    }
  }

  @override
  Stream<BotIncomingMessage> pollMessages() async* {
    _polling = true;
    // Dedicated client for long-polling; stopPolling() closes it.
    _pollClient = _clientFactory();

    while (_polling) {
      try {
        final resp = await _pollClient!.post(
          Uri.parse('$_baseUrl/getUpdates'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'offset': _updateOffset,
            'timeout': 30,
            'allowed_updates': ['message'],
          }),
        );

        if (!_polling) break;
        if (resp.statusCode != 200) {
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['ok'] != true) {
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        final updates = json['result'] as List<dynamic>;
        for (final update in updates) {
          final updateId = update['update_id'] as int;
          _updateOffset = updateId + 1;

          final message = update['message'] as Map<String, dynamic>?;
          if (message == null) continue;

          final text = message['text'] as String?;
          if (text == null || text.isEmpty) continue;

          final chat = message['chat'] as Map<String, dynamic>;
          yield BotIncomingMessage(
            chatId: chat['id'].toString(),
            messageId: message['message_id'] as int,
            text: text,
          );
        }
      } catch (_) {
        if (!_polling) break;
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  @override
  void stopPolling() {
    _polling = false;
    _pollClient?.close();
    _pollClient = null;
  }

  // ------------------------------------------------------------------
  // Telegram-specific helpers
  // ------------------------------------------------------------------

  /// Send a draft (streaming partial text) via Bot API 9.5 `sendMessageDraft`.
  Future<void> _sendDraft(String chatId, String text) async {
    await _post('sendMessageDraft', {
      'chat_id': chatId,
      'text': text,
    });
  }

  /// Publish the draft as a final message.
  /// Falls back to `sendMessage` if `publishMessageDraft` is unavailable.
  Future<void> _publishDraft(String chatId, String text) async {
    try {
      await _post('publishMessageDraft', {
        'chat_id': chatId,
      });
    } catch (_) {
      // publishMessageDraft is Bot API 9.5+; fall back to normal send.
      await sendMessage(chatId, text);
    }
  }

  Future<http.Response> _get(String method) async {
    final resp = await _client.get(Uri.parse('$_baseUrl/$method'));
    _checkResponse(resp, method);
    return resp;
  }

  Future<http.Response> _post(
    String method,
    Map<String, dynamic> body,
  ) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/$method'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _checkResponse(resp, method);
    return resp;
  }

  /// Validate Telegram API response: check HTTP status and `ok` field.
  void _checkResponse(http.Response resp, String method) {
    if (resp.statusCode != 200) {
      throw BotApiException('$method: HTTP ${resp.statusCode}');
    }
    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['ok'] != true) {
        final desc = json['description']?.toString() ?? 'Unknown error';
        throw BotApiException('$method: $desc');
      }
    } on BotApiException {
      rethrow;
    } catch (_) {
      // Non-JSON response — ignore parse error
    }
  }

  /// Split long text into chunks of at most [maxLen] characters.
  static List<String> _splitText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      final end = (start + maxLen).clamp(0, text.length);
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }
}
