# Design: agent_id from the PreToolUse payload, so fan-out detection can fire

**Ticket:** GH-72
**Date:** 2026-09-30
**Spec:** ai-docs/plans/2026-09-30-payload-agent-id.spec.md

> **Round 2 — amended after `design-review` returned ITERATE.** Five issues addressed: the human
> renderer gains a fourth INCOMPLETE clause for the new `complete` leg (§ Approach (g2), D1); the
> `note_ok` edit's collision with the M2 positive control is called out with its re-target (§ Note
> for Task 5 / 6); the AC17 gate is extended and re-measured, and split into a negative and a
> positive half (§ Approach (i)); a `| type == "string"` guard makes a malformed `agent_id` degrade
> to `"main"` instead of dropping the ledger row (§ Approach (a)); and the temp-file shape adopts
> the in-repo `mktemp -d` + `EXIT INT TERM` idiom (§ Approach (c)). The three recommendations are
> folded into Tasks 3, 7 and AC3.
>
> **Round 3 — amended again.** The AC17 measurement recorded in round 2 did not reproduce: the
> recorded pattern was not the one measured, and the dropped phrase was the only thing covering
> `docs/claude-tools-hierarchy.md:110`. The gate is re-measured and now recorded as a full
> `grep -rnoE` enumeration (**12 matches on 6 distinct lines across 3 files**), with
> `agents/inspector.md:125` recovered as a sixth line; `attribution.stored_agents_unread` gains a
> reading instruction in Task 7 and a fifth positive probe in AC17; and Task 4 plus § Approach (d)
> are re-spelled to the `$WORK/rows` + `$WORK/detail` temp shape that § Approach (c) adopted.
>
> **GO write-back (post-review, not a fourth round).** Three notes folded in: **D2** turns "the
> pattern was extracted and run once" from a prose sentence into a standing guard, exercised in both
> failure directions; Task 7 gains the rule that a rewrite must state the new truth positively and
> restate none of the ten gate phrases, with the negative gate re-run after each file; and AC17's
> positive half gains a sixth probe so `stored_agents_unread` is policed on both surfaces Task 7
> writes it to.
>
> **Design Amendment after Group A (user-approved; runs before Group B).** Subtasks 1–3 are
> implemented and revealed four places where this design was untrue about the code: row 1's RED
> estimate (1–2 → **10**, measured), row 1's `fire()` shape (one combined argument → **three
> independent** optionals plus `fire_aid_json`), AC3's gate (ii) blast radius (it caps the token at
> one occurrence **including comments** — Task 7 is warned), and row 3's `call()` (one parameter →
> **two**). See § Group A amendment for the record, including one addition beyond the design and one
> reported finding that is **rejected** and must not become a sweep.
>
> **Second Design Amendment after Group B (applying the user's standing decision to amend between
> groups).** Subtasks 4–6 implemented; five corrections: the fourth `complete` leg's **position** is
> load-bearing (control M8), making the mutation-control hazard a **class with two instances**;
> `fcall()` had to be split into `acall` + `fcall`; row 6's GREEN estimate was 28, not 5 — the second
> undercount, now answered by a rule at the head of § Decomposition rather than a per-row patch; two
> deliberate deviations recorded, one of which (**`refutations` nested inside `agreement`**) binds
> Task 7; and **D2 is RETIRED** with its scope note's own defect recorded and a pre-flight
> enumeration put in its place. See § Group B amendment.
>
> **GO write-back on the second amendment.** Two sharpenings: the mutation-control class is **three**
> instances in **two failure modes** (M2/M8 fail LOUDLY — measured, 163/3/rc 1 against the rejected
> shape; M13 is the silent one, and the rejected shape defeats M12 as well as M8), and Task 7's
> pre-flight must **paste its listing and compare against 10/4/2** rather than merely check non-empty.
>
> **Anchors in this document are pre-edit.** Every `file:line` below was derived by `grep -n` /
> `cat -n` while this design was written. After Task 2, 4 or 6 lands, **re-derive any anchor before
> quoting it** — never compute a post-edit line by adding a delta.

## Approach

### The one-line shape of the fix

The tier-1 hook stops asking the transcript path who the agent is and reads the payload field that
says so. Everything else in this ticket follows from that one field becoming trustworthy: the stored
pointer becomes resolvable, the fan-out arm becomes reachable, the reader gains a second record to
cross-check against, and five prose surfaces that describe the defect become false.

**Verified before designing** — the four payload shapes the hook can receive, run through the exact
jq expression proposed below:

| payload | `agent_id` | `agent_type` | `transcript` |
|---|---|---|---|
| `{transcript_path:"/tmp/p/sess-1.jsonl", agent_id:"abdf3d8dfa6b9c67a", agent_type:"general-purpose"}` | `abdf3d8dfa6b9c67a` | `general-purpose` | `/tmp/p/sess-1/subagents/agent-abdf3d8dfa6b9c67a.jsonl` |
| `{transcript_path:"/tmp/p/sess-1/subagents/agent-abc123.jsonl"}` (AC5 shape) | `main` | `-` | unchanged |
| `{transcript_path:"/tmp/p/sess-1.jsonl"}` | `main` | `-` | unchanged |
| `{}` | `main` | `-` | `-` |

Row 1 reproduces the spec's measured pointer derivation
(`${transcript_path%.jsonl}/subagents/agent-${agent_id}.jsonl`) exactly. Row 2 is the regression
guard: a subagent-shaped `transcript_path` with no `agent_id` must NOT be read as a subagent.

### Chosen approach, component by component

**(a) `hooks/lib/loop-index.sh` — one jq invocation, unchanged in count.** The current derivation at
`:75-78` is a `test()` plus two `sub()` calls; it is replaced by one `sub()` and two comparisons
inside the same single `jq` at `:71-86`. Net cheaper, which is what the spec's § Key decisions
claims and what the table above executes.

```
(.transcript_path // "-")               as $tp
| (if (.agent_id | type) == "string" then .agent_id else "" end)  as $aid
| (if $aid == "" then "main" else $aid end)                       as $agent
| (if $aid == "" or $tp == "-" then $tp
   else (($tp | sub("\\.jsonl$"; "")) + "/subagents/agent-" + $aid + ".jsonl") end) as $tref
```

`agent_type: (.agent_type // "-")` joins the ledger entry at `:82-85`, using the file's existing
absent-field convention (`// "-"`, as `tool`, `tool_use_id` and `cwd` already do). The `$tp == "-"`
leg is a deliberate addition beyond the spec: without it an absent `transcript_path` beside a
present `agent_id` would store the literal `-/subagents/agent-<id>.jsonl`, a pointer that names
nothing and reads as a real path. Costs one comparison.

**The `| type == "string"` guard is load-bearing, and `// ""` is not a substitute for it.**
`//` only catches `null` and `false`. Measured this session against the earlier `(.agent_id // "")`
spelling:

```
$ echo '{"transcript_path":"/tmp/p/s.jsonl","agent_id":12345}' | jq -r '<the four lines>'
jq: error (at <stdin>:1): string ("/tmp/p/s/subagents/agent-") and number (12345) cannot be added
rc=5
```

There is **one** `jq` on this path, so its failure empties `out` and `hooks/lib/loop-index.sh:87`
exits 0 having written nothing — the call leaves the loop index entirely. That honours "a hook that
breaks is worse than a hook that is absent" but **violates the other half of the same constraint**,
which says a missing or malformed `agent_id` must degrade to `"main"`. The type guard makes the
degrade literal. Re-measured across five shapes with the guard in place, all rc 0:

| `.agent_id` | `agent_id` | `transcript` |
|---|---|---|
| `"abc"` | `abc` | `/tmp/p/s/subagents/agent-abc.jsonl` |
| `null` | `main` | unchanged |
| `12345` | `main` | unchanged |
| `["x"]` | `main` | unchanged |
| absent | `main` | `-` (no `transcript_path` either) |

**(b) No `[ -f ]` on the derived pointer**, per § Key decisions — at `PreToolUse` the subagent
transcript may not exist yet for the first call in that subagent. AC6 pins this as a test rather
than leaving it as a comment.

**(c) `hooks/lib/loop-verdict.sh` — the counter leaves the subshell by a REDIRECT, not a pipe.**
This is the mechanism the spec requires the design to name explicitly. The current detail stage at
`:107-121` is `detail=$(awk … | jq … | while … done)` — a command substitution containing a
pipeline, so the `while` body is a subshell twice over. **Measured, this session**, on a reduced
copy of exactly that shape:

```
A: command-substitution+pipe -> n=0 detail_lines=3
B: redirect-from-file      -> flagged=3 unresolved=1 detail_lines=2
```

Shape A reports `n=0` while producing three lines of detail — the failure the spec predicts, where
every assertion about the counter passes and the counter measures nothing. Shape B is the fix:

1. `awk … | jq … > "$WORK/rows"` — the flagged `tool_use_id` + `transcript` rows land in a temp file.
2. `while IFS=… read -r tuid tpath; do … done < "$WORK/rows"` — **a redirect from a file, never a
   pipe**, so the body runs in the CURRENT shell and `flagged` / `unresolved` survive it.
3. Resolved argument text is appended to `"$WORK/detail"`; `detail=$(cat "$WORK/detail")` afterwards.

