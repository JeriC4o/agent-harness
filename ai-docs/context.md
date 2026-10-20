# agent-harness — Project Context

Context for developing **the harness itself**. A consuming project gets its own copy of this file from
[`templates/project/ai-docs/context.md`](../templates/project/ai-docs/context.md).

## Overview

A Claude Code plugin that ships a spec-driven task workflow, a reactive bugfix loop, skeptical review
subagents, and enforcement hooks — plus the method documentation they read. Distributed via this repo
acting as its own plugin marketplace. Consuming projects keep their own profile (`AGENTS.md`,
`ai-docs/context.md`) and their own learning corpus (`ai-docs/learnings/`).

---

# System Entities

## Method file

- **What it is.** Any file under `docs/`, `skills/`, `agents/`, `rules/`, `hooks/`. Ships with the plugin
  and must hold in every project.
- **Identity.** Its path. Method files may not name a language, build tool, domain entity, or ticket prefix.
- **Code.** `docs/agents-method.md` is the root of the method surface.

## Profile file

- **What it is.** Any file under `ai-docs/` or `templates/project/`. Carries project facts.
- **Identity.** Supplied per project; scaffolded from `templates/project/`.

## Promotion candidate

- **What it is.** A method-level lesson abstracted out of one project's Learning Log, carrying no project
  identifiers, eligible to be swept into the harness by a future cross-project `/improve-global`.
- **Status.** Implemented. Written by `/harness:improve` Step 5b into
  `ai-docs/learnings/.promote/`, gated by `scripts/check-candidate.sh`, swept by
  `scripts/collect-candidates.sh` for `/harness:improve-global`.

## Registry

- **What it is.** `~/.claude/harness/registry.json` — the list of projects using this harness, one entry
  per absolute path, written by `/harness:harness-init`.
- **Identity.** `path` is the key. `scope` (`shared` | `local`) decides whether a project takes part in
  cross-project learning sweeps.
- **Invariant.** Paths and labels only, never project content. A consumer skips entries whose path no
  longer exists rather than failing.

## Fix plan

- **What it is.** A `## Fix Plan (Round N)` section appended to a task's `*.progress.md` by
  `agents/fix-scout.md`: one row per `⬜ Open` finding, carrying its disposition, the target it will
  change, an expected changed-line figure on the `max(added,removed)` basis, and the artefact sentence
  the finding puts at stake quoted with its `file:line`.
- **Identity.** The round number. One section per round, highest round is the one gated; a second
  section for the same round is refused rather than appended.
- **Code.** `skills/task/scripts/check-fix-plan.sh` — four verbs (`baseline`, `plan`, `applied`,
  `record`), **eleven reason tokens under `plan`: nine refusals and two routings** (the pair is spelled
  out because "ten refusal reasons" previously covered both kinds and read two ways), **two findings under
  `applied`**, and the single `THRESHOLD_CHANGED_LINES=150` that its ONE firing site reads — the pre-apply
  gate, on the plan's declared total. The disposition vocabulary is **six**; the sixth, `redline:`, is the
  one that records a divergence instead of routing one. The post-apply size arm is withdrawn; `record` persists the post-apply micro-loop's
  iteration count, its cost in orchestrator tool calls and the bounded question's answer.
- **Invariant.** It lives in the progress file, which is gitignored and deleted by `/pr-merged`, so no
  new artefact type and no new deletion path. The gate decides on its TEXT — never on an agent's
  report of it — and a plan the gate refuses never reaches `agents/fix-apply.md`.

## Redline log

- **What it is.** A committed `ai-docs/plans/<spec-base>.redline.md` holding one row per SURVIVING
  divergence between the frozen design and what shipped: its key, its type (`added` / `modified` /
  `removed` relative to the frozen base), the design sentence it diverged from quoted with its
  `file:line`, and what shipped instead. Each row is paired with a pointer marker appended in place on
  the item it corrects, which carries the key and nothing else — so a reviewer reading the design sees
  which items are settled and skips them.
- **Why it exists.** The design is frozen at the design-review GO verdict and is NOT rewritten during the
  work. A divergence that does not break the agreed approach is marked and logged instead of reopening
  the planning chain, and one closing fold after the PR is approved applies the log's rows to the items that diverged.
