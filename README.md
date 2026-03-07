# asscl - 智能课程表

面向学生群体的课程表 & 任务管理应用，支持 AI 智能录入、桌面微件和本地优先的数据存储。

## 功能特性

- **课程管理** — 手动/AI 录入课程，支持每周/单双周/自定义周模式，周网格 & 时间流双视图
- **AI 助手** — 自然语言交互，支持课程导入、查询、修改、删除，设置周次、添加任务/提醒等 12 项操作
- **任务管理** — 待办事项、子任务、优先级、截止日期
- **提醒通知** — 本地通知调度，精确闹钟，支持启用/禁用
- **学期管理** — 多学期创建切换，自动计算当前周次
- **桌面微件** — Android 小组件：下节课 & 周课表一览
- **Telegram Bot** — 提醒转发到 Telegram，通过 Bot 使用 AI 助手（流式输出）
- **网络代理** — 可配置 HTTP 代理，用于 AI 和 Bot 请求
- **Markdown + KaTeX** — AI 回复支持富文本和数学公式渲染
- **AI 课名缩写** — 可选开启，AI 生成简称用于课表格子显示，支持手动编辑

## 使用说明

### AI 配置

应用内 **设置 → AI 配置** 填写：

| 字段 | 说明 | 示例 |
|------|------|------|
| API Endpoint | OpenAI 兼容接口地址 | `https://api.openai.com/v1/chat/completions` |
| API Key | 密钥 | `sk-...` |
| 模型名称 | 可选，默认 `gpt-4o-mini` | `gpt-4o` |

支持任何 OpenAI 兼容 API（如 DeepSeek、本地 Ollama 等）。

### Telegram Bot

应用内 **设置 → Bot 集成** 配置：

1. 通过 [@BotFather](https://t.me/BotFather) 创建 Bot，获取 Token
2. 向 [@userinfobot](https://t.me/userinfobot) 发消息获取你的 Chat ID
3. 在设置中填入 Token 和 Chat ID，启用所需功能

功能：
- **提醒转发** — 创建提醒时自动推送到 Telegram
- **AI 助手** — 直接在 Telegram 与 AI 对话，流式输出
- **后台保活** — App 退到后台时保持 Bot 轮询

### 网络代理

如需代理访问 AI 或 Telegram API，在 **设置 → 代理设置** 配置 HTTP 代理地址和端口。

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter (Dart 3.11+) |
| 状态管理 | flutter_riverpod |
| 数据库 | Drift (SQLite)，本地优先 |
| 路由 | go_router |
| AI 接口 | OpenAI 兼容 API |
| Bot | Telegram Bot API |

## 许可证

私有项目。
