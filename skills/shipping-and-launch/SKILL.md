---
name: shipping-and-launch
description: 准备生产发布。当准备部署到生产环境时使用。当你需要一份发布前检查清单、设置监控、规划分阶段发布，或需要回滚策略时使用。
---

# 发布与上线

## 概述

带着信心发布。目标不只是部署——而是安全地部署，有监控就位、有准备好的回滚计划，并清楚了解成功是什么样的。每次上线都应该是可回退的、可观测的和增量的。

## 何时使用

- 首次把功能部署到生产环境
- 向用户发布重大变更
- 迁移数据或基础设施
- 开启 beta 或抢先体验计划
- 任何带有风险的部署（所有部署都有）

## 发布前检查清单

### 代码质量

- [ ] 所有测试通过（单元、集成、e2e）
- [ ] 构建成功，且没有警告
- [ ] lint 和类型检查通过
- [ ] 代码已评审并批准
- [ ] 没有应在发布前解决的 TODO 注释
- [ ] 生产代码中没有 `console.log` 调试语句
- [ ] 错误处理覆盖预期的失败模式

### 安全

- [ ] 代码或版本控制中没有密钥
- [ ] 生态系统的依赖审计（`npm audit`、`pip-audit`、`cargo audit`、...）没有 critical 或 high 漏洞
- [ ] 所有面向用户的端点都有输入验证
- [ ] 认证和授权检查已就位
- [ ] 已配置安全响应头（CSP、HSTS 等）
- [ ] 认证端点有速率限制
- [ ] CORS 配置为特定来源（不是通配符）

### 性能

- [ ] Core Web Vitals 处于「良好」阈值内
- [ ] 关键路径没有 N+1 查询
- [ ] 图片已优化（压缩、响应式尺寸、懒加载）
- [ ] bundle 体积在预算内
- [ ] 数据库查询有适当的索引
- [ ] 为静态资源和重复查询配置了缓存

### 可访问性

- [ ] 所有交互元素都可以键盘导航
- [ ] 屏幕阅读器能够传达页面内容和结构
- [ ] 颜色对比度达到 WCAG 2.1 AA（文本 4.5:1）
- [ ] 模态框和动态内容的焦点管理正确
- [ ] 错误消息有描述性，并与表单字段关联
- [ ] axe-core 或 Lighthouse 中没有可访问性警告

### 基础设施

- [ ] 生产环境的环境变量已设置
- [ ] 数据库迁移已应用（或准备好应用）
- [ ] DNS 和 SSL 已配置
- [ ] 为静态资源配置了 CDN
- [ ] 已配置日志和错误报告
- [ ] 健康检查端点存在并能响应

### 文档

- [ ] README 已更新任何新的设置要求
- [ ] API 文档是最新的
- [ ] 为任何架构决策写了 ADR
- [ ] changelog 已更新
- [ ] 面向用户的文档已更新（如适用）

## 功能开关策略

藏在功能开关后面发布，以解耦部署与发布：

```typescript
// Feature flag check
const flags = await getFeatureFlags(userId);

if (flags.taskSharing) {
  // New feature: task sharing
  return <TaskSharingPanel task={task} />;
}

// Default: existing behavior
return null;
```

**功能开关生命周期：**

```
1. DEPLOY with flag OFF     → Code is in production but inactive
2. ENABLE for team/beta     → Internal testing in production environment
3. GRADUAL ROLLOUT          → 5% → 25% → 50% → 100% of users
4. MONITOR at each stage    → Watch error rates, performance, user feedback
5. CLEAN UP                 → Remove flag and dead code path after full rollout
```

**规则：**
- 每个功能开关都有一个所有者和一个到期日期
- 全面推广后 2 周内清理开关
- 不要嵌套功能开关（会产生指数级组合）
- 在 CI 中同时测试两种开关状态（开和关）

## 分阶段发布

### 发布序列

```
1. DEPLOY to staging
   └── Full test suite in staging environment
   └── Manual smoke test of critical flows

2. DEPLOY to production (feature flag OFF)
   └── Verify deployment succeeded (health check)
   └── Check error monitoring (no new errors)

3. ENABLE for team (flag ON for internal users)
   └── Team uses the feature in production
   └── 24-hour monitoring window

4. CANARY rollout (flag ON for 5% of users)
   └── Monitor error rates, latency, user behavior
   └── Compare metrics: canary vs. baseline
   └── 24-48 hour monitoring window
   └── Advance only if all thresholds pass (see table below)

5. GRADUAL increase (25% -> 50% -> 100%)
   └── Same monitoring at each step
   └── Ability to roll back to previous percentage at any point

6. FULL rollout (flag ON for all users)
   └── Monitor for 1 week
   └── Clean up feature flag
```

### 发布决策阈值

在每一个阶段用这些阈值决定是推进、暂缓还是回滚：

