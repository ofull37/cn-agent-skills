---
name: deprecation-and-migration
description: 管理弃用与迁移。当移除旧系统、API 或功能时使用。当把用户从一个实现迁移到另一个实现时使用。当决定是维护还是淘汰现有代码时使用。
---

# 弃用与迁移

## 概述

代码是负债，不是资产。每一行代码都有持续的维护成本——要修复的 bug、要更新的依赖、要应用的安全补丁，以及要上手的新工程师。弃用是移除那些不再物有所值的代码的纪律，而迁移是把用户安全地从旧系统带到新系统的过程。

大多数工程组织擅长构建东西。很少有擅长移除它们的。本技能填补这个缺口。

## 何时使用

- 用新系统、API 或库替换旧的
- 淘汰一个不再需要的功能
- 整合重复的实现
- 移除没人拥有、但人人都依赖的死代码
- 规划一个新系统的生命周期（弃用规划从设计时就该开始）
- 决定是维护遗留系统还是投入迁移

## 核心原则

### 代码是负债

每一行代码都有持续成本：它需要测试、文档、安全补丁、依赖更新，以及附近任何人的心智开销。代码的价值在于它提供的功能，而不是代码本身。当同样的功能可以用更少的代码、更少的复杂度或更好的抽象来提供时——旧代码就该走。

### 海勒姆定律让移除变难

一旦用户足够多，每一个可观察的行为都会变得被依赖——包括 bug、时序怪癖和未记录的副作用。这就是为什么弃用需要主动迁移，而不只是发布公告。当用户依赖的是替代品无法复现的行为时，他们无法「直接切换」。

### 弃用规划从设计时开始

在构建新东西时问：「3 年后我们怎么移除它？」拥有干净接口、功能开关和最小表面积设计的系统，比把实现细节泄漏到各处系统更容易弃用。

## 弃用决策

在弃用任何东西之前，回答这些问题：

```
1. Does this system still provide unique value?
   → If yes, maintain it. If no, proceed.

2. How many users/consumers depend on it?
   → Quantify the migration scope.

3. Does a replacement exist?
   → If no, build the replacement first. Don't deprecate without an alternative.

4. What's the migration cost for each consumer?
   → If trivially automated, do it. If manual and high-effort, weigh against maintenance cost.

5. What's the ongoing maintenance cost of NOT deprecating?
   → Security risk, engineer time, opportunity cost of complexity.
```

## 强制弃用 vs 建议弃用

| 类型 | 何时使用 | 机制 |
|------|-------------|-----------|
| **建议（Advisory）** | 迁移是可选的，旧系统稳定 | 警告、文档、推动。用户按自己的时间表迁移。 |
| **强制（Compulsory）** | 旧系统有安全问题、阻碍进展，或维护成本不可持续 | 硬性截止日期。旧系统将在日期 X 之前被移除。提供迁移工具。 |

**默认建议。** 只有维护成本或风险证明必须强制迁移时，才使用强制。强制弃用要求提供迁移工具、文档和支持——你不能只是宣布一个截止日期。

## 迁移流程

### 第 1 步：构建替代品

没有可用的替代品就不要弃用。替代品必须：

- 覆盖旧系统的所有关键用例
- 有文档和迁移指南
- 已通过生产验证（而不只是「理论上更好」）

### 第 2 步：公告与文档化

```markdown
## Deprecation Notice: OldService

**Status:** Deprecated as of 2025-03-01
**Replacement:** NewService (see migration guide below)
**Removal date:** Advisory — no hard deadline yet
**Reason:** OldService requires manual scaling and lacks observability.
            NewService handles both automatically.

### Migration Guide
1. Replace `import { client } from 'old-service'` with `import { client } from 'new-service'`
2. Update configuration (see examples below)
3. Run the migration verification script: `npx migrate-check`
```

### 第 3 步：增量迁移

一次迁移一个消费者，而不是全部同时迁移。对每个消费者：

```
1. Identify all touchpoints with the deprecated system
2. Update to use the replacement
3. Verify behavior matches (tests, integration checks)
4. Remove references to the old system
5. Confirm no regressions
```

**转换法则（Churn Rule）：** 如果你拥有要被弃用的基础设施，你就有责任迁移你的用户——或者提供无需迁移的向后兼容更新。不要宣布弃用，然后让用户自己去摸索。

### 第 4 步：移除旧系统

只有在所有消费者都迁移完成之后：

```
1. Verify zero active usage (metrics, logs, dependency analysis)
2. Remove the code
3. Remove associated tests, documentation, and configuration
4. Remove the deprecation notices
5. Celebrate — removing code is an achievement
```

## 迁移模式

### 绞杀者模式（Strangler Pattern）

让新旧系统并行运行。增量地把流量从旧系统路由到新系统。当旧系统处理 0% 的流量时，移除它。

```
Phase 1: New system handles 0%, old handles 100%
Phase 2: New system handles 10% (canary)
Phase 3: New system handles 50%
Phase 4: New system handles 100%, old system idle
Phase 5: Remove old system
```

### 适配器模式（Adapter Pattern）

创建一个适配器，把来自旧接口的调用翻译给新实现。在迁移后端的同时，消费者继续使用旧接口。

```typescript
// Adapter: old interface, new implementation
class LegacyTaskService implements OldTaskAPI {
  constructor(private newService: NewTaskService) {}

  // Old method signature, delegates to new implementation
  getTask(id: number): OldTask {
    const task = this.newService.findById(String(id));
    return this.toOldFormat(task);
  }
}
```

### 功能开关迁移

用功能开关把消费者逐个从旧系统切换到新系统：

```typescript
function getTaskService(userId: string): TaskService {
  if (featureFlags.isEnabled('new-task-service', { userId })) {
    return new NewTaskService();
  }
  return new LegacyTaskService();
}
```

