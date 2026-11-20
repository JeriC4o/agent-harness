# History and ref reads that answer wrongly

**Source:** ticket GH-189
**Date:** 2026-11-20
**Tracked in:** GH-189

## Scope

**Today.** Several of the harness's reads of version-control history and of branch references cannot
answer in some clones, and return an empty result or a status that their caller reads as a fact: "no
version raise needed", "never frozen", "no commits ahead", "not merged", "never left the machine", a pass
or a finding. The clones are a shallow clone, cut off at a depth; a single-branch clone, which fetches only
one branch; a partial clone, which downloads contents on demand from a source that may be unreachable; and
a clone of another working copy, which inherits that copy's checked-out branch as the remote's default.
Other reads answer wrongly in a full clone: the release check counts the default branch's own later
changes as the branch's, the check runner counts a check that could not run as a failure, and the gate
record writes rows for runs that had not finished or ran on other files. An audit on 2026-11-10 reproduced
every one of these cases, and a second, independent pass reproduced each again and narrowed several. A
later report adds two gate-record cases nobody has reproduced yet: runs the gate record credits to the
project's own check when that check never ran.

**Terms.**

- *Default branch* — the branch the project's profile names as its default.
- *Fork point* — the newest commit that a branch and the default branch's tip have in common.
- *Release check* — the delivery gate that refuses a branch which changed shipped content without raising
  the plugin's version; *shipped content* is what the plugin delivers to a project.
- *History-reading script* — a harness script whose answer depends on commits other than the head commit:
  today the plan-freeze lookup, the checklist ledger through it, and, once item 1 lands, the release check.
- *Shallow refusal* — the one shared stop every history read runs first (item 3).
- *The remote's record of its default branch* — what a clone holds locally about which branch the remote
  treats as default; a single-branch clone and a CI-style checkout hold none.
- *Gate record* — the plugin's log of each run of one of the project's known checks, kept with a
  fingerprint of the files the check ran on. After each run it tells the agent the check's verdict, and it
  warns when a check repeats on the same files or contradicts an earlier run there.
- *Merge style* — the profile's statement of how a human merges a pull request: squash, which lands one new
  commit and none of the branch's own, or merge commits, which land every commit of the branch.

**What this task delivers.**

1. **The release check measures from the fork point.** What a branch changed is measured from its fork
   point to its working tree, never from the default branch's tip. Its version is compared with the
   version on the default branch's tip and must be strictly above it. No rebase is required.
2. **The release check never reads an unreadable base as "no raise needed".** A base commit the clone
   lacks, a change set or manifest it cannot read, and a single-branch clone missing the default branch's
   ref are each a could-not-run, the last naming a remedy that actually brings the ref.
3. **A shallow clone is refused, once and loudly.** One shared check, run first by every history-reading
   script, by every history read the instruction pages prescribe, and by every step that records a plan
   freeze, stops with a could-not-run naming the fetch of full history. No partial answer is computed.
4. **The diff-range guard stops calling a correct diff empty** in a clone that has no local branch named
   after the default branch.
5. **The check runner reports a could-not-run as a could-not-run**, apart from failures, in its count and
   its overall status; a suite that detects its own could-not-run reports it the same way.
6. **The gate record stops writing wrong rows**: a background launch recorded as a pass, a run in another
   folder recorded against this one, and two runs with different arguments read as contradicting. Two
   cases the later report adds are reproduced first, and each is fixed if it reproduces: a copy of a check
   script run from outside the project recorded as the project's own check, and a command that only reads
   a check script's file recorded as a run of it.
7. **The smaller cases.**
   - (a) Branch protection protects the default branch in a single-branch clone whose default is not
     called main.
   - (b) A task branch pushed from a single-branch clone is no longer read as never having left the
     machine.
   - (c) The Learning Log fold stops instead of folding nothing and reporting success when the default
     branch's remote-tracking ref is absent.
   - (d) The plan-freeze lookup picks the newest freeze by ancestry rather than by commit time.
   - (e) This repository's profile declares merge commits as its merge style, the way its pull requests
     actually land, in place of squash.
   - (f) The release check refuses to compare against a base the remote's record calls default when the
     profile names a different default branch.
