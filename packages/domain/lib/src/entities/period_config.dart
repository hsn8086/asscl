import 'package:equatable/equatable.dart';

import 'period_time.dart';

class PeriodConfig extends Equatable {
  final int totalPeriods;
  final List<PeriodTime> periods; // sorted by periodNumber, can be empty
  final String? presetId;

  const PeriodConfig({
    this.totalPeriods = 12,
    this.periods = const [],
    this.presetId,
  });

  bool get hasTimeInfo => periods.isNotEmpty;

  PeriodTime? getTime(int periodNumber) {
    for (final p in periods) {
      if (p.periodNumber == periodNumber) return p;
    }
    return null;
  }

  /// Returns "08:00-09:45" style string, or null if times not configured.
  String? timeRangeString(int startPeriod, int endPeriod) {
    final start = getTime(startPeriod);
    final end = getTime(endPeriod);
    if (start == null || end == null) return null;
    return '${start.startTimeStr}-${end.endTimeStr}';
  }

  @override
  List<Object?> get props => [totalPeriods, periods, presetId];
}
