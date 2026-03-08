# Bot Relay 合并流式 tool call 逻辑错误

## 现象

Telegram Bot 与 AI Agent 对话触发工具调用时，可能出现重复执行、参数拼接错乱或重复提示用户确认。

## 触发条件

1. Telegram Bot 已启用 AI Agent 中继
2. AI 返回流式 tool call，尤其是多次 delta 或多工具调用场景

## 根因分析

`apps/mobile/lib/services/bot_agent_relay.dart` 的 `_mergeToolCallDeltas()` 将 `toolCall.id` 误当作可解析的数字下标使用，而真实 tool call id 并不是这种格式。结果是同一调用可能被重复追加，或把 `name/arguments` 错误拼接。

## 修复方案

应按协议中的稳定键合并 tool call（例如流式返回里的 index 或真实 id），并确保同一工具调用只聚合一次，参数按 delta 顺序追加。

## 验证方式

1. 让 AI 返回带 `query_courses` 或 `add_task` 的流式 tool call
2. 观察 relay 处理结果
3. 预期：每个工具调用只执行一次，参数完整且不重复

## 预防措施

- 为 Bot relay 增加流式 tool call 单元测试
- 严格按上游协议字段语义做聚合
- 对多工具调用和分片参数场景补回归测试
