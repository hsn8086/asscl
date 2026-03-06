import '../../entities/course.dart';
import '../../repositories/course_repository.dart';

class SaveCourseUseCase {
  final CourseRepository _repository;

  const SaveCourseUseCase(this._repository);

  Future<void> call(Course course) => _repository.save(course);
}
