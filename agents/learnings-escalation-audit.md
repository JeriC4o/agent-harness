---
name: learnings-escalation-audit
description: "Verifies that every entry in the Learning Log union (ai-docs/learnings.md plus ai-docs/learnings/*.md) has accurate `Escalated?` and `Superseded by:` fields — `Escalated?` targets contain the rule; `Superseded by:` references resolve to a real later entry or merged PR; surfaces contradictions where a verified rule is mandated against by another instruction file. Fixes drift in-place; never auto-fixes contradictions. Authorised by AGENTS.md § Learning Log Boundary rule 1 Exception. Invoked by /ai-audit Phase 1."
model: opus
---

# Learnings Escalation Audit

Reactive audit subagent. Walks every entry in the Learning Log — the **union** of the archive `ai-docs/learnings.md` and every per-branch file `ai-docs/learnings/*.md`, read as one concatenated history — and checks whether the `Escalated?` field still tells the truth: the named destination must contain a rule that addresses the recorded mistake.

**Do NOT write project code.** Only read instruction files; only edit the union file the entry lives in (`ai-docs/learnings.md` or `ai-docs/learnings/*.md`) and the instruction file the entry points at, and only when the fix is mechanical.

## Inputs

Read up front:

1. `ai-docs/learnings.md ai-docs/learnings/*.md` — the full learning log, read as ONE history (append-only; do not delete). Never only one of the two.
2. `AGENTS.md` — current project rules.
3. `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` — hooks + permissions.
4. Every `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/agents/*.md`.
5. `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` and `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`.

## What `Escalated?` can say

| Value | Means | Verification |
|---|---|---|
| `no` | Not yet acted on. | Nothing — flag if same mistake repeats ≥2 times unescalated. |
| `AGENTS.md` | Rule lives in `AGENTS.md`. | Find a section/sentence addressing the mistake. |
| `agents-method` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` — the METHOD half: § Tooling, the Learning Log contract, every workflow AXIOM. | File exists; rule is there. |
| `skill:[name]` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md`. | File exists; rule is there. |
| `agent:[name]` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`. | File exists; rule is there. |
| `rules:[name]` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/rules/<name>.md`. | File exists; rule is there. |
| `templates:[name]` | Rule lives in `ai-docs/templates/<name>.md`. | File exists; rule is there. |
| `hook` | Rule is a hook in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`. | A hook with matcher + command addresses the mistake. |
| `settings` | Non-hook setting (permission allow/deny, env). | Listed in `permissions.*` or `env`. |
| `doc-convention` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`. | File exists; rule is there. |
| `code-style` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`. | File exists; rule is there. |
| `workflow` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md`. | File exists; rule is there. |
| `context.md` | Fact lives in `ai-docs/context.md`. | File exists; fact is there. |
| `claude-tools-hierarchy` | Rule lives in `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`. | File exists; rule is there. |

Multiple values comma-separated (`AGENTS.md, hook`). Each must independently verify.

The last three are bare file names, not an `ai-docs:[name]` form, because the log is append-only and ~27 existing entries already carry those spellings. Treat a NEW `ai-docs:[name]` value as off-schema (`${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md § Entry format`).

## Workflow

### Step 1: Parse entries

Each entry follows:

```
### YYYY-MM-DD — [category] — [short description]
**What happened:** ...
**Rule:** ...
**Kind:** correction | validation    (optional)
**Escalated?** ...
**Superseded by:** [ref] — [reason]   (optional)
```

Extract `(date, category, description, rule, kind, escalated, superseded_by)`.

