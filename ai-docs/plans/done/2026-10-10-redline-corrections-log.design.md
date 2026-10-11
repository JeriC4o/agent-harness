# Design: Redline log — freeze the plan, mark divergences in place, fold once after approval

**Ticket:** GH-108
**Date:** 2026-10-10
**Spec:** ai-docs/plans/2026-10-10-redline-corrections-log.spec.md

**Scope — this is GH-108's as-built design.** It states the mechanism this change shipped. Its
`file:line` anchors, its signatures and its measurements are claims about that state, and a file this
change touched is described here only as far as this change describes it; the file itself is the authority
on what it says. Where an anchor points into a file this repository edits often, it is given as a section
reference, which locates the clause without being falsified by the next edit above it.

## Approach

### What this change is, in one paragraph

A review finding whose subject is a sentence in the task's spec or design used to stop the round and
re-run the planning chain before any code fix could land. This change splits that on one question —
*does the divergence break the agreed approach?* — and gives the non-breaking answer a cheap path: one
visible marker on the diverged item, one row in a committed log, and the code fix proceeds in the same
round. A divergence found while the code is being written takes no route by itself at all: the step stops
at the **first** one in the task, puts a correction mode to the user once, and that single answer governs
every later divergence. After the PR is approved, `/redline-fold` authors the as-built design, collapses
the spec to its record of deliberate absence, and removes the log.

### The freeze point, and which régime a round is in

The freeze is an **event**, and it is the **design-review GO verdict**. Everything here keys off that
instant:

| Régime | A correction is | Why |
|---|---|---|
| Before GO — Steps 6–7 | a **rewrite** of the design | The document is still being authored. The review loop reworks sections by its own contract (`agents/design.md` § Workflow → Iteration), and nothing has shipped for a base to diverge from |
| After GO — Steps 8–12 and any fix round | a **marker plus a log row** | There is now an agreed base, and the code is being measured against it |

Three consequences the rest of the design rests on:

- **The marking pass is post-GO by construction.** It runs in the implementation step or in the
  Step 10 / Step 11 review-and-fix cycle, neither of which can be reached without a GO verdict. So no
  mechanism here asks which régime it is in — the position in the workflow answers it.
- **One window sits between the two régimes, and it is the only post-GO rewrite there is.** A GO verdict
  carrying notes is closed by folding them into the design, which both `/task` Step 8 and
  `agents/self-review.md:52` require to happen BEFORE the implementation diff starts. Nothing has been
  measured against the base yet, so there is nothing to mark; once the diff starts the window is shut.
  `agents/design.md` § Redline marking states this, because an implementer who reads "after GO, mark"
  alone would mark a note that is still the author's to fold in.
- **A breaking rebuild re-arms the event.** The rebuilt design passes through design-review again and
  that GO is the new freeze point; the log resets to empty because its rows described a base that no
  longer exists. `skills/task/reference.md:80` carries the hand-off and the reset.

The pre-GO régime needed no new instruction beyond a clause making it explicit:
`agents/design.md` § Rules states that a pre-approval correction is a rewrite and that the document
carries no revision account at any stage. § Workflow → Iteration already implied it; the clause is what a
reviewer can be held to.

### Who writes what: the reviewer originates the row, the marking pass promotes it

The reviewer never writes the committed file. `agents/self-review.md:159` disposes the finding
`redline: <type> — <what shipped instead>` in the round's fix plan — which lives in the gitignored
progress file — and a separate `design`-subagent pass promotes it into the log. Three grounds, the first
decisive:

1. **`agents/self-review.md` is shared by four callers and three are out of scope.** The spec requires
   `/bugfix`, `/project-review` and post-push fix rounds to keep today's behaviour. A reviewer taught to
   write a committed log would write one in all four. A `/task`-only promotion step leaves the other three
   untouched *by construction* rather than by a carve-out sentence that can be misread — and
   `agents/self-review.md:159` states the carve-out anyway, so a reader of that one sentence is not left
   to infer it.
2. **One writer of the committed file.** `docs/agents-method.md:124` already makes `design` the only party
   permitted to write `*.design.md`. Making it the only writer of the log too means the marker and its row
   are written in the same invocation, so they cannot diverge — which is what a marked item's "already
   settled" status rests on.
3. **One cut point for each gate.** At plan time the commitment is in the plan; at apply time the marker
   and the row are both in the tree. Both halves are mechanically checkable.

### The row is derived from the fix-plan row, not recorded independently

`docs/templates/progress-format.md` already defines a per-finding `Arm A — artefact sentence at stake`
column holding a quoted sentence plus its backticked `file:line`, and the fix-plan gate already resolves
that anchor and checks the quoted sentence sits within three lines of it on whitespace-normalised text.
That is the redline row's middle field, already validated against the file. An independent record would
need its own anchor-and-quote validator — a second copy of logic the repository has already paid for once.

So the row is assembled from cells that already exist:

| Log row field | Comes from |
|---|---|
| `Key` | `R<round>.<finding #>` — the round from the plan section's heading, the number from the row's `#` cell |
| `Key`, with no plan row | `S<step>.<ordinal>` — the step from the workflow, the ordinal from the order of discovery |
| `Type` | the `redline:` disposition's type token |
| `Artefact sentence diverged from` | the plan row's `Arm A` cell, **verbatim** |
| `What shipped instead` | the disposition's reason text, which **opens** the cell verbatim |

The last field shipped as a **floor rather than a cap** (`agents/design.md` § Redline marking): the pass
may extend the reason with shipped facts a one-line disposition could not hold, such as a second site
corrected in the same pass or a measurement taken afterwards. A cap would have forced the pass to either
drop those facts or re-author the field, and re-authoring is the duplication this derivation exists to
avoid.

**With no plan row the pass authors the row itself**, from the same two facts — the design sentence quoted
verbatim and what shipped. The derivation exists so one divergence is not recorded twice; where no plan row
was ever written there is no second record to drift from.

**A pass that touches an existing row re-derives every `file:line` and every measurement in it**, not only
the fields it came to change. A row cites lines and measures sizes that later rounds are free to edit, and
this is the one record in the family that is committed, so a stale figure ships.

The vehicle is a **sixth disposition** in the fix plan's closed vocabulary:

```
redline: <type> — <what shipped instead>        <type> ∈ added | modified | removed
```

This reuses machinery that was already there, which is why it was chosen over a new column:

- The two existing reason-carrying tokens (`object:`, `resolved:`) already refuse an empty reason via a
  `?*` pattern. Three literal patterns at `skills/task/scripts/check-fix-plan.sh:629` give the closed type
  vocabulary enforced by the pattern itself, with the empty-payload refusal for free.
- **The table's cell count does not change.** The parser refuses a row whose cell count is wrong rather
  than misreading it, so a new column would touch every shipped example, the scout's brief and the parser.
  A new disposition touches a `case`.
- **The routing leg does not fire on it.** The path half of the design-amendment arm is wrapped in
  `if [ "$disp" = fix ]`, so a `redline:` row may name `ai-docs/plans/*.design.md` as its target without
  routing. Measured both ways on synthetic fixtures: a `redline:` row targeting a design artefact leaves
  that arm at `pass`, while a `fix` row naming the same path returns `decision=ROUTE-DESIGN`.
- **A `redline:` row declares 0 changed lines**, because it briefs the fix agent with nothing to do.
  `agents/fix-apply.md:37` says so in the per-disposition action table, and
  `docs/templates/progress-format.md:152` in the vocabulary.

**A `redline:` row usually sits beside a `fix` row and sometimes stands alone**, and
`agents/fix-scout.md:75` states both shapes. Beside a `fix` row is the common one, and there the gate
requires it. Alone is correct when the shipped tree is already right and only the frozen sentence is
stale: there is no edit to route, so the row declares 0 and no `fix` row accompanies it.

### The marker: one visible, machine-detectable pointer token

The marker is the word `REDLINE` plus the log-row key, bracketed and bolded. Its exact spelling is in
`agents/design.md` § Redline marking and in `docs/templates/progress-format.md` § The redline log
(committed); this document cannot quote it, because the fold's own residue check reads that literal and
would report this sentence as an unstripped marker.

**Two key forms, and they divide on whether the divergence has a PLAN ROW rather than on where it was
noticed.** A finding a round planned supplies both halves of `R<round>.<finding #>`; anything with no plan
row takes `S<step>.<ordinal>`, for want of a findings table to take a finding number from — the workflow
step supplies the first half, the order of discovery the second. These two are the whole set.

Requirements the spelling was chosen against, each load-bearing:

- **Visible, not a comment.** The payoff is that a reviewer reading the design sees which items are
  already settled and skips them. An HTML comment would buy the machine-detectability and discard the
  reason for marking at all.
- **Additive.** It is appended to the marked item and the original wording is untouched. **The ITEM is the
  unit, not the line** — for prose, the end of its paragraph or list item, never mid-sentence and never at
  a wrapped line's end that is not also the item's end, because a hard-wrapped paragraph's diverged
  sentence can end anywhere inside it; for a table row, the end of the cell carrying the item's prose, not
  after the row's closing `|`, which is outside the table, and not in a cell holding dependencies or paths
  where a reader does not meet the item.
- **Survives a table cell.** The token carries no `|` and no newline, so it cannot shift a column. Most
  marked items are decomposition rows, which is the cell shape most likely to break.
- **Keyed to its row, and the key is the entire payload.** Both halves are numbers the two sides already
  carry, so there is no new identifier to keep in step, and there is no field here that could disagree with
  the row it points at.
- **Recognised by SHAPE, so a document that quotes the token is not a marked document.** A key is
  alphanumerics, dots, dashes and underscores; a template carries angle brackets and spaces and is
  therefore not one. Without that filter the pairing check reads a file explaining the spelling as
  carrying an unpaired key — which it did on its first live run, against the contract file that defines
  the token.
- **A row is keyed to the step whose WORK it belongs to**, not necessarily the step that noticed it, and
  the ordinal is per key prefix rather than global. The key exists to pair a marker with a row, so a key
  that moved whenever a later step noticed something would break pairs already written.

**One syntax, not two.** Strikethrough is excluded by the spec, which records the ground: it PRESERVES the
superseded wording, and no design may carry a record of superseded material at any stage. One mechanical
consequence falls out — a second marker syntax would be a second residue pattern for the fold to strip and
for the gate to know about, so excluding it keeps the residue set at three patterns.

**The namespace was clean when the mechanism was named.** A case-insensitive search for `redline` over the
tree returned hits only in this task's own spec and learnings file.

### A row may record an EXPANSION, not only a correction

`agents/design.md` § Redline marking states this, and it is the half that keeps the mechanism usable on
work whose design could not have been complete. A base that was simply SILENT about something is the
normal case there, not a defect — so the row records that the base said nothing and this is what the work
established. That is what `added` already means relative to the frozen base, so there is no fourth type
token to invent.

**An extension marks the nearest item whose SCOPE it falls within** — the section, or the decomposition
row, the new work belongs to. A marker needs an item to point at and a silence offers none; the containing
item is that anchor, and the marker on it says it is incomplete as written while the row says what was
added. **If no item in the design contains the work at all**, it is not an extension but a missing whole,
and it takes the breaking route. That line is what keeps "extension" from becoming a bucket for unplanned
scope.

### The implementation step takes no route by itself, and the mode is chosen once per task

