# Tier 1 — count the window in calls, make the dismissal monotonic, cover the calibration, and plant the attribution canary

**Source:** tickets GH-86 (three defects, one struck by its own thread) + GH-88 (coverage that can falsify the calibration)
**Date:** 2026-10-05
**Tracked in:** GH-86, GH-88

> **Joint scope by user decision, 2026-10-05.** GH-88 is not a follow-up here: its variation grid and
> frozen-corpus replay are the *executable form* of GH-86's own acceptance bullets, and GH-88 says so
> itself — "the grid below is also the regression test that keeps #86's repairs from silently
> reverting", and "the monotonicity property **fails today**, so it is the executable form of #86's
> defect 2". One change, one PR.

> **Repair, not retirement.** Tier 1 is the only stage that can speak to the agent at dispatch, before
> the call is paid for. Nothing below removes the stage, lowers it to reporting-only, or turns the
> cascade off. Both tickets open with that carve-out; it is restated here because every decision in this
> spec was taken under it.

## The problem, in one paragraph

Tier 1 (`hooks/lib/loop-index.sh`) has fired **zero times** across the recorded corpus; every verdict
ever written is tier 2 or tier 3. That is not evidence the corpus is loop-free. Two defects, each alone
sufficient to keep the stage silent, are measured and live on the current working tree; a third was
struck by the ticket author's own final comment. Meanwhile the suite that covers tier 1 is green, and
every fixture in it is synthetic and built to fire. A suite whose fixtures all fire measures the
implementation, not the settings.

## Corpus figures — re-derived 2026-10-05, and they have moved

The tickets cite **11 ledgers / 6085 calls**. Measured today over `~/.claude/harness/loops/`:

| | Ticket | Measured — floor as of 2026-10-05, still rising |
|---|---|---|
| Ledgers | 11 | **≥13** |
| `kind:"call"` rows | 6085 | **≥9097** |
| Ledgers written by the post-`4c1cd0a` build (`agent_type: "-"`) | 1 (`e330fc3e`) | **≥3** — `e330fc3e`, `c9baa003` and `022331b5` at this date |
| Distinct non-`main` `agent_id`s recorded | 1 | **≥13** — 5 in `e330fc3e`, ≥8 in `c9baa003` |

**Every cell in the right-hand column is a FLOOR, not a count.** It was re-measured twice during this
spec's own amendment rounds and rose both times, because the sessions that work on this spec are
themselves recorded. Read `≥` as load-bearing: a later reader who diffs a bare number here against a
live measurement will find it wrong, and that is the corpus moving, not the spec being incorrect.

Any figure a gate or an AC bakes in must be re-derived at implementation time, not copied from here or
from the tickets: the corpus is live and grew by a third between the ticket and this spec.

## Defects in scope — re-derived against the working tree at HEAD `6bf33c8`

Every anchor below was produced by `grep -n` on this working tree. **Three anchors the round-1 brief
carried are corrected here**: agent identity is read at `:91-92`, not `:85-86`.

### Defect 1 — the window is counted in ledger LINES, and the agent is told they are steps