- **Identity.** The spec base name. Its head carries four required fields — `**Tracked in:**`,
  `**Spec:**`, `**Design:**`, `**Mode:**` — of which `Mode` is the one with a consumer: `R&D` or
  `Hybrid`, chosen once per task at the first divergence found while writing the code, with grounds that
  must cite the design.
- **Code.** `scripts/check-redline.sh` — six verbs (`pending`, `folded`, `suppression`,
  `revision`, `paired`, `specform`) on the `0 clean / 1 findings / 2 cannot run` convention. `paired` is the pairing
  half for every key form and the marking pass's own exit check; `check-fix-plan.sh`'s `A7` and `A8` are
  the in-round halves. `skills/redline-fold/SKILL.md` is the closing fold; `/pr-merged` refuses on an
  unprocessed log.
- **Invariant.** It is the one file in the plan family that is COMMITTED, because the fold runs after a
  human review and a gitignored file does not survive that far. It is excluded from the fix-plan gate's
  measured diff by `IGNORE_GLOB_REDLINE` and named on the `excluded-in-round` line instead. It is removed
  by the fold, so a surviving log is an unambiguous signal the fold never ran.

## Plan invariants

- **What it is.** The base principles of what a spec and a design are, the record of the elements each
  one is required to be composed of, and the set of pages that define or enforce one. A numbered
  sentence per principle, each carrying its own one-clause reason; thirteen elements keyed by document
  and token together; seven protected pages with a reason each, and seven documented near misses with
  why each one is out.
- **Why it exists.** Measured damage: a self-improvement pass made a required element out of something
  that cannot be known at the time the document is authored, which bought invented content at authoring
  time and an end-of-task review loop that could not converge. All but two of the principles are
  prohibitions, so a hunt for a principle's opposite is structurally blind to an ADDITION — and an
  addition is how the measured damage arrived. That is why the verification COMPARES a recorded statement
  inventory instead of reading sentences and ruling on them: arrived, departed and textually changed are
  three answers a comparison gives exactly — with relocated as a fourth for the files taking the code
  spelling, where a line's position is semantics and prose's position-independence would hide it — an
  addition is the same kind of answer as a contradiction, and no class of passage can be set aside as
  harmless because nothing is set aside at all.
- **Identity.** `docs/plan-invariants.md` is the authority on the wording of the principles and on the
  required-element record. It is method, not profile, so it ships to every installing project. The
  recorded statement inventory is the other half and sits on the opposite side of that line:
  `ai-docs/fixtures/plan-invariants.inventory` is profile, because an inventory of this repository's own
  instruction material is a project fact. It is one row per corpus file — surface, git blob sha, path —
  so previous text is fetched from this repository's own object store rather than held as a second
  committed copy of the corpus, which measured 2.52 MB against the record's 9.8 kB.
- **Code.** `scripts/check-plan-invariants.sh` is the entry point and loads two payload siblings from its
  own directory — `scripts/check-plan-invariants.py`, which holds the corpus, three of the legs and the
  report, and `scripts/check-plan-invariants-refusal.py`, which holds leg 4 and which the first loads.
  Four legs (principle integrity, the inventory comparison, addition, refusal agreement) on the
  `0 clean / 1 findings / 2 cannot run` convention, run as the `plan-invariants` member of
  `scripts/run-checks.sh` and covered by `scripts/test-check-plan-invariants.sh`. The split is a size
  consequence and the failure mode that argued against it is guarded rather than absent: the entry point
  preflights the sibling's existence and readability, and the first sibling's loader wraps the module
  EXECUTION — not the spec lookup, which was measured catching neither failure — so an unloadable sibling
  is a cannot-run and never the findings code. Its verdict line carries the principle, element, surface,
  page, statement, unaccounted and finding counts followed by a per-surface roster, and `--accept` is the
  only thing that levels the record: it prints the report it is about to take in before rewriting
  anything.
  `hooks/lib/plan-invariants-guard.sh` is the edit-time refusal, registered on two `PreToolUse` matchers
  so both the editing tools and the shell route reach it; it covers the record and an acceptance
  invocation as well as the seven protected pages, by a second one-member list kept deliberately apart
  from the list the refusal-agreement leg compares against the table.
