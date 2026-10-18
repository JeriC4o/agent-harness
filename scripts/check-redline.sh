#!/usr/bin/env bash
#
# Is the task's redline log processed, and did the closing fold leave documents
# that describe what shipped?
#
# Run:  check-redline.sh pending     <plans-dir>
#       check-redline.sh folded      <spec> <design>
#       check-redline.sh suppression <file>
#       check-redline.sh revision    <file>
#       check-redline.sh paired      <design> <log>
#       check-redline.sh specform    <spec>
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-redline.sh
#
# THE THREE-OUTCOME CONVENTION IS THE CONTRACT, and `pending` is why it is
# spelled out rather than left to the reader. A caller refuses on anything that
# is not a clean 0 and says which of the two it got. Were the polarity inverted
# -- 0 for a log that IS present, with the caller refusing on 0 -- then a
# missing directory, a lost execute bit and every internal error would all
# return non-zero, and the caller would read non-zero as "nothing to refuse" and
# proceed to delete. The one check whose whole purpose is to be a backstop would
# have silent passage as its failure mode, and neither of the obvious legs (it
# fires on a present log, it does not fire on an absent one) is a cannot-run, so
# neither could see it.
#
# `revision`'s PHRASE LIST IS CONTRACT, not an implementation choice, and so is
# its bound. It matches the named introducers of a revision account and nothing
# more: it catches the common shapes and not every possible paraphrase, and it
# FIRES on a document that merely QUOTES one of them -- which a document stating
# the rule necessarily does. That is why it is a SPOT-CHECK the FOLD runs as its
# own step -- `skills/redline-fold/SKILL.md` calls `revision <design>` directly
# -- and NOT a leg inside `folded`, which checks the retained spec sections, the
# residue headings, the marker and the log and never reads the phrase list. The
# distinction is worth the sentence: a comment that promises a leg the code does
# not have is the quietest kind of false green, and this one is the phrase list's
# only caller outside its own suite. Likewise the assertion that every section
# describes the shipped state is a judgement step in the fold's brief, not a leg
# here. A fragment
# search for superseded material is actively misleading, not merely weak: a
# document that records its own corrections holds the superseded wording inside
# a quotation, so an absence proved from a fragment is a false positive.
#
# `suppression`'s PREDICATE IS CONTRACT TOO, and the disjunction is the whole of
# it. The enumeration pattern is `done/` OR `design\.md`, because the narrower
# `design\.md` alone was MEASURED to reach two of the four instructions in the
# live reviewer brief and to miss the restatement that confers the same
# authority by naming the completed-plans DIRECTORY -- the one that survives any
# search for the filename. The disjunction reproduces all four. A criterion met
# by the narrower pattern is a false green, so the wider one is part of the
# check. The verb then asserts a per-line DISPOSITION rather than a count: of
# the four the disjunction reaches in that file, two confer suppression and must
# name the spec alone, one is the use-case coverage check and is retained
# verbatim, and one is a heading. It prints the enumerated count beside the
# verdict, because an enumeration that silently narrowed its own input set is
# the quietest false green there is.
#
# ITS UNIT IS THE LINE, which is the bound worth stating: every suppression
# instruction in the live brief is written on one line, so the line is the
# instruction. Hard-wrap one of them across two lines and the half carrying the
# path is still enumerated while the suppression wording sits on the other, so
# the line takes the not-suppression disposition. The enumerated count is what
# surfaces that -- it does not drop -- but the disposition would be wrong, so a
# rewrap of this file is a change to this check's input.

set -uo pipefail

die() { printf 'check-redline: %s\n' "$2" >&2; exit "$1"; }

USAGE='usage: check-redline.sh pending     <plans-dir> [ref]
       check-redline.sh folded      <spec> <design>
       check-redline.sh suppression <file>
       check-redline.sh revision    <file>
       check-redline.sh paired      <design> <log>
       check-redline.sh specform    <spec>'

for tool in git grep awk sed tr diff comm sort dirname basename mktemp; do
  command -v "$tool" >/dev/null 2>&1 || die 2 "${tool} is not on PATH, so this gate cannot run"
done

VERB=${1:-}
A1=${2:-}
A2=${3:-}

