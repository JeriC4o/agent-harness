# Design: Tier 1 — count the window in calls, make the dismissal monotonic, cover the calibration, plant the attribution canary

**Ticket:** GH-86, GH-88
**Date:** 2026-10-05
**Spec:** `ai-docs/plans/2026-10-05-tier1-window-and-dismissal.spec.md`
**Branch:** `GH-86-tier1-window`, off `main` at `6bf33c8`

> Every figure below was produced by a command run while writing this design. The corpus is live and
> moved again between the spec and this document (§ Measurements). **Re-derive every number before a
> gate bakes it in** — that instruction is not boilerplate here, it is the thing that already happened
> twice.

---

## Measurements taken for this design

Re-derived 2026-10-05 against `~/.claude/harness/loops/` and the working tree at `6bf33c8`.

| Fact | Spec said | Measured now | How |
|---|---|---|---|
| Ledgers | 12 | **12** | `ls ~/.claude/harness/loops/*.jsonl` |
| `kind:"call"` rows | 8281 | **8322** | per-file `grep -c '"kind":"call"'`, summed |
| Lines | 17863 | **17957** | per-file `wc -l`, summed |
| Corpus lines/call | 2.16 | **2.158** | 17957 / 8322 |
| Distinct non-`main` `agent_id`s | 7 | **8** | `jq -rs` unique over `kind:"call"` per ledger |
| Tier-1 verdicts ever written | 0 | **0** — 105 verdicts, all tier 2 (78) or tier 3 (27) | `jq -rs 'group_by(.tier)'` over all ledgers |
| `agent_id` read at | `loop-index.sh:91-92` | **confirmed `:91`** | `grep -n 'agent_id | type'` |
| All three arms emit `ask` | `:226-227` | **confirmed** | read of `loop-index.sh:220-228` |

The growth is `c9baa003`, which is **the session writing this design** — 83 calls in the spec, 124 now.
That is the cleanest possible demonstration of why a corpus figure may not be copied forward.

**The `44f957de` fingerprint family, re-derived** (`fp 3562779350`, `Read` of `docs/agents-method.md`):

| Ledger line | 37 | 112 | 194 | 1192 | 1875 | 2208 | 2626 | 3360 | 3361 | 3386 | 3409 | 3410 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Call ordinal** | 18 | 50 | 85 | 494 | 790 | 932 | 1115 | **1445** | **1446** | **1458** | **1470** | **1471** |

Twelve rows; the last five are the cluster. **Their span is 26 calls (1445 → 1471), not 20** — so the
`na = 5` assertion AC11 asks for is reachable only at `HARNESS_LOOP_TAIL ≥ 26`. Measured upper bound:
the previous family row sits at ordinal 1115, so `na = 5` holds for `26 ≤ K ≤ 355` and becomes `na = 6`
beyond it. **AC11 must name a window inside that band.** This design picks `K = 40`.

No `Edit` / `Write` / `NotebookEdit` call occurs between lines 3356 and 3410, so the STATE qualifier does
not dismiss the cluster under either rule.

**Replay prototype** (scratch, both rules, over the real `44f957de`):

| `K` | pre-fix (lines, `changed > first`) | post-fix (calls, re-anchored) |
|---|---|---|
| 20 | **0** | 2 |
| 26 | — | 3 |
| 40 | 2 | 3 |
| 100 | 3 | 3 |
| 1000 / 5000 (unbounded) | **0** | 3 |

The pre-fix column reproduces the ticket's measured **20 → 0, 40 → 2, 100 → 3, unbounded → 0** exactly,
which is what licenses trusting the post-fix column.

**A sweep over the real ledger is NOT evidence of monotonicity, and the first draft of this design
treated it as though it were.** Measured, after design review challenged it:

| Sweep | Pre-fix result | Discriminating? |
|---|---|---|
| `K = 1..80`, call-counted, step 1 | **0 non-monotonic steps** | **No** — the post-fix rule also scores 0, so the sweep separates nothing |
| `K = 740..780`, **line-fed** (the control's own feed, § A1b), step 1 | **first break at `K = 760` (3 → 2)** | yes, past 759 |
| `K = 335..355`, call-fed, step 1 | **first break at `K = 343` (3 → 2)** | yes, past 342 — but this feed is a hybrid, not the control |

**Both breaks are measured at step 1.** Round 2 of this document reported 761 and 346; those were the
first sample points a step-10 and a step-5 sweep happened to land on, recorded as if they were
properties of the rule. They are properties of the sweep. The true breaks are 760 and 343.

So the defect is real on this ledger and reachable **only at window widths two orders of magnitude above
the shipped default**. A gate built on the narrow sweep passes against the broken rule — which is the
spec's opening complaint, reproduced inside the design that was supposed to answer it. The grid needs a
fixture that breaks the pre-fix rule at a *realistic* width, and no single-axis case can build one:
it takes **mutation × cluster position combined**.

**The `dismissal anchor` fixture — 15 rows, built and measured for this design.** An older match, a
mutation immediately after it, then a tight recent cluster:

| call ordinal | 1 | 2 | 3–12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|
| row | `Bash` fp A | **`Edit`** | 10 distinct `Read`s | `Bash` fp A | `Bash` fp A | `Bash` fp A (incoming) |

| `K` | 3 | 5 | 10 | 13 | 14 | 20 |
|---|---|---|---|---|---|---|
| **pre-fix** firings | 1 | 1 | 1 | 1 | **0** | **0** |
| **post-fix** firings | 1 | 1 | 1 | 1 | 1 | 1 |

At `K ≤ 13` the window excludes the old match, so `first` is the recent cluster and the mutation at
ordinal 2 is outside the window entirely. At `K = 14` the old match enters, `first` jumps back to it,
the mutation now sits after `first`, and the whole recent cluster is dismissed. **That is the defect,
at a window width an operator would actually type.** This fixture is AC3's grid-side positive control
(§ grid axis *dismissal anchor*).

**Hot path, measured** (4608-line ledger, the largest in the corpus):

| | ms |
|---|---|
| whole hook, end to end, per call | **23.7** (jq-dominated) |
| `tail -n 20 \| awk` alone | 1.8 |
| `tail -n 60 \| awk` alone | **1.9** |
| two tails (the retry path) | 4.0 |
| whole-file read (4608 lines) | 15.5 |

So the chosen window read costs **+0.1 ms** in the normal case and **+2.2 ms** on a retry, against a
23.7 ms baseline — while a whole-file scan costs +13.7 ms *today* and grows without bound (TC1).

**`SubagentStart` payload shape (TC13) — verified, not assumed.** Two independent sources:

1. The shipped CLI's own schema, `claude-code 2.1.273`, at byte offset 170359612:
   `Gie=f(()=>Ce().and(u({hook_event_name:R("SubagentStart"),agent_id:o(),agent_type:o()})))`, where
   `Ce` is the common base beginning `u({session_id:o(),tr…`.
2. `https://code.claude.com/docs/en/hooks` § SubagentStart JSON Input, which lists `session_id`,
   `prompt_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `permission_mode`, `hook_event_name`,
   `agent_id`, `agent_type`.

Also measured from the binary: the event's default timeout is 15 s, its only `hookSpecificOutput` field
is `additionalContext` (**no `permissionDecision` — it structurally cannot block a spawn**), and a
non-zero exit becomes a `hook_blocking_error` attachment, so the exit-0 discipline of TC2 still binds.

`session_id` is the field the canary actually depends on, because the ledger is keyed by it. It is
present. **Implementation still runs the live probe in Task 7** — a schema in a bundle is strong
evidence about intent, not a measurement of what arrives on stdin.

---

## Approach

> **Anchor note, added after Group A shipped Task 1.** Every `loop-index.sh:NNN` address below that
> points at the detector is **pre-extraction history**, not a live address — the code moved. Live
> anchors, re-derived by `grep -n`: `print "RETRY"` at `loop-window.awk:39`, `span =` at `:59`,
> `ai =` / `anchor =` at `:136-137`, `span="${4:-$TAIL_N}"` at `loop-index.sh:160`. The historical
> references (`:123-185`, `:156`, `:183`, `:195-201`, `:217`) are kept because they say where the code
> came from; re-derive before citing any of them as current.

### A1. Extract the detector into a shared file first, before changing it

`hooks/lib/loop-index.sh:123-185` holds the detector as an inline awk program. Task 1 moves it,
**byte-for-byte and with no behaviour change**, into `hooks/lib/loop-window.awk`, invoked as
`awk -f "${HERE_LIB}/loop-window.awk"` with `HERE_LIB` resolved from `$0` exactly as `HERE_JQ` already is
at `:61`.

**This is forced, not stylistic.** The frozen-corpus legs cannot be driven through the hook end to end:
the ledger is an *index*, it stores `fp` — a djb2 hash of `tool_input` — and never the arguments
(`loop-index.sh:8-12`). No payload reproduces a recorded `fp` short of inverting the hash, so a replay
of real rows has to call the detector directly. Giving the hook and the gate one file is the only way to
do that without a second implementation.

Rejected alternatives:

- **Rewrite the fixture's `fp` column to hashes of synthetic payloads.** Preserves the equivalence
  structure and would let the hook be driven end to end — but it relabels the one column the validation
  leg exists to preserve, and AC9 says "the **real**, scrubbed rows".
- **A second awk inside the test.** A copy that drifts from the thing it measures. This repo already
  pays for one such pin (`scripts/test-bin-of.sh`, TC4); adding a second copy to avoid a file move is
  the wrong trade.
- **Leave the awk inline and have the gate `sed` it out of the hook at run time.** A gate that parses
  its subject's source to find the code under test fails silently the first time the surrounding shell
  is reformatted.

Cost: one extra `open()` per call (inside the 1.9 ms already measured) and one new failure mode — a
missing `.awk` file. Guarded: the detector call is wrapped so that an unreadable program yields an empty
verdict, and **the ledger append still happens**. The negative test renames the file and asserts the row
is still written and the exit status is still 0.

#### A1b. The frozen pre-fix detector is an artefact, with a file of its own

**Four separate ACs need a runnable pre-fix rule** — AC1's control, AC3's control, AC5's
"same verdict under both rules", and AC9's validation leg, which is *defined* as a replay under the
pre-fix rules. Left unnamed it lands inline in both new suites: two copies, no owner, each free to be
"tidied up" into agreement with the current detector. That is precisely the drifting copy the list above
rejects, arriving by the back door.

So it is committed as **`hooks/lib/loop-window-prefix.awk`**, created in Task 1 — the one moment in the
change when the pre-fix program still exists verbatim, so the artefact is a *copy of the original*
rather than a reconstruction from memory of it.

**THE CONTROL IS TWO HALVES AND THE AWK IS ONLY ONE OF THEM.** Round 2 of this document called the
`.awk` "both halves frozen together"; that is false, and the error is the ticket's own in miniature. The
pre-fix detector was a **window bound in the shell** (`tail -n "$TAIL_N"`, i.e. LINES) feeding a
**dismissal rule in awk**. Only the second half lives in a `.awk` file. A caller that feeds the frozen
awk a call-counted window gets a hybrid that existed in no build and that no AC describes — and the two
feeds disagree on exactly the numbers the ACs pin:

| frozen awk fed… | `K` = 20 | 40 | 100 | first monotonicity break |
|---|---|---|---|---|
| **lines** — the control | **0** | **2** | **3** | **760** |
| calls — a hybrid, used by nothing | 2 | 3 | 3 | 343 |

The field measurement every AC rests on (20 → 0, 40 → 2, 100 → 3, unbounded → 0) is the **line** row.
Fed calls, Task 6's first assertion fails outright.

**So the invocation is fixed here, once, and every AC inherits it:** the control is
`tail -n K <ledger>` piped into `awk -f hooks/lib/loop-window-prefix.awk`, `K` in **lines**.
**Task 1 commits that as `hooks/lib/loop-window-prefix.sh`** — two lines carrying the `tail` — and the
suites invoke the wrapper, never the `.awk` directly. A feed that lives only in prose is precisely the
silent coupling this whole ticket exists to remove; writing it down and hoping would be the same mistake
one level down.

**Why this is not the rejected second implementation, stated so the distinction survives review.** The
rejected copy is a second implementation of the *current* rule: two things that must agree, with nothing
making them agree. This is a **frozen historical control** — a thing that must *disagree*, and whose
whole value is that it does not move. Its header says so in those words, and names the three properties
that make it sound:

- It is **never** updated to track `loop-window.awk`. A change that makes the two agree destroys every
  control built on it; that sentence is the first line of the file.
- Neither file is wired into any hook. `hooks.json` names neither; only the two new suites read them.
- **It emits THREE fields and must never grow a fourth** (`loop-window-prefix.awk:75`, `:79`). The
  shipped detector emits four, the span being the addition. A fourth field appearing here means someone
  updated the control, which the freeze forbids — so the field count is itself a freeze check, and the
  caller's `${4:-$TAIL_N}` fallback (§ A5) exists because this three-field line is a real input.
- Its correctness bar is fixed and already met: through the wrapper it reproduces the ticket's field
  measurement (20 → 0, 40 → 2, 100 → 3, unbounded → 0), which Task 6 asserts as the gate's own first
  check — so the control is itself controlled, and bit-rot surfaces as a failure rather than as a
  weaker gate.

**Consequence for AC1's control, which was wrong in the first draft and half-wrong in the second.**
"Restore `tail -n "$TAIL_N"`" does not reproduce defect 1 after A2: the awk is call-bounded by then, so
on `ratio-2.4` it sees ~8 calls in the 20-line chunk, emits `RETRY`, and the shell widens back to the
correct window — a positive control that controls nothing. But running the frozen `.awk` alone does not
fix that either: a harness that feeds it calls has reverted the anchor and *kept* the new unit, so it
still proves nothing about a unit. **AC1's control is the wrapper**, which is the only form in which
both halves revert together.

### A2. OQ4 — a call-counted window with no whole-file read: adaptive tail, bound inside awk

Two halves, and the split is what makes AC2b hold.

**The shell sizes a chunk; it never decides the window.** `loop-index.sh` reads
`tail -n $((TAIL_N * 3))`. The factor 3 is a *performance hint* chosen from the measured ratio range
(1.04 … 2.37) and nothing about correctness rests on it.

**awk bounds the window.** The program buffers the chunk, walks back from the end counting `kind:"call"`
rows, and starts its scan at the `TAIL_N`-th most recent one — so it considers exactly `TAIL_N` calls
whatever the line count between them. Interleaved `result` / `turn` / `verdict` rows inside that span are
read as they are today; rows before it are not read at all.

**The retry.** awk knows both how many calls it saw and its own `NR`. It is passed the requested chunk
size `m`; if `calls_seen < TAIL_N` **and** `NR == m` the chunk may have been short, so it prints the bare
token `RETRY` and nothing else. The shell then doubles `m` and re-runs. If `NR < m`, `tail` returned
fewer lines than asked for, the file is exhausted, and there is nothing more to read — terminate and
emit. No iteration cap is needed and none is added: the loop is bounded by the file.

- A `RETRY` takes precedence over an emittable verdict, because a wider chunk can change `count` and
  `na` and therefore the arm.
- `RETRY` can never collide with a verdict line, which is always `<kind> <count> <agents>`.
- A ledger shorter than the window is the common first-call case: `NR < m`, no retry, emit from what
  was seen.

Rejected: `tail -n $((TAIL_N * R))` with a fixed `R` and no retry — the spec's own named hazard, and the
measured 2.3× spread between ledgers is exactly the coupling that broke when `loop-result.sh` was wired.
Rejected: a whole-file awk with a ring buffer — correct, simple, and measured at +13.7 ms per call today
on a file with no truncation contract (TC1). Rejected: `tac` / `tail -r` — neither is portable across the
two platforms this repo is edited on.

### A3. OQ-free — the monotonic dismissal (Scope 2)

Today: `first` is the NR of the **earliest** match in the window (`:156`) and `:183` reads
`if (changed > first) exit`. Widening moves `first` back, so a mutation after an older match silences
every later cluster — the measured unbounded → 0.

**Re-anchor on the evidence that would fire.** A firing needs the current call plus `thr - 1` prior
matches; those are the **most recent** `thr - 1`. Let `m_1 < … < m_n` be the matches in the window:

```
anchor = m_{n - (thr - 2)}      # thr = 3  ->  the second-most-recent match
if (changed > anchor) exit
```

The qualifier is re-anchored, not removed (Key decision), and for the commonest case `n == 2` the rule is
**identical to today's** — `m_{n-1} == m_1 == first` — which is why `test-loop-index.sh`'s existing STATE
cases stay green unmodified. The behaviour diverges only where `n > 2`, which is precisely where the
non-monotonicity lives.

**Why it is monotonic.** Widening the window can only admit *older* rows. It cannot move `m_n` or
`m_{n-1}`, so `anchor` is fixed once `n ≥ thr - 1`. It cannot raise `changed`, which is a maximum over
mutation positions. And a mutation newly admitted by the widening is necessarily older than the anchor
match (otherwise the narrower window held it too), so it cannot flip the comparison. Below
`n = thr - 1` no firing is possible at any width. Firing is therefore non-decreasing in `K`, asserted as
a property over the grid and both corpus legs. **The empirical sweep is the argument's support, not its
proof, and only where it discriminates** — see § Measurements: over `K = 1..80` the *pre-fix* rule also
scores zero violations, so that range proves nothing about either rule. The discriminating evidence is
the `dismissal anchor` fixture (breaks the control at `K = 14`) and the real ledger past **`K = 760`
lines**, the control's own feed (§ A1b).

`error-retry` is untouched: `:179` returns before the STATE test (AC5). The grid asserts this
*executably* — every `error-retry` case produces the **same verdict under the pre-fix rule and the fixed
rule**, which is a sharper statement than a comment.

### A4. OQ2 — yes, the verdict row gains `window_unit`

`loop-index.sh:217` writes `window: $w`; after this change that number means calls in new rows and lines
in old ones, with nothing separating them. The spec records the precedent ("add nothing, fix the
wording") and the counter-argument (`agent_type: null` vs `"-"` was an *accidental* build marker, and
leaning on an accident twice is a choice). **Decision: add `window_unit: "calls"`.** One field, written
by the same `jq -nc` call that already writes `window`.

**`window` stays the REQUESTED `TAIL_N`, while the agent-facing message carries the COUNTED span, and
the two differ on a short ledger.** That is deliberate, and it is written down here because it reads
like an inconsistency: `window` answers "what setting was in force", which is the question a later
reader of the ledger has (`loop-index.sh:205-211` says so), and the setting does not change because the
ledger was young. The message answers "how far back did I actually look", which is the question the
agent being interrupted has, and quoting 20 when only 9 calls were judged would be the defect this
change is fixing, in a new place. A reader who "fixes" one to match the other breaks whichever question
it was answering, so neither is derived from the other. **The span is defined by the formula in § A5,
not by that example** — it counts the call being judged, so "8 prior calls" is a span of 9.

The reader side is where it earns its keep: `scripts/loop-metrics.sh:167`'s `settings` object is an
allowlist, so the projection becomes

```
window_unit: ($v.window_unit // (if ($v.window // null) == null then null else "lines" end))
```

— which encodes "a row that carries a window and no unit was written before the change, and meant
lines". Tier 2 and tier 3 rows carry no `window` (`loop-verdict.sh:97`, `:170`) and stay `null`.

### A5. Scope 3 / 3b — the agent-facing unit, and advice a sibling can act on

The three `why` strings at `:195` / `:198` / `:201` interpolate `TAIL_N`, and after A2 that number *is*
a call count, so "in the last %s steps" becomes true as written with no edit. **The edit is still
required**, because the window the agent is shown must be the window actually counted: the strings
interpolate the *requested* `TAIL_N`, while the span actually counted is smaller whenever the ledger
holds fewer than `TAIL_N` calls. The detector therefore returns the **counted call span** as a fourth
field and the strings interpolate that. AC2 and AC13 are assertions on this number, not on `TAIL_N`.

**The span formula is the contract, not the example above it.** Shipped at
`hooks/lib/loop-window.awk:59`:

```
span = min(calls_in_window, want_calls) + 1
```

The `+ 1` is the call being judged. **The ledger holds PRIOR calls only while the count is `n + 1`**, so
a span over prior calls alone is always at least one short of the count printed beside it. Measured on a
ledger with two prior identical calls: the shipped form emits `loop 3 1 3` — count 3, span 3 — where the
prior-only reading emits `loop 3 1 2`, i.e. *"has run 3 times within the last 2 steps"*, which cannot be
true of anything. The span is the span of the **judgement**: prior calls examined plus the one being
asked about, so `count <= span` holds always. User's decision, 2026-10-05.

**The wording clause follows from that, and it is NOT uniform across the arms.** `loop` and `fanout`
carry both numbers inclusive of the call being judged, so each gains a parenthetical saying so.
`error-retry` does **not**: its count is `fails`, prior failures only — the current call cannot have
failed yet — while its span is inclusive. A blanket "including the current one" makes that arm's
sentence false. **Test obligation:** the per-arm text is asserted per arm, including the negative one —
`error-retry`'s string must NOT claim its count includes the current call.

**`span` is read as `${4:-$TAIL_N}`, never bare** (`hooks/lib/loop-index.sh:160`). A bare `$4` under
`set -u` aborts the hook on a three-field verdict line, which breaks the file's own contract that no
failure path costs the session a tool call. A three-field line is exactly what the frozen control emits
(§ A1b), so the fallback is reached by a real caller, not only in theory; the covering case swaps the
frozen `.awk` into a relocated tree and requires a verdict at rc 0.

For AC14 the `fanout` string at `:198` loses "check whether one result can be reused" — advice whose
reader, a sibling subagent in its own context, has no handle on another agent's result. Proposed
replacement, with the binding part in bold:

> the SAME call has now been made by %s different agents (%s times in the last %s calls). That is fan-out
> duplication, not progress: each sibling pays full price for work a sibling already did. **Before
> approving, narrow this call to the part your own task needs — and if you cannot, say in your hand-back
> that a sibling already ran it, so the parent can stop re-issuing it.**

The wording is the implementer's; AC14 binds two things only — the text names an action available to the
agent it is shown to, and the arm still returns `permissionDecision: "ask"` exactly as `loop` and
`error-retry` do (`:226-227`). `fanout` does not become a quieter signal.

### A6. OQ5 — the canary rides in the ledger as a new row class

`hooks/lib/loop-agent-mark.sh`, wired on `SubagentStart`, appends one row per spawn:

```json
{"ts":"…","kind":"agent-mark","agent_id":"…","agent_type":"…"}
```

**Why the ledger and not a counter beside it.** AC16 requires the contradiction to be visible "from the
ledger alone"; a counter outside it, keyed by session, *is* a second ledger with none of the first one's
contract. And TC3's strict `kind` filtering means a new kind is invisible to the detector **by
construction** — `loop-index.sh:146` already reads `if (k != "call") next` — which is AC17 for free
rather than AC17 by inspection.

**Naming (TC12 + § Naming).** The script may not name itself with a reserved event-name word, and
`subagent-start.sh` is exactly the forbidden spelling. `loop-agent-mark` clashes with nothing in
`docs/claude-tools-hierarchy.md` §§1a/1b/2a/3a/3b and reads as what it is.

**`agent_id` / `agent_type` are recorded although the detection needs only a count.** They arrive free in
the verified payload, they mirror the fields a `call` row already carries, and when the canary fires they
say *which* agent type went missing. **The boundary, stated so it is not crossed later:** no reader may
join an `agent-mark` row to a `call` row. That join is read-time attribution, which Out-of-scope 1
forbids and which `--for` already does by the only honest route — a transcript scan.

**TC2.** Every path exits 0: absent `jq`, empty or malformed stdin, absent or non-string `session_id`,
unwritable ledger dir — the last of these **reports once per session rather than staying silent**, per
§ A12; exit 0 is the part of TC2 that is absolute, silence never was. Modelled on `loop-result.sh`,
which is 57 lines and already has exactly this shape. Note the one asymmetry: a `SubagentStart` hook has no `permissionDecision`, so the arm cannot
block a spawn even if it tried — but a non-zero exit still produces a blocking-error attachment, so the
discipline stands.

### A7. OQ6 — the canary surfaces in both views, computed once

`per_session()` gains three fields, so `--all` and `--for` read the same number (`--for` slurps
`per_session`'s output as `$side`):

```
agent_marks:      ([ $all[]   | select(.kind == "agent-mark") ] | length),
agent_mark_ids:   ([ $all[]   | select(.kind == "agent-mark") | .agent_id? // empty ] | unique | length),
call_agents_sub:  ([ $calls[] | .agent_id | select(. != null and . != "main") ] | unique | length)
```

The contradiction is `agent_marks > 0 and call_agents_sub == 0`, and it prints only then. In `--all` it
appends to the existing `per session:` line; in `--for` it joins the attribution block. **The gap is
widest in `--all`**, which runs no attribution recovery at all — that is the reason for answering OQ6
"both" rather than "`--for` only". No transcript is opened on either path; the `--all` path has no
transcript access by construction, which is how AC16's "without scanning any transcript" is asserted:
run the gate against a fixture directory with no transcripts in it at all.

The honest bound, stated in the reader's own prose: **zero recorded starts cannot distinguish "no
subagent ran" from "the canary itself is not firing."** The canary closes one direction only.

### A8. OQ3 — the grid's expectations are inline; the corpus baseline is a committed file

They are different kinds of number and belong in different places.

- **Grid expectations are a contract.** Each case declares `expect=fire|silent` beside itself; that
  declaration *is* the precision/recall definition, and splitting it from the case makes the table
  unreadable and the pairing (AC6's must-fire / near-miss columns) impossible to check by eye.
- **The corpus baseline is a measurement.** The post-fix firing count per window width against the real
  leg is observed, not designed, so it lives in `ai-docs/fixtures/loop-corpus/44f957de.baseline.json`
  and the gate diffs against it. AC10 is then literally a diff: the gate fails on an unexplained
  *change*, never on the count being greater than zero.

Measured today, to be re-derived at implementation time and committed as that file's content:
`{"20": 2, "26": 3, "40": 3, "100": 3, "unbounded": 3}` for the real leg under the fixed rule, and
`0` for the validation leg at `K = 20` under the pre-fix rule.

### A9. The frozen corpus — what is committed, and why one leg is generated

| Leg | Committed artefact | Size |
|---|---|---|
| Validation (real) | `ai-docs/fixtures/loop-corpus/44f957de.real.jsonl` — all 3999 rows, scrubbed | ~750 KB |
| Fanout (repaired) | **generated at run time** from the real leg + `44f957de.agents.tsv` (5 rows) | ~300 B |
| Baseline | `44f957de.baseline.json` | < 1 KB |

**The whole ledger is committed, not a slice.** A contiguous tail slice would preserve the interleaving
and the cluster's position, but it cannot carry AC9: the pre-fix rule is non-monotonic, so truncating the
prefix can *add* firings rather than remove them, and "0 firings over the full ledger" does not transfer
to a slice. The validation leg is only worth having if it is the thing the field actually recorded.

**The repaired leg is generated, and that is stronger than committing it.** AC11 requires the recovery to
be "reproducible from the committed inputs; the fixture is not hand-authored". A committed second copy is
an assertion that the derivation was run once; a derivation the gate performs on every run is the
derivation under test. The mapping file carries its own provenance in a header comment — the five
`tool_use_id → agent_id` pairs and the command that produced them. The transcripts themselves are not
committed (they live in `~/.claude`, they are large, and they carry conversation content); the gate never
needs them.

**The recovery RULE, not a path.** The mapping's provenance header records the rule and a *scrubbed*
command shape, never a literal path — `ai-docs/fixtures/loop-corpus/` is the exact directory AC18 greps,
and a literal `…/-Users-jc-projects-agent-harness/…` in a header is the needle AC18 looks for, planted
by the file that documents the scrub. The rule is the one `scripts/loop-metrics.sh --for` already uses
(`:244-250`, `:284-287`): *an id absent from the main transcript and present in
`subagents/agent-X.jsonl` was made by agent X.* The recorded shape is

```
grep -l <tool_use_id> "$CLAUDE_PROJECTS/<session-id>/subagents/agent-"*.jsonl
```

Re-verified for this design against the live tree: exactly one hit each, no collisions.

```
toolu_01RoPBifKp3PVYdAiHG6sRfj -> af4ff1f69e2639a73
toolu_01Bhd4qpLET4eeCULUvmnzb3 -> a5cb273d9231c4e41
toolu_017iTwzWXQuPHrytm6VN2zLz -> accd11a8a7a2a5db4
toolu_01NPa7a4CDXgWUnLD5KD32NT -> a10bba56a033ba9f7
toolu_0119rHsuZ18yobp4uoqtczff -> ae5cd4f6da35a54dc
```

Only `agent_id` is rewritten. The stored `transcript` pointer is left alone: the detector never reads it,
and rewriting it would make the fixture assert something about a field this change does not touch.

#### A9b. What is actually in the fixture — a field inventory, because "content-free" is too strong

The ledger's design intent is an index rather than a copy, and no *tool argument* is stored. But
"content-free" and "stores no arguments" are different claims, and the committed file has to be
described by the first. Measured over `44f957de`:

| `kind` | rows | keys | content judgement |
|---|---|---|---|
| `call` | 1728 | `ts`, `kind`, `agent_id`, `tool`, `fp`, `bin`, `tool_use_id`, `transcript`, `cwd` | no arguments; `bin` is a coarse bucket — **57 distinct values**, all command verbs (`bash`, `cat`, `cd`, …) or `Tool subtype` (`Agent harness:self-review`). The verb, never its operands. `cwd` / `transcript` carry the paths the scrub rewrites |
| `result` | 1715 | `ts`, `kind`, `tool_use_id`, `ok` | a boolean and a join key |
| `turn` | 529 | `ts`, `kind` | a marker |
| `verdict` | 27 | `ts`, `kind`, `tier`, `signal`, `scope`, `bin`, `repeats`, `turn_calls`, `judged`, `verdict`, `model`, `reason`, `min_bin_repeats` | **`reason` is free prose written by the tier-3 model**, present on **9 of the 27** |

A sampled `reason`: *"PROGRESS Distinct steps of a systematic validation checklist run—gates 2,5,5a,7
then smoke tests (6,8) interspersed with the test suite the AGENTS.md file prescribes."*

**Judgement: `reason` stays, unredacted.** It is a sentence about this repository's own gates, written
by a detector this repository ships, in a session spent developing this repository — it is the subject
matter, not a leak into it, and it is exactly the kind of row a reader of the fixture needs in order to
believe the fixture is real. It is also load-bearing for the replay: `verdict` rows are what AC8's
"a verdict row never counts itself" exercises natively.

**This design does not rest on the spec's TC5 sentence either way.** TC5 says "the payload itself is
content-free, so nothing else needs redaction"; on the measurement above that sentence is too strong
about `reason`, which is a question for the spec's owner and is being put to the user separately. The
design is written so that both outcomes are already handled: the scrub covers the two username
spellings and nothing else (the decision above), and if the spec later requires `reason` to be dropped,
the change is one `jq` filter in the fixture-build step of Task 5 plus one added assertion in AC18 —
no AC, no leg and no gate moves.

#### A9c. Size: committed uncompressed, and the option that was not taken

**Decision (user, 2026-10-05): commit it as is — plain JSONL, uncompressed.** The trade-off was measured
before the call, and is recorded here so the revisit has a baseline rather than a re-derivation:

| | before | after |
|---|---|---|
| tracked working tree | 1.8 MB | **~2.5 MB (+40 %)** |
| largest tracked file | 118 KB | **~750 KB** |
| `.git` | 2.4 MB | **~2.5 MB (+3 %)** — the ledger gzips **9.6×**, to 78 KB, and git packs it |

So the cost lands almost entirely on the *working tree*, not on clone size: git's own compression
already does to the object what a committed `.gz` would do to the file, which is why the compressed
option buys little where it would be paid for.

**Not taken, available later:** commit `44f957de.real.jsonl.gz` and have the gate `gunzip -c` it into a
temp file. It would hold the working tree near its present size at the cost of a binary blob that no
diff, `grep` or review can read — and the fixture's whole claim is that a reader can go and look at the
rows. Revisit if the working tree becomes a nuisance in practice; nothing in the design depends on the
encoding, because every consumer reads the fixture through one path resolved in one place.

### A10. Every fixture is compact JSON, and the grid proves it on itself

The detector matches with anchored regexes over the raw line — `"kind":"call"`, `"fp":"…"`, no spaces
(`loop-index.sh:145-150`). **A pretty-printed fixture therefore matches nothing**: every `kind` read
comes back empty, every row is skipped, and every `expect=silent` case passes while the suite measures
zero. The whole grid would be green and vacuous — the exact shape of the defect the spec opens with,
rebuilt inside the gate meant to catch it.

TC11 already says the `result` rows must be written "the way `loop-result.sh` writes them". **That
generalises to every fixture and every row class in this change:** one row per line, `jq -c` / `jq -nc`
or a `printf` of the same shape, never `jq .`, never a here-doc of indented JSON.

Pinned by a self-check rather than by the instruction alone — `scripts/test-loop-grid.sh` and
`scripts/test-loop-corpus.sh` each assert, before any case runs, that **every fixture they are about to
use yields at least one parsed `kind:"call"` row** through the detector's own extraction, and abort
naming the fixture if one does not. A gate that cannot see its input must say so rather than pass.

### A11. The fanout leg is asserted at TWO windows, not one

**Decision (orchestrator, 2026-10-05), and it is an addition rather than a spec change:** AC11 names no
window, so asserting a second one leaves its text true and needs no Spec Amendment.

| `K` | repaired leg, measured | why it is asserted |
|---|---|---|
| **20** (the shipped default) | **2 `fanout` firings, each `na = 3`** | the setting the branch actually ships with. Pinning only `K = 40` would leave it untested |
| **40** | 3 firings; the ordinal-1471 row is `fanout` with **`na = 5`** | AC11's five-subagent sentence, at a width inside the measured `26 ≤ K ≤ 355` band |

The pair is also the sharper statement. `na = 3` at the default and `na = 5` at 40 together show the
arm's count tracking the *window*, not a fixture constant — which a single assertion at one width
cannot distinguish from a hard-coded 5. And the `K = 20` leg is what makes the repair's user-visible
effect concrete: **on the current build this cluster fires as `fanout` at the default setting**, where
the pre-fix rule saw nothing at all.

**Scrubbing (TC5) — two spellings, not one.** Measured: 1728 rows carry `/Users/jc` in `cwd` and
`transcript`, and **the same 1728 carry `-Users-jc-`**, because the transcript directory encodes the
project path with `/` replaced by `-`. A scrub that fixes only the slash form leaves the username in every
row. Both are rewritten (`/Users/jc` → `/home/u`, `-Users-jc-` → `-home-u-`), and AC18's grep covers
`/Users/`, `-Users-` and `$HOME`.

**AC18's grep is scoped to the fixture directory, deliberately.** `README.md:280` already carries this
repo's own absolute path in a `claude --plugin-dir` example. A repo-wide grep is a guaranteed red that
says nothing about the fixtures, and widening AC18 to the repo is GH-76's job, not this PR's.

### A12. When the ledger cannot be written, say so ONCE

Found in Group C. `printf … >> "$ledger" 2>/dev/null` applies redirections left to right, so the open
fails *before* stderr is diverted and bash writes the error to the undiverted stream. Measured on the
shipped tree with a mode-500 ledger dir: `loop-index.sh` and `loop-result.sh` each leak the raw shell
error at **rc 0** — `…/loop-index.sh: line …: …/s1.jsonl: Permission denied`. **The leaked text embeds
the ledger path, so its byte length is a property of the path and never of the defect:** measured at
166, 102 and 101 bytes on three different temp dirs. The spread is the point — record the mechanism,
never a byte constant. The pre-extraction sites were `loop-index.sh:151`, `loop-index.sh:224` and
`loop-result.sh:56`; `loop-agent-mark.sh` already used `{ … } 2>/dev/null`, which is how its own suite
caught the class.

**Adding the braces everywhere was rejected, by the user, and the reason is this change's own thesis.**
An unwritable ledger means tier 1 is dead, and a detector dying where nobody notices is exactly the
failure class this PR exists to fix — the same shape as the canary, one layer down. Silence is the
wrong answer.

**The pre-existing leak is not a deliberate alarm either**, and this is recorded so nobody later
"restores" it as one: it fires only on the OPEN failure, so a disk-full mid-write stays silent; it
emits a raw shell error with a path rather than a sentence naming the detector as disabled; and it
repeats on every tool call for the rest of the session.

**Decision — report once, deliberately.** Detect the write failure in **both** modes; emit one clear
sentence per session naming tier 1 as disabled, why, and for which path; stay quiet afterwards. The
"once" marker cannot live in the ledger directory — that is the unwritable thing — so it goes in the
system temp dir keyed by session id, degrading to silence if that is unwritable too. **The file's
contract is otherwise unchanged:** exit 0 on every failure path, stderr only, never a non-zero exit and
never a `permissionDecision`. **One shared implementation under `hooks/lib/`**, not three or four
copies — copies of one rule that must agree is the hazard § A1 already rejects for the detector.

**As shipped, re-derived by `grep -n`. Every number below is an as-of reading, not a durable address.**
The `loop-index.sh` column has already rotted once inside this very table: it was grepped, not computed,
and it was right when measured — then the file grew five lines and `:134`/`:168`/`:245` became
`:139`/`:173`/`:250`. **A correctly measured anchor certifies the moment of measurement, not the file**,
so re-derive at the point of use even when the table says it was derived. The three other files have not
moved since.
The helper is **`hooks/lib/ledger-write.sh`** (not `loop-ledger-write.sh`, which never existed) and it
exports two functions, `harness_ledger_append` at `:30` and `harness_ledger_report_once` at `:55`. Each
caller sources it and defines a brace-form `harness_ledger_append` fallback if it cannot be sourced, so
an absent helper degrades to the silent-but-correct append rather than to a broken hook.

| File | Append sites | `mkdir` guard |
|---|---|---|
| `loop-index.sh` | `:173`, `:250` | `:139` |
| `loop-result.sh` | `:69` | `:66` |
| `loop-agent-mark.sh` | `:72` | `:71` |
| `loop-verdict.sh` (Scope 9) | `:88`, `:127`, `:214` | — |

**The `mkdir -p` guard is the fourth site class, and it is not redundant with the write check** — this
went further than the three append sites the document first named, correctly. A directory that cannot be
CREATED disables the detector exactly as surely as one that cannot be written, so covering one and not
the other rebuilds the partial alarm this change replaces. Neither check subsumes the other, and the
shipped comment at `loop-agent-mark.sh:66-69` states why in both directions: `mkdir -p` returns 0 on a
directory that already exists *whatever its mode*, and an unwritable directory still permits an append
to a ledger file created while it was writable. Both route to the same one-per-session report.

**The vacuous test is repaired regardless of which behaviour had been chosen.**
`hooks/lib/test-loop-index.sh:690-691` is named "an unwritable ledger dir -> 0, silently", discards
stderr and asserts only the exit code, so it cannot see which of the two behaviours is in force. The
word "silently" in that name is checked by nothing — the same vacuous-control class Group A found and
repaired elsewhere. It now asserts the stderr content as well as the status, and that the second call
in the same session is quiet.

**THE TRIGGER IS THE FILE, NOT THE DIRECTORY, AND THE OBVIOUS TRIGGER IS VACUOUS FOR `loop-verdict.sh`.**
Measured three times — by the coordinator, by the spec-writer and independently here. An unwritable
ledger **directory** leaves no ledger file at all, so `loop-verdict.sh:81`'s `[ -s "$ledger" ] || exit 0`
returns before any append is attempted:

| trigger | `loop-verdict.sh` result |
|---|---|
| unwritable **dir**, no ledger file | rc 0, **stderr empty** — exits at `:81`, nothing measured |
| unwritable **file**, present and non-empty (mode 444) | rc 0, the one-sentence report on stderr |

So any suite for Scope 9's sites written to the directory trigger passes while exercising nothing. **Every
verification recipe for `:88` / `:127` / `:214` must name a present, NON-EMPTY, mode-444 ledger file.**
This is this repo's own named hazard — an admission filter keyed on the very property that separates a
real finding from a dismissable one — and `loop-verdict.sh:57`'s comment already warns that `[ -s ]`
tests existence and size and never writability. The directory trigger stays valid for `loop-index.sh`,
`loop-result.sh` and `loop-agent-mark.sh`, which have no such pre-read gate; it is specifically the
tier-2 writer that needs the file-level one.

**THE REPORT-ONCE MARKER IS A SECOND ADMISSION FILTER OF THE SAME SHAPE, AND IT IS THE LOAD-BEARING
CONSTRAINT ON EVERY NEGATIVE ASSERTION.** The decision above buys silence-after-the-first-report with a
marker — `mkdir "${TMPDIR}/harness-ledger-warned-<session>"` as an atomic test-and-set — which is keyed
on **the very property every assertion about the report depends on**, and which **persists across
processes by design**. That is the same hazard this section already names one layer up, reintroduced by
the fix for it.

**Constraint: in any assertion whose premise is "the report did not fire", the marker slot MUST be
provably free at the moment of the measured call.** A consumed marker and a healthy ledger are
indistinguishable from outside — both produce exactly no output — so an assertion that cannot establish
that is measuring nothing and will pass for as long as it exists. The slot's state is part of the
assertion, not setup hygiene around it.

**Two routes establish it. Either is sufficient; which one a case needs is decided by its own setup.**

- **Route A — by construction.** The measured call is the **first** ledger write inside a namespace
  nothing has yet had the chance to spend: a `TMPDIR` fresh per run, or fresh per case. No explicit
  freeing is needed, because there is no earlier write that could have claimed the slot.
- **Route B — explicitly, and then asserted.** Free the slot immediately before the measured call and
  **assert that it is free**. Required whenever anything runs between the namespace being created and
  the measurement — which is the common case, because a case that seeds state seeds it by invoking the
  very hook under test.

**Route A is not the weaker option; it is the narrower one, and its precondition is easy to lose.** A
case that qualifies today stops qualifying the moment an earlier case, or its own seeding, writes first
— and nothing in the suite announces that. So Route B is the default for any case with setup, and a
Route A case is worth a comment saying *why* it qualifies.

**Why a fresh namespace alone is not always enough — the non-obvious half, and the reason this was
`major` rather than a nit:** the generic rule that *a control arm gets freshly-built state* **was
followed in the `test-loop-verdict.sh` control, and was still insufficient**, because the setup inside
that fresh namespace spent the slot before the measurement: seeding eight tier-1 calls means any one of
them claims it under a defect that reports on success — exactly the defect the control exists to catch.
Measured: with the per-case `TMPDIR` in place and only the slot-freeing lines removed, a planted
report-on-success defect leaves that control **green**.

**Which route each shipped case takes, established by plant rather than by reading** — the plant put
`harness_ledger_report_once` into the success branch and each suite was required to go red:

| Case | Route | Plant result |
|---|---|---|
| `test-loop-verdict.sh`, the writable-ledger control | **B** (per-case `TMPDIR` + explicit freeing + precondition) | red, as required |
| `test-ledger-write.sh:60` | **A**, with a per-case `fresh_tmp` — the measured `call_append` is the first write in it | red; the single failure in 39/1 |
| `test-loop-agent-mark.sh:121` | **A**, on a per-run namespace — the measured payload is the first write in it | red; the single failure in 76/1 |

The last two do **neither** of the steps an earlier draft of this section made mandatory, and are
nevertheless sound. That draft shipped its own two counterexamples, which is how a MUST decays into
something read as aspirational: a reader who checks it against the tree finds it false twice and learns
to discount the rest. The rule above is true of the tree and still errs toward more marker control, so
nobody following it can reach a vacuous assertion.

Measured instance, now repaired: `test-loop-verdict.sh`'s negative control under the banner *"and a
writable ledger is unaffected, which is what makes the above a finding"* **could not fail** — the suite
exported one `TMPDIR` for its whole run and its `reset()` cleared the ledger directory but never the
marker, so by the time the control ran the marker was already consumed. The banner stated the control's
purpose correctly and the body could not serve it. It now carries both steps, and the rule is recorded
here as well as in that file's own comment **because a suite in a different file inherits the document,
not the comment** — which is why the design, not the suite, is where this has to live.

**The scope of this constraint is the mechanism, not that one suite.** Any future suite, any future
assertion about a quiet run, and any case ordering that puts a failure case before a health case inherits
it; a marker that survives a `reset` is a cross-case channel in a file whose cases otherwise look
independent.

**On the two skipped design-review rounds, recorded because the user asked and because the answer is not
uniform.** Both were a user decision and both are reported as **skipped, never as passed**. They did not
cost the same:

| Skipped round | Verdict with hindsight |
|---|---|
| § A5, the span formula | **Would not have earned its keep.** The formula was confirmed sound at every width on an independent sweep. |
| § A12, this section | **Would have earned its keep.** A12 caught one admission filter and missed the second one its own fix introduced — the gap above, which reached a negative control in a shipped suite. A reviewer reading A12 against the mechanism was the step that would have found it. |

The point of recording which one cost something is to make the next such decision informed rather than
to re-litigate either. A12's own history is the argument for reviewing a section that *introduces a
mechanism*, and against reviewing one that only states a formula already measured.

---

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **Extract the detector, no behaviour change — and freeze a copy as the control.** Move the awk at `loop-index.sh:123-185` into a new `loop-window.awk`; resolve it from `$0` as `HERE_JQ` already is; guard an unreadable program so the verdict is empty **and the ledger append still happens**. **In the same commit, copy it byte-for-byte to `loop-window-prefix.awk` and commit the two-line `loop-window-prefix.sh` wrapper that feeds it `tail -n K` LINES** — together they are the frozen pre-fix control four ACs rest on, and the wrapper is what makes the feed a committed fact rather than a sentence (§ A1b). The `.awk` header's first line forbids ever updating it to match its sibling; neither file is named by any hook. `test-loop-index.sh` must pass unmodified — it is the regression net for this move. Add five cases: the program renamed away (row still written, rc 0), an `awk -f <prog> </dev/null` parse check for **both** programs, an assertion that `hooks.json` names neither frozen file, the wrapper shown to pass `tail -n K` lines (not calls) to the `.awk`, and — **owning the `$0`-resolution risk, which nothing else in this design covers** — a **relocated-tree case**: copy `hooks/lib/` to a temp dir, invoke `loop-index.sh` *from the copy* against a seeded ledger, and require a verdict to still come out. Chosen over adding `hooks/lib/*.awk` to gate 6's payload check because that gate `exit 2`s wherever the `claude` CLI is absent, and the dependency tier 1 now rests on deserves an owner that always runs; it also tests resolution rather than mere presence. The field-measurement check on the real corpus belongs to Task 6, which is where the fixture exists. | `hooks/lib/loop-index.sh`, `hooks/lib/loop-window.awk` (new), `hooks/lib/loop-window-prefix.awk` (new), `hooks/lib/loop-window-prefix.sh` (new), `hooks/lib/test-loop-index.sh` | — |
| 2 | **Count the window in calls.** awk-side bound to the last `TAIL_N` call rows; shell-side adaptive chunk (`TAIL_N * 3`, `RETRY` token, double on short chunk, terminate on `NR < m`). Return the **counted call span** as a fourth field. Update `test-loop-index.sh`'s window section to interleave `kind:"result"` rows written the way `loop-result.sh` writes them (TC11, compact per § A10). **The positive control is `loop-window-prefix.sh`, not a restored `tail -n` and not the bare `.awk`** — the tail alone leaves the awk call-bounded, so the chunk is short, `RETRY` fires, the shell widens, and the case passes with the defect absent; the `.awk` alone reverts the anchor but keeps the new unit (§ A1b). | `hooks/lib/loop-window.awk`, `hooks/lib/loop-index.sh`, `hooks/lib/test-loop-index.sh` | 1 |
| 3 | **Monotonic dismissal + the agent-facing unit + the fanout advice.** Re-anchor `:183` on `m_{n-(thr-2)}`; interpolate the counted span into the three `why` strings; reword the `fanout` advice (AC14); add `window_unit: "calls"` to the verdict row. | `hooks/lib/loop-window.awk`, `hooks/lib/loop-index.sh`, `hooks/lib/test-loop-index.sh` | 2 |
| 4 | **The variation grid.** New suite: **nine** axes, each with a must-fire case **and** its near-miss, a confusion matrix per axis, non-zero exit on a precision **or** recall regression. The ninth, `dismissal anchor`, is the 15-row mutation × cluster-position fixture that is AC3's grid-side positive control (§ Measurements) — none of the other eight can break the pre-fix rule at a realistic width. Plus the four properties — monotonicity, idempotence, verdict-never-counts-itself, and error-retry invariance against the frozen control, invoked as `loop-window-prefix.sh` and never as the bare `.awk` (§ A1b). Fixture encoding and the pre-run self-check per § A10. Drives the real hook end to end, by path, with an `[ -x ]` assertion. | `scripts/test-loop-grid.sh` (new) | 3 |
| 5 | **Build and commit the corpus fixtures.** Snapshot `44f957de`, scrub both username spellings, commit the real leg **uncompressed** (§ A9c); derive and commit the 5-row mapping, whose provenance header records the recovery RULE and a scrubbed command shape, never a literal path (§ A9); derive and commit the baseline file. **Its values are MEASURED from the committed fixture, never copied from this document** — `{20:2, 26:3, 40:3, 100:3, unbounded:3}` are 2026-10-05 figures and the fixture is a snapshot taken later. Copying them makes AC10 a tautology: the gate would be comparing the design's numbers against the design's numbers, so a fixture that differs from the snapshot goes unnoticed in exactly the direction AC10 exists to catch. Same rule for every other number this task writes down. | `ai-docs/fixtures/loop-corpus/44f957de.real.jsonl`, `…/44f957de.agents.tsv`, `…/44f957de.baseline.json` (all new) | 3 |
| 6 | **The frozen-corpus replay gate.** New suite: generates the repaired leg from the committed inputs; **first asserts `loop-window-prefix.sh` still reproduces the field measurement** (`K` in LINES: 20 → 0, 40 → 2, 100 → 3, unbounded → 0 — the call feed gives 2/3/3 and would fail this check, § A1b), so the control is itself controlled; validation leg under that frozen rule at the shipped window → 0; fixed rule against the committed baseline; repaired leg at `K = 40` → `fanout`, `na = 5` **and at `K = 20` → `fanout`, `na = 3`** (§ A11); the same rows `loop` on the real leg (AC12); monotonicity over both legs; the scoped `/Users/` grep. | `scripts/test-loop-corpus.sh` (new) | 5 |
| 7 | **The canary writer, and the ledger-write report.** Probe the live `SubagentStart` payload in a throwaway `CLAUDE_CONFIG_DIR` and record what arrives; write `loop-agent-mark.sh`; add the `hooks.json` arm; write its suite (TC2 paths, AC17 with/without replay). **Plus § A12:** the shared `hooks/lib/ledger-write.sh` (`harness_ledger_append` + `harness_ledger_report_once`) detecting a failed ledger write in both modes and reporting once per session (marker in the system temp dir, keyed by session id); convert every append site **and every `mkdir -p` guard** to it — the guard is the fourth site class and is not redundant with the write check (§ A12); **Scope 9** routes `loop-verdict.sh`'s three appends through it as well, with the file-level trigger § A12 requires; repair the vacuous `test-loop-index.sh` unwritable-ledger case to assert the stderr text and the silence of the second call. | `hooks/lib/loop-agent-mark.sh` (new), `hooks/lib/ledger-write.sh` (new, § A12), `hooks/lib/test-ledger-write.sh` (new), `hooks/hooks.json`, `hooks/lib/loop-index.sh`, `hooks/lib/loop-result.sh`, `hooks/lib/loop-verdict.sh`, `hooks/lib/test-loop-agent-mark.sh` (new), `hooks/lib/test-loop-index.sh` | 3 |
| 8 | **The canary reader.** `per_session()` gains the three fields; the contradiction prints in `--all` and `--for`; `settings.window_unit` joins the projection. Extend `test-loop-metrics.sh` with the contradiction, its negative control, and the no-transcript assertion. | `scripts/loop-metrics.sh`, `scripts/test-loop-metrics.sh` | 7 |
| 9 | **Prose, registration, propagation, release.** `claude-tools-hierarchy.md`: the `~20 steps` wording at `:101`, a `SubagentStart` row in § Project-defined Hooks, the §3b snapshot note, and the stale "two record classes" sentence at `:110` (four today, five after this change). `ai-docs/context.md` GH-72 entry per Scope 6. `AGENTS.md` check-4 list gains three suites. `test-hook-behaviour.sh`: triple count 19 → 20, a TABLE row, a `payload_for` case. `test-install-smoke.sh`: `SubagentStart` joins the event list **and gains a count assertion** — today that loop is presence-only, so an event missing from the list leaves it green (§ Risks). Inspect group (TC8b): `skills/inspect/SKILL.md` and `agents/inspector.md` learn the canary line and `settings.window_unit`; `scripts/session-events.sh` is checked and expected to need nothing (§ Risks). **Both occurrences of "every failure path exits 0 silently" in `claude-tools-hierarchy.md` become partly false under § A12** — the exit status is still 0, the silence is now one sentence per session — so the hook-contract group (TC8) covers them too. `plugin.json` patch bump. Full gate sequence. | `docs/claude-tools-hierarchy.md`, `ai-docs/context.md`, `AGENTS.md`, `scripts/test-hook-behaviour.sh`, `scripts/test-install-smoke.sh`, `.claude-plugin/plugin.json`, `skills/inspect/SKILL.md`, `agents/inspector.md` | 4, 6, 8 |

**On the "> 7 tasks → propose splitting" rule.** Nine is over the bar and the split is nevertheless
foreclosed, for two reasons that are not preference. The spec's first Key decision is the user's binding
joint-scope call ("One change, one PR"), recorded as not to be re-litigated. And AC9 / AC12 make the
corpus gate a guard on the repair itself — landing the repair without it ships the change whose silent
reversion the gate exists to catch, and landing the gate first means committing a suite that is red by
design. The three-group handoff below is the mitigation.

---

## Handoff plan

`M = 9`. Three groups of exactly 3; the terminal group is 3, inside the required `1..3`.

- **Entry into Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`
  before subtask 1.
- **Group A:** subtasks 1–3 — the detector. Extraction plus the frozen control, call-counted window,
  monotonic dismissal plus the wording and `window_unit`. Ends with `hooks/lib/test-loop-index.sh` green
  and the positive controls demonstrated to fail.
  **Read for this group:** §§ A1, A1b, A2, A3, A4, A5, and AC1–AC5 / AC13 / AC14 in § Test Design.
  **Carry into the group:** the frozen control is `loop-window-prefix.sh`, `K` in LINES (§ A1b); every
  positive control in subtasks 2 and 3 runs it, and the bare `.awk` is the wrong entry point.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh
  context. **Carry forward:** the final `loop-window.awk` field protocol (the four-field verdict line and
  the `RETRY` token), because Group B's two suites are written against it — **and that the frozen control
  is invoked as `loop-window-prefix.sh`, `K` in LINES, never as the bare `.awk`** (§ A1b).
- **Group B:** subtasks 4–6 — the coverage. Grid, fixtures, corpus gate. Ends with both new suites green
  and the baseline file committed.
  **Read for this group:** § Measurements (the `dismissal anchor` fixture and why the narrow sweep is
  non-discriminating), §§ A1b, A8, A9, A9b, A9c, A10, A11, the grid-axis table, and AC1–AC13 / AC18.
- **Handoff after Group B:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group C with fresh
  context. **Carry forward:** the baseline numbers actually measured (they will differ from this
  document's if the fixture snapshot differs) and the exact new suite filenames, which Group C registers.
- **Group C:** subtasks 7–9 — terminal group (3 subtasks; within the `1..3` range). Canary writer, canary
  reader, then prose / registration / propagation / release.
  **Read for this group:** § Measurements (the verified `SubagentStart` payload), §§ A6, A7, the last
  four § Risks entries, and AC14–AC22.

---

## Risks

- **A missing or unparseable `loop-window.awk` silently disables tier 1.** The extraction trades an
  inline program for a file dependency. Mitigation: the guard wraps the detector call only, never the
  ledger append; Task 1 adds the renamed-away case and a parse check. Residual: an `.awk` file is
  invisible to the `bash -n` gate and to `shellcheck`, so the parse check inside the suite is the only
  syntax gate it gets. Say so in the file's own header.
- **`awk -f` path resolution from an installed plugin.** `${CLAUDE_PLUGIN_ROOT}` is not a fixed path, and
  the extraction makes tier 1 depend on a file *arriving beside* the hook. "Works in the repo, silently
  detects nothing once installed" is the same class as the version-keyed-cache failure that produced
  GH-86. Mitigation: reuse the `cd -- "$(dirname -- "$0")"` idiom already at `:61` — **owned by Task 1's
  relocated-tree case**, which is the only assertion in this design that runs the hook from anywhere but
  the repo. Nothing else covers it: gate 6 enumerates skills, agents and hook *events*, never
  `hooks/lib/` payload files.
- **The chunk factor 3 is a performance hint that will read as a contract.** A later reader may "fix" the
  retry away as dead code. Mitigation: AC2b's positive control is a fixture with a lines-per-call ratio
  above 3 (a turn-heavy session; the corpus already spans 1.04 … 2.37), and the control deletes the retry
  branch and requires the count to go wrong.
- **The corpus is live and the fixture is a snapshot of one moment.** `44f957de` has not been written
  since 2026-10-04 16:02, so it is stable — but the *derivation* is from a tree that may prune
  `~/.claude/projects/`. Mitigation: the mapping is committed; the transcripts are never read by the gate.
- **~750 KB of fixture enters the repo.** Decided and closed (§ A9c): committed uncompressed, +40 % on
  the working tree and +3 % on `.git`. The compressed variant is recorded there as available and not
  taken.
- **A ledger that is simultaneously large and call-poor degenerates the window read.** The adaptive
  chunk doubles until it has `TAIL_N` calls; a file of, say, 50 000 rows holding 15 calls ends in a
  whole-file read *plus* ~log₂ partial scans before it — strictly worse than the ring buffer § A2
  rejects. **No realistic path to that shape was found**: `result` rows are bounded by calls, `turn`
  rows by stops, and the worst ratio in the corpus is 2.37 against a theoretical floor of 1.0, so the
  shape needs an unbounded non-call writer that does not exist. Named rather than designed against,
  because the cost of guarding it (a cap, which would silently truncate the window) is worse than the
  risk. Revisit if a fifth row class is ever written per-something-other-than-a-call — the canary is
  per *spawn*, which is rarer than calls, so it does not move this.
- **`docs/claude-tools-hierarchy.md:110` is already wrong** — it says two record classes where four exist.
  The canary makes it five. Fixing the sentence this change invalidates is inside TC8's class; leaving it
  would ship a contract document that contradicts TC3 of the spec that produced it.
- **Two sync obligations that no gate names — and only ONE of them is self-announcing.** The first draft
  said both go red on a new arm; that is wrong about the second, and the wrong half is the half a future
  hook change would lean on.
  - `scripts/test-hook-behaviour.sh:140` asserts a hard-coded `19` triples derived from the manifest, so
    a new arm **does** turn it red. Self-announcing.
  - `scripts/test-install-smoke.sh:85` loops over a hard-coded event list asserting each is **present**
    in the install inventory. There is no count and no converse assertion anywhere in that file, so an
    event the manifest registers and the list omits leaves it **green**. It is not a gate on the
    manifest at all, only on the install. **Silent.**

  Task 9 therefore both adds `SubagentStart` to that list *and* gives it a count assertion — the
  registered-event count read off `hooks/hooks.json` must equal the number the loop checked — so the
  next hook arm announces itself instead of relying on whoever edits the file next having read this.
- **`scripts/session-events.sh` is an Inspect-group member (TC8b) and appears in no task's file list.**
  That is believed correct, not overlooked: it reads transcripts, never the ledger, so neither the new
  row class nor `window_unit` reaches it. The group fires on "either reader's emitted FIELDS", and its
  fields do not move. Task 9 checks it explicitly and records "no change needed" rather than leaving the
  fourth member unaccounted for — a group member silently skipped is how the Spec-Amendment group's last
  member went years without a sweep.
- **`check-propagation-arms.sh` treats `hooks/hooks.json` as a silent control.** The propagation reminder
  deliberately does not fire on it, so the hook-contract obligation to update
  `claude-tools-hierarchy.md` arrives with no nudge at all. The only control is Task 9 and AC20.
- **`window_unit` enters an allowlist projection** (`loop-metrics.sh:167`). A field the hook writes and
  the projection omits is dropped in silence — the same class as TC3b. Task 8 is where both land.
- **The canary is one-directional.** Zero recorded starts cannot separate "no subagent ran" from "the
  canary is not firing". No mitigation is available from the ledger; the reader's prose states the bound
  instead of implying coverage it does not have.
- **`docs/claude-tools-hierarchy.md` grows.** 25320 chars today against the 35000 early-warning line; the
  `loop-index` bullet is already the longest in the file. Mitigation: the `SubagentStart` row is a bullet,
  not an essay, and Task 9 re-runs `wc -c`.

---

## Test Design

**Framework:** project default, applied silently per the spec's last Key decision — a `bash …/test-….sh`
script with the `ok` / `bad` / `check` / `has` / `hasnt` helpers that `hooks/lib/test-loop-index.sh:17-21`
already defines, run bare as its own gate. No new framework, no new helper names.

**House rule carried into every new suite:** each guard carries its own **positive control** that defeats
the guard and requires the damage to reappear (`test-loop-index.sh:5-9`). A grid whose every fixture
fires measures the implementation, not the settings — which is the defect the spec opens with.

**Entry points.** The grid drives `hooks/lib/loop-index.sh` end to end, by path, the way `hooks.json`
invokes it — including an `[ -x ]` assertion on the committed mode, because the convenient
`bash <path>` spelling does not need the executable bit. The corpus gate drives
`hooks/lib/loop-window.awk` directly, for the reason in § A1. The canary suite drives
`hooks/lib/loop-agent-mark.sh` by path and asserts its mode too.

### New fixtures

| Fixture | Shape | What only it can see |
|---|---|---|
| `ratio-1.0` | calls only, no `result` rows — the `74da1c95` shape | the lower end of AC2b |
| `ratio-2.4` | one `result` per call plus `turn` rows — the current shape (TC11) | AC1: lines ≠ calls, which `test-loop-index.sh:342-350` cannot see today |
| `ratio-5` | `turn`-heavy; more than 3 lines per call | forces the `RETRY` path; the AC2b positive control deletes the retry branch and requires the count to go wrong |
| `anchor-15` | 15 rows: old match, mutation, 10 fillers, tight recent cluster | **breaks the pre-fix rule at `K = 14`** — the only fixture here that does so at a realistic width (§ Measurements) |
| `44f957de.real.jsonl` | the field's own rows, scrubbed | defect 1's interleaving natively — 1715 `result` rows against 1728 `call` rows |
| repaired leg | generated from the real leg + the 5-row mapping | AC11 / AC12 |

All of them compact, one row per line, per § A10 — and each checked for at least one parsed
`kind:"call"` row before any case runs.

### The grid's axes (AC6), each with its near-miss

| Axis | Must fire | Must stay silent |
|---|---|---|
| call identity | same tool, same `fp`, ×3 | same tool, different `fp`; different tool, same `fp` |
| intervening mutation | succeeded repeats, no mutation inside the counted span | succeeded repeats with an `Edit` between the counted matches (AC4) |
| outcome | ≥ `RETRY_MIN` failures, mutations notwithstanding (AC5) | one failure only |
| agent multiplicity | 3 distinct `agent_id`s on one `fp` → `fanout` | 3 calls, one agent → `loop`, not `fanout` |
| sparsity | 3 matches inside `K` calls | 3 matches spanning more than `K` calls |
| cluster position | the cluster at the ledger tail | the same cluster followed by `K` unrelated calls |
| time | rows minutes apart (tier 1 keys on position, never on `ts`) | — the control is that a time gap changes **nothing**, asserted as a non-difference |
| ledger schema | rows carrying `kind` | rows with no `kind` field (a pre-`kind` build) are skipped, not guessed at (TC3) |
| **dismissal anchor** | the 15-row shape of § Measurements at `K = 14`: old match, mutation, tight recent cluster | the same shape with the mutation moved *inside* the recent cluster — then the dismissal is correct and both rules agree |

**The ninth axis is not a ninth case of the same kind.** The other eight vary one factor; this one is
*mutation × cluster position combined*, and that combination is the only one that breaks the pre-fix
rule at a window width anyone would type (§ Measurements). It is AC3's grid-side positive control, and
without it AC3's grid half is satisfied by a rule that is already broken.

Each axis prints `tp / fp / tn / fn`; the suite exits non-zero when either precision or recall falls
below the committed expectation for that axis.

### AC verification

| AC | Verified by |
|---|---|
| AC1 | `bash scripts/test-loop-grid.sh` — axis *call identity* on `ratio-2.4` at `HARNESS_LOOP_TAIL=K`, asserting exactly the last `K` call rows are considered; **positive control runs `hooks/lib/loop-window-prefix.sh`** (the wrapper, `K` in LINES) and requires the same case to fail. Two spellings that do **not** work and must not be used: a restored `tail -n "$TAIL_N"` alone (the awk is call-bounded by then, so the short chunk emits `RETRY` and the shell widens back), and the bare `.awk` fed calls (reverts the anchor, keeps the new unit — so it proves nothing about a unit). § A1b |
| AC2 | `bash scripts/test-loop-grid.sh` — on `ratio-2.4`, the number in "in the last %s steps" equals the counted call span, asserted for `loop`, `fanout` and `error-retry` |
| AC2b | `bash scripts/test-loop-grid.sh` — `ratio-1.0`, `ratio-2.4` and `ratio-5` at one `K` all count the same number of calls; positive control deletes the `RETRY` branch and requires `ratio-5` to come out short |
| AC3 | **Two halves, each with its own control, because one sweep cannot serve both. Every control run is `loop-window-prefix.sh`, `K` in LINES (§ A1b); the fixed rule is swept in CALLS, its own unit.** Grid half: `bash scripts/test-loop-grid.sh` — firing count non-decreasing as `K` widens (unbounded = `K` ≥ the fixture's call count), with the **`dismissal anchor` axis as the positive control**: the control must score 1,1,1,1,**0,0** across `K = 3/5/10/13/14/20` while the fixed rule scores 1,1,1,1,1,1. Corpus half: `bash scripts/test-loop-corpus.sh` — the same sweep over both legs, with the control reproducing 20 → 0, 40 → 2, 100 → 3, unbounded → 0. **The sweep range is part of the assertion:** a sweep confined to small `K` is satisfied by the broken rule (measured — the control scores 0 violations over `K = 1..80`), so the corpus half must reach **past `K = 760` lines**, the control's true first break, and the grid half must include `K = 14` on the anchor fixture |
| AC4 | `bash scripts/test-loop-grid.sh` — axis *intervening mutation*, near-miss column |
| AC5 | `bash scripts/test-loop-grid.sh` — every *outcome*-axis case yields the **same verdict under `loop-window-prefix.sh` (lines) and under the shipped hook (calls)**, which is the executable form of "unchanged". The feed matters here too: `fails` is counted over the `result` rows the window admits, so "same verdict under both" is undefined until each side's window is pinned — each runs in its own unit, which is the comparison the AC actually means. Plus the existing fix-break cases in `bash hooks/lib/test-loop-index.sh` |
| AC6 | `bash scripts/test-loop-grid.sh` — the confusion matrix is printed per axis and the gate is shown non-zero against a planted defect (a detector stub that fires on everything must fail on precision; one that never fires must fail on recall) |
| AC7 | `bash scripts/test-loop-grid.sh` — property: the same ledger replayed twice yields identical verdicts |
| AC8 | `bash scripts/test-loop-grid.sh` — property: a verdict row is not counted as a call (the 4-calls-reads-as-6 control from `test-loop-index.sh:144-147`, moved into the property set and kept there too) |
| AC9 | `bash scripts/test-loop-corpus.sh` — validation leg through `hooks/lib/loop-window-prefix.sh` at `K = 20` **lines** → 0 firings. Measured while writing this design: **0** (the same awk fed 20 *calls* gives 2, which is why the wrapper and not the `.awk` is the entry point — § A1b). Preceded by the control-of-the-control: the wrapper must still reproduce 20 → 0, 40 → 2, 100 → 3, unbounded → 0, so a rotted control fails loudly instead of weakening this leg. The leg's own comment and test name must not read as a cap on the fixed detector |
| AC10 | `bash scripts/test-loop-corpus.sh` — fixed rule against `ai-docs/fixtures/loop-corpus/44f957de.baseline.json`; a diff, not a threshold. Measured: `{20: 2, 26: 3, 40: 3, 100: 3, unbounded: 3}` |
| AC11 | `bash scripts/test-loop-corpus.sh` — repaired leg at **two** windows (§ A11): at `K = 40` the ordinal-1471 call classifies `fanout` with `na = 5` (band re-derived here: `na = 5` for `26 ≤ K ≤ 355`), **and at the shipped default `K = 20` there are 2 `fanout` firings, each `na = 3`** — the cluster spans 26 calls, so `na = 5` is unreachable at 20 and asserting only `K = 40` would leave the shipped setting untested |
| AC12 | `bash scripts/test-loop-corpus.sh` — the same row is `loop` on the real leg and `fanout` on the repaired one, asserted as a pair |
| AC13 | `bash scripts/test-loop-grid.sh` — the planted true loop at the shipped default, with the message's number equal to the counted call span |
| AC14 | `bash hooks/lib/test-loop-index.sh` — the emitted `fanout` text no longer contains "one result can be reused", does contain the action clause, **and** the same output carries `"permissionDecision":"ask"` |
| AC15 | `jq -e . hooks/hooks.json`; `bash hooks/lib/test-loop-agent-mark.sh` (empty stdin, malformed JSON, absent `session_id` — each rc 0 and silent; **unwritable ledger dir — rc 0 and exactly one reporting sentence per session, per § A12, not silence**); `bash hooks/lib/test-ledger-write.sh` for the shared writer itself, and `bash hooks/lib/test-loop-verdict.sh` for Scope 9's three sites — **the latter with a present, non-empty, mode-444 ledger FILE, because the directory trigger exits at `loop-verdict.sh:81` and measures nothing** (§ A12). **Every case asserting the report did NOT fire establishes a provably free marker slot at the measured call**, by § A12's Route A (the measured call is the first write in a fresh namespace) or Route B (free it immediately before and assert it) — Route B wherever the case has setup of its own, because a consumed marker is indistinguishable from a healthy ledger; `bash scripts/test-hook-behaviour.sh` (the triple count reads 20 and the new arm has a marker row); `bash scripts/test-install-smoke.sh` (`SubagentStart` in the installed inventory **and** its new count assertion — the presence loop alone would stay green on an omission, § Risks) |
| AC16 | `bash scripts/test-loop-metrics.sh` — a fixture with N `agent-mark` rows and zero non-`main` call rows reports the contradiction; the negative control (starts and non-`main` rows agree) reports nothing; both run against a ledger dir with **no transcripts present**, which is how "no transcript scan" is asserted rather than asserted-about |
| AC17 | `bash hooks/lib/test-loop-agent-mark.sh` — the same fixture with and without `agent-mark` rows yields byte-identical verdicts; `bash scripts/test-loop-metrics.sh` — identical report except the three new fields |
| AC18 | `bash scripts/test-loop-corpus.sh` — first assertion: zero hits for `/Users/`, `-Users-` and `$HOME` **scoped to `ai-docs/fixtures/loop-corpus/`**, which covers the mapping file's provenance header as well as the rows (§ A9: the header records the recovery rule and a `$CLAUDE_PROJECTS/<session-id>/…` shape, never a literal path — the directory AC18 greps is exactly where that needle would otherwise be planted by the file documenting the scrub). Scoped deliberately: `README.md:280` already carries this repo's absolute path, so a repo-wide grep is red for an unrelated reason, and widening AC18 is GH-76's job |
| AC19 | `git add -N` the new scripts, then `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n`, then `git ls-files '*.sh' \| wc -l`, and the count is the assertion rather than the exit status. **Re-derive the expected number from `git ls-files '*.sh'` itself, never from a name list in this document** — a count computed from a stale inventory is the exact defect AC19 exists to catch, reproduced inside AC19's own recipe, and this row has already carried a wrong number once for that reason. **Measured 2026-10-05: 48** — a floor as of that date, not a constant (41 before this change + 7 new `.sh`: `ledger-write.sh`, `loop-agent-mark.sh`, `loop-window-prefix.sh`, `test-ledger-write.sh`, `test-loop-agent-mark.sh`, `test-loop-grid.sh`, `test-loop-corpus.sh`). Four of the seven are suites and are what `AGENTS.md` check 4's list gains; the two `.awk` files are not `.sh` and are covered by Task 1's parse checks instead |
| AC20 | `bash scripts/check-references.sh`; plus `grep -n 'SubagentStart' docs/claude-tools-hierarchy.md` returning the §3b line **and** a new § Project-defined Hooks row; plus `grep -n 'steps' docs/claude-tools-hierarchy.md` showing `:101` now states the counted unit; plus the GH-72 entry in `ai-docs/context.md` carrying this change's measurement |
| AC21 | `bash scripts/check-release.sh` — refuses a branch that changed shipped content without bumping `.claude-plugin/plugin.json` |
| AC22 | In order, each as its own bare call: `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json`; `bash scripts/check-references.sh`; `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n`; every suite in `AGENTS.md` check 4's list; `bash scripts/check-readme-update.sh`; `bash scripts/check-propagation-arms.sh` (**read the member COUNT**, 35 today); then `bash scripts/test-install-smoke.sh`, `bash scripts/check-release.sh`, `bash scripts/test-upgrade-smoke.sh`. An `exit 2` from 6 or 8 is recorded as "could not run", never as a pass |

### Gates executed while writing this design

Prescribing an unexecuted gate is a `major` finding, so the existing gates named above were run on the
branch at `6bf33c8`, each as its own bare call:

| Command | Result |
|---|---|
| `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json` | all three parse |
| `bash scripts/check-references.sh` | clean |
| `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` | rc 0 over **41** tracked files |
| `bash scripts/check-propagation-arms.sh` | 35 members fire, 13 controls silent, 2 pre-fix matches kept |
| `bash hooks/lib/test-loop-index.sh` | 81 passed, 0 failed |
| `bash scripts/test-hook-behaviour.sh` | 121 passed, 0 failed |
| `claude --version` | `2.1.273` — gates 6 and 8 can run on this machine |

The two gates that do **not** exist yet (`test-loop-grid.sh`, `test-loop-corpus.sh`) are specified above
by their assertions and their positive controls, not pinned as commands that were run. Their detector
logic *was* exercised: the replay prototype in § Measurements reproduced the ticket's pre-fix figures
exactly before the post-fix column was trusted.

**Added at round 2**, after design review found AC3's grid half had no working control:

| Measurement | Result |
|---|---|
| pre-fix rule, call-counted, `K = 1..80` step 1, real ledger | **0 non-monotonic steps** — the round-1 sweep was non-discriminating |
| pre-fix rule, call-counted, `K = 1..400` step 5 | first break reported at `K = 346` — **a step artefact, corrected at round 3** |
| pre-fix rule, line-counted, `K = 1..1000` step 10 | first break reported at `K = 761` — **a step artefact, corrected at round 3** |
| `anchor-15` fixture built and replayed, `K = 3/5/10/13/14/20` | pre-fix **1,1,1,1,0,0**; post-fix **1,1,1,1,1,1** |
| field inventory of the committed fixture, by `kind` | `call` 9 keys / `result` 4 / `turn` 2 / `verdict` 13; `reason` non-empty on **9 of 27**; `bin` has **57 distinct values**, all command verbs or `Tool subtype` |

**Added at round 3**, after design review found the control had no defined feed:

| Measurement | Result |
|---|---|
| frozen awk fed **lines**, `K = 20 / 40 / 100` | **0 / 2 / 3** — the field measurement every AC rests on |
| frozen awk fed **calls**, same `K` | 2 / 3 / 3 — a hybrid that existed in no build; would fail Task 6's first assertion |
| line-fed first break, `K = 740..780` **step 1** | **`K = 760`** (3 → 2) |
| call-fed first break, `K = 335..355` **step 1** | **`K = 343`** (3 → 2) — recorded for completeness; no AC uses this feed |

---

## Open questions

All six of the spec's are answered above — OQ2 § A4, OQ3 § A8, OQ4 § A2, OQ5 § A6, OQ6 § A7, OQ1 already
closed by the user.

**The two this design raised at round 1 are now settled, and are recorded here rather than deleted so
the reasoning survives with the decision:**

- ~~**~750 KB of fixture enters the repository.**~~ **Closed, user, 2026-10-05: commit it as is,
  uncompressed, plain JSONL — no size problem for now, may be worth revisiting later.** Measured
  trade-off and the not-taken compressed variant are in § A9c. AC9's validation leg survives intact,
  which was the thing at risk.
- ~~**AC11's window must be stated as `K = 40`.**~~ **Closed, orchestrator, 2026-10-05: `K = 40` as
  proposed, AND the same fixture additionally asserts `na = 3` at the shipped default `K = 20`.** An
  addition, not a spec change — AC11 names no window, so its text stays true and no Spec Amendment is
  needed. Rationale and the measured band are in § A11.

**One question is open and belongs to the spec's owner, not to this design:**

- **Spec TC5 says "the payload itself is content-free, so nothing else needs redaction".** Measured
  (§ A9b), that is too strong: 9 of the 27 `verdict` rows in the committed fixture carry a `reason`
  field holding free prose written by the tier-3 model. This design does **not** edit the spec and does
  not depend on which way it lands — it records the judgement that `reason` stays (it is this
  repository's own subject matter), and notes that the opposite ruling costs one `jq` filter in Task 5
  and one assertion in AC18, with no AC, leg or gate moving. Routed to the user under the Spec
  Amendment recipe by the orchestrator.

