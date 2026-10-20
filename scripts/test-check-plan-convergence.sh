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
mkdir -p "$T/docs" "$T/scripts" "$T/plans" "$T/skills/task/scripts"
cp "${ROOT}/docs/plan-invariants.md" "$T/docs/plan-invariants.md"
# The real file, not a stub: the minimum fragment length is BORROWED from it,
# so a fixture carrying an invented assignment would test the fixture.
cp "${ROOT}/skills/task/scripts/check-fix-plan.sh" "$T/skills/task/scripts/"
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
DESIGN_FIFTH=$(tok design 5)
DESIGN_SECOND_NAME=${DESIGN_SECOND#\#\# }
SPEC_FIRST_NAME=${SPEC_FIRST#\#\# }
[ -n "$SPEC_FIRST" ] && [ -n "$DESIGN_FIRST" ] && [ -n "$DESIGN_SECOND" ] && [ -n "$DESIGN_FIFTH" ] \
  && ok "the fixtures' section names were derived from the record" \
  || bad "the fixtures' section names were derived from the record"

run() { bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1; }

write_pair() { # <spec body> <design body>
  printf '# Spec\n\n%s\n\n%s\n' "$SPEC_FIRST" "$1" > "$T/plans/a.spec.md"
  printf '# Design\n\n%s\n\n%s\n' "$DESIGN_FIRST" "$2" > "$T/plans/a.design.md"
}

# THE RECORD THE REFERENCE CLASS COMPARES AGAINST IS SEEDED FROM THE TREE THESE
# FIXTURES START WITH, never typed: the copied real files carry positions of
# their own, and a hand-written record would have to be re-typed every time one
# of them changes. Seeding leaves a planted position as the only arrival.
mkdir -p "$T/ai-docs/fixtures"
BASE="$T/ai-docs/fixtures/positional-references.baseline"
printf '# Positions accounted for.\n' > "$BASE"
: > "$T/docs/swept.md"
: > "$T/scripts/marked.sh"
printf '{"a": 1}\n' > "$T/data.json"
git -C "$T" add ai-docs/fixtures/positional-references.baseline docs/swept.md \
  scripts/marked.sh data.json >/dev/null 2>&1

swept()  { printf '%s\n' "$1" > "$T/docs/swept.md"; }
marked() { printf '%s\n' "$1" > "$T/scripts/marked.sh"; }
account(){ printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$BASE"; }

write_pair 'Nothing.' 'Nothing.'
# The finding line carries its excuse key between the class and the colon, so
# the row is taken from the tail rather than from a fixed prefix.
run | sed -n 's/^finding reference .*that would account for it is: //p' | sort -u >> "$BASE"
git -C "$T" add ai-docs/fixtures/positional-references.baseline >/dev/null 2>&1
out=$(run)
hasnt "a record seeded from the tree leaves the reference class clean" "$out" 'finding reference'

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
has "a literal twice inside ONE sentence is one site, not two" "$out" 'repeats=0'
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

printf '\n== the completeness class, which HOLDS ==\n'
COMPLETE="$DESIGN_SECOND
| # | Task | Files | Delivers |
|---|---|---|---|
| 1 | Build it | \`scripts/new-thing.sh\` *(new)* | AC1 |

The check at \`scripts/new-thing.sh\` exists because nothing else answers the question.

$DESIGN_FIFTH
- \`scripts/new-thing.sh\` — run by the author, which refuses on a finding"
SPEC_ONE='| AC1 | The thing holds. |'
write_pair "| AC | Criterion |
|---|---|
$SPEC_ONE" "$COMPLETE"
out=$(run)
hasnt "a complete object is silent" "$out" 'finding completeness'
has "and it was examined rather than skipped" "$out" 'objects=1'
has "the delivery column is derived from the document's own header" "$out" 'delivery-column=delivers'

write_pair "| AC | Criterion |
|---|---|
$SPEC_ONE" "${COMPLETE/| 1 | Build it | \`scripts\/new-thing.sh\` *(new)* | AC1 |/| 1 | Build it | \`scripts\/other.sh\` | AC1 |}"
out=$(run)
has "an object no decomposition row names is reported" "$out" 'no stated place'
write_pair "| AC | Criterion |
|---|---|
$SPEC_ONE" "${COMPLETE/- \`scripts\/new-thing.sh\` — run by the author, which refuses on a finding/- \`scripts\/other.sh\` — used somewhere}"
out=$(run)
has "an object with no use-case bullet is reported for its cases and its behaviour together" "$out" 'no stated cases and no stated behaviour'
write_pair "| AC | Criterion |
|---|---|
$SPEC_ONE" "${COMPLETE/The check at \`scripts\/new-thing.sh\` exists because nothing else answers the question./Nothing else mentions it.}"
out=$(run)
has "an object named only in its row and its bullet is reported for its reason" "$out" 'no stated reason'

write_pair "| AC | Criterion |
|---|---|
$SPEC_ONE
| AC2 | A second thing holds. |" "$COMPLETE"
out=$(run)
has "a requirement no row delivers is reported" "$out" 'the requirement AC2 is stated in the spec'
has "and both criteria were counted" "$out" 'criteria=2'
write_pair "| AC | Criterion |
|---|---|
$SPEC_ONE" "${COMPLETE/| AC1 |/| AC1, AC9 |}"
out=$(run)
has "a row claiming a criterion the spec does not state is reported" "$out" 'claims to deliver AC9'

printf '\n== section references, resolved against the document that makes them ==\n'
write_pair 'Nothing.' "$COMPLETE

The reason is given in § $DESIGN_SECOND_NAME, which carries it."
out=$(run)
hasnt "a reference to a section the document has is silent" "$out" 'refers to a section'
has "and own-document references are counted apart from qualified ones" "$out" 'section-refs=1/1'
write_pair 'Nothing.' "$COMPLETE

The reason is given in § Nowhere At All, which carries it."
out=$(run)
has "a reference resolving to no heading is reported" "$out" 'refers to a section [Nowhere At All]'
write_pair 'Nothing.' "$COMPLETE

The reason is given in \`other-file.md\` § Nowhere At All, which carries it."
out=$(run)
hasnt "a reference qualified by a file name is not resolved here" "$out" 'refers to a section'
has "but it is counted, so the figure says what this class did not carry" "$out" 'section-refs=0/1'

printf '\n== the isolation class, which HOLDS ==\n'
write_pair 'The window is 40 rounds wide, a threshold handed down. The same 40 is the cap, a threshold handed down.' 'Nothing.'
out=$(run)
has "the minimum fragment length is borrowed rather than chosen" "$out" 'fragment-min=24'
has "a figure repeated across two statements is reported" "$out" 'states the figure [40] at 2 sites'
write_pair 'The window is 40 rounds wide, a threshold handed down.' 'Nothing.'
out=$(run)
hasnt "a figure at one site is silent" "$out" 'finding isolation'
write_pair 'This whole sentence is long enough to be located.

This whole sentence is long enough to be located.' 'Nothing.'
out=$(run)
has "a whole statement repeated at two sites is reported" "$out" 'states the same span at 2 sites'
write_pair 'Short enough. Short enough.' 'Nothing.'
out=$(run)
hasnt "a repeated statement below the borrowed length is silent" "$out" 'finding isolation'
write_pair 'The first claim rests on a shared phrasing of some length here. A different claim rests on a shared phrasing of some length here too.' 'Nothing.'
out=$(run)
hasnt "a phrase shared INSIDE two different statements is silent" "$out" 'finding isolation'
write_pair 'Nothing.' "$DESIGN_SECOND
| # | Task | Files |
|---|---|---|
| 1 | A cell long enough to be located twice | \`scripts/a.sh\` |
| 2 | A cell long enough to be located twice | \`scripts/b.sh\` |"
out=$(run)
has "a repeated table cell names the rows it sits in" "$out" '| 1 | A cell long enough to be located twice |'
write_pair 'Nothing.' "$DESIGN_SECOND
| # | Task | Files |
|---|---|---|
| 1 | A cell long enough to be located twice | \`scripts/a.sh\` |
| 2 | A different cell, also long enough to locate | \`scripts/b.sh\` |"
out=$(run)
hasnt "two different cells at one site each are silent" "$out" 'states the same span'
mv "$T/skills/task/scripts/check-fix-plan.sh" "$T/skills/task/scripts/gone.sh"
out=$(bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "an unreadable source for the borrowed length -> rc 2" "$rc" "2"
has "and says it is borrowed rather than chosen here" "$out" 'borrowed from it rather than chosen here'
mv "$T/skills/task/scripts/gone.sh" "$T/skills/task/scripts/check-fix-plan.sh"

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


printf '\n== the reference class, against the record that makes it start green ==\n'
write_pair 'Nothing.' 'Nothing.'
swept 'The rule is stated at `docs/plan-invariants.md:120`, which carries it.'
out=$(run)
has "a path-and-line token the record does not account for is reported" "$out" 'docs/plan-invariants.md:120'
has "and the finding prints the row that would account for it" "$out" 'path-line	docs/swept.md	docs/plan-invariants.md:120'
account 'path-line' 'docs/swept.md' 'docs/plan-invariants.md:120'
out=$(run)
hasnt "the same token once the record accounts for it is silent" "$out" 'finding reference'
POSN=$(printf '%s' "$out" | sed -n 's/.* positions=\([0-9]*\) .*/\1/p')
ACCN=$(printf '%s' "$out" | sed -n 's/.* accounted=\([0-9]*\) .*/\1/p')
check "and a clean reference verdict accounts for every position it examined" "$POSN" "$ACCN"
swept 'The rule is stated at `docs/plan-invariants.bin:120`, which carries it.'
out=$(run)
hasnt "a token whose extension no tracked file carries is outside the sweep" "$out" 'finding reference'
swept 'The rule is stated at line 42 of the page, which carries it.'
out=$(run)
has "a prose reference naming a line is reported" "$out" 'prose-line	docs/swept.md	line 42'
swept 'The rule is stated on the first line of the page, which carries it.'
out=$(run)
hasnt "a prose sentence naming no line number is silent" "$out" 'finding reference'
swept 'The help text comes out of `sed -n '"'"'3,20p'"'"' docs/plan-invariants.md`.'
out=$(run)
has "a line-addressed slice of another file is reported" "$out" 'command-slice'
swept 'The help text comes out of `sed -n '"'"'3,20p'"'"' "$0"`.'
out=$(run)
hasnt "the same slice of the running script is the carve-out and is silent" "$out" 'finding reference'
swept 'The count comes out of `grep -n thing docs/plan-invariants.md`.'
out=$(run)
hasnt "a command that PRODUCES a position is not a reference to one" "$out" 'finding reference'
swept ''
out=$(run)
has "the swept file count is printed, so a narrowed input set is visible" "$out" 'swept='
mv "$BASE" "$T/ai-docs/fixtures/moved"
out=$(bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "an absent record -> rc 2, never a clean sweep" "$rc" "2"
has "and says a sweep with no comparand establishes nothing" "$out" 'must not report what it found'
mv "$T/ai-docs/fixtures/moved" "$BASE"
git -C "$T" add ai-docs/fixtures/positional-references.baseline >/dev/null 2>&1
git -C "$T" rm -q --cached ai-docs/fixtures/positional-references.baseline >/dev/null 2>&1
# The fixture's own precondition, asserted rather than assumed: this removal has
# failed silently once, on an index entry the seeding had left behind, and the
# leg then measured a tracked record while its label said otherwise.
git -C "$T" ls-files --error-unmatch ai-docs/fixtures/positional-references.baseline >/dev/null 2>&1 \
  && bad "the record was removed from the index" || ok "the record was removed from the index"
out=$(bash "$SUB" --root "$T" "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "a record outside the index -> rc 2" "$rc" "2"
has "and says the run compares against a file no other clone has" "$out" 'no other clone has'
git -C "$T" add ai-docs/fixtures/positional-references.baseline >/dev/null 2>&1
cp "$BASE" "$T/ai-docs/fixtures/full"
printf '# Nothing accounted for.\n' > "$BASE"
out=$(run); rc=$?
check "an EMPTY record is legitimate rather than a cannot-run" "$rc" "1"
has "and every position becomes an arrival, which is the loud direction" "$out" 'accounted=0'
cp "$T/ai-docs/fixtures/full" "$BASE"

printf '\n== the pairing class, both directions and the ambiguity report ==\n'
marked '# the refusal this claim leans on [refusal-arm]'
write_pair 'The guard in `scripts/marked.sh` refuses an empty set [refusal-arm].' 'Nothing.'
out=$(run)
hasnt "a claim whose mark sits in a file it names pairs" "$out" 'finding pairing'
has "and the pair count is printed, so two empty sides cannot read as agreement" "$out" 'pairs=1'
has "and both sides were counted" "$out" 'claims=1 marks=1'
# THE OTHER DOCUMENT NAMES THE MARKED FILE ON PURPOSE. Marks are swept over the
# files the PAIR names, so a fixture naming the marked file nowhere leaves this
# leg passing because the mark was never read -- proved by muting the
# claiming-statement bound and watching the leg stay green.
write_pair 'The guard in `docs/swept.md` refuses an empty set [refusal-arm].' 'The other guard lives in `scripts/marked.sh`.'
out=$(run)
has "a claim whose mark sits in a file it does not name is reported" "$out" 'resolves to nothing'
has "and the mark it could not use was read rather than skipped" "$out" 'marks=1'
write_pair 'The guard refuses an empty set [refusal-arm].' 'Nothing.'
out=$(run)
has "a claim naming no file in the tree is reported" "$out" 'nothing bounds where its mark may sit'
write_pair 'The guard in `scripts/marked.sh` refuses an empty set.' 'Nothing.'
out=$(run)
has "a mark no statement claims is reported" "$out" 'no statement of this plan claims it'
write_pair 'The guard in `scripts/marked.sh` refuses an empty set [refusal-arm].' 'The same guard in `scripts/marked.sh` refuses it [refusal-arm].'
out=$(run)
has "an id claimed by two statements is reported as ambiguous" "$out" 'claimed by 2 statements'
marked '# the refusal this claim leans on [refusal-arm]
# and a second entity carrying the same mark [refusal-arm]'
write_pair 'The guard in `scripts/marked.sh` refuses an empty set [refusal-arm].' 'Nothing.'
out=$(run)
has "an id marked at two sites is reported as ambiguous" "$out" 'marked at 2 sites'
marked '# the refusal this claim leans on [refusal-arm]'
write_pair 'The guard in `scripts/marked.sh` refuses a set spelled `[refusal-arm]`.' 'Nothing.'
out=$(run)
has "a bracketed token inside a backtick span is not a claim" "$out" 'claims=0'
marked 'printf "%s" "[refusal-arm]"'
write_pair 'The guard in `scripts/marked.sh` refuses an empty set.' 'Nothing.'
out=$(run)
has "a bracketed token outside a comment in a source file is not a mark" "$out" 'marks=0'
marked '# nothing marked here'
swept '# A heading carrying its own id [prose-entity]'
write_pair 'The section in `docs/swept.md` states the rule [prose-entity].' 'Nothing.'
out=$(run)
has "a mark riding a prose heading pairs, needing no comment" "$out" 'pairs=1'
swept '```
# A heading inside a fenced block [prose-entity]
```'
write_pair 'The section in `docs/swept.md` states the rule.' 'Nothing.'
out=$(run)
has "a bracketed token inside a fenced block is not a mark" "$out" 'marks=0'
swept ''
write_pair 'The key in `data.json` is the one this leans on [json-key].' 'Nothing.'
out=$(run)
hasnt "a claim against a language admitting no comment resolves on the file alone" "$out" 'finding pairing'
has "and it still counts as a pair, with no reverse pairing asserted" "$out" 'pairs=1'


printf '\n== the excuse route: the grant act, and what an ordinary run does with its record ==\n'
EX="$T/plans/a.excuses.md"
rm -f "$EX"
PKEY="provenance|spec § ${SPEC_FIRST_NAME}|40"
AKEY="arithmetic|spec § ${SPEC_FIRST_NAME}|20 + 20 = 41"
grant() { bash "$SUB" --root "$T" --excuse "$1" --grounds "$2" \
  "$T/plans/a.spec.md" "$T/plans/a.design.md" 2>&1; }

write_pair 'The window is 40 rounds wide. The band is 20 + 20 = 41 wide.' 'Nothing.'
out=$(run)
has "every finding line carries the key that would excuse it" "$out" "[excuse: ${PKEY}]"
has "and nothing is excused before an act grants one" "$out" 'excused-holding=0 excused-reporting=0'

bash "$SUB" --root "$T" --excuse "$PKEY" "$T/plans/a.spec.md" "$T/plans/a.design.md" >/dev/null 2>&1
check "--excuse without --grounds -> rc 2" "$?" "2"
bash "$SUB" --root "$T" --grounds 'why' "$T/plans/a.spec.md" "$T/plans/a.design.md" >/dev/null 2>&1
check "--grounds without --excuse -> rc 2" "$?" "2"
[ -e "$EX" ] && bad "a refused act wrote no record" || ok "a refused act wrote no record"

out=$(grant 'provenance|spec|not-a-subject-of-any-finding' 'why'); rc=$?
check "a key matching no finding of the run -> rc 2" "$rc" "2"
has "and says an excuse for an unseen finding excuses nothing" "$out" 'excuses nothing'
out=$(grant 'provenance|only-two-parts' 'why'); rc=$?
check "a key that is not three parts -> rc 2" "$rc" "2"
[ -e "$EX" ] && bad "neither refusal wrote a record" || ok "neither refusal wrote a record"

out=$(grant "$PKEY" 'The figure is a worked example in a template, not a measurement.'); rc=$?
check "the grant act -> rc 0" "$rc" "0"
has "and it shows the finding BEFORE excusing it" "$out" 'about to excuse, in full'
has "and the finding it shows is the one the key names" "$out" 'spec states [40] in a clause naming neither'
has "and it names the record it wrote" "$out" 'EXCUSED -- the row above is now recorded'
has "and it says the record is committed and unstaged" "$out" 'COMMITTED record and this run did not stage it'
out=$(run); rc=$?
check "an existing record outside the index -> rc 2" "$rc" "2"
has "and says the run is quieter than every other clone" "$out" 'quieter than every other clone'
git -C "$T" add plans/a.excuses.md >/dev/null 2>&1

out=$(run)
has "the waived finding is reported as excused rather than omitted" "$out" 'excused provenance'
has "and its grounds travel with it" "$out" 'a worked example in a template'
hasnt "and it is no longer counted as a finding" "$out" "finding provenance [excuse: ${PKEY}]"
has "the waived count prints beside the verdict, split by whether the class holds" "$out" 'excused-holding=0 excused-reporting=1'
has "and the holding count is untouched by waiving a reporting finding" "$out" 'holding=1'

BEFORE=$(cksum < "$EX")
out=$(run)
AFTER=$(cksum < "$EX")
check "an ordinary run writes nothing to the record" "$AFTER" "$BEFORE"
out=$(grant "$PKEY" 'a second time'); rc=$?
check "granting the same key twice -> rc 0 and no second row" "$rc" "0"
has "and says so" "$out" 'ALREADY EXCUSED'
AFTER=$(cksum < "$EX")
check "the record is byte-identical after the repeat" "$AFTER" "$BEFORE"

printf '\n== an excuse survives the passage being edited, and dies with its plan ==\n'
write_pair 'The window is 40 rounds wide, a span rewritten since. The band is 20 + 20 = 41 wide.' 'Nothing.'
out=$(run)
has "rewording the passage does not revoke the waiver" "$out" 'excused provenance'
write_pair 'Nothing numeric here. The band is 20 + 20 = 41 wide.' 'Nothing.'
out=$(run)
hasnt "the fault removed reports nothing at all" "$out" 'excused provenance'
write_pair 'The window is 40 rounds wide. The band is 20 + 20 = 41 wide.' 'Nothing.'
out=$(run)
has "the same fault returning at that spot comes back waived" "$out" 'excused provenance'
cp "$T/plans/a.spec.md" "$T/plans/b.spec.md"
cp "$T/plans/a.design.md" "$T/plans/b.design.md"
out=$(bash "$SUB" --root "$T" "$T/plans/b.spec.md" "$T/plans/b.design.md" 2>&1)
hasnt "an unrelated plan inherits nothing -- the record does not travel" "$out" 'excused provenance'
has "and it objects again from scratch" "$out" 'spec states [40] in a clause naming neither'

printf '\n== a waiver over a HOLDING class, and the record this check cannot read ==\n'
out=$(grant "$AKEY" 'The arithmetic is deliberately wrong in a worked example of a false equation.')
has "a holding finding can be waived too, the route being open to any class" "$out" 'EXCUSED'
git -C "$T" add plans/a.excuses.md >/dev/null 2>&1
out=$(run); rc=$?
check "a pair with nothing unexcused left -> rc 0, the caller refusing on holds" "$rc" "0"
hasnt "and it does NOT read as clean, which is what the waived count is for" "$out" 'check-plan-convergence: clean'
has "it says in words that it is proceeding over the waivers" "$out" 'proceeding over 2 excused'
has "the split says a hold was waived rather than a report quieted" "$out" 'excused-holding=1 excused-reporting=1'
has "and the holding count falls to zero" "$out" 'holding=0'
has "the roster names the waivers per class" "$out" ', 1 excused'
printf '| arithmetic | spec | 20 + 20 = 41 |  |\n' >> "$EX"
git -C "$T" add plans/a.excuses.md >/dev/null 2>&1
out=$(run); rc=$?
check "a row with an empty required cell -> rc 2, never a quiet waiver" "$rc" "2"
has "and names the row it could not read" "$out" 'excuses nothing checkably'
git -C "$T" checkout -- plans/a.excuses.md 2>/dev/null || sed -i.bak '/| arithmetic | spec | 20 + 20 = 41 |  |/d' "$EX"
rm -f "$EX.bak"
git -C "$T" add plans/a.excuses.md >/dev/null 2>&1
cp "$T/plans/a.spec.md" "$T/plans/c.md"
out=$(bash "$SUB" --root "$T" "$T/plans/c.md" "$T/plans/a.design.md" 2>&1); rc=$?
check "a spec not named by the record's own construction -> rc 2" "$rc" "2"
has "and says the record beside it cannot be named" "$out" 'cannot be named'
rm -f "$T/plans/c.md" "$T/plans/b.spec.md" "$T/plans/b.design.md"

printf '\n== the record suffix against THIS repository own ignore rules ==\n'
# Run rather than reasoned about: the two suffixes sit in the same directory and
# only one of them is swallowed.
git -C "$ROOT" check-ignore -q "ai-docs/plans/probe.progress.md" \
  && ok "the working record's suffix IS ignored here" \
  || bad "the working record's suffix IS ignored here"
git -C "$ROOT" check-ignore -q "ai-docs/plans/probe.excuses.md" \
  && bad "the excuse record's suffix is NOT ignored here" \
  || ok "the excuse record's suffix is NOT ignored here"

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
