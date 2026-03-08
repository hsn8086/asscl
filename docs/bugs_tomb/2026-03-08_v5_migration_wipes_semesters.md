# v5 数据迁移会清空已有学期并重绑课程

## 现象

从 schema v4 升级到 v5 后，已有学期数据被删除，所有课程被重新绑定到一个新建的默认学期。

## 触发条件

1. 旧数据库版本为 v4
2. 数据库中存在多个学期和已绑定学期的课程
3. 使用当前版本应用打开数据库，触发迁移到 v5

## 根因分析

`packages/data/lib/src/database/app_database.dart` 的 `from < 5` 迁移分支直接执行了 `DELETE FROM semesters_table`，随后创建新的默认学期，并将 `courses_table.semester_id` 与 `activeSemesterId` 全部重写到该新学期。

## 修复方案

应编写真正的数据修复迁移，而不是全表删除。若只需修复日期字段格式，应逐条转换旧学期记录的 `start_date`/`created_at`，并保持课程与活跃学期关联不变。

## 验证方式

1. 构造一个 v4 数据库，包含至少 2 个学期和多门课程
2. 运行迁移到 v5
3. 检查 `semesters_table`、`courses_table.semester_id`、`settings.activeSemesterId`
4. 预期：原学期和课程归属保持不变

## 预防措施

- 为每个 schema 升级编写 migration 测试
- 禁止在迁移中无条件删除用户业务数据
- 迁移脚本必须显式区分“修复格式”和“重置数据”
