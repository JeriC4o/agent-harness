# Design: Removing the statement-inventory comparison

**Ticket:** GH-130
**Date:** 2026-10-21
**Spec:** ai-docs/plans/2026-10-21-remove-statement-inventory.spec.md

## Approach

**One leg leaves the verification, with its record, its by-hand advance, and the parts of the edit-time
refusal that exist only for those two. Nothing is built in its place.** The corpus, the report, the roster
and the other three legs stay. The work is a deletion across the verification, the refusal and their own
two verifications, the record removed from the tree, and honest re-authoring of the prose on every surface
that describes what is going. Every file is enumerated in § Decomposition.

### The corpus survives the removal, which is what makes the shape cheap

The segmentation of files into statements exists for the comparison alone. The CORPUS does not, and that
is the whole of why this removal is a deletion rather than a rebuild: the corpus is still CONSTRUCTED from
the tracked file set, and the surviving refusal-agreement leg still reads it. The five examined surfaces,
their page counts, the unreadable-file branch, the three by-design exclusions and the count of tracked
files neither a surface nor an exclusion claims are all computed where the corpus is built, in
`scripts/check-plan-invariants.py` — `SURFACE_FILES`, `EXCLUDED_FILES`, `UNACCOUNTED` and `PAGES` — and
never by the per-file shape test, so their meaning does not depend on how many corpus members reach
`defines_element` [defines-element] in `scripts/check-plan-invariants-refusal.py`. **Confirmed by reading
that construction and that loop.**

**Far fewer members reach the shape test than the corpus holds, and the paragraph above is written not to
depend on it.** That loop skips the principles document, the guard and every `test-*.sh` before the call,
which over the live tracked tree leaves 33 of 137 corpus pages never reaching it — a measurement over that
tree, counted per surface as profile 0 of 3, method 1 of 53, scaffolding 0 of 11, enforcement 8 of 21 and
verification 24 of 49. It is recorded here because it is what subtask 1 needs when it decides how much
corpus plumbing to keep: all of it, because the construction is where the roster figures come from and the
sweep is not.

`statements` on the verdict line is the only figure fed by nothing else: it is accumulated into
`STATEMENTS` beside `SEGMENTS` and printed by `counts()`, both in `scripts/check-plan-invariants.py`. It
leaves the format string, and `counts()` is reached on every outcome path including the cannot-run one, so
one edit covers all three.

### What stays, and why the separation is by subject rather than by position

In the refusal, `PROTECTED` [protected] in `hooks/lib/plan-invariants-guard.sh` keeps all seven pages, and
so does every part of the shell write arm in that same file: the separator neutralisation, the `padded`
assignment [padded] that marks the two redirect forms before any token is read, the leading-`cd`
resolution, `path_shaped` [path-shaped], the `WRITER_WORDS` [writer-words] and `INPLACE_CMDS`
[inplace-cmds] vocabularies that `has_write_construct` [has-write-construct] reads, the `dd`, `mv` and
`cp` operand rules, the loop-word list, the interpreter construct, and `rel_of`, `record_hit`, `emit`,
`reason_for` and the file-path arm beside them. The arms that go are the ones whose subject is the record
or the shape of the command that advanced it; an arm removed for sitting next to one of those would be a
regression in the one protection this task leaves standing. `why_for` exists only to choose between two
reasons, so with one guarded class left its single surviving sentence folds into `reason_for` and the
function goes; both call sites then pass two arguments.

`is_protected` keeps its name and its loop, minus one term. The reason for the breadth — every surplus
member is a recurring interruption — is unchanged, and so is the seven in `reason_for`'s message.

The element-set leg is untouched in both of its directions, and so are the three routes that derive what it
compares: the two writer templates, the `SEVERITY` pattern [severity] and `ELEMENT_TOKEN` [element-token]
in `scripts/check-plan-invariants.py` that together make the review contract's quieter route readable, and
the enforcer's two pinned lists. The per-page locus sweep keeps its own shape test, `PRESENCE_SHAPE`
[presence-shape] in `scripts/check-plan-invariants-refusal.py`, which still requires a presence, absence or
retention word beside an element token so that scoring the coverage of an element does not read as
requiring one.

