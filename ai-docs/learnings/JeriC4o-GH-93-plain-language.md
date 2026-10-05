# Learning Log — GH-93-plain-language

### 2026-10-06 — tooling — masked two gate results in one session, and found the guard's blind spot for the manifest gate
**What happened:** Running the structural checks for this branch, I masked two gates in a row. First
`jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json > /dev/null`,
reading only the exit status — I caught that one myself and re-ran it printing a per-file value. Then
`bash scripts/test-check-references.sh 2>&1 | tail -3`, which the `result-masking` hook blocked at
dispatch. This is a RECURRENCE: the first entry in `ai-docs/learnings/JeriC4o-main.md`, dated
2026-10-04, records piping a test suite into a pager while running this same gate list, and its rule
was "limit output with the tool's own flags, never with a pager". Two days later I did it again on the
first long suite of the next task.
**Rule:** The urge to mask arrives with LONG output, not with a particular command, so the guard has to
fire on the intent rather than on the spelling: the moment the thought is "I only need the last line",
the action is to redirect the gate to a FILE and then read the file — which is what the hook's own
refusal text prescribes and what I eventually did for the remaining twenty suites. Separately, and
worth more than my slip: the hook cannot see this class on the MANIFEST gate. Its gate pattern
enumerates `make|cargo|go|npm|pnpm|yarn|gradle|mvn|pytest|shellcheck|ruff|eslint|ktlint` plus
`bash <something>test|check|lint|verify<something>.sh`, and `AGENTS.md § Build & Test` names `jq -e .`
over the three manifests as structural check 1. A bare `jq` gate is in none of those alternations, so
discarding its output is invisible to the guard and the check is mine alone — exactly the "five shapes
no command-string guard can see" class the method file already warns about, with a sixth instance: a
gate whose COMMAND is not on the guard's list. The `git ls-files -z '*.sh' | xargs -0 -n1 bash -n`
gate is the same case — it is a pipeline by design, so its own rc is `xargs`', and the method file
documents that as the one form that propagates.
**Kind:** correction
**Escalated?** no