- `hooks/lib/loop-index.sh:64` — `TAIL_N="${HARNESS_LOOP_TAIL:-20}"`
- `hooks/lib/loop-index.sh:123` — `verdict=$(tail -n "$TAIL_N" "$ledger" … | awk \`

The window is 20 **lines of the ledger**. Four row classes share that file: `kind:"call"`
(`loop-index.sh`), `kind:"result"` (`loop-result.sh`, on `PostToolUse` / `PostToolUseFailure`),
`kind:"turn"` and `kind:"verdict"` (`loop-verdict.sh:61`, `:97`, `:170` and `loop-index.sh`'s own
verdict write).

**Measured lines-per-call, per ledger — as of 2026-10-05; the per-ledger call counts have since
risen, while the ~2× spread that makes the point has not:**

| Ledger (prefix) | lines | calls | lines/call |
|---|---|---|---|
| `5e9a66de` | 4608 | 1947 | 2.37 |
| `1134d210` | 2494 | 1072 | 2.33 |
| `f6bad54c` | 2010 | 868 | 2.32 |
| `44f957de` | 3999 | 1728 | 2.31 |
| `e52c854e` | 2070 | 908 | 2.28 |
| `c9baa003` | 186 | 83 | 2.24 |
| `e330fc3e` | 1383 | 626 | 2.21 |
| `10b20947` | 49 | 25 | 1.96 |
| `74da1c95` | 1054 | 1017 | **1.04** |
| **corpus** | **17863** | **8281** | **2.16** |

So `HARNESS_LOOP_TAIL=20` reaches **8–9 calls** in a current ledger — and **~19** in `74da1c95`, written
before outcome recording was wired. The window is not merely halved; **its reach varies about two-fold
between sessions and nothing in the code ties the constant to the rows-per-call it assumes.** That
instability, not the halving, is the sharpest form of the defect, and it is why a fixed multiplier is an
unsafe repair (OQ4).

The agent-facing messages interpolate that same `TAIL_N` into the phrase "in the last %s **steps**":
`:195` / `:196` (error-retry), `:198` / `:199` (fanout), `:201` / `:202` (loop). The number the agent is
shown as a step count is a line count. The same conflation is shipped in prose at
`docs/claude-tools-hierarchy.md:101` — "has already run within the last ~20 **steps**".

### Defect 2 — the dismissal is non-monotonic, so a wider window sees LESS

- `hooks/lib/loop-index.sh:183` — `if (changed > first) exit`
- `first` is set at `:156` to `NR` of the **earliest** matching call inside the window; `changed` at
  `:154` to `NR` of the last `Edit`/`Write`/`NotebookEdit`.

Widen the window and `first` moves *back*, so any mutation after that older match silences every later
cluster. The ticket's replay measured, in ledger lines: **20 → 0 firings, 40 → 2, 100 → 3, unbounded →
0.** The one tuning knob the detector exposes behaves in the opposite direction from the operator's
intent, and "turn it all the way up" is the setting that sees the least.

**Blast radius, measured and narrower than it looks:** `if (fails + 0 >= retry)` at `:179` returns
before `:183` is reached. Defect 2 therefore corrupts the `loop` and `fanout` arms **only**;
`error-retry` is unaffected. No AC or grid axis may claim otherwise.

## Defect 3 — struck, and why it is recorded here rather than omitted

GH-86's body carried a third defect (distinct agents collapse to `agent_id: "main"`, making the
`na > 1 ? "fanout" : "loop"` arm at `:184` unreachable). Its **third thread comment strikes it**, after
a correction cycle worth preserving so it is not re-derived:

1. First comment: declared defect 3 live, citing two post-#74 sessions recording 139 and 426 calls all
   as `main`.
2. Second comment: corrected itself — `agent_type: null` versus `"-"` identifies *which build wrote the
   row*; both cited sessions ran an installed plugin older than `4c1cd0a`, because the install cache is
   version-keyed and only moves on `claude plugin update`. Stale-session artefact, not a live defect.
3. Third comment: settled it positively, with one subagent recording a real `agent_id`, its
   `agent_type`, and the subagent's **own** transcript.

**The evidence is now far stronger than the ticket's.** Re-measured 2026-10-05, `e330fc3e` holds five
distinct non-`main` ids (4 × `harness:self-review`, 1 × `general-purpose`) over 626 calls, and
`c9baa003` — this work's own session, so a floor that rises while the ticket is open — held ≥8 over
≥899. Attribution works on the current build.

**But the `fanout` arm has still never fired on real current-build data — zero tier-1 verdicts across
the whole corpus, re-confirmed 2026-10-05 — and the reason is not attribution.** When this spec was
first written the reason was that **no fingerprint family of ≥3 rows spanned more than one agent in any
post-`4c1cd0a` ledger**; the only multi-agent families were pairs at n=2, and in `c9baa003` they sat
outside any 20-call window. **That is no longer true, and the sentence did not become wrong — the corpus
moved under it.** `c9baa003` is this work's own session: it keeps accumulating subagent traffic because
the task spawns subagents, and it now carries **several** fingerprint families of ≥3 `kind:"call"` rows
spanning more than one `agent_id`. The arm's plumbing is proven and the material for calibration now
exists; its **bar** is nonetheless still unmeasured against a real firing, because no firing has
happened. Figures live once, in `ai-docs/context.md`'s GH-72 entry (currently `:119-139`); they are not
copied here, and calibrating the bar stays out of scope — see § Out of scope item 2.

**One fingerprint links the two observations.** `fp 3562779350` is `Read` of `docs/agents-method.md` —
the file the method tells every subagent to read. It is the fingerprint of GH-86's five-subagent cluster
in `44f957de` *and* of `c9baa003`'s largest multi-agent family, which has grown from a pair into the
widest family in that ledger. More generally, **the largest multi-agent families are `Read`s** — the
shape to keep in mind, and the one claim here that has held at every re-measurement. **The detector's
most likely first real
fanout firing is subagents obeying the method file's own instruction**, which is structural, not a
defect. See Scope 3b.

## Scope

1. **Count the window in calls.** Take the tail over `kind:"call"` rows rather than raw ledger lines, so
   `HARNESS_LOOP_TAIL` means calls and the agent-facing "steps" wording is true as written.
2. **Make the dismissal monotonic.** Re-anchor the STATE test on the span actually being counted — the
   ticket's own suggestion is "require no mutation between the most recent matches rather than after the
   oldest one" — so that widening the window can only add firings, never remove them. The qualifier is
   *re-anchored*, not removed.
3. **Correct the agent-facing unit everywhere it is stated.** The three `why` strings at `:195` / `:198`
   / `:201`, and `docs/claude-tools-hierarchy.md:101`'s "~20 steps".
3b. **Make the `fanout` advice actionable.** All three arms emit the same `permissionDecision: "ask"`
   plus the same stderr line (`:226-227`) — `fanout` is **not** a quieter signal; it interrupts the call
   exactly as `loop` does, and only the wording at `:198` differs. Today that wording is "check whether
   one result can be reused", which the reader of the message — a sibling subagent in its own
   context — cannot act on: it has no handle on another agent's result. Since Scope 1 makes a
   startup-read fan-out materially more likely to land inside one window, the fanout advice must name an
   action available to the agent it is shown to. Wording only; the arm's threshold and decision do not
   move.
4. **GH-88 Deliverable 1 — a pseudo-loop variation grid.** Every axis gets a must-fire case *and* the
   near-miss that must stay silent; output is a confusion matrix per axis; the suite fails on a
   regression in precision **or** in recall. Plus the three properties: monotonicity, idempotence, and
   "a verdict row never counts itself".
5. **GH-88 Deliverable 2 — a frozen-corpus replay gate, in TWO fixtures** (per the user's Q2 decision):
   a **real** leg and a **repaired** leg. See § Frozen corpus below.
6. **Update the GH-72 open question** in `ai-docs/context.md` (the GH-72 bullet — re-derive its line
   span before editing; it was `:119-139` at the time of writing). It already reads "Its bar, `na > 1`,
   … has never been measured against a real firing" — round 1's plan to narrow it was based on a stale
   reading and is dropped. **The disposition it records does not change: the bar stays uncalibrated and
   the question stays open.** What it must gain is the reason WHY it stays open, which has flipped —
   from "there is nothing to measure" to "there is something to measure, and measuring it is a different
   ticket":
   - the arm is reachable on the current build (non-`main` ids are recorded across multiple ledgers);
   - fingerprint families of ≥3 call rows that span more than one agent **now exist**, so the earlier
     "none in the corpus" basis is retired;
   - the largest such families are `Read`s, the widest being `docs/agents-method.md` — a subagent
     obeying an instruction file, which is genuine duplication and also the cheapest kind, so a bar
     tuned on it may be tuned on the one fan-out nobody wants flagged;
   - the canary of Scope 8 is what would make a REGRESSION visible.

   **Write the figures with an as-of date or a `≥`, never as a bare count** — the corpus grows whenever
   anyone works on this ticket. **Check what the entry already says before editing it:** this content
   may already be present, in which case Scope 6 is satisfied and nothing is to be reverted. This item
   is an instruction to bring that entry up to date, never to restore an earlier reading of it.
7. **Bump `.claude-plugin/plugin.json`'s patch version** — `hooks/`, `docs/` and `scripts/` are all
   plugin-loaded content.
8. **Wire the `SubagentStart` hook event as an attribution CANARY** (per the user's Q4 decision). See
   § The canary below. It does not improve attribution and must not be designed as though it does.
9. **Route `loop-verdict.sh`'s three ledger appends through the shared writer.** Added by **user
   decision during implementation**, overruling this spec's own § Out-of-scope 4 — see that item for the
   narrowing and its reason. `hooks/lib/loop-verdict.sh:61`, `:99` and `:173` each spell
   `… >> "$ledger" 2>/dev/null`, and **redirections apply left to right**: the ledger is opened before
   stderr is diverted, so a failed open is announced by the shell itself as a raw error naming the path,
   out of a hook whose contract (TC2) is that a failure path exits 0 and says nothing the author did
   not choose — a raw shell error naming a path is not a chosen message. Convert all three to
   `harness_ledger_append`, the helper the same defect already produced for `loop-index.sh` /
   `loop-result.sh`. **Nothing else in the file is touched** — see Out-of-scope 4.

   **The trigger is NOT the same as `loop-index.sh`'s, and this is the part a test can get wrong.**
   Same mechanism, different reachability:

   | File | Leaks when… | Why | Frequency |
   |---|---|---|---|
   | `loop-index.sh` / `loop-result.sh` | the ledger **directory** is unwritable | the file does not exist yet, so the open fails | once per tool call |
   | `loop-verdict.sh` | the ledger **file itself** is unwritable — a mode change, a read-only mount, a file owned by another user | the file exists and the open still fails | once per turn (`Stop` / `SubagentStop`) |

   **`loop-verdict.sh:58` carries `[ -s "$ledger" ] || exit 0`, which looks as though it makes these
   sites unreachable and does not:** it tests existence and non-emptiness, never writability. Verified
   2026-10-05 — against a mode-444 ledger the test passes and the append leaks a raw
   `permission denied: <path>` line to stderr. **The corollary is the trap:** an unwritable ledger
   *directory* leaves no ledger file at all, so `:58` exits 0 before any append and a test built on
   THAT trigger passes against this file vacuously. Only an unwritable ledger **file** reaches the
   defect. The leak's byte count is a function of the ledger's path length and is deliberately not
   recorded as a figure.

   Narrower trigger, less noise per session, no less wrong: the sentence still escapes a hook that
   promises silence.

### Frozen corpus — what each leg is for (Scope 5)

| Leg | Fixture | Asserts |
|---|---|---|
| **Validation** | the **real** rows, scrubbed | At the shipped window, the replay under **pre-fix** rules reproduces what the field recorded (0 firings). This is what licenses trusting the replay at other settings. It governs the pre-fix rules **only**. |
| **Fanout** | a **repaired copy** — same rows, `agent_id` recovered from the subagent transcripts | The five-subagent cluster classifies as `fanout`, with `na = 5`. Satisfies GH-88's bullet, which is unsatisfiable against the real rows. |

**The repaired copy is confirmed buildable — measured, not assumed.** Each of the five `tool_use_id`s in
the `44f957de` cluster resolves to exactly one subagent transcript, 1:1 and with no collisions:

```
toolu_01RoPBifKp3PVYdAiHG6sRfj -> agent-af4ff1f69e2639a73
toolu_01Bhd4qpLET4eeCULUvmnzb3 -> agent-a5cb273d9231c4e41
toolu_017iTwzWXQuPHrytm6VN2zLz -> agent-accd11a8a7a2a5db4
toolu_01NPa7a4CDXgWUnLD5KD32NT -> agent-a10bba56a033ba9f7
toolu_0119rHsuZ18yobp4uoqtczff -> agent-ae5cd4f6da35a54dc
```

The recovery rule is the one `scripts/loop-metrics.sh --for` already uses (`:244-250`, `:284-287`): an id
absent from the main transcript and present in `subagents/agent-X.jsonl` was made by agent X. The repair
is a **derivation with a committed recipe**, not hand-authored data.

Two properties of the fixture that the design must preserve, both measured:

- The cluster is the **last 5 rows of a 12-row fingerprint family** spanning 2026-09-30 → 2026-10-04 in
  one ledger. Cluster position is one of GH-88's own grid axes, so a fixture that trims the ledger must
  not flatten it.
- `44f957de` carries 1715 `result` rows against 1728 `call` rows. The real leg therefore exercises
  defect 1's interleaving **natively**, which no synthetic fixture can claim.

### The canary (Scope 8) — exactly what it buys, and what it must not duplicate

`hooks/hooks.json` wires `SessionStart`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Stop` and
`SubagentStop`. `SubagentStart` is listed as an embedded event at
`docs/claude-tools-hierarchy.md:46` and **no arm fires on it.**

