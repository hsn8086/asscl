import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:domain/domain.dart' as domain;
import 'package:data/data.dart';

void main() {
  late AppDatabase db;
  late CourseRepositoryImpl repo;

  final now = DateTime(2026, 3, 5);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CourseRepositoryImpl(CourseDao(db));
  });

  tearDown(() => db.close());

  domain.Course makeCourse({String id = '1', String name = 'Math'}) =>
      domain.Course(
        id: id,
        name: name,
        weekday: 1,
        startPeriod: 1,
        endPeriod: 2,
        weekMode: domain.WeekMode.every,
        createdAt: now,
        updatedAt: now,
      );

  test('save and findById', () async {
    final course = makeCourse();
    await repo.save(course);
    final found = await repo.findById('1');
    expect(found, isNotNull);
    expect(found!.name, 'Math');
    expect(found.weekday, 1);
  });

  test('save with custom weeks roundtrip', () async {
    final course = makeCourse().copyWith(
      weekMode: domain.WeekMode.custom,
      customWeeks: [1, 3, 5, 7],
    );
    await repo.save(course);
    final found = await repo.findById('1');
    expect(found!.weekMode, domain.WeekMode.custom);
    expect(found.customWeeks, [1, 3, 5, 7]);
  });

  test('watchAll emits updates', () async {
    final stream = repo.watchAll();

    await repo.save(makeCourse(id: '1', name: 'Math'));

    await expectLater(
      stream,
      emits(predicate<List<domain.Course>>(
          (list) => list.length == 1 && list.first.name == 'Math')),
    );
  });

  test('delete removes course', () async {
    await repo.save(makeCourse());
    await repo.delete('1');
    final found = await repo.findById('1');
    expect(found, isNull);
  });

  test('save updates existing course (upsert)', () async {
    await repo.save(makeCourse());
    await repo.save(makeCourse(name: 'Physics'));
    final found = await repo.findById('1');
    expect(found!.name, 'Physics');
  });
}
