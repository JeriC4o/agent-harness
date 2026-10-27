# Design: Catch a one-sided edit to linked plan statements

**Ticket:** GH-162
**Date:** 2026-10-26
**Spec:** ai-docs/plans/2026-10-26-linked-statement-change-check.spec.md

## Approach

**Three parts, all wired, and none of them stops a plan.** Declared links give a plan pair a committed
record of which statements must move together, and a deterministic check of that record against the current
documents that runs at the end of every pass editing the pair and reports in both directions. The spec
amendment that keeps the approach gets the re-read that three instruction files promise it and nothing
performs, with each genuine finding routed by the side that is wrong. The per-push reconciliation of the
pull-request description is replaced by one read of the ticket and one rewrite of the description at the end
of each iteration. Every new result is a report; the one place where that has to be held deliberately is the
first entry of § Risks.

### Declared links

**The record.** `ai-docs/plans/<spec-base>.links.md`, named by the construction the excuse record is named
by and committed for the same lifecycle reason. Its format is defined on
`docs/templates/progress-format.md` § The record of declared links (committed), a new section beside the
excuse record's, one row per link:

| Cell | Holds |
|---|---|
| `Id` | `L<ordinal>`, unique in the record, so a report can name the row |
| `End A` | the document, `spec` or `design`, then `§` and the heading the quote sits under |
| `Quote A` | that end's words, verbatim — the words carrying the shared fact: the figure, the criterion's requirement, the count |
| `End B`, `Quote B` | the other end, likewise |
| `Grounds` | why the two must move together, in terms a later reader can check |

A literal `|` inside a quote is written `\|`, as in the fix-plan table. The format names no section of a spec
or a design as a literal: every heading in a record is copied from the document its row names. **A record
carrying the table's header and no row declares a pair with no links**, which is how a design that restates
nothing says so; an absent record declares nothing at all, and the check reads it as the could-not-run below.

**Its one writer is the design author.** Whenever the `design` subagent writes or revises the design, it
records every pair AC1 names — a design statement that restates or depends on a spec statement, such as a
figure, a criterion it honours or a count, and any two statements of one document that must move together —
so the link is declared at the moment the restatement is written, by the party writing it. It writes the
record on every such write, one with no row when the pair has no link, and stages it by name the first time
it writes it, as the excuse grant's own output asks of the excuse record. The spec writer never writes it,
and neither does the orchestrator. The duty is a new bullet in `agents/design.md` § Rules pointing at the
contract page `docs/declared-links.md`, which holds everything below that a party acts on: what a link is,
the empty record and the absent one, the states, when the check runs, where a report leads and how a row is
cleared.

**The check.** `scripts/check-plan-links.sh`, called with the spec and the design as its two arguments and
loading its payload `scripts/check-plan-links.py`, reads five things and nothing else: the record; the spec;
the design; the git work tree the spec sits in, for the project root and for whether the record is in the
index; and, through the convergence check's holding sibling, the kept-section list that sibling borrows from
`scripts/check-redline.sh`, which decides whether the spec is folded. Each quote and each document is
normalised the same way — whitespace folded to one space, `\|` read as `|`,
every redline marker removed and then every asterisk — so a re-wrap, a change of emphasis or a marker
appended to an item never moves a link. Each document is
split into sections at its heading lines, outside fenced blocks and through blockquote markers, and each quote
is counted in every section of its own end's document:

| Quotes | State |
|---|---|
| both found exactly once | silent |
| exactly one found nowhere | `moved` — the missing end is the end that changed, the found end the one not re-confirmed |
| both found nowhere | `re-confirm` |
| either found more than once | `ambiguous`, which takes precedence, because the check cannot tell which occurrence the row means |

- **A non-silent row's report names both ends**: each end's document, the heading the row records, and the
  headings its quote was found under, if any. A silent row prints nothing.
- **A folded spec is skipped, never clean.** The check asks the convergence check's holding sibling whether
  the spec is folded, through `folded_spec()` [folded-spec], a new function of
  `scripts/check-plan-convergence-holding.py` that installs only the names the folded-spec rule reads — the
  normaliser, the method-root reader, the could-not-run route and the heading, fence and quote-mark patterns
  — and returns the rule's answer, or nothing when the kept-section list could not be borrowed, which the
  check reports as a could-not-run. The borrowing is done by `retained_sections()` [retained-sections] in
  `scripts/check-plan-convergence-holding.py`, which reads that list out of `scripts/check-redline.sh`. The
  rule — the spec's headings at the kept depth are exactly the kept set — is the one `is_folded()`
  [is-folded] in `scripts/check-plan-convergence-holding.py` already applies for the completeness class, so
  it is stated once. On a folded spec every link with a spec end is reported skipped and not examined, and
  every link with both ends in the design is still examined and printed under its state. The run takes the
  findings exit when one of those examined links is non-silent, and otherwise the could-not-run exit with the
  verdict word `skipped`, with no record at all included; an unstaged or malformed record is the
  could-not-run the bullets below name, as on any spec. The holding sibling's header comment, which says
  every helper there is called only by a class there, gains `folded_spec()` as "the one helper reached from
  outside a class here".
- **An absent record is a could-not-run, never a clean run.** For a spec that is not folded, a missing
  `<spec-base>.links.md` takes the could-not-run exit, and the verdict names the record it looked for. Every
  site that runs the check runs it once a design exists, and the design author writes the record with every
  design, so an absent record there means a write declared nothing rather than that nothing needed declaring
  — the case `docs/gate-outcomes.md` § The three outcomes this page defines names as a record a gate compares
  against that is not there. It blocks nothing, because every site reads the check as a report. A pair with
  no links is declared by a present record with no row, which reads `clean` with a link count of zero.
- **The record follows the excuse record's staging rule.** Present but not in the index is a could-not-run
  naming the record: a record other clones cannot see makes this run's report differ from every other
  clone's, and Step 12's move carries only what the index holds. A record with no table header, a row with an
  empty cell, the wrong number of cells, an end naming a document other than the spec or the design, or a
  quote that normalises to nothing is a could-not-run naming the record or the row.
- **Outcomes.** Exit `0` when the spec is not folded, the record is present and staged, and every link is
  silent, a record with no row included; `1` when at least one examined link is `moved`, `re-confirm` or
  `ambiguous` — on a folded spec, a link with both ends in the design; `2` when the check could not run — an
  absent, unstaged or malformed record among the causes — or the spec is folded and no examined link is
  non-silent, the verdict word then `skipped`. The verdict line names the record, or the record it found
  missing, and counts links per state, skipped included.
- **It is a path-argument check**, so it joins `EXEMPT_CHECKS` [exempt-checks] in `scripts/run-checks.sh`,
  for the reason the convergence check sits there: a runner member is invoked with no arguments, and this
  check needs two. The comment above that list, which speaks of two plan-document gates, names three. For the
  same reason the check is never written in the `bash scripts/<name>.sh` spelling inside the structural-checks
  span of `AGENTS.md`, which the runner's gate inventory parses. The payload's name goes where the profile
  names the payload siblings: `ai-docs/context.md` § Language profile, and every row of that page that lists
  or counts them. The language-profile sentence of `AGENTS.md` names no sibling and only counts them, outside
  that span, so its count moves by one.
