# Design: A converging review checklist, a full check list that runs once at the end, and a gate record that knows what it ran against

**Ticket:** GH-138
**Date:** 2026-10-22
**Spec:** ai-docs/plans/2026-10-22-converging-review-checklist.spec.md

## Approach

The four parts share one primitive: **a digest of the working tree as version control sees it.** It is the
content of every path git does not ignore — tracked files as they stand on disk, plus untracked files that
no ignore rule covers — and nothing else. Index-versus-worktree staging does not move it, an ignored file
(the progress notes, a bugfix trace) does not move it, and computing it writes nothing to the object store.
One shipped script, `scripts/tree-digest.sh`, computes it for the whole tree or for a named path list. The
reviewer's checklist record hashes its scopes with it, the gate-record hook stamps every covered gate run
with it, and the finalise steps compare the last passed gate's stamp against it. One definition of "the
tree changed" serves the spec's three uses of that phrase.

### The converging checklist

**Where the record lives: inside the reviewer's own round section, not in a file of its own.** The spec asks
for the reviewer-owned file to be costed first. It would be a new path class beside the progress notes, and
it only works if it is ignored by version control:

- This repository's `.gitignore` would need an entry for it, and so would `templates/project/gitignore.snippet`.
- `skills/pr-merged/scripts/cleanup-progress.sh` would need to delete it.
- The bugfix and whole-branch review flows would each need a path convention for it.
- Consumers who installed before the change have no ignore entry until they re-scaffold. In their trees
  the file would be untracked and unignored, so every reviewer write would move the tree digest. That
  blinds the repeat detector and breaks the rule that only ignored notes changed means the tree did not
  change.

The progress-notes route costs one sentence. Every caller already names a file the reviewer appends
`## Self-Review (Round N)` to: the task's progress file, the whole-branch review's progress file, or the
bugfix trace. The reviewer already reads its own earlier round sections, because it counts them and
re-evaluates their finding statuses. The carve-out is to add the record subsection to what the reviewer
reads for content, beside the three carve-outs already listed in `agents/self-review.md` § Instructions,
step 2. The record goes there.

**The record is a `### Checklist ledger` subsection at the end of each `## Self-Review (Round N)`.** Each
round writes it in full, so a later round reads only the latest one. It carries two header fields and one
table:

- `**Plan digest:**` is a digest of the spec and the design, taken with every redline marker removed. It is
  `none` when the caller passed no plan documents.
- `**Base:**` is the diff base the round reviewed against.
- The table has one row per **(item, scope)** with these columns: `Item | Scope | Rule | Digest | Findings | State | Trigger`.
  - **Item** is the number of one of the reviewer contract's numbered checklist subsections.
  - **The objection-quality item is the one item with no covered state to digest**, because its subject is
    the set of objected findings rather than any file. In every round after the first it has exactly one
    row, with the scope token `objections` and the Digest cell `—`. It is never carried: its row is always
    `swept` with the trigger `objected`, and sweeping it over an empty set of objections is the act of
    confirming the set is empty. Round 1 writes no row for it, because the reviewer contract runs that item
    in later rounds only and round 1 stays as it is.
  - **Scope** is a space-separated list of repo-relative paths, the token `diff`, or the token
    `objections` described above. `diff` means every path in
    the change at the moment of hashing, and it suits items whose verdict depends on the change as a whole
    (spec and design conformance). The reviewer decides the grouping. An item whose checks are local to a
    file (safety, style, documentation, tests) takes one row per file or per file group. That is what lets a
    one-line fix in one file reset only the rows covering that file.
  - **Rule** names the rule text the row checks, as `path#heading` references. The item's own subsection of
    the reviewer contract is always listed, and any rule page the item applies is added, such as the
    code-style reference or the project's own profile. A reference resolves against the installed plugin
    first and then the project. **[REDLINE S8.4]**
  - **Digest** is two fixed-length hash prefixes joined by a dot: the scope's content hash from
    `scripts/tree-digest.sh`, then the hash of the resolved rule sections. Two halves let a mismatch name its
    trigger.
  - **Findings** lists the numbers of the findings raised under this row in this round, or `—`.
  - **State** is `swept` or `carried`.
  - **Trigger** is empty for a carried row. For a swept row it is one token from a closed set:
    - `first-round`
    - `scope-changed`
    - `rule-changed`
    - `objected`
    - `new-file`
    - `record-invalid`
    - `amendment`

**One shipped script, `scripts/review-ledger.sh`, does all the hashing and comparing, so the reviewer
recomputes nothing by hand.** The name avoids the words `check`, `test`, `lint` and `verify` on purpose.
Two things key on those words, and together they decide what the gate record records: the gate pattern `G`,
one of the three patterns in the result-masking command in `hooks/hooks.json`, and the gate record's one
extra arm, a checked-in script with one of those words in its path token executed directly (§ The gate
record, step 2). Both match the word anywhere in the path token, directory parts included, because the
character class before the keyword admits `/`. This script decides breadth rather than passing or failing
anything, so it must match neither: its name avoids the words, and it is invoked through a path free of
them, which `scripts/review-ledger.sh` under the plugin root normally is.
Neither of the other two patterns keys on a script's name. `B` refuses any `bash`/`sh`/`zsh` invocation of
a `.sh` file or of `-n` joined with `&&` to a second one. `L`, the loop-body pattern, refuses a gate run
inside a loop: it lists build and lint tools by name (`make`, `cargo`, `go`, `npm` through `ktlint`) and
matches any `bash`/`sh`/`zsh` invocation of `-n`, of a `.sh` or `.bash` file, or of a variable. Both match
this script whatever it is called, so the reviewer invokes it as its own call like any other shell script.
It has two verbs:

- **`plan <findings-file> --base <rev> [--plan <path>]…`** runs at the start of a round after the first. It
  reads the latest round's ledger and recomputes every row from the tree. It reads that round's findings
  table for statuses that begin `⚠️ Objected`, and it lists every path in the current change that no
  recorded scope names. It prints one line per row, `carry` or `sweep <trigger>`, then one `new-file <path>`
  line per uncovered path, then a verdict line naming the totals and whether the whole list was reset. **[REDLINE S8.3]**
  - A row is carried only when both digest halves match and none of its findings is objected.
  - The `objections` row always prints `sweep objected`.
  - A scope half that differs gives `scope-changed`, and a rule half that differs gives `rule-changed`.
  - A row that does not parse, or whose digest is not in the two-prefix shape, gives `record-invalid`. The
    `objections` row, whose Digest cell is `—`, is exempt from the shape rule and still prints `sweep objected`.
  - A ledger that is absent sweeps every item as `record-invalid`. **[REDLINE S8.2]**
  - A plan digest that differs from the recorded one sweeps every row as `amendment`, whatever the rows say. **[REDLINE S8.5]**
  - An edited record whose digest no longer matches the tree is swept like any other mismatch.
  - Its exit statuses follow the repository's convention: success for a computed plan, the cannot-run
    status otherwise. On a cannot-run the reviewer sweeps everything and says so.
