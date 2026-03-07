import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app.dart';
import 'providers/notification_providers.dart';

@pragma('vm:entry-point')
Future<void> _homeWidgetBackgroundCallback(Uri? uri) async {
  // Called by the system when widget interaction occurs in the background.
  // Currently no interactive actions — data is pushed from the Dart side.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  HomeWidget.registerInteractivityCallback(_homeWidgetBackgroundCallback);

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
  );
  await notificationsPlugin.initialize(initSettings);

  // Request notification permission (Android 13+)
  if (Platform.isAndroid) {
    final androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  runApp(ProviderScope(
    overrides: [
      notificationPluginProvider.overrideWithValue(notificationsPlugin),
    ],
    child: const App(),
  ));
}
