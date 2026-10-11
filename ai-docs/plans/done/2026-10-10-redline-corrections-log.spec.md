# Redline log: freeze the plan, mark divergences in place, fold once after approval

**Source:** ticket GH-108
**Date:** 2026-10-10
**Tracked in:** GH-108

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

