import 'dart:convert';

import 'package:domain/domain.dart';
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
  }) async {
    var allCourses = await _courseRepo.watchAll().first;
    if (semesterId != null) {
      allCourses =
          allCourses.where((c) => c.semesterId == semesterId).toList();
    }
    final periodConfig = await _periodConfigRepo.getConfig();

    final now = DateTime.now();
    final todayWeekday = now.weekday;

    final todayCourses =
        filterCoursesForDay(allCourses, todayWeekday, currentWeek);
    final nextCourse = findNextCourse(todayCourses, periodConfig, now);

    // Data for small widget (next class)
    await HomeWidget.saveWidgetData<String>(
      'next_course_json',
      nextCourse != null
          ? jsonEncode(courseToMap(nextCourse, periodConfig))
          : '',
    );

    // Data for large widget (weekly schedule)
    final weeklyData =
        buildWeeklyCourses(allCourses, currentWeek, periodConfig);
    await HomeWidget.saveWidgetData<String>(
      'weekly_courses_json',
      jsonEncode(weeklyData),
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
  }

  /// Build weekly courses data: map of weekday (1-7) to list of course maps.
  Map<String, dynamic> buildWeeklyCourses(
      List<Course> all, int currentWeek, PeriodConfig config) {
    final result = <String, dynamic>{};
    for (int day = 1; day <= 7; day++) {
      final dayCourses = filterCoursesForDay(all, day, currentWeek);
      result[day.toString()] =
          dayCourses.map((c) => courseToMap(c, config)).toList();
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

  /// Find the next upcoming course (not yet ended).
  /// Returns the first course of the day if no time info is configured.
  Course? findNextCourse(
      List<Course> todayCourses, PeriodConfig config, DateTime now) {
    if (todayCourses.isEmpty) return null;

    if (!config.hasTimeInfo) {
      return todayCourses.first;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    for (final c in todayCourses) {
      final periodTime = config.getTime(c.endPeriod);
      if (periodTime == null) continue;
      final endMinutes = periodTime.endHour * 60 + periodTime.endMinute;
      if (endMinutes > nowMinutes) return c;
    }
    return null; // All classes ended
  }

  /// Serialize a course to a map suitable for widget display.
  Map<String, dynamic> courseToMap(Course c, PeriodConfig config) {
    final timeRange = config.timeRangeString(c.startPeriod, c.endPeriod);
    return {
      'name': c.name,
      'location': c.location ?? '',
      'teacher': c.teacher ?? '',
      'startPeriod': c.startPeriod,
      'endPeriod': c.endPeriod,
      'timeRange': timeRange ?? '第${c.startPeriod}-${c.endPeriod}节',
      'color': c.color ?? '',
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
