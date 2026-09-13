---
name: interview
description: "Requirements interview with the product owner. Output: spec saved to ai-docs/plans/, cross-linked with the tracking ticket when the project has one. Invoked by /task for Steps 1–5, or run standalone for spec-only work."
argument-hint: "[ticket-key | task description]"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(git branch:*), Bash(git checkout:*), Bash(git mv:*)
---

Orchestrator for the spec-drafting interview. Drives the round loop, surfaces the subagent's questions, applies user's answers — but does **not** draft the spec itself. Spec drafting + question generation live in `.claude/agents/spec-writer.md` (subagent on `model: opus`).

> **MUST run before:** code investigation, `design` Subagent, or writing code. **Carve-out — grounding reads are not "code investigation".** The `spec-writer` § Patterns rules require reading the live/deployed state and the sources that generate it before accepting a ticket's "blocked on deploy" premise, and Step 3a-bis requires grounding an `ask` round's options in real code. Both are permitted here: what this gate forbids is *designing the solution* ahead of the spec, not *verifying the premises the spec rests on*. **What you can actually run:** the source leg — a filtered search for the symbol in the repo, where a hit on the default branch proves *merged*. Proving something is *deployed* needs a fetch neither this skill nor `spec-writer` is granted: ask the user. Sync group: `.claude/agents/spec-writer.md` — keep this carve-out and its § Patterns rules aligned.
> **Branch gate — first action, before round 1.** Run `git branch --show-current`. If it is the default branch, `git checkout -b <TICKET-KEY>-<slug> main` before writing anything: this skill writes `*.spec.md` + `*.state.md`, and AGENTS.md AXIOM 1 binds on any file edit, not just code. Invoked from `/task`? Step 0 already branched — just confirm.
> Run standalone when you want a spec without committing to implementation (defer it to `ai-docs/plans/deferred/` afterward).
> For the full task workflow use `/task` — it delegates Steps 1–5 to this skill, then continues with design → implementation.

> **⚡ Compaction recovery check — read FIRST on every invocation.**
> If you are re-entering this skill after auto-compaction (a summary/compaction block at the top of context, or workflow context feels thin), STOP before any tool call and:
>
> 1. **Locate the durable-state file** — `ls ai-docs/plans/*.spec.md.state.md 2>/dev/null` (read both the matched `.state.md` AND its sibling `<spec_path>`). If exactly one in-flight artefact exists, that's the durable state. None → fresh invocation. Multiple → surface to user.
> 2. Read it **top-to-bottom in one pass**. Recorded `round` is a cross-check, never an instruction to skip the read.
> 3. **Re-enter this skill from the top of its body.** Resume from the round recorded in `.state.md`; do NOT restart at round 1.
>
> See `.claude/skills/context-reset/SKILL.md § Compaction recovery (re-entry)` for canonical rationale.

## Architecture

Two pieces:

1. **This file** (orchestrator) — plumbing only. Detects entry mode, manages state, runs the round loop, parses the subagent's YAML status block, surfaces questions via `AskUserQuestion`, executes action handlers on `unresolvable`.
2. **`.claude/agents/spec-writer.md`** (subagent, `model: opus`) — owns scope extraction, question drafting, pre-resolved-rule blacklist, optimization-target enforcement, and the spec write itself.

## Round / question caps

| Constant | Value | Notes |
|---|---|---|
| `round_cap` | 4 | Hard upper bound on rounds — interview must terminate (`ready` / `unresolvable`) by this round. |
| `questions_per_round_cap` | 4 | Hard upper bound on questions per `ask` round — equals the `AskUserQuestion` tool ceiling (the schema accepts 1–4 question objects). Spec-writer must use the full budget when its question count is design-affecting; orchestrator's own clarification prompts go in a separate UI exchange. |

Hard-coded; passed to subagent every invocation.

### AskUserQuestion tool schema (consumed at Step 3d)

The orchestrator surfaces the spec-writer's questions via `AskUserQuestion`, honouring the tool-side bounds: 1–4 questions per call (matches `questions_per_round_cap`), 2–4 options each, an auto-appended `Other` (never supply it yourself), and `header` ≤ 12 chars. Step 3d enforces these project-side. Full detail: [`reference.md` § AskUserQuestion tool schema](reference.md).

## State file

Path: `<spec_path>.state.md` — e.g. `ai-docs/plans/2026-05-25-name.spec.md` ↔ `ai-docs/plans/2026-05-25-name.spec.md.state.md`.

Created at round 1; deleted on terminal exit. Format: a markdown header + a single fenced YAML block — keys: `schema_version`, `spec_path`, `ticket_ref`, the mutually-exclusive `ticket:` / `task_description:` payload, `round_cap`, `questions_per_round_cap`, `round`, and the `prior_qa` list (each entry `{round, question, proposed_options, answer}`). Full annotated schema: [`reference.md` § State file — YAML schema](reference.md).

