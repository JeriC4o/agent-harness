# Design: Retire the closing fold — correct the design in place, archive the plan as written

**Ticket:** GH-173
**Date:** 2026-10-28
**Spec:** ai-docs/plans/2026-10-28-retire-closing-fold.spec.md

## Approach

The marker, the correction log and the closing fold are replaced by three things that already have a home
in every consuming project — a commit, the working tree, and the review that runs every round:

- **The freeze is a commit.** At each design-review GO, once the GO's notes are worked into the design, the
  spec and the design are committed in a commit whose message ends with the trailer
  `Plan-Freeze: <spec-base>`. Nothing about the freeze lives in a local file.
- **A divergence is corrected in the design, in place**, by the design author, in the same round as the
  code it describes and after that code exists. No marker, no log, no mode question, no question to the
  user. A divergence that breaks the agreed approach keeps the full route and ends in a new freeze.
- **The review reads the computed change.** A new helper computes each plan document's change since the
  plan's latest freeze, from the repository, by content, so the move into the archive is no change and a
  rebase changes nothing. Every review round of the task, follow-up rounds included, rules on each design
  change: breaks the approach, keeps it and describes what shipped, or describes nothing the shipped work
  needed.
- **The review's breadth fingerprint is taken over the frozen plan**, plus the spec as it stands, so an
  in-place correction leaves it alone while a new freeze or an approved requirement change still moves it.
- **The plan reaches the archive as written** inside the task's own pull request, and nothing runs after
  the merge.

**Order of work: decouple first, behaviour unchanged, then build, then remove.** The spec's record of
deliberate absence — the `RETAINED` assignment [retained-list] in `scripts/check-redline.sh`, moving to
`scripts/deliberate-absence.sh` with its id — is read as text by the closing fold's gate and by readers that
survive it: the element derivation in `scripts/check-plan-invariants.py`, at the route that reads the
enforcer's data; `retained_sections()` [retained-sections] in `scripts/check-plan-convergence-holding.py`;
the archive listing `scripts/plan-archive.sh`; and the verifications' extractions of the list, which parse
it out of the same file. It moves to a data file of its own first, with every reader of the constant
re-pointed, the verifications' extractions included, and no behaviour changed, so the later removal of the
fold's verbs cannot take a surviving reader's input with it; a reader that comes back empty after the move
is a changed behaviour, not a moved list. The freeze helper and the new fingerprint come next, and add
everything but one removal: subtask 2 takes the marker strip out of `compute_plan_digest` in
`scripts/review-ledger.sh`, and the settled-marker sentence out of `docs/converging-review.md`, because the
digest over the frozen plan replaces what the strip was for. The instruction rewrite follows, ordered so
that every file linking a page this task deletes is rewritten before the page goes. The removal of the fold
itself — its skill, its verbs and the merge-time refusal, in subtask 6 — comes last.

**Rejected alternatives.**

- **A new freeze at every approved spec amendment**, so the fingerprint could be the frozen pair alone. A
  freeze taken when a spec amendment lands also captures every in-place design correction made since the
  previous freeze that no review has yet ruled on — a correction during implementation followed by a
  declared-link report that ends in a spec amendment is the concrete case — and those corrections then
  vanish from the computed change unreviewed, because an amendment that keeps the approach runs no design
  review that could rule on them first, as the review before a GO's freeze does. It also costs one more
  commit consent per amendment. Hashing the spec as it stands achieves the same breadth reset with neither
  cost.
- **The freeze's commit id in a gitignored file.** It does not survive a rebase, a fresh clone or a second
  machine, and the spec forbids it.
- **Hashing the freeze commit's id into the fingerprint.** A rebase rewrites the id, which would send the
  next round to a full re-examination for a change nobody made. The fingerprint hashes the documents' text
  at the freeze instead.
- **The reviewer reconstructing the change from the design author's hand-back.** That is the author's
  account, which the spec rules out as the input.
- **A mechanical "correction delivered" arm in the fix-plan gate**, in place of the marker-pairing arm. The
  Arm A closing gate already re-reads the cited sentence before a finding closes, and the next review rules
  on every design edit through the computed change, so a third witness would read the same fact.
- **Keeping the `revision` verb of `scripts/check-redline.sh` as a spot-check for in-place corrections.**
  Its phrase list fires on any document that quotes a revision introducer, and the review's ruling on the
  computed change sees every line an in-place correction wrote, a revision account included.
- **Moving `RETAINED` onto `docs/plan-invariants.md`.** Three parsers would change shape in the step that
  is supposed to change nothing, and the principles page would become the source of a list it today only
  records.
- **Renaming `scripts/check-redline.sh`** once only `specform` and `suppression` remain. The rename moves a
  protected page's spec-writer call, the edit-time refusal's data, the profile's touched-scope mapping and
  several readers, and buys a name. The script keeps its name and its header says what it now checks.

## The freeze

- **What it is.** A commit holding the plan's spec and design as approved, with the approval's notes worked
  in. The design author's committed records beside them — the record of declared links, and the record of
  excused findings when the task wrote one — ride in the same commit, because they are written with the
  design and are already staged by name. The message's title is the task's ordinary commit title; its last
  paragraph is the trailer `Plan-Freeze: <spec-base>`, where `<spec-base>` is the spec's file name without
  `.spec.md`, the same name the plan's other records are keyed by.
- **When it is taken.** At every design-review GO of the plan: the first GO, a GO after a design amendment
  that a divergence breaking the approach caused, and a GO after a spec amendment that changed the
  approach. Each time the GO's notes are worked into the design first, by the design author, and then the
  commit is surfaced to the user once — staged list and message — under the repository's existing consent
  rule for commits. Implementation does not begin on a plan with no freeze, and Step 8's first action
  checks for one.
