import '../../entities/reminder.dart';
import '../../repositories/reminder_repository.dart';

class WatchRemindersUseCase {
  final ReminderRepository _repository;

  const WatchRemindersUseCase(this._repository);

  Stream<List<Reminder>> call() => _repository.watchAll();
}