## Workflow

### Step 1: Detect entry mode

Inspect `$ARGUMENTS`:

- **Ticket ref** — matches `^[A-Z][A-Z0-9]+-\d+$` (case-insensitive), or a bare `#N` GitHub issue: load it if a tracker is reachable from this session (`gh issue view <N> --json title,body,state`). If none is, record the key as a reference and carry the user's own description as the body. Record `ticket_ref = <KEY>`.
- **Free text / empty**: use as task description, or ask "What do you want to plan?" if empty. `ticket_ref` is unset until Step 4.

### Step 2: Compute paths and seed state

1. Derive a kebab-case spec slug from the ticket title (or task description), ≤ 5 words.
2. `spec_path = ai-docs/plans/<TODAY>-<slug>.spec.md`. **`<TODAY>` is READ, never derived** — take the session date from the environment context (`Today's date is …`) immediately before composing the path, then verify the composed filename carries that exact date. Never copy or increment the date of a prior plan file. A wrong date prefix is free to prevent here and expensive to repair later: once `*.spec.md` / `*.design.md` reference it, AGENTS.md forbids the orchestrator from editing those files, so every stale path string and `**Date:**` header must go back through its owning subagent.
3. `state_path = <spec_path>.state.md`.
4. Write the initial state file with `round: 1`, `prior_qa: []`, plus the Step 1 payload (ticket-mode `ticket:` block OR free-text `task_description:` block).

### Step 3: Round loop

For each round (1..`round_cap`):

#### 3a. Invoke the subagent

```
Agent(
  subagent_type="general-purpose",
  prompt="""
    Read .claude/agents/spec-writer.md and follow it.

    ticket_ref: <TICKET-KEY | "free-text">
    ticket_body: |
      <verbatim ticket description, OR user's free-text task description>
    round: <N>
    round_cap: 4
    questions_per_round_cap: 4
    prior_qa: <YAML list — each entry: {round, question, proposed_options, answer}>
    spec_path: <spec_path>
  """
)
```

> **Cold-spawn is the contract — not a fallback.** Do NOT narrate "SendMessage not available — falling back to cold spawn" before every round. Do NOT probe `ToolSearch` for `SendMessage` per round (the absence is stable per session). If a status line is emitted at all, phrase it as `Spawning round N spec-writer.` — never as a fallback announcement. Cold-spawn re-pays the spec-writer's preamble cost (file reads + AGENTS.md preflight + pre-resolved-rule blacklist) per round; that is the documented protocol. The misleading "fallback" framing trains the user to mistake the standard path for a problem.

#### 3a-bis. Option-grounding (Explore) — before surfacing any `ask` round

When the spec-writer returns `status: ask` with options that hinge on a code-level mechanism (a transaction/proxy boundary, a concurrency-scope choice, an event-vs-poll wiring decision, a propagation mode), the orchestrator MUST ground those options in the actual codebase BEFORE surfacing them — an option the code forbids is a wasted user turn.

