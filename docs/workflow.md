# Workflow narrative

Extracted detail referenced from `AGENTS.md § Workflow` AXIOMs.

VCS for this harness is **git**; the review surface is a **GitHub PR** driven through `gh`. The default
branch is called `main` throughout; if the project uses another name (`master`, `develop`), substitute it
everywhere — the rules bind on *the default branch*, not on the literal string.

## Merge strategy

PRs are merged by a human through the GitHub UI (or by the repo's merge queue); **Claude never merges**.
After the merge lands, `/pr-merged` cleans up the local branch and its progress files.

## Build before commit

Before every commit, run the project build gate (`%BUILD_CMD%`, AGENTS.md § Build & Test) over the changed
module so dependency-graph regressions surface locally rather than in CI.

A module-scoped build compiles only that module — it does **not** catch every downstream regression. When
the diff changes a **public API signature** or a **constructor dependency of an injected component**, also
build/test-compile the modules that depend on the changed symbol: find them first
(`grep -rn "<ChangedSymbol>" --include='*.<ext>' .`), then run their test compile. A DI-container test in
another module can break at context load without ever naming the new type.

## Explicit-file staging

> **Never** `git add -A` / `git add .` / `git add -u` / `git add **`.

Stage by name. Why: a breadth-add sweeps in `.env`, secrets, IDE files, and generated artefacts that
`.gitignore` does not cover.

**Carve-out — a NAMED directory is not one of the banned forms.** The ban lists exactly the unbounded
forms, and its rationale is unbounded breadth. `git add ai-docs/learnings` names one directory whose entire
contents are, by construction, the Learning Log entries this PR is required to carry — none of the
rationale reaches it. The `auto-stage-learnings` hook uses that form deliberately, because a per-branch
entry file is **untracked on first write** and no per-file spelling can name a file the hook may not
derive. Do not flag it as a breadth violation.

Copy the paths to stage **verbatim from `git status --porcelain` output** — never reconstruct them from
memory or from an absolute path.

## Staging `ai-docs/learnings.md` during PR commits

(The heading names the archive because its slug is a live link target from `AGENTS.md`; the rule below
binds on the whole Learning Log — `ai-docs/learnings.md` **and** `ai-docs/learnings/*.md`.)

Before every `git commit` during a PR task, check `git status` for `ai-docs/learnings.md` **and** for
`ai-docs/learnings/`. If either is modified or untracked, stage it together with the related code changes —
learnings are part of the task deliverable and must be visible in the PR diff. New entries go to the
per-branch file ([§ Target file](templates/learnings-entry-format.md#target-file)), which is **untracked on
first write**, so stage the named directory: `git add ai-docs/learnings` (see § Explicit-file staging for
why that is not a breadth violation). Hook `auto-stage-learnings` enforces both on `git commit`.

After every push (reviewer-comment fix, self-review fix, CI fix): if a learning entry was written *after*
the last code commit landed, give it its own commit on the feature branch in the same turn — do not leave
the entry file as an unstaged working-tree change waiting to be bundled with the next code change. Order:
write learning → `git add ai-docs/learnings` (and `git add ai-docs/learnings.md` if the archive itself
changed, e.g. an `/improve` fold) → `git commit` (Claude asks first) → push.

## No `--no-verify`

Never `git commit --no-verify` / `git push --no-verify` or any hook-skip flag. If a hook fails, fix the
hook. Pre-commit hooks exist precisely so the bypass route does not become the default.

## Post-push fix commits get self-review too

Every code-producing commit on a feature branch with an open PR — including one-liner CI fixes and
reviewer-nit fixes — passes `self-review` before push. The bar is the same as a `/task` commit:
`self-review` APPROVE, or 3 REJECTs then stop and surface.

| Step | Gate |
|---|---|
| Step 0 — identify the failing check / the reviewer thread | `gh pr checks` / `gh pr view --comments` names it |
| Step 1 — open progress section | `## Fix cycle round M` appended to the active progress file |
| Step 2 — classify | class ∈ {`lint` / `build` / `test` / `flake` / `other`} |
| Step 3 — reproduce locally | run the mapped local reproducer; on no-reproduce, STOP and surface |
| Step 4 — diagnose + fix | inline-fix classes apply edits; a real defect routes to `/bugfix` |
| Step 5 — `self-review` | APPROVE or REJECT (loop cap 3) |
| Step 6 — commit | gates green; single commit per invocation |
| Step 7 — user pushes; AXIOM 2 PR-body sync | re-read the PR body via `gh pr view` after every push |

## TDD + lint-changed-files

Plan first. Tests before prod code. Lint changed sources before staging: run the project formatter
(`%FORMAT_CMD%`) to fix what is auto-fixable, **then** the linter as a gate (`%LINT_CMD%`) — a formatter
exits 0 even when non-auto-fixable violations remain, so it is not the gate. A `PostToolUse` hook may
auto-format on `Edit`/`Write`, but the commit flow does not re-run the linter; staged files must be linted
before staging.

## Reading a test result

Extracted from `AGENTS.md § Build & Test`, which links here. The command table stays in AGENTS.md; this
section carries the "is that green real?" detail.

> **Green means FOUR things, and the exit code is not one of them.** Parse the output, not `$?`:
> (1) the runner reports a **non-zero number of executed tests** — "0 tests" / "no tests found" is the
> quietest false green there is, because there is no failure line to read; (2) no suite was **skipped** for
> a tag/size/profile reason you did not intend; (3) no suite failed to **build** (a build failure often
> reports as "skipped", not "failed"); (4) the summary line itself says OK/PASS, and no `ERROR` /
> `INTERNAL` line appears anywhere above it — an infrastructure error means the suite never executed,
> whatever the summary says.
>
> **A filter that matches nothing reports success.** Before trusting a filtered run as evidence, prove the
> runner SELECTED the tests: match the reported count against a counted number of test methods (three
> `@Test`s in the file → `OK: 3`). A dry-run/list flag is weaker evidence than a real filtered run — list
> modes fail in their own ways, and a list that errors can still exit 0.
>
> **A positive control must exercise the exact command shape it licenses.** Proving that a wildcard filter
> returns rows says nothing about whether the exact-name form does.
>
> **A silent tool is a hypothesis, not a finding.** Zero output means the command did not do what you
> assumed; the next step is to make it speak, not to infer a cause from the silence.
>
> **"The tooling is broken" is the most expensive diagnosis available and needs the strongest evidence, not
> the weakest.** It converts every behavioural AC into "verify in CI", so it is a feasibility claim put to
> the user for a decision — AGENTS.md § Tooling already requires running the smallest thing that can
> falsify such a claim first. Three cheap checks that get skipped: (a) read the tool's own `--help` before
> concluding it cannot work; (b) an internal-error message is the tool reporting a fault in its OWN
> plumbing — under-specified, not terminal, and often fixable by a caller-side flag; (c) reproducing the
> symptom on an unrelated module widens the blast radius but is **silent about the cause** — it cannot
> distinguish "the environment cannot run tests" from "every invocation shares one wrong flag". Vary ONE
> flag per run and complete the control matrix BEFORE a cause goes into a durable artefact.
>
> **Piping the output deletes the evidence.** Skip/selection lines often do not exist in piped or
> machine-readable modes, so a criterion above has nothing to match and cannot fire. Do not pipe a gate
> (AGENTS.md § Tooling).

## Relaying a subagent's conclusion

Linked from [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling`](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#tooling)
— the METHOD file, not the project's `AGENTS.md`, which has no such section. Governs what the orchestrator
says to the **user** about work a Subagent returned.

> **A subagent's HEADLINE conclusion earns LESS trust than its incidental facts, not more** — it is the
> part most shaped by wanting a result. The signal to watch for is a conclusion that arrives pre-labelled
> as "the finding", especially one that makes the work look more valuable than expected. Before relaying
> one as fact, either (a) cheaply falsify it against a constraint already known to be in the same document,
> or (b) relay it explicitly as unverified: *"the subagent concludes X; the reviewer is checking whether Y
> breaks it."* Appending "a reviewer is verifying" to a confidently-stated claim does NOT make it
> provisional in the reader's mind.
>
> **CARVE-OUT — counts, sizes, ids and revisions are outside this ranking entirely; re-derive them wherever
> they appear.** [§ Tooling](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#tooling) puts them in a class of their own, and without this clause the
> ranking above actively argues the wrong way: a number dropped in passing is *incidental*, therefore on
> the trusted side. The shape that gets through is exactly that — a subagent mentions "11 containers, one
> per test" as an aside rather than as its finding, so it reads as the part the ranking says to trust. The
> real figure was 12, and 15 after later work; it reached the user as fact. **Both worked examples in this
> section are inferences** — a coverage claim, a mutation claim — so a bare integer does not resemble the
> thing being warned about, which is why it slips past a reader who has understood the section correctly.
>
> **A correct `file:line` citation certifies the QUOTE, not the INFERENCE drawn from it.** The project's
> anchor discipline catches fabricated references; by construction it cannot catch sound-looking reasoning
> over real ones — only execution catches that. Before relaying a coverage claim ("test X catches mutation
> Y"), either run the mutation or label the claim as unverified inference. **This applies with extra force
> when relaying a subagent's conclusion: inheriting a claim does not transfer its verification.**

## Git + GitHub command map

| Purpose | Command | Notes |
|---|---|---|
| Create the feature branch | `git checkout -b <TICKET-KEY>-<slug> main` | Branch off the default branch explicitly so it does not inherit another branch's commits. |
| Current branch | `git branch --show-current` | |
| Park uncommitted work | `git stash` / `git stash pop` | |
| Working-tree state | `git status --porcelain` | Copy paths verbatim from here when staging. |
| Uncommitted diff vs base | `git diff main` | The ONLY form that shows uncommitted working-tree changes. |
| Committed diff vs base | `git diff main...HEAD` | Commit-to-commit — returns EMPTY on a branch with no commits yet, so a gate built on it false-passes pre-commit. Check with `git log main..HEAD --oneline` first. |
| Current revision | `git rev-parse HEAD` | |
| Rewind the default branch | `git reset --soft origin/main` | Never `--hard`; always preserve uncommitted work. |
| Delete a merged branch | `git branch -d <branch>` | Refuses to delete unmerged. |
| Commit | `git commit` | **ASK-level for Claude** — Claude asks before running. Blocked on the default branch by the `branch-protection` hook. |
| Push | `git push -u origin <branch>` | **ASK-level for Claude** — Claude asks before running. Blocked on the default branch by the `branch-protection` hook. |
| Stage everything | `git add -A` / `git add .` | **FORBIDDEN** — see § Explicit-file staging. |
| Open a PR | `gh pr create --title … --body …` | **ASK-level for Claude.** Never `--fill` blindly; never auto-merge. |
| Read a PR | `gh pr view --json title,body,state,url` / `gh pr view --comments` | The AXIOM-2 post-push read. |
| Edit a PR | `gh pr edit --title … --body …` | The AXIOM-2 sync action. |
| CI status | `gh pr checks` | |

### Recovery from accidental edits on the default branch

If `git branch --show-current` reports `main` AND you have already edited files:

```bash
git stash
git checkout -b <TICKET-KEY>-<slug>
git stash pop
```

If you have also already committed on `main` (and not pushed):

```bash
git stash                                   # save uncommitted work
git checkout -b <TICKET-KEY>-<slug>         # branch carries the commits
git checkout main
git reset --soft origin/main                # rewind main
git restore --staged .                      # unstage
git checkout <TICKET-KEY>-<slug>
git stash pop                               # resume on the feature branch
```

Never `git reset --hard`. Always preserve uncommitted work.

## Hook false-positive guard — body content matching ANY PreToolUse Bash regex

**This applies to every `PreToolUse(Bash)` hook, not just `branch-protection`:** each one matches the
literal `tool_input.command` STRING, so any prose passed through Bash (heredoc, `printf`, `echo`) is
scanned as if it were code. A learning entry documenting a hook-blocked command can itself be blocked by
that hook for quoting the command in its `**What happened:**` narrative.

**Prefer the `Edit` / `Write` tools for any content that quotes a forbidden construct** — they are not
subject to the Bash command regexes — and reserve Bash for actually running commands. A Bash-command regex
cannot be made prose-safe, so this is a cost of the hook design, not a bug to fix; the workaround belongs in
the agent's habits.

When a body would contain a matched substring, write it to a file first and pass the file:

```bash
# bad — heredoc body matches the hook regex
gh pr edit 42 --body "$(cat <<'EOF'
... git commit on main is forbidden ...
EOF
)"

# good — body bytes never appear on the command line
#   Write /tmp/pr-42-body.md "<body text>"
gh pr edit 42 --body-file /tmp/pr-42-body.md && rm /tmp/pr-42-body.md
```

Do NOT try to escape or transform the text to slip past the regex — the hook is a safety net; the
workaround keeps the net intact.

## PR review comment resolution

Resolve only comments fixed by code; objections stay open for the reviewer.

| Category | Reply | Resolve? |
|---|---|---|
| `fix` | "Addressed in <commit-hash>: <one-liner>" | YES |
| `already-fixed` | "Already addressed in <commit-hash>: <one-liner>" | YES |
| `objection` | Rationale | NO — leave for reviewer |
| `clarify` | Ask the clarifying question | NO |
| `defer` | "Tracked as <TICKET-KEY> for follow-up" | YES if uncontroversial; NO if contested |
| `ignore-bot` | (no action) | — |

## PR body sync after every push

Per AGENTS.md `## Workflow` AXIOM 2: after every push to a feature branch with an open PR, read the PR body
(`gh pr view --json title,body`). Edit only if the body contradicts the new commits (`gh pr edit`).

| After... | Required action |
|---|---|
| User pushes to a feature branch with an open PR | Read the PR body immediately. |
| Body still describes the diff accurately | No edit needed. |
| Body contradicts new commits (scope drift, AC flips, cited counts) | `gh pr edit --title/--body` to sync. |
| Push immediately preceded `gh pr create` (first push that opened the PR) | Skip the read — the body is what was just authored. The rule fires on the next push. |

## PR title + body shape

- **PR title:** `<TICKET-KEY>: <conventional-commits header>` when the project uses ticket keys
  (e.g. `PROJ-123: feat(api): add label endpoint`); a bare conventional-commits header otherwise.
- **PR body:** summary paragraph(s) ONLY — what changed and why, ≤3 bullets. Markdown renders, so bullets
  and inline code are fine; the constraint is *content* (summary-only), not plain text. **NEVER** add
  `## Summary` / `## Test plan` section headers, test-count or stats lines ("N tests green", "all ACs
  PASS"), or `Co-Authored-By:` trailers (unless the user explicitly asks).
- **Size the description to a merge commit message** — it usually becomes one. Measurement tables, tool
  provenance, version pins and verification transcripts belong in the review thread or the progress file;
  neither ships. The test to apply before saving: *would this sentence still be worth reading in `git log`
  in six months?* A constraint a future editor must not violate passes; evidence that a past check
  succeeded does not.
- **Keep a small, self-contained PR to the files the user asked to change.** Workflow artefacts
  (`*.spec.md` / `*.design.md`, even once moved to `ai-docs/plans/done/`) go in only when the user asks or
  they carry lasting engineering value.
- **In a tracker-integrated repo, writing an identifier is an ACTION, not a reference.** A bare ticket key
  in a PR title/body can create a remote link and transition that ticket's status. Correct for the ticket
  the PR implements; wrong for subtasks, follow-ups, and context tickets cited for background — wrap those
  in backticks, or describe them in prose. Before naming ANY external id in a shared artefact, ask what the
  integration does on match.
- **The commit message body and the PR description are NOT interchangeable.** The commit body (visible via
  `git log`) MAY carry full detail; the PR description stays summary-shaped.

## Markdown link tracing after generate/move

After generating or moving a markdown file with relative links, trace one link via `realpath` before
staging. Catches the common mistake where a moved file's `../foo` link no longer resolves.

## Spec-Amendment group

When a fix diff touches `ai-docs/plans/*.spec.md` or `ai-docs/plans/done/*.spec.md`, that is a Spec
Amendment trigger — NOT an ordinary code-fix.

| Fires in skill | At step |
|---|---|
| `/task` | Step 11 (review fixes) |
| `/bugfix` | Step 5 (fix) |
| `/project-review` | fix loop |

Recipe: stop the step, surface to user for approval, re-invoke `spec-writer` to update the spec, re-run
`/task` Step 6 (design) → Step 7 (design-review) on the amended (spec, design) pair (max 3 rounds), then
resume the triggering step from the GO verdict.

Detection: mechanical at the top of every fix round — `git diff` includes a `*.spec.md` path → the trigger
fires regardless of how small the doc edit appears.

## Sibling-test rule

Every production source file with ≥50 lines of non-trivial logic should have a corresponding test file in
the project's test source root, mapped one-to-one by package/module + name
(`<SourceName>` → `<SourceName>Test`). The mapping, source roots, and file extensions are project-specific;
record them in `ai-docs/context.md` so the rule is checkable.
