# Design: Protect the base terms and the form of the spec and design from the self-improvement path

**Ticket:** GH-116
**Date:** 2026-10-13
**Spec:** ai-docs/plans/2026-10-11-plan-invariants.spec.md

**Scope — this is GH-116's as-built design.** It states the mechanism this change shipped. A figure
appears below only where a decision turns on it: a gap between two costs, a crossed threshold, a ratio,
an observed behaviour. Where one does appear it carries the operands that make it re-derivable and the
occasion it was measured on, because a ratio without its operands is unfalsifiable rather than durable.
The totals `bash scripts/check-plan-invariants.sh` itself prints — its figure line and its surface
roster — are that run's to report and are not copied here; § Measurement provenance names which totals
those are, read off a bare run, and which of the figures below are instead this pass's own measurement.

## Approach

Three layers: a document of base principles, a mechanical verification, and an edit-time refusal on the
pages that define document composition. The verification carries four legs, and the load-bearing one is a
**comparison against a recorded inventory of statements** — it reads no sentence and rules on nothing.

**Why a comparison rather than a reader of sentences**, in the findings that bound the whole design
space: published work on telling a sentence that CHANGES a rule system apart from one that DESCRIBES it
reports no sharp demarcation within natural language, selection by modal verb is incomplete in both
directions, and the best reported classifiers of obligation sentences sit near 0.90 accuracy — so a
protection whose bar is "nothing lands silently" may not rest on that distinction being decided for it,
and cannot be tightened to completion, because there is no boundary for it to converge on. Version
comparison is the proven architecture for this shape of problem, and the three rules it travels with are
stated where they bite, in § The alignment below.

### Where each thing lives

| Artefact | Role |
|---|---|
| `docs/plan-invariants.md` | The eight principles as numbered sentences with their reasons; the required-element record; the protected-page table; the near-miss table; the two-surface statement; the authorisation route; the honest limit stated first |
| `scripts/check-plan-invariants.sh` | The verification's entry point — the flags, the preflights, the three-outcome convention, the acceptance route, and the prose contract of all four legs |
| `scripts/check-plan-invariants.py` | The first payload sibling: the corpus, legs 1 to 3, the inventory comparison and the report. It is the one artefact here whose size is load-bearing: it sits against this repository's hard 1000-line limit, and § Risks prices that margin |
| `scripts/check-plan-invariants-refusal.py` | The second payload sibling: leg 4 and nothing else, loaded by the first |
| `ai-docs/fixtures/plan-invariants.inventory` | The record the comparison reads: one row per corpus file |
| `scripts/test-check-plan-invariants.sh` | The verification's suite |
| `hooks/lib/plan-invariants-guard.sh` and its suite | The edit-time refusal, registered on two `PreToolUse` matchers |

The principles document is **method**: it describes what a spec and a design ARE, which holds in every
project, and it names no language, build tool, domain entity or ticket prefix. The record is
**profile** — an inventory of this repository's own instruction material is a project fact.

**The record's exact path is forced by two gates and was measured rather than chosen on taste.** The
reference gate admits only an enumerated set of project-data paths wherever a method file names one, and
`ai-docs/fixtures/` is in that set while a bare `ai-docs/` sibling is not: measured on this tree, both
candidate paths planted on one line of a method file, the bare sibling returns
`major|L4|… is not a documented project-data path` at rc 1 while the `fixtures/` spelling is silent in
the same run, and the gate is clean again once the probe is reverted. **That root is the least-bad fit
among the admitted ones rather than a match, and the divergence is named here so the next reader does not
build on a false premise.** Its full contract asks for one subdirectory per corpus, each carrying an
input, a derived mapping and a baseline holding a measured expectation with the input's checksum; for an
input a gate REPLAYS so a detector meets what it ships against; and for a fixture that is not refreshed
as routine maintenance. The record diverges on all three: it is a maintained record rather than a frozen
replay input, it is one file at the root rather than a corpus subdirectory with a baseline and a
checksum, and the gate compares against it rather than replaying it. One clause does fit exactly, and it
is the one that matters most here — changing a fixture means changing its baseline on purpose, in the
same commit, which is the acceptance discipline. The two alternatives were weighed and both cost a
method-file edit: admitting a brand-new project-data path moves the gate's list **and** the method page
it mirrors, with the mirror asserted by that gate's own audit mode, on a page already over its size
warning; widening this root's documented contract to admit a maintained record is cheaper but still
rewrites a method contract to accommodate one project artefact. Naming the fit honestly costs nothing and
leaves the measured gate admission untouched. **The second gate is satisfied either way, and this is
measured too:** a backticked record path harvested into the propagation table derives no required hook
arm, because the arms gate filters harvested tokens to markdown, shell and JSON spellings — so the record
needs no arm, while a backticked hook path still would, which is why hook paths stay in prose there.

The record is outside the examined corpus, and that is structural rather than arranged: the profile
surface is an explicit three-name enumeration, so any other file under the project-data root falls
through the surface rule and belongs to no surface. A record inside its own corpus could not be brought
level without changing the thing it records. It is accounted for by name rather than by an exclusion
rule — one file is not a class, and a roster line for it would read as a fourth excluded surface.

### What the change inherited rather than built

Each of these was in the tree when this design was authored, and no subtask below re-lands one.
Confirmed against the files themselves.

1. **The principles document** — eight numbered byte-stable sentences with their reasons, the
   required-element record keyed by document and token, the protected-page table with a reason per
   member, the near-miss table, the authorisation route, the honest limit stated first; registered in the
   method root's agent-doc table and in the docs index. AC1, AC2, AC19.
2. **The edit-time refusal** — the guard on the file-editing matcher group and on the `Bash` group, its
   own suite, and its two pinned expectations plus their payload builders in the hook-behaviour suite.
   AC15, AC16, AC17.
3. **Leg 1** — each pinned principle sentence present and unchanged, an absence reported distinctly
   from a wording difference. AC3, AC4.
4. **Leg 4** — the live refusal coverage against the protected-page table in both directions, the
   near-miss controls, and the element-defining-locus sweep. AC16.
5. **Leg 3** — the required-element set derived from three loci and compared against the record on the
   principles page in both directions, with the fold's heading prohibition read on its own arm. AC6
   partly, and the `elements=` figure AC12 requires.
6. **Registration** — the `plan-invariants` member of the single pre-commit entry point, the documented
   item `5b`, the documented suite list, the pinned member table in the runner's own suite, and the
   prose sites that count the structural checks. AC20. The member's name and the suite's path do not
   change, so no part of that registration moves again.
7. **The propagation group** and the arms it adds to the hook registry.
8. **The version bump.** The distribution manifest carried `0.1.46` when this change landed, above the
   released `0.1.45`. AC21. Later work has moved it on, as every PR touching plugin-loaded content must.
9. **The improvement-pass contract** and the second autonomous-edit route closed in the escalation
   audit's category 2. AC18.

