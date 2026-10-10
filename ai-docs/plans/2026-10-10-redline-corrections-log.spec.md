# Redline log: freeze the plan, mark divergences in place, fold once after approval

**Source:** ticket GH-108
**Date:** 2026-10-10
**Tracked in:** GH-108

## Problem this solves (for a reader who has not seen the ticket)

A review finding whose subject is a sentence in the task's spec or design currently stops the whole fix
round and re-runs the upstream planning chain before any code fix may land — even when the code is correct
and only the document is stale. And nothing at the end of the task corrects those documents to match what
shipped: they reach `ai-docs/plans/done/` in whatever state the task left them.

This change replaces the mid-review amendment detour, for the non-breaking case, with three moves: the
base plan is **frozen once the design is approved**; a diverged item is then **marked in place with a
pointer** to the log row carrying its correction — the marker says only that the item is settled, never what
changed — while the correction text goes into a **redline log**; and **one closing fold, after the PR is
approved**, authors the corrected design afresh as a separate commit on the same PR.

**The marker's colocation is the payoff, and it is the point of the design.** Because every marker sits on
the item it corrects, a reviewer reading the design sees which items are already settled and skips them,
so the design stops being re-verified in detail every round. A mechanism in which the reviewer reads the
log as a separate input and cross-references it against the design is explicitly rejected: it pays for
exactly the reconciliation this shape eliminates.

**What a design document IS**, settled here because the rest depends on it: a design describes the WORKING
LOGIC of the solution, not a ledger of the decisions taken to reach it. Two consequences run through this
spec. Its correctness is simply whether it matches the shipped code, so the fold needs no new review pass
and no user reading. And because it claims nothing was deliberate, it cannot be the authority that
silences a later finding.

## Scope

1. **Change the review question from document-match to approach-break.** `agents/self-review.md:52`
   rejects on staleness alone today — "Stale design that says one thing while implementation does another
   (even correctly) → REJECT (`major`)" — alongside `agents/self-review.md:51`: "No architectural
   decisions made on-the-fly without being reflected in the design?". Replace the staleness test with:
   does the divergence break the agreed approach? Breaking → blocker, routed as today. Non-breaking →
   one marker, one log row, and the code fix proceeds in the same round.

2. **Stop the non-breaking case blocking the code fix.** `agents/self-review.md:151` requires the
   orchestrator to re-run the planning chain "BEFORE the code change lands" on either amendment arm
   (`agents/self-review.md:146`); `skills/task/SKILL.md:173` routes a design-file subject to a Step 7
   re-run and `skills/task/SKILL.md:174` routes a spec-file subject to a full Step 6 → Step 7 chain, max
   3 rounds each. Both routes are narrowed to the breaking case.

3. **Freeze the base at the design-approval verdict, and mark in place after it.** Marking becomes a function
   of the `design` subagent (`agents/design.md`), the only party permitted to write `*.design.md` under
   `docs/agents-method.md:124`. One invocation per review round that carries divergences, never one per
   divergence.

   **The freeze is an EVENT and must be named, or the mechanism is unimplementable.** AC12 requires a breaking
   rebuild to produce "the new frozen base", so a freeze happens at a point in time rather than holding
   vacuously; naming the second one and not the first leaves the first undefined. It begins at the
   design-review GO verdict. **Before it, a correction is a REWRITE:** the design is
   still being authored, the review loop rewrites sections by its own contract (`agents/design.md` §
   Iteration), and nothing has shipped for the base to diverge from. **After it, a correction is a marker plus
   a log row.** The marker is a POINTER to its log row and carries neither the correction's type nor its text:
   one fact in one place, and the marker's only job is to let a reviewer skip a settled item.

4. **Define the redline row as a typed record of a SURVIVING divergence** between the frozen base and what
   shipped — `added` / `modified` / `removed` relative to the base. Not a decision taken along the way,
   and not a discarded experiment: an experiment that left no divergence leaves no row. This ties the
   log's volume to the result rather than to the process.

