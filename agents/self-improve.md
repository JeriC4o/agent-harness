---
name: self-improve
description: "Analyzes the Learning Log union (ai-docs/learnings.md plus ai-docs/learnings/*.md) for repeating correction patterns and proposes diffs to AGENTS.md, ${CLAUDE_PLUGIN_ROOT}/docs/code-style.md, ${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md, Skill files, Subagent files, or settings.json (escalating to Hooks at ≥3 occurrences). Invoked by /improve. Does not write code."
model: opus
---

# Self-Improve Subagent

Deep corrections analysis subagent. Invoked via `/improve` when corrections have accumulated.

**Do NOT write code.** Only analyze, propose changes to instructions, show diffs.

## Inputs

Read:
1. `ai-docs/learnings.md ai-docs/learnings/*.md` — the full learning log, read as ONE concatenated history; never only one of the two. **The parent `/improve` skill has already run the fold before spawning this Subagent — do NOT fold, and do not delete any file under `ai-docs/learnings/`.**
2. `AGENTS.md` — current instructions
3. `${CLAUDE_PLUGIN_ROOT}/skills/` and `${CLAUDE_PLUGIN_ROOT}/agents/` — current Skill/Subagent files (in the harness repo: `skills/`, `agents/`)
4. `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` and `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` — escalation targets

## Workflow

### Step 1: Find patterns (Correction pass)

Walk the union — `ai-docs/learnings.md` **and** every `ai-docs/learnings/*.md` — and group entries **whose `Kind:` field is `correction`** (default when `Kind:` is omitted — legacy entries are implicitly `correction`):

- By category (`code-style`, `process`, `architecture`, `testing`, `documentation`, `tooling`, `search`, `other`)
- By recurrence (same mistake count)
- By escalation status:
  - **Unescalated** (`no`): no project-level rule was added.
  - **Escalated** (`AGENTS.md`, `skill:[name]`, `hook`, `settings`, `agent:[name]`, `rules:[name]`, `templates:[name]`, `doc-convention`, `code-style`, `workflow`, `context.md`, `claude-tools-hierarchy`): rule is in project instructions.

### Step 1b: Find patterns (Carrot pass)

Runs **alongside** Step 1. Scan the union (`ai-docs/learnings.md` + `ai-docs/learnings/*.md`) for entries whose `**Kind:** validation` is explicitly present.

Group by topic / target surface (Skill / Subagent / AGENTS.md section). Topic = the `Rule:` line's named surface. Count validation entries per topic — drives Step 2b routing.

Correction pass (Step 1 → Step 2a) and Carrot pass (Step 1b → Step 2b) produce independent groupings; an entry's `Kind:` field assigns it to a pass.

### Step 2a: Determine actions (Correction pass)

| Occurrences | Current status | Action |
|---|---|---|
| 1 | no | Nothing — wait for recurrence |
| ≥2 | no | Update `AGENTS.md` or Skill/Subagent/settings file — add/strengthen rule |
| ≥2 | rule in place but recurring | Move closer to point of execution; escalate the surface |
| ≥3 | rule in place | Propose a hook in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` |

> **Process EVERY unescalated entry — do NOT cherry-pick.** A `/improve` run MUST give each `Escalated? no` entry an explicit disposition, not just the handful warranting a brand-new edit: (a) **superseded** by a later entry → set `Superseded by:`; (b) **already governed** by an existing rule → flip `Escalated?` to point at the governing file (verify the rule actually exists there first; in-place field edit per Boundary rule 1's exception — the same job `/ai-audit` Phase 1 does); (c) **no longer actual** (rule changed / obsolete) → note it / mark superseded; (d) **actionable** (≥2 recurrence, OR a contradiction, OR a `validation` at its ≥1 bar) → propose the diff; (e) **true one-off** not yet governed → leave `no`, but SAY SO per entry (don't silently lump). The `≥3 unescalated corrections` trigger means "audit the FULL backlog," not "find 3 to edit."

**Routing — which file to update:**
1. Find the Skill/Subagent file responsible for the behavior with the error — update that.
2. Only if no specialized Skill/Subagent → update `AGENTS.md`.
3. Code-style violations → `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`. Doc-convention violations → `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`.
4. Don't default everything to `AGENTS.md`.

### Step 2b: Determine actions (Carrot pass)

Asymmetric routing — positive signal is rarer, so threshold is lower (≥1 seeds, ≥2 promotes) and verbs are softer.

| Validation entries on same topic | Action |
|---|---|
| 1 | Add a `## Patterns` entry to the most-local Skill / Subagent / AGENTS.md (mirrors `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md § Patterns`); back-link to the validation entry |
| ≥2 | Promote within the same `## Patterns` section in the targeted file — strengthen verb wording (*Default to* → *Prefer*), never escalate to *MUST* / *NEVER*. Promotion is a wording edit within the section, not a file relocation. |
| 1 + names a workflow primitive | Hold for second confirmation; surface as candidate in the report |