**Two of those nine were extended rather than left alone**, and the extensions are the decomposition's
work rather than this section's: the refusal gained the record's own one-member list and the acceptance
condition (§ Decomposition, subtask 2), and the principles page gained the authorisation row for bringing
the record level and the three narrower bounds that follow from its limit (subtask 4). What the
inherited and the extended share is that nothing in this list was rebuilt.

### The inventory, the record, and why the record is not a copy of the text

The corpus is a closed set of surfaces, so the statements it carries are an inventory. The verification
records that inventory and compares the tree against it, reporting every statement that arrived,
departed, changed or — in a file taking the code spelling — moved, with its own text, its surface, and on
a change what it said before.

**What the corpus measures — its files, and the statements they segment to — is what the check prints**,
and `bash scripts/check-plan-invariants.sh` is the authority on those two totals; its line and byte
totals are on neither its figure line nor its roster, and § Measurement provenance says so rather than
leaving a reader to look for them. The design turns on a consequence of them rather than on their
values: a record carrying each statement's own text, at one row of `path <TAB> text` per statement,
comes out **larger than the corpus itself**, and larger again if the row also carries its surface,
because every row repeats its path. The row format is stated because it is what makes that
reproducible, and both spellings reach the same
conclusion. The decisive cost is not the landing size: every accepted change would appear twice in the
same diff, once in the edited file and once in the record, in a repository where nearly every commit
edits instruction material. The record would become the largest and noisiest file in the tree, and a
reviewer would read every instruction change twice.

**So the record names its comparand instead of copying it.** One row per corpus file:

```
<surface>  <blob sha>  <path>
```

That shape puts the record **more than two orders of magnitude** below a text copy of the same
inventory, and the ratio rather than either size is why it stays a reviewable artefact. **Both operands,
measured at this pass by driving the shipped segmenter over the tracked corpus:** a `path <TAB> text`
copy of the inventory is **2,658,610 bytes**, and the record as designed is **9,852 bytes in 122 rows** —
a factor of **270**, and the copy is **1.4× the 1,862,488 bytes of corpus** it would be duplicating,
which is the "larger than the corpus itself" above. The two sizes move with the corpus and the ratio is
what the decision rests on; they are written down so a later reader can take the measurement again
instead of taking the ratio on trust. The repository is a git repository and the payload already shells
out to `git`, so the blob the row names is the exact previous text — recoverable with `git cat-file`,
byte-for-byte, with nothing duplicated. A row carries
nothing derivable from that blob: a statement count beside it would be a second record of one fact and
could only come to disagree with it.

**The comparison, per file:**

1. **Every corpus file is segmented on every run**, and the statement total the verdict line carries is
   the sum over all of them. This is not an optimisation question: AC12's false green is a run that
   silently compared fewer statements than the corpus holds, and a run that skipped segmentation for
   unchanged files would have no total to report in exactly the clean case. Measured over five runs at
   this pass, the cost is affordable and is paid: hashing the whole corpus in one process takes
   **0.009 s** and segmenting every one of its files **0.075–0.083 s**, an order of magnitude apart, and
   a clean sweep of all four legs end to end — interpreter start, the object store and the report
   included — is a fraction of a second, on a gate list that already carries a four-minute member.
2. **The current blob sha of every corpus file is taken in one process**, and a file whose sha equals its
   recorded sha skips the three steps that follow — the previous-text fetch from the object store, the
   multiset difference and the alignment. That is what the fast path buys: not the segmentation, but a
   `git cat-file` per file and the only super-linear step in the check.
3. Otherwise both versions are segmented and compared as **multisets**. A multiset rather than a set
   because **nearly every corpus file carries a repeated normalised statement**, so under set semantics
   the removal of one of three identical lines would be invisible. The decision holds at any count above
   zero, which is why the property rather than the count is the claim; measured at this pass the count is
   **110 of 122**, the twelve exceptions being three directory placeholders, a gitignore fragment, a
   settings manifest and seven prose pages.
4. The multiset difference is the exact-match answer: what is in the tree and not the record has
   arrived, what is in the record and not the tree has departed. **For the files taking the code
   spelling the ORDER is compared as well.** A statement that merely moved is in both multisets, so both
   lists come back empty while the sha still differs — and in that exact state the two sequences are
   permutations of each other, so the statements that changed position are reported as their own answer,
   a **relocation** naming each moved line with the statement ordinal it left and the one it arrived at.
   Ordinals rather than file line numbers, because the code spelling drops blank lines and printing one
   as the other sends a reader to the wrong place. In prose a move is still not a change, which is the
   bound that keeps a re-wrap silent. The reason the fourth answer exists is measured: moving the
   entry point's line that executes the payload above its own three cannot-run guards makes all three
   unreachable while leaving the file's line multiset identical, so the exact-match answers are silent on it by
   construction. The position alignment runs with the junk heuristic disabled, because the commonest
   statements in these scripts — a bare `else:`, a closing brace, `fi` — are exactly what that heuristic
   discards, and without them anchoring the alignment a one-line move reports as a hundred.
5. The leftovers are then aligned, and only then — § The alignment below.
6. A path in the corpus with no row has arrived whole; a row with no path has departed whole. Both are
   reported statement by statement, because no region of an examined surface is exempt.

**Nothing is set aside.** There is no class of passage the comparison treats as harmless, so a change can
be absent from the report only by not having happened. What a reported change MEANS is a reader's
judgement on the report, which is the division of labour the rest of this task already rests on.

### The statement, and its two spellings

The unit is part of the contract, so both spellings are stated here rather than left to the
implementation. Both collapse the **internal** runs of whitespace to one space, because these documents
hard-wrap and a unit evaluated line by line is evaluated on a wrap fragment. **They differ on the LEADING
whitespace: the code spelling keeps it inside the statement and the prose spelling drops it.** The
normaliser the two share strips as well as collapses, so the code spelling captures each line's indent
before normalising and puts it back in front of the result.

**Markdown takes the prose spelling and everything else takes the code spelling**, and that split was
measured rather than assumed: every non-markdown file sitting on one of the three prose surfaces is
line-oriented data rather than prose — a settings manifest, empty directory placeholders, a gitignore
fragment — so the extension test puts none of them under the sentence rule. The check's roster counts files per
SURFACE and not per spelling, so the split itself is this pass's measurement: **53 of the 122 corpus
files take the prose spelling and the remaining 69 the code spelling.**

**On a prose surface** a statement is one sentence, one list item, or one clause the author separated
with a semicolon, read over the text of a paragraph joined across its hard-wrapped lines. A backtick span
is opaque, so a path, a flag or a code span carrying a sentence terminator does not cut the sentence it
sits in, while a terminator inside closing markup still ends its sentence — `artefact.**` is this
corpus's commonest sentence end. Four shapes are **line-oriented** rather than paragraph-joined, because
each is its own authored unit and none of them wraps: a heading, a table row, a line inside a fenced
block, and a line inside the YAML front matter at the head of a file. A line is classified with its
blockquote markers stripped while the statement keeps the text as authored, because this corpus states
whole tables and fenced blocks inside a quote and a rule reading the raw line would join those rows into
one paragraph. A heading needs the space after its hashes, which is what the markup itself requires and
what a residual form argues for: measured, re-wrapping this corpus at 72 columns puts `#89):` from a
wrapped `PR #89)` at the head of a line, and a rule keyed on a bare `#` reads that as a heading, breaks
its paragraph in two and reports a change, an arrival and a departure for a reflow that changed no words.

