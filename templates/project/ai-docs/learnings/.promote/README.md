# Promotion candidates

A lesson learned in this project stays in this project. This directory is the **only** way one can reach
the shared harness, and it exists so that crossing costs something deliberate.

## The boundary

`/harness:improve-global` reads **only** `ai-docs/learnings/.promote/*.md`. It has no code path that opens
`ai-docs/learnings.md` or `ai-docs/learnings/*.md`. That is the guarantee: not "the agent was told not to
export project data", but "the sweep cannot see it".

Every candidate is checked by `${CLAUDE_PLUGIN_ROOT}/scripts/check-candidate.sh`, which refuses anything
carrying a project identifier — this repo's name, its ticket-key prefix, a `KEY-123` token, a domain
entity from `ai-docs/context.md`, a file path, or a URL host. The gate runs when a candidate is written
**and again when it is read**, because a file can be hand-edited after it passes.

## What belongs here

A candidate describes the **shape** of a mistake, never the instance:

> ❌ The `DiffSet` merge in `server/core/Merge.kt` silently dropped rows when `PROJ-8812` landed.
> ✅ A gate whose failure mode is empty output reports success when it matched nothing.

If the lesson cannot survive having every project-specific noun removed, it is a project lesson — leave it
in `ai-docs/learnings/` where it belongs. Most lessons are project lessons; that is the expected ratio.

## Format

```markdown
---
id: <kebab-slug>
category: code-style | process | architecture | testing | documentation | tooling | search | other
kind: correction | validation
created: YYYY-MM-DD
---

**Rule:** <what to do, or stop doing — imperative, no project nouns>

**Why:** <the failure mode in general terms>

**Signal:** <what makes it detectable in advance — the shape to watch for>
```

## Lifecycle

1. `/harness:improve` proposes a candidate when a project lesson looks like a method defect. **It asks
   first** — a candidate is never written silently.
2. The gate runs. A refusal names the offending term; rewrite rather than argue with it.
3. The candidate sits here, committed with the project, until a cross-project sweep picks it up.
4. `/harness:improve-global` promotes a rule only when **≥2 distinct projects** carry the same lesson. One
   project hitting something three times is a project pattern; two projects hitting it once each is a
   method defect.

A candidate is not deleted after promotion — it is the evidence that the harness rule has a source.

## `deny-extra.txt`

One term per line, `#` comments allowed. Add any codename, product name, or internal noun the gate cannot
derive from the repo itself. It is cheap insurance and it is read on every check.
