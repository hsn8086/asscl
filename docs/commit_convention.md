# 提交规范（Conventional Commits）

本项目采用 Conventional Commits 规范，统一提交信息格式，便于生成变更日志与自动化检查。

## 格式

```
<类型>(<范围>): <简短描述>

[可选: 详细说明]

[可选: 关联信息]
```

## 类型定义

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(timetable): 添加课程重复规则` |
| `fix` | Bug 修复 | `fix(reminder): 修复重复提醒未触发` |
| `docs` | 文档变更 | `docs: 更新提交规范说明` |
| `test` | 新增/修改测试 | `test(tasks): 补充任务排序单测` |
| `refactor` | 重构（不改变行为） | `refactor(data): 优化仓库实现` |
| `perf` | 性能优化 | `perf(storage): 降低启动加载耗时` |
| `chore` | 构建/依赖/工具 | `chore(deps): 升级 flutter 依赖` |
| `style` | 格式化/样式 | `style: 统一缩进` |
| `ci` | CI/CD 变更 | `ci: 添加测试覆盖率检查` |
| `revert` | 回滚提交 | `revert: 回滚 abc123` |

## 范围（scope）建议

优先使用模块名或目录名：

```
apps, packages, services, docs, tests, infra, config
```

更细粒度示例：

```
apps/mobile, packages/domain, packages/data, packages/presentation
```

## 示例

```
feat(packages/domain): 添加 Task 聚合根

新增 Task 实体与状态流转规则，支持子任务与优先级。

Closes #42
```

```
fix(services/sync): 修复增量同步遗漏已删除记录

原因：查询条件缺少 deleted_at 字段判断。
解决：在同步查询中添加 deleted_at 范围过滤。

Fixes #89
Bug-tomb: docs/bugs_tomb/2024-02-sync-deletion.md
```

## 最佳实践

1. 使用祈使语气：`添加` 而非 `添加了`。
2. 首行不超过 50 字符（中文约 25 字）。
3. 优先说明“为什么”，具体实现可通过 diff 查看。
4. 需要破坏性变更时，必须在 footer 添加：`BREAKING CHANGE: ...`。
