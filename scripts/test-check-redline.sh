#!/usr/bin/env bash
#
# Tests for check-redline.sh.
#
# Run: bash scripts/test-check-redline.sh
#
# Every verb gets three legs, never two: an input that must make the check come
# back NON-EMPTY, a control that must make it come back EMPTY, and a CANNOT-RUN
# leg. The third is not symmetry -- `pending` is a backstop, so its failure mode
# is a caller reading an internal error as "nothing to refuse", and neither of
# the first two legs is a cannot-run, so neither can see it.
#
# The checker is invoked BY PATH, never as `bash <path>`, because that is how a
# skill invokes a plugin script. The convenient form does not need the execute
# bit, so a suite spelled that way is green precisely because it never runs the
# thing the way it ships.
#
# The fixtures build their own throwaway repository with a committed spec, a
# marked design and a log, because the comparand for the collapse check is the
# previous commit and nothing else can stand in for it.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-redline.sh"
REPO=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in [$2]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3]" ;; *) ok "$1" ;; esac; }

run() { OUT=$("$CHECK" "$@" 2>&1); RC=$?; }

SPEC_HEAD='# Spec

**Tracked in:** T-1

## Scope

1. Something.

## Out of scope

- A thing deliberately absent.

## Deferred

| What | Why |
|---|---|
| A later thing | Not now |

## Key decisions

| Question | Decision |
|---|---|
| Which carrier? | A committed file. |

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | The first thing holds. |
| AC2 | The second thing holds. |
| AC3 | The third thing holds. |
'

DESIGN_CLEAN='# Design

## Approach

The working logic, as built.

## Decomposition

| # | Task | Files |
|---|---|---|
| 1 | Wire the gate | one file |

## Use cases

- `the refusal` — run by the closing command before it deletes anything; run by the merge cleanup as its
  last read of the log
- `the retention check` — run by the closing command over the sections the fold keeps; run by a reviewer
  reading a completed plan

THIS FIXTURE IS THE MODEL OF A CORRECTLY FOLDED DESIGN for the whole suite, so it carries what such a
document is allowed to carry and nothing else. It held a test-design section with one verification line
per criterion until a design stopped saying anything about tests; a fixture left on that shape teaches
the forbidden form to every reader of this suite.
'

mktree() { # -> a repository with a committed spec, design and redline log
  local d
  d=$(mktemp -d)
  git -C "$d" init -q .
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  mkdir -p "$d/ai-docs/plans/done"
  printf '%s' "$SPEC_HEAD"    > "$d/ai-docs/plans/t.spec.md"
  printf '%s' "$DESIGN_CLEAN" > "$d/ai-docs/plans/t.design.md"
  { printf '| Key | Type | Artefact sentence diverged from | What shipped instead |\n'
    printf '|---|---|---|---|\n'
    printf '| R1.1 | modified | `ai-docs/plans/t.design.md:9` — "Wire the gate" | one gate, two verbs |\n'
  } > "$d/ai-docs/plans/t.redline.md"
  git -C "$d" add -A
  git -C "$d" commit -qm init
  printf '%s' "$d"
}

printf '\n== pending: present, absent, and the cannot-run lane ==\n'
T=$(mktree)
run pending "${T}/ai-docs/plans"
check "a log in the active directory is reported present" "$RC" "1"
has   "  verdict" "$OUT" "verdict=present"
has   "  names the log" "$OUT" "t.redline.md"
has   "  and says what it means" "$OUT" "the redline fold has not run"

T=$(mktree); mv "${T}/ai-docs/plans/t.redline.md" "${T}/ai-docs/plans/done/t.redline.md"
run pending "${T}/ai-docs/plans"
check "a log beside the completed plan is found too" "$RC" "1"
has   "  names it in done/" "$OUT" "done/t.redline.md"

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"
run pending "${T}/ai-docs/plans"
check "control: no log at all is a clean 0" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"
hasnt "  and reports no log" "$OUT" "verdict=present"

# THE LANE THE BACKSTOP LIVES OR DIES ON. A caller refuses on anything that is
# not a clean 0, so an internal error must not arrive as 0 -- and neither of the
# two legs above is an internal error, so neither can see this.
run pending "${T}/ai-docs/nope"
check "a missing plans directory is exit 2, which is not a pass" "$RC" "2"
has   "  and names what it could not read" "$OUT" "no such plans directory"

NOGIT=$(mktemp -d); mkdir -p "${NOGIT}/plans"
run pending "${NOGIT}/plans"
check "a directory outside a work tree is exit 2 as well" "$RC" "2"
has   "  and says why" "$OUT" "not inside a git work tree"
rm -rf "$NOGIT"

run pending
check "pending with no argument is exit 2" "$RC" "2"
has   "  and prints the usage" "$OUT" "check-redline.sh pending"

printf '\n== folded: the collapse, the residue, the log, and the comparand ==\n'
T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "control: retained sections intact, no residue, log gone -> clean 0" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean findings=0"

# AC14's own control: ONE altered character in ONE retained section.
T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"
sed -i.bak 's/A thing deliberately absent/A thing deliberately absenT/' "${T}/ai-docs/plans/t.spec.md"
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a single altered character in a retained section is detected" "$RC" "1"
has   "  and names the section" "$OUT" "\`## Out of scope\` is not byte-identical"

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"
awk '/^## Deferred$/ { skip = 1 } /^## Key decisions$/ { skip = 0 } !skip' \
  "${T}/ai-docs/plans/t.spec.md" > "${T}/x" && mv "${T}/x" "${T}/ai-docs/plans/t.spec.md"
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a retained section DELETED is detected, not read as identical" "$RC" "1"
has   "  and names it" "$OUT" "no longer carries a \`## Deferred\` section"