5. **Carry the log in a COMMITTED file.** The fold runs after approval, so the log must survive from the
   round that wrote it to a point past the human review. `.gitignore:22` ignores
   `ai-docs/plans/**/*.progress.md`, so the progress file cannot be the carrier.

6. **Wire the reviewer to the markers.** `agents/self-review.md:31` requires the progress file's canonical
   fields to be PRESENT but says "Don't review their content". The reviewer's contract gains the rule that
   a marked item is settled and is not re-raised in a later round. Without this, round N+1 re-reads the
   same base and re-raises the divergence — the loop this change exists to remove.

7. **Teach the fix-plan gate that a non-amendment party now writes the design.**
   `skills/task/scripts/check-fix-plan.sh` routes a round's plan into the amendment chain whenever a `fix`
   row's target matches `ai-docs/plans/*.design.md` (`:514`; the sibling spec arm is `:512`) or a row is
   dispositioned `amendment: design` (`:520`) — failing arms A2/A3 at `:565` and `:568`. It also drops
   those two suffixes from the measured diff total (`:97`, `:98`) and names them on an `excluded-in-round`
   line (`:698`), on the stated premise that the only mid-round writer of those files is an approved
   amendment. The marking pass makes that premise false, so left unchanged this gate routes the marking
   pass straight into the chain the change exists to remove.

8. **Move suppression authority off the design and onto the collapsed spec.**
   `agents/review-findings.md:25` tells every later whole-branch review: "Read every `*.spec.md` and
   `*.design.md` in `ai-docs/plans/done/` — these document **intentional** decisions. Do not raise findings
   for anything explicitly described there." A design of working logic makes no intentionality claim, so it
   must not silence a finding; only the collapsed spec's record of deliberate absence may.
   `agents/review-findings.md:115` repeats the clause and moves with it. The AC-verification re-run over
   `done/*.design.md` (`agents/review-findings.md:38`) is NOT suppression and stays.

9. **Give the fold a home and a named trigger.** It runs after PR approval as a separate commit on the same
   PR. `/task` has no post-approval step — `skills/task/SKILL.md:228` declares everything arriving after
   Step 12 a post-push fix round — and `/pr-merged` activates only on a confirmed merge
   (`skills/pr-merged/SKILL.md:4`, reinforced at `:19`), so it cannot host a pre-merge commit. The fold
   **authors the as-built design AFRESH** rather than editing the frozen one in place; strips spent process
   scaffolding — `## Handoff plan` (`agents/design.md:69`) and `## Open questions` (`agents/design.md:96`),
   plus marker and amendment residue **and any record of superseded material**; collapses the spec to
   `## Out of scope`, `## Deferred`, `## Key decisions` verbatim; and removes the log from the tree, which is
   what makes a surviving log mean "not folded".

   **Fresh authoring is the mechanism, not a style preference.** An in-place edit leaves every sentence the
   editor did not touch, and what it does not touch is precisely what nobody re-read — stale by omission, and
   invisible to any check that looks only at what changed. A freshly authored document cannot inherit a stale
   sentence through a gap. The output path is unchanged: `ai-docs/plans/done/` holds one design per task and
   `agents/review-findings.md` relies on that, so "fresh" means re-authored, never a second file.

10. **Make the merge-time workflow refuse an unprocessed log.** `/pr-merged` is the merge-time workflow and
    gains the refusal. **Recorded sequencing limit:** it runs after the window the fold needs, so the
    refusal can only CATCH the omission and can never repair it — a caught error instead of silent damage,
    which is the whole claim being made for it.

