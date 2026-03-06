import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReminderRepositoryImpl(ReminderDao(db));
});

final watchRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchAll();
});

final reminderDetailProvider =
    FutureProvider.family<Reminder?, String>((ref, id) {
  return ref.watch(reminderRepositoryProvider).findById(id);
});
