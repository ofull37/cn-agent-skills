---
name: code-simplification
description: 为清晰性简化代码，让难以阅读、难以理解的代码更容易维护。当为了清晰性而重构代码、且不改变行为时使用。当代码能用、但可读性、可维护性或可扩展性比应有的差时使用。当评审积累了不必要复杂度的代码时使用。
---

# 代码简化

> 灵感来自 [Claude Code Simplifier 插件](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/code-simplifier/agents/code-simplifier.md)。此处改编为一种模型无关、流程驱动的技能，适用于任何 AI 编码 agent。

## 概述

通过降低复杂度来简化代码，同时保持行为完全一致。目标不是更少的行数——而是更容易阅读、理解、修改和调试的代码。每个简化都必须通过一个简单的测试：「新团队成员理解这个版本，会比理解原版更快吗？」

## 何时使用

- 在功能可用且测试通过之后，但实现感觉比应有的更重
- 在代码评审中，当可读性或复杂度问题被标记时
- 当你遇到深度嵌套的逻辑、过长的函数或不清晰的命名时
- 当重构在时间压力下编写的代码时
- 当整合散落在多个文件中的相关逻辑时
- 在合并了引入重复或不一致的变更之后

**何时不使用：**

- 代码已经很干净可读——不要为了简化而简化
- 你还不理解代码在做什么——先理解，再简化
- 代码是性能关键的，而「更简单」的版本会有可测的更慢
- 你正要彻底重写这个模块——简化一次性代码是白费力气

## 五项原则

### 1. 严格保持行为不变

不要改变代码做什么——只改变它的表达方式。所有输入、输出、副作用、错误行为和边界情况都必须保持一致。如果你不确定某个简化是否保持了行为，就不要做。

```
ASK BEFORE EVERY CHANGE:
→ Does this produce the same output for every input?
→ Does this maintain the same error behavior?
→ Does this preserve the same side effects and ordering?
→ Do all existing tests still pass without modification?
```

### 2. 遵循项目约定

简化意味着让代码与代码库更一致，而不是强加外部偏好。在简化之前：

```
1. Read CLAUDE.md / project conventions
2. Study how neighboring code handles similar patterns
3. Match the project's style for:
   - Import ordering and module system
   - Function declaration style
   - Naming conventions
   - Error handling patterns
   - Type annotation depth
```

破坏项目一致性的简化不是简化——而是折腾。

### 3. 清晰优先于炫技

当紧凑版本需要停下思考才能解析时，显式代码胜过紧凑代码。

```typescript
// UNCLEAR: Dense ternary chain
const label = isNew ? 'New' : isUpdated ? 'Updated' : isArchived ? 'Archived' : 'Active';

// CLEAR: Readable mapping
function getStatusLabel(item: Item): string {
  if (item.isNew) return 'New';
  if (item.isUpdated) return 'Updated';
  if (item.isArchived) return 'Archived';
  return 'Active';
}
```

```typescript
// UNCLEAR: Chained reduces with inline logic
const result = items.reduce((acc, item) => ({
  ...acc,
  [item.id]: { ...acc[item.id], count: (acc[item.id]?.count ?? 0) + 1 }
}), {});

// CLEAR: Named intermediate step
const countById = new Map<string, number>();
for (const item of items) {
  countById.set(item.id, (countById.get(item.id) ?? 0) + 1);
}
```

### 4. 保持平衡

简化有一个失败模式：过度简化。注意这些陷阱：

- **过度内联**——移除一个为概念命名的 helper，会让调用点更难读
- **合并无关逻辑**——两个简单函数合并成一个复杂函数并不更简单
- **移除「不必要」的抽象**——有些抽象是为了可扩展性或可测试性而存在，不是为了复杂度
- **为行数而优化**——更少的行数不是目标；更容易理解才是

### 5. 限定在变更范围内

默认只简化最近修改的代码。除非被明确要求扩大范围，否则避免顺手重构无关代码。不受范围约束的简化会在 diff 中制造噪音，并带来意外回归的风险。

## 简化流程

### 第 1 步：先理解，再动手（切斯特顿栅栏）

在改动或移除任何东西之前，先理解它为什么存在。这就是切斯特顿栅栏：如果你看到路上横着一道栅栏，却不理解它为什么在那里，就不要拆掉它。先理解原因，再决定这个原因是否仍然成立。

