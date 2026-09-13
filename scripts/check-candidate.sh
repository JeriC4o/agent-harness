#!/usr/bin/env bash
#
# The redaction gate. Decides whether one promotion candidate may leave its
# project and enter the shared harness.
#
# Usage:
#   check-candidate.sh <candidate.md> [--project-dir <dir>] [--quiet]
#
# Exit: 0 clean, 1 refused (offending terms on stderr), 2 usage error.
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
# and Signal sections. A malformed candidate is refused rather than promoted
# half-read.
#
# Tests: scripts/test-promotion.sh

set -uo pipefail

die() { printf 'check-candidate: %s\n' "$1" >&2; exit 2; }

FILE=""; PROJECT_DIR=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    --quiet)       QUIET=1; shift ;;
    -h|--help)     sed -n '3,30p' "$0"; exit 0 ;;
    -*)            die "unknown flag: $1" ;;
    *)             [ -z "$FILE" ] || die "unexpected argument: $1"; FILE="$1"; shift ;;
  esac
done

[ -n "$FILE" ] || die "usage: check-candidate.sh <candidate.md> [--project-dir <dir>] [--quiet]"
[ -f "$FILE" ] || die "no such file: $FILE"

if [ -z "$PROJECT_DIR" ]; then
  # ai-docs/learnings/.promote/<file> -> project root
  PROJECT_DIR=$(cd -- "$(dirname -- "$FILE")/../../.." 2>/dev/null && pwd) || die "cannot derive project dir; pass --project-dir"
fi
[ -d "$PROJECT_DIR" ] || die "no such directory: $PROJECT_DIR"
PROJECT_DIR=$(cd -- "$PROJECT_DIR" && pwd)

BODY=$(cat "$FILE")
findings=""
add() { findings="${findings}  - ${1}: ${2}"$'\n'; }

# ---- structure ---------------------------------------------------------------
case "$BODY" in ---*) ;; *) add "structure" "missing frontmatter (must start with ---)" ;; esac
for section in "**Rule:**" "**Why:**" "**Signal:**"; do
  case "$BODY" in *"$section"*) ;; *) add "structure" "missing $section section" ;; esac
done

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

path=$(printf '%s' "$BODY" | grep -oE '(^|[[:space:]`])[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' \
       | grep -vE 'ai-docs/|\.claude/|docs/|skills/|agents/|rules/|hooks/|templates/|and/or|input/output' \
       | head -1 | tr -d ' `')
[ -n "$path" ] && add "file path" "$path"

host=$(printf '%s' "$BODY" | grep -oE 'https?://[A-Za-z0-9.-]+' | head -1)
[ -n "$host" ] && add "url" "${host#*//}"

# ---- verdict ------------------------------------------------------------------
if [ -n "$findings" ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf 'REFUSED %s\n%s' "$FILE" "$findings" >&2
    printf '  Rewrite the lesson so it names the SHAPE of the failure, not the instance.\n' >&2
  fi
  exit 1
fi
exit 0
