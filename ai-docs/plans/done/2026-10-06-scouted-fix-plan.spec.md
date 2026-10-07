# Scouted, mechanically-gated fix plan for review-fix rounds

**Source:** ticket GH-91
**Date:** 2026-10-06
**Tracked in:** GH-91

## Problem statement (derived, not a rewrite of the ticket)

`skills/task/SKILL.md` Step 8 carries a binding every-group handoff rule: the orchestrator never
executes subtask code in its own context. Step 11 (review fixes) carries no equivalent — it routes a
finding through the Arm A / Arm B table, then applies fixes, re-runs gates and loops, all in the
orchestrator's context at whatever size the session has reached.

The ticket's measured baseline (session `e330fc3e-e105-4690-8c78-37110ee25714`, GH-52 / PR #89) shows
the review loop was 55% of task cost, and **the orchestrator's share of that loop (58%) exceeded the
four review subagents' own share (42%)**. The cost mechanism is not that reviewing is expensive: the
cache-read term is 86% of per-turn cost and scales as `context_size × calls × 0.1`, so the same fix
round costs more the later it runs. The driver is therefore the NUMBER of orchestrator tool calls made
at a large context, not the size of the diff under review.

## Scope

1. Introduce a **scout** step at the front of the review-fix round **of the main feature-development
   flow (`/task` Step 11) only**: a fresh-context agent reads the round's `⬜ Open` findings and the
   `File:line` anchors they cite, and writes a **fix plan** artefact to disk.
2. Introduce a **mechanical gate** over that plan artefact — a checked-in script, following the
   `scripts/check-references.sh` precedent — that decides, without a model:
   - **anchor resolution** — refuse a plan whose cited `file:line` anchors do not resolve;
   - **amendment routing** — a plan routes to the Spec / Design Amendment recipe and never reaches
     the fix agent on either of two halves: a row that PROPOSES an edit (dispositioned `fix`) and
     names a `*.spec.md` / `*.design.md` path under `ai-docs/plans/` (active or `done/`), or a row
     dispositioned as an amendment, whatever its target. A row proposing no edit does not route on
     its target alone;
   - **size** — a plan whose declared total of expected changed lines exceeds the threshold escalates
     to the user instead of being applied;
   - **verification named** — the plan names the verification it expects to re-run;
   - the verdict records the **threshold value it fired under**, beside the decision.
3. Introduce a **fix agent**: applies the gate-passed plan in a fresh context, with the plan as its
   brief.
4. Rewire `/task` Step 11 so the orchestrator's own work in the round is reduced to the three
   non-delegable acts (below) plus verifying the applied diff against the plan. That verification has
   an **unconditional micro-loop**, run after the fixes are applied and before the full review pass: the
   mechanical check of which files were touched runs first and reports a file no row named; its result
   then feeds ONE bounded question asking whether what was done matches what the plan said, naming the
   row and the divergence; a mismatch sends the work back for re-fixing with that divergence named, up
   to three attempts, after which it escalates to the user with a process recommendation; and the full
   review pass runs afterwards either way. **There is no post-apply size arithmetic** — an earlier draft
   of this task compared the applied total against the declared one, and that comparison is withdrawn
   (AC18).
5. **The mechanism is always used — no small-round exemption.** Every review round carrying at least
   one `⬜ Open` finding goes scout → gate → fix agent, including a round with a single trivial
   finding.
6. Tests for every gate arm, including a planted unresolvable anchor and, for the amendment arms, a
   separate leg for each half of the routing rule and for its negative case: an edit-proposing row
   naming an artefact routes, a row dispositioned as an amendment routes, and a row proposing no edit
   while naming a real artefact does not route.
7. **Name the three excluded fix loops as follow-up work** (see § Out of scope 1) and file a tracking
   issue for extending the mechanism to them.
8. **Record the owed like-for-like cost measurement durably** (see § Key decisions) and report this
   task's own review-round figure with an explicit not-comparable note.
9. Propagation: the sync-group siblings of the edited files receive the corresponding change in the
   same PR, **and a new sync group is added for the mechanism this task introduces** — an anchor row
   naming every member plus one back-reference row (see § Technical constraints 6).
10. **Widen the plan's row format, on the evidence of the mechanism's first real run** (§ Technical
    constraints 12). The scout ran for real against the eight open findings of this task's own review
    round, produced a plan the gate reads as `PASS`, and reported four shapes of real round the format
    could not represent: a finding already resolved before the round began, a finding needing a code
    fix and its test leg planned together, a path the counting basis has no clause for, and a
    documented example that the gate's own extractor refuses. All four are fixed here rather than
    shipped narrow. Two further shapes it found are **not** fixed here — see § Deferred.

### The three acts that stay with the orchestrator (from the ticket, verbatim intent)

| Act | Why it cannot be delegated |
|---|---|
| Obtaining the **user's consent** | A subagent cannot obtain it; every escalation stays with the orchestrator. |
| **Routing into an amendment** | The Arm A / Arm B decision owns the spec/design artefacts and stays where the surfacing happens. |
| **Confirming the write landed** | The party that applies a change cannot be the only party that asserts it landed (mtime + `grep`, as the Design Amendment recipe already mandates). |

## Out of scope

1. **The three other fix loops that share this cost mechanism.** Verified in the tree on 2026-10-06:
   `docs/workflow.md` § Spec-Amendment group carries a *Fires in skill* table naming three sites —
   `/task` Step 11 (review fixes), `/bugfix` Step 5 (fix), `/project-review` fix loop — and
   `docs/workflow.md` § Post-push fix commits get self-review too is the fourth (the round that handles
   reviewer comments and CI failures after a change is already published; `skills/task/SKILL.md` routes
   there rather than re-entering `/task`). Only `/task` Step 11 is in scope here. The other three are
   named follow-up work, tracked per § Deferred.