- **Invariant.** The record is not the route by which an element becomes required: it is cross-checked
  against the pages that mandate one, in both directions, so a one-sided edit is reported whichever side
  it happened on. A change to a principle is two co-ordinated edits — this page and the verification's
  own pinned copy — and that is the authorisation route rather than a hole. The path the verification
  reads and the path the guard guards are asserted to agree in both directions, because one side alone is
  satisfiable by a guard that guards nothing and the other by a guard that guards the wrong file. The
  detection is wider than the refusal by construction, and the bound is stated rather than hidden: a
  contradicting or adding edit is caught and named, never prevented, and the comparison reports a change
  to a statement's TEXT and never a meaning — so a clean verdict means no statement differs from the
  record, never that no instruction implies a new requirement.

---

# System Design

## Layout

| Path | Role |
|---|---|
| `.claude-plugin/` | `plugin.json` (manifest) + `marketplace.json` (this repo as its own marketplace). **Declare a component key only for a NON-default location** — `hooks/hooks.json`, `skills/`, `agents/` are auto-discovered, and re-declaring one makes the plugin refuse to load it twice (`scripts/test-plugin-manifest.sh` guards this) |
| `skills/<name>/SKILL.md` | The 13 workflow skills — re-derive with `ls -d skills/*/ \| wc -l` rather than trusting this line; the install smoke gate asserts the installed skill list covers every one the tree ships, so a stale count here is invisible to it |
| `agents/<name>.md` | The 10 subagents |
| `rules/ast-index.md` | Code-search hierarchy, inherited verbatim by subagents |
| `hooks/hooks.json` | **22** hook entries in 12 matcher groups, running **19** distinct guards — three are registered twice: two of them on two EVENTS each, and the plan-invariants refusal on two MATCHERS of one event, which is why "how many hooks" has three defensible answers and this row gives all three. Re-derive from the manifest with `jq` over `.hooks[][].hooks[]` (length, and the length of its unique `.command` set) rather than trusting this line; `hooks/lib/` holds the shared guard and the plugin-path resolver (`plugin-ref.sh`) |
| `scripts/` | Plugin-level utilities shared by more than one skill (the promotion gate and sweep), the repository's own gates (`check-references.sh`, `check-release.sh`, `check-readme-update.sh`, `check-propagation-arms.sh`, `check-plan-invariants.sh`, `check-plan-convergence.sh`, `test-install-smoke.sh`, `test-upgrade-smoke.sh`), `run-checks.sh` as the single entry point for the pre-commit list, and the `test-*.sh` suites those and the skills' helpers are covered by |
| `docs/` | Method reference, incl. `agents-method.md` |
| `templates/project/` | What a consuming project gets scaffolded with |
| `ai-docs/` | This repo's own profile + plan/learning data |
| `ai-docs/fixtures/` | Frozen real-world inputs a gate replays, committed and never refreshed as routine maintenance — `loop-corpus/` holds the loop ledger's replayed call rows, and `plan-invariants.inventory` is the recorded statement inventory the plan-invariants gate compares the tree against. That one diverges from the root's own contract (a maintained record rather than a frozen replay input, one file rather than a corpus subdirectory with a checksummed baseline) and is the least-bad fit among the roots a method file is allowed to name; it is levelled only by `check-plan-invariants.sh --accept`, which is the clause of that contract it does satisfy |

## Tech stack

| Concern | Choice |
|---|---|
| Language | Markdown instruction files + POSIX shell, plus eight non-shell payload files in three other languages: `awk`, `jq` and `python3` |
| Build | none |
| Test | `bash scripts/run-checks.sh` — the whole structural list in one call; see `AGENTS.md § Build & Test` |
| CI | none yet |

## Language profile

