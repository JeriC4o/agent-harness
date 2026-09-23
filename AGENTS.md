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
2. `bash scripts/check-references.sh` — markdown links and `#anchor`s resolve; every
   `${CLAUDE_PLUGIN_ROOT}` path exists here; and every bare `ai-docs/…` in a method file names a
   **documented** project-data root rather than a method file written in project spelling. That last
   class is why the script exists: the Propagation Rule's Spec-Amendment sync group pointed its final
   member at `ai-docs/workflow.md`, so that member was never once updated by a sweep, and neither
   hand-run check above could see it.
3. (folded into 2)
4. `bash -n` on every `*.sh`, and every test suite green:
   `scripts/test-plugin-manifest.sh`, `scripts/test-promotion.sh`, `scripts/test-audit-project.sh`,
   `scripts/test-trace-tokens.sh`, `scripts/test-session-events.sh`,
   `scripts/test-backlog-metrics.sh`, `scripts/test-fold.sh`, `scripts/test-check-references.sh`,
   `hooks/lib/test-harness-managed.sh`,
   `skills/harness-init/scripts/test-scaffold.sh`.

**Delivery gates** — the checks above validate this repository's CONTENTS; these two validate that the
contents reach a consumer. Both exist because a bug got past all four structural checks:

5. `bash scripts/test-install-smoke.sh` — installs the working tree as a plugin in a throwaway
   `$CLAUDE_CONFIG_DIR` and requires `✔ enabled` plus a full component inventory. Catches "installs but
   refuses to load". Requires the `claude` CLI; **exits 2 when it cannot run, which is not a pass.**
6. `bash scripts/check-release.sh` — refuses a branch that changed shipped content without bumping
   `.claude-plugin/plugin.json`. Catches "merged but never delivered", which a sandbox install cannot see
   by construction. Run it before opening a PR.

`shellcheck` is **recommended but not required**, and deliberately not named as the gate: it is not
installed on every machine that edits this repo, and a gate that cannot run is worse than one that is
honestly absent. Run it when you have it.

## VCS

| Setting | Value |
|---|---|
| Default branch | `main` |
| Branch naming | `<TICKET-KEY>-<slug>`, or `chore/<slug>` for work with no issue |
| Ticket key format | `GH-<issue number>` |
| Review surface | GitHub PR via `gh` |

**GitHub Issues have no key prefix** — an issue is a bare `#N`, and PRs share the same counter, so the
numbering is contiguous across both. `GH-` is a *local* prefix this repo adds so an issue number can ride
in a branch name and a spec header, where a bare `#` does not belong. It maps one-to-one:

| Surface | Form |
|---|---|
| The issue itself | `#10` |
| Branch | `GH-10-<slug>` |
| Spec header | `**Tracked in:** GH-10` |
| PR title | `GH-10: <conventional-commits header>` |
| Any `gh` command | `gh issue view 10` — **strip the prefix**; `gh` knows nothing about `GH-` |

> **Carve-out — `Closes #N` is permitted in a PR body**, and is the one trailer this repo allows despite
> the summary-only rule. It is an ACTION, not a reference: GitHub closes the issue when the PR merges.
> That is the intended behaviour here, and the softer cousin of the hazard
> [`docs/workflow.md` § PR title + body shape](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-title--body-shape)
> warns about — write it only for the issue the PR actually resolves, never for one it merely mentions.

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
