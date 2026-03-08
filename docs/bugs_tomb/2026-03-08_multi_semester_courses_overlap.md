# 启动时多学期课程重叠显示

## 现象

App 刚启动、未手动切换学期时，课程表同时显示所有学期的课程，导致课程卡片重叠。

## 触发条件

1. 数据库中存在多个学期，每个学期有各自的课程
2. 未设置 `activeSemesterId`（首次使用或数据被清除后）
3. 启动 App → 课程表页面显示所有学期的课程

## 根因分析

`watchCoursesProvider` 在 `activeId == null` 时直接返回所有课程（不做过滤）：

```dart
if (activeId == null) return courses; // ← 返回全部
```

而 `activeSemesterIdProvider` 仅从 `SettingsDao.watchValue('activeSemesterId')` 读取，无自动选择逻辑。首次启动或未显式设置时，`activeId` 为 null，导致所有学期课程混合显示。

## 修复方案

1. **`activeSemesterIdProvider`**：当 `activeSemesterId` 为 null 时，自动选择第一个可用学期并写入设置
2. **`watchCoursesProvider`**：当 `activeId` 为 null 时返回空列表而非全部课程，作为兜底保护

变更文件：
- `apps/mobile/lib/providers/semester_providers.dart`
- `apps/mobile/lib/providers/course_providers.dart`

## 验证方式

1. 清除 `activeSemesterId` 设置 → 启动 App → 自动选中第一个学期，仅显示该学期课程
2. 只有一个学期 → 正常显示
3. 无学期 → 显示空状态
4. 手动切换学期 → 正常过滤

## 预防措施

- 查询关联数据时，外键为空应返回空集而非全集
- 需要"当前选中"语义的设置项应有自动回退逻辑
