---
name: pr-merged
description: "After a PR merge: switch to the default branch, pull, delete the merged branch's local progress files, delete the local PR branch, and prune the stale remote-tracking ref it leaves behind."
when_to_use: "Activate once a PR is CONFIRMED merged — the user says 'merged', or `gh pr view` reports state MERGED — while still standing on that PR's branch. Not on 'approved', not on 'pushed', and never on an inference from `git log`: a squash-merge and a never-merged branch look alike there. Confirm the merge before the first command; on any doubt, ask instead."
allowed-tools: Bash(git checkout:*), Bash(git pull:*), Bash(git fetch:*), Bash(git ls-remote:*), Bash(git push:*), Bash(git branch:*), Bash(git status:*), Bash(gh pr view:*), Bash(rm -f ai-docs/plans/*), Bash(scripts/cleanup-progress.sh:*)
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
5. `git fetch --prune` — **after** step 4, never before. The local remote-tracking ref OUTLIVES the remote branch: where the repository deletes merged branches server-side (`delete_branch_on_merge`), `origin/<previous-branch>` still exists locally, and `git branch -vv` prints it exactly as it prints a live one. **A stale tracking ref is indistinguishable from a live remote branch**, so the authoritative question is `git ls-remote --heads origin`, never `git branch -r` — recorded because the alternative was committed live: the refs were read as surviving remote branches and a deletion was proposed for branches the server had removed minutes earlier.

   **The order is load-bearing, and NOT for the reason it looks like.** Measured on a branch pushed the way this workflow pushes (`-u`, so an upstream exists) and never merged anywhere: with the stale ref present `git branch -d` **succeeds at rc=0** — `warning: deleting branch 'X' that has been merged to 'refs/remotes/origin/X', but not yet merged to HEAD` — while after a prune it refuses at rc=1 `not fully merged`. So keeping the ref makes step 4 **more permissive**, not less. Delete-then-prune is still right, because pruning first would make step 4 refuse the ordinary squash-merge case and stall a step whose only instruction is to stop and report. **The consequence to carry:** in this order `git branch -d`'s merge check is weak, so it is not the safety net it looks like — the merge confirmation from the review surface, required above, is the gate that matters.

   **If the remote branch is still there** — a repository that does not delete merged branches server-side — the prune removes nothing and `git ls-remote --heads origin` still lists it. Deleting it is a separate, outward-facing act: `git push origin --delete <previous-branch>`. Ask before running it rather than folding it into the cleanup.

## Patterns

### 1. Auto-delete the merged local branch without confirmation

*Default to* running `git branch -d <previous-branch>` immediately at step 4 without pausing for confirmation. *Prefer* the silent auto-delete over an `AskUserQuestion` prompt — **not** because `-d` would refuse an unmerged branch, which step 5 shows it usually does not in this position, but because the merge was already confirmed from the review surface before step 1, which is the authorisation this step runs on. The user has also invoked this skill specifically to perform cleanup. If `-d` refuses, stop and report; do NOT escalate to `-D` without explicit user instruction.

> **A squash- or rebase-merged PR CAN leave `-d` refusing** — the branch's commits never appear verbatim on `main` — but only once the remote-tracking ref is gone. **In step 4's position, with the ref still present, `-d` normally deletes with a warning instead** (measured; see step 5), so this arm is rarer than it reads and its absence is not evidence the branch was merged cleanly. When the refusal does come, it is information rather than an obstacle: confirm the PR is actually merged (`gh pr view <N> --json state,mergedAt`) and let the **user** decide on `-D`.
