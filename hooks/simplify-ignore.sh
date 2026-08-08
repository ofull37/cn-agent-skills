#!/bin/bash
# simplify-ignore.sh — Read（PreToolUse）、Edit|Write（PostToolUse）、Stop 的 Hook
#
# PreToolUse Read   → 备份文件，就地（in-place）将块替换为 BLOCK_<hash>
# PostToolUse Edit  → 展开占位符，重新过滤，使文件保持隐藏
# PostToolUse Write → 展开占位符，重新过滤，使文件保持隐藏
# Stop              → 从备份恢复真实文件内容
#
# 会话激活期间，磁盘上的文件始终带有占位符。
# 真实内容（已应用模型的改动）存放在备份中。
#
# 依赖：jq、shasum 或 sha1sum（自动检测）

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "error: missing jq" >&2; exit 1
fi

CACHE="${CLAUDE_PROJECT_DIR:-.}/.claude/.simplify-ignore-cache"
if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# 解析 hook 输入——显式捕获错误，以免 set -e 在畸形 JSON 上
# 静默退出，并浮出一条有用的诊断信息。
parse_error=""
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || {
  parse_error="failed to parse .tool_name from hook input"
  TOOL_NAME=""
}
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || {
  parse_error="failed to parse .tool_input.file_path from hook input"
  FILE_PATH=""
}
if [ -n "$parse_error" ]; then
  printf 'Warning: %s (input: %.120s)\n' "$parse_error" "$INPUT" >&2
fi

hash_cmd() {
  if command -v shasum >/dev/null 2>&1; then shasum
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  else printf '%s\n' "error: missing shasum or sha1sum" >&2; exit 1; fi
}
file_id() { printf '%s' "$1" | hash_cmd | cut -c1-16; }
block_hash() { printf '%s' "$1" | hash_cmd | cut -c1-8; }
# 转义 glob 元字符，使 ${var/pattern/repl} 将 pattern 视为字面量。
# 对 Bash 3.2（macOS）必需，因为在那里引号不能抑制 PE 模式中的 glob。
escape_glob() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\*/\\*}"
  s="${s//\?/\\?}"
  s="${s//\[/\\[}"
  printf '%s' "$s"
}

# ── filter_file：将 simplify-ignore 块替换为 BLOCK_<hash> 占位符 ─
# 读取 $1（源），将过滤后的版本写入 $2（目标），将块保存到缓存。
# 找到块时返回 0，没有时返回 1。
filter_file() {
  local src="$1" dest="$2" fid="$3"
  : > "$dest"
  rm -f "$CACHE/${fid}".block.* "$CACHE/${fid}".reason.* "$CACHE/${fid}".prefix.* "$CACHE/${fid}".suffix.*

  local count=0 in_block=0 buf="" reason="" prefix="" suffix=""

  while IFS= read -r line || [ -n "$line" ]; do
    # 检查开始标记（不 fork——使用 bash case）
    if [ $in_block -eq 0 ]; then
      case "$line" in *simplify-ignore-start*)
        in_block=1
        buf="$line"
        # 提取注释前缀/后缀，以保留符合语言习惯的语法
        prefix="${line%%simplify-ignore-start*}"
        suffix=""
        case "$line" in *'*/'*) suffix=" */" ;; *'-->'*) suffix=" -->" ;; esac
        reason=$(printf '%s' "$line" | sed -n 's/.*simplify-ignore-start:[[:space:]]*//p' \
          | sed 's/[[:space:]]*\*\/.*$//' | sed 's/[[:space:]]*-->.*$//' | sed 's/[[:space:]]*$//')
        # 处理单行块（开始 + 结束在同一行）
        case "$line" in *simplify-ignore-end*)
          in_block=0
          # 立即写入单行块并跳到下一行，
          # 以免下面的结束标记检查再次触发
          local h; h=$(block_hash "$buf")
          count=$((count + 1))
          printf '%s' "$buf" > "$CACHE/${fid}.block.${h}"
          [ -n "$reason" ] && printf '%s' "$reason" > "$CACHE/${fid}.reason.${h}"
          printf '%s' "$prefix" > "$CACHE/${fid}.prefix.${h}"
          printf '%s' "$suffix" > "$CACHE/${fid}.suffix.${h}"
          if [ -n "$reason" ]; then
            printf '%s\n' "${prefix}BLOCK_${h}: ${reason}${suffix}" >> "$dest"
          else
            printf '%s\n' "${prefix}BLOCK_${h}${suffix}" >> "$dest"
          fi
          buf=""; reason=""; prefix=""; suffix=""
          continue
          ;; *)
          continue
          ;;
        esac
      ;; esac
    fi
    # 累积块内容
    if [ $in_block -eq 1 ]; then
      buf="${buf}