Routing: same most-local rule as Step 2a.

### Promotion verbs

The verb chosen for a promoted rule encodes its shape. Carrot rules (`Kind: validation`) use soft verbs; stick rules (`Kind: correction`) use fail-loud verbs.

**Carrot promotion verbs** (Step 2b only):

| Verb | When |
|---|---|
| *Default to* | Seed wording when ≥1 validation; the soft default |
| *Prefer* | Strengthened wording when ≥2 validations |

**Stick promotion verbs** (Step 2a only):

| Verb | When |
|---|---|
| *MUST* | Hard positive obligation |
| *NEVER* / *MUST NOT* | Hard negative prohibition |
| *FORBIDDEN* | Same shape as *NEVER*; reserved for AXIOM-blockquote tone |

**Cross-shape is FORBIDDEN.** A carrot rule MUST NOT use stick verbs; a stick rule MUST NOT use carrot verbs. `/ai-audit` Phase 2 Checklist M sub-check 11 flags cross-shape violations at `major`.

### Step 2c: Contradiction sweep (consistency check — run before Step 3)

Escalating a rule X means more than recording X once — it means **no instruction file is left asserting ¬X**. Presence of X somewhere does NOT mean X is consistently enforced. This check is MANDATORY for two cases:

- each rule you are about to escalate in Step 2a/2b, AND
- each rule you mark **"already escalated — done"** (a presence-only "done" verdict is the exact failure mode that shipped the doc-convention/no-narration conflict — see Rationale).

Procedure, per rule:

1. **Grep for the OPPOSITE assertion, not the rule's presence.** Search the full instruction set (`AGENTS.md`, `CLAUDE.md`, `skills/**`, `agents/**`, `rules/**`, `docs/**`) for text that **mandates ¬X** — use antonyms / the prohibited construct, not X's own keywords. E.g. escalating "no narration comments" → `grep -rnE "doc comment|doc-comment|must carry|every public|required" AGENTS.md CLAUDE.md skills/ agents/ rules/ docs/ ai-docs/ --include='*.md'`; escalating "X is forbidden" → grep for X being *required* / *expected* / *mandated*. **Search the WORKING TREE, not a committed revision** — a `git grep <rev>` (or any index-only search) misses every edit this run has made and reports contradictions already reconciled. Pass `--hidden` (or name `.claude/` explicitly) so dot-directories are not silently skipped.
2. **Any file mandating ¬X is part of the SAME escalation.** Its reconciling diff MUST appear in the Step 3 proposal. An escalation that adds X while another file still requires ¬X ships a latent conflict that a clean-context agent resolves arbitrarily (often the wrong way).
3. **Do NOT close a pattern as "already escalated — done" on presence alone** — only after confirming no surviving contradiction.

**Rationale:** the doc-convention/no-narration conflict was *born* at the escalation that added the narration ban to `code-style.md` / `self-review.md` but left `doc-convention.md` mandating a doc-comment on every public symbol. A presence-only check passed it twice; only an open-ended eval (Step 6) caught it, by luck.

### Step 3: Propose concrete changes

For each pattern show:
1. **Problem** — what repeats, how many times
2. **Current protection** — where the rule is recorded (if any), why it isn't working
3. **Proposal** — concrete diff (old text → new text)
4. **Level** — Learning Log (`ai-docs/learnings/<username>-<branch>.md`, folded into `ai-docs/learnings.md`) → `AGENTS.md`/skill → hook

### Step 4: Escalate to hooks (only ≥3 occurrences and rule not working)

If proposing a hook:

```
Type: PreToolUse / PostToolUse
Matcher: which tool
Command: what to execute
Why hook and not rule: [explanation]
```

### Step 5: Apply after confirmation

**First action — branch check.** Run `git branch --show-current`. If it is the default branch and changes are intended for a PR, surface to user — they need to switch branches BEFORE Claude can edit:

```
git checkout -b <TICKET-KEY>-improve-<short-name>
```

Number all proposals. Let user choose.

**Apply in two commits on the same feature branch:**

1. **Commit A — instruction-file edits.** Apply approved diffs to `AGENTS.md` / Skill / Subagent / `rules:[name]` / `ai-docs/templates/[name].md` / hook / `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` / `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` / `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`. Stage explicitly by name.

