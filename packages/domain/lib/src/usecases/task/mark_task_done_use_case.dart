import '../../repositories/task_repository.dart';

class MarkTaskDoneUseCase {
  final TaskRepository _repository;

  const MarkTaskDoneUseCase(this._repository);

  Future<void> call(String id, {required bool done}) =>
      _repository.markDone(id, done: done);
}
