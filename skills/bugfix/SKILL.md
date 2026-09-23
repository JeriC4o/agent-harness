---
name: bugfix
description: "Reactive bug-fixing workflow. Trace → Root cause → Failing test → Fix → Self-review. Prevents the fix-break cycle."
when_to_use: "Activate on: 'not working', 'broken', 'wrong', 'incorrect', 'doesn't show', unexpected exception/error, failing test that should pass. Divergence signal: 'expected X got Y'. During implementation: 'this is wrong', 'overengineered', 'not what I meant'. Regression: 'broke again'. SKIP for general questions, codebase exploration, known/planned limitations."
argument-hint: "[bug description]"
allowed-tools: Bash(git rm:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(rm:*), Bash(grep:*), Bash(ls:*)
---

Reactive bug-fixing workflow. **Fundamentally different from `/task`:**
- First step is analysis, NOT code.
- Failing test is written BEFORE the fix.

> ⛔ **Do NOT open Edit, do NOT write code until Step 2 (Root Cause) is complete.**

> **⚡ Compaction recovery check — read FIRST on every invocation.**
> If you are re-entering this skill after auto-compaction (summary block at top of context, or workflow context feels thin), STOP before any tool call and:
>
> 1. **Locate the durable-state file** — `ls ai-docs/bugfix/trace-*.md 2>/dev/null`. One match → durable state. None → fresh invocation. Multiple → surface to user.
> 2. Read it **top-to-bottom in one pass**. Recorded `current_step` is a cross-check, never an instruction to skip the read.
> 3. **Re-enter this skill from the top of its body.** Resume logic uses `current_step` (after the full read) to skip user-confirmed checkpoints — if `Confirmed by user: ✅ YES` is present, do NOT re-run Step 1's reproduce-and-trace user-confirmation.
>
> See `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md § Compaction recovery (re-entry)` for canonical rationale.

---

## Step 1: Reproduce and Trace

> **Re-entry-after-compaction case.** If a trace file at `ai-docs/bugfix/trace-*.md` exists, read it top-to-bottom. Then:
>
> | Trace state | Action |
> |---|---|
> | `Confirmed by user: ⏳ PENDING` (or missing) | Re-execute Step 1 normally — trace created but user never confirmed. |
> | `Confirmed by user: ✅ YES` AND `**current_step:**` ≥ Step 2 | **Skip Step 1**. Resume from `**current_step:**`. Do NOT re-trace, do NOT re-ask the user. |
> | Multiple matching trace files | Surface to user; do NOT auto-pick. |

**Goal:** understand the exact sequence of events.

> **⛔ BEFORE ANY FIX: DATA FIRST, THEN CODE.**
> Code shows what CAN happen. Data shows what DID happen.

Spawn the `Explore` Subagent via the `Agent` Tool to trace the actual execution path. `Explore` is read-only; the orchestrator writes the trace artefact from `Explore`'s output. Full prompt: [reference.md § Explore subagent prompt (Step 1 trace)](reference.md#explore-subagent-prompt-step-1-trace).

> **If a session directive forbids spawning Subagents, surface the conflict HERE, at Step 1** — name the affected step, say what an inline pass does and does not cover, and let the user choose. Do NOT silently substitute an inline trace and raise the question later when Step 6.5's more visible AXIOM forces it. A user invoking `/bugfix` is weak evidence of consent to its internal Subagents; an explicit session directive is strong evidence against — only the user breaks that tie.

**Inner steps:**

> **A reproduction is complete when it varies the INPUT, not the COMMAND.** Before recording the trace, name the axis the code BRANCHES on and cover BOTH sides of it — for a path-resolution bug, one fixture that also resolves at the other candidate location and one that does not; for a fallback, one value that hits it and one that does not; for a collision/dedup path, one colliding key and one unique. A wide matrix over a single fixture measures the command surface and hides half the failure modes. And when the trace is about to claim a wrong form "fails loudly", prove it cannot ALSO fail silently — a tool that answers a bad argument with empty output and rc=0 turns every gate built on it into a silent pass.

1. Create artifact `ai-docs/bugfix/trace-YYYY-MM-DD-<short-name>.md` per the schema in [reference.md § Trace artifact schema (Step 1)](reference.md#trace-artifact-schema-step-1).
2. Show the trace to the user and ask: **"Did I understand the behaviour correctly?"**
3. After confirmation — update: `Confirmed by user: ✅ YES`.
4. **Write progress at this step boundary:** rewrite `**current_step:**` to `Step 1: Reproduce and Trace — confirmed`; append a `## Decisions log` bullet recording the divergence point.
5. **Do NOT proceed to Step 2 until the user confirms the trace.**

---

## Step 2: Root Cause

> **First action:** `Read ai-docs/bugfix/trace-*.md`. If missing — go back to Step 1.

Find the single point of failure.

**Rule:** root cause is **one place** where behaviour diverges from the component's contract. Multiple candidates → those are symptoms; dig deeper.

1. Read only files involved in the trace.
2. Find the line where the contract is violated.
3. State: `"Root cause: ClassName.method() in path/Foo.kt line N — does X instead of Y"`.
4. Append to the trace:

   ```markdown
   ## Root Cause
   `ClassName.method()` in `path/Foo.kt` line N — does X instead of Y
   Confirmed by user: ⏳ PENDING
   ```

5. Show root cause to user. After confirmation → `✅ YES`.
6. **Write progress:** rewrite `**current_step:**` to `Step 2: Root Cause — confirmed`; append a `## Decisions log` bullet recording the location.

---

## Step 3: Failing Test (REQUIRED, before Edit)

> ⛔ **Step 5 (Fix) is BLOCKED until the test is red.**

**Checklist:**

- [ ] Test written with the same data as the bug report.
- [ ] Test run: `%TEST_CMD%` filtered to the new test only.
- [ ] Test is **RED** with the expected error (not a compile error — an assertion fail).
- [ ] Only after a red test → Edit.

**Test must:**

- Follow `AGENTS.md § Test Conventions` and the project's fixture/mocking conventions in `ai-docs/context.md`.
- Verify an invariant (comment out the fix → test fails).
- Be named as a behaviour description: `should return error when input is empty`.

**If the test does NOT fail:**

- You didn't find the root cause → go back to Step 2.
- OR assertion is too weak → rewrite the assertion.
- ⛔ Do NOT proceed to fix while the test is green.

**Write progress:** rewrite `**current_step:**` to `Step 3: Failing Test — red`; rewrite `**last_passed_gate:**` to `%TEST_CMD% <args> (RED as expected) | <UTC timestamp> | <git rev-parse HEAD>`; append a `## Decisions log` bullet recording the test name + invariant.

---

## Step 4: Plan + Regression Check

Before Edit, make a plan:

1. What exactly to change (file, method, ~lines).
2. What might break (adjacent components).
3. Which existing tests cover adjacent code — run them.

**Show plan to user if:**

- Change touches >1 file.
- You're changing the same file for the second time in a row (loop signal).

**Write progress:** rewrite `**current_step:**` to `Step 4: Plan + Regression Check`; append a bullet recording the planned change scope.

---

## Step 5: Fix

Now open Edit.

**Site-count rule:** if the fix requires changes in >3 **behaviour-change sites** → you're fixing a symptom. STOP, go back to Step 2.

> **Count sites, not files — and state the count at the Step 4 plan, not retroactively at review.** Say it in BOTH forms: "N files, but M behaviour-change sites"; proceed only when M ≤ 3. NOT behaviour-change sites: mechanical call-site / mock-matcher churn forced by one signature change, a class extracted from that same fix, and its config surface (enum + property). If M > 3, STOP as written — this gate is unconditional, not advisory, and recording the reasoning in the trace is not a substitute for stopping.

**One-attempt rule:** if a new bug appeared in the same place after the fix → STOP. Draw a full system diagram, show it to the user.

**Write progress:** rewrite `**current_step:**` to `Step 5: Fix`; append a bullet recording file(s) and lines touched.

> **Spec Amendment trigger — two arms, and the subject arm comes first.** **(A)** Would closing this finding leave a sentence in a `*.spec.md` / `*.design.md` untrue? **(B)** Does the fix diff touch one under `ai-docs/plans/`? Either is a Spec/Design Amendment, not an ordinary fix — A fires even when the fix lands entirely in code, and a finding that fired A is not closed until the cited sentence is re-read and either confirmed or amended. STOP and route through [`/task` § Spec Amendment recipe](../task/SKILL.md#spec-amendment-recipe), then resume here. Full rationale: [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § Spec-Amendment group](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#spec-amendment-group).

---

## Step 6: Verify

1. Run the failing test from Step 3 — must turn green.
2. Run the full module: `%TEST_CMD% <module-path>` — confirm nothing else broke. Read the result per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Reading a test result`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result), not by exit code.
3. `%FORMAT_CMD%` on changed files to format, then `%LINT_CMD%` as the gate.
4. **Write progress:** rewrite `**current_step:**` to `Step 6: Verify — green`; rewrite `**last_passed_gate:**` to `%TEST_CMD% <module-path> | <UTC timestamp> | <git rev-parse HEAD>`; append a bullet recording any non-trivial regressions caught.

> ⛔ **Do NOT delete the trace artifact yet — Step 6.5 still needs it as the spec-equivalent input for `self-review`.**

---

## Step 6.5: Self-review (loop, max 3 rounds)

> ⛔ **`/bugfix` cannot report Step 6 as complete and proceed to commit until self-review issues APPROVE.** A `/bugfix` PR has the same bar as a `/task` PR — build/test/lint gates don't catch "this magic number should be a named constant", "this doc-comment contradicts the fix", "this fix touches a sibling concern that should be a separate PR".

1. Determine the diff window:
   - **Standalone `/bugfix`** (user bug report entry): `<base>` = `git merge-base origin/main HEAD` (no commits yet on branch) or `HEAD~N` against the pre-fix tip when N local commits exist.
   - **`/bugfix` invoked from `/task` Steps 8–12**: diff window is the bugfix's staged-but-not-pushed commits.

2. Spawn `self-review` — full prompt: [reference.md § self-review subagent prompt (Step 6.5)](reference.md#self-review-subagent-prompt-step-65).

3. **On APPROVE:** proceed to Step 7. **Write progress:** rewrite `**current_step:**` to `Step 6.5: Self-review — APPROVE (Round N)`.
4. **On REJECT:** loop back to Step 5 — address each `⬜ Open` finding. After fixes, return for Round N+1. Rewrite `**current_step:**` to `Step 6.5: Self-review — REJECT (Round N), addressing findings`.
5. **After Round 3 with REJECT:** STOP. Do not commit. Surface remaining findings to the user.

---

## Step 7: Cleanup (only after Step 6.5 APPROVE)

1. **Delete the trace artifact:** `rm -f ai-docs/bugfix/trace-*.md` (the file is gitignored, so no `git rm` is needed unless it was deliberately tracked).

---

## ⛔ Anti-pattern: fix-break cycle

If you suspect a fix-break loop (similar symptom reported twice, same file changed >2 times, user asks "why did you decide to do it that way?"): STOP, close all Edits, draw a full system diagram, show it to the user, and wait for confirmation before continuing. Full detail: [reference.md § Anti-pattern: fix-break cycle](reference.md#anti-pattern-fix-break-cycle).
