# `/ai-audit` reference

Static reference content extracted from `SKILL.md`. Loaded on demand when `/ai-audit` Phase 2 Step 2.3 hits a specific checklist letter, or when Step 2.6 needs to re-verify cross-references anchor-aware.

## Checklist A — Cross-reference integrity

- Every relative link (`../`, `./`, file references in prose) resolves to an existing file.
- Every `[text](file.md)` and bare `file.md` mentioned in instructions points to a file that exists.
- Every Skill or Subagent named in another Skill/Subagent (e.g., `project-review` references `review-findings`, `self-review`) actually has a matching file.

## Checklist B — Conflicting / duplicated rules

- The same topic must not have contradictory guidance in two places (e.g., commit policy in AGENTS.md vs. in a skill).
- Verbatim-duplicated rules across files → consolidate to one canonical home + reference.
- Rule says "see `<other-file>`" — confirm the target file actually contains that rule.

## Checklist C — Dead references

- Skills/agents named in `AGENTS.md` Propagation Rule sync-group rows must exist.
- Agent names referenced in skills must match a file under `.claude/agents/`.
- `ai-docs/plans/done/` references in Subagent checklists must still resolve.

## Checklist D — Frontmatter conformance (skills)

Per the official Claude Code docs:

- Every `SKILL.md` has YAML frontmatter with at minimum `name` and `description`.
- `description` should make trigger conditions clear (when to invoke).
- `disable-model-invocation: true` ↔ skill is user-only — verify intent matches.
- `argument-hint` style is consistent across skills.
- `allowed-tools` syntax matches `ToolName(pattern)` form documented at `code.claude.com/docs/en/skills`.

## Checklist E — Frontmatter conformance (agents)

- Every `.claude/agents/*.md` starts with YAML frontmatter (`---`-delimited block at top of file). A file in `.claude/agents/` without frontmatter is not a Subagent — it's a stray document.
- `name` field equals the file basename.
- `description` is one line and tells the orchestrator when to spawn this Subagent.

## Checklist F — Hooks (`.claude/settings.json`)

- Each hook event name is one of the documented set (`SessionStart`, `PreToolUse`, `PostToolUse`, etc. — confirm against `hooks-guide`).
- Matchers are valid tool name patterns.
- Hook commands fail closed (`exit 2` for blocking) where intended; non-blocking informational hooks use stderr without `exit 2`.
- Timeouts are reasonable (≤30s default, longer only when the work demands it).
- Commands quote `$CLAUDE_PROJECT_DIR` and other env vars correctly — no shell injection footguns.

## Checklist G — AGENTS.md "Propagation Rule" coherence

- Every "sync group" listed in AGENTS.md still has all listed members present and cross-referenced.
- Behaviors described in AGENTS.md and replicated in Subagent checklists agree (e.g., file-size hard/soft limits in `review-findings.md` match AGENTS.md / `ai-docs/code-style.md`).
- Exemptions in AGENTS.md (e.g., trait-impl doc-convention exemption, Java carve-out) appear in every enforcement file.

## Checklist H — Documentation conformance pointers

- `ai-docs/doc-convention.md` is referenced by `review-findings.md` and `self-review.md`. Confirm relative paths resolve.
- The canonical section order listed in `doc-convention.md` matches references in `self-review.md` Checklist 6 and `review-findings.md` Checklist 6.

## Checklist I — File-size & structure (instruction files)

- No `SKILL.md` or Subagent file exceeds ~500 lines without clear sectioning. Long files should split into a thin `SKILL.md` + reference file (`task`, `ai-audit`, `bugfix`, `interview` use this pattern).
- Each skill directory contains exactly one `SKILL.md` (plus optional reference / scripts subdirectories).
- AGENTS.md AXIOM: every file in the audited corpus stays under 40,000 chars; 35,000–39,999 is a `minor` warning band.

## Checklist J — Allow-list / permission consistency

- Tools used in skills' `allowed-tools` should be present (or coverable by) the `permissions.allow` list in `settings.json` — otherwise the user gets a prompt every time.
- Conversely: any allow-listed pattern that no skill actually uses is dead and should be reviewed.

## Checklist K — Skill-directory layout (SKILL.md + supporting files + scripts/)

A skill directory may contain SKILL.md plus supporting files. Audit checks:

