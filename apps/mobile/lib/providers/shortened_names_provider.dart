import 'dart:convert';

import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'ai_providers.dart';
import 'course_providers.dart';
import 'database_provider.dart';

/// Whether AI-shortened course names are enabled.
final aiShortenNamesEnabledProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final value = await dao.getValue('aiShortenNames');
  return value == 'true';
});

/// Runtime cache of shortened course names: courseId → shortName.
/// Only populated when the setting is enabled and AI config is available.
final shortenedCourseNamesProvider =
    AsyncNotifierProvider<ShortenedCourseNamesNotifier, Map<String, String>>(
  ShortenedCourseNamesNotifier.new,
);

class ShortenedCourseNamesNotifier
    extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final enabled = await ref.watch(aiShortenNamesEnabledProvider.future);
    if (!enabled) return {};

    final config = ref.watch(aiConfigProvider).valueOrNull;
    if (config == null) return {};

    final courses = await ref.watch(watchCoursesProvider.future);
    if (courses.isEmpty) return {};

    return _shortenNames(config, courses);
  }

  Future<Map<String, String>> _shortenNames(
    AiImportConfig config,
    List<Course> courses,
  ) async {
    // Build name list (deduplicate by name)
    final uniqueNames = courses.map((c) => c.name).toSet().toList();

    // Skip if all names are already short (≤ 4 characters)
    if (uniqueNames.every((n) => n.length <= 4)) {
      return {};
    }

    try {
      final client = http.Client();
      try {
        final nameList =
            uniqueNames.asMap().entries.map((e) => '${e.key}. ${e.value}').join('\n');

        final response = await client.post(
          Uri.parse(config.apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode({
            'model': config.modelName ?? 'gpt-4o-mini',
            'messages': [
              {
                'role': 'system',
                'content':
                    '你是一个课程名称缩写助手。将课程名称缩短为2-4个字的简称，保留核心含义。'
                    '只输出 JSON 对象，key 为原名称，value 为缩写。不要输出其他内容。',
              },
              {
                'role': 'user',
                'content': '请缩写以下课程名称：\n$nameList',
              },
            ],
            'temperature': 0.1,
          }),
        );

        if (response.statusCode != 200) return {};

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            json['choices'][0]['message']['content'] as String;

        // Extract JSON from response (may have markdown code block)
        final jsonStr = _extractJson(content);
        if (jsonStr == null) return {};

        final mapping = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Build courseId → shortName map
        final result = <String, String>{};
        for (final course in courses) {
          final shortName = mapping[course.name] as String?;
          if (shortName != null && shortName != course.name) {
            result[course.id] = shortName;
          }
        }
        return result;
      } finally {
        client.close();
      }
    } catch (_) {
      return {};
    }
  }

  String? _extractJson(String content) {
    // Try to extract from code block
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!.trim();
    }
    // Try raw JSON
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) return trimmed;
    return null;
  }
}
