# Learning Log — GH-34-deferral-turn-selfcompare

### 2026-09-24 — tooling — the apostrophe hazard, fifth recurrence, and I ran the suite before the syntax check
**What happened:** Writing a comment INTO an embedded jq program, I typed `this turn's`. The jq program
lives in a single-quoted shell string, so the apostrophe closed it and the remainder became shell. I
then ran the test suite, which reported **50 failures across every unrelated section** — and spent the
next minutes reading that wall before recognising the shape. `bash -n` on the same file returns rc 2
and names the exact line. The cheap check would have localised it immediately; I ran the expensive one
first.
**Rule:** After editing a shell script — especially one carrying an embedded program in quotes — run
`bash -n <file>` BEFORE running any suite that executes it. A syntax check is O(1) and points at a
line; a suite failure is O(n) assertions and points nowhere. When a suite fails broadly across
sections that the change could not possibly touch, that shape IS the signal: suspect the file itself,
not the assertions. And the apostrophe hazard now has five recurrences: prefer a phrasing without one
whenever writing prose inside a quoted program — `the matching turn` rather than `this turn's`.
**Kind:** correction
**Escalated?** no

### 2026-09-24 — testing — the fixture that cannot discriminate needs its own guard
**What happened:** The existing coverage for this signal used a session with ONE depth spike. With one
spike, reading the matching row and reading the first row return the same row, so a self-comparison in
the lookup passed unnoticed for as long as the code existed. The new fixture uses two spikes of
different depth — and carries an explicit assertion that the two depths DIFFER, because if a later
edit made them equal the discriminating assertion would silently degrade into one that passes against
the defect.
**Rule:** When a test distinguishes "the matching element" from "some element", the fixture must
contain at least two candidates AND assert that they differ in the field under test. Without that
guard the test's discriminating power depends on a fixture property nothing checks, which is the same
class as a positive control: state what must be true for the assertion to mean anything, and assert it.
**Kind:** correction
**Escalated?** no