- **`seal <findings-file>`** runs after the reviewer has written the round's ledger with the Digest cells
  blank. It fills each blank cell with the digest recomputed from the tree as it stands at sealing time,
  leaving the `objections` row's `—` as written. It refuses a malformed row or a trigger outside the closed set, and it writes nothing else. Sealing from the
  tree, rather than accepting a digest the reviewer typed, means a carried claim can never be a bare
  assertion. **[REDLINE S8.1]**

**The full-reset trigger is the plan digest, and only the task workflow passes plan documents.** The
reasoning:

- A spec or design changes mid-review only through the task workflow's amendment recipes, which are the
  route for a divergence that breaks the agreed approach.
- The marking pass appends redline markers only, and the plan digest strips those markers. A non-breaking
  correction therefore leaves it unchanged. Its code fix still resets the rows covering the files it
  touched.
- The bugfix and whole-branch review flows pass no plan documents. Their plan digest is `none`, and they
  never reset on this ground.
- The task workflow's amendment recipes say that the amendment is what makes the next round sweep every
  item.

That fits the spec's decision that the reset lives where amendments are routed. No orchestrator-written flag
is involved, so nothing can be lost to a compaction between the amendment and the next spawn.

**The reviewer contract, `agents/self-review.md`, changes in eight places, and the mechanics live on a new
reference page.** Six belong to the converging checklist:

- The breadth step: round 1 sweeps everything. A later round runs `plan` and sweeps exactly the rows it
  marks, plus every applicable item over each `new-file` path, adding rows for them. It carries the rest
  and then seals.
- The ledger subsection in the findings format, including the objection-quality item's always-swept
  `objections` row.
- The APPROVE condition, reworded so that every item has been either swept this round or carried with a
  matching recomputed digest.
- The carve-out for reading its own ledger.
- Removal of the cross-round re-derivation bullet in the contract's Rules section, the one that begins "On round > 1, re-verify
  against the RULE FILE". It goes whole, and nothing narrower replaces it. One sentence inside that bullet,
  the instruction to apply a rule's strict clause over its lenient one, is a reading rule, so it is lifted
  out and stays as a one-sentence bullet of its own.
- The verdict's swept/carried line, described below.

Two belong to the touched-scope rule and are described with the loops below: the scoped re-run in the
"Reconcile every green verdict" rule, and the final-check-failure input.

The unit and scope rules, the digest's composition, the trigger set, the ledger's example table and the
script's verbs are stated once, on `docs/converging-review.md`. The contract links to that page and does
not restate them. The ledger itself is the per-item breadth report: State and Trigger say what was swept,
what was carried and why. The verdict printed to stdout adds one line with the swept and carried totals.

**What stays as it is.** Every earlier finding's status is still evaluated each round under the existing
re-review bullets: fixed, objected and still open. That is finding-level work, not a checklist sweep, and
it is small. Settled redline items stay settled.

### Touched-scope checks in the loop, the full list once at the end

**A new method page, `docs/check-scope.md`, states the rule once, and every loop points at it.** It covers:

- **Selection inside the loop.** After a change, run every check that the project's path rule or its
  hand-kept mapping ties to a touched path. **Touched paths are the files changed since the loop's base,
  including untracked files no ignore rule covers** — one definition, used by every loop step that selects,
  the fix round's included. Before running, state the selection in one line: each check, the touched path
  that selected it, and whether the rule or the mapping selected it. Run it with `%TEST_CMD%` in the
  narrowing form the profile gives. The page requires the profile to give that form and to declare, as a
  separate entry, the flag through which the form names its selection, or `none` when the form selects by
  path alone, and it states that the flag's value may be written joined by `=` or as the next word, both
  spellings recording as the same selection (§ The gate record, where arguments are classed). A wrong or missing mapping entry is tolerated here.
  The fix round that follows a final-run failure may add the entry it lacked, and no mechanism checks the
  mapping for completeness.
- **The single full run.** After review approves and before the commit is surfaced, `%FULL_CHECK_CMD%` runs
  once. Its passing record is what the progress file's last-passed-gate field holds, digest included.
- **The tree-unchanged condition.** Immediately before surfacing, compare that field's digest with
  `scripts/tree-digest.sh` run over the current tree. A difference means a file the list examines changed
  after the passing run, so the full run is owed again. Edits only to ignored progress notes never cause one.
- **A failing final run.** It returns the loop to an ordinary fix round: scoped checks, a review round over
  the fix, approval. Then the full list runs again. The commit is surfaced only after a passing run that
  followed the last approval.
- **The nested case.** A bugfix invoked from any loop that owes its own final run runs none, because it is
  still inside that loop and the loop's finalise step owes the run. Two routes reach it today: the task
  workflow, and Step 4 of the fix round on an open pull request, which sends a real defect to the bugfix
  workflow.

**One new method placeholder, and the profile's touched-scope entries.**

- **Placeholders.** `%FULL_CHECK_CMD%` joins the placeholder set named in `docs/agents-method.md` § Build &
  Test. `%TEST_CMD%` keeps its meaning, a narrowing run, and the full list is never reached through it.
- **The profile template.** `templates/project/AGENTS.md` § Build & Test gains a `%FULL_CHECK_CMD%` row,
  plus a "Touched-scope selection" subsection with three separate entries: the path rule (which checks read
  which paths), the hand-kept mapping table, and a `**Selection flag:**` line carrying `%SELECTION_FLAG%`.
  The gate-record hook reads that line (§ The gate record, where arguments are classed). This keeps every one of these facts in
  the section the method
  already references as `AGENTS.md § Build & Test`. No new `AGENTS.md § …` target is introduced for the
  reference check to resolve.
