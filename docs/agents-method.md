# Agent Rules — method

> This file is the **method half** of the harness: rules that hold in every project. It ships with the
> `harness` plugin and is read at session start. The **profile half** — build commands, permissions,
> language, domain context — lives in the consuming project's own `AGENTS.md` and `ai-docs/context.md`.
> Where the two disagree about a project-specific fact, the project profile wins; where they disagree
> about method, this file wins.

**CRITICALLY**
1) English for all output. Other language only on explicit user request.
2) Minimise thinking output shown to user.

## Permissions

Machine-enforced rules live in `.claude/settings.json` (allow/deny entries). Read that file for the authoritative list — duplicating them here lets the two sources drift.

Honor-system rules (still binding):

- **DENY:** Edit files outside the project and outside `~/.claude`.
- **DENY:** Read/Edit `.env`, `secrets.json`, any credential store.
- **ASK:** **deployed configuration files** (`application*.properties`, `*.env.*`, deploy manifests, anything holding environment-specific values). The gate binds on ANY tool that surfaces the file's CONTENTS, not just `Read`/`Edit`. A `grep -r` whose file filter can match a gated path (`--include=*.properties`, or no filter at all) IS a read of it. Exclude it or ask first — and mind the spelling per tool: a glob filter (`--exclude=*.properties`) is not a regex filter (`-g '!*.properties'`), and a glob passed where a regex is expected silently misses profile variants (`application-<profile>.properties`) — the ones carrying deployed overrides. For a setting's DEFAULT, prefer the typed config binder class in source — ungated, authoritative, and it does not drift with the deployed file.
- **ALLOW:** Read/Edit project files (except those above).
- **ASK:** `git commit` / `git push` — Agent asks before running.
- **ASK:** Any tool not allow-listed in `settings.json`; on denial, suggest an alternative.

## Session start

**REQUIRED:** Read `.cursorignore` | `.gitignore`, apply as read blacklist. File not found → ask user.

## Blacklisted files

Read `.cursorignore` | `.gitignore`, deny access to matched paths.

## Build & Test

The project's build, test, format and lint commands live in the **project profile** (`AGENTS.md` §&nbsp;Build & Test in the consuming repo). Skills reference them by the placeholder names `%BUILD_CMD%`, `%TEST_CMD%`, `%FORMAT_CMD%`, `%LINT_CMD%` and `<module-path>`; resolve each against that table before running anything. An unresolved placeholder is a STOP — ask the user rather than guessing a command.

Reading a green test run correctly — the four ways a pass can be fake — is in [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § Reading a test result](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result).

> **AXIOM — Every instruction file Agent loads MUST stay below 40,000 chars.**
> Harness-enforced soft cap; crossing it imposes per-invocation cost on every subagent spawn, `/task`, and review pass. Project-side **35,000-char early warning** gives one full `/task` cycle of headroom before the harness warning fires.
> Applies to: `AGENTS.md`, `CLAUDE.md`, every `${CLAUDE_PLUGIN_ROOT}/skills/**/*.md`, every `${CLAUDE_PLUGIN_ROOT}/agents/**.md`, every `${CLAUDE_PLUGIN_ROOT}/rules/**/*.md`, every `${CLAUDE_PLUGIN_ROOT}/docs/*.md`, and the project's own `AGENTS.md` + `ai-docs/context.md`.
>
> | If `wc -c <file>` reports... | Action |
> |---|---|
> | ≥ 40,000 chars | **`major`** — plan extraction / dedup for the next `/ai-audit` pass; extract verbose subsections into `docs/<topic>.md` reference pages with anchored links. |
> | 35,000–39,999 chars | **`minor`** — proactive extraction pass; don't let the next `/task` push it over 40k. |
> | < 35,000 chars | OK. |
>
> Quick scan, from the harness repo: `wc -c AGENTS.md CLAUDE.md skills/**/*.md agents/*.md rules/*.md docs/*.md`.

## Search

Code-search hierarchy (which tool for which question, and the verbatim block subagents inherit): [`${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md`](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md).

