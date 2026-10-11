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
approved**, authors the corrected design afresh as a separate commit on the same PR. **The same marking-and-log
mechanism also serves a divergence noticed while the code is being written**, where no review has run to
give it a round or a finding number; Scope 13 settles what happens there.

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
   does the divergence break the agreed approach? **At the review-and-fix round this test DECIDES the
   route:** breaking → blocker, routed as today; non-breaking → one marker, one log row, and the code fix
   proceeds in the same round. **While the code is being written it only INFORMS** — there it is one input
   to the once-per-task mode choice under Scope 13, never a route taken automatically.

2. **Stop the non-breaking case blocking the code fix.** `agents/self-review.md:151` requires the
   orchestrator to re-run the planning chain "BEFORE the code change lands" on either amendment arm
   (`agents/self-review.md:146`); `skills/task/SKILL.md:173` routes a design-file subject to a Step 7
   re-run and `skills/task/SKILL.md:174` routes a spec-file subject to a full Step 6 → Step 7 chain, max
   3 rounds each. Both routes are narrowed to the breaking case **at the review-and-fix round**; neither
   fires on a divergence surfaced while the code is being written.

3. **Freeze the base at the design-approval verdict, and mark in place after it.** Marking becomes a function
   of the `design` subagent (`agents/design.md`), the only party permitted to write `*.design.md` under
   `docs/agents-method.md:124`. One invocation per MARKING OCCASION that carries divergences — a
   review-and-fix round, or the implementation step when divergences surface there — never one per
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

   **A divergence includes the base having been SILENT, not only the base having been untrue.** On a
   research-and-development task the plan carries many blank spots, so a base that said nothing about
   something is the normal case rather than a defect: a row may record that the base was silent and that
   this is what the work established. `added` already means exactly that relative to the frozen base, so
   **the vocabulary stays these three tokens** and no fourth is invented.

5. **Carry the log in a COMMITTED file.** The fold runs after approval, so the log must survive from the
   round that wrote it to a point past the human review. `.gitignore:22` ignores
   `ai-docs/plans/**/*.progress.md`, so the progress file cannot be the carrier.

6. **Wire the reviewer to the markers.** `agents/self-review.md:31` requires the progress file's canonical
   fields to be PRESENT but says "Don't review their content". The reviewer's contract gains the rule that
   a marked item is settled and is not re-raised in a later round. Without this, round N+1 re-reads the
   same base and re-raises the divergence — the loop this change exists to remove.

7. **Admit a non-amendment writer of the design mid-round.** Today a round whose plan targets
   `ai-docs/plans/*.design.md`, or carries a row dispositioned as a design amendment, is routed into the
   amendment chain, and those two suffixes are dropped from its measured diff and named as excluded — all
   on the premise that the only mid-round writer of them is an approved amendment. The marking pass makes
   that premise false, so left unchanged a marking pass is routed straight into the chain this change
   exists to remove.

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

11. **Keep the concrete test set out of the frozen plan — in the design AND in the spec.** The base obliges
    every criterion to carry a CONCRETE test, search or shell command (`agents/design.md`), and the in-task
    gate re-runs those exact commands against the shipped tree and `REJECT`s on any failure
    (`agents/self-review.md`) — the channel that fires this loop most often, where the rest of this spec
    concerns only the post-merge pass (`agents/review-findings.md`). Identifiers and invocations are chosen
    while the work is done, after the document is agreed, so a document promising them diverges by
    construction — a **systematic** divergence growing with the criterion count.

    **So the constraint binds BOTH frozen documents.** The design keeps the verification **intent** per
    criterion, naming no test method, path or command; the concrete set sits outside it, hence outside the
    frozen base, where it cannot falsify it. `agents/spec-writer.md` gains the same rule for the spec:
    behaviour observable from outside plus the boundary of what it deliberately leaves out, and no command,
    script, test identifier or tool. Its settling test — *if the implementation can change without changing
    externally visible behaviour, it does not belong in the spec.* **Mechanism inside a requirement was
    mandated, not accidental:** that file told the writer to turn a Definition of Done into a
    machine-checkable guard recorded in the spec; it now demands the obligation and forbids the instrument.

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

