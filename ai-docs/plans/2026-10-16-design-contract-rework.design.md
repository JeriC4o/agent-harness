# Design: Design contract rework — what a plan document must carry, and what checks it

**Ticket:** GH-128
**Date:** 2026-10-16
**Spec:** ai-docs/plans/2026-10-16-design-contract-rework.spec.md

## How every figure here was obtained

The defect that created this task was a document asserting figures nobody measured, so every factual
claim below carries its provenance in the same sentence or in a trailing tag. Three tags, and no fourth:

| Tag | Meaning |
|---|---|
| **[M]** | Measured while writing this design, on branch `GH-128-design-contract-rework` at commit `6e60638` with one untracked file present. The command is shown where the figure is first used. |
| **[R]** | Taken from the task's resolved-figures record, which names the command that produced it. Not re-run here. |
| **[U]** | Read from a surface-mapping reader and **not** re-derived. Owed a re-derivation before anything is built on it. Used only where nothing load-bearing rests on it. |

Every byte size below is `wc -c` output, so it is bytes; the instruction-file cap is written in characters
and these files are not pure ASCII, so a figure within a few hundred of a limit is a figure to re-measure
rather than to trust. **[M]** That discrepancy is a pre-existing open question of the tree, named here
because several of this task's edits land on files within a few hundred bytes of the band — four of them
as the tree now stands, none of them inside it, the session-start page having left the band under
subtask 2.

No absolute statement count appears in this document as a constant. The verification's
`statements=` figure is an as-of reading that moves with every net line added to an examined surface, so
it is used below only as a delta basis.

## Approach

Six scope items, taken with their numbers from the spec's own `## Scope` and from no other source. The
work is one task; the shape below is what makes it reviewable in pieces.

### The measured ground this design stands on

**The tree is green, and that is the comparand for every later claim.** `bash scripts/run-checks.sh`
exits 0 with 36 ok, 0 failed, 28 suites derived from the tree, and the `shell-syntax` member reporting
58 files parsed. **[R]** The runner suppresses the invariants gate's own verdict line, so that gate was
also run bare — `bash scripts/check-plan-invariants.sh` — and reported
`clean | principles=8 elements=14 surfaces=5 pages=122 statements=27371 unaccounted=0 findings=0`, with
the five examined surfaces all clean and three surfaces not-examined by design. **[M]** (Run twice
independently, by the orchestrator and again here; the two outputs agree.)

Two readings of that verdict are load-bearing for the decomposition. `unaccounted=0` reads the opposite
way from the five counts beside it: a non-zero value names tracked files on no examined surface and in no
named exclusion, about which the report then says nothing at all. It is zero now, so any later non-zero
value is this task's own doing. And the clean verdict says nothing about the spec itself, because
`ai-docs/plans/` is one of the three excluded surfaces — the artefacts under these rules quote principle
text by construction. **[M]**

**Sizes of the instruction files this work edits, AS OF THE FREEZE**, from one `wc -c` call over
`docs/*.md`, `docs/templates/*.md`, `agents/*.md`, `skills/*/SKILL.md` and `rules/*.md`. **[M]** The cap
is 40,000 and the early-warning band opens at 35,000. Every figure in this table is a reading taken at
the freeze and is kept at that reading, because a size is an as-of fact and the table is what the
decomposition's extraction obligations were computed from; the block after it carries the current reading
for every row that has since moved, and the obligations below are stated against those:

| File | Bytes | Headroom to the band |
|---|---|---|
| `docs/agents-method.md` | 35,005 | **inside the band already, by 5** |
| `docs/workflow.md` | 34,969 | 31 |
| `docs/claude-tools-hierarchy.md` | 34,966 | 34 |
| `agents/self-review.md` | 34,915 | 85 |
| `skills/task/SKILL.md` | 34,865 | 135 |
| `skills/task/reference.md` | 34,524 | 476 |
| `agents/design.md` | 31,333 | 3,667 |
| `docs/templates/progress-format.md` | 26,155 | 8,845 |
| `agents/review-findings.md` | 17,879 | 17,121 |
| `docs/plan-invariants.md` | 17,019 | 17,981 |
| `docs/code-style.md` | 16,742 | 18,258 |
| `agents/design-review.md` | 13,335 | 21,665 |
| `skills/redline-fold/SKILL.md` | 12,404 | 22,596 |
| `skills/context-reset/SKILL.md` | 9,753 | 25,247 |

**Current reading, re-measured after Group A closed**, from one `wc -c` call over the same set on branch
`GH-128-design-contract-rework` at commit `6e60638` with the branch's uncommitted work present. **[M]**
Six of the fourteen rows have moved; the other eight are unchanged and are not repeated here. Three
movements are this task's own — subtasks 2 and 3 — and three belong to the out-of-band chore riding on
this branch, which is why they are attributed per row:

| File | At the freeze | Now | Headroom to the band | Moved by |
|---|---|---|---|---|
| `docs/agents-method.md` | 35,005 | **31,743** | **3,257 — out of the band** | subtask 2 took 3,612 out of it; subtask 3 put 350 back |
| `agents/self-review.md` | 34,915 | **34,921** | **79** | subtask 2, two references re-pointed at +3 bytes each |
| `docs/code-style.md` | 16,742 | 16,827 | 18,173 | subtask 2, the cross-link sentence |
| `agents/design.md` | 31,333 | 31,882 | 3,118 | the out-of-band chore |
| `agents/design-review.md` | 13,335 | 13,672 | 21,328 | the out-of-band chore |
| `skills/context-reset/SKILL.md` | 9,753 | 11,235 | 23,765 | the out-of-band chore |

**Two of those movements change what a later subtask must do, and they are the reason this block exists
rather than being left for the close.**

**The session-start page is out of the band, so the pressure that justified part of the extraction plan
has eased.** It went in at 5 bytes inside the band and now has 3,257 bytes of headroom. The extraction in
subtask 2 was owed on two grounds — the band and the topical fit of a reference page — and only the first
is discharged. Nothing in the decomposition is removed by this: subtask 3 has already spent 350 of that
headroom, and subtask 3 is the last subtask that adds to this page. What the easing does change is that
**no sentence anywhere may now say this page is inside the band**, and the freeze table's own cell saying
so is scoped by that table's as-of label rather than left to be read as current.

**The per-change sweep's headroom is 79 bytes, not 85, and that is the figure subtask 8 is held to.** It
moved the wrong way — subtask 2 spent 6 bytes on it re-pointing two references — so the file is tighter
than the plan assumed, by the same change that was meant to relieve the page beside it. The consequence
is an ORDERING requirement inside subtask 8 rather than a new subtask: the comment admission is longer
than 79 bytes on its own, so the extraction must precede the addition **in the same subtask**, and the
two cannot be separated into a concern handled elsewhere. Subtask 8's row states it that way.

**Six files sit at or within 500 bytes of the band, not four** — `docs/workflow.md` and
`docs/claude-tools-hierarchy.md` were measured by no reader and are not in the resolved-figures table.
**[M]** Both matter here, and in opposite ways. **That count is as of the freeze; the current count is
five**, the session-start page having left the set, and the five that remain are the four below plus the
per-change sweep at 79 bytes.

`docs/workflow.md` is the page whose subject is closest to item 4's, and its 31 bytes of headroom are
the reason item 4 does not land there.

`docs/claude-tools-hierarchy.md` is worse: **this work is obliged to edit it, and nothing in the spec
anticipates that.** The propagation table carries a standing row requiring that page to be updated in
the same change as any edit that changes a Tool, Subagent, Skill or Hook contract. **[M]** Subtask 12
creates a new subagent contract, so the row fires, and the page has 34 bytes of headroom.

**So the extraction obligation attaches to four separate edits, not to one.** Of the six tight files,
five take new wording from this work:

| File | Headroom | Edited by | Extraction owed |
|---|---|---|---|
| `docs/agents-method.md` | 3,257 — **done**, was inside the band | subtasks 2, 3 | discharged — subtask 2 did it first, before any word was added |
| `docs/claude-tools-hierarchy.md` | 34 | subtask 12 | yes, in subtask 12 |
| `agents/self-review.md` | **79** | subtask 8 | yes, in subtask 8, and **before** the addition in that same subtask — the comment admission is longer than 79 bytes on its own |
| `skills/task/SKILL.md` | 135 | subtask 12 | yes, in subtask 12 |
| `skills/task/reference.md` | 476 | subtask 12 | likely, measured at the edit |
| `docs/workflow.md` | 31 | not edited | none — and this is why item 4 is placed elsewhere |

That concentration is itself a finding about the shape of the work: subtask 12 edits three of the four
files that need an extraction, which makes it the largest subtask in the decomposition and the one most
likely to need splitting if a round finds it unwieldy.

**Which section leaves the session-start page, and what it costs.** The test-conventions section is
4,139 bytes and self-contained, and extracting it clears the band outright. **[M]** Its cost is five
inbound references in four files, plus the recognised-section list in the reference check — and **every
one of those references names the file as well as the section**, so none of them survives the move even
though the heading does. **[M]** The alternative target was the tooling section, whose two largest
paragraphs are 2,491 and 3,432 bytes; it was rejected on two measurements. It carries inbound
references in fourteen files **[M]**, and it holds the rules about not masking a gate's result and about
where a mutable fact comes from — rules needed at session start, which is the one thing an extraction
must not move. The test-conventions block is needed when tests are written, which is after the page has
been read. The references gate is what makes the five re-pointings a gated change rather than a silent
break: it resolves section references and refuses a stale one.

### Decision 1 — how an id is spelled, on both sides

