# Design: Redline log — freeze the plan, mark divergences in place, fold once after approval

**Ticket:** GH-108
**Date:** 2026-10-10
**Spec:** ai-docs/plans/2026-10-10-redline-corrections-log.spec.md

## Approach

### What this change is, in one paragraph

A review finding whose subject is a sentence in the task's spec or design stops the round today and
re-runs the planning chain before any code fix may land. This change splits that on one question —
*does the divergence break the agreed approach?* — and gives the non-breaking answer a cheap path: one
visible marker on the diverged item, one row in a committed log, and the code fix proceeds in the same
round. After the PR is approved, a named command folds the accumulated corrections into the design,
collapses the spec to its record of deliberate absence, and removes the log.

### The freeze point, and which régime a round is in

The freeze is an **event**, and it is the **design-review GO verdict**. Everything in this design keys off
that instant:

| Régime | A correction is | Why |
|---|---|---|
| Before GO — Steps 6–7 | a **rewrite** of the design | The document is still being authored. The review loop rewrites sections by its own contract (`agents/design.md` § Iteration), and nothing has shipped for a base to diverge from |
| After GO — Steps 8–12 and any fix round | a **marker plus a log row** | There is now an agreed base, and the code is being measured against it |

Two consequences the rest of the design depends on:

- **The marking pass is post-GO by construction.** It runs in the Step 10 / Step 11 review-and-fix cycle,
  which cannot be reached without a GO verdict (`skills/task/SKILL.md` Step 7 → Step 8). So no mechanism
  here needs to ask which régime it is in — the position in the workflow answers it.
- **A breaking rebuild re-arms the event.** AC12's "the new frozen base" is the same event firing a second
  time: the rebuilt design passes through design-review again, and that GO is the new freeze point. The
  log resets to empty because its rows described a base that no longer exists.

This also means the pre-GO régime needs no new instruction. `agents/design.md` § Iteration already says
to rework only the affected sections and produce a full document; that *is* rewrite-on-correction, and
Scope 12's author-side clause makes explicit what it already implies.

### The four open questions, decided

**OQ1 — the write path into the committed log: the reviewer ORIGINATES the row, the `design` subagent
PROMOTES it.** The reviewer never writes the committed file.

