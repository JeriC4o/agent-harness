#!/usr/bin/env bash
#
# Delete the local progress files belonging to the merged branch passed as $1.
#
# Run by the `/pr-merged` skill (${CLAUDE_PLUGIN_ROOT}/skills/pr-merged/SKILL.md, step 3) after
# `git checkout main && git pull`, before `git branch -d <previous-branch>`.
#
# Derivation, in order:
#   1. The progress file's own `**Branch:** <branch>` line. Every
#      ai-docs/plans/*.progress.md whose Branch field is exactly the merged
#      branch is deleted. This route is first because it reads the file
#      being deleted rather than a document beside it: the closing fold
#      collapses the spec and drops its `**Tracked in:**` header, so after a
#      fold the spec no longer leads anywhere.
#   2. Ticket linkage, only when no progress file names the branch:
#      branch name KEY-NNN-<slug> -> KEY-NNN -> the spec carrying
#      `**Tracked in:** KEY-NNN` in ai-docs/plans/done/ or ai-docs/plans/ ->
#      ai-docs/plans/<spec-base>.progress.md.
#
# Failure modes (all exit 0 -- workflow step 4 proceeds regardless):
# - Route 1 matched: route 2 is not needed and does not run.
# - Branch name doesn't match KEY-NNN-<slug> (e.g. a manual branch name):
#   prints a one-line note to stdout and skips route 2.
# - No spec carries `Tracked in: KEY-NNN`: prints a one-line note to stderr
#   naming the ticket key and skips route 2.
# - rm -f is silent on missing files (intentional -- files may not exist;
#   idempotent re-runs are safe).
#
# Deferred-task progress files (ai-docs/plans/deferred/) are intentionally
# NOT touched -- deferral is its own workflow and a deferred task has no
# merged PR to drive cleanup. Bugfix traces are deleted by /bugfix Step 7.
#
# Tests: skills/pr-merged/scripts/test-cleanup-progress.sh

set -uo pipefail

PREV_BRANCH="${1:-}"
if [ -z "${PREV_BRANCH}" ]; then
  printf 'cleanup-progress.sh: usage: cleanup-progress.sh <previous-branch>\n' >&2
  exit 2
fi

# Route 1: the Branch field. A fixed-string whole-line match, so a branch
# whose name is a prefix of another's never deletes the other's file.
MATCHED=0
for f in ai-docs/plans/*.progress.md; do
  [ -f "$f" ] || continue
  if grep -qxF -- "**Branch:** ${PREV_BRANCH}" "$f"; then
    rm -f -- "$f"
    MATCHED=1
  fi
done
[ "$MATCHED" -eq 0 ] || exit 0

# Route 2: ticket linkage (convention: KEY-NNN-<slug>).
TICKET_KEY=$(printf '%s' "${PREV_BRANCH}" | grep -oE '^[A-Z][A-Z0-9]*-[0-9]+' | head -n1)

if [ -z "${TICKET_KEY}" ]; then
  printf 'pr-merged: no progress file names branch %s, and the branch does not start with KEY-NNN; skipping spec-driven progress-file cleanup.\n' "${PREV_BRANCH}"
  exit 0
fi

# Read here rather than through the archive listing (scripts/plan-archive.sh):
# the lookup needs one header line from active specs as well, and the listing
# reads the archive alone.
# [spec-by-key]
SPEC_PATH=$(grep -lE "^\*\*Tracked in:\*\* ${TICKET_KEY}\b" ai-docs/plans/done/*.spec.md ai-docs/plans/*.spec.md 2>/dev/null | head -n1)
if [ -n "${SPEC_PATH}" ]; then
  SPEC_BASE=$(basename "${SPEC_PATH}" .spec.md)
  rm -f "ai-docs/plans/${SPEC_BASE}.progress.md"
else
  printf 'pr-merged: no progress file names branch %s, and no /task spec matches Tracked in: %s; skipping spec-driven progress-file cleanup.\n' "${PREV_BRANCH}" "${TICKET_KEY}" >&2
fi

exit 0
