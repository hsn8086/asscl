import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tasks_table.dart';
import '../tables/sub_tasks_table.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [TasksTable, SubTasksTable])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  Stream<List<TasksTableData>> watchAll() => select(tasksTable).watch();

  Stream<List<TasksTableData>> watchByDueDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(tasksTable)
          ..where(
              (t) => t.dueDate.isBiggerOrEqualValue(start) & t.dueDate.isSmallerThanValue(end)))
        .watch();
  }

  Future<TasksTableData?> findById(String id) =>
      (select(tasksTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(TasksTableCompanion entry) =>
      into(tasksTable).insertOnConflictUpdate(entry);

  Future<void> deleteById(String id) =>
      (delete(tasksTable)..where((t) => t.id.equals(id))).go();

  Future<void> markDone(String id, {required bool done}) =>
      (update(tasksTable)..where((t) => t.id.equals(id)))
          .write(TasksTableCompanion(isDone: Value(done), updatedAt: Value(DateTime.now())));

  // SubTask operations
  Future<List<SubTasksTableData>> findSubTasksByTaskId(String taskId) =>
      (select(subTasksTable)..where((t) => t.taskId.equals(taskId))).get();

  Stream<List<SubTasksTableData>> watchSubTasksByTaskId(String taskId) =>
      (select(subTasksTable)..where((t) => t.taskId.equals(taskId))).watch();

  Future<void> upsertSubTask(SubTasksTableCompanion entry) =>
      into(subTasksTable).insertOnConflictUpdate(entry);

  Future<void> deleteSubTasksByTaskId(String taskId) =>
      (delete(subTasksTable)..where((t) => t.taskId.equals(taskId))).go();

  Future<void> replaceSubTasks(
      String taskId, List<SubTasksTableCompanion> entries) async {
    await transaction(() async {
      await deleteSubTasksByTaskId(taskId);
      for (final entry in entries) {
        await into(subTasksTable).insert(entry);
      }
    });
  }
}