11. **Split the design's test obligation so the final test set never enters the frozen base.** Today
    `agents/design.md:116` requires every acceptance criterion to be linked to a CONCRETE test / search /
    shell command, and `:94`'s example writes a test-method name straight into the design;
    `agents/self-review.md:53` then re-runs those exact commands against the shipped tree and issues
    `REJECT (major)` on any failure. Test identifiers are chosen while the tests are written, so the design
    is obliged to promise names that do not yet exist — a **systematic** divergence that grows with the
    criterion count rather than an occasional one. Split the obligation: the design keeps the verification
    **intent** per criterion, stated in terms that name no test method, path or command; the concrete
    command, identifier and path set is recorded outside the design and is therefore outside the frozen
    base, so it cannot falsify it. **This is the same defect this change exists to remove, arriving through
    its most frequent channel — and the one channel the rest of this spec does not cover:** every other
    mention of the re-run here concerns `agents/review-findings.md:38`, the post-merge pass, while
    `agents/self-review.md:53` is the adjacent in-task gate that actually fires the loop and survives AC1's
    narrowing of `:52` untouched.

12. **Forbid a record of superseded material in the design, on BOTH sides of the review.** The rule binds the
    author in `agents/design.md`: while the design is being authored or reviewed, a correction is a rewrite,
    and the document carries no account of what an earlier draft said or argued. **And it binds the reviewer
    in `agents/design-review.md`, which is the half that makes it hold** — neither file states such a rule
    today, so a reviewer is free to improvise a demand for one, and on this branch one did: it asked the
    author to state that a first draft's claim was false "rather than quietly correcting the count", the
    author complied, and ten such passages accumulated. A rule that binds only the author is overridden by the
    next review verdict that asks for the opposite. The reviewer's clause is therefore the operative one: a
    revision account is not a thing a verdict may require, and the round's own findings table is where a
    correction's reasoning belongs.

## Out of scope

- An enforced **size limit** on planning documents. The fold still strips spent scaffolding — that is in
  scope — but no gate is built and no number is set here.
- A new **review pass, user reading, or approval gate on the folded design**. Its correctness is whether it
  matches the shipped code, and existing machinery already checks that.
- **Extending any of this to the other review loops** — `/bugfix`, `/project-review`, post-push fix rounds
  (`docs/workflow.md:86`). `agents/self-review.md` is shared by all of them, so the change there must be
  written so those callers keep today's behaviour; that is a constraint, not an extension.
- **The orphaned-file defects in the plan tree.** This task consumes GH-109 only as evidence that the
  gitignored working file cannot carry the log.
- **Adopting ADR.**
- Re-litigating any settled decision below.

## Deferred

| What | Why | Separate ticket? |
|---|---|---|
| An enforced size limit for retained planning documents | Nine method files already touched; four of them within 3,000 chars of the early-warning threshold, so net-additive prose there is unavailable | Yes — to be filed |
| Extension to `/bugfix`, `/project-review`, post-push fix rounds | Gated on a like-for-like measurement | Already GH-98 |
| An immutable per-decision record (ADR) | Attempts here are cheap and numerous, so a per-attempt record scales with attempts | No |
| `cleanup-progress.sh` reaching `ai-docs/plans/done/`; deletion of `*.spec.md.state.md` | Pre-existing defects, independent of this mechanism | Already GH-109 |

## Key decisions

