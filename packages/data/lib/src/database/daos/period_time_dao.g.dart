// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_time_dao.dart';

// ignore_for_file: type=lint
mixin _$PeriodTimeDaoMixin on DatabaseAccessor<AppDatabase> {
  $PeriodTimesTableTable get periodTimesTable =>
      attachedDatabase.periodTimesTable;
  PeriodTimeDaoManager get managers => PeriodTimeDaoManager(this);
}

class PeriodTimeDaoManager {
  final _$PeriodTimeDaoMixin _db;
  PeriodTimeDaoManager(this._db);
  $$PeriodTimesTableTableTableManager get periodTimesTable =>
      $$PeriodTimesTableTableTableManager(
        _db.attachedDatabase,
        _db.periodTimesTable,
      );
}