1. **Oversized SKILL.md — exemption check + drift detection.** Two additive findings fire from the same pass; both severity `minor`. Source of truth: `ai-docs/skill-size-exemptions.md`.

   - (a) **Parse the index.** Read `ai-docs/skill-size-exemptions.md` and extract, for each row in the exemption table, the SKILL path and the cited `wc -l at audit time` numeric value.
   - (b) **Oversized + no exemption.** Run `wc -l .claude/skills/*/SKILL.md` against the live tree. For each file > 200 lines whose path is NOT in the parsed index, emit a `minor` finding: scan for *reference content* sections (format specs, parser rules, lookup tables, long checklists, embedded templates) — material referenced once or twice but loaded into context on every invocation — and propose extraction to a supporting file OR addition of an exemption entry.
   - (c) **Drift detection.** For each SKILL path listed in the index, compare cited `wc -l` against live `wc -l`. Mismatch → `minor` finding: `` `<path>`: index cites X lines, live is Y lines ``.

2. **Multi-consumer supporting files belong in `ai-docs/templates/`.** When a supporting file is referenced from > 1 Skill or Subagent, propose moving it from the owning Skill's directory to `ai-docs/templates/<file>.md`. Severity `minor`.

3. **Inline-script extraction candidates.** Identify `SKILL.md` sections containing self-contained `bash` blocks — a complete, executable recipe with at most one or two `<placeholder>` substitutions, NOT orchestration guidance the Subagent reconstructs dynamically per call. For each, propose extraction to `.claude/skills/<skill>/scripts/<descriptive-name>.sh`, invoked via the **repo-relative** path `.claude/skills/<skill>/scripts/<name>.sh <args>` (NOT `${CLAUDE_SKILL_DIR}/...` — that variable is expanded in the SKILL body to an absolute path but NOT in `allowed-tools` patterns, so an absolute invocation never matches a repo-relative allow-rule and prompts every call). After extraction, narrow `allowed-tools` to the matching literal `Bash(.claude/skills/<skill>/scripts/<name>.sh *)` (space-` *` form — the canonical tool-generated wildcard; `:*` is an accepted equivalent) — the pattern prefix and the body invocation MUST be the byte-identical repo-relative string (Bash permission matching is literal string-prefix, no path normalization). Severity `minor`. **Published/community-skill exception:** the repo-relative-path rule above is for CHECKED-IN `.claude/skills/` skills only. A PUBLISHED / portable community skill (installed at a variable location — personal/project/plugin, e.g. symlinked into `~/.claude/skills/` from `ai/artifacts/skills/community/`) is the inverse — its BODY invocation MUST use `${CLAUDE_SKILL_DIR}/scripts/<name>` so the path resolves regardless of install location, while `allowed-tools` keeps the relative `Bash(scripts/<name>:*)` (the var is not substituted in `allowed-tools`); accepted tradeoff — those body calls prompt per-use, portability wins for a published artifact.

   **Counter-rule.** Bash snippets that are orchestration guidance — every call has different placeholder values that the Subagent constructs — are NOT script-extraction candidates. Skip those.

## Checklist L — Learning-Log field coherence

When AGENTS.md § Learning Log's *Entry format* lists a field maintained by `/improve` and `/ai-audit` (currently `Escalated?` and `Superseded by:`), verify each field is covered in **all five** mandatory locations:

| Location | Required content |
|---|---|
| AGENTS.md *Boundary rule 1 Exception* | Explicit authorization to edit the field in-place, on **both** Learning Log surfaces (`ai-docs/learnings.md` and `ai-docs/learnings/*.md`) |
| AGENTS.md *Boundary rule 2 Exception* | Explicit authorization for the field's edits to coexist with instruction-file edits in the same `/improve` / `/ai-audit` turn |
| `.claude/agents/self-improve.md` Step 5 (Commit B backfill) | Workflow describing when and how `/improve` writes the field |
| `.claude/agents/learnings-escalation-audit.md` Steps 2/3/4 | Verification recipe + Category-1 drift fixes, applied to whichever union file the entry lives in |
| `ai-docs/templates/learnings-entry-format.md` *Entry template* | Field mirror — AGENTS.md § Learning Log designates this the DEFAULT read for the entry shape, so a field missing here is invisible to every writer |

