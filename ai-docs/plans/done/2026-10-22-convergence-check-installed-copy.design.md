# Design: The plan-convergence check runs from an installed copy

**Ticket:** GH-145
**Date:** 2026-10-22
**Spec:** ai-docs/plans/2026-10-22-convergence-check-installed-copy.spec.md

## Approach

**The check reads from two roots, and it resolves both before Python starts.** The *method root* is the
plugin directory, which is the parent of the wrapper's own directory. Two method inputs are read from it:
the required-element record and the source of the minimum fragment length. The *project root* is the
top level of the git work tree that holds the spec. Project data is read from it: the tracked roster,
the baseline record of positional references, the files the pairing class resolves, and the excuse record
beside the plan. Today one variable, `ROOT` in `scripts/check-plan-convergence.sh`, serves as both. It
defaults to the parent of the wrapper's directory. In the plugin cache that directory has no repository,
so `tracked()` in `scripts/check-plan-convergence.py` fails, and the record's index guard then fails on an
empty roster. Both are cannot-runs, and both happen before any class runs. A copy of the four files plus
the two method inputs, placed outside any work tree and run against this spec, gives exactly that
cannot-run, with every roster line reading examined-clean (reproduced in a scratch directory).

### Resolving the two roots in the wrapper

- **Project root.** The wrapper asks `git -C "$(dirname -- "$SPEC")" rev-parse --show-toplevel`, the
  form the `ROOT` assignment in `skills/task/scripts/check-fix-plan.sh` already uses with its progress
  file. This design adds one step of its own: the answer is normalised to the physical path with
  `pwd -P`, for consistency with the method root, which is already physical, so both roots reach the core
  in one form. No test in the core depends on that step: `read_excuses` in
  `scripts/check-plan-convergence.py` realpaths both the excuse path and the root itself, the baseline
  test in `recorded_positions` in `scripts/check-plan-convergence-reporting.py` looks a fixed relative
  string up in `git ls-files` output, and `rev-parse --show-toplevel` already answers with a physical
  path. If the spec's directory is
  not in a work tree, or git refuses to read it, the result is a cannot-run that names the directory and
  says the project roster is a git index. That covers the spec's out-of-scope non-git project. The design
  document is read by the path given and contributes nothing on the project side. The excuse record sits
  beside the spec, which is why the spec's directory decides.
- **Method root.** This is the wrapper's directory's parent with `pwd -P`, as now. The wrapper also
  decides whether the method root is itself a git work tree. It is one only when `rev-parse
  --show-toplevel`, run from it, succeeds and names the method root itself. Both sides of that
  comparison are normalised to the physical path with `pwd -P` before they are compared, because this is
  a string comparison of two paths, and a symlinked prefix such as macOS's `/tmp` for `/private/tmp` on
  one side only would make the same directory compare unequal. A plugin directory that sits
  inside some other repository, such as a versioned home directory, is not one. That repository's index
  says nothing about the plugin's files, and guarding on it would bring the defect back for that user.
- The wrapper passes the method root, the method-indexed flag and the project root to the core as
  positional arguments. These three replace the core's single root argument today (`ROOT = sys.argv[1]`
  in `scripts/check-plan-convergence.py`), so the full order is: method root, method-indexed flag,
  project root, spec, design, excuse key, grounds. The header comments of both files
  state the new argument order. Doing all the resolution in the shell keeps the core's growth small, and
  the core already sits in the hard-ish size band (see § Risks).
- **`--root` is retired.** It overrides the one directory the defect conflated. An override that points
  the project anywhere but the tree holding the plan would bring back the same two-role confusion through
  a flag. The only caller is the check's own suite, measured with `git grep -n -- --root` over the tree.
  An unknown flag already ends as a usage cannot-run, so a stale caller fails loudly. The wrapper's git
  preflight message changes from "the record … is in the index" to "the project roster is a git index".

### The core reads each input from the root it belongs to

- `read_rel` keeps its name and reads under the project root. The pairing class and the baseline read go
  through it, and the reference sweep's direct `open` in `scripts/check-plan-convergence-reporting.py`
  joins the project root, which it receives as a context key.
- A new `read_method` reads under the method root, and it is the only route to a method input. The
  required-element derivation in the core uses it. So does `fragment_minimum` in
  `scripts/check-plan-convergence-holding.py`, which today reads the borrowed length off `ARMA_QUOTE_MIN`
  [arma-quote-min] in `skills/task/scripts/check-fix-plan.sh` through `read_rel`, and switches to the new
  reader handed to it in the context.