The shipped keyed pairing is `do_paired` in `scripts/check-redline.sh`, read in full. **[M]** It extracts
`[REDLINE <key>]` occurrences from the design, filters them through `grep -Ex
'[A-Za-z0-9][A-Za-z0-9._-]*'`, reads the log's keys out of table cell 2 under the same character class,
compares the two sorted sets with `comm` in both directions, and prints `pairs=` beside the verdict. The
three hazards it paid for are visible in its own comments: a document that merely quotes the convention
must not read as a marked document, comparison is by equality and never containment, and a count of zero
is part of the verdict.

**The spelling extends that mechanism rather than inventing beside it:**

| Side | Form |
|---|---|
| A statement in a durable plan document | the marker `[ENTITY <id>]` appended to the end of the item — its paragraph, its list item, or the end of the cell carrying the item's prose in a table row |
| The source entity the statement leans on | a comment on or immediately above the entity, carrying `[ENTITY <id>]` and nothing else |
| The id itself | `<file-stem>.<entity-name>` — alphanumerics, dots, dashes and underscores, under exactly the character class the shipped filter already uses |
| A prose entity | nothing. Its heading or numbered item is already its declared identity, and the reference resolves by that text |

Four properties, each with its reason:

- **The token is `ENTITY` and not `ANCHOR`, `PIN` or `MARK`.** All three are already load-bearing in this
  tree under other meanings — a propagation anchor row, a `file:line` anchor in a round's fix plan,
  pinned principle sentences, a pinned member table, a pinned gate. **[M]** One name over several axes
  makes every sweep ambiguous, which the redline contract itself refused on that exact ground.
- **The id carries the file stem, not the plan's name.** A plan-scoped id would rot in the source the
  moment the plan moved to the completed-plans directory, and the comment is the half that cannot be
  updated by the party that moves the file. A stem gives a natural namespace in which entity names are
  already unique, which is what makes tree-wide uniqueness hold by construction rather than by
  discipline. A renamed file leaves a cosmetically stale stem and a pairing that still works, which is
  the right failure: the claimed property is detectability, not stability.
- **The character class is the shipped one, unchanged.** Narrowing it to lowercase would have bought a
  second guard against the quoting hazard and cost the ability to name a real entity — `PINNED` is an
  actual variable this work references. Reusing the class means the filter is the same expression on both
  sides and the precedent transfers without variation.
- **The quoting hazard is closed by an authoring rule plus a planted test, because the character class
  alone cannot close it.** Every illustration of this convention is written with the angle-bracket
  placeholder, which carries `<`, `>` and a space and is therefore not a shape-valid id. The rule is
  stated where the convention is stated, and the check's suite plants a page that explains the convention
  to prove the explanation is read as nothing rather than as an unpaired id.
  - **Named as accepted residue, not as closed.** The authoring rule is a rule in an instruction file,
    and this spec's own constraint says a rule enforced only by an instruction file is not a refusal.
    Nothing refuses a future document that illustrates the convention with a shape-valid id instead of
    the placeholder. What makes the residue acceptable is its direction: such a document produces a
    false positive — an id paired with nothing, reported — and not a missed finding. It is discoverable
    by reading the verdict, which is the same ground on which this spec accepts a standing excuse's
    silence. The planted test covers the mechanism's half; the authoring rule's half is residue.

**Direction 2 scans tracked files, and the scan's size is part of its verdict.** Tracked-only is what
keeps the suites out of the input: every suite in this tree builds its fixtures under `mktemp -d`, two of
them initialising a throwaway repository there, so a tracked-file scan cannot see a planted id. **[M]**
It is also the tree's own named false-green hazard, so the count of files scanned and the count of pairs
compared are both printed beside the verdict.

**One language in this repository admits no comment at all, which narrows the bidirectional guarantee.**
The hook manifest and the two files that declare the plugin are JSON, and so is every other file in the
tree written in it — a line added as a comment stops the file parsing. **[M]** The spec now states this
as a property of the language rather than as a list of files, and the criterion governing the pairing is
narrowed to match: where the entity's language admits no comment, the statement names the entity, the
reference resolves from the statement to the entity only, and no reverse pairing is asserted for it. The
design implements exactly that — the carve-out is stated in subtask 7 and bound as a leg in subtask 9 —
and the case is live here rather than hypothetical, because subtask 12 edits the hook manifest.

**The guarantee therefore has a stated boundary, and that boundary is the honest cost of the chosen
form.** An orphaned mark on a JSON entity cannot be detected, because no mark can exist there. What the
one surviving direction still catches is the failure that matters more: a statement naming an entity that
is gone.

### Decision 2 — who runs the semantic class

**A reader of its own, invoked by a convergence pass that produces the three mechanical classes' results
in the same run.** Not the existing design-review contract. Three grounds, two of them mechanical:

- **The spec requires the semantic report to carry no verdict on harm, and the review contract's only
  output is a verdict.** `agents/design-review.md` exists to issue GO, ITERATE or STOP, its first line is
  parsed for that word, and its rules forbid lowering a severity to close a loop. **[M]** A class that
  reports without ruling cannot live inside a contract whose entire product is a ruling; it would acquire
  a ruling by construction.
- **Its verdict vocabulary has no third outcome to spare.** GO, ITERATE and STOP are the three values, and
  a could-not-run is none of them. **[M]** Adding a fourth changes a parsed contract and reaches the task
  skill, the handoff skill and the design contract through the Task/Design sync group.
- **Agreement under repetition has to be affordable.** The spec requires the judgement check's agreement
  across repeated runs over one unchanged input to be measured and printed. Repeating the full review
  checklist to obtain that figure is the most expensive pass in the workflow; repeating one narrow reader
  is not.

The existing review contract keeps the architectural class it already runs and becomes a **consumer** of
the convergence report. This satisfies the requirement that a judgement result never stands alone: the
convergence pass runs the three mechanical classes and the reader together and prints all four results in
one place.

**The new reader is a new mechanism spanning several files in different vocabularies, so it gets a sync
group** rather than the table's fallback row — the propagation page's own procedure item 4 says a
mechanism, as opposed to a phrase, needs one. **[M]**

### Decision 3 — where the three-outcome convention is stated once

**On a new method page, `docs/gate-outcomes.md`, pointed at from the method page's Build & Test section.**

**No method page states it as a convention today — measured, not inherited, and the census needs two
patterns rather than one.** A `git grep -c` over the tracked instruction files for the four spellings of
the cannot-run outcome, excluding the project-data directory, returns **19 matching lines across 11
files**: 6 in this repository's own profile and 13 elsewhere. **[M]** That census undercounts, because
two restatements spell the rule as "which is not a pass" without naming the outcome. A second
`git grep -c` for that phrase returns **8 lines across 3 files** — 4 in the profile, 2 in
`agents/design.md` already counted, and **2 in `skills/task/reference.md`, which the first pattern does
not reach at all.** **[M]**

So the per-gate restatement spans **6 method contracts, not 4**: `agents/design.md` (where one of the
lines calls the three outcomes "this repository's" in so many words), `agents/spec-writer.md`,
`skills/redline-fold/SKILL.md`, `skills/pr-merged/SKILL.md`, `skills/task/reference.md`, and
`agents/design-review.md` — the last being about whether a design's own pinned gate can be run, which is
the same convention applied to a different subject. **[M]** Every one of them is an instruction about a
named gate rather than a statement of a convention, which is what item 4 establishes. The count changes
no work, because this design keeps all the restatements; it changes what a later reader will find when
they go looking, which is why the undercount is corrected rather than left.

**Two patterns were needed to find them, and that is itself the finding.** A sweep keyed on one spelling
of this convention misses a third of its own subject — the shape the propagation page warns about, where
a file describing a mechanism in its own vocabulary is invisible to a search keyed on the changed token.

Why a new page rather than an existing one:

- **The topically closest page cannot take it.** `docs/workflow.md` owns the section on reading a test
  result and has 31 bytes of headroom. **[M]**
- **The page every agent loads at session start cannot take it either.** `docs/agents-method.md` stood
  5 bytes inside the band when this decision was taken. **[M]** It is out of the band now, with 3,257
  bytes of headroom, and the reason is this plan acting on its own sequencing: subtask 2 extracted from
  that page before subtask 3 added a word to it, which is what the `2→3` dependency was for. So the
  ground held when the decision was made and the decision is what dissolved it — the convention still
  gets its own page, because the second ground below is untouched and the headroom recovered is spent
  elsewhere in the plan rather than available for a section this size.
- **A new reference page needs no row in the Agent Docs table.** `docs/propagation.md` is the shipped
  precedent: it is a pure reference page pointed at from the section that owns its subject and appears in
  no such table. **[M]** So the cost on the session-start page is one pointer, not a table row plus a
  pointer.

**The convention's wording must mandate no element of a spec or a design, or it changes the protected set
as a side effect** — and the test that decides this is mechanical and shape-based, not semantic. The
refusal-agreement leg's `defines_element` returns true for a page when a line carries a backticked token
from the required-element set **and** that same line carries one of a fixed list of presence, absence or
retention words. **[M]** The gate-outcomes page names gates and outcomes and no section of either
document, so it clears the shape; the implementation reads the gate's leg-4 findings and its `elements=`
figure after writing the page rather than asserting this in advance.

**All six existing per-gate restatements stay.** The new page becomes the authority they rest on, and
each of them remains what it is: a gate-specific instruction carrying reasoning the page cannot hold —
the polarity argument in the merge-time backstop is the clearest case, where the convention's value is an
argument about which exit status means what for that one check. Collapsing six live instructions into
pointers is work no acceptance criterion asks for, and the isolation class's own subject is a repeated
literal, which a gate-specific instruction is not.

### Decision 4 — the edit-time guard is blind to a whole class of write, and the fix sits in this task

