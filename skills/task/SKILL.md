---
name: task
description: "Full task workflow from a user description OR a ticket key: interview → spec → design → design-review → impl → verify → self-review. Steps are strictly ordered and cannot be skipped."
when_to_use: "Activate when the user asks for implementation work that needs a spec and a design before any code: a new feature, a ticket key to implement, a change spanning several files or modules. The call is PUT TO THE USER for confirmation rather than taken, and a subagent asking for it is refused outright — the `skill-gate` hook decides both, and neither decision is absolute: it fails open where `jq` is unavailable, and the confirmation is a permission `ask`, which a project that allow-lists the `Skill` tool would let through unprompted. Treat both as the rule rather than as a wall. SKIP for a reported defect or regression (that is /bugfix), for questions and codebase exploration, and for a one-line change the user has already specified."
argument-hint: "[TICKET-KEY | task description]"
allowed-tools: Bash(git diff:*), Bash(git rev-parse:*), Bash(git checkout:*), Bash(git branch:*), Bash(git stash:*), Bash(git status:*), Bash(git log:*), Bash(git mv:*), Bash(gh pr view:*), Bash(ls:*), Bash(grep:*)
---

Full workflow for a task. Steps execute **strictly in sequence** — proceeding to N+1 before N is complete is FORBIDDEN.

