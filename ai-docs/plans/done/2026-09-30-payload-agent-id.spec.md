# agent_id from the PreToolUse payload, so fan-out detection can fire

**Source:** ticket GH-72
**Date:** 2026-09-30
**Tracked in:** GH-72

## Problem, as measured

`hooks/lib/loop-index.sh:76-78` derives the ledger's `agent_id` by regex-matching
`transcript_path` against `/subagents/agent-*.jsonl`. That derivation can never succeed in
production, because the `PreToolUse` payload carries the **parent** session's transcript path even
for a tool call made inside a subagent.

Four measurements, all re-derived on 2026-09-30, establish this:

1. **The field exists in the payload and is documented.** `agent_id` is a first-class `PreToolUse`
   input field in the installed client (`claude --version` → `2.1.273`), described verbatim as:
   *"Subagent identifier. Present only when the hook fires from within a subagent (e.g., a tool
   called by an AgentTool worker). Absent for the main thread, even in `--agent` sessions. Use this
   field (not `agent_type`) to distinguish subagent calls from main-thread calls."* `agent_type`
   sits beside it: *"Present when the hook fires from within a subagent (alongside `agent_id`), or
   on the main thread of a session started with `--agent` (without `agent_id`)."*
2. **A live probe confirms the shape.** A nested session with a single `PreToolUse` hook dumping its
   stdin captured two rows: the spawning `Agent` call on the main thread had **neither** field; the
   `Bash` call made inside the subagent carried `agent_id: abdf3d8dfa6b9c67a` and
   `agent_type: general-purpose`. **`session_id` and `transcript_path` were the parent's on both
   rows** — which is both why the derivation fails and why all of it lands in one ledger file.
3. **The consequence is total.** Every `kind:"call"` row in every loop ledger on this machine —
   3048 rows across 6 ledger files at time of writing, a count that only grows — carries
   `agent_id: "main"`. No other value has ever been written.
4. **The correct pointer is derivable from the payload alone.** With `transcript_path` and
   `agent_id`, the path `<transcript_path minus ".jsonl">/subagents/agent-<agent_id>.jsonl` resolves
   to a real file, and the inner call's `tool_use_id` appears in it 2 times and in the parent
   transcript 0 times. No transcript scan is needed on the hot path.

The ticket's framing has been **superseded by (4)**: it hedged that "the fix has to come from a field
in the payload or from a different derivation" and proposed documenting the fan-out arm as
unreachable. A payload field exists, so the arm gets fixed rather than documented as dead.

### The three failures this causes

| # | Failure | Where |
|---|---|---|
| 1 | The `fanout` arm of tier 1 is **unreachable**. It fires on `na > 1`, where `na` counts distinct `agent_id` values — always exactly 1. The one case a shared global ledger exists for is the case it cannot report. | `hooks/lib/loop-index.sh:149,167,180-182` |
| 2 | The stored `transcript` pointer is **wrong for every subagent call**: it names a file that does not contain that `tool_use_id`, so any resolver finds nothing and cannot distinguish that from an empty result. | `hooks/lib/loop-index.sh:84` |
| 3 | Tier 3 resolves that pointer to extract each call's arguments for the model. Its only guard is `[ -f "$tpath" ] || continue` — which **passes**, because the parent file does exist. The following `jq` matches no `tool_use` with that id, the call contributes nothing to `detail`, and the emitted verdict carries no field recording that evidence was missing. When every flagged call is a subagent call, `detail` is empty and the stage silently marks the turn instead of judging. | `hooks/lib/loop-verdict.sh:113-122,144-148` |

### Why the suite stayed green