The spec settles who originates (Key decisions: "the agent that writes the findings table, at the moment
it writes it") and leaves open who carries. Decided for promotion, on three grounds, the first decisive:

1. **`agents/self-review.md` is shared by four callers and three are out of scope.** The spec's Out of
   scope requires `/bugfix`, `/project-review` and post-push fix rounds to keep today's behaviour. A
   reviewer taught to write a committed log writes one in all four callers. A `/task`-only promotion step
   leaves those three untouched *by construction* rather than by a carve-out sentence that can be misread.
2. **One writer of the committed file.** `docs/agents-method.md:124` already makes `design` the only
   party permitted to write `*.design.md`. Making it the only writer of the log too means the marker and
   its row are written in the same invocation, so they cannot diverge — which is what AC5's "a marked
   item is settled" rests on.
3. **One cut point for the gate.** At plan time the commitment is in the plan; at apply time the marker
   and the row are both in the tree. Both halves are mechanically checkable (§ The gate, below).

Where the row lives before promotion: it IS the round's fix-plan row — nothing is written twice. See OQ2.

**OQ2 — the row is DERIVED from the fix-plan row, not recorded independently.**

`docs/templates/progress-format.md:75` already carries a per-finding column "Arm A — artefact sentence at
stake", holding a quoted sentence plus its backticked `file:line`, and the gate already resolves that
anchor and checks the quoted sentence sits within three lines of it on whitespace-normalised text
(`docs/templates/progress-format.md:147`). That is the redline row's middle field, already validated
against the file. An independent record would need its own anchor-and-quote validator — a second copy of
logic the repo has already paid for once.

So the redline row is assembled from cells that already exist:

| Redline row field | Where it comes from |
|---|---|
| `Key` | `R<round>.<finding #>` — the round number from `## Self-Review (Round N)`, the finding number from the plan row's `#` column |
| `Type` | the `redline:` disposition's type token |
| `Artefact sentence diverged from` | the plan row's Arm A cell, **verbatim** |
| `What shipped instead` | the `redline:` disposition's reason text, **verbatim** |

Nothing is re-authored. That is what makes "derive rather than duplicate" real rather than nominal, and
it is why the promotion step cannot drift from the plan it promotes.

The vehicle is a **sixth disposition** in the fix plan's closed vocabulary:

```
redline: <type> — <what shipped instead>        <type> ∈ added | modified | removed
```

This reuses machinery that is already there, which is the whole reason for choosing it over a new column:

- The two existing reason-carrying tokens (`object: <reason>`, `resolved: <reason>`) already refuse an
  empty reason via a `?*` pattern at `skills/task/scripts/check-fix-plan.sh:533-534`. Three literal
  patterns — `'redline: added — '?*`, `'redline: modified — '?*`, `'redline: removed — '?*` — give AC6's
  **closed** type vocabulary enforced by the pattern itself, with the empty-payload refusal for free.
- **The table's cell count does not change.** `docs/templates/progress-format.md:148` records that the
  parser "refuses a row whose cell count is wrong rather than misreading it". A new column would touch
  every shipped example, the scout's brief, and the parser. A new disposition touches a `case`.
- **Measured: the target leg does not fire on it.** The path half of arm A3 is wrapped in
  `if [ "$disp" = fix ]` (`skills/task/scripts/check-fix-plan.sh:510`), so a `redline:` row may name
  `ai-docs/plans/*.design.md` as its target without routing. Probe E below confirms the converse — a
  `fix` row naming that path DOES route — so the discrimination AC8 asks for falls out of a guard that
  already exists. No change to the routing legs at `:512`/`:514` is needed or wanted.

**OQ4 — the marker's spelling: one visible, machine-detectable pointer token, appended in place.**

```
**[REDLINE R<round>.<finding #>]**
```

The token carries the log-row key and nothing else. What changed, of what type, and what shipped instead
live in the log row alone — the marker's whole job is to let a reviewer skip a settled item, and the key
is what gets them to the row that says the rest. **Yes, it must be machine-detectable**, which is the
half of OQ4 the spec leaves open: the completeness gate pairs a plan row with a marker (arm A8) and the
fold's residue check asserts the marker is gone (AC13). Both read the literal `\[REDLINE `.

Requirements the spelling was chosen against, each load-bearing:

- **Visible, not a comment.** The payoff the spec names is that "a reviewer reading the design sees which
  items are already settled and skips them". An HTML comment is invisible to the reader and would buy the
  machine-detectability while discarding the reason for marking at all.
- **Additive — AC3.** It is appended to the end of the marked item's line; the original text is untouched.
  Verified on a fixture: after marking a decomposition row, `grep -c 'Wire the gate'` still returns 1.
- **Survives a table cell.** Most marked items are decomposition rows. The token carries no `|` and no
  newline, so it cannot shift a cell. Verified on a fixture row.
- **Machine-detectable — AC13.** The residue pattern is the literal `\[REDLINE `. Verified both ways on a
  fixture: 3 hits across the three residue patterns before the strip, rc=1 after it.
- **Keyed to its row.** `R<round>.<finding>` is the join between marker and log row, and it is derived
  from numbers both sides already carry — no new identifier to keep in step. It is also the *entire*
  payload, so there is no field here that could disagree with the row it points at.
- **Namespace is clean.** `grep -rniE 'redline'` over the tree returns hits only in this task's own spec
  and learnings file. Nothing to collide with.

**One syntax, not two.** Strikethrough is excluded by the spec, which records the ground: it PRESERVES
the superseded wording, and no design may carry a record of superseded material at any stage. The design
adds one mechanical consequence: a second marker syntax would be a second residue pattern for the fold to
strip and the gate to know about, so excluding it also keeps the residue set at three patterns.

**OQ3 — the named command is a new skill, `/redline-fold`.**

- `/task` cannot host it. `skills/task/SKILL.md:228` declares everything arriving after Step 12 a
  post-push fix round, and re-entering `/task` for a one-step closing pass loads a 32,101-char skill
  behind the `skill-gate` confirmation to do a single spawn.
- `/pr-merged` is excluded by the spec: it activates only on a confirmed merge
  (`skills/pr-merged/SKILL.md:4`, reinforced at `:19`).
- A new skill is the right size for the job: a trigger, measurable preconditions, two spawns, one gate
  call, one surfaced commit.

It also solves the size problem. AC19's binding constraint is that four method files sit within 3,000
chars of the 35,000 early warning. A new file starts at zero, so the mechanism's prose has somewhere to
live that is not one of them.

### Approval cannot be measured here, and the design says so rather than pretending

The spec records that `grep -rn 'reviewDecision'` over `docs`, `agents`, `skills`, `hooks`, `rules`
returns zero hits. Re-run this round: zero hits (rc=1), positive-controlled on the same command form with
`gh pr view`, which returns nine files. The claim holds.

**Measured further, and this is new:** `gh pr list --state all --limit 20 --json number,reviewDecision,reviews`
returns `reviewDecision: ""` and `reviews: []` for **all twenty** PRs this repository has ever had. So
`reviewDecision` is not merely unread here — it carries no information at all, because `main` carries no
branch protection and approval in this project is something the user says.

Pinning `reviewDecision == APPROVED` as the fold's precondition would therefore produce a gate that can
never pass in this repository — precisely the "gate whose failure mode is empty output" this project's
design rules forbid. So:

| Precondition | How it is established |
|---|---|
| not on the default branch | measured — `git branch --show-current` |
| a PR exists for the branch | measured — `gh pr view` exits 1 with "no pull requests found for branch …" when it does not (run: rc=1 on this branch) |
| the PR is still open (the "before merge" half of AC10) | measured — `gh pr view --json state` |
| the PR is approved | **not measurable here.** Carried by the user's invocation, in the shape `skills/pr-merged/SKILL.md:19` already uses for the merge premise. Where `reviewDecision` IS non-empty — a consuming project with branch protection — the skill reads it and refuses on `CHANGES_REQUESTED` / `REVIEW_REQUIRED` |

This is a one-shot precondition read at invocation, not polling: AC10 forbids observing the review surface
to decide *when* to act, and the user's keystroke is what decides that.

### `docs/agents-method.md` is NOT in the edit set — measured, not assumed

The spec lists it among the files this change must touch, with 123 chars of headroom. **It does not need
to be touched**, and proving that is the single most consequential result of this investigation.

The reason it looked unavoidable is `scripts/check-references.sh`'s L4 rule: a bare `ai-docs/…` path in a
method file must name a *documented* project-data root, and the root list is mirrored out of
`docs/agents-method.md` § Agent Docs. A new committed plan-tree file appeared to owe a row there.

It does not, for two independent reasons in the matcher itself:

- `scripts/check-references.sh:179` tests `case $p in "$r"|"$r"/*)` against each documented root, and
  `ai-docs/plans` is already a root (`:68`). Any path under it resolves.
- `scripts/check-references.sh:100` skips a path containing `*` as templated, so the glob spelling
  `ai-docs/plans/*.redline.md` is not even examined.

Verified empirically on two tree copies, both legs (`is_templated` is at `scripts/check-references.sh:100`
and `DOC_ROOTS` at `:68`):

| Fixture: a method file naming… | `check-references.sh --root` |
|---|---|
| `ai-docs/plans/x.redline.md` | **passes** — "project-data spellings … all resolve" |
| `ai-docs/redline/x.md` (control) | **fires** — `major\|L4\|agents/design.md:128: 'ai-docs/redline/x.md' is not a documented project-data path` |

**This settles the log's location:** inside `ai-docs/plans/`, never a new `ai-docs/redline/` root. A new
root would force an `agents-method.md` edit against 123 chars of headroom; the plan tree costs nothing.

Two further reasons `agents-method.md` stays out:

- The size AXIOM's "Applies to:" list at `:48` already covers `every ${CLAUDE_PLUGIN_ROOT}/skills/**/*.md`,
  so the new skill needs no entry.
- `docs/agents-method.md:124` already makes `design` / `spec-writer` the only writers of
  `*.design.md` / `*.spec.md`, which is exactly who performs the fold. The AXIOM needs no amendment.

One adjacent question a reviewer will raise: the fold produces a commit on a branch with an open PR, and
`docs/agents-method.md:118` would nominally route that to a manual `self-review`. **Adjudicated: no edit
is owed, and `docs/workflow.md` stays untouched on this point.** The argument is not that the fold's
output falls outside `:119`'s predicate — reading "user-facing artefact" as excluding a planning document
is an uncited judgement about someone else's wording, and it is the weaker case. The stronger one is that
the fold's output is **machine-gated**: `scripts/check-redline.sh folded` compares the three retained spec
sections byte-for-byte against `git show HEAD:<spec>` and asserts the design carries none of the three
residue patterns (AC13, AC14, AC16). That is strictly more than a `self-review` spawn on a docs-only commit
would deliver, so the obligation is over-satisfied rather than argued away.

### The amendment route is mandated at EIGHT sites, and every one needs an edit

Narrowing the Arm A / Arm B routing table at `skills/task/SKILL.md:173-174` is not sufficient, and the
failure is not subtle: **the orchestrator reads a different sentence and routes anyway.** Six further
sites mandate the route in their own words, and two more forbid the non-breaking remedy by implication.
All eight are listed with a disposition each, so the check is a roll-call rather than a search.

| Site | What it says today | Disposition |
|---|---|---|
| `skills/task/SKILL.md:104` | the Design Amendment trigger itself: "**or** a self-review finding requires a design change: stop the step, surface to user for approval, spawn the `design` subagent" | **narrow** — the marking pass satisfies "requires a design change" word for word |
| `skills/task/SKILL.md:112` | "The amendment TRIGGER is mechanical and mandatory (above) — 'one line', 'AC text unchanged', and 'docs-only' are not mitigating inputs … never whether the recipe fires" | **narrow** — this sentence explicitly forecloses the escape this mechanism depends on |
| `skills/task/SKILL.md:173-174` | the Arm A / Arm B routing rows | **narrow** (already planned) |
| `skills/task/SKILL.md:131` | "Implementation reveals design must change → trigger **Design Amendment**, then resume." | **narrow** — a gate-checklist row, same predicate |
| `skills/task/reference.md:262` | "**Requires a design change** → trigger the **Design Amendment** recipe (user approval required)" | **narrow** — the Step 11 disposition list |
| `skills/task/reference.md:301` | "Design change → Design Amendment triggered?" | **narrow** — the Step 11 gate-checklist row |
| `skills/task/reference.md:82` | "Silently implementing a deviation without triggering Design Amendment — FORBIDDEN." | **narrow by naming the alternative** — see below |
| `skills/task/reference.md:287` | "Silently deviating from the design without triggering Design Amendment." | **narrow by naming the alternative** — see below |

`:112` is the decisive one. It states that the trigger is mechanical, that "docs-only" is not a
mitigating input, and that the soft verb beneath it governs only the review's *depth* and "never whether
the recipe fires". An orchestrator that reads `:112` after this change still routes the marking pass into
the full chain, and Scope 2 / AC2 fails while the two rows at `:173-174` read as narrowed. A reviewer
checking AC2 by reading those two rows would see compliance and the mechanism would not work.

**The two `Silently …` sentences are edited rather than relied on as-is, and the reason is this section's
own thesis.** They can be read as forbidding only *silence* — on which reading a marked item with a log
row is already permitted, since it is the loudest available record. That reading has force, but it is not
the only one available and the surroundings favour the other:

- `:82` is the **first line of a two-line blockquote**, and its sibling `:83` is "Editing `*.design.md`
  inline instead of spawning the `design` subagent — FORBIDDEN." The pair guards the recipe's
  integrity — don't skip it, don't do it yourself — so in that position "without triggering Design
  Amendment" reads naturally as naming the omission of *the recipe*.
- `:287` sits in the `## FORBIDDEN` list beside six unconditional bans ("Skipping design review",
  "Pushing from the default branch", …), where the register is absolute.

So the sentences are **ambiguous**, and keeping them would mean resolving an ambiguity by assertion —
which is precisely the failure this section exists to catch: the orchestrator reads a different sentence
and routes anyway. Asserting a favourable reading of an ambiguous rule is the same mistake as narrowing
one site and declaring the set handled.

**The remedy is better than narrowing, because it makes the claim true by construction:** name the
alternative in the sentence itself.

| Site | Becomes |
|---|---|
| `:82` | "Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — recording a redline marker and its log row — FORBIDDEN." |
| `:287` | "Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — recording a redline marker and its log row." |

**The case qualifier is not optional, and leaving it out silently drops a backstop.** An unqualified
"either … or recording a redline marker and its log row" is satisfied by a **breaking** divergence that
records a marker — so these two sentences would stop forbidding the one case they must keep forbidding,
and before the rewrite they were absolute and did forbid it. The spec settles this twice over, in its own
words: Scope 1 requires "Breaking → blocker, **routed as today**", and AC2 requires the routes be
"narrowed to the breaking case **only**". A sentence letting a breaking divergence escape by marking is
not a narrowing to the breaking case; it is a widening of what is permitted, in the opposite direction
from the one the spec asks for. The qualifier is therefore mandated by the spec directly and adds no
requirement of the design's own.

With the qualifier, all three cases land where the spec puts them: a breaking divergence must still route
or it is forbidden; a non-breaking one may mark instead; and a deviation with neither remedy is forbidden
either way, so the original "silence" prohibition survives intact.

**Char cost, measured rather than estimated:** `+110` bytes at `:82` and `+109` at `:287`, so `+219` on
`skills/task/reference.md` against its 1,391 of headroom. These two are **additions**, because the case
qualifier has nothing to swap out; the other six are true substitutions ("requires a design change" →
"breaks the agreed approach") and are net-neutral to net-negative. `skills/task/SKILL.md` carries 2,899
of headroom and takes only substitutions. Any rationale that will not fit in a substitution goes to
`docs/workflow.md`, which has 8,223 chars and is already a task-4 file; re-measure `reference.md` at
task 5's close, where the Risks section already requires it.

### The gate: two new arms, both in a script that already exists

`skills/task/scripts/check-fix-plan.sh` is the right host and not a new script: it already parses the
plan, already resolves and quote-checks the Arm A cell, is already in `scripts/run-checks.sh`'s
`EXEMPT_CHECKS` (so no registration churn), and its suite `skills/task/scripts/test-check-fix-plan.sh` is
already named in `AGENTS.md` item 4.

**Arm A7 `redline-accounting`, on the `plan` verb.** Fires when a row is dispositioned `fix` *and* its Arm
A cell's anchor names `ai-docs/plans/*.spec.md` or `ai-docs/plans/*.design.md`. Decision `REFUSE`, reason
`arma-unaccounted`.

The arm fires on `fix` **only**, and the exclusions are not conveniences:

- `amendment: spec` / `amendment: design` already route the round — the breaking path, accounted for.
- `redline: <type> — …` is the accounting itself.
- `resolved: <reason>` must stay exempt. The comment at `skills/task/scripts/check-fix-plan.sh:496-502`
  records that its *documented primary case* is "a finding closed before the round by an approved
  amendment names the artefact the finding cited" — so a `resolved:` row legitimately carries a non-`none`
  Arm A cell whose sentence is already true. Firing on it would re-break what that guard was added to fix.
- `object: <reason>` disputes the finding, so no divergence is asserted. The escape hatch this opens has a
  human on it: an objection to `major`/`blocker` needs the user's confirmation
  (`skills/task/SKILL.md` — "Three acts never leave the orchestrator").

The suffix pair is spelled once in the file already, as `IGNORE_GLOB_SPEC` / `IGNORE_GLOB_DESIGN`
(`:97-98`); the arm reuses those variables rather than adding a third spelling.

**Arm A8 `redline-undelivered`, on the `applied` verb.** For every `redline:` row in the round's plan,
assert the design file now carries `[REDLINE R<N>.<K>` and the log carries a row keyed `R<N>.<K>`. This is
the half AC9 names literally — "with no accounting log row is refused" — and it can only run after the
marking pass, which is why it is on `applied` rather than `plan`.

**A8 derives both paths from the progress file's own basename**, not from a new convention and not from an
argument: `<base>.progress.md` → `<base>.design.md` and `<base>.redline.md`, each looked up in
`ai-docs/plans/` and then `ai-docs/plans/done/`. The two-location lookup is `cleanup-progress.sh:43`'s,
reused rather than reinvented — a third spelling of "where the plan artefacts live" is precisely the drift
this change is trying to reduce elsewhere.

**AC9's gate is bounded by a self-declared field, and the bound is stated rather than left implied.** Both
arms key on the Arm A cell, which the scout writes. A scout that writes `none` where a sentence really is
at stake escapes the accounting entirely, and no mechanical check can see that — judging whether closing a
finding would leave a sentence untrue is the judgement Arm A exists to capture. So "enforced by a
CHECKED-IN GATE" is true of the *accounting*, not of the *detection*: given a truthful Arm A cell, the gate
makes the accounting unavoidable; it cannot make the cell truthful. The existing A1 quote-verification is
what makes a *non-`none`* cell trustworthy; a `none` cell is unfalsifiable by construction. This is written
into the gate's own comment block so the next reader does not mistake its reach.

**Probe F, run by the reviewer rather than by this design and reproduced here:** a `redline:` row whose
target is the design file leaves A3 at `pass` and fires only A6 (the vocabulary, before the token exists).
That is the direct confirmation of the central claim above — the `fix` guard at `:510` is what keeps the
`redline:` disposition off the routing leg — and it upgrades that claim from asserted to measured.

**One accounting consequence, recorded because a human reads the number.** `ai-docs/plans/*.redline.md` is
deliberately **not** added to `IGNORE_GLOB_SPEC` / `IGNORE_GLOB_DESIGN`, so the log's rows count toward the
`applied` verb's `actual_changed_lines`. Nothing fires on that figure — it is a measurement by design — but
the orchestrator reads it, so the marking pass's rows will show up in it. Adding a third ignore glob was
rejected: the two existing globs are the suffixes the *routing arms* key on, and
`docs/templates/progress-format.md:145` states that identity explicitly. A third glob with no routing arm
behind it would break that correspondence for a cosmetic gain in a number nothing decides on. **[REDLINE S8.1]**

**The gap AC9 closes was measured, not inferred.** Four probes against today's gate, on synthetic
fixtures modelled on the suite's own `mkfix` helper:

| Probe | Plan row | Today's verdict |
|---|---|---|
| A | `fix` + a non-`none` Arm A cell citing `docs/quoted.md:10` | `decision=PASS`, all six arms pass |
| **B** | `fix` on code + Arm A citing `ai-docs/plans/t.design.md:10` — *the non-breaking case* | **`decision=PASS`** — nothing accounts for the sentence |
| C | `redline: modified — …` | `A6 finding-coverage FAIL … is outside the vocabulary` |
| D | `amendment: design` | `decision=ROUTE-DESIGN reason=design-amendment` |
| E | `fix` **targeting** `ai-docs/plans/t.design.md:10` | `decision=ROUTE-DESIGN` — "finding 1 targets ai-docs/plans/t.design.md:10" |

Probe B is the defect: the code fix is correct, the design sentence is stale, and the gate says PASS.
That run is the pre-mandate demonstration AC9 requires, and it ships as the test's control leg. Probe D is
the half AC8 requires to keep failing. Probe E is why the `redline:` disposition must route on neither leg
— and the `if [ "$disp" = fix ]` guard at `:510` already ensures that.

### No revision account in a design, and the reviewer's clause is the half that makes it hold

A design states the working logic and the design decisions at its current revision. It carries no account
of what an earlier draft said or argued — no "an earlier draft claimed", no quoted superseded wording, no
narration of what a previous round found. Every such passage is read in full by every later
whole-repository review, and none of it describes the system.

**Both sides of the review need a clause, and the reviewer's is the operative one.** Neither
`agents/design.md` nor `agents/design-review.md` carries such a rule today — confirmed by reading both.
So an author-only rule is overridden by the next verdict that asks for the opposite, and a verdict asking
for the opposite is not hypothetical: the rule's absence is what lets a reviewer require a revision
account as a condition of GO.

| File | Clause |
|---|---|
| `agents/design.md` | While the design is being authored or reviewed, a correction is a **rewrite**. The document carries no account of what an earlier draft said or argued. |
| `agents/design-review.md` | **A revision account is not a thing a verdict may require.** A correction's reasoning belongs in the round's own findings table, which is where a reviewer can already see it and which is not read by later reviews. |
| `agents/design-review.md`, checklist | **A revision account found in the design under review is FLAGGED**, at the same severity as any other passage that does not describe the system. |

**The third clause is an addition beyond AC23, and that is recorded here as a decision rather than left
to look like an accident.** AC23 does not require it: the author clause forbids writing an account, the
reviewer clause forbids requiring one, and the fold plus AC13 keeps one out of `ai-docs/plans/done/`, so
the residual exposure is **in-task only**. The orchestrator's call was to close that window anyway, and
the ground is cost: every subagent spawn during the task reads the design in full, so the in-task window
is exactly where the reading cost falls. A rule stated by two files and enforced by neither during the
stage where it costs most is the "a check mandated in prose is not yet a check" shape this repository
documents against.

**Deliberately NOT widened past that.** The reviewer clause stays narrow — it forbids *requiring* an
account and nothing more. Widening it into a general restatement of the author's duty would put the same
rule in two files, which is the drift shape this change spends eight sites removing. One duty, one home;
the checklist clause adds detection, not a second copy of the prohibition.

**This extends tasks 3 and 4 rather than adding a task.** `agents/design.md` is already task 3's file and
`agents/design-review.md` already task 4's — task 4 was rewriting `:32` and re-pointing `:39` / `:85`
there. So `M` stays at **7** and the handoff plan is unchanged; I checked this rather than assuming it,
because a new file in the set would have moved a group boundary.

**Mechanising AC23's two-sided demonstration.** `scripts/check-redline.sh` gains a fifth verb,
`revision <file>`, which flags the named phrases that introduce a revision account. Four legs, two
subjects:

| Leg | Subject | Expected |
|---|---|---|
| positive | a design fixture carrying "an earlier draft said …" | flagged |
| control | a clean design fixture | passes |
| positive | a verdict fixture whose issue row demands a revision account | flagged |
| control | a verdict fixture carrying an ordinary finding | passes |

**What the verb does and does not establish, stated rather than left to be assumed.** It matches a
bounded phrase list, so it catches the named introducers and not every possible paraphrase. The clause in
the reviewer's brief is what binds generally; the verb's job is to make the clause demonstrable and to
catch the common shapes. This is the same honest bound as arm A7's: the gate makes the duty unavoidable
where it can see it, and the brief covers the rest.

### The fold AUTHORS the design afresh, and writes it section by section

The fold does not edit the frozen design. It **re-authors** it from the shipped state. An in-place edit
leaves every sentence the editor did not touch, and what it does not touch is exactly what nobody
re-read — stale by omission, and invisible to any check that looks only at what changed. A freshly
authored document cannot inherit a stale sentence through a gap.

Same output path: `ai-docs/plans/done/` holds one design per task and `agents/review-findings.md:25`
depends on that, so "afresh" means re-authored in place of the old content, never a second file.

**"Afresh" is not "only what is needed" — everything outside the strip set is re-authored, not dropped.**
The strip set is closed and short: `## Handoff plan`, `## Open questions`, every marker, amendment
residue, and any record of superseded material. Everything else the design carries — the approach, the
decomposition, the risks, the rejected alternatives, the test design — is **re-authored against the
shipped state**, because a reader of `ai-docs/plans/done/` needs to know what was built and what was
deliberately not chosen. Dropping a section is not a cheaper fold; it is a different and worse document,
and `agents/review-findings.md:38` still re-runs the verification lines from the design that survives, so
a design that dropped its Test Design would break a post-merge pass. Stated because "afresh" reads to
some as licence to write only the minimum. **[REDLINE R1.6]**

**It must nonetheless be written section by section, not in one call.** `agents/design.md:126` records
the hazard directly: a full-file rewrite of a ~50KB design is the highest-risk moment for a transport
drop, with two observed attempts — 51s and 291s — both dying before the write landed. The fold's input is
a design of exactly that size class, so a single `Write` is the one shape most likely to lose the whole
pass. The brief therefore specifies:

- the fold composes the as-built document **section by section**, each a short targeted write;
- it verifies on disk afterwards (mtime plus a `grep` for an expected new string), because the harness
  does not retry on a socket close;
- the residue check runs **after** that verification, so a partial write is caught as a residue failure
  rather than passing as a fold.

The two instructions are not in tension: "afresh" constrains *what the content is derived from* — the
shipped state, not the previous text — while "section by section" constrains *how the bytes are
delivered*. An implementer reading only the first would reach for one call, which is why both are stated
together.

### The merge-time refusal, and why it is one script shared by two skills

AC11's refusal must run **before** `/pr-merged` does anything, and that is earlier than it first appears:
the log is committed on the branch, so once `git checkout main` runs (step 1) the file is no longer in the
worktree. The guard therefore sits above step 1, beside the existing branch and dirty-tree guards at
`skills/pr-merged/SKILL.md:17` and `:21`. `cleanup-progress.sh` cannot host it — it runs at step 3, after
the checkout, and always exits 0 by design (`:15`).

AC11 requires a test, so it must be a script. It is placed at **`scripts/check-redline.sh`**, not under
either skill's `scripts/`, because both `/redline-fold` and `/pr-merged` need it and
`${CLAUDE_SKILL_DIR}` cannot reach across skills. Precedent for a root-level, argument-taking check that
is not a `run-checks` member: `scripts/check-release.sh` and `scripts/check-candidate.sh`, both already in
`EXEMPT_CHECKS` (`scripts/run-checks.sh:159`). `scripts/check-redline.sh` joins them — it must, because
`stray_checks()` reports any tracked `check-*.sh` that is neither exempt nor a member, and
`documented_checks()` recognises only the `bash scripts/<name>.sh` spelling inside `AGENTS.md`'s
structural-check span, which an argument-taking per-task gate cannot take.

Five verbs, one script, one suite. **Every verb uses this repository's exit convention — `0 clean,
1 findings, 2 cannot run`** — verified in `scripts/check-references.sh:6` and
`scripts/check-release.sh:6`, and required by `AGENTS.md`, which says twice that a tool "exits 2 when it
cannot run, which is not a pass".

| Verb | 0 (clean) | 1 (findings) | 2 (cannot run) | AC |
|---|---|---|---|---|
| `pending <plans-dir>` | no unprocessed log | an unprocessed log is present | the directory is unreadable, the globs cannot be resolved, or the tree is not a work tree | AC10, AC11 |
| `folded <spec> <design>` | the three spec sections byte-identical to `git show HEAD:<spec>`, the design free of all three residue patterns, the log gone | any of those fails | the previous commit is unreachable, so there is no comparand | AC13, AC14, AC16 |
| `suppression <file>` | every suppression-conferring instruction names the spec alone | one names a design or the directory | the file is unreadable | AC15 |
| `acintent <spec> <design>` | every criterion has an intent line and no line carries an identifier | a criterion is uncovered, or a line names one | either document is unreadable | AC22 |
| `revision <file>` | no revision-account introducer present | one is present | the file is unreadable | AC13, AC23 |

**`folded`'s superseded-material leg is split, because only half of it is mechanical.** AC13 requires
that leg be checked **positively**: a document recording its own corrections necessarily contains the
superseded text inside a quotation, so proving an absence from a fragment search returns a false positive.
So the verb runs the `revision` phrase scan as a **spot-check**, and the assertion that every section
describes the shipped state is a judgement step in the fold's brief, named as a judgement rather than
dressed as a gate. Stating which half is which is the point: a fragment search here is actively
misleading, not merely weak. **[REDLINE R1.2]**

**The polarity matters more here than anywhere else in this change**, and the inverted form is worth
naming so nobody reaches for it. Were `pending` to return 0 for *present*, with `/pr-merged` refusing on
0 and 2 reserved for nothing, then a missing plans directory, a lost execute bit and any internal error
would all return non-zero — and `/pr-merged` would read non-zero as "nothing to refuse" and proceed to
`git checkout main` and the cleanup. The one gate whose entire purpose is to be a backstop would have
**silent passage as its failure mode**, and AC11's two legs (fires on a present log, does not fire on an
absent one) cannot see it, because neither leg is a cannot-run. So:

> **`/pr-merged` refuses on anything that is not a clean 0**, and says which of the two it got. The suite
> carries a third leg for the cannot-run lane alongside AC11's two.

**`suppression`'s predicate is written down, because AC15 requires the check to name its own pattern.**
It enumerates every line matching `done/` **OR** `design\.md`, then asserts each enumerated instruction
names the spec alone. The disjunction is the whole point, measured on today's file: `design\.md` alone
returns `:25` and `:38` and **misses `:115`** — the restatement that confers the same authority by naming
the *directory* — while `done/|design\.md` reproduces all four (`:25`, `:36`, `:38`, `:115`). A criterion
met by the narrower grep is the false green AC15 exists to prevent, so the wider pattern is part of the
contract rather than an implementation choice. Of the four the disjunction reaches, `:25` and `:115`
confer suppression and are narrowed, `:38` is the AC-verification re-run and is retained verbatim, and
`:36` is a heading — so the verb asserts a per-line disposition, not a count. A fixture conferring the
authority through the directory spelling alone is its negative leg.

**On AC14's comparand.** The spec's three retained sections are compared against `git show HEAD:<spec>` —
version control, which predates the rewrite and therefore cannot be the rewrite. A captured scratch copy
would be written by the same pass that rewrites the file; `git show` cannot be.

### Where the redline log's format is documented

`docs/templates/progress-format.md`, as a new `## The redline log (committed)` section. Three reasons:

1. AC6 asks for "the same register as the existing `Fix Plan (Round N)` section" — colocation is the
   strongest available form of that.
2. The row is derived from the `Fix Plan (Round N)` row documented in the same file, so the derivation is
   visible in one read rather than across two.
3. 20,208 chars of headroom, against a set in which four files have under 3,000.

Two small amendments come with it: the scope line at `:3` and the absolute claim at `:7` ("All these paths
are **gitignored**") both need the committed sibling named. That contrast — the progress file is
gitignored, the redline log beside it is committed — is the mechanism's load-bearing fact, so stating it at
the file's head is an improvement rather than a tax.

A separate `docs/templates/redline-format.md` was rejected: a tenth file to keep in sync, for content
whose only reader is the party already reading the file beside it.

### The log's path, lifecycle and the `done/` move

`ai-docs/plans/<spec-base>.redline.md`, moving to `ai-docs/plans/done/` with the spec and design at
`/task` Step 12 item 4, and deleted by the fold.

- **Not gitignored — AC7.** `git check-ignore -v ai-docs/plans/2026-10-10-redline-corrections-log.redline.md`
  → rc=1 (not ignored); positive control on the same form,
  `git check-ignore -v ai-docs/plans/foo.progress.md` → rc=0, matched by `.gitignore:22`.
- **Not deleted by `/pr-merged` — AC7.** `cleanup-progress.sh:46` removes
  `ai-docs/plans/<spec-base>.progress.md` and nothing else.
- **Moved at Step 12, deliberately.** The fold runs after approval, by which time Step 12 has already
  `git mv`'d the spec and design to `done/`. Carrying the log in the same move gives the fold, the
  refusal and the post-merge reader one location instead of two. The `pending` verb still checks both
  globs — a branch that never reached Step 12 can carry a log — which is the same two-location lookup
  `cleanup-progress.sh:43` already performs.
- **Removed by the fold.** A surviving log is the unambiguous mechanical signal that the fold never ran,
  which is what makes AC11's refusal possible at all.
- **The post-merge reading list is NOT widened — AC16.** `agents/review-findings.md:25` names
  `*.spec.md` and `*.design.md`; both globs are suffix-specific, so a `.redline.md` in `done/` is
  invisible to it without any edit.

### Scope 11 / AC22: the design promises verification INTENT, never an identifier

**The gate that fires the in-task loop survives Scope 1 untouched.** `agents/self-review.md:52` is the
GO-with-notes staleness sentence Scope 1 narrows; `:53` is a *separate bullet* — the AC-verification-grep
re-run — so narrowing `:52` leaves it in force. `:53` is therefore an edit target in its own right.

**Nine enforcers plus a back-reference, and a token sweep reaches only six of them.**

`grep -rn 'AC<N> verified by' docs agents skills rules hooks` returns **exactly 6** occurrences —
`agents/design.md` ×2, `agents/self-review.md`, `agents/review-findings.md`, `agents/design-review.md`,
`skills/task/reference.md`. **Three more enforce the same duty in a different vocabulary and are
invisible to that sweep**, which is the `docs/propagation.md:47` hazard in its exact documented form: a
file that describes a mechanism in its own words carries none of the changed token. `agents/design-review.md:85`
says "AC-verification **command**"; `agents/design.md:108` and `agents/design-review.md:39` say
"exit gate" — found by `grep -rn 'exit gate'`. The two most strongly worded enforcers of the duty are
among those three, so a sweep-only inventory would have left it standing exactly where it bites hardest.
The set below is therefore built from the RULE's description across both vocabularies, not from either
spelling alone.

| # | Enforcer | What it says today | Disposition |
|---|---|---|---|
| 1 | `agents/design.md:94` | the template example, which writes a literal test-method name | rewritten to an intent example |
| 2 | `agents/design.md:108` | "**Never pin a command as an exit gate without having RUN it** … `design-review` rejects an unexecuted gate as `major`" | re-pointed with `:85`/`:39` — see below |
| 3 | `agents/design.md:116` | the mandate: "linked to a **concrete** test / search / shell command" | rewritten to demand intent |
| 4 | `agents/self-review.md:53` | re-runs every command "from the design against the shipped artefact" | rewritten to the falsification predicate below |
| 5 | `agents/review-findings.md:38` | the same re-run over `done/*.design.md`, post-merge | **intent-coverage**, deliberately weaker than the in-task gate — see below |
| 6 | `agents/design-review.md:32` | "`AC<N> verified by: <command>` lines present for every AC?" | rewritten to the intent form |
| 7 | `agents/design-review.md:39` | "Any command the design pins as an exit gate MUST be EXECUTED — twice — before GO … If you cannot run it, the verdict is **ITERATE**" | re-pointed in step with `:85` — see below |
| 8 | `agents/design-review.md:85` | "A verification gate is a claim about a command, and MUST be falsified before it is trusted" | re-pointed, not deleted — see below |
| 9 | `skills/task/reference.md:298` | the Step 9 gate-checklist row naming the command form | rewritten to the intent form |
| — | `skills/ai-audit/reference.md:332` | back-reference: "`design-review`'s rule that an exit gate must be run twice before it is trusted" | follows whatever `:39` becomes |

**`:39` and `:85` move together or not at all.** `:39` sits in `design-review`'s operative Step-4
checklist; `:85` sits in its Rules appendix. Re-pointing only the appendix leaves the workflow and the
rules disagreeing, and `:39`'s own words then return **ITERATE** on a design that complies with the new
mandate — the reviewer would reject compliance. Both files carry over 23,000 chars of headroom, so there
is no size reason to split them.

One bullet survives unchanged and should not be swept into this: `agents/self-review.md:201` says a
passing AC-verification grep is necessary but not sufficient for a prose deliverable. That is a claim about
sufficiency, not about commands, and it is true of the falsification predicate too.

**AC22 clause 4: the two gates get DIFFERENT predicates, and the divergence is recorded as deliberate
with its reason — the clause's second arm, not its first.**

| Gate | Predicate | Why this one |
|---|---|---|
| `agents/self-review.md:53` — in-task | **falsification** (the predicate is stated once, below) | It runs while the round's per-criterion record still exists, so it can read the `Shown non-empty by` column |
| `agents/review-findings.md:38` — post-merge | **intent-coverage**: each `AC<N> verified by:` intent line in a `done/*.design.md` is covered by some shipped check | It runs after the record is gone. There is nothing stronger it can read |

**The reason is a lifecycle fact, not a preference, and one predicate is unavailable in both
directions.** The falsification evidence lives in the progress file: `.gitignore:22`
(`ai-docs/plans/**/*.progress.md`) means it is never committed, and `cleanup-progress.sh:46` deletes it
at `/pr-merged` step 3. So the stronger predicate cannot go post-merge — it would specify a read of a
file that has been deleted — and the weaker one cannot come in-task, because the in-task gate *can* read
the column and settling for less would discard evidence that exists.

**This is a scope decision, not wording.** § Rejected alternatives refuses a committed sidecar for the
concrete check set *on the ground that* nothing consumes it after merge once `:38` checks
intent-coverage. That reason holds only under the split above. Had `:38` been given falsification, the
sidecar's rejection would collapse and a committed carrier would come back into scope — so the two
passages are load-bearing on each other and must agree. They now do, and the rejection stands unchanged.

Intent-coverage is weaker than falsification but it is not vacuous: it still fails a criterion nothing
covers. Leaving `:38` re-running commands is the option that *is* vacuous, and § Rejected alternatives
records why.

**Intent-coverage is strictly weaker than falsification, and the gap is this project's own best-documented
defect.** "A check exists that covers this intent" says nothing about whether that check can come back
non-empty. `AGENTS.md` item 4 is the standing proof: three natural spellings of `bash -n` all report
success on a file that does not parse, one of them with no output at all. Each would satisfy
intent-coverage; none is a gate. So the in-task predicate is never "is covered":

> **Each criterion's covering check has been shown able to come back NON-EMPTY** — run once as written,
> and once against input engineered to make it fire.

**That duty is re-pointed, not removed, and its new home is
`docs/templates/progress-format.md`** — the `Shown non-empty by` column of the per-criterion record
defined in § Where the concrete set goes. The duty carried by `agents/design.md:108`,
`agents/design-review.md:39` and `:85` — a verification gate is a claim about a command and must be
falsified before it is trusted — is *correct and must not be lost*; it simply has no object in the design
any more, because the design no longer names commands. Attaching it to the column that holds the command
means the two cannot drift apart: they are the same row. Three enforcers then point at it rather than at
the design:

| Enforcer | Re-pointed to |
|---|---|
| `agents/design.md:108` | the gates **this** design pins — the commands recorded under § Approach as measurements — which remain subject to it in full |
| `agents/design-review.md:39` | the same; the reviewer still demands a twice-run gate, of the design's own gates, not of a per-criterion command the design no longer writes |
| `agents/design-review.md:85` | the per-criterion record's falsification column, asserted as part of the Step 9 close rather than at design review |

Decomposition task 3 writes the column and its contract; task 4 writes the three re-pointings and the
`agents/self-review.md:53` predicate that reads the column. Neither is left to be inferred.

**The distinction that makes the rule implementable.** "Names no test method, file path or command" bites
on the identifiers of the CHECK, never on the subject under test. A test method name, the test file's
path and the command are all chosen while the tests are written — that is the entire rationale. The
artefact being observed is named in the spec and is not chosen later. So:

- allowed: *"that the merge-time workflow refuses while an unprocessed log is present, and does not refuse
  when none is"* — an observable property plus its control
- forbidden: *"`bash scripts/test-check-redline.sh` filtered to `the refusal fires on a present log`"*

Task 3 writes this distinction into `agents/design.md`; the rule is unusable without it.

**A recorded measurement is not a pinned gate.** This document's § Approach quotes commands that were run
while designing (probe verdicts, `wc -c` figures, `check-references.sh` legs). Those are historical facts
about what was observed; a later rename cannot falsify them. What AC22 forbids is pinning a command as the
criterion's *exit gate*. The line is clean and the design states it rather than leaving it to be inferred.

**Where the concrete set goes: the progress file, and its lifecycle is honest.** A new
`## Criterion checks (Round N)` section — four columns:

| Column | Holds |
|---|---|
| `AC` | the criterion id |
| `Intent` | the design's intent line, copied |
| `Covering check` | the concrete command / test identifier / path, chosen while the tests were written |
| `Shown non-empty by` | the input that made that check fire, and the result — **blank is a refusal, not a default** |

The fourth column is the falsification duty's new home (§ above). The section is **not** called an
"AC verification map": `agents/self-review.md:186` already uses that exact phrase for a different thing
(an AC-verification map nobody re-derives), and a second mechanism under one name is the collision AC17
exists to prevent on the other side of this change.

It is gitignored, so it dies with the branch, and nothing downstream needs it once it is gone — the
durable evidence is the committed tests themselves. This is deliberately *not* the failure
`ai-docs/context.md:222-223` records, where a figure died with the progress section and left a
disposition "naming a route that did not exist": there, something downstream still needed the number.

**That the fourth column is enforced by prose rather than by a check is deliberate**, recorded so it does
not read as an oversight: no acceptance criterion requires a mechanical read of it, the round that writes
it is the round that is reviewed, and a gate verb asserting the column is non-blank would be cheap to add
later if the prose proves insufficient.

**Mechanising AC22's two-sided demonstration.** `agents/self-review.md` is a prose brief and cannot be
unit-tested, so the demonstration needs a real check. `scripts/check-redline.sh`'s
`acintent <spec> <design>` verb decides the two halves that *are* mechanical:

1. every AC id in the spec's `## Acceptance Criteria` table has a matching `AC<N> verified by:` line in
   the design — this is AC22's "a criterion with no covering check still fails" leg, and it preserves
   everything the old mandate was for;
2. no such line carries a token of command / path / test-identifier shape — the intent-purity half.

Renaming a shipped test then provably changes nothing, because no AC line names one: the suite's rename
leg renames a test in a fixture, re-runs the verb, and asserts it stays green. Semantic coverage —
*does this check really establish that property* — stays the reviewer's judgement, and the design says so
instead of claiming a script decides it.

### This document is the rule's first consumer

Its `## Test Design` section states intent per criterion and pins no command. That is a deliberate
departure from `agents/design.md:116` as it reads **today**, under the spec amendment that rewrites `:116`.
Flagged here so it reads as compliance with the spec rather than as an omission.

### Rejected alternatives

| Alternative | Why not |
|---|---|
| A new `ai-docs/redline/` root for the log | Measured: `check-references.sh` L4 fires `major` on it, forcing an `agents-method.md` edit against 123 chars of headroom. The plan tree costs nothing. |
| A new column in the fix-plan table for the redline payload | Changes the parsed cell count, so every shipped example, the scout's brief and the parser move. A sixth disposition changes a `case`. |
| The reviewer writes the committed log directly | `agents/self-review.md` is shared by three out-of-scope callers; they would all acquire the behaviour. |
| A new repo-level `run-checks` member for the completeness gate | It is a per-task, argument-taking check, not a repo-content check; `run-checks` would invoke it with no arguments. `EXEMPT_CHECKS` is the documented shape for exactly this. |
| A separate script per skill for the refusal | `${CLAUDE_SKILL_DIR}` cannot reach across skills; two copies of one decision is the drift shape this repo keeps paying for. |
| Gate the fold on `gh pr view --json reviewDecision` | Measured: empty on all 20 PRs this repo has had. The gate could never pass. |
| Strikethrough as a second marker syntax | It preserves the superseded wording, which no design may carry at any stage; and a second syntax doubles the residue patterns for no new information. |
| Marking deferred to the fold, or once per divergence | Both forbidden by the spec's settled decision. |
| Leave `agents/review-findings.md:38` re-running commands | After the change the design carries no commands, so it would pass vacuously — a false green, not a divergence. |
| Delete `agents/design-review.md:85`'s falsify-before-trusting duty | The duty is right; only its object moved. Deleting it loses a real guard to a bookkeeping change. |
| A committed sidecar file for the concrete AC-check set | Nothing consumes it after merge once `:38` checks intent-coverage; a committed file with no reader is a thing to drift. |
| A script that judges whether a check really establishes a property | Semantic, not mechanical. Claiming a script decides it is the "check mandated in prose" trap inverted. |

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **The fix-plan gate.** Add the sixth disposition (three closed `redline: <type> — ` patterns, reusing the `?*` empty-payload refusal) and extend the out-of-vocabulary message; add arm **A7 `redline-accounting`** to the `plan` verb (fires on `fix` + an Arm A anchor under either plan-artefact glob; exempts the other four dispositions, with the `resolved:` exemption reasoned in a comment); add arm **A8 `redline-undelivered`** to the `applied` verb; reword the `excluded-in-round` explanation so the marking pass is a named legitimate writer. Reuse `IGNORE_GLOB_SPEC` / `IGNORE_GLOB_DESIGN`; touch neither routing leg. Suite legs written first, including the probe-B control that must fail before the arm exists. **[REDLINE S8.1]** **[REDLINE S8.4]** | `skills/task/scripts/check-fix-plan.sh`, `skills/task/scripts/test-check-fix-plan.sh` | — |
| 2 | **The new gate script.** Create `scripts/check-redline.sh` with five verbs — `pending`, `folded`, `suppression`, `acintent`, `revision` — on the repository's `0 clean / 1 findings / 2 cannot run` convention, with `suppression`'s `done/` OR `design\.md` disjunction and `revision`'s phrase list written into the script's own comment as contract. Suite written first: per verb, a leg that must come back non-empty, a control that must come back empty, **and a cannot-run leg** — `pending`'s is the one whose absence turns the backstop into silent passage. `revision` carries four legs, over a design subject and a verdict subject. Register: `git add -N` both paths before any shell-syntax run. **[REDLINE S8.3]** **[REDLINE S8.5]** | `scripts/check-redline.sh`, `scripts/test-check-redline.sh` | — |
| 3 | **The design subagent's contract + the two record formats.** `agents/design.md` gains `## Redline marking` (the pointer-token spelling, the freeze point at the design-review GO verdict, the one-invocation-per-round bound, the row's derivation from the plan row) and `## The redline fold` (**fresh authoring written section by section** per the transport-drop hazard at `:126`, the three-pattern residue strip, the positive superseded-material assertion, the spec collapse); gains the **author-side no-revision-account clause** (a pre-GO correction is a rewrite; the document carries no account of what an earlier draft said); has `:94` / `:116` rewritten to demand verification intent **with the check-identifier-versus-subject distinction stated**; and has `:108`'s falsify-before-trusting duty re-pointed at the design's own pinned gates. `docs/templates/progress-format.md` gains `## The redline log (committed)` and `## Criterion checks (Round N)` — the latter carrying the **`Shown non-empty by` column that receives the falsification duty, where blank is a refusal** — plus the sixth disposition in the vocabulary-of-five at `:145`, the marking pass in the `excluded-in-round` paragraph at `:145`, and the two head amendments at `:3` / `:7`. **[REDLINE S8.3]** | `agents/design.md`, `docs/templates/progress-format.md` | 1, 2 |
| 4 | **The review contracts.** `agents/self-review.md`: replace `:52`'s staleness sentence with the breaking / non-breaking test; narrow `:151` and the Arm A / Arm B block at `:146-149` to the breaking case; add the settled-marker rule with its explicit carve-out from `:31`; rewrite `:53` to assert **the falsification predicate read off task 3's column**, never bare intent-coverage. `agents/review-findings.md`: narrow `:25` and `:115` to the spec alone, and keep `:38` as verification on the **intent-coverage** predicate — **deliberately weaker than `:53`, because the falsification column lives in a file `.gitignore:22` never commits and `cleanup-progress.sh:46` deletes, so there is nothing stronger for a post-merge pass to read.** Write that reason into `:38` beside the predicate; a later reader who finds the two gates differing must find the lifecycle fact there, not infer a defect. `agents/design-review.md`: rewrite `:32`; re-point **`:39` and `:85` together** — `:39` is the operative Step-4 checklist and `:85` the Rules appendix, and moving one alone makes the reviewer return ITERATE on a compliant design; and add the **reviewer-side clause that a revision account is not a thing a verdict may require**, pointing a correction's reasoning at the round's own findings table. That clause is the operative half of the two-sided rule — without it an author-side rule is overridden by the next verdict asking for the opposite. `skills/ai-audit/reference.md:332`'s back-reference follows `:39`. `docs/workflow.md`: the rationale the agent files point at, plus the guard sentence that `/bugfix`, `/project-review` and post-push rounds keep today's behaviour. | `agents/self-review.md`, `agents/review-findings.md`, `agents/design-review.md`, `skills/ai-audit/reference.md`, `docs/workflow.md` | 3 |
| 5 | **The task wiring — eight sites, every one edited.** `skills/task/SKILL.md`: narrow `:104` (the trigger itself), `:112` (the mechanical-and-mandatory clause that forecloses the escape), `:131` and the two routing rows at `:173-174`, each as a *substitution* of "requires a design change" by "breaks the agreed approach"; add the non-breaking row; add the marking beat to the scouted-plan AXIOM, bounded to one invocation per round and ordered before the apply; carry the log in Step 12 item 4's move. `skills/task/reference.md`: narrow `:262` and `:301`; rewrite `:82` and `:287` to name the non-breaking remedy as a permitted alternative **with the case qualifier, copying the string from the Becomes table verbatim** — `:82` becomes "Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — recording a redline marker and its log row — FORBIDDEN." and `:287` the same without the trailing `— FORBIDDEN`. **Do not drop the qualifier:** without it a breaking divergence satisfies the sentence by marking, and the spec requires "Breaking → blocker, routed as today" (Scope 1) and the routes "narrowed to the breaking case only" (AC2). Measured cost `+219` bytes across the two. Then add `redline:` to Beat 2's vocabulary, the marking beat's recipe, the accumulated-corrections hand-off in the Design Amendment recipe, and rewrite `:298`. Overflow rationale goes to `docs/workflow.md`. **[REDLINE S8.2]** **[REDLINE S11.1]** | `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/workflow.md` | 3, 4 |
| 6 | **The command and the refusal.** Create `skills/redline-fold/SKILL.md`: the measurable preconditions, the unmeasurable-approval statement with its probe result, the empty-log branch, the nothing-starts-it branch, the two owning-subagent spawns, the `folded` gate call, the surfaced commit. `skills/pr-merged/SKILL.md`: the refusal above step 1, **refusing on anything that is not a clean 0 and naming which of the two non-clean outcomes it got**, with the sequencing limit in its own words. | `skills/redline-fold/SKILL.md`, `skills/pr-merged/SKILL.md` | 2, 3 |
| 7 | **Registration, propagation, measurement.** `EXEMPT_CHECKS` gains the new check; `AGENTS.md` item 4's suite list gains the new test; the install-smoke `SKILLS` array gains `redline-fold`; `docs/propagation.md` gains the Redline group anchor + back-reference rows; the plugin patch version is bumped. Then re-measure every touched method file, re-run the propagation gate and **read its member list, confirming by name the three members that are new** — `skills/redline-fold/SKILL.md`, `skills/pr-merged/SKILL.md` and `scripts/check-redline.sh` are the three that take the derived set from 40 to 43, re-measured against the *root-level* script path this design settles on (`agents/design-review.md` is already a member, so naming it on the group row adds nothing to the derived set) — so the figure and the rows cannot drift apart unnoticed — and run the full suite reading the processed file count beside the verdict. | `scripts/run-checks.sh`, `AGENTS.md`, `scripts/test-install-smoke.sh`, `docs/propagation.md`, `.claude-plugin/plugin.json` | 1, 2, 3, 4, 5, 6 |

**Why task 7 is last and separate.** The install-smoke `SKILLS` array is a *count* assertion
(`scripts/test-install-smoke.sh:134-137` compares distinct declared names against `find skills -maxdepth 1 -type d`),
so creating the skill directory in task 6 turns that gate red until task 7 lands. That is the intended
ordering, not an oversight — but it means a suite run between tasks 6 and 7 reports a known failure, and
the implementer must not treat it as a regression.

## Handoff plan

`M = 7`. Grouping is required for every `M ≥ 1`; maximum group size is 3 consecutive subtasks; every
non-terminal group is exactly 3; the terminal group sits within 1..3.

- **Handoff into Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. The first group is entered through a handoff like
  every other, including this one.
- **Group A:** subtasks 1–3 — both gates and the two record formats they decide on. Three subtasks.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh
  context.
- **Group B:** subtasks 4–6 — the agent contracts, the task wiring and the new command. Three subtasks.
- **Handoff after Group B:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group C with fresh
  context.
- **Group C:** subtask 7 — terminal group (1 subtask; within the 1..3 range). Registration, propagation and
  the closing measurement pass.

## Risks

- **`skills/task/reference.md` has 1,391 chars of headroom and task 5 adds to it.** Mitigation: the
  marking pass's full recipe lives in `agents/design.md` (25,578 chars of headroom), which is also its
  correct owner — the agent's own contract. `reference.md` takes only the vocabulary token, a short
  recipe beat, the hand-off sentence and the `:298` rewrite. The two narrowings it receives (`:262`,
  `:301`) are substitutions, so they are net-neutral at worst. Re-measure at task 5's close, not at
  task 7's.
- **The five amendment-route narrowings could be applied inconsistently, leaving one site still
  mandating the full chain.** It is invisible to a
  reviewer who checks only the routing table. Mitigation: task 5 names all eight sites with a
  keep-or-narrow disposition each, so the check is an enumeration rather than a search; `:112` is called
  out as the decisive one because it is the sentence that forecloses the escape rather than merely
  pointing at it.
- **`agents/self-review.md` has 1,545 chars of headroom and task 4 is its largest edit.** Mitigation:
  rule in the agent file, rationale in `docs/workflow.md` (8,223 chars). Two of task 4's edits are
  replacements rather than additions (`:52`, `:53`), which recovers space. Re-measure at task 4's close.
- **The suite is red between tasks 6 and 7** by construction, because the install-smoke skill count is an
  equality assertion. Mitigation: stated in the decomposition note above; the implementer reads it as
  sequencing rather than as a regression, and task 7 closes it.
- **A new `check-*.sh` that is neither exempt nor a member turns `gate-inventory` red.** Mitigation: task 2
  creates the script and task 7 registers it, so the window is the same one above. The failure is loud and
  names the path, so it cannot pass silently.
- **`git ls-files` sees tracked files only, so a new `*.sh` is invisible to the shell-syntax gate.**
  Mitigation: `git add -N` on both new paths is part of task 2, and the processed file COUNT is read beside
  the verdict — 52 at baseline, so 54 after. A count that did not move is the tell.
- **A plan row's Arm A cell could name a plan artefact while the finding is genuinely about code.** Arm A7
  would then demand an accounting that is not owed. Mitigation: that is what `object:` and `resolved:` are
  for, and both are exempt; the scout's brief already defines Arm A as "would closing this finding leave a
  sentence untrue", so a cell naming a sentence that is not at stake is a scout defect the arm correctly
  surfaces rather than a false positive.
- **The marker is appended inside a table cell, so a careless edit could shift a column.** Mitigation: the
  token carries no `|`; the gate's own parser refuses a row with the wrong cell count, so a shifted row
  fails loudly rather than being misread.
- **`/redline-fold` is not in the `skill-gate` set** (`hooks/lib/skill-gate.sh:33` gates `task` alone), so
  a model could invoke it. Mitigation: the skill's own first action refuses a model-initiated invocation,
  in the shape `skills/pr-merged/SKILL.md:19` already uses for the merge premise. The approval it rests on
  is the user's and cannot be measured here.
- **The fold runs after approval and `main` carries no branch protection**, so pushing it dismisses no
  approval and blocks no merge. With suppression authority moved off the design, this is a platform fact
  rather than a risk — recorded because a reader will otherwise look for the mitigation.
- **A gate script whose cannot-run lane is untested reads as a pass.** This is the Major-4 shape
  generalised: `pending` is the one check in this change whose whole purpose is to be a backstop, so its
  failure mode is the only one that matters. Mitigation: the three-outcome convention is stated as a
  contract in § The merge-time refusal, the cannot-run leg is named in task 2's deliverable list, and
  `/pr-merged` refuses on anything that is not a clean 0 rather than on a single value.
- **Pre-existing, out of scope, now tracked:** `agents/design.md:122` and `agents/design-review.md:87`
  name languages and source files from another codebase inside method files, which the project's own
  method/profile rule makes a `major`. Both predate this change and tasks 3 and 4 edit those files —
  **they stay as they are in this change.** Filed as issue **#111**; the provenance half (a named entity
  used as the house example in several further places, including the scaffold template) is issue **#112**.
  The implementer should neither silently inherit them nor expand scope to fix them.