# All three residue patterns at once: the before-the-strip control the fold's
# residue claim rests on.
T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"
{ printf '\n## Handoff plan\n\nGroup A is subtasks 1-3.\n'
  printf '\n## Open questions\n\nNone blocking.\n'
  printf '\n| 1 | Wire the gate | one file | **[REDLINE R1.1]** |\n'
} >> "${T}/ai-docs/plans/t.design.md"
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "all three residue patterns present -> findings" "$RC" "1"
has   "  the spent headings are named" "$OUT" "spent process heading"
has   "  Handoff plan by line" "$OUT" "## Handoff plan"
has   "  Open questions by line" "$OUT" "## Open questions"
has   "  and the marker on its own finding" "$OUT" "still carries a redline marker"
has   "  with the marker's own line" "$OUT" "[REDLINE R1.1]"

T=$(mktree)
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a surviving log is a finding on its own" "$RC" "1"
has   "  and names where it survives" "$OUT" "the redline log survives at"

T=$(mktree); mv "${T}/ai-docs/plans/t.redline.md" "${T}/ai-docs/plans/done/t.redline.md"
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a log left in done/ is found too, from a spec in the active directory" "$RC" "1"
has   "  and names it" "$OUT" "done/t.redline.md"

# THE RECORD OF EXCUSED FINDINGS, which the fold KEEPS. The folded plan still
# has readers -- the fold's own convergence call, and any later run over the
# archived pair -- and a removed record would un-excuse every waiver in it
# permanently. The fixture
# carries none, which is the ordinary state; these legs plant one beside the
# plan, in both directories the fold finds a plan in, and assert it is not a
# finding -- alone, and beside a surviving log, which still is one.
mkexcuses() { # <tree> <relative directory> <spec base>
  { printf '| Class | Spot | Subject | Grounds |\n'
    printf '|---|---|---|---|\n'
    printf '| arithmetic | `%s.design.md` § Approach | 20 + 20 = 41 | a worked example of a false equation |\n' "$3"
  } > "${1}/${2}/${3}.excuses.md"
}

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"; mkexcuses "$T" ai-docs/plans t
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a record of excused findings beside the plan survives the fold, and is no finding" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"; mkexcuses "$T" ai-docs/plans/done t
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a record in done/ survives too" "$RC" "0"

T=$(mktree); mkexcuses "$T" ai-docs/plans t
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a surviving log beside a kept record -> findings" "$RC" "1"
has   "  the log is reported" "$OUT" "the redline log survives at"
hasnt "  and the record is not" "$OUT" "t.excuses.md"

# THE RECORD OF DECLARED LINKS, which the fold keeps as it keeps the excuse
# record: a later run over the archived pair still reads its design-to-design
# links. The same legs, for that record.
mklinks() { # <tree> <relative directory> <spec base>
  { printf '| Id | End A | Quote A | End B | Quote B | Grounds |\n'
    printf '|---|---|---|---|---|---|\n'
    printf '| L1 | spec § Scope | Something. | design § Approach | The working logic | the design restates the scope |\n'
  } > "${1}/${2}/${3}.links.md"
}

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"; mklinks "$T" ai-docs/plans t
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a record of declared links beside the plan survives the fold, and is no finding" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"; mklinks "$T" ai-docs/plans/done t
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a record of declared links in done/ survives too" "$RC" "0"

T=$(mktree); mklinks "$T" ai-docs/plans t
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a surviving log beside a kept record of declared links -> findings" "$RC" "1"
has   "  the log is reported" "$OUT" "the redline log survives at"
hasnt "  and the record is not" "$OUT" "t.links.md"

T=$(mktree); rm -f "${T}/ai-docs/plans/t.redline.md"
mklinks "$T" ai-docs/plans t; mklinks "$T" ai-docs/plans/done t
run pending "${T}/ai-docs/plans"
check "pending: a record of declared links in both directories is no log" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"
hasnt "  and the record is not named" "$OUT" "t.links.md"

# The spec collapsed in done/, which is where the fold actually finds it.
T=$(mktree)
git -C "$T" mv ai-docs/plans/t.spec.md ai-docs/plans/done/t.spec.md
git -C "$T" mv ai-docs/plans/t.design.md ai-docs/plans/done/t.design.md
git -C "$T" rm -q ai-docs/plans/t.redline.md
git -C "$T" commit -qm move
run folded "${T}/ai-docs/plans/done/t.spec.md" "${T}/ai-docs/plans/done/t.design.md"
check "the same documents in done/ are clean too" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

# THE COMPARAND'S OWN CANNOT-RUN LANE: with no previous commit there is nothing
# the retained sections can be byte-compared against, and reporting clean there
# would be a pass asserting nothing.
T=$(mktemp -d); git -C "$T" init -q .; mkdir -p "${T}/ai-docs/plans"
printf '%s' "$SPEC_HEAD" > "${T}/ai-docs/plans/t.spec.md"
printf '%s' "$DESIGN_CLEAN" > "${T}/ai-docs/plans/t.design.md"
run folded "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/t.design.md"
check "no HEAD commit is exit 2, not a clean pass" "$RC" "2"
has   "  and says what is missing" "$OUT" "no comparand"

T=$(mktree); cp "${T}/ai-docs/plans/t.spec.md" "${T}/ai-docs/plans/u.spec.md"
run folded "${T}/ai-docs/plans/u.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a spec absent from HEAD is exit 2 for the same reason" "$RC" "2"
has   "  and names the gap" "$OUT" "is not in HEAD"