2. **Per-step / per-agent spend instrumentation** — GH-90 (verified OPEN on 2026-10-06, title
   "Attribute task spend to flow steps and review agents, shown at Step 12 before push and recorded per
   task"). The ticket states explicitly that it does **not** block this work; measurement here is
   hand-rolled against the recorded baseline.
3. **Wrapping the structural suites in one checked-in script** — the ticket's final "Related" bullet
   proposes this as a cheaper orthogonal lever. It has **already shipped**: `scripts/run-checks.sh`
   exists on `main` (last touched by `ea90e33`). Not part of this task.
4. **A model-based size predictor.** The ticket rules this out by design: a fix's size does not exist
   before the fix does, so any pre-fix size judgement is a prediction. The gate measures the **plan**,
   which is text.
5. **A "touches a public signature" gate arm.** The ticket's flow diagram names it; the ticket's own
   § Acceptance does not. It cannot be made mechanical in a method file — detecting a public signature
   is language-specific, and a method file may not name a language (AGENTS.md § Project-specific
   conventions). Deferred with that reason rather than silently dropped.
6. Changing the review agents' judgement (what `self-review` looks for, its verdict vocabulary). Its
   **findings-table output contract** may be tightened where the scout depends on it — see
   § Technical constraints 7.
7. Re-measuring the baseline. It is recorded in the ticket and is taken as given.
8. **Re-calibrating the size threshold.** The starting value is chosen now (§ Key decisions); tuning it
   is what the recorded threshold value in each verdict exists to enable later.
9. **Any post-apply size arithmetic at all.** Neither a declared-vs-actual comparison nor an absolute
   check on the applied total ships: the post-apply size arm was specified, measured and **withdrawn**
   (AC18), and blast radius is covered instead by the pre-apply cap on the declared total (AC4) plus the
   post-apply question (AC23). The understated-plan residual the arm was once meant to narrow stays
   recorded in § Key decisions and § Open questions rather than closed here.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| Extending the mechanism to `/bugfix` Step 5 (fix), `/project-review`'s fix loop, and the post-push fix round | The user scoped this task to the main feature-development flow; these three share the cost mechanism but have no measured baseline of their own | **Yes** — one follow-up issue, filed as part of this task's delivery |
| The owed like-for-like cost measurement on the next real feature task | This task's own review round reviews instruction text and a check script, not feature code, so its figure is not comparable to the baseline | **Yes** — one follow-up issue, cross-referenced from `ai-docs/context.md` § Open questions |
| A "touches a public signature" gate arm | Cannot be mechanised without naming a language, which a method file may not do | No — recorded here with its reason |
| Turning the hand-rolled displacement measurement into flow-native reporting | Belongs to GH-90 | No — GH-90 exists |
| A declared-vs-actual size comparison on the post-apply arm | **Withdrawn rather than deferred.** It was specified as a trigger and then removed on measured evidence (AC18): the like-for-like subtraction it rested on did not come out equal on honest input, so it fired on honest plans. The question it was a proxy for is now asked directly (AC23), and a plan that honestly declares more than the cap is already stopped before any edit (AC4) | No — and no longer a revisit either. What would have justified revisiting was recorded spread data; with no post-apply arithmetic there is no spread to record, so this row is kept as the record of a mechanism tried and dropped rather than as pending work |
| A plan cell for a constraint the fix must PRESERVE (“do not disturb this passage”) | Found by the first real run: one row edits text two lines above a passage another criterion's verification depends on, and the fix agent reads only the plan, so nothing in it can say so. Deferred for three reasons, not one — it needs a new COLUMN rather than a new value in an existing one, it rests on a single observed case, and it is the only one of the six findings that requires deciding a SHAPE rather than stating a rule | **Yes** — one follow-up issue, with the observed case recorded as its evidence |
| A passing row for a finding whose SUBJECT is a spec or design artefact | Naming the artefact in `Target` routed the round (AC2, AC3) as those two criteria stood before this amendment, and an `amendment:` disposition still does, so such a finding had no passing row; the first real run worked around it by pointing `Target` at the finding's own row in the review table, which is undocumented. Deferred only to the extent the new `resolved:` token (§ Technical constraints 12b) does not already cover it — which is the first thing to check, since a finding closed by an amendment before the round is exactly that token's case | **Yes, conditionally** — file only if a case survives the `resolved:` token. **Settled here, so nothing is filed:** a case did survive the token and was then measured in a real round, and AC2/AC3's path half now fires only on a row that proposes an edit — so a `resolved:` or `object:` row naming the artefact is itself the passing row, and the undocumented workaround is no longer needed. |

## Key decisions

| Question | Decision |
|---|---|
| How wide does the mechanism go? | **The main feature-development flow only** (`/task` Step 11). The three other fix-applying loops become named follow-up work with their own issue. User's answer, round 1. |
| What does the size limit COUNT, and where does it start? | **Total lines the plan expects to change, starting near 150.** User's answer, round 1. Not a file count. The plan declares a per-target expected changed-line figure; the gate sums them and compares against the threshold. |
| Does choosing the number now remove the "record the threshold in the verdict" requirement? | **No.** The ticket requires a verdict to carry the value it fired under so the number stays recalibratable — a fixed starting value and a self-describing verdict are independent requirements. Both hold. **It applied to BOTH firing sites while there were two** — the pre-apply gate on the plan's declared total and the post-apply arm on the actual total. **Corrected: there is now ONE firing site.** The post-apply size arm is withdrawn (AC18), so the self-describing-verdict requirement binds the pre-apply escalation alone, and "one definition of the number, two places it fires" no longer describes the mechanism and must not be read as live. The requirement itself is undiminished — the one verdict that fires still carries the value it fired under (AC5) — and the recorded verdict now additionally carries each micro-loop's iteration count, its cost in orchestrator tool calls and the bounded question's answer (AC24) — the three figures that loop's own retirement is read from. |
| Is the plan's self-declared size checked again AFTER the fix is applied? | **Yes — against the same total-changed-lines limit of 150, as an absolute figure.** User's answer, round 2. Explicitly NOT "a share of what was declared" and NOT "any overrun at all against the exact declared figure": one number, used twice. **Accepted residual hole, recorded knowingly** — because both checks compare against 150 and neither compares the actual against the declared, a plan that declares 20 lines and changes 140 passes the pre-apply gate and the post-apply arm alike. That is the understated-plan case the post-apply arm was raised to close, and the single-number choice leaves it half-open. It was surfaced with that trade-off stated and chosen anyway; what the limit still guarantees is that **no round lands more than 150 changed lines without a human seeing it**, which is the property the escalation exists for. Do not read the arm as proof that a plan's declared figure was honest. **SUPERSEDED IN TWO STEPS, and the record above is kept because it is what was chosen then.** One later round replaced the absolute post-apply comparison with a trigger on declared-vs-actual agreement, because over two real runs the absolute figure produced a verdict nobody could act on — one round declared 54 lines and landed 743. The round after that **withdrew the post-apply size check altogether** (AC18), on measured evidence that the subtraction the trigger rested on does not come out equal on honest input. **So the answer to this row's question is now NO:** the plan's self-declared size is not checked again after the fix is applied, by any arithmetic, and neither "one number, used twice" nor the trigger that briefly replaced it may be read as live. **What survives:** the pre-apply escalation, which still stops at 150 and asks the user before any edit, serving consent and blast radius. **What covers the rest:** the direct question (AC23) — a plan declaring 20 lines and landing 140 is a diff that does not match its plan, and a plan that honestly declares 700 never got past the pre-apply gate. **The residual is unchanged and still accepted:** nothing reports a finding on the declared-vs-actual gap, and the question closes it as a question rather than by measurement. |
| Does a round with one trivial finding skip the mechanism? | **No — always used, no written exemption and no per-round discretion.** User's answer, round 2. It aligns with the rule it is modelled on rather than carving an exception: `skills/task/SKILL.md:128` binds Step 8's every-group handoff for "every group (including the first, including M=1)", and the same file's Step-skip gate carries "No 'too simple' exemption" — at **line 211** as the file now stands, re-derived by `grep -n`; an earlier round of this spec cited line 192, which the task's own edits to that file moved. Line 128 was re-checked and still holds. **Stated plainly, because it is a deliberate cost:** on a round with one trivial finding the mechanism costs more than it saves — three steps to fix one line — and that round runs net-negative. The ticket's displacement requirement does not absorb this: read verbatim, it asks to "State the before/after call count for **a real round**" — a per-round comparison, not an average across rounds, and the recorded baseline is itself per-round (3 / 29 / 19 / 10 / 5 calls). So the honest claim this task can make is that the mechanism displaces work on a round shaped like the expensive ones in the baseline, while a small round pays for the discipline. The reason to accept that is the one the user's answer names: an exemption is where the discipline leaks away. |
| How is the cost claim proved? | **Both legs.** This task's own review round is measured with the baseline's weights and reported **with an explicit note that it is not comparable** (instruction text and a check script, not feature code), AND the like-for-like measurement is recorded as owed by the next real feature task. User's answer, round 1. |
| WHERE does the owed measurement live? | **An entry in `ai-docs/context.md` § Open questions, keyed to a follow-up issue** — the register's existing convention, verified on 2026-10-06, when the register held four live entries (`GH-10`, `GH-11`, `GH-72`, `GH-75`), every one a ticket-keyed entry of exactly this shape — re-checked at the end of the task, when it holds **five**, the fifth being `GH-98`, which is the entry this task added under AC12 and which follows the same convention, and `GH-72` is the same kind of debt (a threshold never measured against a real firing, whose verdict line records the value it fired under so the calibration arrives on its own). `ai-docs/context.md` is profile, not method, which is correct: this is one project's measurement debt, not a rule for every project. |
| Plan per round, or plan per finding? | **Per round.** The ticket's acceptance section states the mechanism "adds one agent round-trip per review round", which fixes the granularity. The size threshold therefore applies to the whole round's plan. |
| How does the orchestrator keep Arm A routing while stopping re-reading every finding? | The plan carries a **per-finding Arm A judgement** ("would closing this leave a spec/design sentence untrue?") as text; the orchestrator decides on the plan's text, not by re-deriving from the findings. The ticket's own rationale requires this: it puts Arm A / Arm B "against **text** rather than against the orchestrator's intention". This resolves the apparent tension between "routing is non-delegable" and "an orchestrator that still reads every finding is a pure loss". **Flagged as an interpretive call** (raised in round 1, endorsed by the orchestrator rather than overruled) — design and review should challenge it explicitly rather than inherit it. |
| Is the gate prose or a script? | **A checked-in script.** The ticket calls it MECHANICAL, cites `scripts/check-references.sh` as precedent, and demands tests — prose cannot be tested. |
| Where does a method-half gate script live? | `skills/task/scripts/<name>.sh`, invoked as `${CLAUDE_SKILL_DIR}/scripts/<name>` per AGENTS.md § Project-specific conventions. Precedent: `skills/harness-init/scripts/`, `skills/pr-merged/scripts/`, `skills/report-defect/scripts/`. A repo-root `scripts/` path would not resolve in a consuming project. |
| Rewrite cap when the scout's plan is refused | **3 rounds**, matching every other loop cap in the flow (Step 7, Step 10, amendment recipes), then surface to the user. |
| Does the CLOSING GATE survive? | Yes. A finding that fired Arm A still may not be marked `✅ Fixed` until the cited sentence is re-read and confirmed or amended. Delegating application does not delegate that. |
| What does the Propagation Rule oblige for the three excluded loops? | **A divergence note, not the mechanism.** The Spec-Amendment group fires on edits to Step 11's amendment routing, and three of its members are files for the excluded loops. The Rule requires the *corresponding* change, not the identical one: each sibling records that the scouted-plan mechanism exists in the main flow, does not yet apply there, and names the follow-up issue. This is the NARROWER reading and does not widen scope past the user's answer. |
| Which arm wins when ONE plan is both unanchored and amendment-naming? | **The anchor check wins — such a plan is REFUSED and rewritten, never routed.** User's answer, round 5. The arms are evaluated in a fixed order and the FIRST failure decides: anchor resolution, then amendment routing, then size. Reasoning the user was shown and accepted: routing is the **expensive** path — it stops the work, asks the user, and re-runs the spec-writer, the design and the design review — so starting it on the strength of a citation that does not exist is the worse of the two outcomes, and the issue's own rationale is that a plan written without opening the anchors it cites is a prediction wearing a plan's clothes. **What the precedence does NOT decide:** the safety property all three criteria carry — such a plan never reaches the fix agent — holds under BOTH orders. The order decides which refusal the plan's author is shown, not whether a bad plan can be applied. Recorded because it was an ambiguity in the contract, surfaced by implementation rather than introduced by it: without it, one of the three criteria is false for this input class under any implementation. |

## Technical constraints

1. **Method/profile boundary (AGENTS.md § Project-specific conventions).** Everything this task writes
   under `skills/`, `agents/`, `docs/`, `rules/` is **method**: it may not name a language, a build
   tool, a domain entity, or a ticket prefix. Verified applicable — Step 11 lives in
   `skills/task/SKILL.md`, and a new agent would live in `agents/`. A project fact landing in a method
   file is a `major` finding. This is also why the "public signature" arm is out of scope, and why the
   owed-measurement entry goes to `ai-docs/context.md` rather than to a method file.
2. **`${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_SKILL_DIR}` path discipline.** Method-file paths are
   plugin-root-relative; project-data paths are repo-relative. A skill script is invoked by
   `${CLAUDE_SKILL_DIR}/scripts/<name>`, never a CWD-root path.
3. **Instruction-file size AXIOM.** The early warning is 35,000 chars and the hard cap 40,000.
   **Before** this task's change (measured 2026-10-06): `skills/task/SKILL.md` **26,947**,
   `skills/task/reference.md` **20,136**. **After** it, re-measured at the end of the task:
   `skills/task/SKILL.md` **29,183**, `skills/task/reference.md` **26,335** — so AC16 holds with
   roughly 5,800 chars of headroom, and the relief valve absorbed the larger share of the growth, as
   intended. Both pairs are kept: the before figure is what the constraint was written against, the
   after figure is what AC16 was checked against, and a single undated pair would read as current and
   be wrong within one round.
   Step 11's new machinery must not push `SKILL.md` over. The established relief valve is
   `skills/task/reference.md`, which Step 11 already uses for full recipes — detail goes there, the
   binding rule stays in `SKILL.md`.
4. **New scripts must be registered — and a `test-*.sh` and a `check-*.sh` register in OPPOSITE
   directions.** `scripts/run-checks.sh` derives its suite list from the tree via `git ls-files` **and
   asserts that derived list matches AGENTS.md § Build & Test item 4's list in both directions**. A new `scripts/test-*.sh` therefore requires the AGENTS.md list
   to be updated in the same change, or the `gate-inventory` member reddens. A skill-local test
   (`skills/task/scripts/test-*.sh`) must likewise appear in that documented list, as
   `skills/harness-init/scripts/test-scaffold.sh` and `skills/report-defect/scripts/test-file-report.sh`
   already do.

   **The new gate script is a `check-*.sh`, and for that class the registration runs the other way:
   it must be EXEMPTED, because it cannot be documented.** Both halves verified in
   `scripts/run-checks.sh` on 2026-10-06.
   - *Half one — it reddens the inventory until it is exempted.* The stray-check arm globs over
     **every tracked shell file** whose basename matches `check-*.sh`, wherever in the tree it sits,
     and reports each one that is neither a wired member nor named in the runner's `EXEMPT_CHECKS`
     string. A new `skills/task/scripts/check-*.sh` therefore reddens the `gate-inventory` member on
     the first run after it is added. That string carries a **prose comment enumerating why each
     current entry is exempt** (today: a delivery gate, and a promotion gate a skill calls on its own),
     so a third entry means amending the comment as well as the list — a list entry with no reason
     beside it is the shape the comment exists to prevent.
   - *Half two — it cannot instead be made a documented member.* The documented-member parser
     recognises only the `` `bash scripts/<name>.sh` `` spelling, and only inside AGENTS.md's
     structural-checks span; a skill-local path cannot take that spelling, so the two directions of the
     inventory comparison can never agree on it. The member table is additionally pinned **verbatim**
     by `scripts/test-run-checks.sh`, so wiring one in would mean amending that assertion too.
   - *Consequence.* The exemption is the **only** route, not a preference — and an exemption means the
     repo-wide runner never executes this gate, so the script's own `test-*.sh` suite (registered per
     the paragraph above) is the entire mechanical coverage it has. Write it accordingly.
