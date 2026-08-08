---
name: incremental-implementation
description: 以薄垂直切片增量地交付变更，并支持在功能开关后发布。当实现任何涉及多个文件的特性或变更时使用。当你即将一次性写大量代码，或当一个任务感觉太大、无法一步落地时使用。
---

# 增量实现

## 概述

用细薄的垂直切片来构建——实现一小块、测试它、验证它，然后扩展。避免一次性实现整个功能。每个增量都应当让系统保持在一个可工作、可测试的状态。这是让大型功能变得可控的执行纪律。

## 何时使用

- 实现任何多文件变更
- 根据任务拆分构建一个新功能
- 重构现有代码
- 任何你想在测试前写超过约 100 行代码的时候

**何时不使用：** 范围本就已经最小的单文件、单函数变更。

## 增量循环

```
┌──────────────────────────────────────┐
│                                      │
│   Implement ──→ Test ──→ Verify ──┐  │
│       ▲                           │  │
│       └───── Commit ◄─────────────┘  │
│              │                       │
│              ▼                       │
│          Next slice                  │
│                                      │
└──────────────────────────────────────┘
```

对每个切片：

1. **实现** 最小的一整块功能
2. **测试** —— 运行测试套件（如果没有测试就写一个）
3. **验证** —— 确认切片按预期工作（测试通过、构建成功、手动检查）
4. **提交** —— 用一条描述性消息保存你的进度（原子提交的指南参见 `git-workflow-and-versioning`）
5. **进入下一个切片** —— 继续前进，不要重新开始

## 切分策略

### 垂直切分（首选）

构建一条贯通技术栈的完整路径：

```
Slice 1: Create a task (DB + API + basic UI)
    → Tests pass, user can create a task via the UI

Slice 2: List tasks (query + API + UI)
    → Tests pass, user can see their tasks

Slice 3: Edit a task (update + API + UI)
    → Tests pass, user can modify tasks

Slice 4: Delete a task (delete + API + UI + confirmation)
    → Tests pass, full CRUD complete
```

每个切片都交付端到端可用的功能。

### 契约优先切分

当前后端和前端需要并行开发时：

```
Slice 0: Define the API contract (types, interfaces, OpenAPI spec)
Slice 1a: Implement backend against the contract + API tests
Slice 1b: Implement frontend against mock data matching the contract
Slice 2: Integrate and test end-to-end
```

### 风险优先切分

先啃风险最大或最不确定的部分：

```
Slice 1: Prove the WebSocket connection works (highest risk)
Slice 2: Build real-time task updates on the proven connection
Slice 3: Add offline support and reconnection
```

如果切片 1 失败，你在投入切片 2 和 3 之前就会发现。

## 实现规则

### 规则 0：简洁优先

在写任何代码之前，问："能工作的最简单的东西是什么？"

写完代码后，用这些检查来审视它：
- 能用更少的行完成吗？
- 这些抽象是否配得上它们带来的复杂度？
- 一位资深工程师看到这个，会不会说"你为什么不只是……"？
- 我是在为假设的未来需求构建，还是为当前任务构建？

```
SIMPLICITY CHECK:
✗ Generic EventBus with middleware pipeline for one notification
✓ Simple function call

✗ Abstract factory pattern for two similar components
✓ Two straightforward components with shared utilities

✗ Config-driven form builder for three forms
✓ Three form components
```

三行相似的代码，好过一次过早的抽象。先实现朴素、明显正确的版本。只有在正确性被测试证明之后才做优化。

### 规则 0.5：范围纪律

只触碰任务要求的东西。

不要：
- "顺带清理"与你的变更相邻的代码
- 重构你并不修改的文件中的 import
- 删除你不完全理解的注释
- 添加规格里没有的、因为"看起来有用"的功能
- 把你只是在阅读的文件里的语法现代化

如果你注意到任务范围之外有值得改进的东西，记下来——不要修：

```
NOTICED BUT NOT TOUCHING:
- src/utils/format.ts has an unused import (unrelated to this task)
- The auth middleware could use better error messages (separate task)
→ Want me to create tasks for these?
```

### 规则 1：一次只做一件事

每个增量只改变一个逻辑上的东西。不要混合关注点：

**不好：** 一个提交既添加新组件，又重构现有组件，还更新构建配置。

**好：** 三个独立提交——每个对应一项变更。

