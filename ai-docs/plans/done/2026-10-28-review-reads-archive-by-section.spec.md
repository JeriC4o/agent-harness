# The whole-repository review reads only the sections it uses from archived plans

**Source:** ticket GH-110
**Date:** 2026-10-28
**Tracked in:** GH-110

## Scope

The whole-repository review reads every spec and design in the archive of completed plans, in full, on
every run. It uses two things from them:

- the spec's record of deliberate absence — its Out of scope, Deferred and Key decisions sections — which
  is the only thing allowed to silence a finding;
- the design's Use cases section, which drives the use-case coverage check.

Measured on 2026-10-28 by a character count over every archived spec and design (the owner's figure in the
ticket, reproduced independently while drafting this): 1,463,656 characters in all, of which those four
sections are 132,948. The rest is the design's account of how things were built, which the code states
more reliably. The archive grows by one spec and one design per task.

A **plan**, below, is the spec and the design in the archive that share one file-name stem; either may be
missing. The **archive listing** is the new output this task adds.

1. **The archive listing.** For every plan in the archive it shows the plan's date, its task key, the names
   of its documents, and the four sections above, verbatim. It is produced from the archive as it stands
   each time it is read.
2. **The review reads the listing instead of the documents.** It opens a single archived plan document in
   full only to settle a specific finding. What can silence a finding, and what the use-case coverage
   check requires, do not change.
3. **Both archive shapes read the same.** A full spec, and a spec the closing fold collapsed to its record
   of deliberate absence — which keeps the three sections and loses its title and header fields — are
   listed alike. No archived document is migrated or edited.
4. **Every other reader of the archive is found and cleaned up.** Each instruction or script shipped with
   the harness that reads archived plan documents either takes what it needs from the listing, or states
   where it does the read what it needs that the listing does not give it — for a whole-document reader,
   why it needs the whole document. This covers the readers that exist when the change ships.
5. **Sentences this change makes untrue are made true.** Every shipped sentence saying the whole-repository
   review reads archived plans in full is corrected. That includes the stated reason of the base principle
   that forbids a plan to carry a record of superseded material: the reason rests on exactly that claim
   today, and is restated on the principles page and in the design author's and design reviewer's
   instructions.

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

## Technical constraints

- The listing ships with the harness and runs in any project the harness is installed into, against that
  project's archive, from the installed copy. Like every method file it names no language, build tool or
  domain entity.
- The three spec sections are the same three the closing fold keeps when it collapses a spec. Whichever of
  this change and the fold's retirement lands first, the harness must not end up with two independent lists
  of the record of deliberate absence that can come to disagree.
- Instruction files that load whole at agent start stay under the project's size early warning, a threshold
  of 35,000 characters set by the project's size rule. The project context page, which lists the shell
  scripts' helpers written in other languages, measured 34,714 characters by a character count on
  2026-10-28.
- A change to a base principle's wording is a change to a protected page; its pinned copy changes in the
  same change.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | When the archive listing is read, every plan in the archive appears in it — a plan carrying none of the four sections, and a plan missing one of its two documents, included — with its date, its task key and the names of its documents, a missing document shown as missing. |
| AC2 | For each of the four sections present in a plan's documents, the listing shows the section's text exactly as it stands in the document, heading included, and says which of the plan's two documents it came from. |
| AC3 | A heading-shaped line inside a fenced block neither starts nor ends a section. Starting from a design whose approach quotes a use-cases heading inside a fenced block, followed by its real Use cases section, the listing shows the real section only. |
| AC4 | When one of the four sections is missing from its document, the listing says it is absent, distinguishably from a section that is present but empty. |
| AC5 | The listing carries nothing from a plan document beyond the plan's date, task key, document names and the four sections. |
| AC6 | A spec collapsed by the closing fold and a full spec carrying the same three sections give the same listed text for those sections. The collapsed spec's plan is listed with its date from the plan's file name and its task key from its design. No archived document is edited to achieve this. |
| AC7 | The task key is shown alone, even when its header line carries other fields: starting from a design whose ticket, date and spec fields share one line, the listing shows the ticket key and nothing after it. A plan naming its key in neither its spec nor its design is listed with the key shown as absent. |
| AC8 | The listing reflects the archive as it stands when read: a plan archived or changed since the previous read appears as it now is. |
| AC9 | In a project that has installed the harness, the listing is produced from that project's archive. |
| AC10 | On a whole-repository review, the archived plans reach the reviewer as the listing. The reviewer opens an archived spec or design in full only to settle a specific finding, never as a sweep of the archive. |
| AC11 | A finding that an archived spec's record of deliberate absence documents as intentional is still not raised; a use case listed in an archived design that no test covers is still raised; nothing in an archived design silences a finding. |
| AC12 | When the listing cannot be produced in full, the review says so in its output and does not treat the missing part as an archive recording no deliberate absence and no use case. |
| AC13 | Every instruction or script shipped with the harness that reads archived plan documents either takes what it needs from the listing, or states where it does the read what it needs that the listing does not give it. |
| AC14 | No shipped instruction states that the whole-repository review reads archived plans in full. The base principle against recording superseded material keeps its rule and states a reason that is true after this change. |

## Open questions

None.
