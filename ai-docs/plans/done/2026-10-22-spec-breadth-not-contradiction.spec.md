# A spec broader than its design is not a contradiction

**Source:** ticket GH-146
**Date:** 2026-10-22
**Tracked in:** GH-146

## Scope

A spec states requirements in behaviour terms and is broader than its design by construction; the design
is the precise plan. Today plan review treats that difference as a contradiction and offers one remedy:
narrow the spec until it matches the design. The narrowed text duplicates design detail, costs a user
approval and a fresh planning round, and is deleted at the closing fold when the spec collapses to its
record of deliberate absence. On the convergence-check task merged earlier the same day, design review
asked for spec amendments on three points that changed nothing built — a criterion saying every class,
count and verdict is unchanged, a decision saying the invocation is unchanged, and a constraint saying an
absent required input is cannot-run — and the user rejected all of them.

The work replaces "the spec sentence is broader than the design" as an amendment trigger with a test that
separates a genuine conflict from mere breadth, and applies that one test everywhere a spec amendment can
be triggered.

1. **The test.** A spec sentence is read for its intent within the whole spec. Three cases, and only the
   third is a finding against the pair:
   - **Breadth** — the spec is general or silent where the design is specific. Not a finding.
   - **A departure the spec itself requires** — the design departs from a literal reading of one spec
     sentence because another sentence of the same spec (a criterion, a constraint or a key decision)
     requires what the design does. Not a spec finding; the design states the departure once, in its own
     risks, and that statement is the single record.
   - **A genuine conflict** — the design does what the spec explicitly rules out (its out-of-scope list,
     a key decision, a constraint), or drops a behaviour an acceptance criterion requires, and no other
     sentence of the spec requires it. This is the only case that reaches the spec-amendment route, and
     even then the remedy may be the design complying rather than the spec changing.
2. **Design review** states that spec under-precision relative to the design is not an issue, states the
   test, and classifies a note as spec-amending only when the test admits a genuine conflict.
3. **The spec-amendment recipe** in the task workflow fires only on a conflict the test admits, from
   design review and from the implementation-time review alike.
4. **The plan-convergence reader** applies the same boundary to its self-contradiction class across the
   spec/design pair. A breadth observation is never a self-contradiction; if the reader mentions one, it
   is a note listed apart from the findings.
