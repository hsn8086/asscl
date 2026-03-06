import '../../repositories/reminder_repository.dart';
import '../../services/notification_service.dart';

class DeleteReminderUseCase {
  final ReminderRepository _repository;
  final NotificationService _notificationService;

  const DeleteReminderUseCase(this._repository, this._notificationService);

  Future<void> call(String id) async {
    await _notificationService.cancel(id);
    await _repository.delete(id);
  }
}
