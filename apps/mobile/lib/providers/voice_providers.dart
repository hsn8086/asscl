import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_providers.dart';
import 'database_provider.dart';
import 'proxy_providers.dart';

/// Voice input configuration.
class VoiceConfig {
  final String endpoint;
  final String apiKey;
  final String model;

  const VoiceConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });
}

/// Whether voice input is enabled.
final voiceEnabledProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final val = await SettingsDao(db).getValue('voiceEnabled');
  return val == 'true';
});

/// Voice configuration (endpoint, key, model).
/// Returns null if voice is disabled or not configured.
final voiceConfigProvider = FutureProvider<VoiceConfig?>((ref) async {
  final enabled = await ref.watch(voiceEnabledProvider.future);
  if (!enabled) return null;

  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);

  final sameAsAgent = await dao.getValue('voiceSameAsAgent');
  final modelName = await dao.getValue('voiceModelName');
  if (modelName == null || modelName.isEmpty) return null;

  if (sameAsAgent == 'true') {
    // Derive from agent config.
    final aiConfig = ref.watch(aiConfigProvider).valueOrNull;
    if (aiConfig == null) return null;
    final endpoint = deriveTranscriptionUrl(aiConfig.apiEndpoint);
    return VoiceConfig(
      endpoint: endpoint,
      apiKey: aiConfig.apiKey,
      model: modelName,
    );
  } else {
    final endpoint = await dao.getValue('voiceApiEndpoint');
    final apiKey = await dao.getValue('voiceApiKey');
    if (endpoint == null || endpoint.isEmpty ||
        apiKey == null || apiKey.isEmpty) {
      return null;
    }
    return VoiceConfig(
      endpoint: endpoint,
      apiKey: apiKey,
      model: modelName,
    );
  }
});

/// SttService instance.
final sttServiceProvider = Provider<SttService?>((ref) {
  final config = ref.watch(voiceConfigProvider).valueOrNull;
  if (config == null) return null;
  final client = ref.watch(httpClientProvider);
  return SttServiceImpl(
    endpoint: config.endpoint,
    apiKey: config.apiKey,
    model: config.model,
    client: client,
  );
});

/// Derive the transcription URL from a chat completions URL.
///
/// E.g. `https://api.openai.com/v1/chat/completions`
///    → `https://api.openai.com/v1/audio/transcriptions`
String deriveTranscriptionUrl(String chatEndpoint) {
  final v1Idx = chatEndpoint.indexOf('/v1/');
  if (v1Idx == -1) return chatEndpoint;
  return '${chatEndpoint.substring(0, v1Idx)}/v1/audio/transcriptions';
}
