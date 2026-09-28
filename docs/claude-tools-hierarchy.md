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

> **This list is a SNAPSHOT and it went badly stale once.** It carried 7 names while the documentation defined 33 — and because `/ai-audit` Checklist O compares project-defined names against exactly this list, the missing 26 were names a clash check could never have caught. Two of them, `PostToolUseFailure` and `PostToolUse`, turned out to be the pair that makes a call outcome knowable at all, so the gap cost a capability as well as a check. Re-read the documentation rather than this file when the answer matters, and refresh here when it differs.

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
- PreToolUse(*) — `loop-index`: appends one line per tool call to a per-session ledger (`~/.claude/harness/loops/<session_id>.jsonl`) and, when the SAME `hash(tool + arguments)` has already run within the last ~20 steps, returns `permissionDecision: "ask"` with the count. **The intervening-edits filter is CONDITIONAL on the outcome**, and that is not a nicety: for calls that succeeded, a write between the repeats means the world changed and the finding is dismissed; for calls that FAILED, the edit means an attempt was made and the call failed again — the fix-break cycle, where dismissing it is how the commonest logical loop stayed invisible. Two prior failures fire as `error-retry`; three occurrences fire as `loop`. Both numbers mirror `${CLAUDE_PLUGIN_ROOT}/scripts/session-events.sh` (`retry_min: 2` against `minrep: 3`), which applies the same split per signature and always did — the live index diverged from it until GH-69. The key is the **hash alone** and `agent_id` is a field beside it — putting the agent in the key would stop the same hash from two agents matching, which is the fan-out case (N siblings each doing one identical call) that no per-agent view can see. **That arm is currently unreachable, and the field is currently wrong:** `agent_id` is derived from `transcript_path`, and the payload carries the PARENT transcript even for a call made inside a subagent, so on every ledger measured so far the field reads `main` for every call and the stored `transcript` pointer names a file that does not contain that `tool_use_id`. `${CLAUDE_PLUGIN_ROOT}/scripts/loop-metrics.sh --for` recovers the real attribution at read time by locating each id in the session's transcripts; live detection is not fixed by that. The ledger is an **index, not a copy**: it stores `tool_use_id` and the transcript path, so detail is one join away and no argument content is duplicated; `transcript` is per entry because a subagent writes its own file. The fingerprint is the same djb2 as `${CLAUDE_PLUGIN_ROOT}/scripts/session-events.sh`, and the two must not drift. **`ask` routes into the normal permission flow, so an already-allow-listed command can pass through without a prompt** — the stderr line is the half that always lands. Unguarded (a loop is never project-specific); every failure path exits 0 silently, so it can never cost a tool call
- PreToolUse(Edit|Write) — Propagation Rule reminder on AGENTS.md / skill / agent / rules edits **[guarded]**
- PreToolUse(Edit|Write) — `archive-protection-reminder`: advisory nudge when a write ADDS a `### ` header to `ai-docs/learnings.md`, pointing at `ai-docs/learnings/<username>-<branch>.md`. Counts headers before vs after, so a field-only edit and a whole-file rewrite stay silent. Never blocks (`exit 0`) — the `/improve` fold passes through
- PostToolUse(Write|Edit) — `learnings-append-check`: warns when a new Learning Log entry did not land last in its file
- PostToolUse(Write|Edit) — `sh-syntax-check`: runs `bash -n` on a written `*.sh` / `*.bash` file and BLOCKS (`exit 2`) when it no longer parses, naming the offending line and the commonest cause — an apostrophe inside a single-quoted region, which closes the string so the shell re-parses the remainder and the reported line is far from the real one. Unguarded, like `gate-pipe-guard`: a shell syntax error is never project-specific. Silent for any other extension and for a path that does not exist
- PostToolUse(Bash) — PR-body-sync reminder on `git push` to a feature branch **[guarded]**
- PostToolUse(*), PostToolUseFailure(*) — `loop-result`: appends a `kind: "result"` row keyed by `tool_use_id` recording whether the call succeeded. **The event name is the answer, not a field**: `PostToolUse` fires after a success and `PostToolUseFailure` after a failure, so nothing parses a tool response — whose shape differs per tool and would drift silently. Appends rather than amending the call row: the ledger is append-only by contract, an in-place edit would race the next `PreToolUse`, and a reader that joins is cheaper than a writer that seeks. **This is what makes the fix-break cycle visible** — without an outcome the index could not tell a failing repeat from a succeeding one, so it applied the intervening-edits filter to both and dismissed `test → edit → test → edit → test` at every round. Unguarded
- Stop, SubagentStop — `loop-verdict`: the COARSE stage of the cascade (exact hash → coarse hash → model → deep analysis). Writes a `kind: "turn"` marker on every stop — the ledger has no turn index because `PreToolUse` does not know one, and `Stop` IS the turn boundary — then fires when ONE `bin` repeats `min_bin_repeats` times **within that turn**. The bin comes from `${CLAUDE_PLUGIN_ROOT}/scripts/bin-of.jq`. **The gate is deliberately not a tier-1 signal**: tier 1 fires only on byte-identity, so gating on it would confine this stage to the class tier 1 already caught. **Its first design did not discriminate and was replaced from measurement:** counting DISTINCT fingerprints and requiring one tool to dominate fired on healthy work every time, because ordinary varied work is also "all fingerprints distinct", and in a shell-driven session one tool is ~98% of calls so concentration is vacuous. Coarse repeats within a turn gave a spread (11 / 5 / 4 / 3 / 2) where both older figures were identical for every turn. **The model stage is OFF by default** (`HARNESS_T3_MODEL`); when on it writes a separate `tier: 3` verdict and takes its reason from the FIRST line of the answer. **It never blocks** — a `Stop` hook returning exit 2 forces the conversation to continue, which is the failure this detector exists to catch. Turn scoping makes re-judging impossible by construction. Absent `claude`, a failed call or an unparseable answer all end it silently. Unguarded; thresholds are a hypothesis from one session and every verdict records the value it fired under
- **The ledger carries two record classes**, `kind: "call"` (one per tool call) and `kind: "verdict"` (one per firing), and **every reader MUST filter on `kind`**: a verdict line carries `tool` and `fp` exactly like a call, so counting one lets each firing make the next more likely. `tier` separates a hash catch from a model catch; `window` / `threshold` record the settings in force, without which a later reader cannot tell a wrong call from a since-changed setting. **Outcome is never written** — a hook cannot see its own effect, but the observations that follow a verdict are the outcome: the same `fp` again means the call went ahead, its absence means it was abandoned, a different `fp` on the same tool means it was reformulated. A call also records `cwd`, because **the ledger is global — one directory for every project — and rates are never pooled across them**: thresholds that fit one codebase say nothing about another, and a mixed figure lets one busy project set a number that reads as general. The project is technically recoverable from the transcript path, whose directory encodes it by replacing `/` with `-`, but that encoding is lossy where a directory name contains a hyphen, so `cwd` is stored exact and the recovered form is a fallback the report labels as such. `${CLAUDE_PLUGIN_ROOT}/scripts/loop-metrics.sh` is what derives all of it, grouping by project and reading outcomes by **position rather than timestamp** — a verdict is appended right after the call that triggered it, so at one-second resolution the two share a `ts` and a time-keyed read readmits the trigger, reporting every verdict as went-ahead. **A tier-2 decline is recorded too** (`verdict: "progress"`), which is not a reversal of "non-firings are not logged": for tier 1 every call is a line, so an absent adjacent verdict IS the non-firing, while for tier 2 the gate firing is itself unrecorded. Recording it both suppresses re-asking the model about a window it already declined and makes the structural gate's false-positive rate countable
- **`loop-metrics.sh --for <transcript.jsonl>` is the ledger view `/inspect` reads**, and it takes a TRANSCRIPT because that is all the skill holds. It resolves the session id from the path — with a special arm for a subagent transcript, `<session-id>/subagents/agent-<id>.jsonl`, whose basename is the agent and would otherwise resolve to a ledger no session ever writes. It emits the verdicts with the fields that make one **locatable** in the run (`ts`, `bin`, `repeats`, `count`, the threshold it fired under, the model's `reason`) rather than merely countable, plus a per-agent census recovered by `tool_use_id`. **A ledger that is absent is emitted as `available: false` with a reason, at rc 0**, so it joins the `unavailable` list rather than reading as a clean run — while an absent TRANSCRIPT stops the run at rc 2, because attribution is a lookup in that file and losing it does not degrade the census but makes every call unattributed beside counts that stay correct. `attribution.complete` is the conjunction of the three things the reader can actually check — the main transcript was opened, nothing failed to parse, and no unattributed call sits where a call still executing cannot be (`unattributed_at_tail`) — and **is not a guarantee that attribution succeeded**: nothing enumerates the transcripts that ought to exist, because the ledger field that would be that list is the broken one above. A subagent transcript that is simply absent while its calls happen to be last stays invisible. **A reader checks `complete` before reading `unattributed`,** and treats a large `unattributed` as worth reporting even when `complete` is true. **Join a ledger row to the transcript by `tool_use_id`, never by fingerprint:** the two are computed from the hook payload and from the recorded call, and they disagree for tools whose input the client rewrites in between (`Agent`, `AskUserQuestion`) — which is exactly the tool a fan-out question is about

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
