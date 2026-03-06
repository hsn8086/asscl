import 'package:domain/domain.dart' as domain;

import '../database/daos/semester_dao.dart';
import '../mappers/semester_mapper.dart';

class SemesterRepositoryImpl implements domain.SemesterRepository {
  final SemesterDao _dao;

  const SemesterRepositoryImpl(this._dao);

  @override
  Stream<List<domain.Semester>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<domain.Semester?> findById(String id) async {
    final row = await _dao.findById(id);
    return row?.toDomain();
  }

  @override
  Future<void> save(domain.Semester semester) =>
      _dao.upsert(semester.toCompanion());

  @override
  Future<void> delete(String id) => _dao.deleteById(id);
}
