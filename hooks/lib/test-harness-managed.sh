#!/usr/bin/env bash
#
# Tests for harness-managed.sh and for the guard actually being wired into the
# hooks that need it. Run from anywhere:
#   bash hooks/lib/test-harness-managed.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
GUARD="${HERE}/harness-managed.sh"
HOOKS_JSON="${HERE}/../hooks.json"
PLUGIN_ROOT=$(cd -- "${HERE}/../.." && pwd)
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

printf '\n== guard: detection ==\n'
d=$(mktemp -d); mkdir -p "$d/ai-docs"
CLAUDE_PROJECT_DIR="$d" bash "$GUARD"; check "ai-docs/ present -> managed" "$?" "0"
d=$(mktemp -d); : > "$d/AGENTS.md"
CLAUDE_PROJECT_DIR="$d" bash "$GUARD"; check "AGENTS.md present -> managed" "$?" "0"
d=$(mktemp -d)
CLAUDE_PROJECT_DIR="$d" bash "$GUARD"; check "neither marker -> unmanaged" "$?" "1"
d=$(mktemp -d); mkdir -p "$d/sub"; : > "$d/AGENTS.md"
( cd "$d/sub" && unset CLAUDE_PROJECT_DIR && bash "$GUARD" ); check "falls back to PWD when no project dir" "$?" "1"

printf '\n== guarded hooks no-op in an unmanaged repo ==\n'
# The identity is pinned per-invocation: a sandbox with no global git identity
# makes `commit --allow-empty` fail, and the suite then runs its checks against
# a repo with no HEAD while still reporting green -- a setup step failing
# silently is exactly what the fixtures are supposed to rule out.
UNMANAGED=$(mktemp -d); git -C "$UNMANAGED" init -q -b main
git -C "$UNMANAGED" -c user.email=t@t -c user.name=t commit -q --allow-empty -m x

# branch-protection would otherwise BLOCK this commit on the default branch.
cmd=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.statusMessage|test("branch before")) | .command' "$HOOKS_JSON")
out=$(cd "$UNMANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$UNMANAGED" \
      bash -c "$cmd" <<< '{"tool_input":{"command":"git commit -m x"}}' 2>&1); rc=$?
check "branch-protection allows commit in unmanaged repo" "$rc" "0"
check "  and stays silent" "$out" ""

MANAGED=$(mktemp -d); git -C "$MANAGED" init -q -b main
git -C "$MANAGED" -c user.email=t@t -c user.name=t commit -q --allow-empty -m x
mkdir -p "$MANAGED/ai-docs"
out=$(cd "$MANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$MANAGED" \
      bash -c "$cmd" <<< '{"tool_input":{"command":"git commit -m x"}}' 2>&1); rc=$?
check "branch-protection still blocks in a managed repo" "$rc" "2"
case "$out" in *BLOCKED*) ok "  and explains why" ;; *) bad "  and explains why" ;; esac

printf '\n== unguarded method hooks fire everywhere ==\n'
cmd=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.statusMessage|test("masked gates")) | .command' "$HOOKS_JSON")
out=$(cd "$UNMANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$UNMANAGED" \
      bash -c "$cmd" <<< '{"tool_input":{"command":"pytest tests | tail -20"}}' 2>&1); rc=$?
check "gate-pipe-guard blocks even in an unmanaged repo" "$rc" "2"

# A suite made of shell scripts was invisible to this guard: the gate anchor
# listed build tools by name and `bash` was not among them, so in a repository
# whose every gate is `bash scripts/test-*.sh` the hook guarded nothing at all.
# The second arm keys on a shell interpreter invoking a SCRIPT FILE whose
# basename carries a gate word -- never on a bare interpreter, which is what
# keeps `bash -c ... | jq` legitimate.
gate_case() { # <label> <command> <want-rc>
  o=$(cd "$UNMANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$UNMANAGED" \
      bash -c "$cmd" <<< "{\"tool_input\":{\"command\":$(jq -Rn --arg c "$2" '$c')}}" 2>&1); r=$?
  check "$1" "$r" "$3"
}
gate_case "a shell test suite piped into tail is blocked" \
          'bash scripts/test-session-events.sh 2>&1 | tail -3' 2
gate_case "a shell check script fused to || echo is blocked" \
          'bash scripts/check-references.sh || echo ok' 2
gate_case "a lint script piped into grep is blocked" \
          'sh tools/lint-all.sh | grep FAIL' 2
gate_case "but a bare interpreter with -c is not a gate" \
          "bash -c 'printf hi' | jq ." 0
gate_case "nor is a non-gate script piped into jq" \
          'bash scripts/session-events.sh x.jsonl | jq .' 0
gate_case "and the suite run bare is not blocked" \
          'bash scripts/test-session-events.sh' 0

# A redirection before the pipe defeated the anchor entirely: the gap between
# the gate word and the pipe excludes `&`, so `2>&1` -- the most ordinary way
# anyone pipes a gate -- could not be crossed. This was blind for EVERY
# language, not only for shell suites, so it is tested on a build tool too.
# Redirections are now normalised out of the command before matching.
gate_case "a redirection before the pipe no longer hides a gate" \
          'pytest tests 2>&1 | tail -20' 2
gate_case "same for a shell suite" \
          'bash scripts/test-fold.sh 2>&1 | grep FAIL' 2
gate_case "and >&2 in a non-gate command still passes" \
          'printf oops >&2 | cat' 0

printf '\n== SessionStart emits nothing when unmanaged, JSON when managed ==\n'
cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON")
out=$(cd "$UNMANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$UNMANAGED" bash -c "$cmd" 2>&1)
check "silent when unmanaged" "$out" ""
out=$(cd "$MANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$MANAGED" bash -c "$cmd" 2>&1)
printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1 \
  && ok "valid JSON when managed" || bad "valid JSON when managed"

printf '\n== every guarded hook names the guard ==\n'
for msg in "branch before" "Auto-staging" "Co-Authored-By" "Propagation Rule" "PR body sync"; do
  c=$(jq -r --arg m "$msg" '[.hooks[][] | .hooks[]? | select(.statusMessage? // "" | test($m)) | .command] | first' "$HOOKS_JSON")
  case "$c" in *harness-managed.sh*) ok "guarded: $msg" ;; *) bad "guarded: $msg" ;; esac
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
