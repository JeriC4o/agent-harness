# Design: The whole-repository review reads only the sections it uses from archived plans

**Ticket:** GH-110
**Date:** 2026-10-28
**Spec:** ai-docs/plans/2026-10-28-review-reads-archive-by-section.spec.md

## Approach

One new script prints the archive listing; the whole-repository review reads that listing instead of the
archived documents; every other reader of the archive states, beside its read, what it needs that the
listing does not give it; and the sentences that claim the review reads archived plans in full are made
true, the sixth base principle's reason among them.

### The archive listing

`scripts/plan-archive.sh` prints the listing to standard output. It is a shell script whose extraction is
an inline program in the same file, as the fold gate's own section reader is, so it adds no payload
sibling in another language and moves none of the profile's sibling lists or counts (§ Size budget).

**Where it reads.** The project root is its one optional argument; without it, the top level of the git
work tree the current directory sits in; outside a work tree, the current directory. The archive is
`ai-docs/plans/done/` under that root. Its method inputs are resolved from its own directory, so an
installed copy reads the project's archive and the plugin's method files (AC9): the spec's three section
headings from the `RETAINED` assignment in `scripts/check-redline.sh` [retained-list], read as text the way
`retained_sections()` in `scripts/check-plan-convergence-holding.py` [retained-sections] already reads it,
and the required-element record on `docs/plan-invariants.md`. Nothing is cached: every run reads the
archive as it stands (AC8).

**What a plan is.** Every file directly in the archive whose name ends `.spec.md` or `.design.md`, grouped
by the stem before that suffix; either document may be missing. Every other file in the archive is
ignored — the declared-link and excuse records, design evidence, a surviving correction log, a stray
progress file. Plans print in stem order, which is date order.

**What each plan carries, and nothing else (AC5).**

- **Date** — the `YYYY-MM-DD` prefix of the stem; a stem without one shows the date as absent.
- **Task key** — from the spec's `**Tracked in:**` field, else the design's `**Ticket:**` field, each read
  only from the document's head: the lines before its first heading of level two or deeper, outside a
  fenced block. The value is the text after the label up to the next bold label or the end of the line,
  trimmed of whitespace and of a trailing separator, so `**Ticket:** GH-128 **Date:** … **Spec:** …` gives
  `GH-128` alone (AC7). An empty value counts as no value. A plan naming its key in neither document shows
  the key as absent and is listed all the same.
- **Document names** — the spec's and the design's file names, or `missing` for either (AC1).
- **The four sections** — the spec's three in the order the `RETAINED` assignment lists them, then the
  design's use-case section. Each is printed exactly as it stands, heading included, under a line naming
  the document it came from (AC2). A section a document does not carry, and every section of a missing
  document, prints as `absent`; a section present with nothing under its heading prints its heading line
  alone, so the two read differently (AC4).

**Where a section starts and ends (AC3).** A heading is a line opening with one to six `#` characters and
a space or tab. A fenced block opens on a line whose first non-space characters, after at most three
spaces, are three or more backticks or tildes, and closes on a line of the same character, at least as
long, carrying nothing else; every line between is inside the block. A section starts at a heading outside
a fenced block whose whole text, trailing whitespace aside, equals the wanted heading, and runs to the line
before the next heading outside a fenced block at the same or a higher level, or to the end of the file.
A heading-shaped line inside a fenced block neither starts nor ends anything. A document carrying the same
heading twice outside fences prints both, in document order: nothing is chosen away.

**Framing.** Each section line states the number of lines that follow it, and the reader takes exactly that
many. A section's own text can hold anything — a horizontal rule, a fenced example, a line that looks like
the listing's framing — so a delimiter recognised by its shape could be forged by the content it frames;
a count cannot.

**Both archive shapes list alike (AC6).** A spec the closing fold collapsed keeps its three sections and
loses its head, so its sections extract exactly as a full spec's do, its date still comes from the file
name, and its key falls through to the design. No archived document is read differently or edited.

**Outcomes.** The repository's convention for anything a caller gates on, with the findings code unused —
a listing has nothing to find:

