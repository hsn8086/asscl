import 'package:test/test.dart';
import 'package:domain/domain.dart';

void main() {
  final now = DateTime(2026, 3, 5);

  group('Course', () {
    test('equality', () {
      final a = Course(
        id: '1',
        name: 'Math',
        weekday: 1,
        startPeriod: 1,
        endPeriod: 2,
        createdAt: now,
        updatedAt: now,
      );
      final b = Course(
        id: '1',
        name: 'Math',
        weekday: 1,
        startPeriod: 1,
        endPeriod: 2,
        createdAt: now,
        updatedAt: now,
      );
      expect(a, equals(b));
    });

    test('copyWith preserves values', () {
      final course = Course(
        id: '1',
        name: 'Math',
        location: 'Room 101',
        weekday: 1,
        startPeriod: 1,
        endPeriod: 2,
        createdAt: now,
        updatedAt: now,
      );
      final updated = course.copyWith(name: 'Physics');
      expect(updated.name, 'Physics');
      expect(updated.location, 'Room 101');
      expect(updated.id, '1');
    });

    test('copyWith can set nullable fields to null', () {
      final course = Course(
        id: '1',
        name: 'Math',
        location: 'Room 101',
        weekday: 1,
        startPeriod: 1,
        endPeriod: 2,
        createdAt: now,
        updatedAt: now,
      );
      final updated = course.copyWith(location: () => null);
      expect(updated.location, isNull);
    });
  });

  group('Task', () {
    test('equality', () {
      final a = Task(
        id: '1',
        title: 'Homework',
        createdAt: now,
        updatedAt: now,
      );
      final b = Task(
        id: '1',
        title: 'Homework',
        createdAt: now,
        updatedAt: now,
      );
      expect(a, equals(b));
    });

    test('copyWith preserves subtasks', () {
      final task = Task(
        id: '1',
        title: 'Homework',
        subtasks: const [SubTask(id: 's1', title: 'Part A')],
        createdAt: now,
        updatedAt: now,
      );
      final updated = task.copyWith(title: 'Updated');
      expect(updated.subtasks.length, 1);
      expect(updated.subtasks.first.title, 'Part A');
    });

    test('default values', () {
      final task = Task(
        id: '1',
        title: 'Test',
        createdAt: now,
        updatedAt: now,
      );
      expect(task.isDone, false);
      expect(task.priority, Priority.medium);
      expect(task.subtasks, isEmpty);
    });
  });

  group('SubTask', () {
    test('equality', () {
      const a = SubTask(id: '1', title: 'A');
      const b = SubTask(id: '1', title: 'A');
      expect(a, equals(b));
    });

    test('copyWith', () {
      const sub = SubTask(id: '1', title: 'A');
      final updated = sub.copyWith(isDone: true);
      expect(updated.isDone, true);
      expect(updated.title, 'A');
    });
  });

  group('Reminder', () {
    test('equality', () {
      final a = Reminder(
        id: '1',
        title: 'Class',
        scheduledAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final b = Reminder(
        id: '1',
        title: 'Class',
        scheduledAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(a, equals(b));
    });

    test('default values', () {
      final r = Reminder(
        id: '1',
        title: 'Test',
        scheduledAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(r.isActive, true);
      expect(r.type, ReminderType.custom);
    });
  });
}
