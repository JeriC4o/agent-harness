# Design: Ref-reading gates refuse a remote-tracking ref they cannot show is current

**Ticket:** GH-139
**Date:** 2026-10-21
**Spec:** ai-docs/plans/2026-10-21-check-redline-stale-ref.spec.md

## Approach

**A new shared helper, `scripts/ref-current.sh`, answers one question: may this ref's tree be read as
the remote's tree? Both gates call it before they read anything.** The redline check's `do_pending`
[do-pending] in `scripts/check-redline.sh` calls it in its ref branch, after the existing resolve check
and before `ls-tree`. The release check calls it on `BASE` [release-base] in `scripts/check-release.sh`,
after the existing resolve check and before the `git diff`. The helper returns clean and prints nothing when
the tree may be read. It returns cannot-run and prints a single reason line when it may not, and each caller passes
that line on under its own prefix (`check-redline:` through `die`, `check-release:` on stderr). No
caller output changes on the readable path, so verdict lines and exit codes stay as they are for current
refs and for refs read as given.

### Classifying the ref: git's own resolution decides

The helper asks `git rev-parse --symbolic-full-name <ref>` which ref git will actually read. The leg
applies only when the answer is under `refs/remotes/`. Measured with git 2.55.0 in a scratch clone with
a bare repository as `origin`:

- `origin/main`, `origin` and `origin/HEAD` all resolve to `refs/remotes/origin/main`. All three get the
  leg, and `origin/HEAD` is checked against the branch it points to.
- `main` resolves to `refs/heads/main`. A local branch is read as given.
- A full commit id and a revision expression such as `origin/main~0` resolve to the empty string. Both
  are read as given.
- An ambiguous name (a local branch literally called `origin/main` next to the tracking ref) also
  resolves to the empty string, with a successful exit status and two lines on stderr: a `warning:` that the name is
  ambiguous and an `error:` line. `rev-parse --verify` then resolves it to the local branch, so the tree
  that gets read is a local branch's, and reading it as given is correct.

The helper discards the classifier's stderr. The exit status and the empty output already carry the
answer, and the two lines would otherwise reach the caller's output on a path that is read as given.

This puts AC5 in the classifier. A commit id or a local branch never reaches the remote probe, so a
caller with no remote, or with an unreachable one, gets exactly what it gets today.

### Naming the remote branch: reverse-map the fetch refspecs

A tracking ref's name does not reliably say which remote and branch it tracks. Remote names can contain
`/`, and a single-branch clone carries an explicit refspec rather than the wildcard. So the helper reads
the mapping from configuration rather than parsing the name. For each name from `git remote`, it walks
that remote's `remote.<name>.fetch` values. It strips a leading `+` and skips negative (`^`) refspecs.
If the destination side carries a `*`, the helper matches its prefix and suffix against the full ref
name and substitutes the captured part into the source side. If it has no `*`, the match must be exact
and the source side is used as written. The first match supplies the remote and the source ref, such as
`refs/heads/main`. If nothing matches, the result is cannot-run: the ref does not belong to any
configured remote, so there is no remote to compare it with. Its reason line names the ref as the caller
passed it, states that no configured remote maps it, and gives the remedy of configuring the remote or
passing a commit id (AC2). It names no remote and no fetch, because there is none to name.

### Asking the remote, read-only

`GIT_TERMINAL_PROMPT=0 git ls-remote -- <remote> <source-ref>` returns the remote's advertisement for
that ref. The helper keeps only the line whose second field equals the source ref exactly, because
`ls-remote` patterns match on the tail. The outcomes:

| Probe result | Helper outcome |
|---|---|
| non-zero exit | cannot-run: the remote could not be reached (AC4) |
| no exactly matching line | cannot-run: the remote no longer has that branch |
| tip differs from `git rev-parse <full-ref>` | cannot-run: the local copy is not the remote's tip. Behind, ahead and diverged are not told apart, because any mismatch voids the claim and the remedy is the same |
| tip equals the local copy | clean, silent |

Each cannot-run line from the three probe rows above names the ref as the caller passed it, the remote,
and `git fetch <remote>` as the remedy (AC2). The unmapped-ref line is the one stated under § Naming the
remote branch. The unreachable case says "could not be reached" in so many words. There is no fallback
to the local copy on any branch of this table (AC4, AC7).

