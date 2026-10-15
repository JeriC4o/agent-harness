# Design: Protect the base terms and the form of the spec and design from the self-improvement path

**Ticket:** GH-116
**Date:** 2026-10-13
**Spec:** ai-docs/plans/2026-10-11-plan-invariants.spec.md

## Approach

Three layers: a document of base principles, a mechanical verification, and an edit-time refusal on the
pages that define document composition. The verification carries four legs, and the load-bearing one is a
**comparison against a recorded inventory of statements** — it reads no sentence and rules on nothing.
The published evidence that bounds this design space, and the three rules the comparison brings with it,
are recorded once in the spec's § Technical constraints and are not restated here.

### Where each thing lives

| Artefact | Role | State |
|---|---|---|
| `docs/plan-invariants.md` | The eight principles as numbered sentences with their reasons; the required-element record; the protected-page table; the near-miss table; the two-surface statement; the authorisation route; the honest limit | In the tree. Two sections are amended by subtask 4 |
| `scripts/check-plan-invariants.sh` | The verification's entry point — flags, preflights, the three-outcome convention, the acceptance route | In the tree. Amended by subtask 1, header included |
| `scripts/check-plan-invariants.py` | Its payload: the corpus, the four legs, the report | In the tree. Its second leg is replaced by subtask 1 |
| `ai-docs/fixtures/plan-invariants.inventory` | The record the comparison reads | New, landed by subtask 1 |
| `scripts/test-check-plan-invariants.sh` | The verification's suite | In the tree. Subtask 1 removes what it asserts about the replaced leg; subtask 3 writes the comparison's legs |
| `hooks/lib/plan-invariants-guard.sh` + its suite | The edit-time refusal on two `PreToolUse` matchers | In the tree. Gains the record and the acceptance route in subtask 2 |

The principles document is **method**: it describes what a spec and a design ARE, which holds in every
project, and it names no language, build tool, domain entity or ticket prefix. The record is
**profile** — an inventory of this repository's own instruction material is a project fact.

**Its exact path is forced by two gates and was measured rather than chosen on taste.** The reference
gate admits only an enumerated set of project-data paths wherever a method file names one, and
`ai-docs/fixtures/` is in that set while a bare `ai-docs/` sibling is not: measured on this tree, both
candidate paths planted on one line of a method file, the bare sibling returns
`major|L4|… is not a documented project-data path` at rc 1 while the `fixtures/` spelling is silent in
the same run, and the gate is clean again once the probe is reverted. **That root is the least-bad fit among the admitted ones rather than a match, and the divergence is
named here so the next reader does not build on a false premise.** Its full contract asks for one
subdirectory per corpus, each carrying an input, a derived mapping and a baseline holding a measured
expectation with the input's checksum; for an input a gate REPLAYS so a detector meets what it ships
against; and for a fixture that is not refreshed as routine maintenance. The record diverges on all
three: it is a maintained record rather than a frozen replay input, it is one file at the root rather
than a corpus subdirectory with a baseline and a checksum, and the gate compares against it rather than
replaying it. One clause does fit exactly, and it is the one that matters most here — changing a fixture
means changing its baseline on purpose, in the same commit, which is the acceptance discipline. The two
alternatives were weighed and both cost a method-file edit: admitting a brand-new project-data path
moves the gate's list **and** the method page it mirrors, with the mirror asserted by that gate's own
audit mode, on a page already over its size warning; widening this root's documented contract to admit a
maintained record is cheaper but still rewrites a method contract to accommodate one project artefact.
Naming the fit honestly costs nothing and leaves the measured gate admission untouched. **The second gate is satisfied either way, and this is measured too:**
a backticked record path harvested into the propagation table derives no required hook arm, because the
arms gate filters harvested tokens to markdown, shell and JSON spellings — so the record needs no arm,
while a backticked hook path still would, which is why hook paths stay in prose.

The record is outside the examined corpus, and that is structural rather than arranged: the profile
surface is an explicit three-name enumeration, so any other file under the project-data root falls
through the surface rule and belongs to no surface. A record inside its own corpus could not be brought
level without changing the thing it records.

### What is already in the tree and is not rebuilt

Confirmed against `git status --short` and the files themselves. None of the following is decomposed
below, and no subtask re-lands any of it:

1. **The principles document** — eight numbered byte-stable sentences with their reasons, the
   required-element record keyed by document and token, the protected-page table with a reason per
   member, the near-miss table, the authorisation route, the honest limit; registered in the method
   root's agent-doc table and in the docs index. AC1, AC2, AC19.
2. **The edit-time refusal** — the guard on the file-editing matcher group and on the `Bash` group, its
   suite, and the four pinned records moved in the hook-behaviour suite. AC15, AC16, AC17.
3. **Leg 1** — each pinned principle sentence present and unchanged, an absence reported distinctly
   from a wording difference. AC3, AC4.
4. **Leg 4** — the live refusal coverage against the protected-page table in both directions, the
   near-miss controls, and the element-defining-locus sweep. AC16.
5. **Leg 3** — the required-element set derived from three loci and compared against the record on the
   principles page in both directions, with the fold's heading prohibition read on its own arm. AC6
   partly, and the `elements=` figure AC12 requires.
6. **Registration** — the `plan-invariants` member of the single pre-commit entry point, the documented
   item `5b`, the documented suite list, the pinned member table in the runner's own suite, and the five
   prose sites that count the structural checks. AC20. The member's name and the suite's path do not
   change, so no part of that registration moves again.
7. **The propagation group** and the arms it adds to the hook registry.
8. **The version bump** to `0.1.46`, which is already higher than the shipped `0.1.45`. AC21.
9. **The improvement-pass contract** and the second autonomous-edit route closed in the escalation
   audit's category 2. AC18.

