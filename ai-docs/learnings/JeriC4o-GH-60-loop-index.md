# Learning Log — JeriC4o / GH-60-loop-index

### 2026-09-26 — tooling — second piped gate in one session, on the rule I had just shipped
**What happened:** Verifying a mutation control, I ran `bash <suite> 2>&1 | grep -E '^  FAIL|passed,'`
to keep the output short. The `gate-pipe-guard` hook blocked it. This is the second time in this session
— the first was `| tail` with a `${PIPESTATUS[0]}` rescue — and it happened *after* I had spent the
session extending that very rule to three more masking shapes and writing its hook legs.
**Rule:** Knowing a rule well is not the same as being governed by it, and having just authored it is not
protection — it may be the opposite, since the construct is fresh in mind as a thing to reason about
rather than a thing to avoid. The trigger both times was identical and is worth naming as the actual
tell: **wanting a long green suite to print less.** When that wish appears, the answer is never a filter
on the gate; it is reading the suite in full, or redirecting to a file and grepping the file. If a
filtered view is genuinely needed, put the fixtures and the filtering inside a checked-in `.sh` — the
carve-out exists for exactly that, and it is the difference between a legitimate script and a masked gate.
**Kind:** correction
**Escalated?** no

### 2026-09-26 — testing — a mutation that does not apply is indistinguishable from a guard that works
**What happened:** I ran six mutations against the new suite to prove it can go red. Five turned it red;
one — "count after appending instead of before" — reported NOT CAUGHT. The obvious reading was a gap in
the tests. The actual cause was that the mutation never applied: `perl -0p` slurps the file, so `^` only
matches at the start of the whole string, and without `/m` the substitution silently matched nothing and
rewrote nothing. With `/m` the same mutation turns the suite red in four places.
**Rule:** A mutation control has the same failure mode as the gate it is checking — it can report success
having done nothing. **Assert the mutation APPLIED before reading its verdict**: diff the mutated copy, or
grep it for the inserted token, and treat a no-op substitution as a broken control rather than as
evidence. The direction of the error matters: a mutation that fails to apply always reads as "the suite
did not catch this", i.e. it manufactures a false gap and sends you looking for a missing test. That is
the more expensive direction, because the honest-looking conclusion is to add a test for something
already covered.
**Kind:** correction
**Escalated?** no
