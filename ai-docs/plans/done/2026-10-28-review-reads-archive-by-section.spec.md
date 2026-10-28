## Out of scope

- **Stale absences.** A section from an older spec can be false after a later task did what it says was
  left out. The listing shows it as written. Lasting current state is GH-165.
- **Retiring the closing fold** (GH-173). This change works whether or not the fold still runs, and
  neither change depends on the other shipping first.
- **Migrating archived plans.** GH-129 is no longer needed for reading; its remaining scope moves to GH-165.
- **What silences a finding, and the use-case coverage predicate.** Both keep their meaning.
- **A size limit on stored plan documents** — this ticket's original statement. The cost is in what the
  reader reads, not in what is stored.
- **Refusing a future whole-document reader.** A later change that adds a reader of archived plans with
  neither the listing nor a stated reason is caught in review. No check of the repository's refuses it.
- **Other files in the archive** — declared-link records, design evidence, a correction log awaiting the
  fold, a progress file left behind. The review does not read them today and does not start.
- **Plans still in progress**, and the in-task reviewers, which do not read the archive.
- **Narrowing the listing to plans relevant to the code under review.** Nothing in a plan says which code
  it governs, so the listing covers the whole archive.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| Bounding the listing's own growth | It grows by one plan's sections per task; replacing archived history with current statements is the lasting fix | No — GH-165 |

## Key decisions

| Question | Decision |
|---|---|
| Which sections the listing carries | The spec's Out of scope, Deferred and Key decisions, and the design's Use cases — fixed by the ticket. Nothing else from a plan document. |
| Does the review still read designs for how things were built | No. Per the ticket, that part is the design's account of how things were built, which the code states more reliably. |
| Where a plan's date comes from | The date in the plan's file name: the one date every archived plan carries in both shapes. A collapsed spec has no date header, and a design's own date header can differ from its plan's: 3 of the 15 archived designs carry a later date than their file name, counted by a header scan of the archive on 2026-10-28. |
| Where a plan's task key comes from | The spec's tracking header when it has one, else the design's ticket header. A collapsed spec has lost its header; every archived design carried a ticket header when the archive was read on 2026-10-28. A plan naming its key in neither is listed with the key shown as absent, never dropped. |
| Stored or computed | Computed from the archive each time it is read. A committed copy would be stale at the next archived plan. |
| Where a section ends | At the next heading of the same or a higher level that is not inside a fenced block. Everything from its heading to that point is printed exactly, heading included. |
| A design with no Use cases section | Listed as absent. 8 of the 15 archived designs predate the section (counted by a heading scan of the archive on 2026-10-28); they contribute no case to the coverage check, as today. |
| What counts as an answer for a reader that does not use the listing | A statement of what it needs that the listing does not give it. For a reader of whole documents that is why it needs the whole document; a reader of one part of a document names that part. |
| Where such a reader records its reason | Beside the read, in the file that does it. A reason recorded only in this task's plan becomes archived history the moment the plan is archived. |
| A reader of archived plans added after this change | Not refused by the repository's checks. Today's readers are cleaned up; a later one is a review finding. The owner's choice. |
| A plan missing its spec or its design | Listed, with the missing document shown as missing and its sections absent. |
| The base principle whose reason this change falsifies | Its stated reason is rewritten so it is true after this change; the rule itself is unchanged. Its restatements change with it. |
| The listing cannot be produced in full | The review says so in its output and never treats the missing part as an archive that records nothing. Whether it then stops or reads the affected documents in full is the design's choice. |

