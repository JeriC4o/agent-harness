# Learning Log — JeriC4o / GH-13-trace-tokens

### 2026-09-17 — tooling — measure a proposed attribution model before building on it
**What happened:** GH-13 specified attributing token spend to "workflow stages". Two plausible stage
models were implemented and then measured against a real 558-message session. Both failed, in opposite
directions: terminating a skill's span at the next human turn dumped 95% of spend into `(no skill)`,
because the user answering `/task`'s own questions ended the stage; terminating it at the next `Skill`
invocation instead let one skill absorb 392 messages of unrelated later work. The shipped unit became a
turn — the one boundary in the transcript that is not an inference.
**Rule:** When a task specifies a heuristic for attributing data, run the heuristic against a real corpus
BEFORE building the reporting on top of it. Each model looked correct while only synthetic fixtures were
in play; the falsification cost one ad-hoc `jq` each and arrived before any of it was public.
**Kind:** validation
**Escalated?** no

### 2026-09-17 — tooling — three of the issue's stated data facts were wrong, and the tests inherited them
**What happened:** The issue asserted that summing `message.usage` per entry gives the spend, that
`isSidechain: true` marks subagent turns in the session transcript, and that a `current_step` timestamp
had to be added to `progress-format.md` first. All three were checked against real transcripts before
implementing: one API message spans several JSONL lines that each repeat the full usage object (1,021
lines for 558 messages, ~45% overcount); subagent turns are in a separate `<session>/subagents/*.jsonl`
and the session file is 100% `isSidechain:false`; and no schema change was needed at all. The first test
suite still encoded the issue's human-turn model and had to be rewritten once real data contradicted it.
**Rule:** A ticket's description of a data format is a claim, not a fact — verify each one against the
data before the tests encode it. Tests written from an unverified premise lock the premise in, and a
green suite then argues FOR the wrong design.
**Kind:** validation
**Escalated?** no

### 2026-09-17 — process — the self-review AXIOM cannot be met in a session that may not spawn agents
**What happened:** The method requires every code-producing commit on a branch with an open PR to pass
the `self-review` subagent before push. This session runs under a directive not to spawn subagents
unless the user asks, so PR #18 was pushed without that pass. The conflict was surfaced to the user
rather than resolved silently in either direction.
**Rule:** When a method AXIOM and an environment constraint conflict, say so explicitly at the point the
gate would have run — do not quietly skip the gate, and do not violate the environment constraint to
satisfy the method. A gate that was skipped must be reported as skipped, never counted as passed.
**Kind:** correction
**Escalated?** no
