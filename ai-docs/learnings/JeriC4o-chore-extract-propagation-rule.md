# Learning Log — JeriC4o / chore/extract-propagation-rule

### 2026-10-04 — architecture — a section's LOCATION was a dependency of a gate, not a documentation detail
**What happened:** Extracting a 7,455-char reference table out of the file every agent loads looked like
a documentation move. Measured before starting: **nine** files named the table's location, and two of
them did so non-trivially — `scripts/check-propagation-arms.sh` DERIVES the hook reminder's path classes
by cutting the section out of that file with `awk`, and the shipped hook message asserts in prose "its
sync-group table is in %s". So the move was not a move: it was a gate rewrite, a change to a
model-facing message's factual claim, a fixture repointing in the gate's own suite, and six text
updates. Everything held afterwards — the gate derives the same 35 members — but the work was four
times what the diff of the two documents suggests.
**Rule:** Before extracting a section, enumerate what names its LOCATION, not just what links to it,
and separate the dependents that merely reference it from the ones that COMPUTE from it. A derivation
gate and a message that states where something lives are both broken by a move that every link check
passes. Where a document is an input to a gate, say so in the document — the extracted page now opens
by naming the gate that reads it and warning that reformatting the table changes what the gate computes.
And check what the section actually contains first: this one held two unrelated AXIOMs, so extracting
"the section" would have moved a naming rule that has nothing to do with propagation.
**Kind:** correction
**Escalated?** no

### 2026-10-04 — testing — renaming the variable collapsed a gate's input set to zero, and three cross-checked numbers caught it
**What happened:** Repointing the derivation gate at the extracted page, the source variable was renamed
`METHOD` → `TABLE`. One later use of `$METHOD` survived — it reads a DIFFERENT list that legitimately
stayed behind — so that read silently became a read of the empty string. The gate reported **0 derived
members** and raised findings. It could just as easily have passed: a gate whose input set narrows to
nothing has nothing to disagree with. What made it loud was that the gate cross-checks three numbers
against each other (members fire, controls stay silent, pre-fix matches are kept), so an empty set
contradicted the other two rather than quietly agreeing with them.
**Rule:** A rename is an input-set change until proven otherwise: after renaming any variable that
names a gate's SOURCE, grep for every surviving use of the old name before running anything, and read
the COUNT the gate processed rather than its exit status. Where one gate reads two different inputs,
declare and existence-check both separately — a single variable covering "the method file" invited the
collapse. The structural lesson is the cross-check: a gate that reports one number can be narrowed to
zero silently; one that reports three numbers which must reconcile cannot.
**Kind:** correction
**Escalated?** no

### 2026-10-04 — testing — a suite that ENUMERATES its own alphabet goes blind the moment a member is added
**What happened:** The manifest suite asserts that every resolved-path call in the hook manifest carries
an emptiness guard and a fallback, and that message references exceed call sites by exactly one. Its
greps spelled the variable names as a character class, `[ab]`. Adding a third resolved address — variable
`t` — made the new call site visible to the call-site count and invisible to the guard and reference
counts, so the three numbers stopped reconciling. The assertion failed for the right reason and named
both figures, but the cause was the suite's own hard-coded alphabet, not the manifest.
**Rule:** Derive the set a check iterates over from the artefact under test; never enumerate it in the
check. Here the alphabet is one `grep | sed | sort -u` away from the captures themselves, and deriving
it makes the next address free. The tell that this class is present: a character class, a hardcoded
list of names, or a fixed count standing where a derivation would do — and the reason it is worth
fixing rather than extending is that extending it works exactly once, for the member you happen to be
adding today.
**Kind:** correction
**Escalated?** no