`hooks/lib/test-loop-index.sh:29` defines
`SUB_TP="/tmp/proj/${SID}/subagents/agent-abc123.jsonl"` and the fan-out arm **is** exercised with it
at lines 248-263. The fixture differs from production input in the single field the code under test
parses, which is the hazard named in
[`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Test Conventions](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#test-conventions):
*"A fixture MUST match production input in every field the code under test PARSES."*

### What is known about the tier-3 judging stage, and what is not

Binding on Scope item 8, and stated here so no later reader over-claims it:

- The judging stage is **off by default in code** — `hooks/lib/loop-verdict.sh:48`,
  `MODEL="${HARNESS_T3_MODEL:-off}"` — and is enabled in the environment this ticket was written in.
- It has produced **exactly one** tier-3 verdict across the entire ledger corpus, an hour before the
  interview that produced this spec: `{"kind":"verdict","tier":3,"signal":"semantic-repeat",`
  `"bin":"echo","repeats":10,"turn_calls":46,"verdict":"progress","model":"haiku","reason":`
  `"PROGRESS Deliberate diagnostic workflow tracing GH-33 through context, schema investigation,`
  `probe execution, and path verification."}`
- That judgement was correct **and was made on complete evidence**: no subagent had been spawned at
  that point in the session, so no flagged call's arguments were missing.
- Therefore **there is no observation anywhere of how the stage behaves on partial evidence.** This
  spec does not claim the stage judges partial evidence well or badly. Closing that gap is precisely
  what Scope item 8 exists for.

## Scope

1. **Read `agent_id` from the payload** in `hooks/lib/loop-index.sh`, defaulting to `"main"` when
   absent. Replaces the `transcript_path` regex derivation entirely — the old derivation is removed,
   not kept as a fallback, because it has never once produced a non-`main` value and a fallback that
   cannot fire is indistinguishable from a bug.
2. **Store the correct `transcript` pointer**: the derived subagent path when `agent_id` is present,
   the payload's `transcript_path` unchanged when it is absent.
3. **Store `agent_type`** as a diagnostic field beside `agent_id`.
4. **Fix the fixtures so they are production-shaped**, and add a regression guard that fails against
   the old derivation (see AC5). This is the minimum the fix requires; the broader fixture-realism
   sweep stays with #49.
5. **Update the prose that asserts the arm is unreachable**, which becomes stale the moment this
   ships. Known surfaces: `docs/claude-tools-hierarchy.md:101,110`, `agents/inspector.md:66,117`,
   `skills/inspect/SKILL.md:79-80`, `scripts/loop-metrics.sh:232-241` (comment) and `:313-320`
   (the `complete` comment), `hooks/lib/loop-index.sh:14-17` (header comment).
6. **Reword the `stored_agent_ids == ["main"]` NOTE** at `scripts/loop-metrics.sh:357-358` so it
   attributes the blindness to the build that **wrote** the ledger, not to the build reading it. No
   schema field, no ledger migration and no date/version boundary — see § Key decisions.
7. **Cross-check the recovered attribution against the stored one, with a per-call link.**
   `scripts/loop-metrics.sh --for` already recovers attribution by `tool_use_id`
   (`:231-275`) and already carries `stored_agent_ids` (`:323`). This task turns those two
   independent records into a comparison that **references** the record it confirms or refutes, and
   uses the now-trustworthy stored field to close the residual `complete` could not cover.
8. **Record the volume of evidence the tier-3 model answered on**, as a counter on the tier-3
   verdict row in `hooks/lib/loop-verdict.sh`. The counter does not make the model better; it makes a
   `progress` verdict reached on complete arguments distinguishable from one reached on half.
9. **Bump `.claude-plugin/plugin.json`** patch version — this is plugin-loaded content.

### 7 in detail — what the cross-check is, concretely

The recovered census and the hook's record answer the same question by different means. Today they
sit side by side and no reader is told whether they agree. After this change:

- **The link is the `tool_use_id`.** It is the ledger row's identity and is already declared the join
  key by this reader's own footer (`scripts/loop-metrics.sh:375`). A recovered attribution that
  refutes the stored one names the exact ledger row it refutes and quotes the value that row stored —
  it does not sit beside it as an independent observation.
- **`attribution.agreement`** carries, for the calls where both records exist (i.e. excluding
  `unattributed`, where the reader has no opinion): `checked`, `confirmed` (stored equals recovered),
  `refuted` (stored differs), and `refutations` — a bounded list of
  `{tool_use_id, stored, recovered}`. The counts are complete; the list is the concrete link and is
  capped so a wholly pre-fix ledger cannot emit hundreds of rows.
- **`attribution.every_stored_agent_read`** closes #71's named residual. #71 could not enumerate the
  transcripts that ought to exist, *"because the ledger field that would be that list is the broken
  one"* (`scripts/loop-metrics.sh:313-320`). After item 1 that field IS the list: for every id in
  `stored_agent_ids` other than `"main"`, a transcript must have been opened and parsed. This joins
  the `complete` conjunction. On a pre-fix ledger `stored_agent_ids == ["main"]`, so the leg is
  vacuously satisfied and no historical ledger changes verdict.

### 8 in detail — what the counter is, and what it deliberately is not

- **It is a counter, not a gate.** The stage keeps judging on whatever evidence it has. Refusing to
  judge on partial evidence was considered and deliberately **not** adopted.
- **Its purpose is to record the volume of evidence**, so the reader of a verdict can weigh it. That
  purpose determines the shape: two integers, not a boolean and not a ratio.
- **"Unresolved" means the flagged call contributed no argument text to `detail`** — whatever the
  cause: the stored pointer names a file that is absent, or names a file that does not contain that
  `tool_use_id` (failure 3 above, the common case today), or the line would not parse. Truncation to
  `MAX_ARG` is not unresolved.

## Out of scope

- Any change to `session_id` handling or to the one-ledger-per-session layout. The payload gives the
  parent's `session_id` for subagent calls, and that is *correct* for this design: the shared ledger
  is what makes cross-agent fan-out detectable at all (`hooks/lib/loop-index.sh:27-33`).
- `hooks/lib/loop-result.sh`. It records outcomes keyed by `tool_use_id` only and derives no
  `agent_id`, so it carries none of this defect.
- **Retiring the #71 read-time recovery** (`scripts/loop-metrics.sh:231-275`). It stays: historical
  ledgers have no usable `agent_id`, a hook can always fail to fire, and it is now half of the
  cross-check in Scope item 7.
- **Making tier 3 refuse to judge, warn, or change its verdict on partial evidence.** Explicitly
  considered and declined. The counter records; it does not decide.
- **Any schema field, ledger migration, or reader-side date/version boundary distinguishing a
  post-fix `main` from a pre-fix `main`.** See § Key decisions — the defect there is one of wording.
- The general fixture-realism audit across the harness — issue #49, *"Three checks that ran and could
  not fail"*.
- Tuning the fan-out threshold. `na > 1` is the existing condition and is unchanged; this task makes
  it reachable, and the sessions after it are the measurement.
- Tuning `MIN_BIN` / `HARNESS_T2_MIN_BIN`, or changing whether the judging stage is on by default.

## Deferred

| What | Why | Separate ticket? |
|---|---|---|
| Whether `na > 1` is the right fan-out bar once the arm actually fires | No data exists yet — the arm has never fired. The verdict line already records `agents` and the threshold it fired under, so the calibration arrives on its own. | Only if the first real firings show it is wrong |
| Making **total** tier-3 evidence loss visible | When *no* flagged call resolves, `hooks/lib/loop-verdict.sh:122` marks the turn and writes **no tier-3 row at all**, so the counter — which lives on that row — cannot report it. The only existing signal is a tier-2 row with `judged:true` and no tier-3 sibling, and that is weak: four other bail paths (`:123`, `:131`, `:132`, `:141`) produce the identical shape. Naming which one bailed is a new row kind, which is beyond "the counter". | Yes, once the counter has produced a distribution worth reading |
| Whether the tier-3 model's judgement degrades on partial evidence | Unmeasurable today — one verdict exists in the whole corpus and it was made on complete evidence. The counter is what makes the question answerable later. | No — it is the counter's own follow-up |

## Key decisions

| Question | Decision |
|---|---|
| Payload field or a different derivation? | The payload field. `agent_id` is documented, measured present, and free — the fix *removes* a regex test and two `sub()` calls from the single hot-path `jq`, so it is strictly cheaper than what it replaces. |
| Keep the `transcript_path` derivation as a fallback? | No. It has produced `main` for 3048/3048 rows; a fallback that has never fired is untested code that looks like coverage. |
| Does the ledger's `agent_id` spelling change? | No, and this is load-bearing. The payload's `agent_id` is `abdf3d8dfa6b9c67a`; `scripts/loop-metrics.sh:273-274` recovers the same id as `basename` minus the `agent-` prefix — `abdf3d8dfa6b9c67a`. The two surfaces already agree, which is what makes the cross-check possible with no translation layer. |
| Store `agent_type`? | Yes, as a **diagnostic field only**. It names which agent type duplicated work in a fan-out report. **No detector may key on it** — the client's own contract warns it is present on the main thread of an `--agent` session *without* `agent_id`, so keying a subagent test on it would misclassify that session. |
| Must the derived pointer exist when the hook writes it? | No, and it must not be checked. At `PreToolUse` the subagent transcript may not yet be on disk for the first call in that subagent. The ledger is an index resolved later; a `[ -f ]` guard on the hot path would both cost a stat and store a knowingly-wrong pointer in the one case it fired. |
| Migrate existing ledgers? | No. Rewriting them would violate the append-only ledger contract, and tier 1's 20-row window ages pre-fix rows out within a turn. |
| Verdict-line schema for `fanout`? | Unchanged. `agents` is already emitted (`hooks/lib/loop-index.sh:196-200`); it has simply always been 1. |
| **Q1 — what happens to the #71 read-time recovery?** | It **stays and is cross-checked against the stored record**. Two independent records of the same fact are worth having, but only if the second says whether it confirms or refutes the first. The recovered attribution must therefore **carry a reference to the stored record it disagrees with** — concretely the `tool_use_id` of the ledger row, plus the `agent_id` that row stored. See Scope § 7 in detail. |
| **Q2 — does tier 3 gain a missing-evidence field?** | **Yes, a counter — and only a counter.** Refusing to judge on partial evidence was offered and declined. The counter does not make the small model better; it records **the volume of evidence the model answered on**, so a `progress` verdict reached on complete arguments is distinguishable from one reached on half. That purpose is what makes it two integers (how many flagged calls went unresolved, against how many were flagged) rather than a boolean. |
| **Q3 — how does a reader tell a correct post-fix `main` from a pre-fix `main`?** | **By nothing new — the wording is the whole defect.** No schema field, no ledger field, no date or version boundary in any reader. The NOTE's own gate (`stored_agent_ids == ["main"]`, `scripts/loop-metrics.sh:357`) **already self-disables** for post-fix ledgers, and tier 1's 20-row window ages pre-fix rows out within a turn. What remains is that the NOTE attributes the blindness to the build *reading* the ledger when it is a property of the build that *wrote* it. Fix the sentence; add nothing. |

## Technical constraints

- **`hooks/` is a method surface.** No language, build tool, domain entity or ticket prefix may enter
  these files. Validation is the structural checks in `AGENTS.md` § Build & Test, not a test runner.
- **A hook that breaks is worse than a hook that is absent.** Every failure path in
  `hooks/lib/loop-index.sh` exits 0 in silence (lines 56-61, 86-96). A missing or malformed
  `agent_id` must take that same path — degrade to `"main"`, never error. The tier-3 counter is
  subject to the same rule: a counter that cannot be computed must not cost a verdict.
- **One `jq` invocation on the hot path.** `hooks/lib/loop-index.sh:71-86` runs before *every* tool
  call; per-call cost is the design constraint. The change stays inside that single invocation.
  Scope items 7 and 8 are **not** hot-path work: item 7 runs in `/inspect`, item 8 once per turn.
- **The tier-3 detail loop is a SUBSHELL.** `hooks/lib/loop-verdict.sh:107-121` is
  `detail=$(… | while … done)`. A variable incremented inside that `while` body is discarded with the
  subshell, so the naive counter reports `0` forever while every assertion about it passes — hazard
  (4) in [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Tooling](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#tooling).
  The count must leave that subshell by a mechanism the design names explicitly, and a test must fail
  if it does not.
- **One flagged call can yield MORE THAN ONE line of argument text.** The probe in § Problem
  measurement 4 found the inner call's `tool_use_id` twice in its own transcript. The counter is
  therefore **per flagged call** — did this call yield any text at all — never per line of `detail`.
- **`repeats` and the flagged count are derived twice, by different code.** The gate's `awk`
  (`:72-85`) counts the bin; the detail stage's `awk` + `jq select(.bin == $b)` (`:107-113`) iterates
  what should be the same rows. Emitting the flagged count explicitly rather than reusing `repeats`
  is deliberate: a disagreement between the two derivations then becomes visible on the row instead
  of being assumed away.
- **Propagation Rule — the Inspect group fires, for all of items 5, 6, 7 and 8.** Per
  [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Propagation Rule](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#propagation-rule),
  an edit to `agents/inspector.md` or to a reader's emitted fields must be matched across
  `skills/inspect/SKILL.md`, `agents/inspector.md`, and the output contracts of
  `scripts/session-events.sh` and `scripts/loop-metrics.sh`. Four vocabularies for one mechanism, so
  a token sweep reaches at most one — the named row is the coverage. New fields
  (`attribution.agreement`, `attribution.every_stored_agent_read`, the tier-3 counter) each need a
  reading instruction in `agents/inspector.md`, not merely an emission.
- **`docs/claude-tools-hierarchy.md` must be updated in the same PR**, because this changes a Hook
  contract (the ledger's `agent_id` and `transcript` fields, and the tier-3 verdict row).
- **The fan-out fixture must carry the parent's `transcript_path` on every row** and differ only in
  `agent_id`, or it reproduces the defect that hid this bug.
- **`complete` stays a measurement, not a claim.** #71 made it the conjunction of what *can* be
  checked (`scripts/loop-metrics.sh:313-320`). The new leg is admissible only because it is equally
  checkable; it must not reintroduce an assertion the reader cannot verify.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | `hooks/lib/loop-index.sh` sets the ledger's `agent_id` from the payload's `.agent_id`, and to `"main"` when that field is absent. No code path in the file reads `transcript_path` to determine the agent. |
| AC2 | When `.agent_id` is present, the ledger row's `transcript` is `<transcript_path with a trailing ".jsonl" removed>/subagents/agent-<agent_id>.jsonl`. When absent, it is `transcript_path` verbatim. |
| AC3 | The ledger row carries `agent_type` from the payload, degrading to the file's existing absent-field convention when it is not sent. No detector branch in `hooks/lib/loop-index.sh` or `hooks/lib/loop-verdict.sh` reads it. |
| AC4 | `hooks/lib/test-loop-index.sh` exercises the `fanout` arm with payloads that are production-shaped: identical parent `transcript_path` on every row, distinguished only by `agent_id`. The arm reports fan-out, names the agent count, and the ledger shows one fingerprint across several `agent_id` values. |
| AC5 | **Regression guard against the old derivation.** A payload whose `transcript_path` is a `…/subagents/agent-<id>.jsonl` path but which carries **no** `agent_id` is recorded with `agent_id: "main"` and with that `transcript_path` stored unchanged. This assertion fails against the pre-fix code and is the permanent encoding of the defect. |
| AC6 | A test asserts the derived pointer is stored even when the target file does not exist on disk, pinning the § Key decisions choice not to stat it. |
| AC7 | **The cross-check exists and links.** `scripts/loop-metrics.sh --for … --json` emits `attribution.agreement` with integer `checked`, `confirmed` and `refuted`, and a `refutations` list whose every element carries the `tool_use_id` of the ledger row, the `agent_id` that row **stored**, and the agent the reader **recovered**. Calls the reader could not attribute are excluded from all three counts and remain reported by `attribution.unattributed` alone. |
| AC8 | `refutations` is capped at a fixed small bound, and `refuted` is the **full** count regardless of that cap. A test builds a ledger with more refutations than the cap and asserts both: the list is capped, the count is not. |
| AC9 | **The human-readable `--for` output renders the disagreement**, naming at least one refuting `tool_use_id` with both values. A disagreement visible only in `--json` does not satisfy this. |
| AC10 | **`attribution.every_stored_agent_read`** is emitted and joins the `complete` conjunction: for every id in `stored_agent_ids` other than `"main"`, a transcript at that session's `subagents/agent-<id>.jsonl` was opened and parsed without error. Tests cover both branches, and a test asserts that a ledger whose `stored_agent_ids` is exactly `["main"]` satisfies the leg vacuously — so no pre-fix ledger changes its `complete` verdict. |
| AC11 | **The tier-3 verdict row records the volume of evidence.** The `kind:"verdict", tier:3` line carries two integers, always present: how many `kind:"call"` rows in the judged turn matched the flagged bin, and how many of those contributed **no** argument text to `detail`. Not a boolean, not a ratio. |
| AC12 | **The counter survives the subshell.** `hooks/lib/test-loop-verdict.sh` asserts a non-zero unresolved count on a turn where some flagged calls resolve and others do not — an assertion that fails if the count is computed inside the `while` body and never leaves it. A second case asserts the count is `0` when every flagged call resolves, so the test cannot pass by the counter being stuck at either end. |
| AC13 | A test covers the failure-3 shape specifically: a flagged call whose stored `transcript` names a file that **exists** but does not contain that `tool_use_id` counts as unresolved. A `[ -f ]`-only notion of resolution fails this. |
| AC14 | Tier 3 still emits its verdict on partial evidence — the counter changes no verdict, no exit path and no threshold. A test asserts the same `verdict` value is produced with and without unresolved calls, given the same model answer. |
| AC15 | **The NOTE attributes the blindness to the writing build.** `scripts/loop-metrics.sh:357-358`'s emitted string states that the build that **wrote** this ledger stored `agent_id=main`, that fan-out detection was blind **while that ledger was being written**, and that the recovered attribution is analysis-only for this session. It contains no claim about the build currently reading it. A test asserts the string on a pre-fix-shaped ledger and asserts the NOTE is **absent** on a ledger carrying real `agent_id` values. |
| AC16 | **No schema, ledger or reader change was made for Q3.** No new ledger field, no migration, and no date or version comparison appears anywhere in the diff for the purpose of distinguishing pre-fix from post-fix rows. |
| AC17 | No instruction file, comment, or emitted string still asserts that the fan-out arm is unreachable or that `agent_id` is always `main` on a current build. Verified against the surfaces named in Scope item 5, and `agents/inspector.md` additionally tells the reader how to read `attribution.agreement`, `attribution.every_stored_agent_read`, and the tier-3 evidence counter. |
| AC18 | `.claude-plugin/plugin.json` patch version bumped. |
| AC19 | All five structural checks in `AGENTS.md` § Build & Test green, including `bash scripts/check-references.sh` and every named suite — with `hooks/lib/test-loop-index.sh`, `hooks/lib/test-loop-verdict.sh` and `scripts/test-loop-metrics.sh` passing, and the `bash -n` gate run in its mandated `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` form with its processed file COUNT checked, not only its exit status. |

## Open questions

None outstanding. All three round-1 questions are answered and recorded in § Key decisions; the
items that remain genuinely unmeasurable are in § Deferred, each with the measurement that will
settle it.
