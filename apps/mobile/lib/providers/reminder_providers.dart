import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'notification_providers.dart';

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

/// Cancel all pending notifications and reschedule active future reminders.
/// Call after WebDAV restore or any bulk data change.
Future<void> rescheduleAllReminders(dynamic ref) async {
  final ns = ref.read(notificationServiceProvider) as NotificationService;
  final repo = ref.read(reminderRepositoryProvider) as ReminderRepository;

  await ns.cancelAll();

  final reminders = await repo.watchAll().first;
  final now = DateTime.now();
  for (final r in reminders) {
    if (r.isActive && r.scheduledAt.isAfter(now)) {
      await ns.schedule(r);
    }
  }
}
