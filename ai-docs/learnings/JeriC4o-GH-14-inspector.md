# Learning Log — JeriC4o / GH-14-inspector

### 2026-09-18 — tooling — an apostrophe inside a single-quoted shell string closed it, again
**What happened:** A jq program embedded in `scripts/session-events.sh` carried the comment "cannot see the
row's own bounds". The apostrophe closed the single-quoted shell string and `bash -n` failed on a line 70
lines away, pointing at jq syntax rather than the real cause. This is the third recurrence of the same
hazard in this repo — `rules/ast-index.md` already documents it, and a SessionStart hook broke on
"project's" earlier in this same build-out.
**Rule:** When writing a heredoc or single-quoted program that embeds another language, assert the
interior is apostrophe-free BEFORE running it — a one-line check in the generating script beats reading a
misleading syntax error. Prefer "the bounds of the row" over "the row's bounds" in any comment destined
for a single-quoted block.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — tooling — a privacy invariant held in theory and leaked in practice
**What happened:** `session-events.sh` was designed to emit only the first token of a Bash command, on the
reasoning that "git" is the same risk class as the command table in AGENTS.md. Running it on a real
transcript put `SP=/private/tmp/.../scratchpad;` into the label column: a command beginning with a variable
assignment makes the first token a path. The fixture tests all passed; only real output showed it.
**Rule:** A privacy invariant is not established by the rule that implements it — probe the real output for
the class of thing that must never appear (paths, `=`, absolute prefixes) and assert the count is zero.
Fixtures test the cases you thought of; the corpus contains the ones you did not.
**Kind:** correction
**Escalated?** no

### 2026-09-18 — process — a proxy named in a ticket is a hypothesis, not a specification
**What happened:** GH-14 specified cache_read spikes as the proxy for "the agent re-read the same context".
Measured, cache_read trends upward all session (early ~100k, late ~14M), so a whole-session median flagged
one turn in five — noise. Per-message normalisation flattened it until nothing was an outlier. Messages per
turn separated cleanly (median 5, max 75) and shipped instead. The same thing happened in GH-13, where two
stage-attribution models both failed on contact with real sessions.
**Rule:** When a ticket names a metric or proxy, measure its distribution on real data before building the
reporting on it. Both times the falsification cost one ad-hoc `jq` and arrived before anything was public;
both times the specified proxy would have shipped a check that cries wolf.
**Kind:** validation
**Escalated?** no

### 2026-09-18 — tooling — a qualifier that exists in the design but not in one code path
**What happened:** Every repetition signature was designed to carry a time window. `repeated-agent-spawn`
computed `span_seconds` and never filtered on it. The fixture happened to place its three spawns 140s
apart, inside the window, so the suite was green; a real session then reported twelve `general-purpose`
spawns spread over a working day as a loop.
**Rule:** When a qualifier applies to a FAMILY of checks, write the negative test for each member, not for
one representative. A computed-but-unused value is the specific shape to look for: it reads as applied at
a glance and is not.
**Kind:** correction
**Escalated?** no
