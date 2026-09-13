# Doc convention — doc-comments

Companion to `ai-docs/code-style.md`. Used by `self-review` and `/project-review` to verify public-API documentation.

## When a doc-comment is written

**Default to NONE.** Doc-comments are NOT written by default — `ai-docs/code-style.md § Comments` governs and it says code is the single source of truth. A doc-comment that merely restates the signature, repeats the symbol name, or narrates WHAT a declaration is / does carries zero information, rots, and is a `major` finding (`self-review` / `/project-review` Checklist 6). Visibility does NOT trigger a doc-comment: a public constant, function, type, or property gets **no** doc-comment just for being public.

Write a doc-comment ONLY when it carries information the signature cannot:

- A non-obvious **WHY** — a hidden constraint, a subtle invariant, a workaround for a specific bug (same bar as `code-style.md § Comments`).
- A real public-API **contract** the types cannot express — `@throws` semantics, a non-obvious `@param` / `@return` constraint, a documented ordering/nullability invariant.

If the only thing a doc-comment would say is recoverable from the name and types, do NOT write it — rename the symbol instead. This file governs the SHAPE / FORMAT of a doc-comment **when one is genuinely warranted**; it is not a mandate to comment every public symbol. Everything below (summary phrasing, section order, `@throws` / `@return` rules, self-sufficiency, code fences) applies only to doc-comments that ARE written — with ONE exception, § `@throws` requirement, which mandates a doc-comment where none exists yet. It is the only rule in this file that creates a doc-comment rather than shaping one, and the only comment a reviewer may require rather than suggest.

**Interface-impl exemption.** An overriding method never carries a doc-comment — it inherits the one on the interface declaration.

## Summary line

- **Third-person present indicative:** `Returns the language map`, `Creates a new review request`, `Validates the diff signature`.
- **Never imperative:** ❌ `Return the language map`, ❌ `Create a new review request`.

## Section order

> **This section governs SHAPE, never COVERAGE.** It fires only once § *When a doc-comment is written* (`:5-16` above) has already established that this doc-comment should exist at all. Nothing below ever mandates ADDING a doc-comment, a `@param`, or a `@return` to a symbol that does not warrant one — "you are missing `@param`" is a finding ONLY on a doc-comment that is itself warranted. **If you arrived here from a citation, read `:5-16` before acting on it:** a formatting rule ("if you write X, format it thus") is not a mandate ("write X"), and the difference is stated in the preamble that a section-level citation skips. (Recurrence: a review finding cited item 3 below, thirteen `@param` lines were added to doc-comments that did not warrant one, and the reviewer rejected the round twice.)

When a doc-comment carries sections, the order is fixed:

1. Summary (one line).
2. Free-form prose (optional).
3. `@param` / `# Parameters` (one per non-receiver param).
4. `@return` / `# Returns` (only when the return is non-obvious or multi-shaped).
5. `@throws` / `# Throws` (for each exception type that a reasonable caller would care about).
6. `@sample` / `# Examples` (where the language supports referencing a sample function elsewhere).
7. `@see` / `# See also`.

## Ad-hoc sections forbidden

Only the canonical headings above are allowed. No stray `# Notes`, `# Implementation details`, `# History`. If the content doesn't fit a canonical heading, it's free-form prose between summary and `@param`.

## `@throws` requirement

A public function that asserts a precondition, throws an argument/state exception, indexes into a collection without bounds-checking, or performs arithmetic that can overflow on plausible inputs — MUST document the exception in `@throws`.

`@throws IllegalArgumentException` on a one-line getter that asserts a non-blank name is required, not optional. This overrides § *When a doc-comment is written*'s default-to-NONE for this one case: the doc-comment must be created even where the fn carries none, and it is the sole carve-out from the rule that a reviewer's request to ADD a comment is a suggestion the author may decline (`.claude/agents/self-review.md § Requests to ADD a comment`).

**`@throws <Type>` is a TYPE assertion — verify the hierarchy, never write it from recall.** The mandate above is discharged by naming the type that actually propagates, not a plausible one. For an exception originating in a framework or dependency, confirm the type against the branch's OWN resolved dependency versions before naming it — a version cached by an unrelated module is a different version, and verifying the wrong one is the exact failure this rule exists to prevent. A sibling type reads like a subtype and is the common error: documenting a supertype the real failure does not extend is a false contract that invites a wrong `catch`. When the honest answer is "everything propagates", write prose instead of a type tag; naming one type reads as an exhaustive contract. When the design document already contains the analysis, the doc-comment MUST agree with it — contradicting your own cited proof is worse than saying nothing. A doc-only fix round is NOT low-risk and does not warrant a lower bar.