One further rule is load-bearing and was measured rather than assumed: **a list item is recognised only
where a list can begin** — after a blank line, a heading, a fence or a table row, or while a list is
already running — never mid-paragraph, because a re-wrap can put a number-and-period at the start of a
line and a rule that trusted the line start would then read half a sentence as a new item.

**The property that rule exists for:** re-wrapping a paragraph is not a change to the inventory, while
re-writing a sentence is — and where a re-wrap does reach the inventory it must reach it LOUDLY rather
than silently. **Measured at this pass** over the corpus's **53 markdown files**, each re-filled at
**72, 88 and 110 columns** by an instrument that re-wraps the ordinary hard-wrapped paragraphs and list
items and leaves the shapes this rule treats as line-oriented alone: **all 53 of the 53 came back with
an identical statement multiset at all three widths**, which is the whole set against itself, and a leg
of the suite pins that property rather than leaving it to this measurement. The list rule earns its
place on the same measurement: with its "where a list can begin" guard removed and everything else
held, the same instrument at the same widths leaves **51 of 53** identical, against a control confirming
the guard-less segmenter already differs from the shipped one on eleven files before any re-wrap. A
blockquote paragraph sits outside that instrument on purpose — the statement keeps its `>` markers as
authored, so re-wrapping one changes the statement by this rule's own definition instead of testing it.
Three residual forms are named rather than hidden, and all three fail in the loud direction — each
reports a departure plus an arrival instead of nothing:

- a wrap that breaks a token across lines, so the joined text differs by that token;
- a wrap that leaves a number-and-period at the head of a line with no list for it to continue;
- a wrap that leaves a `|` at the head of a line, which the table-row rule then reads as a row. Live
  shapes exist for this: an inline code span carrying pipe characters is in the corpus today.

**On a code surface a statement is one non-empty line: its leading indentation plus its internally
collapsed text.** The shell, `python`, `awk`, `jq` and JSON payloads of the enforcement and verification
surfaces are in the corpus — the element lists live there as data, and the text the enforcement layer
hands an agent as a session or a tool use begins is instruction material the agents RECEIVE. A line is
the authored unit of all of them, as a sentence is the authored unit of prose, and the two rules are
deliberately different because segmenting a script into sentences and segmenting a paragraph into
sentences are not the same operation. **The indent is kept because in a script it is scope rather than
layout, and the cost of dropping it was measured on this check itself:** de-indenting its own
principle-wording comparison out of the loop that drives it produced a **clean** verdict with every
surface reported examined-clean, with a control proving the mutant was live — so a stripping rule let the
check call a tree clean in which its own first leg had been disabled. A de-indentation leaves both the
multiset and the order identical, so every other answer the comparison has is silent on it too; keeping
the indent inside the statement is what makes it a change to the statement's text. The cost of the code
rule is stated in the other direction as well: re-wrapping a multi-line message a guard EMITS reports a
departure and an arrival rather than nothing. **Most of the inventory is code rather than prose** — the
verification and enforcement surfaces together carry **19,011** statements against **8,360** on the
profile, method and scaffolding surfaces between them, a factor of **2.3** — so the code rule, and with
it the kept indent, governs the bulk of what is compared. The GAP is the claim and the two sums are its
evidence. They are this pass's own measurement rather than a figure the check hands back: its roster
prints a FILE count per surface and no statement breakdown, so a reader re-derives these by segmenting
the surfaces and summing.

### The alignment, and the three rules it obeys

Exact match runs first, by construction: the multiset difference is complete before anything else looks
at the leftovers. Each remaining arrival is then paired with the remaining departure it most resembles,
by a token-overlap ratio over the normalised words, within the same file, each departure claimed at most
once. A pair at or above the threshold of **0.6** is reported as one **changed** line carrying both the
new text and what it said before; anything unpaired is reported as an arrival or a departure carrying its
own text.

- **The similarity judgement may only ALIGN.** It cannot change the verdict — every leftover is reported
  either way, and the only difference is whether two lines are presented as one. That is a structural
  property of where the pairing sits, not a promise about a threshold.
- **No entailment judgement is taken.** None is delivered here. If one is ever added it may only put
  evidence beside the deterministic result, in both directions, and never arbitrate.
- **The deterministic comparison takes precedence and every line is traceable to the rule that produced
  it.** Each report line names its rule — exact match, the whole-file arrival or departure, the
  relocation, or alignment with the ratio it was paired at.

The ratio is local arithmetic over two word sets: no model, no network, and the same verdict on the same
tree. Measured on real statements of this corpus at this pass: **0.90** for the one word the suite's own
rewording leg changes in a method page's sentence, **0.78** for a principle reworded by two words, and
**0.05** for two unrelated statements — and, measured over this change's own diff while it was being
built, **15 of 18 departures** paired with a reworded arrival at this threshold.

**Its cost is the only super-linear step in the check, so its bound is stated, and one implementation
constraint follows from the measurement rather than from preference.** The pairing is per file and never
crosses files, so the worst case is one large file rewritten whole — every remaining arrival against
every remaining departure, a product of the file's own statement count with itself. **Measured at this
pass on the largest file the corpus holds, at 1,464 statements:** a nominal **1,464 × 1,464 = 2,143,296**
comparisons, of which **1,115,985 — 52%** are actually performed, because a departure already claimed is
not offered again. **Building each statement's word set once rather than rebuilding it per comparison
runs that worst case in 0.45 s against 1.13 s, a 2.5× saving**, best of three runs each, which is why
the hoist is part of the design and not a later optimisation. The statement count is the operand a
reader re-scales on, and it is recorded for that: the step is quadratic in it, so a corpus whose largest
file doubles pays four times this. **Under half a second on the worst file the corpus holds is why the
pairing has no bound above which it stops** — a mode with no value, no
criterion and no suite leg would ship a second reporting path nobody had exercised, and an uncalibrated
threshold is the thing this design rejects a hosted model for.

### The legs, and what each one answers

| Leg | Question | Where it lives |
|---|---|---|
| 1 | Is each pinned principle sentence present and unchanged, with an absence reported distinctly from a wording difference | The first payload sibling |
| 2 | Does the tree's statement inventory match the record, and what arrived, departed, changed or — in a file taking the code spelling — moved | The first payload sibling |
| 3 | Does the required-element set derived from the three loci agree with the record on the principles page, in both directions, and is the fold's heading prohibition read as a prohibition rather than merged into the element set | The first payload sibling |
| 4 | Does the live refusal coverage agree with the protected-page table in both directions, is the guard still registered, does the guarded record agree with the record the check reads, and does every tabled page still carry an element-defining locus | The second payload sibling, loaded by the first |