```
BEFORE SIMPLIFYING, ANSWER:
- What is this code's responsibility?
- What calls it? What does it call?
- What are the edge cases and error paths?
- Are there tests that define the expected behavior?
- Why might it have been written this way? (Performance? Platform constraint? Historical reason?)
- Check git blame: what was the original context for this code?
```

如果你回答不了这些问题，你还没准备好简化。先读更多上下文。

### 第 2 步：识别简化机会

扫描以下模式——每一个都是具体信号，而不是模糊的坏味道：

**结构复杂度：**

| 模式 | 信号 | 简化方式 |
|---------|--------|----------------|
| 深度嵌套（3 层以上） | 控制流难以跟随 | 把条件提取为守卫子句或 helper 函数 |
| 过长函数（50 行以上） | 多个职责 | 拆成命名有描述性的聚焦函数 |
| 嵌套三元表达式 | 需要心智栈来解析 | 替换为 if/else 链、switch 或查找对象 |
| 布尔参数标志 | `doThing(true, false, true)` | 替换为 options 对象或独立函数 |
| 重复条件判断 | 多处出现同样的 `if` 检查 | 提取为命名良好的谓词函数 |

**命名与可读性：**

| 模式 | 信号 | 简化方式 |
|---------|--------|----------------|
| 泛化命名 | `data`、`result`、`temp`、`val`、`item` | 重命名以描述内容：`userProfile`、`validationErrors` |
| 缩写命名 | `usr`、`cfg`、`btn`、`evt` | 用全词，除非缩写是通用的（`id`、`url`、`api`） |
| 误导性命名 | 名为 `get` 的函数实际上还修改了状态 | 重命名以反映真实行为 |
| 解释「做了什么」的注释 | `count++` 上方写着 `// increment counter` | 删除注释——代码本身已经够清楚 |
| 解释「为什么」的注释 | `// Retry because the API is flaky under load` | 保留这些——它们承载了代码无法表达的意图 |

**冗余：**

| 模式 | 信号 | 简化方式 |
|---------|--------|----------------|
| 重复逻辑 | 多个地方出现同样的 5 行以上代码 | 提取为共享函数 |
| 死代码 | 不可达分支、未使用变量、被注释掉的代码块 | 移除（在确认它确实已死之后） |
| 不必要的抽象 | 没有增加价值的包装器 | 内联包装器，直接调用底层函数 |
| 过度工程化的模式 | 为工厂建工厂、只有一种策略的策略模式 | 替换为简单的直接做法 |
| 冗余类型断言 | 强制转换到一个已被推断出的类型 | 移除该断言 |

### 第 3 步：增量应用变更

一次只做一个简化。每次变更后运行测试。**把重构变更与功能或 bug 修复变更分开提交。** 一个既重构又添加功能的 PR 其实是两个 PR——把它们拆开。

```
FOR EACH SIMPLIFICATION:
1. Make the change
2. Run the test suite
3. If tests pass → commit (or continue to next simplification)
4. If tests fail → revert and reconsider
```

避免把多个简化打包进一个未经测试的变更。如果出了岔子，你需要知道是哪个简化引起的。

**500 行法则：** 如果一个重构会触及超过 500 行，就投资自动化（codemods、sed 脚本、AST 转换），而不是手动改。那种规模的手动编辑容易出错，评审起来也累。

### 第 4 步：验证结果

在所有简化完成之后，退后一步，评估整体：

```
COMPARE BEFORE AND AFTER:
- Is the simplified version genuinely easier to understand?
- Did you introduce any new patterns inconsistent with the codebase?
- Is the diff clean and reviewable?
- Would a teammate approve this change?
```

如果「简化后」的版本反而更难理解或评审，就回退。并不是每次简化尝试都会成功。

## 语言特定指南

### TypeScript / JavaScript