> **Commit authorisation.** `git commit` / `git push` / `gh pr create` are ASK-level for Claude; Step 12 prepares the staged-file list + message, confirms, then commits. Hook behaviour (`auto-stage-learnings`, `archive-protection-reminder`, `branch-protection`): [reference.md § Commit authorisation + hooks](reference.md#commit-authorisation--hooks).

The task may originate from either:
- a **ticket key** — `/interview` reads the ticket during Steps 1–5 if the project has a tracker reachable from this session; otherwise the key is carried as a reference only.
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

**First, both convergence halves — then the review, which reads both.** Two calls, each its own: `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-convergence.sh <spec_path> <design_path>`, read by its per-class roster and counts rather than its exit status; and a spawn of the `plan-convergence` reader (`${CLAUDE_PLUGIN_ROOT}/agents/plan-convergence.md`), whose output is a report and never a verdict. A cannot-run from either is not a pass. **The ordering is what satisfies the judgement class's obligation never to be the only check standing** — so neither half is optional and neither is run after the review. Both results go into the review spawn. Spawn prompt, the three figures its report must carry, and what blocks on what: [reference.md § Step 7 — the two convergence halves (detail)](reference.md#step-7--the-two-convergence-halves-detail).

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/design-review.md and follow it.
  Design doc: ai-docs/plans/YYYY-MM-DD-name.design.md
  Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
")
```

Verdict: GO / ITERATE / STOP.

- **GO** → **transcribe the verdict's `note` / `minor` rows and recommendation bullets, verbatim, into the progress file's `## Design-review notes` section FIRST** (creating the file if absent; `(none)` when there are none), then proceed to Step 8. The verdict is a response and nothing else persists it, while both parties enforcing the fold-in read it after it is gone — [why, and the record's shape](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md#design-review-notes). Spec-amending notes need Step 6 → Step 7 re-run, not a fold-in — see *Spec Amendment recipe*.
- **ITERATE** → back to Step 6 (max 3 rounds). **A round whose findings are only about the DOCUMENT's accuracy — stale counts, moved anchors, a representative written in a shape the code never receives — is not a reason to spend a round**, and repeated ones are a size signal rather than a rigour signal: fix them as text and split rather than iterate (`${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` § Rules). At the cap with a genuine DESIGN blocker still open the verdict stays ITERATE and the exhausted cap is surfaced to the user — a burned cap ends the loop, not the gate, and fixes applied after it still get one verification pass.
- **STOP** → fundamental flaw with the approach. Surface verdict + `Issues` table; do not start Step 8.

### Design Amendment (re-entrant — triggered from Step 8 or Step 11)

**From Step 11, when a self-review finding's divergence BREAKS the agreed approach; from Step 8, only when the user asks for the rebuild** — the implementation step surfaces a divergence and nothing restarts on its own account. On either entry: stop the step, surface to user for approval, spawn the `design` subagent to apply the amendment (NEVER edit `*.design.md` inline), re-run Step 7 (max 3 rounds). On GO → resume. **A transport-level drop is not a returned amendment**: Step 8's backoff clause governs, and the write is verified on disk before the round counts as spent. **Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — recording a redline marker and its log row — FORBIDDEN.** Full recipe (spawn-prompts, ITERATE/STOP handling): [reference.md § Design Amendment recipe (re-entrant — triggered from Step 8 or Step 11)](reference.md#design-amendment-recipe-re-entrant--triggered-from-step-8-or-step-11).

### Spec Amendment recipe

If a self-review or reviewer-comment fix requires editing `ai-docs/plans/*.spec.md` (active or `done/`): stop the step, surface to user for approval, re-invoke `spec-writer` to apply the amendment (NEVER `Edit` `*.spec.md` inline). Detection: mechanical at the top of every fix round — `git diff` includes a `*.spec.md` path → trigger fires regardless of how small the doc edit appears.

**After the amendment, ONE question decides the route — does it change the AGREED APPROACH?** Yes re-runs Step 6 → Step 7 and resets the log; no takes neither — no review round and no log row, because a changed requirement is not a divergence — and the closing fold authors the design from the amended spec. Answering it by reflex is the back door this change exists to close, so the recipe states both branches rather than defaulting.

Full recipe (spawn-prompts, and why no interview state file is involved): [reference.md § Spec Amendment recipe (re-entrant — triggered from Step 7 GO-with-notes resolution)](reference.md#spec-amendment-recipe-re-entrant--triggered-from-step-7-go-with-notes-resolution).

> The amendment TRIGGER is mechanical and mandatory **once the route is the amendment** (above) — "one line", "AC text unchanged", and "docs-only" are not mitigating inputs, and the soft verb below governs only the review's DEPTH, never whether the recipe fires. **What decides the ROUTE is a different question and sits upstream of this sentence: does the divergence break the agreed approach?** A non-breaking one takes the marker-plus-log-row remedy and never reaches this trigger; a breaking one reaches it, and then nothing mitigates it.

---

### Step 8: Implementation

> First action: verify spec + design + GO verdict exist AND that every `note` / `minor` / recommendation from the latest design-review GO has been written back into the design doc. **Read those notes from the progress file's `## Design-review notes` section, never from the response text**, and fill each row's last column as you confirm the fold-in. A section absent on a task that reached Step 7 is a STOP, not a clean pass. "Applied in code later" ≠ "resolved in the design"; the design doc is the implementation contract.
>
> **On a transport-level drop (socket closed / connection closed mid-response), resume the SAME agent from its transcript (`SendMessage`) — it preserves already-gathered context.** First resume after a single drop may be immediate; from the 2nd consecutive failure on the same step, `sleep` 2s→4s→8s→16s→32s (cap 32s, small jitter) before re-dispatching; cap ~5 attempts per step, then surface to the user — never a silent loop. Reset the delay after any success.

- **Confirm the Step-0 branch** — `git branch --show-current` must show `<TICKET-KEY>-<slug>`, not `main`. If Step 0 was skipped (resumed or legacy run), create it now off the default branch: `git checkout -b <TICKET-KEY>-<slug> main`. Record the branch name in the progress file. The gate is **any file edit**, not just code — the spec/design/state writes in Steps 1–7 already counted (AXIOM 1).
- **Before any `git commit`:** confirm the branch is not the default one, and check `git status` for `ai-docs/learnings.md` **and** `ai-docs/learnings/` (a first-write per-branch entry file is untracked, and `git status` collapses it to one `ai-docs/learnings/` line). Hook behaviour (`branch-protection`, `auto-stage-learnings`, `archive-protection-reminder`): [reference.md § Commit authorisation + hooks](reference.md#commit-authorisation--hooks).
- Create `ai-docs/plans/YYYY-MM-DD-name.progress.md` at start — **or fill in the one Step 7 already created for the design-review notes, rather than overwriting it** — using canonical schema at [`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md). Required fields: `**Branch:**`, `**base_commit:**`, `**Last build:**`, `**current_step:**`, `**last_passed_gate:**`, `**entry_args:**`, `## Decisions log` (for `/task` also `**Issue:**` / `**Spec:**` / `**Design:**`). Record `**entry_args:**` (original `$ARGUMENTS`) ONCE — read-only thereafter. Field-by-field template: [reference.md § Step 8 — progress-file creation template (detail)](reference.md#step-8--progress-file-creation-template-detail).
- After each subtask:
  1. `%BUILD_CMD% <module-path>` — PASS; `%TEST_CMD%` filtered to the new test if the subtask adds tests; `%FORMAT_CMD%` on changed files.
  2. **Update `.progress.md`:** rewrite `**current_step:**` to `Step 8 — subtask N of M complete`; rewrite `**last_passed_gate:**` (`<gate command> | <UTC ts> | <git rev-parse HEAD>`); **rewrite `## Next action` to the move actually next and tick the closed subtask's box**; append a `## Decisions log` bullet for any non-trivial choice (prefixed `Step 8 subtask N:`). **Every later *Write progress* in this skill names only its own `current_step` value — the other three are owed there too**, and a compaction-recovered orchestrator jumps straight to `## Next action`, where a stale paragraph reads as an instruction rather than as stale.
  3. **Every-group handoff (binding).** During Step 8 the orchestrator NEVER executes subtask code in its own context — every group (including the first, including M=1) fans out through `/context-reset` at the start of each group per the design's `## Handoff plan`. Rationale: [reference.md § Every-group handoff (rationale)](reference.md#every-group-handoff-rationale).
- Unknown API → read sources → search the codebase (`${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md`) → ask user. Don't guess.
- Bug report during impl → activate `/bugfix`, then return.
- **Implementation diverges from the frozen design → surface it; nothing restarts on its own account.** Stop at the **first** divergence in the task, lead with a recommended correction mode and its grounds in one line — the grounds **quote** a signal read off the design itself — and the user's single word settles it for the whole task; asking again at each later divergence is the cost this removes. Default: the answer is fixed in code and the correction becomes one redline marker plus one row in `ai-docs/plans/<spec-base>.redline.md`, whose header carries the chosen mode. The ground-up rebuild stays available and unchanged if the user asks for it (*Design Amendment* above). Modes, the recommendation rubric, the marker's spelling and the one-pass-per-step bound: [`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Redline marking](${CLAUDE_PLUGIN_ROOT}/agents/design.md#redline-marking).

### Step 9: Verify

Gates (all must PASS): `%BUILD_CMD% <module-path>`; `%TEST_CMD% <module-path>` (all green — and read the result per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Reading a test result`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result), not by exit code); `%FORMAT_CMD%` to format THEN `%LINT_CMD%` as the gate — must exit clean (the formatter is NOT the gate; see [`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Linter posture`](${CLAUDE_PLUGIN_ROOT}/docs/code-style.md#linter-posture)). **If the change alters a published interface, or what a component requires of its collaborators, run the gate over its DEPENDENTS too** — both break a file the diff never touched and a module-scoped gate sees neither; find them by searching for the CHANGED name, not the new one. **For changed `.sh` files: `shellcheck <file>`.** Then a per-AC coverage check: locate the test for each AC and show a `| # | Criterion | Test / Verification | Status |` table (one row per AC). On ALL PASS → Step 9.5. Full list: [reference.md § Step 9 — verify list (full)](reference.md#step-9--verify-list-full).

**Write progress:** rewrite `**current_step:**` to `Step 9 — Verify (ALL PASS)`; rewrite `**last_passed_gate:**`; append a `## Decisions log` bullet.

### Step 9.5: Update documentation

Update content files only — **do not move spec/design to `done/` yet** (Step 12). Touch `ai-docs/context.md` (new entity / open question) as applicable. Detail: [reference.md § Step 9.5 — documentation update (detail)](reference.md#step-95--documentation-update-detail). **Write progress:** rewrite `**current_step:**` to `Step 9.5 — docs updated`; append a `## Decisions log` bullet.

### Step 10: Self-review loop (max 3 rounds)

> **If a session directive forbids spawning Subagents and the user has not asked for one**, surface the conflict HERE rather than pushing with the gate silently omitted or spawning in defiance of it: name the step, say what an inline pass does and does not cover, and let the user choose. A gate that did not run is reported as **skipped**, never as passed ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Workflow](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#workflow), same row; recipe in `/bugfix` Step 1).

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
- **After round 3 with REJECT:** surface remaining `⬜ Open` findings to the user and ask how to proceed. **Fixes made after the cap is burned still get one review pass**, exactly as post-push fixes do — a burned cap ends the loop, not the gate. **If the user authorises finalising with findings still open, write `**current_step:**` = `Step 10 — cap burned, user authorised finalise (Round N)` and list those findings in a `## Decisions log` bullet.** That value is the only other thing Step 12's gate admits, and it exists so the override is a recorded fact rather than an inference from the orchestrator having reached the commit step; without it a burned cap could not reach Step 12 at all.

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
> | `*.design.md` under `ai-docs/plans/`, and the divergence **breaks the agreed approach** | **STOP.** Trigger Design Amendment — surface, update design, re-run Step 7 (max 3 rounds), then resume Step 11. Mark originating finding `✅ Fixed (design amended)`. |
> | `*.spec.md` under `ai-docs/plans/`, and the divergence **breaks the agreed approach** | **STOP.** Trigger Spec Amendment — surface, update spec, re-run Step 6 → Step 7, then resume Step 11. Mark `✅ Fixed (spec amended)`. |
> | Either artefact, and the divergence does **not** break the agreed approach | **No stop, and no re-run.** The plan row carries `redline: <type> — <what shipped instead>` with the sentence quoted in its Arm A cell; the round's one marking pass appends the marker and promotes the row; the code fix for that finding is applied in the same round. Mark `✅ Fixed (redlined)`. |
> | Neither arm fires — no artefact claim at stake, fix touches only source / build manifests / non-`ai-docs/plans/` `*.md` | Normal Step 11 code-fix path — hand it to the scouted-plan sequence below, which plans, gates and applies it. The orchestrator itself never edits. |
>
> **CLOSING GATE — a finding that fired Arm A may not be marked `✅ Fixed` until the cited sentence has been RE-READ in its file and either (a) confirmed true of the post-fix state, or (b) amended.** Record which. Shipping the thing a sentence promised makes the sentence true only if the shipped thing does what the sentence says it does.
>
> **Why Arm A exists, and the shape that defeats a diff-keyed table:** [the procedure page](${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md#rationale-moved-out-of-the-always-loaded-step-text).

> **AXIOM — Scouted-plan sequence (binding).** The orchestrator NEVER applies a review fix in its own context — **every** round carrying at least one `⬜ Open` finding (including a round whose one finding is a single-line `nit`) runs all five beats, with no size-based or severity-based carve-out and no per-round discretion to skip them:
>
> `baseline` (orchestrator, 1 call) → **plan** (`fix-scout`, fresh context, fills the stub's table) → `plan` gate (orchestrator, 1 call) → **mark** (`design`, fresh context, **once** per round carrying a `redline:` row, and skipped entirely when none does) → **apply** (`fix-apply`, fresh context, `fix` rows only) → **the post-apply micro-loop** (beat 5 below).
>
> **The marking beat runs BEFORE the apply, and the order is load-bearing.** One invocation marks every item the round's rows name — never one per divergence, never deferred to the closing redline fold. Why that order: [the procedure page](${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md#rationale-moved-out-of-the-always-loaded-step-text).
>
> Both gate calls are `"${CLAUDE_SKILL_DIR}"/scripts/check-fix-plan.sh <verb> <progress-file>`. **Read the `decision=` token, not the exit status** — one status covers five decisions:
>
> | `decision=` | Orchestrator's next move |
> |---|---|
> | `PASS` | spawn `fix-apply`. |
> | `REFUSE` | hand the verdict back to `fix-scout` for a rewrite; max 3 rounds, then surface to the user. |
> | `ROUTE-SPEC` / `ROUTE-DESIGN` | **STOP.** The Arm A / Arm B table above owns it; no fix agent runs this round. |
> | `ESCALATE` | surface to the user with the declared total and the threshold the verdict carries. |
>
> **Three acts never leave the orchestrator:** the user's consent on any escalation or on a `major` / `blocker` objection, routing into a Spec or Design Amendment, and confirming the write landed (mtime + `grep`) once `fix-apply` returns.
>
> **BEAT 5 — the post-apply micro-loop. Unconditional: after the apply, before the full review pass, every round.**
>
> 1. **The mechanical check** — `check-fix-plan.sh applied <progress-file>`. **Two arms, and the `reason=` token names which one fired** — `unplanned-file` when the diff touched a file no `fix` row named, and `redline-undelivered` when a `redline:` row's marker did not reach the design or its row did not reach the log, naming which key is missing from which file. **A token this page does not name is a documentation defect, never an unknown verdict** — the arms are whatever the gate prints. `redline-undelivered` has exactly one remedy: another marking invocation for the named keys, then this check again. **That corrective invocation COMPLETES the round's one marking pass rather than being a second one**, so the once-per-round bound above is satisfied, not broken, by finishing a pass that did not land. The round's changed-line total is reported as a plain **measurement** and nothing fires on it — the post-apply size arm and its `actual-overrun` token are withdrawn. A path matching `ai-docs/plans/*.spec.md` or `ai-docs/plans/*.design.md` — the two suffixes the routing arms key on, not the whole directory — is excluded from the `unplanned-file` arm and NAMED on the verdict's `excluded-in-round` line instead, because an approved amendment's writes are not the fix round's work and the diff cannot tell them from a rogue edit: **whenever the verdict carries that line, the orchestrator reads it and accounts for every named path against the amendment it knows it ran; a named path it cannot account for is a finding.**
> 2. **ONE bounded question**, spawned once, on **exactly three inputs** — the round's own plan section, the applied change, and beat 1's list of files no row named. Nothing else: not the findings table, not the spec, not the session history. It asks whether what was done matches what the plan said, **naming the row and the divergence**. Output: **exactly one of `MATCH` or `DIVERGE`, plus a reason**; an answer outside that two-word set is **refused, not interpreted** — the `record` verb's `<answer>` argument computes that refusal. It may not edit, may not re-run the fix, and decides no rework.
> 3. **On `DIVERGE`** — re-spawn `fix-apply` with that divergence named and nothing new. **Cap three attempts, counted in the round's plan section**, one bullet per attempt written before the re-spawn: `- attempt 2 — finding 5, row 1: <the divergence named>; re-fix dispatched`. **It must NOT begin with `|`** — the gate reads any pipe-leading line in that section as a plan row and refuses the whole plan under `plan-row-malformed`.
> 4. **On a burned cap** — surface to the user, in this fixed shape: which row (finding number and `Target`), what diverged (quoted from the question, not re-derived), the attempts and what changed between them, and **exactly one** of `re-fix` / `amend-the-plan` / `accept` with one sentence of why. It recommends; the user decides.
> 5. **The full review pass runs either way** — a burned cap ends the LOOP, not the gate.
>
> **Then record the loop, once, as it closes:** `check-fix-plan.sh record <progress-file> <iterations> <cost_tool_calls> <answer>`. All three are required and none defaults; `<answer>` is the question's own word, `MATCH` or `DIVERGE`, and the cost is the number of orchestrator tool calls the loop consumed. That row is what this loop's own retirement is read from.
>
> Spawn prompts, the plan format, the reason-token vocabulary and the narrative behind each beat: [`${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md`](${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md).

Every `⬜ Open` finding in the latest `## Self-Review (Round N)` section carries **at least one** row in the round's plan, each with one disposition from the closed six — `fix`, `object: <reason>`, `resolved: <reason>`, `amendment: spec`, `amendment: design`, `redline: <type> — <what shipped instead>` — and a finding may hold several rows when its remedy spans several files. The gate refuses a plan that omits a finding, and one that raises a row the review never raised. Statuses are marked only after the applied diff has been gated.

After all findings resolved, run gates (`%BUILD_CMD%`, `%TEST_CMD%`, `%FORMAT_CMD%` to format then `%LINT_CMD%` as the gate), then:

1. Update `.progress.md`.
2. **PR body sync (unconditional):** if a PR is open (`gh pr view --json title,body`), re-read the PR body, edit only if it contradicts new commits (`gh pr edit`).
3. **Resolve fixed review threads (unconditional)** per `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR review comment resolution`.
4. **Write progress:** rewrite `**current_step:**` to `Step 11 — review fixes complete (Round N)`. Return to Step 10.

### Step 12: Finalise docs, surface staged commit

1. **Step-skip gate.** Read `**current_step:**`. MUST be `Step 10 — self-review APPROVE (Round N)` or `Step 10 — cap burned, user authorised finalise (Round N)`. Else **STOP**, surface the gap, loop back to the missing step. No "too simple" exemption. **`Step 11 — review fixes complete (Round N)` is NOT admissible and used to be** — it means fixes were applied and the review has not been re-run over them, which is why Step 11 ends by returning to Step 10. Both admissible values mean the review question is settled: one by a verdict, one by the user overriding it in writing. A compaction landing between Step 11's write and its return is exactly how the inadmissible state reaches this gate, so read the value rather than inferring the step from how far the work looks done.
2. **Confirm `.progress.md` is NOT staged.** Gitignored (`ai-docs/plans/**/*.progress.md`); should not appear in `git status`. If accidentally tracked, unstage.
3. Confirm the branch is not the default one. Otherwise stop and apply recovery ([`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Recovery`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#recovery-from-accidental-edits-on-the-default-branch)).
4. **Move plan files:** `git mv` spec/design — and `<spec-base>.redline.md` if the task wrote one — to `ai-docs/plans/done/`.
5. `%BUILD_CMD% <module-path>` — sanity build before staging.
6. **Surface to user (Claude doesn't commit unasked):** the stage-list (impl files from `git diff --name-only <base_commit>`, `ai-docs/context.md` if touched, `ai-docs/learnings/` if this task wrote an entry — and `ai-docs/learnings.md` only if the archive itself changed, spec/design now in `done/`) and the suggested commit message. When the project uses ticket keys, the `<TICKET-KEY>:` title prefix is mandatory. Stats lines belong in the commit body, NOT the PR body. Full template: [reference.md § Step 12 — PR-body template (detail)](reference.md#step-12--pr-body-template-detail).
7. **Write progress:** rewrite `**current_step:**` to `Step 12 — staged for user commit`; append a `## Decisions log` bullet.
8. After the user confirms the commit + `git push -u origin <branch>` (the `pr-body-sync` reminder hook fires on push): open the PR (`gh pr create --title "<TICKET-KEY>: <header>" --body-file <file>`) with the user's approval; capture the PR number. **Record it into the progress file's `**PR:** #<id>` field the moment the PR exists** — a later fix round reads that line first, and without it the PR has to be re-derived from the branch (`/pr-merged` works from the branch name and does not read it). Pass the body via `--body-file` when it contains characters a shell would mangle ([`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#hook-false-positive-guard--body-content-matching-any-pretooluse-bash-regex)).

**Reviewer comments and CI failures arrive after Step 12** — handle them as a post-push fix round per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Post-push fix commits get self-review too`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#post-push-fix-commits-get-self-review-too). Do not re-enter `/task` for routine reviewer feedback; architectural-rework requests are the exception.

---

## Gate checklist

Each gate is enforced inline as the **First action** of its step; the consolidated per-step recap table lives in [reference.md § Gate checklist](reference.md#gate-checklist).

## Patterns

Validated approaches `/task` should keep applying (carrot signals; soft verbs) — a pointer list, never a second statement of a rule: [reference.md § Patterns](reference.md#patterns). The heading stays here because other skills reference it.

## FORBIDDEN

Skipping Step 7 design-review; skipping Step 10 self-review on "too simple" tasks; writing code before confirmed spec (Steps 1–5); declaring done without Step 9; editing on the default branch without recovery; silently implementing a design deviation (must trigger Design Amendment). Expanded list: [reference.md § FORBIDDEN](reference.md#forbidden).

---

**Reference:** [`reference.md`](reference.md) — per-section detail (linked inline above).
