import 'dart:io';

import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'database_provider.dart';
import 'proxy_providers.dart';

final aiConfigProvider = FutureProvider<AiImportConfig?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final endpoint = await dao.getValue('aiApiEndpoint');
  final key = await dao.getValue('aiApiKey');
  if (endpoint == null || key == null) return null;
  final model = await dao.getValue('aiModelName');
  return AiImportConfig(apiEndpoint: endpoint, apiKey: key, modelName: model);
});

final aiImportServiceProvider = Provider<AiImportService?>((ref) {
  final config = ref.watch(aiConfigProvider).valueOrNull;
  if (config == null) return null;
  final client = ref.watch(httpClientProvider);
  return AiImportServiceImpl(config: config, client: client);
});

/// Provides an AiAgentService that persists across navigation.
/// Cached: only recreates if the config values actually change.
AiAgentService? _cachedAgent;
AiImportConfig? _lastAgentConfig;
http.Client? _lastAgentClient;

final aiAgentServiceProvider = Provider<AiAgentService?>((ref) {
  final config = ref.watch(aiConfigProvider).valueOrNull;
  final client = ref.watch(httpClientProvider);
  if (config == null) {
    // Config cleared — drop stale cached agent to prevent state pollution.
    _cachedAgent = null;
    _lastAgentConfig = null;
    _lastAgentClient = null;
    return null;
  }
  if (_cachedAgent != null &&
      _lastAgentConfig == config &&
      _lastAgentClient == client) {
    return _cachedAgent;
  }
  _lastAgentConfig = config;
  _lastAgentClient = client;
  _cachedAgent = AiAgentServiceImpl(
    config: config,
    client: client,
    clientFactory: () {
      final proxy = ref.read(proxyConfigProvider).valueOrNull;
      if (proxy != null && proxy.isValid) {
        final ioClient = HttpClient()..findProxy = (uri) => proxy.proxyUrl;
        return IOClient(ioClient);
      }
      return http.Client();
    },
  );
  return _cachedAgent;
});

/// ChatSessionDao provider.
final chatSessionDaoProvider = Provider<ChatSessionDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatSessionDao(db);
});

/// Current chat session ID (null = new session).
final currentChatSessionIdProvider = StateProvider<String?>((ref) => null);

/// Watch all saved chat sessions.
final chatSessionsProvider = StreamProvider<List<ChatSessionsTableData>>((ref) {
  final dao = ref.watch(chatSessionDaoProvider);
  return dao.watchAllSessions();
});

/// "Enter to send" setting.
final enterToSendProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final value = await dao.getValue('enterToSend');
  return value == 'true';
});
