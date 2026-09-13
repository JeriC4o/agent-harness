#!/usr/bin/env bash
#
# The cross-project sweep. Emits one JSON object per line for every promotion
# candidate that is eligible to reach the shared harness.
#
# Usage:
#   collect-candidates.sh [--registry <file>]
#
# Reads ONLY <project>/ai-docs/learnings/.promote/*.md. It has no code path
# that opens ai-docs/learnings.md or ai-docs/learnings/*.md -- the boundary
# against exporting project data is the file selector, not a judgement call.
#
# A candidate is emitted only if:
#   - its project is registered with scope "shared" (never "local")
#   - the project path still exists
#   - it passes check-candidate.sh, re-run here even though the project side
#     already ran it; a candidate can be hand-written or edited after the fact,
#     so the gate runs on the READ as well as on the WRITE
#
# Skipped projects and refused candidates are reported on stderr and never
# silently dropped: a quiet sweep and an empty corpus look identical otherwise.
#
# Output (one per line):
#   {"project":"<name>","id":"<slug>","file":"<abs path>","body":"<text>"}
#
# Exit: 0 always when the registry is readable (an empty corpus is not an
# error), 2 usage error.
#
# Tests: scripts/test-promotion.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-candidate.sh"
REGISTRY="${HARNESS_REGISTRY:-${HOME}/.claude/harness/registry.json}"

die() { printf 'collect-candidates: %s\n' "$1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REGISTRY="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '3,28p' "$0"; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required"
[ -f "$REGISTRY" ] || die "no registry at $REGISTRY (run /harness:harness-init in a project first)"
[ -x "$CHECK" ] || [ -f "$CHECK" ] || die "gate not found: $CHECK"

emitted=0
while IFS=$'\t' read -r path name; do
  [ -n "$path" ] || continue
  if [ ! -d "$path" ]; then
    printf 'skip project %s: path no longer exists (%s) -- prune it from the registry\n' "$name" "$path" >&2
    continue
  fi
  dir="${path}/ai-docs/learnings/.promote"
  [ -d "$dir" ] || continue
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in README.md) continue ;; esac
    if ! bash "$CHECK" "$f" --project-dir "$path" --quiet 2>/dev/null; then
      printf 'skip candidate %s (%s): refused by the redaction gate\n' "$(basename "$f" .md)" "$name" >&2
      continue
    fi
    jq -Rn --arg project "$name" \
           --arg id "$(basename "$f" .md)" \
           --arg file "$f" \
           --rawfile body "$f" \
           '{project:$project, id:$id, file:$file, body:$body}' -c
    emitted=$((emitted+1))
  done
done <<EOF
$(jq -r '.projects[]? | select((.scope // "shared") == "shared") | "\(.path)\t\(.name)"' "$REGISTRY")
EOF

[ "$emitted" -eq 0 ] && printf 'no eligible candidates found\n' >&2
exit 0