8. **The fetch a could-not-run names runs without a permission prompt**, in this repository and in a newly
   scaffolded project; the scripts themselves still never fetch.

## Out of scope

- **Refusing single-branch or partial clones as a class.** Only the reads that answer wrongly there are
  fixed; a single-branch or partial clone with the objects and refs a read needs keeps working.
- **Any script fetching on its own.** Each names the fetch and stops; the agent runs it.
- **Checks that read only the index or the head commit's tree** — the convergence check, the plan-invariants
  check, the link check, the tree digest, and every read of the head commit's id or tree. They read no
  history and get no shallow refusal.
- **Existing consuming projects' settings.** Scaffolding never overwrites a file a project already has, so
  only a newly scaffolded project receives the new permissions; an existing one adds them itself.
- **The pull-request-merged skill's own fetch allowance**, which it already grants itself, stays as it is.
- **The bugfix workflow's diff window.** The audit found it loud as written in every clone shape.
- **Whether the hosting site's branch protection forces branches up to date.** Unverified, and irrelevant
  once item 1 measures from the fork point.
- **Which merge methods the hosting site allows.** It allows squash, merge-commit and rebase merges alike;
  the profile records how the owner merges, and the site's setting stays the owner's.
- **The merge style a newly scaffolded project starts with.** Only this repository's profile changes; the
  scaffolding keeps its default.
- **Archived plans.**

## Deferred

- Which commands may run in a shallow clone once its history reaches what they need, and how deep a CI
  checkout must be for each | the refusal here is the safe starting point; loosening it is a separate
  decision | yes, #190 exists
- CI on every pull request, reading the check runner's status and the release check | the knowledge-base
  work's plan step for it waits on items 1, 2, the shallow refusal of item 3, and item 5 of this task | yes,
  #185 exists

## Key decisions

| Question | Decision |
|---|---|
| Is a shallow clone a supported environment? | No. Recording a plan freeze, reconciling with history and reading what a branch changed all need full history. Every history read stops with a could-not-run naming the fetch of full history, even when what it looks for happens to lie inside the depth. Support is decided by environment, not case by case. This is the ticket's decision, and the rule the knowledge-base work adopted for its own tool on 2026-11-10 |
| Are single-branch and partial clones refused as a class? | No. Items 2, 4 and 7 fix the reads that answer wrongly there, each with a could-not-run naming the fetch that actually works |
| Does any script fetch? | Never. A script stops and names the fetch; the agent runs it and re-runs the command |
| What does the release check measure? | The change set runs from the fork point to the working tree, uncommitted and newly added tracked files included, and the version must be strictly above the default branch tip's, each dot-separated field compared as a number. No rebase is required. The owner decided this on 2026-11-10 |
| Which branch is the default branch? | The one the profile names. The remote's record is a second source: branch protection guards the branch either source names, and the release check refuses when the two disagree. Neither silently picks one |
| What does branch protection do when neither source names a default branch? | It assumes no name. The commit or push goes through with a notice that the default branch is unknown and was not checked, naming how to state it. The case needs a harness-managed project whose profile lost its default-branch row and whose clone holds no remote record; a block there would stop all work on a branch the guard cannot name |
| What does the check runner's status mean? | Findings when any member found a problem; otherwise could-not-run when any member could not run; otherwise clean |
| May the agent fetch without asking? | Yes, in this repository's settings and the scaffolding's: a fetch, and adding a branch to a clone's fetch list. The owner allowed the fetch on 2026-11-10 and the fetch-list step on 2026-11-11. A fetch naming a program for the remote side to run still asks, because that option runs a command on this machine for a local remote; this carve-out is the ticket's, added on top of the owner's allowance |
| Does this task absorb the gate-record report about background launches (#156)? | Yes. Its whole content is item 6's background-launch case, its acceptance is part of this task's, and it closes with this task |
| Does this task absorb the newer gate-record report's two unreproduced cases (#192: a copy of a check script run from outside the project, and a command that only reads a check script's file, each recorded as a run)? | Yes, both, and each is reproduced before anything changes for it. A case that reproduces is fixed. A case that reproduces in no form tried gets no change, and the pull request closing the report says it was not reproduced, naming the forms tried; its criterion still binds the behaviour as it stands. The report's first case, the background launch, is item 6's. The report closes with this task. The owner decided this on 2026-11-20 |
| Which merge style holds (7e)? | Merge commits, replacing squash in this repository's profile, because that is how its pull requests land: the two pull requests merged since the audit landed as merge commits, read from the default branch's history on 2026-11-20, as had nearly every earlier one by the audit's own count. The effect: when the hosting site cannot say whether an earlier task's pull request merged, the default branch's history decides, behind the shallow refusal, and the owner is asked only when there is no commit of that task to look for. The owner decided this on 2026-11-20 |

