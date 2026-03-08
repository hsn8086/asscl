import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/database_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/semester_providers.dart';
import '../../providers/shortened_names_provider.dart';

class DeveloperPage extends ConsumerWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semester = ref.watch(activeSemesterProvider);
    final currentWeek = ref.watch(currentWeekProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('开发者选项')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 诊断信息 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              '诊断信息',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (semester != null) ...[
                    _InfoRow('学期', semester.name),
                    _InfoRow(
                      '起始日期',
                      DateFormat('yyyy-MM-dd').format(semester.startDate),
                    ),
                    _InfoRow('当前周次', '$currentWeek / ${semester.totalWeeks}'),
                  ] else
                    const Text('未设置学期'),
                ],
              ),
            ),
          ),

          // ── 调试操作 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              '调试操作',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('触发天气提醒'),
                  subtitle: const Text('重置今日已展示状态，回到课表页后重新弹出'),
                  onTap: () => _resetWeatherAlert(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.short_text),
                  title: const Text('清除简称缓存'),
                  subtitle: const Text('删除 AI 生成的课程简称'),
                  onTap: () => _clearShortenedNames(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('重置引导流程'),
                  subtitle: const Text('清除引导完成标记，重新进入引导页'),
                  onTap: () => _resetOnboarding(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _resetWeatherAlert(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).deleteKey('weatherAlertLastDate');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置，返回课表页将重新显示天气提醒')),
      );
    }
  }

  Future<void> _clearShortenedNames(
      BuildContext context, WidgetRef ref) async {
    await ref.read(shortenedCourseNamesProvider.notifier).clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('简称缓存已清除')),
      );
    }
  }

  Future<void> _resetOnboarding(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).deleteKey('onboardingCompleted');
    ref.invalidate(onboardingCompletedProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('引导流程已重置')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