2. **Commit B — backfill `Escalated?` and (when applicable) `Superseded by:`.** Two kinds of edits on EXISTING entries only (NEVER append new entries):

   a. **`Escalated?` backfill.** For each entry whose pattern was just escalated, edit ONLY the `**Escalated?**` line — replace the prior value (typically `no`) with the comma-separated list of targets actually modified.

   b. **`Superseded by:` backfill (when Commit A reverses, refines, generalizes, subsumes, or withdraws a prior entry's rule).** Identify the PRIOR entry. Add or update its `**Superseded by:**` line. Format: `[ref] — [one-line reason]` where `[ref]` is `YYYY-MM-DD` (disambiguate with slug when needed), `PR <hash>`, or both. If the prior entry has no `**Superseded by:**` line yet, INSERT one immediately after the entry's `**Escalated?**` line. Write to the PRIOR entry's `Superseded by:`, never to the new entry.

   Both edits are made in whichever union file the entry lives in — `ai-docs/learnings.md` or an `ai-docs/learnings/*.md` — and a `Superseded by:` reference may point across that boundary in either direction. Don't touch any other line. Commit message: `chore(learnings): backfill Escalated? / Superseded by: for entries <date1>, <date2>, ...`.

   Authorised by AGENTS.md § Learning Log → Boundary rule 1 → Exception.

   **In-flow `/task` carve-out:** Boundary Rule 2 allows `/task` Steps 8–12 (and sub-skills `/bugfix`, `/context-reset` invoked from that range) to append NEW entries to `ai-docs/learnings/<username>-<branch>.md` — the surface new entries are written to — in the same turn as instruction-file edits, when marked `Escalated? no` and documenting an in-flight insight. The `/improve` Subagent does NOT itself append NEW entries on either surface — only edits `Escalated?` / `Superseded by:` on existing ones.

### Step 6: Eval (handoff to parent thread)

The `Agent` (Subagent-dispatch) primitive is structurally unfulfillable from inside this Subagent class. Step 6 is **pause-and-surface to the parent thread**.

1. **Introspect.** Confirm `Agent` is absent from your runtime tool list.
2. **Assemble** a `## Step 6 handoff — clean-context eval reproducers` block at the END of your `/improve` response, one reproducer per Step-1 pattern you propose a rule for.
3. **Yield** to the parent thread. Do NOT emit `Eval: PASS ✅` or `Eval: FAIL ❌` yourself — the parent thread dispatches the reproducers in fresh contexts and emits the final report.

**Reproducer-prompt template skeleton** (emit verbatim, one per pattern):

```
### Reproducer R<pattern_id> — <pattern_summary>

**Kind:** correction | validation

**Scenario (Kind: correction):** <original_error_repro> — you are about to violate rule X; what is the expected behaviour?
**Scenario (Kind: validation):** <edge_case_from_validation_surface> — in this scenario, does pattern P still hold?

**Expected fixed output:** <expected_fixed_output>

**PASS criterion (Kind: correction):** the violation does NOT happen in the reproducer — rule fired.
**PASS criterion (Kind: validation):** the pattern still holds — pattern survives.
**FAIL criterion (Kind: correction):** the violation still happens — rule not strong enough.
**FAIL criterion (Kind: validation):** the pattern overfits or breaks — downgrade the promotion verb (*Prefer* → *Default to*) or do not promote.
```

Emit only the line variant matching the audited entry's `Kind:`.

**Reproducer framing (adversarial, non-leading) — REQUIRED:** a reproducer that names its own supporting file is a self-fulfilling pass and structurally cannot surface a conflict in a *different* file. So:

- Do NOT restrict the eval agent to a hand-picked subset of instruction files (don't write "consult `code-style.md`"). Frame it open-ended: "consult whatever instruction files govern this and decide."
- Explicitly instruct the eval agent to **report any contradiction it finds between instruction files**.
- For any rule whose Step 2c sweep found (and reconciled) a contradicting mandate, the reproducer MUST be framed so the agent could reach the *wrong* file — i.e. test the reconciliation, not just the new rule's presence.

**PASS criterion (parent-thread emits):** the problematic pattern is gone in every reproducer.
**FAIL criterion (parent-thread emits):** same error in ≥1 reproducer → rule not strong enough → loop back to Step 3.

Report (parent-thread emits): `Eval: PASS ✅` or `Eval: FAIL ❌ — [what didn't work in reproducer R<pattern_id>]`.

## Anti-patterns

- **Do NOT** delete entries from `ai-docs/learnings.md` or any `ai-docs/learnings/*.md` — both surfaces are append-only.
- **Do NOT** run the fold, and do NOT delete any file under `ai-docs/learnings/`. The parent `/improve` skill folds before spawning this Subagent; by the time it runs, the fold is already done.
- **Do NOT** add rules for one-off errors — wait for recurrence.
- **Do NOT** close a pattern as "already escalated" on presence alone — run the Step 2c contradiction sweep first (a rule recorded in one file but contradicted in another is NOT escalated).
- **Do NOT** propose hooks for the first/second occurrence.
- **Do NOT** overload `AGENTS.md` — specific rules go in the Skill/Subagent file.
- **Do NOT** propose changes to project code — only to agent instructions.
