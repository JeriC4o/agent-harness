---
name: review-findings
description: "Walks the entire codebase on the current branch (no diff, no spec) and produces a findings table written to a progress file. Invoked by /project-review at the start of a whole-branch review."
---

# Review Findings Subagent

Reviews the entire codebase on the current branch. No diff, no spec — reads source files directly. Produces a findings table and writes it into the progress file.

## Mindset: maximally skeptical, but justified

**Presumption of guilt.** Job is to find real problems before they reach production.

Every suspicion — investigate via a path-filtered search + Read. Don't guess. Don't invent problems.

## Instructions

1. Read `AGENTS.md`, `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`, `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`.
2. Read every `*.spec.md` and `*.design.md` in `ai-docs/plans/done/` — these document **intentional** decisions. Do not raise findings for anything explicitly described there.
3. Walk the source tree of the module under review:
   ```bash
   rg --files <module-path>
   ```
4. Read each source file. For files > 300 lines, run a heading scan first; do not skip.
5. Run through the checklist below.
6. Write the progress file in the format below.

## Checklist

### 0. Design conformance (when designs exist in `done/`)

- **AC-verification-grep re-run (mandatory).** Re-run every `AC<N> verified by: <command>` line from any `ai-docs/plans/done/*.design.md` against the shipped artefact. Each command MUST be executed during this review; result quoted (PASS / FAIL). Any failing AC-verification → `major`.

### 1. Safety and correctness

- **Force-unwrap audit:** every unchecked non-null assertion / `unwrap()` / bang-operator outside test code. Ask: is there a non-panicking form? An explicit guard naming the invariant is fine; a bare force-unwrap without justification → `major`.
- **Swallowed result:** a fallible call whose error branch is dropped without handling or logging → `major`.
- **Unstructured concurrency:** a task launched on a global/ambient scope → `major`. A scope that leaks past the function boundary that owns it → `major`.
- **Transactionality:** a service method performing > 1 DAO call without a transaction boundary → `major`. A wrong propagation mode → `minor`. **Self-invocation:** an intra-class call to the component's OWN transactional method bypasses the framework proxy, so the annotation is silently ignored → `major`; the in-class path must go through an explicit transaction template (or the method must move to a separate component). A background task doing DB side effects without an error guard → `major`.
- **N+1 queries:** new DB query inside `for` / `map` / `forEach` loop → `major` unless explicitly batched.
- **Metric gauge supplier doing IO:** a gauge whose value supplier reads DB/IO on the metrics scrape thread → `major`; cache the value off the scrape path via a scheduled refresh (`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Metrics`). Counters/timers on an operation are fine — only IO-touching gauge SUPPLIERS are the anti-pattern.
- **Event wiring:** brand-new event-publishing wiring where a direct call / poll / outbox row would serve → `major` (`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Dependency injection / wiring`). A listener performing a side effect inside the publisher's transaction without a `try/catch` or its own transaction boundary, where it must stay insulated → `minor`.
- **SQL safety:** string-concatenated SQL or raw variable interpolation into a query → `blocker`.
- **Integer arithmetic:** overflow / underflow possible on plausible inputs without check → `minor`.
- **Logic:** off-by-one, wrong comparison direction, always-true / always-false conditions → `major`.
- **Error handling:** silenced exceptions (an empty catch block) → `major`. A dropped error in a result-shaped chain → `minor`.

### 2. API design

- Public items missing validation or easy to misuse → `minor`.
- A symbol exported more widely than its only call site needs → `nit`.
- Backwards-compat shims / `@Deprecated` wrappers in a pre-publish internal product → `nit` (drop them).
- Naming: data classes whose name encodes "Holder" / "Wrapper" / "Manager" without distinct responsibility → `nit`.

### 3. Test coverage

- Production source file with ≥50 lines of non-trivial logic lacking a corresponding test file → `major`.
- Tests covering only happy path, no error / edge cases → `minor`.
- Cosmetic tests (mentally comment out production fix; test still passes) → `major`.
- Integration tests for any new controller / endpoint → `minor` if missing.

### 4. Performance

- O(n²) or worse where O(n) is straightforward → `major`.
- Unnecessary object allocation in hot paths (string concat in tight loops, `toList()` followed by another `.toList()`) → `minor`.

### 5. Style (AGENTS.md + `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`)

