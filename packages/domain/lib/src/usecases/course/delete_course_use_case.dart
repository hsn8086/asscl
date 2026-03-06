import '../../repositories/course_repository.dart';

class DeleteCourseUseCase {
  final CourseRepository _repository;

  const DeleteCourseUseCase(this._repository);

  Future<void> call(String id) => _repository.delete(id);
}
