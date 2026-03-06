# Telegram Bot 接入计划

## 概述

将通知推送和 AI Agent 对话接入 Telegram Bot，作为可选功能放在设置二级菜单。
架构上预留多平台扩展能力（Discord、微信等）。

Telegram Bot API 9.5 (2026-03) 新增 `sendMessageDraft` 方法，支持流式输出消息，
无需再用 editMessageText 模拟流式。

## 架构设计

### 1. Domain 层 — 平台抽象

```
packages/domain/lib/src/services/bot_platform_service.dart
```

```dart
/// 通用 Bot 平台接口，Telegram / Discord / 微信等各实现一个
abstract interface class BotPlatformService {
  /// 发送完整文本消息
  Future<void> sendMessage(String chatId, String text);

  /// 流式发送消息（利用平台流式 API，如 TG sendMessageDraft）
  Future<void> sendMessageStreaming(String chatId, Stream<String> textStream);

  /// 轮询接收新消息（长轮询）
  Stream<BotIncomingMessage> pollMessages();

  /// 测试连接是否有效
  Future<BotConnectionStatus> testConnection();

  /// 停止轮询
  void stopPolling();
}

class BotIncomingMessage {
  final String chatId;
  final int messageId;
  final String text;
}

class BotConnectionStatus {
  final bool ok;
  final String? botUsername; // 成功时返回 bot 名称
  final String? error;      // 失败时返回错误信息
}
```

### 2. Data 层 — Telegram 实现

```
packages/data/lib/src/services/telegram_bot_service.dart
```

核心方法：

| 方法 | Telegram API | 说明 |
|------|-------------|------|
| `sendMessage` | `sendMessage` | 发送完整文本 |
| `sendMessageStreaming` | `sendMessageDraft` + `publishMessageDraft` | 流式输出 AI 回复 |
| `pollMessages` | `getUpdates` (long polling, timeout=30) | 接收用户消息 |
| `testConnection` | `getMe` | 验证 token |

**流式输出流程 (`sendMessageDraft`)**：
1. 收到 AI delta → 调用 `sendMessageDraft(chat_id, text: 累积文本, business_connection_id: null)`
2. 持续推送 delta，TG 客户端显示"正在输入"气泡
3. AI 结束后调用 `publishMessageDraft(chat_id)` 发布为正式消息
4. 限流：控制更新频率 ~100ms/次（TG 限流策略待实测调整）

### 3. App 层 — Provider & UI

#### 3a. 配置存储 (SettingsDao keys)

| Key | 值 | 说明 |
|-----|---|------|
| `tgBotToken` | string | Bot Token |
| `tgChatId` | string | 目标 Chat ID |
| `tgEnabled` | "true"/"false" | 总开关 |
| `tgNotifyEnabled` | "true"/"false" | 通知转发开关 |
| `tgAgentEnabled` | "true"/"false" | AI Agent 开关 |

#### 3b. Providers

```
apps/mobile/lib/providers/bot_providers.dart
```

- `tgConfigProvider` — 读取 TG 配置
- `telegramBotServiceProvider` — 创建 TelegramBotService 实例（无配置时返回 null）
- `tgPollingProvider` — 管理长轮询生命周期

#### 3c. 设置页面

```
apps/mobile/lib/features/settings/bot_settings_page.dart
```

- 在主设置页添加 Card/ListTile 入口 → `context.push('/settings/bot')`
- 子页面内容：
  - 平台选择（目前仅 Telegram，预留 tab 或 dropdown）
  - Bot Token 输入框
  - "测试连接" 按钮 → 调用 `getMe` 显示 bot 用户名
  - Chat ID 输入框 + "获取 Chat ID" 帮助提示
  - 通知转发开关
  - AI Agent 转发开关

#### 3d. 路由

`app_router.dart` 添加：
```dart
GoRoute(
  path: 'bot',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (_, __) => const BotSettingsPage(),
),
```

### 4. 通知转发

在现有 `NotificationService.schedule()` 调用链中增加 TG 推送：

**方案**：修改 `save_reminder_use_case.dart`，保存提醒时若 TG 通知开启，
同步调用 `telegramBotService.sendMessage()` 发送提醒预览。

实际到点通知仍由 `flutter_local_notifications` 负责（系统级可靠），
TG 通知作为补充渠道——在创建时立刻发一条"已设置提醒：xxx 将在 xxx 触发"，
到点时机依赖本地通知系统。

**后续可优化**：加 `workmanager` 后台任务，到点时再发 TG 消息。

### 5. AI Agent via Telegram

**核心流程**：

```
TG 用户发消息
  → pollMessages() 拿到 BotIncomingMessage
  → 调用 AiAgentService.sendStreaming(text: msg.text)
  → 将 Stream<ChatStreamDelta> 的 textDelta
    通过 sendMessageStreaming() 流式推回 TG
  → 遇到 toolCalls → 自动执行（仅安全工具：query 类）
    → 将 tool result 加入 history → 继续 sendStreaming
  → 流结束 → publishMessageDraft
```

**Tool Call 处理策略**（TG 侧）：
- 只读类工具（query_courses, query_semesters）→ 自动执行
- 写入类工具（import, update, delete, set_*）→ 发送确认消息，
  等用户回复"确认"/"取消"后再执行
- 超时 60s 无回复 → 自动取消

**独立会话管理**：
- TG 会话与 App 内会话独立（不共享 history）
- TG 会话存入同一个 `ChatSessions` 表，标记来源为 `telegram`

### 6. 文件清单

#### 新增文件

| 文件 | 层 | 说明 |
|------|---|------|
| `packages/domain/lib/src/services/bot_platform_service.dart` | domain | 平台抽象接口 |
| `packages/data/lib/src/services/telegram_bot_service.dart` | data | TG 实现 |
| `apps/mobile/lib/providers/bot_providers.dart` | app | TG 相关 providers |
| `apps/mobile/lib/features/settings/bot_settings_page.dart` | app | 设置子页面 |
| `apps/mobile/lib/services/bot_agent_relay.dart` | app | TG ↔ AI Agent 中继服务 |

#### 修改文件

| 文件 | 改动 |
|------|------|
| `packages/domain/lib/domain.dart` | export bot_platform_service |
| `packages/data/lib/data.dart` | export telegram_bot_service |
| `apps/mobile/lib/features/settings/settings_page.dart` | 添加"Bot 集成"入口 |
| `apps/mobile/lib/router/app_router.dart` | 添加 `/settings/bot` 路由 |
| `docs/project_structure.md` | 更新结构说明 |

### 7. 实现顺序

1. Domain 层：`BotPlatformService` 接口 + 数据类
2. Data 层：`TelegramBotService` 实现（sendMessage, getMe, getUpdates, sendMessageDraft）
3. App 层：`bot_providers.dart` + `bot_settings_page.dart` + 路由
4. 通知转发：在提醒保存时增加 TG 推送
5. AI 中继：`bot_agent_relay.dart` — 轮询 → AI → 流式回复
6. 测试 + 文档更新
