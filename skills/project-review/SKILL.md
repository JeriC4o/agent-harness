---
name: project-review
description: "Whole-codebase review on the current branch (or branch given as argument). Reads all source files and done plans, runs fix loop and self-review loop until APPROVE."
disable-model-invocation: true
argument-hint: "[branch-name]"
allowed-tools: Bash(git diff:*), Bash(git rev-parse:*), Bash(git checkout:*), Bash(git branch:*), Bash(git log:*), Bash(ls:*), Bash(grep:*)
---

Whole-codebase review workflow. Steps execute **strictly in sequence**.

> **⚡ Compaction recovery check — read FIRST on every invocation.**
> If you are re-entering this skill after auto-compaction (summary block at top of context, or workflow context feels thin), STOP before any tool call and:
>
> 1. **Locate the durable-state file** — run the preamble glob (`ls ai-docs/plans/*.progress.md 2>/dev/null`) and apply validation.
> 2. Once the probe identifies the correct `.progress.md`, read it **top-to-bottom in one pass**.
> 3. **Re-enter this skill from the top of its body** — let the preamble's probe/validation/RESUME sequence route control.
>
> See `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md § Compaction recovery (re-entry)` for canonical rationale.

## ⚡ First: check for active review

```bash
ls ai-docs/plans/*-project-review.progress.md 2>/dev/null
```

**If found → RESUME:**
1. Read the `.progress.md` file.
2. Jump to `## Next action`.
3. Tell user: "Found active review, resuming from [next action]".

---

### Step 1: Determine branch

- If `$ARGUMENTS` is non-empty: confirm the user wants to review that branch, then `git checkout $ARGUMENTS`.
- Otherwise: use the current branch (`git branch --show-current`).

Record `base_commit`:

```bash
git rev-parse HEAD
```

### Step 2: Spawn review Subagent

Create the progress file: `ai-docs/plans/YYYY-MM-DD-project-review.progress.md`. Header fields per `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`: `**Branch:**`, `**base_commit:**`, `**Last build:**`, `**current_step:**`, `**last_passed_gate:**`, plus `## Decisions log`. Initialise `**current_step:** Phase 1 — review-findings`.

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md and follow it exactly.
  Branch: [branch name]
  base_commit: [base_commit]
  Module path to review: <module-path>
  Write progress file to: ai-docs/plans/YYYY-MM-DD-project-review.progress.md
")
```

After the Subagent completes: read the progress file and report finding count + severity breakdown to the user.

**Write progress:** rewrite `**current_step:**` to `Phase 1 — review-findings complete`; append a `## Decisions log` bullet recording the finding count.

### Step 3: Fix loop

For each `⬜ Open` finding in the `## AC Status` table (top-to-bottom):

- **Fix it** → implement, mark `✅ Fixed`.
- **Object** (finding is wrong or intentionally out of scope):
  - `nit` / `minor`: may object autonomously — write reason, mark `⚠️ Objected: <reason>`.
  - `major` / `blocker`: **surface to user first** before objecting. User must approve.

After every 3 fixes (or when all findings in a subtask are resolved):

