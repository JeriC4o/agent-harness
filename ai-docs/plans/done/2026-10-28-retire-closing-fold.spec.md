# Retire the closing fold: correct the design in place, archive the plan as written

**Source:** ticket GH-173
**Date:** 2026-10-28
**Tracked in:** GH-173

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

