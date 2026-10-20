# Design: Design contract rework — what a plan document must carry, and what checks it

**Ticket:** GH-128 **Date:** 2026-10-18 **Spec:**
ai-docs/plans/2026-10-16-design-contract-rework.spec.md

## Approach

The spec asks for five rules and four mechanisms. The rules say what a plan document may contain: a
number names its own provenance, a reference names an entity rather than a position, an open
question carries a price, the closing pass stops re-authoring, and a comment an instrument reads is
never swept. The mechanisms are a convergence check carrying six deterministic classes, three of
which hold a plan while the other three report, a route to excuse one finding, a judgement class
held to a stated standard, and a bidirectional pairing between a statement and the source entity it
leans on. **[REDLINE S8.5]**

The shape of the solution is the one this repository already runs for the base principles: **each
rule is stated once on the surface that owns it, restated in its own words only where a party must
act on it, and enforced by a deterministic check that derives its data from the stating surface
rather than copying it.** Nothing here invents a mechanism shape. The pairing extends a keyed
bidirectional comparison that already ships; the excuse route copies the acceptance act's one
property that matters — it prints what it is about to take in; the baseline record copies the
statement inventory's; the check's wrapper copies the existing plan-document gate's verb-and-path
shape, including its exemption from the gate runner.

**What this plan does NOT contain, because it already shipped on this branch.** The branch carries
one commit, and reading it against its parent shows three pieces of the spec's own scope already in
the tree, so planning them again would be planning work that exists:

- **The provenance obligation is already in the base principle.** The knowability principle now
  carries the second half the spec's first item asks for — a stated number names which kind it is
  and how it was obtained — together with its commentary, and the verification's pinned copy of
  that sentence agrees. Measured by reading the principle and the pinned copy, and by `git diff
  6e60638 a37a265 -- docs/plan-invariants.md`, which shows the sentence arriving. What is left of
  that item is its restatement on the two author surfaces and the reviewer surface, where no
  sentence mentions provenance at all — measured with a search for `provenance`, `threshold the
  task` and `derived in place` across `agents/`, `docs/` and `skills/`, which returns the
  principles page and nothing else that states the obligation.
- **The gate standard for a judgement class is already stated**, in the method half, on
  `docs/gate-outcomes.md`: the three outcomes with a could-not-run that is not a pass, and beside
  them the five obligations binding a check whose judgement a model makes — report and rule on
  nothing, a demonstration per class, agreement under repetition measured and printed, and never
  the only check standing. So the spec's fourth item needs no new statement surface; the judgement
  reader this plan creates points at that page and restates none of it.
- **The removal of file-and-line anchoring from the session-start page**, which now carries the
  token nowhere, so the second item's reach over that surface is already closed.

### The measured ground this plan stands on

Every figure below is a measurement of something that already exists, taken with the command named
beside it before any subtask of this plan ran — so these are the measurements the plan was built
against and not claims about the tree it leaves behind. No figure here is a measurement of anything
this plan builds.

- **The protected page set is seven paths**, read from the `PROTECTED` assignment [protected] in
  `hooks/lib/plan-invariants-guard.sh` (`grep 'PROTECTED='` and the entries it opens). **Every one
  of the seven is edited by this plan** — the two writer contracts, the review contract, the
  closing-pass skill, the task skill and its reference sibling, and the plan-document gate — and
  the guarded comparison record is written by the closing subtask's acceptance act. The edit-time
  refusal therefore fires on nearly every subtask here, which makes its authorisation route a
  planning input rather than a footnote; it is settled under *The refusal reaches almost
  everything here* below.
- **The verification payload has one line of room.** `wc -l scripts/check-plan-invariants.py`
reports 999
  lines; `docs/code-style.md` refuses a source file above one thousand and already calls the band from
  eight hundred to a thousand hard-ish, requiring a justification in the pull request. The payload's own
  header spells its ceiling as a hard thousand-line limit and records that an earlier leg was moved to a
  sibling for exactly that reason, so the repository's own reading of the figure is the stricter
  one. Either
  way the new classes cannot be legs of it; they need their own wrapper and payload. **[REDLINE R1.2]**
- **The gate runner already exempts a check that takes a path argument**, and says why: a member
  is
invoked
  with no arguments, every verb of the plan-document gate requires one, so a documented member would
  report
  could-not-run on every run. Read from `EXEMPT_CHECKS` [exempt-checks] and the comment above it in
  `scripts/run-checks.sh`.
  The new check has the same shape and joins that exemption; its absence from both lists would
  otherwise be
  reported by the runner's own stray-check arm.
- **The live test for protected-page membership has exactly three shapes**, read from
`defines_element` [defines-element] in
  `scripts/check-plan-invariants-refusal.py`: a fenced markdown block whose level-two headings are
  element
  tokens; a shell-style assignment one of whose entries is an element token; and any line carrying a
  backticked element token together with a presence, absence or retention word, where that word list
  is the
  payload's own `PRESENCE_SHAPE` [presence-shape] and a severity verdict alone is deliberately not
  enough. The scan skips
  the principles page and the guard by name, and one further class by filename pattern, which no path
  named in the decomposition matches. This is the test AC33 turns on, and it is why every new page
  and script below carries a stated constraint rather than a hope.
- **The element derivation's second route reads the review contract**, taking any line that
  carries
both a
  severity verdict and a backticked element-shaped token (the `SEVERITY` pattern [severity] and
  `ELEMENT_TOKEN` [element-token] in
  `scripts/check-plan-invariants.py`). Both the open-question wording and the convergence-class
  wording this
  plan adds to that contract name sections the record already carries, so the derivation yields
  pairs the
  record already holds and reports no arrival. A severity line that backticked any other section-shaped
  token would report one, which is a constraint on how those lines are written.
- **The committed comparison record is accounted for by name, and the exclusion beside it already
  admits committed measurement data by rule.** The corpus loop in
  `scripts/check-plan-invariants.py` skips the record path before any exclusion is consulted, and
  the repository-mechanics exclusion's stated membership rule covers "committed measurement data"
  while its path test names one fixtures subdirectory. So a second committed record needs the path
  test widened and no prose rewritten — and widening it cannot absorb the comparison record, which
  never reaches that test.
- **The principles page's heading states a count, and three surfaces outside the page restate
  it.** The verification payload splits the page's body on that heading's exact text and names it
  again in each of two cannot-run messages, and the project profile states the count in two
  sentences. Measured with a tree-wide search for `eight principles` and `The eight`, which also
  shows that **no markdown link anchors that heading**, so renaming it breaks no inbound
  reference.
- **Sizes, measured in one `wc -c` call** over the files this plan touches. Two are already inside
  the 35,000-character early-warning band that `docs/agents-method.md` defines below the
  40,000-character cap: `agents/self-review.md` at 35,267 and `skills/task/SKILL.md` at 35,427.
  Three more have almost no headroom, and the audit skill's reference sibling has the least of any
  file here: that sibling at 34,790, `docs/claude-tools-hierarchy.md` at 34,966 and
  `docs/workflow.md` at 34,930, each read against the band figure above. The rest have room:
  `agents/design.md` 30,811,
  `docs/plan-invariants.md` 19,478, `docs/templates/progress-format.md` 31,051,
  `skills/task/reference.md` 21,951, `agents/design-review.md` 14,354, `agents/review-findings.md`
  18,309, `docs/code-style.md` 16,827, `skills/ai-audit/SKILL.md` 14,333,
  `skills/context-reset/SKILL.md` 11,475, `skills/project-review/SKILL.md` 10,978,
  `skills/redline-fold/SKILL.md` 12,404, `scripts/check-redline.sh` 24,145,
  `hooks/lib/plan-invariants-guard.sh` 17,014.
- **Extraction candidates, each measured by slicing the section between its own heading and the
  next one** — `awk '/^### Project-defined Hooks/{f=1;print;next} /^## /{f=0} f'
  docs/claude-tools-hierarchy.md | wc -c` and the same form for the other two, so the figure is
  addressed by the heading and not by where it falls. That page's project-defined-hooks inventory
  is 28,520 bytes, which is four-fifths of the page, so moving the list leaves a short index
  behind. The validated-approaches section of `agents/self-review.md` is
  3,837 bytes and carries soft verbs rather than obligations. The review-fixes step of
  `skills/task/SKILL.md` is 9,095 bytes, while that round's procedure already lives on its own
  page. The largest section of the audit skill's reference sibling — its frontmatter-and-config
  improvement recommendations — is 7,523 bytes, and it carries recommendations rather than
  obligations, which is what makes it the candidate on the file with the least room. Each figure
  is a measurement of existing text; which block actually moves is settled per edit by the rule
  under *Size is planned work* below.
