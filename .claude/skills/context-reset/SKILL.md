---
name: context-reset
description: "Handoff protocol for large tasks (≥5 subtasks) AND compaction-recovery re-entry. Prevents context degradation and compaction-related quality loss."
when_to_use: "Activate at the start of every design-defined group per the design's ## Handoff plan, when a summary/compaction block appears at the top of context, or when noticing yourself rushing, simplifying, or skipping steps."
allowed-tools: Bash(git status:*), Bash(git rev-parse:*), Bash(git branch:*), Bash(git diff:*), Bash(grep:*), Bash(sleep:*), Bash(stat:*)
---

> **⚡ Compaction recovery check — read FIRST on every invocation.**
> If you are re-entering `/context-reset` after auto-compaction (a summary/compaction block at the top of context, or workflow context feels thin), STOP before any tool call and:
>
> 1. Identify the **parent workflow** (`/task`, `/project-review`) whose handoff `/context-reset` is performing. The parent's identity is recorded as the active progress file's `parent_skill:` field (or `current_step:` mentions a parent step name).
> 2. Run the parent skill's own compaction-recovery callout against its durable-state file (see `/task`, `/project-review` SKILL.md for the parent's variant). `/context-reset`'s body is the shared handoff + re-prime action, not a separate durable surface.
> 3. After the parent's callout routes you to the active subtask, follow `/context-reset`'s **Handoff protocol** below.
>
> This skill carries the canonical rationale below (§ **Compaction recovery (re-entry)**) for the other skills to cross-link to.

## Handoff protocol

When triggered (every design-defined group OR compaction detected):

