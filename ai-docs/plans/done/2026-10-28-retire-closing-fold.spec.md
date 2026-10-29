# Retire the closing fold: correct the design in place, archive the plan as written

**Source:** ticket GH-173
**Date:** 2026-10-28
**Tracked in:** GH-173

## Scope

**Today.** A task's design is frozen when design review approves it. After that, a place where the shipped
work departs from the design without breaking the agreed approach is not corrected in the design: an
in-place marker is appended to the diverged item and a row is written to a committed correction log beside
the plan. Once the pull request is approved, a closing pass — the fold — applies the log's rows to the
design, collapses the spec to its record of deliberate absence (out of scope, deferred, key decisions),
removes the log, and lands as a commit. The post-merge cleanup refuses to run while a log is still on the
branch. This cheap path exists in the task's own rounds alone: a fix round on the task's open pull request,
a bug fix and a whole-project review route every divergence they find the full way — stop, ask the user,
amend the design, review it again.

**What is wrong with it** (facts as the ticket states them; the measurements behind them are in the comments
of GH-165):

- Approval and merge are usually one act, so almost every fold landed as its own pull request after the
  merge, with its own review and merge on top of the fold's own cost.
- Between the merge and the fold, the archived design says one thing and the log beside it another.
- The fold changes the spec's shape, so every reader and check of the archive has to know two shapes.
- A marker is written before the work it describes, so it is often false one commit later.

**What this task delivers.**

1. **Nothing runs after the merge.** The spec and design move to the completed-plans archive in the task's
   own pull request, as they stand, and nothing rewrites them afterwards on that task's behalf.
2. **A divergence is corrected in the design in place**, in the same round as the code it describes and
   after that code exists — in the task's implementation, in its review-and-fix rounds, and in the fix
   rounds that follow once its pull request is open. There are no in-place markers, no correction log and
   no fold. One rule of the retired marker contract is kept and becomes a rule of the design itself: a
   correction is admitted only when it is needed to make the shipped thing correct; work that would widen
   what the task delivers is a new ticket.
3. **The freeze is a commit.** When design review approves the plan, the spec and design are committed in
   a commit whose message carries a trailer naming the plan. "What changed since approval" is the
   difference between the plan as it stands and its latest freeze. The trailer survives a rebase of the
   branch; nothing about the freeze is kept in an uncommitted local file.
4. **A divergence that breaks the agreed approach keeps today's route**: stop, ask the user, amend the
   design, review it again — and the newly approved plan is committed as a new freeze.
5. **Review reads the computed change, not the author's account.** The reviewer of each round is given the
   design's changes since the latest freeze, computed from the repository, as an input of its own, and
   judges each change: does it break the approach or not. Long model edits are reported to corrupt a
   sizeable share of a document silently (research cited in the ticket); a computed change shows every
   edit, the unintended ones included.
6. **The pull-request description links that change in one line**, only when the design changed after the
   freeze.
7. **Fix rounds stay as cheap as today.** A correction that keeps the approach does not send the next review
   round back to a full re-examination. Today that is achieved by stripping markers before the plan's
   fingerprint is taken, which is imperfect: in GH-110 a marker on a line of its own left a line holding a
   single space after stripping, the fingerprint moved, and a non-breaking correction triggered a full
   re-review. The fingerprint is instead taken over the frozen plan.
8. **The retired mechanism goes everywhere it lives**: the closing-fold workflow, the marker contract, the
   fold-related checks, the post-merge refusal, the correction-log disposition of a round's fix plan, and
   the sync group that ties the correction-log files together for the edit-time reminder. The base
   principles of a spec and a design that describe the retired mechanism are rewritten so each is true of
   the new flow.

**Terms used below.** *Freeze* — the commit recording the plan as approved. *Plan* — the task's spec and
design. *Breaks the agreed approach* — the test the workflow already uses to route a divergence to a
design amendment rather than to an ordinary fix. *Full re-examination* — a review round that re-checks every
item of its checklist instead of carrying the ones whose inputs did not change. *Follow-up round* — a fix
round run on the task's open pull request for a reviewer comment or a failing check, after the task's own
rounds have ended. *Full route* — stop, ask the user, amend the plan, review it again.

## Out of scope

- **The bug-fix workflow and the whole-project review, run on their own.** A divergence either of them
  finds keeps routing the full way, as today, whether or not it breaks the approach; neither is given the
  computed change, and neither rules on one. The only difference they see is that the re-read following a
  spec amendment that keeps the approach always corrects a falsified design item directly, because no plan
  carries a correction log any more. The workflow documents made extending the cheap path to them
  conditional on evidence from a measured run; that condition stays in force for these two. A bug fix run
  inside the task is not this case — see § Key decisions.
- **Migrating archived plans.** Plans already in the archive keep whichever shape they have — full, or
  collapsed by a fold — and are not rewritten.
