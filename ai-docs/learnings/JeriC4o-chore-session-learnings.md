# Learning Log — JeriC4o / chore/session-learnings

### 2026-09-24 — tooling — the apostrophe hazard, fourth recurrence, first inside hooks.json
**What happened:** Rewording a hook message to "OVERRIDES the agent's generic default" put an apostrophe
inside a single-quoted `printf` format, inside a shell command, inside a JSON string. It closed the
string. The hook died on a syntax error at dispatch and **silently stopped gating**, while `jq .` still
reported the manifest as valid JSON and the sentence read perfectly to a human. Caught only by running
the hook by hand; no existing check looked at it.
**Rule:** This hazard is already documented in `rules/ast-index.md` and already has Learning Log entries.
Three prose records did not stop a fourth recurrence, which is the threshold at which prose stops being
the answer. `scripts/test-plugin-manifest.sh` now asserts zero interior apostrophes across every hook
command, with `bash -n` on each command as an independent second leg — the apostrophe is one way the
string breaks, not the only one. Both legs were verified by re-introducing the apostrophe.
**Kind:** correction
**Escalated?** no
*(`no` is inaccurate and the inaccuracy is the finding: the rule WAS escalated, into a gate at
`scripts/test-plugin-manifest.sh`. The `Escalated?` enum has no value that can name a test or gate
script — the same shape as the `agents-method` gap just fixed, one target further out. Writing an
invented value would fail `/ai-audit` Phase 1 verification, so the field stays `no` and the truth lives
here.)*

### 2026-09-24 — tooling — the pipe-masking hook does not see a gate run through `bash`
**What happened:** Verifying an edited hook, I read its exit status from `bash -c "$cmd" 2>&1 | head -2`.
A pipeline's `$?` is the LAST command's, so it printed `rc=0` for a hook that had correctly exited 2 — I
briefly recorded a working gate as broken. The repo has a PreToolUse hook specifically for this shape, and
it did not fire. Probed directly afterwards:

    rc=2   pytest tests | head -2
    rc=0   bash -c "$cfg" 2>&1 | head -2
    rc=0   bash scripts/test-fold.sh | tail -1

The hook anchors on a list of gate binaries (`make|cargo|go|npm|pnpm|yarn|gradle|./gradlew|mvn|pytest|
shellcheck|ruff|eslint|ktlint`). `bash` is not in it — so in a repo whose entire test suite is shell
scripts, **every** `bash scripts/test-*.sh | tail` run this session was unguarded.
**Rule:** A hook that enumerates tool names does not generalise to a project whose gates are invoked
differently; its coverage is a project fact, not a method guarantee. Read an exit status un-piped, and do
not treat a clean hook run as evidence the construct was checked. Adding `bash` to that list is not
obviously safe — `bash -c '…' | jq` is a legitimate non-gate shape — so the fix needs design, not a
one-token edit.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — process — I reproduced the defect I was fixing, inside the fix
**What happened:** While writing a carve-out about references that point at the wrong file, I wrote
`AGENTS.md § Tooling` in the new text — the exact mis-attribution the surrounding work was correcting.
§ Tooling exists only in the method file. Caught only because I separately swept the class before
committing; reviewing my own addition had not caught it.
**Rule:** When fixing a defect CLASS rather than an instance, run the class sweep over the diff as well
as over the repo, and run it LAST — before the sweep, the new text is not in the corpus the sweep read.
The failure is not carelessness: a freshly-written sentence is the least suspect text in the file, which
is precisely why an author-side review misses it.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — testing — sweeping the defect class beat trusting the gate written for it
**What happened:** A reference checker written the previous day passed clean. Two defects of the same
family were then found by hand — a sync-group member pointing at a nonexistent file, and ~29 references
naming sections a consumer does not have — because the class was swept independently rather than
delegated to the gate. Each was afterwards added to the checker as a new leg and verified by
re-introducing the defect.
**Rule:** A gate written for a known defect catches that defect. The adjacent class is invisible to it by
construction, so a clean gate run is evidence about the gate's own scope and nothing wider. When a defect
is found, sweep its family by hand ONCE before extending the gate — the sweep decides what the new leg
should be, and the gate then holds the line. A gate is a ratchet, not a search.
**Kind:** validation
**Escalated?** no
