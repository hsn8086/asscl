# WebDAV 同步：保存后立即操作失败 + 设置未备份

## 现象

1. **保存配置后立即点上传/下载/测试连接**，提示"请先填写完整的 WebDAV 配置"。必须退出页面重新进入才能操作。
2. **备份缺失大量设置**：AI 配置（baseUrl、apiKey、modelName）、语音配置、Telegram Bot 配置、代理配置、节次总数/预设 ID 等均未包含在备份中，恢复后这些设置丢失。

## 触发条件

### Bug 1（保存后立即失败）
1. 进入 WebDAV 设置页或引导页
2. 填写 WebDAV 配置
3. 不退出页面，直接点"测试连接"/"上传备份"/"下载恢复"

### Bug 2（设置未备份）
1. 配置好 AI、语音、Telegram 等设置
2. 上传备份
3. 在新设备恢复 → 所有设置丢失

## 根因分析

### Bug 1
`_save()` 调用 `ref.invalidate(webDavConfigProvider)` 使 `FutureProvider` 失效。紧接着 `ref.read(syncServiceProvider)` 读取同步服务，但 `syncServiceProvider` 依赖 `webDavConfigProvider.valueOrNull`——此时 `FutureProvider` 尚未重新解析完成，`valueOrNull` 返回 `null`，导致 `syncServiceProvider` 返回 `null`。

引导页用了 `Future.delayed(100ms)` 试图规避，但这是不可靠的竞态补丁。

### Bug 2
`_exportAll()` 只导出了 6 张数据表 + `activeSemesterId`，完全没有读取 settings 表中的其他配置项。

## 修复方案

### Bug 1
在 `webdav_settings_page.dart` 和 `onboarding_page.dart` 中新增 `_buildSyncService()` 方法，直接从表单当前值构建 `WebDavConfig` → `WebDavService` → `SyncService`，绕过异步 Provider 链。

### Bug 2
- `SettingsDao` 新增 `getAll()` 方法，返回所有设置的 `Map<String, String>`
- `_exportAll()` 导出全部设置（排除 WebDAV 凭据、`onboardingCompleted`、`weatherAlertLastDate` 等设备相关项）
- `_importAll()` 恢复设置（同样排除上述 key）
- 备份版本从 v1 升级到 v2，保持对 v1 备份的向后兼容

## 验证方式

1. 填写 WebDAV 配置后**不退出页面**，直接点测试连接 → 应成功
2. 配置 AI / 语音 / Telegram → 上传备份 → 清空本地 → 下载恢复 → 设置应恢复
3. 使用 v1 格式的旧备份下载恢复 → 应正常导入（仅恢复 activeSemesterId）
4. `flutter test` 全部通过

## 预防措施

- 当需要在 `ref.invalidate()` 后立即使用 Provider 值时，直接构建对象而非读取 Provider
- 新增设置项时检查是否需要加入备份排除列表