## Test Design

**Register note.** Per the spec's Scope 11 and AC22, each line below states the verification **intent** —
what must be observed, about which artefact, and with which control — and names no test method, file path
or command. The concrete check that covers each intent — and the input that was shown to make it fire —
is recorded in the progress file's `## Criterion checks (Round N)` section as the tests are written.
Commands quoted elsewhere in this document are records of measurements already taken, not gates pinned in
advance, and they remain subject to the falsify-before-trusting duty in full.

**Scenario shape every mechanical intent below is built on.** Each new gate leg ships as a pair: one input
that must make the check come back non-empty, and one control that must make it come back empty. A leg
with only the empty direction is not accepted, because an empty result and a mistyped filter are
indistinguishable outputs.

**Fixture basis.** The fix-plan legs build on the suite's existing throwaway-repository helper, which
already produces a tracked spec artefact, a tracked design artefact and a tracked non-routing sibling
under the plan prefix — the three paths the exclusion and routing legs need in order to measure one rule
at a time. The new script's legs build their own throwaway tree with a committed spec, a marked design and
a log, because the comparand for the collapse check is the previous commit.

| AC | Verified by (intent) |
|---|---|
| AC1 | That the reviewer's contract no longer carries any instruction to reject correct code for a stale document, and that what replaced it branches on whether the approach is broken. Control: the sentence is present and findable before the change. |
| AC2 | That a non-breaking divergence produces one marker and one row and leaves the round running. Established by ENUMERATING every instruction that mandates the amendment route and confirming each either branches on approach-breakage or names the non-breaking remedy explicitly as a permitted alternative — eight sites, so the check is a roll-call and not a search, and a pass that inspects only the routing table is rejected. No site is certified on a favourable reading of an ambiguous sentence: where the wording admitted both readings it was changed, not interpreted. Control: a breaking divergence still routes. |
| AC3 | That after marking, the marked item's original wording is still present in the file and the marker sits beside it rather than replacing it. Demonstrated on a decomposition row, because that is the cell shape most likely to break. |
| AC4 | That the marking is attributed to the design subagent and bounded in the step text to one invocation per review round carrying divergences, and that no orchestrator-side edit of a design artefact is instructed anywhere. |
| AC5 | That the reviewer's contract states a marked divergence is not re-raised in a later round, with an explicit carve-out from its don't-review-the-content clause — and that the contract nowhere tells the reviewer to read the log as a separate input. The second half is an absence, so it carries its own positive control. |
| AC6 | That the row's documented shape carries a closed three-value type vocabulary, the artefact sentence diverged from, and what shipped instead; and that the gate refuses a type outside the three. Control: each of the three valid types is accepted. |
| AC7 | That the log's path is not matched by the ignore rules, with a control path that IS matched; and that the merge-time cleanup leaves the log in place while still removing what it is meant to remove. |
| AC8 | That a round carrying a marking pass passes the fix-plan gate while a genuine design amendment still routes it — the discrimination observed as two different decisions from the same gate on two inputs differing only in the disposition, not merely as one passing run. |
| AC9 | That closing a finding whose subject is a plan-artefact sentence, with nothing accounting for it, is refused by the gate. The pre-change behaviour is the control and has already been observed: the unaccounted case currently passes with every arm green, and that run ships as the suite's control leg. The gate's reach is bounded by the scout-written field both arms key on, and that bound is asserted as written down rather than demonstrated, because a field declaring its own absence cannot be falsified mechanically. |
| AC10 | That a named command exists whose step text names itself, states the empty-log branch, states what happens when nothing starts it, and establishes its before-merge position from a measurable fact; and that no surface acquires a repeated read of the review state. |
| AC11 | That the merge-time workflow refuses while an unprocessed log is present, does not refuse when none is, **and refuses on a check that could not run at all** — three outcomes, because with only the first two the backstop's failure mode is silent passage. The check's outcomes follow this repository's established convention rather than a local one, and the refusal is positioned before anything is deleted or moved. The step text states the sequencing limit in its own words. |
| AC12 | That a breaking divergence still reaches the full rebuild, that the rebuild is handed the accumulated markers and rows, and that the step text names the hand-off and the reset of the log to empty. |
| AC13 | That the folded design carries none of the three residue patterns — the two spent headings and the marker token. Control: all three are present before the fold and findable. **The superseded-material leg is checked positively, never by a fragment search:** a document recording its own corrections holds the superseded wording inside a quotation, so an absence proved from a fragment is a false positive. So the assertion is that every section describes the shipped state — a judgement, named as one — with a bounded scan for the phrases that introduce a revision account as its spot-check, and the scan's own ability to fire shown on a fixture that carries one. |
| AC14 | That the three retained spec sections are byte-identical to their pre-fold text, compared against the previous commit rather than against a captured copy written by the same pass. Control: a single altered character in one retained section is detected. |
| AC15 | That every instruction in the whole-branch reviewer's contract conferring suppression — whether by filename or by naming the completed-plans directory — names the spec alone, established by enumerating them under a pattern that reaches BOTH spellings. The narrower filename pattern has been measured to miss the directory-spelling instruction entirely while the disjunction reaches all four, so the pattern is part of the criterion and not an implementation choice. Control: a fixture conferring authority through the directory spelling alone is detected. The verification re-run over completed designs is retained, and that retention is itself asserted. |
| AC16 | That the fold removes the log from the tree, and that the post-merge reader still names exactly the two document classes it names today and no third. |
| AC17 | That the change introduces no new unqualified use of the word the learning-log fold already owns, and none of the name the Learning Log archive owns — measured over the change's own added lines, because both words have legitimate pre-existing uses. A baseline inventory of those uses has been taken so the delta is readable. |
| AC18 | That the propagation table's new group is derived by the arms gate, that the gate passes, and that its reported member list is read and the new members confirmed **by name**, not by the count alone. Already established against the member paths this design settles on: the derived set rises from 40 to 43, the three additions are named in the decomposition, every member fires under existing hook arms, every control stays silent, and no new hook arm is owed. |
| AC19 | That every method file this change touches measures below the early-warning threshold after the change. Already established for the file with 123 chars of headroom: it is out of the edit set entirely, because the documented-root rule resolves any path under the existing plan root — proven on one fixture that passes and one control that fires. |
| AC20 | That the full structural suite passes with exactly one verdict per member and no list drift, that the processed shell-file count is read beside the syntax verdict and has moved by the number of new scripts, and that the plugin patch version is bumped. Baseline established green with its counts recorded. |
| AC21 | That no method file this change touches acquires a language, build tool, domain entity or ticket prefix — measured over the change's added lines, because the tree carries pre-existing instances. The delta form has been exercised against an input that must trip it and against one that must not. |
| AC22 | That renaming a shipped test produces neither a rejection nor an amendment route, while a criterion left with no covering check still fails — the discrimination observed as two different outcomes, not one passing run. Established by ENUMERATING every instruction that enforces the concrete-command form, from both of the vocabularies the rule is written in rather than from the one phrase: nine enforcers plus a back-reference, each asserted to demand intent rather than an identifier. Separately, that the falsification duty survives re-pointing with a named receiver and a predicate about a check having been shown able to fire — never merely about a check existing — and that the reviewer-side checklist and the reviewer-side rules were moved together, since one alone makes compliance read as a defect. And that the in-task and post-merge gates carry **different** predicates, the weaker one post-merge, with its reason recorded at the gate itself: the stronger evidence lives in a file that is never committed and is deleted at merge time, so the two gates cannot read one carrier. A design giving both the same predicate specifies a read of a deleted file. |

