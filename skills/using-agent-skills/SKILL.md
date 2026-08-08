---
name: using-agent-skills
description: 发现并调用 agent 技能。当开始一个会话，或需要发现哪个技能适用于当前任务时使用。这是统领所有其他技能如何被发现和调用的元技能。
---

# 使用 Agent 技能

## 概述

Agent Skills 是一套按开发阶段组织的工程工作流技能集合。每个技能编码了高级工程师遵循的特定流程。这个元技能帮助你为当前任务发现并应用正确的技能。

## 技能发现

当一个任务到达时，识别开发阶段并应用相应的技能：

```
Task arrives
    │
    ├── Don't know what you want yet? ──────→ interview-me
    ├── Have a rough concept, need variants? → idea-refine
    ├── New project/feature/change? ──→ spec-driven-development
    ├── Have a spec, need tasks? ──────→ planning-and-task-breakdown
    ├── Implementing code? ────────────→ incremental-implementation
    │   ├── UI work? ─────────────────→ frontend-ui-engineering
    │   ├── API work? ────────────────→ api-and-interface-design
    │   ├── Need better context? ─────→ context-engineering
    │   ├── Need doc-verified code? ───→ source-driven-development
    │   └── Stakes high / unfamiliar code? ──→ doubt-driven-development
    ├── Writing/running tests? ────────→ test-driven-development
    │   └── Browser-based? ───────────→ browser-testing-with-devtools
    ├── Something broke? ──────────────→ debugging-and-error-recovery
    ├── Reviewing code? ───────────────→ code-review-and-quality
    │   ├── Too complex? ─────────────→ code-simplification
    │   ├── Security concerns? ───────→ security-and-hardening
    │   └── Performance concerns? ────→ performance-optimization
    ├── Committing/branching? ─────────→ git-workflow-and-versioning
    ├── CI/CD pipeline work? ──────────→ ci-cd-and-automation
    ├── Deprecating/migrating? ────────→ deprecation-and-migration
    ├── Writing docs/ADRs? ───────────→ documentation-and-adrs
    ├── Adding logs/metrics/alerts? ───→ observability-and-instrumentation
    └── Deploying/launching? ─────────→ shipping-and-launch
```

## 核心操作行为

这些行为在任何时候、跨所有技能都适用。它们是无可商量的。

### 1. 表面化假设

在实现任何非平凡的东西之前，明确陈述你的假设：

```
ASSUMPTIONS I'M MAKING:
1. [assumption about requirements]
2. [assumption about architecture]
3. [assumption about scope]
→ Correct me now or I'll proceed with these.
```

不要默默填补模糊的需求。最常见的失败模式是做出错误的假设，然后不加检查地带着它往前跑。及早表面化不确定性——它比重做便宜。

### 2. 主动管理困惑

当你遇到不一致、冲突的需求或不清楚的规格说明时：

1. **停止。** 不要带着猜测继续。
2. 说出具体的困惑。
3. 摆出权衡，或提出澄清问题。
4. 在解决之前等待，再继续。

**坏：** 默默选择一个解释，并祈祷它是对的。
**好：**「我在 spec 里看到了 X，但在现有代码里是 Y。哪个优先？」

### 3. 该反驳时就反驳

你不是一个只会说「是」的机器。当一个方案有明显问题时：

- 直接指出问题
- 解释具体的坏处（尽可能量化——「这会增加约 200ms 延迟」，而不是「这可能更慢」）
- 提出替代方案
- 如果人类在掌握完整信息的情况下否决了你的意见，接受他们的决定

奉承是失败模式。「当然！」然后去实现一个坏主意，对谁都没有帮助。诚实的技-术分歧比虚假的一致更有价值。

### 4. 强制简洁

你的自然倾向是过度复杂化。主动抵制它。

在完成任何实现之前，问：
- 这件事能不能用更少的行数完成？
- 这些抽象是否值得它们的复杂度？
- 一位资深工程师看到这个会不会说「你为什么不直接…」？

如果你写了 1000 行而 100 行就够了，你就失败了。宁可采用平淡、显而易见的方案。炫技是昂贵的。

### 5. 保持范围纪律

只触碰你被要求触碰的东西。

不要：
- 移除你不理解的注释
- 「清理」与任务正交的代码
- 顺手重构相邻的系统
- 未经明确批准就删除看起来没用的代码
- 添加 spec 里没有的功能，因为「它们似乎有用」

你的工作是外科手术般的精准，而不是未经邀请的大动干戈。

### 6. 验证，而不是假设

每个技能都包含一个验证步骤。在验证通过之前，任务不算完成。「看起来对」从来不够——必须有证据（通过的测试、构建输出、运行时数据）。

