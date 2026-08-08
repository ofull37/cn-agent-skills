# agent-skills

这是 agent-skills 项目——一个面向 AI 编码智能体的生产级工程技能合集。

> **范围：** 本文件用于配置在 [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) 仓库上工作的智能体，而非其他项目。请勿将其复制到其他项目或全局 agent 配置中；可复用的资产是 `skills/` 下的技能。

## 项目结构

```
skills/       → Core skills (SKILL.md per directory)
agents/       → Reusable agent personas (code-reviewer, test-engineer, security-auditor, web-performance-auditor)
hooks/        → Session lifecycle hooks
.claude/commands/ → Slash commands (/spec, /plan, /build, /test, /review, /code-simplify, /ship; plus /webperf specialist audit)
references/   → Supplementary checklists (testing, performance, security, accessibility, observability)
evals/        → Skill eval cases + framework (see evals/README.md)
docs/         → Setup guides for different tools
```

## 按阶段划分的技能

**定义：** interview-me, idea-refine, spec-driven-development
**规划：** planning-and-task-breakdown
**构建：** incremental-implementation, test-driven-development, context-engineering, source-driven-development, doubt-driven-development, frontend-ui-engineering, api-and-interface-design
**验证：** browser-testing-with-devtools, debugging-and-error-recovery
**评审：** code-review-and-quality, code-simplification, security-and-hardening, performance-optimization
**发布：** git-workflow-and-versioning, ci-cd-and-automation, deprecation-and-migration, documentation-and-adrs, observability-and-instrumentation, shipping-and-launch

## 约定

- 每个技能都位于 `skills/<name>/SKILL.md`
- 带 `name` 和 `description` 字段的 YAML frontmatter
- 描述以技能的功能开头（第三人称），后接触发条件（「Use when...」）
- 每个技能都包含：概述、何时使用、流程、常见合理化借口、危险信号、验证
- 共享参考资料位于根目录 `references/`；对于自包含、可分发的技能，新兴的约定是将技能自身的参考资料放在 `skills/<name>/references/` 内
- 只有当内容超过 100 行时才创建辅助文件

## 参与贡献

在添加新技能或大幅重构现有技能之前，先运行 [CONTRIBUTING.md](CONTRIBUTING.md#before-proposing-a-new-skill) 中的预检清单：搜索目录、检查开放的 PR、确认想法符合 [docs/skill-anatomy.md](docs/skill-anatomy.md)，并说明该空白的必要性。优先扩展现有技能，而不是添加近乎重复的新技能。CONTRIBUTING.md 是本工作流的唯一权威来源；请勿在此处或其他地方重述其清单，直接链接到它。

## 命令

- `npm test` —— 不适用（这是一个文档项目）
- 校验：检查所有 SKILL.md 文件是否具有有效的、包含 name 和 description 的 YAML frontmatter
- 评测：`node scripts/run-evals.js` —— 对每个技能进行触发/路由评测（CI）；`--behavioral <skill>` 用于分级运行

## 拉取请求

PR 面向上游仓库的默认分支。在典型的 fork 设置中，上游 remote 是 `upstream`，你的 fork 是 `origin`，但确切的 remote 名称在这里并不重要。

- 在打开 PR 之前，搜索上游仓库中涉及相同文件或规则的开放 PR 和 issue。如有重叠，请协调（在其基础上构建、让你的规则与其对齐，或在其合并后 rebase），而不是打开一个冲突的 PR。
- 优先提交小而聚焦的 PR，而不是对广泛共享的文件（例如 `scripts/` 下的文件）进行大型重构，后者更可能与进行中的工作发生冲突。

## 边界

- 始终：在创建新技能目录之前运行 CONTRIBUTING.md 预检清单
- 始终：新技能遵循 skill-anatomy.md 格式
- 始终：打开新 PR 之前检查上游仓库的开放 PR 和 issue 是否存在重叠
- 绝不：添加泛泛而谈的建议而非可执行流程的技能
- 绝不：在技能之间重复内容——改为引用其他技能
