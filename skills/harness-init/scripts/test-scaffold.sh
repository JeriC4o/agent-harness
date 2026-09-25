#!/usr/bin/env bash
#
# Tests for scaffold.sh. Run from anywhere:
#   bash skills/harness-init/scripts/test-scaffold.sh
#
# Every case builds a throwaway git repo under a temp dir and points the
# registry at a temp file via $HARNESS_REGISTRY, so nothing touches the real
# ~/.claude/harness/registry.json.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
SCAFFOLD="${HERE}/scaffold.sh"
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

newrepo() {
  d=$(mktemp -d)
  git -C "$d" init -q -b main
  printf '%s' "$d"
}

run() { HARNESS_REGISTRY="$REG" bash "$SCAFFOLD" "$@"; }

REG=$(mktemp -d)/registry.json

printf '\n== case 1: fresh repo gets the full profile ==\n'
P=$(newrepo)
out=$(run "$P" --name demo-app --ticket-prefix DEMO 2>&1); rc=$?
check "exit 0" "$rc" "0"
for f in AGENTS.md CLAUDE.md ai-docs/context.md ai-docs/learnings.md \
         ai-docs/learnings/README.md .claude/settings.json \
         ai-docs/plans/.keep ai-docs/plans/done/.keep ai-docs/plans/deferred/.keep; do
  [ -f "$P/$f" ] && ok "created $f" || bad "created $f"
done
grep -q 'demo-app' "$P/AGENTS.md" && ok "%PROJECT_NAME% substituted" || bad "%PROJECT_NAME% substituted"
grep -q '%PROJECT_NAME%' "$P/AGENTS.md" && bad "no %PROJECT_NAME% left" || ok "no %PROJECT_NAME% left"
grep -q 'ai-docs/bugfix/' "$P/.gitignore" && ok "gitignore appended" || bad "gitignore appended"

printf '\n== case 2: re-run is idempotent and never overwrites ==\n'
printf 'MY OWN RULES\n' > "$P/AGENTS.md"
before_ignore=$(wc -l < "$P/.gitignore")
out2=$(run "$P" --name demo-app 2>&1); rc2=$?
check "exit 0 on re-run" "$rc2" "0"
check "existing AGENTS.md untouched" "$(cat "$P/AGENTS.md")" "MY OWN RULES"
check "gitignore not doubled" "$(wc -l < "$P/.gitignore")" "$before_ignore"
echo "$out2" | grep -qi 'skip' && ok "reports skipped files" || bad "reports skipped files"
n=$(jq --arg p "$P" '[.projects[] | select(.path == $p)] | length' "$REG")
check "registry holds exactly one entry for the path" "$n" "1"

printf '\n== case 3: registry fields ==\n'
check "name recorded"          "$(jq -r --arg p "$P" '.projects[]|select(.path==$p)|.name' "$REG")" "demo-app"
check "ticket_prefix recorded" "$(jq -r --arg p "$P" '.projects[]|select(.path==$p)|.ticket_prefix' "$REG")" "DEMO"
check "scope defaults shared"  "$(jq -r --arg p "$P" '.projects[]|select(.path==$p)|.scope' "$REG")" "shared"

printf '\n== case 4: --scope local is recorded ==\n'
Q=$(newrepo)
run "$Q" --name secret-thing --scope local >/dev/null 2>&1
check "scope local" "$(jq -r --arg p "$Q" '.projects[]|select(.path==$p)|.scope' "$REG")" "local"

printf '\n== case 5: --dry-run writes nothing ==\n'
R=$(newrepo)
run "$R" --name dry --dry-run >/dev/null 2>&1
[ -f "$R/AGENTS.md" ] && bad "dry-run created nothing" || ok "dry-run created nothing"
check "dry-run did not register" "$(jq --arg p "$R" '[.projects[]|select(.path==$p)]|length' "$REG")" "0"

printf '\n== case 6: build-system detection ==\n'
# Capture, then match. Piping into `grep -q` under `pipefail` reports the
# writer's SIGPIPE (141) as the pipeline status, so the assertion would fail
# on a script that behaved correctly -- the masked-gate shape this harness bans.
detects() { # <marker-file> <content> <expected-word>
  d=$(newrepo); printf '%s' "$2" > "$d/$1"
  o=$(run "$d" --name probe-app 2>&1)
  case "$o" in *"$3"*) ok "detects $3" ;; *) bad "detects $3" ;; esac
}
detects package.json '{"name":"x"}' npm
detects Cargo.toml   '[package]'    cargo
detects Makefile     'all:'         make

printf '\n== case 7: usage errors fail loudly ==\n'
run 2>/dev/null; check "no args -> rc 2" "$?" "2"
run /nonexistent/path --name x >/dev/null 2>&1; check "missing dir -> rc 2" "$?" "2"

printf '\n== the entry point the skill invokes by full path is executable ==\n'
# skills/harness-init/SKILL.md invokes this script BY PATH, not via `bash <path>`.
# Every assertion above runs it through the interpreter, which does not need the
# execute bit -- so the suite would stay green while the bit went missing and
# every consumer following the skill got exit 126. Both sibling suites carry this
# assertion; a new file of the same kind means copying it, not re-deriving it.
if [ -x "$SCAFFOLD" ]; then ok "scaffold.sh carries the execute bit"
else bad "scaffold.sh carries the execute bit"; fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
