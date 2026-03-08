import 'package:drift/drift.dart';
import 'package:domain/domain.dart' show WeekMode, Priority, ReminderType;
import 'package:uuid/uuid.dart';

import 'tables/courses_table.dart';
import 'tables/tasks_table.dart';
import 'tables/sub_tasks_table.dart';
import 'tables/reminders_table.dart';
import 'tables/period_times_table.dart';
import 'tables/settings_table.dart';
import 'tables/chat_sessions_table.dart';
import 'tables/chat_messages_table.dart';
import 'tables/semesters_table.dart';
import 'daos/course_dao.dart';
import 'daos/task_dao.dart';
import 'daos/reminder_dao.dart';
import 'daos/period_time_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/chat_session_dao.dart';
import 'daos/semester_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    CoursesTable,
    TasksTable,
    SubTasksTable,
    RemindersTable,
    PeriodTimesTable,
    SettingsTable,
    ChatSessionsTable,
    ChatMessagesTable,
    SemestersTable,
  ],
  daos: [
    CourseDao,
    TaskDao,
    ReminderDao,
    PeriodTimeDao,
    SettingsDao,
    ChatSessionDao,
    SemesterDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(periodTimesTable);
            await m.createTable(settingsTable);
          }
          if (from < 3) {
            await m.createTable(chatSessionsTable);
            await m.createTable(chatMessagesTable);
          }
          if (from < 4) {
            await m.createTable(semestersTable);
            await customStatement(
                'ALTER TABLE courses_table ADD COLUMN semester_id TEXT');

            // Create a default semester and assign all existing courses to it
            final uuid = const Uuid().v4();
            final now = DateTime.now();
            // Find the Monday of the current week
            final monday = now.subtract(Duration(days: now.weekday - 1));
            // Drift stores DateTimeColumn as Unix timestamp in seconds
            final mondayEpoch = monday.millisecondsSinceEpoch ~/ 1000;
            final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;

            await customStatement(
              "INSERT INTO semesters_table (id, name, start_date, total_weeks, created_at) "
              "VALUES ('$uuid', '默认学期', $mondayEpoch, 20, $nowEpoch)",
            );
            await customStatement(
              "UPDATE courses_table SET semester_id = '$uuid'",
            );
            await customStatement(
              "INSERT OR REPLACE INTO settings_table (key, value) "
              "VALUES ('activeSemesterId', '$uuid')",
            );
          }
          if (from < 5) {
            // Fix: v4 migration may have stored dates as ISO strings instead
            // of Unix timestamps. Convert in-place without deleting data.
            final rows = await customSelect(
              'SELECT id, start_date, created_at FROM semesters_table',
            ).get();

            for (final row in rows) {
              final id = row.read<String>('id');
              final rawStart = row.read<int>('start_date');
              final rawCreated = row.read<int>('created_at');

              // If the value looks like a large millisecond timestamp or an
              // ISO-8601 parse artifact, convert it. Drift DateTimeColumn
              // stores as Unix seconds. Values > 1e12 are likely millis.
              int fixTimestamp(int raw) {
                if (raw > 1e12) {
                  // Likely milliseconds — convert to seconds.
                  return raw ~/ 1000;
                }
                return raw; // Already in seconds.
              }

              final fixedStart = fixTimestamp(rawStart);
              final fixedCreated = fixTimestamp(rawCreated);

              if (fixedStart != rawStart || fixedCreated != rawCreated) {
                await customStatement(
                  'UPDATE semesters_table SET start_date = $fixedStart, '
                  'created_at = $fixedCreated WHERE id = \'$id\'',
                );
              }
            }
          }
        },
      );
}
