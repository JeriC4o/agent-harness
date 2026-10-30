# Split the design into the human's review document and the agents' working plan

**Source:** ticket GH-174
**Date:** 2026-10-30
**Tracked in:** GH-174

## Scope

**Today.** One design document serves two readers. The human reviews the approach in it; the agents
implement from it. Most of its text is the agents' working detail — the decomposition into subtasks, the
order of the implementation groups and the handoff between them, and the places each subtask edits — and
the same subtasks are written a second time as a checklist in the task's local progress record. Archived
designs run from 15,039 to 268,149 characters (measured by character count over the 17 designs in the
completed-plans archive on this branch), a length at which a human cannot review an approach, and
architectural review happens on the design, not on the spec. A paper test reported in the ticket fit one
archived design's approach, key decisions, rejected alternatives, a diagram and risks into 4,730
characters, losing no key decision and no rejected alternative.

**What this task delivers.**

1. **The design becomes the human reviewer's document.** It holds the approach, the key decisions with the
   alternatives each rejected, a diagram of the approach, the risks, and a short summary of what the change
   touches. The summary is the use cases — one entry per object the task builds, saying what it is for —
   and, beside them, two things only judgement can supply: a second definition the change introduces of
   something that already has one, and work already in flight that the change breaks. It holds nothing
   derived from the implementation's changes, because it is read before any exist. It is committed and
   travels with the pull request, as today.
2. **A soft length cap on the design's text,** with the diagram's own notation not counted. A design under
   the new rules that runs over it is neither refused nor handed back for its length: the confirmation
   question shows the human its measured length beside the cap, and the human's "yes" accepts it. A
   correction in place after the freeze stays in the item it falsifies even when it takes the design over
   the cap; the human sees the over-cap length, and no new confirmation is asked for it. The archive and the
   designs of tasks begun under the old rules are exempt.
3. **The working plan moves into the local progress record.** Decomposition, group order, handoff and edit
   sites live there, are never committed, frozen or archived, and the decomposition is the task's one
   subtask list. The design author writes it and corrects it; nobody else does. The progress record exists
   from the design step on, and a task is resumed from the step it records rather than from the record's
   existence.
4. **The human confirms the approach with one word on every task,** after design review approves and
   before implementation, having read the frozen design through a link.
5. **The pull-request description links the design** instead of restating it, and adds only what happened
   during implementation.
6. **The base principles and the method's statement of who each document is for change with the flow,**
   each in the same change as its protected copy.
7. **Tasks already in flight finish under the rules they started under.**

**Terms.** *Plan* — a task's spec and design together; the word keeps that meaning. *Working plan* — the
executor's local plan: decomposition, group order, handoff and edit sites. *Progress record* — the task's
local, uncommitted record of its state. *Design author* — the party that writes the design today.
*Freeze* — the commit recording the plan as approved. *Confirmation* — the human's one-word answer on the
approach. *New rules* / *old rules* — the flow after and before this change ships.

## Out of scope

- **The task card and its approval at the end of the interview** — GH-165. That task turns the spec into a
  card holding the task-scoped obligations, adds the first of the two approvals (the card, before the
  design), and adds its own pull-request lines for changed principles. This task adds only the second
  approval, the confirmation after design review.
- **Committing the working plan,** in the design or beside it. It has no reader outside the local executor,
  and a task is executed by one executor; losing it on another machine is accepted.
- **A list of what else the change touches derived from the diff.** It cannot be known when the design is
  written, and the human reads no diff at that point.
- **Use cases in the spec.** The spec is written before the design, does not know the objects the task
  builds, and may not name internal names.
- **A size threshold deciding which tasks get the confirmation.** Everything that reaches a design has
  already passed the one-line and specified-chore routes, and a threshold's inputs would be written by the
  author whose plan it gates.
- **A new mechanism for a "no".** A "no" means the approach broke, which already ends in a new design,
  review and freeze.
- **Migrating archived plans.** They keep the shape they have, decomposition and handoff included.
- **The line in the pull-request description linking the design's changes since approval.** It exists; it
  is not added again.
- **Reviewing the code diff on the review surface before the pull request is approved** — unchanged.
- **Readers that take only the use cases from the design** — the archive listing, the completeness reading
  of use cases, and the whole-repository review's design conformance. Use cases stay in the design, so
  their input is unchanged.
- **The spec, its form rule, and the interview** — unchanged.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| Nothing | — | — |

## Key decisions

