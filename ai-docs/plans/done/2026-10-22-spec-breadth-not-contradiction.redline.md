# Redline log: A spec broader than its design is not a contradiction

**Tracked in:** GH-146
**Spec:** ai-docs/plans/2026-10-22-spec-breadth-not-contradiction.spec.md
**Design:** ai-docs/plans/2026-10-22-spec-breadth-not-contradiction.design.md
**Mode:** Hybrid — recorded by default, no mode having been chosen before the first divergence; the design's `## Open questions` reads "None." and the work changes mechanisms whose shape is already known.

| Key | Type | Artefact sentence diverged from | What shipped instead |
|---|---|---|---|
| R1.1 | modified | `ai-docs/plans/2026-10-22-spec-breadth-not-contradiction.design.md` § The planted control — "Its requirements-half sentence is general: a run that cannot read one of its inputs says so, and that run is not a pass." | the breadth control is replanted in the second-case shape (one spec sentence literally rules the change out, another spec sentence requires it, the design states the departure among its risks), and the fixture no longer explains the expected answer |
| R2.1 | modified | `ai-docs/plans/2026-10-22-spec-breadth-not-contradiction.design.md` § The plan-convergence reader, item "The report template and the "never do" list" — "The report template and the "never do" list gain the breadth-control line and the notes heading, and a report without the breadth-control line is incomplete in the same way one without the coverage line is." | the notes heading and its line shape are stated once, in the boundary section, not in the report template or the never-do list; `agents/plan-convergence.md` places the notes after `unchecked` under the heading `notes — breadth, not findings`, one line each, while the breadth-control line is still carried by the report template and the never-do list as designed |