- **A plan going stale when a later task changes what it describes** — the second half of GH-133. It stays
  with GH-165, the lasting record of current behaviour. This task keeps per-task plans as history, and the
  existing route by which later work amends an archived plan it makes untrue is unchanged (see § Key
  decisions).
- **Splitting the design for its human reader** — GH-174, after this one.
- **What the plan checks detect.** The check that compares spec and design for convergence and the check of
  declared links between them keep their meaning; they keep reading the per-task spec, which stays.
- **The rule on what a criterion may contain**, and the check that enforces it. It is not part of the fold,
  and it stays.
- **The one rewrite allowed between approval and implementation** — working the approval's notes into the
  design before the implementation starts. It stays; the freeze is taken after it (see § Key decisions).

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| Recording, on the first task that runs under the new flow, how many correcting rounds triggered a full re-examination, against what the marker-stripping fingerprint gave | The ticket names it as how the effect is shown; it can only be taken on a task run after this change ships | No — recorded on GH-173 when that run happens |

## Key decisions

| Question | Decision |
|---|---|
| Who writes a design correction | The design author, in place, as it writes the design today; never the orchestrator. One writer per artefact. (Ticket; first base principle.) |
| When a correction is written | In the same round as the code it describes, after that code is written — never ahead of it. (Ticket.) |
| The once-per-task correction-mode question (exploratory versus mixed) | Retired with the marker contract that defines it. The ticket removes that contract and keeps exactly one of its rules — a correction is admitted only when needed to make the shipped thing correct, which was the mixed mode's discipline — as a rule of the design for every task. A non-breaking divergence therefore no longer stops implementation to ask the user anything; a breaking one does. (Derived from the ticket.) |
| When the freeze is taken | When design review approves, once any notes the approval carried have been worked into the design and before implementation begins, so the change since the freeze holds only what was changed after implementation started. (Ticket for the event; the ordering against the notes is a default taken here.) |
| What the freeze commit holds and how it is found | The spec and the design, in a commit whose message carries a trailer naming the plan; the latest such commit for that plan is the freeze. Whether the declared-link record rides in it is the design's choice. (Ticket.) |
| The freeze and commit consent | The freeze is a commit like any other and is subject to the repository's existing consent rule for commits. Implementation does not begin on a plan with no freeze, because every later step that reads "what changed since approval" needs one. (Default taken here.) |
| What the review is given | The design's changes since the latest freeze, computed from the repository, as an input separate from the author's hand-back and from the design itself. Each change is ruled on: breaks the approach, keeps it and describes what shipped, or describes nothing the shipped work needed — an unintended edit, or work beyond the task. (Ticket; the third outcome follows from the kept admission rule and from the ticket's reason for a computed change.) |
| Review breadth after a requirement change | Unchanged from today: an approved change to the spec after the freeze still sends the next review round to a full re-examination, as an amendment does today. The ticket asks fix rounds to stay as cheap as today, not cheaper at the cost of breadth after the requirements moved. Whether that is achieved by the amendment committing a new freeze or otherwise is the design's choice. (Default taken here.) |
| The declared-link record at the end of the task | Archived with the plan or deleted at the closing step — the design's choice (the ticket hands it there). Either way it is settled in the task's own pull request and nothing touches it after the merge. |
| Readers of archived plans | Keep reading both shapes, full and collapsed, as the archive listing already does. New plans reach the archive in the full shape only. (Ticket.) |
| The base principles that change | The principle that the design is frozen at approval, the one on where a changed requirement and a changed artefact are recorded, and the one on the closing fold change; so does the reason given for the principle that a spec broader than its design is not a contradiction. Each is rewritten, or removed, so that it and its reason are true of the new flow, and its protected copy changes in the same commit. Wording is the design's. (Ticket.) |
| Later work that makes a sentence of an archived plan untrue | Today's route is unchanged: the later work — a later task's fix, a bug fix, a whole-project review — still amends the archived plan, with the user's approval, inside its own pull request, so the archived sentence stays true. The ticket's "nothing rewrites them later" retires only the task's own post-merge pass. (Owner's answer.) |
| Follow-up rounds on the task's open pull request | Take the same in-place correction as the task's own rounds: the design author corrects the archived design in place, and the round's review is given and rules on the computed change since the latest freeze. The only reason they were excluded — the marker, the log and the fold existed in the task's own rounds alone — is gone, and the owner settled the evidence condition the workflow documents had placed on extending the cheap path to them. (Owner's answer.) |
| A bug fix run inside the task — a detour during its implementation or its review-and-fix rounds, or the real-defect fix a follow-up round hands to the bug-fix workflow | Part of the round it runs in, so it takes that round's in-place correction, and the round's review rules on the correction through the computed change. A real defect raised on the open pull request is fixed by exactly such a nested bug fix, so excluding it would leave the owner's answer for follow-up rounds covering lint and build fixes alone; during implementation the ticket's in-place correction covers the task's own divergences. A bug fix run on its own keeps today's route (§ Out of scope). (Derived from the ticket and the owner's answer.) |
| Order of the work | Decoupling what the surviving checks share with the retired fold first, behaviour unchanged, then removing — the design's to settle, as the ticket says. |

## Technical constraints

- **Instruction budget.** Every instruction file loaded whole at agent start stays below the 35,000-character
  early warning the method's size rule sets (a threshold handed down by the method). The project context
  file has almost no headroom below it today, so its section describing the correction log is removed, not
  replaced at equal length. The task workflow file and the self-review contract do not grow in net — a
  threshold the ticket hands down.
- **Method and profile stay apart.** Everything this task adds to the method works in every consuming
  project: it relies on nothing beyond the version control every consuming project already uses and names
  no project-specific prefix.
- **A principle and its protected copy change together**, and the mechanism that catches a principle
  changed on one side only keeps working.
- **The full check list runs clean**, with no check's input set silently narrowed to get there. A check
  whose only subject was the retired mechanism is removed from the list deliberately, with that mechanism;
  it is never left in place unrun.
- **A computed change that could not be computed is not an empty change.** A missing freeze, or a failure to
  compute the change, is reported as such and never read as "the design is unchanged".
- **Release.** The change touches plugin-loaded content, so the plugin's version is bumped in the same pull
  request (project convention).

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | After a task's pull request merges, no further commit lands on the default branch for that task: no workflow step is owed for its plan, and the post-merge cleanup completes without refusing, deferring or reminding anyone about the task's plan documents. |
| AC2 | A task's spec and design reach the completed-plans archive inside the task's own pull request, and the move changes nothing in their content: no section is removed, nothing is collapsed, and no step run on that task's behalf rewrites either document after its merge. |
| AC3 | When the task's implementation, one of its review-and-fix rounds, a follow-up round on its open pull request, or a bug fix run inside any of these finds that what shipped departs from the frozen design without breaking the agreed approach, the design is corrected in place in that same round, after the code it describes is written; no marker is added, no correction log is written, and neither a new design review nor a question to the user follows. |
| AC4 | A correction describing work that is not needed to make the shipped work correct is not admitted into the design; work that would widen what the task delivers is proposed as a separate ticket instead. |
| AC5 | When design review approves a plan, the spec and design as approved — with the approval's notes worked in — are committed as that plan's freeze before implementation begins, in a commit that identifies the plan; implementation does not begin while the plan has no freeze. |
| AC6 | The changes to a plan since approval are computed from the repository against that plan's latest freeze. The result is the same after the task branch is rebased, depends on no uncommitted local file, ignores freezes of other plans on the same branch, and counts moving the plan into the archive as no change. |
| AC7 | When a divergence breaks the agreed approach, work stops and the user is asked; on approval the design is amended and reviewed again, and the newly approved plan becomes that plan's latest freeze, so no later review round of the task rules again on a change already approved. |
| AC8 | Every review round of the task, follow-up rounds included, is given the design's changes since the latest freeze, computed from the repository rather than taken from the author's account, and rules on each change: one that breaks the agreed approach takes the stop-and-ask route; one that keeps it and describes what shipped is accepted without a finding; one that describes nothing the shipped work needed — an unintended edit included — is a finding. |
| AC9 | When the design is unchanged since the latest freeze, the review is told so; when no freeze can be found or the change cannot be computed, the review says so and does not treat the design as unchanged. |
| AC10 | Each time the task's pull-request description is written, on the first pass and after every follow-up round, it carries exactly one line linking to the design's changes since the latest freeze when the design changed after it, and no such line when it did not. |
| AC11 | A review round that follows a correction keeping the approach re-examines only what it would have re-examined had the plan not changed; a new freeze, or an approved change to the requirements after the freeze, sends the next round to a full re-examination, as an amendment does today. |
| AC12 | No shipped instruction, reminder, workflow or check directs any party to write a correction marker, keep a correction log, run a closing fold, or refuse or defer anything because one is owed; the closing-fold workflow is no longer offered, and a round's fix plan no longer offers a correction-log disposition. |
| AC13 | Each base principle of a spec and a design, with its stated reason, is true of the new flow: none prescribes a marker, a correction log or a closing pass, and none rests its reason on a fold or a collapsed spec. A principle changed on its page alone, or on its protected copy alone, is still caught. |
| AC14 | Plans archived before this change keep their shape and are not migrated, and every reader of the archive reads both the collapsed and the full shape as it does today. |
| AC15 | When later work makes a sentence of an archived plan untrue, that work still stops and amends the archived plan with the user's approval, inside its own pull request, as it does today. |
| AC16 | Every instruction file loaded whole at agent start stays below the early-warning size, and the task workflow file and the self-review contract are no larger than before the change. |

## Open questions

- None.