### The legs are renumbered

The element-set leg takes the second position and the refusal-agreement leg the third, in the finding-id
prefixes, in every header enumeration, **and in the profile's own record of the legs** — `ai-docs/context.md`
§ Plan invariants carries a leg count and two ordinals in its Code bullet, naming four legs in a
parenthesis, assigning three of them to the first payload sibling and calling the other `leg 4`, so the
count and both ordinals move with the rename rather than being a header. **Rejected alternative: leave
each leg the number it carries today.** An enumeration of three members that skips its second place either
reads as a defect or needs a note whose subject is the removed comparison, and the spec's eighth scope item
requires every surface to stop describing it.

Two ordering constraints fall out and are the only sequencing this change has:

- **Every finding id carrying the removed leg's prefix must be gone before the element-set leg's prefix is
  renamed onto it**, or the rename merges two legs' findings under one prefix.
- **The payloads change before the guard does.** The refusal-agreement leg reads `GUARDED_RECORD` out of
  the guard and treats an unreadable assignment as a cannot-run, so a guard stripped first would make the
  gate report that it could not run. In the stated order every intermediate state is clean: once the leg's
  record arms are gone, a guard still naming a deleted path fires on nothing and reports nothing.

### Where the bound that the removal creates is written

Three surfaces state this mechanism's bounds, and all three carry the new one **whole rather than in one
of its halves**: the opening of `docs/plan-invariants.md`, the `THE BOUND` paragraph in
`scripts/check-plan-invariants.sh`, and the `GH-116` entry in `ai-docs/context.md` § Open questions. The
bound, in the spec's own words, is one statement with two parts — two classes of change are from now on
caught by the pull-request diff and by nothing mechanical: a mandate arriving on an examined page that the
element derivation does not read, in words the coverage sweep does not recognise; and a change to prose
that is not one of the principles' own numbered sentences, those sentences being the only prose any
surviving comparison pins, so the explanatory paragraphs around them, and prose anywhere else on the
examined surfaces, are pinned by nothing.

The second part is the larger one and is why a surface carrying only the first understates what was given
up. The first part names a mandate that the element derivation and the coverage sweep between them miss.
The second names every sentence on the five examined surfaces that is not one of the nine numbered
principles the spec puts out of scope — the explanatory paragraphs on the authority page itself included.

**The wording is taken from the spec, and only two of its three copies there are pinned to each other.**
The spec states the bound whole at its scope item, at its criterion for this bound and in its
key-decisions row, and the convergence check's isolation class holds the repetition at two of those: its
unit is a whole statement or a whole table cell, and the criterion's cell prepends a sentence of its own
before the bound, so that copy is compared with neither of the others. A one-sided edit to it is therefore
caught by a reader checking that criterion and by nothing else — which is worth knowing by anyone copying
this wording onto a surface, because the copy they take it from may be the one that moved.

**One of the three bounds on the authority page inverts rather than dying.** It reads today that the
refusal recognises an edit by its shape, so a writer it does not recognise reaches the page and is then
caught by the comparison instead. The second half of that is what stops being true, and the sentence
becomes the bound above rather than being deleted. The other two — that the comparison reports text and
never meaning, and that the record can be levelled in the same pass as the change it would have
reported — go with the comparison.

**The same claim sits a fourth time, in the guard's own header**, where the write-construct rationale
accepts the cost of an unlisted writer on the ground that the detection legs catch what escapes the guard.
That ground is the half that stops being true, so the clause LOSES it — the same loss the authority page's
third bound takes — and the clause does not become a carrier of the new bound. Only the authority-page
sentence inverts, and it alone survives as the new bound, which is why the carriers remain the three
surfaces named above. Re-authored in the subtask that edits that file, not here.

### Two surfaces need re-authoring rather than trimming