A field added to the entry format without parallel coverage in all five targets → `major` finding.

**Declared-schema fields (no `/improve`-time mutation).** Some fields (currently: `Kind:`) are *declared* and *parsed* but **never** mutated. For each such field verify BOTH legs — a declared enum whose values are never checked is not enforced.

**Leg 1 — value conformance across every entry in the union (`ai-docs/learnings.md` + `ai-docs/learnings/*.md`):** `grep -Hn '^\*\*Kind:\*\*' ai-docs/learnings.md ai-docs/learnings/*.md | grep -vE '\*\*Kind:\*\*[[:space:]]+(correction|validation)[[:space:]]*$'`. Both operands and the `-H` are load-bearing: an off-schema `Kind:` in a per-branch file is exactly as invisible to `/improve` as one in the archive, and with a single readable operand grep drops the `filename:` prefix. This command string is held character-identical with the copy in `.claude/agents/learnings-escalation-audit.md` Step 1 — change one and change the other. The `## Format` template block at the top of the archive is an EXPECTED hit (enum declaration, not an entry value); every OTHER hit is `major` — it removes the entry from both `/improve` passes while looking well-formed. Report the line number only — Boundary rule 1 forbids fixing `Kind:` in place. **Falsify the sweep before trusting a clean result:** the shorter `:\s*(correction|validation)\s*$` form is broken (its `:` binds inside `**Kind:**`, so nothing matches and the inverted grep flags every entry) — run it once against a known-good entry and confirm silence.

**Leg 2 — documentation coverage in:**

| Location | Required content |
|---|---|
| AGENTS.md `## Learning Log` *Entry format* | Declaration of field name, allowed values, default-when-omitted semantics |
| `.claude/agents/self-improve.md` Step 5 | Mention where the workflow branches on its value |
| `.claude/agents/learnings-escalation-audit.md` Steps 2/3/4 | Parse-site usage (verdict routing, sweep predicates) |
| `ai-docs/corrections-log.md` field glossary | Declaration mirror — same allowed-values list, same default-when-omitted note |

## Checklist M — `agent-writing-style.md` conformance

`ai-docs/agent-writing-style.md` is the canonical style reference for fail-loud rules in instruction files. Checklist M sweeps the audited corpus for drift against the Patterns + Anti-patterns. **Audited corpus**: `AGENTS.md` + every `.claude/skills/**/SKILL.md` + every `.claude/agents/**.md` + `ai-docs/code-style.md` + `ai-docs/doc-convention.md` + `ai-docs/agent-writing-style.md` + `ai-docs/corrections-log.md` + `.claude/rules/**/*.md`.

