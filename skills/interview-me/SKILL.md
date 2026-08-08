---
name: interview-me
description: 提取用户真正想要的东西，而不是他们认为自己应该想要的东西。通过一次一个问题的方式逐步访谈，直到对潜在意图达到约 95% 的置信度。当需求描述不明确时（"给我建一个 X"但缺少"给谁用"或"为什么现在"），当用户明确要求时（"interview me"、"grill me"、"are we sure?"、"stress-test my thinking"），或当你发现在任何计划、规格或代码存在之前就默默填补了含糊的需求时使用。
---

# 访谈我

## 概述

人们要求的和他们真正想要的是两回事。他们要求"一个仪表盘"，是因为人们都这么要求，而不是因为仪表盘能解决他们的问题。他们说"让它更快"，却没有任何数字目标。

发现这个差距成本最低的时机，是在任何计划、规格或代码存在之前。一旦你开始构建，切换成本就是真实的，用户会把错误的东西合理化成一个"够好"的东西。错配就此锁定。

本技能在付出任何代价之前弥合这个差距。其他 Define 阶段的技能都假定你大致知道自己想要什么：`idea-refine` 从一个想法生成各种变体，`spec-driven-development` 把需求写下来，`doubt-driven-development` 在你起草好计划之后对其进行压力测试。interview-me 是所有这一切之前的那一步：一次问一个问题，附上你最好的猜测，直到你能在用户说出之前预测到他们将要说什么。

## 何时使用

在以下情况应用本技能：

- 需求至少缺少以下一项：**用户**是谁、他们**为什么**要它、**成功**长什么样、起约束作用的**限制**是什么
- 请求是惯例式的而非具体的（"给我建一个 X"、"让它更快"），而你无法在不猜测的情况下拆解这种惯例
- 你想从尚未浮出水面的假设开始
- 当两个合理的目标彼此冲突时，用户没有说明他们在优化哪个（简洁 vs. 灵活，成本 vs. 速度）
- 用户明确要求："interview me"、"grill me"、"before we start, are we sure?"、"stress-test my thinking"

**何时不使用：**

- 需求明确且自包含（"重命名这个变量"、"修复这个错别字"）
- 用户明确要求速度优先于验证
- 纯粹的信息请求（"X 是怎么工作的？"、"这段代码是做什么的？"）
- 机械性操作（重命名、格式化、移动文件）
- 你已经至少有 95% 的置信度；在假定自己没有之前，重读下面的停止条件

## 加载约束

本技能需要一个实时、响应的用户。**不要在非交互式环境中调用**，例如 CI 流水线、定时运行、`/loop` 或自主循环。如果你身处其中且需求不明确，就把它标记为阻塞项告知用户，而不是去猜。

## 流程

### 步骤 1：提出假设，并附上置信度数值

在问任何问题之前，用**一句话**写下你当前对用户想要什么的最佳解读，外加一个诚实的置信度数值（0–100%）：

```
HYPOTHESIS: You want a way to answer "how are we doing?" in standup, and "dashboard" was the convention that came to mind.
CONFIDENCE: ~30% — missing: who it's for, what "metrics" means in context, and what success looks like
```

这个数值逼你诚实。如果你写下一个很高的数值，却无法真正预测用户对你接下来要问的三个问题的反应，那么这个数值就是错的。从你能站得住脚的置信度开始。

当置信度低于约 70% 时，在同一行末尾附上简短理由——还有什么未解决或缺失的。这告诉用户访谈到底需要揭示什么，并防止这个数值变成一个含糊的信号。

### 步骤 2：一次一个问题，每个都附上猜测

格式：

```
Q: <one focused question>
GUESS: <your hypothesis for the answer, with the reasoning that produced it>
```

等用户反应后再问下一个问题。

**为什么一次一个，而不是批量：**

- 如果你把假设埋在一长串列表里，用户就无法对其做出反应
- 批量会鼓励略读和浅层回答
- 第三个问题往往取决于第一个问题的答案；一次性全问就会锁定错误的框架
- 用户认真思考的精力是有限的；把它花在一次一个问题上

**为什么要附上猜测：**

- 用户对一个错误猜测的反应，比从头生成一个答案更快
- 它让你承诺一个可以被明显证伪的假设，从而保持你的诚实
- 它暴露出*你的*假设，而这正是访谈想要揭示的东西

这里的风险是：一个礼貌的用户为了让气氛融洽而同意你的猜测。缓解办法是让自己明显地愿意被反驳，并且偶尔朝着你预期用户会反驳的方向去猜。