| Exit | Meaning |
|---|---|
| `0` | Complete: every plan listed. The trailer names the archive and counts plans and documents |
| `2` | Not complete, which is never an empty archive. Run-level — no archive directory, an unreadable or unparseable method input, a missing tool — prints only the reason. Document-level — a document it cannot read, or one whose fenced block never closes, which would otherwise read every section after it as absent — still lists everything else, and the trailer names every document it could not list and why. Output-level — a write to standard output that fails — stops the run at that write, names the failed write on standard error and never prints the complete trailer, since a listing cut short on a full volume or a closed descriptor would otherwise end as `0` |

An archive directory that exists and holds no plan is complete, with a plan count of zero.

**The design's section is the one heading the listing carries itself**, held as a string inside the
extraction program. Before it reads the archive, the listing confirms that heading is one of the design
elements the required-element record lists, and exits `2` when it is not: a design template that renamed
its use-case section would otherwise make every later design list the section as absent, which the
review would read as a design with no cases.

### How the whole-repository review reads it

**`skills/project-review/SKILL.md` produces the listing and decides on it.** Step 2 opens, before it
creates the progress file, by making a temporary file and running the listing into it as its own call.
**Anything but `0` stops the review there**: the skill tells the user the listing could not be produced
in full, quotes the trailer, or the reason on a run-level stop, and ends the invocation having written
nothing — no progress file exists yet, so the next invocation finds no active review, starts at Step 1
and runs the listing again against the repaired archive. A review without the listing would raise what a
completed spec records as intentional and lose use cases it must cover, and a partial listing cannot say
which code its missing plan governed, so no partial review is safe to run (AC12). On `0` the skill
creates the progress file and the spawn prompt names the listing's file, which serves that one spawn and
no later one. A Phase 1 spawn on a resumed review, the progress file already in place, first runs the
listing again into a new temporary file under the same stop; a stop there leaves the progress file where
it is, so the next invocation resumes into the Phase 1 spawn rather than starting at Step 1. After the
spawn, a reviewer that recorded its prompt naming no listing has reviewed nothing: the skill reports that
stop to the user instead of a finding count and leaves `**current_step:**` at Phase 1, so the next
invocation resumes into a fresh listing and spawn. The skill's description stops saying it reads done
plans, and its allowed tools gain the listing script and `mktemp`.

**`agents/review-findings.md` reads the listing whole as its view of the archive, and opens an archived
document in full only to settle a specific finding (AC10).**

- **Instructions, step 2** — read the listing the prompt names. It is how completed plans reach this
  review: per plan, its date, key, document names, the spec's record of deliberate absence and the
  design's use cases. Open a completed spec or design in full only to settle a specific finding, never to
  survey the archive. A prompt naming no listing raises no finding: the reviewer records that in the
  Decisions log and stops.
