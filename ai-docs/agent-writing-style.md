# Agent writing style — binary-rule wording

Style guide for instruction files (AGENTS.md, skills, agents) so a fresh-context Subagent can act on the rule without re-reading the surrounding narrative.

## Patterns

### 1. Binary rules over prose

*Default to* writing rules as IF / THEN tables or AXIOM blockquotes. *Prefer* a 2-column "If X, do Y" table to a paragraph that describes the same logic.

**Why.** Subagents read top-to-bottom on cold spawn; a table compresses to one scan. A paragraph requires inference.

### 2. Fail-loud AXIOMs for stick rules

For `Kind: correction` escalations into AGENTS.md, use this shape:

```
> **AXIOM — [one-sentence rule].**
> [Why the rule exists; recurrence count or PR ref.]
>
> | If you see... | Action |
> |---|---|
> | <trigger> | <action> |
```

Verb voice: *MUST* / *NEVER* / *MUST NOT* / *FORBIDDEN*.

### 3. Soft `## Patterns` blocks for carrot rules

For `Kind: validation` escalations, use this shape under a `## Patterns` heading:

```
### N. <pattern name>

*Default to* <behaviour>. *Prefer* <stronger variant> when <condition>.

**Why.** <one paragraph of rationale, cite the validation entry by date>.
```

Verb voice: *Default to* / *Prefer*. Never *MUST* / *NEVER*.

### 4. Surface verbs in lock-step

The verb shape encodes the rule shape. Stick verbs on a `## Patterns` block (or carrot verbs in an AXIOM blockquote) underweight the obligation or lock in a brittle default. `/ai-audit` Phase 2 Checklist M flags cross-shape drift at `major`.

### 5. Cross-link, don't duplicate

When the same rule applies in two surfaces, write it once and link. Two copies drift; one canonical source + N links does not.

### 6. Lift verbose detail into ai-docs/

When a SKILL.md or agent file body crosses ~5KB or a section turns prose-heavy, extract the detail into `ai-docs/<topic>.md` and replace the body section with a link plus a one-line synopsis. Keeps cold-spawn reads cheap.

### 7. Worked example > abstract spec

A 10-line worked example (concrete file paths, concrete commands, concrete expected output) beats a 30-line abstract spec. Use the worked example as the rule's *anchor*; let the spec hang off it.

## Anti-patterns

- **Multi-paragraph rationale before the rule.** The rule comes first; rationale follows.
- **Synonyms in different surfaces.** "Branch protection" in one place, "main guard" in another, same hook — pick one term.
- **Stick verbs on carrot rules.** *MUST* on a `Kind: validation` pattern locks a default into an obligation.
- **Inline duplication of a sister rule.** Mirror it once; link to the canonical sibling.
- **Vague triggers.** "When the situation requires" is unactionable. "When `git branch --show-current` returns `main`" is actionable.

## Sub-checks (used by `/ai-audit` Checklist M)

| # | Sub-check | Severity on violation |
|---|---|---|
| 1 | Stick rule uses stick verbs (*MUST* / *NEVER* / *MUST NOT* / *FORBIDDEN*) | `major` |
| 2 | Carrot rule uses carrot verbs (*Default to* / *Prefer*) | `major` |
| 3 | AXIOM blockquote has trigger column + action column | `minor` |
| 4 | `## Patterns` block carries "Why." paragraph + cite to a Learning Log entry (`ai-docs/learnings.md` or `ai-docs/learnings/*.md`) | `minor` |
| 5 | Cross-surface duplicate detected → keep canonical, link sister | `minor` |
| 6 | Body > 5KB and has no extraction anchor in `ai-docs/` | `nit` |
| 7 | Vague trigger ("when appropriate", "when needed") | `nit` |
| 8 | Worked example is anchored before the abstract spec | `nit` |
| 9 | Stick verbs nested inside a `## Patterns` block | `major` |
| 10 | Carrot verbs nested inside an AXIOM blockquote | `major` |
| 11 | Cross-shape drift detected (verb shape ≠ rule shape) | `major` |

## Propagation rule for new patterns

When a new pattern is added to a `## Patterns` block in any skill / agent / AGENTS.md section, also add a `Kind: validation` entry to `ai-docs/learnings/<username>-<branch>.md` whose `Rule:` line names the same surface — `/ai-audit` Checklist N verifies the bidirectional `## Patterns` ↔ `Kind: validation` coherence at run time. Patterns without a back-link to a validation entry flag `major`.
