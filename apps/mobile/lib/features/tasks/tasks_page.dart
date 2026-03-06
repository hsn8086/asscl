import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:presentation/presentation.dart';

import '../../providers/task_providers.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(watchTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('任务')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.checklist,
              message: '暂无任务，点击 + 添加',
            );
          }
          final pending = tasks.where((t) => !t.isDone).toList();
          final done = tasks.where((t) => t.isDone).toList();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final task in pending)
                _TaskTile(task: task),
              if (done.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '已完成 (${done.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final task in done)
                  _TaskTile(task: task),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/tasks/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final dynamic task; // domain.Task

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Checkbox(
        value: task.isDone,
        onChanged: (value) async {
          await ref
              .read(taskRepositoryProvider)
              .markDone(task.id, done: value ?? false);
        },
      ),
      title: Text(
        task.title,
        style: task.isDone
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: task.dueDate != null
          ? Text(
              '截止: ${task.dueDate!.month}/${task.dueDate!.day}',
            )
          : null,
      trailing: PriorityChip(priority: task.priority),
      onTap: () => context.go('/tasks/${task.id}'),
    );
  }
}
