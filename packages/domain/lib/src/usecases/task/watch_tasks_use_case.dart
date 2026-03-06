import '../../entities/task.dart';
import '../../repositories/task_repository.dart';

class WatchTasksUseCase {
  final TaskRepository _repository;

  const WatchTasksUseCase(this._repository);

  Stream<List<Task>> call() => _repository.watchAll();
}
