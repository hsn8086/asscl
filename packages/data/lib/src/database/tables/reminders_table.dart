import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

class RemindersTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get type => textEnum<domain.ReminderType>()();
  TextColumn get linkedEntityId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
