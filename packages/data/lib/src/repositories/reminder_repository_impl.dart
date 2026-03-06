import 'package:domain/domain.dart' as domain;

import '../database/daos/reminder_dao.dart';
import '../mappers/reminder_mapper.dart';

class ReminderRepositoryImpl implements domain.ReminderRepository {
  final ReminderDao _dao;

  const ReminderRepositoryImpl(this._dao);

  @override
  Stream<List<domain.Reminder>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<domain.Reminder?> findById(String id) async {
    final row = await _dao.findById(id);
    return row?.toDomain();
  }

  @override
  Future<void> save(domain.Reminder reminder) =>
      _dao.upsert(reminder.toCompanion());

  @override
  Future<void> delete(String id) => _dao.deleteById(id);

  @override
  Future<void> setActive(String id, {required bool active}) =>
      _dao.setActive(id, active: active);
}
