# Instruction-file validation methodology

Methodology for testing whether an instruction file (AGENTS.md, a SKILL.md, an agent .md) actually changes Subagent behaviour. Used during `/ai-audit` Phase 2 when a rule is suspected of being dead text.

## Premise

A rule that no Subagent reads — or reads and ignores — is dead text. Adding a rule does not prove it works; only a behavioural test does.

## Methodology

For each candidate rule:

1. **Construct a reproducer scenario.** The scenario must trigger the rule's preconditions with a clear PASS / FAIL signal. Concrete file paths, concrete commands, concrete expected output.
2. **Spawn a fresh-context Subagent** (no conversation history) with the reproducer. Use the project's actual Subagent (`Agent(subagent_type=…)`), not a synthetic prompt.
3. **Observe the Subagent's behaviour.** Did it apply the rule? Did it ignore it? Did it misinterpret it?
4. **Classify the outcome** per the bias taxonomy below.
5. **Record + escalate.** PASS → rule is live; FAIL → propose a rewrite that addresses the failure mode.

## Bias taxonomy

When a rule fails behavioural validation, classify the failure to choose the rewrite shape.

| Bias | Symptom | Rewrite shape |
|---|---|---|
| **Verb-shape mismatch** | Rule uses *Default to* on a stick obligation; Subagent treats it as advisory. | Promote to AXIOM blockquote with *MUST* / *NEVER*. |
| **Buried in narrative** | Rule lives in mid-paragraph; Subagent skipped to the next h2 anchor. | Lift to a fail-loud AXIOM blockquote at section top. |
| **Vague trigger** | Rule says "when appropriate"; Subagent's notion of "appropriate" disagrees with the author's. | Replace with mechanical trigger (regex / command output / file path). |
| **Stale cross-reference** | Rule cites `skill:foo`; `skill:foo` was renamed. | Fix the reference; add propagation-rule row so the link can't rot. |
| **Surface mismatch** | Rule lives in AGENTS.md but the behaviour is owned by a Skill. | Move the rule into the Skill's body; leave a one-line summary in AGENTS.md. |
| **Cold-spawn truncation** | Rule lives past line ~5000-tokens of the Skill; Subagent's per-skill cap truncated. | Move the rule to the top of the body; extract verbose detail into `ai-docs/`. |
| **Implicit assumption** | Rule assumes domain knowledge (VCS semantics, an internal API) the Subagent doesn't carry. | Inline the assumption or link to the canonical reference. |

## Per-bias mitigation recipe

### Verb-shape mismatch

Rewrite from `## Patterns` block to AXIOM blockquote, or vice versa. Verify the new shape passes Checklist M sub-check 1/2 against the audit corpus.

### Buried in narrative

Move the rule to a fail-loud AXIOM blockquote at the **top** of the relevant section, with the trigger column + action column shape. The body of the section retains the rationale; the AXIOM blockquote is the actionable surface.

### Vague trigger

Replace prose ("when the situation requires", "for edge cases") with one of:

- A regex (`'/master.*ci'`)
- A command output (`git branch --show-current` returns `main`)
- A file-path glob (`ai-docs/plans/*.spec.md`)
- A field value (`Escalated? no` AND age > 30 days)

### Stale cross-reference

Repair the link **and** add a Propagation Rule row in `${CLAUDE_PLUGIN_ROOT}/docs/propagation.md` — that is where the sync-group table lives — so future renames trigger sister-file updates.

### Surface mismatch

Move the rule into the closest Skill / agent body. Leave a one-line summary in AGENTS.md only if cross-cutting (referenced by ≥2 Skills).

### Cold-spawn truncation

Bring the rule above the 5000-token mark of the Skill body (typically top of body, preamble area). Push verbose rationale into `ai-docs/<topic>.md`. Verify the truncation point with `head -c 20000 <skill.md> | grep <rule-keyword>`.

### Implicit assumption

Inline the assumption ("`git diff main` shows the working tree, `git diff main...HEAD` does not — see [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md`](workflow.md#git--github-command-map)") or link the canonical reference.

## Reproducer-prompt template

```
### Reproducer R<id> — <rule-summary>

**Rule under test:** <verbatim rule line from instruction file, with file:section anchor>

**Scenario:** <concrete situation that should trigger the rule>

**Setup:**
- Branch: <branch state>
- Files in working tree: <list>
- Expected Subagent task: <what the Subagent should do>

**PASS criterion:** <Subagent applied the rule; observable in its action / refusal>
**FAIL criterion:** <Subagent ignored the rule, or misapplied it; concrete sign of failure>
```

## Where validation results live

After a validation pass:

- PASS → append a `Kind: validation` entry to `ai-docs/learnings/<username>-<branch>.md` confirming the rule fires; `/ai-audit` Checklist N then expects a back-link from a `## Patterns` section (for carrots) or a propagation row in AGENTS.md (for sticks).
- FAIL → append a `Kind: correction` entry naming the bias category; the next `/improve` run will rewrite the rule.

## Dual-model considerations

Some Subagents run on Opus (deeper context-following), others on Haiku/Sonnet (faster, more rule-anchored). A rule that passes against Opus may fail against Haiku. When promoting a validated rule, run a second pass with the Subagent class that will actually consume it (`/task` orchestrator = main loop = Sonnet; `design` / `spec-writer` = Opus).

## Audit corpus

The instruction-file corpus audited by `/ai-audit` is:

- `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` (every skill)
- `${CLAUDE_PLUGIN_ROOT}/agents/*.md` (every agent)
- `${CLAUDE_PLUGIN_ROOT}/rules/**/*.md`
- `ai-docs/{code-style,doc-convention,context,agent-writing-style,corrections-log,workflow,claude-tools-hierarchy,skill-size-exemptions,considerations-link-reading,instruction-file-validation,agent-docs-index}.md`

The 40,000-char file-size cap applies to every file in this corpus.
