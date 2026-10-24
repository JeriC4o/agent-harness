#!/usr/bin/env bash
#
# Tests for cleanup-progress.sh. Run from anywhere:
#   bash skills/pr-merged/scripts/test-cleanup-progress.sh
#
# Every case runs the script inside a fresh fixture directory, because it
# deletes files relative to the directory it is run from. Every deletion a case
# expects is PAIRED with a file beside it that must survive: a cleanup that
# removed everything would pass every "it was deleted" assertion on its own.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
SRC="${HERE}/cleanup-progress.sh"
PASS=0
FAIL=0

ok()    { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in [$2]" ;; esac; }
gone()  { [ ! -e "$2" ] && ok "$1" || bad "$1 -- $2 still exists"; }
kept()  { [ -e "$2" ] && ok "$1" || bad "$1 -- $2 was deleted"; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT INT TERM

fresh() {
  rm -rf "$W/case"
  mkdir -p "$W/case/ai-docs/plans/done" "$W/case/ai-docs/plans/deferred"
}
progress() { # <path> <branch or empty>
  { printf '# Task progress\n\n'
    [ -z "$2" ] || printf '**Branch:** %s\n' "$2"
    printf '**Spec:** ai-docs/plans/x.spec.md\n'; } > "$W/case/$1"
}
cleanup() { (cd "$W/case" && bash "$SRC" "$@" 2>&1); }

printf '\n== usage ==\n'
fresh
out=$(cleanup); rc=$?
check "no branch argument -> rc 2" "$rc" "2"

printf '\n== the Branch field, which survives the fold ==\n'
fresh
# A folded spec: the collapse keeps no header, so it names no ticket.
printf '## Out of scope\n\n- Nothing.\n' > "$W/case/ai-docs/plans/done/2026-01-01-a.spec.md"
progress ai-docs/plans/2026-01-01-a.progress.md GH-9-fold
progress ai-docs/plans/2026-01-02-b.progress.md GH-9-fold-more
progress ai-docs/plans/deferred/2026-01-03-c.progress.md GH-9-fold
out=$(cleanup GH-9-fold); rc=$?
check "a branch named by a progress file -> rc 0" "$rc" "0"
gone "its progress file is deleted, though the folded spec names no ticket" \
  "$W/case/ai-docs/plans/2026-01-01-a.progress.md"
kept "a branch whose name only starts with it keeps its own" \
  "$W/case/ai-docs/plans/2026-01-02-b.progress.md"
kept "a deferred task's progress file is not touched" \
  "$W/case/ai-docs/plans/deferred/2026-01-03-c.progress.md"

# A match by the Branch field ends the run: the ticket route would otherwise also
# reach a progress file linked through another spec tracked under the same key.
fresh
progress ai-docs/plans/2026-01-01-a.progress.md GH-9-fold
printf '**Tracked in:** GH-9\n\n## Scope\n' > "$W/case/ai-docs/plans/2026-01-06-f.spec.md"
progress ai-docs/plans/2026-01-06-f.progress.md GH-9-earlier
out=$(cleanup GH-9-fold); rc=$?
check "a Branch-field match -> rc 0" "$rc" "0"
gone "the matched file is deleted" "$W/case/ai-docs/plans/2026-01-01-a.progress.md"
kept "and the ticket route does not run after it" "$W/case/ai-docs/plans/2026-01-06-f.progress.md"

fresh
progress ai-docs/plans/2026-01-01-a.progress.md fix-some-thing
progress ai-docs/plans/2026-01-02-b.progress.md other-branch
out=$(cleanup fix-some-thing); rc=$?
check "a branch with no ticket key -> rc 0" "$rc" "0"
gone "its progress file is still found by the Branch field" \
  "$W/case/ai-docs/plans/2026-01-01-a.progress.md"
kept "and another branch's file stays" "$W/case/ai-docs/plans/2026-01-02-b.progress.md"

printf '\n== ticket linkage, for a progress file with no Branch field ==\n'
fresh
printf '**Tracked in:** GH-7\n\n## Scope\n' > "$W/case/ai-docs/plans/2026-01-04-d.spec.md"
progress ai-docs/plans/2026-01-04-d.progress.md ''
progress ai-docs/plans/2026-01-05-e.progress.md ''
out=$(cleanup GH-7-linked); rc=$?
check "a ticket key a spec tracks -> rc 0" "$rc" "0"
gone "the spec's progress file is deleted" "$W/case/ai-docs/plans/2026-01-04-d.progress.md"
kept "and an unrelated one stays" "$W/case/ai-docs/plans/2026-01-05-e.progress.md"

fresh
progress ai-docs/plans/2026-01-05-e.progress.md ''
out=$(cleanup GH-8-untracked); rc=$?
check "a ticket key no spec tracks -> rc 0" "$rc" "0"
has "and it says what it skipped" "$out" 'no /task spec matches Tracked in: GH-8'
kept "and nothing is deleted" "$W/case/ai-docs/plans/2026-01-05-e.progress.md"

fresh
out=$(cleanup manual-branch); rc=$?
check "no match by either route -> rc 0" "$rc" "0"
has "and it says the branch has no ticket key" "$out" 'does not start with KEY-NNN'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