**One behaviour inside that set is deliberately changed, and it is named here so the change is not read
as a regression.** The corpus loader today records a file it cannot read and carries on, so a run
completes clean while having compared fewer statements than the corpus holds — which under a comparison
is the precise shape of AC12's false green. Subtask 1 makes an unreadable corpus file a cannot-run, and
moves the surface roster so that it prints on the cannot-run path as well, because that roster is what
tells a surface not examined apart from one examined and found clean.

### The inventory, the record, and why the record is not a copy of the text

The corpus is a closed set of surfaces, so the statements it carries are an inventory. The verification
records that inventory and compares the tree against it, reporting every statement that arrived,
departed or changed, with its own text, its surface, and on a change what it said before.

**Measured on this tree: 122 files, 28,272 lines, 1,810,417 bytes, segmenting to 25,759 statements.**
A record carrying each statement's own text therefore measures **2.52 MB** at one row of
`path <TAB> text` per statement, and **2.81 MB** if the row also carries its surface — larger than the
corpus itself either way, because every row repeats its path. The row format is stated because it is
what makes the figure reproducible, and both spellings reach the same conclusion. The decisive cost is
not the landing size: every accepted change would appear twice in the same diff, once in the edited file
and once in the record, in a repository where nearly every commit edits instruction material. The record
would become the largest and noisiest file in the tree, and a reviewer would read every instruction
change twice.

**So the record names its comparand instead of copying it.** One row per corpus file:

```
<surface>  <blob sha>  <path>
```

Measured: **122 rows, 9,849 bytes.** The repository is a git repository and the payload already shells
out to `git`, so the blob the row names is the exact previous text — recoverable with `git cat-file`,
byte-for-byte, with nothing duplicated. A row carries nothing derivable from that blob: a statement
count beside it would be a second record of one fact and could only come to disagree with it.

**The comparison, per file:**

1. **Every corpus file is segmented on every run**, and the statement total the verdict line carries is
   the sum over all of them. This is not an optimisation question: AC12's false green is a run that
   silently compared fewer statements than the corpus holds, and a run that skipped segmentation for
   unchanged files would have no total to report in exactly the clean case. Measured over five runs, the cost is
   affordable and is paid: hashing the whole corpus in one process takes **0.011–0.012 s** and
   segmenting all 122 files **0.142–0.166 s**, an order of magnitude apart. **A clean sweep therefore
   cannot cost less than about 0.15 s** before the other three legs, and that floor is the honest figure
   rather than the segmentation time on its own.
2. **The current blob sha of every corpus file is taken in one process**, and a file whose sha equals its
   recorded sha skips the three steps that follow — the previous-text fetch from the object store, the
   multiset difference and the alignment. That is what the fast path buys: not the segmentation, but a
   `git cat-file` per file and the only super-linear step in the check.
3. Otherwise both versions are segmented and compared as **multisets**. A multiset rather than a set,
   measured: **111 of the 122 files carry a repeated normalised statement**, so under set semantics the
   removal of one of three identical lines would be invisible.
4. The multiset difference is the exact-match answer: what is in the tree and not the record has
   arrived, what is in the record and not the tree has departed. A statement that merely MOVED inside
   its file is in both multisets and is not a change — which is correct, and is the same reason the
   comparison is per file rather than positional. **[REDLINE R2.2]**
5. The leftovers are then aligned, and only then — § The alignment below.
6. A path in the corpus with no row has arrived whole; a row with no path has departed whole. Both are
   reported statement by statement, because no region of an examined surface is exempt.

**Nothing is set aside.** There is no class of passage the comparison treats as harmless, so a change can
be absent from the report only by not having happened. What a reported change MEANS is a reader's
judgement on the report, which is the division of labour the rest of this task already rests on.

### The statement, and its two spellings

The unit is part of the contract, so both spellings are stated here rather than left to the
implementation. A statement is always **whitespace-normalised** — internal runs of whitespace collapse
to one space — because these documents hard-wrap and a unit evaluated line by line is evaluated on a
wrap fragment. **[REDLINE R3.1]**

**On a prose surface** a statement is one sentence, one list item, or one clause the author separated
with a semicolon, read over the text of a paragraph joined across its hard-wrapped lines. Four shapes are
**line-oriented** rather than paragraph-joined, because each is its own authored unit and none of them
wraps: a heading, a table row, a line inside a fenced block, and a line inside the YAML front matter at
the head of a file. One further rule is load-bearing and was measured rather than assumed: **a list item
is recognised only where a list can begin** — after a blank line, a heading, a fence, or another list
item — never mid-paragraph, because a re-wrap can put a number-and-period at the start of a line and a
rule that trusted the line start would then read half a sentence as a new item.

**The property that rule exists for, measured:** every one of the **53 markdown files in the corpus**
was re-wrapped at three different columns and the statement multiset came back **identical for all 53 at
all three widths**. Re-wrapping a paragraph is not a change to the inventory, while re-writing a
sentence is. Three residual forms are named rather than hidden, and all three fail in the loud
direction — each reports a departure plus an arrival instead of nothing:

- a wrap that breaks a token across lines, so the joined text differs by that token;
- a wrap that leaves a number-and-period at the head of a line with no list for it to continue;
- a wrap that leaves a `|` at the head of a line, which the table-row rule then reads as a row. Live
  shapes exist for this: an inline code span carrying pipe characters is in the corpus today.

**On a code surface a statement is one normalised non-empty line.** The shell, `python`, `awk`, `jq` and
JSON payloads of the enforcement and verification surfaces are in the corpus — the element lists live
there as data, and the text the enforcement layer hands an agent as a session or a tool use begins is
instruction material the agents RECEIVE. A line is the authored unit of all of them, as a sentence is
the authored unit of prose, and the two rules are deliberately different because segmenting a script
into sentences and segmenting a paragraph into sentences are not the same operation. The cost is stated:
re-wrapping a multi-line message a guard EMITS reports a departure and an arrival rather than nothing.
**Measured, code is 71% of the inventory** — 14,433 statements on the verification surface and 3,806 on
the enforcement surface, against 7,520 across the profile, method and scaffolding surfaces together. **[REDLINE R3.1]**

