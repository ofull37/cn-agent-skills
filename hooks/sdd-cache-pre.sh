#!/bin/bash
# sdd-cache-pre.sh — WebFetch 的 PreToolUse hook。
#
# 以 URL 为键的 HTTP 资源缓存。新鲜度通过 HTTP 验证器委托给源服务器；
# 304 Not Modified 是唯一允许从缓存提供内容的信号。
# 命中时，退出码为 2，并将缓存的正文写入 stderr，以便 Claude Code
# 将其代替 WebFetch 结果交付给 agent。否则退出码为 0。
#
# 没有 TTL：如果验证器没捕获到变化，就没有任何东西能捕获。没有
# ETag 或 Last-Modified 的条目永不缓存（无法重新验证）。
#
# 缓存的正文是提示词形状的（WebFetch 会通过模型做后处理），
# 所以键仅含 URL，原始提示词会在命中消息中浮出，
# 好让下一个 agent 判断先前的解读是否仍然适用。
#
# 依赖：jq、curl、shasum（或 sha256sum）。

set -euo pipefail

# 优雅降级：如果缺少任何依赖，放行这次获取。
command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# 调试日志：当设置了 SDD_CACHE_DEBUG=1，或哨兵文件
# 存在于 .claude/sdd-cache/.debug 时激活。用 `touch` / `rm` 切换。
dbg() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
  [ "${SDD_CACHE_DEBUG:-0}" = "1" ] || [ -f "$dir/.debug" ] || return 0
  mkdir -p "$dir"
  printf '%s [pre]  %s\n' "$(date -u +%FT%TZ)" "$*" >> "$dir/.debug.log"
}
dbg "fired"

URL=$(printf '%s' "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null || true)
if [ -z "$URL" ]; then dbg "no url in tool_input, exit"; exit 0; fi
dbg "url=$URL"

# 缓存键是 sha256(URL)，截断为 128 位。
hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

if [ ! -f "$CACHE_FILE" ]; then dbg "no cache file at $CACHE_FILE, exit"; exit 0; fi
dbg "cache file exists: $CACHE_FILE"

FETCHED_AT=$(jq -r '.fetched_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0)
ORIGINAL_PROMPT=$(jq -r '.prompt // empty' "$CACHE_FILE" 2>/dev/null || true)
ETAG=$(jq -r '.etag // empty' "$CACHE_FILE" 2>/dev/null || true)
LAST_MOD=$(jq -r '.last_modified // empty' "$CACHE_FILE" 2>/dev/null || true)

# 没有验证器意味着我们无法验证新鲜度——绝不从缓存提供内容。
if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "cached entry has no etag/last-modified, cannot revalidate, bypass"
  exit 0
fi

HEADERS=()
[ -n "$ETAG" ]     && HEADERS+=(-H "If-None-Match: $ETAG")
[ -n "$LAST_MOD" ] && HEADERS+=(-H "If-Modified-Since: $LAST_MOD")

STATUS=$(curl -sI -o /dev/null -w "%{http_code}" \
  --max-time 5 -L \
  "${HEADERS[@]}" \
  "$URL" 2>/dev/null || echo "000")
dbg "revalidation HEAD status=$STATUS"

if [ "$STATUS" != "304" ]; then
  dbg "not 304, letting WebFetch proceed"
  exit 0
fi

# 服务器确认内容未变。向 agent 提供缓存的副本。
CONTENT=$(jq -r '.content // empty' "$CACHE_FILE" 2>/dev/null || true)
if [ -z "$CONTENT" ]; then dbg "cache file has empty content field, bypass"; exit 0; fi
dbg "cache HIT, blocking WebFetch with ${#CONTENT} bytes of cached content"

VERIFIED_AT_ISO=$(date -u -r "$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "@$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "unknown")

# 用 printf 输出负载，使 $CONTENT 永远不会被 shell 解释
# （文档的代码示例中包含反引号、$vars 和反斜杠；未加引号的
# heredoc 会把它们当作命令替换处理）。
{
  printf '[sdd-cache] Cache hit for %s\n\n' "$URL"
  printf 'Revalidated via HTTP 304; unchanged since %s. Use the cached\n' "$VERIFIED_AT_ISO"
  printf 'content below as if WebFetch had just returned it.\n\n'
  if [ -n "$ORIGINAL_PROMPT" ]; then
    printf 'Original WebFetch prompt: "%s". If your angle differs, judge\n' "$ORIGINAL_PROMPT"
    printf 'whether this reading still covers it.\n\n'
  fi
  printf -- '----- BEGIN CACHED CONTENT -----\n'
  printf '%s\n' "$CONTENT"
  printf -- '----- END CACHED CONTENT -----\n'
} >&2
exit 2