Leg 1 keeps its own pinned copy of the eight sentences, and that is an expectation with provenance
rather than a second authority: a document compared only against itself cannot detect its own rewording.
The principles page governs the wording; the pin exists so a divergence is loud, and a change to both in
one diff is the authorisation route. Leg 3 stays its own leg because it is a derivation and a record
compared in two directions, not a reading of any sentence, and because AC12 requires its count on the
verdict line.

**The verdict line carries seven figures — `principles`, `elements`, `surfaces`, `pages`, `statements`
and `unaccounted` beside `findings`** — followed by the surface roster with each examined surface marked
examined-clean, examined-with-findings or not-examined, and the three surfaces excluded by design named
with their reason and their file count. `statements` is the figure that surfaces this approach's own
false green: a run that silently compared fewer statements than the corpus holds. **`unaccounted` reads
the other way from the five figures beside it** — those should be large and it should be zero, because a
non-zero value names tracked files that are on no surface and in no named exclusion, about which the
report then says nothing at all. It is there because that state was reached: eight tracked files sat
outside both sets while every run read as clean, and a mandate appended to one of them gave a clean
verdict with that file appearing nowhere in the output. So **each exclusion carries a membership rule and
not only a name** — the plan documents under this tree, the learning record as the union of its index
file and its directory of entries, and the repository's own mechanics as three path prefixes plus two
named files — and the three rules partition the surfaceless tracked files instead of labelling three
classes beside an unexamined remainder. **None of the three is a catch-all, deliberately:** a final rule
taking whatever was left would hold `unaccounted` at zero by construction, which is this approach's own
false green wearing the shape of a measurement. The record is accounted for by name rather than by a
rule, for the reason § Where each thing lives gives. The report prints the unaccounted PATHS and not
only the figure, because a count of files nothing else in the report mentions is a reader's dead end: the
remedy is either a surface or an exclusion, and both decisions need the names.

**A finding names the surface it belongs to rather than being matched back to one by its text**, and that
is a requirement rather than a detail: the report quotes whole statements and a statement names other
files, so a roster built by searching finding text reported a surface as carrying findings that belonged
to another. Passing the surface is a separate act from computing it, which is how a leg that had the
surface, interpolated it into the line and stopped there left the roster calling the surface carrying its
findings examined-clean.

**The roster prints on every path, the cannot-run included**, because it is what tells a surface that was
not examined apart from one examined and found clean — and a cannot-run is exactly the outcome where that
distinction is live.

**What a clean verdict actually says is read off the run, not off this document.** This design fixes the
shape above; `bash scripts/check-plan-invariants.sh` prints the values, and its output is the authority
on every one of them. They move with the next edit to the corpus, and the three excluded file counts
move whenever anyone lands a plan document, a learning entry or a repository config file — which is why
a roster leg asserts that a file count is NAMED and pins no value.

### How an accepted change is taken into the record

**The record is brought level by an explicit acceptance run of the verification itself**, which prints
the report it is about to take in and then rewrites the record from the current tree. Three properties
make this the defensible default the spec leaves to the design:

- It is a deliberate act and nothing else's side effect. No other command, and no part of the ordinary
  gate run, advances the record.
- The author reads what they are accepting in the same output, before the rewrite. The acceptance
  verdict then states how many rows it wrote and how many report lines it took in, beside the same seven
  counts the ordinary verdict carries.
- The diff is **one row per changed file** against a record of one row per corpus file — a reviewable
  act, which a text copy two orders of magnitude larger could not be. Acceptance is what makes AC14's
  steady state reachable more than once: the suite's own fixture is built by accepting over a fresh copy
  of the tracked tree and then requiring the unmutated copy to verify clean, so the cycle is pinned by a
  leg rather than by a one-off figure.

The acceptance run writes the blob it records rather than only computing its name, so the object exists
from that moment and becomes permanently reachable when the accepted content is committed — the same
change that lands the record. An acceptance run is also exempt from the record's own preflights and from
the index test, because the first one creates the file.

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

**The record joins the refusal, and so does the acceptance route.** The guard carries a second,
one-member list holding the record's path, and fires on an edit to it by either route. The acceptance
route is a third condition class beside the two the shell arm already carries — a write construct, and a
write operand resolving into the guarded set — and it matches on **the shape of the invocation**: a
command naming the verification's entry point and carrying the acceptance flag, because an acceptance run
rewrites the record with no write construct appearing in the command at all. **Where it sits is
load-bearing:** the arm's basename fast path returns early on a command that names no guarded basename,
and an acceptance invocation names the entry point rather than a protected path, so that token set admits
the record's basename and the entry point's own. Admitting the entry point's token costs no surplus,
because what fires is still decided by the guarded-path test and the entry point is in neither guarded
list — editing the verification is not refused, and the suite asserts that it is not. An edit to the
record and an acceptance run are then both put to the author, by the editing-tool route and the shell
route alike — so a pass that edits instruction material and brings the record level cannot do the second
half unprompted. **The self-improvement path is exactly such a pass, and this is what it meets.**

The refusal's message carries the reason that applies rather than one that covers both loosely: a
protected page is refused because it defines or enforces a required element, the record because levelling
it is how a change to instruction material stops being reported, and a command that reaches both gets
both sentences. Every message names what would permit the edit — allowing the call lets it proceed, which
is the authorisation route rather than a way round it.

That second list is deliberately **not** the list leg 4 compares against the protected-page table. The
record defines no required element, so admitting it to the protected set would make leg 4 report it as a
surplus interruption — correctly. It gets its own agreement assertion instead, in both directions: the
path the verification reads is the path the guard guards, because one side alone is satisfiable by a
guard that guards nothing and the other by a guard that guards the wrong file. That follows the precedent this
repository already sets with the hook arms derived from the propagation table: a list and the thing it
is meant to match are compared in both directions rather than trusted on one side.

**The residual, named.** The refusal's own bound reaches the record as it reaches any protected page —
its six measured silent forms, and an `ask` a project that allow-lists the editing tools can let through
unprompted. The acceptance condition adds two of its own, both in the under-firing direction: the
payload invoked directly, which never spells the entry point the arm matches on, and an acceptance flag
reached through a variable or a shell alias rather than spelled in the command. All eight are asserted in
the guard's suite rather than claimed in its header. No new exposure of any other kind is added; the
record inherits the refusal's.

### Decisions taken, with the alternatives rejected

