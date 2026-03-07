import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shortened_names_provider.dart';

class ShortenedNamesPage extends ConsumerWidget {
  const ShortenedNamesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortenedAsync = ref.watch(shortenedCourseNamesProvider);
    final shortened = shortenedAsync.valueOrNull ?? {};
    final isLoading = shortenedAsync.isLoading;
    final theme = Theme.of(context);

    // Sort entries by key (normalized name) for stable display
    final entries = shortened.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('简称管理'),
        actions: [
          if (!isLoading && shortened.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新生成',
              onPressed: () =>
                  ref.read(shortenedCourseNamesProvider.notifier).regenerate(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清除全部',
              onPressed: () =>
                  ref.read(shortenedCourseNamesProvider.notifier).clearAll(),
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? Center(
                  child: Text(
                    '暂无简称缓存，将在课程加载后自动生成',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    final nameKey = entry.key;
                    final shortName = entry.value;
                    return ListTile(
                      title:
                          Text(nameKey, style: const TextStyle(fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shortName,
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
                                context, ref, nameKey, shortName),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => ref
                                .read(shortenedCourseNamesProvider.notifier)
                                .removeName(nameKey),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  },
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
