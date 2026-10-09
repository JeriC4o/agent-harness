---
name: ai-audit
description: "Two-phase instruction audit over one of two surfaces. Surface `global` audits the harness method files; `project` audits a consuming project profile (unresolved placeholders, dead commands, registry coherence, candidate hygiene, gitignore coverage). Phase 1 verifies every Learning Log `Escalated?` claim points to a rule that exists; Phase 2 reads the instruction files against the documented contracts and proposes fixes."
model: opus
disable-model-invocation: true
argument-hint: "[global|project] [phase1|phase2]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(grep:*), Bash(rg:*), Bash(find:*), Bash(realpath:*), Bash(jq:*), Bash(awk:*), Bash(wc:*), Bash(basename:*), Bash(git branch:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git diff:*), Bash(git check-ignore:*), Bash(scripts/audit-project.sh:*)
---

# AI Audit

Compliance + structural audit of the project's instruction surface. Complements `/improve` (which detects new patterns from the Learning Log union — `ai-docs/learnings.md` **plus** `ai-docs/learnings/*.md`) by checking that **already-recorded** rules are coherent, reachable, and live where they claim to live.

Steps execute strictly in sequence. Stop on any unrecoverable mismatch and surface to user.

## Step 0: Resolve the scope

Two independent dimensions. Both are optional and order does not matter.

**Surface** — *what* is audited:

| Value | Surface | Checklist |
|---|---|---|
| `global` | the harness itself: `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` | A–P |
| `project` | a consuming project's profile: `AGENTS.md`, `ai-docs/**`, `.claude/settings.json` | A, C, L, M, N + Q–U |

**Phase** — *how far*: `phase1` (escalation audit subagent only), `phase2` (instruction audit only), or
omitted for both.

**When the surface is omitted, detect it — do not assume.** The harness repo is the one carrying its own
plugin manifest:

```bash
jq -r '.name // empty' .claude-plugin/plugin.json 2>/dev/null
```

`harness` → **global**. Anything else, or no such file → **project**. State the resolved surface in your
first message; a silent guess about which corpus is being audited is how a project audit "passes" by
checking files that were never there.

> **A `global` run belongs in the harness repo.** If the surface resolves to `global` from somewhere else,
> stop and say so — the fixes it proposes edit method files, which do not exist in a consuming project.

Argument received: `$ARGUMENTS`

---

## Pre-flight: branch check

`git branch --show-current`. If it is the default branch and any change is anticipated — surface to user; they must switch via `git checkout -b chore/YYYY-MM-DD-ai-audit` before any edit.

---

## Phase 1 — Escalation audit (subagent)

Skip if `phase2` was requested. Runs on **either** surface — each has its own Learning Log, and the
subagent audits whichever repo it is pointed at.

Spawn the subagent in a clean context. The subagent reads `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` for full instructions and audits the Learning Log **union** — `ai-docs/learnings.md` plus every `ai-docs/learnings/*.md`, as one history.

```
Agent(subagent_type="general-purpose", prompt="
  Read ${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md and follow it exactly.
  The Learning Log is the UNION of ai-docs/learnings.md and ai-docs/learnings/*.md — audit both, never one alone.
  Working directory: <CLAUDE_PROJECT_DIR>
  Report back: (a) entries audited, (b) mismatches found, (c) contradictions found (rule present at target but another instruction file mandates the opposite — surfaced, never auto-fixed), (d) fixes applied, (e) entries that need user judgment.
")
```

After the subagent reports back:

1. Surface its summary to the user.
2. If the subagent left any entry as **needs user judgment** — present each and ask how to resolve.
3. If the subagent applied edits to `ai-docs/learnings.md`, to any `ai-docs/learnings/*.md`, or to other files, do **not** auto-commit yet — Phase 2 may add changes; bundle into one commit.
4. If the subagent emitted any `🌱 Stale-validation` flags, surface them to the user as a **signal for `/improve`** — NOT an auto-fix.

---

## Phase 2 — Instruction audit (main session)

Skip if `phase1` was requested.