5. **`git ls-files` lists tracked files only.** The shell-syntax gate's input set narrows silently on a
   task that CREATES scripts — run `git add -N <new paths>` first and read the processed file COUNT, not
   only the exit status.
6. **Propagation Rule — one existing group fires, and one new group must be CREATED.** Per
   `docs/propagation.md`:
   - Editing `skills/task/SKILL.md`'s *Spec Amendment / Design Amendment recipe* fires the
     **Spec-Amendment group**: `skills/bugfix/SKILL.md`, `skills/project-review/SKILL.md`,
     `agents/self-review.md`, `docs/workflow.md § Spec-Amendment group`. Step 11's Arm A / Arm B table
     IS that routing, so a change to it fires this group **regardless of the scope answer**. Three of
     those members are the excluded loops' own files — see the Propagation decision above for what they
     receive.
   - **The Task/Design group does NOT fire, and is not swept.** Its row in `docs/propagation.md` is
     scoped by its own parenthetical to `skills/task/SKILL.md`'s *design-phase / handoff contract*.
     This task edits Step 11 — the review-fix round — and spawns the scout and the fix agent directly
     rather than through the `/context-reset` handoff, so `agents/design.md`, `agents/design-review.md`
     and `skills/context-reset/SKILL.md` receive nothing: sweeping them would be three files touched
     with no corresponding change to carry. **Conditional, not absolute:** if the design ends up routing
     either new agent through the handoff contract, that row fires after all — re-read the row against
     the design before concluding either way, and do not inherit this bullet as settled.
   - `agents/self-review.md` and `skills/project-review/SKILL.md` are **Review group** members as well —
     `docs/propagation.md` states an edit to either fires BOTH groups, not whichever row is reached
     first.
   - A new agent contract additionally requires `docs/claude-tools-hierarchy.md` to be updated in the
     same PR, and the new agent's name must not clash with an embedded name there (AGENTS.md § Naming).
   - **This task must CREATE a sync group, not only sweep existing ones.** `docs/propagation.md`
     rule 4: when the thing edited is a *mechanism* rather than a phrase, the catch-all row at the
     bottom of the table is NOT enough — add a group. Rule 5 fixes its shape: **an anchor row naming
     every member, plus one back-reference row pointing at it**, never one row per member (which grows
     as the square of the group and drifts a member at a time). The scouted-fix mechanism is exactly
     that case. **As shipped the group is wider than this constraint first predicted** — anchored on
     the Step 11 sequence in `skills/task/SKILL.md`, with six named members: the recipe in
     `skills/task/reference.md`, the scout's brief, the fix agent's brief, the gate script,
     `docs/templates/progress-format.md` (which defines the plan section the sequence writes into) and
     `docs/workflow.md` § Spec-Amendment group (which carries the amendment routing the gate diverts a
     round into). Seven vocabularies for one mechanism, not the four predicted here before the group
     existed — the two that were missed are the template and the workflow page. A sweep keyed on any
     changed token still reaches at most one of them, which is the reason the group exists. The row is added in **this** PR,
     not left to the follow-up issue. Two mechanical consequences, both of which bite in this same
     change: every NEW path token the anchor row names becomes one more derived member of
     `scripts/check-propagation-arms.sh` (AC17 states the predicted count), and a derived member that
     no existing `case` arm in `hooks/hooks.json` matches needs a new arm here too — that gate asserts
     the arm set and the table agree, so a member with no arm is a `blocker` finding from the gate
     itself, not a later tidy-up.
