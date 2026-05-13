#!/usr/bin/env bash
# claude-push-guard の push-guard.sh をドライランで検証。
# 9 ケース (block 5 + pass 4) を JSON で食わせ、exit code と
# stderr/stdout を確認する。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/hooks/push-guard.sh"
export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"

[ -x "$HOOK" ] || { echo "FAIL: $HOOK not found or not executable" >&2; exit 1; }

fail=0

# usage: assert_case <label> <expected_exit> <json_command>
assert_case() {
  local label="$1"; shift
  local expected="$1"; shift
  local input="$1"; shift
  local actual
  actual=$(printf '%s' "$input" | "$HOOK" >/dev/null 2>&1; echo $?)
  actual=$(echo "$actual" | tail -1)
  if [ "$actual" = "$expected" ]; then
    printf 'PASS  %-50s (exit=%s)\n' "$label" "$actual"
  else
    printf 'FAIL  %-50s expected=%s actual=%s\n' "$label" "$expected" "$actual" >&2
    fail=$((fail+1))
  fi
}

# ---- block (exit=2) ----
assert_case "git push"                       2 '{"tool_input":{"command":"git push origin main"}}'
assert_case "jj git push"                    2 '{"tool_input":{"command":"jj git push"}}'
assert_case "after &&"                       2 '{"tool_input":{"command":"jj commit -m foo && git push"}}'
assert_case "after | (pipe)"                 2 '{"tool_input":{"command":"echo y | git push"}}'
assert_case "git push --tags"                2 '{"tool_input":{"command":"git push --tags origin"}}'

# ---- pass (exit=0) ----
assert_case "just push"                      0 '{"tool_input":{"command":"just push"}}'
assert_case "pkf run push"                   0 '{"tool_input":{"command":"pkf run push"}}'
assert_case "commit message contains git push" 0 '{"tool_input":{"command":"jj describe -m \"docs: how to git push\""}}'
assert_case "gh pr create"                   0 '{"tool_input":{"command":"gh pr create"}}'

# ---- edge: empty / malformed input は fail-open (exit=0) ----
assert_case "empty stdin"                    0 ''
assert_case "no tool_input.command"          0 '{"tool_input":{}}'
assert_case "malformed json (fail-open)"     0 '{not-json'

if [ "$fail" -gt 0 ]; then
  echo "" >&2
  echo "FAILED: $fail case(s)" >&2
  exit 1
fi

echo ""
echo "All cases passed."