- **It preflights what it loads**, as `scripts/check-plan-convergence.sh` does. Two roots are resolved the
  same way — the method root beside the entry point, the project root from the spec's work tree. The entry
  point takes the could-not-run exit, naming the path, when `scripts/check-plan-links.py` or the holding
  sibling is missing or unreadable, before the interpreter starts, and the payload loads the holding sibling
  under a guard that turns any load failure into that exit, as `load_sibling()` [load-sibling] in
  `scripts/check-plan-convergence.py` does.
  An interpreter stopped by an uncaught error exits `1`, this check's findings code, so without the preflight
  a run that could not start would read as a result. The interpreter runs with `-B`, for the reason that
  wrapper states beside its own: without it the first run writes a bytecode cache into the tree it reads,
  which nothing tracks and nothing ignores.

**When it runs** — at the end of every pass that edits the pair after the design is first written and before
the closing fold:

| Pass | Site that runs it |
|---|---|
| Every write of the design author: Step 6's first write, each revision a review round sends back, each design amendment, each fold-in of design-review notes, and each direct correction an amendment that keeps the approach makes | `agents/design.md` § Rules, beside the author's convergence exit check — a second call, read as a report and never part of the refusal |
| Every marking pass, the one inside an amendment that keeps the approach included | the exit-check paragraph of `docs/redline-marking.md`, after the pairing check, and outside the clean-0 refusal that paragraph sets |
| Every spec amendment, once the spec writer has applied it, in whichever workflow entered the recipe | `skills/task/reference.md` § Spec Amendment recipe, step 4 — the orchestrator's own call, whenever a design exists |

The closing fold is the one such pass it does not cover: `agents/design.md` § The redline fold carries its own
gates, and the clause added to `agents/design.md` § Rules names the fold as the pass it skips. A design
author's write after the fold — a direct correction on a plan whose fold already ran, under § The amendment
that keeps the approach — still ends with it, and on a folded spec it reports every spec-end link skipped.
Step 7 does not run it, because Step 7 edits nothing and the design author's hand-back already carries the
report of the write it reviews.

**Where a report leads.** The check never edits either document. What follows depends on the state and, for
a moved link, on where the unchanged end sits:

| State | Unchanged end | What follows |
|---|---|---|
| `moved` | design | The design author brings that end into line in its pass and rewrites the row. After a spec amendment that keeps the approach the design is past its GO, so the route of § The amendment that keeps the approach takes the row instead: its design end is named to the reader first, the orchestrator rules on it from its two quotes with the reader's finding as one input and the reader's silence as none, and a false end is marked and logged where the plan has a correction log, or corrected directly where it has none |
| `moved` | spec | Put to the human as a possible spec amendment. The spec changes only through a spec amendment the human approves, and is never narrowed to match the design |
| `moved`, the changed end's statement deleted with nothing in its place | either | The link no longer exists. Once the unchanged end is dealt with — a design end as the first row says, a spec end by the three cases the first bullet below names: the two AC5 separates, plus a rewording — the design author removes the row, a departure recorded in § Risks |
| `re-confirm` | — | The design author rewrites the row with the current quotes and fresh grounds, or removes it when the link no longer exists, a second departure recorded in § Risks |
| `ambiguous` | — | The design author rewrites the row with quotes found once each |

- **Inside its own pass the design author acts on the report before handing back.** It runs the check at the
  end, acts, and runs it again, so the report it hands back is the one that leaves the pass. A moved row whose
  unchanged end is in the spec, its own edit having changed the design end, falls into one of three cases: the
  two that AC5's last sentences separate, a design error and a genuine conflict, plus a rewording, which is the
  departure from AC5's sentence on an unchanged spec end recorded in § Risks. The edit keeps what the end
  asserts — a rewording — and it rewrites the row with grounds saying so. The edit contradicts the spec
  statement and the design is wrong, and it fixes the design. Or the conflict is genuine, and it leaves the
  row standing and names it in its hand-back as a possible spec amendment. A rewording contradicts nothing,
  so only the last case reaches the human. It never edits the
  spec, and never rewrites a row while its two quotes disagree, except in the amendment's pass in marking
  mode, where the grounds name the redline row that records the correction. Its hand-back carries the check's
  verdict line, each row it rewrote or removed and why, and each row it left non-silent with where it leads.
- **The orchestrator puts a possible spec amendment to the human through the Spec Amendment recipe**, whose
  entry gains this occasion on `skills/task/reference.md` § Spec Amendment recipe and on
  `skills/task/SKILL.md` § Spec Amendment recipe. A declared-link report naming one — in a design author's
  hand-back, or in the orchestrator's own run after an amendment — takes step 3's remedy question as a
  genuine-conflict row does, in plain terms and the design complying first. The design complying returns to the
  design author's pass that raised it, as an ordinary iteration does; the requirement changing continues to
  the spec writer. The entry sentence carries that return target beside the occasion it adds, and step 3,
  whose design-complying answer returns to Step 6, stays as it is: it speaks of a Step 7 genuine-conflict row
  only. Whichever the human picks, the design author's pass that follows rewrites the row. The
  reference page's entry sentence, which names only a Step 7 verdict and a Step 11 finding, also names the
  three callers outside `/task` that already enter the recipe — the fix step of `/bugfix`, the fix loop of
  `/project-review` and a post-push fix round — since the route below serves them too.
- **The orchestrator's own run after an amendment** is carried into the design author's next pass: the Step 6
  re-entry, when the amendment changes the approach or the entry was an iteration; the amendment's own pass of
  § The amendment that keeps the approach, when it keeps the approach. A moved row between two spec
  statements, one of which the amendment changed, has its unchanged end in the spec and takes the remedy
  question above.
- **An ordinary marking pass moves no link**, because the comparison removes markers, so its report travels in
  its hand-back as it stood.

**Clearing is rewriting the row.** The check has no write path, no acknowledge verb and no bulk form, so it
offers no act that clears a row while the documents still differ from it. A non-silent row — moved,
re-confirm or ambiguous — goes silent when the design author rewrites it with its own current quotes and its
own fresh grounds, the act visible in the record's diff, or when the documents return to the text the row
quotes; and a row whose link no longer exists is removed rather than rewritten. Both are departures recorded
in § Risks.

**The record's lifecycle is the excuse record's.** It moves with the plan at Step 12, item 4 of
`skills/task/SKILL.md` naming it beside the excuse record, and comes back on a failing full run, item 1 of
`skills/task/reference.md` § Step 12 — full run, digest compare, failure route naming it too. What keeps the
record in the index is the design author staging it when it first writes it, with every later run of the
check reporting an unstaged one; and `git mv`, which item 4 uses, refuses a path the index does not hold, so
an unstaged record fails the move loudly rather than being skipped. The fold keeps it, as AC6
asks: step 2 and step 5 of `skills/redline-fold/SKILL.md` and `agents/design.md` § The redline fold say so
beside the excuse record, and step 8's late-régime move carries it with the spec, the design and the excuse
record. A later run over the archived pair still examines its design-to-design links against the as-built
design, and reports its spec-end links skipped. The comment in `do_folded` [do-folded] in
`scripts/check-redline.sh`, which says `folded` asserts nothing about the excuse record, names both records;
`pending` looks for the redline log alone (`do_pending` [do-pending] in `scripts/check-redline.sh`) and is
unchanged. The record's own section on the format page carries the same lifecycle.

