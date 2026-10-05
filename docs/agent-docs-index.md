# Agent docs index — verbose row bodies

Companion to `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Agent Docs`. That table lists paths + one-line purposes; this file carries the writer / lifecycle / special-case notes for each row.

## Agent doc rows

### `ai-docs/context.md`

**Purpose.** Project context — entities, services, modules, tech stack, build/test commands.
**Writer.** User + `/improve` (after `/task` runs that introduce new domain entities).
**Lifecycle.** Append-mostly; the "Open questions" section may be edited as decisions land.
**When to read.** On demand only. Not auto-loaded.

### `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`

**Purpose.** Workspace code-style reference + the per-project language profile.
**Writer.** `self-improve` (on escalated `code-style` corrections); user (manual seed).
**Lifecycle.** Section-keyed; new rules append under the relevant section.
**When to read.** When the diff touches source files and the AGENTS.md `## Code Style` summary is insufficient.

### `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`

**Purpose.** Doc-comment convention reference.
**Writer.** `self-improve` (on `doc-convention` escalations).
**Lifecycle.** Section-keyed.
**When to read.** When the diff touches public API surface.

### `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md`

**Purpose.** Extracted Workflow narrative — PR-review-comment recipe, git/GitHub command map, explicit-file staging detail.
**Writer.** `self-improve` (on `process` escalations).
**Lifecycle.** Section-keyed.
**When to read.** When AGENTS.md `## Workflow` AXIOMs link out.

### `${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md`

**Purpose.** Learning Log field glossary + boundary-rule exceptions.
**Writer.** `self-improve` (rare — when a new `Escalated?` value or a new exception clause is introduced).
**Lifecycle.** Reference; updates are infrequent.
**When to read.** When writing a Learning Log entry whose `Kind:` / `Escalated?` / `Superseded by:` shape is unfamiliar.

### `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md`

**Purpose.** Binary-rule writing style — fail-loud AXIOMs for stick rules, soft `## Patterns` blocks for carrots.
**Writer.** `self-improve` (on writing-style escalations); `/ai-audit` Checklist M is the enforcer.
**Lifecycle.** Section-keyed.
**When to read.** When promoting a rule to AGENTS.md / a skill / an agent.

### `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`

**Purpose.** Embedded inventory of Tool / Subagent / Skill / Hook names so `/ai-audit` Checklist O can flag clashes.
**Writer.** `/ai-audit` Phase 2 (refresh) + user (when Claude Code adds an embedded name).
**Lifecycle.** Append + version stamp.
**When to read.** When naming a new project-defined skill / agent / hook.

### `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md`

**Purpose.** Audited list of `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` files exempted from the 200-line soft target.
**Writer.** `/ai-audit` Phase 2 Checklist K (after a user-approved exemption).
**Lifecycle.** Stable rows; line-count column refreshes per audit run.
**When to read.** When `/ai-audit` reports a SKILL.md size violation.

### `${CLAUDE_PLUGIN_ROOT}/docs/considerations-link-reading.md`

**Purpose.** Link-reading policy — when to follow a `[link]` vs skim.
**Writer.** User + `self-improve` (rare).
**Lifecycle.** Stable.
**When to read.** When a skill / agent body contains a reference link the Subagent must decide on.

### `${CLAUDE_PLUGIN_ROOT}/docs/instruction-file-validation.md`

**Purpose.** Dual-model instruction-file-clarity test methodology + bias taxonomy.
**Writer.** `/ai-audit` Phase 2 (when running validation passes).
**Lifecycle.** Stable.
**When to read.** When auditing an instruction file's clarity.

### `${CLAUDE_PLUGIN_ROOT}/docs/plans-summary.md`

**Purpose.** Cross-cutting maintenance plans bodies.
**Writer.** `/task` Step 12 (after plan completes).
**Lifecycle.** Append.
**When to read.** When `context.md` cites a cross-cutting plan by short name.

### `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`

