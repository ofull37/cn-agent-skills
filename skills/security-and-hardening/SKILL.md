---
name: security-and-hardening
description: 加固代码以抵御漏洞、注入和其他攻击。当处理用户输入、认证、数据存储或外部集成时使用。当构建任何接受不可信数据、管理用户会话或与第三方服务交互的功能时使用。
---

# 安全与强化

## 概述

面向 Web 应用的安全优先开发实践。把每一个外部输入都当作敌意的，每一个密钥都当作神圣的，每一次授权检查都是强制的。安全不是一个阶段——它是对每一行触碰用户数据、认证或外部系统的代码的约束。

## 何时使用

- 构建任何接受用户输入的内容
- 实现认证或授权
- 存储或传输敏感数据
- 集成外部 API 或服务
- 添加文件上传、webhook 或回调
- 处理支付或 PII 数据

## 流程：先做威胁建模

不加威胁模型就硬塞控制措施，那是在瞎猜。在强化之前，花五分钟像攻击者一样思考：

1. **画出信任边界。** 不可信数据在哪里进入你的系统？HTTP 请求、表单字段、文件上传、webhook、第三方 API、消息队列，以及 **LLM 输出**。每条边界都是攻击面。
2. **说出资产。** 什么东西值得被偷或被破坏？凭据、PII、支付数据、管理员操作、资金流转。
3. **对每条边界跑一遍 STRIDE**——它是一个快速透镜，不是走流程：

| 威胁 | 要问的 | 典型缓解措施 |
|---|---|---|
| **S**poofing（仿冒） | 有人能冒充用户/服务吗？ | 认证、签名验证 |
| **T**ampering（篡改） | 数据能在传输中或静态时被改动吗？ | 完整性检查、参数化查询、HTTPS |
| **R**epudiation（抵赖） | 之后能否否认一个动作？ | 安全事件的审计日志 |
| **I**nformation disclosure（信息泄露） | 数据会泄露吗？ | 加密、字段白名单、通用错误消息 |
| **D**enial of service（拒绝服务） | 它会被压垮吗？ | 速率限制、输入大小上限、超时 |
| **E**levation of privilege（权限提升） | 用户能获得不应有的权限吗？ | 授权检查、最小权限 |

4. **在用例旁边写下滥用用例。** 对每个功能，问「我会怎么滥用它？」——然后把那变成你的第一个测试。

如果你说不出一个功能的信任边界，你还没准备好保护它。这就是 OWASP **A04：不安全的设计**——大多数漏洞始于设计，而不是代码。

## 三层边界系统

### 始终要做（无例外）

- 在系统边界**验证所有外部输入**（API 路由、表单处理器）
- **参数化所有数据库查询**——绝不把用户输入拼接进 SQL
- **编码输出**以防止 XSS（使用框架的自动转义，不要绕过它）
- 所有外部通信都**使用 HTTPS**
- 用 bcrypt/scrypt/argon2 **对密码进行哈希**（绝不存储明文）
- **设置安全响应头**（CSP、HSTS、X-Frame-Options、X-Content-Type-Options）
- 会话使用 **httpOnly、secure、sameSite cookie**
- 每次发布前，**针对已提交的 lockfile 运行检测到的包管理器的原生 audit**

### 先询问（需要人工批准）

- 添加新的认证流程或更改认证逻辑
- 存储新类别的敏感数据（PII、支付信息）
- 添加新的外部服务集成
- 更改 CORS 配置
- 添加文件上传处理器
- 修改速率限制或节流
- 授予提升的权限或角色

### 绝不做的

- **绝不把密钥提交到版本控制**（API 密钥、密码、令牌）
- **绝不记录敏感数据**（密码、令牌、完整信用卡号）
- **绝不把客户端验证当作安全边界**
- **绝不为图方便禁用安全响应头**
- **绝不对用户提供的数据使用 `eval()` 或 `innerHTML`**
- **绝不把会话存储在客户端可访问的存储中**（用 localStorage 存认证令牌）
- **绝不向用户暴露堆栈跟踪**或内部错误细节

