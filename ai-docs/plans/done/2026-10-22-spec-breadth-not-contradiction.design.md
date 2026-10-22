# Design: A spec broader than its design is not a contradiction

**Ticket:** GH-146
**Date:** 2026-10-22
**Spec:** ai-docs/plans/2026-10-22-spec-breadth-not-contradiction.spec.md

## Approach

**One test, worded once, and every trigger points at it.** The rule becomes a tenth base principle on
`docs/plan-invariants.md`, which is already the single authority on principle wording. The fuller
three-case explanation sits on the same page, in the explanatory prose under the principles, beside the
paragraph that already explains the two existing tests. Every review contract and every amendment trigger
states only its own outcome and a pointer to the principle — a link to `#the-base-principles`, except
where a file's size forces the pointer into words — and no site defines a case again. A site states
the outcome for each case it acts on; where a site's budget allows one clause, that clause names breadth
and says only a genuine conflict counts, which leaves the second case outside the trigger without naming
it. Two copies of the test in two contracts is the drift the fifth principle exists to prevent, and the
spec's decision on where the wording lives asks for exactly this.

### The principle and its explanation

- **The new numbered item is appended after the ninth**, not inserted beside the fifth, which is its
  parent. Inserting would renumber the four after it, and principles are named by number in findings of
  the plan-invariants verification and in prose elsewhere in the tree. Appending moves nothing.
- **The sentence carries the rule, the conflict definition and its own reason.** Its content: a spec
  broader than its design is not a contradiction, and only a genuine conflict changes the spec; a genuine
  conflict is a design that does what the spec explicitly rules out, or drops a behaviour an acceptance
  criterion requires, with no other sentence of the same spec requiring it; a spec that is general or
  silent where the design is specific is breadth, and a departure another sentence of the spec requires is
  stated once, among the design's risks, and is not a spec finding either. The one-clause reason: a spec
  narrowed to match its design states the design's detail a second time, costs an approval and a fresh
  planning round, and is deleted when the closing fold collapses the spec, so the narrowing is paid for
  and then discarded. It is a test, in the shape the spec's constraint asks for: it hands a reviewer the
  question "does the design do what the spec rules out, or drop what a criterion requires?" rather than a
  boundary on wording.
- **The explanatory paragraph that introduces the tests among the principles is reworded** so it counts
  the new principle among the tests rather than the prohibitions, and a new paragraph after it states the
  test in full: a spec sentence is read for its intent within the whole spec; the three cases (breadth,
  a departure the spec itself requires, a genuine conflict) with only the third being a finding against
  the pair, the third pointing to the numbered sentence's definition of a genuine conflict rather than
  wording it again; a spec-internal tension the design resolves by following the spec's more specific sentence is
  the second case; a genuine conflict's remedy is either the design complying, routed as a design-side
  fix, or the requirement changing, which is a spec amendment the user approves, and a reviewer presumes
  neither; the test covers spec sentences only, so a design sentence the implementation contradicts routes
  exactly as before; and the principle is the fifth principle applied at the spec/design boundary. That
  paragraph is the single statement of the fuller test. It is explanatory prose, which the verification
  pins nowhere, while the numbered sentence is pinned.
- **The pinned copy gains the same sentence.** `PINNED` in `scripts/check-plan-invariants.py` holds one
  string per numbered principle, in order, and leg 1 walks that list (the `for idx, want in
  enumerate(PINNED, 1)` loop) reporting an absent item as `leg1-absence` and a changed one as
  `leg1-wording`. A tenth string makes the new principle subject to both, which is what AC8 asks for and
  what the authorisation route on that page already describes: page and pinned copy edited together.
- **One describing sentence moves with it.** The Lifecycle paragraph for the principles page in
  `docs/agent-docs-index.md` says "a ninth principle" travels the authorisation route, but the page
  already holds nine, so the ordinal is stale rather than naming the next. It is reworded to say "a new
  principle", which stays true at any count. Its closing clause, that a one-sided edit is reported rather
  than applied, is false for a principle added to the page alone, which leg 1 does not see; it is narrowed
  to say a one-sided wording change or removal is reported.

