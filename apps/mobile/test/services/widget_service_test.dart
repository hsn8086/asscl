import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asscl/services/widget_service.dart';

// Minimal stub repositories — only pure methods are tested, no I/O.
class _StubCourseRepo implements CourseRepository {
  @override
  Stream<List<Course>> watchAll() => const Stream.empty();
  @override
  Future<Course?> findById(String id) async => null;
  @override
  Future<void> save(Course course) async {}
  @override
  Future<void> delete(String id) async {}
}

class _StubPeriodConfigRepo implements PeriodConfigRepository {
  @override
  Stream<PeriodConfig> watchConfig() => const Stream.empty();
  @override
  Future<PeriodConfig> getConfig() async => const PeriodConfig();
  @override
  Future<void> saveConfig(PeriodConfig config) async {}
  @override
  Future<void> applyPreset(String presetId) async {}
}

Course _course({
  String id = '1',
  String name = 'Math',
  int weekday = 1,
  int startPeriod = 1,
  int endPeriod = 2,
  WeekMode weekMode = WeekMode.every,
  List<int> customWeeks = const [],
  String? location,
  String? color,
}) {
  final now = DateTime(2026, 3, 6);
  return Course(
    id: id,
    name: name,
    weekday: weekday,
    startPeriod: startPeriod,
    endPeriod: endPeriod,
    weekMode: weekMode,
    customWeeks: customWeeks,
    location: location,
    color: color,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late WidgetService service;

  setUp(() {
    service = WidgetService(_StubCourseRepo(), _StubPeriodConfigRepo());
  });

  group('filterCoursesForDay', () {
    test('filters by weekday', () {
      final courses = [
        _course(id: '1', weekday: 1),
        _course(id: '2', weekday: 2),
        _course(id: '3', weekday: 1),
      ];
      final result = service.filterCoursesForDay(courses, 1, 1);
      expect(result.map((c) => c.id), ['1', '3']);
    });

    test('sorts by startPeriod', () {
      final courses = [
        _course(id: 'a', weekday: 3, startPeriod: 5),
        _course(id: 'b', weekday: 3, startPeriod: 1),
        _course(id: 'c', weekday: 3, startPeriod: 3),
      ];
      final result = service.filterCoursesForDay(courses, 3, 1);
      expect(result.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('filters odd weeks', () {
      final courses = [
        _course(id: '1', weekday: 1, weekMode: WeekMode.odd),
      ];
      expect(service.filterCoursesForDay(courses, 1, 1), hasLength(1));
      expect(service.filterCoursesForDay(courses, 1, 2), isEmpty);
    });

    test('filters even weeks', () {
      final courses = [
        _course(id: '1', weekday: 1, weekMode: WeekMode.even),
      ];
      expect(service.filterCoursesForDay(courses, 1, 2), hasLength(1));
      expect(service.filterCoursesForDay(courses, 1, 1), isEmpty);
    });

    test('filters custom weeks', () {
      final courses = [
        _course(
            id: '1',
            weekday: 1,
            weekMode: WeekMode.custom,
            customWeeks: [1, 3, 5]),
      ];
      expect(service.filterCoursesForDay(courses, 1, 3), hasLength(1));
      expect(service.filterCoursesForDay(courses, 1, 4), isEmpty);
    });

    test('returns empty for no matching weekday', () {
      final courses = [_course(weekday: 2)];
      expect(service.filterCoursesForDay(courses, 1, 1), isEmpty);
    });
  });

  group('findNextCourse', () {
    final config = PeriodConfig(
      periods: [
        const PeriodTime(
            periodNumber: 1,
            startHour: 8,
            startMinute: 0,
            endHour: 8,
            endMinute: 45),
        const PeriodTime(
            periodNumber: 2,
            startHour: 8,
            startMinute: 55,
            endHour: 9,
            endMinute: 40),
        const PeriodTime(
            periodNumber: 3,
            startHour: 10,
            startMinute: 0,
            endHour: 10,
            endMinute: 45),
        const PeriodTime(
            periodNumber: 4,
            startHour: 10,
            startMinute: 55,
            endHour: 11,
            endMinute: 40),
      ],
    );

    test('returns null for empty list', () {
      expect(service.findNextCourse([], config, DateTime.now()), isNull);
    });

    test('returns first course when no time info', () {
      final courses = [
        _course(id: 'a', startPeriod: 3),
        _course(id: 'b', startPeriod: 1),
      ];
      final result =
          service.findNextCourse(courses, const PeriodConfig(), DateTime.now());
      expect(result?.id, 'a');
    });

    test('returns next not-yet-ended course', () {
      final courses = [
        _course(id: 'a', startPeriod: 1, endPeriod: 2),
        _course(id: 'b', startPeriod: 3, endPeriod: 4),
      ];
      // At 9:00, course 'a' (ends 9:40) is still ongoing
      final result = service.findNextCourse(
          courses, config, DateTime(2026, 3, 6, 9, 0));
      expect(result?.id, 'a');
    });

    test('skips ended courses', () {
      final courses = [
        _course(id: 'a', startPeriod: 1, endPeriod: 2),
        _course(id: 'b', startPeriod: 3, endPeriod: 4),
      ];
      // At 9:45, course 'a' (ends 9:40) has ended
      final result = service.findNextCourse(
          courses, config, DateTime(2026, 3, 6, 9, 45));
      expect(result?.id, 'b');
    });

    test('returns null when all ended', () {
      final courses = [
        _course(id: 'a', startPeriod: 1, endPeriod: 2),
      ];
      final result = service.findNextCourse(
          courses, config, DateTime(2026, 3, 6, 10, 0));
      expect(result, isNull);
    });
  });

  group('courseToMap', () {
    test('serializes with time range from config', () {
      final config = PeriodConfig(
        periods: [
          const PeriodTime(
              periodNumber: 1,
              startHour: 8,
              startMinute: 0,
              endHour: 8,
              endMinute: 45),
          const PeriodTime(
              periodNumber: 2,
              startHour: 8,
              startMinute: 55,
              endHour: 9,
              endMinute: 40),
        ],
      );
      final course =
          _course(name: '高数', startPeriod: 1, endPeriod: 2, location: 'A101');
      final map = service.courseToMap(course, config, {});
      expect(map['name'], '高数');
      expect(map['location'], 'A101');
      expect(map['timeRange'], '08:00-09:40');
    });

    test('falls back to period text when no config', () {
      final course = _course(startPeriod: 3, endPeriod: 4);
      final map = service.courseToMap(course, const PeriodConfig(), {});
      expect(map['timeRange'], '第3-4节');
    });

    test('uses shortened name when available', () {
      final course = _course(name: '高等数学');
      final map = service.courseToMap(
          course, const PeriodConfig(), {'高等数学': '高数'});
      expect(map['name'], '高数');
    });

    test('includes color', () {
      final course = _course(color: '#FF5722');
      final map = service.courseToMap(course, const PeriodConfig(), {});
      expect(map['color'], '#FF5722');
    });
  });

  group('buildWeeklyCourses', () {
    test('groups courses by weekday', () {
      final courses = [
        _course(id: '1', name: 'Mon1', weekday: 1, startPeriod: 1),
        _course(id: '2', name: 'Mon2', weekday: 1, startPeriod: 3),
        _course(id: '3', name: 'Wed1', weekday: 3, startPeriod: 2),
        _course(id: '4', name: 'Fri1', weekday: 5, startPeriod: 1),
      ];
      final result =
          service.buildWeeklyCourses(courses, 1, const PeriodConfig(), {});
      expect((result['1'] as List).length, 2);
      expect((result['2'] as List).length, 0);
      expect((result['3'] as List).length, 1);
      expect((result['4'] as List).length, 0);
      expect((result['5'] as List).length, 1);
    });

    test('respects week mode filtering', () {
      final courses = [
        _course(id: '1', weekday: 1, weekMode: WeekMode.odd),
        _course(id: '2', weekday: 1, weekMode: WeekMode.even),
      ];
      final oddWeek =
          service.buildWeeklyCourses(courses, 1, const PeriodConfig(), {});
      expect((oddWeek['1'] as List).length, 1);

      final evenWeek =
          service.buildWeeklyCourses(courses, 2, const PeriodConfig(), {});
      expect((evenWeek['1'] as List).length, 1);
    });
  });
}
