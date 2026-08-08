---
name: performance-optimization
description: 优化前端、后端、查询和数据库的应用性能。当存在性能要求、怀疑有性能回归、需要改进 Core Web Vitals 或加载时间、需要修复 N+1 查询模式，或剖析揭示出瓶颈时使用。
---

# 性能优化

## 概述

先测量，再优化。没有测量的性能工作就是瞎猜——而瞎猜会导致过早优化，它增加复杂度却没能改进真正重要的东西。先剖析，找出真正的瓶颈，修复它，再测量一次。只优化那些测量证明重要的东西。

## 何时使用

- spec 中存在性能要求（加载时间预算、响应时间 SLA）
- 用户或监控报告了缓慢的行为
- Core Web Vitals 分数低于阈值
- 你怀疑某个变更引入了回归
- 构建处理大数据集或高流量的功能时

**何时不使用：** 在你有问题证据之前不要优化。过早优化增加的复杂度，其成本高于它所换来的性能。

## Core Web Vitals 目标

| 指标 | 良好 | 需改进 | 较差 |
|--------|------|-------------------|------|
| **LCP**（最大内容绘制） | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| **INP**（交互到下一次绘制） | ≤ 200ms | ≤ 500ms | > 500ms |
| **CLS**（累计布局偏移） | ≤ 0.1 | ≤ 0.25 | > 0.25 |

## 优化工作流

```
1. MEASURE  → Establish baseline with real data
2. IDENTIFY → Find the actual bottleneck (not assumed)
3. FIX      → Address the specific bottleneck
4. VERIFY   → Measure again; keep or revert
5. GUARD    → Add monitoring or tests to prevent regression
```

### 第 1 步：测量

两种互补的方法——两者都用：

- **合成测量（Lighthouse、DevTools 性能面板）：** 受控条件，可复现。最适合 CI 回归检测和隔离特定问题。
- **RUM（web-vitals 库、CrUX）：** 真实条件下真实用户的数据。验证一个修复是否真的改善了用户体验所必需。

**前端：**
```bash
# Synthetic: Lighthouse in Chrome DevTools (or CI)
# Chrome DevTools → Performance tab → Record
# Chrome DevTools MCP → Performance trace

# RUM: Web Vitals library in code
import { onLCP, onINP, onCLS } from 'web-vitals';

onLCP(console.log);
onINP(console.log);
onCLS(console.log);
```

**后端：**
```bash
# Response time logging
# Application Performance Monitoring (APM)
# Database query logging with timing

# Simple timing
console.time('db-query');
const result = await db.query(...);
console.timeEnd('db-query');
```

### 从哪里开始测量

用症状来决定先测量什么：

```
What is slow?
├── First page load
│   ├── Large bundle? --> Measure bundle size, check code splitting
│   ├── Slow server response? --> Measure TTFB in DevTools Network waterfall
│   │   ├── DNS long? --> Add dns-prefetch / preconnect for known origins
│   │   ├── TCP/TLS long? --> Enable HTTP/2, check edge deployment, keep-alive
│   │   └── Waiting (server) long? --> Profile backend, check queries and caching
│   └── Render-blocking resources? --> Check network waterfall for CSS/JS blocking
├── Interaction feels sluggish
│   ├── UI freezes on click? --> Profile main thread, look for long tasks (>50ms)
│   ├── Form input lag? --> Check re-renders, controlled component overhead
│   └── Animation jank? --> Check layout thrashing, forced reflows
├── Page after navigation
│   ├── Data loading? --> Measure API response times, check for waterfalls
│   └── Client rendering? --> Profile component render time, check for N+1 fetches
└── Backend / API
    ├── Single endpoint slow? --> Profile database queries, check indexes
    ├── All endpoints slow? --> Check connection pool, memory, CPU
    └── Intermittent slowness? --> Check for lock contention, GC pauses, external deps
```

### 第 2 步：识别瓶颈

按类别划分的常见瓶颈：

**前端：**

| 症状 | 可能原因 | 调查方法 |
|---------|-------------|---------------|
| LCP 缓慢 | 大图、阻塞渲染的资源、服务器慢 | 检查网络瀑布图、图片大小 |
| CLS 偏高 | 没有尺寸的图片、加载迟的内容、字体偏移 | 检查布局偏移归因 |
| INP 较差 | 主线程上的重型 JavaScript、大范围 DOM 更新 | 在性能跟踪中检查长任务 |
| 初始加载慢 | 大 bundle、大量网络请求 | 检查 bundle 大小、代码分割 |

**后端：**

| 症状 | 可能原因 | 调查方法 |
|---------|-------------|---------------|
| API 响应慢 | N+1 查询、缺少索引、未优化的查询 | 检查数据库查询日志 |
| 内存增长 | 泄漏的引用、无界缓存、大载荷 | 堆快照分析 |
| CPU 尖峰 | 同步重计算、正则回溯 | CPU 剖析 |
| 高延迟 | 缺少缓存、冗余计算、网络跳数 | 沿栈跟踪请求 |

### 第 3 步：修复常见反模式

#### N+1 查询（后端）

