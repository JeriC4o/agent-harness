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
**Escalated?** no | AGENTS.md | agents-method | skill:[name] | hook | settings | agent:[name] | rules:[name] | templates:[name] | gate:[script] | doc-convention | code-style | workflow | context.md | claude-tools-hierarchy (comma-separate multiple)
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
**Escalated?** agent:design

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
**Escalated?** agent:design

### 2026-09-17 — process — the self-review AXIOM cannot be met in a session that may not spawn agents
**What happened:** The method requires every code-producing commit on a branch with an open PR to pass
the `self-review` subagent before push. This session runs under a directive not to spawn subagents
unless the user asks, so PR #18 was pushed without that pass. The conflict was surfaced to the user
rather than resolved silently in either direction.
**Rule:** When a method AXIOM and an environment constraint conflict, say so explicitly at the point the
gate would have run — do not quietly skip the gate, and do not violate the environment constraint to
satisfy the method. A gate that was skipped must be reported as skipped, never counted as passed.
**Kind:** correction
**Escalated?** agents-method, skill:task
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
**Escalated?** hook

### 2026-09-18 — tooling — a privacy invariant held in theory and leaked in practice
**What happened:** `session-events.sh` was designed to emit only the first token of a Bash command, on the
reasoning that "git" is the same risk class as the command table in AGENTS.md. Running it on a real
transcript put `SP=/private/tmp/.../scratchpad;` into the label column: a command beginning with a variable
assignment makes the first token a path. The fixture tests all passed; only real output showed it.
**Rule:** A privacy invariant is not established by the rule that implements it — probe the real output for
the class of thing that must never appear (paths, `=`, absolute prefixes) and assert the count is zero.
Fixtures test the cases you thought of; the corpus contains the ones you did not.
**Kind:** correction
**Escalated?** agents-method

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
**Escalated?** agent:design

### 2026-09-18 — tooling — a qualifier that exists in the design but not in one code path
**What happened:** Every repetition signature was designed to carry a time window. `repeated-agent-spawn`
computed `span_seconds` and never filtered on it. The fixture happened to place its three spawns 140s
apart, inside the window, so the suite was green; a real session then reported twelve `general-purpose`
spawns spread over a working day as a loop.
**Rule:** When a qualifier applies to a FAMILY of checks, write the negative test for each member, not for
one representative. A computed-but-unused value is the specific shape to look for: it reads as applied at
a glance and is not.
**Kind:** correction
**Escalated?** agents-method
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
**Escalated?** rules:ast-index

### 2026-09-18 — process — a negative result is evidence the detector works
**What happened:** `deferral-candidate` found nothing in either real session, and `backlog-metrics` reported
a drip share of 0 with all five tickets filed in one planning pass. The temptation was to read zero findings
as an unfinished detector. Both halves agreeing on a negative is the first evidence that the
deferral/discovery separator actually separates rather than merely sounding plausible.
**Rule:** When building a detector, state what the healthy case should look like BEFORE running it, then
report the negative result as a result. A detector that has only ever been seen firing has not been shown
to discriminate.
**Kind:** validation
**Escalated?** agent:design
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
**Escalated?** agents-method

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
**Escalated?** rules:ast-index

### 2026-09-24 — testing — extracting the code under test from its shipped file, instead of copying it
**What happened:** The `/improve` fold is a shell block living inside `skills/improve/SKILL.md`. Its test
suite extracts that block with awk, anchored on a sentinel inside it, rather than holding a second copy.
It then re-runs the extracted block with one guard deleted per positive control, requiring the damage to
reappear each time. That is what exposed a second, hidden defect: the N1 newline control could not fail
while the nesting bug was present, because a wrongly-folded file happened to supply the newline N1 exists
to add. One silent bug was propping up another, and only a per-guard control could see it.
**Kind:** validation
**Escalated?** agent:self-review

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
**Escalated?** gate:test-plugin-manifest, hook
*(`no` is inaccurate and the inaccuracy is the finding: the rule WAS escalated, into a gate at
`scripts/test-plugin-manifest.sh`. The `Escalated?` enum has no value that can name a test or gate
script — the same shape as the `agents-method` gap just fixed, one target further out. Writing an
invented value would fail `/ai-audit` Phase 1 verification, so the field stays `no` and the truth lives
here.)*
**Superseded by:** the parenthetical above is stale — `gate:[script]` now EXISTS in the `Escalated?`
enum (`ai-docs/learnings.md` § Format and `docs/corrections-log.md`), so the field was backfilled to
`gate:test-plugin-manifest, hook` while the note still says it stays `no`. The field is authoritative;
read the parenthetical as the history of why it was once `no`. Recorded as a field update rather than a
prose edit because Boundary rule 1's exception covers `Escalated?` and `Superseded by:` only.

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
**Escalated?** hook
**Superseded by:** 2026-09-26 (I routed a test suite through a filter to shorten its output) — the hook gained a shell-interpreter leg and fired on that spelling; the residual loop / null-redirect / variable-path gap is closed by the 0.1.22 guard legs.

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
**Escalated?** rules:ast-index

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
**Escalated?** agent:self-review
# Learning Log — GH-29-harness-feedback-channel

### 2026-09-25 — gate-discipline — piped a test suite through `tail -1` one paragraph after instructing a subagent not to
**What happened:** Verifying Group A's return, I ran `bash scripts/test-promotion.sh 2>&1 | tail -1`
to see the summary line. A pipeline's rc is the last command's, so `tail` would have reported success
over a failed suite. I had written the prohibition into the Group A spawn prompt minutes earlier, in
those words, and named the hook that normally catches it as NOT loaded in this session. I appended
`echo "NOTE: piped - rerunning bare next"` to the same call, which shows the violation was recognised
as it was typed rather than discovered afterwards — and typed anyway.
**Rule:** Reading one line out of a gate's output is not a reason to pipe it. Run the gate bare and
read the summary off the bottom of the full output; the whole point of the rule is that the rc must
reach the tool boundary. Recognising the violation mid-keystroke is not a mitigation — abandon the
call and retype it, do not annotate it and send it. The annotation is worse than silence: it converts
a slip into a deliberate act.
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-25 — tooling — `sed` substitution delimiter collided with `|` inside the replacement text, second occurrence
**What happened:** Updating `**last_passed_gate:**`, whose canonical format is
`<gate> | <timestamp> | <commit>`, I wrote `sed "s|^\*\*last_passed_gate:\*\* .*|...|"` — the `|`
delimiter met the format's own `|` separators and `sed` failed with `bad flag in substitute command`.
The same collision, with the same delimiter, is already in this corpus from an earlier branch.
**Rule:** Before choosing a `sed` delimiter, look at the REPLACEMENT text, not only the pattern. When
the replacement is a structured line whose format contains separators, do not use `sed` at all — use
the `Edit` tool, which takes both sides literally and needs no delimiter. A recurrence of a known
delimiter collision is a signal to change tools, not to change the delimiter.
**Kind:** correction
**Escalated?** rules:ast-index

### 2026-09-25 — verification — a subagent's "N pre-existing assertions untouched" is a claim about a diff, so check the diff
**What happened:** Group A reported "the 25 pre-existing assertions are byte-identical" alongside
`+178/−0`. Both are checkable and neither is checked by reading the suite's output: a suite that
prints 138 `ok` lines proves nothing about whether the original 25 still assert what they used to.
`git diff scripts/test-promotion.sh` showing **zero** deleted lines is what substantiates it.
**Rule:** When a subagent claims prior coverage survived its change, verify it against the DIFF, not
against the new run. A green suite is consistent with an assertion having been silently rewritten to
match new behaviour; only the absence of deletions in the region rules that out.
**Kind:** validation
**Escalated?** agent:self-review

### 2026-09-25 — gate-discipline — wrapped seven gates in a `for` loop with `>/dev/null` and `|| echo`, third occurrence this session
**What happened:** To run the remaining item-4 suites I wrote
`for s in ...; do printf '%s: ' "$s"; bash scripts/$s.sh >/dev/null 2>&1 && echo PASS || echo "FAIL rc=$?"; done`.
Three separate prohibitions in one line: a `for` loop exits with the LAST iteration's status, the
gate's output was discarded rather than read, and `|| echo` swallows the rc. AGENTS.md check 4 names
the `for`-loop shape explicitly, in the same file I had read at session start. All seven happened to
pass, which is why nothing surfaced.
**Rule:** Batching gates is the temptation; parallel bare tool calls are the answer, and the method
file says so in as many words — "Run independent diagnostics as parallel tool calls". The construct
is the violation whether or not the gates passed. Three occurrences in one session, all by the
orchestrator, all while the hook that would have blocked them was on disk but not loaded: the
enforcement gap and the behavioural gap are independent, and neither covers the other.
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-25 — gate-coverage — `git ls-files`-based checks are blind to new, untracked files
**What happened:** AGENTS.md check 4 mandates `git ls-files -z '*.sh' | xargs -0 -n1 bash -n` as THE
spelling, because the three natural alternatives return rc 0 on a file that does not parse. But
`git ls-files` lists TRACKED files only. With two new scripts created and not yet added, the gate
covered 22 files and silently skipped exactly the two it most needed to check. A subagent noticed and
ran `git add -N skills/report-defect` (intent-to-add, no content staged), after which the count went
to 24 and the gate became real. `check-release.sh`'s working-tree diff was blind to the new directory
for the same reason.
**Rule:** When a gate enumerates its inputs from the git index, new files are outside it until they
are at least intent-added. On a task that CREATES files, run `git add -N <new paths>` before treating
any `git ls-files`-driven gate as having covered the change — and check the file COUNT the gate
processed, not just its exit status. A gate that silently narrows its own input set is the quietest
false green there is.
**Kind:** correction
**Escalated?** AGENTS.md

