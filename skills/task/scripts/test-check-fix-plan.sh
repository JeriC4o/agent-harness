#!/usr/bin/env bash
#
# Tests for check-fix-plan.sh. Run from anywhere:
#   bash skills/task/scripts/test-check-fix-plan.sh
#
# This suite is the gate's ENTIRE mechanical coverage: a `check-*.sh` under
# skills/ cannot be a documented member of scripts/run-checks.sh, so it is
# exempted there and the repo-wide runner never executes it.
#
# Every leg runs the script BY FULL PATH, never as `bash <path>`, because that
# is how the skill invokes it -- the convenient form does not need the execute
# bit, so a suite spelled that way is green precisely because it never runs the
# thing the way it ships.
#
# Each arm is exercised twice: a CONTROL that reaches the arm and passes, and a
# planted defect that trips it. The control is not decoration -- a parser that
# selects nothing reports every arm as passing, so a planted-defect assertion
# alone cannot tell a live arm from a dead one.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
GATE="${HERE}/check-fix-plan.sh"
REPO=$(cd -- "${HERE}/../../.." && pwd)
PASS=0
FAIL=0

# --- the suite's sandbox, set ONCE for every leg ------------------------------
# The gate writes a verdict row on every escalation, pre-apply ones included,
# and derives the destination from HARNESS_LOOP_DIR (check-fix-plan.sh:110-111).
# Exporting that one variable here moves the DEFAULT destination for every leg
# below, so a leg that sandboxes nothing of its own still cannot write outside
# this tree. Measured before this existed: the unsandboxed escalation legs had
# appended 17 fixture rows to the developer's real
# ~/.claude/harness/fix-plan/verdicts.jsonl, contaminating at birth the corpus
# the row exists to be read from -- per-leg sandboxing is the weak form, because
# it is correct only for the legs that remember it.
#
# This must be HARNESS_LOOP_DIR and NOT HARNESS_VERDICT_DIR. The T1-ZL legs pin
# the sibling derivation by setting HARNESS_LOOP_DIR per invocation; an exported
# HARNESS_VERDICT_DIR takes precedence over that derivation, so those legs would
# look for their row in a sandbox the gate never wrote to and measure nothing.
SUITE_TMP=$(mktemp -d)
export HARNESS_LOOP_DIR="${SUITE_TMP}/loops"
mkdir -p "$HARNESS_LOOP_DIR"
SUITE_VJ="${SUITE_TMP}/fix-plan/verdicts.jsonl"

# The REAL default, read before the first gate invocation so T1-ZM can assert a
# bare suite run left it alone. Deliberately the live $HOME path and not a
# redirected one: a leg asserting against a sandboxed HOME would assert about
# the sandbox, which is the thing in question.
DEFAULT_VJ="${HOME}/.claude/harness/fix-plan/verdicts.jsonl"
default_vj_rows() { if [ -f "$DEFAULT_VJ" ]; then grep -c . "$DEFAULT_VJ"; else printf '0\n'; fi; }
DEFAULT_VJ_BEFORE=$(default_vj_rows)

ok()    { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in [$2]" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 -- did not expect [$3]" ;; *) ok "$1" ;; esac; }

OPEN='⬜ Open'

mkfix() { # -> a repository whose progress file holds one open round-1 finding
  d=$(mktemp -d)
  git -C "$d" init -q .
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  mkdir -p "$d/docs" "$d/ai-docs/plans/done" "$d/ai-docs/learnings"
  printf 'ai-docs/plans/*.progress.md\n' > "$d/.gitignore"
  awk 'BEGIN { for (i = 1; i <= 40; i++) print "line " i }' > "$d/docs/workflow.md"
  awk 'BEGIN { for (i = 1; i <= 40; i++) print "line " i }' > "$d/docs/other.md"
  printf 's1\ns2\ns3\ns4\n' > "$d/ai-docs/plans/t.spec.md"
  printf 'd1\nd2\nd3\nd4\n' > "$d/ai-docs/plans/done/t.design.md"
  # A TRACKED file under the same prefix that is NEITHER of the two routing
  # suffixes, mirroring the real `…design-evidence.md` the repository holds.
  # Without it the non-routing control cannot be written at all: an empty
  # directory is not tracked, so the only paths the diff could see under that
  # prefix were the two suffixes themselves, and a leg over a path excluded by
  # two overlapping rules measures neither.
  printf 'e1\ne2\n' > "$d/ai-docs/plans/t.design-evidence.md"
  printf 'archive\n' > "$d/ai-docs/learnings.md"
  printf 'entry\n' > "$d/ai-docs/learnings/b.md"
  printf 'sibling\n' > "$d/ai-docs/learnings-notes.md"
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s' "$d"
}

prog() { printf '%s/ai-docs/plans/t.progress.md' "$1"; }

review() { # <fixture> <findings-table row...>
  d=$1; shift
  {
    printf '# Progress\n\n## Self-Review (Round 1)\n\n**Verdict:** REJECT\n\n'
    printf '| # | File:line | Severity | Finding | Status |\n|---|---|---|---|---|\n'
    for row in "$@"; do printf '%s\n' "$row"; done
  } > "$(prog "$d")"
}

plan() { # <fixture> <round_base> <verification> <declared> <plan row...>
  d=$1; base=$2; verification=$3; declared=$4; shift 4
  {
    printf '\n## Fix Plan (Round 1)\n\n**round_base:** %s\n' "$base"
    printf '**verification:** %s\n**declared_changed_lines:** %s\n\n' "$verification" "$declared"
    printf '| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |\n|---|---|---|---|---|\n'
    for row in "$@"; do printf '%s\n' "$row"; done
  } >> "$(prog "$d")"
}

gate() { OUT=$("$GATE" "$1" "$2" 2>&1); RC=$?; }

# The stub `baseline` appends is restored away afterwards, so a leg that then
# writes a filled section has exactly ONE section for the round. Two sections
# sharing a round number make the header-field reader take the stub's empty
# values, which looked like a gate defect and was this helper's.
baseline_of() { # <fixture> -> the sha, leaving the progress file as it was
  local keep sha
  keep=$(mktemp)
  cp "$(prog "$1")" "$keep"
  sha=$("$GATE" baseline "$(prog "$1")" | sed 's/.*round_base=//; s/ .*//')
  cp "$keep" "$(prog "$1")"
  printf '%s' "$sha"
}

ONE_OPEN="| 1 | docs/workflow.md:10 | major | A thing | ${OPEN} |"
ONE_FIX='| 1 | fix | docs/workflow.md:10 | 12 | none |'

printf '\n== T1-A anchor resolution ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"; plan "$F" x 'the suite' 12 "$ONE_FIX"
gate plan "$(prog "$F")"
check "a resolving anchor passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  A1 passes" "$OUT" "A1   anchor-resolution    pass"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/workflow.md:9999 | 12 | none |'
gate plan "$(prog "$F")"
check "a line beyond EOF refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=anchor-unresolved"
has   "  names the file's real length" "$OUT" "does not resolve (file has 40 lines)"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/gone.md:3 | 12 | none |'
gate plan "$(prog "$F")"
check "a missing file refuses" "$RC" "1"
has   "  reason" "$OUT" "reason=anchor-unresolved"
has   "  names the fault" "$OUT" "docs/gone.md:3 does not resolve (no such file)"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/workflow.md:10 | 12 | `docs/workflow.md:9999` — "x" |'
gate plan "$(prog "$F")"
check "an unresolvable ARM A anchor refuses too" "$RC" "1"
has   "  the fault is attributed to Arm A" "$OUT" "Arm A docs/workflow.md:9999 does not resolve"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/workflow.md:10 | 12 | a verdict with no citation |'
gate plan "$(prog "$F")"
check "an Arm A cell quoting no anchor refuses" "$RC" "1"
has   "  reason" "$OUT" "the Arm A cell quotes no file:line anchor"

printf '\n== T1-B spec-amendment routing, both detections ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 6 '| 1 | fix | ai-docs/plans/t.spec.md:4 | 6 | none |'
gate plan "$(prog "$F")"
check "an active spec path on a fix row routes -- the disposition is load-bearing" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-SPEC reason=spec-amendment"
hasnt "  and never reports a plan the fix agent may apply" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 6 '| 1 | amendment: spec | docs/workflow.md:10 | 6 | none |'
gate plan "$(prog "$F")"
check "the disposition alone routes, on a non-plans target" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-SPEC reason=spec-amendment"
hasnt "  and never reports a plan the fix agent may apply" "$OUT" "decision=PASS"

printf '\n== T1-C design-amendment routing, both detections ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 6 '| 1 | fix | ai-docs/plans/done/t.design.md:4 | 6 | none |'
gate plan "$(prog "$F")"
check "a design path under done/ routes" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-DESIGN reason=design-amendment"
hasnt "  and never reports a plan the fix agent may apply" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 6 '| 1 | amendment: design | docs/workflow.md:10 | 6 | none |'
gate plan "$(prog "$F")"
check "the disposition alone routes, on a non-plans target" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-DESIGN reason=design-amendment"

