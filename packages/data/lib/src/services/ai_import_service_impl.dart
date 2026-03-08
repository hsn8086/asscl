import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

class AiImportConfig {
  final String baseUrl;
  final String apiKey;
  final String? modelName;

  const AiImportConfig({
    required this.baseUrl,
    required this.apiKey,
    this.modelName,
  });

  String get chatCompletionsUrl => '$baseUrl/chat/completions';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiImportConfig &&
          baseUrl == other.baseUrl &&
          apiKey == other.apiKey &&
          modelName == other.modelName;

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, modelName);
}

class AiImportServiceImpl implements AiImportService {
  final AiImportConfig config;
  final http.Client _client;

  AiImportServiceImpl({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<AiParsedCourse>> parseText(
    String rawText, {
    String? extraPrompt,
  }) async {
    final systemPrompt = StringBuffer('''
你是一个课程表解析助手。用户会提供课程表的文本内容，请将其解析为结构化的 JSON 数组。

每个课程对象的字段：
- name (string, 必填): 课程名称
- location (string|null): 上课地点
- teacher (string|null): 授课教师
- weekday (int, 必填): 星期几，1=周一, 2=周二, ..., 7=周日
- startPeriod (int, 必填): 开始节次，从1开始
- endPeriod (int, 必填): 结束节次
- weekMode (string): "every"=每周, "odd"=单周, "even"=双周, "custom"=自定义
- customWeeks (int[]): 当 weekMode 为 "custom" 时，具体哪几周上课

只输出 JSON 数组，不要输出其他内容。如果无法解析，返回空数组 []。
''');

    if (extraPrompt != null && extraPrompt.isNotEmpty) {
      systemPrompt.writeln('\n额外提示：$extraPrompt');
    }

    final body = jsonEncode({
      'model': config.modelName ?? 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt.toString()},
        {'role': 'user', 'content': rawText},
      ],
      'temperature': 0.1,
    });

    final response = await _client.post(
      Uri.parse(config.chatCompletionsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('AI API 请求失败: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        json['choices'][0]['message']['content'] as String;

    // Extract JSON array from response (handle markdown code blocks)
    final jsonStr = _extractJson(content);
    final list = jsonDecode(jsonStr) as List<dynamic>;

    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return AiParsedCourse(
        name: m['name'] as String,
        location: m['location'] as String?,
        teacher: m['teacher'] as String?,
        weekday: m['weekday'] as int,
        startPeriod: m['startPeriod'] as int,
        endPeriod: m['endPeriod'] as int,
        weekMode: _parseWeekMode(m['weekMode'] as String?),
        customWeeks: (m['customWeeks'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
      );
    }).toList();
  }

  String _extractJson(String content) {
    // Try to extract JSON from markdown code block
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!.trim();
    }
    return content.trim();
  }

  WeekMode _parseWeekMode(String? value) {
    switch (value) {
      case 'odd':
        return WeekMode.odd;
      case 'even':
        return WeekMode.even;
      case 'custom':
        return WeekMode.custom;
      default:
        return WeekMode.every;
    }
  }
}
