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

A module-scoped gate covers only that module and does **not** catch every downstream regression. Two
classes break a file the diff never touched: an altered **published interface**, which can invalidate an
unchanged call site, a test double built against the old shape included; and a change to **what a
component requires of its collaborators**, which fails where that component is ASSEMBLED, not where it is
named. Run the gate over dependents too, found by searching the **CHANGED** name — not the new one, which
no dependent uses yet (`grep -rn "<ChangedName>" --include='*.<ext>' .`).

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
| Step 4 — diagnose + fix | inline-fix classes apply edits; a real defect routes to `/bugfix` with `**parent_skill:** post-push`, so it runs no full list; then the design author corrects in place each design item the fix made untrue ([§ Spec-Amendment group](#spec-amendment-group)) |
| Step 5 — `self-review` | APPROVE or REJECT (loop cap 3); the prompt names the spec and the design at their archived paths, so the review rules on the design's change since the freeze |
| Step 6 — commit | touched-scope checks green in the loop, and `%FULL_CHECK_CMD%` passed once after the Step 5 approval over the tree as it stands ([check scope](${CLAUDE_PLUGIN_ROOT}/docs/check-scope.md)); single commit per invocation |
| Step 7 — user pushes; the iteration ends | read the ticket and rewrite the PR description in place, once for the round ([§ The ticket and the PR description at the end of an iteration](#the-ticket-and-the-pr-description-at-the-end-of-an-iteration)) |

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
> test cases in the file → `OK: 3`). A dry-run/list flag is weaker evidence than a real filtered run — list
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
| Push | `git push -u origin <branch>` | **ASK-level for Claude** — Claude asks before running. Blocked on the default branch by the `branch-protection` hook, **except a LONE deletion of some other branch** (`--delete` / `-d`, or a push whose refspecs are ALL `:<branch>` deletions — one colon refspec standing beside a plain one pushes as well as deletes, while several deletions together are fine), which pushes nothing there. Deleting the default branch stays blocked, and so does any deletion carrying a shell metacharacter — send it as its own bare call. |
| Stage everything | `git add -A` / `git add .` | **FORBIDDEN** — see § Explicit-file staging. |
| Open a PR | `gh pr create --title … --body …` | **ASK-level for Claude.** Never `--fill` blindly; never auto-merge. |
| Read a PR | `gh pr view --json title,body,state,url` / `gh pr view --comments` | The end-of-iteration read (AXIOM 2). |
| Edit a PR | `gh pr edit --title … --body-file <file>` | The end-of-iteration rewrite of the description (AXIOM 2). |
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

## The ticket and the PR description at the end of an iteration

The method file's `## Workflow` AXIOM 2 in full. **An iteration ends at the first pass, before the PR is
opened, and at every correction pass after it** — a fix round for failing checks or one for reviewer
comments — in whichever workflow runs that pass on an open PR. Two workflows carry the act at a step of
their own: `/task`, which ends every pass at item 9 of Step 12, and the post-push fix round, which ends at
the last row of its table in [§ Post-push fix commits get self-review too](#post-push-fix-commits-get-self-review-too),
a `/bugfix` reached from that round returning to it. Any other workflow that runs such a pass — a
standalone `/bugfix` on a branch with an open PR among them — owes the act at the pass's end with no step
of its own. **A push that ends no iteration triggers nothing** — no reminder, no re-read
and no reconciliation with the diff.

**The orchestrator reads, as it writes the description, with no reader spawned.** It is a judgement of
meaning: it stops nothing, and no check reads the ticket or the description.

| At the end of an iteration | Act |
|---|---|
| The ticket, when the task has one | Read it for whether it still conveys the task's meaning. When it does not, put a correction to the user in plain terms ([`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Communication](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#communication)), and edit the ticket only when the user accepts it — it stays the original basis for the work |
| The PR description, at the first pass | Written to [§ PR title + body shape](#pr-title--body-shape) and opened with the PR, with the user's approval |
| The PR description, at each correction pass | Rewritten in place to the same shape (`gh pr edit --body-file <file>`), from the whole task rather than from the last push, and shown to the user before it is applied |

## PR title + body shape

- **PR title:** `<TICKET-KEY>: <conventional-commits header>` when the project uses ticket keys; a bare
  conventional-commits header otherwise.
- **PR description:** written for the reviewer from the whole task, not from the last push. It states the
  problem in the task's own terms, why it is being solved, and what to pay attention to in review — what
  changed is the diff's to show. Where the task changed a process, it carries a diagram of that process in
  the form the project's `AGENTS.md` § VCS names; when the profile names no form, the process is described
  in prose. It carries no test details, no counts, no acceptance-criterion checklist and no stats; no
  `## Summary` or `## Test plan` header; and no `Co-Authored-By:` trailer unless the user asks. It carries
  the closing trailer the project's profile names, when it names one, for the issue the PR resolves and
  under the profile's condition, and every in-place rewrite keeps it. Markdown renders, so bullets, inline
  code and links are fine.
- **The design's change since approval, in one line, each time the description is written.** When
  `${CLAUDE_PLUGIN_ROOT}/scripts/plan-freeze.sh diff` over the design says `changed`, the line links the
  design document's own entry in the review surface's comparison of the freeze commit with the branch
  head; where the surface cannot address one file's entry, it links the comparison and names the design's
  path at the branch head. No such line when it says `unchanged`. When it could not compute, one line
  saying the change since approval could not be computed and why, because no line at all would read as
  unchanged ([§ The plan freeze](#the-plan-freeze)).
- **Keep a small, self-contained PR to the files the task changes.** The plan's spec and design are among
  them: the freeze commits them, and the task's closing step moves them into `ai-docs/plans/done/` in the
  same PR.
- **In a tracker-integrated repo, writing an identifier is an ACTION, not a reference.** A bare ticket key
  in a PR title/body can create a remote link and transition that ticket's status. So a PR title or
  description names no ticket but the one the PR implements: no other key appears in it, wrapped in
  backticks or not, and a subtask, a follow-up or a ticket cited for background is described in prose
  without its key. Before naming ANY external id in a shared artefact, ask what the integration does on
  match.

## Markdown link tracing after generate/move

After generating or moving a markdown file with relative links, trace one link via `realpath` before
staging. Catches the common mistake where a moved file's `../foo` link no longer resolves.

## The plan freeze

**A plan is frozen by a commit.** At each design-review GO, once the design author has worked the GO's
notes into the design, the spec and the design — with the record of declared links, and the record of
excused findings when the task wrote one — are committed in one commit whose message ends with the
trailer `Plan-Freeze: <spec-base>`, `<spec-base>` being the spec's file name without `.spec.md`. The commit
is surfaced to the user once, staged list and message, under the ordinary consent rule for commits.
Nothing about the freeze lives in a local file, and a rebase keeps it: a rebase replays a commit's message
with its trailers, and the change since the freeze is computed from text rather than from commit ids.

**When it is taken.** At every GO of the plan: the first, a GO after a design amendment that a breaking
divergence caused, and a GO after a spec amendment that changed the approach. A spec amendment that keeps
the approach takes none — the review's breadth fingerprint reads the spec as it stands, so the next round
still sweeps every item ([`${CLAUDE_PLUGIN_ROOT}/docs/converging-review.md`](${CLAUDE_PLUGIN_ROOT}/docs/converging-review.md#triggers)).
Implementation does not begin on a plan with no freeze, and the implementation step's first action checks
for one.

**The change since the freeze** is computed by `${CLAUDE_PLUGIN_ROOT}/scripts/plan-freeze.sh`: `find` names
the plan's latest freeze — the latest commit reachable from the branch head whose trailers carry
`Plan-Freeze` with exactly the plan's spec base, so another plan's freeze on the same branch is never
matched; `show` prints a document's text at it; `diff` prints each named document's change since it, then
a verdict line. A document is compared wherever it now sits, so the move into the archive is no change,
and uncommitted corrections count, because a review runs before its round is committed. **Three outcomes,
and the third is never the second:** `changed`, `unchanged`, and could-not-compute — no freeze reachable,
a freeze that does not hold the document, no work tree, a tool missing — which every party reading the
change reports with its reason and none reads as unchanged.

**Who reads it.** Every review round of the task, follow-up rounds included, rules on each changed design
hunk ([`${CLAUDE_PLUGIN_ROOT}/agents/self-review.md`](${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#instructions),
step 5). A GO after the first rules on what its freeze would absorb: the re-entry design review, from
either amendment recipe, is handed `diff` over the design since the previous freeze and rules on each hunk
outside the sections the amendment changed. The pull-request description carries the design's change in
one line ([§ PR title + body shape](#pr-title--body-shape)).

## Spec-Amendment group

The trigger has **two independent arms**, and the second is the one that is easy to leave out:

- **Arm A — subject.** The finding asserts that something a `*.spec.md` / `*.design.md` states is false,
  stale, or unsupported. Test: *would closing this finding leave a sentence in the artefact untrue?*
  A spec sentence merely broader than what shipped stays true; only a genuine conflict (base
  principles) counts. Fires **regardless of where the fix lands**. For a completed plan the archive
  listing is not enough: what the arm needs is any sentence of a completed plan, which the listing's four
  sections do not carry, so search the completed plans for what the fix changes, and open in full only a
  document that search names.
- **Arm B — target.** The fix diff touches `ai-docs/plans/**/*.{spec,design}.md`.

Either arm is a Spec/Design Amendment trigger — NOT an ordinary code-fix.

**Firing an arm is not the same as routing. One further question decides that: does the divergence break
the agreed approach?** The two answers go different ways.

- **Breaking → the full amendment route**, exactly as it always ran — the recipe at the bottom of this
  section — and its GO takes a new freeze ([§ The plan freeze](#the-plan-freeze)).
- **Non-breaking → the design is corrected in place, and the code fix lands in the same round.** The
  design author rewrites each diverged item so it states what shipped and nothing else, after the code it
  describes exists, carrying no account of what the item said before; nothing re-runs and nobody is asked.
  The round's review rules on the correction through the design's change since the freeze. A correction is
  admitted only when it is needed to make the shipped thing correct; work that would widen what the task
  delivers is proposed as a separate ticket. The pass itself:
  [`${CLAUDE_PLUGIN_ROOT}/agents/design.md` § Correcting the design in place](${CLAUDE_PLUGIN_ROOT}/agents/design.md#correcting-the-design-in-place).

**Why the question is about the approach rather than about the document.** The reviewer's rule used to
reject correct code because a design sentence had gone stale, so the expensive path fired on every stale
sentence instead of on the rare divergence that actually invalidates the plan — and the planning chain
re-ran before the code fix was allowed to land.

**Whose design, and which workflows.** The in-place correction covers the task's own design on four
occasions: its implementation, its review-and-fix rounds, the follow-up rounds on its open pull request,
and a bug fix run inside any of those, whose trace carries `**parent_skill:**`. A sentence of another
plan's design — an archived plan later work makes untrue — still takes the amendment route with the user's
approval inside the later work's own pull request, and a spec sentence left untrue is a changed
requirement, which always takes the Spec Amendment recipe. **A standalone `/bugfix` or `/project-review`
keeps the full route** for every divergence it finds and is not given the change since the freeze: its
review prompt names no design. Extending the in-place correction to them is the same
conditional-on-evidence question as the scouted plan below, and it is not in scope here. The one thing
they see change is the fifth act of a spec amendment that keeps the approach, which corrects a falsified
design item directly in every workflow:
[`${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md` § Spec Amendment recipe](${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md#spec-amendment-recipe-re-entrant--triggered-from-a-step-7-verdict),
step 5.

### The implementation step corrects after each group

A divergence found while the code is being written has no round number and no finding number, because no
review has run. The handoff group that meets it records it in the progress file's decisions log — the
design item by its heading, and what shipped — and **the orchestrator applies the one test to the group's
hand-back: does it break the agreed approach?** Not breaking → once the group's code is written, the
design author's in-place correction pass runs once for the group, given the group's recorded divergences;
nothing restarts and nobody is asked. Breaking → work stops and the user is asked; on approval the Design
Amendment recipe runs, and its GO takes a new freeze. Either way the review rounds that follow rule on
the design's change since the freeze, the group's corrections among it.


**Arm B alone is not enough, and the gap is structural.** A diff-keyed rule hands the routing decision to
the same party that then marks the finding `✅ Fixed`. Where a finding admits two valid remedies — ship
the thing the artefact promised, or correct the artefact — choosing the code side routes to the ordinary
path *correctly by the table*. The table is satisfied, not violated, and the artefact sentence stays
false. So Arm A carries a closing gate: a finding that fired it may not be closed until the cited
sentence is re-read in its file and either confirmed true of the post-fix state or amended.

| Fires in skill | At step | Routed through a scouted fix plan? |
|---|---|---|
| `/task` | Step 11 (review fixes) | **Yes.** The round's plan is gated before any fix is applied, and a plan whose row **proposes an edit** to a `*.spec.md` / `*.design.md` target — or carries an `amendment:` disposition, whatever its target — routes here instead of reaching the fix agent, as does a `correction:` row whose quoted sentence is a spec's or another plan's design's. A row proposing no edit records a finding an approved amendment already closed, and does not route on its target alone. |
| `/bugfix` | Step 5 (fix) | No. |
| `/project-review` | fix loop | No. |

**The scouted plan runs in the main feature-development flow only, and the three sites that do without it
— `/bugfix` Step 5, `/project-review`'s fix loop, and the post-push fix round below — do so as the
current state rather than as a pending change.** Extending it to them is **conditional on evidence**: it
is attempted only if a like-for-like cost measurement on a real feature task shows the sequence paid for
itself, and if no effect shows, the extension does not happen at all. Tracked in the harness repository
as issue #98. The amendment routing in this section fires at all four sites either way — the plan changes
*who* detects an amendment in the main flow, not *whether* the trigger applies anywhere.

Recipe: stop, get user approval, have `spec-writer` amend the spec, then take the branch the amendment's
one question names — when it changes the agreed approach, re-run `/task` Steps 6 → 7 on the amended pair
(max 3 rounds) and resume from the GO; when it keeps the approach, re-read the amended pair, route each
genuine finding by the side that is wrong, and resume the interrupted step
([`${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md` § Spec Amendment recipe](${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md#spec-amendment-recipe-re-entrant--triggered-from-a-step-7-verdict)).

Detection: mechanical at the top of every fix round — `git diff` includes a `*.spec.md` path → the trigger
fires regardless of how small the doc edit appears.

## Sibling-test rule

Every production source file with ≥50 lines of non-trivial logic should have a corresponding test file in
the project's test source root, mapped one-to-one by package/module + name
(`<SourceName>` → `<SourceName>Test`). The mapping, source roots, and file extensions are project-specific;
record them in `ai-docs/context.md` so the rule is checkable.

## When a spec amendment re-derives the design

A spec amendment asks one question before anything else happens: does it change the AGREED APPROACH? The
routing table is in [`${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` § Spec Amendment recipe](${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md). This page carries why it is asked.

**Both wrong answers cost something, and they are not symmetric.** Re-deriving a design because a criterion
lost an over-promise re-runs the whole planning chain over a document nothing read in between — the cost
correcting the design in place exists to remove, and on a large design it is the most expensive round in the
workflow. Skipping the chain on a genuine approach change is worse in kind rather than in degree: it ships
an implementation built against a requirement nobody re-planned for, and the divergence is invisible
because the document that would have shown it was never rewritten.

**The spec's own form rule is what makes the cheap row the common one.** Once a criterion cannot name a
command, a script or an identifier ([`${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` § What a spec IS](${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md)),
the spec stops needing edits for implementation detail — which is what drove amendment traffic in the
first place. Measured on the branch that introduced the rule, against its own spec as the branch found it,
and **stated to be reproduced rather than trusted**: the form check over that commit's spec reports
**7 of its 23 criteria spelling an instrument**. Prose naming an instrument class without
a command roughly doubles it, given without a figure because no command reproduces a judgement. By
section that spec was **68%**
acceptance criteria, scope and technical constraints, against **23%** for the three sections the closing
fold retained and **4%** for the record of deliberate absence. An amendment to a
criterion naming an instrument is an amendment about mechanism, and mechanism is what the design, not the
spec, is for.

**The freeze follows from the same question, and is not a separate decision.** A rebuild replaces the
agreed base, so its GO takes a new freeze — one that absorbs every correction made in place since the
previous freeze, which is why the re-entry review rules on those corrections before granting it. An
amendment that leaves the approach intact is not a divergence at all, so it takes no freeze: the review's
fingerprint reads the spec as it stands, so the next round still sweeps every item, and the corrections
the amended pair's re-read makes stay in the change since the freeze for that round to rule on. A design
item the amendment made false, and a predating design-side contradiction the re-read finds, are corrected
directly by the design author.

## Why four path classes are excluded from the unplanned-file arm

The learnings archive and the per-branch learnings files are excluded because the in-flow capture exception
permits appending to them mid-round. `ai-docs/plans/*.spec.md` and `ai-docs/plans/*.design.md` are excluded
because the amendment recipes write to a spec or design artefact and then send the round back, while
`baseline` refuses a second stub — so the round keeps a `round_base` taken before the amendment, and
without the exclusion the arm would fire by construction on every amendment-then-resume round,
permanently. `ai-docs/plans/*.links.md`, the record of declared links, is excluded for the same reason
one step on: the design author writes it mid-round — on a design amendment, on the Step 6 re-entry of an
amendment that changes the approach, and in the pass of an amendment that keeps it — no `fix` row can
name it, and the arm's ignore test short-circuits its membership check. The verdict still names it on the
`excluded-in-round` line, which the orchestrator accounts for against the amendment it knows it ran.

**The two plan suffixes and not the directory.** The routing arms key on the suffixes, so a
directory-wide exclusion would be wider than its own justification: it would drop the briefed lines of a
tracked non-routing path under that directory from the measured total while they still counted on the
declared side. The declared-link glob is a variable of its own, read by the ignore test alone and by no
arm, which is what keeps that correspondence intact.