- **A GO after the first one rules on what its freeze absorbs.** That freeze carries every in-place
  correction made since the previous one, and an amendment entered from implementation reaches it before
  any review has ruled on the corrections of the groups already done. So the re-entry design review, from
  either amendment recipe, is handed the helper's `diff` over the design since the previous freeze as an
  input of its own, and rules on each hunk outside the sections the amendment changed, which its prompt
  names, by the outcomes of
  § The review's ruling and the plan digest, reading the task's code change since the progress file's
  `**base_commit:**` beside it: a hunk that keeps the approach and matches the shipped code is accepted;
  one that breaks it or describes nothing the shipped work needed is a `major` issue. The freeze is taken only
  on that review's GO.
- **A spec amendment that keeps the approach takes no freeze.** The fingerprint reads the spec as it
  stands, so the amendment still sends the next round to a full re-examination, and the design corrections
  its re-read makes stay visible in the computed change for the review to rule on.
- **How it is found.** The latest commit reachable from the branch head whose message trailers carry
  `Plan-Freeze` with exactly the plan's spec base as value. `git log`'s format string offers a trailer
  placeholder filtered by key, and a rebase replays a commit's message with its trailers; both were
  confirmed against the installed git on a scratch repository before this design was written, the rebased
  copy of a freeze resolving to the same value. A freeze of another plan on the same branch carries a
  different value and is never matched.
- **The change since the freeze** is each plan document's text at the freeze against its text in the
  working tree, compared by content wherever the document now sits. The freeze's own tree is searched under
  `ai-docs/plans/` for the document's file name, so the move into `ai-docs/plans/done/` reads as no change,
  and uncommitted corrections are included because a review runs before its round is committed.
- **Three outcomes, and the third is never the second.** `changed`, `unchanged`, or could-not-compute — no
  freeze reachable, a freeze whose tree lacks the document, not a git work tree, a tool missing. A
  could-not-compute is reported with its reason by every party that reads the change and is never read as
  "the design is unchanged".

**The helper is `scripts/plan-freeze.sh`**, a method script named outside the words the result-masking
hook and the gate record key on, because it computes an input rather than passing or failing anything.
Each verb takes a plan document's path, from which it derives the spec base:

- `find` prints the freeze commit and the plan's spec base;
- `show` prints the document's text at the freeze;
- `diff` prints one unified diff per named document, then a verdict line carrying the outcome word, the
  freeze commit, and how many documents it compared and how many changed.

Its exit codes follow the repository's three-outcome convention in `docs/gate-outcomes.md`: the clean code
when the result was computed, changed or unchanged, and the could-not-run code with the reason otherwise.
It never takes the findings code, because it judges nothing.

## Correcting the design in place

A further invocation mode of the design author, under a new heading in `agents/design.md`, *Correcting the
design in place*, which replaces that file's sections *Redline marking* and *The redline fold*. The
orchestrator never writes the design; it spawns this mode once per occasion with the occasion's list of
diverged items:

| Occasion | When the pass runs | Its input |
|---|---|---|
| Implementation, Step 8 | once per handoff group that recorded a divergence, after the group's code is written | the group's divergences, recorded in the progress file's decisions log as the design item by its heading and what shipped |
| A review-and-fix round, Step 11 | once per round carrying a `correction:` row, after the apply and the post-apply micro-loop, before the round's review | the round's `correction:` rows |
| A follow-up round on the task's open pull request | after the round's fix is written, before its review | each design item that round's fix made untrue |
| A bug fix run inside any of those, its trace carrying `**parent_skill:**` | after the fix, within the enclosing round | the design items the bug fix leaves stating something that no longer ships |
| A spec amendment that keeps the approach, in any workflow | the recipe's fifth act, as today | the false design items the re-read ruled on |

**What the pass does.** It rewrites each named item so it states what shipped and nothing else, in place,
carrying no account of what the item said before — the computed change is the record of that. It applies
the rule kept from the retired marker contract, which becomes a rule of the design for every task: **a
correction is admitted only when it is needed to make the shipped thing correct; work that would widen what
the task delivers is proposed as a separate ticket instead.** An extension is written into the item whose
scope it falls within; work no item contains is a missing whole and takes the breaking route. It ends with
the design author's own exit checks, as every write of the design does, and rewrites any declared-link row
whose design end it changed.

**What decides the route** is unchanged: does the divergence break the agreed approach? Not breaking →
this pass; nothing restarts and nobody is asked. Breaking → work stops, the user is asked, the design author
amends, design review runs, and the GO takes a new freeze. In Step 8 the orchestrator applies that test to
the group's hand-back; in a review round the review's own ruling on the computed change is a second reader
of the same test.

**Whose plan.** On the four divergence occasions — implementation, a review-and-fix round, a follow-up
round and a nested bug fix — the in-place correction applies to the task's own design only; a sentence of
another plan's design — an archived plan later work makes untrue — still takes the amendment route with the
user's approval inside the later work's own pull request. The spec amendment's occasion corrects the design
of whichever plan the user-approved amendment changed: in a standalone `/bugfix` or `/project-review` that
is another task's archived design, and the user's approval of the amendment is what admits the correction
there. A spec sentence left untrue is a changed requirement, not a divergence, and always takes the Spec
Amendment recipe; because the spec is now archived whole, a
false spec sentence would otherwise stay false in the archive, and the arm that raises it already admits
only a genuine conflict under the base principles.

**Standalone `/bugfix` and `/project-review` keep the full route** for every divergence they find, and
neither is given the computed change: their review prompts name no design, and that absence is what keeps
them out. The one thing they see change is the Spec Amendment recipe's fifth act, which corrects a falsified
design item directly in every workflow now that no plan carries a correction log.

## The review's ruling and the plan digest

**The ruling** lives in `agents/self-review.md`, at the step that reads the design, and binds only when the
prompt names a design. The task workflow's Step 10 prompt already names the spec and the design, so it gains
no line; a follow-up round's prompt names them at their archived paths, which the post-push table on the
workflow page states. The two other callers of the shared contract stay outside it by the same test: a
standalone or nested `/bugfix` prompt names a trace and `/project-review`'s names neither document, so a bug
fix nested in a task round reviews its own fix without the ruling and the enclosing round's review rules on
the correction it caused. The reviewer runs the helper's `diff` over the spec and the design as its own call
and rules on each changed design hunk:

| The change | Outcome |
|---|---|
| breaks the agreed approach | a Design Amendment trigger, as an Arm A finding raises one today |
| keeps the approach and describes what shipped | accepted, no finding |
| describes nothing the shipped work needed — an unintended edit, or work beyond the task | a `major` finding |

`unchanged` is said in the verdict. A could-not-compute is said too, with its reason, and is a `major`
finding naming the remedy — a missing freeze is taken by surfacing its commit, a failure is fixed — because
a round that cannot see the change since approval cannot rule on it. Spec hunks are approved amendments and
are read as the requirements the design now answers; a design hunk that brings the design in line with one
is the second outcome. The settled-marker rule and its carve-out go.

**The plan digest** in `scripts/review-ledger.sh` is computed over the frozen plan — the spec and the design
as they stood at the latest freeze — together with the spec as it stands. The ledger gains a `--frozen
<path>` option on both verbs whose document is hashed from the helper's `show` output; `--plan <path>` keeps
hashing the document as it stands; the marker stripping in `compute_plan_digest` goes. A frozen document the
helper cannot resolve is the ledger's could-not-run, on which the reviewer already sweeps every item and
says so. The task's rounds and its follow-up rounds pass `--plan <spec> --frozen <spec> --frozen <design>`;
`/bugfix` and `/project-review` pass none and record `none`, as today. So:

| Event | Digest | Next round |
|---|---|---|
| an in-place correction | unchanged | carries what it would have carried |
| a new freeze | the frozen half moves | full re-examination |
| an approved spec amendment, either branch | the live half moves | full re-examination |
| the move into the archive | unchanged — content, not path, is hashed | carries |
| a rebase | unchanged — text, not commit ids, is hashed | carries |

`docs/converging-review.md` states the new definition, which callers pass which documents, and loses the
settled-marker sentence.

**The pull-request description** carries, each time it is written — the first pass and every follow-up
round — exactly one line naming the design's change since approval when the helper's `diff` over the
design says `changed`; no such line when it says `unchanged`; and when it could not compute, one line saying
the change since approval could not be computed and why, because no line at all would read as unchanged.
The line links the design document's own entry in the review surface's comparison of the freeze commit with
the branch head, so it points at the design's change rather than at the whole branch; where the surface
cannot address one file's entry, the link is the comparison and the line names the design's path at the
branch head. The rule lives in `docs/workflow.md` § PR title + body shape, which Step 12 and the follow-up
round already point at.

## The fix plan

The disposition `redline: <type> — <what shipped instead>` becomes `correction: <what shipped instead>`; the
type vocabulary existed only for the log row and goes with it. In `skills/task/scripts/check-fix-plan.sh`:

- **The accounting arm keeps its decision token `arma-unaccounted`**, and its verdict label becomes
  `correction-accounting`. A `fix` row whose Arm A anchor is a sentence of the task's own design is
  accounted for by a `correction:` row for the same finding; one whose anchor is a spec sentence by nothing
  short of `amendment: spec`, which routes the round. **[REDLINE S8.3]**
- **A `correction:` row whose Arm A anchor is in another plan's design routes the round** as
  `ROUTE-DESIGN` with the reason `design-amendment`. The task's own design is the one the progress file's
  `**Design:**` field names, compared by spec base so its archived path matches too. **[REDLINE S8.2]**
- **The `applied` verb loses the `redline-undelivered` arm**; `unplanned-file` is its one finding.
- **`IGNORE_GLOB_REDLINE` [ignore-glob-redline] goes from `skills/task/scripts/check-fix-plan.sh`**, with its
  comment; the reason the design suffix is excluded from the unplanned-file arm now names the correction
  pass where it named the marking pass. **[REDLINE R1.3]**

The round's order changes with it. The correction runs **after** the apply and the post-apply micro-loop and
before the round's review, because a correction describes code that exists: written first, it is false one
re-fix later, which is the ticket's complaint about the marker. The orchestrator confirms the correction
landed as it confirms every agent write, and the Arm A closing gate re-reads the cited sentence before the
finding is marked `✅ Fixed (corrected in place)`.

## The record of deliberate absence

`scripts/deliberate-absence.sh` holds the `RETAINED` assignment, moved verbatim with its id, and a header
naming every reader. It is parsed as text and sourced by no entry point once the fold's gate is gone. Its
shell assignment of plan headings is what `defines_element` [defines-element] in
`scripts/check-plan-invariants-refusal.py` reads as an element-defining locus, so it joins the
protected-page table on `docs/plan-invariants.md` and `PROTECTED` [protected] in
`hooks/lib/plan-invariants-guard.sh`, and the element derivation reads `RETAINED` from it. The
list now means what the archive listing extracts from every completed spec and what a spec collapsed by the
retired fold still carries; collapsed specs stay in the archive unmigrated, and every reader keeps reading
both shapes.

`scripts/check-redline.sh` keeps `specform` and `suppression`. With `RETAINED` and the fold's residue list
gone it carries no element-defining locus, so it leaves the protected-page table and joins the near misses:
its criterion-content rule is composition, while the refusal asks only about headings and element names,
which that rule is not. Its comments are rewritten without a backticked plan heading beside a presence
word, so the coverage sweep agrees in both directions.

## What is removed, and what stays

