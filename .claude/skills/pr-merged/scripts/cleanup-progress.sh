#!/usr/bin/env bash
#
# Delete the local progress files belonging to the merged branch passed as $1.
#
# Run by the `/pr-merged` skill (.claude/skills/pr-merged/SKILL.md, step 3) after
# `git checkout main && git pull`, before `git branch -d <previous-branch>`.
#
# Derivation (ticket linkage):
#   1. Branch name convention: KEY-NNN-<slug>. Extract KEY-NNN.
#   2. Grep `^**Tracked in:** KEY-NNN` in ai-docs/plans/done/ + ai-docs/plans/
#      -> matching /task spec file.
#   3. `basename <spec> .spec.md` -> spec-base name.
#   4. Delete ai-docs/plans/<spec-base>.progress.md (if it exists).
#
# Failure modes (all exit 0 -- workflow step 4 proceeds regardless):
# - Branch name doesn't match KEY-NNN-<slug> (e.g. a manual branch name):
#   prints a one-line note to stdout and skips the spec-driven cleanup.
# - No spec carries `Tracked in: KEY-NNN`: prints a one-line warning to stderr
#   naming the ticket key and skips the /task-progress-file deletion.
# - rm -f is silent on missing files (intentional -- files may not exist;
#   idempotent re-runs are safe).
#
# Deferred-task progress files (ai-docs/plans/deferred/) are intentionally
# NOT touched -- deferral is its own workflow and a deferred task has no
# merged PR to drive cleanup. Bugfix traces are deleted by /bugfix Step 7.

set -uo pipefail

PREV_BRANCH="${1:-}"
if [ -z "${PREV_BRANCH}" ]; then
  printf 'cleanup-progress.sh: usage: cleanup-progress.sh <previous-branch>\n' >&2
  exit 2
fi

# Extract ticket key from branch name (convention: KEY-NNN-<slug>).
TICKET_KEY=$(printf '%s' "${PREV_BRANCH}" | grep -oE '^[A-Z][A-Z0-9]*-[0-9]+' | head -n1)

if [ -z "${TICKET_KEY}" ]; then
  printf 'pr-merged: branch %s does not start with KEY-NNN; skipping spec-driven progress-file cleanup.\n' "${PREV_BRANCH}"
  exit 0
fi

SPEC_PATH=$(grep -lE "^\*\*Tracked in:\*\* ${TICKET_KEY}\b" ai-docs/plans/done/*.spec.md ai-docs/plans/*.spec.md 2>/dev/null | head -n1)
if [ -n "${SPEC_PATH}" ]; then
  SPEC_BASE=$(basename "${SPEC_PATH}" .spec.md)
  rm -f "ai-docs/plans/${SPEC_BASE}.progress.md"
else
  printf 'pr-merged: no /task spec matches Tracked in: %s (derived from branch %s); skipping spec-driven progress-file cleanup.\n' "${TICKET_KEY}" "${PREV_BRANCH}" >&2
fi

exit 0