run folded "${T}/ai-docs/plans/gone.spec.md" "${T}/ai-docs/plans/t.design.md"
check "a missing spec file is exit 2" "$RC" "2"
has   "  and names it" "$OUT" "no such spec"

printf '\n== suppression: the disjunction reaches both spellings ==\n'
S=$(mktemp -d)
# THE POSITIVE FIXTURE IS THE REAL SAMPLE, VERBATIM AND ON ONE LINE, and both
# halves of that matter. The verb's unit is the line, and every suppression
# instruction in the live reviewer brief is written on one -- so a fixture that
# hard-wrapped the same sentence would put the path on one line and the
# suppression wording on another, take the not-suppression disposition, and pass
# while measuring nothing. It is FROZEN here rather than read out of the live
# file: the live text is narrowed by this same change, and the shape the verb
# must keep catching afterwards is this one.
SUPPRESS_BY_FILENAME='2. Read every `*.spec.md` and `*.design.md` in `ai-docs/plans/done/` — these document **intentional** decisions. Do not raise findings for anything explicitly described there.'
{ printf '# Reviewer brief\n\n'; printf '%s\n' "$SUPPRESS_BY_FILENAME"; } > "${S}/by-filename.md"
run suppression "${S}/by-filename.md"
check "an instruction conferring suppression on a design is a finding" "$RC" "1"
has   "  and says so" "$OUT" "names a design document"
has   "  with the enumerated count beside the verdict" "$OUT" "enumerated=1"

# THE MEASURED NEGATIVE LEG. This fixture carries NO `design.md` at all, so the
# narrower pattern returns nothing on it while the authority is conferred in
# full through the directory spelling. A criterion met by that narrower pattern
# is the false green this leg exists to refuse.
{ printf '# Reviewer brief\n\n'
  printf -- '- Anything explicitly documented as intentional in `ai-docs/plans/done/`.\n'
} > "${S}/by-directory.md"
check "the fixture carries no design.md spelling at all" "$(grep -c 'design\.md' "${S}/by-directory.md")" "0"
run suppression "${S}/by-directory.md"
check "the directory spelling alone still fires" "$RC" "1"
has   "  and names the spelling it caught" "$OUT" "names the completed-plans directory without narrowing to the spec"

# The control is the SAME two instructions with the design dropped, each still
# on one line, so it differs from the two positives in the narrowing alone.
{ printf '# Reviewer brief\n\n'
  printf '2. Read every `*.spec.md` in `ai-docs/plans/done/` — these document **intentional** decisions. Do not raise findings for anything explicitly described there.\n'
  printf -- '- Anything explicitly documented as intentional in a `*.spec.md` in `ai-docs/plans/done/`.\n'
} > "${S}/narrowed.md"
run suppression "${S}/narrowed.md"
check "control: both spellings narrowed to the spec are clean" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean enumerated=2 findings=0"
check "  and BOTH lines are dispositioned suppression, not merely counted" \
      "$(printf '%s\n' "$OUT" | grep -c ' suppression$')" "2"

# The retention half of the criterion: a coverage check over completed DESIGNS
# is not suppression and must survive the narrowing untouched. The fixture
# reproduces the live brief's wording, which changed when a design stopped
# saying anything about tests -- a fixture left on the superseded sentence
# asserts the disposition of a line the brief no longer contains.
cat > "${S}/verification.md" <<'EOF'
# Reviewer brief

- **Use-case coverage (mandatory).** For every case listed under `## Use cases`
  in any `ai-docs/plans/done/*.design.md`, name a shipped test that covers it.
EOF
run suppression "${S}/verification.md"
check "control: the use-case coverage check over completed designs stays clean" "$RC" "0"
has   "  and is dispositioned as not conferring suppression" "$OUT" "not-suppression"

cat > "${S}/heading.md" <<'EOF'
### 0. Design conformance (when designs exist in `done/`)
EOF
run suppression "${S}/heading.md"
check "control: a heading naming the directory confers nothing" "$RC" "0"
has   "  and is dispositioned as such" "$OUT" "not-suppression"

# The live reviewer brief, on the ENUMERATION rather than the verdict: the count
# is what proves the pattern still reaches every instruction in it, and it holds
# whether or not those instructions have yet been narrowed.
run suppression "${REPO}/agents/review-findings.md"
has "the live reviewer brief enumerates four instructions" "$OUT" "enumerated=4"

run suppression "${S}/nope.md"
check "a missing file is exit 2" "$RC" "2"
has   "  and names it" "$OUT" "no such file"

printf '\n== revision: a design subject and a verdict subject, both ways ==\n'
R=$(mktemp -d)
cat > "${R}/design-dirty.md" <<'EOF'
# Design

## Approach

An earlier draft said the carrier was the progress file; that is corrected here.
EOF
run revision "${R}/design-dirty.md"
check "a design carrying a revision account is flagged" "$RC" "1"
has   "  and names the introducer it matched" "$OUT" "[an earlier draft]"
has   "  with its line" "$OUT" "at line 5"

cat > "${R}/design-clean.md" <<'EOF'
# Design

## Approach

The carrier is a committed file beside the plan, because the fold runs after the
human review.
EOF
run revision "${R}/design-clean.md"
check "control: a design describing only its current state is clean" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean findings=0"

# THE VERDICT SUBJECT, which is the half the rule was missing: a reviewer is
# free to improvise a demand for a revision account, and on this mechanism's own
# branch one did.
cat > "${R}/verdict-dirty.md" <<'EOF'
# Design Review — Round 2

**Verdict:** ITERATE

| # | Severity | Issue |
|---|---|---|
| 1 | minor | State that a first draft's count was wrong, rather than quietly correcting the count. |
EOF
run revision "${R}/verdict-dirty.md"
check "a verdict demanding a revision account is flagged" "$RC" "1"
has   "  and names an introducer" "$OUT" "revision-account introducer is present"

