---
name: documentation-and-adrs
description: 记录决策与文档。当做出架构决策、更改公共 API、发布功能，或需要记录未来工程师和 agent 理解代码库所需的背景时使用。
---

# 文档与 ADR

## 概述

记录决策，而不只是代码。最有价值的文档捕获*为什么*——导致某个决策的背景、约束和权衡。代码显示*做了什么*；文档解释*为什么这样做*以及*考虑了哪些替代方案*。这个背景对于未来在代码库中工作的人类和 agent 都至关重要。

## 何时使用

- 做出一个重要的架构决策
- 在相互竞争的方案之间做选择
- 添加或更改公共 API
- 发布一个改变面向用户行为的功能
- 让新团队成员（或 agent）上手项目
- 当你发现自己反复解释同一件事时

**何时不使用：** 不要为显而易见的代码写文档。不要添加复述代码已表达内容的注释。不要为一次性原型写文档。

## 架构决策记录（ADR）

ADR 捕获重大技术决策背后的推理。它们是你所能写出的最高价值的文档。

### 何时写 ADR

- 选择框架、库或主要依赖
- 设计数据模型或数据库 schema
- 选择认证策略
- 决定 API 架构（REST vs. GraphQL vs. tRPC）
- 在构建工具、托管平台或基础设施之间做选择
- 任何回退成本高昂的决策

### 先匹配现有约定

在创建 ADR 之前，检查可用的仓库上下文，寻找已确立的约定——现有的 ADR、项目指令，以及与 ADR 相关的配置或工具（例如 `.adr-dir` 文件）。已确立的约定优先于下面的默认设置。匹配：

- **位置和格式**——例如 `docs/adr/*.md`、`Documentation/Decisions/*.rst`、MADR 布局或 `adr-tools` 配置。匹配现有的目录、文件扩展名和标记语言（Markdown vs reStructuredText）。
- **编号与命名**——延续现有的序列和文件名模式（`ADR-004-Title.rst`、`0004-title.md`、…）；不要从 001 重新开始，也不要引入第二套方案。
- **章节标题**——复用项目的标题集，而不是强加本模板的。

如果可用证据互相冲突，提出这个冲突，而不是默默引入另一套方案。只有在无法确立任何约定时，才应用下面的默认设置。

### ADR 模板

把 ADR 存放在 `docs/decisions/` 中，使用顺序编号（除非项目已经在用另一个位置——见上）：

```markdown
# ADR-001: Use PostgreSQL for primary database

## Status
Accepted | Superseded by ADR-XXX | Deprecated

## Date
2025-01-15

## Context
We need a primary database for the task management application. Key requirements:
- Relational data model (users, tasks, teams with relationships)
- ACID transactions for task state changes
- Support for full-text search on task content
- Managed hosting available (for small team, limited ops capacity)

## Decision
Use PostgreSQL with Prisma ORM.

## Alternatives Considered

### MongoDB
- Pros: Flexible schema, easy to start with
- Cons: Our data is inherently relational; would need to manage relationships manually
- Rejected: Relational data in a document store leads to complex joins or data duplication

### SQLite
- Pros: Zero configuration, embedded, fast for reads
- Cons: Limited concurrent write support, no managed hosting for production
- Rejected: Not suitable for multi-user web application in production

### MySQL
- Pros: Mature, widely supported
- Cons: PostgreSQL has better JSON support, full-text search, and ecosystem tooling
- Rejected: PostgreSQL is the better fit for our feature requirements

## Consequences
- Prisma provides type-safe database access and migration management
- We can use PostgreSQL's full-text search instead of adding Elasticsearch
- Team needs PostgreSQL knowledge (standard skill, low risk)
- Hosting on managed service (Supabase, Neon, or RDS)
```

### ADR 生命周期

```
PROPOSED → ACCEPTED → (SUPERSEDED or DEPRECATED)
```

- **不要删除旧的 ADR。** 它们捕获历史背景。
- 当决策改变时，写一个新的 ADR，引用并取代旧的。

## 行内文档

### 何时加注释

注释*为什么*，而不是*什么*：

```typescript
// BAD: Restates the code
// Increment counter by 1
counter += 1;

// GOOD: Explains non-obvious intent
// Rate limit uses a sliding window — reset counter at window boundary,
// not on a fixed schedule, to prevent burst attacks at window edges
if (now - windowStart > WINDOW_SIZE_MS) {
  counter = 0;
  windowStart = now;
}
```

