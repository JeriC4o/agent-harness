# Catch a one-sided edit to linked plan statements

**Source:** ticket GH-162
**Date:** 2026-10-26
**Tracked in:** GH-162

## Scope

**The problem.** Two statements of a plan pair often assert one fact: a figure in the spec and in the
design, a criterion restated where the design honours it, a count above its list. When one is edited and
the other is not, the plan contradicts itself, and nothing in the task flow is built to see that event:

- The within-document repeat class of the deterministic convergence check compares inside one document,
  never the spec against the design, and is a report rather than a hold since GH-135.
- The meaning reader that runs beside that check at design review judges meaning, but reads the whole
  current pair with no idea what changed. Asked open-endedly whether a document contradicts itself, a model
  finds few planted contradictions; asked about a named statement, it finds most (ContraDoc, cited in the
  ticket).
- Two windows have no reader at all: folding the reviewer's approval notes into the design, and a spec
  amendment answered "the approach does not change". For the second, the task recipe's spec-amendment
  route, its reference's "No" branch and the redline contract's "a changed requirement is not a divergence"
  paragraph each claim the closing fold then authors the design from the amended spec. It does not — it
  applies the correction log's rows only — so after such an amendment nothing re-reads the spec against the
  design.

**The event to catch** is a change at one site, judged against the other sites that speak about the same
object.

