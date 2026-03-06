import '../entities/task.dart';

abstract interface class TaskRepository {
  Stream<List<Task>> watchAll();
  Stream<List<Task>> watchByDueDate(DateTime date);
  Future<Task?> findById(String id);
  Future<void> save(Task task);
  Future<void> delete(String id);
  Future<void> markDone(String id, {required bool done});
}
