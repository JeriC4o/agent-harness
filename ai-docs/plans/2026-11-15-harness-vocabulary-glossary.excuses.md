# Excused convergence findings: 2026-11-15-harness-vocabulary-glossary.spec.md

Each row waives ONE finding of `check-plan-convergence.sh` for this plan and no other. Granted by
`check-plan-convergence.sh --excuse '<class>|<spot>|<subject>' --grounds '<why>'`, which prints the
finding before writing the row. Removed by deleting its row, which is an act of the same kind. The
format is `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` § The record of excused findings
(committed).

| Class | Spot | Subject | Grounds |
|---|---|---|---|
| completeness | spec § Key decisions | Scope comes to about 42 by this spec's count | The spec's sentence reads 'the list under § Scope comes to about 42 by this spec's count': it points at the Scope heading, which the spec carries, and the check took the words after the heading as part of its name. The reference resolves; nothing in the plan is undelivered. |