**Purpose.** Canonical `.progress.md` schema spec.
**Writer.** `/improve` (when new fields are added to the schema).
**Lifecycle.** Stable.
**When to read.** When writing or reading any `.progress.md` file.

### `ai-docs/plans/*.spec.md` / `*.design.md` / `*.progress.md`

**Purpose.** Active task artefacts.
**Writer.** `spec-writer` (spec), `design` (design), `/task` Step 8 (progress).
**Lifecycle.** `*.progress.md` is gitignored, local-only; deleted by `/pr-merged`. `*.spec.md` + `*.design.md` move to `plans/done/` at Step 12.
**When to read.** During the active task.

### `ai-docs/plans/done/`

**Purpose.** Completed plans (spec + design).
**Writer.** `/task` Step 12.
**Lifecycle.** Permanent.

### `ai-docs/plans/deferred/`

**Purpose.** Blocked or spec-only plans.
**Writer.** `/interview` deferred path + `/task` "park" decisions.
**Lifecycle.** Moved back to `plans/` by `/task ⚡ Second` activation.

### `ai-docs/bugfix/trace-*.md`

**Purpose.** `/bugfix` trace artefact.
**Writer.** `/bugfix` Step 1.
**Lifecycle.** Deleted by `/bugfix` Step 7 on resolution.

### `ai-docs/learnings.md`

**Purpose.** Corrections-log ARCHIVE — the history half of the `/improve` feed, and the destination of `/improve`'s fold. **No NEW entry is authored here.**
**Writer.** `/improve`'s fold (appends folded per-branch files verbatim at EOF); `self-improve` for `Escalated?` / `Superseded by:` backfills.
**Lifecycle.** Append-only; never edited or deleted.

### `ai-docs/learnings/`

**Purpose.** Per-branch entry files, `<username>-<branch>.md` — where every NEW Learning Log entry goes. Read as one history with the archive: `ai-docs/learnings.md ai-docs/learnings/*.md`.
**Writer.** Any session that violates a rule or confirms a non-obvious protocol; `self-improve` for `Escalated?` / `Superseded by:` backfills.
**Lifecycle.** Append-only per file; a file is deleted only by `/improve`'s fold, once it is identical to the copy on the default branch.
**When to read.** Derivation of the filename: `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` § Target file. Directory contract + fold: `ai-docs/learnings/README.md`.

### `ai-docs/feedback/`

**Purpose.** Defect reports about the HARNESS ITSELF, drafted in a consuming project and filed upstream — one file per report, carrying Symptom / Repro / Expected / Surface / Evidence plus the installed harness version and an idempotency hash. Distinct from `ai-docs/learnings/`, which carries abstracted RULES: a report names a harness `file:line` and is never promoted as a lesson.
**Writer.** The report-drafting skill; never written by hand during ordinary work.
**Lifecycle.** Committed with the project — the local file is the evidence a filing had a source, and it survives a failed `gh` call so the text can be pasted manually. The directory is created on first use rather than scaffolded, since an empty directory cannot be committed.
**When to read.** Before filing, to see whether the same defect already went upstream.

### `ai-docs/fixtures/`

**Purpose.** Real inputs, captured once and frozen, that a gate replays so a detector is exercised against the thing it ships against rather than against a hand-written approximation of it. One subdirectory per corpus; each carries the input, any derived mapping, and a baseline file holding the MEASURED expectation plus the input's own checksum, so a regenerated fixture fails by name instead of surfacing as a detector regression.
**Writer.** The task that needs the corpus, once. A fixture is not refreshed as routine maintenance.
**Lifecycle.** Committed and long-lived. Anything captured from a real session is scrubbed before it lands — and the scrub is a gate in the replaying suite, not a step someone remembers, because the needle is usually present in more than one spelling. Changing a fixture means changing its baseline on purpose, in the same commit.
**When to read.** When a replay gate fails: read the baseline first, since it names whether the input or the detector moved.

