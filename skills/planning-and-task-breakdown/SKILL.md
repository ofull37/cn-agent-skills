---
name: planning-and-task-breakdown
description: 把工作拆分成有序的任务。当你有一份规格或清晰的需求、需要把工作拆分成可实现的任务时使用。当一个任务感觉太大、无法开始，当你需要估算范围，或当可能存在并行工作时使用。
---

# 规划与任务拆分

## 概述

把工作分解成小而可验证的任务，并带有明确的验收标准。好的任务拆分，是"能可靠完成工作的 agent"和"产出一团乱麻的 agent"之间的分水岭。每个任务都应该足够小，能在一次专注的会话中实现、测试和验证。

## 何时使用

- 你有一份规格，需要把它拆成可实现的单元
- 一个任务感觉太大或太模糊，无法开始
- 工作需要在多个 agent 或会话之间并行
- 你需要向人类传达范围
- 实现顺序并不明显

**何时不使用：** 范围明确的单文件变更，或规格已经包含定义良好的任务时。

## 规划流程

### 步骤 1：进入计划模式

在写任何代码之前，以只读模式运作：

- 阅读规格和代码库的相关部分
- 识别现有模式和约定
- 绘制组件之间的依赖关系
- 记录风险和未知项

**规划期间不要写代码。** 输出是一份保存到 `tasks/plan.md` 的计划文档和一份保存到 `tasks/todo.md` 的任务清单，而不是实现。

### 步骤 2：识别依赖图

绘制什么依赖什么：

```
Database schema
    │
    ├── API models/types
    │       │
    │       ├── API endpoints
    │       │       │
    │       │       └── Frontend API client
    │       │               │
    │       │               └── UI components
    │       │
    │       └── Validation logic
    │
    └── Seed data / migrations
```

实现顺序沿依赖图自底向上：先构建基础。

### 步骤 3：垂直切分

与其先构建全部数据库、再全部 API、再全部 UI——不如一次构建一条完整的功能路径：

**不好（水平切分）：**
```
Task 1: Build entire database schema
Task 2: Build all API endpoints
Task 3: Build all UI components
Task 4: Connect everything
```

**好（垂直切分）：**
```
Task 1: User can create an account (schema + API + UI for registration)
Task 2: User can log in (auth schema + API + UI for login)
Task 3: User can create a task (task schema + API + UI for creation)
Task 4: User can view task list (query + API + UI for list view)
```

每个垂直切片都交付可用、可测试的功能。

### 步骤 4：编写任务

每个任务遵循这个结构：

```markdown
## Task [N]: [Short descriptive title]

**Description:** One paragraph explaining what this task accomplishes.

**Acceptance criteria:**
- [ ] [Specific, testable condition]
- [ ] [Specific, testable condition]

**Verification:**
- [ ] Tests pass: [the repository's focused-test command]
- [ ] Build succeeds: [the repository's build command]
- [ ] Manual check: [description of what to verify]

**Dependencies:** [Task numbers this depends on, or "None"]

**Files likely touched:**
- `src/path/to/file.ts`
- `tests/path/to/test.ts`

**Estimated scope:** [Small: 1-2 files | Medium: 3-5 files | Large: 5+ files]
```

### 步骤 5：排序与设检查点

安排任务，使：

1. 依赖被满足（先构建基础）
2. 每个任务让系统保持在一个可工作的状态
3. 每 2-3 个任务之后设置验证检查点
4. 高风险任务靠前（尽早失败）

添加明确的检查点：

```markdown
## Checkpoint: After Tasks 1-3
- [ ] All tests pass
- [ ] Application builds without errors
- [ ] Core user flow works end-to-end
- [ ] Review with human before proceeding
```

## 任务体量估算指南

| 体量 | 文件数 | 范围 | 示例 |
|------|-------|-------|---------|
| **XS** | 1 | 单个函数或配置变更 | 添加一条校验规则 |
| **S** | 1-2 | 一个组件或端点 | 添加一个新的 API 端点 |
| **M** | 3-5 | 一个功能切片 | 用户注册流程 |
| **L** | 5-8 | 多组件功能 | 带筛选和分页的搜索 |
| **XL** | 8+ | **太大——需要进一步拆分** | — |

如果一个任务是 L 或更大，它应当被拆成更小的任务。agent 在 S 和 M 任务上表现最好。

**什么时候需要进一步拆分任务：**
- 它需要超过一次专注的会话（大约 2 小时以上的 agent 工作）
- 你无法用 3 条或更少的要点描述验收标准
- 它涉及两个或更多独立的子系统（例如认证和计费）
- 你发现自己在任务标题里写了"和"（这是一个任务其实是两个的迹象）

## 输出文件

- **计划文档：** 把实现计划保存到 `tasks/plan.md`。
- **任务清单：** 把清单式任务列表保存到 `tasks/todo.md`。

如果 `tasks/` 目录不存在就创建它。这些路径是 `/build` 命令和其他下游工具所期望的约定。

## 计划文档模板

```markdown
# Implementation Plan: [Feature/Project Name]

## Overview
[One paragraph summary of what we're building]

## Architecture Decisions
- [Key decision 1 and rationale]
- [Key decision 2 and rationale]

## Task List

### Phase 1: Foundation
- [ ] Task 1: ...
- [ ] Task 2: ...

### Checkpoint: Foundation
- [ ] Tests pass, builds clean

### Phase 2: Core Features
- [ ] Task 3: ...
- [ ] Task 4: ...

### Checkpoint: Core Features
- [ ] End-to-end flow works

### Phase 3: Polish
- [ ] Task 5: ...
- [ ] Task 6: ...

### Checkpoint: Complete
- [ ] All acceptance criteria met
- [ ] Ready for review

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk] | [High/Med/Low] | [Strategy] |

## Open Questions
- [Question needing human input]
```

## 并行化机会

当有多个 agent 或会话可用时：

- **可以安全并行：** 独立的功能切片、为已实现功能写的测试、文档
- **必须串行：** 数据库迁移、共享状态变更、依赖链
- **需要协调：** 共享 API 契约的功能（先定义契约，再并行化）

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| "我边做边想" | 这就是你最后得到一团乱麻和返工的方式。10 分钟的规划能省下数小时。 |
| "任务很明显" | 无论如何都要写下来。明确的任务会浮出隐藏的依赖和被遗忘的边缘情况。 |
| "规划是额外开销" | 规划本身就是任务。没有计划的实现只是打字。 |
| "我能把一切都记在脑子里" | 上下文窗口是有限的。书面计划能跨越会话边界和压缩存活下来。 |

## 危险信号

- 没有书面任务清单就开始实现
- 说"实现这个功能"却没有验收标准的任务
- 计划中没有验证步骤
- 所有任务都是 XL 体量
- 任务之间没有检查点
- 没有考虑依赖顺序

## 验证

在开始实现之前，确认：

- [ ] 每个任务都有验收标准
- [ ] 每个任务都有一个验证步骤
- [ ] 任务依赖已被识别并正确排序
- [ ] 没有任务改动超过约 5 个文件
- [ ] 主要阶段之间存在检查点
- [ ] 人类已经评审并批准了计划

## 另请参阅

验收标准是逐任务层面的，回答"我们是否构建了正确的东西？"。它们坐落在项目级的"完成定义"（Definition of Done）之上——那是每个任务在算作完成之前必须越过的常设门槛。参见 `references/definition-of-done.md`。
