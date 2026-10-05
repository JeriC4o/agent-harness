# Learning Log — chore-checks-runner

### 2026-10-06 — tooling — piped a test suite into `tail` on the first run of the session; THIRD occurrence of this pattern
**What happened:** The very first time I ran the new suite I wrote
`bash scripts/test-run-checks.sh 2>&1 | tail -20; echo "rc=${PIPESTATUS[0]}"`. The `result-masking`
hook blocked it at dispatch, so no gate result was actually masked — but the rule binds on the
CONSTRUCT as written, not on whether the gate ran. This is the third recorded occurrence of the same
pattern in three days: `ai-docs/learnings/JeriC4o-main.md` (2026-10-04, a suite into a pager) and
`ai-docs/learnings/JeriC4o-GH-93-plain-language.md` (2026-10-06, `| tail -3` on
`test-check-references.sh`, plus `> /dev/null` on the manifest gate). Note what is NOT shared: the
previous two happened deep into a long gate list, this one happened on call four of a fresh session,
with a short expected output. The reaching-for-a-filter reflex is not a fatigue effect and not a
long-output effect — it fired here because I expected the run to FAIL and wanted only the verdict
line, which is the cheapest moment to be careless and the one where the full output matters most: a
first red run is exactly the output worth reading whole.
**Rule:** When the expected outcome of a gate is RED, that is the strongest reason to run it bare — the
failure lines are the payload, not noise to trim. The guard that works is at composition time: if the
command string contains a filter after a gate, delete the filter before dispatch rather than relying on
the hook, which is a safety net and not a substitute. Already-escalated control: the `result-masking`
hook caught this one, as it caught the previous one, so the mechanism is working and the gap is mine.
**Kind:** correction
**Escalated?** no

### 2026-10-06 — testing — wrote a planted-defect leg whose planted defect was not a defect
**What happened:** `scripts/test-run-checks.sh` has a leg asserting that the shell-syntax member
reddens on a tracked file that does not parse. I planted
`if [ 1 = 1 ; then echo no; fi` as the broken fixture. `bash -n` accepts that file (rc 0): an unclosed
`[` is a RUNTIME failure of the `[` command, not a parse error. The leg reported PASS against a runner
that had not yet been written, and when the runner existed the leg went red — which is the only reason
I looked. Had the runner been written first, the leg would have passed permanently while asserting
nothing. Verified both spellings independently afterwards: the original fixture exits 0 under `bash -n`,
an unterminated `if true; then` exits 2. The project method file already mandates exactly this check —
"verify the mandated invocation FAILS on a planted defect before writing it down" — and I wrote the leg
without running the plant once.
**Rule:** A planted defect is a measurement, so it gets measured: run the plant against the gate's
underlying tool ALONE, before asserting anything about the gate, and keep that run in the suite as its
own assertion (`the planted defect fails bash -n on its own`) rather than as a comment claiming it
does. Writing tests before the code is what surfaced this one for free — a leg that passes while the
implementation does not exist is a leg that measures nothing, and test-first makes that visible in the
first run instead of never.
**Kind:** correction
**Escalated?** no

### 2026-10-06 — architecture — made empty output the success signal without ruling out every path to empty
**What happened:** In `scripts/run-checks.sh` the gate-inventory member treated empty output from
`inventory_findings` as "the lists agree". That function opened with `tmp=$(mktemp -d) || return` for
the two `comm` inputs, and `mktemp` was **not** in the runner's own required-tool preflight — whose
stated purpose is "a missing tool is not a pass". On a machine without `mktemp` the one member that can
see list drift returned empty, reported `ok`, and the whole run exited **0** over a tree that really had
drifted. Found by the review agent, not by me, and not by the suite: the suite's thin-PATH leg symlinks
`mktemp` in by hand, so the control was built around the very tool the required list forgot. Confirmed
with a paired control on one fake tree carrying a real undocumented suite, `mktemp`'s presence the only
difference: `rc=1 / FAIL gate-inventory` with it, `rc=0 / ok gate-inventory` without. After the fix
(`comm` fed by process substitution, plus an explicit finding when either side derives to nothing) both
legs of that same control return `rc=1`.
**Rule:** When empty output IS the success signal, enumerate every way the producer can emit nothing and
make each one speak: a missing tool, an unreadable input, a parse that matched no lines, a derivation
that legitimately found zero. Each needs its own finding, never a bare `return`. Two corollaries worth
keeping: a tool used by a check belongs in that check's own preflight list, and the preflight is itself
a list beside code, so it drifts — the suite now derives the tools the body invokes and compares them
against what the preflight demands, the same shape as the drift check the runner performs on its member
list. And a thin-PATH fixture that symlinks a tool in is asserting that tool is required; if the code
under test does not demand it, the fixture is hiding the gap rather than probing it.
**Kind:** correction
**Escalated?** no

