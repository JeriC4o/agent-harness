# Corrections log — field glossary + boundary carve-outs

Companion to `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Learning Log`. Reference, not narrative.

> For the entry SHAPE and for the TARGET FILE a new entry goes to, read [`${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md`](templates/learnings-entry-format.md) (§ Target file — `ai-docs/learnings/<username>-<branch>.md`) — not the tail of the log. This file is the field GLOSSARY (semantics); the template is the quick-reference form.

## Entry format — field glossary

```
### YYYY-MM-DD — [category] — [short description]
**What happened:** ...
**Rule:** ...
**Kind:** correction | validation              # optional; default `correction`
**Escalated?** no | AGENTS.md | agents-method | skill:[name] | hook | settings | agent:[name] | rules:[name] | templates:[name] | doc-convention | code-style | workflow | context.md | claude-tools-hierarchy
**Superseded by:** [ref] — [reason]            # optional; omit when not applicable
```

### `Kind:` semantics

| Value | Meaning | Promotion verbs in escalated rule |
|---|---|---|
| `correction` (default) | The session violated an instruction. Stick signal — log it so the rule can be hardened. | *MUST* / *NEVER* / *MUST NOT* / *FORBIDDEN* |
| `validation` | A non-obvious protocol or pattern worked. Carrot signal — log it so the pattern can be promoted to a `## Patterns` section. | *Default to* / *Prefer* |

Cross-shape (carrot verb on a stick rule, or vice versa) is FORBIDDEN — `/ai-audit` Phase 2 Checklist M flags cross-shape drift at `major`.

### `Escalated?` value set