13. **Settle the correction MODE once per task, at the first divergence found while writing the code.**
    Such a divergence has no round number and no finding number, because no review has run — and nothing
    restarts on its own account. The implementation step stops at the FIRST one, leads with a
    **recommendation read off the design**, states its grounds in one line, and the user confirms or flips
    it with a single word. The chosen mode then governs every later divergence in the same task: asking
    again at each one reimposes the per-divergence cost this change exists to remove. The mode is recorded
    in the **redline log's HEADER** — the progress file is gitignored (`.gitignore:22`) and is deleted at
    merge, while the log is committed and is what the closing fold reads.

    **The recommendation rests on signals a reader can point at in the design**, never on a preference: a
    non-empty open-questions section and risks deferred to a later task point to the R&D mode; decisions
    carried as MEASURED rather than assumed — anchors pinned to real output, probes already run — point to
    the hybrid mode.

    **R&D mode.** The design is accepted as carrying blank spots. A correction or an extension goes into
    the log as it is found, nothing restarts, and the closing fold is where the design becomes true again.

    **Hybrid mode.** A non-breaking divergence or an extension goes into the log; a divergence the user
    judges to break the approach may still take the rebuild route. Its one operative discipline is **do not
    inflate scope**, written as a test rather than an exhortation: an extension is admitted only when it is
    needed to make the shipped thing CORRECT, not merely because it is adjacent to it — an extension that
    would widen what the task DELIVERS is a new ticket, not a log row.

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
| Merge-time cleanup reaching progress files under `ai-docs/plans/done/`; deletion of `*.spec.md.state.md` | Pre-existing defects, independent of this mechanism | Already GH-109 |
| A capability-indexed spec root with per-task change folders and a delta merge at archive | This task takes the spec's FORM only; separating durable state from per-task history reshapes the plan tree — filed, not dropped | Already GH-114 |
| A verification pass reading the spec as an oracle, with the dimensions it judges kept separate | Same staging: the form settles first, so this was filed too | Already GH-115 |

## Key decisions

