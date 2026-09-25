# Learning Log — JeriC4o / chore/improve-sweep

### 2026-09-26 — tooling — piped a test suite into `tail` to shorten its output, masking its exit status
**What happened:** While validating the `/improve` fold I ran two test suites as
`bash scripts/test-check-references.sh 2>&1 | tail -5; exit ${PIPESTATUS[0]}` and the equivalent for
`scripts/test-plugin-manifest.sh`. The `result-masking` PreToolUse hook blocked both. The `${PIPESTATUS[0]}`
rescue was deliberate and it does propagate the suite's rc — but the construct still throws away the
suite's output, which is the half of a gate result a reader actually judges, and the rule binds on the
CONSTRUCT as written, not on whether this particular spelling happened to preserve rc.
**Rule:** Run a gate bare, as its own Bash call, and read its FULL output. Do not reach for `| tail` to
keep a long green suite short — a suite's per-assertion lines are the evidence that it ran the assertions
it claims. Limit output with the tool's own flags when it has them; a suite with no such flag is simply
read in full. `${PIPESTATUS[0]}` is not an exemption from the rule; it repairs rc and leaves the output
loss untouched.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — documentation — I wrote a carve-out by misquoting the enumeration it cited
**What happened:** Reconciling a documented audit block against the gate-masking rule, I wrote that the
rule "binds on a loop whose body runs a build / test / lint / format gate, and this loop invokes only
`grep` and `awk`." The rule I was citing reads `Each gate (format, lint, build, test, search)`. I dropped
**search** from a five-item list and then rested the entire carve-out on the gap I had just created — the
block's body runs `grep -Fx`, which is a search. A clean-context eval caught it by re-reading the cited
line; I had quoted the enumeration from memory while looking at the sentence I was writing.
**Rule:** When a carve-out argues that a rule does not reach some case, re-read the rule's own
enumeration and quote it in full BEFORE writing the exemption — a carve-out is a claim about the cited
text, so the citation is the thing to verify, not the reasoning built on it. An enumeration shortened by
one item is the most dangerous shape available: it reads as a faithful restatement, and the dropped item
is invariably the one that would have refused the exemption. Prefer stating why a known violation is
being TOLERATED over constructing a reason it is not a violation.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — process — I added a rule to a section and not to the block that ships it
**What happened:** I appended a new bullet to `rules/ast-index.md` § Forbidden and discharged the
Propagation Rule by sweeping for the changed keywords. The sweep came back clean. But the same file ends
with a verbatim block that subagents inherit, which RESTATES three of that section's four shell-hazard
bullets in its own words — so the sweep, keyed on my new wording, could not see it. Subagents would have
inherited the three older hazards and not the new one, from the same file.
**Rule:** A propagation sweep finds files sharing the changed WORDING; it cannot find a restatement in
different words, including one further down the file you just edited. When a file contains a
digest/inherited/verbatim copy of its own content, that copy is a sync-group member of the section it
digests — check it by STRUCTURE (does this section have a restating counterpart?) before trusting an
empty sweep. The repo already names this failure mode in the Propagation Rule procedure; I ran the sweep
it prescribes and still missed it, because I treated the sweep as the whole obligation.
**Kind:** correction
**Escalated?** no