The failure this closes is a **silent degradation, not a wrong answer**. At `hooks/lib/loop-index.sh:91-92`
agent identity comes from one payload field, and an absent or non-string `agent_id` degrades to the
literal `"main"` — indistinguishable from a genuine main-agent call. Nothing in the ledger can then
tell "no subagent ran" from "attribution broke". A dispatch-time record of a subagent STARTING makes the
state *"N subagents started, 0 non-`main` rows"* self-contradictory, and therefore detectable.

**The boundary that keeps this from being over-built.** `scripts/loop-metrics.sh:393-396` already prints
that contradiction — but only in `--for` mode, only for one session, and only by paying a scan of the
session's transcripts (`:244-250` states that cost is affordable "exactly here … and nowhere else in the
cascade"). The canary's whole novelty is making the same contradiction visible **from the ledger alone,
with no transcript scan**, and therefore in the corpus-wide `--all` view where attribution recovery does
not run at all. The design must not re-implement read-time attribution, and must not put a transcript
scan anywhere near the hot path.

## Out of scope

1. **Defect 3 / attribution repair.** Struck by the ticket author's final comment and re-measured
   working today. No change to how `agent_id`, `agent_type` or `transcript` are derived — the canary
   observes attribution, it does not supply it.
2. **Calibrating the `na > 1` bar — still out of scope, on a new basis.** This item used to read
   "no fingerprint family of ≥3 rows spans more than one agent in either post-`4c1cd0a` ledger." That
   was true when it was written and it is false now — **not an error of measurement, a measurement
   whose date has moved.** There are **three** post-`4c1cd0a` ledgers rather than two, and the third is
   *this task's own session*: it filled with subagent traffic while this change was being implemented,
   because the work spawns subagents. One of those ledgers now carries several fingerprint families of
   ≥3 `kind:"call"` rows that span more than one `agent_id`. **The figures live once, in
   `ai-docs/context.md`'s GH-72 entry, and are deliberately not copied here** — they were still moving
   while this amendment was being written, and a second copy is a second thing to go stale.
   **The disposition is unchanged: calibration is NOT in this PR.** Only its basis changes — from
   "there is nothing to measure" to "there is something to measure, and measuring it is a different
   ticket." No figure above is licence to tune the bar here; the fanout arm's threshold and decision
   stay exactly where Scope 3b leaves them (wording only). Stays the open question in
   `ai-docs/context.md`, updated per Scope 6.
   **One observation for whoever does calibrate it later:** the largest multi-agent families are
   `Read`s, and the largest of all is `fp 3562779350` — `Read` of `docs/agents-method.md`, the file the
   method tells every subagent to read. That is genuine duplication and also the cheapest kind, so a bar
   tuned on it may be tuned on the one fan-out nobody actually wants flagged.
