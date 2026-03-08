import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/course_dao.dart';
import '../database/daos/task_dao.dart';
import '../database/daos/reminder_dao.dart';
import '../database/daos/period_time_dao.dart';
import '../database/daos/semester_dao.dart';
import '../database/daos/settings_dao.dart';
import '../mappers/course_mapper.dart';
import '../mappers/task_mapper.dart';
import '../mappers/reminder_mapper.dart';
import '../mappers/period_time_mapper.dart';
import '../mappers/semester_mapper.dart';
import 'webdav_service.dart';

/// Service that exports/imports app data as JSON via WebDAV.
class SyncService {
  final AppDatabase db;
  final WebDavService webdav;

  /// Settings keys excluded from backup (device-specific, transient, or sensitive).
  static const _excludedSettingsKeys = {
    'onboardingCompleted',
    'webdavUrl',
    'webdavUsername',
    'webdavPassword',
    'webdavRemotePath',
    'weatherAlertLastDate',
    // Sensitive credentials — must not leak via sync.
    'aiApiKey',
    'tgBotToken',
    'tgOwnerId',
    'proxyUrl',
    'proxyUsername',
    'proxyPassword',
  };

  SyncService({required this.db, required this.webdav});

  /// Export all data and upload to WebDAV.
  Future<void> uploadBackup() async {
    final json = await _exportAll();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
    await webdav.upload(bytes);
  }

  /// Maximum backup size to download (50 MB).
  static const _maxDownloadBytes = 50 * 1024 * 1024;

  /// Download from WebDAV and restore all data.
  Future<void> downloadRestore() async {
    final bytes = await webdav.download();
    if (bytes.length > _maxDownloadBytes) {
      throw WebDavException(
          '备份文件过大 (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)，'
          '上限为 ${_maxDownloadBytes ~/ 1024 ~/ 1024} MB');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw WebDavException('备份文件格式错误，无法解析 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw WebDavException('备份文件格式错误，顶层结构不是 JSON 对象');
    }
    await _importAll(decoded);
  }

  Future<Map<String, dynamic>> _exportAll() async {
    final courseDao = CourseDao(db);
    final taskDao = TaskDao(db);
    final reminderDao = ReminderDao(db);
    final periodTimeDao = PeriodTimeDao(db);
    final semesterDao = SemesterDao(db);
    final settingsDao = SettingsDao(db);

    // Read all data.
    final courses = await courseDao.watchAll().first;
    final tasks = await taskDao.watchAll().first;
    final reminders = await reminderDao.watchAll().first;
    final periodTimes = await periodTimeDao.getAll();
    final semesters = await semesterDao.watchAll().first;
    final allSettings = await settingsDao.getAll();

    // Filter out excluded keys.
    final settings = <String, String>{};
    for (final entry in allSettings.entries) {
      if (!_excludedSettingsKeys.contains(entry.key)) {
        settings[entry.key] = entry.value;
      }
    }

    // Load subtasks for each task.
    final tasksWithSubtasks = <Map<String, dynamic>>[];
    for (final task in tasks) {
      final subtaskRows = await taskDao.findSubTasksByTaskId(task.id);
      final subtasks = subtaskRows.map((s) => s.toDomain()).toList();
      tasksWithSubtasks.add(_taskToJson(task.toDomain(subtasks: subtasks)));
    }

    return {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'semesters': semesters.map((s) => _semesterToJson(s.toDomain())).toList(),
      'courses': courses.map((c) => _courseToJson(c.toDomain())).toList(),
      'tasks': tasksWithSubtasks,
      'reminders':
          reminders.map((r) => _reminderToJson(r.toDomain())).toList(),
      'periodTimes':
          periodTimes.map((p) => _periodTimeToJson(p.toDomain())).toList(),
    };
  }

  Future<void> _importAll(Map<String, dynamic> json) async {
    final version = json['version'] as int?;
    if (version != 1 && version != 2) {
      throw WebDavException('不支持的备份版本: $version');
    }

    await db.transaction(() async {
      final courseDao = CourseDao(db);
      final taskDao = TaskDao(db);
      final reminderDao = ReminderDao(db);
      final periodTimeDao = PeriodTimeDao(db);
      final semesterDao = SemesterDao(db);
      final settingsDao = SettingsDao(db);

      // Clear existing data.
      await db.delete(db.subTasksTable).go();
      await db.delete(db.tasksTable).go();
      await db.delete(db.coursesTable).go();
      await db.delete(db.remindersTable).go();
      await db.delete(db.periodTimesTable).go();
      await db.delete(db.semestersTable).go();

      // Import semesters.
      final semesters = json['semesters'] as List? ?? [];
      for (final s in semesters) {
        final semester = _semesterFromJson(s as Map<String, dynamic>);
        await semesterDao.upsert(semester.toCompanion());
      }

      // Import courses.
      final courses = json['courses'] as List? ?? [];
      for (final c in courses) {
        final course = _courseFromJson(c as Map<String, dynamic>);
        await courseDao.upsert(course.toCompanion());
      }

      // Import tasks + subtasks.
      final tasks = json['tasks'] as List? ?? [];
      for (final t in tasks) {
        final map = t as Map<String, dynamic>;
        final task = _taskFromJson(map);
        await taskDao.upsert(task.toCompanion());
        final subtasks = map['subtasks'] as List? ?? [];
        for (final st in subtasks) {
          final subtask = _subtaskFromJson(st as Map<String, dynamic>);
          await taskDao.upsertSubTask(subtask.toCompanion(task.id));
        }
      }

      // Import reminders.
      final reminders = json['reminders'] as List? ?? [];
      for (final r in reminders) {
        final reminder = _reminderFromJson(r as Map<String, dynamic>);
        await reminderDao.upsert(reminder.toCompanion());
      }

      // Import period times.
      final periodTimes = json['periodTimes'] as List? ?? [];
      final ptEntries = periodTimes
          .map(
              (p) => _periodTimeFromJson(p as Map<String, dynamic>).toCompanion())
          .toList();
      if (ptEntries.isNotEmpty) {
        await periodTimeDao.replaceAll(ptEntries);
      }

      // Import settings.
      if (version == 2) {
        // v2: full settings map (excluding device-specific keys).
        final settings =
            (json['settings'] as Map<String, dynamic>?)?.cast<String, String>();
        if (settings != null) {
          for (final entry in settings.entries) {
            if (!_excludedSettingsKeys.contains(entry.key)) {
              await settingsDao.setValue(entry.key, entry.value);
            }
          }
        }
      } else {
        // v1: only activeSemesterId.
        final activeSemesterId = json['activeSemesterId'] as String?;
        if (activeSemesterId != null) {
          await settingsDao.setValue('activeSemesterId', activeSemesterId);
        }
      }
    });
  }

  // ── JSON Serialization ──

  Map<String, dynamic> _courseToJson(Course c) => {
        'id': c.id,
        'name': c.name,
        'location': c.location,
        'teacher': c.teacher,
        'weekday': c.weekday,
        'startPeriod': c.startPeriod,
        'endPeriod': c.endPeriod,
        'weekMode': c.weekMode.name,
        'customWeeks': c.customWeeks,
        'color': c.color,
        'semesterId': c.semesterId,
        'createdAt': c.createdAt.millisecondsSinceEpoch,
        'updatedAt': c.updatedAt.millisecondsSinceEpoch,
      };

  Course _courseFromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String?,
        teacher: j['teacher'] as String?,
        weekday: j['weekday'] as int,
        startPeriod: j['startPeriod'] as int,
        endPeriod: j['endPeriod'] as int,
        weekMode: WeekMode.values.byName(j['weekMode'] as String),
        customWeeks:
            (j['customWeeks'] as List?)?.map((e) => e as int).toList() ??
                const [],
        color: j['color'] as String?,
        semesterId: j['semesterId'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int),
      );

