import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/course_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/ai_providers.dart';
import '../../providers/shortened_names_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // AI config
  final _endpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _enterToSend = false;
  bool _aiShortenNames = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final endpoint = await dao.getValue('aiApiEndpoint');
    final key = await dao.getValue('aiApiKey');
    final model = await dao.getValue('aiModelName');
    final enterToSend = await dao.getValue('enterToSend');
    final aiShortenNames = await dao.getValue('aiShortenNames');
    if (mounted) {
      setState(() {
        _endpointController.text = endpoint ?? '';
        _apiKeyController.text = key ?? '';
        _modelController.text = model ?? '';
        _enterToSend = enterToSend == 'true';
        _aiShortenNames = aiShortenNames == 'true';
      });
    }
  }

  Future<void> _saveAiConfig() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final endpoint = _endpointController.text.trim();
    final key = _apiKeyController.text.trim();
    final model = _modelController.text.trim();

    if (endpoint.isNotEmpty) {
      await dao.setValue('aiApiEndpoint', endpoint);
    } else {
      await dao.deleteKey('aiApiEndpoint');
    }
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

    ref.invalidate(aiConfigProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 配置已保存')),
      );
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

  Widget _buildShortenedNamesList(BuildContext context) {
    final shortenedAsync = ref.watch(shortenedCourseNamesProvider);
    final coursesAsync = ref.watch(watchCoursesProvider);
    final courses = coursesAsync.valueOrNull ?? [];
    final shortened = shortenedAsync.valueOrNull ?? {};
    final isLoading = shortenedAsync.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text('简称管理',
                style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (!isLoading && shortened.isNotEmpty) ...[
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新生成'),
                onPressed: () => ref
                    .read(shortenedCourseNamesProvider.notifier)
                    .regenerate(),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清除全部'),
                onPressed: () => ref
                    .read(shortenedCourseNamesProvider.notifier)
                    .clearAll(),
              ),
            ],
          ],
        ),
        if (shortened.isEmpty && !isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '暂无简称缓存，将在课程加载后自动生成',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (shortened.isNotEmpty)
          ...courses
              .where((c) => shortened.containsKey(c.id))
              .map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(c.name,
                        style: const TextStyle(fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shortened[c.id]!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () =>
                              _editShortName(context, c.id, c.name, shortened[c.id]!),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(shortenedCourseNamesProvider.notifier)
                              .removeName(c.id),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  )),
      ],
    );
  }

  Future<void> _editShortName(
    BuildContext context,
    String courseId,
    String fullName,
    String currentShortName,
  ) async {
    final controller = TextEditingController(text: currentShortName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑简称'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('原名: $fullName',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '简称',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      ref.read(shortenedCourseNamesProvider.notifier).setName(courseId, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Semester Management ---
          Card(
            child: ListTile(
              leading: const Icon(Icons.school),
              title: const Text('学期管理'),
              subtitle: const Text('创建、切换学期，设置开学日期'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/semesters'),
            ),
          ),

          const SizedBox(height: 8),

          // --- Period Config Entry (submenu) ---
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('节次时间配置'),
              subtitle: const Text('设置上下课时间、学校预设'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/period-config'),
            ),
          ),

          const SizedBox(height: 16),

          // --- AI Config Section ---
          Text('AI 配置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _endpointController,
            decoration: const InputDecoration(
              labelText: 'API Endpoint',
              hintText: 'https://api.openai.com/v1/chat/completions',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'gpt-4o-mini',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saveAiConfig,
            icon: const Icon(Icons.save),
            label: const Text('保存 AI 配置'),
          ),

          const Divider(height: 40),

          // --- Agent Settings ---
          Text('AI 助手设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('回车发送'),
            subtitle: Text(_enterToSend ? 'Enter 发送消息，Shift+Enter 换行' : 'Enter 换行'),
            value: _enterToSend,
            onChanged: _toggleEnterToSend,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('AI 缩短课程名'),
            subtitle: const Text('在课表格子中用 AI 生成的简称显示，不修改原名'),
            value: _aiShortenNames,
            onChanged: _toggleAiShortenNames,
            contentPadding: EdgeInsets.zero,
          ),
          if (_aiShortenNames) _buildShortenedNamesList(context),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
