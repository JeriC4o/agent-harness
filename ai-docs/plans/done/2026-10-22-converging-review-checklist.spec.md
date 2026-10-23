# A converging review checklist, a full check list that runs once at the end, and a gate record that knows what it ran against

**Source:** ticket GH-138 (with GH-140 folded in at the user's request)
**Date:** 2026-10-22
**Tracked in:** GH-138

## Scope

Four parts that share one record.

1. **The review checklist converges across rounds.** Today every self-review round re-sweeps every
   checklist item over the whole diff, however small the change since the previous round. Measured by the
   inspection pass on the session the ticket cites: round 3 reviewed a one-line fix and was the broadest
   and most expensive round of the session. After this task, a round after the first re-sweeps only the
   items whose covered state changed, and proves it by recomputing — never by trusting — a digest the
   earlier round recorded.
2. **The full check list leaves the loop.** Today a project's whole check list may run at every
   verification point of the implementation, review and fix loop; in this repository the test command IS
   the whole undivided list, documented as taking minutes, and the cited session ran it seven times in the
   loop. After this task:
   - inside the loop — implementation, verification, every self-review round and every fix round — only
     the checks the change touches run: a check runs when it reads a touched file, by a simple rule from
     the touched paths plus a hand-kept mapping, kept in the project profile, for the cases the rule
     cannot see;
   - the full list runs **once**, after self-review approves and immediately before the commit is
     surfaced;
   - if that run fails, the failure is handled as an ordinary fix round — scoped checks, a review round
     over the fix, approval — and then the full list runs again. A wrong or missing mapping entry is caught
     by this final run; no automatic derivation of checks from paths is built.

   The rule changes at every place that mandates a whole-list run inside the loop today: the task
   workflow's verify step and its per-subtask gates; the gates the task workflow's review-fix step runs
   after all findings are resolved, and the same sentence on the fix-round procedure page; the
   verification a fix round's plan names and its applying agent re-runs; the reviewer's instruction to
   re-run a gate it cannot reconcile; the task workflow's finalise step, which gains the single full run
   and admits a commit only after it; the project profile's Build & Test section, whose test command is
   the whole list and takes no narrowing argument by design; the project profile template and the
   project set-up flow that fills it, which gain the touched-scope selection; and the progress record's
   description of the last passed gate. The same rule reaches every other workflow whose loop ends in a
   commit: the bug-fix workflow (whose module-wide test run currently precedes its review), the
   whole-branch review's fix loop and final verification, and the fix round on an open pull request.
3. **A gate run knows what it ran against.** Every invocation of a covered gate records the state of its
   input set beside its verdict. That record is used diagnostically: a repeat run over an unchanged input
   set, and two verdicts from one gate about one artefact that disagree, are reported at any distance, in
   any agent of the session — to the agent at the moment it happens, and as a count in the inspection
   report. The record of the last passed gate can also answer whether the working tree changed since that
   gate passed, in a workflow that commits nothing until the end — which is what lets the finalise step
   confirm the full list passed over the tree being committed.
4. **Findings a human raised after the automated review passed are counted.** This is the instrument the
   ticket names to replace the removed bar-drift guard: if review bar drift is real, it surfaces as a
   non-zero count. Built in this task, at the user's request.

The cross-round re-derivation rule (re-verify every item against the rule file each round, on the ground
of bar drift) is removed, not softened, and not reinstated in a narrower form.

## Out of scope

- Answering a gate from its record instead of running it (a skip or cache). Dropped by the user's
  decision: once the full list runs only at the end, nothing in the loop re-runs it, so there is nothing
  to skip. Scoped checks are cheap and simply run.
- Deriving which checks to run from the touched paths automatically (GH-94). The touched-scope selection
  here is a simple rule plus a hand-kept mapping, and the final full run is what catches its mistakes.
- Deciding whether another review round is worth spending at all — the round-stopping question (GH-56).
  This task governs the breadth of a round that does run.
- A wider loop-detection window, or any change to how the existing per-call fingerprint is computed. Both
  of the ticket's instances defeat any window and any exact-input hash; the new signals are keyed on
  neither.
- Making the harness emit its own event stream in general (GH-53). Whichever route the design takes to
  write the gate record, a general event stream is not built here.
- Showing the loop detector a planted loop it could miss (GH-41).
- The closing fold's re-runs (GH-125).

## Deferred

- (none)

## Key decisions

| Question | Decision |
|---|---|
| Where the full check list runs | Once, after self-review approves and before the commit is surfaced — never inside implementation, verification, review or fix rounds. Settled by the user. Reason given: implementation against a spec is expensive, and a whole-list run is paid per loop iteration. |
| What runs inside the loop | Only the checks the change touches: a rule from touched paths to the checks that read them, plus a hand-kept mapping for the cases the rule cannot see. Settled by the user. Both halves are project facts and live in the project profile; the method states the rule and names neither. |
| A failing final run | An ordinary fix round: scoped checks, a review round over the fix, approval, then the full list again. Settled by the user. The converging checklist is what keeps that extra review round narrow. |
| A wrong mapping entry | Tolerated inside the loop; the final full run catches it. No mechanism guards the mapping's completeness. |
| A skip-from-record mechanism | Not built. Settled by the user. |
| Which other workflows the scoped-then-full rule reaches | Every loop that ends in a commit: the task workflow, the bug-fix workflow, the whole-branch review's fix loop, and the fix round on an open pull request. Settled by the user. |
| Where the per-item checklist record lives | Free. Either the task's progress notes (which needs a carve-out to the reviewer's ban on reading the orchestrator's fields) or a file the reviewer alone writes and reads; both are outside the commit. The design chooses, costing the reviewer-owned file first, as the ticket's amendment asks. |
| What keeps a carried item honest | A recomputable digest of the item's covered state and of the rule text it checks. The next round recomputes it from the tree; a record holding a bare claim, or one that cannot be recomputed, is treated as reset. |
| The bar-drift guard | Removed without a narrower replacement — settled by the user in the session that found the defect. The adjacent instruction to apply a rule's strict clause over its lenient one is a reading rule, not a cross-round one, and stays. |
| What resets the whole list | An amendment to the spec or the design that changes the agreed approach. A non-breaking correction recorded as a redline does not reset the whole list; the code fix it carries changes files, and the items covering those files reset on that ground alone. |
| First round | Unchanged: a full sweep. Convergence starts at the second round. |
| Who learns about a repeat or a contradiction | The agent, at the moment it happens, and the inspection report, as a count. Settled by the user. |
| The detector blocks nothing | Repeat and contradiction are signals, never refusals. |
| What counts as a contradiction | Opposite outcomes from one gate about one artefact **with the working tree unchanged between them**. Keyed this way, an ordinary fail-then-fix-then-pass sequence is silent, while all three of the ticket's instances fire: each crossed no tree change. A difference in state outside the tree (a fetched remote branch) is exactly what the signal should surface. |
| Gate identity across command-line variations | One gate is the gate itself, whatever surrounds its invocation: a prefix command, a redirect, or a different working-directory spelling does not make it a different gate. |
| What the human-raised count counts | Per pull request: each comment a person posted on it, plus each fix commit pushed to its branch after it was opened, excluding the closing fold commit and version bumps. Settled by the user. Review in this repository mostly happens in chat, so the pushed fixes carry most of the signal. |
| Where the human-raised count is read | For any one pull request on demand, as a tally across merged pull requests, and in the inspection report. The design chooses the instrument. |
| Applies to which reviewer callers | Any round after the first, from any caller, that finds an earlier round's record for the same task. The full-reset trigger lives where amendments are already routed, in the task workflow. |

## Technical constraints

- Every instruction file stays below the harness's 40,000-character cap (a threshold handed down by the
  method file). Several method files this task edits already sit just under the method file's
  35,000-character early warning, so growth in any of them must be offset by a cut elsewhere in the same file.
