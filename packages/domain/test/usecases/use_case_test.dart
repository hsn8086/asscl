import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:domain/domain.dart';

@GenerateMocks([CourseRepository, TaskRepository, ReminderRepository, NotificationService])
import 'use_case_test.mocks.dart';

void main() {
  final now = DateTime(2026, 3, 5);

  group('SaveCourseUseCase', () {
    late MockCourseRepository repo;
    late SaveCourseUseCase useCase;

    setUp(() {
      repo = MockCourseRepository();
      useCase = SaveCourseUseCase(repo);
    });

    test('calls repository.save', () async {
      final course = Course(
        id: '1',
        name: 'Math',
        weekday: 1,
        startPeriod: 1,
        endPeriod: 2,
        createdAt: now,
        updatedAt: now,
      );
      when(repo.save(course)).thenAnswer((_) async {});
      await useCase(course);
      verify(repo.save(course)).called(1);
    });
  });

  group('DeleteCourseUseCase', () {
    late MockCourseRepository repo;
    late DeleteCourseUseCase useCase;

    setUp(() {
      repo = MockCourseRepository();
      useCase = DeleteCourseUseCase(repo);
    });

    test('calls repository.delete', () async {
      when(repo.delete('1')).thenAnswer((_) async {});
      await useCase('1');
      verify(repo.delete('1')).called(1);
    });
  });

  group('WatchCoursesUseCase', () {
    late MockCourseRepository repo;
    late WatchCoursesUseCase useCase;

    setUp(() {
      repo = MockCourseRepository();
      useCase = WatchCoursesUseCase(repo);
    });

    test('returns repository.watchAll stream', () {
      when(repo.watchAll()).thenAnswer((_) => Stream.value([]));
      expect(useCase(), emits(isEmpty));
    });
  });

  group('SaveTaskUseCase', () {
    late MockTaskRepository repo;
    late SaveTaskUseCase useCase;

    setUp(() {
      repo = MockTaskRepository();
      useCase = SaveTaskUseCase(repo);
    });

    test('calls repository.save', () async {
      final task = Task(id: '1', title: 'HW', createdAt: now, updatedAt: now);
      when(repo.save(task)).thenAnswer((_) async {});
      await useCase(task);
      verify(repo.save(task)).called(1);
    });
  });

  group('MarkTaskDoneUseCase', () {
    late MockTaskRepository repo;
    late MarkTaskDoneUseCase useCase;

    setUp(() {
      repo = MockTaskRepository();
      useCase = MarkTaskDoneUseCase(repo);
    });

    test('calls repository.markDone', () async {
      when(repo.markDone('1', done: true)).thenAnswer((_) async {});
      await useCase('1', done: true);
      verify(repo.markDone('1', done: true)).called(1);
    });
  });

  group('SaveReminderUseCase', () {
    late MockReminderRepository repo;
    late MockNotificationService notif;
    late SaveReminderUseCase useCase;

    setUp(() {
      repo = MockReminderRepository();
      notif = MockNotificationService();
      useCase = SaveReminderUseCase(repo, notif);
    });

    test('saves and schedules active reminder', () async {
      final reminder = Reminder(
        id: '1',
        title: 'Class',
        scheduledAt: now,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      when(repo.save(reminder)).thenAnswer((_) async {});
      when(notif.schedule(reminder)).thenAnswer((_) async {});
      await useCase(reminder);
      verify(repo.save(reminder)).called(1);
      verify(notif.schedule(reminder)).called(1);
    });

    test('saves and cancels inactive reminder', () async {
      final reminder = Reminder(
        id: '1',
        title: 'Class',
        scheduledAt: now,
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );
      when(repo.save(reminder)).thenAnswer((_) async {});
      when(notif.cancel('1')).thenAnswer((_) async {});
      await useCase(reminder);
      verify(repo.save(reminder)).called(1);
      verify(notif.cancel('1')).called(1);
      verifyNever(notif.schedule(any));
    });
  });

  group('DeleteReminderUseCase', () {
    late MockReminderRepository repo;
    late MockNotificationService notif;
    late DeleteReminderUseCase useCase;

    setUp(() {
      repo = MockReminderRepository();
      notif = MockNotificationService();
      useCase = DeleteReminderUseCase(repo, notif);
    });

    test('cancels notification and deletes', () async {
      when(notif.cancel('1')).thenAnswer((_) async {});
      when(repo.delete('1')).thenAnswer((_) async {});
      await useCase('1');
      verify(notif.cancel('1')).called(1);
      verify(repo.delete('1')).called(1);
    });
  });
}
