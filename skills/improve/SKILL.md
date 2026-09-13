---
name: improve
description: "Fold merged-branch learning files into the archive, then analyze the corrections-log union (ai-docs/learnings.md plus ai-docs/learnings/*.md), find repeating patterns, propose instruction updates and escalation to hooks."
model: opus
disable-model-invocation: true
argument-hint: "[optional context]"
---

## Fold — run this FIRST, before the spawn below

The Learning Log is the union of the archive `ai-docs/learnings.md` and the per-branch files `ai-docs/learnings/*.md`. The fold collapses merged-branch files back into the archive so the directory does not grow without bound.

**This runs in the PARENT (this skill), and the reason is ORDERING, not permissions.** The fold precedes the analysis passes — i.e. it happens before `self-improve` is spawned at all — so there is no subagent yet to delegate it to. It is **not** parent-side because of the harness-file permission carve-out below: that carve-out is about edits under `${CLAUDE_PLUGIN_ROOT}` / `~/.claude/**` silently failing in a spawned subagent, and it explicitly notes subagents *can* edit `ai-docs/**`, which is all the fold touches.

**Foldable set.** A file under `ai-docs/learnings/` is folded **only if** it exists on the default branch (`main`) **AND** is byte-identical there, and never the current branch's own file. Byte-identity — not mere existence — is the test: a still-open branch that appended more entries locally differs from `main` and is skipped, which excludes both a file this branch created and a file inherited from an unmerged stacked base. Full contract: `ai-docs/learnings/README.md` in the project being improved.

**The fold appends verbatim at EOF** — no sort-insert, no re-dating, no reformatting. A mid-file write into archived history would violate Boundary rule 1; an append does not. Canonical reading order across the union is the entry's own `### YYYY-MM-DD` header, so an out-of-order file position is not a correctness problem.

```sh
ARCHIVE=ai-docs/learnings.md
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
BASE=${BASE:-main}
abort() {                                            # a derivation failure is LOUD: rc=1, stderr, before any append
  printf '[fold] ABORT: %s. Nothing folded, nothing deleted; fix the derivation and re-run.\n' "$1" >&2
  exit 1
}

name=$(derive_name) || abort "derive_name failed (rc=$?)"     # a plain assignment DOES propagate rc — but only if it is TESTED
[ -n "$name" ] || abort "derive_name produced an empty name"  # the empty-SUCCESS case: rc=0, so the line above misses it
self="ai-docs/learnings/$name"                       # § Target file rule — the tree's only copy of the pipeline

ensure_nl() {                                        # append a newline iff the file lacks one
  [ -s "$1" ] || return 0
  if [ "$(tail -c 1 "$1" | wc -l)" -eq 0 ]; then printf '\n' >> "$1"; fi
  return 0
}

ensure_nl "$ARCHIVE"                                 # N1 — ONCE, ABOVE the loop

for f in $(git ls-tree -r --name-only "origin/$BASE" ai-docs/learnings); do   # repo-relative paths; silent + rc=0 when absent
  case "$f" in
    ai-docs/learnings/README.md) continue ;;         # G1 — the keeper is never folded
    "$self") continue ;;                             # G2 — skip self
  esac
  [ -s "$f" ] || continue                            # G0 — a zero-byte file would falsely compare identical
  git show "origin/$BASE:$f" | cmp -s - "$f" || continue   # byte-identity against the merged copy
  cat "$f" >> "$ARCHIVE"                             # verbatim, at EOF
  ensure_nl "$ARCHIVE"                               # N2 — after EVERY append, INSIDE the loop
  git rm -q "$f"                                     # source deleted; staged by auto-stage-learnings
done
```

**Both `derive_name` guards are load-bearing, and they cover different shapes.** Without them `self` silently becomes the bare `ai-docs/learnings/`, which no candidate ever equals — so G2 is **disabled while the loop completes and reports success**, and the fold consumes this branch's own live entry file into the append-only archive, where Boundary rule 1 makes it unremovable. `[ -n "$name" ]` uniquely catches **rc=0 with empty output** — the shape where `derive_name` succeeds and prints nothing, so no rc test can see it. `|| abort` uniquely catches **non-zero rc *with* output** — a partial name from a half-failed derivation, which composes a plausible-but-wrong `self` and disables G2 just as thoroughly. The two shapes that *look* like `|| abort`'s territory are not: a failing or undefined `derive_name` writes nothing to stdout, so `[ -n "$name" ]` already stops them and `|| abort` only buys the accurate diagnostic there (`failed (rc=7)` / `(rc=127)` rather than `produced an empty name`). Neither guard covers the other's own shape — but showing that takes a **five**-stub set: exercised only against `ok` / `empty` / `fail` / `undefined`, `|| abort` is indistinguishable from dead code. Both sit above N1, so an abort cannot leave a partially-normalized archive. Do not "simplify" either away: a gate that exercises only a working `derive_name` produces a byte-identical result with the guards removed, so it cannot see their absence — and a gate that omits the non-zero-rc-with-output shape cannot see `|| abort`'s absence either.

