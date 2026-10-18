# Design contract rework: what a plan document must carry, and what checks it

**Source:** ticket GH-128
**Date:** 2026-10-16
**Tracked in:** GH-128

## Scope

All five numbered items of the tracking issue's plan land in this task, as one spec and one task, plus one
further rule the author authorised explicitly after reading what it widens (item 6 below). The issue's own
sequencing section governs the ORDER the work is done in; it is not a licence to split the extent.

1. **The knowability principle reaches content, not only required elements.** The principle forbidding an
   element whose content is only determined later is extended to govern any number a spec or a design
   states. The obligation is provenance, not prohibition: a number names, in the same sentence, which kind
   it is — a threshold given by the task, an estimate derived in place with its derivation shown, or a
   measurement of something that already exists — and how it was obtained. A number whose only honest
   provenance would be a measurement of the artefact the document describes cannot exist when the document
   is authored, and is forbidden.

2. **A reference names an ENTITY, and the two sides are joined by a shared id.** Two halves hold together,
   and neither replaces the other.

   **What is marked and what is referenced is always an entity, never a position.** In source: a method, a
   class, a variable, inside a named file. In prose: a heading, or a numbered item. A file-and-line position
   stops being the required form of a reference inside a durable plan document, and a position is never what
   either side points at.

   **The link between the two sides is an id they share.** A statement in a plan document carries an id; the
   same id appears in a comment on the entity that statement leans on. That shared id is what makes the
   pairing checkable in **both** directions: every id a plan names resolves to its entity, and every id
   marked in the source is named by some statement. Where the entity is prose, its heading or numbered item
   is already a declared identity and carries the id without a comment.

   Source files are therefore edited by this work and an id convention begins to be maintained. Line numbers
   keep exactly one use and lose the other: accepted in a round's own working record and in review output
   regenerated against the file in front of it, forbidden as an anchor inside a durable document. The
   distinguishing property claimed for an entity reference is detectability, not stability: a stale name
   resolves to nothing, while a stale position resolves to something plausible.

   **The id comment also has to be admitted by the rules that strip comments.** The repository deletes a
   comment that restates what the code already says, that deletion is swept for actively on every change,
   and it is instructed again at every handoff. An id states an identity rather than a reason, so it is
   admitted only by being named as **a directive an instrument reads** rather than as narration. Because an
   id now lives in a code comment, this admission is a requirement of the chosen form and not a widening of
   it: an id the next review strips is an id the bidirectional check cannot find. The precedent to extend
   rather than invent is already in the tree — a lint-suppression directive written in comment syntax
   appears four times across two of this repository's own test scripts (three times in
   scripts/test-loop-corpus.sh and once in scripts/test-upgrade-smoke.sh), one instruction surface tells a
   reviewer to honour such directives rather than sweep them, and one of the sweeping surfaces already names
   directives-in-comment-syntax as a class it must never flag.

3. **The checks on a design become convergence classes, and the mechanical ones hold the work.** Beside the
   existing architectural check, four classes: logical completeness (every named object has a place, a
   reason, a stated behaviour and something that will verify it; every requirement reaches an object; no
   dangling section reference; no criterion without a verification line), isolation (one fact in one place),
   semantic consistency (the document contradicts neither itself nor the artefacts it describes), and
   arithmetic (a stated rate or formula holds). Three are mechanical; semantic consistency is the one
   judgement class. What a design is checked against is convergence, never how much evidence it contains.

   **All three mechanical classes refuse rather than advise**, and a route exists to excuse a single finding
   that is harmless. An excuse, once granted, stands permanently until someone removes it by hand. The route
   is new surface: nothing in the repository excuses a finding today, and the one comparable act — levelling
   the record a comparison reads — prints the report it is about to take in, is never taken by an ordinary
   run, and is put to the author. The excusing route is held to the same three properties.

4. **A stated gate standard for a judgement class.** The three-outcome convention was written for
   deterministic gates, and a class a model runs is given a stated replacement rather than an exemption:
   three outcomes kept with a could-not-run still not a pass; reporting without ruling on harm; a positive
   control per class; agreement under repetition measured and printed; and never the only check standing.

