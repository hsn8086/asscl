import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

import '../database/app_database.dart';

extension CourseRowToDomain on CoursesTableData {
  domain.Course toDomain() => domain.Course(
        id: id,
        name: name,
        location: location,
        teacher: teacher,
        weekday: weekday,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
        weekMode: weekMode,
        customWeeks:
            (jsonDecode(customWeeks) as List).map((e) => e as int).toList(),
        color: color,
        semesterId: semesterId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension CourseDomainToCompanion on domain.Course {
  CoursesTableCompanion toCompanion() => CoursesTableCompanion(
        id: Value(id),
        name: Value(name),
        location: Value(location),
        teacher: Value(teacher),
        weekday: Value(weekday),
        startPeriod: Value(startPeriod),
        endPeriod: Value(endPeriod),
        weekMode: Value(weekMode),
        customWeeks: Value(jsonEncode(customWeeks)),
        color: Value(color),
        semesterId: Value(semesterId),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      );
}
