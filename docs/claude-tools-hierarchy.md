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
- `inspector` (judges a reduced session event stream for harness defects)

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

### Project-defined Hooks

Defined in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`. A hook marked **[guarded]** is prefixed with
`"${CLAUDE_PLUGIN_ROOT}"/hooks/lib/harness-managed.sh || exit 0` and no-ops in a repo with no harness
profile (no `ai-docs/` and no `AGENTS.md`) — it presupposes that profile. An unmarked hook encodes pure
method and holds in every repo, which is why it carries no guard.

- SessionStart — rules-load reminder **[guarded]**
- PreToolUse(Bash) — broad `find` / `grep -r` over `$HOME` blocker
- PreToolUse(Bash) — `branch-protection`: blocks `git commit` / `git push` on the default branch, with the recovery recipe in its message **[guarded]**
- PreToolUse(Bash) — `auto-stage-learnings`: stages `ai-docs/learnings.md` **and** the `ai-docs/learnings/` directory on `git commit` (two independent `git status` probes, so a first-write untracked per-branch file is staged too) **[guarded]**
- PreToolUse(Bash) — `co-authored-by`: blocks a `Co-Authored-By` trailer in a `git commit` message (`-m` string or `-F` file) **[guarded]**
- PreToolUse(Bash) — `diff-range-guard`: warns when a gate is built on `git diff <base>...HEAD` on a branch with no commits yet (empty diff at rc=0 → silent pass); points at `git diff <base>` for the working-tree form
- PreToolUse(Bash) — `config-search-gate`: blocks a content search whose file filter can match an ASK-gated deployed-config file. Catches an explicit `.properties` filter/path and a recursive search rooted in a resources dir; does NOT catch a bare unfiltered search whose pattern happens to match a config key, so a clean run is not clearance
- PreToolUse(Bash) — `gate-pipe-guard`: blocks a gate — a named build / test / lint / format tool, **or a shell interpreter invoking a script file whose basename carries `test` / `check` / `lint` / `verify`**, which is what makes a suite written in shell a gate rather than an ordinary command; a bare `bash -c …` is not one — whose result is MASKED — piped into `head`/`tail`/`grep`/`jq`/`sed`/`awk`/`wc`/`cut`/`sort`/`uniq`, fused to a trailing `|| echo` / `|| true`, `;`-joined behind an `echo`/`printf` banner, **redirected into `/dev/null`** (which discards the line naming WHICH assertion failed, so even a correct rc leaves nothing to act on), or **run inside a `for` / `while` loop** (which exits with the LAST iteration's status, erasing every earlier failure). The loop leg fires only when the loop BODY invokes a **named build / test / lint / format tool or a shell interpreter**, so a loop over `grep` / `awk` / `realpath` passes. **That is narrower than the rule on purpose, and a pass is not clearance:** `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Tooling counts **search** among the gates, and blocking every loop containing a `grep` would be intolerable, so the hook deliberately under-approximates. The rule still binds on the construct. **A gate whose path arrives through a VARIABLE or a glob is invisible to this hook by construction** — no guard that matches the command string can see it — so that construct check stays with the author. Carve-outs pass: a `cd <dir> &&` prefix, a `[ -n … ] &&` guard that does not swallow the rc, and any chain inside a hook or checked-in `.sh`. **The gate match is anchored at COMMAND POSITION** (start of string, or after `;` `&` `|` `(` `` ` ``), so a gate name inside a search pattern — the project's own propagation sweep — is not a gate invocation and is not blocked. Newlines are normalised to `;` before matching, so a gate piped across a line break is still caught, and **redirections (`2>&1`, `&>`) are normalised away**, so the commonest spelling of a piped gate no longer slips past the `&` the gap cannot cross. There is NO heredoc opt-out: prose that quotes a piped gate at the start of a line is blocked like any other, and the remedy is the `Edit` / `Write` tools per `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`
- PreToolUse(*) — `loop-index`: appends one line per tool call to a per-session ledger (`~/.claude/harness/loops/<session_id>.jsonl`) and, when the SAME `hash(tool + arguments)` has already run within the last ~20 steps with no `Edit` / `Write` / `NotebookEdit` in between, returns `permissionDecision: "ask"` with the count. The key is the **hash alone** and `agent_id` is a field beside it — putting the agent in the key would stop the same hash from two agents matching, which is the fan-out case (N siblings each doing one identical call) that no per-agent view can see. The ledger is an **index, not a copy**: it stores `tool_use_id` and the transcript path, so detail is one join away and no argument content is duplicated; `transcript` is per entry because a subagent writes its own file. The fingerprint is the same djb2 as `${CLAUDE_PLUGIN_ROOT}/scripts/session-events.sh`, and the two must not drift. **`ask` routes into the normal permission flow, so an already-allow-listed command can pass through without a prompt** — the stderr line is the half that always lands. Unguarded (a loop is never project-specific); every failure path exits 0 silently, so it can never cost a tool call
- PreToolUse(Edit|Write) — Propagation Rule reminder on AGENTS.md / skill / agent / rules edits **[guarded]**
- PreToolUse(Edit|Write) — `archive-protection-reminder`: advisory nudge when a write ADDS a `### ` header to `ai-docs/learnings.md`, pointing at `ai-docs/learnings/<username>-<branch>.md`. Counts headers before vs after, so a field-only edit and a whole-file rewrite stay silent. Never blocks (`exit 0`) — the `/improve` fold passes through
- PostToolUse(Write|Edit) — `learnings-append-check`: warns when a new Learning Log entry did not land last in its file
- PostToolUse(Write|Edit) — `sh-syntax-check`: runs `bash -n` on a written `*.sh` / `*.bash` file and BLOCKS (`exit 2`) when it no longer parses, naming the offending line and the commonest cause — an apostrophe inside a single-quoted region, which closes the string so the shell re-parses the remainder and the reported line is far from the real one. Unguarded, like `gate-pipe-guard`: a shell syntax error is never project-specific. Silent for any other extension and for a path that does not exist
- PostToolUse(Bash) — PR-body-sync reminder on `git push` to a feature branch **[guarded]**
- Stop, SubagentStop — `loop-verdict`: tier 2 of the loop index. Reads the same ledger once per turn and applies a STRUCTURAL gate keyed on the OPPOSITE of byte-identity — one tool repeated `min_calls` times with `min_distinct` distinct fingerprints, dominating the window — then resolves those calls' arguments from the transcript and asks a small model whether they are one intent retried or distinct steps. The gate is deliberately NOT a tier-1 signal: tier 1 fires only on byte-identity, so gating on it would confine tier 2 to the class tier 1 already caught. **It never blocks** — a `Stop` hook returning exit 2 forces the conversation to continue, which is the failure this detector exists to catch — and it reports through stderr plus a `kind: "verdict"`, `tier: 2` line. A window already judged for that tool is not re-judged, or every turn would re-ask. Absent `claude`, a failed call or an unparseable answer all end it silently. Unguarded; thresholds are tunable and every verdict records the ones it fired under
- **The ledger carries two record classes**, `kind: "call"` (one per tool call) and `kind: "verdict"` (one per firing), and **every reader MUST filter on `kind`**: a verdict line carries `tool` and `fp` exactly like a call, so counting one lets each firing make the next more likely. `tier` separates a hash catch from a model catch; `window` / `threshold` record the settings in force, without which a later reader cannot tell a wrong call from a since-changed setting. **Outcome is never written** — a hook cannot see its own effect, but the observations that follow a verdict are the outcome: the same `fp` again means the call went ahead, its absence means it was abandoned, a different `fp` on the same tool means it was reformulated. A call also records `cwd`, because **the ledger is global — one directory for every project — and rates are never pooled across them**: thresholds that fit one codebase say nothing about another, and a mixed figure lets one busy project set a number that reads as general. The project is technically recoverable from the transcript path, whose directory encodes it by replacing `/` with `-`, but that encoding is lossy where a directory name contains a hyphen, so `cwd` is stored exact and the recovered form is a fallback the report labels as such. `${CLAUDE_PLUGIN_ROOT}/scripts/loop-metrics.sh` is what derives all of it, grouping by project and reading outcomes by **position rather than timestamp** — a verdict is appended right after the call that triggered it, so at one-second resolution the two share a `ts` and a time-keyed read readmits the trigger, reporting every verdict as went-ahead. **A tier-2 decline is recorded too** (`verdict: "progress"`), which is not a reversal of "non-firings are not logged": for tier 1 every call is a line, so an absent adjacent verdict IS the non-firing, while for tier 2 the gate firing is itself unrecorded. Recording it both suppresses re-asking the model about a window it already declined and makes the structural gate's false-positive rate countable

> **Not configured, but expected per project:** a `PostToolUse(Write|Edit)` formatter hook running `%FORMAT_CMD%` on changed source files. Add it once the project's formatter command is filled in (`AGENTS.md § Build & Test`).

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
