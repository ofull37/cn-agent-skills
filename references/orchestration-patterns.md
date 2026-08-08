# 编排模式

本仓库认可（endorse）的 agent 编排模式参考目录，以及应避免的反模式。在添加一个协调多个 persona 的新 slash 命令，或引入一个「包装」现有 persona 的新 persona 之前，先阅读本文。

核心规则：**用户（或 slash 命令）才是编排者。Persona 不调用其他 persona。** 技能是 persona 工作流内部的必经环节。

---

## 认可的模式

### 1. 直接调用（无编排）

单一 persona、单一视角、单一产物。这是默认选项，也是最便宜的选项。

```
user → code-reviewer → report → user
```

**何时使用：** 工作是对单个产物的一种视角，并且你能用一句话描述它。

**示例：**
- 「评审这个 PR」→ `code-reviewer`
- 「找出 `auth.ts` 中的安全问题」→ `security-auditor`
- 「checkout 流程缺少哪些测试？」→ `test-engineer`

**成本：** 一次往返。这是你始终应当用来对照编排模式的基准。

---

### 2. 单 persona 的 slash 命令

一个用项目的技能包装单个 persona 的 slash 命令。省去用户每次重新解释工作流的麻烦。

```
/review → code-reviewer (with code-review-and-quality skill) → report
```

**何时使用：** 相同的单 persona 调用以相同的设置反复出现。

**本仓库中的示例：** `/review`、`/test`、`/code-simplify`。

**成本：** 与直接调用相同。slash 命令只是一个保存下来的提示词。

**反向信号：** 如果 slash 命令的正文主要是「决定该调用哪个 persona」，就删掉它，让用户直接调用 persona。

---

### 3. 带合并的并行展开

多个 persona 并发处理同一输入，各自产出一份独立报告。一个合并步骤（在主 agent 的上下文中）将它们综合成单一决策。

```
                    ┌─→ code-reviewer    ─┐
/ship → fan out  ───┼─→ security-auditor ─┤→ merge → go/no-go + rollback
                    └─→ test-engineer    ─┘
```

**何时使用：**
- 子任务真正相互独立（没有共享可变状态、没有顺序依赖）
- 每个子 agent 受益于自己的上下文窗口
- 合并步骤足够小，能留在主上下文中
- 挂钟延迟很重要

**本仓库中的示例：** `/ship`。

**成本：** N 个并行的子 agent 上下文 + 一次合并回合。高于直接调用，但挂钟更快，并且由于每个子 agent 保持对单一视角的关注，产出的报告质量更好。

**采纳此模式前的验证清单：**
- [ ] 我能同时运行所有子 agent 而没有顺序问题吗？
- [ ] 每个 persona 是否产出*种类*不同的发现，而不只是从不同角度得出的同一发现？
- [ ] 合并步骤是否能装进主 agent 剩余的上下文？
- [ ] 用户的等待时间是否足够长，让并行真正可感知？

如果任一答案为「否」，回退到直接调用或单 persona 命令。

---

### 4. 由用户驱动的顺序 slash 命令流水线

用户按定义好的顺序运行 slash 命令，在它们之间传递上下文（或提交历史）。没有编排 agent——用户就是编排者。

```
user runs:  /spec  →  /plan  →  /build  →  /test  →  /review  →  /ship
```

**何时使用：** 工作流有依赖（每一步需要上一步的输出），并且步骤之间的人工判断能增加价值。

**本仓库中的示例：** 完整的 DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP 生命周期。

**成本：** 每步一个子 agent 上下文。对编排层而言是免费的，因为没有编排 agent。

**为什么不让它自动化：** LLM「生命周期编排器」会（a）在步骤之间丢失细微差别，因为它必须为交接做摘要，（b）跳过那些能及早发现错误方向工作的人工检查点，以及（c）通过转述回合使 token 成本翻倍。

---

### 5. 研究隔离（上下文保护）

当任务需要阅读大量不应污染主上下文的材料时，派生一个只返回摘要的研究子 agent。

```
main agent → research sub-agent (reads 50 files) → digest → main agent continues
```

**何时使用：**
- 主会话需要保持对下游任务的专注
- 调查结果远小于它消耗的输入
- 决策质量受益于主 agent 事后有思考空间

