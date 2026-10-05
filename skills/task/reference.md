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
3. Read only files from `## Files touched`.
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
5. **On GO** → resume from the step that triggered the amendment.
6. **On ITERATE** → re-spawn the `design` subagent with the iteration feedback and re-run review (counts against the 3-round limit). Never edit the design doc inline to "fix the blockers".
7. **On STOP** → surface to user; do not proceed.

> Silently implementing a deviation without triggering Design Amendment — FORBIDDEN.
> Editing `*.design.md` inline instead of spawning the `design` subagent — FORBIDDEN. The orchestrator's role is (1) surface to user, (2) spawn `design`, (3) spawn `design-review`. The `Write` to `*.design.md` belongs to the `design` subagent regardless of how trivial the amendment looks.

## Spec Amendment recipe (re-entrant — triggered from Step 7 GO-with-notes resolution)

If a Step 7 design-review GO verdict surfaces a `note` / `minor` / recommendation whose resolution requires a change to the **spec** (wording, AC, or technical-constraints edit) — not just an in-place design fold-in:

1. **Classify each note** at Step 7 close: **design-internal** (route through `design` subagent for in-place fold-in; no loop) vs **spec-amending** (note implies a spec wording / AC / constraint change).
2. **Stop before Step 8.** Do not begin implementation against the pre-amendment spec — FORBIDDEN.
3. **Surface to user via `AskUserQuestion`** — state the requirement change itself in plain product terms (what is expected of the system now, versus before), not as a spec edit: **no** spec or design citation, **no** acceptance-criterion id ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)). Wait for explicit approval.
4. **On user approval — re-invoke the `spec-writer` subagent to apply the amendment** — do NOT `Edit` `*.spec.md` inline. Per AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`":
   - Update the interview state file (`<spec_path>.state.md`) by appending the user's amendment description as a Q&A entry in `prior_qa`, incrementing `round`.
   - Spawn `spec-writer` with the updated state. The spec-writer owns the `Write` to `*.spec.md`.
5. **Re-enter Step 6 (`design` Subagent)** with explicit context: "spec was amended at Step 7 GO-with-notes resolution".
6. **Re-enter Step 7 (design-review)** against the new (spec, design) pair (counts against the 3-design-round-cap).
7. **On GO** → proceed to **Step 8**.

> Folding a spec-amending note into the design alone is FORBIDDEN — the design would be built against the old spec without ever being verified against the new one.
> Editing `*.spec.md` inline instead of re-invoking `spec-writer` — FORBIDDEN. The orchestrator's role is (1) update state file, (2) re-spawn `spec-writer`, (3) re-spawn `design`, (4) re-spawn `design-review`.

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

1. `%BUILD_CMD% <module-path>` — compiles clean.
1b. **Downstream-dependents test-compile when a PUBLIC API signature changed.** If the diff adds or alters a public signature — ESPECIALLY adding an overload whose defaulted-trailing-param form is call-arity-ambiguous with an existing overload (it silently makes existing mock-stubs ambiguous) — also compile the TEST sources of downstream modules that mock/depend on that symbol, not just `<module-path>`. Find them with a filtered search for the symbol in test sources, then test-compile each. Better: avoid the ambiguity at the source — drop the new overload's trailing default, or give it a distinct name. **Also when the diff changes an injected component's CONSTRUCTOR (adds/removes/retypes a dependency):** DI-context tests that wire the UNCHANGED class break at context load for the newly-required bean even though they never mention the new type — search for the CHANGED CLASS's OWN name in test sources, NOT just the new dependency's name, and test-compile each hit's module.
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

## Step 11 — review-fix narrative (detail)

For each `⬜ Open` finding in the latest `## Self-Review (Round N)` section — **classify before choosing a remedy**, per the Step 11 AXIOM in `SKILL.md`. The first question is not "how do I fix this" but *"would closing this leave a sentence in the spec or design untrue?"*; if yes, it is an amendment however the fix lands.

- **Fix it** → mark `✅ Fixed`, implement the change. **If the finding quoted a spec/design sentence, re-read that sentence in its file first** and either confirm it true of the post-fix state or amend it — shipping what a sentence promised makes the sentence true only if the shipped thing does what it says.
- **Requires a design change** → trigger the **Design Amendment** recipe (user approval required); on return mark `✅ Fixed (design amended)`.
- **Requires a spec change** → trigger the **Spec Amendment** recipe; on return mark `✅ Fixed (spec amended)`.
- **Object to it** (finding is wrong or intentionally out of scope):
  - `nit` / `minor`: Subagent may object autonomously — write reason, mark `⚠️ Objected: <reason>`.
  - `major` / `blocker`: **surface to user first** before objecting. User must approve.

