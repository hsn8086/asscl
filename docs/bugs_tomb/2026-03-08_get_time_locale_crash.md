# Agent get_time 工具调用因未初始化 locale 数据而崩溃

## 现象

AI 助手调用 `get_time` 工具后立即停止响应。控制台报错：
```
LocaleDataException: Locale data has not been initialized,
call initializeDateFormatting(<locale>).
```

Agent 获取时间后不再继续后续流程，用户看到对话中断。

## 触发条件

1. 打开 AI 助手页面
2. 发送任何消息使 Agent 调用 `get_time` 工具
3. `DateFormat('yyyy-MM-dd HH:mm:ss (EEEE)', 'zh_CN')` 抛出异常

同样的问题也潜伏在 `bot_agent_relay.dart` 和 `weather_providers.dart` 中。

## 根因分析

`DateFormat` 使用 `zh_CN` locale 时，需要预先调用 `initializeDateFormatting('zh_CN')` 加载 locale 数据。项目中从未调用过此初始化函数。

此外，`_executeGetTime` 没有 try-catch 保护，异常直接从 stream listener 抛出，导致整个 streaming 流程中断。

## 修复方案

1. **`main.dart`** — 在应用启动时调用 `await initializeDateFormatting('zh_CN')`，一次性覆盖所有使用 `zh_CN` locale 的 `DateFormat` 场景。

2. **`ai_import_page.dart`** — `_executeGetTime` 增加 try-catch，异常时将错误信息作为 tool result 返回给 Agent，而非崩溃。

## 验证方式

1. 启动应用，打开 AI 助手
2. 发送消息触发 `get_time` 调用
3. Agent 应正确返回含中文星期的时间字符串并继续对话

## 预防措施

- 使用带 locale 参数的 `DateFormat` 时，确保对应 locale 已在 `main()` 中初始化
- 所有 tool call 执行函数应有 try-catch 防护，避免单个工具错误中断整个 Agent 流程
