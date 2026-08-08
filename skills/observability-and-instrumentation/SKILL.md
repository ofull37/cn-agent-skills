---
name: observability-and-instrumentation
description: 给代码埋点，让生产行为可见且可诊断。当添加日志、指标、追踪或告警时使用。当发布任何会在生产环境运行的功能、且需要证据证明它正常工作时使用。当有生产问题被报告，但你无法从现有数据判断发生了什么时使用。
---

# 可观测性与埋点

## 概述

你无法观测的代码，就是无法运维的代码。可观测性是从外部，用代码发出的遥测数据回答「系统在做什么、为什么？」的能力。埋点不是发布后的附加件——它和功能一起编写，就像测试一样。如果一个功能上线时没有遥测，第一个用户报告的 bug 就会变成考古，而不是一次查询。

## 何时使用

- 构建任何会在生产环境运行的功能
- 添加新服务、端点、后台任务或外部集成
- 一次生产事故花太长时间才诊断出来（「我们无法判断发生了什么」）
- 设置或评审告警规则
- 评审一个添加 I/O、重试、队列或跨服务调用的 PR

**不用于：**
- 诊断正在发生的故障——使用 `debugging-and-error-recovery` 技能（可观测性正是让该技能下次变快的东-西）
- 剖析和优化已测得的缓慢——使用 `performance-optimization` 技能
- 发布当天的监控检查清单和回滚触发器——参见 `shipping-and-launch` 技能；本技能覆盖喂养它们的埋点

## 流程

### 1. 在埋点之前先定义「正常」

没有问题的遥测就是噪音。在添加任何埋点之前，写下值班工程师会针对这个功能提出的 2-4 个问题：

```
FEATURE: checkout payment retry
QUESTIONS ON-CALL WILL ASK:
1. What fraction of payments succeed on first attempt vs after retry?
2. When a payment fails permanently, why? (provider error? timeout? validation?)
3. Is the payment provider slower than usual?
→ Every signal below must help answer one of these.
```

如果你说不出这些问题，你还没准备好埋点——你会记录一切，却什么也学不到。

### 2. 为每个问题选择正确的信号

| 信号 | 回答什么 | 成本特征 | 示例 |
|---|---|---|---|
| **结构化日志** | 「这个具体案例中发生了什么？」 | 每事件一次；随流量增长 | 带 provider 错误码的 `payment_failed` |
| **指标** | 「有多频繁 / 有多快，汇总来看？」 | 每序列固定；查询便宜 | provider 调用的 p99 延迟 |
| **追踪** | 「时间在跨服务中花在了哪里？」 | 每请求一次；通常采样 | 一次慢结账，按跳数分解 |

经验法则：指标告诉你**出了**问题，追踪告诉你**在哪**，日志告诉你**为什么**。

### 3. 结构化日志

记录事件，而不是散文。每一行日志都是一个 JSON 对象，带一个稳定的事件名和机器可读的字段：

```typescript
// BAD: string interpolation — unqueryable, inconsistent
logger.info(`Payment ${id} failed for user ${userId} after ${n} retries`);

// GOOD: stable event name + structured fields
logger.warn({
  event: 'payment_failed',
  paymentId: id,
  provider: 'stripe',
  errorCode: err.code,
  attempt: n,
}, 'payment failed');
```

**日志级别——一致地使用它们：**

| 级别 | 含义 | 值班行动 |
|---|---|---|
| `error` | 不变量被破坏；可能有人需要行动 | 调查 |
| `warn` | 已降级但已处理（重试成功、使用了回退） | 留意趋势 |
| `info` | 重要的业务事件（订单已下、任务已完成） | 无 |
| `debug` | 诊断细节 | 默认在生产中关闭 |

**关联 ID 是强制的。** 在系统边界生成（或接受）一个请求 ID，并把附加到每一行日志、每一个 span 和每一次出站调用上。没有它，你就无法从交错的日志中重建单个请求：

```typescript
// Express: child logger per request, ID propagated downstream
app.use((req, res, next) => {
  req.id = req.headers['x-request-id'] ?? crypto.randomUUID();
  req.log = logger.child({ requestId: req.id });
  res.setHeader('x-request-id', req.id);
  next();
});
```

**绝不记录密钥、令牌、密码或完整 PII。** 这是来自 `security-and-hardening` 技能的硬性规则——遥测管道是一条经典的数据泄漏路径。对字段做白名单；不要记录整个请求体。

### 4. 指标

对于请求驱动的服务，在每个端点和每个外部依赖上埋 **RED**：**R**ate（请求/秒）、**E**rrors（失败率）、**D**uration（延迟直方图，而不是平均值）。对于资源（队列、连接池、主机），使用 **USE**：**U**tilization（利用率）、**S**aturation（饱和）、**E**rrors（错误）。

与追踪一样，供应商无关的路径是 OpenTelemetry 指标 API（与第 5 步相同的 SDK 和上下文）。下面的示例使用 Prometheus 的 `prom-client`——一个常见的后端选择，不是唯一选择；RED/USE 和基数规则无论哪种都相同。

```typescript
import { Histogram } from 'prom-client';

const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status_class'],  // '2xx', not '200'
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});
```