**What this task delivers** (the split is the owner's decision; see § Key decisions):

1. **Declared links**, wired and report only. The design author records each pair of statements that must
   move together in the plan's committed link record, as two verbatim quotes with their grounds, and a check
   of the record against the current documents runs at the end of every pass that edits the pair between
   the design's first write and the closing fold. Its report names the end that changed and the end that
   did not: an unchanged design end is brought into line by the design author, and an unchanged spec end is
   put to the human as a possible spec amendment. Which workflow sites carry the check is the design's.
2. **The "approach does not change" route repaired**, wired: the false sentences corrected; the amended pair
   re-read by today's whole-pair reader, with the declared links that touch an amended spec statement naming
   the design statements it reads first; and each genuine finding routed by the side that is wrong. A false
   design statement goes to a correction the closing fold applies while the plan has a correction log ahead
   of that fold, and is otherwise corrected directly by the design author in the same change as the
   amendment: the route is entered from several workflows, and some keep no such log at that point — a bug
   fix, a whole-project review, a plan whose closing fold already ran. A wrong spec statement goes to a
   further spec amendment, and a wrong artefact outside the pair to ordinary work.
3. **The rule for the pull-request description and the ticket**, wired; added to this task by the owner
   (§ Key decisions). Today the method has the description re-read after every push and edited whenever it
   contradicts the new commits: a strict reconciliation of a text nothing versions and no check reads, under
   a shape that asks for what changed — which the diff already shows — rather than the problem, the reason
   and where to look. And nothing reads the ticket at the end, so when the task's meaning moved during the
   work nobody offers the human a correction. The per-push sync is replaced by a read of both texts at the
   end of each iteration: the ticket is corrected only with the human's consent, and the description is
   rewritten for the reviewer.

## Out of scope

- GH-135's work, already merged: the within-document repeat class reporting instead of holding, and the
  excuse record surviving the closing fold.
- **Inferring which statements are linked from a diff of the pair, and a model read of each change.** It
  needs a statement alignment of its own and a model read per change, and nothing shows it would catch what
  a link declared when the restatement is written does not. Established practice declares the link at the
  moment the restatement is made: suspect links in requirements tools, Chromium's paired-change markers. A
  later task may take it up with evidence that one-sided edits get past declared links.
- **A recorded baseline of the pair at review rounds.** Declared links are checked against the current
  documents, so nothing in this task reads one.
- **The spec-amendment detection that reads only changes to tracked files**, and so cannot see a spec that
  was never committed: not repaired here. Its gap is a different event from the one this task catches — a
  spec edited outside the amendment route — and nothing this task delivers relies on it.
- **Embeddings or vector similarity** as a link finder. They score at chance on statements that differ only
  in a number and below random on negation — the two differences that make linked statements contradict —
  and they add a runtime dependency (research cited in the ticket).
- **A trained classifier.** It needs far more labelled drift than this repository has recorded, and it ships
  model weights, which breaks portability.
- **A deterministic hold on "a literal changed at one site and survives at another".** Linking by equal
  value joins different facts that share a value, and on planted legitimate edits it classed most of them as
  hold-worthy.
- **A per-edit hook.** Replayed over recorded edits, most of its fires were non-actionable; it fires on the
  very edit that removes a restatement, and it misses shell writes.
- **Filtering small integers out of the repeat class.** The noise comes from linking by value, not from
  magnitude.
- Approaches the research proposed beyond the ticket: a residual-old-token rule on its own, number-word
  provenance, and a file-level co-change report at pull-request time.
- Deleting the tree-derivable counts in shipped files (GH-79, GH-127), and re-reading a divergence note when
  a later change moves what it names (GH-133).
- Stale prose at the closing fold that carries neither a number nor an identity. It stays accepted as
  unnoticed, as the seventh base principle already states.
- Promoting anything to a hold, including declared links.

## Deferred

- Declared links over shipped files, generalising the hand-recorded mirror obligations | the research marks
  it later and optional, and whether it is worth building rests on how declared links fare on plan pairs
  first | yes.

## Key decisions

| Question | Decision |
|---|---|
| How the ticket is split | **Decided by the owner on 2026-10-26: all three parts are wired here, and nothing is built and left unwired.** A part no workflow step calls does nothing, so each part is either wired or not built. Inferring links from a diff of the pair and a model read of each change are not built (§ Out of scope); declared links are wired, as a report. |
| Can anything new stop a plan | Nothing new stops a plan in this task: the declared-link check reports, and promoting it to a hold is out of scope. (Decided by the owner on 2026-10-26.) |
| Who writes the declared-link record | **Decided by the owner on 2026-10-26: the design author**, when it writes or revises the design. Whenever a design statement restates or depends on a statement of the spec — a figure, a criterion it honours, a count — or two statements of one document must move together, it records the pair. One writer, per the first base principle; the spec writer never writes the record. The design author is the party writing the restatement, so the link is declared at the moment the restatement is made. |
| How the declared-link check is shown to work | No replay of recorded history and no measured bar precede wiring it: the bar the ticket sets for a declared link is a bar for holding a plan, and this check holds nothing. It is verified as an ordinary check is, over each state in both directions — a changed spec end and a changed design end. (Decided by the owner on 2026-10-26.) |
| May the closing fold correct a design statement a requirement change made false | Yes, while the plan has a correction log ahead of its closing fold, and each genuine finding of the re-read is routed by the side that is wrong. A false design statement — one the amendment made false, or a genuine design-side contradiction the re-read finds that predates it — becomes, while that log exists, a redline marker plus a correction-log row, marked as a divergence found outside a review round is marked, and the closing fold applies it; where there is no such log, the design author corrects the statement directly, in the same change as the amendment. The route is entered from several workflows, and some keep no correction log at that point: a bug fix, a whole-project review, a plan whose closing fold already ran. A wrong spec statement goes to a further spec amendment, with the human's approval, which re-enters this same route. A wrong artefact outside the pair is fixed as ordinary work, with no log row. Only a finding judged harmless is recorded instead, with its reason, in the progress record's decisions log; that log is not committed and is deleted at merge, so a genuine defect recorded only there would be lost. No finding goes into the pull-request body. The redline contract's sentence "a changed requirement is not a divergence" is reworded so the requirement itself still goes only to the spec while a design item it falsified is admitted to the log. No pinned base principle is reworded: the fifth routes the requirement to the spec, and the log row records the design item, which is a different fact. (Ticket default; the routing by the side that is wrong, the decisions-log record of a harmless finding, and the direct correction where no correction log exists, decided by the owner on 2026-10-26.) |
| Which reader serves the repaired route in this task | Today's whole-pair reader. The three sentences promise a re-read that never happens; correcting them while leaving the window unread would keep the gap the ticket names. The declared links that touch an amended spec statement name the design statements it reads first; they narrow nothing, and the whole pair is still read. |
| Where the rule for the pull-request description and the ticket is delivered | **Decided by the owner on 2026-10-26: in this task**, not in a separate ticket; no ticket is filed. It is wired here, as the other two parts are. Its requirement is the owner's own statement of the rule, restated in § Scope, and in § Acceptance Criteria; which files carry it is the design's. |
| Who performs the end-of-iteration read, and whether it can stop anything | It is a judgement of meaning, never a reconciliation and never a gate: it stops nothing, and no check reads the ticket or the pull-request description. Default: the orchestrator's own reading, made as it writes the description, with no reader spawned — the owner left this open, and it is the cheapest form that meets the criteria; the design may choose otherwise. |

## Technical constraints

- **Determinism.** The declared-link check's result is a pure function of the current plan documents and the
  committed link record: same input, same result. Model output holds nothing.
- **Three outcomes, everywhere.** Each new check reports clean, findings or could-not-run, and a
  could-not-run never reads as a pass.
- **The project's language profile and the method/profile boundary bind**: shipped method files name no
  language or tool, and method paths stay plugin-root-relative. Each new payload sibling is entered in the
  language profile's sibling list and in the payload count the project's agent rules state, in the same
  change.
- **Instruction-size headroom.** Measured by a character count on 2026-10-26, against the method's
  35,000-character early warning: the task skill at 32,499 characters, and the method file at 34,065, which
  carries the per-push rule for the pull-request description this task replaces. New workflow text lands on
  pages reached by link rather than on files loaded whole, and replacing that rule leaves the method file
  below the warning.
- **Protected pages.** The spec-writer and design contracts, the design-review contract, the closing-fold
  skill, the task skill and its reference, and the redline check are the plan-invariants protected set, so
  every edit to them is put to the author when made.
- **The propagation rule binds.** Every restatement this task changes — what the plan checks report and what
  holds, what survives the closing fold, and how a spec amendment that keeps the approach is routed — lands
  on every member of its sync group in the same change; the plan-convergence, redline and spec-amendment
  groups each carry some of them.
- **Plugin-loaded content changes**, so the plugin's patch version is bumped.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Whenever the design author writes or revises the design, it records in the plan's committed link record every pair of statements that must move together: a design statement that restates or depends on a statement of the spec — a figure, a criterion it honours, a count — and any two statements of one document that must move together. Each row is two verbatim quotes, each with its document and heading, plus the grounds for the link. The design author is the record's only writer; the spec writer never writes it. |
| AC2 | Checked against the current documents, a row whose quotes are both found is silent; exactly one missing reports that link as moved, naming which end changed and which was not re-confirmed; both missing reports it for re-confirmation; a quote found more than once reports it as ambiguous. The result depends only on the current documents and the record. |
| AC3 | A non-silent row — moved, re-confirm or ambiguous — is cleared only by rewriting that row with the current quotes and fresh grounds; nothing clears several rows in one act. |
| AC4 | The check runs at the end of every pass that edits the plan pair after the design is first written and before the closing fold: every write by the design author, including each review-round revision and each design amendment, and every spec amendment, once the spec writer has applied it. |
| AC5 | A moved link's report names the end that changed and the end that did not, and what follows depends on where the unchanged end sits. An unchanged end in the design is brought into line by the design author, except after a spec amendment answered "the approach does not change", where it takes the route AC8 states. An unchanged end in the spec is put to the human as a possible spec amendment, and the check never edits the spec. A design edit that contradicts a linked spec statement is either a design error, fixed in the design, or a genuine conflict, which changes the spec only through a spec amendment the human approves; a spec is never narrowed to match its design. A re-confirm or ambiguous row is rewritten by the design author, as AC3 states. |
| AC6 | The declared-link record survives the closing fold as the excuse record does; its check reports a folded spec as skipped, never as clean; and every check of what a folded or pending plan carries, and the step that moves a finished plan into the completed-plans directory, treat the record as they treat the excuse record. |
| AC7 | In this task no result of the declared-link check stops a plan from proceeding; it reports. |
| AC8 | After a spec amendment answered "the approach does not change", the whole amended pair is re-read by the meaning reader before work resumes, and the design statements that declared links tie to an amended spec statement are named to it as the ones to read first. Each genuine finding is routed by the side that is wrong. A false design statement — one the amendment made false, or a genuine design-side contradiction that predates it — becomes, while the plan has a correction log ahead of its closing fold, a redline marker plus a correction-log row, which the closing fold applies; where there is no such log, the design author corrects it directly, in the same change as the amendment. A wrong spec statement goes to a further spec amendment, with the human's approval, which re-enters this same route; a wrong artefact outside the pair is fixed as ordinary work, with no log row. A finding judged harmless is recorded with its reason in the progress record's decisions log. No instruction file claims that the closing fold re-authors the design from an amended spec, and no finding is carried into the pull-request body. |
| AC9 | A push that ends no iteration triggers nothing: no rule, reminder or workflow step asks for the ticket or the pull-request description to be read, or reconciled with the diff, because a push happened, and no check reads either text. |
| AC10 | At the end of each iteration the ticket, when the task has one, and the pull-request description are both read for whether they convey the task's meaning. An iteration ends at the first pass, before the pull request is opened, and at every correction pass after it, whether a fix round for failing checks or one for reviewer comments, in whichever workflow runs that pass on an open pull request. |
| AC11 | The ticket stays the original basis for the work and changes only with the human's consent: when the end-of-iteration read finds that it no longer conveys the task's meaning, a correction is put to the human, and the ticket is edited only when the human accepts it. |
| AC12 | At the end of each iteration the pull-request description is written for the reviewer from the whole task, not from the last push — at the first pass for the pull request being opened, and at each correction pass in place of the previous description. It states the problem in the task's own terms, why it is being solved, and what to pay attention to in review; where the task changed a process, it carries a diagram of that process. It carries no test details, no counts, no acceptance-criterion checklist and no stats. |
| AC13 | The pull-request description names the issue the pull request resolves, unambiguously, and no other ticket: it keeps the `Closes #N` trailer for that issue alone, and no other ticket is named anywhere in it — not in a trailer, not elsewhere in the description, whether wrapped in backticks or not. No instruction file admits an exception to this. |
| AC14 | No method page names the diagram's form; each says the diagram takes the form the project's profile names. This project's profile names Mermaid, which the host renders in a pull-request description, and the profile template a new project is scaffolded from names Mermaid as a default the project may change. |

## Open questions

- (none)
