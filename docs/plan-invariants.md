# Plan invariants — the base principles of a spec and a design

This page is the single authority on the WORDING of the principles below. Where another instruction file
states the same rule in its own words, this page governs on any disagreement.

It also records the required composition of a spec and of a design, which pages define or enforce that
requirement, and which pages deliberately do not.

**The limit, stated first because a reader who takes a clean verification for a proof has misread it.** An
edit that contradicts a principle, or that adds a required element, is **caught and named — never
prevented**. The mechanism makes such an edit impossible to make *silently*; it does not make it
impossible to make. One further bound follows from that one, and it is the widest: the edit-time refusal
recognises an edit by its SHAPE, so a writer it does not recognise reaches the page, and what reads the
change there is a human reading a diff. Two classes of change are from now on caught by the pull-request
diff and by nothing mechanical: a mandate arriving on an examined page that the element derivation does
not read, in words the coverage sweep does not recognise; and a change to prose that is not one of the
principles' own numbered sentences, those sentences being the only prose any surviving comparison pins, so
the explanatory paragraphs around them, and prose anywhere else on the examined surfaces, are pinned by
nothing.

## The base principles

1. **One writer per artefact.** The orchestrator writes neither a spec nor a design; each is written only
   by its owning subagent. *Because a party that both writes a document and reports on it can close a
   finding by editing the evidence.*
2. **A spec is a behaviour contract, not an implementation plan.** A criterion may not spell a command,
   script, tool or test identifier. *Because a criterion naming its instrument asserts which instrument
   ran, not what the system does, and cannot survive a change of instrument.*
3. **A design says NOTHING about tests**, and the furthest it goes is naming the cases each object it
   builds is used in. *Because every sentence a design could write about a test is a promise about
   something that does not exist when the document is authored, and each narrowed version of this rule
   regrew — first a per-criterion command, then an intent line, then a suite total.*
4. **The design is frozen at the design-review GO verdict.** After it, a divergence that does not break
   the agreed approach is a marker plus a log row, never a rewrite. *Because re-verifying an unchanged
   document every round is the cost this replaced.*
5. **A changed requirement goes to the spec; a changed artefact goes to the log; nothing is recorded in
   both places.** *Because two records of one fact is the drift the mechanism exists to reduce.*
6. **Neither document carries a record of superseded material, and no verdict may require one.** *Because
   every such passage is read in full by every later whole-repository review and none of it describes the
   system.*
7. **The closing fold runs once, after approval.** It applies the correction log's rows to the design
   items that diverged, collapses the spec to its record of deliberate absence, and leaves the rest of the
   frozen document alone. *Because an untouched sentence is now either caught mechanically — a number
   whose provenance is gone, an identity that no longer pairs in either direction — or it is prose stating
   neither, which is accepted as unnoticed rather than re-derived against the chance that it rotted.*
8. **A required element of a spec or a design must be knowable at the time the document is authored, and
   so must the origin of every number either document states.** An element whose content is only
   determined later is forbidden. A stated number names, in the same sentence, which kind it is — a
   threshold the task handed down, an estimate derived in place with its derivation shown, or a
   measurement of something that already exists — and how it was obtained; a figure whose only honest
   origin would be a measurement of the artefact the document describes is forbidden with it, that
   measurement being one nobody can take while the document is still being written. *Because it
   guarantees two failures at once: invented content at authoring time, and a review loop at the end that
   cannot converge — the document is corrected against reality, reality moves on, and the correction
   reopens.*
9. **A question left open must be one whose answer would change neither the chosen approach, nor the
   requirements, nor how the work breaks up.** A gap failing that test is closed before the plan is
   agreed; a gap passing it that later turns out to have changed any of the three re-enters the full
   design-and-review cycle rather than being patched in place. *Because the gap is paid for either way,
   and the cheaper-looking price — note it and carry on — is the one that falls due as a rewrite of an
   agreed plan at the moment the work is most committed to it.*
10. **A spec broader than its design is not a contradiction, and only a genuine conflict changes the spec.**
    A genuine conflict is a design that does what the spec explicitly rules out, or drops a behaviour an
    acceptance criterion requires, with no other sentence of the same spec requiring it; a spec that is
    general or silent where the design is specific is breadth, and a departure another sentence of the spec
    requires is stated once, among the design's risks, and is not a spec finding either. *Because a spec
    narrowed to match its design states the design's detail a second time, costs an approval and a fresh
    planning round, and is deleted when the closing fold collapses the spec, so the narrowing is paid for
    and then discarded.*

