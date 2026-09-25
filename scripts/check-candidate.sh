#!/usr/bin/env bash
#
# The redaction gate. Decides whether one promotion candidate may leave its
# project and enter the shared harness.
#
# Usage:
#   check-candidate.sh <candidate.md> [--mode rule|report] [--project-dir <dir>] [--quiet]
#
# Exit: 0 clean, 1 refused (offending terms on stderr), 2 usage error.
#
# TWO MODES. `rule` (the default) gates an abstracted promotion candidate: a
# harness path is permitted by an unanchored name alternation, and the required
# structure is Rule/Why/Signal. `report` gates a defect report about the harness
# itself, whose whole point is to name a harness file. There the alternation is
# not used at all -- it is a NAME match, so it would export every project file
# whose first segment happens to be spelled like a harness directory, and most
# projects have a scripts/ or a docs/. Report mode resolves each path token
# against the running harness tree instead, and swaps in the report's own
# section list. Every other leg is shared between the modes, so the
# project-identifier vocabulary cannot drift apart.
#
# WHY A MECHANICAL GATE. "Do not export project data" cannot rest on an agent
# promising to redact: the promise is unfalsifiable and the failure is silent.
# This gate derives a deny vocabulary from the project itself and refuses any
# candidate that still carries one of its terms, so the boundary is a check
# rather than an intention.
#
# The deny vocabulary, derived fresh each run so it cannot drift:
#   - the project directory name, and the `name` under which it is registered
#   - its ticket-key prefix (registry) and any KEY-123 shaped token
#   - every `## Entity` heading in ai-docs/context.md
#   - any path-like token (two segments joined by /) and any URL host
#   - extra terms in ai-docs/learnings/.promote/deny-extra.txt, one per line
#
# Terms match on WORD boundaries, never as bare substrings -- see the -w note
# at the matching loop.
#
# Structure is checked too: a candidate must carry frontmatter plus Rule, Why
# and Signal sections -- in report mode, frontmatter carrying harness_version
# and hash, plus Symptom, Repro, Expected, Surface and Evidence sections, and
# Surface must name a path that exists under the harness root. A malformed
# candidate is refused rather than promoted half-read.
#
# Tests: scripts/test-promotion.sh

set -uo pipefail

die() { printf 'check-candidate: %s\n' "$1" >&2; exit 2; }

FILE=""; PROJECT_DIR=""; QUIET=0; MODE=rule; HARNESS_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)        MODE="${2:-}"; shift 2 ;;
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    --quiet)       QUIET=1; shift ;;
    -h|--help)     sed -n '3,44p' "$0"; exit 0 ;;
    -*)            die "unknown flag: $1" ;;
    *)             [ -z "$FILE" ] || die "unexpected argument: $1"; FILE="$1"; shift ;;
  esac
done

case "$MODE" in rule|report) ;; *) die "unknown mode: $MODE (want rule|report)" ;; esac

[ -n "$FILE" ] || die "usage: check-candidate.sh <candidate.md> [--mode rule|report] [--project-dir <dir>] [--quiet]"
[ -f "$FILE" ] || die "no such file: $FILE"