- **The marked-id pairing has a shipped precedent with three paid-for hazards**, in the
  `do_paired` function [do-paired] of `scripts/check-redline.sh`, which is the plan-document gate's
  `paired` verb: it extracts keys from both sides, compares by set equality
  rather than containment, reports each direction separately, filters by the key's shape on both
  sides so a document quoting the convention is not a marked document, and prints the pair count
  so two unmarked sides cannot agree vacuously. Read from that verb and its header.
- **A minimum-fragment length already exists in this repository**, `ARMA_QUOTE_MIN=24`
  [arma-quote-min] in
  `skills/task/scripts/check-fix-plan.sh`, used there to decide when a quoted fragment is long
  enough to identify a sentence. The isolation class borrows that constant rather than choosing
  one.

### Decision 1 — one new deterministic check, with its own wrapper

Six deterministic classes and the excuse route land in a new check,
`scripts/check-plan-convergence.sh` with a payload beside it, rather than as verbs of the existing
plan-document gate or legs of the existing verification. **[REDLINE R1.1]**

Three grounds, each measured above: the verification payload is at the hard line limit, so it has no
room; the plan-document gate is a protected page, so every edit to it costs an authorisation and it
already carries three kinds of element data, which is what put it in the protected set; and a check
that must stay OUT of the protected set cannot be grown inside one that is in it. The new check's
input is a spec-and-design pair plus, for the reference and pairing classes, the tracked tree — so
it takes path arguments and joins the gate runner's existing exemption for exactly that shape.

**Which classes HOLD a plan and which only report, settled here once so every enumeration can agree
with it.** Three hold: completeness, isolation and arithmetic. Those are the three the requirements
name as mechanical, and the criterion that makes a finding prevent a plan from being treated as
agreed names exactly them. The other three — provenance, reference and pairing — **report and do not
hold**, because their own criteria say a finding is reported and say nothing about holding, and a
design that made them refuse would be broadening a requirement on its own authority. The boundary
also falls where the cost does: the two classes whose input is the tracked tree can report something
no author of the plan under review put there, and a hold on those would let one unrelated commit
stop every later design review until somebody levelled a record or excused a finding in a plan it
has nothing to do with. **A reporting class's finding is never swallowed:** it travels in the
author's hand-back and into the review, where the reviewer may raise it by judgement, and — for a
position arriving in the tree — the levelling is owed by whoever committed the anchor, not by the
next plan's author.

**The excuse route stays open to any finding, and the excused count is printed SPLIT by whether the
class holds.** Open, because the requirement says a single finding can be excused and names no class
— closing it to the reporting classes would narrow a requirement, which is the same error as
broadening one in the other direction. Split, because the requirement that an excused finding stay
visible and counted exists so that a plan carrying excuses cannot read as clean, and one mixed
figure cannot say whether ten excuses waived ten holds or quieted ten reports: the first is a plan
proceeding over ten findings, the second is noise management. Two figures on a verdict line that
already carries several is the whole cost of telling those apart. The grants live in
`ai-docs/plans/<spec-base>.excuses.md`, which exists to keep the grounds for proceeding over a
finding beside the plan they were granted for, so they outlive the round that granted them and end
only when the closing pass retires the plan. Version control is what carries them to whoever
reviews the pull request; a round's own working notes never travel that far.

**The check holds no element token as a literal.** It needs the section names to LOCATE regions of
the document under examination — the rows the completeness class reads its objects from, the bullets
it reads their cases from — and it derives those names from the required-element record on the
principles page at run time, the way the propagation gate derives its path classes from the
propagation table. That is the isolation-correct form, and it also makes the second shape of the
membership test unreachable here: there is no assignment and no backticked element token to pair
with a presence word.

**What happens when a derived section is absent from the document under examination, because the
three possible answers are not equally safe.** The region is simply empty: the objects or cases it
would have supplied are absent from the sets the classes examine, the examined count for that set
prints as zero, and **nothing reports the section as absent**. A could-not-run would make the check
hold a plan on a missing section, and a finding naming the section would assert its presence — which
is precisely what would put this script in the protected set. A zero where a non-zero is expected is
still visible, because every class prints what it examined; it is read as a report about the run
rather than as a clean verdict. The substantive ground for the script's non-membership is the one
under *Keeping the protected set the same size* — it reports per-object gaps and never a missing
section, so it enforces no element — and the shape test is that rule's live approximation rather
than a second reason.

**The classes, what each reads, and whether it holds:**

| Class | What it reads | What it reports | Holds? |
|---|---|---|---|
| Provenance | every number literal in either plan document, with the sentence carrying it | a number whose sentence names neither its kind nor how it was obtained; and a number whose only possible origin is a measurement of the artefact the document describes, named with the heading or numbered item it sits under | reports |
| Arithmetic | every sentence stating a relation whose operands and result are all literal in it | the written value beside the computed one; a relation with a non-literal operand is counted as not-evaluable beside the verdict rather than silently skipped | **holds** |
| Completeness | the objects the document names, the criteria the spec states, and the section references the document makes | an object with no stated place, no reason, no stated behaviour or no stated cases; a criterion no row reaches; a section reference resolving to nothing | **holds** |
| Isolation | repeated literals within one plan document | the same number, or the same span at two or more sites where the span is at least as long as the minimum fragment length the fix-plan gate already enforces, naming both sites | **holds** |
| Reference | three shapes across the tracked tree, against the baseline record: a token joining a file to a digit run with a colon, optionally a digit range; a prose reference naming a line or a line range; and a command carrying a line-addressed slice of a file other than the one it is running from, which leaves out the house idiom of a script printing its own header as help | a position that outlives its task or that a reader may trust without re-deriving it | reports |
| Pairing | the ids a plan statement claims and the ids marked in source | a claimed id no mark carries; a marked id no statement claims; an id resolving to more than one of either | reports |

**How the completeness class identifies an object, and the one question it answers structurally.**
An object is an identifier the document presents in backticks as **a path marked `*(new)*` in the
decomposition row that creates it**, or as the leading item of a use-case bullet. The first half of
that test is what makes the set the objects the task BUILDS, which is the set the design contract's
use-case section is written for: an unmarked path is a file the task edits, and a document owing a
use-case list for every file it touches would owe one for work that creates no object. **The marking
is declarative, and that is the whole point of it.** A test asking whether the path exists yet
answers differently before and after the work, and the direction it moves loses a finding: a built
path with no use-case bullet is an object while the tree lacks it and stops being one the moment the
file appears, so a holding class would quietly stop holding on exactly the case the half exists to
catch — reachable whenever the full checklist is re-run against an amended plan after implementation
has begun. A marking in the cell is read from the cell, needs nothing from the filesystem, and
cannot move when the file comes into existence. The second half runs the other way and catches an
object built inside a file that already exists: it is named by its own bullet or by nothing, and a
bullet whose leading item resolves to no named file is reported. An object's place is a
decomposition row that names it; its reason is a mention inside the approach; its cases are its
use-case bullet's clauses. Its stated behaviour is read from the same clauses, because the design
contract's own bullet shape requires each clause to say what the object does in that case — so a
bullet with no clause states neither, and the finding names both. A clause that names a case while
saying nothing about what the object does in it is a judgement, and it belongs to the judgement
class rather than here. Stating that boundary is what keeps the holding classes deterministic, which
is what pays for the single judgement one. **[REDLINE S8.4]**

**How a requirement reaches an object.** The decomposition carries a cell naming the criteria each
row delivers, and the class compares the union of those cells against the spec's criteria in both
directions: a criterion no row names is reported, and a row naming a criterion the spec does not
state is reported. The link runs from a requirement to the object that delivers it and carries
nothing else. It adds a column to the decomposition template and no section to either document, so
the element record does not move — the derivation reads headings inside the template's fenced block
and a column is not one. **This document carries that column already**, so the mechanism is
exercised by the first plan that asks for it.

### Decision 2 — what an id is, how the two sides pair, and where the guarantee stops

A statement that leans on a source entity carries an id; the same id appears in a comment on that
entity. The spelling is a bracketed marker whose payload is a lowercase slug of alphanumerics and
dashes. The convention's own templates are written with angle brackets, which are not slug
characters, so a page explaining the mechanism carries no id — the shape filter binds both sides,
which is the first of the three hazards the shipped pairing already paid for.

**Uniqueness is enforced rather than engineered.** No namespace prefix is imposed. An id marked on
two entities, or claimed by two statements, is reported as ambiguous in both directions rather than
passing in either — which is cheaper than a naming scheme and is the only form that cannot be
defeated by a careless copy. Comparison is by equality over whole slugs, never containment, which is
the second paid-for hazard: a containment search reports a short id as accounted for because a
longer one was. The pair count prints beside the verdict, which is the third.