| Question | Decision |
|---|---|
| Is the design rewritten during the task, and why mark in place rather than cross-reference? | **Not once it is frozen — and the freeze begins at the design-approval verdict.** Before that the document is still being authored and a correction is simply a rewrite; after it a correction is a marker plus a log row, colocated with the item it corrects so the reviewer can skip a settled item. |
| What does a marker carry? | **A pointer to its log row, and nothing else** — not the correction's type, not its text. One fact in one place: a marker that repeated the type would duplicate the log row's own field and the two could drift, and the marker's only job is to let a reviewer skip a settled item. **Strikethrough is excluded**, though it was considered: it PRESERVES the superseded wording, which the row below forbids. |
| Is a record of superseded material kept anywhere? | **No, at any stage.** Not while the design is being authored, not after the freeze, not in the folded document. The design reflects the work and the design decisions at that revision and nothing more; a train of thought and an account of what an earlier round argued only get in the way, and they are read in full by every later whole-repository review. The review round's own findings table is where a correction's reasoning belongs. |
| Does the fold edit the frozen document or author a new one? | **Authors it afresh.** An in-place edit leaves every sentence the editor did not touch, and those are exactly the ones nobody re-read — stale by omission, and invisible to a check that looks only at what changed. Same output path, since `ai-docs/plans/done/` holds one design per task. |
| Who marks, and how often? | **The `design` subagent, once per review round that carries divergences.** Marking and reconciling the log against the design are its functions — not a checked-in script's and not the orchestrator's. One invocation per divergence is forbidden; so is deferring all marking to the fold. (Per-round bound recorded by the orchestrator, not vetoed.) |
| When does the fold run, and does it always run? | **After PR approval, as a separate commit on the same PR — and only when the log has at least one row.** A human's review is a correction record of the same class as a machine-review divergence, so folding earlier would force either a second fold or a design stale the moment it is assembled. "After merge" was rejected: it would force the correction onto a second branch and a second PR, and this repo never edits on the default branch. Zero rows means the frozen plan already describes what shipped; the step records which branch it took rather than running a no-op rewrite. |
| What starts the fold? | **A named command.** Agent-polling of the review surface is rejected: it can fire while the user is still mid-comment and consume an incomplete set of human corrections — the exact failure the one-fold-at-the-end shape exists to prevent. A conversational cue alone is rejected as having no backstop. |
| What if nobody runs it? | **The merge-time workflow REFUSES on finding an unprocessed log.** Binding, not optional. Its limit is recorded with it: it runs after the fold's window, so it catches the omission and cannot repair it. |
| Does the folded design get a second look before merge? | **No.** Its correctness is whether it matches the shipped code, which existing machinery already checks. No review pass, no user reading, no approval gate is added. |
| Where does suppression authority over later findings live? | **In the collapsed spec only** — the record of deliberate absence. `agents/review-findings.md:25` grants it to designs as well today; that is a required edit target of this change. |
| Where does the log live? | **In a committed file**, because it must survive to a fold that runs after the human review. This REVERSES the carrier named in the ticket body; that reasoning is superseded and is not restated here. |
| A divergence that breaks the agreed APPROACH? | **Keep today's full rebuild.** The expensive path now fires rarely rather than on every stale sentence, and a scoped alternative requires judging which part is affected — a wrong judgement leaves a stale base standing, a new failure mode bought to cheapen a rare path. (Orchestrator default, surfaced with its reasoning and not vetoed.) |
| Does the fold carry a supersession chain or overwrite? | **Destructive overwrite.** A design is reshaped by dozens of discarded experiments; the superseded reasoning belongs to approaches that did not survive and has close to no readership. |
| Is the spec deleted at the fold? | **No — collapsed.** Its surviving payload is the record of *deliberate absence*: `## Out of scope`, `## Deferred`, `## Key decisions`, verbatim. The design has no section that can carry this; it describes what was built, never the boundary of what was deliberately not built. |
| What happens to markers and rows when a BREAKING divergence triggers the full rebuild? | **The rebuild consumes them, the log resets to empty, and the rebuilt document becomes the new frozen base.** Derived from two settled decisions: the rows describe divergence from a base that no longer exists, and the destructive-fold decision already says the superseded journey has no readership. The rebuild must therefore be *told* the accumulated corrections, or it loses them. |
| Does the log survive the fold as a file? | **No — the fold removes it.** Of everything in `ai-docs/plans/done/`, only `agents/review-findings.md` reads anything, and it reads `*.spec.md` and `*.design.md` only, so nothing would consume a retained log; the log is committed, so the PR's history preserves the record. Two consequences: the post-merge reading list is NOT widened, and a surviving log is an unambiguous mechanical signal that the fold never ran. |
| What is the artefact called? | **"redline"**, never "corrections log" unqualified — that name is taken by the Learning Log (`docs/corrections-log.md` is its field glossary; `docs/agents-method.md:187` calls `ai-docs/learnings.md` the "Corrections log ARCHIVE"). The closing pass is **"the redline fold"**, never a bare "fold": `docs/propagation.md:24` already anchors a **Fold group** for `/improve`'s learning-log fold, and `skills/improve/SKILL.md` carries **20 occurrences of the bare word across 13 lines** (`grep -o` and `grep -c`, case-sensitive — two different measures, both stated because they differ). An unqualified second mechanism would collide in every sweep. |
| Who performs the fold's writes? | **The owning subagents** — `design` for the design, `spec-writer` for the spec. Forced by `docs/agents-method.md:124`: the orchestrator NEVER writes `*.spec.md` / `*.design.md`. The fold is a spawn, not an orchestrator edit. |
| Which surface writes a row? | The agent that writes the findings table, at the moment it writes it — "a byproduct of review, not a new step". |