**The probe writes nothing locally, and AC9 depends on that.** In the same scratch clone, the output of
`git for-each-ref` and the listing of `.git` were identical before and after a `git ls-remote` against a
remote that held a newer commit, and no `FETCH_HEAD` appeared. The helper takes no lock and writes no
file in the repository.

### Why the helper's name has no `check-` prefix

`scripts/run-checks.sh` derives every tracked `check-*.sh` and requires each one to be either a
documented member or listed in `EXEMPT_CHECKS` [exempt-checks]. A `check-` name would force an exemption
entry for something that is not a gate. The helper is a shared dependency of two gates, like the payload
siblings beside `scripts/check-plan-invariants.sh`, but it is invoked rather than loaded. It is a `.sh`
file, so the shell-syntax and untracked-shell members cover it with no change to the runner.

### Per-caller wiring

- **`do_pending`** — `scripts/check-redline.sh` gains a `HERE` derived from `$0`, as
  `scripts/check-release.sh` already has, and calls `"${HERE}/ref-current.sh" "$dir" "$ref"` after
  testing `-x` on it: a helper that is missing or not executable is a cannot-run naming it, never a pass. The worktree branch of the
  function does not change and never calls the helper (AC6). The comment block above the function gains
  the reason for the leg: a resolved stale ref turns a skipped fetch into a pass.
- **`BASE`** — `scripts/check-release.sh` calls the helper with `"$ROOT"` and `"$BASE"`, after testing
  `-x` on it: a helper that is missing or not executable is a cannot-run naming the helper, never a pass. Its exit-code
  header line grows from "usage/environment error" to include "or the base could not be shown to match its
  remote". A short paragraph next to it says why a stale base is wrong in both directions: changes already
  on the default branch read as this branch's own, and a bump already on the default branch reads as this
  branch's bump. The existing "does not exist (fetch first?)" message for a base that does not resolve
  stays.
- **Mapping the helper's status, in both callers.** The helper writes its reason line to stdout and
  nothing else there; the stderr of the git commands it runs is its own to discard or keep. Each caller
  captures that stdout and reads only whether the status is zero. **Every non-zero status is a
  cannot-run**: the caller exits with its own cannot-run status and emits the helper's reason line under
  its own prefix — `check-redline:` through `die`, `check-release:` on stderr. It never passes the
  helper's status through, so no internal failure of the helper, and no status the shell itself returns
  for a helper it could not start, can read as `check-redline` findings or as a missing bump in
  `check-release`. When the captured line is empty, the caller's line names the helper and the status it
  returned instead.

### Rejected alternatives

- **Have each gate fetch.** Ruled out by the spec's Key decisions and Out of scope: a gate must not
  change local state.
- **Compare against the local branch's upstream (`@{u}`, ahead/behind counts).** These are local reads.
  Whether a tracking ref is current is a fact about the remote, which no local read can establish.
- **Inline the leg in both scripts.** The refspec reverse-map and the probe would then exist twice, and
  the two copies could drift apart on exactly the cases (explicit refspecs, missing branch) where a wrong
  answer is quiet.
- **A sourced function file.** Both callers define short global helpers (`die`, `finding`), so sourcing
  would share their namespace. An invoked script with an exit code fits how both gates already treat
  their dependencies, and its interface is just its exit status plus one line.
- **Derive remote and branch by splitting the ref name at the first `/`.** This is wrong for a remote
  name containing `/` and for any explicit, non-wildcard refspec.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | Create the currency helper: argument check, classification by `--symbolic-full-name`, refspec reverse-map over every configured remote, the `ls-remote` probe with exact-line filtering and `GIT_TERMINAL_PROMPT=0`, stderr of the classifier discarded, and the exit-2 reason lines: for a stale, unreachable or branch-gone ref, the ref, the remote and `git fetch <remote>`; for an unmapped ref, the ref, that no configured remote maps it, and the remedy of configuring the remote or passing a commit id. Header comment states the contract (clean and silent when readable, cannot-run with one line otherwise, never a finding) and why the name avoids the `check-` prefix. Tracked with the execute bit | `scripts/ref-current.sh` (new) | AC2, AC4, AC5, AC9 | — |
