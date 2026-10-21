# Excused convergence findings: 2026-10-21-check-redline-stale-ref.spec.md

Each row waives ONE finding of `check-plan-convergence.sh` for this plan and no other. Granted by
`check-plan-convergence.sh --excuse '<class>|<spot>|<subject>' --grounds '<why>'`, which prints the
finding before writing the row. Removed by deleting its row, which is an act of the same kind. The
format is `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` § The record of excused findings
(committed).

| Class | Spot | Subject | Grounds |
|---|---|---|---|
| isolation | spec | 0 | The digit is an exit status in the convention both checks already ship (0 clean, 1 findings, 2 cannot run), stated once in Key decisions; every other site cites that same contract, so there is no independent figure to drift. |
| isolation | spec | 1 | The digit is an exit status in the convention both checks already ship (0 clean, 1 findings, 2 cannot run), stated once in Key decisions; the other sites cite that same contract or quote the ticket verbatim, so there is no independent figure to drift. |
| isolation | spec | 2 | The digit is an exit status in the convention both checks already ship (0 clean, 1 findings, 2 cannot run), stated once in Key decisions; the other sites cite that same contract or quote the ticket verbatim, so there is no independent figure to drift. |