printf '\n== T1-D size: the boundary, the overrun, and the header-vs-rows check ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 150 '| 1 | fix | docs/workflow.md:10 | 150 | none |'
gate plan "$(prog "$F")"
check "the boundary is inclusive" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  the header carries the value it fired under" "$OUT" "threshold_changed_lines=150"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 151 '| 1 | fix | docs/workflow.md:10 | 151 | none |'
gate plan "$(prog "$F")"
check "one over the boundary escalates" "$RC" "1"
has   "  decision" "$OUT" "decision=ESCALATE reason=size-over-threshold"
has   "  the header carries the value it fired under" "$OUT" "threshold_changed_lines=150"
has   "  the arm reports both numbers" "$OUT" "declared 151 of 150"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 400 '| 1 | fix | ai-docs/plans/t.spec.md:4 | 400 | none |'
gate plan "$(prog "$F")"
has "routing beats size: a plan that both routes and overruns ROUTES" "$OUT" "decision=ROUTE-SPEC"
has "  and the size arm still reports its finding" "$OUT" "A4   size                 FAIL  declared 400 of 150"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 40 "$ONE_FIX"
gate plan "$(prog "$F")"
check "a header disagreeing with its own rows refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=declared-sum-mismatch"
has   "  both totals named" "$OUT" "declared_changed_lines 40 disagrees with the rows, which sum to 12"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' '' "$ONE_FIX"
gate plan "$(prog "$F")"
check "an absent total refuses rather than reading as zero" "$RC" "1"
has   "  reason" "$OUT" "no declared_changed_lines"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/workflow.md:10 | about twelve | none |'
gate plan "$(prog "$F")"
check "a non-integer row figure refuses" "$RC" "1"
has   "  reason" "$OUT" "is not an integer"

printf '\n== T1-E the threshold is defined in exactly one place ==\n'
check "the literal appears once in the gate" "$(grep -cw 150 "$GATE")" "1"
check "and once as the assignment" "$(grep -c '^THRESHOLD_CHANGED_LINES=150$' "$GATE")" "1"

MUT=$(mktemp -d)
sed 's/^THRESHOLD_CHANGED_LINES=150$/THRESHOLD_CHANGED_LINES=77/' "$GATE" > "${MUT}/g.sh"
chmod +x "${MUT}/g.sh"
F=$(mkfix); review "$F" "$ONE_OPEN"
B=$("${MUT}/g.sh" baseline "$(prog "$F")" | sed 's/.*round_base=//; s/ .*//')
{
  printf '**verification:** the suite\n**declared_changed_lines:** 12\n'
  printf '%s\n' "$ONE_FIX"
} >> "$(prog "$F")"
has "mutating the one constant moves the plan verdict" "$("${MUT}/g.sh" plan "$(prog "$F")" 2>&1)" "threshold_changed_lines=77"
# The converse half of the same property, now that the limit has ONE firing
# site: `applied` reports no limit at all, so there is nothing there to move.
# The positive co-assertion is what stops this reading as agreement when the
# verb simply failed to run.
MUTAPPLIED=$("${MUT}/g.sh" applied "$(prog "$F")" 2>&1)
has   "  and applied ran at all" "$MUTAPPLIED" "verb=applied"
hasnt "  while carrying no threshold for the mutation to move" "$MUTAPPLIED" "threshold_changed_lines"

# AC5's absence half, read across THREE verbs' headers rather than one: a limit
# is printed only where it is enforced. A limit has a single definition
# elsewhere, so a second printing is a second copy that can drift from it -- and
# a limit shown beside a figure reads as a comparison that is still happening.
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 12 "$ONE_FIX"
printf 'edit\n' >> "${F}/docs/workflow.md"
gate plan "$(prog "$F")"
has   "the plan verb prints the limit it fires on" "$OUT" "threshold_changed_lines=150"
gate applied "$(prog "$F")"
has   "the applied verb ran" "$OUT" "verb=applied"
hasnt "  and prints no limit" "$OUT" "threshold_changed_lines"

# `grep -w` rather than a `\b` escape: a word-boundary escape is a GNU
# extension, and a pattern the platform's grep does not understand comes back
# empty, which this leg would read as agreement.
# The scanned paths go through a FILE rather than one space-joined variable:
# an unquoted expansion is word-split by bash and left whole by zsh, so the
# convenient spelling scans one nonexistent path under the wrong shell and comes
# back empty, which this leg would read as agreement.
LITERAL_FILES=$(mktemp)
for p in skills/task/SKILL.md skills/task/reference.md docs/templates/progress-format.md; do
  [ -f "${REPO}/${p}" ] && printf '%s\n' "${REPO}/${p}" >> "$LITERAL_FILES"
