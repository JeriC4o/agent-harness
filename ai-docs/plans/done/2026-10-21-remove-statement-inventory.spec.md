# Removing the statement-inventory comparison

**Source:** ticket GH-130
**Date:** 2026-10-21
**Tracked in:** GH-130

**What this is about, so the document stands on its own.** One of this repository's verifications answers
four questions about what a spec and a design are. Three of them compare one file against another: the
base principles against a second copy of the same sentences held inside the verification itself; the set
of elements each document must be composed of, derived from the pages that mandate one and compared
against the published record of that set, in both directions; and the edit-time refusal's live coverage
against the published table of pages it is supposed to cover, also in both directions. The fourth is
different in kind. It keeps a recorded snapshot of every sentence in the repository's instruction
material and compares the tree against it, reporting every statement that arrived, departed, changed or —
in a file taking the code spelling — moved. That snapshot advances only through one by-hand act, which
prints what it is about to take in and then rewrites the snapshot from the tree.

**The fourth comparison is removed, with its snapshot, its by-hand advance, and the parts of the
edit-time refusal that exist only to guard those two. Nothing is built in its place.**

**Why, and this is the whole of the reason.** A pull request's diff already shows which instruction files
a change touched. The list of those files is just their names, so pinning their content to recorded
versions adds volume and nothing else. A human's approval of a pull request **is** the approval of the
edits in it, so asking for a second confirmation puts the same judgement a second time in a worse format.
It is useless work.

**The ticket is declined on one point, and this document records that rather than hiding it.** GH-130 asks
for this comparison to be kept, narrowed to a cheap tripwire on an instruction edit that reached the tree
with no pull request behind it. That is declined. Such an edit either went through review or should not
exist, so there is no class left for a mechanism to watch. The most anything can do is notice, within a
working session, that a file differs from what it remembers editing and ask whether an edit made outside
the flow should be validated by process — ordinary conversation, not a gate, and nothing is built for it.
What validation an edit needs follows from the edit: code through tests, prose through reading. Both
already exist. The ticket is not re-filed.

**Scale, so the removal's reach is visible.** Measured on this branch's clean tree on 2026-10-21, by the
verification's own verdict line and per-surface roster: nine principles, thirteen elements, five examined
surfaces carrying 137 pages and 30,710 statements between them, no tracked file unaccounted for, no
findings; three further surfaces excluded by design. The snapshot carries one row per examined page. Read
every figure as an as-of measurement — all of them move with any later change to the examined surfaces,
and the statement total is the one that stops existing.

## Scope

1. **No run of the verification reports a statement as having arrived, departed, changed or moved.** The
   comparison against a recorded snapshot of the instruction material ceases to exist, as does the
   segmentation of files into statements that fed it.

2. **The recorded snapshot leaves the repository**, and nothing reads one. A tree carrying no such
   snapshot is an ordinary tree rather than one the verification cannot run against.

3. **The by-hand advance ceases to exist.** There is no route, by hand or otherwise, that rewrites a
   record of the instruction material, because there is no such record to rewrite.

4. **The edit-time refusal stops having anything to do with the snapshot or its advance**, and keeps
   everything it does for the pages that define or enforce a required element. Those two sets of
   behaviour are separated exactly: a refusal arm that survives for the snapshot would guard a file that
   no longer exists, and a page arm removed with it would be a regression in the one protection this task
   leaves standing.

5. **The verification's verdict line and per-surface roster report only what it measured.** A figure
   naming a quantity nothing measures is the defect this removal would otherwise introduce, and it is the
   first thing the result is read for.

6. **The three comparisons between files keep running as a gate, unchanged.** Their answers, the
   directions they compare in, their distinct could-not-run outcome and their place in the sequence of
   checks run before a commit all stay as they are.

7. **The examined corpus keeps its definition**, because the refusal-coverage comparison reads the files
   on it looking for a rule that makes an element required. The five examined surfaces, the three
   surfaces excluded by design with a membership rule each, and the count of tracked files that neither a
   surface nor an exclusion claims all keep their meaning, their place in the verdict line and their
   lines in the roster.

8. **Every surface that describes the removed comparison stops describing it.** That includes the
   published authority on these principles — its stated bounds, its account of which surfaces are refused
   and which are examined, and its account of what a clean result means — this repository's own contract
   for the checks it runs before a commit, its record of this mechanism and of the mechanism's open
   bounds, the sync-group table that keeps these surfaces moving together, and the prose in a
   neighbouring check that compares its own record's polarity and its own missing levelling act against
   the ones being removed.

