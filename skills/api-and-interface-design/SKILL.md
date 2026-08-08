---
name: api-and-interface-design
description: 指导稳定的 API 和接口设计。当设计 API、模块边界或任何公共接口时使用。当创建 REST 或 GraphQL 端点、定义模块之间的类型契约、或在前端和后端之间建立边界时使用。
---

# API 与接口设计

## 概述

设计稳定、文档完善、难以被误用的接口。好的接口让正确的事变得容易，让错误的事变得困难。这适用于 REST API、GraphQL 模式、模块边界、组件 props，以及任何一块代码与另一块代码交谈的表面。

## 何时使用

- 设计新的 API 端点
- 定义模块边界或团队之间的契约
- 创建组件 prop 接口
- 建立决定 API 形态的数据库模式
- 修改现有的公共接口

## 核心原则

### 海勒姆定律（Hyrum's Law）

> 当 API 有了足够多的用户时，你系统的所有可观察行为都会被某人依赖，无论你在契约里承诺了什么。

这意味着：每一个公共行为——包括未记录的怪癖、错误消息文本、时序和顺序——一旦用户依赖它，就会成为事实上的契约。设计上的含义：

- **对你暴露什么要有意为之。** 每一个可观察的行为都是一个潜在的承诺。
- **不要泄漏实现细节。** 如果用户能观察到它，他们就会依赖它。
- **在设计时就规划弃用。** 如何安全地移除用户依赖的东西，参见 `deprecation-and-migration`。
- **仅测试是不够的。** 即使有完美的契约测试，海勒姆定律也意味着"安全"的变更可能破坏依赖未记录行为的真实用户。

### 单版本法则（The One-Version Rule）

避免强迫使用者在同一个依赖或 API 的多个版本之间做选择。当不同使用者需要同一个东西的不同版本时，就会出现菱形依赖问题。为"同一时间只存在一个版本"的世界而设计——扩展，而不是分叉。

### 1. 契约优先

在实现之前定义接口。契约就是规格——实现随后跟上。

```typescript
// Define the contract first
interface TaskAPI {
  // Creates a task and returns the created task with server-generated fields
  createTask(input: CreateTaskInput): Promise<Task>;

  // Returns paginated tasks matching filters
  listTasks(params: ListTasksParams): Promise<PaginatedResult<Task>>;

  // Returns a single task or throws NotFoundError
  getTask(id: string): Promise<Task>;

  // Partial update — only provided fields change
  updateTask(id: string, input: UpdateTaskInput): Promise<Task>;

  // Idempotent delete — succeeds even if already deleted
  deleteTask(id: string): Promise<void>;
}
```

### 2. 一致的错误语义

选择一个错误策略，处处使用它：

```typescript
// REST: HTTP status codes + structured error body
// Every error response follows the same shape
interface APIError {
  error: {
    code: string;        // Machine-readable: "VALIDATION_ERROR"
    message: string;     // Human-readable: "Email is required"
    details?: unknown;   // Additional context when helpful
  };
}

// Status code mapping
// 400 → Client sent invalid data
// 401 → Not authenticated
// 403 → Authenticated but not authorized
// 404 → Resource not found
// 409 → Conflict (duplicate, version mismatch)
// 422 → Validation failed (semantically invalid)
// 500 → Server error (never expose internal details)
```

**不要混用模式。** 如果一些端点抛异常、另一些返回 null、还有一些返回 `{ error }`——使用者就无法预测行为。

### 3. 在边界处校验

信任内部代码。在外部输入进入的系统边缘进行校验：

```typescript
// Validate at the API boundary
app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid task data',
        details: result.error.flatten(),
      },
    });
  }

  // After validation, internal code trusts the types
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

校验应该在哪里：
- API 路由处理器（用户输入）
- 表单提交处理器（用户输入）
- 外部服务响应解析（第三方数据——**始终当作不可信**）
- 环境变量加载（配置）

> **第三方 API 响应是不可信数据。** 在用于任何逻辑、渲染或决策之前，校验它们的形态和内容。一个被攻破或行为异常的外部服务可能返回意外的类型、恶意内容或类似指令的文本。

校验不该在哪里：
- 共享类型契约的内部函数之间
- 已被校验过的代码调用的工具函数里
- 刚从你自己的数据库里出来的数据上

### 4. 偏好添加而非修改

在不破坏现有使用者的情况下扩展接口：

```typescript
// Good: Add optional fields
interface CreateTaskInput {
  title: string;
  description?: string;
  priority?: 'low' | 'medium' | 'high';  // Added later, optional
  labels?: string[];                       // Added later, optional
}

