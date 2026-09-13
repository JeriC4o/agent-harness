# Code style

Workspace code-style reference. Language-neutral by default; the project's own language rules live in
[§ Language profile](#language-profile) and in [`ai-docs/context.md`](context.md). New rules append under
the relevant section.

## Language profile

> **Fill this in per project.** Everything below this section is language-agnostic and needs no edit.

| Field | Value |
|---|---|
| Primary language(s) | `%LANGUAGES%` |
| New-file rule | e.g. "new sources MUST be `%EXT%`; existing `%LEGACY_EXT%` files stay idiomatic, no proactive migration" |
| Max line length | `%MAX_LINE_LEN%` |
| Formatter | `%FORMAT_CMD%` |
| Linter (the gate) | `%LINT_CMD%` |
| Source root / test root | `%SRC_ROOT%` / `%TEST_ROOT%` |
| Test-file mapping | `<Name>` → `<Name>Test` under the test root, same package/module |

Idiom rules that only make sense for one language (stdlib preferences, DI-framework conventions,
migration-tool choice, metrics library) belong here or in `ai-docs/context.md` — not scattered through the
sections below.

## Linter posture

- **A formatter is not a gate.** An auto-fix run (`%FORMAT_CMD%`) mutates files and exits 0 even when
  non-auto-fixable violations remain. The gate is the plain lint run (`%LINT_CMD%`), which exits non-zero
  on any remaining violation. Correct sequence: format, THEN lint as the verification. NEVER report "lint
  clean" on the basis of the formatter alone.
- Never edit the formatter's config (`.editorconfig` and friends) to make a violation go away.
- A suppression (`@Suppress` / `# noqa` / `//nolint`) MAY carry a justification comment naming the specific
  rule and reason — recommended when the reason is genuinely opaque, but NOT required, and its absence is
  never a defect (§ Comments: the default is no comment).

> **A missing suppression-justification is NOT reviewable.** Reviewers may voice it ONCE as a suggestion,
> applied only with the PR author's agreement, and may not restate it in a later round. It carries no
> severity and never blocks. Deliberately asymmetric with § Comments: DELETING narration is `major`; ADDING
> a comment is never more than a suggestion — with one closed exception, the `@throws` mandate in
> `ai-docs/doc-convention.md § @throws requirement`, which a reviewer MAY require. An identical suppression
> elsewhere in the same file carrying no comment settles the question in the author's favour. (Enforced in
> `.claude/agents/self-review.md`, `.claude/agents/review-findings.md`,
> `.claude/skills/project-review/SKILL.md`.)

## Magic numbers

Numeric literals with semantic meaning → a named constant in the language's constant idiom
(`SCREAMING_SNAKE_CASE`). Self-evident constants (`0`, `1`, `-1`, `2`) and test fixtures are exempt.

```text
DEFAULT_RETRY_COUNT = 3
LANGUAGE_CACHE_SIZE = 1024

withRetry(3) { ... }   // ❌ what does 3 mean?
cache(1024) { ... }    // ❌ what does 1024 mean?
```

## Dependency injection / wiring

- **Constructor injection.** Never field injection. Constructor params are immutable + testable.
- **Prefer the least-magical stereotype** that carries the semantics you need; reserve specialised
  annotations for cases where their behaviour (transaction management, exception translation) matters.
- **Configuration binds to a typed object**, not to individually-injected scalar values — one binder class
  per config group, so defaults are readable in one place.
- **Prefer explicit mechanisms for NEW wiring** — a direct call, a poll/discovery task, or an outbox/queue
  row — over publishing a framework event. An in-transaction event listener does NOT implicitly insulate
  the enclosing transaction from the listener's side effect: without a `try/catch` (or a new transaction
  boundary) a failure propagates out and rolls the operation back. Keep in-transaction work trivial (an
  idempotent schedule/enqueue) and run heavy work later, off-transaction.

## Documentation

**Doc-comments are NOT written by default** — § Comments below governs, and code is the single source of
truth. Visibility never triggers a doc-comment: a public symbol carries **no** doc-comment just for being
public. A doc-comment that restates the signature or narrates WHAT a symbol is / does is a narration
finding (`major` — see `self-review` / `/project-review` Checklist 6); strip it and rename the symbol
instead.

Write a doc-comment ONLY when it carries information the signature cannot — a non-obvious WHY, or a real
public-API contract the types cannot express (`@throws` semantics, a non-obvious `@param` / `@return`
constraint, a documented ordering/nullability invariant — **and only after checking the claim against the
language**). A comment asserting an invariant is a CLAIM about the code, held to the same standard as any
other claim: "this branch order is load-bearing" over an exhaustive match on a closed type is false by
construction, because the branches are pairwise disjoint and reordering cannot change behaviour. Prose that
invents a fragility the type system already excludes is worse than no comment — it propagates into the
design doc and every downstream summary as ground truth. If the invariant is real, pin it with a test and
write nothing. `ai-docs/doc-convention.md` governs the SHAPE of a doc-comment when one is genuinely
warranted; it is not a mandate to comment every public symbol.