# `paired` IS WHAT MAKES THE BOTH-WAYS CLAIM TRUE, and it exists because the
# in-round half cannot cover every key form. check-fix-plan.sh's A8 reads the
# keys off a round's fix-plan table and rebuilds them as `R<round>.<finding #>`,
# so it covers the review-and-fix form only. A divergence found during
# implementation never appears in a plan table, so its `S<step>.<ordinal>` row
# had no mechanical half at all -- and the template and the marking contract
# both state that a row with no marker and a marker with no row are each a
# finding. This verb reads whatever key the marker carries, so neither form is
# special-cased and a third would need no change here.
#
# THE COUNT IS PART OF THE VERDICT, not decoration: an empty design and an empty
# log pair vacuously, and `pairs=0` is the only thing that distinguishes "both
# directions checked and agreed" from "there was nothing to check".
do_paired() { # <design> <log>
  local design=$1 log=$2 k pairs modeline='' modeblock='' rest='' mode='n/a'
  readable "$design" 'design'
  readable "$log" 'redline log'
  # A DOCUMENT THAT QUOTES THE TEMPLATE IS NOT A MARKED DOCUMENT, so the key
  # SHAPE is part of the check. The design that defines this mechanism spells the
  # token out to explain it, and the contract file does too, so without the shape
  # filter the first live run reports `R<round>.<finding #>` as an unpaired key --
  # which it did. A key carries alphanumerics, dots, dashes and underscores; a
  # placeholder carries angle brackets and spaces and is therefore not one. The
  # same filter binds BOTH sides, because a log may quote the row template as
  # readily as a design quotes the marker.
  grep -o '\[REDLINE [^]]*\]' "$design" | sed 's/^\[REDLINE //; s/\]$//' \
    | grep -Ex '[A-Za-z0-9][A-Za-z0-9._-]*' | sort -u > "${WORK}/pm"
  # Cell 2 is the key, the same position check-fix-plan.sh reads it from. The
  # header and the separator are rejected by value rather than by line number,
  # because a log gains a head and the table's offset is not fixed.
  #
  # COMPARISON IS BY EQUALITY, via sorted sets and `comm`, never by containment:
  # `R1.1` is a prefix of `R1.10` and `S8.1` of `S8.10`, so a containment search
  # would report item 1 as accounted for because item 10 was. The hazard is the
  # one check-fix-plan.sh already records at its own key comparison.
  awk -F'|' 'NF >= 5 { k = $2; gsub(/^[ \t]+|[ \t]+$/, "", k)
                       if (k != "" && k != "Key" && k ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) print k }' "$log" \
    | sort -u > "${WORK}/pr"
  comm -23 "${WORK}/pm" "${WORK}/pr" > "${WORK}/p-nomarkerrow"
  comm -13 "${WORK}/pm" "${WORK}/pr" > "${WORK}/p-norow"
  while read -r k; do
    [ -n "$k" ] || continue
    finding "marker ${k} has no row in the log, so a settled item points at nothing"
  done < "${WORK}/p-nomarkerrow"
  while read -r k; do
    [ -n "$k" ] || continue
    finding "row ${k} has no marker in the design, so the correction names no item"
  done < "${WORK}/p-norow"
  pairs=$(comm -12 "${WORK}/pm" "${WORK}/pr" | grep -c . )

  # THE MODE FIELD, AND THE OVER-FIRING CASE THAT BOUNDS IT. An
  # implementation-step row exists only because the step put the once-per-task
  # choice to the user, so a log carrying one and no mode means the gate never
  # fired. A log whose rows all came from review rounds never reaches that gate
  # and owes nothing -- keying the refusal on "rows but no mode" would redden a
  # correct log, so it is keyed on the presence of an `S` row instead. The
  # GROUNDS are required as well as the token, because a mode is meant to be
  # disagreed with on what it rested on rather than as a preference.
  if grep -qE '^S[0-9]+\.' "${WORK}/pr"; then
    modeline=$(grep -m1 -E '^\*\*Mode:\*\*' "$log")
    if [ -z "$modeline" ]; then
      finding 'the log carries an implementation-step row but no mode line, so the once-per-task choice was never put to the user'
    else
      mode=$(printf '%s' "$modeline" | sed -E 's/^\*\*Mode:\*\*[[:space:]]*//' | awk '{print $1}')
      case $mode in
        'R&D'|'Hybrid') ;;
        *) finding "the mode is [${mode}], which is outside the two-token vocabulary R&D | Hybrid" ;;
      esac
      rest=$(printf '%s' "$modeline" | sed -E 's/^\*\*Mode:\*\*[[:space:]]*[^[:space:]]+[[:space:]]*//')
      if [ -z "$rest" ]; then
        finding 'the mode names no grounds, and the grounds are what the choice can be disagreed with on'
      else
        # THE GROUNDS MUST BE READ OFF THE DESIGN, not merely present. What is
        # assertable here is the CITATION, never which mode was recommended --
        # a check that judged the recommendation would be judging a judgement.
        # A backticked token carrying a line number or a section heading is
        # evidence pointing at the document; a preference carries neither.
        # The whole mode BLOCK is read rather than its first line, because the
        # grounds wrap and the anchors land after the wrap in every real
        # example. Bound, stated as contract: this catches grounds that cite
        # NOTHING. It cannot tell a relevant citation from an irrelevant one,
        # and the reader the gate exists for -- the user confirming the
        # recommendation in one word -- is the one who can.
        modeblock=$(awk '/^\*\*Mode:\*\*/ { f = 1 }
                         f && /^[[:space:]]*$/ { exit }
                         f { print }' "$log")
        printf '%s\n' "$modeblock" | grep -qE '`[^`]*(##|:[0-9]+)[^`]*`' \
          || finding 'the mode grounds cite nothing from the design -- no backticked anchor and no section heading -- so there is no evidence to disagree with'
      fi
    fi
  fi

  printf 'check-redline: verb=paired verdict=%s pairs=%s mode=%s findings=%s\n' \
    "$(verdict_word)" "$pairs" "$mode" "$FINDINGS"
  [ "$FINDINGS" -eq 0 ]
}