### The alignment, and the three rules it obeys

Exact match runs first, by construction: the multiset difference is complete before anything else looks
at the leftovers. Each remaining arrival is then paired with the remaining departure it most resembles,
by a token-overlap ratio over the normalised words, within the same file, each departure claimed at most
once. A pair above the threshold is reported as one **changed** line carrying both the new text and what
it said before; anything unpaired is reported as an arrival or a departure carrying its own text.

- **The similarity judgement may only ALIGN.** It cannot change the verdict — every leftover is reported
  either way, and the only difference is whether two lines are presented as one. That is a structural
  property of where the pairing sits, not a promise about a threshold.
- **No entailment judgement is taken.** None is delivered here. If one is ever added it may only put
  evidence beside the deterministic result, in both directions, and never arbitrate.
- **The deterministic comparison takes precedence and every line is traceable to the rule that produced
  it.** Each report line names its rule — exact match, or alignment with the ratio it was paired at.

The ratio is local arithmetic over two word sets: no model, no network, and the same verdict on the same
tree. Measured on real rewordings in this corpus: **0.94** and **0.88** for a sentence reworded a word or
two, **0.09** for two unrelated statements, and over this branch's own change **15 of 18 departures**
paired with a reworded arrival at a threshold of 0.6.

**Its cost is the only super-linear step in the check, so its bound is stated, and one implementation
constraint follows from the measurement rather than from preference.** The pairing is per file and never
crosses files, so the worst case is one large file rewritten whole: measured on the largest corpus file,
1,464 statements against 1,464, **2,143,296 nominal ratio computations in 4.54 s — and 1.05 s when each
statement's word set is built once instead of once per comparison.** Building the word sets once is
therefore part of the design and not a later optimisation. The nominal product is also an overcount,
because a departure already claimed is not offered again: measured on the same file, **1,072,380
computations actually performed, half the nominal, at 0.56 s**. **A second or so on the worst file the
corpus holds needs no escape hatch, so the pairing has no bound above which it stops** — a mode with no
value, no criterion and no suite leg would ship a second reporting path nobody had exercised, and an
uncalibrated threshold is the thing this design rejects a hosted model for.

### The legs, and what each one answers

| Leg | Question | State |
|---|---|---|
| 1 | Is each pinned principle sentence present and unchanged, with an absence reported distinctly from a wording difference | In the tree |
| 2 | Does the tree's statement inventory match the record, and what arrived, departed or changed | Replaced by this design |
| 3 | Does the required-element set derived from the three loci agree with the record on the principles page, in both directions, and is the fold's heading prohibition read as a prohibition rather than merged into the element set | In the tree |
| 4 | Does the live refusal coverage agree with the protected-page table in both directions, is the guard still registered, and does every tabled page still carry an element-defining locus | In the tree |

Leg 1 keeps its own pinned copy of the eight sentences, and that is an expectation with provenance
rather than a second authority: a document compared only against itself cannot detect its own rewording.
The principles page governs the wording; the pin exists so a divergence is loud, and a change to both in
one diff is the authorisation route. Leg 3 stays because it is a derivation and a record compared in two
directions, not a reading of any sentence, and because AC12 requires its count on the verdict line.

**The verdict line carries `principles`, `elements`, `surfaces`, `pages`, `statements` and `findings`,**
followed by the surface roster with each surface examined-clean, examined-with-findings or not-examined,
and the two surfaces excluded by design named with their reason. `statements` replaces the former
occurrence count: the false green this approach can have is a run that silently compared fewer
statements than the corpus holds, and that is the figure which surfaces it. The roster prints on the
cannot-run path too, for the reason § What is already in the tree gives. **[REDLINE R2.1]**

### How an accepted change is taken into the record

**The record is brought level by an explicit acceptance run of the verification itself**, which prints
the report it is about to take in and then rewrites the record from the current tree. Three properties
make this the defensible default the spec leaves to the design:

- It is a deliberate act and nothing else's side effect. No other command, and no part of the ordinary
  gate run, advances the record.
- The author reads what they are accepting in the same output, before the rewrite.
- The diff is **one row per changed file** against a 122-row file — a reviewable act, which a 2.52 MB
  text copy could not be. Acceptance is what makes AC14's steady state reachable more than once:
  measured end to end on a fixture copy of this corpus, an acceptance run followed by a verification run
  returns `clean | pages=122 statements=25759`.

The acceptance run writes the blob it records, so the object exists from that moment and becomes
permanently reachable when the accepted content is committed — the same change that lands the record.

**Acceptance DEGRADES rather than blocking, and that is a requirement rather than a convenience.**
Previous text is what a report needs, not what a rewrite needs, so a row whose recorded blob the
repository cannot produce is reported as a row with no previous text available and the record is still
rewritten from the current tree. Only the ordinary verification treats such a row as a cannot-run. The
asymmetry closes a trap that is otherwise reachable by an ordinary sequence — accept, then revert or
amend that content without re-accepting, then let garbage collection prune the unreferenced object:
the verification is then a cannot-run, the single entry point reads a cannot-run as a failure, the
documented escape is to commit the accepted content, and the commit is what the failure blocks. An
acceptance run that needs no previous text is the only exit that cannot be blocked by the thing it
exists to clear.

### Whether the record can be brought level in the same pass as the change it would have reported

This is the one place the approach is weaker than a check that carries its expectation inside itself, and
it is closed as far as the refusal reaches rather than left open.