**基数是失败模式。** 每一个唯一的标签组合都是一个独立的时间序列。标签必须来自小而固定的集合（路由模板、状态类别、provider 名）。绝不用用户 ID、原始 URL、错误消息或其他无界值作为标签——那些属于日志和追踪。

```
OK as label:    route="/api/tasks/:id"   status_class="5xx"   provider="stripe"
NEVER a label:  user_id, email, request_id, full URL, error message text
```

平均值永远不跟踪，百分位数始终跟踪：平均值会隐藏那 1% 体验很差的用户。使用直方图并读取 p50/p95/p99。

### 5. 分布式追踪

使用 OpenTelemetry——它是供应商无关的标准，而且自动埋点几乎零代码地覆盖 HTTP、gRPC 和常见 DB 客户端：

```typescript
// tracing.ts — must be imported before anything else
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  serviceName: 'checkout-service',
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

只在有意义的内在工作单元周围添加手动 span（例如 `applyDiscounts`、`chargeProvider`），并附加值班会用来过滤的属性。在每一个异步边界传播上下文——HTTP 头、队列消息元数据——否则追踪会在那个缺口处断掉。默认以低比率做基于头部（head-based）的采样；如果你的后端支持尾部（tail）采样，则保留 100% 的错误。

### 6. 告警

对**用户能感受到的症状**告警，而不是对原因：

```
SYMPTOM (page-worthy):           CAUSE (dashboard, not a page):
error rate > 1% for 5 min        CPU at 85%
p99 latency > 2s                 one pod restarted
queue age > 10 min               disk at 70%
```

基于原因的告警会在没什么问题的时候触发，却会漏掉你无法预见的故障。基于症状的告警正好在用户受到伤害时触发，无论原因是什么。

为你创建的每个告警设置规则：

1. **它必须是可行动的。** 如果应对是「忽略它，它会自愈」，就删除这个告警。
2. **它链接到一个 runbook**——哪怕只有三行：它意味着什么、要跑的第一个查询、升级路径。
3. **它有由 SLO 或历史数据证明的阈值和持续时间**，而不是靠猜。
4. 只使用两种严重级别：**page**（面向用户、立即行动）和 **ticket**（降级、本周行动）。第三级会变成噪音，训练人们忽略一切。

### 7. 验证遥测本身

埋点是代码；它可能出错。在宣布工作完成之前，触发路径并查看实际输出：

- 在 staging 中强制一个错误 → 用 `requestId` 在日志中找到它，确认字段是结构化的（不是 `[object Object]`）
- 发送测试流量 → 确认指标序列以预期的标签和合理的值出现
- 在追踪 UI 中跟随一个请求跨服务 → 没有断开的 span
- 把每个新告警各触发一次（临时降低阈值）→ 确认它到达正确的渠道，且 runbook 链接可用

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「它跑通了我再加日志」 | 「之后」会变成「第一次事故之后」，而那正是发现自己失明时最昂贵的时刻。边构建边埋点。 |
| 「日志越多 = 可观测性越强」 | 非结构化的噪音会让事故处理更慢，而不是更快。三个可查询的事件胜过三百行散文。 |
| 「先用 console.log 凑合」 | 非结构化输出无法过滤、关联或告警。结构化日志器一次性多花五分钟。 |
| 「出问题时我们看看仪表盘就行」 | 没有定义问题就建起来的仪表盘，给你看一切，唯独没有答案。从值班问题开始。 |
| 「重要的事都告警，之后再来调」 | 嘈杂的呼机训练人们忽略它。调优永远不会发生；被漏掉的真实 page 会发生。 |
| 「把用户 ID 当作指标标签让调试更容易」 | 它也会让你的指标后端崩溃。高基数查找属于日志和追踪。 |
| 「对我们两个服务来说，追踪是小题大做」 | 两个服务就意味着已有日志无法回答的跨服务延迟问题。自动埋点让成本趋近于零。 |

## 危险信号

- 一个带重试、队列或外部调用、却没有新增任何遥测的功能 PR
- 用字符串插值而不是结构化字段构建的日志行
- 没有关联/请求 ID——每一行日志都是孤儿
- 用用户 ID、原始 URL 或错误消息文本作为标签的指标（基数炸弹）
- 延迟只跟踪平均值，没有百分位数
- 每天都触发、又被不采取行动地确认掉的告警
- 对原因（CPU、内存）告警而呼人，同时面向用户的错误率却无人监控
- 日志中出现密钥、令牌或完整请求体
- 用「在我机器上能跑」作为生产功能健康的唯一证据

## 验证

给一个功能埋点之后，确认：

- [ ] 这个功能的值班问题已被写下来，且每个信号都映射到其中一个问题
- [ ] 所有日志输出都是结构化的（JSON），带稳定的事件名，且每一行都有关联 ID
- [ ] 任何日志行中都没有密钥、令牌或未经脱敏的 PII（抽查实际输出）
- [ ] 每个新端点和每个外部依赖都有 RED 指标，且标签集有界
- [ ] 延迟是直方图；p95/p99 可查询
- [ ] 单个请求可以在追踪 UI 中端到端跟随，没有断开的 span
- [ ] 每个新告警都是基于症状的、有 runbook 链接，并且已被测试触发过一次
- [ ] 在 staging 中诱导的一次失败仅靠遥测就定位到了，没有读源码

这个清单的一目了然版，包括发布前埋点闸门，参见 `references/observability-checklist.md`。
