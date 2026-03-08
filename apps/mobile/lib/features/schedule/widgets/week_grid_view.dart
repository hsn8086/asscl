import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:presentation/presentation.dart';

import '../../../providers/course_providers.dart';
import '../../../providers/period_config_providers.dart';
import '../../../providers/semester_providers.dart';
import 'course_card.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const _headerHeight = 24.0;
const _minCellHeight = 36.0;
const _maxCellHeight = 72.0;

class WeekGridView extends ConsumerStatefulWidget {
  final int weekNumber;
  const WeekGridView({super.key, required this.weekNumber});

  @override
  ConsumerState<WeekGridView> createState() => _WeekGridViewState();
}

class _WeekGridViewState extends ConsumerState<WeekGridView> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(watchCoursesProvider);
    final configAsync = ref.watch(periodConfigProvider);
    final weekNumber = widget.weekNumber;

    final config = configAsync.valueOrNull ?? const PeriodConfig();

    // Time indicator and today highlight only show on the real current week.
    final realWeek = ref.watch(currentWeekProvider);
    final isCurrentWeek = weekNumber == realWeek;

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

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalPeriods = config.totalPeriods;
            final availableHeight = constraints.maxHeight;

            // Calculate adaptive cell height.
            var cellHeight =
                (availableHeight - _headerHeight) / totalPeriods;
            cellHeight = cellHeight.clamp(_minCellHeight, _maxCellHeight);

            final gridHeight = _headerHeight + cellHeight * totalPeriods;
            final needsScroll = gridHeight > availableHeight;

            Widget grid =
                _buildGrid(context, filtered, config, isCurrentWeek, cellHeight);

            if (needsScroll) {
              grid = SingleChildScrollView(child: grid);
            }

            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 2.5,
              child: grid,
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

  Widget _buildGrid(BuildContext context, List<Course> courses,
      PeriodConfig config, bool isCurrentWeek, double cellHeight) {
    final totalPeriods = config.totalPeriods;
    final hasTime = config.hasTimeInfo;
    final labelWidth = hasTime ? 56.0 : 40.0;
    final cellWidth =
        (MediaQuery.of(context).size.width - labelWidth) / 7;

    // Only show time indicator on the current week
    final timeIndicatorY = (hasTime && isCurrentWeek)
        ? _calcTimeIndicatorY(config, cellHeight)
        : null;
    // Only highlight today on the current week
    final todayWeekday = isCurrentWeek ? _now.weekday : -1;

    final courseMap = <(int, int), Course>{};
    final occupiedBy = <(int, int), Course>{};
    for (final c in courses) {
      courseMap[(c.weekday, c.startPeriod)] = c;
      for (int p = c.startPeriod; p <= c.endPeriod; p++) {
        occupiedBy[(c.weekday, p)] = c;
      }
    }

    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  SizedBox(width: labelWidth, child: Container()),
                  for (int i = 0; i < _weekdays.length; i++)
                    SizedBox(
                      width: cellWidth,
                      child: Center(
                        child: Text(
                          _weekdays[i],
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: (i + 1) == todayWeekday
                                    ? FontWeight.bold
                                    : null,
                                color: (i + 1) == todayWeekday
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (int period = 1; period <= totalPeriods; period++)
              Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    height: cellHeight,
                    child: _periodLabel(context, period, config, cellHeight),
                  ),
                  for (int day = 1; day <= 7; day++)
                    SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: _cellContent(
                        context,
                        courseMap, occupiedBy, day, period,
                        cellWidth, cellHeight,
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (timeIndicatorY != null && todayWeekday >= 1)
          Positioned(
            top: timeIndicatorY + _headerHeight,
            // Position only on today's column
            left: labelWidth + (todayWeekday - 1) * cellWidth,
            width: cellWidth,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _periodLabel(
      BuildContext context, int period, PeriodConfig config, double cellHeight) {
    final pt = config.getTime(period);
    final timeFontSize = (cellHeight / 60.0 * 8).clamp(6.0, 9.0);
    if (pt == null) {
      return Center(
        child:
            Text('$period', style: Theme.of(context).textTheme.labelSmall),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$period', style: Theme.of(context).textTheme.labelSmall),
        Text(pt.startTimeStr,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontSize: timeFontSize, color: Colors.grey)),
        Text(pt.endTimeStr,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontSize: timeFontSize, color: Colors.grey)),
      ],
    );
  }

  double? _calcTimeIndicatorY(PeriodConfig config, double cellHeight) {
    final nowMinutes = _now.hour * 60 + _now.minute;

    for (final pt in config.periods) {
      final startMin = pt.startHour * 60 + pt.startMinute;
      final endMin = pt.endHour * 60 + pt.endMinute;

      if (nowMinutes >= startMin && nowMinutes <= endMin) {
        final fraction = (nowMinutes - startMin) / (endMin - startMin);
        return (pt.periodNumber - 1) * cellHeight + fraction * cellHeight;
      }
    }

    final sorted = List.of(config.periods)
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    for (int i = 0; i < sorted.length - 1; i++) {
      final endMin = sorted[i].endHour * 60 + sorted[i].endMinute;
      final nextStartMin =
          sorted[i + 1].startHour * 60 + sorted[i + 1].startMinute;
      if (nowMinutes > endMin && nowMinutes < nextStartMin) {
        return sorted[i].periodNumber * cellHeight;
      }
    }

    if (sorted.isNotEmpty) {
      final firstStart =
          sorted.first.startHour * 60 + sorted.first.startMinute;
      if (nowMinutes < firstStart) return 0;
      final lastEnd = sorted.last.endHour * 60 + sorted.last.endMinute;
      if (nowMinutes > lastEnd) {
        return sorted.last.periodNumber * cellHeight;
      }
    }

    return null;
  }

  Widget _cellContent(
    BuildContext context,
    Map<(int, int), Course> courseMap,
    Map<(int, int), Course> occupiedBy,
    int weekday,
    int period,
    double cellWidth,
    double cellHeight,
  ) {
    final course = courseMap[(weekday, period)];
    if (course != null) {
      final spanPeriods = course.endPeriod - course.startPeriod + 1;
      final totalHeight = cellHeight * spanPeriods;

      return OverflowBox(
        alignment: Alignment.topLeft,
        maxHeight: totalHeight,
        minHeight: totalHeight,
        child: SizedBox(
          height: totalHeight,
          width: cellWidth,
          child: CourseCard(
            course: course,
            spanPeriods: spanPeriods,
            cellHeight: cellHeight,
          ),
        ),
      );
    }

    // Occupied by a multi-period course — transparent but tappable
    final owner = occupiedBy[(weekday, period)];
    if (owner != null) {
      return GestureDetector(
        onTap: () => context.go('/schedule/course/${owner.id}'),
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      );
    }

    return const SizedBox.shrink();
  }
}