**The record joins the refusal, and so does the acceptance route.** The guard gains a second,
one-member list holding the record's path, and fires on an edit to it by either route. The acceptance
route is a third condition class beside the two the shell arm already carries — a write construct, and a
write operand resolving into the guarded set — and it matches on **the shape of the invocation**: a
command invoking the verification and carrying the acceptance flag. **Where it sits is load-bearing:**
the arm's basename fast path returns early on a command that names no guarded basename, and an
acceptance invocation names the verification rather than a protected page, so the fast path's token set
must admit the record's basename and the verification's own, or the new condition is never reached. An
edit to the record and an acceptance run are then both put to the author, by the editing-tool route and
the shell route alike — so a pass that edits instruction material and brings the record level cannot do
the second half unprompted. **The self-improvement path is exactly such a pass, and this is what it
meets.**

That second list is deliberately **not** the list leg 4 compares against the protected-page table. The
record defines no required element, so admitting it to the protected set would make leg 4 report it as a
surplus interruption — correctly. It gets its own agreement assertion instead, in both directions: the
path the verification reads is the path the guard guards, following the derived-arms precedent the spec
names.

**The residual, named.** The refusal's own bound reaches the record as it reaches any protected page —
its six measured silent forms, and an `ask` a project that allow-lists the editing tools can let through
unprompted. The acceptance condition adds two of its own, both in the under-firing direction: the
payload invoked directly, which never spells the entry point the arm matches on, and an acceptance flag
reached through a variable or a shell alias rather than spelled in the command. No new exposure of any
other kind is added; the record inherits the refusal's.

### Decisions taken, with the alternatives rejected

| Decision | Why, and what was rejected |
|---|---|
| The record names a **blob per corpus file**; previous text comes from the repository's own history | A record carrying each statement's text measures 2.52 MB at `path <TAB> text` per row and would put every accepted change in the diff twice, in a repository where nearly every commit edits instruction material. A digest-only record was rejected for the opposite reason: a digest detects that a statement moved and cannot produce what it said before, which AC11 requires |
| The record is a **committed artefact**, not the previous commit | Comparing against `HEAD` needs no record and has no steady-state problem, and was rejected because acceptance would then be the commit itself: an addition would be reported before it was committed and silent for ever after, and the spec's own open question — whether the record can be brought level in the same pass — presupposes a record that can be edited and therefore guarded |
| The record lives under the **fixtures root** of the project-data directory | Measured in both directions against the reference gate: that root is admitted wherever a method file names it and a bare sibling is not, and it is the least-bad fit among the admitted roots rather than a match — § Where each thing lives names the three clauses of that root's contract the record diverges from, and the one it satisfies exactly. Admitting a new project-data path was rejected on cost, and widening this root's contract on the same ground one step smaller: the gate's list and the method page it mirrors must move together, that mirror is itself asserted, and the page is already over its own size warning |
| The comparison is a **multiset per file**, not a set and not a positional diff | Measured: 111 of 122 files carry a repeated normalised statement, so a set loses the removal of one of several identical lines. A positional diff would report a moved paragraph as a change, which is not one |
| **Every file is segmented every run**, and the sha fast path skips only the object fetch, the difference and the alignment | AC12's false green is a run that compared fewer statements than the corpus holds; a run that segmented only changed files would have no statement total in the clean case, which is the case the detector exists for. Measured over five runs, segmentation of the whole corpus costs 0.142–0.166 s against 0.011–0.012 s to hash — an order of magnitude, and a sixth of a second on a gate that already runs a four-minute member — and what the fast path actually buys is not the segmentation but the only super-linear step |
| Alignment is **token overlap within one file**, computed locally, with each statement's word set built once | It only pairs leftovers for presentation, so the threshold cannot change a verdict — which is what "a similarity judgement may only align" requires. Measured, hoisting the word sets out of the inner loop is 4.3× on the worst case, which is the difference between a second and five, and that one second on the largest file in the corpus is why the pairing carries no abandonment bound: a threshold with no value and no leg would be an uncalibrated one, which is half of why the row below rejects a hosted model. An embedding model was rejected outright: this gate runs before a commit and must return the same verdict on the same tree with no network call, and a hosted model would pin a model version as data and introduce a threshold nobody here can calibrate |
| A code surface's unit is the **line** | A line is the authored unit of a script, as a sentence is of prose. Applying the sentence rule to a shell script yields deterministic nonsense; extracting only the prose a script emits would require deciding which lines are instruction material, which is the judgement this approach exists not to make |
| The element cross-check stays as its **own leg** | It is a derivation compared against a record in both directions, it reads no sentence, and AC12 requires its count. Folding it into the comparison would lose the direction in which a widened record alone is reported |
| The payload stays **one sibling**, with leg 1's pinned sentences folded back in | The reason that settles it is the module load: a sibling that exists but cannot be loaded reports as findings rather than as a cannot-run, and one file removes that failure mode outright. The pinned data left beside the comparison is the eight sentences and one severity spelling, which do not earn a file of their own. The size consequence is **not** claimed as settled — § Risks carries it as expected rather than measured, with the split as the stated fallback **[REDLINE R2.1]** |
| The payload keeps `python3` | The three legs that survive are built and verified in it, and rebuilding them in shell to avoid an extension is work the amendment does not call for. The interpreter is already preflighted with its reason — the host `grep` has been measured answering `0` to a pattern it refused — and the two findings that attach to the extension are answered rather than tolerated: the payload is asserted present in the examined corpus and the record is asserted tracked — the index test, not the corpus test, since the record has no surface — and the payload's parse is asserted by the suite, which the single entry point runs |
| The report names every arrival rather than summarising a new file | AC11 exempts no region of an examined surface, and "this file is new, read it yourself" is such an exemption. The volume is priced in § Risks instead, with its measured figure |

### Measurement provenance

