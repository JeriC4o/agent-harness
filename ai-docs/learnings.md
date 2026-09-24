# Agent Learnings Log

Running log of corrections and validated non-obvious approaches. Read by the `/improve` skill.

This file is the **ARCHIVE** half of the Learning Log. **No NEW entry is authored here** — new entries go
to `ai-docs/learnings/<username>-<branch>.md` ([§ Target file](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md#target-file)).
`/improve`'s fold appends merged-branch files here verbatim at EOF.

**Never delete entries.** Only add. Use `/improve` to analyze patterns and escalate to rules.

## Format

```
### YYYY-MM-DD — [category] — [short description]
**What happened:** [quote or paraphrase of the correction/confirmation]
**Rule:** [what should happen instead, or what to keep doing]
**Kind:** correction | validation    (optional; defaults to `correction` when omitted)
**Escalated?** no | AGENTS.md | skill:[name] | hook | settings | agent:[name] | rules:[name] | templates:[name] | doc-convention | code-style | workflow | context.md | claude-tools-hierarchy (comma-separate multiple)
**Superseded by:** [ref] — [one-line reason]    (optional; omitted when not applicable)
```

Categories: `code-style` | `process` | `architecture` | `testing` | `documentation` | `tooling` | `search` | `other`

---

_(no archived entries yet)_
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
# Learning Log — JeriC4o / GH-14-inspector

### 2026-09-18 — tooling — an apostrophe inside a single-quoted shell string closed it, again
**What happened:** A jq program embedded in `scripts/session-events.sh` carried the comment "cannot see the
row's own bounds". The apostrophe closed the single-quoted shell string and `bash -n` failed on a line 70
lines away, pointing at jq syntax rather than the real cause. This is the third recurrence of the same
hazard in this repo — `rules/ast-index.md` already documents it, and a SessionStart hook broke on
"project's" earlier in this same build-out.
**Rule:** When writing a heredoc or single-quoted program that embeds another language, assert the
interior is apostrophe-free BEFORE running it — a one-line check in the generating script beats reading a
misleading syntax error. Prefer "the bounds of the row" over "the row's bounds" in any comment destined
for a single-quoted block.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — tooling — a privacy invariant held in theory and leaked in practice
**What happened:** `session-events.sh` was designed to emit only the first token of a Bash command, on the
reasoning that "git" is the same risk class as the command table in AGENTS.md. Running it on a real
transcript put `SP=/private/tmp/.../scratchpad;` into the label column: a command beginning with a variable
assignment makes the first token a path. The fixture tests all passed; only real output showed it.
**Rule:** A privacy invariant is not established by the rule that implements it — probe the real output for
the class of thing that must never appear (paths, `=`, absolute prefixes) and assert the count is zero.
Fixtures test the cases you thought of; the corpus contains the ones you did not.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — process — a proxy named in a ticket is a hypothesis, not a specification
**What happened:** GH-14 specified cache_read spikes as the proxy for "the agent re-read the same context".
Measured, cache_read trends upward all session (early ~100k, late ~14M), so a whole-session median flagged
one turn in five — noise. Per-message normalisation flattened it until nothing was an outlier. Messages per
turn separated cleanly (median 5, max 75) and shipped instead. The same thing happened in GH-13, where two
stage-attribution models both failed on contact with real sessions.
**Rule:** When a ticket names a metric or proxy, measure its distribution on real data before building the
reporting on it. Both times the falsification cost one ad-hoc `jq` and arrived before anything was public;
both times the specified proxy would have shipped a check that cries wolf.
**Kind:** validation
**Escalated?** no

### 2026-09-18 — tooling — a qualifier that exists in the design but not in one code path
**What happened:** Every repetition signature was designed to carry a time window. `repeated-agent-spawn`
computed `span_seconds` and never filtered on it. The fixture happened to place its three spawns 140s
apart, inside the window, so the suite was green; a real session then reported twelve `general-purpose`
spawns spread over a working day as a loop.
**Rule:** When a qualifier applies to a FAMILY of checks, write the negative test for each member, not for
one representative. A computed-but-unused value is the specific shape to look for: it reads as applied at
a glance and is not.
**Kind:** correction
**Escalated?** no
# Learning Log — JeriC4o / chore/backlog-metrics

### 2026-09-18 — tooling — a privacy constraint silently blocked the measurement it was written for
**What happened:** `session-events.sh` emitted only the first token of a Bash command, so `gh issue create`
and `gh pr view` were both just `gh`. When the need arose to count tickets filed mid-task, the constraint
made it impossible — and nothing in the design said so; the label simply looked adequate. The fix was an
allowlist of known subcommand verbs rather than a looser pattern, because a branch name matches any
reasonable pattern and a branch name can carry a project identifier.
**Rule:** When a redaction rule drops a field, record what questions it makes unanswerable. A constraint
that quietly removes future measurements is discovered late, at the moment the answer is needed, and the
pressure then is to loosen it hastily rather than widen it precisely.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — tooling — a text-slice patch duplicated a block instead of replacing it
**What happened:** A python patch replaced the span from `def bin_of:` to `def is_human_turn:`, assuming
that order. In the file `bin_of` came LAST, so the slice ran backwards: the old definitions were duplicated
and the stale `bin_of` shadowed the new one. `bash -n` passed, jq compiled, and five tests failed with no
hint at the cause — the symptom was a correct new definition that never ran.
**Rule:** Before replacing a span between two anchors, assert the anchors are in the expected ORDER
(`start < end`), not merely that both exist. A backwards slice silently duplicates rather than failing, and
in a language where the last definition wins, the duplicate is invisible until behaviour contradicts the
source.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — process — a negative result is evidence the detector works
**What happened:** `deferral-candidate` found nothing in either real session, and `backlog-metrics` reported
a drip share of 0 with all five tickets filed in one planning pass. The temptation was to read zero findings
as an unfinished detector. Both halves agreeing on a negative is the first evidence that the
deferral/discovery separator actually separates rather than merely sounding plausible.
**Rule:** When building a detector, state what the healthy case should look like BEFORE running it, then
report the negative result as a result. A detector that has only ever been seen firing has not been shown
to discriminate.
**Kind:** validation
**Escalated?** no
# Learning Log — JeriC4o / chore/fold-nested-guard-notes

### 2026-09-24 — tooling — a command substitution swallowed the exit status I was asserting on
**What happened:** The fold test captured a run with `out=$(run_fold ...)`, where `run_fold` assigned
`RC=$?` internally. Command substitution is a subshell, so `RC` never reached the caller and the suite
died on `RC: unbound variable`. Had the variable been pre-initialised instead of unset, every exit-status
assertion in the suite would have silently compared against a stale value — a whole class of test
assertions reporting pass while measuring nothing.
**Rule:** A function that reports an exit status must set it in the CALLER's shell — invoke it bare and
read the global, never inside `$( )`. `AGENTS.md § Tooling` already names two shapes that mask a status
(a pipeline's `$?`, a trailing `|| true`); the subshell of a command substitution is the same family and
was not on the list. When a helper both prints and reports, split the two: print to a variable the helper
assigns, return the status through the environment.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — tooling — the link checker was wrong before the links were
**What happened:** A markdown link/anchor sweep reported 26 dead anchors across the repo. Nearly all were
the checker's own defect: its slugifier collapsed runs of whitespace, while the real rule strips
punctuation and maps each remaining space to one hyphen — so `## Build & Test` is `#build--test`, not
`#build-test`. Twenty findings would have been reported to the user as repository defects. Adding a
positive control (`slug('Build & Test') == 'build--test'`) reduced the list to zero real findings.
**Rule:** A checker written for one pass is itself unverified code, and its first output is a claim about
the repository that the user may act on. Before reading a new checker's findings as findings, assert it
against one input whose correct answer is known independently. This repo already holds the rule for test
gates ("a gate that cannot fail is not a gate"); a one-off analysis script is the same object and is
usually exempted by habit because it feels like a query rather than a gate.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — testing — extracting the code under test from its shipped file, instead of copying it
**What happened:** The `/improve` fold is a shell block living inside `skills/improve/SKILL.md`. Its test
suite extracts that block with awk, anchored on a sentinel inside it, rather than holding a second copy.
It then re-runs the extracted block with one guard deleted per positive control, requiring the damage to
reappear each time. That is what exposed a second, hidden defect: the N1 newline control could not fail
while the nesting bug was present, because a wrongly-folded file happened to supply the newline N1 exists
to add. One silent bug was propping up another, and only a per-guard control could see it.
**Kind:** validation
**Escalated?** no

### 2026-09-24 — process — a PreToolUse gate reads the branch BEFORE the command runs, not during it
**What happened:** `git checkout -b <branch> && <write> && git commit` was blocked by the branch-protection
hook, which reported the branch as `main`. Correctly so: the hook inspects state at dispatch time, so the
`checkout` later in the same compound command does not exist yet from its point of view.
**Rule:** A state-changing prerequisite for a hooked command must be its OWN tool call. Chaining "enter the
allowed state" with "do the gated thing" always reads as the gated thing in the disallowed state.
**Kind:** correction
**Escalated?** no
# Learning Log — JeriC4o / chore/session-learnings

### 2026-09-24 — tooling — the apostrophe hazard, fourth recurrence, first inside hooks.json
**What happened:** Rewording a hook message to "OVERRIDES the agent's generic default" put an apostrophe
inside a single-quoted `printf` format, inside a shell command, inside a JSON string. It closed the
string. The hook died on a syntax error at dispatch and **silently stopped gating**, while `jq .` still
reported the manifest as valid JSON and the sentence read perfectly to a human. Caught only by running
the hook by hand; no existing check looked at it.
**Rule:** This hazard is already documented in `rules/ast-index.md` and already has Learning Log entries.
Three prose records did not stop a fourth recurrence, which is the threshold at which prose stops being
the answer. `scripts/test-plugin-manifest.sh` now asserts zero interior apostrophes across every hook
command, with `bash -n` on each command as an independent second leg — the apostrophe is one way the
string breaks, not the only one. Both legs were verified by re-introducing the apostrophe.
**Kind:** correction
**Escalated?** no
*(`no` is inaccurate and the inaccuracy is the finding: the rule WAS escalated, into a gate at
`scripts/test-plugin-manifest.sh`. The `Escalated?` enum has no value that can name a test or gate
script — the same shape as the `agents-method` gap just fixed, one target further out. Writing an
invented value would fail `/ai-audit` Phase 1 verification, so the field stays `no` and the truth lives
here.)*

### 2026-09-24 — tooling — the pipe-masking hook does not see a gate run through `bash`
**What happened:** Verifying an edited hook, I read its exit status from `bash -c "$cmd" 2>&1 | head -2`.
A pipeline's `$?` is the LAST command's, so it printed `rc=0` for a hook that had correctly exited 2 — I
briefly recorded a working gate as broken. The repo has a PreToolUse hook specifically for this shape, and
it did not fire. Probed directly afterwards:

    rc=2   pytest tests | head -2
    rc=0   bash -c "$cfg" 2>&1 | head -2
    rc=0   bash scripts/test-fold.sh | tail -1

The hook anchors on a list of gate binaries (`make|cargo|go|npm|pnpm|yarn|gradle|./gradlew|mvn|pytest|
shellcheck|ruff|eslint|ktlint`). `bash` is not in it — so in a repo whose entire test suite is shell
scripts, **every** `bash scripts/test-*.sh | tail` run this session was unguarded.
**Rule:** A hook that enumerates tool names does not generalise to a project whose gates are invoked
differently; its coverage is a project fact, not a method guarantee. Read an exit status un-piped, and do
not treat a clean hook run as evidence the construct was checked. Adding `bash` to that list is not
obviously safe — `bash -c '…' | jq` is a legitimate non-gate shape — so the fix needs design, not a
one-token edit.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — process — I reproduced the defect I was fixing, inside the fix
**What happened:** While writing a carve-out about references that point at the wrong file, I wrote
`AGENTS.md § Tooling` in the new text — the exact mis-attribution the surrounding work was correcting.
§ Tooling exists only in the method file. Caught only because I separately swept the class before
committing; reviewing my own addition had not caught it.
**Rule:** When fixing a defect CLASS rather than an instance, run the class sweep over the diff as well
as over the repo, and run it LAST — before the sweep, the new text is not in the corpus the sweep read.
The failure is not carelessness: a freshly-written sentence is the least suspect text in the file, which
is precisely why an author-side review misses it.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — testing — sweeping the defect class beat trusting the gate written for it
**What happened:** A reference checker written the previous day passed clean. Two defects of the same
family were then found by hand — a sync-group member pointing at a nonexistent file, and ~29 references
naming sections a consumer does not have — because the class was swept independently rather than
delegated to the gate. Each was afterwards added to the checker as a new leg and verified by
re-introducing the defect.
**Rule:** A gate written for a known defect catches that defect. The adjacent class is invisible to it by
construction, so a clean gate run is evidence about the gate's own scope and nothing wider. When a defect
is found, sweep its family by hand ONCE before extending the gate — the sweep decides what the new leg
should be, and the gate then holds the line. A gate is a ratchet, not a search.
**Kind:** validation
**Escalated?** no