| 指标 | 推进（绿） | 暂缓并调查（黄） | 回滚（红） |
|--------|-----------------|-------------------------------|-----------------|
| 错误率 | 在基线的 10% 以内 | 高于基线 10-100% | 高于基线 2 倍以上 |
| P95 延迟 | 在基线的 20% 以内 | 高于基线 20-50% | 高于基线 50% 以上 |
| 客户端 JS 错误 | 没有新的错误类型 | 新错误 < 0.1% 的会话 | 新错误 > 0.1% 的会话 |
| 业务指标 | 中性或正向 | 下降 < 5%（可能是噪音） | 下降 > 5% |

### 何时回滚

出现以下情况立即回滚：
- 错误率比基线增加超过 2 倍
- P95 延迟增加超过 50%
- 用户报告的问题激增
- 检测到数据完整性问题
- 发现安全漏洞

## 监控与可观测性

### 监控什么

```
Application metrics:
├── Error rate (total and by endpoint)
├── Response time (p50, p95, p99)
├── Request volume
├── Active users
└── Key business metrics (conversion, engagement)

Infrastructure metrics:
├── CPU and memory utilization
├── Database connection pool usage
├── Disk space
├── Network latency
└── Queue depth (if applicable)

Client metrics:
├── Core Web Vitals (LCP, INP, CLS)
├── JavaScript errors
├── API error rates from client perspective
└── Page load time
```

### 错误报告

```typescript
// Set up error boundary with reporting
class ErrorBoundary extends React.Component {
  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // Report to error tracking service
    reportError(error, {
      componentStack: info.componentStack,
      userId: getCurrentUser()?.id,
      page: window.location.pathname,
    });
  }

  render() {
    if (this.state.hasError) {
      return <ErrorFallback onRetry={() => this.setState({ hasError: false })} />;
    }
    return this.props.children;
  }
}

// Server-side error reporting
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  reportError(err, {
    method: req.method,
    url: req.url,
    userId: req.user?.id,
  });

  // Don't expose internals to users
  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' },
  });
});
```

### 发布后验证

上线后的第一个小时内：

```
1. Check health endpoint returns 200
2. Check error monitoring dashboard (no new error types)
3. Check latency dashboard (no regression)
4. Test the critical user flow manually
5. Verify logs are flowing and readable
6. Confirm rollback mechanism works (dry run if possible)
```

## 回滚策略

每次部署在发生之前都需要一个回滚计划：

```markdown
## Rollback Plan for [Feature/Release]

### Trigger Conditions
- Error rate > 2x baseline
- P95 latency > [X]ms
- User reports of [specific issue]

### Rollback Steps
1. Disable feature flag (if applicable)
   OR
1. Deploy previous version: `git revert <commit> && git push`
2. Verify rollback: health check, error monitoring
3. Communicate: notify team of rollback

### Database Considerations
- Migration [X] has a rollback: `npx prisma migrate rollback`
- Data inserted by new feature: [preserved / cleaned up]

### Time to Rollback
- Feature flag: < 1 minute
- Redeploy previous version: < 5 minutes
- Database rollback: < 15 minutes
```

## 参见

- 每个变更在进入本清单之前必须通过的项目级完成定义（Definition of Done），参见 `references/definition-of-done.md`
- 安全发布前检查参见 `references/security-checklist.md`
- 性能发布前检查清单参见 `references/performance-checklist.md`
- 发布前的可访问性验证参见 `references/accessibility-checklist.md`

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「staging 能跑，生产也能跑」 | 生产环境有不同的数据、流量模式和边界情况。部署后要监控。 |
| 「这个不需要功能开关」 | 每个功能都受益于一个紧急关闭开关。即使是「简单」的变更也可能弄坏东西。 |
| 「监控是额外开销」 | 没有监控意味着你从用户投诉中发现问题，而不是从仪表盘中。 |
| 「我们以后再上监控」 | 在上线前就加上。你无法调试你看不到的东西。 |
| 「回滚等于承认失败」 | 回滚是负责任的工程。发布一个有问题的功能才是失败。 |

## 危险信号

- 没有回滚计划就部署
- 生产环境没有监控或错误报告
- 大爆炸式发布（一次全上，没有 staging）
- 没有到期日或所有者的功能开关
- 部署后第一个小时没人监控
- 生产环境配置靠记忆，而不是靠代码
- 「今天是周五下午，发了它」

## 验证

部署之前：

- [ ] 发布前检查清单已完成（所有部分为绿）
- [ ] 功能开关已配置（如适用）
- [ ] 回滚计划已记录
- [ ] 监控仪表盘已设置
- [ ] 团队已收到部署通知

部署之后：

- [ ] 健康检查返回 200
- [ ] 错误率正常
- [ ] 延迟正常
- [ ] 关键用户流程正常
- [ ] 日志在流动
- [ ] 回滚已测试或确认就绪