**What resolves what.** The statement names the entity for the reader — a method, a class or a
variable inside a named file, or a heading or numbered item in prose — and carries the id for the
check. The check requires the id's mark to sit inside one of the files the claiming statement names
in backticks; a statement claiming an id while naming no file is itself reported, because nothing
then bounds where the mark may be. **The limit of the guarantee, stated rather than left to be
inferred:** a statement that names entity A while its mark sits on entity B inside the same file
pairs cleanly, so the pairing proves colocation with a file and an author's intent, never that the
marked entity is the named one. Detectability is the property being bought — a vanished entity takes
its comment with it, so the id stops resolving, where a stale position resolves to something
plausible.

**Where a comment does not exist, the obligation narrows and says so.** Six tracked files are
written in a language with no comment syntax at all, measured by `git ls-files '*.json' | wc -l`; a
line added as one stops the parse. For an entity there, the statement names the entity and the
resolution runs in one direction only — from the statement to the file it names, which must exist —
and no reverse pairing is asserted. The narrowing is a property of the language rather than a list
of today's files.

### Decision 3 — the reference class starts green, against a baseline it does not sweep

The positional-reference prohibition is general: it binds wherever a position outlives the task it
was taken in, or may be trusted without having been re-derived. Its input set is therefore the whole
tracked tree rather than a surface list — and that choice also delivers the carve-out structurally
instead of by exemption. **The sanctioned home for a position is the round's own working record,
which is gitignored and so is not tracked at all**, and review output is not a file. So the two
admitted cases fall outside the input set by construction rather than by an allow-list — which is a
claim about the CARVE-OUT only, and not a claim that the class needs no exclusion rule for any other
reason.

**It does not get one, and the measurement is the ground rather than the objection.** Measured at
authoring time with `git ls-files -z | xargs -0 grep -cE
'[A-Za-z0-9_./-]+\.(md|sh|py|json|jq|awk):[0-9]+'` summed by class — a figure that moves with every
commit, which is why the command is given rather than its output — the great majority of the first
shape's occurrences sit in three classes: plan documents, the learning record, and the same class
the membership scan skips by filename pattern. The count on the durable method, enforcement and
verification surfaces the prohibition is about is in the low tens, spread over a handful of files.
Three membership rules mirroring the statement inventory's own exclusions would shrink the
baseline's first run to that handful. They are declined for three reasons. The baseline already
absorbs everything that predates the rule, so an exclusion changes nothing the class reports today
and only silences a FUTURE arrival inside those classes — and an arrival in the pattern-skipped
class is the kind that rots, since those files pin positions in the files they examine. The
inventory's three rules answer a different question — which files state a rule a plan is held to —
so copying them here would put one fact in two places under two meanings, which is the isolation
class's own subject. **And one of the three cannot be written without deciding a question that is
the author's:** whether the prohibition reaches backwards into the completed plans is open and
unanswered, and an exclusion for them would answer it in one direction inside a document the author
reads as a plan rather than as a decision. **Nothing here answers it, and it stands** — it is
carried in § Open questions, where it passes the admissibility test, because the baseline is built
from whatever the tree holds either way and no row sweeps those documents under either answer.

Sweeping the positions that predate the rule is outside this task by the spec's own boundary. A
class that reported them all on its first run would ship a gate that is red on arrival, which the
spec refuses in the same words it refuses accepting a size band. So the class compares the tree
against a **baseline record** of the positions that predate it, committed at
`ai-docs/fixtures/positional-references.baseline`, and reports every arrival. The record is levelled
only by an explicit act that prints what it is about to take in, copied from the statement
inventory's acceptance route — the one comparable act in the tree — and the author runs it. The
baseline is what makes "the rule binds from here" a mechanical statement rather than a promise, and
it leaves the sweep exactly where the spec put it: the author's to schedule. **[REDLINE R1.3]**

**This class reports and does not hold a plan, and the reason is the input set rather than the
class's weight.** Its requirement says a position is reported, never that it holds; and its input is
a tree whose anchors can arrive from a commit the plan under review never touched. A hold here would
stop every later design review on an anchor its author did not write and cannot excuse — the excuse
record is scoped to the plan beside it. So an arrival is reported in the author's hand-back and in
the review, where the reviewer may raise it by judgement, and the levelling is owed by whoever
committed the anchor. The same polarity and the same reason bind the pairing class, whose input set
is the same tree; the three classes that do hold read the plan pair alone, so everything they report
is in the hands of the author being reviewed.

**A mandate is not a stored anchor, and the two are not scoped alike.** An instruction telling a
writer to produce a position regenerates the anti-pattern on every run, so on every surface this
plan already edits the mandates are rewritten to name an entity. A contract that states the new rule
while mandating the old form contradicts itself, which is the judgement class's own subject, so
leaving one would ship the first finding of the mechanism being built. **Five surfaces, and only
three of them are contracts:** the design contract carries two of the three mandating sentences and
the review contract the third, each demanding a position as evidence for a load-bearing claim; the
record schema mandates one in the committed log's own field; the plan-document gate's pairing verb
accepts a position as evidence for the correction mode, its grounds assertion matching a backticked
token that carries either a section heading or a colon followed by a digit run, with its own comment
saying so in those words, and that alternation loses the positional branch so grounds must cite an
entity; and the audit pair carries **two** recording instructions that mandate a line number, one on
each of its two files — the skill's own run-the-checklist step, and the reference sibling's
learning-record field-coherence clause, whose detail body asks for the line number only because the
append-only boundary rule forbids fixing the field in place. A sweep of that pair returns these two
and no third. Both are ruled on below, and the second's entity is the one its own reason names: the
report names **the entry**. **The spec contract carries no such mandate and takes the obligations
only** — measured with `grep -c 'file:line'`, which returns nothing for it against three for the
design contract, one for the review contract and five for the record schema — so an implementer
opening it should not go looking for one. Mandates on surfaces this plan does not otherwise touch
stay with the author's separate sweep.

**The audit checklist's archived-reference clause moves to the entity form, and it is the clearest
specimen of why.** The clause reads, on the audit skill's letter table and in its own narrowing on
the reference sibling, that references to the completed-plans directory in a subagent checklist
still resolve. **It cannot fail, for two reasons measured separately.** Every reference it reads
names that directory and nothing inside it — four of them, in the post-merge review contract and the
design contract, found with `grep -rn 'ai-docs/plans/done' agents/ skills/ docs/` — so what it
verifies is that a directory exists. And the direction that CAN go wrong is one it does not read at
all: a reference out of an archived plan INTO a method page, written as a position. Such a citation
always resolves, because a position resolves to whatever now sits there — in the worst case in the
archive, to a mandatory bullet of the same kind and shape that now states the negation of what the
citation promises. That is the whole property the prohibition exists to remove, stated as a contrast
the clause itself should carry: **a stale entity name resolves to nothing and announces itself,
while a stale position resolves to something plausible and does not.**

**What the clause becomes, and what it deliberately does not claim.** It verifies that a reference
naming an entity resolves to an entity that exists, which is the thing that can actually fail, **and
it reports how many such references it resolved** — because a clause that examines nothing reads
exactly like a clause that found nothing, which is this plan's own hazard met on its own amendment.
Both surfaces carry it, and neither is satisfied by the other's presence, for the reason the
open-gap price is stated on three surfaces. **It claims no coverage of the archive as it stands, and
that is deliberate.** A position anywhere in the tracked tree is the reference class's input, which
reports rather than holds and starts green against the baseline, so what predates the rule is
absorbed there and an arrival is reported there — and **nothing in this amendment answers whether
the prohibition reaches backwards into the completed plans. That question is the author's and it
stands**, carried in § Open questions. Converting the archive to give this clause something to
verify is exactly the act that would answer it, which is why the clause is made honest instead. **No
new sync-group row is owed for either edit**, measured against the propagation table: those two
files are already a declared group, and its trigger names three things — the letter table, the
reference sibling's checklist detail bodies, and the footer's letter range. **Two of the three
move**, and the third does not, because the clause keeps its letter and so stays inside the range
the footer names. Editing both files in one change is what that group asks for. The count is given
as three rather than two on purpose: the sibling's own text tells a reader to read a group off the
propagation table rather than off any one sentence, and a sentence here saying "two" invites the
shortcut that instruction exists to prevent. One window follows and costs nothing: between this
clause landing and the reference class existing, the archive's positional load is covered by neither
— the same state as today, because what the clause covered there never failed.

