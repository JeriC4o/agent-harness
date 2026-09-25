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
**Escalated?** no