- **Set-up.** `skills/harness-init/SKILL.md` fills the full-list row and the three subsection entries. It
  confirms the full command runs. For a module-addressed project it defaults the rule to "a touched path
  selects `%TEST_CMD%` for its module, and `%LINT_CMD%` over the changed files", and the selection flag to
  `none`; the module path such a run names is a directory, which the gate record keys as a path argument
  (§ The gate record, where arguments are classed). It starts the mapping as `(none yet)`.
- **The audit.** `scripts/audit-project.sh` adds `%FULL_CHECK_CMD%` to its label list, which holds
  permanent labels that a filled-in profile still carries as the placeholder column. `%SELECTION_FLAG%`
  stays off that list, as `%VERSION_BUMP_PATHS%` and `%DEPLOYED_CONFIG_GLOBS%` do, because it is a value
  set-up replaces: a project that left it unfilled is reported as carrying an unresolved placeholder,
  rather than passing silently into a gate record that would read the literal token as its flag.

**This repository's profile.** In `AGENTS.md` § Build & Test:

- `%TEST_CMD%` becomes `bash scripts/run-checks.sh --only <member>[,<member>…]`.
- `%FULL_CHECK_CMD%` becomes `bash scripts/run-checks.sh`.
- The selection flag is `--only`.
- The touched-scope subsection is placed after the delivery gates, outside the span that the runner's
  gate-inventory member parses.
- The path rule:
  - A touched `<dir>/<name>.sh`, or one of its payload siblings, selects `<dir>/test-<name>.sh` where that
    exists.
  - A touched suite selects itself.
  - Any touched `*.sh` selects `shell-syntax` and `untracked-shell`.
  - A touched manifest selects `manifests`.
  - Any touched `*.md` selects `references`.
- The mapping holds the cases the rule cannot see. Each entry is derived during implementation by reading
  which files a member opens. Known entries:
  - `hooks/hooks.json` selects the hook-behaviour suite and `propagation-arms`.
  - `docs/propagation.md` selects `propagation-arms`.
  - `README.md` selects `readme-update`.
  - The plan-invariants pages select `plan-invariants`.
  - The Build & Test section of `AGENTS.md` selects `gate-inventory`.
  - The loop hooks select the loop grid and corpus suites.

**`scripts/run-checks.sh` gains `--only <member>[,<member>…]`.** Member names are spelled as `--list`
prints them. With the flag, the runner runs only those members, prints the selected names and states that
the full list was not run, and still gives one verdict per member. An unknown member name takes the cannot-run exit. It is a
change to the profile's runner. The header comment "NO FLAG NARROWS THE RUN" rested on narrowing being
silent, and the reworded comment says what replaced that concern: narrowing is explicit and reported, and
the final full run is the safety net. The suite list stays derived from the tree, and a run without the
flag is unchanged. Selection stays with the agent, so the runner implements no path-to-check derivation.
The automatic derivation is out of scope.

**The loops.** Each edit replaces a whole-list run inside the loop with the scoped selection, and adds the
single full run at the loop's end:

- **Task workflow.**
  - Step 8 item 1's test clause, which today runs `%TEST_CMD%` filtered to the new test only when the
    subtask adds tests, becomes the touched-scope selection per `docs/check-scope.md`, so a subtask that
    adds no test still runs the checks its touched paths select.
  - Step 9's `%TEST_CMD% <module-path>` becomes the touched-scope selection.
  - Step 11's "after all findings resolved, run gates" becomes the touched-scope selection, over the
    touched paths as `docs/check-scope.md` defines them.
  - Step 12 moves the plan files to done, runs the build, runs the full list once and compares the digest
    before surfacing. On a failure, Step 12 moves the plan files back, so routing, exclusions and review
    prompts see the paths they key on. It then spawns the Step 10 reviewer with the failing output's file
    named, and the reviewer records one `major` finding per failing check. Every checklist row with an
    unchanged scope carries, so that round is narrow. The task then continues through Step 11 and Step 10
    as an ordinary round, and returns to Step 12. Step 12 states the full run and the digest compare in
    `skills/task/SKILL.md`; the failure route is written in `skills/task/reference.md` § Step 12, with a
    one-line pointer.
- **The fix-round procedure.** `docs/scouted-fix-round.md` carries the same sentence as Step 11.
  `agents/fix-scout.md` names, in `**verification:**`, the touched-scope checks for the round's target
  files, and never the full list. `agents/fix-apply.md` re-runs those.
- **The reviewer.** The "Reconcile every green verdict" rule in `agents/self-review.md` keeps its demand for
  an unpiped re-run, scoped to the touched-scope checks, and narrowed to the runs that need it: the
  reviewer re-runs a scoped check only when the author's run was piped, or when the progress file's
  `last_passed_gate` carries no gate-record digest equal to the current tree's. A run the gate record
  stamped over the tree under review is already evidence that it ran. The reviewer's instructions also
  accept the final-check-failure input described for Step 12.
- **Bugfix workflow.** Step 6's module-wide run becomes the scoped selection. A full-run step sits between
  the Step 6.5 approval and the Step 7 cleanup, in standalone mode only. On a failure the bugfix goes back
  to Step 5, then Step 6, then Step 6.5. A bugfix reached from the task workflow, or from Step 4 of the fix
  round on an open pull request, is not standalone and skips that step under the nested case.
- **Whole-branch review.** Step 3's per-batch gates and Step 4's final verify become scoped, because Step 4
  precedes the review. On APPROVE, Step 5 runs the full list once before it surfaces the commit, and a
  failure goes back to the REJECT path.
- **Fix round on an open pull request.** In `docs/workflow.md` § Post-push fix commits get self-review too,
  the Step 6 row requires the full list to have passed once after the Step 5 approval.
- **Progress-file templates.** The `last_passed_gate` example in `skills/task/reference.md` and every
  written `last_passed_gate` value in the three skills gain the digest field.

**Size headroom is part of the change.** The 35,000-character early warning is a threshold the method file
hands down. Four files are within reach of it, measured with `wc -c` in this session. Sizes and budgets
here are in bytes because a byte count is an upper bound on a character count, so a file whose budget is met
in bytes is also below that character warning:

| File | Measured size | Offset that keeps it below the threshold |
|---|---|---|
| `skills/task/SKILL.md` | 34,999 bytes (measured, `wc -c`, this session) | Step 8's transport-drop backoff paragraph (475 bytes, measured with `awk` `length` on its line, this session) moves to `skills/task/reference.md`, and so does the rationale tail of Step 12 item 1, the passage from "Both admissible values mean the review question is settled" to the end of that item (320 bytes, measured with `grep -o … \| wc -c`, this session). Each leaves a one-line pointer of at most 100 bytes, a ceiling this design sets, so the move frees at least 595 bytes (795 − 2 × 100). That 595 is the budget, set by this design, for the combined net growth of the four edited steps; the new text there is pointers to `docs/check-scope.md` and to `skills/task/reference.md` § Step 12 rather than restated rules |
| `agents/self-review.md` | 32,220 bytes (measured, `wc -c`, this session), 2,780 below the threshold | It takes the eight changes listed under § The converging checklist, seven of which add text, and loses the cross-round re-derivation bullet (549 bytes, measured with `awk` `length` on its line, this session). The offset is that the ledger's example table, the trigger set and the script's verbs live on `docs/converging-review.md`, so each change in the contract is a sentence and a link. The net growth budget, set by this design, is at most 2,779 bytes, the measured headroom less one byte so that the file ends strictly below the threshold, and the net is counted as the bytes those seven changes add, minus the 549-byte bullet removed, plus the one-sentence strict-clause bullet kept in its place |
| `docs/workflow.md` | 34,993 bytes (measured, `wc -c`, this session) | The section headed "Why the attempt count lives beside the plan" moves into `docs/scouted-fix-round.md`, which links to it today and is the only page that does |
| `docs/templates/progress-format.md` | 34,684 bytes (measured, `wc -c`, this session) | In the `last_passed_gate` lifecycle entry, the sentence about the commit hash letting a re-entering subagent verify the tree is replaced by the digest sentence that now does that job. It is not added beside it |

### The gate record

**A new hook script, `hooks/lib/gate-record.sh`, writes the record.** It is wired on `PostToolUse` and
`PostToolUseFailure` with a `Bash` matcher. It runs after the call, so it never blocks and never costs a
call. The verdict comes from the event name, which is how `hooks/lib/loop-result.sh` already reads an
outcome. Measured on this session's loop ledger: a failed Bash call made inside a subagent has a `call` row
carrying that subagent's `agent_id`, and a `result` row with `ok: false`. That shows two things: the failure
event fires for a Bash non-zero exit, and subagents write into the parent session's ledger. The hooks
documentation also gives a Bash `Exit code 1` as its `PostToolUseFailure` example. The steps:

1. **Recognise covered gates.** The command is split into segments at shell separators. Leading environment
   assignments and redirections are stripped, and a `cd <dir>` segment updates the effective directory for
   the segments after it. A segment is a covered gate when it matches the gate vocabulary.
2. **Use one shared vocabulary.** The inline result-masking command in `hooks/hooks.json` defines three
   patterns, and all three move into a sourced file, `hooks/lib/gate-pattern.sh`, unchanged:
   - `G`, the gate pattern: a build or lint tool, a `bash`/`sh`/`zsh` invocation of a script whose path
     token carries `test`, `check`, `lint` or `verify` anywhere, directory parts included, or `jq` with its
     exit-status flag.
   - `B`, any `bash`/`sh`/`zsh` invocation of a `.sh` file or of `-n`, used to refuse two such calls joined
     with `&&`.
   - `L`, the loop-body pattern, used to refuse a gate run inside a loop.
   The result-masking command sources all three from there and keeps every test it runs. The gate record
   uses `G` alone, plus one more arm: a checked-in script whose path token carries `test`, `check`, `lint`
   or `verify`, executed directly without an interpreter prefix. That is how a skill script is invoked through
   its directory variable, and the fix-plan contradiction instance in the ticket was such an invocation.
   With one vocabulary the two hooks cannot drift apart. **When the file is absent or unreadable, or leaves
   `G` empty, both hooks fail open**, and the guard runs BEFORE the source rather than after it:
   `f=<path>; [ -r "$f" ] || exit 0; . "$f"; [ -n "$G" ] || exit 0`. A trailing `|| exit 0` on the `.`
   cannot do this job, because in a non-interactive POSIX shell a `.` that cannot open its file is a
   special-builtin error that ends the shell before the `||` is reached: `/bin/sh` on this machine, which is
   bash in POSIX mode, exits non-zero, and `/bin/dash` exits with the status a pre-call hook reads as a
   block (measured, `sh -c` and `dash -c` on an absent path, this session); only
   `bash` invoked as `bash` reaches the `|| exit 0`. The guarded form exits 0 under `/bin/sh`, `/bin/dash`
   and `bash` alike for an absent file, an unreadable file and a file that leaves `G` empty, and sources the
   file normally when it is present (measured with `sh -c`, `dash -c` and `bash -c` against fixtures under
   `/tmp`, this session). This matters because the result-masking command is inline in `hooks/hooks.json`
   and nothing states which shell runs it. The sibling hooks' `harness-managed.sh || exit 0` is not the
   same posture: it EXECUTES a script, whose failure is an ordinary non-zero status, where this file is
   sourced. A masking command that carried on with an empty `G` would refuse any pipe into `head`, `grep` or
   `sed`, and a gate record that carried on would record nothing meaningful. **A file that is present but
   does not parse is not covered by the guard** — the same measurement ended the shell with a non-zero
   status under both `/bin/sh` and `/bin/dash` — and is left to the profile's syntax check over every
   tracked shell file, which is the residue in § Risks.
3. **Normalise identity, so a prefix, a redirect or a working-directory spelling never makes a different
   gate.**
   - A script gate's identity is its path, resolved against the effective directory with variables the hook
     environment can expand. It is then expressed relative to the repository top level, or failing that
     relative to the plugin root. An unresolvable path falls back to its parent directory and basename.
   - A build-tool gate's identity is the tool plus its first non-flag word.
   - Each argument falls in one of three classes, decided without naming any project's runner:
     - a **path argument** resolves, against the effective directory, to an existing file or directory. A
       file is recorded as its normalised path joined to a hash of the file's content at the moment of the
       call, so a rewritten file is a different input even when the file is one version control ignores. A
       directory is recorded as its normalised path alone, because the tree digest already covers the
       content version control sees inside it. This is what keeps a module-addressed run, whose positional
       argument is a module directory and whose profile declares the selection flag `none`, keyed on the
       module it ran over;
     - a **selection argument** is a value of the selection flag that the project's `AGENTS.md` § Build &
       Test declares on its `**Selection flag:**` line, read from the repository top level. The value is
       taken in either spelling, the flag joined to it by `=` (`--only=a,b`) or the flag followed by the
       value as the next word (`--only a,b`), and the two produce the same class and the same key: the
       flag word itself is consumed in both and becomes no argument of any class. A comma-joined value is
       split and the members sorted. When the line is absent, reads `none`, or still carries an unfilled
       `%…%` token, no argument is in this class;
     - every other argument is a **mode argument**, such as a positional verb or an unrelated flag.
   - The **argument key** is all three classes, normalised. It identifies the invocation.
   - The **artefact key** is the path arguments and the selection arguments, without the mode arguments. It
     identifies what the verdict is about. A full run of a runner and a scoped run of the same runner
     therefore have different artefact keys, as do two different scoped selections — whether the scope is
     named through the selection flag or as a module directory — while one plan checked in two modes keeps
     one artefact key.
