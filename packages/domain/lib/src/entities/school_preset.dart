import 'period_time.dart';

class SchoolPreset {
  final String id;
  final String name;
  final int totalPeriods;
  final List<PeriodTime> periods;
  final String? aiPromptHint;

  const SchoolPreset({
    required this.id,
    required this.name,
    required this.totalPeriods,
    required this.periods,
    this.aiPromptHint,
  });
}
