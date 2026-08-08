#!/bin/bash
# simplify-ignore-test.sh — simplify-ignore hook 的测试
#
# 通过从 hook 中提取函数定义来练习 filter_file。
# 运行：bash hooks/simplify-ignore-test.sh

set -euo pipefail

PASS=0 FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export CACHE="$TMPDIR/cache"
mkdir -p "$CACHE"

# 提取我们需要的函数定义
hash_cmd() {
  if command -v shasum >/dev/null 2>&1; then shasum
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  else printf '%s\n' "error: missing shasum or sha1sum" >&2; exit 1; fi
}
file_id() { printf '%s' "$1" | hash_cmd | cut -c1-16; }
block_hash() { printf '%s' "$1" | hash_cmd | cut -c1-8; }
escape_glob() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\*/\\*}"
  s="${s//\?/\\?}"
  s="${s//\[/\\[}"
  printf '%s' "$s"
}

# 从 hook 脚本中提取 filter_file（第 59 行 "filter_file()" 到第 142 行结束大括号）
eval "$(sed -n '/^filter_file()/,/^}/p' hooks/simplify-ignore.sh)"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s\n' "$label" >&2
    printf '    expected: %s\n' "$(printf '%s' "$expected" | cat -v)" >&2
    printf '    actual:   %s\n' "$(printf '%s' "$actual" | cat -v)" >&2
  fi
}

# ── 测试 1：单行块正好产生一个占位符 ────────────
printf 'Test 1: Single-line block (start+end on same line)\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/single-line.js"
DEST="$TMPDIR/single-line-filtered.js"
cat > "$SRC" <<'EOF'
const a = 1;
/* simplify-ignore-start */ const secret = 42; /* simplify-ignore-end */
const b = 2;
EOF

FID="test_single"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "exactly one placeholder line" "1" "$placeholder_count"
assert_eq "line before block preserved" "1" "$(grep -c 'const a = 1' "$DEST")"
assert_eq "line after block preserved" "1" "$(grep -c 'const b = 2' "$DEST")"

