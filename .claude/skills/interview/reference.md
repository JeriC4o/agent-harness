# /interview — reference

Detail bodies extracted from `SKILL.md` to keep the orchestrator under the 200-line soft target. Loaded on demand.

## State file — YAML schema

Path: `<spec_path>.state.md` — e.g. `ai-docs/plans/2026-05-25-name.spec.md` ↔ `ai-docs/plans/2026-05-25-name.spec.md.state.md`.

Created at round 1; deleted on terminal exit. Format: a markdown header followed by a single fenced YAML block:

```yaml
schema_version: 1
spec_path: ai-docs/plans/YYYY-MM-DD-name.spec.md
ticket_ref: "TICKET-KEY"
ticket:                          # present only when ticket_ref resolves to a real ticket; omitted for free-text mode
  key: "TICKET-KEY"
  title: "<verbatim from the tracker>"
  status: open                   # open | closed
  description: |
    <verbatim ticket description>
task_description: |              # present only in free-text entry mode (mutually exclusive with ticket)
  <user's free-text task description>
round_cap: 4
questions_per_round_cap: 4
round: 2
prior_qa:
  - round: 1
    question: "..."
    proposed_options:              # option labels surfaced via AskUserQuestion (excluding the auto-appended `Other`)
      - "Option A"
      - "Option B"
      - "Option C"
    answer: "..."                  # one of `proposed_options` (user picked it), OR free-form text (user picked `Other` and typed). When `answer` doesn't match any `proposed_options` entry, treat as a free-form `Other` reply and interpret against the proposed list (e.g. "between A and B").
```

## AskUserQuestion tool schema (consumed at Step 3d)

The orchestrator surfaces the spec-writer's questions via `AskUserQuestion`. Tool-side limits the orchestrator must honour:

- **Questions per call: 1–4.** The tool accepts an array of 1 to 4 question objects. `questions_per_round_cap = 4` matches this ceiling — Step 3d's validation rejects anything > 4.
- **Options per question: 2–4.** Each question's `options` array must have 2–4 entries.
- **Automatic `Other` option.** The tool auto-appends an `Other` choice that lets the user type free-form text — do NOT include `Other` in the supplied `options` array (would duplicate the auto-injected one). The labels of the *proposed* options are persisted into `prior_qa[].proposed_options` (see State file above) so a later round's spec-writer can interpret a free-form `Other` answer that references the original options ("between A and B").
- **Header length ≤ 12 chars.** Each question's `header` field (the chip/tag label) is capped at 12 characters.

Step 3d's validation (`len(questions) <= questions_per_round_cap`, `header` ≤ 12 chars, `options` 2..4) is the project-side enforcement of these bounds; the tool-side schema is the authoritative ceiling.
