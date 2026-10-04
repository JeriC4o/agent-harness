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
**Escalated?** no

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
**Escalated?** no

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
**Escalated?** no

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
**Escalated?** no

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
**Escalated?** no

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
**Escalated?** no

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
**Escalated?** no
