# The plan-convergence check runs from an installed copy

**Source:** ticket GH-145
**Date:** 2026-10-22
**Tracked in:** GH-145

## Scope

The deterministic plan-convergence check is the mechanical half of the convergence step every task runs
between design and review. The workflow invokes it from the installed plugin directory. Today that copy
cannot run anywhere but this repository: it treats the directory it is installed in as a git work tree,
and the plugin cache is a plain copy with no repository, so every run ends as cannot-run before any class
examines anything (reproduced against the installed 0.1.48 copy, output quoted in the ticket).

The cause is that one directory serves two different roles in the check:

1. **The method inputs** — the required-element record the section names are derived from, and the
   source of the minimum fragment length the isolation class reads. These ship with the plugin and belong
   to the plugin's own directory.
2. **The project data** — the tracked-file roster the reference class sweeps, the baseline record of
   positional references it compares against, the files the pairing class resolves a plan's named paths
   against, and the excuse record beside the plan, whose index membership is checked. These belong to
   the project whose plan is being checked.

In this repository the two coincide, which is why the defect was invisible here. The work:

1. Method inputs are read from the plugin's own directory. Their index-membership guard applies only
   where that directory is itself a git work tree; outside one, being present and readable is what is
   required.
2. Project data is read from the working tree of the project that holds the plan documents, and every
   index-membership guard on project data is evaluated against that project's index.
3. In a project that keeps no baseline record of positional references, the reference class is not
   examined: its roster line says not-examined and gives the reason, and the other five classes run and
   decide the verdict as usual.
4. A permanent regression guard: a copy of the check outside any git work tree is exercised by this
   repository's own checks, so a return of the defect is refused before it ships.

## Out of scope

- The other checks the workflow runs from the installed copy. Each was read for the same assumption:
  the redline check and the fix-plan gate already locate their repository from the plan or progress
  document they are given, not from their own directory, and the plan-invariants check is a structural
  check of this repository that no workflow step runs in a consuming project. None is changed here.
- Any change to what the six classes detect, how a finding is keyed or excused, or the three-outcome
  convention.
- A project that is not a git work tree at all. The project roster is a git index; such a project gets
  cannot-run naming that cause, as any unreadable required input does.

## Deferred

- Scaffolding a baseline record of positional references into a newly set-up project, so the reference
  class runs there too | not needed for the check to run, since a missing record now skips that one class |
  separate ticket if wanted.

## Key decisions

| Question | Decision |
|---|---|
| Which tree is "the project" | The working tree containing the plan documents, not the directory the check is invoked from and not the plugin's. The redline check and the fix-plan gate locate their repository the same way. |
| Index guard on method inputs | Kept wherever the plugin directory is a git work tree — this repository, or a plugin installed from a local clone — because there a method input that is not staged is still read by this run and by no other clone. Dropped only where there is no index to consult. |
| Invocation | Unchanged. The workflow's existing call, with the plan pair as its only arguments, is the one that must work. |
| Reference class with no baseline record in the project | Not examined, and said so: the roster marks the class not-examined with the reason that the project has no baseline record; the other five classes run normally and the verdict is theirs. Chosen by the user over treating the absence as an empty record (every positional reference in the project would then report, turning the run to findings) and over refusing to run. |
| What counts as "no baseline record" | The record is absent from the project's working tree. A record that is present but not staged in the project's index, or present but unreadable, stays cannot-run, as it is in this repository today — the skip covers a project that never kept one, not one whose record is broken. |

## Technical constraints

- Outcomes keep their meaning: clean or excused-only is 0, findings 1, cannot-run 2, and cannot-run is
  never a pass.
- A required input that is absent or unreadable is still cannot-run, in an installed copy as much as here.
- A class that did not run must never read as examined-clean.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | When the check is run from a copy of the plugin that is not inside any git work tree, against a plan pair in a project's git working tree, it reaches the class sweep and prints its verdict line and per-class roster instead of ending as cannot-run. |
| AC2 | When, in such a copy, the required-element record is missing or unreadable, the run is still cannot-run and names the record. |
| AC3 | When the check runs from a copy that is itself a git work tree and a method input is present but not staged, the run is still cannot-run naming that input — the existing guard in this repository is not weakened. |
| AC4 | When run from an installed copy, the reference class sweeps the files tracked by the project holding the plan, and the pairing class resolves the paths a plan names against that project — never against the plugin's own files. |
| AC5 | When a plan's excuse record exists in the project but is not staged in the project's index, the run is cannot-run naming it, exactly as it is in this repository today; a staged record is honoured from an installed copy. |
| AC6 | When run in this repository against a plan pair, every class, count and verdict is what it was before the change. |
| AC7 | A change that makes a copy outside any git work tree unable to reach the class sweep again is refused by this repository's own checks before it can merge. |
| AC8 | When a project keeps no baseline record of positional references, the run does not end as cannot-run on that account: the reference class is reported as not examined with the reason that the record is absent, it contributes no finding, and the verdict is decided by the other five classes. |
| AC9 | When a project's baseline record is present but not staged in its index, or present but unreadable, the run is cannot-run naming the record. |

## Open questions

- None.
