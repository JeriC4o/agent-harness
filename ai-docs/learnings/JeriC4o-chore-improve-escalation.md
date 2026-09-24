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
**Escalated?** no
