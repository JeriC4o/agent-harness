#!/usr/bin/env bash
#
# Suite for scripts/check-instruction-size.sh. Each leg builds a throwaway git
# tree and asserts the exit status together with the line that proves why.

set -uo pipefail

GATE="$(cd -- "$(dirname -- "$0")" && pwd)/check-instruction-size.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in output" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3] in output" ;; *) ok "$1" ;; esac; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM
D="$T/t"

# fill <file> <chars> [<char>] -- exactly <chars> characters, no newline.
fill() { mkdir -p "$(dirname -- "$1")"; python3 -c 'import sys; sys.stdout.write(sys.argv[2] * int(sys.argv[1]))' "$2" "${3:-a}" > "$1"; }
tree() {
  rm -rf "$D"; mkdir -p "$D"; git -C "$D" init -q
  fill "$D/agents/a.md" 100
  git -C "$D" add -A
}
run() { OUT=$(bash "$GATE" --root "$1" 2>&1); RC=$?; }

printf '\n== clean tree ==\n'
tree; run "$D"
check "a small whole-load file -> rc 0" "$RC" "0"
has "  verdict and count" "$OUT" "verdict=clean files=1"

printf '\n== the warning band and the cap, at their edges ==\n'
tree; fill "$D/agents/a.md" 34999; git -C "$D" add -A; run "$D"
check "34,999 chars -> rc 0" "$RC" "0"
has "  headroom reported" "$OUT" "headroom=1"
tree; fill "$D/skills/s/SKILL.md" 35000; git -C "$D" add -A; run "$D"
check "35,000 chars -> rc 1" "$RC" "1"
has "  named as inside the band" "$OUT" "skills/s/SKILL.md: 35000 chars -- inside the 35000-39999 warning band"
tree; fill "$D/AGENTS.md" 40000; git -C "$D" add -A; run "$D"
check "40,000 chars -> rc 1" "$RC" "1"
has "  named as over the cap" "$OUT" "AGENTS.md: 40000 chars -- over the 40000 cap"

printf '\n== characters, not bytes ==\n'
tree; fill "$D/agents/a.md" 20000 "—"; git -C "$D" add -A; run "$D"
check "20,000 three-byte characters (60,000 bytes) -> rc 0" "$RC" "0"

printf '\n== the whole-load class, and only it ==\n'
for p in CLAUDE.md CLAUDE.local.md .claude/agents/x.md .claude/skills/s/SKILL.md \
         ai-docs/context.md docs/agents-method.md templates/project/AGENTS.md \
         templates/project/CLAUDE.md templates/project/ai-docs/context.md; do
  tree; fill "$D/$p" 36000; git -C "$D" add -A; run "$D"
  check "$p at 36,000 -> rc 1" "$RC" "1"
done
for p in docs/workflow.md docs/templates/progress-format.md skills/s/reference.md rules/r.md \
         agents/sub/a.md skills/s/sub/SKILL.md; do
  tree; fill "$D/$p" 60000; git -C "$D" add -A; run "$D"
  check "$p at 60,000 is reached by link -> rc 0" "$RC" "0"
done

printf '\n== an untracked file is read, an ignored one is not ==\n'
tree; fill "$D/agents/new.md" 36000; run "$D"
check "untracked, unignored -> rc 1" "$RC" "1"
tree; printf 'agents/new.md\n' > "$D/.gitignore"; fill "$D/agents/new.md" 36000; run "$D"
check "ignored -> rc 0" "$RC" "0"

printf '\n== a tracked file deleted from disk is skipped, not a cannot-run ==\n'
tree; fill "$D/agents/b.md" 10; git -C "$D" add -A; rm "$D/agents/b.md"; run "$D"
check "deleted but still in the index -> rc 0" "$RC" "0"

printf '\n== CRLF counts two characters, as wc -m does ==\n'
tree; python3 -c 'import sys; sys.stdout.write("a\r\n" * 12000)' > "$D/agents/a.md"; git -C "$D" add -A; run "$D"
check "12,000 CRLF lines = 36,000 chars -> rc 1" "$RC" "1"

printf '\n== cannot run is not a pass ==\n'
tree; git -C "$D" rm -qf agents/a.md; run "$D"
check "no whole-load file -> rc 2" "$RC" "2"
has "  and says so" "$OUT" "verdict=cannot-run"
tree; printf '\377\376' > "$D/agents/b.md"; git -C "$D" add -A; run "$D"
check "an undecodable whole-load file -> rc 2" "$RC" "2"
mkdir -p "$T/plain"; run "$T/plain"
check "not a git tree -> rc 2" "$RC" "2"
tree; sed "s/^import /raise SystemExit(1)  # import /" "$GATE" > "$T/crash.sh"
cmp -s "$GATE" "$T/crash.sh" && bad "the crash mutant did not apply"
OUT=$(bash "$T/crash.sh" --root "$D" 2>&1); RC=$?
check "a body that ends without a verdict -> rc 2" "$RC" "2"
OUT=$(bash "$GATE" --bogus 2>&1); RC=$?
check "unknown flag -> rc 2" "$RC" "2"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
