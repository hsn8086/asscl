import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:domain/domain.dart' as domain;
import 'package:data/data.dart';

void main() {
  late AppDatabase db;
  late ReminderRepositoryImpl repo;

  final now = DateTime(2026, 3, 5);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReminderRepositoryImpl(ReminderDao(db));
  });

  tearDown(() => db.close());

  domain.Reminder makeReminder({String id = '1', String title = 'Class'}) =>
      domain.Reminder(
        id: id,
        title: title,
        scheduledAt: now.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
      );

  test('save and findById', () async {
    await repo.save(makeReminder());
    final found = await repo.findById('1');
    expect(found, isNotNull);
    expect(found!.title, 'Class');
    expect(found.isActive, true);
  });

  test('setActive updates isActive', () async {
    await repo.save(makeReminder());
    await repo.setActive('1', active: false);
    final found = await repo.findById('1');
    expect(found!.isActive, false);
  });

  test('delete removes reminder', () async {
    await repo.save(makeReminder());
    await repo.delete('1');
    final found = await repo.findById('1');
    expect(found, isNull);
  });
}
