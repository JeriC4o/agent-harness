#!/usr/bin/env bash
#
# Exit: 0 clean, 1 findings, 2 cannot run or skipped -- neither of which is a pass.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
METHOD_ROOT=$(cd -- "${HERE}/.." && pwd -P)
USAGE='usage: check-plan-links.sh <spec> <design>'

[ $# -eq 2 ] || { printf 'check-plan-links: %s\n' "$USAGE" >&2; exit 2; }
SPEC=$1
DESIGN=$2

for f in "$SPEC" "$DESIGN"; do
  [ -e "$f" ] || { printf 'check-plan-links: cannot run -- no such plan document: %s\n' "$f" >&2; exit 2; }
  [ -r "$f" ] || { printf 'check-plan-links: cannot run -- the plan document %s is unreadable\n' "$f" >&2; exit 2; }
done

command -v git >/dev/null 2>&1 \
  || { printf 'check-plan-links: cannot run -- git is needed, because whether the record is staged is read from the index\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { printf 'check-plan-links: cannot run -- python3 is the scanning tool\n' >&2; exit 2; }

# Caught here, before python3 starts, because an interpreter stopped by an
# uncaught error exits 1, which is this check's findings code.
PAYLOAD="${HERE}/check-plan-links.py"
HOLDING_PAYLOAD="${HERE}/check-plan-convergence-holding.py"
for p in "$PAYLOAD" "$HOLDING_PAYLOAD"; do
  [ -e "$p" ] || { printf 'check-plan-links: cannot run -- the payload %s does not exist\n' "$p" >&2; exit 2; }
  [ -r "$p" ] || { printf 'check-plan-links: cannot run -- the payload %s is unreadable\n' "$p" >&2; exit 2; }
done

# Two roots, because an installed copy sits in a plugin cache that is no
# repository: the kept-section list ships beside this file, while the record
# and its index belong to the work tree holding the spec.
SPEC_DIR=$(cd -- "$(dirname -- "$SPEC")" && pwd -P)
PROJECT_TOP=$(git -C "$SPEC_DIR" rev-parse --show-toplevel 2>/dev/null)
[ -n "$PROJECT_TOP" ] \
  || { printf 'check-plan-links: cannot run -- %s is not in a git work tree, and whether the record is staged is read from its index\n' "$SPEC_DIR" >&2; exit 2; }
PROJECT_ROOT=$(cd -- "$PROJECT_TOP" && pwd -P)

# `-B`: without it the first run writes scripts/__pycache__/ into the tree it
# reads, which nothing tracks and nothing ignores.
exec python3 -B "$PAYLOAD" "$METHOD_ROOT" "$PROJECT_ROOT" "$SPEC" "$DESIGN"
