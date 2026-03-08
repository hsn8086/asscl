import 'package:equatable/equatable.dart';

class Semester extends Equatable {
  final String id;
  final String name;
  final DateTime startDate; // First Monday of the semester
  final int totalWeeks;
  final DateTime createdAt;

  const Semester({
    required this.id,
    required this.name,
    required this.startDate,
    this.totalWeeks = 20,
    required this.createdAt,
  });

  /// Calculate the current week number based on today's date.
  /// Returns a value clamped to [1, totalWeeks].
  int currentWeek([DateTime? now]) {
    final today = now ?? DateTime.now();
    final daysDiff = today.difference(startDate).inDays;
    final week = (daysDiff ~/ 7) + 1;
    return week.clamp(1, totalWeeks);
  }

  /// Whether [now] is before the semester start date.
  bool hasStarted([DateTime? now]) {
    final today = now ?? DateTime.now();
    return !today.isBefore(startDate);
  }

  /// Whether [now] is after the last day of the semester.
  bool hasEnded([DateTime? now]) {
    final today = now ?? DateTime.now();
    final endDate = startDate.add(Duration(days: totalWeeks * 7));
    return today.isAfter(endDate);
  }

  @override
  List<Object?> get props => [id, name, startDate, totalWeeks, createdAt];
}