| Question | Decision |
|---|---|
| Where use cases live | In the design, one entry per object the task builds. (Owner, 2026-10-30.) |
| Correction after the freeze | Stays in place, as GH-173 made it: a divergence that keeps the approach is corrected in the design item it falsifies. (Owner, 2026-10-30.) |
| Where the working plan lives and who writes it | In the local progress record, written and corrected only by the design author; the orchestrator writes neither the design nor the working plan, and the rest of the progress record keeps its present writers. (Owner, 2026-10-27 and 2026-10-30.) |
| Marking a subtask done | Not a write to the working plan. The orchestrator records progress outside the working plan's text; where, and how resumption reads it, is the design's choice. (Default taken here: one writer for the working plan, and the decomposition and the subtask list are one section.) |
| Every acceptance criterion delivered by some subtask | Kept from today's design rules. With the subtasks in the working plan, design review is where it is judged; whether anything else also checks it is the design's choice, under the rule on what a refusing check may read. (Default taken here.) |
| The confirmation | On every task that reaches a design, after design review approves and the freeze is taken, before implementation. Committing the freeze, pushing it and confirming are asked as one question, because a terminal shows a diagram's source rather than a picture and the human reads the design on the review surface. The "yes" is recorded in the progress record beside the freeze. (Owner.) |
| A "no" | Carries the human's reason to the design author and takes the existing new-design, review and freeze route. Whether it counts against design review's round cap is the design's choice. (Owner.) |
| The length cap | 5,000 characters — a threshold the ticket hands down, fixed only after the paper test below — held as a soft limit. A design under the new rules over the cap is neither refused nor handed back for its length; its measured length and the cap are shown in the confirmation question, and the human's "yes" accepts it. A correction in place after the freeze stays in the design item it falsifies even when it takes the design over the cap: the over-cap length is shown to the human, at a place the design chooses, and asks for no new confirmation; the correction shortens no item the divergence did not falsify, and a correction that keeps the approach never becomes a new design for its length. The diagram is not counted; it is recognised by the diagram form the project's profile names, because a method file may not name a diagram language. Prose put inside a diagram's labels is counted; the use cases are counted. (Owner; the soft limit, owner 2026-10-30.) |
| The paper test before the cap is fixed | A reviewer's version of the smallest archived design (15,039 characters) and of the largest (268,149) — both measured by character count on this branch — is written with the summary included and measured. The median archived design (68,463, same measurement) is the one the ticket already tested. If either does not fit, the revised figure is put to the owner with both measurements before the change ships. (Ticket for the test; putting the revision to the owner is a default taken here.) |
| A diagram on every design | Every design under the new rules carries one. (Read from the ticket's list of what the design holds.) |
| Register of the design | Written for its human reader: a criterion, file or symbol may be named, but never in place of saying what it is or does. (Default taken here, following from the design becoming the human's document and the method's rule for text addressed to a human.) |
| How a design begun under the new rules is told from one begun under the old | The design's choice, provided no design of a task already in flight is measured against the length cap or refused for its shape. (Default taken here.) |
| Who creates the progress record at the design step | The design's choice, provided the record names the task's branch from creation, because the post-merge cleanup finds the record by that field. (Ticket for the field.) |
| What each check reads once the working plan leaves the design | The design's choice, under one rule: a check that can refuse the design author's hand-back reads only documents that travel with the pull request, and a plan with no working plan is a normal state. (Ticket.) |
| Whether the working plan's sections join the record of required elements as a third document | The design's choice. (Ticket.) |
| Link and diagram form for a project with no remote | The design's choice; both are profile facts. (Ticket.) |
| A task resumed on another machine | Has no working plan, and returns to the design step for a new design, review, freeze and confirmation. (Owner, following from the rejection of a committed working plan.) |

## Technical constraints

- **Instruction budget.** Every instruction file loaded whole at agent start stays below the method's
  35,000-character early warning (a threshold the method hands down). The task workflow file, the
  self-review contract and the method file stand at 33,073, 33,114 and 33,712 characters (measured by
  character count on this branch), and the ticket hands down that the change does not add to them: each is
  no larger in net after it.
- **Method and profile stay apart.** No method file names a diagram language or a review surface's link
  form; both are read from the project's profile, and the method still works in a consuming project.
- **A principle and its protected copy change together**, the record of required elements and every page
  that makes an element required agree after the change, and the mechanism that catches a one-sided change
  to either keeps working.
- **A could-not-run is not a pass.** An absent working plan never turns a check of the plan into a
  could-not-run, and no check reads a could-not-run as agreement.
- **The full check list runs clean** with no check's input set silently narrowed to get there.
- **Release.** The change touches plugin-loaded content, so the plugin's version is bumped in the same pull
  request (project convention).

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | A design written under the new rules holds the approach, the key decisions each with the alternatives it rejected, a diagram of the approach, the risks, the use cases — one entry per object the task builds, saying what it is for — and any second definition the change introduces of something already defined and any work in flight that the change breaks; it holds no decomposition, group order, handoff or edit sites, and nothing whose content could only come from the implementation's changes. |
| AC2 | Every statement of such a design can be understood by a human reader without opening another file: a criterion, file or symbol is never named in place of saying what it is or does. |
| AC3 | When a design written under the new rules exceeds the length cap — the diagram's notation excluded, prose inside its labels and the use cases included — it is neither refused nor handed back to its author for its length: the confirmation question shows the human its measured length beside the cap, and the human's "yes" accepts the design at that length. |
| AC4 | When a correction in place after the freeze takes the design over the length cap, the correction stays in the design item it falsifies, the design's measured length and the cap are shown to the human, and no new confirmation is asked for it; no item the divergence did not falsify is shortened, and a correction that keeps the approach is not turned into a new design because of its length. |
| AC5 | The length cap ships only after a reviewer's version of the smallest and of the largest archived design, summary included, has been written and measured within it; when either does not fit, the revised cap is put to the owner with both measurements before the change ships. |
| AC6 | An archived design, and the design of a task begun before the change shipped, is never measured against the length cap or refused for holding its decomposition and handoff, and every reader of a design accepts both the old shape and the new one. |
| AC7 | A task's working plan — its decomposition, group order, handoff and edit sites — is kept in its local progress record and is never committed, frozen or archived; the decomposition is the task's only subtask list, so no subtask is written in two places. |
| AC8 | Only the design author writes the working plan, when the design is written and when it is corrected after the freeze; no other party edits it, marking a subtask done included, and the progress record's other contents keep their present writers. |
| AC9 | From the moment the design step writes the working plan, the progress record exists and names the task's branch, so the post-merge cleanup finds and removes it. |
| AC10 | A task re-entered after its design step but before implementation began resumes at the step it had reached: design review, the freeze and the confirmation are not skipped, and having been created before implementation does not make the progress record fail the re-entry checks or put its working plan up for deletion. |
| AC11 | Design review examines the working plan together with the design, and a plan whose working plan is missing, or in which some acceptance criterion is delivered by no subtask, is not approved. |
| AC12 | Apart from design review, a check of the plan that can refuse the design author's hand-back gives the same verdict whether or not a working plan is present; a plan read after its merge, or on a machine without its working plan, is checked as a normal state and is never reported as could-not-run for that absence. |
| AC13 | After design review approves and the freeze is taken, the human is asked one question covering committing the freeze, pushing it and confirming the approach, with a link to the design as frozen; implementation does not start until the human's "yes" is recorded beside that freeze. |
| AC14 | The confirmation is asked on every task that reaches a design, with no size threshold, and again after every new freeze taken because the approach changed; a correction in place that keeps the approach, and any change to the working plan, asks for none. |
| AC15 | A "no" carries the human's reason to the design author, and the task takes the existing route of a new design, design review and freeze, followed by a new confirmation. |
| AC16 | A correction to the working plan changes neither the freeze nor the pull-request description's line linking the design's changes since approval. |
| AC17 | Each time the pull-request description is written, it links the design rather than restating its approach or decisions, adds only what happened during implementation, and carries the line linking the design's changes since approval at most once. |
| AC18 | A task planned under the new rules and re-entered where its working plan is absent returns to the design step and is planned again — new design, design review, freeze and confirmation — and is never implemented from the design alone. |
| AC19 | Each base principle of a spec and a design is true of the new flow: one writer per artefact covers the working plan; the principle on archiving no longer speaks of a design's process sections and states that the working plan is not archived; the principle bounding what a design says about tests is unchanged; and "plan" still means the spec and the design. A principle changed on its page alone, or on its protected copy alone, is still caught. |
| AC20 | The record of a design's required elements no longer carries the decomposition or the handoff, and it agrees, in both directions, with every page that makes an element of a design required. |
| AC21 | The method states that the design is written for the human who reviews the approach, and that the confirmation is answered by reading the design through the link the question carries; every other question to a human stays answerable without opening a file. |
| AC22 | Every instruction file loaded whole at agent start stays below the early-warning size, and the task workflow file, the self-review contract and the method file are each no larger than before the change. |

## Open questions

- None.
