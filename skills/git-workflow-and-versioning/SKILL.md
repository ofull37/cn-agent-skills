---
name: git-workflow-and-versioning
description: 结构化 git 工作流实践。当进行任何代码变更时使用。当提交、分支、解决冲突，或需要跨多个并行流组织工作时使用。当发布 release、选择语义化版本号的提升、打标签或编写 changelog 时使用。
---

# Git 工作流与版本管理

## 概述

Git 是你的安全网。把提交当作存档点，把分支当作沙盒，把历史当作文档。当 AI agent 以高速生成代码时，有纪律的版本控制正是让变更保持可控、可评审、可回退的机制。

## 何时使用

始终使用。每一次代码变更都流经 git。

## 核心原则

### 主干开发（推荐）

让 `main` 始终可部署。在短命的特性分支上工作，1-3 天内合并回去。长期存活的分支是隐藏成本——它们会分叉、制造合并冲突、拖延集成。DORA 研究一再表明，主干开发与高效的工程团队相关。

```
main ──●──●──●──●──●──●──●──●──●──  (always deployable)
        ╲      ╱  ╲    ╱
         ●──●─╱    ●──╱    ← short-lived feature branches (1-3 days)
```

这是推荐的默认做法。使用 gitflow 或长期分支的团队可以把这些原则（原子提交、小变更、有描述性的消息）适配到他们的分支模型上——提交纪律比具体采用哪种分支策略更重要。

- **开发分支是成本。** 分支每多存活一天，就多积累一天的合并风险。
- **发布分支是可以接受的。** 当 main 继续前进、而你需要稳定一个 release 时。
- **功能开关胜过长分支。** 优先把未完成的工作藏在开关后面部署，而不是把它留在分支上数周。

### 1. 尽早提交，频繁提交

每一个成功的增量都有它自己的提交。不要积累大量未提交的变更。

```
Work pattern:
  Implement slice → Test → Verify → Commit → Next slice

Not this:
  Implement everything → Hope it works → Giant commit
```

提交就是存档点。如果下一个变更弄坏了什么，你可以立刻回退到最后一个已知良好状态。

### 2. 原子提交

每个提交只做一件符合逻辑的事：

```
# Good: Each commit is self-contained
git log --oneline
a1b2c3d Add task creation endpoint with validation
d4e5f6g Add task creation form component
h7i8j9k Connect form to API and add loading state
m1n2o3p Add task creation tests (unit + integration)

# Bad: Everything mixed together
git log --oneline
x1y2z3a Add task feature, fix sidebar, update deps, refactor utils
```

### 3. 有描述性的消息

提交消息解释*为什么*，而不只是*什么*：

```
# Good: Explains intent
feat: add email validation to registration endpoint

Prevents invalid email formats from reaching the database.
Uses Zod schema validation at the route handler level,
consistent with existing validation patterns in auth.ts.

# Bad: Describes what's obvious from the diff
update auth.ts
```

**格式：**
```
<type>: <short description>

<optional body explaining why, not what>
```

**类型：**
- `feat` — 新功能
- `fix` — bug 修复
- `refactor` — 既不修 bug 也不加功能的代码变更
- `test` — 添加或更新测试
- `docs` — 仅文档
- `chore` — 工具、依赖、配置

### 4. 保持关注点分离

不要把格式化变更与行为变更混在一起。不要把重构与功能混在一起。每种变更都应该是独立的提交——理想情况下是独立的 PR：

```
# Good: Separate concerns
git commit -m "refactor: extract validation logic to shared utility"
git commit -m "feat: add phone number validation to registration"

# Bad: Mixed concerns
git commit -m "refactor validation and add phone number field"
```

**把重构与功能工作分开。** 一个重构变更和一个功能变更是两个不同的变更——分开提交。这让每个变更都更容易评审、回退和在历史中理解。小的清理（重命名变量）可以在评审者酌情下包含在功能提交里。

### 5. 控制变更规模

每个提交/PR 目标约 100 行。超过约 1000 行的变更应该拆分。拆分大变更的方法参见 `code-review-and-quality` 中的拆分策略。

```
~100 lines  → Easy to review, easy to revert
~300 lines  → Acceptable for a single logical change
~1000 lines → Split into smaller changes
```

## 分支策略

### 特性分支

```
main (always deployable)
  │
  ├── feature/task-creation    ← One feature per branch
  ├── feature/user-settings    ← Parallel work
  └── fix/duplicate-tasks      ← Bug fixes
```