| Removed | Where it lived |
|---|---|
| the closing-fold workflow | `skills/redline-fold/` |
| the marker contract | `docs/redline-marking.md` |
| the fold-only verbs `pending` [do-pending], `folded` [do-folded], `revision` and `paired` [do-paired], with `section_of` [section-of] and the residue and revision constants | `scripts/check-redline.sh` |
| the fold's prohibition arm, which read the residue headings | `scripts/check-plan-invariants.py`, in the derivation route that reads the enforcer's data |
| the merge-time refusal and its allowed tool | `skills/pr-merged/SKILL.md` |
| the `redline:` disposition, its accounting and delivery arms, and the log's ignore glob | `skills/task/scripts/check-fix-plan.sh` and the fix-plan pages |
| the marker strip in the fingerprint | `scripts/review-ledger.sh` |
| the marker normalisation — no archived plan carries a marker, a search of `ai-docs/plans/done/` for the marker's key shape returning nothing on 2026-10-28 | `scripts/check-plan-links.py` and `docs/declared-links.md` |
| the Redline sync group, and every member note naming it | `docs/propagation.md` |
| the redline log's format and the committed-exception paragraph | `docs/templates/progress-format.md` |
| the closing fold's skill entry | `docs/claude-tools-hierarchy.md`, the `SKILLS` inventory in `scripts/test-install-smoke.sh`, `README.md` |

**The propagation reminder's arms need no change.** `hooks/hooks.json` carries no arm for the Redline group — a search of it
for the group's name returned nothing on 2026-10-28 — because its propagation reminder fires on path classes, and every class a Redline member occupied — agent, method-page, skill and
script paths — is named by another group's row. The propagation-arms member of the check list derives the
classes from the edited table and confirms none was lost.

**What stays, and why.**

- `specform` and `suppression` in `scripts/check-redline.sh`. The criterion-content rule is out of scope.
  `do_suppression` [do-suppression] in `scripts/check-redline.sh` was re-read for this task: it enforces where the whole-repository
  review takes suppression authority from — the spec's record of deliberate absence — and names neither the
  fold nor its log, so it is unchanged.
- **Arm A's sentence about completed plans**, at each of its sites — `agents/self-review.md`,
  `skills/bugfix/SKILL.md`, `skills/project-review/SKILL.md` and `docs/workflow.md` § Spec-Amendment group.
  Re-read: it names neither the fold nor its log and stays true.
- The reasons `agents/design.md` gave under *The redline fold* for keeping the frozen design's sections go
  with that section. The one other readers lean on — a design's use cases reach every whole-repository
  review through the archive listing — stays true because the design is archived whole, and it already
  stands as the sixth principle's reason.
- **Readers of the collapsed shape**: `is_folded()` [is-folded] and `folded_spec()` [folded-spec] in
  `scripts/check-plan-convergence-holding.py`, the declared-link check's skip of a collapsed spec, the
  archive listing's absent-section handling, and the progress-file cleanup's lookup by the `**Branch:**`
  field. Old plans keep their shape.
- **Readers of history**: `scripts/human-findings.sh` keeps recognising a fold commit by the log it deleted,
  because pull requests merged before this change still carry one. Its description in
  `skills/inspect/SKILL.md` stays true of those pull requests and is left as it is; the one in `README.md`,
  rewritten in subtask 7 anyway, says the excluded fold commits predate this change.
- `scripts/ref-current.sh` stays, with `scripts/check-release.sh` as its one caller; its comment says so.
- **The declared-link record is archived with the plan**, moved at Step 12 as today. A later amendment of an
  archived plan runs the declared-link check over the archived pair, and two archived records are already
  read that way; deleting it at the closing step would turn every such run into a record declaring nothing.
  Settled in the task's own pull request, untouched after the merge.

## The base principles

The principles that change on `docs/plan-invariants.md` are the numbered items the spec names, each changed
together with its pinned copy in `PINNED` [pinned-principles] in `scripts/check-plan-invariants.py` in the
same commit, so the check's principle-integrity leg keeps catching a one-sided edit. The ordinals below are
the page's own item numbers, identifiers rather than quantities, and they stay as they are, so no reference
to the tenth principle moves.

- **4.** **The design is frozen by a commit at the design-review GO verdict and corrected in place after
  it.** A divergence that does not break the agreed approach is corrected in the item it falsifies, after
  the code it describes exists and only as far as the shipped work needs; one that breaks the approach is a
  new design, a new review and a new freeze. *Because the change since the freeze is then computed from the
  repository rather than reported by the party that made it, so every edit to the agreed plan, an unintended
  one included, reaches the review that rules on it.*
- **5.** **A changed requirement goes to the spec; a changed artefact goes to the design; nothing is recorded
  in both places.** *Because two records of one fact is the drift the mechanism exists to reduce.*
- **7.** **A plan is archived as it stands, and nothing rewrites it on its task's behalf after the merge.**
  The spec keeps every section and the design keeps every section, its process sections included.
  *Because a pass after the merge lands as a change of its own with a review of its own, and until it
  lands the archive says one thing while the record of its correction says another.*
- **10.** The rule is unchanged. The reason becomes: *Because a spec narrowed to match its design states
  the design's detail a second time and costs an approval and a fresh planning round, and the archived spec
  then keeps that detail for good, so every later correction of the design leaves the spec to be amended
  with it.*

The same page's prose follows: the paragraph on the record of deliberate absence loses the fold's removal
list and says what the three headings now are; the protected-page table and the near-miss table change as
§ The record of deliberate absence states; `agents/design.md`'s row counts the loci it still carries; and
every sentence counting the protected pages follows the table.

## Sync groups

The Redline group is removed. A **Freeze group** replaces it, anchored on `docs/workflow.md` § The plan
freeze, because the mechanism is again spread over parties that share almost no words — the trailer's name
is the only token a sweep would find in all of them:

| Member | Its vocabulary |
|---|---|
| `docs/workflow.md` § The plan freeze | what a freeze is, when it is taken, the three outcomes, the pull-request line |
| `scripts/plan-freeze.sh` | the trailer's spelling, how a freeze is found, the verbs and exit codes |
| `scripts/review-ledger.sh` and `docs/converging-review.md` | the digest over the frozen plan and who passes what |
| `agents/self-review.md` | the ruling on each change |
| `agents/design-review.md`, its Design-Amendment re-entry paragraph | the ruling on what a re-entry GO's freeze absorbs |
| `agents/design.md` § Correcting the design in place | who corrects, when, and the admission rule |
| `skills/task/SKILL.md` Steps 7, 8 and 11, and the two amendment recipes on `skills/task/reference.md` | where a freeze is taken and where a correction runs |