cat > "${R}/verdict-clean.md" <<'EOF'
# Design Review — Round 2

**Verdict:** ITERATE

| # | Severity | Issue |
|---|---|---|
| 1 | major | The gate's cannot-run lane is untested, so an internal error reads as a pass. |
EOF
run revision "${R}/verdict-clean.md"
check "control: an ordinary finding is unaffected" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

printf 'AN EARLIER DRAFT argued otherwise.\n' > "${R}/caps.md"
run revision "${R}/caps.md"
check "the scan is case-insensitive, so capitals do not evade it" "$RC" "1"

run revision "${R}/nope.md"
check "a missing file is exit 2" "$RC" "2"

printf '\n== the entry point a skill invokes is executable ==\n'
# THE TWO MODES DIFFER ON PURPOSE, so neither is "corrected" to match the other.
# This checker is invoked from a skill as a plugin-root path, the shape
# check-candidate.sh and collect-candidates.sh already use, and that form needs
# the bit -- every root-level script invoked that way in this repository carries
# it. The SUITE is only ever run as `bash scripts/test-check-redline.sh` from the
# gate list, which does not, so it stays 644 beside its siblings. The committed
# MODE is what is asserted, not the working tree's: a lost bit reaches a consumer
# through the index.
if [ -x "$CHECK" ]; then ok "check-redline.sh carries the execute bit"
else bad "check-redline.sh carries the execute bit"; fi
MODE=$(git -C "$REPO" ls-files -s -- scripts/check-redline.sh | awk '{ print $1 }')
check "the mode git records is 100755" "$MODE" "100755"
SMODE=$(git -C "$REPO" ls-files -s -- scripts/test-check-redline.sh | awk '{ print $1 }')
check "while the suite's own mode is 644, as its siblings are" "$SMODE" "100644"

printf '\n== usage ==\n'
printf '\n== paired: a marker with no row and a row with no marker are each a finding ==\n'
# This verb is why the template may say the pairing is checked both ways. A8 in
# check-fix-plan.sh covers the R form INSIDE a round, keyed off the plan table;
# a Step-8 divergence never appears in a plan, so without this verb the S form
# had no mechanical half at all and the claim was false for it.
W=$(mktemp -d)
# The third argument defaults to a VALID mode line, and that is deliberate: a
# log carrying an implementation-step row owes one, so a pairing fixture without
# it is not a correct log and a pairing leg built on it would be measuring two
# things at once. The mode legs below pass their own value, or `-` for none.
mkpair() { # <design markers> <log keys> [mode line; `-` for none]
  local d="${W}/d.md" l="${W}/l.md" k m=${3-'**Mode:** R&D — `## Open questions` at `:12` is non-empty'}
  : > "$d"; printf '# Design\n\n' >> "$d"
  for k in $1; do printf 'An item that is settled. **[REDLINE %s]**\n' "$k" >> "$d"; done
  printf '# Redline log\n\n' > "$l"
  [ "$m" = '-' ] || printf '%s\n\n' "$m" >> "$l"
  printf '| Key | Type | Artefact sentence diverged from | What shipped instead |\n|---|---|---|---|\n' >> "$l"
  for k in $2; do printf '| %s | added | `x.md:1` — "a sentence long enough to locate" | what shipped |\n' "$k" >> "$l"; done
}

mkpair 'S8.1 S8.2' 'S8.1 S8.2'
run paired "${W}/d.md" "${W}/l.md"
check "both directions satisfied is clean" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"
has   "  and the pair count is reported, not just the verdict" "$OUT" "pairs=2"

mkpair 'S8.1 S8.2' 'S8.1'
run paired "${W}/d.md" "${W}/l.md"
check "a marker whose row is missing is a finding" "$RC" "1"
has   "  and the unpaired key is NAMED" "$OUT" "S8.2"
hasnt "  while the paired one is not reported as unpaired" "$OUT" "marker S8.1 "

mkpair 'S8.1' 'S8.1 S8.2'
run paired "${W}/d.md" "${W}/l.md"
check "a row whose marker is missing is a finding" "$RC" "1"
has   "  and the unpaired key is NAMED" "$OUT" "S8.2"

mkpair 'S8.1' 'S8.2'
run paired "${W}/d.md" "${W}/l.md"
check "both directions failing at once is still one finding verdict" "$RC" "1"
has   "  the marker with no row is named" "$OUT" "S8.1"
has   "  and the row with no marker is named" "$OUT" "S8.2"

# The R form is not special-cased: the verb reads whatever key the marker carries.
mkpair 'R2.4' 'R2.4'
run paired "${W}/d.md" "${W}/l.md"
check "the round-keyed form pairs by the same code path" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

# The control: no markers and no rows is clean, and must not be read as a pass
# that measured something. The count is what distinguishes the two.
mkpair '' ''
run paired "${W}/d.md" "${W}/l.md"
check "control: nothing to pair is clean" "$RC" "0"
has   "  and says so by count rather than silently" "$OUT" "pairs=0"

# The two assertions below are deliberately spelled as the FULL message. The
# usage text names a `<design>` argument, so a leg asserting only the word
# "design" is satisfied by the usage block an unimplemented verb prints -- a
# vacuous pass, which is how this leg read before the verb existed.
# THE MODE FIELD, AND THE OVER-FIRING CASE THAT BOUNDS IT. A log carrying an
# implementation-step row owes a mode: that row only exists because the step put
# the choice to the user, so a missing mode means the gate never fired. A log
# whose rows all came from review rounds never reaches that gate and owes
# nothing -- keying the refusal on "rows but no mode" would redden a correct
# log, which is why it is keyed on the presence of an `S` row instead.
mkmode() { # <row keys> <mode line, or empty for none>
  mkpair "$1" "$1" "${2:--}"
}

