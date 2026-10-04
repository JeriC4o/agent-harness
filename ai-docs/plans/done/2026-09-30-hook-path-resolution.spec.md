# Hook path resolution — emit addresses that resolve, match paths that occur

**Source:** ticket GH-75
**Date:** 2026-09-30
**Amended:** 2026-10-01 — narrowed after `design-review` ITERATE; defect 3/3b split to **GH-77**, defect 4 and the L2 gate split to **GH-76**
**Tracked in:** GH-75

> **Note on notation.** `${CLAUDE_PLUGIN_ROOT}` written as a dollar-brace token means **the literal
> variable reference as it appears in `hooks/hooks.json`**, never the directory it expands to. Where the
> expanded value is meant, this spec writes *the resolved install path*. The distinction IS the defect; a
> quotation showing an absolute path where the manifest holds the variable was mangled in transit. Every
> string below was re-derived from `hooks/hooks.json`.

## What this task is, after narrowing

Two defects in `hooks/hooks.json`, one root cause: **the manifest names a variable where a value is
needed, and names the install location where the source tree occurs.**

`hooks/hooks.json` holds **25** occurrences of `${CLAUDE_PLUGIN_ROOT}` across **18** hook commands
(`grep -o` count; re-derive rather than trust the number). Classifying each by what precedes it:

| form | count | runtime behaviour |
|---|---|---|
| `"command": "\"${CLAUDE_PLUGIN_ROOT}` — the executable path, double-quoted | 11 | expands; correct |
| inside a single-quoted `echo` / `printf` payload the model reads | 12 | **stays literal** |
| inside the `PreToolUse [Edit\|Write]` `case` match pattern | 2 | expands, to the **install** dir |

**Split out of this task**, filed so nothing is dropped, each carrying `design-review`'s findings:

| Issue | What went | Why it is separable |
|---|---|---|
| **GH-76** | Defect 4 (`README.md:280` naming one author's home directory), the L2 shipped-surface gate and its exclusion list | A documentation-surface gate with its own scope question. Its exclusion list was found to miss `ai-docs/learnings.md` — which sits at `ai-docs/` rather than under `ai-docs/learnings/`, and which `/improve`'s fold legally appends into, so the gate would be permanently red with no permitted remedy. That is a scope problem to solve on its own, not a rider here. |
| **GH-77** | Defect 3 (the constant-true stale-merge predicate), defect 3b (`skills/bugfix/SKILL.md:157`), the full ten-occurrence `origin/main` disposition table, and the candidate predicate with its four-state evidence | A different file, a different mechanism, and a predicate that must be **designed** and exercised against a real branch per merge strategy. It was folded in by user decision at round 1 and is unfolded by user decision now. |

Both issues carry their reasoning verbatim; nothing was deleted to make this spec shorter.

## Defect 1 — model-facing hook text carries the variable unexpanded

**Established from production, not from a shell demo.** This project's real session transcripts under
`~/.claude/projects/-Users-jc-projects-agent-harness/*.jsonl`, grepped for the delivered
`additionalContext`, yield **69 deliveries** of:

```
REQUIRED SESSION START: read ${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md
```

Every one carries the literal token; **zero** carry a resolved path. This settles the mechanism: Claude
Code does **not** textually substitute the token in the command string — it exports an environment
variable, so a double-quoted occurrence expands and a single-quoted one does not. Had substitution been
textual, all 25 occurrences would resolve and no defect would exist.

Delivery is itself proof the variable was available *for that hook*: the command is chained behind
`"${CLAUDE_PLUGIN_ROOT}"/hooks/lib/harness-managed.sh || exit 0`, so an unresolved script path would
have suppressed the message entirely. The message arrived; the text still names the variable.

**That proof covers only half the sites.** Re-derived by parsing the manifest and counting each variable
role separately — the 12 prose sites are spread across **9** of the 18 commands:

| the 12 prose sites live in… | sites | is the variable ALSO used as an executable path there? |
|---|---|---|
| hooks guarded by `harness-managed.sh` (`SessionStart`, branch-block, `Co-Authored-By`, propagation reminder) | 6 | **yes** — expansion proven by delivery |
| unguarded pure-method hooks (ASK-gated-config, masked-gate ×2, archive-protection, learnings-append, sh-syntax) | 6 | **no** — the hook never references the variable except in its prose |

For those 6 sites the manifest never expands the variable at all, so nothing in current behaviour
demonstrates it is populated in their environment. A fix that assumes it is must handle an **empty**
root: naively injecting an unset variable turns the address into a root-relative
`/docs/agents-method.md`, which is worse than the literal because it looks resolvable.

**Why it crosses a project boundary.** In this repository the literal resolves by accident —
`docs/agents-method.md` exists relative to the working directory, so the agent reads the source copy and
nothing looks wrong. In a consuming project that file does not exist, and `SessionStart` fires *before*
any skill invocation, a skill invocation being the only place the resolved plugin directory is currently
stated. The nearest resolvable hint in reach is `~/.claude/harness/registry.json`, which harness skills
read legitimately and which carries this repository's own absolute path as a registered project. That is
the originating report: an agent in a consuming project reached for `agents-method.md` by an absolute
path into this repo's working tree and had to request permission to read outside its project.

The permission prompt was the rule working correctly — `ALLOW` covers project files, anything not
allow-listed is `ASK`. **The defect is that the harness induced the request.** Under a sandbox it is
worse than a prompt: the address is unusable and the agent has no fallback.

**The file it is sent for is present and readable; only the address is unusable.** Measured:
`docs/agents-method.md` exists in the installed tree at **35,927 bytes**, alongside a full directory
tree (`agents`, `docs`, `hooks`, `rules`, `scripts`, `skills`, `templates`, `AGENTS.md`, `CLAUDE.md`).

**No permission entry authorises that read today.** Measured across both shipped permission surfaces —
this repo's `.claude/settings.json` and `templates/project/.claude/settings.json`, which the scaffolder
ships into every consuming project — **neither holds any `Read(...)` allow entry covering the plugin
root.** The only `~/.claude` entry in either is `Edit(~/.claude/**)`. The read falls through to "ASK:
any tool not allow-listed", every session.

**The resolved address is version-pinned.** The install cache holds **14** coexisting version
directories; the newest **cached** one is `0.1.29`, while `0.1.30` is the version in the tree and not
itself cached. The resolved address therefore names a version-specific directory, and a permission entry
written as one fixed absolute path breaks on every upgrade — it has to be a glob over the cache.

## Defect 2 — the propagation-rule reminder is dead for nine of ten member classes

The `PreToolUse [Edit|Write]` reminder matches, verbatim from the manifest:

```
*AGENTS.md|*.claude/skills/*/SKILL.md|*${CLAUDE_PLUGIN_ROOT}/agents/*.md|*${CLAUDE_PLUGIN_ROOT}/rules/*.md
```

Re-measured by running that exact pattern in a `case`, with the real install root exported, against one
real edit path per class the Propagation Rule table names. **Representatives are absolute paths**, for
the reason in § Technical constraints:

| edited path | reminder | table membership |
|---|---|---|
| `<repo>/AGENTS.md` | **FIRES** | named |
| `<repo>/CLAUDE.md` | silent | catch-all row only — see below |
| `<repo>/agents/inspector.md` | silent | named (Review, Task/Design, Inspect, Learning-Log groups) |
| `<repo>/rules/ast-index.md` | silent | named |
| `<repo>/skills/inspect/SKILL.md` | silent | named |
| `<repo>/skills/ai-audit/reference.md` | silent | named (ai-audit group) |
| `<repo>/docs/agents-method.md` | silent | named — **no `docs/` arm exists at all** |
| `<repo>/docs/templates/learnings-entry-format.md` | silent | named (Learning-Log + Fold groups) |
| `<repo>/scripts/session-events.sh` | silent | named (Inspect group, output contract) |
| `<repo>/ai-docs/learnings/README.md` | silent | named (Learning-Log + Fold groups) |
| `<install>/agents/inspector.md` | **FIRES** | — |
| `<repo>/ai-docs/plans/x.spec.md` | silent | not a member — correct negative control |

**One of ten member classes fires.** The `agents/` and `rules/` arms fire only under the install path —
a location `AGENTS.md § Permissions` explicitly **DENIES** editing from this repo, so the only edit they
can catch is one the rules already forbid. The skills arm requires a `.claude/` path component this
repository does not have (its skills live at `skills/<name>/SKILL.md`). Corroborated by a live run: the
GH-72 task (PR #74, merged 2026-09-30) edited `agents/inspector.md` and `skills/inspect/SKILL.md` and no
reminder appeared at any point.

**Two member classes are wider than first recorded**, both found by enumerating the table rather than the
arms: `skills/*/reference.md` (the ai-audit group's own row) and `scripts/*.sh` (the Inspect group names
`session-events.sh` and `loop-metrics.sh` output contracts as sync-group members). Neither has ever had
an arm.

**`CLAUDE.md` is a member by the catch-all row only.** Measured: inside `docs/agents-method.md`
`## Propagation Rule` … `## Communication`, the only bare `CLAUDE.md` occurrence is a `wc -c` example
under a different section — the table names no `CLAUDE.md` row. Its membership comes from the final
fallback row, *Any other instruction file*. A derivation reading only the table's explicit path tokens
therefore **drops `CLAUDE.md`**, so it must account for the catch-all row rather than treating the table
as a closed path list.

This is the more serious of the two defects. The Propagation Rule is what keeps sync-group siblings from
drifting, and `AGENTS.md § Build & Test` already records a case where a missed sweep left a group member
stale for its entire life.

## Why no existing gate sees either

- `scripts/check-references.sh` L3 asks whether a `${CLAUDE_PLUGIN_ROOT}`-prefixed path **exists in this
  repo**. An existence question about the source tree. It says nothing about runtime resolvability by a
  consumer, and nothing about whether a match pattern matches anything.
- `scripts/test-plugin-manifest.sh` asserts only that hook commands carry no interior apostrophe (with
  its own positive control) and that each parses under `bash -n`. No assertion mentions
  `additionalContext`, `permissionDecisionReason`, or any matcher.
- **Nothing executes a hook and reads what it emitted.** That is the missing level, and the reason L3 is
  a named deliverable rather than an extra.

## Scope

1. **Defect 1 — the 12 model-facing message sites emit an address a consumer can act on.** Each emits
   the **resolved absolute path** of the installed copy. When that path cannot be shown, the message
   states that correct operation of the plugin requires read access to the plugin directory and **names
   it**. No copy of the method docs into the project; no hiding the location.
2. **Defect 1, accepted consequence — the harness authorises the read it asks for.** The method's
   `§ Permissions` gains the plugin root as a read-allowed location, and
   `templates/project/.claude/settings.json` (the machine-enforced surface the scaffolder ships to every
   consuming project) gains the matching `Read(...)` allow entry as a **glob over the version-pinned
   install cache**, not a fixed path. Without this the request fires every session and the new message
   explains a denial the harness itself never authorised.
3. **Defect 2 — the propagation reminder fires on method files edited where they actually live, and its
   arm list is DERIVED from the Propagation Rule table** rather than maintained beside it, with a gate
   asserting the two agree. Hand re-synchronising the ten classes is rejected: this defect exists
   *because* the arm list and the table drifted, so a hand fix re-opens on the next group member added.
   The derivation must account for the catch-all row.
4. **Write the boundary down.** An agent in a consuming project works from the installed copy and never
   from this repository's source tree, **even when `~/.claude/harness/registry.json` makes its path
   known**. The registry's contents are untouched.
5. **Tests — the named deliverable.** Two levels survive the narrowing (L2 left with GH-76):
   - **L1 (static)** — every occurrence of the variable in the manifest is exactly the double-quoted
     executable form; no model-facing text carries an unexpanded dollar-brace.
   - **L3 (behavioural)** — **execute** each hook and assert on what it **emits** and on which paths it
     **matches**. This is the level that catches defect 2: the broken `case` pattern is syntactically
     well-formed and points at a real directory, so no static pattern check can see it.
6. **Each level demonstrated able to FAIL against a committed control.** A check that cannot fire is
   this repository's most serious defect class, and an L3 that fails open is the specific hazard — see
   AC15.
7. **The new gate is registered as a numbered structural check**, not merely appended to a suite list.
   See AC18.
8. **`.claude-plugin/plugin.json` patch bump to `0.1.31`.** Measured: `main` and this branch both carry
   `0.1.30`, with 0 commits ahead. The install cache is keyed by version.

## Out of scope

- **Defect 4 / `README.md:280` / the L2 gate → GH-76.** Including the exclusion-list scope question.
- **Defect 3, defect 3b, the `origin/main` disposition table → GH-77.** Including the deliberate
  exclusion of `docs/workflow.md`'s recovery recipe and of `scripts/check-release.sh`'s script default,
  which are recorded on that issue rather than here.
- **Changing the permission model.** Reading outside the project stays `ASK` by default; scope item 2
  adds one narrowly-scoped read allowance for the plugin root, nothing wider.
- **Copying the method docs into consuming projects.** Rejected with reasons: the method file is the
  method half and ships with the plugin *by design*, while the profile half lives in the project.
  Measured — `templates/project/` ships `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`,
  `gitignore.snippet` and `ai-docs/**`, and no file from `docs/`. An in-project copy would create N
  copies that drift and would defeat plugin upgrades.
- **Changing what `~/.claude/harness/registry.json` contains.** Decided round 1; see § Key decisions.
- **Rewriting the 11 double-quoted executable-path occurrences.** They expand and are correct.
- **`hooks/lib/*.sh` internals**, beyond whatever L3 needs to invoke them.

## Deferred

| What | Why | Separate ticket? |
|---|---|---|
| `.claude/settings.json` and `templates/project/.claude/settings.json` overlap heavily but are **not** a named sync group, and no gate mirrors them — unlike `ai-docs/learnings/README.md`, whose mirror `check-references.sh` enforces. Re-derived with explicit labels: **`templates/project/.claude/settings.json` allow=21, deny=16**; **`.claude/settings.json` allow=10, deny=16** — the template holds **11 more** allow entries and the two deny lists are **byte-identical**. Noticed while measuring scope item 2, which edits one of the pair. | Observation, not this task's defect. Scope item 2 touches the template deliberately; whether the pair needs a Propagation Rule group is a question about the Propagation Rule table. | Yes — worth filing after this lands |

## Key decisions

| Question | Decision |
|---|---|
| **Defect 1 — what should a model-facing message say, given no in-project address exists?** | **The resolved absolute path of the installed copy**, plus: when that path cannot be shown, say that correct plugin operation needs read access to the plugin directory and **name it**. User's round-1 answer. No in-project copy, no hiding the location. |
| Does that decision imply a permission change? | **Yes, and it is accepted scope.** Naming a path the harness never authorised reading would fire the request every session and leave the message explaining a denial of the harness's own making. |
| Why not "never emit an out-of-project address at all"? | It would have required inventing an in-project copy of the method docs — measured absent from `templates/project/`, and absent *by design* per the method/profile split. |
| Is `CLAUDE_PLUGIN_ROOT` an environment variable or a textual substitution? | **Environment variable.** Settled by 69 production deliveries of the literal token; textual substitution would have resolved all 25 occurrences. |
| Is the variable proven available at every one of the 12 prose sites? | **No — at 6 of 12.** The other 6 live in unguarded hooks that never reference it as an executable path, so the fix must handle an empty root rather than assume one. |
| **Defect 2 — minimal repair, or widen?** | **Derive the arm list from the Propagation Rule table**, widened to every path class the table names, with a gate asserting the two agree. User's round-1 answer, chosen over hand-repairing three arms precisely because drift is the root cause. |
| How many member classes are broken? | **Nine of ten.** Round 1 undercounted by two classes (`skills/*/reference.md`, `scripts/*.sh`). |
| **Registry — stop exposing this repo's own path to consumers?** | **No. Write the rule only**; contents untouched. Once defect 1 hands the agent a resolvable address it stops hunting, so the registry is no longer a hint that leads anywhere. Measured cost of the alternative: the registry is read by **nine** files, including three test suites and the whole promotion pipeline. |
| **Why narrow now, after two amendment rounds of widening?** | `design-review` returned ITERATE with five `major` findings, and artefact size was part of the diagnosis: several findings were the documents losing accuracy as they grew. Narrowing is the user's decision and is the remedy for the finding, not a retreat from it. Nothing is dropped — GH-76 and GH-77 carry the reasoning verbatim. |
| Does the ticket's "What closing this needs" list bind as a DoD? | Yes — recorded in § Scope and encoded as ACs rather than one-time verifications. |
| Where do the tests live? | **Design's call.** `scripts/test-plugin-manifest.sh` is the closest existing home for L1 and L3. |
| Test framework | None. Validation is the structural checks in `AGENTS.md § Build & Test`. |
| Branch / ticket format | `GH-75-hook-path-resolution`, already checked out. |

## Technical constraints

- **Record the DERIVATION, not the derived value, whenever the value can move.** A line anchor, a count,
  an id, a size and a revision are all mutable facts; writing one down freezes a measurement that was
  correct when taken and is wrong as soon as anything shifts. **The instances this task has produced are
  enumerated in the Learning Log for this branch** — deliberately not counted here, because every
  previous draft of this sentence carried a number that the next round falsified. The pattern is stable
  even where the tally is not: a correct *mechanism* arrives with a wrong *count*. The rule for every
  artefact here: **state the command that yields the value**, and treat any number written beside it as
  illustrative. Where a quantity must be a gate, it is **re-derived at run time**. This binds the
  implementation's prose and commit messages, not only its code.

- **The marker landscape, measured — why AC2a needs a construction-unique key and AC15a scopes
  disjointness.** 18 commands; **16** distinct `statusMessage` values; **16** distinguishable commands.
  Two `statusMessage` values appear twice, and in both cases the two commands' strings are
  **byte-identical**: `loop-result.sh` on `PostToolUse/*` and `PostToolUseFailure/*`, `loop-verdict.sh`
  on `Stop` and `SubagentStop`. Emitted markers:

  | group | commands | marker |
  |---|---|---|
  | distinct bracketed marker | 6 | `[auto-stage-learnings]`, `[propagation-rule-reminder]`, `[archive-protection-reminder]`, `[learnings-append-check]`, `[sh-syntax-check]`, `[pr-body-sync]` |
  | shared bare prefix | 6 | `BLOCKED:` — distinguishable only by message body, not by prefix |
  | shared bracketed marker | 3 | `[loop-index]`, emitted by **two different scripts** (`loop-index.sh` and `loop-verdict.sh`) |
  | no bracketed marker | 2 | `loop-result.sh` emits none |
  | JSON, not a bracketed line | 1 | `SessionStart` |

  Re-derive each figure; the shape is the load-bearing part, not the tallies.

- **Every L3 assertion is EXACT or ANCHORED, never a substring test, and the suite carries a control
  proving the wrong output does not satisfy the right assertion.** Verified on the shape that prompted
  this: `STALE` is a substring of `NOT-STALE`, so both a bare `grep 'STALE'` and a glob `case *STALE*`
  match the wrong verdict, while `[ "$out" = "STALE" ]` correctly does not. The verdict case itself left
  with GH-77; the rule stays, because every marker assertion L3 makes is exposed to it. A suite whose
  markers are substrings of one another passes on the wrong output.

- **An L3 assertion must not be satisfiable by EMPTY output.** With a generic payload **all 18 commands
  emit 0 bytes** — each is a conditional gate that fires only on its own trigger. An absence assertion
  ("the output contains no dollar-brace") is therefore satisfied by a hook that ran and did nothing, and
  by a hook that failed to run at all. Every assertion pairs "emitted its own expected marker" with the
  property under test. This is the failure that already occurred once in this task: an arm probe
  reported all twelve paths firing **including the negative control**, because the extracted command
  file did not exist and every run printed an error to stderr.

- **`tool_input.file_path` is absolute, so propagation representatives must be absolute.** Measured over
  this project's real transcripts, scoped to the tools the hook's matcher actually selects
  (`Edit`/`Write`/`MultiEdit` `tool_use` blocks): **519 paths, 519 absolute, 0 relative**. Re-derive
  rather than trust the number; the direction is the load-bearing part. This matters because the arm
  requires a `/` before `agents`, which a repo-relative path has not got: `agents/design.md` is
  **SILENT** against the arm while `<root>/agents/design.md` **FIRES**. A representative recorded
  relative makes a correct arm look broken, and the natural repair — dropping the leading `*/` — is
  measurably worse: `*agents/*.md` then fires on `my-agents/notes.md` and `sub-agents/x.md`, and the
  sibling arms fire on `src/docs/readme.md`, `node_modules/x/docs/a.md` and `vendor/scripts/build.sh`,
  past the false-positive bound below.

- **False-positive bound on a widened arm.** An arm such as `*/agents/*.md` fires in **any**
  harness-managed project with an `agents/` directory. The reminder never blocks (stderr, exit 0), so
  the cost is noise rather than obstruction, and the `harness-managed.sh` guard bounds the blast radius
  to opted-in projects — but an arm that additionally matches `my-agents/` or `node_modules/` is outside
  the bound, not merely noisier.

- **A static L1 may NOT identify single-quoted regions by splitting on apostrophes.** Re-measured: of
  the 18 hook commands, exactly **one** — the ASK-gated-config hook — has **odd** apostrophe parity,
  because it contains `tr -d "'"`, an apostrophe inside *double* quotes. Any check that pairs
  apostrophes to decide which regions are single-quoted has its parity flipped from that point and
  misclassifies the remainder of that command, including the prose site it carries. L1 must be a
  property every occurrence must hold, not an inference about which region an occurrence sits in.

- **A windowed L1 grep silently misses a boundary occurrence.** Verified: on a crafted command whose
  variable reference sits at the very start (or very end), `grep -o '.\{1\}\${CLAUDE_PLUGIN_ROOT}'`
  returns **0** while the unwindowed count is **1**. Today both counts are **25**, so the hole is
  latent — but L1's whole claim over the parity approach is that it holds for *every* occurrence, so it
  needs a conservation assertion (AC12).

- **No interior apostrophe anywhere in a hook command.** Guarded by `scripts/test-plugin-manifest.sh`
  with its own positive control — a **fourth** recurrence of that defect. An apostrophe inside a
  single-quoted region closes the string and the shell re-parses the remainder, so the reported error
  line is usually far from the real one. A `jq` rewrite of the message sites can reintroduce one.
- **`printf` format-string safety.** The prose sites sit inside single-quoted `printf` formats that
  already carry `%s` conversions (e.g. the propagation reminder's `You are editing %s`). A resolved path
  is data and belongs in an **argument**, never in the format.
- **The `harness-managed.sh` guard is per-hook and deliberate.** Six hooks are prefixed with
  `"${CLAUDE_PLUGIN_ROOT}"/hooks/lib/harness-managed.sh || exit 0`; the rest encode pure method and
  carry no guard on purpose. The guard passes when the project holds `ai-docs/` **or** `AGENTS.md`
  (keyed on `CLAUDE_PROJECT_DIR` or `$PWD`). L3 must set up whichever condition each hook requires, or
  it measures nothing — a guarded hook run in a directory with neither marker exits 0 silently.
- **The resolver lives inside the plugin root.** That is why an unreadable root cannot be probed by
  `chmod`-ing the root itself: the guard script becomes unexecutable and every guarded-hook assertion
  goes vacuous. The consequence to probe instead is behavioural — see AC5.
- **Method/profile split.** `hooks/`, `skills/`, `agents/`, `rules/`, `docs/`, `scripts/` are **method**
  files: no language, build tool, domain entity, default-branch name or ticket prefix. Project facts
  live in `ai-docs/` or `templates/project/` — which is why scope item 2's machine permission entry
  belongs in `templates/project/.claude/settings.json` and its honour-system statement in the method
  file. `docs/agents-method.md § Permissions` states its own reason: duplicating the machine-enforced
  list into the method file lets the two drift.
- **Check 4's mandated form is load-bearing, and this task creates scripts.** `git ls-files -z '*.sh'`
  piped into `xargs -0 -n1 bash -n`, and not otherwise — the three natural alternatives all report
  success on a file that does not parse. `git ls-files` lists **tracked** files only, so
  `git add -N <new paths>` must run first, and the **file COUNT** the gate processed must be checked,
  not only its exit status.
- **Committed mode is not uniform, so AC19 must not assume it.** Measured: `scripts/check-release.sh`
  and `scripts/check-references.sh` are committed **100644**, `scripts/test-plugin-manifest.sh`
  **100755**. Both are invoked as `bash scripts/…` in `AGENTS.md`, where the executable bit is not
  needed. The bit is load-bearing only for a script production invokes **by path**.
- **`scripts/check-references.sh` must stay green**, including its existence check over every new
  `${CLAUDE_PLUGIN_ROOT}` reference, its `AGENTS.md § …` section check, and the byte-identity check on
  the scaffolded learning-log copy.
- **Delivery gates.** `scripts/check-release.sh` refuses a branch that changed shipped content without a
  `plugin.json` bump. `scripts/test-install-smoke.sh` and `scripts/test-upgrade-smoke.sh` **exit 2 when
  they cannot run, which is not a pass.**

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Executing the `SessionStart` hook command with the plugin root set to an arbitrary directory yields an `additionalContext` whose method-file reference is a **resolved absolute path** under that directory, carrying no dollar-brace, and actionable by an agent that knows nothing but that message. |
| AC2 | **Two-part, per command, over all 18:** for each hook command the suite asserts (i) the command **emitted its OWN expected marker** for a payload that triggers it, and (ii) that emitted text contains **no unexpanded dollar-brace**. Leg (i) is mandatory because leg (ii) is a pure ABSENCE assertion that empty output satisfies — and with a generic payload all 18 emit 0 bytes. An absence assertion published without its marker is not a pass. |
| AC2a | **The suite selects each command by a key that is unique BY CONSTRUCTION**, not by its emitted text or its `statusMessage`. The manifest triple — event, matcher, index within the matcher's group — is measured **unique, 18 of 18**, and so is the equivalent `jq` path; either is acceptable and both are free. A key derived from output cannot be unique, because four commands are indistinguishable by output (§ Technical constraints → marker landscape). |
| AC3 | **A per-hook trigger inventory is a deliverable, not an implementation detail:** for each of the 18 commands, the input that makes it emit is recorded and used. Measured examples — `sh-syntax-check` needs a `.sh` that fails `bash -n` (606 bytes emitted when supplied, 0 otherwise); the ASK-gated-config hook needs a matching search command; the masked-gate hook needs a piped gate. **A command that cannot be made to emit is a suite FINDING, not a pass**, and is reported as such rather than counted green. |
| AC4 | With the plugin root **unset** or **set to the empty string**, no hook emits a root-relative address such as `/docs/agents-method.md`. The 6 prose sites in unguarded hooks are covered, and at least one is exercised directly. |
| AC4a | **A POSITIVE assertion on the address itself**, at address granularity: each emitted reference is asserted to be an absolute path that begins with the root under test and ends in the expected method-file name. An absence-only formulation is insufficient — with the resolver reachable but printing nothing, a site emits `… See .` and every other stated assertion still passes: leg (i) finds the command's marker (present regardless of the address), leg (ii) finds no dollar-brace, and AC4 is itself an absence check. **This state is reachable rather than contrived**, because the resolver's contract is always-exit-0, so the fallback fires only when the resolver is *unreachable* and never when it *fails*. |
| AC4b | **Generalised, and binding on every criterion in this table:** AC2 leg (i)'s marker is at **command** granularity while the property under test is at **address** granularity, and a command-level marker cannot make an address-level assertion non-vacuous. Wherever an assertion concerns a substring of a command's output, the non-vacuity witness must be at that substring's granularity, not the command's. |
| AC5 | With the plugin root **set but unreadable**, the message states that correct operation requires read access to the plugin directory and **names that directory**. Its stated cause is **agnostic** — e.g. "its absolute path cannot be shown here" — and must NOT assert that the variable is unset, because in this state it **is** set. Asserted by execution, not by matching source text. |
| AC6 | The four root states are each exercised: **set and readable**, **unset**, **empty string**, **set but unreadable**. AC1 covers the first, AC4 the middle two, AC5 the last. |
| AC7 | The method's `§ Permissions` names the plugin root as a read-allowed location, and `templates/project/.claude/settings.json` carries a matching `Read(...)` allow entry written as a **glob over the version-pinned install cache**, so it survives an upgrade. Asserted, given that neither surface holds any such entry today. |
| AC8 | The `PreToolUse [Edit\|Write]` propagation reminder **FIRES** for every member class the Propagation Rule table names — at minimum the nine measured silent today: `CLAUDE.md`, `agents/*.md`, `rules/*.md`, `skills/*/SKILL.md`, `skills/*/reference.md`, `docs/*.md`, `docs/templates/*.md`, `scripts/*.sh`, `ai-docs/learnings/README.md` — and keeps firing for `AGENTS.md`. **Every representative is an ABSOLUTE path**, per the transcript measurement in § Technical constraints; a relative representative makes a correct arm look broken. |
| AC9 | The arm list is **DERIVED** from the Propagation Rule table rather than maintained beside it, and a gate asserts the two agree — failing when a path class is added to the table with no corresponding arm. Demonstrated by planting a member row and showing the gate fails. |
| AC10 | AC9's derivation covers the table's **catch-all row**: `CLAUDE.md` is a member through *Any other instruction file* and through no named path token, so a derivation reading only explicit tokens is shown NOT to drop it. |
| AC11 | **Negative controls, plural, and inside the false-positive bound:** at least one non-member path is shown silent (`ai-docs/plans/*.spec.md`), AND the widened arms are shown silent on `my-agents/notes.md`, `sub-agents/x.md`, `src/docs/readme.md`, `node_modules/x/docs/a.md` and `vendor/scripts/build.sh` — the paths a leading-`*/`-dropped arm was measured to catch. |
| AC11a | **Anchoring the arms on the repo root introduces silent fail-open inputs, and four are asserted controls — each shown SILENT-versus-FIRING, so a fail-open is a failed test rather than a quiet loss of the entire reminder:** (a) **trailing slash** on the anchor; (b) **realpath divergence** — the anchor and the incoming path naming the same directory by different spellings; (c) a **relative** anchor; (d) a **non-root working directory**. Each of (a)–(c) is required as an explicit control; (d) is required at least as a documented invocation condition. An arm that matches nothing must fail the suite, never pass it quietly. |
| AC11b | **Case (b) is demonstrated, not hypothesised.** Measured on this platform: `/tmp` is a symlink to `private/tmp` and `realpath /tmp` yields `/private/tmp`; real transcripts in this project carry `Edit`/`Write` `file_path` values under `/private/tmp/…` (112 in the sampled set, re-derive rather than trust the number). So an anchor captured as `/tmp/...` and a payload arriving as `/private/tmp/...` name one directory and match no arm. The suite normalises both sides, or asserts the divergent pair explicitly. |
| AC12 | **L1 gate** — every occurrence of the variable in the manifest is exactly the double-quoted executable form, expressed as a property of each occurrence rather than an inference about quoting regions. It carries a **conservation assertion: the windowed match count equals the unwindowed total**, so a boundary occurrence cannot be invisible to it. Demonstrated to FAIL against a planted unexpanded reference AND against a planted boundary occurrence. |
| AC13 | **L3 gate** — a check **EXECUTES** each hook and asserts on what it emits and on which paths it matches, demonstrated to FAIL against the pre-fix `case` pattern as a committed defect-2 regression fixture. Behaviour, not source text. |
| AC14 | L3 satisfies each hook's own precondition: for a `harness-managed.sh`-guarded hook the test directory carries a harness marker, and the suite **proves** the guard passed rather than assuming it — an assertion that would fail if the hook had silently no-opped. |
| AC15 | Every L3 assertion is **exact or anchored**, never a substring test, and the suite carries a control showing that the **wrong** output does not satisfy the right assertion. |
| AC15a | **Marker disjointness is required pairwise across DISTINCT commands only.** Two commands whose command strings are byte-identical emit identical text by construction and cannot be made disjoint — measured: `loop-result.sh` backs `PostToolUse/*` and `PostToolUseFailure/*`, and `loop-verdict.sh` backs `Stop` and `SubagentStop`, both pairs byte-identical. Requiring disjointness over all 18 is unsatisfiable; requiring it over the 16 distinguishable commands is not. Each identical pair is instead distinguished by its selection key (AC2a), not by its output. |
| AC15b | **A marker table covers all 18 commands, or names each command it leaves unmarked and why.** The landscape is measured in § Technical constraints: only **6** commands carry a distinct bracketed marker today, **6** share the bare prefix `BLOCKED:`, **3** share `[loop-index]` (emitted by two different scripts), **2** emit no bracketed marker at all, and `SessionStart` emits JSON rather than a bracketed line. The 12 unmarked commands are where a collision actually bites, so silence about them is the defect this criterion closes. |
| AC16 | Each control is a committed fixture or an in-suite planted case, re-runnable by a later reader — not a claim in a commit message that the author checked once. Recomputed for what this task actually contains: **AC4a** (the degenerate-address state), **AC9** (planted table member), **AC11a** (the three fail-open anchor inputs), **AC12** (planted unexpanded reference and planted boundary occurrence), **AC13** (the pre-fix `case` pattern) and **AC15** (wrong output against the right assertion). |
| AC17 | The written-down boundary states that an agent in a consuming project works from the installed copy and never from this repository's source tree, even when `~/.claude/harness/registry.json` makes its path known. It lands in a **method** file (project facts forbidden there), and any `AGENTS.md § …` reference it adds passes `check-references.sh`. |
| AC18 | **The new propagation-arms gate is registered as its own NUMBERED structural check in `AGENTS.md § Build & Test`**, alongside checks 2 and 5 — not merely added to check 4's list, which is a list of *test suites*. Without this, nothing documented runs the gate on a later branch and the standing-proof criterion has nothing standing behind it. |
| AC18a | **Every claim of the check COUNT is updated, and the obligation is discharged BY SEARCH rather than against a list.** A list of these dependents has now been wrong twice — the design found two, review found two more, and the true set is four: `AGENTS.md` (twice — "run all five" and "the five structural checks cannot see delivery"), `README.md` (the count plus its enumeration of what the five are), and `ai-docs/context.md` (which carries **both** the structural count and the "three delivery gates" count, so one file moves two numbers). The AC is satisfied by re-running the search and updating every hit, not by matching this enumeration. |
| AC18b | **Numbered cross-references are a second dependent class, distinct from the count.** The list in `AGENTS.md § Build & Test` runs 1–8 continuously (1–5 structural, 6–8 delivery), so inserting a sixth structural check collides with the delivery gate currently numbered 6 and shifts `AGENTS.md`'s "invisible to gate 6" reference. Prior art exists in the same list — item 3 reads "(folded into 2)", a tombstone that kept the numbering stable through a removal — so a non-renumbering option is available. Which option is taken is design's call; leaving the cross-references inconsistent is not. |
| AC18c | **`ai-docs/context.md`'s exclusion from the new arms is a RECORDED DECISION, not a gap.** It is a *profile* file, named **0** times in the Propagation Rule table, so the derived arms do not reach it — yet it demonstrably carries text that must move when `AGENTS.md § Build & Test` changes. Three independent safety nets (the design's enumeration, this task's file list, the new arms) all missed the same file. If the exclusion stands, the spec records that context.md's propagation is **enumerated by hand**, so the silence is deliberate. Note the tension with AC10: `CLAUDE.md` is admitted via the catch-all row *Any other instruction file*, and `context.md` answers that description too — design must state why the catch-all admits one and not the other, or admit both. |
| AC19 | For each **new** `*.sh` the spec's invocation form is stated and honoured: a `scripts/` **gate** is invoked as `bash scripts/<name>.sh` and needs no executable bit (`check-release.sh` and `check-references.sh` are committed 100644); a script production invokes **by path** — e.g. under `skills/*/scripts/` — is committed executable and is exercised by path in at least one assertion. This criterion scopes to NEW scripts only and mandates no particular mode-inspection idiom. |
| AC20 | No hook command gains an interior apostrophe (`test-plugin-manifest.sh`'s count stays at 0) and every command still parses under `bash -n`; no resolved path is injected into a `printf` **format** string rather than an argument. |
| AC21 | All five structural checks green, with check 4 run in its mandated form after `git add -N` on every new script, and the **processed file COUNT** verified — not only the exit status. |
| AC22 | `.claude-plugin/plugin.json` bumped to `0.1.31`, and `scripts/check-release.sh` green. |

## Open questions

None. The round-1 questions were answered, the Spec-Amendment decisions are in § Key decisions, and the
narrowing is recorded with its issues in § What this task is.

One item is deliberately left to design rather than pre-empted:

- **Where AC9's derivation lives** — a generated arm list, a check that parses the table, or the table
  becoming a single source both read. All three satisfy AC8–AC10.