- Quick search / Read pass on the cited mechanism (e.g. confirm whether a transactional call site crosses a proxy boundary; confirm a DAO's propagation mode; check whether the module enables the framework feature the option assumes).
- If exploration shows an option is structurally impossible (e.g. a self-invoked proxied call the framework will silently ignore), drop or annotate that option before `AskUserQuestion`; do NOT surface a dead choice.
- Record what you explored in the state file's `prior_qa` note for the round, so the constraint travels forward.

This is option-grounding only — it does NOT draft the spec (the spec-writer owns the write) and does NOT replace the user decision; it removes infeasible options so the user chooses among real ones.

#### 3b. Parse the YAML status block

Subagent's response ends with a fenced YAML block. Extract; parse `status`, `round`, and `questions` / `reason` as applicable.

**On parse failure** (malformed YAML, missing required fields):

1. **One-shot retry** — re-spawn with prompt: `"Re-emit only the YAML status block, exact schema. Your previous response did not contain a parseable status block at the end."` Parse again.
2. **On second failure** — orchestrator-injects a synthetic `unresolvable` and proceeds to 3d.

#### 3c. Branch on status

- **`ready`** → Step 4.
- **`ask`** → 3d.
- **`unresolvable`** → 3e.

#### 3d. Surface questions to the user

Validate:

- `len(questions) <= questions_per_round_cap` — if exceeded, one-shot Subagent re-spawn with trim instruction.
- Each `header` ≤ 12 chars; each `options` list 2..4 entries.
- No question contains a pre-resolved-rule blacklist substring (defence in depth; the Subagent should have caught it).

Call `AskUserQuestion(questions=[...])` with the entire list.

Append each `(question, proposed_options, answer)` to state's `prior_qa` with `round: <current>` — `proposed_options` = the question's `options` array as surfaced via `AskUserQuestion` (option labels only; do NOT persist the descriptions or the auto-appended `Other`). Increment `round`. Loop to 3a.

#### 3e. Action chooser on `unresolvable`

Build `AskUserQuestion` with the Subagent's `reason.detail` as the question prose. Options: Subagent's `suggested_action` first, plus the other applicable actions:

| Category | Actions to offer (recommended first) |
|---|---|
| `cap_reached` | `extend_cap`, `defer_to_deferred`, `abort` |
| `logically_unresolvable` | `defer_to_deferred`, `abort`, `request_external_info` |
| `external_dependency` | `request_external_info`, `defer_to_deferred`, `abort` |
| `empty_scope` | `abort`, `request_external_info`, `defer_to_deferred` |
| `user_loop` | `defer_to_deferred`, `abort`, `request_external_info` |

Execute the chosen action:

- **`extend_cap`** — bump `round_cap += 1`; loop to 3a.
- **`defer_to_deferred`** — `git mv <spec_path> ai-docs/plans/deferred/`; delete state file; exit. Skip Step 4.
- **`abort`** — delete `<spec_path>` if exists; delete state file; exit. Skip Step 4.
- **`request_external_info`** — prompt user for extra context; loop to 3a with `extra_context: <paste>` injected.

### Step 4: Cross-link and exit (on `ready`)

1. Show the user the final spec at `<spec_path>` (last 80 lines if long).
2. Confirm — `AskUserQuestion`: "Approve the spec?" / { Approve, Tweak first }.
3. On Approve:
   - Resolve the tracking ticket if not pinned (ticket-ref mode = already pinned; free-text mode = propose creating one, e.g. `gh issue create --title "<from spec>" --body-file <file>`), **after user approval**. Then **cause the key to be captured** into the spec's `**Tracked in:**` field **via the spec-writer** — re-invoke the spec-writer with the resolved key in `prior_qa` (e.g. an instruction "set Tracked in to <KEY>"). Do NOT `Edit` the spec from the orchestrator: the spec-writer owns ALL `*.spec.md` writes (see Anti-patterns; AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`").
   - Post the cross-link comment on the ticket when the project has a tracker (`gh issue comment <N> --body "Spec: \`<spec_path>\`"`); skip it otherwise.
   - Delete the state file.
4. Skill exits. `/task` (the caller) resumes at Step 6 (`design` Subagent).

> **Forward-handoff of explored constraints.** Any code-level constraint surfaced during a 3a-bis option-grounding pass (e.g. "the REQUIRES_NEW heartbeat call site is intra-class → must use `transactionTemplate.execute`, not the annotated method"; "the module enables allopen → no manual `open`") MUST be carried into the spec's scope/constraints so the `design` Subagent inherits it. Re-invoke the spec-writer to record the constraint — the orchestrator does NOT edit the spec directly. A constraint discovered at interview time but not written into the spec is re-litigated (or violated) at design time.

> **Skip the tracking-ticket resolution when the user explicitly states "no tracking ticket", or when the project has no tracker.** Note the reason in the spec header (`**Tracked in:** none — <reason>`) and skip the cross-link comment.

> **A follow-up ticket is a commitment to schedule work, not a place to park an observation.** Create one only when the work is actually going to be scheduled; otherwise record the finding in the design document or surface it in conversation. **Do NOT link a follow-up to the parent by default** — a "relates" link asserts "a reader of the parent needs this", which is true for INPUTS (the analysis it came from, the ticket that made the premise stale, the originating complaint) and usually false for work spun OUT of it. Judge the link set from the reviewer's side: five links on a bugfix reads as sprawl even when each is individually defensible. Note also that a ticket stays PR-associated through the PR body and through a key referenced in code even after every tracker link is gone — so "unlink" and "not tracked" are different states, and which one is wanted must be established before acting.

## Spec-only run

If the user wants to stop after the interview:

1. `git mv <spec_path> ai-docs/plans/deferred/`.
2. Delete the state file.
3. Do NOT proceed to Step 6 of `/task`. The spec can be picked up later via `/task`'s deferred-plan-activation preamble.

## Anti-patterns

- Drafting questions yourself in the orchestrator. The subagent owns question authorship.
- **Mutating the spec yourself — FORBIDDEN even for one-line user tweaks.** The spec-writer subagent owns ALL `Write` / `Edit` operations on `*.spec.md`. On user "Tweak first" after `status: ready`: append the Q&A to state's `prior_qa`, increment `round`, RE-INVOKE the spec-writer. Do NOT `Edit` the spec yourself — that violates AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`".
- Skipping the YAML status parse and inferring intent from prose.
- Embedding the pre-resolved-rule blacklist in this file. Lives in the Subagent.
- Forgetting to delete the state file on terminal exit.
- Saving the spec without `**Tracked in:**` (unless user explicitly opted out).
- Skipping the cross-link comment on the tracking ticket when the project has one.
- Silently switching to implementation mid-interview.