**The fix-plan gate is told about the record.** The design author writes it mid-round — on a Design
Amendment from Step 11, on the Step 6 re-entry of an approach-changing amendment taken mid-round, and in the
pass of § The amendment that keeps the approach — and no `fix` row can name it, so without an exclusion every
such round would report it as an unplanned file by construction. `skills/task/scripts/check-fix-plan.sh`
gains `IGNORE_GLOB_LINKS`, matching `ai-docs/plans/*.links.md`, in its own variable read by `is_ignored`
[is-ignored] alone and by no arm, for the reason `IGNORE_GLOB_REDLINE` [ignore-glob-redline] carries in its
comment in `skills/task/scripts/check-fix-plan.sh`: the two routing globs are the suffixes the anchor test
keys on, and a separate variable keeps that pair a pair. The record is still named on the verdict's
`excluded-in-round` line, which the orchestrator accounts for against the design author's pass it knows it
ran. Under the Scouted-Fix group sweep the same exclusion lands on three pages: `docs/workflow.md` § Why four
path classes are excluded from the unplanned-file arm gains the record, and its heading names five classes;
the beat-5 paragraph of `docs/scouted-fix-round.md` that counts the classes and links that heading follows
the count and the renamed anchor; and the in-round exclusion list on `docs/templates/progress-format.md`
§ `Fix Plan (Round N)` sections, which names the learnings paths and the two routing suffixes only, gains the
redline log and the record.

**Rejected:**

- a seventh class of the convergence check: its findings would pass through the excuse route, a second way
  to clear a row that AC3 does not admit, and an unreadable record would turn the author's exit check into a
  could-not-run, which stops a plan;
- a check carrying its own copy of the folded-spec rule, which is two definitions of one fact — the event
  this task exists to catch;
- extracting a shared statement reader from the convergence core for this check: the check needs no
  segmentation, only a section split and the folded-spec rule, and the rule is reached in place;
- running it at Step 7 as well, where nothing is edited.

### The amendment that keeps the approach

Three sentences claim that the closing fold authors the design from an amended spec: the second paragraph of
`skills/task/SKILL.md` § Spec Amendment recipe, the "No" branch of step 5 in `skills/task/reference.md`
§ Spec Amendment recipe, and the changed-requirement paragraph of `docs/redline-marking.md`. The fold applies
the log's rows and nothing else, so after such an amendment nothing re-reads the spec against the design. The
"No" branch becomes a route of six acts, in order, stated on the reference page; the task skill's paragraph
carries one sentence of it and the link. `/bugfix` and `/project-review` send a spec amendment through the
same recipe, and a post-push fix round reaches it too, so the route serves every workflow that enters the
recipe; only the form of its fifth act differs between them, by a test read off the files.

1. **The spec writer applies the amendment and names what it amended.** Its hand-back carries each spec
   statement the amendment changed, added or removed — the heading the statement sits under and its words as
   they now stand, a removed one by its heading and the words it had — in the `amended` field of the final
   status block that `agents/spec-writer.md` § Output contract defines, a field required whenever the
   invocation applied an amendment the Spec Amendment recipe passed it. The declared-link check then runs, as
   step 4 now runs it after every amendment.
2. **The amended pair is re-read before work resumes**: the deterministic convergence check as its own call,
   and today's whole-pair reader spawned as Step 7 spawns it, so the reader is never the only check standing.
   The reader's prompt names two sets of design statements to read first, both drawn by the orchestrator:
   - the design end of every link whose spec-end quote falls inside one of the statements the `amended`
     field names, even when the quote is intact — read off the record and that field;
   - every design end of every link the declared-link check reports moved — read off its report.
   They narrow nothing, and the whole pair is still read. `agents/plan-convergence.md` gains the occasion in
   its description, and one clause saying a prompt may name statements to read first, which it reads first
   while reading the whole pair as always.
3. **The orchestrator rules on every finding before anything is written, and routes each by the side that is
   wrong.** The re-read reads the whole pair, so it also carries contradictions the amendment did not cause,
   among them ones an earlier round ruled harmless. Four sets, and one rule for a moved link:
   - **A false design statement goes to the fifth act** — one the amendment made false, whether a reader
     finding against it, a holding finding of the deterministic check the amendment caused, such as a
     criterion it added that no decomposition row delivers, or a moved link ruled false below; or a genuine
     design-side contradiction the re-read finds that predates the amendment.
   - **A wrong spec statement goes to a further spec amendment**, with the human's approval, which re-enters
     this same route.
   - **A wrong artefact outside the pair is fixed as ordinary work** in the step the amendment interrupted — a
     subtask's work in Step 8, a fix row in a review-and-fix round, the fix step of `/bugfix`, the fix loop of
     `/project-review`, a post-push fix commit — with no log row.
   - **A finding judged harmless**, whatever its origin, is recorded and nothing more, except that the fifth
     act rewrites the declared-link row of a harmless moved link, as AC3 requires.
   - **A moved link whose unchanged end is in the design is ruled by the orchestrator from its two quotes**,
     with the reader's finding on that end as one input and the reader's silence as none: a model that raised
     nothing does not clear a deterministic report. The changed spec quote and the unchanged design quote are
     read side by side; a design end the change made false joins the first set, and one that still holds is
     ruled harmless, its row rewritten in the fifth act. A moved link whose unchanged end is in the spec takes
     the second set's question.
4. **Wrong spec statements go first.** Each is put to the human through the recipe's step 3, batched and led
   by a default. An approved one is applied by the spec writer and the route restarts at its first act over
   the new pair, with nothing written before it. A refused one leaves the spec as it stands, and its finding
   is ruled again between the other three sets.
5. **One pass of the design author**, spawned once when the first set holds an item or the declared-link
   check left a non-silent row, and given those inputs only. **Its form follows from whether the amended plan
   has a correction log ahead of its closing fold**, a test read off the files rather than chosen:
   - **The plan has one** while the task that owns it is between its design-review GO and Step 12, where
     `docs/templates/progress-format.md` § The redline log (committed) has the task's first marking pass
     create the log, so an absent file there is a log with no row yet; and at any later point while the plan's
     log is present beside its spec, since the fold is what removes it.
   - **Where it has one, the pass runs in marking mode.** It appends one marker per false item and authors
     that item's log row. Both kinds of false item — one the amendment made false, and a predating design-side
     contradiction — take `S<step>.<ordinal>`, the form `docs/redline-marking.md` gives a divergence with no
     plan row, keyed to the step whose work the item belongs to: Step 8 for any item the decomposition builds,
     whatever step or workflow the amendment interrupted, so the key is a number even after Step 12. The
     ordinal is one more than the highest the log carries under that prefix. The contract's statement "These
     two forms are the whole set" stays true. The mode test in `do_paired` [do-paired] in
     `scripts/check-redline.sh` asks for the mode line whenever the log carries an `S` row, so when the task has
     not yet chosen its correction mode, the once-per-task mode question is put to the user before the pass is
     spawned, as for any divergence. Because the items are rows, the fold corrects them.
   - **Where it has none, the pass corrects each false item directly**, in the same change as the amendment: an
     ordinary revising invocation that reworks only the items named, as `agents/design.md` § Workflow has an
     iteration rework only the sections affected. It writes no marker, creates no log, and ends with the
     design author's own exit checks. No design-review round follows: the workflow's own self-review pass reads
     the correction with the rest of the change before it is committed — Step 10 of `/task`, Step 6.5 of
     `/bugfix`, Step 5 of `/project-review`, and the review step of the post-push round.
   - **In either form it rewrites every non-silent row of the declared-link record**: a row whose design end it
     marked or corrected gets grounds naming that change — the log row's key, or the corrected item — and a
     row whose design end still holds gets fresh grounds saying so.