## Tooling

**Every mutable fact — path, `file:line` anchor, id, count, ref — comes from authoritative output, never from assumption or from earlier in this session.** A skill's wrapper script lives at `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<script>.sh` (the path is in the skill's SKILL.md `allowed-tools` line / usage examples) — invoke it by that full path, NOT a CWD-root `scripts/<script>.sh`. Generally: copy any path verbatim from the source that handed it to you (SKILL.md) rather than reconstructing it. **A line anchor is the same class of fact:** never compute a post-edit line number by adding a delta to a pre-edit one — run `grep -n '<the actual token>' <file>` and cite what it prints, and verify a claimed net-zero/net-N hunk with diff. Cite the **executable statement**, not the doc-comment that describes it (prose drifts, and citing it to upgrade a claim from inferred to confirmed is circular). When handing a subagent an anchor that post-dates an edit, mark it "re-derive, do not trust". **A count, a size, an id and a revision are the same class of fact:** re-derive when handing it over or quoting it. A number or feasibility claim put in front of the **user** for a DECISION is a gate, not a remark: run the smallest thing that can falsify it first. A read that contradicts evidence already established this session means re-read, not report. **A subagent's CONCLUSION is not a fact, and a correct `file:line` certifies the QUOTE, not the inference drawn from it** — [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` → Relaying a subagent's conclusion](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#relaying-a-subagents-conclusion).

**Never let one command's exit status mask another's.** Each gate (format, lint, build, test, search) runs as its OWN Bash call — do not join independent gates with `&&` / `;`, and do not pipe a gate through `head` / `tail` / `grep`: a pipeline's rc is the LAST command's. Limit output with the tool's own flags (`-m` / `--max-count`, `-n`, `-L`) and read the gate's full output. Run independent diagnostics as parallel tool calls, never separated by an `echo` / `printf` marker. **Three further shapes mask a gate just as completely:** (1) a trailing `|| echo …` / `|| true` — probe a possibly-absent tool in a SEPARATE `command -v` call, then run the gate bare; (2) `$?` after a pipeline is the LAST command's status — run un-piped or read `${PIPESTATUS[0]}` / `$pipestatus[1]`; (3) an unquoted `$var` file list — **zsh does not word-split**. `No files matched` / `Total 0 tests` / `unknown option` IS the failure. **The rule binds on the CONSTRUCT as written, not on whether the gate happened to run.** **Carve-out — NOT result-masking:** a `cd <dir> && <cmd>` prefix, a `[ -n "$x" ] && …` guard that does not swallow a gate's rc, and any chain inside a hook or checked-in `.sh`.

**Capture tool-usage lessons in memory.** When you hit and resolve friction with a tool/skill (wrong output envelope, query dialect, flag, param shape, auth quirk), save the corrected usage to `~/.claude` memory as a `reference` memory so new sessions don't repeat the mistake. This cross-session `~/.claude` memory is distinct from `ai-docs/learnings.md` (the instruction-violation log): tool-usage know-how goes to memory, instruction violations go to the Learning Log.

### Skill-usage priority

When more than one installed skill can serve a task, pick the **highest tier that can do the job**. This is a tie-breaker for *ad-hoc* skill selection — it does **NOT** override a harness skill that already invokes a specific skill by name.

**Tiers** (format: **Tier #** — `skill/path` (short description)). Populate per project; a project that installs no extra skills leaves this empty and falls back to the built-in tools.

_(none yet)_

## Code Style

See [`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`](${CLAUDE_PLUGIN_ROOT}/docs/code-style.md) for the canonical reference (language profile, linter posture, magic numbers, file size, logging, error types, naming, comments).

- Per-language rules (which extension new files use, max line length, formatter/linter commands, source roots) live in [`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` § Language profile](${CLAUDE_PLUGIN_ROOT}/docs/code-style.md#language-profile) — fill it in once per project.
- Format changed files with `%FORMAT_CMD%`, then run `%LINT_CMD%` as the gate. The formatter is never the gate.

## Workflow

> **AXIOM 1 — NEVER edit on the local default branch (`main`) when work is intended for a PR.**
> Create a feature branch **before** any file edit — not before commit, **before edit**. "File edit" includes a `*.spec.md` / `*.design.md` / `*.state.md` / `ai-docs/learnings/<username>-<branch>.md` write, so the branch precedes `/interview`, not just the first source file.
>
> The first action of any skill that produces commits OR writes a planning artifact is checking the current branch; if it is the default branch, switch **before** any `Edit` / `Write`.

- Merges happen through the GitHub UI; Claude never merges. → [§ Merge strategy](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#merge-strategy)
- Run the changed module's build before commit so dependency-graph regressions surface locally. → [§ Build before commit](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#build-before-commit)
- Stage explicitly; **Never** `git add -A` / `git add .`. → [§ Explicit-file staging](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#explicit-file-staging)
- **Before every `git commit` during a PR task**, stage `ai-docs/learnings.md` **and** `ai-docs/learnings/` with related code. **After every push**, give a post-push learning entry its own commit. → [§ Staging learnings.md during PR commits](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#staging-ai-docslearningsmd-during-pr-commits)
- **NEVER** add a `Co-Authored-By: …` trailer to any commit message unless the user asks. Commit body = `<TICKET-KEY>:` title + summary (+ optional stats) only. Enforced by the `co-authored-by` PreToolUse hook (`.claude/settings.json`).
- Plan first. Tests before prod code (TDD). Format changed files, then lint as the gate. → [§ TDD + lint-changed-files](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#tdd--lint-changed-files)
- Files with ~50+ lines of substantial logic MUST have a sibling test file. → [§ Sibling-test rule](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#sibling-test-rule)
- **PR review comment resolution:** Resolve only comments fixed by code; objections stay open for the reviewer. → [§ PR review comment resolution](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-review-comment-resolution)

> **AXIOM 2 — Read the PR body after EVERY push to a feature branch with an open PR. Unconditional.**
> The READ is mandatory even when the push was a routine typo / format / nit. The EDIT is conditional — only when the body contradicts the new commits.
>
> | After... | Required action                                                                              |
> |---|----------------------------------------------------------------------------------------------|
> | User pushes to a feature branch with an open PR | Read PR body immediately (`gh pr view --json title,body`).                                   |
> | Body still describes the diff accurately | No edit needed.                                                                              |
> | Body contradicts new commits (renames, scope drift, AC flips, cited counts) | Edit the PR description to sync (`gh pr edit`).                                              |
> | Push immediately preceded (first push that opened the PR) | **Skip** the read — the body is what you just authored. The rule fires on the **next** push. |
>
> **AXIOM — Every code-producing commit on a feature branch with an open PR (or about-to-be-opened PR) must pass `self-review` before push.**
> The per-skill rules already exist (`/task` Step 10, `/bugfix` Step 6.5). This AXIOM names them as instances of a single workspace rule.
>
> | If the commit is... | Action |
> |---|---|
> | Initial implementation in `/task` | `/task` Step 10 — spawn `self-review`. |
> | Bugfix in `/bugfix` (standalone or detoured from `/task`) | `/bugfix` Step 6.5 — spawn `self-review`. |
> | Ad-hoc fix on a feature branch with an open PR (CI fix, reviewer nit) | Spawn `self-review` manually before push. → [§ Post-push fix commits](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#post-push-fix-commits-get-self-review-too) |
> | Docs-only / instruction-file-only commit (no source diff) | Self-review optional; still required if the diff touches any user-facing artefact. |
>
> APPROVE = ready to push. REJECT = fix on the same branch and re-run; after 3 REJECTs in a row, surface and stop without pushing.

> **AXIOM — The orchestrator NEVER writes to `*.spec.md` / `*.design.md` files directly. ALL writes are owned by the matching subagent (`spec-writer` / `design`).**
> Same root cause across multiple recurrences: orchestrator received the subagent's output as conversation text, didn't see the file on disk, and either transcribed the response manually OR edited the file in-place to apply user tweaks / amendment notes. Both shortcuts violate the subagent contract — `/interview` § Anti-patterns and `/task` reference both name this.
>
> | If you see... | Action |
> |---|---|
> | `design` subagent returned with the full design-doc text in its response, but `ls ai-docs/plans/*.design.md` is missing OR doesn't reflect the response | **STOP.** RE-RUN the `design` subagent (do NOT transcribe its text). The design subagent owns the `Write`. |
> | `spec-writer` returned `status: ready`, user picked "Tweak first", and you're tempted to `Edit` the spec | **STOP.** Append the Q&A to state's `prior_qa`, increment `round`, RE-INVOKE the spec-writer. The spec-writer owns the `Write`. |
> | Design Amendment recipe step says "update the design doc" | Spawn the `design` subagent with the amendment description. Orchestrator role: (1) surface to user, (2) spawn `design`, (3) spawn `design-review` on the result. NEVER `Edit` `*.design.md` inline — even for one-line fixes. |
> | Spec Amendment recipe step says "amend the spec" | Re-invoke `spec-writer` with the amendment in `prior_qa`; for `/task` Step 11 amendments, then run `design` → `design-review` chain. NEVER `Edit` `*.spec.md` inline. |
> | A reviewer comment on a PR proposes a one-line spec/design fix | The fix is NOT a "trivial edit" — it routes through the Spec / Design Amendment recipe. |

## Propagation Rule

> **AXIOM — Edits to one instruction file MUST propagate to its sync-group siblings in the SAME PR.**
> The Propagation Rule fires whenever you edit an instruction file. Sister files in the same sync group must receive the corresponding change before the PR is opened.
>
> | If you edit... | You MUST also check / update... |
> |---|---|
> | `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` | `${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` (Review group) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md` | `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` (Review group) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` | `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md` (Review group) |
> | `${CLAUDE_PLUGIN_ROOT}/skills/interview/SKILL.md` | `${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` (Interview group — pre-resolved-rule list mirrors live in `spec-writer.md`) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` | `${CLAUDE_PLUGIN_ROOT}/skills/interview/SKILL.md` (Interview group) |
> | `AGENTS.md` (rule add / exemption) | Run the [propagation sweep](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md#propagation-sweep) and apply the same change to every match. |
> | `AGENTS.md § Learning Log` (Boundary rules, entry format, `Kind:`, `Escalated?` semantics) | `${CLAUDE_PLUGIN_ROOT}/agents/self-improve.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` AND `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` AND `ai-docs/learnings/README.md` (Learning-Log group) |
> | `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` (design-phase / handoff contract) | `${CLAUDE_PLUGIN_ROOT}/agents/design.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` AND `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` (Task/Design group) |
> | `${CLAUDE_PLUGIN_ROOT}/agents/design.md` OR `${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` OR `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` | See *Task/Design group* anchor row above. |
> | `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` *Spec Amendment recipe* / *Design Amendment recipe* | `${CLAUDE_PLUGIN_ROOT}/skills/bugfix/SKILL.md` AND `${CLAUDE_PLUGIN_ROOT}/skills/project-review/SKILL.md` AND `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` AND `ai-docs/workflow.md § Spec-Amendment group` (Spec-Amendment group) |
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

> **AXIOM — Project-defined Tool / Subagent / Skill / Hook names MUST NOT clash with embedded names in `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md` §§1a/1b/2a/3a/3b. On clash, the project name is renamed; the embedded name is never renamed.**

Do not refer to a skill as an "agent" or vice versa — the distinction matters for spawning. (`project-review` is a skill; `review-findings` and `self-review` are agents spawned by it.)

## Communication

Interpret user phrasing literally and conservatively. When uncertain — ask, don't guess.

- **"Submit / push to PR"** = `git push` the branch to remote so commits appear in the open PR. **NOT** merge. Only merge when the user explicitly says "merge".
- **"wtf?" / "what?" / "huh?"** (or similar surprise/frustration) = the previous action was the opposite of what the user wanted. **Stop immediately**, do not retry, ask what was wrong before doing anything else.
- **IDE files** (`.idea/`, `*.iml`, `.vscode/`, `*.swp`) — never add, remove, modify, stage, or `.gitignore` them unless the user explicitly asks. They are the user's domain.

## Agent Docs

| Path | Purpose |
|------|---------|
| `ai-docs/context.md` | Project context — read on demand |
| `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` | Workspace code-style reference + language profile |
| `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` | Doc-comment convention |
| `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` | Extracted Workflow narrative + git/GitHub command map |
| `${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md` | Learning Log field glossary + boundary carve-outs |
| `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md` | Binary-rule writing style for dual-model readability |
| `${CLAUDE_PLUGIN_ROOT}/docs/agent-docs-index.md` | Verbose bodies of this `§ Agent Docs` table |
| `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md` | Embedded inventory; clash-detection source |
| `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md` | Audited list of `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` size exemptions |
| `${CLAUDE_PLUGIN_ROOT}/docs/considerations-link-reading.md` | Link-reading policy |
| `${CLAUDE_PLUGIN_ROOT}/docs/instruction-file-validation.md` | Dual-model instruction-file clarity test methodology |
| `${CLAUDE_PLUGIN_ROOT}/docs/plans-summary.md` | Cross-cutting maintenance plans |
| `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` | Canonical `.progress.md` schema |
| `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` | Canonical entry template + § Target file (where a new entry goes) |
| `ai-docs/plans/*.spec.md` | Active task spec + acceptance criteria |
| `ai-docs/plans/*.design.md` | Active task design documents |
| `ai-docs/plans/*.progress.md` | Active task progress / handoff state — local-only (gitignored) |
| `ai-docs/plans/done/` | Completed plans (spec + design) |
| `ai-docs/plans/deferred/` | Blocked or future plans |
| `ai-docs/bugfix/trace-*.md` | Bugfix trace + durable-state surface — deleted on resolution |
| `ai-docs/learnings.md` | Corrections log ARCHIVE — history + `/improve` fold destination |
| `ai-docs/learnings/` | Per-branch entry files — where NEW entries go; union with the archive |
| `${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md` | On-demand code-search hierarchy + verbatim block subagents inherit |

See [`${CLAUDE_PLUGIN_ROOT}/docs/agent-docs-index.md`](${CLAUDE_PLUGIN_ROOT}/docs/agent-docs-index.md) for the verbose body of each row (writers, lifecycle, special cases).

## Learning Log

On **ANY** instruction violation, write a new entry to `ai-docs/learnings/<username>-<branch>.md` ([§ Target file](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md#target-file)), never to the archive — there is no "obvious", "minor", "trivial", "already-known", or "duplicate" disposition. The history (including recurrences and superseded entries) is the artefact `/improve` audits to decide escalation fan-out. See [`${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md` → FORBIDDEN skip-reasons](${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md#forbidden-reasoning-for-skipping-a-learningsmd-write) for the enumerated skip-reasons.

**For the entry format, default to reading [`${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md)** — not the tail of the log. Reserve the log itself (the union: `ai-docs/learnings.md` + `ai-docs/learnings/*.md`, one history) for its CONTENT (recurrence / dedup / escalation audit).

**Read the two boundary rules below before you write — both have been violated multiple times.**

### Boundary rule 1 — the Learning Log is APPEND-ONLY, on BOTH surfaces

> **NEVER** edit, rewrite, reorder, summarise, or delete an existing entry in `ai-docs/learnings.md` or any `ai-docs/learnings/*.md` — append only; a supersession, a correction, or a tidy-up is a NEW entry, never an edit. `/improve`'s fold is an AUTHORISED append + source deletion, not a violation (contract: `ai-docs/learnings/README.md` in the project).
>
> **Exception — `Escalated?` and `Superseded by:` fields, subagent-driven only.** Both fields MAY be updated in-place, on either surface, by the `self-improve` Subagent (`/improve`) and the `learnings-escalation-audit` Subagent (`/ai-audit` Phase 1) — [per-Subagent contract](${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md#exception). All other lines remain immutable.

### Boundary rule 2 — a Learning Log write triggers NO other rule-file edits in the same turn

> When you write an entry — to `ai-docs/learnings/<username>-<branch>.md` or to `ai-docs/learnings.md` — you **MUST NOT** also edit, in the same conversation turn: `AGENTS.md`, `CLAUDE.md`, `${CLAUDE_PLUGIN_ROOT}/skills/**`, `${CLAUDE_PLUGIN_ROOT}/agents/**`, `.claude/settings.json`, `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`, `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`.
>
> Writing a learning entry is **NOT** authorisation to escalate into instruction files. Set `Escalated? no` and stop. Project-level escalation happens only when the user runs `/improve` (which spawns `self-improve`), or explicitly asks ("escalate this", "update AGENTS.md").
>
> **Exception — `/improve` and `/ai-audit`.** Those two workflows MAY update `Escalated?` / `Superseded by:` in place, on either surface, alongside instruction-file edits — **existing entries ONLY**; a NEW entry still cannot be appended in the same turn. [Contract](${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md#exception--improve-and-ai-audit-workflows).
>
> **Exception — in-flow capture during `/task` Steps 8–12** (incl. sub-skills `/bugfix`, `/context-reset`). A NEW entry MAY be appended to the branch's file alongside an instruction-file edit when it documents an in-task insight and is marked `Escalated? no`. [Conditions](${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md#exception--in-flow-learning-capture-during-task-steps-812).

### Entry format

```
### YYYY-MM-DD — [category] — [short description]
**What happened:** [quote or paraphrase]
**Rule:** [what to do instead, or what to keep doing]
**Kind:** correction | validation    (optional; defaults to `correction` when omitted)
**Escalated?** no | AGENTS.md | skill:[name] | hook | settings | agent:[name] | rules:[name] | templates:[name] | doc-convention | code-style | workflow | context.md | claude-tools-hierarchy (comma-separate multiple)
**Superseded by:** [ref] — [one-line reason]    (optional; omitted when not applicable)
```

`Kind:` defaults to `correction` when omitted — existing entries need NO rewrite. Write `Kind: validation` for entries that document a working protocol / pattern the subagent should keep doing (carrot signal); write `Kind: correction` (or omit) for entries that document a violation to stop doing (stick signal).

See [`${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md` → Entry format — field glossary](${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md#entry-format--field-glossary) for each field's semantics; the enum is in that file's § Categories.

Run `/improve` when **≥3 unescalated correction entries**, **≥2 unescalated validation entries**, or a `🌱 Stale-validation` flag from `/ai-audit` accumulates.

## Test Conventions

Language-agnostic rules. Framework-specific conventions (which DI test annotations, which mocking library, which fixture classes) belong in the project's `ai-docs/context.md`.

- **No nested test classes.** When scenarios need different context configuration, split into SEPARATE TOP-LEVEL classes (one per setup) — nested ids become `Class$Inner`, which breaks test-filter expressions.
- Test config mirrors prod.
- A mock the test never stubs or verifies belongs in the class-level mock declaration list, not a standalone field. Reserve the field form for mocks the test actually stubs or verifies.
- Prefer the mocking library's declarative stubbing form over the imperative one.
- Use matchers on **all** args of a stubbed call, never a raw+matcher mix.
- Prefer expressive matcher assertions; bare `assertEquals` / `assertTrue` at last resort only.
- Inline single-use vars. Merge assertions via value-type equality rather than field-by-field checks.
- Use the project's shared test fixtures; no domain mocks where a fixture exists.
- No trivial delegate-to-DAO tests.
- Default to BDD `should …` test names — `should <observable behaviour> [when <condition>]` — one meaningful user/system-as-user scenario per test. Arrange/act/assert as blank-line-separated blocks, NOT `// given` / `// when` / `// then` marker comments.
- Test behaviour, transitions, errors, edges.
- No `@Suppress` / `@SuppressWarnings` / equivalent unless unavoidable.