9. **What the removal gives up is stated where the bounds are stated, whole rather than in one of its
   halves.** Two classes of change are from now on caught by the pull-request diff and by nothing
   mechanical: a mandate arriving on an examined page that the element derivation does not read, in words
   the coverage sweep does not recognise; and a change to prose that is not one of the principles' own
   numbered sentences, those sentences being the only prose any surviving comparison pins, so the
   explanatory paragraphs around them, and prose anywhere else on the examined surfaces, are pinned by
   nothing. That is the premise of this decision, written down rather than left to be rediscovered, and it
   is one statement with two parts wherever it appears: a surface carrying only the first half understates
   the bound.

## Out of scope

- **The nine principles and the thirteen required elements themselves.** Neither their wording, their
  count, nor the record of them is touched. The comparison that pins the wording and the comparison that
  pins the set in both directions both survive.
- **The protected page set and the breadth of the edit-time refusal over it.** Every page stays covered,
  the refusal stays page-wide, and every firing and silent direction it is documented as having keeps its
  behaviour.
- **Any replacement for the removed comparison.** Named explicitly so no later reader re-proposes one:
  walking the default branch's instruction-file commits and requiring each to be reachable from a merged
  pull request was offered and is declined. So is any cheaper or narrower variant of the tripwire the
  ticket asks for. The net effect of this task is a removal.
- **The earlier plan for this ticket.** Moving the snapshot's advance into the pass that closes approved
  work, making that pass owed by every task, and changing what the merge-time cleanup refuses are all
  abandoned, not deferred. Those passes and that refusal are untouched.
- **Merging the verification's two payload files back into one.** The second one exists because the first
  crossed a size limit that the removal relieves. Taking advantage of that is a refactor with no motive
  beyond size, and the guard that makes the split safe is already proven.
- **The neighbouring convergence check's own record and the way it is brought level.** Only the prose
  that points at the mechanism being removed changes there.
- **Historical records.** The completed plan documents for the work that built this mechanism, and the
  learning-record entry describing how its approach was arrived at, record what happened and stay as
  they are.
- **A consuming project's own instruction material.** Whether it would ever have joined the examined
  corpus is already recorded as a deferred question by the page that would answer it, and that page ships
  either way.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| Whether the examined corpus still earns five surfaces and three named exclusions, now that only the refusal-coverage sweep reads it | The sweep genuinely reads every file on all five, so the breadth is doing work today. The figure that would justify narrowing it is a finding that only the breadth caught, and no such finding has been observed. Narrowing on a judgement rather than on that would trade a measured reach for a guess | Only if the sweep turns out never to fire outside a handful of pages |
| Whether the neighbouring convergence check's own record should gain an explicit act that prints what it is about to take in | That check's own prose records the gap and names the act being removed here as the model it would have copied. The gap predates this task and is not created by it; what this task owes is to stop pointing at a mechanism that will not exist | No — the gap is already recorded where that check describes itself |

## Key decisions

