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
  // Wait for the semester stream to emit at least one value.
  final activeId = await ref.read(activeSemesterIdProvider.future);
  final semesters = ref.read(semestersProvider).valueOrNull ?? [];
  final semester = activeId == null
      ? null
      : semesters.where((s) => s.id == activeId).firstOrNull;
  final week = ref.read(currentWeekProvider);
  ref.read(widgetServiceProvider).updateWidgets(
        semesterName: semester?.name ?? '',
        semesterId: activeId,
        currentWeek: week,
      );
}