## Technical constraints

**The reviewer's native write surface is the gitignored file, and the log must be committed.**
`agents/self-review.md:37` appends its `## Self-Review (Round N)` section to the progress file, and
`agents/self-review.md:159` names that file as where findings go. Two shapes satisfy the committed-carrier
decision: the reviewer writes rows straight into the committed log, or it keeps writing to the progress
file and the round's single `design`-subagent invocation promotes them while it marks. The second leaves the
reviewer's contract untouched and gives the committed file one writer, matching the decision that log
reconciliation is the design subagent's function. The settled decision binds the carrier, not the path.

**Nothing in this harness can see an approval today.** `grep -rn 'reviewDecision'` over `docs`, `agents`,
`skills`, `hooks` and `rules` returns zero hits (exit 1). That is why the trigger is a named command rather
than an observation, and why the backstop has to live in a workflow that *is* triggered.

**`main` carries no branch protection** — the protection endpoint returns 404 "Branch not protected". So
there is no required-review rule and no "dismiss stale approvals on new commits" setting: pushing the fold
commit after approval dismisses nothing and blocks nothing. With suppression authority moved off the design
(Scope 8), that is a fact about the platform rather than a risk.

**The post-merge reading list, and what it is read FOR.** `agents/review-findings.md:25` reads every
`*.spec.md` and `*.design.md` in `ai-docs/plans/done/`, and `:38` re-runs every `AC<N> verified by:` line
from those designs. That list is today **12 tracked documents totalling 891,725 chars**, the largest a
single design at **269,905 chars** — re-measured this round over `done/*.spec.md` and `done/*.design.md`,
the two globs the agent names. `agents/design.md:126` records the observed rewrite hazard at "~50KB" — the
real worst case here is five times that — and `ai-docs/plans/*.design.md` is absent from the 40,000-char axiom's list (`docs/agents-method.md:48`), so nothing bounds it. After this
change the designs are still read and their AC lines still re-run; what they stop doing is silencing
findings.

**Size headroom is the binding constraint on how this is written.** `docs/agents-method.md:46` carries the
40,000-char axiom with a 35,000-char early warning, over the list at `:48`. Current `wc -c`, re-measured
this round:

| File this change must touch | chars | Headroom to 35,000 |
|---|---|---|
| `docs/agents-method.md` | 34,877 | **123** |
| `skills/task/reference.md` | 33,609 | 1,391 |
| `agents/self-review.md` | 33,455 | 1,545 |
| `skills/task/SKILL.md` | 32,101 | 2,899 |
| `docs/workflow.md` | 26,777 | 8,223 |
| `agents/review-findings.md` | 16,974 | 18,026 |
| `docs/templates/progress-format.md` | 14,792 | 20,208 |
| `docs/propagation.md` | 11,201 | 23,799 |
| `agents/design.md` | 9,422 | 25,578 |

Four of the nine sit within 3,000 chars of the early warning and one within 123. Net-additive prose in
those four is not available: the change either lands in the roomy files, or extracts as it adds. This
measurement is why the size limit is out of scope.

