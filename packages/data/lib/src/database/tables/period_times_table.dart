import 'package:drift/drift.dart';

class PeriodTimesTable extends Table {
  IntColumn get periodNumber => integer()();
  IntColumn get startHour => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endHour => integer()();
  IntColumn get endMinute => integer()();

  @override
  Set<Column> get primaryKey => {periodNumber};
}
