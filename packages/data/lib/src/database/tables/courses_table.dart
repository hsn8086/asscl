import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

class CoursesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  TextColumn get teacher => text().nullable()();
  IntColumn get weekday => integer()();
  IntColumn get startPeriod => integer()();
  IntColumn get endPeriod => integer()();
  TextColumn get weekMode => textEnum<domain.WeekMode>()();
  TextColumn get customWeeks => text().withDefault(const Constant('[]'))();
  TextColumn get color => text().nullable()();
  TextColumn get semesterId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
