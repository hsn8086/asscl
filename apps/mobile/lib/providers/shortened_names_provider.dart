import 'dart:convert';

import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_providers.dart';
import 'course_providers.dart';
import 'database_provider.dart';
import 'proxy_providers.dart';

const _cacheKey = 'shortenedCourseNames';

/// Helper to look up a short name from the cache by course name.
String? lookupShortName(Map<String, String> cache, String courseName) {
  return cache[courseName.trim().toLowerCase()];
}

/// Whether AI-shortened course names are enabled.
final aiShortenNamesEnabledProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final value = await dao.getValue('aiShortenNames');
  return value == 'true';
});

/// Persistent cache of shortened course names: normalizedName → shortName.
/// Normalized name = name.trim().toLowerCase().
/// Stored as JSON in the settings table.
final shortenedCourseNamesProvider =
    AsyncNotifierProvider<ShortenedCourseNamesNotifier, Map<String, String>>(
  ShortenedCourseNamesNotifier.new,
);

class ShortenedCourseNamesNotifier
    extends AsyncNotifier<Map<String, String>> {
  SettingsDao get _dao => SettingsDao(ref.read(appDatabaseProvider));

  @override
  Future<Map<String, String>> build() async {
    final enabled = await ref.watch(aiShortenNamesEnabledProvider.future);
    if (!enabled) return {};

    // Load from DB cache
    var cached = await _loadCache();

    // Migrate old courseId-based cache to name-based cache
    if (cached.isNotEmpty) {
      final courses = await ref.watch(watchCoursesProvider.future);
      final courseById = {for (final c in courses) c.id: c};
      final hasOldKeys = cached.keys.any((k) => courseById.containsKey(k));
      if (hasOldKeys) {
        final migrated = <String, String>{};
        for (final entry in cached.entries) {
          final course = courseById[entry.key];
          if (course != null) {
            migrated[course.name.trim().toLowerCase()] = entry.value;
          } else {
            // Already a name-based key, keep it
            migrated[entry.key] = entry.value;
          }
        }
        cached = migrated;
        await _saveCache(cached);
      }
      return cached;
    }

    // No cache — try AI generation
    final config = ref.watch(aiConfigProvider).valueOrNull;
    if (config == null) return {};

    final courses = await ref.watch(watchCoursesProvider.future);
    if (courses.isEmpty) return {};

    final result = await _shortenNamesViaAi(config, courses);
    if (result.isNotEmpty) await _saveCache(result);
    return result;
  }

  /// Manually set a shortened name by normalized course name key.
  Future<void> setName(String nameKey, String shortName) async {
    final current = state.valueOrNull ?? {};
    final updated = {...current, nameKey: shortName};
    state = AsyncData(updated);
    await _saveCache(updated);
  }

  /// Remove a single shortened name by normalized course name key.
  Future<void> removeName(String nameKey) async {
    final current = state.valueOrNull ?? {};
    final updated = {...current}..remove(nameKey);
    state = AsyncData(updated);
    await _saveCache(updated);
  }

  /// Clear all shortened names and regenerate via AI.
  Future<void> regenerate() async {
    await _dao.deleteKey(_cacheKey);
    ref.invalidateSelf();
  }

  /// Clear all shortened names without regenerating.
  Future<void> clearAll() async {
    state = const AsyncData({});
    await _dao.deleteKey(_cacheKey);
  }

  Future<Map<String, String>> _loadCache() async {
    final raw = await _dao.getValue(_cacheKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCache(Map<String, String> data) async {
    await _dao.setValue(_cacheKey, jsonEncode(data));
  }

  Future<Map<String, String>> _shortenNamesViaAi(
    AiImportConfig config,
    List<Course> courses,
  ) async {
    // Deduplicate by trimmed + lowercased name so "Python程序设计" and
    // "PYTHON程序设计" are only sent to AI once.
    final seen = <String, String>{}; // lowercased → original display form
    for (final c in courses) {
      final trimmed = c.name.trim();
      final key = trimmed.toLowerCase();
      // Keep the first occurrence as the canonical display form
      seen.putIfAbsent(key, () => trimmed);
    }
    final uniqueNames = seen.values.toList();
    if (uniqueNames.every((n) => n.length <= 4)) return {};

    try {
      final client = ref.read(httpClientProvider);
      final nameList = uniqueNames
            .asMap()
            .entries
            .map((e) => '${e.key}. ${e.value}')
            .join('\n');

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
        final content = json['choices'][0]['message']['content'] as String;
        final jsonStr = _extractJson(content);
        if (jsonStr == null) return {};

        final mapping = jsonDecode(jsonStr) as Map<String, dynamic>;
        // Build a case-insensitive lookup: lowercased key → shortName
        final nameLookup = <String, String>{};
        for (final entry in mapping.entries) {
          final short = entry.value as String?;
          if (short != null) {
            nameLookup[entry.key.trim().toLowerCase()] = short;
          }
        }

        final result = <String, String>{};
        for (final entry in nameLookup.entries) {
          final key = entry.key; // already lowercased
          final shortName = entry.value;
          if (shortName.toLowerCase() != key) {
            result[key] = shortName;
          }
        }
        return result;
    } catch (_) {
      return {};
    }
  }

  String? _extractJson(String content) {
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!.trim();
    }
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) return trimmed;
    return null;
  }
}