**All but three are prohibitions; the remaining three are tests, and each hands a reader a question rather
than a boundary.** The prohibitions say what may not happen. The eighth asks of a proposed element: can
its content be known when the document is written? If not, it is out — and the reason is not taste. An
element whose content arrives later forces the author to invent it, and the end-of-task review then
corrects the document against a tree that keeps moving, so the correction reopens every round. The ninth
asks the same kind of question of a gap: would answering it change the approach, the requirements or the
decomposition? If it would, the gap is not one this plan may leave open, because the answer arrives after
the plan is agreed and lands as a rewrite rather than as a note. The tenth asks of a spec sentence the
design is more specific than: does the design do what the spec rules out, or drop what a criterion
requires?

**The tenth test in full.** A spec sentence is read for its intent within the whole spec, and a design
measured against it falls into one of three cases, of which only the third is a finding against the pair.
**Breadth** — the spec is general or silent where the design is specific — is no finding at any severity.
**A departure the spec itself requires** — the design departs from a literal reading of one sentence
because another sentence of the same spec, a criterion, a constraint or a key decision, requires what the
design does — is no spec finding; the design states it once, among its risks, and that statement is the
single record. A spec-internal tension the design resolves by following the spec's more specific sentence
is this case too. **A genuine conflict** is the one the tenth sentence defines, and its remedy is either
the design complying, routed as a design-side fix, or the requirement changing, which is a spec amendment
the user approves; a reviewer presumes neither. The test reads spec sentences only, so a design sentence
the implementation contradicts routes exactly as it did before. It is the fifth principle applied at the
spec/design boundary: a deliberate departure has one record, in the design, and the spec is not rewritten
to repeat it.

**The obligation half asks a second question of every number, and its answer is provenance rather than
silence.** Which kind of number is this, and how was it obtained? A threshold the task handed down, an
estimate whose derivation is shown where it is stated, and a measurement of something that already exists
all answer it, in the sentence that states the figure and not in a later paragraph a reader has to find.
A figure that can answer neither half without measuring the artefact the document describes answers it
with nothing at all, because that measurement is one nobody can take yet. **A document is not made
honest by stating fewer numbers** — the figure that chooses between two approaches has to be there for
the choice to be checkable, so the remedy for an unprovenanced number is its provenance and never its
deletion.

**The eighth is the general form of what the third says for identifiers alone.** The generative case,
measured rather than imagined: a rule once mandated, inside the design, a per-test list carrying line
numbers and expected results. Those identifiers do not exist when the design is authored, so the author
fabricated them; review corrected the document against the tree, the tree moved, and the correction
reopened. **The rule live today is wider than the correction that replaced it, and the widening is this
page's own history repeating:** the correction left the design stating a per-criterion verification
intent, that intent was then found to be the same promise in a shorter form, and the rule now in force
is that a design says nothing about tests at all. Every narrowed version regrew — a per-criterion
command, then an intent line, then a suite total — which is why the prohibition is the whole class.
Where a concrete command, identifier or path is wanted, it is recorded in the implementation round's own
working record, outside the frozen base and deleted with the task.

**A principle is present only with its reason.** Each numbered sentence carries its own one-clause
`*Because …*`; a sentence stripped of it is not this principle in shorter form, because the reason is what
a later reader weighs a proposed exception against.

## The required elements of a spec and of a design

An element is **required** when a writer's template enumerates it, when a review contract treats its
absence as a blocking finding, or when a mechanical check asserts its presence. All three routes count;
the second and third change what a document must contain without any template changing anywhere.

Elements are keyed by **document and token together**, because one section name is required of both
documents and dropping it from one of them must stay visible. They are **compared as a set, never
counted**: replacing one required element with another leaves a count unmoved while a set comparison
reports a departure and an arrival.

| Document | Required element |
|---|---|
| spec | `## Scope` |
| spec | `## Out of scope` |
| spec | `## Deferred` |
| spec | `## Key decisions` |
| spec | `## Technical constraints` |
| spec | `## Acceptance Criteria` |
| spec | `## Open questions` |
| design | `## Approach` |
| design | `## Decomposition` |
| design | `## Handoff plan` |
| design | `## Risks` |
| design | `## Use cases` |
| design | `## Open questions` |

**This record is not the route by which an element becomes required.** It is cross-checked against the
pages above in both directions: widening the record alone names an element no page mandates, and widening
a template alone names an element the record does not carry. Either direction is a finding. That is what
keeps this page out of the refusal set — it mandates nothing, so an edit here cannot quietly make
anything mandatory.