### 规则 2：保持可编译

每个增量之后，项目必须能构建，现有测试必须通过。不要在两个切片之间把代码库留在损坏状态。

### 规则 3：未完成功能使用功能开关

如果某个功能还没准备好面向用户，但你需要合并增量：

```typescript
// Feature flag for work-in-progress
const ENABLE_TASK_SHARING = process.env.FEATURE_TASK_SHARING === 'true';

if (ENABLE_TASK_SHARING) {
  // New sharing UI
}
```

这让你能把小的增量合并到主分支，而不暴露未完成的工作。

### 规则 4：安全的默认值

新代码应当默认采用安全、保守的行为：

```typescript
// Safe: disabled by default, opt-in
export function createTask(data: TaskInput, options?: { notify?: boolean }) {
  const shouldNotify = options?.notify ?? false;
  // ...
}
```

### 规则 5：利于回滚

每个增量都应当可以独立回退：

- 增量式变更（新文件、新函数）容易回退
- 对现有代码的修改应当最小且聚焦
- 数据库迁移应当有对应的回滚迁移
- 避免在一个提交里删除某样东西又在同一个提交里替换它——把它们分开

## 与 agent 协作

当你指挥一个 agent 增量实现时：

```
"Let's implement Task 3 from the plan.

Start with just the database schema change and the API endpoint.
Don't touch the UI yet — we'll do that in the next increment.

After implementing, run the repository's test and build commands to
verify nothing is broken."
```

对每个增量，明确什么是范围内的、什么不在范围内。

## 增量清单

每个增量之后，用仓库自己的命令验证（参见 test-driven-development 技能的"先了解技术栈"章节）：

- [ ] 变更只做一件事，并且完整地做好了
- [ ] 所有现有测试仍然通过（仓库的测试命令：`npm test`、`./gradlew test`、`pytest`、……）
- [ ] 构建成功（仓库的构建命令）
- [ ] 在技术栈有类型检查的情况下，类型检查通过（`npx tsc --noEmit`、`mypy`、……）
- [ ] 代码规范检查通过（仓库的 lint 命令）
- [ ] 新功能按预期工作
- [ ] 变更用一条描述性消息提交

**注意：** 在每次可能影响它的变更之后运行各验证命令。成功运行之后，除非代码自那以来已改变，否则不要重复同一条命令——在未变化的代码上重复运行不会增加信息。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| "我到最后再一起测试" | Bug 会相互叠加。切片 1 里的一个 bug 会让切片 2-5 全错。每个切片都要测试。 |
| "一次性全做完更快" | 它*感觉*更快，直到某样东西坏了，而你找不到是 500 行变更里的哪一行导致的。 |
| "这些改动太小了，不值得单独提交" | 小提交是免费的。大提交会隐藏 bug，并让回滚变得痛苦。 |
| "我之后再添加功能开关" | 如果功能不完整，它就不应当对用户可见。现在就加开关。 |
| "这个重构足够小，可以一起带上" | 重构和功能混在一起，会让两者都更难评审和调试。把它们分开。 |
| "让我再跑一次构建命令，确保一下" | 成功运行之后，除非代码自那以来已改变，否则重复同一条命令不会增加任何东西。在后续编辑之后再运行它，而不是作为一种安慰。 |

## 危险信号

- 写了超过 100 行代码还没跑过测试
- 一个增量里包含多个无关的变更
- "让我顺便也把这个加上"的范围扩张
- 为了更快而跳过测试/验证步骤
- 增量之间构建或测试损坏
- 大量未提交的变更不断堆积
- 在第三个用例要求之前就构建抽象
- 在"反正我在改这个文件"时触碰任务范围之外的文件
- 为一次性操作创建新的工具文件
- 没有任何中间的代码变更，就连续两次运行同一条构建/测试命令

## 验证

完成一个任务的所有增量之后：

- [ ] 每个增量都被单独测试并提交
- [ ] 完整测试套件通过
- [ ] 构建干净
- [ ] 功能按规格端到端工作
- [ ] 没有遗留未提交的变更

## 另请参阅

逐增量验证是局部检查。在宣布一个任务完成之前，应用项目级的"完成定义"（Definition of Done）作为最终闸门——那是每个增量无论任务如何都必须越过的常设门槛。参见 `references/definition-of-done.md`。