### 2026-10-06 — documentation — wrote a comment claiming a guard exists, in the same breath as fixing the gap that guard was for
**What happened:** The fix for the previous entry added a leg deriving the tools the runner's body
invokes and comparing them against its preflight list. I then wrote, in `scripts/run-checks.sh`,
"test-run-checks.sh now asserts that every tool the body invokes appears here" — and repeated the claim
in the previous entry's Rule text, which is append-only and therefore still says it. The claim was false
two ways, both found by the review agent in the next round. First, the derivation reads a CLOSED
vocabulary of tool names, and `dirname` — invoked by the ROOT default on the runner's own fourth
executable line — was in neither the vocabulary nor the preflight list. Second, the text I derived
invocations from included the `for t in …; do` declaration line itself, so every required tool appeared
in the "invoked" set by construction: the containment check could not fail on account of a required
tool, and the positive control beside it could not tell "found real invocations" from "found the
declaration". Behaviour was safe — a missing `dirname` makes the repo-identity check fail with rc 2 —
so this was a false CLAIM, not a false green, which is exactly why no test caught it.
**Rule:** A sentence asserting that a guard exists is itself a claim to verify, and the moment of
maximum risk is the commit that FIXES the gap: the fix is fresh, the relief is real, and the sentence
gets written in the past tense about a mechanism that is one case narrower than stated. Two concrete
habits. Scope the claim to what the mechanism actually reads ("derives from a closed vocabulary, so it
is a net for the tools it knows, never a proof") rather than to what it is for. And when a check derives
one set from a file to compare against another set in that same file, exclude the second set's own
declaration from the first derivation — otherwise the comparison is partly against itself, which is the
general form of the defect here and reads as passing.
**Kind:** correction
**Escalated?** no

### 2026-10-06 — testing — a mutation guard that asked "did the file change?" called a broken sed an applied mutation
**What happened:** Three new legs run a mutated copy of `scripts/run-checks.sh`. I wrote the mutations
with `sed 's|^manifests|fn:manifests_member$|…|'` — `|` as the delimiter inside a pattern that itself
contains `|`. Every one failed with `sed: bad flag in substitute command`, writing a truncated file. My
apply-proof was `cmp -s "$RUNNER" "$MUT"`, so it asked only whether the output DIFFERED from the
original: a truncated file differs, and the guard reported "the mutation applied" before three legs then
failed against a mutant that was not the mutation I meant. Re-spelled with `#` as the delimiter, two of
the three still did not apply, for a second reason: the first member of the table sits on the
`MEMBERS='` assignment line, so a pattern anchored at `^manifests` matches nothing — the review agent
hit that same line in its own round-2 mutation and rebuilt it rather than reporting the result.
**Rule:** An apply-proof proves the INTENDED change, never that the file moved: assert the new text is
present in the mutant AND absent from the original AND that the mutant still parses. Those three turned
both failures into red legs instead of silently-wrong green ones. Second, when a pattern contains the
delimiter, change the delimiter rather than escaping — and when a mutation targets the first element of
a multi-line assignment, remember it shares a line with the assignment and pick a middle element
instead.
**Kind:** correction
**Escalated?** no