### 步骤 3：倾听"想要的 vs. 应该想要的"

最危险的回答，是那些用户说出一个有思考力的回答*听起来该有的样子*、而不是他们真正想要什么的回答。留意：

- 模式匹配最佳实践套话（"我想要它可扩展"、"干净的架构"）却没有具体细节的回答
- 顺从惯例的回答（"大多数应用都这么做"、"标准做法"）
- 诸如"I should probably…"、"I think I'm supposed to…"、"good engineering practice says…"之类的措辞
- 把流行词当作目标——当"现代"、"可扩展"、"健壮"成为答案，而不是一个具体结果时

当你听到这些时，该问的问题是：

> *"如果你不必向任何人证明这件事，你实际上想要的是什么？"*

这一个问题往往比前面五个问题加起来都更有用。

### 步骤 4：用用户自己的话重述意图

当你的置信度很高时，把你现在认为用户想要的东西写回去。保持简洁（5–8 行），尽可能使用他们的语言，并把结构组织得让用户可以逐行确认或纠正：

```
Here's what I now think you want:

- Outcome:      <one line>
- User:         <one line — who benefits>
- Why now:      <one line — what changed>
- Success:      <one line — how we know it worked>
- Constraint:   <one line — the binding limit>
- Out of scope: <one line — what we're explicitly not doing>

Yes / no / refine?
```

包含"Out of scope"（范围之外）是没得商量的。一半的错配，是双方对*不*构建什么存在心照不宣的分歧。

### 步骤 5：确认——明确的"是"，而不是"随你便"

闸门是一个明确的"是"。以下情况**不算**是"是"：

- "Whatever you think is best."（随你觉得最好）→ 用户在授权给你，这意味着他们也没有 95% 的置信度。给出两个具体选项，重新以选择的形式再问一次。
- "Sounds good."（听起来不错）→ 含糊。追问："有什么你想改的吗？"沉默不是确认。
- "Sure, let's go."（行，走吧）→ 往往是礼貌地脱身，而不是认可。同样的追问。
- 沉默之后是"okay let's start."（好，我们开始吧）→ 用户已经放弃了访谈，而不是达成了共识。停下来，问是否漏掉了什么。

如果他们纠正你，把纠正折进来再重述。循环直到获得一个明确的"是"。

### 95% 置信度停止点

当你对这个问题的回答为"是"时，你就完成了：

> *我能预测用户对我接下来要问的三个问题的反应吗？*

如果能，你们就达成了共同理解。停止访谈，产出重述。如果不能，你还没完成；继续问下一个问题。

这是一个可检验的测试，而不是一种感觉。它也有一个下限：如果已经问了好几轮还是无法预测，那说明的是这个需求本身，而不是继续硬磨的理由。停下来告诉用户："我已经问了 X 个问题，还是无法预测你的反应。有一些基础性的东西缺失。想退一步吗？"

## 输出

本技能的产出是一份**确认过的意图陈述**：来自步骤 4 的重述，加上来自步骤 5 的明确"是"。这就是交付物。规格、计划和任务清单都是下游产物；它们消费本技能产出的意图。

如果用户希望意图能够持久保存（一个跨会话的项目、移交给另一位协作者），主动提议保存到 `docs/intent/[topic].md`。只有他们确认后才保存。

## 示例

一个简短的前后对比。

**没有 `interview-me`：**

```
User:  build me a dashboard for our metrics
Agent: <starts proposing chart libraries and layouts>
```

Agent 已经假设了：给谁用、什么指标、"for our team"是什么意思、成功长什么样。这些全都没有被说出来。每一个假设都是用户日后可以说"这不是我的意思"的地方。

**使用 `interview-me`：**

```
User: build me a dashboard for our metrics

Agent:
HYPOTHESIS: You want a way to answer "how are we doing?" in standup, and "dashboard" came to mind because that's the conventional answer.
CONFIDENCE: ~30% — missing: who it's for, what "metrics" are, and what success looks like

Q:     When you say "how are we doing?", who's asking — you alone, the engineering team in standup, or up the chain (e.g., your manager, an exec, a board)?
GUESS: engineering team in standup, because "we" usually scopes that way and standups are where this question gets asked. If it's for execs the metrics and the framing change a lot.

User: It's actually for me. I keep losing track of which experiments are running and what their early signal looks like.

Agent:
Updated read: not a team dashboard at all. It's a personal experiment tracker. Confidence: ~60% — still missing: what "early signal" means and what done looks like.

Q:     Is the gap that you don't know which experiments exist, or that you can't see their results in one place?
GUESS: the second one. You have a list of experiments somewhere, but their results live in five different tools, and reconciling them by hand is what you're tired of.

User: First one actually. I literally don't have a list. They're spread across different docs.

Agent: <continues>
```

