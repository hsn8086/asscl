import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:presentation/presentation.dart';

import '../../providers/course_providers.dart';
import '../../providers/period_config_providers.dart';
import '../../providers/widget_providers.dart';

const _weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class CourseDetailPage extends ConsumerWidget {
  final String courseId;

  const CourseDetailPage({required this.courseId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/schedule/course/$courseId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: '删除课程',
                content: '确认删除该课程？',
              );
              if (confirmed && context.mounted) {
                await ref.read(courseRepositoryProvider).delete(courseId);
                ref.read(widgetServiceProvider).updateWidgets();
                if (context.mounted) context.go('/schedule');
              }
            },
          ),
        ],
      ),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (course) {
          if (course == null) {
            return const Center(child: Text('课程不存在'));
          }
          final config = ref.watch(periodConfigProvider).valueOrNull;
          final timeRange = config?.timeRangeString(
              course.startPeriod, course.endPeriod);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoTile('课程名称', course.name),
              _infoTile('星期', _weekdayNames[course.weekday]),
              _infoTile(
                '节次',
                '第${course.startPeriod}-${course.endPeriod}节'
                '${timeRange != null ? ' ($timeRange)' : ''}',
              ),
              _infoTile('周模式', course.weekMode.name),
              if (course.customWeeks.isNotEmpty)
                _infoTile('自定义周次', course.customWeeks.join(', ')),
              if (course.location != null) _infoTile('地点', course.location!),
              if (course.teacher != null) _infoTile('教师', course.teacher!),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