`ai-docs/context.md` § Plan invariants argues the whole mechanism from the comparison under its own
why-it-exists bullet: a hunt for a principle's opposite is blind to an ADDITION, so the verification
compares a recorded inventory instead of reading sentences. The measured damage that justifies the
mechanism is unchanged, and the answer to the addition is still there — it is the required-element set
derived from three loci and compared against the record in both directions, plus the per-page locus sweep
that reports a page acquiring an element-defining rule. The bullet is rewritten to say that, not shortened.

`docs/plan-invariants.md` § Two surfaces claims that a mandate landing on an unrefused page of the five, or
in text that no page carries, is still caught and named. The second clause was the comparison's reach and
goes; the first narrows to a mandate the derivation or the sweep recognises. That page's near-miss section
opens by saying each near miss stays inside the detection, which stays true in that narrower sense and is
qualified rather than cut — and the qualification carries two narrowings rather than one, because stating
only the first would leave the preamble claiming a universality it does not have. The opening claim keeps
the width § Two surfaces states for it: every page named there is on one of the five examined surfaces.
Beside it goes the narrower reading — what reads a page FOR a rule that makes an element required covers
five of the seven rows, because the per-page locus sweep skips the principles document, the guard and every
`test-*.sh` before it inspects anything. So the row naming `scripts/test-check-redline.sh` and its siblings
is a corpus member and nothing more, and the enforcement row holds for `hooks/hooks.json`, which the sweep
does read, but not for the guard or the seven `hooks/lib/test-*.sh` beside it.

### The size pressure the removal relieves

The comparison leg measures **453 lines** in `scripts/check-plan-invariants.py` — a measurement, taken with
`wc -l` over the span from the leg's own banner to the start of the next leg's. With the rest of the
deletions above it, the payload lands far enough under this repository's thousand-line limit that the
Thousand-line exemption row in `ai-docs/context.md` § Language profile has no exemption left to record for
it. **Rejected alternative: merge the two payload siblings back into one.** The spec puts it out of scope;
the split stays and the ground stated for it becomes the spec's own — merging is a refactor with no motive
beyond size.

**Rejected alternative: rename that row.** Five files point at it by name — a measurement, taken with
`grep -rn 'Thousand-line exemption'` over the tree: two convergence payloads
(`scripts/check-plan-convergence-holding.py`, `scripts/check-plan-convergence-reporting.py`), the
convergence wrapper `scripts/check-plan-convergence.sh`, and the two invariants-side files
`scripts/check-plan-invariants.sh` and `scripts/check-plan-invariants-refusal.py`.
`scripts/check-plan-convergence.py` names the hard limit and not the row, so it is not one of the five. The
row still records how this repository answers that limit, so only the half about the invariants payload
leaves; the convergence half, which records a hard-ish-band justification, is the row's surviving content.

**The two invariants-side citations go with that half, and they are header prose rather than data.** Both
cite the row as the standing justification for the payload split — the entry point's header says the first
sibling took the per-file route, and the sibling's own header says the payload now holds it. With the
payload far enough under the limit there is no exemption left for either to cite, so that prose is
re-authored in subtask 1 beside the rest of its header work. What survives in the sibling's header is the
ground that never depended on the overage: the span is a pure sink, exporting no name the payload reads
back, which is why it was the cheapest of the three candidates to move.

The count of non-shell payload files on that page and on `AGENTS.md` § Language profile does not move:
neither payload sibling is deleted.

### Two other rejected alternatives, recorded so they are not re-proposed

**Switching the repository-mechanics exclusion to a prefix on the fixtures root.** The record was skipped
before any membership rule ran, which is the stated reason that root is reached by named files rather than
by a prefix; with the record gone that reason goes. The named list stays anyway: a prefix widens what the
exclusion claims, and the list's other ground — a new record under that root is owed its own name rather
than being silently absorbed — never depended on the record. Only the dead clause of the comment leaves.

