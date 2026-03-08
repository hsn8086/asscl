import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/database_provider.dart';
import '../../providers/ai_providers.dart';
import '../../providers/shortened_names_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _enterToSend = false;
  bool _aiShortenNames = false;
  bool _isLoaded = false;

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final enterToSend = await dao.getValue('enterToSend');
    final aiShortenNames = await dao.getValue('aiShortenNames');
    if (mounted) {
      setState(() {
        _enterToSend = enterToSend == 'true';
        _aiShortenNames = aiShortenNames == 'true';
      });
    }
  }

  Future<void> _toggleEnterToSend(bool value) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue('enterToSend', value.toString());
    ref.invalidate(enterToSendProvider);
    setState(() => _enterToSend = value);
  }

  Future<void> _toggleAiShortenNames(bool value) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue('aiShortenNames', value.toString());
    ref.invalidate(aiShortenNamesEnabledProvider);
    setState(() => _aiShortenNames = value);
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 课程管理 ──
          _SectionHeader('课程管理'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.school,
                  title: '学期管理',
                  subtitle: '创建、切换学期，设置开学日期',
                  onTap: () => context.push('/settings/semesters'),
                ),
                const Divider(height: 1, indent: 56),
                _NavTile(
                  icon: Icons.schedule,
                  title: '节次时间',
                  subtitle: '上下课时间配置',
                  onTap: () => context.push('/settings/period-config'),
                ),
              ],
            ),
          ),

          // ── AI ──
          _SectionHeader('AI'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.key,
                  title: 'AI 配置',
                  subtitle: 'API 地址、密钥、模型',
                  onTap: () => context.push('/settings/ai-config'),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.keyboard_return),
                  title: const Text('回车发送'),
                  subtitle: Text(
                    _enterToSend
                        ? 'Enter 发送，Shift+Enter 换行'
                        : 'Enter 换行',
                  ),
                  value: _enterToSend,
                  onChanged: _toggleEnterToSend,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.short_text),
                  title: const Text('AI 缩短课程名'),
                  subtitle: const Text('在课表格子中显示 AI 简称'),
                  value: _aiShortenNames,
                  onChanged: _toggleAiShortenNames,
                ),
                if (_aiShortenNames) ...[
                  const Divider(height: 1, indent: 56),
                  _NavTile(
                    icon: Icons.text_fields,
                    title: '简称管理',
                    subtitle: '查看、编辑、重新生成',
                    onTap: () => context.push('/settings/shortened-names'),
                  ),
                ],
              ],
            ),
          ),

          // ── 集成 ──
          _SectionHeader('集成'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.cloud,
                  title: '天气提醒',
                  subtitle: '开屏天气提醒条件配置',
                  onTap: () => context.push('/settings/weather'),
                ),
                const Divider(height: 1, indent: 56),
                _NavTile(
                  icon: Icons.smart_toy,
                  title: 'Bot 集成',
                  subtitle: 'Telegram 通知转发、AI 助手',
                  onTap: () => context.push('/settings/bot'),
                ),
                const Divider(height: 1, indent: 56),
                _NavTile(
                  icon: Icons.sync,
                  title: 'WebDAV 同步',
                  subtitle: '通过 WebDAV 备份和恢复数据',
                  onTap: () => context.push('/settings/webdav'),
                ),
              ],
            ),
          ),

          // ── 网络 ──
          _SectionHeader('网络'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.vpn_lock,
                  title: '代理设置',
                  subtitle: 'HTTP 代理，用于 AI 和 Bot 请求',
                  onTap: () => context.push('/settings/proxy'),
                ),
              ],
            ),
          ),

          // ── 其他 ──
          if (kDebugMode) ...[
            _SectionHeader('其他'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _NavTile(
                    icon: Icons.developer_mode,
                    title: '开发者选项',
                    subtitle: '调试工具和诊断信息',
                    onTap: () => context.push('/settings/developer'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
