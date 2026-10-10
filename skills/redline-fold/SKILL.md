---
name: redline-fold
description: "The closing pass of a task that accumulated redline corrections: once the PR is approved and before it merges, author the as-built design afresh, collapse the spec to its record of deliberate absence, remove the redline log, and surface one commit on the same PR."
when_to_use: "Activate once the user says the PR is APPROVED, while still standing on that PR's branch and before the merge. Not on 'pushed', not on 'merged' — a merged PR is past this pass's window and `/pr-merged` is the surface that refuses then. The approval cannot be measured in a repository whose review surface reports none, so the user's invocation IS the approval; an agent that merely believes a PR was approved has nothing to read."
argument-hint: "[spec base name, when the branch carries more than one plan]"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(git branch:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git show:*), Bash(git rm:*), Bash(git diff:*), Bash(gh pr view:*), Bash(ls:*), Bash(scripts/check-redline.sh:*)
---

> Near-stateless: no `.progress.md` discipline applies; re-entry consists of re-invoking the skill.

Current branch: !`git branch --show-current`

The closing half of the redline mechanism. During the task a divergence between the frozen design and
what shipped was recorded twice over — a pointer marker on the diverged item, a row in a committed log —
and nothing rewrote the design. **This pass is where the design becomes true again**, once, after the
human review has had its say, as a separate commit on the same PR.

> **This skill may be invoked by the model, so the approval is a PREMISE that cannot be measured here and
> must not be assumed.** A user who types the command has seen the approval; an agent may only believe
> it, and step 5 removes a committed file. So: a model-initiated invocation is **refused** — say that the
> redline fold runs on the user's word and stop. A human invoking it is itself the confirmation and needs no
> query. Where the review surface DOES report a decision (a repository with branch protection), read it
> and refuse on a changes-requested or review-required state; where it reports nothing, that silence is
> not an approval and not a refusal, and the user's invocation is what decides.

## Preconditions

Three are measurable and are checked before anything is written. The fourth is not, and the skill says so
rather than pinning a gate that could never pass.

| Precondition | How it is established |
|---|---|
| not standing on the default branch | `git branch --show-current` |
| a PR exists for this branch | `gh pr view` exits non-zero with "no pull requests found for branch …" when it does not |
| the PR is still open — the *before merge* half | `gh pr view --json state` |
| the PR is approved | **not measurable where the review surface reports no decision.** Measured on one repository: every PR it has ever had returns an empty review decision and an empty review list, so a gate pinned on that field could never pass. Carried by the user's invocation instead |

This is a one-shot read at invocation, **not polling.** Watching the review surface to decide *when* to
act is excluded by design: it can fire while a reviewer is still mid-comment and consume an incomplete
set of human corrections — the exact failure the one-pass-at-the-end shape exists to prevent.

## Steps

1. **Locate the plan trio.** `<spec-base>.spec.md`, `<spec-base>.design.md` and `<spec-base>.redline.md`,
   in `ai-docs/plans/` or in `ai-docs/plans/done/` — a branch that reached its task's close carries them
   beside the completed plans, one that did not carries them in the active directory. With more than one
   candidate and no argument given, ask rather than guess.

2. **The empty branch, and it is a real branch rather than a degenerate one.** No log, or a log carrying
   no rows: **stop here** and record which branch was taken. The frozen plan already describes what
   shipped, so there is nothing to author, and a rewrite that changes nothing still risks dropping a
   sentence nobody re-read. If a log with no rows is present, remove it (step 5) — a surviving log is the
   signal that this pass never ran, and leaving an empty one would raise that signal falsely.

3. **Spawn the `design` subagent to author the as-built design.** The orchestrator never writes a
   `*.design.md`; this pass is a spawn, not an edit.

   ```
   Agent(subagent_type="general-purpose", prompt="
     Read ${CLAUDE_PLUGIN_ROOT}/agents/design.md § The redline fold and follow it.
     Design: ai-docs/plans/<spec-base>.design.md
     Spec:   ai-docs/plans/<spec-base>.spec.md
     Log:    ai-docs/plans/<spec-base>.redline.md
     Author the as-built design afresh, section by section. Strip the spent
     process headings, every marker and any record of superseded material;
     re-author everything else against the shipped state. Verify each write on
     disk before the next one.
   ")
   ```

   **Afresh, and section by section, are different instructions and both bind.** "Afresh" constrains what
   the content is derived FROM — the shipped state, never the previous text, because an in-place edit
   leaves every sentence the editor did not touch and what it did not touch is what nobody re-read.
   "Section by section" constrains how the bytes are DELIVERED: a full-file rewrite of a document this
   size is the highest-risk moment for a transport drop, and the harness does not retry on a socket
   close. An implementer reading only the first reaches for one call.

4. **Spawn `spec-writer` to collapse the spec.** Its surviving payload is its record of *deliberate
   absence* — `## Out of scope`, `## Deferred`, `## Key decisions`, **byte-identical** to their pre-fold
   text. The design has no section that can carry this: a design describes what was built, never the
   boundary of what was deliberately not built.

   ```
   Agent(subagent_type="general-purpose", prompt="
     Read ${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md and follow it.
     Spec: ai-docs/plans/<spec-base>.spec.md
     Collapse it to ## Out of scope, ## Deferred and ## Key decisions, each
     byte-identical to its current text. Nothing else survives.
   ")
   ```

5. **Remove the log from the tree** — `git rm` it. Nothing downstream reads it: the post-merge reading
   list names the spec and the design and no third class, and the commit history preserves the record.
   That removal is what makes a surviving log mean *this pass never ran*.

6. **Assert positively that every section describes the shipped state.** This is a **judgement** and is
   named as one. It cannot be done by searching for superseded wording: a document that records its own
   corrections holds that wording inside a quotation, so an absence proved from a fragment is a false
   positive rather than a weak result. Read each section against what shipped.

7. **Then the gate, and the spot-check beside it.** Two calls, each its own:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh folded ai-docs/plans/<spec-base>.spec.md ai-docs/plans/<spec-base>.design.md
   ```

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh revision ai-docs/plans/<spec-base>.design.md
   ```

   `folded` compares the three retained spec sections byte-for-byte against the previous commit, asserts
   the design carries none of the residue patterns, and asserts the log is gone. The comparand is version
   control deliberately — it predates the rewrite and therefore cannot BE the rewrite, which a copy
   captured by this same pass could not promise. `revision` is the **spot-check** under step 6's
   judgement, never a substitute for it: it matches a bounded list of the phrases that introduce an
   account of a past revision, so it catches the named shapes and not every paraphrase.

   **Proceed on a clean 0 and on nothing else.** On findings, fix and re-run. On cannot-run — which is
   **not** a pass — say so and stop: there is no comparand, so nothing was checked.

8. **Surface the commit; do not commit unasked.** One commit on the same PR, carrying the re-authored
   design, the collapsed spec and the log's removal. Give the user the staged-file list and a suggested
   message. No review pass, no user reading and no approval gate is added on the folded document: its
   correctness is whether it matches the shipped code, and step 7 is more than a review spawn on a
   documentation-only commit would deliver.

## If nothing starts this pass

Nothing polls for it, so the omission is possible by construction. **The merge-time workflow refuses on
finding an unprocessed log** — binding, not optional. Its limit is recorded with it there and is worth
repeating: that refusal runs *after* this pass's window, so it catches the omission and can never repair
it. A caught error instead of silent damage is the whole claim being made for it.
