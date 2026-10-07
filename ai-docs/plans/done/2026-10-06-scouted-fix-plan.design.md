# Design: Scouted, mechanically-gated fix plan for review-fix rounds

**Ticket:** GH-91
**Date:** 2026-10-06
**Spec:** ai-docs/plans/2026-10-06-scouted-fix-plan.spec.md
**Design round:** 3 of 3 — first revised against the second Spec Amendment, which fixes the full arm
precedence. **No spec size is recorded here:** this header carried one, the spec has taken six
amendments since, and the figure was stale within the round — re-derive with `wc -c` when it matters.
**Status:** all seven decomposition subtasks (1, 1a, 2, 3, 4, 5, 6) have landed — re-derived from the
working tree, not inherited. The mechanism has had **two real runs** on this task's own review rounds:
the first produced a valid plan over eight real findings, and the second was ROUTED by its own gate onto
this document — both records kept in full below and in the AC-verification map.
**Amendment sections are carried newest-first, below this header, and each one names its own approval**
— no running total is kept here, because this header stated "two" through three subsequent amendments
and an orientation line that counts is an orientation line that goes stale. The one currently being
applied is **§ Design Amendment — round 9: the post-apply size check is WITHDRAWN**, which
subsumes the round-3 routing amendment below it; the round-3 section's own owed Spec Amendment to
AC2/AC3 has **LANDED**, so its code half is sanctioned. Design-review cap is spent at
3 of 3: **a burned cap ends the LOOP, not the gate** — one verification pass, then ship.

---

## Design Amendment — round 9: the post-apply size check is WITHDRAWN (user-approved)

**This amendment DELETES more than it adds, and that is the point.** Round 8's size machinery — the
declared-vs-actual trigger, the tolerance as a second quantity, the like-for-like subtraction, the
comparable-declared figure, the `check-ignore` predicate and the zero-declaration refusal that existed to
feed it — is withdrawn in every form. What replaces it is shorter than what it replaces.

### What was withdrawn, recorded once rather than reverted

| Form | Fate |
|---|---|
| an absolute verdict on the applied total against the threshold | shipped; retired on evidence — one round declared 54 lines and landed 743, a verdict nobody could act on |
| a trigger on declared-vs-actual agreement within a tolerance | specified in round 8, **never shipped**; withdrawn because the subtraction it rested on does not come out equal on honest input, so it fired on honest plans |
| the tolerance as AC5's second quantity | withdrawn with it; **AC5 is back to ONE quantity with ONE firing site**, the pre-apply gate |
| the `check-ignore` predicate and its 128-error branch | **withdrawn, and there was no code to remove** — re-derived: `grep -c 'check-ignore' skills/task/scripts/check-fix-plan.sh` → **0**. It existed only in round 8's proposal |
| the A4 refusal of a non-`fix` row declaring non-zero | withdrawn; it existed to make the subtraction honest, and with no subtraction it has no purpose in this task |

> **The sentences round 8 wrote for that machinery are superseded wherever they still stand.** The records
> of *what was specified and why it was removed* stay — that history is the evidence the user's decision
> rests on. Corrected at their own sites: § The gate: arms and verdict format (the arm table, the sample
> verdict), § the reason-token list, and the AC5 / AC18 / AC22 verification rows.
>
> **THE CLAIM THAT USED TO CLOSE THIS PARAGRAPH IS WITHDRAWN AS FALSE.** It read: "no withdrawn sentence
> anywhere in this document now describes the mechanism being built", and the enumeration beside it listed
> only the sites I had visited — **a completeness claim whose evidence was a list of what I happened to
> correct**, which is the one shape that cannot support it. The withdrawal also invalidates **structural
> counts keyed on other tokens**, which no sweep for the machinery's own words reaches:
>
> | Count | Was | Is | Sites, by token |
> |---|---|---|---|
> | the round's beats | four | **five** | "a four-beat round"; `SKILL.md`'s four-beat sequence in § Size budget |
> | the gate's verbs | three | **four** (`record` is added) | "One script, three verbs"; the heading "Why one script with three verbs"; "one gate script with three verbs exists" |
> | the post-apply arms | two | **one** | the verb table's `applied` row, "arms (a) and (b)"; § Size budget's "the two post-apply arms as one sentence each"; `agents/fix-apply.md`'s "## The two arms your diff is measured by" |
> | the threshold's firing sites | both | **one** | "Putting both firing sites …"; "the moment both verdicts carry their threshold value" |
>
> **Three of those are consequential rather than cosmetic and are corrected in place here:** § Size
> budget's split (it is the budget the instruction-text item implements), the verb table's `applied` row
> (the canonical verb map an implementer reads), and § Test Design's **T1-I** row (the place legs are read
> from, and it still specified a leg asserting the deleted arm's boundary both ways). The rest are counts in
> narrative prose; they are listed above **by token rather than by line** so the handoff sweeps them with a
> search rather than a recollection. **The lesson, which is this document's own and was ignored one
> paragraph above: a completeness claim needs a search, not an enumeration.**
>
> **Why removing the arm loses no coverage**, which is what makes this a simplification rather than a
> retreat: the arm existed so that no round lands more work than the threshold without a human seeing it.
> The direct question answers that better and more cheaply — a plan declaring twenty lines and landing
> seven hundred **is** a diff that does not match its plan, and a plan that honestly declares seven
> hundred was already stopped at declaration time by the pre-apply escalation. The number was a poor proxy
> for a question that can be asked directly.

### The micro-loop — beats, owners, and where the cap is counted

Unconditional, every round, between the apply and the full review pass. **Each beat names its owner,
because the one failure that matters is a beat drifting to a party that cannot be held to its bound.**

| # | Beat | Owner | Bound |
|---|---|---|---|
| 1 | the mechanical file check — `check-fix-plan.sh applied`, arm (a): which paths the diff touched that no row named | the **gate** (a script) | no model judgement anywhere in it; it is set membership over the diff and the `Target` column |
| 2 | ONE bounded question, fed beat 1's result, **naming the row and the divergence** | the **orchestrator**, spawning once | three fixed inputs, two-word output — § The bound below |
| 3 | on a mismatch: back for re-fixing, **with that divergence named** | the **orchestrator**, re-spawning `fix-apply` | the re-fix brief carries the named row and divergence and nothing new; it is not a fresh plan |
| 4 | on a burned cap: escalate to the user with a **process recommendation** | the **orchestrator** | it recommends; the user decides (AC9) |
| 5 | the full review pass | as already shipped | runs **either way**, in every one of the above cases |

**The cap is three attempts, and it is counted in the round's plan section — one line per attempt, written
by the orchestrator before beat 3 re-spawns.** Three reasons that location rather than a counter in the
gate: the gate is stateless between invocations by construction (it recomputes from the tree each time);
the progress file is the surface that already survives a compaction and a session restart, which is
exactly when a cap is lost; and an attempt count that lives beside the plan it is counting attempts
against is auditable by the same read that checks the plan.

> **THE ATTEMPT LINE'S SHAPE IS PART OF THE SPECIFICATION, and "one line per attempt" without one was a
> defect.** It must **NOT begin with `|`.** Re-derived from the parser: `check-fix-plan.sh:144`'s
> `table_rows()` matches `/^[[:space:]]*\|/`, so **any** line in the section whose first non-space character
> is a pipe is read as a plan row — and one with the wrong cell count refuses the whole plan under
> `plan-row-malformed`. An attempt log written as a little table would therefore break the gate that reads
> the section it lives in. **The shape that ships is a bullet:**
>
> ```
> - attempt 2 — finding 5, row 1: the divergence named was <quoted reason>; re-fix dispatched
> ```
>
> A leading `-` is invisible to the row parser, the text is free-form after it, and the count is
> `grep -c '^- attempt '` over the section — one command, no parser. **A literal `|` anywhere in the quoted
> reason is fine on a bullet** and would not be on a row, which is the second reason not to use one.
> **This is the shape the workflow already ships in its two review loops — a cap of three, then
> surface — so the existing rule governs it unchanged: a burned cap ends the LOOP, not the GATE.** Work
> done after the cap still gets its review pass. Nothing new is invented about caps here, and that is
> deliberate: a cap with its own semantics would be one more thing to learn. **Counted, rather than
> asserted: this is the FOURTH cap in the workflow, not the third** — the two review loops, the scout's
> rewrite cap at `skills/task/reference.md:216` ("max 3 rounds"), and now this one. The argument is
> *stronger* at four than at three, not weaker: the more caps there are, the more a fourth set of semantics
> costs, and all four are the same shape — three attempts, then surface.

**What the escalation hands the user, as a fixed shape rather than a free paragraph** — because an
escalation that varies in shape is one the user must read from scratch each time:

| Field | Content |
|---|---|
| which row | the finding number and the `Target` of the row that diverged |
| what diverged | the named divergence, quoted from the question's reason, not re-derived |
| the attempts | three, and what changed between them |
| the recommendation | exactly one of **re-fix / amend-the-plan / accept**, with one sentence of why |

**The recommendation is a recommendation.** It names a course; it does not take it. The decision
terminates at the user, as AC9 requires of every escalation path, and nothing in beats 2–4 hands a
subagent that decision.

### The bound on the question — now MORE important, because it is unconditional

The failure mode is unchanged and its cost has gone up: **if the input widens or the output becomes
interpretable, this is a second review pass and we have added the cost this task exists to remove.**

| Element | Bound |
|---|---|
| inputs | exactly **THREE**: the round's own plan section, the applied change, and **beat 1's result — the list of files no row named**. Nothing else: not the findings table, not the spec, not the session history. The orchestrator assembles the list, so the question cannot widen it by reading more |
| output | exactly one of **`MATCH`** or **`DIVERGE`**, plus a reason in prose. The two words are the closed set's **members**, not examples. An answer outside the set is **refused, not interpreted**, and the refusal is **computed** — see § The vocabulary below |
| count | ONE question per attempt. No retry of the question itself, no second opinion |
| authority | none to apply, none to decide rework. It may not edit and may not re-run the fix; its answer feeds the next attempt and nothing else |
| what follows | the review pass, on every path |

> **Why the two-word output is the load-bearing bound and not a convenience.** An interpretable answer
> makes the orchestrator a judge of prose, which is a review pass by another name. A closed two-word
> vocabulary makes the answer mechanically checkable, so refusing an out-of-vocabulary answer is a *check*
> rather than a judgement — and that refusal is what stops the bound eroding one hedged sentence at a time.
>
> **THE TWO WORDS ARE NAMED: `MATCH` and `DIVERGE`.** A set of cardinality two whose members are unnamed
> cannot be checked, which is how the first real run came to invent its own pair at dispatch time. Naming
> them is what turns the bound from a description into a gate.
>
> **`MATCH` / `MISMATCH` was rejected although it reads better, and the reason is worth keeping because it
> is the kind that gets lost.** `MATCH` is a **substring** of `MISMATCH`, so any implementation that
> compares by containment rather than by equality — `case $x in *MATCH*)`, `[[ $x == *MATCH* ]]`, a
> `grep MATCH` — accepts `MISMATCH` as `MATCH` and reports agreement on a diverging round. **A vocabulary
> that is only safe under exact comparison is a vocabulary that depends on the implementer not slipping**,
> and a computable refusal is this round's entire point. `MATCH` and `DIVERGE` stand in no substring
> relation to each other and do not even share a first letter, so a sloppy comparison fails loudly instead
> of quietly.
>
> **Non-collision was CHECKED, not assumed.** Against the gate's own decision vocabulary, enumerated from
> source — `PASS`, `OK`, `REFUSE`, `ESCALATE`, `FINDING`, `ROUTE-SPEC`, `ROUTE-DESIGN` — and against the
> plan's five disposition tokens (`fix`, `object:`, `resolved:`, `amendment: spec`, `amendment: design`):
> no collision either way. And `grep -n 'MATCH\|DIVERGE'` over the gate, its suite's siblings, both agent
> contracts, the recipe, the step text and the progress-file template returns **nothing**, so neither word
> is already in use as anything else in this mechanism.
>
> **The third input is NEW and it reverses one of round 8's three arguments. Named rather than quietly
> dropped.** Round 8 decided the question must **not** consume arm (a)'s result, and its second reason was
> "feeding it in would widen AC23's input, which AC23 forbids". AC23 now makes that list the third input
> and states its reason in the criterion: with the question unconditional, the list is a precomputed
> mechanical fact the question would otherwise re-derive from the diff by eye, which is slower and less
> reliable. **So reason 2 is retired by the criterion.** Reasons 1 and 3 stand, and so does the conclusion
> they actually support: **arm (a) stays a FINDING and is not downgraded.** An unnamed file is a
> set-membership fact about which files were touched, not a coarse estimate of how much, so the critique
> that retired the size arm never reached it — and the orchestrator remains the only party holding both
> *which files* and *what the plan said*. A round may still carry `decision=FINDING reason=unplanned-file`
> and a question answering *matches*: that is a well-formed pair, and the recipe presents both.

### AC24 — the sibling directory, and how the gate LOCATES the appender

**The sibling directory, chosen here because the criterion left it to design:**

```
LOOP_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
VERDICT_DIR="${HARNESS_VERDICT_DIR:-$(dirname -- "$LOOP_DIR")/fix-plan}"
# default: ~/.claude/harness/fix-plan/verdicts.jsonl
```

Three properties that decided it. It is **derived from `HARNESS_LOOP_DIR` rather than hardcoded**, so a
suite that redirects the loop dir into a sandbox gets the sibling inside that sandbox too — the suite
already does exactly that, so a hardcoded `$HOME` path would have tests writing to the developer's real
home. It is **a sibling and not a child**, which is what AC24 requires: the measured defect was that a
single row planted in the loop ledger's own directory moved an existing report's project, session and
verdict counts and fabricated a session block carrying a false sentence about the file's age. And it has
**its own override**, so the two surfaces can be moved independently.

**One file, `verdicts.jsonl`, not one per session** — re-derived, and the reason is a constraint rather
than a preference: the only producer of a session id in this repository is a hook payload
(`hooks/lib/loop-verdict.sh:78`, `.session_id`), and `grep -rn 'CLAUDE_SESSION_ID' .` returns nothing, so
a script the orchestrator invokes has no session id to key a filename with. The appender's `session_id`
argument keys only its once-per-session warning marker and is `tr`-sanitised there, so a stable literal
satisfies its contract. Each row instead carries branch and `round_base`, so it is attributable without
the filename.

**`mkdir -p "$VERDICT_DIR"` before the first append.** The appender does not create directories — it
appends and reports a failed open — so without this the first write always fails, reports once, and the
criterion is never satisfied on a fresh machine.

> **TWO MEASURED CONSEQUENCES OF REUSING THE APPENDER, recorded as ACCEPTED rather than fixed — and the
> reason they are acceptable is narrow, so it is stated rather than implied.** AC24 requires exactly one
> thing of a failed write: that the round's outcome is unchanged. Both consequences below leave that
> property intact, and neither is worth a second reporter — a second reporter is the drift
> `hooks/lib/ledger-write.sh`'s own header says it exists to avoid.
>
> 1. **The failure report names the wrong mechanism.** A failed append emits "LOOP DETECTION IS DISABLED
>    for this session", which is false of a fix-plan verdict write — loop detection is unaffected. Accepted:
>    the sentence is wrong about the cause and right about the remedy (a directory that cannot be written),
>    and the alternative is a second reporter.
> 2. **The once-per-session warning becomes once-per-MACHINE for this writer.** The marker is keyed on the
>    `session_id` argument, and we pass a stable literal, so the marker persists until the temp directory
>    clears and the **second failure onward is silent**. Accepted, and the literal is still the right choice:
>    it is what keeps this writer's marker from colliding with the hooks' session-keyed ones, which would be
>    the worse failure — suppressing a loop-detection warning that matters.
>
> **Neither is designed around here.** If the silence later proves to cost something, the fix is a distinct
> marker key for this writer, not a reporter of its own.

**How the gate locates the appender, and why the obvious way is wrong.** `check-fix-plan.sh:94` sets
`ROOT` from the **progress file's** repository (`git -C "$(dirname -- "$PROGRESS")" rev-parse
--show-toplevel`). In a consuming project that is the project, not the plugin, so **any `$ROOT`-relative
path to `hooks/lib/` does not exist there**. The resolution must be `$0`-relative, copying the pattern the
four hooks already use (`hooks/lib/loop-index.sh:75`, `loop-result.sh:31`, `loop-agent-mark.sh:35`):

```
HERE_LIB=$( { cd -- "$(dirname -- "$0")/../../../hooks/lib" && pwd; } 2>/dev/null ) || HERE_LIB=""
if [ -n "$HERE_LIB" ] && [ -r "${HERE_LIB}/ledger-write.sh" ]; then
  . "${HERE_LIB}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi
```

`../../../hooks/lib` is the path from `skills/task/scripts/` and it was resolved on disk, not computed.

> **⚠ THE HAZARD, and it is NOT the one it looks like — the difference decides whether the criterion
> survives a wrong path.** Copying only the `if` would make a wrong path a **silent no-op**: the guard
> declines to source, `harness_ledger_append` is then undefined, the `|| true` swallows the
> `command not found`, no line is ever written, and a suite that sources the library directly stays green
> because it never exercises the resolution. **The `else` branch is what prevents that, and it is the half
> most likely to be dropped as boilerplate.** The shipped comment at `hooks/lib/loop-index.sh:70-74` says
> so in as many words — "an absent helper must cost the WARNING and nothing else, so the fallback still
> appends" — so the fallback is load-bearing, not decoration: with it, a wrong path costs the
> once-per-session warning and the row is still written.
>
> **Therefore the test may NOT source the library directly.** It must invoke the gate **by path**, the way
> the orchestrator invokes it, and assert the line landed — and one leg must run the gate from a tree where
> `hooks/lib/ledger-write.sh` is absent and still require the row, which is the only leg that can tell the
> `if`-only copy from the correct one.

**Two writers, because the two facts live with two different parties.**

| Line | Written by | Carries |
|---|---|---|
| the pre-apply escalation (AC4) | the gate, in `do_plan` where A4 escalates | the decision and **the threshold value it fired under** (AC5's one firing site) |
| the micro-loop's own line | a **fourth verb** (signature below), invoked once by the orchestrator when the loop closes | the decision, **the loop's iteration count, its cost and the bounded question's answer** — the three figures AC24 says the retirement rule is read from |

> **THE SIGNATURE IS CORRECTED — an earlier form read `check-fix-plan.sh record <progress-file>`, which
> could receive NEITHER figure the criterion requires.** Both are the orchestrator's facts and the same
> paragraph refused to let the orchestrator write the line, so neither had a channel at all. What ships:
>
> ```
> check-fix-plan.sh record <progress-file> <iterations> <cost_tool_calls>
> ```
>
> **Both arguments are REQUIRED, not optional with a default.** A default would silently record a zero and
> the retirement rule would then be read off a column of zeros — a figure that is absent is recoverable, a
> figure that is wrong is not. The verb refuses a non-integer or a missing argument with a non-zero exit,
> in the same `die 2` shape the other verbs use for an input they cannot work from.
>
> **The cost unit is PINNED: the number of orchestrator tool calls the loop consumed.** Not wall-clock, not
> tokens, not a model-cost estimate. It is pinned because the spec's own cost model is that one — "the
> driver is therefore the NUMBER of orchestrator tool calls made at a large context, not the size of the
> diff under review" — and because it is the only unit the baseline this task is measured against is
> expressed in, so a figure in any other unit cannot be compared with the thing it exists to be compared
> with. **Counted from the orchestrator's own calls for that loop and no others**, which the round's attempt
> lines already make auditable. The field name carries the unit (`cost_tool_calls`), so a later reader
> cannot mistake which it is — a bare `cost` is how a second unit gets invented.
>
> **`iterations` is derivable from the attempt lines and is still passed explicitly**, rather than parsed
> out of them: a parser over prose is a second definition of the count, and the attempt lines are written by
> the orchestrator anyway, so it already holds the number it would be parsed for.

> **ROUND 10 — the ANSWER becomes a fourth argument, and the signature above is where it goes.** The two
> arguments below the signature shipped; this one is the delta. **The spec fixes the refusal and leaves the
> POSITION to design, so it is chosen here with its reason:**
>
> ```
> check-fix-plan.sh record <progress-file> <iterations> <cost_tool_calls> <answer>
> ```
>
> **APPENDED at position 5, not inserted.** Three reasons, and the first is the one that decides it:
>
> 1. **The arguments are POSITIONAL, so inserting re-binds the shipped ones silently.** They are read as
>    `ARG_ITERATIONS=${3:-}` and `ARG_COST=${4:-}` (`check-fix-plan.sh:188`-`:189`, re-derived). Put the answer at
>    position 3 and a call written as `record <file> 2 7` passes `2` as the answer and `7` as the iteration
>    count — **both wrong, and the error message names the wrong argument**, which is the shape that costs an
>    implementer an hour. Appending leaves every existing call and every existing leg correct.
> 2. **Validation order should stay equal to argument order**, because that is what makes each refusal point
>    at the argument it is about. The lane validates `ARG_ITERATIONS` then `ARG_COST`; the answer's arm goes
>    after them.
> 3. **The row builder appends too.** `verdict_row` takes `<verb> <round> <decision> <reason> <round_base>
>    <threshold|''> <iterations|''> <cost|''>` and builds the JSON with one `+ (if $x == "" then {} else …)`
>    clause per optional field, in that order. Adding a ninth parameter and a fourth clause continues an
>    established order; renumbering `$6`–`$8` inside a `jq` program string to make room in the middle is an
>    edit that goes wrong without failing.
>
> **The refusal, on the same lane and in the same shape as the other two arguments** — a `case` in
> `do_record` before any work, `die 2` for an input the verb cannot work from:
>
> ```
> case $ARG_ANSWER in
>   MATCH|DIVERGE) ;;
>   '')  die 2 'record needs <answer>, the bounded question'"'"'s answer, exactly MATCH or DIVERGE' ;;
>   *)   die 2 "record needs <answer> as exactly MATCH or DIVERGE; got [${ARG_ANSWER}]" ;;
> esac
> ```
>
> **The vocabulary arm comes FIRST and the patterns carry no `*`.** A `case` arm is an exact whole-word match
> here, which is what makes the substring hazard behind the `MISMATCH` rejection unreachable in this
> implementation — and the design says so rather than relying on it, because the next implementation of the
> same check may not be a `case`. Lower-case `match` is refused automatically for the same reason; the words
> are upper-case and the arm is not case-folded.
>
> **RECORDED, not merely validated — this is the half a `case` statement alone would miss.** The answer goes
> into the row as its own field, **`question_answer`**, named rather than left as `answer` because the row
> already carries a `decision` field and a bare `answer` beside it invites the two to be read as one thing.
> **A check whose input is discarded leaves no evidence that it ran:** a verb that validated the word and
> dropped it would satisfy the refusal clause and still leave the retirement data unable to say how often the
> loop answered `DIVERGE`, which is the frequency the rule is read from. The human-readable line gains the
> same field beside `iterations=` and `cost_tool_calls=`.

**Why a fourth verb rather than letting the orchestrator append the line itself:** the iteration count,
the cost and the bounded question's answer are the orchestrator's facts, but hand-rolling a JSON line in
the orchestrator's own Bash call puts a second writer of the format outside the one place that owns it, and
a second copy of a format is a second thing to drift. The verb keeps one writer, one line shape adopted from
`hooks/lib/loop-verdict.sh:124` and `:211` (`{ts: (now|todate), kind: "verdict", …}`), and one place where
`|| true` is correct. **`USAGE` at `check-fix-plan.sh:76` gains the verb**, or the script's own help text
becomes the fifth stale enumeration of this round.

> **`harness_ledger_append … || true` is correct here and is NOT result-masking.** The rule's carve-out
> covers a chain inside a checked-in `.sh`; `hooks/lib/loop-verdict.sh:127` already spells it exactly this
> way; and AC24 *requires* the semantics — a failed write must leave the round's outcome unchanged.
> Verified against the falsification question that was put to it: the appender never exits non-zero by
> contract, so this `|| true` cannot mask any gate's status, because no gate's status reaches it.

### The residual, recorded and deliberately NOT designed

The defect that sank the comparison — a predicate called on a `Target` carrying a `:N` line anchor answers
"not ignored" for an ignored path — **has no code to live in**: the gate has zero `check-ignore` calls, so
the predicate existed only in round 8's proposal and is withdrawn with it. **No predicate is designed here
in order to fix its bug.** What remains is the pre-existing declared-figure residual: the scout is
instructed in prose to count on the stated basis and nothing verifies that it did. That is unchanged by
this amendment, is not a new finding, and is not in scope.

### What the implementation handoff must now do — the complete list

> **ROUND 10, read the status column first: items 6 and 7 have ALREADY LANDED.** Re-derived against the
> shipped script rather than taken on report — `grep -n 'actual-overrun'` over `check-fix-plan.sh` returns
> nothing, `record)` is a verb arm at `:182` and `:728`, `do_record` is at `:702` with its two `case`
> validation arms, `VERDICT_DIR` is derived at `:111`, `HERE_LIB` resolves `$0`-relative at `:132` **with its
> `else` fallback**, `verdict_append` carries the `mkdir -p` at `:167`, and `USAGE` at `:96`-`:97` documents
> all four verbs across two lines. **So round 10's work is a DELTA against shipped code, not a greenfield
> build**, which is why items 15–18 cite live anchors and why the argument position below is chosen against
> a real signature instead of a proposed one.
>
> **AS-OF MARKER, and this block needs one more than the table below does, because it CLAIMS freshness.**
> "Re-derived against the shipped script" was true when written and is **not** true now: **all seven
> anchors above have moved.** Re-derived this pass — `record)` `:182`→**`:197`** and `:728`→**`:756`**,
> `do_record` `:702`→**`:719`**, `VERDICT_DIR` `:111`→**`:119`**, `HERE_LIB` `:132`→**`:140`**, the
> `mkdir -p` `:167`→**`:177`**, and `USAGE` `:96`-`:97`→**`:103`-`:105`**, which is **three** lines now
> rather than two. The one non-anchor claim still holds: `grep -c 'actual-overrun'` over the gate returns
> **0**. **The seven are deliberately left as written.** They are the record of where the work was found,
> and the conclusion they support is untouched by the drift — round 10's work was, and remains, a DELTA
> against shipped code.

> **DERIVED BY RUNNING THE SYNC-GROUP SWEEP, not by naming members one at a time — which is how three got
> missed.** `docs/propagation.md:32` is the Scouted-Fix group's anchor row; its trigger is "the four beats,
> the decision vocabulary, the two post-apply arms", **all three of which round 9 changes**, so the whole
> group fires. Its seven members, checked against this list one by one:
>
> | Member (per `docs/propagation.md:32`) | Covered by |
> |---|---|
> | `skills/task/SKILL.md` Step 11 | item 13 |
> | `skills/task/reference.md` § Step 11 | items 4, 5, 13 |
> | `skills/task/scripts/check-fix-plan.sh` | items 1, 6, 7 |
> | `docs/templates/progress-format.md` § `Fix Plan (Round N)` | items 5, 13 |
> | `agents/fix-scout.md` | **item 10 — was MISSING** |
> | `agents/fix-apply.md` | **items 11 and 12 — was MISSING** |
> | `docs/workflow.md` § Spec-Amendment group | **item 14 — was MISSING** |
>
> **The group also fires on the round-3 guard**, which is why items 4, 5 and 14 are instruction-text work in
> a handoff whose first item is a script change: `docs/propagation.md:33`'s back-reference row names the gate
> script's "verdict format, arm set or reason tokens" as a trigger in its own right.

> **AS-OF MARKER for the table below, and it covers every row: these anchors were measured when the row
> was written, not now.** A row carrying `LANDED` says so explicitly; an unmarked row is **not** thereby
> current. **Re-derive every anchor against the working tree before acting on it, one row at a time** —
> the drift is **not uniform**, so no single offset recovers it. Measured this pass, by way of proof:
> item 1's `case $target in` has moved from `:374` to **`:511`**, while item 4's `reference.md:206`-`:207`
> and the `USAGE` citation in items 7 and 15 resolve **exactly**. **The anchors are deliberately left as
> written.** They are the record of where the work was found, and renumbering them one at a time is what
> produced the mixed state this marker exists to describe.

| # | Work | Files |
|---|---|---|
| 1 | the routing guard: wrap `case $target in` at `:374` only (§ The routing arms' PATH half) | `check-fix-plan.sh` |
| 2 | `T1-ZK`, four legs, first leg shown RED pre-guard | `test-check-fix-plan.sh` |
| 3 | correct the stale assertion message at `test-check-fix-plan.sh:131` | `test-check-fix-plan.sh` |
| 4 | `reference.md:206` and `:207` gain the `fix` qualifier — **`major`, plugin-loaded, sync-group member** | `skills/task/reference.md` |
| 5 | **LANDED — and the phrase this row quotes NO LONGER EXISTS in the tree, re-derived this pass.** What the row recorded: five anchors across four files whose live justification was the disposition claim "no passing plan can name them" — `check-fix-plan.sh:61` and `:64`, `reference.md:234`, `docs/templates/progress-format.md:143`, the banner at `test-check-fix-plan.sh:541`. **That phrase now has a true zero outside this document:** `grep -rl` finds it here alone, the shorter `no passing plan` finds no wording variant either, and a control phrase run the same way returns its implementation files — so the zero is a real absence, not a pattern slip. **The correction is what removed it.** The instruction files carry the disposition-aware wording the fix required instead — `reference.md`'s "a row that PROPOSES an edit", `progress-format.md`'s "a row proposing no edit may name one but briefs nothing" — and the gate's routing guard is now wrapped in `if [ "$disp" = fix ]`. **So the quote stays as the RECORD of what was corrected; it is NOT a live anchor to go and read, and nothing in the tree should be expected to match it** | four files |
| 6 | **LANDED — verified in the shipped script, not assumed.** **arm (b) DELETED** — the `actual-overrun` comparison and its reason token go, and **`threshold_changed_lines=` is removed from `applied`'s and `baseline`'s headers**; `applied` keeps `actual_changed_lines=`, `ignored=`, `binary=` and the excluded/binary lines | `check-fix-plan.sh` |
| 7 | **LANDED — verified in the shipped script.** the `record` verb with its three-argument signature, `USAGE` updated (now at `:103`-`:105`, re-derived — three lines, all four verbs, the third naming the answer vocabulary), the sibling directory with `mkdir -p`, the `$0`-relative sourcing **with its `else` branch**, and the pre-apply escalation's own line | `check-fix-plan.sh` |
| 8 | legs — see the expansion below | `test-check-fix-plan.sh` |
| 9 | the `mkfix` fixture line — verified: `test-check-fix-plan.sh:36`-50 creates only `ai-docs/plans/t.spec.md` and `ai-docs/plans/done/t.design.md`, and an empty directory is not tracked, so **T1-ZF's non-routing control cannot be written today** | `test-check-fix-plan.sh` |
| 10 | **`agents/fix-scout.md:82`** — the agreement rationale the withdrawal removes: "a plan declaring twelve lines and a diff measuring twelve lines agree only if both sides count the same way". The basis itself STAYS (the declared total still exists and A4 still checks it); what goes is the claim that a *measurement* will be compared against it | `agents/fix-scout.md` |
| 11 | **`agents/fix-apply.md` — the arm brief is false.** `:39` heads a section "## The two arms your diff is measured by"; `:44` describes the deleted arm as live ("**Actual size.** The round's whole changed-line total is measured against a threshold the gate reports in its verdict"); `:54` repeats "inspected by two arms over the diff". **Shipping items 1–9 without this leaves the fix agent briefed to be measured by an arm that does not exist** | `agents/fix-apply.md` |
| 12 | **`agents/fix-apply.md` — the re-fix boundary, and this is a SECOND, independent reason that file is owed an edit.** Beat 3 re-spawns the fix agent with a named divergence, and its contract currently says the honest move when the plan turns out wrong is to stop and return, with "Plan, re-plan, or add a row" forbidden at `:54`. **A re-fix attempt sits exactly on that boundary and the contract must say which side it is on** — see the ruling below | `agents/fix-apply.md` |
| 13 | the micro-loop in instruction text: the five beats, the cap and where it is counted, **the attempt line's shape**, the escalation's fixed shape, the question's three inputs and two-word output, the retired `actual-overrun` token, and the `record` verb | `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/templates/progress-format.md` |
| 14 | **`docs/workflow.md:357`** — the *Fires in skill* table describes the routing as "a plan naming a `*.spec.md` / `*.design.md` target — or carrying an `amendment:` disposition". The guard narrows the path half to a **`fix`** row, so this sentence goes stale with item 4's. **Found by the sweep, and it is item 4's class rather than round 9's** | `docs/workflow.md` |
| 15 | **ROUND 10 — the answer argument.** `record` gains `<answer>` at **position 5** (`ARG_ANSWER=${5:-}` beside the existing `${3:-}` / `${4:-}`), a third `case` arm on the same validation lane refusing anything but `MATCH` / `DIVERGE` with `die 2`, the field **`question_answer`** added to `verdict_row`'s signature as its ninth parameter with a fourth `+ (if … then {} else …)` clause, and the same field on the human-readable line. **`USAGE` at `:103`-`:105` (re-derived) and the header comment at `:6` both carry the signature and move with it** — checked: the usage string is otherwise correct today, all three of its lines and all four verbs, the third naming the answer vocabulary | `check-fix-plan.sh` |
| 16 | **ROUND 10 — the vocabulary's leg.** Each of `MATCH` and `DIVERGE` accepted; anything else refused with a non-zero exit; and **the accepted word asserted IN the written row**, not merely that the call exited 0 — a verb that validated and discarded would pass a refusal-only leg | `test-check-fix-plan.sh` |
| 17 | **ROUND 10 — the two instruction files disagree about the output and neither names the words.** `skills/task/SKILL.md:199` reads "Output: **two words plus a reason**", which says the answer *is* two words; `skills/task/reference.md:242` reads "Output is **one of two words plus a reason**", which is the right cardinality. **Both must name `MATCH` and `DIVERGE` and agree on "exactly one of".** An unnamed two-member set is what let the first real run invent its own pair | `skills/task/SKILL.md`, `skills/task/reference.md` |
| 18 | **ROUND 10 — the false comment at `check-fix-plan.sh:685`.** It calls `actual_changed_lines=` "one of the two numbers the loop's retirement rule accumulates". **Two errors in one clause:** the criterion's two figures are the **iteration count** and the **cost** (now three, with the answer), and **this verb writes no row at all** — `record` does. The rest of that comment is correct and stays: the figure is a measurement nothing fires on, read by a human | `check-fix-plan.sh` |

> **RULING on item 12, because the brief cannot be written without it: a re-fix attempt is NOT re-planning,
> and the contract must say so in those words.** The boundary at `:54` forbids the fix agent from *choosing*
> what to fix — inventing a row, widening the diff, deciding the plan is wrong and acting on that. A re-fix
> attempt is the opposite: the orchestrator has already decided, the divergence is **named for** the agent,
> and the rows it may act on are unchanged. So the agent is being handed a narrower brief, not a licence to
> re-plan, and the stop-and-return instruction still binds **within** an attempt — if the named divergence
> cannot be fixed without touching a file no `fix` row names, the agent stops and returns, and that return
> is what consumes the attempt. **Without this sentence the two instructions contradict each other** at the
> exact moment beat 3 fires, and an agent resolving that contradiction by itself is the failure the bound on
> the question exists to prevent.

**Item 8 expanded, because two of its legs are REPLACEMENTS for shipped legs this list did not name.**

| Leg | Why |
|---|---|
| **`test-check-fix-plan.sh:211` must be re-pointed** — it asserts that mutating the threshold constant moves the **`applied`** verdict, which it no longer does | removing the field from `applied` breaks a green leg; the replacement asserts the mutation moves **`plan`**'s header and that `applied`'s is unaffected, which is the same property one firing site now implies |
| **`:691` must be re-pointed** — it asserts the **`baseline`** stub prints the threshold it would fire under | same cause; the stub no longer prints it, so the leg asserts its **absence** there |
| **the absence leg AC5 demands, which item 8 omitted** — the number appears in **no second place** | `grep -lw` per literal with its planted positive control, plus an assertion that `applied`'s and `baseline`'s headers do not carry it. **Three verbs' headers read, not one** |
| `:565`'s message reads "arm (b) charges the briefed file" | the **assertion** is about a field that stays; only the message names a deleted arm. Re-word the message, do not re-point the leg — and check the whole file for the same shape, since a message naming a gone mechanism is invisible to a green run |
| arm (b)'s removal asserted positively | a round whose actual total exceeds the old threshold now reports **no finding from that arm** |
| the `record` verb | its line carries the iteration count, the cost and the question's answer; it **refuses** a missing or non-integer figure **and an answer outside `MATCH` / `DIVERGE`** |
| the ledger | a simulated write failure leaves the round's outcome unchanged; the neighbouring report's counts unmoved; **and the gate invoked BY PATH from a tree with no `hooks/lib`, still writing the row** — the only leg that separates an `if`-only copy of the guard from a correct one |

**Six items are GONE from the round-8 list:** the like-for-like subtraction, `AGREEMENT_TOLERANCE_LINES`,
the two-quantity split with its mutation-and-converse anti-drift leg, the cross-side agreement leg, the
`check-ignore` 128 branch, and the A4 zero-declaration refusal with its three legs.

> **Item 5 still carries its trap, and the brief must name it.** Those five anchors sit in the round-3 plan
> under **one** finding whose subject is the **suffix** half, so a fix applied as briefed rewrites the
> suffix half and leaves the **disposition** claim — "because no passing plan can name them" — false. The
> brief must name the disposition half as a separate obligation at each of the five anchors.

### Ordering — the ruling is INVERTED, and the cost is owned rather than argued away

**The predicate inversion is moot — the subtraction is gone — but this one stands: a handoff that edits
`check-fix-plan.sh` collides with the un-applied round-3 plan, whose finding-2 rows carry anchors INTO
that same script.** Either A1 refuses the rewritten plan on stale anchors, or re-anchoring consumes one of
the permitted rewrites.

> **RULING, CORRECTED: the guard lands BEFORE the plan is rewritten and re-gated** — as a delegated
> amendment implementation outside the plan, the third precedent shape this document already carries.
>
> **An earlier form of this ruling said the opposite** — "the implementation runs AFTER `fix-apply`" — on
> the ground that "nothing in this amendment is a precondition of the round-3 plan passing the gate … the
> round-3 plan's own rows deliver items 1–5". **That ground was false, and it reinstated the circularity
> this document records twice as its own durable rule** — re-derived by grepping the sentence rather than
> recalled: it sits in § The routing arms' PATH half and in § Decomposition shape, and round 1's instance of
> the same shape is in the AC11 row as "a format cannot be planned in the format it widens" —
> *a remedy that unblocks the gate cannot travel through the gate it unblocks.* If a row of the
> plan delivers the guard, the plan must pass the gate for the guard to land, and the plan cannot pass
> without the guard. `fix-apply` never runs and the guard never lands. Recorded rather than quietly
> swapped, because the false leg is the one a later agent would have built on.

**Why the guard is a precondition — measured on the plan as it stands, not argued from the shape.** The
rows for findings 1, 5 and 7 today carry `amendment: design` dispositions with design-document Targets
(plus one `resolved:` row on finding 1). **Those amendments have LANDED, rounds 6 through 9.** So in the
rewrite nothing is owed on them, and their honest disposition is `resolved:` with the Target naming where
the fix actually landed — which for all three is this design document. **A `resolved:` row with a
design-document Target routes on the PATH half, which is precisely what the guard narrows, and precisely
the shape that returned `ROUTE-DESIGN` on rewrite 1.**

**I tested for a shape that neither routes nor lies, because the ruling turns on there being none. There
is none.** **SEVEN candidates — the whole disposition vocabulary against both Target choices, so the
table's exhaustiveness is checkable rather than asserted.** An earlier form said "four" over a five-row
table and omitted the two `amendment:` tokens, which is the enumeration-instead-of-search mistake this
round has already had to correct once. Each row is refused by something already settled:

| Candidate rewrite shape for findings 1, 5, 7 | Why it fails |
|---|---|
| `resolved:` with the design document as Target | **routes** on the path half — the shape under discussion |
| `resolved:` with the Target pointed at the finding's own row in the review table | does not route (`*.progress.md` is not a routing suffix), but **lies about where the fix landed** — § Three contract questions settles that a `resolved:` row carries *the anchor the finding itself cited*, and the spec's § Deferred row now records this workaround as "no longer needed" **because** the narrowing makes a `resolved:` row the passing row. Using it would contradict both settlements to dodge the arm they were written for |
| `object: <reason>` | **false** — nobody disputes these findings; they were fixed |
| omitted from the plan | **refused** by A6 under `finding-coverage` |
| `fix` with the design document as Target | routes (correctly), and would brief `fix-apply` to edit a design artefact |
| `amendment: design` — the disposition the rows carry **today** | **routes on the DISPOSITION half**, which the guard does not touch and must not. It is also **false now**: those amendments landed in rounds 6–9, so nothing is owed and the row would assert an outstanding amendment that is not outstanding |
| `amendment: spec` | routes on the disposition half likewise, and is false for a third reason — the findings' subject is this design document, not the spec |

**The two `amendment:` rows do not weaken the conclusion; they are why it holds.** They are the only
dispositions that reach an amendment recipe without a path, and both route — so there is no disposition in
the closed vocabulary of five, against either Target choice, that both avoids routing and states the truth.
The vocabulary being **closed** is what makes this exhaustive rather than a survey: a sixth token would
reopen the question, and adding one is a recorded out-of-scope defect.

**So the order is forced, and these are its costs rather than reasons for it:**

1. **It spends a rewrite on re-anchoring, and that is bookkeeping.** Finding 2's rows point at lines in
   `check-fix-plan.sh`, so any edit above them moves those lines and A1 refuses the rewritten plan. Editing
   first does not *risk* that refusal — it **produces** it, which is why the re-anchor is certain rather
   than probable.
2. **A rewrite spent on bookkeeping is the worst way to spend one.** Budget, re-derived below: one is
   already spent, so this leaves one in hand after the re-anchor rather than two.

**Neither cost is an argument for the other order, because the other order is not more expensive — it is
impossible.** A cost that is certain and bounded loses to a dependency that cannot be satisfied at all.

**The rewrite budget, re-derived from the artefact rather than asserted** — and an earlier form of this
section said "two rewrites of three are already spent, so one remains", which was wrong:

| Evidence | Reading |
|---|---|
| `skills/task/reference.md:216` — "hand the verdict back to the same `fix-scout` for a rewrite — **max 3 rounds**" | the cap is **3** |
| the progress file's § Round-3 plan state — "`## Fix Plan (Round 3)` holds **rewrite 1**" | **one** is spent |
| the same file's work queue — "rewrite the round-3 plan again (this will be **rewrite 2** of the 3 the recipe allows)" | the next consumes the second, leaving **one** |

So: **one spent, two available, and the re-anchor consumes one of those two.** The figure rests on the
progress file's own account because **the contract does not define rewrite accounting at all** — that is
one of the recorded out-of-scope defects, named here and left, and it is the reason this budget is read off
an artefact instead of a rule.

**What rides with the guard — items 2–5 land in the SAME handoff as item 1.** Items 2 and 3 are the
guard's own test surface, and a guard shipped without the leg that proves it narrows anything is a change
nobody can review. Items 4 and 5 are the sites the guard makes false: `reference.md:206`-`:207`'s arm
definition and the four "no passing plan can name them" premises. **Correcting them before the guard would
replace one false claim with another, and correcting them after leaves plugin-loaded instruction text
contradicting the shipped code for the length of a round** — and item 4 is `major` and a sync-group member,
so the Propagation Rule requires it in the same PR as the code regardless. The same handoff is the only
placement where neither of those holds.

**Items 6–10 have no claim on the plan, so their placement is a cost question rather than a correctness
one. Chosen: they ride the same handoff, after items 1–5, with item 10 last.** One handoff over two saves a
full re-read of a 229KB design document and a cold agent's re-derivation of the same anchors; the internal
order already carries the only dependency that matters, which is that the instruction text is written after
the arm set is final. Splitting would buy a smaller review surface and pay a context reset for it, and the
per-round displacement figure this task owes makes that trade visible rather than free.

**Consequence to carry, which the inversion makes LARGER rather than smaller:** the lines this handoff
lands — now including the guard and its legs, before any plan is applied — are charged to the round's
actual total and are declared by no row, so the mechanical arm will name them. That is the
amendment-then-resume shape the in-round exclusion list and the `excluded-in-round` read-obligation already
exist for; it is **named and left**, not designed around.

### Decomposition — and the cap argument is WITHDRAWN as false

**The decomposition stays at SEVEN and this work is not a subtask**, which is the same conclusion round 8
reached. **But the argument it reached it by was false, and this document already recorded the measurement
that refutes it.** Round 8 said a new subtask "would need a fourth group, which that cap forbids". It
would not: § Handoff plan's own callout records the arithmetic — with non-terminal groups at exactly 3 and
a terminal group of 1..3, three groups hold up to **nine** subtasks, `M = 8` regroups cleanly to 3/3/2,
and the cap first breaches at `M = 10`. So "an eighth subtask cannot be absorbed by regrouping" was
literally false there and the cap claim is literally false here, for the same reason. **Deleted rather than
softened, because it was relayed to the user as verified fact and had to be corrected.**

**The sound ground, which needs no cap at all: all three groups have already RUN.** There is no open group
to carry new work, and the group is the unit of fan-out (`skills/context-reset/SKILL.md:30`). An eighth
subtask would therefore be a label with no executor — not because a fourth group is forbidden, but because
creating one would mean re-opening a completed decomposition to run a single amendment, when the third
precedent shape exists for exactly this case.

**So: the third precedent shape** — an approved amendment implemented by a delegated handoff, outside the
plan — and it joins the routing guard rather than forming a second round, for the already-settled reason
that one pass over a combined set costs one round instead of two.

**And it runs BEFORE the round-3 plan is rewritten and re-gated, not after `fix-apply`.** That is § Ordering's
corrected ruling and it is a dependency, not a sequencing preference: the guard is a precondition of the
plan passing the gate, so a plan row cannot deliver it. The placement is pinned in both sections
deliberately — this is the one fact about this handoff that, stated two ways, would send an implementer
down an impossible path.

**RULING on the handoff count: ONE handoff now suffices, where round 8 needed two.** The split existed
because the subtraction had to be written against a predicate the guard settled; with the subtraction gone,
no item in 6–10 depends on the outcome of 1–5, and the whole list is ten items across four files rather
than eleven across six with an ordering constraint threaded through them. **The internal order still
holds and is a dependency:** items 1–5 before 6–7 (the premise sites are false *because of* the guard, so
correcting them first swaps one false claim for another), and item 10 **last**, because the instruction
text enumerates the arms, the tokens and the beats, and the arm set must be final before the prose
describing it is written — the same dependency that ordered 1a before subtask 4.

---

## Design Amendment — round 3, which the gate ROUTED (user-approved)

The scout planned round 3; the gate returned `decision=ROUTE-SPEC` with A3 also failing, and three of
its sixteen rows name this document. **The mechanism refused to let its own design be edited without
an amendment**, which is the routing arm working on the artefact that specified it.

### The stale pending-amendment claim — in TWO places, and the worse one is not the row I was pointed at

I was pointed at the AC18 verification row. The scout found the identical claim in § GAP 1's
blockquote, and judged **that** the more harmful of the two because it is the paragraph an implementer
reads *before* ever reaching the AC table. It was right: correcting only the row would have preserved
the error exactly where it does most damage.

**Re-derived rather than taken on report — and NEITHER a hit count nor a spec line number is recorded
here, because both rotted inside this single round.** What the criteria carry is recorded against the
**AC id**, the one identifier in the spec that does not move when a sentence is inserted above it:

| Carried by | The clause, verbatim from the criterion |
|---|---|
| AC2 | "names a `*.spec.md` path under `ai-docs/plans/` (active or `done/`) routes to the Spec Amendment recipe" |
| AC3 | "names a `*.design.md` path under `ai-docs/plans/` routes to the Design Amendment recipe" |
| AC7 | "arm (a): **except for a `*.spec.md` or `*.design.md` under `ai-docs/plans/` (active or `done/`)**" |
| ~~AC18~~ | **NO LONGER CARRIES IT — round 9.** This row quoted AC18 as reading "The actual total additionally EXCLUDES the lines of a `*.spec.md` or `*.design.md` under `ai-docs/plans/` (active or `done/`)". Re-derived: `grep -cF` of that sentence against the live spec returns **0** — the post-apply size arm is withdrawn in every form, so the criterion has no actual total to exclude anything from. **The exclusion itself still ships and is still a criterion: it is AC7's, on arm (a), and the row above quotes it (`grep -cF` → 1).** Corrected rather than deleted, because a reader who remembers AC18 carrying it needs to find out where it went |

The remaining hits are prose restatements, not criteria, and they are likewise located by section rather
than by line: one in § Scope's enumeration of the arms, one in § Technical constraints 12c's statement of
the measurable-total gap, one in AC11's round-3 record, and the progress-file glob in § Open questions.
To re-derive: `grep -nF 'ai-docs/plans/' <spec>` and read which AC ids and which sections the hits land
in. **Do not carry the count forward.**

> **Why the count is WITHHELD rather than updated, which is the finding behind this correction.** This
> document claimed **6**; the orchestrator measured **7**; the measurement taken for this amendment reads
> **8**, and the eighth hit is **AC11's own round-3 record** — added by the very Spec Amendment that was
> meant to settle the question. Three values inside one round, each of them true when it was written.
> So the remedy applied to the earlier stale-claim finding reproduced that finding's own defect class: a
> re-derivation presented as current, which then went stale again. A count over a document that is still
> under amendment has a shelf life shorter than the round that takes it. The durable form is worth more
> than any of the three numbers: **record the identifier that survives an edit above it, plus the command
> that re-derives the rest.** The six-line block of spec line numbers that stood here is deleted for the
> same reason, not tidied — five of its six anchors were dead within one round, while the sentences they
> pointed at were all still there to be found by their text.

So the sixth Spec Amendment **has landed**, AC7 now carries the exclusion clause, and both of my
sentences — "the spec carries no `ai-docs/plans/` exclusion clause at all" and "until that amendment
lands, this section is a design of a remedy the criteria do not yet mandate" — are false. Both are
corrected in place.

### The exclusion is keyed on a DIRECTORY while its justification keys on SUFFIXES

**This is the defect, stated as the mismatch rather than as a width.** The routing arms that justify
the exclusion fire on `*.spec.md` and `*.design.md`; the exclusion is keyed on the prefix
`ai-docs/plans/`. An exclusion must key on the same thing its justification keys on, or it covers paths
no argument has been made for. Four such paths exist in the tree today, re-derived:

```
$ git ls-files 'ai-docs/plans/*' | grep -v "\.spec\.md$\|\.design\.md$"
ai-docs/plans/.keep
ai-docs/plans/deferred/.keep
ai-docs/plans/done/.keep
ai-docs/plans/done/2026-09-30-hook-path-resolution.design-evidence.md
```

Demonstrated end to end by `self-review`, cited as supplied: a plan row targeting a non-routing path
under that prefix and declaring 40 returns `PASS … declared 40 of 150`, and `applied` then returns
`actual_changed_lines=0 ignored=1`. **Forty lines of real change, charged as zero, with no routing
arm having fired** — because the justification never applied to that path.

**The remedy: narrow the prefix to the two suffixes.** `IGNORE_PREFIX_PLANS='ai-docs/plans/'`
(`check-fix-plan.sh:71`) becomes a match on `ai-docs/plans/**/*.spec.md` and
`ai-docs/plans/**/*.design.md`. One line, landing in this same round. The two criteria are being
amended in parallel, so this is not blocked on them.

**SIX shipped sentences become true only once that line lands — not the four I was told.** Enumerated
and re-derived; two are plugin-loaded **and** Scouted-Fix group members, so the sweep obligation
reaches them and they are not optional:

| # | Surface | What it asserts |
|---|---|---|
| 1 | `skills/task/scripts/check-fix-plan.sh:71` + the comment above it | the constant itself |
| 2 | `docs/templates/progress-format.md:143` | "that list holds … and `ai-docs/plans/`" |
| 3 | `skills/task/reference.md:234` | "Three path classes are excluded from both arms" |
| 4 | `skills/task/scripts/test-check-fix-plan.sh:538` | the T1-ZF leg banner |
| 5 | **`agents/fix-apply.md:52`** | "A path under `ai-docs/plans/` is the one case the arm does not report as a finding" |
| 6 | **`skills/task/SKILL.md:196`** | the applied-diff gating paragraph |

**T1-ZF and T1-ZG follow the narrowing**, and T1-ZF gains the control the mismatch demands: a
**non-routing** path under `ai-docs/plans/` — a `.keep`, or the real
`done/2026-09-30-hook-path-resolution.design-evidence.md` — must be **charged and named as unplanned**,
not excluded. Without that control the narrow and wide prefixes are observationally identical and the
suite cannot tell them apart.

### The routing arms' PATH half keys on every row while its justification keys on PERMISSION (user-approved)

**This is the same defect as the section immediately above, one arm over.** There, an exclusion keyed on
a directory while its justification keyed on two suffixes. Here, the routing arms' path detection keys on
*any* row's `Target` while its justification keys on what a `fix` row AUTHORISES — so again the arm covers
inputs no argument has been made for. Recording them as one class is the point: *an arm must key on the
same thing its justification keys on.*

**THE DECISION, as approved.** The **path-detecting** half of A2 and A3 fires only on a row whose
disposition is `fix`. The **disposition** half — a row dispositioned `amendment: spec` or
`amendment: design` — keeps routing amendments, untouched. **The path arm is NARROWED, never dropped:** a
`fix` row whose Target is a spec or design artefact is an attempt to have the fix agent edit one, and that
must keep routing. Both verdicts, both reason tokens and the arm-line format stay exactly as they are.

**Why it is required rather than cosmetic.** The fifth disposition token's own documented primary case is
*a finding closed before the round by an approved amendment* (§ (b) The fifth disposition token). Such a
row's Target is the artefact the finding cited, and the settlement in § Three contract questions fixes it
there deliberately. The path arm therefore re-routes the round on the honest recording of a closed
finding — and since an amendment, by definition, touches a spec or a design artefact, the token is
**unusable for its own typical case**. A round cannot leave the routing loop by telling the truth, and
`do_baseline`'s refusal of a second stub for the same round means it cannot be cleared that way either.

**It is not hypothetical, and the spec already anticipated it conditionally.** § Deferred carries the row
"A passing row for a finding whose SUBJECT is a spec or design artefact", deferred *"only to the extent
the new `resolved:` token (§ Technical constraints 12b) does not already cover it — which is the first
thing to check, since a finding closed by an amendment before the round is exactly that token's case"*,
and flagged **"Yes, conditionally — file only if a case survives the `resolved:` token"**. All three
fragments verified with `grep -cF` against the live spec rather than retyped. A case does survive, and the
surviving case has now been measured rather than argued: a round-3 plan carrying exactly this shape
returned `decision=ROUTE-DESIGN`. The condition the spec set is met, which is what makes this a
settlement of a recorded conditional rather than a new idea.

**Three consistency arguments, all already settled in this document.** Arm (a)'s allowed set keys on
`fix` rows only, for this same reason — `check-fix-plan.sh:510`, `awk … '$3 == "fix"'`. § Three contract
questions states that a non-`fix` row's `Target` "feeds no permission — it is documentary", so routing on
it keys an arm on a cell this design has declared to carry no permission. And the tokens that mean *route
me* are already in the vocabulary, so narrowing the path half removes no expressiveness: a scout that
wants an amendment says so with the disposition. The row also stays auditable either way, because A1
resolves every row's `Target` before the routing arms are reached — `check-fix-plan.sh:355`,
`fault=$(anchor_fault "$anchor")`, inside the row loop with no filter on the disposition.

**The change, with its anchors re-derived by grepping the executable statement.**

| Site | Executable statement today | Change |
|---|---|---|
| `check-fix-plan.sh:374` | `case $target in` | wrapped in `if [ "$disp" = fix ]; then … fi` |
| `:375` | `ai-docs/plans/*.spec.md\|ai-docs/plans/*.spec.md:*)` | unchanged inside the guard |
| `:376` | `routespec="${routespec}${routespec:+, }finding ${num} targets ${target}"` | unchanged |
| `:377` | `ai-docs/plans/*.design.md\|ai-docs/plans/*.design.md:*)` | unchanged inside the guard |
| `:378` | `routedesign="${routedesign}${routedesign:+, }finding ${num} targets ${target}"` | unchanged |
| `:380`–`:382` | `case $disp in` → the two `amendment:` arms | **NOT guarded — must stay outside** |
| `:427` | `if [ -n "$routespec" ]; then arm A2 spec-amendment FAIL "$routespec"; decide ROUTE-SPEC spec-amendment` | unchanged |
| `:430` | `if [ -n "$routedesign" ]; then arm A3 design-amendment FAIL "$routedesign"; decide ROUTE-DESIGN design-amendment` | unchanged |

> **The implementation hazard, stated because getting it backwards inverts the whole decision.** The
> guard wraps the `case $target in` block at `:374` **only**. Wrapping the `case $disp in` block at `:380`
> as well would stop `amendment:` rows routing — the exact opposite of the approved change, and a shape
> that reads correct at a glance because both `case` blocks sit adjacent in the same loop body. The two
> halves are independent by design: path-and-`fix` detects a misdirected fix agent, disposition detects a
> requested amendment.
>
> **One shell fact worth pinning, since the patterns look like paths:** inside `case`, `*` matches `/`
> — there is no pathname-expansion semantics — so `ai-docs/plans/*.design.md` already covers
> `ai-docs/plans/done/<x>.design.md`, which is what AC2's "(active or `done/`)" requires. Narrowing the
> row set does not disturb that.

**The Spec Amendment this subsection owed has LANDED, and the routing fix is now SANCTIONED.** The
record of what was owed stays, because it is why the amendment exists: AC2 and AC3 read "A fix plan …
that **names** a `*.spec.md` path under `ai-docs/plans/` … routes", with no row qualifier, so the
narrowed code would have contradicted a live criterion the moment it landed — the exact failure this
task's own amendment rule exists to prevent. **What they say now**, re-derived from the criteria and
recorded against **AC ids** rather than spec line numbers, which is this document's own durable rule:

- **AC2** routes a plan whose anchors all resolve, and never lets it reach the fix agent, **when either
  half fires** — a row *dispositioned `fix`* naming a `*.spec.md` path under `ai-docs/plans/` (active or
  `done/`), **or** a row *dispositioned `amendment: spec`* whatever its target. The path half is keyed on
  a row that **proposes an edit** and is explicitly "narrowed rather than dropped"; a row proposing **no**
  edit "does not route on its target alone". AC2 carries this design's own reasoning for it, including
  that the fifth token's typical case would otherwise be unrecordable.
