#!/usr/bin/env bash
#
# Every could-not-compute case is asserted on its exit status AND on the absence
# of the word "unchanged": the one reading this helper exists to prevent is a
# failure to compute taken for a plan nobody edited.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
PF="${HERE}/plan-freeze.sh"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case $2 in *"$3"*) ok "$1" ;; *) bad "$1 (no [$3] in: $2)" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1 (found [$3] in: $2)" ;; *) ok "$1" ;; esac; }

command -v git >/dev/null 2>&1 || { printf 'cannot run: git absent\n' >&2; exit 2; }

D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

run() { OUT=$(bash "$PF" "$@" 2>&1); RC=$?; }
not_computed() { # <label>
  same "$1 -> exit 2" "$RC" 2
  has  "  says it could not compute" "$OUT" "verdict=could-not-compute"
  hasnt "  and never reads as unchanged" "$OUT" "verdict=unchanged"
}

R="$D/repo"
mkdir -p "$R/ai-docs/plans/done" "$R/src"
git -C "$R" init -q
git -C "$R" config user.email t@t
git -C "$R" config user.name t
S="$R/ai-docs/plans/2026-01-01-x.spec.md"
G="$R/ai-docs/plans/2026-01-01-x.design.md"
printf '# Spec\n\nCriterion one.\n' > "$S"
printf '# Design\n\nItem one.\n' > "$G"
printf 'a\n' > "$R/src/a"
git -C "$R" add -A
git -C "$R" commit -q -m base
BASE_SHA=$(git -C "$R" rev-parse HEAD)

printf '\n== no freeze yet ==\n'
run find "$S"; not_computed "a plan with no freeze"
has "  and names the trailer it looked for" "$OUT" "Plan-Freeze: 2026-01-01-x"
printf 'b\n' > "$R/src/a"
git -C "$R" commit -q -am 'GH-1: work' -m 'Plan-Freeze: 2026-01-01-x' -m 'A paragraph after it.'
run find "$S"; not_computed "the key on a line outside the trailer block"
git -C "$R" commit -q --allow-empty -m 'another plan' -m 'Plan-Freeze: 2026-01-01-x-more'
run find "$S"; not_computed "a longer plan name sharing this one as a prefix"

printf '\n== the freeze ==\n'
git -C "$R" commit -q --allow-empty -m 'GH-1: freeze' -m 'Plan-Freeze: 2026-01-01-x'
F1=$(git -C "$R" rev-parse HEAD)
run find "$S"
same "find exits 0" "$RC" 0
has  "  naming the freeze commit" "$OUT" "freeze=${F1}"
has  "  and the plan" "$OUT" "plan=2026-01-01-x"
run find "$G"
has  "the design names the same freeze" "$OUT" "freeze=${F1}"
bash "$PF" show "$G" > "$D/shown"
same "show exits 0" "$?" 0
same "show prints the document's committed bytes" "$(cmp -s "$D/shown" "$G" && echo same)" same
run diff "$S" "$G"
same "diff of an untouched plan exits 0" "$RC" 0
has  "  unchanged, both documents compared" "$OUT" "verdict=unchanged freeze=${F1} documents=2 changed=0"
hasnt "  and prints no hunk" "$OUT" "@@"

printf '\n== a change since the freeze, uncommitted ==\n'
printf '# Design\n\nItem one, as shipped.\n' > "$G"
run diff "$S" "$G"
same "diff of a corrected design exits 0, not the findings code" "$RC" 0
has  "  changed, one of two" "$OUT" "verdict=changed freeze=${F1} documents=2 changed=1"
has  "  with the removed line" "$OUT" "-Item one."
has  "  and the added line" "$OUT" "+Item one, as shipped."
bash "$PF" show "$G" > "$D/shown"
same "show still prints the text as frozen" "$(cat "$D/shown")" "$(printf '# Design\n\nItem one.')"

printf '\n== another plan frozen later on the same branch ==\n'
printf '# Spec\n' > "$R/ai-docs/plans/2026-02-02-y.spec.md"
git -C "$R" add ai-docs/plans/2026-02-02-y.spec.md
git -C "$R" commit -q -m 'GH-2: freeze' -m 'Plan-Freeze: 2026-02-02-y'
run find "$S"
has  "is never matched" "$OUT" "freeze=${F1}"

