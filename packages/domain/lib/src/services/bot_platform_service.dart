/// Abstract bot platform interface.
///
/// Each messaging platform (Telegram, Discord, etc.) implements this
/// interface so the rest of the app can be platform-agnostic.
abstract interface class BotPlatformService {
  /// Send a complete text message.
  Future<void> sendMessage(String chatId, String text);

  /// Send a message with streaming (platform-native streaming if supported).
  /// [textStream] yields incremental text deltas.
  Future<void> sendMessageStreaming(String chatId, Stream<String> textStream);

  /// Long-poll for incoming messages.
  Stream<BotIncomingMessage> pollMessages();

  /// Test whether the current config is valid.
  Future<BotConnectionStatus> testConnection();

  /// Stop any active polling.
  void stopPolling();
}

/// A message received from the bot platform.
class BotIncomingMessage {
  final String chatId;
  final String? senderId;
  final String chatType;
  final int messageId;
  final String text;

  const BotIncomingMessage({
    required this.chatId,
    this.senderId,
    this.chatType = 'private',
    required this.messageId,
    required this.text,
  });
}

/// Result of a connection test.
class BotConnectionStatus {
  final bool ok;
  final String? botUsername;
  final String? error;

  const BotConnectionStatus({required this.ok, this.botUsername, this.error});

  const BotConnectionStatus.success(String username)
      : ok = true,
        botUsername = username,
        error = null;

  const BotConnectionStatus.failure(String message)
      : ok = false,
        botUsername = null,
        error = message;
}
