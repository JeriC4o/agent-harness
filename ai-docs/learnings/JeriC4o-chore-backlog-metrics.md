# Learning Log — JeriC4o / chore/backlog-metrics

### 2026-09-18 — tooling — a privacy constraint silently blocked the measurement it was written for
**What happened:** `session-events.sh` emitted only the first token of a Bash command, so `gh issue create`
and `gh pr view` were both just `gh`. When the need arose to count tickets filed mid-task, the constraint
made it impossible — and nothing in the design said so; the label simply looked adequate. The fix was an
allowlist of known subcommand verbs rather than a looser pattern, because a branch name matches any
reasonable pattern and a branch name can carry a project identifier.
**Rule:** When a redaction rule drops a field, record what questions it makes unanswerable. A constraint
that quietly removes future measurements is discovered late, at the moment the answer is needed, and the
pressure then is to loosen it hastily rather than widen it precisely.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — tooling — a text-slice patch duplicated a block instead of replacing it
**What happened:** A python patch replaced the span from `def bin_of:` to `def is_human_turn:`, assuming
that order. In the file `bin_of` came LAST, so the slice ran backwards: the old definitions were duplicated
and the stale `bin_of` shadowed the new one. `bash -n` passed, jq compiled, and five tests failed with no
hint at the cause — the symptom was a correct new definition that never ran.
**Rule:** Before replacing a span between two anchors, assert the anchors are in the expected ORDER
(`start < end`), not merely that both exist. A backwards slice silently duplicates rather than failing, and
in a language where the last definition wins, the duplicate is invisible until behaviour contradicts the
source.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — process — a negative result is evidence the detector works
**What happened:** `deferral-candidate` found nothing in either real session, and `backlog-metrics` reported
a drip share of 0 with all five tickets filed in one planning pass. The temptation was to read zero findings
as an unfinished detector. Both halves agreeing on a negative is the first evidence that the
deferral/discovery separator actually separates rather than merely sounding plausible.
**Rule:** When building a detector, state what the healthy case should look like BEFORE running it, then
report the negative result as a result. A detector that has only ever been seen firing has not been shown
to discriminate.
**Kind:** validation
**Escalated?** no