- **AC3** is the same two halves one arm over, incorporating AC2's narrowing, its anchor qualifier, its
  real-artefact fixture requirement and its **three** mandated test legs by reference.
- **AC2 also forbids the suite shape that would hide this:** "'One test per arm' does not satisfy this
  criterion, because a suite written against the unqualified rule stays green under the narrowed one."
  Three legs per arm, each against a plan differing from a passing one in **that half alone**.

Re-derive with `grep -n '^| AC2 |' <spec>` and `grep -n '^| AC3 |' <spec>` and read the criteria; no line
number and no count is recorded here, because both have already gone stale twice on this task. **Two
further criteria the unqualified wording contradicted inside the same spec**, which is the strongest
statement of why this was a defect rather than a preference: § Technical constraints 12b and **AC22** both
assert of the fifth disposition token that **"it routes nothing"** — a claim the unqualified routing arms
falsified for that token's own primary case. And § Deferred's "A passing row for a finding whose SUBJECT
is a spec or design artefact" row is now marked **SETTLED rather than conditional**: a passing row exists
under the narrowing, so nothing is filed and the undocumented workaround the first real run invented is
no longer needed.

**Test leg T1-ZK** — the next free name, re-derived from the suite with `grep -o 'T1-Z[A-Z]*' … | sort -u`
(highest present: `T1-ZJ`). Four legs, separate by construction, each differing from the passing shape in
one half alone:

| Direction | Shape | Required verdict |
|---|---|---|
| the case the token exists for | a `resolved: <reason>` row whose `Target` is a REAL `ai-docs/plans/<x>.design.md:<n>`, every anchor resolving, 0 declared | `PASS`, routing nothing — **shown RED against the pre-fix gate**, where it prints `decision=ROUTE-DESIGN` |
| the half that must NOT be lost | the same row with its disposition changed to `fix` | `decision=ROUTE-DESIGN reason=design-amendment` |
| the disposition half, untouched | an `amendment: spec` row whose `Target` is a non-plans file | `decision=ROUTE-SPEC reason=spec-amendment` |
| the spec side of both | the first two directions against a real `*.spec.md` target | `PASS`, then `ROUTE-SPEC` |

> **The first leg must be shown red before its assertion is written**, and the red run is the evidence
> rather than the green one: a leg authored after the guard lands cannot distinguish "the narrowing works"
> from "the fixture never routed anyway". The fixture requirement AC2 already imposes still binds — the
> target is a **real** artefact under `ai-docs/plans/`, because a fabricated path fails A1 first and the
> leg would then pass on the refusal while measuring nothing about routing. The third leg asserts the
> disposition half independently of the path half, so a change to one cannot be read off the other.
>
> **CORRECTION — the claim this blockquote made for that leg was false, and the Test Design row was right
> all along.** It read: "the control that keeps the two halves distinguishable: without it, a guard
> mistakenly wrapped around `:380` as well leaves the suite green." It does not. Under that mistake
> `amendment:` rows stop routing, so T1-B's second leg and T1-C's second leg both go **red** — the suite
> catches it without T1-ZK's third leg at all. What the third leg actually buys is an assertion of the
> disposition half inside the same leg family as the narrowing, so a later edit cannot retire the two
> existing legs and leave the half unpinned. **This is the exact defect class this document records about
> itself:** the narrative copy carried a false justification while the table copy
> (`T1-ZK`'s row in § Test Design) stated it correctly, and the narrative is the one read first. Third
> instance on this task, and the first one where the table was the correct copy.

**What the landed criteria oblige that T1-ZK alone does not deliver — one item, and it is in the EXISTING
suite rather than in the new leg.** AC2 and AC3 mandate three legs per arm; legs 1 and 2 of both arms are
already shipped and still correct under the narrowing — T1-B's `fix`-row spec-path leg and its
`amendment: spec` leg, T1-C's `fix`-row design-path leg (which also covers `done/`) and its
`amendment: design` leg. T1-ZK supplies the missing third leg on both arms, so the mandate is met
jointly. **But one shipped assertion MESSAGE is now false, and it is false in precisely the direction
AC2's closing sentence warns about:** `skills/task/scripts/test-check-fix-plan.sh:131` reads
`check "an active spec path routes, whatever the disposition says" "$RC" "1"`. Under the narrowing the
disposition is exactly what decides, and the leg stays **green** only because its fixture happens to use
a `fix` row — a suite written against the unqualified rule passing under the narrowed one, which is the
shape AC2 forbids relying on. The implementation handoff therefore owes a third edit beside the guard and
T1-ZK: that message must name the `fix` disposition as load-bearing. T1-C's two messages were read and
need no change ("a design path under done/ routes", "the disposition alone routes, on a non-plans
target") — neither claims disposition-independence. No extra leg is mandated for `object:`, because the
guard tests `= fix` and so covers every no-edit token by construction, and AC2 mandates one no-edit leg
rather than one per token.

**How the change reaches the code — path (i), a delegated amendment implementation, and the other two are
ruled out by evidence rather than by preference.** The plan format expresses **findings**; A6 requires
every open finding to have a row and refuses a row matching no open finding under `plan-row-unmatched`.
The routing fix is the remedy for none of round 3's findings, so no row is available to it.

| Path | Verdict |
|---|---|
| (ii) attach it to an existing finding number | **Refused.** No round-3 finding subsumes it; attaching it would be a formality that makes A6 pass while the row's `#` points at a finding whose subject is something else — the Defect B shape (a present row whose image is inadequate) deliberately introduced rather than found |
| (iii) defer | **Ruled out by the user's decision.** |
| (i) a delegated amendment implementation, applied BEFORE the plan's next rewrite | **Taken.** |

**And the reason (i) is not merely the remainder — a fourth consideration that settles it: the fix is a
PRECONDITION of the plan it would otherwise be a row in.** Findings 1, 5 and 7 are closed by *this*
amendment, so their rows are `resolved:` rows whose `Target` is this design document; that is precisely
the shape the path arm re-routes on, and it is the shape that returned `ROUTE-DESIGN`. So the plan cannot
pass the gate until the fix is in the code, and a row inside that plan could never deliver it. That is
the same bootstrap as round 1's "a format cannot be planned in the format it widens", recorded in AC11 —
second instance, different arm, and the general form is worth keeping: **a remedy that unblocks the gate
cannot travel through the gate it unblocks.**

So, concretely: the orchestrator spawns an implementation handoff for the guard plus T1-ZK — it never
executes subtask code in its own context — and it runs **before** the round-3 plan's next rewrite. The
precondition it used to carry, the Spec Amendment to AC2/AC3, is **discharged**: that amendment has
landed, so the handoff's remaining scope is the guard, T1-ZK, and the one stale assertion message above. No new decomposition subtask: `M` is at seven and
`${CLAUDE_PLUGIN_ROOT}/agents/design.md:106` binds at eight. § Decomposition shape's precedent table
gains this as its third shape.

**Consequence for this round's own measurement, stated because AC11 turns on it.** The round still counts
as outcome **1a — end to end — if and only if** the rewritten plan passes the gate and `fix-apply` applies
it; this is a condition, not a claim about what will happen. Applying the routing fix outside the plan
does **not** disqualify the round: AC11's outcome 1a names scout → gate → fix agent, and an amendment's
*implementation* has never been inside the plan — `SKILL.md` mandates resuming Step 11 after an amendment,
which presupposes exactly that. Two honest consequences travel with the figure, and both must be stated
rather than discovered:

- The guard and T1-ZK land after `round_base`, so their lines are charged to the round's actual total,
  while the plan declares none of them. The declared total and the measured total therefore differ by
  undeclared amendment work — the § Technical constraints 12c asymmetry, which the criterion already
  obliges the orchestrator to state beside any figure.
- **WITHDRAWN, and the premise under it was already false when written.** This bullet predicted that
  `skills/task/scripts/test-check-fix-plan.sh` would appear on arm (a)'s unplanned list "because the
  format carries one `Target` per row", citing the multi-file-remedy limitation as already-recorded. The
  format no longer carries one Target per row: the widening (§ (a) At least one row per finding) removed
  that, AC7's allowed set is "the union over ALL the plan's rows", and
  `docs/templates/progress-format.md` states a finding "may occupy more than one row — one per file its
  remedy touches". **Measured on the round-3 plan on disk: finding 2 already has SIX rows naming both
  files.** So the limitation I cited was recorded *before* the widening landed and no longer binds, and
  this bullet's consequence does not follow. What survives of it is the standing instruction, which was
  never contingent on the limitation: a `Target` must name the line being fixed, never be re-pointed at
  another file to silence an arm.

### Two new mechanism defects — RECORDED, not fixed

The user approved fixing round 3's findings, not these. Both are the **second** real run saying
something the first could not, which is itself the strongest datum here: the first run found six
format defects, and a second run on a different shape found two arm defects neither the design nor any
review predicted.

**Defect A — the disposition vocabulary is two cases short.** Neither case is expressible in the five
tokens:

| Case | Why each existing token is false |
|---|---|
| an **acknowledged, unrepairable** finding | the skipped round cannot be mended by any edit, so `fix` is false; nobody disputes it, so `object:` is false; the tree does not satisfy it, so `resolved:` is false |
| a **live defect deferred to a follow-up** | closing it needs a detector, and all this round can produce is a recorded gap |

The scout wrote **no row** for the unrepairable half and reported it in prose instead — *which is
exactly what its contract tells it to do*, and is the same shape as the first run's `object:`-with-a-
disclaiming-reason. **The scout's own suggestion, recorded verbatim as a candidate:** a sixth token
**`acknowledged: <reason>`**, routing nothing, declaring 0, asserting neither dispute nor satisfaction.

**Defect B — and this is the sharper one: A6 counts FINDINGS, not the halves a finding has.** Measured:
A6 passed with `7 open findings, 16 dispositions` on a plan that leaves a `major` finding's **primary
subject with no row at all**. So a scout that obeys the contract's "say so rather than stretch a token"
instruction produces a plan that **looks complete to the gate**, and the hand-back becomes the only
carrier of the gap — *the one channel this mechanism exists to replace*. That is a defect in the arm,
not in the scout.

> **Defect B falsifies something I wrote, and I am flagging it rather than quietly fixing it.** § A6's
> converse argues that enumerating both directions of the findings-to-plan mapping closes the arm, and
> the standing rule I added to § Test Design says to ask "what the *many* side can contain that the
> *one* side never mentioned". Both are about **membership** — which findings and which rows appear.
> Defect B is about **sufficiency**: a finding can be present, and present several times, while the
> part of it that matters has no row. Membership in both directions does not imply coverage of a
> finding's substance, and no count of rows per finding can see it. The durable form, one altitude up
> from what I wrote: **a coverage arm over a mapping checks that the mapping is total; it cannot check
> that each image is adequate.** Fixing this needs a notion of a finding's parts that the format does
> not have — which is why it is a candidate for a follow-up and not a line change.

### Three contract questions the design should settle, and here are the settlements

Two are design's to decide and I decide them; the third is in flight.

**1. The `Target` cell for a non-`fix` row — settled: it is the anchor the FINDING cited.** The scout
found no convention for a `resolved:` row and used the artefact line for `amendment:` rows. Since the
Design Amendment above, arm (a)'s allowed set is `fix` rows only, so a non-`fix` row's `Target` feeds
no permission — it is documentary, and A1 still resolves it. So: **`object:` and `resolved:` rows carry
the anchor the finding itself cited**, which keeps the row auditable and the gate's per-row checks
satisfiable; **`amendment:` rows carry the artefact line**, deliberately, because that is what makes
the routing arms fire and routing is the correct outcome for them. Cheap, needs no code change, and
removes the guess.

**2. Arm A per finding or per row — settled: per FINDING, and every row of that finding carries the
same cell.** The Arm A question is about a finding's *subject*, and AC10's closing gate is per finding,
so the per-finding reading is the one the obligation rests on. The gate requires a non-empty cell per
*row*, so the rows of one finding repeat it. Redundant, and the redundancy is the point: each row stays
self-describing for the gate while the obligation stays unambiguous for a finding spanning eight rows.
A reader must not infer eight separate Arm A obligations from eight rows.

**3. The contract's own Arm A example is still the 21-character placeholder** — round 3's finding 6, in
flight. **One interaction to carry into that fix:** GAP 2's floor refuses a fragment under **24**
whitespace-normalised characters, so a 21-character placeholder would be refused by the strengthened
A1 once GAP 2 lands. The corrected example therefore needs to satisfy three things at once — parse
under the extractor (T1-ZE), clear the 24-character floor, and be a plausible quote. Note also that
T1-ZE asserts only that the anchor **extracts**; it does not run the quote-verification, and extending
it to do so would fail on any placeholder example by construction.

### One positive, which belongs in the contract rather than only in a hand-back

The quote instruction was **usable exactly as written**, and the technique that made all five quotes
verify first time is worth promoting into `agents/fix-scout.md`: **extract each fragment with a
fixed-string search and paste the command's output rather than retyping it.** Em dashes and bold
markers are what silently break a retyped quote, and both appear in nearly every artefact sentence in
this repository. That is the same `-F` discipline that has now caught five probe failures on this task,
applied to authorship rather than to searching — and under GAP 2's exact-substring rule a retyped
em dash is no longer a cosmetic slip but a refusal.

---

## Design Amendment — two gaps my own false sentences were covering (user-approved)

Both were found by `self-review` and both are real mechanism defects, not prose errors. In each case a
sentence in this document asserted the gap away, and in each case that sentence was the stated reason a
test leg was not written. The user chose to fix the mechanisms.

### GAP 1 — "`applied` is never reached for that round" is false, and permanently so

**The claim, and where it sits.** Re-derived: `design.md:996` and the comment at
`skills/task/scripts/test-check-fix-plan.sh:528-530`. Both say a routing plan means `applied` is never
reached, and `:528-530` names that as the reason T1-ZA's `amendment:` leg was asserted on the
construction rather than end to end.

**Why it is false.** `skills/task/SKILL.md:173-174` mandates "then **resume** Step 11" after either
amendment. On resume, `do_baseline` refuses a second stub for a round that already has one
(`check-fix-plan.sh:217`), so the round keeps a `round_base` taken **before** the amendment wrote to the
spec or design file — while A2/A3 forbid any *passing* plan from naming those paths. So on every
amendment-then-resume round, both post-apply arms fire **by construction**: arm (a) names the plan
artefacts as files the plan did not name, and arm (b) charges the amendment's lines to the fix round.
This is not a bootstrap condition that clears once the task settles; it recurs on every such round
forever.

Measured by `self-review` on this task's own round and cited as supplied: arm (a) named both plan
documents among eight files, and arm (b) reported **743 of 150**, of which **492** was those two files.

**The remedy: extend the in-round ignore list to `ai-docs/plans/`, and REPORT what it excludes.** The
list at `check-fix-plan.sh:58-59` already exists for exactly this class — tracked paths the orchestrator
may legitimately touch mid-round — and the amendment's writes to a spec or design artefact are the
clearest instance of it. One prefix entry, no new verb, no interaction with `:217`.

**Why this beats the two alternatives, and the arithmetic decides it rather than taste:**

| Option | Verdict |
|---|---|
| **Static prefix entry on `ai-docs/plans/`** (chosen) | Removes the amendment's 492 lines. Arm (b) then reports **251 of 150** — still a finding, and a **true** one, because 251 is the round's real fix work. Covers active and `done/`, which is the same class A2/A3 key on. |
| **Re-baseline on resume** | Reaches the same 251 only in the lucky case. It moves the baseline past the amendment *and past any fix work already done earlier in the round*, so it would erase genuine edits from the measurement — **less precise, not more**. It also needs a new verb that rewrites the stub in place against `:217`'s refusal, and it opens an abuse vector (re-baseline after the fix agent runs and any overrun vanishes) that would then need its own mitigation. |
| **Round-aware exclusion** (exclude only when an amendment ran) | The most precise in principle and the most state in practice: it needs a durable marker that an amendment ran this round, which is a new field in the progress file and a new way for the round's bookkeeping to be wrong. Rejected as cost without a matching gain, since the reporting requirement below recovers what it would have bought. |

**The reporting requirement is what keeps the backstop — and the verdict has TWO surfaces that carry
different things, so the label matters.** Re-derived:

| Surface | Carries |
|---|---|
| `check-fix-plan.sh:451` — `arm '' excluded-in-round "${ignored}" "$ignpaths"` | the **path names**. The only place they appear |
| `check-fix-plan.sh:455` — `emit applied … ignored=${ignored}` | a **count only** |

A blanket exclusion would otherwise remove arm (a)'s ability to catch a fix agent that edited a spec
file it was never briefed to touch. So a change to an excluded `ai-docs/plans/` path is **named on the
`excluded-in-round` line** rather than silently dropped, exactly as the learnings paths already are.
A2/A3 guarantee that **no passing plan names those paths**, so any change to one is unbriefed by
construction — naming it preserves the signal while the exclusion removes the false total. The
discrimination between "the amendment wrote this" and "the fix agent went rogue" is then the
orchestrator's, which is correct: it is the party that knows whether it ran an amendment, and that
knowledge is not derivable from the diff.

**An earlier draft of this paragraph said `ignored=`, which is the count-only surface.** That is the
header field at `:455`, and a leg or a reader directed there would see `ignored=2` and no paths at all.
The capability the backstop needs lives at `:451` and nowhere else.

> **THE READ OBLIGATION — it is owed to an instruction file, because an obligation written nowhere is
> not an obligation.** Re-derived with `grep -nF 'excluded-in-round'` against `skills/task/SKILL.md`,
> `skills/task/reference.md`, `agents/fix-scout.md`, `agents/fix-apply.md` and this design: **no
> match** in any of them, with a positive control confirming the search form reaches those files. So
> the remedy as first written assigned a duty to the orchestrator and recorded it in no place the
> orchestrator reads, and an implementer following the design would have gone looking for `ignored=`.
>
> **Subtask 4's surfaces owe one sentence**, in Step 11's binding text or its recipe: *whenever the
> `applied` verdict carries an `excluded-in-round` line, the orchestrator reads it and accounts for
> every named path against the amendment it knows it ran; a named path it cannot account for is a
> finding.* That sentence is what converts the downgrade below from a loss into a transfer.
>
> **The root these share, which is the better statement of the failure mode.** This remedy
> **downgrades a finding to a report**, and *a report is only as good as the obligation to read it plus
> the test that it was written.* The code half is already right — `:451` emits the names — so what was
> missing is wiring, not capability. All three of this round's issues sit on that one axis at three
> altitudes: **the criterion** claimed the arm was undiminished, **the leg** claimed to check naming
> while checking a count, and **no instruction** claimed the read at all. Each layer assumed a layer
> below it had covered the downgrade; none had.

**Both false sentences are corrected**, and T1-ZA's `amendment:` leg becomes writable end to end,
which is the test the false sentence was suppressing.

> **The spec dependency this remedy had is DISCHARGED — the sixth Spec Amendment landed.** An earlier
> draft of this blockquote said the spec carried no `ai-docs/plans/` exclusion clause at all and that
> "until that amendment lands, this section is a design of a remedy the criteria do not yet mandate".
> **Both sentences are now false.** Re-derived against the live spec: **AC7 carries the clause**, in the
> suffix-keyed form — "arm (a): **except for a `*.spec.md` or `*.design.md` under `ai-docs/plans/` (active
> or `done/`)**". AC7's older "the arm is
> not weakened" wording, which this remedy did falsify, has been amended with it. So implementation
> **is** sanctioned by the criteria as they now stand.
>
> **ROUND 10 — one clause removed from the sentence above, under the same narrow exception taken and accepted
> last round.** It read "— and AC18 carries the matching exclusion for the actual total". It does not:
> `sed -n '353p' <spec> | grep -cF 'ai-docs/plans/'` returns **0**, and the post-apply total AC18 once
> excluded lines from no longer exists. The exclusion is **AC7's alone**. Removed rather than annotated at
> length because this is a protected site and the clause is a verified-false live claim inside it — the
> minimum edit that stops it being read as current, and the same class of exception as the AC18 quote
> corrected in the criteria-by-AC-id table.
>
> **Two corrections to this very paragraph, because its own re-derivation went stale and one half of it
> was never right.** It quoted AC7 as reading "for a path outside `ai-docs/plans/`" — that wording
> appears **nowhere** in the spec (`grep -c 'for a path outside' <spec>` → **0**), and it inverts the
> criterion's sense: AC7 excludes the two suffixes *under* that directory, it does not act on paths
> outside it. And it recorded a hit count, now **withdrawn rather than updated**, because the figure has
> read 6, 7 and 8 inside this one round — the last move caused by the Spec Amendment that was supposed
> to settle the question. § The stale pending-amendment claim holds the full account and the
> criteria-by-AC-id table; this blockquote names the criterion and no longer restates a count it cannot
> keep true.
>
> **Kept rather than deleted, because the correction is the more useful record than the claim ever
> was.** The scout that planned round 3 found this stale blockquote — not the AC18 row I had been
> pointed at — and judged it the more harmful of the two, since it is the paragraph an implementer
> reads *before* reaching the AC table. It was right, and the general form is worth the space: **when
> the same false claim sits in a narrative section and in a table, the narrative copy is the one that
> does the damage**, because it is read first and read by someone looking for orientation rather than
> for verification. Correct both, and correct the narrative one first.

| Leg | Scenario |
|---|---|
| T1-ZF | **The amendment-then-resume round — and this is the ONLY leg pinning the backstop, so its assertion surface is load-bearing.** A round whose `round_base` predates an edit to `ai-docs/plans/<x>.spec.md` and to `ai-docs/plans/done/<y>.design.md`, plus a real fix to one briefed file. Arm (a) must **not** name either plan artefact as unplanned; arm (b)'s total must **exclude** their lines. **The primary assertion targets the `excluded-in-round` arm line by that label and requires BOTH paths BY NAME** — not the header's `ignored=` count, which a leg could satisfy with `ignored=2` while carrying no path names at all and no one would notice, because T1-ZG asserts the non-plans direction and nothing else pins "still named". Control: the briefed file's lines **are** charged and an unbriefed non-plans file **is** named — so the entry is a prefix exclusion and not a blanket amnesty. |
| T1-ZG | **T1-ZA's `amendment:` half, now end to end.** Previously asserted on the allowed-set construction because `applied` was believed unreachable. Now: a gated plan carrying an `amendment: spec` row, resumed after the amendment, with the fix agent editing a `fix` row's target — arm (a) names neither the plan artefact (excluded) nor the briefed file (allowed), and does name a third file touched by nobody's row. |

### GAP 2 — the anchor guard is weaker than the contract claims

**The claim, re-derived:** `agents/fix-scout.md:88` — "the gate resolves that anchor, so a fabricated
citation is refused mechanically."

**What the guard actually does.** `anchor_fault` (`check-fix-plan.sh:159-174`, re-derived) checks
**two** things: the file exists, and the line is within the file's line count. It never checks that the
quoted sentence is *at* that line. `self-review` demonstrated it on this round's own gated plan: all
four Arm A anchors were re-derived and **none** held the sentence it quoted — `design.md:26` is now a
blank line — and `check-fix-plan.sh plan` still printed `A1 anchor-resolution pass`.

**Why this is structural rather than cosmetic.** Two load-bearing decisions rest on it. The user's
round-5 decision gave A1 precedence over amendment routing *because* "a plan written without opening
the anchors it cites is a prediction wearing a plan's clothes" — and a line-range check cannot tell an
opened anchor from a plausible guess. And the entire cost argument for this mechanism is that the
orchestrator decides from the plan's **text** instead of re-deriving from the findings, which is only
sound if the text is verified. A guard that accepts any in-range line verifies the *shape* of a
citation and nothing about its *content*.

**The remedy: verify the quoted sentence against the cited line, within a window, on normalised
whitespace.** The rule, stated precisely because every clause is answering a failure mode:

1. **Scope.** Arm A cells that are not `none`, as now. Unchanged.
2. **Window, not line.** Match against lines `line-W … line+W` (**W = 3** proposed) joined into one
   string. This is what makes legitimate **re-wrapping** pass: instruction prose here is hard-wrapped,
   so a quoted sentence routinely spans two or three lines and a single-line match would refuse
   correct citations — which would make the mechanism unusable, the failure to avoid above all others.
3. **Whitespace normalised.** Collapse every run of whitespace to one space on both sides before
   comparing, so a line break inside the quoted sentence is invisible to the match. Nothing else is
   normalised — no case folding, no punctuation stripping — because each additional normalisation is a
   paraphrase the check would start accepting.
4. **Elision honoured.** Split the quote on `…` / `...` into fragments; **every** fragment must appear
   in the window, in order. Quoting a long sentence in parts is normal practice and must not be
   penalised; requiring order is what stops a fragment bag from matching unrelated text.
5. **Minimum specificity.** A fragment shorter than **24 characters** is refused as *too short to
   locate* rather than accepted. Without this a three-word quote matches almost any window and the
   check becomes decorative — the same "a check that cannot discriminate is not a check" problem this
   design has hit twice.
6. **Refuse, not warn — and its own reason token, `arma-quote-unverified`.** Refuse, because A1's
   precedence was granted on the premise that an unopened anchor is fatal; a warning would restore
   exactly the pass this gap is. A distinct token because the remedies differ: `anchor-unresolved`
   means fix the line number, `arma-quote-unverified` means re-read the file — the same reasoning that
   gave `plan-row-unmatched` its own token.

**What this deliberately does not close, stated so it is not mistaken for airtight.** An exact
substring within a window refuses a paraphrase and accepts a re-wrap, which is the trade asked for.
It will still accept a quote that is verbatim but cited **three lines off**, and it will refuse a
verbatim quote whose sentence has moved **more than three lines** since the plan was written. The
second is the honest cost of W: a round-trip through the rewrite cap, not a wrong result. W is a
starting value chosen like the threshold was, and the verdict should report it so it stays
recalibratable.

> **KNOWN RESIDUAL — the neighbouring sentence. Narrower than "accepts a plausible fabrication", and
> not nothing.** What GAP 2 exists to close *is* closed: a fabricated sentence appearing nowhere near
> the anchor is caught. But a **verbatim quote of a NEIGHBOURING sentence** inside the seven-line
> window still passes. The citation is then subtly wrong while the check reads green — and the Arm A
> cell's whole purpose is to let the orchestrator confirm *the* sentence at stake, not a sentence near
> it.
>
> The floor compounds this rather than guarding against it: **24 whitespace-normalised characters is
> about four words of instruction prose**, and strings that long genuinely recur across these files, so
> a quote of exactly 24 can match a window it does not belong to. The floor stops a three-word quote
> matching anything; it does not make a 24-character quote distinctive.
>
> **Do not read a passing window as proof that the cited sentence is the quoted one** — it proves the
> quoted text occurs within three lines of the cited line. **No change to the remedy**, which is the
> right trade at this price, and T1-ZJ already makes any retune of W a visible decision rather than a
> silent one. Recorded here so a later reader inherits the limit rather than rediscovering it.

| Leg | Scenario |
|---|---|
| T1-ZH | **The discriminating leg: a fabricated but RESOLVABLE citation.** The cited file exists and the line is in range, but the quoted sentence is nowhere near it — the exact shape `self-review` demonstrated. Must print `decision=REFUSE reason=arma-quote-unverified`. Control: the same cell with the sentence actually at that line → `PASS` with `A1 anchor-resolution pass`. **Must be shown red against the pre-strengthening gate**, where it prints `pass`. |
| T1-ZI | **The usability legs, which matter as much as the refusal.** A sentence hard-wrapped across three lines, quoted as one → **PASSES** (window + whitespace normalisation). A quote eliding its middle with `…`, both fragments present and in order → **PASSES**; the same with one fragment absent → REFUSE; fragments present but **out of order** → REFUSE. A fragment under 24 characters → REFUSE, with its own message distinguishing *too short to locate* from *not found*. |
| T1-ZJ | **The window's stated boundary, asserted so the limit is documented rather than discovered.** A verbatim sentence exactly `W` lines from the cited line → PASSES; at `W+1` → REFUSES. This pins `W` as a value the suite knows, so changing it is a decision with a visible test rather than a silent retune. |

---

## Design Amendment — the widened plan format (fourth Spec Amendment, user-approved)

The mechanism's **first real run** produced a valid plan over eight real findings (every anchor
resolved, declared 54 of 150, gate dry-reads `PASS`) and six shapes it could not represent. Three were
predicted by nobody — not this design, not three rounds of design-review, not the implementation
review. § Technical constraints 12 makes four of them binding; this section owes the HOW.

**One measured finding changes what part (d) must say, and it is stated first because an implementer
following the spec's wording literally would ship a red gate.** Details under (d).

### (a) At least one row per finding — and the hazard is which half relaxes

The relaxation is narrow: **only the "appears more than once" half.** Both refusing halves survive —
a finding in **no** row is refused, and a row whose number matches **no** open finding is refused.
That second half is `plan-row-unmatched`, the defect subtask 1a was created to close, so **relaxing the
wrong half silently reopens it.** That is the primary hazard of this change and the implementation must
be unable to drift into it rather than merely instructed not to.

**How the implementation is made unable to drift.** The two halves live on opposite sides of one
mapping and are computed from different inputs, so the guard is to keep them in separate loops over
separate files rather than in one reconciliation:

| Half | Input it reads | What relaxes |
|---|---|---|
| a finding in no row | `${WORK}/open-numbers` (`check-fix-plan.sh:265`, iterated at `:357`) | nothing |
| a row matching no finding | `${WORK}/rows`, membership-tested against `open-numbers` (`:313`) | nothing |
| a finding in more than one row | whichever loop counted occurrences | **this, and only this** |

So the change is the **removal of an occurrence count**, not an edit to either membership test. Stated
that way the hazard is structural rather than a matter of care: `:313` is a `grep -qxF` membership test
and membership is unaffected by multiplicity, so two rows for one finding both pass it unchanged.

> **WHERE THE EDIT LANDS — read this before touching the file; the sentence above says what is safe,
> not what to do.** "A correct implementation touches neither membership test" is true of `:313`, but
> the relaxation **is** an edit, and it lands inside the same loop as the surviving absent-refusal. An
> implementer who reads only the safety claim could open that loop, find nothing to change, and either
> stop or edit the wrong branch.
>
> All anchors below re-derived against the live file immediately before writing them:
>
> | Line | Content | Disposition |
> |---|---|---|
> | `:351` | `while IFS= read -r num; do` — the `open-numbers` loop | unchanged |
> | `:352` | `case $(… grep -cx -- "$num") in` — the scrutinee | unchanged (see below) |
> | `:353` | `0)` → "open finding N is absent from the plan" | **unchanged — this is the surviving absent-refusal** |
> | `:354` | `1) ;;` | **widen the pattern to `*)`** |
> | `:355` | `*)` → "appears more than once in the plan" | **DELETE this arm** |
> | `:357` | `done < "${WORK}/open-numbers"` | unchanged |
>
> **Net: one arm deleted, one pattern widened** — the `case` is left with `0)` (absent → refuse) and
> `*)` (one or more → accept). The `*)` arm at `:355` is multiplicity's **only** consumer, which is
> what makes this a deletion rather than a rewrite.
>
> **The scrutinee at `:352` needs no change and should not get one.** `grep -cx` still works correctly
> against `0)` / `*)`; afterwards only zero-versus-nonzero is consulted, so swapping it for a
> `grep -qx` membership test would be a legitimate simplification and is **not required** — churn in a
> line adjacent to a refusal branch is its own risk, and the gate has no review round left.
>
> **And `plan-row-unmatched` cannot reopen from this change**, which the verification pass confirmed in
> source: that half lives at `:313`, in a different loop, over a different file, and is never reached
> by an edit to these two arms.

**The test obligation that makes it checkable** — AC21 requires three legs and forbids one combined
assertion: a multi-row finding **passes**, an omitted finding is **refused**, a fabricated row number
is **refused**. The design adds the discriminator AC21 implies: **each refusing leg must differ from a
PASSING plan in that half alone.** A leg built by mutating the multi-row plan in two places at once
cannot show which half caught it, and a suite of that shape stays green if either half is lost — which
is exactly the failure T1-Z's own history on this task demonstrates.

**Why rows and not a multi-valued `Target` cell**, recorded because the measurement is the argument:
the anchor arm reads only the **first** token of the cell while the applied-diff arm matches the
**whole** cell, so a two-path cell breaks both checks at once and both files are then flagged. Several
rows leave every arm reading exactly what it already reads, which is why this widening needs no change
to arms A1–A5 or to either applied arm.

### (b) The fifth disposition token — `resolved: <reason>`

The vocabulary stays **closed**, now at five, validated at `check-fix-plan.sh:299` whose `case` already
has the shape this slots into (`fix|'amendment: spec'|'amendment: design'` / `'object: '?*`). The new
arm is `'resolved: '?*` — the `?*` is what refuses an empty reason, mirroring `object:`.

**What it asserts, which is the part that may not be weakened:** *the tree already satisfies this
finding, no edit is owed this round, and this is not a dispute.* Non-routing, zero declared lines,
reason part of the value.

**I keep the spec's lexeme.** It was offered as respellable and I considered `closed:` and
`already-satisfied:`; `resolved:` is better than both because the contrast it must carry is with
`object:`, and "objected" versus "resolved" is a distinction a reader gets without a glossary.

**One corner of the new token, recorded as deliberate so it is not rediscovered as a bug.** A
`resolved:` row whose `Target` is a plans artefact **will route.** A2/A3 detect on the target path
**or** the disposition, so a `resolved:` finding about a sentence in a `*.spec.md` triggers the
spec-amendment route even though no edit is owed. That is the **safe direction and it stays**:
over-routing costs a surfaced amendment the user can wave off, while under-routing lets an artefact
sentence stay false, and the dual detection is intentional (§ The gate — A2 and A3 each have two
independent detections). T1-ZC's passing leg deliberately scopes to a non-plans target, so **the suite
will not notice this and is not meant to** — no leg is owed; this sentence is the record.

**Why the token exists at all is the durable part.** The only no-edit, non-routing token available was
`object:`, which the contract defines as *the finding is not accepted* — false for a finding closed by
an amendment. The scout used it anyway, with a reason saying in plain words that this was not a
dispute. **An approximate token gets used when no exact one exists**, and the behaviour to expect is
exactly what happened: not a refusal, not an invented token, but the nearest available value plus prose
explaining that it is wrong. A closed vocabulary missing a real case does not produce an error; it
produces a quiet lie with a footnote. That is the argument for auditing a closed vocabulary against
real inputs rather than against imagined ones.

### (c) The gitignored-path clause, on both sides

The gate already charges 0 for such a path — that is how the progress file, which this round writes to
constantly, stays outside the measured tree (`is_ignored` is called at `check-fix-plan.sh:406`, and the
branch increments `ignored` and `continue`s at `:407` before any line arithmetic; an earlier draft of
this section cited `:406`'s call as `:407`, corrected on re-derivation). The **basis** names new,
deleted and binary files and is silent on it, so the scout had to guess and over-declared by 1 to stay
safe.

**The clause: a path outside the measured tree contributes 0.** It goes on both sides — the declared
total and the actual total — because AC4's and AC18's figures are comparable only while both count the
same way, and that shared basis is the entire reason AC5 can accumulate a declared-versus-actual
spread.

**It is `.gitignore`-derived, not list-derived, and the distinction matters.** Two different exclusions
are already in play and they must not be conflated: `git add -A` honours `.gitignore`, so a gitignored
path never enters either tree and is invisible to the diff; separately, the two-entry **in-round ignore
list** (`IGNORE_EXACT='ai-docs/learnings.md'`, `IGNORE_PREFIX='ai-docs/learnings/'` at `:51-52`)
excludes *tracked* paths the orchestrator may legitimately touch mid-round. The clause being added
describes the first. A scout cannot see either by inspection, so the basis must say so in words.

### (d) Every documented plan example parses under the gate's own extractor

**Measured, and it corrects the spec's account of this change.** I lifted `arma_anchor`
(`check-fix-plan.sh:169-176`) verbatim and ran it over both shipped examples:

```
NO ANCHOR  agents/fix-scout.md:53         `<spec path>`:40 — "<the quoted sentence>"
NO ANCHOR  docs/templates/progress-format.md:79   `<spec path>:<line>` — "<the quoted sentence>"
```

**Neither parses — including the file the spec designates as correct.** AC22 states that
`progress-format.md:79` "does" yield its anchor; it does not. There are **two** independent faults and
the spec names only one:

| Fault | Present in | Why the extractor rejects it |
|---|---|---|
| line number outside the backticks | `fix-scout.md:53` only | the backticked token is `<spec path>`, which carries no `:<line>` at all |
| a **space** inside the placeholder, and a non-numeric line | **both files** | the extractor requires `^[^ ]+:[0-9]+$`; `<spec path>` fails `[^ ]+` and `<line>` fails `[0-9]+` |

Narrowed by probe: `` `<spec path>:40` `` still fails (the space), `` `<spec-path>:40` `` parses, and
`` `docs/workflow.md:215` `` parses. So the placeholder, not only the punctuation, is load-bearing.

**Consequence an implementer must not meet by surprise: "the template is right, the contract is wrong"
is half true.** The template's backtick *placement* is right and is the direction to copy. But
correcting `fix-scout.md` to match `progress-format.md` exactly would leave the mechanical assertion
**red against both files**. The repair is two-part: copy the template's placement, and give both files
a placeholder the extractor accepts — a path with no space and a numeric line, e.g.
`` `<spec-path>:40` ``.

**Two scoping rules the assertion needs, or it fails on correct rows.** The gate itself skips the cell
when it is the literal `none` (`:272` tests `arma != none` before calling the extractor), and rows 1
and 2 of both examples are `none`. So: the assertion applies to **Arm A cells that are not `none`**,
and it must call the gate's own extractor rather than a reimplementation of it — a second copy of that
awk is a second thing to drift. Lifting the function from the shipped script is what makes the leg a
test of the gate rather than of a lookalike.

**The real-artefact fixture requirement (AC2) is re-asserted by this widening, not relaxed.** A format
change is precisely where a fixture silently stops matching production input, and this one is a format
change to the cell a routing leg cites.

### Two findings about method, stated to outlive this task

Both come out of the first real run, both are more general than the token or the format that produced
them, and `design-review` asked for them at this level rather than as notes on a change.

**1. A calibration datum on review as a method: one real run found six defects; imagining inputs found
one.** Those six shapes survived a design, **three** rounds of design-review and a skeptical
implementation review. Three of them were predicted by **nobody**. `design-review` predicted exactly
one — the multi-file case — and only because the amendment it happened to be reviewing *was* an
instance of it.

The general form, which is the one to carry: **a format is validated against real inputs or it is not
validated.** Review against imagined inputs is good at finding what a format *says* and poor at finding
what it *cannot say*, because the reviewer and the author imagine from the same place. The corollary
for this repository's own rules: *"Probe real output for the class of thing that must never appear,
not only for the thing that must"* (`docs/agents-method.md § Test Conventions`) — and the first real
plan is that probe. **The cheapest reviewable artefact on this task was the one real run**, which
argues for dogfooding a format on one genuine input before the third review round, not after it.

**2. The failure mode a closed vocabulary actually produces — and the reason no gate could catch it.**
Faced with a case the vocabulary did not contain, the scout did **not** refuse and did **not** invent a
token. It wrote the nearest available value — `object:` — with a reason saying in plain words that this
was not a dispute. **A quiet lie with a footnote is harder to detect than either an error or a
refusal**, and nothing mechanical in the gate could have seen it: every arm passed, the vocabulary
check at `:299` was satisfied, the plan was valid. Only reading a real plan found it.

Two consequences worth acting on beyond this task. **Audit a closed vocabulary against real inputs
rather than imagined ones** — the gate can prove the vocabulary is closed, and cannot prove it is
*complete*, so completeness is an empirical question and the only instrument is a real case.
And **when a value arrives with prose explaining why it is wrong, treat the prose as the finding** — a
disclaiming reason beside a well-formed value is a vocabulary gap reporting itself in the only channel
it has.

### Decomposition shape — the same call as the arm (a) amendment, and why

`M` is at seven and `agents/design.md:106` binds at eight, so this is **not** a new subtask. **Three**
precedents now exist on this task and they are not interchangeable:

| Precedent | When it applies | Shape |
|---|---|---|
| **subtask 1a** | the decomposition is closed but a **group has not yet run** | a named non-sequential entry, executed by that group |
| **the arm (a) amendment** | **every group has run**, and the change is the remedy for an open finding | a review finding carried through the scouted sequence |
| **the routing fix (round 3), and the round-9 micro-loop with it** | every group has run, and the change is **the remedy for no finding** — or is a precondition of the plan that would carry it | an approved amendment implemented by a delegated handoff, **outside** the plan. **The round-9 work takes this shape too and rides the same handoff**, because all three groups have already RUN and the group is the unit of fan-out (`skills/context-reset/SKILL.md:30`), so a new subtask would have no open group to carry it. **NOT because a fourth group is forbidden** — an earlier form of this row said so and it was false; § Handoff plan's own callout records the arithmetic that refutes it, three groups holding up to nine subtasks with the cap first breached at ten |

**The third shape exists because the second one is unavailable to it, and the reason is structural rather
than procedural.** The plan format expresses findings; the routing fix is nobody's remedy, so it has no
row — and even if a row were manufactured for it, the plan carrying that row cannot pass the gate until
the fix is already in the code. See § The routing arms' PATH half keys on every row for the full
derivation and for why attaching it to an existing finding number was refused. The durable form:
**a remedy that unblocks the gate cannot travel through the gate it unblocks.**

Every group has run, so the arm (a) amendment takes the second shape. **And it joins the arm (a) amendment rather than
forming a second round:** both are pending, both are user-approved, and one scout → gate → fix-agent
pass over the combined set costs one round instead of two. That is also the cheaper dogfood — the
displacement figure AC11 owes is measured per round, and two rounds where one would do would
understate the mechanism by construction.

### Test legs

| Leg | Scenario |
|---|---|
| T1-ZB | **(a) multi-row, three legs, never combined (AC21).** A finding occupying two rows → `PASS`. An open finding in no row → `REFUSE reason=finding-coverage`. A row numbered for no open finding → `REFUSE reason=plan-row-unmatched`. **Each refusing leg differs from the passing plan in that half alone**, so the leg that caught it is identifiable and the suite cannot stay green if either half is lost. |
| T1-ZC | **(b) the fifth token.** `resolved: <reason>` with a non-empty reason, 0 declared, non-plans target → `PASS`, routing nothing. Empty reason (`resolved:`) → `REFUSE`. A token outside the five → `REFUSE`, which is the leg that keeps the vocabulary closed. A round whose rows are **all** `resolved:` → `PASS` with declared 0 (AC19: no exemption hides in the vocabulary). |
| T1-ZD | **(c) the gitignored clause.** A round editing a gitignored path and one real file: the actual total charges only the real file, the verdict reports the gitignored path as excluded, and a plan declaring 0 for the gitignored row agrees with the measured total. Control: the same edit to a non-gitignored path **is** charged. |
| T1-ZE | **(d) examples parse.** Extracts every Arm A cell that is not `none` from every plan example in `agents/fix-scout.md` and `docs/templates/progress-format.md`, runs the **gate's own** `arma_anchor` over each, and requires a non-empty anchor from all of them. **Positive control, because the failure mode is an empty result:** the leg must be shown red against today's tree, where both files fail — a leg written after the files are fixed and never run against the broken state proves nothing. |

### Two notes from the first run, folded in where they change behaviour

**A brief that contradicts the gate it feeds.** The orchestrator's spawn prompt told the scout not to
touch the plan's header fields, against a gate that **refuses them empty** (`verification-missing`,
and `declared_changed_lines` absent is a refusal). The scout filled them and named the contradiction,
which is the documented correct response to a directive that disagrees with its own controls. **This is
a defect in how the brief is written, not in the format**, and the fix belongs in
`skills/task/reference.md` § Step 11's recipe: the spawn prompt must state **which fields the scout
fills** — `verification` and `declared_changed_lines`, the two `baseline` deliberately leaves empty —
and must not describe the stub as untouchable. The stub's emptiness is a feature (a placeholder would
pass the verification arm) and the brief has to say which half of it is the scout's.

**A false brief is worse than a true finding.** Offered a way to silence the multi-file refusal —
point the row's `Target` at the test file and let another row cover the script by path — the scout
rejected it, on the ground that it would hand the fix agent a brief misdirecting it away from the real
line. Keep this as a stated principle wherever the design discusses what a plan asserts: **the plan is
a brief for another agent before it is an input to a gate, so a row that satisfies the gate while
pointing at the wrong line is a worse outcome than a refusal.** It is the same reasoning that makes
Arm A quote a sentence rather than record a verdict, and the reason the gate's refusals are cheap by
design — a refusal costs one rewrite; a false brief costs a wrong edit plus the round that finds it.

### AC22's false premise — raised, and now CLOSED in the spec

AC22 originally said `docs/templates/progress-format.md:79` yields the anchor it appears to carry.
Measured above, it does not — the placeholder's space defeats the extractor — so an implementer reading
"the fix is the template's form, not the contract's" would have copied the template and still been red,
with no review round left to catch it.

**The spec correction has landed and is complete**, verified on disk by the orchestrator: AC22 now
names **both** faults, the **two-part** repair (copy the template's placement, *and* give both examples
a placeholder that parses), that the two files are sync-group members corrected together, and all three
conditions on the assertion — the non-`none` scope, the use of the gate's own extractor, and the
red-against-today obligation. **Nothing further is owed from the spec**, and part (d) above and AC22
now agree. The dependency flagged as "must not land wrong" is closed.

---

## Design Amendment — arm (a)'s allowed set (user-approved, post-implementation)

Implementation review found that arm (a) pre-authorises files it should not. The user approved both the
code fix and this design correction, so the sentence it falsified is amended rather than left standing.
**The design-review cap is spent at 3 of 3, so this gets one verification pass and then ships.**

| Item | Resolution |
|---|---|
| **Arm (a) builds its allowed set from every plan row** | **Confirmed in source and specified.** `check-fix-plan.sh:401` (re-derived) takes `$4` — the `Target` cell — with no filter on `$3`, the disposition. So `object:` and `amendment:` rows pre-authorise their targets, which are exactly the rows `fix-apply` may not touch. Allowed set is now **`fix`-row targets only**, matching the token validated at `:299`. Test leg **T1-ZA**. § The gate. |
| **The falsified sentence** | **Amended.** The AC7 row said subtask 1a closed the gap "from the only direction arm (a) cannot see". Re-derived to `:1077` before editing, as instructed — the anchor had **not** moved. It now records **two** closed directions and claims neither is the only one. |
| **The pattern, now twice in one mechanism** | Both defects are *a permission derived from the wrong side of a mapping*. Added to § Test Design's standing rules as a third rule aimed at authority rather than coverage: **when a permission is derived from a table, check what the table admits that the permission never meant to cover** — expect the next one wherever a list serves both as a description and as a grant. |
| **"Six vocabularies" against seven named paths** | **Confirmed at `docs/propagation.md:32`** — the shipped anchor row, which names seven paths and then counts six. Exactly the drift this design warned itself about, in text this design specified. It needs `Seven`, and the prose's own enumeration needs the seventh role (the workflow page's amendment routing) named beside the six it lists. Flagged for the orchestrator: it is a one-word fix in a file the amendment is not otherwise touching. |
| **The counting basis is not identical across surfaces** | **Confirmed, and the loose claim replaced rather than softened.** Four surfaces, not three. `progress-format.md:143` drops the new-file / deleted-file / binary clauses; `fix-scout.md:73` says a deleted file counts "the line count it has now" against the gate's "at the baseline". Both text fixes ride with this amendment, with the reason they may. § The counting basis. |
| **Every line number re-derived** | Done, and it caught one of mine. See below. |

### Re-deriving caught a fourth self-inflicted measurement error

Instructed to re-derive every anchor, I ran `grep -n 'planned=$(table_rows' …` and got **nothing** — and
briefly concluded the file had changed under me. It had not: **`$(` in a basic regular expression can
never match**, because `$` anchors end-of-line, so the pattern was unsatisfiable and the empty result
was my own. `grep -nF 'planned='` found it at `:401` immediately, with a positive control to prove the
search form could return a hit.

That is the fourth time on this task that a probe, not the thing probed, produced the wrong answer —
after the porcelain/plumbing rename confusion, two contaminated "clean tracked tree" fixtures, and a
stale `A4 at :322`. **The durable form: an empty search result is a claim about the search until a
positive control says otherwise**, which is the rule this repository already states and which I have
now violated once and caught once in the same round.

### State re-derived rather than inherited, because it had moved again

The brief described Group B as blocked. It is not: **subtasks 1a, 4, 5 and 6 have all landed.**
`plan-row-unmatched` is present in both the gate and its suite; `skills/task/SKILL.md`,
`reference.md`, `progress-format.md`, `propagation.md`, `hooks.json`, `workflow.md`, `self-review.md`,
`bugfix/SKILL.md`, `project-review/SKILL.md`, `context.md` and `plugin.json` are all modified in the
working tree.

**So this amendment is not a decomposition subtask and the table stays at seven.** There is no group
left to place it in, and inventing subtask 8 would trip `agents/design.md:106` for a one-expression fix
— which would be the convenient-carve-out reading of a rule I spent round 3 getting right. It is a
review finding, and the orchestrator will run it through the scouted scout → gate → fix-agent sequence
this task built. That is the mechanism dogfooding itself on its own defect.

**And the propagation prediction is confirmed.** `bash scripts/check-propagation-arms.sh` on the live
tree: **`40 derived members all fire, 13 controls all silent, 2 pre-fix matches all kept`**, with
`agents/fix-scout.md`, `agents/fix-apply.md`, `skills/task/scripts/check-fix-plan.sh` and
`docs/templates/progress-format.md` all listed as firing. AC17 asked for a figure recorded before the
run and matched after it; **40 was recorded in round 2's write-back and 40 is what the gate reports.**

### One defect outside this amendment's scope, reported not fixed

`ai-docs/context.md:73` says "The 12 hooks". Re-derived from the manifest —
`jq '[.hooks[][].hooks[]] | length' hooks/hooks.json` → **20**. Same class as the anchors corrected
twice on this task, in a file subtask 6 has already touched, and not a file this amendment is otherwise
editing. Flagged for the orchestrator rather than silently corrected.

---

## Round-3 revision log — the second Spec Amendment (arm precedence)

The spec now fixes the full arm precedence; this design stated only half of it, which is how the
ambiguity reached implementation. Two obligations, both discharged, plus one finding my own probe
surfaced.

| Item | Resolution |
|---|---|
| **§ Arm order stated only half the order** | **Fixed.** It now states anchor resolution → amendment routing → size, first failure decides, with a pair-by-pair table of reasons, what the precedence does *not* decide, and the note that this was an ambiguity *surfaced* by implementation rather than introduced by it. § The gate. |
| **The missing discriminating test leg** | **Added as T1-Y**, with what it plants and what it must print. **Verified absent from the shipped suite** by enumerating its section banners — not assumed absent from an evidence table. § Test Design. |
| **AC2's real-artefact fixture requirement** | **Already satisfied; no work owed.** `mkfix` writes real four-line `ai-docs/plans/t.spec.md` and `ai-docs/plans/done/t.design.md`, and T1-B/T1-C cite `:4` in each. Recorded with the citation so nobody re-does it. |
| **Precedence in the implementation** | **No code change owed**, re-derived in source: `check-fix-plan.sh:197` first-wins `decide()`, arms at `:303` / `:306` / `:309` / `:322`. All three precedence pairs were also run by hand against the shipped gate and already print the required decision. |
| **Subtask 5's index precondition** | **Added.** The two agent contracts were on disk but intent-to-add only reached them after the fact, and the propagation gate resolves bare filenames from the index. Subtask 5 now carries the `git add -N` precondition explicitly rather than inheriting it. |
| **T1-Z's swap leg was claimed to discriminate; it does not** | **Corrected, and the leg is kept with its real job named.** `design-review` built both candidate A6 implementations and ran four inputs through each: on the swap both print `REFUSE reason=finding-coverage`, because the omitted finding trips the pre-existing missing-check first. Measured generally: **no input discriminates the two while all three existing A6 checks are intact** — my own pigeonhole observation, stated correctly in the body and then overstated in the cell. The swap leg is now described as a **regression canary**, the **primary** leg is named as the actual discriminator (it separates them on the reason token), and a **mutation leg** is added to test the independence claim the set check was chosen for, following `scripts/test-run-checks.sh:299-314`. § The gate, § Test Design. |
| **The two-limits callout rested on one false leg** | **Corrected; the conclusion stands on `design.md:106` alone.** The group cap does not forbid an eighth subtask: three groups hold up to nine (3/3/2 at `M = 8`, 3/3/3 at `M = 9`), and `context-reset/SKILL.md:83` is first breached at `M = 10`. "An eighth subtask cannot be absorbed by regrouping" was literally false. Recorded rather than quietly fixed, because a reader who believed it would refuse an `M = 9` the rules permit. § Handoff plan. |
| **A6's refusal-path count was understated** — found while re-deriving the token list | **Corrected.** A6 already refuses under `no-plan-section` (`:233`) and `plan-row-malformed` (`:252`) besides `finding-coverage` (`:348`), so 1a makes **four** distinct reason tokens under one arm, not the "five refusal causes" an earlier draft of T1-Z asserted. The full twelve-token vocabulary is now enumerated from source. § A6's converse. |
| **A6's converse is unchecked** — found by this round's precedence probe | **Decided by the ORCHESTRATOR: fix it in this task.** Verified in source at `check-fix-plan.sh:350`, where both counts are computed inline and never compared. Lands as **subtask 1a**, a named amendment to subtask 1's artefact carried out by Group B, with reason token `plan-row-unmatched` and test leg T1-Z. No spec amendment owed — AC7 is *literally* satisfied by a padded plan, so closing this makes AC7 mean what it reads rather than changing what it says. `M` moves 6 → 7 and the groups re-form as 3 / 3 / 1. § A6's converse. |

### A6's converse — decided by the orchestrator: fix it in this task, as subtask 1a

**Decision and attribution.** Raised by this round's precedence probe, verified in source by the
orchestrator, and **decided by the orchestrator to be fixed inside this task** rather than deferred.
Recorded here with its reasoning because a later reader will otherwise re-litigate it.

**Why fix rather than defer**, in order of weight:

1. **It is a hole in the mechanism's primary safety property, not a cosmetic gap in one arm.** The
   plan's `Target` column is what arm (a) measures the applied diff against, so a plan row matching no
   open finding **pre-authorises a file**. Arm (a) cannot see it from its own side by construction: it
   is keyed on files the plan did *not* name, and a padded plan names them.
2. **The condition is already detected and merely not acted on.** A gate that computes a disagreement,
   prints it, and returns `pass` is the "looks like a check, is not a check" shape this repository's
   rules exist to prevent — and the worst possible place to ship one is inside the gate whose entire
   purpose is mechanical trust.
3. **The price is one comparison and one test leg**, against an artefact whose own suite is its entire
   mechanical coverage (§ Technical constraints 4). Deferring a known widening of the safety property
   at that price is a bad trade — and AC13's follow-up issue is for extending the mechanism to three
   *other* flows, so parking a defect there would quietly change what that issue is.

**No spec amendment is owed, and that was checked rather than assumed.** No criterion becomes untrue
either way. AC7 is *literally satisfied* by a padded plan, because the extra file **is** named — which
is exactly how the hole survives a diff-keyed reading, the same structural failure the spec's own
Arm A / Arm B discussion describes. Closing it makes AC7 mean what it reads rather than changing what
it says, so it is a strengthening inside a mechanism the spec already mandates.

**What was wrong with my definition, stated so the lesson transfers.** Not "my definition was the
defect" — that tells a later reader nothing. The accurate description: **A6's definition enumerated
three failure modes of the findings-to-plan mapping and omitted the fourth, which exists only in the
direction the mapping is many-to-one.** Findings map to plan rows, so the definition naturally covered
the finding side — missing, duplicated, mislabelled — and left the row side unchecked. **The durable
check when defining any coverage arm: enumerate the failure modes in BOTH directions of the mapping,
and ask explicitly what the many side can contain that the one side never mentioned.**

**The measured evidence.** With one `⬜ Open` finding and two plan rows, the shipped gate prints:

```
  A6   finding-coverage     pass  1 open findings, 2 dispositions
```

Both counts are computed inline in the pass branch — `skills/task/scripts/check-fix-plan.sh:350`,
re-read in source this round — and never compared.

**How to close it: compare the SETS, not the two counts.** The counts would in fact suffice *today*, by
a pigeonhole argument — if every open finding appears in the plan, no finding appears twice, and the
counts are equal, then no row can be unmatched. **That is the weaker form and it should not ship**,
because it is correct only as a conjunction with two other checks: it passes on a *swap* (one finding
omitted, one row fabricated, counts equal) the moment either of those checks regresses. The direct
check — each plan row's `#` must match an `⬜ Open` finding — depends on nothing else. The loop over
`${WORK}/rows` already exists; this is one membership test inside it.

> **The honest limit of that argument, measured by `design-review` against both implementations
> built and run.** While all three existing A6 checks are intact, **no input discriminates
> count-equality from set-membership on the decision alone** — the pigeonhole holds, so both refuse
> everything the other refuses:
>
> | Input | count-equality | set-membership |
> |---|---|---|
> | open{1}, rows{1,2} | `REFUSE finding-coverage` | `REFUSE plan-row-unmatched` |
> | swap — open{1,2}, rows{1,3} | `REFUSE finding-coverage` | `REFUSE finding-coverage` |
> | omission — open{1,2}, rows{1} | `REFUSE finding-coverage` | `REFUSE finding-coverage` |
> | clean — open{1}, rows{1} | `PASS` | `PASS` |
>
> So the set check earns its place on two narrower grounds than "it discriminates", and the design says
> which: it **names the fault correctly** (row 1 — the reason token differs, which is what T1-Z's
> primary leg asserts and the weaker implementation cannot satisfy), and it **survives regression of
> the checks the pigeonhole argument leans on**, which only the mutation leg can show. An earlier draft
> of T1-Z's cell claimed the swap leg discriminated; it does not, and the body's own wording — "the
> moment either of those checks regresses" — was the correct conditional that the cell dropped. Worth
> recording because *a leg that cannot discriminate is not a leg* is this design's recurring theme, and
> here it was asserted about one of the design's own legs.

