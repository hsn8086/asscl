import '../enums/week_mode.dart';

class AiParsedCourse {
  final String name;
  final String? location;
  final String? teacher;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final WeekMode weekMode;
  final List<int> customWeeks;

  const AiParsedCourse({
    required this.name,
    this.location,
    this.teacher,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    this.weekMode = WeekMode.every,
    this.customWeeks = const [],
  });
}