### 数据库 Schema 迁移（扩/缩）

Schema 变更是最有风险的迁移，因为数据是唯一无法通过回退部署来回滚的东西。失败模式是把 schema 变更与代码变更耦合在一起：在同一个发布里改列名并开始使用新名字，在发布窗口期间——旧代码和新代码同时运行时——其中一方在查询一个不存在的列。解决办法是**绝不在原地改列**。以增量阶段迁移，让旧代码和新代码在每一步都同时有效。

```
EXPAND ──────────────→ MIGRATE ──────────────→ CONTRACT
add the new column,    backfill existing rows,  once no code reads the
nullable, alongside    dual-write old+new from  old column, drop it in
the old one            the app                  a later, separate deploy
```

**完整示例——把 `name` 重命名为 `full_name`：**

1. **扩展（Expand）。** 添加可为空的 `full_name`。部署。（旧代码忽略它；什么都不会坏。）
2. **双写（Dual-write）。** 应用在每次插入/更新时同时写 `name` 和 `full_name`。部署。
3. **回填（Backfill）。** 分批把现有行的 `name → full_name` 复制过去，这样你不会锁住表。
4. **切换读取（Switch reads）。** 让应用指向 `full_name`，继续写两个字段。部署并静置观察。
5. **收缩（Contract）。** 停止写 `name`，然后在*另一个、更晚的*部署中删除该列。

每一步都可独立部署、可回退：如果第 4 步表现异常，回滚代码，`full_name` 仍然在被填充。把每个阶段当作一个薄的垂直切片——参见 `incremental-implementation` 技能。

**规则：**
- **先加后删，破坏性操作最后且单独进行。** 添加（新可空列、新表、新索引）在任何部署中都是安全的；删除和重命名要等没有代码再引用旧形态后，拥有自己的部署。
- **每个迁移都有经过测试的向下路径。** 一个无法逆转的迁移就是一个无法回退的部署。在合并前写好并运行 `down`。
- **分批回填，避开热路径。** 对数百万行执行一次 `UPDATE` 会锁住表；要分块并限流。
- **在不阻塞写入的情况下构建大索引**（例如 Postgres `CREATE INDEX CONCURRENTLY`）。
- **在切换有风险时，用功能开关与代码解耦**，与上面「功能开关迁移」模式完全一样。

## 僵尸代码

僵尸代码是没人拥有、但人人都依赖的代码。它没有积极维护，没有明确的所有者，并不断积累安全漏洞和兼容性问题。迹象：

- 6 个多月没有提交，但仍存在活跃消费者
- 没有指定的维护者或团队
- 没人修复的失败测试
- 带已知漏洞却没人更新的依赖
- 引用已不存在系统的文档

**应对：** 要么指派一个所有者并妥善维护它，要么用一份具体的迁移计划弃用它。僵尸代码不能永远悬在中间状态——它要么得到投入，要么被移除。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「它还能用，为什么要移除？」 | 没人维护的可用代码会积累安全债和复杂度。维护成本在无声地增长。 |
| 「以后可能有人需要它」 | 如果以后需要，可以重建。为了「以防万一」留着无用代码，成本高于重建。 |
| 「迁移成本太高了」 | 把迁移成本与 2-3 年的持续维护成本相比。长期来看，迁移通常更便宜。 |
| 「我们做完新系统后再弃用」 | 弃用规划从设计时开始。等新系统做完，你会有新的优先事项。现在就开始规划。 |
| 「用户会自己迁移」 | 他们不会。提供工具、文档和激励——或者自己做迁移（转换法则）。 |
| 「我们可以无限期地同时维护两套系统」 | 两套系统做同一件事，是双倍的维护、测试、文档和新手上手成本。 |
| 「只是重命名一列而已，一行代码」 | 发布期间新旧代码同时运行——其中一方会查询一个不再存在的列。扩/缩，绝不在原地重命名。 |
| 「我会在同一个迁移里加新列并删旧列」 | 这会把一个安全的添加和一个破坏性的删除耦合起来。删除要有自己的部署，在没有任何代码引用旧形态之后。 |
| 「需要时我们会写回滚」 | 没有向下路径的迁移是一个无法回退的部署。在合并前写好并运行 `down`。 |

## 危险信号

- 没有可用替代品的弃用系统
- 没有迁移工具或文档的弃用公告
- 多年停留在「建议」阶段、毫无进展的「软」弃用
- 没有所有者却有活跃消费者的僵尸代码
- 往已弃用的系统里添加新功能（应该把投入放在替代品上）
- 不先测量当前使用情况就弃用
- 不验证零活跃消费者就移除代码
- 一个 schema 变更和依赖它的代码在同一个部署中发布
- 一列被原地重命名或删除，而不是通过扩/缩
- 一个没有经过测试的向下路径就合并的迁移，或一个锁住表的回填

## 验证

完成一次弃用之后：

- [ ] 替代品已通过生产验证，并覆盖所有关键用例
- [ ] 存在带具体步骤和示例的迁移指南
- [ ] 所有活跃消费者都已迁移（由指标/日志验证）
- [ ] 旧代码、测试、文档和配置已被完全移除
- [ ] 代码库中不再有对弃用系统的引用
- [ ] 弃用通知已被移除（它们已完成使命）

完成一次数据库 schema 迁移之后：

- [ ] 变更以增量阶段发布（扩展 → 回填 → 收缩），而不是一次性的原地编辑
- [ ] 在每一个部署步骤中，旧代码和新代码对 schema 都同时有效
- [ ] 每个迁移都有经过测试的向下路径；回填以限流的分批进行
- [ ] 破坏性步骤（删除/重命名）在没有任何代码引用旧形态之后，拥有自己的部署