**Reason token: `plan-row-unmatched`.** Spelled here so it is not invented at implementation time. It
follows the existing `<thing>-<state>` shape of `anchor-unresolved`, and it is deliberately **its own
token rather than more `finding-coverage` detail**: the three existing causes are all "the plan
under-covers or mis-labels a finding the review raised", a scout that failed to address something, with
the remedy *fix the row*. This one is "the plan asserts a finding the review never raised", with the
remedy *delete the row* and a different risk — pre-authorisation. Same arm, different fault class, so
the verdict names it differently.

**A6 already carries more refusal paths than the three the definition enumerated, re-derived in source
this round:** `no-plan-section` (`check-fix-plan.sh:233`, when there is no `## Fix Plan` section at
all) and `plan-row-malformed` (`:252`, a row whose cell count is not 5) both refuse under the `A6`
label with their own tokens, alongside `finding-coverage` (`:348`) which carries the four sub-causes.
Adding `plan-row-unmatched` makes **four distinct reason tokens under one arm**, and T1-Z's controls
exist to keep them from collapsing into each other. The gate's full token vocabulary after 1a:
`anchor-unresolved`, `spec-amendment`, `design-amendment`, `declared-sum-mismatch`,
`size-over-threshold`, `verification-missing`, `no-plan-section`, `plan-row-malformed`,
`finding-coverage`, **`plan-row-unmatched`**, `unplanned-file`, `actual-overrun`.

> **CORRECTED for round 9, and the list above is the record of the vocabulary after 1a rather than the one
> that ships.** One change, and it is a deletion: **`actual-overrun` is RETIRED**, because the post-apply
> size arm is withdrawn in every form (§ Design Amendment — round 9) and `applied` emits no size token at
> all. Nothing is added in its place — **an earlier draft of this callout said a new A4 token for a
> non-`fix` row declaring non-zero would replace it; that refusal existed only to make a subtraction honest
> and is withdrawn with the subtraction.** A token list is exactly the kind of enumeration that goes stale
> beside the thing it enumerates, so the shipped vocabulary is the one in `reference.md`'s reason-token
> table, which the recipe reads and which the handoff list's instruction-text item updates; this paragraph
> records the shape of the change, not the authoritative list.

### How it was found, which is the part worth keeping

Nobody looked for it. It fell out of the **precedence** probe: to test arm order I needed a plan
carrying two faults at once, which meant a plan with two rows against a fixture that had one open
finding — a shape no per-property leg ever builds. The arm then printed its own counts disagreeing and
passed.

The transferable part: **a leg written to test an interaction constructs inputs no single-property leg
constructs, and those inputs exercise arms nobody was testing.** T1-Y was asked for to discriminate arm
precedence; it incidentally discriminated A6. That is an argument for writing interaction legs even
when each property already has one — which is also, independently, the reason AC1 now demands T1-Y.

### Three implementation facts folded in where they change what a later reader would do

- **`baseline` writes the table HEADING too**, so the counting basis travels with every plan rather
  than depending on the scout reproducing it. The stub leaves `verification` and
  `declared_changed_lines` **empty rather than placeholder-filled**, because a placeholder is non-empty
  and an unfilled stub would then pass the verification arm — the same "fallback that satisfies the
  comparison it feeds" hazard the test conventions name. And `baseline` **exits 2 rather than appending
  a second section** to a round that already has one, since two sections sharing a round number make
  the header reader take the stub's empty values.
- **The AC5 no-literal grep is narrower than it looks, and my spelling of it was wrong.** `\b` is a GNU
  extension, so on a `grep` that does not implement it the scan returns **empty** and the leg reads
  that as agreement — a silent pass in the exact shape this design keeps warning about. The suite
  ships `grep -lw` with a planted positive control. The unqualified `grep -rn '150'` is unusable:
  re-run this round it returns **2 hits**, both the `1500 incl. tests` file-size limit —
  `agents/review-findings.md:72` and `agents/self-review.md:85`.
- **`check-propagation-arms.sh` reports 36 right now, and that is correct rather than a miss**:
  re-run this round, `36 derived members all fire, 13 controls all silent, 2 pre-fix matches all kept`.
  It derives from the table subtask 5 has not yet edited. The existing `agents/*.md` arm already matches
  both new agent files, so **the one added hook arm is owed only by the gate script's path**. The
  predicted **40** is unchanged.

---

## Write-back notes from the GO verdict

Five design-internal notes, each re-measured here rather than accepted. Two changed my answer.

| Note | Resolution |
|---|---|
| **1 — pure rename** | **Confirmed, and it is 2N.** My first probe of this disagreed, and my first probe was wrong: I measured it with `git diff --numstat --cached`, where rename detection is **on by default**, and got the collapsed `=>` form at `0 0`. Re-measured against the command the design actually ships — `git diff-tree -r --numstat`, which is plumbing and detects nothing by default — a 10-line rename yields `0 10 ren_from.txt` + `10 0 ren_to.txt`, so max-sum = **20 = 2N**. The basis definition and `fix-scout`'s brief now say a rename counts as a delete plus an add. § The counting basis, and T1-N gains a sub-leg. |
| **2a — the `write-tree` absolute** | **Conceded; the sentence was false and the snippet carried the defect it disqualified others for.** Measured: `snap()` exactly as § The baseline wrote it returns **rc 0 with empty output** when `read-tree` is pointed at a bogus rev, because `rm -f "$idx"` is its last command and the function's status is `rm`'s. The absolute is dropped and the snippet is guarded. The containment the reviewer cited is also confirmed: `diff-tree -r --numstat "" <sha>` **hard-errors at rc 128**, so an empty baseline cannot report zero. § The baseline. |
| **2b — `stash create -u`** | **Qualified.** The apparent contradiction is resolved and neither measurement was wrong. Measured both ways: genuinely clean tracked tree + untracked files → rc 0, **empty**; dirty tracked tree → a **sha**. In both, the untracked files stay untracked and absent from the diff. So `-u` is silently accepted rather than rejected, and the row now carries the qualifier. |
| **3 — "five members"** | **Stale word, fixed by enumerating instead of counting in prose.** The row is now written out path by path and the prediction derived from that list in place. |
| **4 — `progress-format.md`** | **Decided: include it. Prediction moves to 40.** Reasoning and the measured run below. |
| **5 — `hooks/hooks.json`** | **Accepted.** It is a hardcoded *control* the gate requires to stay silent, and it appears in subtask 5's file list. Subtask 5 now says so explicitly. |

### Note 4, decided: `docs/templates/progress-format.md` is a member

**Included.** The deciding argument is the one I used to win the gate-script question, and applying it
to one file and not the other would be the inconsistency I accused the alternative of. Rule 4's test is
whether a file "explains a mechanism in its own vocabulary", invisible to a token sweep.
`progress-format.md` defines the `## Fix Plan (Round N)` schema **that the gate parses** — it is the
mechanism's data structure, written in the progress file's vocabulary rather than the gate's. If that
file's section drifts, the parser breaks and no sweep over `skills/` or `agents/` reaches it.

The cost that made the gate script contentious is absent here: it already matches the reminder's
existing `"$pd"/docs/*.md` arm, so **no new hook arm** is needed for this member.

**Measured, with the full membership in place: `40 derived members all fire, 13 controls all silent,
2 pre-fix matches all kept`**, and `scripts/test-check-propagation-arms.sh` against that same tree
`53 passed, 0 failed`. **The recorded prediction is therefore 40**, superseding 39. A run reporting
anything else is a finding, not a new baseline.

### Carried forward into implementation

**Keep the revision-log pattern.** The reviewer judged the two rows recording primitives that *look*
correct and are not — `stash create -u`, and `add -N` + `stash create` — more valuable than the row
recording what shipped, because they are what stops the next agent re-trying them. So: every
implementation subtask that discards a candidate records the candidate, the measured failure mode, and
the command that produced it. A discarded approach with no recorded measurement is an invitation to
re-discover it.

This round supplies one more instance, and it is mine rather than inherited: my first rename probe used
the porcelain `git diff` where the design ships the plumbing `git diff-tree`, and the two have opposite
rename-detection defaults. **Probing a command that is not the command under test is its own failure
mode**, and it produced a confident wrong answer that contradicted a correct report.

---

## Round-2 revision log

Read against the amended spec, re-measured, and changed. Every figure below was re-derived in this
round; none was carried over.

| Issue | Resolution |
|---|---|
| **MAJOR 1** — untracked half of the measurement not scoped to the round | **Confirmed and fixed by replacing the baseline mechanism.** Re-measured on this branch: **1014** untracked lines (`737` design + `277` spec) — and it was 772 earlier in this same revision, which is itself the point: the figure grows as the task writes. So arm (b) would fire and arm (a) would name both plan artefacts on this task's own first round. `git stash create` baselines tracked files only; `git stash create -u` was measured to return **empty** anyway, and `git add -N` + `git stash create` was measured to **fail outright** (`error: Entry … not uptodate. Cannot merge.`, rc 128, empty output — a silent-empty baseline, the worst mode). The design now uses a **temp-index tree baseline**, which is exact for tracked and untracked alike. Plus a narrow in-round ignore list. § The baseline. |
| **MAJOR 2** — the two firing sites measure different quantities | **Confirmed; resolved by redefining arm (b), which the spec permits "but then say so".** Measured: 80 existing lines rewritten → `numstat 80 80` → added+removed = **160**, so arm (b) would trip at ~75 modified lines on this repo's dominant diff shape. The basis is now defined **once** as per-file `max(added, removed)`, summed, and stated on **both** sides. § The counting basis. |
| **MINOR 3** — `applied --since <rev>` let the measuring party pick its own baseline | **Fixed by removal.** `--since` is dropped; `applied` reads `round_base` out of the gated plan section. § The gate. |
| **MINOR 4** — the AC19 verification line could never return empty | **Confirmed and fixed.** Re-run as written: 3 hits at rc 0 (lines 127, 192, 218, none in Step 11). The span is now in the command, and both directions were run. § AC verification. |
| **MINOR 5** — free text in positionally-split columns | **Fixed.** Escaped pipes are normalised to a placeholder before splitting and restored after, with a round-trip leg. § The plan format. |
| **Text item** — `run-checks.sh` exemption comment | **Accepted.** Confirmed at `scripts/run-checks.sh:153`, a two-item prose comment. Subtask 2 amends it. |
| **Text item** — `progress-format.md` line citations said to be off | **Not reproduced; citations re-derived and left as they were.** All five were re-checked against the live file this round and every one is exact: `:7` gitignored, `:78` the per-round `## Fix cycle round M` row, `:119` the `Self-Review (Round N) sections` heading, `:123` the anchor-at-EOF note, `:130` deletion by `/pr-merged`. Reported back rather than "corrected", because changing a correct citation would introduce the drift the item was guarding against. |
| **The membership tension** | **Resolved in favour of naming the gate script.** Measured, not argued. The count recorded here was 39; write-back note 4 adds `docs/templates/progress-format.md` as a member, so **the live prediction is 40** — § Naming the gate script on the anchor row is the single source for it. |
| **Spec amendment 1's conditional** | **Re-checked against this design, and it does not fire.** Neither agent is routed through the handoff contract: both are spawned with a direct `Agent` call from Step 11, `/context-reset` is not involved, and `skills/task/SKILL.md:128`'s every-group handoff rule is not edited. So `agents/design.md`, `agents/design-review.md` and `skills/context-reset/SKILL.md` receive nothing, and the Task/Design group stays unswept. |

---

## Approach

### The shape

Step 11 becomes a multi-beat round with one script owning every number — **four beats as first designed, FIVE since round 9 added the micro-loop** (mechanical check → question → re-fix → escalate-on-burned-cap → review); the count is corrected here and the sequence itself is in § Design Amendment — round 9:

```
orchestrator: baseline  ──▶  scout (fresh ctx)  ──▶  gate (script)  ──▶  fix agent (fresh ctx)  ──▶  gate (script)
              1 call         writes the plan         decides            applies `fix` rows          verifies the diff
                            into the progress        PASS / REFUSE /                                arms (a) + (b)
                            file                     ROUTE-* / ESCALATE
```

Four decisions, each with its own exit lane, are resolved in the sections below. The five
design-owned questions the spec assigned here are answered as:

| Spec open question | Decision |
|---|---|
| Where the plan artefact lives, gitignored or committed, per-round or overwritten | A **`## Fix Plan (Round N)` section appended to the task's existing `ai-docs/plans/<base>.progress.md`**. Already a file on disk, already gitignored, already per-round, already deleted by `/pr-merged`. |
| Two agent files or one with two modes | **Two** — `agents/fix-scout.md` and `agents/fix-apply.md`. |
| One gate script or several | **One script** — `baseline`, `plan`, `applied`, and `record` since round 9. **Four verbs, not the three this row first named.** |
| The gate verdict's exact output format | A `decision=` key-value header line plus one line per arm. Spelled out in § The gate. |
| Where the threshold constant is defined | A single `THRESHOLD_CHANGED_LINES=150` assignment at the top of that one script, which is the *only* file in the change permitted to contain the literal. |
| Disposition of an objected finding | A closed-vocabulary **`Disposition` column**, mandatory per finding, mechanically checked by a new gate arm (A6). |
| The understated-plan residual | **No declared-vs-actual arm ships.** One arithmetic arm is added that is *not* that comparison; see § The residual, honestly bounded. |

Three further decisions the spec did not assign but which the round-2 findings force, recorded here
because each one changes what a number in this design means:

| Decision | Answer |
|---|---|
| What a "changed line" counts as, on both sides | Per file, `max(added, removed)`, summed. A modified line counts **once**. § The counting basis. |
| How the round's own change is isolated | A temp-index **tree** baseline, recorded as one sha in the plan header. § The baseline. |
| Whether the gate script is a sync-group member | **Yes**, named on the anchor row — as is `docs/templates/progress-format.md`, on the same reasoning. Predicted derived-member count **40**. § Naming the gate script on the anchor row. |

### Why the plan lives in the progress file

The spec's only hard requirement is "a file on disk, because the gate must read text". The progress
file satisfies it and nothing else has to be invented. Measured cost of the alternative — a separate
`ai-docs/plans/<base>.fixplan.md` — is five additional registration sites, each a place to drift:

1. `.gitignore` (this repo) **and** `templates/project/gitignore.snippet`, which is the same
   byte-mirror obligation `AGENTS.md § Project-specific conventions` already records for
   `ai-docs/learnings/README.md`. Verified: the snippet is the file `scaffold.sh:85-94` appends to a
   consuming project's `.gitignore`, so a line missing there ships an un-ignored artefact to every
   consumer.
2. `docs/agents-method.md § Agent Docs` — a new artefact row.
3. `docs/agent-docs-index.md` — the verbose body of that row (`docs/agent-docs-index.md:91-95` is the
   existing `*.progress.md` row).
4. `skills/pr-merged/scripts/cleanup-progress.sh` — deletion on merge, otherwise the artefact
   outlives its task.
5. `docs/templates/progress-format.md` — still needed, because the plan references the round the
   findings table defines.

The progress-file section needs only (5), and even that is an *extension* of an existing pattern
rather than a new one: `docs/templates/progress-format.md:78` already specifies a per-round
`## Fix cycle round M` section for the post-push fix round, and `:119-123` already specifies how a
round-numbered section is appended and anchored. Three existing facts carry over for free — the file
is gitignored (`progress-format.md:7`), it is deleted by `/pr-merged`
(`progress-format.md:130`), and the round number is already derived by counting `## Self-Review`
sections (`agents/self-review.md:30`).

The cost of this choice is that the gate must select a section out of a larger file rather than read
a whole one. That is one parse function and three test legs (§ Test Design, T1-R), and it buys
removal of five drift sites.

**Rejected:** a committed plan. Nothing downstream reads it after the round, the information is fully
recoverable from the diff and the findings table, and committing it would put a disposable artefact
into `ai-docs/plans/done/` forever.

### Why two agent files

`agents/` has one role per file throughout (`design` / `design-review`, `review-findings` /
`self-review`). The two roles here differ in every dimension that matters:

| | `fix-scout` | `fix-apply` |
|---|---|---|
| Tool posture | reads code, writes one section | edits arbitrary files, runs gates |
| Failure mode | a wrong plan (caught by the gate) | a wrong edit (caught by the `applied` arms) |
| Forbidden | editing anything but its plan section | planning, re-deriving findings, routing |

A single file with a mode switch would put both tool postures and both forbidden-lists in one body and
rely on prose dispatch to keep them apart — the shape that degrades first under truncation. Two files
also keep each one far below the instruction-file size axiom; the largest existing agent file is
`agents/self-review.md` at 32,031 chars, which is already in the axiom's warning band.

**Name-clash check (AGENTS.md § Naming).** `fix-scout` and `fix-apply` appear nowhere in
`docs/claude-tools-hierarchy.md` §§1a/1b/2a/3a/3b — grepped for `scout`, `fix-plan`, `fixer`, `apply`,
zero hits — and nowhere in this session's available-skills list. §2a's embedded subagent types are
`claude`, `claude-code-guide`, `Explore`, `general-purpose`, `Plan`, `statusline-setup`; no overlap.
Both names get a row in § Project-defined Subagents.

### Why one script rather than several — three verbs when written, four since round 9

`scripts/check-references.sh` is the cited precedent and it carries six labelled sub-checks (L1–L6) in
one file. More important here: **AC5 requires one definition of the threshold.** When this was written it
required that definition to feed **two** firing sites; **since round 9 there is ONE** — the pre-apply gate —
because the post-apply arm that was the second site is withdrawn. The argument survives the change intact,
and is stronger in the one-site form: if the gate were prose in `SKILL.md`, the number would exist twice —
once in the script, once in the instruction text — and nothing could stop them drifting. Keeping the one
firing site in the script makes AC5 structural rather than aspirational: there is literally one assignment,
and a test can assert that no instruction file contains the literal at all (§ Test Design, T1-E; the
gate form was run both ways, see below). **The phrase "both firing sites" here is a record of the two-site
era, not a live claim.**

The verbs — three as designed, four since round 9:

| Verb | Called by | Does |
|---|---|---|
| `baseline <progress-file>` | orchestrator, once at round start | appends the round's plan stub carrying `**round_base:**`, and prints the sha |
| `plan <progress-file>` | orchestrator, after the scout returns | arms A1–A6 over the latest `## Fix Plan (Round N)` section |
| `applied <progress-file>` | orchestrator, after the fix agent returns, once per micro-loop attempt | **arm (a) only** — arm (b) is deleted (round 9) — against the `round_base` it **reads from that section** |
| `record <progress-file> <iterations> <cost_tool_calls> <answer>` | orchestrator, once when the micro-loop closes | appends one `kind: "verdict"` line to the sibling ledger carrying the loop's iteration count, its cost in orchestrator tool calls, and the bounded question's answer as `question_answer` (AC24). **The one point of mechanical control over AC23's vocabulary:** anything but `MATCH` / `DIVERGE` is refused with `die 2` before anything is written |

> **This table is the canonical verb map an implementer reads, so both corrections land here rather than
> only in the amendment section:** `applied` ran "arms (a) and (b)" until round 9 deleted arm (b), and the
> script has **four** verbs now, not three. `USAGE` at `check-fix-plan.sh:76` carries the same list and
> moves with it.

**`applied` takes no baseline argument, and that is MINOR 3's fix.** A `--since <rev>` parameter lets
the party doing the measuring choose what it measures against — the same defect as trusting the fix
agent's self-reported size, or letting the applying party be the only one asserting the write landed.
The baseline is written by `baseline` into the section that `plan` then gates, so by the time `applied`
runs, the value has already passed a gate and no caller can substitute a later one. `applied` exits
**2 — cannot run** when the section carries no `round_base`, or one that does not resolve to an object
in this repository: a missing baseline silently measuring nothing is precisely the empty-output failure
`docs/agents-method.md § Tooling` warns about, and rc 2 is this repo's "could not run, which is not a
pass".

**Path and name.** `skills/task/scripts/check-fix-plan.sh`, invoked as
`"${CLAUDE_SKILL_DIR}"/scripts/check-fix-plan.sh` per AGENTS.md § Project-specific conventions.
Precedent: `skills/report-defect/SKILL.md:82`.

### The baseline — MAJOR 1, and why three candidate primitives were discarded

A Step-11 round does **not** commit: `skills/task/reference.md § Step 11` ends the round with gates, a
progress update and a return to Step 10. So on round 2 the working tree already carries round 1's
edits, and `git diff HEAD` would charge them to round 2. Worse, `/task` does not commit until Step 12,
so **every file the task itself created is untracked during every Step 11 round.**

**The defect round 1 shipped, re-measured on this branch today:**

```
git ls-files -o --exclude-standard -z | xargs -0 -n1 wc -l
     737 ai-docs/plans/2026-10-06-scouted-fix-plan.design.md
     277 ai-docs/plans/2026-10-06-scouted-fix-plan.spec.md      ->  1014 lines
```

Round 1 counted untracked files by summing `wc -l` over that whole set, with no baseline. So before a
single line of implementation exists, arm (b) would report 1014 against a threshold of 150, and arm (a)
would name both plan artefacts as files the plan did not mention. The figure also *grows as the task
writes* — `design-review` measured 732, this revision measured 772 when it began and 1014 when it
ended, and every one of those deltas is this document — which makes it a moving false positive rather
than a fixed one, and makes any single recorded value stale on sight.

The leak reaches tracked files too. `docs/corrections-log.md`'s in-flow capture exception permits
appending `ai-docs/learnings/<username>-<branch>.md` during Steps 8–12, and that file is **not**
gitignored, so an entry written mid-round would be charged to the fix agent.

Three primitives were tried. The first two are recorded because each looks correct and is not:

| Candidate | Measured outcome |
|---|---|
| `git stash create` | Scopes **tracked** files exactly — round-1 edits correctly excluded, tree and `git status` untouched. But untracked files are absent from `--numstat` entirely, so the whole defect survives. On a clean tree it prints nothing at rc 0, needing a fallback. |
| `git stash create -u` | **Does not help, and `-u` is silently accepted rather than rejected.** Measured both ways: with a **clean** tracked tree and untracked files present it returns rc 0 and **empty**; with a **dirty** tracked tree it returns a sha. In both cases the untracked files stay untracked and are absent from the diff, so the flag changes the baseline's emptiness and nothing else. A flag that is accepted, appears to work on a dirty tree, and silently does not do what its name says is worse than one that errors. |
| `git add -N …` then `git stash create` | **Fails outright:** `error: Entry 'round1-untracked.txt' not uptodate. Cannot merge. / Cannot save the current worktree state`, rc 128, **empty output**. An empty baseline substituted into `git diff ""` compares against nothing, so this candidate's failure mode is a silent pass. |

**What ships: a temp-index tree baseline.** Build a throwaway index from `HEAD`, `git add -A` into it,
and write a tree. `GIT_INDEX_FILE` redirects every write away from the real index, so nothing in the
repository is modified; only blob and tree objects are created, exactly as `stash create` does.

```sh
snap() {                               # one sha, tracked and untracked alike
  local idx sha; idx=$(mktemp)
  GIT_INDEX_FILE="$idx" git -C "$ROOT" read-tree HEAD || { rm -f "$idx"; return 2; }
  GIT_INDEX_FILE="$idx" git -C "$ROOT" add -A        || { rm -f "$idx"; return 2; }
  sha=$(GIT_INDEX_FILE="$idx" git -C "$ROOT" write-tree)
  rm -f "$idx"                         # never the last command: its rc is not the answer
  [ -n "$sha" ] || return 2
  printf '%s' "$sha"
}
# baseline:  round_base=$(snap) || die 2 "could not compute a baseline, which is not a pass"
# applied:   git -C "$ROOT" diff-tree -r --numstat "$round_base" "$(snap)"
```

**The guard is not decoration, and the unguarded version had the defect it was written to avoid.**
Measured: with `read-tree` pointed at a bogus rev, the first draft of this function — whose last
statement was `rm -f "$idx"` — returned **rc 0 and empty output**, because a function's status is its
last command's and `rm` succeeded. That is simultaneously the silent-empty-baseline shape used to
disqualify candidate 3 above, and the `out=$(fn)` hazard `docs/agents-method.md § Tooling` names. The
guarded form returns **rc 2**. So: capture the sha, remove the temp index, *then* test the sha.

An earlier draft of this section claimed `write-tree` "cannot return empty on a valid repository". That
was an unverified absolute and it is false in the degenerate case above; it has been removed rather than
softened. What does hold, measured, is the containment downstream: `diff-tree -r --numstat "" <sha>`
**hard-errors at rc 128** rather than reporting zero changed lines, so an empty baseline that somehow
reached the consumer would fail loudly — and `applied` independently exits 2 on a `round_base` that is
absent or unresolvable. Two guards and a loud consumer, because the failure mode is a silent pass.

Measured end to end, with a round-1 untracked file, a round-2 modification of it, a round-2 new file, a
tracked modification, and a gitignored progress file all present at once:

```
diff-tree -r --numstat $BASE $NOW
1	0	f.txt                      # tracked modification: exact hunk count
2	1	round1-untracked.txt       # charged its round-2 DELTA, not its 3 whole lines
2	0	round2-new.txt             # genuinely new in this round
                                   # notes.progress.md: ABSENT from both lists
git status --short -> " M f.txt" / "?? round1-untracked.txt" / "?? round2-new.txt"   # unchanged
```

Four properties, each measured rather than reasoned:

- **The round-1 leak is closed.** The round-1 untracked file is charged 2 added / 1 removed — its
  round-2 delta — instead of its whole 3 lines.
- **Deletions are counted, including of untracked files.** A separate probe deleted one tracked file
  (3 lines) and one untracked file created at baseline (4 lines): `0 3` and `0 4`, totalling 7 under the
  basis below. A deleted untracked file is invisible to every other candidate here.
- **Gitignored paths exclude themselves.** `git add -A` honours `.gitignore`, so the progress file —
  which this round writes to constantly — never enters either tree. No ignore-list entry needed, and
  no risk of the plan's own section being charged to the round.
- **Nothing is mutated.** The real index and `git status` were byte-identical before and after.

**The narrow in-round ignore list.** Two tracked paths remain legitimately editable mid-round and are
excluded by name: `ai-docs/learnings.md` and anything under `ai-docs/learnings/`. Measured with the
ignore list applied to the deletion probe: `changed_lines=7 files=2 ignored=1 binary=0` — the two
added learning-log lines were excluded and the exclusion was **reported in the verdict**. That last
part is the point: a silent ignore list grows, so the count of ignored paths is printed beside the
total, the same discipline `run-checks.sh` applies to its `EXEMPT_CHECKS` prose comment. The list is
two entries and the design fixes it at two; an addition is a design change, not an implementation
detail.

**Binary files cannot be line-counted and are not silently zero.** Measured: `diff-tree --numstat`
emits `-` for both columns on a binary path. The gate counts such a path as 0 lines **and names it in
the verdict** (`binary=1`), so a number that cannot be right is never presented as if it were.

### The counting basis — MAJOR 2, and why arm (b) is redefined rather than the plan

Round 1 defined arm (b) as `numstat` added+deleted and never defined the declared side at all: the
column was headed "Expected changed lines" and the total was "the sum of the column below". Two
quantities, one threshold.

**Measured, on the diff shape this repository produces most — rewriting instruction prose:**

```
# 100-line file, 80 existing lines rewritten, nothing added or deleted on net
git diff --numstat $BASE  ->  80	80	f.txt      ->  added+removed = 160
```

So a round that changes 80 lines would be reported as 160 and escalate. Arm (b) would effectively fire
at about 75 modified lines against a threshold the user set at 150. That is not a rounding error in the
mechanism; it defeats the decision § Key decisions records — "the actual total against that same
absolute number" — and it poisons the calibration data AC5 exists to accumulate, because a
declared-versus-actual spread measured in two different units is not a spread.

**The basis, defined once and binding on both sides: per file, `max(added, removed)`, summed across
files. A modified line counts once.** A new file contributes its line count; a deleted file contributes
the line count it had at baseline; a binary file contributes 0 and is named.

**A rename counts as a delete plus an add — so an N-line rename counts 2N, and a scout declares 2N.**
This is the one case where the basis contradicts its own "a changed line counts once" principle, so it
is stated explicitly rather than left to be inferred. Measured against the shipped command, which does
**not** pass `-M`:

```
git diff-tree -r --numstat $BASE $NOW      # a 10-line file, purely renamed
0	10	ren_from.txt
10	0	ren_to.txt                         -> max-sum = 20 = 2N
```

**Omitting `-M` is deliberate, and the reason is arm (a) rather than the count.** With `-M` the same
trees collapse to a single row whose path field is `ren_from.txt => ren_to.txt` — measured — and arm (a)
matches diff paths against the plan's `Target` column, so that composite would match no planned path
and every rename would be reported as an unplanned file. Two plain paths are matchable; one composite
path is not. The 2N over-count is the price, and it errs in the safe direction: it escalates to a human
who can see the rename, where an under-count would pass silently.

**The trap this cost me, recorded so it is not repeated.** My first measurement of this used
`git diff --numstat --cached` and reported `0 0` with the collapsed path — because `git diff` is
porcelain and has rename detection **on** by default, while `git diff-tree` is plumbing and has it
**off**. Same question, opposite answer, and only the plumbing form is what ships. Probe the command
under test, not its porcelain sibling.

