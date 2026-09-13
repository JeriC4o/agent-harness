---
name: harness-init
description: "Scaffold the harness project profile into a repo and register it: copies AGENTS.md / ai-docs templates, resolves every %PLACEHOLDER% command with the user, and records the project in the harness registry. Idempotent — re-run to upgrade an existing profile."
disable-model-invocation: true
argument-hint: "[project-dir] (defaults to CWD)"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(scripts/scaffold.sh:*), Bash(git branch:*), Bash(git status:*), Bash(git checkout:*), Bash(ls:*), Bash(jq:*)
---

Scaffolds the **profile half** of the harness into a project: `AGENTS.md`, `ai-docs/context.md`, the
plans/learnings dirs, `.claude/settings.json`, and the `.gitignore` block — then registers the project so
cross-project commands can find it. The **method half** already ships with the plugin; nothing is copied
for it.

> Near-stateless: no `.progress.md` discipline applies; re-entry consists of re-invoking the skill.

> **Branch gate — first action.** Run `git branch --show-current`. If it is the default branch, create a
> branch before any write: this skill writes tracked files, and AXIOM 1 binds on any file edit. A repo
> with **no commits yet** is the documented exception — there is no default branch to protect, so
> scaffolding straight onto it is correct.

## Step 1: Scaffold (dry run first)

```bash
${CLAUDE_SKILL_DIR}/scripts/scaffold.sh <project-dir> --dry-run
```

Show the user what would be created and what already exists. **An existing file is never overwritten** —
a hand-edited `AGENTS.md` survives a re-run, and the script reports it as skipped. Then run for real:

```bash
${CLAUDE_SKILL_DIR}/scripts/scaffold.sh <project-dir> --name <name> --ticket-prefix <PFX|none> [--scope local]
```

- `--name` — defaults to the directory basename; substituted for `%PROJECT_NAME%`.
- `--ticket-prefix` — the project's ticket key prefix (`PROJ` → `PROJ-123`), or `none`.
- `--scope local` — excludes this project from future cross-project sweeps. Use it for client work or
  anything whose lessons must not travel.

**An omitted flag never wipes a previously recorded value** — a re-run is an upgrade, not a reset.

## Step 2: Resolve the commands (the point of the skill)

The scaffolder prints a detected build system and *suggested* commands. They are a starting point, not an
answer — **verify each one runs in this repo before writing it into `AGENTS.md`.** A command that was
guessed and never executed is the exact defect `design-review` rejects as a decorative gate.

For each of `%BUILD_CMD%`, `%TEST_CMD%`, `%FORMAT_CMD%`, `%LINT_CMD%` and `<module-path>`:

1. Propose the detected form; ask the user to confirm or correct it (`AskUserQuestion`, one round).
2. **Run it.** A build/test command that errors on its own repo is not a gate.
3. For `%TEST_CMD%`, also establish the **single-test filter syntax** and prove it selects: run it against
   one known test and match the reported count. A filter that matches nothing exits 0 and turns every
   later verification into a silent pass.
4. Write the confirmed value into the project's `AGENTS.md` § Build & Test table.

If no build system is detected, ask for all four outright rather than guessing.

## Step 3: Seed `ai-docs/context.md`

Fill what can be established cheaply, and leave the rest as explicit placeholders rather than invented
facts:

- **Language profile** — extension, line length, formatter/linter, source and test roots. Derive from the
  tree (`ls`, existing config files), not from the build system's conventions.
- **Overview** — one paragraph. Ask the user; do not paraphrase the README, which may be stale.
- **Entities / modules** — leave the template headings in place unless the user names them now. `/task`
  Step 9.5 appends them as they are discovered, which is more reliable than a cold guess.

## Step 4: Report

Show the user:

- files created vs left alone,
- each resolved command **and the evidence it ran**,
- the registry path and this project's entry (`jq '.projects[] | select(.path=="<dir>")' <registry>`),
- anything still carrying a `%PLACEHOLDER%`.

**An unresolved placeholder is a STOP, not a default.** A skill that hits one must ask, never guess a
command — guessing is how a fake green enters the workflow at step one.

## Registry

`~/.claude/harness/registry.json` (override with `$HARNESS_REGISTRY`):

```json
{ "version": 1,
  "projects": [ { "path": "/abs/path", "name": "demo-app", "ticket_prefix": "DEMO",
                  "scope": "shared", "harness_version": "0.1.0",
                  "registered_at": "2026-09-14", "updated_at": "2026-09-14" } ] }
```

One entry per absolute path, sorted by path. `scope: shared` opts the project into future cross-project
learning sweeps; `local` opts out. The registry holds paths and labels only — **never** project content.

**Stale entries are expected**: repos get moved and deleted. A consumer of the registry must skip an entry
whose `path` no longer exists rather than failing, and should offer to prune it.

## FORBIDDEN

- Overwriting an existing profile file. The script refuses; do not work around it with `Write`.
- Writing a `%PLACEHOLDER%` value that was not executed in this repo.
- Registering a project the user has not asked to register.
- Scaffolding onto the default branch of a repo that already has commits (AXIOM 1).