### Design review

`agents/design-review.md` carries three changes, all pointing at the principle rather than restating it.

- **A checklist item, "Spec breadth".** A spec less precise than the design is not an issue at any
  severity, and asking for the spec to be narrowed to match the design is itself a review defect, the
  same shape the contract already uses for asking for test content. The reviewer classifies by the test.
  Breadth raises nothing. A departure another spec sentence requires raises nothing against the spec;
  when the design does not state that departure among its risks, the review raises a `minor`
  design-side issue asking the design to state it there (AC2). A genuine conflict is raised as `major`,
  and its suggestion names both remedies — make the design comply, or change the requirement through the
  Spec Amendment recipe, which puts the change to the user — and presumes neither (AC3).
- **The spec-amending-notes sentence under the GO verdict is rewritten.** It stops stating a fixed re-run
  of the planning chain and says instead that a GO carries no spec-amending note: a genuine conflict is
  `major`, so it arrives on an ITERATE, where the Spec Amendment recipe and its own route question take
  it. One route, stated by the recipe, in fewer words than the sentence it replaces.
- **The convergence checklist item learns the reader's two new outputs.** The reader's breadth notes are
  not findings and are not raised; a reader run whose breadth control came back flagged has shown it read
  breadth as a conflict on that run, so its self-contradiction findings across the pair are weighed
  against the principle rather than taken as found.

AC1 and AC7 follow from the checklist item. On the merged convergence-check pair, the criterion that every
class, count and verdict is unchanged meets a design that changes two things on cannot-run paths: roster
lines for classes that never ran read not-examined, because the spec's own constraint that the roster
never shows an unexamined class as clean requires it, and a missing required-element record reports only
"could not be read", which changes message text and touches no class, count or verdict. The decision that
the invocation is unchanged meets a design that keeps the workflow's two-argument call and retires an
optional flag; the constraint that an absent required input is cannot-run meets a design that skips one
class because the spec's own decision on a project with no baseline record directs it. The roster change
and the baseline skip are the second case; the message-text change is breadth; the retired flag is
breadth, or at most the second case. The merged design states all four among its risks — so the review
raises no spec amendment on any of them.

### The Spec Amendment recipe

- **The recipe in `skills/task/reference.md` classifies by the test.** Its classification step today
  splits notes into design-internal and spec-amending, the latter being any note implying a spec wording,
  criterion or constraint change. It becomes: breadth is neither and is dropped; a departure the spec
  itself requires is design-internal (the design states it among its risks); spec-amending is a genuine
  conflict only. The recipe's entry is stated as what actually reaches it: any Step 7 verdict carrying a
  genuine-conflict row — AC3's conflict is `major` and arrives on an ITERATE, so a GO carries no
  spec-amending note — or a Step 11 finding that fires Arm A, the post-freeze entry the skill's recipe
  section already names. For a Step 7 genuine-conflict row the
  surface-to-user step asks which remedy the user wants, in plain product terms, design complying first;
  design complying returns to Step 6 as an ordinary ITERATE does, and the requirement changing continues
  through the recipe's existing spawn and route-question steps.
- **On an ITERATE entry the verdict's own loop resumes after the amendment, whatever the route question
  answers.** The route question's "No" branch runs no design re-derivation and no design-review round, and
  so leaves no GO, while Step 8's first action requires one. So once the spec is amended, the orchestrator
  returns to Step 6 against the amended spec — the design subagent revises the design for the verdict's
  other rows and for the amended requirement — then to Step 7, the round counting against Step 7's
  round cap. On an ITERATE entry the route question's answer is moot: the design is not yet frozen, so
  there is neither a frozen base to re-derive nor a redline log to reset, and the Step 6 → Step 7 return is
  the ITERATE loop itself, which the question never governed. The route question keeps its wording, as the
  spec's out-of-scope list requires. The recipe states this as one clause of the ITERATE entry, after the
  route question, so the "No" branch's "no design-review round" stays true of the post-freeze entry from
  Step 11 Arm A and is not reworded.
