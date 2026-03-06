library;

// Enums
export 'src/enums/week_mode.dart';
export 'src/enums/priority.dart';
export 'src/enums/view_type.dart';
export 'src/enums/reminder_type.dart';

// Entities
export 'src/entities/course.dart';
export 'src/entities/task.dart';
export 'src/entities/reminder.dart';
export 'src/entities/period_time.dart';
export 'src/entities/period_config.dart';
export 'src/entities/school_preset.dart';
export 'src/entities/ai_parsed_course.dart';
export 'src/entities/chat_session.dart';
export 'src/entities/semester.dart';

// Data
export 'src/data/school_presets.dart';

// Repository interfaces
export 'src/repositories/course_repository.dart';
export 'src/repositories/task_repository.dart';
export 'src/repositories/reminder_repository.dart';
export 'src/repositories/period_config_repository.dart';
export 'src/repositories/semester_repository.dart';

// Service interfaces
export 'src/services/notification_service.dart';
export 'src/services/ai_import_service.dart';
export 'src/services/ai_agent_service.dart';
export 'src/services/bot_platform_service.dart';

// Use cases - Course
export 'src/usecases/course/save_course_use_case.dart';
export 'src/usecases/course/delete_course_use_case.dart';
export 'src/usecases/course/watch_courses_use_case.dart';

// Use cases - Task
export 'src/usecases/task/save_task_use_case.dart';
export 'src/usecases/task/delete_task_use_case.dart';
export 'src/usecases/task/mark_task_done_use_case.dart';
export 'src/usecases/task/watch_tasks_use_case.dart';

// Use cases - Reminder
export 'src/usecases/reminder/save_reminder_use_case.dart';
export 'src/usecases/reminder/delete_reminder_use_case.dart';
export 'src/usecases/reminder/watch_reminders_use_case.dart';