Measured against the working tree this round, with `git` and `python3`: the corpus is **122 files,
28,272 lines, 1,810,417 bytes** across five surfaces (profile 3, method 44, scaffolding 11, enforcement
20, verification 44, of which 53 files are markdown); **25,759 statements** under the two spellings
above — profile 305, method 6,925, scaffolding 290, enforcement 3,806, verification 14,433, so the code
surfaces are **71%** of the inventory; a text-carrying record is **2.52 MB** as `path <TAB> text` and
**2.81 MB** with a surface column, against the record as designed at **122 rows, 9,849 bytes**;
one-process hashing of the whole corpus takes **0.011–0.012 s** over five runs and segmenting every
file **0.142–0.166 s**, an order of magnitude apart, so the floor for a clean sweep is **0.152 s** —
a second instrument measured 0.013–0.014 s and 0.135–0.139 s for the same two passes, a floor of 0.149 s,
which is the agreement that makes the figure reproducible rather than local; **111 of 122** files carry a
repeated normalised statement; all **53** markdown files are re-wrap-stable at three widths; this
branch's own uncommitted change reports **18 of 122 files differing, 2,448 arrivals and 18 departures**,
of which 15 departures pair as a change at a 0.6 threshold; worst-case alignment, the largest corpus
file rewritten whole, is **1,464 × 1,464 = 2,143,296 ratios in 4.54 s naive and 1.05 s with word sets
built once**; the payload's current pattern machinery occupies **318 lines** of its 870 — a boundary
judgement to within a line or two — and the pinned data that survives beside it is **24** of the data
sibling's 218.

**The statement total moves with the rendering**, as every count of this kind does: a second rendering of
the rules above returned 25,799 against 25,759, a 0.16% spread. It is the figure the landed check prints
that the record is built from and that AC12 reports, never a figure transcribed from this document.

**Measured end to end on a fixture copy of the corpus**, with a prototype of the rules above, each plant
paired with the control that the unmutated copy is clean: each of the three sentences that a shape-reading
mechanism cannot be trusted with produces **exactly one arrival carrying that sentence's own text**, with
the statement count moving by one; rewording a principle reports a **change** at 0.92 carrying what it
said before; deleting the improvement pass's declining paragraph reports **three departures** with their
text; a mandate inserted only into the text a guard emits reports an **arrival** on the enforcement
surface; renaming a required element reports a **change** while the element count stays put; and a real
page re-wrapped at a different column stays **clean**.

**Measured on the live tree, both directions, for the two gates subtask 5's edits reach:** the bare
record path in a method file returns `major|L4|… is not a documented project-data path` at rc 1 while the
`fixtures/` spelling on the same line is silent, and the gate is clean once the probe is reverted; and a
backticked record path derives no required arm from the propagation table, because that gate filters
harvested tokens to markdown, shell and JSON spellings.

Taken from the spec without re-derivation: the per-path commit counts and the near-miss union, neither of
which this design depends on. The shipped version is already **0.1.46** against a released `0.1.45`.

## Decomposition

`M = 5`. Every surviving artefact named under § What is already in the tree is in the tree and is not a
subtask; no row below re-lands one.

