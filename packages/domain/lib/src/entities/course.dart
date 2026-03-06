import 'package:equatable/equatable.dart';

import '../enums/week_mode.dart';

class Course extends Equatable {
  final String id;
  final String name;
  final String? location;
  final String? teacher;
  final int weekday; // 1=Mon … 7=Sun
  final int startPeriod; // 1-based lesson slot
  final int endPeriod;
  final WeekMode weekMode;
  final List<int> customWeeks; // non-empty only when weekMode==custom
  final String? color; // hex color string
  final String? semesterId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.name,
    this.location,
    this.teacher,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    this.weekMode = WeekMode.every,
    this.customWeeks = const [],
    this.color,
    this.semesterId,
    required this.createdAt,
    required this.updatedAt,
  });

  Course copyWith({
    String? id,
    String? name,
    String? Function()? location,
    String? Function()? teacher,
    int? weekday,
    int? startPeriod,
    int? endPeriod,
    WeekMode? weekMode,
    List<int>? customWeeks,
    String? Function()? color,
    String? Function()? semesterId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location != null ? location() : this.location,
      teacher: teacher != null ? teacher() : this.teacher,
      weekday: weekday ?? this.weekday,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      weekMode: weekMode ?? this.weekMode,
      customWeeks: customWeeks ?? this.customWeeks,
      color: color != null ? color() : this.color,
      semesterId: semesterId != null ? semesterId() : this.semesterId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        location,
        teacher,
        weekday,
        startPeriod,
        endPeriod,
        weekMode,
        customWeeks,
        color,
        semesterId,
        createdAt,
        updatedAt,
      ];
}
