import 'package:drift/drift.dart';

import 'tasks_table.dart';

class SubTasksTable extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(TasksTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
