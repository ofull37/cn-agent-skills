# sdd-cache hook

[`source-driven-development`](../skills/source-driven-development/SKILL.md) 的跨会话引用缓存。在不削弱该技能「对照当前文档验证」保证的前提下，跳过冗余的 `WebFetch` 调用。

## 为什么

`source-driven-development` 会为每个框架相关的决策获取官方文档。跨会话处理同一个项目，意味着要一遍又一遍地获取相同的页面。将内容作为本地记忆缓存会违背该技能——文档会变，而过期的缓存会掩盖这一点。

这个 hook 将获取到的内容缓存在磁盘上，但**每次复用时都通过 HTTP `If-None-Match` / `If-Modified-Since` 与源服务器重新验证**。只有当服务器响应 `304 Not Modified` 时才从缓存提供内容，这是一次新鲜的验证——而非读取记忆。

## 设置

1. 将 hooks 添加到 `.claude/settings.json`（个人使用可加到 `.claude/settings.local.json`）：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/hooks/sdd-cache-pre.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/hooks/sdd-cache-post.sh\"",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

   `${CLAUDE_PROJECT_DIR}` 解析为你启动 Claude Code 的目录。当 hooks 位于同一项目内时，上面的片段有效。如果你把 `agent-skills` 安装在其他位置（例如作为共享插件放在 `~/agent-skills` 下），请把 `${CLAUDE_PROJECT_DIR}/hooks/...` 替换为每个脚本的绝对路径。

2. 确保 `.claude/sdd-cache/` 在你的 `.gitignore` 中（本仓库已包含）。

3. 像往常一样使用 `/source-driven-development`（或该技能）。无需改动技能或 agent 的工作流——缓存是透明的。

## 心智模型

以 URL 为键的 HTTP 资源缓存。新鲜度通过 `ETag` / `Last-Modified` 委托给源服务器；没有 TTL，键中不含提示词。

存储的正文不是原始 HTML——`WebFetch` 会用调用者的提示词让模型对每个响应做后处理，所以我们缓存的是某个 agent 对页面的解读。键保持仅 URL，以便跨会话复用读取；原始提示词作为元数据保留，并在命中消息中浮出，好让下一个 agent 判断先前的解读是否适用。

## 工作原理

每个 URL 一条缓存条目，以 JSON 形式存储在 `.claude/sdd-cache/<sha>.json` 中：

| 事件 | 动作 |
|---|---|
| `PreToolUse WebFetch` | 如果条目存在，发送带 `If-None-Match` / `If-Modified-Since` 的 `HEAD` 请求。收到 `304` 时，阻止该次获取，并通过 stderr 将缓存内容返回给 agent，原始提示词作为元数据浮出。否则放行该次获取。 |
| `PostToolUse WebFetch` | 捕获响应，发出 `HEAD` 请求记录当前的 `ETag` / `Last-Modified`，并存储 `{url, prompt, etag, last_modified, content, fetched_at}`。 |

**新鲜度规则：**

- 只有源服务器确认 `304 Not Modified` 时才会提供条目。
- 没有 `ETag` 或 `Last-Modified` 头的条目永不缓存——没有验证器，hook 之后就无法验证新鲜度，而缓存将意味着信任记忆。
- 缓存键是 `sha256(url)`。同一个 URL 用不同提示词请求会命中同一条目；缓存的正文反映的是首次获取时所用的提示词，该提示词会与命中一起显示，以便 agent 决定是复用还是手动重新获取。

**Agent 会看到什么：**

- 缓存命中：`WebFetch` 通过退出码 2 被阻止。Claude Code 将 hook 的 stderr 负载作为工具错误回传给 agent——这是缓存命中的预期信号，不是失败。负载以 `[sdd-cache] Cache hit for <url>` 为前缀，并将缓存的正文包裹在 `----- BEGIN CACHED CONTENT -----` / `----- END CACHED CONTENT -----` 标记之间，让 agent 可以像 `WebFetch` 刚返回它一样使用。
- 缓存未命中或过期：`WebFetch` 正常运行；结果被存储供下次使用。

技能本身保持不变。它继续遵循 `DETECT → FETCH → IMPLEMENT → CITE`。hook 只改变 `FETCH` 运行时底层发生的事。

## 本地测试

### 1. 直接冒烟测试脚本

