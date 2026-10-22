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