A divergence found while the code is being written has no round number and no finding number, because no
review has run. The shipped step restarts nothing on its own account: it stops at the **first** such
divergence in the task, leads with a recommended correction mode and its grounds in **one line**, and the
user's single word settles it for the whole task. A question re-asked at every divergence is the cost this
mechanism exists to remove. `skills/task/SKILL.md:133` binds the beat and
`docs/workflow.md:381` § The implementation step takes no route by itself carries the reasoning.

| Mode | What it means |
|---|---|
| **R&D** | The design is accepted as carrying blank spots. A correction or an extension goes into the log as it is found, nothing restarts, and the closing fold is where the design becomes true again. The path for work whose design could not have been complete |
| **Hybrid** | The mixed régime: a non-breaking divergence or an extension goes to the log, while a divergence the user judges to break the approach may still take the rebuild route. Its one operative discipline is a **test, not an exhortation** — an extension is admitted only when it is needed to make the shipped thing correct, never because it is adjacent to it. An extension that would widen what the task delivers is a new ticket, not a log row |

**The step leads with a recommendation rather than a bare question**, because the design usually already
shows which process the work is going to be, and a bare question hands the user work the document can
answer. The grounds are signals read off the design and **quoted**, so the user can disagree with the
evidence rather than with a preference: a non-empty open-questions section, a risk phrased as unknown until
implementation, or work that creates a mechanism which does not yet exist point to R&D; decisions carried
as measured, anchors pinned to real output and probes already run point to Hybrid. A recommendation that
needs a paragraph to justify has already failed — the gate exists to cost the user one keystroke.

**The chosen mode is recorded in the LOG's header, not in the progress file**, and the lifecycle is the
whole reason: the progress file is gitignored and deleted at merge, while the log is committed and is what
the fold reads. The mode is also what explains to a later reader why the log holds the number of rows it
holds — a long log under `R&D` is the mechanism working, and the same log under `Hybrid` is a scope
question. `docs/templates/progress-format.md` prescribes the head as four FIELDS rather than as a layout —
`**Tracked in:**`, `**Spec:**`, `**Design:**`, `**Mode:**` — because `Mode` is the one field with a
consumer and a reader greps for its spelling; the arrangement stays the writer's.

**The mode's grounds are gated, and the bound on that gate is written into the script.** The pairing verb
requires the mode block to carry a backticked token holding a line number or a section heading, so grounds
that cite nothing are refused. It reads the whole mode **block** rather than its first line, because the
grounds wrap and the anchors land after the wrap in every real example. The bound, stated at
`scripts/check-redline.sh:160-167`: it catches grounds that cite NOTHING and cannot tell a relevant
citation from an irrelevant one — the reader the gate exists for, the user confirming in one word, is the
one who can. The verb prints the mode as data and never asserts which mode was right.

**A task whose divergences all came from review rounds never reaches the mode gate and owes no mode.** The
refusal is therefore keyed on the presence of an `S` row (`scripts/check-redline.sh:145`) rather than on
rows-without-mode, which would redden a correct log.

### The closing pass is its own skill, and approval is carried rather than measured

`/redline-fold`, at `skills/redline-fold/SKILL.md`. Neither of the two existing surfaces could host it:

- `/task` cannot. `skills/task/SKILL.md:233` routes everything arriving after Step 12 — reviewer comments,
  CI failures — to a post-push fix round, and re-entering the skill for a one-step closing pass loads a
  34,865-char file behind the `skill-gate` confirmation to do a single spawn.
- `/pr-merged` is excluded by the spec: it activates only on a confirmed merge
  (`skills/pr-merged/SKILL.md:4`, reinforced at `:19`).

A new skill is also the right size for the job — a trigger, measurable preconditions, two spawns, two gate
calls, one surfaced commit — and it solved the size problem that otherwise had nowhere to go: the method
files this change touches sit close to the 35,000-char early warning, and a new file starts at zero.
`skills/redline-fold/SKILL.md` shipped at 8,959 chars.

**Approval cannot be measured in this repository, and the skill says so rather than pinning a gate that
could never pass.** A search for `reviewDecision` over `docs`, `agents`, `skills`, `hooks`, `rules`
returns zero hits, positive-controlled on the same command form with `gh pr view`, which returns nine
files. Measured further: a listing of every PR this repository has ever had returns an empty review
decision and an empty review list for **all twenty**. So the field is not merely unread here — it carries
no information at all, because the default branch has no branch protection and approval in this project is
something the user says. Pinning `reviewDecision == APPROVED` would have produced a gate whose failure
mode is empty output, which this project's own design rules forbid.

| Precondition | How it is established |
|---|---|
| not on the default branch | measured — the current-branch read |
| a PR exists for the branch | measured — the PR read exits non-zero with "no pull requests found for branch …" when it does not |
| the window this change required — the PR still open | measured — the PR's state field |
| the PR is approved | **not measurable here.** Carried by the user's invocation, in the shape `skills/pr-merged/SKILL.md:19` already uses for the merge premise. Where that field IS non-empty — a consuming project with branch protection — the skill reads it and refuses on a changes-requested or review-required state |

This is a one-shot read at invocation, **not polling.** Watching the review surface to decide *when* to act
is excluded by design: it can fire while a reviewer is still mid-comment and consume an incomplete set of
human corrections — the exact failure the one-pass-at-the-end shape exists to prevent.

**The skill is not in the `skill-gate` set** (`hooks/lib/skill-gate.sh` gates `task` alone), so a model can
reach it. Its own first action therefore refuses a model-initiated invocation — the approval it rests on is
the user's, and an agent can only believe a PR was approved.

**Two branches are real rather than degenerate, and both are written down.** A log that is absent, or
present with no rows, stops the pass at step 2: the frozen plan already describes what shipped, so there is
nothing to author, and a rewrite that changes nothing still risks dropping a sentence nobody re-read. An
empty log is still removed, because a surviving log is the signal that this pass never ran and leaving one
would raise that signal falsely.

### `docs/agents-method.md` is NOT in the edit set

The spec listed it among the files this change must touch, and it has 123 chars of headroom against the
early warning — unchanged by this work, because it stayed out of the edit set. It did not need to be
touched, and establishing that was the single most consequential result of the investigation.

The reason it looked unavoidable is the reference check's rule that a bare `ai-docs/…` path in a method
file must name a *documented* project-data root, where the root list is mirrored out of
`docs/agents-method.md` § Agent Docs. A new committed plan-tree file appeared to owe a row there. It does
not, for two independent reasons in the matcher itself:

- `scripts/check-references.sh:179` tests each documented root with `case $p in "$r"|"$r"/*)`, and
  `ai-docs/plans` is already a root at `:68`. Any path under it resolves.
- `scripts/check-references.sh:100` skips a path containing `*` as templated, so the glob spelling
  `ai-docs/plans/*.redline.md` is not even examined.

Verified on two tree copies, both legs: a method file naming `ai-docs/plans/x.redline.md` passes, while the
control naming `ai-docs/redline/x.md` fires `major | L4 | … is not a documented project-data path`.

**That settled the log's location** — inside `ai-docs/plans/`, never a new `ai-docs/redline/` root. A new
root would have forced an `agents-method.md` edit against almost no headroom; the plan tree cost nothing.

Two further reasons it stayed out:

- The size AXIOM's "Applies to:" list already covers every `${CLAUDE_PLUGIN_ROOT}/skills/**/*.md`, so the
  new skill needed no entry.
- `docs/agents-method.md:124` already makes `design` / `spec-writer` the only writers of
  `*.design.md` / `*.spec.md`, which is exactly who performs the fold. The AXIOM needed no amendment.

**One adjacent question, adjudicated: the fold's commit owes no `self-review` spawn, and
`docs/workflow.md` stays untouched on that point.** The fold produces a commit on a branch with an open PR,
which `docs/agents-method.md:118` would nominally route to a manual review. The argument is not that the
output falls outside that predicate — reading "user-facing artefact" as excluding a planning document is an
uncited judgement about someone else's wording, and it is the weaker case. The stronger one is that the
output is **machine-gated**: the `folded` verb compares the three retained spec sections byte-for-byte
against the previous commit and asserts the design carries none of the three residue patterns. That is
strictly more than a review spawn on a documentation-only commit would deliver, so the obligation is
over-satisfied rather than argued away.

### The amendment route is mandated at EIGHT sites, and every one is edited

Narrowing the Arm A / Arm B routing table alone is not sufficient, and the failure is not subtle: **the
orchestrator reads a different sentence and routes anyway.** Six further sites mandate the route in their
own words and two more forbade the non-breaking remedy by implication. All eight carry a disposition, so
the check is a roll-call rather than a search. The table below carries those eight plus the one row the
change ADDS, which is not a site that mandated anything:

| Site | Disposition, as shipped |
|---|---|
| `skills/task/SKILL.md:104` | the Design Amendment trigger itself — **narrowed** to "from Step 11, when a self-review finding's divergence BREAKS the agreed approach; from Step 8, only when the user asks for the rebuild" |
| `skills/task/SKILL.md:114` | the mechanical-and-mandatory clause — **narrowed** with "once the route is the amendment", plus a sentence saying what decides the route and that it sits upstream |
| `skills/task/SKILL.md:133` | the gate-checklist row — **substituted** for the surface-and-choose-a-mode beat |
| `skills/task/SKILL.md:175-176` | the Arm A / Arm B routing rows — **narrowed** to the breaking case, each row carrying the qualifier explicitly |
| `skills/task/SKILL.md:177` | **new row** — either artefact, non-breaking: no stop and no re-run, `✅ Fixed (redlined)` |
| `skills/task/reference.md:266-267` | the Step 11 disposition list — **split** into a breaking row and a non-breaking row |
| `skills/task/reference.md:306` | the Step 11 gate-checklist row — **substituted** for "Breaking divergence → Amendment, non-breaking → marker + log row?" |
| `skills/task/reference.md:84` | the FORBIDDEN blockquote — **rewritten to name the alternative**, see below |
| `skills/task/reference.md:292` | the `## FORBIDDEN` list entry — **rewritten the same way**, without the trailing `— FORBIDDEN` |

**`:114` was the decisive one.** It stated that the trigger is mechanical, that "docs-only" is not a
mitigating input, and that the soft verb beneath it governs only the review's *depth* and "never whether
the recipe fires". An orchestrator reading it unchanged would still route the marking pass into the full
chain, while the two routing rows read as narrowed — so a reviewer checking the routing table alone would
see compliance and the mechanism would not work. The shipped sentence keeps the trigger absolute **and
moves the route decision upstream of it**: a non-breaking divergence never reaches the trigger, and a
breaking one reaches it and then nothing mitigates it.

**The two `Deviating …` sentences were edited rather than relied on as they stood.** They could be read as
forbidding only *silence*, on which reading a marked item with a log row is already permitted, since it is
the loudest available record. That reading has force but it is not the only one available, and the
surroundings favoured the other: `:84` is the first line of a two-line blockquote whose sibling `:85`
forbids editing `*.design.md` inline, so the pair guards the recipe's integrity — don't skip it, don't do
it yourself — and in that position "without triggering Design Amendment" reads as naming the omission of
*the recipe*; and `:292` sits in the `## FORBIDDEN` list beside unconditional bans, where the register is
absolute. Keeping them would have meant resolving an ambiguity by assertion, which is the same mistake as
narrowing one site and declaring the set handled. The remedy makes the claim true by construction: name
the alternative in the sentence itself.

