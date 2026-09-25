---
id: loop-and-null-redirect-mask-a-gate
category: tooling
kind: correction
created: 2026-09-26
---

**Rule:** Run each gate as its own bare call. A gate run inside a loop reports only the last iteration's
status, and a gate whose output goes to the null device discards the line naming which assertion failed.
When only part of a long output is needed, redirect to a file and read the file.

**Why:** Both constructs return success over a failing gate, and the second does so even when the status
is read correctly — so a later claim of correctness rests on a check that measured nothing. Batching
several gates into one call is the temptation that produces the loop form, and wanting a compact
transcript is the one that produces the null redirect. A guard matching the command string cannot see a
gate whose path arrives through a variable or a glob, so that construct check stays with the author.

**Signal:** A loop whose body invokes a build, test, lint, format **or search** tool — a search that
decides something is a gate like any other, and a guard narrow enough to stay usable will not flag it. A
gate invocation followed by a redirect to the null device. A gate whose path is a variable or a glob.
