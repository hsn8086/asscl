// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTableTable get tasksTable => attachedDatabase.tasksTable;
  $SubTasksTableTable get subTasksTable => attachedDatabase.subTasksTable;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
  $$TasksTableTableTableManager get tasksTable =>
      $$TasksTableTableTableManager(_db.attachedDatabase, _db.tasksTable);
  $$SubTasksTableTableTableManager get subTasksTable =>
      $$SubTasksTableTableTableManager(_db.attachedDatabase, _db.subTasksTable);
}
