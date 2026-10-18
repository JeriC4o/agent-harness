# Test conventions

Extracted from `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Test Conventions`, which keeps the heading
and points here. The heading below is the one that section carried, unchanged, so a reference to it needed
only its file half re-pointed. This page is pure reference and is read when tests are written — which is
after the session-start page has been read, and is why it does not live in that page.

## Test Conventions

Language-agnostic rules. Framework-specific conventions (which DI test annotations, which mocking library, which fixture classes) belong in the project's `ai-docs/context.md`.

- **No nested test classes.** When scenarios need different context configuration, split into SEPARATE TOP-LEVEL classes (one per setup) — nested ids become `Class$Inner`, which breaks test-filter expressions.
- Test config mirrors prod.
- A mock the test never stubs or verifies belongs in the class-level mock declaration list, not a standalone field. Reserve the field form for mocks the test actually stubs or verifies.
- Prefer the mocking library's declarative stubbing form over the imperative one.
- Use matchers on **all** args of a stubbed call, never a raw+matcher mix.
- Prefer expressive matcher assertions; bare `assertEquals` / `assertTrue` at last resort only.
- Inline single-use vars. Merge assertions via value-type equality rather than field-by-field checks.
- Use the project's shared test fixtures; no domain mocks where a fixture exists.
- No trivial delegate-to-DAO tests.
- Default to BDD `should …` test names — `should <observable behaviour> [when <condition>]` — one meaningful user/system-as-user scenario per test. Arrange/act/assert as blank-line-separated blocks, NOT `// given` / `// when` / `// then` marker comments.
- Test behaviour, transitions, errors, edges.
- No `@Suppress` / `@SuppressWarnings` / equivalent unless unavoidable.
- **A fixture MUST match production input in every field the code under test PARSES.** A fixture that differs there is not a fixture for that code: the parse takes a different branch and the assertion measures nothing. When a gate reads a format, pin at least one fixture to a real sample verbatim rather than to a hand-written approximation of it — a suite built entirely on the approximation stays green while the thing it covers is dead.
- **Where a parse carries a fallback, test the fallback's OWN branch.** What a failed parse yields is itself behaviour under test, and a failure value that happens to satisfy the comparison it feeds turns the gate into a silent pass.
- **When a qualifier applies to a FAMILY of checks, write the negative test for every member, not for one representative.** A value that is computed and never applied is the shape this catches: it reads as applied at a glance, and only the member that lacks it can show otherwise.
- **Probe real output for the class of thing that must never appear**, not only for the thing that must. Fixtures cover the cases you thought of; a real corpus contains the ones you did not.
- **When a test distinguishes "the MATCHING element" from "some element", the fixture MUST hold at least two candidates AND assert they differ in the field under test.** With one candidate, reading the matching row and reading the first row return the same row, so a self-comparison passes for as long as the code exists — and without the explicit difference assertion, a later edit that makes them equal silently degrades a discriminating test into one that passes against the defect. **The same question applies to a detector's ADMISSION FILTER:** after adding a qualifier, check what the filter lets reach it. Where the qualifier names a property as the thing that separates a real finding from a dismissable one, the filter must not key on that same property — it structurally excludes the case the qualifier exists to confirm.
- **A suite MUST invoke the entry point the way its CALLER invokes it.** When production calls a script by path, at least one assertion calls it by path — or asserts the executable bit directly. The convenient `<interpreter> <path>` form does not need that bit, so a suite spelled that way is green precisely because it does not run the thing the way it ships, and the failure surfaces as a permission error on the caller's second step. Check the committed MODE, not only the content. Generalisation: when a defect class already has a named assertion somewhere in the tree, a new file of the same kind means COPYING that assertion — the lesson does not transfer on its own.