**Both recording instructions are rewritten in the same change, and the carve-out is why rather than
a technicality.** The carve-out admits a position when the output outlives no task AND every
position in it is re-derived as the row carrying it is written. The audit's findings meet the first
on their main route: the step that records them presents them and applies the approved fixes in the
same pass, and the following step re-runs the checks against the tree in front of it. **But that
same step has a second route, and on it the first condition fails:** it writes an entry to the
learning record, which is committed, outlives the pass, and is re-derived by nobody. A position
recorded under either present instruction is therefore admissible on one route and stored on the
other, and neither instruction can tell them apart. **Both reports travel that same step, so both
take the same ruling.** The skill's recorded finding names the rule and the entity it conflicts
with; the sibling's field-coherence report names the entry, which is the entity its own reason
already points at — the append-only rule forbids fixing the field in place, so the report cannot be
a fix and must identify the entry it is about. In both, a position may still be used while the pass
acts on the file in front of it, and never travels into the entry. Leaving either would put a
mandate for the old form on the one surface whose own job is to catch an anti-pattern, inside a
change that edits that surface — the self-contradiction the paragraph above refuses.

### Decision 4 — the judgement class gets its own reader, and the orchestrator produces both halves

The spec leaves open who runs the semantic class. It goes to a reader of its own,
`agents/plan-convergence.md`, spawned by the design-review step, rather than into the review
contract.

Three grounds, and the first is a contradiction rather than a cost. The review contract's output is
a ruling — GO, ITERATE or STOP — while this class must report and rule on nothing; housing a
never-rule class inside a contract whose whole output is a verdict is the self-contradiction the
class itself exists to catch. Second, the agreement figure the standard requires is measured over
repeated runs on one unchanged input, and a reviewer's pass is the wrong unit to repeat — a narrow
reader with one document in and a finding list out can be repeated cheaply, where a full review
cannot. Third, the reader must be independent of the document's author, which the shipped one-writer
principle already requires and which a pass spawned by the author would break.

**Three readings, and the number is derived here rather than handed down**: three is the smallest
count at which a single disagreement shows up as a minority rather than as a tie, so it is the
cheapest run that can distinguish instability from a stable answer. The pass prints the agreement
across those readings beside the report, and prints what a healthy figure would look like before the
first one, so a low figure reads as a measurement rather than as an unfinished mechanism.

**The deterministic results are produced in the same step**, by the orchestrator that spawns the
reader: the step runs the new check and spawns the reader, and the review that follows reads both.
No judgement result ever stands alone, which is the fifth obligation on the outcome page, satisfied
by where the invocation sits rather than by a sentence asking for it.

**The demonstration obligation is met inside the run rather than beside it.** The standard requires
each class the reader covers to be shown catchable. The pass therefore reads, on every run and as
part of its own input, a committed document at `ai-docs/fixtures/plan-convergence-planted.md`
holding one planted fault per class, and reports per class whether that fault came back — a class
whose planted fault is not reported is printed as uncovered. That keeps the demonstration inside the
mechanism's own output, where the reader of a verdict can see it, and it is why the obligation needs
no surface of its own.

**Its location is chosen for two measured reasons.** It sits beside the committed measurement data,
so the one widened exclusion path test that accounts for the baseline record accounts for it too and
the verification's unaccounted figure stays at zero without a second change. And because the
references gate walks every markdown file it finds on disk, a planted fault may not be a broken link
or an unresolvable anchor — a document planting one would redden that gate instead of this reader,
so the planted faults are confined to the classes the reader rules on. **[REDLINE S8.2]**

### Decision 5 — where each rule is stated once, and the comment admission's single home

| Rule | Stated once on | Restated in its own words on | Enforced by |
|---|---|---|---|
| A reference names an entity; ids pair in both directions | `docs/entity-references.md` (new) | the two writer contracts and the review contract, as the obligation each party has | the reference and pairing classes |
| A number names its provenance | the base principle, already shipped | the two writer contracts and the review contract | the provenance class |
| A comment an instrument reads is a directive | `docs/code-style.md` § Comments | the four surfaces that sweep or enforce the policy, as a pointer | no mechanical check — a judgement, as the policy itself already says of the narration call |
| An open question carries a price | a new base principle | both writer contracts and the review contract | the judgement class, and the review contract's refusal |
| The closing pass keeps the frozen plan | the closing-fold base principle, reworded | the design contract's own closing-pass section and the closing-pass skill | the plan-document gate's residue verb |

**The reference rule gets a new page rather than a section of the principles page**, because it
binds the whole tree and the principles page is the authority on what a spec and a design must
carry. A rule about every surface does not belong inside the page titled for two documents. The page
is pure reference, carries no element token, and is pointed at from the session-start method page —
the only always-loaded surface, and therefore the only place a tree-wide prohibition reaches a
writer who never opens a plan contract.

**The comment admission is stated once on the policy page, and the surface that already owns a
directive class loses its example list to a pointer.** That answers the spec's open question against
the measured sizes: the policy page has room, while the surface carrying today's example list is one
of the two already inside the early-warning band — so consolidating there would add text to a file
that must lose it, and consolidating onto the policy page shrinks that file instead. The admission
is written as a membership rule — a comment an instrument reads is a directive, and an instrument is
anything that fails or changes behaviour when the comment is removed — because the live carve-out
names three example syntaxes and decides nothing about a fourth. Deleting a directive becomes a
finding rather than a cleanup, which inverts the reward the current policy gives a reviewer for
stripping an id.

**The new mechanism is described in several vocabularies, so it gets a sync group rather than the
fallback row.** The propagation page's own procedure says so: a sweep finds files that share the
changed wording, while a named row names files that describe the same mechanism in different words,
and a group of three or more members takes one anchor row plus one back-reference row. The members
are the reference page that states the rule, the check that enforces it, the reader contract for the
judgement class, the two writer contracts and the review contract that restate the obligations, and
the record schema that defines the excuse record — the rule, its enforcement, its judgement half,
its three restatements and its data. The reminder's arms are derived from that table by a gate, so
the arms move in the same change and the gate's member roster is read afterwards rather than its
exit status alone.

### Decision 6 — the open-gap price becomes a base principle, and a heading stops stating a count

The price binds a spec and a design alike, and the only surface that speaks for both is the
principles page. It lands there as a new numbered principle with its own one-clause reason, restated
on the two writer contracts as the author's test and on the review contract as a refusal. Neither
statement is satisfied by the other's presence: the author's half is a test applied while writing,
the reviewer's is a verdict.

Three consequences are planned rather than discovered, each measured above: **[REDLINE R1.6]**

- **The page's heading states a count and must stop.** It is renamed to a form that states none.
  The verification payload carries that heading's exact text three times — once as the body split
  and once in each of two cannot-run messages — so the page and the payload move in one act —
  which is the page's own documented authorisation route, not an obstacle. No inbound markdown
  anchor points at it.
- **The commentary that counts the principles and classes them moves with them.** It names how
  many are prohibitions and which single one is a test and an obligation; the new principle is a
  second non-prohibition, so that sentence is rewritten rather than incremented.
- **The project profile states the count twice** and is an examined surface, so both statements
  move
in the
  same change or the tree ships a false sentence and a red comparison.

The route back is already in the tree: a gap that turns out to have changed the approach, the
requirements or the decomposition re-enters the full design-and-review cycle, which is exactly how a
divergence that breaks the agreed approach is already handled. So the principle names a price an
existing route already charges, and nothing new is wired for it.

**This document's own open-questions section is held to the new rule as it is written**, which is
why the section below carries only questions whose answers change none of those three.

### Decision 7 — the closing pass keeps the frozen plan

The pass stops authoring the design afresh. It applies the correction log's rows to the items that
diverged, strips the spent scaffolding, removes the log and the plan's record of excuses, and leaves
the rest of the frozen document alone. Over the recorded divergences a reader still reads the result
and vouches for it. Over everything else the pass owes only the two deterministic classes that cover
what rots unnoticed — numbers, and references to code — and owes no reader's assertion that the
whole document describes what shipped.

**The replacement principle carries its own reason, and that reason answers the one it displaces.**
The displaced reason is that an in-place edit leaves every sentence the editor did not touch, and
what it does not touch is what nobody re-read. That is why the narrowing could not have been taken
before the first two items: an untouched sentence is now either checked mechanically — a number
whose provenance is gone, an identity that no longer pairs in either direction — or it is prose
stating neither, which the spec records as accepted residue. The pairing's second direction is what
makes the identity half two-sided, which is the spec's own stated reason for the ordering being a
requirement.