if [ -z "$PROJECT_DIR" ]; then
  if [ "$MODE" = report ]; then
    # ai-docs/feedback/<file> -> project root; one level shallower than a
    # promotion candidate's. A derivation that cannot be confirmed is a usage
    # error, never a silent pass: landing one level off makes every
    # project-identifier term resolve against the wrong tree, and the gate then
    # runs, says nothing, and exports what it was built to hold back.
    PROJECT_DIR=$(cd -- "$(dirname -- "$FILE")/../.." 2>/dev/null && pwd) || die "cannot derive project dir; pass --project-dir"
    FILE_ABS=$(cd -- "$(dirname -- "$FILE")" && pwd)/$(basename -- "$FILE")
    case "$FILE_ABS" in
      "$PROJECT_DIR"/ai-docs/feedback/*) ;;
      *) die "derived project dir $PROJECT_DIR does not hold $FILE at ai-docs/feedback/; pass --project-dir" ;;
    esac
    [ -d "$PROJECT_DIR/ai-docs" ] || die "derived project dir $PROJECT_DIR has no ai-docs directory; pass --project-dir"
  else
    # ai-docs/learnings/.promote/<file> -> project root
    PROJECT_DIR=$(cd -- "$(dirname -- "$FILE")/../../.." 2>/dev/null && pwd) || die "cannot derive project dir; pass --project-dir"
  fi
fi
[ -d "$PROJECT_DIR" ] || die "no such directory: $PROJECT_DIR"
PROJECT_DIR=$(cd -- "$PROJECT_DIR" && pwd)

if [ "$MODE" = report ]; then
  # $0 is the PRIMARY branch: CLAUDE_PLUGIN_ROOT is unset inside a Bash call, so
  # in a real consuming-project run nothing supplies it and the derivation is
  # what executes. The gate always lives at <root>/scripts/, so <script dir>/..
  # is the root of whichever copy is running. The env var wins when set,
  # because an explicit value should.
  HARNESS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname -- "$0")/..}"
  HARNESS_ROOT=$(cd -- "$HARNESS_ROOT" 2>/dev/null && pwd -P) || die "harness root does not resolve: ${CLAUDE_PLUGIN_ROOT:-$(dirname -- "$0")/..}"
  for marker in .claude-plugin/plugin.json docs/agents-method.md; do
    [ -e "$HARNESS_ROOT/$marker" ] || die "no $marker under $HARNESS_ROOT; not a harness install"
  done
  # Markers are necessary but not sufficient: the harness repository ships them
  # and is simultaneously a consuming project, and report mode cannot check a
  # project against itself. Both sides are physicalised because `cd && pwd` is
  # LOGICAL, so a project reached through a symlink into the root otherwise
  # compares as unrelated; the trailing `/` is what separates a descendant from
  # a shared-prefix sibling, for which a bare prefix test exits 2 and kills the
  # channel for a project that has nothing to do with the harness.
  PHYS_PROJECT=$(cd -- "$PROJECT_DIR" && pwd -P)
  case "$PHYS_PROJECT/" in "$HARNESS_ROOT"/*) die "harness root $HARNESS_ROOT equals or contains the project dir $PHYS_PROJECT" ;; esac
fi

BODY=$(cat "$FILE")
findings=""
add() { findings="${findings}  - ${1}: ${2}"$'\n'; }

# A slash token asserts a file when its final segment carries an extension or it
# joins three or more segments -- unless every segment is numeric, which is a
# date. Everything else is prose, and prose is where read/write, client/server
# and input/output live: a defect report describes behaviour, so blanket-
# refusing slash pairs would make the channel unusable. The >=2-separator clause
# cannot be relaxed to buy back three-term prose runs, because that clause is
# also the only thing separating myproject/scripts/deploy-prod.sh from prose.
is_path_claim() {
  claim=1
  printf '%s' "${1##*/}" | grep -qE '\.[A-Za-z0-9]{1,4}$' && claim=0
  case "$1" in */*/*) claim=0 ;; esac
  [ "$claim" -eq 0 ] || return 1
  printf '%s' "$1" | grep -qE '^[0-9]+(/[0-9]+)*/?$' && return 1
  return 0
}

