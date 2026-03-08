import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_provider.dart';
import '../../providers/proxy_providers.dart';
import '../../providers/reminder_providers.dart';
import '../../providers/sync_providers.dart';
import '../../providers/widget_providers.dart';

class WebDavSettingsPage extends ConsumerStatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  ConsumerState<WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends ConsumerState<WebDavSettingsPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController();
  bool _isLoaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final url = await dao.getValue('webdavUrl');
    final username = await dao.getValue('webdavUsername');
    final password = await dao.getValue('webdavPassword');
    final remotePath = await dao.getValue('webdavRemotePath');
    if (mounted) {
      setState(() {
        _urlController.text = url ?? '';
        _usernameController.text = username ?? '';
        _passwordController.text = password ?? '';
        _pathController.text = remotePath ?? '/asscl';
      });
    }
  }

  Future<void> _save() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);

    await dao.setValue('webdavUrl', _urlController.text.trim());
    await dao.setValue('webdavUsername', _usernameController.text.trim());
    await dao.setValue('webdavPassword', _passwordController.text.trim());
    await dao.setValue('webdavRemotePath', _pathController.text.trim());

    ref.invalidate(webDavConfigProvider);
    ref.invalidate(syncServiceProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WebDAV 配置已保存')),
      );
    }
  }

  /// Build a [SyncService] directly from the current form values,
  /// bypassing the async provider chain.
  SyncService? _buildSyncService() {
    final config = WebDavConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      remotePath: _pathController.text.trim(),
    );
    if (!config.isValid) return null;

    final client = ref.read(httpClientProvider);
    final db = ref.read(appDatabaseProvider);
    return SyncService(
      db: db,
      webdav: WebDavService(config: config, client: client),
    );
  }

  Future<void> _testConnection() async {
    await _save();
    setState(() => _busy = true);
    try {
      final sync = _buildSyncService();
      if (sync == null) {
        _showSnackBar('请先填写完整的 WebDAV 配置');
        return;
      }
      final ok = await sync.webdav.testConnection();
      _showSnackBar(ok ? '连接成功' : '连接失败，请检查配置');
    } catch (e) {
      _showSnackBar('连接出错: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    await _save();
    setState(() => _busy = true);
    try {
      final sync = _buildSyncService();
      if (sync == null) {
        _showSnackBar('请先填写完整的 WebDAV 配置');
        return;
      }
      await sync.uploadBackup();
      _showSnackBar('备份上传成功');
    } catch (e) {
      _showSnackBar('上传失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('下载恢复将覆盖本地所有课程、任务、提醒等数据，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _save();
    setState(() => _busy = true);
    try {
      final sync = _buildSyncService();
      if (sync == null) {
        _showSnackBar('请先填写完整的 WebDAV 配置');
        return;
      }
      await sync.downloadRestore();
      await rescheduleAllReminders(ref);
      refreshWidgets(ref);
      _showSnackBar('数据恢复成功');
    } catch (e) {
      _showSnackBar('恢复失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 同步')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              '连接配置',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Text(
            '通过 WebDAV 在多设备间同步课程、任务、提醒等数据。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'WebDAV 地址',
                      hintText: 'https://dav.example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: '远程路径',
                      hintText: '/asscl',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.folder),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('保存'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _testConnection,
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('测试连接'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 同步操作 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text(
              '同步操作',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Text(
            '上传会将本地数据备份到 WebDAV；下载会用远程数据覆盖本地。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  title: const Text('上传备份'),
                  subtitle: const Text('将本地数据上传到 WebDAV'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _busy ? null : _upload,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download),
                  title: const Text('下载恢复'),
                  subtitle: const Text('从 WebDAV 恢复数据（覆盖本地）'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _busy ? null : _download,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
