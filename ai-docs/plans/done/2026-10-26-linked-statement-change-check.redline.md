# Redline log: Catch a one-sided edit to linked plan statements

**Tracked in:** GH-162
**Spec:** ai-docs/plans/2026-10-26-linked-statement-change-check.spec.md
**Design:** ai-docs/plans/2026-10-26-linked-statement-change-check.design.md
**Mode:** Hybrid — the owner's word for the whole task, on the recommendation that two of the design's three
parts change sites whose shape already exists: `## Approach` says the amendment that keeps the approach
"gets the re-read that three instruction files promise it" and that the per-push reconciliation "is replaced
by one read of the ticket and one rewrite of the description"; and `## Open questions` is "(none)".

| Key | Type | Artefact sentence diverged from | What shipped instead |
|---|---|---|---|
| R1.1 | modified | `ai-docs/plans/2026-10-26-linked-statement-change-check.design.md` § Approach › The pull-request description and the ticket, the bullet opening "The description" — "and at most a closing trailer the project's profile permits" | the shape section says the description carries the closing trailer the profile names, for the issue the PR resolves, and every in-place rewrite keeps it |
| R1.1 | modified | `ai-docs/plans/2026-10-26-linked-statement-change-check.design.md` § Approach › The pull-request description and the ticket, the bullet opening "The trailer's condition stays a profile fact." — "The method page says no more than that a closing trailer the profile permits is allowed" | the method page says the description carries and keeps the profile's closing trailer for the issue the PR resolves; the profile keeps the spelling and its condition |
| S8.1 | modified | `ai-docs/plans/2026-10-26-linked-statement-change-check.design.md` § Approach › The pull-request description and the ticket, the bullet opening "The description" — "the bullets on the title, on keeping a small pull request to the files asked for, and on an identifier being an action stay as they are" | the bullet on an identifier being an action on `docs/workflow.md` § PR title + body shape loses its allowance for a PR title or description — there no ticket but the PR's own is named, wrapped in backticks or not, and a ticket cited for context is described in prose without its key; the bullets on the title and on a small pull request stay as they are |
| S8.2 | modified | `ai-docs/plans/2026-10-26-linked-statement-change-check.design.md` § Approach › The pull-request description and the ticket, the bullet opening "The description" — "The template's body bullet defers to that section without restating the shape, keeping its rule against naming another ticket key" | the template's body bullet on `skills/task/reference.md` § Step 12 — PR-body template (detail) keeps its rule against naming another ticket key with the exception for a backtick-wrapped key removed |