**Added by amendment, on the author's instruction, after the freeze.** The scope is one defect in a live
protection plus its planted counterexample, and the boundary of "one defect" is argued below rather than
assumed, because the same mechanism has several spellings and a reviewer is owed the line between them.

**The two outcomes, measured.** Against an absolute path to a protected page, with `CLAUDE_PROJECT_DIR`
set to the repository root and the guard fed a synthetic `PreToolUse` payload: **[M]**

| Command shape | Guard's answer |
|---|---|
| `sed -i '' 's/alpha/beta/g' <protected path>` | `permissionDecision: "ask"` with its full confirmation text, exit 0 |
| `sed -i '' 's\|alpha\|beta\|g' <the same path>` | **nothing at all, exit 0** |

**The mechanism, established from the code rather than inherited.** The shell arm segments the command
at `hooks/lib/plan-invariants-guard.sh:350`, which translates each of eight characters — `;`, `&`, `|`,
`(`, `)`, `{`, `}` and the backtick — into a newline and reads each resulting line as a pipeline segment
with its own command word. One step earlier, at `:245`, the quote characters are replaced by spaces, so
by the time segmentation runs there is nothing left to say which characters were inside a quoted span.
A substitution delimiter that happens to be one of those eight therefore cuts the command in four. The
segmentation of the silent case, printed directly: **[M]**

```
1  sed -i     s
2  alpha
3  beta
4  g  /…/agents/design.md
```

**Both of the shell arm's two conditions are satisfied, each in a segment where the other is absent** —
which is why neither fires. Segment 1 carries the in-place writer and sets the in-place flag, because
`-i` matches the short-flag cluster rule at `:315`; its only operand candidates are `-i`, which
`path_shaped` rejects at `:238` as an option, and `s`, which it rejects for carrying neither a slash nor
a dot. Segment 4 carries the resolved protected path, but its command word is `g` — a fragment of the
substitution script — which is in neither the in-place command list at `:249` nor the writer-word list
at `:247`, so no write construct is seen beside the path. The arm's own header reasoning at `:25` is
sound and it is the segmentation underneath it that breaks the pairing.

**The blindness is not pipe-specific, and the real boundary of the defect is one sentence: a separator
character inside a quoted span of the command.** Seventeen delimiters were measured against the same
protected path. All eight segmentation characters are silent; the other nine — `/`, `#`, `,`, `!`, `%`,
`@`, `:`, `+`, `=` — all reach the confirmation correctly. **[M]** The same silence holds for the
double-quoted spelling of the script, for the `-e` spelling, for `perl -pi -e`, for a brace-delimited
address block, and for a second `-e` script when only the second one carries a separator; and it holds
against the guarded record as well as against the protected pages, since both lists are read by the same
arm. **[M]** Treating only the pipe as the defect would ship a counterexample that passes while the
double-quoted spelling of the identical command stays silent, which is the failure the positive-control
requirement exists to prevent — so the subtask closes the class, and the class is defined by that one
sentence rather than by an enumeration of delimiters.

**This is a SEVENTH silent form, and the guard's own header counts six.** The header at `:44` opens
`THE SIX SILENT FORMS OF THE WRITE ARM, every one of them under-firing` and enumerates them: a glob, a
command substitution producing the path, a target list read from a file, an unlisted writer, an
interpreter script's variable-indirected writer, and a directory change that is not a leading prefix.
The quoted-separator form is none of those six. **[M]** So the guard carries a stated count that the
thing it counts already falsifies — the exact defect class this whole task exists to make mechanically
visible, found in the enforcement code of the very mechanism being reworked. Closing the hole makes that
sentence true rather than changing what it claims, which is why the subtask's scope is the silence and
not the number.

**What editing the guard fires, checked rather than claimed.** Three answers, and the third is the one
that binds. **[M]**

- **The guard refuses nothing on itself.** `hooks/lib/plan-invariants-guard.sh` is in neither the
  protected list at `:62` nor the one-member record list at `:81`, and its basename contains no guarded
  basename, so the fast path at `:187` returns before any condition is reached. An `Edit` payload naming
  it, and one naming its suite, are both silent. The entry point at `:87` is **not** guarded either —
  the file says so and the suite asserts it — so the second one-member list is the record alone.
- **No propagation group fires.** The Plan-Invariants group's trigger row names the refusal's *page
  list*, its *guarded-record list* and its *two registrations*. A change to command segmentation touches
  none of the three, and the residual enumeration is mirrored nowhere outside the guard and its own
  suite. So the fix's propagation surface is exactly the two files the subtask names.
- **Both files are on the enforcement surface of the statement inventory**, at rows 42 and 50 of the
  record. Every statement the fix adds, changes or removes there is reported by the inventory comparison
  and has to be taken in by an acceptance act at the group boundary, exactly like any other edit to
  instruction material. That is what editing the guard fires, and it is the only thing it fires.

**The repair direction, measured on a mutant copy rather than proposed.** Neutralise the separator
characters that sit inside a quoted span before segmentation runs, leaving the span's own quoting intact
and leaving the eight characters meaningful everywhere else. Shrinking the separator set is **not** the
repair and was ruled out: those eight characters are what makes a compound command segment at all, and
the silences the guard is deliberately built to keep — a read beside a write, a directory change that is
not a leading prefix — are read off that segmentation. A quote-agnostic mutant carrying this one change
was measured against 56 shapes: all ten spellings of the hole fire, all ten pre-existing confirmations
still fire, all nineteen silences still hold, all six residual forms stay silent, and the acceptance
condition is undisturbed — **56 of 56, zero disagreements**. **[M]** The implementing subtask is free to
reach the same property another way; what is pinned here is the property, the ruled-out direction, and
the shape set the repair is answerable to.

**The positive control is mandatory and was run in both directions before this was written down.** The
suite's current reading is **129 passed, 0 failed**. **[M]** With four `sh_asks` assertions and **four
paired `sh_silent` controls — one per shape** — inserted into a copy of the suite, run in a sandbox copy
of the tree against the **unfixed** guard: **133 passed, 4 failed**, rc 1 — each of the four reporting
`want [ask], got [silent]`, and all four controls passing. Against the fixed guard in the same sandbox:
**137 passed, 0 failed**, rc 0, with no pre-existing assertion disturbed. **[M]** So the test is already
known to be capable of failing, which is the whole point: a test for a command shape the guard ignores is
a test for which the guard's silence and the test's success are the same observation. The live guard was
never touched — it is byte-identical to the commit and every probe ran on a copy. **[M]**

**One control per shape, and not one for the family — the figures above are the second measurement, the
first having been taken with a single control and pinned at 134.** The prescription in subtask 16's row
and in the risks entry has always read "each paired with a silent control", which is eight new
assertions and lands at 137; a lone control cannot reach that figure, so **this document pinned a count
that the sentence beside it falsified — this task's own subject class, in the document that defines the
rule against it.** It is resolved the way the repository's test convention requires rather than the way
the smaller number invited: when a qualifier binds a FAMILY of checks, the negative test is written for
every member. The ground is in the control's own job — it separates "the hole is closed" from "the arm
now over-fires on reads", and a control on the pipe says nothing about whether the double-quoted
spelling has begun firing on a read. So the probe was re-run with four controls and the figures here are
what it gave; **the 137 is measured, not projected.**

The paired silent control is not optional either; it is what
distinguishes closing the hole from making the arm fire on reads, and a repair that bought the four
`ask` assertions by over-firing would be worse than the hole.

**This is not AC33's subject, and the distinction matters for the review.** That criterion asks whether
the SET of pages whose edit fires the refusal is the same after this work as before it. This fix changes
no page's membership in either list, adds no locus defining or enforcing a required element, and leaves
the element record untouched; it changes which command SPELLINGS reach the arm at all. The criterion is
neither satisfied nor threatened by it, and the subtask carries no acceptance criterion of its own — it
is scope the author added, and the decomposition says so where it lands.

**Adjacent shapes found while measuring, recorded for a later decision and deliberately NOT scoped in.**
The author approved closing this arm's blindness, not an audit of the hook's command parsing, so these
are written down and left: **[M]**

| Shape | Answer | Why it is outside this subtask |
|---|---|---|
| The six residual forms the header enumerates | silent | Documented, deliberate, and each one asserted silent in the suite. Not defects |
| The acceptance condition's two residuals — the payload invoked directly, and the flag reached through a variable | silent | Same: stated bounds with assertions behind them |
| A write whose construct is absent from the writer-word list | silent | Residual 4 by another name; widening that list is the audit the author did not approve |

None of the three is affected either way by the repair above, which is the ground for leaving them: the
measured shape set shows the fix neither closes them nor disturbs them, so nothing about this subtask
makes them more or less urgent than they were.

### Items 5 and 6, and the two surfaces each moves

**Item 5 narrows the closing pass in exactly two contracts.** `agents/design.md` § The redline fold says
it authors the design afresh and carries the positive whole-document assertion as its numbered judgement
step; `skills/redline-fold/SKILL.md` repeats both in its own words, in the subagent prompt it spawns, in
the paragraph that keeps "afresh" and "section by section" from being severed, and in its own numbered
judgement step. **[M]** Both narrow; the residue assertions in both stay; "section by section" survives
on its own terms in both, because it constrains how the bytes are delivered and not what the content is
derived from.

**Item 5 also re-bases a signal that would otherwise contradict item 6.** The design contract's
divergence-mode table names a non-empty open-questions section as "the strongest single signal there is"
for the exploratory mode. **[M]** Item 6 narrows that section to questions that change nothing
structural, which is close to the opposite of what the signal is read as meaning. The re-basing: that row
loses its strongest-signal status, and the strongest remaining signal becomes work that creates a
mechanism which does not exist yet — already a row in the same table. Leaving the two statements side by
side is the self-contradiction the judgement class exists to catch, in the document that defines the
judgement class.

