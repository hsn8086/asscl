import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'semester_providers.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CourseRepositoryImpl(CourseDao(db));
});

/// Courses filtered by the active semester.
/// Waits for activeSemesterId to resolve before emitting,
/// to avoid briefly flashing all courses.
final watchCoursesProvider = StreamProvider<List<Course>>((ref) async* {
  final activeId = await ref.watch(activeSemesterIdProvider.future);
  yield* ref.watch(courseRepositoryProvider).watchAll().map((courses) {
    if (activeId == null) return courses;
    return courses.where((c) => c.semesterId == activeId).toList();
  });
});

final courseDetailProvider =
    FutureProvider.family<Course?, String>((ref, id) {
  return ref.watch(courseRepositoryProvider).findById(id);
});