**The case qualifier is not optional, and leaving it out would silently drop a backstop.** An unqualified
"either … or recording a redline marker and its log row" is satisfied by a **breaking** divergence that
records a marker, so those two sentences would stop forbidding the one case they must keep forbidding —
and before the rewrite they were absolute and did forbid it. The spec settles it twice: Scope 1 requires
"Breaking → blocker, **routed as today**" and AC2 requires the routes be "narrowed to the breaking case
**only**". A sentence letting a breaking divergence escape by marking is not a narrowing to the breaking
case; it is a widening in the opposite direction. So the qualifier is mandated by the spec directly and
adds no requirement of the design's own. With it, all three cases land where the spec puts them: a
breaking divergence must still route or it is forbidden, a non-breaking one may mark instead, and a
deviation with neither remedy is forbidden either way — the original silence prohibition survives intact.

**Measured on the shipped tree:** `skills/task/reference.md` moved 33,609 → 34,524 chars (+915) and
`skills/task/SKILL.md` 32,101 → 34,865 (+2,764). Both sit below the 35,000-char early warning, and the
rationale that would not fit went to `docs/workflow.md` as § The implementation step takes no route by
itself and § When a spec amendment re-derives the design.

### A changed REQUIREMENT is not a divergence, and the Spec Amendment recipe asks one question

The log records shipped work departing from the frozen design. A change to what was ASKED FOR belongs in
the spec, written by the spec's own owner, and the closing fold then authors the design from the amended
spec. A changed artefact goes to the log, a changed requirement goes to the spec, and nothing is recorded
in both places (`agents/design.md` § Redline marking).

That required the Spec Amendment recipe to be edited, not merely the Design Amendment one. As it stood it
told a spec amendment to re-run Step 6 → Step 7 unconditionally, which contradicts the sentence above — two
shipped method files disagreeing in one PR. **Shipped: the recipe asks one question first — does the
amendment change the AGREED APPROACH?**

- **Yes** — scope, intent or the approach itself moved. Re-enter Step 6 stating that the spec was amended,
  then Step 7 against the new pair, counting against the 3-round cap; the rebuilt design is the new frozen
  base and the log **resets**.
- **No** — a criterion restated, an over-promise withdrawn, a wording clarified. No design re-derivation,
  no design-review round and **no log row either**: a changed requirement is not a divergence, so nothing
  of it is recorded in the log and the log does not reset. The closing fold authors the design from the
  amended spec.

`skills/task/SKILL.md:110` carries the routing sentence; `skills/task/reference.md:97-99` is the operative
step with both branches; `:101`'s orchestrator-role clause closes with "answer step 5's question and take
only the branch it names", and its sibling note names answering by reflex, in either direction, as the
failure. The recipe's step 5 was written as a **substitution** rather than an append — three numbered lines
stay three and the two blockquote notes stay two — so what the shape buys is line-count neutrality, not
bytes.

**Why the question is asked rather than defaulted, and the measurement behind it** —
`docs/workflow.md:442` § When a spec amendment re-derives the design. Both wrong answers cost something and
they are not symmetric: re-deriving a design because a criterion lost an over-promise re-runs the whole
planning chain over a document nothing read in between, which on a large design is the most expensive round
in the workflow; skipping the chain on a genuine approach change is worse in kind rather than in degree,
because it ships an implementation built against a requirement nobody re-planned for and the divergence is
invisible, the document that would have shown it never having been rewritten.

**The cheap branch is the common one because of the spec's own form rule**, and that is measured rather
than asserted. Run against this task's own spec as the branch found it — commit `825300b` — the form check
reports **7 of its 23 criteria spelling an instrument**: `verdict=dirty criteria=23 findings=7`, naming
AC1, AC7, AC8, AC17, AC18, AC19 and AC20, and reproducible by anyone who runs the verb against that commit.
Prose naming an instrument class without a command roughly doubles it, and is given without a figure
because no command reproduces a judgement. By section that spec was **68%** acceptance criteria, scope and
technical constraints, against **23%** for the three sections the closing fold retains and **4%** for the
record of deliberate absence. An amendment to a criterion naming an instrument is an amendment about
mechanism, and mechanism is what the design, not the spec, is for.

**The log's fate follows from the same question and is not a separate decision.** A rebuild replaces the
agreed base, so the log resets. An amendment that leaves the approach intact is not a divergence at all, so
nothing resets and the accumulated rows survive to the fold.

### The fix-plan gate: two new arms in a script that already exists

`skills/task/scripts/check-fix-plan.sh` is the right host and not a new script: it already parses the plan,
already resolves and quote-checks the `Arm A` cell, is already in `scripts/run-checks.sh`'s `EXEMPT_CHECKS`
so no registration churn was owed, and its suite is already named in `AGENTS.md` item 4. The `plan` verb
went from six arms to seven and the `applied` verb from one finding to two.

**Arm A7 `redline-accounting`, on the `plan` verb.** Decision `REFUSE`, reason `arma-unaccounted`. It fires
when a row is dispositioned `fix`, its `Arm A` cell is non-empty and not `none`, and that cell's anchor
names `ai-docs/plans/*.spec.md` or `ai-docs/plans/*.design.md` — **unless the row's finding number is in
the set of findings that carry a `redline:` row.**

**That last exemption is per FINDING, not per disposition, and it is what makes the arm honest rather than
perverse.** The verb reads the set of finding numbers carrying a `redline:` row once before the row loop
(`skills/task/scripts/check-fix-plan.sh:490-491`, rationale at `:482-489`) and A7 skips a `fix` row whose
number is in it (`:574`). A purely per-row arm refuses the honest plan and passes the evasive one: a `fix`
row whose `Arm A` cell truthfully names the at-stake sentence is refused however the round accounts for it,
because a sibling `redline:` row for the same finding does not clear it — while a cell declaring `none`
with no redline row at all was never refused. A finding may hold several rows by design, so the pair — one
`fix` row routing the edit, one `redline:` row recording what the edit leaves untrue — is the shape the
exemption reads. Measured on a scratch copy with the exemption condition removed: the leg asserting that a
`fix` row's truthful cell PASSES when its finding carries an accounting row fails with
`decision=REFUSE reason=arma-unaccounted`. With the exemption in place that leg passes, and the leg
asserting the refusal where no accounting row exists still observes the refusal — so both directions hold
and the arm cannot be satisfied by silence.

The arm fires on `fix` **alone**, and each of the four disposition exclusions is load-bearing:

- `amendment: spec` / `amendment: design` already route the round through A2/A3, which IS the accounting
  for the breaking case.
- `redline: <type> — …` is the accounting itself.
- `object: <reason>` disputes the finding, so no divergence is asserted. The escape hatch this opens has a
  human on it: an objection to a `major` or a `blocker` needs the user's confirmation before it stands.
- `resolved: <reason>` **must** stay exempt. Its documented primary case is a finding closed before the
  round by an approved amendment, which names the artefact the finding cited — so a `resolved:` row
  legitimately carries a plan-artefact sentence that is already TRUE. Firing on it would re-break exactly
  what the `fix` guard on the path half was added to fix, and the round could not be cleared the other way
  either, because `baseline` refuses a second stub.

**Arm A8 `redline-undelivered`, on the `applied` verb.** For every `redline:` row in the round's plan it
asserts the design file carries that row's marker and the log carries a row under the same key. It can only
run after the marking pass, which is why it is on `applied` rather than `plan`: at plan time the commitment
is in the plan, at apply time the marker and the row are both in the tree.

**A8 derives both paths from the progress file's own basename**, not from a new convention and not from an
argument: `<base>.progress.md` gives `<base>.design.md` and `<base>.redline.md`, each looked up through the
same two-location helper `skills/pr-merged/scripts/cleanup-progress.sh:43` already uses — active directory
first, then `done/`. A third spelling of "where the plan artefacts live" is precisely the drift this change
reduces elsewhere. **The key comparison is an equality**, because `R1.1` is a prefix of `R1.10`: a
containment search reports finding 1 as accounted for because finding 10 was.

**The reach of both arms is bounded by a self-declared field, and the bound is written into the script
rather than left implied** (`skills/task/scripts/check-fix-plan.sh:559-567`). Both key on the `Arm A` cell,
which the scout writes. A scout that writes `none` where a sentence really is at stake escapes the
accounting entirely, and no mechanical check can see that — judging whether closing a finding would leave a
sentence untrue is the judgement `Arm A` exists to capture. So "enforced by a checked-in gate" is true of
the *accounting*, not of the *detection*: given a truthful cell the gate makes the accounting unavoidable;
it cannot make the cell truthful. A1's quote verification is what makes a non-`none` cell trustworthy; a
`none` cell is unfalsifiable by construction.

**The log is excluded from the measured diff, by its own variable.** `IGNORE_GLOB_REDLINE` at
`skills/task/scripts/check-fix-plan.sh:118` is read by `is_ignored` at `:398` and by **no arm**, which is
the point rather than an accident: the two existing globs are the suffixes the A7 anchor test keys on, and
`docs/templates/progress-format.md:153` states that correspondence explicitly, so the pair stays a pair. The
log must be excluded, because `is_ignored` short-circuits the unplanned-file arm's MEMBERSHIP test and not
only the measured total, and the planned set is built from `fix` rows alone — so a `redline:` row's target
can never be admitted there. Measured: with the log unexcluded, a round whose only unplanned write was the
log returns `decision=FINDING reason=unplanned-file`, rc 1. The cost is taken deliberately and stated in
the script's own comment at `:114-117`: the log's lines no longer reach `actual_changed_lines`, and the
`excluded-in-round` line NAMES the log instead — so the write stays visible to the orchestrator by name
rather than as an anonymous addend. Nothing fires on that figure; it is a measurement the orchestrator
reads.

`docs/templates/progress-format.md:153` names the marking pass as the second legitimate mid-round writer of
the design artefact, beside an approved amendment, for the same reason each excluded path is named rather
than merely counted: a diff cannot tell the two parties apart, and they have different remedies.

**The gap A7 closes was measured, not inferred.** Four probes against the pre-change gate, on synthetic
fixtures modelled on the suite's own plan-fixture helper:

| Probe | Plan row | Pre-change verdict |
|---|---|---|
| A | `fix` + a non-`none` Arm A cell citing an ordinary document | `decision=PASS`, all six arms pass |
| **B** | `fix` on code + Arm A citing a design artefact — *the non-breaking case* | **`decision=PASS`** — nothing accounted for the sentence |
| C | `redline: modified — …` | `A6 finding-coverage FAIL … is outside the vocabulary` |
| D | `amendment: design` | `decision=ROUTE-DESIGN reason=design-amendment` |
| E | `fix` **targeting** a design artefact | `decision=ROUTE-DESIGN` — the row's target routes the round |

Probe B is the defect the arm closes: the code fix is correct, the design sentence is stale, and the gate
says PASS. It ships as the suite's control leg. Probe D is the half that must keep failing, and probe E is
why the `redline:` disposition must route on neither leg — the `fix` guard on the path half already ensures
that, and probe C confirms the converse before the token existed.

**Suite: 434 passed, 0 failed**, including a dedicated section for the ignore-variable behaviour plus its
control — removing the variable from a scratch copy of the gate fails exactly six of that section's
assertions while the control stays green.

### No revision account in a design, and the reviewer's clause is the half that makes it hold