**Item 6 lands as a ninth principle, and two independent reasons say it is safe to do so.** The spec's
own ground is the element record: the open-questions section is already a recorded required element of
both documents, so no route can make it newly required — not a writer's template, which already
enumerates it, not a review contract treating its absence as blocking, and not a mechanical check
asserting its presence — and the derivation that reads a severity verdict beside an element-shaped token
therefore yields a pair the record already carries, so no arrival is reported. That ground is about the
record and the derivation, which is the mechanism that decides what is **required**.

The second reason is about the separate mechanism that decides protected-page **membership**, and it
makes the placement doubly safe. That sweep skips three things before testing any page: the principles
page and the guard by path, and every file matching the test-suite name pattern by pattern. **[M]** A
rule naming the open-questions section therefore cannot trip the membership shape test at all when it
sits on the principles page. The three contracts that restate it — the two author-side ones and the
reviewer-side one — are all already inside the protected set, so the shape test cannot move them either.
The reviewer-side statement is required on its own: the spec's criterion says neither statement is
satisfied by the other's presence, and the reviewer surface carries no such rule today. **[M]**

### What a principle rewording actually costs, in files

**Principle 7 is a three-file move; principle 8 is a four-file move.** Measured, not assumed:

| Principle | Files that must move in the same change |
|---|---|
| 7 (the closing fold) | `docs/plan-invariants.md`, the pinned copy in `scripts/check-plan-invariants.py`, and the comparison record |
| 8 (knowability) | the same three, plus `scripts/test-check-plan-invariants.sh`, whose leg-1 mutation fixture quotes a fragment of principle 8's reason and asserts the pinned text names the failure it removes |
| A ninth principle | **five files, not the same three** — the page (the principle, its heading, and the commentary that counts the principles and names how many are prohibitions), the pinned copy, `scripts/test-check-plan-invariants.sh`, whose clean-case leg pins `principles=8` under the label "all eight principles counted", `ai-docs/context.md`, which states the count in **three** statements of its own, and the record. The suite is a member of the structural list and the project profile is an examined surface, so a ninth principle that moved neither would leave the tree red and a false sentence shipped |

`git grep -ln` for either principle's lead sentence returns exactly two tracked files — the page and the
payload. **[M]** The third file holds a fragment rather than the sentence, which is why a search for the
sentence does not find it: the suite's leg-1 legs rewrite `two failures at once: invented content at
authoring time, and a review loop` and then assert the report names `invented content at authoring time`.
**[M]** The pinned copy is a single joined line at a four-space indent while the page's text is
hard-wrapped with three-space continuation indents, and both renderings are load-bearing — the page's
item regex reads the continuation indent and the payload's code segmentation keeps the leading indent
inside the statement. **[U]** on the mechanism, **[M]** on the two renderings themselves.

The record is the last mover in every row above, and it is advanced only by the acceptance route.

**The heading over the principles is a load-bearing literal, and renaming it fails the gate in the
quietest available way — so the rename is an explicit, enumerated edit rather than a side effect.** The
payload splits the page's body on the exact string `## The eight principles`, and a failed split routes
to its cannot-run branch: a rename on the page alone does not produce a finding, it produces exit 2,
which is not a pass and names no principle. The literal appears three times in that payload — the split
itself and two of its refusal messages. **[M]**

**The heading is renamed, not kept.** Keeping it would leave a heading saying "eight" over nine
principles — a stated count made false by the same change, inside the one document that defines the rule
against exactly that. The cheaper edit would have been to leave it, and this design refuses the cheaper
edit on the grounds the task itself exists to enforce. So subtask 14 renames the heading to one that
states no count, in the page and in **all three count-bearing occurrences** in the payload, in the same
edit. The exact split string appears twice there; the third occurrence is the section-reference spelling
inside a refusal message. The label matters because an implementer searching for the split literal alone
would stop at two and leave the third stating a count that is no longer true.

**The project profile states the count three times, and two sweeps missed the third — which is this
task's own subject, so it is named rather than just fixed.** Two of the three are plain sentences a
search for the word finds. The third sits in a bullet whose word "principles" is on one physical line
while its count is on the next, so a search keyed on the word prints a line carrying no count, the hit is
seen, and it is judged not count-bearing. **[M]** That is the same shape as the restatement census two
sections above, where one spelling missed a third of its own subject: the evidence a sweep returns is
shaped by the line the pattern matched, not by the statement the line belongs to.

**A reader editing that bullet will be standing next to three other pinned figures** — the element count,
the protected-page count and the near-miss count. **[M]** None of the three moves for a ninth principle,
and the second of them is one this work's own criteria require to stay put. They are named here so the
edit is surgical rather than a rewrite of the sentence that happens to carry them.

### Where the new mechanical check lives, and where it cannot

**It is a new script and it cannot be a member of the check runner.** The runner's own comment states the
reason for the shipped exemptions verbatim: "a member is invoked with no arguments, and every one of its
verbs requires at least one, so a documented member would report `cannot run` on every run." **[M]** A
per-plan check takes a spec and a design, so it joins `EXEMPT_CHECKS` beside the redline gate and the
fix-plan gate, and it must **not** be spelled as a structural check inside the profile's own list span —
the inventory member parses that span for `bash scripts/<name>.sh` and compares it against the member
table in both directions, so naming it there makes the comparison unsatisfiable. **[M]** Its own test
suite, by contrast, is derived from the tree and **must** be named in the profile's suite list, which is
also compared in both directions. **[M]**

**The check must carry no element-defining locus, and that is a constraint on how it is written, not a
hope.** The shape test's second form reads a shell variable assignment of the form `NAME='…'` and returns
true when any newline- or pipe-separated entry is a required-element token. **[M]** So the new check
pins no list of required sections: it resolves section references against the document's own headings,
and for the one leg that genuinely needs the element token it **delegates**.

**That delegation has a shipped target, and the target has no caller today.** `check-redline.sh acintent
<spec> <design>` already asserts that every criterion in the spec has its verification-intent line in the
design and that no such line names an identifier, and prints `criteria=` and `intent_lines=` beside its
verdict. **[M]** `git grep` for the verb across the whole tree finds it only in the script, its suite,
and one archived design document — **no live workflow invokes it.** **[M]** The convergence pass becomes
its first caller. Three things follow at once: the completeness class gets a tested implementation, a
shipped gate stops being dead, and enforcement of that element stays inside the script that already
carries it and is already protected — so the new script adds no page to the protected set.

**The residual risk of delegating, stated because it is invisible to every mechanism here.** If a later
edit drops the delegated call, the element stays required — the template route still mandates it — so the
element set does not move and the membership test is right not to fire. No protected page is edited, so
no refusal fires either. Coverage of that criterion would simply stop, quietly, and nothing in the
invariants verification or the refusal would say so. The only thing standing between that edit and the
loss is the leg in the new check's own suite asserting that a criterion carrying no verification line is
reported. That leg is therefore not an ordinary test: it is the sole guard on a delegated enforcement,
and a round that deletes it as redundant removes the coverage rather than a duplicate.

### Where an excuse is stored

**Beside the plan it covers: `ai-docs/plans/<spec-base>.excuses.md`, committed, removed by the closing
pass.** The alternative placements fail on a measurement. The repository-mechanics exclusion claims
`.claude-plugin/`, `.claude/`, `ai-docs/fixtures/loop-corpus/`, `.gitignore` and `README.md` and nothing
else; the comparison record is accounted for separately by name, "because it is one file rather than a
class". **[M]** So a new committed file under `ai-docs/fixtures/` would be claimed by nothing and
`unaccounted` would go to 1 — the gate reporting that it says nothing at all about that file. Widening
the exclusion to the whole fixtures directory would make its stated ground ("committed measurement data")
false of its newest member, which is this task's own defect class. Accounting for it by name would work
and costs an edit to the payload and the page.

The plans directory needs none of that: it is already an excluded surface, the lifetime matches — an
excuse covers a finding at a spot in a specific plan — and the shipped correction log is the precedent in
the same family, being committed, consumed by the closing pass and removed by it.

**The spec now says this, so the lifetime is settled rather than assumed.** An excuse dies with the plan
it covers: it lives beside that plan, and within that plan it stands until removed by hand, with an edit
to the covered passage not revoking it and a recurrence at that spot reported as excused. In a later,
unrelated task the check objects from scratch. The closing pass is the one stated exception to removal
being an act of the same kind as granting — it removes every excuse together with the correction log, by
nobody's explicit act, because the plan's end of life ends the spot the excuse covers. The residue
assertion the closing pass owes therefore names three things rather than two, and subtask 11 lands that
third.

**One cost of this lifetime is worth naming, because it is not what the rejected alternative's cost
was.** A grant is per-plan, so the same harmless finding recurring in a later task must be excused
again. That is a repeated interruption rather than a silent failure, and it is the price of not letting a
grant made in one task silence a check in an unrelated one.

### Rejected alternatives

