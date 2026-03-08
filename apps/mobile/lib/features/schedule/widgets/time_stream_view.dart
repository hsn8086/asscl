import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:presentation/presentation.dart';

import '../../../providers/course_providers.dart';
import 'course_card.dart';

class TimeStreamView extends ConsumerWidget {
  final int weekNumber;
  const TimeStreamView({super.key, required this.weekNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(watchCoursesProvider);

    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (courses) {
        if (courses.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_month,
            message: '暂无课程，点击 + 添加',
          );
        }

        final filtered =
            courses.where((c) => _shouldShow(c, weekNumber)).toList();

        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_month,
            message: '本周暂无课程',
          );
        }

        final sorted = [...filtered]
          ..sort((a, b) {
            final dayCompare = a.weekday.compareTo(b.weekday);
            if (dayCompare != 0) return dayCompare;
            return a.startPeriod.compareTo(b.startPeriod);
          });
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final course = sorted[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CourseCard(course: course, expanded: true),
            );
          },
        );
      },
    );
  }

  bool _shouldShow(Course course, int weekNumber) {
    switch (course.weekMode) {
      case WeekMode.every:
        return true;
      case WeekMode.odd:
        return weekNumber.isOdd;
      case WeekMode.even:
        return weekNumber.isEven;
      case WeekMode.custom:
        return course.customWeeks.contains(weekNumber);
    }
  }
}
