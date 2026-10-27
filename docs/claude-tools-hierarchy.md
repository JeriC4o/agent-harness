# Claude tools hierarchy

Embedded inventory of Tool / Subagent / Skill / Hook names. Consumed by `/ai-audit` Phase 2 Checklist O to detect clashes between project-defined names and Claude Code's embedded names.

> **AXIOM — Project-defined names MUST NOT clash with embedded names. On clash, the project name is renamed; the embedded name is never renamed.**

## §1a — Embedded Tools (built-in)

Names reserved by Claude Code's built-in tool set. Project-defined tool aliases that shadow these are forbidden.

- `Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `WebFetch`, `WebSearch`
- `TaskCreate`, `TaskUpdate`, `TaskGet`, `TaskList`, `TaskOutput`, `TaskStop`
- `NotebookEdit`
- `Agent`, `AskUserQuestion`
- `EnterPlanMode`, `ExitPlanMode`, `EnterWorktree`, `ExitWorktree`
- `Skill`, `CronCreate`, `CronList`, `CronDelete`, `ScheduleWakeup`

## §1b — MCP servers (this project)

**None configured.** There is no project `.mcp.json`, so the harness exposes no `mcp__<server>__<tool>` tools. When a project adds one, enumerate its servers here — an MCP server name is as reserved as an embedded tool name, and a project-defined skill MUST NOT shadow one.

## §2a — Embedded Subagent types

Names exposed by the `Agent` tool's `subagent_type` parameter at the harness level:

- `claude` (catch-all)
- `claude-code-guide`
- `Explore` (read-only search)
- `general-purpose`
- `Plan`
- `statusline-setup`

## §3a — Embedded Skills (user-invocable)

The full list lives in the session's available-skills system reminder — read it there rather than trusting this file, which is a snapshot. Project-defined skills under `.claude/skills/` MUST NOT shadow any of them. Names seen in recent harness builds: `claude-api`, `init`, `code-review`, `security-review`, `update-config`, `keybindings-help`, `simplify`, `fewer-permission-prompts`, `loop`, `schedule`, `run`, `artifact-design`, `dataviz`, `self-review` (embedded).

> **Note — `self-review` clash carve-out.** Claude Code carries an embedded `self-review` skill. The project-defined `self-review` at `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` is a **Subagent**, not a skill — the surface differs (skill = `Skill` tool invocation; Subagent = `Agent` tool spawn). The clash is type-mismatched and tolerated. If a future Claude Code release introduces an embedded `self-review` Subagent, the project Subagent must be renamed.

## §3b — Embedded Hook event names

- `SessionStart`, `Setup`, `SessionEnd`
- `UserPromptSubmit`, `UserPromptExpansion`
- `PreToolUse`, `PermissionRequest`, `PermissionDenied`
- `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`
- `Notification`, `MessageDisplay`, `Elicitation`, `ElicitationResult`
- `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`
- `Stop`, `StopFailure`
- `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`
- `WorktreeCreate`, `WorktreeRemove`
- `PreCompact`, `PostCompact`
- `PreModelSwitch`, `PostModelSwitch`

Matchers are tool names (Edit, Write, Bash, …); hook commands MUST NOT name themselves with these reserved event-name words.

> **This list is a SNAPSHOT and it went badly stale once.** It carried 7 names while the documentation defined 33 — and because `/ai-audit` Checklist O compares project-defined names against exactly this list, the missing 26 were names a clash check could never have caught. Two of them, `PostToolUseFailure` and `PostToolUse`, turned out to be the pair that makes a call outcome knowable at all, so the gap cost a capability as well as a check. Re-read the documentation rather than this file when the answer matters, and refresh here when it differs. **One name on this list has been exercised rather than copied:** `SubagentStart` was wired as a hook and its payload read off stdin on `claude-code 2.1.273`, which is how the pair of fields the published docs list but the client does not send (`permission_mode`, `scratchpad_dir`) was found. A name appearing here says the event exists, never that a given field arrives on it.

## Project-defined names (project surface)

Kept here so the audit can compare both sides without grepping the whole tree on every run.

### Project-defined Subagents

- `spec-writer`
- `design`
- `design-review`
- `self-review` (project; clash-tolerated — see §3a note)
- `self-improve`
- `learnings-escalation-audit`
- `review-findings`
- `inspector` (judges a reduced session event stream for harness defects)
- `fix-scout` (writes a review round's fix plan into the section the gate reads)
- `fix-apply` (applies the gate-passed plan's fix rows and nothing else)
- `plan-convergence` (reports where a plan pair contradicts itself or an artefact; issues no verdict)

### Project-defined Skills

- `task` (orchestrator)
- `interview`
- `bugfix`
- `context-reset`
- `improve`
- `ai-audit`
- `pr-merged`
- `project-review`
- `harness-init` (scaffolds the project profile + registers the project)
- `improve-global` (cross-project sweep over promotion candidates)
- `inspect` (session analysis for workflow loops)
- `report-defect`
- `redline-fold`

### Project-defined Hooks

Registered in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`. **The names are here; each hook's behaviour is on
[`${CLAUDE_PLUGIN_ROOT}/docs/hook-inventory.md`](${CLAUDE_PLUGIN_ROOT}/docs/hook-inventory.md)** — what it
matches, what it deliberately does not, where it fails open, and which bounds were measured. A clash check
needs only this index; anything about what a hook DOES needs that page.

