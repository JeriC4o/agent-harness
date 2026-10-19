#!/usr/bin/env bash
#
# Tests for check-plan-convergence.sh.
#
# Run: bash scripts/test-check-plan-convergence.sh
#
# Every class is planted deliberately in a synthetic plan pair whose correct
# answer is known independently of the checker, and every planted fault is
# PAIRED with a case that must stay silent. A finding without its paired silence
# says only that the class fires, never that it discriminates -- and a class
# that fires on everything is a class nobody can act on.
#
# THE SYNTHETIC ROOT CARRIES ITS OWN COPY OF THE RECORD THE CHECK DERIVES
# SECTION NAMES FROM, and it is a copy of the live one rather than a stand-in:
# the derivation is the mechanism under test, so a fixture record with invented
# section names would test the fixture.

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-plan-convergence.sh"
ROOT=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- unexpected [$3]" ;; *) ok "$1" ;; esac; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

command -v python3 >/dev/null 2>&1 || { printf 'cannot run: python3 absent\n' >&2; exit 2; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/docs" "$T/scripts" "$T/plans"
cp "${ROOT}/docs/plan-invariants.md" "$T/docs/plan-invariants.md"
cp "$CHECK" "${HERE}/check-plan-convergence.py" "$T/scripts/"
git -C "$T" init -q
git -C "$T" add -A >/dev/null 2>&1
SUB="$T/scripts/check-plan-convergence.sh"

# The element tokens the fixtures need are read out of the copied record rather
# than typed here, for the reason the header gives and for one more: a suite
# that spelled them would be the second place they live.
tok() { # <spec|design> <ordinal, 1-based>
  sed -n '/^## The required elements of a spec and of a design$/,/^## /p' "$T/docs/plan-invariants.md" \
    | sed -n "s/^| *$1 *| \`\([^\`]*\)\` *|.*/\1/p" | sed -n "$2p"
}
SPEC_FIRST=$(tok spec 1)
DESIGN_FIRST=$(tok design 1)
DESIGN_SECOND=$(tok design 2)
[ -n "$SPEC_FIRST" ] && [ -n "$DESIGN_FIRST" ] && [ -n "$DESIGN_SECOND" ] \
  && ok "the fixtures' section names were derived from the record" \
  || bad "the fixtures' section names were derived from the record"

run() { bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1; }

write_pair() { # <spec body> <design body>
  printf '# Spec\n\n%s\n\n%s\n' "$SPEC_FIRST" "$1" > "$T/plans/a.spec.md"
  printf '# Design\n\n%s\n\n%s\n' "$DESIGN_FIRST" "$2" > "$T/plans/a.design.md"
}

printf '\n== the three outcomes ==\n'
write_pair 'Nothing numeric here.' 'Nothing numeric here either.'
out=$(run); rc=$?
check "a pair with nothing to report -> rc 0" "$rc" "0"
has "and says so" "$out" 'check-plan-convergence: clean'
write_pair 'The window is 40 rounds wide.' 'Nothing.'
out=$(run); rc=$?
check "a pair with a finding -> rc 1" "$rc" "1"
bash "$SUB" --root "$T" "$T/plans/missing.spec.md" "$T/plans/a.design.md" >/dev/null 2>&1
check "an absent document -> rc 2, which is not a pass" "$?" "2"
out=$(bash "$SUB" --root "$T" "$T/plans/missing.spec.md" "$T/plans/a.design.md" 2>&1)
has "and names it as a cannot-run" "$out" 'cannot run'
bash "$SUB" --root "$T" "$T/plans/a.spec.md" >/dev/null 2>&1
check "one path only -> rc 2 usage" "$?" "2"
mv "$T/scripts/check-plan-convergence.py" "$T/scripts/hidden.py"
bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" >/dev/null 2>&1
check "an absent payload -> rc 2, never rc 1" "$?" "2"
mv "$T/scripts/hidden.py" "$T/scripts/check-plan-convergence.py"

printf '\n== the provenance class, each accepted kind paired with the silent case ==\n'
write_pair 'The window is 40 rounds wide.' 'Nothing.'
out=$(run)
has "a bare figure is reported" "$out" 'spec states [40]'
write_pair 'The window is 40 rounds wide, the threshold the task handed down.' 'Nothing.'
out=$(run)
hasnt "a threshold handed down is silent" "$out" 'states [40]'
write_pair 'The window is 40 rounds wide, measured with `wc -l`.' 'Nothing.'
out=$(run)
hasnt "a measurement of something existing is silent" "$out" 'states [40]'
write_pair 'The window is 40 rounds wide, an estimate derived from the two caps.' 'Nothing.'
out=$(run)
hasnt "an estimate derived in place is silent" "$out" 'states [40]'
write_pair 'The window is 20 + 20 = 40 rounds wide.' 'Nothing.'
out=$(run)
hasnt "a derivation shown as arithmetic needs no word for it" "$out" 'states [40]'
write_pair 'Item 7 and items 8, 9 and 10 are interdependent.' 'Nothing.'
out=$(run)
hasnt "an ordinal a sequence noun introduces is not a figure" "$out" 'finding provenance'
write_pair 'The constant `ARMA_QUOTE_MIN=24` is borrowed.' 'Nothing.'
out=$(run)
hasnt "a numeral inside a backtick span is a token being named" "$out" 'finding provenance'
write_pair 'Criterion AC12 of GH-128, dated 2026-10-16, at version 0.1.48.' 'Nothing.'
out=$(run)
hasnt "an identifier, a date and a version are not figures" "$out" 'finding provenance'
write_pair '1. The first item.
2. The second item.' 'Nothing.'
out=$(run)
hasnt "a list item's own ordinal marker is structure" "$out" 'finding provenance'

printf '\n== the provenance class reaches a figure only a measurement of the artefact could give ==\n'
write_pair 'Nothing.' "$DESIGN_SECOND
| # | Task | Files |
|---|---|---|
| 1 | Build it | \`scripts/new-thing.sh\` *(new)* |

The new check at \`scripts/new-thing.sh\` is 820 lines long, measured with \`wc -l\`."
out=$(run)
has "a figure beside a path the plan creates is reported" "$out" 'a path this plan creates'
hasnt "and its provenance half is satisfied, so only the one finding stands" "$out" 'naming neither which kind'
write_pair 'Nothing.' "$DESIGN_SECOND
| # | Task | Files |
|---|---|---|
| 1 | Build it | \`scripts/new-thing.sh\` *(new)* |

The page it leaves behind is 820 lines long, measured with \`wc -l\`."
out=$(run)
hasnt "the same figure in a clause naming no created path is silent" "$out" 'a path this plan creates'
write_pair 'Nothing.' "$DESIGN_SECOND
| # | Task | Files | Notes |
|---|---|---|---|
| 1 | The page it leaves behind is 820 lines, measured with \`wc -l\` | \`scripts/new-thing.sh\` *(new)* | — |"
out=$(run)
hasnt "a table row's file cell does not reach the figure in its task cell" "$out" 'a path this plan creates'

printf '\n== the arithmetic class, which HOLDS ==\n'
write_pair 'The band is 20 + 20 = 41 wide.' 'Nothing.'
out=$(run)
has "a false equation is reported" "$out" 'the operands compute to 40'
has "and it is counted as a holding finding" "$out" 'holding=1'
write_pair 'The band is 20 + 20 = 40 wide.' 'Nothing.'
out=$(run)
hasnt "a true equation is silent" "$out" 'finding arithmetic'
has "and it was examined rather than skipped" "$out" 'relations=1'
write_pair 'There are 30 of one and 20 of the other, 51 together.' 'Nothing.'
out=$(run)
has "a false total over its addends is reported" "$out" 'which sum to 50'
write_pair 'There are 30 of one and 20 of the other, 50 together.' 'Nothing.'
out=$(run)
hasnt "a true total is silent" "$out" 'finding arithmetic'
write_pair 'The derived set = the recorded set, measured in both directions.' 'Nothing.'
out=$(run)
has "an equality this class cannot read as literals is counted, not dropped" "$out" 'not-evaluable=1'
hasnt "and it is not reported as a false relation" "$out" 'finding arithmetic'
write_pair 'A re-derived figure in a self-review round is not a relation.' 'Nothing.'
out=$(run)
has "a hyphenated word is not an operator" "$out" 'relations=0'

printf '\n== the derived regions ==\n'
write_pair 'Nothing.' 'Nothing.'
out=$(run)
has "both documents' regions are counted" "$out" 'regions=2/'
write_pair 'Nothing.' 'Nothing.'
printf '# Design\n\nNo required heading at all.\n' > "$T/plans/a.design.md"
out=$(run); rc=$?
check "a document missing every derived section still exits 0" "$rc" "0"
has "its present-region count falls, which is what a reader weighs" "$out" 'regions=1/'
# Asserted on the anchored count and not on the word `finding`, which the
# verdict line carries either way: a loose substring here passed over its own
# subject once already.
has "and nothing reports the section as absent" "$out" 'findings=0'

printf '\n== the derivation cannot run on a record it cannot read ==\n'
write_pair 'Nothing.' 'Nothing.'
mv "$T/docs/plan-invariants.md" "$T/docs/moved.md"
out=$(bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "an unreadable record -> rc 2" "$rc" "2"
has "and says the derivation had no source" "$out" 'cannot run'
mv "$T/docs/moved.md" "$T/docs/plan-invariants.md"
sed -i.bak 's/^## The required elements of a spec and of a design$/## Something else entirely/' \
  "$T/docs/plan-invariants.md"
out=$(bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "a record whose heading moved -> rc 2, never a clean sweep" "$rc" "2"
mv "$T/docs/plan-invariants.md.bak" "$T/docs/plan-invariants.md"
git -C "$T" rm -q --cached docs/plan-invariants.md >/dev/null 2>&1
out=$(bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "a record outside the index -> rc 2" "$rc" "2"
has "and says the run reads a file no other clone has" "$out" 'not in the index'
git -C "$T" add docs/plan-invariants.md >/dev/null 2>&1

printf '\n== the payload parses, which no shell test can see ==\n'
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "${HERE}/check-plan-convergence.py" \
  && ok "check-plan-convergence.py parses" || bad "check-plan-convergence.py parses"

printf '\n== the check holds no section token of a spec or a design as a literal ==\n'
# The condition on which this check stays out of the edit-time refusal's page
# set. Asserted against the record's own rows rather than against a list here,
# so widening the record cannot leave this leg testing a stale set.
LEAKED=''
while IFS= read -r t; do
  [ -n "$t" ] || continue
  grep -qF -- "\`$t\`" "${HERE}/check-plan-convergence.py" && LEAKED="${LEAKED}${LEAKED:+ }[$t]"
  grep -qF -- "\`$t\`" "$CHECK" && LEAKED="${LEAKED}${LEAKED:+ }[$t in the wrapper]"
done <<EOF
$(sed -n '/^## The required elements of a spec and of a design$/,/^## /p' "${ROOT}/docs/plan-invariants.md" \
   | sed -n 's/^| *\(spec\|design\) *| `\([^`]*\)` *|.*/\2/p')
EOF
check "no element token is backticked in either file" "$LEAKED" ""

printf '\n== this repository own plan pair is examined rather than skipped ==\n'
LIVE_SPEC=$(ls "${ROOT}"/ai-docs/plans/*.spec.md 2>/dev/null | head -1)
LIVE_DESIGN=${LIVE_SPEC%.spec.md}.design.md
if [ -n "$LIVE_SPEC" ] && [ -f "$LIVE_DESIGN" ]; then
  out=$(bash "$CHECK" "$LIVE_SPEC" "$LIVE_DESIGN" 2>&1)
  hasnt "the live pair is not a cannot-run" "$out" 'CANNOT RUN'
  hasnt "and its region census is not empty" "$out" 'regions=0/'
  hasnt "and its statement count is not zero" "$out" 'statements=0 '
else
  ok "no active plan pair in this tree, so there is nothing to examine"
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