**Both newline calls are load-bearing, and their POSITIONS are the whole point.** Without them a source file that lacks a trailing `\n` makes the next file's `### ` header land on the previous file's last line — it stops being an entry header, so three entries folded yield a count of two — and the archive itself is left unterminated, so every later fold and hand-append glues too. Byte-comparing the appended region cannot see this: the appended bytes genuinely are identical, and the loss lives at the seam *between* chunks. **Keep N1 above the loop and N2 inside it.** Putting both inside makes N1-of-iteration-*k+1* the same operation as N2-of-iteration-*k*, so they mask each other and neither can be individually falsified.

`derive_name` is deliberately not spelled out here: the sanitization pipeline has exactly one home, [`${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` § Target file](${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md#target-file). Do not copy it into this file.

**ACCEPTED RISK — resurrection.** A merged branch that is re-opened and re-pushed between the fold and the merge re-adds already-archived entries. This surfaces as a visible **modify/delete conflict**, not silent duplication, and is accepted rather than mitigated — so the next reader hits a named case instead of an unexplained conflict.

Launch the `self-improve` subagent.

The subagent reads `${CLAUDE_PLUGIN_ROOT}/agents/self-improve.md` for full instructions.

The subagent will:
1. Read `ai-docs/learnings.md` **and** `ai-docs/learnings/*.md` — one concatenated history — for all correction records. The parent has already folded; the subagent does not fold.
2. Find repeating patterns (same mistake ≥2 times = `Kind: correction`; same topic ≥1 = `Kind: validation`).
3. Propose concrete diffs to `AGENTS.md` / `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` / `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` / a Skill / a Subagent file.
4. For mistakes that repeat ≥3 times despite existing rules — propose escalation to a hook in `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`.
5. Apply changes after user confirmation, on a feature branch.
6. Hand off Step 6 eval to the parent thread (this skill) — dispatch the reproducer prompts in fresh `Agent` contexts. Report PASS/FAIL per pattern.

> **Apply step (5) is performed by the PARENT/main orchestrator directly — NEVER delegate it to a spawned `general-purpose` agent (backgrounded or foreground).** A spawned subagent runs non-interactively and **cannot edit files under `~/.claude/**`** (the edit needs a permission prompt it can't answer), which is where an installed harness lives (`${CLAUDE_PLUGIN_ROOT}`), so delegated skill / agent / hook edits **silently fail** — the agent reports success on the `ai-docs/**` / `AGENTS.md` edits it *could* make while the harness half is dropped. The parent applies ALL the confirmed `/improve` edits itself with `Edit`/`Write`. (Only the **Step-6 eval** reproducers are dispatched to `general-purpose` agents — those agents only READ instruction files, never edit, so the permission limit does not apply to them.)
>
> **Escalation target — read this before proposing any harness edit.** A project-level `/improve` run escalates into the PROJECT profile (`AGENTS.md`, `ai-docs/context.md`, `ai-docs/code-style` overrides). Changing a METHOD file — anything under `${CLAUDE_PLUGIN_ROOT}` — changes behaviour for *every* project using the harness, so it is not this command's call to make: record it as a promotion candidate and let the harness repo's own review decide.

Run when **≥3 unescalated correction entries**, **≥2 unescalated validation entries**, or a `🌱 Stale-validation` flag from `/ai-audit` accumulates. Mirror of the threshold line in `AGENTS.md § Learning Log` — keep both in sync per the Propagation Rule.

## Step 6 dispatch contract

The `self-improve` Subagent cannot itself spawn `Agent` calls. After the Subagent returns its proposal, the parent (this skill) reads the `## Step 6 handoff — clean-context eval reproducers` block and dispatches each reproducer via `Agent(subagent_type="general-purpose", prompt=<reproducer-block-verbatim>)`. Collect verdicts; emit a final `Eval: PASS ✅ / FAIL ❌` per pattern.

**Dispatch each reproducer VERBATIM; never narrow the governing-file list** — do not hint a subset of instruction files in the spawn prompt. Restricting the eval agent to a hand-picked file set defeats the contradiction-catching purpose (an eval that only sees the rule's supporting file cannot surface a conflicting mandate in another file). See `self-improve.md § Step 6 → Reproducer framing`.

## See also

- `/ai-audit` (`${CLAUDE_PLUGIN_ROOT}/skills/ai-audit/SKILL.md`) — passive auditor for already-escalated entries.

Context from user (if any): $ARGUMENTS
