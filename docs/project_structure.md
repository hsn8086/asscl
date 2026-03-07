# 项目结构说明

本项目已建立 Flutter 工程与基础包结构。此文档用于约定结构，并作为 agent 工作的基准参考。

## 当前目录结构

```
asscl/
├── CLAUDE.md                          # Agent 工作指南
├── README.md                          # 面向用户的产品介绍
├── .github/workflows/ci.yml          # GitHub Actions CI
├── docs/
│   ├── PRD.md                         # 产品需求文档
│   ├── project_structure.md           # 本文件（面向开发者）
│   ├── commit_convention.md           # 提交规范
│   ├── bugs_tomb/README.md            # Bug 复盘规范
│   └── plans/
│       ├── README.md                  # 计划文档规范
│       └── template.md               # 计划模板
├── apps/
│   └── mobile/                        # Flutter 应用 (iOS/Android)
│       ├── lib/
│       │   ├── main.dart              # 应用入口（通知权限、plugin 注入）
│       │   ├── app.dart               # MaterialApp.router + 微件同步
│       │   ├── router/
│       │   │   ├── app_router.dart    # GoRouter + StatefulShellRoute
│       │   │   └── main_scaffold.dart # 底部导航栏（4 Tab）
│       │   ├── providers/
│       │   │   ├── database_provider.dart
│       │   │   ├── course_providers.dart
│       │   │   ├── task_providers.dart
│       │   │   ├── reminder_providers.dart
│       │   │   ├── notification_providers.dart
│       │   │   ├── view_providers.dart
│       │   │   ├── period_config_providers.dart
│       │   │   ├── ai_providers.dart
│       │   │   ├── widget_providers.dart
│       │   │   ├── semester_providers.dart       # 学期 + 当前周计算
│       │   │   ├── shortened_names_provider.dart # AI 缩短课名（持久化缓存）
│       │   │   ├── bot_providers.dart            # Telegram Bot 配置 + 前台服务
│       │   │   └── proxy_providers.dart          # HTTP 代理配置 + 客户端注入
│       │   ├── services/
│       │   │   ├── widget_service.dart    # 桌面组件数据同步服务
│       │   │   └── bot_agent_relay.dart   # TG ↔ AI Agent 中继服务
│       │   └── features/
│       │       ├── schedule/          # 课程表 Tab
│       │       │   ├── schedule_page.dart
│       │       │   ├── course_detail_page.dart
│       │       │   ├── course_form_page.dart
│       │       │   ├── ai_import_page.dart   # AI 助手（独立 Tab）
│       │       │   └── widgets/
│       │       │       ├── week_grid_view.dart  # 含时间指针
│       │       │       ├── time_stream_view.dart
│       │       │       └── course_card.dart     # 支持 AI 简称显示
│       │       ├── tasks/             # 任务 Tab
│       │       │   ├── tasks_page.dart
│       │       │   ├── task_detail_page.dart
│       │       │   └── task_form_page.dart
│       │       ├── reminders/         # 提醒 Tab
│       │       │   ├── reminders_page.dart
│       │       │   ├── reminder_detail_page.dart
│       │       │   └── reminder_form_page.dart
│       │       └── settings/          # 设置
│       │           ├── settings_page.dart         # 主设置（导航入口 + 开关）
│       │           ├── ai_config_page.dart        # AI API 配置
│       │           ├── period_config_page.dart    # 节次时间配置
│       │           ├── semester_manage_page.dart   # 学期管理
│       │           ├── bot_settings_page.dart      # Bot 集成设置（Telegram）
│       │           ├── proxy_settings_page.dart    # 代理设置
│       │           └── shortened_names_page.dart   # AI 简称管理
│       ├── android/
│       │   └── app/src/main/
│       │       ├── kotlin/.../
│       │       │   ├── NextClassWidgetProvider.kt      # 下节课微件
│       │       │   └── TodayScheduleWidgetProvider.kt  # 周课表微件
│       │       └── res/layout/
│       │           ├── widget_next_class.xml
│       │           ├── widget_today_schedule.xml
│       │           ├── widget_period_course.xml       # 课程起始格
│       │           ├── widget_period_course_cont.xml  # 课程延续格（无间隙）
│       │           └── widget_period_empty.xml        # 空格
│       └── test/
│           ├── widget_test.dart
│           └── services/
│               └── widget_service_test.dart
├── packages/
│   ├── domain/                        # 纯 Dart 包：领域层
│   │   └── lib/src/
│   │       ├── enums/                 # WeekMode, Priority, ViewType, ReminderType
│   │       ├── entities/              # Course, Task(+SubTask), Reminder, Semester,
│   │       │                          # PeriodTime, PeriodConfig, SchoolPreset, AiParsedCourse
│   │       ├── data/                  # 静态数据（school_presets.dart）
│   │       ├── repositories/          # 仓库抽象接口（含 SemesterRepository）
│   │       ├── services/              # NotificationService, AiImportService, AiAgentService,
│   │       │                          # BotPlatformService 接口
│   │       └── usecases/              # 用例（course/, task/, reminder/）
│   ├── data/                          # 数据层
│   │   └── lib/src/
│   │       ├── database/
│   │       │   ├── tables/            # Drift 表（含 SemestersTable, SettingsTable）
│   │       │   ├── daos/              # CourseDao, TaskDao, ReminderDao, PeriodTimeDao,
│   │       │   │                      # SettingsDao, SemesterDao, ChatSessionDao
│   │       │   ├── app_database.dart  # @DriftDatabase (schema v5)
│   │       │   └── database_factory.dart
│   │       ├── mappers/               # Drift row ↔ Domain entity
│   │       ├── repositories/          # 仓库实现（含 SemesterRepositoryImpl）
│   │       └── services/              # NotificationServiceImpl, AiImportServiceImpl,
│   │                                  # AiAgentServiceImpl, TelegramBotService
│   └── presentation/                  # 共享 Widget + 主题
│       └── lib/src/
│           ├── theme/app_theme.dart
│           └── widgets/               # ConfirmDialog, PriorityChip, EmptyState
```

