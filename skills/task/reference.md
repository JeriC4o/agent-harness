# /task — Reference

Reference material extracted from `SKILL.md`. SKILL body owns the workflow steps; this file owns reference / troubleshooting / detail material. Loaded on demand.

## ⚡ First — validation sequence (detail)

The ⚡ First preamble's glob `ls ai-docs/plans/*.progress.md` is a flat match — it ignores branch and merge state. Two failure modes:

1. **Stale-merge.** Matched progress file's task already merged through the GitHub UI, bypassing `/pr-merged` (the gitignored `.progress.md` survived). RESUME-ing would point at a completed task.
2. **Wrong-branch parallel PR.** Matched progress file belongs to an unrelated in-flight PR on a different feature branch. RESUME-ing cross-contaminates flows.

**Validation sequence (run before the RESUME jump):**

1. Read `**Branch:**` and `**base_commit:**` from the matched `.progress.md`.
2. **Stale-merge check.** `git merge-base --is-ancestor <base_commit> origin/main` — exit 0 means that base is already an ancestor of the default branch (the work merged). Stale candidate. **A record with no `**base_commit:**` never reached implementation** and is checked against the plan's freeze instead, when `${CLAUDE_PLUGIN_ROOT}/scripts/plan-freeze.sh find <design>` names one. Only `find`'s no-freeze reason — no commit reachable from the head carries the plan's freeze trailer — reads as no freeze: nothing of the task can have merged, and only the branch is matched. Any other could-not-compute is a STOP put to the user. So a record created at the design step passes validation, and the delete option, offered only on a mismatch, never reaches its working plan.
3. **Branch-match check.** Compare the progress file's `**Branch:**` against `git branch --show-current`. If they differ, the user is on a different branch from the progress file's owner. Wrong-branch candidate.
4. If **either** check signals a mismatch, surface to user with three options and wait — do NOT jump to RESUME:
   - **delete** — `rm ai-docs/plans/<base>.progress.md`, then proceed with the new task.
   - **park** — `mv ai-docs/plans/<base>.progress.md ai-docs/plans/<base>.progress.md.parked`; the `.parked` suffix takes it out of the glob.
   - **RESUME anyway** — user explicitly chooses to ignore the mismatch (rare).
5. If both checks pass (base_commit NOT yet merged AND branch matches), proceed to RESUME flow.

