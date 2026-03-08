import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/period_config_providers.dart';
import '../../../providers/shortened_names_provider.dart';

const _weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class CourseCard extends ConsumerWidget {
  final Course course;
  final bool expanded;
  final int spanPeriods;
  final double cellHeight;

  const CourseCard({
    required this.course,
    this.expanded = false,
    this.spanPeriods = 1,
    this.cellHeight = 60.0,
    super.key,
  });

  Color get _color {
    if (course.color != null) {
      final hex = course.color!.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }
    const palette = [
      Colors.indigo,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.purple,
      Colors.green,
    ];
    return palette[course.weekday % palette.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expanded) {
      final config = ref.watch(periodConfigProvider).valueOrNull;
      final timeRange = config?.timeRangeString(
          course.startPeriod, course.endPeriod);
      return Card(
        color: _color.withValues(alpha: 0.15),
        child: ListTile(
          title: Text(course.name),
          subtitle: Text(
            '${_weekdayNames[course.weekday]} 第${course.startPeriod}-${course.endPeriod}节'
            '${timeRange != null ? ' ($timeRange)' : ''}'
            '${course.location != null ? ' · ${course.location}' : ''}',
          ),
          trailing: course.teacher != null ? Text(course.teacher!) : null,
          onTap: () => context.go('/schedule/course/${course.id}'),
        ),
      );
    }

    // Grid card — may span multiple periods
    final shortenedNames =
        ref.watch(shortenedCourseNamesProvider).valueOrNull ?? {};
    final displayName = lookupShortName(shortenedNames, course.name) ?? course.name;

    final scale = cellHeight / 60.0;
    final nameFontSize = ((spanPeriods > 1 ? 11.0 : 10.0) * scale).clamp(8.0, 14.0);
    final detailFontSize = (9.0 * scale).clamp(7.0, 11.0);

    return GestureDetector(
      onTap: () => context.go('/schedule/course/${course.id}'),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _color.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontSize: nameFontSize,
                fontWeight: FontWeight.w500,
                color: _color,
              ),
              maxLines: spanPeriods > 2 ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.location != null) ...[
              const SizedBox(height: 2),
              Text(
                course.location!,
                style: TextStyle(fontSize: detailFontSize, color: _color.withValues(alpha: 0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (course.teacher != null) ...[
              const SizedBox(height: 1),
              Text(
                course.teacher!,
                style: TextStyle(fontSize: detailFontSize, color: _color.withValues(alpha: 0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