- **Checklist 0** — its heading conditions on the listing carrying use cases, and the coverage bullet
  reads each case from the listing, naming the section in words rather than as a backticked heading
  (§ Staying outside the refusal's page set). The predicate is unchanged: a case nothing covers is
  `major`, and a design the listing carries no use-case section for contributes no case, as today
  (AC11). The bullet says so in those words and carries no presence word, which keeps true the measured
  claim in the comment above `PRESENCE_SHAPE` that the post-merge pass says nothing about any element
  being absent (§ Staying outside the refusal's page set).
- **What you do NOT check** — the suppression bullet still names a completed spec in the archive
  directory and its record of deliberate absence as the only thing conferring it, and says the listing is
  where that record is read; a completed design, its use cases included, silences nothing (AC11).
- **Rules** — the bullet that skips anything "documented there" across the completed plans becomes: check
  the listing for a completed spec whose record of deliberate absence documents the finding as
  intentional, and skip it only then. The bullet as it stands lets any archived document silence a
  finding.

**The amendment trigger's subject arm states its read wherever it can reach the archive.** Arm (A) asks
whether closing a finding leaves a plan sentence untrue. In `/project-review` and `/bugfix`, neither of
which has a plan of its own, the plan it asks about is a completed one looked up across the archive, and
`agents/self-review.md` runs the same arm for both, its arm scoped to every plan under the plans
directory, the archive included. What the arm needs is any sentence of a completed plan, which the
listing's four sections do not carry. Each of the three sites gains one sentence, beside its arm (A),
stating that need and its bound: search the completed plans for what the fix changes, and open in full
only a document that search names. That keeps a fix-loop question from turning into a sweep. The
reviewer's sentence is worded for a completed plan rather than for a caller, so it binds whichever
workflow spawned it. `docs/workflow.md` § Spec-Amendment group, the group page carrying the arm's
rationale, gains the same sentence as the group's sibling. The task skill's own arm and its fix scout act
on the sentence a finding cites, opened by the file the citation names, and look nothing up across the
archive. The scout's description in `agents/fix-scout.md` reads "Reads a review round's open findings
and the anchors they cite", and `agents/fix-scout.md` § What you must not do restates it as "You read the
anchors they cite"; under `agents/fix-scout.md` § The Arm A cell the scout records a quoted sentence with
its anchor, which the orchestrator running the task skill's Step 11 arm confirms "in one search instead
of taking your word". Where an in-task reviewer reaches a completed plan, the reviewer's sentence already binds it.

**The suppression gate learns the listing's name.** `do_suppression` in `scripts/check-redline.sh`
[do-suppression] enumerates the lines of a review instruction that name the completed plans and asserts
that every one conferring suppression narrows to the spec. Its enumeration reaches two spellings today,
the archive directory and the design file suffix. The listing is a third way to name the same material,
and the rewritten brief calls it "the listing" as well as "the archive listing", so a line saying
"skip anything the listing documents as intentional" would hand a design's use cases suppression
authority through a spelling a phrase match cannot see. The enumeration therefore also matches the
listing's script name and the word "listing" itself, case-insensitively and as a whole word, which reaches
every spelling of the listing the brief uses without depending on how an author qualifies it; the unit
stays the line. A line that the enumeration reaches only through the listing and that confers suppression
must name the spec as a word — a word match, since a substring match would accept "specific". The two
existing rules stand unchanged. The verb's header comment, which states what the enumeration reaches in
the live review instructions and how each line is dispositioned, is re-derived against the rewritten
instructions, and the pattern the verb prints beside its verdict names the wider enumeration.

### Every other reader of the archive

**Membership.** A reader of the archive is a shipped instruction or script that reads the content of
another task's archived spec or design: by sweeping the archive, by looking a plan up across it, or by
reading a file set the archive belongs to. Three kinds of read are not membership, each for a stated
reason:

- **A plan the reader is handed, read by the workflow that owns or amends it, wherever it sits** — the
  closing fold and the two subagents it spawns, the fold gate's `folded` verb [do-folded], `paired` verb
  [do-paired] and `revision` verb, all in `scripts/check-redline.sh`, the fix-plan gate's marker lookup,
  the convergence and declared-link checks over the pair they are handed (the convergence check's other
  reads are members, below), a post-push round's reviewers, and the amendment recipe re-reading the pair
  the trigger that fired already cited. The listing carries nothing such a party needs: it needs the
  whole of the one plan it is executing or amending. The spec's out-of-scope line on the in-task
  reviewers, which do not read the archive, is this exclusion read for its intent: an in-task reviewer
  reviews its own task's plan. The same reviewer's arm (A), looking a completed plan up for `/bugfix` or
  `/project-review`, is a member below.
- **Names, index entries and bytes only** — the fold gate's `pending` verb in `scripts/check-redline.sh`
  [do-pending] lists log names; the propagation-arms check reads the index; the tree digest hashes
  changed files as bytes and interprets nothing in them.
- **Moving or locating a file** — the task's close moves the plan into the archive; the location tables
  on the method page and the docs index describe where plans live.

The plan-invariants check is not a reader either: `EXCLUDED_SURFACES` in `scripts/check-plan-invariants.py`
[excluded-surfaces] claims every path under the plans directory for its plan-documents exclusion, and an
excluded path is never opened.

**The members, and what each does:**

| Reader | What it reads | Disposition |
|---|---|---|
| `agents/review-findings.md` | Every archived spec and design, in full | Takes the listing (§ How the whole-repository review reads it) |
| `skills/project-review/SKILL.md` | The archive, through its reviewer and through arm (A) | Produces the listing; arm (A) states its need and its search (§ How the whole-repository review reads it) |
| `skills/bugfix/SKILL.md` | Through arm (A) in Step 5, any completed plan whose sentence the fix may leave untrue, the workflow having no plan of its own | Arm (A) states, beside the arm, its need — any sentence of a completed plan, which the listing's four sections do not carry — and its bound: search, then open in full only a document the search names |
| `agents/self-review.md` | Through arm (A), in its section on findings that require a design or spec amendment, scoped to every plan under the plans directory; a completed plan when `/bugfix` or `/project-review` runs it | The same need and bound, beside arm (A), worded for a completed plan whichever workflow spawned the reviewer |
| `skills/pr-merged/scripts/cleanup-progress.sh` | The tracking header of every spec, completed and active, to map a ticket key to a plan | States, beside the ticket-key lookup [spec-by-key], that it needs one header line from active specs as well, and the listing reads the archive alone |
| `scripts/check-references.sh` | Every markdown file in the tree, whole | States, beside `md_files()` [md-files], that a link or an anchor can sit anywhere in a file, and the listing carries four sections |
| `scripts/check-method-purity.sh` | Every text file in the tree, whole, for a foreign identifier | States, beside the `paths` list [purity-paths], that a foreign identifier is refused wherever it sits |
| `scripts/check-plan-convergence-reporting.py` | Every tracked file in its reference class — one tree-wide read — and one read of the files the plan names, in its pairing class | States, beside `reference()` [reference-sweep] and `pairing()` [pairing-sweep] each, that a position or a mark can sit anywhere in a file |

Each statement goes beside the read, in the file that does it, as one comment or one sentence, and carries
the id the table gives it on the entity it sits beside. The three arm (A) sentences are prose beside a
prose rule and carry no id. `docs/workflow.md` § Spec-Amendment group is not a reader — it states the
arm's rationale and runs no review — and takes the same sentence as the group's sibling.

### Sentences this change makes untrue

- **The sixth base principle's reason**, on `docs/plan-invariants.md` and in its pinned copy `PINNED` in
  `scripts/check-plan-invariants.py` [pinned-principles], changed together as the authorisation route
  requires. The rule is unchanged. The reason becomes: *Because every later reader of the document pays
  for every such passage — the record of deliberate absence and the use cases on every whole-repository
  review, the rest whenever the document is opened — and none of it describes the system.*
- **Its restatement in `agents/design.md` § Rules**, in the bullet on pre-approval corrections, and **in
  `agents/design-review.md` § Rules**, in the bullet on revision accounts: each states the same reason in
  its own words, with no claim that a later review reads the document in full.
- **`agents/design.md` § The redline fold**, which keeps the approach, decomposition, risks, rejected
  alternatives and use cases "because the post-merge review reads them from the design that survives".
  The reason becomes that the surviving design is what a later reader opens to settle a finding, and that
  its use cases reach every whole-repository review through the listing.
- **`agents/review-findings.md` step 2 and the project-review description**, rewritten in § How the
  whole-repository review reads it.

A case-insensitive sweep on 2026-10-28 for the phrases "read in full", "reads all", "read every", "every
later" and "post-merge", over every tracked file under `agents/`, `skills/`, `docs/`, `rules/`, `hooks/`,
`scripts/` and `templates/` and over `README.md` and `AGENTS.md`, found the sentences above and no other
that this change makes untrue. Three other hits speak of what a later review reads, and stay true:
`agents/design.md` § The redline fold and step 5 of `skills/redline-fold/SKILL.md` give "the post-merge
reading list" as naming the spec and the design, which holds because the listing reads those two
documents and never the correction log; and the comment above `PRESENCE_SHAPE` in
`scripts/check-plan-invariants-refusal.py` says the post-merge pass "says nothing about any element being
absent", which the coverage bullet keeps true by carrying no presence word (§ How the whole-repository
review reads it). Every remaining hit speaks of something other than how archived plans are read, such
as a later field, run or divergence, the merge-time cleanup or the instruction-surface audit, or quotes a
review instruction's line as data rather than stating anything about the system.

### The record of deliberate absence stays one list

The listing keeps no copy of the spec's three headings: it parses the one assignment already read by the
fold gate's `folded` verb, by the plan-invariants check in `scripts/check-plan-invariants.py`, and by
`retained_sections()` in the convergence check's holding classes. That assignment's comment gains one
sentence naming those readers and the listing by name, so whichever change moves it — this one never
does, the fold's retirement may — moves every reader with it. A move that missed the listing is a
cannot-run, never a second list: the listing exits `2` when the assignment is not where it reads it.
Nothing here depends on the fold still running.

### Staying outside the refusal's page set

The listing reads sections and mandates none, so it belongs outside the edit-time refusal's page set, as
the convergence and declared-link checks do. The coverage sweep decides membership by shape —
`defines_element` in `scripts/check-plan-invariants-refusal.py` [defines-element] reads a page as
element-defining when it carries a section heading inside a markdown-tagged fence, a shell assignment of
the form `NAME='…'` whose entries include a section heading, or a backticked section heading on a line that
also carries a presence word such as "absent" or "missing", the words `PRESENCE_SHAPE` in the same file
[presence-shape] lists. A page carrying any of the three and absent from the table is reported as an
unguarded route. So the listing holds the design heading as a string inside its extraction program, takes
the spec's three at run time, and keeps its comments free of a backticked section heading beside a
presence word. `agents/review-findings.md`, a documented near miss, holds a stricter line, because the
comment above `PRESENCE_SHAPE` gives as its measured reason for the near miss that the post-merge pass
says nothing about any element being absent: each of its bullets is one line, the coverage bullet names
the section in words, and no line this task adds to the brief carries a presence word.

### Size budget

`ai-docs/context.md` is not edited. It measured 34,714 characters by a Python character count on
2026-10-28, against the 35,000 early warning the project's size rule sets, and nothing this task adds
belongs there: the listing is documented in its own header and in the review instructions that run it,
it adds no payload sibling, and no near-miss row is added whose count the context page carries. The
`AGENTS.md` sentence counting the payload siblings is unchanged for the same reason.

The instruction files this task edits that load whole at agent start, each measured by the same count on
2026-10-28, the last column being the early warning less that count:

| File | Characters | Under the warning |
|---|---|---|
| `agents/self-review.md` | 32,862 | 2,138 |
| `AGENTS.md` | 23,612 | 11,388 |
| `agents/design.md` | 23,393 | 11,607 |
| `agents/design-review.md` | 19,103 | 15,897 |
| `agents/review-findings.md` | 19,083 | 15,917 |
| `skills/bugfix/SKILL.md` | 13,530 | 21,470 |
| `skills/project-review/SKILL.md` | 12,781 | 22,219 |

Every file but the first takes at most a paragraph. `agents/self-review.md` is the tight one, its
headroom 35,000 - 32,862 = 2,138 characters, and it takes one sentence. That sentence is estimated at
183 + 120 = 303 characters: its need clause and its bound clause, 80 and 103 characters by the same count
of the wording § How the whole-repository review reads it gives them, plus a lead-in tying them to a
completed plan of about twenty words at six characters each. That leaves 2,138 - 303 = 1,835 characters
under the warning. `docs/workflow.md`, which takes the same
sentence, is reached by link and is outside the class the size rule caps.

### Rejected alternatives

- **A committed listing.** Stale at the next archived plan; the spec decides it is computed on every read.
- **Reusing the fold gate's section reader**, `section_of` in `scripts/check-redline.sh` [section-of]. It
  starts and ends a section only at second-level headings and does not track fenced blocks, so a quoted
  heading inside an example would start a section (AC3), and a first-level heading would not end one.
- **A payload sibling in another language.** Cleaner to write, but it adds an entry to the context page's
  sibling list, its interpreter and linter rows and the profile's count, on a page with no room for them.
- **The reviewer producing the listing itself.** The decision to stop would then sit in two parties — the
  subagent recording an incomplete listing and the skill noticing it afterwards. The skill reads the exit
  status directly and decides once.
- **Moving the record of deliberate absence to a file of its own now.** It would change the protected-page
  table, the guard's page list and two parsers in a task that only needs to read it; where the list lives
  after the fold retires is that change's decision.
- **Placing the script under the project-review skill.** It reads two method files at the plugin root and
  is run by the skill through the plugin root; the skill-scripts directory would only add a relative climb
  to reach them.
- **Narrowing the listing to plans relevant to the code under review** — out of scope: nothing in a plan
  says which code it governs.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | **The archive listing.** Create the script: the root argument and its two fallbacks; the method inputs read from its own directory, with the record cross-check on the design heading; plans grouped by stem; the date from the file name and the key from the head of either document; the fenced-block and heading rules; the four sections, framed by line count, with `absent` and `missing`; the two outcomes and the trailer; a header comment stating what it reads, why the design heading is a string inside the program, and why it carries no section heading beside a presence word. Make the profile entries `AGENTS.md` § Build & Test requires of a new script. Enter the script in the Review group's anchor row on the propagation page, as the listing the reviewer reads | `scripts/plan-archive.sh` *(new)*, `AGENTS.md`, `docs/propagation.md` | AC1, AC2, AC3, AC4, AC5, AC6, AC7, AC8, AC9 | — |
| 2 | **The review reads the listing.** In the project-review skill: the description, the allowed tools, Step 2 opening with the listing before the progress file exists, the stop on anything but `0` that writes nothing and leaves the next invocation to start at Step 1, the file named in the spawn prompt, and arm (A)'s sentence stating its need and its search. In the reviewer's brief: step 2, Checklist 0's heading and coverage bullet, the suppression bullet and the Rules bullet, each line kept clear of the shapes § Staying outside the refusal's page set names and of any presence word. In the fold gate: the enumeration in `do_suppression` widened to the listing's script name and the word "listing", its narrowing rule, the pattern it prints, its header comment re-derived against the rewritten brief, the readers sentence on the `RETAINED` comment, and the ids `[do-suppression]`, `[retained-list]` and `[section-of]` marked on their entities. Of the group sweeps this edit owes, Spec-Amendment finds arm (A) in the bug-fix workflow, the shared reviewer and the workflow page, which row 5 carries; Review, Redline and Plan-Invariants find no sibling stating what these three files change | `skills/project-review/SKILL.md`, `agents/review-findings.md`, `scripts/check-redline.sh` | AC10, AC11, AC12, AC13, AC14 | 1 |
| 3 | **The sixth principle's reason and its restatements.** Rewrite the reason on the principles page and in `PINNED` in the same change, marking `PINNED` with `[pinned-principles]` and `EXCLUDED_SURFACES` with `[excluded-surfaces]`; restate it in the design author's bullet on pre-approval corrections and in the design reviewer's bullet on revision accounts; give the design author's fold section its true reason for keeping the frozen sections. The two agent files are protected pages; every edit to them here is prose inside an existing section, which the armed refusal passes | `docs/plan-invariants.md`, `scripts/check-plan-invariants.py`, `agents/design.md`, `agents/design-review.md` | AC14 | 1 |
| 4 | **The other readers state their need.** Beside each of the five reads, in the four scripts the members table names, one comment saying what it needs that the listing does not give it, marked with the id the table gives that entity; bump the plugin's patch version | `skills/pr-merged/scripts/cleanup-progress.sh`, `scripts/check-references.sh`, `scripts/check-method-purity.sh`, `scripts/check-plan-convergence-reporting.py`, `.claude-plugin/plugin.json` | AC13 | 1 |
| 5 | **The amendment trigger's subject arm states its read in every workflow that reaches the archive.** Beside arm (A) in the bug-fix workflow's Step 5 and in `agents/self-review.md` § Findings that require Design/Spec Amendment, not a code fix, one sentence carrying the need and bound clauses project-review's arm (A) takes in row 2 behind a lead-in naming the archive listing — "For a completed plan the archive listing is not enough:" — because neither site produces the listing, so a bare "the listing" there would point at nothing; the reviewer's sentence worded for a completed plan rather than for a caller and held to the estimate § Size budget gives; the same sentence, lead-in included, in `docs/workflow.md` § Spec-Amendment group, as the group's sibling, which produces no listing either | `skills/bugfix/SKILL.md`, `agents/self-review.md`, `docs/workflow.md` | AC13 | 2 |

## Risks

- **The listing or the reviewer's brief reads as element-defining.** The refusal-agreement leg reports a
  page carrying one of the three shapes `defines_element` reads, outside the protected-page table, as an
  unguarded route — which would push a page that mandates nothing into the refusal set or leave the
  check reporting it. Mitigation: § Staying outside the refusal's page set; both files carry the design
  heading only where none of the shapes can see it.
- **A new route to suppression authority.** The listing carries design sections beside the spec's, so a
  review line naming the listing without narrowing to the spec would let a design silence a finding.
  Mitigation: the enumeration in `do_suppression` reaches the word "listing" however the line qualifies
  it, so a line spelling it "the listing" is enumerated as one spelling it "the archive listing" is, and
  every such line conferring suppression must name the spec.
- **The design heading drifting from the design template.** The listing carries it as a string, so a
  renamed template section would read as absent on every later design. Mitigation: the cross-check
  against the required-element record, which the plan-invariants check already holds to the template in
  both directions; a renamed section moves the record and the listing exits `2`.
- **The fold's retirement moving the record of deliberate absence.** Mitigation: the listing parses the
  one assignment and exits `2` when it is gone; the assignment's comment names every reader, the listing
  among them.
- **The listing's size.** The four sections measured 132,948 characters across the archive (the spec's
  count, 2026-10-28), and the listing adds a few framing lines per plan. The skill therefore writes the
  listing to a file rather than handing it over as one tool output, and the reviewer reads that file
  whole, in parts. Its growth by one plan's sections per task is deferred to GH-165 by the spec.