6. **Every finding judged harmless goes into the progress record's `## Decisions log` with its reason, and
   nowhere else** — the one act beside that record being the fifth act's rewrite of a harmless moved link's
   declared-link row. The record is the working record of the workflow that entered the route, and each carries
   that section: the task's progress file, which a post-push round shares, the bug-fix trace, and the project
   review's progress file. One bullet each, prefixed with the step or round the amendment interrupted. Each of
   those records is gitignored and deleted when its workflow closes, which is why a genuine defect never goes
   there alone: it would be lost. No finding of this route is carried into the pull-request description.

**Which form each workflow takes**, read from the files:

| Workflow entering the recipe | Correction log at that point | Fifth act |
|---|---|---|
| `/task`, before Step 12 | Past the GO the plan always has one: the task's first marking pass creates it, in the active plans directory. An entry before the GO comes from a Step 7 verdict, whose own loop revises the design, as `skills/task/reference.md` § Spec Amendment recipe states for an ITERATE entry, so this route is not reached there | marking |
| `/task`, after Step 12 and before the fold | Item 4 of Step 12 moved the log to `ai-docs/plans/done/` if the task wrote one, and the fold has not removed it; a task that wrote none has no file. `/task` runs no step of its own here except the architectural-rework re-entry, which rebuilds the design and is past a fresh GO when it next reaches the route, so the recipe is reached here through a post-push round, `/bugfix` or `/project-review` | marking when the log is present, direct when it is absent |
| `/task`, after the fold | None: step 5 of `skills/redline-fold/SKILL.md` removes the log, and the fold's empty branch is a plan with no log or a log with no rows, which the fold removes | direct |
| `/bugfix` | None of its own: `agents/self-review.md` § Findings that require Design/Spec Amendment, not a code fix says it has no log and no marking pass. Detoured from `/task` before Step 12 over that task's plan, the task's log applies; over any other plan, that plan's log is present only while its fold is pending | by the amended plan, under the test above |
| `/project-review` | None of its own, as for `/bugfix`. The plans it reads mostly sit in `ai-docs/plans/done/`, where a log survives only while its fold is pending | by the amended plan, as for `/bugfix` |
| post-push fix round | None of its own. It works on the task's plan, whose log sits in `ai-docs/plans/done/` when the task wrote one and the fold has not run | marking when the log is present, direct when it is absent or the fold already ran |

**The two pages that say those callers have no log are brought into line with the table.**
`agents/self-review.md` § Findings that require Design/Spec Amendment, not a code fix says "`/bugfix`,
`/project-review` and a post-push round have no log and no marking pass, so a divergence they find routes as
before". That stays true of a divergence they find, and turns false of the route, which can mark in a
post-push round over a plan whose log is present. The sentence is reworded: they run no marking pass for a
divergence they find, so it routes as before, and the one marking pass they can reach is the route's, over a
plan whose log is present. `docs/workflow.md` § Spec-Amendment group, whose paragraph opening "Only `/task`
has the cheap path" says the marker, the committed log and the closing fold exist in `/task` alone, gains the
same exception and a link to the table above where it stands, on `skills/task/reference.md` § Spec Amendment
recipe, so the table has one home. `skills/bugfix/SKILL.md` and `skills/project-review/SKILL.md` route
through the recipe and resume their own step afterwards; both statements stay true, so neither page changes.

**The changed-requirement paragraph on `docs/redline-marking.md` is reworded** so the requirement itself still
goes only to the spec, while a design item it made false is admitted to the log where the plan has one and
corrected directly by the design author where it has none. The row records the design item, which is a
different fact from the requirement, so nothing is recorded in both places. No pinned base principle is
reworded: the fifth principle on `docs/plan-invariants.md` routes the requirement to the spec, and the log row
records a design item. The direct correction departs from the letter of the fourth, a departure recorded in
§ Risks.

**Every statement of when a marking pass runs, of which divergence has no plan row, and of which one puts the
mode choice gains this occasion**, so no statement of those three kinds stays narrower than the route:

- `agents/design.md` § Redline marking — the sentence saying where `/task` invokes the mode, which names
  implementation and a review-and-fix round only, and the one setting one invocation per review round or
  implementation step that carries divergences;
- `docs/redline-marking.md` — its opening sentence of the same kind; the paragraph setting one invocation per
  review round and one per implementation step; the paragraph opening "With no plan row — a divergence found
  during implementation", which has the pass author the row itself; the paragraph opening "That choice is made
  ONCE PER TASK, on the first divergence", which gains that a mode already in the log's head is never asked
  again, whichever occasion put it; and the exit-check paragraph, which runs the pairing check whenever the
  pass wrote a marker or the log exists, because the amendment's pass may write none and the pairing check is
  a could-not-run on a log that does not exist;
- `docs/templates/progress-format.md` § The redline log (committed) — the `Key` row, whose `S` form reads "for
  one implementation found"; the `Mode` paragraph, which names the first implementation-found divergence as
  the one that puts the choice; the marker bullet, whose `S` form reads "for a divergence implementation
  found"; and the bullet "**One writer.**", worded as "every marking pass — a review round's, an
  implementation step's, or the one inside an amendment that keeps the approach — promotes or authors the rows
  and appends the markers in the same invocation", its second sentence naming each kind's originator, none of
  which writes to the log: the reviewer for a round's row, the step that surfaced the divergence for an
  implementation step's, and the convergence re-read the orchestrator ruled on for an amendment's;
- `docs/workflow.md` § The implementation step takes no route by itself — its sentence "The step stops at the
  FIRST such divergence in the task" gains that a mode an amendment's pass already put is not asked again;
- `docs/workflow.md` § When a spec amendment re-derives the design — its paragraph on the log's fate says that
  a falsified design item, and a predating design-side contradiction the re-read finds, are logged where the
  plan has a log and corrected directly where it has none, rather than left to a fold that authors nothing;
- `docs/workflow.md` § Spec-Amendment group — besides the exception and the link above, its closing
  "Recipe:" sentence, which names only the re-run of Steps 6 → 7, names the re-read route as the other branch;
- `ai-docs/context.md` § Redline log — its identity bullet, which has the mode chosen "at the first divergence
  found while writing the code", names the task's first divergence instead;
