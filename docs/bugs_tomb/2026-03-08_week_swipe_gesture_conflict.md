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

分两步修复：

### 第一步：外层改用 PageView

将外层 `GestureDetector` + 子视图模式替换为 `PageView.builder`：

- `PageView` 天然支持左右滑动翻页
- `onPageChanged` 回调同步更新 `selectedWeekProvider`
- AppBar 箭头按钮通过 `ref.listenManual` + `PageController.animateToPage` 同步页面
- 每页传递各自的 `weekNumber` 参数给子视图

变更文件：
- `apps/mobile/lib/features/schedule/schedule_page.dart`
- `apps/mobile/lib/features/schedule/widgets/week_grid_view.dart`
- `apps/mobile/lib/features/schedule/widgets/time_stream_view.dart`

### 第二步：移除内部水平 ScrollView

仅用 `PageView` 仍不够 —— `WeekGridView` 内部的 `SingleChildScrollView(scrollDirection: Axis.horizontal)` 仍会在手势竞技场中与 `PageView` 冲突并优先消费水平拖拽事件。

移除内部水平 `SingleChildScrollView`，格子宽度直接按屏幕宽度等分（去掉 `cellWidth.clamp(48.0, 80.0)` 的最小值 clamp），确保内容不超出屏幕。

变更文件：`apps/mobile/lib/features/schedule/widgets/week_grid_view.dart`

## 验证方式

1. 进入周视图，左右滑动 → 周次正确切换
2. 点击 AppBar 箭头 → 页面跟随滑动
3. 点击"本周"芯片 → 页面跳转到对应周
4. 切换到时间流视图 → 滑动同样可切换周
5. 第 1 周左滑、最后一周右滑 → 不超出范围

## 预防措施

- 避免在含有可滚动子视图的场景中使用外层 `GestureDetector` 检测同方向拖拽
- 需要翻页式交互时优先使用 `PageView`
- **同方向嵌套可滚动组件**（如 PageView 内含水平 ScrollView）会导致手势冲突，内层总是优先消费。要么移除内层滚动，要么确保内层使用 `NeverScrollableScrollPhysics`
