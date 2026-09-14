# Agent Rules — agent-harness (profile)

> **This repo is the harness itself**, so it plays two roles at once: it *ships* the method half
> (`docs/agents-method.md`, `skills/`, `agents/`, `rules/`, `hooks/`) and it *consumes* it while being
> developed. The method file is the authority on how to work here — read it first:
> [`docs/agents-method.md`](docs/agents-method.md). In an installed project the same file is at
> `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md`.
>
> Everything below is this repo's own profile — the half a consuming project supplies for itself from
> [`templates/project/AGENTS.md`](templates/project/AGENTS.md).

## Build & Test

This repo ships instruction files and shell scripts; it has no compiler.

| Placeholder | Meaning | This project |
|---|---|---|
| `%BUILD_CMD%` | Compile the changed module | n/a — no build step |
| `%TEST_CMD%` | Run a module's tests | n/a — validation is the checks below |
| `%FORMAT_CMD%` | Auto-format changed files | n/a |
| `%LINT_CMD%` | Lint as the gate | `bash -n` on every `*.sh` and `jq -e .` on every manifest |
| `<module-path>` | How a module is addressed | a top-level dir: `skills/`, `agents/`, `docs/`, `rules/`, `hooks/` |

**Structural checks that stand in for a test suite** — run all four before any commit that touches
instruction files:

1. `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json` — manifests parse.
2. Every markdown relative link resolves, and every `#anchor` exists in its target.
3. No `${CLAUDE_PLUGIN_ROOT}` path points at a file that does not exist in this repo.
4. `bash -n` on every `*.sh`, and every test suite green:
   `scripts/test-plugin-manifest.sh`, `scripts/test-promotion.sh`, `scripts/test-audit-project.sh`,
   `hooks/lib/test-harness-managed.sh`, `skills/harness-init/scripts/test-scaffold.sh`.

`shellcheck` is **recommended but not required**, and deliberately not named as the gate: it is not
installed on every machine that edits this repo, and a gate that cannot run is worse than one that is
honestly absent. Run it when you have it.

## VCS

| Setting | Value |
|---|---|
| Default branch | `main` |
| Branch naming | `chore/<slug>` or `<TICKET-KEY>-<slug>` |
| Ticket key format | `none` — this repo has no tracker; specs carry `**Tracked in:** none — <reason>` |
| Review surface | GitHub PR via `gh` |

## Permissions — project specifics

- **DENY:** editing `~/.claude/plugins/**` from this repo. An installed copy of this harness is a build
  artefact; the source of truth is this working tree.

## Language profile

See [`ai-docs/context.md`](ai-docs/context.md) § Language profile. In short: Markdown instruction files
plus POSIX shell; no compiled sources.

## Project-specific conventions

- **Two surfaces, two audiences.** A file under `docs/`, `skills/`, `agents/`, `rules/` is **method** —
  it must hold in every project, so it may not name a language, a build tool, a domain entity, or a
  ticket prefix. A file under `ai-docs/` or `templates/project/` is **profile** — project facts live
  there. A method file that acquires a project fact is a `major` finding.
- **Paths inside method files are `${CLAUDE_PLUGIN_ROOT}`-relative; paths to project data are
  repo-relative.** `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` is method; `ai-docs/plans/…` is data and
  resolves against whichever project is open. Mixing them is the one mistake that breaks the harness for
  every consumer while still working here.
- **A skill script is invoked as `${CLAUDE_SKILL_DIR}/scripts/<name>`**, never by a repo-relative path —
  the plugin installs to a variable location.
- **Any PR touching plugin-loaded content bumps `.claude-plugin/plugin.json`'s patch version.** The
  install cache is keyed by version, so an unbumped fix silently never reaches an installed copy. See
  [`README.md` § Releasing](README.md#releasing).
