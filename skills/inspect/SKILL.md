---
name: inspect
description: "Analyse a finished session for harness defects: loops, gates re-run without a state change, review rounds that burned their cap, turns that went round and round. A script finds the candidates; the inspector agent reads the run where they point and judges. Proposes Learning Log entries and never edits an instruction file."
when_to_use: "Activate when the user asks why a session went in circles, where its effort went, or what the harness itself cost — and after a run that burned a review cap, re-ran a gate with no state change between runs, or spent several rounds on one finding. It reads a FINISHED session, so it is near-useless mid-task: the transcript it would read is the one still being written, and the loop it would find is the one still running. It proposes Learning Log entries and edits no instruction file. SKIP when the question is what the instructions SAY rather than what a run did (that is /ai-audit), when it is whether a diff is correct (that is self-review), and when nothing actually looped — a clean run has nothing to report and this pass is not free. PUT THE CALL TO THE USER rather than taking it on a hunch: it costs a full pass over a whole transcript."
model: opus
argument-hint: "[session.jsonl path, or omitted for the most recent session of this project]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(scripts/session-events.sh:*), Bash(scripts/trace-tokens.sh:*), Bash(scripts/loop-metrics.sh:*), Bash(ls:*), Bash(git branch:*), Bash(git status:*), Bash(jq:*)
---

Reads what a session actually did and reports where the **harness** sent the agent in circles — as opposed
to `/ai-audit`, which reads what the instructions say, and `self-review`, which reads a diff.

> **Branch gate — first action.** `git branch --show-current`. This skill writes a Learning Log entry, and
> AXIOM 1 binds on any file write. If it is the default branch, branch before Step 4.

## Step 0: Resolve the session

With an argument, use it. Without one, take the most recent transcript for the current project:

```bash
ls -t ~/.claude/projects/"$(pwd | sed 's|/|-|g')"/*.jsonl 2>/dev/null | head -1
```

If that resolves to the session you are running in **right now**, say so before continuing: a live
transcript is still being written, so its last turn is truncated and its counts move between reads.
Inspecting a finished session is the intended use.

If nothing resolves, ask for the path. Do not guess at another project's transcript.

## Step 1: Reduce — mechanically, before any judgement

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/session-events.sh <session.jsonl> --signatures
```

A real session runs to thousands of entries and does not fit in a context. This pass is what makes the
run navigable: counts, tool names, fingerprints and timestamps, so the agent knows which turns and which
seq ranges are worth its attention before it opens anything.

Add `${CLAUDE_PLUGIN_ROOT}/scripts/trace-tokens.sh <session.jsonl>` when the question is cost rather than
looping; the two read the same transcript for different purposes.

Add `${CLAUDE_PLUGIN_ROOT}/scripts/backlog-metrics.sh` when the question is whether the ticket tail is
growing faster than work ships. It reads the repo, not the session, and answers the other half of
`deferral-candidate`: this skill sees one session filing a ticket, that script sees whether filing has
become the habit.

**Read `unavailable` yourself, now.** A signature that could not run is the first thing the user needs, and
it must not wait for the agent's report to surface.

## Step 1b: The ledger — what the live cascade already decided

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/loop-metrics.sh --for <session.jsonl> --json
```

Step 1 derives candidates from a transcript after the fact. The `PreToolUse` / `Stop` cascade was watching
while the session ran, and wrote what it saw. Without this the inspector re-derives from scratch and cannot
tell a **detector hit** from a **detector miss** — which is the only feedback the cascade has, and the
difference between "this looks like a loop" and "this was flagged live, the user let it through, and it ran
anyway".

**It is a WIDER view of the same session, not a second opinion on the same data.** `--signatures` reads one
transcript file; the ledger records every tool call in the session including the ones made inside spawned
agents, whose transcripts live in a separate directory that pass never opens. Expect the call count here to
exceed it, sometimes by a large fraction. That is not a discrepancy to reconcile — and neither is the turn
count, which here counts stop events and there counts prompts. **Two numbers under one word, measuring
different things: never subtract them.**

**An absent ledger is reported with the `unavailable` list, not passed over.** The mode says so itself,
`available: false` at rc 0. A session nobody watched and a session in which nothing fired look identical
from here, and only one of them is a clean result.

**rc 2 is a different answer and is not a missing ledger.** It means the path you handed over does not
resolve, so no attribution is possible — read the message, fix the path, and run it again. Do not fall
back to the signatures alone on an rc 2 without saying so: that is a path you got wrong, not a fact about
the session.

**Pass the whole record to the agent, including `attribution`.** Its `complete` field says whether the
per-agent census can be trusted, and the agent is told to read that before it reads `unattributed`.
`agreement` carries the reader's comparison of the ids the hook stored against the ones it recovered, and
`every_stored_agent_read` with `stored_agents_unread` names the agents whose transcripts it never opened —
between them they say whether a census is wrong rather than short, and the agent has a reading for each. The
verdict rows carry evidence of their own: a `tier: 3` row records `flagged_calls` and `unresolved_calls`. A
summary that keeps the counts and drops the flags hands over the one shape that reads as confident and
is not.

**Pass `agent_marks`, `agent_mark_ids` and `call_agents_sub` too — they are the ledger's own check on the
stored attribution, and they are the only one that needs no transcript.** One `agent-mark` row is written
per subagent spawn. Starts recorded with `call_agents_sub` at zero means the stored `agent_id` degraded to
the literal `"main"`, which reads as a genuine main-agent call, so a clean fan-out reading over those rows
means nothing; the agent has a reading for it and reports it as a harness defect. **The check closes one
direction only** — zero recorded starts cannot separate "no subagent ran" from "the canary is not firing" —
so a zero is never evidence that attribution is sound.