mkmode 'S8.1' '**Mode:** R&D — `## Open questions` names four unplanned extensions'
run paired "${W}/d.md" "${W}/l.md"
check "an implementation-step row with a mode naming its grounds is clean" "$RC" "0"
has   "  and the mode is reported, so a reader need not open the log" "$OUT" "mode=R&D"

mkmode 'S8.1' ''
run paired "${W}/d.md" "${W}/l.md"
check "an implementation-step row with NO mode line is a finding" "$RC" "1"
has   "  and says what is missing" "$OUT" "no mode"

mkmode 'S8.1' '**Mode:** Hybrid'
run paired "${W}/d.md" "${W}/l.md"
check "a mode naming a mode but no grounds is a finding" "$RC" "1"
has   "  because the grounds are what the choice is disagreed with on" "$OUT" "grounds"

# THE GROUNDS MUST BE READ OFF THE DESIGN, not merely present. The criterion is
# that the recommendation is checked on its EVIDENCE and never on which mode was
# recommended -- so what is assertable is that the grounds CITE the design: a
# backticked SECTION HEADING. A preference carries none, and neither does a
# line-addressed token any more -- a position outlives nothing, so grounds cite
# an entity. The leg below asserts that direction rather than leaving it to the
# pattern. The whole mode BLOCK is read, not its first line, because the grounds
# wrap and the heading lands after the wrap in every real example.
mkmode 'S8.1' '**Mode:** R&D — `## Open questions` opens "None blocking"'
run paired "${W}/d.md" "${W}/l.md"
check "grounds citing a design section are clean" "$RC" "0"
has   "  mode" "$OUT" "mode=R&D"

mkmode 'S8.1' '**Mode:** Hybrid — the base is carried as measured (`:351`)'
run paired "${W}/d.md" "${W}/l.md"
check "a line-number citation alone no longer satisfies it" "$RC" "1"
has   "  and the message asks for a section rather than naming the position" "$OUT" "no backticked heading"

mkmode 'S8.1' '**Mode:** R&D — because I prefer it'
run paired "${W}/d.md" "${W}/l.md"
check "grounds that cite nothing from the design are a finding" "$RC" "1"
has   "  and the message says what is missing, not that the mode is wrong" "$OUT" "cite"
hasnt "  so it never asserts WHICH mode was recommended" "$OUT" "R&D is"

mkmode 'S8.1' '**Mode:** Whatever — some grounds'
run paired "${W}/d.md" "${W}/l.md"
check "a mode outside the two-token vocabulary is a finding" "$RC" "1"

# The control, and the reason the refusal is not keyed on "rows but no mode".
mkmode 'R2.4' ''
run paired "${W}/d.md" "${W}/l.md"
check "control: a review-round row owes no mode at all" "$RC" "0"
has   "  and the verb says so rather than reporting a mode it never had" "$OUT" "mode=n/a"

mkmode 'R2.4' '**Mode:** Hybrid — carried from an earlier occasion'
run paired "${W}/d.md" "${W}/l.md"
check "control: a mode present on a review-only log is harmless, not a finding" "$RC" "0"

# A DOCUMENT THAT QUOTES THE MARKER TEMPLATE IS NOT A MARKED DOCUMENT. The
# design that defines the mechanism necessarily spells the token out, and so
# does this repository's own contract file. Found by running the verb against
# the live branch, where the template quote was the only finding while both real
# keys paired -- the same self-quoting false-positive class `revision` carries.
mkpair 'S8.1' 'S8.1'
printf 'The marker is written **[REDLINE R<round>.<finding #>]** and carries nothing else.\n' >> "${W}/d.md"
printf 'A second form is **[REDLINE S<step>.<ordinal>]** for an implementation divergence.\n' >> "${W}/d.md"
run paired "${W}/d.md" "${W}/l.md"
check "a quoted marker TEMPLATE is not counted as a marker" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"
has   "  and the real marker still paired" "$OUT" "pairs=1"
hasnt "  the placeholder is not reported as an unpaired key" "$OUT" "<round>"

run paired "${W}/absent.md" "${W}/l.md"
check "cannot-run: an absent design is exit 2" "$RC" "2"
has   "  and names what was missing, not the usage block" "$OUT" "no such design:"
run paired "${W}/d.md" "${W}/absent.md"
check "cannot-run: an absent log is exit 2" "$RC" "2"
has   "  and names what was missing, not the usage block" "$OUT" "no such redline log:"
run paired "${W}/d.md"
check "cannot-run: one argument is exit 2" "$RC" "2"
rm -rf "$W"

printf '\n== pending against a REF: the discriminator a stale task branch needs ==\n'
# The worktree is the wrong thing to read once a merge has happened. A merged
# task branch keeps its own copy of the log in its tree forever, so a worktree
# read on that branch refuses permanently and names a remedy already performed --
# which would make the branch cleanup unreachable. The question is whether the
# DEFAULT branch still carries an unprocessed log, and that is a question about a
# ref, not about the files in front of you.
PR=$(mktemp -d)
git -C "$PR" init -q
git -C "$PR" config user.email t@t; git -C "$PR" config user.name t
mkdir -p "${PR}/ai-docs/plans/done"
printf 'x\n' > "${PR}/ai-docs/plans/keep.md"
git -C "$PR" add -A; git -C "$PR" commit -qm base
# A log committed, then folded away in a later commit: the ref that still has it
# and the ref that does not.
printf '| Key |\n' > "${PR}/ai-docs/plans/t.redline.md"
git -C "$PR" add -A; git -C "$PR" commit -qm withlog
WITHLOG=$(git -C "$PR" rev-parse HEAD)
git -C "$PR" rm -q "${PR}/ai-docs/plans/t.redline.md" 2>/dev/null || git -C "$PR" rm -q ai-docs/plans/t.redline.md
git -C "$PR" commit -qm folded
FOLDED=$(git -C "$PR" rev-parse HEAD)

