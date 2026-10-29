#!/usr/bin/env bash
#
# Tests for check-redline.sh.
#
# Run: bash scripts/test-check-redline.sh
#
# Every verb gets three legs, never two: an input that must make the check come
# back NON-EMPTY, a control that must make it come back EMPTY, and a CANNOT-RUN
# leg, because neither of the first two is a cannot-run and so neither can see an
# internal error arriving as a clean result.
#
# The checker is invoked BY PATH, never as `bash <path>`, because that is how a
# skill invokes a plugin script. The convenient form does not need the execute
# bit, so a suite spelled that way is green precisely because it never runs the
# thing the way it ships.

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

printf '\n== suppression: the archive listing is a third spelling ==\n'
# The listing carries a design's use cases beside the spec's record, so a line
# naming it can hand a design suppression authority while matching neither of
# the two path spellings. Each fixture is one line, for the reason above.
{ printf '# Reviewer brief\n\n'
  printf -- '- Skip anything the listing documents as intentional.\n'
} > "${S}/listing-bare.md"
check "the fixture carries neither path spelling" "$(grep -cE 'done/|design\.md' "${S}/listing-bare.md")" "0"
run suppression "${S}/listing-bare.md"
check "a line conferring suppression through the listing alone, naming no spec, is a finding" "$RC" "1"
has   "  and says so" "$OUT" "names the archive listing without naming the spec"
has   "  the printed pattern names the wider enumeration" "$OUT" 'pattern=done/|design\.md|(?i)plan-archive|(?i)\blisting\b'

{ printf '# Reviewer brief\n\n'
  printf -- '- Skip a finding the Archive Listing records as intentional for a specific reason.\n'
  printf -- '- Do not raise anything plan-archive.sh shows was left out.\n'
} > "${S}/listing-spellings.md"
run suppression "${S}/listing-spellings.md"
has   "any capitalisation of the word, and the script name, are enumerated" "$OUT" "enumerated=2"
check "  a substring of the spec's name is not the spec: both are findings" \
      "$(printf '%s\n' "$OUT" | grep -c 'without naming the spec')" "2"

{ printf '# Reviewer brief\n\n'
  printf -- '- Check the listing for a completed spec whose record documents it as intentional.\n'
  printf -- '- Read the archive listing whole; no instruction here confers anything.\n'
} > "${S}/listing-narrowed.md"
run suppression "${S}/listing-narrowed.md"
check "control: a listing line that names the spec is clean" "$RC" "0"
has   "  both lines enumerated, one dispositioned suppression" "$OUT" "verdict=clean enumerated=2 findings=0"
check "  the suppression line is dispositioned as such" "$(printf '%s\n' "$OUT" | grep -c ' suppression$')" "1"

{ printf '# Reviewer brief\n\n'
  printf -- '- Enlisting helpers or reading listings is not the archive word, and confers nothing intentional.\n'
} > "${S}/listing-word.md"
run suppression "${S}/listing-word.md"
check "control: the word is matched whole, so neither longer word is enumerated" "$RC" "0"
has   "  nothing enumerated" "$OUT" "enumerated=0"

# The live reviewer brief, on its enumeration and its verdict. The count proves
# the pattern still reaches every line in it that names the completed plans --
# the instruction to read the listing, the design-conformance heading, the
# coverage bullet, and the two lines conferring suppression; the verdict proves
# both of those lines narrow the suppression to the spec.
run suppression "${REPO}/agents/review-findings.md"
has "the live reviewer brief enumerates five lines" "$OUT" "enumerated=5"
check "  and is clean" "$RC" "0"

run suppression "${S}/nope.md"
check "a missing file is exit 2" "$RC" "2"
has   "  and names it" "$OUT" "no such file"

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

# The SUBJECT exemption: a criterion naming the surface it is about asserts
# nothing about which check ran, so it is not an instrument.
mkspec 'The cleanup is reachable from its own command and never from `/improve`.'
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
for tok in '`FooTest`' '`CleanupRefusalSpec`' '`TestCleanupRefusal`' '`CleanupRefusalTests`' \
           '`should_refuse_when_absent`' '`ItRefusesWhenAbsent`'; do
  mkspec "Covered by ${tok} in the suite."
  run specform "${SW}/s.md"
  check "test identifier refused: ${tok}" "$RC" "1"
done

# And one leg per ADMITTED class, because a pattern that refuses everything is not
# a form check -- it is a ban on backticks.
for tok in '`/pr-merged`' '`/improve`' '`## Out of scope`' '`ai-docs/plans/*.links.md`' \
           '`**Design:**`' '`<spec-base>.<suffix>`' '`correction:`'; do
  mkspec "The cleanup is reachable from its own command and never from ${tok}."
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
has   "  and prints both verbs" "$OUT" "check-redline.sh suppression"
run
check "no verb at all is exit 2" "$RC" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