| # | Sub-check | Severity |
|---|---|---|
| 1 | **Pattern 1 (binary rules)** — IF/THEN tables or AXIOM blockquotes; every `> **AXIOM —` block must be followed by an action table within the same blockquote. | `major` |
| 2 | **Pattern 2 (fail-loud AXIOM)** — stick rules use stick verbs (*MUST* / *NEVER* / *MUST NOT* / *FORBIDDEN*); carrot rules use carrot verbs (*Default to* / *Prefer*). | `minor` |
| 3 | **Pattern 3 (action-table column)** — right column of every `\| If you see... \| Action \|` table starts with an action verb (imperative form). | `minor` |
| 4 | **Pattern 4 (explicit file lists)** — fail-loud lists that enumerate files spell out each path; no glob-as-entire-list. | `major` |
| 5 | **Pattern 5 (lock-step verbs)** — verb shape matches rule shape. Stick verbs on carrot rules / carrot verbs on stick rules → `major`. |
| 6 | **Pattern 6 (link, don't duplicate)** — cross-surface duplicate rule with `[link]` to canonical sibling. | `minor` |
| 7 | **Pattern 7 (extract verbose detail)** — body > 5KB and no extraction anchor in `ai-docs/` → `nit`. |
| 8 | **Pattern 8 (file-size cap)** — every covered instruction file < 40,000 chars; 35,000–39,999 is `minor`. | see body |
| 9 | **Anti-patterns table audit** — no row of the Anti-patterns table appears verbatim as a positive rule. | `major` |
| 10 | **Cross-shape verbs** — carrot blocks must NOT use stick verbs; stick blocks must NOT use carrot verbs. | `major` |
| 11 | **Compaction-recovery callout consistency** — role-aware presence of the locked invariant tiers across the 7 callout-carrying skills (see detail note below). | `major` |

### Sub-check 11 — compaction-recovery callout consistency

Keys on **role-aware invariant tiers** — NOT byte-equality. The 5 callout-carrying skills are `task`, `project-review`, `bugfix`, `interview`, `context-reset`. Two tiers:

| Tier | Scope | Invariant that MUST be present |
|---|---|---|
| **Tier 1** | all 7 callout-carrying skills | the opening line `> **⚡ Compaction recovery check — read FIRST on every invocation.**` |
| **Tier 2** | the 4 **consumer** skills only (`task`, `project-review`, `bugfix`, `interview`) — `context-reset` is **EXEMPT** as the rationale carrier | the cross-link substring `.claude/skills/context-reset/SKILL.md § Compaction recovery (re-entry)` |

A missing Tier-1 or Tier-2 invariant, or an invented variant of either, is `major`.

**NOT keyed — documented acceptable variance.** Three phrases vary by role and are NOT keyed: `STOP before any tool call`; `top-to-bottom in one pass`; `Re-enter this skill from the top of its body`. Keying them would false-positive on `context-reset` (carrier variant).

**Refinement note (vs the spec).** The spec Key-decisions row lists 5 phrases as "invariant", but live audit found only the opening line (all 7) + the cross-link (6 consumers) are truly universal — the other 3 are acceptable variance, not keyed.

**False-positive guard.** The sub-check MUST produce ZERO findings against `context-reset` (a correct-by-design carrier variant).

### Sub-check 8 — file-size AXIOM conformance

Detection mechanism:

```bash
wc -c AGENTS.md CLAUDE.md .claude/skills/**/*.md .claude/agents/*.md \
      .claude/rules/**/*.md \
      ai-docs/code-style.md ai-docs/doc-convention.md ai-docs/context.md \
      ai-docs/agent-writing-style.md ai-docs/corrections-log.md \
      ai-docs/workflow.md ai-docs/claude-tools-hierarchy.md
```

| Reported size (chars) | Finding | Severity |
|---|---|---|
| `< 35,000` | none | — |
| `35,000–39,999` | `<path>: <count> chars — early warning (≥ 35,000)` | `minor` (**actionable** — present extraction plan in same pass) |
| `≥ 40,000` | `<path>: <count> chars — AXIOM violation (≥ 40,000)` | `major` |

The 35,000–39,999 band is actionable, NOT a passive heads-up. Recurring misclassification: large instruction files (e.g. AGENTS.md around 36k chars) get tagged "Heads-up surfaced — no fix this pass" and extraction is deferred. When the band fires, propose a concrete extraction plan in the same `/ai-audit` pass — list candidate verbose subsections + target `ai-docs/<topic>.md` paths + the anchored pointers to leave behind — and ask the user to approve via the SKILL.md Step 2.5 `minor` rule. The point of the band (separate from the 40k hard cap) is to give one full `/task` cycle of headroom; deferring to "next `/ai-audit`" wastes that headroom.

## Checklist N — Bidirectional `## Patterns` ↔ `Kind: validation` coherence

The carrot-side analog of Checklist C. Every promoted-from-validation carrot must round-trip in both directions:

**Forward direction.** Every `### N. <Name>` entry under a `## Patterns` section in the audited corpus whose **body uses carrot verbs** (`Default to` / `Prefer`) MUST back-link to at least one `Kind: validation` entry in the union — `ai-docs/learnings.md` or any `ai-docs/learnings/*.md`. Detection: for each `### N. <Name>` block, grep its body for `Default to` or `Prefer`; if found, also grep for a Learning Log back-link (either surface's path + a date-slug citation) within the same block.

**Forward-sweep carrier-vs-template exemption.** Entries WITHOUT carrot verbs are out of scope. Named exempt source: `ai-docs/agent-writing-style.md § Patterns` (template source, not a promoted-from-validation carrier).

**Reverse direction.** Every `Kind: validation` entry in the union (`ai-docs/learnings.md` + `ai-docs/learnings/*.md`) whose `Escalated?` ≠ `no` MUST have a corresponding `## Patterns` block in each named target file. Multi-target: the `Escalated?` field may name multiple comma-separated targets; the reverse sweep iterates each independently — a validation entry escalated to two targets must have a `## Patterns` block in BOTH files.

| Direction | Trigger | Action |
|---|---|---|
| Forward | `### N. <Name>` block in `## Patterns` uses carrot verb AND no Learning Log back-link (`ai-docs/learnings.md` or `ai-docs/learnings/*.md`) in the same block | flag (`major`) |
| Forward (exemption) | `### N. <Name>` block has no carrot verb in its body | no flag |
| Forward (named exempt source) | The audited file is `ai-docs/agent-writing-style.md` | no flag |
| Reverse | `Kind: validation` entry with `Escalated? ≠ no` AND named target file lacks `## Patterns` block OR back-linking entry | flag (`major`) |
| Reverse (predicate gate) | `Kind: validation` entry with `Escalated? no` | no flag |

## Checklist O — Embedded-name clash scan

Enforces the AGENTS.md `## Propagation Rule` clash-rename AXIOM. Project-defined Tool / Subagent / Skill / Hook names MUST NOT clash with embedded names enumerated in `ai-docs/claude-tools-hierarchy.md` §§1a/1b/2a/3a/3b. Any match → `major` finding (project side renames; the embedded name is never renamed).

**Recipe.** Enumerate two sorted lists and intersect them; empty intersection passes.

1. **Project names** — collect every name the project DEFINES:
   - Subagent names: `awk 'FNR==1{f=0} /^---$/{f=!f; next} f && /^name:/{print $2}' .claude/agents/*.md`
   - Skill names: `awk 'FNR==1{f=0} /^---$/{f=!f; next} f && /^name:/{print $2}' .claude/skills/*/SKILL.md`
   - Hook event names: `jq -r '.hooks | keys[]' .claude/settings.json`
   - Sort + dedupe → `project-names.txt`.
2. **Embedded names** — extract names from the FIRST column of `ai-docs/claude-tools-hierarchy.md` §§1a + 1b + 2a + 3a + 3b table rows. Namespaced names count as ONE token; do NOT split on `:`.
3. **Intersection** — `comm -12 <(sort -u project-names.txt) <(sort -u embedded-names.txt)` MUST return empty.

| Trigger | Action |
|---|---|
| `comm -12` output is empty | no flag — clash-scan baseline holds |
| `comm -12` output is non-empty | `major` finding per name: "Project-defined `<name>` clashes with embedded `<name>` enumerated at `claude-tools-hierarchy.md` §§<sections>. Rename the project side." |

Severity `major` — the clash makes ambiguous which name resolves at dispatch time.

## Checklist P — Frontmatter/config improvement recommendations

Where Checklist D/E verify frontmatter *conformance* (is it well-formed?), Checklist P recommends frontmatter *improvement* (is it minimal-yet-complete?). It is the only checklist that emits **forward-looking** advice rather than compliance findings.

**Schema source.** Reuse the Step 2.1 `claude-code-guide` fetch — do NOT spawn a second `claude-code-guide` Subagent. Diff each `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, and each `.claude/settings.json` hook config against the FULL documented Claude Code field set returned by that fetch.

**Routing.** Findings flow through the existing Step 2.5 `minor` / `nit` approval flow. A field-config that is *actively misleading* (e.g. `disable-model-invocation` asymmetry that lets a user-only skill be model-invoked) is `major`; everything else is `minor` or `nit`.

**The four recommendation verbs.** Per field, per surface, emit exactly one of:

| Verb | When |
|---|---|
| **add** | A documented field is absent AND concretely useful for this surface (see the per-field gates below). |
| **drop** | A field is present but equals its documented default, OR is redundant for this surface. |
| **normalize** | Field value uses an inconsistent style vs siblings (e.g. mixed separators across `allowed-tools` entries). |
| **resolve-asymmetry** | A sibling pair disagrees (one of a pair carries a field the other lacks with no role reason). |

### Minimal-frontmatter philosophy (AC7)

Optimise for the **MINIMAL correct frontmatter**, not maximal field coverage. A fuller frontmatter is NOT a better frontmatter. Minimal valid SUBAGENT frontmatter = `name` + `description` only (`model` / `tools` are optional and default to inherit). Skill frontmatter follows the same convention.

### Do-NOT-fill-spuriously gates (AC4)

Each **add** recommendation is gated on concrete usefulness — never recommend a field just because the schema documents it:

| Field | Recommend **add** only if... |
|---|---|
| `argument-hint` | the skill actually takes arguments. |
| `when_to_use` | the skill is model-invocable (`disable-model-invocation` ≠ `true`). |
| `allowed-tools` | the skill runs gated tools. A pure launcher (e.g. `improve`, which only spawns a Subagent) correctly needs NO `allowed-tools` — do not recommend adding one. |

### Default-valued fields → REMOVAL (AC5)

A field whose value equals its documented default adds nothing → flag for **drop** (REMOVAL). `not-applicable` ("this surface inherits the default intentionally") is a valid per-field verdict that adds nothing and needs no change — record it as such; do NOT recommend adding a field merely to make the verdict explicit.

### `model` / `effort` rule — two-way model-posture taxonomy (AC6)

The model-posture taxonomy is an **auditable two-way rule**. Flag deviations in BOTH directions.

| Surface class | Members | Expected `model:` | Deviation flagged |
|---|---|---|---|
| **Non-code reasoning** (SHOULD pin `model: opus`) | skills: `ai-audit`, `improve`; agents: `design`, `design-review`, `learnings-escalation-audit`, `self-improve`, `spec-writer` | `model: opus` present | omits `model:` → flag |
| **Code-working** (SHOULD inherit — omit `model:`) | skills: `task`, `project-review`, `bugfix`, `interview`, `context-reset`, `pr-merged`; agents: `self-review`, `review-findings` | no `model:` line | pins `model:` → flag |

> **SKILL-honored vs SUBAGENT-may-be-ignored (GH #44385).** A SKILL `model: opus` pin is **reliably honored** by the harness. A SUBAGENT (`.claude/agents/*.md`) `model:` pin **may be ignored** — the agent can inherit the spawner's session model regardless of its frontmatter. So for agents the frontmatter pin is **intent-level** only; reliable opus comes from the opus-pinned spawning skill (the agent inherits) OR an explicit `model=` at the `Agent()` spawn site. Checklist P treats an agent's `model: opus` pin as correct-intent and does NOT recommend dropping it, but records that the practical guarantee lives at the spawner.

### Run output — per-surface recommendation table (AC3)

The run output is a per-surface recommendation table — **one row per skill / agent / hook**:

| Surface | Type | Verb | Field | Recommendation | Severity |
|---|---|---|---|---|---|
| `<name>` | skill / agent / hook | add / drop / normalize / resolve-asymmetry / not-applicable | `<field>` | one-line rationale | minor / nit / major |

The table is emitted at audit runtime (Step 2.5 output) — it is NOT stored in the repo.

## Step 2.6 sub-step 4 — Cross-reference re-verification (anchor-aware)

For every relative link the audit touched, confirm the target file exists AND the anchor (if present) matches a heading slug. Anchor-aware check rather than naive `realpath -m`:

```bash
for f in <changed-files>; do
  grep -oE '\(\.\./[./]*[^)#]+(#[^)]*)?\)' "$f" | sort -u | while read ref; do
    path_with_anchor=$(echo "$ref" | tr -d '()')
    path=${path_with_anchor%%#*}
    anchor=${path_with_anchor#*#}; [ "$anchor" = "$path_with_anchor" ] && anchor=""
    src_dir=$(dirname "$f")
    abs=$(realpath -m "$src_dir/$path")
    [ -e "$abs" ] || { echo "FILE MISSING: $f -> $path"; continue; }
    [ -z "$anchor" ] && continue
    # heading-slug match: lowercase, strip non-alnum-non-hyphen, spaces->hyphens
    awk '/^#{1,6}\s/{line=$0; gsub(/^#+\s+/,"",line); line=tolower(line); gsub(/[^a-z0-9 -]/,"",line); gsub(/ /,"-",line); gsub(/-+/,"-",line); sub(/^-+/,"",line); sub(/-+$/,"",line); print line}' "$abs" | grep -Fx "$anchor" >/dev/null || echo "ANCHOR MISSING: $f -> $path#$anchor"
  done
done
```