| Value | Means | Verified against |
|---|---|---|
| `no` | Not yet acted on (no project-level rule). | Nothing — but flag if same mistake repeats ≥2 times. |
| `AGENTS.md` | Rule lives in `AGENTS.md`. | grep for distinctive keyword from `Rule:`. |
| `agents-method` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` — the METHOD half: § Tooling, the Learning Log contract, every workflow AXIOM. | grep finds rule. |
| `skill:[name]` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md`. | File exists; grep finds rule. |
| `agent:[name]` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`. | File exists; grep finds rule. |
| `rules:[name]` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/rules/<name>.md`. | File exists; grep finds rule. |
| `templates:[name]` | Rule lives in `ai-docs/templates/<name>.md`. | File exists; grep finds rule. |
| `hook` | Rule is a hook in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`. | A hook matcher+command references the relevant tool/behavior. |
| `settings` | Non-hook setting (permission allow/deny, env). | Listed in `permissions.*` or `env`. |
| `doc-convention` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`. | grep finds rule. |
| `code-style` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`. | grep finds rule. |
| `workflow` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md`. | grep finds rule. |
| `context.md` | Fact lives in `ai-docs/context.md`. | grep finds fact. |
| `claude-tools-hierarchy` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`. | grep finds rule. |

Multiple values comma-separated (`AGENTS.md, hook`). Each must independently verify.

> **Why the last three are bare file names rather than an `ai-docs:[name]` form.** All three name a page under `ai-docs/`, so a single parametrised value would be tidier — but the log is APPEND-ONLY (Boundary rule 1), so once entries carry a spelling it can never be rewritten. Pick one spelling per target and keep it: two spellings for one target is the drift this row set exists to remove.

### `Superseded by:` format

- `YYYY-MM-DD` — a later entry of the same date, resolved across the whole union: `ai-docs/learnings.md` **and** every `ai-docs/learnings/*.md`, read as one history. The reference form is unchanged — only its resolution scope is the union, so a reference may point from a per-branch file into the archive or the other way round. If multiple entries share the date, append a quoted slug from the entry description for disambiguation.
- `PR #N` — a merged PR that changed the rule. Verified via `gh pr view <N> --json state` — only MERGED state qualifies.
- Both comma-separated.

Written by `self-improve` Subagent (in-place edit of an existing entry) when a later escalation reverses, refines, generalizes, or withdraws the prior rule. Never added by hand — adding the field is `/improve`'s job.

## Boundary rule 1 — append-only

The Learning Log is APPEND-ONLY on BOTH surfaces — `ai-docs/learnings.md` and every `ai-docs/learnings/*.md`. Never edit, rewrite, reorder, summarise, or delete an existing entry. Even when a newer correction supersedes an older one — write a NEW entry that says so; leave the old one intact.

`/improve`'s fold is an AUTHORISED append, not a violation: it appends a folded file's entries verbatim at the archive's EOF and deletes that source file. No entry is edited, reordered or dropped — the entries move between surfaces byte-for-byte. See `ai-docs/learnings/README.md`.

### Exception

`Escalated?` and `Superseded by:` MAY be updated in-place, on either surface, by the `self-improve` Subagent (`/improve`) and the `learnings-escalation-audit` Subagent (`/ai-audit` Phase 1). All other lines remain immutable.

| Subagent | May write | Field rules |
|---|---|---|
| `self-improve` | NEW value on `Escalated?` of escalated entries (Commit B backfill); NEW `Superseded by:` line on a PRIOR entry whose rule the current escalation withdraws | Owned by `/improve` |
| `learnings-escalation-audit` | Drift-corrections to `Escalated?` and `Superseded by:` values (typo fixes, stale target updates) | NEVER add a `Superseded by:` line that wasn't already there |

## Boundary rule 2 — no other rule-file edits in same turn

When you write a Learning Log entry — to `ai-docs/learnings/<username>-<branch>.md`, or to `ai-docs/learnings.md` — you MUST NOT also edit in the same conversation turn: `AGENTS.md`, `CLAUDE.md`, `${CLAUDE_PLUGIN_ROOT}/skills/**`, `${CLAUDE_PLUGIN_ROOT}/agents/**`, `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`, `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`. Writing a learning entry is NOT authorisation to escalate. Set `Escalated? no` and stop.

Project-level escalation happens ONLY when:
1. The user runs `/improve` (spawns `self-improve` Subagent), OR
2. The user explicitly asks ("escalate this", "update AGENTS.md", etc.).

### Exception — `/improve` and `/ai-audit` workflows

`self-improve` (via `/improve`) + `learnings-escalation-audit` (via `/ai-audit` Phase 1) MAY update `Escalated?` / `Superseded by:` on existing entries, on either surface, alongside instruction-file edits. **Existing-entry updates ONLY** — NEW learning entries STILL cannot be appended in the same turn as instruction-file edits.

### Exception — in-flow learning capture during `/task` Steps 8–12

A NEW learning entry MAY be appended to the branch's `ai-docs/learnings/<username>-<branch>.md` in the same turn as an instruction-file edit when ALL hold:
1. Running skill is `/task` Steps 8–12 (inclusive of sub-skills `/bugfix`, `/context-reset` invoked from that range).
2. Entry documents an in-task insight (not pre-emptive escalation).
3. Marked `Escalated? no`.

## FORBIDDEN reasoning for skipping a `learnings.md` write

This binds on **every** Learning Log write — an `ai-docs/learnings/<username>-<branch>.md` entry exactly as much as an archive one. (The heading keeps its original wording deliberately: `AGENTS.md` links to its slug.) These have been used in violation of the "write on ANY instruction violation" rule and are explicitly disallowed as skip-reasons:

- "obvious" / "minor" / "trivial" / "self-evident"
- "already known" / "already documented"
- "duplicate of an earlier entry"
- "would clutter the log"
- "the fix is in the diff anyway"
- "the user already corrected me"

The history (including recurrences and superseded entries) IS the artefact `/improve` audits to decide escalation fan-out. Editing or skipping past entries destroys that history.

## Categories

`code-style` · `process` · `architecture` · `testing` · `documentation` · `tooling` · `search` · `other`