5. **The closing pass becomes the frozen plan with its corrections applied, and what it still owes is
   narrowed.** It stops re-authoring the design. It applies the correction log's rows to the items that
   diverged, strips the spent scaffolding, and leaves the rest of the frozen document alone. Over the
   recorded divergences a reader still reads and vouches. Over everything else the pass owes only automatic
   checks for the content that goes stale unnoticed — numbers, and references to code — and owes **no**
   reader's assertion that the whole document describes what shipped. That whole-document assertion stands
   today in two places, in both the design contract's own closing-pass section and the closing-pass skill's
   ordered steps, worded in each as a positive assertion over every section and named in each as a
   judgement; both narrow. The principle stating that the closing pass authors afresh changes wording
   accordingly, and its replacement carries its own reason, which must answer the one it displaces — that an
   edit in place leaves every sentence the editor did not touch.

6. **A deliberately left-open gap carries a stated price.** A question may stay open in a plan only when
   answering it would change neither the chosen approach, nor the requirements, nor how the work is broken
   up. A gap that fails that test is not deferrable, and one that turns out to have been load-bearing after
   the plan was agreed goes back through the full design-and-review cycle rather than being patched in
   place. No new mechanism is needed: that is already how a divergence which breaks the approach is handled,
   so the rule names a price the route already charges. **This is a widening beyond the issue's five numbered
   items**, authorised by the author on the measurement behind it — the largest available study of
   multi-agent failures attributes roughly two fifths of them to unresolved ambiguity — and it must reach the
   author of a plan and its reviewer alike, the reviewer surface being the one that carries no such rule
   today.

**Items 1, 2 and 5 are interdependent by the issue's own argument.** Item 5's justification is that items 1
and 2 remove the content that rots silently: no measurement of the artefact under construction left to go
stale, and no line position left to drift. A decomposition that lets item 5 land before items 1 and 2 would
ship a decision whose stated grounds are not yet true, so the ordering is a requirement and not a
preference. Item 5's narrowed closing obligation inherits the same dependency: it machine-checks exactly
the two content classes items 1 and 2 govern, and item 2's bidirectional form is what gives the second of
those two classes anything to check in both directions.

## Out of scope

