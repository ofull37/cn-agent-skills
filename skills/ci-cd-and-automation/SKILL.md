---
name: ci-cd-and-automation
description: 自动化 CI/CD 流水线搭建。当设置或修改构建和部署流水线时使用。当你需要自动化质量门、在 CI 中配置测试运行器，或建立部署策略时使用。
---

# CI/CD 与自动化

## 概述

自动化质量门，让没有任何变更能在未通过测试、lint、类型检查和构建的情况下进入生产。CI/CD 是其他每一个技能的强制执行机制——它捕获人类和 agent 都会漏掉的东西，并且它对每一个变更都一致地执行。

**左移：** 尽可能在流水线早期发现问题。一个在 lint 中被抓到的 bug 只花几分钟；同一个 bug 在生产中被抓到要花几小时。把检查向上游移动——静态分析在测试之前，测试在 staging 之前，staging 在生产之前。

**更快即更安全：** 更小的批次和更频繁的发布降低风险，而不是增加风险。一次 3 个变更的部署比 30 个变更的更容易调试。频繁发布能建立对发布流程本身的信心。

## 何时使用

- 设置新项目的 CI 流水线
- 添加或修改自动化检查
- 配置部署流水线
- 当一个变更应该触发自动化验证时
- 调试 CI 失败

## 质量门流水线

每个变更在合并前都要经过这些门：

```
Pull Request Opened
    │
    ▼
┌─────────────────┐
│   LINT CHECK     │  eslint, prettier
│   ↓ pass         │
│   TYPE CHECK     │  tsc --noEmit
│   ↓ pass         │
│   UNIT TESTS     │  jest/vitest
│   ↓ pass         │
│   BUILD          │  npm run build
│   ↓ pass         │
│   INTEGRATION    │  API/DB tests
│   ↓ pass         │
│   E2E (optional) │  Playwright/Cypress
│   ↓ pass         │
│   SECURITY AUDIT │  npm audit
│   ↓ pass         │
│   BUNDLE SIZE    │  bundlesize check
└─────────────────┘
    │
    ▼
  Ready for review
```

**任何门都不能跳过。** 如果 lint 失败，就修 lint——不要禁用那条规则。如果测试失败，就修代码——不要跳过那个测试。

## GitHub Actions 配置

### 基本 CI 流水线

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Type check
        run: npx tsc --noEmit

      - name: Test
        run: npm test -- --coverage

      - name: Build
        run: npm run build

      - name: Security audit
        run: npm audit --audit-level=high
```

### 带数据库集成测试

```yaml
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: ci_user
          POSTGRES_PASSWORD: ${{ secrets.CI_DB_PASSWORD }}
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - name: Run migrations
        run: npx prisma migrate deploy
        env:
          DATABASE_URL: postgresql://ci_user:${{ secrets.CI_DB_PASSWORD }}@localhost:5432/testdb
      - name: Integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://ci_user:${{ secrets.CI_DB_PASSWORD }}@localhost:5432/testdb
```

> **注意：** 即使是仅用于 CI 的测试数据库，也要使用 GitHub Secrets 存储凭据，而不是硬编码值。这能培养好习惯，并防止测试凭据在其它上下文中的意外复用。

### E2E 测试

```yaml
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - name: Install Playwright
        run: npx playwright install --with-deps chromium
      - name: Build
        run: npm run build
      - name: Run E2E tests
        run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

## 把 CI 失败反馈给 Agent

CI 与 AI agent 结合的威力在于反馈回路。当 CI 失败时：

```
CI fails
    │
    ▼
Copy the failure output
    │
    ▼
Feed it to the agent:
"The CI pipeline failed with this error:
[paste specific error]
Fix the issue and verify locally before pushing again."
    │
    ▼
Agent fixes → pushes → CI runs again
```

**关键模式：**

```
Lint failure → Agent runs `npm run lint --fix` and commits
Type error  → Agent reads the error location and fixes the type
Test failure → Agent follows debugging-and-error-recovery skill
Build error → Agent checks config and dependencies
```

## 部署策略

### 预览部署

每个 PR 都有一个预览部署，用于手动测试：

```yaml
# Deploy preview on PR (Vercel/Netlify/etc.)
deploy-preview:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v4
    - name: Deploy preview
      run: npx vercel --token=${{ secrets.VERCEL_TOKEN }}
```

### 功能开关

功能开关把部署与发布解耦。把未完成或有风险的功能藏在开关后面部署，这样你可以：