# `specform` IS WHAT MAKES THE SPEC'S FORM RULE A REFUSAL rather than an
# instruction. A criterion states an observable behaviour and the condition that
# triggers it; it may not name the instrument that checks it, because a criterion
# naming one asserts which instrument ran rather than what the system does, and it
# cannot survive a change of instrument. The rule and its settling test live in
# `agents/spec-writer.md`; this is its enforcement.
#
# THE SCAN MUST REACH CRITERION BODIES, and the natural spelling does not: a
# `grep -o` anchored at the row start stops at the first column separator, so it
# inspects the ID CELLS and reports every spec clean. That false green was hit for
# real while auditing a spec by hand. The row is therefore split on the separator
# and the body taken from the third field onward. **What GUARDS that is the suite's
# leg planting a token in the LAST criterion's body, and nothing else** -- in
# particular not the printed `criteria=` count, which is incremented per selected
# ROW and is independent of the body extraction: replace the extraction with the
# broken form and the count still reports 26. The count tells a reader how many
# criteria the selector matched, which is worth printing and is not a reach check.
#
# THE SUBJECT EXEMPTION IS PART OF THE RULE, not a loophole: a criterion whose
# subject IS a named surface -- the command a fold must not be reachable from, a
# heading the fold retains, a marker's own spelling, a disposition token -- names
# it without asserting which check ran.
#
# ITS BOUND, stated because the other verbs state theirs and this one's is the
# widest: it classifies BACKTICKED tokens by shape plus two bare phrases. It
# catches an invocation, an executable path, a bare tool name, a build placeholder,
# a hyphenated check or test command, and a test-identifier shape. It does NOT
# read prose: a criterion that names an instrument CLASS in words -- "a test
# asserts", "the check that compares" -- passes, and that reading is a judgement
# left to the reviewer. A criterion naming a tool in prose without backticks
# passes too. So a clean verdict means no criterion SPELLS an instrument, never
# that no criterion implies one.
INSTRUMENT_BARE='exits[[:space:]]+0|%[A-Z_]+%'
# THE TOOL LIST IS NOT THIS REPOSITORY'S VOCABULARY, and that is the point: the
# verb ships to consumers, so a project on gradle, npm, maven or pytest must have
# a criterion naming ITS build tool refused too. A list covering only the shell
# would give false assurance to every tree but this one.
TOOLS='bash|sh|zsh|jq|grep|wc|awk|sed|diff|stat|find|xargs|cat|head|tail|cut|sort|comm|make|git|shellcheck|printf|echo'
TOOLS="${TOOLS}|npm|pnpm|yarn|npx|cargo|go|gradle|mvn|maven|rake|tox|dotnet|bundle"
TOOLS="${TOOLS}|pytest|python|python3|ruby|node|deno|ktlint|eslint|prettier|ruff|black|mypy|tsc\\b|gofmt"