```typescript
// SIMPLIFY: Unnecessary async wrapper
// Before
async function getUser(id: string): Promise<User> {
  return await userService.findById(id);
}
// After
function getUser(id: string): Promise<User> {
  return userService.findById(id);
}

// SIMPLIFY: Verbose conditional assignment
// Before
let displayName: string;
if (user.nickname) {
  displayName = user.nickname;
} else {
  displayName = user.fullName;
}
// After
const displayName = user.nickname || user.fullName;

// SIMPLIFY: Manual array building
// Before
const activeUsers: User[] = [];
for (const user of users) {
  if (user.isActive) {
    activeUsers.push(user);
  }
}
// After
const activeUsers = users.filter((user) => user.isActive);

// SIMPLIFY: Redundant boolean return
// Before
function isValid(input: string): boolean {
  if (input.length > 0 && input.length < 100) {
    return true;
  }
  return false;
}
// After
function isValid(input: string): boolean {
  return input.length > 0 && input.length < 100;
}
```

### Python

```python
# SIMPLIFY: Verbose dictionary building
# Before
result = {}
for item in items:
    result[item.id] = item.name
# After
result = {item.id: item.name for item in items}

# SIMPLIFY: Nested conditionals with early return
# Before
def process(data):
    if data is not None:
        if data.is_valid():
            if data.has_permission():
                return do_work(data)
            else:
                raise PermissionError("No permission")
        else:
            raise ValueError("Invalid data")
    else:
        raise TypeError("Data is None")
# After
def process(data):
    if data is None:
        raise TypeError("Data is None")
    if not data.is_valid():
        raise ValueError("Invalid data")
    if not data.has_permission():
        raise PermissionError("No permission")
    return do_work(data)
```

### React / JSX

```tsx
// SIMPLIFY: Verbose conditional rendering
// Before
function UserBadge({ user }: Props) {
  if (user.isAdmin) {
    return <Badge variant="admin">Admin</Badge>;
  } else {
    return <Badge variant="default">User</Badge>;
  }
}
// After
function UserBadge({ user }: Props) {
  const variant = user.isAdmin ? 'admin' : 'default';
  const label = user.isAdmin ? 'Admin' : 'User';
  return <Badge variant={variant}>{label}</Badge>;
}

// SIMPLIFY: Prop drilling through intermediate components
// Before — consider whether context or composition solves this better.
// This is a judgment call — flag it, don't auto-refactor.
```

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「它能跑，不用动它」 | 能跑但难读的代码，坏了的时候也会难修。现在简化，能为将来的每一次改动节省时间。 |
| 「行数更少总是更简单」 | 一行的嵌套三元表达式并不比五行的 if/else 更简单。简单是关于理解速度，而不是行数。 |
| 「我顺便把这个无关代码也快速简化一下」 | 不受范围约束的简化会产生嘈杂的 diff，并给你本来不打算改的代码带来回归风险。保持专注。 |
| 「类型让它自文档化了」 | 类型记录的是结构，不是意图。一个命名良好的函数解释*为什么*，比一个类型签名解释*什么*更好。 |
| 「这个抽象以后可能有用」 | 不要保留推测性的抽象。如果现在没用到，它就是不带来价值的复杂度。移除它，需要时再加回来。 |
| 「原作者一定有他的理由」 | 也许吧。查一下 git blame——应用切斯特顿栅栏。但积累起来的复杂度往往没有理由；它只是在压力下迭代的残渣。 |
| 「我会在添加这个功能的同时重构」 | 把重构与功能工作分开。混合的变更在历史中更难评审、回滚和理解。 |

## 危险信号

- 需要修改测试才能通过的简化（你很可能改了行为）
- 「简化后」的代码比原版更长、更难跟随
- 为了匹配你的偏好而不是项目约定而重命名
- 因为「让代码更干净」而移除错误处理
- 简化你并不完全理解的代码
- 把许多简化打包进一个巨大、难以评审的提交
- 未经要求就重构当前任务范围之外的代码

## 验证

在完成一轮简化之后：

- [ ] 所有现有测试在未修改的情况下通过
- [ ] 构建成功，且没有新的警告
- [ ] linter/formatter 通过（没有风格回归）
- [ ] 每个简化都是一个可评审的、增量的变更
- [ ] diff 干净——没有混入无关变更
- [ ] 简化后的代码遵循项目约定（对照 CLAUDE.md 或等价物检查）
- [ ] 没有错误处理被移除或削弱
- [ ] 没有遗留死代码（未使用的导入、不可达分支）
- [ ] 团队成员或评审 agent 会把这个变更视为净改进而批准它