问了两三个问题，agent 就发现真正的需求不是"一个仪表盘"，而是"一个列表"。不同的产物、不同的范围、不同的工作量。那个仪表盘本来会是错的。

## 与其他技能的交互

- **`idea-refine`**：下游。如果确认后的意图是"我想要 X，但我不知道如何划定范围"，就移交给 `idea-refine`，让它针对现在明确的意图生成各种变体。
- **`spec-driven-development`**：下游。如果确认后的意图是具体的（"我想要面向 Y 用户、带 Z 成功标准的 X"），就移交给 `spec-driven-development` 把它写下来。
- **`planning-and-task-breakdown`**：在本技能下游两步（在 spec 之后）。
- **`doubt-driven-development`**：时间线的另一端。interview-me 是决策前的意图提取；doubt-driven 是决策后的产物审查。两者都捕捉分歧，但发生在不同的时机。
- **`source-driven-development`**：正交。interview-me 澄清用户想要什么；SDD 验证框架事实。它们并不竞争。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| "这个需求已经够清楚了" | 如果你现在无法用一句话写出用户期望的结果，这个需求就不清楚。在决定之前先跑步骤 1。 |
| "问太多问题是浪费他们的时间" | 4–6 个有针对性问题浪费的时间很少。构建错误东西浪费的时间是巨大的，而且承担这个成本的是用户。 |
| "我边构建边弄清楚" | 代码存在之后的切换成本是现在的 10 倍。实现过程中的发现就是返工。 |
| "他们说了'随你便'，所以我就该自己决定" | "随你便"是授权，不是决策。给出两个具体选项，以选择的形式重新再问。 |
| "我应该给他们几个选项挑" | 选项在用户知道自己想要什么、并且是在权衡取舍时才有效。他们还不知道自己想要什么。列出选项是拓宽搜索；提问是收窄它。 |
| "如果我附上猜测，就是在引导他们" | 引导正是重点。对猜测做出反应，比从头生成要快。风险是谄媚，而不是引导；通过让自己明显愿意被反驳来缓解。 |
| "我们已经聊得够多了，我懂了" | 检验一下：你能预测他们对接下来三个问题的反应吗？如果不能，你还没懂。 |
| "用户说了'是'，我们完成了" | 如果这个"是"跟在一个含糊的重述或一个开放式的"sounds good"后面，那么这个"是"是空洞的。具体地重述并重新确认。 |

## 危险信号

- 一条消息里连续问三个或更多问题：这是批量，不是访谈
- 一个没有附上你的假设的问题：这是在调查，不是承诺
- 把"whatever you think is best"当作最终回答接受
- 在用户明确确认你的重述之前就产出 spec、计划或任务清单
- 把问题框成"什么是最佳实践？"而不是"你实际想要什么？"
- 用户给出一个彰显成熟的回答（"可扩展"、"干净"、"现代"），而你未加探究就接受了，不确认那是否是他们真正想要的
- 三轮以上你的置信度没有明显上升：你在问错问题，退一步重新框定
- 置信度数值低于约 70% 却没有任何理由：用户不知道缺了什么，就无法帮你弥合差距
- 在用户确认之前就保存意图文档（文档本身就暗示了一个用户并没有给出的"是"）
- 在重述中跳过"Out of scope"那一行（关于非目标的心照不宣的分歧，占错配的一半）

## 验证

应用 interview-me 之后：

- [ ] 第一轮就陈述了一个明确的假设，并附上置信度数值
- [ ] 每个低于约 70% 的置信度数值都附带一行理由（还有什么未解决或缺失的）
- [ ] 问题一次只问一个，每个都附上 agent 的猜测
- [ ] 当用户给出彰显成熟或顺应惯例的回答时，至少进行了一次"如果你不必向任何人证明这件事，你实际想要的是什么？"的探究
- [ ] 一个具体重述（Outcome / User / Why now / Success / Constraint / Out of scope）被写回给用户
- [ ] 用户用一个明确的"是"确认了重述（不是"whatever you think"，不是"sounds good"，不是沉默）
- [ ] 在停止点时，agent 能预测它接下来要问的三个问题的反应
- [ ] 任何移交给下游技能（`idea-refine`、`spec-driven-development`）的做法，都是基于确认后的意图来框定的，而不是基于最初那个不明确的需求
