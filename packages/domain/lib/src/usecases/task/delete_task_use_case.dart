import '../../repositories/task_repository.dart';

class DeleteTaskUseCase {
  final TaskRepository _repository;

  const DeleteTaskUseCase(this._repository);

  Future<void> call(String id) => _repository.delete(id);
}