done
for p in "${REPO}"/agents/*.md; do
  [ -f "$p" ] && printf '%s\n' "$p" >> "$LITERAL_FILES"
done
SCANNED=$(grep -c . "$LITERAL_FILES")
if [ "$SCANNED" -ge 4 ]; then ok "the no-literal scan reads ${SCANNED} instruction files"
else bad "the no-literal scan reads ${SCANNED} instruction files -- an empty input set is not agreement"; fi
LEAK=''
while IFS= read -r p; do
  grep -qw 150 "$p" && LEAK="${LEAK}${LEAK:+ }${p}"
done < "$LITERAL_FILES"
check "no instruction file carries the threshold literal" "$LEAK" ""
PLANT=$(mktemp -d)
printf 'The threshold is 150 changed lines.\n' > "${PLANT}/x.md"
check "and that scan can come back non-empty" "$(grep -lw 150 "${PLANT}/x.md")" "${PLANT}/x.md"

printf '\n== T1-F verification named ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"; plan "$F" x '' 12 "$ONE_FIX"
gate plan "$(prog "$F")"
check "a present-but-empty verification refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=verification-missing"

F=$(mkfix); review "$F" "$ONE_OPEN"
{
  printf '\n## Fix Plan (Round 1)\n\n**round_base:** x\n**declared_changed_lines:** 12\n\n'
  printf '| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |\n|---|---|---|---|---|\n'
  printf '%s\n' "$ONE_FIX"
} >> "$(prog "$F")"
gate plan "$(prog "$F")"
check "an absent verification line refuses" "$RC" "1"
has   "  reason" "$OUT" "reason=verification-missing"

printf '\n== T1-G finding coverage ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN" "| 2 | docs/other.md:5 | nit | Another | ${OPEN} |"
plan "$F" x 'the suite' 12 "$ONE_FIX"
gate plan "$(prog "$F")"
check "an open finding absent from the plan refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=finding-coverage"
has   "  names the finding" "$OUT" "open finding 2 is absent from the plan"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | maybe later | docs/workflow.md:10 | 12 | none |'
gate plan "$(prog "$F")"
check "an out-of-vocabulary disposition refuses" "$RC" "1"
has   "  quotes the disposition" "$OUT" "disposition [maybe later] is outside the vocabulary"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | object: |  docs/workflow.md:10 | 12 | none |'
gate plan "$(prog "$F")"
check "object: with no reason refuses" "$RC" "1"
has   "  reason" "$OUT" "is outside the vocabulary"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/workflow.md:10 | 12 |  |'
gate plan "$(prog "$F")"
check "an empty Arm A cell refuses" "$RC" "1"
has   "  says none must be deliberate" "$OUT" "the Arm A cell is empty, and none must be written deliberately"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | object: the cited form is the documented one | docs/workflow.md:10 | 0 | none |'
gate plan "$(prog "$F")"
check "a plan whose every finding is objected to, total 0, PASSES" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN"
gate plan "$(prog "$F")"
check "a round with no plan section at all refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=no-plan-section"
has   "  no arm claims to have passed" "$OUT" "A1   anchor-resolution    n/a"

TWO_OPEN="| 2 | docs/other.md:5 | nit | Another | ${OPEN} |"
TWO_FIX='| 2 | fix | docs/other.md:5 | 3 | none |'
THREE_FIX='| 3 | fix | docs/other.md:5 | 3 | none |'
BAD_ANCHOR='| 1 | fix | docs/workflow.md:9999 | 12 | none |'

printf '\n== T1-Y arm precedence, on one plan carrying two faults at once ==\n'
# The only legs that discriminate the arm ORDER: a per-property suite is green
# whichever order ships. Their controls are the single-fault legs already in
# this file -- T1-A's resolving anchor, T1-B/T1-C's routing, T1-D's escalation
# -- without which a gate that refused everything would satisfy these three.
# The amendment targets are REAL artefacts, so A2/A3 fire on routing rather
# than on an anchor that could not resolve either way.
F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
plan "$F" x 'the suite' 18 "$BAD_ANCHOR" '| 2 | fix | ai-docs/plans/t.spec.md:4 | 6 | none |'
gate plan "$(prog "$F")"
check "unanchored and spec-naming at once refuses" "$RC" "1"
has   "  the anchor arm takes the decision" "$OUT" "decision=REFUSE reason=anchor-unresolved"
hasnt "  and the expensive route is not started" "$OUT" "ROUTE-SPEC"
has   "  while the superseded arm still shows its own fault" "$OUT" "A2   spec-amendment       FAIL"

F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
plan "$F" x 'the suite' 18 "$BAD_ANCHOR" '| 2 | fix | ai-docs/plans/done/t.design.md:4 | 6 | none |'
gate plan "$(prog "$F")"
check "unanchored and design-naming at once refuses" "$RC" "1"
has   "  the anchor arm takes the decision" "$OUT" "decision=REFUSE reason=anchor-unresolved"
hasnt "  and the expensive route is not started" "$OUT" "ROUTE-DESIGN"
has   "  while the superseded arm still shows its own fault" "$OUT" "A3   design-amendment     FAIL"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 200 '| 1 | fix | docs/workflow.md:9999 | 200 | none |'
gate plan "$(prog "$F")"
check "unanchored and over the threshold at once refuses" "$RC" "1"
has   "  the anchor arm takes the decision" "$OUT" "decision=REFUSE reason=anchor-unresolved"
hasnt "  and no size judgement is put to a human" "$OUT" "ESCALATE"
has   "  while the size arm still shows its own fault" "$OUT" "A4   size                 FAIL  declared 200 of 150"

printf '\n== T1-Z A6 the converse: a plan row matching no open finding ==\n'

# PRIMARY -- the discriminator, and the only leg that is one. Every target
# resolves and every disposition is in vocabulary, so no earlier arm can claim
# the decision, and the row the review never raised is the single fault. A
# count-equality implementation refuses this too but can only say
# `finding-coverage`, so the leg separates the two on the reason TOKEN.
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 15 "$ONE_FIX" "$TWO_FIX"
gate plan "$(prog "$F")"
check "a plan row matching no open finding refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=plan-row-unmatched"
has   "  names the offending row" "$OUT" "plan row [2] matches no open finding"
hasnt "  and does not report it as under-coverage" "$OUT" "reason=finding-coverage"

# SWAP -- a regression canary, NOT a discriminator: the omitted finding trips
# the pre-existing missing-check first, so both candidate implementations print
# the same reason here. Kept to pin which token wins while all three original
# A6 checks are intact, and that the losing fault is still diagnosed.
F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
plan "$F" x 'the suite' 15 "$ONE_FIX" "$THREE_FIX"
gate plan "$(prog "$F")"
check "one finding omitted and one row fabricated refuses" "$RC" "1"
has   "  under-coverage wins the decision" "$OUT" "decision=REFUSE reason=finding-coverage"
has   "  and the unmatched row is still diagnosed" "$OUT" "A6   plan-row-unmatched   FAIL  plan row [3]"

# MUTATION -- what actually tests the independence claim the set check was
# chosen for. With the missing-check disabled the swap's counts still agree, so
# a count-equality implementation would pass it; the membership test must still
# refuse. The apply-proof is strict for the reason `scripts/test-run-checks.sh`
# records: a guard that only asks "does the output differ" calls a sed error a
# successful mutation.
MUT="$(mktemp -d)/mutant.sh"
OLD='is absent from the plan'
NEW='      0) : ;;'
mutate_gate() {
  local why changed
  why=$(sed "s#^.*${OLD}.*\$#${NEW}#" "$GATE" 2>&1 >"$MUT")
  [ -z "$why" ] || { printf '       sed said: %s\n' "$why"; return 1; }
  grep -qF "$NEW" "$MUT" || return 1
  grep -qF "$NEW" "$GATE" && return 1
  grep -qF "$OLD" "$MUT" && return 1
  bash -n "$MUT" || return 1
  changed=$(diff "$GATE" "$MUT" | grep -c '^[<>]')
  [ "$changed" = "2" ] || { printf '       %s lines changed, expected 2\n' "$changed"; return 1; }
  chmod +x "$MUT" || return 1
  return 0
}
if mutate_gate; then
  ok "the missing-check mutation applied and the mutant parses"
  F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
  plan "$F" x 'the suite' 15 "$ONE_FIX" "$THREE_FIX"
  OUT=$("$MUT" plan "$(prog "$F")" 2>&1); RC=$?
  check "with the missing-check gone the swap still refuses" "$RC" "1"
  has   "  and now reports the converse" "$OUT" "decision=REFUSE reason=plan-row-unmatched"
else
  bad "the missing-check mutation did not apply, so its leg would measure nothing"
fi

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 "$ONE_FIX"
gate plan "$(prog "$F")"
check "control: one finding, one matching row passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
plan "$F" x 'the suite' 12 "$ONE_FIX"
gate plan "$(prog "$F")"
has   "control: the omission direction keeps its own token" "$OUT" "reason=finding-coverage"
hasnt "  so the two directions cannot collapse" "$OUT" "plan-row-unmatched"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | object: the cited form is the documented one | docs/workflow.md:10 | 0 | none |'
gate plan "$(prog "$F")"
check "control: the all-objected plan still passes" "$RC" "0"
hasnt "  so the check keys on the row number, not its disposition" "$OUT" "plan-row-unmatched"

MULTI_B='| 1 | fix | docs/other.md:5 | 3 | none |'

printf '\n== T1-ZB at least one row per finding: one half relaxed, two intact ==\n'
# Each refusing leg differs from the PASSING plan in its own half alone -- leg 2
# keeps the plan byte-identical and adds a finding, leg 3 keeps the review table
# identical and adds a row. A leg mutating both halves cannot show which one
# caught it, and stays green if either is lost.
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 15 "$ONE_FIX" "$MULTI_B"
gate plan "$(prog "$F")"
check "one finding occupying two rows passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  and multiplicity is no longer a fault" "$OUT" "A6   finding-coverage     pass  1 open findings, 2 dispositions"
hasnt "  nothing reports it as doubled" "$OUT" "appears more than once"

F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
plan "$F" x 'the suite' 15 "$ONE_FIX" "$MULTI_B"
gate plan "$(prog "$F")"
check "the SAME plan refuses once a finding it never names is open" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=finding-coverage"
has   "  names the absent finding" "$OUT" "open finding 2 is absent from the plan"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 18 "$ONE_FIX" "$MULTI_B" "$THREE_FIX"
gate plan "$(prog "$F")"
check "the same review table refuses once a row matches no finding" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=plan-row-unmatched"
has   "  names the offending row" "$OUT" "plan row [3] matches no open finding"

printf '\n== T1-ZC the fifth disposition token ==\n'
RESOLVED_1='| 1 | resolved: closed by the user-approved amendment before this round began | docs/workflow.md:10 | 0 | none |'
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 "$RESOLVED_1"
gate plan "$(prog "$F")"
check "resolved: with a reason, 0 declared, a non-plans target passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
hasnt "  and routes nothing" "$OUT" "ROUTE"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | resolved: | docs/workflow.md:10 | 0 | none |'
gate plan "$(prog "$F")"
check "resolved: with no reason refuses, as object: does" "$RC" "1"
has   "  and says why" "$OUT" "is outside the vocabulary"

# A near-miss lexeme rather than obvious nonsense: the vocabulary is closed, so
# the thing to prove is that a plausible synonym is refused too.
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | closed: already satisfied | docs/workflow.md:10 | 0 | none |'
gate plan "$(prog "$F")"
check "a plausible synonym outside the five refuses" "$RC" "1"
has   "  quotes the token" "$OUT" "disposition [closed: already satisfied] is outside the vocabulary"
has   "  and names all five" "$OUT" "fix / object: <reason> / resolved: <reason> / amendment: spec / amendment: design"

F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"
plan "$F" x 'the suite' 0 "$RESOLVED_1" '| 2 | resolved: the tree already satisfies it | docs/other.md:5 | 0 | none |'
gate plan "$(prog "$F")"
check "a round whose every row is resolved: still produces a passing plan" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  with a declared total of 0" "$OUT" "A4   size                 pass  declared 0 of 150"

printf '\n== T1-ZD a gitignored path contributes 0 on both sides ==\n'
# .gitignore-derived exclusion, which is NOT the two-entry in-round ignore list:
# `add -A` honours .gitignore, so the path never enters either tree and no
# verdict field can report it -- `ignored=` counts only the TRACKED paths the
# diff does see. The design's leg wording expected the verdict to name it; the
# mechanism cannot, and asserting that it does would have measured nothing.
F=$(mkfix); review "$F" "$ONE_OPEN"
printf 'docs/scratch/\n' >> "${F}/.gitignore"
git -C "$F" add .gitignore; git -C "$F" commit -qm ignore-scratch
mkdir -p "${F}/docs/scratch"
B=$(baseline_of "$F")
awk 'BEGIN { for (i = 1; i <= 10; i++) print "s " i }' > "${F}/docs/scratch/notes.md"
printf 'edit\n' >> "${F}/docs/workflow.md"
plan "$F" "$B" 'the suite' 1 \
  '| 1 | fix | docs/workflow.md:10 | 1 | none |' \
  '| 1 | fix | docs/scratch/notes.md:1 | 0 | none |'
gate applied "$(prog "$F")"
check "ten lines written to a gitignored path fire neither arm" "$RC" "0"
has   "  only the real file is charged" "$OUT" "actual_changed_lines=1"
hasnt "  and the gitignored path appears in no verdict field" "$OUT" "docs/scratch"
has   "  the in-round ignore list is a different exclusion and counted none" "$OUT" "ignored=0"
gate plan "$(prog "$F")"
check "  and the declared side agrees, 0 for that row" "$RC" "0"
has   "  on the same figure the applied side measured" "$OUT" "A4   size                 pass  declared 1 of 150"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
mkdir -p "${F}/docs/kept"
awk 'BEGIN { for (i = 1; i <= 10; i++) print "s " i }' > "${F}/docs/kept/notes.md"
printf 'edit\n' >> "${F}/docs/workflow.md"
plan "$F" "$B" 'the suite' 11 \
  '| 1 | fix | docs/workflow.md:10 | 1 | none |' \
  '| 1 | fix | docs/kept/notes.md:1 | 10 | none |'
gate applied "$(prog "$F")"
check "control: the identical write to a NON-gitignored path IS charged" "$RC" "0"
has   "  both contributions sum" "$OUT" "actual_changed_lines=11"
has   "  and arm (a) matched both planned paths" "$OUT" "(a)  unplanned-file       pass"

printf '\n== T1-ZA arm (a) admits fix-row targets only ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"; B=$(baseline_of "$F")
OBJ_ROW='| 2 | object: the cited form is the documented one | docs/other.md:5 | 0 | none |'
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |' "$OBJ_ROW"
printf 'edit\n' >> "${F}/docs/workflow.md"; printf 'edit\n' >> "${F}/docs/other.md"
gate applied "$(prog "$F")"
check "a file named only by an objected row is not pre-authorised" "$RC" "1"
has   "  decision" "$OUT" "decision=FINDING reason=unplanned-file"
has   "  and the objected row's target is the one named" "$OUT" "(a)  unplanned-file       FAIL  docs/other.md"
hasnt "  while the fix row's target is not flagged" "$OUT" "docs/workflow.md"

F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |' "$OBJ_ROW"
printf 'edit\n' >> "${F}/docs/workflow.md"
gate applied "$(prog "$F")"
check "control: a fix-row target is still admitted" "$RC" "0"
has   "  decision" "$OUT" "decision=OK"

F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |' '| 2 | fix | docs/other.md:5 | 0 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"; printf 'edit\n' >> "${F}/docs/other.md"
gate applied "$(prog "$F")"
check "control: the same two-row plan with row 2 as a fix admits both" "$RC" "0"
has   "  so the arm keys on the disposition, not the row's position" "$OUT" "decision=OK"

# The allowed set is also asserted on its CONSTRUCTION, which pins the filter
# itself rather than one of its consequences; T1-ZG asserts the `amendment:`
# half end to end. `grep -F`, because `$(` in a basic regular expression can
# never match -- `$` anchors end-of-line, and the empty result reads as drift.
ALLOWED=$(grep -F 'planned=$(table_rows' "$GATE")
check "the allowed-set construction was found at all" "$(printf '%s\n' "$ALLOWED" | grep -c .)" "1"
has   "  and it admits a row only when its disposition is exactly fix" "$ALLOWED" '$3 == "fix"'
hasnt "  so an amendment row cannot widen it" "$ALLOWED" 'amendment'
hasnt "  nor can an objected row" "$ALLOWED" 'object'

printf '\n== T1-ZF the amendment-then-resume round: ai-docs/plans/ excluded and NAMED ==\n'
# SKILL.md mandates resuming the round after an amendment while `baseline`
# refuses a second stub, so the round keeps a round_base taken BEFORE the
# amendment wrote to a spec or design artefact -- and A2/A3 forbid any passing
# plan from PROPOSING AN EDIT to those two SUFFIXES, a `fix` row naming one
# routing while a row proposing no edit briefs nothing. Arm (a) therefore fired by
# construction on every such round, permanently. The exclusion closes that, and
# the `excluded-in-round` LINE is what keeps it a narrowing rather than an
# amnesty: the header's `ignored=` carries a COUNT ONLY, so a leg reading the
# header is satisfied by `ignored=2` while no path is named anywhere.
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
# Both artefacts are under the prefix and NOT gitignored, so this leg measures
# the prefix exclusion ALONE. The two exclusions overlap on a `.progress.md`
# under the same prefix, and a leg over a doubly-excluded path measures neither.
if git -C "$F" check-ignore -q ai-docs/plans/t.spec.md
then bad "the fixture's spec artefact is gitignored, so this leg measures the other exclusion"
else ok  "the fixture's spec artefact is excluded by the prefix alone, not by .gitignore"; fi
if git -C "$F" check-ignore -q ai-docs/plans/done/t.design.md
then bad "the fixture's design artefact is gitignored, so this leg measures the other exclusion"
else ok  "the fixture's design artefact is excluded by the prefix alone, not by .gitignore"; fi
awk 'BEGIN { for (i = 1; i <= 10; i++) print "amended spec " i }'   >> "${F}/ai-docs/plans/t.spec.md"
awk 'BEGIN { for (i = 1; i <= 10; i++) print "amended design " i }' >> "${F}/ai-docs/plans/done/t.design.md"
printf 'edit\n' >> "${F}/docs/workflow.md"
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |'
gate applied "$(prog "$F")"
check "a round whose baseline predates an amendment is OK" "$RC" "0"
has   "  decision" "$OUT" "decision=OK"
has   "  arm (a) names neither plan artefact" "$OUT" "(a)  unplanned-file       pass"
has   "  the measurement charges the briefed file and nothing else" "$OUT" "actual_changed_lines=1"
has   "  and the exclusion is counted" "$OUT" "ignored=2"
EXCL=$(printf '%s\n' "$OUT" | grep 'excluded-in-round')
has   "  the excluded-in-round line NAMES the spec artefact" "$EXCL" "ai-docs/plans/t.spec.md"
has   "  and NAMES the design artefact" "$EXCL" "ai-docs/plans/done/t.design.md"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
awk 'BEGIN { for (i = 1; i <= 10; i++) print "amended spec " i }' >> "${F}/ai-docs/plans/t.spec.md"
printf 'edit\n' >> "${F}/docs/workflow.md"
printf 'edit\n' >> "${F}/docs/other.md"
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |'
gate applied "$(prog "$F")"
check "control: an unbriefed file OUTSIDE the prefix is still a finding" "$RC" "1"
has   "  decision" "$OUT" "decision=FINDING reason=unplanned-file"
ARMA=$(printf '%s\n' "$OUT" | grep -F '(a)')
has   "  named on arm (a) by itself" "$ARMA" "docs/other.md"
hasnt "  so the entry is a suffix exclusion, not a blanket amnesty" "$ARMA" "ai-docs/plans/"

# The NON-ROUTING control, and the reason the exclusion is two suffixes rather
# than the directory: A2/A3 key on two filename suffixes, so a tracked path
# under the same directory that is NEITHER suffix is briefable by a passing plan
# -- and a directory-wide exclusion then drops those BRIEFED lines from the
# measured total, declared against zero measured. This leg is the discriminator
# between the two spellings, which are otherwise observationally identical.
F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"; B=$(baseline_of "$F")
EVID='ai-docs/plans/t.design-evidence.md'
if git -C "$F" check-ignore -q "$EVID"
then bad "the non-routing fixture is gitignored, so this leg measures the other exclusion"
else ok  "the non-routing fixture is tracked and excluded by neither .gitignore nor a suffix"; fi
plan "$F" "$B" 'the suite' 2 '| 1 | fix | docs/workflow.md:10 | 1 | none |' "| 2 | fix | ${EVID}:2 | 1 | none |"
gate plan "$(prog "$F")"
check "a non-routing path under ai-docs/plans/ may be briefed by a passing plan" "$RC" "0"
has   "  because the routing arms key on two suffixes, not on the directory" "$OUT" "decision=PASS"
printf 'edit\n' >> "${F}/docs/workflow.md"
printf 'edit\n' >> "${F}/${EVID}"
gate applied "$(prog "$F")"
check "and the lines it briefed are MEASURED rather than excluded" "$RC" "0"
has   "  decision" "$OUT" "decision=OK"
has   "  both briefed edits are charged to the round" "$OUT" "actual_changed_lines=2"
has   "  and nothing was excluded, so no declared-vs-actual gap opens" "$OUT" "ignored=0"

# The same path in the other direction, which is what pins arm (a) itself: edited
# and named by NO row, it must FLAG. Under the directory-wide form it was silently
# excluded and the verdict stayed OK -- so the two legs together are the pair that
# tells the two spellings apart, one on the measurement and one on the arm.
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
printf 'edit\n' >> "${F}/docs/workflow.md"
printf 'edit\n' >> "${F}/${EVID}"
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |'
gate applied "$(prog "$F")"
check "an UNNAMED edit to a non-routing path under the prefix is a finding" "$RC" "1"
has   "  decision" "$OUT" "decision=FINDING reason=unplanned-file"
ARMA=$(printf '%s\n' "$OUT" | grep -F '(a)')
has   "  named on arm (a) like any other unplanned path" "$ARMA" "$EVID"
hasnt "  rather than being quietly excluded instead" "$OUT" "excluded-in-round"

printf '\n== T1-ZG the amendment row END TO END, not on the construction ==\n'
# T1-ZA asserts the `amendment:` half on the allowed-set expression because
# `applied` was believed unreachable for a routing round. It is reachable on
# every amendment-then-resume round, so the half is written out: the plan ROUTES
# at the `plan` verb, the round resumes, and `applied` then runs against the
# pre-amendment baseline.
F=$(mkfix); review "$F" "$ONE_OPEN" "$TWO_OPEN"; B=$(baseline_of "$F")
AMEND_ROW='| 2 | amendment: spec | ai-docs/plans/t.spec.md:4 | 6 | none |'
plan "$F" "$B" 'the suite' 7 '| 1 | fix | docs/workflow.md:10 | 1 | none |' "$AMEND_ROW"
gate plan "$(prog "$F")"
check "the plan routes rather than passing" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-SPEC"
printf 'amended\n' >> "${F}/ai-docs/plans/t.spec.md"
printf 'edit\n'    >> "${F}/docs/workflow.md"
printf 'edit\n'    >> "${F}/docs/other.md"
gate applied "$(prog "$F")"
check "and applied IS reached for that round" "$RC" "1"
has   "  decision" "$OUT" "decision=FINDING reason=unplanned-file"
ARMA=$(printf '%s\n' "$OUT" | grep -F '(a)')
has   "  arm (a) names the file nobody's row touched" "$ARMA" "docs/other.md"
hasnt "  not the amendment's own plan artefact" "$ARMA" "ai-docs/plans/t.spec.md"
hasnt "  nor the briefed fix target" "$ARMA" "docs/workflow.md"
EXCL=$(printf '%s\n' "$OUT" | grep 'excluded-in-round')
has   "  while the amendment's write is NAMED as excluded" "$EXCL" "ai-docs/plans/t.spec.md"

printf '\n== T1-H applied arm (a): unplanned files ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 3 '| 1 | fix | docs/workflow.md:10 | 3 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"
gate applied "$(prog "$F")"
check "only planned files is OK" "$RC" "0"
has   "  decision" "$OUT" "decision=OK"
has   "  arm (a) passes" "$OUT" "(a)  unplanned-file       pass"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 3 '| 1 | fix | docs/workflow.md:10 | 3 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"; printf 'edit\n' >> "${F}/docs/other.md"
gate applied "$(prog "$F")"
check "an unplanned tracked file edited is a finding" "$RC" "1"
has   "  decision" "$OUT" "decision=FINDING reason=unplanned-file"
has   "  names the path" "$OUT" "(a)  unplanned-file       FAIL  docs/other.md"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 3 '| 1 | fix | docs/workflow.md:10 | 3 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"; printf 'new\n' > "${F}/docs/created.md"
gate applied "$(prog "$F")"
check "an unplanned file CREATED this round is a finding" "$RC" "1"
has   "  names the path" "$OUT" "docs/created.md"

printf '\n== T1-I applied REPORTS the measurement; the size arm is gone ==\n'
# Arm (b) is withdrawn, so nothing post-apply compares a total against a limit.
# What survives is the MEASUREMENT the header reports, and these fixtures -- a
# tracked and an untracked contribution -- are kept for the counting basis
# behind it. The leg asserts the reported figure and the ABSENCE of any verdict
# against the old boundary; asserting that boundary either way would assert a
# mechanism that no longer exists.
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 150 '| 1 | fix | docs/new.md:1 | 150 | none |'
awk 'BEGIN { for (i = 1; i <= 150; i++) print "n " i }' > "${F}/docs/new.md"
gate applied "$(prog "$F")"
check "a round at the old boundary is OK" "$RC" "0"
has   "  the total is the untracked file's whole length" "$OUT" "actual_changed_lines=150"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 151 '| 1 | fix | docs/new.md:1 | 151 | none |'
awk 'BEGIN { for (i = 1; i <= 151; i++) print "n " i }' > "${F}/docs/new.md"
gate applied "$(prog "$F")"
check "a round PAST the old boundary is OK too -- no size arm fires" "$RC" "0"
has   "  decision" "$OUT" "decision=OK"
has   "  while the measurement is still reported" "$OUT" "actual_changed_lines=151"
hasnt "  no overrun reason token survives" "$OUT" "actual-overrun"
hasnt "  no second arm line at all" "$OUT" "(b)"
hasnt "  and no limit is printed where nothing enforces one" "$OUT" "threshold_changed_lines"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 160 '| 1 | fix | docs/workflow.md:1 | 40 | none |' '| 1 | fix | docs/new.md:1 | 120 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"
awk 'BEGIN { for (i = 1; i <= 151; i++) print "n " i }' > "${F}/docs/new.md"
gate applied "$(prog "$F")"
has "a tracked and an untracked contribution sum into one total" "$OUT" "actual_changed_lines=152"

printf '\n== T1-J the cannot-run lanes ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" '' 'the suite' 3 "$ONE_FIX"
gate applied "$(prog "$F")"
check "an absent round_base is exit 2, not a pass" "$RC" "2"
has   "  reason named" "$OUT" "carries no round_base"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" 0000000000000000000000000000000000000000 'the suite' 3 "$ONE_FIX"
gate applied "$(prog "$F")"
check "a round_base that resolves to nothing is exit 2" "$RC" "2"
has   "  reason names the value" "$OUT" "does not resolve to a tree in this repository"

F=$(mkfix); review "$F" "$ONE_OPEN"
gate applied "$(prog "$F")"
check "applied with no plan section is exit 2" "$RC" "2"
has   "  reason named" "$OUT" "no ## Fix Plan (Round N) section"

BARE=$(mktemp -d); git -C "$BARE" init -q .; mkdir -p "${BARE}/ai-docs/plans"
printf '# P\n\n## Self-Review (Round 1)\n' > "${BARE}/ai-docs/plans/t.progress.md"
gate baseline "${BARE}/ai-docs/plans/t.progress.md"
check "baseline on a tree with no HEAD is exit 2" "$RC" "2"
has   "  reason named" "$OUT" "could not compute a baseline tree, which is not a pass"
check "  and no stub was written" "$(grep -c 'Fix Plan' "${BARE}/ai-docs/plans/t.progress.md")" "0"

F=$(mkfix); printf '# P\n' > "$(prog "$F")"
gate baseline "$(prog "$F")"
check "baseline with no review round is exit 2" "$RC" "2"
has   "  reason named" "$OUT" "no ## Self-Review (Round N) section"

printf '\n== baseline writes a stub that cannot pass unfilled ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
gate baseline "$(prog "$F")"
check "baseline exits 0" "$RC" "0"
has   "  prints the sha it recorded" "$OUT" "round_base="
hasnt "  and no longer prints a limit it never fires on" "$OUT" "threshold_changed_lines"
STUB=$(sed -n '/## Fix Plan/,$p' "$(prog "$F")")
has "the stub carries the round heading"     "$STUB" "## Fix Plan (Round 1)"
has "the stub carries the basis in the column heading" "$STUB" "Expected changed lines (max(added,removed))"
has "the stub leaves verification for the scout" "$STUB" "**verification:**"
gate plan "$(prog "$F")"
check "an unfilled stub REFUSES rather than passing" "$RC" "1"
has   "  the verification arm fires" "$OUT" "A5   verification-named   FAIL"
gate baseline "$(prog "$F")"
check "a second baseline for the same round is exit 2" "$RC" "2"
has   "  reason named" "$OUT" "already carries a ## Fix Plan (Round 1) section"

printf '\n== T1-K the round-1 leak: last round'"'"'s work is not charged to this one ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
printf 'r1a\nr1b\nr1c\n' > "${F}/docs/round1-untracked.md"
printf 'r1\n' >> "${F}/docs/other.md"
B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 4 \
  '| 1 | fix | docs/round1-untracked.md:1 | 2 | none |' \
  '| 1 | fix | docs/round2-new.md:1 | 2 | none |'
printf 'r1a\nr1b-changed\nr1c\nr1d\n' > "${F}/docs/round1-untracked.md"
printf 'r2\nr2\n' > "${F}/docs/round2-new.md"
gate applied "$(prog "$F")"
check "the round is OK" "$RC" "0"
has   "  the untracked file is charged its DELTA, not its length" "$OUT" "actual_changed_lines=4"
has   "  and the round-1 tracked edit fires neither arm" "$OUT" "(a)  unplanned-file       pass"

printf '\n== T1-L the in-round ignore list is narrow and never silent ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"
printf 'a new learning\n' >> "${F}/ai-docs/learnings/b.md"
printf 'an archive line\n' >> "${F}/ai-docs/learnings.md"
gate applied "$(prog "$F")"
check "both ignore-list paths fire neither arm" "$RC" "0"
has   "  and the exclusion is counted in the header" "$OUT" "ignored=2"
has   "  and every excluded path is named" "$OUT" "ai-docs/learnings.md ai-docs/learnings/b.md"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |'
printf 'edit\n' >> "${F}/docs/workflow.md"
printf 'not ignored\n' >> "${F}/ai-docs/learnings-notes.md"
gate applied "$(prog "$F")"
check "a path one character outside the list DOES fire" "$RC" "1"
has   "  named as unplanned" "$OUT" "ai-docs/learnings-notes.md"
has   "  and nothing was excluded" "$OUT" "ignored=0"

printf '\n== T1-M the counting basis: a modified line counts once ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 80 '| 1 | fix | docs/workflow.md:10 | 80 | none |'
awk 'BEGIN { for (i = 1; i <= 80; i++) print "rewritten " i }' > "${F}/docs/workflow.md"
gate applied "$(prog "$F")"
check "80 rewritten lines is 80, not 160" "$RC" "0"
has   "  the total" "$OUT" "actual_changed_lines=80"
hasnt "  and not added+removed" "$OUT" "actual_changed_lines=160"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 160 '| 1 | fix | docs/workflow.md:10 | 160 | none |'
awk 'BEGIN { for (i = 1; i <= 160; i++) print "rewritten " i }' > "${F}/docs/workflow.md"
gate applied "$(prog "$F")"
# Re-pointed with arm (b): this sub-leg's subject is the BASIS at a larger
# figure, and the verdict it used to assert was the deleted size arm's. Past the
# old boundary the verb is now OK, so asserting the refusal here would assert a
# mechanism that is gone.
check "160 rewritten lines is 160, and no size arm fires on it" "$RC" "0"
has   "  the total" "$OUT" "actual_changed_lines=160"

F=$(mkfix); review "$F" "$ONE_OPEN"
awk 'BEGIN { for (i = 1; i <= 80; i++) print "rewritten " i }' > "${F}/docs/workflow.md"
git -C "$F" add -A; git -C "$F" commit -qm round0
review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 80 '| 1 | fix | docs/workflow.md:10 | 80 | none |'
awk 'BEGIN { for (i = 1; i <= 80; i++) print "again " i }' > "${F}/docs/workflow.md"
gate applied "$(prog "$F")"
has "a plan declaring 80 and a diff measuring 80 agree on the same tree" "$OUT" "actual_changed_lines=80"
gate plan "$(prog "$F")"
has "  and the declared side passes on that same figure" "$OUT" "A4   size                 pass  declared 80 of 150"

printf '\n== T1-N deletions, binaries, renames ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
printf 'u1\nu2\nu3\nu4\n' > "${F}/docs/gone-untracked.md"
B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 44 \
  '| 1 | fix | docs/other.md:1 | 40 | none |' \
  '| 1 | fix | docs/gone-untracked.md:1 | 4 | none |'
rm -f "${F}/docs/other.md" "${F}/docs/gone-untracked.md"
gate applied "$(prog "$F")"
has "a deleted tracked file and a deleted untracked one both charge their length" "$OUT" "actual_changed_lines=44"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 0 '| 1 | fix | docs/blob.bin:1 | 0 | none |'
printf 'a\000b\001c\002binary\000payload\n' > "${F}/docs/blob.bin"
gate applied "$(prog "$F")"
check "a binary path is OK" "$RC" "0"
has   "  contributes nothing to the total" "$OUT" "actual_changed_lines=0"
has   "  is counted in the header" "$OUT" "binary=1"
has   "  and is NAMED rather than silently absent" "$OUT" "binary-no-line-count 1     docs/blob.bin"

F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 80 \
  '| 1 | fix | docs/other.md:1 | 40 | none |' \
  '| 1 | fix | docs/renamed.md:1 | 40 | none |'
git -C "$F" mv docs/other.md docs/renamed.md
gate applied "$(prog "$F")"
check "a 40-line pure rename is OK against a plan declaring 2N" "$RC" "0"
has   "  and charges 2N" "$OUT" "actual_changed_lines=80"
has   "  arm (a) matched both plain paths" "$OUT" "(a)  unplanned-file       pass"

# Rename detection stays OFF on purpose: with -M the two rows collapse to one
# `from => to` path, which matches no planned Target, so arm (a) would report
# every rename as an unplanned file. This pins the absence.
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 80 '| 1 | fix | docs/other.md:1 | 80 | none |'
git -C "$F" mv docs/other.md docs/renamed.md
gate applied "$(prog "$F")"
hasnt "no verdict ever carries the collapsed rename path form" "$OUT" "=>"
has   "  the destination surfaces as a plain path" "$OUT" "docs/renamed.md"

printf '\n== T1-P escaped pipes round-trip through the positional split ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
# The quoted cell is pinned to a REAL pipe-bearing row verbatim rather than to a
# hand-written approximation, so the leg exercises the escaped pipe all the way
# through to the content match against the file -- a placeholder quote would
# round-trip through the split and then fail to locate anything.
{ awk 'BEGIN { for (i = 1; i <= 4; i++) print "line " i }'
  printf '| Setting | Value | Meaning of the row that stands |\n'; } > "${F}/docs/table.md"
plan "$F" x 'the suite' 7 '| 1 | object: the row reads \| a \| b \| and stands | docs/workflow.md:10 | 7 | "\| Setting \| Value \| Meaning of the row that stands \|" — `docs/table.md:5` |'
gate plan "$(prog "$F")"
check "escaped pipes in both free-text columns shift no later field" "$RC" "0"
has   "  the Arm A anchor BEHIND the pipes was still found" "$OUT" "A1   anchor-resolution    pass"
has   "  and the row's figure reached the size arm intact" "$OUT" "declared 7 of 150"
hasnt "  and the restored pipes matched the file's own row" "$OUT" "arma-quote-unverified"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 7 '| 1 | object: the row reads | a | b | and stands | docs/workflow.md:10 | 7 | "a | b | c" — `docs/other.md:5` |'
gate plan "$(prog "$F")"
check "the same row with RAW pipes is refused, not misread" "$RC" "1"
has   "  the parser names the cell count rather than guessing" "$OUT" "the row holds 10 cells, the format holds 5"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 7 '| 1 | nope \| still nope | docs/workflow.md:10 | 7 | none |'
gate plan "$(prog "$F")"
has "a cell echoed into a verdict carries a real pipe" "$OUT" "disposition [nope | still nope]"
check "and no placeholder leaks into the output" "$(printf '%s' "$OUT" | tr -dc '\001\002' | wc -c | tr -d ' ')" "0"

printf '\n== T1-Q neither verb mutates the repository ==\n'
F=$(mkfix); review "$F" "$ONE_OPEN"
printf 'dirty\n' >> "${F}/docs/workflow.md"; printf 'untracked\n' > "${F}/docs/u.md"
IDX_BEFORE=$(shasum "${F}/.git/index" | cut -d' ' -f1)
ST_BEFORE=$(git -C "$F" status --short)
B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 1 '| 1 | fix | docs/workflow.md:10 | 1 | none |'
"$GATE" plan "$(prog "$F")" >/dev/null 2>&1
"$GATE" applied "$(prog "$F")" >/dev/null 2>&1
check "the real index is byte-identical afterwards" "$(shasum "${F}/.git/index" | cut -d' ' -f1)" "$IDX_BEFORE"
check "git status --short is byte-identical afterwards" "$(git -C "$F" status --short)" "$ST_BEFORE"

printf '\n== T1-R the highest round is the one gated ==\n'
F=$(mkfix)
{
  for n in 1 2; do
    printf '\n## Self-Review (Round %s)\n\n| # | File:line | Severity | Finding | Status |\n|---|---|---|---|---|\n' "$n"
    printf '| 1 | docs/workflow.md:10 | nit | x | ✅ Fixed |\n'
  done
  printf '\n## Self-Review (Round 3)\n\n| # | File:line | Severity | Finding | Status |\n|---|---|---|---|---|\n'
  printf '| 7 | docs/other.md:5 | major | y | %s |\n' "$OPEN"
  for n in 1 2; do
    printf '\n## Fix Plan (Round %s)\n\n**round_base:** r%s\n**verification:** stale\n**declared_changed_lines:** 9999\n\n' "$n" "$n"
    printf '| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |\n|---|---|---|---|---|\n'
    printf '| 1 | fix | docs/gone.md:1 | 9999 | none |\n'
  done
  printf '\n## Fix Plan (Round 3)\n\n**round_base:** r3\n**verification:** the suite\n**declared_changed_lines:** 5\n\n'
  printf '| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |\n|---|---|---|---|---|\n'
  printf '| 7 | fix | docs/other.md:5 | 5 | none |\n'
} >> "$(prog "$F")"
gate plan "$(prog "$F")"
check "round 3 is gated while rounds 1 and 2 hold poison" "$RC" "0"
has   "  the round is reported" "$OUT" "round=3"
has   "  and the stale rounds' figures are absent" "$OUT" "declared 5 of 150"
hasnt "  no stale total leaks in" "$OUT" "9999"
has   "  the round's own open finding was matched" "$OUT" "A6   finding-coverage     pass  1 open findings"

printf '\n== T1-ZE every shipped plan example parses under the gate own extractor ==\n'
# The extractor is LIFTED from the shipped gate by function name rather than
# reimplemented: a second copy of that matcher is a second thing to drift, and
# a leg built on the copy tests the lookalike. The lift carries an apply-proof
# because `eval` of an empty extraction defines nothing and every assertion
# below would then read "no anchor" as the instruction file's fault.
LIFT=$(awk '/^arma_anchor\(\)/, /^}$/' "$GATE")
has   "the extractor text was lifted from the gate" "$LIFT" 'arma_anchor()'
has   "  carrying its no-space, numeric-line matcher" "$LIFT" ':[0-9]+$'
eval "$LIFT"
check "  and it is a shell function in this suite" "$(type -t arma_anchor)" "function"
check "  positive control: a well-formed cell yields its anchor" \
      "$(arma_anchor '`docs/workflow.md:215` — "s"')" "docs/workflow.md:215"
check "  negative control: a cell carrying no anchor yields nothing" \
      "$(arma_anchor 'the sentence, unbackticked, docs/workflow.md:215')" ""

# Only Arm A cells that are not `none` are in scope: the gate tests
# `arma != none` before calling the extractor, and the first rows of both
# examples are `none`, so an unscoped leg would fail on correct rows.
PLAN_CELLS=$(mktemp)
for p in agents/fix-scout.md docs/templates/progress-format.md; do
  awk -v src="$p" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    index($0, "| # | Disposition | Target file:line |") == 1 { intbl = 1; next }
    intbl && $0 !~ /^[[:space:]]*\|/ { intbl = 0 }
    intbl {
      n = split($0, f, "|")
      if (n < 7) next
      if (trim(f[2]) ~ /^-+$/) next
      cell = trim(f[6])
      if (cell == "" || cell == "none") next
      print src "\t" cell
    }' "${REPO}/${p}" >> "$PLAN_CELLS"
done
CELLS=$(grep -c . "$PLAN_CELLS")
if [ "$CELLS" -ge 2 ]; then ok "the scan reads ${CELLS} non-none Arm A cells from the shipped examples"
else bad "the scan reads ${CELLS} non-none Arm A cells -- an empty input set is not agreement"; fi
NOANCHOR=''
while IFS=$'\t' read -r src cell; do
  [ -n "$(arma_anchor "$cell")" ] || NOANCHOR="${NOANCHOR}${NOANCHOR:+; }${src} [${cell}]"
done < "$PLAN_CELLS"
check "every shipped plan example yields the anchor it appears to carry" "$NOANCHOR" ""

SENTENCE='The orchestrator accounts for every named path against the amendment it ran.'
quotefix() { # <fixture> -> docs/quoted.md, 30 lines, SENTENCE verbatim at line 10
  { awk 'BEGIN { for (i = 1; i <= 9; i++) print "preamble " i }'
    printf '%s\n' "$SENTENCE"
    awk 'BEGIN { for (i = 1; i <= 20; i++) print "trailer " i }'; } > "${1}/docs/quoted.md"
}

printf '\n== T1-ZH a fabricated but RESOLVABLE citation is refused ==\n'
# File-exists plus line-in-range accepts a citation whose sentence sits nowhere
# near the line, which is a prediction wearing a plan's clothes. A1's precedence
# over amendment routing was granted on the premise that an unopened anchor is
# fatal, so this REFUSES rather than warning -- a warning would restore exactly
# the pass being closed.
F=$(mkfix); review "$F" "$ONE_OPEN"; quotefix "$F"
plan "$F" x 'the suite' 12 '| 1 | fix | docs/quoted.md:10 | 12 | `docs/quoted.md:10` — "A sentence that appears nowhere in that file at all." |'
gate plan "$(prog "$F")"
check "a quote absent from the cited line refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  on its own arm line, because the remedy is re-read the file" "$OUT" "A1   arma-quote-unverified"
has   "  while the anchor itself is reported as resolving" "$OUT" "A1   anchor-resolution    pass"

F=$(mkfix); review "$F" "$ONE_OPEN"; quotefix "$F"
plan "$F" x 'the suite' 12 "| 1 | fix | docs/quoted.md:10 | 12 | \`docs/quoted.md:10\` — \"${SENTENCE}\" |"
gate plan "$(prog "$F")"
check "control: the sentence actually AT that line passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
hasnt "  so the arm does not refuse everything" "$OUT" "arma-quote-unverified"

printf '\n== T1-ZI the usability set: re-wrap, elision, order, and the floor ==\n'
# Refusing a correct citation is the failure to avoid above all others: this
# repository hard-wraps prose, so a quoted sentence routinely spans three lines
# and a single-line match would refuse the plans that did open their anchors.
WRAP1='The orchestrator reads the excluded-in-round line and accounts'
WRAP2='for every named path against the amendment it knows it ran; a'
WRAP3='named path it cannot account for is a finding.'
wrapfix() { # <fixture> -> docs/wrapped.md, one sentence hard-wrapped at 10-12
  { awk 'BEGIN { for (i = 1; i <= 9; i++) print "preamble " i }'
    printf '%s\n%s\n%s\n' "$WRAP1" "$WRAP2" "$WRAP3"
    awk 'BEGIN { for (i = 1; i <= 20; i++) print "trailer " i }'; } > "${1}/docs/wrapped.md"
}
armarow() { # <quote> -> a one-row plan citing docs/wrapped.md:11
  printf '| 1 | fix | docs/wrapped.md:11 | 12 | `docs/wrapped.md:11` — "%s" |' "$1"
}

F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow "${WRAP1} ${WRAP2} ${WRAP3}")"
gate plan "$(prog "$F")"
check "a sentence hard-wrapped across three lines, quoted as one, passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow "${WRAP1}…${WRAP3}")"
gate plan "$(prog "$F")"
check "a quote eliding its middle, fragments in order, passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow "${WRAP1}…a fragment that is simply not in that file.")"
gate plan "$(prog "$F")"
check "one fragment absent refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  naming the fragment and the window" "$OUT" "is absent from lines 8-14"

F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow "${WRAP3}…${WRAP1}")"
gate plan "$(prog "$F")"
check "both fragments present but out of ORDER refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  distinguished from absent, because the remedy differs" "$OUT" "are out of order"

F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow 'reads the line')"
gate plan "$(prog "$F")"
check "a fragment under the floor refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  as too short to locate, not as not found" "$OUT" "too short to locate a sentence"
hasnt "  so a three-word quote cannot match any window" "$OUT" "is absent from lines"

# That leg quotes text ABSENT from the window, so it refuses with or without the
# floor and asserts the MESSAGE rather than the outcome. The floor's own outcome
# is this: a fragment that IS at the cited line and is still refused for being
# too short to identify a sentence. Presence is proved first, because the leg
# measures nothing if the fragment happens not to be there.
SHORT='is a finding.'
F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
check "the short fragment IS in the window, so the refusal can only be the floor's" \
      "$(grep -cF "$SHORT" "${F}/docs/wrapped.md")" "1"
plan "$F" x 'the suite' 12 "$(armarow "$SHORT")"
gate plan "$(prog "$F")"
check "a fragment under the floor refuses even when it is at the cited line" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  naming the length it measured against the floor" "$OUT" "13 characters -- too short to locate a sentence (minimum 24)"

# The empty-fragment skip is the one clause the implementation argued for against
# the literal rule, so it gets its own legs rather than resting on the argument: a
# leading or trailing `…` yields an empty fragment that carries no claim to locate
# anything, and refusing it would reject citations that are correct.
F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow "…${WRAP3}")"
gate plan "$(prog "$F")"
check "a LEADING elision passes on its one non-empty fragment" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"

F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow "${WRAP1}…")"
gate plan "$(prog "$F")"
check "and a TRAILING elision likewise" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"

# The skip opens no vacuous pass: a quote that is NOTHING but an elision yields
# only empty fragments, locates nothing, and is refused under the floor.
F=$(mkfix); review "$F" "$ONE_OPEN"; wrapfix "$F"
plan "$F" x 'the suite' 12 "$(armarow '…')"
gate plan "$(prog "$F")"
check "a quote that is only an elision refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  as locating no sentence at all, not as absent" "$OUT" "quotes no sentence -- too short to locate a sentence"

printf '\n== T1-ZJ the match window, pinned at its boundary ==\n'
# W is a starting value chosen the way the threshold was, so the verdict reports
# it and the suite pins both sides of it: changing W is then a decision with a
# visible test rather than a retune nobody sees.
F=$(mkfix); review "$F" "$ONE_OPEN"; quotefix "$F"
plan "$F" x 'the suite' 12 "| 1 | fix | docs/quoted.md:7 | 12 | \`docs/quoted.md:7\` — \"${SENTENCE}\" |"
gate plan "$(prog "$F")"
check "a verbatim sentence exactly W lines from the citation passes" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  and the verdict reports the window it searched" "$OUT" "arma_quote_window=3"

F=$(mkfix); review "$F" "$ONE_OPEN"; quotefix "$F"
plan "$F" x 'the suite' 12 "| 1 | fix | docs/quoted.md:6 | 12 | \`docs/quoted.md:6\` — \"${SENTENCE}\" |"
gate plan "$(prog "$F")"
check "one line past W refuses" "$RC" "1"
has   "  decision" "$OUT" "decision=REFUSE reason=arma-quote-unverified"
has   "  naming the window it searched" "$OUT" "lines 3-9"

printf '\n== T1-ZK the routing arms path half keyed on fix rows ==\n'
# Each leg differs from the passing shape in ONE half alone, because a suite
# written against the unqualified rule stays green under the narrowed one.
# The targets are the fixture's REAL four-line artefacts: a fabricated plans
# path fails A1 first, and a leg asserting only "not PASS" would then pass on
# the refusal while measuring nothing about routing.
RESOLVED_DESIGN='| 1 | resolved: the amendment landed in round 9 | ai-docs/plans/done/t.design.md:4 | 0 | none |'
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 "$RESOLVED_DESIGN"
gate plan "$(prog "$F")"
check "a row proposing NO edit does not route on its design target" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  A3 passes" "$OUT" "A3   design-amendment     pass"
hasnt "  and the round is not sent to an amendment recipe" "$OUT" "ROUTE-DESIGN"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | fix | ai-docs/plans/done/t.design.md:4 | 0 | none |'
gate plan "$(prog "$F")"
check "the same row proposing an edit still routes" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-DESIGN reason=design-amendment"

# The control that catches a guard mistakenly wrapped around the disposition
# `case` as well: that mistake reads correct at a glance, because both `case`
# blocks sit adjacent in the same loop body.
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | amendment: spec | docs/workflow.md:10 | 0 | none |'
gate plan "$(prog "$F")"
check "the disposition half is untouched by the narrowing" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-SPEC reason=spec-amendment"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | resolved: the amendment landed | ai-docs/plans/t.spec.md:4 | 0 | none |'
gate plan "$(prog "$F")"
check "a row proposing NO edit does not route on its spec target either" "$RC" "0"
has   "  decision" "$OUT" "decision=PASS"
has   "  A2 passes" "$OUT" "A2   spec-amendment       pass"
hasnt "  and the round is not sent to an amendment recipe" "$OUT" "ROUTE-SPEC"

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 0 '| 1 | fix | ai-docs/plans/t.spec.md:4 | 0 | none |'
gate plan "$(prog "$F")"
check "while the spec side of the edit-proposing half still routes" "$RC" "1"
has   "  decision" "$OUT" "decision=ROUTE-SPEC reason=spec-amendment"

printf '\n== T1-ZL the record verb and the verdict ledger ==\n'
# The rows build through jq, exactly as hooks/lib/loop-verdict.sh builds its
# own, so an absent jq means no row is built and every leg below would measure
# nothing. Named rather than skipped silently.
if command -v jq >/dev/null 2>&1; then ok "jq is present, so a verdict row can be built"
else bad "jq is ABSENT: no verdict row can be built, so every T1-ZL leg below measures nothing"; fi

# The verdict file is a SIBLING of the loop ledger's directory, derived from
# HARNESS_LOOP_DIR so a sandboxed suite stays sandboxed. A single row planted in
# the loop dir itself was measured to move a neighbouring report's project,
# session and verdict counts, so the sibling choice is pinned by a leg rather
# than trusted.
SB=$(mktemp -d); LD="${SB}/loops"; mkdir -p "$LD"; VJ="${SB}/fix-plan/verdicts.jsonl"
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 12 "$ONE_FIX"
OUT=$(HARNESS_LOOP_DIR="$LD" "$GATE" record "$(prog "$F")" 2 7 MATCH 2>&1); RC=$?
check "record exits 0" "$RC" "0"
has   "  it reports the loop's iteration count" "$OUT" "iterations=2"
has   "  and its cost in orchestrator tool calls" "$OUT" "cost_tool_calls=7"
if [ -f "$VJ" ]; then ok "  the row lands in the sibling directory"
else bad "  the row lands in the sibling directory -- nothing at ${VJ}"; fi
check "  and nothing lands in the loop ledger's own directory" "$(ls -1 "$LD" | grep -c .)" "0"
check "  one line per firing" "$(grep -c . "$VJ")" "1"
ROW=$(tail -1 "$VJ")
has   "  the line carries the iteration count" "$ROW" '"iterations":2'
has   "  and the cost, with the unit in the field name" "$ROW" '"cost_tool_calls":7'
has   "  and names itself a verdict, as the shipped rows do" "$ROW" '"kind":"verdict"'
has   "  and is attributable without the filename" "$ROW" "\"round_base\":\"${B}\""

OUT=$(HARNESS_LOOP_DIR="$LD" "$GATE" record "$(prog "$F")" 2 2>&1); RC=$?
check "a missing cost argument is exit 2, never a defaulted zero" "$RC" "2"
has   "  and names the figure it could not read" "$OUT" "cost_tool_calls"
OUT=$(HARNESS_LOOP_DIR="$LD" "$GATE" record "$(prog "$F")" two 7 MATCH 2>&1); RC=$?
check "a non-integer iteration count is exit 2" "$RC" "2"
OUT=$(HARNESS_LOOP_DIR="$LD" "$GATE" record "$(prog "$F")" 2 lots MATCH 2>&1); RC=$?
check "a non-integer cost is exit 2" "$RC" "2"
check "  and no refused call wrote a row" "$(grep -c . "$VJ")" "1"

# The second writer: the pre-apply escalation, which is the one firing that
# carries a threshold value at all.
SB2=$(mktemp -d); LD2="${SB2}/loops"; mkdir -p "$LD2"; VJ2="${SB2}/fix-plan/verdicts.jsonl"
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 151 '| 1 | fix | docs/workflow.md:10 | 151 | none |'
OUT=$(HARNESS_LOOP_DIR="$LD2" "$GATE" plan "$(prog "$F")" 2>&1); RC=$?
check "the pre-apply escalation still escalates" "$RC" "1"
has   "  decision" "$OUT" "decision=ESCALATE reason=size-over-threshold"
check "  and writes one verdict row" "$(grep -c . "$VJ2")" "1"
ROW=$(tail -1 "$VJ2")
has   "  carrying the decision" "$ROW" '"decision":"ESCALATE"'
has   "  and the threshold value it fired under" "$ROW" '"threshold_changed_lines":150'

F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 12 "$ONE_FIX"
OUT=$(HARNESS_LOOP_DIR="$LD2" "$GATE" plan "$(prog "$F")" 2>&1)
has   "a plan that does not escalate still passes" "$OUT" "decision=PASS"
check "  and writes no row, so the ledger counts firings not calls" "$(grep -c . "$VJ2")" "1"

# AC24 asks for the line to be written and explicitly NOT for the round's
# outcome to depend on it.
RO=$(mktemp -d); chmod 500 "$RO"
F=$(mkfix); review "$F" "$ONE_OPEN"
plan "$F" x 'the suite' 151 '| 1 | fix | docs/workflow.md:10 | 151 | none |'
OUT=$(HARNESS_VERDICT_DIR="${RO}/nope" "$GATE" plan "$(prog "$F")" 2>&1); RC=$?
check "an unwritable verdict directory leaves the plan verdict unchanged" "$RC" "1"
has   "  decision" "$OUT" "decision=ESCALATE reason=size-over-threshold"
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 12 "$ONE_FIX"
OUT=$(HARNESS_VERDICT_DIR="${RO}/nope" "$GATE" record "$(prog "$F")" 1 4 MATCH 2>&1); RC=$?
check "and leaves record's own outcome unchanged" "$RC" "0"
chmod 700 "$RO"

# THE ONLY LEG THAT SEPARATES AN `if`-ONLY COPY OF THE SOURCING GUARD FROM A
# CORRECT ONE, and it is why this suite may not source the library directly.
# Measured across four variants: with-`else`+lib, `if`-only+lib and
# with-`else`+no-lib all write the row; `if`-only+no-lib writes NONE. The two
# lib-present variants are indistinguishable, so a suite that sourced
# ledger-write.sh would pass forever while the resolution was never exercised.
NOLIB=$(mktemp -d); mkdir -p "${NOLIB}/skills/task/scripts"
cp "$GATE" "${NOLIB}/skills/task/scripts/check-fix-plan.sh"
chmod +x "${NOLIB}/skills/task/scripts/check-fix-plan.sh"
if [ -e "${NOLIB}/hooks" ]; then bad "the copied tree must have no hooks/lib for this leg to measure anything"
else ok "the copied tree carries no hooks/lib"; fi
SB3=$(mktemp -d); LD3="${SB3}/loops"; mkdir -p "$LD3"; VJ3="${SB3}/fix-plan/verdicts.jsonl"
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 12 "$ONE_FIX"
OUT=$(HARNESS_LOOP_DIR="$LD3" "${NOLIB}/skills/task/scripts/check-fix-plan.sh" record "$(prog "$F")" 3 11 DIVERGE 2>&1); RC=$?
check "the gate invoked BY PATH with no hooks/lib beside it still exits 0" "$RC" "0"
check "  and STILL writes the row -- the else branch is load-bearing" "$(grep -c . "$VJ3")" "1"
has   "  with both figures intact" "$(tail -1 "$VJ3")" '"cost_tool_calls":11'

# The sibling choice, pinned on the neighbouring reader rather than on the path.
SB4=$(mktemp -d); LD4="${SB4}/loops"; mkdir -p "$LD4"
printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","kind":"call","tool":"Bash","fp":"abc","session_id":"s1"}' > "${LD4}/s1.jsonl"
BEFORE=$(HARNESS_LOOP_DIR="$LD4" bash "${REPO}/scripts/loop-metrics.sh" --all --json 2>&1)
has "the neighbouring loop report reads something to begin with" "$BEFORE" '"calls": 1'
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 12 "$ONE_FIX"
NOISE=$(HARNESS_LOOP_DIR="$LD4" "$GATE" record "$(prog "$F")" 1 5 MATCH 2>&1)
has "  and the record verb wrote its row" "$NOISE" "cost_tool_calls=5"
AFTER=$(HARNESS_LOOP_DIR="$LD4" bash "${REPO}/scripts/loop-metrics.sh" --all --json 2>&1)
check "the neighbouring report's own counts are unmoved by the new rows" "$AFTER" "$BEFORE"

printf '\n== T1-ZN the bounded question answer is a closed two-member vocabulary ==\n'
# The answer is VALIDATED and RECORDED, and each accepted word is asserted IN
# the written row rather than inferred from exit 0: a verb that refused an
# invented word and then dropped the accepted one would satisfy a refusal-only
# leg while leaving the retirement data unable to say how often the loop
# answered DIVERGE.
SB5=$(mktemp -d); LD5="${SB5}/loops"; mkdir -p "$LD5"; VJ5="${SB5}/fix-plan/verdicts.jsonl"
F=$(mkfix); review "$F" "$ONE_OPEN"; B=$(baseline_of "$F")
plan "$F" "$B" 'the suite' 12 "$ONE_FIX"
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 MATCH 2>&1); RC=$?
check "MATCH is accepted" "$RC" "0"
has   "  and the human-readable line names the answer" "$OUT" "question_answer=MATCH"
has   "  and the ROW carries it, so the check left evidence it ran" "$(tail -1 "$VJ5")" '"question_answer":"MATCH"'
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 DIVERGE 2>&1); RC=$?
check "DIVERGE is accepted" "$RC" "0"
has   "  and its row carries the other word, so neither is hardcoded" "$(tail -1 "$VJ5")" '"question_answer":"DIVERGE"'
check "  one row per accepted call" "$(grep -c . "$VJ5")" "2"

# MISMATCH IS THE LEG THE VOCABULARY WAS CHOSEN FOR. `MATCH` is a substring of
# it, so a containment comparison -- `case $x in *MATCH*)`, `[[ $x == *MATCH* ]]`,
# a `grep MATCH` -- reports agreement on a diverging round. This leg is what
# separates exact comparison from the sloppy one.
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 MISMATCH 2>&1); RC=$?
check "MISMATCH is refused rather than read as MATCH by containment" "$RC" "2"
has   "  and the refusal names the two words it accepts" "$OUT" "DIVERGE"
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 match 2>&1); RC=$?
check "lower-case match is refused -- the set is the two words as written" "$RC" "2"
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 diverge 2>&1); RC=$?
check "and lower-case diverge likewise, so the case rule is not one-sided" "$RC" "2"
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 agreement 2>&1); RC=$?
check "a word of the run's own invention is refused" "$RC" "2"
OUT=$(HARNESS_LOOP_DIR="$LD5" "$GATE" record "$(prog "$F")" 2 7 2>&1); RC=$?
check "a missing answer is exit 2, on the lane the two figures already use" "$RC" "2"
has   "  and names the argument it could not read" "$OUT" "answer"
check "  and no refused call wrote a row" "$(grep -c . "$VJ5")" "2"

printf '\n== T1-X the entry point the skill invokes is executable ==\n'
if [ -x "$GATE" ]; then ok "check-fix-plan.sh carries the execute bit"
else bad "check-fix-plan.sh carries the execute bit"; fi
MODE=$(git -C "$REPO" ls-files -s -- skills/task/scripts/check-fix-plan.sh | awk '{ print $1 }')
check "the mode git records is 100755" "$MODE" "100755"

printf '\n== usage ==\n'
gate bogus /dev/null
check "an unknown verb is exit 2" "$RC" "2"
has   "  and says what the verbs are" "$OUT" "baseline|plan|applied"
has   "  including the fourth, with all three of its required arguments" "$OUT" "record <progress-file> <iterations> <cost_tool_calls> <answer>"
has   "  and names the two words the answer may be" "$OUT" "exactly one of MATCH or DIVERGE"
OUT=$("$GATE" plan 2>&1); RC=$?
check "a missing progress-file argument is exit 2" "$RC" "2"
OUT=$("$GATE" plan /nope/nope.md 2>&1); RC=$?
check "a missing progress file is exit 2" "$RC" "2"
has   "  names the path" "$OUT" "no such progress file"

# LAST, so it covers every gate invocation this suite makes, usage legs included.
printf '\n== T1-ZM no leg writes to the real verdict ledger ==\n'
# The control comes first: without a row in the suite's own default location the
# untouched-assertion below is vacuous -- a gate that wrote nowhere at all would
# satisfy it forever, including after a regression that stopped the writer.
SUITE_ROWS=0
if [ -f "$SUITE_VJ" ]; then SUITE_ROWS=$(grep -c . "$SUITE_VJ"); fi
if [ "$SUITE_ROWS" -gt 0 ]; then ok "the escalating legs' rows landed in the suite's sandbox (${SUITE_ROWS})"
else bad "the escalating legs' rows landed in the suite's sandbox -- nothing at ${SUITE_VJ}, so the next assertion measures nothing"; fi
check "and the real ledger has the row count it had before the suite ran" "$(default_vj_rows)" "$DEFAULT_VJ_BEFORE"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
