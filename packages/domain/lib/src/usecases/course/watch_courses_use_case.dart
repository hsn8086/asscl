import '../../entities/course.dart';
import '../../repositories/course_repository.dart';

class WatchCoursesUseCase {
  final CourseRepository _repository;

  const WatchCoursesUseCase(this._repository);

  Stream<List<Course>> call() => _repository.watchAll();
}