3. **A-B-A-B oscillation detection.** GH-88 carves this out of its own scope explicitly: "detected by no
   tier at all … belongs in its own issue rather than riding on this one."
4. **Tier 2 / tier 3 — their DETECTION LOGIC, which is narrower than this item used to say.** The
   model stage and `scripts/session-events.sh`'s own detectors are untouched except where the shared
   fingerprint definition forbids drift (TC4). In `hooks/lib/loop-verdict.sh`, **out of scope** means
   its tiers, thresholds, bins, prompt, model stage, the `[ -s "$ledger" ]` early exit and every
   decision it reaches — no behaviour this file has as a DETECTOR changes.
   **One thing is now IN scope, by user decision taken during implementation: its three ledger-append
   sites** (`:61`, `:99`, `:173`) are converted to the shared writer per Scope 9. **This is a deliberate
   narrowing of the exclusion, not scope creep**, and the record of why is the point: the implementing
   agent found the same `>> "$ledger" 2>/dev/null` defect here, correctly did NOT touch it, and cited
   this item rather than its own judgement. The user's ruling was that the exclusion is not a good
   enough reason once the shared helper already exists and the repair is three lines. The exclusion
   stands for everything else in the file.
5. **Migrating, rewriting or back-filling existing ledgers.** The ledger is append-only by contract, and
   the established posture (GH-72's spec) is that a session in flight across an upgrade restarts its
   window — the safe direction. The repaired-copy FIXTURE is a committed derivation, not a migration.
6. **Weakening or removing the `ask` decision.** Tier 1 stays `ask`, never `deny`, on all three arms.
7. **Suppressing the startup-read fan-out.** Scope 3b changes the advice wording only. Exempting that
   cluster would contradict the user's Q2 decision, which requires it to classify as `fanout`.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| A-B-A-B / A-B-C-A-B-C oscillation as a first-class signal | Cheaper to design once the grid exists; GH-88 already carves it out | **Yes** — new issue, blocked on this PR landing |
| `na > 1` bar calibration | Needs a real firing to calibrate against, and there has been none (zero tier-1 verdicts corpus-wide). Multi-agent families of ≥3 rows DO now exist — the earlier "corpus contains none" basis is retired — but tuning the bar is a different ticket. See § Out of scope item 2 | No — stays as the GH-72 open question in `ai-docs/context.md` |
| Using `SubagentStart` to SUPPLY agent identity rather than to observe it | Explicitly not this change's purpose; the user's Q4 rationale is the canary | No — reopen only if the canary ever fires |
| `#76`'s absolute-path gate | Open issue, gate not yet written; this change must merely not *add* a needle for it | No — GH-76 owns it |

## Key decisions

| Question | Decision |
|---|---|
| GH-86 alone, or jointly with GH-88? | **Jointly.** User decision, round 1. One spec, one PR. |
| Does GH-86's "at the shipped setting the replay still reproduces what the field recorded" cap the fixed detector? | **No — it is a VALIDATION LEG against the PRE-fix rules only.** The default stays 20, now meaning 20 CALLS, and **new firings at the shipped default are the intended effect of the repair**. User decision, round 1, taken against the orchestrator's recommendation of "hold, then raise". Not to be re-litigated or softened: no AC may read the corpus bullet as a cap. |
| What does the frozen-corpus gate freeze? | **Both legs** — real rows for validation, a repaired copy for the fanout assertion; the pre-/post-`4c1cd0a` distinction becomes a tested property in its own right. Costs two fixtures. User decision, round 1. |
| Is wiring `SubagentStart` part of this change? | **Yes, in scope** — user decision, round 1, taken against the orchestrator's recommendation of "out of scope" and after being told explicitly that it does not improve attribution today. Its purpose is the canary; design it for that and nothing more. Not to be re-litigated. |
| Is defect 3 in scope? | **No.** Struck by the ticket's own third comment and re-measured working today. Recorded above rather than omitted, because its correction cycle is what makes the frozen-corpus fixture design non-obvious. |
| Repair shape for defect 2 | The ticket's own proposal (anchor on the most recent matches) is the **default**; the binding requirement is the monotonicity property (AC3), not a particular rule. Design may choose otherwise if it carries AC3 and AC4. |
| Does the STATE qualifier survive? | **Yes, re-anchored not removed.** It is the whole point of GH-69's conditional edit filter; AC4 is its negative control. |
| Does the error-retry arm change? | **No.** `:179` returns before `:183`, so defect 2 never touched it, and `fails >= RETRY_MIN` still fires regardless of intervening edits. AC5 guards it. |
| Does the fanout arm's advice change? | **Yes, wording only** (Scope 3b). Threshold, decision and stderr behaviour are untouched. |
| Migrate old ledgers so the new unit applies retroactively? | **No** — append-only contract, established posture. |
| Does a verdict row need a unit marker now that `window` changes meaning? | **Left to design** (OQ2). |
| Which test framework / assertion style? | Project default, applied silently: a `bash …/test-….sh` script with `check` / `has` helpers, run bare as its own gate. |

## Technical constraints

| # | Constraint |
|---|---|
| TC1 | **The hot path is the whole design constraint.** `loop-index.sh` runs before *every* tool call and is deliberately ONE `jq` invocation plus one `tail`. The ledger has **no truncation** by contract (`:50-54`), so it grows unbounded — a call-counted window must not become a whole-file read per call. The largest ledger measured today is 4608 lines. |
| TC2 | **A hook that breaks is worse than a hook that is absent — and `exit 0` is the absolute half of that contract, while silence never was.** Every failure path exits 0, unconditionally, and never costs the session a tool call: malformed payload, absent `jq`, unwritable ledger. **Silence is the DEFAULT, not the guarantee.** The one deliberate exception is the unwritable ledger, which reports a single sentence per session, because tier 1 and tier 2 both read that file — losing it disables detection for the whole session while every tool call still succeeds and nothing looks wrong, and a detector that dies where nobody notices is the precise failure this change exists to fix. Silencing its own death would be the first instance of it. Full rationale in `hooks/lib/ledger-write.sh`'s header; the trigger that reaches it, which differs per file, is TC2b. Every clause here binds the new `SubagentStart` arm identically. |
| TC2b | **The unwritable-ledger report (TC2) is reached by a DIFFERENT trigger in each file, and that is the thing a suite gets wrong.** **The trap: the trigger is not interchangeable between files.** An unwritable ledger **directory** reaches `loop-index.sh` / `loop-result.sh` (the file does not exist yet, so the open fails) but **cannot** reach `loop-verdict.sh`, whose `:58` `[ -s "$ledger" ]` exits 0 before any append when the ledger is absent or empty. Only an unwritable ledger **file**, present and non-empty, reaches `:61` / `:99` / `:173`. **A fixture built on the directory-level trigger is therefore vacuously green against `loop-verdict.sh` — this repo's own named hazard of an admission filter keyed on the very property that separates a real finding from a dismissable one.** Any suite covering Scope 9 pins mode 444 on a NON-EMPTY ledger file, and the leaked text embeds the ledger path, so its byte length is path-dependent and must not be asserted as a constant. |
| TC3 | **Readers MUST filter on `kind`, strictly.** A line whose `kind` this build does not know is skipped rather than guessed at (`:136-146` states it, `:145-146` enforces it). A verdict row carries `tool` and `fp` like a call; counting one lets each firing make the next more likely. The four kinds today are `call`, `result`, `turn`, `verdict`. |
| TC3b | **Strict `kind` filtering cuts both ways, and this is the trap in Scope 8.** A new canary row kind is automatically safe for the DETECTOR — but it is also automatically **invisible to the readers**: `scripts/loop-metrics.sh` selects known kinds only (`:134-135`, `:189-197`, `:297`). A canary nobody reads is not a canary. Any new row class must be taught to the reader in the same PR, which is also what fires the Inspect sync group (TC8b). |
| TC4 | **The djb2 fingerprint and `bin-of.jq` must stay byte-identical to `scripts/session-events.sh`'s copies** — pinned by `scripts/test-bin-of.sh`. If they drift, `/inspect` and the hook are talking about different fingerprints while both calling them fingerprints. |
| TC5 | **Frozen-corpus fixtures carry `cwd` and `transcript`: absolute paths containing a username.** Scrub before committing. GH-76 (open) will gate on "no tracked file names this repo's own absolute path"; a fixture that ships a needle makes that gate red on arrival. The payload itself is content-free, so nothing else needs redaction. The **repaired** leg must be scrubbed by the same rule as the real one. |
| TC6 | **New `*.sh` files are invisible to the `bash -n` gate until tracked.** `git ls-files` lists tracked files only — run `git add -N <new paths>` first, and check the **file count** the gate processed, not only its exit status. The mandated spelling is `git ls-files -z '*.sh'` into `xargs -0 -n1 bash -n`; the three natural alternatives all report success on a file that does not parse. |
| TC7 | **Every new suite must be registered** in `AGENTS.md` § Build & Test check 4's enumerated list, or it is a gate nobody runs. This change adds at least two suites (the grid/corpus gate, the canary's suite). |
| TC8 | **Propagation — hook-contract group.** Any edit changing a Hook contract updates `docs/claude-tools-hierarchy.md` in the same PR. Three distinct obligations here: `:101`'s "~20 steps" (Scope 3), a **new `SubagentStart` row in § Project-defined Hooks**, and the §3b snapshot note. Verify with `bash scripts/check-propagation-arms.sh`, reading the member COUNT it reports, not only its exit status. |
| TC8b | **Propagation — Inspect group.** If `scripts/loop-metrics.sh`'s emitted fields move — which TC3b makes likely — `skills/inspect/SKILL.md`, `agents/inspector.md`, `scripts/session-events.sh` and `scripts/loop-metrics.sh` must move together. `docs/propagation.md` warns this group is invisible to a token sweep: four vocabularies for one mechanism. |
| TC9 | **`.claude-plugin/plugin.json` patch bump is mandatory.** The install cache is keyed by version; an unbumped fix silently never reaches an installed copy — and that cache is exactly what produced GH-86's own stale-build false alarm. |
| TC10 | **Method/profile boundary.** `hooks/`, `docs/`, `scripts/` are method — no project nouns, no ticket prefixes in their prose. Corpus fixtures are project data. |
| TC11 | **The existing window test cannot see defect 1.** `hooks/lib/test-loop-index.sh:342-350` interleaves only `kind:"call"` rows, so lines and calls are the same number in that fixture and the assertion passes against both the broken and the fixed rule. Any AC1 fixture MUST interleave `kind:"result"` rows written the way `loop-result.sh` writes them. |
| TC12 | **Hook commands MUST NOT name themselves with a reserved event-name word** (`docs/claude-tools-hierarchy.md:53`), and project-defined names must not clash with the embedded inventory (`agents-method.md` § Naming). A canary script named for the event it listens on is the obvious spelling and the one this forbids. |
| TC13 | **The `SubagentStart` payload shape is NOT established by this spec.** The only recorded facts are that the event exists and that its matcher runs against `agent_type`. Whether it carries an `agent_id` is unverified — and the canary does not need one: a bare count of starts is already enough to contradict "0 non-`main` rows". Design verifies the payload before depending on any field, and must not assume the `PreToolUse` shape. |

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | **The window counts calls, not lines.** On a ledger whose `kind:"call"` rows are interleaved with `kind:"result"`, `kind:"turn"` and `kind:"verdict"` rows, the detector at `HARNESS_LOOP_TAIL=K` considers exactly the last `K` call rows, whatever the line count between them. Demonstrated to FAIL against the pre-fix `tail -n` rule on that same fixture (TC11). |
| AC2 | **The agent-facing unit is true as written.** On a fixture where lines ≠ calls, the number interpolated into "in the last %s steps" equals the number of CALLS the window spanned, for all three arms. |
| AC2b | **The reach is stable across ledger shapes.** The same `K` yields the same number of counted calls on two fixtures with materially different lines-per-call ratios (the measured corpus spans 1.04 to 2.37). This is the AC that rejects a fixed-multiplier repair, which would satisfy AC1 on one shape and fail on the other. |
| AC3 | **Monotonicity, as an executable property.** For a fixed ledger and a fixed incoming call, the firing count is **non-decreasing** as `HARNESS_LOOP_TAIL` widens, including to unbounded. Asserted over the variation grid AND both corpus legs. Demonstrated to FAIL against the pre-fix `changed > first` rule — the measured 20→0 / 40→2 / 100→3 / unbounded→0 is the positive control. |
| AC4 | **The STATE qualifier still dismisses.** A succeeded repeat with an `Edit`/`Write`/`NotebookEdit` between the counted matches stays silent. Negative control for AC3: a monotonic rule that fires on everything also satisfies AC3. |
| AC5 | **The error-retry arm is unchanged, and the grid says so.** ≥`RETRY_MIN` failures of the same `fp` fire as `error-retry` regardless of intervening edits, and that arm short-circuits at `:179` before the STATE test. No grid axis or AC may assert that defect 2 affected `error-retry`; it did not. |
| AC6 | **Variation grid with paired near-misses.** Every axis in GH-88's table — call identity, intervening mutation, outcome, agent multiplicity, sparsity, cluster position, time, ledger schema — carries a must-fire case AND the near-miss that must stay silent. The suite prints a **confusion matrix per axis** and exits non-zero on a regression in precision or in recall. A grid without the near-miss column measures sensitivity only, which is how a detector that fires on everything passes. |
| AC7 | **Idempotence.** Replaying the same ledger twice yields the same verdicts. |
| AC8 | **A verdict row never counts itself.** Kept inside the property set so the properties live in one place, not only as the existing standalone assertion. |
| AC9 | **Frozen-corpus validation leg.** The **real**, scrubbed rows are committed, and at the shipped window the replay under the **PRE-fix** rules reproduces what the field recorded (0 firings). **This leg governs the pre-fix rules only and is explicitly NOT a cap on the fixed detector** (Key decision, round 1). An AC, a comment or a test name that reads it as a cap is a defect in this gate. |
| AC10 | **Post-fix reach is recorded as a baseline, and is allowed to be higher.** The fixed detector's firing count against the real leg at each window width is committed as the gate's expected value. The gate fails on an unexplained CHANGE to that baseline, never on the count being greater than zero. |
| AC11 | **Frozen-corpus fanout leg.** The **repaired** copy — `agent_id` recovered per the committed recipe — classifies the five-subagent cluster as `fanout` with `na = 5`, not as `loop`. The recovery is reproducible from the committed inputs; the fixture is not hand-authored. |
| AC12 | **Pre-/post-`4c1cd0a` attribution is a tested property.** The same rows under the two legs produce `loop` (all `main`) and `fanout` (recovered ids) respectively, and the gate asserts both — so a future change that silently reintroduces the collapse flips a test rather than a field report. |
| AC13 | **A planted true loop fires at the shipped default** — the same call three times with nothing changed between — with the message's unit matching the unit actually counted. |
| AC14 | **The fanout advice names an action its reader can take.** The `:198` string no longer instructs a sibling subagent to reuse a result it cannot reach. Asserted on the emitted stderr/JSON text, and paired with an assertion that the arm still returns `permissionDecision: "ask"` exactly as `loop` and `error-retry` do (`:226-227`) — `fanout` is not and does not become a quieter signal. |
| AC15 | **A `SubagentStart` arm exists and is harmless.** `hooks/hooks.json` carries a `SubagentStart` arm; `jq -e .` parses the manifest; the arm exits 0 on a malformed, empty and absent payload and on an unwritable ledger (TC2); and it has a registered suite (TC7). |
| AC15b | **`loop-verdict.sh`'s ledger appends report instead of leaking — a DIFFERENT file from AC15's subject, with a different trigger.** Named explicitly here rather than inherited from the canary's arm: with the ledger **file** at mode **444** and **present and non-empty** (an empty or absent ledger trips the `:58` early exit and measures nothing — TC2b), each of `hooks/lib/loop-verdict.sh:61`, `:99` and `:173` yields **rc 0**, **exactly one** reporting sentence, and **silence on a second invocation in the same session**. No raw shell `permission denied` reaches stderr from any of the three. The assertion is on the sentence's presence and on the second call's silence, never on a byte count (TC2b). |
| AC16 | **The canary makes the contradiction detectable from the ledger alone.** Given a ledger containing N subagent-start records and zero non-`main` `call` rows, a reader reports the contradiction **without scanning any transcript**. Asserted against a fixture, with the negative control that a ledger whose starts and non-`main` rows agree reports nothing. |
| AC17 | **The canary does not touch the detector.** The new row class is not counted as a call, does not shift the window, and does not alter any verdict — demonstrated by replaying a fixture with and without the canary rows and asserting identical verdicts (TC3). |
| AC18 | **No fixture names an author's home directory.** A grep for the repo's own absolute path and for `/Users/` over every committed fixture, both legs, returns zero hits (TC5). |
| AC19 | **Every new suite is reachable by the gates.** Registered in `AGENTS.md` check 4's list; `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` processes the new files after `git add -N`, verified by **file count**, not only by exit status. |
| AC20 | **The shipped prose states the counted unit and the new arm.** `docs/claude-tools-hierarchy.md:101`'s "within the last ~20 steps" is true of the unit now counted; § Project-defined Hooks gains a `SubagentStart` row; `ai-docs/context.md`'s GH-72 entry carries this change's measurement per Scope 6. |
| AC21 | **`.claude-plugin/plugin.json` patch version is bumped** in the same PR. |
| AC22 | **The full gate sequence is green** — `AGENTS.md` § Build & Test checks 1, 2, 4, 5, 5a, plus gates 6–8 before the PR (or an honest `exit 2` recorded as "could not run", never as a pass). `check-propagation-arms.sh` is read by member COUNT, not only exit status (TC8). |

