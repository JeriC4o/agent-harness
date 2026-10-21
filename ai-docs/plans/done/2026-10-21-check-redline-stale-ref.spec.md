# Gates that read a remote-tracking ref must not pass on a copy they cannot show is current

**Source:** ticket GH-139
**Date:** 2026-10-21
**Tracked in:** GH-139

## Scope

1. **The redline check's pending question in its ref form** — the form that reads a named ref's tree
   instead of the worktree. Today, when that ref is a remote-tracking ref that resolves but points at an
   older commit than the remote holds, the check reads the old tree and reports clean. A caller that
   skipped the fetch is turned into a pass. The ref form gains a currency leg: for a remote-tracking ref
   it asks the remote for that branch's current tip, and reads the tree only when the local copy matches
   it; otherwise it reports **cannot-run**.
2. **The release check** (the delivery gate that refuses a branch which changed shipped content without
   bumping the plugin version, run before opening a PR). It compares the working tree against a base ref
   that defaults to the local copy of the remote default branch, and today it refuses only when that ref
   does not resolve at all. A stale base yields a wrong answer in either direction: changes already on
   the default branch read as this branch's own, and a version bump already on the default branch reads
   as this branch's bump. It gains the same currency leg, with the same outcomes.
3. Each cannot-run output is actionable without the calling workflow open. When the ref is stale, its
   remote is unreachable, or the remote no longer has the branch, the output names the ref, the remote,
   and fetching that remote as the remedy. When the ref lives among the remote-tracking refs but no
   configured remote maps it, there is no remote to name: the output names the ref, states that no
   configured remote maps it, and gives the remedy — configure the remote, or pass a commit id.
4. The instructions that describe either check — the post-merge cleanup workflow, and the repository's
   own description of the release gate — stay consistent with the new behaviour, including that the
   release gate, when its base is a remote-tracking ref, needs the remote reachable and reports
   cannot-run when it is not; a commit-id or local-branch base makes no remote contact.

## Out of scope

- The worktree form of the redline check (no ref argument). It reads the files in front of it; there is
  nothing to be stale against.
- The hardcoded default-branch name, both in method files and as the release check's default base —
  owned by GH-77 (the "literal" half of this family; this ticket is the staleness half). This task
  leaves the release check's default base as it is and adds only the currency leg.
- Any other verb of the redline check.
- Making either check fetch. The chosen route changes nothing locally; the fetch stays with the caller,
  and the post-merge workflow's existing fetch line stays where it is.

## Deferred

- *(none)*

## Key decisions

| Question | Decision |
|---|---|
| Definition of Done, recorded verbatim from the ticket | "with a ref argument, the gate either fetches it itself, or compares it against the remote and reports **cannot-run** when it cannot show the ref is current"; "a stale-tracking-ref fixture … asserts **rc 2** — and explicitly not rc 1, because there is no comparand and a finding would claim one"; "whichever route is chosen, the cannot-run message names the missing fetch". Turned into the permanent obligations AC1–AC4 rather than one-time checks. |
| Fetch, or ask the remote? (user, round 1) | **Ask the remote for its tip and refuse if the local copy differs.** Neither check performs a fetch or alters any local ref. Whether a remote-tracking ref is current is a fact about the remote, so no local-only read can establish it; contacting the remote is therefore unavoidable for a remote-tracking ref, and is read-only. |
| Where the release check's staleness fix goes (user, round 1) | **In this task**, under the same contract as the redline check. |
| Which refs get the currency leg | Remote-tracking refs only. A commit id is immutable and a local branch names no remote it could be behind, so both are read as given with no remote contact — keeps the existing behaviour for callers that pass a commit id, and is the deliberate absence that keeps offline callers working. |
| A local copy that differs from the remote tip in any direction (behind, ahead, diverged), or a branch the remote no longer has | Not shown current → cannot-run. The claim each check makes is "the tree I read is the remote's tree"; any mismatch voids it. |
| Remote unreachable | Cannot-run, with the remote named. Never a pass, never a finding, and no fallback to reading the local copy. |
| Offline callers of the release check | Verified: the repository's single-call check runner lists the release check as exempt and never runs it, and the runner's own test uses a stub in its place; no other script or test invokes it. So no sandboxed caller is affected. A caller with no remote can still pass a commit id or local branch as the base and is read as given. |
| Exit-code convention | Unchanged for both checks: 0 clean / fine, 1 findings / bump missing, 2 cannot run — and a cannot-run is not a pass. |

## Technical constraints

- Verdict-line shape and exit codes of both checks are kept for the current-ref cases; callers parse them.
- The redline check's worktree form must keep working in a repository with no remote configured.
- Contacting the remote must not change any local ref or object the caller would observe.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Given a remote-tracking ref whose remote branch has since moved to a newer commit, and no fetch since, the redline check's pending question in ref form exits 2 (cannot-run). It never reports clean, and never reports a finding (exit 1), because a stale ref is no comparand and a finding would claim one — this holds whether or not the stale tree carries a redline log. |
| AC2 | Whenever either check exits 2 because its ref is stale, its remote could not be reached, or its remote no longer has the branch, its output names the ref, the remote, and fetching that remote as the remedy. When it exits 2 because the ref is a remote-tracking ref that no configured remote maps, its output names the ref, states that no configured remote maps it, and gives the remedy of configuring the remote or passing a commit id. |
| AC3 | Given a remote-tracking ref that matches its remote's tip, the redline check's ref form behaves as before: exit 0 naming the ref when that tree holds no redline log, exit 1 naming each log when it holds one. |
| AC4 | Given a remote-tracking ref whose remote is unreachable, either check exits 2 and says the remote could not be reached; neither falls back to reading the local copy. |
| AC5 | Given a commit id or a local branch name as the ref, either check reads that tree as given, with no remote contact, exactly as before. |
| AC6 | The redline check's worktree form is unchanged in behaviour and makes no remote contact. |
| AC7 | Given a base that is a remote-tracking ref whose remote branch has moved since the last fetch, the release check exits 2 — neither "no bump needed", nor "OK", nor "bump required" — whatever the branch's own changes and version. |
| AC8 | Given a current remote-tracking base, the release check's verdicts are as before: fine when no shipped content changed or the version moved, refused when shipped content changed and the version did not. |
| AC9 | After either check runs, every local ref and the local copy of the remote branch point where they pointed before. |
| AC10 | The post-merge cleanup workflow still refuses on anything but a clean 0, and the description of the release gate says that, when its base is a remote-tracking ref, it needs the remote reachable, that a commit-id or local-branch base makes no remote contact, and that its cannot-run is not a pass. |

## Open questions

- *(none)*