A design states the working logic and the design decisions at its current revision. It carries no account
of what a superseded draft said or argued, no quoted superseded wording, and no narration of what a round
found. Every such passage is read in full by every later whole-repository review, and none of it describes
the system.

**Both sides of the review needed a clause, and the reviewer's is the operative one.** Neither
`agents/design.md` nor `agents/design-review.md` carried such a rule — confirmed by reading both. An
author-only rule is overridden by the next verdict that asks for the opposite, and a verdict asking for the
opposite is not hypothetical: the rule's absence is what lets a reviewer require a revision account as a
condition of GO.

| File | Clause, as shipped |
|---|---|
| `agents/design.md` § Rules → *A pre-approval correction is a REWRITE* | A pre-approval correction is a **rewrite**; the document carries no revision account at any stage, and a correction's reasoning belongs in the review round's own findings table |
| `agents/design-review.md:78` | **A revision account is not a thing a verdict may require.** Never ask the author to state that a draft was wrong, to record what a round argued, or to narrate a correction instead of making it |
| `agents/design-review.md:36`, checklist | **A revision account found in the design under review is FLAGGED** — a passage narrating what a draft said or argued, quoting superseded wording, or recording that a round was wrong = `major`, at the same severity as any other passage that does not describe the system. The pointer marker is explicitly NOT one: it carries a log-row key and nothing else, and what changed lives outside the document |

**The third clause is an addition beyond what AC23 requires, and it is recorded as a decision rather than
left to look like an accident.** AC23 is satisfied by the first two plus the fold: the author clause forbids
writing an account, the reviewer clause forbids requiring one, and the fold plus the residue check keeps one
out of `ai-docs/plans/done/`. The residual exposure was therefore **in-task only** — and that is exactly
where the reading cost falls, because every subagent spawn during the task reads the design in full. A rule
stated by two files and enforced by neither during the stage where it costs most is the "a check mandated in
prose is not yet a check" shape this repository documents against.

**Deliberately not widened past that.** The reviewer clause stays narrow: it forbids *requiring* an account
and nothing more. Widening it into a general restatement of the author's duty would put the same rule in two
files, which is the drift shape this change spends eight sites removing. One duty, one home; the checklist
adds detection, not a second copy of the prohibition.

**The demonstration is mechanised, and its bound is stated.** `scripts/check-redline.sh revision <file>`
matches a bounded list of the phrases that introduce an account of a past revision
(`scripts/check-redline.sh:301`), over a design subject and over a verdict subject, each with a control. It
catches the named shapes and not every possible paraphrase, and it **fires on a document that merely
QUOTES one of them** — which a document stating the rule necessarily does. So it is a spot-check the fold
runs as its own step and **not** a leg inside `folded`: `REVISION_PHRASES` is read by `do_revision` alone,
while `do_folded` never reaches it. The script's own header comment at `:28-43` carries that distinction,
because a comment promising a leg the code does not have is the quietest kind of false green, and this is
the phrase list's only caller outside its own suite. The clause in the reviewer's brief is what binds
generally; the verb makes the clause demonstrable.

### The fold AUTHORS the design afresh, and writes it section by section

The fold does not edit the frozen design. It **re-authors** it from the shipped state. An in-place edit
leaves every sentence the editor did not touch, and what it did not touch is exactly what nobody re-read —
stale by omission, and invisible to any check that looks only at what changed. A freshly authored document
cannot inherit a stale sentence through a gap.

Same output path: `ai-docs/plans/done/` holds one design per task and `agents/review-findings.md:25`
depends on that, so "afresh" means re-authored in place of the old content, never a second file.

**"Afresh" is not "only what is needed" — everything outside the strip set is re-authored, not dropped.**
The strip set is closed and short: `## Handoff plan`, `## Open questions`, every marker, amendment residue,
and any record of superseded material. The first three are patterns a check can search for; the last two
are not, and are the judgement step. Everything else — the approach, the decomposition, the risks, the
rejected alternatives, the test design — is re-authored against the shipped state, because a reader of the
completed plan needs to know what was built and what was deliberately not chosen. Dropping a section is not
a cheaper fold; it is a different and worse document, and `agents/review-findings.md:38` still reads the
verification intents from the design that survives, so a design that dropped its Test Design would break a
post-merge pass. Stated because "afresh" reads to some as licence to write only the minimum.

**It must nonetheless be written section by section, not in one call.** `agents/design.md` § Patterns
records the hazard directly: a full-file rewrite of a large design is the highest-risk moment for a
transport drop, with two observed attempts dying before the write landed. The fold's input is a document of
exactly that size class, so one full-file write is the shape most likely to lose the whole pass. So:

- the fold composes the document **section by section**, each a short targeted write;
- it **verifies on disk** afterwards — mtime plus a search for an expected new string — because the harness
  does not retry on a socket close;
- it then **asserts positively that every section describes the shipped state**, which is a judgement and
  is named as one;
- and the residue check runs **after** that verification, so a partial write is caught as a residue failure
  rather than passing as a fold.

The two instructions are not in tension: "afresh" constrains *what the content is derived from* — the
shipped state, not the previous text — while "section by section" constrains *how the bytes are delivered*.
An implementer reading only the first reaches for one call, which is why `agents/design.md` § The redline
fold and `skills/redline-fold/SKILL.md` step 3 both state them together.

**The spec is collapsed, not deleted, and its own subagent writes it.** Its surviving payload is its record
of *deliberate absence* — `## Out of scope`, `## Deferred`, `## Key decisions`, byte-identical to their
pre-fold text — because the design has no section that can carry it: a design describes what was built,
never the boundary of what was deliberately not built. That write belongs to the spec's owner, not to the
design subagent and not to the orchestrator.

**The log is removed from the tree.** Nothing downstream reads it — the post-merge reading list names the
spec and the design and no third class — and the commit history preserves the record. A surviving log is
therefore the unambiguous mechanical signal that the fold never ran, which is what lets the merge-time
workflow refuse on one.

### The redline gate script: seven verbs, one script, one suite

`scripts/check-redline.sh`, at the repository root rather than under either skill's `scripts/`, because
both `/redline-fold` and `/pr-merged` need it and `${CLAUDE_SKILL_DIR}` cannot reach across skills.
Precedent for a root-level, argument-taking check that is not a `run-checks` member:
`scripts/check-release.sh` and `scripts/check-candidate.sh`, both already in `EXEMPT_CHECKS`.
`scripts/check-redline.sh` joined them — it had to, because the stray-check member reports any tracked
`check-*.sh` that is neither exempt nor a member.

**Its exemption has its own reason, and that reason is not the fix-plan gate's.** The fix-plan gate cannot
be a documented member because the inventory recognises only the `bash scripts/<name>.sh` spelling inside
`AGENTS.md`'s structural-check span, and a skill-local path cannot take it. This script *could* take that
spelling and still must not: a member is invoked with **no arguments**, and every one of its verbs requires
at least one, so a documented member would report `cannot run` on every run. The two entries are reasoned
separately in `scripts/run-checks.sh:153-164` rather than collapsed, so the second does not read as a copied
exemption.

**Every verb uses this repository's exit convention — `0 clean, 1 findings, 2 cannot run`** — and the
convention is written into the script's header as contract (`scripts/check-redline.sh:17-26`) rather than
left to the reader.

| Verb | 0 (clean) | 1 (findings) | 2 (cannot run) |
|---|---|---|---|
| `pending <plans-dir>` | no unprocessed log in either location | a log is present | the directory is missing or unreadable, or it is not inside a work tree |
| `folded <spec> <design>` | the three retained spec sections byte-identical to their text in the previous commit, the design free of all three residue patterns, the log gone | any of those fails | there is no HEAD commit, or the spec is not in it, so there is no comparand |
| `suppression <file>` | every suppression-conferring instruction names the spec alone | one names a design document, or the completed-plans directory without narrowing to the spec | the file is unreadable |
| `acintent <spec> <design>` | every criterion has an intent line and no intent line carries an identifier | a criterion is uncovered, or a line names one | either document is unreadable, or the spec carries no criteria table |
| `revision <file>` | no revision-account introducer present | one is present | the file is unreadable |
| `paired <design> <log>` | marker set and row set equal, in both directions and for both key forms; the mode block present and citing the design where an implementation-step row exists | a marker with no row, a row with no marker, a missing or out-of-vocabulary mode, or grounds citing nothing | either file is unreadable |
| `specform <spec>` | no criterion spells an instrument | one does, named by id | the spec is unreadable |

**`pending`'s polarity matters more than anywhere else in this change, and the inverted form is named in
the script so nobody reaches for it.** Were `pending` to return 0 for *present*, with the caller refusing on
0 and 2 reserved for nothing, then a missing plans directory, a lost execute bit and every internal error
would all return non-zero — and the caller would read non-zero as "nothing to refuse" and proceed to delete.
The one gate whose entire purpose is to be a backstop would have **silent passage as its failure mode**, and
neither of the obvious legs — it fires on a present log, it does not fire on an absent one — is a cannot-run,
so neither could see it. Hence: the caller refuses on anything that is not a clean 0 and says which of the
two it got, and the suite carries a third leg for the cannot-run lane.

**`pending` checks both locations**, because a branch that never reached the task's close carries its log in
the active directory while one that did carries it beside the completed plan.

**`paired` is what makes the both-ways claim true, and it exists because the in-round half cannot cover
every key form.** A8 reads its keys off a round's fix-plan table and rebuilds them as `R<round>.<finding #>`,
so it covers the review-and-fix form only; a divergence found during implementation never appears in a plan
table, so its `S<step>.<ordinal>` row had no mechanical half at all. This verb reads whatever key the marker
carries, so neither form is special-cased and a third would need no change. It is pinned as the marking
pass's own exit check (`agents/design.md` § Redline marking), which is the only moment both halves are
freshly written and their author is still in context to fix them. **Its count is part of the verdict**: an
empty design and an empty log pair vacuously, and `pairs=0` is the only thing that distinguishes "both
directions checked and agreed" from "there was nothing to check". Run against this task's own pair it
reports `verdict=clean pairs=8 mode=R&D findings=0`.

**`specform` is what makes the spec's form rule a refusal rather than an instruction**, and its predicate
is measured in both directions. Against this task's shipped spec: `verdict=clean criteria=26 findings=0`.
Against the same spec at commit `825300b`: `verdict=dirty criteria=23 findings=7`. Its scan reads each
criterion's **body**, not its id cell — a match anchored at the row start stops at the first column
separator and reports every spec clean, which is a false green hit for real while auditing a spec by hand —
so the row is split on the separator and the body taken from the third field onward. What guards that reach
is the suite's leg planting a token in the LAST criterion's body, and **not** the printed `criteria=` count,
which is incremented per selected row and is independent of the body extraction. **Its bound is the widest
in the script and is stated at `scripts/check-redline.sh:207-216`:** it classifies BACKTICKED tokens by
shape plus two bare phrases, so a criterion naming an instrument class in prose alone passes, and that
reading stays the reviewer's. A clean verdict means no criterion SPELLS an instrument, never that none
implies one. **Its tool list is deliberately not this repository's vocabulary** — the verb ships to
consumers, so a project on any other build tool must have a criterion naming ITS tool refused too. The
subject exemption is part of the rule rather than a loophole: a criterion whose subject IS a named surface —
a command a fold must not be reachable from, a heading the fold retains, a marker's own spelling, a
disposition token — names it without asserting which check ran.

