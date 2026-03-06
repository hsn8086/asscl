import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bot_providers.dart';
import '../../providers/database_provider.dart';

class BotSettingsPage extends ConsumerStatefulWidget {
  const BotSettingsPage({super.key});

  @override
  ConsumerState<BotSettingsPage> createState() => _BotSettingsPageState();
}

class _BotSettingsPageState extends ConsumerState<BotSettingsPage> {
  final _tokenController = TextEditingController();
  final _chatIdController = TextEditingController();
  bool _enabled = false;
  bool _notifyEnabled = false;
  bool _agentEnabled = false;
  bool _isLoaded = false;
  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _tokenController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final token = await dao.getValue('tgBotToken');
    final chatId = await dao.getValue('tgChatId');
    final enabled = await dao.getValue('tgEnabled');
    final notify = await dao.getValue('tgNotifyEnabled');
    final agent = await dao.getValue('tgAgentEnabled');
    if (mounted) {
      setState(() {
        _tokenController.text = token ?? '';
        _chatIdController.text = chatId ?? '';
        _enabled = enabled == 'true';
        _notifyEnabled = notify == 'true';
        _agentEnabled = agent == 'true';
      });
    }
  }

  Future<void> _save() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final token = _tokenController.text.trim();
    final chatId = _chatIdController.text.trim();

    if (token.isNotEmpty) {
      await dao.setValue('tgBotToken', token);
    } else {
      await dao.deleteKey('tgBotToken');
    }
    if (chatId.isNotEmpty) {
      await dao.setValue('tgChatId', chatId);
    } else {
      await dao.deleteKey('tgChatId');
    }
    await dao.setValue('tgEnabled', _enabled.toString());
    await dao.setValue('tgNotifyEnabled', _notifyEnabled.toString());
    await dao.setValue('tgAgentEnabled', _agentEnabled.toString());

    ref.invalidate(tgConfigProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bot 配置已保存')),
      );
    }
  }

  Future<void> _testConnection() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _testResult = '请先输入 Bot Token');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final service = TelegramBotService(token: token);
    final status = await service.testConnection();

    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = status.ok
            ? '连接成功！Bot: @${status.botUsername}'
            : '连接失败: ${status.error}';
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _save();
  }

  Future<void> _toggleNotify(bool value) async {
    setState(() => _notifyEnabled = value);
    await _save();
  }

  Future<void> _toggleAgent(bool value) async {
    setState(() => _agentEnabled = value);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('Bot 集成')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Platform hint ---
          Text('Telegram Bot', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '配置 Telegram Bot 后可将提醒转发到 Telegram，并通过 Bot 使用 AI 助手。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // --- Master switch ---
          SwitchListTile(
            title: const Text('启用 Telegram Bot'),
            value: _enabled,
            onChanged: _toggleEnabled,
            contentPadding: EdgeInsets.zero,
          ),

          if (_enabled) ...[
            const SizedBox(height: 12),

            // --- Token ---
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Bot Token',
                hintText: '123456:ABC-DEF...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),

            // --- Test connection ---
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('测试连接'),
                ),
                if (_testResult != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testResult!.startsWith('连接成功')
                            ? Colors.green
                            : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // --- Chat ID ---
            TextFormField(
              controller: _chatIdController,
              decoration: const InputDecoration(
                labelText: 'Chat ID',
                hintText: '你的 Telegram 数字 ID',
                border: OutlineInputBorder(),
                helperText: '向 @userinfobot 发送任意消息可获取你的 Chat ID',
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // --- Feature toggles ---
            SwitchListTile(
              title: const Text('提醒转发'),
              subtitle: const Text('创建提醒时同步推送到 Telegram'),
              value: _notifyEnabled,
              onChanged: _toggleNotify,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('AI 助手'),
              subtitle: const Text('通过 Telegram Bot 与 AI 助手对话（流式输出）'),
              value: _agentEnabled,
              onChanged: _toggleAgent,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            // --- Save ---
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
            ),
          ],

          const SizedBox(height: 32),

          // --- Future platforms placeholder ---
          Text(
            '更多平台',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.more_horiz),
              title: const Text('敬请期待'),
              subtitle: const Text('Discord、微信等平台支持将在后续版本中添加'),
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
