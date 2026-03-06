import 'package:domain/domain.dart' show PeriodTime;
import 'package:drift/drift.dart';

import '../database/app_database.dart';

extension PeriodTimeRowToDomain on PeriodTimesTableData {
  PeriodTime toDomain() => PeriodTime(
        periodNumber: periodNumber,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      );
}

extension PeriodTimeDomainToCompanion on PeriodTime {
  PeriodTimesTableCompanion toCompanion() => PeriodTimesTableCompanion(
        periodNumber: Value(periodNumber),
        startHour: Value(startHour),
        startMinute: Value(startMinute),
        endHour: Value(endHour),
        endMinute: Value(endMinute),
      );
}
