---
description: 用于添加或修改技能的防重复护栏
paths:
  - "skills/**"
---

# 添加或修改技能

本仓库已经覆盖了开发生命周期的大部分环节，因此大多数新技能的想法都会与现有技能或打开的 PR 重叠。在创建新的 `skills/<name>/` 目录或对现有技能进行重大改造之前：

- 运行 [CONTRIBUTING.md](../../CONTRIBUTING.md#before-proposing-a-new-skill) 中的预检检查：搜索目录、检查打开的 PR（`gh pr list --state open`），并说明该空白的合理性。
- 优先扩展现有技能，而不是添加近似的重复项。如果想法与现有技能重叠，就编辑该技能，而不是新建目录。
- 让 `SKILL.md` 符合 [docs/skill-anatomy.md](../../docs/skill-anatomy.md)，并且绝不在技能之间重复内容，改为引用另一个技能。

CONTRIBUTING.md 是整个工作流程的唯一事实来源；本规则只是指向它，而不是复述其检查清单。