**示例：** 「找出 monorepo 中这个已废弃 API 的每个调用点」、「总结这 30 份 ADR 对缓存的看法」。

**成本：** 一个隔离的子 agent 上下文。只要替代方案是把数百个文件加载进主上下文，就值得。

**在 Claude Code 上，使用内置的 `Explore` 子 agent** 而不是定义自定义的研究 persona。`Explore` 在 Haiku 上运行、被禁止使用写入/编辑工具，并且就是为此模式而生的。只有当 `Explore` 不合适时才定义自定义研究子 agent（例如，你需要一个模型无法推断的领域特定系统提示）。

---

## Claude Code 兼容性

本目录与 harness 无关，但大多数读者会在 Claude Code 上运行它。下面说明每种模式如何映射到 Claude Code 的原语——以及平台在哪些地方替我们强制执行规则。

### Persona 存放位置

插件子 agent 放在插件根目录的 `agents/` 中。本仓库是一个插件（`.claude-plugin/plugin.json`），因此插件启用时，`agents/code-reviewer.md`、`agents/security-auditor.md` 和 `agents/test-engineer.md` 会被自动发现。无需任何路径配置。

### 子 agent vs. Agent Teams

Claude Code 有两种并行原语。模式 3（带合并的并行展开）映射到**子 agent**。如果你需要互相沟通的队友，改用 **Agent Teams**。

| | 子 agent | Agent Teams |
|--|-----------|-------------|
| 协调 | 主 agent 展开，子 agent 只回传报告 | 队友互相发消息，共享任务清单 |
| 上下文 | 每个子 agent 自己的上下文窗口 | 每个队友自己的上下文窗口 |
| 何时使用 | 产出报告的独立任务 | 需要讨论的协作工作 |
| 状态 | 稳定 | 实验性——需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| 成本 | 较低 | 较高——每个队友都是独立的 Claude 实例 |

**本仓库中的 persona 两种模式都可用。** 当作为子 agent 派生时（例如由 `/ship`），它们向主会话报告发现。当作为队友派生时（`Spawn a teammate using the security-auditor agent type…`），它们可以直接质疑彼此的发现。persona 定义相同；变化的只是派生上下文。

一个微妙之处：persona 中的 `skills` 和 `mcpServers` frontmatter 字段在作为子 agent 运行时会被采用，但在**作为队友运行时会被忽略**——队友从你的项目和用户设置加载技能与 MCP 服务器，与普通会话一样。如果某个 persona 依赖加载特定的技能或 MCP 服务器，请在会话级别配置它，使其在两种模式下都可用。

### 平台强制执行的规则

本目录中的两条规则不只是约定——Claude Code 会强制执行：

- **「子 agent 不能再派生子 agent」**（引用文档原文）。反模式 B（persona 调用 persona）和反模式 D（深层 persona 树）在 Claude Code 上从构造上就不可能存在。
- **「禁止嵌套团队」**——队友不能派生自己的团队。同样的反模式在团队层面被阻止。

这意味着你可以放心采纳本目录中的模式，而不用担心贡献者意外构建出反模式。它们只会加载失败。

### 需要了解的内置子 agent

在定义自定义子 agent 之前，先检查以下某个是否已覆盖该角色：

| 内置 | 用途 |
|----------|---------|
| `Explore` | 只读的代码库搜索与分析。用于模式 5（研究隔离）。 |
| `Plan` | 规划模式期间的只读研究。 |
| `general-purpose` | 既需要探索又需要修改的多步骤任务。 |

不要重新定义它们。把你的专业 persona（code-reviewer、security-auditor、test-engineer）叠加在它们之上。

### 插件 agent 的 frontmatter 限制

插件子 agent **不**支持 `hooks`、`mcpServers` 或 `permissionMode` frontmatter 字段——它们会被静默忽略。如果未来的 persona 需要其中任何一个，用户必须把文件复制到 `.claude/agents/` 或 `~/.claude/agents/` 中。

在插件 agent 中**确实**生效的字段是：`name`、`description`、`tools`、`disallowedTools`、`model`、`maxTurns`、`skills`、`memory`、`background`、`effort`、`isolation`、`color`、`initialPrompt`。如果你想优化成本，可以为每个 persona 使用 `model`（例如 `test-engineer` 的覆盖率扫描用 Haiku、`code-reviewer` 用 Sonnet、`security-auditor` 用 Opus）。