After all findings are resolved, run gates (`%BUILD_CMD%`, `%TEST_CMD%`, `%FORMAT_CMD%` to format then `%LINT_CMD%` as the gate), update `.progress.md`, re-read the PR body via `gh pr view --json title,body` (edit only if it contradicts new commits), and resolve every fixed review thread per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR review comment resolution`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-review-comment-resolution).

## Step 12 — PR-body template (detail)

Claude prepares the title + body per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR title + body shape`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-title--body-shape); the user approves before `gh pr create` runs:

- **Title:** `<TICKET-KEY>: <conventional-commits header>` when the project uses ticket keys; a bare conventional-commits header otherwise.
- **Body:** summary paragraph(s) only — what changed and why, ≤3 bullets. Markdown renders, so bullets / inline code / links are fine — the constraint is *content* (summary-only). **NEVER** add `## Summary` / `## Test plan` section headers, test-count/stats lines, or `Co-Authored-By:` trailers (unless the user asks). **Name no ticket key other than the PR's own** — in a tracker-integrated repo a key in the description creates a remote link and can transition that ticket's status, and neither is undone by editing the text afterwards; backtick-wrap a key a human reader genuinely needs. Detail belongs in the commit body (`git log`) + the diff, not the PR description.
- **Pass the body via `--body-file`** whenever it contains backticks, apostrophes, or a construct a `PreToolUse(Bash)` hook matches — see [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#hook-false-positive-guard--body-content-matching-any-pretooluse-bash-regex).

## FORBIDDEN

- Declaring done with uncovered ACs.
- Skipping design review.
- Writing code before the spec is confirmed.
- `rm`ing `.progress.md` from within `/task` (it's gitignored and lives until `/pr-merged`).
- Staging `.progress.md` into a commit.
- Pushing from the default branch.
- Silently deviating from the design without triggering Design Amendment.

## Gate checklist

| Before | Check |
|---|---|
| Steps 1–5 | Spec saved? `**Tracked in:** <KEY>` present (or `none` with reason)? ACs confirmed by user and verifiable? |
| Step 6 | Spec exists? ACs confirmed? Not a "spec-only / defer" run? |
| Step 8 | Design doc with GO? `## Handoff plan` present for every M ≥ 1? **Every GO-note written back into design doc?** |
| Step 8 start | Feature branch checked out? `git branch --show-current` is NOT the default branch? `base_commit` + `branch` recorded in progress file? |
| Each subtask | Build ✅? Tests run? `.progress.md` updated? Group handoff via `/context-reset`? |
| Step 9 | Build + tests + lint clean? All ACs covered with `AC<N> verified by: <command>` lines? |
| Step 9.5 | context.md updated? (spec/design NOT moved yet) |
| Step 10 | Self-review APPROVE? (Progress file persists in the working tree — gitignored — until `/pr-merged`.) |
| Step 11 | `major`/`blocker` objections confirmed by user? Design change → Design Amendment triggered? PR body re-read after any push? |
| Step 12 | Branch ≠ default? spec/design moved to done/? Build clean? PR title prefixed and body summary-only (no Summary/Test-plan sections)? |

## Commit authorisation + hooks

Per AGENTS.md, `git commit` / `git push` / `gh pr create` are ASK-level for Claude. `/task` Step 12 prepares the staged file list + commit message, asks for confirmation, then runs the commit. Hook behaviour:

- **`auto-stage-learnings`** — auto-stages `ai-docs/learnings.md` and the `ai-docs/learnings/` directory (`git add ai-docs/learnings`) when either has unstaged or untracked changes at `git commit`. The directory form is what covers a per-branch entry file on its **first** write, when it is still untracked.
- **`archive-protection-reminder`** — advisory `Edit|Write` nudge when a write ADDS a `### ` header to `ai-docs/learnings.md`: new entries belong in `ai-docs/learnings/<username>-<branch>.md`. Exits 0, never blocks — the `/improve` fold and `Escalated?` / `Superseded by:` field edits pass untouched.
- **`branch-protection`** — blocks `git commit` / `git push` on the default branch as a safety net, and prints the recovery recipe.
- **`co-authored-by`** — blocks a `Co-Authored-By` trailer in a commit message (${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Workflow overrides the harness default here).
