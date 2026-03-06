import 'package:domain/domain.dart' as domain;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationServiceImpl implements domain.NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationServiceImpl(this._plugin);

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
      reminder.id.hashCode,
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
      _plugin.cancel(reminderId.hashCode);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