- **The shared reviewer departs from the literal out-of-scope line on in-task reviewers.** The spec puts
  the in-task reviewers out of scope as readers that do not read the archive; `agents/self-review.md`
  gains a sentence here because its arm (A), run by `/bugfix` and `/project-review`, does look completed
  plans up, and AC13 requires every such reader to state its need. Under the tenth base principle this is
  a departure another sentence of the spec requires, stated here once, and no spec amendment. The edit is
  one sentence, inside the headroom § Size budget derives.
- **A stop on an incomplete listing halts the whole review.** Deliberate. The spec's key decision leaves
  stopping or reading the affected documents in full to this design, and reading them in full would
  conflict with AC10, which allows a full read only to settle a specific finding; stopping honours both.
  Every archived document closes every fenced block it opens, measured by a fence scan over the archive on
  2026-10-28, so no archived document is unlisted today.
- **Per-element work.** The listing extracts each document once, so an archive of N plans costs at most 2N
  short extraction runs (two documents per plan) and reads nothing outside the project and the plugin's
  own method files: linear in the archive, with no per-plan call to anything remote.
- **Arm (A)'s search widening into a sweep.** Bounded in its own sentence at each of the three sites that
  run the arm against the archive: a search for what the fix changes, and a full read only of a document
  that search names.
