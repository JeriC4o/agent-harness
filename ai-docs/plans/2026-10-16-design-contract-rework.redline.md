# Redline log: Design contract rework — what a plan document must carry, and what checks it

**Tracked in:** GH-128
**Spec:** ai-docs/plans/2026-10-16-design-contract-rework.spec.md
**Design:** ai-docs/plans/2026-10-16-design-contract-rework.design.md

**Mode:** R&D — chosen by the author for the WHOLE task on the first implementation-found divergence, and
carried across the re-authoring because the mode was never the document's to decide. The grounds are
restated against the base now in force rather than kept from the one it replaced: the base still says of
itself that it is incomplete, carrying a non-empty `## Open questions` and a `## Risks` section whose
mitigations name work that does not exist yet. What has changed is the KIND of incompleteness, and the
change strengthens the mode rather than weakening it — each open question now passes the test the new
principle states, so none of them can move the approach, the requirements or the decomposition, which is
exactly the condition under which a correction belongs in this log instead of restarting the cycle. So a
correction or an extension goes into this log as it is found, nothing restarts, and the closing fold is
where the design becomes true again.

## Rows

| Key | Type | Artefact sentence diverged from | What shipped instead |
|---|---|---|---|
| S8.1 | modified | § Decision 8 of the design, the paragraph opening **This is a seventh silent form against a header that enumerates six**, whose closing claim is: "Closing the hole makes that sentence true rather than changing what it claims" | The repair shipped exactly as that section specifies, the ruled-out direction and the paired-silent-case requirement included — and the header's sentence did not become true. It now opens with SEVEN silent forms and enumerates seven. The new member is a form the prediction could not have reached: a separator the shell would not treat as one because a backslash escapes it, OUTSIDE any quoted span. It was found by looking for a residual, measured silent both before and after the repair with its paired read silent in both, and the guard's own verification now asserts it silent as the seventh item beside its six siblings. So the quoted-span hole is closed as designed and the stated count is still falsified by the thing it counts, by a different member. Closing the escaped form is left to the author: the row's boundary sentence is "a separator that sits inside a quoted span", three parties reached that boundary by measurement, and widening a repair past its authorisation is not the implementer's call |

**One row.** The log was empty by construction after the reset rather than by omission — see below — and
this is the first divergence recorded against the base now in force.

## Why this log was reset, and what the reset cost

The design was **re-authored from scratch** rather than amended, so the document the previous row
diverged from no longer exists. A row records a departure from a frozen base; when the base is replaced,
a row against the old one names nothing, and the pairing gate said so in those terms — it reported
`pairs=0` with the row carrying no marker in the design, run before the reset rather than inferred.

**The reset cost nothing, and the reason is that the row's SUBJECT is gone rather than that the new base
restates it.** The row recorded that a decomposition row named seven files where nine changed, because two
files outside that row's list pin a count the subtask falsified. That subtask is not in the current plan
at all: the work shipped, and the base authored after it plans only what is left. So there is no row left
for the divergence to be a departure from.

**What is NOT claimed here, because it would be false.** The two off-list files were a verification suite
and a verification payload, and naming a suite in a design is now forbidden outright, so the current base
could not close that gap by listing them even if the subtask were still in the plan. The base records that
limit in its own terms instead, and the repository's own derived-suite comparison is what makes such a
path land. Version control holds the superseded log in full, so nothing about the earlier round is lost
— only its standing as an open correction is.

**One side effect worth naming:** the superseded row addressed its target by an ordinal within the design.
That form is now forbidden outright, and the spec states the prohibition generally rather than only for
plan documents. So the reset removes an instance of this task's own subject from this task's own
artefacts, by replacement rather than by a sweep.
