# Commit each workflow step as a write transaction, and drop the ask before a commit

**Source:** ticket GH-180
**Date:** 2026-11-03
**Tracked in:** GH-180

## Scope

**Today.** The method asks the user before every commit. Each workflow that commits stops at its end,
shows a list of files to stage and a suggested message, and waits for the user to authorise the commit or
make it. Inside the task workflow the plan is committed once, at its approval, and that commit is asked
inside the confirmation question; implementation records the commit that closed each subtask, yet each of
those commits is also subject to the ask. So most of what a task writes sits uncommitted between its
approval and its end. Since GH-174 a task re-entered before implementation resumes from the step its
progress record names, validated backwards to the first step whose outputs are present and intact — but
an interruption can leave a step's outputs half-written and uncommitted, and nothing in version control
then tells a finished step from a broken one. Separately, the check that recognises a leftover progress
record of an already-merged task asks whether the task's commits are in the default branch's history. A
squash merge puts none of them there, so under squash that check would resume a merged task.

**What this task delivers.**

1. **The ask before a commit goes, everywhere.** A commit on a task's branch is made without asking, in
   every workflow, both in the method's written rules and in the permission prompt the host raises. The
   guards on a commit stay: none on the default branch, and no attribution trailer unless the user asks.
   Pushing and opening a pull request are still asked.
2. **Each step of the task workflow commits what it wrote, as a write transaction.** A step that changes a
   shared file commits that change before it is marked done; a step that writes only the local record is
   marked done only after its outputs are written there. The other committing workflows keep their present
   commit points, now made without asking.
3. **Resumption reads the commits.** A step whose commit exists has finished. A step whose outputs exist
   only uncommitted is checked, and committed when they hold or redone when they do not.
4. **Both merge styles are supported, through a project setting, default squash.** Each project declares
   how a human merges its pull requests — squash, or keep every commit — and every harness behaviour that
   runs after a merge gives the right answer under either.
5. **Every statement of the old ask is swept** from the shipped instructions, the scaffolded project
   files and the user-facing description of the workflow.

**Terms.** *Step* — one step of the task workflow as its progress record names it: the requirements'
approval at the end of the interview, each write of the design, each plan-review verdict, the review's
notes worked in, the freeze, the confirmation, each implementation subtask, each in-place correction of
the design, the documentation update, each code-review verdict and each review-fix round, and the closing
step. *Shared file* — a file kept in version control that travels with the pull request. *Local record* —
the progress record and the interview's state, which are never committed. *Freeze* — the commit marking
the plan as approved at a plan-review approval. *Confirmation question* — the one question asked after the
freeze, before implementation. *Review surface* — the hosting site where a pull request is reviewed and
merged. *Merge style* — how a human merges a task's pull request: *squash* combines the branch's commits
into one new commit on the default branch, so none of the branch's own commits reaches it; *keep every
commit* joins the branch with a merge commit, so every step commit reaches the default branch. *Leftover
record* — a progress record found when a task workflow starts, which may belong to a task already merged.

## Out of scope

- **Pushing and opening a pull request.** Both stay asked: they are visible outside the machine, and the
  owner's statement covered only the commit.
- **Merging.** Still a human's act on the review surface. The merge-style setting records how that human
  merges; the harness neither merges nor changes how the review surface merges.
- **How the review surface composes a squash commit's message.**
- **The post-merge cleanup.** Unchanged: it already confirms the merge on the review surface rather than
  from history, and leaves a refused deletion of a squash-merged branch to the user.
- **The guards on a commit** — the refusal on the default branch and the refusal of an attribution
  trailer. Unchanged.
- **Committing the local record or the working plan.** Both stay local; for them the transaction is the
  order of writes.
- **A commit per step in the other workflows** — bug fixing, the whole-branch review, a fix round on an
  open pull request, the instruction audit and improvement. They keep their present commit points and
  resume rules.
- **Rewriting an already-scaffolded project's files.** Scaffolding never overwrites an existing file; such
  a project loses the written ask with this change, the host's own prompt stays until its settings allow
  the commit, and with no merge style declared it is treated as squash.
- **What a commit message carries** — the ticket-key title and the freeze's marker. Unchanged.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| Nothing yet | — | — |

## Key decisions