- **The heading is renamed** to match
  the wider entry — "triggered from a Step 7 verdict" — and its one inbound link, in
  `skills/task/SKILL.md`, follows.
- **The Step 7 GO bullet in `skills/task/SKILL.md` stops stating its own route.** Its closing clause
  says spec-amending notes need a Step 6 → Step 7 re-run; it becomes the shorter statement that a GO
  carries no spec-amending note, a genuine conflict being `major` and arriving on an ITERATE.
- **The Step 7 ITERATE bullet gains one clause**: a genuine-conflict row goes to the Spec Amendment
  recipe's remedy question before Step 6, and Step 6 follows whichever remedy the user picks. Without it the orchestrator follows "back to Step 6" on an
  ITERATE, never reaches the recipe, and hands the conflict to the design subagent, so the user is never
  offered the requirement-changing remedy (AC3).
- **The skill's link to the recipe** carries the short label "reference.md § Spec Amendment recipe"
  rather than the full heading, beside the renamed anchor.

### The implementation-time subject trigger

The Arm A question — would closing this finding leave a sentence in a spec or design untrue? — gains one
clause at every site that states it: a spec sentence merely broader than what shipped is not left untrue,
and only a genuine conflict under the principle counts (AC6). "Only a genuine conflict counts" is what
keeps the second case — a departure another spec sentence requires — from firing the trigger, so every
site carries that phrase; the sites with room also name the second case outright, and
`skills/task/SKILL.md`, at its size warning, relies on the phrase and names the principle in words. Design sentences are untouched, per the
spec's out-of-scope list. The sites, measured with `grep -nE "Arm A|untrue"` over `agents/`, `skills/` and
`docs/`:

- `skills/task/SKILL.md` Step 11, Arm A of the routing AXIOM.
- `docs/workflow.md` § Spec-Amendment group, Arm A.
- `skills/bugfix/SKILL.md`, arm (A) of its Spec Amendment trigger.
- `skills/project-review/SKILL.md`, arm (A) of its Spec/Design Amendment trigger.
- `agents/self-review.md` § Findings that require Design/Spec Amendment, not a code fix, arm (A).
- `agents/fix-scout.md`, the Arm A question in its workflow; a spec sentence that is only broader than
  what shipped, or that another spec sentence overrides, is recorded as `none` in the Arm A cell, which
  the fix-plan gate already accepts as a deliberate answer.
- `docs/scouted-fix-round.md` § Step 11 — review-fix narrative (detail), which restates the question.

`docs/agents-method.md`'s amendment row speaks of a sentence that is false, stale or unsupported, which a
broader spec sentence is not, so it stays as written.

### The plan-convergence reader

`agents/plan-convergence.md` changes in four places.

- **A boundary section after the class table.** The self-contradiction class across the spec/design pair
  applies the principle: breadth and a departure another spec sentence requires are never a
  self-contradiction; a genuine conflict about one object is still one, reported naming both sites
  (AC5). The boundary narrows what counts as a conflict and never whether conflicts are sought.
- **A notes list apart from the findings.** A breadth observation the reader wants to mention goes under
  its own heading in the report. A note is not a finding, does not change the outcome word and does not
  enter the agreement figure (AC4).
- **A planted breadth case beside the planted faults**, read from the same control document on every run.
  It is a negative control: it must not be reported. It is not a class and carries no coverage word. The
  report carries one line saying whether it was flagged and in how many of the three readings; flagged in
  any reading means flagged. A flagged case is a failure of the run, so `clean` additionally requires it
  unflagged and a flagged run is `findings` at minimum, the finding being that the boundary failed. Its
  result is never listed among the pair's findings (AC9).
- **The report template and the "never do" list** gain the breadth-control line and the notes heading, and
  a report without the breadth-control line is incomplete in the same way one without the coverage line
  is. **[REDLINE R2.1]**