**Deleting the row in `ai-docs/fixtures/positional-references.baseline` that accounts for a command slice
reading the record.** That slice leaves the tree with the refusal's own verification, so the row stops
accounting for anything. The spec puts that record out of scope, and the class that reads it reports
arrivals only — `reference` in `scripts/check-plan-convergence-reporting.py` compares each swept position
against the record and reports what the record does not hold, never what the record holds and the tree does
not. The stale row therefore reddens nothing. Named as residue rather than fixed.

Replacement mechanisms are declined by the spec and are not re-opened here.

## Decomposition

| # | Task | Files | Delivers | Depends on |
|---|------|-------|----------|------------|
| 1 | Remove the comparison leg whole — both segmenters, the unit splitter, the alignment and relocation passes, the hashing and blob readers, the record parser and writer, the accumulated statement total, the rule-name constants and the reporting helpers, with the two imports that served only them. Drop the acceptance mode, the record's path spelling and its three preflights, the record's index test, the blob clause of the interpreter-and-git preflight, and the statement figure from the verdict builder, which is reached on all three outcome paths. Two further spots naming the comparison sit outside the leg span and outside any header and go with it: the corpus-construction comment and the cannot-run message it guards, which tells a reader a file could not be read so its statements were never compared — user-visible output on a surviving path; and the comment above the verdict region, which calls the statement figure the one that surfaces this approach's own false green. Drop the guarded-record extraction and the two arms it feeds from the sweep sibling, and the record from the context mapping it is handed. Remove the record from the tree. Renumber the surviving legs per § Approach, and re-author every header, including the bound paragraph that gains the bound the removal creates whole, and the two exemption citations that name the thousand-line row as the standing justification for the payload split | `scripts/check-plan-invariants.sh`, `scripts/check-plan-invariants.py`, `scripts/check-plan-invariants-refusal.py`, `ai-docs/fixtures/plan-invariants.inventory` (removed) | AC1, AC2, AC3, AC4, AC5, AC6, AC11 | — |
| 2 | Separate the refusal's two concerns: remove the one-member record list and its banner, the entry-point token and its banner, the acceptance-shape arm, the record predicate, and the record sentence in the reason builder, folding its surviving sentence into the message assembler; drop the two surplus terms from the membership test and the basename fast path; re-author the header on two counts. Its silent-form count becomes the write arm's six — eight today, less the acceptance condition's two. And its write-construct rationale, which closes by saying that the cost of an unlisted writer escaping this guard is borne because the detection legs still catch it, loses that clause for the same reason the authority page's third bound loses its own second half | `hooks/lib/plan-invariants-guard.sh` | AC7, AC8 | 1 |
| 3 | Strip from the verification's own suite every passage whose subject is the comparison, the record or the acceptance invocation, and carry the renamed finding-id prefixes. Re-author the fixture, which no longer needs an acceptance run or a commit, the clean-case figure reads, the corpus-narrowing case — whose only remaining signal is the page figure, as that file's own prose says it was before the comparison existed — and the bare-tree case, which now reaches the empty-corpus branch directly and absorbs the case that existed only to get past the record preflight | `scripts/test-check-plan-invariants.sh` | AC12 | 1 |
| 4 | Strip from the refusal's own suite the record's two firing directions, the acceptance route with its fast-path control, the acceptance residuals and the guarded-record agreement, and the two fixture spellings they used | `hooks/lib/test-plan-invariants-guard.sh` | AC12 | 2 |
| 5 | Re-author the published authority: its opening bounds, where one inverts into the bound the removal creates and two go; the two-surfaces table's refusal row and its claim about text no page carries; the paragraph below that table which accounts for every tracked file on no examined surface by naming the three exclusions *together with the comparison record*, called out there by name because it is one file rather than a class — with the record gone the three exclusions account for that set on their own and the by-name clause has nothing to name; the near-miss preamble; and the authorisation-route row that asks a reader to level a record | `docs/plan-invariants.md` | AC9, AC11 | — |
| 6 | Re-author this repository's own records: the pre-commit contract's entry for this gate, which states four legs and names the record; the plan-invariants entity, whose why-it-exists bullet is rewritten rather than trimmed, whose identity and code bullets lose the record, and whose code bullet also carries the renumbering of § Approach, in its own enumeration rather than in a header — four legs named in a parenthesis today, three of them assigned to the first payload sibling and the fourth called `leg 4`, all three figures moving to three, two and `leg 3`; the fixtures row under the layout table; the thousand-line exemption row under the language profile, which keeps its heading and loses its first half; the open-question bounds, where the two whose whole subject was the comparison go with it, the third survives only as its closing clause — that nothing asserts the principles page reaches an installed copy at all, the install check inventorying skills, agents and hook events with no documentation arm — promoted to a bound in its own right rather than left as an instance of a framing that no longer applies, and the bound the removal creates is added whole, leaving the entry carrying two; its preamble drops the statement figure, which names a quantity nothing will measure, keeps the page figure, which the verdict line still measures, and claims a number of bounds matching the two it then carries; and the sync-group table's anchor and back-reference rows, whose count sentence becomes twelve — the thirteen vocabularies that row enumerates today, less the record | `AGENTS.md`, `ai-docs/context.md`, `docs/propagation.md` | AC10, AC11 | — |
| 7 | Stop the neighbouring check from pointing at a mechanism that will not exist: in its reporting payload, the polarity comparison and the *comparison clause* of the missing-levelling-act comment — the clause saying the act would print what it is about to take in the way the statement inventory's acceptance does; the gap statement that opens that comment and the sentence recording that the record moves by a hand edit today both stay, because the spec's Deferred row rests its no-separate-ticket answer on that comment continuing to record the gap. Then the segmenter contrast in its core payload — whose two-consumers sentence has one consumer left — and its wrapper's own ground for being a separate check, which cites the invariants payload having no room. Bump the plugin's patch version. Then run the whole pre-commit list in one call, as `AGENTS.md` § Build & Test resolves it, reading each member's verdict and the two rosters named in § Risks | `scripts/check-plan-convergence.py`, `scripts/check-plan-convergence-reporting.py`, `scripts/check-plan-convergence.sh`, `.claude-plugin/plugin.json` | AC10, AC12 | 1, 2, 3, 4, 5, 6 |

