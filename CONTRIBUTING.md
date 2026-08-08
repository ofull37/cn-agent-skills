# 参与 Agent Skills 贡献

感谢你有兴趣参与贡献！本项目是一个面向 AI 编码智能体的生产级工程技能合集。

第一次来？[docs/developer-onboarding.md](docs/developer-onboarding.md) 是一份导览，介绍仓库如何组织（五个层次、验证循环和贡献路径），并告诉你在什么时候阅读本文档、[skill-anatomy.md](docs/skill-anatomy.md) 和 [evals/README.md](evals/README.md)。本文件是权威规则手册；上手指南是地图。

## 添加新技能

### 提出新技能之前

这个技能包已经覆盖了大部分开发生命周期，许多提案会与现有技能或另一个开放 PR 重叠。在提交提案之前，请完成以下检查，避免评审者去分拣重复项：

1. **搜索目录。**浏览 [README 中的技能列表](README.md)，并翻阅 `skills/`，看看是否已有技能完整或部分覆盖你的想法。
2. **检查开放的 PR。**运行 `gh pr list --state open`（或浏览 PRs 标签页），查找同一主题的提案。已经存在一些近乎重复的技能；不要再增加它们。
3. **阅读结构规范。**确认你的想法符合 [docs/skill-anatomy.md](docs/skill-anatomy.md) 中的格式——带验证的可执行工作流，而非泛泛而谈的建议。
4. **在 PR 描述中说明该空白的必要性。**明确指出为什么现有技能或开放 PR 没有覆盖这个需求。如果有重叠，建议扩展现有技能，而不是添加新技能。

如果你的想法是对现有技能的完善，优先对该技能做一次聚焦的修改，而不是新建目录。

### 创建技能

1. 在 `skills/` 下创建一个使用 kebab-case 命名的目录
2. 按照 [docs/skill-anatomy.md](docs/skill-anatomy.md) 中的格式添加 `SKILL.md`
3. 包含带 `name` 和 `description` 字段的 YAML frontmatter
4. 确保 `description` 以技能的功能开头（第三人称），然后包含一个或多个 `Use when` 触发条件

### 技能质量门槛

技能应当：

- **具体（Specific）**——可操作的步骤，而非泛泛而谈的建议
- **可验证（Verifiable）**——带有证据要求的明确退出标准
- **久经考验（Battle-tested）**——基于真实工程工作流，而非理论理想
- **最小化（Minimal）**——只包含正确引导 agent 所需的内容

### 结构

每个新技能必须具备：

- 技能目录下的 `SKILL.md`
- 包含有效的 `name` 和 `description` 的 YAML frontmatter
- `evals/cases/<skill-name>.json` 位置的评测用例文件——至少 3 个正向触发、2 个负向触发（尽可能带 `owner`），以及 1 个行为评测。执行评测必须以 `evals/fixtures/` 下的真实文件为支撑；对话型技能可以使用经评审把关的 `kind: "dialogue"` 评测代替（见 [evals/README.md](evals/README.md)）。CI 会强制执行这些要求。

新技能一般应遵循标准结构：

- **概述（Overview）**——该技能做什么以及为什么重要
- **何时使用（When to Use）**——触发条件
- **流程（Process）**——分步工作流
- **常见合理化借口（Common Rationalizations）**——agent 用来跳过步骤的借口及反驳
- **危险信号（Red Flags）**——技能被错误应用的警告信号
- **验证（Verification）**——如何确认技能被正确应用

上面的 frontmatter 字段是必需的。章节结构是推荐模式：只要保留相同意图并保持技能易于遵循，使用 `How It Works`、`Workflow` 或 `Core Process` 等等效标题也是可以的。

### 不该做什么

- 不要在技能之间重复内容——改为引用其他技能
- 不要添加泛泛而谈的建议而非可执行流程的技能
- 除非内容超过 100 行，否则不要创建辅助文件
- 不要仅仅为了与其他技能保持一致就创建空的 `scripts/` 目录——只有在技能包含可运行辅助脚本时才添加 `scripts/`
- 不要将参考资料放在技能目录内——使用 `references/`

## 修改现有技能

- 保持修改聚焦且最小化
- 保留现有结构和语气
- 测试编辑后 YAML frontmatter 仍然有效

## 仓库级文件

仓库根目录的 `AGENTS.md` 和 `CLAUDE.md` 用于配置在 [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) 仓库上工作的 agent。编写设置指南或文档时，不要指示用户将这些文件复制到他们自己的项目或全局 agent 配置中；可复用的资产是 `skills/` 下的技能。

## 翻译

我们不接受文档（README、`docs/`）或技能及其内容的翻译。随着技能和文档的演进，翻译副本会逐渐失同步，而我们无法长期维护它们——除非依赖 agent 翻译加社区修正，这会增加维护成本而价值有限。请保持所有技能、文档和贡献为英文。

## 测试钩子

会话启动钩子（`hooks/session-start.sh`）会将 `using-agent-skills` 元技能注入每个新的 Claude Code 会话。`hooks/session-start-test.sh` 处的回归测试会验证钩子的 JSON payload——无论 `jq` 是否可用。

在打开任何涉及以下内容的 PR 之前运行它：

- `hooks/session-start.sh`
- `skills/using-agent-skills/SKILL.md`（钩子内嵌的元技能内容）

```bash
bash hooks/session-start-test.sh
```

预期输出：`session-start JSON payload OK`。脚本在任何断言失败时都会以非零状态退出。

### 复现无 jq 回退

当 `PATH` 中没有 `jq` 时，钩子会优雅地降级为 `INFO` 优先级的 payload。要在本地演练该分支，可在测试调用时从 `PATH` 中移除 `jq` 的目录：

```bash
JQ_DIR=$(dirname "$(command -v jq)")
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "^${JQ_DIR}$" | tr '\n' ':' | sed 's/:$//') \
  bash hooks/session-start-test.sh
```

当 `jq` 位于自己的独立目录中时（例如 Homebrew 安装的 `/opt/homebrew/bin`、手动安装的 `/usr/local/bin`），这种方式可以干净地运行。如果你的 `jq` 与测试依赖的其他工具（如 `/usr/bin` 中的 `mktemp`）共用系统 bin 目录，更简单的做法是通过单独的包管理器安装 `jq`，让它拥有自己的 bin 目录，然后重新运行。

在移除后的 `PATH` 下，钩子的 `command -v jq` 检查会失败，`INFO` 优先级回退会运行，测试会断言 `jq is required` 提示消息而非正常 payload。

## 报告问题

如果你发现以下情况，请打开一个 issue：

- 技能给出了错误或过时的指导
- 常见工程工作流缺少覆盖
- 技能之间存在不一致

如果某个技能的指导有误、过时，或在你的项目中不适用（例如，在 Maven 或 Gradle 仓库中假定使用 `npm test`），请使用 [Skill gap](https://github.com/addyosmani/agent-skills/issues/new?template=skill-gap.yml) issue 表单。它会询问受影响的技能、相关摘录、你的项目背景，以及你实际的做法——这些足以让维护者进行分拣，而无需自由格式的长篇描述。

## 许可证

通过参与贡献，即表示你同意你的贡献将在 MIT 许可证下授权。