## OWASP Top 10 防护模式

这些是防护模式，不是排名。2021 版的排序参见 `references/security-checklist.md` 中的速查表。

### 注入（SQL、NoSQL、操作系统命令）

```typescript
// BAD: SQL injection via string concatenation
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// GOOD: Parameterized query
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

// GOOD: ORM with parameterized input
const user = await prisma.user.findUnique({ where: { id: userId } });
```

### 失效的身份认证

```typescript
// Password hashing
import { hash, compare } from 'bcrypt';

const SALT_ROUNDS = 12;
const hashedPassword = await hash(plaintext, SALT_ROUNDS);
const isValid = await compare(plaintext, hashedPassword);

// Session management
app.use(session({
  secret: process.env.SESSION_SECRET,  // From environment, not code
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,     // Not accessible via JavaScript
    secure: true,       // HTTPS only
    sameSite: 'lax',    // CSRF protection
    maxAge: 24 * 60 * 60 * 1000,  // 24 hours
  },
}));
```

### 跨站脚本（XSS）

```typescript
// BAD: Rendering user input as HTML
element.innerHTML = userInput;

// GOOD: Use framework auto-escaping (React does this by default)
return <div>{userInput}</div>;

// If you MUST render HTML, sanitize first
import DOMPurify from 'dompurify';
const clean = DOMPurify.sanitize(userInput);
```

### 失效的访问控制

```typescript
// Always check authorization, not just authentication
app.patch('/api/tasks/:id', authenticate, async (req, res) => {
  const task = await taskService.findById(req.params.id);

  // Check that the authenticated user owns this resource
  if (task.ownerId !== req.user.id) {
    return res.status(403).json({
      error: { code: 'FORBIDDEN', message: 'Not authorized to modify this task' }
    });
  }

  // Proceed with update
  const updated = await taskService.update(req.params.id, req.body);
  return res.json(updated);
});
```

### 安全配置错误

```typescript
// Security headers (use helmet for Express)
import helmet from 'helmet';
app.use(helmet());

// Content Security Policy
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],  // Tighten if possible
    imgSrc: ["'self'", 'data:', 'https:'],
    connectSrc: ["'self'"],
  },
}));

// CORS — restrict to known origins
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true,
}));
```

### 敏感数据暴露

```typescript
// Never return sensitive fields in API responses
function sanitizeUser(user: UserRecord): PublicUser {
  const { passwordHash, resetToken, ...publicFields } = user;
  return publicFields;
}

// Use environment variables for secrets
const API_KEY = process.env.STRIPE_API_KEY;
if (!API_KEY) throw new Error('STRIPE_API_KEY not configured');
```

### 服务器端请求伪造（SSRF）

每当服务器获取一个受用户影响的 URL——webhook、「从 URL 导入」、图片代理、链接预览——攻击者都可能把它指向内部服务（云元数据、`localhost`、私有 IP）。

```typescript
// BAD: fetch whatever the user gives you
await fetch(req.body.webhookUrl);

// GOOD: allowlist scheme + host, reject if ANY resolved IP is private, forbid redirects
import { lookup } from 'node:dns/promises';
import ipaddr from 'ipaddr.js';

const ALLOWED_HOSTS = new Set(['hooks.example.com']);

async function assertSafeUrl(raw: string): Promise<URL> {
  const url = new URL(raw);
  if (url.protocol !== 'https:') throw new Error('https only');
  if (!ALLOWED_HOSTS.has(url.hostname)) throw new Error('host not allowed');
  // Resolve ALL records; a single private/reserved address fails the check.
  const addrs = await lookup(url.hostname, { all: true });
  if (addrs.some((a) => ipaddr.parse(a.address).range() !== 'unicast')) {
    throw new Error('private/reserved IP');
  }
  return url;
}

await fetch(await assertSafeUrl(req.body.webhookUrl), { redirect: 'error' });
```

