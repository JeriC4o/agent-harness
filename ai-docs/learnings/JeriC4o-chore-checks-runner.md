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

### 2026-10-06 — process — handed back a follow-up list instead of finishing cheap work, and one item on it was already done
**What happened:** After the review approved the branch I offered three items as follow-up issues and
asked whether to file them. The user's reply: "какие задачки? у тебя все время что то в остатке — ты
специально режешь скоуп чтоб не доделывать?" Checked each against the tree rather than defending the
list, and the challenge was largely right. Item two — a mutation guard passing on a mutant truncated at
a statement boundary — I had ALREADY closed in the same round I reported it as open, by requiring the
mutant to differ by exactly two lines; I listed it from memory of the review's wording instead of from
the file. Item one was six lines (one verdict per member, which neither total can show) and there was no
reason not to write it. Item three I had carried in the reviewer's framing — "a tracked gate script
named outside both naming conventions is invisible" — and in that framing the only fix is a declared
"not a gate" list that grows with every new hook library and reddens on arrival, so it looked expensive
and I deferred it. Reframed to the risk that actually matters — a structural check can be DOCUMENTED and
never wired in — it derives from the gate list, needs no declared list, and took about as long as the
first item. Both are now in the branch, with legs, and the reframed one closed a case the earlier pin
existed for: of the three gaps my own PR body announced, two are gone and one is genuinely narrower than
stated.
**Rule:** Before offering anything as follow-up, do two things. Re-derive whether it is still open —
a leftover list quoted from a review's wording goes stale the moment you act on that review, and
reporting a closed item as open is the same class of error as reporting an unrun gate as passed. Then
price it honestly: a fix under about ten lines with a clear test is work to do now, not a decision to
hand back, and "it is out of scope" is a claim about cost that has to survive being reframed in my own
words rather than the reviewer's. A gap inherited in someone else's framing usually carries their
proposed remedy with it, and that remedy is what makes it look expensive.
**Kind:** correction
**Escalated?** no

### 2026-10-06 — process — attributed four already-shipped fixes to the commit I was asking to have reviewed
**What happened:** Second instance in one session, four times wider than the first. The entry above
records listing ONE item (the mutation apply-proof) as open when it was already closed. Writing the
hand-back for the next commit I then wrote that a predicate fix plus three small ones "went in with"
commit `7c7fec8` — and all four had shipped in `997068c`, the commit already pushed. The review agent
checked it against the tree: `git show 997068c:scripts/run-checks.sh` carries `declare -F` at three
places, `git show 997068c:scripts/test-run-checks.sh` carries the changed-lines clause and the surfaced
`sed` stderr, and `git diff 997068c HEAD -- scripts/run-checks.sh` touches none of those lines. I
re-derived all of it afterwards and it holds. Nothing was claimed closed that was open, so the branch
has no defect from this — the damage is to the record and to the reviewer's time, which was spent
re-deriving an attribution I could have derived in one command.
**Rule:** The commit a fix landed in is a mutable fact like any other, so it comes from `git diff` /
`git show`, never from the conversation — and specifically never from my own earlier message, which is
the worst source because it reads as authoritative and is already stale. Writing a hand-back that
attributes work to a commit means running the diff for that commit FIRST and building the list from its
output. The general form, and the reason this is the second instance: the conversation is a cache that
is invalidated by every action I take, and the longer a session runs the more confidently wrong that
cache gets. Re-deriving beats remembering at a cost of one command.
**Kind:** correction
**Escalated?** no

### 2026-10-06 — process — pushed to a branch and rewrote a PR body without re-reading that the PR had merged mid-flight
**What happened:** Third instance of the same root cause in one session, and the first one with an
outward-facing effect. While the review round on the second commit was running, the user merged PR #96 —
containing only the first commit. I then pushed the second commit to the same branch and ran
`gh pr edit --body-file` to sync the description, per the rule that a push to a branch with an open PR is
followed by reading the body and editing it when it contradicts the new commits. Both commands succeeded
and neither told me anything was wrong: the push updated the branch, and `gh pr edit` happily rewrote the
body of a MERGED pull request. For a couple of minutes the merged PR described two checks that were not
in it. Found only because the confirmation command I ran afterwards printed `MERGED, commits: 1`, which I
had expected to read `OPEN, commits: 2`. Recovered by restoring #96's original body from the file it was
created from — verified by diffing the live body against that file, identical but for one trailing blank
line GitHub adds — and opening #97 from the same branch for the two follow-up commits plus the version
bump the new base required. A first attempt to verify the restore used two phrases that are line-wrapped
in the source files and therefore could never match, so it reported neither version present; that is the
same not-from-the-output error one layer down.
**Rule:** A pull request's STATE is a mutable fact with an owner other than me, so it is re-derived
immediately before any action that depends on it — `gh pr view --json state` before a body edit, and
before treating a push as landing in an open PR. The rule that says "read the body after every push"
silently assumes the PR is still open; that assumption is exactly what a long-running review round
invalidates, because the user is working in the same repository at the same time. Two corollaries. A
command that succeeds is not evidence that it did the right thing — `gh pr edit` does not refuse a merged
PR — so the confirmation has to assert the state I expected, not merely that the call returned 0. And
when verifying a text restore, compare whole FILES with `diff`; a grep for a remembered phrase fails
silently when the source wraps that phrase across lines.
**Kind:** correction
**Escalated?** no
