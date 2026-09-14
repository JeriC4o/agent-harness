# agent-harness

Multiagentic workflow harness — a Claude Code **plugin** carrying a spec-driven task workflow, a reactive
bugfix loop, skeptical review subagents, and enforcement hooks. Install it once, use it in every project;
each project keeps its own context and its own learning log.

Everything in the plugin is **tool-neutral**: git + GitHub for VCS and review, `%PLACEHOLDER%` tokens for
the build, test, format and lint commands each project fills in.

## Install

One-time, per machine:

```bash
/plugin marketplace add JeriC4o/agent-harness
/plugin install harness@agent-harness
```

Skills are namespaced by plugin, so they are invoked as `/harness:task`, `/harness:bugfix`, and so on.

Choose the scope deliberately:

| Scope | Command | Use when |
|---|---|---|
| User | `claude plugin install harness@agent-harness --scope user` | You work across many repos. Hooks that presuppose a harness profile no-op in repos without one, so this is safe. |
| Project | `claude plugin install harness@agent-harness --scope project` | You want the choice committed in `.claude/settings.json` so your team inherits it. |

To pin a version instead of tracking `main`: `/plugin marketplace add JeriC4o/agent-harness@v0.1.0`.

**Requires:** `git`, `gh` (authenticated — `gh auth login`), and `jq`.

## Set up a project

Run once per repo, from the repo root:

```
/harness:harness-init
```

It scaffolds the **profile half** — `AGENTS.md`, `ai-docs/context.md`, the plans/learnings directories,
`.claude/settings.json`, and a `.gitignore` block — then walks you through resolving the commands the
workflow needs, and registers the project in `~/.claude/harness/registry.json`.

Three things it does deliberately:

- **It never overwrites an existing file.** Re-running it on an already-set-up repo is an upgrade, not a
  reset: your hand-edited `AGENTS.md` survives, and a flag you omit does not wipe a value it recorded earlier.
- **It makes you *run* each command before recording it.** A `%BUILD_CMD%` that was guessed and never
  executed is the exact defect the review agents reject, so the setup refuses to invent one.
- **`--scope local` opts a repo out** of any future cross-project learning sweep — use it for client work.

Then fill in what only you know: the overview paragraph and the domain entities in `ai-docs/context.md`.
Leave the rest as placeholders; `/harness:task` appends entities as it discovers them, which beats a cold guess.

Prefer to do it by hand? Copy `templates/project/` into the repo root, replace `%PROJECT_NAME%`, fill the
`§ Build & Test` table in `AGENTS.md`, and append `gitignore.snippet` to your `.gitignore`.

## Daily use

| You want to… | Run |
|---|---|
| Build a feature properly | `/harness:task <ticket-key or description>` — interview → spec → design → review → implement → verify → self-review → commit |
| Fix something broken | `/harness:bugfix <what is wrong>` — reproduces and writes a failing test *before* touching the fix |
| Plan without building | `/harness:interview` — produces a spec, parks it in `ai-docs/plans/deferred/` |
| Review a whole branch | `/harness:project-review` |
| Clean up after a merge | `/harness:pr-merged` — from the merged branch |
| Check the profile is still sound | `/harness:ai-audit project` — placeholders, dead commands, registry, gitignore |
| Turn repeated corrections into rules | `/harness:improve` — when ≥3 unescalated entries have piled up |
| Audit the instruction files themselves | `/harness:ai-audit` |

What accumulates in the repo as you work: specs and designs in `ai-docs/plans/` (moved to `done/` on
completion), and corrections in `ai-docs/learnings/<user>-<branch>.md`. **The learning log is per project
and committed with the code** — lessons from one repo never leak into another.

## Update

```bash
/plugin marketplace update agent-harness
```

Your project profile is untouched by an update — it lives in your repo, not in the plugin. If a new
harness version adds template files, `/harness:harness-init` picks them up on a re-run without disturbing
anything you have edited.


## The split: method vs profile

| | Ships with the plugin | Supplied by each project |
|---|---|---|
| **What** | How to work: workflow steps, review checklists, search discipline, Learning Log contract | What is true here: build commands, language, domain entities, permissions |
| **Where** | `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` | `AGENTS.md`, `ai-docs/context.md` |
| **Referenced as** | `${CLAUDE_PLUGIN_ROOT}/docs/…` | repo-relative `ai-docs/…` |

That second row is the whole trick. Method paths are absolute-by-variable, so they resolve wherever the
plugin is installed; data paths are repo-relative, so they resolve against **whichever project is open**.
A globally-installed skill writing `ai-docs/learnings/<user>-<branch>.md` therefore writes into the
current project — **per-project learning is a property of the addressing, not a feature to build.**

## Layout

```text
.claude-plugin/
  plugin.json              manifest
  marketplace.json         this repo as its own marketplace
skills/<name>/SKILL.md     the 8 workflows below
agents/<name>.md           the 7 subagents
rules/ast-index.md         code-search hierarchy, inherited verbatim by subagents
hooks/hooks.json           the 12 hooks (hooks/lib/ holds the shared guard)
scripts/                   utility scripts shared by more than one skill
docs/
  agents-method.md         the method rule surface, read at session start
  workflow.md              git/GitHub command map, PR shape, reading a test result
  code-style.md            language-neutral code style
  doc-convention.md        when a doc-comment is written, and its shape
  templates/               canonical .progress.md and Learning Log entry formats
templates/project/         what a consuming project gets scaffolded with
ai-docs/                   this repo's own profile + plan/learning data
```

