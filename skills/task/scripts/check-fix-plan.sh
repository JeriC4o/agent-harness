#!/usr/bin/env bash
#
# Gate the review-fix round's plan section inside a task progress file.
#
# Run:  check-fix-plan.sh baseline|plan|applied <progress-file>
#       check-fix-plan.sh record <progress-file> <iterations> <cost_tool_calls> <answer>
# Exit: 0  PASS (plan) / OK (applied, record)
#       1  any other decision -- REFUSE, ROUTE-SPEC, ROUTE-DESIGN, ESCALATE, FINDING
#       2  cannot run, which is NOT a pass
#
# `record` writes the post-apply micro-loop's own verdict row and decides
# nothing. All THREE arguments are REQUIRED rather than defaulted: a default
# silently records a zero and the loop's retirement rule would then be read off a
# column of zeros -- a figure that is absent is recoverable, a figure that is
# wrong is not. The cost unit is PINNED to the number of orchestrator tool calls
# the loop consumed, not wall-clock, not tokens: it is the only unit the baseline
# this mechanism is measured against is expressed in. The field name carries the
# unit, because a bare `cost` is how a second unit gets invented.
#
# <answer> is the bounded question's answer: exactly one of MATCH or DIVERGE, a
# closed two-member set compared for EQUALITY and never by containment. That is
# why the pair is not MATCH/MISMATCH, which reads better: MATCH is a SUBSTRING of
# MISMATCH, so a containment comparison reports agreement on a diverging round.
# The word is RECORDED in the row as well as refused when unknown -- a check whose
# input is discarded leaves no evidence that it ran.
#
# READ THE `decision=` TOKEN, not the status alone. One rc covers five decisions
# whose next moves differ, and a status describing a property of its input must
# not be chained on (agents-method.md § Tooling). Non-zero means "not PASS",
# which is the safe direction for the three stop lanes.
#
# THE COUNTING BASIS, binding on the declared and the measured side alike: per
# file, max(added, removed), summed across files -- so a modified line counts
# ONCE. A new file contributes its line count, a deleted file the count it had
# at the baseline, a binary file 0 and is named. A rename counts as a delete
# plus an add, so an N-line rename counts 2N and a plan declaring 2N agrees.
# A path outside the measured tree -- one .gitignore excludes -- contributes 0
# on BOTH sides, because the declared and the actual totals are comparable only
# while both count the same way. That is a DIFFERENT exclusion from the in-round
# ignore list below: .gitignore keeps a path out of both trees, so the diff
# never sees it and no verdict field can report it, while the ignore list drops
# TRACKED paths the diff does see. A scout can inspect neither, so both are
# written down.
#
# `diff-tree` runs WITHOUT -M on purpose. With it a rename collapses to a single
# `from => to` path, which matches no planned Target, so arm (a) would report
# every rename as an unplanned file. Two plain paths cost a 2N over-count and
# err toward a human seeing the round.
#
# THE BASELINE IS A TEMP-INDEX TREE, because a round does not commit: on round 2
# the worktree still carries round 1's edits, and every file the task itself
# created is untracked for the whole task. `stash create` cannot see untracked
# files, `stash create -u` returns empty on a clean tracked tree, and `add -N`
# plus `stash create` fails at rc 128 with empty output. A tree written through
# GIT_INDEX_FILE covers tracked and untracked alike, honours .gitignore, and
# mutates neither the real index nor the worktree.
#
# AN EMPTY BASELINE THAT READS AS A VALID ONE IS THE FAILURE MODE HERE, so the
# guards are three deep: snap() tests the captured sha AFTER removing its temp
# index (a function's status is its last command's, so ending on `rm` reports
# nothing), `baseline` refuses to write a stub it has no sha for, and `applied`
# exits 2 on a round_base that is absent or does not resolve.

set -uo pipefail

THRESHOLD_CHANGED_LINES=150

# Three classes of path a round may legitimately touch outside its plan, each
# with the reason it is here -- an allowlist with no reason beside it is
# indistinguishable from a bug someone silenced, and the verdict prints how many
# paths it excluded so the list cannot widen invisibly.
#   ai-docs/learnings.md -- the archive, which /improve folds into mid-task
#   ai-docs/learnings/   -- the per-branch entry files the in-flow capture
#                           exception permits appending to during a round
#   ai-docs/plans/*.spec.md and ai-docs/plans/*.design.md -- the artefacts an
#       approved amendment rewrites mid-round. The step mandates RESUMING the
#       round afterwards and `baseline` refuses a second stub, so the round keeps
#       a round_base taken before the amendment while A2/A3 forbid any passing
#       plan from PROPOSING AN EDIT to those two SUFFIXES -- without this entry
#       arm (a) fires by construction on every amendment-then-resume round,
#       permanently. THE TWO SUFFIXES AND NOT THE DIRECTORY: A2/A3 key on the
#       suffixes, so a directory-wide prefix is strictly wider than its own
#       justification, and a tracked non-routing path under it (this repository
#       holds `ai-docs/plans/done/<x>.design-evidence.md`) is briefable by a
#       passing plan AND dropped from the measured total -- declared lines
#       against zero measured, the asymmetry these arms exist to close. It is a
#       narrowing and not an amnesty: a `fix` row naming either suffix routes and
#       a row proposing no edit briefs nothing, so every change to one is
#       unbriefed by construction and each is NAMED on the excluded-in-round line
#       for the orchestrator to account for against the amendment it knows it
#       ran. That discrimination is not derivable from a diff, which looks
#       identical whichever party made it. Inside `case` there is no pathname
#       expansion and `*` spans `/`, so both patterns cover ai-docs/plans/done/
#       as well -- the same note the A2/A3 arms carry.
IGNORE_EXACT='ai-docs/learnings.md'
IGNORE_PREFIX='ai-docs/learnings/'
IGNORE_GLOB_SPEC='ai-docs/plans/*.spec.md'
IGNORE_GLOB_DESIGN='ai-docs/plans/*.design.md'

