---
name: pr-merged
description: "After a PR merge: switch to the default branch, pull, delete the merged branch's local progress files, and delete the local PR branch."
when_to_use: "Activate once a PR is CONFIRMED merged — the user says 'merged', or `gh pr view` reports state MERGED — while still standing on that PR's branch. Not on 'approved', not on 'pushed', and never on an inference from `git log`: a squash-merge and a never-merged branch look alike there. Confirm the merge before the first command; on any doubt, ask instead."
allowed-tools: Bash(git checkout:*), Bash(git pull:*), Bash(git branch:*), Bash(git status:*), Bash(gh pr view:*), Bash(rm -f ai-docs/plans/*), Bash(scripts/cleanup-progress.sh:*)
---

> Near-stateless: no `.progress.md` discipline applies; re-entry consists of re-invoking the skill.

Current branch: !`git branch --show-current`

Working tree:
```!
git status --porcelain
```

If the current branch is the default branch (`main`), stop and tell the user this skill must be run while standing on the merged PR branch.

> **This skill may be invoked by the model, so the merge is a PREMISE that must be measured, not assumed.** A user who types `/pr-merged` has seen the merge; an agent may only believe it, and step 3 deletes files before step 4's `git branch -d` can refuse anything. So before step 1, confirm the merge from the review surface — `gh pr view --json state,mergedAt` for the current branch's PR — and require `state == "MERGED"`. No PR, a non-merged state, or no tracker reachable from this session → **stop and ask the user**; do not fall back to inferring the merge from `git log`, which cannot distinguish a squash-merge from a branch that was never merged at all. A human invoking this skill is itself the confirmation and needs no query.

If `git status --porcelain` shows any modified, staged, or untracked entries, stop and ask the user how to proceed (commit, stash, discard, ignore). Do not run any further commands until the user answers.

Otherwise, run in order. **Capture `<previous-branch>` from the `Current branch:` value above before step 1** — once `git checkout main` runs, that value is no longer the current branch.

1. `git checkout main`
2. `git pull`
3. **Delete the merged branch's local progress files** (gitignored Subagent artefacts; no longer needed). Run the cleanup script:

   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/cleanup-progress.sh <previous-branch>
   ```

   The script encapsulates the ticket-linkage derivation (branch name → ticket key → spec lookup → progress-file paths) and handles the failure modes:

   - **Branch name doesn't match `KEY-NNN-<slug>`** (e.g. a manual branch): prints a one-line note and skips the spec-driven cleanup.
   - **No matching `/task` spec** (manual PR without `/task`): skips the `/task`-progress-file deletion.
   - **Bugfix traces** (`ai-docs/bugfix/trace-*.md`) are deleted by `/bugfix` Step 7, not here.

   Spec + design files move to `ai-docs/plans/done/` during `/task` Step 12, NOT here. Deferred-task progress files (`ai-docs/plans/deferred/`) are intentionally NOT touched.

   Source: [`${CLAUDE_PLUGIN_ROOT}/skills/pr-merged/scripts/cleanup-progress.sh`](scripts/cleanup-progress.sh).

4. `git branch -d <previous-branch>` — always `-d`, never `-D`. If `-d` refuses (branch not fully merged), stop and report the message; do not force-delete.

## Patterns

### 1. Auto-delete the merged local branch without confirmation

*Default to* running `git branch -d <previous-branch>` immediately at step 4 without pausing for confirmation. *Prefer* the silent auto-delete over an `AskUserQuestion` prompt — `git branch -d` refuses to delete unmerged branches, and the user has already invoked this skill specifically to perform cleanup. If `-d` refuses, stop and report; do NOT escalate to `-D` without explicit user instruction.

> **A squash- or rebase-merged PR leaves `-d` refusing**, because the branch's commits never appear verbatim on `main`. That refusal is information, not an obstacle: confirm the PR is actually merged (`gh pr view <N> --json state,mergedAt`) and let the **user** decide on `-D`.