- `scripts/check-redline.sh` — the mode-field comment inside `do_paired`, which says an
  implementation-step row exists "only because the step put the once-per-task choice", names the amendment's
  route beside the step as a party that puts it; its conclusion, that such a row with no mode line means the
  choice was never put, stands.

**The sites that already describe an amendment's row stay as they are.** On `docs/redline-marking.md` the
marker template, the bullet dividing the forms by whether a plan row exists, the bullet keying a row to the
step whose work it belongs to, the derivation table's row for a key with no plan row, and the paragraph
naming which checker reaches which form all hold of it: it has no plan row, its key names the step whose work
the item belongs to, and `paired` reaches it. In `scripts/check-redline.sh` the comment above `do_paired` and
the finding text "the log carries an implementation-step row but no mode line" hold too, because the row's
key names Step 8 and the route puts the mode question before such a row exists. And the Step 8 bullet of
`skills/task/SKILL.md` stops at "the **first** divergence in the task", which an amendment's row can be
without the bullet changing. An amendment's row owes the mode line every `S`
row owes, so the log's mode field stays as it is and only its account gains the occasion.

**Rejected:** sending every genuine finding to the fifth act, which marks or rewrites a correct design item
when the wrong side is the spec or an artefact, or leaves the pass nothing to do; a key form of its own for an
item a requirement change made false, which would widen the contract's closed set of two forms and add edit
sites while no checker tells it apart from an `S` row; and keying the amendment's row by the step the amendment
interrupted, which has no number after Step 12 and would move a key whenever a later step noticed the same
item.

### The pull-request description and the ticket

Today a push, not the end of a piece of work, is what triggers a read of the description: the second workflow
axiom in `docs/agents-method.md` § Workflow, `docs/workflow.md` § PR body sync after every push, the
`pr-body-sync` reminder in `hooks/hooks.json`, item 2 of Step 11 on `skills/task/SKILL.md` and the paragraph
opening "After all findings are resolved" on `docs/scouted-fix-round.md` each have the description re-read
after every push and edited when it contradicts the new commits. The shape it is held to asks for what changed,
which the diff already shows: on `docs/workflow.md` § PR title + body shape, the bullet "**PR body:** summary
paragraph(s) ONLY — what changed and why", the bullet "**Size the description to a merge commit message**"
with its six-months test, and the bullet "**The commit message body and the PR description are NOT
interchangeable.**", whose last clause keeps the description "summary-shaped"; and the template on
`skills/task/reference.md` § Step 12 — PR-body template (detail). Nothing reads the ticket at the end. All of
it is replaced by one read at the end of each iteration.

- **Where an iteration ends, and why that reaches every workflow.** The method file's second workflow axiom
  is rewritten to the end-of-iteration rule, and it binds in every workflow: an iteration ends at the first
  pass, before the pull request is opened, and at every correction pass after it — a fix round for failing
  checks or one for reviewer comments — in whichever workflow runs that pass on an open pull request. Two
  workflows carry the act at a step of their own: `/task`, which ends every pass at item 9 of Step 12, and the
  post-push fix round, which ends at the last row of its table on `docs/workflow.md` § Post-push fix commits
  get self-review too, a `/bugfix` reached from that round returning to it. Any other workflow that runs such
  a pass — a standalone `/bugfix` on a branch with an open pull request among them — owes the act under the
  axiom, with no step of its own. **The closing fold is not a correction pass**: it applies corrections the
  review already approved, and changes neither the problem, the reason, nor what to look at in review, so its
  commit to an open pull request in the early window triggers neither act. A push that ends no iteration
  triggers nothing.
- **Every `/task` pass ends at item 9 of Step 12.** On the first pass the item opens the pull request, with a
  description written to the shape below and with the user's approval, and records its number as it does
  today. When a pull request is already open — `/task` re-entered for architectural rework, the one re-entry
  `skills/task/SKILL.md` admits after Step 12 — it rewrites the description in place through `--body-file`,
  shown to the user before it is applied as the first pass's description is. Either way it reads the ticket.
  Item 2 of Step 11 is removed and the two items after it move up, because Step 11 returns to Step 10 and
  sits mid-loop, before the review re-runs, before the commit and before the push; the same act leaves the
  "After all findings are resolved" paragraph on `docs/scouted-fix-round.md`.
- **Who reads.** The orchestrator, as it writes the description, with no reader spawned — the spec's
  default, and the cheapest form that meets the criteria. It is a judgement of meaning: it stops nothing, and
  no check reads the ticket or the description.
- **The ticket** is read for whether it still conveys the task's meaning. When it does not, a correction is
  put to the human in plain terms, under the register `docs/agents-method.md` § Communication sets, and the
  ticket is edited only when the human accepts it. The hard rule "Don't rewrite the ticket body" in
  `agents/spec-writer.md` § Hard rules stays, and gains a clause naming the orchestrator as the party that reads
  the ticket at the end of each iteration and the human as the one who accepts a correction, so the spec
  writer's own rule is not where the read lives.
- **The description** is written at the end of each iteration for the reviewer, from the whole task and not
  from the last push — at the first pass for the pull request being opened, and at each correction pass in
  place of the previous one. It states the problem in the task's own terms, why it is being solved, and what
  to pay attention to in review; where the task changed a process, it carries a diagram of that process in the
  form the project's `AGENTS.md` § VCS names, and when the profile names no form, the process is described in
  prose, a departure recorded in § Risks. It carries no test details, no counts, no acceptance-criterion checklist and no stats;
  no `## Summary` or `## Test plan` header; and no `Co-Authored-By:` trailer unless the user asks. It carries
  the closing trailer the project's profile names, for the issue the pull request resolves, and every in-place
  rewrite keeps it. The shape is stated once, on `docs/workflow.md` § PR title + body shape, whose heading is
  kept because `AGENTS.md` § VCS and the template link its anchor: the three bullets quoted above give way to
  it; the bullet on an identifier being an action loses its allowance for a key wrapped in backticks, so that a
  PR title or description names no ticket but the pull request's own, wrapped in backticks or not, and a ticket
  cited for context is described in prose without its key; and the bullets on the title and on keeping a small
  pull request to the files asked for stay as they are. The template's body bullet defers to that section
  without restating the shape, keeping its rule against naming another ticket key with the exception for a
  key wrapped in backticks removed, and its opening sentence names the in-place rewrite beside the opening of
  a pull request as the act the user approves.
- **The per-push statements go.** The method file's second workflow axiom becomes the end-of-iteration rule,
  a short statement linking the section that states it in full: `docs/workflow.md` § PR body sync after every
  push, renamed "The ticket and the PR description at the end of an iteration" and rewritten. The rows for
  reading and editing a pull request on `docs/workflow.md` § Git + GitHub command map, which name the per-push
  read and the sync action, name the end-of-iteration read and rewrite. The post-push round's last row names
  the end of the iteration instead of a push. The Step 11 row of `skills/task/reference.md` § Gate checklist
  loses its question about a re-read after a push, and its Step 12 row asks about the description's shape and
  the ticket read instead of a summary-only body. The two examples on `docs/considerations-link-reading.md`,
  which name that axiom and an anchor of the per-push section, name the renamed section and its anchor.