```typescript
// BAD: N+1 — one query per task for the owner
const tasks = await db.tasks.findMany();
for (const task of tasks) {
  task.owner = await db.users.findUnique({ where: { id: task.ownerId } });
}

// GOOD: Single query with join/include
const tasks = await db.tasks.findMany({
  include: { owner: true },
});
```

#### 无界数据获取

```typescript
// BAD: Fetching all records
const allTasks = await db.tasks.findMany();

// GOOD: Paginated with limits
const tasks = await db.tasks.findMany({
  take: 20,
  skip: (page - 1) * 20,
  orderBy: { createdAt: 'desc' },
});
```

#### 缺少图片优化（前端）

```html
<!-- BAD: No dimensions, no format optimization -->
<img src="/hero.jpg" />

<!-- GOOD: Hero / LCP image — art direction + resolution switching, high priority -->
<!--
  Two techniques combined:
  - Art direction (media): different crop/composition per breakpoint
  - Resolution switching (srcset + sizes): right file size per screen density
-->
<picture>
  <!-- Mobile: portrait crop (8:10) -->
  <source
    media="(max-width: 767px)"
    srcset="/hero-mobile-400.avif 400w, /hero-mobile-800.avif 800w"
    sizes="100vw"
    width="800"
    height="1000"
    type="image/avif"
  />
  <source
    media="(max-width: 767px)"
    srcset="/hero-mobile-400.webp 400w, /hero-mobile-800.webp 800w"
    sizes="100vw"
    width="800"
    height="1000"
    type="image/webp"
  />
  <!-- Desktop: landscape crop (2:1) -->
  <source
    srcset="/hero-800.avif 800w, /hero-1200.avif 1200w, /hero-1600.avif 1600w"
    sizes="(max-width: 1200px) 100vw, 1200px"
    width="1200"
    height="600"
    type="image/avif"
  />
  <source
    srcset="/hero-800.webp 800w, /hero-1200.webp 1200w, /hero-1600.webp 1600w"
    sizes="(max-width: 1200px) 100vw, 1200px"
    width="1200"
    height="600"
    type="image/webp"
  />
  <img
    src="/hero-desktop.jpg"
    width="1200"
    height="600"
    fetchpriority="high"
    alt="Hero image description"
  />
</picture>

<!-- GOOD: Below-the-fold image — lazy loaded + async decoding -->
<img
  src="/content.webp"
  width="800"
  height="400"
  loading="lazy"
  decoding="async"
  alt="Content image description"
/>
```

#### 不必要的重新渲染（React）

```tsx
// BAD: Creates new object on every render, causing children to re-render
function TaskList() {
  return <TaskFilters options={{ sortBy: 'date', order: 'desc' }} />;
}

// GOOD: Stable reference
const DEFAULT_OPTIONS = { sortBy: 'date', order: 'desc' } as const;
function TaskList() {
  return <TaskFilters options={DEFAULT_OPTIONS} />;
}

// Use React.memo for expensive components
const TaskItem = React.memo(function TaskItem({ task }: Props) {
  return <div>{/* expensive render */}</div>;
});

// Use useMemo for expensive computations
function TaskStats({ tasks }: Props) {
  const stats = useMemo(() => calculateStats(tasks), [tasks]);
  return <div>{stats.completed} / {stats.total}</div>;
}
```

#### 过大的 Bundle 体积

```typescript
// Modern bundlers (Vite, webpack 5+) handle named imports with tree-shaking automatically,
// provided the dependency ships ESM and is marked `sideEffects: false` in package.json.
// Profile before changing import styles — the real gains come from splitting and lazy loading.

// GOOD: Dynamic import for heavy, rarely-used features
const ChartLibrary = lazy(() => import('./ChartLibrary'));

// GOOD: Route-level code splitting wrapped in Suspense
const SettingsPage = lazy(() => import('./pages/Settings'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <SettingsPage />
    </Suspense>
  );
}
```

#### 缺少缓存（后端）

```typescript
// Cache frequently-read, rarely-changed data
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes
let cachedConfig: AppConfig | null = null;
let cacheExpiry = 0;

async function getAppConfig(): Promise<AppConfig> {
  if (cachedConfig && Date.now() < cacheExpiry) {
    return cachedConfig;
  }
  cachedConfig = await db.config.findFirst();
  cacheExpiry = Date.now() + CACHE_TTL;
  return cachedConfig;
}

// HTTP caching headers for static assets
app.use('/static', express.static('public', {
  maxAge: '1y',           // Cache for 1 year
  immutable: true,        // Never revalidate (use content hashing in filenames)
}));

// Cache-Control for API responses
res.set('Cache-Control', 'public, max-age=300'); // 5 minutes
```

### 第 4 步：验证（保留或回退）

在你重新测量之前，一个修复只是一个假设。这一步决定它能否存活。

**用测量基线相同的方式重新测量：** 相同的命令、相同的条件、相同的固定预算（墙上时钟时间、样本数或请求数）。用冷缓存取的基线与用热缓存得到的结果相比，测的是缓存，而不是你的变更。