1. `%BUILD_CMD% <module-path>` — must compile.
2. `%TEST_CMD% <module-path>` — all green. "Green" is the parsed OUTPUT, never the exit code — a run that selected zero tests reports success. Prove selection by matching the reported count against a counted number of test methods. See [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` → Reading a test result](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result).
3. `%FORMAT_CMD%` on changed files.
4. Update `## Files touched` and mark subtask `[x]` in progress file.
5. **Write progress:** rewrite `**current_step:**` to `Phase 2 — fix loop (after N fixes)`; rewrite `**last_passed_gate:**` to `%TEST_CMD% <module-path> | <UTC timestamp> | <git rev-parse HEAD>`.

> **Spec/Design Amendment trigger.** If a fix diff touches a `*.spec.md` or `*.design.md` under `ai-docs/plans/` (including `done/`), STOP — that is an amendment, not an ordinary fix. Route through [`/task` § Spec Amendment recipe](../task/SKILL.md#spec-amendment-recipe), then resume the fix loop ([`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § Spec-Amendment group](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#spec-amendment-group)).

**Context handoff rule:** if finding count ≥ 10 and >half remain open, spawn a Subagent per subtask rather than working inline — pass the progress file path.

### Step 4: Final verify

1. `%BUILD_CMD% <module-path>` — PASS.
2. `%TEST_CMD% <module-path>` — all green. "Green" is the parsed OUTPUT, never the exit code — a run that selected zero tests reports success. Prove selection by matching the reported count against a counted number of test methods. See [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` → Reading a test result](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result).
3. `%FORMAT_CMD%` on every changed file to format, THEN `%LINT_CMD%` as the gate — must exit clean. The formatter is not the gate.
4. **Doc convention conformance.** Doc-comments are NOT mandatory — a public symbol with no doc-comment is correct, not a finding. **Asking for a comment to be ADDED (including a `@Suppress` justification) is a SUGGESTION, never a defect:** it carries no severity, never blocks, applies only with the author's agreement, and is voiced ONCE — never restated in a later round, reworded or re-severitied. Absence of a comment is the documented default, so "there is no justification here" is not a finding; an identical construct elsewhere in the same file carrying no comment settles it in the author's favour. Deliberately asymmetric with the rule below — DELETING narration stays `major`. **One CLOSED exception — the `@throws` mandate:** a public function asserting a precondition, throwing an argument/state exception, indexing without a bounds-check, or overflowing on plausible inputs MUST document it (`${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md § @throws requirement`), and its absence stays a finding even when the fn carries no doc-comment — that is the one place the documented default is a comment rather than none. It covers `@throws` only, never `@param` / `@return` / section order (those presuppose an already-warranted doc-comment, so they are not add-a-comment requests) and never a suppression justification. Flag narration doc-comments (restate the signature / narrate WHAT) as `major` per `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Comments` — read each doc-comment's OPENING sentence in isolation (an opening sentence restating the symbol name / type / signature / return is narration even when a genuine why follows: strip the opening sentence, not the whole comment), and treat a doc-comment on a brand-new symbol with extra suspicion (default-expect NONE; copying a precedent's structure does not justify copying its doc-comment). For doc-comments that ARE present (or that the `@throws` mandate warrants creating — `@return` does NOT warrant one, per `doc-convention.md:14`), verify the SHAPE against `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` (summary tense, `@param` / section order / `@throws` / `@return` where applicable). Overriding methods are exempt. Also flag any comment / provenance note that names a framework/library/tool, asserts an annotation's presence, claims an API field's absence/presence, or asserts storage-engine / concurrency behaviour ("this never waits", "`DO NOTHING` takes no lock") NOT confirmable against the source (imports / deps / schema) as `major` — false claims propagate as ground truth (`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Comments`); judge a DB/concurrency claim by its observable failure mode ("does it ever wait? does it ever enqueue?"), since a claim can be true about locks and false about queueing. `@throws <Type>` is the same claim class: a type originating in a framework/dependency that is not confirmable against the branch's own resolved dependency versions → `major` (a sibling type reads like a supertype, and a false tag invites a wrong `catch`); where a doc-comment and a design doc's analysis disagree, the doc-comment is the finding. Mechanical heading scan:

   ```bash
   grep -rnE '/\*\*|\* @(param|return|throws|sample|see)' <module-path>
   ```

5. Update progress file: `**Last build:** PASS`.
6. **Write progress:** rewrite `**current_step:**` to `Phase 3 — final verify (PASS)`; append a bullet recording doc-convention findings fixed.

### Step 5: Self-review loop (max 3 rounds)

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md and follow it.
  Progress: ai-docs/plans/YYYY-MM-DD-project-review.progress.md
  base_commit is recorded in the progress file.
  There is no spec or design doc — this is a review-driven task.
  Treat the findings table in ## AC Status as the acceptance criteria.
")
```

**On APPROVE:**

1. **Write progress:** rewrite `**current_step:**` to `Phase 4 — self-review APPROVE (Round N)`.
2. `%FORMAT_CMD%` on every changed file to format, then `%LINT_CMD%` as the gate (final pass).
3. Surface staged file list + suggested commit message to the user (Claude doesn't commit; the user does).
4. After the user confirms commit landed: delete `ai-docs/plans/YYYY-MM-DD-project-review.progress.md`.
5. Done.

**On REJECT:**

- Rewrite `**current_step:**` to `Phase 4 — self-review REJECT (Round N), addressing findings`.
- Fix each `⬜ Open` finding from the self-review section (same fix/object rules as Step 3).
- Return to Step 5.

**After round 3 with REJECT:** surface remaining `⬜ Open` findings to the user and ask how to proceed. Do not delete `.progress.md` until resolved.

## Gate checklist

| Before | Check |
|---|---|
| Step 2 | branch confirmed? base_commit recorded? |
| Step 3 | build green after every 3 fixes? |
| Step 4 | all four checks pass (build, test, lint, doc convention)? |
| Step 5 | self-review APPROVE before commit-surface? |
| Cleanup | `major`/`blocker` objections user-approved? progress file deleted? |