**RESUME flow — only after validation passes.** A record with no `**base_commit:**` resumes from the step it records, validated backwards: [§ Re-entry before implementation](#re-entry-before-implementation). A record carrying one has reached implementation and skips Steps 1–7:

1. Read the `.progress.md` file.
2. Read spec — only `## Acceptance Criteria`.
3. Read only the files `git diff --name-only <base_commit>` names — version control holds that set, and no hand-maintained copy of it exists in this file.
4. Jump to `## Next action` — on a new-shape record, at the first subtask of the working plan with no `## Completed subtasks` line. A new-shape design whose record has no working plan returns to Step 6.
5. Tell user: "Found active task [X], resuming from [subtask Y]".

## Re-entry before implementation

**The recorded step.** Before implementation `**current_step:**` names the last step marked done, and a step is marked done only after its outputs are written, so the record never runs ahead of its data. A boundary there rewrites `**current_step:**` alone.

| Step marked done | `**current_step:**` | Its outputs, written first | The task goes on to |
|---|---|---|---|
| none yet | `Step 6 — record created` | — | the design step |
| design | `Step 6 — design written` | the design; on the new shape the working plan | design review |
| design review, round N, ITERATE | `Step 7 — round N ITERATE` | the verdict's issues, verbatim, under `## Design-review issues (Round N)` | the design step, which revises against them |
| design review, round N, GO | `Step 7 — round N GO` | the verdict's notes, as that approval's table in `## Design-review notes` | the design author working the notes in |
| notes worked in | `Step 7 — notes worked in` | the last column of every row of that table, filled as the orchestrator finds each note in the design or the working plan; a note it cannot find goes back to the design author first | the confirmation question; on the earlier shape the freeze |
| freeze | `Step 7 — plan frozen` | the freeze commit, and its push where the question asked for one | the answer, asking nothing about a commit; on the earlier shape implementation |
| confirmation | `Step 7 — confirmation answered` | `**confirmation:**` `yes` with the freeze's id, or `no` with its reason in the decisions log | on `yes` implementation, which writes `**base_commit:**`; on `no` the design step, the reason carried to the design author |

**Validated backwards.** Read the record end to end first. Then check the recorded step — it finished, and its outputs are present and intact — and on a failure the step before it, and so on back to the first step that passes; resume right after that step, and at the design step when none passes. The artefacts never carry the resume point past the step after the recorded one: they only refuse a resume point whose preconditions they do not show. A step passes only while the earlier outputs it depends on still hold:

- every step after the design step needs the design and, on the new shape, the working plan — so a missing working plan fails every step back to the design step;
- a freeze, and a `yes`, pass only while `plan-freeze.sh diff` shows the plan unchanged since that freeze, and a `yes` only while it names the freeze `plan-freeze.sh find` names;
- a `no` needs only its reason in the decisions log, because the redesign it starts changes the design.

Where the step that passed is not the recorded one, tell the user which output was missing. A step whose outputs landed before a crash left it unmarked runs again over them: the fold-in finds each note already worked in, and the question finds the plan unchanged since a freeze and asks only for the push the freeze may lack, where one is asked, and for the answer. A record with no `**base_commit:**` naming none of these values was written under the earlier rules, by Step 7 for its notes, and is read as recording the approval.

## ⚡ Second — bare-ticket activation sequence (full)

Activation sequence (bare-ticket → matching deferred spec):

1. Parse `$ARGUMENTS` — confirm it matches a ticket key (`^[A-Z][A-Z0-9]+-\d+$`).
2. Load the ticket if the project has a tracker reachable from this session (`gh issue view <N> --json title,body,state` for a GitHub issue). If none is reachable, the key is a reference only — carry it and continue.
3. Grep deferred specs:
   ```bash
   grep -l "^\*\*Tracked in:\*\* <KEY>\b" ai-docs/plans/deferred/*.spec.md
   ```
   Zero matches → fall through to Steps 1–5 (interview-driven flow). The ticket description loaded in step 2 is interview context.
   One match → continue with step 4.
   Multiple matches → surface to user.
4. Move the matched spec (and `*.design.md` / `*.progress.md` siblings if present) from `ai-docs/plans/deferred/` to `ai-docs/plans/`:
   ```bash
   git mv ai-docs/plans/deferred/YYYY-MM-DD-name.spec.md ai-docs/plans/
   git mv ai-docs/plans/deferred/YYYY-MM-DD-name.design.md ai-docs/plans/    # if exists
   mv ai-docs/plans/deferred/YYYY-MM-DD-name.progress.md ai-docs/plans/      # if exists; gitignored so plain mv
   ```
5. Surface spec's existing `## Acceptance Criteria` to user verbatim, ask: *"Confirm these ACs, or revise before continuing?"* — wait. Any revisions applied to the spec file before Step 6 launches.
6. **Do NOT run the interview.** **Do NOT create an `*.state.md` interview state file.** **Do NOT re-resolve the tracking ticket** — the spec's `**Tracked in:** <KEY>` is authoritative.
7. If a `.progress.md` came along (rare): take the RESUME flow above.
8. Otherwise jump directly to **Step 6**.

## Design Amendment recipe (re-entrant — triggered from Step 8 or Step 11)

**From Step 11 it fires on a divergence that BREAKS the agreed approach; from Step 8 when a group's divergence breaks it and the user approves the rebuild** — nothing restarts on its own account there.

1. **Stop** the current step. Do not silently continue with the deviated approach.
2. **Surface to user** — say what the system will now do differently and why, in the product's own terms, answerable without opening a file: **no** design-document or spec citation, **no** acceptance-criterion or decomposition-task id; restate the constraint inline ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)). Wait for approval.
3. **Spawn the `design` subagent to apply the amendment** — do NOT edit `*.design.md` inline. Per AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`":
   ```
   Agent(subagent_type="general-purpose", prompt="
     Read ${CLAUDE_PLUGIN_ROOT}/agents/design.md and follow it.
     Existing design: ai-docs/plans/YYYY-MM-DD-name.design.md
     Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
     Context: amendment requested during implementation / self-review. Specifically: <describe the change>.
     Update the design doc to incorporate the amendment.
   ")
   ```
4. Re-run design review (max 3 rounds total across all design-review runs). **Its GO would take a freeze that absorbs every correction made in place since the previous one**, so first run `${CLAUDE_PLUGIN_ROOT}/scripts/plan-freeze.sh diff <design>` as its own call, output to a file, and hand that file to the review as an input of its own beside the sections the amendment changed — it rules on every hunk outside them ([`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § The plan freeze](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#the-plan-freeze)):
   ```
   Agent(subagent_type="general-purpose", prompt="
     Read ${CLAUDE_PLUGIN_ROOT}/agents/design-review.md and follow it.
     Design: ai-docs/plans/YYYY-MM-DD-name.design.md
     Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
     Context: design was amended during implementation / self-review — describe what changed.
     Sections the amendment changed: <their headings>.
     Change since the previous freeze: <the file holding the diff output>.
     Progress: ai-docs/plans/YYYY-MM-DD-name.progress.md
   ")
   ```
5. **On GO** → the new freeze — on a new-shape design asked as the confirmation question ([§ Step 7 — the confirmation question](#step-7--the-confirmation-question)), whose "yes" names the new freeze — then resume from the step that triggered the amendment. **The new freeze is what makes the next self-review round sweep every checklist item:** it moves the frozen half of the plan digest that round's ledger is compared against ([`${CLAUDE_PLUGIN_ROOT}/docs/converging-review.md` § Triggers](${CLAUDE_PLUGIN_ROOT}/docs/converging-review.md#triggers)).
6. **On ITERATE** → re-spawn the `design` subagent with the iteration feedback and re-run review (counts against the 3-round limit). Never edit the design doc inline to "fix the blockers".
7. **On STOP** → surface to user; do not proceed.

> Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — having it corrected in place — FORBIDDEN.
> Editing `*.design.md` inline instead of spawning the `design` subagent — FORBIDDEN. The orchestrator's role is (1) surface to user, (2) spawn `design`, (3) spawn `design-review`. The `Write` to `*.design.md` belongs to the `design` subagent regardless of how trivial the amendment looks.

## Spec Amendment recipe (re-entrant — triggered from a Step 7 verdict)

Entered from any Step 7 verdict carrying a genuine-conflict row, from a Step 11 finding that fires Arm A, from the three callers outside `/task` that send a spec amendment here — the fix step of `/bugfix`, the fix loop of `/project-review` and a post-push fix round — and from a declared-link report naming a possible spec amendment, in a design author's hand-back or in step 4's own run. That last entry takes step 3's remedy question as a genuine-conflict row does, the design complying first: the design complying returns to the design author's pass that raised it, as an ordinary iteration does, and the requirement changing continues to step 4; whichever the user picks, the design author's pass that follows rewrites the row ([`${CLAUDE_PLUGIN_ROOT}/docs/declared-links.md` § Where a report leads](${CLAUDE_PLUGIN_ROOT}/docs/declared-links.md#where-a-report-leads)). A GO carries no spec-amending note: a genuine conflict is `major`, so at Step 7 it arrives on an ITERATE.

1. **Classify each note and row** at Step 7 close by [the tenth base principle](${CLAUDE_PLUGIN_ROOT}/docs/plan-invariants.md#the-base-principles): **breadth** — the spec general or silent where the design is specific — is neither kind and is dropped; **design-internal** (route through `design` subagent for in-place fold-in; no loop) includes a departure another spec sentence requires, which the design states among its risks; **spec-amending** is a genuine conflict only.
2. **Stop before Step 8.** Do not begin implementation against the pre-amendment spec — FORBIDDEN.
3. **Surface to user via `AskUserQuestion`** — state the requirement change itself in plain product terms (what is expected of the system now, versus before), not as a spec edit: **no** spec or design citation, **no** acceptance-criterion id ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)). Wait for explicit approval — **for a Step 7 genuine-conflict row the question is instead which remedy the user wants**, in the same plain terms, the design complying first: the design complying returns to Step 6 as an ordinary ITERATE does and leaves this recipe; the requirement changing continues to step 4.
4. **On user approval — re-invoke the `spec-writer` subagent to apply the amendment** — do NOT `Edit` `*.spec.md` inline. Per AGENTS.md AXIOM "the orchestrator NEVER writes to `*.spec.md` / `*.design.md`":
   - **Pass the amendment in the spawn prompt, as a `prior_qa` entry or as `extra_context`. There is no interview state file to update** — it is the orchestrator's bookkeeping for the multi-round interview loop, it is deleted at that skill's terminal exit, and on the deferred-spec activation route (⚡ Second step 6) creating one is forbidden outright. A late amendment is a single invocation with no loop, and `spec-writer` never reads that file anyway: it reads `AGENTS.md`, the ticket body and the current draft from paths in its prompt, and takes the history as a prompt field — its own contract names `prior_qa` **or** `extra_context` as the channel for exactly this kind of re-invocation.
   - Spawn `spec-writer` with that prompt. The spec-writer owns the `Write` to `*.spec.md`.
   - **Once it has applied the amendment, and whenever a design exists, run `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-links.sh <spec> <design>`** — the orchestrator's own call, in whichever workflow entered this recipe, read as a report that stops nothing. Its report is carried into the design author's next pass on the pair; a moved link whose unchanged end is in the spec — a link between two spec statements, one of which the amendment changed, among them — is a possible spec amendment and takes step 3's remedy question.
5. **Ask the one question that decides the rest: does the amendment change the AGREED APPROACH?**
   - **Yes** — scope, intent or the approach itself moved. Re-enter Step 6 (`design`) stating that the spec was amended, then Step 7 against the new pair (counts against the 3-round cap); its GO takes a new freeze, the review first ruling on the change since the previous one as the Design Amendment recipe's step 4 hands it, and on a new-shape design the confirmation question is asked again; then proceed.
   - **No** — a criterion restated, an over-promise withdrawn, a wording clarified. **No design re-derivation, no design-review round and no freeze**: a changed requirement is not a divergence. The amended pair is re-read instead, by six acts in order, in whichever workflow entered this recipe:
     1. **The spec writer applies the amendment and names what it amended** — each statement it changed, added or removed, by the heading it sits under and its words as they now stand, a removed one by its heading and the words it had, in the `amended` field of its final status block ([`${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` § Output contract](${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md#output-contract)). Step 4's declared-link run follows.
     2. **The amended pair is re-read before work resumes**: `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-convergence.sh <spec> <design>` as its own call, and the `plan-convergence` reader spawned as Step 7 spawns it ([§ Step 7 — the two convergence halves (detail)](#step-7--the-two-convergence-halves-detail)), so the reader is never the only check standing. Its prompt names two sets of design statements to read first, both drawn by the orchestrator: the design end of every declared link whose spec-end quote falls inside a statement the `amended` field names, even when the quote is intact — read off the link record and that field; and every design end of a link step 4's run reported `moved`. They narrow nothing: the whole pair is still read.
     3. **Rule on every finding before anything is written, and route each by the side that is wrong.** The re-read reads the whole pair, so it also carries contradictions the amendment did not cause, among them ones an earlier round ruled harmless:
        - **a false design statement goes to the fifth act** — one the amendment made false, whether a reader finding against it, a holding finding of the deterministic check the amendment caused, such as a criterion it added that no decomposition row of an earlier-shape design delivers, or a moved link ruled false below; on a new-shape design, while a group is still to run, every criterion the amendment added or changed, because no check reads the working plan after the freeze; or a genuine design-side contradiction the re-read finds that predates the amendment;
        - **a wrong spec statement goes to a further spec amendment**, with the user's approval, which re-enters this route;
        - **a wrong artefact outside the pair is fixed as ordinary work** in the step the amendment interrupted — a subtask in Step 8, a fix row in a review-and-fix round, the fix step of `/bugfix`, the fix loop of `/project-review`, a post-push fix commit;
        - **a finding judged harmless**, whatever its origin, is recorded and nothing more, except that the fifth act rewrites the declared-link row of a harmless moved link;
        - **a moved link whose unchanged end is in the design is ruled from its two quotes**, with the reader's finding on that end as one input and the reader's silence as none — a model that raised nothing does not clear a deterministic report. The changed spec quote and the unchanged design quote are read side by side: a design end the change made false joins the first set, and one that still holds is ruled harmless, its row rewritten in the fifth act. A moved link whose unchanged end is in the spec takes the second set's question.
     4. **Wrong spec statements go first.** Each is put to the user through step 3, batched and led by a default. An approved one is applied by the spec writer and the route restarts at its first act over the new pair, with nothing written before it; a refused one leaves the spec as it stands, and its finding is ruled again between the other three sets.
     5. **One pass of the `design` subagent**, spawned once when the first set holds an item or step 4's run left a non-silent row, and given those inputs only. **It corrects each false item directly**, places each criterion named to it in a subtask of the working plan or names the subtask already delivering it, and lists each with its subtask in its hand-back, in the same change as the amendment, by the in-place correction ([`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Correcting the design in place](${CLAUDE_PLUGIN_ROOT}/agents/design.md#correcting-the-design-in-place)), reworking only the items named and ending with the design author's own exit checks. No design-review round follows: the workflow's own self-review pass reads the correction with the rest of the change before it is committed — Step 10 of `/task`, Step 6.5 of `/bugfix`, Step 5 of `/project-review`, the review step of the post-push round.
        - **It rewrites every non-silent row of the declared-link record**: a row whose design end it corrected gets grounds naming the corrected item, and a row whose design end still holds gets fresh grounds saying so.
     6. **Every finding judged harmless goes into the `## Decisions log` of the working record of the workflow that entered the route, with its reason, and nowhere else** — the one act beside it being the fifth act's rewrite of a harmless moved link's declared-link row. That record is the task's progress file, which a post-push round shares, the bug-fix trace, or the project review's progress file: one bullet each, prefixed with the step or round the amendment interrupted. Each is gitignored and deleted when its workflow closes, which is why a genuine defect never goes there alone: it would be lost. No finding of this route is carried into the pull-request description.

   - **Either branch, once self-review has run, makes the next round sweep every checklist item** — the amended spec moves the live half of the plan digest, and the Yes branch's new freeze the frozen half too.

   **On an ITERATE entry the verdict's own loop resumes, whatever step 5 answers.** Once the spec is amended, re-enter Step 6 against it — the `design` subagent revises the design for the verdict's other rows and for the amended requirement — then Step 7, counting against the 3-round cap; the "No" branch leaves no GO, and Step 8 needs one. Before the GO there is no freeze to re-derive against, so step 5's answer is moot here, and the Step 6 → Step 7 return is the ITERATE loop itself, which the question never governed.

> Editing `*.spec.md` inline instead of re-invoking `spec-writer` — FORBIDDEN. The orchestrator's role is (1) carry the amendment into the spawn prompt, (2) re-spawn `spec-writer`, (3) answer step 5's question and take only the branch it names, then, on an ITERATE entry, resume the verdict's loop.
**Review DEPTH for an amendment — a preference, not a route.** The route is decided upstream by whether
the divergence breaks the agreed approach; this governs only how hard the resulting review looks.
**Default to** keeping the full review loop for an amendment that changes a VERIFICATION GATE rather than
prose — the gate is what every later claim of correctness rests on, so a silently-broken check is worse
than no check. Request that reviewer behaviour explicitly in the spawn prompt: extract the check block
verbatim from the file, run it against self-built conforming AND violating fixtures, and try to falsify
each "this is structural / guaranteed" sentence rather than reading it.

> **Answering step 5 by reflex, in either direction, is the failure** — why, and the measurement behind it: [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § When a spec amendment re-derives the design](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#when-a-spec-amendment-re-derives-the-design).

## Steps 1–5 — spec creation delegation (detail)

`/task` does not duplicate the interview workflow. Scope extraction, key-decision confirmation, tracking-ticket resolution and spec writing are owned by `/interview`.

**Already have a spec?** If a saved spec exists under `ai-docs/plans/`, confirm with the user and **skip to Step 6**.

**Otherwise, run the interview**:

```
Skill(skill="interview", args="$ARGUMENTS")
```

The interview handles entry-mode detection, scope confirmation, clarifying-question rounds (max 4, max 3 questions per round), ticket resolution, and spec writing.

**Spec-only run.** If the user wants to stop after the interview, `git mv` the spec to `ai-docs/plans/deferred/`, and **do not proceed to Step 6**.

**Before Step 6:** confirm spec exists at `ai-docs/plans/YYYY-MM-DD-name.spec.md` and user has approved its `## Acceptance Criteria`.

## Step 7 — the two convergence halves (detail)

The step produces BOTH results before the review spawn, and the review reads both. The ordering is
the obligation: a judgement class may never be the only check standing, and nothing in either
contract asks for that — it is satisfied by the deterministic check running in the same step.

**The deterministic half** is `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-convergence.sh <spec> <design>`,
its own bare call. Six classes, two of which HOLD a plan — completeness, arithmetic — and four of
which only report. Read the per-class roster and the counts beside the verdict rather
than the exit status: a class reporting zero over a document with content examined nothing, and a
plan whose findings are all excused exits 0 while saying so in those terms. A cannot-run is not a
pass. The author's own exit check already ran this before handing back
([`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Rules](${CLAUDE_PLUGIN_ROOT}/agents/design.md#rules)),
so a holding finding arriving here means the plan changed after that check or the check was skipped
— either is worth saying out loud rather than re-running quietly.

**The judgement half** is the `plan-convergence` reader. Its output is a report and never a verdict,
so there is nothing here to route on: the findings travel into the review, which rules on them.

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/plan-convergence.md and follow it.
  Spec: ai-docs/plans/YYYY-MM-DD-name.spec.md
  Design: ai-docs/plans/YYYY-MM-DD-name.design.md
")
```

**These parts of its report are the result and not decoration.** The agreement across its
three readings, with the healthy figure it states before the first; the coverage line, naming each
of its two classes covered or uncovered against the planted faults it reads on every run; the
breadth-control line, saying whether the planted spec-broader-than-design case was flagged and in how
many readings, a flagged case keeping the outcome off `clean`; and the outcome word, where
`cannot-run` is not a pass. A report arriving without them is incomplete —
re-spawn it rather than reading the finding list alone, because a finding list with no agreement
figure cannot be told from a stable one.

**Neither half is a verdict and neither blocks by itself.** What blocks is the reviewer's own rule
([`${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` § Rules](${CLAUDE_PLUGIN_ROOT}/agents/design-review.md#rules)):
GO is unavailable while an unexcused holding finding stands. Granting an excuse is the design
author's act and leaves a checkable record; it is not the reviewer's and not the orchestrator's.

## Step 7 — the confirmation question

On a new-shape design, once design review approves, the design author has worked the notes in and the
orchestrator has found each of them in the design or the working plan, the orchestrator asks **one
question**, once per approval that takes a freeze. In plain words it says that the agreed plan will be
committed as the approved plan and pushed to the branch, gives the link to the design there, states the
design's measured length beside the cap, and says what each answer does: "yes" confirms the approach, at
that length, and lets implementation start; "no", with a reason, sends the approach back to be redesigned.
An earlier-shape design gets no question: its freeze is surfaced once as a commit, as before.

- **The length** is the length line from the design author's last exit check, which ends every write of
  the design, or, when that hand-back is not at hand, from a run of
  `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-convergence.sh` over the design as it stands. It is stated
  whether or not the design is over the cap, and over the cap nothing more is asked: the "yes" accepts it.
- **The link** is built from the `File link form` row of the project's `AGENTS.md` § VCS, with the branch
  as the ref: the question is asked before the commit exists, and the branch's head is the freeze from
  the push until the answer, because nothing is committed in between. Where the row says `none`, or the
  profile has no such row, the question names the design's path instead, for reading where the project's
  own viewer renders it.
- **The push** is asked whenever the repository has a remote, whatever the row says; only the link needs
  a link form. With no remote the question asks to commit and confirm.
- **The usual reply consents to the commit and the push first** and gives the answer after reading the
  design — on the review surface, which a human can do only after the push, or where the project's own
  viewer renders it when there is none. Act on the commit and the push, mark the freeze done, and await
  the answer without a second question.
- **The "yes"** is written as `**confirmation:**` `yes <freeze commit id>`. A new freeze — after a design
  amendment, or a spec amendment that changed the approach — names a different commit, so the question is
  asked again; a correction in place takes no freeze and asks nothing, and the working plan is outside
  every freeze, so changing it asks nothing either.
- **A "no"** is written as `**confirmation:**` `no`, its reason in the decisions log, and goes to the
  design author as the reason the approach was refused: Step 6, Step 7 and a new question. The freeze it
  follows stays in the branch's history; a "no" given before any consent to the commit commits nothing. It
  does not count against design review's round cap: the cap stops two agents circling, and the human ruling
  is not that.

## Step 8 — progress-file creation template (detail)

The record is created at Step 6's first action when none exists, using the canonical format at [`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md), with every header field but `**base_commit:**`: `**Branch:**`, `**Last build:**`, `**current_step:**`, `**last_passed_gate:**` as `(none yet)`, `**entry_args:**`, `## Decisions log`, and for `/task` also `**Issue:**` / `**Spec:**` / `**Design:**`. Step 8 writes `**base_commit:**` either way, and creates the whole record only for a task begun before Step 6 created one:

```
**Branch:** <TICKET-KEY>-<slug>
**base_commit:** <git rev-parse HEAD, taken after the plan's confirmed freeze>
**current_step:** Step 8 — Implementation start
**last_passed_gate:** %BUILD_CMD% <module-path> | <ISO-8601 UTC timestamp> | <git rev-parse HEAD> | <tree digest from the gate record's line, or measured>
**entry_args:** <original $ARGUMENTS — a ticket key, "activate <slug>", free text, or (none)>
```

The `**entry_args:**` field is recorded ONCE, when the record is created, and **read-only thereafter**. On lost-arguments re-entry (empty `$ARGUMENTS` after compaction), this is the canonical entry reference.

## Step 8 — first-action GO-notes verification (detail)

Verify both spec and design (with GO verdict) exist AND that **every note / minor / recommendation of the last approval's table in `## Design-review notes` was worked into the design or the working plan** — the orchestrator filled each row's last column as it found the note there before the freeze, so on such a task this finds every row filled, and a blank is a note to send back to the design author before anything else. "Applied in code later" ≠ "resolved in the plan". On a new-shape design `**confirmation:**` must be `yes` naming the freeze `plan-freeze.sh find` names; any other value is the confirmation step not yet done. Missing spec, missing design, missing GO verdict, OR unresolved GO-notes = previous steps incomplete.

## Step 8 — transport-drop backoff

**On a transport-level drop (socket closed / connection closed mid-response), resume the SAME agent from its transcript (`SendMessage`) — it preserves already-gathered context.** First resume after a single drop may be immediate; from the 2nd consecutive failure on the same step, `sleep` 2s→4s→8s→16s→32s (cap 32s, small jitter) before re-dispatching; cap ~5 attempts per step, then surface to the user — never a silent loop. Reset the delay after any success.

## Step 9 — verify list (full)

1. `%BUILD_CMD% <module-path>` — PASS.
1b. **Run the gate over DEPENDENTS when the change alters a published interface, or what a component requires of its collaborators.** A module-scoped gate cannot see either class, and both break a file the diff never touched. An altered **published interface** can invalidate a call site that itself did not change — including a test double built against the old shape, and most sharply where the new form is ambiguous with an existing one at the CALL site rather than at the definition; prefer avoiding that ambiguity at the source (a distinct name beats an optional form that collides) over compiling every dependent to find it. A change to **what a component requires of its collaborators** fails where the component is ASSEMBLED rather than where it is named, so a module that never mentions the new requirement still breaks at wiring time. Find the dependents by searching the test sources for the **CHANGED** name — not the new one, which no dependent uses yet — and run each hit's module through the gate.
2. The touched-scope checks — the selection stated in one line, then run with `%TEST_CMD%` in its narrowing form per [`${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md`](${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md); never the full list, which Step 12 runs once — all green, read per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Reading a test result`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result). A zero-selected run reports success; prove selection before trusting a filtered pass.
3. `%FORMAT_CMD%` on every changed source file to format, THEN `%LINT_CMD%` as the gate — must exit clean. The formatter is not the gate.
4. For shell (`.sh`) files: `shellcheck <file>` — the analogue of the lint gate. Honor existing per-file `# shellcheck disable=...` directives; do not add new blanket disables. Surface it as an explicit AC at spec/design time, not only as a workflow gate.
5. For each AC — confirm covered by test or manual verification.
6. Show a `| # | Criterion | Test / Verification | Status |` summary table.
7. On ALL PASS → proceed to Step 9.5.

## Step 9.5 — documentation update (detail)

Update content files only — do NOT move spec/design to `done/` yet (Step 12):

1. **`ai-docs/context.md`** — resolve open questions answered during impl; update Plans list; add new architectural decisions.

## Every-group handoff (rationale)

During Step 8 the orchestrator NEVER executes subtask code in its own context. Every group fans out through `/context-reset` — including the first group, and including M = 1 designs. Re-state the rule to yourself before deciding the next action: *"Did I just receive a group return? Then the next action is to spawn the next group's `/context-reset` handoff, until the working plan's groups — an earlier-shape design's handoff plan — are exhausted. No exceptions for 'one more quick subtask in this turn' or 'the first group is small enough to do inline'."*

**Failure modes this prevents.** Long-lived orchestrator sessions hit auto-compaction mid-task; the compaction summary does not reproduce the strict step sequence faithfully and Step 10 (self-review) gets silently omitted, or runtime handoff triggers fire against a degraded context. The every-group fan-out removes the failure mode structurally: the orchestrator's own context never grows long enough to trip compaction.

## Step 8 — local FAIL investigation before push

When the test gate returns FAILED, identify the specific failing test and reproduce it in isolation (`%TEST_CMD%` filtered to that one test) before deciding the failure was transient. A subsequent green run is NOT proof of transience — different test isolation, parallel test ordering, or dirty test fixtures can flip results. Only accept "transient" when the test is on a known-flaky list AND multiple reruns are consistently green.

## Step 11 — the scouted-plan sequence

Moved to [`${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md`](${CLAUDE_PLUGIN_ROOT}/docs/scouted-fix-round.md)
— the spawn prompts for all five beats, the plan format, the reason-token table, the post-apply
micro-loop and the narrative behind each beat. The heading stays here so inbound references to it keep
resolving, and because the gate list below reads this page's own section names at run time.

## Step 12 — full run, digest compare, failure route

**Why only two `current_step` values pass the step-skip gate.** Both admissible values mean the review question is settled: one by a verdict, one by the user overriding it in writing. A compaction landing between Step 11's write and its return is exactly how the inadmissible state reaches this gate, so read the value rather than inferring the step from how far the work looks done.

**The single full run** is item 6 of Step 12: after the plan files move to `done/` and the build passes, `%FULL_CHECK_CMD%` runs once, its output redirected to a file. Its passing record goes into `**last_passed_gate:**` with the tree digest from the gate record's line — or measured with `${CLAUDE_PLUGIN_ROOT}/scripts/tree-digest.sh` straight after the run and marked as measured, when the full command is outside the gate vocabulary. Immediately before surfacing the commit, the field's digest is compared with a fresh `tree-digest.sh`; a difference owes the run again. The rule and its edge cases: [`${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md`](${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md).

**On a failing full run:**

1. **Move the plan files back** out of `done/` — spec, design, and the record of excused findings and the record of declared links if either moved — so routing, exclusions and review prompts see the paths they key on.
2. **Write progress:** rewrite `**current_step:**` to `Step 12 — full run failed (Round N)`; rewrite `## Next action`.
3. **Spawn the Step 10 reviewer** with the failing output's file named. It records one `major` finding per failing check. Every checklist row whose scope is unchanged carries, so the round is narrow.
4. **Continue as an ordinary round** — Step 11 fixes, Step 10 reviews — and return to Step 12, which runs the full list again. The commit is surfaced only after a passing full run that followed the last approval.

## Step 12 — PR-body template (detail)

Claude prepares the title + body per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR title + body shape`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-title--body-shape); the user approves before `gh pr create` opens the PR, and before `gh pr edit` rewrites the description in place when one is already open:

- **Title:** `<TICKET-KEY>: <conventional-commits header>` when the project uses ticket keys; a bare conventional-commits header otherwise.
- **Body:** to the shape that section states, which this template does not restate. **Name no ticket key other than the PR's own** — in a tracker-integrated repo a key in the description creates a remote link and can transition that ticket's status, and neither is undone by editing the text afterwards.
- **Pass the body via `--body-file`** whenever it contains backticks, apostrophes, or a construct a `PreToolUse(Bash)` hook matches — see [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Hook false-positive guard`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#hook-false-positive-guard--body-content-matching-any-pretooluse-bash-regex).

## Patterns

Validated approaches `/task` should keep applying (carrot signals; soft verbs). **Each is stated in full elsewhere and this is a pointer list, not a second statement** — it was not: three rules lived only here until they were moved to the page that carries their siblings, which is the shape this list exists to avoid.

- **Default to** resuming the SAME agent from its transcript (`SendMessage`) on a transport-level drop, with exponential backoff from the 2nd consecutive failure, rather than cold-spawning a replacement that discards its gathered context. Full rule: [§ Step 8 — transport-drop backoff](#step-8--transport-drop-backoff); re-stated for the design phase in [SKILL.md § Design Amendment](SKILL.md#design-amendment-re-entrant--triggered-from-step-8-or-step-11).
- **Writing and receiving a spawn prompt** — mark every factual claim with how it was obtained, treat a restated rule as a reminder rather than enforcement, read an instruction that contradicts itself as evidence rather than as a command, and read a relayed finding for which artefact it actually points at. All four, with the measurements behind them: [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication) and § Tooling.

## FORBIDDEN

- Declaring done with uncovered ACs.
- Skipping design review.
- Writing code before the spec is confirmed.
- `rm`ing `.progress.md` from within `/task` (it's gitignored and lives until `/pr-merged`).
- Staging `.progress.md` into a commit.
- Pushing from the default branch.
- Deviating from the design without either triggering Design Amendment or — for a divergence that does not break the agreed approach — having it corrected in place.

## Gate checklist

| Before | Check |
|---|---|
| Steps 1–5 | Spec saved? `**Tracked in:** <KEY>` present (or `none` with reason)? ACs confirmed by user and verifiable? |
| Step 6 | Spec exists? ACs confirmed? Not a "spec-only / defer" run? Progress record created when none existed, or left standing? |
| Step 8 | Design doc with GO? Plan frozen — `plan-freeze.sh find` names a freeze? Groups for every M ≥ 1 — the working plan's, or an earlier-shape design's handoff plan? **Every row of the last GO's notes table filled?** New shape: `**confirmation:**` `yes` naming that freeze? |
| Step 8 start | Feature branch checked out? `git branch --show-current` is NOT the default branch? `base_commit` + `branch` recorded in progress file? |
| Each subtask | Build ✅? Touched-scope checks run, selection stated? `.progress.md` updated, its completion line written? Group handoff via `/context-reset`? |
| Step 9 | Build + tests + lint clean? `## Criterion checks (Round N)` filled, `Shown non-empty by` included? (**No design-side verification line is asked for — a design says nothing about tests**, so the round record is where a criterion meets a check.) |
| Step 9.5 | context.md updated? (spec/design NOT moved yet) |
| Step 10 | Self-review APPROVE? (Progress file persists in the working tree — gitignored — until `/pr-merged`.) |
| Step 11 | `major`/`blocker` objections confirmed by user? Breaking divergence → Amendment, non-breaking → `correction:` row, corrected in place after the micro-loop? |
| Step 12 | Branch ≠ default? spec/design moved to done/? Build clean? Full list passed once, digest unchanged before surfacing? PR title prefixed? Ticket read, and the description written to the shape — the problem, why, where to look, no test details, counts or Summary/Test-plan sections? |

## Commit authorisation + hooks

Per AGENTS.md, `git commit` / `git push` / `gh pr create` are ASK-level for Claude. `/task` Step 12 prepares the staged file list + commit message, asks for confirmation, then runs the commit. Hook behaviour:

- **`auto-stage-learnings`** — auto-stages `ai-docs/learnings.md` and the `ai-docs/learnings/` directory (`git add ai-docs/learnings`) when either has unstaged or untracked changes at `git commit`. The directory form is what covers a per-branch entry file on its **first** write, when it is still untracked.
- **`archive-protection-reminder`** — advisory `Edit|Write` nudge when a write ADDS a `### ` header to `ai-docs/learnings.md`: new entries belong in `ai-docs/learnings/<username>-<branch>.md`. Exits 0, never blocks — the `/improve` fold and `Escalated?` / `Superseded by:` field edits pass untouched.
- **`branch-protection`** — blocks `git commit` / `git push` on the default branch as a safety net, and prints the recovery recipe. **A LONE `git push origin --delete <other-branch>` is exempt** — it sends nothing to the default branch — while a deletion naming the default branch, or one carrying a shell metacharacter, is still blocked: [`${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`](${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md).
- **`co-authored-by`** — blocks a `Co-Authored-By` trailer in a commit message (${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Workflow overrides the harness default here).