- **Interruption.** The listing writes nothing but standard output. A run killed mid-way leaves a partial
  temporary file and no `0`, and the skill acts on the exit status, never on the file's presence. A stop
  on the opening listing leaves no progress file, so re-entry after the archive is repaired is an
  ordinary first invocation. A stop on the listing a resumed Phase 1 spawn runs leaves the progress file
  in place, and re-entry resumes into a fresh listing and spawn.
- **A published interface.** The suppression verb's enumeration widens, so a file that was clean can
  report a line conferring suppression through the listing without naming the spec; that is the intended
  catch. The pattern it prints beside its verdict changes with it. The verb's set, exit convention and
  other refusal reasons are unchanged. The reviewer's spawn prompt gains one line.

## Use cases

- `scripts/plan-archive.sh` — run by `/project-review` Step 2 into a temporary file, its exit status
  deciding whether the review runs at all; read whole by the reviewer as its view of completed plans, an
  archived document being opened in full only to settle a specific finding, the spec sections deciding what a finding may not be raised for and the use-case sections naming the
  cases coverage is owed for; run from an installed copy in a consuming project, against that project's
  archive; run by hand by anyone who wants what the completed plans deliberately left out, and which use
  cases they promised, without opening each plan.
- `/project-review` Step 2's listing step — stops a review that cannot see every completed plan's record,
  before anything is written, and tells the user what is missing; otherwise creates the progress file and
  names the listing's file to the reviewer.
- Arm (A)'s need-and-search sentence — read in `/project-review`'s and `/bugfix`'s fix loops, and by the
  shared reviewer whichever workflow spawned it, when a fix may leave a completed plan's sentence untrue,
  to find that sentence without reading the archive; read on the workflow page by whoever next changes the
  arm, as the group's statement of what the arm reads.
- `do_suppression`'s widened enumeration — run against a review instruction file to confirm that every
  line naming the listing, by its script name or by the word, and conferring suppression names the spec;
  reports a line that would let a design's listed sections silence a finding.
- The sixth principle's reason — read by an author or reviewer weighing a proposed exception to the rule
  against recording superseded material; compared by the plan-invariants check with its pinned copy.
- The readers' comments — read by whoever next changes one of those readers, to see why it reads more
  than the listing.
