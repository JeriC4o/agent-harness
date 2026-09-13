# agent-harness

Multiagentic workflow harness — a reusable Claude Code harness: workflow skills, review subagents, enforcement hooks, and the agent-facing
doc set they read. Drop it into a new repo, fill in the placeholders, and the `/task` → `/bugfix` loop works
on day one.

Everything here is **tool-neutral**: git + GitHub for VCS and review, `%PLACEHOLDER%` tokens for the
project's build, test, format and lint commands.

## Layout

```text
AGENTS.md                  the rule surface — permissions, workflow AXIOMs, propagation rule, learning log
CLAUDE.md                  entry point; imports AGENTS.md
.claude/
  settings.json            permissions + PreToolUse / PostToolUse hooks (branch protection, gate masking, …)
  skills/                  the workflows below
  agents/                  subagents the workflows spawn
  rules/ast-index.md       code-search hierarchy, inherited verbatim by subagents
ai-docs/
  context.md               project context — TEMPLATE, fill it in
  code-style.md            language-neutral code style + a per-project language profile
  doc-convention.md        when a doc-comment is written, and what shape it takes
  workflow.md              git/GitHub command map, PR shape, test-result reading, staging rules
  templates/               canonical .progress.md and Learning Log entry formats
  plans/                   specs, designs, progress files (active / done / deferred)
  learnings/               per-branch Learning Log entries; learnings.md is the archive
```

## Workflows

| Skill | What it does |
|---|---|
| `/task` | The full loop: interview → spec → design → design-review → implement → verify → self-review → commit. Steps are strictly ordered. |
| `/bugfix` | Reactive: trace → root cause → failing test → fix → self-review. Test before fix, always. |
| `/interview` | Requirements interview that produces the spec. Invoked by `/task`, or standalone for spec-only work. |
| `/context-reset` | Group handoff for large tasks, and the compaction-recovery protocol every orchestrator re-enters through. |
| `/project-review` | Whole-branch review: findings table → fix loop → self-review until APPROVE. |
| `/pr-merged` | Post-merge cleanup: switch to the default branch, pull, drop the branch's progress files, delete the branch. |
| `/improve` | Folds merged learning files into the archive, finds repeating corrections, proposes rule escalations. |
| `/ai-audit` | Audits the instruction surface itself: broken links, drifted exemptions, name clashes, hook validity. |

Subagents (`.claude/agents/`): `spec-writer`, `design`, `design-review`, `self-review`, `review-findings`,
`self-improve`, `learnings-escalation-audit`.

## Adopting it in a project

1. Copy `AGENTS.md`, `CLAUDE.md`, `.claude/`, and `ai-docs/` into the repo root.
2. Replace `%PROJECT_NAME%` in `CLAUDE.md`.
3. Fill in the command table in [`AGENTS.md` § Build & Test](AGENTS.md#build--test) — `%BUILD_CMD%`,
   `%TEST_CMD%`, `%FORMAT_CMD%`, `%LINT_CMD%`, and how a module is addressed on the command line.
4. Fill in [`ai-docs/code-style.md` § Language profile](ai-docs/code-style.md#language-profile) and
   [`ai-docs/context.md`](ai-docs/context.md) — entities, modules, tech stack, test conventions.
5. Add a `PostToolUse(Write|Edit)` formatter hook to `.claude/settings.json` once `%FORMAT_CMD%` is real.
6. Merge the `.gitignore` entries so `*.progress.md` and `*.state.md` stay local.

## Design notes

- **Fail-loud rules, soft patterns.** Prohibitions are written as AXIOMs with a table of triggers;
  validated approaches are `## Patterns` blocks with soft verbs. `ai-docs/agent-writing-style.md` is the
  style contract for both.
- **One writer per artefact.** The orchestrator never writes `*.spec.md` / `*.design.md` — the owning
  subagent does. Violating that is how transcribed-instead-of-written docs drift.
- **Durable state survives compaction.** Every orchestrator carries a compaction-recovery callout at the
  top of its body and a `.progress.md` on disk, so a truncated session re-enters where it left off.
- **The Learning Log is append-only.** Corrections go to `ai-docs/learnings/<user>-<branch>.md`; `/improve`
  is the only thing that escalates them into rules.
- **Hooks catch what prose cannot.** Branch protection, gate-masking (`| tail` on a test run), learnings
  auto-staging, propagation reminders — see `.claude/settings.json`.
