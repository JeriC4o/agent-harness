# Declared links

The contract for a plan pair's record of statements that must move together, and for the check that
reads it. Pointed at from [`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Rules](${CLAUDE_PLUGIN_ROOT}/agents/design.md#rules),
which gives the design author the record, and from the Spec Amendment recipe on
[`${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md`](${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md#spec-amendment-recipe-re-entrant--triggered-from-a-step-7-verdict),
which routes what an amendment moved. The record's format is
[`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` § The record of declared links (committed)](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md#the-record-of-declared-links-committed).

**Nothing on this page stops a plan.** The check exits like a gate, and every site that runs it reads it as
a report: none refuses on it, and a could-not-run of it travels in the hand-back and blocks nothing.

## What a link is

Two statements of a plan pair that must move together, so that editing one and not the other leaves the
plan contradicting itself:

- **a design statement that restates or depends on a statement of the spec** — a figure, a criterion it
  honours, a count;
- **any two statements of one document that must move together** — a count and the list it counts, a
  rule and the example that applies it.

Each link is one row of `ai-docs/plans/<spec-base>.links.md`: two verbatim quotes, each with its document
and the heading it sits under, and the grounds for the link. A quote is **the words carrying the shared
fact** — the figure, the requirement, the count — rather than the paragraph around them: short enough that
an unrelated edit beside it moves nothing, long enough to be found once in its document.

## The record's one writer

**The design author**, at the moment the restatement is written, by the party writing it. On every write of
the design it records every link the pair has, and writes the record even when there is none. It stages the
record by name the first time it writes it. The spec writer never writes the record, and neither does the
orchestrator.

- **A record carrying the table's header and no row declares a pair with no links**, which is how a design
  that restates nothing says so; the check reads it as clean, with a link count of zero.
- **An absent record declares nothing at all**, and the check reads it as a could-not-run naming the record
  it looked for. Every site that runs the check runs it once a design exists, so an absent record there
  means a write declared nothing rather than that nothing needed declaring.
- **A record present but not in the index is a could-not-run**, because a record other clones cannot see
  makes this run's report differ from every other clone's. So is a record with no table header, a row with
  an empty cell or the wrong number of cells, an end naming a document other than the spec or the design,
  and a quote that normalises to nothing.

## The check

`${CLAUDE_PLUGIN_ROOT}/scripts/check-plan-links.sh <spec> <design>`. It reads the record, the two documents,
the index of the work tree the spec sits in, and the sections a folded spec keeps, borrowed from the closing
fold's own gate — nothing else, so its result depends on no history.

Each quote and each document is normalised the same way — whitespace folded to one space, `\|` read as `|`,
every redline marker removed and then every asterisk — so a re-wrap, a change of emphasis or a marker
appended to an item never moves a link. Each document is split into sections at its heading lines, outside
fenced blocks and through blockquote markers, and each quote is counted in every section of its own end's
document:

| Quotes | State |
|---|---|
| both found exactly once | silent |
| exactly one found nowhere | `moved` — the missing end is the end that changed, the found end the one not re-confirmed |
| both found nowhere | `re-confirm` |
| either found more than once | `ambiguous`, which takes precedence, because the check cannot tell which occurrence the row means |

- **A non-silent row's report names both ends**: each end's document, the heading the row records, and the
  headings its quote was found under, if any. A silent row prints nothing.
- **A folded spec is skipped, never clean.** Every link with a spec end is reported skipped and not
  examined; every link with both ends in the design is still examined and printed under its state. The run
  takes the findings exit when one of those is non-silent, and otherwise the could-not-run exit with the
  verdict word `skipped`, an absent record included. An unstaged or malformed record is still a
  could-not-run.
- **Outcomes.** `0` when the spec is not folded, the record is present and staged, and every link is
  silent; `1` when an examined link is `moved`, `re-confirm` or `ambiguous`; `2` when the check could not
  run, or the spec is folded and no examined link is non-silent. The verdict line names the record, or the
  record it found missing, and counts links per state, skipped included — read the counts, not only the
  exit status ([`${CLAUDE_PLUGIN_ROOT}/docs/gate-outcomes.md`](${CLAUDE_PLUGIN_ROOT}/docs/gate-outcomes.md#the-three-outcomes-this-page-defines)).

The check never edits either document. It has no write path, no acknowledge verb and no bulk form.

## When it runs

At the end of every pass that edits the pair after the design is first written and before the closing
fold:

| Pass | Site that runs it |
|---|---|
| Every write of the design author: Step 6's first write, each revision a review round sends back, each design amendment, each fold-in of design-review notes, and each direct correction an amendment that keeps the approach makes | [`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Rules](${CLAUDE_PLUGIN_ROOT}/agents/design.md#rules), beside the author's convergence exit check — a second call, read as a report and never part of the refusal |
| Every marking pass, the one inside an amendment that keeps the approach included | the exit-check paragraph of [`${CLAUDE_PLUGIN_ROOT}/docs/redline-marking.md`](${CLAUDE_PLUGIN_ROOT}/docs/redline-marking.md), after the pairing check and outside its clean-0 refusal |
| Every spec amendment, once the spec writer has applied it, in whichever workflow entered the recipe | the Spec Amendment recipe's step 4 on [`${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md`](${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md#spec-amendment-recipe-re-entrant--triggered-from-a-step-7-verdict) — the orchestrator's own call, whenever a design exists |

**The closing fold is the one such pass it does not cover**: the fold carries its own gates. A design
author's write after the fold — a direct correction on a plan whose fold already ran — still ends with it,
and on a folded spec it reports every spec-end link skipped. The design review does not run it, because the
review edits nothing and the design author's hand-back already carries the report of the write it reviews.

## Where a report leads

What follows depends on the state and, for a moved link, on where the unchanged end sits:

| State | Unchanged end | What follows |
|---|---|---|
| `moved` | design | The design author brings that end into line in its pass and rewrites the row. After a spec amendment that keeps the approach the design is past its GO, so that amendment's route takes the row instead: its design end is named to the whole-pair reader first, the orchestrator rules on it from its two quotes with the reader's finding as one input and the reader's silence as none, and a false end is marked and logged where the plan has a correction log, or corrected directly where it has none |
| `moved` | spec | Put to the human as a possible spec amendment. The spec changes only through a spec amendment the human approves, and is never narrowed to match the design |
| `moved`, the changed end's statement deleted with nothing in its place | either | The link no longer exists. Once the unchanged end is dealt with — a design end as the first row says, a spec end by the three cases below — the design author removes the row |
| `re-confirm` | — | The design author rewrites the row with the current quotes and fresh grounds, or removes it when the link no longer exists |
| `ambiguous` | — | The design author rewrites the row with quotes found once each |

- **Inside its own pass the design author acts on the report before handing back.** It runs the check at
  the end, acts, and runs it again, so the report it hands back is the one that leaves the pass. A moved
  row whose unchanged end is in the spec, its own edit having changed the design end, falls into one of
  three cases. The edit keeps what the end asserts — a rewording — and it rewrites the row with grounds
  saying so. The edit contradicts the spec statement and the design is wrong, and it fixes the design. Or
  the conflict is genuine, and it leaves the row standing and names it in its hand-back as a possible spec
  amendment. A rewording contradicts nothing, so only the last case reaches the human. It never edits the
  spec, and never rewrites a row while its two quotes disagree, except in the marking pass of an amendment
  that keeps the approach, where the grounds name the correction-log row that records the correction.
- **Its hand-back carries** the check's verdict line, each row it rewrote or removed and why, and each row
  it left non-silent with where it leads.
- **The orchestrator puts a possible spec amendment to the human through the Spec Amendment recipe.** A
  declared-link report naming one — in a design author's hand-back, or in the orchestrator's own run after
  an amendment — takes the recipe's remedy question as a genuine-conflict row does, in plain terms and the
  design complying first. The design complying returns to the design author's pass that raised it, as an
  ordinary iteration does; the requirement changing continues to the spec writer. Whichever the human
  picks, the design author's pass that follows rewrites the row.
- **The orchestrator's own run after an amendment is carried into the design author's next pass**: the
  Step 6 re-entry, when the amendment changes the approach or the entry was an iteration; the
  amendment's own pass, when it keeps the approach. A moved row between two spec statements, one of which
  the amendment changed, has its unchanged end in the spec and takes the remedy question above.
- **An ordinary marking pass moves no link**, because the comparison removes markers, so its report travels
  in its hand-back as it stood.

## Clearing a row

**Clearing is rewriting the row.** The check offers no act that clears a row while the documents still
differ from it. A non-silent row — moved, re-confirm or ambiguous — goes silent when the design author
rewrites it with its own current quotes and its own fresh grounds, the act visible in the record's diff, or
when the documents return to the text the row quotes; and a row whose link no longer exists is removed
rather than rewritten. Each rewrite and each removal is named in the hand-back with its reason.

**A row left non-silent is reported again at every later run**, which is the point: every state names who
acts, and whichever remedy the human picks for a possible spec amendment, the pass that follows rewrites
the row.
