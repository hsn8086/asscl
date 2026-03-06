import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/courses_table.dart';

part 'course_dao.g.dart';

@DriftAccessor(tables: [CoursesTable])
class CourseDao extends DatabaseAccessor<AppDatabase> with _$CourseDaoMixin {
  CourseDao(super.db);

  Stream<List<CoursesTableData>> watchAll() => select(coursesTable).watch();

  Future<CoursesTableData?> findById(String id) =>
      (select(coursesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(CoursesTableCompanion entry) =>
      into(coursesTable).insertOnConflictUpdate(entry);

  Future<void> deleteById(String id) =>
      (delete(coursesTable)..where((t) => t.id.equals(id))).go();
}
