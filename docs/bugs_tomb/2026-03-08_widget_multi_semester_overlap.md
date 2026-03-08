# 微件启动时多学期课程重叠

## 现象

Android 桌面微件（NextClass / TodaySchedule）在应用刚启动时显示所有学期的课程，导致课程重叠。

## 触发条件

1. 用户有多个学期，每个学期有课程
2. 冷启动应用（或从后台恢复）
3. 桌面微件立即刷新，但显示了所有学期的课程

## 根因分析

`refreshWidgets()` 在 `App.initState()` 中同步调用，此时 `activeSemesterProvider`（依赖 `activeSemesterIdProvider` 这个 `StreamProvider`）尚未解析完成，返回 `null`。

`WidgetService.updateWidgets()` 在 `semesterId == null` 时不做学期过滤，导致所有学期的课程全部推送到微件。

```dart
// 修复前：同步读取，启动时 semester 为 null
void refreshWidgets(dynamic ref) {
  final semester = ref.read(activeSemesterProvider); // null at startup!
  ref.read(widgetServiceProvider).updateWidgets(
    semesterId: semester?.id,  // null → 不过滤
    ...
  );
}
```

## 修复方案

将 `refreshWidgets` 改为 `async`，使用 `activeSemesterIdProvider.future` 等待学期 ID 解析完成后再推送微件数据：

```dart
Future<void> refreshWidgets(dynamic ref) async {
  final activeId = await ref.read(activeSemesterIdProvider.future);
  // ... 使用 activeId 过滤
}
```

变更文件：`apps/mobile/lib/providers/widget_providers.dart`

## 验证方式

1. 配置多个学期，各有课程
2. 冷启动应用 → 桌面微件只显示当前活跃学期的课程
3. 从后台恢复 → 微件正确刷新

## 预防措施

- 依赖 `StreamProvider` 的数据不要在启动时同步读取，应 `await .future`
- 微件更新应确保数据完全就绪后再推送
