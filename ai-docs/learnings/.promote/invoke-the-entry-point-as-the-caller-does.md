---
id: invoke-the-entry-point-as-the-caller-does
category: testing
kind: correction
created: 2026-09-26
---

**Rule:** A suite invokes the entry point the way its caller invokes it. Where production calls a script
by path, at least one assertion calls it by path, or asserts the executable bit directly. Check the
committed mode, not only the content.

**Why:** The convenient interpreter-plus-path form does not need that bit, so the suite is green precisely
because it does not run the thing the way it ships. The failure then surfaces on the caller's second step,
past every review round and past a delivery check that confirms arrival rather than runnability. When a
defect class already has a named assertion somewhere in the tree, a new file of the same kind means
copying that assertion — the lesson does not transfer on its own.

**Signal:** Every assertion in a suite spelled differently from the one call site in the shipping caller.
A new file of a kind that an older sibling already carries a special assertion for.