4. **Compute the input-set digest.** It is `scripts/tree-digest.sh` run at the repository top level of the
   effective directory. Outside a repository the digest is null, and the row takes part in no signal.
5. **Attribute the verdict as far as the exit status allows.** The command's exit status is the status of
   the last segment that ran. Each covered gate gets its own row, and its `ok` is set by the first rule that
   applies:
   - **An all-`&&` chain that exits zero:** every segment ran and passed, so every gate in it records
     `ok: true`.
   - **The final segment is a gate, not inside a pipeline, and not preceded by `||`:**
     - when it is the only segment or follows a `;`, the exit status is that gate's own, and is attributed
       to it in both directions, whatever gates ran earlier; **[REDLINE R1.6]**
     - when it follows an `&&` run, a zero exit records `ok: true`, because it ran and passed. A non-zero
       exit is attributed to it when no earlier segment of that run is a gate: the prefix segments — a `cd`,
       a fetch, any other command — are taken as succeeded, so a prefix's own failure would be attributed
       to the gate, which is part of the residue in § Risks. This is the rule that records the ticket's
       instance of a check answering one way bare and the other way behind a fetch prefix. When an earlier
       segment of the run is a gate, the failing one cannot be told apart and the final gate records
       `ok: null`.
   - **Everything else records `ok: null`:** a gate followed by a later segment, a gate inside a pipeline,
     a gate in an `||` chain, and every earlier gate of an `&&` chain that exits non-zero.
   A null-verdict row takes part in repeats and never in contradictions. The residue it covers is stated
   in § Risks.
6. **Detect signals at any distance.** The hook reads every earlier `kind: "gate"` row in the session's
   ledger, whatever agent wrote it and however long ago, filtered to the same repository.
   - A **repeat** is the same identity, argument key and digest.
   - A **contradiction** is the same identity, artefact key and digest with the opposite verdict. Equal
     digests at both invocations are the tree-unchanged condition, so fail, then fix, then pass is silent,
     while a flip across a remote fetch or a prefix change fires. One plan passed in one mode and refused
     in another over an unchanged tree fires, because mode arguments are not in the artefact key. A plan
     refused, rewritten and then passed is silent, because the rewrite changes its content hash. A scoped
     pass followed by a failing full run over an unchanged tree is silent, because the selection differs, and
     so is one module passing and another failing, because their directory paths differ.
   - When both apply, the contradiction is reported.
7. **Append the row.** It goes through `harness_ledger_append` in `hooks/lib/ledger-write.sh`, so the
   unwritable-ledger report stays the single one. The row carries `ts`, `kind: "gate"`, `gate`, `args`,
   `artefact`, `repo`, `digest`, `ok`, `agent_id`, `tool_use_id`, `cwd`, and `signal` (`null`, `repeat` or
   `contradiction`), plus the prior row's `tool_use_id`, `ts` and `agent_id` when a signal fired.
8. **Tell the calling agent.** The hook emits `hookSpecificOutput.additionalContext`, which the hooks
   documentation says is placed in Claude's context beside the tool result for both events. There is always
   one line, naming the gate, its exit status (zero or non-zero) and the tree digest. On a signal it adds
   one sentence naming the earlier invocation and what matched. It never emits a permission decision, and
   it exits zero unless the stderr fallback stated in § Risks, under subagent delivery, is adopted.

**The last-passed-gate field reads the record.** In `docs/templates/progress-format.md`, `last_passed_gate`
becomes four fields: `<gate command> | <timestamp or (not measured)> | <commit hash> | <tree digest>`. The
digest is copied from the hook's line for that run. The hook is the only place the stamp is recorded; the
one other source of a digest in that field is the measured fallback for a full-list command outside the
gate vocabulary, described in § Risks, which is marked as measured. The finalise steps compare the field
with a fresh `scripts/tree-digest.sh`.

**The record's contract is documented beside the other record classes.**

- `docs/loop-ledger.md` goes from five record classes to six. The new bullet covers the gate row and the two
  signals, and says they block nothing.
- `docs/hook-inventory.md` gains the hook's entry.
- `docs/claude-tools-hierarchy.md` gains the name `gate-record`, which carries no reserved event word.

### The inspection report

`scripts/loop-metrics.sh --for` emits a `gates` block. It holds the count of recorded gate rows, the counts
of repeats and of contradictions, and one entry per signal giving its time, gate, signal, agent and the
prior invocation. The text mode prints the two counts. `skills/inspect/SKILL.md` § Step 1b passes the block
to the agent, and `agents/inspector.md` states both counts in its report and names each contradiction.

### Findings a human raised

**A shipped script, `scripts/human-findings.sh`, is the instrument.** It has three modes, `--pr <n>`,
`--branch <name>` and `--merged [--limit <n>]`, and an optional `--json`. It reads pull-request data through
`gh`.

- **What counts.** One finding is one comment a person posted on the pull request: an issue comment, a review
  body, or an inline review comment, whose author is not a bot account. It is also one commit pushed to the
  branch after the pull request was opened, unless it is a version bump, the closing fold, or a merge commit
  (one with more than one parent), which carries no fix of its own.
