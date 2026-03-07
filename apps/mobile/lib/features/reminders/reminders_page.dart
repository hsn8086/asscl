import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:presentation/presentation.dart';

import '../../providers/notification_providers.dart';
import '../../providers/reminder_providers.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(watchRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('提醒')),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (reminders) {
          if (reminders.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications,
              message: '暂无提醒，点击 + 添加',
            );
          }
          final sorted = [...reminders]
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final reminder = sorted[index];
              return ListTile(
                title: Text(reminder.title),
                subtitle: Text(
                  '${reminder.scheduledAt.month}/${reminder.scheduledAt.day} '
                  '${reminder.scheduledAt.hour.toString().padLeft(2, '0')}:'
                  '${reminder.scheduledAt.minute.toString().padLeft(2, '0')}',
                ),
                trailing: Switch(
                  value: reminder.isActive,
                  onChanged: (active) async {
                    await ref
                        .read(reminderRepositoryProvider)
                        .setActive(reminder.id, active: active);
                    final ns = ref.read(notificationServiceProvider);
                    if (active && reminder.scheduledAt.isAfter(DateTime.now())) {
                      await ns.schedule(reminder.copyWith(isActive: active));
                    } else {
                      await ns.cancel(reminder.id);
                    }
                  },
                ),
                onTap: () => context.go('/reminders/${reminder.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/reminders/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
