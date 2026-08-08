# 性能检查清单

Web 应用性能的快速参考清单。与 `performance-optimization` 技能配合使用。

## 目录

- [Core Web Vitals 目标](#core-web-vitals-targets)
- [TTFB 诊断](#ttfb-diagnosis)
- [前端检查清单](#frontend-checklist)
- [后端检查清单](#backend-checklist)
- [测量命令](#measurement-commands)
- [常见反模式](#common-anti-patterns)

## Core Web Vitals 目标

| 指标 | 良好 | 需改进 | 较差 |
|--------|------|------------|------|
| LCP（最大内容绘制） | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| INP（交互到下一次绘制） | ≤ 200ms | ≤ 500ms | > 500ms |
| CLS（累积布局偏移） | ≤ 0.1 | ≤ 0.25 | > 0.25 |

## TTFB 诊断

当 TTFB 缓慢（> 800ms）时，检查 DevTools Network 瀑布流中的每个组成部分：

- [ ] **DNS 解析**慢 → 为已知来源添加 `<link rel="dns-prefetch">` 或 `<link rel="preconnect">`
- [ ] **TCP/TLS 握手**慢 → 启用 HTTP/2、考虑边缘部署、验证 keep-alive
- [ ] **服务器处理**慢 → 对后端进行性能分析、检查慢查询、添加缓存

## 前端检查清单

### 图片
- [ ] 图片使用现代格式（WebP、AVIF）
- [ ] 图片响应式缩放（`srcset` 和 `sizes`）
- [ ] 图片和 `<source>` 元素具有显式 `width` 和 `height`（在美术设计场景中防止 CLS）
- [ ] 首屏以下图片使用 `loading="lazy"` 和 `decoding="async"`
- [ ] 首屏/LCP 图片使用 `fetchpriority="high"` 且不懒加载

### JavaScript
- [ ] 包大小低于 200KB gzipped（初始加载）
- [ ] 使用动态 `import()` 对路由和重功能进行代码分割
- [ ] 启用 tree shaking（验证依赖提供 ESM 并标记 `sideEffects: false`）
- [ ] `<head>` 中没有阻塞性 JavaScript（使用 `defer` 或 `async`）
- [ ] 繁重计算卸载到 Web Workers（如适用）
- [ ] 对以相同 props 重渲染的昂贵组件使用 `React.memo()`
- [ ] `useMemo()` / `useCallback()` 仅在性能分析显示有收益时使用
- [ ] 长任务（> 50ms）被拆分以保持主线程可用——这是改善 INP 的主要杠杆
- [ ] 在长时间运行的循环内部使用 `yieldToMain` 模式，以便输入事件能在块之间执行
- [ ] 在可用时使用现代调度 API：`scheduler.yield()`（首选）、带优先级的 `scheduler.postTask()`、仅在需要时让出的 `isInputPending()`
- [ ] 使用 `requestIdleCallback` 处理可延迟、非紧急的工作（分析上报、预取、预热）
- [ ] 非关键工作从事件处理器中延后（例如分析、日志），以免延迟对交互的响应
- [ ] 第三方脚本以 `async` / `defer` 加载、审计其大小，在较重时用 facade 前置（聊天组件、嵌入内容）

### CSS
- [ ] 关键 CSS 已内联或预加载
- [ ] 非关键样式没有阻塞渲染的 CSS
- [ ] 生产环境中没有 CSS-in-JS 运行时开销（使用抽取）

### 字体
- [ ] 限制在 2–3 个字体系列，每个系列 2–3 个字重（每增加一个字重就是一次额外请求）
- [ ] 仅使用 WOFF2 格式（最小、支持最广——跳过 WOFF/TTF/EOT）
- [ ] 尽可能自托管（第三方字体 CDN 增加 DNS + TCP + TLS 往返）
- [ ] LCP 关键字体预加载：`<link rel="preload" as="font" type="font/woff2" crossorigin>`
- [ ] `font-display: swap`（非关键字体用 `optional`）以避免 FOIT 阻塞渲染
- [ ] 通过 `unicode-range` 做子集化，只提供每个页面需要的字形
- [ ] 需要多种字重/样式时考虑可变字体（一个文件替代多个）
- [ ] 用 `size-adjust`、`ascent-override`、`descent-override` 调整回退字体指标，以减少字体切换时的 CLS
- [ ] 在任何自定义字体之前，先考虑系统字体栈

### 网络
- [ ] 静态资源以长 `max-age` + 内容哈希缓存
- [ ] API 响应在合适的地方缓存（`Cache-Control`）
- [ ] 启用 HTTP/2 或 HTTP/3
- [ ] 为已知来源预连接资源（`<link rel="preconnect">`）
- [ ] 在关键的非图片资源上使用 `fetchpriority`（例如关键的 `<link rel="preload">`、首屏 `<script>`）——不仅仅用于 `<img>`
- [ ] 没有不必要的重定向

### 渲染
- [ ] 没有布局抖动（强制同步布局）
- [ ] 动画使用 `transform` 和 `opacity`（GPU 加速）
- [ ] 长列表使用虚拟化（例如 `react-window`）
- [ ] 没有不必要的整页重渲染
- [ ] 屏幕外区域使用 `content-visibility: auto` 配合 `contain-intrinsic-size`，跳过不可见区域的布局/绘制
- [ ] 没有 `unload` 事件处理器，HTML 响应上没有 `Cache-Control: no-store`——保持返回/前进缓存（bfcache）资格

## 后端检查清单

### 数据库
- [ ] 没有 N+1 查询模式（使用急切加载 / join）
- [ ] 查询有合适的索引
- [ ] 列表端点分页（绝不 `SELECT * FROM table`）
- [ ] 已配置连接池
- [ ] 已启用慢查询日志

### API
- [ ] 响应时间 < 200ms（p95）
- [ ] 请求处理器中没有同步的繁重计算
- [ ] 使用批量操作而不是单个调用的循环
- [ ] 响应压缩（gzip/brotli）
- [ ] 适当的缓存（内存、Redis、CDN）

### 基础设施
- [ ] 静态资产使用 CDN
- [ ] 服务器靠近用户部署（或边缘部署）
- [ ] 已配置水平扩展（如需要）
- [ ] 负载均衡器的健康检查端点

## 测量命令

### INP 现场数据与 DevTools 工作流

1. **先看现场数据** — 在优化之前，通过 [CrUX Vis](https://developer.chrome.com/docs/crux/vis) 或你的 RUM 工具检查真实用户的 INP
2. **识别慢交互** — 打开 DevTools → Performance 面板 → 交互时录制；查找由点击/按键触发的长任务
3. **在中端 Android 上测试** — INP 问题往往只在较慢的硬件上浮现；使用真机或 DevTools CPU 降速（4×–6× 减速）

```bash
# Lighthouse CLI
npx lighthouse https://localhost:3000 --output json --output-path ./report.json

# Bundle analysis
npx webpack-bundle-analyzer stats.json
# or for Vite:
npx vite-bundle-visualizer

# Check bundle size
npx bundlesize

# Web Vitals in code
import { onLCP, onINP, onCLS } from 'web-vitals';
onLCP(console.log);
onINP(console.log);
onCLS(console.log);

# INP with interaction-level detail (attribution build)
import { onINP } from 'web-vitals/attribution';
onINP(({ value, attribution }) => {
  const { interactionTarget, inputDelay, processingDuration, presentationDelay } = attribution;
  console.log({ value, interactionTarget, inputDelay, processingDuration, presentationDelay });
});
```

## 常见反模式

| 反模式 | 影响 | 修复 |
|---|---|---|
| N+1 查询 | 数据库负载线性增长 | 使用 join、includes 或批量加载 |
| 无界查询 | 内存耗尽、超时 | 始终分页，加 LIMIT |
| 缺少索引 | 数据增长时读取变慢 | 为过滤/排序的列添加索引 |
| 布局抖动 | 卡顿、掉帧 | 批量读取 DOM，然后批量写入 |
| 未优化的图片 | LCP 变慢、浪费带宽 | 使用 WebP、响应式尺寸、懒加载 |
| 大体积包 | 交互时间变慢 | 代码分割、tree shake、审计依赖 |
| 阻塞主线程 | INP 不佳、UI 无响应 | 用 `scheduler.yield()` / `yieldToMain` 切分长任务，卸载到 Web Workers |
| 内存泄漏 | 内存不断增长，最终崩溃 | 清理监听器、定时器、引用 |