| Decision | Why, and what was rejected |
|---|---|
| The record names a **blob per corpus file**; previous text comes from the repository's own history | A record carrying each statement's text comes out larger than the corpus itself at `path <TAB> text` per row, two orders of magnitude above the record as designed — both sizes behind that ratio are measured in § The inventory, the record, and why the record is not a copy of the text — and would put every accepted change in the diff twice, in a repository where nearly every commit edits instruction material. A digest-only record was rejected for the opposite reason: a digest detects that a statement moved and cannot produce what it said before, which AC11 requires |
| The record is a **committed artefact**, not the previous commit | Comparing against `HEAD` needs no record and has no steady-state problem, and was rejected because acceptance would then be the commit itself: an addition would be reported before it was committed and silent for ever after, and the question answered two sections above — whether the record can be brought level in the same pass as the change it would have reported — presupposes a record that can be edited and therefore guarded |
| The record lives under the **fixtures root** of the project-data directory | Measured in both directions against the reference gate: that root is admitted wherever a method file names it and a bare sibling is not, and it is the least-bad fit among the admitted roots rather than a match — § Where each thing lives names the three clauses of that root's contract the record diverges from, and the one it satisfies exactly. Admitting a new project-data path was rejected on cost, and widening this root's contract on the same ground one step smaller: the gate's list and the method page it mirrors must move together, that mirror is itself asserted, and the page is already over its own size warning |
| The comparison is a **multiset per file**, with ORDER compared for the code spelling only | Nearly every corpus file carries a repeated normalised statement — the count and the exceptions to it are measured in § The inventory, the record, and why the record is not a copy of the text — so a set loses the removal of one of several identical lines. Order is compared where a line's position is semantics — measured, one `exec` moved above three cannot-run guards leaves the line multiset identical and makes all three unreachable. A FULLY positional comparison was rejected as breaking: it reports a moved paragraph as a change, which is not one, and a re-wrap of the markdown here is measured to leave the multiset identical over every markdown file in the corpus at all three widths — the counts are in § The statement, and its two spellings — which is the property that would be lost |
| **Every file is segmented every run**, and the sha fast path skips only the object fetch, the difference and the alignment | AC12's false green is a run that compared fewer statements than the corpus holds; a run that segmented only changed files would have no statement total in the clean case, which is the case the detector exists for. Measured at this pass, segmentation of the whole corpus costs 0.075–0.083 s against 0.009 s to hash — an order of magnitude, and a clean sweep of all four legs runs end to end in a fraction of a second, on a gate list that already carries a four-minute member — and what the fast path actually buys is not the segmentation but the only super-linear step |
| Alignment is **token overlap within one file**, computed locally, with each statement's word set built once | It only pairs leftovers for presentation, so the threshold cannot change a verdict — which is what "a similarity judgement may only align" requires. Measured, hoisting the word sets out of the inner loop buys a multiple on the worst case — the corpus's largest file at 1,464 statements, with the ratio, both timings and the operands in § The alignment, and the three rules it obeys — and that worst case running in under half a second is why the pairing carries no abandonment bound: a threshold with no value and no leg would be an uncalibrated one, which is half of why this row rejects a hosted model. An embedding model was rejected outright: this gate runs before a commit and must return the same verdict on the same tree with no network call, and a hosted model would pin a model version as data and introduce a threshold nobody here can calibrate |
| A code surface's unit is the **line, indentation included** | A line is the authored unit of a script, as a sentence is of prose. Applying the sentence rule to a shell script yields deterministic nonsense; extracting only the prose a script emits would require deciding which lines are instruction material, which is the judgement this approach exists not to make. The indent is inside the statement because in a script it is scope: measured, de-indenting this check's own principle-wording comparison out of its loop produced a clean verdict with every surface examined-clean while its first leg was disabled, and that whole class of change reports as nothing under a stripping rule |
| The element cross-check stays as its **own leg** | It is a derivation compared against a record in both directions, it reads no sentence, and AC12 requires its count. Folding it into the comparison would lose the direction in which a widened record alone is reported |
| The payload is **two siblings**, with leg 1's pinned sentences as literals in the first | A size consequence, measured: one file carrying all four legs reached 1010 lines against this repository's hard 1000-line limit, which ships no exemption a hand-written script can claim. The split put the first sibling back inside the band a PR description must justify rather than over the limit, and § Risks prices the margin it bought. Leg 4 is the span that moves because it was measured the cheapest of the three candidates — a pure SINK, none of the nine names it defines read anywhere else in the payload, where leg 3 exports two names and leg 2 four. The failure mode that argued for one file is GUARDED rather than absent: an absent or unreadable sibling is a cannot-run at the entry point before the interpreter starts, and an unparseable one is a cannot-run in the loader, which wraps the module EXECUTION and not the spec lookup — measured across three cases, sibling absent, unparseable and good, a `None` spec and a `None` loader are both absent in all three, while the real failures come out of the execution and exit 1, the findings code, so a check that could not load half of itself would have read as a check that found problems. A suite leg therefore asserts rc 2 and NOT merely a non-zero exit. The pinned data left beside the comparison is the eight sentences and one severity spelling, which do not earn a file of their own |
| The payload keeps `python3` | The legs are built and verified in it, and rebuilding them in shell to avoid an extension is work the amendment does not call for. The interpreter is preflighted with its reason — the host `grep` has been measured answering `0` to a pattern it refused on a complexity limit — and the two findings that attach to the extension are answered rather than tolerated: both payload siblings are asserted present in the examined corpus and the record is asserted tracked — the index test, not the corpus test, since the record has no surface — and the payload's parse is asserted by the suite, which the single entry point runs |
| The report names every arrival rather than summarising a new file | AC11 exempts no region of an examined surface, and "this file is new, read it yourself" is such an exemption. The volume is priced in § Risks instead, as the rate the report costs per answer |

### Measurement provenance

**The authority on the totals the check prints is the check itself, and what it prints was read off a
bare run rather than assumed.** On a clean tree `bash scripts/check-plan-invariants.sh` emits two
things: a verdict line carrying the seven figures `principles`, `elements`, `surfaces`, `pages`,
`statements`, `unaccounted` and `findings`, in that printed order, and below it a surface roster of one
line per surface carrying a **file count** — for the five examined surfaces, and for the three excluded
by design, each of those with its reason. The other paths add to those two rather than replacing either:
the report itself, a finding line per answer, the cannot-run line naming the input that could not be
read, and an UNACCOUNTED roster line naming the paths whenever that set is non-empty. `--accept` prints
the report it is about to take in, then the same figure line beside the rows it wrote and the report
lines it took in. Those totals are that run's to report, and they do not all move together: `pages` and
`statements` move with every edit to this repository's instruction material — the statement total for a
second reason as well, since the segmentation rules are themselves inside the corpus they segment —
`findings` moves with what that edit did, and `unaccounted` moves only when a tracked file lands on no
surface and in no named exclusion. The rest are constants this design fixes rather than counts that
drift: the eight principles, the enumerated elements and the five surfaces. **So this document names one
of them in only two shapes**: as an OPERAND of a measurement attributed to this pass, the corpus's file
count under the ratios in this document being the case that arises; and where the figure is one of those
constants. What it does not do is restate a drifting total as the current value.

**The totals this document reasons about and the check does not print are each either measured here or
named as derivable.** The corpus's LINE and BYTE totals are on neither the figure line nor the roster;
the byte total is the one of the two a decision touches, and § The inventory, the record, and why the
record is not a copy of the text records it as measured at this pass beside the two sizes whose ratio
the record's shape rests on. The per-surface STATEMENT breakdown is absent too — the roster counts files
— so the two sums § The statement, and its two spellings turns on are this pass's own measurement, and a
reader re-derives them by segmenting those surfaces and summing. The record's SIZE and ROW COUNT appear
on no ordinary run either: the row count is one row per corpus file, so the roster's file counts give it
in one step, and both are recorded as measured where the record-shape decision needs them.