**Three ordering constraints bind every subtask.** First, each subtask's own edits land inside the
examined corpus, so the verification reports them: each subtask therefore closes with an acceptance run
over its own change and a green pre-commit list, never carrying a red across a subtask or a handoff
boundary where nothing is left in context to explain it. Second, the suite is a member of that list and
asserts against the leg being replaced, so **the removal travels with the leg, in the same subtask** —
a suite left asserting a deleted mechanism reddens the list for every later subtask, and its mutant
builder copies the payload's siblings by name, so a deleted sibling breaks fixture construction
outright rather than failing one leg. Third, the payload must be visible to the index before the list is
run — `git add -N` on anything new, and the file COUNT the syntax gate processed read as well as its exit
status.

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **The comparison, the record and the acceptance route.** The payload's second leg becomes the inventory comparison: the two statement spellings, per-run segmentation of every file, the per-file sha fast path over the object fetch and the difference, the multiset difference, the alignment over the leftovers with each statement's word set built once — the measured difference between a second and five on the worst file the corpus holds, which is why it carries no abandonment bound — and a report line per arrival, departure and change carrying its text, its surface, the previous text where there is one, and the rule that produced it. The verdict line carries principles, elements, surfaces, pages, statements and findings, with the surface roster printed on the cannot-run path as well as the others, and the two by-design exclusions unchanged. An unreadable corpus file becomes a cannot-run. The pattern vocabulary, the per-occurrence dispositions, the residue ledger, the section roster and the corpus-wide token sweep are not part of this design and go with the leg; the pinned sentences and the one severity spelling fold back into the payload and the data sibling is deleted. **In this same subtask, and for the reason the second ordering constraint gives: the suite's legs asserting the replaced machinery go, and its mutant builder becomes a two-file copy** — it names the deleted sibling today and carries a header explaining why a mutant must be the whole check. The entry point gains the acceptance flag and its degrade-rather-than-block rule, the record's own preflights, and two assertions of different shapes, because the two files differ by design: the payload sibling is asserted present in the **examined corpus**, which it is, and the record is asserted **tracked** — present in the index — because it has no surface and corpus membership is a test it could never pass. A file read for its data while untracked makes the local run green and every other clone a cannot-run. Every other failure of a required input stays a cannot-run. **The header prose of both files moves with the code**: the entry point's own description of its four legs, its ledger-transcription rule, its stated BOUND and its sibling count, and the payload's naming of the deleted sibling — all of it sits inside the compared corpus, so stale text there is itself inventoried. The new BOUND is this design's: the comparison reports a change to a statement's text, never a meaning. Then the first acceptance run lands the record **[REDLINE S8.1]** **[REDLINE R2.1]** **[REDLINE R2.2]** | `scripts/check-plan-invariants.py`, `scripts/check-plan-invariants.sh`, `scripts/test-check-plan-invariants.sh`, `scripts/check-plan-invariants-data.py` (deleted), `ai-docs/fixtures/plan-invariants.inventory` | — |
| 2 | **The refusal covers the record and the acceptance route.** The guard gains a second one-member list holding the record's path, kept out of the list leg 4 compares against the table, and a third condition class matching an invocation of the verification that carries the acceptance flag — placed so the basename fast path cannot return before it, which means that path's token set admits the record's basename and the entry point's own. Leg 4 gains the two-direction assertion that the path the verification reads is the path the guard guards. The guard's suite covers both in both firing directions — an edit to the record and an acceptance run asserted to FIRE, a read of the record asserted SILENT — because neither direction is observable from the other, and asserts the two acceptance residuals silent so the bound is a measured fact. The registry is untouched, so no pinned record in the hook-behaviour suite and no prose count of hook entries moves | `hooks/lib/plan-invariants-guard.sh`, `hooks/lib/test-plan-invariants-guard.sh`, `scripts/check-plan-invariants.py` | 1 |
| 3 | **The comparison's legs, added to a suite that is already green.** Each is a mutation against a throwaway fixture tree carrying its own git history, since the comparison reads a blob the record names: the three sentences that defeated a shape-reading mechanism, each asserted to produce one arrival carrying its own text, each paired with the control that the unmutated copy is clean; a re-wrap asserted clean, which is where the 53-of-53 property is pinned; a reworded statement asserted to report what it said before; a departure asserted to carry the departed text; a mandate carried only in emitted text; a required element replaced with the count unchanged; an arrival planted inside a fenced block and inside a table row; a surface made unreadable asserted a cannot-run whose roster still reports it not-examined rather than counted clean; the record absent, unreadable, empty and naming an unrecoverable blob, each asserted a cannot-run distinct from clean and from red, paired with the acceptance run over the same tree asserted to complete; the payload and the record untracked, each asserted a cannot-run; and the payload asserted to parse, so a gate the single entry point runs does parse it. The suite's path and its place in the documented list do not change | `scripts/test-check-plan-invariants.sh` | 1, 2 |
| 4 | **The principles page.** Its honest limit keeps its first sentence — caught and named, never prevented — and its further bounds become this design's: the comparison reports a change to a statement's text, so a mandate that changes no statement is not reported; the record can be brought level in the same pass as a change, as far as the refusal does not reach; and the refusal recognises an edit by its shape, so an unrecognised writer reaches the page and is caught by the comparison instead. The authorisation route gains the row for bringing the record level. Nothing else on the page moves — the principles, the element record, both tables and the two-surface statement are already right **[REDLINE R2.1]** | `docs/plan-invariants.md` | 1 |
| 5 | **Registration prose, propagation, and the closing acceptance.** The documented item `5b` and the project context's entity block describe the four legs as they now are, with the verdict line's counts named as now printed; the language profile admits the payload's extension beside the three non-shell payload files already in the tree, in two other languages, and names how its parse is asserted; the propagation group's anchor and back-reference rows name one payload sibling and the record rather than a ledger and a roster, with the record spelled at the admitted path and every hook path kept in prose. **Two gates are re-run with their member lists read and not only their status:** the arms gate, whose derivation reads the table's backticked tokens, and the gate inventory, because item `5b` sits inside the span the runner parses to derive its own member set. The reference gate is run for the project-data spelling. Then the closing acceptance over the tree as this change leaves it, and the whole pre-commit list green — the run that proves AC14 on the real tree and that every earlier subtask's own acceptance was taken | `AGENTS.md`, `ai-docs/context.md`, `docs/propagation.md`, `ai-docs/fixtures/plan-invariants.inventory` | 1, 2, 3, 4 |

## Handoff plan

`M = 5` — two groups, 3 + 2.

- **Handoff into Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Step 8 binds a handoff at the start of every group, the first included.
- **Group A:** subtasks 1–3 — the comparison and the record, the refusal's cover of them, the comparison's suite legs. Grouped because leg 4's new agreement assertion needs the guard's second list to compare against, and the suite's new legs need both, so splitting them would leave a check reporting a finding it cannot resolve in its own group.
- **Handoff after Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh context.
- **Group B:** subtasks 4–5 — the principles page, then the registration prose, propagation and the closing acceptance. Terminal group (2 subtasks; within the 1..3 range).

## Risks

- **The report's volume on a change that adds files.** Measured on this branch's own uncommitted change:
  18 of 122 corpus files differ and the report is **2,448 lines**, of which 2,369 are the statements of
  seven new files. An ordinary prose edit is the order the spec priced — measured at +12/−4 on the
  profile's rule file and +19/−5 on the project context. Mitigation: none that preserves AC11, and that
  is deliberate — a per-file summary for a new file is exactly the exempted class the criterion forbids.
  What is offered instead is that the report is grouped by file, the verdict line carries the totals, and
  acceptance is one run. The figure is named here so that a later judgement that it is too high is a
  changed requirement travelling the amendment route rather than a defect in what was built.
- **The record can be brought level in the same pass as the change it would have reported, outside the
  refusal's reach.** Closed for both edit routes and for the acceptance route by subtask 2, so the
  residual is the refusal's own measured bound — its six silent shell forms, an `ask` let through by a
  project that allow-lists the editing tools, and the acceptance condition's own two: the payload invoked
  directly, and the flag reached through a variable or an alias. Mitigation: the suite asserts both
  firing directions and the two new residuals; and a reader of the principles page meets the bound there,
  because subtask 4 states it as one of the page's own.
- **A statement that changes nothing textually changes nothing in the report.** A mandate a reader infers
  from a statement whose words did not move is not an arrival and is not reported. This is the honest
  limit of a comparison, and it is the direction that cannot be closed by any mechanism this task may
  build. Mitigation: stated in the check's own header and on the principles page, so a clean run is never
  read as a proof.
- **An untracked page is outside the corpus by construction.** The surface list comes from the index, so
  a brand-new instruction page that was never staged is in no surface and is never compared. Mitigation:
  the repository's existing remedy and signal — `git add -N`, and the untracked member of the single
  entry point — plus the payload's own assertions that the files it reads for data are tracked, which is
  the case where the gap was measured to produce a clean sweep.