**一次只改一件事。** 三个优化一起落地只会产生一个数字，你无法归因。如果它们必须一起发布，先单独测量每一个。

**要打败噪音，而不只是平均值。** 重复测量，把增量与运行间方差进行比较。在 ±5% 方差内取得 3% 的提升不算提升；那只是不同的样本。

然后严格决定：

| 与基线相比的结果 | 行动 |
|---|---|
| 超过阈值、测试全绿 | **保留。** 提交时在消息里带上前后数字。 |
| 在噪音范围内（无可测变化） | **回退。** |
| 更差 | **回退。** |
| 有改进，但有一个测试变红 | **回退。** 一个穿着胜利外衣的回归。 |

**「中性」是回退，不是保留。** 这是团队跳过的一步：变更已经写好，扔掉它感觉很浪费，所以它未经测量就落地了，代码库积累了从未带来任何东西的复杂度。你保留的代码，你要永远维护它。让它物有所值。

**正确性把关指标。** 测试套件保持全绿*并且*数字在变。一个通过丢弃产品所需的工作来取胜的「优化」（跳过一次验证、缓存了必须新鲜的东西、移除一个承载负荷的 `await`）是回归，不是胜利。

#### 记录每一次尝试，包括被回退的

被回退的工作不会在 git 历史中留下痕迹，这正是同一个死想法下个季度又被试一遍的原因。保留一份简短的账本，让一个被否定的想法保持被否定：

| 想法 | 基线 → 结果 | 裁决 | 原因 |
|---|---|---|---|
| 记忆化行组件 | INP 240ms → 235ms | 回退 | 在噪音范围内（±15ms）。行不是瓶颈。 |
| 虚拟化列表 | INP 240ms → 90ms | 保留 | 长任务从跟踪中消失了。 |
| 预连接到 API 来源 | LCP 2.8s → 2.8s | 回退 | 本来就是同源的。 |

PR 描述中的一节或仓库里的一个 `PERF.md` 都可以。重要的是下一个人（或下一个 agent）在提出实验前读到它，不会重跑一个已经失败过的。

## 性能预算

设定预算并执行它：

```
JavaScript bundle: < 200KB gzipped (initial load)
CSS: < 50KB gzipped
Images: < 200KB per image (above the fold)
Fonts: < 100KB total
API response time: < 200ms (p95)
Time to Interactive: < 3.5s on 4G
Lighthouse Performance score: ≥ 90
```

**在 CI 中执行：**
```bash
# Bundle size check
npx bundlesize --config bundlesize.config.json

# Lighthouse CI
npx lhci autorun
```

## 参见

详细的性能检查清单、优化命令和反模式参考参见 `references/performance-checklist.md`。


## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「我们以后再优化」 | 性能债会复利。现在就修复明显的反模式，把微优化推迟。 |
| 「在我机器上很快」 | 你的机器不是用户的机器。在具有代表性的硬件和网络上剖析。 |
| 「这个优化是显而易见的」 | 如果你没测量，你就不确定。先剖析。 |
| 「用户不会注意到 100ms」 | 研究表明 100ms 的延迟会影响转化率。用户注意到的比你想象的要多。 |
| 「框架会处理性能」 | 框架能预防一些问题，但修不了 N+1 查询或过大的 bundle。 |
| 「它没帮上多大忙，但也没坏处」 | 中性的变更是要回退的。你永远在为它们付维护费，却没得到任何回报。 |
| 「我们已经写完了，留着吧」 | 沉没成本。测量不会在乎这个变更写了多久。 |
| 「改进很明显，不用重新测量」 | 那重新测量也很便宜，而且能证明它。未被测量的「胜利」正是中性复杂度落地的方式。 |

## 危险信号

- 没有剖析数据支撑的优化
- 数据获取中的 N+1 查询模式
- 没有分页的列表端点
- 没有尺寸、懒加载或响应式尺寸的图片
- 未经评审就不断增长的 bundle 体积
- 生产环境没有性能监控
- 到处用 `React.memo` 和 `useMemo`（过度使用和不足使用一样糟）
- 没有重新测量来证明其合理性就保留的优化
- 多个优化打包进一次测量，导致无法归因到任何一个变更
- 一个需要修改、跳过或删除测试才能取得的「胜利」
- 同一个失败的优化被尝试了不止一次，因为没人记录第一次尝试

## 验证

在有任何与性能相关的变更之后：

- [ ] 存在前后测量数据（具体数字）
- [ ] 结果用与基线相同的方式重新测量（相同命令、相同条件）
- [ ] 改进超过了运行间方差，而不仅仅是平均值
- [ ] 没有战胜基线的变更被回退，而不是作为中性保留
- [ ] 尝试被记录下来，保留和回退的都记，这样死想法不会被重跑
- [ ] 特定的瓶颈已被识别并处理
- [ ] Core Web Vitals 处于「良好」阈值内
- [ ] bundle 体积没有显著增加
- [ ] 新的数据获取代码中没有 N+1 查询
- [ ] 性能预算在 CI 中通过（如果已配置）
- [ ] 现有测试仍然通过（优化没有破坏行为）
