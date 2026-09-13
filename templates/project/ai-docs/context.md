# %PROJECT_NAME% — Project Context

> **Template.** Fill every `%PLACEHOLDER%` and delete the sections that do not apply. This file is read
> **on demand**, not auto-loaded — keep it factual and dense, and let the code stay the source of truth.
> Only write down what the code cannot tell a reader: domain vocabulary, cross-module invariants, and the
> reasons behind non-obvious structure.

## Overview

One paragraph: what this system does, who uses it, and what it integrates with.

---

# System Entities

Domain vocabulary. One `##` section per entity, each answering: what it is, what identifies it, what it is
often confused with, and where it lives in code.

## %Entity%

- **What it is.** One or two sentences.
- **Identity.** The field(s) that identify it, and any second id it is confused with.
- **Lifecycle.** Created by … / mutated by … / terminal states.
- **Code.** `path/to/Type` — the authoritative definition.

> Add an entity here when a `/task` introduces one, or when a correction shows the agent guessed its
> meaning wrong. Do NOT paste class listings; name the file and move on.

---

# System Design

## Services / processes

| Component | Responsibility | Entry point |
|---|---|---|
| `%service%` | `%what it owns%` | `%path%` |

## Key modules

| Module | Responsibility |
|---|---|
| `%module%` | `%what it owns%` |

## Tech stack

| Concern | Choice |
|---|---|
| Language / toolchain | `%LANGUAGES%` |
| Build | `%BUILD_TOOL%` |
| Test framework | `%TEST_FRAMEWORK%` |
| Mocking | `%MOCK_LIB%` |
| Assertions | `%ASSERTION_LIB%` |
| Framework / DI | `%FRAMEWORK%` |
| Persistence | `%DB%` + `%MIGRATION_TOOL%` |
| Logging | `%LOGGING%` |
| Metrics | `%METRICS%` |
| CI | `%CI%` |

## Language profile

| Field | Value |
|---|---|
| Primary language(s) | `%LANGUAGES%` |
| New-file rule | e.g. "new sources MUST be `%EXT%`; existing `%LEGACY_EXT%` files stay idiomatic, no proactive migration" |
| Max line length | `%MAX_LINE_LEN%` |
| Formatter | `%FORMAT_CMD%` |
| Linter (the gate) | `%LINT_CMD%` |
| Source root / test root | `%SRC_ROOT%` / `%TEST_ROOT%` |
| Test-file mapping | `<Name>` → `<Name>Test` under the test root, same package/module |

Idiom rules that only make sense for this project's language (stdlib preferences, DI conventions,
migration tool, metrics library) belong here, not in the harness's language-agnostic
`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`.

## Build & test commands

The canonical command table lives in this project's [`AGENTS.md` § Build & Test](../AGENTS.md#build--test); repeat here only the
project-specific details that do not fit a one-line cell (module addressing, profile flags, how to run a
single test, which suites need a container runtime).

## Code organization

```text
%repo%/
├── %module-a%/        # …
├── %module-b%/        # …
└── ai-docs/           # agent-facing docs (this file, plans, learnings)
```

- **Source root:** `%SRC_ROOT%` — **test root:** `%TEST_ROOT%`.
- **Test-file mapping:** `<Name>` → `<Name>Test`, same package/module.
- **Integration tests:** `%INT_TEST_LAYOUT%` (delete if the project has none).

## Request-scoped logging fields

The MDC/context field names in use, verbatim — agents must reuse these rather than invent variants:
`%field-one%`, `%field-two%`.

---

# Conventions worth writing down

Use this section for the rules a newcomer (human or agent) gets wrong on their first PR — the ones that
are conventions of *this repo*, not of the tooling. Each entry: the rule, one sentence of why, and the
directory to imitate.

- `%rule%` — `%why%`. Imitate: `%path%`.

---

# Open questions

Unresolved decisions, with the date raised and who owns the answer. Cleared as decisions land.

- _(none yet)_
