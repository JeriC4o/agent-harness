# Skill-size exemptions

Audited list of `.claude/skills/*/SKILL.md` files exempted from the 200-line soft target. Consumed by `/ai-audit` Phase 2 Checklist K item 1.

Empty by default. Rows added only after a user-approved exemption during an `/ai-audit` run.

## Exemptions

| Skill | Line count | Date approved | Reason |
|---|---|---|---|
| _(none)_ | — | — | — |

## Approval recipe

1. `/ai-audit` Checklist K flags a SKILL.md > 200 lines.
2. Owner argues either (a) split into `reference.md` extractions until under 200, OR (b) request a permanent exemption with rationale.
3. On user-approved exemption, append a row to the table with `wc -l` count, approval date, and reason ("orchestrator complexity — every step has a fail-loud gate"; "embedded keyword list").
4. Next audit run compares actual `wc -l` to the recorded count; drift > 10% surfaces a `nit` to re-audit.

## Cross-link

Checklist K detail: see `.claude/skills/ai-audit/reference.md` § Checklist K.
