# AI 流式请求绕过统一 HTTP Client 与代理配置

## 现象

非流式 AI 请求可正常使用注入的 HTTP client，但流式请求未走统一注入链路，导致代理、Mock 和统一网络配置失效。

## 触发条件

1. 配置了自定义 HTTP client 或代理
2. 调用 AI Agent 的流式接口 `sendStreaming()`

## 根因分析

`packages/data/lib/src/services/ai_agent_service_impl.dart` 中，普通请求使用构造时注入的 `_client`，但流式请求会新建 `http.Client()` 赋给 `_activeStreamClient`，没有复用注入 client 的代理配置和测试替身。

## 修复方案

流式请求也应基于统一注入的网络能力实现，至少要保证代理配置、证书策略和测试 Mock 行为一致。若必须为取消请求创建独立 client，应同步继承代理与网络配置。

## 验证方式

1. 注入一个可观测的 MockClient 或带代理的 client
2. 调用 `send()` 与 `sendStreaming()`
3. 预期：两者都命中同一套网络注入链路

## 预防措施

- 网络服务禁止在内部偷偷新建裸 `http.Client()`
- 为代理场景补充 AI streaming 测试
- 对所有外部请求统一走 provider 注入