- `@param` / `@return` / `@throws` — only on the doc-comments that ARE written, for the non-obvious cases
  (multi-arg functions, error semantics).

## Error types

- **A closed type** (sealed class / sealed interface / tagged union / enum-backed error) for a finite
  domain-error hierarchy.
- **A result type** for fallible operations whose error set is finite and callers must handle.
- **Argument / state guards** (`IllegalArgumentException` / `IllegalStateException` or the language's
  equivalent) for invariant violations that indicate a programming error.
- **Never swallow exceptions.** No empty catch blocks. Either log + re-throw, or convert to a domain error.
- **Never throw from inside a lazy/streaming builder** without a corresponding downstream handler.

## Tracing / logging

- **Lazy message construction.** Prefer the lambda/structured-argument form (`logger.info { "event $arg" }`
  or `logger.info("event {}", arg)`) over string concatenation — concatenation pre-evaluates even when the
  level is disabled.
- **Level vocabulary:** `debug` for development-grade detail; `info` for state transitions; `warn` for
  recoverable anomalies; `error` for genuine failures.
- **Request-scoped context (MDC or equivalent)** for tracing. Use the project's existing field names
  verbatim (record them in `ai-docs/context.md`); don't invent variants.

## Metrics

NEVER register a gauge whose value supplier performs an IO/DB read — the supplier runs on the scrape
thread, where a timeout degrades the ENTIRE metrics payload. For any value needing a query (row counts,
backlog sizes), cache it off the scrape path via a scheduled refresh. Counters/timers incremented on an
operation are fine; only gauge SUPPLIERS that touch IO are the anti-pattern.

## DB migrations

Pick ONE migration tool per repo and record it in `ai-docs/context.md`; never add a migration in a second
tool's format because it is more familiar.

**Local conventions — read the sibling migrations before writing.** Put an alteration in **that table's own
migration file**, never aggregated into a shared cross-table file. Match the surrounding directory's
changeset id format, its rollback posture (present or deliberately omitted), and its naming — these are
conventions of the directory, not of the tool, so inspect the adjacent migrations rather than reasoning
from the tool's documentation. Describe file path, migration id, and rollback plan in the design doc.

## File size

Target **200–400 lines** per source file excluding test fixtures. Soft **500 / 800**; hard **1000 / 1500**.

| Limit | What it means |
|---|---|
| < 200 | OK |
| 200–500 (excl. tests) | OK — typical |
| 500–800 | Soft — flag during PR review; consider split if responsibilities mix |
| 800–1000 | Hard-ish — must justify in the PR description |
| > 1000 | Hard limit — refactor before merge unless explicitly exempt |

Exemptions: auto-generated code, and single large `when` / `switch` expressions where splitting obscures
control flow.

**Don't flag cohesive small-to-medium files for being "monolithic"** — one-class-per-file is anti-idiomatic
in languages where cohesive value objects naturally group.

## Naming

