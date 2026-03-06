import '../../entities/task.dart';
import '../../repositories/task_repository.dart';

class SaveTaskUseCase {
  final TaskRepository _repository;

  const SaveTaskUseCase(this._repository);

  Future<void> call(Task task) => _repository.save(task);
}