**`suppression`'s predicate is written down, because the criterion requires the check to name its own
pattern.** It enumerates every line matching `done/` **OR** `design\.md`, then asserts a per-line
disposition. The disjunction is the whole point, measured on the brief as this change found it: the narrower
`design\.md` alone reaches `:25` and `:38` and **misses `:115`** — the restatement that confers the same
authority by naming the completed-plans *directory* — while the disjunction reproduces all four
(`:25`, `:36`, `:38`, `:115`). A criterion met by the narrower pattern is the false green this verb exists to
prevent, so the wider pattern is part of the contract rather than an implementation choice.

**Measured in both directions against the real brief**, which is the demonstration the criterion asks for:

| Subject | Verdict |
|---|---|
| `agents/review-findings.md` as the change found it | `dirty enumerated=4 findings=2` — `:25` confers suppression and names a design document; `:115` confers it and names the directory without narrowing to the spec |
| `agents/review-findings.md` as shipped | `clean enumerated=4 findings=0` — `:115` is the one line still taking the suppression disposition, now naming the spec alone; `:25` is a reading instruction that grants nothing |

**It asserts a disposition per line, never a count**, and it prints the enumerated count beside the verdict,
because an enumeration that silently narrowed its own input set is the quietest false green there is. **Its
unit is the LINE**, which is the bound worth stating: every suppression instruction in the live brief is
written on one line, so the line is the instruction — hard-wrap one of them and the half carrying the path
is still enumerated while the suppression wording sits on the other, so that line takes the
not-suppression disposition. The enumerated count does not drop, so a rewrap of that file is a change to
this check's input. `scripts/check-redline.sh:59-65` says so.

**`folded`'s comparand is version control, deliberately.** The three retained spec sections are compared
against the spec as the previous commit holds it, which predates the rewrite and therefore cannot BE the
rewrite. A scratch copy captured by the same pass could not promise that. The comparison is a file diff
rather than a string equality, because command substitution strips trailing newlines from both sides and a
byte claim made that way cannot see the one difference a hand-rewrite is most likely to introduce.

**`folded`'s superseded-material leg is split, because only half of it is mechanical.** A document recording
its own corrections necessarily contains the superseded text inside a quotation, so proving an absence from a
fragment search returns a false positive rather than a weak result. So the assertion that every section
describes the shipped state is a **judgement** in the fold's brief, named as one, with the `revision` verb
as a spot-check beside it — called by the fold as its own step rather than wired into `folded`. Stating
which half is which is the point: a fragment search here is actively misleading, not merely weak.

**Suite: 188 passed, 0 failed.** Per verb, a leg that must come back non-empty and a control that must come
back empty, plus a cannot-run leg — `pending`'s being the one whose absence turns the backstop into silent
passage. `specform` carries one leg per token class in both directions, twenty-two of them: fifteen refused
classes and seven admitted, the admitted set being what keeps the check from degenerating into a ban on
backticks, because a group of alternatives sharing one input cannot ratchet — deleting a whole alternative
must redden that class alone.

### The merge-time refusal

The refusal must run **before** `/pr-merged` does anything, and that is earlier than it first appears: the
log is committed on the branch, so once the checkout of the default branch runs the file is no longer in the
worktree. The guard therefore sits above step 1, beside the existing branch and dirty-tree guards at
`skills/pr-merged/SKILL.md:17` and `:21`. `cleanup-progress.sh` could not host it — it runs at step 3, after
the checkout, and always exits 0 by design.

**It refuses on anything that is not a clean 0 and says which of the two it got.** Reading a non-zero status
as "nothing to refuse" is the one mistake this guard cannot afford.

**The sequencing limit is stated at the guard rather than left to be discovered.** `/pr-merged` runs after
the window this change gave the fold — that fold's commit belongs on the open PR, and by the time a merge
is confirmed that PR is closed. **So within what this change shipped, the refusal CATCHES the omission and
performs no repair of its own:** it names what is owed and stops. A caught error instead of silent damage
is the whole claim being made for it.

### Where the redline log's format is documented

`docs/templates/progress-format.md`, as a new `## The redline log (committed)` section at `:187`. Three
reasons:

1. The criterion asks for "the same register as the existing `Fix Plan (Round N)` section" — colocation is
   the strongest available form of that.
2. The row is derived from the `Fix Plan (Round N)` row documented in the same file, so the derivation is
   visible in one read rather than across two.
3. It had the headroom; it shipped at 26,155 chars against a set in which several files sit within a few
   hundred of the early warning.

Two head amendments came with it, at `:4-5` and `:10`: the file's scope line and its absolute claim that all
these paths are gitignored both needed the committed sibling named. That contrast — the progress file is
gitignored, the log beside it is committed — is the mechanism's load-bearing fact, so stating it at the
file's head is an improvement rather than a tax.

A separate `docs/templates/redline-format.md` was rejected: another file to keep in sync, for content whose
only reader is the party already reading the file beside it.

### The log's path, lifecycle and the `done/` move

`ai-docs/plans/<spec-base>.redline.md`, moving to `ai-docs/plans/done/` with the spec and design at `/task`
Step 12 item 4 (`skills/task/SKILL.md:227`), and removed by the fold.

- **Not gitignored.** A check-ignore read of this task's own log exits non-zero (not ignored);
  positive-controlled on the same command form against a progress-file path, which exits 0 and is matched by
  `.gitignore:22`.
- **Not deleted by `/pr-merged`.** `skills/pr-merged/scripts/cleanup-progress.sh:46` removes
  `ai-docs/plans/<spec-base>.progress.md` and nothing else.
- **Moved at Step 12, deliberately.** The fold runs after approval, by which time Step 12 has already moved
  the spec and design to `done/`. Carrying the log in the same move gives the fold, the refusal and the
  post-merge reader one location instead of two. `pending` still checks both globs — a branch that never
  reached Step 12 can carry a log — which is the same two-location lookup `cleanup-progress.sh:43` performs.
- **Removed by the fold**, which is what makes a surviving log an unambiguous signal that the fold never ran.
- **The post-merge reading list is NOT widened.** `agents/review-findings.md:25` names `*.spec.md` and
  `*.design.md`; both globs are suffix-specific, so a `.redline.md` in `done/` is invisible to it without
  any edit.

### Scope 11 / AC22: the design promises verification INTENT, never an identifier

**The gate that fires the in-task loop survives Scope 1 untouched.** `agents/self-review.md:52` is the
GO-with-notes staleness sentence Scope 1 narrows; `:53` is a *separate bullet* — the AC-verification re-run
— so narrowing `:52` leaves it in force, and `:53` was an edit target in its own right.

**Nine enforcers plus a back-reference, and a token sweep reaches only some of them.** A search for the
`AC<N> verified by` token over `docs`, `agents`, `skills`, `rules`, `hooks` returned six occurrences before
the change and returns **five** after it, `agents/self-review.md` having stopped carrying the token when its
bullet moved to the falsification predicate. **Three further sites enforced the same duty in a different
vocabulary and were invisible to that sweep**, which is the propagation hazard this repository documents in
its exact form: a file that describes a mechanism in its own words carries none of the changed token. One
says "AC-verification **command**"; two say "exit gate" and are found by a search for that phrase instead.
The two most strongly worded enforcers of the duty were among those three, so a sweep-only inventory would
have left it standing exactly where it bites hardest. The set below was therefore built from the RULE's
description across both vocabularies, never from either spelling alone.

| # | Enforcer, as shipped | Disposition |
|---|---|---|
| 1 | `agents/design.md` § Artifact format → the `AC<N> verified by` line of the Test Design template | the template example — rewritten to an intent example |
| 2 | `agents/design.md` § Rules → *Never pin a command as an exit gate*, plus its sub-bullet | the falsify-before-trusting duty — **re-pointed** at the design's own pinned gates |
| 3 | `agents/design.md` § Rules → *AC-verification line is mandatory* | the mandate — rewritten to demand intent, with the check-identifier-versus-subject distinction stated in its first sub-bullet |
| 4 | `agents/self-review.md:53` | rewritten to the falsification predicate, reading the per-criterion record's column |
| 5 | `agents/review-findings.md:38` | **intent-coverage**, deliberately weaker than the in-task gate, with the lifecycle reason written beside it |
| 6 | `agents/design-review.md:32` | the checklist row — rewritten to the intent form, `major` on a line naming an identifier |
| 7 | `agents/design-review.md:40` | the operative Step-4 clause — re-pointed in step with `:87` |
| 8 | `agents/design-review.md:87` | the Rules appendix — re-pointed, not deleted |
| 9 | `skills/task/reference.md:303` | the Step 9 gate-checklist row — rewritten to the intent form, and extended to demand the per-criterion record with its falsification column |
| — | `skills/ai-audit/reference.md:332` | back-reference: "a gate the design pins must be run twice before it is trusted" — follows `:40` |

**`:40` and `:87` move together or not at all.** `:40` sits in the reviewer's operative Step-4 checklist;
`:87` sits in its Rules appendix. Re-pointing only the appendix leaves the workflow and the rules
disagreeing, and `:40`'s own words then return **ITERATE** on a design that complies with the new mandate —
the reviewer would reject compliance. They sit in one file, which carries ample headroom — 13,335 chars
against the early warning — so there was no size reason to split them.

One bullet survives unchanged and should not be swept into this: `agents/self-review.md` says a passing
AC-verification check is necessary but not sufficient for a prose deliverable. That is a claim about
sufficiency, not about commands, and it is true of the falsification predicate too.

**The two gates get DIFFERENT predicates, and the divergence is recorded as deliberate with its reason.**

| Gate | Predicate | Why this one |
|---|---|---|
| `agents/self-review.md:53` — in-task | **falsification**: each criterion's covering check has been shown able to come back NON-EMPTY | It runs while the round's per-criterion record still exists, so it can read the falsification column |
| `agents/review-findings.md:38` — post-merge | **intent-coverage**: each intent line in a completed design is covered by some shipped check | It runs after the record is gone. There is nothing stronger left to read |

**The reason is a lifecycle fact, not a preference, and one predicate is unavailable in each direction.**
The falsification evidence lives in the progress file, which `.gitignore:22` keeps out of every commit and
`skills/pr-merged/scripts/cleanup-progress.sh:46` deletes at `/pr-merged` step 3. So the stronger predicate
cannot go post-merge — it would specify a read of a deleted file — and the weaker one cannot come in-task,
because the in-task gate *can* read the column and settling for less would discard evidence that exists.
That reason is written into `agents/review-findings.md:38` beside the predicate, so a later reader who finds
the two gates differing finds the lifecycle fact there rather than inferring a defect.

**This is a scope decision, not wording.** § Rejected alternatives refuses a committed sidecar for the
concrete check set *on the ground that* nothing consumes it after merge once `:38` checks intent-coverage.
That reason holds only under the split above: had `:38` been given falsification, the sidecar's rejection
would collapse and a committed carrier would come back into scope. The two passages are load-bearing on
each other and they agree.

**Intent-coverage is strictly weaker than falsification, and the gap is this project's own best-documented
defect.** "A check exists that covers this intent" says nothing about whether that check can come back
non-empty. `AGENTS.md` item 4 is the standing proof: three natural spellings of one syntax check all report
success on a file that does not parse, one of them with no output at all. Each would satisfy
intent-coverage; none is a gate. So the in-task predicate is never "is covered":