**The temp shape follows the in-repo idiom, not a new one.** Re-derived this session, the
established spelling is a temp DIRECTORY with a three-signal trap —
`scripts/session-events.sh:88`, `scripts/backlog-metrics.sh:57` and
`scripts/test-check-readme-update.sh:51` are all verbatim
`WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT INT TERM`. This task adopts it exactly. The earlier
draft of this design proposed `mktemp` (a file) plus a derived `"$work.d"` that `mktemp` never
reserved — a second path nothing had claimed, which is a collision waiting on a busy machine — and
a trap on `EXIT` alone. `INT` and `TERM` matter here specifically: this is a `Stop` hook, and a
cancelled turn can interrupt it. The two-file form is kept, but both files live inside the one
reserved directory.

`mktemp -d` failure takes the existing degrade path (`mark_turn`), so a counter that cannot be
computed never costs a verdict. `mark_turn` already exits 0, so the trap fires on every path.

**(d) Resolution is "did this call contribute any argument text", not "does the file exist".** The
`[ -f "$tpath" ] || continue` at `:115` becomes `[ -f "$tpath" ] || { unresolved=$((unresolved+1)); continue; }`,
and the jq result is tested for emptiness — a file that exists but holds no `tool_use` with that id
(failure 3, today's common case) yields empty output and counts as unresolved. AC13 is the test that
a `[ -f ]`-only notion of resolution cannot pass. `flagged` increments **before** any guard, and
once per row of `"$WORK/rows"` — per flagged call, never per line of detail, because the measured probe
found one id twice in its own transcript.

**(e) The tier-3 row gains `flagged_calls` and `unresolved_calls`**, both always present, at
`:144-148`. Two integers, per AC11 — not a boolean, not a ratio. Nothing else on that row, and no
exit path or threshold, changes (AC14).

**(f) `scripts/loop-metrics.sh` — the cross-check is a join on the map the reader already builds.**
`$by_id` (`:282`) maps `tool_use_id → recovered agent`; `$calls` carries `.agent_id` as stored. For
every call where `$by_id[.tool_use_id]` is non-null, compare the two. `checked` / `confirmed` /
`refuted` are complete counts; `refutations` is `$refs[0:5]`, each element
`{tool_use_id, stored, recovered}` — the per-call link the user asked for. Calls with no recovered
agent are excluded from all three and stay reported by `unattributed` alone (AC7). The cap is a
literal 5; `refuted` is `$refs | length` and is never capped (AC8).

**(g) `every_stored_agent_read` needs a list the shell owns, not one jq can infer.** `ids_of`
(`:254-258`) emits one record per `tool_use` found — so a subagent transcript that exists, parses,
and happens to contain no tool calls produces no record and would be indistinguishable from one
never opened. The shell loop at `:271-275` therefore accumulates a second accumulator beside
`BAD_TX`:

```
if ids_of "$s" "${a#agent-}"; then note_ok "${a#agent-}"; else note_bad "$s"; fi
```

`note_ok` uses the same `NL=$'\n'` literal-newline idiom as `note_bad` (`:261-267`) — the hazard
that file already documents — and the list reaches jq as `--argjson read_ok` through the same
`jq -Rrs split("\n") | map(select(. != "")) | tojson` conversion as `bad_json` (`:276`). Then:

```
every_stored_agent_read:
  ( $calls | map(.agent_id) | unique
    | map(select(. != null and . != "main"))
    | all(. as $a | $read_ok | index($a) != null) )
```

**Verified against jq, this session:** `[] | all(…)` → `true`; `["a"] | all(. as $x | ["a","b"] | index($x) != null)`
→ `true`; `["a","b"] | all(. as $x | ["a"] | index($x) != null)` → `false`. The empty case is what
makes a pre-fix ledger (`stored_agent_ids == ["main"]`) satisfy the leg vacuously, so no historical
ledger changes its `complete` verdict (AC10). The `!= null` filter is defensive and free: a ledger
row written by a build with no `agent_id` field at all would otherwise put `null` in the list and
flip `complete` to false for a reason unrelated to this change.

`complete` (`:320`) becomes the four-way conjunction, and it stays a **measurement**: every leg is
something the reader executed, none is an assertion it cannot verify.

**(g2) A fourth leg needs a fourth clause in the human renderer — and this is the half the first
draft of this design missed.** `scripts/loop-metrics.sh:345-351` (re-derived) enumerates exactly
three reasons a census is incomplete: `main_transcript_read` (`:347`), `unreadable_transcripts`
(`:348-349`), `unattributed_at_tail` (`:350`), then a fixed closing sentence at `:351`. Run against a
view where only `every_stored_agent_read` is false, the whole output degenerates to:

```
  ATTRIBUTION IS INCOMPLETE -- the per-agent census above is wrong, not merely partial: Treat the 0
  unattributed call(s) as unknown: not the main agent, not calls in flight.
```

No reason named, and it points the reader at a count of **0**. The regression is worse than
cosmetic: the commonest firing case for the new leg is a live session whose subagent transcript
lags — which is precisely the case `:343-344` currently explains with the benign in-flight gloss,
and which `:350` already names in prose. Post-fix such a session would **lose** that gloss (because
`complete` is now false) and gain a reasonless alarm in its place. A leg that can turn `complete`
false without being able to say why is not admissible under the spec's "`complete` stays a
measurement" constraint.

So the chain gains a fourth clause, before the closing sentence at `:351`:

```
+ (if .every_stored_agent_read then ""
   else " the ledger names agent(s) whose transcript was never opened or would not parse: "
        + (.stored_agents_unread | join(", ")) + "." end)
```

`stored_agents_unread` is emitted beside `every_stored_agent_read` — it is
`stored_agent_ids` minus `main` minus `read_ok`, the list the leg already computes, surfaced instead
of discarded so the message can name the ids rather than assert an absence. Emitting the list also
makes the leg's own arithmetic checkable from the record, which is what keeps it a measurement.

This is covered by **D1** in § AC verification — a design-added check rather than a spec AC; see
§ Open questions.

**(h) The NOTE (`:355-358`) is reworded, and nothing else.** Its gate (`$n > 1` and
`stored_agent_ids == ["main"]`) already self-disables on a post-fix ledger, which is why Q3 needs no
schema field, no migration and no date/version comparison (AC16). The new string attributes the
blindness to the build that **wrote** the ledger and says the recovered attribution is analysis-only
**for this session** — it makes no claim about the build currently reading it.

**(i) Prose, and what the AC17 gate can and cannot see.** Measured with `grep -rnoE` — **12 matches
on 6 distinct lines across 3 files**, listed in full because a per-file *count* is the wrong
instrument here (see the round-3 correction below):

```
agents/inspector.md:66:The live hook cannot see it either
agents/inspector.md:66:reads `main` for every call
agents/inspector.md:66:arm keyed on it does not fire
agents/inspector.md:125:it is the conjunction of the three
docs/claude-tools-hierarchy.md:101:currently unreachable
docs/claude-tools-hierarchy.md:101:field is currently wrong
docs/claude-tools-hierarchy.md:101:reads `main` for every call
docs/claude-tools-hierarchy.md:110:three things the reader can actually check
docs/claude-tools-hierarchy.md:110:nothing enumerates the transcripts that ought to exist
docs/claude-tools-hierarchy.md:110:ledger field that would be that list is the broken one
scripts/loop-metrics.sh:236:arm keyed on it can never fire
scripts/loop-metrics.sh:313:reader has no list of what should exist
```

**Round-3 correction, and it is worth stating plainly because the error was the very defect this
gate exists to catch.** Round 2 recorded "5 lines across 3 files" from a `-c` run of a pattern that
was *not* the pattern written into the design: the verification run carried
`ledger field that would be that list is the broken one`, that phrase matched
`docs/claude-tools-hierarchy.md:110`, and it was then dropped from the recorded pattern on the
reasoning that it could not match `scripts/loop-metrics.sh:313` across a line break. It could not —
but it was carrying `:110` on its own, and dropping it silently removed a surface from the gate's
reach while the recorded number still claimed it. **Measured pattern A, recorded pattern B.**

**Precisely where the `-c` figure came from, because a vague root cause would let this recur.**
Re-run this session, both patterns against the same three files:

| pattern | `agents/inspector.md` | `docs/claude-tools-hierarchy.md` | `scripts/loop-metrics.sh` |
|---|---|---|---|
| round-2 **measured** (with `ledger field…`) | 1 | **2** | 2 |
| round-2 **recorded** (without it) | 1 | **1** | 2 |

So the recorded `-c` figure of `2` was **correct for the pattern actually run** and wrong for the
pattern written down. `-c` did not hide `:110` from the run — the *substitution* removed `:110` from
the gate while the number kept vouching for it. The lesson is therefore narrower and sharper than
"`-c` is misleading":

- **Verify the pattern you WRITE DOWN, not the one you happened to run.** This is the whole defect.
  The re-measurement above was produced by extracting the pattern **out of this document** and
  executing that string. **That is now a standing guard, not a thing that was done once** — see
  **D2** in § AC verification, which re-extracts the pattern from the AC17 row, runs it, and diffs
  the result against the enumeration block above. A prose sentence saying the check was performed
  would record history; D2 records an obligation. The distinction is the same one this whole section
  is about, and it was very nearly repeated here: an earlier draft of this paragraph asserted a
  checker existed when the checker existed only in a scratch directory.
- **Record an enumeration anyway, because it makes that substitution self-evident.** `-c` yields
  bare integers, so two different patterns produce output that looks interchangeable; a `-rnoE`
  listing of the recorded pattern would have shown `:110` simply missing. A count answers *"can this
  gate fire?"*; § Risks claims something stronger — *"which surfaces does this gate police?"* — and
  only the listing answers that.

Two surfaces were recovered by the fix, both wholly on one line and both matchable all along:

- **`docs/claude-tools-hierarchy.md:110`** carries two sentences this change falsifies — that
  `attribution.complete` is "the conjunction of the three things the reader can actually check" (it
  becomes four), and that "nothing enumerates the transcripts that ought to exist, because the
  ledger field that would be that list is the broken one above" (Scope item 7 makes this false).
  Three phrases now match it.
- **`agents/inspector.md:125`** makes the same conjunction claim and was invisible for the *other*
  reason: "the conjunction of the three / things the reader can actually check" **straddles the
  `:125/:126` break**, so the phrase that catches `:110` cannot catch it. Its own single-line phrase
  is `it is the conjunction of the three`. Task 7's `:114-129` range already covers the edit; this
  makes the gate able to confirm it.

And two surfaces the gate legitimately cannot police:

- **`scripts/loop-metrics.sh:313`** — the comment Scope item 7 falsifies, whose sentence straddles
  `:313/:314`. Caught by `reader has no list of what should exist`, wholly on `:313`.
- **`skills/inspect/SKILL.md` matches nothing, and correctly so.** Grepped for `main` / `blind` /
  `stored` / `analysis-only` / `broken`, its only hit is `:58`, which is about something else. It
  carries no false claim — its gap is an *omission*: `:79-82` tells the reader to pass `attribution`
  and to check `complete`, and does not name the new fields. That obligation is discharged by the
  **positive** half of the AC17 gate, not the negative half. A negative-only gate would report this
  surface clean forever.

`hooks/lib/loop-index.sh` likewise matches nothing: its header at `:14-17` is not false, merely
about to understate (it explains why `transcript` is per-entry without saying where the value now
comes from). Task 2 updates it; the gate is not the thing that catches it.

`agents/inspector.md` and `docs/claude-tools-hierarchy.md` additionally need reading instructions
for the new fields, because emitting a field without telling the reader how to weigh it is what the
Propagation Rule's Inspect group exists to prevent.

### Alternatives rejected

| Alternative | Why not |
|---|---|
| Keep the `transcript_path` derivation as a fallback behind the payload field | § Key decisions forbids it. It has produced `main` for every row ever written; a fallback that has never fired is untested code that reads as coverage. AC1 pins its total removal. |
| Branch on `agent_type` to decide "is this a subagent" | The client's own contract: `agent_type` is present on the MAIN thread of an `--agent` session *without* `agent_id`. Keying on it misclassifies that session's main thread as a subagent. AC3 forbids any detector branch on it. |
| `[ -f ]` the derived pointer before storing it | Costs a stat on the hot path and, in the single case it would fire, stores a knowingly-wrong pointer instead of a not-yet-written one. |
| Make tier 3 refuse to judge / warn / change verdict on partial evidence | Offered to the user and explicitly declined. AC14 pins the verdict as unchanged. |
| Compute the tier-3 counter with `${PIPESTATUS}` / a global set inside the `while` | Both still die with the subshell. The redirect is the only shape that keeps the body in the current shell, and it is the one measured above. |
| Emit the counter as a boolean `evidence_complete` or a ratio | The user's stated purpose is the VOLUME of evidence the small model answered on, so a `progress` on full arguments is distinguishable from one on half. Two integers carry that; a boolean and a ratio both discard it. |
| Reuse `repeats` as the flagged count on the tier-3 row | The gate's `awk` (`:72-85`) and the detail stage's `awk` + `jq select(.bin == $b)` (`:107-113`) are two derivations of what should be one number. Emitting the second explicitly makes a disagreement visible on the row instead of assumed away. |
| Retire the read-time recovery now that the stored field works | Out of scope by the spec: historical ledgers have no usable `agent_id`, a hook can always fail to fire, and it is now half of the cross-check. |
| Migrate / rewrite existing ledgers | Violates the append-only ledger contract; tier 1's 20-row window ages pre-fix rows out within a turn anyway. |

## Decomposition

> **A row's RED/GREEN figure is an ESTIMATE. The § Test Design scenario list is the contract.**
> Stated once here rather than patched per row, because it has now been wrong twice in the same
> direction: row 1 said "1–2" where 10 was measured, row 6 said "5" where 28 was. Both undercounted
> from the same cause — the row enumerated a subset of what § Test Design mandates, and a reader
> who trusts the number over the list under-builds. When the two disagree, the list wins; when a
> measured figure arrives, record it and keep the list as the authority.

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **Production-shaped tier-1 fixtures + the two new guards.** *(IMPLEMENTED — see § Group A amendment.)* `fire()` takes **three independent optional arguments**, not one: `$3` transcript_path, `$4` agent_id, `$5` agent_type, where **empty means the field is ABSENT from the payload** rather than present-and-empty — the client omits all three, and a present-but-empty field takes a different branch in the hook. A single combined argument cannot express `agent_id` present with `agent_type` absent, which § Test Design requires (it must store `-`); and `$3` needs the same treatment or the `$tp == "-"` leg is unreachable. A **non-string** `agent_id` needs `--argjson`, which `--arg` cannot express, so it gets its own `fire_aid_json()` helper. Rewrite the fan-out section so all three calls carry the **parent** `MAIN_TP` and differ only in `agent_id`, asserting fan-out fires, names the agent count, and the ledger shows one `fp` across several `agent_id`s (AC4). Add the AC5 regression guard (subagent-shaped `transcript_path`, no `agent_id` → `agent_id:"main"` and `transcript` stored verbatim) and the AC6 guard (derived pointer stored although the target file does not exist). **Expect RED on 10 assertions** — measured at subtask 1 before any production edit, not estimated. **The § Test Design scenario list, not this number, is the contract.** The ten are the whole of the new behaviour, which is why the earlier "1–2" was wrong: it counted only AC5 and ignored this design's own § Test Design, which mandates the happy path, the `agent_type`-absence edge and the fan-out rewrite as well, each red pre-fix by construction. | `hooks/lib/test-loop-index.sh` (post-edit: `:35-44` `fire`, `:47-52` `fire_aid_json`, fan-out at `:317-339`) | — |
| 2 | **Read the agent from the payload.** Replace the `$agent` derivation at `:75-78` with the four-line expression in § Approach (a); add `agent_type` to the entry at `:82-85`; store `$tref` instead of `$tp`. Update the file header at `:14-17` (the `transcript` paragraph) and `:27-33` (the fan-out paragraph) so neither still describes a derivation this file no longer performs. No change to the `awk` detector — `:133` already reads `agent_id` off the line. | `hooks/lib/loop-index.sh` | 1 |
| 3 | **Tier-3 evidence-counter assertions.** *(IMPLEMENTED — see § Group A amendment.)* `call()` gains **two** optional parameters, not one: `$2` agent_id, which makes tier 1 store a pointer at the subagent's own transcript that nothing has written yet — the absent-file shape; and `$3 = noline`, which leaves the id out of a transcript that IS on disk — the shape a `[ -f ]` guard cannot tell from a hit, and the one AC13 exists for. The original row named only the first and described the second as "appending the transcript line for only some ids" without giving `call()` any way to do it. Add a section covering: a turn where some flagged calls resolve and others do not → `unresolved_calls` non-zero (AC12 first half); a turn where all resolve → `0` (AC12 second half, so the counter cannot pass by being stuck); a flagged call whose stored `transcript` **exists but lacks the id** → unresolved (AC13); a flagged call whose derived pointer names nothing → unresolved; `flagged_calls` present and equal to the number of flagged rows (AC11); the same `verdict` value with and without unresolved calls, given the same stubbed answer (AC14) — **and that the verdict compared is a real one.** Two ABSENT tier-3 verdicts compare equal, so an invariance assertion that only checks "same value" passes on a turn that wrote no row at all; pin the value to `progress` as well as to itself. This was added by Group A beyond the design, and it is the same defect class the design spent two rounds closing, so it is recorded here rather than left in a commit message. Build "file exists, id absent" with `call()`'s `$3 = noline`. **The new section MUST set `HARNESS_T3_MODEL` back on.** `:177` is exactly `export HARNESS_T3_MODEL=off; unset STUB_SEEN` — placing the section after it with no re-enable means tier 3 never runs, no tier-3 row is written, and every counter assertion fails for a fixture reason. Follow `:151` (`export HARNESS_T3_MODEL=haiku`), and restore `off` explicitly at the end, per the reason given at `:175-177`. **Expect RED.** | `hooks/lib/test-loop-verdict.sh` (`:56-68` `call()`, new section after `:177`) | 2 |
| 4 | **Subshell-free detail loop + the two integers.** Rewrite `:107-121` per § Approach (c)/(d), using the in-repo temp idiom verbatim — `WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT INT TERM`, as `scripts/session-events.sh:88` and `scripts/backlog-metrics.sh:57` spell it. Flagged rows to `"$WORK/rows"`; `while IFS=… read -r tuid tpath; do … done < "$WORK/rows"` — **a redirect, never a pipe**; `flagged` incremented before any guard; `unresolved` incremented on both the absent-file and the empty-result branches; resolved text appended to `"$WORK/detail"` and `detail=$(cat "$WORK/detail")` after the loop. Add `flagged_calls` / `unresolved_calls` to the tier-3 row at `:144-148`. `mktemp -d` failure → `mark_turn`. `:122` and every other bail path unchanged. **Expect GREEN for all 7 of Group A's REDs**, which are two different problems: six are `null` on the two new fields and go green the moment the fields are emitted; the seventh, `and the two turns really did differ in evidence`, is the **control that makes AC14's invariance non-vacuous** — it is red because both turns' counters are absent and so compare equal. **Turn it green by giving the two turns genuinely DIFFERENT evidence, never by relaxing the comparison.** Weakening it is the cheapest way to make it pass and would delete exactly the property it exists to protect — AC14 would then assert that two identical nothings are identical. **And 64/64 of the pre-existing assertions still green.** | `hooks/lib/loop-verdict.sh` | 3 |
| 5 | **Reader assertions: agreement, the new `complete` leg, the NOTE.** *(IMPLEMENTED — see § Group B amendment.)* An `agent_id` parameter on `fcall()` alone **cannot be used**: `fcall` hard-codes `>> "$FL"`, so a fixture with its own ledger cannot call it and the new parameter would sit unused. Split it instead — `acall <id> <agent_id> <ledger>` does the work, and `fcall() { acall "$1" "${2:-main}" "$FL"; }` keeps every existing call site working. New sections: (a) a ledger whose stored ids partly agree and partly disagree with the transcripts → `agreement.checked/confirmed/refuted` correct, `refutations[]` carrying `tool_use_id` + `stored` + `recovered`, and unattributed calls excluded from all three (AC7); (b) more than 5 refutations → list capped at 5, `refuted` the full count (AC8); (c) the human `--for` output names at least one refuting id with both values (AC9); (d) `every_stored_agent_read` true when every non-`main` stored id has a readable transcript, false when one is missing, and **vacuously true** on `stored_agent_ids == ["main"]` so `complete` is unchanged for a pre-fix ledger (AC10); (e) the reworded NOTE present on a pre-fix-shaped ledger and **absent** on one carrying real ids (AC15); (f) the INCOMPLETE line **names a reason** when only `every_stored_agent_read` is false, and names the unread ids (D1). Add a positive control that deletes the agreement comparison and shows the refutation disappears, and one that deletes the `every_stored_agent_read` leg so a missing-transcript ledger reads as `complete`. **Also re-target the M2 control at `:310-317`** — see the note below the table. **Expect RED.** | `scripts/test-loop-metrics.sh` (`:236-298`, `:242-249`, **`:310-317`**) | 2 |
| 6 | **Reader implementation.** Add `note_ok` + the `read_ok` accumulator to the transcript loop (`:271-275`) and pass it as `--argjson read_ok`; add `agreement`, `every_stored_agent_read` and `stored_agents_unread` to the `attribution` object (`:302-323`); extend `complete` (`:320`) to the four-way conjunction — **and the new leg MUST be inserted BEFORE `$ua_tail`, never appended after it**; see § Mutation-control class below, this is not a style preference. Add the disagreement line **and the fourth INCOMPLETE clause** to the human renderer (`:331-376`, chain at `:345-351`); reword the NOTE (`:355-358`); rewrite the two stale comments at `:232-241` and `:313-320`. **Expect GREEN for 28** (estimate — the § Test Design scenario list is the contract, not this number). **Of the 130 pre-existing assertions, the three at `:312` and `:314-317` are re-targeted by Task 5, and control M8 constrains the leg's POSITION as above — the rest are unchanged.** *(IMPLEMENTED — see § Group B amendment.)* | `scripts/loop-metrics.sh` | 5 |
| 7 | **Propagation, prose and delivery.** Rewrite `agents/inspector.md:66` (the fan-out dismissal row) and `:114-129` (§ Attribution) — the latter gains how to read **all four** new reader fields — `attribution.agreement`, `attribution.every_stored_agent_read`, **`attribution.stored_agents_unread`** and the tier-3 evidence counter. `stored_agents_unread` is easy to drop precisely because it was added late, by the ISSUE-1 fix, and a field emitted with no reading instruction is the thing this design argues the Inspect group exists to prevent; the instruction is that it names the agents whose calls the census could not have attributed, so a non-empty list means the `by_agent` figures are wrong rather than partial. Also rewrite `agents/inspector.md:125` — re-derived; it repeats the "conjunction of the three things" claim that `:110` makes and becomes false in the same way. Rewrite `docs/claude-tools-hierarchy.md:101` (the `loop-index` bullet), `:108` (the `loop-verdict` bullet, for the two new row fields) and `:110` (the `--for` bullet — **two false sentences**: `complete` becomes a four-way conjunction, and "nothing enumerates the transcripts that ought to exist, because the ledger field that would be that list is the broken one" is exactly what Scope item 7 repeals); update `skills/inspect/SKILL.md:79-82` so the skill names the new fields among what it hands the agent. **Check `scripts/session-events.sh` and record the result**: it is the fourth Inspect-group member (`docs/agents-method.md:145`), and the Propagation Rule says *check / update*, not *update if changed*. Its output contract is expected to be untouched — it emits no `agent_id` and reads no ledger — but "expected" is not "checked", and a member whose check is never recorded is how the Spec-Amendment group drifted. **State the new truth positively; restate none of the ten AC17 gate phrases.** A correction written as "`complete` is no longer the conjunction of the three things the reader can actually check" quotes the phrase in order to repeal it and keeps the negative gate non-empty forever — and restating what you are correcting is the *natural* way to write a correction, so this is a property of phrase-based negative gates rather than a trap in this one. Write what is true now and let the old claim go unquoted. **PRE-FLIGHT, before the first prose edit: run the AC17 negative pattern and record what it still matches.** D2 is retired (§ D2's retirement) and this replaces it. The listing is the positive control for the gate: AC17's "must be EMPTY" cannot tell *all fixed* from *pattern too narrow*, and only a non-empty BEFORE proves the gate could fire on the surfaces you are about to edit. **PASTE the `-rnoE` listing into the PR body (or this design) and compare it against the recorded figure — do not merely check it is non-empty.** Expect exactly **10 matches on 4 lines across 2 files**: `agents/inspector.md:66` (×3), `:125`; `docs/claude-tools-hierarchy.md:101` (×3), `:110` (×3). A count that is lower means the pattern narrowed, which a non-empty check would wave through. If it is empty, STOP: the pattern is broken, not the prose fixed. **The paste is the load-bearing half.** Unlike D2, this step is ordering-dependent — run after the first edit it reports the post-edit state, which on a correct Group C is empty and therefore indistinguishable from the broken-pattern condition it exists to detect — and it leaves no trace of having run. An inverted or skipped order is invisible without an artefact; with one, absence is visible and a narrowed pattern shows up as a wrong count rather than as a passing non-empty result. **Use `attribution.agreement.refutations` as the field path in every reading instruction** — `refutations` is nested inside `agreement`, per § Group B amendment. **If any prose edit lands in `hooks/lib/loop-index.sh`, re-run AC3 gate (ii) too** — it caps `agent_type` at ONE occurrence in that whole file, comments included, so a header paragraph that names the identifier breaks it; write the concept without the token, as Group A did. **Re-run the AC17 negative gate after EACH file, not only at the end**: six lines across three files are being rewritten, and a single run at the end says only that something still matches, not which rewrite reintroduced it. Bump `.claude-plugin/plugin.json` `0.1.29 → 0.1.30` (AC18). Then the full gate run (AC19). | `agents/inspector.md`, `docs/claude-tools-hierarchy.md`, `skills/inspect/SKILL.md`, `.claude-plugin/plugin.json`; **checked, expected unchanged:** `scripts/session-events.sh` | 2, 4, 6 |

### Note for Task 5 / 6 — the `note_ok` edit breaks an existing positive control, by design

This is the one place where a Task-6 edit reaches outside its own file, and an implementer who does
not expect it will hit an unexplained RED.

`scripts/test-loop-metrics.sh:310-317` is the **M2** control ("without the subagent scan, the
subagent's calls vanish from the census"). Re-derived, `:311` is:

```
perl -0pe 's/ids_of "\$s" "\$\{a#agent-\}" \|\| note_bad "\$s"/:/' "$READER" > "$M2"
```

It matches the CURRENT `:274`, which is `ids_of "$s" "${a#agent-}" || note_bad "$s"`. § Approach (g)
replaces that with an `if … then note_ok … else note_bad … fi`, which has no `||` — so the perl
substitution silently matches nothing, `grep -c 'ids_of "$s"'` on the mutant returns **1** where
`:312` asserts `0`, and the two dependent assertions at `:314-317` then measure the unmutated
reader. Three assertions go RED for a fixture reason, not a real one.

**Task 5 therefore re-targets M2 at the new line shape in the same commit that introduces it** — the
mutation must still delete the subagent scan, and `:312`'s "the mutation applied" assertion must
still be able to fail. That assertion is not decoration: it is the guard that would otherwise let
M2 rot into a control that mutates nothing and passes forever, which is exactly the failure class
this repo's own `AGENTS.md` check 4 was written about.

## Handoff plan

`M = 7` — three groups, 3 + 3 + 1.

- **Entering Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` before subtask 1. The handoff binds at the start of **every** group, including the first.
- **Group A:** subtasks 1–3 — the tier-1 hook, test-first, plus the tier-3 assertions that depend on it.
- **Handoff after Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh context.
- **Group B:** subtasks 4–6 — the tier-3 counter implementation and the whole reader change.
- **Handoff after Group B:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group C with fresh context.
- **Group C:** subtask 7 — terminal group (1 subtask; within the 1..3 range). Prose, propagation, version bump and the full gate run.

## Group A amendment — what implementation proved untrue about this design

Subtasks 1–3 are implemented. Verified independently, not relayed: `bash hooks/lib/test-loop-index.sh`
→ **81 passed, 0 failed, rc 0**; `bash hooks/lib/test-loop-verdict.sh` → **69 passed, 7 failed,
rc 1**. **Six** of the seven REDs report `null` on `flagged_calls` / `unresolved_calls` — the two
fields subtask 4 adds. The seventh is a different shape and must be named separately, because a
sentence that certifies it by the wrong shape certifies nothing: it is the companion control
`and the two turns really did differ in evidence` (`want [differ], got [same]`), red because **both**
turns' counters are absent and therefore compare equal. All seven are **expected RED by design until
Group B**, not a regression — but by two distinct mechanisms, and Task 4 has a constraint attached to
the seventh. The
implementation reads `.agent_id` with the type guard at `hooks/lib/loop-index.sh:91`, derives `$tref`
at `:93-94`, and emits `agent_type` exactly once at `:99`. AC3's three gates measure green on it:
(i)=1, (ii)=1, (iii) empty.

Four corrections, all folded into the rows above:

| # | The design said | The code needed |
|---|---|---|
| 1 | "Expect RED on 1–2 assertions" (row 1) | **10**, measured before any production edit. The estimate contradicted this design's own § Test Design, which mandates the happy path, the `agent_type`-absence edge and the fan-out rewrite as well as AC5 — each red pre-fix by construction. An implementer trusting the number over the scenario list would under-build. |
| 2 | `fire()` gains "an optional 4th argument that adds `agent_id` + `agent_type`" (row 1) | Three independent optionals (`$3` tp, `$4` aid, `$5` aty), empty = field **absent from** the payload, plus a separate `fire_aid_json()`. One combined argument cannot express `agent_id` present with `agent_type` absent — a case § Test Design requires — and `--arg` cannot produce a non-string at all. |
| 3 | AC3's gate (ii) stated without its blast radius | The gate caps `agent_type` at one occurrence in the whole file, **comments included**. Group A's first header draft would have made it return 3. Now stated in AC3 and warned in Task 7, which edits prose in that same file. |
| 4 | `call()` "gains an optional `agent_id` parameter" (row 3) | **Two**: `$2` agent_id for the absent-file shape, `$3 = noline` for the file-exists-but-lacks-the-id shape. The design described the second in prose and gave no parameter for it. |

**One addition beyond the design, recorded because it closes the class this design is about.** Group A
added `and that verdict is a real one`, pinning AC14's invariance to `progress` rather than only to
itself. Two ABSENT tier-3 verdicts compare equal, so the invariance assertion would otherwise pass on
a turn that wrote no row at all — a gate green because it measured nothing.

**One claim from Group A that is NOT a finding, recorded so it is not re-opened.** The pre-existing
`haiku` occurrences in test files were reported as a method-surface violation needing cleanup. They
are not. `AGENTS.md` bars a method file from naming a language, a build tool, a domain entity or a
ticket prefix; a model name is none of those and is project-neutral. The count was also wrong —
re-derived here as **6 occurrences across 2 files** (`hooks/lib/test-loop-verdict.sh:157,167,270,309`
and `scripts/test-loop-metrics.sh:39,107`), not 4 in one. **No violation, no cleanup, and Task 7 must
not grow a sweep for it.** What *is* worth keeping is the habit: Group A used a neutral `stub-model`
value in the NEW assertions it wrote, which reads better than a real model name in a stub and costs
nothing. A convention for new code only — it is not a reason to touch the six existing lines.

**The precedent, which is what makes this closure durable.** A rule reading can be re-argued; a
count of what the rule would condemn cannot. Model names already appear in **twelve shipped method
files** — re-derived here with `grep -rlE '\b(haiku|sonnet|opus)\b' agents/ skills/ docs/ rules/`:
`agents/design.md`, `agents/design-review.md`, `agents/inspector.md`, `agents/self-improve.md`,
`agents/spec-writer.md`, `agents/learnings-escalation-audit.md`, `skills/inspect/SKILL.md`,
`skills/interview/SKILL.md`, `skills/improve/SKILL.md`, `skills/improve-global/SKILL.md`,
`skills/ai-audit/SKILL.md`, `skills/ai-audit/reference.md`. Several are `model:` frontmatter, which
is the mechanism by which a subagent is dispatched at all. **Accepting the reported violation would
condemn all twelve**, including the frontmatter this very design's `design` subagent runs under. The
next reader who notices the two test files should be handed this paragraph, not a fresh argument.

### One defect in how this document was built, on three surfaces

Recorded because it is a confirmed pattern rather than three accidents, and because a design about
gates that measure nothing should not be silent about its own:

| round | the claim | what was actually behind it |
|---|---|---|
| 2 | AC17 matches "5 lines across 3 files" | a `-c` count taken from a pattern that was **not** the one written down |
| 3 | "a checker exists that would fail if the row and the run diverged" | a script in a scratch directory, with no existence in the deliverable |
| Group A | "all seven REDs report `null` on the two new fields" | true of **six**; the seventh is a different shape entirely |
| Group B | "the mutation-control class has TWO instances, which degrade silently" | **three** exist, and "silently" is true only of the third — the two tabulated fail LOUDLY |

**One defect: a plausible aggregate standing in for an enumeration.** Each time, a single summary —
a count, a capability, a shape — was asserted over a set whose members were never listed, and each
time the summary was *nearly* right, which is what let it pass. This is the same conclusion
§ Approach (i) reached about `-c` versus `-rnoE`, arrived at independently three times before being
recognised as one thing.

**The fourth instance refines the countermeasure, because its measurement was not the problem.** The
Group B entry's central claim was verified BY CONSTRUCTION — both shapes built, run, byte-compared —
and held on first check. Both residual defects sat in the *summary around* that measurement: an
instance count that lagged a third finding, and an adjective carried from the general class onto two
specific instances where it does not hold. So the lesson is **not** "measure more carefully"; the
measuring was already right. It is: **re-derive the summary from the measurement after every edit to
either.** A summary written once and then extended by hand drifts from the evidence beneath it even
when that evidence is sound.

The countermeasure that works is the one D2 embodies: **make the enumeration the artefact, and make
something re-derive it.** Prose that reports a set is a claim about the set; a listing that a command
reproduces is the set. Where a summary must be stated, state the member count and list the members
beside it, so the two can disagree in public — which is precisely how the seventh RED was caught.

## Group B amendment — what implementation proved untrue about this design

Subtasks 4–6 are implemented. Verified independently: `bash hooks/lib/test-loop-verdict.sh` →
**76 passed, 0 failed, rc 0**; `bash scripts/test-loop-metrics.sh` → **166 passed, 0 failed, rc 0**.
Group A's seven REDs are closed, and **the seventh needed no test change at all** — the fixture at
`hooks/lib/test-loop-verdict.sh:232-246` already gave the two turns different evidence and read
`same` only because both sides were `null`. The comparison was not relaxed, which is the whole of
what Task 4's constraint existed to protect.

Two deliberate deviations, both kept:

- **`every_stored_agent_read` is `($unread | length) == 0`, not `all(…)`** (`scripts/loop-metrics.sh:314`).
  Equivalent on every input including the vacuous one, and it makes the flag and
  `stored_agents_unread` **one derivation instead of two that can drift** — strictly better than what
  this design specified.
- **`refutations` is nested inside `agreement`**: `attribution.agreement.{checked, confirmed,
  refuted, refutations}` (`:350`). AC7's phrasing admits either reading. **This is the binding
  spelling for Task 7** — `agents/inspector.md`'s reading instructions must use it, or they will
  describe a path that does not exist.

### Mutation-control class — THREE instances, in TWO failure modes

The first amendment recorded M2 as a one-off. It is not. **An edit that removes or alters the
literal a mutation control targets makes that control mutate nothing while its "the mutation
applied" assertion still passes** — and the assertions beneath it then measure the *unmutated*
subject.

| control | the literal it targets | what would have defeated it |
|---|---|---|
| **M2** (`scripts/test-loop-metrics.sh:311`) | `ids_of "$s" "${a#agent-}" \|\| note_bad "$s"` | the `note_ok` rewrite drops the `\|\|`; re-targeted in Task 5 |
| **M8** (`:453-455`) | `and $ua_tail),` | appending the new `complete` leg AFTER `$ua_tail` |
| **M13** (`:637-648`) | `whose transcript was never opened` | — the literal held; the hazard was in the `case` BENEATH it, whose arms glob the output. Found and fixed by Group B, explanation at `:640-642` |

**M8 demonstrated, not asserted.** Building the rejected shape and running M8's own mutation against
it:

```
A) leg BEFORE $ua_tail -> M8 "mutation applied" grep -c = 0   (M8 asserts 0)
B) leg AFTER  $ua_tail -> M8 "mutation applied" grep -c = 0   (M8 asserts 0)
   ...and the B mutant is BYTE-IDENTICAL to its source: M8 mutated nothing,
      yet its "the mutation applied" assertion would PASS.