block_files=$(ls "$CACHE/${FID}".block.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "one block file in cache" "1" "$block_files"

block_content=$(cat "$CACHE/${FID}".block.*)
assert_eq "block content matches" \
  "/* simplify-ignore-start */ const secret = 42; /* simplify-ignore-end */" \
  "$block_content"

# ── 测试 2：多行块 ─────────────────────────────────────────────
printf '\nTest 2: Multi-line block\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/multi-line.js"
DEST="$TMPDIR/multi-line-filtered.js"
cat > "$SRC" <<'EOF'
const a = 1;
// simplify-ignore-start
const secret1 = 42;
const secret2 = 99;
// simplify-ignore-end
const b = 2;
EOF

FID="test_multi"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "exactly one placeholder for multi-line block" "1" "$placeholder_count"

output_lines=$(wc -l < "$DEST" | tr -d ' ')
assert_eq "output has 3 lines (before + placeholder + after)" "3" "$output_lines"

# ── 测试 3：一个文件中的多个块 ──────────────────────────────────
printf '\nTest 3: Multiple blocks in one file\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/multi-block.js"
DEST="$TMPDIR/multi-block-filtered.js"
cat > "$SRC" <<'EOF'
line1
// simplify-ignore-start
blockA
// simplify-ignore-end
line2
// simplify-ignore-start
blockB
// simplify-ignore-end
line3
EOF

FID="test_multiblock"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "two placeholders for two blocks" "2" "$placeholder_count"

block_files=$(ls "$CACHE/${FID}".block.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "two block files in cache" "2" "$block_files"

# ── 测试 4：原因字符串被保留 ──────────────────────────────────────
printf '\nTest 4: Reason string in placeholder\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/reason.js"
DEST="$TMPDIR/reason-filtered.js"
cat > "$SRC" <<'EOF'
// simplify-ignore-start: perf-critical
hot_loop();
// simplify-ignore-end
EOF

FID="test_reason"
filter_file "$SRC" "$DEST" "$FID"

assert_eq "placeholder includes reason" "1" "$(grep -c 'perf-critical' "$DEST")"

reason_files=$(ls "$CACHE/${FID}".reason.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "reason file saved" "1" "$reason_files"
assert_eq "reason content" "perf-critical" "$(cat "$CACHE/${FID}".reason.*)"

# ── 测试 5：结尾换行保留 ────────────────────────────────
printf '\nTest 5: Trailing newline preservation\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/no-trailing-nl.js"
DEST="$TMPDIR/no-trailing-nl-filtered.js"
printf 'line1\n// simplify-ignore-start\nsecret\n// simplify-ignore-end' > "$SRC"

FID="test_trail"
filter_file "$SRC" "$DEST" "$FID"

# 源文件没有结尾换行；目标文件也应没有结尾换行
src_has_nl=$(tail -c 1 "$SRC" | wc -l | tr -d ' ')
dest_has_nl=$(tail -c 1 "$DEST" | wc -l | tr -d ' ')
assert_eq "dest preserves no-trailing-newline from source" "$src_has_nl" "$dest_has_nl"

# ── 测试 6：无块 → 返回 1 ────────────────────────────────────────
printf '\nTest 6: No blocks returns 1\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/no-blocks.js"
DEST="$TMPDIR/no-blocks-filtered.js"
cat > "$SRC" <<'EOF'
const a = 1;
const b = 2;
EOF

FID="test_noblocks"
rc=0
filter_file "$SRC" "$DEST" "$FID" || rc=$?
assert_eq "returns 1 when no blocks found" "1" "$rc"

# ── 测试 7：未闭合的块发出警告并写出 ─────────────────────
printf '\nTest 7: Unclosed block\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/unclosed.js"
DEST="$TMPDIR/unclosed-filtered.js"
cat > "$SRC" <<'EOF'
line1
// simplify-ignore-start
orphan code
EOF

FID="test_unclosed"
stderr_out=$(filter_file "$SRC" "$DEST" "$FID" 2>&1) || true
assert_eq "warning emitted for unclosed block" "1" "$(printf '%s' "$stderr_out" | grep -c 'unclosed')"
assert_eq "orphan code flushed to output" "1" "$(grep -c 'orphan code' "$DEST")"

# ── 测试 8：带原因的单行块 ────────────────────────────────
printf '\nTest 8: Single-line block with reason\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/single-reason.js"
DEST="$TMPDIR/single-reason-filtered.js"
cat > "$SRC" <<'EOF'
before
/* simplify-ignore-start: hot-path */ x = compute(); /* simplify-ignore-end */
after
EOF

FID="test_single_reason"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "exactly one placeholder for single-line+reason" "1" "$placeholder_count"
assert_eq "reason in placeholder" "1" "$(grep -c 'hot-path' "$DEST")"

# ── 测试 9：HTML 注释语法 ──────────────────────────────────────────
printf '\nTest 9: HTML comment syntax\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/html.html"
DEST="$TMPDIR/html-filtered.html"
cat > "$SRC" <<'EOF'
<div>
<!-- simplify-ignore-start -->
<secret-component />
<!-- simplify-ignore-end -->
</div>
EOF

FID="test_html"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "HTML block replaced" "1" "$placeholder_count"
assert_eq "HTML suffix preserved" "1" "$(grep -c '\-\->' "$DEST")"

# ── 测试 10：JSON 解析错误警告 ──────────────────────────────────
printf '\nTest 10: Malformed JSON input produces warning\n'

# 没有 jq 时，hook 的守卫会在解析输入之前退出。断言这台机器
# 能走到的分支（与 session-start-test.sh 同样的模式）。
warning_out=$(echo 'NOT_JSON{{{' | bash hooks/simplify-ignore.sh 2>&1) || true
if command -v jq >/dev/null 2>&1; then
  assert_eq "warning on bad JSON" "1" "$(printf '%s' "$warning_out" | grep -c 'Warning.*failed to parse')"
else
  assert_eq "missing-jq guard surfaced" "1" "$(printf '%s' "$warning_out" | grep -c 'error: missing jq')"
fi

# ── 汇总 ──────────────────────────────────────────────────────────────
printf '\n══════════════════════════════════════════\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