| Question | Decision |
|---|---|
| Is the comparison moved, as the ticket asks, or removed? | Removed. The pull-request diff already shows which instruction files a change touched; the list of those files is just their names, so pinning their content to recorded versions adds volume and nothing else. A human's approval of a pull request is the approval of the edits in it, so a second confirmation asks the same judgement twice in a worse format. It is useless work. This is settled and is not re-opened. |
| Does a cheap tripwire on an edit with no pull request behind it survive? | No, and this declines what GH-130 asks for. An instruction edit either went through review or should not exist, so there is no class left for a mechanism to watch. |
| Then what notices an edit made outside the flow? | Within a working session, an agent noticing that a file differs from what it remembers editing, and asking whether that edit should be validated by process. Ordinary conversation. Nothing is built for it. |
| What validation does an instruction edit need? | Whatever its own kind needs: code through tests, prose through reading. Both already exist. |
| Is a replacement mechanism built? | No. The one that was offered — requiring every instruction-file commit on the default branch to be reachable from a merged pull request — is declined, and is named in this document so it is not re-proposed. |
| Is GH-130 re-filed with the narrower request? | No. This document carries the decision and its ground. |
| Why do the other three comparisons survive? | They check agreement **between** files, which a diff cannot show: a page against a copy of its own sentences held elsewhere, a derived set against a published record in both directions, and a live refusal's coverage against a published table in both directions. A reader approving a diff sees one side of each of those pairs. |
| Does the examined corpus survive? | Yes. The refusal-coverage comparison reads the files on the five examined surfaces, so the surfaces, the page count, the three by-design exclusions and the count of files neither a surface nor an exclusion claims all keep their meaning and their place in the result. |
| What happens to the snapshot's own edit-time protection? | It goes with the snapshot. A refusal arm guarding a deleted file is dead weight that reads as protection. The refusal's coverage of the pages that define or enforce a required element is untouched. |
| Does the result still carry a statement total? | No. Nothing measures one, and a verdict line reporting a figure nothing measured is worse than one that reports less. |
| What becomes of the record of this mechanism's open bounds? | Of the three bounds recorded there, two go whole and one goes in part. **Whole:** that the record could be brought level in the same pass as the change it would have reported, and whether the report's volume stays proportionate once the corpus reached a steady state. **In part:** that the verification is a change detector against an accepted record rather than a presence assertion, so a clean verdict means less than it looks — that framing, and the measured departure count and statement-total movement that evidenced it, are the removed comparison and go with it. **What survives of it** is the one clause that never depended on it: nothing asserts that the principles page reaches an installed copy at all, the install check inventorying skills, agents and hook events with no arm for documentation. That clause stays as a bound in its own right rather than as an instance of a framing that no longer applies. The entry's preamble also measures the instruction material in pages and in statements; the statement figure names a quantity nothing will measure after this and goes with the comparison — AC10 is where that is required, together with the rest of the entry's re-authoring, because AC10 already owns this record and a second home for one figure would be a second place to keep in step. The question stays open on the surviving clause and on the bound the removal creates. |
| Do the verification's two payload files merge back into one? | No. Out of scope. |
| What is given up, stated rather than argued? | Two classes of change are from now on caught by the pull-request diff and by nothing mechanical: a mandate arriving on an examined page that the element derivation does not read, in words the coverage sweep does not recognise; and a change to prose that is not one of the principles' own numbered sentences, those sentences being the only prose any surviving comparison pins, so the explanatory paragraphs around them, and prose anywhere else on the examined surfaces, are pinned by nothing. |

## Technical constraints

- **No figure on the verdict line, and no line of the per-surface roster, may name a quantity nothing
  measured.** Every figure the result carries traces to one of the three surviving comparisons or to the
  corpus they read, on every outcome path including the one where the verification cannot run.
- **The roster keeps three distinguishable states, and the state that reports findings keeps being
  reachable.** Today a surface carrying findings is only ever shown in that state by a finding the removed
  comparison produced; after the removal the surviving comparisons must be what puts a surface in it,
  because a state nothing can reach is a state that will silently stop working. The defect this guards
  against has happened here before: a finding that computed its surface and printed it in its own text
  without recording it left the surface carrying every finding of the run reading as examined and clean.
- **Nothing that checks the surviving comparisons may be satisfied by a finding the removed one
  produced.** Today any text change anywhere in the instruction material reddens the run, so a check that
  plants a defect for one of the other comparisons passes whether that comparison saw it or not. After the
  removal each must stand on its own answer.
- **The three outcomes stay, and a could-not-run is never a pass.** Clean, findings and could-not-run stay
  distinguishable, and every input the verification still needs keeps taking the could-not-run branch when
  it is absent, unreadable or empty, rather than reading as agreement. The inputs that can produce that
  outcome are exactly the ones the surviving comparisons read — no more, and none of them a record of the
  instruction material.
- **The refusal's two concerns are separated by what each arm's subject is, not by where the arm sits.**
  Some arms exist only for the snapshot and for the shape of the command that advanced it; the rest cover
  the protected pages through both the file-editing route and the shell route. The documented set of forms
  the refusal deliberately does not reach shrinks to the forms that still exist, and the stated reason it
  gives an author names only the one class it still guards.
- **The published authority on these principles must describe only mechanisms that exist.** A stated bound
  naming a comparison that was removed is worse than no bound, and that page carries three such bounds
  today, one of which asserts that an edit escaping the refusal is caught by the comparison instead.