- **A recorded blob can become unreachable.** An acceptance whose content is never committed leaves a
  loose object that garbage collection may remove, and a shallow or partial clone may not carry the
  object at all. Mitigation: the ordinary verification reports a cannot-run naming the row, which is not
  a pass; the acceptance run writes the object rather than only computing its name; acceptance degrades
  rather than blocking, so the one exit from that state cannot itself be blocked; and committing the
  accepted content makes the object permanently reachable.
- **The segmentation rules carry three measured residual forms** — a wrap that breaks a token, one that
  leaves an orphaned number-and-period, and one that leaves a `|` at a line head. Mitigation: all three
  fail loudly rather than silently, which is the direction that matters; the list rule is the one that
  makes 53 of 53 markdown files re-wrap-stable at three widths, and subtask 3 pins that property as a
  leg rather than leaving it asserted here.
- **The payload's size after the leg is replaced.** The pattern machinery is 318 of its 870 lines and the
  pinned data that survives is 24 of a 218-line sibling, so roughly 576 lines stand before the comparison
  is written — and the comparison must carry two segmentation spellings, the fast path, the record's
  parse, the preflight failure modes, blob retrieval, the multiset difference, the alignment with its
  bound, report lines with rule provenance and previous text, and the acceptance mode, in a file that is
  roughly two fifths comment by house style. **The band that must be justified in a PR description is a
  likely landing zone rather than an avoided one**, and the hard limit is reachable. Mitigation: subtask
  1 reads the count after the edit; if it lands in that band the PR body owes the justification; if it
  approaches the hard limit the pinned data splits out again and keeps its tracked-corpus assertion, and
  the module-load failure mode comes back with it as a cannot-run rather than as findings.
- **The verification is a repository-local gate and ships with the toolkit anyway.** A consuming project
  that invokes it finds no record and gets a cannot-run naming it. Mitigation: reach into a consuming
  project is deferred by the spec, and a cannot-run is the honest outcome rather than a false green.
- **Subtask 5's edits reach three gates, and two of them are the kind that pass while being wrong.**
  The reference gate refuses an undocumented project-data spelling anywhere a method file names one;
  the arms gate derives its expected arms from the propagation table's backticked tokens while
  requiring the hook registry's own paths to stay silent; and the gate inventory derives its member list
  from the span item `5b` sits in. Mitigation: the record is spelled at the admitted path, measured in
  both directions; every hook path stays in prose, which is measured to be necessary because a backticked
  hook path does derive a required arm while the record's path cannot; and both derived gates are re-run
  with their member counts read rather than only their status.
- **Five of the seven protected pages are plausible targets of this task's own work, and the record is now
  guarded too.** The refusal therefore fires during the work that installs it, and during every
  acceptance. Mitigation: the author-allows path is the authorisation route and the suite asserts it, so
  landing the protection never requires switching it off.

## Test Design

- **Base fixture:** a throwaway tree per leg, carrying only the files that leg reads, **with its own git
  history** — the comparison reads a blob the record names, so a fixture without a commit and a staged
  index reports a clean sweep over a corpus that does not contain the plant. The record is written by an
  acceptance run inside the fixture before any mutation, and the unmutated copy is asserted clean before
  each plant. A mutant of the check is **the whole check**: the entry point and its payload, since the
  entry point loads the payload from its own directory and a part-copied mutant would run the unmutated
  code beside the planted defect.
- **Entry points:** the verification with no arguments, with a root override and with the acceptance
  flag; the guard fed a payload on standard input; the single entry point with a root override.
- **Every plant is paired with a control.** A plant that reddens proves nothing on its own; the pair is
  what shows which rule is responsible. Every leg whose failure mode is empty output is additionally
  shown able to come back non-empty.
- **The three sentences are legs of their own**, since they are what a shape-reading mechanism cannot be
  trusted with: a required part of the design whose content cannot exist when the document is authored;
  the same mandate stated beside a reading verb; and the same mandate whose object names a section the
  record already carries. Each must be reported as one arrival carrying its own text, with the statement
  count moving, and each is paired with the clean control on the same page.
- **Both firing directions of the refusal**, because neither is observable from the other: a write to the
  record and an acceptance run asserted to FIRE, a read of the record and a read of a protected page
  asserted SILENT, and the two acceptance residuals asserted silent.
- **The cannot-run family in full:** the record absent, unreadable, empty, or naming an object the
  repository cannot produce; a corpus file unreadable; the payload or the record untracked. Each asserted
  distinct from clean and from red, asserted to be treated as a failure by the single entry point, and —
  for the unrecoverable blob — paired with an acceptance run over the same tree asserted to complete.

- AC1 verified by: that the shipping document presents each principle as one numbered sentence carrying
  its own one-clause reason, and that the count a reader arrives at end to end equals the count the
  verification reports — with the control that a principle stripped of its reason is not counted present.
- AC2 verified by: that the authoring-time test stands as a principle in its own right and that its
  sentence names both failures it guarantees, with the control that a version naming only one of the two
  is reported as a wording difference rather than passing.
- AC3 verified by: that rewording exactly one principle, with nothing else touched, turns the
  verification red and that the finding identifies which principle changed rather than only that
  something did.
- AC4 verified by: that removing a principle entirely is reported as an absence, observably different in
  the output from what a reworded principle produces, with the control being the same tree reworded
  instead of emptied.
- AC5 verified by: that a sentence asserting a principle's negation, planted in a rule document the
  agents read, turns the verification red and puts that sentence's own text and its surface in front of a
  reader — with the control that the same page unmutated is clean, so the arrival is what reddened it and
  not the page.
- AC6 verified by: that an instruction mandating an element outside the enumeration turns the
  verification red by two independent routes — the derived element set disagreeing with the record, and
  the mandating statement itself arriving with its text — demonstrated on an element chosen to contradict
  no principle, which is the case a hunt for a principle's opposite passes green.
