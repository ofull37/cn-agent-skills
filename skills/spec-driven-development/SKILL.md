---
name: spec-driven-development
description: 在编码之前创建规格。当开始一个新项目、功能或重大变更且尚无规格时使用。当需求不清楚、含糊或只存在于一个模糊想法中时使用。
---

# 规格驱动开发

## 概述

在写任何代码之前，先写一份结构化的规格。这份规格是你和人类工程师之间共享的真相源——它定义了我们构建什么、为什么构建，以及我们如何知道它完成了。没有规格的代码就是猜测。

## 何时使用

- 开始一个新项目或新功能
- 需求含糊或不完整
- 变更涉及多个文件或模块
- 你即将做出一个架构决策
- 任务需要超过 30 分钟来实现

**何时不使用：** 单行修复、错别字修正，或需求明确且自包含的变更。

## 带门禁的工作流

规格驱动开发有四个阶段。在当前阶段被验证之前，不要推进到下一个阶段。

```
SPECIFY ──→ PLAN ──→ TASKS ──→ IMPLEMENT
   │          │        │          │
   ▼          ▼        ▼          ▼
 Human      Human    Human      Human
 reviews    reviews  reviews    reviews
```

### 阶段 1：规格化

从高层愿景开始。向人类提出澄清问题，直到需求具体化。

**立即浮出假设。** 在写任何规格内容之前，列出你在假设什么：

```
ASSUMPTIONS I'M MAKING:
1. This is a web application (not native mobile)
2. Authentication uses session-based cookies (not JWT)
3. The database is PostgreSQL (based on existing Prisma schema)
4. We're targeting modern browsers only (no IE11)
→ Correct me now or I'll proceed with these.
```

不要默默填补含糊的需求。规格的全部目的就是在代码被写出来*之前*浮出误解——假设是最危险的一种误解。

**写一份覆盖这六个核心领域的规格文档：**

1. **目标** —— 我们在构建什么、为什么？用户是谁？成功长什么样？

2. **命令** —— 带标志的完整可执行命令，而不仅仅是工具名称。
   ```
   Build: npm run build
   Test: npm test -- --coverage
   Lint: npm run lint --fix
   Dev: npm run dev
   ```

3. **项目结构** —— 源代码在哪里、测试放哪里、文档归哪里。
   ```
   src/           → Application source code
   src/components → React components
   src/lib        → Shared utilities
   tests/         → Unit and integration tests
   e2e/           → End-to-end tests
   docs/          → Documentation
   ```

4. **代码风格** —— 一个真实的代码片段比三段描述更能展示你的风格。包括命名约定、格式化规则和良好输出的示例。

5. **测试策略** —— 用什么框架、测试放在哪里、覆盖率期望、哪些关注点用哪级测试。

6. **边界** —— 三层体系：
   - **始终要做：** 提交前运行测试、遵循命名约定、校验输入
   - **先询问：** 数据库模式变更、添加依赖、更改 CI 配置
   - **绝不：** 提交机密、编辑 vendor 目录、未经批准移除失败的测试

**规格模板：**

```markdown
# Spec: [Project/Feature Name]

## Objective
[What we're building and why. User stories or acceptance criteria.]

## Tech Stack
[Framework, language, key dependencies with versions]

## Commands
[Build, test, lint, dev — full commands]

## Project Structure
[Directory layout with descriptions]

## Code Style
[Example snippet + key conventions]

## Testing Strategy
[Framework, test locations, coverage requirements, test levels]

## Boundaries
- Always: [...]
- Ask first: [...]
- Never: [...]

## Success Criteria
[How we'll know this is done — specific, testable conditions]

## Open Questions
[Anything unresolved that needs human input]
```

**把指示重构成成功标准。** 收到模糊的需求时，把它们翻译成具体的条件：

```
REQUIREMENT: "Make the dashboard faster"

REFRAMED SUCCESS CRITERIA:
- Dashboard LCP < 2.5s on 4G connection
- Initial data load completes in < 500ms
- No layout shift during load (CLS < 0.1)
→ Are these the right targets?
```

