# Learning Log — JeriC4o / GH-71-inspect-ledger

### 2026-09-28 — tooling — a suite that reads the ambient environment is not a gate
**What happened:** `hooks/lib/test-loop-verdict.sh` asserted that the judging stage stays quiet by
relying on `HARNESS_T3_MODEL` being ABSENT from the environment. That held on a machine where the
cascade had never been switched on, and stopped holding the moment it was enabled in
`~/.claude/settings.json`. The suite then reported two failures in the section about the COARSE gate —
which says nothing about a model — so the red was about a setting and pointed at the wrong code. It had
been green for days on the machine that wrote it.
**Rule:** A suite pins every environment variable its assertions depend on, at the top, explicitly.
Pinning alone would then hide a change to the shipped default, so the default gets ONE dedicated
assertion with the variable genuinely removed (`env -u`), plus a positive control that sets it and
requires the assertion to invert. Inheriting a variable is not "testing the default" — it is testing the
developer.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — a join key has to be measured before it is written into a contract
**What happened:** The plan was for `/inspect` to match ledger rows to transcript entries by
fingerprint, since both compute the same djb2 over the tool input. Measured on a real session first:
43 of 45 agreed and 2 did not, and the two were `Agent` and `AskUserQuestion` — tools whose input the
client rewrites between the hook firing and the transcript record. By `tool_use_id` the match was 45 of
45. A fingerprint join would have been wrong on exactly the tool a fan-out question is about, and every
row it produced would have looked ordinary.
**Rule:** Before writing a join into a contract, run it over real data and count the disagreements. Two
derivations of "the same" value from two sources agree until they meet the case where the sources
differ, and that case is never the common one — which is why it survives every casual check.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — a field that is described but never read back stays wrong indefinitely
**What happened:** `hooks/lib/loop-index.sh` derives `agent_id` from `transcript_path`, and
`docs/claude-tools-hierarchy.md` described the fan-out case it enables at length. Across all 1100 call
rows in all five ledgers on this machine the field reads `main` — without exception, including in
sessions whose subagents made hundreds of calls. The `PreToolUse` payload carries the PARENT transcript
path even for a subagent's call, so the derivation cannot produce anything else. The fan-out arm has
never fired, the stored `transcript` pointer names a file that does not contain that `tool_use_id`, and
tier 3 opens that wrong file to collect its evidence and judges on what is left. Three consequences, no
symptom: every failure path is silent by design.
**Rule:** A field written by a hook and read by nothing is unverified, however carefully the doc
describes it. Ship the reader in the same change as the writer, or record the field as unverified until
one exists. "Detail is one join away" is a claim about a join nobody has performed.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — process — two numbers under one word, from two scopes
**What happened:** `session-events.sh --signatures` reported 45 tool calls and 4 turns for a session
whose ledger held 70 calls and 12 turn markers. Neither is wrong: the signatures pass reads one
transcript file while the ledger records every call in the session including those made inside spawned
agents, whose transcripts live in a directory it never opens — and "turn" means a prompt on one side and
a stop event on the other. Read as a discrepancy, this invites reconciling two correct numbers.
**Rule:** When two passes report the same word, state their SCOPE and their UNIT beside the figures
before either is compared. A count is not comparable to another count merely because both are counts of
things with the same name.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — the input a derivation depends on was never checked for existence
**What happened:** `loop-metrics.sh --for` takes a transcript path and attributes every ledger call by
finding its `tool_use_id` in that file. Nothing checked the file was there. `self-review` ran it against
a wrong directory: call counts, turn counts, verdict counts and outcomes all correct, and the per-agent
census 100% wrong — every call in `unattributed`, under a bracketed gloss saying a live session has one
call in flight. So the corruption arrived with a benign explanation attached, and the one reader placed
to notice it had been told in `agents/inspector.md` to dismiss exactly that symptom. The flag that would
have exposed it, `main_transcript_read`, was computed and reached the JSON but was printed nowhere and
named in no instruction file. Realistic triggers are dull: a mistyped path, or a pruned transcript
beside a ledger directory that has no retention policy.
**Rule:** When one figure is a LOOKUP into an external file and its neighbours are not, the file's
absence produces a report that is entirely right except for that figure — the shape least likely to be
questioned. Check the input exists and stop; and never offer a benign explanation for a symptom
unconditionally, because the same symptom is what total failure looks like. A computed degradation flag
that no output prints and no reader is told about does not count as having handled the case.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — the apostrophe inside a single-quoted jq program, again
**What happened:** Writing the new report lines I put `the session's main transcript` inside a
single-quoted jq program. The quote closed the string, the shell re-parsed the remainder, and `bash -n`
reported a syntax error on a line seven lines below the real one. Then the first fix removed a different
apostrophe and the file still would not parse, so the same failure cost two rounds. This is the third
occurrence in this repo, and there is already a `sh-syntax-check` `PostToolUse` hook for it.
**Rule:** After any edit that adds English prose inside a single-quoted region — jq, awk, perl — run
`bash -n` on the file before anything else, and when it reports an error, grep the whole added region for
`'` rather than fixing the first apostrophe seen. The reported line is downstream of the real one, so
reading it as the location is what turns one mistake into two rounds.
**Kind:** correction
**Escalated?** no
