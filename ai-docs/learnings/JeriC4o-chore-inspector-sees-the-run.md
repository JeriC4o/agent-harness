# Learning Log — chore/inspector-sees-the-run

### 2026-09-26 — process — a review cap that counts rounds cannot stop a loop that is not about the code
**What happened:** In one `/task` run the design-review loop took 4 rounds over 59 minutes and the
self-review loop burned all 3 of its rounds, ending on a REJECT whose `major` was a green-reporting gate
introduced by the previous round's own fix. The four post-cap fixes then reached commit with no review
round at all. Mid-run the agent diagnosed it itself — "the code converged long ago; the document is
looping" — measured a 113,677-byte design against a 1,049-line implementation on an increment the user
had scoped as one increment, and observed that the last two and a half rounds changed "neither the code,
nor the verdict, nor a single claim". It then had to invent a stopping rule on the spot and ask the user
for permission to depart from the recipe.
**Rule:** A review loop's exit condition must read what a round FOUND, not only how many rounds have run.
State, at the cap site, what makes another round worth spending — a new `major` / blocker against code, or
against a claim that is actually false — and say explicitly that a round returning only prose-consistency
findings about a design document is fixed as text without re-entering review. State separately that fixes
made after the cap is burned still get one review pass, as post-push fixes already do.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — step-regression flags the workflow's own loop-back, and fires on the APPROVE that ends it
**What happened:** The session's only step-regression, 11 → 10, was the progress write
`**current_step:** Step 10 — self-review APPROVE (Round 3)` — the success path terminating the loop.
`skills/task/SKILL.md:157` and `:186` mandate that exact edge on every REJECT round, so the row is emitted
by every `/task` run that takes any review round, and again on the APPROVE that ends it.
`scripts/session-events.sh:328` compares step numbers with no exception, and `agents/inspector.md:68`
pushes the whole judgement onto the reader with no marker to read.
**Rule:** A detector must not report a transition its own workflow prescribes. Either exclude the
documented Step 11 → Step 10 edge, or carry the progress line's own text on the row so the reader can
separate a REJECT loop-back and a terminating APPROVE from a genuine skip without re-opening the
transcript.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — the spawn window admits fan-outs and excludes the re-entries it exists to catch
**What happened:** `agents/inspector.md:64` says spawns seconds apart are a fan-out to dismiss and spawns
minutes apart are re-entries to confirm. `scripts/session-events.sh:267-273` bins Agent spawns through a
600-second sliding window, which cannot hold a burst wider than ~10 minutes — so the confirm case is
structurally excluded. Measured: a 5-spawn design loop with four ITERATE rounds, spread 17:37 to 18:36
with gaps of 11 to 18 minutes, produced zero rows; the two rows that did fire were a 4-spawn fan-out 12
seconds wide and a 425-second burst. Both the qualifier and the shared window default were written in the
same session, the window deliberately left shared on the reasoning that a second knob was not worth it.
**Rule:** When a qualifier names the time gap as the thing that separates confirm from dismiss, the
detector must not use that same gap as its admission filter. Group repeated spawns of one
`subagent_type` over the whole session or the turn, report the gap distribution, and let the qualifier do
the separating. More generally: after adding a qualifier, check what the admission filter lets reach it.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — a subagent hand-back opens a counted turn, so a delegating deep turn is split below the spike threshold
**What happened:** `scripts/session-events.sh:121-126` counts any user-string entry not prefixed
`task-notification`, `local-command-` or `system-reminder`. On one session 22 of the 91 reported turns
were not human turns: 14 inbound subagent hand-backs, 6 terminal-echo entries, 2 compaction entries. A
subagent result arriving as a task-notification is excluded while the same result arriving as an
inter-session hand-back opens a turn. One instruction whose work ran 27 minutes across 3 design spawns
was chopped into five counted turns by four hand-backs and none was flagged, while a comparable stretch
whose subagents returned as task-notifications was flagged at factor 5.
**Rule:** A turn boundary is a HUMAN instruction. Exclude inbound agent-to-agent messages, terminal-echo
entries and compaction blocks from the turn count the same way task-notifications are already excluded,
so that delegating and non-delegating work of equal size are measured alike.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — tooling — deferral-candidate misses a ticket drafted in the deep turn and filed in the next
**What happened:** `scripts/session-events.sh:313-314` requires the `gh issue create` call itself to land
in a spike turn. On one session two issue bodies were drafted as the final two actions of the deepest
turn in the run, immediately after a review round, and the create calls executed in the following,
ordinary turn. The detector reported nothing. This is the same shape as the self-comparison bug fixed at
line 316 in that session, one step narrower.
**Rule:** A deferral is decided where it is drafted, not where the command runs. Attribute a ticket to
the turn that produced its body, or widen the window to the turn immediately following a spike, so that
the cheap exit is visible wherever the two steps are split.
**Kind:** correction
**Escalated?** no