| Alternative | Why not |
|---|---|
| The semantic class inside the existing review contract | Its only output is a ruling, and the criterion requires a report that rules on nothing; and its three verdict values have no room for a could-not-run without changing a parsed contract across a sync group. Cheaper per round, and it cannot satisfy two criteria. |
| The three-outcome convention on `docs/workflow.md` beside the section on reading a test result | 31 bytes of headroom. **[M]** Topically the best home and mechanically unavailable. |
| The three-outcome convention on `docs/plan-invariants.md` | Headroom is ample, and the page declares itself the single authority on the wording of the principles. A gate convention makes it two authorities, and the page's exemption from the refusal rests on it mandating nothing — a property worth not complicating. |
| A new verb on the redline gate for the design-to-source pairing | That script is a protected page, so every subsequent edit to it is an author interruption, and its subject is the correction mechanism rather than plan convergence. The pairing SHAPE is inherited; the file is not. |
| Re-implementing the verification-line leg in the new check | It would state one fact in two places, which is the isolation class the same work introduces, and it would give the new script an element-defining locus and so a seat in the protected set. |
| Narrowing the id character class to lowercase | Buys a second guard against the quoting hazard; costs the ability to name real entities whose names are not lowercase. The authoring rule plus a planted test closes the hazard without the cost. |
| Collapsing the six per-gate restatements into pointers | No criterion asks for it, and each carries gate-specific reasoning the shared page cannot hold. |
| Advancing the comparison record once, at the end of the task | The gate would then report findings for the whole task and no report could be attributed to the step that caused it. The record is advanced at each group boundary instead. |

### One rule of this design's own contract it cannot satisfy, and why

**The decomposition below has sixteen subtasks, and the design contract says a decomposition over seven
should be proposed as a split into several tickets.** The spec's scope section forecloses that: all six
items land as one spec and one task, with the issue's sequencing governing order only and explicitly not
licensing a split of the extent, and that decision is recorded as the first row of the spec's own key
decisions. The sixteenth subtask is scope the author added after the freeze, which widens the conflict
without changing its nature — it was approved as work to do inside this task, so proposing it as a
separate ticket would be proposing back the split the author had just declined. The contract's rule and
the spec's decision cannot both be honoured, so this design honours the spec and names the conflict
rather than resolving it silently. The mitigation is the handoff plan: five groups of three and a
terminal group of one, each group a reviewable unit with its own gate run and its own acceptance act, so
the review burden is bounded per group rather than per task.

**This design cites positions, and the convention it introduces forbids them.** The rule is not yet in
force: the live design contract requires a `file:line` or an empirical result for any load-bearing
mechanism claim, and the live review contract makes a load-bearing claim without one a blocking finding.
This document is reviewed under those contracts. So load-bearing claims here name the entity **and**
carry the evidence the current contract demands, which satisfies today's rule and demonstrates
tomorrow's form. The transition window closes atomically, because both contracts are edited in the same
change by subtask 9.

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | Establish what the acceptance route actually does and prints, by running it against a throwaway root copy rather than against the live record; record the observed verdict line, what the record gained and lost, and whether the edit-time refusal fires on it | `ai-docs/plans/2026-10-16-design-contract-rework.progress.md` | — |
| 2 | Extract the test-conventions section out of the page every agent loads at session start into a new reference page, leaving one anchored pointer, and **re-point all five inbound references, each of which names the file as well as the section and so survives no move**; update the sentence in the code-style page that asserts where the block lives, and the recognised-section list in the reference check; keep the heading text identical so only the file half of each reference changes; re-measure every file touched immediately before and after **[REDLINE S8.1]** | `docs/agents-method.md`, `docs/test-conventions.md` *(new)*, `docs/code-style.md`, `agents/self-review.md`, `agents/spec-writer.md`, `skills/bugfix/SKILL.md`, `scripts/check-references.sh` | 1 |
| 3 | Establish the gate-outcome convention: the three deterministic outcomes with a could-not-run still not a pass, and the replacement standard for a class a model runs — reporting without ruling on harm, a positive control per class, agreement under repetition measured and printed, and never the only check standing. Pointer from the method page's build-and-test section. Confirm the new page carries no element-defining locus | `docs/gate-outcomes.md` *(new)*, `docs/agents-method.md` | 2 |
| 4 | Reword the knowability principle from a prohibition over required elements into a provenance obligation over any number either document states, on the page, in the verification's pinned copy, and in the suite leg that quotes a fragment of its reason | `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `scripts/test-check-plan-invariants.sh` | 3 |
| 5 | Restate the provenance obligation on both author surfaces and on the reviewer surface, binding the behaviour contract and the approach document alike, with the three admitted kinds and the one forbidden kind | `agents/spec-writer.md`, `agents/design.md`, `agents/design-review.md` | 4 |
| 6 | Create the convergence check carrying the provenance and arithmetic legs, with its own suite and its first replayed fixture pinned verbatim to a real sample; add the fixture's subdirectory prefix to the repository-mechanics exclusion so it is claimed rather than unaccounted; register the check as an argument-taking exemption of the runner rather than a member, name the suite in the profile's suite list and the check nowhere in its structural-check span; stage both new scripts so the syntax member's file count moves with them | `scripts/check-plan-convergence.sh` *(new)*, `scripts/test-check-plan-convergence.sh` *(new)*, `ai-docs/fixtures/plan-convergence/` *(new)*, `scripts/check-plan-invariants.py`, `docs/plan-invariants.md`, `scripts/run-checks.sh`, `AGENTS.md` | 5 |
| 7 | State the id convention — the token, the id's form, what carries it on each side, the rule that every illustration uses the placeholder form, **and the carve-out for an entity whose language admits no comment: the statement names the entity, the reference resolves from statement to entity only, and no reverse pairing is asserted for it** — and convert the comment carve-out from an example list into a membership rule keyed on an instrument reading the comment | `docs/plan-invariants.md`, `agents/design.md`, `docs/code-style.md` | 6 |
| 8 | Propagate the comment admission to the four surfaces that sweep or enforce the policy: the mandatory per-change sweep, the whole-tree review contract, the whole-tree review skill, and the handoff instruction that repeats it. The per-change sweep has **79** bytes of headroom and the admission is longer than that, so text leaves it for a reference page in the same change, and **the extraction precedes the addition inside this subtask** rather than being deferred to a separate concern | `agents/self-review.md`, `agents/review-findings.md`, `skills/project-review/SKILL.md`, `skills/context-reset/SKILL.md` | 7 |
| 9 | Move the durable documents off positions: the four sentences requiring a position for a load-bearing claim, the committed correction log's row format, and the re-derive duty in both places that state it — leaving every ephemeral-record obligation untouched and no single rule spanning both. Add the reference-resolution and bidirectional pairing legs with their suite, **the reverse-pairing leg bound to entities whose language admits a comment, with the comment-less case asserted to resolve one way and to be excluded from the reverse direction rather than failing it** | `agents/design.md`, `agents/design-review.md`, `docs/templates/progress-format.md`, `scripts/check-plan-convergence.sh`, `scripts/test-check-plan-convergence.sh` | 8 |
| 10 | Add the completeness and isolation legs, delegating the per-criterion verification-line assertion to the shipped criterion verb instead of restating it; make all three mechanical classes refuse rather than advise, and print the examined-file count and the compared-pair count beside the verdict | `scripts/check-plan-convergence.sh`, `scripts/test-check-plan-convergence.sh`, `agents/design-review.md` | 9 |
| 11 | Add the excusing route: an explicit act that prints the finding it is about to excuse, a per-plan committed store naming the finding, its spot and its grounds, an excused count beside the verdict, removal as an act of the same kind, and the closing pass's new residue obligation over the store | `scripts/check-plan-convergence.sh`, `scripts/test-check-plan-convergence.sh`, `docs/templates/progress-format.md`, `skills/redline-fold/SKILL.md` | 10 |
| 12 | Create the semantic reader's contract and the convergence pass that runs it beside the three mechanical classes in one run, with a positive control per class and repetition agreement measured and printed; wire the invocation into the design step and its recipe; register the new subagent in the embedded inventory, which the standing propagation row obliges in the same change; add the sync group for the new mechanism and the matching reminder arms; extract from each of the three tight files it edits before adding a word to them | `agents/plan-semantics.md` *(new)*, `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/claude-tools-hierarchy.md`, `docs/propagation.md`, `hooks/hooks.json` | 11 |
| 13 | Narrow the closing pass in both contracts that state its behaviour, reword the closing-fold principle so its replacement carries its own reason answering the one it displaces, re-base the divergence-mode signal that would otherwise contradict the open-questions rule, and add the pass's two automatic checks over numbers and references to code | `agents/design.md`, `skills/redline-fold/SKILL.md`, `docs/plan-invariants.md`, `scripts/check-plan-invariants.py` | 12 |
| 14 | Add the ninth principle with its own one-clause reason; rename the heading that states a count to one that states none, in the page and in all three count-bearing occurrences in the payload — two being the exact split string and the third the section-reference spelling in a refusal message; move the commentary that counts the principles and names how many are prohibitions, the suite leg that pins the count, and **all three** count-bearing statements in the project profile, the third of which sits in a bullet carrying three further pinned figures that must not move; and state the price of a left-open gap on the author surfaces and on the reviewer surface, neither satisfied by the other | `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `scripts/test-check-plan-invariants.sh`, `ai-docs/context.md`, `agents/spec-writer.md`, `agents/design.md`, `agents/design-review.md` | 13 |
| 15 | Close the change: **sweep the change's own added lines on every method surface it touched, for a number stating no kind and no origin and for a reference naming a position rather than an entity, and fix what it finds** — the one act whose subject is this work's own output rather than the mechanism it builds; then sweep every fired sync group, bump the plugin's patch version, re-measure every edited instruction file against the cap and the band, run the whole structural check list and read its member and file counts rather than its exit status alone, and put the final acceptance run to the author | `.claude-plugin/plugin.json`, `ai-docs/fixtures/plan-invariants.inventory`, plus whatever that sweep corrects | 14 |
| 16 | **Close the edit-time guard's blindness to a separator character used inside a quoted span of the command**, so a write to a protected page or to the guarded record is put to the author whichever delimiter its in-place script takes; and plant the counterexample in the guard's suite — four `ask` assertions covering the pipe, the double-quoted spelling, a second segmentation character and the guarded record, each paired with a silent control on a read whose script merely contains the same character. **Show the planted assertions FAILING against the unfixed guard before writing them down as passing**, and read the suite's assertion count rather than its exit status alone: **129 before, 133 passed with 4 failed against the unfixed guard, 137 passed with 0 failed after the repair** — eight new assertions, four confirmations and four controls, both end figures measured on a sandbox copy rather than projected. Do not widen the writer-word list, do not shrink the separator set, and do not touch either guarded list — § Approach → Decision 4 carries the measured shape set the repair is answerable to, and the adjacent shapes it leaves alone | `hooks/lib/plan-invariants-guard.sh`, `hooks/lib/test-plan-invariants-guard.sh` | — *(independent of 1–15; see § Handoff plan)* |

**Seven sync groups fire across this decomposition, plus one this work adds.** Derived from the
propagation page's table, which carries 12 distinct group names over 29 data rows — `grep -o '([A-Za-z/-]*
group)' docs/propagation.md | sort -u` prints 12 names, and `grep -c '^> | '` prints 30 lines, one of them
the header. **[R]**, re-confirmed here for the group names. **[M]** The eight:

