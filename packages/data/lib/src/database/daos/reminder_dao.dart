import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reminders_table.dart';

part 'reminder_dao.g.dart';

@DriftAccessor(tables: [RemindersTable])
class ReminderDao extends DatabaseAccessor<AppDatabase>
    with _$ReminderDaoMixin {
  ReminderDao(super.db);

  Stream<List<RemindersTableData>> watchAll() =>
      select(remindersTable).watch();

  Future<RemindersTableData?> findById(String id) =>
      (select(remindersTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsert(RemindersTableCompanion entry) =>
      into(remindersTable).insertOnConflictUpdate(entry);

  Future<void> deleteById(String id) =>
      (delete(remindersTable)..where((t) => t.id.equals(id))).go();

  Future<void> setActive(String id, {required bool active}) =>
      (update(remindersTable)..where((t) => t.id.equals(id))).write(
          RemindersTableCompanion(
              isActive: Value(active), updatedAt: Value(DateTime.now())));
}