- **交付代码但不启用它。** 及早合并到 main，准备好时再启用。
- **不重新部署即可回滚。** 关闭开关，而不是回退代码。
- **金丝雀发布新功能。** 先对 1% 的用户启用，然后 10%，然后 100%。
- **运行 A/B 测试。** 比较有功能与无功能时的行为。

```typescript
// Simple feature flag pattern
if (featureFlags.isEnabled('new-checkout-flow', { userId })) {
  return renderNewCheckout();
}
return renderLegacyCheckout();
```

**开关生命周期：** 创建 → 为测试启用 → 金丝雀 → 全面推广 → 移除开关和死代码。永远活着的开关会变成技术债——创建时就要设定清理日期。

### 分阶段发布

```
PR merged to main
    │
    ▼
  Staging deployment (auto)
    │ Manual verification
    ▼
  Production deployment (manual trigger or auto after staging)
    │
    ▼
  Monitor for errors (15-minute window)
    │
    ├── Errors detected → Rollback
    └── Clean → Done
```

### 回滚计划

每个部署都应该可回退：

```yaml
# Manual rollback workflow
name: Rollback
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Rollback deployment
        run: |
          # Deploy the specified previous version
          npx vercel rollback ${{ inputs.version }}
```

## 环境管理

```
.env.example       → Committed (template for developers)
.env                → NOT committed (local development)
.env.test           → Committed (test environment, no real secrets)
CI secrets          → Stored in GitHub Secrets / vault
Production secrets  → Stored in deployment platform / vault
```

CI 绝不应该拥有生产密钥。使用独立的密钥用于 CI 测试。

## CI 之外的自动化

### Dependabot / Renovate

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
```

### Build Cop 角色

指定一个人负责让 CI 保持全绿。当构建坏了时，Build Cop 的职责是修复或回退——而不是那个变更导致问题的人。这可以防止在每个人都以为别人会修的情况下，坏构建不断积累。

### PR 检查

- **必需评审：** 合并前至少 1 个批准
- **必需状态检查：** 合并前 CI 必须通过
- **分支保护：** 不允许强制推送到 main
- **自动合并：** 如果所有检查通过且已批准，自动合并

## CI 优化

当流水线超过 10 分钟时，按影响顺序应用这些策略：

```
Slow CI pipeline?
├── Cache dependencies
│   └── Use actions/cache or setup-node cache option for node_modules
├── Run jobs in parallel
│   └── Split lint, typecheck, test, build into separate parallel jobs
├── Only run what changed
│   └── Use path filters to skip unrelated jobs (e.g., skip e2e for docs-only PRs)
├── Use matrix builds
│   └── Shard test suites across multiple runners
├── Optimize the test suite
│   └── Remove slow tests from the critical path, run them on a schedule instead
└── Use larger runners
    └── GitHub-hosted larger runners or self-hosted for CPU-heavy builds
```

**示例：缓存与并行**
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm run lint

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npx tsc --noEmit

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm test -- --coverage
```

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「CI 太慢了」 | 优化流水线（见下方 CI 优化），不要跳过它。一个 5 分钟的流水线能省下几个小时的调试。 |
| 「这个变更是小事，跳过 CI」 | 琐碎的变更也会弄坏构建。况且 CI 对琐碎变更本来就很快。 |
| 「测试是偶发的，重跑就行」 | 偶发测试掩盖真实 bug，还浪费每个人的时间。修复不稳定性。 |
| 「我们以后再上 CI」 | 没有 CI 的项目会积累损坏状态。第一天就设置它。 |
| 「手动测试就够了」 | 手动测试不可扩展，也不可重复。尽可能自动化。 |

## 危险信号

- 项目没有 CI 流水线
- CI 失败被忽略或压住
- 为了让流水线通过而在 CI 中禁用测试
- 未经 staging 验证就部署到生产
- 没有回滚机制
- 密钥存在代码或 CI 配置文件里（而不是密钥管理器）
- CI 时间很长却没有优化投入

## 验证

在设置或修改 CI 之后：

- [ ] 所有质量门都已就位（lint、类型、测试、构建、审计）
- [ ] 流水线在每个 PR 和推送到 main 时运行
- [ ] 失败会阻止合并（已配置分支保护）
- [ ] CI 结果反馈回开发循环
- [ ] 密钥存储在密钥管理器中，而不是代码中
- [ ] 部署有回滚机制
- [ ] 测试套件的流水线运行时间在 10 分钟以内
