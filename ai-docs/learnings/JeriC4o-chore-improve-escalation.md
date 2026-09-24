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
**Escalated?** no
