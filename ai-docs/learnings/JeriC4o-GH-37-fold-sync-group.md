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
