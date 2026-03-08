# 左右滑动无法切换周

## 现象

课程表页面左右滑动不再能切换周次，手势完全无响应。AppBar 上的箭头按钮仍可正常切换。

## 触发条件

1. 进入课程表页面（周视图）
2. 在课表区域左右滑动
3. 周次不变化

## 根因分析

`schedule_page.dart` 的 body 使用 `GestureDetector(onHorizontalDragEnd:)` 包裹子视图来检测水平滑动。但 `WeekGridView` 内部嵌套了 `SingleChildScrollView(scrollDirection: Axis.horizontal)`，该 ScrollView 在手势竞技场中优先消费水平拖拽事件，导致外层 `GestureDetector` 永远无法获胜。

此外，commit 81bcc74 为课程格子添加了 `GestureDetector(behavior: HitTestBehavior.opaque)` 扩大点击区域，进一步阻断了手势向上传递。

两层手势拦截叠加，使得外层的周切换 `onHorizontalDragEnd` 完全失效。

## 修复方案

将外层 `GestureDetector` + 子视图模式替换为 `PageView.builder`：

- `PageView` 天然支持左右滑动翻页，不与子视图的内部滚动冲突
- `onPageChanged` 回调同步更新 `selectedWeekProvider`
- AppBar 箭头按钮通过 `PageController.animateToPage` 同步页面

变更文件：`apps/mobile/lib/features/schedule/schedule_page.dart`
- `ConsumerWidget` → `ConsumerStatefulWidget`（持有 `PageController`）
- body 从 `GestureDetector` 改为 `PageView.builder`
- 按钮/芯片切换周时通过 `addPostFrameCallback` 同步 PageView 位置

## 验证方式

1. 进入周视图，左右滑动 → 周次正确切换
2. 点击 AppBar 箭头 → 页面跟随滑动
3. 点击"本周"芯片 → 页面跳转到对应周
4. 切换到时间流视图 → 滑动同样可切换周
5. 第 1 周左滑、最后一周右滑 → 不超出范围

## 预防措施

- 避免在含有可滚动子视图的场景中使用外层 `GestureDetector` 检测同方向拖拽
- 需要翻页式交互时优先使用 `PageView`
