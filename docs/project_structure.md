# 项目结构说明

本项目已建立 Flutter 工程与基础包结构。此文档用于约定结构，并作为 agent 工作的基准参考。

## 当前目录结构

```
asscl/
├── CLAUDE.md                          # Agent 工作指南
├── docs/
│   ├── PRD.md                         # 产品需求文档
│   ├── project_structure.md           # 本文件
│   ├── commit_convention.md           # 提交规范
│   ├── bugs_tomb/README.md            # Bug 复盘规范
│   └── plans/
│       ├── README.md                  # 计划文档规范
│       └── template.md               # 计划模板
├── apps/
│   └── mobile/                        # Flutter 应用 (iOS/Android)
│       ├── lib/
│       │   ├── main.dart              # 应用入口
│       │   ├── app.dart               # MaterialApp.router
│       │   ├── router/
│       │   │   ├── app_router.dart    # GoRouter + StatefulShellRoute
│       │   │   └── main_scaffold.dart # 底部导航栏
│       │   ├── providers/
│       │   │   ├── database_provider.dart
│       │   │   ├── course_providers.dart
│       │   │   ├── task_providers.dart
│       │   │   ├── reminder_providers.dart
│       │   │   ├── notification_providers.dart
│       │   │   ├── view_providers.dart
│       │   │   ├── period_config_providers.dart
│       │   │   ├── ai_providers.dart
│       │   │   └── widget_providers.dart
│       │   ├── services/
│       │   │   └── widget_service.dart    # 桌面组件数据同步服务
│       │   └── features/
│       │       ├── schedule/          # 课程表 Tab
│       │       │   ├── schedule_page.dart
│       │       │   ├── course_detail_page.dart
│       │       │   ├── course_form_page.dart
│       │       │   ├── ai_import_page.dart   # AI 智能录入
│       │       │   └── widgets/
│       │       │       ├── week_grid_view.dart  # 含时间指针
│       │       │       ├── time_stream_view.dart
│       │       │       └── course_card.dart
│       │       ├── tasks/             # 任务 Tab
│       │       │   ├── tasks_page.dart
│       │       │   ├── task_detail_page.dart
│       │       │   └── task_form_page.dart
│       │       ├── reminders/         # 提醒 Tab
│       │       │   ├── reminders_page.dart
│       │       │   ├── reminder_detail_page.dart
│       │       │   └── reminder_form_page.dart
│       │       └── settings/          # 设置
│       │           └── settings_page.dart  # 节次时间 + AI 配置
│       └── test/
│           ├── widget_test.dart
│           └── services/
│               └── widget_service_test.dart
├── packages/
│   ├── domain/                        # 纯 Dart 包：领域层
│   │   └── lib/src/
│   │       ├── enums/                 # WeekMode, Priority, ViewType, ReminderType
│   │       ├── entities/              # Course, Task(+SubTask), Reminder, PeriodTime, PeriodConfig, SchoolPreset, AiParsedCourse
│   │       ├── data/                  # 静态数据（school_presets.dart）
│   │       ├── repositories/          # 仓库抽象接口（含 PeriodConfigRepository）
│   │       ├── services/              # NotificationService, AiImportService 接口
│   │       └── usecases/              # 用例（course/, task/, reminder/）
│   ├── data/                          # 数据层
│   │   └── lib/src/
│   │       ├── database/
│   │       │   ├── tables/            # Drift 表（含 PeriodTimesTable, SettingsTable）
│   │       │   ├── daos/              # CourseDao, TaskDao, ReminderDao, PeriodTimeDao, SettingsDao
│   │       │   ├── app_database.dart  # @DriftDatabase (schema v2)
│   │       │   └── database_factory.dart
│   │       ├── mappers/               # Drift row ↔ Domain entity
│   │       ├── repositories/          # 仓库实现（含 PeriodConfigRepositoryImpl）
│   │       └── services/              # NotificationServiceImpl, AiImportServiceImpl
│   └── presentation/                  # 共享 Widget + 主题
│       └── lib/src/
│           ├── theme/app_theme.dart
│           └── widgets/               # ConfirmDialog, PriorityChip, EmptyState
```

## 子模块说明

| 模块 | 类型 | 说明 | 依赖 |
|------|------|------|------|
| `packages/domain` | 纯 Dart | 实体、枚举、仓库接口、用例 | equatable, uuid |
| `packages/data` | Flutter | Drift 数据库、DAO、仓库实现、通知服务、AI 导入服务 | domain, drift, flutter_local_notifications, http |
| `packages/presentation` | Flutter | 共享主题与 Widget | domain, flutter |
| `apps/mobile` | Flutter App | UI 页面、路由、状态管理 | domain, data, presentation, riverpod, go_router |

### 技术栈

- **状态管理**: flutter_riverpod
- **数据库**: drift (SQLite)
- **路由**: go_router (StatefulShellRoute)
- **通知**: flutter_local_notifications
- **桌面组件**: home_widget (Android AppWidget)
- **ID 策略**: UUID (uuid 包)

### 架构原则

- `domain` 为纯 Dart 包，不依赖 Flutter，可用 `dart test` 独立测试
- `data` 实现 `domain` 中定义的仓库接口
- `apps/mobile` 通过 Riverpod Provider 注入仓库实现
- Widget 测试通过 Provider override 注入假数据，无需数据库

## 相关文档

- [PRD](./PRD.md)
- [MVP 路线图](./plans/0001-flutter-mvp-roadmap.md)
