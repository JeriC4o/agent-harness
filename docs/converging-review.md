# Converging review

How a self-review round after the first decides which checklist items to sweep again. Pointed at from
[`${CLAUDE_PLUGIN_ROOT}/agents/self-review.md`](${CLAUDE_PLUGIN_ROOT}/agents/self-review.md), which keeps
the obligations and links here for the mechanics. Round 1 sweeps every item, as it always has. From
round 2 on, an item is swept again only when what it covered changed, when the rule it checks changed,
when a finding raised under it is objected, or when the plan it was checked against was amended.
Everything else is **carried**, and a carried item is proven by a digest recomputed from the tree, never
by the earlier round's word.

## The ledger

Each `## Self-Review (Round N)` section ends with a `### Checklist ledger` subsection, written in full
every round, so a later round reads only the latest one. Two header fields and one table:

```markdown
### Checklist ledger

**Plan digest:**
**Base:** `<the diff base this round reviewed against>`

| Item | Scope | Rule | Digest | Findings | State | Trigger |
|---|---|---|---|---|---|---|
| 1 | diff | ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#1-spec-conformance | | — | swept | first-round |
| 5 | src/a.sh | ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#5-style ai-docs/context.md#language-profile | | 3 | swept | scope-changed |
| 5 | src/lib | ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#5-style ${CLAUDE_PLUGIN_ROOT}/docs/code-style.md#comments | | — | carried | |
| 7 | objections | ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#7-objection-quality | — | — | swept | objected |
```

The reviewer writes the Plan digest field and every Digest cell **blank**; the seal fills them (§ The
script). One row per **(item, scope)**:

- **Item** — the number of one of the reviewer contract's numbered checklist subsections.
- **Scope** — what the row covered: a space-separated list of repo-relative paths (a directory covers
  everything under it), the token `diff`, or the token `objections`.
  - `diff` is every path in the change at the moment of hashing: files changed since the base, plus
    untracked files no ignore rule covers. It suits an item whose verdict depends on the change as a
    whole — spec and design conformance.
  - An item whose checks are local to a file — safety, style, documentation, tests — takes one row per
    file or per file group. **That split is the whole point:** a one-line fix in one file then resets
    only the rows covering that file. One row per item over everything is the shape that never converges.
  - `objections` belongs to the objection-quality item alone, whose subject is the set of objected
    findings rather than any file. From round 2 on it has exactly one row, Digest `—`, always `swept` /
    `objected` — sweeping it over an empty set is how the set is confirmed empty. Round 1 writes no row
    for it, because that item runs from round 2 on.
- **Rule** — the rule text the row checks, as space-separated `path#slug` references. The item's own
  subsection of the reviewer contract is always listed; add any rule page the item applies, such as the
  code-style reference or the project's own profile. A slug is the heading's GitHub anchor, or any prefix
  of it ending before a `-` that names exactly one heading, so `#5-style` names the Style item. A
  reference spelled `${CLAUDE_PLUGIN_ROOT}/<path>#slug` resolves against the plugin root, and a bare
  repo-relative `<path>#slug` against the project working tree — the split method files already use, so
  a project's own profile is hashed from the project, never from the plugin's shipped copy. The section runs to the next heading of
  the same or a higher level, so a nested subsection belongs to its parent.
- **Digest** — two 12-hex prefixes joined by a dot: the scope's content hash, then the hash of the
  resolved rule sections. Two halves let a mismatch name its trigger.
- **Findings** — the numbers of this round's findings raised under the row, or `—`.
- **State** — `swept` or `carried`.
- **Trigger** — empty for a carried row; for a swept row, one token from the closed set below.

**Plan digest** is a digest of the plan documents the caller passed: each `--frozen` document as it stood
at the plan's latest freeze, read through `${CLAUDE_PLUGIN_ROOT}/scripts/plan-freeze.sh`, and each
`--plan` document as it stands; `none` when the caller passed neither. Text is hashed, never a path or a
commit id, so the plan's move into the archive and a rebase of the branch leave it where it was.

## Triggers

| Trigger | The row was swept because |
|---|---|
| `first-round` | this is round 1 |
| `scope-changed` | the scope half of its digest differs: a file it covers changed, or for `diff`, a path entered or left the change |
| `rule-changed` | the rule half differs: a section it cites was edited |
| `objected` | a finding raised under it is marked objected, or it is the `objections` row |
| `new-file` | a path in the change that no recorded scope names; every applicable item sweeps it and gains a row for it |
| `record-invalid` | the row, or the whole ledger, is missing, malformed, or cannot be recomputed |
| `amendment` | the plan digest differs from the recorded one |

**A `diff` row names no path.** A path covered only by a `diff` row is still listed as `new-file`, so the
file-local items reach it; the `diff` row itself resets through `scope-changed` when the change's path set
moves.

**The full reset is the plan digest, and only the task workflow passes plan documents.** Its rounds and
its follow-up rounds on the open pull request pass `--plan <spec> --frozen <spec> --frozen <design>`. The
frozen half moves when a new freeze is taken at a design-review GO, and the live half when an approved
amendment changes the spec, so either sends the next round to sweep every item. A design corrected in
place after the freeze moves neither half; the code change the correction describes resets the rows
covering the files it touched. The bug-fix workflow and the whole-branch review pass no plan documents, record `none`,
and never reset on this ground.

## The script

`${CLAUDE_PLUGIN_ROOT}/scripts/review-ledger.sh` does all the hashing and comparing; the reviewer computes
no digest by hand. Invoke it as its own call, like any other shell script.

- **`plan <findings-file> --base <rev> [--plan <path>]… [--frozen <path>]…`** — at the start of every
  round after the first. It reads the latest round's ledger and that round's findings table, recomputes
  every row from the tree, and prints one line per row — `carry <item> <scope>` or
  `sweep <trigger> <item> <scope>` — then one `new-file <path>` per uncovered path, then a verdict line
  with the totals and whether the whole list was reset. With no ledger in the latest round it prints
  `sweep record-invalid <item>` for every item. Exit 0 on a computed plan, 2 when it cannot run.
- **`seal <findings-file> [--plan <path>]… [--frozen <path>]…`** — after the round's ledger is written. It
  fills every blank Digest cell from the tree as it stands, writes `—` into a blank `objections` cell, and
  fills a blank Plan digest from the plan documents given, or `none`. It refuses — exit 1, nothing written
  — a malformed row, a state other than `swept` / `carried`, a trigger outside the closed set or on a
  carried row, an unresolvable rule, a missing or unknown base, and a typed digest that differs from the
  recomputed one. Sealing from the tree is what keeps a carried claim from ever being a bare assertion.
  Exit 2 when it cannot run.

Pass the same `--plan` and `--frozen` documents to both verbs. A `--frozen` document whose frozen text
cannot be resolved — no freeze of its plan, or a freeze that does not hold it — is a cannot-run of either
verb.

## A round after the first

1. Run `plan` with the round's base and plan documents.
2. Sweep exactly the rows it marks `sweep`, plus every applicable item over each `new-file` path, adding
   rows for them with the trigger `new-file`. Sweep the objection-quality item over the objected findings.
3. Write every `carry` row back as `carried`, Digest blank, Trigger empty.
4. Write the ledger, then run `seal`.

**On a cannot-run from `plan`, sweep every item and say so in the verdict.** A refused `seal` is fixed and
re-run before the verdict is returned.

**What stays as it is.** Every earlier finding's status is still evaluated each round — fixed, objected,
still open. That is finding-level work, not a checklist sweep, and it is small.

A whole-repository review reads this page when it judges a ledger.
