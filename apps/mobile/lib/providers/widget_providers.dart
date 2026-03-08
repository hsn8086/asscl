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
    final activeId = await ref.read(activeSemesterIdProvider.future);
    final semesters = await ref.read(semestersProvider.future);
    final semester = activeId == null
        ? null
        : semesters.where((s) => s.id == activeId).firstOrNull;
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
