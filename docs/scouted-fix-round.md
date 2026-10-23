# The review-fix round — the scouted-plan sequence

> Extracted from `${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md`, which carried it until the two
> task-flow pages reached the instruction-file size cap between them. This is METHOD: it holds in
> every project and names no language, build tool, domain entity or ticket prefix. It is loaded when a
> review round actually runs, which is the only time any of it applies.
>
> **The binding obligation lives in `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` § Step 11 and is not
> repeated here** — that page is always in context and this one is not, so an obligation moved here
> would be an obligation a round could miss. What is here is the procedure: the spawn prompts, the
> plan format, the reason-token vocabulary and the narrative behind each beat.

## Step 11 — the scouted-plan sequence (recipe)

The round's five beats, per the Scouted-plan AXIOM in `SKILL.md`. The gate script owns every number in the round: the baseline it measures against, the threshold the **one** size check fires on — the pre-apply gate, on the plan's declared total — and the verdict both agents are judged by.

**Beat 1 — baseline (orchestrator, one call).**

```
"${CLAUDE_SKILL_DIR}"/scripts/check-fix-plan.sh baseline ai-docs/plans/YYYY-MM-DD-name.progress.md
```

It appends the round's `## Fix Plan (Round N)` stub — the heading, the three header fields and the table heading — and prints the tree sha it recorded. The orchestrator transcribes nothing: the sha reaches the plan by the script's own write, so it cannot be mistyped, and a later caller cannot substitute a baseline of its own choosing. Exit 2 means the round could not be baselined, which is not a pass.

**Beat 2 — plan (`fix-scout`, fresh context).**

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/fix-scout.md and follow it.
  Progress: ai-docs/plans/YYYY-MM-DD-name.progress.md
  Round: N
  Fill the stub's table, and the two header fields `baseline` deliberately left
  empty: **verification:** and **declared_changed_lines:**. Do not touch
  **round_base:** or any other round's section.
")
```

**The spawn prompt names which fields the scout fills, and that sentence is load-bearing.** The gate refuses an empty `verification` and an absent `declared_changed_lines`, so a brief telling the scout the stub is untouchable contradicts the gate it feeds — and the first real run produced exactly that, with the scout filling them anyway and naming the contradiction. The stub's emptiness is a feature, because a placeholder would satisfy the verification arm; the brief has to say which half of it is the scout's.

The scout fills the table — **at least one** row per open finding, `#` copied from the findings table, a closed-vocabulary `Disposition` (`fix` / `object: <reason>` / `resolved: <reason>` / `amendment: spec` / `amendment: design` / `redline: <type> — <what shipped instead>`), the target `file:line`, the expected changed lines on the basis the column heading names, and either `none` or the quoted artefact sentence Arm A puts at stake. A finding whose remedy spans several files takes a row per file; what is refused is a finding in no row, or a row matching no open finding:

```markdown
| 1 | fix | <path>:<line> | 12 | none |
```