| Question | Decision |
|---|---|
| The ask before a commit | Removed in every workflow: a commit on a task's branch is made without asking, and no question asks for consent to one. (Owner, 2026-10-30.) |
| Push and opening a pull request | Still asked. (Owner's standing practice since 2026-10-30; ticket.) |
| The host's permission prompt | Removed too, in this repository's and the scaffolded project's permission settings: committing, and staging the files named, run without a prompt; staging every change at once still prompts. A written rule alone leaves the host prompting before every commit, which the owner's statement rules out — "I see no point in a permission for a commit" — and which a commit per step would multiply. (Default taken here, following from the owner's statement; surfaced to the owner, who raised no objection.) |
| Which workflows commit per step | The task workflow only, its interview included. The others keep their present commit points, now made without asking, and their present resume rules. (Default taken here: the owner, asked, did not answer; the default was announced to the owner, who may override it at the requirements' approval.) |
| The unit of commit during implementation | The subtask: each subtask's work is committed when it closes, so every group's work is committed. The progress record already names, for each closed subtask, the commit that closed it. (Default taken here; the ticket names the group, and a commit per subtask satisfies it.) |
| A step's transaction | A shared file: written, committed, then the step marked done. The local record: written, then the step marked done. (Ticket.) |
| The freeze | Stays one marked commit at each plan-review approval; the commits of the rounds before it are ordinary and never read as a freeze. A freeze is taken even when the plan's text has not changed since the last round's commit, because an approval with no freeze would block implementation. (Ticket for the first sentence; default taken here for the second.) |
| The confirmation question | Asks to push the freeze and to confirm the approach — with no remote, only to confirm — and nothing about a commit; the freeze is committed before it is asked. (Ticket, Related section.) |
| Resumption | A committed step has finished; an uncommitted one is checked, committed when its outputs hold and redone when they do not. (Owner, 2026-10-30; ticket.) |
| A task in flight when this ships | Resumed by the same rule: outputs the old rules left uncommitted are checked and committed when they hold, so no task is sent back for a commit it was never required to make. (Default taken here.) |
| Build before a commit | Owed only by a commit that changes what the project's build reads; a commit carrying only the plan's documents does not wait on a build. (Default taken here; the difference is cost only.) |
| When the full check list runs | Unchanged: once, after the last review approval, before the closing commit and the push that follows it. The step commits made inside the loop precede it. (Default taken here.) |
| How the step commits reach the default branch | Both merge styles are supported, through a setting each project declares: squash, or keep every commit. The default is squash: a scaffolded project declares it, and a project declaring nothing, or a value the method does not recognise, is treated as squash — the reading that is correct under both styles while the review surface answers. Under squash the step history lives on the branch and in the pull request only. (Owner: "support both, default squash"; the treatment of an unrecognised value is a default taken here.) |
| This repository's own merge style | Squash. (Default taken here, from the owner's words that the detailed step history is not needed in the default branch. This repository has merged by merge commit so far — measured: the latest merges on the default branch, pull request 181 among them, are merge commits, read from its merge log on 2026-11-03. A declared squash loses nothing against a merge actually made by merge commit, because under squash the merged state is read from the review surface, which reports either.) |
| Recognising a leftover record of merged work | A task's work counts as merged when a pull request from its branch has merged on the review surface — the one the record names, or, where it names none, one opened from the record's branch. This holds under both merge styles and for a record at any step. (Owner: "it is enough to check that it is merged"; the branch lookup is a default taken here, so that a pull request opened outside the workflow is still recognised, as the history reading recognises it today.) |
| Work that has never left the machine | Cannot have merged, since a merge happens only on the review surface; its record passes the merged check without the user being asked, under either style. (Default taken here; keeps a record created before implementation resuming without a question, as today.) |
| When the review surface cannot say | Under keep every commit, the default branch's history decides, as it does today. Under squash that history cannot tell, so the user is told why and asked before the record is resumed or removed. This is the one behaviour the setting changes. (Follows from the owner's two-style decision; asking on a could-not-compute is today's rule for this check.) |
| The freeze under squash | Loses nothing the harness reads. Every reader of the freeze — each review round on the open pull request and its record of what each round rules on, the pull-request description's line on the design's change, the re-entry plan review, and the implementation step's first check — runs while the task's branch is live, and the archive of completed plans is read by its text, never by its freeze. The leftover-record check, the one exception, is the one this task changes. (Measured: read of every caller of the freeze reader and every history reader among the shipped scripts on this branch, 2026-11-03.) |
| Where the step history survives under squash | On the review surface. On this repository's, a pull request's commits stay reachable under the pull request's own reference after its branch is deleted. That is a fact of this repository's host and stays in its profile; the method states no host's retention. (Measured: this repository's version-control profile.) |

## Technical constraints

- **Instruction budget.** Every instruction file loaded whole at agent start stays below the method's
  35,000-character early warning (a threshold the method hands down). The task workflow file and the
  method file stand at 33,061 and 33,688 characters, leaving 1,939 and 1,312; this repository's agent
  rules file and context page stand at 24,133 and 33,612 (all measured by character count on this branch,
  2026-11-03).
- **Method and profile stay apart.** The method states the rules — the commit without asking, the step
  transaction, both merge styles and how the declared one is read; permission entries and the declared
  merge style are project facts and live in the profile, here and in the scaffolded template. The method
  names no host, tracker, command-line client or ticket prefix.
- **The human-findings measure.** It counts each ordinary commit pushed after a pull request opened as one
  finding a human raised; merge, fold and version-bump commits are excluded. It reads each push made to
  the pull request's branch on the review surface, never the default branch, so the merge style does not
  change it (measured: read of the counting script on this branch). Step commits made before the pull
  request opens do not reach it; a workflow that commits after it opens keeps its present number of
  commits per round, or the measure changes meaning.
- **A could-not-run is not a pass**, and the full check list runs clean with no check's input set
  silently narrowed.
- **Release.** The change touches plugin-loaded content, so the plugin's version is bumped in the same pull
  request (project convention).

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | When any workflow reaches a point where it commits on a task's branch, the commit is made without the user being asked first; no question put to the user asks for consent to a commit, and no workflow leaves a commit for the user to make. |
| AC2 | In this repository and in a project newly scaffolded by the harness, committing on a task's branch, together with staging the files that commit names, raises no permission prompt; an attempt to stage every change in the working tree at once is still not run without the user's consent. |
| AC3 | A commit attempted on the default branch is still refused, and a commit whose message carries an attribution trailer the user did not ask for is still refused. |
| AC4 | Pushing a branch and opening a pull request are each still asked before they run, and the push that ends a task is asked only after the full check list has passed following the last review approval. |
| AC5 | Every step of the task workflow that changes a shared file commits that change before the step is marked done — the requirements at their approval, the design at each write, the freeze at each plan-review approval, each implementation subtask, each in-place correction of the design, the documentation update, each review-fix round, each amendment of the requirements or the design, and the closing step; no commit carries a local record. |
| AC6 | For every step, the progress record marks the step done only after the step's outputs are written and, where they are shared files, committed, so the record never names as done a step whose outputs version control does not hold. |
| AC7 | At every plan-review approval exactly one commit carrying the approval marker is taken, even when the plan's text is unchanged since the previous round's commit, and a commit made at an earlier round is never read as a freeze. |
| AC8 | When the confirmation question is asked, the freeze already exists as a commit, and the question asks to push it and to confirm the approach — or, in a repository with no remote, only to confirm it — and asks nothing about a commit. |
| AC9 | When a task is re-entered and a step's commit exists, that step has finished: an interruption between the commit and the step being marked done — an implementation subtask whose completion was not recorded included — never causes the step to be redone, and whether resumption continues past it still depends on its outputs being present and intact. |
| AC10 | When a task is re-entered and a step's outputs exist only uncommitted, they are checked: when they are present and intact they are committed and the step counts as finished, and when they are not the step is redone; resumption then continues right after the last step that passes, validated backwards from the recorded step. |
| AC11 | A task in flight when the change ships, whose earlier steps the old rules left uncommitted, is resumed by the same rule and is never sent back to an earlier step for lacking a commit the old rules did not require. |
| AC12 | A commit that carries only the plan's documents is not held back waiting for a project build. |
| AC13 | No statement in the shipped instructions, the scaffolded project files or the user-facing description of the workflow says that a commit is asked for, confirmed or authorised by the user, or made by the user; every statement that pushing or opening a pull request is asked stays true. |
| AC14 | Every instruction file loaded whole at agent start stays below the early-warning size. |
| AC15 | This repository and every project newly scaffolded by the harness declare a merge style, squash in both; a project that declares none, or a value the method does not recognise, is treated as squash; and the user-facing description of the harness names the setting, its two values and its default. |
| AC16 | When a task workflow starts and finds a leftover record whose branch has a merged pull request — merged by squash or by merge commit — the record is not resumed: the user is offered to delete it, park it, or resume anyway, whichever step the record names and whether or not the record names the pull request. |
| AC17 | When a task workflow starts and finds a leftover record none of whose work has merged, the record is not reported as merged work under either merge style; one none of whose work has ever left the machine passes without the user being asked, even where the review surface cannot be reached. |
| AC18 | When the review surface cannot say whether a leftover record's pull request merged, a project declaring keep every commit decides it from the default branch's history, and a project treated as squash tells the user why and asks before the record is resumed or removed. |
| AC19 | With the review surface reachable, every behaviour of the task workflow and every measurement that runs after a task's pull request has merged gives the same result whichever merge style was used; none of them needs the task's branch commits, its freeze among them, to be in the default branch's history. |

## Open questions

- None.