### 何时不加注释

```typescript
// Don't comment self-explanatory code
function calculateTotal(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

// Don't leave TODO comments for things you should just do now
// TODO: add error handling  ← Just add it

// Don't leave commented-out code
// const oldImplementation = () => { ... }  ← Delete it, git has history
```

### 记录已知坑

```typescript
/**
 * IMPORTANT: This function must be called before the first render.
 * If called after hydration, it causes a flash of unstyled content
 * because the theme context isn't available during SSR.
 *
 * See ADR-003 for the full design rationale.
 */
export function initializeTheme(theme: Theme): void {
  // ...
}
```

## API 文档

对于公共 API（REST、GraphQL、库接口）：

### 与类型内联（TypeScript 首选）

```typescript
/**
 * Creates a new task.
 *
 * @param input - Task creation data (title required, description optional)
 * @returns The created task with server-generated ID and timestamps
 * @throws {ValidationError} If title is empty or exceeds 200 characters
 * @throws {AuthenticationError} If the user is not authenticated
 *
 * @example
 * const task = await createTask({ title: 'Buy groceries' });
 * console.log(task.id); // "task_abc123"
 */
export async function createTask(input: CreateTaskInput): Promise<Task> {
  // ...
}
```

### REST API 的 OpenAPI / Swagger

```yaml
paths:
  /api/tasks:
    post:
      summary: Create a task
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateTaskInput'
      responses:
        '201':
          description: Task created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        '422':
          description: Validation error
```

## README 结构

每个项目都应该有一个 README，覆盖：

```markdown
# Project Name

One-paragraph description of what this project does.

## Quick Start
1. Clone the repo
2. Install dependencies: `npm install`
3. Set up environment: `cp .env.example .env`
4. Run the dev server: `npm run dev`

## Commands
| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm test` | Run tests |
| `npm run build` | Production build |
| `npm run lint` | Run linter |

## Architecture
Brief overview of the project structure and key design decisions.
Link to ADRs for details.

## Contributing
How to contribute, coding standards, PR process.
```

## Changelog 维护

对于已发布的功能：

```markdown
# Changelog

## [1.2.0] - 2025-01-20
### Added
- Task sharing: users can share tasks with team members (#123)
- Email notifications for task assignments (#124)

### Fixed
- Duplicate tasks appearing when rapidly clicking create button (#125)

### Changed
- Task list now loads 50 items per page (was 20) for better UX (#126)
```

## 面向 Agent 的文档

对 AI agent 上下文的特别考量：

- **CLAUDE.md / rules 文件** —— 记录项目约定，让 agent 遵循它们
- **Spec 文件** —— 保持 spec 更新，让 agent 构建正确的东西
- **ADR** —— 帮助 agent 理解过去的决策为何如此（防止重新决策）
- **行内坑** —— 防止 agent 掉进已知陷阱

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「代码是自文档化的」 | 代码显示什么。它不显示为什么、哪些替代方案被否决，或存在哪些约束。 |
| 「API 稳定下来我们再写文档」 | 当你写文档时，API 稳定得更快。文档是设计的第一道测试。 |
| 「没人读文档」 | Agent 会读。未来的工程师会读。三个月后的你自己也会读。 |
| 「ADR 是额外开销」 | 一份 10 分钟的 ADR 能防止六个月后对同一决策进行 2 小时的辩论。 |
| 「注释会过时」 | 关于*为什么*的注释是稳定的。关于*什么*的注释会过时——这就是为什么你只写前者。 |

## 危险信号

- 没有书面理由的架构决策
- 没有文档或类型的公共 API
- 不解释如何运行项目的 README
- 被注释掉的代码而不是删除
- 已经存在数周的 TODO 注释
- 一个拥有重大架构选择的项目却没有 ADR
- 复述代码而不是解释意图的文档

## 验证

在完成文档之后：

- [ ] 所有重大架构决策都有 ADR
- [ ] README 覆盖快速开始、命令和架构概览
- [ ] API 函数有参数和返回类型文档
- [ ] 已知坑在它们重要的地方做了行内记录
- [ ] 没有遗留被注释掉的代码
- [ ] rules 文件（CLAUDE.md 等）是当前且准确的
