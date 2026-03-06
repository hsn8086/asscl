import '../entities/semester.dart';

abstract interface class SemesterRepository {
  Stream<List<Semester>> watchAll();
  Future<Semester?> findById(String id);
  Future<void> save(Semester semester);
  Future<void> delete(String id);
}
