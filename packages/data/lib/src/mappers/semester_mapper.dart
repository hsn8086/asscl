import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

import '../database/app_database.dart';

extension SemesterRowToDomain on SemestersTableData {
  domain.Semester toDomain() => domain.Semester(
        id: id,
        name: name,
        startDate: startDate,
        totalWeeks: totalWeeks,
        createdAt: createdAt,
      );
}

extension SemesterDomainToCompanion on domain.Semester {
  SemestersTableCompanion toCompanion() => SemestersTableCompanion(
        id: Value(id),
        name: Value(name),
        startDate: Value(startDate),
        totalWeeks: Value(totalWeeks),
        createdAt: Value(createdAt),
      );
}