printf '\n== the move into the archive ==\n'
git -C "$R" add "$G"
git -C "$R" commit -q -m 'GH-1: work'
git -C "$R" mv ai-docs/plans/2026-01-01-x.spec.md ai-docs/plans/done/
git -C "$R" mv ai-docs/plans/2026-01-01-x.design.md ai-docs/plans/done/
git -C "$R" commit -q -m 'GH-1: archive'
AS="$R/ai-docs/plans/done/2026-01-01-x.spec.md"
AG="$R/ai-docs/plans/done/2026-01-01-x.design.md"
run diff "$AS"
has  "the archived spec reads as no change" "$OUT" "verdict=unchanged freeze=${F1} documents=1 changed=0"
run diff "$AG"
has  "the archived design still shows only the correction" "$OUT" "documents=1 changed=1"
has  "  against its path at the freeze" "$OUT" "ai-docs/plans/2026-01-01-x.design.md (freeze ${F1})"

printf '\n== a new freeze of the same plan ==\n'
git -C "$R" commit -q --allow-empty -m 'GH-1: re-freeze' -m 'Plan-Freeze: 2026-01-01-x'
F2=$(git -C "$R" rev-parse HEAD)
run diff "$AS" "$AG"
has  "the latest freeze is the one read" "$OUT" "verdict=unchanged freeze=${F2} documents=2 changed=0"

printf '\n== a rebase ==\n'
git -C "$R" checkout -q -b side "$BASE_SHA"
printf 'side\n' > "$R/side"
git -C "$R" add side
git -C "$R" commit -q -m side
git -C "$R" checkout -q -
BEFORE=$(bash "$PF" show "$AG")
git -C "$R" rebase -q side
run find "$AS"
same "after a rebase find still exits 0" "$RC" 0
hasnt "  on a rewritten commit" "$OUT" "freeze=${F2}"
same "  whose document text is unchanged" "$(bash "$PF" show "$AG")" "$BEFORE"
run diff "$AS" "$AG"
has  "  and the plan still reads as unchanged" "$OUT" "verdict=unchanged"

printf '\n== could not compute ==\n'
printf '# Design\n' > "$R/ai-docs/plans/2026-03-03-z.design.md"
git -C "$R" add ai-docs/plans/2026-03-03-z.design.md
git -C "$R" commit -q -m 'GH-3: freeze, with the design left out' -m 'Plan-Freeze: 2026-03-03-z'
git -C "$R" rm -q --cached ai-docs/plans/2026-03-03-z.design.md
git -C "$R" commit -q -m 'GH-3: drop'
git -C "$R" commit -q --allow-empty -m 'GH-3: freeze again' -m 'Plan-Freeze: 2026-03-03-z'
run diff "$R/ai-docs/plans/2026-03-03-z.design.md"; not_computed "a freeze whose tree lacks the document"
run show "$R/ai-docs/plans/2026-03-03-z.design.md"
same "show of it exits 2" "$RC" 2
run diff "$R/src/a"; not_computed "a path that is no plan document"
run diff "$R/ai-docs/plans/2026-01-01-gone.spec.md"; not_computed "a document that does not exist"
run diff "$AS" "$R/ai-docs/plans/2026-02-02-y.spec.md"; not_computed "two plans in one call"
N="$D/nogit"; mkdir -p "$N"; printf '# Spec\n' > "$N/a.spec.md"
run diff "$N/a.spec.md"; not_computed "a document outside any git work tree"
FAKE="$D/fakebin"; mkdir -p "$FAKE"
REALGIT=$(command -v git)
cat > "$FAKE/git" <<EOF
#!/bin/sh
for a in "\$@"; do
  case \$a in log) printf '\036abc\n%%(trailers:key=Plan-Freeze,unfold)\n'; exit 0 ;; esac
done
exec "$REALGIT" "\$@"
EOF
chmod +x "$FAKE/git"
OUT=$(PATH="$FAKE:$PATH" bash "$PF" diff "$AS" 2>&1); RC=$?
not_computed "a git that prints the trailer placeholder back"
has  "  naming the missing placeholder" "$OUT" "no trailer placeholder"
EMPTY="$D/empty"; mkdir -p "$EMPTY"
OUT=$(PATH="$EMPTY" "$(command -v bash)" "$PF" diff "$AS" 2>&1); RC=$?
not_computed "no git on PATH"

printf '\n== usage ==\n'
run; same "no verb exits 2" "$RC" 2
run frob "$AS"; same "an unknown verb exits 2" "$RC" 2
run show; same "show with no document exits 2" "$RC" 2
run show "$AS" "$AG"; same "show with two documents exits 2" "$RC" 2

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
