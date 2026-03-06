import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/bot_agent_relay.dart';
import 'database_provider.dart';

/// Telegram bot configuration read from SettingsDao.
class TgBotConfig {
  final String token;
  final String chatId;
  final bool notifyEnabled;
  final bool agentEnabled;
  final bool keepAlive;

  const TgBotConfig({
    required this.token,
    required this.chatId,
    this.notifyEnabled = false,
    this.agentEnabled = false,
    this.keepAlive = false,
  });

  bool get isValid => token.isNotEmpty && chatId.isNotEmpty;
}

/// Reads Telegram bot settings from the database.
final tgConfigProvider = FutureProvider<TgBotConfig?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final enabled = await dao.getValue('tgEnabled');
  if (enabled != 'true') return null;

  final token = await dao.getValue('tgBotToken');
  final chatId = await dao.getValue('tgChatId');
  if (token == null || token.isEmpty) return null;

  final notify = await dao.getValue('tgNotifyEnabled');
  final agent = await dao.getValue('tgAgentEnabled');
  final keepAlive = await dao.getValue('tgKeepAlive');

  return TgBotConfig(
    token: token,
    chatId: chatId ?? '',
    notifyEnabled: notify == 'true',
    agentEnabled: agent == 'true',
    keepAlive: keepAlive == 'true',
  );
});

/// Provides a [TelegramBotService] if config is valid, null otherwise.
final telegramBotServiceProvider = Provider<TelegramBotService?>((ref) {
  final config = ref.watch(tgConfigProvider).valueOrNull;
  if (config == null || !config.isValid) return null;
  return TelegramBotService(token: config.token);
});

/// Forward a reminder to Telegram if notification forwarding is enabled.
/// Silently does nothing if TG is not configured or notify is off.
Future<void> forwardReminderToTg(dynamic ref, Reminder reminder) async {
  final config = ref.read(tgConfigProvider).valueOrNull as TgBotConfig?;
  if (config == null || !config.notifyEnabled) return;
  final bot = ref.read(telegramBotServiceProvider) as TelegramBotService?;
  if (bot == null) return;

  final df = DateFormat('yyyy-MM-dd HH:mm');
  final text = '🔔 *提醒已设置*\n'
      '*${reminder.title}*\n'
      '${reminder.body ?? ''}\n'
      '⏰ ${df.format(reminder.scheduledAt)}';

  try {
    await bot.sendMessage(config.chatId, text.trim());
  } catch (_) {
    // Non-critical — don't break the save flow.
  }
}

/// Manages the [BotAgentRelay] lifecycle.
/// Starts polling when TG agent is enabled, stops when disabled.
/// When keepAlive is enabled, starts an Android foreground service.
final botAgentRelayProvider = Provider<BotAgentRelay>((ref) {
  final relay = BotAgentRelay(ref);
  final config = ref.watch(tgConfigProvider).valueOrNull;

  if (config != null && config.agentEnabled && config.isValid) {
    relay.start();
    if (config.keepAlive) {
      _startForegroundService();
    } else {
      _stopForegroundService();
    }
  } else {
    _stopForegroundService();
  }

  ref.onDispose(() {
    relay.stop();
    _stopForegroundService();
  });
  return relay;
});

// ── Foreground service helpers ──

bool _foregroundInitialized = false;

void initForegroundTask() {
  if (_foregroundInitialized) return;
  _foregroundInitialized = true;
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'tg_bot_keep_alive',
      channelName: 'Bot 保活',
      channelDescription: 'Telegram Bot 后台轮询服务',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      playSound: false,
      showBadge: false,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> _startForegroundService() async {
  initForegroundTask();
  if (await FlutterForegroundTask.isRunningService) return;
  await FlutterForegroundTask.startService(
    serviceId: 888,
    notificationTitle: 'Bot 运行中',
    notificationText: 'Telegram Bot 正在后台监听消息',
  );
}

Future<void> _stopForegroundService() async {
  if (!_foregroundInitialized) return;
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}
