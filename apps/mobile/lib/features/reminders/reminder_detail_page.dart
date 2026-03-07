import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:presentation/presentation.dart';

import '../../providers/notification_providers.dart';
import '../../providers/reminder_providers.dart';

class ReminderDetailPage extends ConsumerWidget {
  final String reminderId;

  const ReminderDetailPage({required this.reminderId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderAsync = ref.watch(reminderDetailProvider(reminderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.go('/reminders/$reminderId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: '删除提醒',
                content: '确认删除该提醒？',
              );
              if (confirmed && context.mounted) {
                await ref
                    .read(reminderRepositoryProvider)
                    .delete(reminderId);
                await ref.read(notificationServiceProvider).cancel(reminderId);
                if (context.mounted) context.go('/reminders');
              }
            },
          ),
        ],
      ),
      body: reminderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (reminder) {
          if (reminder == null) {
            return const Center(child: Text('提醒不存在'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('标题'),
                subtitle: Text(reminder.title),
              ),
              if (reminder.body != null)
                ListTile(
                  title: const Text('内容'),
                  subtitle: Text(reminder.body!),
                ),
              ListTile(
                title: const Text('提醒时间'),
                subtitle: Text(
                  '${reminder.scheduledAt.year}/${reminder.scheduledAt.month}/${reminder.scheduledAt.day} '
                  '${reminder.scheduledAt.hour.toString().padLeft(2, '0')}:'
                  '${reminder.scheduledAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
              ListTile(
                title: const Text('类型'),
                subtitle: Text(reminder.type.name),
              ),
              SwitchListTile(
                title: const Text('启用'),
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
            ],
          );
        },
      ),
    );
  }
}