7. **Findings input contract.** The scout reads the findings table `self-review` writes to the progress
   file: `| # | File:line | Severity | Finding | Status |`, with `⬜ Open` as the live status. Anchors in
   that table are re-derived by the reviewer, so they are resolvable at the time the scout runs — a
   non-resolving anchor is a real defect signal, which is why refusing on it is safe. If the scout needs
   a guarantee the current contract does not give, `agents/self-review.md`'s output contract is
   tightened (and the propagation groups in 6 fire).
8. **Version bump.** Any PR touching plugin-loaded content bumps `.claude-plugin/plugin.json`'s patch
   version (AGENTS.md § Project-specific conventions; `scripts/check-release.sh` enforces it).
9. **No result-masking in the new gate's invocation**, and the gate's own `.sh` internals are inside the
   checked-in-script carve-out. A gate mandated in prose is not yet a gate: verify the mandated
   invocation FAILS on a planted defect before writing it down.
10. **How the post-apply actual changed-line total is obtained.** From the VCS diff of the round's own
    applied change, not from the fix agent's report — the applying party cannot be the only party
    asserting its own size, which is the same principle as the write-landed confirmation. The command
    that produces it is subject to the counting-command hazard in `docs/agents-method.md` § Tooling: a
    count's exit status describes its INPUT, so the captured VALUE is compared, never chained on, and
    the derivation is not piped through a filter.
11. **Measurement method is fixed by the baseline.** Input-token equivalents at
    `fresh_input ×1 + output ×5 + cache_read ×0.1 + cache_creation ×2`, deduped by message id, per the
    ticket. Any figure reported under this task uses those weights or the comparison is void.
12. **The plan's row format — widened by the mechanism's first real run, and these four parts are
    binding.** The evidence is a real plan over eight real findings (every anchor resolved, declared
    54 of 150, gate reads `PASS`), so each part below is a shape the format demonstrably could not
    represent rather than a shape someone imagined.
    - **(a) At LEAST one row per finding, not exactly one.** A single finding may occupy several rows
      so that a code fix and the test leg that covers it are both named — which the format could not
      do while the `Target` cell was single-valued and a second row was impossible. **The coverage set
      check survives unchanged in both its refusing halves:** a finding appearing in NO row is still
      refused, and a row whose number matches no open finding is still refused. Only the
      "appears more than once" half is relaxed. That set check is the defect its own subtask was
      created to close, so relaxing the wrong half reopens it — the two halves are separately
      asserted, never as one combined test.
    - **Why rows and not a multi-valued cell.** Costed and rejected: the anchor arm reads only the
      FIRST token of the `Target` cell while the applied-diff arm matches the whole cell, so a
      two-path cell breaks both checks at once and both files are then flagged. Several rows leave
      every arm reading what it already reads.
    - **(b) A fifth disposition token, for a finding resolved BEFORE the round began.** The vocabulary
      stays **closed**, now at five. The new token is spelled `resolved: <reason>` — the design may
      respell the lexeme, but not weaken what it asserts: *the tree already satisfies this finding, no
      edit is owed this round, and this is not a dispute*. It exists because the only no-edit,
      non-routing token available was `object:`, which the contract defines as "the finding is not
      accepted" — false for a finding closed by an amendment, and the scout used it with a reason
      saying so in plain words rather than inventing a token. **An approximate token gets used when no
      exact one exists**, which is why the assertion is written down and not left to inference. Like
      `object:`, the reason is part of the value, so an empty reason is refused; the row declares 0
      expected changed lines; and it routes nothing.
    - **(c) The counting basis gains a clause for a gitignored path: it contributes 0.** The basis
      names new, deleted and binary files and says nothing about a path outside the measured tree,
      while the gate already charges 0 for one — which is how the progress file stays out of the
      measurement. The clause is written on the **declared** side, the total the pre-apply gate sums
      (AC4). **The applied side still MEASURES, and nothing fires on what it measures** — the
      distinction an earlier form of this clause collapsed. `check-fix-plan.sh:702` emits
      `actual_changed_lines=${actual} ignored=${ignored} binary=${binary}`, so an applied-side total IS
      computed and printed; what the withdrawal removed (AC18) is the COMPARISON, not the measurement.
      The clause therefore still governs how that figure is counted on both sides, and the sentence "no
      applied-side total is computed" is retired as false of the shipped gate. Absent the clause a scout
      can only guess, and this one over-declared by 1 to stay on the safe side.
      **The comparability OBLIGATION this clause carried is withdrawn with the arm it served; the
      asymmetry it described is not.** It said that a declared total and a measured total are not the
      same quantity and that whoever reports both owes the gap. No arm compares them any more, so
      nothing is refused or flagged on the difference — but both figures are still printed, the two
      classes of declared line invisible to the applied-side measurement still make them unequal on
      honest input, and a reader who sets one beside the other still owes the gap. What is retired is
      the GATE's obligation to reconcile them, not the arithmetic fact that they differ.
      **One residual, named rather than left to be rediscovered.** The predicate behind this clause is
      called on a plan `Target`, and a `Target` carries a line anchor, so an ignored path can read as
      not-ignored and the declared total can come out slightly HIGH. High is the safe direction — it
      moves the total toward the pre-apply escalation, never away from it — which is the same reasoning
      the zero-declaration obligation under (b) now rests on. It is recorded here because it was the
      measured defect that sank the withdrawn comparison, and on the declared side it survives as an
      inaccuracy that cannot hide work rather than as a hole.
    - **(d) Every documented plan example must parse under the gate's OWN extractor — and when this
      was written NEITHER of the two shipped examples did, for two independent reasons.** Measured
      2026-10-06, before the correction this task applies, by running the extractor itself over both
      cells rather than by reading them. The extractor
      (`skills/task/scripts/check-fix-plan.sh:297-304`) walks the backticked tokens of the Arm A cell
      and takes the first one matching `^[^ ]+:[0-9]+$` — so **no space anywhere inside the token, and
      a numeric line number**. Fault one, in `agents/fix-scout.md:53` only: it writes
      `` `<spec path>`:40 ``, with the line number OUTSIDE the backticks.
      `docs/templates/progress-format.md:79` writes `` `<spec path>:<line>` ``, so its PLACEMENT is
      right and is the direction to copy. Fault two is in **both**: the space inside the placeholder,
      and a non-numeric `<line>`. Verified by probe — `` `<spec path>:40` `` still yields no anchor
      once the placement is fixed, while `` `<spec-path>:40` `` parses. **So “the template is right
      and the contract is wrong” is HALF true and must not be read as the whole repair:** correcting
      the contract to match the template exactly would leave AC22's own assertion red against both
      files. The repair is two-part — the template's placement, plus a placeholder that parses — and
      the fault in the file a scout actually reads is the worse of the two, which is why it is named
      first. Two sync-group members that LOOK like they disagree while both being broken is worse than
      a plain disagreement: the apparent disagreement invites copying one onto the other, and that is
      precisely the repair which does not work. **A format change is also exactly where a test
      fixture silently stops matching production input**, so the real-artefact requirement on the
      routing legs (AC2) is re-asserted, not relaxed, by this widening.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | A fix plan citing a `file:line` anchor that does not resolve is **refused** by the mechanical gate. A test plants an unresolvable anchor and asserts the refusal. **This arm is evaluated FIRST and its refusal takes precedence**, so a plan that is *both* unresolvable and amendment-naming is refused rather than routed (AC2, AC3), and a plan that is both unresolvable and over the threshold is refused rather than escalated (AC4). A test asserts the precedence on a plan carrying both properties at once — not only on each property alone, since a per-property suite is green whichever order ships. |