- Method surfaces may not name this repository's own gate list, tools or ticket prefix. Which checks read
  which paths, and which list is the full one, are project-profile facts; the method states the rule.
- The progress notes are ignored by version control, so an edit to them is not a change to any gate's
  input set; an untracked but unignored file is, because the structural check list examines it.
- The human-raised count needs the hosting site's pull-request data; where that is unreachable, the count
  reports that it could not be computed rather than reading as zero.
- Edits to instruction files propagate to their sync-group siblings in the same change.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | The first review round of a task sweeps every checklist item and leaves, per item, a record of what the item covered and a digest of the covered state and of the rule text it checks, which a later round can recompute from the tree alone. |
| AC2 | In a later round, an item whose recomputed digest matches its record, and under which no finding is marked objected, is carried closed and is not re-swept. Example: round two fixes one line in one file; round three re-sweeps only the items covering that file. |
| AC3 | A later round re-sweeps an item when a file in its scope changed, when the rule text it checks changed, or when a finding raised under it is marked objected; a file newly added to the change is swept by every item that applies to it. |
| AC4 | A recorded item that is missing, malformed, or whose digest cannot be recomputed is re-swept, never carried. Example: a record whose claimed digest no longer matches the tree, because someone edited the record rather than the code, is re-swept. |
| AC5 | After an amendment to the spec or the design that changes the agreed approach, the next round sweeps every item, whatever the records say. |
| AC6 | The reviewer's instructions carry no requirement to re-derive, on the ground of bar drift, an item whose recomputed digest matches; and none in a narrower form. |
| AC7 | Each round's report states, per item, whether it was swept or carried, and for a swept item after round one which trigger reset it, so a round's breadth can be counted afterwards. |
| AC8 | No instruction in force during implementation, verification, a self-review round or a fix round directs the full check list to run — in the task workflow, the bug-fix workflow, the whole-branch review's fix loop, or the fix round on an open pull request. Example: a task whose review takes three rounds with two fix rounds between them runs the full list zero times before the first approval. |
| AC9 | Inside the loop, the checks that run after a change are those that read a touched file, by the path rule or by the project's hand-kept mapping, and the run states which checks it selected and from which touched paths. Example: a change touching one file runs that file's own checks and any check the mapping ties to it, and no other. |
| AC10 | In each loop that ends in a commit (the four AC8 names), after self-review approves, the full check list runs exactly once before the commit is surfaced; the commit is not surfaced unless that run passed over the working tree as it now stands. |
| AC11 | When the final full run fails, the task returns to a fix round whose fix is reviewed and approved, and the full list then runs again; the commit is surfaced only after a passing final run that followed the last approval. A change made after the passing final run — of any file the list examines — requires it to run again before the commit is surfaced. |
| AC12 | The project profile and its template carry the touched-scope rule's project half — which checks read which paths, and the hand-kept mapping — and the full list, as separate entries; the method names neither a project's checks nor its paths. |
| AC13 | The record of the last passed gate tells whether the working tree changed since that gate passed, with nothing committed in between: an edit to any file the gate examines reads as changed; an edit only to the task's ignored progress notes does not. |
| AC14 | Every invocation of a covered gate in a session — from the main thread, any subagent, or by hand — records the gate, the digest of its input set and its verdict, and this is the record the last-passed-gate field and the detector both read. |
| AC15 | A second invocation of a gate over an input set whose digest equals an earlier invocation's in the same session is reported as a repeat, at any distance in calls or time and across agents, and whatever differs in the command line around the gate. Example: the full list runs in three different reviewer agents tens of minutes apart, with only progress-note writes between them; two repeats are reported. |
| AC16 | Two verdicts from one gate about one artefact with opposite outcomes and no working-tree change between them are reported as a contradiction, at any distance. Examples: a plan check that passes a fix plan in one mode and fails the same plan in another over an unchanged tree; a check answering clean and then present seconds apart, the second invocation carrying an extra prefix command. A fail followed by a pass across a tree change is not reported. |
| AC17 | A repeat or a contradiction is shown to the agent that caused it at the moment it occurs, without blocking the invocation, and is counted in the inspection report of that session. |
| AC18 | For a pull request, the count of findings a human raised after self-review approved can be obtained, and a tally across merged pull requests. One finding is one comment a person posted on the pull request, or one fix commit pushed to its branch after it was opened; the closing fold commit and version-bump commits are not counted. Example: a pull request with two human comments and three later commits — one fix, one fold, one version bump — counts three; where the hosting site's data cannot be read, the result says it could not be computed and never reads as zero. |

## Open questions

- (none)