## 子模块说明

| 模块 | 类型 | 说明 | 依赖 |
|------|------|------|------|
| `packages/domain` | 纯 Dart | 实体、枚举、仓库接口、用例、服务接口 | equatable, uuid |
| `packages/data` | Flutter | Drift 数据库、DAO、仓库实现、通知服务、AI 服务、TG Bot 服务 | domain, drift, flutter_local_notifications, http |
| `packages/presentation` | Flutter | 共享主题与 Widget | domain, flutter |
| `apps/mobile` | Flutter App | UI 页面、路由、状态管理 | domain, data, presentation, riverpod, go_router, gpt_markdown |

## 技术栈

- **状态管理**: flutter_riverpod
- **数据库**: drift (SQLite)，schema v5
- **路由**: go_router (StatefulShellRoute，4 Tab)
- **通知**: flutter_local_notifications
- **桌面组件**: home_widget (Android AppWidget)
- **AI 渲染**: gpt_markdown (Markdown + KaTeX)
- **AI 接口**: OpenAI 兼容 API（可配置 endpoint/key/model）
- **Bot 集成**: Telegram Bot API 9.5+（sendMessageDraft 流式输出）
- **HTTP 代理**: dart:io HttpClient.findProxy + IOClient
- **前台服务**: flutter_foreground_task（Bot 保活）
- **ID 策略**: UUID (uuid 包)

## 底部导航结构

| Tab | 路由 | 页面 |
|-----|------|------|
| 课程表 | `/schedule` | SchedulePage |
| AI 助手 | `/agent` | AiImportPage |
| 任务 | `/tasks` | TasksPage |
| 提醒 | `/reminders` | RemindersPage |

## AI Agent 工具

AiAgentService 支持 12 个工具调用：

| 工具 | 说明 |
|------|------|
| `import_courses` | 从文本/图片导入课程 |
| `query_courses` | 查询课程 |
| `update_course` | 修改课程 |
| `delete_courses` | 删除课程 |
| `set_current_week` | 设置当前周次 |
| `add_task` | 添加任务 |
| `add_reminder` | 添加提醒 |
| `set_period_times` | 设置节次时间 |
| `query_semesters` | 查询所有学期 |
| `create_semester` | 创建学期 |
| `update_semester` | 修改学期 |
| `delete_semester` | 删除学期 |

## Telegram Bot 架构

```
用户消息 → TelegramBotService.pollMessages()
  → BotAgentRelay._handleMessage()
    → 校验 chatId == config.chatId（拒绝非授权用户）
    → AiAgentService.sendStreaming()
    → 文本回复 → bot.sendMessage()
    → 工具调用：
        只读（query_courses/query_semesters）→ 自动执行
        写入 → 提示用户到 App 确认
```

## HTTP 代理注入

`proxy_providers.dart` 提供 `httpClientProvider`，所有 HTTP 请求（AI、Bot、测试连接）统一走此 client。代理启用时创建 `IOClient`（设 `findProxy`），否则返回普通 `http.Client()`。

## 架构原则

- `domain` 为纯 Dart 包，不依赖 Flutter，可用 `dart test` 独立测试
- `data` 实现 `domain` 中定义的仓库接口
- `apps/mobile` 通过 Riverpod Provider 注入仓库实现
- `main.dart` 初始化的 notification plugin 通过 `ProviderScope.overrides` 注入，保证全局单例
- Widget 测试通过 Provider override 注入假数据，无需数据库

## 开发

### 环境要求

- Flutter SDK ≥ 3.22.0 (Dart ≥ 3.11.1)
- Java 17 (Android 编译)

### 运行

```bash
cd apps/mobile && flutter pub get
flutter run
flutter build apk
```

### 测试

```bash
cd packages/domain && dart test
cd packages/data && dart test
cd apps/mobile && flutter test
```

### 静态分析

```bash
cd apps/mobile && flutter analyze
```

### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/)，详见 [commit_convention.md](./commit_convention.md)。

## CI

GitHub Actions 自动运行：
- **Analyze** — 四个包分别静态分析
- **Test** — 四个包分别单元测试
- **Build** — 编译 debug APK 并上传 artifact

## 相关文档

- [PRD](./PRD.md)
- [提交规范](./commit_convention.md)
- [Bug 复盘](./bugs_tomb/README.md)
- [计划文档](./plans/README.md)
