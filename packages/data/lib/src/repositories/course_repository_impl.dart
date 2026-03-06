import 'package:domain/domain.dart' as domain;

import '../database/daos/course_dao.dart';
import '../mappers/course_mapper.dart';

class CourseRepositoryImpl implements domain.CourseRepository {
  final CourseDao _dao;

  const CourseRepositoryImpl(this._dao);

  @override
  Stream<List<domain.Course>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<domain.Course?> findById(String id) async {
    final row = await _dao.findById(id);
    return row?.toDomain();
  }

  @override
  Future<void> save(domain.Course course) => _dao.upsert(course.toCompanion());

  @override
  Future<void> delete(String id) => _dao.deleteById(id);
}
