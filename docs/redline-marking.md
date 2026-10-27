# Redline marking — the contract

The third invocation mode of the `design` subagent, extracted from
[`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Redline marking](${CLAUDE_PLUGIN_ROOT}/agents/design.md#redline-marking),
which loads whole on every spawn while this mode runs only when a divergence is found. Everything below binds
the marking pass exactly as it did inline.

A third invocation mode, and the only one in which this subagent writes to an AGREED design rather than
authoring one. Invoked by `/task` wherever a divergence between the design and what shipped is found after
the freeze — during implementation, or in a review-and-fix round whose findings carry one — and by the route
of a spec amendment that keeps the approach, in whichever workflow entered it, where the plan has a
correction log ahead of its closing fold
([`${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md` § Spec Amendment recipe](${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md#spec-amendment-recipe-re-entrant--triggered-from-a-step-7-verdict),
step 5).

**The freeze is an event, and it is the design-review GO verdict.** Before it the document is still being
authored and a correction is a rewrite (`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Rules); after it there
is an agreed base and the code is being measured against it, so a correction is a marker plus a log row.
Nothing here has to ask which régime it is in: the marking pass runs after implementation has begun, and
neither implementation nor the review-and-fix cycle can be reached without a GO. **One window sits between the two and is the only
post-GO rewrite there is:** a GO verdict carrying notes is closed by folding them in, which `/task` Step 8
and `agents/self-review.md` both require to happen BEFORE the implementation diff starts — **both read
those notes out of the task's working record, where Step 7 transcribes them, not out of the review
response, so when you are spawned to fold one in that record is where it is.** Nothing has been
measured against the base yet, so there is nothing to mark; once the diff starts, that window is shut and
every correction is a marker plus a row.

**One invocation per review round that carries divergences, one per implementation step that does, and one
per spec amendment whose re-read leaves a false design item or a non-silent declared link** — never one per
divergence, and never deferred to the closing fold. One pass marks every diverged item its
caller found and promotes every row.

**The marker is a pointer, and it carries nothing else:**

```
**[REDLINE R<round>.<finding #>]**
**[REDLINE S<step>.<ordinal>]**
```

- It is **appended** to the end of the marked item, and the ITEM is the unit, not the line: for prose,
  the end of the item — its paragraph or list item — never mid-sentence, and never at a wrapped line's
  end that is not also the item's end, because a hard-wrapped paragraph's diverged sentence can end
  anywhere inside it; and **the end of the cell carrying the item's prose** for a table row — not after
  the row's closing `|`, which is outside the table, and not in a cell holding dependencies or paths,
  where a reader does not meet the item. The original wording is untouched and stays readable. That
  colocation is the whole payoff: a reviewer reading the design sees which items are already settled and
  skips them, so the document stops being re-verified in detail every round.
- It carries the log-row key and nothing more — not the correction's type, not its text. One fact in one
  place: a marker repeating the type would duplicate the row's own field and the two could then drift.
- It carries no `|` and no newline, so appending it inside a table cell cannot shift a column. Most
  marked items are decomposition rows, which is the cell shape most likely to break.
- `R<round>.<finding #>` is derived from numbers both sides already carry, so there is no new identifier
  to keep in step, and the key is the marker's entire payload.
- **The two forms divide on whether the divergence has a PLAN ROW, not on where it was noticed.** A
  finding a round planned supplies both halves of `R<round>.<finding #>`; anything with no plan row takes
  `S<step>.<ordinal>`, for want of a findings table to take a finding number from — the workflow step
  supplies the first half, the order of discovery the second. These two forms are the whole set.
- **A row is keyed to the step whose WORK it belongs to, not necessarily the step that noticed it**, and
  the ordinal is per key prefix, never global: the key exists to pair a marker with a row, so a key that
  moved whenever a later step noticed something would break pairs already written.
- **A key is recognised by SHAPE, so a document that quotes the token is not a marked document.** A key is
  alphanumerics, dots, dashes and underscores; the two lines above are templates, and angle brackets and
  spaces are not key characters. Not every `[REDLINE …]` occurrence is a marker — a file explaining the
  spelling carries no key at all, which is why the pairing check reads one of those lines as nothing
  rather than as an unpaired key.

**The row is DERIVED from the round's fix-plan row, never re-authored.** The reviewer originates it as a
`redline: <type> — <what shipped instead>` disposition in that round's `## Fix Plan (Round N)` table; this
pass promotes it into the committed log. Nothing is written twice:

| Log row field | Comes from |
|---|---|
| `Key` | `R<round>.<finding #>` — the round from the plan section's heading, the number from the row's `#` cell |
| `Key`, no plan row | `S<step>.<ordinal>` — the step from the workflow, the ordinal from the order of discovery |
| `Type` | the disposition's type token: `added`, `modified` or `removed`, relative to the frozen base |
| `Artefact sentence diverged from` | the plan row's `Arm A` cell, **transformed and not copied** — that cell carries a position because the fix-plan gate requires one of it, and this log carries none, so the promotion resolves the position to the entity holding the sentence: the named file and a heading or numbered item inside it, with only the sentence travelling verbatim |
| `What shipped instead` | the disposition's reason text, which **opens** the cell verbatim — a floor, not a cap: the pass may extend it with shipped facts a one-line reason could not hold, such as a second site corrected in the same pass |

**With no plan row — a divergence found during implementation, or a design item a spec amendment's re-read
ruled false — this pass authors the row itself**, from
the same two facts: the design sentence quoted verbatim with the entity it sits in, and what shipped. The
derivation above exists so
that one divergence is not recorded twice, and where no plan row was ever written there is no second
record to drift from.

**A pass that touches an EXISTING row re-derives every MEASUREMENT in it**, not only the fields it came to
change. A row measures sizes that later rounds are free to edit, so a figure correct when it was written is
a claim about a tree that no longer exists — and this record is committed, so a stale figure ships. **There is no position in a row to re-derive**, because the quoting field names an
entity instead. The duty covering positions belongs to the round's own gitignored working record alone,
where it is stated on
[`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md)
§ Anchors and measurements in this file go stale while it is being written; no single rule spans both
records.

The log is `ai-docs/plans/<spec-base>.redline.md`. It is **committed**, because the fold that consumes it
runs after a human review and the progress file cannot survive that far. Its row format is defined in
[`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md),
beside the fix-plan row it is derived from. A row records a **surviving** divergence, not a decision taken
along the way: an experiment that left no divergence leaves no row, which ties the log's volume to the
result rather than to the process.

**A row may record an EXPANSION, not only a correction of something untrue.** A base that was simply
silent about something is the normal case on work that still holds open questions, not a defect — so the
row records that the base said nothing and this is what the work established. That is what `added` already
means relative to the frozen base, so there is no fourth type token to invent.

**An extension marks the nearest item whose SCOPE it falls within** — the section, or the decomposition
row, the new work belongs to. A marker needs an item to point at, and a silence offers none; the
containing item is that anchor, and the marker on it says it is incomplete as written while the row says
what was added. The payoff is colocation's usual one: a reader of that section learns it grew before
starting to re-verify it. **If no item in the design contains the work at all**, it is not an extension
but a missing whole, and it takes the breaking route — the line that keeps "extension" from becoming a
bucket for unplanned scope.

**A changed REQUIREMENT is not a divergence and does not come here; a design item it made false does.**
This log records shipped work departing from the frozen design; a change to what was ASKED FOR belongs in
the spec, written by the spec's own owner. The fold applies this log's rows and nothing else, so it never
re-reads the spec against the design: an amendment that keeps the approach is followed by a re-read of the
amended pair instead, and a design item that re-read rules false is admitted here where the plan has a log,
and corrected directly by the design author where it has none
([`${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md` § Spec Amendment recipe](${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md#spec-amendment-recipe-re-entrant--triggered-from-a-step-7-verdict),
step 5). The row records the design item, a different fact from the requirement: a changed artefact goes
to the log, a changed requirement goes to the spec, and nothing is recorded in both places.

**Both halves are mechanically checked, so neither is optional — and each key form has its own checker.**
`${CLAUDE_PLUGIN_ROOT}/skills/task/scripts/check-fix-plan.sh` refuses a plan that closes a finding whose
`Arm A` cell names a spec or design sentence with nothing accounting for it, and after the pass its `A8`
arm asserts that the design carries the marker and the log a row under the same key: that is the in-round
half, and `R<round>.<finding #>` is the only form it reads, because it takes the key from a plan row.
`${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh paired` is the half that covers `S<step>.<ordinal>`, where
no plan row exists — for every `[REDLINE <key>]` in the design a row under that key in the log, and for
every row a marker, in both directions and for both key forms. A missing marker and a missing row are each
a finding. What no check can see is a plan row that declares `none` where a sentence really is at stake —
that judgement is what the `Arm A` cell exists to capture, and it is yours.

**Your own exit check, and it is not optional.** Having appended every marker and promoted every row, run
`${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh paired <design> <log>` whenever the pass wrote a marker or
the log exists, and hand back on nothing but a clean 0 — an amendment's pass that only rewrites
declared-link rows writes no marker, and `paired` over a log that does not exist cannot run. On anything else, say **which** of the two non-clean outcomes you got — findings, or cannot-run,
which is not a pass — and what it named. This is the only moment both halves are freshly written and you
are still in context to fix them; after you hand back, a missing row is someone else's puzzle. **Then
run `${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-links.sh <spec> <design>`**, a report that
sits outside the clean-0 refusal above, and carry its verdict line in the hand-back. An ordinary marking
pass moves no link, because the comparison removes markers, so its report travels as it stood; what each
state means and where it leads is
[`${CLAUDE_PLUGIN_ROOT}/docs/declared-links.md`](${CLAUDE_PLUGIN_ROOT}/docs/declared-links.md).

**In a review-and-fix round, a divergence that BREAKS the agreed approach is not marked.** There the test
is mechanical, and the breaking case routes to the full rebuild, which is handed the accumulated markers
and rows, after which the log resets to empty and the rebuilt document becomes the new frozen base. The
rows described a base that no longer exists, so the rebuild must be told them or they are lost.

**During implementation that call is the user's, and the default is the cheap one.** The step surfaces the
divergence and names the two modes below; the breaking / non-breaking test informs the choice rather than making
it, because no gate reads it here. Unless the user asks for the design to be rebuilt from the ground up —
a route that stays available and unchanged — the answer is fixed in the code and the correction becomes a
marker plus a log row, with no re-review and no re-run of the design-and-review loop.

**That choice is made ONCE PER TASK, on the first divergence.** The step surfaces that one — or, when the
first is a design item a spec amendment's re-read ruled false, that amendment's route puts the question
before its marking pass is spawned — the user picks a mode, and the mode governs every later divergence in
the same task. A mode already in the log's head is never asked again, whichever occasion put it. A
question re-asked at each divergence is the cost this mechanism exists to remove.

| Mode | What it means |
|---|---|
| **R&D** | The design is accepted as carrying blank spots. A correction or an extension goes into the log as it is found, nothing restarts, and the closing fold is where the design becomes true again. The path for work whose design could not have been complete |
| **Hybrid** | The mixed régime: a non-breaking divergence or an extension goes to the log, while a divergence the user judges to break the approach may still take the rebuild route. Its one operative discipline is a **test, not an exhortation — an extension is admitted only when it is needed to make the shipped thing correct**, never because it is adjacent to it. An extension that would widen what the task delivers is a new ticket, not a log row |

**The step leads with a RECOMMENDATION, not a bare question.** The design usually already shows which
process this is going to be, so a bare question hands the user work the document can answer.
Recommendation first, its grounds in **one line**, and a single word settles it. The grounds are signals
read off the design under review and **quoted** in the recommendation, so the user can disagree with the
evidence rather than with a preference:

| Signal, quoted from the design | Points to |
|---|---|
| A non-empty `## Open questions` — every gap it may carry is one this contract's own open-gap rule admits, so the section records a question the WORK answers rather than a hole in the base | R&D, and the strongest single signal there is |
| A risk phrased as unknown until implementation, or a measurement deferred to a named later task | R&D |
| Work that creates a mechanism that does not exist yet | R&D |
| Decisions carried as measured rather than assumed, and every claim about existing behaviour tied to the entity it is true of | Hybrid — that base was built against facts and is unlikely to need widening |
| Work that changes something whose shape is already known and measured | Hybrid |

A recommendation that needs a paragraph to justify has already failed: this gate exists to cost the user
one keystroke, and not to exhaust them.

**The chosen mode is recorded in the LOG's header, not in the progress file.** The progress file is
gitignored and deleted at merge, while the log is committed and is what the fold reads — and the mode is
what explains to a later reader why the log holds the number of rows it holds.