**A new committed plan-tree file owes an explicit lifecycle.** `ai-docs/context.md:222-223` records
figures that lived only in the gitignored progress section and "died with it", leaving the disposition that
depended on them to "name a route that did not exist". Independently, the deletion path is broken: `cleanup-progress.sh:43` resolves the spec across both
`ai-docs/plans/done/` and `ai-docs/plans/`, then `:46` deletes from `ai-docs/plans/` only, leaving a
**300,024-char** orphan at `ai-docs/plans/done/2026-10-06-scouted-fix-plan.progress.md` in this tree right
now. The fold's removal of the log is that lifecycle.

**Overlap with the existing fix plan.** `docs/templates/progress-format.md:75` already carries a
per-finding column "Arm A — artefact sentence at stake", holding a quoted sentence plus its `file:line`,
gate-validated against the file (`:147` — the gate resolves the anchor and checks the quoted sentence is
within three lines of it). That is close to the redline row's payload. Deriving rather than duplicating is a
live option for the design phase; two independent records of one divergence is the drift shape this repo
keeps paying for.

**Propagation groups this change fires** (`docs/propagation.md`): Review group (`:17`, `:18`);
Spec-Amendment group (`:30`, `:31`); Scouted-Fix group (`:32`, `:33` — seven members, including
`check-fix-plan.sh` and `progress-format.md`); Task/Design group (`:28`, `:29`).
Because this is a new MECHANISM rather than a phrase, `docs/propagation.md:47` (Procedure item 4) makes a
token sweep insufficient: a new sync group row is owed, in the anchor-plus-back-reference shape item 5
mandates (`:48`). `scripts/check-propagation-arms.sh` DERIVES the reminder's path classes from that table
and asserts the `case` arms in `hooks/hooks.json` agree, so a new group row can oblige a new hook arm.

**Method / profile split is live.** `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` are method files: no
language, build tool, domain entity or ticket prefix may appear in them, and paths inside them are
`${CLAUDE_PLUGIN_ROOT}`-relative while project-data paths stay repo-relative. A method file acquiring a
project fact is a `major` finding.

**Gate registration is two-sided.** Any new gate script must appear both in `AGENTS.md`'s structural-check
span and as a member of `scripts/run-checks.sh`, which derives its suite from the tree and asserts the two
lists agree in both directions. A new script also needs `git add -N` before the shell-syntax gate, whose
input set is tracked files only.

**Release mechanics.** The install cache is keyed by version, so this PR bumps
`.claude-plugin/plugin.json`'s patch version.