- **The reminder hook is removed**, with its bullet on `docs/hook-inventory.md` § The hooks and its row on
  `docs/claude-tools-hierarchy.md` § Project-defined Hooks. It fires on `git push`, and a push cannot tell
  whether it ends an iteration, so any wording it carried would still ask for a read because a push happened.
  Item 9 of Step 12, which names it as firing on push, stops naming it.
- **The diagram's form is a profile fact.** No method page names it; each says the form the project's profile
  names. `AGENTS.md` § VCS gains a row naming Mermaid, which the host renders in a pull-request description,
  and `templates/project/AGENTS.md` § VCS the same row, naming Mermaid as a default the project may change.
  `mermaid` joins the doc-tool names in the vocabulary `WORDS` [purity-words] of
  `scripts/check-method-purity.sh`, so check 5c refuses a method page that names the form. The template carries no copy of any other site above.
- **The trailer's condition stays a profile fact.** `AGENTS.md` § VCS keeps its `Closes #N` carve-out and the
  condition on it — only for the issue the pull request resolves, never for one it merely mentions — and its
  phrase "the one trailer this repo allows despite the summary-only rule" is reworded to name the description,
  since no summary-only rule remains. The method page says the description carries and keeps the profile's
  closing trailer for the issue the pull request resolves; the profile keeps the spelling and its condition.

**Rejected:** rewording the reminder to the end of an iteration, because its trigger is still a push; a
spawned reader for the end-of-iteration read, which would cost a spawn per iteration for a judgement nothing
consumes; and the read at the end of Step 11, which sits mid-loop and never runs on a re-entry whose first
review approves.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | **The declared-link check and its record.** Build the entry point and its payload: the record parse with its escaped-pipe rule, the normalisation, the per-section count, the four states with `ambiguous` taking precedence, the report naming both ends, the absent record's could-not-run and the empty record's clean, the staging rule, the folded-spec skip through `folded_spec()`, the outcomes, the two roots, the preflight and `-B`. Add `folded_spec()` to the holding sibling and name it in that file's header comment as the one helper reached from outside a class here. Mark each entity this document gives an id with that id in a comment on it: `folded_spec()`, `retained_sections()` and `is_folded()` in the holding sibling, and `load_sibling()` in the convergence core. Define the format of `ai-docs/plans/<spec-base>.links.md`, its empty form and its lifecycle on the format page, beside the excuse record's. Put the check on the runner's exemption list, with the comment above it. Enter the payload in the language profile's sibling list and in every row of the context page that lists or counts the siblings, move the count in the profile's language-profile sentence by one, and enter the new files in the Plan-Convergence group | `scripts/check-plan-links.sh` *(new)*, `scripts/check-plan-links.py` *(new)*, `scripts/check-plan-convergence-holding.py`, `scripts/check-plan-convergence.py`, `docs/templates/progress-format.md`, `scripts/run-checks.sh`, `AGENTS.md`, `ai-docs/context.md`, `docs/propagation.md` | AC2, AC3, AC6, AC7 | — |
| 2 | **Declared links wired.** Write the contract page: what a link is, the record's one writer, the empty record and the absent one, the states, when the check runs, where each state leads, and how a row is cleared or removed. In `agents/design.md` § Rules, add the bullet giving the design author the record, written on every write and with no row when the pair has no link, and run the check beside the convergence exit check at the end of every pass but the fold, acting on its report as § Declared links states; in the exit-check paragraph of `docs/redline-marking.md`, run it after the pairing check; on the Spec Amendment recipe, run it at step 4 once the spec writer has applied an amendment, in whichever workflow entered the recipe, and give the recipe's entry sentence the possible spec amendment a report names, with the return target of its design-complying answer, and the three callers outside `/task` that already enter it. Enter the page in the Plan-Convergence group. Protected pages, each edit put to the owner: the exit-check bullet and the new bullet of `agents/design.md` § Rules; on `skills/task/reference.md` the recipe's entry sentence and step 4; on `skills/task/SKILL.md` the recipe's first paragraph | `docs/declared-links.md` *(new)*, `agents/design.md`, `docs/redline-marking.md`, `skills/task/reference.md`, `skills/task/SKILL.md`, `docs/propagation.md` | AC1, AC4, AC5, AC7 | 1 |
| 3 | **The record through the other gates, Step 12 and the fold.** Name the record beside the excuse record in item 4 of Step 12, in item 1 of the failure route on the reference page, in steps 2, 5 and 8 of the fold skill, in the fold section of the design contract, and in the `do_folded` comment of the redline check, marking `do_folded` with its id. Exclude the record from the fix-plan gate's unplanned-file arm through `IGNORE_GLOB_LINKS`, its own variable read by the ignore test alone, with a comment giving the reason, and mark `is_ignored` and `IGNORE_GLOB_REDLINE` with their ids. Under the Scouted-Fix group sweep, add the record to the workflow page's section on the excluded path classes with the count in its heading corrected, carry the renamed anchor and the count to the fix-round page's beat-5 paragraph, and add the redline log and the record to the format page's in-round exclusion list. Protected pages, each edit put to the owner: item 4 of Step 12 on `skills/task/SKILL.md`; item 1 of `skills/task/reference.md` § Step 12 — full run, digest compare, failure route; steps 2, 5 and 8 of `skills/redline-fold/SKILL.md`; the paragraph keeping the excuse record in `agents/design.md` § The redline fold; in `scripts/check-redline.sh`, the comment in `do_folded` on the excuse record and the id mark above that function | `skills/task/SKILL.md`, `skills/task/reference.md`, `skills/redline-fold/SKILL.md`, `agents/design.md`, `scripts/check-redline.sh`, `skills/task/scripts/check-fix-plan.sh`, `docs/workflow.md`, `docs/scouted-fix-round.md`, `docs/templates/progress-format.md` | AC6 | 1 |
| 4 | **The amendment that keeps the approach.** Correct the three sentences claiming the fold authors the design from an amended spec; state the six acts, the test for a correction log and the table of which form each workflow takes on the "No" branch of step 5 on the reference page, and their one sentence in the second paragraph of the task skill's recipe; add the `amended` field to the spec writer's final status block; give the reader its second occasion and its read-first clause; reword the changed-requirement paragraph; give every site § The amendment that keeps the approach lists the occasion — the amendment's `S` row keyed to the step whose work the item belongs to, the mode question put when the log carries none, and the direct correction where the plan has no log — and the "One writer" bullet the wording that section quotes, and the mode-field comment in `do_paired` the party that section names; reword the reviewer contract's sentence on the callers that have no log, and give the workflow page's Spec-Amendment section the exception and a link to the table. Protected pages, each edit put to the owner: on `skills/task/SKILL.md` the recipe's second paragraph; on `skills/task/reference.md` the "No" branch of step 5; the two sentences of `agents/design.md` § Redline marking; on `agents/spec-writer.md` the final status block of its output contract; in `scripts/check-redline.sh` the mode-field comment inside `do_paired` | `skills/task/SKILL.md`, `skills/task/reference.md`, `agents/spec-writer.md`, `docs/redline-marking.md`, `docs/templates/progress-format.md`, `agents/design.md`, `agents/self-review.md`, `docs/workflow.md`, `agents/plan-convergence.md`, `ai-docs/context.md`, `scripts/check-redline.sh` | AC5, AC8 | 2 |
| 5 | **The rule for the pull-request description and the ticket.** Replace the per-push read with the end-of-iteration read at every site § The pull-request description and the ticket lists: the method file's second workflow axiom; on `docs/workflow.md` the per-push section, renamed and rewritten, the post-push round's last row, the command map's two rows and the three bullets of the shape section; item 2 of Step 11, removed, and item 9 of Step 12; the template and the Step 11 and Step 12 rows of the gate checklist; the fix-round paragraph. Remove the reminder hook and its two inventory entries; reword the link-reading page's two examples; give the spec writer's hard rule against rewriting the ticket body its clause; add the diagram-form row to both profiles' VCS sections and reword the carve-out's summary-only phrase; add `mermaid` to the method-purity vocabulary and mark `WORDS` with its id; bump the plugin's patch version. Protected pages, each edit put to the owner: on `skills/task/SKILL.md` item 2 of Step 11 and item 9 of Step 12; on `skills/task/reference.md` the PR-body template and the Step 11 and Step 12 rows of the gate checklist; on `agents/spec-writer.md` the hard rule against rewriting the ticket body | `docs/agents-method.md`, `docs/workflow.md`, `hooks/hooks.json`, `docs/hook-inventory.md`, `docs/claude-tools-hierarchy.md`, `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/scouted-fix-round.md`, `agents/spec-writer.md`, `docs/considerations-link-reading.md`, `AGENTS.md`, `templates/project/AGENTS.md`, `scripts/check-method-purity.sh`, `.claude-plugin/plugin.json` | AC9, AC10, AC11, AC12, AC13, AC14 | 4 |

