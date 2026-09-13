# Link-reading policy

When a skill / agent / AGENTS.md body contains a `[link]` reference, follow this policy.

## Default: skim by anchor + summary

A link's surrounding sentence usually carries the one-line summary you need. *Default to* trusting the summary and continuing.

## Follow the link when

- The link target is the **canonical source** of a rule the current step enforces (e.g. `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § File size` when the current diff adds a 1200-line file).
- The link target is a **template** the current step must produce (e.g. `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` when writing a `.progress.md`).
- The link target is **named in an AXIOM** (e.g. AGENTS.md `## Workflow` AXIOM 2 links to `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § PR body sync` — the AXIOM is unactionable without the recipe).
- The summary disagrees with what the current task implies — read the target to resolve.

## Don't follow the link when

- The summary is sufficient.
- The link is an audit-trail anchor (`see ai-docs/learnings.md 2026-MM-DD <slug>`) and you're not auditing.
- The link is a worked example and the abstract spec above it already answered the question.

## Anchor-aware paths

A link like `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-body-sync` resolves to that exact h2 / h3 anchor — read only the anchored section, not the whole file. Tools that strip the `#anchor` (e.g. naive `realpath`) miss the contract.

## When the link is broken

Surface to the user. `/ai-audit` Checklist A catches broken links across the corpus; an inline broken link discovered during a `/task` run is a finding for the next `/ai-audit` invocation, not a fix the current task should bundle.

## Cross-skill links

Skill A → Skill B body link: skim. The link tells you Skill B exists and roughly covers the topic. Open Skill B fully only if your current step depends on Skill B's contract (e.g. `/task` Step 10 spawns `self-review` — Step 10 needs the `self-review` agent's verdict shape, so Read the agent file fully before spawning).