**Measurement this change is judged by later** (not an acceptance criterion). The baseline is at
`ai-docs/context.md:210-212` and the weighting formula a comparable figure must use at `:242`. Read those
lines directly — the per-round split is the comparison, never an average — rather than any summary here,
which would be a second copy that drifts.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | `agents/self-review.md` no longer rejects on staleness alone: the sentence at `agents/self-review.md:52` is replaced by a two-branch test on whether the divergence breaks the agreed approach, and a `grep -n` over the file shows no surviving instruction to reject correct code for a stale document. |
| AC2 | A non-breaking divergence produces exactly one in-place marker plus one log row and does NOT block the round: no planning-chain re-run is triggered, and the code fix for that finding is applied in the same round. The "BEFORE the code change lands" requirement (`agents/self-review.md:151`) and the routing rows (`skills/task/SKILL.md:173-174`) are narrowed to the breaking case only. |
| AC3 | The design document is NOT rewritten during the task for a non-breaking divergence: the marking is additive to the item it marks, and the item's original text remains readable in the file after marking. |
| AC4 | The marking is performed by the `design` subagent and is bounded to **one invocation per review round carrying divergences**, stated as a bound in the step text — not one per divergence, and not deferred to the fold. The orchestrator performs no `Edit` on `*.design.md`. |
| AC5 | The reviewer treats a marked item as settled: the agent's contract states that a divergence already marked is not re-raised in a later round, and the carve-out from `agents/self-review.md:31`'s "Don't review their content" is explicit. The reviewer is NOT instructed to read the log as a separate input and reconcile it against the design. |
| AC6 | The redline row's shape is documented with a closed type vocabulary (`added` / `modified` / `removed` relative to the frozen base), the artefact and sentence diverged from, and what shipped instead — in the same register as the existing `Fix Plan (Round N)` section. |
| AC7 | The log is committed and reachable after the PR is approved: it is not matched by `.gitignore` (`git check-ignore` reports nothing for it) and it is not deleted by `skills/pr-merged/scripts/cleanup-progress.sh`. |
| AC8 | `bash skills/task/scripts/check-fix-plan.sh` no longer routes the marking pass into the amendment chain, and its `excluded-in-round` accounting (`:698`) names the marking pass as a legitimate mid-round writer of `ai-docs/plans/*.design.md`. A test asserts a round carrying a marking pass PASSES the gate, and a separate test asserts a genuine `amendment: design` row still FAILS it — the discrimination, not just the pass. |
| AC9 | Completeness is enforced by a CHECKED-IN GATE, not by prose: closing a finding whose subject was a spec or design sentence with no accounting log row is refused. Per `docs/agents-method.md` § Tooling ("A check MANDATED in prose is not yet a check"), the gate is demonstrated to FAIL against a deliberately planted missing row before the mandate is written down, and that demonstration ships as a test. |
| AC10 | The redline fold has a named home that runs **after PR approval and before merge**, producing a separate commit on the same PR, started by a **named command**. The step text names the command, states what happens when the log is empty, and states what happens when nothing starts it. Neither `/pr-merged` nor any post-merge surface hosts the fold itself, and no polling of the review surface is introduced. |
| AC11 | The merge-time workflow REFUSES when an unprocessed redline log is present on the branch, before it deletes or moves anything; a test asserts the refusal fires on a present log and does NOT fire on an absent one. The step text records the sequencing limit in its own words: the refusal runs after the fold's window, so it catches the omission and cannot repair it. |
| AC12 | A breaking divergence still has a blocking route to the full rebuild, and the rebuild is handed the accumulated markers and log rows, after which the log is empty and the rebuilt document is the new frozen base. The step text names this hand-off explicitly. |
| AC13 | After the fold, the design describes the as-built result and carries no `## Handoff plan`, no `## Open questions`, no markers, no amendment residue **and no record of superseded material** — no "an earlier draft said", no quoted superseded wording, no account of what a previous round argued. A grep over the folded document for those headings and for the marker syntax returns nothing. **The superseded-material leg is checked POSITIVELY, not by a fragment search:** a document that records its own corrections necessarily contains the superseded text inside a quotation, so proving an absence from a fragment gives a false positive — verified twice on this branch's own design. Assert instead that every section of the folded document describes the shipped state, and spot-check the phrases that introduce a revision account. |
| AC14 | After the fold, the spec retains `## Out of scope`, `## Deferred` and `## Key decisions` **byte-identical** to their pre-fold text, and the check that asserts this compares against the captured pre-fold content rather than against a plausible rewrite. |
| AC15 | Suppression authority names the spec only: no instruction in `agents/review-findings.md` authorises suppressing a finding on the basis of a `*.design.md`. **Two spellings must both be narrowed, and they fail differently.** `:25` names `*.spec.md` and `*.design.md` explicitly. The restatement at `:115` — "Anything explicitly documented as intentional in `ai-docs/plans/done/`" — names the **directory**, so it confers the same authority while surviving any search for the filename. **The check names its own pattern:** a grep for `design\.md` is explicitly NOT sufficient, and a criterion met by that grep alone is a false green of exactly the shape `docs/agents-method.md` § Tooling warns about ("a check MANDATED in prose is not yet a check: the spelling is part of it"). The verification instead ENUMERATES every instruction in the file that confers suppression — by filename or by directory — and asserts each names the spec only; it is demonstrated against a fixture carrying the directory spelling before the mandate is written down. The AC-verification re-run over `done/*.design.md` (`:38`) is retained unchanged — it is verification, not suppression, and losing it would be a silent regression. |
| AC16 | The fold removes the log from the tree, and the post-merge reading list is NOT widened: `agents/review-findings.md` still names `*.spec.md` and `*.design.md` in `ai-docs/plans/done/` and no further file class. |
| AC17 | Naming is unambiguous: the artefact is "redline", the closing pass is "the redline fold", and a `grep -rn` shows no new bare "fold" or bare "corrections log" that could be read as the `/improve` learning-log fold (`docs/propagation.md:24`) or as the Learning Log archive (`docs/agents-method.md:187`). |
| AC18 | `docs/propagation.md` gains a sync group for this mechanism in the anchor-plus-back-reference shape, naming every member on the anchor row; `bash scripts/check-propagation-arms.sh` exits 0 **and** its reported member list is read and confirmed to name the new members, not merely its exit status. |
| AC19 | Every method file this change touches still reports `wc -c` **below 35,000**, measured after the change. A file that would cross it is extracted rather than allowed to cross. |
| AC20 | `bash scripts/run-checks.sh` exits 0 with exactly one verdict per member and no list drift; any new `*.sh` is tracked (`git add -N`) before the shell-syntax gate runs and the processed file COUNT is read beside the verdict. `.claude-plugin/plugin.json`'s patch version is bumped. |
| AC21 | No method file under `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` acquires a language, build tool, domain entity or ticket prefix; project-data paths in them stay repo-relative and method paths stay `${CLAUDE_PLUGIN_ROOT}`-relative. |
| AC22 | A changed test identifier is not a finding. `agents/design.md` no longer demands a concrete command per criterion — it demands the verification **intent**, in terms naming no test method, file path or command — and `agents/self-review.md`'s re-run asserts that each criterion's stated intent is covered by some shipped check, rather than re-running a command the design guessed before the tests existed. **Two-sided demonstration, not just the pass:** one test shows that RENAMING a shipped test produces no `REJECT` and no amendment route; a separate test shows that a criterion with NO covering check still fails. `agents/review-findings.md:38`'s post-merge re-run is either adjusted consistently or its divergence from the in-task gate is recorded as deliberate with the reason stated. |
| AC23 | No record of superseded material survives in a design at any stage, and the rule binds BOTH sides of the review. `agents/design.md` states that while the design is authored or reviewed a correction is a rewrite and the document carries no account of what an earlier draft said or argued. `agents/design-review.md` states that a revision account is not a thing a verdict may require, and points a correction's reasoning at the round's own findings table. **The two-sided demonstration is the reviewer's clause, because that is the half that was missing:** neither file carries such a rule today, so show that a verdict demanding a revision account is refused under the new clause, and separately that an ordinary finding is unaffected. **This branch's own design is the fixture:** it accumulated ten such passages because a reviewer asked for them and the author complied, so the criterion is not met until those ten are gone from `ai-docs/plans/2026-10-10-redline-corrections-log.design.md` and the positive check — every section describes the current state rather than a past one — passes over it. |

## Open questions

1. **Which write path carries a row into the committed log** — the reviewer directly, or the round's single
   design-subagent invocation promoting it while it marks. The trade is under Technical constraints.
2. **Whether the row is DERIVED from the existing fix-plan "artefact sentence at stake" column or recorded
   independently.** The overlap is recorded under Technical constraints so the choice is made deliberately.
3. **Where the named command lives** — a command of its own, or a named step of an existing workflow invoked
   by name. AC10 constrains that it is named and non-polling, not where it is declared.
4. **The marker's concrete SPELLING**, and whether that spelling must be machine-detectable for the
   completeness gate and the fold's residue check. What the marker IS — a pointer to its log row, carrying
   neither the correction's type nor its text — is settled under Scope 3 and is not reopened here; only the
   token's shape is a design-phase choice.
