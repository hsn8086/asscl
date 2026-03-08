import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

/// Speech-to-text implementation that uses the LLM's multimodal capability.
///
/// Sends audio as base64-encoded `input_audio` to the chat completions
/// endpoint and asks the model to transcribe it.
class MultimodalSttServiceImpl implements SttService {
  final String chatCompletionsUrl;
  final String apiKey;
  final String model;
  final http.Client _client;

  MultimodalSttServiceImpl({
    required this.chatCompletionsUrl,
    required this.apiKey,
    required this.model,
    required http.Client client,
  }) : _client = client;

  @override
  Future<String> transcribe({
    required String filePath,
    String? language,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final base64Audio = base64Encode(bytes);

    // Detect format from extension.
    final ext = filePath.split('.').last.toLowerCase();
    final format = switch (ext) {
      'mp3' => 'mp3',
      'wav' => 'wav',
      'ogg' => 'ogg',
      'flac' => 'flac',
      'webm' => 'webm',
      'm4a' => 'mp4',
      'mp4' => 'mp4',
      _ => 'wav',
    };

    final systemPrompt = language != null
        ? '请将以下音频转写为文字（语言：$language）。只输出转写文本，不要添加任何其他内容。'
        : '请将以下音频转写为文字。只输出转写文本，不要添加任何其他内容。';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Audio,
                'format': format,
              },
            },
          ],
        },
      ],
      'temperature': 0.0,
    });

    final response = await _client.post(
      Uri.parse(chatCompletionsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          '多模态转写失败 (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        json['choices'][0]['message']['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('多模态转写返回空结果');
    }
    return content.trim();
  }
}
