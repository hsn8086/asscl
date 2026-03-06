# asscl - 智能课程表

面向学生群体的课程表 & 任务管理应用，支持 AI 智能录入、桌面微件和本地优先的数据存储。

## 功能特性

- **课程管理** — 手动/AI 录入课程，支持每周/单双周/自定义周模式，周网格 & 时间流双视图
- **AI 助手** — 自然语言交互，支持课程导入、查询、修改、删除，设置周次、添加任务/提醒、配置节次时间
- **任务管理** — 待办事项、子任务、优先级、截止日期
- **提醒通知** — 本地通知调度，精确闹钟支持
- **学期管理** — 多学期切换，自动计算当前周次
- **桌面微件** — Android 小组件：下节课 & 周课表一览
- **Markdown + KaTeX** — AI 回复支持富文本和数学公式渲染
- **AI 课名缩写** — 可选开启，AI 生成简称仅用于显示，支持手动编辑

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter (Dart 3.11+) |
| 状态管理 | flutter_riverpod |
| 数据库 | Drift (SQLite)，本地优先 |
| 路由 | go_router (StatefulShellRoute) |
| 通知 | flutter_local_notifications |
| 桌面微件 | home_widget (Android AppWidget) |
| AI 渲染 | gpt_markdown |
| AI 接口 | OpenAI 兼容 API (可配置 endpoint) |

## 项目结构

```
asscl/
├── apps/mobile/             # Flutter 应用
│   ├── lib/
│   │   ├── main.dart        # 入口
│   │   ├── app.dart         # MaterialApp.router
│   │   ├── router/          # GoRouter + 底部导航
│   │   ├── providers/       # Riverpod 状态管理
│   │   ├── services/        # 微件数据同步
│   │   └── features/        # 功能模块
│   │       ├── schedule/    # 课程表 + AI 助手
│   │       ├── tasks/       # 任务管理
│   │       ├── reminders/   # 提醒管理
│   │       └── settings/    # 设置 + 学期管理
│   ├── android/             # Android 原生（微件）
│   └── test/                # 测试
├── packages/
│   ├── domain/              # 纯 Dart：实体、接口、用例
│   ├── data/                # 数据层：Drift、DAO、仓库实现、AI 服务
│   └── presentation/        # 共享 Widget + 主题
└── docs/                    # 文档
    ├── PRD.md               # 产品需求文档
    ├── project_structure.md # 详细项目结构
    └── commit_convention.md # 提交规范
```

详细结构参见 [docs/project_structure.md](docs/project_structure.md)。

## 快速开始

### 环境要求

- Flutter SDK ≥ 3.22.0 (Dart ≥ 3.11.1)
- Java 17 (Android 编译)

### 运行

```bash
# 安装依赖
cd apps/mobile && flutter pub get

# 运行（连接设备或模拟器）
flutter run

# 编译 APK
flutter build apk
```

### 测试

```bash
# 全部测试
cd packages/domain && dart test
cd packages/data && dart test
cd apps/mobile && flutter test

# 静态分析
cd apps/mobile && flutter analyze
```

## AI 配置

应用内 **设置 → AI 配置** 填写：

| 字段 | 说明 | 示例 |
|------|------|------|
| API Endpoint | OpenAI 兼容接口地址 | `https://api.openai.com/v1/chat/completions` |
| API Key | 密钥 | `sk-...` |
| 模型名称 | 可选，默认 `gpt-4o-mini` | `gpt-4o` |

支持任何 OpenAI 兼容 API（如 DeepSeek、本地 Ollama 等）。

## 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat(scope): 描述    # 新功能
fix(scope): 描述     # 修复
docs: 描述           # 文档
test(scope): 描述    # 测试
refactor(scope): 描述 # 重构
```

详见 [docs/commit_convention.md](docs/commit_convention.md)。

## CI

GitHub Actions 自动运行：
- **Analyze** — 四个包分别静态分析
- **Test** — 四个包分别单元测试
- **Build** — 编译 debug APK 并上传 artifact

## 许可证

私有项目。