**On the `project` surface, start here** — run the mechanical checks first, then apply only the applicable
letters (A, C, L, M, N) to the profile files:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/audit-project.sh <project-dir>
```

Output is `severity|check|message`, one per line; exit 1 means at least one blocker. Fold each line into
the findings table as-is — the script owns Q–U and has already done the work.

Two of those checks are **executed, not read** (`R` runs `command -v` on each recorded command; `U` asks
`git check-ignore` about a real probe file), because a command table naming a binary nobody has and an
ignore block that does not actually match both look perfectly correct on the page.

Steps 2.1–2.3 below describe the `global` surface. On `project`, skip the doc fetch (there are no skills
or agents here to conform) and go straight to Step 2.4.

### Step 2.1: Pull canonical Claude Code docs

Spawn the `claude-code-guide` Subagent via `Agent`:

```
Agent(subagent_type="claude-code-guide", prompt="
  Return the verbatim canonical shape contracts from these three Claude Code documentation pages:
  - https://code.claude.com/docs/en/skills           — skill frontmatter schema (required vs optional; allowed-tools shape; argument-hint; disable-model-invocation)
  - https://code.claude.com/docs/en/sub-agents       — Subagent file structure (frontmatter; body conventions)
  - https://code.claude.com/docs/en/hooks-guide      — Hook event names, matchers, JSON I/O contract, exit-code semantics

  For each page, extract the verbatim schema text. Cite the URL alongside each block.
")
```

### Step 2.2: Inventory the instruction surface

Read every file in:

- `AGENTS.md` and `CLAUDE.md`.
- `ai-docs/context.md`, `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`, `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`, `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md`, `ai-docs/learnings.md` + `ai-docs/learnings/*.md` (one union), `${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md`, `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md`, `${CLAUDE_PLUGIN_ROOT}/docs/agent-docs-index.md`, `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md`, `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md`, `${CLAUDE_PLUGIN_ROOT}/docs/considerations-link-reading.md`, `${CLAUDE_PLUGIN_ROOT}/docs/instruction-file-validation.md`.
- Any active `*.spec.md` / `*.design.md` under `ai-docs/plans/`.
- Every `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md`.
- Every `${CLAUDE_PLUGIN_ROOT}/agents/*.md`.
- Every `${CLAUDE_PLUGIN_ROOT}/rules/**/*.md`.
- `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`.

Do NOT read `.claude/settings.local.json` unless user explicitly authorises.

### Step 2.3: Run the checklist

For each violation: record file path, line number, the rule it conflicts with, the proposed fix.

| Letter | Purpose |
|---|---|
| A | Cross-reference integrity — every relative link + named Skill/Subagent resolves |
| B | Conflicting / duplicated rules — no contradictions; verbatim duplicates consolidated |
| C | Dead references — every sync-group member exists; `ai-docs/plans/done/` references resolve |
| D | Frontmatter conformance (skills) — `name` / `description` / `allowed-tools` shape per official docs |
| E | Frontmatter conformance (agents) — YAML block present; `name` == basename; `description` is one line |
| F | Hooks (`${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`) — event names, matchers, exit codes, env-var quoting |
| G | `propagation.md` coherence — sync groups intact; exemptions replicated everywhere |
| H | Documentation conformance pointers — `doc-convention.md` references resolve; section order matches |
| I | File-size & structure — a Subagent file > ~500 lines without sectioning; 40,000-char cap not crossed. **`SKILL.md` line count belongs to K**, which owns the soft target and the exemption index |
| J | Allow-list / permission consistency — `allowed-tools` covered by `permissions.allow`; no dead entries |
| K | Skill-directory layout — oversized SKILL.md, multi-consumer supporting files, inline-script extraction candidates |
| L | Learning-Log field coherence — every Entry-format field covered in all five mandatory locations; declared-enum fields (`Kind:`) additionally value-conformant across every log entry in the union (`ai-docs/learnings.md` + `ai-docs/learnings/*.md`) |
| M | `agent-writing-style.md` conformance — sub-checks (Patterns 1–7 + Anti-patterns + Cross-shape verbs) |
| N | Bidirectional `## Patterns` ↔ `Kind: validation` coherence — every promoted carrot round-trips both ways |
| O | Embedded-name clash scan — project-defined Tool / Subagent / Skill / Hook names MUST NOT clash with embedded names in `claude-tools-hierarchy.md` |
| P | Frontmatter / config improvement recommendations — diff each skill/agent/hook against the full documented Claude Code field set; recommend add/drop/normalize/resolve-asymmetry; emits a per-surface recommendation table |

**Project surface — letters Q–U**, produced mechanically by `scripts/audit-project.sh`:

| Letter | Purpose |
|---|---|
| Q | Profile completeness — no unresolved `%PLACEHOLDER%` left in `AGENTS.md` / `ai-docs/context.md` (`blocker`: an unresolved placeholder is a STOP, not a default) |
| R | Command liveness — the binary each `%*_CMD%` names exists on PATH or in the repo; a gate that cannot run is not a gate |
| S | Registry coherence — this path is registered, with a valid `scope` |
| T | Candidate hygiene — every `.promote/*.md` still passes the redaction gate; a refused candidate will silently never be swept |
| U | Gitignore coverage — `git check-ignore` confirms progress/state files are really ignored |

### Step 2.4: Categorise findings

- `blocker` — broken link, dead reference, frontmatter missing → instruction is unusable as written.
- `major` — contradicting rules, drifted exemption, hook with shell injection.
- `minor` — duplication, inconsistent style, unhelpful description.
- `nit` — wording, ordering, formatting.

Cap at 25 findings; if more, list the 25 most severe and note truncation.

### Step 2.5: Present + apply

Show user a numbered list of findings with proposed fixes:

- `blocker` / `major`: ask user to confirm before applying.
- `minor` / `nit`: may apply autonomously if mechanical and obvious; otherwise ask.

> **File-size sub-check (35,000–39,999 char band) is ACTIONABLE `minor`, not passive heads-up.** Recurring misclassification: large instruction files (e.g. AGENTS.md at ~36k chars) get tagged "Heads-up surfaced (no fix this pass)" and extraction is deferred. The early-warning band exists specifically to give one full `/task` cycle of headroom before the file crosses 40k. Treat the band as actionable: present an extraction plan (which verbose subsections move to which `ai-docs/<topic>.md` reference page, with anchored pointer left behind) and ask the user to approve per the `minor` rule above. Do NOT defer to "next `/ai-audit`" — that wastes the headroom.

Apply approved fixes via `Edit` / `Write`. Write a new entry to `ai-docs/learnings/<username>-<branch>.md` ([§ Target file](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md#target-file)) per AGENTS.md "Learning Log" format **only if** the audit revealed a *new* class of mistake worth tracking. New entries never go into the archive.

### Step 2.6: Verify

After edits:

1. Re-run any grep-based checks from Step 2.3 — confirm zero remaining. Use the same working-tree search the check specified; `git grep` without a revision reads the index, and with one reads a commit — neither sees this run's uncommitted fixes reliably.
2. If hooks were edited, eyeball JSON validity: `jq . ${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`.
3. If Subagent or Skill files were edited, confirm their frontmatter still parses by reading back.
4. **Cross-reference re-verification (anchor-aware).** For every relative link the audit touched, verify the path resolves AND any `#anchor` matches a real heading in the target file.

---

## Step 3: Commit (if changes were made)

> Per AGENTS.md, `git commit` is ASK-level for Claude. Prepare the staged file list + commit message, ask for explicit user approval, then run `git commit`. The `branch-protection` hook still blocks `git commit` on the default branch as a safety net.

If `ai-docs/learnings.md` or anything under `ai-docs/learnings/` was modified or newly created, ensure it's staged alongside other changes (`git add ai-docs/learnings.md` / `git add ai-docs/learnings` — the directory form is what catches a first-write untracked entry file).

---

## Gate checklist

| Before | Check |
|---|---|
| Phase 1 spawn | not on the default branch OR no edits planned? |
| Phase 1 done | subagent reported every `needs user judgment` item? |
| Phase 2 fetch | all three docs successfully fetched? |
| Phase 2 apply | `major` / `blocker` user-approved? |
| Commit | `jq .` passes on settings.json? frontmatter still valid? cross-references re-verified? |

## Anti-patterns

- Do **not** rewrite Learning Log history — `ai-docs/learnings.md` **and** every `ai-docs/learnings/*.md` are append-only. Phase 1 may only correct `Escalated?` / `Superseded by:` of an existing entry, on either surface, or add a *new* corrective entry (which goes to the per-branch file, never the archive).
- Do **not** invent rules. The audit finds compliance gaps in *existing* rules; new rules go through `/improve`.
- Do **not** skip the `claude-code-guide` spawn in Phase 2.
- Do **not** auto-resolve a blocker without surfacing.
- Do **not** edit `.claude/settings.local.json` — user-local.

---

**Reference:** [`reference.md`](reference.md) — detail body for every checklist letter (A–U), Step 2.6 sub-step 4 anchor-aware cross-reference recipe, Checklist M sub-checks, Checklist N forward / reverse coherence rules, Checklist O embedded-name clash recipe, Checklist P frontmatter/config improvement recipe, Checklists Q–U project-surface checks.
