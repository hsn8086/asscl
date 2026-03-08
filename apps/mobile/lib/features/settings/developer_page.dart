import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/database_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/semester_providers.dart';
import '../../providers/shortened_names_provider.dart';
import '../../providers/weather_providers.dart';
import '../schedule/widgets/weather_alert_card.dart';

/// Provider to hold a mock WeatherInfo for developer preview.
/// When non-null, WeatherAlertCard can be overridden to show this.
final mockWeatherProvider = StateProvider<WeatherInfo?>((ref) => null);

class DeveloperPage extends ConsumerWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semester = ref.watch(activeSemesterProvider);
    final currentWeek = ref.watch(currentWeekProvider);
    final weatherAsync = ref.watch(currentWeatherProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('开发者选项')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 诊断信息 ──
          _sectionHeader(theme, '诊断信息'),
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
                  const Divider(height: 16),
                  weatherAsync.when(
                    loading: () => const _InfoRow('天气', '加载中...'),
                    error: (e, _) => _InfoRow('天气', '获取失败: $e'),
                    data: (weather) {
                      if (weather == null) {
                        return const _InfoRow('天气', '未启用或无权限');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow('位置', weather.location),
                          _InfoRow('天气', weather.condition),
                          _InfoRow('温度',
                              '${weather.tempC.round()}°C（体感 ${weather.feelsLikeC.round()}°C）'),
                          _InfoRow('湿度', '${weather.humidity}%'),
                          _InfoRow('风速',
                              '${weather.windSpeedKmph} km/h ${weather.windDir}'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── 天气卡片预览 ──
          _sectionHeader(theme, '天气卡片预览'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.umbrella),
                  title: const Text('雨天卡片'),
                  subtitle: const Text('模拟下雨 20°C'),
                  onTap: () => _showMockWeatherCard(context, '小雨', 20),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.ac_unit),
                  title: const Text('雪天卡片'),
                  subtitle: const Text('模拟下雪 -3°C'),
                  onTap: () => _showMockWeatherCard(context, '小雪', -3),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.wb_sunny),
                  title: const Text('高温卡片'),
                  subtitle: const Text('模拟晴天 38°C'),
                  onTap: () => _showMockWeatherCard(context, '晴', 38),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.severe_cold),
                  title: const Text('低温卡片'),
                  subtitle: const Text('模拟阴天 -5°C'),
                  onTap: () => _showMockWeatherCard(context, '阴', -5),
                ),
              ],
            ),
          ),

          // ── 调试操作 ──
          _sectionHeader(theme, '调试操作'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('重置天气提醒状态'),
                  subtitle: const Text('清除今日已展示标记，回到课表页后重新弹出'),
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

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  void _showMockWeatherCard(
      BuildContext context, String condition, double tempC) {
    final weather = WeatherInfo(
      location: '模拟位置',
      tempC: tempC,
      feelsLikeC: tempC - 2,
      condition: condition,
      humidity: 65,
      windSpeedKmph: 12,
      windDir: 'N',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('天气卡片预览'),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: WeatherAlertCard.preview(weather: weather),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
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
