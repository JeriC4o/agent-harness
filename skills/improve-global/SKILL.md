---
name: improve-global
description: "Sweep promotion candidates across every registered project, find lessons that recur in two or more of them, and propose changes to the shared harness method files. Reads only sanitized candidates — never a project's raw learning log."
model: opus
disable-model-invocation: true
argument-hint: "[optional focus area]"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(scripts/collect-candidates.sh:*), Bash(scripts/check-candidate.sh:*), Bash(git branch:*), Bash(git status:*), Bash(git checkout:*), Bash(jq:*)
---

Cross-project half of the learning loop. `/harness:improve` escalates within one project; this command
looks across all of them and asks a different question: **is this a defect in the method itself?**

> **Run this in the harness repo**, not in a consuming project — its output is edits to method files
> (`docs/`, `skills/`, `agents/`, `rules/`, `hooks/`), which live here.

> **Branch gate — first action.** `git branch --show-current`. If it is the default branch, branch before
> any write (AXIOM 1).

## The data boundary — read this before Step 1

The sweep reads **only** `<project>/ai-docs/learnings/.promote/*.md`. There is no code path here that
opens a project's `learnings.md` or `learnings/*.md`, and you must not add one, not even to "check
context" on a candidate that looks incomplete. A candidate that cannot stand on its own is a candidate to
reject, not a reason to reach into the project.

If you find yourself wanting the original entry, that want is the signal the abstraction failed. Say so in
the report and let the project decide whether to rewrite it.

## Step 1: Collect

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/collect-candidates.sh
```

One JSON object per line: `{project, id, file, body}`. The script applies the eligibility rules —
`scope: shared` only, existing paths only, gate-passing candidates only — and reports skips on stderr.

**Read the stderr.** A refused candidate and a pruned project are both findings worth surfacing: the first
means a project tried to promote something it shouldn't, the second means the registry has rotted.

If nothing is eligible, say so and stop. That is a normal outcome, not a failure.

## Step 2: Cluster

Group candidates by the **rule they state**, not by wording or category. Two candidates belong to the same
cluster when applying one would have prevented the other's failure.

Record for each cluster: the rule, the distinct projects it came from, and the candidate ids.

## Step 3: Apply the threshold

| Cluster spans… | Verdict |
|---|---|
| **≥2 distinct projects** | **Promote** — propose a method-file edit. |
| 1 project, any number of candidates | **Hold.** Report it; do not edit a method file. |

The threshold counts **projects, not occurrences**, and the asymmetry is deliberate. Three occurrences in
one repo are evidence about that repo — its stack, its layout, its habits. One occurrence in each of two
repos is evidence about the method, because the only thing the two share is the harness. Promoting on
volume from a single project is how one project's quirk becomes everyone's rule.

## Step 4: Propose

For each promoted cluster, draft the smallest edit that would have prevented it, and name the target:

| Target | For |
|---|---|
| `docs/agents-method.md` | a workspace-wide AXIOM or permission rule |
| `docs/workflow.md`, `docs/code-style.md`, `docs/doc-convention.md` | narrative method detail |
| `skills/<name>/SKILL.md` | a rule that belongs to one workflow's steps |
| `agents/<name>.md` | a review or planning checklist item |
| `rules/ast-index.md` | search / tool discipline |
| `hooks/hooks.json` | a rule already stated in prose that keeps being violated anyway |

Two rules on shape, both from `docs/agent-writing-style.md`: a **correction** becomes a fail-loud AXIOM
with a trigger table; a **validation** becomes a soft `## Patterns` entry. Cross-shape (a soft verb on a
stick rule) is a defect the audit flags.

**Escalate to a hook only when prose has already failed** — the cluster shows the rule existed and was
violated regardless. A hook that encodes a rule nobody has broken yet is cost without evidence.

## Step 5: Confirm, then apply

Surface every proposed edit to the user with its evidence (rule, projects, candidate ids) and wait.
**Apply nothing without approval** — these edits change behaviour in every project that installs the
harness, which is precisely why this command is separate from `/harness:improve`.

On approval, apply the edits **yourself** (`Edit` / `Write`); do not delegate to a spawned subagent, which
cannot edit files under `~/.claude/**` and will report success on the half it could write.

The Propagation Rule fires on every one of these edits — a method-file change must reach its sync-group
siblings in the same PR.

## Step 6: Report

- promoted clusters, with target file and the projects that justified each
- held clusters (single-project), named so the next sweep can see them accumulate
- refused candidates and stale registry entries from Step 1's stderr
- candidates read, projects swept, projects skipped

Do **not** delete or edit a candidate in a consuming project — they are that project's files, and a
promoted candidate stays as the evidence the harness rule has a source.

## FORBIDDEN

- Reading any file under a project's `ai-docs/learnings/` other than `.promote/*.md`.
- Promoting a cluster that spans one project, however many candidates it holds.
- Editing a method file before the user approves it.
- Writing into a consuming project from this command. It reads projects; it writes only the harness.