### 并行派生多个子 agent

在 Claude Code 中，并行展开（模式 3）要求**在单次 assistant 回合中发出多次 Agent 工具调用**。顺序回合会串行执行。`/ship` 明确指出了这一点。任何新的编排命令也应如此。

---

## 工作示例：用 Agent Teams 进行竞争性假设调试

这个示例展示了何时该用 **Agent Teams** 而非 `/ship` 的子 agent 展开。两种模式乍看相似——都派生相同的三个 persona——但价值来自不同的地方。

### 场景

> *Checkout occasionally hangs for ~30 seconds before completing. It happens roughly once every 50 sessions. No errors in logs. Started after last week's release.*

（结账偶尔会挂起约 30 秒才完成。大约每 50 个会话发生一次。日志中没有错误。自上周末的发布之后开始。）

合理的根因（互斥，都符合症状）：

1. 新的支付确认流程中的竞态条件
2. 某个偶发落到慢速同步网络调用的认证检查
3. 某条随购物车规模扩大的查询缺少索引
4. 某个不稳定的第三方 API，其 SDK 在超时前静默重试

单个 agent 会选择第一个说得通的理论就停止调查。`/ship` 式的子 agent 展开会让每个 persona 独立报告——但它们的报告永远不会相遇，所以没有任何东西能排除错误的理论。

这正是 Agent Teams 文档描述的情况：*「当多个独立调查者积极试图互相证伪时，幸存下来的理论极有可能就是真正的根因。」*

### 为什么这*不是*一项 `/ship` 的工作

| | `/ship`（子 agent） | Agent Teams |
|--|--------------------|-------------|
| 子 agent 能看到 | 同一个 diff、不同的视角 | 共享任务清单、彼此的消忸 |
| 输出 | 三份独立报告 → 一次合并 | 对抗性辩论 → 共识根因 |
| 适合 | 你希望对已知产物得到裁决 | 你想在假设*中找出*产物 |

`/ship` 是一份裁决；Agent Teams 是一次调查。

### 设置（一次性，每个环境）

Agent Teams 是实验性的。在 `~/.claude/settings.json` 中：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

需要 Claude Code v2.1.32 或更高版本。本仓库中的 persona 会被自动拾取——无需手动编写团队配置文件。

### 触发提示词

在主会话中，用自然语言输入：

```
Users report checkout hangs for ~30 seconds intermittently after last
week's release. No errors in logs.

Create an agent team to debug this with competing hypotheses. Spawn
three teammates using the existing agent types:

  - code-reviewer  — investigate race conditions and blocking calls
                     in the checkout code path
  - security-auditor — investigate auth checks, session handling,
                       and any synchronous network calls added recently
  - test-engineer  — propose tests that would distinguish between the
                     hypotheses and check coverage gaps in checkout

Have them message each other directly to challenge each other's
theories. Update findings as consensus emerges. Only converge when
two teammates agree they can disprove the others'.
```

主会话派生三个引用现有 persona 名的队友。persona 正文会被**追加**到每个队友的系统提示中，作为额外指令（叠加在主会话安装的团队协调指令之上）；上面的触发提示词就是它们的任务。

### 会发生什么

1. 每个队友在自己的上下文窗口中运行，从自己的视角探索代码库。
2. 队友用 `message` 直接互相发送发现。主会话无需转发。
3. 共享任务清单显示谁在调查什么——任何时候都可以用 `Ctrl+T`（进程内模式）或在 tmux 面板中（分割模式）查看。
4. 当 `code-reviewer` 发现一个应为顺序执行的 `Promise.all` 时，它会发消息给 `security-auditor`，确认认证调用不是竞态的一部分。`security-auditor` 检查并回复——要么确认竞态是真正的问题，要么给出反证。
5. `test-engineer` 为当前占上风的理论提出一个聚焦的集成测试，团队用它验证后再宣布共识。
6. 主会话综合收敛后的发现并呈现给你。

你可以用 `Shift+Down` 循环到任何队友并输入，从而打断它——适用于把误入歧途的调查者拉回来。

### 何时清理

当调查锁定根因后，告诉主会话：

```
Clean up the team
```

始终通过主会话清理，而不是通过队友（根据文档：队友缺少团队级上下文来执行清理）。

### 成本预期