| 2 | Wire the helper into the ref branch of `do_pending` after the resolve check; add `HERE`; test `-x` on the helper first, so a missing or non-executable helper is a cannot-run naming it, never a pass; map every non-zero helper status to this script's cannot-run under its own prefix, per § Per-caller wiring; add the `[do-pending]` mark and the comment paragraph on why a resolved ref is not yet a readable one; add `[ref]` to the `pending` line of the top-of-file Run header, so it matches the `USAGE` string, which already carries it and stays as it is | `scripts/check-redline.sh` | AC1, AC3, AC5, AC6 | 1 |
| 3 | Wire the helper into the release check after the base resolve check; add the `[release-base]` mark on `BASE`; test `-x` on the helper first, so a missing or non-executable helper is a cannot-run naming it, never a pass; map every non-zero helper status to this script's cannot-run under its own prefix, per § Per-caller wiring; extend the exit-code header and add the stale-base paragraph | `scripts/check-release.sh` | AC7, AC8, AC5 | 1 |
| 4 | Bring the describing surfaces into line. In the post-merge workflow, the refusal paragraph after the fetch line says that a stale or unreachable remote is a cannot-run naming the fetch, and the existing fetch line stays. The release gate's item under `AGENTS.md` § Build & Test → Delivery gates says the gate needs the remote reachable for a remote-tracking base, that its cannot-run is not a pass, and that a commit id or local branch is read as given. The profile's `scripts/` layout row names the helper. Bump the plugin's patch version | `skills/pr-merged/SKILL.md`, `AGENTS.md`, `ai-docs/context.md`, `.claude-plugin/plugin.json` | AC10, AC2 | 2, 3 |

## Handoff plan

- **Before Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` to enter the first group with fresh context.
- **Group A:** subtasks 1–3, which build the helper and wire both gates to it.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group B with fresh
  context.
- **Group B:** subtask 4, the terminal group (1 subtask, within the 1..3 range): the describing surfaces
  and the version bump.

## Risks

- **The release gate now needs the network for its default base.** Offline, `origin/main` is a cannot-run
  instead of a verdict. This is intended, because the spec's AC4 makes it a cannot-run, and the release gate's
  description in `AGENTS.md` says so. A caller with no remote can still pass a commit id or local branch, which is
  read as given. `scripts/run-checks.sh` exempts this gate by name, so the offline pre-commit list is
  unaffected.
- **Race between the caller's fetch and the probe.** A push in between makes a just-fetched ref stale.
  The result is a cannot-run naming the fetch, never a wrong verdict, and re-running fixes it.
- **A blocking SSH prompt.** `GIT_TERMINAL_PROMPT=0` suppresses git's own credential prompt. An SSH
  host-key or passphrase prompt is outside it, and forcing SSH batch mode would override the user's own
  SSH configuration, so it is not forced. A hang is visible and is never a pass.
- **A revision expression over a tracking ref (`origin/main~1`) skips the leg.** Classification follows
  git's resolution, which reports no full name for an expression, so the tree is read as given. This is
  accepted: the spec scopes the leg to remote-tracking refs, and the only callers pass `origin/<branch>`.
- **Overlapping refspecs across remotes.** The first match in `git remote` order wins. Configurations
  where two remotes write into the same tracking namespace are already broken for `git fetch` itself.
- **Published interface.** Exit codes and verdict lines are unchanged for current and as-given refs, and
  the new output is a cannot-run reason line only. The post-merge workflow already refuses on anything other
  than a clean result, so its control flow does not change.
- **Execute bit.** Both callers test `-x` on the helper before invoking it, so a lost bit is a cannot-run
  rather than a silent pass.
- **Per-element work.** There is one probe per run. The refspec walk is bounded by the configured remotes
  and their fetch lines.

## Use cases

- `scripts/ref-current.sh` — used by the redline check's ref form before it reads a tree. It answers
  silently for a commit id, a local branch, or a tracking ref matching its remote. It refuses with a
  fetch remedy for a stale, unreachable or branch-gone ref, and with the remedy of configuring the remote
  or passing a commit id for a ref no configured remote maps. Used by the release check on its base, with the same outcomes. When the remote
  cannot be reached it reports that the remote could not be reached and never falls back to the local
  copy.
- the currency leg in `do_pending` — used by the post-merge workflow's refusal, so a skipped or failed
  fetch becomes a cannot-run instead of a clean read of an old default branch. A direct caller that
  passes a commit id gets the unchanged ref read.
- the currency leg in `scripts/check-release.sh` — used before opening a PR, so a stale base cannot hide
  this branch's shipped changes, or a missing bump, behind the default branch's own. An offline author
  who passes a commit id or local branch as the base gets that tree read as given.

## Open questions

- *(none)*
