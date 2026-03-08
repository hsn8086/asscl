import 'dart:io';

import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'database_provider.dart';
import 'proxy_providers.dart';

final aiConfigProvider = FutureProvider<AiImportConfig?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);

  // Try new key first, then fall back to legacy key with migration.
  var baseUrl = await dao.getValue('aiBaseUrl');
  if (baseUrl == null) {
    final legacy = await dao.getValue('aiApiEndpoint');
    if (legacy != null) {
      // Strip trailing path segments (e.g. /chat/completions).
      baseUrl = extractBaseUrl(legacy);
      await dao.setValue('aiBaseUrl', baseUrl);
      await dao.deleteKey('aiApiEndpoint');
    }
  }

  final key = await dao.getValue('aiApiKey');
  if (baseUrl == null || key == null) return null;
  final model = await dao.getValue('aiModelName');
  return AiImportConfig(baseUrl: baseUrl, apiKey: key, modelName: model);
});

/// Extract base URL from a full endpoint URL.
/// e.g. `https://api.openai.com/v1/chat/completions` → `https://api.openai.com/v1`
String extractBaseUrl(String endpoint) {
  final chatIdx = endpoint.indexOf('/chat/completions');
  if (chatIdx != -1) return endpoint.substring(0, chatIdx);
  final audioIdx = endpoint.indexOf('/audio/transcriptions');
  if (audioIdx != -1) return endpoint.substring(0, audioIdx);
  // If it already looks like a base URL, use as-is.
  return endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;
}

final aiImportServiceProvider = Provider<AiImportService?>((ref) {
  final config = ref.watch(aiConfigProvider).valueOrNull;
  if (config == null) return null;
  final client = ref.watch(httpClientProvider);
  return AiImportServiceImpl(config: config, client: client);
});

/// Creates an [AiAgentServiceImpl] using the current config and proxy.
AiAgentServiceImpl? _createAgent(Ref ref, AiImportConfig config, http.Client client) {
  return AiAgentServiceImpl(
    config: config,
    client: client,
    clientFactory: () {
      final proxy = ref.read(proxyConfigProvider).valueOrNull;
      if (proxy != null && proxy.isValid) {
        final ioClient = HttpClient()..findProxy = (uri) => proxy.proxyUrl;
        return IOClient(ioClient);
      }
      return http.Client();
    },
  );
}

/// App-side AI agent — persists across navigation, isolated from Bot.
AiAgentService? _cachedAppAgent;
AiImportConfig? _lastAppConfig;
http.Client? _lastAppClient;

final aiAgentServiceProvider = Provider<AiAgentService?>((ref) {
  final config = ref.watch(aiConfigProvider).valueOrNull;
  final client = ref.watch(httpClientProvider);
  if (config == null) {
    _cachedAppAgent = null;
    _lastAppConfig = null;
    _lastAppClient = null;
    return null;
  }
  if (_cachedAppAgent != null &&
      _lastAppConfig == config &&
      _lastAppClient == client) {
    return _cachedAppAgent;
  }
  _lastAppConfig = config;
  _lastAppClient = client;
  _cachedAppAgent = _createAgent(ref, config, client);
  return _cachedAppAgent;
});

/// Bot-side AI agent — separate instance with its own conversation history.
AiAgentService? _cachedBotAgent;
AiImportConfig? _lastBotConfig;
http.Client? _lastBotClient;

final botAgentServiceProvider = Provider<AiAgentService?>((ref) {
  final config = ref.watch(aiConfigProvider).valueOrNull;
  final client = ref.watch(httpClientProvider);
  if (config == null) {
    _cachedBotAgent = null;
    _lastBotConfig = null;
    _lastBotClient = null;
    return null;
  }
  if (_cachedBotAgent != null &&
      _lastBotConfig == config &&
      _lastBotClient == client) {
    return _cachedBotAgent;
  }
  _lastBotConfig = config;
  _lastBotClient = client;
  _cachedBotAgent = _createAgent(ref, config, client);
  return _cachedBotAgent;
});

/// ChatSessionDao provider.
final chatSessionDaoProvider = Provider<ChatSessionDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatSessionDao(db);
});

/// Current chat session ID (null = new session).
final currentChatSessionIdProvider = StateProvider<String?>((ref) => null);

/// Watch all saved chat sessions.
final chatSessionsProvider = StreamProvider<List<ChatSessionsTableData>>((ref) {
  final dao = ref.watch(chatSessionDaoProvider);
  return dao.watchAllSessions();
});

/// "Enter to send" setting.
final enterToSendProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final value = await dao.getValue('enterToSend');
  return value == 'true';
});
