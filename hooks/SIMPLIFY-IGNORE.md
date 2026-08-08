# simplify-ignore hook

`/code-simplify` 的块级保护。标记那些永远不应被简化的代码——模型将看不到它们。

## 设置

1. 标注你想要保护的代码块：

```js
/* simplify-ignore-start: perf-critical */
// manually unrolled XOR — 3x faster than a loop
result[0] = buf[0] ^ key[0];
result[1] = buf[1] ^ key[1];
result[2] = buf[2] ^ key[2];
result[3] = buf[3] ^ key[3];
/* simplify-ignore-end */
```

2. 将 hooks 添加到 `.claude/settings.json`：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh\"" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh\"" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh\"" }]
      }
    ]
  }
}
```

3. 运行 `/code-simplify` ——受保护的块会变成 `/* BLOCK_de115a1d: perf-critical */` 占位符。模型对周围代码进行推理，而看不到受保护的实现。

> **注意：** hook 会在 `.claude/.simplify-ignore-cache/` 中存储临时备份。确保该路径在你的 `.gitignore` 中。

## 工作原理

一个脚本，三个 hook 事件：

| 事件 | 动作 |
|---|---|
| `PreToolUse Read` | 备份文件，就地（in-place）将块替换为 `BLOCK_<hash>` 占位符 |
| `PostToolUse Edit\|Write` | 将占位符展开回真实代码，保存模型的改动，重新过滤 |
| `Stop` | 会话结束时从备份恢复所有文件 |

每个块都做内容哈希（通过 `shasum`/`sha1sum` 生成 8 位十六进制字符），因此即使模型复制或重排了占位符，往返也无歧义。缓存按项目隔离，以防止跨会话干扰。

## 标注语法

```js
/* simplify-ignore-start */           // basic — hides the block
/* simplify-ignore-start: reason */   // with reason — appears in placeholder
/* simplify-ignore-end */
```

任何注释风格都可用（`//`、`/*`、`#`、`<!--`）。支持每文件多个块以及单行块。占位符保留原始注释语法（例如 Python 用 `# BLOCK_xxx`，HTML 用 `<!-- BLOCK_xxx -->`）。

## 崩溃恢复

如果 Claude Code 崩溃而没有触发 Stop hook，磁盘上的文件可能仍带有 `BLOCK_<hash>` 占位符。要手动恢复：

```bash
echo '{}' | bash hooks/simplify-ignore.sh
```

备份存储在项目目录内的 `.claude/.simplify-ignore-cache/` 中。

## 已知局限

- **单行块会隐藏整行。** 如果 `simplify-ignore-start` 和 `simplify-ignore-end` 与其他代码出现在同一行，整行都会从模型中隐藏，而不仅仅是标注的部分。请为标注使用独立的行。
- **注释后缀检测只覆盖 `*/` 和 `-->`。** 使用非标准注释结束符的模板引擎（ERB 的 `%>`、Blade 的 `--}}`）可能产生不配对的占位符。请改用 `#` 或 `//` 风格的注释。
- **回退展开是渐进式的，而非精确的。** 如果模型改变了占位符的格式（例如改了原因文本），hook 会尝试渐次更简单的匹配：完整占位符 → 前缀+哈希+后缀 → 仅哈希。仅哈希的回退可能留下小的残留（例如多余的 `:` 或原因文本）。发生这种情况时会向 stderr 打印一条警告。
- **文件重命名会留下占位符。** 如果模型通过 shell 命令重命名或移动文件，新文件会保留 `BLOCK_<hash>` 占位符。会话停止时，原始代码会保存为 `<旧文件名>.recovered`。你必须手动将恢复的代码还原到新文件中。

## 要求

- `jq`、`shasum` 或 `sha1sum`（自动检测）、Bash 3.2+