run pending "${PR}/ai-docs/plans"
check "no ref: the worktree is read, as before" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

run pending "${PR}/ai-docs/plans" "$WITHLOG"
check "a ref whose tree carries a log is present" "$RC" "1"
has   "  and names the log from that ref" "$OUT" "t.redline.md"

run pending "${PR}/ai-docs/plans" "$FOLDED"
check "a ref whose tree is folded is clean" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean"

# THE DISCRIMINATOR: worktree dirty, ref clean. This is the state a merged task
# branch is in after the fold landed on the default branch somewhere else.
printf '| Key |\n' > "${PR}/ai-docs/plans/t.redline.md"
run pending "${PR}/ai-docs/plans"
check "control: the worktree read still refuses in that state" "$RC" "1"
run pending "${PR}/ai-docs/plans" "$FOLDED"
check "but the REF read sees the fold and lets the cleanup through" "$RC" "0"
has   "  and says which ref it read" "$OUT" "ref="

run pending "${PR}/ai-docs/plans" no-such-ref
check "cannot-run: an unresolvable ref is exit 2" "$RC" "2"
has   "  and names the ref it could not resolve" "$OUT" "no-such-ref"
rm -rf "$PR"

printf '\n== pending against a REMOTE-TRACKING ref: a resolved ref is not yet a current one ==\n'
# A bare repository stands in for the remote, so no leg touches the network.
RW=$(mktemp -d)
g() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
git init -q --bare -b main "${RW}/b.git"
git init -q -b main "${RW}/c"
mkdir -p "${RW}/c/ai-docs/plans"
printf 'x\n' > "${RW}/c/ai-docs/plans/keep.md"
g "${RW}/c" add -A; g "${RW}/c" commit -qm base
g "${RW}/c" remote add origin "${RW}/b.git"
g "${RW}/c" push -q -u origin main 2>/dev/null
git clone -q "${RW}/b.git" "${RW}/d" 2>/dev/null
CP="${RW}/c/ai-docs/plans"
snap() { git -C "${RW}/c" for-each-ref; (cd "${RW}/c/.git" && find . | sort); }

printf '| Key |\n' > "${CP}/t.redline.md"
g "${RW}/c" add -A; g "${RW}/c" commit -qm withlog; g "${RW}/c" push -q 2>/dev/null
WITHLOG=$(git -C "${RW}/c" rev-parse HEAD)
g "${RW}/d" pull -q 2>/dev/null
g "${RW}/d" rm -q ai-docs/plans/t.redline.md; g "${RW}/d" commit -qm folded; g "${RW}/d" push -q 2>/dev/null

BEFORE=$(snap)
run pending "$CP" origin/main
check "stale ref whose tree carries a log, remote folded: exit 2, not a finding" "$RC" "2"
hasnt "  and no verdict is claimed" "$OUT" "verdict="
has   "  names the ref" "$OUT" "origin/main"
has   "  names the remote" "$OUT" "remote origin"
has   "  names the fetch that fixes it" "$OUT" "git fetch origin"
check "  and no ref or .git entry moved" "$(snap)" "$BEFORE"

g "${RW}/c" fetch -q
FOLDED=$(git -C "${RW}/c" rev-parse origin/main)
run pending "$CP" origin/main
check "current ref whose tree is folded: clean 0, as before" "$RC" "0"
has   "  naming the ref" "$OUT" "verdict=clean ref=origin/main"

printf '| Key |\n' > "${RW}/d/ai-docs/plans/u.redline.md"
g "${RW}/d" add -A; g "${RW}/d" commit -qm newlog; g "${RW}/d" push -q 2>/dev/null
run pending "$CP" origin/main
check "stale clean ref while the remote carries a log: exit 2, not clean" "$RC" "2"
has   "  and names the fetch" "$OUT" "git fetch origin"

g "${RW}/c" fetch -q
run pending "$CP" origin/main
check "current ref whose tree carries a log: finding 1, as before" "$RC" "1"
has   "  naming the log" "$OUT" "u.redline.md"

git -C "${RW}/c" remote set-head origin main
run pending "$CP" origin
check "the bare remote name, current: finding 1" "$RC" "1"
STALE_SAVED=$(git -C "${RW}/c" rev-parse origin/main)
git -C "${RW}/c" update-ref refs/remotes/origin/main "$FOLDED"
run pending "$CP" origin
check "the bare remote name resolves to the tracking ref and gets the leg: stale is exit 2" "$RC" "2"
has   "  naming the fetch" "$OUT" "git fetch origin"
git -C "${RW}/c" update-ref refs/remotes/origin/main "$STALE_SAVED"

g "${RW}/c" push -q origin "${WITHLOG}:refs/heads/a/refs/heads/main" 2>/dev/null
run pending "$CP" origin/main
check "a remote branch tail-matching refs/heads/main and sorting first does not stand in for it" "$RC" "1"
hasnt "  and the current ref is not called stale" "$OUT" "git fetch"
git -C "${RW}/b.git" update-ref -d refs/heads/a/refs/heads/main
g "${RW}/d" fetch -q
DP="${RW}/d/ai-docs/plans"
g "${RW}/c" pull -q 2>/dev/null
g "${RW}/c" rm -q ai-docs/plans/u.redline.md; g "${RW}/c" commit -qm refold; g "${RW}/c" push -q 2>/dev/null
run pending "$DP" origin/HEAD
check "origin/HEAD is checked against the branch it points to" "$RC" "2"
has   "  and names the ref as passed" "$OUT" "origin/HEAD"
g "${RW}/c" fetch -q

