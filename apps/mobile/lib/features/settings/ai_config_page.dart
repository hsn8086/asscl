import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/voice_providers.dart';

class AiConfigPage extends ConsumerStatefulWidget {
  const AiConfigPage({super.key});

  @override
  ConsumerState<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends ConsumerState<AiConfigPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  // Voice settings
  final _voiceEndpointController = TextEditingController();
  final _voiceApiKeyController = TextEditingController();
  final _voiceModelController = TextEditingController();
  bool _voiceEnabled = false;
  bool _voiceSameAsAgent = true;
  String _voiceMode = 'whisper'; // 'whisper' or 'multimodal'

  bool _isLoaded = false;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _voiceEndpointController.dispose();
    _voiceApiKeyController.dispose();
    _voiceModelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);

    // Read base URL (or migrate from legacy key).
    var baseUrl = await dao.getValue('aiBaseUrl');
    if (baseUrl == null) {
      final legacy = await dao.getValue('aiApiEndpoint');
      if (legacy != null) {
        baseUrl = extractBaseUrl(legacy);
      }
    }

    final key = await dao.getValue('aiApiKey');
    final model = await dao.getValue('aiModelName');

    // Voice settings
    final voiceEnabled = await dao.getValue('voiceEnabled');
    final voiceSameAsAgent = await dao.getValue('voiceSameAsAgent');
    final voiceMode = await dao.getValue('voiceMode');
    final voiceEndpoint = await dao.getValue('voiceApiEndpoint');
    final voiceKey = await dao.getValue('voiceApiKey');
    final voiceModel = await dao.getValue('voiceModelName');

    if (mounted) {
      setState(() {
        _baseUrlController.text = baseUrl ?? '';
        _apiKeyController.text = key ?? '';
        _modelController.text = model ?? '';
        _voiceEnabled = voiceEnabled == 'true';
        _voiceSameAsAgent = voiceSameAsAgent != 'false'; // default true
        _voiceMode = voiceMode ?? 'whisper';
        _voiceEndpointController.text = voiceEndpoint ?? '';
        _voiceApiKeyController.text = voiceKey ?? '';
        _voiceModelController.text = voiceModel ?? '';
      });
    }
  }

  Future<void> _toggleVoiceEnabled(bool value) async {
    setState(() => _voiceEnabled = value);
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).setValue('voiceEnabled', value.toString());
    ref.invalidate(voiceEnabledProvider);
    ref.invalidate(voiceConfigProvider);
  }

  Future<void> _toggleVoiceSameAsAgent(bool value) async {
    setState(() => _voiceSameAsAgent = value);
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).setValue('voiceSameAsAgent', value.toString());
    ref.invalidate(voiceConfigProvider);
  }

  Future<void> _setVoiceMode(String mode) async {
    setState(() => _voiceMode = mode);
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).setValue('voiceMode', mode);
    ref.invalidate(voiceModeProvider);
    ref.invalidate(voiceConfigProvider);
  }

  Future<void> _save() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final baseUrl = _baseUrlController.text.trim();
    final key = _apiKeyController.text.trim();
    final model = _modelController.text.trim();

    if (baseUrl.isNotEmpty) {
      await dao.setValue('aiBaseUrl', baseUrl);
    } else {
      await dao.deleteKey('aiBaseUrl');
    }
    // Clean up legacy key if it exists.
    await dao.deleteKey('aiApiEndpoint');

    if (key.isNotEmpty) {
      await dao.setValue('aiApiKey', key);
    } else {
      await dao.deleteKey('aiApiKey');
    }
    if (model.isNotEmpty) {
      await dao.setValue('aiModelName', model);
    } else {
      await dao.deleteKey('aiModelName');
    }

    // Save voice settings
    await dao.setValue('voiceEnabled', _voiceEnabled.toString());
    await dao.setValue('voiceSameAsAgent', _voiceSameAsAgent.toString());
    await dao.setValue('voiceMode', _voiceMode);

    final voiceEndpoint = _voiceEndpointController.text.trim();
    final voiceKey = _voiceApiKeyController.text.trim();
    final voiceModel = _voiceModelController.text.trim();

    if (voiceEndpoint.isNotEmpty) {
      await dao.setValue('voiceApiEndpoint', voiceEndpoint);
    } else {
      await dao.deleteKey('voiceApiEndpoint');
    }
    if (voiceKey.isNotEmpty) {
      await dao.setValue('voiceApiKey', voiceKey);
    } else {
      await dao.deleteKey('voiceApiKey');
    }
    if (voiceModel.isNotEmpty) {
      await dao.setValue('voiceModelName', voiceModel);
    } else {
      await dao.deleteKey('voiceModelName');
    }

    ref.invalidate(aiConfigProvider);
    ref.invalidate(voiceEnabledProvider);
    ref.invalidate(voiceModeProvider);
    ref.invalidate(voiceConfigProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 配置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();
    final theme = Theme.of(context);
    final isWhisper = _voiceMode == 'whisper';

    return Scaffold(
      appBar: AppBar(title: const Text('AI 配置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          Text(
            '配置 AI 服务的 API 信息，支持 OpenAI 兼容接口。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              hintText: 'https://api.openai.com/v1',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.psychology),
            ),
          ),

          // ── 语音输入 ──
          const SizedBox(height: 32),
          Text(
            '语音输入',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '录音后转为文字，可选 Whisper API 或 LLM 多模态转写。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用语音输入'),
            subtitle: const Text('在对话输入栏显示麦克风按钮'),
            value: _voiceEnabled,
            onChanged: _toggleVoiceEnabled,
          ),
          if (_voiceEnabled) ...[
            // Voice mode selector
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'whisper',
                    label: Text('Whisper API'),
                    icon: Icon(Icons.mic, size: 18),
                  ),
                  ButtonSegment(
                    value: 'multimodal',
                    label: Text('LLM 多模态'),
                    icon: Icon(Icons.auto_awesome, size: 18),
                  ),
                ],
                selected: {_voiceMode},
                onSelectionChanged: (s) => _setVoiceMode(s.first),
              ),
            ),

            if (isWhisper) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('和 Agent 一致'),
                subtitle: const Text('复用上方 Base URL 和 Key'),
                value: _voiceSameAsAgent,
                onChanged: _toggleVoiceSameAsAgent,
              ),
              if (!_voiceSameAsAgent) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _voiceEndpointController,
                  decoration: const InputDecoration(
                    labelText: 'STT Endpoint',
                    hintText: 'https://api.openai.com/v1/audio/transcriptions',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _voiceApiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'STT API Key',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _voiceModelController,
                decoration: const InputDecoration(
                  labelText: 'STT 模型名称',
                  hintText: 'whisper-1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.record_voice_over),
                ),
              ),
            ] else ...[
              Text(
                '多模态模式将使用上方配置的 LLM 模型直接转写音频，无需额外配置。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