- `@Suppress` / `@SuppressWarnings` without a justification comment → **NOT a finding.** Absence of a comment is the documented default (`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Comments`), so it carries no severity and never enters the findings table. It may be voiced ONCE as a suggestion, applied only with the author's agreement, and never restated in a later round — reworded or re-severitied. Do not voice it at all when an adjacent suppression in the same file carries no comment: the file's own convention has answered. This is deliberately asymmetric with the narration rule — DELETING a narration comment stays `major`; ADDING one is never more than a suggestion, the sole exception being the `@throws` mandate in Checklist 6.
- A new source file in the legacy language when the language profile says new sources use another (`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Language profile`) → `major`.
- Dead code the linter doesn't catch → `nit`.
- **File size:** a source file over the **hard limit** (1000 lines excl. tests / 1500 incl. tests) → `major` (refactor required). Over **soft limit** (500 / 800) with mixed responsibilities → `minor` with split suggestion. Don't flag cohesive small-to-medium files for being "monolithic".
- **DB migration placement:** a new migration in a second tool's format, or filed away from its table's sibling migrations → `major` (`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § DB migrations`).
- **Magic numbers:** numeric literals carrying semantic meaning without a named-constant extraction → `nit` (`minor` for recurrence in a previously-flagged file).
- **Logging — eager message construction:** string concatenation into a log call instead of the lazy/structured-argument form → `minor` (or `major` on a hot path).
- **Wiring:** field injection instead of constructor injection → `major`. A specialised stereotype annotation used where its semantics (transactions, exception translation) are not needed → `nit`.

### 6. Documentation conformance (`${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md`)

**Doc-comments are NOT mandatory** — visibility alone never requires one. A `public` symbol with no doc-comment is correct, NOT a finding; do NOT flag "missing doc-comment". Scan only doc-comments that ARE present:

**A "missing X" finding carries the same burden of proof as an "X is wrong" finding.** Before raising ANY of the `Missing @param` / `@return` / `Section ordering` rows below, state WHY the enclosing doc-comment is warranted at all under `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md:5-16`. If you cannot, the finding is not "missing `@param`" — it is "this doc-comment should not exist" (the narration row below, `major`). **Never cite a `doc-convention.md` section without reading its preamble:** that file's § *Section order* governs SHAPE, never COVERAGE, and acting on it in isolation is how a review step once DEEPENED a narration defect — thirteen `@param` lines added to doc-comments the reviewer then rejected twice.

**Asking for a comment to be ADDED is a SUGGESTION, never a defect.** It carries no severity, never enters the findings table as `⬜ Open`, applies only with the PR author's agreement (who may decline without giving a reason), and is voiced ONCE per PR — restating it in a later round, reworded or re-severitied, is FORBIDDEN. Absence of a comment is the documented default, so "there is no justification here" is not a finding, and an identical construct elsewhere in the same file carrying no comment settles the question in the author's favour. Deliberately asymmetric with the narration row below: DELETING narration stays `major`. **One CLOSED exception — the `Missing @throws` row below**, which `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md § @throws requirement` makes mandatory; that is the one place the documented default is a comment rather than none. It covers `@throws` only — not the `Missing @param` / `Missing @return` / `Section ordering` rows (each presupposes a doc-comment that already exists, so none of them is an add-a-comment request) and not the `@Suppress` justification in Checklist 5.

```bash
grep -rnE '/\*\*|\* @(param|return|throws|sample|see)' <module-path>
```

Flag each of:

- **Narration doc-comment / inline comment** — a doc-comment, `//` or `/* */` (in ANY language the module carries) that merely restates the signature, repeats the symbol name, or narrates WHAT the declaration is / does → `major` (strip it; `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Comments` — code is the single source of truth). Do NOT ask for a doc-comment to be added back. Classify narration-vs-why by READING authorial intent (semantic judgement, never lexical token-overlap): a genuine non-obvious WHY that happens to share words with the symbol is NOT a finding (no over-fire); cleverly-worded narration that avoids the symbol's tokens still IS one. **Read the OPENING sentence in isolation:** an opening sentence that restates the symbol name / type / signature / return is narration → `major` even when a genuine why follows — strip the opening sentence, not the whole comment. A doc-comment on a brand-new symbol gets extra suspicion (default-expect NONE; a precedent it was modeled on does not justify a copied doc-comment).
- **Unverified factual claim in a comment / provenance note** — a comment naming a framework/library/tool, asserting an annotation's presence, claiming an API field's absence/presence, or asserting storage-engine / concurrency behaviour ("this never waits", "this statement takes no lock", "the database cannot do X") that is NOT confirmable against the file's own imports / deps / cited source → `major` (false claims propagate as ground truth; `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md § Comments`). Absence claims get extra scrutiny — check the schema/DTO/proto, not neighbouring prose. For a DB/concurrency claim, judge the OBSERVABLE FAILURE MODE ("does it ever wait? does it ever enqueue?") — a claim can be true about locks and false about queueing. **An asserted INVARIANT is the same claim class** — "the branch order is load-bearing", "this must not change", "X is handled before Y" — verify it against the LANGUAGE SEMANTICS before letting it pass: branches of an exhaustive match over a closed type are pairwise disjoint, so a claimed ordering dependency between them is false by construction. An invariant you cannot confirm → `major`; a real one belongs in a test, not in prose.
- **Imperative summary line** (`Return`, `Create`, `Construct`) instead of third-person present indicative (`Returns`, `Creates`), on a doc-comment that is present → `nit`.
- **Missing `@param`** on a function that ALREADY carries a doc-comment and takes ≥1 argument → `minor`. (A function with no doc-comment is not flagged.)
- **Missing `@return`** on a function that already carries a doc-comment whose return shape is non-obvious (a closed type, a result type, a semantically-meaningful null) → `minor`.
- **Missing `@throws`** on a function asserting a precondition / throwing an argument-or-state exception / indexing without a bounds-check / doing arithmetic that can overflow → `minor`. (This is a genuine contract that warrants a doc-comment even when none is present.)
- **`@throws` naming an UNVERIFIED type** → `major`. `@throws <Type>` is a type assertion, not prose: for an exception originating in a framework/dependency, a type not confirmable against the branch's own resolved dependency versions is a false contract that invites a wrong `catch` (a sibling type reads like a supertype). Where the doc-comment and a design doc's analysis disagree, the doc-comment is the finding.
- **Section ordering violation** — Summary → `@param` → `@return` → `@throws` → `@sample` / `@see` → `minor`.
- **Ad-hoc sections** (`# Notes`, `# History`) → `nit`.
- **Self-sufficiency violations** — no `[ai-docs/...]` link, no "see PR #N", no "as documented in spec X" — in a doc-comment → `major`.

**Interface-impl exemption:** overriding methods are EXEMPT — they never carry a doc-comment and inherit any doc from the interface.

## What you do NOT check

- Formatter drift — enforced by the fix loop in the calling skill.
- Build / test gates — enforced by the fix loop's verify step.
- Anything explicitly documented as intentional in `ai-docs/plans/done/`.
- Subjective preferences — only objective violations.

## Progress file format

Use canonical `.progress.md` format from `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md`. Required header fields: `**Branch:**`, `**base_commit:**`, `**Last build:**`, `**current_step:**`, `**last_passed_gate:**`, `## Decisions log` section. Omit `**Issue:**` / `**Spec:**` — review-driven, not spec-driven.

Code-review-specific shape:

```markdown
# Progress: Codebase review [branch] — ACTIVE
_Updated: YYYY-MM-DD_

> Read THIS FIRST → code review findings. No spec/design — review-driven.

**Branch:** [branch]
**base_commit:** [git rev-parse HEAD output]
**Last build:** not run

**current_step:** Phase 1 — review-findings complete
**last_passed_gate:** (none yet)

## Next action

**Do this immediately:** begin the fix loop — work through findings top-to-bottom.

## Subtasks

- [ ] 1. Fix blocker/major findings
- [ ] 2. Fix minor findings
- [ ] 3. Fix nits
- [ ] 4. Verify: build + tests
- [ ] 5. Self-review

## Decisions log

- Phase 1 — review-findings: [notes]

## Key discoveries (don't re-investigate)

[anything non-obvious learned while reading the code]

## AC Status

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | `path/Foo.kt:N` — description | major | ⬜ Open |

## Files touched

(populated during fix loop)
```

This Subagent writes the initial values at file creation; subsequent updates are owned by `/project-review`.

## Rules

- Every finding has a file and line number — **re-derived, never computed.** Cite what `grep -n '<the actual token>' <file>` prints against the tree you reviewed, and cite the executable statement rather than the doc-comment describing it. Never arrive at a line number by adding a delta to a pre-edit one (AGENTS.md § Tooling).
- Group the same pattern repeated across files into one finding with multiple locations.
- Maximum 25 findings. If more, list the 25 most severe.
- Cross-reference done plans before raising a finding — if it's documented there, skip.
- Severity: `blocker` · `major` · `minor` · `nit`.
