---
description: 通过并行分发到专家角色来运行发布前检查清单，然后综合出 go/no-go 决策
---

调用 agent-skills:shipping-and-launch 技能。

`/ship` 是一个**扇出协调器**。它针对当前更改并行运行三个专家角色，然后将它们的报告合并为带有回滚计划的单一 go/no-go 决策。这些角色独立运行——没有共享状态，没有顺序依赖——这正是并行执行在这里既安全又有用的原因。

## 阶段 A — 并行扇出

使用 Agent 工具并发创建三个子代理。**在单个助手回合中发起全部三个 Agent 工具调用，让它们并行执行**——顺序调用会让本命令失去意义。

在 Claude Code 中，每次调用都要传入与该角色 `name` 字段匹配的 `subagent_type`：

1. **`code-reviewer`** — 对已暂存的更改或最近的提交进行五维评审（正确性、可读性、架构、安全、性能）。输出标准的评审模板。
2. **`security-auditor`** — 执行一轮漏洞与威胁建模检查。检查 OWASP Top 10、机密信息处理、认证/授权、依赖项 CVE。输出标准的审计报告。
3. **`test-engineer`** — 分析本次更改的测试覆盖率。识别快乐路径、边界情况、错误路径和并发场景中的缺口。输出标准的覆盖率分析。

在没有 Agent 工具的其他 harness 中，按顺序调用每个角色的 system prompt，并将它们的输出视为并行返回——合并阶段仍然有效。

约束（来自 Claude Code 的子代理模型）：
- 子代理不能创建其他子代理——不要让一个角色把工作委托给另一个角色。
- 每个子代理都有自己的上下文窗口，并且只向主会话返回它的报告。
- 如果你需要彼此交流而不仅仅是汇报的队友，请使用 Claude Code Agent Teams，并将这些角色引用为队友类型（参见 `references/orchestration-patterns.md`）。

**角色解析。** 如果你在 `.claude/agents/` 或 `~/.claude/agents/` 中定义了自己的 `code-reviewer`、`security-auditor` 或 `test-engineer`，这些定义会优先于本插件的版本——`/ship` 会自动采用你的自定义配置。这是有意为之：插件子代理位于 Claude Code 作用域优先级表的底部，因此用户级定义按设计胜出。

## 阶段 B — 在主上下文中合并

当三份报告都返回后，主代理（而非子角色）对它们进行综合：

1. **代码质量** — 汇总 `code-reviewer` 的 Critical/Important 发现，以及任何失败的测试、lint 或构建输出。解决评审者之间的重复项。
2. **安全** — 将 `security-auditor` 的任何 Critical/High 发现提升为发布阻塞项。与 `code-reviewer` 的安全维度交叉核对。
3. **性能** — 从 `code-reviewer` 的性能维度提取；如适用则交叉核对 Core Web Vitals。
4. **可访问性** — 验证键盘导航、屏幕阅读器支持、对比度（三个角色未覆盖——直接在此处理，或调用可访问性检查清单）。
5. **基础设施** — 环境变量、迁移、监控、功能开关。直接验证。
6. **文档** — README、ADR、changelog。直接验证。

## 阶段 C — 决策与回滚

产出一个单一的输出：

```markdown
## Ship Decision: GO | NO-GO

### Blockers (must fix before ship)
- [Source persona: Critical finding + file:line]

### Recommended fixes (should fix before ship)
- [Source persona: Important finding + file:line]

### Acknowledged risks (shipping anyway)
- [Risk + mitigation]

### Rollback plan
- Trigger conditions: [what signals would prompt rollback]
- Rollback procedure: [exact steps]
- Recovery time objective: [target]

### Specialist reports (full)
- [code-reviewer report]
- [security-auditor report]
- [test-engineer report]
```

## 规则

1. 阶段 A 的三个角色并行运行——绝不按顺序执行。
2. 角色之间不互相调用。主代理在阶段 B 中合并。
3. 在做出任何 GO 决策之前，回滚计划是强制性的。
4. 如果任何角色返回 Critical 发现，默认裁决为 NO-GO，除非用户明确接受该风险。
5. **仅当以下条件全部成立时才跳过扇出：** 更改涉及 2 个或更少的文件、diff 少于 50 行，并且不涉及认证、支付、数据访问或配置/环境。否则，默认进行扇出。`/ship` 是为面向生产的更改设计的——当爆炸半径不可忽视时，即使 diff 看起来很小，也要运行并行评审。
