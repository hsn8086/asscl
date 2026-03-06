import 'package:data/data.dart';
import 'package:domain/domain.dart';
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

  const TgBotConfig({
    required this.token,
    required this.chatId,
    this.notifyEnabled = false,
    this.agentEnabled = false,
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

  return TgBotConfig(
    token: token,
    chatId: chatId ?? '',
    notifyEnabled: notify == 'true',
    agentEnabled: agent == 'true',
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
final botAgentRelayProvider = Provider<BotAgentRelay>((ref) {
  final relay = BotAgentRelay(ref);
  final config = ref.watch(tgConfigProvider).valueOrNull;

  if (config != null && config.agentEnabled && config.isValid) {
    relay.start();
  }

  ref.onDispose(() => relay.stop());
  return relay;
});