## Risks

- **Something built here could come to stop a plan.** The declared-link check exits like a gate, and a caller
  could wire it as one by reflex. Mitigation: every site that runs it reads it as a report — the design
  author's refusal stays on the convergence check's holding classes, the marking pass's on the pairing check,
  and the recipe's step 4 stops nothing — and the check sits on the runner's exemption list, so the full check
  run never invokes it. A could-not-run of it, an absent or unstaged record among them, travels in the
  hand-back and blocks nothing.
- **Protected-page prompts.** Every edit to a page on the plan-invariants guard's list (`PROTECTED`
  [protected] in `hooks/lib/plan-invariants-guard.sh`) is put to the owner when made. This task edits six of
  those pages, in these regions and nothing else on them:
  - `agents/design.md` — the exit-check bullet of its rules and a new bullet there for the record (row 2); the
    paragraph of its fold section keeping the excuse record (row 3); the two sentences of its marking section
    on where and how often the mode runs (row 4);
  - `skills/task/SKILL.md` — the first paragraph of its Spec Amendment recipe (row 2) and the second (row 4);
    item 2 of Step 11, removed, with the two items after it moving up (row 5); item 4 of Step 12 (row 3) and
    item 9 (row 5);
  - `skills/task/reference.md` — the entry sentence and step 4 of its Spec Amendment recipe (row 2) and the
    "No" branch of step 5 (row 4); item 1 of its Step 12 failure route (row 3); the opening sentence and body
    bullet of its PR-body template (row 5); the Step 11 and Step 12 rows of its gate checklist (row 5);
  - `skills/redline-fold/SKILL.md` — steps 2, 5 and 8 (row 3);
  - `agents/spec-writer.md` — the final status block of its output contract, which gains the `amended` field
    (row 4); the hard rule "Don't rewrite the ticket body" (row 5);
  - `scripts/check-redline.sh` — the comment in `do_folded` on the excuse record, and the id mark above that
    function (row 3); the mode-field comment inside `do_paired` (row 4).

  `agents/design-review.md` is not edited. Mitigation: each region is edited in one call per row that names
  it, so the owner meets one prompt per region and row and can read the region's purpose off the row.
- **Instruction size.** Against the 35,000-character early warning the method hands down, the loaded-whole
  pages this task edits stand, measured with `wc -m` on 2026-10-26, at `docs/agents-method.md` 34,065,
  `ai-docs/context.md` 32,720, `skills/task/SKILL.md` 32,499, `AGENTS.md` 23,213, `agents/spec-writer.md`
  22,057, `agents/design.md` 21,660, `skills/redline-fold/SKILL.md` 14,922, `agents/plan-convergence.md`
  8,807, `templates/project/AGENTS.md` 2,885 and `agents/self-review.md` 32,738. `docs/agents-method.md` is the
  loaded-whole page this task edits
  nearest the warning, and row 5 is the only row that edits it: it replaces the second workflow axiom — a
  block measuring 1,098 characters from its first line to the next axiom, by a python3 character count on
  2026-10-26 — with a short statement linking `docs/workflow.md`, so the page shrinks. Mitigation for the
  rest: the task skill gains clauses and pointers only, and loses item 2 of Step 11 and the hook's mention in
  item 9, while the route's detail lands on its reference page and the link contract on
  `docs/declared-links.md`, both reached by link; `ai-docs/context.md` gains one payload name in each row that
  lists the siblings and a reworded clause on when the mode is chosen; the design contract gains two clauses
  that point at the contract page; the spec writer's contract gains one status field and one clause on its
  hard rule against rewriting the ticket body; the reviewer contract
  rewords one sentence. The size check, check 5d, reddens at that warning.
- **Three ways a row stops reporting without being rewritten — departures from AC3 that other criteria
  force.** AC3 says a non-silent row is "cleared only by rewriting that row with the current quotes and fresh
  grounds; nothing clears several rows in one act".
  - **A revert.** The check's result depends on no history — only on the current documents, the record and
    whether the record is staged (AC2). The index read is how the check establishes that it reads the
    committed record AC1 names, and the kept-section list it borrows is its own method configuration. So when
    the documents return to the text a row quotes, every row an edit had broken goes silent at once and no row
    is rewritten. AC2 forces it.
  - **A `re-confirm` row whose link no longer exists is removed.** AC1 makes a row two verbatim quotes of a
    pair that must move together, and a pair one of whose statements is gone has no current quote to record,
    so the only row AC1 admits for it is none.
  - **A `moved` row whose changed end was deleted outright, with nothing in its place, is removed** once its
    unchanged end is dealt with, for the same reason: there is no end left to bring into line, and AC1 admits
    no row quoting a statement that does not exist.

  Mitigation: a reverted pair says again what each row quotes, so the silence is true; each removal is visible
  in the record's diff, and the hand-back names each removed row and why; and what the check never offers is
  an act that clears a row while the documents still differ from it.
- **A re-confirmation against an unchanged spec end departs from AC5.** AC5 says "An unchanged end in the spec
  is put to the human as a possible spec amendment", and the first part of the spec's scope says the same.
  The design author instead re-confirms a moved row whose design end it reworded, when the rewording keeps what
  the spec end states, and puts only a genuine conflict to the human. AC3 requires that reading together with
  AC5's own split: AC3 clears a non-silent row by its rewrite with current quotes and fresh grounds, and AC5
  separates a design error, fixed in the design, from a genuine conflict, the one case that changes the spec
  through an amendment the human approves; a rewording is neither, so it never reaches the human. Nothing
  mechanical can tell a rewording from a contradiction or make fresh grounds honest. Mitigation: the hand-back
  lists every row the author rewrote and why, the record's diff shows each rewrite, and the orchestrator can
  put any re-confirmation it doubts to the human through the same remedy question.