SEP=$'\002'
PIPEHOLD=$'\001'

USAGE='usage: check-fix-plan.sh baseline|plan|applied <progress-file>
       check-fix-plan.sh record <progress-file> <iterations> <cost_tool_calls> <answer>
       <answer> is exactly one of MATCH or DIVERGE'

die() { printf 'check-fix-plan: %s\n' "$2" >&2; exit "$1"; }

# --- the verdict ledger -----------------------------------------------------
# A SIBLING of the loop ledger's directory, never a child of it: a single row
# planted in the loop dir itself was measured to move an existing report's
# project, session and verdict counts and to fabricate a session block carrying
# a false sentence about the file's age. Derived from HARNESS_LOOP_DIR rather
# than hardcoded, so a suite that redirects the loop dir into a sandbox gets the
# sibling inside that sandbox too -- a hardcoded $HOME path would have tests
# writing into the developer's real home. Its own override, so the two surfaces
# can be moved independently.
LOOP_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
VERDICT_DIR="${HARNESS_VERDICT_DIR:-$(dirname -- "$LOOP_DIR")/fix-plan}"
VERDICT_FILE="${VERDICT_DIR}/verdicts.jsonl"
# ONE file, not one per session: the only producer of a session id in this
# repository is a hook payload, and nothing exports one, so a script the
# orchestrator invokes has no id to key a filename with. Each row carries the
# branch and the round_base instead, so it is attributable without the filename.
# The appender's session_id argument keys only its once-per-session warning
# marker and is sanitised there, so a stable literal satisfies its contract --
# and keeps this writer's marker from colliding with the hooks' session-keyed
# ones, which would suppress a loop-detection warning that matters.
VERDICT_MARKER_KEY='check-fix-plan'

# THE `else` BRANCH IS LOAD-BEARING, and it is the half most likely to be
# dropped as boilerplate. Copying only the `if` makes a wrong path a silent
# no-op: the guard declines to source, `harness_ledger_append` is then
# undefined, the `|| true` below swallows the `command not found`, and no row is
# ever written. `hooks/lib/loop-index.sh:70-74` says so in as many words -- an
# absent helper must cost the WARNING and nothing else, so the fallback still
# appends. The resolution is $0-relative and not $ROOT-relative because $ROOT is
# the PROGRESS FILE's repository, which in a consuming project is the project
# rather than the plugin, where no hooks/lib exists at all.
HERE_LIB=$( { cd -- "$(dirname -- "$0")/../../../hooks/lib" && pwd; } 2>/dev/null ) || HERE_LIB=""
if [ -n "$HERE_LIB" ] && [ -r "${HERE_LIB}/ledger-write.sh" ]; then
  . "${HERE_LIB}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi

# One writer of this row's format, because a second copy of a format is a second
# thing to drift. The shape is adopted from hooks/lib/loop-verdict.sh:124 and
# :211 rather than invented, including its treatment of a jq that fails or is
# absent: the row comes back empty and the append is skipped.
#   verdict_row <verb> <round> <decision> <reason> <round_base> \
#               <threshold|''> <iterations|''> <cost|''> <question_answer|''>
verdict_row() {
  jq -nc --arg verb "$1" --arg round "$2" --arg dec "$3" --arg rsn "$4" \
         --arg base "$5" --arg thr "$6" --arg it "$7" --arg cost "$8" \
         --arg ans "$9" \
         --arg branch "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
    '{ts: (now|todate), kind: "verdict", surface: "fix-plan", verb: $verb,
      round: $round, decision: $dec, reason: $rsn,
      branch: $branch, round_base: $base}
     + (if $thr  == "" then {} else {threshold_changed_lines: ($thr  | tonumber)} end)
     + (if $it   == "" then {} else {iterations:             ($it   | tonumber)} end)
     + (if $cost == "" then {} else {cost_tool_calls:        ($cost | tonumber)} end)
     + (if $ans  == "" then {} else {question_answer:        $ans}               end)' 2>/dev/null
}

