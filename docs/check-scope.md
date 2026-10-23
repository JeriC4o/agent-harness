# Check scope — touched-scope checks in the loop, the full list once at the end

Every loop that ends in a commit — the task workflow, the bugfix workflow, the whole-branch review and the
fix round on an open pull request — runs two kinds of check at two different moments. **Inside the loop,
only the checks a change touches. Once, after review approves and before the commit is surfaced, the full
list.** This page states that rule once; each loop's step points here rather than restating it.

The commands come from the project profile, `AGENTS.md § Build & Test`: `%TEST_CMD%` is the narrowing run
and `%FULL_CHECK_CMD%` the full list. The full list is never reached through `%TEST_CMD%`.

## Selection inside the loop

**Touched paths are the files changed since the loop's base, including untracked files no ignore rule
covers.** One definition, used by every loop step that selects — the fix round's included.

After a change, run every check that the profile's **path rule** or its **hand-kept mapping** ties to a
touched path. Both live in the profile's touched-scope selection subsection: the path rule says which
checks read which paths, and the mapping holds the cases a rule cannot see. Before running, **state the
selection in one line**: each check, the touched path that selected it, and whether the rule or the
mapping selected it. Then run it with `%TEST_CMD%` in the narrowing form the profile gives.

The profile must give that form, and must declare — as a separate entry, the `**Selection flag:**` line —
the flag through which the form names its selection, or `none` when the form selects by path alone. The
flag's value may be written joined by `=` or as the next word; both spellings record as the same
selection. The gate record reads that line to tell a selection from a mode
([`${CLAUDE_PLUGIN_ROOT}/docs/loop-ledger.md`](${CLAUDE_PLUGIN_ROOT}/docs/loop-ledger.md#the-loop-ledger)).

**A wrong or missing mapping entry is tolerated here.** The final full run is what catches a check the
selection missed, and the fix round that follows such a failure may add the entry it lacked. No mechanism
checks the mapping for completeness.

## The single full run

After review approves and before the commit is surfaced, `%FULL_CHECK_CMD%` runs **once**. Its passing
record is what the progress file's `last_passed_gate` field holds, the tree digest included
([`${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`](${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md)).
The digest is copied from the gate record's line for that run.

**A full-list command outside the gate vocabulary** writes no record and reports no digest. The field then
takes the digest measured with `${CLAUDE_PLUGIN_ROOT}/scripts/tree-digest.sh` immediately after the run,
marked `(measured)` rather than recorded.

## The tree-unchanged condition

Immediately before surfacing the commit, compare the field's digest with
`${CLAUDE_PLUGIN_ROOT}/scripts/tree-digest.sh` run over the current tree. A difference means a file the
list examines changed after the passing run, so **the full run is owed again**. Edits only to ignored
progress notes never cause one.

**A late write moves the digest, and that is the requirement working.** A learning-log entry, or any other
unignored file written after the passing run, changes the digest and forces another full run. Write such
files before the final run, or run it again.

## A failing final run

It returns the loop to an ordinary fix round: the scoped checks over the fix, a review round over it,
approval. Then the full list runs again. **The commit is surfaced only after a passing full run that
followed the last approval.** Each loop names where its failure route re-enters; the review round that
receives the failing output records one `major` finding per failing check.

## The nested case

A bugfix invoked from any loop that owes its own final run **runs none**: it is still inside that loop,
and the loop's finalise step owes the run. Two routes reach it — the task workflow, and Step 4 of the fix
round on an open pull request, which sends a real defect to the bugfix workflow.

## What the gate record reports along the way

The gate record stamps every covered gate run with the tree digest and flags a **repeat** (the same gate
with the same arguments over the same tree) or a **contradiction** (the same gate over the same artefact
and tree with the opposite verdict). The flag is a ledger row, and the hook's line also reaches the
calling agent's own context, a subagent's included, after a pass or a failure (observed on the installed
0.1.53 build). A reviewer that
re-runs a scoped check over the tree the author's run was stamped against gets a repeat — **expected, not
a defect**; the reviewer re-runs only when the author's run was piped or `last_passed_gate` carries no
digest equal to the current tree's. A scoped pass followed by a failing full run over an unchanged tree is
silent, because the selection differs.
