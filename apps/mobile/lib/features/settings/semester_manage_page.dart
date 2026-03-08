import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:presentation/presentation.dart';
import 'package:uuid/uuid.dart';

import '../../providers/course_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/semester_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/widget_providers.dart';

const _uuid = Uuid();

class SemesterManagePage extends ConsumerWidget {
  const SemesterManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semestersAsync = ref.watch(semestersProvider);
    final activeId = ref.watch(activeSemesterIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('学期管理')),
      body: semestersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (semesters) {
          if (semesters.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('暂无学期'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showSemesterForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('创建学期'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: semesters.length,
            itemBuilder: (context, index) {
              final s = semesters[index];
              final isActive = s.id == activeId;
              return Card(
                color: isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: Icon(
                    isActive ? Icons.check_circle : Icons.circle_outlined,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    '${_formatDate(s.startDate)} · 共${s.totalWeeks}周 · '
                    '当前第${s.currentWeek()}周',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showSemesterForm(context, ref, semester: s);
                        case 'delete':
                          _deleteSemester(context, ref, s, isActive);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => _setActive(ref, s.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSemesterForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _setActive(WidgetRef ref, String semesterId) async {
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).setValue('activeSemesterId', semesterId);
    ref.invalidate(activeSemesterIdProvider);
    refreshWidgets(ref);
  }

  Future<void> _deleteSemester(
    BuildContext context,
    WidgetRef ref,
    Semester semester,
    bool isActive,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除学期',
      content: '确认删除「${semester.name}」？该学期下的课程也会被删除。',
    );
    if (!confirmed || !context.mounted) return;

    final repo = ref.read(semesterRepositoryProvider);
    final courseRepo = ref.read(courseRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);

    // Collect course IDs being deleted to clean up task references.
    final allCourses = await courseRepo.watchAll().first;
    final deletedCourseIds = <String>{};
    for (final c in allCourses) {
      if (c.semesterId == semester.id) {
        deletedCourseIds.add(c.id);
        await courseRepo.delete(c.id);
      }
    }

    // Unlink tasks that referenced deleted courses (don't delete the tasks).
    if (deletedCourseIds.isNotEmpty) {
      final tasks = await taskRepo.watchAll().first;
      for (final t in tasks) {
        if (t.courseId != null && deletedCourseIds.contains(t.courseId)) {
          await taskRepo.save(t.copyWith(courseId: () => null));
        }
      }
    }

    await repo.delete(semester.id);

    if (isActive) {
      // Switch to first remaining semester, or clear if none left
      final remaining = await repo.watchAll().first;
      final db = ref.read(appDatabaseProvider);
      if (remaining.isNotEmpty) {
        await SettingsDao(db)
            .setValue('activeSemesterId', remaining.first.id);
      } else {
        await SettingsDao(db).deleteKey('activeSemesterId');
      }
    }

    ref.invalidate(semestersProvider);
    ref.invalidate(activeSemesterIdProvider);
    refreshWidgets(ref);
  }

  Future<void> _showSemesterForm(
    BuildContext context,
    WidgetRef ref, {
    Semester? semester,
  }) async {
    final result = await showModalBottomSheet<Semester>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SemesterFormSheet(semester: semester),
    );
    if (result == null) return;

    final repo = ref.read(semesterRepositoryProvider);
    await repo.save(result);

    // Set as active
    final db = ref.read(appDatabaseProvider);
    await SettingsDao(db).setValue('activeSemesterId', result.id);

    ref.invalidate(semestersProvider);
    ref.invalidate(activeSemesterIdProvider);
    refreshWidgets(ref);
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class _SemesterFormSheet extends StatefulWidget {
  final Semester? semester;
  const _SemesterFormSheet({this.semester});

  @override
  State<_SemesterFormSheet> createState() => _SemesterFormSheetState();
}

class _SemesterFormSheetState extends State<_SemesterFormSheet> {
  late final TextEditingController _nameController;
  late DateTime _startDate;
  late int _totalWeeks;

  @override
  void initState() {
    super.initState();
    final s = widget.semester;
    _nameController = TextEditingController(text: s?.name ?? '');
    if (s != null) {
      _startDate = s.startDate;
      _totalWeeks = s.totalWeeks;
    } else {
      // Default: this Monday
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      _totalWeeks = 20;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      // Snap to Monday
      final monday = picked.subtract(Duration(days: picked.weekday - 1));
      setState(() => _startDate = monday);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final semester = Semester(
      id: widget.semester?.id ?? _uuid.v4(),
      name: name,
      startDate: _startDate,
      totalWeeks: _totalWeeks,
      createdAt: widget.semester?.createdAt ?? DateTime.now(),
    );
    Navigator.of(context).pop(semester);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.semester != null ? '编辑学期' : '新建学期',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '学期名称',
              hintText: '如：2025-2026 秋季学期',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('开始日期（自动对齐到周一）'),
            subtitle: Text(
              '${_startDate.year}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.day.toString().padLeft(2, '0')}（周一）',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('总周数：'),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _totalWeeks > 1
                    ? () => setState(() => _totalWeeks--)
                    : null,
              ),
              Text('$_totalWeeks',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _totalWeeks < 30
                    ? () => setState(() => _totalWeeks++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
