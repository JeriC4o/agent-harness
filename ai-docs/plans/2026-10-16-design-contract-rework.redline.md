# Redline log: Design contract rework — what a plan document must carry, and what checks it

**Tracked in:** GH-128
**Spec:** ai-docs/plans/2026-10-16-design-contract-rework.spec.md
**Design:** ai-docs/plans/2026-10-16-design-contract-rework.design.md
**Mode:** R&D — the base says of itself that it is incomplete: it ships a non-empty
`## Open questions` and its `## Risks` section carries figures the design itself marks as owed a
re-derivation before anything is built on them. The author chose this mode for the whole task on the
first implementation-found divergence, so a correction or an extension goes into this log as it is found,
nothing restarts, and the closing fold is where the design becomes true again.

## Rows

| Key | Type | Artefact sentence diverged from | What shipped instead |
|---|---|---|---|
| S8.1 | added | `ai-docs/plans/2026-10-16-design-contract-rework.design.md:630` — the Files column of decomposition row 2, which names seven paths: "`docs/agents-method.md`, `docs/test-conventions.md` *(new)*, `docs/code-style.md`, `agents/self-review.md`, `agents/spec-writer.md`, `skills/bugfix/SKILL.md`, `scripts/check-references.sh`" | Nine files changed, not seven. Two the base was silent about had to move because each pins a count the subtask falsified: `scripts/test-check-plan-invariants.sh`, which pins the corpus markdown-file count in **four** separate spellings — the comment heading naming the property, a prose sentence reasoning about the miscount, the assertion's label, and the assertion's expected value — and `scripts/check-plan-invariants.py`, which states the same count **twice** in comments defending the re-wrap-stability property. The new reference page moved the real count from 53 to 54 and the suite failed on exactly that pinned assertion; subtask 3 added a second page and moved the same six spellings again, to 55. The suite failure was **the gate working as intended and not a defect** — a stated count falsified by the same change that states it, which is this task's own subject met in its own tree. |

## What this row does and does not claim

- **The failure was the mechanism working.** The suite's pinned assertion is there precisely so that a
  change to the corpus cannot move the count silently. It fired. Nothing about this divergence is a
  defect in the suite, in the payload, or in the subtask; the design's file list was simply short by the
  two files that hold the figure the subtask moved.
- **Both off-list files are verified at the current count.** All six spellings read 55, and
  `bash scripts/test-check-plan-invariants.sh` reports **265 passed, 0 failed**, rc 0. The two comment
  spellings in the payload were confirmed against the diff rather than inferred, and so were the four in
  the suite.
- **The count 53 still appears in the payload and is correctly untouched.** It states a different figure
  there — the shell-spelling share of the corpus, not its markdown share — which is the hazard the design
  names as "a sweep keyed on one spelling misses a third of its subject", met in the field: the superseded
  value and a live unrelated value are the same token.
- **One thing reported as a divergence is NOT one and deliberately has no row.** The extracted
  `## Test Conventions` heading stays on the session-start page as an anchored pointer. Row 2 of the
  decomposition asks in its own words for the extraction to leave "one anchored pointer" and to "keep the
  heading text identical", so the retained heading is compliance with the row rather than a departure
  from it. A row here for a non-divergence would be worse than a missing one, because the closing fold's
  cost is meant to be proportional to the number of rows.

## Not in this log, and where it went instead

**The amendment adding subtask 16** — closing the edit-time guard's blindness to a separator character
used inside a quoted span of the command — is scope the author approved, so it amends the design rather
than appearing here. A changed requirement goes to the spec, a changed artefact comes to this log, and
new scope the author approves goes to the design; nothing is recorded in two of the three.

**The corrected instruction-file sizes** fold into the design for the same reason: they are planning
inputs that a later subtask acts on, not a record of shipped work departing from the plan. The design now
carries the freeze reading and the current reading side by side, each with its provenance, and the
obligations below them are stated against the current one.