# `|| true` is correct HERE and is not result-masking: the rule's carve-out
# covers a chain inside a checked-in .sh, loop-verdict.sh:127 already spells it
# this way, and the criterion REQUIRES the semantics -- a failed write must
# leave the round's outcome unchanged. The appender never exits non-zero by
# contract, so no gate's status reaches this line to be masked.
# The appender does not create directories -- it appends and reports a failed
# open -- so without the mkdir the first write always fails on a fresh machine.
verdict_append() { # <row, possibly empty>
  [ -n "$1" ] || return 0
  mkdir -p "$VERDICT_DIR" 2>/dev/null
  harness_ledger_append "$VERDICT_MARKER_KEY" "$VERDICT_FILE" "$1" || true
  return 0
}

for tool in git awk grep sort tail cat rm dirname mktemp; do
  command -v "$tool" >/dev/null 2>&1 || die 2 "${tool} is not on PATH, so this gate cannot run"
done

VERB=${1:-}
PROGRESS=${2:-}
ARG_ITERATIONS=${3:-}
ARG_COST=${4:-}
# APPENDED at position 5, never inserted: the arguments above are positional, so
# an insert re-binds the shipped ones and an existing call would pass its
# iteration count as the answer while the error message named a different
# argument.
ARG_ANSWER=${5:-}

case $VERB in
  baseline|plan|applied|record) ;;
  *) die 2 "$USAGE" ;;
esac
[ -n "$PROGRESS" ] || die 2 "$USAGE"
[ -f "$PROGRESS" ] || die 2 "no such progress file: ${PROGRESS}"

ROOT=$(git -C "$(dirname -- "$PROGRESS")" rev-parse --show-toplevel 2>/dev/null)
[ -n "$ROOT" ] || die 2 "${PROGRESS} is not inside a repository, so a round cannot be measured"

WORK=$(mktemp -d) || die 2 'mktemp -d failed, so this gate cannot run'
trap 'rm -rf "$WORK"' EXIT

snap() {
  local idx sha
  idx="${WORK}/snap-index"
  rm -f "$idx"
  GIT_INDEX_FILE="$idx" git -C "$ROOT" read-tree HEAD 2>/dev/null || { rm -f "$idx"; return 2; }
  GIT_INDEX_FILE="$idx" git -C "$ROOT" add -A 2>/dev/null       || { rm -f "$idx"; return 2; }
  sha=$(GIT_INDEX_FILE="$idx" git -C "$ROOT" write-tree 2>/dev/null)
  rm -f "$idx"
  [ -n "$sha" ] || return 2
  printf '%s' "$sha"
}

review_round_count() {
  awk '/^## Self-Review \(Round [0-9]+\)[[:space:]]*$/ { c++ } END { print c+0 }' "$PROGRESS"
}

plan_round_numbers() {
  awk '/^## Fix Plan \(Round [0-9]+\)[[:space:]]*$/ {
         n = $0; sub(/^## Fix Plan \(Round /, "", n); sub(/\).*$/, "", n); print n
       }' "$PROGRESS"
}

section() { # <heading kind> <round>
  awk -v kind="$1" -v want="$2" '
    /^## / { inside = ($0 ~ "^## " kind " \\(Round " want "\\)[[:space:]]*$"); next }
    inside { print }
  ' "$PROGRESS"
}

header_field() { # <label> <section file>
  awk -v lab="**$1:**" '
    index($0, lab) == 1 {
      v = substr($0, length(lab) + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      print v; exit
    }' "$2"
}

# Two columns hold free text and one of them quotes instruction-file prose,
# which in this repository is routinely a table row full of `\|`. Holding the
# escaped pipe keeps a positional split from shifting every later field -- and,
# in the LAST column, from truncating the quoted sentence with nothing shifted
# to show it happened. The leading field is the raw column count, because a row
# whose cell count is wrong must be refused rather than misread.
table_rows() { # <section file>
  awk -v sep="$SEP" -v hold="$PIPEHOLD" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^[[:space:]]*\|/ {
      line = $0
      gsub(/\\\|/, hold, line)
      n = split(line, f, "|")
      for (i = 1; i <= n; i++) f[i] = trim(f[i])
      if (f[2] == "#" || f[2] ~ /^-+$/) next
      printf "%d", n
      for (i = 2; i < n; i++) printf "%s%s", sep, f[i]
      printf "\n"
    }' "$1"
}

open_findings() { # <section file>
  awk '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^[[:space:]]*\|/ {
      n = split($0, f, "|")
      if (n < 4) next
      num = trim(f[2]); status = trim(f[n-1])
      if (num == "#" || num ~ /^-+$/) next
      if (status ~ /Open/) print num
    }' "$1"
}