## Risks

- **The refusal-agreement leg blocks on a guard stripped out of order.** It treats an unreadable
  `GUARDED_RECORD` assignment as a cannot-run, so a guard edited before the payload makes the gate report
  that it could not run — which is not a pass and reads as a failure with no defect behind it. Mitigation:
  subtask 2 depends on subtask 1, and both sit in the same group.
- **The renumbering collides with itself.** Renaming the element-set leg's prefix onto the removed leg's
  while any id still carries the removed one merges two legs' findings under one prefix. Mitigation: the
  deletion and the rename are one subtask, in that order.
- **The tree cannot be read clean between subtask 1 and subtask 3.** The verification's own verification
  still names the removed material in that window, and the renamed prefixes have landed on only one side of
  the pair. Mitigation: both subtasks sit in Group A, and the pre-commit list is read once, in Group C.
- **The roster's examined-with-findings state could become unreachable.** Today that state is only ever
  OBSERVED through a finding the comparison produced, which is a fact about this tree rather than about the
  roster: the surviving legs report identities that currently agree, so on a clean tree they produce no
  finding to put a surface in it. Mitigation: the surviving leg that reddens exactly one surface
  is the principle-integrity leg — each of its three findings passes `surface_of(PRINCIPLES_DOC)` to
  `finding` in `scripts/check-plan-invariants.py`, which puts the method surface in the red set and leaves
  the other four clean, because a reworded principle touches neither the required-element table nor either
  page-set table and the per-page locus sweep skips the principles document. The element-set leg reddens
  the method surface on its two record-versus-derivation findings and the verification surface on its
  prohibition finding, which passes the enforcer's own surface rather than the principles page's, and the
  refusal-agreement leg reddens whichever surface the page it names belongs to.
