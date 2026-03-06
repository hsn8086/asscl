import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../providers/task_providers.dart';

const _uuid = Uuid();

class TaskFormPage extends ConsumerStatefulWidget {
  final String? taskId;

  const TaskFormPage({this.taskId, super.key});

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  Priority _priority = Priority.medium;
  DateTime? _dueDate;
  final List<_SubTaskEntry> _subtasks = [];
  bool _isLoading = false;

  bool get _isEditing => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadTask();
  }

  Future<void> _loadTask() async {
    final task =
        await ref.read(taskRepositoryProvider).findById(widget.taskId!);
    if (task != null && mounted) {
      setState(() {
        _titleController.text = task.title;
        _descController.text = task.description ?? '';
        _priority = task.priority;
        _dueDate = task.dueDate;
        _subtasks
          ..clear()
          ..addAll(task.subtasks.map((s) => _SubTaskEntry(
                id: s.id,
                controller: TextEditingController(text: s.title),
                isDone: s.isDone,
              )));
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final s in _subtasks) {
      s.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final task = Task(
      id: widget.taskId ?? _uuid.v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      priority: _priority,
      dueDate: _dueDate,
      subtasks: _subtasks
          .where((s) => s.controller.text.trim().isNotEmpty)
          .map((s) => SubTask(
                id: s.id,
                title: s.controller.text.trim(),
                isDone: s.isDone,
              ))
          .toList(),
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(taskRepositoryProvider).save(task);
    ref.invalidate(watchTasksProvider);
    if (widget.taskId != null) {
      ref.invalidate(taskDetailProvider(widget.taskId!));
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑任务' : '添加任务'),
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
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SegmentedButton<Priority>(
              segments: const [
                ButtonSegment(value: Priority.low, label: Text('低')),
                ButtonSegment(value: Priority.medium, label: Text('中')),
                ButtonSegment(value: Priority.high, label: Text('高')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) =>
                  setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dueDate == null
                  ? '设置截止日期'
                  : '截止: ${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _dueDate = picked);
                      }
                    },
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('子任务', style: Theme.of(context).textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _subtasks.add(_SubTaskEntry(
                        id: _uuid.v4(),
                        controller: TextEditingController(),
                      ));
                    });
                  },
                ),
              ],
            ),
            for (var i = 0; i < _subtasks.length; i++)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtasks[i].controller,
                      decoration: InputDecoration(
                        hintText: '子任务 ${i + 1}',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        _subtasks[i].controller.dispose();
                        _subtasks.removeAt(i);
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SubTaskEntry {
  final String id;
  final TextEditingController controller;
  bool isDone;

  _SubTaskEntry({
    required this.id,
    required this.controller,
    this.isDone = false,
  });
}