The Plan-Invariants group's member list swaps the fold's skill and `scripts/check-redline.sh` for the new
data file; the Plan-Convergence group drops the fold's skill; every cross-membership note naming *Redline*
is rewritten. The Scouted-Fix group keeps its members, whose text changes in subtask 4.

## Size budget

Sizes are character counts measured on 2026-10-28 — `wc -m` on a whole file, and on a section or passage
cut out first where one is named. The two thresholds are handed down: the method's size rule sets the
35,000-character early warning, and the ticket sets the no-growth limit on the task workflow file and the
self-review contract.

- **`ai-docs/context.md`** measured 34,714 characters with `wc -m`, and its Redline log section measured
  2,143 with `wc -m` on the section cut out; that section is removed. The slack for everything this task
  adds to the file — a compact Plan freeze entry and the wording changes elsewhere in it — is derived as
  35,000 - (34,714 - 2,143) = 2,429 characters.
- **`skills/task/SKILL.md`** measured 33,341 characters with `wc -m` and must end no larger. The passages this
  design rewrites there — Step 8's divergence bullet, Step 11's non-breaking row, the scouted sequence's
  marking-beat lines, the Spec Amendment no-branch paragraph and the trigger note beneath it — measured
  870, 376, 706, 802 and 543 characters with `wc -m` on each passage. The freeze at the GO and Step 8's
  freeze check are paid for out of them, with detail on the workflow page's new section.
- **`agents/self-review.md`** measured 33,130 characters with `wc -m` and must end no larger. The passages it
  loses or rewrites measured, by a character count of each passage, 49 for the marker carve-out clause in
  step 2, 254 for the settled-marker sentences in step 5, 746 for the non-breaking paragraph, and 512 for
  the paragraph explaining that the routing now runs against a fix plan, which restates the scouted-fix
  page and keeps one obligation sentence. The ruling, the new non-breaking paragraph and that one sentence
  fit inside what they free.
- **`docs/agents-method.md`** measured 33,558 characters with `wc -m`; the commit-body rule admitting the
  freeze trailer is a clause inside a headroom derived as 35,000 - 33,558 = 1,442 characters.
- **`agents/design.md`** measured 23,600 characters with `wc -m`, and the two sections it loses measured 6,722
  together with `wc -m` on the cut-out span, far more than the new section and the admission rule take.
- **`agents/design-review.md`** measured 19,187 characters with `wc -m`; the re-entry ruling and the marker
  sentence's removal sit inside a headroom derived as 35,000 - 19,187 = 15,813 characters.

## This task's own run

