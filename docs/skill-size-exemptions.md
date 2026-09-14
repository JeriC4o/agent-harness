# Skill-size exemptions

Audited list of `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` files exempted from the 200-line soft target. Consumed by `/ai-audit` Phase 2 Checklist K item 1.

Empty by default. Rows added only after a user-approved exemption during an `/ai-audit` run.

## Exemptions

| Skill | Line count | Date approved | Reason |
|---|---|---|---|
| `task` | 211 | 2026-09-14 | Orchestrator with a strictly ordered step sequence, each step carrying its own fail-loud gate. Extracting steps into `reference.md` would make the reader follow a link mid-sequence, which is the failure the ordering exists to prevent. Detail already lives in `reference.md`; what remains is the sequence itself. |
| `ai-audit` | 221 | 2026-09-14 | Same shape, plus two surfaces (`global` / `project`) whose checklist tables must be visible together for the scope decision to be made correctly. Per-letter detail is already extracted to `reference.md`. |

Both sit far below the hard constraint that actually matters — the 40,000-char instruction-file cap
(`AGENTS.md § Build & Test`): `task` is ~22k, `ai-audit` ~11k. The 200-line target is about keeping a
body scannable, and an ordered workflow is scannable at 211 lines in a way a fragmented one is not.

## Approval recipe

1. `/ai-audit` Checklist K flags a SKILL.md > 200 lines.
2. Owner argues either (a) split into `reference.md` extractions until under 200, OR (b) request a permanent exemption with rationale.
3. On user-approved exemption, append a row to the table with `wc -l` count, approval date, and reason ("orchestrator complexity — every step has a fail-loud gate"; "embedded keyword list").
4. Next audit run compares actual `wc -l` to the recorded count; drift > 10% surfaces a `nit` to re-audit.

## Cross-link

Checklist K detail: see `${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/reference.md` § Checklist K.
