# 可访问性检查清单

WCAG 2.1 AA 合规的快速参考。与 `frontend-ui-engineering` 技能配合使用。

## 目录

- [基本检查](#essential-checks)
- [常见 HTML 模式](#common-html-patterns)
- [测试工具](#testing-tools)
- [快速参考：ARIA 活动区域](#quick-reference-aria-live-regions)
- [常见反模式](#common-anti-patterns)

## 基本检查

### 键盘导航
- [ ] 所有交互元素可通过 Tab 键聚焦
- [ ] 焦点顺序遵循视觉/逻辑顺序
- [ ] 焦点可见（聚焦元素上有轮廓/光晕）
- [ ] 自定义组件有键盘支持（Enter 激活，Escape 关闭）
- [ ] 没有键盘陷阱（用户总能 Tab 离开某个组件）
- [ ] 页面顶部有跳到内容的链接——在键盘聚焦时可见（至少如此）
- [ ] 模态框打开时聚焦被限制在其中，关闭时返回焦点

### 屏幕阅读器
- [ ] 所有图片都有 `alt` 文本（装饰性图片用 `alt=""`）
- [ ] 所有表单输入都有关联的标签（`<label>` 或 `aria-label`）
- [ ] 按钮和链接有描述性文本（而非「点这里」）
- [ ] 仅图标的按钮有 `aria-label`
- [ ] 页面有一个 `<h1>`，标题不跳级
- [ ] 动态内容变更会被播报（`aria-live` 区域）
- [ ] 表格有带 scope 的 `<th>` 表头

### 视觉
- [ ] 文本对比度 ≥ 4.5:1（普通文本）或 ≥ 3:1（大文本，18px+）
- [ ] UI 组件与背景的对比度 ≥ 3:1
- [ ] 颜色不是传达信息的唯一方式
- [ ] 文本可放大到 200% 而不破坏布局
- [ ] 没有每秒闪烁超过 3 次的内容

### 表单
- [ ] 每个输入都有可见标签
- [ ] 必填字段有标识（不能仅靠颜色）
- [ ] 错误消息具体且与字段关联
- [ ] 错误状态不仅靠颜色可见（图标、文本、边框）
- [ ] 表单提交错误有汇总且可聚焦
- [ ] 已知字段使用自动填充（例如 `type="email" autocomplete="email"`）

### 内容
- [ ] 已声明语言（`<html lang="en">`）
- [ ] 页面有描述性的 `<title>`
- [ ] 链接与周围文本可区分（不能仅靠颜色）
- [ ] 移动端触控目标 ≥ 44x44px
- [ ] 有意义的空状态（而非空白屏幕）

## 常见 HTML 模式

### 按钮 vs. 链接

```html
<!-- Use <button> for actions -->
<button onClick={handleDelete}>Delete Task</button>

<!-- Use <a> for navigation -->
<a href="/tasks/123">View Task</a>

<!-- NEVER use div/span as buttons -->
<div onClick={handleDelete}>Delete</div>  <!-- BAD -->
```

### 表单标签

```html
<!-- Explicit label association -->
<label htmlFor="email">Email address</label>
<input id="email" type="email" required />

<!-- Implicit wrapping -->
<label>
  Email address
  <input type="email" required />
</label>

<!-- Hidden label (visible label preferred) -->
<input type="search" aria-label="Search tasks" />
```

### ARIA 角色

```html
<!-- Navigation -->
<nav aria-label="Main navigation">...</nav>
<nav aria-label="Footer links">...</nav>

<!-- Status messages -->
<div role="status" aria-live="polite">Task saved</div>

<!-- Alert messages -->
<div role="alert">Error: Title is required</div>

<!-- Modal dialogs -->
<dialog aria-modal="true" aria-labelledby="dialog-title">
  <h2 id="dialog-title">Confirm Delete</h2>
  ...
</dialog>

<!-- Loading states -->
<div aria-busy="true" aria-label="Loading tasks">
  <Spinner />
</div>
```

### 可访问列表

```html
<ul role="list" aria-label="Tasks">
  <li>
    <input type="checkbox" id="task-1" aria-label="Complete: Buy groceries" />
    <label htmlFor="task-1">Buy groceries</label>
  </li>
</ul>
```

## 测试工具

```bash
# Automated audit
npx axe-core          # Programmatic accessibility testing
npx pa11y             # CLI accessibility checker

# In browser
# Chrome DevTools → Lighthouse → Accessibility
# Chrome DevTools → Elements → Accessibility tree

# Screen reader testing
# macOS: VoiceOver (Cmd + F5)
# Windows: NVDA (free) or JAWS
# Linux: Orca
```

## 快速参考：ARIA 活动区域

| 值 | 行为 | 用于 |
|-------|----------|---------|
| `aria-live="polite"` | 在下次停顿时播报 | 状态更新、保存确认 |
| `aria-live="assertive"` | 立即播报 | 错误、时间敏感的提醒 |
| `role="status"` | 与 `polite` 相同 | 状态消息 |
| `role="alert"` | 与 `assertive` 相同 | 错误消息 |

## 常见反模式

| 反模式 | 问题 | 修复 |
|---|---|---|
| 用 `div` 当按钮 | 不可聚焦、无键盘支持 | 使用 `<button>` |
| 缺少 `alt` 文本 | 屏幕阅读器看不到图片 | 添加描述性 `alt` |
| 仅靠颜色的状态 | 色盲用户看不到 | 添加图标、文本或图案 |
| 自动播放的媒体 | 令人迷失、无法停止 | 添加控件、不要自动播放 |
| 无 ARIA 的自定义下拉框 | 键盘/屏幕阅读器无法使用 | 使用原生 `<select>` 或正确的 ARIA listbox |
| 移除焦点轮廓 | 用户看不到自己在哪 | 给轮廓设置样式，不要移除 |
| 空的链接/按钮 | 只播报「链接」而没有描述 | 添加文本或 `aria-label` |
| `tabindex > 0` | 破坏自然 Tab 顺序 | 仅使用 `tabindex="0"` 或 `-1` |