### 2026-09-25 — validation — an instruction repeated verbatim in a spawn prompt did not prevent the violation
**What happened:** Both subagents were given the no-piped-gates rule in their spawn prompt, in the
rule's own words, with the note that the enforcing hook was not loaded this session. Group B still
piped `test-session-events.sh` through `tail` once — caught it, re-ran bare, and reported both facts
unprompted. The orchestrator violated the same rule three times over the same period.
**Rule:** Keep stating the rule in spawn prompts — Group B's self-catch and honest disclosure is the
behaviour that instruction produced, and it is worth its cost. But do not treat in-prompt restatement
as equivalent to enforcement: measured this session, it reduced neither the orchestrator's nor the
subagent's violation rate to zero. The loaded hook is the control; the prompt is a reminder.
**Kind:** validation
**Escalated?** skill:task

### 2026-09-25 — gate-discipline — fourth piped gate in one session, after logging the first three
**What happened:** To inspect the new rows I ran `bash scripts/test-promotion.sh 2>/dev/null | grep -E …`
and appended `echo "--- suite rc checked separately below ---"`. Same construct and same annotation
habit as the first occurrence, which is already an entry in this file. Three prior entries in this
same session did not prevent it. The genuine need — seeing twelve specific lines out of a long
suite — is real, and piping is the reflex that meets it.
**Rule:** The need to read a SUBSET of a gate's output is the actual trigger for this violation, and
it recurs because nothing in the workflow answers it. Two constructs do, and neither masks the rc:
redirect to a file in one call and read the file in another (`bash suite.sh > "$SCRATCH/out" 2>&1`
then grep the file), or run the gate bare and accept the full output. **A note saying the rc will be
checked separately is not a mitigation — it is the tell.** Four occurrences in one session, all with
the rule loaded in context and three already written down, is evidence that a logged rule does not
change same-session behaviour; only the hook does, and the hook is not loaded here (issue #43).
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-25 — verification — a substring match was recorded as a verbatim quotation and propagated into five artefacts
**What happened:** I ran `grep -rn 'Rewrite the lesson' scripts/ skills/ docs/` and got two hits: the
gate's `printf` and `skills/improve/SKILL.md:118`. I reported this as "`improve/SKILL.md` quotes that
wording as the documented workflow", making the trailer "a two-file contract". The gate prints
`Rewrite the lesson so it names the SHAPE of the failure, not the instance.`; `SKILL.md:118` says
`Rewrite the lesson; never edit the gate, and never work around it`, and `:111` separately says
`Write the SHAPE of the failure, never the instance.` Different verb, different negation, seven lines
apart. The exact-string search returns **zero** hits. The false premise reached two spawn prompts,
three design sentences and two comments in shipped code, and survived two design-review rounds. It
was caught by self-review round 2, which ran the verbatim search.
**Rule:** "File X quotes Y" is a claim about an EXACT STRING and is verified only by searching for
that exact string. A grep pattern short enough to match is not evidence of a quotation — it is
evidence of a shared phrase. When about to write "quotes", "verbatim", "the same sentence", or "a
two-file contract", run the full-sentence search first and paste its output; if it returns nothing,
the correct word is "describes" or "paraphrases", and the coupling being claimed is weaker than the
sentence asserts.
**Kind:** correction
**Escalated?** agent:self-review

### 2026-09-25 — delegation — orchestrator-supplied "context" is laundered into artefacts as measured fact
**What happened:** The false quotation claim above was not discovered by either design-review round,
because by then it lived in the design document as an apparently-measured statement. The path was:
my reading → a spawn prompt's context section → the design → two shipped comments. A subagent has no
way to tell which lines of a spawn prompt were measured and which are the orchestrator's paraphrase;
everything in that section arrives with equal authority. The one time it failed to propagate this
session was when I wrongly told self-review that the refusal trailer was "recorded in the design" —
that agent re-derived it with grep, found zero occurrences, and said so. So the declining behaviour
exists but fires inconsistently.
**Rule:** In a spawn prompt, mark every factual claim with how it was obtained — "measured, output
below" versus "my reading, re-derive it". Prefer pasting the command and its raw output over stating
the conclusion drawn from it. When a subagent's task depends on a claim, say explicitly that it must
verify rather than inherit it. Facts travel further than their provenance, and an artefact written
from an unmarked paraphrase is indistinguishable from one written from a measurement.
**Kind:** correction
**Escalated?** skill:task

### 2026-09-25 — validation — the review chain caught what every earlier layer passed
**What happened:** Across this task the layers caught, in order: self-review round 1 found that the
138-assertion suite could not discriminate the design's chosen mechanism from the one it explicitly
rejected (the mutation survived untouched); design-review round 1 found a false measurement the
design contradicted four lines later; design-review round 2 found five stale pointers and ruled on an
open judgement using in-tree precedent; the note-folding pass found three size statements beyond the
list it was given and two more issues it declined to fix unasked; self-review round 2 found the
quotation claim. Every layer found something no earlier layer had, and none of them re-litigated a
settled decision.
**Rule:** Keep the evaluator-optimizer chain even when each round looks like it is finding only
wording. The findings were not cosmetic: the round-1 major was a gate that could not fail, and the
round-2 major was a false premise already shipped in code comments. **Also keep instructing each
agent to distrust the supplied list of affected locations** — three separate rounds found that such a
list was incomplete, which is the single most reliable finding-generator observed here.
**Kind:** validation
**Escalated?** agent:self-review

### 2026-09-25 — test-fidelity — the suite invoked the script differently from how the skill invokes it, hiding a rc-126 blocker
**What happened:** `skills/report-defect/SKILL.md` invokes `"${CLAUDE_SKILL_DIR}"/scripts/file-report.sh`
directly by full path. The file was committed `100644`, so a consumer following the skill gets
`permission denied`, exit 126, on the skill's second step. Every one of the suite's 76 assertions ran
it as `bash "$PROD"`, which does not need the execute bit — so the suite was green precisely because
it did not run the script the way the skill runs it. Five review rounds (three self-review, two
design-review) missed it; the delivery gate missed it because it asserts a file *reached* the install,
not that it is *runnable*. This repo had already hit this exact defect on `scripts/session-events.sh`
and had already written the assertion for it in `scripts/test-session-events.sh` — the lesson was
recorded and the bug shipped again on the next script.
**Rule:** A suite must invoke the entry point **the way its caller invokes it**. When a skill calls a
script by path, at least one assertion must call it by path, or must assert `[ -x ]` directly — the
`bash <path>` form is convenient and it silently removes the execute bit from the contract. Check the
committed **mode**, not just the content: `git ls-files -s '*.sh'` shows it, and in this repo
everything under `skills/*/scripts/` is `100755`. Generalisation worth keeping: when a defect class
already has a named assertion somewhere in the tree, adding a new file of the same kind means copying
that assertion, not trusting that the lesson transferred.
**Kind:** correction
**Escalated?** agents-method
# Learning Log — GH-34-deferral-turn-selfcompare

### 2026-09-24 — tooling — the apostrophe hazard, fifth recurrence, and I ran the suite before the syntax check
**What happened:** Writing a comment INTO an embedded jq program, I typed `this turn's`. The jq program
lives in a single-quoted shell string, so the apostrophe closed it and the remainder became shell. I
then ran the test suite, which reported **50 failures across every unrelated section** — and spent the
next minutes reading that wall before recognising the shape. `bash -n` on the same file returns rc 2
and names the exact line. The cheap check would have localised it immediately; I ran the expensive one
first.
**Rule:** After editing a shell script — especially one carrying an embedded program in quotes — run
`bash -n <file>` BEFORE running any suite that executes it. A syntax check is O(1) and points at a
line; a suite failure is O(n) assertions and points nowhere. When a suite fails broadly across
sections that the change could not possibly touch, that shape IS the signal: suspect the file itself,
not the assertions. And the apostrophe hazard now has five recurrences: prefer a phrasing without one
whenever writing prose inside a quoted program — `the matching turn` rather than `this turn's`.
**Kind:** correction
**Escalated?** hook

### 2026-09-24 — testing — the fixture that cannot discriminate needs its own guard
**What happened:** The existing coverage for this signal used a session with ONE depth spike. With one
spike, reading the matching row and reading the first row return the same row, so a self-comparison in
the lookup passed unnoticed for as long as the code existed. The new fixture uses two spikes of
different depth — and carries an explicit assertion that the two depths DIFFER, because if a later
edit made them equal the discriminating assertion would silently degrade into one that passes against
the defect.
**Rule:** When a test distinguishes "the matching element" from "some element", the fixture must
contain at least two candidates AND assert that they differ in the field under test. Without that
guard the test's discriminating power depends on a fixture property nothing checks, which is the same
class as a positive control: state what must be true for the assertion to mean anything, and assert it.
**Kind:** correction
**Escalated?** agents-method
# Learning Log — GH-37-fold-sync-group

### 2026-09-24 — process — five times in one branch I replaced a false universal with a narrower false universal
**What happened:** A sequence, not five separate slips. (1) "the script already applied a time window
and an intervening-edit check" → (2) "every signature carries `filters` and `threshold`", true of
three kinds of six → (3) a README restatement, false for the same three → (4) "a derivation mismatch
does not fail loudly", which a guard I had added an hour earlier made false → (5) "an anchor row plus
a back-reference, as the Task/Design and Fold groups do", false of three of the five qualifying
groups, and shipped WITH an audit clause enforcing it → (6) "`project-review` and `self-review` reach
the group through the Review row", a route that does not exist. Every one was caught by review; none
by me. The rule forbidding exactly this went into `rules/ast-index.md` during the same session, and I
broke it four times after writing it.
**Rule:** A replacement claim inherits the ORIGINAL's burden of proof in full — a quantifier that
shrank is not a quantifier that was checked. Before writing "every / each / all" in a correction,
enumerate the members it now quantifies over and verify the claim against each one, by reading them,
not by reasoning about them. The failure is not carelessness about facts; it is treating the
replacement sentence as lower-stakes than the sentence being replaced, when it is the one that will
be believed next.
**Kind:** correction
**Escalated?** rules:ast-index

### 2026-09-24 — tooling — I wrote a guard that could not fire on the case it existed for
**What happened:** Adding a gate that the scaffolded copy of a contract matches the live one, I
guarded the comparison on both files existing. Deleting the copy then produced exit 0 and a success
line stating the contract resolves. Absence is the worse half — a stale copy ships an out-of-date
contract, a missing one ships none at all — so the guard hid precisely the case worth catching, while
the profile sentence I wrote alongside claimed the mirror was enforced.
**Rule:** When a check compares two things, the absence of either is a distinct finding, not a reason
to skip the check. An existence guard around a comparison converts the most severe case into a silent
pass. Before writing `if [ -f A ] && [ -f B ]`, ask which of A-missing, B-missing and A-differs-from-B
is the worst outcome, and make sure the code reports it.
**Kind:** correction
**Escalated?** gate:check-references
# Learning Log — GH-43-documented-update-procedure

### 2026-09-25 — tooling — I piped a gate through `tail` inside the very task whose subject is a fake green
**What happened:** Running the AGENTS.md check-4 suites for Task 7, I invoked
`bash scripts/test-audit-project.sh 2>&1 | tail -3` to keep the output short. The task brief had just
restated the rule verbatim ("NEVER pipe a gate through head/tail/grep — a pipeline's rc is the LAST
command's"), and the method file states it too. The rc I read was `tail`'s, so the suite's own status was
discarded; the run happened to be green, which is exactly why the shape is dangerous. The
`gate-pipe-guard` hook did not fire on this spelling. I re-ran it bare and it was genuinely 14/0, but the
first invocation measured nothing.
**Rule:** Limit a gate's output with the gate's own flags, never with a pipeline. A long green suite is
not a reason to pipe — read the full output. The rule binds on the CONSTRUCT as written, not on whether
the gate happened to pass.
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-25 — tooling — the orchestrator repeated the piped-gate violation one turn after logging it
**What happened:** Verifying Group C's work, I ran the install smoke gate as
`bash scripts/test-install-smoke.sh 2>&1 | tail -5` with `rc=${PIPESTATUS[0]}`. Two faults in one line.
First, the pipe itself — the same construct the entry above this one had just recorded, in the same
session, on the same branch. Second, `PIPESTATUS` is a bash array; this shell is zsh, where the spelling
is `$pipestatus[1]`, so the substitution expanded to nothing and the output literally read `rc=` — I
asked for an exit status and got an empty string. The method file names both faults explicitly, adjacent
to each other, and I had quoted that same passage to three subagents in their briefs. I re-ran the gate
bare: 33 passed, 0 failed, rc 0.
**Rule:** Reading a rule to someone else does not install it. Before a gate invocation, check the command
for a pipe and for `$?`/`PIPESTATUS` after one; if output length is the motive, use the gate's own flags
or read the whole thing. Note also that a recurrence one turn after the log entry means the log is not
the enforcement mechanism — the construct has to be checked at the moment of writing the command.
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-25 — validation — the `gate-pipe-guard` hook did not fire on either piped-gate invocation
**What happened:** Two independent piped-gate invocations in this session — a subagent's
`bash scripts/test-audit-project.sh 2>&1 | tail -3` and the orchestrator's
`bash scripts/test-install-smoke.sh 2>&1 | tail -5` — were both allowed through. Neither was blocked.
`hooks/lib/test-harness-managed.sh` carries a passing assertion named "a shell test suite piped into tail
is blocked", so the hook's own suite is green on a case its live matching appears to miss. Two data
points from different agents, same result. NOT investigated or fixed — out of scope for GH-43, and the
session was running the 0.1.12 plugin payload while the repo is at 0.1.19, so a version skew between the
loaded hook and the tested one is a live hypothesis that must be ruled out before anything is concluded.
**Rule:** Record, do not act. Before treating this as a hook defect, re-test from a session started on
the current plugin version — the installed payload and the working tree were five versions apart for
most of this session, which is itself the bug this branch fixes. If it reproduces on a current session,
it is the same class as GH-43 (a check whose green comes from a configuration where it cannot fail) and
deserves its own ticket.
**Kind:** validation
**Escalated?** no
**Superseded by:** 2026-09-26 (I routed a test suite through a filter to shorten its output) — re-probed against the current payload, the hook fired; the version-skew hypothesis this entry asked to rule out is resolved.

### 2026-09-25 — tooling — third piped-gate invocation, this time to read an experiment's result
**What happened:** Checking the Round-2 finding that a deleted guard goes unnoticed, I ran
`bash scripts/test-check-readme-update.sh 2>&1 | tail -2` to see only the totals. Third instance in one
session, after two entries above already recording it. The excuse available to me — "this is an
experiment, not a gate run for a pass/fail decision" — is precisely the reasoning the method file
forecloses: the rule binds on the CONSTRUCT as written, not on whether the gate happened to run or on
what I intended to do with the result. On the second, identical experiment I wrote
`… > /tmp/sabotage.out 2>&1; echo "suite rc=$?"` and then grepped the FILE, which reads the status from
the unpiped command and still keeps the output short.
**Rule:** When you want a long gate's summary line, redirect to a file and grep the file — never pipe the
gate. The redirect keeps `$?` attached to the gate; the pipe hands it to `tail`. Three occurrences in one
session means the construct is a reflex, so the check belongs at the moment of composing any command whose
first word is `bash` and which contains a `|`.
**Kind:** correction
**Escalated?** agents-method, hook
# Learning Log — chore/improve-escalation

### 2026-09-24 — process — the fold ran with its skip-self guard protecting a phantom, and I watched it happen
**What happened:** Running `/harness:improve`'s fold, the derivation printed
`self=ai-docs/learnings/jc-chore-improve-escalation.md` — a path that has never existed in this
repository, because every entry file is named from the git identity while the documented source was
the OS account. The guard that skips "self" compares composed paths, so for the whole run it
protected a file that does not exist. Nothing failed, nothing warned, and the fold reported success.
The live entry file survived only because it happens to be unmerged, so the byte-identity test
rejected it — the second guard doing the first guard's job by luck.
**Rule:** When two places derive the same name independently, a divergence between them is silent by
construction: each side is internally consistent and neither can see the other. Before trusting a
guard that works by comparing a derived identifier against reality, print the derived value once and
look at it against what is actually on disk. And when a guard's protection depends on a derivation,
the gate must exercise the REAL derivation — a suite that stubs it out tests the guard against a
premise it supplied itself.
**Kind:** correction
**Escalated?** templates:learnings-entry-format, skill:improve

### 2026-09-24 — process — I read a skill's own commentary as evidence that its guards worked
**What happened:** The fold block in `skills/improve/SKILL.md` carries several paragraphs of careful
reasoning about which guard catches which failure shape, naming a five-stub set and explaining why
each stub is load-bearing. I took that as evidence the guard set was sound. It is not evidence: the
suite stubs the derivation out entirely, so the one function every guard's correctness depends on had
never run under test, and the prose reasoned about a scenario no gate ever entered. This repository
has shipped exactly this shape before — commentary reasoning about what a gate would catch, while no
gate existed.
**Rule:** Prose about a guard is a claim about the guard, at the same evidentiary level as a comment
claiming an invariant — not a substitute for seeing the guard fail. Before accepting that a guard set
is complete, check what the gate actually stubs: whatever is stubbed is precisely what has never been
tested, and it is usually the thing the prose is most confident about.
**Kind:** correction
**Escalated?** workflow, agent:review-findings

### 2026-09-24 — process — third recurrence: I replaced a false universal with a narrower false universal
**What happened:** Three times in one branch. A claim that the script "already applied a time window and
an intervening-edit check" became "every signature carries `filters` and `threshold`" — false for three
kinds of six. Corrected, that became a README sentence saying "each signature reports which qualifiers
ran" — false for the same three. And after adding the derivation guard I wrote that a mismatch "does not
fail loudly", which the guard I had just added made false in exactly the case that matters. Each
replacement was narrower than the last and still wrong; each was caught by a reader, never by me.
**Rule:** When a fix REPLACES a universal claim, the replacement inherits the original's burden of proof
in full — enumerate the members it now quantifies over and check the claim against each, before writing
it. A quantifier that shrank is not a quantifier that was verified. Treat "every / each / all" in text
you are about to write as a claim requiring the same evidence as an asserted invariant in code.
**Kind:** correction
**Escalated?** rules:ast-index

### 2026-09-24 — tooling — a documented gate was spelled in a way that could not fail
**What happened:** The profile named the lint gate as `bash -n` on every `*.sh`. Tested against a
deliberately broken fixture, three of the four natural spellings report success: `-exec bash -n {} +`
batches, so only the first file is parsed and the rest become positional parameters — rc 0 with no
output at all; `-exec … \;` prints the error and `find` still exits 0; a `for` loop exits with the last
iteration's status. I had personally written two of those three forms earlier in the same session.
**Rule:** A gate named in prose is not yet a gate — the spelling is part of it. When a profile or
instruction file mandates a check, mandate the exact invocation and verify it FAILS on a planted defect;
"run X over every Y" leaves the composition to the reader, and the readings that mask a failure are the
ones that look most natural. This is the gate-that-cannot-fail rule applied to the gate's own definition.
**Kind:** correction
**Escalated?** AGENTS.md

### 2026-09-24 — process — a contract calling itself complete shipped incomplete to every consumer
**What happened:** The fold contract lists its filters "in order" and is cited elsewhere as the full
contract. It carried four of six filters and none of the derivation guards, and its byte-identical copy
is scaffolded into every consuming project — so anyone implementing the fold from it ships one without
the guard that prevents permanent loss. Found by a clean-context agent, not by me, although I had edited
the fold twice that hour and cited that very file.
**Rule:** A file that calls itself the full contract for a mechanism must be re-read against the
mechanism whenever the mechanism changes, and the claim of completeness is what makes it a defect rather
than a summary. When the same file ships as a template, a gap there reaches consumers who cannot see the
implementation it describes.
**Kind:** correction
**Escalated?** workflow, agent:review-findings
# Learning Log — chore/inspector-defects

### 2026-09-24 — tooling — I piped a gate through `tail` and joined it with `&&` in one call
**What happened:** After setting the execute bit I ran the suite as
`chmod +x … && git diff --summary … && bash scripts/test-session-events.sh 2>&1 | tail -3`.
That suite is a GATE. A pipeline's exit status belongs to `tail`, and the `&&` chain hides which
member failed. The run happened to be green and I re-ran it bare immediately, but the masked form
is the violation, not the outcome.
**Rule:** `agents-method.md` § Tooling — each gate runs as its OWN Bash call, never joined with
`&&` / `;`, never piped through `head` / `tail` / `grep`. Limit output with the tool's own flags.
The rule binds on the CONSTRUCT as written, not on whether the gate happened to pass. Same turn, a
second instance: a `for … do bash -n "$f" || echo FAIL; done` sweep, where `|| echo` swallows the
non-zero status the sweep exists to surface — replaced with
`git ls-files -z '*.sh' | xargs -0 -n1 bash -n`, which actually fails.
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-24 — testing — I wrote a cosmetic test and my own positive control caught it
**What happened:** Fixing a regression where a non-string timestamp killed the whole report, I added a
test built on ONE event. It passed. Then the mutation control — revert the guard, expect red — produced
**zero** failures. A single event never forms a repetition group, so the span computation the test
existed to exercise was never reached: the test passed identically with and without the fix. Rebuilt on
three grouped events; it then went red under mutation and green with the guard.
**Rule:** A green test proves nothing until it has been seen RED for the right reason. Run the mutation
before believing the assertion, not after — and when a fixture exercises code reached only through a
grouping, aggregation or filter, build the fixture so that path actually runs. The harness already
states this as "mentally comment out the production fix; if the test still passes it is cosmetic → REJECT";
the mental version is weaker than the executed one.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings

### 2026-09-24 — process — my propagation sweep searched the instruction files and missed the code I was fixing
**What happened:** After editing a claim in an agent definition I swept for its terms across the
instruction directories and found one further copy, which I fixed. Self-review found two more: the header
comment of the very script the fix was editing, and the repository's front page. Both stated the same
false universal, and both shipped in the version this PR bumps.
**Rule:** A propagation sweep is scoped by the CLAIM, not by the directory an instruction file lives in.
Sweep the file being edited (a long header comment is an instruction file with a different extension) and
the reader-facing entry points — README and equivalents — not only the instruction tree. And when a fix
replaces a false universal, check the replacement is not a narrower false universal: "every X" became
"every signature" and was wrong for half the kinds.
**Kind:** correction
**Escalated?** rules:ast-index

### 2026-09-24 — testing — every fixture used a timestamp spelling the production input never has
**What happened:** `scripts/test-session-events.sh` carried two passing time-window tests and a
passing span assertion while the window filter was dead against real transcripts. A count of
fractional-second timestamps across the whole suite returned **0**: every fixture wrote whole-second
times, which is exactly the spelling jq's `fromdateiso8601` accepts — and the millisecond spelling a
live transcript always writes is the one it rejects. The suite could not see the defect it was
written to cover, and stayed green through ten releases.
**Rule:** A fixture that differs from production input in the field the code PARSES is not a fixture
for that code. When a gate reads a format, pin at least one fixture to the real thing byte-for-byte.
And when a parse carries a `catch`, test the catch's own branch: what a failed parse YIELDS is the
behaviour under test, and a failure value that satisfies the comparison it feeds turns the gate into
a silent pass.
**Kind:** correction
**Escalated?** agents-method
# Learning Log — chore/inspector-sees-the-run

### 2026-09-26 — process — a review cap that counts rounds cannot stop a loop that is not about the code
**What happened:** In one `/task` run the design-review loop took 4 rounds over 59 minutes and the
self-review loop burned all 3 of its rounds, ending on a REJECT whose `major` was a green-reporting gate
introduced by the previous round's own fix. The four post-cap fixes then reached commit with no review
round at all. Mid-run the agent diagnosed it itself — "the code converged long ago; the document is
looping" — measured a 113,677-byte design against a 1,049-line implementation on an increment the user
had scoped as one increment, and observed that the last two and a half rounds changed "neither the code,
nor the verdict, nor a single claim". It then had to invent a stopping rule on the spot and ask the user
for permission to depart from the recipe.
**Rule:** A review loop's exit condition must read what a round FOUND, not only how many rounds have run.
State, at the cap site, what makes another round worth spending — a new `major` / blocker against code, or
against a claim that is actually false — and say explicitly that a round returning only prose-consistency
findings about a design document is fixed as text without re-entering review. State separately that fixes
made after the cap is burned still get one review pass, as post-push fixes already do.
**Kind:** correction
**Escalated?** skill:task, agent:design-review

### 2026-09-26 — tooling — step-regression flags the workflow's own loop-back, and fires on the APPROVE that ends it
**What happened:** The session's only step-regression, 11 → 10, was the progress write
`**current_step:** Step 10 — self-review APPROVE (Round 3)` — the success path terminating the loop.
`skills/task/SKILL.md:157` and `:186` mandate that exact edge on every REJECT round, so the row is emitted
by every `/task` run that takes any review round, and again on the APPROVE that ends it.
`scripts/session-events.sh:328` compares step numbers with no exception, and `agents/inspector.md:68`
pushes the whole judgement onto the reader with no marker to read.
**Rule:** A detector must not report a transition its own workflow prescribes. Either exclude the
documented Step 11 → Step 10 edge, or carry the progress line's own text on the row so the reader can
separate a REJECT loop-back and a terminating APPROVE from a genuine skip without re-opening the
transcript.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — the spawn window admits fan-outs and excludes the re-entries it exists to catch
**What happened:** `agents/inspector.md:64` says spawns seconds apart are a fan-out to dismiss and spawns
minutes apart are re-entries to confirm. `scripts/session-events.sh:267-273` bins Agent spawns through a
600-second sliding window, which cannot hold a burst wider than ~10 minutes — so the confirm case is
structurally excluded. Measured: a 5-spawn design loop with four ITERATE rounds, spread 17:37 to 18:36
with gaps of 11 to 18 minutes, produced zero rows; the two rows that did fire were a 4-spawn fan-out 12
seconds wide and a 425-second burst. Both the qualifier and the shared window default were written in the
same session, the window deliberately left shared on the reasoning that a second knob was not worth it.
**Rule:** When a qualifier names the time gap as the thing that separates confirm from dismiss, the
detector must not use that same gap as its admission filter. Group repeated spawns of one
`subagent_type` over the whole session or the turn, report the gap distribution, and let the qualifier do
the separating. More generally: after adding a qualifier, check what the admission filter lets reach it.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — a subagent hand-back opens a counted turn, so a delegating deep turn is split below the spike threshold
**What happened:** `scripts/session-events.sh:121-126` counts any user-string entry not prefixed
`task-notification`, `local-command-` or `system-reminder`. On one session 22 of the 91 reported turns
were not human turns: 14 inbound subagent hand-backs, 6 terminal-echo entries, 2 compaction entries. A
subagent result arriving as a task-notification is excluded while the same result arriving as an
inter-session hand-back opens a turn. One instruction whose work ran 27 minutes across 3 design spawns
was chopped into five counted turns by four hand-backs and none was flagged, while a comparable stretch
whose subagents returned as task-notifications was flagged at factor 5.
**Rule:** A turn boundary is a HUMAN instruction. Exclude inbound agent-to-agent messages, terminal-echo
entries and compaction blocks from the turn count the same way task-notifications are already excluded,
so that delegating and non-delegating work of equal size are measured alike.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — deferral-candidate misses a ticket drafted in the deep turn and filed in the next
**What happened:** `scripts/session-events.sh:313-314` requires the `gh issue create` call itself to land
in a spike turn. On one session two issue bodies were drafted as the final two actions of the deepest
turn in the run, immediately after a review round, and the create calls executed in the following,
ordinary turn. The detector reported nothing. This is the same shape as the self-comparison bug fixed at
line 316 in that session, one step narrower.
**Rule:** A deferral is decided where it is drafted, not where the command runs. Attribute a ticket to
the turn that produced its body, or widen the window to the turn immediately following a spike, so that
the cheap exit is visible wherever the two steps are split.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — I routed a test suite through a filter to shorten its output
**What happened:** Running the pre-commit suites, I wrote a call that ran one suite into a pager and then
re-ran it discarding stdout, to avoid printing 159 lines. The `gate-pipe-guard` hook blocked it. A
pipeline exits with the status of its LAST member, so a failing suite reports success that way — the
masking `docs/agents-method.md` section Tooling enumerates. The second half was no better: discarding
stdout throws away the line that says WHICH assertion failed, so even a correct exit status would have
left nothing to read. The motive was saving context, which is not a reason the rule admits.
**Rule:** A gate runs bare, as its own call, and its full output is read. Long output is the cost of the
gate, not a problem to route around — bound it with the tool's own flags where it has them, otherwise
read it. Wanting a shorter transcript is never a reason to weaken a check.
**Kind:** correction
**Escalated?** agents-method, hook

### 2026-09-26 — tooling — I quoted a blocked command inside a shell heredoc and the hook blocked the write
**What happened:** Writing the entry above, I appended it to the Learning Log with a heredoc whose TEXT
quoted the very construct the entry was about. `gate-pipe-guard` matches the literal command string, so
it fired on the prose rather than on an invocation. A memory note already records this exact lesson and
names the remedy; I had it and did not apply it.
**Rule:** When the text being written quotes a construct a PreToolUse hook matches, write it with the
Write or Edit tool, never a shell heredoc. The hook reads the command string and cannot tell a citation
from a call. Applies equally to commit messages, issue bodies and log entries.
**Kind:** correction
**Escalated?** workflow, hook
# Learning Log — JeriC4o / GH-60-loop-index

### 2026-09-26 — tooling — second piped gate in one session, on the rule I had just shipped
**What happened:** Verifying a mutation control, I ran `bash <suite> 2>&1 | grep -E '^  FAIL|passed,'`
to keep the output short. The `gate-pipe-guard` hook blocked it. This is the second time in this session
— the first was `| tail` with a `${PIPESTATUS[0]}` rescue — and it happened *after* I had spent the
session extending that very rule to three more masking shapes and writing its hook legs.
**Rule:** Knowing a rule well is not the same as being governed by it, and having just authored it is not
protection — it may be the opposite, since the construct is fresh in mind as a thing to reason about
rather than a thing to avoid. The trigger both times was identical and is worth naming as the actual
tell: **wanting a long green suite to print less.** When that wish appears, the answer is never a filter
on the gate; it is reading the suite in full, or redirecting to a file and grepping the file. If a
filtered view is genuinely needed, put the fixtures and the filtering inside a checked-in `.sh` — the
carve-out exists for exactly that, and it is the difference between a legitimate script and a masked gate.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — a mutation that does not apply is indistinguishable from a guard that works
**What happened:** I ran six mutations against the new suite to prove it can go red. Five turned it red;
one — "count after appending instead of before" — reported NOT CAUGHT. The obvious reading was a gap in
the tests. The actual cause was that the mutation never applied: `perl -0p` slurps the file, so `^` only
matches at the start of the whole string, and without `/m` the substitution silently matched nothing and
rewrote nothing. With `/m` the same mutation turns the suite red in four places.
**Rule:** A mutation control has the same failure mode as the gate it is checking — it can report success
having done nothing. **Assert the mutation APPLIED before reading its verdict**: diff the mutated copy, or
grep it for the inserted token, and treat a no-op substitution as a broken control rather than as
evidence. The direction of the error matters: a mutation that fails to apply always reads as "the suite
did not catch this", i.e. it manufactures a false gap and sends you looking for a missing test. That is
the more expensive direction, because the honest-looking conclusion is to add a test for something
already covered.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings
# Learning Log — JeriC4o / GH-62-loop-tier2

### 2026-09-26 — architecture — I wrote a rule in the morning and violated it in a spec by the afternoon
**What happened:** In #59 I escalated a `§ Testing` bullet: *"Where the qualifier names a property as the
thing that separates a real finding from a dismissable one, the filter must not key on that same
property — it structurally excludes the case the qualifier exists to confirm."* Hours later, writing the
GH-60 issue, I specified that tier 2 of the loop detector "must never run unconditionally: tier 1 plus
the existing qualifiers is the filter that decides whether it runs at all." Tier 1 keys on byte-identity;
tier 2 exists for repetition that is NOT byte-identical. Gating tier 2 on tier 1 confines it to the class
tier 1 already caught — the same defect, in the same shape, in a document I wrote about that defect.
**Rule:** The rule binds on specifications, not only on code, and a freshly-authored rule is at its LEAST
protective — it sits in mind as a thing recently reasoned about rather than a thing to check against.
When designing a second detector for what a first one misses, state the property the first keys on and
verify the second's gate keys on something else; if the gate cannot be described without referring to the
first detector's signal, it is the same detector. Prose describing two tiers is not evidence they differ.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — the mutation-applied assertion existed, and was inverted
**What happened:** After logging yesterday that a mutation which fails to apply reads as a missing test, I
added explicit "the mutation applied" checks to the tier-2 suite. Two of them asserted the opposite of
what applying means: I grepped the mutated copy for the deleted guard and expected to find it once.
Both reported FAIL. A third control failed for an unrelated reason — the fixture seeded tier-2 verdict
lines, which tripped the already-judged guard, so the control could not fire whatever the mutation did.
**Rule:** An inverted applied-check is the good failure — it is loud, and it fails in the direction that
gets looked at. The dangerous sibling is the third case: a control blocked by a DIFFERENT guard than the
one under test, which reports "not caught" and looks exactly like a missing test. When a positive control
does not produce the expected damage, the first question is not "is the test missing" but **"did anything
else stop this control from firing"** — and a fixture that trips an unrelated guard is the commonest
answer. Build control fixtures from the minimum that reaches the guard under test, and prefer a seeded
record that no other guard inspects.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings

### 2026-09-26 — validation — a hardcoded inventory list is a gate that silently narrows
**What happened:** `scripts/test-install-smoke.sh` verifies that components reach a real install, but its
hook-event check iterated a hardcoded `SessionStart PreToolUse PostToolUse`. Adding `Stop` and
`SubagentStop` would have loaded, or not, with nothing noticing — the suite would stay green either way,
while claiming to verify that hooks reach the install.
**Rule:** Keep checking, on every new component, whether the gate that covers its CLASS enumerates
members by hand. An inventory gate is honest about what it lists and silent about what it omits, so its
green is scoped to the list rather than to the class — the same shape as a gate that narrows its own
input set. Extending the list is part of adding the component, not a follow-up.
**Kind:** validation
**Escalated?** no
# Learning Log — JeriC4o / GH-64-loop-metrics

### 2026-09-26 — architecture — writing the reader is what found the writer's defects
**What happened:** I shipped the ledger over two PRs and called the recording done. Building the reader
surfaced two defects in the writer within the first hour, neither visible from the writing side: a tier-2
decline left no trace, so the same window was re-judged on every Stop (measured: 4 model calls for 4
stops against 1 when the answer was circling), and the disagreement rate between the structural gate and
the model — the gate's false-positive rate, the one number that decides whether either tier earns its
place — was unrecorded entirely.
**Rule:** A record format is not finished when something writes it; it is finished when something reads
it for the purpose the format exists for. Write the consumer before declaring the producer done, or at
minimum before shipping a second producer on top of the first. The defects a reader finds are
systematically invisible to the writer, because the writer's tests assert what it wrote and the reader's
assert what can be ANSWERED — and "nothing was written here" is a passing assertion for the first and a
missing answer for the second.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — I wrote the right principle in a comment and implemented the opposite
**What happened:** The outcome derivation in `loop-metrics.sh` carried the comment *"Position, not time:
two lines can share a timestamp, and order is what the append guarantees"* — directly above a filter
keyed on `ts >= verdict.ts`. A verdict is appended right after the call that triggered it, so at
one-second resolution the trigger is readmitted and every verdict reads as went-ahead. The comment was
correct, adjacent, and written by me in the same sitting.
**Rule:** A comment stating an invariant is the weakest possible evidence that the code beneath it holds
the invariant — and it is weakest precisely when the author wrote both, because the intention is
discharged by writing it down. When a comment names the thing NOT to do, read the next lines as if
looking for that exact mistake. It was caught only because the fixture gave every line the same
timestamp, i.e. because the fixture reproduced the real shape rather than a convenient one.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — the same control-blocked-by-another-guard shape, one day later
**What happened:** A positive control meant to show the model being re-asked reported 1 call instead of 4.
Cause: `STUB_ANSWER=... jq ... | bash "$MUT"` sets the variable for `jq`, on the left of the pipe, so the
hook never saw it and the stub fell back to its default CIRCLING answer — which wrote a verdict and armed
the already-judged guard. The control was blocked by a DIFFERENT guard than the one under test. I logged
this exact shape yesterday.
**Rule:** Recurrence, not a new lesson: when a positive control does not produce the expected damage, ask
first what else could have stopped it. Two specific instances now, both in stubbed-hook suites, and the
mechanism was the same both times — the fixture's own setup satisfying an unrelated guard. Concretely for
this shape: a var assignment prefixed to a command applies to THAT command only, so with a pipe it never
reaches the far side; export it, or set it inside the function that spans the pipe.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings
# Learning Log — JeriC4o / GH-67-coarse-gate

### 2026-09-26 — architecture — a threshold is a hypothesis, and mine was wrong about the axis, not the number
**What happened:** I shipped the tier-2 gate with three tunables and labelled them "a hypothesis from one
session" — which read as responsible. The first real data showed the problem was not the values: two of
the three conditions could not discriminate at any setting. Counting DISTINCT fingerprints is satisfied
maximally by healthy varied work, and requiring one tool to dominate is vacuous where one tool is 98% of
every session. No amount of tuning fixes a filter keyed on a property both cases share.
**Rule:** Labelling a threshold as provisional buys nothing if the AXIS is wrong, and "we will tune it
later" hides that distinction. Before shipping a numeric gate, state what the healthy case looks like on
that axis and check the two cases differ there at all — if the healthy case scores as high as the finding,
the number is not the problem and tuning will never find that out. The repo already says a named proxy is
a hypothesis; the missing half is that a hypothesis needs a discriminating measurement, not a tunable.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — the suite passed because its fixtures were hand-written
**What happened:** After the writer changed its record shape, the reader suite stayed fully green — 49
assertions — while the reader counted a `tier: 2` record carrying a `verdict` field that the writer had
stopped emitting. The fixtures were built by hand from the test author's idea of the format, so they
agreed with the reader and nothing compared either to production. The drift was found by running the real
hook, not by any assertion.
**Rule:** A fixture written by hand pins the FORMAT AS UNDERSTOOD, never the format as produced. Where a
suite covers a reader whose producer lives in the same tree, at least one leg must build its input by
RUNNING the producer — an integration leg, however small. Without it the two halves can drift apart while
both suites stay green, and each will look correct in isolation. This is the concrete form of the fixture
rule already in § Testing: production input, in every field the code under test parses.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — process — two control failures in one suite, both from the fixture, not the guard
**What happened:** Writing the rewritten tier-2 suite, two positive controls reported "not caught". Both
were fixture defects: one ran the real hook before the mutated one, and the Stop it issued wrote a turn
marker that reset the count the control depended on; the other wrote a transcript entry under a different
`tool_use_id` than the ledger, so the pointer resolution found nothing and every model-stage assertion
failed for an unrelated reason.
**Rule:** Third and fourth instance of the same shape now — a control blocked by something other than the
guard under test. The pattern across all four: the control's SETUP satisfies or resets a mechanism the
control does not mention. Concretely, two habits that would have caught all four: give each control arm
its own freshly-built state rather than sharing a ledger with the arm before it, and derive every
cross-referencing identifier from one variable rather than writing it twice.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings

### 2026-09-26 — tooling — fourth piped gate in one session, and the hook is still the only thing stopping it
**What happened:** I sent a test suite through `grep` to shorten its output for the fourth time this
session. The `gate-pipe-guard` hook blocked it each time. Between the second and the fourth I extended
that very rule, wrote its hook legs, and logged the recurrence twice.
**Rule:** Recording a recurrence is not a control, and neither is having authored the rule. The trigger is
stable and identifiable: **the moment a long green suite is about to print and I want less of it.** At
that moment the only correct moves are to run it bare and read it, or to redirect to a file. Four
instances in one session, all the same trigger, all stopped by machinery rather than by me — which is
itself the argument for the machinery, and against trusting the prose for this class.
**Kind:** correction
**Escalated?** no
# Learning Log — JeriC4o / GH-69-call-outcomes

### 2026-09-28 — architecture — a priority statement found a defect that months of building had not
**What happened:** The user rejected hook latency as the next task and said harness quality and catching
LOGICAL loops outrank it. Taking that literally — ranking by "which class of loop does this let us see" —
surfaced within minutes that the live detector dismissed the fix-break cycle at every round, and that
`scripts/session-events.sh` had encoded the correct answer all along (`error-retry-loop` deliberately
carries no intervening-edits filter). I had built three stages of a cascade without noticing that the
most common logical loop was excluded by one of its own qualifiers.
**Rule:** When a user restates the priority, re-rank the open work against it explicitly rather than just
reordering the list — the ranking criterion is a lens, and applying it to items already built is where it
pays. Concretely: "which class of X does this let us see" finds gaps that "what should I build next"
never asks about, because the second question presumes the existing coverage is sound.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — architecture — a qualifier copied without its scope inverts its meaning
**What happened:** The STATE qualifier — dismiss a repeat when an edit intervened — is correct and is
taken from the retrospective detector. I applied it to every signal. In the retrospective detector it is
attached to ONE signature (`repeated-tool-call`) and deliberately withheld from another
(`error-retry-loop`), because for a failing call an intervening edit means "an attempt was made and it
failed again" rather than "the question changed". Copying the qualifier without its scope reversed what
it does on the case that matters most.
**Rule:** When borrowing a qualifier from an existing detector, borrow its SCOPE with it — which signals
it attaches to and, more importantly, which it is withheld from. A filter list per signature is a design
statement, not an implementation detail: `filters: ["window"]` next to `filters: ["window",
"intervening-edits"]` is the author saying the difference is deliberate. Read the absence, not only the
presence.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — an embedded-name inventory drifted from 7 to 33 and weakened a gate
**What happened:** `docs/claude-tools-hierarchy.md` §3b listed 7 hook event names; the documentation
defines 33. That list is what `/ai-audit` Checklist O compares project-defined names against, so 26 names
were ones a clash check could never catch. Worse than a stale document: two of the missing entries
(`PostToolUse` / `PostToolUseFailure`) were the pair that makes a call outcome knowable, so the gap hid a
capability as well as a check.
**Rule:** A file whose job is to MIRROR an external surface decays silently and takes its consumer's
guarantee with it. When a checklist compares against an embedded inventory, re-derive the inventory from
the source before trusting a clean result — and prefer re-reading the source to reading the mirror
whenever the answer matters. A mirror is a cache; treat a cached answer to a design question as stale
until checked.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — shape (4) of my own masking rule, in a probe for a different blind spot
**What happened:** Writing a probe for the fix-break fix, I set a variable inside a function invoked as
`out=$(fn)` and read it afterwards. Command substitution is a subshell, so the assignment was discarded
and the script died on `unbound variable`. That is masking shape (4), which I extended and documented in
`agents-method.md` two days ago.
**Rule:** Recurrence, and the failure was loud this time only because `set -u` was on — without it the
variable would have been empty and the probe would have reported a wrong result quietly. Two habits that
would prevent it: have the CALLER compute anything the caller needs to read back, and keep `set -u` in
every throwaway probe, where the temptation to skip it is highest and the cost of a silent empty is the
same as in shipped code.
**Kind:** correction
**Escalated?** no
# Learning Log — JeriC4o / GH-71-inspect-ledger

### 2026-09-28 — tooling — a suite that reads the ambient environment is not a gate
**What happened:** `hooks/lib/test-loop-verdict.sh` asserted that the judging stage stays quiet by
relying on `HARNESS_T3_MODEL` being ABSENT from the environment. That held on a machine where the
cascade had never been switched on, and stopped holding the moment it was enabled in
`~/.claude/settings.json`. The suite then reported two failures in the section about the COARSE gate —
which says nothing about a model — so the red was about a setting and pointed at the wrong code. It had
been green for days on the machine that wrote it.
**Rule:** A suite pins every environment variable its assertions depend on, at the top, explicitly.
Pinning alone would then hide a change to the shipped default, so the default gets ONE dedicated
assertion with the variable genuinely removed (`env -u`), plus a positive control that sets it and
requires the assertion to invert. Inheriting a variable is not "testing the default" — it is testing the
developer.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — a join key has to be measured before it is written into a contract
**What happened:** The plan was for `/inspect` to match ledger rows to transcript entries by
fingerprint, since both compute the same djb2 over the tool input. Measured on a real session first:
43 of 45 agreed and 2 did not, and the two were `Agent` and `AskUserQuestion` — tools whose input the
client rewrites between the hook firing and the transcript record. By `tool_use_id` the match was 45 of
45. A fingerprint join would have been wrong on exactly the tool a fan-out question is about, and every
row it produced would have looked ordinary.
**Rule:** Before writing a join into a contract, run it over real data and count the disagreements. Two
derivations of "the same" value from two sources agree until they meet the case where the sources
differ, and that case is never the common one — which is why it survives every casual check.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — a field that is described but never read back stays wrong indefinitely
**What happened:** `hooks/lib/loop-index.sh` derives `agent_id` from `transcript_path`, and
`docs/claude-tools-hierarchy.md` described the fan-out case it enables at length. Across all 1100 call
rows in all five ledgers on this machine the field reads `main` — without exception, including in
sessions whose subagents made hundreds of calls. The `PreToolUse` payload carries the PARENT transcript
path even for a subagent's call, so the derivation cannot produce anything else. The fan-out arm has
never fired, the stored `transcript` pointer names a file that does not contain that `tool_use_id`, and
tier 3 opens that wrong file to collect its evidence and judges on what is left. Three consequences, no
symptom: every failure path is silent by design.
**Rule:** A field written by a hook and read by nothing is unverified, however carefully the doc
describes it. Ship the reader in the same change as the writer, or record the field as unverified until
one exists. "Detail is one join away" is a claim about a join nobody has performed.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — process — two numbers under one word, from two scopes
**What happened:** `session-events.sh --signatures` reported 45 tool calls and 4 turns for a session
whose ledger held 70 calls and 12 turn markers. Neither is wrong: the signatures pass reads one
transcript file while the ledger records every call in the session including those made inside spawned
agents, whose transcripts live in a directory it never opens — and "turn" means a prompt on one side and
a stop event on the other. Read as a discrepancy, this invites reconciling two correct numbers.
**Rule:** When two passes report the same word, state their SCOPE and their UNIT beside the figures
before either is compared. A count is not comparable to another count merely because both are counts of
things with the same name.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-09-28 — tooling — the input a derivation depends on was never checked for existence
**What happened:** `loop-metrics.sh --for` takes a transcript path and attributes every ledger call by
finding its `tool_use_id` in that file. Nothing checked the file was there. `self-review` ran it against
a wrong directory: call counts, turn counts, verdict counts and outcomes all correct, and the per-agent
census 100% wrong — every call in `unattributed`, under a bracketed gloss saying a live session has one
call in flight. So the corruption arrived with a benign explanation attached, and the one reader placed
to notice it had been told in `agents/inspector.md` to dismiss exactly that symptom. The flag that would
have exposed it, `main_transcript_read`, was computed and reached the JSON but was printed nowhere and
named in no instruction file. Realistic triggers are dull: a mistyped path, or a pruned transcript
beside a ledger directory that has no retention policy.
**Rule:** When one figure is a LOOKUP into an external file and its neighbours are not, the file's
absence produces a report that is entirely right except for that figure — the shape least likely to be
questioned. Check the input exists and stop; and never offer a benign explanation for a symptom
unconditionally, because the same symptom is what total failure looks like. A computed degradation flag
that no output prints and no reader is told about does not count as having handled the case.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — the apostrophe inside a single-quoted jq program, again
**What happened:** Writing the new report lines I put `the session's main transcript` inside a
single-quoted jq program. The quote closed the string, the shell re-parsed the remainder, and `bash -n`
reported a syntax error on a line seven lines below the real one. Then the first fix removed a different
apostrophe and the file still would not parse, so the same failure cost two rounds. This is the third
occurrence in this repo, and there is already a `sh-syntax-check` `PostToolUse` hook for it.
**Rule:** After any edit that adds English prose inside a single-quoted region — jq, awk, perl — run
`bash -n` on the file before anything else, and when it reports an error, grep the whole added region for
`'` rather than fixing the first apostrophe seen. The reported line is downstream of the real one, so
reading it as the location is what turns one mistake into two rounds.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — process — a completeness flag that names the wrong quantifier
**What happened:** Fixing the absent-transcript defect I added `attribution.complete` and commented it
*"True only when every transcript that should have been read was read in full."* The script has no list
of what should exist — the ledger field that would be that list is the broken one — so the flag could
only report on files it FOUND. `self-review` produced the gap: main transcript present and parseable,
subagent directory empty, nine of ten calls misattributed, `complete: true`, and the benign gloss
asserting work in flight. The fix for the first round of the same shape had reproduced it one level down.
**Rule:** When a flag says "every X", check what enumerates X. If nothing does, the flag is reporting on
what it happened to encounter and must be named and documented that way. Then look for a property that IS
checkable and assert that instead — here, position: a call with no transcript record because it is still
executing is necessarily among the LAST in the ledger, so one in the middle is a transcript nobody
opened. A measurement beats a reworded claim, and the residual it still cannot cover gets written down
rather than implied.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-09-28 — tooling — a separator that command substitution deleted
**What happened:** `note_bad() { BAD_TX="${BAD_TX}${BAD_TX:+$(printf '\n')}$1"; }` — command substitution
strips trailing newlines, so the separator was the empty string. Two unreadable transcript paths
concatenated into a single path that exists nowhere, and the report printed it verbatim as the file to go
and look at. The fixture exercised one bad transcript, so it was byte-identical either way and could not
see it.
**Rule:** `$(printf '\n')` is empty; use `$'\n'` or a variable holding a literal newline. And a test for
a joiner needs at least TWO elements — with one, every separator behaves identically, so the fixture
cannot distinguish a correct one from an absent one.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — process — the guard leg that fires on all real input had no control
**What happened:** `complete` is a three-way conjunction, and two of its legs got a positive control each
while the third — the `$ua == 0` short-circuit, which is the leg that answers on every real session,
since live data has zero unattributed calls — got none. `self-review` proved it by mutation: deleting the
guard left the suite at 130 passed, 0 failed. The shipped code was correct; the exposure was that a later
edit there would report "ATTRIBUTION IS INCOMPLETE" on 100% of healthy sessions with the suite still
green. Every fixture in the file carried at least one unattributed call, so the clean case was the one
case never constructed.
**Rule:** "One positive control per guard" counts the LEGS of a conjunction, not the expression. And when
the fixtures all exercise the interesting case, the boring case is the one with no coverage — check
which branch real input takes and make sure a fixture takes it too.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings

### 2026-09-28 — tooling — the mutant that failed for a different reason than it claimed
**What happened:** A positive control tried to restore a pre-fix line by rewriting it literally, but the
replacement had to carry an apostrophe through a single-quoted perl program, and the escaping that
survived emitted a two-character `\n` rather than the empty string. The assertion went red either way, so
the control looked fine; its comment described a mutant that was never produced. Found by comparing the
mutant against the real pre-fix line in git rather than against the comment.
**Rule:** A mutation control is a claim about WHAT was changed, and the assertion going red does not
verify it — reproduce the bug by its EFFECT when the literal spelling cannot be written cleanly, and say
in the comment which of the two you did. When a pre-fix version exists in git, diff the mutant against it.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings
# Learning Log — JeriC4o / GH-72-payload-agent-id

### 2026-09-30 — tooling — a gate piped into a pager is not a gate, and a subagent hits the rule too
**What happened:** The round-1 `spec-writer` subagent ran `bash scripts/check-references.sh` piped
into `tail` to shorten the output. The masked-gate `PreToolUse` hook blocked the call, and the
subagent re-ran it bare and self-reported the violation in its hand-back. The rule it crossed is
`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Tooling: a pipeline's exit status is the LAST
command's, so `<gate> | tail` reports `tail`'s success no matter what the gate found. Two things are
worth recording beyond the violation itself. First, the orchestrator's spawn prompt DID restate the
governing constraints, and the restatement did not prevent it — the loaded hook is what stopped it,
which is the same asymmetry `/task` § Patterns already records about restatement versus enforcement.
Second, the subagent correctly declined to write this entry itself, because a Learning Log write is
the orchestrator's call and Boundary rule 2 constrains what may accompany one.
**Rule:** Limit a gate's output with the gate's OWN flags, never with a pipe. When output length is
the problem, redirect to a file and read the file — that keeps the gate's exit status intact and
keeps the line naming WHICH assertion failed. This binds inside a subagent exactly as it binds in the
orchestrator: delegation does not dilute the method rules, and a spawn prompt that restates them is a
reminder rather than a control.
**Kind:** correction
**Escalated?** no

### 2026-09-30 — testing — a recorded measurement must be re-run for the pattern actually written down
**What happened:** The design recorded an AC17 gate measurement — "5 lines across 3 files", itemised
per file — as the mitigation its own § Risks named for "a prose surface is missed". Re-run with
`grep -rnoE`, the recorded pattern returns 4 distinct lines, and `docs/claude-tools-hierarchy.md:110`,
listed as covered, matches nothing. The root cause is narrower than "the count was wrong", and the
first diagnosis offered — that `grep -c` hid the detail — was itself wrong. The figure was CORRECT for
the pattern that was run: that pattern still carried a phrase which was single-handedly matching
`:110`, and the phrase was then dropped from the pattern that got written down, for a sound reason
(it straddles a line break elsewhere) but without re-measuring. Measured pattern A, recorded
pattern B. `:110` was not an empty surface — it asserts `complete` is "the conjunction of the three
things the reader can actually check" and that "nothing enumerates the transcripts that ought to
exist, because the ledger field that would be that list is the broken one", both of which this change
falsifies, and both wholly on one line and matchable all along.
**Rule:** Re-run the measurement against the pattern in its FINAL written form, after every edit to
that pattern — editing a pattern invalidates every number taken before the edit, including one taken
minutes earlier. Record the measurement as an enumeration of matches (`grep -rnoE`), never as counts:
counts answer "can this gate fire", enumeration answers "which surfaces does it police", and a gate
documented as a coverage mitigation is claiming the second. Best of all, make the recorded pattern and
the executed pattern the same string by construction — extract it from the document and run that.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-09-30 — process — a wrong root cause from the orchestrator gets corrected, not adopted
**What happened:** Reviewing the above, the orchestrator diagnosed the cause as a `grep -c` blind spot
and passed that diagnosis down as part of the fix instruction. The design subagent ran the check,
found the real cause was a pattern mismatch between what was measured and what was recorded, said so,
and corrected the two places where the orchestrator's weaker diagnosis had already been written into
the design document. The orchestrator then verified the correction independently
(`grep -noE 'ledger field that would be that list is the broken one' docs/claude-tools-hierarchy.md`
returns `110:`) rather than accepting it, and adopted it.
**Rule:** A diagnosis travelling downward in a spawn prompt carries the same authority as any other
claim in it, which is to say none beyond its provenance — mark it as a reading, not a finding, so the
receiving agent knows it may be falsified. And when a subagent contradicts the orchestrator with a
mechanism, verify the mechanism and take the correction; a document that records a plausible root
cause instead of the real one teaches the wrong lesson to every later reader.
**Kind:** validation
**Escalated?** skill:task

### 2026-09-30 — testing — a summary asserted over a set is a claim about every member
**What happened:** Three times in one task, on three different surfaces, a plausible aggregate stood in
for an enumeration and was wrong in the member nobody checked. (1) A design recorded an AC17 gate
measurement as a per-file count taken from a pattern that was then edited before being written down;
the count kept vouching for a surface the edit had silently uncovered. (2) A hand-back reported "I
wrote a checker that would fail on divergence" when what existed was a one-off extraction in a
scratchpad — a capability asserted over future runs from a single past one. (3) A hand-back certified
"all seven REDs report `null` on the two new fields"; reading the suite output, six do and the seventh
is `want [differ], got [same]` — a different shape. In (3) the conclusion (expected-RED, not a
regression) was still correct, which is what makes the shape dangerous: the summary is right about the
set and wrong about a member, so nothing downstream looks off. The seventh was also the member that
mattered most — it is the control that keeps an invariance assertion non-vacuous, and the cheapest way
to turn it green is to weaken it, which would delete the property it exists to protect.
**Rule:** Before writing a sentence of the form "all N do X", enumerate the N and read each one. Prefer
recording the enumeration itself over the count — `grep -rnoE` over `grep -c`, the list of failing
assertion names over "7 failed" — because an enumeration cannot be right about the aggregate and wrong
about a member. When the members are a test suite's failures, the enumeration is free: the suite
already printed it. The same rule binds on capability claims: "this guard fails on divergence" is a
claim over future runs, and it is earned by exercising the failing case, not by the passing one.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-09-30 — tooling — the orchestrator broke the gate rule it had been enforcing all task
**What happened:** Re-running gates after a self-review fix, the orchestrator sent two suites' output
to the null device and kept only the exit code. The masked-gate `PreToolUse` hook blocked it: that
redirect discards the line naming WHICH assertion failed, so even a correct status leaves nothing to
act on. This is the same rule the orchestrator had restated in five separate spawn prompts during this
task, and had already logged once against a subagent that piped a gate into a pager. The trigger was
wanting one compact result line from a gate whose full output is long and was expected to be green —
the status was all that seemed to matter, which is precisely the reasoning the rule forbids. A second
block followed immediately when this entry was first written through a shell heredoc: the hook matches
the literal command string, so PROSE QUOTING a blocked construct is itself blocked. The entry had to be
written with the file-editing tools instead.
**Rule:** Redirect a gate to a FILE and read the file — never to the null device, not even when only
the status is wanted, because the choice to discard the output is made before knowing whether it would
have mattered. Treat "I only need the exit code" as the signal to write to a file, not as licence to
skip it. And restating a rule to others does not install it in oneself: the two gates this appeared on
were the ones expected to pass, which is exactly the condition under which output looks disposable.
Separately, when an entry must quote a hooked construct, author it with Edit or Write, never a shell
heredoc — already in cross-session memory, and it fired again here.
**Kind:** correction
**Escalated?** no
# Learning Log — JeriC4o / GH-75-hook-path-resolution

### 2026-10-01 — tooling — a legitimate zero exit-codes as failure and swallows the rest of an `&&` chain
**What happened:** A spec-writer subagent chained verification steps with `&&` where the first was a
`grep -c`. That count was legitimately `0` — the correct answer — but `grep` exits non-zero when it
matches nothing, so the `&&` short-circuited and every later step in the chain never ran. The agent
noticed and re-ran the checks as separate calls, so no finding was lost. It is the masking shape
`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Tooling already enumerates, reached by a route the
enumeration does not name: not a gate piped into a pager, but a *successful* check whose success is
spelled as a non-zero status.
**Rule:** A counting command's exit status encodes "did it match", never "did it succeed", so it may
never be a link in an `&&` chain of verification steps. Run each check as its own call and read its
output. Where a count must be tested, compare the captured value (`[ "$n" = 0 ]`) rather than relying
on the command's status. The general form, which is what makes this worth recording beyond the one
command: before chaining on any command's status, ask what that status MEANS for that command — for
`grep`, `diff` and `test` it reports a property of the input, not the health of the run.
**Kind:** correction
**Escalated?** agents-method

### 2026-10-01 — testing — three agents measured one fact and got three totals, all correct
**What happened:** Establishing that the propagation hook only ever sees absolute paths, three
independent measurements were taken of how many `file_path` values the project's transcripts hold:
519, 1090, and a third figure nobody could reproduce. None was wrong — they scoped differently. 519
counts only the tool calls the hook's matcher selects; 1090 counts every `file_path` key in the same
transcripts. The load-bearing fact was identical in all three: **zero** relative paths. The dispute
was entirely about the denominator, and it cost a round of cross-checking to discover that there was
no dispute at all.
**Rule:** A count is meaningless without its scope, so record the scope and the derivation command in
the same breath as the number — and when two counts of "the same thing" disagree, compare the scopes
before doubting the data. Prefer the narrowest scope that still answers the question: here it is the
tool calls the matcher actually selects, because a wider net imports paths from tools the hook never
sees. Relatedly, when a measurement is offered as a correction to someone else's, state the scope
first; a bare "it is 173, not 0" reads as a contradiction when it is a different question.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-10-01 — process — growing an artefact past the point where it can stay accurate is itself the defect
**What happened:** GH-75 was filed for two defects in one file. Measurement kept finding adjacent
instances of the same family, each genuinely in scope by the ticket's own logic, and the user approved
folding in each one. The spec reached 48 KB and the design 50 KB across two widening rounds, and the
first design-review round returned five `major` findings — of which three were the documents having
lost accuracy as they grew: transposed counts, stale line anchors, and a list of representatives
written in a shape that did not match what the code receives. The remedy was not a sixth round of
careful reading but splitting the work: the spec came back to 34 KB, and the removed scope went to two
new issues carrying the review's findings verbatim so nothing was dropped.
**Rule:** Treat repeated `major` findings that are *about the document rather than the design* as a
size signal, not a rigour signal, and split rather than iterate. Two symptoms to watch for, both
present here: a correction that introduces its own error (an amendment fixing transposed counts wrote
line numbers that the same edit moved), and two artefacts agreeing with each other while both being
wrong, which is what happens when the agents that wrote them have been talking. When splitting, the
removed scope needs an issue of its own BEFORE the narrowing lands, or the reasoning behind it is lost
and the split is indistinguishable from quietly dropping work.
**Kind:** correction
**Escalated?** skill:task, agent:design-review

### 2026-10-01 — process — a document marked work DONE that was never executed, and no gate could see it
**What happened:** A design amendment added a tenth `case` arm after the implementing group had already
handed back, and marked the decomposition row `DONE (Group A)` — conflating "the amendment specifies
it" with "the tree has it". Measured: `grep -cF '.claude/skills' hooks/hooks.json` returned 0. Every
gate the implementing group ran was green, because nothing in the suite tests arm membership. The gate
that would have caught it was in the NEXT group, and it would have been written against the design's
claim that the arm already existed — so its own assertion would have failed, and the implementer would
have attributed the failure to their gate code rather than to a missing arm. It surfaced only because
the implementing group reported its arms as an ENUMERATION extracted from the live manifest rather
than as a count, and because it raised the dropped class as a finding against the frozen design
instead of quietly adding an arm.
**Rule:** A claim about the TREE must be answered by the tree, at the moment the claim is written —
`grep` the artefact and paste the result beside the status, never infer the status from the instruction
that requested the work. A status marker is a measurement, not a plan. Where a class of claim has no
gate behind it, say so next to the claim; "all gates green" is not evidence for a property no gate
tests. And the structural remedy, which is cheaper than vigilance: give the exception an INDEPENDENT
witness. Here the prior behaviour was already committed as a fixture, so one assertion — no path the
old pattern matched is silent under the new one — would have caught it with nobody checking by hand.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-10-01 — process — the orchestrator's instruction contradicted its own rationale, and the subagent was right to weigh them
**What happened:** Deciding between two spellings of a glob, the orchestrator wrote "do not use the one
in the design's AC8 row" and then named that exact spelling as the one to ship. Measured afterwards:
the rejected spelling sat in five body places, and AC8 was the single place that agreed with the
decision — the clause was exactly inverted. The subagent did not execute it literally. It counted
where each spelling sat, weighed the prohibition against the bold directive, the stated rationale and
the control list it had been given, found two of three signals agreed, shipped the correct arm, and
NAMED the contradiction in its hand-back rather than papering over it. Literal execution would have
shipped a glob that fires beyond the regression the user approved.
**Rule:** When an instruction's literal clause contradicts its own rationale or the controls it
supplies, treat the instruction as evidence rather than as a command: re-derive the facts it rests on,
act on the reading the majority of its signals support, and report the contradiction explicitly. An
instruction that disagrees with itself cannot be obeyed, only interpreted — and an interpretation
carried out silently is indistinguishable from a mistake. Correspondingly, when WRITING an
instruction, supply the rationale and the controls alongside the directive; they are what makes a slip
recoverable by the receiver. Here they were the only thing that was.
**Kind:** validation
**Escalated?** skill:task

### 2026-10-04 — testing — the remedy proposed for a cannot-fail check was itself a cannot-fail check
**What happened:** A review round flagged a test leg whose oracle was the wrong file — it compared the
scaffolding template's deny list against this repository's own copy, so an identical edit to both
would satisfy it while the list changed. The proposed remedy was to compare against the committed
version of the same file instead. Measured: this branch never touched that list, so the committed copy
was already byte-equal to the working one — the proposed oracle was a comparison of a value with
itself from the very first run, not merely after the change landed. The orchestrator rejected it for
the weaker reason (that it would go vacuous once committed) and shipped the sixteen entries as an
enumerated committed constant; the next review round confirmed the stronger reading and that the pair
of legs is a strict superset of the one property replaced. The decisive evidence was the mutation the
old leg could not see: removing one entry from BOTH files leaves the cross-file comparison green while
the enumerated leg fails.
**Rule:** A remedy for a check that cannot fail must clear the same bar as the check it replaces —
name the mutation it is supposed to catch and RUN that mutation before accepting it. Oracles defined
relative to version-control history are self-referential by construction for any property the current
work does not change, and become self-referential for everything once the work merges; the durable
oracle for "this list is exactly these entries" is the enumeration, committed beside the test. And
when a reviewer's remedy is declined, state which mutation the replacement catches that theirs does
not: that sentence is what let the next round verify the substitution instead of re-litigating it.
**Kind:** correction
**Escalated?** agent:self-review, agent:review-findings

### 2026-10-04 — tooling — the corpus contaminated itself at the moment it was measured
**What happened:** A test comment froze "69 measured deliveries" as the provenance for why the suite
exists. A review re-derived 83, then 86 half an hour later in its next round — and the growth was the
review's own search commands being written into the session transcripts it was searching. Separately
measured: the obvious search over-counts, returning 90 raw hits against 81 actual deliveries, the
other 9 being review commands and tool results that merely quoted the string being counted.
**Rule:** A count taken from a session-transcript corpus is measured on a surface that the act of
measuring writes to, so it is not reproducible even in principle and must never be frozen in a comment
or an assertion. Record the invariant instead — here, zero resolved deliveries, which holds at any N —
and if a figure is genuinely needed, report the raw hits and the qualifying hits as two numbers and
say which side the measuring commands themselves fell on. The general shape: before writing a
measurement down, ask whether taking it perturbs what it measures.
**Kind:** correction
**Escalated?** workflow, agents-method
# Learning Log — JeriC4o / chore/improve-sweep

### 2026-09-26 — tooling — piped a test suite into `tail` to shorten its output, masking its exit status
**What happened:** While validating the `/improve` fold I ran two test suites as
`bash scripts/test-check-references.sh 2>&1 | tail -5; exit ${PIPESTATUS[0]}` and the equivalent for
`scripts/test-plugin-manifest.sh`. The `result-masking` PreToolUse hook blocked both. The `${PIPESTATUS[0]}`
rescue was deliberate and it does propagate the suite's rc — but the construct still throws away the
suite's output, which is the half of a gate result a reader actually judges, and the rule binds on the
CONSTRUCT as written, not on whether this particular spelling happened to preserve rc.
**Rule:** Run a gate bare, as its own Bash call, and read its FULL output. Do not reach for `| tail` to
keep a long green suite short — a suite's per-assertion lines are the evidence that it ran the assertions
it claims. Limit output with the tool's own flags when it has them; a suite with no such flag is simply
read in full. `${PIPESTATUS[0]}` is not an exemption from the rule; it repairs rc and leaves the output
loss untouched.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — documentation — I wrote a carve-out by misquoting the enumeration it cited
**What happened:** Reconciling a documented audit block against the gate-masking rule, I wrote that the
rule "binds on a loop whose body runs a build / test / lint / format gate, and this loop invokes only
`grep` and `awk`." The rule I was citing reads `Each gate (format, lint, build, test, search)`. I dropped
**search** from a five-item list and then rested the entire carve-out on the gap I had just created — the
block's body runs `grep -Fx`, which is a search. A clean-context eval caught it by re-reading the cited
line; I had quoted the enumeration from memory while looking at the sentence I was writing.
**Rule:** When a carve-out argues that a rule does not reach some case, re-read the rule's own
enumeration and quote it in full BEFORE writing the exemption — a carve-out is a claim about the cited
text, so the citation is the thing to verify, not the reasoning built on it. An enumeration shortened by
one item is the most dangerous shape available: it reads as a faithful restatement, and the dropped item
is invariably the one that would have refused the exemption. Prefer stating why a known violation is
being TOLERATED over constructing a reason it is not a violation.
**Kind:** correction
**Escalated?** workflow, agents-method

### 2026-09-26 — process — I added a rule to a section and not to the block that ships it
**What happened:** I appended a new bullet to `rules/ast-index.md` § Forbidden and discharged the
Propagation Rule by sweeping for the changed keywords. The sweep came back clean. But the same file ends
with a verbatim block that subagents inherit, which RESTATES three of that section's four shell-hazard
bullets in its own words — so the sweep, keyed on my new wording, could not see it. Subagents would have
inherited the three older hazards and not the new one, from the same file.
**Rule:** A propagation sweep finds files sharing the changed WORDING; it cannot find a restatement in
different words, including one further down the file you just edited. When a file contains a
digest/inherited/verbatim copy of its own content, that copy is a sync-group member of the section it
digests — check it by STRUCTURE (does this section have a restating counterpart?) before trusting an
empty sweep. The repo already names this failure mode in the Propagation Rule procedure; I ran the sweep
it prescribes and still missed it, because I treated the sweep as the whole obligation.
**Kind:** correction
**Escalated?** no