`skills/task/reference.md` § Step 7 — the two convergence halves (detail) names what in the reader's
report is part of the result; it gains the breadth-control line beside the agreement figure, the coverage
line and the outcome word, so the orchestrator re-spawns a report that lacks it. Two sentences carry a
count that this fourth item makes false, and both change: that paragraph's opening, "Three figures in its
report are part of the result", is reworded to drop the count, and the Step 7 sentence in
`skills/task/SKILL.md` that links to it, naming "the three figures its report must carry", becomes "what
its report must carry".

### The planted control

`ai-docs/fixtures/plan-convergence-planted.md` gains a section of its own for the breadth case, apart from
the two halves holding the faults and apart from the per-class table, so it shares no object with either
planted fault. Its requirements-half sentence is general: a run that cannot read one of its inputs says
so, and that run is not a pass. Its approach-half sentence is specific about the same behaviour and adds
nothing the first rules out: when the control document cannot be read, the outcome word is `cannot-run`
and the report names the control document as the input it could not read. A short explanation states why
this is breadth and not a contradiction, with a pointer to the principle written as a plain path rather
than a markdown link. The document's opening paragraph is widened to say it holds one planted non-fault
beside the planted faults. The three shapes the document already forbids — a broken link or anchor, a
position inside a file, a bracketed lowercase slug outside a backtick span — stay absent. The fixtures row
in `ai-docs/context.md` that describes this document gains the breadth case. **[REDLINE R1.1]**

### Sync groups

Each group a change fires, and what its other members need:

- **Plan-Invariants** (principle wording, pinned copy, and the protected pages edited here): no member
  restates the principle list; the edit-time refusal's page list is unchanged because no page acquires an
  element-defining locus; both improvement passes decline principle changes in general terms.
- **Spec-Amendment** (recipe and Arm A): every member is edited in this change.
- **Review** (`agents/self-review.md`, `skills/project-review/SKILL.md`): `agents/review-findings.md`
  states no amendment trigger.
- **Scouted-Fix** (`agents/fix-scout.md`, `docs/scouted-fix-round.md`, `docs/workflow.md`): the Arm A
  cell's syntax, the gate's arms and the fix-plan row format are unchanged.
- **Task/Design** (`agents/design-review.md`, `skills/task/SKILL.md`): `agents/design.md` already sends
  a departure to its risks section by practice and the review enforces it; `skills/context-reset/SKILL.md`
  is untouched by routing.
- **Redline** (the recipe in `skills/task/reference.md`): `agents/design.md` § Redline marking already
  sends a changed requirement to the spec and nothing here alters that.
- **Plan-Convergence** (`agents/plan-convergence.md`, `agents/design-review.md`): no other member describes
  the reader's report; the planted control is outside the group by the note under the propagation table.
