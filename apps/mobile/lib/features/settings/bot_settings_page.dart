import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bot_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/proxy_providers.dart';

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
  bool _keepAlive = false;
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
    final keepAlive = await dao.getValue('tgKeepAlive');
    if (mounted) {
      setState(() {
        _tokenController.text = token ?? '';
        _chatIdController.text = chatId ?? '';
        _enabled = enabled == 'true';
        _notifyEnabled = notify == 'true';
        _agentEnabled = agent == 'true';
        _keepAlive = keepAlive == 'true';
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
    await dao.setValue('tgKeepAlive', _keepAlive.toString());

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

    final client = ref.read(httpClientProvider);
    final service = TelegramBotService(token: token, client: client);
    final status = await service.testConnection();

    if (!status.ok) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = '连接失败: ${status.error}';
        });
      }
      return;
    }

    // Connection OK — try sending a test message if chatId is configured.
    final chatId = _chatIdController.text.trim();
    String resultText = '连接成功！Bot: @${status.botUsername}';

    if (chatId.isNotEmpty) {
      try {
        await service.sendMessage(chatId, '✅ Bot 连接测试成功！');
        resultText += '\n已向 Chat $chatId 发送测试消息';
      } catch (e) {
        resultText += '\n⚠️ 发送测试消息失败: $e';
      }
    }

    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = resultText;
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
    if (!value) setState(() => _keepAlive = false);
    await _save();
  }

  Future<void> _toggleKeepAlive(bool value) async {
    setState(() => _keepAlive = value);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bot 集成')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Telegram ──
          _sectionHeader(theme, 'Telegram'),
          Text(
            '配置 Telegram Bot 后可将提醒转发到 Telegram，并通过 Bot 使用 AI 助手。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Master switch
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: const Icon(Icons.telegram),
              title: const Text('启用 Telegram Bot'),
              value: _enabled,
              onChanged: _toggleEnabled,
            ),
          ),

          if (_enabled) ...[
            const SizedBox(height: 12),

            // Connection card
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Bot Token',
                        hintText: '123456:ABC-DEF...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _chatIdController,
                      decoration: const InputDecoration(
                        labelText: 'Chat ID',
                        hintText: '你的 Telegram 数字 ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        helperText: '向 @RawDataBot 发消息获取 Chat ID',
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('测试连接'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('保存'),
                        ),
                      ],
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testResult!.startsWith('连接成功')
                              ? Colors.green
                              : theme.colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Feature toggles
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active),
                    title: const Text('提醒转发'),
                    subtitle: const Text('创建提醒时同步推送到 Telegram'),
                    value: _notifyEnabled,
                    onChanged: _toggleNotify,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.psychology),
                    title: const Text('AI 助手'),
                    subtitle: const Text('通过 Bot 对话，流式输出'),
                    value: _agentEnabled,
                    onChanged: _toggleAgent,
                  ),
                  if (_agentEnabled) ...[
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.battery_saver),
                      title: const Text('后台保活'),
                      subtitle: const Text('App 退到后台时保持 Bot 轮询'),
                      value: _keepAlive,
                      onChanged: _toggleKeepAlive,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── 更多平台 ──
          _sectionHeader(theme, '更多平台'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.more_horiz,
                  color: theme.colorScheme.onSurfaceVariant),
              title: const Text('敬请期待'),
              subtitle: const Text('更多平台支持正在规划中'),
              enabled: false,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