| Question | Decision |
|---|---|
| Is the design rewritten during the task, and why mark in place rather than cross-reference? | **Not once it is frozen — and the freeze begins at the design-approval verdict.** Before that the document is still being authored and a correction is simply a rewrite; after it a correction is a marker plus a log row, colocated with the item it corrects so the reviewer can skip a settled item. |
| What does a marker carry? | **A pointer to its log row, and nothing else** — not the correction's type, not its text. One fact in one place: a marker that repeated the type would duplicate the log row's own field and the two could drift, and the marker's only job is to let a reviewer skip a settled item. **Strikethrough is excluded**, though it was considered: it PRESERVES the superseded wording, which the row below forbids. |
| Is a record of superseded material kept anywhere? | **No, at any stage.** Not while the design is being authored, not after the freeze, not in the folded document. The design reflects the work and the design decisions at that revision and nothing more; a train of thought and an account of what an earlier round argued only get in the way, and they are read in full by every later whole-repository review. The review round's own findings table is where a correction's reasoning belongs. |
| Does the fold edit the frozen document or author a new one? | **Authors it afresh**, for the stale-by-omission reason given under Scope 9. Same output path, since `ai-docs/plans/done/` holds one design per task. |
| Who marks, and how often? | **The `design` subagent, once per marking occasion that carries divergences** — a review-and-fix round, or the implementation step when divergences surface there. Marking and reconciling the log against the design are its functions — not a checked-in script's and not the orchestrator's. One invocation per divergence is forbidden; so is deferring all marking to the fold. (Per-round bound recorded by the orchestrator, not vetoed.) |
| When does the fold run, and does it always run? | **After PR approval, as a separate commit on the same PR — and only when the log has at least one row.** A human's review is a correction record of the same class as a machine-review divergence, so folding earlier would force either a second fold or a design stale the moment it is assembled. "After merge" was rejected: it would force the correction onto a second branch and a second PR, and this repo never edits on the default branch. Zero rows means the frozen plan already describes what shipped; the step records which branch it took rather than running a no-op rewrite. |
| What starts the fold? | **A named command.** Agent-polling of the review surface is rejected: it can fire while the user is still mid-comment and consume an incomplete set of human corrections — the exact failure the one-fold-at-the-end shape exists to prevent. A conversational cue alone is rejected as having no backstop. |
| What if nobody runs it? | **The merge-time workflow REFUSES on finding an unprocessed log.** Binding, not optional. Its limit is recorded with it: it runs after the fold's window, so it catches the omission and cannot repair it. |
| Does the folded design get a second look before merge? | **No.** Its correctness is whether it matches the shipped code, which existing machinery already checks. No review pass, no user reading, no approval gate is added. |
| Where does suppression authority over later findings live? | **In the collapsed spec only** — the record of deliberate absence. `agents/review-findings.md:25` grants it to designs as well today; that is a required edit target of this change. |
| Where does the log live? | **In a committed file**, because it must survive to a fold that runs after the human review. This REVERSES the carrier named in the ticket body; that reasoning is superseded and is not restated here. |
| A divergence that breaks the agreed APPROACH, at the review-and-fix round? | **Keep today's full rebuild.** The expensive path now fires rarely rather than on every stale sentence, and a scoped alternative requires judging which part is affected — a wrong judgement leaves a stale base standing, a new failure mode bought to cheapen a rare path. (Orchestrator default, surfaced with its reasoning and not vetoed.) |
| What happens when the code diverges from the frozen plan while it is being WRITTEN? | **Nothing restarts on its own account; the mode is chosen ONCE per task at the first such divergence; marker-plus-row is the default.** Recommendation-first, confirmed or flipped in one word, because the design usually already shows which process the work is — a bare question hands the reader work the document can answer, and a question repeated at every divergence is the cost this change exists to remove. Mechanism, modes, signals and the do-not-inflate-scope test: Scope 13. The ground-up rebuild stays available and unchanged. |
| Does the fold carry a supersession chain or overwrite? | **Destructive overwrite.** A design is reshaped by dozens of discarded experiments; the superseded reasoning belongs to approaches that did not survive and has close to no readership. |
| Is the spec deleted at the fold? | **No — collapsed.** Its surviving payload is the record of *deliberate absence*: `## Out of scope`, `## Deferred`, `## Key decisions`, verbatim. The design has no section that can carry this; it describes what was built, never the boundary of what was deliberately not built. |
| What happens to markers and rows when a BREAKING divergence triggers the full rebuild? | **The rebuild consumes them, the log resets to empty, and the rebuilt document becomes the new frozen base.** Derived from two settled decisions: the rows describe divergence from a base that no longer exists, and the destructive-fold decision already says the superseded journey has no readership. The rebuild must therefore be *told* the accumulated corrections, or it loses them. |
| Does the log survive the fold as a file? | **No — the fold removes it.** Of everything in `ai-docs/plans/done/`, only `agents/review-findings.md` reads anything, and it reads `*.spec.md` and `*.design.md` only, so nothing would consume a retained log; the log is committed, so the PR's history preserves the record. Two consequences: the post-merge reading list is NOT widened, and a surviving log is an unambiguous mechanical signal that the fold never ran. |
| What is the artefact called? | **"redline"**, never "corrections log" unqualified — that name is taken by the Learning Log (`docs/corrections-log.md` is its field glossary; `docs/agents-method.md:187` calls `ai-docs/learnings.md` the "Corrections log ARCHIVE"). The closing pass is **"the redline fold"**, never a bare "fold": `docs/propagation.md:24` already anchors a **Fold group** for `/improve`'s learning-log fold, and `skills/improve/SKILL.md` carries **20 occurrences of the bare word across 13 lines**. An unqualified second mechanism would collide in every sweep. |
| Who performs the fold's writes? | **The owning subagents** — `design` for the design, `spec-writer` for the spec. Forced by `docs/agents-method.md:124`: the orchestrator NEVER writes `*.spec.md` / `*.design.md`. The fold is a spawn, not an orchestrator edit. |
| Which surface writes a row? | **At the review-and-fix round, the agent that writes the findings table, at the moment it writes it** — "a byproduct of review, not a new step". A divergence found while the code is being written has no findings table, so its row is written at the implementation step when the fix lands — still a byproduct of the work rather than a step of its own. |

## Technical constraints