  Map<String, dynamic> _taskToJson(Task t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'priority': t.priority.name,
        'isDone': t.isDone,
        'dueDate': t.dueDate?.millisecondsSinceEpoch,
        'courseId': t.courseId,
        'subtasks': t.subtasks.map(_subtaskToJson).toList(),
        'createdAt': t.createdAt.millisecondsSinceEpoch,
        'updatedAt': t.updatedAt.millisecondsSinceEpoch,
      };

  Task _taskFromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        priority: Priority.values.byName(j['priority'] as String),
        isDone: j['isDone'] as bool,
        dueDate: j['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['dueDate'] as int)
            : null,
        courseId: j['courseId'] as String?,
        subtasks: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int),
      );

  Map<String, dynamic> _subtaskToJson(SubTask s) => {
        'id': s.id,
        'title': s.title,
        'isDone': s.isDone,
      };

  SubTask _subtaskFromJson(Map<String, dynamic> j) => SubTask(
        id: j['id'] as String,
        title: j['title'] as String,
        isDone: j['isDone'] as bool,
      );

  Map<String, dynamic> _reminderToJson(Reminder r) => {
        'id': r.id,
        'title': r.title,
        'body': r.body,
        'scheduledAt': r.scheduledAt.millisecondsSinceEpoch,
        'type': r.type.name,
        'linkedEntityId': r.linkedEntityId,
        'isActive': r.isActive,
        'createdAt': r.createdAt.millisecondsSinceEpoch,
        'updatedAt': r.updatedAt.millisecondsSinceEpoch,
      };

  Reminder _reminderFromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        scheduledAt:
            DateTime.fromMillisecondsSinceEpoch(j['scheduledAt'] as int),
        type: ReminderType.values.byName(j['type'] as String),
        linkedEntityId: j['linkedEntityId'] as String?,
        isActive: j['isActive'] as bool,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int),
      );

  Map<String, dynamic> _periodTimeToJson(PeriodTime p) => {
        'periodNumber': p.periodNumber,
        'startHour': p.startHour,
        'startMinute': p.startMinute,
        'endHour': p.endHour,
        'endMinute': p.endMinute,
      };

  PeriodTime _periodTimeFromJson(Map<String, dynamic> j) => PeriodTime(
        periodNumber: j['periodNumber'] as int,
        startHour: j['startHour'] as int,
        startMinute: j['startMinute'] as int,
        endHour: j['endHour'] as int,
        endMinute: j['endMinute'] as int,
      );

  Map<String, dynamic> _semesterToJson(Semester s) => {
        'id': s.id,
        'name': s.name,
        'startDate': s.startDate.millisecondsSinceEpoch,
        'totalWeeks': s.totalWeeks,
        'createdAt': s.createdAt.millisecondsSinceEpoch,
      };

  Semester _semesterFromJson(Map<String, dynamic> j) => Semester(
        id: j['id'] as String,
        name: j['name'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(j['startDate'] as int),
        totalWeeks: j['totalWeeks'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
      );
}