- **Scaling the review pass to the stakes** (the issue's sixth item). The issue itself records this as
  already filed as a separate pre-existing issue, so leaving it there is the status quo rather than a split
  of this task's scope. Recorded explicitly so it is not re-litigated later.
- **Correcting stale absolute figures already present in shipped content.** Filed separately as a
  pre-existing issue. This task changes the rule that admits such figures; it does not sweep the existing
  instances.
- **Measuring the closing pass's cost after the change.** Filed separately as a pre-existing issue.
- **A consuming project's own profile.** Whether a consumer's profile joins the protected set is already
  recorded as deferred by the page that would answer it, and it ships either way.
- **Re-running the prior-art research.** The issue's verdicts are taken as given, including the three that
  go against the position which opened it.
- **Positions inside a round's own working record.** The record of a review round is deliberately the home
  for the identifiers a durable plan may not carry; it is produced against the tree in front of it and
  deleted with the task. Its file-and-line obligations stay exactly as they are — including its standing
  duty to re-derive every position in a row it touches — and a sweep that removed them would break the
  routes that read it.
- **Retro-fitting ids to entities no plan references.** An id is created on the entity a plan leans on,
  never as a coverage exercise over the tree. This is also what keeps the second direction of the check
  honest rather than unsatisfiable: the source side is marked only where a statement exists to name it.
- **Any living as-built description of built behaviour in prose.** See Deferred.
- **A universal id on every statement a plan makes.** The id is carried by a statement that leans on a
  source entity, which is a rule about what such a statement contains rather than a new element either
  document must have.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| A living as-built document describing built behaviour in prose | Item 5 leaves the code as the only as-built record, because the behaviour contract collapses to its record of deliberate absence and the approach document stays the plan it was. The issue names this a deliberate position rather than an oversight, and names its own revisit trigger: a reader needing the built behaviour described in prose | Only when that trigger fires |
| Scoring a corpus of pre-implementation designs for numeric content against downstream rework | The one experiment that would settle the numbers question empirically. No study ablates a design document, and the closest proxies test nothing about what a design should not contain. It is a measurement programme, not a documentation change | Yes, if ever pursued |
| Catching a stale sentence that carries neither a number nor an identity | Accepted as unnoticed under this round's decision about what the closing pass still owes. The alternative was a reader's re-read of the whole document, which is the cost this work exists to remove. **This residue is NARROWER than the round that recorded it assumed**, because the bidirectional link gives the reference class two directions instead of one: a named entity that has since vanished is caught, and so now is a marked entity that no statement names any longer. What survives is prose stating neither a figure nor an identity — a rationale, a described behaviour, a claim about a tool | Only if such a staleness is ever observed to do harm |
| A fault reintroduced at a spot that carries a standing excuse | The author chose a permanent excuse over one that expires when its passage is edited, having been shown this exact cost in the choice: while the excuse stands, the check is silent at that spot even for a fault that is no longer harmless. The counterweight is that an excuse is never invisible — it is reported as excused and counted beside the verdict — so the silence is discoverable by reading the verdict rather than by remembering the grant | Only if a reintroduction is ever observed to ship |

## Key decisions

| Question | Decision |
|---|---|
| Does this task take all five plan items, or a narrower slice? | All five, as one spec and one task, with no work carved out into new tickets. The sequencing section constrains order only. |
| How far does the move away from file-and-line references go? | All the way: an entity is marked in the source and the plan's statement names it through a shared id. Both halves hold at once and neither is an alternative to the other — what is marked and referenced is always an entity, and the id shared between the two sides is what the check reads in both directions. The author calls this the strongest available form. Measured before the choice: the tree carries no declared id of any form today, so every id this work relies on is one this work creates. |
| What does an id sit on, and what may it never sit on? | An entity. In source that is a method, a class or a variable inside a named file; in prose a heading or a numbered item. Never a position, and never a region of a file identified by where it falls. A prose entity needs no comment, because its heading already is its declared identity. |
| Which way does the check run? | Both, and that is the reason the form was chosen. Every id a plan names must resolve to the entity carrying it, and every id marked in the source must be named by some statement. One direction alone would leave either dangling statements or orphaned marks, and the two failures are discovered at different times. |
| Is a bidirectional keyed pairing a new mechanism shape for this repository? | **No, and that is the strongest precedent available — it is already shipped here, not merely in an external toolchain.** The closing pass's own check already pairs a marker carrying a key inside a design against the row carrying that key inside the correction log, compares the two as sets in both directions, and reports a marker with no row and a row with no marker each as a finding. Item 2 extends that proven shape from design-to-log to design-to-source, so the work inherits a tested mechanism rather than inventing one — and inherits the three hazards it already records. |
| Does an id comment already sit inside the repository's comment policy, as the issue asserts? | **No — the issue's claim does not survive reading the live policy, and the admission is a requirement of the chosen form rather than a widening of it.** The policy's admitting rule is not "anything that is not narration": it is that a comment is written only for a non-obvious reason the code cannot express, and the one live sentence about a reference-style comment says that a ticket number in a comment is not automatically such a reason. Deleting a narration comment is a blocking finding while adding any comment is never more than a suggestion, so a reviewer is positively rewarded for deleting an id. Five surfaces carry that policy or enforce it: the policy page itself, the mandatory per-change comment sweep, the whole-branch review contract, the whole-branch review skill, and the handoff instruction that tells the next implementer to keep only a genuinely non-obvious why. So the id needs an explicit admission as a directive an instrument reads. The author has accepted this consequence explicitly. |
| Is the precedent to extend already in the tree, or does it have to be invented? | It exists, and was re-derived rather than taken on trust. A lint-suppression directive written in comment syntax appears four times across two of this repository's own test scripts — three times in scripts/test-loop-corpus.sh and once in scripts/test-upgrade-smoke.sh, one a structural test suite and the other one of the delivery gates, and neither of them a check script; one instruction surface tells a reviewer to honour existing per-file directives of that form rather than sweep them; and the mandatory comment sweep already names directives-in-comment-syntax as a class it must never flag. **But that existing class is stated by EXAMPLE, not by rule** — it names a migration directive, a lint suppression and a build pragma, and nothing in it decides a form the list does not mention. So the work extends a real precedent and must also convert it into a stated membership rule, because an example list cannot admit a class it was written before. |
| What do the three mechanical classes do when they find something? | They hold the plan until it is fixed. All three refuse; none merely reports. The failure that cost four passes was a duplication of one figure across three sites, and report-only is the posture under which it happened. An override route for a harmless finding must exist. |
| Where can that override route live? | Inside the check, never in the layer that collects verdicts. That layer is all-or-nothing by construction — any member's failure fails the whole run — so a member that could be excused there would be a member that can never refuse. The excusing act therefore belongs to the check's own clean / findings / could-not-run verdict, which is also what lets an excused finding stay visible instead of vanishing. |
| How long does an excuse last? | **As long as the plan it covers, and permanently within it.** It lives beside that plan. Inside the plan it covers that finding at that spot until an explicit act deletes it; editing the passage does not revoke it, and the same fault returning there is reported as still excused rather than raised afresh. The closing pass removes it together with the correction log, so in a later unrelated task the check objects again from scratch. The author chose permanence-within-the-plan over an excuse that expires when its passage is edited, having been shown the cost in that choice — while the excuse stands the check is silent at that spot — and chose it over an excuse outliving its plan, which was offered with its own two costs: a grant made in one task would silence a check in an unrelated one, and the record would need a home that either a surface or a named exclusion must claim, or the count of files neither of those claims stops being zero. What survives from the expiring alternative is the part the choice did not touch: an excused finding is reported as excused and counted beside the verdict, so a plan carrying many excuses cannot read as a clean one. |
| What does the closing pass still owe for the parts no correction was recorded against? | A machine check over the rot-prone content only. The recorded divergences are read and vouched for; over everything else only automatic checks for numbers and for references to code run. No reader's assertion over the whole document survives. Anything stale that carries neither a number nor an identity goes unnoticed, and that is accepted — items 1 and 2 remove most of what could be stale, and this closes the displaced principle's hole mechanically rather than by hoping someone re-reads. |
| What covers a divergence that occurred and was never recorded? | Settled by the answer above and no longer open. The enumerated corrections are what a reader vouches for; an unrecorded divergence is reached only if it shows up as a number or as an identity that no longer pairs, and otherwise is accepted as unnoticed. |
| Does the closing pass's existing retention-and-residue check need changing for item 5? | No, verified against it: it compares the retained contract sections against their text in version control, asserts the design free of the spent headings and the markers, and asserts the correction log gone. Not one of those assertions presumes the document was re-authored, so keeping the frozen text with corrections applied satisfies all of them unchanged. |
| Which record loses its duty to re-derive file positions, and which keeps it? | Verified, because the same sentence sits in two contracts governing records with different lifetimes. The **committed** correction log loses it: its references become entity-plus-id, so there is no position left to re-derive. The **ephemeral** round working record keeps it untouched — it is produced against the tree in front of it, deleted with the task, and is the sanctioned home for positions. Reading the obligation as one rule over both records would have removed a duty that record still needs. |
| Is the rule about a deliberately left-open gap in scope? | Yes — taken on in this task, authorised explicitly by the author on top of the earlier decision to do all of it. Leaving a question open now carries a stated price instead of being free, and the price needs no new mechanism because an approach-breaking divergence already routes back through the full cycle. |
| Does the isolation class reach a paraphrase, or only a repeated literal? | Repeated literals, default taken and recorded rather than asked. That is the class of failure actually measured on the run that prompted this work, where one figure was pinned at three sites. Reaching a paraphrase needs judgement, which would move the class across the determinism boundary the whole plan rests on — three mechanical classes are what pays for the single judgement one — and paraphrased self-contradiction is already the judgement class's own subject. |
| Who may excuse a mechanical finding? | The author, by an explicit act, and never the pass that produced the document. The repository's standing rule is that a rule enforced only by an instruction file is not a refusal, and the one comparable act in the tree is put to the author for exactly that reason. A self-excusing pass would make the refusal just decided advisory again. Removing an excuse is an act of the same kind, by the same hand. |
| The issue states that every surface this work touches is a protected page whose edit fires an author-authorised refusal. Does it? | Not for all of them, verified against the live protected set. The design contract, the design-review contract and the closing-pass skill are inside the edit-time refusal; the principles page and the method page are deliberately outside it, the latter with a measured reason recorded on the principles page itself. The comment policy and the review passes that sweep comments are outside it too, and this work now also touches those. The work plans for a refusal on the first group and for the principles page's own two-edit authorisation route on the second, rather than assuming one mechanism covers both. |
| The issue states that the three-outcome gate convention lives in the method page, so item 4 amends it there. Does it live there? | No. No method page states it as a convention. It appears as a per-gate restatement inside four separate contracts and as a rule in this repository's own profile, and one contract calls it "this repository's" in so many words. Item 4 therefore ESTABLISHES the convention in the method half as well as extending it to a judgement class — a larger change than an amendment, and one that must hold for every consuming project rather than for this one. |
| Can item 4's new wording, item 6's, or item 2's id obligation be added to the method page freely? | Only if it mandates no element of either document. The principles page excludes the method page from the refusal precisely because that page restates no element mandate, and its membership rule is that a page acquiring such a rule joins the set. Item 6 passes on the element record rather than on what its sentences mean: the open-questions section is already a recorded required element of BOTH documents, so no route can make it newly required — not a writer's template, which already enumerates it; not a review contract treating its absence as a blocking finding; and not a mechanical check asserting its presence. The derivation that reads a severity verdict beside an element-shaped token therefore yields, for item 6's wording, a pair the record already carries, so no arrival is reported either. The ground is deliberately not "it only constrains what may be written inside a section both documents already carry": that is a claim about what a sentence means, while the live derivation reads shape and not meaning. Item 2's id obligation passes because it constrains what a statement leaning on source must contain, and requires no new section and no new field. Item 4's wording must be checked against the same test as it is written. |
| Is the provenance obligation written for the approach document only, or for the behaviour contract too? | Default taken: both, because the principle it extends already binds a spec and a design alike, and a measurement of the artefact under construction is equally impossible in either. A narrowing to one document would need an explicit carve-out sentence stating why the other is exempt. Recorded as a widening beyond the issue's literal wording, which speaks only of a design. |
| Does item 6's price bind the behaviour contract's open questions as well as the approach document's? | Yes, same default, and the author's own wording supports it: the test names the requirements alongside the approach and the decomposition, and the requirements live in the behaviour contract. The route already exists on that side too — a changed requirement is amended and then re-enters the design cycle — so the price is again a name for an existing charge. |

## Technical constraints

- **Every surface this work touches is in the method half**, so none of the new wording may name a
  language, a build tool, a domain entity or a ticket prefix. A project fact landing in a method file is a
  blocking finding, and item 4 is the exposed case: the convention it establishes currently exists only as
  a project-profile rule and must be restated so it holds in every project.
- **Instruction files an agent loads are capped, with an early-warning band below the cap, and the
  pressure is now measured rather than estimated.** A size scan of the tracked instruction files, run
  while this was written, puts one surface this work must edit already inside the warning band and three
  more within a few hundred characters of it — among them the whole-branch review contract, which must take
  the comment admission, and the task skill, which is a propagation sibling in three of the groups this work
  fires. Those figures are measurements of files that already exist, taken at authoring time, and they move
  as soon as the work starts: so they are a reason to treat extraction as planned work with its own
  acceptance, and they are not a budget. Each file is re-measured immediately before and immediately after
  its own edit.
- **Extraction is work in this task, not a contingency.** At least two of the surfaces cannot absorb their
  new wording without text leaving them for a reference page. A plan that adds the wording and accepts the
  band is a plan that ships a known finding.
- **The comment admission must be a membership rule and not a longer example list.** The one existing
  directive carve-out names three example syntaxes and decides nothing about a fourth, which is exactly how
  a class stated by example fails the form it was written before. The admission states what makes a comment
  a directive — that an instrument reads it — so a reader can class a form the examples never named.
- **An id must resolve to exactly one entity.** Two entities carrying the same id, or two statements
  claiming it, make both directions of the check ambiguous rather than failing it, which is the quiet
  outcome. The spelling and namespace of an id are the design's to choose; uniqueness is not.
- **The existing pairing records three hazards the source-side check inherits, and each one was paid  for.** First, **a document that QUOTES the id convention is not a marked document**: the live pairing  filters by the key's shape precisely because a page explaining the mechanism spells its token out, and  the first real run reported that explanatory placeholder as an unpaired key. The filter has to bind  BOTH sides, because the source can quote the convention as readily as a plan can. Second,  **comparison is by equality over whole ids, never by containment** — one id is a prefix of another, so  a containment search reports an id as accounted for because a longer one was. Third, **a pairing count  of zero is part of the verdict**, because an unmarked document and an unmarked source agree vacuously  and that is indistinguishable from both directions having been checked.
- **The propagation fan-out is wide, and it is a cost rather than a formality.** Editing the design
  contract or the review contract fires the group binding them to the task skill and the handoff skill;
  editing the closing-pass skill fires a group of ten surfaces; editing the principles page fires a group
  that includes the verification's own payload, the recorded comparison inventory, the edit-time refusal's
  page list and all seven protected pages; and editing the comment policy reaches the three review surfaces
  that sweep comments plus the handoff prompt that repeats the instruction. Several files sit in three
  groups at once, so one edit can oblige a dozen others in the same change.
- **A principle's wording cannot change on its page alone.** The verification holds its own pinned copy of
  the principle sentences; the page and that copy move in the same change, and that pairing is the
  authorisation route rather than an obstacle. The change lands inside the examined corpus, so the
  comparison record is advanced only by the acceptance route, which prints the report it is about to take
  in, and that run is itself put to the author.
- **The principles page carries commentary that counts its own principles**, naming how many of them are
  prohibitions and which single one is a test rather than a prohibition. Two principles change wording
  here and a further rule may or may not become a ninth; either way that commentary moves with them, and an
  addition has its own stated authorisation route on the page.
- **A principle is present only with its reason.** The replacement for the closing-pass principle carries
  its own one-clause reason; a sentence stripped of it is not the principle in shorter form, because the
  reason is what a later reader weighs a proposed exception against.
- **An absence is reported distinctly from a wording difference**, and a could-not-run is reported
  distinctly from a pass. Both distinctions already hold for the existing verification and must survive.
- **More than one contract states the closing pass's behaviour in its own words.** Both the design
  contract's own closing-pass section and the closing-pass skill say the design is authored afresh, section
  by section, and each carries the positive whole-document assertion as a named judgement step; item 5
  moves both. The closing pass's residue assertions stay: the spent scaffolding is still stripped, and the
  correction log is still removed.
- **The two instructions that currently travel together must not be severed by accident.** "Afresh"
  constrains what the content is derived from, and that is what item 5 removes; "section by section"
  constrains how the bytes are delivered, and it exists because a full-file rewrite of a document this size
  is where a write is most likely to be lost. The second survives item 5 on its own terms.
- **A non-empty open-questions section is today the strongest single signal routing work into its
  exploratory mode.** Item 6 narrows what may legitimately sit in that section to questions that change
  nothing structural — close to the opposite of what the signal is read as meaning. The two statements
  cannot both stand unexamined: the signal's stated ground is re-justified or re-based in the same change,
  and leaving them side by side is a self-contradiction of exactly the class item 3's judgement check
  exists to catch.
- **An edit to one instruction file propagates to its sync-group siblings in the same change.**
- **Shipped content changes, so the plugin's patch version is bumped in the same change**; the install
  cache is keyed by version, so an unbumped change never reaches an installed copy.
- **A rule enforced only by an instruction file is not a refusal.** Where a criterion below says something
  is reported, the obligation is mechanical unless the criterion names it as a judgement.
- **A new check must not be able to narrow its own input set silently.** A check that processes fewer
  inputs than exist reads exactly like a clean one, so the count of what was examined is reported beside
  the verdict.
- **Ids go into files written in several languages that share no annotation mechanism, and one of those
  languages admits no comment at all.** Wherever a comment exists — the shell scripts, and each of the
  non-shell payload languages beside them, all of which take a comment introduced by a single character — a
  comment is the id's only available carrier, and the admission recorded above is what keeps it alive. The
  hook manifest and the two files that declare the plugin are the exception, and so is every other file
  in the tree written in the same language: JSON has no comment syntax at all, and a line added as one
  stops the file parsing, so there is no carrier to admit. The exception is stated as the language's
  property rather than as a list of the files that have it today, for the reason the admission above is
  stated as a membership rule. An entity in such a file can therefore carry no marked id, which is why the criterion governing
  the pairing is narrowed rather than read as satisfied there.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | A number stated in a spec or a design that does not name, in the same sentence, which kind of number it is and how it was obtained is reported as a finding. |
| AC2 | A number whose only possible origin is a measurement of the artefact the document describes is reported wherever it appears in either document, naming the number and where it sits. |
| AC3 | An estimate whose derivation is shown in place is accepted, and so is a threshold handed down by the task. The obligation admits the derived figure that chooses between approaches and excludes only the figure that cannot exist when the document is written. |
| AC4 | A reference in a durable plan document that identifies its target by position within a file is reported. One that identifies its target as a named entity — a method, a class or a variable in a named file, or a heading or numbered item in prose — is not. |
| AC5 | A reference whose named entity no longer exists is reported, naming the reference that failed to resolve; a reference whose entity exists is silent. |
| AC6 | A statement that leans on a source entity carries an id, and the same id appears in a comment on that entity. A statement whose id is matched by no marked entity is reported, and a marked id that no statement names is reported, each naming the id and which side was missing. The number of pairs actually compared appears beside the verdict, so a document carrying no ids and a source carrying none do not read as agreement. Where the entity's language admits no comment, the obligation narrows: the statement names the entity, and the reference resolves in ONE direction only — from the statement to the entity it names, which must exist — and no reverse pairing is asserted for it. The guarantee that holds in both directions therefore does not cover those entities, and that limit is stated here rather than left to be inferred, because a criterion that silently loses a guarantee is worse than one that states where it stops. |
| AC7 | An id resolves to exactly one entity. The same id marked on two entities, or claimed by two statements, is reported as ambiguous rather than passing in either direction. |
| AC8 | An id survives the rules that delete comments. A pass enumerating the comment lines a change adds classes a comment carrying an id as a directive an instrument reads and reports nothing against it; a review of the whole tree does the same; and a handoff that instructs the next implementer to delete restating comments exempts it likewise. Deleting one is a finding, not a cleanup. |
| AC9 | The rule that admits such a comment states what makes it a directive rather than listing which syntaxes qualify, so a comment form the rule's examples never named is still classed correctly. |
| AC10 | A position within a file remains accepted in a round's own working record and in review output produced against the file it describes and discarded with the round that produced it, and the obligations that read those positions — including the duty to re-derive every position in a row that is touched — are unchanged by this work. |
| AC11 | The committed record of corrections carries no surviving obligation to re-derive a file position, because the references in it name entities and ids instead. The ephemeral working record's obligation is untouched, and no single rule spans both. |
| AC12 | A plan naming an object that has no stated place, no reason, no stated behaviour, or nothing that will verify it is reported, naming the object and what it lacks. The same report covers a requirement that reaches no object, a section reference that resolves to nothing, and a criterion carrying no verification line. |
| AC13 | A plan stating the same fact in two places that can drift apart is reported, naming both places. The reach is a repeated literal; a paraphrase is the judgement class's subject and not this one's. |
| AC14 | A stated rate or formula whose arithmetic does not hold is reported, with the computed value shown beside the written one. |
| AC15 | A finding of any of the three mechanical classes prevents the plan from being treated as agreed. The hold is a refusal and not a recommendation: nothing short of fixing the finding or excusing it explicitly lets the plan proceed. |
| AC16 | A single finding can be excused by an explicit act that records which finding is excused, where it sits, and on what grounds, in terms a later reader can check. No ordinary run excuses anything, and the act shows the finding it is about to excuse before excusing it. |
| AC17 | An excused finding stays visible: it is reported as excused rather than omitted, and the number of excused findings appears beside the verdict, so a plan carrying ten excused findings cannot read as a clean one. |
| AC18 | An excuse dies with the plan it covers. It lives beside that plan, and within that plan it stands until it is removed by hand: editing the passage it covers does not revoke it, and the same fault recurring at that spot is reported as excused rather than raised afresh. In a later, unrelated task the check objects again from scratch. Removing an excuse by hand is an explicit act of the same kind as granting one, and the record names the spot plainly enough that a reader can find the excuse in order to remove it. The closing pass is the one stated exception to that sameness: it removes every excuse together with the correction log, by nobody's explicit act, because the plan's end of life ends the spot the excuse covers. |
| AC19 | A plan that contradicts itself, or that contradicts the artefacts it describes, is reported. That report carries no verdict on whether the contradiction does harm; the author rules on it. |
| AC20 | The judgement check distinguishes three outcomes — clean, findings, and could-not-run — and a could-not-run is not a pass. |
| AC21 | A deliberately planted fault of each class the judgement check covers is caught by it. A class with no such demonstration is not a check and is reported as uncovered. |
| AC22 | The judgement check's agreement across repeated runs over one unchanged input is measured and reported with its result, rather than assumed. |
| AC23 | A judgement result never stands alone: the mechanical classes' results are produced beside it in the same pass. |
| AC24 | The closing pass retains the frozen document and applies the correction log's rows to the items that diverged. A closing pass that re-authors the document is a violation of the stated principle, not a stylistic choice. |
| AC25 | Over the items no correction was recorded against, the closing pass reports a number that no longer holds and an identity that no longer pairs in either direction, and owes nothing further. No obligation anywhere requires a reader to assert that the whole document describes what shipped, and a stale sentence carrying neither a number nor an identity is accepted as unnoticed. |
| AC26 | Over the items a correction WAS recorded against, a reader still reads the result and vouches for it. |
| AC27 | The closing pass still strips the spent scaffolding, removes the correction log, and removes the plan's record of excuses; anything retaining any of those three afterwards is reported. |
| AC28 | The behaviour contract's collapse to its record of deliberate absence is unchanged by this work, and the sections it retains still survive the pass byte-identically. |
| AC29 | The principle governing the closing pass states its own reason, and that reason accounts for why an edit in place is now safe where it previously was not. |
| AC30 | A plan leaving open a question whose answer would change the chosen approach, the requirements, or how the work is broken up is refused at review, not merely noted by its author. A plan whose open questions change none of those three is accepted. |
| AC31 | A gap left open that later turns out to have changed one of those three re-enters the full design-and-review cycle; patching the agreed plan in place is refused. |
| AC32 | The price of leaving a gap open is stated to the author of a plan and to its reviewer alike, and neither statement is satisfied by the other's presence. |
| AC33 | The set of pages whose edit fires the author-authorised refusal is the same after this work as before it, and two conditions are both needed to make that so: no wording this work adds makes any element of a spec or a design required, and no page or script this work adds or edits acquires a locus that defines or enforces a required element. The first condition alone does not carry the conclusion, because a page belongs to the set by defining OR by enforcing a required element: a new mechanical check that asserts the presence of an element which is already required thereby enforces it and joins the set, with nothing having become newly required. If an element is made required after all, it is recorded in the element record in the same change. |
| AC34 | Every number this work introduces into a method page satisfies AC1 through AC3, and every reference it introduces satisfies AC4 through AC7 — the rules hold first for the documents that state them. |
| AC35 | Every instruction file this work edits is measured immediately before and immediately after its own edit, and none ends above the cap or newly inside the early-warning band. Where new wording would cross either line, text is extracted to a reference page in the same change rather than the band being accepted. |

## Open questions

All decisions this spec needs are taken. Three items are left open deliberately, and none of them changes
the approach, the requirements, or how the work breaks up.

- **Who runs the semantic class** — the existing review contract, or a reader of its own with its own
  invocation. Left to the design; both satisfy the judgement criteria above, and the choice is about cost
  rather than about what the mechanism can do.
- **How an id is spelled and where its namespace lives.** The criteria fix the behaviour — one id, one
  entity, checkable from both sides — and leave the form to the design, which chooses it while the checks
  are written rather than promising it here.
- **Whether the arithmetic class has any precedent to borrow from.** The issue reports finding none and
  calls it new and the cheapest of the five. If it is genuinely novel, its positive control carries more
  weight than the other classes', because nothing external corroborates its shape.
- **Where the comment admission is stated once rather than five times.** Five surfaces carry or enforce the
  comment policy today, and one of them already owns a directive class — which makes it the natural
  candidate to hold the definition while the others point at it. Whether that consolidation is taken is a
  question about the measured sizes, and the design answers it against those rather than here.