- **Human-register** (the recipe's surface-to-user step): the plain-terms rule is applied, not changed.
- `docs/claude-tools-hierarchy.md`'s reader row still describes the reader truly and is left alone.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | Append the tenth principle with its reason; reword the paragraph introducing the tests and add the paragraph stating the three-case test in full; add the same sentence to the pinned list; reword the Lifecycle sentence that names the next principle by ordinal and narrow its one-sided clause to a wording change or removal | `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `docs/agent-docs-index.md` | AC8 | — |
| 2 | Design review: the "Spec breadth" checklist item with its three outcomes and the review-defect clause; the GO sentence saying a GO carries no spec-amending note because a genuine conflict is `major` and arrives on ITERATE, deferring to the recipe; the convergence item reading the reader's notes and breadth-control line | `agents/design-review.md` | AC1, AC2, AC3, AC7 | 1 |
| 3 | Recipe: classification by the test, entry from any Step 7 verdict carrying a genuine-conflict row or from a Step 11 Arm A finding, the remedy question for a Step 7 conflict row, the clause that on an ITERATE entry the loop resumes at Step 6 against the amended spec and then Step 7, counted against the cap, the route question's answer being moot before the freeze, the renamed heading; the Step 7 GO bullet's closing clause saying a GO carries no spec-amending note, the Step 7 ITERATE bullet's clause sending a genuine-conflict row to the remedy question before Step 6, and the recipe link with its short label in the skill | `skills/task/reference.md`, `skills/task/SKILL.md` | AC3 | 1, 2 |
| 4 | Subject trigger: the breadth clause on Arm A at every site that states it, spec sentences only | `skills/task/SKILL.md`, `docs/workflow.md`, `skills/bugfix/SKILL.md`, `skills/project-review/SKILL.md`, `agents/self-review.md`, `agents/fix-scout.md`, `docs/scouted-fix-round.md` | AC6 | 1 |
| 5 | Reader: the boundary section, the notes list, the planted breadth case as a negative control with its line and its effect on the outcome word, the report template and never-do list; the Step 7 detail naming the breadth-control line as part of the result, with the count dropped from its paragraph's opening and from the skill's Step 7 sentence that links to it | `agents/plan-convergence.md`, `skills/task/reference.md`, `skills/task/SKILL.md` | AC4, AC5, AC9 | 1 |
| 6 | Control and delivery: the breadth case's own section in the planted control and its opening paragraph; the fixtures row in the profile; the plugin patch version bump | `ai-docs/fixtures/plan-convergence-planted.md`, `ai-docs/context.md`, `.claude-plugin/plugin.json` | AC9 | 5 |

## Handoff plan

- **Before Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` to enter the first group with fresh context.
- **Group A:** subtasks 1–3 — the principle and its pinned copy, design review, and the recipe.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group B with fresh
  context.
- **Group B:** subtasks 4–6 — terminal group (three subtasks, within the allowed range): the subject
  trigger at every site, the reader contract, and the planted control with the version bump.

## Risks

- **Protected pages ask before every edit.** `agents/design-review.md`, `skills/task/SKILL.md` and
  `skills/task/reference.md` are on the edit-time refusal's page list, the protected-page table of
  `docs/plan-invariants.md` mirrored in the shared hook code, which asks on any edit whatever it touches. Each prompt is
  allowed; the list itself does not change.
- **A spurious design element through the review contract.** Route 2 of the element derivation in
  `scripts/check-plan-invariants.py` adds, as a design element, any backticked section-shaped token on a
  line of `agents/design-review.md` that also carries a severity verdict (`SEVERITY` [severity] and
  `ELEMENT_TOKEN` [element-token]). A new line there naming a spec section as a backticked token beside a
  severity would report a design element arriving that the record does not carry. The new checklist lines
  name spec sections in plain words.
- **A false unguarded route through an unprotected page.** The coverage sweep (`defines_element`
  [defines-element] with `PRESENCE_SHAPE` [presence-shape] in `scripts/check-plan-invariants-refusal.py`)
  treats a line carrying a backticked element token and a presence word such as "absent" or "missing" as
  an element-defining locus, and reports any such page outside the refusal set. The edited unprotected
  pages — the reader contract, self-review, the bugfix and project-review skills, the workflow page, the
  scout contract, the scouted-round page and the docs index — refer to the risks section and the spec's
  lists in plain words, never as backticked section tokens.
- **Two files sit at the size early warning.** `skills/task/SKILL.md` measures 34,859 bytes and
  `docs/workflow.md` 34,981 (both by `wc -c` on this branch today) against the 35,000-character early
  warning the method's size AXIOM hands down, leaving 141 and 19 bytes of headroom (each the warning minus
  the measurement). The skill gains two clauses: the ITERATE clause and the Arm A clause, the latter
  unlinked and naming the base principles in words. Four cuts offset them: the GO-bullet clause's
  shorter wording, the recipe link's label shortened from the full heading to the section name, the
  anchor's "step-7-go-with-notes-resolution" replaced by "a-step-7-verdict", and the Step 7 sentence's "the three figures
  its report must carry" shortened to "what its report must carry". An estimate by `wc -c` on candidate
  wordings of all six puts the additions above the cuts by less than the skill's headroom, so the skill
  stays under the warning; should the final wording outrun that headroom, the skill crosses the warning,
  a `minor` finding. The warning counts characters and `wc -c` counts bytes; a multi-byte character
  counts once in the first and more than once in the second, so a byte figure never understates the
  character figure and the headroom stated here errs safe. In the workflow page the clause cannot fit in its headroom alone, so the same section's
  restatement of the recipe's spawn sequence is tightened by the clause's length without changing what it
  says. Crossing the warning is a `minor` finding, not a gate.
- **The recipe's target arm keeps its wording.** Scope item 3, read literally, has the recipe fire only
  on a conflict the test admits, while the out-of-scope list keeps the target arm — a fix that actually
  edits a spec routes through the recipe — unchanged. Leaving the target arm alone is the second case of
  this design's own test: the out-of-scope sentence requires it. A fix that edits a spec still enters the
  recipe mechanically; the test governs which findings become such a fix, at design review and at Arm A.
  The route question after an amendment is likewise out of scope and keeps its wording; on an ITERATE
  entry its answer is moot, because before the GO freeze neither a frozen base nor a redline log exists,
  so its "No" branch is scoped to post-freeze entries.
- **A one-sided addition stays quiet.** Leg 1 walks the pinned list only, so a principle added to the page
  without a pinned copy is not reported. AC8 asks for alteration and removal to be reported, and both are;
  the addition direction is the existing behaviour for every principle and this change does not alter it.
  Both halves land in one subtask.
- **The reader's own stability on the negative control.** The reader is a model and may flag the breadth
  case in some readings. Any reading flagging it marks the run flagged, and the count of readings is
  printed, so an unstable boundary shows as a measurement rather than averaging away.
- **Classification is a judgement.** Whether a departure is required by another spec sentence is the
  reviewer's call, and a wrong call either requests an unneeded amendment or misses a conflict. The
  principle hands the reviewer a single question and the AC2 remedy keeps the departure's record in one
  place, so a wrong call is visible in the design's risks rather than silent.

## Use cases

- `docs/plan-invariants.md` — the tenth principle is read by design review, the convergence reader and
  every Arm A site through their links when classifying a spec sentence against a narrower design or
  implementation; its explanatory paragraph is where a reader finds the three cases and the remedy rule;
  the plan-invariants verification reads the numbered sentence and compares it with the pinned copy.
- `scripts/check-plan-invariants.py` — its pinned list makes a reworded or removed tenth principle a
  reported wording difference or absence on every structural check run, and its count of present
  principles includes the new one.
- `agents/design-review.md` — used by the design reviewer at Step 7 to raise nothing on breadth, a `minor`
  design-side issue for an unstated departure, and a `major` conflict with both remedies; used to tell the
  reviewer that a GO carries no spec-amending note, leaving the route to the recipe.
- `skills/task/reference.md` — used by the orchestrator at Step 7 close to classify notes and conflict
  rows by the test, to ask the user which remedy a conflict takes, to return to Step 6 and then Step 7
  after an amendment entered from an ITERATE, and to require the breadth-control line in the reader's
  report.
- `skills/task/SKILL.md` — used by the orchestrator at Step 7 to proceed from a GO with no spec-amending
  note to route, to send a genuine-conflict row on an ITERATE to the recipe's remedy question, and to know
  what the reader's report must carry; and at Step 11 to leave Arm A unfired by a spec sentence that is
  merely broader than what shipped.
- `agents/self-review.md` — used by the implementation-time reviewer to flag arm (A) only for a spec
  sentence in genuine conflict with what shipped, in the task, bugfix and whole-branch flows.
- `agents/fix-scout.md` — used by the scout to write `none` in the Arm A cell for a breadth-only spec
  sentence.
- `agents/plan-convergence.md` — used by the reader at Step 7 to keep breadth out of self-contradiction,
  list breadth observations as notes, still report a genuine conflict naming both sites, and print whether
  the planted breadth case was flagged.
- `ai-docs/fixtures/plan-convergence-planted.md` — read by the reader on every run as the negative control
  it must not report, beside the two planted faults it must report.

## Open questions

- None.