${line}"
    fi
    # 检查结束标记
    case "$line" in *simplify-ignore-end*)
      if [ $in_block -eq 1 ]; then
        local h; h=$(block_hash "$buf")
        count=$((count + 1))
        printf '%s' "$buf" > "$CACHE/${fid}.block.${h}"
        [ -n "$reason" ] && printf '%s' "$reason" > "$CACHE/${fid}.reason.${h}"
        printf '%s' "$prefix" > "$CACHE/${fid}.prefix.${h}"
        printf '%s' "$suffix" > "$CACHE/${fid}.suffix.${h}"
        if [ -n "$reason" ]; then
          printf '%s\n' "${prefix}BLOCK_${h}: ${reason}${suffix}" >> "$dest"
        else
          printf '%s\n' "${prefix}BLOCK_${h}${suffix}" >> "$dest"
        fi
        in_block=0; buf=""; reason=""; prefix=""; suffix=""
        continue
      fi
      ;;
    esac
    [ $in_block -eq 0 ] && printf '%s\n' "$line" >> "$dest"
  done < "$src"

  # 未闭合的块 → 原样写出
  if [ $in_block -eq 1 ] && [ -n "$buf" ]; then
    printf 'Warning: unclosed simplify-ignore-start in %s (block not hidden)\n' "$src" >&2
    printf '%s\n' "$buf" >> "$dest"
  fi

  # 保留源文件的结尾换行状态
  if [ -s "$dest" ] && [ -s "$src" ] && [ -n "$(tail -c 1 "$src")" ]; then
    perl -pe 'chomp if eof' "$dest" > "${dest}.nnl" && \
      cat "${dest}.nnl" > "$dest" && rm -f "${dest}.nnl"
  fi

  [ $count -gt 0 ] && return 0 || return 1
}

