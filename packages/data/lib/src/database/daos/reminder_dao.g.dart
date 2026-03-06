// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_dao.dart';

// ignore_for_file: type=lint
mixin _$ReminderDaoMixin on DatabaseAccessor<AppDatabase> {
  $RemindersTableTable get remindersTable => attachedDatabase.remindersTable;
  ReminderDaoManager get managers => ReminderDaoManager(this);
}

class ReminderDaoManager {
  final _$ReminderDaoMixin _db;
  ReminderDaoManager(this._db);
  $$RemindersTableTableTableManager get remindersTable =>
      $$RemindersTableTableTableManager(
        _db.attachedDatabase,
        _db.remindersTable,
      );
}