`range() !== 'unicast'` 检查覆盖了 loopback、链路本地 `169.254.169.254`（云元数据，SSRF 的头号目标）、私有地址和唯一本地地址范围，同时涵盖 IPv4 和 IPv6。

**注意事项——这仍然有一个 TOCTOU 缺口。** `fetch` 在检查之后会再次解析 DNS，因此使用短 TTL 记录的攻击者可以在校验与连接之间重绑定到内部 IP。对于高风险表面，解析一次并连接到钉死的 IP，或者在前面放一个过滤代理（`request-filtering-agent` / `ssrf-req-filter`）。

## 输入验证模式

### 在边界的 Schema 验证

```typescript
import { z } from 'zod';

const CreateTaskSchema = z.object({
  title: z.string().min(1).max(200).trim(),
  description: z.string().max(2000).optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  dueDate: z.string().datetime().optional(),
});

// Validate at the route handler
app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid input',
        details: result.error.flatten(),
      },
    });
  }
  // result.data is now typed and validated
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

### 文件上传安全

```typescript
// Restrict file types and sizes
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

function validateUpload(file: UploadedFile) {
  if (!ALLOWED_TYPES.includes(file.mimetype)) {
    throw new ValidationError('File type not allowed');
  }
  if (file.size > MAX_SIZE) {
    throw new ValidationError('File too large (max 5MB)');
  }
  // Don't trust the file extension — check magic bytes if critical
}
```

## 分诊依赖审计结果

包管理器的 audit 报告的是已知公告；它们并不能证明一个包是可信的，也不能证明有漏洞的代码是可到达的。使用这个决策树：

```
The native package-manager audit reports a vulnerability
├── Severity: critical or high
│   ├── Is the vulnerable code reachable in runtime, build, test, or deployment paths?
│   │   ├── YES --> Fix immediately (update, patch, or replace the dependency)
│   │   └── NO (confirmed unused across those paths) --> Fix soon, but not a blocker
│   └── Is a fix available?
│       ├── YES --> Update to the patched version
│       └── NO --> Check for workarounds, consider replacing the dependency, or add to allowlist with a review date
├── Severity: moderate
│   ├── Reachable in production? --> Fix in the next release cycle
│   └── Dev-only? --> Fix when convenient, track in backlog
└── Severity: low
    └── Track and fix during regular dependency updates
```

**关键问题：**
- 有漏洞的函数真的在你的代码路径中被调用吗？
- 这个依赖是运行时依赖还是仅开发依赖？
- 结合你的部署上下文，这个漏洞是否可利用（例如，仅客户端应用中的服务端漏洞）？

当你推迟修复时，记录原因并设定一个复查日期。

### 供应链卫生

不要默认信任 npm，也不要拿最近的 manifest 当作安装根。按这个顺序做：

1. **找到安装边界和包管理器。** 使用拥有 lockfile 的工作区根，或者仅当独立嵌套项目位于该工作区之外时才使用它。在那里，交叉核对 `packageManager`（若存在）、lockfile 和 CI；在发现不一致或出现互相竞争的 lockfile 时停下来。钉死包管理器版本，并使用 `references/security-checklist.md` 中的矩阵。
2. **在首次执行前阻断依赖脚本。** 以禁用脚本或记录在案的默认拒绝（fail-closed）策略来引导安装，检查待执行的脚本源码，只批准最小必需的包，提交该策略，然后用干净的冻结/不可变安装来验证。绝不不加区分地批准脚本。

审计只能发现已知公告；它们捕获不到一个新变恶意或被域名仿冒的包。因此：

- **绝不自动应用强制的审计修复**（`npm audit fix --force` 或等价物）。预览修复方案、阅读变更日志，并测试每一个产生的升级；强制修复可能跨越声明的依赖范围。
- **在支持的地方验证注册表签名和来源**（`npm audit signatures`、`pnpm audit signatures`），并把缺失视为需要调查的信号，而不是被攻破的自动证明。
- **把新依赖、lockfile diff 和脚本策略变更放在一起评审**——所有权、维护情况、发布年龄、来源、传递依赖图，以及诸如 `cross-env` vs `crossenv` 的域名仿冒（OWASP **A06**、**LLM03**）。

## 速率限制

```typescript
import rateLimit from 'express-rate-limit';

