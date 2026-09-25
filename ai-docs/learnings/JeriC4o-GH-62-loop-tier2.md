# Learning Log — JeriC4o / GH-62-loop-tier2

### 2026-09-26 — architecture — I wrote a rule in the morning and violated it in a spec by the afternoon
**What happened:** In #59 I escalated a `§ Testing` bullet: *"Where the qualifier names a property as the
thing that separates a real finding from a dismissable one, the filter must not key on that same
property — it structurally excludes the case the qualifier exists to confirm."* Hours later, writing the
GH-60 issue, I specified that tier 2 of the loop detector "must never run unconditionally: tier 1 plus
the existing qualifiers is the filter that decides whether it runs at all." Tier 1 keys on byte-identity;
tier 2 exists for repetition that is NOT byte-identical. Gating tier 2 on tier 1 confines it to the class
tier 1 already caught — the same defect, in the same shape, in a document I wrote about that defect.
**Rule:** The rule binds on specifications, not only on code, and a freshly-authored rule is at its LEAST
protective — it sits in mind as a thing recently reasoned about rather than a thing to check against.
When designing a second detector for what a first one misses, state the property the first keys on and
verify the second's gate keys on something else; if the gate cannot be described without referring to the
first detector's signal, it is the same detector. Prose describing two tiers is not evidence they differ.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — the mutation-applied assertion existed, and was inverted
**What happened:** After logging yesterday that a mutation which fails to apply reads as a missing test, I
added explicit "the mutation applied" checks to the tier-2 suite. Two of them asserted the opposite of
what applying means: I grepped the mutated copy for the deleted guard and expected to find it once.
Both reported FAIL. A third control failed for an unrelated reason — the fixture seeded tier-2 verdict
lines, which tripped the already-judged guard, so the control could not fire whatever the mutation did.
**Rule:** An inverted applied-check is the good failure — it is loud, and it fails in the direction that
gets looked at. The dangerous sibling is the third case: a control blocked by a DIFFERENT guard than the
one under test, which reports "not caught" and looks exactly like a missing test. When a positive control
does not produce the expected damage, the first question is not "is the test missing" but **"did anything
else stop this control from firing"** — and a fixture that trips an unrelated guard is the commonest
answer. Build control fixtures from the minimum that reaches the guard under test, and prefer a seeded
record that no other guard inspects.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — validation — a hardcoded inventory list is a gate that silently narrows
**What happened:** `scripts/test-install-smoke.sh` verifies that components reach a real install, but its
hook-event check iterated a hardcoded `SessionStart PreToolUse PostToolUse`. Adding `Stop` and
`SubagentStop` would have loaded, or not, with nothing noticing — the suite would stay green either way,
while claiming to verify that hooks reach the install.
**Rule:** Keep checking, on every new component, whether the gate that covers its CLASS enumerates
members by hand. An inventory gate is honest about what it lists and silent about what it omits, so its
green is scoped to the list rather than to the class — the same shape as a gate that narrows its own
input set. Extending the list is part of adding the component, not a follow-up.
**Kind:** validation
**Escalated?** no
