import 'package:drift/drift.dart';

class SemestersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get totalWeeks => integer().withDefault(const Constant(20))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
