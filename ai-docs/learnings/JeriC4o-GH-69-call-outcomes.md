# Learning Log — JeriC4o / GH-69-call-outcomes

### 2026-09-28 — architecture — a priority statement found a defect that months of building had not
**What happened:** The user rejected hook latency as the next task and said harness quality and catching
LOGICAL loops outrank it. Taking that literally — ranking by "which class of loop does this let us see" —
surfaced within minutes that the live detector dismissed the fix-break cycle at every round, and that
`scripts/session-events.sh` had encoded the correct answer all along (`error-retry-loop` deliberately
carries no intervening-edits filter). I had built three stages of a cascade without noticing that the
most common logical loop was excluded by one of its own qualifiers.
**Rule:** When a user restates the priority, re-rank the open work against it explicitly rather than just
reordering the list — the ranking criterion is a lens, and applying it to items already built is where it
pays. Concretely: "which class of X does this let us see" finds gaps that "what should I build next"
never asks about, because the second question presumes the existing coverage is sound.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — architecture — a qualifier copied without its scope inverts its meaning
**What happened:** The STATE qualifier — dismiss a repeat when an edit intervened — is correct and is
taken from the retrospective detector. I applied it to every signal. In the retrospective detector it is
attached to ONE signature (`repeated-tool-call`) and deliberately withheld from another
(`error-retry-loop`), because for a failing call an intervening edit means "an attempt was made and it
failed again" rather than "the question changed". Copying the qualifier without its scope reversed what
it does on the case that matters most.
**Rule:** When borrowing a qualifier from an existing detector, borrow its SCOPE with it — which signals
it attaches to and, more importantly, which it is withheld from. A filter list per signature is a design
statement, not an implementation detail: `filters: ["window"]` next to `filters: ["window",
"intervening-edits"]` is the author saying the difference is deliberate. Read the absence, not only the
presence.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — an embedded-name inventory drifted from 7 to 33 and weakened a gate
**What happened:** `docs/claude-tools-hierarchy.md` §3b listed 7 hook event names; the documentation
defines 33. That list is what `/ai-audit` Checklist O compares project-defined names against, so 26 names
were ones a clash check could never catch. Worse than a stale document: two of the missing entries
(`PostToolUse` / `PostToolUseFailure`) were the pair that makes a call outcome knowable, so the gap hid a
capability as well as a check.
**Rule:** A file whose job is to MIRROR an external surface decays silently and takes its consumer's
guarantee with it. When a checklist compares against an embedded inventory, re-derive the inventory from
the source before trusting a clean result — and prefer re-reading the source to reading the mirror
whenever the answer matters. A mirror is a cache; treat a cached answer to a design question as stale
until checked.
**Kind:** correction
**Escalated?** no

### 2026-09-28 — tooling — shape (4) of my own masking rule, in a probe for a different blind spot
**What happened:** Writing a probe for the fix-break fix, I set a variable inside a function invoked as
`out=$(fn)` and read it afterwards. Command substitution is a subshell, so the assignment was discarded
and the script died on `unbound variable`. That is masking shape (4), which I extended and documented in
`agents-method.md` two days ago.
**Rule:** Recurrence, and the failure was loud this time only because `set -u` was on — without it the
variable would have been empty and the probe would have reported a wrong result quietly. Two habits that
would prevent it: have the CALLER compute anything the caller needs to read back, and keep `set -u` in
every throwaway probe, where the temptation to skip it is highest and the cost of a silent empty is the
same as in shipped code.
**Kind:** correction
**Escalated?** no