> **Each criterion's covering check has been shown able to come back NON-EMPTY** — run once as written, and
> once against input engineered to make it fire.

Intent-coverage is nonetheless not vacuous: it still fails a criterion nothing covers. Leaving `:38`
re-running commands is the option that *is* vacuous, since after the change the design carries no commands.

**The falsification duty is re-pointed, not removed, and its new home is a column.**
`docs/templates/progress-format.md:257` § Criterion checks (Round N) defines a four-column per-criterion
record:

| Column | Holds |
|---|---|
| `AC` | the criterion id |
| `Intent` | the design's intent line, copied |
| `Covering check` | the concrete command, test identifier or path, chosen while the tests were written |
| `Shown non-empty by` | the input that made that check fire, and the result — **blank is a refusal, not a default** |

The duty carried by `agents/design.md` § Rules → *Never pin a command as an exit gate*,
`agents/design-review.md:40` and `:87` — a verification gate is a claim about a command and must be
falsified before it is trusted — is *correct and must not be lost*; it
simply has no object in the design any more, because the design no longer names commands. Attaching it to
the column that holds the command means the two cannot drift apart: they are the same row.

**The distinction that makes the rule implementable**, written into the first sub-bullet of
`agents/design.md` § Rules → *AC-verification line is mandatory* because the rule is unusable without it:
"names no test method, file path or command" bites on the identifiers of the CHECK,
never on the subject under test. A test method's name, the test file's path and the command are all chosen
while the tests are written — that is the entire rationale. The artefact being observed is named in the
spec and is not chosen later. So an observable property plus its control is allowed, and the same thing
written as a filtered invocation of a named suite is forbidden.

**A recorded measurement is not a pinned gate**, stated as its own sub-bullet under `agents/design.md`
§ Rules → *AC-verification line is mandatory* rather than left to be inferred. This document's § Approach
quotes commands that were run while designing — probe verdicts, suite totals, size figures. Those are
historical facts about what was observed; a later rename cannot falsify
them. What the rule forbids is pinning a command as a criterion's *exit gate*.

**The section is NOT called an "AC verification map".** `agents/self-review.md` already uses that exact
phrase for a different thing — a map nobody re-derives — and a second mechanism under one name is the
collision the naming criterion exists to prevent on the other side of this change.

**Its lifecycle is honest: it dies with the branch, and nothing downstream needs it.** The durable evidence
is the committed tests themselves. This is deliberately *not* the failure `ai-docs/context.md` records,
where a figure died with a progress section and left a disposition naming a route that did not exist; there,
something downstream still needed the number.

**That the fourth column is enforced by prose rather than by a check is deliberate**, recorded at
`docs/templates/progress-format.md` so it does not read as an oversight: no criterion requires a mechanical
read of it, the round that writes it is the round that is reviewed, and a verb asserting the column is
non-blank would be cheap to add later if the prose proves insufficient.

**The two halves that ARE mechanical are decided by `acintent <spec> <design>`:** every criterion id in the
spec's criteria table has a matching intent line in the design — which is the "a criterion with no covering
check still fails" leg, preserving everything the old mandate was for — and no such line carries a token of
command, path or test-identifier shape. Renaming a shipped test then provably changes nothing, because no
intent line names one; the suite's rename leg renames a test in a fixture, re-runs the verb and asserts it
stays green. Semantic coverage — *does this check really establish that property* — stays the reviewer's
judgement, and the design says so instead of claiming a script decides it.

### Scope / AC26: the spec promises behaviour, and a criterion naming an instrument is refused

This arrived through the Spec Amendment route's **no** branch — a criterion restated, not an approach
changed — so it reached the shipped tree without a design re-derivation, and the closing fold is where it
enters the design.

**The rule's home is `agents/spec-writer.md` § What a spec IS, and what it may not contain.** A spec is a
behaviour contract: it says what the system does, observably, from outside. The test that settles every
borderline case is one sentence — *if the implementation can change without changing externally visible
behaviour, it does not belong in the spec* — and the forbidden list gains one entry beside the existing
four: a command, a script path or a gate invocation, because **a criterion that names its own instrument
asserts which instrument ran, not what the system does**, and it cannot survive a change of instrument.

**Two cases that look like exceptions are worked in the file rather than left to be re-argued**, both having
been raised against the rule in practice:

- *"The requirement IS that it be mechanical."* A criterion saying "closing such a finding is enforced by a
  checked-in gate, not by prose" reads as though deleting the instrument would drop a guarantee. Apply the
  test: if the refusal moved from a gate into prose, externally visible behaviour **would** change — the
  system stops refusing. So the behaviour is "closing it is REFUSED, not merely discouraged", and the gate
  is the instrument that delivers it. Write the refusal; let the design choose what refuses.
- *"The subject of this criterion IS a command."* A criterion about a size cap or a check suite seems to
  need its invocation. It does not: the property is "no instruction file exceeds the cap" or "the check
  list runs clean with its input set not silently narrowed". The invocation that demonstrates it belongs in
  the round's criterion-checks section.

**The rule is a refusal, and `specform` is what refuses it.** It is pinned as the spec writer's own exit
check before `status: ready`, which is what makes the form rule a refusal rather than an instruction in the
file that states it. The brief also tells its reader to **read the printed criterion count against the spec
they wrote** — a number below their criterion count means the selector missed rows, which is a different
failure from a criterion being clean — and to know the verb's bound before trusting a clean run.

**Why this rule is what makes the cheap amendment branch the common one** is argued in
`docs/workflow.md:442`, with the figures reproduced in § A changed REQUIREMENT above. Once a criterion
cannot name a command, a script or an identifier, the spec stops needing edits for implementation detail —
which is what drove amendment traffic in the first place.

### Rejected alternatives

| Alternative | Why not |
|---|---|
| A new `ai-docs/redline/` root for the log | Measured: the reference check's documented-root rule fires `major` on it, forcing an `agents-method.md` edit against almost no headroom. The plan tree costs nothing. |
| A new column in the fix-plan table for the redline payload | Changes the parsed cell count, so every shipped example, the scout's brief and the parser move. A sixth disposition changes a `case`. |
| The reviewer writes the committed log directly | `agents/self-review.md` is shared by three out-of-scope callers; they would all acquire the behaviour. |
| A third ignore glob read by a routing arm | The two existing globs are the suffixes the routing and anchor arms key on, and the template states that correspondence. The log is excluded by a **separate** variable read by `is_ignored` alone, so the pair stays a pair. |
| An arm A7 exemption keyed per DISPOSITION only | Measured: it refuses the honest plan and passes the evasive one — a truthful `Arm A` cell is refused however the round accounts for it, while a cell declaring `none` with no redline row is never refused. The exemption is per FINDING. |
| A new repo-level `run-checks` member for the redline gate | A member is invoked with no arguments and every verb of this one requires at least one, so it would report `cannot run` on every run. `EXEMPT_CHECKS` is the documented shape. |
| A separate script per skill for the refusal | `${CLAUDE_SKILL_DIR}` cannot reach across skills; two copies of one decision is the drift shape this repository keeps paying for. |
| Gate the fold on the PR's review-decision field | Measured: empty on all twenty PRs this repository has had. The gate could never pass. |
| Strikethrough as a second marker syntax | It preserves the superseded wording, which no design may carry at any stage; and a second syntax doubles the residue patterns for no new information. |
| Marking deferred to the fold, or once per divergence | Both forbidden by the spec's settled decision. |
| A fourth type token for a base that was silent | `added` already means exactly that relative to the frozen base. |
| Leave `agents/review-findings.md:38` re-running commands | After the change the design carries no commands, so it would pass vacuously — a false green, not a divergence. |
| Delete `agents/design-review.md:87`'s falsify-before-trusting duty | The duty is right; only its object moved. Deleting it loses a real guard to a bookkeeping change. |
| A committed sidecar file for the concrete AC-check set | Nothing consumes it after merge once `:38` checks intent-coverage; a committed file with no reader is a thing to drift. |
| A script that judges whether a check really establishes a property | Semantic, not mechanical. Claiming a script decides it is the "check mandated in prose" trap inverted. |
| The narrower filename-only enumeration pattern for `suppression` | Measured on the brief as this change found it: it misses the restatement that confers the same authority by naming the directory. The disjunction is part of the contract. |
| Wiring the phrase scan into `folded` as a leg | It fires on a document that merely QUOTES one of the phrases, which a document stating the rule necessarily does. It is a spot-check the fold calls as its own step. |
| An opt-out flag to narrow the redline suite | A gate that can silently narrow its own input set is the hazard `AGENTS.md` item 4 exists to close. |

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **The fix-plan gate.** Add the sixth disposition (three closed `redline: <type> — ` patterns, reusing the `?*` empty-payload refusal) and extend the out-of-vocabulary message; add arm **A7 `redline-accounting`** to the `plan` verb — firing on `fix` plus an `Arm A` anchor under either plan-artefact glob, exempting the other four dispositions with the `resolved:` exemption reasoned in a comment, and **exempting per FINDING** any `fix` row whose number carries a `redline:` row; add arm **A8 `redline-undelivered`** to the `applied` verb, deriving both paths from the progress file's basename and comparing keys by equality; exclude the log from the measured diff by a **separate** `IGNORE_GLOB_REDLINE` read by `is_ignored` and no arm, with the accepted cost in the script's comment; reword the `excluded-in-round` explanation so the marking pass is a named legitimate writer. Touch neither routing leg. Suite legs written first, including the probe-B control that must fail before the arm exists, plus a section for the ignore variable and its control. | `skills/task/scripts/check-fix-plan.sh`, `skills/task/scripts/test-check-fix-plan.sh` | — |
| 2 | **The new gate script.** Create `scripts/check-redline.sh` with seven verbs — `pending`, `folded`, `suppression`, `acintent`, `revision`, `paired`, `specform` — on the repository's `0 clean / 1 findings / 2 cannot run` convention, with the convention itself, `suppression`'s `done/` OR `design\.md` disjunction and its line unit, `revision`'s phrase list and its spot-check-not-a-leg status, `paired`'s key-shape filter and mode bound, and `specform`'s body-reach requirement and classification bound all written into the script's own comments as contract. Suite written first: per verb, a leg that must come back non-empty, a control that must come back empty, **and a cannot-run leg** — `pending`'s being the one whose absence turns the backstop into silent passage. `specform` carries one leg per token class in both directions. Register the new paths with the index before any shell-syntax run. | `scripts/check-redline.sh`, `scripts/test-check-redline.sh` | — |
| 3 | **The authoring subagents' contracts + the two record formats.** `agents/design.md` gains `## Redline marking` (both key-token spellings and the placement rule, the freeze point at the design-review GO verdict with the GO-with-notes window named, the one-pass-per-occasion bound, the row's derivation from the plan row with the reason field a floor rather than a cap, the extension-anchoring rule and the requirement/artefact boundary, the re-derivation duty on an existing row, the mode table with its recommendation rubric, and `paired` as the pass's own exit check) and `## The redline fold` (fresh authoring written section by section per the transport-drop hazard, the residue strip, the positive superseded-material assertion, the spec collapse, the log's removal, the gate); gains the **author-side no-revision-account clause**; has the template example and the mandate rewritten to demand verification intent **with the check-identifier-versus-subject distinction stated**; and has the falsify-before-trusting duty re-pointed at the design's own pinned gates. `agents/spec-writer.md` § What a spec IS gains the instrument clause, the settling test, the two worked near-exceptions and `specform` as its exit check. `docs/templates/progress-format.md` gains `## The redline log (committed)` — with the prescribed four-field head — and `## Criterion checks (Round N)` carrying the **`Shown non-empty by` column where blank is a refusal**, plus the sixth disposition in the vocabulary, the marking pass in the `excluded-in-round` paragraph, and the two head amendments. | `agents/design.md`, `agents/spec-writer.md`, `docs/templates/progress-format.md` | 1, 2 |
| 4 | **The review contracts.** `agents/self-review.md`: replace the staleness sentence with the breaking / non-breaking test; narrow the "BEFORE the code change lands" requirement and the Arm A / Arm B block to the breaking case; add the settled-marker rule with its explicit carve-out from the don't-review-their-content clause and the statement that the reviewer is not asked to read the log; rewrite `:53` to assert **the falsification predicate read off task 3's column**, never bare intent-coverage. `agents/review-findings.md`: narrow the reading instruction and the suppression restatement to the spec alone, and keep `:38` as verification on the **intent-coverage** predicate — deliberately weaker than `:53` — writing the lifecycle reason in beside it. `agents/design-review.md`: rewrite the Tests checklist row; re-point **`:40` and `:87` together**; and add the **reviewer-side clause that a revision account is not a thing a verdict may require**. `skills/ai-audit/reference.md`'s back-reference follows `:40`. `docs/workflow.md`: the rationale the agent files point at, plus the guard sentence that `/bugfix`, `/project-review` and post-push rounds keep today's behaviour. | `agents/self-review.md`, `agents/review-findings.md`, `agents/design-review.md`, `skills/ai-audit/reference.md`, `docs/workflow.md` | 3 |
| 5 | **The task wiring, enumerated rather than searched for.** The eight amendment-route sites, each as a substitution of "requires a design change" by "breaks the agreed approach" or, for the two `Deviating …` sentences, as an addition naming the non-breaking remedy **with the case qualifier**; the new non-breaking routing row; the marking beat added to the scouted-plan sequence, bounded to one invocation per round and **ordered before the apply**; the implementation step's surface-and-choose-a-mode beat; the accumulated-corrections hand-off in the Design Amendment recipe; the log carried in Step 12's move; and the **Spec Amendment recipe rewritten as a question with two branches**, written as a substitution so three numbered lines stay three. Plus the three homes of the disposition vocabulary that the gate's token needs: the scout's disposition table and its beside-not-instead rule, the fix agent's per-disposition action table, and the task skill's closed-vocabulary enumeration. Overflow rationale goes to `docs/workflow.md` as two new sections. Re-measure both task files at this task's close. | `skills/task/SKILL.md`, `skills/task/reference.md`, `agents/fix-scout.md`, `agents/fix-apply.md`, `docs/workflow.md` | 1, 3, 4 |
| 6 | **The command and the refusal.** Create `skills/redline-fold/SKILL.md`: the measurable preconditions, the unmeasurable-approval statement with its probe result, the model-invocation refusal, the empty-log branch, the nothing-starts-it branch, the two owning-subagent spawns with afresh and section-by-section both stated, the log's removal, the positive judgement step, the two gate calls and the surfaced commit. `skills/pr-merged/SKILL.md`: the refusal above step 1, **refusing on anything that is not a clean 0 and naming which of the two non-clean outcomes it got**, with the sequencing limit in its own words. | `skills/redline-fold/SKILL.md`, `skills/pr-merged/SKILL.md` | 2, 3 |
| 7 | **Registration, propagation, measurement.** `EXEMPT_CHECKS` gains the new check, with its own reason stated separately from the fix-plan gate's; `AGENTS.md` item 4's suite list gains the new test; the install-smoke skill array gains the new skill; `docs/propagation.md` gains the Redline group anchor plus back-reference rows; the public command table and the embedded-name inventory gain the new skill; `ai-docs/context.md` gains the Redline log entity and has the fix-plan gate's own entry corrected; the plugin patch version is bumped. Then re-measure every touched method file, re-run the propagation gate and **read its member list, confirming the new members by name**, and run the full check list reading the processed file count beside the syntax verdict. | `scripts/run-checks.sh`, `AGENTS.md`, `scripts/test-install-smoke.sh`, `docs/propagation.md`, `README.md`, `docs/claude-tools-hierarchy.md`, `ai-docs/context.md`, `.claude-plugin/plugin.json` | 1, 2, 3, 4, 5, 6 |