AHEAD=$(g "${RW}/c" commit-tree -p HEAD -m ahead "$(git -C "${RW}/c" rev-parse 'HEAD^{tree}')")
SAVED=$(git -C "${RW}/c" rev-parse origin/main)
git -C "${RW}/c" update-ref refs/remotes/origin/main "$AHEAD"
run pending "$CP" origin/main
check "a tracking ref AHEAD of its remote is exit 2 too" "$RC" "2"
has   "  naming the fetch" "$OUT" "git fetch origin"
git -C "${RW}/c" update-ref refs/remotes/origin/main "$SAVED"

git -C "${RW}/c" update-ref refs/remotes/zz/main "$SAVED"
run pending "$CP" zz/main
check "a tracking ref no configured remote maps is exit 2" "$RC" "2"
has   "  names the ref" "$OUT" "zz/main"
has   "  says no configured remote maps it" "$OUT" "no configured remote maps"
has   "  remedy: configure the remote" "$OUT" "configure the remote"
has   "  or pass a commit id" "$OUT" "pass a commit id"
hasnt "  and names no fetch, there being no remote" "$OUT" "git fetch"
git -C "${RW}/c" update-ref -d refs/remotes/zz/main

git -C "${RW}/c" branch -q local-folded "$FOLDED"
git -C "${RW}/c" remote set-url origin "${RW}/no-such-remote.git"
BEFORE=$(snap)
run pending "$CP" origin/main
check "an unreachable remote is exit 2, with no fallback to the local copy" "$RC" "2"
hasnt "  no verdict read from the local copy" "$OUT" "verdict="
has   "  says the remote could not be reached" "$OUT" "could not be reached"
has   "  names the ref" "$OUT" "origin/main"
has   "  names the remote and the fetch" "$OUT" "git fetch origin"
check "  and no ref or .git entry moved" "$(snap)" "$BEFORE"

run pending "$CP" "$WITHLOG"
check "remote unreachable: a commit id is read as given" "$RC" "1"
has   "  with the old result" "$OUT" "t.redline.md"
run pending "$CP" local-folded
check "remote unreachable: a local branch is read as given" "$RC" "0"
has   "  with the old result" "$OUT" "verdict=clean ref=local-folded"
run pending "$CP"
check "remote unreachable: the worktree form reads the worktree as before" "$RC" "0"
has   "  verdict" "$OUT" "verdict=clean logs=none"
g "${RW}/c" remote set-url origin "${RW}/b.git"

git -C "${RW}/b.git" update-ref -d refs/heads/main
run pending "$CP" origin/main
check "a branch the remote no longer has is exit 2" "$RC" "2"
has   "  says so" "$OUT" "no longer has"
has   "  and names the fetch" "$OUT" "git fetch origin"
g "${RW}/c" push -q origin main 2>/dev/null

git -C "${RW}/c" config remote.s.url "${RW}/b.git"
git -C "${RW}/c" config remote.s.fetch refs/heads/main:refs/remotes/s/main
git -C "${RW}/c" update-ref refs/remotes/s/main "$FOLDED"
run pending "$CP" s/main
check "an explicit (single-branch) refspec, stale: exit 2" "$RC" "2"
has   "  names the remote it maps to" "$OUT" "remote s "
has   "  and the fetch" "$OUT" "git fetch s"
git -C "${RW}/c" remote remove s

git -C "${RW}/c" remote add a/b "${RW}/b.git"
git -C "${RW}/c" update-ref refs/remotes/a/b/main "$FOLDED"
run pending "$CP" a/b/main
check "a remote whose name contains /, stale: exit 2" "$RC" "2"
has   "  names the whole remote name" "$OUT" "remote a/b "
has   "  and the fetch" "$OUT" "git fetch a/b"
git -C "${RW}/c" remote remove a/b

HX="${RW}/hx"; mkdir -p "$HX"
cp "$CHECK" "${HX}/check-redline.sh"
"${HX}/check-redline.sh" pending "$CP" origin/main > "${RW}/out" 2>&1; RC=$?; OUT=$(cat "${RW}/out")
check "a missing helper is exit 2, never a pass" "$RC" "2"
has   "  and names the helper" "$OUT" "ref-current.sh is missing or not executable"
cp "${HERE}/ref-current.sh" "${HX}/ref-current.sh"; chmod -x "${HX}/ref-current.sh"
"${HX}/check-redline.sh" pending "$CP" origin/main > "${RW}/out" 2>&1; RC=$?; OUT=$(cat "${RW}/out")
check "a non-executable helper is exit 2" "$RC" "2"
printf '#!/bin/sh\nexit 1\n' > "${HX}/ref-current.sh"; chmod +x "${HX}/ref-current.sh"
"${HX}/check-redline.sh" pending "$CP" origin/main > "${RW}/out" 2>&1; RC=$?; OUT=$(cat "${RW}/out")
check "a helper status of 1 is mapped to exit 2, not passed through as findings" "$RC" "2"
has   "  and the status is named when the helper gave no reason" "$OUT" "returned status 1"
rm -rf "$RW"

