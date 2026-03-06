import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../providers/course_providers.dart';
import '../../providers/period_config_providers.dart';
import '../../providers/semester_providers.dart';
import '../../providers/widget_providers.dart';

const _uuid = Uuid();
const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class CourseFormPage extends ConsumerStatefulWidget {
  final String? courseId;

  const CourseFormPage({this.courseId, super.key});

  @override
  ConsumerState<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends ConsumerState<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _teacherController = TextEditingController();

  int _weekday = 1;
  int _startPeriod = 1;
  int _endPeriod = 2;
  WeekMode _weekMode = WeekMode.every;
  final Set<int> _customWeeks = {};
  bool _isLoading = false;
  String? _existingSemesterId;

  bool get _isEditing => widget.courseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadCourse();
    }
  }

  Future<void> _loadCourse() async {
    final course =
        await ref.read(courseRepositoryProvider).findById(widget.courseId!);
    if (course != null && mounted) {
      setState(() {
        _nameController.text = course.name;
        _locationController.text = course.location ?? '';
        _teacherController.text = course.teacher ?? '';
        _weekday = course.weekday;
        _startPeriod = course.startPeriod;
        _endPeriod = course.endPeriod;
        _weekMode = course.weekMode;
        _customWeeks
          ..clear()
          ..addAll(course.customWeeks);
        _existingSemesterId = course.semesterId;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final course = Course(
      id: widget.courseId ?? _uuid.v4(),
      name: _nameController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      teacher: _teacherController.text.trim().isEmpty
          ? null
          : _teacherController.text.trim(),
      weekday: _weekday,
      startPeriod: _startPeriod,
      endPeriod: _endPeriod,
      weekMode: _weekMode,
      customWeeks: _customWeeks.toList()..sort(),
      semesterId: _isEditing
          ? _existingSemesterId
          : ref.read(activeSemesterIdProvider).valueOrNull,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(courseRepositoryProvider).save(course);
    ref.invalidate(watchCoursesProvider);
    ref.read(widgetServiceProvider).updateWidgets();
    if (widget.courseId != null) {
      ref.invalidate(courseDetailProvider(widget.courseId!));
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '添加课程'),
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '教师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(
                labelText: '星期',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                7,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_weekdayNames[i]),
                ),
              ),
              onChanged: (v) => setState(() => _weekday = v!),
            ),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final config = ref.watch(periodConfigProvider).valueOrNull;
              final totalPeriods = config?.totalPeriods ?? 12;
              String periodLabel(int p) {
                final pt = config?.getTime(p);
                if (pt != null) return '第$p节 (${pt.startTimeStr}-${pt.endTimeStr})';
                return '第$p节';
              }
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _startPeriod,
                      decoration: const InputDecoration(
                        labelText: '开始节次',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        totalPeriods,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(periodLabel(i + 1)),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _startPeriod = v!;
                          if (_endPeriod < _startPeriod) {
                            _endPeriod = _startPeriod;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _endPeriod,
                      decoration: const InputDecoration(
                        labelText: '结束节次',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        totalPeriods - _startPeriod + 1,
                        (i) => DropdownMenuItem(
                          value: i + _startPeriod,
                          child: Text(periodLabel(i + _startPeriod)),
                        ),
                      ),
                      onChanged: (v) => setState(() => _endPeriod = v!),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            SegmentedButton<WeekMode>(
              segments: const [
                ButtonSegment(value: WeekMode.every, label: Text('每周')),
                ButtonSegment(value: WeekMode.odd, label: Text('单周')),
                ButtonSegment(value: WeekMode.even, label: Text('双周')),
                ButtonSegment(value: WeekMode.custom, label: Text('自定义')),
              ],
              selected: {_weekMode},
              onSelectionChanged: (s) => setState(() => _weekMode = s.first),
            ),
            if (_weekMode == WeekMode.custom) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: List.generate(20, (i) {
                  final week = i + 1;
                  return FilterChip(
                    label: Text('$week'),
                    selected: _customWeeks.contains(week),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _customWeeks.add(week);
                        } else {
                          _customWeeks.remove(week);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