- **Push times.** A commit records when it was made, not when it was pushed, so push times come from the
  hosting site's push-activity record for the branch: `repos/{owner}/{repo}/activity` read through `gh api`,
  filtered to the branch's ref and to pushes, and paginated. Each entry gives one push's timestamp and its
  before and after commits. The commits a push introduced are those reachable from its after commit and not
  from its before commit, read through the site's compare endpoint; a push with no before commit, which
  creates the branch, is compared against the pull request's base. A commit counts when a push timestamped
  after the pull request's `created_at` introduced it, and a commit introduced by more than one push counts
  once. The fold, version-bump and merge-commit exclusions apply to that set.
- **The record's reach.** The site keeps a bounded push history; the oldest entry on this repository's
  record was about 18 days old (measured, reading the record through `gh api` during the design review). The record reaches back to the opening only
  when its oldest entry for the branch is timestamped at or before the pull request's `created_at`. When it
  does not, pushes between the opening and that entry may be missing, so the script takes the cannot-compute
  exit for that pull request and never counts the commits it can see as the whole.
- **The closing fold.** The fold commit is the one that deletes an `ai-docs/plans/**/*.redline.md`. It does
  so on every run, because the fold runs only when a log exists and removes it. That is method-level, with
  no message pattern to drift.
- **Version bumps.** A version-bump commit is one whose changed paths all lie inside the project's declared
  bump paths. Those are a project fact, so they come from a new profile line,
  `**Version-bump paths:**`, in `ai-docs/context.md`. The line sits beside the `Deployed-config globs`
  line, which is the precedent for a hook or script reading a profile line. It is added to
  `templates/project/ai-docs/context.md` as `%VERSION_BUMP_PATHS%`, filled by `skills/harness-init/SKILL.md`
  (where `none` is valid), and set in this repository to the two plugin manifests.
- **When it cannot compute.** If the hosting site is unreachable, `gh` is absent, the profile line is
  missing, or the push-activity record does not reach back to the opening, the script takes the cannot-run exit with the reason and never prints a zero. The tally across merged pull requests
  lists every pull request it could not read and says the total is partial.

**Where the count is read.** It can be read on demand for one pull request, as a tally, and in the
inspection report. `skills/inspect/SKILL.md` gains a step that takes the session's branch from the
transcript's `gitBranch` field (measured present in this repository's transcripts) and runs the script in
`--branch` mode. A cannot-compute joins the `unavailable` list. `agents/inspector.md` reports the count.
The inspect skill's `allowed-tools` line gains the script.

### Sync groups

- **A new Check-Scope group in `docs/propagation.md`.** The anchor row is `docs/check-scope.md`, and its
  members are `skills/task/SKILL.md` Steps 8, 9, 11 and 12, `skills/task/reference.md` § Step 9 and
  `skills/task/reference.md` § Step 12, the bugfix
  skill's Steps 6 and 6.5, the whole-branch review's Steps 3 to 5, `docs/workflow.md` § Post-push,
  `docs/scouted-fix-round.md`, `agents/fix-scout.md` and `agents/fix-apply.md`. One mechanism is described
  in their separate vocabularies, which is the case the procedure's fourth point says a sweep cannot cover.
  Every member lies in a path class the propagation reminder already has an arm for, so the arm-derivation
  check gains no unguarded class. **[REDLINE S8.6]**
- **A Review-group member.** `docs/converging-review.md` joins the Review group's anchor row beside
  `agents/self-review.md`.
- **The template mirror.** The method may not name `templates/`, so the obligation that this repository's
  `AGENTS.md` Build & Test shape and the template's stay parallel is recorded under `AGENTS.md` §
  Project-specific conventions. That follows the precedent of the learning-log mirror.
- **Inspect group.** Its existing row already covers `loop-metrics.sh`'s emitted fields, the inspect skill
  and the inspector.
- **Spec-Amendment group.** The amendment-recipe sentence about the full reset is specific to the task
  workflow. The group's other members (bugfix, whole-branch review, reviewer, workflow) need no matching
  change, because they pass no plan documents. The sweep records that.

### Rejected alternatives

- **A reviewer-owned record file.** Costed above. The ignore-entry lag in existing consumers alone would
  break the tree-unchanged guarantee.
- **The amendment reset as a flag the orchestrator writes.** It is a second mechanism that can be lost
  between the amendment and the spawn. The plan digest is the same fact, recomputed.
- **One ledger row per checklist subsection, with no scope split.** Every item covers every file, so a
  one-line fix would reset everything. That is the measured failure itself.
- **A digest taken by staging into a temporary index.** It is exact, but it writes loose objects on every
  gate run. The chosen digest reads index stat data and hashes only modified and untracked files, without
  writing.
- **A gate's input set narrower than the tree.** A hook cannot know which files a gate reads. The spec
  defines a contradiction by the working tree being unchanged, and the tree digest is that condition.
- **A per-repository gate log in the git directory.** That would be a second record. The spec asks for one
  record that both the last-passed-gate field and the detector read. The field already carries the digest
  across sessions.
- **Selecting checks inside the runner from touched paths.** That is the automatic derivation the spec puts
  out of scope.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | The tree digest: whole-tree and path-list modes, ignored paths excluded, staging state ignored, nothing written to the object store, the cannot-run exit outside a repository | `scripts/tree-digest.sh` | AC13 | — |
