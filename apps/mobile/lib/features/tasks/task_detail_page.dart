import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:presentation/presentation.dart';

import '../../providers/task_providers.dart';

class TaskDetailPage extends ConsumerWidget {
  final String taskId;

  const TaskDetailPage({required this.taskId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/tasks/$taskId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: '删除任务',
                content: '确认删除该任务？',
              );
              if (confirmed && context.mounted) {
                await ref.read(taskRepositoryProvider).delete(taskId);
                if (context.mounted) context.go('/tasks');
              }
            },
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (task) {
          if (task == null) {
            return const Center(child: Text('任务不存在'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('标题'),
                subtitle: Text(task.title),
              ),
              if (task.description != null)
                ListTile(
                  title: const Text('描述'),
                  subtitle: Text(task.description!),
                ),
              ListTile(
                title: const Text('优先级'),
                trailing: PriorityChip(priority: task.priority),
              ),
              ListTile(
                title: const Text('状态'),
                subtitle: Text(task.isDone ? '已完成' : '未完成'),
              ),
              if (task.dueDate != null)
                ListTile(
                  title: const Text('截止日期'),
                  subtitle: Text(
                      '${task.dueDate!.year}/${task.dueDate!.month}/${task.dueDate!.day}'),
                ),
              if (task.subtasks.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('子任务',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                for (final sub in task.subtasks)
                  CheckboxListTile(
                    value: sub.isDone,
                    title: Text(sub.title),
                    onChanged: null,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