- 从 `main`（或团队默认分支）分出
- 保持分支短命（1-3 天内合并）——长期分支是隐藏成本
- 合并后删除分支
- 未完成的功能优先用功能开关，而不是长期分支

### 分支命名

```
feature/<short-description>   → feature/task-creation
fix/<short-description>       → fix/duplicate-tasks
chore/<short-description>     → chore/update-deps
refactor/<short-description>  → refactor/auth-module
```

## 使用 Worktree

对于并行的 AI agent 工作，使用 git worktree 同时运行多个分支：

```bash
# Create a worktree for a feature branch
git worktree add ../project-feature-a feature/task-creation
git worktree add ../project-feature-b feature/user-settings

# Each worktree is a separate directory with its own branch
# Agents can work in parallel without interfering
ls ../
  project/              ← main branch
  project-feature-a/    ← task-creation branch
  project-feature-b/    ← user-settings branch

# When done, merge and clean up
git worktree remove ../project-feature-a
```

好处：
- 多个 agent 可以同时在不同功能上工作
- 无需切换分支（每个目录都有自己的分支）
- 如果一个实验失败，删除 worktree——什么都不会丢
- 变更在显式合并之前都是隔离的

## 存档点模式

```
Agent starts work
    │
    ├── Makes a change
    │   ├── Test passes? → Commit → Continue
    │   └── Test fails? → Revert to last commit → Investigate
    │
    ├── Makes another change
    │   ├── Test passes? → Commit → Continue
    │   └── Test fails? → Revert to last commit → Investigate
    │
    └── Feature complete → All commits form a clean history
```

这个模式意味着你永远不会丢失超过一个增量的工作。如果 agent 跑偏了，`git reset --hard HEAD` 会带你回到最后一个成功状态。

## 变更摘要

在任一次修改之后，提供一份结构化的摘要。这让评审更容易、记录范围纪律，并暴露意外的变更：

```
CHANGES MADE:
- src/routes/tasks.ts: Added validation middleware to POST endpoint
- src/lib/validation.ts: Added TaskCreateSchema using Zod

THINGS I DIDN'T TOUCH (intentionally):
- src/routes/auth.ts: Has similar validation gap but out of scope
- src/middleware/error.ts: Error format could be improved (separate task)

POTENTIAL CONCERNS:
- The Zod schema is strict — rejects extra fields. Confirm this is desired.
- Added zod as a dependency (72KB gzipped) — already in package.json
```

这个模式能及早捕获错误的假设，并给评审者一张清晰的变更地图。「没有触碰」这一节尤其重要——它表明你行使了范围纪律，没有自作主张地大动干戈。

## 提交前卫生

每次提交之前：

```bash
# 1. Check what you're about to commit
git diff --staged

# 2. Ensure no secrets
git diff --staged | grep -i "password\|secret\|api_key\|token"

# 3. Run tests
npm test

# 4. Run linting
npm run lint

# 5. Run type checking
npx tsc --noEmit
```

用 git hooks 自动化这个流程：

```json
// package.json (using lint-staged + husky)
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md}": ["prettier --write"]
  }
}
```

## 处理生成文件

- 仅当项目期望它们时**提交生成文件**（例如 `package-lock.json`、Prisma 迁移）
- **不要提交**构建输出（`dist/`、`.next/`）、环境文件（`.env`）或 IDE 配置（除非共享，否则 `.vscode/settings.json`）
- **有一个 `.gitignore`** 覆盖：`node_modules/`、`dist/`、`.env`、`.env.local`、`*.pem`

## 用 Git 调试

```bash
# Find which commit introduced a bug
git bisect start
git bisect bad HEAD
git bisect good <known-good-commit>
# Git checkouts midpoints; run your test at each to narrow down

# View what changed recently
git log --oneline -20
git diff HEAD~5..HEAD -- src/

# Find who last changed a specific line
git blame src/services/task.ts

# Search commit messages for a keyword
git log --grep="validation" --oneline
```

## 发布与版本管理

提交是你*自己*跟踪变更的方式；**版本**是*消费者*跟踪它的方式。一旦有别的任何东西依赖你的代码——另一个团队、一个已发布的包、一个已部署的客户端——「main 上最新」就不再是「我在跑什么，升级安全吗？」的充分答案。版本号和 changelog 就是回答这个问题的契约。