**Why task 7 is last and separate.** The install-smoke skill array is a *count* assertion — it compares
distinct declared names against the skill directories on disk — so creating the skill directory in task 6
turns that gate red until task 7 lands. The same window applies to the stray-check member, which reports
any tracked `check-*.sh` that is neither exempt nor a member, and so reddens from task 2 until task 7. Both
are the intended ordering rather than an oversight, and both fail loudly and name the path.

## Risks

Each risk the work carried, with the mitigation as shipped and the closing measurement where there is one.

- **`skills/task/reference.md` and `skills/task/SKILL.md` both sit close to the early warning and task 5
  adds to both.** Mitigation as shipped: the marking pass's full recipe lives in `agents/design.md`, which
  is also its correct owner — the agent's own contract — while the task files take only the vocabulary
  token, the short recipe beats, the hand-off sentence and the checklist rewrites, and the overflow
  rationale goes to `docs/workflow.md`. Re-measured at close: `reference.md` 33,609 → 34,524 (+915),
  `SKILL.md` 32,101 → 34,865 (+2,764). Both below 35,000, and both now tight enough that the next edit to
  either owes an extraction rather than an addition.
- **`docs/workflow.md` is the overflow sink for three tasks' rationale, and a sink has a bottom.** It was
  chosen for the overflow because it had the most headroom in the set — 8,223 chars when the change began.
  Re-measured at close: 26,777 → 34,969 (+8,192), leaving **31 chars** against the early warning. So the
  mitigation worked exactly once and is now spent: the next rationale this mechanism needs cannot go here,
  and the next edit to this file owes an extraction. This is the tightest file in the change and the one a
  later reader should measure first.
- **The eight amendment-route narrowings could be applied inconsistently, leaving one site still mandating
  the full chain** — invisible to a reviewer who checks only the routing table. Mitigation: task 5 names all
  eight with a keep-or-narrow disposition each, so the check is an enumeration rather than a search, and the
  mechanical-and-mandatory clause is called out as the decisive one because it is the sentence that
  forecloses the escape rather than merely pointing at it. Two of the eight were ambiguous rather than
  wrong, and were rewritten to name the alternative rather than certified on a favourable reading.
- **`agents/self-review.md` sits close to the early warning and task 4 is its largest edit.** Mitigation:
  rule in the agent file, rationale in `docs/workflow.md`. Two of task 4's edits are replacements rather
  than additions, which recovers space. Re-measured at close: 34,915 chars — 85 below the warning, so the
  next edit to this file owes an extraction rather than an addition.
- **The suite is red between tasks 2 and 7, and again between tasks 6 and 7**, by construction, because
  both the skill count and the check inventory are equality assertions. Mitigation: stated in the
  decomposition note; the implementer reads it as sequencing rather than as a regression, and task 7 closes
  it. Both failures name the path.
- **The index sees tracked files only, so a new `*.sh` is invisible to the shell-syntax gate.** Mitigation:
  registering both new paths with the index is part of task 2, and the processed file COUNT is read beside
  the verdict rather than the exit status alone. Re-measured at close: 54 tracked shell files, against 52
  at baseline — the two new scripts, and a count that had not moved would have been the tell.
- **A plan row's `Arm A` cell could name a plan artefact while the finding is genuinely about code**, so
  A7 would demand an accounting that is not owed. Mitigation: that is what `object:` and `resolved:` are
  for, and both are exempt; the scout's brief defines `Arm A` as "would closing this finding leave a
  sentence untrue", so a cell naming a sentence that is not at stake is a scout defect the arm correctly
  surfaces rather than a false positive.
- **A7 could penalise the honest plan**, which is the shape the per-row form actually had: a truthful cell
  refused however the round accounted for it, while a cell declaring `none` was never refused. Mitigation
  as shipped: the exemption is per FINDING, read once before the row loop, with its own leg asserting the
  PASS and the sibling leg asserting the refusal where no accounting row exists, so both directions hold.
- **The marker is appended inside a table cell, so a careless edit could shift a column.** Mitigation: the
  token carries no `|` and no newline; the gate's parser refuses a row with the wrong cell count, so a
  shifted row fails loudly rather than being misread. The placement rule in `agents/design.md` also names
  the cell that carries the item's prose, so the marker does not land in a dependency or path cell where a
  reader does not meet the item.
- **A document that merely QUOTES the marker token would read as a marked document.** Mitigation: the
  pairing verb admits a key by SHAPE, so a template carrying angle brackets and spaces is not a key. This
  fired for real on the verb's first live run, against the contract file that defines the token.
- **A gate script whose cannot-run lane is untested reads as a pass.** `pending` is the one check here whose
  whole purpose is to be a backstop, so its failure mode is the only one that matters. Mitigation: the
  three-outcome convention is written into the script's own header as contract, the cannot-run leg is in
  task 2's deliverable list, and the caller refuses on anything that is not a clean 0 rather than on a
  single value.
- **A comment promising a leg the code does not have.** The phrase scan is called by the fold as its own
  step and is not wired into `folded`; a header comment claiming otherwise would be the quietest kind of
  false green. Mitigation: the script's header states which verb reads the phrase list and what `folded`
  does read, and the phrase list has exactly one caller outside its own suite.
- **`/redline-fold` is not in the `skill-gate` set**, so a model could invoke it. Mitigation: the skill's own
  first action refuses a model-initiated invocation, in the shape `skills/pr-merged/SKILL.md:19` already uses
  for the merge premise. The approval it rests on is the user's and cannot be measured here.
- **The fold runs after approval and the default branch carries no branch protection**, so pushing the fold
  commit dismisses no approval and blocks no merge. With suppression authority moved off the design this is
  a platform fact rather than a risk — recorded because a reader will otherwise look for the mitigation.
- **The merge-time refusal performs no repair of its own.** It runs after the window this change gave the
  fold, by construction. Mitigation: that bound is stated at the guard itself, so the refusal is read as a
  bound rather than as a promise. A caught error instead of silent damage is the whole claim.
- **Pre-existing, out of scope, still tracked:** `agents/design.md` § Patterns and
  `agents/design-review.md:89` name a language, a runtime tool and a storage engine inside method files,
  which the project's own method/profile rule makes a `major`. Both predate this change and tasks 3 and 4
  edit those files — **they stay as they are here.** Filed as issue **#111**; the provenance half, a named
  entity used as the house example in several further places including the scaffold template, is issue
  **#112**. Both are open. The
  implementer should neither silently inherit them nor expand scope to fix them.

## Test Design

**Register note.** Per the spec's Scope 11 and AC22, each line below states the verification **intent** —
what must be observed, about which artefact, and with which control — and names no test method, file path
or command. The concrete check covering each intent, and the input shown to make it fire, is recorded in
the progress file's `## Criterion checks (Round N)` section as the tests are written. Commands and figures
quoted elsewhere in this document are records of measurements already taken, not gates pinned in advance,
and they remain subject to the falsify-before-trusting duty in full.