- **One input the verification reddens on today stops being a finding at all.** A page dropped from the
  index is reported as a whole file departing, because the record still names it; after the removal that
  tree is clean and the page figure on the verdict line is the only place the narrowing shows. Nothing else
  the three surviving legs answer changes its verdict, because each of them reports an identity rather than
  a text difference. Mitigation: subtask 3 names that one input.
- **Two gates derive from surfaces this change edits, and a clean exit status does not show it.**
  `scripts/check-propagation-arms.sh` derives its expected arm set from the sync-group table that subtask 6
  edits; the record is not among its derived members, because the extraction keeps only `.md`, `.sh` and
  `.json` tokens and the record's extension is neither — so no derived arm should change, which is exactly
  why the roster is read rather than the status. The runner's own gate-inventory member parses the span of
  `AGENTS.md` that subtask 6 also edits, and that entry keeps naming this gate in the spelling the member
  extracts. Mitigation: subtask 7 reads both rosters by name.
- **A method page acquiring a project fact.** `docs/plan-invariants.md` ships to every installing project,
  and the bound it gains names a pull-request diff, which is not a project fact — no path, no command, no
  ticket prefix. Mitigation: the profile-side half of the same bound carries the ticket, and the two halves
  are written in different subtasks against different surfaces.
- **An unbumped patch version never reaches an installed copy.** The install cache is keyed by version and
  this change edits plugin-loaded content. Mitigation: subtask 7 bumps it, and a delivery gate refuses a
  branch that changed shipped content without one.
- **Header counts going stale.** Several of these headers state counts of their own content — the guard's
  silent forms, the sync-group row's vocabularies, the refusal sibling's context names and the names its
  span defines. Mitigation: each is re-derived from the amended text in the subtask that amends it, never
  carried over.

## Use cases

**This task builds no new object**, so the list is the five files the mechanism is composed of — its entry
point, its two payload siblings, the edit-time refusal, and the page the verification reads — with the uses
each one still has. Every other file this task changes is a surface that describes the mechanism or a suite
that verifies it, not a part of it, and has no use case of its own to state; those files are enumerated in
§ Decomposition.

- `scripts/check-plan-invariants.sh` — run with no arguments as the `plan-invariants` member of this
  repository's pre-commit list, which reads its verdict line and its roster; run with `--root` against a
  copy of a tree by a reader comparing two trees' answers; preflights `git` and `python3` and refuses with
  a reason when either is absent.
- `scripts/check-plan-invariants.py` — loaded by that entry point as its logic half: builds the corpus from
  the tracked file set across five surfaces, partitions the surfaceless remainder into three named
  exclusions and an unaccounted list, runs the principle-integrity and element-set legs, loads its sibling,
  and prints the verdict line, the findings and the roster on each of the three outcome paths.
- `scripts/check-plan-invariants-refusal.py` — loaded by that payload and called once with a context
  mapping: compares the refusal's live covered set against the protected-page table in both directions,
  reads the near-miss table as the control the set comparison cannot provide, confirms both registrations,
  and sweeps every corpus file for an element-defining rule in both directions.
- `hooks/lib/plan-invariants-guard.sh` — invoked by the hook manifest on the file-editing matcher and on
  the shell matcher: puts an edit to one of the seven protected pages to the author whatever the edit
  touches, through a spelled path, a resolved path, a leading directory change, a write construct's
  operands, a loop word list and an interpreter's write call alike; stays silent on a read of the same
  page, on an unmanaged project, and on a payload it cannot parse; supplies the author the reason and the
  page that makes the call authorisable.
- `docs/plan-invariants.md` — read by the verification for the pinned principles, the required-element
  record, the protected-page table and the near-miss table; read by a human before proposing a change to
  either document's composition, and by the two automated improvement passes as the page whose subject they
  must decline and hand to the author; named by the refusal's own message as where a member's grounds are.
