# Propagation Rule

Extracted from `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Propagation Rule`, which keeps the AXIOM and
points here for the sync-group table and the sweep procedure. This page is pure reference and grows by one
row per sync group — which is why it does not live in the file every agent loads at session start.

**`scripts/check-propagation-arms.sh` DERIVES the propagation reminder's path classes from the table below**,
reading BOTH cells of every row, because some groups name a member only on the anchor row's right-hand cell.
Moving, renaming or reformatting this table changes what that gate computes, so its shape is load-bearing:
re-run the gate after any edit here, and check the member COUNT it reports rather than only its exit status.

> **AXIOM — Edits to one instruction file MUST propagate to its sync-group siblings in the SAME PR.**
> The Propagation Rule fires whenever you edit an instruction file. Sister files in the same sync group must receive the corresponding change before the PR is opened.
>
> | If you edit... | You MUST also check / update... |
> |---|---|
> | `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` | `${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` (Review group) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md` OR `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` | See *Review group* anchor row above. |
> | `${CLAUDE_PLUGIN_ROOT}/skills/interview/SKILL.md` | `${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` (Interview group — pre-resolved-rule list mirrors live in `spec-writer.md`) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` | `${CLAUDE_PLUGIN_ROOT}/skills/interview/SKILL.md` (Interview group) |
> | `AGENTS.md` (rule add / exemption) | Run the [propagation sweep](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md#propagation-sweep) and apply the same change to every match. |
> | `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Learning Log` (Boundary rules, entry format, `Kind:`, `Escalated?` semantics) | `${CLAUDE_PLUGIN_ROOT}/agents/self-improve.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` AND `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` AND `ai-docs/learnings/README.md` (Learning-Log group) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/self-improve.md` OR `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` OR `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` OR `ai-docs/learnings/README.md` | See *Learning-Log group* anchor row above. `ai-docs/learnings/README.md` and `learnings-entry-format.md` § Target file are *Fold group* members as well — an edit touching those fires BOTH groups, not whichever row you reach first. |
> | `${CLAUDE_PLUGIN_ROOT}/skills/improve/SKILL.md` (the fold block, its guards, or the order they run in) | `ai-docs/learnings/README.md` (which states the fold contract) AND `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` § Target file (which owns the derivation every guard depends on) (Fold group) |
> | `ai-docs/learnings/README.md` OR `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` § Target file | See *Fold group* anchor row above. |
> | `${CLAUDE_PLUGIN_ROOT}/skills/inspect/SKILL.md` (what it runs, what it hands the agent, what it surfaces) | `${CLAUDE_PLUGIN_ROOT}/agents/inspector.md` AND the output contracts of `${CLAUDE_PLUGIN_ROOT}/scripts/session-events.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/loop-metrics.sh` (Inspect group). Four vocabularies for one mechanism — the skill names the inputs, the agent how to read them, the scripts produce them — so a token sweep reaches at most one. |
> | `${CLAUDE_PLUGIN_ROOT}/agents/inspector.md` OR either reader's emitted fields, signature kinds, or thresholds | See *Inspect group* anchor row above. |
> | `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` (design-phase / handoff contract) | `${CLAUDE_PLUGIN_ROOT}/agents/design.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` AND `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` (Task/Design group) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/design.md` OR `${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` OR `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` | See *Task/Design group* anchor row above. |
> | `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` *Spec Amendment recipe* / *Design Amendment recipe* | `${CLAUDE_PLUGIN_ROOT}/skills/bugfix/SKILL.md` AND `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` AND [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md § Spec-Amendment group`](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#spec-amendment-group) (Spec-Amendment group) |
> | `${CLAUDE_PLUGIN_ROOT}/skills/bugfix/SKILL.md` *Spec Amendment* handling OR `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § Spec-Amendment group OR `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` OR `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` | See *Spec-Amendment group* anchor row above. The last two are *Review group* members as well — an edit to either fires BOTH groups, not whichever row you reach first. |
> | `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md` (new `## Patterns` entry) | Add a `Kind: validation` entry to `ai-docs/learnings/<username>-<branch>.md` (Checklist N coherence) |
> | `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md` | `${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/SKILL.md` Checklist K (cited line counts must match) |
> | `${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/SKILL.md` ↔ `${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/reference.md` | Keep the Step 2.3 letter table, the reference.md checklist detail bodies (incl. Checklist M sub-checks), and the `**Reference:**` footer letter range in sync (ai-audit group). |
> | `${CLAUDE_PLUGIN_ROOT}/rules/<file>.md` | Run the [propagation sweep](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md#propagation-sweep) — rule files are read on-demand, so cross-rule edits must sweep every instruction directory. |
> | Any edit that changes a Tool / Subagent / Skill / Hook contract OR renames a stable anchor in `claude-tools-hierarchy.md` | Update `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md` in the same PR. |
> | Any other instruction file | Run the same [propagation sweep](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md#propagation-sweep) — Procedure below catches lingering references. |

**Procedure:**
1. Before closing the edit, run the [propagation sweep](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md#propagation-sweep) for any file that references the same rule, exemption, or terminology — all four paths, `--hidden`, and a positive control before trusting an empty result.
2. Apply the same change (or the corresponding enforcement adjustment) in every match.
3. AGENTS.md rule exemptions especially must propagate to subagent checklists that enforce the rule (`self-review.md`, `review-findings.md`).
4. **A sweep and a named row are not interchangeable coverage.** A sweep finds files that share the changed *wording*; a named row names files that describe the same *mechanism* in different words. A file that explains a mechanism in its own vocabulary is invisible to a sweep keyed on the changed TOKEN — which is how a contract went stale while its describing files carried no occurrence of the identifier that changed. When the thing you edited is a mechanism rather than a phrase, the fallback row at the bottom of the table is NOT enough: add a group.
5. **A group of three or more members gets an anchor row plus one back-reference row**, as the Task/Design and Fold groups do — not one row per member, which grows as the square of the group and drifts a member at a time. Name every member on the anchor row; the back-reference row points at it.