- **Method-input index guard, one rule for both inputs.** When the method root is a work tree, a method
  input that is present on disk and not in the method root's index is a cannot-run that names the input
  and says "stage it". When the method root is not a work tree, there is no guard: presence and
  readability are all that is required. In both cases an absent or unreadable input is the existing
  "could not be read" cannot-run, which names the input (AC2). The method root's roster is the project
  roster when the two roots are the same directory, which is the case in this repository, so no extra
  git call runs there. Otherwise it is a separate `git ls-files` on the method root. Applying the guard
  to the fragment source as well as the required-element record makes AC3 hold for either input. In this
  repository both are tracked, so nothing changes there.
- **Project-side guards use the project roster only.** The excuse record's membership test in
  `read_excuses` already takes a relative path against the root after `realpath`. It now takes it against
  the project root and the project roster, so an unstaged record is a cannot-run from any copy, and a
  staged one is honoured (AC5). The baseline record's membership test reads the same roster (AC9).

### A project with no baseline record skips one class and says so

`recorded_positions` in the reporting sibling gains a third outcome. If the record is absent from the
project's working tree, the result is a skip, not a block. The reporting group's `run` then runs
provenance and pairing as usual and does not run the reference class. Today `run` returns before all
three when the record is missing, and that early return stays only for the block. A record that is
present but not staged, or present but unreadable, takes the existing cannot-run branch unchanged (AC9).
A skip adds no finding, so the verdict comes from the other five classes (AC8).

### The roster never shows a class that did not run as examined-clean

Each sibling records which of its classes it entered, plus any class it skipped with the reason. The core
reads both through `tally`, so a sibling that never loaded counts as having entered nothing. In
`roster()`:

- A skipped class prints `not-examined` with its reason. For the reference class the reason is that the
  project keeps no baseline record, and the record's path is named.
- A class that was never entered prints `not-examined` because the run stopped before it.
- A class that ran keeps its existing state word.

This puts the spec's constraint into code wherever a run is cut short. It also fixes the cannot-run
roster, which today prints examined-clean for six classes that never ran. The spelling `not-examined`
follows the plan-invariants check's own surface roster. The counts line keeps its format.

### Rejected alternatives

- **Keep `--root` as a project-root override.** This would mean no changes in the suite. But a run could
  then read its roster from a tree that does not hold the plan, while the excuse record is still found
  beside the plan. That is the conflation the ticket removes.
- **Resolve the project from the current directory.** Rejected by the spec's decision on which tree is the
  project. The caller's working directory is not part of the invocation contract.
- **Guard a method input on any enclosing repository's index.** This fails for a plugin directory inside
  an unrelated repository: the index exists and never lists the plugin's files.
- **Treat a missing baseline as an empty record.** Rejected by the user: every positional reference in
  the project would report as a finding.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | Wrapper resolves both roots: the project root from the spec's directory, with a cannot-run naming that directory when it is not in a work tree; the method root and its work-tree flag, which is set only when the method root is itself a top level; passes method root, flag and project root to the core in place of today's single root argument, so the core receives method root, method-indexed flag, project root, spec, design, excuse key, grounds; retires `--root` from the parser, the usage string and the Run header; rewords the git preflight; the suite's invocations stop passing the retired flag | `scripts/check-plan-convergence.sh`, `scripts/test-check-plan-convergence.sh` | AC1, AC4 | — |
| 2 | Core takes the new argument order — method root, method-indexed flag, project root, spec, design, excuse key, grounds — the three leading arguments replacing today's single `ROOT` (`sys.argv[1]`); `read_rel` reads under the project root and a new `read_method` under the method root, which is the only reader for a method input; one guard rule for both method inputs, active only when the flag is set, against the project roster when the roots coincide and the method root's own roster otherwise; excuse-record membership against the project root and roster; context carries both readers and the project root; the roster prints not-examined for a skipped class with its reason and for a class never entered; the holding sibling's `fragment_minimum` reads through `read_method` and records the classes it entered | `scripts/check-plan-convergence.py`, `scripts/check-plan-convergence-holding.py` | AC1, AC2, AC3, AC5, AC6 | 1 |
| 3 | Reporting sibling: the reference sweep opens files under the project root; `recorded_positions` returns a skip when the baseline is absent from the project tree, and keeps the cannot-run when it is present but unstaged or unreadable; `run` still runs provenance and pairing on a skip and returns early only on a block; it records which classes it entered and the skip reason for the reference class | `scripts/check-plan-convergence-reporting.py` | AC4, AC6, AC8, AC9 | 2 |
| 4 | Regression guard: this repository's own check list runs a copy of the check placed outside any git work tree, against a plan pair in a git project, and refuses when that run does not reach the class sweep | `scripts/test-check-plan-convergence.sh` | AC7 | 1, 2, 3 |
| 5 | Describing surfaces: re-measure the core file's line figure and update the Thousand-line exemption row's justification text in the profile; bump the plugin patch version; sweep the Plan-Convergence sync group and record that no member states a fact this change alters, because each describes the classes and the verdict, never which root an input is read from; `agents/design-review.md` and `agents/design.md` stay silent on the new not-examined reference class, because both already direct the reader to the per-class roster rather than the exit status, the roster line carries its own reason, and the reference class reports without holding, so its absence cannot change whether a plan is held | `ai-docs/context.md`, `.claude-plugin/plugin.json` | AC6 | 2, 3 |

