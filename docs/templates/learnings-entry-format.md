# Learnings-entry format (canonical template)

Read THIS for the Learning Log entry format — do **not** re-read the log just to recall the shape. Reserve reading the log for its CONTENT (recurrence / escalation audit, dedup check, prior entries), and read it as the union: `ai-docs/learnings.md` **plus** every `ai-docs/learnings/*.md` are one single history.

The authoritative rules live in **AGENTS.md § Learning Log**; field semantics in **`${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md`**. This file is the quick-reference template only.

## Target file

**A new entry is authored into `ai-docs/learnings/<username>-<branch>.md` — never appended to `ai-docs/learnings.md`**, which is the archive (existing history + the destination of `/improve`'s fold). Directory contract, union semantics and the fold: `ai-docs/learnings/README.md`.

Derive the path mid-task from two commands — no directory listing, no lookup:

| Component | Source |
|---|---|
| `username` | `whoami` |
| `branch` | `git branch --show-current` |

Sanitize `username` and `branch` **independently** through this pipeline — replace every character outside the allowed set with `-`, collapse each run of `-`, then strip leading/trailing `-` and `.`. **This is the tree's ONLY copy; every other file links here instead of restating it.**

```
sed 's/[^A-Za-z0-9._-]/-/g; s/--*/-/g; s/^[-.]*//; s/[-.]*$//'
```

| Branch | Target file |
|---|---|
| `learnings-per-branch-files` | `ai-docs/learnings/maratik-learnings-per-branch-files.md` |
| `users/maratik/better-pgdriver` | `ai-docs/learnings/maratik-users-maratik-better-pgdriver.md` |
| `main` | `ai-docs/learnings/maratik-main.md` |

**The default branch is not special-cased.** `branch` is literally `main`, so the target is `ai-docs/learnings/<username>-main.md` — per-user, therefore still conflict-free, and an ordinary foldable file. That name exists so the derivation is *total* (never undefined), **not** as a licence to stay on `main`: AXIOM 1 still requires a feature branch before any PR-targeted edit, entry writes included.

**Why this shape — disjoint filenames.** One file per user per branch **cannot collide** with another user's or another branch's file, and that is exactly what makes two branches' entries merge without a conflict: each branch adds a file no other branch touches, so the merge is a pure add instead of two appends racing for the same trailing lines. Sanitization is not injective in principle (`a/b` and `a-b` compose to the same basename); no such pair exists today, and a collision would degrade only to one shared file — today's behaviour — never to data loss.

## Entry template

```
### YYYY-MM-DD — [category] — [short description]
**What happened:** [quote or paraphrase of the incident / observation]
**Rule:** [what to do instead, or what to keep doing]
**Kind:** correction | validation    (optional; defaults to `correction` when omitted)
**Escalated?** no | AGENTS.md | skill:[name] | hook | settings | agent:[name] | rules:[name] | templates:[name] | doc-convention | code-style | workflow | context.md | claude-tools-hierarchy    (comma-separate multiple)
**Superseded by:** [ref] — [one-line reason]    (optional; omit when not applicable)
```

- `category` ∈ `code-style | process | architecture | testing | documentation | tooling | search | other`.
- `Kind: validation` = a working protocol/pattern to KEEP doing (carrot). `Kind: correction` (or omitted) = a violation to STOP doing (stick). **`Kind:` is a CLOSED enum — those two values or omitted, nothing else.** An invented third value (`confirmed-approach`, `insight`, `note`) does not fail loudly: the Correction pass matches `correction`, the Carrot pass matches `validation`, so an off-schema entry falls through BOTH and becomes invisible to `/improve` — the one thing the log exists to feed. It also cannot be repaired in place (Hard rule 1), so the only remedy is appending a correcting entry.
- Convert relative dates to absolute (`YYYY-MM-DD`).

## Hard rules (see AGENTS.md § Learning Log for the full text)

1. **APPEND-ONLY, on both surfaces.** Never edit / rewrite / reorder / summarise / delete an existing entry — in `ai-docs/learnings.md` or in any `ai-docs/learnings/*.md`, committed or not. "I haven't committed it yet" is NOT a licence to repair a bad entry in place; that is the exact moment the temptation peaks (you have just written the defective line), and a wrong `Kind:` in particular can only ever be fixed by appending. A newer correction that supersedes an older one is a NEW entry that says so; leave the old one intact. (Only `Escalated?` / `Superseded by:` may be updated in-place, and only by the `self-improve` / `learnings-escalation-audit` subagents.)
2. **No same-turn escalation.** Writing a Learning Log entry — to `ai-docs/learnings/<username>-<branch>.md` or to `ai-docs/learnings.md` — MUST NOT also edit `AGENTS.md`, `CLAUDE.md`, `${CLAUDE_PLUGIN_ROOT}/skills/**`, `${CLAUDE_PLUGIN_ROOT}/agents/**`, `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`, or `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` in the same turn. Set `Escalated? no` and stop. (Exception: in-flow capture during `/task` Steps 8–12 may append a NEW entry alongside an instruction-file edit when it documents an in-task insight, `Escalated? no`.)
3. **Write on ANY instruction violation** — no "obvious / minor / trivial / duplicate" skip. The history (incl. recurrences) is the artefact `/improve` audits.
4. **Anchor the append at EOF, on UNIQUE text.** `**Kind:** correction` and `**Escalated?** no` are NOT anchors — they repeat in nearly every entry, so a patch keyed on one lands in the MIDDLE of the log. Read the tail of the TARGET file first (`tail -20 ai-docs/learnings/<username>-<branch>.md`) and anchor on the complete FINAL entry — its `### YYYY-MM-DD — …` header together with its last field line — then confirm with `tail -5` that the new entry is last. The branch's first entry has no tail to anchor on: create the file with that entry as its entire content. A misplaced entry stays where it landed: Boundary rule 1 forbids moving it. **A PostToolUse hook (`${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`) now flags this after the fact** — it compares the line of the `### ` heading your edit added against the file's last heading and prints a warning to stderr when they differ. It is advisory (exit 0) and fires only AFTER the write, so it is a safety net, not a substitute for anchoring correctly.

## When to run `/improve`

≥3 unescalated `correction` entries, OR ≥2 unescalated `validation` entries, OR a `🌱 Stale-validation` flag from `/ai-audit`.
