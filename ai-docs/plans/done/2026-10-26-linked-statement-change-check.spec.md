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

