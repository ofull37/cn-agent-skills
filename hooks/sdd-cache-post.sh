#!/bin/bash
# sdd-cache-post.sh — WebFetch 的 PostToolUse hook。
#
# WebFetch 之后，将响应正文存储在 .claude/sdd-cache/<sha>.json 中，
# 并附上通过 HEAD 请求捕获的当前 ETag / Last-Modified，
# 以便 pre hook 在下一次获取时重新验证。
#
# 以 URL 为键。调用者的提示词作为元数据存储（不属于键的一部分），
# 这样未来的缓存命中可以显示是什么问题产生了这份缓存解读。
# 没有 ETag 或 Last-Modified 的条目不被缓存。
#
# 依赖：jq、curl、shasum（或 sha256sum）。

set -euo pipefail

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
  printf '%s [post] %s\n' "$(date -u +%FT%TZ)" "$*" >> "$dir/.debug.log"
}
dbg "fired, input=$(printf '%s' "$INPUT" | head -c 400)"

URL=$(printf '%s'    "$INPUT" | jq -r '.tool_input.url    // empty' 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
if [ -z "$URL" ]; then dbg "no url in tool_input, exit"; exit 0; fi
dbg "url=$URL prompt=$(printf '%s' "$PROMPT" | head -c 80)"

# WebFetch 的 tool_response 形状（截至 2026-04 的 Claude Code）：一个对象，
# 键为 bytes、code、codeText、durationMs、result、url——内容位于
# .result。其他键（.output / .text / .content / .body）作为
# 防御性回退保留，以防形状变化；如果都不匹配，jq 返回空。
# 字符串分支处理较旧的/自定义的集成。
TOOL_RESPONSE_TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_response | type' 2>/dev/null || echo "unknown")
dbg "tool_response type=$TOOL_RESPONSE_TYPE keys=$(printf '%s' "$INPUT" | jq -r 'try (.tool_response | keys | join(",")) catch "n/a"' 2>/dev/null)"

CONTENT=$(printf '%s' "$INPUT" | jq -r '
  if (.tool_response | type) == "object" then
    (.tool_response.result
     // .tool_response.output
     // .tool_response.text
     // .tool_response.content
     // .tool_response.body
     // empty)
  elif (.tool_response | type) == "string" then
    .tool_response
  else
    empty
  end
' 2>/dev/null || true)

if [ -z "$CONTENT" ]; then
  dbg "could not extract content from tool_response, exit (shape unknown)"
  exit 0
fi
dbg "extracted content bytes=${#CONTENT}"

# 必须与 pre hook 匹配：sha256(URL)，前 32 个十六进制字符。
hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

# 从源服务器捕获验证器。跟随重定向，使它们匹配
# agent 实际访问的 URL。去除 CR，让 awk 的段落模式
# 能识别重定向链上响应块之间的空行分隔符。
HEAD_OUT=$(curl -sI -L --max-time 5 "$URL" 2>/dev/null | tr -d '\r' || true)

# 只取最终响应的响应头（最后一个段落），避免拾取
# 中间 301/302 跳转的验证器。
FINAL_HEADERS=$(printf '%s' "$HEAD_OUT" | awk '
  BEGIN { RS = ""; last = "" }
  { last = $0 }
  END { print last }
')

extract_header() {
  local name="$1"
  printf '%s' "$FINAL_HEADERS" | awk -v h="$name" '
    BEGIN { FS = ":" }
    tolower($1) == tolower(h) {
      sub(/^[^:]*:[ \t]*/, "")
      sub(/[ \t]+$/, "")
      print
      exit
    }
  '
}

ETAG=$(extract_header "ETag")
LAST_MOD=$(extract_header "Last-Modified")
dbg "HEAD etag=$ETAG last_modified=$LAST_MOD"

if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "no validator from origin, removing any stale entry and exit"
  rm -f "$CACHE_FILE"
  exit 0
fi

NOW=$(date +%s)

TMP="${CACHE_FILE}.$$.tmp"
if jq -n \
  --arg url           "$URL" \
  --arg prompt        "$PROMPT" \
  --arg etag          "$ETAG" \
  --arg last_modified "$LAST_MOD" \
  --arg content       "$CONTENT" \
  --argjson fetched_at "$NOW" \
  '{url: $url, prompt: $prompt, etag: $etag, last_modified: $last_modified, content: $content, fetched_at: $fetched_at}' \
  > "$TMP"
then
  mv "$TMP" "$CACHE_FILE"
  dbg "wrote cache file $CACHE_FILE"
else
  rm -f "$TMP"
  dbg "jq failed, temp cleaned"
fi

exit 0
