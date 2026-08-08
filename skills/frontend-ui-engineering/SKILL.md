---
name: frontend-ui-engineering
description: 构建生产级、可访问、响应式（移动端自适应）的用户界面。当构建或修改界面和页面、创建组件、实现布局、满足 WCAG 可访问性要求、管理状态，或当输出需要看起来像生产级而不是 AI 生成的时使用。
---

# 前端 UI 工程

## 概述

构建生产级、可访问、性能良好且视觉精良的用户界面。目标是让 UI 看起来像顶级公司里一位懂设计的工程师做的——而不是像 AI 生成的。这意味着真正遵循设计系统、正确的可访问性、深思熟虑的交互模式，以及没有那种通用的"AI 美学"。

## 何时使用

- 构建新的 UI 组件或页面
- 修改现有的用户界面
- 实现响应式布局
- 添加交互性或状态管理
- 修复视觉或 UX 问题

## 组件架构

### 文件结构

把与一个组件相关的所有内容放在一起：

```
src/components/
  TaskList/
    TaskList.tsx          # Component implementation
    TaskList.test.tsx     # Tests
    TaskList.stories.tsx  # Storybook stories (if using)
    use-task-list.ts      # Custom hook (if complex state)
    types.ts              # Component-specific types (if needed)
```

### 组件模式

**组合优于配置：**

```tsx
// Good: Composable
<Card>
  <CardHeader>
    <CardTitle>Tasks</CardTitle>
  </CardHeader>
  <CardBody>
    <TaskList tasks={tasks} />
  </CardBody>
</Card>

// Avoid: Over-configured
<Card
  title="Tasks"
  headerVariant="large"
  bodyPadding="md"
  content={<TaskList tasks={tasks} />}
/>
```

**保持组件聚焦：**

```tsx
// Good: Does one thing
export function TaskItem({ task, onToggle, onDelete }: TaskItemProps) {
  return (
    <li className="flex items-center gap-3 p-3">
      <Checkbox checked={task.done} onChange={() => onToggle(task.id)} />
      <span className={task.done ? 'line-through text-muted' : ''}>{task.title}</span>
      <Button variant="ghost" size="sm" onClick={() => onDelete(task.id)}>
        <TrashIcon />
      </Button>
    </li>
  );
}
```

**把数据获取与展示分开：**

```tsx
// Container: handles data
export function TaskListContainer() {
  const { tasks, isLoading, error } = useTasks();

  if (isLoading) return <TaskListSkeleton />;
  if (error) return <ErrorState message="Failed to load tasks" retry={refetch} />;
  if (tasks.length === 0) return <EmptyState message="No tasks yet" />;

  return <TaskList tasks={tasks} />;
}

// Presentation: handles rendering
export function TaskList({ tasks }: { tasks: Task[] }) {
  return (
    <ul role="list" className="divide-y">
      {tasks.map(task => <TaskItem key={task.id} task={task} />)}
    </ul>
  );
}
```

## 状态管理

**选择能工作的最简单的方案：**

```
Local state (useState)           → Component-specific UI state
Lifted state                     → Shared between 2-3 sibling components
Context                          → Theme, auth, locale (read-heavy, write-rare)
URL state (searchParams)         → Filters, pagination, shareable UI state
Server state (React Query, SWR)  → Remote data with caching
Global store (Zustand, Redux)    → Complex client state shared app-wide
```

**避免 prop 钻取超过 3 层。** 如果你在通过不使用它们的组件传递 props，引入 context 或重构组件树。

## 设计系统遵循

### 避免 AI 美学

AI 生成的 UI 有可识别的模式。避免所有它们：

| AI 默认 | 为什么它是问题 | 生产级做法 |
|---|---|---|
| 到处都是紫色/靛蓝 | 模型默认选择视觉上"安全"的调色板，让每个应用看起来都一样 | 使用项目实际的调色板 |
| 过多的渐变 | 渐变增加视觉噪音，与大多数设计系统冲突 | 平坦或与设计系统匹配的细微渐变 |
| 什么都圆角（rounded-2xl） | 最大圆角传达"友好"，但忽略了真实设计中圆角半径的层级 | 来自设计系统的统一 border-radius |
| 通用的 hero 区块 | 模板驱动的布局，与实际内容或用户需求毫无关联 | 内容优先的布局 |
| Lorem ipsum 式文案 | 占位文本掩盖了真实内容会暴露的布局问题（长度、换行、溢出） | 真实感的占位内容 |
| 到处是超大 padding | 均匀慷慨的 padding 破坏视觉层级，浪费屏幕空间 | 一致的间距刻度 |
| 通用的卡片网格 | 均匀网格是布局捷径，忽略信息优先级和扫描模式 | 目的驱动的布局 |
| 重阴影设计 | 分层阴影增加与内容竞争的深度，在低端设备上拖慢渲染 | 除非设计系统指定，否则用细微或没有阴影 |

### 间距与布局

使用一致的间距刻度。不要发明数值：

```css
/* Use the scale: 0.25rem increments (or whatever the project uses) */
/* Good */  padding: 1rem;      /* 16px */
/* Good */  gap: 0.75rem;       /* 12px */
/* Bad */   padding: 13px;      /* Not on any scale */
/* Bad */   margin-top: 2.3rem; /* Not on any scale */
```

