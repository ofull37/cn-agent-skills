# Agent Skills

**面向 AI 编码智能体的生产级工程技能。**

技能将高级工程师构建软件时使用的工作流、质量门禁和最佳实践编码化。这些技能被打包成可复用资产，让 AI 智能体在开发的每个阶段都能一致地遵循它们。

<a href="https://trendshift.io/repositories/25200" target="_blank"><img src="https://trendshift.io/api/badge/repositories/25200" alt="addyosmani%2Fagent-skills | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

![Addy's Agent Skills](https://addyosmani.com/assets/images/addys-agent-skills.jpg)

```
  DEFINE          PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ Spec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  PRD │      │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────┘      └──────┘      └──────┘      └──────┘      └──────┘
  /spec          /plan          /build        /test         /review       /ship
```

---

## 命令

8 个 slash 命令，对应开发生命周期的各个阶段。每个命令都会自动激活合适的技能。

| 你正在做什么 | 命令 | 核心原则 |
|-------------------|---------|---------------|
| 定义要构建什么 | `/spec` | 先写 spec（规格说明）再写代码 |
| 规划如何构建 | `/plan` | 小而原子的任务 |
| 增量构建 | `/build` | 一次只交付一个切片 |
| 证明它能工作 | `/test` | 测试即证明 |
| 合并前评审 | `/review` | 提升代码健康度 |
| 审计 Web 性能 | `/webperf` | 先测量再优化 |
| 简化代码 | `/code-simplify` | 清晰胜过炫技 |
| 发布到生产 | `/ship` | 更快更安全 |

有 spec 之后想减少手动步骤？**`/build auto`** 会生成计划，并在一次授权通过后实现所有任务——你只需批准一次计划，然后它会自主运行。它移除的是人在任务*之间*的介入，而不是验证：每个任务仍然是测试驱动并单独提交，遇到失败或高风险步骤时会暂停。

技能还会根据你正在做的事情自动激活——设计 API 时触发 `api-and-interface-design`，构建 UI 时触发 `frontend-ui-engineering`，以此类推。

---

## 快速开始

**最快路径——任意 agent，一条命令。** 开源 [skills CLI](https://github.com/vercel-labs/skills) 可安装到 70+ 个 agent（Claude Code、Cursor、Codex、Copilot、Cline 等）：

```bash
npx skills add ofull37/cn-agent-skills            # install all 24 skills
npx skills add ofull37/cn-agent-skills --list     # browse before installing
```

或者单独获取技能：

```bash
npx skills add ofull37/cn-agent-skills --skill code-review-and-quality   # five-axis review before merge
npx skills add ofull37/cn-agent-skills --skill interview-me              # requirements interrogation, one question at a time
npx skills add ofull37/cn-agent-skills --skill test-driven-development   # red-green-refactor, enforced
```

> **只安装一个技能？** 按技能执行的 `npx` 安装只会复制
> `skills/<name>/`，而不会复制仓库级的 `references/` 目录。该技能仍然
> 可用，但无法访问补充共享清单的路径。请改用整个仓库的集成方式、
> 克隆仓库，或将所需清单复制到已安装技能内部的
> `references/` 目录。这个可移植性缺口正在
> [#361](https://github.com/addyosmani/agent-skills/issues/361) 中跟踪。

更想要原生集成？从下面选择你的工具。

<details>
<summary><b>Claude Code（推荐）</b></summary>

**市场安装：**

```
/plugin marketplace add ofull37/cn-agent-skills
/plugin install cn-agent-skills@cn-addy-agent-skills
```

> **遇到 SSH 错误？** 市场会通过 SSH 克隆仓库。如果你没有在 GitHub 上配置 SSH 密钥，可以[添加 SSH 密钥](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)，或在添加市场这一步使用完整的 HTTPS URL 来强制走 HTTPS 克隆：
> ```bash
> /plugin marketplace add https://github.com/ofull37/cn-agent-skills.git
> /plugin install cn-agent-skills@cn-addy-agent-skills
> ```
>
> 如果在 Windows 或 macOS 上 `/plugin install` 仍然报 `git@github.com: Permission denied (publickey)`，推荐的解决办法是配置一次 Git，让子进程克隆时把 GitHub 的 SSH URL 改写为 HTTPS：
> ```bash
> git config --global url."https://github.com/".insteadOf git@github.com:
> ```

**本地 / 开发：**

```bash
git clone https://github.com/ofull37/cn-agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

</details>

<details>
<summary><b>Cursor</b></summary>

将工作流技能放在 `.cursor/skills/` 下（从 `agent-skills/skills/` 同步），把简短策略放在 `.cursor/rules/*.mdc` 中——不要把完整技能粘贴进规则文件。参见 [docs/cursor-setup.md](docs/cursor-setup.md)。

</details>

<details>
<summary><b>Antigravity CLI</b></summary>

作为原生插件安装，提供技能、子代理和 slash 命令。参见 [docs/antigravity-setup.md](docs/antigravity-setup.md)。

**从仓库安装：**

```bash
agy plugin install https://github.com/ofull37/cn-agent-skills.git
```

**从本地克隆安装：**

```bash
git clone https://github.com/ofull37/cn-agent-skills.git
agy plugin install ./agent-skills
```

</details>

<details>
<summary><b>Gemini CLI</b></summary>

作为原生技能安装以实现自动发现，或添加到 `GEMINI.md` 以获得持久上下文。参见 [docs/gemini-cli-setup.md](docs/gemini-cli-setup.md)。

**从仓库安装：**

```bash
gemini skills install https://github.com/ofull37/cn-agent-skills.git --path skills
```

**从本地克隆安装：**

```bash
gemini skills install ./agent-skills/skills/
```

</details>

<details>
<summary><b>Windsurf</b></summary>

将技能内容添加到你的 Windsurf 规则配置中。参见 [docs/windsurf-setup.md](docs/windsurf-setup.md)。

</details>

<details>
<summary><b>OpenCode</b></summary>

通过 AGENTS.md 和 `skill` 工具使用 agent 驱动的技能执行。

参见 [docs/opencode-setup.md](docs/opencode-setup.md)。

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

使用 `agents/` 中的 agent 定义作为 Copilot 角色，并将技能内容放入 `.github/copilot-instructions.md`。参见 [docs/copilot-setup.md](docs/copilot-setup.md)。

</details>

<details>
  <summary><b>Kiro IDE & CLI </b></summary>
  Kiro 的技能位于 ".kiro/skills/" 下，可以存储在项目（Project）或全局（Global）层级。Kiro 也支持 Agents.md。参见 Kiro 文档：https://kiro.dev/docs/skills/
</details>

<details>
<summary><b>Codex</b></summary>

作为原生 Codex 插件安装（Codex CLI v0.122+）：

```bash
codex plugin marketplace add ofull37/cn-agent-skills
codex plugin add cn-agent-skills@cn-agent-skills
```

第一个命令注册市场；第二个命令安装插件。Codex 通过 `.codex-plugin/plugin.json` 直接读取根目录的 `skills/`。安装后，可以在聊天中使用 `@` 调用技能（例如 `@spec-driven-development`）。本地安装和故障排查参见 [docs/codex-setup.md](docs/codex-setup.md)。

</details>

<details>
<summary><b>Command Code</b></summary>

使用内置的 `cmd skills` 命令进行原生安装。Command Code 会克隆仓库、发现每个 `SKILL.md`，并安装到 `.commandcode/skills/`：

```bash
cmd skills add ofull37/cn-agent-skills            # pick skills to install (project)
cmd skills add ofull37/cn-agent-skills --global   # install for all projects (~/.commandcode/skills/)
cmd skills add ofull37/cn-agent-skills -s spec-driven-development  # install a specific skill
```

安装后的技能会出现在 TUI 的 slash 菜单中，例如 `/spec-driven-development`。参见 [docs/commandcode-setup.md](docs/commandcode-setup.md)。

</details>

<details>
<summary><b>其他智能体</b></summary>

技能就是纯 Markdown——它们适用于任何接受系统提示词或指令文件的智能体。参见 [docs/getting-started.md](docs/getting-started.md)。

</details>



---

## 采用

已经安装？如何推行这套技能包取决于你的代码库。**[采用指南](docs/adoption-guide.md)** 覆盖两条路径：绿地项目从第一天就采用完整生命周期，或对既有代码库采用增量、验证优先的推广方式。

---

## 全部 24 个技能

上面的命令只是入口。这个技能包共包含 24 个技能——23 个生命周期技能外加 `using-agent-skills` 元技能。每个技能都是一个结构化的工作流，带有步骤、验证门禁和反合理化借口表格。你也可以直接引用任意技能。

### 元技能——判断哪个技能适用

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [using-agent-skills](skills/using-agent-skills/SKILL.md) | 将收到的任务映射到合适的技能工作流，并定义共享的运行规则 | 开始一个新会话，或需要判断哪个技能适用时 |

### 定义——明确要构建什么

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [interview-me](skills/interview-me/SKILL.md) | 一次只问一个问题，逐步挖掘用户真正想要的东西，而不是他们自认为应该想要的东西，直到置信度达到约 95% | 需求不明确，或用户明确要求「interview me」/「grill me」时 |
| [idea-refine](skills/idea-refine/SKILL.md) | 通过结构化的发散/收敛思维，把模糊的想法变成具体的提案 | 你有一个粗糙的概念需要探索时 |
| [spec-driven-development](skills/spec-driven-development/SKILL.md) | 在写任何代码之前，先编写覆盖目标、命令、结构、代码风格、测试和边界的 PRD | 启动新项目、新功能或重大变更时 |

### 规划——拆解任务

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [planning-and-task-breakdown](skills/planning-and-task-breakdown/SKILL.md) | 将 spec 分解为带有验收标准和依赖顺序的小型、可验证任务 | 你已有 spec，需要可执行的任务单元时 |

### 构建——编写代码

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [incremental-implementation](skills/incremental-implementation/SKILL.md) | 薄垂直切片——实现、测试、验证、提交。功能开关、安全默认值、便于回滚的变更 | 任何涉及多个文件的变更时 |
| [test-driven-development](skills/test-driven-development/SKILL.md) | 红绿重构、测试金字塔（80/15/5）、测试粒度、DAMP 优于 DRY、碧昂丝法则、浏览器测试 | 实现逻辑、修复 bug 或变更行为时 |
| [context-engineering](skills/context-engineering/SKILL.md) | 在正确的时间为 agent 提供正确的信息——规则文件、上下文打包、MCP 集成 | 开始会话、切换任务，或输出质量下降时 |
| [source-driven-development](skills/source-driven-development/SKILL.md) | 让每个框架决策都基于官方文档——验证、引用来源、标注未经证实的部分 | 希望任何框架或库的代码都有权威出处时 |
| [doubt-driven-development](skills/doubt-driven-development/SKILL.md) | 对进行中的每个非平凡决策进行对抗式、全新上下文评审——CLAIM → EXTRACT → DOUBT → RECONCILE → STOP，并支持用户授权的跨模型升级 | 风险较高（生产、安全、不可逆操作）、在陌生代码中工作，或「现在验证比以后调试更划算」时 |
| [frontend-ui-engineering](skills/frontend-ui-engineering/SKILL.md) | 组件架构、设计系统、状态管理、响应式设计、WCAG 2.1 AA 无障碍标准 | 构建或修改面向用户的界面时 |
| [api-and-interface-design](skills/api-and-interface-design/SKILL.md) | 契约优先设计、海勒姆定律、单一版本规则、错误语义、边界校验 | 设计 API、模块边界或公共接口时 |

### 验证——证明它能工作

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [browser-testing-with-devtools](skills/browser-testing-with-devtools/SKILL.md) | 通过 Chrome DevTools MCP 获取实时运行时数据——DOM 检查、控制台日志、网络跟踪、性能分析 | 构建或调试任何在浏览器中运行的内容时 |
| [debugging-and-error-recovery](skills/debugging-and-error-recovery/SKILL.md) | 五步排查：复现、定位、简化、修复、防护。停线法则、安全回退 | 测试失败、构建中断或行为不符合预期时 |

### 评审——合并前的质量门禁

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [code-review-and-quality](skills/code-review-and-quality/SKILL.md) | 五维评审、变更规模控制（约 100 行）、严重程度标签（Nit/Optional/FYI）、评审速度规范、拆分策略 | 合并任何变更之前 |
| [code-simplification](skills/code-simplification/SKILL.md) | 切斯特顿栅栏、500 规则，在保持行为完全不变的前提下降低复杂度 | 代码能工作，但可读性或可维护性比应有的水平差时 |
| [security-and-hardening](skills/security-and-hardening/SKILL.md) | OWASP Top 10 防护、认证模式、密钥管理、依赖审计、三层边界体系 | 处理用户输入、认证、数据存储或外部集成时 |
| [performance-optimization](skills/performance-optimization/SKILL.md) | 先测量再优化——Core Web Vitals 目标、性能分析工作流、包体分析、反模式检测 | 存在性能要求，或怀疑出现性能回归时 |

### 发布——自信地部署

| Skill | 功能 | 适用时机 |
|-------|-------------|----------|
| [git-workflow-and-versioning](skills/git-workflow-and-versioning/SKILL.md) | 主干开发、原子提交、变更规模控制（约 100 行）、把提交当作存档点的模式 | 进行任何代码变更时（始终） |
| [ci-cd-and-automation](skills/ci-cd-and-automation/SKILL.md) | 左移、更快更安全、功能开关、质量门禁流水线、失败反馈回路 | 搭建或修改构建与部署流水线时 |
| [deprecation-and-migration](skills/deprecation-and-migration/SKILL.md) | 代码即负债的理念、强制与建议性弃用、迁移模式、僵尸代码清理 | 移除旧系统、迁移用户或下线功能时 |
| [documentation-and-adrs](skills/documentation-and-adrs/SKILL.md) | 架构决策记录（ADR）、API 文档、行内文档标准——记录*为什么* | 做架构决策、变更 API 或发布功能时 |
| [observability-and-instrumentation](skills/observability-and-instrumentation/SKILL.md) | 结构化日志、RED 指标、OpenTelemetry 追踪、基于症状的告警——边构建边埋点 | 添加遥测，或发布任何会在生产中运行的内容时 |
| [shipping-and-launch](skills/shipping-and-launch/SKILL.md) | 发布前检查清单、功能开关生命周期、分阶段发布、回滚流程、监控搭建 | 准备部署到生产环境时 |

---

## Agent 角色

面向定向评审的预配置专家角色：

| Agent | 角色 | 视角 |
|-------|------|-------------|
| [code-reviewer](agents/code-reviewer.md) | 资深 Staff 工程师 | 以「Staff 工程师会批准这个吗？」为标准的五维代码评审 |
| [test-engineer](agents/test-engineer.md) | QA 专家 | 测试策略、覆盖率分析，以及 Prove-It 模式 |
| [security-auditor](agents/security-auditor.md) | 安全工程师 | 漏洞检测、威胁建模、OWASP 评估 |
| [web-performance-auditor](agents/web-performance-auditor.md) | Web 性能工程师 | Core Web Vitals 审计，提供 Quick/Deep 两种模式以及指标诚实性原则；通过 `/webperf` 运行 |

决策矩阵、编排规则，以及角色如何与技能和 slash 命令组合使用，见 [docs/agents.md](docs/agents.md)。

---

## 参考清单

技能在需要时引用的速查资料：

| 参考 | 覆盖内容 |
|-----------|--------|
| [definition-of-done.md](references/definition-of-done.md) | 所有变更必须达到的全局标准，与每项任务的验收标准形成对照 |
| [testing-patterns.md](references/testing-patterns.md) | 测试结构、命名、mock、React/API/E2E 示例、反模式（JavaScript/TypeScript） |
| [security-checklist.md](references/security-checklist.md) | 提交前检查、认证、输入校验、请求头、CORS、OWASP Top 10 |
| [performance-checklist.md](references/performance-checklist.md) | Core Web Vitals 目标、前端/后端清单、测量命令 |
| [accessibility-checklist.md](references/accessibility-checklist.md) | 键盘导航、屏幕阅读器、视觉设计、ARIA、测试工具 |
| [observability-checklist.md](references/observability-checklist.md) | 值班问题、结构化日志、RED/USE 指标、追踪、基于症状的告警、发布前门禁 |
| [orchestration-patterns.md](references/orchestration-patterns.md) | 官方认可的多角色编排模式、反模式，以及「角色不调用角色」的规则 |

---

## 技能的工作原理

每个技能都遵循一致的结构：

```
┌─────────────────────────────────────────────────┐
│  SKILL.md                                       │
│                                                 │
│  ┌─ Frontmatter ─────────────────────────────┐  │
│  │ name: lowercase-hyphen-name               │  │
│  │ description: Guides agents through [task].│  │
│  │              Use when…                    │  │
│  └───────────────────────────────────────────┘  │                                                                                                
│  Overview         → What this skill does        │
│  When to Use      → Triggering conditions       │
│  Process          → Step-by-step workflow       │
│  Rationalizations → Excuses + rebuttals         │
│  Red Flags        → Signs something's wrong     │
│  Verification     → Evidence requirements       │
└─────────────────────────────────────────────────┘
```

**关键设计选择：**

- **流程而非文档。** 技能是 agent 遵循的工作流，而不是供其阅读的参考文档。每个技能都有步骤、检查点和退出标准。
- **反合理化借口。** 每个技能都包含一个表格，列出 agent 常用来跳过步骤的借口（例如「以后再加测试」），并附有对应的反驳论据。
- **验证不可妥协。** 每个技能都以证据要求结尾——测试通过、构建输出、运行时数据。「看起来没问题」永远不够。
- **渐进式披露。** `SKILL.md` 是入口；辅助参考资料只在需要时加载，以保持 token 用量最小化。

---

## 项目结构

```
agent-skills/
├── skills/                            # 24 skills (23 lifecycle + 1 meta)
│   ├── interview-me/                  #   Define
│   ├── idea-refine/                   #   Define
│   ├── spec-driven-development/       #   Define
│   ├── planning-and-task-breakdown/   #   Plan
│   ├── incremental-implementation/    #   Build
│   ├── context-engineering/           #   Build
│   ├── source-driven-development/     #   Build
│   ├── doubt-driven-development/      #   Build
│   ├── frontend-ui-engineering/       #   Build
│   ├── test-driven-development/       #   Build
│   ├── api-and-interface-design/      #   Build
│   ├── browser-testing-with-devtools/ #   Verify
│   ├── debugging-and-error-recovery/  #   Verify
│   ├── code-review-and-quality/       #   Review
│   ├── code-simplification/           #   Review
│   ├── security-and-hardening/        #   Review
│   ├── performance-optimization/      #   Review
│   ├── git-workflow-and-versioning/   #   Ship
│   ├── ci-cd-and-automation/          #   Ship
│   ├── deprecation-and-migration/     #   Ship
│   ├── documentation-and-adrs/        #   Ship
│   ├── observability-and-instrumentation/ # Ship
│   ├── shipping-and-launch/           #   Ship
│   └── using-agent-skills/            #   Meta: how to use this pack
├── agents/                            # 4 specialist personas
├── references/                        # 7 supplementary checklists
├── hooks/                             # Session lifecycle hooks
├── .claude/commands/                  # 8 slash commands (Claude Code)
├── .gemini/commands/                  # 8 slash commands (Gemini CLI)
├── commands/                          # 8 slash commands (Antigravity CLI)
├── plugin.json                        # Antigravity plugin manifest
└── docs/                              # Setup guides per tool
```

---

## 为什么选择 Agent Skills？

AI 编码智能体默认会走最短路径——这往往意味着跳过 spec、测试、安全评审，以及那些让软件可靠的做法。Agent Skills 为智能体提供了结构化的工作流，强制其遵循高级工程师在编写生产代码时所用的同一种纪律。

每个技能都内嵌了来之不易的工程判断：*何时*写 spec、*测试什么*、*如何*评审、*何时*发布。这些不是泛泛的提示词——它们是那种有立场、以流程驱动的，将生产级质量与原型级质量区分开来的工作流。

技能吸收了 Google 工程文化中的最佳实践——包括 [Software Engineering at Google](https://abseil.io/resources/swe-book) 和 Google [工程实践指南](https://google.github.io/eng-practices/) 中的理念。你会看到 API 设计中的海勒姆定律、测试中的碧昂丝法则和测试金字塔、代码评审中的变更规模控制和评审速度规范、简化中的切斯特顿栅栏、git 工作流中的主干开发、CI/CD 中的左移和功能开关，以及一个把代码视为负债的专门弃用技能。这些不是抽象的原则——它们被直接嵌入到 agent 遵循的分步工作流中。

---

## 与同类项目对比

想知道它与 [Superpowers](https://github.com/obra/superpowers) 或 [Matt Pocock's skills](https://github.com/mattpocock/skills) 相比如何？请看 **[docs/comparison.md](docs/comparison.md)**，其中诚实地并排比较了三者的不同定位以及各自适用的时机——还附有一个受控[正面交锋实验](https://www.linkedin.com/pulse/superpowers-vs-agent-skills-faster-shipping-safer-reasoning-om-mishra-dzakf/)的链接。

---

## 参与贡献

技能应当**具体**（可操作的步骤，而非泛泛而谈的建议）、**可验证**（带有证据要求的明确退出标准）、**久经考验**（基于真实工作流）、**最小化**（只包含引导 agent 所需的内容）。

格式规范见 [docs/skill-anatomy.md](docs/skill-anatomy.md)，贡献指南见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 团队

agent-skills 由以下人员构建和维护：

| | Name | GitHub | Role |
|---|------|--------|------|
| <img src="https://github.com/addyosmani.png?size=120" width="60" height="60" alt="Addy Osmani"> | **Addy Osmani** | [@addyosmani](https://github.com/addyosmani) | 创建者 |
| <img src="https://github.com/federicobartoli.png?size=120" width="60" height="60" alt="Federico Bartoli"> | **Federico Bartoli** | [@federicobartoli](https://github.com/federicobartoli) | 协作者 |
| <img src="https://github.com/nucliweb.png?size=120" width="60" height="60" alt="Joan León"> | **Joan León** | [@nucliweb](https://github.com/nucliweb) | 协作者 |

---

## 许可证

MIT 许可——欢迎在您的项目、团队和工具中使用这些技能。