# <token, backticks already stripped> -> 0 when it spells an instrument
sf_is_instrument() {
  case $1 in
    /*)    return 1 ;;   # a slash-command names a SURFACE, not a check
    '#'*)  return 1 ;;   # a heading the fold retains
    '**'*) return 1 ;;   # a marker's own spelling
    '<'*)  return 1 ;;   # a key form or placeholder shape
  esac
  printf '%s' "$1" | grep -qE "^(${TOOLS})([[:space:]]|\$)" && return 0
  printf '%s' "$1" | grep -qE '\.(sh|bash|py|rb|js)([[:space:]]|$)' && return 0
  printf '%s' "$1" | grep -qE '^\./' && return 0
  printf '%s' "$1" | grep -qE '^(check|test)-[a-z0-9.-]+$' && return 0
  # Test-identifier shapes across languages, not only snake_case: a criterion
  # naming the test that covers it is naming an instrument in any dialect.
  printf '%s' "$1" | grep -qE '^(test_[A-Za-z0-9_]+|[A-Za-z0-9_]*_test|should_[A-Za-z0-9_]+)$' && return 0
  printf '%s' "$1" | grep -qE '^(Test[A-Z][A-Za-z0-9]*|[A-Z][A-Za-z0-9]*(Test|Tests|Spec|Specs|IT)|should[A-Z][A-Za-z0-9]*|[Ii]t[A-Z][A-Za-z0-9]*)$' && return 0
  return 1
}

do_specform() { # <spec>
  local spec=$1 n=0 body id row tok
  readable "$spec" 'spec'
  : > "${WORK}/sf"
  while IFS= read -r row; do
    id=$(printf '%s' "$row" | awk -F'|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }')
    body=$(printf '%s' "$row" | cut -d'|' -f3-)
    n=$((n + 1))
    if printf '%s\n' "$body" | grep -qE "$INSTRUMENT_BARE"; then
      printf '%s\n' "$id" >> "${WORK}/sf"
      continue
    fi
    printf '%s\n' "$body" | grep -o '`[^`]*`' | tr -d '`' > "${WORK}/sf-toks"
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      if sf_is_instrument "$tok"; then
        printf '%s\n' "$id" >> "${WORK}/sf"
        break
      fi
    done < "${WORK}/sf-toks"
  done < <(grep -E '^\| AC[0-9]+ \|' "$spec")
  while read -r id; do
    [ -n "$id" ] || continue
    finding "${id} spells an instrument -- a criterion states the behaviour, never the command, script, tool or test identifier that checks it"
  done < "${WORK}/sf"
  printf 'check-redline: verb=specform verdict=%s criteria=%s findings=%s\n' \
    "$(verdict_word)" "$n" "$FINDINGS"
  [ "$FINDINGS" -eq 0 ]
}

case $VERB in
  pending|folded|suppression|revision|paired|specform) ;;
  *) die 2 "$USAGE" ;;
esac

WORK=$(mktemp -d) || die 2 'mktemp -d failed, so this gate cannot run'
trap 'rm -rf "$WORK"' EXIT

readable() { # <path> <what it is>
  [ -n "$1" ] || die 2 "$USAGE"
  [ -f "$1" ] || die 2 "no such $2: $1"
  [ -r "$1" ] || die 2 "$2 is not readable: $1"
}

# The three residue patterns the fold must leave nothing of: the two spent
# process headings and the marker token. Named in one place, so the fold's brief
# and this gate cannot come to disagree about how many there are.
RESIDUE_HEADINGS='^## Handoff plan|^## Open questions'
RESIDUE_MARKER='[REDLINE '

# The spec's surviving payload: its record of DELIBERATE ABSENCE. The design has
# no section that can carry this, so these three are retained verbatim while the
# rest of the spec goes.
RETAINED='## Out of scope
## Deferred
## Key decisions'

REVISION_PHRASES='an earlier draft
an earlier version of this
an earlier revision
a previous draft
a previous round argued
a previous round found
a first draft
the first draft
rather than quietly correcting
previously claimed
originally claimed
the stale claim'

SUPPRESSION_MARKERS='do not raise
intentional
suppress'

FINDINGS=0
finding() { FINDINGS=$((FINDINGS + 1)); printf '  finding: %s\n' "$1"; }
verdict_word() { if [ "$FINDINGS" -eq 0 ]; then printf clean; else printf dirty; fi; }

section_of() { # <heading line> <file> -> the heading and its body, verbatim
  awk -v want="$1" '
    /^## / { line = $0; sub(/[[:space:]]+$/, "", line); inside = (line == want); if (inside) print; next }
    inside { print }
  ' "$2"
}

# --- pending ----------------------------------------------------------------
# THE OPTIONAL REF IS THE POST-MERGE FORM OF THE QUESTION, and the worktree form
# is wrong once a merge has happened. A merged task branch keeps its own copy of
# the log in its tree forever, so a worktree read while standing on it refuses
# permanently and names a remedy that has already been performed somewhere else --
# which would make the branch cleanup unreachable through the caller that refuses.
# What a post-merge caller must ask is whether the DEFAULT branch still carries an
# unprocessed log, because that is where a fold lands in either window. With no ref
# the worktree is read, which is the right question before a merge.
do_pending() {
  local dir=$1 ref=${2:-} p found='' listing
  [ -n "$dir" ] || die 2 "$USAGE"
  [ -d "$dir" ] || die 2 "no such plans directory: ${dir}"
  [ -r "$dir" ] || die 2 "plans directory is not readable: ${dir}"
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die 2 "${dir} is not inside a git work tree, so there is no branch to check"
  if [ -n "$ref" ]; then
    git -C "$dir" rev-parse --verify --quiet "${ref}^{tree}" >/dev/null \
      || die 2 "cannot resolve ref ${ref}, so there is no tree to read"
    listing=$(git -C "$dir" ls-tree -r --name-only "$ref")
    found=$(printf '%s\n' "$listing" | grep -E '(^|/)[^/]*\.redline\.md$' | tr '\n' ' ')
    found=${found% }
    if [ -n "$found" ]; then
      printf 'check-redline: verb=pending verdict=present ref=%s logs=%s\n' "$ref" "$found"
      printf '  finding: an unprocessed redline log is in the tree of %s, so the redline fold has not run there\n' "$ref"
      return 1
    fi
    printf 'check-redline: verb=pending verdict=clean ref=%s logs=none\n' "$ref"
    return 0
  fi
  # BOTH LOCATIONS: a branch that never reached the task's close carries its log
  # in the active directory, while one that did carries it beside the completed
  # plan.
  for p in "${dir}"/*.redline.md "${dir}"/done/*.redline.md; do
    [ -f "$p" ] || continue
    found="${found}${found:+ }${p}"
  done
  if [ -n "$found" ]; then
    printf 'check-redline: verb=pending verdict=present logs=%s\n' "$found"
    printf '  finding: an unprocessed redline log is on the branch, so the redline fold has not run\n'
    return 1
  fi
  printf 'check-redline: verb=pending verdict=clean logs=none\n'
}

# --- folded -----------------------------------------------------------------
do_folded() {
  local spec=$1 design=$2 sdir plans base h p log=''
  readable "$spec" 'spec'
  readable "$design" 'design'
  sdir=$(dirname -- "$spec")
  base=$(basename -- "$spec" .spec.md)
  case $sdir in */done) plans=${sdir%/done} ;; *) plans=$sdir ;; esac

  git -C "$sdir" rev-parse --verify --quiet HEAD >/dev/null 2>&1 \
    || die 2 "${sdir} has no HEAD commit, so there is no comparand for the retained sections"
  # VERSION CONTROL IS THE COMPARAND, deliberately: HEAD predates the rewrite and
  # therefore cannot BE the rewrite. A captured scratch copy would be written by
  # the same pass that rewrites the file; `git show` cannot be.
  git -C "$sdir" show "HEAD:./$(basename -- "$spec")" > "${WORK}/head-spec" 2>/dev/null \
    || die 2 "${spec} is not in HEAD, so there is no pre-fold text to compare against"

  printf 'check-redline: verb=folded spec=%s design=%s\n' "$spec" "$design"
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    section_of "$h" "$spec" > "${WORK}/live"
    section_of "$h" "${WORK}/head-spec" > "${WORK}/was"
    # diff and not a string comparison: command substitution strips trailing
    # newlines from both sides, so a byte claim made that way cannot see the one
    # difference a hand-rewrite is most likely to introduce.
    if [ ! -s "${WORK}/live" ]; then
      finding "the spec no longer carries a \`${h}\` section, which the collapse retains verbatim"
    elif ! diff -q "${WORK}/live" "${WORK}/was" >/dev/null 2>&1; then
      finding "\`${h}\` is not byte-identical to its text in HEAD"
    fi
  done <<EOF