| Group | Fired by | Why it is wide |
|---|---|---|
| Plan-Invariants | subtasks 4, 6, 7, 13, 14 | Thirteen vocabularies: the page, the three-file verification, the comparison record, the refusal's page list and its two registrations, the seven protected pages, and the two improvement passes that must decline this class. Subtask 6 is in this group because the fixture's exclusion prefix lands in two of its primary members |
| Redline | subtasks 11, 13 | Ten vocabularies; the closing-pass skill is its anchor |
| Task/Design | subtasks 5, 9, 12 | The design contract, the review contract, the task skill and the handoff skill |
| Review | subtask 8 | The whole-tree review skill, its contract, and the per-change sweep |
| Spec-Amendment | subtask 8 | The per-change sweep is a member of this group as well |
| Scouted-Fix | subtasks 9, 11, 12 | The round record's template and the task reference are members |
| Human-register | subtasks 9, 12 | The task reference is a member |
| Convergence *(new)* | subtask 12 | The reader's contract, the check, the pass that runs both, the review contract that consumes the report, and the step that invokes it — five vocabularies for one mechanism, which is what the table's own procedure says needs a group rather than the fallback row |

**One standing row fires too, and it is not a group.** The table carries a row obliging the embedded
tool-and-subagent inventory to be updated in the same change as any edit that changes a Tool, Subagent,
Skill or Hook contract. **[M]** Subtask 12 creates a subagent contract and adds hook arms, so that row
fires twice over. It is listed separately because it is a one-way obligation rather than a sync group,
and because the page it points at has 34 bytes of headroom.

**Subtask 16 fires no sync group, and that is a measured answer rather than an omission.** The
Plan-Invariants group's trigger names the edit-time refusal's page list, its guarded-record list and its
two registrations; a change to how the command string is segmented is none of the three. The one
enumeration the fix sits beside — the residual-form count in the guard's own header — is mirrored on no
other surface, so the propagation surface is the two files the row names. **[M]** § Approach → Decision 4
records the search that establishes it.

## Handoff plan

`M = 16` — six groups, 3 + 3 + 3 + 3 + 3 + 1. Every group is entered through a handoff, including the
first.

**Six groups is admissible, and the arithmetic is the whole of the justification.** Non-terminal groups
must be exactly 3 and the terminal group must be 1..3, so sixteen subtasks admit exactly one shape: five
groups of 3 and a terminal group of 1. **The NUMBER of groups is unbounded** — a cap of three stood in
the handoff skill and was removed as unsupported, both contracts now recording that the count follows
from `M` and the group-size rule rather than being chosen, so a plan of six groups is admissible where it
would not have been before that change. **[M]** Group size, not group count, is what the propose-a-split
duty governs, and that duty is a proposal the author answers.

- **Entry into Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Group A:** subtasks 1–3 — the acceptance act is established, the session-start page gets its headroom
  back, and the gate convention exists for item 3's judgement class to rest on.
- **Handoff after Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group B with fresh context.
- **Group B:** subtasks 4–6 — the knowability principle becomes a provenance obligation and gets its
  first mechanical legs.
- **Handoff after Group B:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group C with fresh context.
- **Group C:** subtasks 7–9 — the id convention, its admission against the comment sweeps, and the move
  of durable documents off positions.
- **Handoff after Group C:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group D with fresh context.
- **Group D:** subtasks 10–12 — the remaining mechanical classes, the excusing route, and the judgement
  class with its pass.
- **Handoff after Group D:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group E with fresh context.
- **Group E:** subtasks 13–15 — the closing pass narrows, the ninth principle lands, and the change is
  closed.
- **Handoff after Group E:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group F with fresh context.
- **Group F:** subtask 16 — terminal group (1 subtask; within the 1..3 range). The edit-time guard's
  blind delimiter class is closed and its counterexample planted.

**Group F is independent of every other group and MAY be run ahead of them, which is how the argument for
fixing the guard early is honoured without renumbering anything.** Its file set is
`hooks/lib/plan-invariants-guard.sh` and `hooks/lib/test-plan-invariants-guard.sh`; no other subtask in
this decomposition names a file under `hooks/lib/` at all — subtask 12's only hook file is the manifest.
**[M]** Nothing in 1–15 depends on it and it depends on nothing. The handoff skill licenses exactly this:
where the design shows two groups independent and their file sets disjoint, the orchestrator may spawn
them concurrently, and the design is the thing that says which those are. **This design says so of Group
F**, and an orchestrator wanting the protection in force before Groups B–E edit a protected page should
run Group F first.

**The argument for placing the fix early was weighed and here is the ruling, with its ground.** The
argument for early is real: **six of the seven protected pages are edited by this task** — every one but
the closing-pass check — across subtasks 2, 5, 7, 9, 10, 11, 12, 13 and 14, **[M]** so while the hole is
open any of those edits written with a separator as its substitution delimiter escapes the author's
authorisation entirely. Against it stand three measured facts. First, **in this session the author cannot
see the confirmation anyway**: the permission mode auto-approves the ask, so the property is already lost
here for a second and independent reason, and fixing the hole early restores it for every other session
but not for this one. Second, the protection's beneficiaries are those other sessions, and **no other
session runs on this branch before it merges** — so the fix reaches all of them wherever it sits in the
branch, and "early" buys nothing for them either. Third, inserting the subtask at position 4 would
renumber 4–15 to 5–16, and this document refers to subtasks by number at dozens of sites while the live
handoff record names Group B as subtasks 4–6; **a subtask number is a positional reference, which is the
exact class of reference this task exists to drive out of durable documents**, so buying the protection
by a mass renumber would spend the task's own subject matter on it.

So: **numbered last, grouped last, and explicitly runnable first.** That placement costs no renumbering,
and the one case where early placement would genuinely buy something — a later session, in a stricter
permission mode, resuming Groups B–E before the fix lands — is covered by the concurrency licence above
rather than by the ordinal. The ground is that the ordinal and the run order are different things here,
and only the second one carries the protection.

**Each group closes with three acts beyond its own verification, and all three are part of the boundary
rather than of a subtask.** First, the whole structural check list is run and its member count, its
parsed-file count and the invariants gate's own verdict line are read — not its exit status alone.
Second, once the id convention exists — which is from Group C onward in ordinal order — the group's own
added lines on method surfaces are checked for a number stating no kind and no origin and for a reference
naming a position rather than an entity. **That act is keyed on whether the convention exists when the
group runs, not on the group's letter**, which matters only because Group F may be run out of order: run
first it is covered by the closing sweep like Groups A and B, run in its ordinal place it owes the
per-group check. Third, the comparison record is brought level by the acceptance route over the change
that group made, which prints the report it is about to take in and is itself put to the author. Six
acceptance acts, one per group, and the reason for one per group rather than one per task is that a
report covering sixteen subtasks cannot be attributed to the subtask that caused it.

**The second act exists because one criterion's subject is this work's own output, and no mechanism this
work builds can reach it.** The requirement that every number and every reference this work puts on a
method page obey the rules it is writing is not satisfiable by the convergence check: that check takes a
specification and a design as its arguments and never reads a method page. Nor is it satisfiable by the
invariants verification, which compares statements for change and rules on no sentence's content. So it
needs a named act, and it gets two — a per-group check from Group C onward, and the whole-change sweep in
subtask 15 — because a sweep run only at the end would be reading sixteen subtasks' worth of added lines
in one pass, which is the review shape this task exists to remove. Group A and Group B are covered by the
closing sweep alone, since the rules they state do not yet exist while they are being written.

**Group F owes the per-group check at its own boundary, whenever it runs, and this is the one place
appending a subtask after the closing sweep leaves a gap that has to be named.** Subtask 15 holds the
whole-change sweep and cannot reach lines added after it, so in ordinal order Group F's own added lines
would be swept by nothing. Run before Group C it is in Group A's and Group B's position and the closing
sweep covers it; run anywhere after, it carries the check itself. Its added lines are comments in two
shell files, and a comment stating a count is exactly what the sweep looks for — the guard's own header
is where a stated count was already found untrue, so this is the last surface that should be exempt from
the rule the task is writing.

**Items 1, 2 and 5 are ordered, and the group boundaries carry the order.** Item 5's stated ground is
that items 1 and 2 removed the content that rots; item 5 is subtask 13, in the last group of the linear
chain, and the dependency chain from 13 back to 4 passes through every subtask of items 1 and 2. A decomposition
letting item 5 land first would ship a decision whose grounds are not yet true.