**This task runs on the installed flow from start to end.** `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin
cache's install path for version 0.1.62 — the `installPath` read with `cat` from
`~/.claude/plugins/installed_plugins.json` on 2026-10-28 — and not to this working tree. Every workflow,
agent, hook and flow gate of this task is that copy's, follow-up rounds on its pull request included; this
repository's `.claude/settings.json` and `.claude/settings.local.json` carry no `hooks` key, read with `jq`
on 2026-10-28. The working-tree text that runs is the project's own: the profile; the check commands, as
item 2 states; and the method page `docs/agents-method.md`, which this repository's `CLAUDE.md` loads by a
repository-relative link, so the session reads from the working tree the commit-body clause subtask 3
edits there — a clause that only admits a trailer the installed flow never writes. No freeze is taken for
this plan: no installed party reads one. The first run of the new flow is the next task, once the installed copy is
updated to the release this pull request carries, and the spec's deferred measurement is taken there.

1. **Divergences take the installed route**: a marker and a log row under the correction mode the installed
   workflow asks for once per task, or the installed amendment route for one that breaks the approach. The
   log is `ai-docs/plans/2026-10-28-retire-closing-fold.redline.md`, and the installed Step 12 moves it into
   the archive with the plan.
2. **Two sets of scripts, kept apart.** The installed copy's scripts are what the flow's own gates run — the
   fix-plan gate, the marker-pairing check, the review ledger, the tree digest, the convergence and
   declared-link checks of the design author's exit, and the closing fold's gates — and they still know the
   marker, the log and the `redline:` disposition. The working tree's scripts, which this task edits, are
   what the project's check commands run: the touched-scope selection inside a loop and the full check list
   at the closing step, both resolved through this repository's profile to repository-relative paths. The
   delivery gates install the working tree into a throwaway configuration directory and leave the installed
   copy alone. So a working-tree script that no longer knows the marker or the log never judges this task's
   flow, and an installed gate never judges this task's edited scripts.
3. **A log, or a marker in the design, present at the closing step is harmless to the working tree's
   checks.** The full check list runs after the installed Step 12 has moved the log beside the plan in the
   archive. After Group C no working-tree script parses a log or strips a marker; the scripts that open
   those files read them as plain text. The fold's verbs were never members — `scripts/check-redline.sh`
   takes arguments and stands in `EXEMPT_CHECKS` [exempt-checks] in `scripts/run-checks.sh` — and they are
   gone after subtask 6. `scripts/human-findings.sh` still matches a log's path among a pull request's
   removed files to recognise a fold commit, as § What is removed, and what stays keeps it on purpose, and
   opens no log. Every member that sees the log or the design reads it as it reads any other file:
   `EXCLUDED_SURFACES` [excluded-surfaces] in `scripts/check-plan-invariants.py` accounts for every path
   under `ai-docs/plans/` as a plan document; `scripts/plan-archive.sh` lists the archived spec and design
   files, this task's design and any marker in it included, as text, and never opens the log; the purity
   check reads both as tracked text; and the reference check reads them, with every other markdown file on
   disk — `md_files` [md-files] in `scripts/check-references.sh` finds them without consulting the index,
   so this task's gitignored progress file is read too — for links and plugin-root paths. That is the one
   condition: a plugin-root path to a page this task deletes, which installed text links freely, is
   reported in any of those files and is rewritten as a repository path.
4. **The end, in one of two branches, both before the merge.** With no log, the plan reaches the archive
   full at Step 12 and nothing is owed. With a log, the Step 12 hand-back says in its first line that the
   merge waits for the closing fold; on the user's word that the pull request is approved, the installed
   fold runs in its early window on this same open pull request — the rows applied, the spec collapsed to
   its record of deliberate absence, the log removed — and its commit joins the pull request. Either way
   nothing lands after the merge, and the installed merge-time cleanup, which refuses only on a log on the
   default branch, finds none.
5. **This plan's archived shape, against AC2 and AC14.** Without a log both hold as written. With one, the
   fold collapses this spec and the plan is the last the retired flow archives, which is read as consistent
   with the spec rather than as an exception to it. AC2 governs tasks the shipped flow runs, and the spec
   places the first such run after this change: its deferred measurement "can only be taken on a task run
   after this change ships". A plan the retired flow archives is the class AC14 and the out-of-scope line on
   migrating archived plans govern — it keeps whichever shape that flow gave it, is not migrated, and is read
   by every reader of the archive, all of which read both shapes and keep reading them after subtask 1. The
   fold's commit lands before the merge, so AC1 and AC2's bar on a rewrite after the merge hold in both
   branches.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | **Decouple the record of deliberate absence, behaviour unchanged.** Create the data file holding `RETAINED` moved verbatim with its id and a header naming every reader. Re-point every reader of the constant at it, the verifications' extractions included: the fold gate's `folded` verb sources it; `retained_sections()` through `RETAINED_SOURCE`; the element derivation's read of `RETAINED`, split from its read of the residue headings, which stays on `scripts/check-redline.sh` until subtask 6; the archive listing's input path, its variable renamed to say what it is; and each verification's extraction that parses the list out of `scripts/check-redline.sh`. The subtask is done only when each of those extractions comes back non-empty from the new file, because one left on the old file reads nothing once the list has moved. Enter the file in the protected-page table, in `PROTECTED`, and in the list of files the plan-invariants check reads for their data; rewrite `scripts/check-redline.sh`'s protected row to the two lists it still carries; re-key the profile's touched-scope mapping row from `scripts/check-redline.sh` to the new file; add the file to the Plan-Invariants group's members; reword the holding payload's comments that call the list the fold's own | `scripts/deliberate-absence.sh` *(new)*, `scripts/check-redline.sh`, `scripts/check-plan-invariants.py`, `scripts/check-plan-convergence-holding.py`, `scripts/plan-archive.sh`, `hooks/lib/plan-invariants-guard.sh`, `docs/plan-invariants.md`, `docs/propagation.md`, `AGENTS.md` | AC14 | — |
| 2 | **The freeze helper and the digest over the frozen plan.** Create the helper with its three verbs and outcomes as § The freeze states, and the profile entries AGENTS.md § Build & Test requires of a new script. In the ledger: the `--frozen` option on both verbs, the stripping removed, a frozen document it cannot resolve a could-not-run. Rewrite `docs/converging-review.md`'s plan-digest definition, its full-reset paragraph with which callers pass which documents, and remove its settled-marker sentence | `scripts/plan-freeze.sh` *(new)*, `scripts/review-ledger.sh`, `docs/converging-review.md`, `AGENTS.md` | AC6, AC9, AC11 | — |
| 3 | **The task flow and its review.** `skills/task/SKILL.md`: Step 7's GO — notes worked in by the design author, then the freeze surfaced once, Step 8 waiting for it; the Design Amendment paragraph — the in-place correction in the forbidden-deviation clause, a new freeze on GO; the Spec Amendment paragraphs — the no-branch takes no review round and no freeze and corrects false design items directly, and the trigger note names the in-place correction; Step 8's first action checks the freeze and its divergence bullet states the occasion table's first row and the breaking route; Step 11's arm table, the scouted sequence with the correction beat after the micro-loop, the micro-loop's single `applied` token, the disposition vocabulary and the write-landed act; Step 12's move list. `skills/task/reference.md`: both amendment recipes — a new freeze on each GO, the re-entry design review's prompt carrying the helper's `diff` over the design since the previous freeze, the fifth act always direct and its per-workflow table removed — the Step 8 template's `**base_commit:**` taken after the freeze, the Step 12 failure route's move-back list, the forbidden list and the gate checklist. `docs/workflow.md`: in the Spec-Amendment group section, the non-breaking route and its boundary paragraph as this design's section on correcting in place states them; the implementation-step section renamed for what it now says; a new section, *The plan freeze*, holding what this design's section on the freeze states; the closing paragraph of the section on a spec amendment re-deriving the design; the closing-fold sentence in the section on the ticket and the description at the end of an iteration; in the section on the title and body shape, the freeze-change line and the workflow-artefacts bullet, which the freeze makes false; the post-push table's fix and review rows. `agents/self-review.md`: the carve-out list, the ruling at its design step, the non-breaking paragraph, and the trims the size budget below names. `skills/bugfix/SKILL.md` Step 5: a bug fix whose trace carries `**parent_skill:**` takes the enclosing round's in-place correction for its task's own design. `docs/agents-method.md`: the commit-body rule admits the freeze trailer, and the co-authored-by refusal in `hooks/hooks.json`, which restates that rule when it refuses, admits it in the same words. `docs/propagation.md`: the Redline group out, the Freeze group in, the cross-membership notes | `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/workflow.md`, `agents/self-review.md`, `skills/bugfix/SKILL.md`, `docs/agents-method.md`, `hooks/hooks.json`, `docs/propagation.md` | AC2, AC3, AC5, AC7, AC8, AC9, AC10, AC15, AC16 | 2 |
| 4 | **The fix plan's correction disposition.** In the gate, everything § The fix plan lists, with its header comments re-read. `agents/fix-scout.md`: the vocabulary row and the beside-or-alone paragraph for `correction:`, carrying the admission rule and naming the spec and another plan's design as amendment routes. `agents/fix-apply.md`: the row. `docs/scouted-fix-round.md`: the vocabulary in the plan beat, the `arma-unaccounted` row, the marking beat replaced by the correction beat after the micro-loop with its spawn prompt, the `applied` paragraph, the review-fix narrative's non-breaking bullet and its status, and the rationale for the order. `docs/templates/progress-format.md`: the example row and the vocabulary bullet, the committed-exception paragraph at its head, the redline-log sentences and the section example in the section on anchors and measurements going stale, the redline-log section removed, the record of excused findings named by its own construction rather than by the redline log's, and both records' lifecycle — kept in the archive. `docs/workflow.md`: the path-class section heading and body for the classes that remain, with the link to it from `docs/scouted-fix-round.md` | `skills/task/scripts/check-fix-plan.sh`, `agents/fix-scout.md`, `agents/fix-apply.md`, `docs/scouted-fix-round.md`, `docs/templates/progress-format.md`, `docs/workflow.md` | AC3, AC4, AC12, AC15 | 3 |
| 5 | **The design author's contract and the principles.** `agents/design.md`: the sections *Redline marking* and *The redline fold* removed; the section *Correcting the design in place* added as this design states it; the admission rule among its rules; the exit-check sentence covering every pass; the pre-approval bullet saying that after the freeze a correction is the in-place mode and that neither carries an account of earlier wording. `docs/declared-links.md` § When it runs: the opening line loses its bound at the closing fold, the marking-pass row becomes the in-place correction pass, and the closing-fold paragraph goes. `docs/declared-links.md` § Where a report leads: the `moved` row whose unchanged end is the design corrects a false design end directly, with no marker and no log; the first bullet loses its exception for the marking pass of an amendment that keeps the approach; and the bullet saying an ordinary marking pass moves no link is rewritten for the in-place correction pass, which rewrites every row whose design end it changed. `docs/redline-marking.md` deleted last, every page that linked it having been rewritten — in subtasks 3 and 4, and earlier in this subtask `agents/design.md` § Redline marking and `docs/declared-links.md` § When it runs. `agents/design-review.md`: the marker sentence in the revision-account bullet, and the Design-Amendment re-entry paragraph — entered from either amendment recipe, it rules on each hunk of the change since the previous freeze outside the sections the amendment changed, as § The freeze states, before its GO. Principles 4, 5, 7 and 10 on `docs/plan-invariants.md` and in `PINNED`, in one commit, and the page's row for `agents/design.md` | `agents/design.md`, `docs/redline-marking.md` *(deleted)*, `agents/design-review.md`, `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `docs/declared-links.md` | AC3, AC4, AC12, AC13 | 3, 4 |
| 6 | **Remove the fold and the checks whose only subject it was.** Delete the fold's skill. In `scripts/check-redline.sh`, everything § What is removed lists, the usage and header rewritten for the two remaining verbs, and the comments kept clear of a plan heading beside a presence word — the comments on the heading and emphasis cases of `sf_is_instrument` among them, each reworded to name the token shape it skips rather than the fold or the marker. The docstring of `excuse_path()` in `scripts/check-plan-convergence.py` names the record's construction directly rather than as the correction log's. In the plan-invariants check, the prohibition arm and the residue read, and `scripts/check-redline.sh` out of the list of files read for data. On `docs/plan-invariants.md`: the record-of-absence paragraph, both tables and the sentences counting protected pages; `PROTECTED` follows. `skills/pr-merged/SKILL.md`: the refusal and its allowed tool removed, step 3's wording about the fold; the cleanup script's matching comment. The marker normalisation in the declared-link check and its sentence on `docs/declared-links.md`, with the sentence there saying where the collapsed-spec sections are borrowed from. `scripts/ref-current.sh`'s caller comment. The skill out of `docs/claude-tools-hierarchy.md` and out of the `SKILLS` inventory in `scripts/test-install-smoke.sh`. The Plan-Invariants and Plan-Convergence groups' member lists **[REDLINE S8.1]** **[REDLINE S8.4]** **[REDLINE S8.5]** | `skills/redline-fold/SKILL.md` *(deleted)*, `scripts/check-redline.sh`, `scripts/check-plan-convergence.py`, `scripts/check-plan-invariants.py`, `docs/plan-invariants.md`, `hooks/lib/plan-invariants-guard.sh`, `skills/pr-merged/SKILL.md`, `skills/pr-merged/scripts/cleanup-progress.sh`, `scripts/check-plan-links.py`, `docs/declared-links.md`, `scripts/ref-current.sh`, `docs/claude-tools-hierarchy.md`, `scripts/test-install-smoke.sh`, `docs/propagation.md` | AC1, AC12, AC14 | 1, 5 |
| 7 | **Profile, README and release.** `ai-docs/context.md`: the Redline log section removed; the Fix plan section's disposition sentence and its `applied` findings; the Declared links section's invariant; the Plan invariants section's page counts; the Layout row's `ref-current.sh` sentence; a compact Plan freeze entry, all within the slack the size budget below derives. `AGENTS.md` re-read for any statement of a removed verb. `README.md`: the closing-fold command row removed; the task-flow diagram with the freeze after the GO's notes, the divergence edge corrected in place, and the fold node removed; the Step 11 diagram with the correction after the micro-loop and the paragraph under it; the human-findings sentence's mention of the fold. The plugin's patch version **[REDLINE S8.6]** **[REDLINE S8.7]** | `ai-docs/context.md`, `AGENTS.md`, `README.md`, `.claude-plugin/plugin.json` | AC12, AC16 | 6 |