**Three headings in the spec's record of deliberate absence survive the closing fold byte-identically** —
`## Out of scope`, `## Deferred` and `## Key decisions`. Two headings are the fold's opposite case: it
must REMOVE `## Handoff plan` and `## Open questions` from the design. That removal list is a
prohibition, not an element source. Both of its entries happen also to be template elements today, which
is coincidence rather than structure, so a widening of it is reported as a prohibition arriving and
named — never absorbed into the set above.

## The protected page set

**Membership is derivable, and the rule is this: a page belongs here when it defines or enforces a
required element of a spec or a design.** The rule is what matters; the paths follow from it. A page that
acquires such a rule joins the set rather than becoming the unguarded route.

| Page | What about it defines or enforces a required element |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md` | Enumerates the spec's required sections as a template, and separately states what a criterion may and may not contain. Both are composition |
| `${CLAUDE_PLUGIN_ROOT}/agents/design.md` | Enumerates the design's required sections as a template; mandates one further element in its rules rather than in that template; and names which spec sections survive the closing fold. Three loci in one file, and the measured damaging edit was of exactly this class. **It was four until the per-criterion verification line was removed as an element** — recorded because a locus count that only ever grows is the shape this row warns about |
| `${CLAUDE_PLUGIN_ROOT}/agents/design-review.md` | Makes the absence of named elements a blocking finding under its own severity rubric. The quieter of the two routes to a new requirement: an element becomes mandatory here with no template changing anywhere |
| `${CLAUDE_PLUGIN_ROOT}/skills/redline-fold/SKILL.md` | Names the spec sections retained byte-identically and the design headings allowed to survive, so it defines what both documents contain after the fold |
| `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md` | Its binding step rule requires the design's handoff-plan section to exist in order to operate at all |
| `${CLAUDE_PLUGIN_ROOT}/skills/task/reference.md` | Its step-gate checklists assert the presence of individual sections before a step may close; an element asserted there is required in practice whatever the templates say |
| `${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh` | Carries the retained-spec-section list, the surviving-design-heading list and the criterion-content rule as data. Widening a list here adds a required element without touching one word of prose. **It carried a fourth, the per-criterion verification-line requirement, until that element was removed**; the verb asserting it was deleted with it |

**The refusal is armed by learning mode, and while armed it asks only about a section change.** The
measured damage came from a self-improvement pass, so the refusal fires only in a session that ran one of
the automated learning passes — `/improve`, `/improve-global`, or `/ai-audit`, whose escalation audit
edits instruction files on its own — read from that session's transcript by structure: a mention of the
name is not a run. While armed, an edit to one of these seven is judged by the page before it against the
page after it, and put to the author when it adds, removes or renames a heading of level two or deeper, or
adds or drops a name from the required-element record above; a typo fix in an unrelated paragraph passes.
A shell write to one of them is put to the author whenever it is recognised, because its content is not
visible to the refusal. A change the refusal cannot read — an unreadable record, an unreadable page, an
edit whose text the payload does not carry — fails toward asking. **A mandate written in plain prose
inside an existing section, spelling neither a heading nor a recorded name, passes the refusal even when
armed;** what reads it is the pull-request diff, the class the opening limit of this page already names.
Outside learning mode the refusal is silent, and an element arriving or leaving is what the verification
catches, in the full check list and in the pull-request diff. This replaced a refusal that asked on every
edit, and measured, almost none of the edits it stopped changed a section.

## The near misses

These pages touch document composition, or could, and are deliberately outside the refusal. Each one
stays inside the detection, in the width § Two surfaces states for it: every page named here is on one of
the five examined surfaces. **What reads a page FOR a rule that makes an element required is narrower than
that**, and two rows below sit partly outside it — the coverage sweep skips the principles page,
the guard and every `test-*.sh` before it inspects anything, so the row naming `scripts/test-check-redline.sh`
and its siblings is a corpus member and nothing more, and the enforcement row holds for `hooks/hooks.json`,
which the sweep does read, but not for the guard or the seven `hooks/lib/test-*.sh` beside it.

| Page | Why it is out |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` | Reads only the criteria list from the spec, and reads the per-round working record for content. It mandates no element of either document today, and it is the most-edited of the candidate contracts, so admitting it on its capability alone would buy no protection at the highest price of any candidate |
| `${CLAUDE_PLUGIN_ROOT}/agents/review-findings.md` | Makes a use case no test covers a blocking finding, which is about the coverage of an element the design template already requires rather than about requiring a new one. **Its predicate was rewritten when the per-criterion verification line stopped being an element**, and the near-miss verdict survives the rewrite for the same reason it was granted: it still scores coverage of a section the template mandates, and mandates nothing itself |
| `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` | Defines the composition of the round record that deliberately sits OUTSIDE the frozen base, and is the sanctioned home for the identifiers the third principle keeps out of the design. Protecting it would guard the relief valve, not the documents |
| `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` | Measured, and it reproduces: a sweep of the whole method-documentation directory for any section name of either document returns only this page, whose record table spells all thirteen element tokens as data and mandates nothing for the reason given under that table. This row's page is not among the hits, so it defines no element — and it is the single most-edited file in the tree. The pointer it carries to this page names the document and its authority, and restates no element mandate; a pointer that restated one would make that file element-defining |
| `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` and the shared code under `${CLAUDE_PLUGIN_ROOT}/hooks/lib/` | Out of the REFUSAL set, and out of that set only. Neither mandates an element today, and this is where the refusal itself registers — so refusing edits here would make the protection unable to arrive without authorising its own arrival. The text this layer writes into an agent's context as a session or a tool use begins is instruction material, so it is INSIDE the detection |
| `${CLAUDE_PLUGIN_ROOT}/scripts/test-check-redline.sh` and its siblings | They reproduce both documents' section names as fixture text. A fixture asserts nothing about what a real document must contain, and the fixtures move with every change to the checks |
| `${CLAUDE_PLUGIN_ROOT}/skills/interview/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` | Measured: neither enumerates a section of either document; both point at the contracts instead |

A consuming project's own profile is a separate question and is deferred; this page and the contracts it
describes ship either way.

## Two surfaces, deliberately different in width

| Surface | What it covers |
|---|---|
| The refusal | The seven pages above, in a session that ran `/improve`, `/improve-global` or `/ai-audit` — nothing else |
| The detection | The instruction material on five named surfaces — the project profile, the method pages, the scaffolding a consuming project receives, the text the enforcement layer writes into context as a session or a tool use begins, and the checks and suites where element lists live as data. Not everything an agent reads: a tracked file outside all five is outside the detection, which is what the three named exclusions and the report's own count of unaccounted files exist to say out loud |

**Being outside the refusal is never being outside the detection — for every surface the detection
examines.** A mandate landing on an unrefused page of those five is still caught and named, as far as the
element derivation reads the page that carries it and the coverage sweep recognises the words it arrives
in; one landing on a surface that is deliberately out is not, which is why the three exclusions below are
named with their reasons and their sizes. The report says which surfaces it examined and which it did not,
because a surface that was not examined is a different outcome from one examined and found clean — and a
decision to leave a surface freely editable must not quietly also remove it from what is checked.

Three surfaces are deliberately out of the detection, and the report names each one with its reason
rather than omitting it: the plan documents themselves, which are the artefacts under these rules and
which quote principle text by construction; the learning record, where an entry is a proposal rather than
a rule; and the repository's own mechanics — what configures the repository, what declares the plugin, and
committed measurement data — where the ground is not that nobody reads them but that none of them states a
rule a spec or a design is held to. Each exclusion carries a membership rule and not only a name, so the
three together account for every tracked file that is on no examined surface, and the report counts what
neither a surface nor an exclusion claims. **That count should be zero, and a non-zero one is the report
saying nothing at all about those files.** It is the figure that would have caught eight tracked files
sitting outside both sets while every run read as clean.

## The authorisation route

**A change to a principle is two co-ordinated edits, and that is the authorisation route rather than a
hole.** The verification holds its own copy of the numbered sentences, so an edit to this page alone is
loud. Changing this page AND that copy together passes — and the diff a human reads then carries both
halves, which is exactly what "not silently" means.

| What you are changing | What it takes |
|---|---|
| The wording of a principle | Edit this page and the verification's pinned copy in the same change |
| Removing a principle | The same two edits; the verification reports an absence distinctly from a wording difference, because a vanished principle protects nothing while a reworded one still says something |
| Adding a principle | The same route, because an addition can contradict a sentence already here |
| Adding or removing a required element | Edit the page that mandates it and the record on this page; a one-sided edit is reported in whichever direction it went |
| An edit to a protected page that the refusal stops | Allow it. Allowing it lets the edit proceed, so installing or repairing this protection never requires switching it off |

**A correction recorded in the learning record never travels this route automatically.** An entry whose
remedy would change either document's composition, or change, weaken or remove a principle, is surfaced
to the author as a decision and is never converted into a diff against an instruction file. The automated
improvement pass declines such a change and says that it declined.
