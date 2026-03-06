# AGENT 指南

本文件用于说明该项目内 agent 的工作方式与约定。请先阅读并遵循。

## 文档索引

- 项目结构: `docs/project_structure.md`
- 产品需求(PRD): `docs/PRD.md`
- Bug 复盘规范: `docs/bugs_tomb/README.md`

## 基本工作流

1. 先阅读 `docs/project_structure.md`，确认模块边界与当前结构。
2. 任何功能/修复都必须有测试覆盖；若缺失测试，先补测试再实现功能。
3. 交付前必须跑完测试并确保通过。
4. 产生设计决策、模块变更或接口变更时，同步更新文档。
5. 遇到 Bug，按 `docs/bugs_tomb/README.md` 记录复盘。

## 变更约束

- 非必要不改动 `.opencode/` 目录内内容。
- 新增模块后必须更新 `docs/project_structure.md`。

## 提交规范

本项目采用 Conventional Commits 规范，详见：`docs/commit_convention.md`。

### 快速参考

- 功能: `feat(scope): 描述`
- 修复: `fix(scope): 描述`
- 文档: `docs: 描述`
- 测试: `test(scope): 描述`
- 重构: `refactor(scope): 描述`

## 计划文档

计划文档目录：`docs/plans/`。

### 子代理执行要求

1. 开始实现前，必须阅读 PRD 与上述核心计划。
2. 如发现计划与实现冲突，先在计划中提出变更建议再推进。
3. 每个模块交付必须附带测试并通过。
