# cancel() 关闭共享 HTTP Client 导致后续请求失败

## 现象

未开启代理时，AI 对话取消后再次发送消息报错：
`ClientException: HTTP request failed. Client is already closed.`

## 触发条件

1. 不启用网络代理
2. 进入 AI 对话，发送消息
3. 在 AI 回复流式输出期间点击取消
4. 再次发送消息 → 报错 Client is already closed

## 根因分析

`AiAgentServiceImpl.cancel()` 直接调用 `_client.close()` 关闭了由 `httpClientProvider` 注入的共享 `http.Client` 实例。关闭后：

1. `_client` 被替换为新的 `http.Client()`（无代理配置）
2. 其他持有同一 client 引用的服务（Bot、天气等）后续请求直接报 "Client is already closed"
3. 即使 AiAgent 自身的新 client 也丢失了代理配置

## 修复方案

不再关闭共享的 `_client`。改为每次流式请求创建独立的 `_activeStreamClient`：

- `sendStreaming()` 开始时 `_activeStreamClient = http.Client()`
- `cancel()` 仅关闭 `_activeStreamClient`，不触碰共享 `_client`
- `finally` 块中清理 `_activeStreamClient`

变更文件：`packages/data/lib/src/services/ai_agent_service_impl.dart`

## 验证方式

1. 不开代理 → AI 对话 → 取消 → 再次发送 → 正常响应
2. 开代理 → 同上流程 → 正常响应
3. 取消后其他服务（Bot 测试连接等）正常工作

## 预防措施

- 注入的共享资源（http.Client、数据库连接等）不应被消费方关闭
- 需要取消网络请求时，使用独立的、可丢弃的 client 实例
