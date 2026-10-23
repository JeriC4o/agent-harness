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