## `@return` requirement

`@return` is required when:

- The return type is a multi-shaped result (sealed class, `Result<T>`, `Either`).
- `null` carries semantic meaning (a `Foo?` whose null encodes "not found" vs "deleted").
- The return is a collection whose ordering / sortedness / nullability of elements is invariant.

`@return` is NOT required for:

- Single-shape returns where the type name is self-explanatory (`fun userId(): UserId`).
- Unit / `void` return types.

## Code fences

- Tag every fence with the sample's language (` ```kotlin `, ` ```go `, ` ```ts `).
- Markdown in doc-comments: use backtick fences for code blocks.

## Self-sufficiency: no repo-internal references

doc-comment must read self-sufficient to a docs reader who has no access to the source tree.

### Pattern A — banned substrings in doc comments

Reject any doc-comment line matching:

- `as documented in …`
- `see <relative-path>`
- `per the spec at …` / `per design at …`
- `as discussed in PR #…` / `cf. PR #…`
- `as flagged in learnings.md …`

These references rot — a reader browsing generated API docs cannot follow them.

### Pattern B — banned link targets

Reject any doc-comment `[link](path)` whose path resolves to:

- `ai-docs/**`
- `.claude/**`
- `AGENTS.md` / `CLAUDE.md`
- `*.spec.md` / `*.design.md` / `*.progress.md`

These are contributor surfaces, not API documentation.

### Family C — inline `//` comments inside doc-comment code fences

A `//` inside a doc-comment code fence is fine when:
- (i) It's useful to a docs reader independent of the repo (e.g. `// for n=10 this is ~3 calls`).

A `//` inside a doc-comment code fence is rule-(ii) violating when:
- It assumes repo-internal architecture or contributor convention (`// uses the DAO's batch-upsert`).

Rule-(ii) matches → REJECT.

## Module-level docs

No mandatory module / package doc. A top-of-file module/package doc block is written ONLY when the module's purpose is non-obvious from its name and contents — the same "non-obvious WHY" bar as above. A one-paragraph block that merely restates the package name is a narration finding; omit it.

## Sample functions

Use `@sample` over inline doc-comment code fences when the example is non-trivial:

```kotlin
/**
 * Validates a review request's diff signature.
 *
 * @sample com.example.review.samples.validateSimpleDiff
 */
fun validate(req: ReviewRequest): Result<Unit> = …
```

Sample functions live in a sibling `samples/` package and are never invoked at runtime.

## Mechanical heading scan

To audit a changed file for doc-section presence + order:

```bash
grep -nE '/\*\*|\* @(param|return|throws|sample|see)' <changed-file>
```

## Feature flags / build profiles

When a doc references a capability that is gated (feature flag, build profile, conditional compilation),
point to the declaration that gates it — never describe the gate from memory.

## Skill docs & CLI `--help` — describe behaviour, not implementation

Skill `.md` files and CLI `--help` text describe OBSERVABLE BEHAVIOUR only. Strip every implementation detail: internal endpoint / handler names (`/v1/pull-requests/cursor` → "a `pr list` row", never "cursor row"), HTTP verbs + handler paths, internal class / DTO / swagger-def names (`XxxDto`, `Public_…`, `@ApiModel` names), and wire/serialization terms (epoch, Jackson, JAX-RS, `json.Number`, "cursor"). Describe the user-facing JSON keys, flags, and observable semantics instead, and match the surrounding doc's existing vocabulary.

When a CLI's user-facing behaviour changes, sync its skill docs (`SKILL.md` / `reference.md` / `evals.json`) in the SAME PR. When you spot ONE impl-detail leak, sweep and fix ALL of them, not only the ones your change touched. Before closing any skill-doc edit, grep the addition for leak terms: `grep -niE "cursor|epoch|float|instant|jackson|jax-?rs|serializ|<InternalClass>"`. 

## Cross-link

Doc-convention violations checked by `self-review` Checklist 6 and `review-findings` Checklist 6.
