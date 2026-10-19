# Frontmatter and configuration improvement recommendations

The recipe behind the audit checklist letter that recommends frontmatter *improvement* rather than
verifying frontmatter *conformance*. Extracted from
[`${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/reference.md` § Checklist P](${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/reference.md#checklist-p--frontmatterconfig-improvement-recommendations),
which keeps the letter's heading and a pointer here, so the obligations a run loads stay on that page and
only the recommendations live on this one. This page is pure reference and states no rule about what any
document must contain.

Where Checklist D/E verify frontmatter *conformance* (is it well-formed?), Checklist P recommends frontmatter *improvement* (is it minimal-yet-complete?). It is the only checklist that emits **forward-looking** advice rather than compliance findings.

**Schema source.** Reuse the Step 2.1 `claude-code-guide` fetch — do NOT spawn a second `claude-code-guide` Subagent. Diff each `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/agents/*.md`, and each `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` hook config against the FULL documented Claude Code field set returned by that fetch.

**Routing.** Findings flow through the existing Step 2.5 `minor` / `nit` approval flow. A field-config that is *actively misleading* (e.g. `disable-model-invocation` asymmetry that lets a user-only skill be model-invoked) is `major`; everything else is `minor` or `nit`.

**The six legal values.** Per field, per surface, emit exactly one of them — the set is CLOSED **for per-field rows**, so an outcome some rule mandates for such a row while the set omits it is a defect in this list, never a judgement call at runtime. A finding about THIS LIST rather than about a surface's field is the documented exception and takes no value at all; the exhaustiveness clause under the model-posture rule is the one that does. Four of the six are **recommendation verbs**:

| Verb | When |
|---|---|
| **add** | A documented field is absent AND concretely useful for this surface (see the per-field gates below). |
| **drop** | A field is present but equals its documented default, OR is redundant for this surface. |
| **normalize** | Field value uses an inconsistent style vs siblings (e.g. mixed separators across `allowed-tools` entries). |
| **resolve-asymmetry** | A sibling pair disagrees (one of a pair carries a field the other lacks with no role reason). |

The remaining two are **not** recommendation verbs, which is why the heading above counts values rather than verbs; the Run output table's Value column carries all six:

| Value | When |
|---|---|
| **not-applicable** | This surface inherits the documented default intentionally; nothing to change, and the verdict is recorded rather than acted on. |
| **posture-question** | A rule's flag stands, but the remedy is a decision for the surface's owner and not for the audit — so the row states the question and names the options instead of prescribing one. `drop` is specifically NOT the value here: it would have the audit resolve what it is reporting. |

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
| **Non-code reasoning** (SHOULD pin `model: opus`) | skills: `ai-audit`, `improve`, `improve-global`, `inspect`; agents: `design`, `design-review`, `learnings-escalation-audit`, `self-improve`, `spec-writer`, `fix-scout`, `inspector` | `model: opus` present | omits `model:` → flag |
| **Code-working / script-driven** (SHOULD inherit — omit `model:`) | skills: `task`, `project-review`, `bugfix`, `interview`, `context-reset`, `pr-merged`, `harness-init`, `report-defect`; agents: `self-review`, `review-findings`, `fix-apply` | no `model:` line | pins `model:` → flag |

**The two membership lists are EXHAUSTIVE, and a surface the table does not name is the hole this clause closes.** A two-way rule that says nothing about a surface cannot flag it in either direction, which is how five surfaces sat outside it. Derive the surfaces rather than trusting the lists — `ls ${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md ${CLAUDE_PLUGIN_ROOT}/agents/*.md` compared against the two rows above, **in both directions** — and treat a surface in neither row as a `major` finding in its own right, reported BEFORE anything about its `model:` line: which posture it should carry is the owner's decision, not the audit's. **That finding is reported in PROSE, outside the per-surface table, and takes none of the six values** — it is a defect in THIS LIST rather than in the surface's frontmatter, the remedy edits this page, and the table's `Field` column is one an unlisted surface cannot fill. `posture-question` in particular does not fit: its first clause is "a rule's flag stands", and the whole point here is that a rule silent about a surface cannot flag it at all.

> **SKILL-honored vs SUBAGENT-may-be-ignored (GH #44385).** A SKILL `model: opus` pin is **reliably honored** by the harness. A SUBAGENT (`${CLAUDE_PLUGIN_ROOT}/agents/*.md`) `model:` pin **may be ignored** — the agent can inherit the spawner's session model regardless of its frontmatter. So for agents the frontmatter pin is **intent-level** only; reliable opus comes from the opus-pinned spawning skill (the agent inherits) OR an explicit `model=` at the `Agent()` spawn site. Checklist P treats a **Non-code-reasoning** agent's `model: opus` pin as correct-intent and does NOT recommend dropping it, but records that the practical guarantee lives at the spawner. **The shield is scoped to that row and does not reach the Code-working / script-driven one**, where a pin contradicts the posture the row expects: there the row's flag stands, and it is reported under the `posture-question` value — drop the pin, or reclassify the surface — never as a `drop` recommendation the audit resolves by itself. Leaving the shield unscoped would void the agent half of that row and recreate the "rule silent on a surface" hole the exhaustiveness clause above exists to close. `fix-apply` is the live instance: it edits files and pins `model: opus`.

### Run output — per-surface recommendation table (AC3)

The run output is a per-surface recommendation table — **one row per skill / agent / hook**:

| Surface | Type | Value | Field | Recommendation | Severity |
|---|---|---|---|---|---|
| `<name>` | skill / agent / hook | add / drop / normalize / resolve-asymmetry / not-applicable / posture-question | `<field>` | one-line rationale | minor / nit / major |

The table is emitted at audit runtime (Step 2.5 output) — it is NOT stored in the repo.

