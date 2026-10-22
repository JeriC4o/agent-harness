# /task — Reference

Reference material extracted from `SKILL.md`. SKILL body owns the workflow steps; this file owns reference / troubleshooting / detail material. Loaded on demand.

## ⚡ First — validation sequence (detail)

The ⚡ First preamble's glob `ls ai-docs/plans/*.progress.md` is a flat match — it ignores branch and merge state. Two failure modes:

1. **Stale-merge.** Matched progress file's task already merged through the GitHub UI, bypassing `/pr-merged` (the gitignored `.progress.md` survived). RESUME-ing would point at a completed task.
2. **Wrong-branch parallel PR.** Matched progress file belongs to an unrelated in-flight PR on a different feature branch. RESUME-ing cross-contaminates flows.

**Validation sequence (run before the RESUME jump):**

1. Read `**Branch:**` and `**base_commit:**` from the matched `.progress.md`.
2. **Stale-merge check.** `git merge-base --is-ancestor <base_commit> origin/main` — exit 0 means that base is already an ancestor of the default branch (the work merged). Stale candidate.
3. **Branch-match check.** Compare the progress file's `**Branch:**` against `git branch --show-current`. If they differ, the user is on a different branch from the progress file's owner. Wrong-branch candidate.
4. If **either** check signals a mismatch, surface to user with three options and wait — do NOT jump to RESUME:
   - **delete** — `rm ai-docs/plans/<base>.progress.md`, then proceed with the new task.
   - **park** — `mv ai-docs/plans/<base>.progress.md ai-docs/plans/<base>.progress.md.parked`; the `.parked` suffix takes it out of the glob.
   - **RESUME anyway** — user explicitly chooses to ignore the mismatch (rare).
5. If both checks pass (base_commit NOT yet merged AND branch matches), proceed to RESUME flow.

**RESUME flow (skip Steps 1–7) — only after validation passes:**

1. Read the `.progress.md` file.
2. Read spec — only `## Acceptance Criteria`.
3. Read only the files `git diff --name-only <base_commit>` names — version control holds that set, and no hand-maintained copy of it exists in this file.
4. Jump to `## Next action`.
5. Tell user: "Found active task [X], resuming from [subtask Y]".

## ⚡ Second — bare-ticket activation sequence (full)

Activation sequence (bare-ticket → matching deferred spec):

1. Parse `$ARGUMENTS` — confirm it matches a ticket key (`^[A-Z][A-Z0-9]+-\d+$`).
2. Load the ticket if the project has a tracker reachable from this session (`gh issue view <N> --json title,body,state` for a GitHub issue). If none is reachable, the key is a reference only — carry it and continue.
3. Grep deferred specs:
   ```bash
   grep -l "^\*\*Tracked in:\*\* <KEY>\b" ai-docs/plans/deferred/*.spec.md
   ```
   Zero matches → fall through to Steps 1–5 (interview-driven flow). The ticket description loaded in step 2 is interview context.
   One match → continue with step 4.
   Multiple matches → surface to user.
4. Move the matched spec (and `*.design.md` / `*.progress.md` siblings if present) from `ai-docs/plans/deferred/` to `ai-docs/plans/`:
   ```bash
   git mv ai-docs/plans/deferred/YYYY-MM-DD-name.spec.md ai-docs/plans/
   git mv ai-docs/plans/deferred/YYYY-MM-DD-name.design.md ai-docs/plans/    # if exists
   mv ai-docs/plans/deferred/YYYY-MM-DD-name.progress.md ai-docs/plans/      # if exists; gitignored so plain mv
   ```
5. Surface spec's existing `## Acceptance Criteria` to user verbatim, ask: *"Confirm these ACs, or revise before continuing?"* — wait. Any revisions applied to the spec file before Step 6 launches.
6. **Do NOT run the interview.** **Do NOT create an `*.state.md` interview state file.** **Do NOT re-resolve the tracking ticket** — the spec's `**Tracked in:** <KEY>` is authoritative.
7. If a `.progress.md` came along (rare): jump to RESUME path's `## Next action`.
8. Otherwise jump directly to **Step 6**.