$RETAINED
EOF

  if grep -qE -- "$RESIDUE_HEADINGS" "$design"; then
    finding "the design still carries a spent process heading: $(grep -nE -- "$RESIDUE_HEADINGS" "$design" | tr '\n' ' ')"
  fi
  if grep -qF -- "$RESIDUE_MARKER" "$design"; then
    finding "the design still carries a redline marker: $(grep -nF -- "$RESIDUE_MARKER" "$design" | tr '\n' ' ')"
  fi

  for p in "${plans}/${base}.redline.md" "${plans}/done/${base}.redline.md"; do
    [ -f "$p" ] || continue
    log="${log}${log:+ }${p}"
  done
  [ -z "$log" ] || finding "the redline log survives at ${log}, and the fold removes it"

  printf 'check-redline: verb=folded verdict=%s findings=%s\n' "$(verdict_word)" "$FINDINGS"
  [ "$FINDINGS" -eq 0 ]
}

# --- suppression ------------------------------------------------------------
do_suppression() {
  local file=$1 line no body lower marker confers disp enumerated=0
  readable "$file" 'file'
  printf 'check-redline: verb=suppression file=%s pattern=done/|design\\.md\n' "$file"
  grep -nE -- 'done/|design\.md' "$file" > "${WORK}/enumerated"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    no=${line%%:*}
    body=${line#*:}
    enumerated=$((enumerated + 1))
    lower=$(printf '%s' "$body" | tr 'A-Z' 'a-z')
    confers=0
    while IFS= read -r marker; do
      case $lower in *"$marker"*) confers=1 ;; esac
    done <<EOF
$SUPPRESSION_MARKERS
EOF
    if [ "$confers" -eq 0 ]; then
      disp='not-suppression'
    else
      disp=suppression
      case $body in
        *design.md*)
          finding "${file}:${no} confers suppression and names a design document" ;;
        *done/*)
          case $body in
            *spec.md*) ;;
            *) finding "${file}:${no} confers suppression and names the completed-plans directory without narrowing to the spec" ;;
          esac ;;
      esac
    fi
    printf '  %s:%s %s\n' "$file" "$no" "$disp"
  done < "${WORK}/enumerated"
  printf 'check-redline: verb=suppression verdict=%s enumerated=%s findings=%s\n' \
    "$(verdict_word)" "$enumerated" "$FINDINGS"
  [ "$FINDINGS" -eq 0 ]
}

# --- revision ---------------------------------------------------------------
do_revision() {
  local file=$1 phrase lines
  readable "$file" 'file'
  tr 'A-Z' 'a-z' < "$file" > "${WORK}/lowered"
  printf 'check-redline: verb=revision file=%s\n' "$file"
  while IFS= read -r phrase; do
    [ -n "$phrase" ] || continue
    lines=$(grep -nF -- "$phrase" "${WORK}/lowered" | awk -F: '{ printf "%s%s", sep, $1; sep = "," }')
    [ -z "$lines" ] || finding "a revision-account introducer is present -- [${phrase}] at line ${lines}"
  done <<EOF
$REVISION_PHRASES
EOF
  printf 'check-redline: verb=revision verdict=%s findings=%s\n' "$(verdict_word)" "$FINDINGS"
  [ "$FINDINGS" -eq 0 ]
}

case $VERB in
  pending)     do_pending "$A1" "$A2" ;;
  folded)      do_folded "$A1" "$A2" ;;
  suppression) do_suppression "$A1" ;;
  revision)    do_revision "$A1" ;;
  paired)      do_paired "$A1" "$A2" ;;
  specform)    do_specform "$A1" ;;
esac