// General API rate limit
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                   // 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
}));

// Stricter limit for auth endpoints
app.use('/api/auth/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,  // 10 attempts per 15 minutes
}));
```

## 密钥管理

```
.env files:
  ├── .env.example  → Committed (template with placeholder values)
  ├── .env          → NOT committed (contains real secrets)
  └── .env.local    → NOT committed (local overrides)

.gitignore must include:
  .env
  .env.local
  .env.*.local
  *.pem
  *.key
```

**提交前始终检查：**
```bash
# Check for accidentally staged secrets
git diff --cached | grep -i "password\|secret\|api_key\|token"
```

**如果密钥被提交过，就轮换它。** 删除那一行或重写历史是不够的——一旦它到达远端，就假定它已被攻破。先吊销并重新签发密钥，然后从历史中清除。

## 保护 AI / LLM 功能

如果你的应用调用 LLM——聊天机器人、摘要器、agent、RAG——它就继承了一个新的攻击面。把它映射到 [OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org/llm-top-10/)：

- **把模型的所有输出都当作不可信输入（LLM05：输出处理不当）。** 绝不把 LLM 输出直接传进 `eval`、SQL、shell、`innerHTML` 或文件路径。像对待原始用户输入一样验证和编码它。
- **假设提示词可能被劫持（LLM01：提示词注入）。** 上下文窗口中的不可信文本——一条用户消息、一个抓取的网页、一个 PDF——都可能携带指令。系统提示词不是安全边界；在代码中执行权限，而不是在提示词中。
- **把密钥和其他用户的数据挡在提示词之外（LLM02 / LLM07）。** 上下文中的任何内容都可能被原样回显。不要把 API 密钥、跨租户数据或完整系统提示词放在模型可能复述的地方。
- **约束工具和 agent 的权限（LLM06：过度代理）。** 把工具范围缩到最小，对破坏性或不可逆操作要求确认，并验证每一个工具参数。
- **限制消耗（LLM10：无界消耗）。** 封顶 token、请求速率和循环/递归深度，这样精心构造的输入就不能耗尽成本或拖垮系统。
- **隔离检索数据（LLM08：向量与嵌入弱点）。** 在 RAG 中，把向量库当作一条信任边界：按租户划分嵌入，这样一个人就检索不到另一个人的数据；并在索引前验证文档，这样投毒的内容就不能左右回答。

```typescript
// BAD: trusting model output as a command or as markup
const sql = await llm.generate(`Write SQL for: ${userQuestion}`);
await db.query(sql);                                   // arbitrary query execution
container.innerHTML = await llm.reply(userMessage);   // stored XSS, via the model

// GOOD: model output is data — parse defensively, then validate, then encode
let intent;
try {
  intent = CommandSchema.parse(JSON.parse(await llm.replyJson(userMessage)));
} catch {
  throw new ValidationError('unexpected model output'); // JSON.parse or schema failed
}
await runAllowlistedAction(intent.action, intent.params);
container.textContent = await llm.reply(userMessage);
```

## 安全评审清单

```markdown
### Authentication
- [ ] Passwords hashed with bcrypt/scrypt/argon2 (salt rounds ≥ 12)
- [ ] Session tokens are httpOnly, secure, sameSite
- [ ] Login has rate limiting
- [ ] Password reset tokens expire

### Authorization
- [ ] Every endpoint checks user permissions
- [ ] Users can only access their own resources
- [ ] Admin actions require admin role verification