**The behaviour contract's side of the pass is deliberately untouched.** Its collapse to the record
of deliberate absence stays as it is, written by its own owner, with the three retained sections
surviving byte-identically — the gate already compares them against version control and that
comparison presumes nothing about whether the design was re-authored. Nothing in this plan edits
that half, and the non-change is stated rather than left to be inferred from silence.

**"Section by section" survives and is not severed.** It constrains how the bytes are delivered,
never what the content is derived from, and it exists because a full-file rewrite of a document this
size is where a write is most likely to be lost. Both contracts keep it; only the derived-from half
changes.

**The residue assertions grow by one.** The gate's folded verb already compares the retained
contract sections against version control, asserts the design free of the spent headings and the
markers, and asserts the log gone. The plan's record of excuses joins that last assertion as a
second filename, which is the smallest possible change to a protected page and leaves every other
assertion untouched — verified by reading the verb: not one of them presumes the document was
re-authored.

### Decision 8 — the edit-time guard is blind to a separator inside a quoted span

This work is independent of everything else here and its file set is disjoint from every other
subtask's.

**The two outcomes, measured on the live guard with synthetic payloads naming an absolute path to a
protected page.** An in-place substitution whose script uses a slash as its delimiter reaches the
confirmation with its full text. The identical command with one of the segmentation characters as
the delimiter is silent, exit 0.

**The mechanism, established from the code and addressed by entity.** The shell arm's `padded`
assignment [padded] in `hooks/lib/plan-invariants-guard.sh` replaces both quote characters with
spaces before anything else reads the command. The
segment loop is then fed through a translation that turns each of eight characters — the two
statement separators, the pipe, the two bracket pairs and the backtick — into a newline, and reads
each resulting line as its own pipeline segment with its own command word. By the time segmentation
runs, nothing records which characters sat inside a quoted span, so a substitution delimiter that
happens to be one of the eight cuts the command into pieces. The arm's two conditions then hold in
different segments, each missing the other, and every entity named here is in
`hooks/lib/plan-invariants-guard.sh`: the segment carrying the in-place writer sets the
in-place flag but offers `path_shaped` [path-shaped] no operand it will accept — one candidate is
rejected as an
option, the other for carrying neither slash nor dot — while the segment carrying the resolved
protected path has a fragment of the substitution script as its command word, which is in neither
`WRITER_WORDS` [writer-words] nor `INPLACE_CMDS` [inplace-cmds], so `has_write_construct`
[has-write-construct] sees nothing beside the path.

**The defect's boundary is one sentence — a separator character inside a quoted span — and it covers
all eight characters and both quote spellings.** The silent set is derivable from the code rather
than taken from a sample, and it is exactly the eight characters the segment loop's translation
names — **but the derivation has two branches, not one, and the second is why it is worth stating
this way.** A delimiter outside that set normally leaves the command in one piece, so the in-place
writer and the resolved path sit in the same segment and the arm fires. The redirect character is
the exception that fires for a different reason: the `padded` assignment rewrites it into the
redirect placeholder before segmentation ever runs, so `has_write_construct` matches on the
placeholder and the write arm is reached whether or not the command writes anything — which is an
over-fire that exists today and is recorded in § Risks. The derivation covers the whole candidate
space because every delimiter takes one of the three paths: inside the translation argument and
silent, rewritten into a write construct and firing, or neither and firing on the intact segment.
Measured beside that derivation: the silence holds for the double-quoted spelling, for the alternate
script flag, for an interpreter spelling of the same edit, for a brace-delimited address block, and
against the guarded record as well as the protected pages, both lists being read by the same arm.
Closing only the pipe would ship a demonstration that passes while the double-quoted spelling of the
identical command stays silent, which is precisely what the demonstration obligation exists to
prevent. **[REDLINE R1.10]**

**This is a seventh silent form against a header that enumerates six.** The guard's own header opens
its enumeration with the count and lists them: a glob, a command substitution producing the path, a
target list read from a file, an unlisted writer, an interpreter script's variable-indirected
writer, and a directory change that is not a leading prefix. A separator inside a quoted span is
none of the six. Closing the hole makes that sentence true rather than changing what it claims — a
stated count falsified by the very thing it counts, found in the enforcement code of the mechanism
this task reworks. **[REDLINE S8.1]**

**The repair direction is measured, and one direction is ruled out.** Neutralise the separator
characters that sit inside a quoted span before segmentation runs, leaving the span's own quoting
intact and the eight characters meaningful everywhere else. Shrinking the separator set is not the
repair: those characters are what makes a compound command segment at all, and the silences the
guard deliberately keeps — a read beside a write, a directory change that is not a leading prefix —
are read off that same segmentation. A quote-agnostic mutant carrying this one change was measured
against a corpus of command shapes with zero disagreements: every spelling of the hole fires, every
pre-existing confirmation still fires, every deliberate silence still holds, all six enumerated
residuals stay silent, and the acceptance condition is undisturbed. The implementing subtask may
reach the property another way; what is pinned is the property, the ruled-out direction, and the
shape set the repair answers to. The live guard was never touched during that probing — every probe
ran on a copy, confirmed by hashing the file against its committed blob.

**What editing the guard fires, checked rather than claimed.** The guard refuses nothing on itself:
its own path is in neither of its two lists and its basename contains no guarded basename, so its
fast path returns before any condition is reached. No propagation group fires: the group binding the
refusal names its page list, its guarded-record list and its two registrations, and command
segmentation is none of the three. Both the guard and its sibling sit on the enforcement surface of
the statement inventory, so every statement the fix adds, changes or removes there is reported by
the comparison and taken in by the closing acceptance, exactly like any other edit to instruction
material.

**This is not the protected-set criterion's subject.** That criterion asks whether the SET of pages
whose edit fires the refusal is the same afterwards. This fix changes no page's membership, adds no
locus defining or enforcing a required element, and leaves the element record untouched; it changes
which command spellings reach the arm at all.

### The refusal reaches almost everything here, and the route is the author's word

All seven protected pages are edited by this plan. Two facts about that, both measured, and the
second is the one that binds:

- **The refusal is sound.** Fed a synthetic payload naming an absolute path to a protected page,
  the
guard
  returns an ask with its full confirmation text, and its path normalisation handles the absolute
  spelling
  the editing tools mandate.
- **It produced no prompt during the work already done on this branch**, because this session's
permission
  mode auto-approves an ask without surfacing it. So no part of this plan may rest on an author seeing a
  refusal.

**The route, therefore:** every group whose subtasks edit a protected page opens by putting those
edits to the author in words — naming the pages and what changes on each — and proceeds on the
author's answer, the way the Group A acceptance act was authorised. The same applies to the two
records this plan levels: the statement inventory and the new baseline. Neither is advanced by an
ordinary run, each prints the report it is about to take in, and each acceptance is put to the
author with that report. A plan that assumed the prompt would arrive would be claiming more than the
mechanism delivers under this configuration.

### Keeping the protected set the same size

The spec's protected-set criterion needs two conditions together, and each is checkable before the
gate runs rather than after:

1. **No wording this plan adds makes any element of a spec or a design required.** The new
principle, the
   open-question price and the id obligation all constrain what goes inside sections both documents
   already
   carry; the requirement-to-object link adds a column, not a section. Nothing here adds a heading
   to either
   template, and the element record stays as it is.
2. **No page or script this plan adds or edits acquires a locus that defines or enforces a
   required element.** This is the condition that does the work, because a page joins the set by
   defining OR by enforcing one — a new check asserting the presence of an already-required
   element would join it with nothing having become newly required. So: the new check holds no
   element token as a literal and derives the names it needs from the record at run time; it
   reports per-object gaps rather than a missing section, so it asserts no element's presence; the
   new reference page and the new reader contract carry no element token at all; and on every page
   edited outside the protected set, no line is written that puts a backticked element token
   beside a presence, absence or retention word.

**The rules hold first for the wording that states them.** Every number this work writes into a
method page names, in its own sentence, which kind it is and how it was obtained, and every
reference it writes names an entity with its id rather than a position — checked by reading the
added text at the moment it is written, and then mechanically once the provenance and reference
classes exist, since those classes read the tracked tree and the pages this work edits are in it. A
rule whose own statement breaks it is the first finding its own mechanism would report.

**Each of those is verified against the live shape test rather than against a reading of it** — the
three routes named under the measured ground — by searching the written text for the test's own
patterns before the verification runs, and then by reading the verification's element count and both
directions of its refusal-agreement leg afterwards. That is what made the last such claim on this
branch measured rather than argued, and the inverse mistake is recorded too: a page was once
reported as an unguarded route because a severity verdict landed on the same line as a presence
word, with no meaning having changed at all.