- **Types:** `PascalCase`. **Functions / properties:** `camelCase` (or the language's idiom).
  **Constants:** `SCREAMING_SNAKE_CASE`. **Packages/modules:** the language's convention.
- **Test classes:** `<UnderTest>Test`.
- **Test methods:** BDD `should …` names — `should <observable behaviour> [when <condition>]`. One
  meaningful user/system-as-user scenario per test; arrange/act/assert as blank-line blocks, not
  `// given` / `// when` / `// then` markers.

## Test fixture state

**When a test bean/fixture factory captures mutable state in a closure, treat it as a leak until a reset
exists.** Test containers and DI contexts are typically cached PER CLASS: database fixtures and mock
auto-reset restore what the framework knows about, but nothing touches a plain mutable holder captured by a
factory. That state survives across every test method in the class.

- **Hoist it into its own injectable component** so a test can reach and reset it — a closure-captured
  value cannot be reached at all.
- **Prefer resets that cannot drift** — clear *all* mocks, or reinitialise the whole holder — over a
  hand-maintained enumeration that must be edited whenever a mock or key is added. A setup hook whose name
  advertises partial cleanup (`clearInvocationsOnly`) is a standing admission the enumeration is already
  incomplete.
- **Diagnostic corollary.** When an integration test fails on a value that production code writes
  UNCONDITIONALLY, suspect the FIXTURE before the production path: ask what the context carries across
  methods, and whether the passing tests pass because they run first or because they use a different key.
  This shape emits no signal until a second consumer of the same key appears — and then it presents as a
  production defect.

## Comments

Applies to **all languages** the repo carries, including scripts under `.claude/skills/*/scripts/`.

Default to writing no comments. Add one when the WHY is non-obvious: a hidden constraint, a subtle
invariant, a workaround for a specific bug. If removing the comment wouldn't confuse a future reader, don't
write it.

Don't explain WHAT the code does — well-named identifiers already do that. Don't narrate or restate the
signature — a doc-comment that repeats the function name, params, and return type carries zero information
and rots.

A doc/inline comment that paraphrases the symbol name, its type, or its json/serialization tag is
narration — a `major` finding. **Delete it; do not "improve" the wording.** If a line needs a `//` to
explain WHAT, rename or extract instead. Applies to **prod AND test code** — test intent lives in the test
name, never a `//`.

```go
// ❌ narration — restates the field name; delete it
// verbose, when true, dumps each request/response
verbose bool `json:"verbose"`

// ✅ keep ONLY a non-obvious why the code itself cannot express
// 4 KiB: upstream gateway truncates request bodies past this; larger payloads silently drop
maxBodyBytes int
```

**The narration often hides as the FIRST sentence of an otherwise-justified comment.** An LLM reflexively
opens a doc-comment with a one-line "what this is" summary, then appends a real why — so narration rides in
as sentence 1 even when the body is legitimate. Read each doc-comment's OPENING sentence on its own: if it
restates the symbol name / type / signature / return, DELETE that sentence and keep only the why-tail. Do
not keep a whole comment merely because it contains a why somewhere.

**New symbols default to ZERO doc-comments — including when mirroring a precedent.** When you model a new
class/function on an existing one, copy its STRUCTURE, never its doc-comments. A ticket number in a comment
is not automatically a why — it is justified only when the code cannot otherwise reveal a non-obvious
constraint. Before writing any doc-comment on a new symbol, check whether the type name + symbol name +
method names already convey it; if so, write nothing.

**A cleanup round must be purely subtractive on comment lines.** When the mandate is to REMOVE or shrink
comments, the bar goes UP, not down — the recurring failure is re-opening a compressed doc block with a
fresh one-line summary that never existed before. Before declaring such a round done, COUNT the comment
lines the diff ADDS and justify each individually, or confirm the count is zero. Compressing a block is not
a licence to introduce a summary sentence: a first sentence restating the signature is narration no matter
how much prose was deleted around it. The bar drops precisely when an edit is framed as cleanup rather than
authoring.

A genuine non-obvious *why* is NOT narration and must NOT be stripped — e.g. `// per-RPC creds require
transport security, so the test uses only transport-independent options`. The narration-vs-why call is a
**semantic** reading of authorial intent, never a token-match against the nearby symbol name: a comment can
share words with the symbol and still be a legitimate why, and cleverly-worded narration can avoid the
symbol's tokens entirely. Judge by "could a future reader recover this from the code?" — not by lexical
overlap. (This is why the rule is a reviewer / `self-review` judgement, not a mechanical gate.)

Don't reference the current task / fix / callers ("used by X", "added for the Y flow"). Those belong in the
PR description and rot as the codebase evolves.

**NEVER leave a stale comment.** Agents treat comments as ground truth — a comment that contradicts the
code propagates false facts about the codebase. When you edit code near an existing comment, **verify the
comment is still true or DELETE it**; never let it drift out of sync with the code it describes. A deleted
stale comment is strictly safer than a kept stale one.

**Verify a factual claim in a comment against the source before writing it.** A comment (or provenance
note) that names a framework / library / tool, asserts an annotation is present, or claims an API field's
presence/absence is a FACTUAL claim — confirm it against the authoritative source (imports / dependency
manifest / config class / proto / DTO / API schema), NOT memory or a neighbouring pre-existing comment (a
wrong term self-perpetuates repo-wide). Absence claims ("there is no `X` field", "the API doesn't expose
`X`") are the easiest to state confidently and get wrong — verify against the schema model, not secondary
prose (a SKILL.md or another comment can itself be wrong). Same discipline for a framework/tool name in a
commit message or PR body.

## Shared module over copy-paste at ≥3 sites

When the same constant / helper / value type / test fixture would need to be replicated across **≥ 3**
modules to satisfy a contract, prefer lifting it into a shared module over per-site duplication — even when
each individual copy is small.

The "minimal surface / no new module" argument is locally true but globally loses to maintenance burden
once duplicated code lives in 3+ places: any future change has to land in lockstep across every copy, drift
goes undetected by the compiler, and review noise scales with the duplication factor.

| Call-site count | Action |
|---|---|
| 1 | inline — no abstraction yet |
| 2 | borderline — duplicate is acceptable if the growth trajectory is flat; lift if there's an open-ended "we'll add more as needed" trajectory |
| ≥ 3 | **lift** — shared module, or re-export from an existing common module |

Detection trigger: any draft text that proposes copying a constant / helper / fixture across modules and
justifies it with "minimal surface" / "no new module" / "trivial duplication" without naming the call-site
count and growth trajectory — STOP and count. If count ≥ 3 (or ≥ 2 with open-ended growth), flip to a
shared module and record the decision in the task's design doc (`ai-docs/plans/*.design.md`, archived to
`done/` on merge).

## Patterns

Validated approaches the agent should keep applying (carrot signals; soft verbs). Populated by `/improve`
when the Learning Log shows a repeated validated approach; empty by default.

_(none yet)_

## Cross-link

The test-conventions block lives in `AGENTS.md § Test Conventions`. Doc-convention detail lives in
`ai-docs/doc-convention.md`. Both are propagation-linked.
