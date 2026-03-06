import '../entities/course.dart';

abstract interface class CourseRepository {
  Stream<List<Course>> watchAll();
  Future<Course?> findById(String id);
  Future<void> save(Course course);
  Future<void> delete(String id);
}
