# Excused convergence findings: 2026-10-21-remove-statement-inventory.spec.md

Each row waives ONE finding of `check-plan-convergence.sh` for this plan and no other. Granted by
`check-plan-convergence.sh --excuse '<class>|<spot>|<subject>' --grounds '<why>'`, which prints the
finding before writing the row. Removed by deleting its row, which is an act of the same kind. The
format is `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` § The record of excused findings
(committed).

| Class | Spot | Subject | Grounds |
|---|---|---|---|
| isolation | spec | Two classes of change are from now on caught by the pull-request diff and by not | The spec amendment states this bound as ONE statement with two parts and AC11 requires it stated whole wherever this mechanism bounds are stated, so the repetition at scope item 9, AC11 and the key-decisions row is the criterion itself rather than drift. The three sites are byte-identical on the normalised text today; a one-sided edit falsifies AC11 rather than slipping through. The spec is written by its owning subagent and not by the designer, so collapsing a site is not a move available here. |