- **Every co-moving surface moves in one change.** This mechanism is described in several vocabularies
  that share no searchable token — the verification and its payload files, the edit-time refusal and its
  registration, the authority page, this repository's contract for its own checks, its record of the
  mechanism and of the mechanism's bounds, the sync-group table, and a neighbouring check's prose about
  this one. A sweep by token reaches at most one of them.
- **Where the sync-group table changes, whatever the enforcement layer derives from it stays in agreement
  with it, in both directions**, and the sequence of checks run before a commit stays in agreement with
  its own published list, also in both directions — this mechanism's entry sits inside the span that list
  is derived from.
- **A file's own header prose moves with its code.** Each of the files involved describes what it holds
  and why, and that prose sits on an examined surface.
- **The method half may not acquire a project fact.** The authority page ships to every installing
  project, so a project path, a project command or this repository's ticket prefix stays on the profile
  side — which is also what made the removed snapshot a profile artefact in the first place.
- **The published inventory of non-shell payload files keeps agreeing with the tree**, on both pages that
  state it, since nothing derives either one.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | With any sentence in any instruction file altered, added or deleted, and with no other change, a verification run says nothing about a statement having arrived, departed, changed or moved, and names no recorded inventory of the instruction material anywhere in its output. |
| AC2 | On a tree that carries no recorded inventory of the instruction material at all, a verification run reaches a verdict rather than reporting that it cannot run; and no file in the tree holds such an inventory. |
| AC3 | A verification run's verdict line carries a figure only for a quantity measured on that run, and carries no statement total on any outcome, the one where it cannot run included. |
| AC4 | On a run where exactly one surface carries a finding, the roster reports that surface as examined-with-findings and every other examined surface as examined-clean, and the finding that puts it in that state is produced by one of the three surviving comparisons; a surface whose files could not all be read is still reported as not-examined rather than as clean; and each of the three surfaces excluded by design is still named with its reason. |
| AC5 | A tracked file that is on no examined surface and in no named exclusion is still counted on the verdict line and named with its path in the roster. |
| AC6 | An absent principle is still reported distinctly from a reworded one; a one-sided change to the required-element set is still reported in whichever direction it happened, with a widened removal list reported as a prohibition arriving rather than absorbed into the set; and a gap or a surplus in the edit-time refusal's coverage is still reported in both directions. Each of the three still reports being unable to run as its own outcome rather than as agreement, and no such outcome depends on a record of the instruction material. |
| AC7 | An edit to a page that defines or enforces a required element of a spec or a design is still put to the author whatever the edit touches, reached through the file-editing route and through the shell route alike, including through a leading directory change, an in-place editor, a redirect, a move, a removal and a script that opens the page for writing; and a read of the same page through any of those routes stays silent. |
| AC8 | No edit to any path, and no command, is put to the author on account of a record of the instruction material or of an act that levelled one, and the text the refusal shows an author mentions neither. |
| AC9 | The published authority on these principles asks no reader to level a record, states as a bound only what still holds, and its account of which surfaces are refused, which are examined and what a clean result means agrees with what the verification now does. |
| AC10 | This repository's own contract for the checks it runs before a commit, its record of this mechanism, and every other page that described the removed comparison or its by-hand advance describe neither; and the record of this mechanism's open bounds drops the two bounds whose whole subject was the removed comparison, keeps of the third only the clause that nothing asserts the principles page reaches an installed copy, states no count of statements in the instruction material anywhere, including in its own preamble, and claims a number of bounds that matches the number it then carries. |
| AC11 | The bound that the removal creates is stated wherever this mechanism's bounds are stated, and stated whole rather than in one of its halves. Two classes of change are from now on caught by the pull-request diff and by nothing mechanical: a mandate arriving on an examined page that the element derivation does not read, in words the coverage sweep does not recognise; and a change to prose that is not one of the principles' own numbered sentences, those sentences being the only prose any surviving comparison pins, so the explanatory paragraphs around them, and prose anywhere else on the examined surfaces, are pinned by nothing. |
| AC12 | The whole sequence of checks run before a commit is clean on the tree this change leaves, read by each member's own verdict rather than by its exit status alone, with no member's input set silently narrowed, and with the published list of those members and the set the sequence derives for itself in agreement in both directions. |

## Open questions

- Whether a mandate of the class AC11 names has ever actually arrived in this tree. The answer changes
  neither the chosen approach, nor what the system must do, nor how the work breaks up: the removal is
  settled on the ground that review covers it, and the bound is recorded either way. It would only change
  what a later reader does about the bound.
