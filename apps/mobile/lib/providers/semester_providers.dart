import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

final semesterRepositoryProvider = Provider<SemesterRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SemesterRepositoryImpl(SemesterDao(db));
});

final semestersProvider = StreamProvider<List<Semester>>((ref) {
  return ref.watch(semesterRepositoryProvider).watchAll();
});

final activeSemesterIdProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SettingsDao(db).watchValue('activeSemesterId');
});

final activeSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? [];
  final activeId = ref.watch(activeSemesterIdProvider).valueOrNull;
  if (activeId == null || semesters.isEmpty) return null;
  return semesters.where((s) => s.id == activeId).firstOrNull;
});

/// The "real" current week based on semester start date.
final currentWeekProvider = Provider<int>((ref) {
  final semester = ref.watch(activeSemesterProvider);
  if (semester == null) return 1;
  return semester.currentWeek();
});
