---
id: two-gates-one-conjunction
category: tooling
kind: correction
created: 2026-10-09
---

**Rule:** Never join two verification commands with a conjunction in one call. Run each as its own call
and read each verdict. This holds when the first is cheap and feels like a precondition for the second —
that framing is the rationalisation, not an exemption.

**Why:** Only the last command's exit status survives, so the first verdict is unreadable. Worse, a
counting command returns a non-zero status for a legitimate zero — nothing matched — which
short-circuits the rest of the chain, and a truncated chain is indistinguishable from a completed one
when the last thing printed is a number. Verification has been reported as done, in writing, on runs that
never happened this way. Six incidents from five parties in one corpus, several of them within hours of
the rule being restated.

**Signal:** The words "while I am at it" or "that is just a precondition". A cheap syntax or existence
check chained ahead of an expensive suite. Any conjunction whose left side is a command whose exit status
describes a property of its input rather than the health of the run.
