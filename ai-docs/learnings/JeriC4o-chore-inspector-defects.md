# Learning Log — chore/inspector-defects

### 2026-09-24 — tooling — I piped a gate through `tail` and joined it with `&&` in one call
**What happened:** After setting the execute bit I ran the suite as
`chmod +x … && git diff --summary … && bash scripts/test-session-events.sh 2>&1 | tail -3`.
That suite is a GATE. A pipeline's exit status belongs to `tail`, and the `&&` chain hides which
member failed. The run happened to be green and I re-ran it bare immediately, but the masked form
is the violation, not the outcome.
**Rule:** `agents-method.md` § Tooling — each gate runs as its OWN Bash call, never joined with
`&&` / `;`, never piped through `head` / `tail` / `grep`. Limit output with the tool's own flags.
The rule binds on the CONSTRUCT as written, not on whether the gate happened to pass. Same turn, a
second instance: a `for … do bash -n "$f" || echo FAIL; done` sweep, where `|| echo` swallows the
non-zero status the sweep exists to surface — replaced with
`git ls-files -z '*.sh' | xargs -0 -n1 bash -n`, which actually fails.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — testing — I wrote a cosmetic test and my own positive control caught it
**What happened:** Fixing a regression where a non-string timestamp killed the whole report, I added a
test built on ONE event. It passed. Then the mutation control — revert the guard, expect red — produced
**zero** failures. A single event never forms a repetition group, so the span computation the test
existed to exercise was never reached: the test passed identically with and without the fix. Rebuilt on
three grouped events; it then went red under mutation and green with the guard.
**Rule:** A green test proves nothing until it has been seen RED for the right reason. Run the mutation
before believing the assertion, not after — and when a fixture exercises code reached only through a
grouping, aggregation or filter, build the fixture so that path actually runs. The harness already
states this as "mentally comment out the production fix; if the test still passes it is cosmetic → REJECT";
the mental version is weaker than the executed one.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — process — my propagation sweep searched the instruction files and missed the code I was fixing
**What happened:** After editing a claim in an agent definition I swept for its terms across the
instruction directories and found one further copy, which I fixed. Self-review found two more: the header
comment of the very script the fix was editing, and the repository's front page. Both stated the same
false universal, and both shipped in the version this PR bumps.
**Rule:** A propagation sweep is scoped by the CLAIM, not by the directory an instruction file lives in.
Sweep the file being edited (a long header comment is an instruction file with a different extension) and
the reader-facing entry points — README and equivalents — not only the instruction tree. And when a fix
replaces a false universal, check the replacement is not a narrower false universal: "every X" became
"every signature" and was wrong for half the kinds.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — testing — every fixture used a timestamp spelling the production input never has
**What happened:** `scripts/test-session-events.sh` carried two passing time-window tests and a
passing span assertion while the window filter was dead against real transcripts. A count of
fractional-second timestamps across the whole suite returned **0**: every fixture wrote whole-second
times, which is exactly the spelling jq's `fromdateiso8601` accepts — and the millisecond spelling a
live transcript always writes is the one it rejects. The suite could not see the defect it was
written to cover, and stayed green through ten releases.
**Rule:** A fixture that differs from production input in the field the code PARSES is not a fixture
for that code. When a gate reads a format, pin at least one fixture to the real thing byte-for-byte.
And when a parse carries a `catch`, test the catch's own branch: what a failed parse YIELDS is the
behaviour under test, and a failure value that satisfies the comparison it feeds turns the gate into
a silent pass.
**Kind:** correction
**Escalated?** no
