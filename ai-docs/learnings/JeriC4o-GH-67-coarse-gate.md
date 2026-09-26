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
**Escalated?** no

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
