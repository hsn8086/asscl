import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/ai_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/proxy_providers.dart';
import '../../providers/reminder_providers.dart';
import '../../providers/sync_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  // WebDAV fields
  final _webdavUrlController = TextEditingController();
  final _webdavUsernameController = TextEditingController();
  final _webdavPasswordController = TextEditingController();
  final _webdavPathController = TextEditingController(text: '/asscl');
  bool _webdavBusy = false;

  // AI fields
  final _aiBaseUrlController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    _webdavPathController.dispose();
    _aiBaseUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    // Save AI config if provided.
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);

    final baseUrl = _aiBaseUrlController.text.trim();
    final key = _aiApiKeyController.text.trim();
    final model = _aiModelController.text.trim();

    if (baseUrl.isNotEmpty) await dao.setValue('aiBaseUrl', baseUrl);
    if (key.isNotEmpty) await dao.setValue('aiApiKey', key);
    if (model.isNotEmpty) await dao.setValue('aiModelName', model);

    if (baseUrl.isNotEmpty || key.isNotEmpty) {
      ref.invalidate(aiConfigProvider);
    }

    // Mark onboarding as completed.
    await dao.setValue('onboardingCompleted', 'true');
    ref.invalidate(onboardingCompletedProvider);

    if (mounted) context.go('/schedule');
  }

  Future<void> _saveWebDavAndNext() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);

    final url = _webdavUrlController.text.trim();
    final username = _webdavUsernameController.text.trim();
    final password = _webdavPasswordController.text.trim();
    final path = _webdavPathController.text.trim();

    if (url.isNotEmpty) await dao.setValue('webdavUrl', url);
    if (username.isNotEmpty) await dao.setValue('webdavUsername', username);
    if (password.isNotEmpty) await dao.setValue('webdavPassword', password);
    if (path.isNotEmpty) await dao.setValue('webdavRemotePath', path);

    ref.invalidate(webDavConfigProvider);
    ref.invalidate(syncServiceProvider);

    _nextPage();
  }

  SyncService? _buildSyncService() {
    final config = WebDavConfig(
      url: _webdavUrlController.text.trim(),
      username: _webdavUsernameController.text.trim(),
      password: _webdavPasswordController.text.trim(),
      remotePath: _webdavPathController.text.trim(),
    );
    if (!config.isValid) return null;

    final client = ref.read(httpClientProvider);
    final db = ref.read(appDatabaseProvider);
    return SyncService(
      db: db,
      webdav: WebDavService(config: config, client: client),
    );
  }

  Future<void> _testWebDavConnection() async {
    // Save first so provider picks up values.
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);

    await dao.setValue('webdavUrl', _webdavUrlController.text.trim());
    await dao.setValue('webdavUsername', _webdavUsernameController.text.trim());
    await dao.setValue('webdavPassword', _webdavPasswordController.text.trim());
    await dao.setValue('webdavRemotePath', _webdavPathController.text.trim());
    ref.invalidate(webDavConfigProvider);
    ref.invalidate(syncServiceProvider);

    setState(() => _webdavBusy = true);
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
      if (mounted) setState(() => _webdavBusy = false);
    }
  }

  Future<void> _downloadRestore() async {
    // Save first.
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);

    await dao.setValue('webdavUrl', _webdavUrlController.text.trim());
    await dao.setValue('webdavUsername', _webdavUsernameController.text.trim());
    await dao.setValue('webdavPassword', _webdavPasswordController.text.trim());
    await dao.setValue('webdavRemotePath', _webdavPathController.text.trim());
    ref.invalidate(webDavConfigProvider);
    ref.invalidate(syncServiceProvider);

    setState(() => _webdavBusy = true);
    try {
      final sync = _buildSyncService();
      if (sync == null) {
        _showSnackBar('请先填写完整的 WebDAV 配置');
        return;
      }
      await sync.downloadRestore();
      await rescheduleAllReminders(ref);
      _showSnackBar('数据恢复成功');

      // If the backup contained AI config, skip the AI page.
      final aiBase = await dao.getValue('aiBaseUrl');
      final aiKey = await dao.getValue('aiApiKey');
      if (aiBase != null && aiBase.isNotEmpty &&
          aiKey != null && aiKey.isNotEmpty) {
        if (mounted) {
          await dao.setValue('onboardingCompleted', 'true');
          ref.invalidate(onboardingCompletedProvider);
          context.go('/schedule');
        }
        return;
      }
    } catch (e) {
      _showSnackBar('恢复失败: $e');
    } finally {
      if (mounted) setState(() => _webdavBusy = false);
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(theme),
                  _buildWebDavPage(theme),
                  _buildAiPage(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 0: Welcome ──

  Widget _buildWelcomePage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            '欢迎使用课程表',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '管理课程、任务和提醒，AI 助手帮你高效学习。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('开始'),
          ),
        ],
      ),
    );
  }

  // ── Page 1: WebDAV ──

  Widget _buildWebDavPage(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Icon(
          Icons.sync,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'WebDAV 同步',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '配置 WebDAV 可在多设备间同步数据，也可以从已有备份恢复。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        TextFormField(
          controller: _webdavUrlController,
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
          controller: _webdavUsernameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _webdavPasswordController,
          decoration: const InputDecoration(
            labelText: '密码',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _webdavPathController,
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
              child: OutlinedButton.icon(
                onPressed: _webdavBusy ? null : _testWebDavConnection,
                icon: _webdavBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('测试连接'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _webdavBusy ? null : _downloadRestore,
                icon: const Icon(Icons.cloud_download, size: 18),
                label: const Text('下载恢复'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _nextPage,
              child: const Text('跳过'),
            ),
            FilledButton(
              onPressed: _webdavBusy ? null : _saveWebDavAndNext,
              child: const Text('下一步'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Page 2: AI Config ──

  Widget _buildAiPage(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Icon(
          Icons.auto_awesome,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'AI 配置',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '配置 AI 服务后，可使用 AI 助手导入课程、智能问答等功能。\n支持 OpenAI 兼容接口。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        TextFormField(
          controller: _aiBaseUrlController,
          decoration: const InputDecoration(
            labelText: 'API Base URL',
            hintText: 'https://api.openai.com/v1',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _aiApiKeyController,
          decoration: const InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _aiModelController,
          decoration: const InputDecoration(
            labelText: '模型名称',
            hintText: 'gpt-4o-mini',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.psychology),
          ),
        ),

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _finish,
              child: const Text('跳过'),
            ),
            FilledButton(
              onPressed: _finish,
              child: const Text('完成'),
            ),
          ],
        ),
      ],
    );
  }
}