- AC7 verified by: that the identical planted mandate reddens the verification when it lands on a page
  the refusal does not cover, paired with the same mandate on a refused page, both required red, so the
  catch is shown not to depend on the page being refused.
- AC8 verified by: that making an element mandatory purely by treating its absence as a blocking finding
  in a review contract, with no template altered anywhere, is reported as an arrival carrying that
  statement's text, so the quieter of the two routes to a new requirement needs no route of its own.
- AC9 verified by: that a mandate planted in the instruction that tells the design author what to write
  is caught, in the shape of the edit that caused the measured damage — a required part of the document
  whose content cannot exist when the document is authored — and not only one planted on the page that
  lists the principles.
- AC10 verified by: that replacing one required element with another, leaving the number of required
  elements unchanged, is reported with the element that arrived and the one that went, the control being
  that the element count on the verdict line is identical before and after, so only a comparison of sets
  could have seen it.
- AC11 verified by: that an arrival, a departure and a change are each reported with the statement's own
  text and its surface, that the change additionally carries what it said before, that each line names
  the rule that produced it, and that the statement total moves when a statement is added — with the
  control that no region is skipped, shown by planting inside a fenced block, inside a table row and
  inside the text a guard emits, and requiring each to be reported like any other.
- AC12 verified by: that the verdict is accompanied by the number of principles, enumerated elements,
  surfaces, pages and statements compared, that the statement total is reported on a run where nothing
  changed as well as on a red one, and that narrowing any one of those inputs moves its figure while the
  verdict alone would not have — so a run that examined less than the full corpus is distinguishable from
  a clean one. **[REDLINE S8.2]**
- AC13 verified by: that each way a run can be prevented from completing reports an outcome distinct from
  both clean and red, that the single pre-commit entry point treats that outcome as a failure rather than
  a pass, and that the surface roster is still printed on that path.
- AC14 verified by: that the verification is clean over the real tree as this change leaves it, not over
  a fixture; and that a change a reader accepts can be taken into the record, after which the
  verification is clean again — demonstrated as a cycle: clean, mutate, red, accept, clean, with the
  controls that the acceptance run reports what it took in before taking it, and that it completes on a
  tree where the ordinary verification cannot.
- AC15 verified by: that an edit to a page which defines or enforces a required element is put to the
  author whatever the edit touches, demonstrated with a change to a paragraph having no bearing on
  either document's composition, and that the refusal names the page and what would permit the edit —
  with the paired control that merely reading the same page is not put to the author, by each route an
  edit can take.
- AC16 verified by: that a page carrying an element-defining rule while uncovered is reported, that a
  covered page carrying no such rule is reported too, and that the record's own guarded path is asserted
  to agree with the path the verification reads in both directions — each by its own mutation, so no
  direction rests on another passing.
- AC17 verified by: that allowing a refused edit lets it proceed, so a protected page and the record can
  both be changed by the author landing the protection without the protection being switched off.
- AC18 verified by: that removing or rewording the declining rule in either automated pass is reported
  with the departing text, so the contract that routes this class to the author cannot be weakened
  unseen — with the control that the unmutated pages are clean. **The criterion's behavioural half is met
  by that contract's own text being pinned inside the examined corpus, which is the closure every
  instruction-contract criterion in this repository gets; no mechanism here observes obedience, and this
  line claims none.**
- AC19 verified by: that the principles document states its own limit in its own text, and that removing
  or weakening that statement is reported as a departure carrying it.
- AC20 verified by: that the documented list of pre-commit checks and the list the single entry point
  runs agree in both directions after this change, demonstrated by removing the member from each side in
  turn and requiring the inventory to report it each time.
- AC21 verified by: that the shipped version recorded in the distribution manifest is higher after this
  change than the released one.
- AC22 verified by: that starting from a tree the verification finds clean, a rule requiring a new
  element carried only in the text the agents receive as a session or a tool use begins — written on no
  page they open — is reported with its own text and its surface, exactly as the same mandate added to a
  page is, with the page-borne version as the control.
- AC23 verified by: that a surface the refusal deliberately does not cover is still examined, and that
  the report tells a surface that was not examined apart from one examined and found clean —
  demonstrated by making one surface unreadable and requiring the roster to report it not examined rather
  than counting it among the clean, on a run whose outcome is itself distinct from clean.

## Open questions

- **Whether the report's volume stays proportionate once the corpus is in its steady state.** Measured at
  2,448 lines for this change, dominated by new files, against tens of lines for an ordinary prose edit.
  The figure to revisit against is the one the landed check prints over the next few tasks, not the one
  here. Revisit with a count rather than on a judgement.
- **Whether the similarity threshold wants moving.** It cannot change a verdict, only whether two lines
  are presented as one, so this is a readability question. Measured once, on one change: 15 of 18
  departures paired. Revisit if a reader reports reading pairs that do not belong together.
- **Whether a contradiction or an addition found in a consuming project's own profile is in remit.**
  Deferred by the spec; the principles document and the contracts ship either way.
- **Whether the refusal's own registration is protected against later removal.** The enforcement layer is
  deliberately outside the refusal set, and the comparison reports a departure as readily as an arrival,
  so the guard's own emitted text and its registered command both sit inside the examined corpus and
  their removal is reported. Whether that is enough, or whether the registration wants the derived-arms
  treatment, is left open with that route recorded.
- **How a ninth principle is admitted.** The same authorisation route as changing one, because an
  addition can contradict a sentence already there. Revisit when one is actually proposed.
- **The residual the protected-page boundary accepts, named rather than guarded.** Removing the sanctioned
  home for the identifiers the third principle keeps out of the design is now reported as a departure
  carrying its text, which is what the comparison buys over a rule that hunts for a shape. What stays
  unguarded is the edit itself: that page is deliberately outside the refusal.
