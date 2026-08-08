# AGENTS.md

本文件为在这个仓库中处理代码的 AI 编码智能体（Claude Code、Cursor、Copilot、Antigravity 等）提供指导。

> **范围：** 本文件用于配置在 [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) 仓库上工作的智能体。它不打算被复制到其他项目或全局 agent 配置中；可复用的资产是 `skills/` 下的技能，而不是本文件。

## 仓库概述

面向高级软件工程师的一套 Claude.ai 和 Claude Code 技能。技能是打包的指令和脚本，用于扩展 Claude 和你的编码智能体的能力。

## OpenCode 集成

OpenCode 采用由 `skill` 工具和本仓库 `/skills` 目录驱动的**技能驱动执行模型**。

### 核心规则

- 如果任务匹配某个技能，你必须调用它
- 技能位于 `skills/<skill-name>/SKILL.md`
- 如果有技能适用，绝不直接实现
- 始终严格遵循技能说明（不要只部分应用）

### 意图 → 技能映射

智能体应自动将用户意图映射到技能：

- 功能 / 新特性 → `spec-driven-development`，然后 `incremental-implementation`、`test-driven-development`
- 规划 / 任务拆解 → `planning-and-task-breakdown`
- Bug / 失败 / 意外行为 → `debugging-and-error-recovery`
- 代码评审 → `code-review-and-quality`
- 重构 / 简化 → `code-simplification`
- API 或接口设计 → `api-and-interface-design`
- UI 工作 → `frontend-ui-engineering`

### 生命周期映射（隐式命令）

OpenCode 不支持 `/spec` 或 `/plan` 之类的 slash 命令。

相反，智能体必须在内部遵循以下生命周期：

- 定义 → `spec-driven-development`
- 规划 → `planning-and-task-breakdown`
- 构建 → `incremental-implementation` + `test-driven-development`
- 验证 → `debugging-and-error-recovery`
- 评审 → `code-review-and-quality`
- 发布 → `shipping-and-launch`

### 执行模型

对于每个请求：

1. 判断是否有任何技能适用（哪怕只有 1% 的可能）
2. 使用 `skill` 工具调用合适的技能
3. 严格遵循技能工作流
4. 只有在所需步骤（spec、plan 等）完成之后才继续实现

### 反合理化借口

以下想法是错误的，必须忽略：

- 「这太小了，不需要技能」
- 「我可以直接快速实现」
- 「我先收集一下上下文」

正确行为：

- 始终先检查并使用技能

这确保 OpenCode 与 Claude Code 一样，会完整强制执行工作流。

## 编排：角色、技能与命令

这个仓库有三个可组合的层次。它们职责不同，不应混淆：

- **技能（Skills）**（`skills/<name>/SKILL.md`）——带有步骤和退出标准的工作流。即*怎么做*。当意图匹配时是必经的一环。
- **角色（Personas）**（`agents/<role>.md`）——带有视角和输出格式的角色。即*谁来做*。
- **Slash 命令**（`.claude/commands/*.md`）——面向用户的入口。即*何时做*。这是编排层。

组合规则：**用户（或 slash 命令）是编排者。角色不能调用其他角色。**角色可以调用技能。

这个仓库唯一认可的多角色编排模式是**并行扇出加合并步骤（parallel fan-out with a merge step）**——`/ship` 用它并行运行 `code-reviewer`、`security-auditor` 和 `test-engineer`，并综合它们的报告。不要构建一个决定调用哪个角色的「路由器」角色；那是 slash 命令和意图映射的职责。

决策矩阵见 [docs/agents.md](docs/agents.md)，完整模式目录见 [references/orchestration-patterns.md](references/orchestration-patterns.md)。

**Claude Code 互操作：**`agents/` 中的角色既可以作为 Claude Code 子代理（从本插件的 `agents/` 目录自动发现），也可以作为 Agent Teams 团队成员（生成时按名称引用）。两个平台约束与我们的规则一致：子代理不能生成其他子代理，团队不能嵌套。插件代理会静默忽略 `hooks`、`mcpServers` 和 `permissionMode` 这些 frontmatter 字段。

## 创建新技能

> **开始之前：**运行 [CONTRIBUTING.md](CONTRIBUTING.md#before-proposing-a-new-skill) 中的预检清单，搜索目录，检查开放的 PR（`gh pr list --state open`），确认想法符合 [docs/skill-anatomy.md](docs/skill-anatomy.md)，并在 PR 描述中说明该空白的必要性。大多数新技能的想法会与现有技能或开放 PR 重叠；优先扩展现有技能，而不是添加近乎重复的新技能。CONTRIBUTING.md 是本工作流的唯一权威来源。

这个仓库里的技能以 markdown 为主：每个技能位于 `skills/<kebab-case-name>/SKILL.md`，带 YAML frontmatter（`name`、`description`），并遵循章节结构（概述、何时使用、流程、常见合理化借口、危险信号、验证）。只有当技能包含可运行辅助脚本时才添加 `scripts/` 目录；大多数技能只有 markdown，而且没有按技能分发的 zip 包。

完整的格式、命名约定、frontmatter 规则、辅助文件阈值和写作原则，请参见 [docs/skill-anatomy.md](docs/skill-anatomy.md)——这是技能结构的唯一权威来源。不要在此处重述这些指导，直接链接到它。