## Workflows

| Skill | What it does |
|---|---|
| `/harness:task` | The full loop: interview → spec → design → design-review → implement → verify → self-review → commit. Steps are strictly ordered. |
| `/harness:bugfix` | Reactive: trace → root cause → failing test → fix → self-review. Test before fix, always. |
| `/harness:interview` | Requirements interview that produces the spec. Invoked by `/harness:task`, or standalone for spec-only work. |
| `/harness:context-reset` | Group handoff for large tasks, and the compaction-recovery protocol every orchestrator re-enters through. |
| `/harness:project-review` | Whole-branch review: findings table → fix loop → self-review until APPROVE. |
| `/harness:pr-merged` | Post-merge cleanup: switch to the default branch, pull, drop the branch's progress files, delete the branch. |
| `/harness:improve` | Folds merged learning files into the archive, finds repeating corrections, proposes rule escalations — and drafts promotion candidates for lessons that are about the method. |
| `/harness:improve-global` | Run in the harness repo: sweeps candidates across every registered project and promotes a rule once ≥2 of them hit it. |
| `/harness:ai-audit [global\|project]` | Audits an instruction surface: `global` checks the harness method files; `project` checks your profile — unresolved placeholders, commands that do not resolve, registry coherence, candidate hygiene, gitignore coverage. Detects the surface if you omit it. |
| `/harness:harness-init` | Scaffolds the project profile and registers the repo. Run once per project; idempotent. |

Subagents: `spec-writer`, `design`, `design-review`, `self-review`, `review-findings`, `self-improve`,
`learnings-escalation-audit`.

## Releasing

The plugin cache is keyed by **version**, so an installed copy only refreshes when
`.claude-plugin/plugin.json` carries a version it has not seen. A fix shipped without a bump reaches
nobody — `/plugin marketplace update` will refresh the marketplace metadata, report success, and leave the
old payload in place.

**Bump the patch version in the same PR as any change to plugin-loaded content** — `skills/`, `agents/`,
`rules/`, `hooks/`, `docs/`, `scripts/`, `templates/`. A change confined to `README.md` or `ai-docs/`
(this repo's own profile) does not ship to consumers and needs no bump.

Consumers update with:

```bash
claude plugin marketplace update agent-harness
claude plugin install harness@agent-harness --scope user
```

Then restart the session — hooks are read at start.

## Developing the harness itself

This repo consumes its own method file directly ([`docs/agents-method.md`](docs/agents-method.md)) rather
than through an install, so edits take effect without reinstalling. To exercise it as a real plugin:

```bash
claude --plugin-dir /Users/jc/projects/agent-harness
```

There is no build. The gate is four structural checks — JSON manifests parse, every relative link and
anchor resolves, every `${CLAUDE_PLUGIN_ROOT}` path exists, `bash -n` on every script — plus two delivery
gates: `scripts/test-install-smoke.sh` installs the working tree into a throwaway config and requires the
plugin to actually load, and `scripts/check-release.sh` refuses a branch that changed shipped content
without a version bump. See [`AGENTS.md` § Build & Test](AGENTS.md#build--test).

## Design notes

- **Fail-loud rules, soft patterns.** Prohibitions are AXIOMs with a trigger table; validated approaches
  are `## Patterns` blocks with soft verbs. [`docs/agent-writing-style.md`](docs/agent-writing-style.md)
  is the style contract for both.
- **One writer per artefact.** The orchestrator never writes `*.spec.md` / `*.design.md` — the owning
  subagent does. Violating that is how transcribed-instead-of-written docs drift.
- **Durable state survives compaction.** Every orchestrator carries a compaction-recovery callout at the
  top of its body and a `.progress.md` on disk, so a truncated session re-enters where it left off.
- **The Learning Log is append-only, and per project.** Corrections go to
  `ai-docs/learnings/<user>-<branch>.md` in the project they happened in. Escalating a lesson into the
  *harness* — where it would change behaviour for every project — is deliberately a separate act: the
  lesson must first be abstracted into a **promotion candidate** that passes a mechanical redaction gate
  (no repo name, ticket key, entity, path or URL), and `/harness:improve-global` promotes it only once
  **two distinct projects** have hit the same thing. The sweep reads candidates and nothing else, so the
  boundary is a file selector rather than an instruction to be careful.
- **Hooks catch what prose cannot.** Branch protection, gate-masking (`| tail` on a test run), learnings
  auto-staging, propagation reminders — see [`hooks/hooks.json`](hooks/hooks.json). Hooks that presuppose
  a harness profile are guarded and no-op elsewhere; hooks that encode pure method (do not mask a gate,
  do not scan `$HOME`) hold in every repo by design.

## Roadmap

The build-out is complete: the split (1), plugin packaging (2), project bootstrap (3), cross-project
learning (4), the audit's two surfaces (5), and hook guards (6).

What is *designed but not yet evidenced*: the `≥2 distinct projects` promotion threshold is reasoned, not
observed. It meets evidence the first time two real projects carry candidates — that, rather than more
building, is the next thing worth doing.
