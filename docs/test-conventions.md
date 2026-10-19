# Test conventions

Extracted from `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Test Conventions`, which keeps the heading
and points here. The heading below is the one that section carried, unchanged, so a reference to it needed
only its file half re-pointed. This page is pure reference and is read when tests are written — which is
after the session-start page has been read, and is why it does not live in that page.

## Test Conventions

**Every rule on this page must hold in ANY language, and one that cannot is a defect in this page rather
than a rule to work around.** That is an obligation on whoever edits here, not a description of the page —
a description would simply rot. The project's own spellings — which test-double library, which shared
fixtures, whatever marks a test's context — belong in its `ai-docs/context.md`.

- **Keep a test's id free of characters the runner's filter treats as syntax**, and give each distinct setup its own TOP-LEVEL unit rather than nesting it. Nesting is what usually introduces such a character (a separator between outer and inner name), and the cost is not cosmetic: the id stops being selectable by the runner's own filter expression, so the test cannot be run alone.
- Test config mirrors prod.
- **Declare a test's doubles where the harness can reset them.** A double the test never configures or interrogates belongs in that declaration, not in a standalone field of its own; reserve the field form for the ones the test actually configures or interrogates.
- Prefer the test-double library's declarative configuration form over the imperative one.
- **Constrain EVERY argument of a configured call, or none** — never a mix of a literal and a matcher. A mix silently stops constraining the arguments given literally, so the call matches inputs the test never meant to accept.
- Prefer expressive assertions that state the property being checked; bare assertions at last resort only.
- Inline single-use vars. Merge assertions by comparing whole values rather than field by field.
- Use the project's shared test fixtures; no domain doubles where a fixture exists.
- **No test of a method that only forwards.** It asserts the forwarding and nothing else, and it fails only when the forwarding is edited.
- Default to BDD `should …` test names — `should <observable behaviour> [when <condition>]` — one meaningful user/system-as-user scenario per test. Arrange/act/assert as blank-line-separated blocks, NOT `// given` / `// when` / `// then` marker comments.
- Test behaviour, transitions, errors, edges.
- No lint-suppression directive unless unavoidable, and never a blanket one — scope it to the single rule and the single site, with the reason beside it.
- **A fixture MUST match production input in every field the code under test PARSES.** A fixture that differs there is not a fixture for that code: the parse takes a different branch and the assertion measures nothing. When a gate reads a format, pin at least one fixture to a real sample verbatim rather than to a hand-written approximation of it — a suite built entirely on the approximation stays green while the thing it covers is dead.
- **Where a parse carries a fallback, test the fallback's OWN branch.** What a failed parse yields is itself behaviour under test, and a failure value that happens to satisfy the comparison it feeds turns the gate into a silent pass.
- **When a qualifier applies to a FAMILY of checks, write the negative test for every member, not for one representative.** A value that is computed and never applied is the shape this catches: it reads as applied at a glance, and only the member that lacks it can show otherwise.
- **Probe real output for the class of thing that must never appear**, not only for the thing that must. Fixtures cover the cases you thought of; a real corpus contains the ones you did not.
- **When a test distinguishes "the MATCHING element" from "some element", the fixture MUST hold at least two candidates AND assert they differ in the field under test.** With one candidate, reading the matching row and reading the first row return the same row, so a self-comparison passes for as long as the code exists — and without the explicit difference assertion, a later edit that makes them equal silently degrades a discriminating test into one that passes against the defect. **The same question applies to a detector's ADMISSION FILTER:** after adding a qualifier, check what the filter lets reach it. Where the qualifier names a property as the thing that separates a real finding from a dismissable one, the filter must not key on that same property — it structurally excludes the case the qualifier exists to confirm.
- **A suite MUST invoke the entry point the way its CALLER invokes it.** When production calls a script by path, at least one assertion calls it by path — or asserts the executable bit directly. The convenient `<interpreter> <path>` form does not need that bit, so a suite spelled that way is green precisely because it does not run the thing the way it ships, and the failure surfaces as a permission error on the caller's second step. Check the committed MODE, not only the content. Generalisation: when a defect class already has a named assertion somewhere in the tree, a new file of the same kind means COPYING that assertion — the lesson does not transfer on its own.