**The reviewer's native write surface is the gitignored file, and the log must be committed.**
`agents/self-review.md:37` appends its `## Self-Review (Round N)` section to the progress file, and
`agents/self-review.md:159` names that file as where findings go. Two shapes satisfy the committed-carrier
decision: the reviewer writes rows straight into the committed log, or it keeps writing to the progress
file and the round's single `design`-subagent invocation promotes them while it marks. The second leaves the
reviewer's contract untouched and gives the committed file one writer, matching the decision that log
reconciliation is the design subagent's function. The settled decision binds the carrier, not the path.

**Nothing in this harness can see an approval today.** No file under `docs`, `agents`, `skills`, `hooks`
or `rules` refers to a review-approval state at all. That is why the trigger is a named command rather
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
40,000-char axiom with a 35,000-char early warning, over the list at `:48`. Current sizes, re-measured
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
depended on them to "name a route that did not exist". Independently, the deletion path is broken:
merge-time cleanup resolves a task's spec across both `ai-docs/plans/done/` and `ai-docs/plans/` but
deletes from `ai-docs/plans/` only, so a progress file under `done/` survives — a **300,024-char**
orphan sits at
`ai-docs/plans/done/2026-10-06-scouted-fix-plan.progress.md` in this tree right now. The fold's removal of the log is that lifecycle.

**Overlap with the existing fix plan.** `docs/templates/progress-format.md:75` already carries a
per-finding column "Arm A — artefact sentence at stake", holding a quoted sentence plus its `file:line`,
gate-validated against the file (`:147` — the gate resolves the anchor and checks the quoted sentence is
within three lines of it). That is close to the redline row's payload. Deriving rather than duplicating is a
live option for the design phase; two independent records of one divergence is the drift shape this repo
keeps paying for.

**Propagation groups this change fires** (`docs/propagation.md`): Review group (`:17`, `:18`);
Spec-Amendment group (`:30`, `:31`); Scouted-Fix group (`:32`, `:33` — seven members); Task/Design group
(`:28`, `:29`). Because this is a new MECHANISM rather than a phrase, `docs/propagation.md:47` (Procedure
item 4) makes a token sweep insufficient: a new sync group row is owed, in the anchor-plus-back-reference
shape item 5 mandates (`:48`). The propagation reminder's own path classes are derived from that table and
held to agree with it in both directions, so a new group row can oblige a new reminder arm.

**Method / profile split is live.** `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` are method files: no
language, build tool, domain entity or ticket prefix may appear in them, and paths inside them are
`${CLAUDE_PLUGIN_ROOT}`-relative while project-data paths stay repo-relative. A method file acquiring a
project fact is a `major` finding.

**Gate registration is two-sided.** Any check this change adds must be registered both in `AGENTS.md`'s
structural-check span and as a member of the combined check list, which derives its suite from the tree and
holds the two lists to agree in both directions. And a newly created file is unknown to version control
until it is staged, which silently narrows the input set of any check that walks tracked files only.

**Release mechanics.** The install cache is keyed by version, so this PR bumps
`.claude-plugin/plugin.json`'s patch version.