**This is a redefinition of arm (b), and the spec's permission for that is used deliberately** (§ Open
questions: "Redefining arm (b) instead is permitted, but then say so"). Saying so: the alternative the
review suggested first — adopt the VCS added+removed basis on both sides — is self-consistent and
cheaper to implement, and it was rejected on a behavioural ground rather than an aesthetic one. Under
it, 150 would mean 75 rewritten lines, so ordinary prose-editing rounds in this repository would
escalate to the user as a matter of course. An escalation that fires on the normal case stops carrying
information, and the user chose 150 for "total lines the plan expects to change" — a phrase that reads
on a rewritten line as one line, not two. `max(added, removed)` is also how a scout naturally
estimates: "about twelve lines in this file" means twelve lines will look different.

Verified against the probes above: 80 rewritten → `max(80,80)` = **80**, under the threshold; the
deletion probe → `max(0,3) + max(0,4)` = **7**; the mixed probe → `max(1,0) + max(2,1) + max(2,0)` =
**5**.

**Where the basis is stated.** **Four** surfaces, not three, and the claim is now stated as what it
actually is — *each surface states the basis, and the four statements must not contradict each other* —
rather than as "all carry the same sentence", which was loose and measurably false:

| Surface | Role | Status, re-derived this round |
|---|---|---|
| `skills/task/scripts/check-fix-plan.sh` header | the implementation | full basis |
| the plan's column heading, `Expected changed lines (max(added,removed))` | the declared side, carried with every plan | the formula only, by design — it is a column heading |
| `agents/fix-scout.md:73` | the party that estimates | full basis, but says a deleted file contributes "the line count it **has now**" where the gate measures it **at the baseline** |
| `docs/templates/progress-format.md:143` | the section's schema | **drops the new-file, deleted-file and binary clauses entirely** |

Two gaps, both found by `design-review` rather than by me, and both worth closing rather than
re-describing. `progress-format.md:143` should carry the three dropped clauses, and
`fix-scout.md:73` should say *at the baseline*: the two readings are equivalent at plan time, because
the file still exists when the scout estimates, but a scout reasoning about a file it intends to delete
has no reason to know that and the gate's wording is the authoritative one.

**Why these two text fixes ride with the Design Amendment rather than becoming a new subtask.** They
are prose in instruction files, which is the class the amendment is already touching, and the
distinction drawn for subtask 1a holds in the other direction: a *behavioural* change must be visible
on its own surface, while a sentence that must agree with three other sentences is exactly a
propagation edit and belongs with them. The plan column is deliberately left as the formula alone —
a heading carrying four clauses stops being a heading.

### The gate: arms and verdict format

Verdict goes to stdout, one header line plus one line per arm:

```
check-fix-plan: verb=plan round=2 decision=REFUSE reason=anchor-unresolved threshold_changed_lines=150 declared_changed_lines=37
  A1 anchor-resolution    FAIL  skills/task/SKILL.md:9999 does not resolve (file has 222 lines)
  A2 spec-amendment       pass
  A3 design-amendment     pass
  A4 size                 pass  declared 37 of 150
  A5 verification-named   pass  bash scripts/run-checks.sh
  A6 finding-coverage     pass  3 open findings, 3 dispositions
```

**Decision vocabulary** — four outcomes, because the orchestrator's next move differs for each:

| `decision=` | Next move | AC |
|---|---|---|
| `PASS` | spawn `fix-apply` | — |
| `REFUSE` | hand the verdict back to `fix-scout` for a rewrite; cap 3 rounds, then surface to the user | AC1, AC6 |
| `ROUTE-SPEC` | STOP; Spec Amendment recipe; **no fix agent this round** | AC2 |
| `ROUTE-DESIGN` | STOP; Design Amendment recipe; **no fix agent this round** | AC3 |
| `ESCALATE` | surface to the user with the declared total and the threshold | AC4 |

**Exit status: `0` for `PASS`, `1` for every other decision, `2` for cannot-run.** Deliberately *not*
one rc per decision. Two reasons. The repo convention is 0/1/2 across `check-references.sh`,
`check-readme-update.sh` and `check-release.sh`. And `docs/agents-method.md § Tooling` warns that a
status describing a property of the input must not be chained on — so the skill text instructs the
orchestrator to **read the `decision=` token**, with rc serving only as "not PASS". Any non-zero stops
the fix agent, which is the safe direction for the three stop-lanes.

**CORRECTED — round 9.** This paragraph read: "`threshold_changed_lines=150` appears in the header of
**both** the `plan` and the `applied` verdict, read from the one constant. That is AC5's 'neither site's
reported value can drift'." **Both halves are now false, and the second was the dangerous one**: followed
literally it leaves the measuring verb reporting a quantity it no longer fires on, which is the shape a
later reader mistakes for a comparison that is still happening.

**What holds now: `threshold_changed_lines=150` appears in `plan`'s header and NOWHERE ELSE** — not in
`applied`'s, not in `baseline`'s. AC5 has exactly ONE firing site, the pre-apply gate, so one reporting
site is what "no site reports a value other than the one it fired under" means here. **The anti-drift
property is per SITE, not per VERB**, and the rule survived both of this criterion's earlier drafts intact
because it was never about how many sites there are. The implementation therefore **removes** the field
from the other two verbs' headers; leaving it is the second-copy drift the criterion exists to prevent.

**Arm order is load-bearing, and the full order is: anchor resolution → amendment routing → size. The
FIRST failure decides.** An earlier draft of this section fixed only the second half of that order
("routing is evaluated before size") and left the anchor arm's position unstated — which is how the
ambiguity reached implementation. It is stated in full here so the next reader does not re-derive it.

| Pair | Winner | Why |
|---|---|---|
| unresolvable anchor **vs** amendment-naming | **REFUSE**, never route | Routing is the **expensive** path: it stops the work, asks the user, and re-runs the spec-writer, the design and the design review. Starting all that on the strength of a citation that does not exist is the worse outcome — and a plan whose anchors were never opened is a prediction wearing a plan's clothes, which is the defect the whole mechanism exists to catch. |
| unresolvable anchor **vs** over threshold | **REFUSE**, never escalate | Same reason, cheaper consequence: an escalation spends a human's attention on a size judgement about a plan that cannot be trusted to describe its own targets. |
| amendment-naming **vs** over threshold | **ROUTE**, never escalate | AC2/AC3 say such a plan "never reaches the fix agent", and an escalation the user waves through would send it there. |

**What the precedence does *not* decide.** The safety property all three criteria share — such a plan
never reaches the fix agent — holds under **every** order, because each of these outcomes is non-`PASS`
and only `PASS` admits the fix agent. So the order chooses which lane the orchestrator takes, not
whether a bad plan can be applied.

**And the author is shown every fault regardless, which is better than the precedence alone implies.**
Measured against the shipped gate: each arm prints its own verdict line whether or not it wins the
decision, so a plan that is both unanchored and spec-naming reports `A1 … FAIL` *and* `A2 … FAIL` while
the header reads `decision=REFUSE reason=anchor-unresolved`. The precedence picks which fault is *acted
on*; it suppresses no diagnosis.

```
check-fix-plan: verb=plan round=1 decision=REFUSE reason=anchor-unresolved threshold_changed_lines=150 declared_changed_lines=12
  A1   anchor-resolution    FAIL  finding 1: docs/workflow.md:9999 does not resolve (file has 40 lines)
  A2   spec-amendment       FAIL  finding 2 targets ai-docs/plans/t.spec.md:4
  A3   design-amendment     pass
  A4   size                 pass  declared 12 of 150
```

**No code change is owed.** Re-derived in source rather than taken from a report:
`skills/task/scripts/check-fix-plan.sh:197` defines `decide()` as first-wins
(`[ -n "$DECISION" ] && return 0`), and the arms fire in the required order — A1 at `:303`, A2 at
`:306`, A3 at `:309`, A4 at `:318`/`:321`. **Re-derived this round, and the A4 citation is corrected:**
an earlier draft cited A4 at `:322`, which is its `decide ESCALATE`, not its `arm` emission — A4 splits
across two FAIL branches (`:318` for the declared-sum mismatch, `:321` for the overrun) with the
`decide` calls on `:319` and `:322`. Each `arm … FAIL` is emitted **before** its `decide`, which is what
makes T1-Y's requirement — a superseded arm still shows its own FAIL line — satisfiable by shipped
code. What *is* owed is the discriminating test leg; see § Test Design, T1-Y.

Arms over the latest `## Fix Plan (Round N)` section:

| Arm | Refuses / routes when | AC |
|---|---|---|
| A1 anchor-resolution | any `Target file:line` or Arm-A anchor names a missing file, or a line beyond the file's line count | AC1 |
| A2 spec-amendment | any target path matches `ai-docs/plans/**/*.spec.md` (active or `done/`), **or** any `Disposition` is `amendment: spec` | AC2 |
| A3 design-amendment | same for `*.design.md` / `amendment: design` | AC3 |
| A4 size | `declared_changed_lines` ≠ the column sum → `REFUSE`; sum > threshold → `ESCALATE` | AC4 |
| A5 verification-named | `**verification:**` absent or empty | AC6 |
| A6 finding-coverage | an `⬜ Open` finding number from the round's Self-Review table is missing from the plan, appears twice, or carries an empty / out-of-vocabulary `Disposition` or an empty Arm-A cell — reason `finding-coverage`. **Plus the converse (subtask 1a): a plan row whose `#` matches no `⬜ Open` finding in the round's table — reason `plan-row-unmatched`.** | AC19, AC7 |

A2 and A3 each have **two independent detections** — the target path and the declared disposition —
because a scout that mislabels an amendment as a `fix` must still be caught by the path, and a scout
that labels it correctly while naming a non-plans path must still be caught by the label. Each
detection gets its own test leg. **The leg count this paragraph used to derive is SUPERSEDED, and the
arithmetic is corrected rather than left to be rediscovered:** it read that AC2/AC3 ask for "one test
per arm", so two detections per arm meant four legs. Those criteria now **mandate three legs per arm**
and name "one test per arm" as insufficient, because the path detection is narrowed to a row that
proposes an edit and the third leg is the one that asserts a no-edit row does **not** route. So: six
legs across the two arms — T1-B and T1-C carry the first two on each, T1-ZK carries the third on both.
The first sentence above stands unchanged and is now the narrowed path half's own justification: a scout
that mislabels an amendment as a `fix` is still caught by the path.

`applied` arms — **one arm now, not two:**

| Arm | Reports a finding when | AC |
|---|---|---|
| (a) unplanned-file | a path in `diff-tree -r --name-only <round_base> <now>` is absent from the arm's **allowed set**, after the in-round ignore list is applied. **The allowed set is the targets of `fix` rows only** — see below | AC7 |

> **ARM (b) IS DELETED — round 9, and it is the record of two forms neither of which survives.** It stood
> here first as "(b) actual-overrun | the summed `max(added, removed)` over that same diff, after the
> ignore list, exceeds the threshold", with a sample verdict reading
> `decision=FINDING reason=actual-overrun threshold_changed_lines=150` and `(b) actual-overrun FAIL 204 of
> 150`. **That form shipped and was retired on evidence** — one round declared 54 lines and landed 743,
> producing a verdict nobody could act on. It was then respecified as a **router** on declared-vs-actual
> agreement within a tolerance, with `agreement=within|diverged` in the header and an `ASK` arm status;
> **that form never shipped** and is withdrawn too, because the like-for-like subtraction it rested on does
> not come out equal on honest input. Both are kept here as the record of what was specified; **neither is
> what the implementation builds.** What the implementation builds is: no arm (b), no `actual-overrun`
> token, no tolerance, no `agreement=` field, no `declared_comparable_lines=`, and no post-apply
> arithmetic of any kind. The question in § the micro-loop replaces all of it.

`applied` therefore emits **one** decision from **one** arm, over the two trees of § The baseline:
`decision=FINDING reason=unplanned-file` at rc 1 when a path no row named was touched, `decision=OK` at
rc 0 otherwise, in both cases carrying `ignored=<k> binary=<m>` so nothing is excluded invisibly, plus the
`excluded-in-round` and `binary-no-line-count` lines when they apply.

`applied`'s header therefore reads:

```
check-fix-plan: verb=applied round=2 decision=FINDING reason=unplanned-file actual_changed_lines=204 ignored=1 binary=0
  (a) unplanned-file   FAIL  docs/other.md
  excluded-in-round    1     ai-docs/plans/2026-10-06-x.design.md
```

> **`actual_changed_lines=` STAYS in the header, and that is deliberate rather than an oversight.** Nothing
> compares it against anything any more, so it decides nothing — but it is the figure the micro-loop's
> question is read against by a human. **It is NOT one of the figures AC24 accumulates for the retirement
> rule** — those are the loop's iteration count, its cost and the bounded question's answer, and this verb
> writes no verdict row at all; `record` writes it. The field is a **measurement**, not a verdict.
>
> **`threshold_changed_lines=` is REMOVED from `applied`'s header and from `baseline`'s, and appears only
> in `plan`'s.** AC5 now has exactly ONE firing site, so printing the number where nothing fires on it
> would reinstate the second-copy drift the criterion exists to prevent — and a verb that reports a
> quantity it does not use is the shape a later reader mistakes for a comparison.
>
> **THE GENERAL RULE THESE TWO DECISIONS SHARE IS RESTATED, because the form it first had contradicted the
> second decision one paragraph below it.** It read: "a reported number that no arm fires on is safe; a
> number an arm fires on without reporting it is not." By that rule the threshold field would be safe to
> keep — and it is being removed. Both decisions are right; the rule was the wrong generalisation of them.
>
> **The discriminator is LIMIT versus MEASUREMENT, not whether an arm fires:**
>
> | Kind | Printed where nothing enforces it | Why |
> |---|---|---|
> | a **limit** — a value a decision is taken against (`threshold_changed_lines`) | **unsafe, remove it** | it has a single definition elsewhere, so a second printing is a second copy that can drift from it, and a limit shown beside a figure reads as a comparison that is still happening |
> | a **measurement** — a value read off the tree (`actual_changed_lines`) | **safe, keep it** | it is computed where it is printed and has no definition elsewhere to drift from; there is no second copy to be wrong |
>
> So: `actual_changed_lines=` stays because it is a measurement, and `threshold_changed_lines=` goes from
> the two verbs that do not fire on it because it is a limit. The rule that survives is **"a limit is
> printed only where it is enforced; a measurement is printed wherever it is taken"** — and it reaches
> both decisions without contradicting either.

**Arm (a)'s allowed set is the targets of `fix` rows only — Design Amendment, user-approved.** The
shipped expression takes the `Target` of *every* row:

```
skills/task/scripts/check-fix-plan.sh:401   (re-derived this round)
  planned=$(table_rows "$sec" | awk -F"$SEP" '{ t = $4; sub(/:[0-9]+$/, "", t); print t }')
```

No filter on the disposition cell, which is field `$3`. So a plan carrying `object: <reason>` or
`amendment: spec` / `amendment: design` rows **pre-authorises those rows' target files** — and those are
precisely the rows `fix-apply` is forbidden to touch. A fix agent that edited one anyway would not be
reported. The remedy is one expression: admit a row only when its disposition is exactly `fix`, the
token the vocabulary check at `:299` validates (`fix|'amendment: spec'|'amendment: design'` /
`'object: '?*`).

**The rule, stated so it does not have to be re-derived: a row the fix agent may not act on must not
widen what the fix agent is permitted to touch.** Permission comes from the disposition, not from the
mere presence of a target.

**This is the same failure shape as the A6 converse closed in subtask 1a, and that is now twice in one
mechanism.** Both are *a permission derived from the wrong side of a mapping*: A6's converse let a row
with no finding behind it authorise a file, and this lets a row with no mandate behind it authorise a
file. In both cases the plan's `Target` column was read as "files in play" when the thing it actually
licenses is narrower. The pattern is the durable lesson and it is now in § Test Design's standing
rules: **when a permission is derived from a table, check what the table admits that the permission
never meant to cover.**

**The `amendment:` half is NOT moot at runtime, and an earlier draft of this paragraph said it was.**
It claimed such a plan routes and therefore `applied` is never reached for that round. That is false and
permanently so: `skills/task/SKILL.md:173-174` mandates resuming Step 11 after the amendment, and
`do_baseline` refuses a second stub (`check-fix-plan.sh:217`), so `applied` runs against a pre-amendment
baseline on every amendment-then-resume round. The full correction, the remedy and its legs are in
§ GAP 1 at the top of this document. The allowed set is stated as a property of the arm regardless —
relying on another arm's behaviour for this one's correctness is the conjunction trap § A6's converse
argues against, and here that reliance was not merely fragile but factually wrong.

**Table-cell parsing — MINOR 5.** Two columns hold free text: `object: <reason>`, and the Arm-A cell,
which by design quotes a sentence out of an instruction file. In this repository such a sentence is
routinely a table row, so it arrives full of `\|`. The gate splits columns positionally, so an escaped
pipe shifts every later field. Round 1 left this unhandled. The fix: **normalise `\|` to a placeholder
before splitting and restore it after**, so a cell round-trips whole. Two reasons this cannot be left
to fail-toward-refusal, which is what it does today: the Arm-A cell is the **last** column, so a stray
pipe there truncates the quoted sentence silently rather than shifting anything — and that cell is
exactly what AC10's post-fix re-read depends on. There is no assertion to copy here; the two existing
gate scripts extract backticked tokens instead of splitting columns, so this is the first
column-splitting parser in the tree and T1-P is its first positive control.

### The plan format the scout writes

`baseline` writes the stub — the heading and the three header fields. The scout fills the table. That
split matters: the orchestrator records nothing by hand, so the baseline sha cannot be mistranscribed,
and a round with no stub is a round with no plan, which A6 then refuses by construction.

```markdown
## Fix Plan (Round N)

**round_base:** <tree sha, written by `check-fix-plan.sh baseline`; never edited by the scout>
**verification:** <the command(s) this round expects to re-run>
**declared_changed_lines:** <integer — the sum of the column below>

| # | Disposition | Target file:line | Expected changed lines (max(added,removed)) | Arm A — artefact sentence at stake |
|---|---|---|---|---|
| 1 | fix | docs/workflow.md:215 | 12 | none |
| 2 | object: the cited form is the documented one | skills/task/SKILL.md:135 | 0 | none |
| 3 | amendment: spec | ai-docs/plans/<x>.spec.md:40 | 6 | `ai-docs/plans/<x>.spec.md:40` — "<quoted sentence>" |
```

`#` is the finding number from the round's `## Self-Review (Round N)` table, which is what lets A6
compare the two sets. `Disposition` is a closed vocabulary: `fix`, `object: <reason>`,
`amendment: spec`, `amendment: design`. The counting basis rides in the column heading rather than in
prose beside it (§ The counting basis), and a literal `|` inside either free-text column is written
`\|` and round-trips through the parser's placeholder normalisation.

**This is the answer to the objected-findings open question.** The disposition is carried per finding
and mechanically required, so a round whose every finding is objected to still produces a plan — it
produces one whose every row says `object:` and whose declared total is 0. The fix agent is told to
apply **only** `fix` rows. AC19's "a reader cannot find a licence to apply a fix in the orchestrator's
own context" then has a mechanical companion: a round with no plan section fails A6 by construction,
because there is no section to parse.

### Interpretive calls — challenged, as asked

**1. The per-finding Arm A judgement carried as plan text.** *Endorsed, but only with a
strengthening.* As the spec states it, the orchestrator trades re-deriving the finding for trusting
the scout's judgement — a swap of one unverifiable act for another. The fix is to make the Arm A cell
**quote the sentence**, with its `file:line`, rather than record a verdict about it. Three things
follow, none of which hold for a bare verdict: A1 already resolves that anchor, so a fabricated
citation is refused mechanically; the orchestrator's decision is then taken on a quoted sentence it
can confirm in one `grep` rather than on an opinion; and AC10's closing gate — re-read the cited
sentence post-fix — becomes a single batched `grep` instead of a re-derivation. A6 refuses an empty
cell, so `none` must be written deliberately. With that, the call is sound; without it, I would have
flagged it as the weakest load-bearing element in the spec.

**2. The narrower propagation reading** (siblings record that the mechanism exists in the main flow,
does not apply there yet, and name the follow-up issue). *Endorsed.* `docs/propagation.md:13` says
siblings "must receive the corresponding change", not the identical one, and a divergence note is a
corresponding change. The CREATE obligation this call originally surfaced is now in the spec
(constraint 6), and the group's membership is settled in § Naming the gate script on the anchor row.

**3. Deferring the "touches a public signature" arm.** *Endorsed, with the reasoning restated because
it is stronger than the spec puts it.* A method file may not name a language
(AGENTS.md § Project-specific conventions), and detecting a public signature requires one. There is no
language-free substitute: arm (a) catches an *unplanned file*, which is a different property, and
nothing in a plan's text distinguishes a signature change from any other edit. Deferral is correct.

**4. The owed measurement in `ai-docs/context.md` § Open questions.** *Endorsed, verified
independently.* All four live entries are ticket-keyed and of exactly this shape — `GH-10:124`,
`GH-11:126`, `GH-72:128`, `GH-75:174`. `GH-72` is the same debt class, down to recording the value a
verdict fired under so the calibration arrives on its own. And the register is profile, not method,
which is where one project's measurement debt belongs.

### The residual, honestly bounded

The spec carries the understated-plan residual open on purpose and forbids both assuming the current
pair closes it and shipping a declared-vs-actual arm. **Neither is done here.**

A4 does add one arithmetic check — `declared_changed_lines` must equal the sum of the per-row column.
**This is not a declared-vs-actual comparison and it does not narrow the residual the spec describes.**
It catches only a plan whose own header contradicts its own rows; the spec's case — a plan whose rows
honestly sum to 20 while the fix lands 140 — passes A4 and passes the pre-apply gate. A4 exists because a
header that disagrees with its rows makes every other number in the verdict meaningless, not because it
closes a hole.

**CORRECTED — round 9, two sentences of this paragraph.** It also said such a plan "passes the post-apply
arm": there is no post-apply arm, and under the micro-loop 20 declared against 140 landed **is** a diff that
does not match its plan, so the question is put against it. And it said the spread "starts accumulating the
moment both verdicts carry their threshold value, which is what AC5 ships" — **AC5 ships one firing site and
accumulates nothing.** The figures that accumulate are **AC24's**, in the sibling ledger, and they are the
loop's iteration count, its cost and the bounded question's answer rather than a spread.

What the pair guarantees is unchanged and is the only claim to make: **no round lands more than 150 changed
lines without a human seeing it** — now via the pre-apply cap on the declared total plus the unconditional
question, with no post-apply arithmetic.

### Size budget

Measured 2026-10-06 with `wc -c`: `skills/task/SKILL.md` **26,947**, `skills/task/reference.md`
**20,136**. Headroom to the 35,000 early warning is **8,053 chars**.

The split:

- **`SKILL.md` Step 11 gets the binding rule only** — the always-on sentence, the **five-beat** sequence,
  the decision table's routing column, the three non-delegable acts, and the **one** post-apply arm as
  a single sentence. Budget **≤ 2,000 chars net**, with the existing Arm A / Arm B AXIOM block
  retained unchanged.

  > **CORRECTED — round 9, and this one is consequential because it IS the budget the instruction-text item
  > implements.** It read "the four-beat sequence … and the two post-apply arms as one sentence each". The
  > round is **five** beats now (mechanical check → question → re-fix → escalate-on-burned-cap → review) and
  > there is **one** post-apply arm. **The net budget does not move**: one arm sentence is dropped and the
  > beat list gains one, plus the cap, the attempt-line shape and the escalation's fixed shape — so the
  > implementer re-measures with `wc -c` against ≤ 2,000 rather than assuming the old split still fits, and
  > **a budget overrun is a finding to surface, not a licence to spend more**, since `SKILL.md` is
  > size-capped.
  >
  > **ROUND 10 adds two words to this budget and no more.** Both instruction files must name `MATCH` and
  > `DIVERGE` and agree on "exactly one of" (handoff item 17), which is a *substitution* at `SKILL.md:199`
  > and `reference.md:242` rather than new prose — the sentence already describes the output, it just does
  > not name the set. **Both files already carry the Step 11 text, so the `wc -c` re-measure is against the
  > SHIPPED sizes, not the ones recorded above**, which were taken before any of this landed. Re-derive
  > both; do not read the 26,947 / 20,136 pair below as current. **Measured now with `wc -c`:
  > `skills/task/SKILL.md` 31,550 and `skills/task/reference.md` 32,961** — so headroom to the 35,000 early
  > warning is **3,450** and **2,039** respectively. `reference.md` is the tighter of the two and is the file
  > the recipe grows in, so item 17's substitution there is the kind that must not become a paragraph.
- **`reference.md § Step 11` gets the recipe** — spawn prompts, the plan format, the full verdict
  vocabulary, the rewrite cap, the write-landed procedure. No cap needed; it is at 20,136 and is the
  established relief valve.

Subtask 4 re-measures both with `wc -c` and the figure is read, not assumed.

### What does *not* change

- **`agents/self-review.md`'s output contract needs no tightening.** Checked against what the scout
  consumes: the round-numbered section (`:156`), `File:line` (`:160`), severity (`:168`), `⬜ Open`
  status (`:162`), and the separate `Design Amendment trigger` callout (`:145-149`). Every field the
  scout needs is already specified. It still receives the Spec-Amendment group's corresponding change
  — one sentence noting that the Step 11 routing it describes now runs against a plan — but its
  contract is untouched, so § Technical constraints 7's conditional does not fire.
- **The Task/Design group does not fire — re-checked against this design, not inherited.** The spec's
  constraint 6 now states the negative and attaches a conditional: the row fires after all if the
  design routes either new agent through the handoff contract. It does not. Both agents are spawned by
  a direct `Agent` call inside Step 11; `/context-reset` is named nowhere in the new machinery; and
  Step 8's every-group handoff rule at `skills/task/SKILL.md:128` is untouched. The handoff contract
  this design *does* invoke is the one governing its own implementation — the `## Handoff plan` below
  — which is `/task`'s existing Step 8 mechanism used as-is, not a change to it. So `agents/design.md`,
  `agents/design-review.md` and `skills/context-reset/SKILL.md` receive nothing, and sweeping them
  would be three files touched with no corresponding change to carry.

### Naming the gate script on the anchor row — the tension, resolved by measurement

Two agents reached opposite conclusions with good reasons on both sides, so this was settled by running
it rather than by weighing the arguments.

**The readings.** Round 1 of this design declined to name `skills/task/scripts/check-fix-plan.sh` on
the anchor row, because replaying the live hook arms showed it matches none of the ten — the scripts
arm is root-anchored (`"$pd"/scripts/*.sh`) — so naming it would make
`check-propagation-arms.sh` report a `blocker`. `design-review` endorsed that. The spec-writer read
`docs/propagation.md` rule 5's "Name every member on the anchor row" as requiring it, and the amended
constraint 6 counts the gate script among the mechanism's files.