# ── Stop：从备份恢复所有文件 ───────────────────────────────────────
if [ -z "$TOOL_NAME" ]; then
  [ -d "$CACHE" ] || exit 0
  for bak in "$CACHE"/*.bak; do
    [ -f "$bak" ] || continue
    fid="${bak##*/}"; fid="${fid%.bak}"
    pathfile="$CACHE/${fid}.path"
    [ -f "$pathfile" ] || { rm -f "$bak"; continue; }
    orig=$(cat "$pathfile")
    if [ -f "$orig" ]; then
      cat "$bak" > "$orig"
      rm -f "$bak" "$pathfile" "$CACHE/${fid}".block.* "$CACHE/${fid}".reason.* "$CACHE/${fid}".prefix.* "$CACHE/${fid}".suffix.*
      rmdir "$CACHE/${fid}.lock" 2>/dev/null
    else
      # 文件被移动/删除——将备份保存为 .recovered，不要销毁它
      mkdir -p "$(dirname "${orig}.recovered")"
      mv "$bak" "${orig}.recovered"
      rm -f "$pathfile" "$CACHE/${fid}".block.* "$CACHE/${fid}".reason.* "$CACHE/${fid}".prefix.* "$CACHE/${fid}".suffix.*
      rmdir "$CACHE/${fid}.lock" 2>/dev/null
      printf 'Warning: %s was moved/deleted. Recovered original to %s.recovered\n' "$orig" "$orig" >&2
    fi
  done
  # 清理孤立锁（已创建但在备份前崩溃）
  for lockdir in "$CACHE"/*.lock; do
    [ -d "$lockdir" ] || continue
    rmdir "$lockdir" 2>/dev/null
  done
  exit 0
fi

[ -z "$FILE_PATH" ] && exit 0

# ── PreToolUse Read：就地过滤 ──────────────────────────────────────────
if [ "$TOOL_NAME" = "Read" ]; then
  [ -f "$FILE_PATH" ] || exit 0
  case "$(basename "$FILE_PATH")" in simplify-ignore*|SIMPLIFY-IGNORE*) exit 0 ;; esac

  mkdir -p "$CACHE"
  ID=$(file_id "$FILE_PATH")

  # 如果备份已存在，说明文件已被过滤——跳过
  [ -f "$CACHE/${ID}.bak" ] && exit 0

  grep -q 'simplify-ignore-start' -- "$FILE_PATH" || exit 0

  # 原子锁：如果另一个会话与我们竞争，mkdir 会失败
  if ! mkdir "$CACHE/${ID}.lock" 2>/dev/null; then
    # 锁已存在——仅在过期时回收（>60 秒，无备份 = 崩溃遗留）
    if [ ! -f "$CACHE/${ID}.bak" ] && \
       [ -n "$(find "$CACHE/${ID}.lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
      rmdir "$CACHE/${ID}.lock" 2>/dev/null || true
      mkdir "$CACHE/${ID}.lock" 2>/dev/null || exit 0
    else
      exit 0
    fi
  fi

  # 备份原始文件（保留结尾换行状态）
  cp -p "$FILE_PATH" "$CACHE/${ID}.bak" 2>/dev/null || cp "$FILE_PATH" "$CACHE/${ID}.bak"
  printf '%s' "$FILE_PATH" > "$CACHE/${ID}.path"

  # 就地过滤（cat > 保留 inode 和权限）
  FILTERED="$CACHE/${ID}.$$.tmp"
  rm -f "$FILTERED"
  if filter_file "$FILE_PATH" "$FILTERED" "$ID"; then
    cat "$FILTERED" > "$FILE_PATH"
    rm -f "$FILTERED"
  else
    rm -f "$FILTERED" "$CACHE/${ID}.bak" "$CACHE/${ID}.path"
    rmdir "$CACHE/${ID}.lock" 2>/dev/null
  fi
  exit 0
fi

# ── PostToolUse Edit|Write：展开，然后重新过滤 ────────────────────────────
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  ID=$(file_id "$FILE_PATH")
  [ -f "$CACHE/${ID}.bak" ] || exit 0
  ls "$CACHE/${ID}".block.* >/dev/null 2>&1 || exit 0

  # 展开占位符，保留模型在它们周围添加的任何内联代码
  EXPANDED="$CACHE/${ID}.$$.expanded"
  rm -f "$EXPANDED"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *BLOCK_*)
      # 展开这一行上的所有占位符（支持每行多个）
      for bf in "$CACHE/${ID}".block.*; do
        [ -f "$bf" ] || continue
        h="${bf##*.}"
        case "$line" in *"BLOCK_${h}"*)
          # 重建确切的占位符模式
          bp=""; bs=""; br=""
          [ -f "$CACHE/${ID}.prefix.${h}" ] && bp=$(cat "$CACHE/${ID}.prefix.${h}")
          [ -f "$CACHE/${ID}.suffix.${h}" ] && bs=$(cat "$CACHE/${ID}.suffix.${h}")
          [ -f "$CACHE/${ID}.reason.${h}" ] && br=$(cat "$CACHE/${ID}.reason.${h}")
          if [ -n "$br" ]; then
            placeholder="${bp}BLOCK_${h}: ${br}${bs}"
          else
            placeholder="${bp}BLOCK_${h}${bs}"
          fi
          block_content=$(cat "$bf"; printf x); block_content="${block_content%x}"
          # 转义模式中的 glob 元字符（* ? [ \）
          esc_placeholder=$(escape_glob "$placeholder")
          # Bash 原生替换（// = 全局替换）：替换占位符，保留周围代码
          line="${line//$esc_placeholder/$block_content}"
          # 回退：如果模型改了原因文本，尝试去掉原因
          # （仅当 BLOCK_hash 仍然存在且不在原始块内容中时才触发）
          case "$block_content" in *"BLOCK_${h}"*) ;; *)
            case "$line" in *"BLOCK_${h}"*)
              printf 'Warning: placeholder BLOCK_%s was modified by model, using fuzzy match\n' "$h" >&2
              esc_fuzzy=$(escape_glob "${bp}BLOCK_${h}${bs}")
              line="${line//$esc_fuzzy/$block_content}"
              # 最后手段：只匹配哈希令牌
              case "$line" in *"BLOCK_${h}"*)
                line="${line//BLOCK_${h}/$block_content}"
              ;; esac
            ;; esac
          ;; esac
        ;; esac
      done
    ;; esac
    printf '%s\n' "$line" >> "$EXPANDED"
  done < "$FILE_PATH"
  # 保留结尾换行状态
  if [ -s "$EXPANDED" ] && [ -s "$FILE_PATH" ] && [ -n "$(tail -c 1 "$FILE_PATH")" ]; then
    perl -pe 'chomp if eof' "$EXPANDED" > "${EXPANDED}.nnl" && \
      cat "${EXPANDED}.nnl" > "$EXPANDED" && rm -f "${EXPANDED}.nnl"
  fi
  # 如果模型完全删除了一个受保护块，发出警告
  for bf in "$CACHE/${ID}".block.*; do
    [ -f "$bf" ] || continue
    bh="${bf##*.}"
    # 展开后，块会以原始代码的形式出现（simplify-ignore-start）。
    # 如果展开后的代码和占位符都不在 EXPANDED 中，说明它被删除了。
    if ! grep -qF "BLOCK_${bh}" "$EXPANDED" 2>/dev/null; then
      # 取块的第一行，检查它是否被展开回去
      first_line=$(head -1 "$bf")
      if ! grep -qF "$first_line" "$EXPANDED" 2>/dev/null; then
        printf 'Warning: protected block BLOCK_%s was deleted by model\n' "$bh" >&2
      fi
    fi
  done
  # 保留 inode 和权限
  cat "$EXPANDED" > "$FILE_PATH"
  rm -f "$EXPANDED"

  # 将展开后的版本保存为新备份（这是带模型改动的「真实」文件）
  cp "$FILE_PATH" "$CACHE/${ID}.bak"

  # 就地重新过滤，使磁盘上的文件保持带占位符
  FILTERED="$CACHE/${ID}.$$.tmp"
  rm -f "$FILTERED"
  if filter_file "$FILE_PATH" "$FILTERED" "$ID"; then
    cat "$FILTERED" > "$FILE_PATH"
    rm -f "$FILTERED"
  fi

  exit 0
fi
