# Progress-file format (canonical)

Used by `/task`, `/project-review`, `/bugfix`, and the `review-findings` / `self-review` agents. It also
defines the row format of the **committed** redline log, which is not a progress file but is derived from
one of its sections — § The redline log (committed) below says why the two are documented together.

Path: `ai-docs/plans/YYYY-MM-DD-name.progress.md` (for `/task` and `/project-review`); `ai-docs/bugfix/trace-*.md` (the `/bugfix` trace file, which IS the progress file).

All these paths are **gitignored**. Progress files live in the working tree across compaction events but
never enter the commit. **The one exception is the redline log**, `ai-docs/plans/<spec-base>.redline.md`,
which sits beside the progress file and IS committed — it has to survive from the round that wrote it to a
fold that runs after a human review, which a gitignored file cannot do. That contrast is the mechanism's
load-bearing fact, which is why it is stated here rather than only where the format is defined.

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
**last_passed_gate:** <gate command | ISO-8601 UTC timestamp or `(not measured)` | commit hash, or `(none yet)` for the whole field>

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
| 4 | redline: modified — <what shipped instead> | <design-path>:120 | 0 | `<design-path>:120` — "<the quoted sentence, at least 24 characters>" |
```

`<line>` is re-derived from `grep -n '<the actual token>' <file>`, never computed by adding a delta to a pre-edit number (${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling). A line number recorded here goes stale as soon as the file is edited again — prefer recording the token alongside it, and when handing an anchor that post-dates an edit to a subagent, mark it "re-derive, do not trust".

## Required fields by surface

| Surface | Required | Optional |
|---|---|---|
| `/task` | Branch, base_commit, Last build, current_step, last_passed_gate, entry_args, Issue, Spec, Design, Next action, Subtasks, Files touched, Decisions log, **PR** (from Step 12 onward — absent before the PR exists), **Fix Plan (Round N)** (one per Step 11 round carrying an open finding), **Criterion checks (Round N)** (written as the tests are written) | parent_skill |
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

Three-field format: `<gate command> | <ISO-8601 UTC timestamp or `(not measured)`> | <commit hash>`.

Example: `%TEST_CMD% common/http-client | 2026-05-25T11:55:00Z | a3f9c1d`.

Rewritten only when a gate passes. The hash lets a re-entering Subagent verify the gate ran against the current tree (or detect that work happened since).

> **AXIOM — the timestamp is MEASURED, never composed, and a field that demands a stamp does not entitle you to produce one.**
> Measure first, read the output, THEN write — never batch the clock read into the same tool call as the write that consumes it, which guarantees the field is authored before the reading exists. Where no clock was read for the run, write `(not measured)` and say whose measurement the previous stamp was; **NEVER overwrite a measured stamp with an invented one.** Two recorded instances on one branch, the second inside a session handoff — the moment of lowest scrutiny and highest consequence, because every number in that document will be trusted by a session that cannot check it against a transcript it will not have. This field is the three-field format's whole justification: a fabricated command or hash is obvious on sight, while **a fabricated timestamp is indistinguishable from a real one**, so the field hardest to audit is the one that most needs measure-then-write.

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
- **`Disposition` is a closed vocabulary of six:** `fix`, `object: <reason>`, `resolved: <reason>`, `amendment: spec`, `amendment: design`, `redline: <type> — <what shipped instead>`. Every reason-carrying token refuses an empty reason, because the reason is part of the value. **`redline:`'s type is a closed three-value set** — `added`, `modified`, `removed`, relative to the frozen base — enforced by the pattern itself rather than by a parse, so a fourth type is refused like any other token outside the vocabulary. It is the disposition for a divergence between the design and what shipped that does **not** break the agreed approach: the code fix proceeds in the same round, and the row is promoted into the committed redline log by that round's single marking pass (§ The redline log (committed)). It declares **0**, because it briefs the fix agent with nothing to do — the marking pass makes its own writes. A `redline:` row may name a spec or design artefact as its `Target` without routing the round, because the routing arms key on a row that proposes a fix; and a `fix` row whose `Arm A` cell names a spec or design sentence with no `redline:` row accounting for it is refused, which is what makes the accounting unavoidable rather than advisable. `resolved:` asserts that the tree already satisfies the finding, that no edit is owed this round, and that this is not a dispute — the case `object:` would otherwise be stretched to cover. A round whose every row plans no edit is a legitimate plan whose declared total is 0, and it still fires the whole sequence.
- **The counting basis rides in the column heading** rather than in prose beside it, so it travels with every plan: per file, `max(added, removed)`, summed across files, and a modified line counts once. A new file contributes its line count; a deleted file the count it had at the baseline; a rename counts as a delete plus an add, so an N-line rename is declared as 2N; a binary file contributes 0 and is named in the verdict; and a path `.gitignore` excludes contributes 0, on the declared side and the measured side alike, because the two totals are comparable only while both count the same way. The gitignored case is why the plan itself — which lives in this gitignored file — never charges against the round it describes, and it is a different exclusion from the short in-round list of **tracked** paths the verdict counts out loud. That list holds the learnings archive, the per-branch learnings files and the two routing suffixes `ai-docs/plans/*.spec.md` and `ai-docs/plans/*.design.md` — the last because **two** legitimate parties write those artefacts mid-round: an approved amendment, which rewrites one and then resumes the round against a baseline taken before it, and the **marking pass**, which appends a redline pointer to the design beside each item the round found diverged. Those are different parties with different remedies, and a diff cannot tell them apart, which is why each excluded path is named rather than merely counted. **It is those two suffixes and NOT the whole directory**, because that is exactly what the routing arms key on: a tracked path under `ai-docs/plans/` that is neither suffix *can* be briefed by a passing plan, and excluding it would drop briefed lines from the measured total while they still counted on the declared side. Those paths are excluded from the applied diff only; a plan can never brief an **edit** to one of the two suffixes, since a `fix` row naming a spec or design artefact routes the round instead of passing — and a row proposing no edit may name one but briefs nothing, so every change there is unbriefed either way. Each excluded path is **named** on the verdict's `excluded-in-round` line, which the orchestrator reads and accounts for.
- **The Arm A cell is never blank** — either the literal `none`, written deliberately, or a quoted sentence carrying its own backticked `file:line`. The gate resolves that anchor **and** checks that the quoted sentence is at it, within a window of three lines either side on whitespace-normalised text, with `…` elision honoured while every retained fragment is at least 24 characters and in order. So the cell records a sentence copied from the file, not a plausible one: a resolvable anchor whose quote is nowhere near it is refused, which is what a file-exists-plus-line-in-range check could not do.
- **A literal `|` inside either free-text column is written `\|`.** A raw pipe shifts every later field; the parser normalises the escaped form and refuses a row whose cell count is wrong rather than misreading it.
- **`round_base` is never hand-edited or re-derived.** It is the baseline the post-apply arm measures the round against, written before the plan was gated so no later party can substitute one of its own choosing.
- **The post-apply micro-loop's attempt count lives in this section, as bullets after the table** — one per re-fix attempt, written by the orchestrator before it re-spawns the fix agent, capped at three:

  ```
  - attempt 2 — finding 5, row 1: the divergence named was <quoted reason>; re-fix dispatched
  ```

  Here rather than in the gate because the gate holds no state between invocations, while this file survives a compaction and a session restart — which is exactly when a cap is lost — and a count beside the plan it counts against is auditable by the same read that checks the plan. **The bullet must NOT begin with `|`:** the gate reads any line in this section whose first non-space character is a pipe as a plan row, and one with the wrong cell count refuses the whole plan. A leading `-` is invisible to that parser, a literal `|` in the quoted reason is then harmless, and the count is `grep -c '^- attempt '` over the section.

## Anchors and measurements in this file go stale while it is being written

This file's sections cite `file:line` anchors and record measurements, and the files they point at are the
ones the task is editing. Two rules, both learned by paying for them twice in one task.

**A pass that touches an EXISTING row re-derives every `file:line` and every measurement in it**, not only
the fields it came to change. A row is a claim about a tree that later rounds are free to edit, so a figure
correct when written describes a tree that no longer exists. On the task that introduced this rule, the
pass that WROTE it moved four lines and so falsified an open finding's freshly re-derived anchor set inside
the same pass — the duty is not a precaution, it is the normal case.

**Prefer a SECTION reference over a line number when citing a file this task is editing.** `§ Redline
marking (the Step-8 route)` cannot drift; `:144-145` drifts the next time anything above it grows. Reserve
a line number for a file the task does not touch, for a quoted sentence the reader must find exactly, and
for an anchor naming an EDIT TARGET in the base the task started from — that last class is a HEAD anchor
and must NOT be renumbered to working-tree lines, which is the easy way to "fix" a correct citation into a
wrong one.

**A grep that finds nothing has not proved absence.** These documents hard-wrap, so a phrase spanning a
wrap is invisible to a single-line search; a fragment, or `grep -c` on a distinctive token, is what
settles it.

## The redline log (committed)

`ai-docs/plans/<spec-base>.redline.md` — the one file in this family that is **committed**, and the reason
is lifecycle: the fold that consumes it runs after the PR is approved, which is well past the point a
gitignored file survives to.

It is documented here, beside the `Fix Plan (Round N)` section, because every one of its cells is
**derived** from a row of that table rather than recorded independently. Two records of one divergence is
the drift this mechanism exists to reduce, so the derivation is visible in a single read:

| Column | Holds | Derived from |
|---|---|---|
| `Key` | `R<round>.<finding #>` for a divergence a review round found, `S<step>.<ordinal>` for one implementation found | the round and number from the plan row; or, where no plan row exists, the step and the order of discovery |
| `Type` | `added` \| `modified` \| `removed`, relative to the frozen base | the `redline:` disposition's type token |
| `Artefact sentence diverged from` | the quoted sentence plus its backticked `file:line` | the plan row's `Arm A` cell, **verbatim** |
| `What shipped instead` | what the shipped artefact does instead | the disposition's reason text, **verbatim** |

```markdown
| Key | Type | Artefact sentence diverged from | What shipped instead |
|---|---|---|---|
| R2.4 | modified | `<design-path>:120` — "<the quoted sentence, at least 24 characters>" | <what shipped instead> |
| S8.1 | added | `<design-path>:348` — "<the quoted sentence, at least 24 characters>" | <what shipped instead> |
```

**The head above the table prescribes FIELDS, not layout** — the writer may arrange and expand them, and
usually should, because a log is read by a human looking for why a design says what it says. Four fields
are required, spelled as below so a reader can grep for them: `**Tracked in:**` (the same spelling the
spec header uses), `**Spec:**`, `**Design:**`, and `**Mode:**`.

```markdown
# Redline log: <task name>

**Tracked in:** <TICKET-KEY>
**Spec:** <spec-path>
**Design:** <design-path>
**Mode:** R&D | Hybrid — <the one line of evidence the recommendation rested on>
```

`Mode` is the one field with a consumer. It records the choice the first implementation-found divergence
put to the user, which governs every later divergence in the same task, and it lives HERE rather than in
this file's own sections for a lifecycle reason: a progress file is gitignored and deleted at merge, while
the log is committed and is what the closing fold reads. It is also what tells a later reader why the log
holds the number of rows it holds — a long log under `R&D` is the mechanism working, and the same log under
`Hybrid` is a scope question. Carry the evidence line with it, so the mode can be disagreed with on what it
rested on rather than as a preference.

- **A row records a SURVIVING divergence**, not a decision taken along the way and not a discarded
  experiment: an experiment that left no divergence leaves no row. That ties the log's volume to the
  result rather than to the process.
- **Every row is paired with a marker on the item it corrects**, appended in place and carrying only this
  row's key: `**[REDLINE R<round>.<finding #>]**`, or `**[REDLINE S<step>.<ordinal>]**` for a divergence
  implementation found. The marker says the item is settled; this row says what changed. The pairing is
  checked both ways — a row with no marker and a marker with no row are each a finding — so a reviewer can
  skip a marked item without reading the log at all. **Two checkers cover it between them, and which one
  covers which form is not interchangeable:** `check-fix-plan.sh`'s `A8` arm reads the keys off a round's
  fix-plan table and so reaches the `R` form only, while
  `${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh paired <design> <log>` compares the two sets directly and
  reaches both. A key is admitted by SHAPE, so a document that quotes the token to explain it is not a
  marked document.
- **One writer.** The round's single marking pass promotes the rows and appends the markers in the same
  invocation, so the two cannot diverge. The reviewer that originated the row writes only to the
  gitignored progress file, which is what keeps the other review surfaces that share its brief unchanged.
- **Lifecycle.** Created by the first marking pass of the task. Moved to `ai-docs/plans/done/` with the
  spec and the design when the task closes, so the fold, the merge-time refusal and any later reader have
  one location rather than two. Reset to empty when a breaking divergence forces a rebuild, because its
  rows described a base that no longer exists. **Removed by the fold** — which is what makes a surviving
  log an unambiguous signal that the fold never ran, and the merge-time workflow refuses on one. It is
  not matched by the ignore rules and not deleted by the merge-time progress-file cleanup; nothing else
  removes it.

## Criterion checks (Round N)

Where the CONCRETE check set lives, which the design no longer carries. The design states each
criterion's verification **intent** and names no test method, path or command, because those are chosen
while the tests are written — after the design is agreed — so a design that promised them would diverge
from the shipped tree by construction. This section is written as the tests are written.

| Column | Holds |
|---|---|
| `AC` | the criterion id |
| `Intent` | the design's intent line, copied |
| `Covering check` | the concrete command, test identifier or path, chosen while the tests were written |
| `Shown non-empty by` | the input that made that check fire, and the result |

```markdown
| AC | Intent | Covering check | Shown non-empty by |
|---|---|---|---|
| AC1 | <the design's intent line, copied> | <command / test identifier / path> | <the input that made it fire, and the result> |
```

- **`Shown non-empty by` blank is a REFUSAL, not a default.** This column is where the
  falsify-before-trusting duty now lives, and the predicate is never "a check exists that covers this
  intent": it is that the covering check **has been shown able to come back NON-EMPTY** — run once as
  written, and once against input engineered to make it fire. The gap between the two is this
  repository's best-documented defect class: three natural spellings of one syntax check all report
  success on a file that does not parse, one of them with no output at all. Each would satisfy "a check
  exists"; none is a gate.
- **It is enforced by prose rather than by a check**, deliberately and recorded so it does not read as an
  oversight: the round that writes it is the round that is reviewed, and a verb asserting the column is
  non-blank would be cheap to add later if the prose proves insufficient.
- **It is NOT called an "AC verification map".** That phrase already names a different thing in the
  reviewer's brief — a map nobody re-derives — and a second mechanism under one name is a collision.
- **Lifecycle: it dies with the branch, and nothing downstream needs it.** This file is gitignored and is
  deleted when the PR merges, so this section does not survive to a post-merge pass. That is why the
  post-merge re-run carries the weaker predicate — each intent is covered by some shipped check — with
  its reason recorded at that gate: the stronger evidence lives in a file no commit contains. The durable
  evidence is the committed tests themselves. This is deliberately not the failure where a figure died
  with a progress section and left a disposition naming a route that did not exist; there, something
  downstream still needed the number.

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