**A tier-1 verdict row carries `settings.window_unit`, and a row without it is not the same row.** `window`
changed meaning without changing shape: rows written before the call-counted window recorded a number of
ledger LINES, rows after it record a number of CALLS. Comparing two `window` values across that line
compares two different units, so read the unit before reading the number. **An older row reads `"lines"`,
not `null`** — the reader infers it from the row, because only a pre-change build wrote a window with no
unit beside it and that build counted lines. `null` is reserved for a row with no window at all (tier 2,
tier 3), so it means "no unit applies" rather than "unknown".

## Step 2: Judge — spawn the inspector

```
Agent(subagent_type="inspector", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/inspector.md and follow it exactly.
  Here are the signatures and the unavailable list: <paste the --signatures JSON>
  Here is the loop ledger for this session: <paste the --for JSON, or the unavailable record it returned>
  The transcript is at <path>. Start from the signatures, then read the run where they point —
  by seq range, turn, or timestamp span. Do not read it front to back; it does not fit.
  Quote the run where the quote is the evidence; do not copy a credential into an entry.
  Report: (a) signatures that could not run and why — and whether the ledger was available,
  (b) confirmed defects with the instruction at fault, (c) dismissed candidates with the reason,
  (d) candidates the live cascade MISSED, which is how the detector gets tuned,
  (e) proposed Learning Log entries.
")
```

Pass the JSON **in the prompt** and the transcript **as a path**. The JSON is what tells the agent where
to look; without it in front of them, an agent handed a path reads from the top and burns the context it
needs for judging.

> **Why the agent reads the run.** A repetition is a loop or a retry depending on what happened between
> the repeats; a deep turn is circling or sweeping depending on the order of what it did. Neither is in
> the counts, so an inspector judging from counts alone returns "unjudgeable" on exactly the candidates
> that matter. It is looking for where this harness wastes its own effort, and it needs the run to find it.

## Step 3: Surface before writing

Show the user, in this order:

1. signatures that did not run, and why — **first, always**, and whether the ledger was there;
2. confirmed defects, each with its evidence and the instruction at fault;
3. dismissed candidates and why they were dismissed;
4. what the live cascade missed — a defect confirmed here that nothing flagged at the time is a finding
   about the DETECTOR, and it is the only way the thresholds ever move.

A dismissal is a result. A run that confirms nothing but dismisses six candidates with reasons is a good
run, and saying so is what stops the next one from being ignored.

## Step 4: Write the entries — on approval only

On approval, append the agent's proposed entries to `ai-docs/learnings/<username>-<branch>.md`
([§ Target file](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md#target-file)), `Kind:
correction`, `Escalated? no`.

**The orchestrator writes them; the agent does not.** And `Escalated? no` is binding: this skill proposes,
`/improve` escalates across accumulated evidence from many sessions. Fixing the rule in the same breath as
judging it is grading your own work.

Per Boundary rule 2, a Learning Log write triggers **no other instruction-file edit in the same turn**.

## Calibration

Thresholds are tuned against real sessions, not guessed: `--spike-factor` defaults to 5× the median turn
because 3× flagged one turn in five on a real session, which is a list nobody reads. `--window` (600s) and
`--min-repeats` (3) carry the time and repetition qualifiers — but `--min-repeats` governs
`repeated-tool-call` and `repeated-agent-spawn` only: `error-retry-loop` fires at two, because two failures
of the same call with no change between them is already the shape. Each of those three repetition
signatures reports the `threshold` it actually used and the `filters` that actually ran on it; read those
rather than assuming the top-level numbers applied.

**`--window` is a sliding window, and a row reports two counts because of it.** The question is whether
the threshold is met inside *any* window, not whether every occurrence of that call fits in one — asking
the latter passes only a call that happens nowhere else in the session, which is why the signature
returned a structural zero before. `count` is the burst the window found; `total_in_session` is how many
times that call ran in all. A large gap between them is not itself a defect: it means the call is routine
and went tight somewhere. `turn-depth-spike`, `deferral-candidate` and `step-regression` carry neither
field.

**`repeated-agent-spawn` does not use `--window` at all — it chains on `--spawn-gap` (1800s).** Its
qualifier *is* the gap: seconds apart is a fan-out, minutes apart is a round cap re-entering. A width
filter would therefore decide the question the judge is there to answer, and it did — a four-round design
loop with 11-to-18-minute gaps fits no ten-minute window, so on a real session it produced zero rows while
a 12-second fan-out produced one. The chain admits both and puts `gap_seconds` (`min`/`median`/`max`) on
the row. `--spawn-gap` is the idle threshold that ends a chain, not a loop threshold: raise it and
unrelated stretches of work join up; lower it toward a window width and the re-entries vanish again.

**Expect to tune before trusting.** The first runs against a new project will be noisy. A signature that
keeps producing dismissals is a threshold to adjust, and saying that out loud beats quietly ignoring it.

## FORBIDDEN

- Writing an entry that carries a credential recovered from the run. Say a value was read, not what it was.
- Reading the transcript yourself to double-check the agent. The agent judges; re-reading the run in the
  orchestrator spends the context the user is waiting on and duplicates work already done.
- Editing any instruction file from this skill — including "while we are here" fixes for a defect it found.
- Reporting a clean result without first stating which signatures could not run.
- Running this as a `Stop` hook. Transcript analysis after every turn is absurd cost for a signal that only
  matters in aggregate.