- **A process with no diagram when the profile names no form departs from AC12.** AC12 says "where the task
  changed a process, it carries a diagram of that process". AC14 forces the exception: "No method page names
  the diagram's form; each says the diagram takes the form the project's profile names", so when the profile
  names none there is no form a method page may prescribe, and the description describes the process in prose.
  Mitigation: the template a project is scaffolded from names a default form (AC14), so a profile names none
  only where a project removed it.
- **The direct correction departs from the letter of the fourth base principle.** That principle, on
  `docs/plan-invariants.md`, makes a post-GO divergence "a marker plus a log row, never a rewrite", and the
  route's fifth act rewrites a design item where the plan has no correction log. AC8 requires it, and the spec's
  key-decisions row on the closing fold says which workflows keep no log. Mitigation: it happens only where no
  log exists to carry the correction, in workflows whose own divergences already reach the design author by the
  amendment route with no log; it reworks only the items the orchestrator ruled false; and the workflow's own
  self-review pass reads it before it is committed. Two freeze sentences say the same of the marking mode and
  stay as they are: the freeze paragraph of `docs/redline-marking.md`, "the only post-GO rewrite there is …
  every correction is a marker plus a row", and the opening sentence of `agents/design.md` § Redline marking,
  "the only one in which this subagent writes to an AGREED design". Both speak of `/task`, where the marker,
  the committed log and the closing fold live — the scoping the paragraph opening "Only `/task` has the cheap
  path" on `docs/workflow.md` § Spec-Amendment group states, kept with the one exception § The amendment that
  keeps the approach gives it — and `/task` itself never takes the direct correction: before Step 12 its plan
  has a log, and after it the route is reached through a post-push round, `/bugfix` or `/project-review`.
  Those three callers already rewrite a post-GO design through today's Design Amendment route under the same
  two sentences.
- **A link nobody declared catches nothing.** The check sees declared pairs only. Mitigation: AC1 makes the
  record a duty of every write, at the moment the restatement is written; the whole-pair reader still reads
  every pair at Step 7 and after an amendment that keeps the approach; inferring links from a diff stays out of
  scope on the grounds the spec records.
- **A plan begun before this lands has no record**, so every run of the check over it is a could-not-run
  naming the missing record until the design author's next write creates one. Mitigation: a could-not-run here
  blocks nothing, and the hand-back that carries it names the record; an archived plan with a folded spec is
  reported skipped instead.
- **Two definitions of what a heading line is.** The link payload splits sections with its own heading, fence
  and quote-mark patterns beside the convergence core's, and installs its own in `folded_spec()`. The rule
  that decides a folded spec is stated once; the patterns it reads are not. Mitigation: the payload's patterns
  carry the core's names and a comment naming the core as their source, so a search for either finds both; and
  the kept sections are level-two headings, which both read alike.
- **A new method page read as a carrier of a required element.** A page or a script naming a plan section
  beside a presence word reads to check 5b as enforcing a required element on a surface the edit-time refusal
  does not protect. Mitigation: `docs/declared-links.md`, the record's format section and the payload name no
  section of a spec or a design as a literal — the payload borrows the kept list as the holding sibling does —
  and check 5b is selected by any instruction file on the surfaces it examines.
- **The amendment's marking pass with no log file yet.** Before a task's first marking pass the log does not
  exist, and a marking-mode pass that only rewrites link rows writes no marker and so creates none, while the
  pairing check is a could-not-run on a log that does not exist. Mitigation: the exit-check paragraph runs the
  pairing check whenever the pass wrote a marker or the log exists.
- **A row left non-silent is reported again at every later run.** Mitigation: every state names who acts, and
  whichever remedy the human picks for a possible spec amendment, the design author's pass that follows
  rewrites the row.
- **Sync groups beyond the three the spec names.** The edited pages also belong to the Task/Design,
  Scouted-Fix, Check-Scope, Human-register, Interview, Review and Plan-Invariants groups on
  `docs/propagation.md`, and
  removing a hook is a hook-contract change, which that page sends to `docs/claude-tools-hierarchy.md`.
  Mitigation: each row closes with the propagation sweep for every group its edited files belong to, and a
  sibling the sweep finds is edited in that row. Every new member falls under an arm the propagation reminder
  already carries — `docs/*.md`, `scripts/*.sh`, `scripts/*.py` — so the arms check 5a derives need no new
  one.
- **`README.md` states a hook count.** It already differs from the hook entries the manifest holds, measured
  on 2026-10-26 by listing them with `jq`, and tree-derivable counts in shipped files are GH-79's and GH-127's,
  outside this task. Removing the reminder hook does not re-derive it.

## Use cases

- `scripts/check-plan-links.sh` — run by the design author at the end of every pass of `agents/design.md`
  § Workflow, a direct correction in any workflow included, to act on its own record before handing back; by
  every marking pass at its end, the amendment's pass included; by the orchestrator once the spec writer has
  applied an amendment, in whichever workflow entered the recipe, to route what the amendment moved; on demand
  by anyone over a plan, and over an archived pair, where it reports the spec-end links skipped and never
  clean.
- `scripts/check-plan-links.py` — invoked by its entry point only: parses the record, normalises and counts
  each quote section by section, assigns each link its state, asks `folded_spec()` whether the spec is folded
  and, when it is, skips the spec-end links, still examines the design-to-design ones, and exits with
  findings when one of those is non-silent and as `skipped` otherwise, reads a record with no row as a
  declared pair with no links,
  refuses an absent, unstaged or malformed record as a could-not-run naming it, and prints the report and the
  verdict line.
- `folded_spec()` — called by the link payload to recognise a folded spec by the rule the completeness class
  applies, with the names that rule reads supplied by the caller.
- `ai-docs/plans/<spec-base>.links.md` — written on every write of the design author, with no row when the
  pair has no link, staged, and rewritten row by row, the amendment's pass included; read by the declared-link
  check on every run; read by the orchestrator, beside the `amended` field, to name the design ends the reader
  reads first; counted out of a fix round's measured diff and named on its `excluded-in-round` line; moved
  with the plan at Step 12 and back on a failing full run; kept by the fold.
- `docs/declared-links.md` — read by the design author before it writes or revises the record, reached from
  `agents/design.md` § Rules; read by the orchestrator when a report names a possible spec amendment or an
  amendment's own run reports a moved link, reached from the Spec Amendment recipe; read by the amendment's
  pass, in either form, when it rewrites rows.
- `amended` — written by the spec writer into its final status block whenever an invocation applied an
  amendment, naming each statement changed, added or removed; read by the orchestrator after an amendment that
  keeps the approach, to name to the whole-pair reader the design end of every link whose spec-end quote falls
  inside one of those statements.
- `IGNORE_GLOB_LINKS` — read by the fix-plan gate's ignore test alone, so a fix round's `applied` verdict
  counts the record out of the measured diff and names it on the `excluded-in-round` line instead of reporting
  it as an unplanned file; read by no routing arm.