三个 Sonnet 队友运行约 10–15 分钟的调查，成本明显高于由 `/ship` 将同样的三个 persona 作为子 agent 派生。其正当性是*结论的质量*——在错误的修复代价高昂的生产调试中，多花这些 token 很划算。对于常规的 PR 评审，坚持用 `/ship`。

### 此场景中的反模式

**不要**把它重新构建成一个展开子 agent 的 `/debug` slash 命令。子 agent 不能互相发消息——你会失去让这个模式发挥作用的对抗性辩论。如果某个工作流反复出现，把上面的触发提示词作为片段记录下来，而不是把它包装进一个误用子 agent 的 slash 命令。

### 何时*不*用 Agent Teams

- 对已知 diff 做生产上线的裁决 → 使用 `/ship`（子 agent）。
- 对一个产物的一种专家视角 → 直接调用 persona。
- 顺序生命周期（spec → plan → build）→ 用户驱动的 slash 命令（模式 4）。
- 以小块摘要为结果的重阅读型研究 → 内置 `Explore` 子 agent。

只有当队友**需要**互相挑战才能得出正确答案时，才使用 Agent Teams。

---

## 反模式

### A. 路由器 persona（「元编排器」）

一个职责是决定该调用哪个其他 persona 的 persona。

```
/work → router-persona → "this needs a review" → code-reviewer → router (paraphrases) → user
```

**它为何失败：**
- 纯粹的路由层，没有领域价值
- 增加两次转述跳数 → 信息丢失 + 约 2 倍 token 成本
- 用户本来就知道自己想要评审；他们可以直接调用 `/review`
- 复制了 slash 命令和 `AGENTS.md` 中的意图映射已经做的工作

**应改为：** 添加或打磨 slash 命令。在 `AGENTS.md` 中记录意图 → 命令的映射。

---

### B. 调用另一个 persona 的 persona

一个在见到认证代码时内部调用 `security-auditor` 的 `code-reviewer`。

**它为何失败：**
- Persona 被设计为产出单一视角；把它们串起来违背了这一点
- 调用方 persona 传出的摘要丢失了被调用 persona 需要的上下文
- 失败模式成倍增加（谁的输出格式胜出？谁的规则适用？）
- 向用户隐藏成本

**应改为：** 让调用方 persona 在自己的报告中*建议*进行一次后续审计。由用户或 slash 命令运行第二次审查。

---

### C. 会转述的顺序编排器

一个代替用户依次调用 `/spec`、然后 `/plan`、然后 `/build` 等的 agent。

**它为何失败：**
- 丢失了能及早发现错误方向工作的人工检查点
- 每次交接都会总结上下文——在长流水线中累积漂移
- token 成本翻倍：每一步都要编排器回合 + 子 agent 回合
- 恰恰在最需要判断力的地方剥夺了用户的自主权

**应改为：** 让用户保持编排者身份。在 `README.md` 中记录推荐的顺序，让用户自己调用它。

---

### D. 深层 persona 树

`/ship` 调用一个 `pre-ship-coordinator`，后者调用一个 `quality-coordinator`，后者再调用 `code-reviewer`。

**它为何失败：**
- 每一层都增加延迟和 token，却没有决策价值
- 调试变成多层次的调查
- 叶子 persona 在多次摘要步骤中丢失上下文

**应改为：** 将编排深度保持至多 1 层（slash 命令 → personas）。合并发生在主 agent 中。

---

## 决策流程

在考虑一个新的编排工作流时，走一遍这个流程：

```
Is the work one perspective on one artifact?
├── Yes → Direct invocation. Stop.
└── No  → Will the same composition repeat?
         ├── No  → Direct invocation, ad hoc. Stop.
         └── Yes → Are sub-tasks independent?
                  ├── No  → Sequential slash commands run by user (Pattern 4).
                  └── Yes → Parallel fan-out with merge (Pattern 3).
                           Validate against the checklist above.
                           If any check fails → fall back to single-persona command (Pattern 2).
```

---

## 何时向本目录添加新模式

只有满足以下条件后才添加新条目：

1. 你已在实际工作中至少用过该模式两次
2. 你能说出本仓库中一个演示它的具体产物
3. 你能解释为什么现有模式行不通
4. 你能描述它的反模式影子（人们会错误地构建成什么样）

过早加入的目录条目会变成没人遵循的理想化文档。
