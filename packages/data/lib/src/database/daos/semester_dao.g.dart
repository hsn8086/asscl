// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'semester_dao.dart';

// ignore_for_file: type=lint
mixin _$SemesterDaoMixin on DatabaseAccessor<AppDatabase> {
  $SemestersTableTable get semestersTable => attachedDatabase.semestersTable;
  SemesterDaoManager get managers => SemesterDaoManager(this);
}

class SemesterDaoManager {
  final _$SemesterDaoMixin _db;
  SemesterDaoManager(this._db);
  $$SemestersTableTableTableManager get semestersTable =>
      $$SemestersTableTableTableManager(
        _db.attachedDatabase,
        _db.semestersTable,
      );
}
