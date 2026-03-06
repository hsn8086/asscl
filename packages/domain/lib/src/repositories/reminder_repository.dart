import '../entities/reminder.dart';

abstract interface class ReminderRepository {
  Stream<List<Reminder>> watchAll();
  Future<Reminder?> findById(String id);
  Future<void> save(Reminder reminder);
  Future<void> delete(String id);
  Future<void> setActive(String id, {required bool active});
}