A hook marked **[guarded]** no-ops in a repo with no harness profile. An unmarked one encodes pure method
and holds in every repo, which is why it carries no guard.

| Event | Name | |
|---|---|---|
| SessionStart | rules-load reminder | [guarded] |
| PreToolUse(Bash) | broad `find` / `grep -r` over `$HOME` blocker | |
| PreToolUse(Bash) | `branch-protection` | [guarded] |
| PreToolUse(Bash) | `auto-stage-learnings` | [guarded] |
| PreToolUse(Bash) | `co-authored-by` | [guarded] |
| PreToolUse(Bash) | `diff-range-guard` | |
| PreToolUse(Bash) | `config-search-gate` | |
| PreToolUse(Bash) | `gate-pipe-guard` | |
| PreToolUse(*) | `loop-index` | |
| PreToolUse(Edit\|Write) | `propagation-rule-reminder` | [guarded] |
| PreToolUse(Edit\|Write) | `archive-protection-reminder` | |
| PreToolUse(Skill) | `skill-gate` | |
| PostToolUse(Write\|Edit) | `learnings-append-check` | |
| PostToolUse(Write\|Edit) | `sh-syntax-check` | |
| PostToolUse(*), PostToolUseFailure(*) | `loop-result` | |
| PostToolUse(Bash), PostToolUseFailure(Bash) | `gate-record` | |
| Stop, SubagentStop | `loop-verdict` | |
| SubagentStart | `loop-agent-mark` | |

The ledger `loop-index`, `loop-result`, `gate-record`, `loop-verdict` and `loop-agent-mark` write — its one
unswallowed failure, its six record classes, and the view `/inspect` reads: [`${CLAUDE_PLUGIN_ROOT}/docs/loop-ledger.md` § The loop ledger](${CLAUDE_PLUGIN_ROOT}/docs/loop-ledger.md#the-loop-ledger).

> **Not configured, but expected per project:** a `PostToolUse(Write|Edit)` formatter hook running
> `%FORMAT_CMD%` on changed source files. Add it once the project's formatter command is filled in
> (`AGENTS.md § Build & Test`).

## Skill-usage priority

When more than one installed skill can serve a task, pick the highest tier that can do the job. Tie-breaker for ad-hoc selection only — does NOT override a harness skill that invokes a specific skill by name. Codified rule: `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling → Skill-usage priority`.

**This project installs no external skill tiers.** Populate the table below when it does; leave it empty otherwise, and fall back to the built-in tools.

| Tier | Source | Skills |
| --- | --- | --- |
| — | — | _(none yet)_ |

When a tier is populated, two rules carry over from the pattern this table replaced:

- **Establish "a skill isn't installed" with a directory listing (`ls -la ~/.claude/skills`), never with a file-content walker** — skills are often symlinked DIRECTORIES, and `rg --files` / `find` without `-L` do not follow them, so absence from that output is absence of evidence, not evidence of absence.
- **Falling back to a raw route (a hand-rolled REST call, the browser) silently changes the authority surface.** If the preferred route itself fails, report THAT concrete failure rather than routing around it.

## Maintenance

When Claude Code adds a new embedded name, `/ai-audit` Phase 2 surfaces the clash if any project surface uses it. Update §§1a/1b/2a/3a/3b in the same PR that resolves the clash. Project-defined renames must propagate (Propagation Rule fires).