### Input
- [ ] All user input validated at the boundary
- [ ] SQL queries are parameterized
- [ ] HTML output is encoded/escaped
- [ ] Server-side URL fetches are allowlisted (no SSRF to internal services)

### Data
- [ ] No secrets in code or version control
- [ ] Sensitive fields excluded from API responses
- [ ] PII encrypted at rest (if applicable)

### Infrastructure
- [ ] Security headers configured (CSP, HSTS, etc.)
- [ ] CORS restricted to known origins
- [ ] Dependencies audited for vulnerabilities
- [ ] Error messages don't expose internals

### Supply Chain
- [ ] One authoritative lockfile committed; CI uses that manager's frozen/immutable install
- [ ] Native audit triaged by reachability and fix risk; dependency install scripts blocked unless explicitly approved
- [ ] New dependencies reviewed (ownership, provenance, release age, transitive graph)

### AI / LLM (if used)
- [ ] Model output treated as untrusted (no eval/SQL/innerHTML/shell)
- [ ] Secrets and other users' data kept out of prompts
- [ ] Tool/agent permissions scoped; destructive actions require confirmation
```

## 参见

详细的安全检查清单和提交前验证步骤参见 `references/security-checklist.md`。

## 常见合理化借口

| 合理化借口 | 现实 |
|---|---|
| 「这是内部工具，安全无所谓」 | 内部工具也会被攻破。攻击者瞄准最薄弱的环节。 |
| 「我们以后再补安全」 | 安全返工比一开始就做难 10 倍。现在就加。 |
| 「没人会想着利用这个」 | 自动化扫描器会发现它。靠隐蔽来安全不是安全。 |
| 「框架会处理安全」 | 框架提供的是工具，不是保证。你仍然需要正确地使用它们。 |
| 「只是个原型而已」 | 原型会变成生产。安全习惯从第一天就要有。 |
| 「这里的威胁建模是小题大做」 | 花五分钟想「我会怎么攻击这个？」能防止那些事后没有任何控制措施能修补的设计缺陷。 |
| 「只是 LLM 输出而已，只是文本」 | 那段「文本」可以是一条 SQL 语句、一个 script 标签或一条 shell 命令。像对待任何不可信输入一样对待它。 |
| 「audit 通过了，所以这个依赖是安全的」 | 审计匹配的是已知公告。它检测不出一个新变恶意的包，也不会让未经评审的安装脚本变得安全可执行。 |

## 危险信号

- 用户输入直接传给数据库查询、shell 命令或 HTML 渲染
- 源代码或提交历史中的密钥
- 没有认证或授权检查的 API 端点
- 缺失 CORS 配置或通配符（`*`）来源
- 认证端点没有速率限制
- 向用户暴露堆栈跟踪或内部错误
- 带有已知严重漏洞的依赖、同一安装边界下互相竞争的 lockfile、不可复现的安装、或未经区分地批准的脚本
- 服务器在无白名单的情况下获取用户提供的 URL（SSRF）
- LLM/模型输出被传入查询、DOM、shell 或 `eval`
- 密钥、PII 或完整系统提示词被放进 LLM 上下文窗口

## 验证

在实现与安全相关的代码之后：

- [ ] 原生 audit 没有未缓解的可到达的 critical/high 发现；CI 保留权威 lockfile 并阻止未经评审的依赖脚本
- [ ] 源代码或 git 历史中没有密钥
- [ ] 所有用户输入都在系统边界验证
- [ ] 每个受保护的端点都检查了认证和授权
- [ ] 响应中存在安全响应头（用浏览器 DevTools 检查）
- [ ] 错误响应不暴露内部细节
- [ ] 认证端点启用了速率限制
- [ ] 服务器端 URL 获取已对照白名单验证（无 SSRF）
- [ ] LLM/模型输出在使用前已验证和编码（如果存在 AI 功能）