**Measurement this change is judged by later** (not an acceptance criterion). The baseline is at
`ai-docs/context.md:210-212` and the weighting formula a comparable figure must use at `:242`. Read those
lines directly — the per-round split is the comparison, never an average — rather than any summary here,
which would be a second copy that drifts.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Correct code is no longer rejected for a stale document: the sentence at `agents/self-review.md:52` is replaced by a two-branch test on whether the divergence breaks the agreed approach, and no instruction to reject on staleness alone survives anywhere in that file. |
| AC2 | A non-breaking divergence produces exactly one in-place marker plus one log row and does NOT block the round: no planning-chain re-run is triggered, and the code fix for that finding is applied in the same round. The "BEFORE the code change lands" requirement (`agents/self-review.md:151`) and the routing rows (`skills/task/SKILL.md:173-174`) are narrowed to the breaking case **at the review-and-fix round** only, and neither fires on a divergence surfaced while the code is being written. |
| AC3 | The design document is NOT rewritten during the task for a non-breaking divergence: the marking is additive to the item it marks, and the item's original text remains readable in the file after marking. |
| AC4 | The marking is performed by the `design` subagent and is bounded to **one invocation per marking occasion carrying divergences** — a review-and-fix round, or the implementation step when divergences surface there — stated as a bound in the step text — not one per divergence, and not deferred to the fold. The orchestrator writes `*.design.md` at no point. |
| AC5 | The reviewer treats a marked item as settled: the agent's contract states that a divergence already marked is not re-raised in a later round, and the carve-out from `agents/self-review.md:31`'s "Don't review their content" is explicit. The reviewer is NOT instructed to read the log as a separate input and reconcile it against the design. |
| AC6 | The redline row's shape is documented with a closed type vocabulary of **exactly three tokens** (`added` / `modified` / `removed` relative to the frozen base), the artefact and sentence diverged from, and what shipped instead — in the same register as the existing `Fix Plan (Round N)` section. The documented shape states that a base which was SILENT about something is recorded as `added`, so no fourth token is owed; and the row's KEY admits a row that has neither a round nor a finding number — a round-and-finding key for a row raised by a review, a step-and-ordinal key (`S8.1`) for one raised while the code was being written. |
| AC7 | The log survives from the round that wrote it to a point past the PR's approval: version control tracks it rather than ignoring it, and merge-time cleanup does not delete it. |
| AC8 | A round whose plan records a marking pass is accepted and is not routed into the amendment chain, while a round carrying a genuine design amendment still is — the discrimination holds in both directions, not just the pass. The round's accounting for excluded mid-round writes of `ai-docs/plans/*.design.md` names the marking pass as a legitimate writer of them. |
| AC9 | Closing a finding whose subject was a spec or design sentence, with no log row accounting for it, is REFUSED, not merely discouraged. The refusal is observed to fire against a deliberately planted missing row, and it keeps firing for later work rather than holding only for the round that introduced it. |
| AC10 | The redline fold has a named home that runs **after PR approval and before merge**, producing a separate commit on the same PR, started by a **named command**. The step text names the command, states what happens when the log is empty, and states what happens when nothing starts it. Neither `/pr-merged` nor any post-merge surface hosts the fold itself, and no polling of the review surface is introduced. |
| AC11 | The merge-time workflow REFUSES when an unprocessed redline log is present on the branch, before it deletes or moves anything, and the refusal fires on a present log and not on an absent one. The step text records the sequencing limit in its own words: the refusal runs after the fold's window, so it catches the omission and cannot repair it. |
| AC12 | A breaking divergence **at the review-and-fix round** still has a blocking route to the full rebuild, and the rebuild is handed the accumulated markers and log rows, after which the log is empty and the rebuilt document is the new frozen base. The step text names this hand-off explicitly. |
| AC13 | After the fold, the design describes the as-built result and carries no `## Handoff plan`, no `## Open questions`, no markers, no amendment residue **and no record of superseded material** — no "an earlier draft said", no quoted superseded wording, no account of what a previous round argued. Neither those headings nor the marker syntax appears anywhere in it, and every section of it describes the shipped state rather than a past one. |
| AC14 | After the fold, the spec retains `## Out of scope`, `## Deferred` and `## Key decisions` **byte-identical** to their pre-fold text — identical to that text as it actually stood, not merely to a plausible rewrite of it. |
| AC15 | Suppression authority names the spec only: every instruction in `agents/review-findings.md` that confers it names `*.spec.md` and no design. **Two spellings confer it, and they fail differently.** `:25` names `*.spec.md` and `*.design.md` explicitly; the restatement at `:115` — "Anything explicitly documented as intentional in `ai-docs/plans/done/`" — names the **directory**, so it confers the same authority while naming no filename, and narrowing the filename spelling alone leaves it standing. Both are narrowed. The AC-verification re-run over `done/*.design.md` (`:38`) is RETAINED as an obligation — it is verification, not suppression, and losing it would be a silent regression — while its predicate changes with AC22 to intent-coverage. |
| AC16 | The fold removes the log from the tree, and the post-merge reading list is NOT widened: `agents/review-findings.md` still names `*.spec.md` and `*.design.md` in `ai-docs/plans/done/` and no further file class. |
| AC17 | Naming is unambiguous: the artefact is "redline", the closing pass is "the redline fold", and no new bare "fold" or bare "corrections log" appears anywhere that could be read as the `/improve` learning-log fold (`docs/propagation.md:24`) or as the Learning Log archive (`docs/agents-method.md:187`). |
| AC18 | `docs/propagation.md` gains a sync group for this mechanism in the anchor-plus-back-reference shape, naming every member on the anchor row, and the propagation reminder fires on each of those members — which members it names is what satisfies this, never a bare pass. |
| AC19 | No method file this change touches exceeds **35,000 chars** once the change is complete. A file that would cross it is extracted rather than allowed to cross. |
| AC20 | The repository's whole check list runs clean, with exactly one verdict per member, no drift between that list and the tree, and its input set not silently narrowed — every shell file this change adds is among the files actually processed rather than skipped as unknown to version control. `.claude-plugin/plugin.json`'s patch version is bumped. |
| AC21 | No method file under `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` acquires a language, build tool, domain entity or ticket prefix; project-data paths in them stay repo-relative and method paths stay `${CLAUDE_PLUGIN_ROOT}`-relative. |
| AC22 | A changed test identifier is not a finding. `agents/design.md` no longer demands a concrete command per criterion — it demands the verification **intent**, in terms naming no test method, file path or command — and `agents/self-review.md`'s re-run asserts that each criterion's stated intent is covered by some shipped check, rather than re-running a command the design guessed before the tests existed. **Two-sided, not just the pass:** RENAMING a shipped test produces no `REJECT` and no amendment route, while a criterion with NO covering check still fails. `agents/review-findings.md:38`'s post-merge re-run is either adjusted consistently or its divergence from the in-task gate is recorded as deliberate with the reason stated. |
| AC23 | No record of superseded material survives in a design at any stage, and the rule binds BOTH sides of the review. `agents/design.md` states that while the design is authored or reviewed a correction is a rewrite and the document carries no account of what an earlier draft said or argued. `agents/design-review.md` states that a revision account is not a thing a verdict may require, and points a correction's reasoning at the round's own findings table. **The reviewer's clause is the half that was missing, so it is the one shown to bite:** neither file carries such a rule today, and under the new clause a verdict demanding a revision account is refused while an ordinary finding is unaffected. **This task's own design is where the rule is first owed:** it accumulated ten such passages because a reviewer asked for them and the author complied, so the criterion is unmet until those ten are gone and every section of that document describes the current state rather than a past one. |
| AC24 | The implementation step takes NO route automatically on a divergence from the frozen plan: it stops at the **first** one in the task and puts the choice to the user ONCE, leading with a recommended mode whose grounds are read off the design and settled by the user's confirm-or-flip. Both modes are named (R&D and hybrid), the chosen one governs every later divergence in the same task, and no condition re-runs the planning chain by itself. The chosen mode is recorded where the closing fold reads it — the committed log's header, not the progress file that merge deletes. A task whose divergences were all raised by a review never reaches that choice and owes no mode. |
| AC25 | **A judgement criterion: whether an extension is needed to make the shipped thing correct rather than merely adjacent to it is a judgement, so what satisfies this is the recorded decision on each extension and not a check.** The hybrid mode's scope discipline is stated as that test rather than an exhortation: an extension reaches the log only when correctness needs it, and one that would widen what the task DELIVERS is routed to a new ticket instead of a log row. |
| AC26 | A spec written under this method states behaviour and the boundary of what it deliberately leaves out, and a criterion naming a command, script, test identifier or tool is REFUSED, not merely discouraged. The two cases that look like exceptions are settled rather than left to be re-argued: a requirement that something be MECHANICAL becomes the refusal it delivers, and one whose subject is a check becomes the property that check demonstrates. **This task's own spec is where the rule is first owed:** no criterion in it names an instrument. |

## Open questions

1. **Which write path carries a row into the committed log** — the reviewer directly, or the round's single
   design-subagent invocation promoting it while it marks — and the same question for a row raised while
   the code was being written, which has no reviewer at all. The trade is under Technical constraints.
2. **Whether the row is DERIVED from the existing fix-plan "artefact sentence at stake" column or recorded
   independently.** The overlap is recorded under Technical constraints so the choice is made deliberately.
3. **Where the named command lives** — a command of its own, or a named step of an existing workflow invoked
   by name. AC10 constrains that it is named and non-polling, not where it is declared.
4. **The marker's concrete SPELLING**, and whether that spelling must be machine-detectable for the
   completeness gate and the fold's residue check. What the marker IS — a pointer to its log row, carrying
   neither the correction's type nor its text — is settled under Scope 3 and is not reopened here; only the
   token's shape is a design-phase choice.
