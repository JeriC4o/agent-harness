#!/usr/bin/env bash
#
# Two checks of what a plan and the review that reads it may say: a spec's
# criteria spell no instrument, and the whole-repository review takes its
# suppression authority from completed specs alone.
#
# Run:  check-redline.sh specform    <spec>
#       check-redline.sh suppression <file>
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-redline.sh
#
# `suppression`'s PREDICATE IS CONTRACT, and the disjunction is the whole of
# it. The enumeration pattern is `done/` OR `design\.md` OR the archive
# listing -- its script name, or the word `listing` matched case-insensitively
# as a whole word. The narrower `design\.md` alone was MEASURED to miss the
# restatement that confers the same authority by naming the completed-plans
# DIRECTORY -- the one that survives any search for the filename. The listing is
# a third way to name the same material, and it carries a design's use cases
# beside the spec's record, so a line saying "skip anything the listing
# documents as intentional" would hand a design suppression authority through a
# spelling neither path matches. Matching the bare word reaches the listing
# however a line qualifies it. A criterion met by a narrower pattern is a false
# green, so the wider one is part of the check. The verb then asserts a per-line
# DISPOSITION rather than a count: in the live reviewer brief the disjunction
# reaches five lines -- the instruction to read the listing, the design-
# conformance heading and the use-case coverage bullet, none conferring
# suppression, and two that confer it and name the spec, one through the
# directory and one through the listing alone. A line conferring suppression
# through the listing alone must name the spec as a WORD, because a substring
# match would accept "specific". It prints the enumerated count beside the
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

USAGE='usage: check-redline.sh specform    <spec>
       check-redline.sh suppression <file>'

for tool in grep awk tr cut mktemp; do
  command -v "$tool" >/dev/null 2>&1 || die 2 "${tool} is not on PATH, so this gate cannot run"
done

VERB=${1:-}
A1=${2:-}

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
# subject IS a named surface -- a slash command, a document's section, an
# emphasised spelling, a disposition token -- names it without asserting which
# check ran.
#
# ITS BOUND, stated because the other verb states its own and this one's is the
# wider: it classifies BACKTICKED tokens by shape plus two bare phrases. It
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
    '#'*)  return 1 ;;   # a section heading names a SURFACE, not a check
    '**'*) return 1 ;;   # an emphasised spelling is quoted, not run
    '<'*)  return 1 ;;   # a placeholder names no real command
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
  specform|suppression) ;;
  *) die 2 "$USAGE" ;;
esac

WORK=$(mktemp -d) || die 2 'mktemp -d failed, so this gate cannot run'
trap 'rm -rf "$WORK"' EXIT

readable() { # <path> <what it is>
  [ -n "$1" ] || die 2 "$USAGE"
  [ -f "$1" ] || die 2 "no such $2: $1"
  [ -r "$1" ] || die 2 "$2 is not readable: $1"
}

SUPPRESSION_MARKERS='do not raise
intentional
suppress'

FINDINGS=0
finding() { FINDINGS=$((FINDINGS + 1)); printf '  finding: %s\n' "$1"; }
verdict_word() { if [ "$FINDINGS" -eq 0 ]; then printf clean; else printf dirty; fi; }

# --- suppression ------------------------------------------------------------
# [do-suppression]
do_suppression() {
  local file=$1 line no rest body lower marker confers disp listing_only enumerated=0
  readable "$file" 'file'
  printf 'check-redline: verb=suppression file=%s pattern=done/|design\\.md|(?i)plan-archive|(?i)\\blisting\\b\n' "$file"
  awk '{ l = tolower($0) }
       /done\/|design\.md/ { print NR ":0:" $0; next }
       l ~ /plan-archive/ || l ~ /(^|[^a-z0-9_])listing([^a-z0-9_]|$)/ { print NR ":1:" $0 }' \
    "$file" > "${WORK}/enumerated"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    no=${line%%:*}
    rest=${line#*:}
    listing_only=${rest%%:*}
    body=${rest#*:}
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
      if [ "$listing_only" = 1 ] \
         && ! printf '%s\n' "$lower" | grep -qE '(^|[^a-z0-9_])spec([^a-z0-9_]|$)'; then
        finding "${file}:${no} confers suppression and names the archive listing without naming the spec"
      fi
    fi
    printf '  %s:%s %s\n' "$file" "$no" "$disp"
  done < "${WORK}/enumerated"
  printf 'check-redline: verb=suppression verdict=%s enumerated=%s findings=%s\n' \
    "$(verdict_word)" "$enumerated" "$FINDINGS"
  [ "$FINDINGS" -eq 0 ]
}

case $VERB in
  suppression) do_suppression "$A1" ;;
  specform)    do_specform "$A1" ;;
esac