## Handoff plan

- **Before Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` to enter the first group with fresh context.
- **Group A:** subtasks 1–3. The two-root resolution and the readers in all four check files.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent /task resumes in Group B with fresh
  context.
- **Group B:** subtasks 4–5, the terminal group (two subtasks, within the allowed range): the regression
  guard, the profile row and the version bump.

## Risks

- **The core's size.** The core is already in the hard-ish band that `docs/code-style.md` § File size
  routes to a justification. All root resolution happens in the wrapper, and the core gains only the
  second reader, the guard rule and the roster states. Its measured line figure in the profile's
  Thousand-line row is re-measured in subtask 5 and is not stated here. Crossing the hard limit would
  need a split along the existing seam, not an exemption.
- **Retiring `--root` departs from the spec's "Invocation: Unchanged".** The design reads that decision
  as covering the workflow's two-argument call, which is unchanged; the optional flag is removed. Its only
  caller in the tree is the suite. A caller outside the tree gets a usage cannot-run, which is not a pass
  and names the usage.
- **This repository's behaviour departs from AC6's unqualified wording on cannot-run paths.** Here the
  two roots are the same directory and the method root is a top level. So both guards read the same
  roster they read today, every class runs, and the verdict line, counts and roster lines of a run that
  reaches the sweep do not change. Two things do change, both on cannot-run paths only:
  - Roster lines for classes that never ran now read not-examined instead of examined-clean, which the
    spec's constraint that the roster never shows an unexamined class as clean requires.
  - A missing required-element record now reports only "could not be read". Today it also reports "not
    in the index", because the rule is now one guard for present inputs.
- **The baseline skip departs from the spec's constraint that an absent required input is cannot-run.**
  The design treats the baseline record as required only where the project keeps one: absent from the
  project's working tree, it is a skip with a stated reason, as the spec's own decision on a project with
  no baseline record directs; present but unstaged or unreadable, it is still cannot-run (AC9).
- **A plugin directory inside an unrelated repository.** It is treated as having no index. A method input
  staged nowhere is then accepted when it is present and readable. This is the spec's chosen boundary:
  the guard is kept only where the plugin directory is itself a work tree.
- **Git refusing a work tree it considers unsafe.** The project-root resolution fails, and the run is a
  cannot-run naming the directory, not a misread roster.
- **Per-element work.** The roster lookups stay set membership tests. There is at most one extra
  `git ls-files`, and only when the roots differ and the method root is a work tree.

## Use cases

- Two-root resolution in the wrapper. In a consuming project, the workflow's existing two-argument call
  reads method inputs from the plugin cache and project data from the project. In this repository both
  resolve to the working tree. For a spec outside any work tree, it ends as a cannot-run naming the
  directory.
- `read_method` with the conditional guard. The core uses it to derive section names. The holding group
  uses it to borrow the minimum fragment length. It refuses an unstaged method input only where the
  plugin directory is its own work tree.
- The project-rooted `read_rel` and roster. The reference class sweeps the project's tracked files with
  them. The pairing class resolves named paths against the project. The excuse and baseline guards test
  membership in the project's index.
- The baseline skip. In a project that never kept a baseline, the reference class is reported as
  not-examined, with the reason, and the other five classes decide the verdict.
- The not-examined roster state. Any reader of the roster, including the design exit check, the design
  review and the task's convergence step, can tell a class that did not run from one that ran clean.
- The out-of-tree regression guard. This repository's own check list refuses a change that stops a copy
  outside any work tree from reaching the class sweep.

## Open questions

- None.
