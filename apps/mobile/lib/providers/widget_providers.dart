import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/widget_service.dart';
import 'course_providers.dart';
import 'period_config_providers.dart';
import 'semester_providers.dart';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  final courseRepo = ref.watch(courseRepositoryProvider);
  final periodConfigRepo = ref.watch(periodConfigRepositoryProvider);
  return WidgetService(courseRepo, periodConfigRepo);
});

/// Convenience: read semester context and update widgets in one call.
///
/// Awaits [activeSemesterIdProvider] so the widget update is not fired before
/// the active semester has been resolved (which would cause all-semester data
/// to be pushed to the home-screen widget).
Future<void> refreshWidgets(dynamic ref) async {
  try {
    final activeId = await ref.read(activeSemesterIdProvider.future) as String?;
    final List<Semester> semesters =
        await ref.read(semestersProvider.future) as List<Semester>;
    Semester? semester;
    if (activeId != null) {
      for (final s in semesters) {
        if (s.id == activeId) {
          semester = s;
          break;
        }
      }
    }
    final week = semester?.currentWeek() ?? 1;
    debugPrint('[Widget] refreshWidgets: activeId=$activeId, '
        'semester=${semester?.name}, week=$week, '
        'semesters.length=${semesters.length}');
    await ref.read(widgetServiceProvider).updateWidgets(
          semesterName: semester?.name ?? '',
          semesterId: activeId,
          currentWeek: week,
        );
  } catch (e, st) {
    debugPrint('[Widget] refreshWidgets FAILED: $e\n$st');
  }
}
