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
  final bool isMultimodal;

  const VoiceConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    this.isMultimodal = false,
  });
}

/// Whether voice input is enabled.
final voiceEnabledProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final val = await SettingsDao(db).getValue('voiceEnabled');
  return val == 'true';
});

/// Voice mode: 'whisper' (default) or 'multimodal'.
final voiceModeProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final val = await SettingsDao(db).getValue('voiceMode');
  return val ?? 'whisper';
});

/// Voice configuration (endpoint, key, model).
/// Returns null if voice is disabled or not configured.
final voiceConfigProvider = FutureProvider<VoiceConfig?>((ref) async {
  final enabled = await ref.watch(voiceEnabledProvider.future);
  if (!enabled) return null;

  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final mode = await ref.watch(voiceModeProvider.future);
  final isMultimodal = mode == 'multimodal';

  final sameAsAgent = await dao.getValue('voiceSameAsAgent');
  final useSameAsAgent = sameAsAgent != 'false'; // default true

  if (isMultimodal) {
    // Multimodal mode: use chat completions endpoint with the main model.
    final aiConfig = ref.watch(aiConfigProvider).valueOrNull;
    if (aiConfig == null) return null;
    return VoiceConfig(
      endpoint: aiConfig.chatCompletionsUrl,
      apiKey: aiConfig.apiKey,
      model: aiConfig.modelName ?? 'gpt-4o-mini',
      isMultimodal: true,
    );
  }

  // Whisper mode: default model to 'whisper-1' if not set.
  final modelName = await dao.getValue('voiceModelName');
  final model = (modelName != null && modelName.isNotEmpty)
      ? modelName
      : 'whisper-1';

  if (useSameAsAgent) {
    final aiConfig = ref.watch(aiConfigProvider).valueOrNull;
    if (aiConfig == null) return null;
    return VoiceConfig(
      endpoint: '${aiConfig.baseUrl}/audio/transcriptions',
      apiKey: aiConfig.apiKey,
      model: model,
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
      model: model,
    );
  }
});

/// SttService instance — uses either Whisper API or multimodal chat.
final sttServiceProvider = Provider<SttService?>((ref) {
  final config = ref.watch(voiceConfigProvider).valueOrNull;
  if (config == null) return null;
  final client = ref.watch(httpClientProvider);

  if (config.isMultimodal) {
    return MultimodalSttServiceImpl(
      chatCompletionsUrl: config.endpoint,
      apiKey: config.apiKey,
      model: config.model,
      client: client,
    );
  }

  return SttServiceImpl(
    endpoint: config.endpoint,
    apiKey: config.apiKey,
    model: config.model,
    client: client,
  );
});
