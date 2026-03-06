import '../entities/reminder.dart';

abstract interface class NotificationService {
  Future<void> schedule(Reminder reminder);
  Future<void> cancel(String reminderId);
  Future<void> cancelAll();
}
