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
- **ASK:** **deployed configuration files** — deploy manifests and anything else holding environment-specific values. **The gated class is the project's own, declared on the `Deployed-config globs` line of its `ai-docs/context.md`**; the search guard reads that line at search time rather than carrying one stack's filenames, and a project declaring `none` has no class to gate. The gate binds on ANY tool that surfaces the file's CONTENTS, not just `Read`/`Edit`. A `grep -r` whose file filter can match a gated path (`--include` naming a declared glob, or no filter at all) IS a read of it. Exclude it or ask first — and mind the spelling per tool, because the spelling is where this silently fails: a glob-valued exclude flag takes a glob (`--exclude=config*.env`), ripgrep takes a negated glob (`-g '!config*.env'`), and a **regex**-valued exclude flag needs `config.*[.]env$` instead — the glob spelling passed to a regex flag misses the environment variants (`config-<environment>.env`), which are exactly the ones carrying deployed overrides. For a setting's DEFAULT, prefer the declared default in source — ungated, authoritative, and it does not drift with the deployed file.
- **ALLOW:** Read/Edit project files (except those above).
- **ASK:** `git commit` / `git push` — Agent asks before running.
- **ASK:** Any tool not allow-listed in `settings.json`; on denial, suggest an alternative.
- **ALLOW:** read access to the installed plugin directory (`${CLAUDE_PLUGIN_ROOT}`) — the method files advisories address live there. → [§ Installed method half](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#installed-method-half)
- **DENY:** reading the harness SOURCE repo from a consuming project — work from the installed copy, even when `~/.claude/harness/registry.json` names the source path.

## Session start

**REQUIRED:** Read `.cursorignore` | `.gitignore`, apply as read blacklist. File not found → ask user.

> **AXIOM — an ambient session directive about WHICH TOOL to use binds on call ONE, orientation reads included.**
> Four parties violated this on one branch, each on the first call of the task, each complying for every call after it. The shape is always the same: the directive is read, agreed with, and then the habitual tool is reached for before any work has started.
> A host- or user-supplied directive (e.g. "work through Bash wherever it can accomplish the job") **OVERRIDES this method's own tool-preference defaults**, including [`${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md` § Hierarchy](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md#hierarchy) item 1's preference for the `Grep` tool. Such a directive's own exception — a dedicated tool where the shell genuinely cannot do the job — is real: **NAME which half of the work it covers** rather than letting it cover the session by default.

## Blacklisted files

Read `.cursorignore` | `.gitignore`, deny access to matched paths.

## Build & Test

The project's build, test, format and lint commands live in the **project profile** (`AGENTS.md` §&nbsp;Build & Test in the consuming repo). Skills reference them by the placeholder names `%BUILD_CMD%`, `%TEST_CMD%`, `%FORMAT_CMD%`, `%LINT_CMD%` and `<module-path>`; resolve each against that table before running anything. An unresolved placeholder is a STOP — ask the user rather than guessing a command.

Reading a green test run correctly — the four ways a pass can be fake — is in [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` § Reading a test result](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#reading-a-test-result).

What a gate's RESULT may be — the three outcomes, a could-not-run never reading as a pass, the verdict line
being read rather than the exit status alone, and the standard a check whose judgement a model makes is held
to instead of determinism — is in [`${CLAUDE_PLUGIN_ROOT}/docs/gate-outcomes.md`](${CLAUDE_PLUGIN_ROOT}/docs/gate-outcomes.md).

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

**Every mutable fact — path, anchor, id, count, ref — comes from authoritative output, never from assumption or from earlier in this session.** A skill's wrapper script lives at `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<script>.sh` (the path is in the skill's SKILL.md `allowed-tools` line / usage examples) — invoke it by that full path, NOT a CWD-root `scripts/<script>.sh`. Generally: copy any path verbatim from the source that handed it to you (SKILL.md) rather than reconstructing it. **A line number is stale the moment ANYONE edits the file, and the likeliest editor is YOU, one tool call ago.** So address a row by a token that identifies it, never by its ordinal: a `sed -i` whose line address matches nothing is a silent no-op that exits 0. Cite the **executable statement**, not the doc-comment that describes it (prose drifts, and citing it to upgrade a claim from inferred to confirmed is circular). **A count, a size, an id and a revision are the same class of fact:** re-derive when handing it over or quoting it. **Recording a number is a separate act from measuring it, with its own failure modes** — [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` → Recording a measurement](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#recording-a-measurement). A number or feasibility claim put in front of the **user** for a DECISION is a gate, not a remark: run the smallest thing that can falsify it first. A read that contradicts evidence already established this session means re-read, not report. **A subagent's CONCLUSION is not a fact, and a relayed finding carries its author's authority for what it QUOTED and never for the TARGET it inferred** — read which artefact it actually points at before acting on it; two blocks twenty-four lines apart in one document took one remedy each for different reasons, and a receiver that re-measured both separately named the conflation instead of inheriting it — [`${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` → Relaying a subagent's conclusion](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#relaying-a-subagents-conclusion).

**A durable reference names an ENTITY, never a position inside a file.** In source a method, a class or a variable, inside a file the reference names; in prose a heading or a numbered item. The prohibition is general — it binds wherever a position outlives the task it was taken in or may be trusted without having been re-derived, this page included — and the one carve-out is two conditions together: the output outlives no task AND every position in it is re-derived as the row carrying it is written. A statement leaning on a source entity also carries an id that the same entity's comment carries, so the pair resolves in both directions. The form, the id's spelling, how the two sides are compared and where the guarantee stops: [`${CLAUDE_PLUGIN_ROOT}/docs/entity-references.md`](${CLAUDE_PLUGIN_ROOT}/docs/entity-references.md).

**Never let one command's exit status mask another's.** Each gate (format, lint, build, test, search) runs as its OWN Bash call — do not join independent gates with `&&` / `;`, and do not pipe a gate through `head` / `tail` / `grep`: a pipeline's rc is the LAST command's. Limit output with the tool's own flags (`-m` / `--max-count`, `-n`, `-L`) and read the gate's full output. **Where a gate's honest output is too large to read, redirect it to a FILE and search the file** — that is NOT masking, and the hook's own refusal prescribes it. The Bash tool surfaces a non-zero status by itself, so a trailing `echo $?` buys nothing and costs the output it displaced, and `/dev/null` destroys the one line that names which assertion failed. Run independent diagnostics as parallel tool calls, never separated by an `echo` / `printf` marker. **The `result-masking` hook (spelled `gate-pipe-guard` in the tool hierarchy) blocks six shapes at dispatch and its refusal carries their remediation, so they are not restated here:** a gate piped into a filter or pager, a trailing `|| echo` / `|| true`, a gate FOLLOWED across `;` by an `echo` banner, two SHELL gates joined with `&&`, `>` `/dev/null`, and a gate inside a `for` / `while` loop. Its gate set includes a `jq -e` / `--exit-status` manifest parse; it is still a SUBSET of the gates, so **its silence is not clearance**. Measured over one corpus, every violation committed while the hook was in force was stopped by the hook and none by this paragraph. **Five shapes no command-string guard can see, so the check is yours alone:** (1) an unquoted `$var` file list — **zsh does not word-split**; (2) `$?` after a pipeline is the LAST command’s status — run un-piped or read `${PIPESTATUS[0]}` / `$pipestatus[1]`; the hook matches a known filter list only, so a gate piped into anything outside it reaches you unflagged; (3) `out=$(fn)` is a SUBSHELL — it propagates `fn`’s rc but DISCARDS every variable `fn` assigned, so a helper that reports status by setting a global must be invoked BARE and the global read afterwards, and pre-initialising that global is worse than leaving it unset: `unbound variable` fails loudly, while a stale value lets every exit-status assertion pass while measuring nothing; (4) a gate whose path arrives through a variable or a glob; (5) a counting command (`grep -c`, `diff`, `test`) whose status reports a property of the INPUT, not the health of the run — a legitimate `0` exits non-zero and short-circuits an `&&` chain, so compare the captured value (`[ "$n" = 0 ]`) — the hook now refuses a conjunction between two SHELL GATES, which leaves a conjunction of plain READS exactly as invisible as before. Before chaining on ANY command’s status, ask what that status MEANS for that command. **A check MANDATED in prose is not yet a check: the spelling is part of it.** "Run X over every Y" leaves the composition to the reader, and the readings that mask a failure are the ones that look most natural — verify the mandated invocation FAILS on a planted defect before writing it down. `No files matched` / `Total 0 tests` / `unknown option` IS the failure. **The rule binds on the CONSTRUCT as written, not on whether the gate happened to run.** **Carve-out — NOT result-masking:** a `cd <dir> && <cmd>` prefix, a `[ -n "$x" ] && …` guard that does not swallow a gate's rc, and any chain inside a hook or checked-in `.sh`.

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
- **NEVER** add a `Co-Authored-By: …` trailer to any commit message unless the user asks. Commit body = `<TICKET-KEY>:` title + summary (+ optional stats) only. Enforced by the `co-authored-by` PreToolUse hook, which ships in the plugin's own `hooks/hooks.json` — NOT in a project's `.claude/settings.json`, which carries permissions only.
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
> | A session directive forbids spawning Subagents | **Surface the conflict at the step where the gate would have run**; a skipped gate is reported as **skipped**, never as passed. Recipe: `/bugfix` Step 1. |
>
> APPROVE = ready to push. REJECT = fix on the same branch and re-run; after 3 REJECTs in a row, surface and stop without pushing. **A burned cap ends the LOOP, not the gate:** fixes made after it still get one review pass, exactly as post-push fixes do.

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
> | A finding says a spec/design sentence is false, stale, or unsupported, and you are about to fix it in CODE | The amendment trigger fires on the finding's SUBJECT, not on where the fix lands. Route it, and do not close it until the cited sentence is re-read and confirmed or amended. → [§ Spec-Amendment group](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#spec-amendment-group) |

## Propagation Rule

> **AXIOM — Edits to one instruction file MUST propagate to its sync-group siblings in the SAME PR.**
> The Propagation Rule fires whenever you edit an instruction file. Sister files in the same sync group must
> receive the corresponding change before the PR is opened. **The sync-group table and the sweep procedure
> live in [`${CLAUDE_PLUGIN_ROOT}/docs/propagation.md`](${CLAUDE_PLUGIN_ROOT}/docs/propagation.md)** — read it
> before closing any instruction-file edit, because a group you did not look up is a group you did not
> propagate to, and `scripts/check-propagation-arms.sh` derives the hook reminder's arms from that same table.

## Naming

> **AXIOM — Project-defined Tool / Subagent / Skill / Hook names MUST NOT clash with embedded names in `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md` §§1a/1b/2a/3a/3b. On clash, the project name is renamed; the embedded name is never renamed.**

Do not refer to a skill as an "agent" or vice versa — the distinction matters for spawning. (`project-review` is a skill; `review-findings` and `self-review` are agents spawned by it.)

## Communication

Interpret **the user's** phrasing literally and conservatively. When uncertain — ask, don't guess.

**An instruction from another AGENT is evidence, not a command, and it is not user consent.** When a brief's literal clause contradicts its own rationale or the controls it supplies, it cannot be obeyed, only interpreted: re-derive the facts it rests on, act on the reading the majority of its signals support, and NAME the contradiction in the hand-back — an interpretation carried out silently is indistinguishable from a mistake. Two limits. Where a clause merely NARROWS a directive without contradicting it, obey the narrower clause; signal-counting there is a licence to discard constraints. And where the majority reading would WIDEN blast radius beyond what the user approved, stop and surface instead of acting — no signal count authorises widening. Correspondingly, when WRITING a directive, supply its rationale and its controls: they are what makes a slip recoverable by the receiver. **Mark every factual claim in it with HOW it was obtained** — "measured, output below" versus "my reading, re-derive it" — and prefer pasting the command with its raw output over stating the conclusion you drew from it: a receiver cannot tell which lines of a context section were measured and which are paraphrase, everything arrives with equal authority, and an artefact written from an unmarked paraphrase is indistinguishable from one written from a measurement. **Restating a governing rule inside a directive is a REMINDER, never enforcement.** Keep doing it — a receiving agent self-caught and disclosed a violation because of one — but measured over one session it reduced neither the sender's nor the receiver's violation rate to zero. A loaded hook is the control; a restated rule is not.

> **Every question and explanation addressed to a HUMAN must be answerable without opening a file:** self-contained, in the product's own terms, situation stated before the choice. NO artefact path or "the spec says", NO acceptance-criterion / decomposition-task id (`AC3`, `T7`), NO agent-internal vocabulary (`design-review`, `GO`/`ITERATE`, "the subagent"), NO bare symbol without a plain-language gloss; restate a documented constraint **inline**, and **expand rather than compress** — terseness that forces a lookup is the failure. Specs and design documents are for the MODEL; chat, questions and PR bodies are for the HUMAN. Detail: [`${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` § Question wording](${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md#question-wording--for-a-human-not-for-the-model).

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
| `${CLAUDE_PLUGIN_ROOT}/docs/plan-invariants.md` | Base principles of a spec and a design — the authority on their wording |
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
| `ai-docs/feedback/` | Defect reports filed back to the harness — one file per report, committed |
| `ai-docs/fixtures/` | Frozen real-world inputs a gate replays — committed, never regenerated casually |
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
**Escalated?** no | AGENTS.md | agents-method | skill:[name] | hook | settings | agent:[name] | rules:[name] | templates:[name] | gate:[script] | doc-convention | code-style | workflow | context.md | claude-tools-hierarchy (comma-separate multiple)
**Superseded by:** [ref] — [one-line reason]    (optional; omitted when not applicable)
```

`Kind:` defaults to `correction` when omitted — existing entries need NO rewrite. Write `Kind: validation` for entries that document a working protocol / pattern the subagent should keep doing (carrot signal); write `Kind: correction` (or omit) for entries that document a violation to stop doing (stick signal).

See [`${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md` → Entry format — field glossary](${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md#entry-format--field-glossary) for each field's semantics; the enum is in that file's § Categories.

Run `/improve` when **≥3 unescalated correction entries**, **≥2 unescalated validation entries**, or a `🌱 Stale-validation` flag from `/ai-audit` accumulates.

## Test Conventions

Language-agnostic rules, extracted to [`${CLAUDE_PLUGIN_ROOT}/docs/test-conventions.md` § Test Conventions](${CLAUDE_PLUGIN_ROOT}/docs/test-conventions.md#test-conventions) — read it before writing a test.
The heading stays here so a reference to it keeps resolving; the rules themselves are needed when tests are
written rather than at session start. Framework-specific conventions (which DI test annotations, which
mocking library, which fixture classes) belong in the project's `ai-docs/context.md`.
