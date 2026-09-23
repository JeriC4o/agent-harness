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
