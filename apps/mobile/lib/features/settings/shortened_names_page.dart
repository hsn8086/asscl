import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai_providers.dart';
import '../../providers/shortened_names_provider.dart';

class ShortenedNamesPage extends ConsumerWidget {
  const ShortenedNamesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortenedAsync = ref.watch(shortenedCourseNamesProvider);
    final shortened = shortenedAsync.valueOrNull ?? {};
    final isLoading = shortenedAsync.isLoading;
    final hasError = shortenedAsync.hasError;
    final theme = Theme.of(context);

    final entries = shortened.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('简称管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新生成',
            onPressed: isLoading
                ? null
                : () => ref
                    .read(shortenedCourseNamesProvider.notifier)
                    .regenerate(),
          ),
          if (shortened.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清除全部',
              onPressed: isLoading
                  ? null
                  : () => ref
                      .read(shortenedCourseNamesProvider.notifier)
                      .clearAll(),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? _buildEmptyState(context, ref, hasError, theme)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    return ListTile(
                      title: Text(entry.key,
                          style: const TextStyle(fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _editShortName(
                                context, ref, entry.key, entry.value),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => ref
                                .read(shortenedCourseNamesProvider.notifier)
                                .removeName(entry.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, bool hasError, ThemeData theme) {
    final hasAiConfig =
        ref.watch(aiConfigProvider).valueOrNull != null;

    final String message;
    final String? hint;
    if (!hasAiConfig) {
      message = '需要先配置 AI 服务';
      hint = '前往 设置 → AI 配置 填写 API 信息后，回到这里点击「重新生成」';
    } else if (hasError) {
      message = '生成失败';
      hint = '请检查 AI 配置和网络连接，然后点击右上角刷新重试';
    } else {
      message = '暂无简称';
      hint = '点击右上角刷新按钮，通过 AI 为课程名生成 2-4 字简称';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.short_text, size: 48,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editShortName(
    BuildContext context,
    WidgetRef ref,
    String nameKey,
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
            Text('原名: $nameKey',
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
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && context.mounted) {
      ref
          .read(shortenedCourseNamesProvider.notifier)
          .setName(nameKey, result);
    }
  }
}