按技能验证是局部检查。适用于*每一个*变更（无论哪个技能生效）的项目级标准是完成定义（Definition of Done）：测试通过、没有回归、行为在运行时得到验证、文档已更新。参见 `references/definition-of-done.md`。它是对每个任务验收标准的补充，而不是替代。

## 要避免的失败模式

这些是看似高产、却制造问题的微妙错误：

1. 不检查就做出错误假设
2. 不管理自己的困惑——迷失时仍埋头前进
3. 不表面化你注意到的不一致
4. 不在不明显的决策上摆出权衡
5. 对有明显问题的方案阿谀奉承（「当然！」）
6. 过度复杂化代码和 API
7. 修改与任务正交的代码或注释
8. 移除你不完全理解的东西
9. 因为「这是显而易见的」就在没有 spec 的情况下构建
10. 因为「看起来对」就跳过验证

## 技能规则

1. **开始工作前检查是否有适用的技能。** 技能编码了防止常见错误的流程。

2. **技能是工作流，不是建议。** 按顺序遵循步骤。不要跳过验证步骤。

3. **多个技能可以同时适用。** 一个功能实现可能按顺序涉及 `idea-refine` → `spec-driven-development` → `planning-and-task-breakdown` → `incremental-implementation` → `test-driven-development` → `code-review-and-quality` → `code-simplification` → `shipping-and-launch`。

4. **有疑问时，从 spec 开始。** 如果任务是非平凡的且没有 spec，从 `spec-driven-development` 开始。

## 生命周期序列

对于一个完整的功能，典型的技能序列是：

```
1.  interview-me                → Extract what the user actually wants
2.  idea-refine                 → Refine vague ideas
3.  spec-driven-development     → Define what we're building
4.  planning-and-task-breakdown → Break into verifiable chunks
5.  context-engineering         → Load the right context
6.  source-driven-development   → Verify against official docs
7.  incremental-implementation  → Build slice by slice
8.  observability-and-instrumentation → Instrument as you build (runs parallel with 7-9, not after)
9.  doubt-driven-development    → Cross-examine non-trivial decisions in-flight
10. test-driven-development     → Prove each slice works
11. code-review-and-quality     → Review before merge
12. code-simplification         → Reduce unnecessary complexity while preserving behavior
13. git-workflow-and-versioning → Clean commit history
14. documentation-and-adrs      → Document decisions
15. deprecation-and-migration   → Retire old systems and move users safely when needed
16. shipping-and-launch         → Deploy safely
```

不是每个任务都需要每个技能。一个 bug 修复可能只需要：`debugging-and-error-recovery` → `test-driven-development` → `code-review-and-quality`。

## 速查表

| 阶段 | 技能 | 一句话摘要 |
|-------|-------|-----------------|
| 定义 | interview-me | 在任何计划、spec 或代码存在之前，表面化用户真正想要的东西 |
| 定义 | idea-refine | 通过结构化的发散与收敛思维来提炼想法 |
| 定义 | spec-driven-development | 在写代码之前先有需求和验收标准 |
| 计划 | planning-and-task-breakdown | 分解成小的、可验证的任务 |
| 构建 | incremental-implementation | 薄的垂直切片，在扩展之前逐个测试 |
| 构建 | source-driven-development | 在实现之前对照官方文档验证 |
| 构建 | doubt-driven-development | 对每个非平凡决策做对抗性的新上下文评审 |
| 构建 | context-engineering | 在正确的时间加载正确的上下文 |
| 构建 | frontend-ui-engineering | 带可访问性的生产级 UI |
| 构建 | api-and-interface-design | 带清晰契约的稳定接口 |
| 验证 | test-driven-development | 先写失败的测试，然后让它通过 |
| 验证 | browser-testing-with-devtools | 用 Chrome DevTools MCP 做运行时验证 |
| 验证 | debugging-and-error-recovery | 复现 → 定位 → 修复 → 防护 |
| 评审 | code-review-and-quality | 带质量门的五维评审 |
| 评审 | code-simplification | 减少不必要复杂度的同时保持行为不变 |
| 评审 | security-and-hardening | OWASP 防护、输入验证、最小权限 |
| 评审 | performance-optimization | 先测量，只优化重要的东西 |
| 发布 | git-workflow-and-versioning | 原子提交、干净历史 |
| 发布 | ci-cd-and-automation | 每个变更上的自动化质量门 |
| 发布 | deprecation-and-migration | 移除旧系统并安全地迁移用户 |
| 发布 | documentation-and-adrs | 记录为什么，而不只是什么 |
| 发布 | observability-and-instrumentation | 结构化日志、RED 指标、追踪、基于症状的告警 |
| 发布 | shipping-and-launch | 发布前检查清单、监控、回滚计划 |