## Handoff plan

`M = 7`: two groups of three and a terminal group of one.

- **Group A:** subtasks 1–3 — the decoupling, the freeze helper and the flow rewrite. Enter it through
  `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Handoff after Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
  Parent /task resumes in Group B with fresh context.
- **Group B:** subtasks 4–6 — the fix plan, the design author's contract and the removal.
- **Handoff after Group B:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
  Parent /task resumes in Group C with fresh context.
- **Group C:** subtask 7 — terminal group (1 subtask; within the 1..3 range): the profile, the README and the
  release.

## Risks

- **A branch in flight at upgrade carries markers and a log and has no freeze.** The new version cannot fold
  it, and its review would report no freeze. Mitigation: no such branch exists in this repository —
  `git ls-files` lists no `*.redline.md` on 2026-10-28, and this task's own branch folds any log it
  accumulates before its merge (§ This task's own run) — and a consuming project's branch is brought across
  once by a design-author pass applying the log's rows in place, removing the markers and the log, then a
  freeze commit. The pull-request description says so for upgraders.
- **A freeze squashed into later commits.** An interactive rebase that squashes the freeze with the work
  after it makes the freeze carry the corrected design, and the change since approval reads unchanged.
  Mitigation: the freeze is its own commit, merges happen in the review surface's UI, and nothing in the
  workflow squashes a branch.
- **An older git without the trailer placeholder.** Mitigation: the helper reports could-not-compute, which
  every reader reports and none reads as unchanged; the review's ruling then raises it as a finding.
- **The design author's edits corrupting unrelated text.** The ticket cites research measuring silent
  corruption in long model edits. Mitigation: the computed change shows every edited line, and the
  review's third outcome makes an unneeded edit a `major` finding.
- **Spec sentences now cost a user question where a log row was enough.** Mitigation: Arm A raises a spec
  sentence only for a genuine conflict under the base principles, and the tenth principle's breadth test is
  what keeps that class small; the spec is archived whole, so a false sentence would otherwise stay false.
- **The fingerprint's live half moves on any spec edit.** Accepted: the spec has one writer and changes only
  through an approved amendment, which is exactly the event that must reset the next round.
- **Text that disagrees between subtasks, across groups** — Step 11 naming `correction:` in subtask 3, in
  Group A, while the gate admits it only from subtask 4, in Group B; principles 4, 5, 7 and 10 prescribing
  the marker, the log and the fold until subtask 5; `ai-docs/context.md` and `README.md` describing the fold
  until subtask 7. Mitigation: the tree is consistent after Group C; every workflow, agent, hook and flow
  gate that runs this task is the installed copy's, so none of them reads the working tree's flow text
  (§ This task's own run); of the working-tree text that does run, the check commands and the profile's
  selection of them change with the scripts they run, and the method page's one edited clause only admits
  a trailer the installed flow never writes; and the review and the full check list run after Group C.
- **The coverage sweep's two directions for the moved list.** If `scripts/check-redline.sh` keeps a plan
  heading beside a presence word it is reported as an unguarded route; if the data file left the table it
  would be the same. Mitigation: § The record of deliberate absence; the plan-invariants member reports
  either direction.
- **Ids on deleted entities.** `[do-pending]`, `[do-folded]`, `[do-paired]`, `[section-of]` and
  `[ignore-glob-redline]` disappear with their entities, so an archived plan citing one loses its pair.
  Accepted: the pairing class reports and holds nothing, and archived plans are history. `[retained-list]`
  moves with `RETAINED`, so its pairs survive.
- **Positional baseline rows for removed code** absorb nothing once the code is gone, and new text could
  arrive with a position the baseline does not account for. Mitigation: new text names entities, and the
  reference class only reports.

## Use cases

- `scripts/plan-freeze.sh` — `find`: Step 8's first action confirms the plan has a freeze before any code is
  written; the orchestrator reads the freeze commit for the pull-request line. `show`: the ledger hashes the
  spec and the design as frozen. `diff`: every review round of the task, follow-up rounds included, reads
  the change it rules on; the re-entry design review after an amendment reads the change since the
  previous freeze before its GO; the orchestrator decides whether the pull-request line is written, and
  which of its two forms; a follow-up round reads the archived plan's change across its move into the
  archive.
- The freeze commit — identifies the agreed plan for the helper; taken at every design-review GO with the
  user's consent; read again after a rebase, unchanged.
- `scripts/review-ledger.sh` `--frozen` — the task's rounds and its follow-up rounds pass it so an in-place
  correction keeps the next round narrow while a new freeze resets it; `/bugfix` and `/project-review`
  never pass it.
- `scripts/deliberate-absence.sh` — the archive listing extracts its headings from every completed spec;
  the convergence check recognises a collapsed spec by them; the declared-link check skips a collapsed
  spec's links through the same recognition; the plan-invariants derivation reads its headings as spec
  elements; the edit-time refusal guards it as a protected page.
- The `correction:` disposition — the scout writes it for a non-breaking divergence from the task's own
  design; the gate accounts a `fix` row with it and routes one naming another plan's design; the
  orchestrator spawns the correction pass from it after the micro-loop; the fix agent skips it.
- The design author's in-place correction mode — Step 8 after each group with recorded divergences; Step 11
  after the micro-loop; a follow-up round after its fix; a nested bug fix inside any of these; the fifth
  act of a spec amendment that keeps the approach, in every workflow.
- The review's ruling on the computed change — Step 10 rounds and follow-up rounds: accepts a correction
  that describes what shipped, raises the amendment trigger on one that breaks the approach, and raises a
  `major` finding on an edit nothing needed or on a change it could not compute.
- The re-entry design review's ruling — after either amendment recipe: accepts an earlier in-place
  correction that describes what shipped, and raises a `major` issue on one that breaks the approach or
  that nothing needed, before the GO whose freeze would absorb it.
- The pull-request line — written on the first pass and after every follow-up round: links the design's
  entry in the change since approval when the design changed, says it could not be computed when it could not, and is absent
  when the design is unchanged.
- The Freeze sync group — the propagation reminder's sweep reaches every party of the mechanism when one of
  them changes.

## Open questions

- None.
