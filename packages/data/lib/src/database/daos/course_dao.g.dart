// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_dao.dart';

// ignore_for_file: type=lint
mixin _$CourseDaoMixin on DatabaseAccessor<AppDatabase> {
  $SemestersTableTable get semestersTable => attachedDatabase.semestersTable;
  $CoursesTableTable get coursesTable => attachedDatabase.coursesTable;
  CourseDaoManager get managers => CourseDaoManager(this);
}

class CourseDaoManager {
  final _$CourseDaoMixin _db;
  CourseDaoManager(this._db);
  $$SemestersTableTableTableManager get semestersTable =>
      $$SemestersTableTableTableManager(
        _db.attachedDatabase,
        _db.semestersTable,
      );
  $$CoursesTableTableTableManager get coursesTable =>
      $$CoursesTableTableTableManager(_db.attachedDatabase, _db.coursesTable);
}
