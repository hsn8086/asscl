import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../providers/reminder_providers.dart';

const _uuid = Uuid();

class ReminderFormPage extends ConsumerStatefulWidget {
  final String? reminderId;

  const ReminderFormPage({this.reminderId, super.key});

  @override
  ConsumerState<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends ConsumerState<ReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = TimeOfDay.now();
  ReminderType _type = ReminderType.custom;
  bool _isLoading = false;

  bool get _isEditing => widget.reminderId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadReminder();
  }

  Future<void> _loadReminder() async {
    final reminder =
        await ref.read(reminderRepositoryProvider).findById(widget.reminderId!);
    if (reminder != null && mounted) {
      setState(() {
        _titleController.text = reminder.title;
        _bodyController.text = reminder.body ?? '';
        _scheduledDate = reminder.scheduledAt;
        _scheduledTime = TimeOfDay.fromDateTime(reminder.scheduledAt);
        _type = reminder.type;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  DateTime get _combinedDateTime => DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final reminder = Reminder(
      id: widget.reminderId ?? _uuid.v4(),
      title: _titleController.text.trim(),
      body: _bodyController.text.trim().isEmpty
          ? null
          : _bodyController.text.trim(),
      scheduledAt: _combinedDateTime,
      type: _type,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(reminderRepositoryProvider).save(reminder);
    ref.invalidate(watchRemindersProvider);
    if (widget.reminderId != null) {
      ref.invalidate(reminderDetailProvider(widget.reminderId!));
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑提醒' : '添加提醒'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入标题' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '内容',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '日期: ${_scheduledDate.year}/${_scheduledDate.month}/${_scheduledDate.day}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _scheduledDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _scheduledDate = picked);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '时间: ${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _scheduledTime,
                );
                if (picked != null) {
                  setState(() => _scheduledTime = picked);
                }
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<ReminderType>(
              segments: const [
                ButtonSegment(
                    value: ReminderType.courseReminder, label: Text('课程')),
                ButtonSegment(
                    value: ReminderType.taskReminder, label: Text('任务')),
                ButtonSegment(
                    value: ReminderType.custom, label: Text('自定义')),
              ],
              selected: {_type},
              onSelectionChanged: (s) =>
                  setState(() => _type = s.first),
            ),
          ],
        ),
      ),
    );
  }
}
