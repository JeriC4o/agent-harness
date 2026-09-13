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
- **Status.** Designed, not implemented — step 4 of the split plan.

---

# System Design

## Layout

| Path | Role |
|---|---|
| `.claude-plugin/` | `plugin.json` (manifest) + `marketplace.json` (this repo as its own marketplace) |
| `skills/<name>/SKILL.md` | The 8 workflow skills |
| `agents/<name>.md` | The 7 subagents |
| `rules/ast-index.md` | Code-search hierarchy, inherited verbatim by subagents |
| `hooks/hooks.json` | The 12 hooks |
| `docs/` | Method reference, incl. `agents-method.md` |
| `templates/project/` | What a consuming project gets scaffolded with |
| `ai-docs/` | This repo's own profile + plan/learning data |

## Tech stack

| Concern | Choice |
|---|---|
| Language | Markdown instruction files + POSIX shell |
| Build | none |
| Test | structural checks — see `AGENTS.md § Build & Test` |
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

No build. The four structural checks in `AGENTS.md § Build & Test` are the gate. They are hand-run today;
mechanising them as a script under `skills/ai-audit/scripts/` is an open task.

---

# Conventions worth writing down

- **`${CLAUDE_PLUGIN_ROOT}` for method paths, repo-relative for project data.** A method file that links
  to `ai-docs/…` breaks for every consumer — name project data in inline code, never as a markdown link.
- **Skill scripts run via `${CLAUDE_SKILL_DIR}/scripts/<name>`.** A repo-relative invocation resolves
  against the consuming project and silently fails there while working here.
- **Plugin skills are invoked namespaced**: `/harness:task`, not `/task`.

---

# Open questions

- 2026-09-14 — cross-project `/improve-global` + registry: designed, not built (steps 3–4).
- 2026-09-14 — hook guards for repos without `ai-docs/` (step 6); until then, prefer enabling the plugin
  at project scope rather than user scope.
- 2026-09-14 — `skills/task/SKILL.md` is 211 lines against the 200-line soft target; exemption or
  extraction, owner's call.