### 排版

尊重排版层级：

```
h1 → Page title (one per page)
h2 → Section title
h3 → Subsection title
body → Default text
small → Secondary/helper text
```

不要跳过标题层级。不要为非标题内容使用标题样式。

### 颜色

- 使用语义化颜色令牌：`text-primary`、`bg-surface`、`border-default`——而不是原始 hex 值
- 确保足够的对比度（普通文本 4.5:1，大文本 3:1）
- 不要仅仅依赖颜色来传达信息（也要使用图标、文本或图案）

## 可访问性（WCAG 2.1 AA）

每个组件都必须满足这些标准：

### 键盘导航

```tsx
// Every interactive element must be keyboard accessible
<button onClick={handleClick}>Click me</button>        // ✓ Focusable by default
<div onClick={handleClick}>Click me</div>               // ✗ Not focusable
<div role="button" tabIndex={0} onClick={handleClick}    // ✓ But prefer <button>
     onKeyDown={e => {
       if (e.key === 'Enter') handleClick();
       if (e.key === ' ') e.preventDefault();
     }}
     onKeyUp={e => {
       if (e.key === ' ') handleClick();
     }}>
  Click me
</div>
```

### ARIA 标签

```tsx
// Label interactive elements that lack visible text
<button aria-label="Close dialog"><XIcon /></button>

// Label form inputs
<label htmlFor="email">Email</label>
<input id="email" type="email" />

// Or use aria-label when no visible label exists
<input aria-label="Search tasks" type="search" />
```

### 焦点管理

```tsx
// Move focus when content changes
function Dialog({ isOpen, onClose }: DialogProps) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (isOpen) closeRef.current?.focus();
  }, [isOpen]);

  // Trap focus inside dialog when open
  return (
    <dialog open={isOpen}>
      <button ref={closeRef} onClick={onClose}>Close</button>
      {/* dialog content */}
    </dialog>
  );
}
```

### 有意义的空状态和错误状态

```tsx
// Don't show blank screens
function TaskList({ tasks }: { tasks: Task[] }) {
  if (tasks.length === 0) {
    return (
      <div role="status" className="text-center py-12">
        <TasksEmptyIcon className="mx-auto h-12 w-12 text-muted" />
        <h3 className="mt-2 text-sm font-medium">No tasks</h3>
        <p className="mt-1 text-sm text-muted">Get started by creating a new task.</p>
        <Button className="mt-4" onClick={onCreateTask}>Create Task</Button>
      </div>
    );
  }

  return <ul role="list">...</ul>;
}
```

## 响应式设计

移动优先设计，然后扩展：

```tsx
// Tailwind: mobile-first responsive
<div className="
  grid grid-cols-1      /* Mobile: single column */
  sm:grid-cols-2        /* Small: 2 columns */
  lg:grid-cols-3        /* Large: 3 columns */
  gap-4
">
```

在这些断点测试：320px、768px、1024px、1440px。

## 加载与过渡

```tsx
// Skeleton loading (not spinners for content)
function TaskListSkeleton() {
  return (
    <div className="space-y-3" aria-busy="true" aria-label="Loading tasks">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="h-12 bg-muted animate-pulse rounded" />
      ))}
    </div>
  );
}

// Optimistic updates for perceived speed
function useToggleTask() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: toggleTask,
    onMutate: async (taskId) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] });
      const previous = queryClient.getQueryData(['tasks']);

      queryClient.setQueryData(['tasks'], (old: Task[]) =>
        old.map(t => t.id === taskId ? { ...t, done: !t.done } : t)
      );

      return { previous };
    },
    onError: (_err, _taskId, context) => {
      queryClient.setQueryData(['tasks'], context?.previous);
    },
  });
}
```

## 另请参阅

详细的可访问性要求和测试工具，参见 `references/accessibility-checklist.md`。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| "可访问性是有更好" | 在许多司法管辖区它是法律要求，也是工程质量标准。 |
| "我们之后再做响应式" | 事后改装响应式设计，比一开始就构建它难 3 倍。 |
| "设计还没定稿，所以我跳过样式" | 使用设计系统默认值。未加样式的 UI 会给评审者留下破碎的第一印象。 |
| "这只是一个原型" | 原型会变成生产代码。把基础做对。 |
| "AI 美学暂时还行" | 它传达的是低质量。从一开始就使用项目实际的设计系统。 |

## 危险信号

- 超过 200 行的组件（拆分它们）
- 内联样式或任意的像素值
- 缺少错误状态、加载状态或空状态
- 没有键盘导航测试
- 颜色作为状态的唯一指示（红/绿而没有任何文本或图标）
- 通用的"AI 观感"（紫色渐变、超大卡片、模板布局）

## 验证

构建 UI 之后：

- [ ] 组件渲染时无控制台错误
- [ ] 所有交互元素都可键盘访问（用 Tab 遍历页面）
- [ ] 屏幕阅读器能传达页面的内容和结构
- [ ] 响应式：在 320px、768px、1024px、1440px 下都能工作
- [ ] 加载、错误和空状态都得到处理
- [ ] 遵循项目的设计系统（间距、颜色、排版）
- [ ] 开发工具或 axe-core 中没有可访问性警告