# Prints one `<verdict>|<token>` line per slash token that asserts a file.
# Unlike the default mode's regex this one also captures a leading `/`: without
# it an absolute project path is never even extracted, and the existence check
# turns `..` into an escape hatch out of the harness tree that the name
# alternation never had.
path_claims() {
  printf '%s' "$1" \
    | grep -oE '(^|[[:space:]`])/?[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' \
    | sed -E 's/^[[:space:]`]+//; s/[.,;:)]+$//' \
    | while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        case "$tok" in
          /*)   printf 'absolute path|%s\n' "$tok"; continue ;;
          *..*) printf 'parent traversal|%s\n' "$tok"; continue ;;
        esac
        is_path_claim "$tok" || continue
        if [ -e "${HARNESS_ROOT}/${tok}" ]
          then printf 'permitted|%s\n' "$tok"
          else printf 'no such path under the harness root|%s\n' "$tok"
        fi
      done
}

# ---- structure ---------------------------------------------------------------
case "$BODY" in ---*) ;; *) add "structure" "missing frontmatter (must start with ---)" ;; esac
if [ "$MODE" = report ]; then
  for section in "**Symptom:**" "**Repro:**" "**Expected:**" "**Surface:**" "**Evidence:**"; do
    case "$BODY" in *"$section"*) ;; *) add "structure" "missing $section section" ;; esac
  done
  for fmkey in "harness_version:" "hash:"; do
    case "$BODY" in *"$fmkey"*) ;; *) add "structure" "missing $fmkey frontmatter key" ;; esac
  done
  # Evaluated over the Surface LINE, never over the whole body: a real report
  # carries a path in Evidence too, so a body-scoped test passes every report
  # regardless of what Surface says, and the one mitigation that makes Surface
  # definitionally a harness path is voided while the suite stays green.
  surface_ok=0
  while IFS= read -r claim; do
    case "$claim" in permitted\|*) surface_ok=1 ;; esac
  done <<EOF
$(path_claims "$(printf '%s' "$BODY" | grep '^\*\*Surface:\*\*')")
EOF
  [ "$surface_ok" -eq 1 ] || add "structure" "Surface names no path that exists under the harness root"
else
  for section in "**Rule:**" "**Why:**" "**Signal:**"; do
    case "$BODY" in *"$section"*) ;; *) add "structure" "missing $section section" ;; esac
  done
fi

# ---- derived vocabulary ------------------------------------------------------
REGISTRY="${HARNESS_REGISTRY:-${HOME}/.claude/harness/registry.json}"
terms=""
terms="${terms}$(basename "$PROJECT_DIR")"$'\n'
if [ -f "$REGISTRY" ] && command -v jq >/dev/null 2>&1; then
  reg=$(jq -r --arg p "$PROJECT_DIR" '.projects[]? | select(.path==$p) | "\(.name)\n\(.ticket_prefix)"' "$REGISTRY" 2>/dev/null)
  terms="${terms}${reg}"$'\n'
fi
CTX="${PROJECT_DIR}/ai-docs/context.md"
if [ -f "$CTX" ]; then
  # entity headings, minus the template placeholder and generic section names
  ents=$(grep -E '^## ' "$CTX" | sed -E 's/^## //' \
         | grep -vE '^(%|Overview|Services|Key modules|Tech stack|Language profile|Build|Code organization|Request-scoped|Registry|Promotion candidate|Method file|Profile file|Layout)' \
         | grep -E '^[A-Za-z][A-Za-z0-9]+$')
  terms="${terms}${ents}"$'\n'
fi
EXTRA="${PROJECT_DIR}/ai-docs/learnings/.promote/deny-extra.txt"
[ -f "$EXTRA" ] && terms="${terms}$(grep -vE '^\s*(#|$)' "$EXTRA")"$'\n'

while IFS= read -r t; do
  [ -n "$t" ] || continue
  [ "$t" = "null" ] && continue
  [ "$t" = "none" ] && continue
  [ "${#t}" -lt 3 ] && continue
  # -w, not a bare substring match: a 3-letter ticket prefix like ORD would
  # otherwise refuse every candidate containing "record", "order" or
  # "coordinate", which makes the gate unusable for the projects most likely to
  # have a short prefix. The KEY-123 form stays caught -- "-" is a word
  # boundary -- and the structural ticket-key check below catches it anyway.
  if printf '%s' "$BODY" | grep -qiwF -- "$t"; then
    add "project identifier" "$t"
  fi
done <<EOF
$(printf '%s' "$terms" | sort -u)
EOF

# ---- structural leaks (independent of vocabulary) ----------------------------
key=$(printf '%s' "$BODY" | grep -oE '\b[A-Z][A-Z0-9]{1,9}-[0-9]+\b' | head -1)
[ -n "$key" ] && add "ticket key" "$key"

if [ "$MODE" = report ]; then
  refused=""
  while IFS= read -r claim; do
    [ -n "$claim" ] || continue
    reason=${claim%%|*}; tok=${claim#*|}
    if [ "$reason" = permitted ]; then
      # Advisory only. A spelling that exists in both trees misroutes triage,
      # which is the channel's whole purpose, but refusing it would false-refuse
      # a report about ai-docs/learnings/.promote/ -- which exists in both and is
      # among the likeliest defects this channel will carry.
      [ -e "${PROJECT_DIR}/${tok}" ] && printf 'check-candidate: ambiguity warning: %s exists in BOTH the harness and this project\n' "$tok" >&2
    elif [ -z "$refused" ]; then
      refused="${tok} (${reason})"
    fi
  done <<EOF
$(path_claims "$BODY")
EOF
  [ -n "$refused" ] && add "file path" "$refused"
else
  path=$(printf '%s' "$BODY" | grep -oE '(^|[[:space:]`])[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' \
         | grep -vE 'ai-docs/|\.claude/|docs/|skills/|agents/|rules/|hooks/|templates/|and/or|input/output' \
         | head -1 | tr -d ' `')
  [ -n "$path" ] && add "file path" "$path"
fi

host=$(printf '%s' "$BODY" | grep -oE 'https?://[A-Za-z0-9.-]+' | head -1)
[ -n "$host" ] && add "url" "${host#*//}"

# ---- verdict ------------------------------------------------------------------
if [ -n "$findings" ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'REFUSED %s\n%s' "$FILE" "$findings" >&2
    # Rule mode's line stays byte-for-byte because default-mode behaviour is
    # unchanged by construction. Separately, skills/improve/SKILL.md instructs the
    # promoting agent, in its own words, to do what this line advises — so
    # rewording here desynchronises that description, though neither file quotes
    # the other. Report mode wants the opposite advice: rewriting a report to get
    # past the gate is the loop skills/report-defect/SKILL.md forbids.
    if [ "$MODE" = report ]
      then printf '  Do not rewrite the report to get past this. Abort, name the term above, and let the user decide.\n' >&2
      else printf '  Rewrite the lesson so it names the SHAPE of the failure, not the instance.\n' >&2
    fi
  fi
  exit 1
fi
exit 0
