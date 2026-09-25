---
id: fixture-needs-two-candidates
category: testing
kind: correction
created: 2026-09-26
---

**Rule:** When a test distinguishes the matching element from some element, the fixture holds at least two
candidates and asserts they differ in the field under test. When a qualifier names a property as what
separates a real finding from a dismissable one, the admission filter must not key on that same property.

**Why:** With one candidate, reading the matching element and reading the first element return the same
element, so a self-comparison passes for as long as the code exists. Without the explicit difference
assertion, a later edit that makes the candidates equal silently degrades a discriminating test into one
that passes against the defect. A filter keyed on the qualifier's own property structurally excludes the
case the qualifier exists to confirm.

**Signal:** A single-element fixture behind an assertion about which element was selected. A value
computed by a detector and used only inside its own admission filter.