```

Both shapes report `0` — **for opposite reasons.** In A the literal was found and replaced; in B it
was never there, so the control degrades into assertions about an **unmodified** reader.

**But whether the SUITE notices is a second, separable question — and this is where the class splits.**
The control's own `check "the mutation applied"` is silent in both modes, always. What differs is what
sits beneath it:

| mode | what sits beneath the control | result when the mutation silently fails to apply |
|---|---|---|
| **LOUD** — M2, M8 | assertions that DEMAND the damaged behaviour | they run against an undamaged subject and **fail** |
| **SILENT** — M13 | a `case` whose arms GLOB the output | an unmutated reader can still match a passing arm — **green** |

Measured, by running the whole suite against the rejected leg-after reader in an isolated copy:
**163 passed, 3 failed, rc 1** —

```
FAIL without the position test, six misattributed calls read as complete (want [true], got [false])
FAIL the control did not reproduce the false reassurance
FAIL without the leg, a ledger naming an unread agent reads as complete (want [true], got [false])
```

Two things that run counter to the first draft of this section and are worth stating plainly.
**First, the leg-after shape would have been caught — loudly.** An earlier wording here said the
control "silently degrades", which is true of the control's own assertion and **wrong about M2 and
M8 as a whole**: their dependent assertions demand the damage and fail without it. That adjective
was carried from the general class onto two specific instances where it does not hold. **Second, the
rejected shape defeats TWO controls, not one** — M12 (`:631-635`) targets `$every_read and $ua_tail`,
which the reorder also destroys, and its dependent assertion is the third failure above.

**M13 is the genuinely silent member**, and therefore the one to look hardest for: its literal held,
so nothing about the control's own check was wrong; the hazard was that the `case` beneath it asked
only whether the header and the closing sentence were both present, which the **unmutated** reader
also satisfies because it prints the reason between them.

**Obligation for Group C and `self-review`, unchanged in force and now sharper in aim:** for every
mutation control whose target literal your edits touch, confirm a `0` means "replaced", not "absent"
— and when the assertion beneath it is a `case` or any glob match rather than an equality, treat it
as the silent mode and check it by hand, because the suite will not tell you.
Implemented correctly at `scripts/loop-metrics.sh:343`, with `$ua_tail` last.

**Obligation for Group C and `self-review`: for every mutation control whose target literal your
edits touch, check that the control still mutates** — read the `grep -c` assertion and confirm a
`0` means "replaced", not "absent". The two known instances are a class, not a checklist; do not
check only these two.

### D2's retirement, and the defect in its own scope note

**D2 is retired as of Group B.** Measured after subtask 6: `live=10 recorded=12`, rc 1, missing
`scripts/loop-metrics.sh:236` and `:313` — both rewritten by Group B while implementing the reader,
because they live in the file it was editing.

**D2's scope note was wrong, and in an instructive way.** It said to run D2 "once at the start of
Task 7 before any prose is rewritten" and to retire it after — assuming all prose rewriting happens
in Task 7. It does not: two of the six stale lines were comments in the reader itself. The real
retirement condition was always **"the first prose rewrite"**, which has now happened two subtasks
early. That is the same ambiguity D2's scope note was written to prevent for Task 7 — arriving one
subtask too late, in the note itself.

**What D2 conflated.** It compared the recorded enumeration against a LIVE run, which answers two
questions at once: *(a) is the recorded pattern the one that produced the recorded enumeration?*
(document integrity — its actual purpose) and *(b) does the tree still match?* (tree state — which
this ticket exists to change). Once (b) starts moving, (a) is no longer separable, and re-recording
the enumeration after every edit would turn D2 into bookkeeping that rots rather than a guard.

**Its replacement in Task 7 is a pre-flight enumeration**, which covers the residual D2 leaves
behind: AC17's "must be EMPTY" cannot distinguish *all six lines fixed* from *pattern too narrow to
match anything* — an over-narrow pattern also returns empty. So Task 7 runs the pattern **first**,
records what it still matches, and that non-empty listing is the positive control proving the gate
can fire on the surfaces about to be edited. **Current state, measured: 10 matches on 4 lines across
2 files** — `agents/inspector.md:66` (×3) and `:125`, `docs/claude-tools-hierarchy.md:101` (×3) and
`:110` (×3). `scripts/loop-metrics.sh` is already clean.

## Risks

- **The counter is written inside the subshell anyway, reports 0 forever, and every assertion passes.**
  Mitigation: AC12 requires *both* a non-zero case and a zero case, so the counter cannot pass by
  being stuck at either end; the redirect-vs-pipe distinction is measured in § Approach (c) rather
  than asserted; and the design names `while … done < "$WORK/rows"` as the mechanism, so a reviewer can
  check the construct without running anything.
- **`flagged` counted per line of `detail` rather than per flagged call.** The measured probe found
  one `tool_use_id` twice in its own transcript, so this inflates silently on exactly the input the
  ticket is about. Mitigation: `flagged` increments once per row read from `"$WORK/rows"`, before any
  guard; the AC11 test asserts it equals the number of flagged ledger rows, not the line count of
  `detail`.
- **AC5's guard is written so it passes against the pre-fix code too.** ✅ **CONFIRMED IN GROUP A,
  exactly as predicted.** The `transcript` half passes pre-fix (the old code stored
  `transcript_path` verbatim); only the `agent_id` half fails. Measured: `no agent_id in the payload
  -> main` went RED wanting `main`, getting `abc123`, while its sibling `and the path is stored
  verbatim, not re-derived` **passed against pre-fix code**. Mitigation held: Task 1 was run and seen
  RED before Task 2, and the RED was on the `agent_id` assertion specifically. Left in place as a
  live risk for anyone re-running the sequence.
- **`every_stored_agent_read` flips `complete` to false on a ledger it should not.** Two shapes:
  an `agent_id` of `null` from a pre-`agent_id` build, and a transcript that exists and parses but
  holds no `tool_use`. Mitigation: `select(. != null and . != "main")` handles the first; the
  shell-owned `read_ok` list (rather than inferring readability from `$by_id`) handles the second.
  AC10's vacuous-satisfaction test is the guard that catches a regression here.
- **The `read_ok` list loses its separator.** `scripts/loop-metrics.sh:261-267` documents this exact
  bug: `$(printf '\n')` is the empty string, so two ids concatenate into one that matches nothing.
  Mitigation: `note_ok` reuses the existing `NL=$'\n'`, and the AC10 test fixture must carry **two**
  subagent transcripts — a one-element fixture cannot see it.
- **`agent_type` leaks into a detector.** Mitigation: AC3's grep gate, which today returns rc 1 on
  both hook files, must after the change return exactly one line — the ledger emit in
  `loop-index.sh` — and nothing in `loop-verdict.sh`.
- **A prose surface is missed, and the gate that was supposed to catch it cannot see it.** The
  Inspect group's premise is that four vocabularies describe one mechanism, so a token sweep reaches
  at most one — and this design demonstrated the failure on itself **twice**. Round 1's pattern
  missed `scripts/loop-metrics.sh:313` (sentence straddles a line break) and could never match
  `skills/inspect/SKILL.md` (omission, not false claim). Round 2's *recorded* pattern then silently
  dropped the phrase that was carrying `docs/claude-tools-hierarchy.md:110`, while the recorded `-c`
  count still implied that surface was covered. Mitigation, in three parts: the gate is recorded as
  a **`grep -rnoE` enumeration of every match** rather than a per-file count — a count answers "can
  it fire", only a listing answers "which surfaces does it police", and § Risks claims the second;
  the pattern in § Approach (i) was re-measured by copying it **out of this document**, not from the
  scratch buffer it was drafted in; and it has a **positive** half for surfaces whose defect is
  silence.
- **A non-string `agent_id` silently drops the ledger row.** Measured: `agent_id: 12345` makes the
  single hot-path `jq` exit 5, `out` is empty, `:87` exits 0, and the call never enters the index —
  a degrade the wrong way, past the one constraint that says malformed input must become `"main"`.
  Mitigation: the `| type == "string"` guard in § Approach (a), plus the test-design case below.
  Note this failure is INVISIBLE to a suite that only checks exit status: the hook exits 0 either
  way, so the assertion has to be on the ledger CONTENTS.
- **A new `complete` leg turns the census false with no reason printed**, and takes the benign
  in-flight gloss away from the live sessions that most need it. Mitigation: § Approach (g2)'s
  fourth renderer clause plus `stored_agents_unread`, covered by D1 below.
- **Re-targeting the M2 control weakens it instead of moving it.** A perl mutation that matches
  nothing leaves the reader unmutated and every downstream assertion measuring the wrong thing.
  Mitigation: `:312`'s "the mutation applied" assertion must stay, and must be seen to FAIL against
  a deliberately wrong pattern before the re-target is accepted.
- **The PR ships without reaching an installed copy.** Mitigation: AC18's version bump, plus
  `scripts/check-release.sh` before opening the PR (AGENTS.md § Build & Test gate 7).
- **A new `.sh` file escapes the `bash -n` gate.** No new scripts are planned, so `git ls-files`
  covers everything — but if Task 3 or 5 adds a fixture script, `git add -N` it first and re-check
  the processed COUNT, not only the exit status.

## Test Design

**Test context.** No test runner exists; each suite is a shell script with its own `check` / `has` /
`hasnt` helpers and a `N passed, M failed` footer. Fixtures are built by RUNNING the real hook
(`test-loop-verdict.sh:56-68`) or by emitting ledger lines with `jq -nc`
(`test-loop-metrics.sh:242-249`). Every guard carries its own positive control — a mutated copy of
the script under test that defeats one guard and must make the damage reappear
(`test-loop-metrics.sh:300-330` is the established pattern).

**Baseline, measured this session, before any change:**

| Suite | Result |
|---|---|
| `bash hooks/lib/test-loop-index.sh` | 66 passed, 0 failed |
| `bash hooks/lib/test-loop-verdict.sh` | 64 passed, 0 failed |
| `bash scripts/test-loop-metrics.sh` | 130 passed, 0 failed |
| `bash scripts/test-plugin-manifest.sh` | 30 passed, 0 failed |
| `bash scripts/check-references.sh` | resolves |
| `bash scripts/check-readme-update.sh` | passes |
| `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json` | rc 0 |
| `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` | rc 0 |
| `git ls-files -z '*.sh' \| tr -dc '\0' \| wc -c` | **35** tracked scripts — the COUNT the gate must still process |

### Per-task scenarios

**Task 1–2 (`hooks/lib/test-loop-index.sh`, `hooks/lib/loop-index.sh`)**
- Happy path: parent `transcript_path` + `agent_id` present → row carries that id, `agent_type`, and
  the derived pointer.
- Fan-out: three calls, one `fp`, identical parent `transcript_path`, three distinct `agent_id`s →
  `permissionDecision:"ask"`, `fan-out duplication`, `3 different agents`.
- Edge — the regression: subagent-shaped `transcript_path`, **no** `agent_id` → `main`, transcript
  verbatim.
- Edge — absence: no `agent_type` → `-`. No `transcript_path` + `agent_id` present → `transcript`
  stays `-`, not `-/subagents/…`.
- Edge — **malformed type**: `agent_id` as a number, and as an array → `agent_id:"main"`, transcript
  unchanged, **and a ledger row is written at all**. Assert on the ledger CONTENTS, never on the
  hook's exit status: the pre-guard code exits 0 too, having written nothing, so an rc-only
  assertion passes against the defect.
- Edge — the pointer is not stat'd: derived path stored although the file does not exist.
- Unchanged: every existing failure path still exits 0 (empty stdin, malformed JSON, no session_id,
  unwritable ledger dir).

**Task 3–4 (`hooks/lib/test-loop-verdict.sh`, `hooks/lib/loop-verdict.sh`)**
- Mixed: some flagged calls resolve, some do not → `unresolved_calls > 0`, `flagged_calls` = flagged
  rows, verdict still written.
- All resolve → `unresolved_calls == 0` (the other end of the counter).
- Edge — failure 3: stored `transcript` exists, does not contain the id → unresolved.
- Edge — absent file: derived pointer names nothing → unresolved.
- Invariance: same stubbed answer, with and without unresolved calls → same `verdict`.
- Unchanged: `[ -n "$detail" ] || mark_turn` still bails when nothing resolves (that total-loss case
  is § Deferred, not this ticket); `mktemp` failure degrades rather than errors.

**Task 5–6 (`scripts/test-loop-metrics.sh`, `scripts/loop-metrics.sh`)**
- Agreement: stored and recovered agree on some ids, disagree on others, and one call is
  unattributed → counts exact, unattributed excluded from all three, `refutations[]` linked.
- Cap: >5 refutations → `refutations | length == 5`, `refuted` the full number.
- Human render: the `--for` text output names a refuting `tool_use_id` with both values.
- `every_stored_agent_read`: true (all non-`main` ids readable), false (one transcript missing),
  vacuously true (`stored_agent_ids == ["main"]`) with `complete` unchanged from today.
- NOTE: present and reworded on a pre-fix-shaped ledger; absent on one carrying real ids.
- **Renderer, `every_stored_agent_read` false in isolation** (main transcript read, nothing
  unparseable, unattributed at tail): the INCOMPLETE line names a reason and lists the unread ids —
  it does not degenerate to the bare header plus "Treat the 0 unattributed call(s) as unknown".
- Positive controls: delete the agreement comparison → the refutation disappears; delete the
  `every_stored_agent_read` leg → the missing-transcript ledger reads as `complete`; delete the
  fourth renderer clause → the reasonless INCOMPLETE line returns.
- **M2 re-target** (`:310-317`): the mutation still applies (`:312` → `0`), and the two dependent
  assertions still see the subagent's calls vanish.

### AC verification

Every command below was **executed while writing this design**. Where a gate's failure mode is EMPTY
output, the note records what made it come back non-empty.

| AC | Verified by |
|---|---|
| AC1 | `bash hooks/lib/test-loop-index.sh` — the AC5 section; plus `grep -n 'test("/subagents/agent-' hooks/lib/loop-index.sh` must be EMPTY. *(Non-empty today: it matches `:76` — that is the proof the gate can fire.)* |
| AC2 | `bash hooks/lib/test-loop-index.sh` — asserts `"transcript":"/tmp/proj/sess-1/subagents/agent-<id>.jsonl"` for a payload carrying `agent_id`, and the unchanged path when absent. Derivation independently re-run this session over all four payload shapes (§ Approach table). |
| AC3 | `bash hooks/lib/test-loop-index.sh` (the field is stored, `-` when absent) **and** two greps, because a count alone does not check WHICH line: (i) `grep -n 'agent_type: (.agent_type // "-")' hooks/lib/loop-index.sh` must print exactly the ledger-emit line — pinning the text, so a detector branch cannot satisfy the gate by moving the emit elsewhere; (ii) `grep -c 'agent_type' hooks/lib/loop-index.sh` must be `1` — taken with (i), the single occurrence IS the emit, so no detector branch can exist; and (iii) `grep -n 'agent_type' hooks/lib/loop-verdict.sh` must be EMPTY. Three bare greps, never a pipeline — a search is a gate, and a pipeline's rc is the last command's. **Gate (ii) forbids the token ANYWHERE in that file except the emit — including in a COMMENT, and that is deliberate rather than an oversight.** "Exactly one occurrence" is what proves no detector branch exists; the moment a prose mention is exempted, the gate stops distinguishing a comment from a branch. Group A hit this: its first draft of the fan-out header paragraph named the token twice and would have made the gate return 3. The fix is to write the concept without the identifier — it used "the agent TYPE stored beside it". **Task 7 edits prose in this same file and will hit the same edge.** *Measured on the implemented file: (i)=1, (ii)=1, (iii) rc 1 — all three green.* *(Both files return rc 1 on `agent_type` today, so every one of these is a real change rather than a tautology. Note `subagent_type` contains `agent_type` as a substring; neither hook file contains `subagent_type` today, and gate (ii) would catch it if one appeared.)* |
| AC4 | `bash hooks/lib/test-loop-index.sh` — the rewritten fan-out section: `fan-out duplication`, `3 different agents`, one `fp` across several `agent_id`s, identical `transcript_path` on every fired payload. |
| AC5 | `bash hooks/lib/test-loop-index.sh` — run it at the end of Task 1 and record that the `agent_id` assertion is RED; re-run after Task 2 and record it GREEN. |
| AC6 | `bash hooks/lib/test-loop-index.sh` — the pointer assertion paired with `[ ! -f "$derived" ]` in the same section. |
| AC7 | `bash scripts/test-loop-metrics.sh` — `attribution.agreement.checked/confirmed/refuted` and `refutations[0] | .tool_use_id, .stored, .recovered`; plus the assertion that an unattributed call appears in `attribution.unattributed` and in none of the three counts. |
| AC8 | `bash scripts/test-loop-metrics.sh` — the >5-refutation ledger: `refutations | length == 5` and `refuted` the full count. |
| AC9 | `bash scripts/test-loop-metrics.sh` — `has` against the human `--for` output for the refuting `tool_use_id` and both values. |
| AC10 | `bash scripts/test-loop-metrics.sh` — the three `every_stored_agent_read` branches. jq semantics for the vacuous leg re-derived this session: `jq -n '[] \| all(. == "x")'` → `true`. |
| AC11 | `bash hooks/lib/test-loop-verdict.sh` — `jq -r '.flagged_calls, .unresolved_calls'` on the tier-3 row, both integers, on every tier-3 case in the suite. |
| AC12 | `bash hooks/lib/test-loop-verdict.sh` — the non-zero case AND the zero case. The construct itself is checked by reading the loop: it must be `done < "$WORK/rows"`, never `\| while`. Measured shape comparison in § Approach (c) (`n=0` vs `flagged=3 unresolved=1`). |
| AC13 | `bash hooks/lib/test-loop-verdict.sh` — the "file exists, id absent" case. A `[ -f ]`-only implementation counts it resolved and fails this assertion. |
| AC14 | `bash hooks/lib/test-loop-verdict.sh` — same `STUB_ANSWER`, two turns differing only in unresolved calls, same `.verdict`. |
| AC15 | `bash scripts/test-loop-metrics.sh` — `has` the reworded string on a pre-fix-shaped ledger, `hasnt`/`case` the NOTE on a ledger carrying real ids. |
| AC16 | `git diff main -- scripts/loop-metrics.sh hooks/lib/loop-index.sh hooks/lib/loop-verdict.sh \| grep -nE '^\+.*(strftime\|fromdateiso8601\|mktime\|schema_version\|ledger_version\|since\|written_before\|written_after)'` — must be EMPTY. *Proven able to match:* the same pattern run over a synthetic `+ if .schema_version > 2 then` line returned `1:+ if .schema_version > 2 then`, rc 0. |
| AC17 | **Two halves, because one surface carries an omission rather than a false claim.** **Negative** — `grep -rnoE 'currently unreachable\|arm keyed on it (can never fire\|does not fire)\|reads \`main\` for every call\|The live hook cannot see it either\|field is currently wrong\|reader has no list of what should exist\|ledger field that would be that list is the broken one\|nothing enumerates the transcripts that ought to exist\|three things the reader can actually check\|it is the conjunction of the three' agents/inspector.md docs/claude-tools-hierarchy.md skills/inspect/SKILL.md scripts/loop-metrics.sh hooks/lib/loop-index.sh` — must be EMPTY. **Run it with `-no` and read the enumeration, not `-c`**: round 2 recorded a `-c` figure taken from a *different* pattern than the one it wrote down, and bare integers make two patterns look interchangeable where a listing would have shown `docs/claude-tools-hierarchy.md:110` simply missing. *Measured today, by copying this pattern out of this document and running it: **12 matches on 6 distinct lines across 3 files** — `agents/inspector.md:66` (×3) and `:125`, `docs/claude-tools-hierarchy.md:101` (×3) and `:110` (×3), `scripts/loop-metrics.sh:236` and `:313`; `skills/inspect/SKILL.md` and `hooks/lib/loop-index.sh` match nothing.* The full listing is in § Approach (i). **Positive** — six probes, each of which must be NON-empty: `grep -n 'agreement' agents/inspector.md`, `grep -n 'every_stored_agent_read' agents/inspector.md`, `grep -n 'unresolved_calls' agents/inspector.md`, `grep -n 'stored_agents_unread' agents/inspector.md`, `grep -n 'agreement' skills/inspect/SKILL.md`, `grep -n 'stored_agents_unread' skills/inspect/SKILL.md`. All six return rc 1 today, so each is a real assertion. The sixth exists for symmetry: Task 7 names `stored_agents_unread` for the skill as well as the agent, and a field probed on only one of the two surfaces it is written to is half-policed. The positive half is the only thing that can police `skills/inspect/SKILL.md`, whose negative count is 0 and correctly so. |
| AC18 | `jq -r .version .claude-plugin/plugin.json` → `0.1.30`; `bash scripts/test-plugin-manifest.sh` (30 passed today); `bash scripts/check-release.sh` before opening the PR. |
| AC19 | Each as its OWN bare Bash call, never chained: `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json`; `bash scripts/check-references.sh`; `bash scripts/check-readme-update.sh`; `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` **in that exact form**, with `git ls-files -z '*.sh' \| tr -dc '\0' \| wc -c` read beside it and compared against the **35** measured today; then every named suite in AGENTS.md § Build & Test, with `hooks/lib/test-loop-index.sh`, `hooks/lib/test-loop-verdict.sh` and `scripts/test-loop-metrics.sh` among them. |
| **D2** *(design-added — a contract-integrity guard on THIS document)* | **The AC17 pattern as recorded reproduces the enumeration as recorded.** Run from the repo root, against this design file (`$D`): extract the pattern from the AC17 row, un-escape the markdown table's `\|` and the inline-code `` \` ``, run it, and `diff` the sorted result against the § Approach (i) enumeration. The recorded spelling is `${CLAUDE_PLUGIN_ROOT}`-free and repo-relative because it reads a project-data file:<br>`pat=$(grep -m1 -o "grep -rnoE '[^']*'" "$D" \| sed "s/^grep -rnoE '//; s/'$//"); pat=${pat//\\\|/\|}; pat=${pat//\\\`/\`}`<br>`grep -rnoE "$pat" agents/inspector.md docs/claude-tools-hierarchy.md skills/inspect/SKILL.md scripts/loop-metrics.sh hooks/lib/loop-index.sh \| sort > /tmp/live`<br>`grep -E '^(agents\|docs\|scripts\|skills\|hooks)/[^:]*:[0-9]+:' "$D" \| sort > /tmp/recorded`<br>`diff /tmp/recorded /tmp/live`<br>**Sort both sides** — `grep -r`'s file order is not stable across runs, and an unsorted diff fails for that alone. **Exercised in BOTH directions, this session, which is the half that makes it a guard rather than a hope:** (a) against this file → `live=12 recorded=12`, PASS, rc 0; (b) against a copy with `ledger field that would be that list is the broken one` deleted **from the AC17 row only** — i.e. the exact round-2 defect re-staged → `live=11 recorded=12`, FAIL rc 1, naming `docs/claude-tools-hierarchy.md:110` as the lost line; (c) against a copy with one line deleted from the enumeration block instead → `live=12 recorded=11`, FAIL rc 1. It catches drift on either side. **One ordering requirement, introduced by D2 itself:** the extraction takes the FIRST `grep -rnoE '…'` in the file, so the AC17 row must stay above this one. D2's own recorded command contains that same token — verified after adding it, D2 still reports `live=12 recorded=12` PASS on this file. Were a future edit to invert the order, the extracted pattern would become `[^']*`, which matches everything, so the diff blows up rather than quietly comparing the wrong thing; the failure is loud in either arrangement. **🔴 RETIRED AS OF GROUP B — do not run it; rc 1 is now its expected output.** Measured after subtask 6: `live=10 recorded=12`, rc 1, the two missing lines being `scripts/loop-metrics.sh:236` and `:313`. **That is not a regression.** Group B legitimately rewrote those two comments while implementing the reader — they live in the file it was editing. **The retirement condition was always "the first prose rewrite"; the scope note wrongly assumed that could only happen in Task 7,** and it is recorded as a defect in § D2's retirement below rather than quietly corrected. D2's replacement for Task 7 is the pre-flight enumeration named there. Kept in the table, marked retired, because deleting it would leave a future reader to rediscover both the guard and the reason it stopped applying. |
| **D1** *(design-added — not a spec AC; see § Open questions)* | **Whenever `complete` is false, the INCOMPLETE line names a reason.** `bash scripts/test-loop-metrics.sh` — a fixture where `main_transcript_read` is true, `unreadable_transcripts` is empty, `unattributed_at_tail` is true, and only `every_stored_agent_read` is false: the human `--for` output must name the unread agent id(s), and must NOT be the bare header followed by "Treat the 0 unattributed call(s) as unknown". Paired with a positive control that removes the fourth clause and shows the reasonless line return. Without D1, AC10 is satisfiable by a change that makes the reader's headline output strictly worse than before. |

> **Two spellings that would mask AC19 and must not be used.** `find … -exec bash -n {} +` batches,
> so only the first file is parsed and the rest become positional parameters — rc 0, no output, the
> quietest possible false green. A `for` loop exits with the LAST iteration's status, erasing every
> earlier failure. Only `xargs -0 -n1` propagates. The suites are gates too: run each bare, never
> piped into `tail`, and redirect to a FILE if the output is long.

## Open questions

**One, and it is a routing question for the orchestrator, not a design gap.**

**D1 is carried here as a design-added check rather than a spec acceptance criterion.** The renderer
gap it closes is a consequence of AC10 (a `complete` leg that cannot explain its own false branch is
not properly joined to the conjunction), and the spec's § Technical constraints already binds it
("`complete` stays a measurement, not a claim"). So the design covers it either way and no
implementer is left guessing. But if the orchestrator wants it enforced as a first-class AC that
`self-review` re-runs by number, that is a **Spec Amendment** — re-invoke `spec-writer` with it in
`prior_qa`, then `design` → `design-review`. The design subagent cannot add a spec AC, and writing
one here would be the shortcut the AXIOM forbids. **No blocker either way.**

Otherwise: the spec records all three round-1 answers in § Key decisions, the genuinely unmeasurable
items are in § Deferred with the measurement that will settle each, and every load-bearing mechanism
this design relies on — the payload derivation including its type guard, the subshell hazard and its
fix, jq's `all` on an empty array, the in-repo temp idiom, the M2 control's perl pattern, and every
grep gate whose failure mode is empty output — was executed rather than assumed.