## Open questions

- ~~**OQ1 — what the frozen corpus freezes for the fan-out assertion.**~~ **Closed by the user's round-1
  Q2 decision:** both legs. Recorded in § Frozen corpus and bound by AC9 / AC11 / AC12.
- **OQ2 — whether the verdict row needs a unit marker.** Design's call. `hooks/lib/loop-index.sh:217`
  records `window: $w`, and `scripts/loop-metrics.sh:167` surfaces it as `settings.window`. After this
  change that number means calls in new rows and lines in old ones, with nothing distinguishing them.
  The precedent (GH-72 spec) is "add nothing; fix the wording"; the counter-argument is that
  `agent_type: null` versus `"-"` is exactly the accidental build-marker that let GH-86's second comment
  correct its first, and relying on an accident twice is a choice.
- **OQ3 — where the precision/recall baseline lives.** Design's call: a committed expected-values file
  the grid diffs against, versus figures asserted inline in the suite. AC6 and AC10 bind the behaviour
  either way.
- **OQ4 — how a call-counted window is read without a whole-file scan.** Design's call under TC1.
  Candidates: `tail -n $((TAIL_N * R))` for a rows-per-call factor `R` plus filtering, versus an
  awk-side early exit. **The measured ratio spread of 1.04 to 2.37 makes a fixed `R` unsafe** — it is the
  same silent coupling that broke when `loop-result.sh` was wired. AC2b is the gate on this.