| Field | Value |
|---|---|
| Primary language(s) | Markdown, POSIX shell (`bash`). Eight tracked payload files are in three other languages — `hooks/lib/loop-window.awk`, `hooks/lib/loop-window-prefix.awk`, `scripts/bin-of.jq`, `scripts/check-plan-invariants.py`, `scripts/check-plan-invariants-refusal.py`, `scripts/check-plan-convergence.py`, `scripts/check-plan-convergence-holding.py` and `scripts/check-plan-convergence-reporting.py` |
| New-file rule | Method content is Markdown; executable helpers are `.sh` under `skills/<skill>/scripts/`. A payload in another language is a SIBLING loaded by a `.sh` entry point from its own directory, never an entry point itself, so every caller still invokes a shell script and the interpreter is preflighted with its reason in one place |
| Max line length | soft 110 for prose; no hard limit |
| Formatter | none |
| Linter (the gate) | `shellcheck` for `.sh`; `jq -e .` for JSON manifests. **Neither the `shell-syntax` member nor `untracked-shell` globs anything but `*.sh`, so no gate in the pre-commit list parses a payload sibling by walking the tree** — each is asserted by the suite that owns its entry point instead: `scripts/check-plan-invariants.py` is `ast.parse`d by a leg of `scripts/test-check-plan-invariants.sh`, and `scripts/check-plan-convergence.py` with both of its siblings — `scripts/check-plan-convergence-holding.py` and `scripts/check-plan-convergence-reporting.py` — by a leg of `scripts/test-check-plan-convergence.sh` that enumerates all three, each run by its single entry point, and the invariants payloads are additionally asserted tracked by the check itself, because a file read for its data while untracked makes the local run green and every other clone a cannot-run |
| Source root / test root | n/a — no compiled sources |
| Required external interpreters | `python3` and `perl`, beside the `awk` and `jq` the payload files above need. `python3` runs all five `.py` payloads above — `scripts/check-plan-invariants.py` with the refusal sibling it loads, and `scripts/check-plan-convergence.py` with the holding and reporting siblings it loads — and is the scanning tool of both plan-document checks, each of which preflights it by name and names every payload it could not find. `perl` executes nowhere in the tree's shipped code and is still a hard dependency of the mandatory check list: five of its members build their mutant fixtures with it — the loop-index and loop-verdict verifications under `hooks/lib/`, and the bin-of, loop-grid and loop-metrics suites under `scripts/` — so on a host without it those positive controls cannot run, and a could-not-run is not a pass. `scripts/run-checks.sh` demands it in the same preflight roster as the tools it invokes itself, which is what makes that failure loud and early rather than mid-suite. **A word-list mention is not an invocation:** `hooks/lib/plan-invariants-guard.sh` and its own verification carry the name as DATA, inside the vocabulary that recognises a command writing a file in place, and neither runs it |
| Thousand-line exemption | `scripts/check-plan-invariants.py` is the one file in this repository **exempt from `docs/code-style.md` § File size**: `wc -l` reported 1,001 lines before this branch's two id comments landed and reports 1,003 now, against a hard limit of one thousand. The only seam that removes the overage moves the `PINNED` list — the check's own second copy of the base-principle sentences, eleven lines of data by `wc -l` over that assignment — into a fourth payload file, which by that subtraction lands the payload at about 992, eight lines under the limit; the payload's own header already argues against that file, on the ground that the data left after the second leg stopped measuring a sentence against a vocabulary does not earn one. This row records that the three lines are tolerated rather than paid for that way, and names the seam if it is ever revisited. The convergence payload took the other route: it crossed the same limit at 1,447 lines and was split into three files instead. The core file that split left measures 805 lines, inside the 800–1000 band `docs/code-style.md` calls **hard-ish** and routes to a justification in the pull-request description: what that file keeps is what both sibling groups read — the plan pair, the segmentation, the numeral readers, the excuse route and the report — so a further cut would have to cross machinery both siblings call rather than follow a seam the check already states as data, and the five lines above 800 are tolerated on that ground. This row is the durable record of that justification, and the pull request carries the same one when it opens. |

## Deployed configuration

**Deployed-config globs:** `.env` `.env.*`

