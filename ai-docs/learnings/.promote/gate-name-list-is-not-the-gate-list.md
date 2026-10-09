---
id: gate-name-list-is-not-the-gate-list
category: tooling
kind: correction
created: 2026-10-09
---

**Rule:** When an automated guard recognises its subject by a list of names, its silence is not clearance.
The real list of verification commands is always longer than any name list written into a guard, so a
construct the guard passed may still be forbidden. Check the construct against the rule, not against the
guard.

**Why:** A guard that matches command names can only know the names someone thought to enumerate. A
verification command invoked under a name outside the list — a parser run for its exit status, a checker
reached through a variable or a glob — arrives unflagged, and the absence of a refusal reads as
permission. The asymmetry also runs the other way on purpose: a guard deliberately narrower than its rule
under-approximates to stay tolerable, so passing it proves nothing about the rule. Twice in one corpus the
first item on a written list of checks was the one the guard could not see.

**Signal:** A guard whose subject is identified by an alternation of literal names. Any rule whose
enforcement in practice is "the tool would have stopped me". A verification command whose invocation
differs in spelling from every example the guard carries.