**Scenario shape every mechanical intent below is built on.** Each new gate leg ships as a pair: one input
that must make the check come back non-empty, and one control that must make it come back empty. A leg with
only the empty direction is not accepted, because an empty result and a mistyped filter are
indistinguishable outputs.

**Fixture basis.** The fix-plan legs build on the suite's existing throwaway-repository helper, which
already produces a tracked spec artefact, a tracked design artefact and a tracked non-routing sibling under
the plan prefix — the three paths the exclusion and routing legs need in order to measure one rule at a
time. The new script's legs build their own throwaway tree with a committed spec, a marked design and a log,
because the comparand for the collapse check is the previous commit.

- AC1 verified by: that the reviewer's contract no longer carries any instruction to reject correct code
  for a stale document, and that what replaced it branches on whether the approach is broken. Control: the
  superseded sentence is present and findable in the contract as this change found it.
- AC2 verified by: that a non-breaking divergence produces one marker and one row and leaves the round
  running. Established by ENUMERATING every instruction that mandates the amendment route and confirming
  each either branches on approach-breakage or names the non-breaking remedy explicitly as a permitted
  alternative — eight sites, so the check is a roll-call and not a search, and a pass that inspects only the
  routing table is rejected. No site is certified on a favourable reading of an ambiguous sentence: where
  the wording admitted both readings it was changed, not interpreted. Control: a breaking divergence still
  routes.
- AC3 verified by: that after marking, the marked item's original wording is still present in the file and
  the marker sits beside it rather than replacing it. Demonstrated on a decomposition row, because that is
  the cell shape most likely to break. The rule that the ITEM rather than the line is the unit — so a
  wrapped paragraph takes its marker at the paragraph's end — is asserted as written down in the marking
  contract, since where inside a paragraph a marker belongs is a judgement no leg can decide.
- AC4 verified by: that the marking is attributed to the design subagent and bounded in the step text to
  one invocation per occasion carrying divergences — a review round, or the implementation step — and that
  no orchestrator-side edit of a design artefact is instructed anywhere.
- AC5 verified by: that the reviewer's contract states a marked divergence is not re-raised in a later
  round, with an explicit carve-out from its don't-review-the-content clause, and that the contract nowhere
  tells the reviewer to read the log as a separate input. The second half is an absence, so it carries its
  own positive control.
- AC6 verified by: that the row's documented shape carries a closed three-value type vocabulary, the
  artefact sentence diverged from and what shipped instead; that the documented shape states a base which
  was SILENT about something takes the same token as an addition, so no fourth token is owed; that both key
  forms are admitted, one for a divergence a review round found and one for a divergence implementation
  found; and that the gate refuses a type outside the three. Control: each of the three valid types is
  accepted.
- AC7 verified by: that the log's path is not matched by the ignore rules, with a control path that IS
  matched; and that the merge-time cleanup leaves the log in place while still removing what it is meant to
  remove.
- AC8 verified by: that a round carrying a marking pass passes the fix-plan gate while a genuine design
  amendment still routes it — the discrimination observed as two different decisions from the same gate on
  two inputs differing only in the disposition, not merely as one passing run. And that the round's
  accounting for excluded mid-round writes of the design artefact names the marking pass as a legitimate
  writer of them.
- AC9 verified by: that closing a finding whose subject is a plan-artefact sentence, with nothing accounting
  for it, is refused by the gate. The pre-change behaviour is the control and has already been observed: the
  unaccounted case passed with every arm green, and that run ships as the suite's control leg. The
  converse is asserted as its own leg, because without it the arm penalises the honest plan: a row whose
  cell truthfully names the at-stake sentence PASSES when the same finding carries an accounting row, while
  the leg beside it observes the refusal where no accounting row exists. The gate's reach is bounded by the
  scout-written field both arms key on, and that bound is asserted as written down rather than demonstrated,
  because a field declaring its own absence cannot be falsified mechanically.
- AC10 verified by: that a named command exists whose step text names itself, states the empty-log branch,
  states what happens when nothing starts it, and establishes its before-merge position from a measurable
  fact; and that no surface acquires a repeated read of the review state.
- AC11 verified by: that the merge-time workflow refuses while an unprocessed log is present, does not
  refuse when none is, **and refuses on a check that could not run at all** — three outcomes, because with
  only the first two the backstop's failure mode is silent passage. The check's outcomes follow this
  repository's established convention rather than a local one, the refusal is positioned before anything is
  deleted or moved, and the step text states the sequencing limit in its own words.
- AC12 verified by: that a breaking divergence still reaches the full rebuild, that the rebuild is handed
  the accumulated markers and rows, and that the step text names the hand-off and the reset of the log to
  empty.
- AC13 verified by: that the folded design carries none of the three residue patterns — the two spent
  headings and the marker token. Control: all three are present before the fold and findable.
  **The superseded-material leg is checked positively, never by a fragment search:** a document recording
  its own corrections holds
  the superseded wording inside a quotation, so an absence proved from a fragment is a false positive. So
  the assertion is that every section describes the shipped state — a judgement, named as one — with a
  bounded scan for the phrases that introduce an account of a past revision as its spot-check, and that
  scan's own ability to fire shown on a fixture that carries one.
- AC14 verified by: that the three retained spec sections are byte-identical to their pre-fold text,
  compared against the previous commit rather than against a captured copy written by the same pass, and by
  a file comparison rather than a string equality, so a trailing-newline difference cannot hide. Control: a
  single altered character in one retained section is detected.
- AC15 verified by: that every instruction in the whole-branch reviewer's contract conferring suppression —
  whether by filename or by naming the completed-plans directory — names the spec alone, established by
  enumerating them under a pattern that reaches BOTH spellings. The narrower filename pattern has been
  measured to miss the directory-spelling instruction entirely while the disjunction reaches all four, so
  the pattern is part of the criterion and not an implementation choice. The enumerated count is read beside
  the verdict, because an enumeration that narrowed its own input set is the quietest false green there is.
  Control: the contract as this change found it is detected twice over — one instruction conferring the
  authority over a design document, one conferring it through the directory spelling alone. The verification
  re-run over completed designs is retained, and that retention is itself asserted.
- AC16 verified by: that the fold removes the log from the tree, and that the post-merge reader still names
  exactly the two document classes it names today and no third.
- AC17 verified by: that the change introduces no new unqualified use of the word the learning-log fold
  already owns, and none of the name the Learning Log archive owns — measured over the change's own added
  lines, because both words have legitimate pre-existing uses. A baseline inventory of those uses has been
  taken so the delta is readable.
- AC18 verified by: that the propagation table's new group is derived by the arms gate, that the gate
  passes, and that its reported member list is read and the new members confirmed **by name**, not by the
  count alone. Already established against the member paths this design settles on: the derived set is 43
  members, every one firing under existing hook arms, every control silent, and no new hook arm owed.
- AC19 verified by: that every method file this change touches measures below the early-warning threshold
  after the change, each figure read rather than inferred from the shape of the edit. Already established
  for the file that had the least headroom: it is out of the edit set entirely, because the documented-root
  rule resolves any path under the existing plan root — proven on one fixture that passes and one control
  that fires.
- AC20 verified by: that the full structural check list passes with exactly one verdict per member and no
  drift between that list and the tree, that the processed shell-file count is read beside the syntax
  verdict and has moved by the number of new scripts, and that the plugin patch version is bumped.
- AC21 verified by: that no method file this change touches acquires a language, build tool, domain entity
  or ticket prefix — measured over the change's added lines, because the tree carries pre-existing
  instances. The delta form has been exercised against an input that must trip it and against one that must
  not.
- AC22 verified by: that renaming a shipped test produces neither a rejection nor an amendment route, while
  a criterion left with no covering check still fails — the discrimination observed as two different
  outcomes, not one passing run. Established by ENUMERATING every instruction that enforces the
  concrete-command form, from both of the vocabularies the rule is written in rather than from the one
  phrase: nine enforcers plus a back-reference, each asserted to demand intent rather than an identifier.
  Separately, that the falsification duty survives re-pointing with a named receiver and a predicate about a
  check having been shown able to fire — never merely about a check existing — and that the reviewer-side
  checklist and the reviewer-side rules were moved together, since one alone makes compliance read as a
  defect. And that the in-task and post-merge gates carry **different** predicates, the weaker one
  post-merge, with its reason recorded at the gate itself: the stronger evidence lives in a file that is
  never committed and is deleted at merge time, so the two gates cannot read one carrier. A design giving
  both the same predicate specifies a read of a deleted file.
- AC23 verified by: that no record of superseded material survives in a design at any stage, and that the
  rule binds both sides of the review. The author's side states that a pre-approval correction is a rewrite
  and that the document carries no account of what a superseded draft said or argued. **The reviewer's side
  — the half that was missing, so the half the demonstration is about — states that a revision account is
  not a thing a verdict may require**, and points a correction's reasoning at the round's own findings
  table. The reviewer's checklist carries the detection half beside it, at the same severity as any other
  passage that does not describe the system, with the pointer marker explicitly carved out of it — a
  marker carries a key and nothing else, so it is not an account of anything. Shown both ways: a verdict
  demanding such an account is refused under the new clause, and separately an ordinary finding is
  unaffected. **This document is the fixture:** it is checked positively,
  section by section, for describing its current state rather than a past one, and the bounded phrase scan
  is run over it with that scan's own ability to fire established on a fixture that carries an account of a
  past revision.
- AC24 verified by: that the implementation step takes no route automatically on a divergence from the
  frozen plan — it stops at the FIRST one in the task and puts the choice to the user once, leading with a
  recommended mode whose grounds are read off the design and settled by the user's confirm-or-flip. Both
  modes are named, the chosen one governs every later divergence in the same task, and no condition re-runs
  the planning chain by itself. The chosen mode is recorded where the closing fold reads it — the committed
  log's header, not the progress file that merge deletes — and the record is refused when the mode is
  absent, when it is outside the two-token vocabulary, or when its grounds cite nothing from the design.
  The citation requirement is observed on the whole mode block rather than its first line, since the grounds
  wrap. A task whose divergences were all raised by a review never reaches the choice and owes no mode:
  that is asserted as the keying of the refusal, with a record carrying no implementation-step row passing.
- AC25 verified by: **a judgement criterion — what satisfies it is the recorded decision on each extension
  and not a check.** That the hybrid mode's scope discipline is stated as a test rather than an exhortation:
  an extension reaches the log only when correctness needs it, and one that would widen what the task
  DELIVERS is routed to a new ticket instead of a log row. And that the boundary has a stated floor: work
  no item in the design contains at all is a missing whole and takes the breaking route, which is what keeps
  the extension type from becoming a bucket for unplanned scope.
- AC26 verified by: that a criterion naming a command, script, test identifier or tool is REFUSED rather
  than discouraged — the refusal pinned as the spec writer's own exit check, so the rule is not enforced
  only by the file that states it. The predicate is observed in both directions on real specs: this task's
  spec reports clean at its full criterion count, while the same spec as the branch found it reports dirty
  with the offending criteria named, and a set of instrument spellings planted into a copy of the clean spec
  is refused class by class with the clean criteria in that same run staying clean. The scan is asserted to
  reach criterion BODIES rather than id cells, by a leg planting a token in the LAST criterion's body — not
  by the printed criterion count, which is independent of the body extraction. Its bound is asserted as
  written down: a criterion naming an instrument class in prose alone passes, and that reading stays the
  reviewer's. The two cases that look like exceptions are settled in the file rather than left to be
  re-argued.