5. **The implementation-time subject trigger** ("would closing this finding leave a spec sentence
   untrue?") uses the same test for spec sentences: a spec sentence broader than what shipped is not left
   untrue.
6. **A pinned base principle.** The rule — a spec broader than its design is not a contradiction, and only
   a genuine conflict changes the spec — joins the base principles of a spec and a design, with its own
   reason, and is protected exactly as the existing principles are: its stored wording is verified, an
   absence is reported distinctly from a wording difference, and changing it takes the existing
   authorisation route.
7. **The reader's self-test covers the false alarm.** The planted control the convergence reader reads on
   every run gains a spec-broader-than-design case that must NOT be reported. On every run the reader
   says whether it flagged that case; a run that flags it as a contradiction says so in its report and is
   not clean.

## Out of scope

- The target arm of the amendment trigger — a fix that actually edits a spec still routes through the
  recipe, unchanged.
- Design sentences. The test is about a spec sentence against a narrower design or implementation; a
  design sentence the implementation contradicts routes exactly as today.
- What the closing fold keeps, the redline log, and the route question the recipe asks after an amendment
  (does it change the agreed approach).
- The spec author's own contract. A spec is already written in behaviour terms; nothing there changes.
- The deterministic convergence check and its six classes.

## Deferred

- (none)

## Key decisions

| Question | Decision |
|---|---|
| Where a deliberate departure is recorded | In the design's existing risks section, once — the shape the convergence-check design already used. No new design section and no new required element. A departure of the second case with no such statement is a design-side issue for the reviewer to raise, never a spec amendment. |
| Which reviews the test governs | Every point where a spec amendment can be triggered: design review, the convergence reader, and the implementation-time subject trigger shared by the task, bugfix and whole-branch review flows. The ticket's expectation is that only a genuine conflict reaches the recipe, and the recipe is entered from all of them; a second, looser test at implementation time would re-open the same narrowing there. |
| Where the test's wording lives | The rule is a pinned base principle, so its wording lives once on the base-principles page, the single authority for principle wording. The review contracts point at it rather than restating it, so they cannot drift apart. Where the three-case test's fuller explanation sits is the design's choice, provided it is stated once. (User decision, round 1.) |
| How the reader's breadth exemption is proven | On every run, not once at delivery: the self-test carries a planted breadth case alongside the planted faults, and flagging it is a reported failure of the run. A one-off confirmation would let the exemption regress silently, which is the failure this ticket is about. (User decision, round 1.) |
| Relation to the existing principle that one fact has one record | The new principle is its application at the spec/design boundary: a deliberate departure is recorded once, in the design, and the spec is not rewritten to repeat it. It adds a principle; it changes no existing principle's wording. |
| A genuine conflict's remedy | Either the design complies with the spec, routed as a design-side fix, or the requirement changes, which is a spec amendment the user approves. The reviewer does not presume the second. |
| How a reader note affects its report | A breadth note does not count as a finding, does not change the outcome word and does not enter the agreement figure. |
| Design review's own routing sentence | Stops stating a fixed re-run of the planning chain for every spec-amending note and defers to the recipe's existing route question, so the two contracts state one route. |

## Technical constraints

- The reader still reports a genuine conflict across the pair as a self-contradiction; the boundary
  narrows what counts as a conflict, never whether conflicts are found.
- A spec-internal tension that the design resolves by following the spec's more specific sentence is
  treated as the second case, not as a contradiction to amend.
- The new principle is a test, in the shape of the existing tests among the principles: it hands the
  reviewer a question (does the design do what the spec rules out, or drop what a criterion requires?),
  not a boundary on wording.
- The planted breadth case is kept apart from the planted faults: it is not a class, has no coverage
  word of its own among the classes, and its result never enters the pair's findings.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | When a design is more specific than a spec sentence, does nothing the spec rules out and drops nothing a criterion requires, design review raises no issue on that account and nothing is routed to a spec amendment. |
| AC2 | When a design departs from a literal reading of a spec sentence because another sentence of the same spec requires the departure, design review does not ask for a spec amendment; if the design does not state the departure among its risks, the review asks the design to state it there. |
| AC3 | When a design does what the spec explicitly rules out, or drops a behaviour a criterion requires, with no other spec sentence requiring it, design review raises it as a conflict, and the remedy offered is either the design complying or a spec change put to the user for approval. |
| AC4 | When the plan-convergence reader meets a spec sentence broader than a design sentence, it does not report it as a self-contradiction; any mention of it appears as a note apart from the findings and leaves the outcome word and the agreement figure unchanged. |
| AC5 | When the spec and design genuinely conflict about one object, the reader still reports a self-contradiction naming both sites. |
| AC6 | When an implementation-time review finds only that a spec sentence is broader than what shipped, the spec-amendment trigger does not fire; a finding the test admits as a genuine conflict still fires it. |
| AC7 | Given the merged convergence-check spec and design, a design review of the pair raises no issue asking to amend the spec over the criterion that every class, count and verdict is unchanged, the decision that the invocation is unchanged, or the constraint that an absent required input is cannot-run. |
| AC8 | The rule that a spec broader than its design is not a contradiction appears among the pinned base principles with its reason; when its wording is altered or it is removed without the co-ordinated update of the stored copy, the structural verification of the principles reports it, naming an absence distinctly from a wording difference. |
| AC9 | On every run of the plan-convergence reader, its report states whether the planted spec-broader-than-design case was flagged; when it was flagged as a contradiction, the report says so and the outcome word is not clean. |

## Open questions

- None.