printf '\n== specform: a criterion may not name its own instrument ==\n'
# AC26 says an instrument-naming criterion is REFUSED, not merely discouraged, and
# the contract's own worked case argues that a refusal living only in prose is not
# a refusal -- move it there and the system stops refusing. This verb is what
# makes the criterion true of the shipped tree rather than of an instruction.
#
# THE LAST LEG IS THE ONE THAT MATTERS. The scan has to reach criterion BODIES,
# and the natural spelling does not: `grep -o '^| AC[0-9]*[^|]*'` stops at the
# first column separator, so it inspects the id cells and reports every spec
# clean. That false green was hit for real while auditing this very spec, so the
# leg plants the token in the LAST row's body, where a scan that stopped early or
# read only the first cell cannot see it.
SW=$(mktemp -d)
mkspec() { # <criterion body...> -> a spec whose criteria table holds them
  local b n=1
  printf '# Spec\n\n## Acceptance Criteria\n\n| # | Criterion |\n|---|---|\n' > "${SW}/s.md"
  for b in "$@"; do printf '| AC%s | %s |\n' "$n" "$b" >> "${SW}/s.md"; n=$((n+1)); done
}

mkspec 'The step refuses while the required record is absent, and does not refuse once it is present.'
run specform "${SW}/s.md"
check "a behaviour-shaped criterion is clean" "$RC" "0"
has   "  and the scanned count is reported, not just the verdict" "$OUT" "criteria=1"

mkspec 'The gate passes when `bash scripts/run-checks.sh` exits 0.'
run specform "${SW}/s.md"
check "a criterion naming a script invocation is a finding" "$RC" "1"
has   "  and the criterion is NAMED" "$OUT" "AC1"

mkspec 'Verified because `grep -n` over the file returns nothing.'
run specform "${SW}/s.md"
check "a criterion naming a search tool is a finding" "$RC" "1"

# The SUBJECT exemption, disclosed as a real case in this spec: AC10 names a
# surface that must not host the fold and AC17 a naming collision. Neither
# asserts which check ran, so neither is an instrument.
mkspec 'The fold is reachable from its own command and never from `/pr-merged`.'
run specform "${SW}/s.md"
check "a slash-command named as the SUBJECT is clean" "$RC" "0"

# The discriminating leg: body of the LAST row.
mkspec 'Clean behaviour one.' 'Clean behaviour two.' 'Holds when `wc -c` reports under the cap.'
run specform "${SW}/s.md"
check "a token in the LAST criterion's body is still found" "$RC" "1"
has   "  and it is attributed to that criterion, not the first" "$OUT" "AC3"
has   "  with the scan's reach reported" "$OUT" "criteria=3"

# ONE LEG PER TOKEN CLASS, because a group sharing a single input cannot ratchet:
# delete one alternative from the pattern and the suite must go red for THAT class
# alone. Round 3 measured the old shape failing this -- removing the whole `git …`
# alternative reddened nothing at all.
for tok in '`bash scripts/x.sh`' '`scripts/check-redline.sh`' '`git grep`' '`git rev-parse`' \
           '`./gradlew :mod:test`' '`jq`' '`grep`' '`wc -c`' '`xargs`' \
           '%TEST_CMD%' '`check-redline`' '`test-check-redline`' \
           '`test_marker_without_row`' '`shouldRefuseWhenAbsent`' 'exits 0'; do
  mkspec "The property holds, verified by ${tok} over the tree."
  run specform "${SW}/s.md"
  check "instrument class refused: ${tok}" "$RC" "1"
done

# THE VERB SHIPS TO CONSUMERS, so the tool list cannot be this repository's own
# vocabulary. A project on gradle, npm, maven or pytest would have a criterion
# naming ITS build tool admitted, which is the same defect as a narrow predicate
# under a wide promise -- the direction that gives false assurance to someone
# else's tree rather than to this one.
for tok in '`npm test`' '`pnpm build`' '`yarn lint`' '`cargo test`' '`go test ./...`' \
           '`gradle check`' '`./gradlew :mod:test`' '`mvn verify`' '`pytest -k x`' \
           '`python3 -m pytest`' '`node scripts/x.js`' '`ktlint`' '`eslint`' '`ruff check`' \
           '`dotnet test`' '`rake spec`' '`tox`'; do
  mkspec "The property holds, verified by ${tok} over the tree."
  run specform "${SW}/s.md"
  check "consumer build tool refused: ${tok}" "$RC" "1"
done

# Test identifiers in the shapes other languages actually use, not only snake_case.
for tok in '`FooTest`' '`RedlineFoldSpec`' '`TestRedlineFold`' '`RedlineFoldTests`' \
           '`should_refuse_when_absent`' '`ItRefusesWhenAbsent`'; do
  mkspec "Covered by ${tok} in the suite."
  run specform "${SW}/s.md"
  check "test identifier refused: ${tok}" "$RC" "1"
done

# And one leg per ADMITTED class, because a pattern that refuses everything is not
# a form check -- it is a ban on backticks.
for tok in '`/pr-merged`' '`/improve`' '`## Out of scope`' '`ai-docs/plans/*.redline.md`' \
           '`**[REDLINE S8.1]**`' '`R<round>.<finding #>`' '`added`'; do
  mkspec "The fold is reachable from its own command and never from ${tok}."
  run specform "${SW}/s.md"
  check "subject class admitted: ${tok}" "$RC" "0"
done

run specform "${SW}/absent.md"
check "cannot-run: an absent spec is exit 2" "$RC" "2"
has   "  and names what was missing, not the usage block" "$OUT" "no such spec:"
run specform
check "cannot-run: no argument is exit 2" "$RC" "2"
rm -rf "$SW"

run bogus x
check "an unknown verb is exit 2" "$RC" "2"
has   "  and prints every verb" "$OUT" "check-redline.sh revision"
run
check "no verb at all is exit 2" "$RC" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
