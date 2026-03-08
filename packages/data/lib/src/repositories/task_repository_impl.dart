import 'package:domain/domain.dart' as domain;
import 'package:rxdart/rxdart.dart';

import '../database/daos/task_dao.dart';
import '../mappers/task_mapper.dart';

class TaskRepositoryImpl implements domain.TaskRepository {
  final TaskDao _dao;

  const TaskRepositoryImpl(this._dao);

  @override
  Stream<List<domain.Task>> watchAll() {
    return _dao.watchAll().switchMap((taskRows) {
      if (taskRows.isEmpty) return Stream.value(<domain.Task>[]);
      final streams = taskRows.map((row) {
        return _dao.watchSubTasksByTaskId(row.id).map((subRows) {
          return row.toDomain(
            subtasks: subRows.map((s) => s.toDomain()).toList(),
          );
        });
      });
      return Rx.combineLatestList(streams);
    });
  }

  @override
  Stream<List<domain.Task>> watchByDueDate(DateTime date) {
    return _dao.watchByDueDate(date).switchMap((taskRows) {
      if (taskRows.isEmpty) return Stream.value(<domain.Task>[]);
      final streams = taskRows.map((row) {
        return _dao.watchSubTasksByTaskId(row.id).map((subRows) {
          return row.toDomain(
            subtasks: subRows.map((s) => s.toDomain()).toList(),
          );
        });
      });
      return Rx.combineLatestList(streams);
    });
  }

  @override
  Future<domain.Task?> findById(String id) async {
    final row = await _dao.findById(id);
    if (row == null) return null;
    final subRows = await _dao.findSubTasksByTaskId(id);
    return row.toDomain(
      subtasks: subRows.map((s) => s.toDomain()).toList(),
    );
  }

  @override
  Future<void> save(domain.Task task) async {
    await _dao.upsertWithSubTasks(
      task.toCompanion(),
      task.id,
      task.subtasks.map((s) => s.toCompanion(task.id)).toList(),
    );
  }

  @override
  Future<void> delete(String id) => _dao.deleteById(id);

  @override
  Future<void> markDone(String id, {required bool done}) =>
      _dao.markDone(id, done: done);
}
