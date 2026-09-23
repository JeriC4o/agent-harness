---
name: task
description: "Full task workflow from a user description OR a ticket key: interview → spec → design → design-review → impl → verify → self-review. Steps are strictly ordered and cannot be skipped."
disable-model-invocation: true
argument-hint: "[TICKET-KEY | task description]"
allowed-tools: Bash(git diff:*), Bash(git rev-parse:*), Bash(git checkout:*), Bash(git branch:*), Bash(git stash:*), Bash(git status:*), Bash(git log:*), Bash(git mv:*), Bash(gh pr view:*), Bash(ls:*), Bash(grep:*)
---

Full workflow for a task. Steps execute **strictly in sequence** — proceeding to N+1 before N is complete is FORBIDDEN.

> **Commit authorisation.** `git commit` / `git push` / `gh pr create` are ASK-level for Claude; Step 12 prepares the staged-file list + message, confirms, then commits. Hook behaviour (`auto-stage-learnings`, `archive-protection-reminder`, `branch-protection`): [reference.md § Commit authorisation + hooks](reference.md#commit-authorisation--hooks).

The task may originate from either:
- a **ticket key** (e.g. `/task PROJ-1234`) — `/interview` reads the ticket during Steps 1–5 if the project has a tracker reachable from this session; otherwise the key is carried as a reference only.
- a **user description** (e.g. `/task add foo to bar`) or empty (`/interview` interviews the user).

> **⚡ Compaction recovery check — read FIRST on every invocation.**
> If you are re-entering this skill after auto-compaction (summary block at top of context, or workflow context feels thin), STOP before any tool call and:
>
> 1. **Locate the durable-state file via this skill's active-state probe** — run the preamble glob (`ls ai-docs/plans/*.progress.md 2>/dev/null`) and apply the validation it documents.
> 2. Once the probe identifies the correct durable-state file, read it **top-to-bottom in one pass** — every line, including older sections and the `## Decisions log`. Do not skim. Recorded `current_step` is a cross-check, never an instruction to skip the read.
> 3. **Re-enter this skill from the top of its body** — let the preamble's probe / validation / RESUME sequence route control.
>
> If the probe finds no matching durable-state file, fresh invocation.
>
> See `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md § Compaction recovery (re-entry)` for canonical rationale.

## ⚡ First: check for active task

```bash
ls ai-docs/plans/*.progress.md 2>/dev/null
```

> **Re-entry-after-compaction case (lost-arguments path).** If `$ARGUMENTS` is empty (lost to compaction) AND the glob finds a match with `**entry_args:**` recorded, treat recorded `entry_args` as the canonical entry reference. `⚡ Second` and `⚡ Third` preambles MUST NOT fire on the lost-arguments path. Only `⚡ First` may route.

**If found → validate the match BEFORE jumping to RESUME** (gate — do NOT skip): branch matches `git branch --show-current`, `**base_commit:**` reachable, spec file exists, and the work is not already merged into the default branch. If validation fails, surface to user with **delete / park / RESUME anyway** options. Only after validation passes, run the **RESUME flow (skip Steps 1–7)**.

Validation checks (stale-merge + wrong-branch) and the RESUME-flow steps: [reference.md § ⚡ First — validation sequence (detail)](reference.md#-first--validation-sequence-detail).

---

## ⚡ Second: bare-ticket activation of a matching deferred spec

Fires only when `$ARGUMENTS` is **non-empty** and looks like a ticket key (`^[A-Z][A-Z0-9]+-\d+$`). Scan `ai-docs/plans/deferred/*.spec.md` for `**Tracked in:** <KEY>`. Zero matches → fall through to **⚡ Second-bis** (below). Exactly one match → move spec + design + progress into `ai-docs/plans/`, surface ACs for confirmation, jump to Step 6. Multiple matches → surface to user. Full sequence: [reference.md § ⚡ Second — bare-ticket activation sequence (full)](reference.md#-second--bare-ticket-activation-sequence-full).

---

## ⚡ Second-bis: bare-ticket re-entry of an active (planned-but-unstarted) spec

Fires when `$ARGUMENTS` is a ticket key AND `⚡ First` / `⚡ Second` found nothing. A `/task` can be **fully planned** — spec + design committed to the **active** `ai-docs/plans/` dir (NOT `deferred/`, NOT `done/`) — yet never started, so no `.progress.md` exists. Both routing preambles above miss this quadrant. Detect it BEFORE falling through to a fresh interview:

```bash
grep -rl "Tracked in:.*$ARGUMENTS" ai-docs/plans/*.spec.md 2>/dev/null
```

A hit (confirm the sibling `*.design.md` exists too) means the spec/design already exist → surface to the user for confirmation and skip to Step 6/7 (design-review → implementation); do **NOT** re-interview (it would duplicate the approved spec). Only after this active-spec scan comes up empty is a fresh interview (Steps 1–5) correct.

---

### Step 0: Branch gate (FIRST action — before Steps 1–5)

Run `git branch --show-current`. If it is the default branch (`main`), run `git checkout -b <TICKET-KEY>-<slug> main` **now**, before invoking `/interview`. Derive `<slug>` from the ticket title (or task description) — do not wait for the spec filename, which does not exist yet. If a DIFFERENT ticket's branch is checked out, pass the `main` base explicitly (same command) so the new branch does not inherit its commits; verify with `git log main..HEAD --oneline` (empty = clean). `git checkout -b` carries uncommitted and untracked work across, so branching here costs nothing and branching late risks a dirty default branch.

> AGENTS.md AXIOM 1 binds on **any file edit**, and Steps 1–5 write `*.spec.md` + `*.state.md`. Branching at Step 8 is too late — "the skill says Step 8" is not a licence.

### Steps 1–5: Spec creation (delegated to `/interview`)

`/task` does not duplicate the interview workflow — treat Steps 1–5 as a single delegated phase. If a saved spec already exists under `ai-docs/plans/`, confirm with the user and skip to Step 6. Otherwise invoke `Skill(skill="interview", args="$ARGUMENTS")` (handles entry-mode detection, scope confirmation, clarifying rounds, ticket resolution, spec writing). Spec-only runs move the spec to `ai-docs/plans/deferred/` and stop. Detail: [reference.md § Steps 1–5 — spec creation delegation (detail)](reference.md#steps-15--spec-creation-delegation-detail).

**Before Step 6:** confirm the spec exists at `ai-docs/plans/YYYY-MM-DD-name.spec.md` and the user has approved its `## Acceptance Criteria`.

### Step 6: Design Subagent

First action: confirm the spec exists. Spawn `design`:

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/design.md and follow it.
  Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
  Research the codebase, produce Design Document with decomposition + Handoff plan.
")
```

**After return — verify the file exists** (`ls ai-docs/plans/*.design.md` → `YYYY-MM-DD-name.design.md`). The `design` subagent owns the `Write`; if the design-doc text appeared in the response but no file landed on disk, **STOP and RE-RUN the `design` subagent** — do NOT transcribe its text output into the file using `Write` / `Edit` yourself (AGENTS.md AXIOM: orchestrator never writes `*.design.md`).

### Step 7: Design review

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/design-review.md and follow it.
  Design doc: ai-docs/plans/YYYY-MM-DD-name.design.md
  Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
")
```

Verdict: GO / ITERATE / STOP.

- **GO** → proceed to Step 8. Spec-amending notes need Step 6 → Step 7 re-run, not a fold-in — see *Spec Amendment recipe*.
- **ITERATE** → back to Step 6 (max 3 rounds).
- **STOP** → fundamental flaw with the approach. Surface verdict + `Issues` table; do not start Step 8.

### Design Amendment (re-entrant — triggered from Step 8 or Step 11)

If implementation reveals a necessary deviation from the design, **or** a self-review finding requires a design change: stop the step, surface to user for approval, spawn the `design` subagent to apply the amendment (NEVER edit `*.design.md` inline), re-run Step 7 (max 3 rounds). On GO → resume. **A transport-level drop is not a returned amendment** — resume the SAME agent per Step 8's backoff clause rather than cold-spawning a fresh one (a respawn discards its gathered context), and verify the write landed on disk (mtime + `grep`) before treating the round as spent. **Silently implementing a deviation without triggering Design Amendment — FORBIDDEN.** Full recipe (spawn-prompts, ITERATE/STOP handling): [reference.md § Design Amendment recipe (re-entrant — triggered from Step 8 or Step 11)](reference.md#design-amendment-recipe-re-entrant--triggered-from-step-8-or-step-11).

### Spec Amendment recipe

If a self-review or reviewer-comment fix requires editing `ai-docs/plans/*.spec.md` (active or `done/`): stop the step, surface to user for approval, re-invoke `spec-writer` to apply the amendment (NEVER `Edit` `*.spec.md` inline), re-run Step 6 (design) → Step 7 (design-review) on the amended (spec, design) pair (max 3 rounds). Resume the triggering step from the GO verdict. Detection: mechanical at the top of every fix round — `git diff` includes a `*.spec.md` path → trigger fires regardless of how small the doc edit appears.

Full recipe (state-file update, spawn-prompts): [reference.md § Spec Amendment recipe (re-entrant — triggered from Step 7 GO-with-notes resolution)](reference.md#spec-amendment-recipe-re-entrant--triggered-from-step-7-go-with-notes-resolution).

> The amendment TRIGGER is mechanical and mandatory (above) — "one line", "AC text unchanged", and "docs-only" are not mitigating inputs, and the soft verb below governs only the review's DEPTH, never whether the recipe fires. **Default to** keeping the full review loop for an amendment that changes a VERIFICATION GATE rather than prose — the gate is what every later claim of correctness rests on, so a silently-broken check is worse than no check. Request this reviewer behaviour explicitly in the spawn prompt: extract the check block verbatim from the file, run it against self-built conforming AND violating fixtures, and try to falsify each "this is structural / guaranteed" sentence rather than reading it.

---

### Step 8: Implementation

> First action: verify spec + design + GO verdict exist AND that every `note` / `minor` / recommendation from the latest design-review GO has been written back into the design doc. "Applied in code later" ≠ "resolved in the design"; the design doc is the implementation contract.
>
> **On a transport-level drop (socket closed / connection closed mid-response), resume the SAME agent from its transcript (`SendMessage`) — it preserves already-gathered context.** First resume after a single drop may be immediate; from the 2nd consecutive failure on the same step, `sleep` 2s→4s→8s→16s→32s (cap 32s, small jitter) before re-dispatching; cap ~5 attempts per step, then surface to the user — never a silent loop. Reset the delay after any success.

- **Confirm the Step-0 branch** — `git branch --show-current` must show `<TICKET-KEY>-<slug>`, not `main`. If Step 0 was skipped (resumed or legacy run), create it now off the default branch: `git checkout -b <TICKET-KEY>-<slug> main`. Record the branch name in the progress file. The gate is **any file edit**, not just code — the spec/design/state writes in Steps 1–7 already counted (AXIOM 1).
- **Before any `git commit`:** confirm the branch is not the default one, and check `git status` for `ai-docs/learnings.md` **and** `ai-docs/learnings/` (a first-write per-branch entry file is untracked, and `git status` collapses it to one `ai-docs/learnings/` line). Hook behaviour (`branch-protection`, `auto-stage-learnings`, `archive-protection-reminder`): [reference.md § Commit authorisation + hooks](reference.md#commit-authorisation--hooks).
- Create `ai-docs/plans/YYYY-MM-DD-name.progress.md` at start using canonical schema at [`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md). Required fields: `**Branch:**`, `**base_commit:**`, `**Last build:**`, `**current_step:**`, `**last_passed_gate:**`, `**entry_args:**`, `## Decisions log` (for `/task` also `**Issue:**` / `**Spec:**` / `**Design:**`). Record `**entry_args:**` (original `$ARGUMENTS`) ONCE — read-only thereafter. Field-by-field template: [reference.md § Step 8 — progress-file creation template (detail)](reference.md#step-8--progress-file-creation-template-detail).
- After each subtask:
  1. `%BUILD_CMD% <module-path>` — must compile; `%TEST_CMD%` filtered to the new test if the subtask adds tests; `%FORMAT_CMD%` on changed files.
  2. **Update `.progress.md`:** rewrite `**current_step:**` to `Step 8 — subtask N of M complete`; rewrite `**last_passed_gate:**` (`<gate command> | <UTC ts> | <git rev-parse HEAD>`); append a `## Decisions log` bullet for any non-trivial choice (prefixed `Step 8 subtask N:`).
  3. **Every-group handoff (binding).** During Step 8 the orchestrator NEVER executes subtask code in its own context — every group (including the first, including M=1) fans out through `/context-reset` at the start of each group per the design's `## Handoff plan`. Rationale: [reference.md § Every-group handoff (rationale)](reference.md#every-group-handoff-rationale).
- Unknown API → read sources → search the codebase (`${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md`) → ask user. Don't guess.
- Bug report during impl → activate `/bugfix`, then return.
- Implementation reveals design must change → trigger **Design Amendment**, then resume.

### Step 9: Verify

Gates (all must PASS): `%BUILD_CMD% <module-path>`; `%TEST_CMD% <module-path>` (all green — and read the result per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Reading a test result`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result), not by exit code); `%FORMAT_CMD%` to format THEN `%LINT_CMD%` as the gate — must exit clean (the formatter is NOT the gate; see [`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Linter posture`](${CLAUDE_PLUGIN_ROOT}/docs/code-style.md#linter-posture)). **If the diff changed a PUBLIC API signature (esp. an arity-ambiguous overload), also test-compile every module that mocks/depends on the symbol** — a module-scoped build alone misses a downstream mock-stub compile break. **Also for a CONSTRUCTOR-dependency change on an injected component: search for the CHANGED CLASS's OWN name in test sources** — DI-context tests break at load even without mentioning the new type. **For changed `.sh` files: `shellcheck <file>`.** Then a per-AC coverage check: locate the test for each AC and show a `| # | Criterion | Test / Verification | Status |` table (one row per AC). On ALL PASS → Step 9.5. Full list: [reference.md § Step 9 — verify list (full)](reference.md#step-9--verify-list-full).

**Write progress:** rewrite `**current_step:**` to `Step 9 — Verify (ALL PASS)`; rewrite `**last_passed_gate:**`; append a `## Decisions log` bullet.

### Step 9.5: Update documentation

Update content files only — **do not move spec/design to `done/` yet** (Step 12). Touch `ai-docs/context.md` (new entity / open question) as applicable. Detail: [reference.md § Step 9.5 — documentation update (detail)](reference.md#step-95--documentation-update-detail). **Write progress:** rewrite `**current_step:**` to `Step 9.5 — docs updated`; append a `## Decisions log` bullet.

### Step 10: Self-review loop (max 3 rounds)

Spawn `self-review`:

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md and follow it.
  Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
  Design: ai-docs/plans/YYYY-MM-DD-name.design.md
  Progress: ai-docs/plans/YYYY-MM-DD-name.progress.md
")
```

- **On APPROVE:** proceed to Step 12. The progress file is gitignored and **stays in the working tree** (deleted only by `/pr-merged`) — do NOT `rm` it here. Write progress: `**current_step:**` = `Step 10 — self-review APPROVE (Round N)`.
- **On REJECT:** proceed to Step 11, then loop back here. Write progress: `**current_step:**` = `Step 10 — self-review REJECT (Round N), addressing findings`.
- **After round 3 with REJECT:** surface remaining `⬜ Open` findings to the user and ask how to proceed.

### Step 11: Review fixes

> **AXIOM — A finding is routed by its SUBJECT, not by the remedy chosen for it. Classify BEFORE choosing a fix.**
> Two independent arms; check **A first**, because choosing a remedy is what defeats it.
>
> **Arm A — the finding's subject.** Ask one question: **would closing this finding leave a sentence in a `*.spec.md` / `*.design.md` untrue?** If yes, the amendment trigger fires **even when the fix lands entirely in code**.
>
> **Arm B — the fix's target.** The proposed fix would edit a `*.spec.md` / `*.design.md` under `ai-docs/plans/` (active or `done/`).
>
> | Arm A or B names a… | Action |
> |---|---|
> | `*.design.md` under `ai-docs/plans/` | **STOP.** Trigger Design Amendment — surface, update design, re-run Step 7 (max 3 rounds), then resume Step 11. Mark originating finding `✅ Fixed (design amended)`. |
> | `*.spec.md` under `ai-docs/plans/` | **STOP.** Trigger Spec Amendment — surface, update spec, re-run Step 6 → Step 7, then resume Step 11. Mark `✅ Fixed (spec amended)`. |
> | Neither arm fires — no artefact claim at stake, fix touches only source / build manifests / non-`ai-docs/plans/` `*.md` | Normal Step 11 code-fix path — apply, re-run gates. |
>
> **CLOSING GATE — a finding that fired Arm A may not be marked `✅ Fixed` until the cited sentence has been RE-READ in its file and either (a) confirmed true of the post-fix state, or (b) amended.** Record which. Shipping the thing a sentence promised makes the sentence true only if the shipped thing does what the sentence says it does.
>
> **Why Arm A exists.** Keying only on the fix diff hands the routing decision to the same party that then marks the finding `✅ Fixed`. The shape: a finding reports that a design's mitigation cites a check as the thing that catches a failure, and that check has since been deleted. **Both remedies are valid** — ship the check, or correct the sentence. Choosing the code-side remedy routes to the normal path **correctly by a diff-keyed table**: the table is satisfied, not violated, while the sentence stays false. Nothing between "choose fix" and "mark `✅ Fixed`" re-reads it.

For each `⬜ Open` finding in the latest `## Self-Review (Round N)` section: **fix** (mark `✅ Fixed`), **design-amend** (per table), **spec-amend** (per table), or **object** (`nit` / `minor` autonomously; `major` / `blocker` only after user approval — mark `⚠️ Objected: <reason>`).

After all findings resolved, run gates (`%BUILD_CMD%`, `%TEST_CMD%`, `%FORMAT_CMD%` to format then `%LINT_CMD%` as the gate), then:

1. Update `.progress.md`.
2. **PR body sync (unconditional):** if a PR is open (`gh pr view --json title,body`), re-read the PR body, edit only if it contradicts new commits (`gh pr edit`).
3. **Resolve fixed review threads (unconditional)** per `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR review comment resolution`.
4. **Write progress:** rewrite `**current_step:**` to `Step 11 — review fixes complete (Round N)`. Return to Step 10.

### Step 12: Finalise docs, surface staged commit

1. **Step-skip gate.** Read `**current_step:**`. MUST be `Step 10 — self-review APPROVE (Round N)` or `Step 11 — review fixes complete (Round N)`. Else **STOP**, surface the gap, loop back to the missing step. No "too simple" exemption.
2. **Confirm `.progress.md` is NOT staged.** Gitignored (`ai-docs/plans/**/*.progress.md`); should not appear in `git status`. If accidentally tracked, unstage.
3. Confirm the branch is not the default one. Otherwise stop and apply recovery ([`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Recovery`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#recovery-from-accidental-edits-on-the-default-branch)).
4. **Move plan files:** `git mv` spec/design to `ai-docs/plans/done/`.
5. `%BUILD_CMD% <module-path>` — sanity build before staging.
6. **Surface to user (Claude doesn't commit unasked):** the stage-list (impl files from `## Files touched`, `ai-docs/context.md` if touched, `ai-docs/learnings/` if this task wrote an entry — and `ai-docs/learnings.md` only if the archive itself changed, spec/design now in `done/`) and the suggested commit message. When the project uses ticket keys, the `<TICKET-KEY>:` title prefix is mandatory. Stats lines belong in the commit body, NOT the PR body. Full template: [reference.md § Step 12 — PR-body template (detail)](reference.md#step-12--pr-body-template-detail).
7. **Write progress:** rewrite `**current_step:**` to `Step 12 — staged for user commit`; append a `## Decisions log` bullet.
8. After the user confirms the commit + `git push -u origin <branch>` (the `pr-body-sync` reminder hook fires on push): open the PR (`gh pr create --title "<TICKET-KEY>: <header>" --body-file <file>`) with the user's approval; capture the PR number. **Record it into the progress file's `**PR:** #<id>` field the moment the PR exists** — a later fix round reads that line first, and without it the PR has to be re-derived from the branch (`/pr-merged` works from the branch name and does not read it). Pass the body via `--body-file` when it contains characters a shell would mangle ([`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#hook-false-positive-guard--body-content-matching-any-pretooluse-bash-regex)).

**Reviewer comments and CI failures arrive after Step 12** — handle them as a post-push fix round per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Post-push fix commits get self-review too`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#post-push-fix-commits-get-self-review-too). Do not re-enter `/task` for routine reviewer feedback; architectural-rework requests are the exception.

---

## Gate checklist

Each gate is enforced inline as the **First action** of its step; the consolidated per-step recap table lives in [reference.md § Gate checklist](reference.md#gate-checklist).

## Patterns

Validated approaches `/task` should keep applying (carrot signals; soft verbs). Each is stated in full at its point of execution — this index exists so the rule is findable without reading every step.

- **Default to** resuming the SAME agent from its transcript (`SendMessage`) on a transport-level drop, with exponential backoff from the 2nd consecutive failure, rather than cold-spawning a replacement that discards its gathered context. Full rule: [Step 8](#step-8-implementation); re-stated for the design phase in [Design Amendment](#design-amendment-re-entrant--triggered-from-step-8-or-step-11).

## FORBIDDEN

Skipping Step 7 design-review; skipping Step 10 self-review on "too simple" tasks; writing code before confirmed spec (Steps 1–5); declaring done without Step 9; editing on the default branch without recovery; silently implementing a design deviation (must trigger Design Amendment). Expanded list: [reference.md § FORBIDDEN](reference.md#forbidden).

---

**Reference:** [`reference.md`](reference.md) — per-section detail (linked inline above).
