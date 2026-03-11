import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  final CourseRepository _courseRepo;
  final PeriodConfigRepository _periodConfigRepo;

  WidgetService(this._courseRepo, this._periodConfigRepo);

  /// Update all home screen widgets with current course data.
  Future<void> updateWidgets({
    String semesterName = '',
    String? semesterId,
    int currentWeek = 1,
    Map<String, String> shortenedNames = const {},
  }) async {
    var allCourses = await _courseRepo.watchAll().first;
    debugPrint('[Widget] total courses in DB: ${allCourses.length}');
    if (semesterId != null) {
      allCourses =
          allCourses.where((c) => c.semesterId == semesterId).toList();
      debugPrint('[Widget] after semesterId($semesterId) filter: ${allCourses.length}');
    } else {
      debugPrint('[Widget] semesterId is null, no filter applied');
    }
    final periodConfig = await _periodConfigRepo.getConfig();

    final now = DateTime.now();
    final todayWeekday = now.weekday;

    final todayCourses =
        filterCoursesForDay(allCourses, todayWeekday, currentWeek);
    debugPrint('[Widget] today(weekday=$todayWeekday, week=$currentWeek) courses: ${todayCourses.length}');
    final nextCourse = findNextCourse(todayCourses, periodConfig, now);

    // Data for small widget (next class)
    await HomeWidget.saveWidgetData<String>(
      'next_course_json',
      nextCourse != null
          ? jsonEncode(courseToMap(nextCourse, periodConfig, shortenedNames))
          : '',
    );

    // Data for large widget (weekly schedule)
    final weeklyData =
        buildWeeklyCourses(allCourses, currentWeek, periodConfig, shortenedNames);
    final weeklyJson = jsonEncode(weeklyData);
    debugPrint('[Widget] weeklyJson length=${weeklyJson.length}, '
        'semesterName=$semesterName, currentWeek=$currentWeek');
    await HomeWidget.saveWidgetData<String>(
      'weekly_courses_json',
      weeklyJson,
    );
    await HomeWidget.saveWidgetData<int>(
      'current_week',
      currentWeek,
    );
    await HomeWidget.saveWidgetData<int>(
      'total_periods',
      periodConfig.totalPeriods,
    );
    await HomeWidget.saveWidgetData<String>(
      'semester_name',
      semesterName,
    );

    await HomeWidget.updateWidget(
      androidName: 'NextClassWidgetProvider',
      qualifiedAndroidName: 'com.hsn8086.asscl.NextClassWidgetProvider',
    );
    await HomeWidget.updateWidget(
      androidName: 'TodayScheduleWidgetProvider',
      qualifiedAndroidName: 'com.hsn8086.asscl.TodayScheduleWidgetProvider',
    );
    debugPrint('[Widget] updateWidget calls completed');
  }

  /// Build weekly courses data: map of weekday (1-7) to list of course maps.
  Map<String, dynamic> buildWeeklyCourses(
      List<Course> all, int currentWeek, PeriodConfig config,
      Map<String, String> shortenedNames) {
    final result = <String, dynamic>{};
    for (int day = 1; day <= 7; day++) {
      final dayCourses = filterCoursesForDay(all, day, currentWeek);
      result[day.toString()] =
          dayCourses.map((c) => courseToMap(c, config, shortenedNames)).toList();
    }
    return result;
  }

  /// Filter courses for a given weekday and week number.
  List<Course> filterCoursesForDay(
      List<Course> all, int weekday, int currentWeek) {
    return all
        .where((c) => c.weekday == weekday)
        .where((c) => _isActiveInWeek(c, currentWeek))
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
  }

  /// Find the next upcoming course (not yet started).
  /// Returns the first course of the day if no time info is configured.
  Course? findNextCourse(
      List<Course> todayCourses, PeriodConfig config, DateTime now) {
    if (todayCourses.isEmpty) return null;

    if (!config.hasTimeInfo) {
      return todayCourses.first;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    for (final c in todayCourses) {
      final periodTime = config.getTime(c.startPeriod);
      if (periodTime == null) continue;
      final startMinutes = periodTime.startHour * 60 + periodTime.startMinute;
      if (startMinutes > nowMinutes) return c;
    }
    return null; // All classes started or ended
  }

  /// Serialize a course to a map suitable for widget display.
  Map<String, dynamic> courseToMap(Course c, PeriodConfig config,
      Map<String, String> shortenedNames) {
    final timeRange = config.timeRangeString(c.startPeriod, c.endPeriod);
    final shortName = shortenedNames[c.name.trim().toLowerCase()];
    final startTime = config.getTime(c.startPeriod);
    final startMinutes = startTime != null
        ? startTime.startHour * 60 + startTime.startMinute
        : -1;
    return {
      'name': shortName ?? c.name,
      'location': c.location ?? '',
      'teacher': c.teacher ?? '',
      'startPeriod': c.startPeriod,
      'endPeriod': c.endPeriod,
      'timeRange': timeRange ?? '第${c.startPeriod}-${c.endPeriod}节',
      'color': c.color ?? '',
      'startMinutes': startMinutes,
    };
  }

  bool _isActiveInWeek(Course c, int week) {
    switch (c.weekMode) {
      case WeekMode.every:
        return true;
      case WeekMode.odd:
        return week.isOdd;
      case WeekMode.even:
        return week.isEven;
      case WeekMode.custom:
        return c.customWeeks.contains(week);
    }
  }
}