| AC2 | A fix plan **whose cited anchors all resolve** routes to the Spec Amendment recipe and **never reaches the fix agent** when either half of the rule fires: a row **dispositioned `fix`** that names a `*.spec.md` path under `ai-docs/plans/` (active or `done/`), or a row **dispositioned `amendment: spec`** whatever its target. **The path half is keyed on a row that PROPOSES an edit, and it is narrowed rather than dropped:** what it catches is an attempt to have the fix agent edit a spec artefact, so a row proposing an edit to one must keep routing. A row proposing **no** edit does not route on its target alone — otherwise a finding already closed before the round by an approved amendment (§ Technical constraints 12b) could not be recorded truthfully without re-routing the round, and since an amendment by definition touches a spec or a design artefact, that is the token's own typical case rather than an edge of it. The anchor qualifier is AC1's precedence, not a weakening: without resolving anchors the plan is refused, and it still never reaches the fix agent. **Fixture requirement:** the routing leg cites a REAL artefact under `ai-docs/plans/`, because a fabricated path cannot resolve as an anchor and the leg would then return the refusal — passing for the wrong reason while measuring nothing about routing. **Three separate test legs, never one combined assertion, each asserted against a plan that differs from a passing one in that half ALONE:** an edit-proposing row naming the artefact routes; a row dispositioned as an amendment routes whatever its target; and a row proposing no edit while naming a real artefact does **not** route. “One test per arm” does not satisfy this criterion, because a suite written against the unqualified rule stays green under the narrowed one. |
| AC3 | A fix plan **whose cited anchors all resolve** routes to the Design Amendment recipe and never reaches the fix agent on the same two halves as AC2, one arm over: a row **dispositioned `fix`** that names a `*.design.md` path under `ai-docs/plans/`, or a row **dispositioned `amendment: design`** whatever its target. AC2's narrowing of the path half and the reason for it, AC2's anchor qualifier, its real-artefact fixture requirement and its three test legs all apply here unchanged. |
| AC4 | A fix plan whose declared total of expected changed lines exceeds the threshold **escalates to the user** instead of being applied, and the gate's output records the **threshold value it fired under** beside the decision. A test asserts both the escalation and the presence of the recorded value. The total is summed over **rows**, so a finding occupying several rows (§ Technical constraints 12a) contributes each of them; and the declared figure is computed on the basis § Technical constraints 12c fixes, **including its gitignored-path clause**, since a figure computed on a different basis is not comparable to the actual total AC18 measures. |
| AC5 | **ONE quantity, defined in exactly ONE place, with exactly ONE firing site.** The threshold's shipped starting value is **total changed lines, 150**, and the only site that fires on it is the pre-apply gate on the plan's declared total (AC4), which reports the value it fired under from that one definition — so a reported value cannot drift from the value it fired under. **Two earlier forms of this criterion are retired and must not be read as live.** It once said "**both** firing sites … read their reported value from that one definition", which went false when the post-apply arm stopped comparing against the number; a later round then split it into TWO quantities, a threshold and a tolerance, which is false now that the post-apply size arm is withdrawn entirely (AC18) and no tolerance exists. The rule survives both drafts intact because it was never about how many sites there are: no site reports a value other than the one it fired under. A test asserts the reported-equals-fired property at that one site, and asserts the number appears in no second place. |
| AC6 | A fix plan that names no verification to re-run is refused. |
| AC7 | The orchestrator verifies the applied diff against the plan — arm (a): **except for a `*.spec.md` or `*.design.md` under `ai-docs/plans/` (active or `done/`)**, a fix agent that edited a file the plan did not name is reported as a **finding**, not accepted as a convenience. **The set of names is the union over ALL the plan's rows**, so a finding occupying several rows (§ Technical constraints 12a) names every file it plans to touch and the arm no longer fires on a test leg that the format simply had no room to declare. A test asserts both directions on a multi-row finding: a file named on any row of that finding is accepted, and one named on no row is still flagged. **A `*.spec.md` or `*.design.md` under `ai-docs/plans/` is EXCLUDED from this arm, deliberately:** an unnamed edit to one is counted and **named on an informational line**, and the verdict stays `OK` rather than becoming a finding. So the arm **is** narrowed for those two suffixes. **The exclusion is keyed on the SUFFIXES, not on the directory**, because the directory is strictly wider than the justification: what earns the exclusion is that the routing arms (AC2, AC3) send a plan naming one of those two suffixes to an amendment, and a non-routing file in the same directory earns nothing. Measured — the directory holds tracked files that are not either suffix, among them `ai-docs/plans/done/2026-09-30-hook-path-resolution.design-evidence.md`, and under the directory-wide form a plan row targeting it declared 40 and the applied verb measured 0. Forty declared, nothing measured, no arm fired. An earlier round of this criterion claimed “the arm is not weakened”; that held only of the multi-row union, is false of the exclusion, and is not repeated here — the narrowing is deliberate and the criterion says so rather than splitting the difference. **What makes it a delegation and not a hole:** telling *an approved amendment wrote this* apart from *the fix agent went rogue* is not derivable from the diff, which looks identical either way. Only the ORCHESTRATOR knows whether it ran an amendment this round, so the discrimination rests with the one party that holds the fact, and the gate declines to guess rather than guessing wrong in whichever direction. A test asserts three legs: an unnamed edit to one of the two suffixes leaves the verdict `OK` and appears on the informational line; an unnamed edit to a non-routing file in the SAME directory still flags, which is the leg the directory-wide form would have passed wrongly; and one outside the directory still flags. Measured: before the widening, the first real run predicted this arm would fire on the gate script's own test suite, and the scout refused to silence it by pointing `Target` at the test file instead, on the ground that a brief misdirecting the fix agent away from the real line is worse than a true finding. |
| AC8 | The orchestrator confirms the write landed on disk (mtime + `grep`) before the round is treated as spent — the applying party is not the only party asserting the write. |
| AC9 | Every escalation path terminates at the orchestrator surfacing to the user; no subagent is given the user's consent decision. |
| AC10 | A finding that fired Arm A is not marked `✅ Fixed` until the cited sentence has been re-read and either confirmed true of the post-fix state or amended, with which one recorded. |
| AC11 | **Displacement, not addition — leg 1: one arm per review verdict, and two outcomes under arm 1.** Exactly one arm applies, and the reporting states WHICH. **Arm 1 — a fix round ran** (some review round carried at least one `⬜ Open` finding, so Step 11's sequence fired). **Arm 1 has two OUTCOMES**, because its trigger says the sequence STARTED, not that it completed — the gap is here, in what arm 1 requires, not in the trigger split, which is exhaustive. **Outcome 1a — the sequence ran END TO END** (scout → gate → fix agent applied the plan): the review round is measured with the baseline's weights (§ Technical constraints 11), and the before/after orchestrator call count is stated against the recorded baseline (66 calls across the loop; 3 / 29 / 19 / 10 / 5 per round) **per round, never as an average**, carrying an explicit note that the figure **is not comparable** because the diff under review is instruction text and a check script, not feature code. **Outcome 1b — the sequence ran only in PART:** the figure is recorded as **NOT OBTAINED**, naming which beats ran and which did not, and the obligation carries forward **whole** — a partial run discharges no part of it. The reason it is not reported anyway: a figure taken from a round whose fixes the ORCHESTRATOR applied describes **baseline** behaviour, not the mechanism's, so presenting it as the mechanism's “after” figure would be false in precisely the direction this task exists to prevent. Its absence is therefore neither a waiver nor a failure of the implementation. **Arm 2 — no fix round ran** (the review approved on the first pass, so Step 11 never fired): the reporting says so explicitly and names it as the reason **no “after” figure exists at all** — not “not yet measured”, and not a silent waiver — and the obligation carries forward to the first later task whose review does produce a fix round that runs the sequence end to end, recorded alongside the owed like-for-like measurement in `ai-docs/context.md` § Open questions (AC12's entry, keyed to its follow-up issue). **THIS TASK'S DISPOSITION — arm 1, outcome 1b: the figure is NOT OBTAINED.** Round 1 rejected with eight open findings, so the trigger fired. Beats 1–3 ran for real: the gate took the round's baseline, the scout wrote a valid 8-row plan with every anchor resolving, and the gate returned `PASS` at 54 declared lines of 150. Beat 4 did not: the orchestrator applied the fixes rather than the fix agent, because the round's own work included widening the plan format, and a format cannot be planned in the format it widens. So the criterion was **satisfiable in principle and not satisfied in fact**, for a reason the implementation did not control and which is itself recorded as a limitation. The like-for-like measurement is owed by the first later task whose review produces a fix round that runs the sequence **end to end**, and is already recorded twice outside this spec: in `ai-docs/context.md` § Open questions and as the gate on `GH-98`. **ROUND 3 — the sequence is running END TO END, and its figure is PENDING.** Round 1's record above stands as written: it is what happened, and the two rounds went differently, which is itself the evidence. For round 3 the user chose to run the mechanism rather than work around it, so beat 1 took the round's own baseline (`round_base=0117edf6…`, round 3, threshold 150), the scout produced a valid plan, and the gate returned `decision=ROUTE-SPEC` — the routing arms firing on a plan whose rows name spec and design artefacts, which is the mechanism working rather than a detour. **No figure is claimed here, because none exists yet:** the fix round has not completed, and when it does the ORCHESTRATOR measures it, on the baseline's weights, per round, with the not-comparable note. Until then this criterion's outcome for round 3 is **pending**, not obtained and not waived. **What any such figure can mean is still bounded by a subtraction, even though no arm compares the two totals any more.** A plan's declared total and the total the `applied` verb measures are not the same quantity, and the two are comparable only while the difference between them is stated, because two classes of declared line are structurally invisible to that measurement (§ Technical constraints 12c). What the withdrawal removed (AC18) is the COMPARISON, not the measurement: `check-fix-plan.sh:702` still prints an applied-side total, so both figures exist to be set side by side and whoever quotes both still owes the gap. **An earlier form of this passage said no applied-side total is computed; that is false of the shipped gate and is retired.** None of this reaches the figure THIS criterion reports, which is a CALL COUNT on the baseline's weights and was never the size comparison. **No instance count is recorded in this criterion:** the recipe permits a scout to rewrite its plan inside a round, so a figure fixed here would go false of the artefact it describes while the rule above still held. **Why these cases belong in the criterion rather than in judgement:** an “after” count needs a round that ran scout → gate → fix agent END TO END, so neither a first-pass approval nor a partial run can produce one — and which case applies is fixed by the review verdict and by what the round's own work happens to be, neither of which the implementation controls. Demanded unconditionally, the criterion would be unsatisfiable through no fault of the work. |
| AC12 | **Displacement, not addition — leg 2.** The owed like-for-like measurement is recorded durably as an entry in `ai-docs/context.md` § Open questions, keyed to a follow-up issue, naming the baseline it must be compared against and the weights it must use. |
| AC13 | A follow-up issue exists for extending the mechanism to `/bugfix` Step 5, `/project-review`'s fix loop, and the post-push fix round, naming all three sites. |
| AC14 | Each Spec-Amendment group sibling belonging to an excluded loop records that the mechanism exists in the main flow, does not apply there yet, and names the follow-up issue. |
| AC15 | `bash scripts/run-checks.sh` exits 0, with the new test(s) appearing as named members and the shell-syntax member's processed file COUNT covering the newly created scripts. |
| AC16 | `skills/task/SKILL.md` remains under 35,000 chars after the change. |
| AC17 | The **Spec-Amendment group** named in § Technical constraints 6 is swept (the Task/Design group does not fire and is deliberately not swept), the new sync group's **anchor row plus back-reference row** exist in `docs/propagation.md`, and `bash scripts/check-propagation-arms.sh` exits 0 with its reported derived-member count **matching a figure predicted before the run** — a count merely read is not a check. Baseline **36**, measured 2026-10-06: `36 derived members all fire, 13 controls all silent, 2 pre-fix matches all kept`. Arithmetic: the gate's member set is the distinct path tokens the table names, so each NEW token ending `.md` / `.sh` / `.json` on the anchor row adds exactly one member, while `skills/task/SKILL.md` and `skills/task/reference.md` are already members and add none. At amendment time the candidate figures were **37 / 38 / 39**, depending on a group membership the design had not yet fixed; all three were superseded by what shipped. **Measured outcome: 40**, which matched the figure the design recorded before the run — so the criterion is MET, and the arithmetic held while the enumeration behind it was incomplete. 40 = 36 + 4: `agents/fix-scout.md`, `agents/fix-apply.md`, `skills/task/scripts/check-fix-plan.sh` and `docs/templates/progress-format.md`. The last of those is the one the candidates missed. The requirement is unchanged: the design records which membership it ships and therefore which figure is expected **before** the gate is run, and a run whose count differs from the recorded prediction is a finding, not a new baseline. |
| AC18 | **Post-apply micro-loop — unconditional, and what replaced the withdrawn size arm.** After the fixes are applied and before the full review pass, the orchestrator runs, every round and with no exemption: **first** the mechanical check of which files the applied diff touched, which reports a file no row named (arm (a), AC7); **then** ONE bounded question (AC23), fed that result, asking whether what was done matches what the plan said and **naming the row and the divergence**; **on a mismatch** the work goes back for re-fixing with that divergence named, up to **three** attempts; **on a burned cap** the orchestrator escalates to the user with a **process recommendation** naming which row, what diverged, and which of re-fix / amend-the-plan / accept it advises; and **the full review pass runs afterwards either way**. **This is the shape the workflow already ships in its two review loops** — a cap of three, then surface — and the existing rule that a burned cap ends the LOOP rather than the GATE governs it unchanged: work done after the cap still gets its review pass. **The post-apply SIZE check is WITHDRAWN — no verdict, no trigger, no tolerance, no like-for-like subtraction, no comparable-declared figure.** It shipped in no form: it was specified as an absolute verdict, respecified as a trigger on declared-vs-actual agreement, and then removed on measured evidence that the subtraction it rested on does not come out equal on honest input, so it fired on honest plans. **Why removing it loses no coverage, which is what makes this a simplification rather than a retreat:** the arm existed to guarantee that no round lands more work than the threshold without a human seeing it, and the direct question answers that better and more cheaply — a plan declaring twenty lines and landing seven hundred IS a diff that does not match its plan, while a plan that honestly declares seven hundred was already stopped at declaration time by the pre-apply escalation (AC4). **So the pre-apply cap on the declared total plus the post-apply question cover blast radius completely, with no post-apply arithmetic at all.** The number was a poor proxy for a question that can be asked directly. **The loop's own retirement rule is stated in advance and recorded in the follow-up issue rather than here** — keyed from `ai-docs/context.md` § Open questions, the surface AC12 already uses for the owed measurement: this loop is as unmeasured as everything else in this task, so if it routinely burns all three attempts it is worse than one review round and must be removed, which is why each loop's iteration count, its cost in orchestrator tool calls and the bounded question's answer are all three recorded (AC24). **What the suite reaches, and what it cannot.** Asserted mechanically, because it passes through the gate: that a loop's verdict row is written for the round carrying its iteration count, its cost and the question's answer, and that an out-of-vocabulary answer is refused (AC23, AC24). NOT asserted, and not to be read as covered: that the loop ran at all, that it ran after the fixes and before the review pass, that the cap was honoured at three rather than four, and that a burned cap escalated instead of proceeding. All four are orchestrator conduct, which a shell suite cannot reach; the recorded iteration count is what makes the retirement rule readable, and is evidence of the cap only as far as the party writing it is honest. Those four are verified by reading the round, not by the suite. |
| AC19 | **No small-round exemption.** The rewired Step 11 fires the scout → gate → fix-agent sequence on **every** round carrying at least one `⬜ Open` finding, with no size-based or severity-based exemption clause and no per-round orchestrator discretion to skip it — worded as Step 8's every-group handoff rule is worded. A reader of the rewired step cannot find a licence to apply a fix in the orchestrator's own context. **The widened format adds no exemption either.** A round every one of whose rows plans no edit — all `object:`, all `resolved:` (§ Technical constraints 12b), or any mix — is a legitimate plan and still fires the whole sequence; `resolved:` records that a finding was already closed before the round, and is never a reason to skip the scout, the gate or the fix agent, nor to apply an edit in the orchestrator's own context. A reader of the rewired step cannot find that licence in the disposition vocabulary any more than in a size or severity clause. |
| AC20 | **Two halves; the first is already delivered.** **Half 1 — DONE, do not re-deliver.** The statement that a round with a single trivial finding runs net-negative under AC19, and that this was accepted deliberately, is recorded durably in `ai-docs/context.md` § Open questions and in the follow-up issue that gates extending the mechanism (`GH-98`) — both verified present on 2026-10-06. A later reader finding AC20 open should not read this half as outstanding. Verified against both surfaces during this task's review and recorded **PASS**. **Half 2 — travels with the displacement figure.** Under AC11's outcome 1a it is reported **per round against the baseline's per-round counts (3 / 29 / 19 / 10 / 5), never as an average that hides the trivial-finding round**. Under AC11's outcome 1b or arm 2 — which is this task's case — **half 2 travels forward with the obligation**, to the task that produces a figure from an end-to-end run. Half 1 stands on its own either way and does not wait for it. |
| AC21 | **Coverage under the widened format — one half relaxed, two halves intact.** The gate accepts a plan in which one finding occupies several rows, and still **refuses** a plan in which (i) an open finding appears in **no** row, or (ii) a row carries a number matching **no** open finding. Three separate test legs, never one combined assertion: a multi-row finding PASSES; an omitted finding is REFUSED; a fabricated row number is REFUSED. The two refusing halves are what the coverage check was built to close, so a test that would stay green if either were lost does not satisfy this criterion — assert each half against a plan that differs from a passing one in that half ALONE. |
| AC22 | **The fifth disposition token, and the examples that teach it.** The disposition vocabulary remains **closed**, now at five, and the gate refuses anything outside it — a test asserts the refusal of an out-of-vocabulary token, so the vocabulary cannot quietly become open. The new token asserts *the tree already satisfies this finding, no edit is owed this round, and this is not a dispute*; it routes nothing, declares 0 expected changed lines, and — like `object:` — refuses an empty reason, each asserted by its own test leg. **And every plan example shipped in an instruction file parses under the gate's own extractor**, asserted mechanically rather than by eye: the example in the agent contract a scout actually reads and the one in the canonical template must both yield the anchors they appear to carry. **Measured 2026-10-06, before the correction this task applies: NEITHER example parsed** — `agents/fix-scout.md:53` carries two faults (the line number outside the backticks, AND a space inside the placeholder), and `docs/templates/progress-format.md:79` has the placement right but the same space fault plus a non-numeric `<line>`. The repair is therefore **two-part**: copy the template's PLACEMENT, and give both examples a placeholder that actually parses (§ Technical constraints 12d). The two files are sync-group members and are corrected together. The two faults above are the record of what was FOUND and when; they are not a claim about the present state, which the assertion itself is what reports. **Three conditions on the assertion, absent which it fails on correct rows:** it calls the gate's **own** extractor and never a reimplementation, because a second copy of that matcher is a second thing to drift; it applies only to Arm A cells that are not `none`, since the gate skips those entirely and the first two rows of both examples are `none`; and its test leg is **shown RED against today's tree before the examples are corrected**, because a leg written after the fix and never run against the broken state proves nothing. |
| AC23 | **The bounded question, UNCONDITIONAL, with a NAMED closed answer vocabulary the gate enforces.** Every round, after the mechanical file check and before the full review, the orchestrator puts exactly ONE question against the applied change: *does what was done match what the plan said* — **naming the row and the divergence** rather than asking in the abstract. **THREE fixed inputs:** the plan's own section for that round, the applied change, and **the mechanical check's result — the list of files no row named (AC7)**. That third input is a precomputed mechanical fact the question would otherwise re-derive from the diff by eye, which is slower and less reliable than the check that has already run. **Nothing else is an input** — not the findings table, not the spec, not the session's history. **The answer is exactly one of two words, and the two words are `MATCH` and `DIVERGE`**, stated here as the closed set's MEMBERS and not as examples, accompanied by a reason in prose. A set of cardinality two whose members are unnamed cannot be checked, which is how the first real run came to invent its own pair at dispatch time. **The closedness is enforced mechanically rather than by judgement:** the answer is passed to the verdict-recording verb (AC24) as an argument, and that verb **refuses anything outside the set** on the same argument-validation lane its other arguments already use — so an invented answer cannot be recorded and cannot pass silently. This is the criterion's only point of mechanical control, and it exists because a refusal that cannot be computed is a second review pass, which is what the bound was for. **It holds no authority to apply anything and no authority to decide rework:** it may not edit, it may not re-run the fix, and its answer does not by itself end the round — a `DIVERGE` feeds the next re-fix attempt (AC18), and when the attempts are spent the decision terminates at the orchestrator surfacing to the user with its recommendation, exactly as AC9 requires of every escalation path. **The review pass runs either way**, so the question is a cheaper look placed BEFORE the review and never a substitute for it. **What the suite reaches, and what it cannot, stated so no leg is read as covering more than it does.** Asserted mechanically: each of the two words is accepted, and an out-of-vocabulary answer is refused. NOT asserted, and not to be read as covered: that the question was asked at all, that it was asked exactly once, that it received only its three inputs, and that the answer corresponds to what the diff actually shows. Those are orchestrator conduct and the answer's own honesty; the gate can refuse a word it does not know, and cannot check whether the right word was chosen. |
| AC24 | **The verdict persists, in a SIBLING directory, and records what the loop's retirement is read from.** Each firing of the pre-apply escalation (AC4) and each run of the post-apply micro-loop (AC18) writes one verdict line carrying the decision, the threshold value it fired under where one applies (AC5), **that loop's iteration count and its cost**, and **the bounded question's answer** (AC23) — the figures the retirement rule is read from, absent which that rule is unenforceable. **The verb that writes this line is where the answer's vocabulary is enforced:** the answer arrives as an argument, anything outside `MATCH` / `DIVERGE` is refused on the same argument-validation lane the iteration count and the cost already use, and the argument is RECORDED and not merely validated — a check whose input is discarded leaves no evidence that it ran. **It reuses the shipped appender rather than adding a surface:** `hooks/lib/ledger-write.sh:30`, `harness_ledger_append() {`, taking a session id, a ledger path and one line; and `hooks/lib/loop-verdict.sh` already writes `kind: "verdict"` lines (`:124`, `:211`), so the line shape is adopted rather than invented. **It does NOT write into the loop ledger's own directory** — the one `HARNESS_LOOP_DIR` names (`hooks/lib/ledger-write.sh:77`) — but into a sibling of it, and this is the criterion's correction of an earlier draft that would have used that directory: planting a single row there was measured to move an existing report's project, session and verdict counts and to fabricate a session block carrying a false sentence about the file's age. A verdict surface that corrupts a neighbouring report is not a persistence mechanism. **A failed write never fails the round:** that appender returns 1 and reports once, never exits non-zero and never costs the session a tool call, so this criterion asks for the line to be written and explicitly NOT for the round's outcome to depend on it. A test asserts a line is appended per firing; that it carries the iteration count, the cost and the answer; that each of the two words is accepted and anything else refused; that a simulated write failure leaves the round's outcome unchanged; and that the neighbouring report's own counts are unmoved by the new rows. |

## Open questions

- **The understated-plan residual, carried open on purpose.** The pre-apply gate compares the declared
  total against the absolute 150, and nothing compares anything once the fix has landed, because the
  post-apply size arm is withdrawn (AC18) — so a plan that declares 20 lines and changes 140 still
  passes the gate, and no arithmetic anywhere reports a finding on the gap. This is **not** an
  unanswered question — it is an accepted consequence, recorded here so a later reader does not mistake
  the mechanism for airtight. **What changed about it, and it is neither of the two things earlier
  drafts of this entry said:** "once real verdicts accumulate the spread becomes measurable" is not
  live, and neither is "the spread is now computed every round in order to route a question". No spread
  is computed at all. What covers the concern instead is the direct question (AC23), which asks whether
  the diff matches its plan rather than measuring by how much it missed. **Design and review may argue
  for a declared-vs-actual arm, but may not assume one exists**, and must weigh the measured reason the
  last one was withdrawn: the subtraction it rested on did not come out equal on honest input.
- **RESOLVED — the plan carries an explicit per-finding disposition, from a closed five-token
  vocabulary, and the fix agent acts on exactly one of the five.** The question was whether the plan
  should carry a disposition at all and how the fix agent would be told to leave the objected findings
  alone. Both are decided. **The shape this entry originally floated — `fix / object /
  amendment-route` — is superseded and must not be read as live:** the vocabulary is `fix`,
  `object: <reason>`, `amendment: spec`, `amendment: design` and `resolved: <reason>`
  (§ Technical constraints 12b; the fifth token ships with this task), and `agents/fix-apply.md` takes
  **only** the rows dispositioned `fix`, with a per-disposition table stating what it does with each of
  the others. Step 11's objection rules are unchanged — a `nit` / `minor` may be objected to
  autonomously, a `major` / `blocker` only with the user's approval. The hard requirement this entry
  recorded still holds and is now carried by AC19: the always-on rule binds the ROUND, so a round whose
  every row plans no edit still produces a plan and still fires the sequence rather than letting the
  orchestrator freelance.
- **RESOLVED on storage, with ONE HALF LEFT OPEN below — the plan is a `## Fix Plan (Round N)` section
  inside the task's own `.progress.md`**, not a separate artefact. It is gitignored (`.gitignore`
  matches `ai-docs/plans/**/*.progress.md`), one section per round — the gate's `baseline` verb refuses
  to write a round that already has one, so a round cannot silently overwrite its predecessor — and it
  is deleted when the progress file is. The original hard requirement held: it is text on disk, because
  the gate must read it.
  - **RESOLVED — a verdict line persists, in a sibling of the loop ledger's directory (AC24).** This
    half was carried open because the plan and its verdict died with the gitignored progress file, so
    the data that would ever recalibrate anything accumulated nowhere. The answer was not to invent an
    artefact: the shared appender and the `kind: "verdict"` line shape already ship. **Two corrections
    an earlier draft of this entry needs.** The destination is a SIBLING directory, not the loop
    ledger's own, because planting a row there was measured to corrupt an existing report. And what the
    line is read FOR has changed: the declared-vs-actual spread it was going to collect no longer
    exists, so it carries each micro-loop's iteration count, its cost in orchestrator tool
    calls and the bounded question's answer instead — all three, which together are what that
    loop's retirement rule is read from. Still recorded outside this spec, beside the measurement gate in
    `ai-docs/context.md` § Open questions, because what it enables outlives this task.
    - **This is NOT a defect in the plan-format widening.** It is a consequence of the storage
      decision — keeping the plan inside the gitignored progress-file section — which was right for
      every other reason: the gate reads text on disk, the plan never pollutes the measured tree, and
      nothing extra has to be cleaned up. The consequence was invisible until someone ran the
      mechanism once, which is the only way it could have been found.
    - **Two dispositions elsewhere waited on this half; neither waits any longer, and neither is a
      follow-up.** The understated-plan entry above and the § Deferred row for a declared-vs-actual
      comparison both once said *revisit once verdicts carrying their threshold value accumulate*.
      There is no spread to accumulate — the arm those dispositions pointed at is withdrawn — so read
      both as closed records of a mechanism tried and dropped, not as scheduled work.
- **RESOLVED — TWO agent files, not one file with two modes.** `agents/fix-scout.md` writes the plan;
  `agents/fix-apply.md` applies only the rows dispositioned as fixes. Worth recording rather than
  deleting, because the choice is load-bearing downstream: two contracts are two members of the new
  sync group, and therefore two of the derived members `scripts/check-propagation-arms.sh` counts
  (AC17).
- **RESOLVED — ONE script with FOUR verbs**, `baseline | plan | applied | record`
  (`skills/task/scripts/check-fix-plan.sh`), rather than several scripts. **An earlier form of this
  answer said THREE verbs** and is retired: the micro-loop's verdict row is written by a fourth verb
  (AC24) rather than by an append the orchestrator hand-rolls, because a second writer of that format
  outside the one place that owns it is a second thing to drift. **One rider in this entry was wrong and
  does not survive its retirement:** it said `run-checks.sh` derives from the tree either way. It does
  not. A `check-*.sh` cannot be a documented member of that runner and must be named in its exemption
  list instead, so what the tree-derived suite list picks up is the gate's own `test-*.sh` and never the
  gate itself (§ Technical constraints 4). The shape of the gate was free; its registration was not.
- **RESOLVED — one `key=value` header line per run, followed by one line per arm.** The gate prints
  `check-fix-plan: verb=<baseline|plan|applied|record> round=<N> decision=<…> reason=<…>
  threshold_changed_lines=<…>`, extended per verb — `round_base=` on `baseline`,
  `declared_changed_lines=` on `plan`, `actual_changed_lines=` / `ignored=` / `binary=` on `applied`,
  and `iterations=` / `cost_tool_calls=` / the bounded question's answer on `record` (AC23, AC24) —
  then one indented line per arm carrying its id, its name, `pass` or `FAIL`, and its detail. AC4's two
  requirements are met **structurally** rather than by convention: every verb emits through one header,
  so the decision and the threshold value cannot be omitted by a caller or forgotten by a new verb.
  **Two earlier forms of this entry are retired.** One listed three verbs where there are four. The
  other dropped `actual_changed_lines=` from the `applied` verb on the ground that no applied-side total
  is computed — false of the shipped gate, which emits it at `check-fix-plan.sh:702`; the withdrawal
  (AC18) removed the comparison, and that field is a MEASUREMENT nothing fires on, read by a human
  against the question and explicitly NOT one of the three figures the retirement rule
  accumulates (AC24). **One pointer, not a half-answer:** the
  verdict goes to stdout and also persists as one line in a sibling of the loop ledger's directory
  (AC24). The FORMAT question was always closed here; the KEEPING question is closed too, and this entry
  is the pointer between them.
- **RESOLVED — `THRESHOLD_CHANGED_LINES=150`, one assignment near the top of
  `skills/task/scripts/check-fix-plan.sh`, and nothing else names the number.** The pre-apply `plan`
  verb reads it from there and reports it through the same header it decides on, so its reported value
  cannot drift from the value it fired under — which is what AC5 asks. **It has exactly ONE consumer.**
  Two earlier forms of this entry are retired: the first said both firing sites read the number from
  here, and the second said the `applied` verb fires instead on a separate tolerance. The post-apply
  size arm is withdrawn (AC18), so there is no second site and no second quantity.
  Checked rather than assumed: the figure appears in **no** instruction file — not in the
  rewired step, the recipe, either agent contract, or the progress-file template. That absence is the
  property worth preserving, and the reason this entry is retired as an answer rather than deleted: a
  prose copy of `150` would read as helpful and would become a second definition the first time the
  value is tuned.