**What is recorded here is what a decision turns on** — a gap, a crossed threshold, a ratio, or a
behaviour that was observed. Each was measured against the working tree with `git` and `python3`, driving
the shipped segmenter itself rather than a copy of it:

- **Hashing against segmenting: 0.009 s to hash the whole corpus in one process, 0.075–0.083 s to
  segment every file in it, over five runs.** An order of magnitude, and the gap rather than either
  figure is what the sha fast path rests on. The timings are machine-local; the ordering between them is
  not.
- **Nearly every corpus file carries a repeated normalised statement**, measured at this pass — § The
  inventory, the record, and why the record is not a copy of the text carries the count and the
  exceptions to it. This is why the comparison is a multiset and not a set, and the conclusion holds at
  any count above zero: under set semantics the removal of one of several identical lines is invisible.
- **A re-wrap either leaves the inventory identical or fails loudly**, measured at this pass over the
  corpus's markdown files at all three widths, and again under the same instrument with the list rule's
  guard removed, against a control proving the guard-less segmenter live. That is the property the
  list-item rule exists for and the reason prose stays position-independent; § The statement, and its two
  spellings carries both counts, the instrument and the one shape it excludes.
- **One file carrying all four legs reached 1010 lines against this repository's hard 1000-line limit**,
  which ships no exemption a hand-written script can claim. A crossed threshold, and the whole
  justification for the two-sibling split.
- **De-indenting the check's own principle-wording comparison out of the loop that drives it produced a
  clean verdict with every surface reported examined-clean**, against a control proving the mutant was
  live. An observed behaviour, and why the indent is kept inside a code statement: without it, that whole
  class of change reports as nothing.
- **The alignment ratio reads 0.90, 0.78 and 0.05** — for the one word the suite's rewording leg changes
  in a method page's sentence, for a principle reworded by two words, and for two unrelated statements —
  against the threshold of **0.6**. A calibration: without these three the threshold is a number nobody
  can defend, which is half of why a hosted model was rejected. Measured over this change's own diff
  while it was being built, **15 of 18 departures** paired with a reworded arrival at it.
- **Building each statement's word set once rather than per comparison is a measured saving on the
  worst case** — the ratio and both timings are in § The alignment, and the three rules it obeys. The
  worst case is the corpus's largest file at **1,464 statements** rewritten whole: a nominal
  **2,143,296** comparisons of which **1,115,985** are actually performed, because a claimed departure
  is not offered again. The ratio is what the implementation constraint rests on; the worst case runs
  in under half a second, which is why the pairing carries no abandonment bound. The statement count is
  recorded with it because the step is quadratic in it and that is what a reader re-scales.
- **A sibling that is absent or unparseable exits rc 2, not rc 1.** Measured across three cases —
  sibling absent, unparseable, and good — a `None` spec and a `None` loader are absent in all three,
  while the real failure comes out of the module execution and would otherwise exit 1, the findings code.
  A distinction rather than a size: a suite leg asserts rc 2 and not merely a non-zero exit, because a
  check that could not load half of itself would otherwise read as a check that found problems.
- **The report costs two lines per arrival, departure or relocation and three per change.** A rate, and
  the volume risk in § Risks rests on it rather than on any one report's length. The project context
  holds the measured length of this change's own report, as the question to revisit with a count.

**Measured on the live tree, both directions, for the two gates the registration edits reach:** the bare
record path in a method file returns `major|L4|… is not a documented project-data path` at rc 1 while the
`fixtures/` spelling on the same line is silent, and the gate is clean once the probe is reverted; and a
backticked record path derives no required arm from the propagation table, because that gate filters
harvested tokens to markdown, shell and JSON spellings.

**The behaviours this design turns on are pinned by legs of the suite rather than by a figure recorded
here** — the three sentences that defeat a shape-reading mechanism, each reported as one arrival carrying
its own text; the re-wrap control; the reworded statement reporting what it said before; the departure
carrying its text; a mandate carried only in emitted text; a required element renamed with the element
count standing still; and the clean control beside every plant. § Test Design states them.

Not re-derived at this pass, and nothing here depends on them: the per-path commit counts behind the
protected-page boundary, and the union of the near misses. The distribution manifest carried **0.1.46**
when this change landed, against a released `0.1.45`.

## Decomposition

`M = 5`. Every artefact named under § What the change inherited is in the tree and is not a subtask; no
row below re-lands one.