**The chain through subtasks 1–15 is strictly linear — each of them depends on its predecessor — and
that forecloses all parallelism inside that run, so which links are causal and which are conveniences is
stated rather than left to be re-derived.** Subtask 16 sits outside the chain entirely, depending on
nothing and carrying nothing that depends on it, which is the one piece of parallelism this
decomposition does offer. Eight links are causal: 1→2 (nothing may edit inside the examined corpus before the
acceptance act is understood), 2→3 (the pointer needs the headroom), 4→5 (the restatements restate the
reworded principle), 5→6 (the legs implement the rule just stated), 7→8 (the propagation carries the
admission just written), 10→11 (an excuse excuses a finding the classes must already produce), 11→12 (the
pass reports excused counts beside all four classes), and 14→15 (the close follows the last edit). Six
links are conveniences, and a later round may re-group across any of them: 3→4, 6→7, 8→9, 9→10, 12→13 and
13→14. Five of those six serialise edits to a shared file — the design contract, the check script, or the
principles page and its pinned copy — and 13→14 additionally halves the number of acceptance acts by
putting both principle edits in one group.

**One floor survives any re-grouping, and it is stated separately because the classification above would
otherwise dissolve it.** Cut all six convenience links and the causal components are `{1,2,3}`,
`{4,5,6}`, `{7,8}`, `{9}`, `{10,11,12}`, `{13}`, `{14,15}` and `{16}` — in which subtask 13 is a
free-floating singleton that could run first. Subtask 16 is a free-floating singleton too and that is
deliberate, not an oversight of the same kind: nothing in the spec orders it against anything, so it
carries no floor and may run anywhere. That is item 5 landing before items 1 and 2, which the spec calls a
requirement and not a preference. So: **subtask 13 may not precede subtask 9**, whatever a re-grouping
does to the links around it. That floor is the ordering requirement in its own right, and the convenience
labels do not reach it. The dependency column in the table is conservative and already enforces it; this
sentence is for the round that decides to re-group and reads the labels instead of the column.

## Risks

- **The acceptance act has never been run by anyone, and this work cannot finish without it.** Everything
  known about it is read off the code and a format string. **[R]** *Mitigation:* subtask 1 establishes its
  real behaviour against a throwaway root copy — the entry point takes a root argument, so the live record
  is never the subject of the experiment **[M]** — and records the observed verdict line before any later
  subtask depends on it. A could-not-run there is a stop, not a retry.
- **A new surface can be read as element-defining by shape and so widen the protected set — and two
  different shape tests exist, which are easy to confuse and govern different questions.** The one that
  decides protected-page membership has three routes: a backticked required-element token on a line that
  also carries a presence, absence or retention word; a shell list assignment one of whose entries is
  such a token, which is the route that reads the enforcer's pinned data; and a fenced markdown block
  whose section headings are such tokens, which is the template route. Its own comment states that a
  severity verdict alone is deliberately **not** enough for it. The separate test that decides whether an
  element becomes **required** is the derivation, which reads the review contract for a line carrying both
  an element-shaped token and a severity verdict in one of three spellings. **[M]** Membership and
  requirement are different questions with different patterns. *Mitigation:* the three new surfaces name
  no section of either document; the one leg that needs the token delegates to the script that already
  carries it; and after each new surface lands, the gate's leg-4 findings and its element count are read
  rather than the exit status alone.
- **That sweep skips three things, and this design relies on the third without having named it.** It
  skips the principles page and the guard by path, and every file matching the test-suite name pattern by
  pattern. **[M]** The pattern is what keeps this work's own new suite out of the sweep even though the
  suite will plant element tokens as fixture text. *Mitigation:* the new suite is named to match that
  pattern, which it does by following the sibling convention — stated here because a suite named
  otherwise would redden a leg nobody was watching.
- **`unaccounted` can leave zero, and a non-zero value means the report says nothing at all about the
  files it names.** Two of this work's new files are at risk and they take different answers.
  *Mitigation:* every new instruction file and script is placed where the surface mapping already claims
  it — the documentation and agent directories map to the method surface and the scripts directory to the
  verification surface **[M]**; the excuse record sits beside its plan, inside a directory that is
  already a named exclusion; and the replayed fixture is the one case needing new wiring, so subtask 6
  adds its subdirectory prefix to the repository-mechanics exclusion, whose stated ground already covers
  committed measurement data. The figure is read at every group boundary, and a value of 1 after subtask
  6 means the prefix did not land.
- **Six instruction files sit at or within 500 bytes of the early-warning band and five of them take new
  wording from this work**, one of them obliged by a standing propagation row rather than by anything the
  spec names. **[M]** *Mitigation:* the extraction obligation is attached to each of the four edits that
  needs one — subtask 2 for the session-start page, subtask 8 for the per-change sweep, and subtask 12
  for the remaining two — rather than concentrated in one early subtask that would not cover them. Every
  edited file is measured immediately before and immediately after its own edit, and an extraction
  precedes the wording rather than following it.
- **Subtask 12 carries three of those four extractions as well as a new contract, a new sync group and
  hook arms.** It is the heaviest subtask in the decomposition. *Mitigation:* named as such here, so a
  round that finds it unwieldy splits it on a known boundary rather than discovering the weight late.
- **The syntax gate lists tracked files only, so two new scripts are invisible to it until staged.** Its
  current reading is 58 files parsed. **[R]** *Mitigation:* stage both new scripts with an intent-to-add
  before the gate runs, and read the parsed-file count moving rather than the exit status.
- **The source-side scan would otherwise pair a plan's markers with themselves.** A plan document is
  tracked once committed and carries the same marker token the source carries, so a scan over all tracked
  files would read every statement's id back as a marked source id and every pairing would succeed
  vacuously. *Mitigation:* the scan excludes the directory that holds plan documents, and the suite
  plants a marked plan inside the scanned tree so the exclusion is demonstrated rather than assumed.
- **Two of the four sentences item 2 rewords currently carry project-specific facts on method surfaces.**
  Readers split on whether that is a violation or sits under an audited exemption, and the unmeasured
  input is the exemption register. **[U]** *Mitigation:* the spec puts that condition out of scope, so the
  rewording changes the reference form and leaves the examples exactly as they are. This work neither
  fixes nor extends them, and the design says so rather than letting a reviewer read the untouched
  examples as endorsement.
- **The judgement class's agreement under repetition may come back low.** *Mitigation:* the criterion asks
  for the figure to be measured and printed, not for it to clear a threshold. What the healthy case looks
  like is stated before the first run, so a low figure is reportable as a result rather than readable as
  an unfinished mechanism.
- **A full-file write of a document this size is where a write is most likely to be lost**, with two
  observed attempts dying before the write landed. *Mitigation:* every document in this task is written
  section by section and verified on disk — modification time plus a search for an expected new string —
  before the next section.
- **Eight sync groups fire, and the reminder's path classes are derived from the propagation table.**
  Adding a group changes what that gate computes. *Mitigation:* the new group's arms land in the same
  subtask as its rows, and the gate is re-run with its member count read rather than only its status.
- **A repair to the guard that over-fires is worse than the hole it closes, and the guard's own header
  says why: a refusal that lands on ordinary reads is the kind that gets switched off, which costs the
  whole protection rather than one prompt.** The ambient working style here reads through the shell, so
  the seven most-read pages in the repository meet this arm on nearly every orientation read.
  *Mitigation:* the hole's four `ask` assertions are each paired with a silent control of its own — four
  controls, not one, because this risk is per shape and so is the control that answers it — and the 129
  assertions already in the suite are the regression surface, taking the suite to 137. The repair is
  accepted only on the whole suite, with its assertion count read as part of the verdict rather than its
  exit status alone. The
  measured shape set in § Approach → Decision 4 is what the repair is answerable to, and the one
  direction already ruled out there is shrinking the separator set, which would dissolve the silences
  the guard is built to keep.
- **The guard's suite is a member of the structural check list, so a repair that leaves it red blocks
  every later subtask's boundary**, and Group F may be the first group run. *Mitigation:* the subtask's
  exit condition is the suite green at its new assertion count, measured before the group closes; and
  because the two files are on the enforcement surface of the statement inventory, the group's own
  acceptance act is what takes in the statements the fix moves. Both are boundary acts the plan already
  carries, so nothing new is owed beyond running them for this group too.

## Test Design

The project ships instruction files and shell scripts and has no compiler, so "test" means one of three
things here: a suite beside a script, a structural check over the instruction text, or a measurement
recorded in the round's own working record. **[M]**

- **Suite shape for the new check:** a sibling suite in the same directory, following the shipped pattern
  of the two comparable gates — assertion helpers, fixtures built under a throwaway directory, and where
  tracked-file behaviour is under test, a throwaway repository initialised inside it. **[M]**
- **Entry point:** the new check is invoked by path with a document pair as arguments, which is also why
  it is an exemption of the runner rather than a member.
- **Scenarios per leg:** the finding case, the clean control that proves the finding case is the plant's
  doing, the count printed beside the verdict, and a could-not-run case for each unreadable input.
- **Fixtures:** a fixture pinned to a real sample verbatim is required wherever a leg reads a format, and
  the new check reads a format, so at least one such fixture is committed. **It goes in a named
  subdirectory of the frozen-input directory, and that subdirectory prefix is added to the
  repository-mechanics exclusion in the same subtask that lands the first fixture** — subtask 6. Without
  that, the fixture is claimed by no surface and by no exclusion and the unaccounted count goes to 1.
  **[M]** The exclusion's existing ground — that these files are committed measurement data stating no
  rule a spec or a design is held to — is true of a replayed fixture without alteration, which is what
  makes this a widening of the membership rule rather than a change to its reason. The shape copies the
  one that already claims the other replayed corpus: a named subdirectory prefix rather than the whole
  directory, which keeps the widening as narrow as the thing it admits.
- **The structural check list is the regression surface for every instruction-file edit**, and its
  pre-change baseline is recorded under § Approach as the comparand.
