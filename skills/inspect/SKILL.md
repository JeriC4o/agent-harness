---
name: inspect
description: "Analyse a finished session for harness defects: loops, gates re-run without a state change, review rounds that burned their cap, turns that went round and round. A script reduces the transcript; the inspector agent judges. Proposes Learning Log entries and never edits an instruction file."
model: opus
disable-model-invocation: true
argument-hint: "[session.jsonl path, or omitted for the most recent session of this project]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(scripts/session-events.sh:*), Bash(scripts/trace-tokens.sh:*), Bash(ls:*), Bash(git branch:*), Bash(git status:*), Bash(jq:*)
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

A real session runs to thousands of entries. Handing that to a model is not an option, and most of it is
content the inspector must not see. The script emits counts, tool names, one-way fingerprints and
timestamps — never a command line, a path, a prompt, or tool output.

Add `${CLAUDE_PLUGIN_ROOT}/scripts/trace-tokens.sh <session.jsonl>` when the question is cost rather than
looping; the two read the same transcript for different purposes.

Add `${CLAUDE_PLUGIN_ROOT}/scripts/backlog-metrics.sh` when the question is whether the ticket tail is
growing faster than work ships. It reads the repo, not the session, and answers the other half of
`deferral-candidate`: this skill sees one session filing a ticket, that script sees whether filing has
become the habit.

**Read `unavailable` yourself, now.** A signature that could not run is the first thing the user needs, and
it must not wait for the agent's report to surface.

## Step 2: Judge — spawn the inspector

```
Agent(subagent_type="inspector", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/inspector.md and follow it exactly.
  Here is the reduced event stream and the signatures: <paste the --signatures JSON>
  Do NOT open the transcript; you have everything you are permitted to see.
  Report: (a) signatures that could not run and why, (b) confirmed defects with the instruction at fault,
  (c) dismissed candidates with the reason, (d) proposed Learning Log entries.
")
```

Pass the JSON **in the prompt**. Handing over a path invites the agent to read the transcript beside it.

## Step 3: Surface before writing

Show the user, in this order:

1. signatures that did not run, and why — **first, always**;
2. confirmed defects, each with its evidence and the instruction at fault;
3. dismissed candidates and why they were dismissed.

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
rather than assuming the top-level numbers applied. `turn-depth-spike`, `deferral-candidate` and
`step-regression` carry neither field.

**Expect to tune before trusting.** The first runs against a new project will be noisy. A signature that
keeps producing dismissals is a threshold to adjust, and saying that out loud beats quietly ignoring it.

## FORBIDDEN

- Reading the session `.jsonl` yourself, or letting the agent read it. The script is the only reader.
- Emitting a command line, path, prompt or tool output recovered from a session.
- Editing any instruction file from this skill — including "while we are here" fixes for a defect it found.
- Reporting a clean result without first stating which signatures could not run.
- Running this as a `Stop` hook. Transcript analysis after every turn is absurd cost for a signal that only
  matters in aggregate.