**Why the spec-writer's reading wins on the rule.** Rule 5 does not decide *who the members are*; it
decides the row's **shape** given a membership ("an anchor row naming every member, plus one
back-reference row — never one row per member"). The membership question is answered by rule 4: a group
exists because "a file that explains a mechanism in its own vocabulary is invisible to a sweep keyed on
the changed TOKEN". The gate script is the clearest instance of that in this change — the verdict
format is a contract the Step 11 text and both agent briefs depend on, expressed in shell rather than
in prose, so no token sweep over `.md` files reaches it. And there is direct precedent: the **Inspect
group** names `scripts/session-events.sh` and `scripts/loop-metrics.sh` for exactly this reason
(`docs/propagation.md:26` — "the skill names the inputs, the agent how to read them, the scripts
produce them — so a token sweep reaches at most one"). Declining to name our script would make this
group the one exception, and the reason would be implementation cost.

**Why the cost objection does not survive measurement.** Round 1 said naming it "would force a
blocker". Measured: it forces **one added glob pattern**, and the pattern is the mirror of one already
there. The reminder's arms live in a single `case` branch's pattern list, so adding to that list is
purely additive — no existing pattern can stop matching. Added `"$pd"/skills/*.sh` beside the existing
`"$pd"/skills/*.md` (in `case`, `*` spans `/`, which is why `skills/*.md` already covers
`skills/task/reference.md`), inserted the anchor and back-reference rows, and ran the gate:

```
check-propagation-arms: 39 derived members all fire, 13 controls all silent, 2 pre-fix matches all kept.
  ... fires   agents/fix-apply.md
  ... fires   agents/fix-scout.md
  ... fires   skills/task/scripts/check-fix-plan.sh
```

That run was against a **five**-path row and is kept because it isolates the cost of this one decision:
adding the gate script and its arm, and nothing else. The shipped row names seven paths and measures
**40** — enumerated below, and that is the figure AC17 is checked against.

All thirteen controls stayed silent — none of them sits under `$pd/skills/`, which is what bounds the
new pattern — and both pre-fix regression probes were kept, so the gate's own
"no path the pre-fix arms matched is silent" leg is intact. `scripts/test-check-propagation-arms.sh`
was then run against that same patched tree: **53 passed, 0 failed**, including its three legs
asserting the live files it reads were never written.

**Decision: the anchor row names the gate script.** The membership is enumerated below rather than
counted in prose — an earlier draft said "five members", which was stale from before the gate script
joined, and a prose count beside a derived figure is exactly the drift this gate exists to catch.

**The Scouted-Fix group's anchor row names these seven paths**, and the prediction is derived from this
list in place:

| # | Member | New derived token? |
|---|---|---|
| 1 | `skills/task/SKILL.md` *Step 11 scouted-plan sequence* (the anchor's left cell) | no — already a member |
| 2 | `skills/task/reference.md` | no — already a member (Human-register group) |
| 3 | `docs/workflow.md` § Spec-Amendment group | no — already a member (Spec-Amendment group) |
| 4 | `agents/fix-scout.md` | **yes** |
| 5 | `agents/fix-apply.md` | **yes** |
| 6 | `skills/task/scripts/check-fix-plan.sh` | **yes** — needs the one added hook arm |
| 7 | `docs/templates/progress-format.md` | **yes** — already matched by `"$pd"/docs/*.md`, no arm needed |

Baseline 36 + four new tokens = **40**. Members 1–3 contribute nothing because the gate's member set is
the set of distinct path tokens the whole table names, and those three are already named elsewhere in
it — which is why naming them here is free, and why naming them is still right: the anchor row is what a
reader consults, and a row that omits three of its own members to keep a number tidy is the "drifts a
member at a time" failure rule 5 warns about.

**Measured with that exact row in place: `40 derived members all fire, 13 controls all silent, 2
pre-fix matches all kept`**, with `docs/templates/progress-format.md` and
`skills/task/scripts/check-fix-plan.sh` both appearing in the fires list; and
`scripts/test-check-propagation-arms.sh` against the same tree, `53 passed, 0 failed`. A run reporting
anything other than 40 is a finding, not a new baseline.

**One implementation note the probe produced.** The probe patched `hooks/hooks.json` by loading and
re-dumping it with a JSON serialiser, which reformatted the whole file. The implementation must edit
the command string in place: the reminder's `command` is one very long line, and a round-trip through
any pretty-printer turns a one-pattern change into a whole-file diff that no reviewer can read.

---

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | Gate script + its suite, TDD. Three verbs; arms A1–A6 and (a)/(b); the single `THRESHOLD_CHANGED_LINES=150`; the temp-index tree baseline; the `max(added,removed)` basis; the two-entry in-round ignore list reported in the verdict; binary paths named not zeroed; escaped-pipe normalisation. Every arm shown red on a planted defect before its assertion is written. | `skills/task/scripts/check-fix-plan.sh`, `skills/task/scripts/test-check-fix-plan.sh` | — |
| 2 | Register both, in the directions the runner demands — they run opposite ways. `git add -N` both paths **first**; add `` `skills/task/scripts/test-check-fix-plan.sh` `` to AGENTS.md § Build & Test item 4's suite list; add `skills/task/scripts/check-fix-plan.sh` to `EXEMPT_CHECKS` in `run-checks.sh` **and extend the prose comment above it from two reasons to three** (`scripts/run-checks.sh:153`). Then `run-checks.sh --list`, reading the findings, and the full run, reading the counts. | `AGENTS.md`, `scripts/run-checks.sh` | 1 |
| 3 | The two agent files, plus their inventory rows and the clash check. `fix-scout` writes only its plan section and estimates on the stated basis; `fix-apply` applies only `fix` rows and may invoke no gated skill. | `agents/fix-scout.md`, `agents/fix-apply.md`, `docs/claude-tools-hierarchy.md` | — |
| **1a** | **Close A6's converse** — a plan row whose `#` matches no `⬜ Open` finding refuses, reason token `plan-row-unmatched`, plus its test leg T1-Z. An explicit, named amendment to subtask 1's artefact, carried out by Group B after Group A closed. Numbered `1a` rather than `7` **so the change is visible on the surface it actually touches**: it is a script change, and burying it in a step whose title is about rewiring instruction text is how a script change escapes review. Precedent for a non-sequential entry: `AGENTS.md § Build & Test`'s own check `5a`. | `skills/task/scripts/check-fix-plan.sh`, `skills/task/scripts/test-check-fix-plan.sh` | 1 |
| 4 | Rewire Step 11: binding rule in `SKILL.md`, recipe in `reference.md`, `## Fix Plan (Round N)` schema in the progress-file template. Re-measure both task files with `wc -c`. **Depends on 1a**, because the recipe enumerates the gate's refusal reasons and `plan-row-unmatched` is one of them. | `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/templates/progress-format.md` | 1, 1a, 3 |
| 5 | Propagation: create the **Scouted-Fix group** — anchor row naming the **seven** paths enumerated in § Naming the gate script on the anchor row, plus one back-reference row — in `docs/propagation.md`; add the `"$pd"/skills/*.sh` pattern to the propagation reminder's `case` list by **in-place string edit**, not a JSON round-trip; sweep the Spec-Amendment group, giving each excluded-loop sibling the divergence note naming the follow-up issue; update § Spec-Amendment group's *Fires in skill* table. Re-run `check-propagation-arms.sh` against the **predicted 40** and re-run its own suite. | `docs/propagation.md`, `hooks/hooks.json`, `skills/bugfix/SKILL.md`, `skills/project-review/SKILL.md`, `agents/self-review.md`, `docs/workflow.md`, `docs/templates/progress-format.md` | 4 |
| 6 | Delivery: the owed-measurement entry in `ai-docs/context.md` § Open questions keyed to its issue; the follow-up issue naming all three excluded sites; the `.claude-plugin/plugin.json` patch bump; the per-round displacement figure with its not-comparable note and the net-negative statement. | `ai-docs/context.md`, `.claude-plugin/plugin.json` | 1–5 |

**Subtask 5 is sequenced after 4 deliberately.** The group row must name the files as they end up, and
`check-propagation-arms.sh` derives its expected arm set from that table — writing the row before the
files settle means re-deriving it.

**Subtask 5 gained `hooks/hooks.json`.** That is the cost of naming the gate script as a member, and it
is one added glob pattern whose safety was measured (§ Naming the gate script on the anchor row): 40
members all firing, 13 controls still silent, 2 pre-fix probes kept, and the gate's own suite 53/0
against the patched tree.

> **Subtask 5's own index precondition: `git add -N` every path the anchor row names, before running
> the gate.** The gate resolves the bare filenames in the table against the **index**, so a member that
> exists on disk but was never staged is a member it cannot see — and the symptom is a count one short
> of the prediction, which reads exactly like a wrong prediction. This is not hypothetical: both agent
> contracts existed on disk while absent from the index, and only `git add -N` on the two `.md` paths
> brought all four new files into `git ls-files -s`. Subtask 2 carries this precondition for the
> shell-syntax gate; subtask 5 needs its own for the propagation gate, because the two gates derive
> different input sets from the same index and either can narrow silently.

> **`hooks/hooks.json` is EDITED by subtask 5 and is NOT a member of the group.** It is one of the
> gate's thirteen hardcoded **controls** — it appears in the measured run above as `silent
> hooks/hooks.json`, and the gate requires it to stay that way. Writing the anchor row from this
> subtask's file list would make the same path a derived member that must fire *and* a control that
> must stay silent, and the gate would then fail in both directions at once with a message explaining
> neither. The file list is what subtask 5 *touches*; § Naming the gate script on the anchor row is the
> membership. The same caution applies to `skills/bugfix/SKILL.md`, `skills/project-review/SKILL.md`
> and `agents/self-review.md`: subtask 5 edits them as **Spec-Amendment** siblings, and they are not
> Scouted-Fix members either.

## Handoff plan

`M = 7` → three groups of 3 / 3 / 1, **re-grouped in round 3** when subtask 1a was added. Per
`${CLAUDE_PLUGIN_ROOT}/agents/design.md § Rules → handoff-grouping`: grouping is required for every
`M ≥ 1`, non-terminal groups are exactly 3, the terminal group is within `1..3`.

- **Entry into Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. The orchestrator does not execute subtask 1
  in its own context — the handoff binds at the start of the **first** group too.
- **Group A:** subtasks 1–3 — the gate script with its suite, its registration, and the two agent
  files. Non-terminal, exactly 3. **Complete and green.**
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh
  context.
- **Group B:** subtasks **1a, 4, 5** — the A6 converse arm, the Step 11 rewire, and the propagation
  sweep. Non-terminal, exactly 3. **1a runs first in the group, and the order is a dependency rather
  than a preference:** subtask 4 writes the instruction text that enumerates the gate's arms and
  refusal reasons, so the arm set has to be final before the prose describing it is written.
- **Handoff after Group B:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group C with fresh
  context.
- **Group C:** subtask 6 — delivery. Terminal group (1 subtask; within the `1..3` range).

**Why three groups rather than a fourth subtask in Group B.** Adding 1a to `{4, 5, 6}` would make the
terminal group four subtasks, which the rubric scores as a `major` design defect — terminal groups are
`1..3`. Splitting instead costs one extra `/context-reset` handoff.

> **What forbids an eighth subtask is the seven-task threshold, and that alone.**
> `${CLAUDE_PLUGIN_ROOT}/agents/design.md:106` — "If scope > 7 tasks in decomposition — propose
> splitting into multiple tickets" — binds at `M = 8`, and the decomposition is now exactly seven
> (1, 1a, 2, 3, 4, 5, 6). So anything further that surfaces during Group B or C goes to AC13's
> follow-up issue or a new one: the task is too large and the remainder belongs in its own ticket.
>
> **The group cap does NOT also forbid it, and an earlier draft of this callout said it did.** The
> arithmetic: `skills/context-reset/SKILL.md:83` caps a task at three design-defined groups, and with
> non-terminal groups exactly 3 and a terminal group of `1..3`, three groups hold up to **nine**
> subtasks — `M = 8` regroups cleanly to 3/3/2 and `M = 9` to 3/3/3, both compliant. The cap is first
> breached at `M = 10`. So "an eighth subtask cannot be absorbed by regrouping" was literally false;
> an eighth subtask *is* absorbable, and the seven-task threshold is what rules it out. This
> decomposition is at the three-group maximum, but that maximum is not what is binding here.
>
> Recorded rather than quietly corrected, because the false leg is the one a later agent would have
> built on: a reader who believed the group cap bound at `M = 8` would have concluded that `M = 9`
> needed a new ticket when the rules permit it in three groups.

---

## Risks

- **A new `check-*.sh` under `skills/` reddens `gate-inventory`, and nothing in the spec says so.**
  Measured on a clone with both new files staged: `run-checks.sh --list` exits 1 with
  `a tracked check script that is neither a member nor exempt: skills/task/scripts/check-fix-plan.sh`.
  *Mitigation:* the `EXEMPT_CHECKS` entry in subtask 2 — the same category as `check-candidate.sh`,
  "the promotion gate a skill calls on its own". Measured: with the entry added, the identical tree
  exits 0 with empty stderr, and `test-run-checks.sh` still passes 100/0 (its pinned table covers
  `MEMBERS`, not `EXEMPT_CHECKS`). *Alternative measured and rejected:* renaming to
  `fix-plan-gate.sh` also returns the tree to green with no `run-checks.sh` edit, but it drops the
  repo's gate-naming convention and, per a replay of the hook's own pattern, loses `gate-pipe-guard`
  coverage on a hand-run `bash skills/task/scripts/check-fix-plan.sh … | head` — which that same
  replay confirms **is** blocked for the `check-` spelling. The spec's constraint 4 now states this
  direction and adds the consequence that matters most: an exemption means the repo-wide runner never
  executes this gate, so its own suite is its **entire** mechanical coverage.
- **Both arms charging the round for work it did not do.** The round-1 defect, re-measured at 772
  untracked lines on this branch (§ The baseline). *Mitigation:* the temp-index tree baseline, with
  T1-K asserting a round-1 untracked file is absent from round-2's total **and** from arm (a) — the
  leg the review asked for, and the one that would have caught this.
- **The two-place suite registration, measured both ways.** On the same clone,
  `in the tree but not named in AGENTS.md: skills/task/scripts/test-check-fix-plan.sh` at rc 1 before
  the AGENTS.md entry, rc 0 after. *Mitigation:* subtask 2 does both edits in one change.
- **`git ls-files` is index-only, so the syntax gate silently narrows on this task.** *Mitigation:*
  `git add -N` precedes the gate in subtask 2, and the **counts** are read: baseline today is
  `31 ok, 0 failed — 24 suites derived from the tree`, so the post-change run must read
  `32 ok, 0 failed — 25 suites`. A count that did not move is the finding.
- **Round-selection bug in the plan parser.** A growing progress file holds up to three plan sections;
  reading the wrong one gates a stale plan. *Mitigation:* select by highest `N`, plus T1-R's
  three-rounds-present leg and the ascending-order check `progress-format.md:123` already mandates.
- **An empty baseline reads as a valid one.** **Four** measured ways to get one, and the fourth is the
  one that matters: `git stash create` on a clean tree (empty, rc 0); `git stash create -u` on a clean
  tracked tree (empty); `git add -N` + `git stash create` (empty, **rc 128**); and **the `write-tree`
  form itself**, whose first draft returned **rc 0 and empty** when `read-tree` failed, because the
  function ended in `rm -f` and a function's status is its last command's. The hazard is the **class,
  not the primitive** — no choice of primitive retires it, which is why the mitigation is three-deep
  rather than a better command. *Mitigation:* `snap()` tests the captured sha after removing the temp
  index and returns 2; `baseline` refuses to write a stub it could not compute a sha for; `applied`
  exits **2 — cannot run** on a `round_base` that is absent or does not resolve; and the consumer is
  loud anyway — `diff-tree -r --numstat "" <sha>` hard-errors at **rc 128**, measured, rather than
  reporting zero changed lines. T1-J covers the write side and the unresolvable-read side; an empty
  value that compares against nothing is the "fallback's own branch" hazard
  `docs/agents-method.md § Test Conventions` names, and the first draft of this design contained it.
- **The in-round ignore list grows silently.** Two entries today
  (`ai-docs/learnings.md`, `ai-docs/learnings/`), each with a stated reason. An ignore list is a
  silencer, and this repo's own precedent — `run-checks.sh`'s `EXEMPT_CHECKS` prose comment, and
  `check-references.sh`'s "an allowlist with no reason is indistinguishable from a bug someone
  silenced" — says a reason must sit beside every entry. *Mitigation:* the count of ignored paths is
  printed in every verdict, each entry carries its reason in the script, and T1-L asserts an entry
  outside the list is **not** ignored, so the list cannot quietly widen into a wildcard.
- **The threshold literal leaking into instruction text.** *Mitigation:* the T1-E grep gate, run both
  ways while writing this design (below).
- **The counting basis drifting back apart.** The whole of MAJOR 2 was one quantity named on one side
  only. *Mitigation:* the basis is in the plan's **column heading**, so it travels with every plan
  rather than living in prose; T1-M exercises both sides on the same pure-modification input, which is
  the only input shape that can tell the two bases apart.
- **`skills/task/SKILL.md` crossing 35,000.** 8,053 chars of headroom against a ≤2,000-char budget.
  *Mitigation:* `wc -c` re-measured in subtask 4; detail goes to `reference.md`.
- **`fix-apply` reaching for a gated skill.** `skill-gate` denies `/task` to a subagent outright.
  *Mitigation:* the agent file forbids invoking `/task` or `/bugfix` and requires returning instead,
  so the round's control stays with the orchestrator.
- **A round with one trivial finding runs net-negative.** Not a defect — § Key decisions accepts it
  deliberately. *Mitigation:* AC20's statement is a delivery obligation in subtask 6, reported per
  round against the baseline's per-round counts (3 / 29 / 19 / 10 / 5), never as an average.

---

## Test Design

Base: a throwaway `git init` tree built per leg, as `skills/report-defect/scripts/test-file-report.sh`
and `skills/harness-init/scripts/test-scaffold.sh` do. Entry point: `check-fix-plan.sh` **invoked by
full path**, not as `bash <path>` — `test-scaffold.sh:88-94` and `test-file-report.sh:270-274` both
carry an explicit execute-bit assertion for exactly this reason, and
`docs/agents-method.md § Test Conventions` requires copying that assertion into a new file of the same
kind. Committed mode must be `100755`, as every existing skill-local script is.

| Leg | Scenario |
|---|---|
| T1-A | Planted unresolvable anchor (line beyond EOF, and a missing file) → `decision=REFUSE reason=anchor-unresolved`. Control: a resolving anchor passes. |
| T1-B | `*.spec.md` as a target path → `ROUTE-SPEC`; and `Disposition: amendment: spec` with a non-plans target → `ROUTE-SPEC`. Both legs assert no fix-agent-eligible output. |
| T1-C | Same two detections for `*.design.md` → `ROUTE-DESIGN`. |
| T1-D | Column sum 151 → `ESCALATE`, header carries `threshold_changed_lines=150`. Control: 150 passes (boundary is inclusive). Header disagreeing with the rows → `REFUSE`. |
| T1-E | Single-source threshold: `plan` and `applied` report the same value; mutating the constant in a temp copy moves **both** outputs; no instruction file contains the literal. |
| T1-F | `**verification:**` absent, and present-but-empty → `REFUSE`. |
| T1-G | A6: an `⬜ Open` finding missing from the plan; one listed twice; an out-of-vocabulary disposition; an empty Arm-A cell. Control: an all-`object:` plan with a declared total of 0 **passes**. |
| T1-H | `applied` arm (a): a file edited that the plan did not name → `FINDING`; a file **created** in this round and not named likewise. Control: only planned files → `OK`. |
| T1-I | **RETIRED on the applied side — round 9, and this row is corrected here because § Test Design is where legs are read from.** It specified "`applied` arm (b): 151 actual lines on the stated basis → `FINDING` carrying the threshold; 150 → `OK`", asserting the deleted arm's boundary in **both** directions. Arm (b) no longer exists, so the leg asserts a mechanism that is gone and must be **removed, not re-pointed** — nothing in the micro-loop has a boundary at 150. **What the leg's inputs are worth keeping for:** its tracked-and-untracked contribution fixtures still exercise the counting basis behind `actual_changed_lines=`, which the header still reports, so they move to a leg that asserts the **reported figure** rather than a verdict against a threshold. **T1-I's pre-apply half stands** — the threshold's one firing site is `plan`, and T1-D already asserts the 150/151 boundary there. |
| T1-J | `baseline`: it refuses to write a stub without a sha; `applied` exits **2** on a `round_base` that is absent, and on one that does not resolve to an object. |
| T1-K | **The round-1 leak.** A file created in round 1 (tracked *and* untracked variants) is absent from round 2's total **and** from arm (a). A file created in round 2 is present in both. The discriminating leg for MAJOR 1. |
| T1-L | The in-round ignore list: an edit to `ai-docs/learnings/<f>.md` fires neither arm and is reported as `ignored=1`. Control: an edit to a path one character outside the list **does** fire, so the list is not a wildcard. |
| T1-M | **The counting basis, both sides, same input.** 80 existing lines rewritten → `max(80,80)` = **80** → `OK`, proving the basis does not double-charge; 160 rewritten → **160** → `FINDING`. The declared side is exercised on the same tree, so a plan declaring 80 and a diff measuring 80 agree. The discriminating leg for MAJOR 2. |
| T1-N | Deletions: a deleted tracked file charges its line count; a deleted untracked file created at baseline likewise. A binary path contributes 0 and is reported as `binary=1`, never silently absent. **Rename sub-leg:** an N-line pure rename charges **2N** and surfaces as **two** plain paths, so a plan declaring 2N agrees and arm (a) can match both against the `Target` column. Pins the deliberate absence of `-M`: a leg asserting the composite `a => b` path form does **not** appear, since that form would make every rename an unplanned file. |
| T1-P | **Escaped-pipe round-trip.** An Arm-A cell quoting an instruction-file table row containing `\|` is recovered whole, and a `\|` inside `object: <reason>` does not shift the later columns. The first column-splitting parser in this tree, so this is its first positive control. |
| T1-Q | `baseline` and `applied` mutate nothing: the real index and `git status --short` are byte-identical before and after each verb. |
| T1-R | Three plan sections present → the highest `N` is the one gated. |
| T1-Y | **Arm precedence, on one plan carrying two faults at once.** The leg AC1 now requires, and the only one that discriminates: a per-property suite is green under either order. Three sub-legs, each a single plan. (1) An unresolvable anchor **and** a target under `ai-docs/plans/*.spec.md` → must print `decision=REFUSE reason=anchor-unresolved`, must **not** print `ROUTE-SPEC` in the header, and must still show `A2 spec-amendment FAIL` on its own line. (2) The same against `ai-docs/plans/done/*.design.md` → `REFUSE`, not `ROUTE-DESIGN`, with `A3 … FAIL` still shown. (3) An unresolvable anchor **and** a declared total over the threshold → `REFUSE`, not `ESCALATE`, with `A4 … FAIL declared 200 of 150` still shown. **Each sub-leg needs its matching control already in the suite** (T1-A's resolving-anchor pass, T1-B/T1-C's routing, T1-D's escalation), because without them the leg is satisfied by a gate that refuses everything. |
| T1-Z | **A6's converse (subtask 1a).** Four parts; what each one buys is stated because three of them cannot discriminate on their own. **(1) Primary — the discriminator.** One `⬜ Open` finding, two plan rows, the second numbered for a finding that does not exist, all targets resolving so no earlier arm can claim the decision. Must print `decision=REFUSE reason=plan-row-unmatched` and name the offending row on the `A6` line. This is the leg that separates the two candidate implementations, and it does so **on the reason token**: a count-equality implementation refuses too, but can only say `finding-coverage`. **(2) Swap — a regression canary, NOT a discriminator.** Two open findings, two rows, one omitted and one fabricated. Both implementations print `REFUSE reason=finding-coverage`, because the omitted finding trips the pre-existing missing-check before either new check runs. Kept to pin the set check's behaviour against a future regression of the missing and duplicate checks. **(3) Mutation — what actually tests the independence claim.** Disable the missing-check in a temp copy of the gate, with an apply-proof, then re-run the swap input: the set check must still refuse it and must now say `plan-row-unmatched`. Precedent, including why the apply-proof has to prove the *intended* change rather than mere difference: `scripts/test-run-checks.sh:299-314` (`mutate_runner` — sed errors caught, new text present in mutant and absent from the original, mutant still parses, exactly two changed lines). **(4) Three controls**, because a leg asserting only "not pass" is satisfied by a gate that refuses everything: one finding / one matching row → `decision=PASS`; the omission direction alone → `reason=finding-coverage`, **not** the new token, so the two directions cannot collapse; and T1-G's all-`object:` plan still passes, proving the check keys on the row's `#` rather than its disposition. |
| T1-ZA | **Arm (a)'s allowed set (the Design Amendment).** Plants a gated plan with **two** rows against a review table with two open findings: row 1 `fix` targeting file X, row 2 `object: <reason>` targeting file Y. The applied diff then edits **both** X and Y. Must print `decision=FINDING reason=unplanned-file` and name **Y** — and must **not** name X. **Controls, because a leg asserting only "not OK" is satisfied by an arm that flags everything:** (1) the same plan with the diff editing only X → `decision=OK`, proving `fix` targets are still admitted; (2) the same two-row plan with row 2's disposition changed to `fix` and both files edited → `decision=OK`, proving the arm keys on the **disposition** and not on the row's position or count. **(3) The `amendment:` variant is now asserted END TO END as T1-ZG**, not on the construction — the belief that `applied` was unreachable for a routing round was false (§ GAP 1), and that false belief was the whole reason this leg was scoped away. |
| T1-ZK | **The routing arms' path half keyed on `fix` rows (the round-3 Design Amendment).** Four legs, each differing from the passing shape in one half alone: (1) a `resolved: <reason>` row whose `Target` is a REAL `ai-docs/plans/<x>.design.md:<n>`, 0 declared, every anchor resolving → `PASS`, routing nothing — **shown RED against the pre-fix gate**, where it prints `decision=ROUTE-DESIGN`; (2) the same row with the disposition changed to `fix` → `decision=ROUTE-DESIGN reason=design-amendment`, which is the half that must not be lost; (3) an `amendment: spec` row whose `Target` is a non-plans file → `decision=ROUTE-SPEC reason=spec-amendment`, the control that catches a guard mistakenly wrapped around the disposition `case` as well; (4) legs 1 and 2 against a real `*.spec.md` target → `PASS`, then `ROUTE-SPEC`. **The red run is the evidence, not the green one** — a leg authored after the guard lands cannot tell "the narrowing works" from "the fixture never routed anyway". AC2's real-artefact fixture requirement still binds: a fabricated path fails A1 first and the leg would pass on the refusal while measuring nothing about routing. **T1-ZK is the third of the three legs AC2/AC3 now mandate per arm** — T1-B and T1-C already ship legs 1 and 2 on both arms and stay correct — **and it carries one obligation on the existing suite:** `test-check-fix-plan.sh:131`'s message ("an active spec path routes, whatever the disposition says") is false under the narrowing while its leg stays green on a `fix` fixture, so it must name the disposition as load-bearing. |
| T1-X | `check-fix-plan.sh` carries the execute bit; committed mode is `100755`. |

**T1-Y is verified absent from the shipped suite, not assumed absent.** Its section banners were
enumerated: the suite carries `T1-A anchor resolution`, `T1-B spec-amendment routing, both detections`,
`T1-C design-amendment routing, both detections` and a `routing beats size` assertion at
`skills/task/scripts/test-check-fix-plan.sh:175`, and **no** banner or assertion combining an
unresolvable anchor with an amendment path. The three sub-legs above were then run by hand against the
shipped gate and all three already print the required decision, so T1-Y is a **coverage** gap rather
than a behaviour gap: the leg pins behaviour that exists and is currently unguarded.

**AC2's new real-artefact fixture requirement is already satisfied, and needs no new work.** Checked in
the suite's own fixture builder rather than inferred: `mkfix` writes a real four-line
`ai-docs/plans/t.spec.md` and a real four-line `ai-docs/plans/done/t.design.md`
(`skills/task/scripts/test-check-fix-plan.sh`, `mkfix`), and T1-B/T1-C cite `:4` in each — which
resolves. So the routing legs route for the right reason today. The requirement is worth keeping in the
spec because the failure it describes is invisible: under first-wins precedence a fabricated plans path
returns `REFUSE`, and a leg asserting only "not PASS" would pass while measuring nothing about routing.

> **Two standing rules for anyone adding a leg to this suite, both earned on this task rather than
> imported.**
>
> **Write the interaction leg even where every property already has one.** The A6 converse gap was not
> looked for — it fell out of building an *interaction* input for T1-Y: two faults in one plan against
> a one-finding fixture, a shape no per-property leg constructs. The durable form: **a leg written to
> test an interaction constructs inputs no single-property leg constructs, and those inputs exercise
> arms nobody was testing.** T1-Y was asked for to discriminate arm precedence and incidentally
> discriminated A6.
>
> **When defining a coverage arm, enumerate the failure modes in BOTH directions of the mapping.** A6's
> definition covered three failure modes of the findings-to-plan mapping and omitted the fourth, which
> exists only in the direction the mapping is many-to-one. Findings map to plan rows, so the definition
> naturally guarded the finding side — missing, duplicated, mislabelled — and left the row side
> unchecked. Ask explicitly what the *many* side can contain that the *one* side never mentioned.
>
> **And when a PERMISSION is derived from a table, check what the table admits that the permission
> never meant to cover.** This is the same check pointed at authority rather than coverage, and it has
> now found two defects in this one mechanism — both of them *a permission derived from the wrong side
> of a mapping*. Arm (a)'s allowed set was built from every plan row: once from rows matching no
> finding (closed by subtask 1a's `plan-row-unmatched`), and once from rows the fix agent is forbidden
> to act on (closed by the Design Amendment above). Each time, the plan's `Target` column was read as
> "files in play" when what it licenses is narrower. **Two instances is a pattern, not a coincidence:
> expect the next one wherever a list serves both as a description and as a grant.**

**Every arm is shown red on a planted defect before its assertion is written** — subtask 1's
acceptance condition, not a suggestion. `docs/agents-method.md § Tooling` is explicit that a check
mandated in prose is not yet a check, and the four shapes it warns about (`No files matched`,
`Total 0 tests`, an empty diff, `unknown option`) are all live here: a plan parser that selects
nothing reports every arm as passing.

### AC verification

Commands marked **RUN** were executed while writing this design, once as written and once against
input that must trip them.

> **The `(form verified)` convention is RETIRED, and the rows it marked are discharged rather than
> deleted.** It was introduced in round 2 and endorsed by `design-review` as an honesty device: a
> reader must not mistake a *specified* leg for a *run* one, and the suite could not be run before it
> existed. That reason has expired — **the suite exists and runs**. Re-derived here rather than taken
> from a report: `bash skills/task/scripts/test-check-fix-plan.sh`. **Round 9 measured `225 passed,
> 0 failed` with twenty-five legs (`T1-A` … `T1-ZE`); do not read that pair as current.**
> **Re-derived now, round 10: `367 passed, 0 failed`, with all thirty-four legs present
> (`T1-A` … `T1-ZN`)** — including every leg this design specified, and including round 10's own
> answer-vocabulary leg `T1-ZN`, which is green.
>
> The marker is kept in this sentence, and nowhere else, because **a stale honesty marker is worse
> than none** — it is read as current, and left standing it would tell a reader that six criteria rest
> on unrun assertions when the suite shows them green and several were shown red first. A reader of the
> archived design should be able to see the markers were real and were discharged, not that they never
> existed.
>
> **Three statuses replace it, and the distinction is the valuable part.** The brief asked for two; a
> third exists and is strictly more informative, so all three are kept:
>
> | Marker | Means |
> |---|---|
> | **(run)** | the leg exists and passes in the green suite above |
> | **(run; shown red)** | additionally demonstrated to FAIL against a tree lacking the behaviour it asserts — a one-off before acceptance, attested by the implementation, not re-established on later runs |
> | **(run; red re-proved every run)** | carries an **in-suite** mutation leg with an apply-proof, so its discrimination is re-established on every invocation rather than attested once |
>
> The one-off evidence behind **(run; shown red)**: the gate was backed up, the three behavioural edits
> reverse-applied, the suite run bare at **`209 passed, 16 failed`**, then restored and confirmed
> byte-identical with the execute bit intact. **T1-ZE** additionally ran red against today's tree
> *before* either example was corrected, printing both file names with both faulty cells quoted.
>
> **(run; red re-proved every run)** is the strongest and currently applies to **T1-Z**, whose mutation
> leg sits at `skills/task/scripts/test-check-fix-plan.sh:364-386` and carries the full apply-proof the
> round-3 specification demanded — sed errors caught, new text present in the mutant, old text absent,
> mutant parses, exactly two changed lines, execute bit set. It is the difference between "we checked
> once that this test can fail" and "this test proves it can fail every time it runs".
>
> **Where a row says only (run), that is deliberate and not an omission.** Subtask 1's acceptance
> condition required every arm to be shown red on a planted defect before its assertion was written,
> and the implementation reports that discipline — but it is not re-measured here and the older legs
> carry no in-suite mutation proof, so they are not promoted on the strength of a report.

| AC | Verified by |
|---|---|
| AC1 | `skills/task/scripts/test-check-fix-plan.sh` → T1-A for the refusal, **and T1-Y for the precedence half added by the second amendment**. T1-Y is the only leg that discriminates, since a per-property suite is green whichever order ships. The behaviour was **RUN** against the shipped gate this round: an unresolvable anchor paired with a real `ai-docs/plans/t.spec.md:4` target prints `decision=REFUSE reason=anchor-unresolved` while still reporting `A2 spec-amendment FAIL`, and the same holds paired with a real `done/*.design.md` target and with a 200-of-150 overrun. Controls run alongside: resolving-anchor-plus-spec-path → `ROUTE-SPEC`; unresolvable-only → `REFUSE`. The leg is a coverage gap over behaviour that already exists |
| AC2 | T1-B's two legs **(run)** **plus T1-ZK**. **The criterion now has TWO halves and mandates THREE legs**, and the three are met jointly rather than by any one leg: the path half fires only on a row *dispositioned `fix`* naming a `*.spec.md` path under `ai-docs/plans/` (active or `done/`) — T1-B's first leg; the disposition half fires on `amendment: spec` whatever the target — T1-B's second leg; and a row proposing **no** edit while naming a real artefact must **not** route — **T1-ZK**, which is the leg the shipped suite did not have and the only one asserted against a plan differing from a passing one in that half ALONE. **This row previously recorded a DEPENDENCY: that dependency is DISCHARGED.** The record of it stays, because it is why the amendment was written — AC2 used to read "names a `*.spec.md` path" with no row qualifier, so the narrowed code would have contradicted a live criterion. It no longer does: the criterion carries the narrowing, the no-edit exclusion, the real-artefact fixture requirement and the explicit refusal of a one-test-per-arm suite ("a suite written against the unqualified rule stays green under the narrowed one"). **One obligation remains, and it is on the SHIPPED suite, not on the criteria:** `test-check-fix-plan.sh:131`'s message asserts that an active spec path routes "whatever the disposition says", which the narrowing makes false while the leg stays green on a `fix` fixture — the exact shape AC2's closing sentence forbids relying on. **No spec line number is recorded here**; § The routing arms' PATH half carries the re-derivation command, in prose rather than in a table cell — a `grep` pattern containing a table-escaped `\|` is alternation with an empty branch and matches every line, which is the same hazard AC19's row now warns about |
| AC3 | T1-C's two legs **(run)** **plus T1-ZK**, under AC2's note: the same two halves one arm over, and AC3 incorporates AC2's narrowing, anchor qualifier, fixture requirement and three legs by reference. T1-C's first leg covers the `fix`-row design path including `done/`, its second the `amendment: design` disposition on a non-plans target, and T1-ZK the no-edit row that must not route. **Dependency DISCHARGED on the same amendment.** The measured instance that proved the narrowing necessary is on this arm: a round-3 plan recording a finding closed by an approved amendment returned `decision=ROUTE-DESIGN`. T1-C's two assertion messages were read and need no change — neither claims disposition-independence. Re-derivation command: § The routing arms' PATH half, per AC2's note |
| AC4 | T1-D **(run)**. **Swept for the widening:** the declared total is summed over **rows**, not findings (§ Technical constraints 12a), so a finding occupying several rows contributes each row — T1-ZB's multi-row passing plan is also the leg that pins the sum, since a per-finding sum would disagree with it |
| AC5 | T1-E. **The spelling this design originally pinned is withdrawn.** `grep -rn '\b150\b'` relies on `\b`, a GNU extension: on a `grep` without it the scan returns **empty** and the leg reads that as agreement — a silent pass, and the hazard this design warns about elsewhere. The suite ships **`grep -lw`** with a planted positive control instead. The unqualified `grep -rn '150'` is also unusable, **re-run this round: 2 hits**, both the `1500 incl. tests` file-size limit (`agents/review-findings.md:72`, `agents/self-review.md:85`) — so the word-boundary condition is load-bearing rather than tidiness, and the portable spelling is the one that must ship. **SWEPT for round 9 — back to ONE quantity with ONE firing site, and the round-8 sweep this row carried is WITHDRAWN.** That sweep said the criterion "now carries TWO quantities" and specified a mutation-and-converse leg over a threshold and a tolerance; **no tolerance exists** — the post-apply size arm is withdrawn in every form (AC18) — so that leg is withdrawn with it. **Both of this criterion's earlier forms are records, not live claims:** "both firing sites read their reported value from that one definition" held while one number fired twice, and the two-quantity split held for one round in which the trigger was still specified. What ships: `THRESHOLD_CHANGED_LINES=150`, re-derived at `check-fix-plan.sh:49`, one assignment, read by the pre-apply gate alone. Legs: the static half stays — `grep -lw` per literal with its planted positive control, proving no second copy anywhere — **plus a leg asserting the number appears in `plan`'s header and in NEITHER `applied`'s nor `baseline`'s**, which is the half that catches a verb reporting a quantity it does not fire on. The `grep -rn '\b150\b'` spelling stays withdrawn for the reason recorded above |
| AC6 | T1-F **(run)** |
| AC7 | T1-H, plus T1-K's arm-(a) half and T1-L's control, **plus T1-Z and T1-ZA**. Both belong to AC7 as much as to AC19: arm (a) measures the applied diff against the plan's `Target` column, so a target the plan should never have offered pre-authorises a file and AC7 is satisfied *literally* while its intent is defeated. **Two such directions are now closed, and neither is "the only" one** — T1-Z closes a row matching no open finding, T1-ZA closes a row the fix agent is forbidden to act on. Arm (a) cannot see either from its own side, because it is keyed on files the plan did *not* name and both of these are named. **T1-Z: (run; red re-proved every run)** — its in-suite mutation leg disables the missing-check and requires the swap to refuse with `plan-row-unmatched`. **T1-ZA: (run; shown red)** via the reverse-apply experiment. **T1-H, T1-K, T1-L: (run)** |
| AC8 | `stat` + `grep` of the written section after `fix-apply` returns, per the Design Amendment recipe's existing mtime+grep wording; asserted as a step in `reference.md § Step 11` |
| AC9 | `grep -n 'ESCALATE\|surface to the user' skills/task/SKILL.md skills/task/reference.md agents/fix-scout.md agents/fix-apply.md` — every escalation lane terminates at the orchestrator and neither agent file carries a consent decision |
| AC10 | T1-G's Arm-A-cell leg plus the retained CLOSING GATE text; `grep -n 'CLOSING GATE' skills/task/SKILL.md` |
| AC11 | **Swept: the criterion is now arm-and-outcome structured, and this task's disposition is arm 1, outcome 1b — the figure is NOT OBTAINED.** The trigger fired (round 1 rejected with eight open findings) and beats 1–3 ran for real: the gate took the round's baseline, the scout wrote a valid 8-row plan with every anchor resolving, the gate returned `PASS` at 54 declared of 150. Beat 4 did not — the orchestrator applied the fixes, because the round's own work was widening the plan format and a format cannot be planned in the format it widens. So the criterion is **satisfiable in principle and not satisfied in fact**, and is recorded NOT OBTAINED naming which beats ran, with the obligation carrying forward **whole**. Not a waiver: a figure from a round the orchestrator fixed describes **baseline** behaviour, so reporting it as the mechanism's "after" would be false in the one direction this task exists to prevent. Verified by reading the recorded disposition, not by producing a number. **ROUND 3 — the sequence is running END TO END and its figure is PENDING. Round 1's record above stands exactly as written**, because it is what happened and the two rounds went differently, which is itself the evidence; this row is AMENDED by addition, not rewritten. The criterion gained its round-3 record while this row still carried round 1's account alone — the gap that is closed here. What must be true for round 3, stated as obligations rather than as quantities: beat 1 took the round's **own** baseline (`round_base=0117edf6…`, round 3, threshold 150); beat 2 produced a plan; beat 3 gated it, and the gate returned **`decision=ROUTE-SPEC`** on the round's first plan — the routing arms firing on rows that name this document and the spec, which is the mechanism working rather than a detour; beat 4 has not completed, so the outcome is **pending — not obtained and not waived**, and the figure is the ORCHESTRATOR's to measure when it does, on the baseline's weights, per round, with the not-comparable note. Verified by reading the recorded disposition and the gate's own verdict line. **NO instance count appears in this row, deliberately.** The sixth Spec Amendment removed the criterion's declared / invisible / ceiling figures for the stated reason that the recipe permits a scout to rewrite its plan inside a round, so a quantity belonging to that artefact goes false while the rule above it still holds — and one rewrite inside this round already moved all three. A design row that re-added them would reinstate the same defect one level down, which is why what is recorded here is the rule and the pending status |
| AC12 | `grep -n 'GH-' ai-docs/context.md` shows the new ticket-keyed entry beside the four existing ones (**RUN** today: `GH-10:124`, `GH-11:126`, `GH-72:128`, `GH-75:174`) |
| AC13 | `gh issue view <N>` on the created follow-up, naming `/bugfix` Step 5, `/project-review`'s fix loop, and the post-push fix round |
| AC14 | `grep -n '<issue key>' skills/bugfix/SKILL.md skills/project-review/SKILL.md docs/workflow.md` — one divergence note per excluded-loop sibling |
| AC15 | `bash scripts/run-checks.sh` — **RUN** today: exit 0, `31 ok, 0 failed — 24 suites derived from the tree`. Post-change it must read `32 ok, 0 failed — 25 suites`, with the `shell-syntax` member's processed COUNT covering both new scripts. The red direction was also **RUN**, on a clone: `run-checks.sh --list` at rc 1 naming the unregistered suite and the stray check, and rc 0 after both remedies |
| AC16 | `wc -c skills/task/SKILL.md` — **RUN** today: 26,947. Must stay < 35,000 |
| AC17 | `bash scripts/check-propagation-arms.sh` — **predicted count: 40**, recorded here before the run as AC17 requires, superseding the 39 of the first round-2 draft. Membership shipped: two separate agent contracts, the gate script, **and** `docs/templates/progress-format.md`, all named on the anchor row — the seven-path enumeration in § Naming the gate script on the anchor row, of which four are new derived tokens, so 36 + 4. **RUN** four times this round: baseline `36 … all fire, 13 controls all silent, 2 pre-fix matches all kept`; a 5-member row with the one added arm → `39 …`; the full seven-path row → **`40 derived members all fire, 13 controls all silent, 2 pre-fix matches all kept`**, with `docs/templates/progress-format.md` and `skills/task/scripts/check-fix-plan.sh` both listed as firing; and `scripts/test-check-propagation-arms.sh` against that last tree → `53 passed, 0 failed`. A run reporting anything but 40 is a finding, not a new baseline |
| AC18 | T1-I and T1-M **(run)**. T1-M is the one that matters: it is the only leg whose input shape can distinguish the two candidate bases. **Swept ONCE, and an earlier draft of this row claimed twice — corrected.** The sweep that holds: the actual total carries 12c's gitignored-path clause, asserted by **T1-ZD**, on the same basis AC4's declared total uses — one basis, two sides, or the figures are not comparable. **The exclusion is now a criterion too — the sixth Spec Amendment has LANDED**, so the second sweep this row once claimed prematurely is real as of now: re-derived against the live spec, **AC7** carries "arm (a): **except for a `*.spec.md` or `*.design.md` under `ai-docs/plans/` (active or `done/`)**" in the **suffix-keyed** form, not a directory-wide one. **CORRECTED — round 10, and this is the THIRD stale claim this one row has carried.** It said "and **AC18** itself carries the matching exclusion for the actual total", explicitly "re-derived against the live spec". **AC18 carries no such clause and carries no `ai-docs/plans/` path at all:** `grep -nF 'ai-docs/plans/' <spec>` hits lines 31, 337, 338, 342 and 390, and AC18 is at 353 — `sed -n '353p' <spec> | grep -cF 'ai-docs/plans/'` returns **0**. The exclusion ships and is a criterion; it is **AC7's alone**, on arm (a). The sharpest part of this: **this row's own correction table already recorded AC18 as no longer carrying it**, so the row contradicted itself across two of its own sentences — a correction written into one half of a row while the other half kept asserting the thing corrected. A row long enough to disagree with itself is the hazard, not the individual claim. **No hit count is recorded in this row.** The "6 hits" it used to carry is **withdrawn rather than corrected to a new figure**: that count has read 6, 7 and 8 inside this one round, the last move caused by the Spec Amendment that was meant to settle the question, so any number written here would be a fourth value already waiting for its own correction. Re-derive with `grep -nF 'ai-docs/plans/' <spec>` and read which AC ids the hits land in; § The stale pending-amendment claim holds the criteria-by-AC-id table. **T1-ZF** asserts it, and must also assert the narrowing of § Design Amendment — round 3: the exclusion keys on the `.spec.md` / `.design.md` suffixes, not on the directory, so a non-routing path under that prefix is charged and named rather than excluded. The intermediate draft of this row — claiming two sweeps before the amendment landed, then claiming one after — was wrong in both directions at different times, which is the hazard of a verification row that tracks a criterion still in motion. **And a THIRD time, which is what the paragraph above corrects: the remedy for that intermediate draft was itself false when written** — it asserted 6 hits where the orchestrator had already measured 7, and it attributed to AC7 a wording ("for a path outside `ai-docs/plans/`") that has never appeared in the spec at all. So the fix for a stale-claim finding reproduced that finding's own defect class, in this row, in the same round: a re-derivation presented as current. That is the reason this row now carries an AC id and a re-derivation command where it used to carry a number. **SWEPT for round 8 — arm (b) is now a TRIGGER, so what this row verifies has changed in kind.** Everything above is kept as the record of a verdict that shipped and was retired on evidence; what follows is what the criterion asks for now. **T1-I is SUPERSEDED on the applied side:** it asserted the actual total against the threshold, and nothing compares those two any more — the threshold has exactly one firing site, the pre-apply gate (AC5), and T1-I's pre-apply half stands. **T1-M's record stands unchanged** — it remains the only leg whose input shape distinguishes the two candidate bases, which the trigger does not touch. **New legs, and the first is the one that decides whether the trigger measures anything at all:** the declared total reduced by both invisible classes before comparison, with ONE leg per class asserted separately and a third showing a path under neither is still counted (AC18 demands the separation); a **cross-side agreement** leg taking one gitignored path and asserting the measured side's absence-from-the-diff and the declared side's `git check-ignore` agree on it, because those are two different mechanisms and "one basis, two sides" is otherwise a claim rather than a property; a conformant-plan leg showing the subtraction is a **no-op** when the scout applied the basis; agreement routes to the review pass with **no** question; divergence routes to the question and **then** the review pass; and the routed verdict **carries the tolerance it fired under**. **ROUND 9 WITHDRAWS all of the above that describes a comparison, and this row's round-8 sweep is a RECORD of a mechanism that never shipped.** Withdrawn with it: the two subtraction legs, the neither-class control, the cross-side agreement leg, the no-op leg, the tolerance-reported leg, and `agreement=within|diverged` in any form. **What AC18 now asks for is a LOOP, not an arm**, so what verifies it is a sequence rather than a figure. **ROUND 10 — the "Legs:" list this row carried is REWRITTEN, because it named as legs four things a shell suite cannot reach, and the criterion now says so itself.** It read: "a round with no mismatch still runs the loop and reaches the review pass; a mismatch re-fixes with the divergence named …; three mismatches escalate with the process recommendation …; and the review pass runs in every one of those cases". **Every one of those is ORCHESTRATOR CONDUCT.** A suite that invokes a shell script cannot observe that a loop ran, that it ran between the apply and the review, that it stopped at three attempts rather than four, or that a burned cap escalated instead of proceeding — so a row listing them as legs claims coverage that does not exist, which is worse than an honest gap because it stops anyone looking for one. **What IS asserted mechanically, and it is what passes through the gate:** a loop's verdict row is written for the round carrying its **iteration count**, its **cost** and the **question's answer**, and an **out-of-vocabulary answer is refused** (AC23, AC24). **What is NOT asserted and must not be read as covered:** that the loop ran at all, that it ran in the right place, that the cap held at three, that a burned cap escalated. **The recorded iteration count makes the retirement rule READABLE; it does not prove the cap was obeyed** — it is self-reported by the party the cap binds. Those four are verified by reading the round, not by the suite. **T1-I is superseded on the applied side** — nothing compares the actual total against the threshold any more; its pre-apply half stands. **T1-M's record stands unchanged**: it remains the only leg whose input shape distinguishes the two candidate bases, which neither the trigger nor the loop touches. Mechanics: § Design Amendment — round 9 |
| AC19 | T1-G's all-`object:` control, plus a span-scoped prose check. **RUN both directions this round.** As written in round 1 the command was unscoped and returned 3 hits at rc 0 (`skills/task/SKILL.md:127`, `:192`, `:218` — none in Step 11), so it could never produce the empty result the row claimed. Scoped form: `sed -n '/^### Step 11/,/^### Step 12/p' skills/task/SKILL.md > <tmp>` then `grep -nE 'too simple\|trivial\|small round\|exempt' <tmp>` → **empty at rc 1** against the live file. **RE-RUN for this amendment, and it still returns empty at rc 1.** Against a temp copy with `A round with a single trivial finding is exempt from the scouted-plan sequence.` planted inside Step 11 → **1 hit at rc 0**. The gate is therefore proven able to come back non-empty, and the two commands are separate calls so neither masks the other. **The span LENGTH is removed from this row rather than updated.** It read "(29-line span)"; measured for this amendment, the same `sed` range yields **48** lines. The length was never what the check rests on — the span is fixed by its **delimiters**, `/^### Step 11/` to `/^### Step 12/`, and its line count moves every time Step 11's own prose is edited, which is work this very task does. Recorded at one value and measured at another while the check itself never changed once, a length in a verification row is a number that can only go stale, so what the row keeps is the range that selects the span and the result the check returns over it. **One spelling caution, because this row pins an exit gate and the failure mode is an empty result:** the `\|` above is MARKDOWN table escaping. The executable form uses bare pipes — `grep -nE 'too simple|trivial|small round|exempt'` — and a reader who copies the escaped form into `grep -E` searches for the literal string `too simple|trivial|small round|exempt`, which comes back empty and reads exactly like the pass this row claims |
| AC20 | **Swept into two halves.** **Half 1 — PASS, do not re-deliver:** the net-negative statement and its deliberate acceptance are recorded durably in `ai-docs/context.md` § Open questions and in `GH-98`, both verified present. A later reader finding AC20 open must not read this half as outstanding. **Half 2 travels with AC11's figure** — per round against 3 / 29 / 19 / 10 / 5, never as an average — and under this task's outcome 1b it carries forward with the obligation. Half 1 stands either way |
| AC21 | **New criterion, previously unrepresented in this table.** **T1-ZB**, whose three legs are separate by construction: a multi-row finding PASSES, an omitted finding is REFUSED (`finding-coverage`), a fabricated row number is REFUSED (`plan-row-unmatched`). Each refusing leg differs from the passing plan in **that half alone**, which is what AC21 means by forbidding one combined assertion. **T1-Z carries the stronger status** — `(run; red re-proved every run)` — its in-suite mutation leg at `skills/task/scripts/test-check-fix-plan.sh:364-386` disables the missing-check and still requires the converse to refuse, so neither half can be lost silently **(run)** |
| AC22 | **New criterion, previously unrepresented in this table.** The closed vocabulary and the fifth token: **T1-ZC** asserts a valid `resolved:` row passes with 0 declared and routes nothing, an empty reason refuses, an out-of-vocabulary token refuses (which is what keeps the vocabulary closed), and an all-`resolved:` round passes — AC19's no-exemption half. The examples half: **T1-ZE** runs the gate's **own** extractor over every non-`none` Arm A cell in `agents/fix-scout.md` and `docs/templates/progress-format.md` and requires an anchor from each. **Shown RED against today's tree before either example was corrected**, printing both file names with both faulty cells quoted — the condition AC22 states, and the reason the leg is evidence rather than decoration **(run; shown red)**. **The round-8 sweep of this row is WITHDRAWN.** It said AC22's "declares 0" becomes a check — an A4 refusal of a non-`fix` row whose `expected` is not 0, with three legs. That refusal existed **only** to keep the withdrawn subtraction honest: with no comparable-declared figure, a non-`fix` row's declared number inflates nothing and diverges nothing. So the check is withdrawn and **"declares 0" stays unchecked prose**, which is recorded here as the residual it is rather than left to look closed. It is not a new finding and it is not in scope: this task's own named defect class applies to it, and closing it needs a decision of its own |
| AC23 | **New criterion.** The bounded question, verified on its **BOUNDS** rather than on its answer, because the failure mode is that it grows into a second review pass — and the question is now **unconditional**, so that failure mode costs every round rather than some. Legs: exactly ONE question per attempt, put **every** round (the round-8 form asserted "only on `agreement=diverged`" — **withdrawn**, there is no trigger); **all THREE inputs present and no fourth** — the round's own plan section, the applied change, and the mechanical check's result — the orchestrator assembles that list. **ROUND 10 — this row's leg list is CUT TO THE ONE LEG THAT EXISTS, and the rest is restated as what it always was: unreachable.** It claimed legs for "exactly ONE question per attempt, put every round", for all three inputs being present "and no fourth", and for "no apply path and no rework-decision path exists from it, asserted by grepping the instruction text". **Only the last of those is even a search, and a `grep` over prose asserting the ABSENCE of a lane is not a leg** — it passes on any wording that does not happen to use the words searched for. **AC23's one real leg:** the answer vocabulary's enforcement — each of **`MATCH`** and **`DIVERGE`** is accepted by the recording verb, and anything outside the set is **refused**, on the argument-validation lane. That is the criterion's only point of mechanical control and the row now claims exactly it. **NOT asserted, and not to be read as covered:** that the question was asked at all, that it was asked exactly once, that it received only its three inputs, and whether the word chosen is the *right* word for what the diff shows. The gate can refuse a word it does not know; it cannot check whether the right word was chosen. **The third input is a REVERSAL of a round-8 decision and the row says so:** round 8 ruled the question must not consume arm (a)'s result, on the ground that it would widen the input — AC23 now makes that list the third input and gives its reason, so that ground is retired while the conclusion it was supporting (arm (a) stays a finding) stands on its other two. Mechanics: § Design Amendment — round 9 |
| AC24 | **New criterion.** **Reuse verified in source, not assumed:** `harness_ledger_append` at `hooks/lib/ledger-write.sh:30`, sourced never executed, returning 0/1 and by contract never exiting non-zero; the line shape adopted from `hooks/lib/loop-verdict.sh:124` and `:211`, both `jq -nc` objects carrying `kind: "verdict"`. **The round-8 form of this row is WITHDRAWN on two counts:** it wrote into the loop ledger's **own** directory, and it asserted a line per **branch of the trigger**. There is no trigger, and that directory was measured to be the wrong one — a single row planted there moved an existing report's project, session and verdict counts and fabricated a session block carrying a false sentence about the file's age. **So the rows go to a SIBLING directory** (§ Design Amendment — round 9 names it and derives it from `HARNESS_LOOP_DIR` so a sandboxed suite stays sandboxed), and what the row carries is **the loop's iteration count, its cost and the bounded question's answer** — the three figures the retirement rule is read from, absent which that rule is unenforceable. Legs: one line per firing (the pre-apply escalation, and once per loop); the line carries the iteration count, the cost **and the question's answer**; **each of `MATCH` and `DIVERGE` is accepted and anything outside the set is refused** — the enforcement point AC23 delegates here, and the leg must assert the answer is **in the written row** and not merely that the call exited 0, because a verb that validated the word and dropped it would pass a refusal-only leg while leaving the retirement data unable to say how often the loop answered `DIVERGE`; a **simulated write failure leaves the round's outcome unchanged**; and **the neighbouring report's own counts are unmoved by the new rows**, which is the leg that pins the sibling choice rather than trusting it. **One leg is not optional and is the only one that can catch the quietest failure:** the gate must be invoked **BY PATH**, as the orchestrator invokes it, from a tree where `hooks/lib/ledger-write.sh` is absent — and the row must still be written. A suite that sources the library directly never exercises the resolution, so an `if`-only copy of the guard (no `else` fallback) passes it while writing nothing, forever |

---

## Open questions

None for the product owner. The seven the spec assigned to design are answered in § Approach, and the
three further decisions the round-2 findings forced are recorded beside them.

**Four of those seven are now retired in the spec as well, because shipped reality answered them**, and
this design's answers are no longer proposals: two agent files exist (`agents/fix-scout.md`,
`agents/fix-apply.md`), one gate script exists (three verbs when this was written, FOUR since round 9 added `record`), the plan lives in the progress file as
a `## Fix Plan (Round N)` section, and the disposition vocabulary is five tokens rather than four. The
remaining three — the gate's verdict format, the threshold's single definition site, and the objected-
finding disposition — are likewise shipped. **Read none of the spec's § Open questions entries on those
subjects as live.**

The A6 converse gap that was open here in round 3's first draft is **closed**: the orchestrator decided
to fix it inside this task, and it is now subtask 1a with reason token `plan-row-unmatched` and test leg
T1-Z (§ A6's converse). Nothing about it remains open.

**Round 1's three spec findings are all closed** — the spec was amended on each, and this round
verified each amendment against the tree rather than accepting it: the Task/Design negative holds under
this design (§ What does *not* change, re-checked against the conditional the amendment attached), the
CREATE obligation is now stated and discharged by subtask 5, and both registration directions are now
in constraint 4 with the consequence that the gate's own suite is its entire coverage.

**One item that was a non-finding and has since become a real one — my own citations, and the way they
went stale is worth more than the fix.** In round 3 `design-review` flagged my
`docs/templates/progress-format.md` line citations as "off by a few lines", I re-derived all five, found
every one exact, and declined the correction on the ground that changing a correct anchor to match a
report of drift would introduce the drift. **That was right then and is wrong now.** Subtask 4 edited
that file, and re-deriving this round gives:

| Cited as | Now at | What it anchors |
|---|---|---|
| `:7` | **`:7`** | the gitignored statement — unmoved |
| `:78` | **`:90`** | the per-round `## Fix cycle round M` row |
| `:119` | **`:131`** | the `Self-Review (Round N)` sections heading |
| `:123` | **`:135`** | the anchor-at-EOF note |
| `:130` | **`:153`** | deletion by `/pr-merged` |

Four of five moved. **`design-review` closed this question in agreement and said its own round-2 drift
claim was the wrong one:** the round-2 claim was wrong, the round-3 defence was right *as a defence*,
and four of five have now genuinely moved because subtask 4 edited the file **after** that defence —
the three statements are not in tension, because a verified anchor is verified as of a revision. It
called the sequence a good instance rather than an embarrassment, and noted that the file being cited
states that very rule.

Both facts hold at once: my defence was correct as a defence, because I had
re-derived them and they were exact — **and a verified anchor is verified only as of a revision.**
Citing one across a later edit to its own file is a different act from deriving it, and
`progress-format.md` itself states the rule I then fell to: *"a line number recorded here goes stale as
soon as the file is edited again — prefer recording the token alongside it."* The citations above are
corrected; the durable fix is the one that file already prescribes, which is to anchor on the token.

**One residual, unchanged and deliberately not closed. THE SCOPE FENCE STANDS; THE MECHANICS SENTENCE DID
NOT, and is corrected here.** The understated-plan hole is exactly where the spec leaves it, and nothing in
this task closes it.

This paragraph used to read that "a plan that honestly declares 20 and lands 140 still passes the pre-apply
gate, the post-apply arm, and A4's arithmetic check", and that "the spread AC5 accumulates is now a spread
of comparable numbers". **Three things in that are now false.** There is no post-apply arm to pass — it is
withdrawn in every form (§ Design Amendment — round 9). AC5 accumulates no spread: it is ONE quantity with
ONE firing site, and the figures that accumulate are AC24's, in the sibling ledger. And such a plan does
**not** sail through: 20 declared against 140 landed **is a diff that does not match its plan**, so the
micro-loop's question is put against it, which is the whole reason the arithmetic could be deleted without
losing coverage.

**What remains residual is narrower and is a different thing: nothing VERIFIES the declared figure.** The
scout is instructed in prose to count on the stated basis, and no check confirms it did — so an
understated plan is caught by a question rather than by a measurement, and a question can be answered
*matches* on a plan whose number was never right. That is the pre-existing residual, it is not new, and no
predicate is designed here in order to fix it.