### Size is planned work, not a contingency

Every instruction file is measured immediately before and immediately after its own edit. Two rules,
and the second exists because two files are already inside the band:

- A file below the band ends below it. Where the new wording would cross it, text leaves the file
  for a reference page in the same change.
- A file already inside the band ends **no larger than it started**, which means every edit to one
of them
  carries an extraction. The measured candidates are named under the ground above; which block moves is
  decided by the rule the earlier extraction pass established — obligations stay on the page a round
  loads, procedure and rationale move — and the file is re-measured after the move.

**Two crossings are certain rather than conditional, and both are planned work.** The
tool-and-subagent inventory page is one of those the ground above measures with almost no headroom,
and the new reader contract obliges it a row, so that subtask moves the page's
project-defined-hooks inventory to `docs/hook-inventory.md`, which exists to hold that inventory so
the tool-and-subagent page a round loads stays an index. The audit skill's reference sibling is
measured there with almost none either and takes two added instructions, so its largest section
moves to `docs/frontmatter-recommendations.md`, which exists to hold recommendations away from the
sibling a round opens for obligations. Neither is written as a condition on a measurement, because
a conditional
extraction turns the row's own measurement obligation into a branch, and a tie within tens of bytes
either way is exactly the state in which a branch becomes a coin toss. **[REDLINE S8.3]**

### Rejected alternatives