1. `%BUILD_CMD% <module-path>` — ensure code compiles.
2. Update `ai-docs/plans/YYYY-MM-DD-name.progress.md` per canonical schema at [`ai-docs/templates/progress-format.md`](../../../ai-docs/templates/progress-format.md).
3. Launch ONE `Agent` Tool call per **group** (per the design's `## Handoff plan`). The Subagent owns all subtasks in its group and runs them sequentially in-context, committing after each:

   ```
   Agent(subagent_type="general-purpose",
         prompt="Read ai-docs/plans/YYYY-MM-DD-name.progress.md and complete Group <X>'s subtasks <N>–<M>, then return. DELETE any comment (doc-comment / `//` / `/* */`) that restates what the code, symbol name, type, or serialization tag already says — a field doc that paraphrases the field name IS narration; remove it. Keep ONLY a genuinely non-obvious 'why' (ai-docs/code-style.md § Comments). Applies to prod AND test code.")
   ```

4. Do NOT spawn one Agent per subtask. The group is the unit of fan-out; the subtask is the unit of commit.
5. Do NOT continue in current context.

The per-group subagent inherits the canonical schema verbatim and writes `current_step` / `last_passed_gate` / `Decisions log` entries at the same subtask boundaries the orchestrator writes today.

## Compaction recovery (re-entry)

Canonical rationale for the compaction-recovery callout that every code-side orchestrator places at the top of its body.

### Why a callout at all

Claude Code's per-skill truncation after auto-compaction keeps the **start** of `SKILL.md` and drops the rest. The compaction-recovery callout therefore lives at the very top of each code-side orchestrator SKILL.md so it survives even when the rest of the body is dropped at the per-skill cap. The user explicitly chose **heuristic self-detection** over a `SessionStart|compact` hook — the callout is the only mechanism; correctness rests on its wording.

Why this bites under Sonnet specifically (motivation, NOT an operational rule — do not enforce these numbers): a Sonnet session draws on a 1M base context but the harness caps each session at ~200k (≈180k input + ≈20k output), and auto-compaction fires as input nears the 180k input ceiling — exactly the event that truncates each skill body. Opus 1M sessions are not auto-compacted the same way, so the callout is load-bearing only in Sonnet sessions; under Opus it is harmless redundancy. Code-working skills run on both models, so the callout stays on all of them.

### The Full-read-on-re-entry invariant

Every re-entry path (compaction recovery or otherwise) MUST re-read the durable-state file end-to-end before any tool calls, then re-enter the skill from the **top of its body** (preambles included). The recorded `current_step` is a hint and a cross-check, NEVER an instruction to skip the read or jump straight to that step.

The invariant matters because:

- `/task` Step 1 is the spec phase (not the active-state probe — that lives in the `⚡ First` preamble above Step 1).
- `/project-review` Step 1 is "Determine branch" (not the RESUME probe).
- `/bugfix` Step 1 is "Reproduce and Trace" — re-running it on a confirmed trace re-asks the user to confirm what's already confirmed.
- `/interview` Step 1 is "Detect entry mode" — round counter lives in `.state.md`, not in Step 1.

Re-entering literally "from Step 1" would skip the active-state probes in two of five skills and re-trace in `/bugfix`. The wording "**re-enter the skill from the top of its body**" covers all uniformly.

### Variant taxonomy

Three callout variants address three structurally-different probe shapes:

- **Variant A** — `/task`, `/project-review`. Probe lives in a `⚡ First` preamble that globs / greps for the active artefact. Callout routes via the probe then re-enters from the top of the body.
- **Variant B** — `/bugfix`, `/interview`. Probe is a fixed-glob (`ai-docs/bugfix/trace-*.md` or `<spec_path>.state.md`); when a single in-flight artefact exists the callout reads it and applies a per-skill resume rule.
- **Variant C** — `/context-reset` itself. No own durable surface; routes to whichever parent skill is active. The callout above this section is Variant C.

## Checkpoint handoff: 1 Agent = 1 group

- Do NOT ask "continue?" between subtasks within a group — just proceed.
- Each `Agent` Tool call = 1 design-defined group; the Subagent commits after each subtask inside the group (subject to AGENTS.md commit/push ASK — Claude asks before committing; commits happen via user authorisation outside the loop, OR within an explicit pre-authorised flow like `/task` Step 12).
- Update progress.md after each subtask (current_step, last_passed_gate, Decisions log).
- Next group's Agent is spawned by the orchestrator only after the current group's Agent returns.
- **A transport-level drop is NOT a returned group.** On a socket-closed / connection-closed-mid-response failure, resume the SAME agent from its transcript (`SendMessage`) rather than spawning a fresh one — a fresh spawn discards the group's already-gathered context and re-does the work. From the 2nd consecutive failure on the same group, `sleep` 2s→4s→8s→16s→32s (cap 32s, small jitter) before re-dispatching; cap ~5 attempts, then surface to the user — never a silent loop. Reset the delay after any success. Before treating a group as done, verify its writes landed on disk (mtime + `grep` for the expected new string); the harness does not auto-retry on socket close.

## `.progress.md` format (canonical)

Full format spec at **[`ai-docs/templates/progress-format.md`](../../../ai-docs/templates/progress-format.md)**. Required fields include `**current_step:**`, `**last_passed_gate:**`, and a `## Decisions log` section in addition to `**Branch:**` / `**base_commit:**` / `**Last build:**`.

## Rules

1. Progress file = `ai-docs/plans/*.progress.md`. Updated at each checkpoint. Gitignored.
2. On context reset: pass file path in Agent prompt: `"Read ai-docs/plans/YYYY-MM-DD-name.progress.md and continue"`.
3. `%BUILD_CMD% <module-path>` BEFORE handoff — don't pass broken code.
4. Maximum 3 design-defined groups per task. More needed → task is too large; decompose into separate tickets.

## Patterns

### 1. Trust the compaction-recovery callout

*Default to* following the compaction-recovery callout at the top of every code-side orchestrator SKILL.md exactly — locate the durable-state file via the parent skill's active-state probe, read it end-to-end before any tool call, re-enter the skill from the top of its body. *Prefer* the protocol over shortcut paths even when context feels thin or the recorded `current_step` looks like a clear instruction to jump.

**Why.** Claude Code's per-skill truncation after auto-compaction keeps the start of `SKILL.md` and drops the rest. The full-read-on-re-entry invariant is what preserves workflow correctness across compression events; jumping to a recorded step would skip the parent skill's active-state probe or re-trace already-confirmed state.

### 2. Resume a dropped subagent, don't respawn it

*Default to* resuming the SAME agent from its transcript (`SendMessage`) after a transport-level drop (socket closed / connection closed mid-response) — a cold respawn discards every bit of context that agent had gathered, which is the same loss this skill exists to prevent. First resume after a single drop may be immediate; from the 2nd consecutive failure on the same step, `sleep` 2s→4s→8s→16s→32s (cap 32s, small jitter); cap ~5 attempts, then surface to the user — never a silent loop. Reset the delay after any success. Verify a mid-write drop actually landed (mtime + `grep`) before treating the step as done.

**Why.** A drop mid-handoff is indistinguishable from a completed one at the orchestrator, and respawning looks cheaper than it is: the replacement re-reads everything and may write a *different* artefact over a partial one. (Same rule is re-stated in [`/task` § Patterns](../task/SKILL.md#patterns).)