- **Subtask 16's test design, which carries no acceptance criterion and so is stated here in full.** The
  suite already exists and is a member of the structural check list, so nothing is created: **eight
  assertions go into it — four asserting a confirmation and four asserting a silence, one control per
  shape.** The four confirmations cover the pipe delimiter, the double-quoted spelling of the same
  substitution, a second segmentation character, and the same shape aimed at the guarded record rather
  than at a protected page — four because the class is defined by a separator inside a quoted span and a
  single delimiter would not demonstrate the class. **Each one is paired with its own control**: a read
  whose sed script carries the same separator character, in the same quoting, against the same target.
  The control is per shape and not per family because its job is to separate "the hole is closed" from
  "the arm now over-fires on reads", and a control on the pipe says nothing about whether the
  double-quoted spelling has begun firing on a read. **The scenario order is
  part of the design and not a convention:** the four confirmations are run against the unfixed guard
  FIRST and must be seen to fail, because a test for a shape the guard ignores is a test for which the
  guard's silence and the test's success are the same observation; only then is the repair applied and
  the suite required green. The suite's assertion count is read as part of the verdict — **129 before,
  133-passed-4-failed against the unfixed guard, 137 after** — since an assertion that was never reached
  reports nothing and a count that did not move is how that looks from outside. Both figures are
  measured, not projected. **[M]** The
  boundary acts are the existing ones: the whole structural check list by its counts, and the group's own
  acceptance act over the statements the fix moves on the enforcement surface.

AC1 verified by: that a document stating a number without naming, in the same sentence, which kind of number it is and how it was obtained is reported, and that the same sentence carrying both is silent — the two observed in one run over inputs differing only in that clause.
AC2 verified by: that a number whose only possible origin is a measurement of the artefact the document describes is reported wherever it sits in either document, with the number and its location named, against a control where a measurement of something that already exists sits in the same position and is silent.
AC3 verified by: that an estimate showing its derivation in place and a threshold handed down by the task are both accepted while a forbidden figure in the same document is reported, so acceptance and refusal are observed together rather than in separate runs.
AC4 verified by: that a reference identifying its target by position inside a file is reported in a durable plan document while a named-entity reference in the same place is not, with the control being the same two references inside a round's own working record, where neither is reported.
AC5 verified by: that a reference whose named entity has been removed is reported and names the reference that failed to resolve, against a control where the entity is present and the reference silent.
AC6 verified by: that a statement whose id is matched by no marked entity and a marked id that no statement names are each reported with the id and the missing side named; that the number of pairs actually compared is printed beside the verdict, demonstrated on a document and a source carrying no ids at all, where that number is what separates agreement from nothing having been checked; and that an entity whose language admits no comment is resolved from the statement alone and excluded from the reverse direction rather than failing it, with the narrowed guarantee stated where the obligation is.
AC7 verified by: that one id marked on two entities, and one id claimed by two statements, are each reported as ambiguous rather than passing in either direction.
AC8 verified by: that the per-change comment enumeration, the whole-tree review and the handoff instruction each class a comment carrying an id as a directive an instrument reads and report nothing against it, and that deleting one is raised as a finding rather than accepted as a cleanup.
AC9 verified by: that the admitting rule classes a comment form none of its own examples mentions, demonstrated on exactly such a form.
AC10 verified by: that a position inside a file stays accepted in a round's own working record and in review output produced against the file it describes, and that the duty to re-derive every position in a row that is touched still reads as binding there — the control being the durable documents, where the same position is now reported.
AC11 verified by: that the committed record of corrections carries no surviving obligation to re-derive a position, that the ephemeral working record's obligation is unchanged, and that no single rule spans both records.
AC12 verified by: that an object with no stated place, no reason, no stated behaviour or nothing that will verify it is reported with the object and what it lacks named, and that the same report covers a requirement reaching no object, a section reference resolving to nothing, and a criterion carrying no verification line.
AC13 verified by: that one literal stated at two places which can drift apart is reported with both places named, and that a paraphrase of one fact is not reported by this class.
AC14 verified by: that a stated rate or formula whose arithmetic does not hold is reported with the computed value shown beside the written one.
AC15 verified by: that a finding of any of the three mechanical classes prevents the plan from being treated as agreed, observed as a refusal rather than a recommendation, with nothing short of fixing the finding or excusing it explicitly letting the plan proceed.
AC16 verified by: that a single finding is excused only by an explicit act recording which finding, where it sits and on what grounds in terms a later reader can check, that the act shows the finding before excusing it, and that an ordinary run excuses nothing.
AC17 verified by: that an excused finding appears as excused rather than omitted and that the count of excused findings is printed beside the verdict, so a plan carrying ten of them cannot read as a clean one.
AC18 verified by: that an excuse survives an edit to the passage it covers and the same fault recurring at that spot is reported as excused rather than raised afresh, that removing one by hand is an explicit act of the same kind as granting, that the record names the spot plainly enough for a reader to find it, and that the closing pass removes every excuse with the correction record by nobody's explicit act — so the same finding in a later, unrelated plan is objected to from scratch.
AC19 verified by: that a plan contradicting itself, and a plan contradicting an artefact it describes, are each reported, and that neither report carries a verdict on whether the contradiction does harm.
AC20 verified by: that the judgement check distinguishes clean, findings and could-not-run, and that whatever consumes its result refuses on a could-not-run rather than proceeding.
AC21 verified by: that a deliberately planted fault of each class the judgement check covers is caught by it, and that a class for which no such demonstration exists is reported as uncovered rather than counted as covered.
AC22 verified by: that the judgement check's agreement across repeated runs over one unchanged input is measured and printed with its result, with the healthy expectation stated before the first run so a low figure reads as a result.
AC23 verified by: that the three mechanical classes' results are produced in the same pass as the judgement result, so no run exists in which the judgement stands alone.
AC24 verified by: that the closing pass retains the frozen document and applies the correction rows to the items that diverged, and that a pass re-authoring the document is reported as a violation of the stated principle rather than accepted as a stylistic choice.
AC25 verified by: that over the items no correction was recorded against, the pass reports a number that no longer holds and an identity that no longer pairs in either direction and owes nothing further, that no obligation anywhere still requires a reader to assert the whole document describes what shipped, and that a stale sentence carrying neither a number nor an identity passes unreported by design.
AC26 verified by: that over the items a correction was recorded against, a reader reads the result and vouches for it.
AC27 verified by: that the pass still strips the spent scaffolding, removes the correction record and removes the plan's record of excuses, and that anything retaining any of those three afterwards is reported.
AC28 verified by: that the behaviour contract still collapses to its record of deliberate absence and the sections it retains survive the pass byte-identically, unchanged by this work.
AC29 verified by: that the principle governing the closing pass states its own reason and that the reason accounts for why an edit in place is now safe where it previously was not.
AC30 verified by: that a plan leaving open a question whose answer would change the chosen approach, the requirements or how the work is broken up is refused at review rather than merely noted by its author, and that a plan whose open questions change none of the three is accepted.
AC31 verified by: that a gap left open which later turns out to have changed one of those three re-enters the full design-and-review cycle, and that patching the agreed plan in place is refused.
AC32 verified by: that the price of leaving a gap open is stated to the author of a plan and to its reviewer, and that removing either statement leaves the other unsatisfied.
AC33 verified by: that the set of pages whose edit fires the author-authorised refusal is the same after this work as before it, observed under both conditions the criterion names — that no wording added makes an element of either document required, and that no page or script added or edited acquires a locus defining or enforcing one — with the required-element set unmoved and both directions of the element comparison and both directions of the refusal-coverage comparison agreeing.
AC34 verified by: that every number this work introduces into a method page names its kind and its origin in the same sentence, and every reference it introduces names an entity rather than a position — the rules observed holding first for the documents that state them.
AC35 verified by: that every instruction file this work edits is measured immediately before and immediately after its own edit, that none ends above the cap or newly inside the early-warning band, and that where new wording would have crossed either line, text left for a reference page in the same change.

## Open questions

**Four questions this design depends on are settled in the spec and are not open here.** The criterion
about the protected set carries both the conditions it needs, and the second — that no page or script
this work adds or edits acquires a locus defining or enforcing a required element — is the one this
design engineers for. The sixth item's ground is the element record: the open-questions section is
already a recorded required element of both documents, so no route can make it newly required, and the
derivation that reads a severity verdict beside an element-shaped token yields a pair the record already
carries. The comment-less language case is narrowed in the criterion itself, so the one-way resolution
is a requirement rather than a reading. And an excuse dies with the plan it covers.

Two questions remain open, and neither changes the approach, the requirements, nor the breakdown:

- **A shipped gate has no caller, which this design treats as an opportunity rather than a defect.** The
  verb that asserts every criterion has its verification-intent line and that no such line names an
  identifier exists, is tested, and is invoked by nothing in any live workflow — only by its own suite and
  one archived plan. **[M]** The convergence pass becomes its first caller. Whether that gap should also
  be reported separately as a pre-existing defect is the author's call; this design does not fix it beyond
  giving the verb a caller.
- **Three classes of command still escape the edit-time guard after subtask 16, all of them documented
  bounds rather than discoveries, and whether any should be closed is the author's call.** The six
  residual forms the guard's header enumerates, the acceptance condition's two residuals, and a writer
  whose construct is absent from the writer-word list. Each is asserted silent in the suite today, each
  under-fires rather than over-fires, and the repair in subtask 16 neither closes nor disturbs any of
  them — measured. **[M]** They are recorded in § Approach → Decision 4 with that measurement beside
  them. The author approved closing one arm's blindness, not auditing the hook's command parsing, so
  nothing here is scoped in; this question exists so the decision is the author's rather than being
  settled by the silence of a design that had measured them and said nothing.