Canonical schema, header fields and the counting basis: [`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` § `Fix Plan (Round N)` sections](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md#fix-plan-round-n-sections).

**Beat 3 — gate (orchestrator, one call).** `check-fix-plan.sh plan <progress-file>`, then read the `decision=` token. The verdict is one header line plus one line per arm; every arm prints its own line whether or not it wins the decision, so a plan with two faults shows both and the header names the one being acted on.

| Reason token | Arm | Decision |
|---|---|---|
| `anchor-unresolved` | A1 | `REFUSE` — a `Target` or Arm-A anchor names a missing file or a line past its end |
| `arma-quote-unverified` | A1 | `REFUSE` — the Arm-A anchor resolves but the sentence it quotes is not at that line: no fragment of the quote is found within the window the header reports as `arma_quote_window`, the fragments are present out of order, or one is under 24 characters and so too short to locate. The remedy is re-read the file, not renumber the anchor. Whitespace is normalised and `…` elision is honoured, so re-wrapping and quoting in parts both pass |
| `spec-amendment` | A2 | `ROUTE-SPEC` — a **`fix`** row whose target is under `ai-docs/plans/**/*.spec.md`, or an `amendment: spec` disposition whatever its target. The path half keys on a row that PROPOSES an edit, because what it catches is an attempt to have the fix agent edit a spec artefact; a row proposing none — `object:`, `resolved:` — does not route on its target alone, or a finding already closed by an approved amendment could not be recorded truthfully |
| `design-amendment` | A3 | `ROUTE-DESIGN` — the same two detections, and the same `fix` qualifier on the path half, for `*.design.md` |
| `declared-sum-mismatch` | A4 | `REFUSE` — the header's total disagrees with its own rows, or either is not an integer |
| `size-over-threshold` | A4 | `ESCALATE` — the rows sum past the threshold the verdict names |
| `verification-missing` | A5 | `REFUSE` — no verification named, so the round expects nothing re-run |
| `no-plan-section` | A6 | `REFUSE` — no `## Fix Plan (Round N)` section to parse |
| `plan-row-malformed` | A6 | `REFUSE` — a row whose cell count is not 5, usually a raw `\|` in free text |
| `finding-coverage` | A6 | `REFUSE` — an open finding is absent from the plan, or a row's disposition is out of vocabulary (including a reason-carrying token with an empty reason) or its Arm-A cell empty. Several rows for one finding is **not** a fault |
| `plan-row-unmatched` | A6 | `REFUSE` — a row whose `#` matches no open finding; such a row pre-authorises a file the review never raised |
| `arma-unaccounted` | A7 | `REFUSE` — a `fix` row closes a finding whose `Arm A` cell names a spec or design sentence and no row accounts for it, so the round would ship a divergence with nothing recording it. The remedy is a `redline:` row for that finding, not a reworded `Arm A` cell. **Evaluated last of the plan arms**, so a round that routes or is under-covered reports that instead. **The verdict line labels this arm `redline-accounting` while the decision carries `arma-unaccounted`** — look the row up by the token, not by the label |

**On `REFUSE`:** hand the verdict back to the same `fix-scout` for a rewrite — **max 3 rounds**, then surface the verdict to the user and stop. On `ROUTE-SPEC` / `ROUTE-DESIGN` the amendment recipes above own the round and no fix agent runs. On `ESCALATE` the user sees the declared total and the threshold and decides.

**Beat 3b — mark (`design`, fresh context), once per round carrying a `redline:` row and BEFORE the apply**, on `${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Redline marking: it appends every marker and promotes every row.

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/design.md § Redline marking and follow it.
  Design: ai-docs/plans/YYYY-MM-DD-name.design.md
  Log:    ai-docs/plans/YYYY-MM-DD-name.redline.md
  Progress: ai-docs/plans/YYYY-MM-DD-name.progress.md
  Round: N
  Mark every `redline:` row of that round's ## Fix Plan section and nothing else.
")
```

**Both the record and the round number are passed, and neither is derivable by the agent.** It writes keys built as `R<round>.<finding #>` and derives each row from that round's plan table, so a guessed round number produces keys that agree with each other and belong to different findings — and the post-apply arm then reports the keys it expected as missing. The round is a fact the orchestrator holds; a fresh context can at best take the highest-numbered plan section, which is a different thing.

**Beat 4 — apply (`fix-apply`, fresh context), only on `PASS`.**

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/fix-apply.md and follow it.
  Progress: ai-docs/plans/YYYY-MM-DD-name.progress.md
  Round: N
  Apply the `fix` rows of that round's ## Fix Plan section and nothing else.
")
```

**Then the orchestrator's own two acts, in this order.**

1. **Confirm the write landed** — `stat` the files the plan named and `grep` for the changed text, per the Design Amendment recipe's existing mtime+grep wording. The party that applied the change is not the only party asserting it landed.
2. **Gate the applied diff** — `check-fix-plan.sh applied <progress-file>`. It reads the `round_base` out of the gated plan section and reports `decision=FINDING` on either of **two** independent arms — `reason=unplanned-file` when the diff touched a path no `fix` row named, and `reason=redline-undelivered` when a `redline:` row's `[REDLINE R<round>.<finding #>]` marker did not reach the design or its row did not reach the log, naming which key is missing from which file — and `decision=OK` only when both pass. So a round whose marking record did not land reports a defect with NO unplanned path in it. Its only remedy is another marking invocation for the named keys then a re-run of this verb, and **that corrective invocation completes the round's one marking pass rather than being a second one** — which is what Beat 3b's bound means. It is also the last repairable moment: after the round closes nothing reads the log again, the pairing check is run only by the marking pass itself, and the closing fold strips every marker. The header carries `actual_changed_lines=<n> ignored=<k> binary=<m>`, so nothing is excluded from the count invisibly. **`actual_changed_lines` is a MEASUREMENT and nothing fires on it** — the post-apply size arm and its `actual-overrun` token are withdrawn, so the verb runs two arms and reports one figure for a human to read. The threshold appears in `plan`'s header only, which is the one place it is enforced.

   **Four path classes are excluded from the `unplanned-file` arm, and the exclusion is a narrowing, not an amnesty**: A2/A3 refuse any passing plan that **proposes an edit** to a spec or design suffix, so every change to one is unbriefed by construction either way. **The header's `ignored=` is a count only; the `excluded-in-round` line is the one place the paths are named.** Whenever the verdict carries that line, the orchestrator reads it and accounts for every named path against the amendment or the marking pass it knows it ran; a named path it cannot account for is a finding. That discrimination cannot be delegated to the gate — an approved amendment's edit and a fix agent editing a spec it was never briefed to touch produce an identical diff, and only the orchestrator holds the fact that separates them. Which four classes, and why each is there: [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § Why four path classes are excluded from the unplanned-file arm](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#why-four-path-classes-are-excluded-from-the-unplanned-file-arm).

A `FINDING` is a finding to act on — it goes into the round like any other, never written off as a convenience. Exit 2 from `applied` means the round has no usable baseline, which is not a pass.

**Beat 5 — the post-apply micro-loop (orchestrator).** Unconditional: it runs after the apply and before the full review pass, on every round, with no exemption. Beat 1 of it is the `applied` call above. What follows:

| # | Act | Bound |
|---|---|---|
| 2 | **ONE bounded question**, spawned once | Three fixed inputs, assembled by the orchestrator so the question cannot widen them by reading more: the round's own plan section, the applied change, and the `applied` verdict's list of files no row named. **Nothing else** — not the findings table, not the spec, not the session history. It asks whether what was done matches what the plan said, **naming the row and the divergence**. Output is **exactly one of `MATCH` or `DIVERGE`, plus a reason**, and an answer outside that two-word set is **refused, not interpreted** — the `record` verb's `<answer>` argument computes that refusal, so it is a check rather than a judgement, which is what stops the bound eroding one hedged sentence at a time. No authority to apply, none to decide rework: it may not edit and may not re-run the fix |
| 3 | **On `DIVERGE`, re-spawn `fix-apply`** with that divergence named | The re-fix brief carries the named row and divergence and **nothing new** — it is not a fresh plan. A re-fix attempt is **not** re-planning, and `fix-apply`'s contract says so in those words; stop-and-return still binds within an attempt, and that return is what consumes the attempt |
| 4 | **On a burned cap, surface to the user** | Fixed shape, so the user does not read it from scratch each time: which row (the finding number and the `Target`), what diverged (quoted from the question's reason, not re-derived), the attempts and what changed between them, and **exactly one** recommendation of `re-fix` / `amend-the-plan` / `accept` with one sentence of why. It recommends; the user decides |
| 5 | **The full review pass**, on every path | A burned cap ends the LOOP, not the gate — work done after the cap still gets its review pass |

**The cap is three attempts and it is counted in the round's plan section**, one bullet per attempt, written by the orchestrator before beat 3 re-spawns:

```
- attempt 2 — finding 5, row 1: the divergence named was <quoted reason>; re-fix dispatched
```

Why that location rather than a counter in the gate: [§ Why the attempt count lives beside the plan](#why-the-attempt-count-lives-beside-the-plan). **The bullet must NOT begin with `|`** — the gate reads any line in that section whose first non-space character is a pipe as a plan row, and one with the wrong cell count refuses the whole plan under `plan-row-malformed`. A leading `-` is invisible to that parser, a literal `|` in the quoted reason is then harmless, and the count is `grep -c '^- attempt '` over the section.

**Then record the loop, once, as it closes** — `check-fix-plan.sh record <progress-file> <iterations> <cost_tool_calls> <answer>`. It decides nothing and exits 0; it appends one verdict row carrying the loop's iteration count, its cost and the question's answer, which is what this loop's own retirement is read from. **All three arguments are required and none defaults:** a default would record a zero silently and the retirement rule would be read off a column of zeros — an absent figure is recoverable, a wrong one is not. **The cost unit is the number of orchestrator tool calls the loop consumed** (not wall-clock, not tokens), counted from the calls made for that loop and no others, which the attempt bullets make auditable. **`<answer>` is exactly one of `MATCH` or `DIVERGE`** — anything else is exit 2, and the word is written into the row rather than only checked, because a check whose input is discarded leaves no evidence it ran. A failed write never changes the round's outcome.

## Step 11 — review-fix narrative (detail)

For each `⬜ Open` finding in the latest `## Self-Review (Round N)` section — **classify before choosing a remedy**, per the Step 11 AXIOM in `SKILL.md`. The first question is not "how do I fix this" but *"would closing this leave a sentence in the spec or design untrue?"*; if yes, it is an amendment however the fix lands. A spec sentence merely broader than what shipped, or one another spec sentence overrides, is not left untrue; only a genuine conflict under [the base principles](${CLAUDE_PLUGIN_ROOT}/docs/plan-invariants.md#the-base-principles) counts.

- **Fix it** → the plan row says `fix` and `fix-apply` applies it; the orchestrator marks `✅ Fixed` once the applied diff is gated. **If the finding quoted a spec/design sentence, re-read that sentence in its file** and either confirm it true of the post-fix state or amend it — shipping what a sentence promised makes the sentence true only if the shipped thing does what it says.
- **Breaks the agreed approach** → trigger the **Design Amendment** recipe (user approval required); on return mark `✅ Fixed (design amended)`.
- **Diverges from a design sentence without breaking the approach** → the row says `redline: <type> — <what shipped instead>`; the round's one marking pass writes the marker and the log row; mark `✅ Fixed (redlined)`.
- **Requires a spec change** → trigger the **Spec Amendment** recipe; on return mark `✅ Fixed (spec amended)`.
- **Already closed before the round began** (an approved amendment settled it, and the tree already satisfies it) → the plan row says `resolved: <reason>` and nothing is applied. It is not an objection and not an exemption: the round still runs the whole sequence.
- **Object to it** (finding is wrong or intentionally out of scope):
  - `nit` / `minor`: Subagent may object autonomously — write reason, mark `⚠️ Objected: <reason>`.
  - `major` / `blocker`: **surface to user first** before objecting. User must approve.

After all findings are resolved, run gates (`%BUILD_CMD%`, the touched-scope checks over the round's touched paths per [`${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md`](${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md) — never the full list, which runs once after review approves — `%FORMAT_CMD%` to format then `%LINT_CMD%` as the gate), update `.progress.md`, re-read the PR body via `gh pr view --json title,body` (edit only if it contradicts new commits), and resolve every fixed review thread per [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR review comment resolution`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-review-comment-resolution).

## Rationale moved out of the always-loaded step text

Two passages the ordered step list used to carry inline. They explain WHY the step text is shaped as it
is; neither states an obligation, which is why they could move while the obligations could not.

**Why Arm A exists.** Keying only on the fix diff hands the routing decision to the same party that then
marks the finding `✅ Fixed`. The shape: a finding reports that a design's mitigation cites a check as the
thing that catches a failure, and that check has since been deleted. **Both remedies are valid** — ship
the check, or correct the sentence. Choosing the code-side remedy routes to the normal path **correctly
by a diff-keyed table**: the table is satisfied, not violated, while the sentence stays false. Nothing
between "choose fix" and "mark `✅ Fixed`" re-reads it. Two consequences follow, and the step text
carries both as obligations with their reasons left here: the two arms are checked in order, A first,
because choosing a remedy is what defeats the subject test; and the closing gate re-reads the cited
sentence in its own file, because shipping the thing a sentence promised makes the sentence true only if
the shipped thing does what the sentence says it does.

**Why the marking beat runs before the apply.** The `applied` verb asserts that the design carries each
`redline:` row's marker and the log carries its row, so a marking pass that ran afterwards would be
asserted against a tree that does not yet hold what it is about to write. The order is not a preference
between two workable sequences — one of them makes the assertion meaningless. The same assertion is why a
corrective marking invocation COMPLETES the round's one pass rather than being a second one: the
once-per-round bound is satisfied, not broken, by finishing a pass that did not land.

## Why the attempt count lives beside the plan

Three reasons, not one: the fix-plan gate recomputes from the tree on every invocation and holds no state
between them; the progress file survives a compaction and a session restart, which is exactly when a cap
is lost; and an attempt count written beside the plan it counts against is auditable by the same read that
checks the plan. The format constraint that follows from the gate's parser is stated where the count is
written, in [§ Step 11 — the scouted-plan sequence (recipe)](#step-11--the-scouted-plan-sequence-recipe).