| Alternative | Why not |
|---|---|
| Add the new classes as legs of the existing verification | Its payload is at the hard line limit, measured; and it is loaded by a wrapper whose data makes it part of the mechanism the refusal guards |
| Add them as verbs of the existing plan-document gate | That gate is a protected page because it carries element data; growing a check that must stay OUT of the protected set inside one that is IN it is the one shape that cannot be made to work |
| Let the reference class report every pre-existing position | Ships a gate that is red on arrival, and the sweep is outside this task by the spec's own boundary |
| Give ids a namespace prefix to guarantee uniqueness | A prefix cannot survive a careless copy, and the ambiguity report is required anyway; two mechanisms for one property is the isolation class's own subject |
| Put the semantic class in the review contract | Its output is a ruling and this class must rule on nothing; and the agreement figure would require repeating a whole review pass |
| Have the design's author spawn the judgement reader | A party that both writes a document and reports on it can close a finding by editing the evidence — the shipped one-writer principle |
| State the comment admission on the surface that already owns the example list | That surface is inside the early-warning band and must lose text, not gain it; the policy page has room and is the policy's home |
| Keep the heading that states a principle count and add the ninth beneath it | A heading saying eight over nine principles is a stated count falsified by the same change, inside the document that defines the rule against exactly that |
| Carry a table of figure provenances instead of inline provenance | The base principle requires the provenance in the sentence stating the figure, not in a paragraph the reader has to find |

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | **The reference rule and the id convention, stated once.** A new reference page: what an entity reference is in source and in prose; the id's spelling and its shape filter binding both sides; comparison by equality over whole ids; uniqueness enforced by an ambiguity report; the one-direction narrowing where a language admits no comment; and the carve-out as two conditions together — the output outlives no task AND every position in it is re-derived as the row carrying it is written. A pointer from the session-start method page, which is the only always-loaded surface. Page staged with an intent-to-add before any verification run is believed | `docs/entity-references.md` *(new)*, `docs/agents-method.md` | AC4, AC6, AC9, AC10 | — |
| 2 | **The comment admission.** The membership rule on the policy page — a comment an instrument reads is a directive, and an instrument is whatever fails or changes behaviour when the comment goes — with deleting one named as a finding rather than a cleanup. The per-change comment sweep's example list becomes a pointer, which shrinks that file; the whole-branch review contract, the whole-branch review skill and the handoff instruction take the same pointer | `docs/code-style.md`, `agents/self-review.md`, `agents/review-findings.md`, `skills/project-review/SKILL.md`, `skills/context-reset/SKILL.md` | AC8, AC9 | 1 |
| 3 | **The plan-document contracts and the audit surfaces take the two obligations and lose their positional mandates.** Both writer contracts and the review contract state the provenance obligation in their own words and the reference-and-id obligation as a pointer to the page from row 1; the three sentences that currently mandate citing a position for a load-bearing claim are rewritten to mandate naming an entity with its id. **The audit surfaces take three changes.** The archived-reference clause becomes the entity-resolution check on the letter table and in its own narrowing on the reference sibling, reporting how many such references it resolved and claiming no coverage of the archive as it stands. And **both** recording instructions stop mandating a line number: the skill's run-the-checklist step names the rule and the entity it conflicts with, and the sibling's learning-record field-coherence clause names the entry — the entity its own reason already points at, since the append-only rule forbids fixing the field in place. Both reports travel the step that writes a finding into the committed learning record, where nobody re-derives a position. **The reference sibling takes two of those edits into a file the ground above measures with almost no headroom**, so the extraction is planned work and not a contingency: its largest section — the frontmatter-and-config improvement recommendations, recommendations rather than obligations — moves to its own page in the same change, and the file is measured immediately before and after regardless | `agents/design.md`, `agents/spec-writer.md`, `agents/design-review.md`, `skills/ai-audit/SKILL.md`, `skills/ai-audit/reference.md`, `docs/frontmatter-recommendations.md` *(new)* | AC1, AC2, AC3, AC4, AC5, AC6, AC35 | 1 |
| 4 | **The committed correction log moves to entity-plus-id; the ephemeral record keeps its positions.** The log's row field that quotes a diverged sentence carries the entity and its id instead of a position, and the duty to re-derive every position in a touched row splits: the ephemeral sections keep it verbatim, the committed log loses it because there is no position left to re-derive. No single rule spans both records afterwards. **The copy relation between the two records is the hidden half and is severed here rather than described away:** that field is specified today as a verbatim copy of the fix plan's own cell, and the fix-plan gate refuses a cell quoting no position — so the promotion into the committed log becomes a TRANSFORMATION, stated in both places that specify the field. Measured, so the file list is bounded: the arm that pairs a marker with a row keys on the row's first cell alone and never reads this field, so neither gate changes, and the ephemeral cell keeps its position and its gate untouched | `docs/templates/progress-format.md`, `agents/design.md` | AC10, AC11 | 1, 3 |
| 5 | **The check's wrapper, its payload, and the two plan-pair-local classes.** Three outcomes with a could-not-run that is not a pass; the examined counts beside the verdict, including the not-evaluable count; the provenance class and the arithmetic class; section names derived from the required-element record at run time rather than held as literals; a derived section absent from the document under examination yields an empty region and a zero count, never a finding about the section. The runner's path-argument exemption takes the new check, and the profile's gate inventory is reconciled with what the runner derives from the index — **but the check's name must not enter the profile's structural-checks span in the `bash scripts/<name>.sh` spelling**, because that span is parsed and a check named there while exempt from membership reddens the inventory member in one direction; measured precedent, the existing path-argument gate is named nowhere in that span | `scripts/check-plan-convergence.sh` *(new)*, `scripts/check-plan-convergence.py` *(new)*, `AGENTS.md`, `scripts/run-checks.sh` | AC1, AC2, AC3, AC14 | 3 |
| 6 | **The completeness and isolation classes.** Objects read from the decomposition's file cells and the use-case bullets; place, reason, cases and behaviour answered structurally with the judgement boundary stated; a criterion no row reaches and a section reference resolving to nothing in the same report; repeated numbers and repeated spans of at least the borrowed minimum length, naming both sites. The decomposition template gains the cell naming which criteria a row delivers | `scripts/check-plan-convergence.py`, `agents/design.md` | AC12, AC13 | 5 |
| 7 | **The reference and pairing classes, with the baseline that makes them start green.** Positional references across the tracked tree against a committed baseline record; the ids a plan claims against the ids marked in source, both directions, by equality, with the pair count printed and ambiguity reported; the mark required inside a file the claiming statement names. The baseline is created and staged, and the comparison payload's exclusion path test is widened so the new record is accounted for and the verdict's unaccounted figure stays at zero | `scripts/check-plan-convergence.py`, `ai-docs/fixtures/positional-references.baseline` *(new)*, `scripts/check-plan-invariants.py` | AC4, AC5, AC6, AC7 | 1, 5 |
| 8 | **The excuse route.** A committed per-plan record at `ai-docs/plans/<spec-base>.excuses.md`, beside the plan and named by the same construction the correction log uses, with a suffix the ignore rules do not swallow — confirmed with `git check-ignore -v`, which reports the round record's suffix ignored and this one not; a grant act that prints the finding before excusing it and no ordinary run that excuses anything; an excused finding reported as excused with the excused count beside the verdict; the excuse keyed by class, by the entity-named spot and by the finding's subject, so editing the passage does not revoke it and the same fault at that spot comes back excused. Removing one by hand is an act of the same kind, and the record names the spot plainly enough to find | `ai-docs/plans/<spec-base>.excuses.md` *(new)*, `scripts/check-plan-convergence.sh`, `scripts/check-plan-convergence.py`, `docs/templates/progress-format.md` | AC15, AC16, AC17, AC18 | 5, 6, 7 |
| 9 | **The refusal wiring, on the two parties that can hold a plan, and only for the classes that hold.** The design's author runs the check as its own exit check and hands back on nothing but a verdict carrying no unexcused finding of the three holding classes — completeness, isolation, arithmetic — which is the shipped shape for the spec's form gate; a reporting class's findings travel in the hand-back rather than blocking it. The reviewer may not issue GO while such a finding stands unexcused, and reads the reporting classes' findings as input to its own judgement; its checklist gains the convergence classes with the severity lines written so the element derivation yields only pairs the record already carries | `agents/design.md`, `agents/design-review.md` | AC15, AC19 | 5, 6, 7, 8 |
| 10 | **The judgement reader and the pass that produces both halves.** A reader contract whose output is a report and never a verdict, pointing at the outcome page's five obligations rather than restating them; three readings with the agreement printed beside the report and the healthy figure stated before the first; a committed document at `ai-docs/fixtures/plan-convergence-planted.md` holding one planted fault per class, read on every run, with each class printed as having reported its own planted fault or not, and planting nothing that would redden the references gate instead. The design-review step runs the deterministic check and spawns the reader, so no judgement result stands alone. The tool-and-subagent inventory takes its row, and its project-defined-hooks inventory moves to its own page in the same change | `agents/plan-convergence.md` *(new)*, `ai-docs/fixtures/plan-convergence-planted.md` *(new)*, `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/claude-tools-hierarchy.md`, `docs/hook-inventory.md` *(new)* | AC19, AC20, AC21, AC22, AC23 | 9 |
| 11 | **The closing pass stops authoring afresh.** The base principle is reworded with its own reason answering the displaced one, on the page and in the verification's pinned copy as one act; the design contract's closing-pass section and the closing-pass skill both narrow to applying the log's rows to the items that diverged; "section by section" stays and is marked as surviving on its own terms; the whole-document assertion is replaced in both places | `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `agents/design.md`, `skills/redline-fold/SKILL.md` | AC24, AC26, AC28, AC29 | 7, 10 |
| 12 | **What the closing pass still owes, and the third residue.** The pass runs the provenance class and the reference-and-pairing classes over the items no correction was recorded against, and owes nothing further there; the recorded divergences are read and vouched for; the plan's record of excuses is removed with the log, and the folded verb reports either one surviving, asserted by the same literal-path construction it already uses for the log. In the same file and the same change, the pairing verb's mode-grounds assertion loses its positional branch, so grounds cite an entity rather than a position | `skills/redline-fold/SKILL.md`, `scripts/check-redline.sh` | AC25, AC27 | 8, 11 |
| 13 | **The open-gap price as a base principle.** The new numbered principle with its one-clause reason; the heading renamed so it states no count, with all three of the payload's occurrences of it — the body split and both cannot-run messages — moved in the same act; the commentary that counts the principles and classes them rewritten; the pinned copy extended; the project profile's two count-bearing statements moved | `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `ai-docs/context.md` | AC30, AC31, AC32 | 11 |
| 14 | **The price reaches both authors and the reviewer.** Both writer contracts state the test an open question must pass — answering it changes neither the approach, nor the requirements, nor how the work breaks up — and the review contract refuses a plan whose open question fails it, with the route back named as the cycle that already handles an approach-breaking divergence. Neither statement is satisfied by the other's presence | `agents/design.md`, `agents/spec-writer.md`, `agents/design-review.md` | AC30, AC31, AC32 | 13 |
| 15 | **Close the change.** The new sync group gets its anchor row and its one back-reference row, and the propagation reminder's arms are extended to the classes derived from it, with the derivation gate re-run and its member roster read; every other group this work fired is swept and its siblings reconciled; the plugin's patch version is bumped because shipped content changed; the two conditions of the protected-set criterion are verified against the live shape test in both directions; every edited instruction file is re-measured; and the statement inventory's acceptance is put to the author with its report | `docs/propagation.md`, `hooks/hooks.json`, `.claude-plugin/plugin.json`, `ai-docs/fixtures/plan-invariants.inventory` | AC33, AC34, AC35 | 1–14, 16 |
| 16 | **Close the edit-time guard's blindness to a separator inside a quoted span.** Neutralise a separator that sits inside a quoted span before segmentation, leaving the span's quoting intact and the eight characters meaningful elsewhere; the demonstration covers both quote spellings and is paired with a silent case per shape, because a repair that bought the confirmations by making the arm fire on reads would be worse than the hole. Independent of every other row; file set disjoint from all of them | `hooks/lib/plan-invariants-guard.sh` | — (author-added scope, no criterion) | — |

**Sixteen rows, counted from the table above, and the duty to propose a split is discharged rather
than skipped:** the design contract asks for a split proposal above seven subtasks, and the author's
recorded decision is that all of this is one task with nothing carved out into separate tickets. The
proposal is therefore named here and the decision stands.

## Handoff plan

Six groups. Every group — including the first — is entered through a `/context-reset` handoff per
`${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`, and every group whose rows edit a protected
page opens by putting those edits to the author in words, because no refusal prompt reaches them in
this configuration.

- **Group A:** subtasks 1–3 — the rules, stated once each, before anything enforces them.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with
  fresh context.
- **Group B:** subtasks 4–6 — the record's references, then the check's wrapper and the three
  classes whose input is the plan pair alone.
- **Handoff after Group B:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Group C:** subtasks 7–9 — the two tree-wide classes with their baseline, the excuse route, and
the two
  parties that can hold a plan.
- **Handoff after Group C:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Group D:** subtasks 10–12 — the judgement reader and the closing pass.
- **Handoff after Group D:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Group E:** subtasks 13–15 — the new principle, the price on three surfaces, and the closing
  act.
- **Handoff after Group E:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Group F:** subtask 16 — terminal group, one subtask, within the 1..3 range.

**The dependency graph, and the one concurrency this design licenses.** A–E are strictly serial, and
the files they share across group boundaries are these eight, derived from the file cells of the
table above rather than listed by hand: `agents/design.md` (A, B, C, D, E),
`agents/design-review.md` (A, C, E), `agents/spec-writer.md` (A, E),
`scripts/check-plan-invariants.py` (C, D, E), `docs/plan-invariants.md` (D, E),
`docs/templates/progress-format.md` (B, C), `scripts/check-plan-convergence.py` (B, C) and
`scripts/check-plan-convergence.sh` (B, C). Concurrency over a shared file is never licensed.
`skills/redline-fold/SKILL.md` is shared by two rows inside Group D and crosses no boundary, which
is why it is not in that list. **Group F is independent and its file set is disjoint from every
other group's**, so it may run concurrently with A, B, C or D — but it must be complete before
subtask 15, whose acceptance act levels the record over the whole tree and whose version bump covers
all shipped content. So F is concurrent with A–D and never with E.

## Risks

- **An edit to a protected page proceeds without the author having seen anything.** Measured: the
refusal
  fires correctly and this session's permission mode swallows it. Mitigation: the group-opening
  authorisation in the handoff plan, in words, naming the pages. There is no mechanical backstop, and
  pretending otherwise is the claim the spec forbids.
- **A new page or script acquires an element-defining locus by accident and the protected set has
  to grow.** The live test fires on a backticked element token beside a presence, absence or
  retention word — a shape a careful sentence can hit with no change of meaning, which has already
  happened once on this branch. Mitigation: search each written text for the test's own three
  routes before the verification runs, and read both directions of the refusal-agreement leg
  afterwards, not only the exit status.
- **The new check narrows its own input set silently.** A check that examined fewer inputs than
exist reads
  exactly like a clean one. Mitigation: every class prints what it examined — plan documents, numbers,
  objects, criteria, pairs, tracked files, not-evaluable relations — and a zero where a non-zero is
  expected is a finding about the run rather than a clean verdict.
- **A new script is invisible to the gate that parses the tree.** The shell-syntax member lists
  tracked files only, and the verification's corpus likewise, so a new script or page that is not
  staged with an intent-to-add is examined by nothing while every gate reads green. Mitigation:
  stage each new path before any run is believed, and read the processed-file and page counts, not
  the exit status.
- **The gate inventory reddens until it names the new check.** The runner derives its lists from
  the
tree
  and compares them against the profile's in both directions, so a new check is reported until both
  sides
  agree. That is the mechanism working; the member names what is missing.
- **The baseline record is accepted unread.** The acceptance route's property — it prints the
  report
it is
  about to take in — is conditional on a record existing to compare against: with the record absent, the
  preflights that would refuse are skipped by design, so a first run would absorb everything while
  printing nothing. Mitigation: the baseline is created once, deliberately, and never accepted while
  absent; the same rule already binds the statement inventory.
- **The judgement reader's agreement figure comes back low.** Three readings of one document may
disagree,
  and the standard deliberately sets no threshold. Mitigation: the healthy figure is stated before the
  first run, so a low one is reported as a measurement rather than read as an unfinished mechanism — and
  the deterministic classes are never withdrawn in its favour.
- **Three readings per design review is a real cost.** It is paid deliberately: a judgement class
  whose stability is unmeasured is a check nobody can weigh, and three is the smallest count that
  distinguishes a minority from a tie, derived in § Decision 4. The reader is narrow by contract —
  one document in, a finding list out — and no comparison with the cost of a review pass is
  offered, because none has been measured.
- **A reporting class speaks in every design review about things that plan did not touch.** The
reference
  and pairing classes read the tracked tree, so once an anchor or an orphaned mark is committed
  anywhere,
  every later run names it until somebody levels the record. It does not hold a plan — that is the
  polarity in § Decision 1 — so the cost is noise in a report rather than a stopped review, and the
  baseline keeps it at nothing until a commit adds one. The author should know the shape of it: the
  party
  who owes the levelling is whoever committed the anchor, and nothing mechanical sends it to them.
- **The amended audit clause examines nothing and reads clean.** Until entity references exist in
  the surfaces it reads, the entity-resolution check resolves none and a reader sees a passing
  letter. Mitigation is the rule this plan applies to its own mechanisms: the clause reports the
  number it resolved, so nothing is examined silently. **No surface claims coverage of the
  archive's existing load** — the baseline absorbs what predates the rule and only an arrival
  there is reported, which is the distinction § Decision 3 states and the thing this bullet must
  not quietly widen. **And the mitigation is an instruction and nothing more:** the clause is a
  checklist letter a reader runs, so a pass that forgets to print the count reads exactly like a
  pass that printed a zero.
- **The isolation class over-fires on a repeated literal that is not a duplicated fact.** A
  heading, a path, a template word and a borrowed constant all repeat legitimately. Mitigation:
  the class reaches a repeated number or a span of at least the borrowed minimum length, a
  paraphrase is explicitly the judgement class's subject, and a single harmless finding is what
  the excuse route exists for.
- **A principle's wording change reddens the comparison until the pinned copy moves.** That is the
  documented authorisation route rather than a defect; both edits land in the same act, and the
  comparison's first leg is read after them.
- **A file already inside the early-warning band grows instead of shrinking.** Two are, measured.
  Mitigation: the no-larger-than-it-started rule with a pre-measured candidate per file, and a
  measurement immediately before and immediately after each edit.
- **The arm already over-fires on a read today, before any repair, for one delimiter.** This is a
  present-tense fact and not a risk the repair introduces: a read whose substitution delimiter is
  the redirect character reaches the confirmation with no in-place flag anywhere in the command,
  because the `padded` assignment rewrites that character into the redirect placeholder before
  segmentation and `has_write_construct` matches the placeholder whatever else the segment holds —
  while the slash and at-sign spellings of the same read are correctly silent. The repair neither
  closes nor widens it, and it is named here so that a demonstration of the repair is not read as
  having caused it. **The risk the repair does carry** is that neutralising a separator inside a
  quoted span makes the arm fire on reads it used to pass. Mitigation: the silent case paired with
  every confirmed one, per shape rather than per family — a silent case on one delimiter says
  nothing about whether another spelling has begun firing on a read.
- **The fold's narrowing leaves a stale sentence carrying neither a number nor an identity.**
Accepted by
  the spec as residue, and narrower than it reads because the pairing runs in two directions. Named here
  so the acceptance is visible rather than implied.

## Use cases

- `docs/entity-references.md` — read by a plan's author while writing a statement that leans on
source, to
  learn what may be referenced and how an id is spelled; read by the reviewer to judge a reference
  without
  re-deriving the rule; read by the implementer of the pairing class as the authority the check
  derives its
  shape filter from; pointed at from the session-start page so a writer who never opens a plan contract
  still meets the prohibition.
- `scripts/check-plan-convergence.sh` — run by the design's author as its own exit check, which
refuses the
  hand-back on an unexcused finding of completeness, isolation or arithmetic and carries the reporting
  classes' findings forward instead; run by the reviewer, which may not issue GO while such a finding
  stands and which weighs the reporting classes' findings by judgement; run by the closing pass over
  the items no correction was
  recorded against, to report a number that no longer holds and an identity that no longer pairs; run by
  the author with its excuse verb, to excuse one finding after seeing it.
- `scripts/check-plan-convergence.py` — loaded by the wrapper above and by nothing else; holds the
  six classes, the counts each prints, and the derivation that reads section names from the
  element record rather than carrying them.
- `ai-docs/fixtures/positional-references.baseline` — read by the reference class as the comparand
  that tells an arriving position from one that predates the rule; rewritten only by the author's
  explicit acceptance, which prints the report first; read by a later sweep's author as the list
  of what is left to remove.
- `agents/plan-convergence.md` — read by the reader the design-review step spawns, as its whole
contract;
  read by the orchestrator to know what it gets back and in what shape; read by the reviewer beside the
  deterministic verdict, as the report it must weigh and may overturn.
- `ai-docs/plans/<spec-base>.excuses.md` — read by the check to report a known finding as excused
  rather than raising it afresh; read by the reviewer to see what a plan has been excused for,
  because an excused finding that vanished would make a plan carrying ten of them read as clean;
  read by the author who wants one removed, which is why it names the spot as an entity; removed
  by the closing pass with the correction log.
- `ai-docs/fixtures/plan-convergence-planted.md` — read by the judgement pass on every run, as the
  input whose known faults say whether each class is reporting at all; read by whoever adds a
  class, as the one place a new class's fault has to be planted before the pass will call that
  class covered; read by a reader of the pass's output, who sees a class printed as uncovered and
  learns that its silence proves nothing.
- `docs/frontmatter-recommendations.md` — read by the audit pass when it reaches the letter whose
  recommendations moved there, as the detail its checklist points at; read by whoever proposes a
  frontmatter or configuration improvement, as the place such a recommendation is recorded rather
  than re-argued; pointed at from the reference sibling it left, which keeps the obligations on
  the page a run loads and sends only the recommendations away.
- `docs/hook-inventory.md` — read by the audit pass that compares the project surface against the
embedded
  one without walking the tree; read by anyone tracing which hook event a mechanism registers on;
  pointed
  at from the inventory page it was extracted from, which keeps the index a reader scans.
- `hooks/lib/plan-invariants-guard.sh` — run by the harness before every edit and every command
  that
could
  write, to put an edit to a protected page or the guarded record in front of the author; read by the
  verification's refusal-agreement leg as the live covered set, which is why its two lists are data;
  read
  by a maintainer asking which silent forms are deliberate, which is why its header enumerates them.

## Open questions

Each of the four below changes none of the approach, the requirements or how the work breaks up —
which is the test the new principle states, applied to this document as it was written.

- **Whether the arithmetic class has any external precedent to borrow from.** The research behind
  the ticket reports none. If it is genuinely novel its planted-fault demonstration carries more
  weight than the other classes', since nothing outside corroborates its shape — which changes how
  carefully that one input is built, not what is built or in which order.
- **Which block leaves each file that is already inside the early-warning band.** Candidates are
measured
  and the rule that chooses between them is stated; the choice is made against the measurement at the
  moment of the edit, because the file will have moved by then.
- **Whether the id's slug reads better as one word or as a dotted pair.** The behaviour is fixed —
one id,
  one entity, equality over whole ids, ambiguity reported — and the spelling inside the shape filter is
  cosmetic in both directions of the check.
- **Whether the positional prohibition reaches backwards into the completed plans.** The author's
  to answer; nothing in the instruction surface answers it and nothing in this document does
  either. It passes the test on all three counts: the approach is the baseline plus a class that
  reports rather than holds under either answer; the requirements place the sweep of what predates
  the rule outside this task under either answer; and no row sweeps those documents either way,
  since the baseline is built from whatever the tree holds when it is created. What the answer
  would change is whether an exclusion rule is written later — a change to one script, after this
  plan closes.
