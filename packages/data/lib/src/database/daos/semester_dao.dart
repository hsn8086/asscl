import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/semesters_table.dart';

part 'semester_dao.g.dart';

@DriftAccessor(tables: [SemestersTable])
class SemesterDao extends DatabaseAccessor<AppDatabase>
    with _$SemesterDaoMixin {
  SemesterDao(super.db);

  Stream<List<SemestersTableData>> watchAll() =>
      (select(semestersTable)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<SemestersTableData?> findById(String id) =>
      (select(semestersTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsert(SemestersTableCompanion entry) =>
      into(semestersTable).insertOnConflictUpdate(entry);

  Future<void> deleteById(String id) =>
      (delete(semestersTable)..where((t) => t.id.equals(id))).go();
}