## Technical constraints

- The shallow refusal judges the repository holding the file it was given, or the project directory, and
  never the folder the script itself sits in. In a consuming project every harness script runs from the
  plugin's installed copy, which has no history of its own and sits beside a one-commit shallow clone of
  the plugin (verified on the owner's machine on 2026-11-13, as the ticket records).
- Outcomes follow the three-outcome convention the harness already uses: clean, findings, could-not-run,
  each with its own status. A could-not-run is never a pass and never a finding.
- Reading the profile's default-branch row from a shipped hook or script is reading the project's own half
  of the rules; no method page gains a project fact.
- The knowledge-base work's CI step depends on items 1, 2, the shallow refusal of item 3, and item 5. If
  this task were ever split, those land first.
- Order of work, as the ticket asks: for every item, the wrong answer is demonstrated in the tree before
  the fix that corrects it. A reported case that cannot be demonstrated gets no fix.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | A branch that changed no shipped file since its fork point is accepted by the release check, with a message saying no shipped content changed, whatever version the default branch's tip carries and however far that tip has moved since the fork, with no rebase. |
| AC2 | The release check never counts the default branch's own changes after the fork point as the branch's. A branch is judged by what changed from its fork point to its working tree, committed, staged, unstaged and newly added tracked files alike, including before the branch's first commit. |
| AC3 | A branch whose shipped files changed since its fork point is accepted only when its version is strictly above the version on the default branch's tip, each dot-separated field compared as a number. An equal version is refused; a lower one is refused with a message naming the tip's version and saying the branch must raise its version above it. |
| AC4 | When the branch and the base share no history, the release check is a could-not-run naming that cause and saying no fetch cures it. |
| AC5 | Given a base the clone does not hold, such as a full commit id the clone lacks or a branch whose contents a partial clone cannot fetch, the release check is a could-not-run naming the missing object and the fetch that brings it; it never reports that no raise is needed or that this is a first release. The helper that confirms a base is current refuses an absent commit the same way instead of accepting it as given. |
| AC6 | A failure to read what changed, or to read the plugin's manifest at the base, is a could-not-run. Only a manifest genuinely absent at the base reads as a first release. |
| AC7 | In a single-branch clone missing the default branch's ref, the release check's could-not-run names a remedy which, once run, makes that ref present, after which the release check gives its verdict. Every instruction or message suggesting a commit id as the base says the commit must be present in the clone. |
| AC8 | When the remote's record of its default branch names a different branch from the profile's default branch, the release check is a could-not-run naming both. |
| AC9 | Every history-reading script, run in a shallow clone, stops before reading or writing anything, as a could-not-run with one message saying the clone is shallow and naming the fetch of full history, including when what it looks for lies inside the depth. That message never states an absent record such as no freeze, not merged or no commits ahead. |
| AC10 | In a clone with full history, the history-reading scripts answer as they would without the shallow refusal: a plan never frozen keeps its own reason, distinct from the shallow refusal, and a finding reads as a finding. |
| AC11 | The shallow refusal judges the repository holding the file it was given, or the project directory, never the folder its script sits in: run from a copy of the plugin with no history of its own, it answers normally for a full-history project and refuses a shallow one. |
| AC12 | No plan freeze is recorded in a shallow clone. Self-review's remedy for a missing freeze, the design review's renewed approval after rework, and a resumed task's freeze commit each stop at the shallow refusal first. |
| AC13 | Every history read the instruction pages prescribe is preceded by the shallow refusal, so in a shallow clone each ends at that refusal rather than at an answer: a resumed task's list of commits since a recorded commit, the tests of whether a recorded commit was rewritten or merged, and the Learning Log escalation audit's count of recent activity. |
| AC14 | No harness script fetches on its own. Every could-not-run that a fetch cures names that fetch and stops. |
| AC15 | In a clone holding the default branch only as a remote-tracking ref, with no local branch of that name, the diff-range guard does not block a three-dot diff of a branch that has commits ahead of the default branch. |
| AC16 | The diff-range guard says a branch has no commits ahead only when its read of history succeeded and listed nothing. A failed read never produces that message: the guard stays silent or says the base did not resolve. The published list of hooks says this guard blocks. |
| AC17 | The check runner counts members that could not run apart from members that failed, prints the could-not-run count in its summary, and ends with findings when any member found a problem, otherwise with could-not-run when any member could not run, otherwise clean. |
| AC18 | A suite of this repository that detects that one of its legs could not run, and has no leg that found a problem, reports could-not-run rather than failure, including when the only leg that cannot run is one needing an installed copy of the harness on the machine. |
| AC19 | A check launched with the host's background mode is recorded by the gate record with its verdict unknown, and its notice says the verdict is not yet known. No repeat and no contradiction is reported against that row, so a later foreground run of the same check on the same files is neither a contradiction nor a repeat of a pass. |
| AC20 | A check run in another folder, reached through a variable set earlier in the same command, is recorded against that folder's files, or with its files recorded as unknown; a row whose files are unknown is matched against nothing. |
| AC21 | Two runs of one check with different arguments are never reported as contradicting each other. |
| AC22 | Whenever a gate-record row's verdict is unknown, its notice says the verdict is unknown and never says the check exited zero. |
| AC23 | A check script whose file lies outside the project, such as a copy of one of the project's checks, is never recorded or announced as a run of the project's check on the project's files, whether it is run by its own path or from its own folder. |
| AC24 | A command that only reads a check script's file without running it, such as printing or searching it, records no run of that check and gives no notice of one. |
| AC25 | Branch protection blocks a commit or push on the branch the profile names as default, and on the branch the remote's record names as default where the clone holds one, including in a single-branch clone holding no remote record whose default branch is not called main. |
| AC26 | When neither the profile nor the remote's record names a default branch, branch protection assumes no name: the commit or push goes through with a notice that the default branch is unknown and was not checked, saying how to state it. |
| AC27 | A task branch pushed from a single-branch clone is treated as having left the machine: whether a branch was pushed is decided from its configured upstream or from the remote's own list of branches, never from remote-tracking refs alone. |
| AC28 | When the default branch's remote-tracking ref is absent, the Learning Log fold stops with a non-zero status naming the fetch, instead of folding nothing and reporting success. |
| AC29 | Where more than one freeze of a plan is reachable from the head, the plan-freeze lookup takes the one that no later freeze of the same plan descends from, whatever the commit times. |
| AC30 | This repository's profile declares merge commits as its merge style, no longer squash. So when the hosting site cannot say whether an earlier task's pull request merged, the default branch's history decides, by whether it holds a commit of that task, and the owner is asked only when there is no such commit to look for. |
| AC31 | In this repository and in a newly scaffolded project, the agent runs a fetch from a remote, and the step adding a branch to a clone's fetch list, with no permission prompt. A fetch carrying the option that names a program for the remote side to run, in any abbreviation the version-control tool accepts, still asks. |
| AC32 | Each wrong answer a script or hook gave before this task, if it returns, makes the project's check list report a problem; each case the audit found correct stays correct. |

## Open questions

- Whether cloud sessions or editors clone shallow, single-branch or from a local working copy is
  unverified. It changes nothing here: the refusal is decided by environment, and each fix holds in every
  clone shape.
- Whether the knowledge-base work's checks become members of the check runner is open there. Item 5's
  status rule is the same either way.
