import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../providers/proxy_providers.dart';

class ProxySettingsPage extends ConsumerStatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  ConsumerState<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends ConsumerState<ProxySettingsPage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _enabled = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final enabled = await dao.getValue('proxyEnabled');
    final host = await dao.getValue('proxyHost');
    final port = await dao.getValue('proxyPort');
    if (mounted) {
      setState(() {
        _enabled = enabled == 'true';
        _hostController.text = host ?? '';
        _portController.text = port ?? '';
      });
    }
  }

  Future<void> _save() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final host = _hostController.text.trim();
    final port = _portController.text.trim();

    await dao.setValue('proxyEnabled', _enabled.toString());
    if (host.isNotEmpty) {
      await dao.setValue('proxyHost', host);
    } else {
      await dao.deleteKey('proxyHost');
    }
    if (port.isNotEmpty) {
      await dao.setValue('proxyPort', port);
    } else {
      await dao.deleteKey('proxyPort');
    }

    ref.invalidate(proxyConfigProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('代理配置已保存')),
      );
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('代理设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              'HTTP 代理',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Text(
            '配置代理后，AI 请求和 Telegram Bot 请求将通过代理发送。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: const Icon(Icons.vpn_lock),
              title: const Text('启用代理'),
              value: _enabled,
              onChanged: _toggleEnabled,
            ),
          ),

          if (_enabled) ...[
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: '代理地址',
                        hintText: '127.0.0.1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        hintText: '7890',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