这让你能朝着一个清晰的目标循环、重试和解决问题，而不是去猜"更快"是什么意思。

### 阶段 2：规划

有了经过验证的规格，生成一份技术实现计划：

1. 识别主要组件及其依赖
2. 确定实现顺序（必须先构建什么）
3. 记录风险与缓解策略
4. 识别什么可以并行构建，什么必须串行
5. 在阶段之间定义验证检查点

> 这些步骤背后的依赖图映射和垂直切分机制，遵循 `planning-and-task-breakdown`；它是权威来源。上面的要点是一个轻量摘要；如果两者出现分歧，以 `planning-and-task-breakdown` 为准。
>
> **输出约定：** 按 `/plan` 命令的约定，把计划保存到 `tasks/plan.md`，把任务清单保存到 `tasks/todo.md`。如果 `tasks/` 不存在就创建它。下游命令（`/build` 等）期望这些路径。

计划应当是可供评审的：人类应当能读到它并说"是，这是正确的方法"或"不，把 X 改掉"。

### 阶段 3：任务

把计划拆分成离散的、可实现的任务：

- 每个任务应能在一次专注的会话中完成
- 每个任务有明确的验收标准
- 每个任务包含一个验证步骤（测试、构建、手动检查）
- 任务按依赖排序，而不是按感知的重要性排序
- 没有任务应当需要改动超过约 5 个文件

> 完整的任务体量估算和依赖排序机制，遵循 `planning-and-task-breakdown`；它是权威来源。下面的模板是一个轻量的内联形式；如果两者出现分歧，以 `planning-and-task-breakdown` 为准。

**任务模板：**
```markdown
- [ ] Task: [Description]
  - Acceptance: [What must be true when done]
  - Verify: [How to confirm — test command, build, manual check]
  - Files: [Which files will be touched]
```

### 阶段 4：实现

按照 `skills/incremental-implementation/SKILL.md`（`incremental-implementation`）和 `skills/test-driven-development/SKILL.md`（`test-driven-development`）一次执行一个任务。使用 `skills/context-engineering/SKILL.md`（`context-engineering`）在每一步加载正确的规格章节和源文件，而不是把整份规格一股脑丢给 agent。

## 保持规格鲜活

规格是一份活的文档，不是一次性产物：

- **决策改变时更新** —— 如果你发现数据模型需要改变，先更新规格，再实现。
- **范围改变时更新** —— 新增或删减的功能应当反映在规格里。
- **提交规格** —— 规格应当和代码一起放进版本控制。
- **在 PR 中引用规格** —— 把每个 PR 实现的内容链接回规格章节。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| "这个很简单，我不需要规格" | 简单的任务不需要*很长*的规格，但仍然需要验收标准。一份两行的规格就够了。 |
| "我写完代码再写规格" | 那是文档，不是规格。规格的价值在于在*编码之前*逼出清晰。 |
| "规格会拖慢我们" | 一份 15 分钟的规格能防止数小时的返工。用 15 分钟做瀑布，好过用 15 小时调试。 |
| "反正需求会变" | 这正是为什么规格是活的文档。一份过时的规格仍然好过没有规格。 |
| "用户知道自己想要什么" | 即使是清晰的请求也有隐含的假设。规格把这些假设浮出水面。 |

## 危险信号

- 没有任何书面需求就开始写代码
- 在澄清"完成"是什么意思之前就问"我是不是该直接开始构建？"
- 实现任何规格或任务清单里都没提到的功能
- 做出架构决策却不记录
- 因为"要构建什么很明显"而跳过规格

## 验证

在进入实现之前，确认：

- [ ] 规格覆盖全部六个核心领域
- [ ] 人类已经评审并批准了规格
- [ ] 成功标准是具体且可测试的
- [ ] 边界（始终/先询问/绝不）已定义
- [ ] 规格已保存到仓库中的一个文件里