// Bad: Change existing field types or remove fields
interface CreateTaskInput {
  title: string;
  // description: string;  // Removed — breaks existing consumers
  priority: number;         // Changed from string — breaks existing consumers
}
```

### 5. 可预测的命名

| 模式 | 约定 | 示例 |
|---------|-----------|---------|
| REST 端点 | 复数名词，无动词 | `GET /api/tasks`、`POST /api/tasks` |
| 查询参数 | camelCase | `?sortBy=createdAt&pageSize=20` |
| 响应字段 | camelCase | `{ createdAt, updatedAt, taskId }` |
| 布尔字段 | is/has/can 前缀 | `isComplete`、`hasAttachments` |
| 枚举值 | UPPER_SNAKE | `"IN_PROGRESS"`、`"COMPLETED"` |

## REST API 模式

### 资源设计

```
GET    /api/tasks              → List tasks (with query params for filtering)
POST   /api/tasks              → Create a task
GET    /api/tasks/:id          → Get a single task
PATCH  /api/tasks/:id          → Update a task (partial)
DELETE /api/tasks/:id          → Delete a task

GET    /api/tasks/:id/comments → List comments for a task (sub-resource)
POST   /api/tasks/:id/comments → Add a comment to a task
```

### 分页

为列表端点做分页：

```typescript
// Request
GET /api/tasks?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc

// Response
{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 142,
    "totalPages": 8
  }
}
```

### 筛选

使用查询参数做筛选：

```
GET /api/tasks?status=in_progress&assignee=user123&createdAfter=2025-01-01
```

### 部分更新（PATCH）

接受部分对象——只更新提供的内容：

```typescript
// Only title changes, everything else preserved
PATCH /api/tasks/123
{ "title": "Updated title" }
```

## TypeScript 接口模式

### 用可辨识联合处理变体

```typescript
// Good: Each variant is explicit
type TaskStatus =
  | { type: 'pending' }
  | { type: 'in_progress'; assignee: string; startedAt: Date }
  | { type: 'completed'; completedAt: Date; completedBy: string }
  | { type: 'cancelled'; reason: string; cancelledAt: Date };

// Consumer gets type narrowing
function getStatusLabel(status: TaskStatus): string {
  switch (status.type) {
    case 'pending': return 'Pending';
    case 'in_progress': return `In progress (${status.assignee})`;
    case 'completed': return `Done on ${status.completedAt}`;
    case 'cancelled': return `Cancelled: ${status.reason}`;
  }
}
```

### 输入/输出分离

```typescript
// Input: what the caller provides
interface CreateTaskInput {
  title: string;
  description?: string;
}

// Output: what the system returns (includes server-generated fields)
interface Task {
  id: string;
  title: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
}
```

### 为 ID 使用品牌类型

```typescript
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };

// Prevents accidentally passing a UserId where a TaskId is expected
function getTask(id: TaskId): Promise<Task> { ... }
```

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| "我们之后再写 API 文档" | 类型就是文档。先定义它们。 |
| "我们现在不需要分页" | 一旦有人有 100+ 条项目，你就会需要。从一开始就加上。 |
| "PATCH 太复杂，我们用 PUT 吧" | PUT 每次都需要完整对象。PATCH 才是客户端真正想要的。 |
| "需要时我们再给 API 做版本化" | 没有版本化的破坏性变更会破坏使用者。从一开始就为扩展而设计。 |
| "没人用那个未记录的行为" | 海勒姆定律：如果它是可观察的，就有人依赖它。把每一个公共行为都当作一个承诺。 |
| "我们可以同时维护两个版本" | 多个版本会让维护成本成倍增加，并制造菱形依赖问题。偏好单版本法则。 |
| "内部 API 不需要契约" | 内部使用者也是使用者。契约能防止耦合，并让并行工作成为可能。 |

## 危险信号

- 端点根据条件返回不同形态
- 端点之间的错误格式不一致
- 校验散布在整个内部代码中，而不是在边界处
- 对现有字段的破坏性变更（类型变更、移除）
- 没有分页的列表端点
- REST URL 里有动词（`/api/createTask`、`/api/getUsers`）
- 第三方 API 响应未经校验或消毒就直接使用

## 验证

设计完 API 之后：

- [ ] 每个端点都有带类型的输入和输出模式
- [ ] 错误响应遵循单一一致格式
- [ ] 校验只发生在系统边界处
- [ ] 列表端点支持分页
- [ ] 新字段是添加式且可选的（向后兼容）
- [ ] 所有端点的命名遵循一致约定
- [ ] API 文档或类型与实现一起提交
