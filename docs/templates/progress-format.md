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

## Fix Plan (Round 1)

**round_base:** <tree sha, written by the gate's `baseline` verb — never hand-edited>
**verification:** <the command(s) this round expects to re-run>
**declared_changed_lines:** <integer — the sum of the column below>

| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |
|---|---|---|---|---|
| 1 | fix | <path>:<line> | 12 | none |
| 2 | object: <reason> | <path>:<line> | 0 | none |
| 3 | amendment: spec | <spec-path>:40 | 6 | `<spec-path>:40` — "<the quoted sentence, at least 24 characters>" |
```

`<line>` is re-derived from `grep -n '<the actual token>' <file>`, never computed by adding a delta to a pre-edit number (${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling). A line number recorded here goes stale as soon as the file is edited again — prefer recording the token alongside it, and when handing an anchor that post-dates an edit to a subagent, mark it "re-derive, do not trust".

## Required fields by surface

| Surface | Required | Optional |
|---|---|---|
| `/task` | Branch, base_commit, Last build, current_step, last_passed_gate, entry_args, Issue, Spec, Design, Next action, Subtasks, Files touched, Decisions log, **PR** (from Step 12 onward — absent before the PR exists), **Fix Plan (Round N)** (one per Step 11 round carrying an open finding) | parent_skill |
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

### `Fix Plan (Round N)` sections

One per review round carrying at least one `⬜ Open` finding. The heading, the three header fields and the table heading are appended by the gate script's `baseline` verb; the `fix-scout` agent fills the table and the two empty header fields; the gate then parses the section and decides whether it may be applied. `N` matches the `## Self-Review (Round N)` the findings come from, and the section with the highest `N` is the one the gate reads.

- **`#` is the finding's own number from that round's findings table**, copied and never renumbered. **A finding may occupy more than one row** — one per file its remedy touches, since the `Target` cell holds a single path — and the gate measures the applied diff against the union of a finding's rows. What the `#` still decides is the two refusing directions: a plan missing an open finding is refused, and so is a row whose number matches no open finding, the latter because it would otherwise pre-authorise a file the review never raised.
- **`Disposition` is a closed vocabulary of five:** `fix`, `object: <reason>`, `resolved: <reason>`, `amendment: spec`, `amendment: design`. Both reason-carrying tokens refuse an empty reason, because the reason is part of the value. `resolved:` asserts that the tree already satisfies the finding, that no edit is owed this round, and that this is not a dispute — the case `object:` would otherwise be stretched to cover. A round whose every row plans no edit is a legitimate plan whose declared total is 0, and it still fires the whole sequence.
- **The counting basis rides in the column heading** rather than in prose beside it, so it travels with every plan: per file, `max(added, removed)`, summed across files, and a modified line counts once. A new file contributes its line count; a deleted file the count it had at the baseline; a rename counts as a delete plus an add, so an N-line rename is declared as 2N; a binary file contributes 0 and is named in the verdict; and a path `.gitignore` excludes contributes 0, on the declared side and the measured side alike, because the two totals are comparable only while both count the same way. The gitignored case is why the plan itself — which lives in this gitignored file — never charges against the round it describes, and it is a different exclusion from the short in-round list of **tracked** paths the verdict counts out loud. That list holds the learnings archive, the per-branch learnings files and the two routing suffixes `ai-docs/plans/*.spec.md` and `ai-docs/plans/*.design.md` — the last because an amendment rewrites a spec or design artefact and then resumes the round against a baseline taken before it. **It is those two suffixes and NOT the whole directory**, because that is exactly what the routing arms key on: a tracked path under `ai-docs/plans/` that is neither suffix *can* be briefed by a passing plan, and excluding it would drop briefed lines from the measured total while they still counted on the declared side. Those paths are excluded from the applied diff only; a plan can never brief an **edit** to one of the two suffixes, since a `fix` row naming a spec or design artefact routes the round instead of passing — and a row proposing no edit may name one but briefs nothing, so every change there is unbriefed either way. Each excluded path is **named** on the verdict's `excluded-in-round` line, which the orchestrator reads and accounts for.
- **The Arm A cell is never blank** — either the literal `none`, written deliberately, or a quoted sentence carrying its own backticked `file:line`. The gate resolves that anchor **and** checks that the quoted sentence is at it, within a window of three lines either side on whitespace-normalised text, with `…` elision honoured while every retained fragment is at least 24 characters and in order. So the cell records a sentence copied from the file, not a plausible one: a resolvable anchor whose quote is nowhere near it is refused, which is what a file-exists-plus-line-in-range check could not do.
- **A literal `|` inside either free-text column is written `\|`.** A raw pipe shifts every later field; the parser normalises the escaped form and refuses a row whose cell count is wrong rather than misreading it.
- **`round_base` is never hand-edited or re-derived.** It is the baseline the post-apply arm measures the round against, written before the plan was gated so no later party can substitute one of its own choosing.
- **The post-apply micro-loop's attempt count lives in this section, as bullets after the table** — one per re-fix attempt, written by the orchestrator before it re-spawns the fix agent, capped at three:

  ```
  - attempt 2 — finding 5, row 1: the divergence named was <quoted reason>; re-fix dispatched
  ```

  Here rather than in the gate because the gate holds no state between invocations, while this file survives a compaction and a session restart — which is exactly when a cap is lost — and a count beside the plan it counts against is auditable by the same read that checks the plan. **The bullet must NOT begin with `|`:** the gate reads any line in this section whose first non-space character is a pipe as a plan row, and one with the wrong cell count refuses the whole plan. A leading `-` is invisible to that parser, a literal `|` in the quoted reason is then harmless, and the count is `grep -c '^- attempt '` over the section.

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