```bash
# Simulate a PostToolUse payload: cache a page
echo '{
  "tool_input": {
    "url": "https://react.dev/reference/react/useActionState",
    "prompt": "extract the signature"
  },
  "tool_response": "useActionState(action, initialState) returns [state, formAction, isPending]"
}' | bash hooks/sdd-cache-post.sh

# Inspect the stored entry
ls .claude/sdd-cache/
cat .claude/sdd-cache/*.json | jq .

# Simulate the next PreToolUse on the same URL + prompt
echo '{
  "tool_input": {
    "url": "https://react.dev/reference/react/useActionState",
    "prompt": "extract the signature"
  }
}' | bash hooks/sdd-cache-pre.sh
echo "exit=$?"
```

预期结果：

- 第一条命令会在 `.claude/sdd-cache/` 下创建一个文件（仅当服务器返回了 `ETag` 或 `Last-Modified`）。
- 第二条命令在源服务器回复 `304` 时以退出码 `2` 结束并把缓存内容输出到 stderr，否则静默退出 `0`。

### 2. 在真实会话中端到端测试

1. 按上文所示，在 `.claude/settings.local.json` 中注册 hooks。
2. 在本仓库中启动一个 Claude Code 会话。
3. 让 agent 获取一个文档页面（例如「fetch `https://react.dev/reference/react/useActionState` and summarize」）。
4. 验证 `.claude/sdd-cache/` 下出现一个文件。
5. 让 agent 用相同的提示词再次获取同一个页面。
6. 验证第二次 `WebFetch` 被阻止，并返回缓存内容（在会话记录中可见，为一条带 `[sdd-cache]` 前缀的工具错误）。

### 3. 新鲜度验证

为了确认文档变更时缓存会失效，强制制造一次 `ETag` 不匹配。挑一个具体的条目——一旦缓存里不止一个文件，`*.json` 就不安全了：

```bash
# Pick the entry you want to corrupt (swap in the actual filename)
ENTRY=.claude/sdd-cache/e49c9f378670cfbb1d7d871b6dee16d9.json

# Patch its ETag to something the origin will not recognize
jq '.etag = "W/\"stale-etag-forced\""' "$ENTRY" > "$ENTRY.tmp" && mv "$ENTRY.tmp" "$ENTRY"

# Next PreToolUse should miss (server returns 200, not 304)
echo '{"tool_input":{"url":"...", "prompt":"..."}}' | bash hooks/sdd-cache-pre.sh
echo "exit=$?"   # expect 0 (fetch allowed through)
```

### 4. 调试

两个 hook 在调试模式开启时，会将带时间戳的事件写入 `.claude/sdd-cache/.debug.log`。用以下任一方式启用：

```bash
# Option A: env var (per-session)
SDD_CACHE_DEBUG=1 claude

# Option B: sentinel file (persistent)
mkdir -p .claude/sdd-cache && touch .claude/sdd-cache/.debug
# …disable with: rm .claude/sdd-cache/.debug
```

日志捕获 URL、检测到的 `tool_response` 形状、HEAD 状态，以及每次调用命中或未命中的原因。当缓存未命中看起来意外时很有用（通常是：源服务器停止发出验证器）。

## 已知局限

- **正文是提示词形状的。** 命中返回的是先前 agent 对页面的解读，原始提示词会浮出，以便当前 agent 决定它是否适用。如果不适用，删除 `.claude/sdd-cache/` 下对应的文件以强制重新获取。
- **每次缓存写入都要多花一次 HEAD。** Claude Code 不暴露 `WebFetch` 已经收到的响应头，所以 post hook 需要重新查询源服务器以捕获 `ETag` / `Last-Modified`。每次未命中多一次往返——这是保持它成为纯 hook、不做任何核心改动的代价。
- **没有 `ETag` 或 `Last-Modified` 的服务器永不缓存。** 大多数官方文档站点（react.dev、docs.djangoproject.com、developer.mozilla.org）会发出验证器。不发出的站点总是被重新获取。
- **行为异常的服务器可能返回错误的 `304`。** 那是需要诊断的服务器 bug，而不是需要防御的缓存不变量；我们不会用 TTL 来掩盖它。如果发现过期条目，删除它。
- **缓存是本地且按项目隔离的。** 没有团队级的共享缓存。要添加共享缓存需要带签名的内容寻址存储层，这超出范围。

## 要求

- `jq`
- `curl`
- `shasum` 或 `sha256sum`（自动检测）
- Bash 3.2+
