import '../../entities/reminder.dart';
import '../../repositories/reminder_repository.dart';
import '../../services/notification_service.dart';

class SaveReminderUseCase {
  final ReminderRepository _repository;
  final NotificationService _notificationService;

  const SaveReminderUseCase(this._repository, this._notificationService);

  Future<void> call(Reminder reminder) async {
    await _repository.save(reminder);
    if (reminder.isActive) {
      await _notificationService.schedule(reminder);
    } else {
      await _notificationService.cancel(reminder.id);
    }
  }
}
