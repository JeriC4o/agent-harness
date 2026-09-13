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

- `SessionStart`
- `PreToolUse`
- `PostToolUse`
- `Notification`
- `Stop`
- `SubagentStop`
- `PreCompact`

Matchers are tool names (Edit, Write, Bash, …); hook commands MUST NOT name themselves with these reserved event-name words.

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

### Project-defined Hooks

Defined in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`:

- SessionStart — rules-load reminder
- PreToolUse(Bash) — broad `find` / `grep -r` over `$HOME` blocker
- PreToolUse(Bash) — `branch-protection`: blocks `git commit` / `git push` on the default branch, with the recovery recipe in its message
- PreToolUse(Bash) — `auto-stage-learnings`: stages `ai-docs/learnings.md` **and** the `ai-docs/learnings/` directory on `git commit` (two independent `git status` probes, so a first-write untracked per-branch file is staged too)
- PreToolUse(Bash) — `co-authored-by`: blocks a `Co-Authored-By` trailer in a `git commit` message (`-m` string or `-F` file)
- PreToolUse(Bash) — `diff-range-guard`: warns when a gate is built on `git diff <base>...HEAD` on a branch with no commits yet (empty diff at rc=0 → silent pass); points at `git diff <base>` for the working-tree form
- PreToolUse(Bash) — `config-search-gate`: blocks a content search whose file filter can match an ASK-gated deployed-config file. Catches an explicit `.properties` filter/path and a recursive search rooted in a resources dir; does NOT catch a bare unfiltered search whose pattern happens to match a config key, so a clean run is not clearance
- PreToolUse(Bash) — `gate-pipe-guard`: blocks a gate (build / test / lint / format / `shellcheck`) whose result is MASKED — piped into `head`/`tail`/`grep`/`jq`/`sed`/`awk`/`wc`/`cut`/`sort`/`uniq`, fused to a trailing `|| echo` / `|| true`, or `;`-joined behind an `echo`/`printf` banner. Carve-outs pass: a `cd <dir> &&` prefix, a `[ -n … ] &&` guard that does not swallow the rc, and any chain inside a hook or checked-in `.sh`. **The gate match is anchored at COMMAND POSITION** (start of string, or after `;` `&` `|` `(` `` ` ``), so a gate name inside a search pattern — the project's own propagation sweep — is not a gate invocation and is not blocked. Newlines are normalised to `;` before matching, so a gate piped across a line break is still caught. There is NO heredoc opt-out: prose that quotes a piped gate at the start of a line is blocked like any other, and the remedy is the `Edit` / `Write` tools per `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`
- PreToolUse(Edit|Write) — Propagation Rule reminder on AGENTS.md / skill / agent / rules edits
- PreToolUse(Edit|Write) — `archive-protection-reminder`: advisory nudge when a write ADDS a `### ` header to `ai-docs/learnings.md`, pointing at `ai-docs/learnings/<username>-<branch>.md`. Counts headers before vs after, so a field-only edit and a whole-file rewrite stay silent. Never blocks (`exit 0`) — the `/improve` fold passes through
- PostToolUse(Write|Edit) — `learnings-append-check`: warns when a new Learning Log entry did not land last in its file
- PostToolUse(Bash) — PR-body-sync reminder on `git push` to a feature branch

> **Not configured, but expected per project:** a `PostToolUse(Write|Edit)` formatter hook running `%FORMAT_CMD%` on changed source files. Add it once the project's formatter command is filled in (`AGENTS.md § Build & Test`).

## Skill-usage priority

When more than one installed skill can serve a task, pick the highest tier that can do the job. Tie-breaker for ad-hoc selection only — does NOT override a harness skill that invokes a specific skill by name. Codified rule: `AGENTS.md § Tooling → Skill-usage priority`.

**This project installs no external skill tiers.** Populate the table below when it does; leave it empty otherwise, and fall back to the built-in tools.

| Tier | Source | Skills |
| --- | --- | --- |
| — | — | _(none yet)_ |

When a tier is populated, two rules carry over from the pattern this table replaced:

- **Establish "a skill isn't installed" with a directory listing (`ls -la ~/.claude/skills`), never with a file-content walker** — skills are often symlinked DIRECTORIES, and `rg --files` / `find` without `-L` do not follow them, so absence from that output is absence of evidence, not evidence of absence.
- **Falling back to a raw route (a hand-rolled REST call, the browser) silently changes the authority surface.** If the preferred route itself fails, report THAT concrete failure rather than routing around it.

## Maintenance

When Claude Code adds a new embedded name, `/ai-audit` Phase 2 surfaces the clash if any project surface uses it. Update §§1a/1b/2a/3a/3b in the same PR that resolves the clash. Project-defined renames must propagate (Propagation Rule fires).
