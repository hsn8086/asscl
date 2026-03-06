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
void refreshWidgets(dynamic ref) {
  // ref can be WidgetRef or Ref — both support read()
  final semester = ref.read(activeSemesterProvider);
  final week = ref.read(currentWeekProvider);
  ref.read(widgetServiceProvider).updateWidgets(
        semesterName: semester?.name ?? '',
        semesterId: semester?.id,
        currentWeek: week,
      );
}