**Three ordering constraints bind every subtask.** First, each subtask's own edits land inside the
examined corpus, so the verification reports them: each subtask therefore closes with an acceptance run
over its own change and a green pre-commit list, never carrying a red across a subtask or a handoff
boundary where nothing is left in context to explain it. Second, **a deletion travels with the thing that
deletes it, in the same subtask, for every consumer that names the deleted path** — the suite is a member
of that list and its mutant builder copies the payload's siblings by name, so a deleted sibling breaks
fixture construction outright rather than failing one leg; and the propagation table is the second
consumer, naming the data sibling as a `${CLAUDE_PLUGIN_ROOT}` path, so the reference gate's link leg —
also a member of that list — reddens on the deletion until the cell stops naming it. That is why one cell
of `docs/propagation.md` sits in subtask 1's file list although the group's own vocabulary belongs to
subtask 5. Measured in three bare runs, one per state: clean at rc 0 before, rc 1 with exactly one
blocker-severity link finding naming that path in the group's anchor row once the sibling was gone, and
clean at rc 0 again once it was restored byte-for-byte. The arms gate cannot see the same path at all,
because it filters harvested tokens to markdown, shell and JSON spellings before resolving one against
the index, so the deletion moves nothing there. Third, the payload must be visible to the index before
the list is run — `git add -N` on anything new, and the file COUNT the syntax gate processed read as well
as its exit status.

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **The comparison, the record and the acceptance route.** The payload's second leg is the inventory comparison: the two statement spellings, per-run segmentation of every file, the per-file sha fast path over the object fetch and the difference, the multiset difference, the order comparison for the code spelling where the multiset is unchanged and the sha is not, the alignment over the leftovers with each statement's word set built once — the measured 2.5× on the worst file the corpus holds, which then runs in under half a second, which is why it carries no abandonment bound — and a report line per arrival, departure, change and relocation carrying its text, its surface, the previous text where there is one, and the rule that produced it. The verdict line carries principles, elements, surfaces, pages, statements, unaccounted and findings, with the surface roster printed on the cannot-run path as well as the others and each of the three by-design exclusions carrying a membership rule rather than only a name. An unreadable corpus file is a cannot-run. The pinned sentences and the one severity spelling become literals in the payload and the data sibling is deleted; one cell of the propagation table loses that path in the same subtask, for the reason the second ordering constraint gives. **In this same subtask the suite's legs that asserted the leg this one replaces go with it, and its mutant builder becomes a whole-check copy** — it must name every file the check is, because the entry point loads its payload from its own directory and that payload loads the second sibling from its own, so a part-copied mutant runs unmutated code beside the planted defect. The entry point gains the acceptance flag and its degrade-rather-than-block rule, the record's own preflights, the sibling's existence and readability preflights, and two assertions of different shapes, because the two kinds of file differ by design: both payload siblings are asserted present in the **examined corpus**, which they are, and the record is asserted **tracked** — present in the index — because it has no surface and corpus membership is a test it could never pass. A file read for its data while untracked makes the local run green and every other clone a cannot-run. Every other failure of a required input stays a cannot-run. **The header prose of each file moves with its code**: the entry point's description of its four legs, its stated BOUND, its sibling count and its whitespace rule, and each payload sibling's account of what the other holds — all of it sits inside the compared corpus, so stale text there is itself inventoried. The BOUND is this design's: the comparison reports a change to a statement's text, never a meaning. Then the first acceptance run lands the record | `scripts/check-plan-invariants.py`, `scripts/check-plan-invariants-refusal.py`, `scripts/check-plan-invariants.sh`, `scripts/test-check-plan-invariants.sh`, `scripts/check-plan-invariants-data.py` (deleted), `ai-docs/fixtures/plan-invariants.inventory`, one cell of `docs/propagation.md` | — |
| 2 | **The refusal covers the record and the acceptance route.** The guard gains a second one-member list holding the record's path, kept out of the list leg 4 compares against the table, and a third condition class matching an invocation of the entry point that carries the acceptance flag — placed so the basename fast path cannot return before it, which means that path's token set admits the record's basename and the entry point's own. Leg 4 gains the two-direction assertion that the path the verification reads is the path the guard guards. The guard's suite covers both in both firing directions — an edit to the record and an acceptance run asserted to FIRE, a read of the record asserted SILENT, an edit to the unguarded entry point asserted SILENT — because no direction is observable from another, and asserts the two acceptance residuals silent so the bound is a measured fact. The registry is untouched, so no pinned record in the hook-behaviour suite and no prose count of hook entries moves | `hooks/lib/plan-invariants-guard.sh`, `hooks/lib/test-plan-invariants-guard.sh`, `scripts/check-plan-invariants-refusal.py` | 1 |
| 3 | **The comparison's legs, added to a suite that is already green.** Each is a mutation against a throwaway fixture tree carrying its own git history, since the comparison reads a blob the record names: the three sentences that defeated a shape-reading mechanism, each asserted to produce one arrival carrying its own text, each paired with the control that the unmutated copy is clean; a re-wrap asserted clean, which is where the re-wrap property is pinned; a reworded statement asserted to report what it said before; a departure asserted to carry the departed text; a mandate carried only in emitted text; a required element replaced with the count unchanged; an arrival planted inside a fenced block and inside a table row; a line moved inside a code file asserted a relocation and the same class of move inside prose asserted silent, each with its own control; a block de-indented out of its branch asserted a change carrying the indent it had, and the same shift inside a hard-wrapped paragraph asserted silent; a tracked file in neither a surface nor an exclusion asserted counted and named; a surface made unreadable asserted a cannot-run whose roster still reports it not-examined rather than counted clean; a surface carrying findings asserted examined-with-findings rather than clean; the record absent, unreadable, empty and naming an unrecoverable blob, each asserted a cannot-run distinct from clean and from red, paired with the acceptance run over the same tree asserted to complete; the payload and the record untracked, each asserted a cannot-run; a sibling absent and a sibling unparseable, each asserted rc 2 and not the findings code; and the payload asserted to parse, so a gate the single entry point runs does parse it. The suite's path and its place in the documented list do not change | `scripts/test-check-plan-invariants.sh` | 1, 2 |
| 4 | **The principles page.** Its honest limit keeps its first sentence — caught and named, never prevented — and its further bounds become this design's: the comparison reports a change to a statement's text, so a mandate that changes no statement is not reported; the record can be brought level in the same pass as a change, as far as the refusal does not reach; and the refusal recognises an edit by its shape, so an unrecognised writer reaches the page and is caught by the comparison instead. The authorisation route gains the row for bringing the record level. **The two-surface statement moves as well, and so does its detection-width cell**, because both overclaimed the detection's reach: the cell now reads that the detection covers the instruction material on five named surfaces and that a tracked file outside all five is outside it, and the paragraph below the table names three deliberately excluded surfaces with a reason each and the report's own count of what neither a surface nor an exclusion claims. The principles, the element record and both tables are untouched — they are already right | `docs/plan-invariants.md` | 1 |
| 5 | **Registration prose, propagation, and the closing acceptance.** The documented item `5b` and the project context's entity block describe the four legs as they now are, with the verdict line's counts named as now printed; the project context's language-profile row names both payload siblings among the tracked non-shell payload files and names how each one's parse is asserted, since no member of the pre-commit list parses a payload by walking the tree; the propagation group's anchor and back-reference rows name the entry point, its two payload siblings and the record, with the record spelled at the admitted path and every hook path kept in prose. **Two gates are re-run with their member lists read and not only their status:** the arms gate, whose derivation reads the table's backticked tokens, and the gate inventory, because item `5b` sits inside the span the runner parses to derive its own member set. The reference gate is run for the project-data spelling. Then the closing acceptance over the tree as this change leaves it, and the whole pre-commit list green — the run that proves AC14 on the real tree and that every earlier subtask's own acceptance was taken | `AGENTS.md`, `ai-docs/context.md`, `docs/propagation.md`, `ai-docs/fixtures/plan-invariants.inventory` | 1, 2, 3, 4 |

## Risks

- **The report's volume on a change that adds files.** The report prints **two lines per arrival,
  departure or relocation and three per change**, so a file of N statements arriving whole costs 2N lines
  of report. Measured at this pass, the corpus averages **224 statements** a file and its largest member
  holds **1,464**, which puts a whole-file arrival at roughly **450** lines of report for a typical
  member and **2,928** for the largest. That is the shape of the risk: a change that adds instruction
  files produces a report in the thousands of lines, while an ordinary prose edit lands in the tens.
  Mitigation: none that preserves AC11, and that is deliberate — a per-file summary for a new file is
  exactly the exempted class the
  criterion forbids. What is offered instead is that the report is grouped by file, the verdict line
  carries the totals, and acceptance is one run. The rate is named here, and the project context holds
  the measured length of this change's own report, so that a later judgement that the volume is too high
  is a changed requirement travelling the amendment route rather than a defect in what was built.
- **The record can be brought level in the same pass as the change it would have reported, outside the
  refusal's reach.** Closed for both edit routes and for the acceptance route by subtask 2, so the
  residual is the refusal's own measured bound — its six silent shell forms, an `ask` let through by a
  project that allow-lists the editing tools, and the acceptance condition's own two: the payload invoked
  directly, and the flag reached through a variable or an alias. Mitigation: the suite asserts both
  firing directions and the two new residuals; and a reader of the principles page meets the bound there,
  because subtask 4 states it as one of the page's own.