### 语义化版本

对于任何有消费者的东西，按 `MAJOR.MINOR.PATCH` 版本化，并让数字承载意义：

```
  MAJOR  breaking change — consumers must change their code to upgrade
  MINOR  new functionality, backward-compatible — safe to upgrade
  PATCH  bug fix, backward-compatible — safe to upgrade
```

这个数字是一个承诺，所以要让代码与之匹配。一个改变了消费者所依赖行为的「patch」是穿着伪装的 major 变更（海勒姆定律——参见 `api-and-interface-design` 技能）。当不确定某个变更是否是破坏性的时，假定它是；一个惊喜的 major 比一个被弄坏的消费者便宜得多。

### 给 release 打标签，并让标签成为事实来源

一个 release 是历史中一个不可变的时间点，而不是一个移动的分支。给它打标签，这样它总能被复现：

```bash
git tag -a v1.4.0 -m "Release 1.4.0"
git push origin v1.4.0
```

从标签派生版本号，而不是在零散的文件里手改它，这样构件、标签和 changelog 就永远不会不一致。

### 维护一份为人类编写的 changelog

changelog 不是 `git log`。它是经过策划、面向消费者的「改了什么、我需不需要关心？」的答案——按 `Added / Changed / Fixed / Deprecated / Removed / Security` 分组，最新在上，每一条都围绕用户影响措辞，而不是内部机制。

```markdown
## [1.4.0] - 2025-06-12
### Added
- Bulk task import via CSV
### Fixed
- Timezone drift in recurring task due dates
### Deprecated
- `GET /v1/tasks/all` — use the paginated `GET /v1/tasks` (removal in 2.0)
```

在做出变更的同一个变更里写下这条记录，趁影响还新鲜——而不是在发布时从提交考古中重建。破坏性变更要带迁移说明和弃用窗口（遵循 `deprecation-and-migration` 技能）；实际发布 release 是 `shipping-and-launch` 技能的活——本节是喂给它的版本契约。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「功能做完了再提交」 | 一个巨大的提交无法评审、调试或回退。逐个切片提交。 |
| 「消息无所谓」 | 消息就是文档。未来的你（和未来的 agent）需要理解改了什么以及为什么。 |
| 「我之后再 squash」 | Squashing 会摧毁开发的叙事。从一开始就保持干净的增量提交。 |
| 「分支是额外开销」 | 短命分支是免费的，还能防止冲突的工作互相碰撞。长期分支才是问题——1-3 天内合并。 |
| 「我之后会拆分这个变更」 | 大变更更难评审、部署风险更大、回退也更难。在提交前拆分，而不是之后。 |
| 「我不需要 .gitignore」 | 直到带着生产密钥的 `.env` 被提交。立刻设置它。 |
| 「只是个小修复，升个 patch 就行」 | 检查消费者能观察到什么。一个他们依赖的行为变更是 major，无论 diff 多大。 |
| 「changelog 就是提交日志」 | 提交是给你自己的；changelog 是给消费者的，按影响策划。从原始提交生成会埋没真正重要的东西。 |
| 「我们在发布时再写 changelog」 | 到那时影响只能凭记忆重建，一半都丢了。随着变更一起写。 |

## 危险信号

- 大量未提交的变更在积累
- 诸如「fix」「update」「misc」的提交消息
- 格式化变更与行为变更混在一起
- 项目没有 `.gitignore`
- 提交 `node_modules/`、`.env` 或构建产物
- 与 main 显著分叉的长期分支
- 强制推送到共享分支
- 一个破坏性变更以 minor 或 patch 版本提升发布
- 一个没有标签的 release，或与标签不同步的手改版本号
- 一个面向用户的 release 没有 changelog 条目，或 changelog 只是倾倒出来的提交消息

## 验证

对每个提交：

- [ ] 提交只做一件符合逻辑的事
- [ ] 消息解释为什么，遵循类型约定
- [ ] 提交前测试通过
- [ ] diff 中没有密钥
- [ ] 没有只改格式的变更与行为变更混在一起
- [ ] `.gitignore` 覆盖标准排除项

对每个 release（任何有消费者的东西）：

- [ ] 版本提升与变更匹配：破坏性 → major，新增 → minor，修复 → patch
- [ ] release 已打标签，且版本从标签派生，而不是不同步的手改
- [ ] changelog 有为本版本按影响分组的、经过策划、人类可读的条目
