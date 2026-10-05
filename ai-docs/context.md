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

---

# System Design

## Layout

| Path | Role |
|---|---|
| `.claude-plugin/` | `plugin.json` (manifest) + `marketplace.json` (this repo as its own marketplace). **Declare a component key only for a NON-default location** — `hooks/hooks.json`, `skills/`, `agents/` are auto-discovered, and re-declaring one makes the plugin refuse to load it twice (`scripts/test-plugin-manifest.sh` guards this) |
| `skills/<name>/SKILL.md` | The 8 workflow skills |
| `agents/<name>.md` | The 7 subagents |
| `rules/ast-index.md` | Code-search hierarchy, inherited verbatim by subagents |
| `hooks/hooks.json` | The 12 hooks; `hooks/lib/` holds the shared guard and the plugin-path resolver (`plugin-ref.sh`) |
| `scripts/` | Plugin-level utilities shared by more than one skill (the promotion gate and sweep), the repository's own gates (`check-references.sh`, `check-release.sh`, `check-readme-update.sh`, `check-propagation-arms.sh`, `test-install-smoke.sh`, `test-upgrade-smoke.sh`), `run-checks.sh` as the single entry point for the pre-commit list, and the `test-*.sh` suites those and the skills' helpers are covered by |
| `docs/` | Method reference, incl. `agents-method.md` |
| `templates/project/` | What a consuming project gets scaffolded with |
| `ai-docs/` | This repo's own profile + plan/learning data |

## Tech stack

| Concern | Choice |
|---|---|
| Language | Markdown instruction files + POSIX shell |
| Build | none |
| Test | `bash scripts/run-checks.sh` — the whole structural list in one call; see `AGENTS.md § Build & Test` |
| CI | none yet |

## Language profile

| Field | Value |
|---|---|
| Primary language(s) | Markdown, POSIX shell (`bash`) |
| New-file rule | Method content is Markdown; executable helpers are `.sh` under `skills/<skill>/scripts/` |
| Max line length | soft 110 for prose; no hard limit |
| Formatter | none |
| Linter (the gate) | `shellcheck` for `.sh`; `jq -e .` for JSON manifests |
| Source root / test root | n/a — no compiled sources |

## Build & test commands

No build. The checks in `AGENTS.md § Build & Test` are the gate: six structural ones over the repo's
contents, plus three delivery gates (`test-install-smoke.sh`, `check-release.sh`,
`test-upgrade-smoke.sh`) that answer the question the structural ones cannot — does this reach a
consumer. The structural six run in one call as `bash scripts/run-checks.sh`, which reports a verdict per
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
- _(closed 2026-09-14 — hook guards shipped in #3; `--scope user` is now the recommended install.)_
- _(closed 2026-09-14 — both recorded as approved exemptions in `docs/skill-size-exemptions.md`: they are
  ordered orchestrators, and splitting the sequence costs more than the length does.)_
- _(closed 2026-09-14 — the first `/harness:ai-audit global` ran and its findings shipped in #9.)_
