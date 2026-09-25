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

# Three further shapes returned success over a failing gate while no rule and
# no hook named them. A loop exits with the LAST iteration status, so every
# earlier failure is erased; /dev/null discards the line naming WHICH assertion
# failed, so even a correct rc leaves nothing to act on. The loop leg keys on
# the loop BODY invoking a gate, which is what keeps an ordinary loop legitimate.
gate_case "a loop over gates is blocked" \
          'for s in a b; do bash scripts/test-$s.sh >/dev/null 2>&1 && echo PASS || echo FAIL; done' 2
gate_case "a loop running bash -n over files is blocked" \
          'for f in *.sh; do bash -n "$f" || echo FAIL; done' 2
gate_case "a loop over a named build tool is blocked" \
          'for m in a b; do pytest tests/$m; done' 2
gate_case "but a loop whose body runs no gate is not" \
          'for f in docs/*.md; do grep -c THING "$f"; done' 0
gate_case "a gate redirected into /dev/null is blocked" \
          'bash scripts/test-fold.sh >/dev/null 2>&1; echo done' 2
gate_case "same with the &> spelling the normaliser strips" \
          'bash scripts/test-fold.sh &>/dev/null' 2
gate_case "but a gate redirected into a FILE is the documented remedy" \
          'bash scripts/test-fold.sh > out.txt 2>&1' 0
gate_case "and a non-gate silenced with /dev/null still passes" \
          'command -v shellcheck >/dev/null 2>&1 || echo missing' 0

# The || leg had the SAME defect the pipe leg was fixed for: its gap could not
# cross an `&`, so the idiomatic PASS/FAIL line -- gate && echo PASS || echo FAIL
# -- slipped past while the bare `gate || echo` form was caught. The fix that
# taught the pipe leg to cross `&` was never applied here.
gate_case "an intervening && no longer defeats the || leg" \
          'bash scripts/test-fold.sh && echo PASS || echo FAIL' 2
gate_case "same for a named build tool" \
          'pytest tests && echo ok || echo bad' 2
gate_case "but a cd prefix is still not masking" \
          'cd /tmp && bash scripts/test-fold.sh' 0
gate_case "nor is a guard that does not swallow the rc" \
          '[ -n "$x" ] && bash scripts/test-fold.sh' 0

printf '\n== sh-syntax-check fires on a broken .sh and only on .sh ==\n'
# FIFTH self-numbered recurrence of the apostrophe-in-a-single-quoted-program
# hazard, the last one costing a wall of 50 unrelated test failures before the
# shape was recognised. Prose in two instruction files and a gate covering ONE
# surface did not stop it, so it is a hook now. Unguarded for the same reason
# gate-pipe-guard is: a shell syntax error is never project-specific.
shcmd=$(jq -r '.hooks.PostToolUse[] | select(.matcher=="Write|Edit") | .hooks[] | select(.command|test("sh-syntax-check")) | .command' "$HOOKS_JSON")
printf '%s\n' '#!/bin/bash' "jq -r '.a # the row's own bounds' x" > "$UNMANAGED/broken.sh"
printf '%s\n' '#!/bin/bash' 'echo ok' > "$UNMANAGED/good.sh"
printf '%s\n' 'not shell at all: (' > "$UNMANAGED/notes.md"
sh_case() { # <label> <path> <want-rc>
  o=$(cd "$UNMANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$UNMANAGED" \
      bash -c "$shcmd" <<< "{\"tool_input\":{\"file_path\":$(jq -Rn --arg p "$2" '$p')}}" 2>&1); r=$?
  check "$1" "$r" "$3"
}
sh_case "a .sh that no longer parses is blocked" "$UNMANAGED/broken.sh" 2
sh_case "a .sh that parses is not" "$UNMANAGED/good.sh" 0
sh_case "a non-shell file is never checked" "$UNMANAGED/notes.md" 0
sh_case "a path that does not exist is silent" "$UNMANAGED/gone.sh" 0
o=$(cd "$UNMANAGED" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$UNMANAGED" \
    bash -c "$shcmd" <<< "{\"tool_input\":{\"file_path\":$(jq -Rn --arg p "$UNMANAGED/broken.sh" '$p')}}" 2>&1)
case "$o" in *apostrophe*) ok "  and names the commonest cause" ;; *) bad "  and names the commonest cause" ;; esac

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
