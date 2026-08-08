# Skill Evals

这个仓库如何衡量其技能是否真的有效：它们是否在**应该触发时触发**、彼此之间是否**保持区分**，以及是否按每个技能承诺的方式**改变 agent 的行为**。

## 参考实践（以及我们采纳了什么）

目前没有统一的社区标准来评估 `SKILL.md` 技能，但有两种做法走在前列：

- **Anthropic 的 skill-creator v2** 为每个技能定义了一个 `evals.json`（prompt + `expectations[]`，根据对话记录评分），并测试 description 对样本 prompt 的触发准确性。我们为行为层采用了它的 [`evals.json` 结构](https://github.com/anthropics/skills/tree/main/skills/skill-creator)，并额外增加了一个可选的 `kind` 字段来选择被评分的产物。
- **Superpowers**（obra）用 bash + `claude -p` + prompt 素材和评分脚本来测试技能。我们的行为层运行器遵循相同的无头 `claude` 模式，评分规则取自 `expectations[]`。

两者都没有提供的是对一个**多技能目录**进行的**确定性、CI 安全**的检查——每个技能的 description 是否包含用户实际会说的词汇，以及两个技能的 description 是否相互冲突。这就是下面的第二层，也是本仓库的补充。

## 三个层级

| 层级 | 检查内容 | 运行方式 | 成本 |
|---|---|---|---|
| 1. 结构 | frontmatter、命名、必需章节、命令一致性 | CI（`validate-skills.js`、`validate-commands.js`） | 免费 |
| 2. 触发与路由 | 正面 prompt 将其技能排进 top-k；负面 prompt 不能排进；没有两个 description 近似冲突 | CI（`run-evals.js`） | 免费 |
| 3. 行为 | 遵循该技能的 agent 满足其 `expectations[]` | 按需（`run-evals.js --behavioral`） | 消耗 tokens |

第二层是路由的**词汇近似**（对 description 做词干化的 TF-IDF）。它无法判断语义——那是第三层的工作——但它能抓住主导真实触发 bug 的两种失败模式：description 缺少用户所说的词汇（漏报），以及 description 过于宽泛、压过了正确技能（误报）。第二层失败通常意味着要**修改 description**，而不是修改 eval。

## 运行

```bash
# Tier 2 — deterministic, runs in CI
node scripts/run-evals.js
node scripts/run-evals.js --min-rank1 80  # enforce the current routing floor

# Tier 3 — behavioral, runs each eval through headless claude, then grades it
node scripts/run-evals.js --behavioral test-driven-development            # spends tokens
node scripts/run-evals.js --behavioral test-driven-development --dry-run  # prints the plan only
```

第三层支持两种行为产物类型。`execution` 是默认类型：每个 eval 在一个一次性 git 仓库中运行，来自 `files[]` 的真实项目输入会从 `evals/fixtures/` 中落地并作为基线提交，评分器对完整的 `--output-format stream-json --verbose` 执行轨迹（包括工具调用）进行评分。`dialogue` 保留给那些交付物本身就是对话的技能；它不需要 fixture，评分器对 assistant 的对话轮次进行评分，而不要求文件改动或命令。声称使用 `dialogue` 是需要人工评审的豁免，而不是 execution 类技能的一般逃生通道。

执行器以显式的权限模式运行（`--permission-mode acceptEdits` 加上一份预批准的工具清单），这样 execution 类 eval 能够真正编辑文件、运行命令、检查 diff 并提交，而不是被拒绝后只能口述。轨迹在评分器 prompt 中被视为不可信数据加以围栏，并通过 stdin 传给评分器（轨迹可能达到 MB 级；argv 会触及操作系统参数大小限制），执行器和评分器调用都带有超时，评分器输出在写入 `evals/results/`（gitignore 忽略）之前会先按 JSON 校验，使用 skill-creator 的 `grading.json` 形状。纪律类技能还包含针对时间压力、沉没成本和权威压力的施压用例；这些用例验证当 prompt 主张跳过工作流时，工作流仍然成立。

## Eval 用例格式

每个技能一个文件：`evals/cases/<skill-name>.json`。

```json
{
  "skill_name": "test-driven-development",
  "trigger": {
    "positive": [
      { "prompt": "Write a failing test for this bug before fixing it", "top_k": 3 }
    ],
    "negative": [
      { "prompt": "Update the architecture diagram in the docs", "owner": "documentation-and-adrs" }
    ]
  },
  "evals": [
    {
      "id": 1,
      "kind": "execution",
      "prompt": "Fix the reported rounding bug in the invoice totals, test-first.",
      "expected_output": "A failing test demonstrating the bug, a minimal fix turning it green, full suite passing",
      "files": [
        "test-driven-development"
      ],
      "expectations": [
        "A failing test is written and shown failing before the fix",
        "The implementation is the minimum needed to pass",
        "The full suite is run after the fix to catch regressions"
      ]
    }
  ]
}
```

- `evals[]` 使用 skill-creator 的核心结构（`id`、`prompt`、`expected_output`、可选的 `files[]`、`expectations[]`），再加上本仓库的可选 `kind`。`kind` 必须是 `execution` 或 `dialogue`，出于兼容性默认为 `execution`。execution 类 eval 要求 `files[]` 非空；路径相对于 `evals/fixtures/`，可以命名一个文件或项目目录。dialogue 类 eval 可以省略 `files[]`，因为对话记录本身就是产物。Expectations 是评分器针对相关产物检查的可验证陈述——衡量行为，而不是措辞。
- `trigger` 是本仓库的扩展。`positive` prompt 是应该路由到这里的真实用户请求（`top_k` 默认为 3；对于某技能的标志性请求可收紧为 1）。`negative` prompt 属于**另一个**技能；本技能不得为它们排第一。在可行的地方，在 `owner` 中声明那个技能：运行器随后断言 owner **压过**本技能，把负面用例变成真正的两两路由测试，而不是当 prompt 什么也匹配不到时可以空洞通过的测试。

**编写好的触发 prompt：** 改写用户真实的说话方式；不要复制 description（那是在作弊测试）。如果一个真实可信的 prompt 无法排进名次，是因为 description 缺少其词汇，那这就是一个真实发现——去改进 description。

## 添加技能

每个技能都附带一个 eval 文件。当你添加 `skills/<name>/` 时，要同时添加 `evals/cases/<name>.json`，其中至少包含 3 个正面触发、2 个负面触发和 1 个行为 eval。execution 类 eval 必须以 `evals/fixtures/<name>/` 为支撑；只有当技能的交付物确实是对话本身时，才使用 `kind: "dialogue"`。缺失用例文件、用例数量不足、未知的 `kind`、无效的 fixture 路径以及缺失必需的 fixture 都是 CI 错误。

## 需要关注的指标

第二层运行会打印一个**触发 rank-1 比率**（正面 prompt 中把其技能排第一位的比例，而不仅仅是 top-k）。CI 以 `--min-rank1 80` 运行，在已提交的 86% 基线以下留有有用的余量，这样无关的 description 改动不会立即让 CI 变红。随着路由改进可提高该下限；绝不要为让回归通过而降低它。数字下降意味着 description 正在彼此漂移。冲突检查在成对 description 相似度 ≥75% 时报错，在 ≥50% 时告警。这些 eval 暴露出的已知 description 词汇缺口记录在 [#351](https://github.com/addyosmani/agent-skills/issues/351) 中。
