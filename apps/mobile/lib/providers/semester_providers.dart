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

final activeSemesterIdProvider = StreamProvider<String?>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);

  await for (final id in dao.watchValue('activeSemesterId')) {
    if (id != null) {
      yield id;
    } else {
      // No active semester set — auto-select the first available one.
      final semesters = await ref.read(semesterRepositoryProvider).watchAll().first;
      if (semesters.isNotEmpty) {
        final firstId = semesters.first.id;
        await dao.setValue('activeSemesterId', firstId);
        yield firstId;
      } else {
        yield null;
      }
    }
  }
});

final activeSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? [];
  final activeId = ref.watch(activeSemesterIdProvider).valueOrNull;
  if (activeId == null || semesters.isEmpty) return null;
  for (final s in semesters) {
    if (s.id == activeId) return s;
  }
  return null;
});

/// The "real" current week based on semester start date.
final currentWeekProvider = Provider<int>((ref) {
  final semester = ref.watch(activeSemesterProvider);
  if (semester == null) return 1;
  return semester.currentWeek();
});
