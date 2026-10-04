# Design evidence — GH-75 hook path resolution

**Ticket:** GH-75
**Date:** 2026-10-01
**Design:** [`2026-09-30-hook-path-resolution.design.md`](2026-09-30-hook-path-resolution.design.md)

Verification records split out of the design at `design-review`'s direction, so the design carries the
**contract** and this file carries the **samples**. Nothing here is an instruction. Every record below is
reproduced at run time by `scripts/test-hook-behaviour.sh` (§ M1 states, arm membership) or
`scripts/check-propagation-arms.sh` (arm membership, controls) — these are the measured values, not the
source of truth.

> **An enumeration and its count travel together.** Each block below carries both. The design carries a
> pointer here and no bare count, because a pointer plus a bare count is the configuration that produced
> "11 controls" over an enumeration of ten.

---

## § M1 — the six root states, emitted tails

The design states the six states, their fixtures and the **state 4 ≡ 5 ≡ 6 byte-identity requirement**,
which is a contract (`hooks/lib/plugin-ref.sh`'s header cites it). Only the sample bytes live here.
Measured on an unguarded site, the `sh-syntax-check` shape.

| # | state | emitted tail |
|---|---|---|
| 1 | set, readable | `See <root>/rules/ast-index.md.` |
| 2 | **unset** | `See rules/ast-index.md — correct operation of the plugin requires read access to the plugin directory.` — no leading slash, no cause claimed |
| 3 | **empty string** | byte-identical to state 2 |
| 4 | set, **target file** unreadable (root traversable, resolver reachable) | `See <root>/rules/ast-index.md — correct operation of the plugin requires read access to the plugin directory <root>.` |
| 5 | set, **root** unreadable (resolver unreachable, fallback fires) | byte-identical to state 4 |
| 6 | set, resolver reachable but **silent** (hardened emptiness guard) | byte-identical to state 4 |

Group A confirmed 2 ≡ 3 and 4 ≡ 5 ≡ 6 with `cmp`, and that no state emits the degenerate `See .`.

---

## § M2 — arm membership, measured with the ten-arm set landed

**MEMBERS — 14 fired of 14 probed.** Each probed as an absolute path under the physical project root:

| # | representative | admitted by |
|---|---|---|
| 1 | `AGENTS.md` | named token |
| 2 | `CLAUDE.md` | catch-all row → the `> Applies to:` enumeration |
| 3 | `agents/design.md` | named token |
| 4 | `rules/ast-index.md` | named token (`rules/<file>.md`, `<…>`→`*`) |
| 5 | `rules/sub/x.md` | same arm; `case` globs cross `/` |
| 6 | `skills/task/SKILL.md` | named token |
| 7 | `skills/task/reference.md` | named token (ai-audit group row) |
| 8 | `skills/task/notes.md` | same arm, deliberately wider |
| 9 | `docs/agents-method.md` | named token |
| 10 | `docs/templates/learnings-entry-format.md` | same arm; globs cross `/` |
| 11 | `scripts/session-events.sh` | named token, **right cell only** (Inspect group anchor row) |
| 12 | `ai-docs/learnings/README.md` | named token |
| 13 | `ai-docs/context.md` | catch-all row → the `> Applies to:` enumeration |
| 14 | `.claude/skills/deploy/SKILL.md` | **carve-in** — catch-all row, no token can produce it |

**CONTROLS — 13 silent of 13 probed.**

| # | control | what it bounds |
|---|---|---|
| 1 | `my-agents/notes.md` | the dropped-`*/` repair |
| 2 | `sub-agents/x.md` | the dropped-`*/` repair |
| 3 | `src/docs/readme.md` | the dropped-`*/` repair |
| 4 | `node_modules/x/docs/a.md` | the dropped-`*/` repair |
| 5 | `vendor/scripts/build.sh` | the dropped-`*/` repair |
| 6 | `ai-docs/plans/x.spec.md` | non-member (the spec's named negative control) |
| 7 | `ai-docs/learnings/<user>-<branch>.md` | the one reasoned exclusion (Boundary rule 2) |
| 8 | `README.md` | non-member |
| 9 | `hooks/hooks.json` | non-member |
| 10 | a sibling project's `docs/a.md` | root anchoring |
| 11 | `.claude/skills/deploy/reference.md` | **distinguishes the spellings** — fires under the rejected `*.md` |
| 12 | `.claude/skills/notes.md` | **distinguishes the spellings** — fires under the rejected `*.md` |
| 13 | a sibling project's `.claude/skills/deploy/SKILL.md` | **the old UNANCHORED arm fired on this**; the root-anchored one does not, so restoring the class did not restore the cross-project false positive |

Controls 1–5 are the five the design keeps in body text: AC11 names them as required and the
false-positive bound is *defined* by them rather than sampled from them.

---

## Rejected-spelling measurement

The arm ships as `"$pd"/.claude/skills/*/SKILL.md`. The rejected `"$pd"/.claude/skills/*.md`:

| path | `*/SKILL.md` (shipped) | `*.md` (rejected) | old unanchored arm |
|---|---|---|---|
| `<pd>/.claude/skills/deploy/SKILL.md` | FIRES | FIRES | FIRES |
| `<pd>/.claude/skills/deploy/reference.md` | silent | **FIRES** | silent |
| `<pd>/.claude/skills/notes.md` | silent | **FIRES** | silent |
| `<sibling>/.claude/skills/deploy/SKILL.md` | silent | silent | **FIRES** |

The rejected spelling fires where the old arms were silent — it widens past the regression it exists to
repair, on the same ground the design uses to exclude the rest of `<pd>/.claude/**`.

---

## The project-side `.claude/**` mirror class

The `> Applies to:` enumeration is written in plugin-root spelling, so every class it names has a
project-side mirror the token harvest cannot reach. Measured silent under the shipped arms, **three**
besides the carve-in:

| mirror | verdict |
|---|---|
| `<pd>/.claude/agents/*.md` | silent |
| `<pd>/.claude/rules/**/*.md` | silent |
| `<pd>/.claude/commands/*.md` | silent |

Recorded as a bounded gap in the design, with the reason it is not closed here.

---

## The diagnostic's length is a function of its input

`design-review` measured the unusable-anchor diagnostic at 117 bytes for a 16-character anchor, 122 for
21 and 103 for 2; an independent re-derivation of the same relationship disagreed with that constant by
one byte, because neither statement recorded its capture method (whether the trailing newline is
included). **That disagreement is the argument:** no byte count for this message is assertable, the
design asserts the anchored marker prefix instead, and this file records the relationship — length grows
one-for-one with the anchor — without committing a constant.
