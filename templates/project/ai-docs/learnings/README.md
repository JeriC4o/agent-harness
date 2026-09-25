# Learning Log — per-branch entry files

New Learning Log entries are authored here, one file per user per branch. `ai-docs/learnings.md` is
the **archive**: it holds the existing history and is the destination of the periodic fold below. It
is not an index — there is no index file.

## Where a new entry goes

`ai-docs/learnings/<username>-<branch>.md`. The derivation — the two commands it reads, the
sanitization it applies, the worked examples, and the default-branch case — is stated **once**, in
[`${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` § Target file](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md#target-file).
Link to it; never restate it here or anywhere else. A second copy is a drift surface. The one thing
worth repeating, because the fold's skip-self guard depends on it: that derivation returns the
**basename including `.md`**, and the fold appends no extension of its own — a stem-only derivation
disables the skip-self guard silently and lets the fold eat this branch's live entry file.

Files in this directory use the **same entry format** as the archive — no per-file front matter, no
per-file `## Format` block, no new fields.

## The union — one single history

`ai-docs/learnings.md` **plus** every `ai-docs/learnings/*.md` are ONE history, exactly as if all the
files were concatenated. No consumer may read only one of the two. Canonical reading order is by each
entry's own `### YYYY-MM-DD` header; where dates tie, archive entries precede directory entries. File
position carries no chronology signal across files.

**Canonical operand string** — quote it verbatim wherever a consumer sweeps or reads the union:

    ai-docs/learnings.md ai-docs/learnings/*.md

Carry `-H` on every widened `grep` over those operands: with exactly one readable operand `grep` drops
the `filename:` prefix, and a consumer parsing `file:line:` silently loses the path.

This `README.md` is also the keeper that guarantees `ai-docs/learnings/*.md` always expands — so the
operand set stays well-defined and no unexpanded-glob warning reaches stderr to be misread as an
error. Never delete it, and never fold it.

The directory also has **one subdirectory**, `.promote/`, which plays by different rules: it holds
promotion candidates bound for the cross-project sweep, not log entries, and its contract is its own
[`.promote/README.md`](.promote/README.md). The fold never enters it — see the foldable set below.

## Fold contract — owned by `/improve`

The fold runs in the `/improve` **parent**, before the `self-improve` subagent is spawned. It is
parent-side because of that ordering, not because of any permission carve-out.

**Foldable set**, in order:

1. **Directly in this directory only** — nothing under a subdirectory, at any depth. The iteration set
   comes from `git ls-tree -r`, which recurses, so this exclusion has to be written; it does not come
   for free. It is expressed as *nesting*, not as the name `.promote`, so the next subdirectory added
   here is safe on the day it is created rather than on the day someone remembers to name it.
2. **Skip self** — the file this run would itself append to (the live append target for the branch in
   progress).
3. **Default-branch identity** — keep a candidate only if it exists on the default branch (`main`) AND
   its working-tree bytes are byte-identical to the bytes there. Everything else is skipped: a
   still-open branch that appended more entries locally differs from `main`, so its file is left alone.
   Existence alone is not the test; identity is.
4. **Keeper** — this `README.md` is never a candidate.
5. **Entry files only** — a non-entry file placed directly in this directory (a `.txt`, a stray note) is
   not the archive's to take.
6. **Non-empty** — a zero-byte file would compare identical to anything and must not qualify on that.

**Before any of the above runs, the fold checks its own name derivation**, because every filter in the
list depends on it. Three failure shapes are refused, loudly and before the archive is touched at all:
an empty name, a non-zero exit from the derivation, and — the one the other two structurally cannot
see — a derivation that SUCCEEDS and is WRONG, detected by finding a file for this branch under a
different username. That last case is the dangerous one: it returns a plausible name, so nothing about
it looks like a failure, and the skip-self filter then protects a path that does not exist while the
live append target stays eligible.

**Append and delete.** Each folded file's bytes are appended **verbatim at EOF** of
`ai-docs/learnings.md` — no sort-insert, no re-dating, no renumbering, no reformatting — and the
source file is then deleted. Appending at EOF is what keeps Boundary rule 1's no-reorder guarantee
intact for already-archived entries; a sort-insert would be a mid-file write into archived history.

**Trailing-newline normalization is part of the algorithm, not a nicety.** A source file that does not
end in a newline makes the next file's `### ` header land on the previous file's last line, where it
stops being an entry header — three entries folded, two survive — and it leaves the archive itself
unterminated, so every later fold and hand-append glues too. The archive's tail is normalized **once,
before the first append**; each appended chunk is normalized **after it lands**. Comparing an appended
chunk against its source cannot see this failure: those bytes genuinely are identical, and the loss
lives at the seam *between* chunks. Verification therefore needs an entry-count leg over two or more
files in one run, not a byte comparison.

#### Accepted risk — resurrection of a re-opened branch

A merged branch that is re-opened and re-pushed **between** the fold and the merge re-adds entries the
fold has already archived. This is an accepted risk, not a mitigated one: it surfaces as a visible
**modify/delete conflict**, never as silent duplication, so the next reader meets a named case rather
than an unexplained conflict.
