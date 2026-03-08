import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'semester_providers.dart';

final viewTypeProvider = StateProvider<ViewType>((ref) => ViewType.weekGrid);

/// The week currently displayed in the UI. Initialized from the computed
/// current week, but can be manually changed by the user.
/// Resets automatically when the active semester changes.
final selectedWeekProvider = StateProvider<int>((ref) {
  // Re-create (reset) whenever the active semester changes.
  ref.watch(activeSemesterIdProvider);
  ref.listenSelf((_, next) {
    HomeWidget.saveWidgetData<int>('current_week', next);
  });
  return ref.read(currentWeekProvider);
});