anchor_fault() { # <path or path:line> -> the fault, or nothing when it resolves
  local anchor=$1 path line total
  case $anchor in
    *:*) path=${anchor%:*}; line=${anchor##*:} ;;
    *)   path=$anchor; line='' ;;
  esac
  case $line in ''|*[!0-9]*) path=$anchor; line='' ;; esac
  if [ ! -f "${ROOT}/${path}" ]; then
    printf '%s does not resolve (no such file)' "$anchor"; return 0
  fi
  [ -n "$line" ] || return 0
  total=$(awk 'END { print NR+0 }' "${ROOT}/${path}")
  if [ "$line" -lt 1 ] || [ "$line" -gt "$total" ]; then
    printf '%s does not resolve (file has %s lines)' "$anchor" "$total"
  fi
}

arma_anchor() { # <cell> -> the first backticked path:line it quotes
  printf '%s' "$1" | awk '
    { while (match($0, /`[^`]+`/)) {
        token = substr($0, RSTART + 1, RLENGTH - 2)
        if (token ~ /^[^ ]+:[0-9]+$/) { print token; exit }
        $0 = substr($0, RSTART + RLENGTH)
      } }'
}

# File-exists plus line-in-range verifies the SHAPE of a citation and nothing
# about its content, so a fabricated-but-resolvable anchor passed -- and A1 was
# given precedence over amendment routing precisely on the premise that an
# unopened anchor is fatal, which a range check cannot establish. Each clause
# below answers a failure mode and none is decoration:
#   the WINDOW, because this repository hard-wraps prose and a quoted sentence
#     routinely spans three lines, so a single-line match would refuse the
#     plans that did open their anchors -- the one failure to avoid above all;
#   WHITESPACE NORMALISATION and nothing further, because every additional
#     normalisation is a paraphrase the check would start accepting;
#   ELISION in order, because quoting a long sentence in parts is normal and
#     order is what stops a bag of fragments matching unrelated text;
#   the FLOOR, because a three-word quote matches almost any window, which
#     would leave the check decorative.
# Refuse, not warn: a warning restores exactly the pass this closes. An empty
# fragment from a leading or trailing elision carries no claim to locate and is
# skipped, but a quote yielding no non-empty fragment at all is refused under
# the floor rather than passing vacuously.
#
# KNOWN RESIDUAL: a verbatim quote of a NEIGHBOURING sentence inside the window
# still passes, and 24 normalised characters is about four words, which recur
# across these files. A passing window proves the quoted text occurs within W
# lines of the cited line -- not that the cited sentence is the quoted one.
ARMA_QUOTE_WINDOW=3
ARMA_QUOTE_MIN=24

arma_quote_fault() { # <path:line> <restored cell> -> the fault, or nothing
  local anchor=$1 cell=$2 path line quoted lo hi
  path=${anchor%:*}; line=${anchor##*:}
  case $cell in
    *'"'*'"'*) quoted=${cell#*\"}; quoted=${quoted%\"*} ;;
    *) quoted='' ;;
  esac
  lo=$((line - ARMA_QUOTE_WINDOW)); [ "$lo" -ge 1 ] || lo=1
  hi=$((line + ARMA_QUOTE_WINDOW))
  awk -v lo="$lo" -v hi="$hi" -v q="$quoted" -v minlen="$ARMA_QUOTE_MIN" '
    function norm(s) { gsub(/[[:space:]]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
    NR >= lo && NR <= hi { win = win " " $0 }
    END {
      win = norm(win)
      n = split(q, frag, /…|\.\.\./)
      pos = 1; located = 0
      for (i = 1; i <= n; i++) {
        f = norm(frag[i])
        if (f == "") continue
        if (length(f) < minlen) {
          printf "quotes [%s], %d characters -- too short to locate a sentence (minimum %d)", f, length(f), minlen
          exit
        }
        located++
        at = index(substr(win, pos), f)
        if (at == 0) {
          if (index(win, f) > 0)
            printf "quoted fragments are out of order: [%s] appears before its predecessor in lines %d-%d", f, lo, hi
          else
            printf "quoted sentence is not at that line: [%s] is absent from lines %d-%d", f, lo, hi
          exit
        }
        pos = pos + at - 1 + length(f)
      }
      if (located == 0) printf "quotes no sentence -- too short to locate a sentence (minimum %d)", minlen
    }' "${ROOT}/${path}"
}

restore() { printf '%s' "${1//$PIPEHOLD/|}"; }

is_ignored() { # <path>
  [ "$1" = "$IGNORE_EXACT" ] && return 0
  # The two plans globs are UNQUOTED on purpose: a quoted expansion in a `case`
  # pattern is a LITERAL, so the quoted form would match no real path at all.
  case $1 in
    "${IGNORE_PREFIX}"*) return 0 ;;
    $IGNORE_GLOB_SPEC|$IGNORE_GLOB_DESIGN) return 0 ;;
  esac
  return 1
}

DECISION=''
REASON=none
ARMS="${WORK}/arms"
: > "$ARMS"

arm() { printf '  %-4s %-20s %-5s %s\n' "$1" "$2" "$3" "${4:-}" >> "$ARMS"; }

# Only the FIRST failing arm sets the decision, and the arms are evaluated in
# the order they are printed: that is what makes routing beat size, so a plan
# that both names a plans artefact and overruns routes rather than escalating to
# a user who could wave it through to the fix agent.
decide() { [ -n "$DECISION" ] && return 0; DECISION=$1; REASON=$2; }

# A LIMIT is printed only where it is ENFORCED; a MEASUREMENT is printed wherever
# it is taken. The threshold has exactly one firing site, the pre-apply gate, so
# it is `plan`'s own extra field rather than every verb's header: a limit printed
# where nothing fires on it is a second copy that can drift from its one
# definition, and reads as a comparison that is still happening.
emit() { # <verb> <round> <extra header fields>
  printf 'check-fix-plan: verb=%s round=%s decision=%s reason=%s%s\n' \
    "$1" "$2" "$DECISION" "$REASON" "${3:+ $3}"
  cat "$ARMS"
}

do_baseline() {
  local round sha
  round=$(review_round_count)
  [ "$round" -gt 0 ] || die 2 "${PROGRESS} carries no ## Self-Review (Round N) section, so there is no round to plan for"
  if plan_round_numbers | grep -qx "$round"; then
    die 2 "${PROGRESS} already carries a ## Fix Plan (Round ${round}) section"
  fi
  sha=$(snap) || die 2 'could not compute a baseline tree, which is not a pass'
  {
    printf '\n## Fix Plan (Round %s)\n\n' "$round"
    printf '**round_base:** %s\n' "$sha"
    printf '**verification:**\n'
    printf '**declared_changed_lines:**\n\n'
    printf '| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |\n'
    printf '|---|---|---|---|---|\n'
  } >> "$PROGRESS"
  printf 'check-fix-plan: verb=baseline round=%s decision=OK round_base=%s\n' \
    "$round" "$sha"
}

do_plan() {
  local round sec declared verification sum
  local ncells num disp target expected arma
  local faults='' routespec='' routedesign='' sizefault='' coverage='' unmatched=''
  local quotefaults='' anchor fault numbers missing

  round=$(plan_round_numbers | sort -n | tail -1)
  if [ -z "$round" ]; then
    DECISION=REFUSE; REASON=no-plan-section
    arm A1 anchor-resolution n/a
    arm A2 spec-amendment n/a
    arm A3 design-amendment n/a
    arm A4 size n/a
    arm A5 verification-named n/a
    arm A6 finding-coverage FAIL 'no ## Fix Plan (Round N) section to parse'
    emit plan '-' "threshold_changed_lines=${THRESHOLD_CHANGED_LINES} declared_changed_lines=- arma_quote_window=${ARMA_QUOTE_WINDOW}"
    return 1
  fi

  sec="${WORK}/plan-section"
  section 'Fix Plan' "$round" > "$sec"
  table_rows "$sec" > "${WORK}/rows"
  declared=$(header_field declared_changed_lines "$sec")
  verification=$(header_field verification "$sec")

  while IFS="$SEP" read -r ncells num disp target expected arma; do
    if [ "$ncells" != 7 ]; then
      DECISION=REFUSE; REASON=plan-row-malformed
      arm A1 anchor-resolution n/a
      arm A2 spec-amendment n/a
      arm A3 design-amendment n/a
      arm A4 size n/a
      arm A5 verification-named n/a
      arm A6 finding-coverage FAIL "finding ${num:-?}: the row holds $((ncells - 2)) cells, the format holds 5"
      emit plan "$round" "threshold_changed_lines=${THRESHOLD_CHANGED_LINES} declared_changed_lines=${declared:--} arma_quote_window=${ARMA_QUOTE_WINDOW}"
      return 1
    fi
  done < "${WORK}/rows"

  section 'Self-Review' "$round" > "${WORK}/review-section"
  open_findings "${WORK}/review-section" | grep . > "${WORK}/open-numbers"

  sum=0
  while IFS="$SEP" read -r ncells num disp target expected arma; do
    anchor=${target%% *}
    fault=$(anchor_fault "$anchor")
    [ -z "$fault" ] || faults="${faults}${faults:+; }finding ${num}: ${fault}"
    if [ "${arma}" != none ] && [ -n "${arma}" ]; then
      anchor=$(arma_anchor "$arma")
      if [ -z "$anchor" ]; then
        faults="${faults}${faults:+; }finding ${num}: the Arm A cell quotes no file:line anchor"
      else
        fault=$(anchor_fault "$anchor")
        if [ -n "$fault" ]; then
          faults="${faults}${faults:+; }finding ${num}: Arm A ${fault}"
        else
          # Only once the anchor resolves: a quote check against a line that is
          # not there has nothing to report that A1 has not already said.
          fault=$(arma_quote_fault "$anchor" "$(restore "$arma")")
          [ -z "$fault" ] || quotefaults="${quotefaults}${quotefaults:+; }finding ${num}: Arm A ${fault}"
        fi
      fi
    fi

    # THE PATH HALF IS KEYED ON A ROW THAT PROPOSES AN EDIT, and the guard wraps
    # THIS `case` only. What the path half catches is an attempt to have the fix
    # agent edit a spec or design artefact, so permission is what it must key on
    # -- and permission comes from the disposition, exactly as arm (a)'s allowed
    # set does. Unqualified it fired on a row proposing no edit, which made
    # `resolved:` unusable for its own documented primary case: a finding closed
    # before the round by an approved amendment names the artefact the finding
    # cited, so recording that truthfully re-routed the round, and `baseline`
    # refuses a second stub so it could not be cleared that way either.
    #
    # Wrapping the `case $disp in` block below as well would stop `amendment:`
    # rows routing -- the exact opposite of this change, and a shape that reads
    # correct at a glance because both blocks sit adjacent in the same loop body.
    # The two halves are independent: path-and-`fix` detects a misdirected fix
    # agent, the disposition detects a requested amendment. T1-ZK's third leg is
    # the control for that mistake.
    #
    # Inside `case`, `*` matches `/` -- there is no pathname expansion here -- so
    # `ai-docs/plans/*.design.md` already covers `ai-docs/plans/done/<x>.design.md`.
    if [ "$disp" = fix ]; then
      case $target in
        ai-docs/plans/*.spec.md|ai-docs/plans/*.spec.md:*)
          routespec="${routespec}${routespec:+, }finding ${num} targets ${target}" ;;
        ai-docs/plans/*.design.md|ai-docs/plans/*.design.md:*)
          routedesign="${routedesign}${routedesign:+, }finding ${num} targets ${target}" ;;
      esac
    fi
    case $disp in
      'amendment: spec')   routespec="${routespec}${routespec:+, }finding ${num} is dispositioned $(restore "$disp")" ;;
      'amendment: design') routedesign="${routedesign}${routedesign:+, }finding ${num} is dispositioned $(restore "$disp")" ;;
    esac

    case $expected in
      ''|*[!0-9]*) sizefault="${sizefault}${sizefault:+; }finding ${num}: expected changed lines [${expected}] is not an integer" ;;
      *) sum=$((sum + expected)) ;;
    esac

    case $disp in
      fix|'amendment: spec'|'amendment: design') ;;
      # `?*` on both reason-carrying tokens is what refuses an empty reason:
      # the reason IS part of the value, so a bare `object:` or `resolved:`
      # asserts nothing and falls through to the out-of-vocabulary branch.
      'object: '?*) ;;
      'resolved: '?*) ;;
      *) coverage="${coverage}${coverage:+; }finding ${num}: disposition [$(restore "$disp")] is outside the vocabulary fix / object: <reason> / resolved: <reason> / amendment: spec / amendment: design" ;;
    esac
    [ -n "$arma" ] || coverage="${coverage}${coverage:+; }finding ${num}: the Arm A cell is empty, and none must be written deliberately"

    # The converse direction, which no finding-side check can see: findings map
    # to rows, so those checks guard the finding side only, and a row matching
    # no open finding PRE-AUTHORISES a file -- arm (a) measures the applied diff
    # against the Target column, so a fabricated row is invisible from there by
    # construction. Tested as set MEMBERSHIP, not count equality: the counts
    # agree on a swap (one finding omitted, one row fabricated), so equality was
    # only ever correct as a conjunction with the other A6 checks -- and one of
    # those, the duplicate check, has since been deliberately removed, which is
    # exactly the regression a count would have been silent about. Membership is
    # also what lets a finding hold several rows: multiplicity does not affect it.
    if ! grep -qxF -- "$num" "${WORK}/open-numbers"; then
      unmatched="${unmatched}${unmatched:+; }plan row [${num}] matches no open finding in the round's table"
    fi
  done < "${WORK}/rows"

  if [ -n "$faults" ]; then arm A1 anchor-resolution FAIL "$faults"; decide REFUSE anchor-unresolved
  else arm A1 anchor-resolution pass; fi

  # Two fault classes under A1, each with its own token because the remedies
  # differ: anchor-unresolved means fix the line number, arma-quote-unverified
  # means re-read the file. The line is printed whether or not it wins.
  if [ -n "$quotefaults" ]; then
    arm A1 arma-quote-unverified FAIL "$quotefaults"
    decide REFUSE arma-quote-unverified
  fi

  if [ -n "$routespec" ]; then arm A2 spec-amendment FAIL "$routespec"; decide ROUTE-SPEC spec-amendment
  else arm A2 spec-amendment pass; fi

  if [ -n "$routedesign" ]; then arm A3 design-amendment FAIL "$routedesign"; decide ROUTE-DESIGN design-amendment
  else arm A3 design-amendment pass; fi

  case $declared in
    '') sizefault="${sizefault}${sizefault:+; }no declared_changed_lines, and an absent total cannot be checked against the rows" ;;
    *[!0-9]*) sizefault="${sizefault}${sizefault:+; }declared_changed_lines [${declared}] is not an integer" ;;
    *) [ "$declared" -eq "$sum" ] || sizefault="${sizefault}${sizefault:+; }declared_changed_lines ${declared} disagrees with the rows, which sum to ${sum}" ;;
  esac
  if [ -n "$sizefault" ]; then
    arm A4 size FAIL "$sizefault"
    decide REFUSE declared-sum-mismatch
  elif [ "$sum" -gt "$THRESHOLD_CHANGED_LINES" ]; then
    arm A4 size FAIL "declared ${sum} of ${THRESHOLD_CHANGED_LINES}"
    decide ESCALATE size-over-threshold
  else
    arm A4 size pass "declared ${sum} of ${THRESHOLD_CHANGED_LINES}"
  fi

  if [ -z "$verification" ]; then
    arm A5 verification-named FAIL 'no verification named, so the round expects nothing to be re-run'
    decide REFUSE verification-missing
  else
    arm A5 verification-named pass "$(restore "$verification")"
  fi

  numbers=$(awk -F"$SEP" '{ print $2 }' "${WORK}/rows")
  missing=''
  while IFS= read -r num; do
    case $(printf '%s\n' "$numbers" | grep -cx -- "$num") in
      0) missing="${missing}${missing:+; }open finding ${num} is absent from the plan" ;;
      *) ;;
    esac
  done < "${WORK}/open-numbers"
  coverage="${coverage}${missing:+${coverage:+; }}${missing}"

  # Two fault classes under one arm, each with its own reason token and each
  # printing its own line, because the remedies differ: a finding-coverage
  # fault means fix the row, an unmatched row means delete it. The
  # finding-coverage decide comes first so the swap case -- one finding
  # omitted, one row fabricated -- keeps reporting the under-coverage a scout
  # can act on rather than the padding it produced.
  if [ -n "$coverage" ]; then
    arm A6 finding-coverage FAIL "$coverage"
    decide REFUSE finding-coverage
  fi
  if [ -n "$unmatched" ]; then
    arm A6 plan-row-unmatched FAIL "$unmatched"
    decide REFUSE plan-row-unmatched
  fi
  if [ -z "$coverage" ] && [ -z "$unmatched" ]; then
    arm A6 finding-coverage pass "$(grep -c . < "${WORK}/open-numbers") open findings, $(grep -c . < "${WORK}/rows") dispositions"
  fi

  [ -n "$DECISION" ] || DECISION=PASS

  # The pre-apply escalation's own verdict row -- the one firing that carries a
  # threshold value at all. Written once the decision is FINAL rather than inside
  # A4's branch: `decide` is first-wins, so a round that both routes and overruns
  # is not an escalation, and a row claiming one there would be false.
  if [ "$DECISION" = ESCALATE ]; then
    verdict_append "$(verdict_row plan "$round" "$DECISION" "$REASON" \
      "$(header_field round_base "$sec")" "$THRESHOLD_CHANGED_LINES" '' '' '')"
  fi

  emit plan "$round" "threshold_changed_lines=${THRESHOLD_CHANGED_LINES} declared_changed_lines=${declared:--} arma_quote_window=${ARMA_QUOTE_WINDOW}"
  [ "$DECISION" = PASS ]
}

do_applied() {
  local round sec base now actual ignored binary unplanned binpaths ignpaths
  local added removed path contrib planned

  round=$(plan_round_numbers | sort -n | tail -1)
  [ -n "$round" ] || die 2 "${PROGRESS} carries no ## Fix Plan (Round N) section, so there is no round_base to measure against"

  sec="${WORK}/plan-section"
  section 'Fix Plan' "$round" > "$sec"
  base=$(header_field round_base "$sec")
  [ -n "$base" ] || die 2 "round ${round}'s plan section carries no round_base, and a baseline that measures nothing is not a pass"
  git -C "$ROOT" rev-parse --verify --quiet "${base}^{tree}" >/dev/null 2>&1 \
    || die 2 "round ${round}'s round_base [${base}] does not resolve to a tree in this repository"

  now=$(snap) || die 2 'could not compute the current tree, which is not a pass'
  git -C "$ROOT" diff-tree -r --numstat "$base" "$now" > "${WORK}/numstat" \
    || die 2 "could not diff ${base} against the current tree"

  # Permission comes from the disposition, not from the presence of a target: an
  # `object:`, `resolved:` or `amendment:` row names a file `fix-apply` is
  # forbidden to touch, so admitting its target would pre-authorise the one edit
  # this arm exists to report.
  planned=$(table_rows "$sec" | awk -F"$SEP" '$3 == "fix" { t = $4; sub(/:[0-9]+$/, "", t); print t }')

  actual=0; ignored=0; binary=0; unplanned=''; binpaths=''; ignpaths=''
  while IFS="	" read -r added removed path; do
    [ -n "$path" ] || continue
    if is_ignored "$path"; then
      ignored=$((ignored + 1)); ignpaths="${ignpaths}${ignpaths:+ }${path}"; continue
    fi
    if [ "$added" = '-' ] || [ "$removed" = '-' ]; then
      binary=$((binary + 1)); binpaths="${binpaths}${binpaths:+ }${path}"
      contrib=0
    else
      contrib=$added
      [ "$removed" -gt "$added" ] && contrib=$removed
    fi
    actual=$((actual + contrib))
    printf '%s\n' "$planned" | grep -qx -- "$path" \
      || unplanned="${unplanned}${unplanned:+ }${path}"
  done < "${WORK}/numstat"

  if [ -n "$unplanned" ]; then
    arm '(a)' unplanned-file FAIL "$unplanned"
    decide FINDING unplanned-file
  else
    arm '(a)' unplanned-file pass
  fi

  # ARM (b) IS DELETED. It compared this round's actual changed-line total
  # against the threshold and was retired on evidence: one round declared 54
  # lines and landed 743, producing a verdict nobody could act on. A plan
  # declaring twenty lines and landing seven hundred IS a diff that does not
  # match its plan, which the micro-loop's one bounded question asks directly and
  # more cheaply; and a plan that honestly declares seven hundred was already
  # stopped at declaration time by the pre-apply escalation. So there is no
  # post-apply arithmetic of any kind here, and `actual_changed_lines=` below is
  # a MEASUREMENT nothing fires on -- the figure the question is read against by
  # a human. It is NOT one of the figures the loop's retirement rule accumulates:
  # those are the iteration count, the cost and the question's answer, and this
  # verb writes no verdict row at all -- `record` writes it.

  [ "$ignored" -eq 0 ] || arm '' excluded-in-round "${ignored}" "$ignpaths"
  [ "$binary" -eq 0 ] || arm '' binary-no-line-count "${binary}" "$binpaths"

  [ -n "$DECISION" ] || DECISION=OK
  emit applied "$round" "actual_changed_lines=${actual} ignored=${ignored} binary=${binary}"
  [ "$DECISION" = OK ]
}

# The micro-loop's own verdict row. A FOURTH VERB rather than an append written
# by the orchestrator, because hand-rolling the JSON line in the orchestrator's
# own Bash call puts a second writer of this format outside the one place that
# owns it -- and a second copy of a format is a second thing to drift. All three
# values are the orchestrator's facts, which is why they arrive as arguments.
# `iterations` is derivable from the round's attempt lines and is still passed
# explicitly: a parser over prose would be a second definition of the count, and
# the party writing those lines already holds the number.
#
# It decides nothing, so it exits 0 once its arguments are usable. A write that
# fails changes nothing about the round -- that is AC24's whole requirement of a
# failed write -- while an argument it cannot work from is `die 2`, the same
# cannot-run lane the other verbs use.
do_record() {
  local round sec base
  case $ARG_ITERATIONS in
    '') die 2 'record needs <iterations>, and it is required rather than defaulted: a defaulted zero would be read as a measurement' ;;
    *[!0-9]*) die 2 "record needs <iterations> as a non-negative integer; got [${ARG_ITERATIONS}]" ;;
  esac
  case $ARG_COST in
    '') die 2 'record needs <cost_tool_calls>, the number of orchestrator tool calls the loop consumed, and it is required rather than defaulted' ;;
    *[!0-9]*) die 2 "record needs <cost_tool_calls> as a non-negative integer; got [${ARG_COST}]" ;;
  esac
  # THE PATTERNS CARRY NO `*` BY DESIGN. These are exact alternatives, so
  # MISMATCH, match and diverge all fall to the catch-all; a containment
  # comparison would read MISMATCH as agreement on a diverging round. This is the
  # bounded question's only point of mechanical control: without it the refusal of
  # an out-of-vocabulary answer is a judgement, which is a review pass by another
  # name. The word is recorded below as well as checked here.
  case $ARG_ANSWER in
    MATCH|DIVERGE) ;;
    '') die 2 'record needs <answer>, the bounded question answer, exactly one of MATCH or DIVERGE' ;;
    *) die 2 "record needs <answer> as exactly one of MATCH or DIVERGE; got [${ARG_ANSWER}]" ;;
  esac

  round=$(plan_round_numbers | sort -n | tail -1)
  [ -n "$round" ] || die 2 "${PROGRESS} carries no ## Fix Plan (Round N) section, so there is no round to record a loop against"
  sec="${WORK}/plan-section"
  section 'Fix Plan' "$round" > "$sec"
  base=$(header_field round_base "$sec")

  verdict_append "$(verdict_row record "$round" OK micro-loop "$base" '' "$ARG_ITERATIONS" "$ARG_COST" "$ARG_ANSWER")"
  printf 'check-fix-plan: verb=record round=%s decision=OK reason=micro-loop iterations=%s cost_tool_calls=%s question_answer=%s\n' \
    "$round" "$ARG_ITERATIONS" "$ARG_COST" "$ARG_ANSWER"
}

case $VERB in
  baseline) do_baseline ;;
  plan)     do_plan ;;
  applied)  do_applied ;;
  record)   do_record ;;
esac