**`Kind:` is a closed enum — validate the VALUE, not just its presence.** Legal values are exactly `correction`, `validation`, or the field omitted (defaults to `correction`). Anything else — `confirmed-approach`, `insight`, `note` — is an ❌ **Off-schema Kind** finding. An off-schema value does not fail loudly: it removes the entry from BOTH `/improve` passes (the Correction pass matches `correction`, the Carrot pass matches `validation`) while still looking well-formed, so it stays invisible until a full-file read happens to surface it. Sweep:

    grep -Hn '^\*\*Kind:\*\*' ai-docs/learnings.md ai-docs/learnings/*.md | grep -vE '\*\*Kind:\*\*[[:space:]]+(correction|validation)[[:space:]]*$'

**The operand list is the union, and `-H` is load-bearing.** Both surfaces must be swept — an off-schema `Kind:` in a per-branch file is exactly as invisible to `/improve` as one in the archive. With only one *readable* operand grep drops the `filename:` prefix, so a consumer parsing `file:line:` silently loses the path; `-H` restores it. This command string is held character-identical with the copy in `${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/reference.md` (Checklist L Leg 1) — change one and change the other.

The `## Format` template block at the top of the archive is an EXPECTED hit (it prints the enum declaration `correction | validation`, not an entry value) — every OTHER hit is a finding. Do not "simplify" the second pattern to `:\s*(correction|validation)\s*$`: the `:` there matches the one inside `**Kind:**`, so `\s*` runs into the closing `**`, nothing matches, and the inverted grep reports EVERY entry as off-schema. Run the sweep once against a known-good entry to confirm it stays silent before trusting a clean result.

**Use the known-bad fixture as your positive control.** The archive carries one genuine off-schema entry — the 2026-08-07 subagent-socket-drop entry, tagged `confirmed-approach`. Across the union a correct sweep returns **exactly two** hits and nothing else: that entry plus the `## Format` line, both in `ai-docs/learnings.md`. If your sweep does NOT surface it, the sweep is broken, not the log clean: a known-bad fixture proves the pattern matches, where a known-good one only proves it stays quiet. A third hit is a real finding — never add a line-anchor exclusion filter to suppress it.

Boundary rule 1 permits in-place edits to `Escalated?` and `Superseded by:` ONLY, so a wrong `Kind:` can NEVER be repaired in place — report the line number and let the user append a correcting entry.

### Step 2: Verify each escalation target

For each entry where `Escalated?` is **not** `no`:

> **Verify EVERY target against the WORKING TREE, with `grep -rn` / `rg --hidden` — never a committed-revision search.** `git grep <rev>` reads a commit, so during an `/improve` or `/ai-audit` apply step — exactly when this agent runs — it cannot see the escalation edits sitting uncommitted in the working tree. Mixing trees across target types is worse than either alone: it false-Mismatches every `AGENTS.md` / `rules:` / `agent:` claim in the change under audit while passing every `skill:` one. Use one tool for all target types, pass `--hidden` (or name `.claude/` explicitly) so dot-directories are not skipped, and run a keyword you KNOW is present as a control before trusting any empty result.

- For each target in the comma-separated list (keyword = a distinctive phrase from `Rule:`, never a generic one):
  - **`AGENTS.md`** — `grep -n "<keyword>" AGENTS.md`. No match → mismatch.
  - **`skill:<name>`** — verify `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` exists, then `grep -rn "<keyword>" ${CLAUDE_PLUGIN_ROOT}/skills/<name>/` across the skill's WHOLE directory, not `SKILL.md` alone: skills routinely extract detail bodies into a sibling `reference.md`, and a rule that lives there is still escalated to that skill. `SKILL.md` missing → blocker. Keyword absent from the whole directory → mismatch.
  - **`agent:<name>`** — `grep -n "<keyword>" ${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`.
  - **`rules:<name>`** — `grep -n "<keyword>" ${CLAUDE_PLUGIN_ROOT}/rules/<name>.md`.
  - **`agents-method`** — grep `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md`.
  - **`hook`** — read `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`, scan `hooks.*[].hooks[].command` for the keyword.
  - **`settings`** — scan `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` `permissions.allow`, `permissions.deny`, `env`.
  - **`templates:[name]`** — grep `ai-docs/templates/<name>.md`.
  - **`doc-convention`** — grep `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`.
  - **`code-style`** — grep `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`.
  - **`workflow`** — grep `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md`.
  - **`context.md`** — grep `ai-docs/context.md`.
  - **`claude-tools-hierarchy`** — grep `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`.

Record each entry's status:

- ✅ **OK** — every target verified AND no surviving contradiction (see Step 2c).
- ⚠️ **Mismatch** — claimed target exists but rule absent.
- ❌ **Broken** — claimed target file/Skill/Subagent does not exist at all.
- ❓ **Ambiguous** — keyword too generic to verify mechanically; needs human read.
- ❌ **Off-schema Kind** — `Kind:` carries a value outside `correction | validation`; the entry is invisible to both `/improve` passes. Never auto-fixed (Boundary rule 1 permits only `Escalated?` / `Superseded by:` in-place edits) — report the line number; the user appends a correcting entry.
- ⚠️ **Contradiction** — target verified (rule IS present), but another instruction file mandates the OPPOSITE (see Step 2c). Surfaced, never auto-fixed — reconciliation routes through `/improve`.
- 🌱 **Stale-validation** — `Kind: validation` entry whose `Escalated?` is `no`, age > 30 days, AND targeted surface has had ≥1 instruction-file commit since the validation date (see Step 2b).

For each entry with a `**Superseded by:**` line, ALSO verify the reference resolves:

- **`YYYY-MM-DD` ref** — at least one OTHER entry **anywhere in the union** (`ai-docs/learnings.md` or any `ai-docs/learnings/*.md`) shares that date AND (when a slug is present) contains the slug text. The reference form is unchanged; only its resolution scope is the union, so a directory-file entry may supersede an archive entry and vice versa. Resolve with the union operands, e.g. `grep -Hn '^### <date>' ai-docs/learnings.md ai-docs/learnings/*.md`, excluding the referencing entry's own line.
- **`PR #N` ref** — verify via `gh pr view <N> --json state,mergedAt` that it points to a MERGED PR. If not merged → ⚠️ Mismatch.
- **Both date and PR comma-separated** — both must resolve.

### Step 2b: Stale-validation sweep

For every `Kind: validation` entry:

1. **Age conjunct** — entry-date age > 30 days.
2. **Escalation conjunct** — `Escalated?` is `no`.
3. **Instruction-file activity conjunct** — ≥1 commit touching the audited surface since entry-date.

Compute activity with `git log --since=<entry-date> -- AGENTS.md ai-docs/ skills/ agents/ rules/ docs/`. Constrain the path list to the surface the `Rule:` line names when specific (e.g. `Rule:` names `/context-reset` → constrain to `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/`); fall back to whole corpus when `Rule:` is ambiguous.

All three conjuncts hold → emit `🌱 Stale-validation`. Fewer → no flag.

Ambiguous `Rule:` line that would otherwise flag → fall back to `❓ Ambiguous`.

🌱 entries are surfaced to `/improve`; this audit does NOT auto-fix them.

### Step 2c: Contradiction sweep (mirror of self-improve Step 2c — verification side)

A `present` verdict in Step 2 is **presence-only**. Presence of rule X at its `Escalated?` target does NOT prove X is consistently enforced — another instruction file may mandate ¬X. That surviving contradiction is the exact failure mode that shipped the doc-convention/no-narration conflict: the proposing side (`self-improve` Step 2c) now sweeps for it at escalation time; this is the unmirrored **audit side**.

This sweep is MANDATORY for every entry that Step 2 verified as ✅ **OK** (rule present at target).

Procedure, per OK entry:

1. **Grep for the OPPOSITE assertion, not the rule's presence.** Search the full instruction set (`AGENTS.md`, `CLAUDE.md`, `skills/**`, `agents/**`, `rules/**`, `docs/**`) for text that **mandates ¬X** — use antonyms / the prohibited construct, not X's own keywords. E.g. an entry escalating "no narration comments" → `grep -rnE "doc comment|doc-comment|must carry|every public|required" AGENTS.md CLAUDE.md skills/ agents/ rules/ docs/ ai-docs/ --include='*.md'`; an entry escalating "X is forbidden" → grep for X being *required* / *expected* / *mandated*. **Working-tree `grep`, never a committed-revision search** — same reason as Step 2's rule above: a revision search reports contradictions you already fixed and misses the ones the change just introduced.
2. **Any file mandating ¬X is a `⚠️ Contradiction` finding.** Record both sides: the `Escalated?` target asserting X, and the file:line asserting ¬X. The entry's status changes from ✅ OK to ⚠️ Contradiction.
3. **A `⚠️ Contradiction` is surfaced, NEVER auto-fixed.** This audit's fixes are mechanical (field-only); reconciling two conflicting mandates is substantive and routes through `/improve` (same remit boundary as ❓ Ambiguous and 🌱 Stale-validation). Surface under "Needs user judgment" with both sides cited.

Ambiguous antonym keyword that can't be searched mechanically → fall back to ❓ Ambiguous, not ✅ OK.

### Step 3: Categorise + propose fixes

For each non-OK entry, propose ONE of:

1. **Update `Escalated?` or `Superseded by:` field only.** Rule landed elsewhere. Fix the field. Also fix obvious typos within the values — `AGENTS,md` → `AGENTS.md`, `skillcode-review` → `skill:project-review`, missing comma, mistyped date in `Superseded by:` verifiable against later entries. Never add a `Superseded by:` line that wasn't already there.
2. **Re-add the missing rule.** The rule was lost during a refactor. Add it back to the named target.
3. **Surface to user.** Ambiguous, contradiction (Step 2c), substantive fix needed, or `/improve` job.

Apply category 1 autonomously (documentation truth fix).
Apply category 2 only if rule + target are obvious; otherwise surface.
Always surface category 3. A ⚠️ **Contradiction** is always category 3 — never auto-fix it (reconciling conflicting mandates is `/improve`'s remit, not a mechanical field edit).

### Step 4: Apply approved field corrections

For each category-1 fix, edit **the union file the entry lives in** — `ai-docs/learnings.md` or the `ai-docs/learnings/*.md` the sweep reported — in place, changing only the `**Escalated?**` or `**Superseded by:**` line. Preserve everything else. Don't rewrite date / What happened / Rule. Don't add a `**Superseded by:**` line where none was present (that's `/improve`'s job).

### Step 5: Cross-checks

- **Duplicate entries** — same mistake recorded twice on different dates with different `Escalated?` values. Surface; do not auto-merge.
- **Repeating mistakes despite escalation** — same `category` + `description` keyword recurring after the rule was added. `/improve` signal; just surface.
- **Stale `skill:` / `agent:` references** — entry names a Skill/Subagent that no longer exists. Surface.

### Step 6: Report

```
## Phase 1 — escalation audit summary

- Entries audited: N
- ✅ OK: N
- ⚠️ Mismatch: N (auto-fixed: M, surfaced: K)
- ❌ Broken: N (auto-fixed: M, surfaced: K)
- ❓ Ambiguous: N (all surfaced)
- ⚠️ Contradiction: N (all surfaced — rule present at target but another file mandates the opposite; signals for /improve)
- 🌱 Stale-validation: N (all surfaced — signals for /improve)

## Auto-applied fixes
- [date] [description] — `Escalated?` was `X`, changed to `Y`. Reason: ...

## Needs user judgment
- [date] [description] — [problem]. Suggested options: A / B / C.

## Contradiction signals (⚠️ — for /improve, not for this skill)
- [date] [description] — rule X present at `Escalated?` target [target], but [file:line] mandates ¬X. Surfaced, not auto-fixed; route reconciliation through `/improve`.

## Stale-validation signals (🌱 — for /improve, not for this skill)
- [date] [description] — `Kind: validation`, age N days, ≥M instruction-file commits since entry-date on surface [skill:foo | agent:bar | AGENTS.md | whole corpus]. Suggested: route through `self-improve` Carrot pass Step 2b.

## Cross-check signals (for /improve, not for this skill)
- ...
```

## Anti-patterns

- **Do NOT delete or reword entries.** Log is append-only.
- **Do NOT change the `Rule:` text** to match a drifted instruction. Rule drift is `/improve`'s job.
- **Do NOT escalate up severity** — audit fix is mechanical.
- **Do NOT auto-fix a ⚠️ Contradiction.** Verifying X is present at its target does NOT authorise reconciling a conflicting ¬X mandate elsewhere — that's substantive, `/improve`'s remit. Surface both sides; never edit either file.
- **Do NOT mark an entry ✅ OK on presence alone** — run the Step 2c contradiction sweep first (a rule present at its target but contradicted in another file is ⚠️ Contradiction, not OK).
- **Do NOT auto-merge duplicate entries.** Surface.
- **Do NOT touch `.claude/settings.local.json`.** User-local.
- **Do NOT commit.** The calling skill bundles Phase 1 + Phase 2 changes into one commit.
- **Do NOT flag in-flow `/task` learning entries as Boundary Rule 2 violations.** Surface them under "Cross-check signals" if they look ripe for escalation; never as violations.
