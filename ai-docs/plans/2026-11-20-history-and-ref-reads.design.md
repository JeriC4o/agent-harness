# Design: History and ref reads that answer wrongly

**Ticket:** GH-189
**Date:** 2026-11-20
**Spec:** ai-docs/plans/2026-11-20-history-and-ref-reads.spec.md

## Approach

One rule throughout: a read that cannot answer stops as a could-not-run and names the command that cures
it, instead of handing its caller an empty answer to read as a fact. No script fetches.

**Two shared pieces.**

- **The shallow refusal**, a new script, `scripts/full-history.sh`. Given a path, it asks version control
  whether the repository holding that path is a shallow clone. If it is, it stops as a could-not-run with
  one line: the clone is shallow, history beyond its depth is not here, run `git fetch --unshallow`.
  Otherwise it passes silently. It never looks at its own location. The plan-freeze lookup, the checklist ledger and
  the release check run it first. The instruction pages run it before every walk of history they
  prescribe — the resume's lists of commits since a recorded commit, its tests of whether a recorded commit
  was rewritten or merged, the escalation audit's count of recent activity, the three-dot diff in the
  command reference — and before any plan freeze is committed.
- **A profile reader**, `hooks/lib/default-branch.sh`: the branch the `Default branch` row of the project's
  version-control table in `AGENTS.md` names, or nothing.

**Each read.**

- **Release check.** The change set runs from the fork point to the working tree, uncommitted work
  included, so a branch that changed nothing shipped passes whatever the tip's version. A base sharing no
  history with the branch is a could-not-run saying no fetch cures it. The base is confirmed present as a
  commit before any use, and every read keeps its status. The
  manifest's presence at the base is decided by listing the base's tree, so only a genuinely absent
  manifest reads as a first release. The version must be strictly above the tip's, each field compared as
  a number. A single-branch clone missing the default branch's ref is told
  `git remote set-branches --add origin <default> && git fetch origin <default>`. The helper that confirms
  a base is current refuses an absent commit given as is.
- **Freeze lookup.** Among the plan's freezes reachable from the head, it takes the one no other freeze of
  the plan descends from.
- **Branch protection** guards the branch either the profile or the remote's record names; with neither, the
  command passes with a notice saying how to name it.
- **Diff-range guard.** The base resolves as the remote-tracking ref, else the local branch; only a
  successful read listing nothing blocks.
- **Check runner.** A member ending as could-not-run is counted as such, apart from failures; the run ends
  with findings over could-not-run over clean. A suite that detects its own could-not-run leg, with no leg
  failing, ends as could-not-run.
- **Gate record.** A background launch is recorded with its verdict unknown and matched by nothing; every
  unknown verdict's notice says so. A `cd` it cannot resolve, or a check script outside both the repository
  and the plugin, gives the row unknown files. Contradiction compares the whole argument list. A command
  that only reads a check script records no run, a shell started only to parse it included.
- **Smaller.** The Learning Log fold stops, naming the fetch, when the default branch's remote-tracking ref is
  absent; a branch counts as pushed from its configured upstream or the remote's list of branches; the
  profile's merge style reads `merge-commit`; a fetch and adding a branch to the fetch list run unprompted,
  and `--upload-pack` in any abbreviation still asks.

```mermaid
flowchart TD
    C["a script, or a page step, reads history"] --> S{"shallow clone?"}
    S -->|yes| R1["could-not-run: run git fetch --unshallow"]
    S -->|no| P{"base, refs and objects present?"}
    P -->|no| R2["could-not-run naming the fetch that brings them"]
    P -->|yes| Q["read, keeping its status"]
    Q -->|failed| R3["could-not-run"]
    Q -->|succeeded| A["clean or findings"]
```

## Key decisions

- **One refusal, given its target.** Rejected: each script testing depth itself — the rule copied per
  caller; testing the script's own location — a project runs the scripts from an installed copy with no
  history.
- **The release check keeps reading the repository it ships from**, and hands that directory to the
  refusal: it is that repository's own delivery gate and runs nowhere else. Rejected: the working
  directory — a changed gate with no reader.
- **The release check's default base** ([release-base] in `scripts/check-release.sh`) is the profile's
  default, else the remote's record,
  else `main`, and the check refuses whenever the two name different branches, whatever base was passed,
  naming both and `git remote set-head origin <profile default>`. Rejected: refusing only the derived
  base — the criterion is unconditional.
- **Version order**: a missing field reads as zero; a field that is not a number is a could-not-run.
  Rejected: text order — it ranks a two-digit field below a one-digit one.
- **The profile reader serves branch protection and the release check only.** The diff-range guard stays
  silent on a failed read and the fold stops, so neither needs it.
- **The unknown-default notice is shown to the person with no permission decision**, so a push still asks.
  Rejected: an allow decision — it skips that ask.
- **An unresolvable folder is recorded as unknown.** Rejected: interpreting assignments made earlier in
  the command inside the hook.
- **A background launch** is told by the background flag in the tool's input, or by the launch reply the
  host returns in place of a result (verify on a real launch). A gate ended by a lone `&` keeps its present
  reading.
- **Two freezes neither of which descends from the other** are a could-not-compute naming both.

## Risks

- Every shallow checkout, a future CI checkout included, now refuses the release check, the freeze lookup
  and the checklist ledger: the refusal names the fetch, which runs unprompted, and loosening it is a
  separate open ticket.
- A clone whose remote's record is wrong refuses the release check even for an explicit base; the message
  names both branches and the remedy.
- The glossary sits just under its size warning (measured with `wc -m docs/glossary.md` on 2026-11-20:
  34,455 characters against the 35,000-character early warning the profile sets): the new entry is one
  short row, and the always-loaded task and method pages are not edited.

## Use cases

- `scripts/full-history.sh` — run first by the plan-freeze lookup, the checklist ledger and the release
  check on the repository each reads; run by the agent before each walk of history an instruction page
  prescribes and before committing a plan freeze; in a shallow clone it stops all of them with one line
  naming `git fetch --unshallow`; with full history it is silent; where version control cannot say, it is a
  could-not-run.
- `hooks/lib/default-branch.sh` — read by branch protection at every commit or push, to guard the profile's
  default beside the remote's record; read by the release check to derive its default base and to refuse
  when the remote's record names another branch; prints nothing for a profile without the row or still
  holding the template's placeholder, which both callers read as unknown.

## Collisions

- The knowledge-base work refuses shallow clones in its own tool by the same rule; when it lands it can call
  this refusal instead of carrying a second one.
- The default branch is then read two ways: from the profile and the remote's record (branch protection,
  release check), and from the remote's record alone (diff-range guard, fold).

## Open questions

- None.
