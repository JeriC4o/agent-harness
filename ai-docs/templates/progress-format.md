# Progress-file format (canonical)

Used by `/task`, `/project-review`, `/bugfix`, and the `review-findings` / `self-review` agents.

Path: `ai-docs/plans/YYYY-MM-DD-name.progress.md` (for `/task` and `/project-review`); `ai-docs/bugfix/trace-*.md` (the `/bugfix` trace file, which IS the progress file).

All these paths are **gitignored**. Progress files live in the working tree across compaction events but never enter the commit.

## Template

```markdown
# Progress: <task name> — ACTIVE
_Updated: YYYY-MM-DD_

> Read THIS FIRST → orchestrator state for compaction recovery.

**Branch:** <output of `git branch --show-current` — the current feature branch>
**base_commit:** <`git rev-parse HEAD` at task start>
**Last build:** <PASS | FAIL | not run>

<!-- Compaction-recovery / re-entry fields (required for code-side orchestrators): -->
**current_step:** <Step / Phase the orchestrator was last at>
**last_passed_gate:** <gate command | ISO-8601 UTC timestamp | commit hash, or `(none yet)`>

<!-- Optional re-entry fields: -->
**parent_skill:** </task | /project-review>    <!-- omit unless nested -->
**entry_args:** <original $ARGUMENTS at skill entry>            <!-- required for /task; optional elsewhere -->

<!-- /task-specific fields: -->
**Issue:** <TICKET-KEY>   <!-- omit when the task has no ticket -->
**Spec:** ai-docs/plans/<YYYY-MM-DD-name>.spec.md
**Design:** ai-docs/plans/<YYYY-MM-DD-name>.design.md
**PR:** #<id>                                                  <!-- OMIT the line entirely until the PR exists (like parent_skill above) — never emit the literal `#<id>` placeholder: it is neither a match nor "absent", so the readers below take the Mismatch branch and refuse to append. -->
<!-- Write **PR:** the moment the branch's PR is opened (`gh pr create`, or the first push that opens it); keep it in sync if the PR is ever recreated. A post-push fix round resolves the PR id by matching `**Branch:**` against the current branch and reading THIS line first, falling back to `gh pr view --json number` only when it is missing; it doubles as the cross-check that a progress file found the other way round (PR → ticket → spec → progress) belongs to the PR in hand — a mismatch means the wrong file was matched, not that the field is stale. `/pr-merged` works from the branch name and does not read it. -->

## Next action

<one-paragraph description of the exact next step the orchestrator should take>

## Subtasks

- [x] 1. <Completed subtask>
- [ ] 2. <Pending subtask>
- ...

## Files touched

- `path/to/file` — <one-line description of the change>
- ...

## Decisions log

- Step 6: <decision made at design step>
- Step 8 subtask 1: <decision made during impl>
- ...

## Key discoveries (don't re-investigate)

<anything non-obvious learned while reading the code — facts that would force a re-read on a fresh spawn>

## Self-Review (Round 1)

**Verdict:** APPROVE | REJECT

| # | File:line | Severity | Finding | Status |
|---|---|---|---|---|
| 1 | <path>:<line> | major | <description> | ⬜ Open / ✅ Fixed / ⚠️ Objected: <reason> |
```

`<line>` is re-derived from `grep -n '<the actual token>' <file>`, never computed by adding a delta to a pre-edit number (AGENTS.md § Tooling). A line number recorded here goes stale as soon as the file is edited again — prefer recording the token alongside it, and when handing an anchor that post-dates an edit to a subagent, mark it "re-derive, do not trust".

## Required fields by surface

| Surface | Required | Optional |
|---|---|---|
| `/task` | Branch, base_commit, Last build, current_step, last_passed_gate, entry_args, Issue, Spec, Design, Next action, Subtasks, Files touched, Decisions log, **PR** (from Step 12 onward — absent before the PR exists) | parent_skill |
| `/project-review` | Branch, base_commit, Last build, current_step, last_passed_gate, Next action, Subtasks, AC Status table | parent_skill, entry_args |
| post-push fix round (CI fix / reviewer nit on an open PR) | All `/task` fields PLUS a per-round `## Fix cycle round M` section, and **PR** | — |
| `/bugfix` | current_step, last_passed_gate, parent_skill (when invoked from `/task`), entry_args, Actual behaviour, Expected behaviour, Confirmed by user, Decisions log | — |

## Lifecycle by field

### `Branch` / `base_commit`

Written once at file creation. Never edited. The base reference for `git diff` operations.

### `Last build`

Written at task start (`not run`), `PASS` after a successful `%BUILD_CMD%` / `%TEST_CMD%`, `FAIL` on a failed gate. Edited at every gate boundary.

### `current_step`

The fail-loud step gate. Every step boundary REWRITES this field. Subagents reading it on re-entry know exactly where the orchestrator was. Format: `Step N — <one-line summary>` or `Phase N — <one-line summary>` or `Round M Step N — <one-line summary>` for multi-round skills.

### `last_passed_gate`

Three-field format: `<gate command> | <ISO-8601 UTC timestamp> | <commit hash>`.

Example: `%TEST_CMD% common/http-client | 2026-05-25T11:55:00Z | a3f9c1d`.

Rewritten only when a gate passes. The hash lets a re-entering Subagent verify the gate ran against the current tree (or detect that work happened since).

### `entry_args`

Written ONCE at file creation, read-only thereafter. The original `$ARGUMENTS` value. On lost-arguments re-entry (post-compaction with empty `$ARGUMENTS`), this is the canonical entry reference.

### `parent_skill`

Written when the file is owned by a nested skill (`/bugfix` called from `/task` Step 8, `/context-reset` from any parent). The parent's compaction-recovery callout reads this to identify which orchestrator owns the file.

### `Issue` / `Spec` / `Design`

`/task`-specific. Written at Step 1; never edited. Spec / Design paths may flip from `ai-docs/plans/<name>.{spec,design}.md` to `ai-docs/plans/done/<name>.{spec,design}.md` at Step 12 — the field is updated then.

### `Decisions log`

Append-only. Each step boundary appends ≥0 lines (one line per non-trivial decision, prefixed with the step name).

### `Self-Review (Round N)` sections

Appended by the `self-review` Subagent. Count existing `## Self-Review` sections to determine N. Each round writes its full findings table — earlier round tables stay intact.

> **Anchor a new round at EOF, on unique text.** An empty findings-table header is identical in every round, so a patch keyed on it inserts Round N between an EARLIER round's header and its rows. Anchor on the file's final line(s), then verify the `## Self-Review (Round …)` headings run in ascending order before returning a verdict.

## Lifecycle by process

- **Created** at task start by the orchestrator's first action.
- **Extended** at every step boundary (rewrite `current_step`, possibly `last_passed_gate`; append to `Decisions log`).
- **Read** at every re-entry (compaction recovery, lost-arguments path).
- **Deleted** by `/pr-merged` after the PR merges (the `cleanup-progress.sh` script). The spec + design move to `ai-docs/plans/done/`; the progress file is removed.

## Exemptions from `current_step` / `last_passed_gate` / `Decisions log`

Skills that don't carry orchestrator state:

- `/interview` — uses a sibling `<spec_path>.state.md` instead.
- `/pr-merged` — terminal cleanup, no in-flight state.
- `/improve` — runs in one turn, no resume.
- `/ai-audit` — runs in one turn (Phase 1 + Phase 2), no resume.

These skills do not own a progress file; their compaction-recovery semantics are "re-invoke the skill from scratch".