- **OQ5 — where the canary's record lives and what reads it.** Design's call under TC3b and TC13: a new
  ledger row class read by `scripts/loop-metrics.sh`, versus a counter outside the ledger. AC16 binds
  the behaviour (detectable without a transcript scan) and AC17 the non-interference; the carrier is
  open. Whichever is chosen, the Inspect sync group (TC8b) moves with it.
- **OQ6 — whether the canary should surface in `--all` as well as `--for`.** Design's call. The gap the
  canary closes is widest in `--all`, where `scripts/loop-metrics.sh` runs no attribution recovery at
  all — but `--all` is a corpus view and a per-session contradiction may read oddly there.
- ~~**OQ7 — which criterion binds Scope 9, because on measurement NONE of the existing ones can.**~~
  **Closed by the user's round-4 routing: `AC15b` is the criterion**, carrying the unwritable-**file**
  trigger (mode 444, ledger present and non-empty), rc 0, exactly one sentence, silence on the second
  call, and naming `loop-verdict.sh` explicitly rather than inheriting AC15's subject. `TC2b` is the
  constraint it rests on. Suffixed per the `AC2b` precedent, so no existing row was renumbered and
  AC15 was not widened. **The provenance is the part worth keeping: this gap was found by checking a
  premise supplied in an amendment brief, and the premise was false.** The brief asserted the behaviour
  was already bound by an existing criterion; it was not, and the criterion it named could not have
  reached the defect even read generously. Had the premise been accepted, Scope 9 would have shipped
  with a suite that passed while measuring nothing — which is the failure this entire ticket exists to
  fix. The three measurements that falsified it are preserved below.
  The round-3 amendment brief stated the behaviour was already bound by "the criterion
  covering the unwritable-ledger report — rc 0 plus exactly one sentence and silence on the second
  call". Checked against the documents rather than assumed, that criterion does not reach this file,
  for three independent reasons:
  1. **AC15 is textually scoped to one arm in one file** — "**A `SubagentStart` arm** exists and is
     harmless … **the arm** exits 0 … on an unwritable ledger". `loop-verdict.sh` is a `Stop` /
     `SubagentStop` hook; no reading of AC15's subject includes it.
  2. **The design's verification recipe for AC15 runs the canary's suite only** —
     `bash hooks/lib/test-loop-agent-mark.sh`. No leg of it executes `loop-verdict.sh`.
  3. **The strongest reason, and it is structural: the trigger both documents name is an unwritable
     ledger DIRECTORY, which this file's `:58` early-exit makes unreachable** (Scope 9). So even read
     at its most generous, that criterion's own stated trigger cannot exercise the defect — a suite
     written to it would pass against `loop-verdict.sh` while measuring nothing, which is this repo's
     named hazard of an admission filter keyed on the very property that separates a real finding from
     a dismissable one.

  At the time of the finding, Scope 9 therefore had **no** acceptance criterion, and the one trigger
  that would bind it — an unwritable ledger **file**, mode 444, reaching `:61` / `:99` / `:173` — was
  named by no AC in this document. **That is the state this entry recorded, and it is RESOLVED: `AC15b`
  now names exactly that trigger and `TC2b` the constraint.** Nothing above is outstanding; it is kept
  as the evidence trail, because "a mandated change with no gate" is the exact shape this whole ticket
  exists to fix and it very nearly shipped inside the ticket that fixes it.
