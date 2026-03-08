import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'semester_providers.dart';

final viewTypeProvider = StateProvider<ViewType>((ref) => ViewType.weekGrid);

/// The week currently displayed in the UI. Initialized from the computed
/// current week, but can be manually changed by the user.
/// Resets automatically when the active semester changes.
final selectedWeekProvider =
    NotifierProvider<SelectedWeekNotifier, int>(SelectedWeekNotifier.new);

class SelectedWeekNotifier extends Notifier<int> {
  @override
  int build() {
    // Re-create (reset) whenever the active semester changes.
    ref.watch(activeSemesterIdProvider);
    listenSelf((_, next) {
      HomeWidget.saveWidgetData<int>('current_week', next);
    });
    return ref.read(currentWeekProvider);
  }

  // ignore: use_setters_to_change_properties
  void set(int week) => state = week;

  void increment() => state++;

  void decrement() => state--;
}