| AC23 | That no record of superseded material survives in a design at any stage, and that the rule binds both sides of the review. The author's side states that a pre-approval correction is a rewrite and that the document carries no account of what an earlier draft said or argued. **The reviewer's side — the half that was missing, so the half the demonstration is about — states that a revision account is not a thing a verdict may require**, and points a correction's reasoning at the round's own findings table. Shown both ways: a verdict demanding such an account is refused under the new clause, and separately an ordinary finding is unaffected. **This document is the fixture:** it is checked positively, section by section, for describing its current state rather than a past one, and the bounded phrase scan is run over it with that scan's own ability to fire established on a fixture that carries a revision account. |
## Open questions

None blocking. The spec's four open questions are decided under § Approach, with the reasoning and the
measurements behind each.

Two adjacent questions are settled rather than open, and are recorded here so they are not re-raised:

1. **The fold commit's self-review obligation** — settled, no edit owed, `docs/workflow.md` untouched on
   this point. The argument is in § `docs/agents-method.md` is NOT in the edit set: the fold's output is
   machine-gated against the previous commit, which is more than a review spawn on a docs-only commit
   would deliver.
2. **The pre-existing method/profile violations** — tracked as issues **#111** (language and foreign
   source files named in method files) and **#112** (the provenance half: one named entity used as the
   house example in several further places, including the scaffold template). Both are out of scope here
   and the affected lines stay as they are; the Risks bullet records that so a later round does not read
   their survival as an oversight.

