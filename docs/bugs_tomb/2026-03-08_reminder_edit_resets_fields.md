# 编辑提醒会重置启用状态与关联字段

## 现象

编辑已有提醒后，原本已禁用的提醒会被重新启用，且可能丢失原有的关联实体 ID 与创建时间。

## 触发条件

1. 已存在一个提醒
2. 该提醒包含 `isActive=false` 或 `linkedEntityId`
3. 进入编辑页后保存

## 根因分析

`apps/mobile/lib/features/reminders/reminder_form_page.dart` 在保存编辑结果时重新构造了 `Reminder`，但没有保留旧对象的 `isActive`、`linkedEntityId`、`createdAt` 等字段，导致保存后被默认值覆盖。

## 修复方案

编辑场景应先读取原对象，再只覆盖用户可编辑字段，保留 `createdAt`、`linkedEntityId`、`isActive` 等非表单字段。

## 验证方式

1. 创建一个已禁用或带关联 ID 的提醒
2. 进入编辑页，仅修改标题后保存
3. 预期：启用状态、关联 ID、创建时间保持不变

## 预防措施

- 为提醒编辑场景补回归测试
- 对表单提交区分“新建对象”和“编辑对象”两条路径
- 对非表单字段采用 copyWith 而非重新手写构造