| 2 | The review ledger script: `plan` (row recompute, two-half trigger naming, objected-finding reset, uncovered-path listing, plan digest with redline markers stripped, invalid and absent record handling) and `seal` (fills blank digests from the tree, refuses malformed rows and unknown triggers) | `scripts/review-ledger.sh` | AC1, AC2, AC3, AC4, AC5, AC7 | 1 |
| 3 | The converging reviewer: the reference page; in the reviewer contract, the breadth step, the ledger subsection in the findings format with the objection-quality item's always-swept `objections` row, the reworded APPROVE condition, the read carve-out, removal of the cross-round re-derivation bullet with the strict-clause reading rule kept, and the verdict's swept/carried line; the amendment recipes' full-reset sentence; the Self-Review lifecycle clause pointing at the ledger; the Review group's new member | `docs/converging-review.md`, `agents/self-review.md`, `skills/task/reference.md`, `docs/templates/progress-format.md`, `docs/propagation.md`, `docs/agent-docs-index.md` | AC1, AC2, AC3, AC4, AC5, AC6, AC7 | 2 |
| 4 | The gate record: the shared gate vocabulary file and the result-masking command sourcing it; both hooks failing open through a readability guard run before the source and an empty-`G` guard after it; the hook (recognition, identity normalisation, the three argument classes with file content hashes, directory paths and the profile's selection flag in its `=` and next-word spellings, digest, verdict attribution across `&&` and `;` chains, repeat and contradiction at any distance across agents, row append, `additionalContext` line); the wiring on both post-call events; the four-field `last_passed_gate` with its offset; the ledger, inventory and name-clash pages | `hooks/lib/gate-pattern.sh`, `hooks/lib/gate-record.sh`, `hooks/hooks.json`, `docs/templates/progress-format.md`, `docs/loop-ledger.md`, `docs/hook-inventory.md`, `docs/claude-tools-hierarchy.md` | AC13, AC14, AC15, AC16, AC17 | 1 |
| 5 | The profile half and the rule: the check-scope method page; `%FULL_CHECK_CMD%` in the method's placeholder set; the template's full-list row and touched-scope subsection with its selection-flag line; set-up filling them; `%FULL_CHECK_CMD%` alone on the audit's label list; this repository's Build & Test (narrowing `%TEST_CMD%`, `%FULL_CHECK_CMD%`, path rule, mapping, selection flag `--only`) and its template-mirror convention; the runner's `--only` with its reworded header | `docs/check-scope.md`, `docs/agents-method.md`, `templates/project/AGENTS.md`, `skills/harness-init/SKILL.md`, `scripts/audit-project.sh`, `AGENTS.md`, `scripts/run-checks.sh`, `README.md` | AC9, AC12 | 4 |
| 6 | The task loop: Step 8 item 1's test clause, Step 9 and Step 11 scoped; Step 12's move, build, single full run and digest compare, with its failure route (plan files moved back, reviewer spawned with the failing output, ordinary round) written in `skills/task/reference.md` § Step 12; the Step 8 and Step 12 offsets moved to the reference page; the reference page's Step 9 list and progress template; the fix-round page's post-resolution sentence and the attempt-count section received from the workflow page; the scout's verification field and the applier's re-run; the reviewer's scoped and narrowed re-run and final-check-failure input | `skills/task/SKILL.md`, `skills/task/reference.md`, `docs/scouted-fix-round.md`, `agents/fix-scout.md`, `agents/fix-apply.md`, `agents/self-review.md` | AC8, AC9, AC10, AC11 | 3, 5 |
| 7 | The other three loops: the bugfix verify step scoped and its standalone-only full run between approval and cleanup, with its failure route, skipped when the bugfix is reached from the task workflow or from the post-push round's Step 4; the whole-branch review's Steps 3 and 4 scoped and Step 5's single full run with its failure route; the post-push table row; the workflow page's offset; every `last_passed_gate` value these skills write carrying the digest | `skills/bugfix/SKILL.md`, `skills/bugfix/reference.md`, `skills/project-review/SKILL.md`, `docs/workflow.md` | AC8, AC10, AC11 | 5, 6 |
| 8 | Signals in the inspection report: the `gates` block in the per-session reader's JSON and text output, the skill's Step 1b hand-over, the inspector's reporting of both counts and of each contradiction | `scripts/loop-metrics.sh`, `skills/inspect/SKILL.md`, `agents/inspector.md` | AC17 | 4 |
| 9 | The human-raised count: the script with its three modes, push times read from the site's push-activity record with its reach check, the bot, fold, version-bump and merge-commit exclusions, and the cannot-compute exit; the version-bump profile line in the template, in set-up and in this repository; the inspect skill's branch-resolved step, its `allowed-tools`, and the inspector's report of the count; the README's inspect section | `scripts/human-findings.sh`, `templates/project/ai-docs/context.md`, `ai-docs/context.md`, `skills/harness-init/SKILL.md`, `skills/inspect/SKILL.md`, `agents/inspector.md`, `README.md` | AC18 | 8 |
| 10 | Sync and delivery: the Check-Scope group in the propagation table, the propagation sweep over every edited instruction file, and the plugin patch version bump | `docs/propagation.md`, `.claude-plugin/plugin.json` | AC8, AC12 | 6, 7, 9 |

## Handoff plan

- **(a)** Grouping is required for every M ≥ 1, a threshold the design contract hands down. Here M = 10, counted from the decomposition's rows.
- **(b)** Non-terminal groups are exactly 3 consecutive subtasks, a size the design contract hands down. The terminal group is subtask 10 alone.
- **Handoff into Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`.
- **Group A:** subtasks 1–3. This is the converging checklist end to end.
- **Handoff after Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. The parent /task resumes in Group B with fresh context.
- **Group B:** subtasks 4–6. It covers the gate record, the profile half and rule, and the task loop.
- **Handoff after Group B:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. The parent /task resumes in Group C with fresh context.
- **Group C:** subtasks 7–9. It covers the other loops, the inspection report, and the human-raised count.
- **Handoff after Group C:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. The parent /task resumes in Group D with fresh context.
- **Group D:** subtask 10. This is the terminal group: 1 subtask, within the 1..3 range.
- **(c)** The handoff destination at every boundary is `/context-reset`, as named above.
- **(d)** The terminal group size is within the 1..3 range.

## Risks

- **Scope exceeds seven tasks.** The contract's duty to propose a split was discharged: the split was put to
  the user, who chose one task and one pull request. The four handoff groups bound each implementation
  context instead.
- **Delivery of `additionalContext` to a subagent is documented for the main conversation only.** The hooks
  documentation says tool events fire inside subagents and carry `agent_id`. It does not say where the
  context string lands. The record and the inspection count do not depend on it. Only "shown to the agent
  at the moment" does, and only for subagent calls. The hook's line has to be observed in a subagent before
  the property is claimed. If it does not land there, the fallback is stderr on a non-zero exit, which the
  post-call event shows to the model without blocking. That fallback would be the one non-zero exit among
  the ledger hooks, and it would be stated as such.
- **A gate whose own input is an ignored file it is not given by name.** A path argument naming a file carries its
  content hash, so a gate handed an ignored file on its command line — the fix-plan check handed the
  progress file — sees a rewrite of that file as a new input, and a refused-then-rewritten plan raises no
  signal. A gate that finds an ignored input by convention rather than by argument is still keyed on the
  tree digest alone, which the spec rules an ignored-file edit does not move; such a gate re-run after that
  edit reports a repeat. The signal blocks nothing and names both invocations.
- **A shared vocabulary file that is present but does not parse.** The guard before the source fails open
  on an absent or unreadable file and on an empty `G`, but a `.` of a file with a syntax error still ends a
  non-interactive POSIX shell with a non-zero status, so a broken `hooks/lib/gate-pattern.sh` could block
  every Bash call through the result-masking command. That file is a tracked `*.sh`, so the profile's
  syntax check over every tracked shell file refuses it before it can ship; an edit made in a working tree
  and not yet checked is exposed until that check runs.
- **Verdicts the exit status cannot attribute.** A gate in a pipeline, a gate followed by a later segment,
  a gate in an `||` chain, and every earlier gate of a failing `&&` chain record `ok: null`, take part in
  repeats only, and can raise no contradiction. The result-masking hook already refuses most of these
  shapes for a shell gate, so the residue is mostly build-tool and `jq` chains. The opposite error is also
  accepted: a non-gate prefix joined by `&&` is taken as succeeded, so a failing prefix — a fetch that
  could not reach the remote — is recorded as the gate's failure, and can raise a contradiction the gate
  did not earn. The signal's sentence names both command lines, so the prefix is visible.
- **The objection-quality item departs from "round 1 sweeps every item".** The spec keeps round 1 unchanged,
  and the reviewer contract runs that item in later rounds only, so round 1's ledger has no row for it.
  From round 2 on it is swept every round, never carried.
- **Two triggers re-sweep items whose covered state did not change.** The spec's scope says a later round
  re-sweeps only the items whose covered state changed; its criteria require two exceptions, and the design
  follows the criteria. A finding marked objected re-sweeps its item with both digest halves matching
  (AC3), and an amendment that changes the agreed approach re-sweeps every item (AC5). The objection-quality
  row, swept every round from round 2 on, is a third case of the same departure. The `rule-changed` trigger
  is not one: the rule half of a row's digest is part of its covered state, so a changed rule text is a
  change of covered state.
- **The reviewer's re-run over an unchanged tree reports a repeat.** The narrowing stated for the reviewer among the loops limits the
  re-run to an author run that was piped or carries no matching gate-record digest. When it does happen
  over the tree the author's run was stamped against, the repeat is expected, and `docs/check-scope.md`
  says so.
- **A full-list command outside the gate vocabulary.** When a project's `%FULL_CHECK_CMD%` matches no arm,
  no record is written and no digest is reported. `docs/check-scope.md` then has the field take the digest
  the agent measures with `scripts/tree-digest.sh` immediately after the run, marked as measured rather
  than recorded. Set-up warns when the confirmed full command is unrecognised.
- **Late writes move the digest.** A learning-log entry or any other unignored file written after the
  passing final run changes the digest and forces another full run. That is the requirement working, and
  the check-scope page says so, so it does not read as a defect.
- **The runner reverses a deliberate decision.** `--only` contradicts the runner's header and the profile's
  "undivided by design". Both are reworded in the same change.
- **The gate-inventory span is load-bearing.** Any `bash scripts/<name>.sh` spelling added between the
  **Structural checks** and **Delivery gates** headings of `AGENTS.md` becomes an expected runner member.
  The touched-scope subsection sits after the delivery gates, and its mapping names members as `--list`
  prints them.
- **Protected pages ask before every edit.** `skills/task/SKILL.md` and `skills/task/reference.md` are on
  the edit-time refusal's page list. Each prompt is allowed, and the list does not change.
- **Push-record reach and attribution.** A pull request opened before the push-activity record's reach
  takes the cannot-compute exit, so a tally across older merged pull requests lists those as unread and
  says the total is partial. A rebase or amend pushed after opening introduces every rewritten commit
  again, and each counts. Comments an agent posts through the person's own account count as human. Both
  biases are stated in the script's output header rather than corrected.
- **Hook cost per gate call.** The digest reads index stat data and hashes only modified and untracked files.
  The signal scan reads the session ledger's gate rows. Both grow with the tree's change set and the
  session's length, not with the repository's history.

## Use cases

- `scripts/tree-digest.sh` — the gate-record hook calls it to stamp every covered gate run. The finalise
  steps of all four loops call it to compare the current tree against the last passed gate's stamp. The
  review ledger script calls it to hash a row's scope paths.
- `scripts/review-ledger.sh` — the reviewer uses `plan` at the start of every round after the first, to learn
  which rows to sweep, why, and which new paths need sweeping. It uses `seal` at the end of every round to
  fill the digests it recorded. This holds for every caller: task, bugfix, whole-branch review and post-push
  round.
- `docs/converging-review.md` — the reviewer reads it for the unit, scope and rule rules, the trigger
  vocabulary and the script's verbs. A whole-repository review reads it when judging a ledger.
- `agents/self-review.md` — the reviewer uses it to decide each round's breadth, to write and seal the
  ledger, to approve on swept-or-carried items, to re-run only scoped checks, and to turn a failing final
  run into findings.
- `hooks/lib/gate-pattern.sh` — the result-masking hook sources it to recognise a gate it may refuse. The
  gate-record hook sources it to recognise a gate it must record.
- `hooks/lib/gate-record.sh` — the client runs it after every Bash call in every agent of a session. It
  records each covered gate with its digest and verdict, and tells the calling agent the digest. It flags a
  repeat or a contradiction at the moment it happens.
- `docs/check-scope.md` — every loop's orchestrator reads it to select and state the scoped checks, to run
  the full list once after approval, to confirm the tree is unchanged before surfacing, and to route a
  failing final run.
- `scripts/run-checks.sh` — with `--only`, this repository's agents use it as the narrowing `%TEST_CMD%` inside every
  loop. Without the flag it is `%FULL_CHECK_CMD%` at each loop's end.
- `templates/project/AGENTS.md` touched-scope subsection and `%FULL_CHECK_CMD%` row — set-up fills them for a
  new project. Every loop reads them to resolve the selection and the full command.
- `scripts/loop-metrics.sh` `gates` block — the inspect skill passes it to the inspector, which reports the
  session's repeat and contradiction counts.
- `scripts/human-findings.sh` — a person or agent runs it on demand for one pull request, and as a tally
  across merged pull requests to see whether review bar drift is real. The inspect skill runs it for the
  session's branch.
- `**Selection flag:**` profile line — the gate-record hook reads it to tell a selection argument from a
  mode argument, so a scoped run and a full run of one runner are different artefacts. Set-up fills it.
- `**Version-bump paths:**` profile line — the human-findings script reads it to exclude version-bump commits.
  Set-up fills it.

## Open questions

- (none)
