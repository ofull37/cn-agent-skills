# 安全检查清单

Web 应用安全的快速参考。与 `security-and-hardening` 技能配合使用。

## 目录

- [威胁建模（从这里开始）](#threat-modeling-start-here)
- [提交前检查](#pre-commit-checks)
- [认证](#authentication)
- [授权](#authorization)
- [输入验证](#input-validation)
- [安全响应头](#security-headers)
- [CORS 配置](#cors-configuration)
- [数据保护](#data-protection)
- [依赖安全](#dependency-security)
- [AI / LLM 安全](#ai--llm-security)
- [错误处理](#error-handling)
- [OWASP Top 10 快速参考](#owasp-top-10-quick-reference)
- [OWASP Top 10 for LLMs 快速参考](#owasp-top-10-for-llms-quick-reference)

## 威胁建模（从这里开始）

在考虑控制措施之前，花五分钟像攻击者一样思考：

- [ ] 已映射信任边界（请求、上传、webhook、第三方 API、LLM 输出）
- [ ] 已点名资产（凭据、PII、支付数据、管理操作、资金流转）
- [ ] 对每个边界运行 STRIDE（欺骗、篡改、否认、信息泄露、DoS、权限提升）
- [ ] 在用例旁边写出滥用用例（「我会如何滥用它？」）

## 提交前检查

- [ ] 代码中没有机密信息（`git diff --cached | grep -i "password\|secret\|api_key\|token"`）
- [ ] `.gitignore` 覆盖：`.env`、`.env.local`、`*.pem`、`*.key`
- [ ] `.env.example` 使用占位值（而非真实机密信息）

## 认证

- [ ] 密码使用 bcrypt（≥12 轮）、scrypt 或 argon2 哈希
- [ ] 会话 cookie：`httpOnly`、`secure`、`sameSite: 'lax'`
- [ ] 已配置会话过期（合理的 max-age）
- [ ] 登录端点有速率限制（每 15 分钟 ≤10 次尝试）
- [ ] 密码重置令牌：限时（≤1 小时）、一次性使用
- [ ] 多次失败后账户锁定（可选，并附通知）
- [ ] 敏感操作支持 MFA（可选但推荐）

## 授权

- [ ] 每个受保护端点都检查认证
- [ ] 每次资源访问都检查所有权/角色（防止 IDOR）
- [ ] 管理端点要求验证管理员角色
- [ ] API 密钥范围限定为最低必要权限
- [ ] JWT 令牌已验证（签名、过期时间、签发者）

## 输入验证

- [ ] 所有用户输入都在系统边界得到验证（API 路由、表单处理器）
- [ ] 验证使用允许列表（而非拒绝列表）
- [ ] 字符串长度受约束（最小/最大）
- [ ] 数值范围已验证
- [ ] 使用合适的库验证邮箱、URL 和日期格式
- [ ] 文件上传：类型受限、大小受限、内容已验证
- [ ] SQL 查询参数化（不使用字符串拼接）
- [ ] HTML 输出已编码（使用框架的自动转义）
- [ ] 重定向前验证 URL（防止开放重定向）
- [ ] 服务端 URL 请求列入允许列表；阻止私有/保留 IP（防止 SSRF）

## 安全响应头

```
Content-Security-Policy: default-src 'self'; script-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0  (disabled, rely on CSP)
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

## CORS 配置

```typescript
// Restrictive (recommended)
cors({
  origin: ['https://yourdomain.com', 'https://app.yourdomain.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

// NEVER use in production:
cors({ origin: '*' })  // Allows any origin
```

## 数据保护

- [ ] 敏感字段从 API 响应中排除（`passwordHash`、`resetToken` 等）
- [ ] 敏感数据不被记录（密码、令牌、完整信用卡号）
- [ ] PII 静态加密（如法规要求）
- [ ] 所有外部通信使用 HTTPS
- [ ] 数据库备份加密

## 依赖安全

首先定位**安装边界**。如果该包被某个父级 `workspaces` 声明匹配，使用该 workspace 根；否则使用同时拥有其清单和依赖图、且最近的项目的根。在该边界，核实 `packageManager`（如存在）、lockfile 和 CI 命令。如果它们不一致或该处存在相互竞争的 manager lockfile，则停下来。只有当一个嵌套项目位于父 workspace 之外时它才是独立的；独立子项目可以合理地使用不同的 manager。

| Manager/版本信号 | 冻结/不可变 CI 安装 | 已知漏洞审计 |
|---|---|---|
| npm（`package-lock.json` 或 `npm-shrinkwrap.json`） | `npm ci` | `npm audit` |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm audit` |
| Yarn 2+ | `yarn install --immutable` | `yarn npm audit -A -R` |
| Yarn 1 | `yarn install --frozen-lockfile` | `yarn audit` |

对于未列出的 manager 或版本，请查阅其官方文档；不要用另一个 manager 的命令或更新的默认值来替代。

### 安装脚本关卡

绝不要通过首先在默认值未经核实的客户端上执行普通安装，来发现依赖的生命周期脚本。

1. 在禁用依赖脚本的情况下引导，或采用文档化的默认拒绝策略并强制执行失败即关闭。
2. 在批准之前检查确切的脚本源码和包版本。
3. 在安装边界记录最窄的原生允许/拒绝策略并提交它。
4. 使用该策略运行一次干净的冻结/不可变安装，并验证所需包仍然能构建。

**时点快照：** 包管理器默认值和命令名变化很快。在依赖本矩阵之前，请对照所固定客户端的当前官方文档进行核实。

| Manager 版本 | 原生策略 |
|---|---|
| 未经核实细粒度批准的 npm | 使用 `npm ci --ignore-scripts` 引导，或在打算全项目阻止时持久化 `ignore-scripts=true`。保持脚本禁用，或在允许任何经过评审的依赖脚本之前刻意升级。 |
| npm 11.18.x（在 11.18.0 上验证） | 未经评审的依赖脚本默认带警告运行。在正常安装前强制执行 `strict-allow-scripts=true`，然后从安装边界使用不感知 workspace 的 `npm install-scripts ls`；批准保持版本锁定，拒绝按名称全局生效。 |
| npm 12.x（在 12.0.1 上验证） | 未经评审的依赖脚本默认被跳过；`strict-allow-scripts=true` 使它们的存在在执行前就让安装失败。使用同样的 `npm install-scripts` 评审与批准流程。 |
| pnpm 11+ | 使用 `pnpm approve-builds` 并提交 `allowBuilds` 决策；`strictDepBuilds` 默认为 `true`，因此未评审的构建会失败。 |
| pnpm 10.26–10.x | 显式配置 `allowBuilds`，或使用 `pnpm approve-builds` 配合传统的 `onlyBuiltDependencies` / `ignoredBuiltDependencies` 列表。设置 `strictDepBuilds: true`；其 v10 默认值为 `false`。 |
| pnpm 10.1–10.25 | `pnpm approve-builds` 记录传统列表；在支持的地方（10.3+）启用 `strictDepBuilds`。 |
| 较旧或未知的 pnpm | 使用 `pnpm install --frozen-lockfile --ignore-scripts` 引导。保持脚本禁用，除非固定版本记录了可执行的策略。 |
| Yarn 4.14+ | 依赖 postinstall 默认禁用。仅通过顶层 `dependenciesMeta.<package>.built: true` 授予所需例外。 |
| Yarn 2–4.13 | 在 `.yarnrc.yml` 中设置 `enableScripts: false`，然后仅通过顶层 `dependenciesMeta.<package>.built: true` 授予所需例外；不要全局启用脚本。 |
| Yarn 1 | 使用 `yarn install --ignore-scripts` 引导；保持脚本禁用，除非每个所需例外都在所固定客户端的文档化工作流下经过评审。 |

权威检查：[npm install-scripts](https://docs.npmjs.com/cli/v11/commands/npm-install-scripts/)、[install policy](https://docs.npmjs.com/cli/v11/commands/npm-install/) 和 [CLI releases](https://github.com/npm/cli/releases)；[pnpm approve-builds](https://pnpm.io/cli/approve-builds) 和 [build settings](https://pnpm.io/settings#allowbuilds)；[Yarn security](https://yarnpkg.com/features/security) 和 [manifest](https://yarnpkg.com/configuration/manifest#dependenciesMeta)。

**供应链卫生**（漏洞审计无法捕获新出现的恶意包）：
- [ ] 每个项目/workspace 根只提交一个权威 lockfile，且 CI 永不重写它
- [ ] 严重/高危发现已按可达性分类处理；延期有理由和评审日期
- [ ] 强制的审计修复（`npm audit fix --force` 或等价物）永不自动执行；修复 diff 和变更日志经过评审
- [ ] 在 manager 支持的情况下，验证注册表签名/来源证明
- [ ] 依赖生命周期脚本在首次执行前被阻止，且只能通过所固定 manager 的原生策略批准
- [ ] 新依赖就所有权、维护情况、发布年龄、来源证明、传递依赖图和 typosquatting 进行评审

## AI / LLM 安全

对于任何调用 LLM 的功能（聊天机器人、摘要器、agent、RAG）：

- [ ] 模型输出被视为不受信任——绝不进入 `eval`/SQL/shell/`innerHTML`/文件路径
- [ ] 假定存在提示注入；权限在代码中强制执行，而非在系统提示中
- [ ] 机密信息、跨租户数据和完整系统提示保持在上下文窗口之外
- [ ] 工具/agent 权限做了范围限制；破坏性或不可逆操作要求确认
- [ ] 设置 token、速率和递归/循环限制（约束消耗）

## 错误处理

```typescript
// Production: generic error, no internals
res.status(500).json({
  error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' }
});

// NEVER in production:
res.status(500).json({
  error: err.message,
  stack: err.stack,         // Exposes internals
  query: err.sql,           // Exposes database details
});
```

## OWASP Top 10 快速参考

| # | 漏洞 | 预防 |
|---|---|---|
| 1 | 访问控制失效 | 每个端点做认证检查、所有权验证 |
| 2 | 加密失败 | HTTPS、强哈希、代码中无机密信息 |
| 3 | 注入 | 参数化查询、输入验证 |
| 4 | 不安全的设计 | 威胁建模、spec 驱动的开发 |
| 5 | 安全配置错误 | 安全响应头、最小权限、审计依赖 |
| 6 | 易受攻击的组件 | 生态系统的依赖审计（`npm audit`、`pip-audit`……）、保持依赖更新、最小化依赖 |
| 7 | 认证失败 | 强密码、速率限制、会话管理 |
| 8 | 数据完整性失效 | 验证更新/依赖、签名产物 |
| 9 | 日志失败 | 记录安全事件，不记录机密信息 |
| 10 | SSRF | 验证/允许列表 URL、限制出站请求 |

## OWASP Top 10 for LLMs 快速参考

适用于带 LLM 功能的应用。参见 [OWASP GenAI Security Project](https://genai.owasp.org/llm-top-10/)。

| ID | 风险 | 预防 |
|---|---|---|
| LLM01 | 提示注入 | 不要把系统提示当作边界；在代码中强制执行权限 |
| LLM02 | 敏感信息泄露 | 让机密信息/PII 远离提示；过滤输出 |
| LLM03 | 供应链 | 像审查任何依赖一样审查模型、数据集和插件 |
| LLM04 | 数据与模型投毒 | 使用可信模型来源、验证完整性；审查微调和 RAG 数据 |
| LLM05 | 输出处理不当 | 将模型输出视为不受信任；验证、参数化、编码 |
| LLM06 | 过度自主 | 限定工具权限；确认破坏性操作 |
| LLM07 | 系统提示泄露 | 假定系统提示可能泄露；其中不放任何机密信息 |
| LLM08 | 向量与嵌入弱点 | 按租户分区 RAG 嵌入；索引前验证文档 |
| LLM09 | 错误信息 | 用引用支撑答案；验证关键论断；保持人在回路中 |
| LLM10 | 无界消耗 | 限制 token、请求速率和循环/递归深度 |