- **A statement that changes nothing textually changes nothing in the report.** A mandate a reader infers
  from a statement whose words did not move is not an arrival and is not reported, and neither is a claim
  that became false because something else in the tree moved. This is the honest limit of a comparison,
  and it is the direction that cannot be closed by any mechanism this task may build. Mitigation: stated
  in the check's own header and on the principles page, so a clean run is never read as a proof.
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
  fail loudly rather than silently, which is the direction that matters; the list rule is what holds a
  re-wrap off the inventory for all 53 of the corpus's markdown files at three widths against 51 without
  it, and subtask 3 pins that property as a leg rather than leaving it asserted here.
- **The payload sits against its size limit.** The first sibling stands at **990 lines of a hard
  1000-line limit** that ships no exemption a hand-written script can claim, inside the band a PR
  description must justify; the split bought that margin once and the next substantial edit spends it.
  That margin is a live figure rather than a record of this pass: read it off the file before any edit
  that adds to it. Mitigation: a further leg can move out on the same terms, and the terms are what
  matters rather than the room — leg 4 was a pure sink, so its seam is one call and a context mapping
  with nothing read back, while leg 3 exports two names and leg 2 four, so either costs a wider seam.
  What makes any such split defensible is that an unloadable sibling is a cannot-run at the entry point
  or in the loader and never the findings code, and a suite leg asserts rc 2 rather than merely a
  non-zero exit.
- **The verification is a repository-local gate and ships with the toolkit anyway.** A consuming project
  that invokes it finds no record and gets a cannot-run naming it. Mitigation: reach into a consuming
  project is deferred by the spec, and a cannot-run is the honest outcome rather than a false green.
- **The registration edits reach three gates, and two of them are the kind that pass while being wrong.**
  The reference gate refuses an undocumented project-data spelling anywhere a method file names one;
  the arms gate derives its expected arms from the propagation table's backticked tokens while
  requiring the hook registry's own paths to stay silent; and the gate inventory derives its member list
  from the span item `5b` sits in. Mitigation: the record is spelled at the admitted path, measured in
  both directions; every hook path stays in prose, which is measured to be necessary because a backticked
  hook path does derive a required arm while the record's path cannot; and both derived gates are re-run
  with their member counts read rather than only their status.
- **Five of the seven protected pages are plausible targets of this task's own work, and the record is
  guarded too.** The refusal therefore fires during the work that installs it, and during every
  acceptance. Mitigation: the author-allows path is the authorisation route and the suite asserts it, so
  landing the protection never requires switching it off.

## Test Design

- **Base fixture:** a throwaway copy of the tracked tree per leg, **staged, committed and then
  accepted.** All four steps are load-bearing. The check takes its corpus from the git INDEX while
  reading several files directly for their data, so a file that is present but unstaged is read for data
  and never compared — and the sweep then reports a clean run over a corpus that does not contain the
  planted defect. That happened once on the real tree, with the one page this check exists to protect
  left out of its own corpus, so the first leg of the suite is a positive control on the fixture itself.
  The COMMIT matters because the comparison reads a blob the record names: a fixture whose objects are
  only loose and unreferenced is one garbage collection away from a cannot-run. And the ACCEPTANCE is
  what writes the record, so the fixture's expectation is built from the fixture's own tree rather than
  inherited from the real one. A mutant of the check is **the whole check** — every file it consists of,
  since the entry point loads its payload from its own directory and that payload loads the second
  sibling from its own, so a part-copied mutant would run unmutated code beside the planted defect and
  every mutation leg would come back green against a defect it never planted.
- **Entry points:** the verification with no arguments, with a root override and with the acceptance
  flag; the guard fed a payload on standard input; the single pre-commit entry point with a root
  override.
- **Every plant is paired with a control**, and the mutation helpers report how many sites they changed
  and fail the leg at zero. That is measured rather than defensive: two mutations of the principles
  document matched nothing — the document hard-wraps and the sentence being replaced did not — and both
  legs went green over an unmutated tree. Every leg whose failure mode is empty output is additionally
  shown able to come back non-empty.
- **Any text change anywhere in the corpus reddens the comparison**, so no leg asserts a clean verdict
  over a mutated tree. That is the point of the comparison rather than an inconvenience: a mutation that
  produced a clean verdict would be a statement that changed and was not reported.
- **A roster line for an excluded surface is asserted to NAME a file count, and no value is pinned.** Those
  three counts move whenever anyone lands a plan document, a learning entry or a repository config file,
  so a pinned count there is a false assertion waiting for the next commit — measured, it reddened the
  default branch at the merge that shipped this suite, because that merge moved three plan documents into
  the completed directory. The count-naming legs therefore match a pattern where the others match a
  literal.
- **The three sentences are legs of their own**, since they are what a shape-reading mechanism cannot be
  trusted with: a required part of the design whose content cannot exist when the document is authored;
  the same mandate stated beside a reading verb; and the same mandate whose object names a section the
  record already carries. Each must be reported as one arrival carrying its own text, with the statement
  count moving, and each is paired with the clean control on the same page.
- **The three roster states are each asserted**, because none is observable from another: examined-clean,
  examined-with-findings on the surface a planted finding belongs to, and not-examined for a surface that
  could not be read — with a mutant that still reports the finding while mis-rostering it, so the
  distinction is shown to be about the roster rather than about the finding.
- **Both firing directions of the refusal**, because neither is observable from the other: a write to the
  record and an acceptance run asserted to FIRE, a read of the record and a read of a protected page
  asserted SILENT, an edit to the unguarded entry point asserted SILENT, and the two acceptance
  residuals asserted silent.
- **The cannot-run family in full:** the record absent, unreadable, empty, or naming an object the
  repository cannot produce; a corpus file unreadable; the payload or the record untracked; a payload
  sibling absent, and one that exists but cannot be parsed. Each asserted distinct from clean and from
  red, asserted to be treated as a failure by the single entry point, and — for the unrecoverable blob —
  paired with an acceptance run over the same tree asserted to complete.
- **What is pinned elsewhere, so this suite does not claim it:** the single entry point's reading of a
  member that exits non-zero is a leg of the runner's own suite, and the guard's firing and silence
  directions are legs of the guard's suite. This suite pins the rc 2 outcome itself, not the runner's
  treatment of it.

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
- AC11 verified by: that an arrival, a departure, a change and a relocation are each reported with the
  statement's own text and its surface, that the change additionally carries what it said before, that
  each line names the rule that produced it, and that the statement total moves when a statement is added
  and stands still when one only moves — with the control that no region is skipped, shown by planting
  inside a fenced block, inside a table row and inside the text a guard emits, and requiring each to be
  reported like any other.
- AC12 verified by: that the verdict is accompanied by the number of principles, enumerated elements,
  surfaces, pages and statements compared, and by the count of tracked files that no surface and no
  stated exclusion claims; that the statement total is reported on a run where nothing changed as well as
  on a red one; and that narrowing any one of those inputs moves its figure — with a page dropped from
  the corpus moving the VERDICT as well, because the record still names the path it left, so a narrowed
  run is distinguishable in two places rather than one and the figure is the weaker of the two signals.
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
