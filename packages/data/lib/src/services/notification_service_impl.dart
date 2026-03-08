import 'package:domain/domain.dart' as domain;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationServiceImpl implements domain.NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationServiceImpl(this._plugin);

  /// Convert a UUID string to a stable 31-bit positive int for notification IDs.
  /// Uses FNV-1a hash for better distribution than String.hashCode.
  static int _stableId(String uuid) {
    var hash = 0x811c9dc5; // FNV offset basis
    for (var i = 0; i < uuid.length; i++) {
      hash ^= uuid.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF; // FNV prime, keep 31-bit positive
    }
    return hash;
  }

  @override
  Future<void> schedule(domain.Reminder reminder) async {
    const androidDetails = AndroidNotificationDetails(
      'asscl_reminders',
      'Reminders',
      channelDescription: 'Course and task reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      _stableId(reminder.id),
      reminder.title,
      reminder.body,
      tz.TZDateTime.from(reminder.scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(String reminderId) =>
      _plugin.cancel(_stableId(reminderId));

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
