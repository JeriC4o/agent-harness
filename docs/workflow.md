# Workflow narrative

Extracted detail referenced from `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Workflow` AXIOMs.

VCS for this harness is **git**; the review surface is a **GitHub PR** driven through `gh`. The default
branch is called `main` throughout; if the project uses another name (`master`, `develop`), substitute it
everywhere — the rules bind on *the default branch*, not on the literal string.

## Installed method half

Reasoning behind the two `§ Permissions` entries that govern where method rules are read from.

A hook's advisory names a method file by its resolved absolute path inside the installed plugin
directory. That address is actionable only if the agent may open it, so the directory is read-allowed and
the scaffolded `.claude/settings.json` carries a matching `Read(...)` allow entry.

**That entry is a GLOB over the install cache, never a version-pinned path.** The cache gives each
installed version its own directory and keeps the earlier ones, so a pinned entry grants access to
whichever copy was current when it was written and denies the one the next upgrade installs. The denial
surfaces as an unreadable method file — an advisory that still prints an address and still cannot be
followed — rather than as anything a reader would connect back to a permission entry.

**The source repository and the installed copy are different things, and only the installed copy is
authoritative for a consuming project.** The harness registry records where the source tree lives, so its
path is knowable from inside any project; reading method rules from there means reading uncommitted,
half-edited or branch-local instructions that the project never installed, and reading them *as though*
they were the rules in force. An installed copy is the build artefact of a released version, which is
precisely what makes it the right thing to read. Changing method rules is a release, not an edit.

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
> the user for a decision — ${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling already requires running the smallest thing that can
> falsify such a claim first. Three cheap checks that get skipped: (a) read the tool's own `--help` before
> concluding it cannot work; (b) an internal-error message is the tool reporting a fault in its OWN
> plumbing — under-specified, not terminal, and often fixable by a caller-side flag; (c) reproducing the
> symptom on an unrelated module widens the blast radius but is **silent about the cause** — it cannot
> distinguish "the environment cannot run tests" from "every invocation shares one wrong flag". Vary ONE
> flag per run and complete the control matrix BEFORE a cause goes into a durable artefact.
>
> **Piping the output deletes the evidence.** Skip/selection lines often do not exist in piped or
> machine-readable modes, so a criterion above has nothing to match and cannot fire. Do not pipe a gate's OUTPUT into a filter or a
> pager; a pipeline that FEEDS a gate, with the gate last and nothing filtering what it prints, is fine
> and is sometimes the only correct form (${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling).

## Recording a measurement

Linked from [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Tooling`](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#tooling).

**A measurement and the sentence that records it are two artefacts, and taking the first does not verify
the second.** Re-run the measurement against the pattern in its FINAL written form after every edit to
that pattern — editing a pattern invalidates every number taken before the edit, including one taken
minutes earlier — and prefer making the recorded and executed pattern the same string by extracting it
from the document and running that. Record the ENUMERATION of matches (`grep -rnoE`, the list of failing
assertion names), and never a count IN PLACE OF it — a count may ride alongside, with its scope and
unit, but it may not be the whole claim: a count answers "can this fire", an enumeration answers "which
surfaces does it police", and an enumeration cannot be right about the aggregate and wrong about a
member. State the SCOPE and the UNIT beside every figure — two counts of things with the same name are
not comparable, and a correction offered without its scope reads as a contradiction when it is a
different question. A status marker (`DONE`, `complete`, "all gates green") is a measurement: answer it
from the tree at the moment it is written and paste the result beside it, never from the instruction that
requested the work. And before writing any figure down, ask whether TAKING it perturbs what it
measures — a count over a surface the act of measuring writes to is not reproducible even in principle,
so record the invariant that holds at any N instead.

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
> **Two shapes the carve-out does not name, both recorded.** (1) **When your OWN output already contains
> the number, the brief takes it from your output and from nowhere else** — a hand-back is not a shortcut
> to a value you already hold. A figure phrased as a measurement inside a hand-back is indistinguishable,
> in summarising-reading mode, from one you measured; the countermeasure is positional, not attentional —
> scroll to the tool result that produced it and copy from there. (2) **A relayed claim is MORE dangerous
> inside a careful brief than a sloppy one**, because a brief that separates "measured, output below" from
> "my reading, re-derive it" makes an UNMARKED sentence read as measured. And the claim you check least is
> *good news about work you just authorised*, which is the class to check most.
>
> **A correct `file:line` citation certifies the QUOTE, not the INFERENCE drawn from it.** The project's
> anchor discipline catches fabricated references; by construction it cannot catch sound-looking reasoning
> over real ones — only execution catches that. Before relaying a coverage claim ("test X catches mutation
> Y"), either run the mutation or label the claim as unverified inference. **This applies with extra force
> when relaying a subagent's conclusion: inheriting a claim does not transfer its verification.**
>
> **Prose about a guard is a claim about the guard, at the same evidentiary level as a comment asserting
> an invariant — never a substitute for having seen the guard fail.** Before accepting that a guard set is
> complete, read what the GATE STUBS: whatever is stubbed is exactly what has never run under test, and it
> is usually the thing the prose is most confident about. A file that calls itself the full contract for a
> mechanism earns a re-read against that mechanism every time the mechanism changes — the claim of
> completeness is what makes a gap a defect rather than a summary, and when such a file also ships as a
> template, the gap reaches consumers who cannot see the implementation it describes.

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

**Content that quotes a forbidden construct MUST go in through the `Edit` / `Write` tools** — they are not
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

**A reply is read by a human reviewer** — self-contained, in the product's own terms: **never** cite a `*.spec.md` / `*.design.md` or an acceptance-criterion / decomposition-task id at a reviewer; restate the reasoning inline ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)).

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

The trigger has **two independent arms**, and the second is the one that is easy to leave out:

- **Arm A — subject.** The finding asserts that something a `*.spec.md` / `*.design.md` states is false,
  stale, or unsupported. Test: *would closing this finding leave a sentence in the artefact untrue?*
  Fires **regardless of where the fix lands**.
- **Arm B — target.** The fix diff touches `ai-docs/plans/**/*.{spec,design}.md`.

Either arm is a Spec/Design Amendment trigger — NOT an ordinary code-fix.

**Arm B alone is not enough, and the gap is structural.** A diff-keyed rule hands the routing decision to
the same party that then marks the finding `✅ Fixed`. Where a finding admits two valid remedies — ship
the thing the artefact promised, or correct the artefact — choosing the code side routes to the ordinary
path *correctly by the table*. The table is satisfied, not violated, and the artefact sentence stays
false. So Arm A carries a closing gate: a finding that fired it may not be closed until the cited
sentence is re-read in its file and either confirmed true of the post-fix state or amended.

| Fires in skill | At step | Routed through a scouted fix plan? |
|---|---|---|
| `/task` | Step 11 (review fixes) | **Yes.** The round's plan is gated before any fix is applied, and a plan whose row **proposes an edit** to a `*.spec.md` / `*.design.md` target — or carries an `amendment:` disposition, whatever its target — routes here instead of reaching the fix agent. A row proposing no edit records a finding an approved amendment already closed, and does not route on its target alone. |
| `/bugfix` | Step 5 (fix) | No. |
| `/project-review` | fix loop | No. |

**The scouted plan runs in the main feature-development flow only, and the three sites that do without it
— `/bugfix` Step 5, `/project-review`'s fix loop, and the post-push fix round below — do so as the
current state rather than as a pending change.** Extending it to them is **conditional on evidence**: it
is attempted only if a like-for-like cost measurement on a real feature task shows the sequence paid for
itself, and if no effect shows, the extension does not happen at all. Tracked in the harness repository
as issue #98. The amendment routing in this section fires at all four sites either way — the plan changes
*who* detects an amendment in the main flow, not *whether* the trigger applies anywhere.

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
