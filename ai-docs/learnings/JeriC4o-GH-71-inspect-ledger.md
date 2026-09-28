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