The file class whose CONTENTS are ASK-gated by
[`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Permissions](../docs/agents-method.md#permissions). The
search guard `hooks/lib/deployed-config-guard.sh` reads the line above at search time, so the gated class
is this project's own spelling rather than one stack's filenames carried inside a method file. One glob
per backticked token, all on that one line; a project with no such class writes `none`, which silences the
guard. **This project holds no deployed configuration in the tree** — the two globs are the class the
method surface itself names, they are gitignored here, and the declaration exists so the guard has a class
to read rather than one to invent.

## Build & test commands

No build. The checks in `AGENTS.md § Build & Test` are the gate: seven structural ones over the repo's
contents, plus three delivery gates (`test-install-smoke.sh`, `check-release.sh`,
`test-upgrade-smoke.sh`) that answer the question the structural ones cannot — does this reach a
consumer. The structural seven run in one call as `bash scripts/run-checks.sh`, which reports a verdict per
member, derives its suite list from the tree rather than carrying one, keeps every member's status instead
of the last one's, and cross-checks its own member table against the gate list in `AGENTS.md` — in both
directions, for suites and for every structural check that section spells as a script invocation — so a
script-backed gate can be neither documented-and-unwired nor wired-and-undocumented. The four members
backed by a shell function rather than a script (the manifest parse, the syntax gate, the untracked-file
check and the inventory itself) are outside that comparison: deleting their items from the gate list is
silent, and the pinned member table in the suite is what covers them. The three delivery gates stay separate: they run once before a PR, need the
`claude` CLI, and exit 2 when they cannot run, so folding them in would give the runner's rc 2 two
meanings.

---

# Conventions worth writing down

- **`${CLAUDE_PLUGIN_ROOT}` for method paths, repo-relative for project data.** A method file that links
  to `ai-docs/…` breaks for every consumer — name project data in inline code, never as a markdown link.
- **Skill scripts run via `${CLAUDE_SKILL_DIR}/scripts/<name>`.** A repo-relative invocation resolves
  against the consuming project and silently fails there while working here.
- **Plugin skills are invoked namespaced**: `/harness:task`, not `/task`.
- **A model-facing hook message resolves its own addresses; the matcher anchors on the project.**
  `${CLAUDE_PLUGIN_ROOT}` expands in the double-quoted executable path and stays LITERAL inside the
  single-quoted payload the model reads, so every method address in a message goes through
  `hooks/lib/plugin-ref.sh`: it emits the address only when that file is readable here and otherwise
  names the read access the plugin needs. A `case` arm anchors on `CLAUDE_PROJECT_DIR`, never on the
  install — an arm written against the install path can only fire on an edit the rules already deny.
- **Bump `plugin.json` version in the same PR as any change to plugin-loaded content.** The install cache
  is keyed by version; without a bump the fix reaches nobody, and `marketplace update` reports success
  while leaving the old payload in place. Content that ships: `skills/`, `agents/`, `rules/`, `hooks/`,
  `docs/`, `scripts/`, `templates/`.

---

# Open questions

- `GH-10` — the ≥2-distinct-projects promotion threshold is reasoned, not observed. Revisit once two
  projects carry candidates.
- `GH-116` — three bounds of the statement-inventory verification, none of which any gate reports,
  measured against a corpus of **122 pages and 27,361 statements** as the branch leaves it. **Read the
  statement total as an as-of figure and never as a fixed one:** it moves by the net lines any later
  change adds to the examined surfaces, so a reader whose measurement differs is watching the corpus
  move rather than catching this entry out. What has to stay true for the bounds below to mean
  anything is the BOUNDS, not the magnitude.

  **The record can be levelled in the same pass as the change it would have reported, and this is
  EVIDENCED rather than theoretical.** It is closed as far as the refusal reaches: the record and the
  acceptance route are both put to the author, so a pass that edits rule material cannot do the second
  half unprompted. Outside that reach it is open. The evidence arrived from this task's own work rather
  than from a probe: prose describing the superseded mechanism was still in the tree when the first
  acceptance ran, so it entered the record as the corpus's accepted state and **the comparison was silent
  on it by construction**. It cost nothing, because the plan had already assigned that prose to a later
  step and a positive control now shows the span is no longer blind. What it establishes is that the
  exposure is reachable by ordinary ordering, not only by a pass covering its tracks.

  **The verification is a CHANGE detector against an accepted record, not a presence assertion — so a
  clean verdict means less than it looks.** The numbered principles do get a presence assertion, a
  pinned copy inside the verification reported as an absence when one vanishes. Nothing else does. Measured:
  deleting the principles page's own statement of its limit reports 7 departures with their text and moves
  the statement total down by exactly those **7**, so it cannot STOP being stated unseen — the DELTA is the
  measured fact and the absolutes are not, because they move with every later change; but had that
  sentence never shipped,
  nothing would have reddened. The same shape applies to whether the principles page reaches an INSTALL:
  the install gate inventories skills, agents and hook events and has no documentation arm. Six of the
  twenty-three criteria are recorded as partial for bounds of exactly this kind, each with its own.

  **Whether the report's volume stays proportionate once the corpus is in its steady state. Revisit with
  a count, not a judgement.** Measured on this branch's own change: 2,448 report lines across 18 differing
  files, of which 2,369 were the statements of seven new files, against tens of lines for an ordinary
  prose edit. The figure to revisit against is what the landed verification prints over the next few
  tasks, not the one measured here while it was being built.
- `GH-11` — `/harness:improve` Step 5b has never produced a candidate on a real Learning Log; every part
  is unit-tested, the path is not.
- `GH-72` — the tier-1 fan-out arm became reachable when the hook started reading `agent_id` off the
  payload. Its bar, `na > 1`, is inherited from a time when the arm could not fire at all, so it has
  never been measured against a real firing. The verdict line records `agents` and the threshold it
  fired under, so the calibration arrives on its own; revisit only if the first real firings show the
  bar is wrong.
  **Re-measured under GH-86, and the earlier basis for leaving it alone no longer holds — while the
  disposition does.**

  **Read every number below as a FLOOR at its as-of stamp, never as a bare count.** This corpus is not
  a fixed object and it is not an impartial one: the method file tells every subagent to read
  `docs/agents-method.md`, so the very fingerprint family that makes this point grows each time anyone
  works on this point. These figures were re-derived three times in a few hours while the entry was
  being written and rose on two of them. A later reader whose live measurement exceeds what is written
  here is watching the corpus move, not catching the document out.

  As of **2026-10-05T16:00Z**: **≥13 ledgers**, **≥9149 `kind:"call"` rows**, and **0 tier-1 verdicts
  ever written** — 107 verdicts in total, 79 tier-2 and 28 tier-3. That last figure is the one that has
  not moved at any measurement, and it is the reason the question is still open.

  **≥13 distinct non-`main` agent ids**, carried by **2** of those ledgers; a third post-`4c1cd0a`
  ledger exists (a 1-call probe session) and carries none, so "which ledgers could show attribution" and
  "which do" are different counts and both are worth keeping.

  **The stale claim, named so it is not re-inherited.** GH-86's spec originally recorded "no fingerprint
  family of ≥3 rows spans more than one agent in either post-`4c1cd0a` ledger". That is false and has
  been amended. One ledger now carries **≥5 families of ≥3 rows, ≥4 of them spanning more than one
  agent**. The largest is `fp 3562779350` at **8 rows across 8 distinct agents** — verified by
  recomputing djb2 over `tool_input` per `hooks/lib/loop-index.sh:101-103` rather than by trusting a
  label, and it is `Read` of `docs/agents-method.md`. A fingerprint does not move, so it is the one
  precise value here worth carrying forward.

  **The largest multi-agent families are `Read`s — but not all of them are.** `fp 271202357` is a `Bash`
  family spanning two agents, so "every multi-agent family is a subagent obeying an instruction file" is
  wrong and an earlier draft of this entry said it. The durable form is the one above, true at every
  measurement so far. It still matters before tightening the bar: the dominant shape is genuine
  duplication and also the cheapest kind there is, so a bar tuned on it would be tuned on the one
  fan-out nobody wants flagged.

  **Two facts that must not be collapsed into one.** The bar is uncalibrated **for want of a firing** —
  zero tier-1 verdicts corpus-wide, re-confirmed at every measurement — AND there is now **material to
  calibrate against**, where the old basis said there was none. Both are true. Neither licenses tuning
  the bar, which stays out of GH-86's scope.

  The `agent-mark` canary added by GH-86 is what now makes a REGRESSION here visible: if these ids ever
  collapse back to `main`, recorded subagent starts with no non-`main` call row says so from the ledger
  alone.
- `GH-75` — the propagation reminder's arms are now derived from the sync-group table and anchored on
  the project directory, so the project-side mirrors a consumer may keep (`.claude/agents/*.md`,
  `.claude/rules/**/*.md`, `.claude/commands/*.md`) are matched by no arm. Measured as a widening
  rather than a regression: no path the pre-fix arms matched is silent under the current set, and
  `scripts/check-propagation-arms.sh` asserts that. Revisit when a consuming project actually keeps
  those mirrors.
- `GH-98` — the scouted fix-plan sequence (scout → mechanical gate → fix agent) shipped into the main
  feature-development flow only, on a cost baseline measured by hand from a single session. Its payoff
  has never been measured against a real firing, so the figure that would justify it does not exist
  yet. What is owed is a **like-for-like measurement of the review loop on the next real feature
  task** — the same loop, run through the scouted flow, measured the same way.

  **That measurement is the GATE on whether the mechanism is extended at all, not owed bookkeeping.**
  `GH-98` is written as a conditional: the extension to the three remaining fix-applying loops does
  not begin until a like-for-like measurement shows the effect, and if no effect shows the issue is
  **closed** rather than left open — raising instead whether the main-flow mechanism earns its keep.
  Extending on the analogy alone multiplies a cost that nothing has yet shown buys anything.

  **The baseline the comparison must be made against** (from GH-91, session
  `e330fc3e-e105-4690-8c78-37110ee25714`, the GH-52 task / PR #89): the review loop was **55% of task
  cost**; within that loop the orchestrator's own share was **58%** against the four review subagents'
  **42%**; orchestrator tool calls across the loop **66**, as **3 / 29 / 19 / 10 / 5** per round. The
  per-round counts are the comparison — **never an average**, which hides the round carrying a single
  trivial finding, and that round runs net-negative under the always-on rule by design.

  **A second debt, found on the mechanism's first real run and NOT closed: the threshold has never been
  recalibrated against a real firing.** The single `150` ships as a reasoned starting value, and the
  justification for shipping one number rather than two was that each verdict records the value it fired
  under, so the declared-vs-actual spread becomes measurable and the calibration arrives on its own.
  **As first recorded here, it could not:** the plan and its verdict lived only in the task's
  `*.progress.md` section, which is gitignored and deleted when the PR merges, so every round's figures
  died with it — which made "revisit once verdicts accumulate", the disposition recorded for the
  understated-plan residual in GH-91's spec and design, name a route that did not exist. That was the
  one place where GH-91's shipped answer made a different open question HARDER to resolve, which is why
  it is recorded beside the measurement gate rather than filed away.

  **That half is superseded — the route now exists, and this round built it.** `check-fix-plan.sh`
  appends one JSON row per firing to `~/.claude/harness/fix-plan/verdicts.jsonl`, a SIBLING of the loop
  ledger's directory and outside the progress file, carrying the branch, the round and its `round_base`,
  the decision and reason, the threshold value an escalation fired under, and — for the post-apply
  micro-loop — its iteration count, its tool-call cost and the bounded question's answer. Real rows
  from this branch have landed in it (as of 2026-10-07). So the figures no longer die with the round,
  and the disposition above names a route that exists.

  **What is still owed is the measurement, which the ledger does not supply.** One row is not a
  calibration: no threshold has been revisited, `150` remains the reasoned starting value, and the
  spread those rows exist to expose needs enough real firings to show one. Whether a persisted verdict
  is worth keeping at all is also still open — only where it lives is now settled. Closing this for
  tidiness would still remove the only path to ever recalibrating the threshold.

  **The weights are part of the baseline, not a choice.** Input-token equivalents at
  `fresh_input ×1 + output ×5 + cache_read ×0.1 + cache_creation ×2`, **deduped by message id**. A
  figure computed any other way is not comparable to the numbers above and the comparison is void;
  there is no partial credit for a differently-weighted measurement.

  **Read every number above as a FLOOR at its as-of stamp, never as a bare count.** The
  mechanism under measurement is the cache-read term, which scales as `context_size × calls × 0.1`, so
  the same round costs more the later in a session it runs — and the harness's own instruction surface,
  which every session and every subagent loads, grows each time anyone works on it. A later
  measurement whose figures exceed these is watching the thing move, not catching this entry out. What
  has to stay fixed for the comparison to mean anything is the METHOD and the per-round split, not the
  magnitude.

  **Unlike `GH-72`, this calibration does not arrive on its own.** The gate's verdict line records the
  threshold value it fired under, so a mis-set threshold self-reports from ordinary runs; the
  displacement figure does not. It needs a real feature task's review round measured deliberately, and
  nothing fires a reminder when one goes past unmeasured. GH-91's own round is explicitly NOT it — the
  diff under review there was instruction text and a check script rather than feature code, so its
  figure ships with a not-comparable note and settles nothing.
- _(closed 2026-09-14 — hook guards shipped in #3; `--scope user` is now the recommended install.)_
- _(closed 2026-09-14 — both recorded as approved exemptions in `docs/skill-size-exemptions.md`: they are
  ordered orchestrators, and splitting the sequence costs more than the length does.)_
- _(closed 2026-09-14 — the first `/harness:ai-audit global` ran and its findings shipped in #9.)_
