# 敏感配置明文存储在 settings 表

## 现象

AI Key、Telegram Bot Token、语音接口 Key 等敏感信息会直接以明文形式写入本地数据库。

## 触发条件

1. 用户在设置页保存 AI、Bot、语音或代理配置
2. 读取 SQLite 数据库中的 `settings_table`

## 根因分析

`packages/data/lib/src/database/tables/settings_table.dart` 仅使用 `key/value` 文本列，`SettingsDao` 直接以字符串形式保存和读取配置。上层设置页面直接写入密钥，没有使用 Android Keystore / iOS Keychain 等安全存储。

## 修复方案

将 API Key、Bot Token 等敏感字段迁移到安全存储；数据库中仅保留非敏感配置，或保存加密后的引用信息。文档中关于“已加密”的描述也应同步修正。

## 验证方式

1. 在设置页保存任一密钥
2. 导出或查看本地数据库
3. 预期：数据库中不应出现明文密钥

## 预防措施

- 敏感配置统一走系统安全存储
- 为安全存储补充集成测试或最小验证脚本
- 文档中的安全声明必须与实现一致
