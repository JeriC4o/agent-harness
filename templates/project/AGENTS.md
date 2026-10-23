# Agent Rules — %PROJECT_NAME%

> **Profile half.** This file carries what is true of *this project only*. The method half — workflow
> AXIOMs, the Propagation Rule, the Learning Log contract, tooling and review rules — ships with the
> `harness` plugin at `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` and is read at session start.
> Where the two disagree about a project fact, this file wins; about method, the method file wins.
>
> Fill in every `%PLACEHOLDER%` below. An unresolved placeholder is a STOP, not a guess.

## Build & Test

| Placeholder | Meaning | This project |
|---|---|---|
| `%BUILD_CMD%` | Compile the changed module | `%FILL_ME%` |
| `%TEST_CMD%` | Run the checks a touched path selects — the narrowing form (+ the filter syntax for one test) | `%FILL_ME%` |
| `%FULL_CHECK_CMD%` | Run the full check list — once, after review approves, never inside a loop | `%FILL_ME%` |
| `%FORMAT_CMD%` | Auto-format changed files (NOT a gate) | `%FILL_ME%` |
| `%LINT_CMD%` | Lint as the gate (exits non-zero on violations) | `%FILL_ME%` |
| `<module-path>` | How a module is addressed on the command line | `%FILL_ME%` |

### Touched-scope selection

Inside a loop only the checks a touched path selects run, through `%TEST_CMD%`; the full list runs once at
the end. The rule: `${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md`.

**Path rule:** `%FILL_ME%` — which checks read which paths, e.g. "a touched path selects `%TEST_CMD%` for
its module, and `%LINT_CMD%` over the changed files".

**Mapping** — the cases the path rule cannot see, one row per touched path:

| Touched path | Selects |
|---|---|
| (none yet) | |

**Selection flag:** `%SELECTION_FLAG%` — the flag through which `%TEST_CMD%` names its selection, or `none`
when it selects by path alone.

Project-specific gate notes (profile flags, suites needing a container runtime, how to run a single
test) go in [`ai-docs/context.md`](ai-docs/context.md) § Build & test commands.

## VCS

| Setting | Value |
|---|---|
| Default branch | `main` |
| Branch naming | `<TICKET-KEY>-<slug>` |
| Ticket key format | `%TICKET_PREFIX%-NNN`, or `none` if the project has no tracker |
| Review surface | GitHub PR via `gh` |

## Permissions — project specifics

Machine-enforced entries live in `.claude/settings.json`. Add here only the honor-system rules that are
specific to this repo — paths that must never be read, services that must never be called, directories
an agent may not touch.

- _(none yet)_

## Language profile

See [`ai-docs/context.md`](ai-docs/context.md) § Language profile — primary language, new-file rule, line
length, formatter/linter, source and test roots, test-file mapping.

## Project-specific conventions

Rules a newcomer gets wrong on their first PR — conventions of *this repo*, not of the tooling. Each
entry: the rule, one sentence of why, and the directory to imitate.

- _(none yet)_
