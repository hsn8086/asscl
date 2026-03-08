import 'dart:developer' as dev;

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
    // Wait for both streams to emit at least one value to avoid race conditions
    // where semestersProvider hasn't loaded yet, causing empty semester name and
    // wrong week number.
    final activeId = await ref.read(activeSemesterIdProvider.future);
    final semesters = await ref.read(semestersProvider.future);
    final semester = activeId == null
        ? null
        : semesters.where((s) => s.id == activeId).firstOrNull;
    final week = semester?.currentWeek() ?? 1;
    await ref.read(widgetServiceProvider).updateWidgets(
          semesterName: semester?.name ?? '',
          semesterId: activeId,
          currentWeek: week,
        );
  } catch (e, st) {
    dev.log('refreshWidgets failed', error: e, stackTrace: st);
  }
}
