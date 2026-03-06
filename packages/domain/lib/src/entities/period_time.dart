import 'package:equatable/equatable.dart';

class PeriodTime extends Equatable {
  final int periodNumber; // 1-based
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const PeriodTime({
    required this.periodNumber,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get startTimeStr =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';

  String get endTimeStr =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props =>
      [periodNumber, startHour, startMinute, endHour, endMinute];
}