## Design Amendment recipe (re-entrant — triggered from Step 8 or Step 11)

**From Step 11 it fires on a divergence that BREAKS the agreed approach; from Step 8 only when the user asks for the rebuild** — nothing restarts on its own account there.

1. **Stop** the current step. Do not silently continue with the deviated approach.
2. **Surface to user** — say what the system will now do differently and why, in the product's own terms, answerable without opening a file: **no** design-document or spec citation, **no** acceptance-criterion or decomposition-task id; restate the constraint inline ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)). Wait for approval.
3. **Spawn the `design` subagent to apply the amendment** — do NOT edit `*.design.md` inline. Per AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`":
   ```
   Agent(subagent_type="general-purpose", prompt="
     Read ${CLAUDE_PLUGIN_ROOT}/agents/design.md and follow it.
     Existing design: ai-docs/plans/YYYY-MM-DD-name.design.md
     Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
     Context: amendment requested during implementation / self-review. Specifically: <describe the change>.
     Update the design doc to incorporate the amendment.
   ")
   ```
4. Re-run design review (max 3 rounds total across all design-review runs):
   ```
   Agent(subagent_type="general-purpose", prompt="
     Read ${CLAUDE_PLUGIN_ROOT}/agents/design-review.md and follow it.
     Design: ai-docs/plans/YYYY-MM-DD-name.design.md
     Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
     Context: design was amended during implementation / self-review — describe what changed.
   ")
   ```
5. **On GO** → resume from the step that triggered the amendment. **A branch carrying redline rows hands the rebuild every accumulated marker and row in step 3's prompt.** After the GO the log is empty and the rebuilt document is the new frozen base.
6. **On ITERATE** → re-spawn the `design` subagent with the iteration feedback and re-run review (counts against the 3-round limit). Never edit the design doc inline to "fix the blockers".
7. **On STOP** → surface to user; do not proceed.

> Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — recording a redline marker and its log row — FORBIDDEN.
> Editing `*.design.md` inline instead of spawning the `design` subagent — FORBIDDEN. The orchestrator's role is (1) surface to user, (2) spawn `design`, (3) spawn `design-review`. The `Write` to `*.design.md` belongs to the `design` subagent regardless of how trivial the amendment looks.

## Spec Amendment recipe (re-entrant — triggered from a Step 7 verdict)

Entered from any Step 7 verdict carrying a genuine-conflict row, or from a Step 11 finding that fires Arm A. A GO carries no spec-amending note: a genuine conflict is `major`, so at Step 7 it arrives on an ITERATE.

1. **Classify each note and row** at Step 7 close by [the tenth base principle](${CLAUDE_PLUGIN_ROOT}/docs/plan-invariants.md#the-base-principles): **breadth** — the spec general or silent where the design is specific — is neither kind and is dropped; **design-internal** (route through `design` subagent for in-place fold-in; no loop) includes a departure another spec sentence requires, which the design states among its risks; **spec-amending** is a genuine conflict only.
2. **Stop before Step 8.** Do not begin implementation against the pre-amendment spec — FORBIDDEN.
3. **Surface to user via `AskUserQuestion`** — state the requirement change itself in plain product terms (what is expected of the system now, versus before), not as a spec edit: **no** spec or design citation, **no** acceptance-criterion id ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)). Wait for explicit approval — **for a Step 7 genuine-conflict row the question is instead which remedy the user wants**, in the same plain terms, the design complying first: the design complying returns to Step 6 as an ordinary ITERATE does and leaves this recipe; the requirement changing continues to step 4.
4. **On user approval — re-invoke the `spec-writer` subagent to apply the amendment** — do NOT `Edit` `*.spec.md` inline. Per AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`":
   - **Pass the amendment in the spawn prompt, as a `prior_qa` entry or as `extra_context`. There is no interview state file to update** — it is the orchestrator's bookkeeping for the multi-round interview loop, it is deleted at that skill's terminal exit, and on the deferred-spec activation route (⚡ Second step 6) creating one is forbidden outright. A late amendment is a single invocation with no loop, and `spec-writer` never reads that file anyway: it reads `AGENTS.md`, the ticket body and the current draft from paths in its prompt, and takes the history as a prompt field — its own contract names `prior_qa` **or** `extra_context` as the channel for exactly this kind of re-invocation.
   - Spawn `spec-writer` with that prompt. The spec-writer owns the `Write` to `*.spec.md`.
5. **Ask the one question that decides the rest: does the amendment change the AGREED APPROACH?**
   - **Yes** — scope, intent or the approach itself moved. Re-enter Step 6 (`design`) stating that the spec was amended, then Step 7 against the new pair (counts against the 3-round cap); on GO proceed. The rebuilt design is the **new frozen base** and the redline log **resets**.
   - **No** — a criterion restated, an over-promise withdrawn, a wording clarified. **No design re-derivation, no design-review round, and no log row either**: a changed requirement is not a divergence, so nothing of it is recorded in the log and the log does **not** reset. The closing fold authors the design from the amended spec.

   **On an ITERATE entry the verdict's own loop resumes, whatever step 5 answers.** Once the spec is amended, re-enter Step 6 against it — the `design` subagent revises the design for the verdict's other rows and for the amended requirement — then Step 7, counting against the 3-round cap; the "No" branch leaves no GO, and Step 8 needs one. Before the GO freeze there is neither a frozen base to re-derive nor a log to reset, so step 5's answer is moot here, and the Step 6 → Step 7 return is the ITERATE loop itself, which the question never governed.

> Editing `*.spec.md` inline instead of re-invoking `spec-writer` — FORBIDDEN. The orchestrator's role is (1) carry the amendment into the spawn prompt, (2) re-spawn `spec-writer`, (3) answer step 5's question and take only the branch it names, then, on an ITERATE entry, resume the verdict's loop.
**Review DEPTH for an amendment — a preference, not a route.** The route is decided upstream by whether
the divergence breaks the agreed approach; this governs only how hard the resulting review looks.
**Default to** keeping the full review loop for an amendment that changes a VERIFICATION GATE rather than
prose — the gate is what every later claim of correctness rests on, so a silently-broken check is worse
than no check. Request that reviewer behaviour explicitly in the spawn prompt: extract the check block
verbatim from the file, run it against self-built conforming AND violating fixtures, and try to falsify
each "this is structural / guaranteed" sentence rather than reading it.

> **Answering step 5 by reflex, in either direction, is the failure** — why, and the measurement behind it: [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § When a spec amendment re-derives the design](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#when-a-spec-amendment-re-derives-the-design).

## Steps 1–5 — spec creation delegation (detail)

`/task` does not duplicate the interview workflow. Scope extraction, key-decision confirmation, tracking-ticket resolution and spec writing are owned by `/interview`.

**Already have a spec?** If a saved spec exists under `ai-docs/plans/`, confirm with the user and **skip to Step 6**.

**Otherwise, run the interview**:

```
Skill(skill="interview", args="$ARGUMENTS")
```

The interview handles entry-mode detection, scope confirmation, clarifying-question rounds (max 4, max 3 questions per round), ticket resolution, and spec writing.

**Spec-only run.** If the user wants to stop after the interview, `git mv` the spec to `ai-docs/plans/deferred/`, and **do not proceed to Step 6**.

**Before Step 6:** confirm spec exists at `ai-docs/plans/YYYY-MM-DD-name.spec.md` and user has approved its `## Acceptance Criteria`.

## Step 7 — the two convergence halves (detail)

The step produces BOTH results before the review spawn, and the review reads both. The ordering is
the obligation: a judgement class may never be the only check standing, and nothing in either
contract asks for that — it is satisfied by the deterministic check running in the same step.

**The deterministic half** is `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-convergence.sh <spec> <design>`,
its own bare call. Six classes, three of which HOLD a plan — completeness, isolation, arithmetic —
and three of which only report. Read the per-class roster and the counts beside the verdict rather
than the exit status: a class reporting zero over a document with content examined nothing, and a
plan whose findings are all excused exits 0 while saying so in those terms. A cannot-run is not a
pass. The author's own exit check already ran this before handing back
([`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Rules](${CLAUDE_PLUGIN_ROOT}/agents/design.md#rules)),
so a holding finding arriving here means the plan changed after that check or the check was skipped
— either is worth saying out loud rather than re-running quietly.

**The judgement half** is the `plan-convergence` reader. Its output is a report and never a verdict,
so there is nothing here to route on: the findings travel into the review, which rules on them.

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/plan-convergence.md and follow it.
  Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
  Design: ai-docs/plans/YYYY-MM-DD-name.design.md
")
```

**These parts of its report are the result and not decoration.** The agreement across its
three readings, with the healthy figure it states before the first; the coverage line, naming each
of its two classes covered or uncovered against the planted faults it reads on every run; the
breadth-control line, saying whether the planted spec-broader-than-design case was flagged and in how
many readings, a flagged case keeping the outcome off `clean`; and the outcome word, where
`cannot-run` is not a pass. A report arriving without them is incomplete —
re-spawn it rather than reading the finding list alone, because a finding list with no agreement
figure cannot be told from a stable one.

**Neither half is a verdict and neither blocks by itself.** What blocks is the reviewer's own rule
([`${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` § Rules](${CLAUDE_PLUGIN_ROOT}/agents/design-review.md#rules)):
GO is unavailable while an unexcused holding finding stands. Granting an excuse is the design
author's act and leaves a checkable record; it is not the reviewer's and not the orchestrator's.

## Step 8 — progress-file creation template (detail)

Create using canonical format at [`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md). Required: `**Branch:**`, `**base_commit:**`, `**Last build:**`, `**current_step:**`, `**last_passed_gate:**`, `**entry_args:**`, `## Decisions log`. For `/task` also `**Issue:**` / `**Spec:**` / `**Design:**`.

```
**Branch:** <TICKET-KEY>-<slug>
**base_commit:** <git rev-parse HEAD>
**current_step:** Step 8 — Implementation start
**last_passed_gate:** %BUILD_CMD% <module-path> | <ISO-8601 UTC timestamp> | <git rev-parse HEAD>
**entry_args:** <original $ARGUMENTS — a ticket key, "activate <slug>", free text, or (none)>
```

The `**entry_args:**` field is recorded ONCE at Step 8 and **read-only thereafter**. On lost-arguments re-entry (empty `$ARGUMENTS` after compaction), this is the canonical entry reference.

## Step 8 — first-action GO-notes verification (detail)

Verify both spec and design (with GO verdict) exist AND that **every note / minor / recommendation from the latest design-review GO verdict has been written back into the design document**. "Applied in code later" ≠ "resolved in the design"; the design doc is the implementation contract. Scan the most recent design-review verdict block — for each `Severity: note` / `minor` row and each `## Recommendations` bullet, confirm the corresponding section of `ai-docs/plans/YYYY-MM-DD-name.design.md` was updated to match. Missing spec, missing design, missing GO verdict, OR unresolved GO-notes = previous steps incomplete.

## Step 9 — verify list (full)

1. `%BUILD_CMD% <module-path>` — PASS.
1b. **Run the gate over DEPENDENTS when the change alters a published interface, or what a component requires of its collaborators.** A module-scoped gate cannot see either class, and both break a file the diff never touched. An altered **published interface** can invalidate a call site that itself did not change — including a test double built against the old shape, and most sharply where the new form is ambiguous with an existing one at the CALL site rather than at the definition; prefer avoiding that ambiguity at the source (a distinct name beats an optional form that collides) over compiling every dependent to find it. A change to **what a component requires of its collaborators** fails where the component is ASSEMBLED rather than where it is named, so a module that never mentions the new requirement still breaks at wiring time. Find the dependents by searching the test sources for the **CHANGED** name — not the new one, which no dependent uses yet — and run each hit's module through the gate.
2. `%TEST_CMD% <module-path>` — all green, read per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Reading a test result`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result). A zero-selected run reports success; prove selection before trusting a filtered pass.
3. `%FORMAT_CMD%` on every changed source file to format, THEN `%LINT_CMD%` as the gate — must exit clean. The formatter is not the gate.
4. For shell (`.sh`) files: `shellcheck <file>` — the analogue of the lint gate. Honor existing per-file `# shellcheck disable=...` directives; do not add new blanket disables. Surface it as an explicit AC at spec/design time, not only as a workflow gate.
5. For each AC — confirm covered by test or manual verification.
6. Show a `| # | Criterion | Test / Verification | Status |` summary table.
7. On ALL PASS → proceed to Step 9.5.

## Step 9.5 — documentation update (detail)

Update content files only — do NOT move spec/design to `done/` yet (Step 12):

1. **`ai-docs/context.md`** — resolve open questions answered during impl; update Plans list; add new architectural decisions.

## Every-group handoff (rationale)

During Step 8 the orchestrator NEVER executes subtask code in its own context. Every group fans out through `/context-reset` — including the first group, and including M = 1 designs. Re-state the rule to yourself before deciding the next action: *"Did I just receive a group return? Then the next action is to spawn the next group's `/context-reset` handoff, until the design's `## Handoff plan` is exhausted. No exceptions for 'one more quick subtask in this turn' or 'the first group is small enough to do inline'."*

**Failure modes this prevents.** Long-lived orchestrator sessions hit auto-compaction mid-task; the compaction summary does not reproduce the strict step sequence faithfully and Step 10 (self-review) gets silently omitted, or runtime handoff triggers fire against a degraded context. The every-group fan-out removes the failure mode structurally: the orchestrator's own context never grows long enough to trip compaction.

## Step 8 — local FAIL investigation before push

When the test gate returns FAILED, identify the specific failing test and reproduce it in isolation (`%TEST_CMD%` filtered to that one test) before deciding the failure was transient. A subsequent green run is NOT proof of transience — different test isolation, parallel test ordering, or dirty test fixtures can flip results. Only accept "transient" when the test is on a known-flaky list AND multiple reruns are consistently green.

## Step 11 — the scouted-plan sequence

Moved to [`${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md`](${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md)
— the spawn prompts for all five beats, the plan format, the reason-token table, the post-apply
micro-loop and the narrative behind each beat. The heading stays here so inbound references to it keep
resolving, and because the gate list below reads this page's own section names at run time.

## Step 12 — PR-body template (detail)

Claude prepares the title + body per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR title + body shape`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-title--body-shape); the user approves before `gh pr create` runs:

- **Title:** `<TICKET-KEY>: <conventional-commits header>` when the project uses ticket keys; a bare conventional-commits header otherwise.
- **Body:** summary paragraph(s) only — what changed and why, ≤3 bullets. Markdown renders, so bullets / inline code / links are fine — the constraint is *content* (summary-only). **NEVER** add `## Summary` / `## Test plan` section headers, test-count/stats lines, or `Co-Authored-By:` trailers (unless the user asks). **Name no ticket key other than the PR's own** — in a tracker-integrated repo a key in the description creates a remote link and can transition that ticket's status, and neither is undone by editing the text afterwards; backtick-wrap a key a human reader genuinely needs. Detail belongs in the commit body (`git log`) + the diff, not the PR description.
- **Pass the body via `--body-file`** whenever it contains backticks, apostrophes, or a construct a `PreToolUse(Bash)` hook matches — see [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#hook-false-positive-guard--body-content-matching-any-pretooluse-bash-regex).

## Patterns

Validated approaches `/task` should keep applying (carrot signals; soft verbs). **Each is stated in full elsewhere and this is a pointer list, not a second statement** — it was not: three rules lived only here until they were moved to the page that carries their siblings, which is the shape this list exists to avoid.

- **Default to** resuming the SAME agent from its transcript (`SendMessage`) on a transport-level drop, with exponential backoff from the 2nd consecutive failure, rather than cold-spawning a replacement that discards its gathered context. Full rule: [SKILL.md § Step 8](SKILL.md#step-8-implementation); re-stated for the design phase in [SKILL.md § Design Amendment](SKILL.md#design-amendment-re-entrant--triggered-from-step-8-or-step-11).
- **Writing and receiving a spawn prompt** — mark every factual claim with how it was obtained, treat a restated rule as a reminder rather than enforcement, read an instruction that contradicts itself as evidence rather than as a command, and read a relayed finding for which artefact it actually points at. All four, with the measurements behind them: [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication) and § Tooling.

## FORBIDDEN

- Declaring done with uncovered ACs.
- Skipping design review.
- Writing code before the spec is confirmed.
- `rm`ing `.progress.md` from within `/task` (it's gitignored and lives until `/pr-merged`).
- Staging `.progress.md` into a commit.
- Pushing from the default branch.
- Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — recording a redline marker and its log row.

## Gate checklist

| Before | Check |
|---|---|
| Steps 1–5 | Spec saved? `**Tracked in:** <KEY>` present (or `none` with reason)? ACs confirmed by user and verifiable? |
| Step 6 | Spec exists? ACs confirmed? Not a "spec-only / defer" run? |
| Step 8 | Design doc with GO? `## Handoff plan` present for every M ≥ 1? **Every GO-note written back into design doc?** |
| Step 8 start | Feature branch checked out? `git branch --show-current` is NOT the default branch? `base_commit` + `branch` recorded in progress file? |
| Each subtask | Build ✅? Tests run? `.progress.md` updated? Group handoff via `/context-reset`? |
| Step 9 | Build + tests + lint clean? `## Criterion checks (Round N)` filled, `Shown non-empty by` included? (**No design-side verification line is asked for — a design says nothing about tests**, so the round record is where a criterion meets a check.) |
| Step 9.5 | context.md updated? (spec/design NOT moved yet) |
| Step 10 | Self-review APPROVE? (Progress file persists in the working tree — gitignored — until `/pr-merged`.) |
| Step 11 | `major`/`blocker` objections confirmed by user? Breaking divergence → Amendment, non-breaking → marker + log row? PR body re-read after any push? |
| Step 12 | Branch ≠ default? spec/design moved to done/? Build clean? PR title prefixed and body summary-only (no Summary/Test-plan sections)? |

## Commit authorisation + hooks

Per AGENTS.md, `git commit` / `git push` / `gh pr create` are ASK-level for Claude. `/task` Step 12 prepares the staged file list + commit message, asks for confirmation, then runs the commit. Hook behaviour:

- **`auto-stage-learnings`** — auto-stages `ai-docs/learnings.md` and the `ai-docs/learnings/` directory (`git add ai-docs/learnings`) when either has unstaged or untracked changes at `git commit`. The directory form is what covers a per-branch entry file on its **first** write, when it is still untracked.
- **`archive-protection-reminder`** — advisory `Edit|Write` nudge when a write ADDS a `### ` header to `ai-docs/learnings.md`: new entries belong in `ai-docs/learnings/<username>-<branch>.md`. Exits 0, never blocks — the `/improve` fold and `Escalated?` / `Superseded by:` field edits pass untouched.
- **`branch-protection`** — blocks `git commit` / `git push` on the default branch as a safety net, and prints the recovery recipe. **A LONE `git push origin --delete <other-branch>` is exempt** — it sends nothing to the default branch — while a deletion naming the default branch, or one carrying a shell metacharacter, is still blocked: [`${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`](${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md).
- **`co-authored-by`** — blocks a `Co-Authored-By` trailer in a commit message (${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Workflow overrides the harness default here).
