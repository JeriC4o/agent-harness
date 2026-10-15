# Protect the base terms and the form of the spec and design from the self-improvement path

**Source:** ticket GH-116
**Date:** 2026-10-11
**Tracked in:** GH-116

The harness rewrites its own rule files: a correction pattern repeating in the learning record becomes a
proposed diff to the instruction surface, escalating to a hook at three occurrences of a class. **No part
of that surface is off-limits today**, so the rules that define what a spec and a design ARE — and the
rules that define what they must CONTAIN — can be rewritten by the mechanism whose job is rewriting
rules.

**A check that hunts for a principle's opposite cannot be the whole protection, and that is this task's
central correction to the ticket.** The base principles are all negation-shaped, so such a check is blind
to an **addition**: a rule saying "every design carries a list of tests with their line numbers and
expected results" contradicts no principle, leaves a contradiction hunt green, and changes the form of
the document. An addition is how the damage actually arrived.

**So the verification does not judge a sentence — it inventories statements and compares.** The
instruction material the agents read is enumerable, so the verification names the surfaces it examines
and the statements those surfaces carry are an inventory. The verification records that inventory and
compares the tree against it: is a statement new, did one disappear, did one's text change. Each answer
is reported with the statement's own text and the surface it sits on. No passage of an examined surface
is set aside as harmless, so nothing there is silenced, and an addition is caught by construction rather
than by being recognised as one. Where the examination stops is reported too — each class of file left
out is named with its reason and its size, and anything in neither the examined set nor a named
exclusion is counted and named, so the boundary is visible on the report rather than found out later.
What a change MEANS — whether it contradicts a principle, whether it adds a required element, whether
it does any harm at all — is read off that report by a human, which is the division of labour the rest
of this document already rests on.

**What is forbidden is qualified, not blanket.** The form of these documents is not frozen for all time.
What may not happen is a change to the composition of a spec or a design that **guarantees two failures
at once: invented content at the moment of authoring, and a review loop at the end that cannot
converge.** An element whose content is only determined after the document is agreed forces the author
to fabricate it; review then corrects the document against reality, reality moves on, and the correction
reopens.

**The refusal is page-wide, and that makes the breadth of the protected page set a requirement rather
than a detail.** An edit to a page that defines what either document must contain is refused until the
author allows it, whatever the edit touches — a typo fix in an unrelated paragraph is refused exactly
like a change to the required-element set. Every surplus page in that set is therefore a recurring
interruption, so the set is stated exactly below, with a reason per member and with the near misses named
and justified.

The bar this task is judged against is the ticket's own: **an edit that contradicts a base principle, or
that adds a required element to either document, turns the repository's verification red and names what
it hit.** Not "impossible to change" — impossible to change *silently*.

## Scope

1. **One document holding the base principles** as numbered, byte-stable sentences, each carrying its
   one-clause reason. The seven existing ones are reproduced verbatim under § Technical constraints.
2. **An eighth principle, of a different kind from the seven: it carries a test, not a prohibition.** A
   required element of a spec or a design must be knowable at the time the document is authored; an
   element whose content is only determined later is forbidden, because it guarantees invented content at
   authoring time and a review loop at the end that cannot converge.
3. **The enumerated set of required elements of a spec and of a design becomes protected material.** It
   is the record a reader holds a report against: an instruction that mandates an element outside that
   set turns the verification red and names the statement that mandates it.
4. **One verification over an enumerated corpus of instruction surfaces**: each principle sentence is
   present unchanged, and the statements those surfaces carry match the recorded inventory. Any arrival,
   any departure and any change of a statement's text turns the verification red and is reported with
   that statement's own text and its surface — whether it bears on a principle, on the form of either
   document, or on neither. The corpus is named in the report, and so is everything it leaves out.
5. **An automatic refusal of an edit to any page that defines or enforces a required element**, firing on
   every edit to such a page and inspecting nothing about the edit's text, and carrying what
   authorisation would permit it. The protected set is the one enumerated under § Technical constraints.
6. **Two surfaces, deliberately different in width.** The refusal covers the enumerated pages. The
   detection covers a wider enumerated corpus, which holds every page of the enumerated refusal set and
   every page of this repository named as a near miss beside it — including the text the enforcement
   layer hands the agents as a session or a tool use begins, which is instruction material they RECEIVE
   rather than open. So a mandate landing on an examined page the refusal does not cover, or in text
   that no page carries, is still caught and named. Where the detection stops is disclosed rather than
   implied: every class of file deliberately left out is named with its reason and how many files it
   holds, and any tracked file in neither the examined corpus nor a named exclusion is counted and
   named — so nothing sits outside both with the report silent about it.
7. **The self-improvement contract may not propose a change to document form at all.** A correction
   entry whose remedy would change the composition of a spec or a design, or would change, weaken or
   remove a principle, is surfaced to the author as a decision; it is never converted into a diff
   against a rule file, and the automated improvement pass proposes no such edit.
8. **The honest limit stated in the document itself** — the protection catches and names a contradicting
   or adding edit; it does not prevent one.
9. **The repository's own gate inventory stays consistent** — the new verification is both wired into
   the single entry point and named in the documented gate list, in both directions.
10. **The shipped version is bumped**, so an installed copy actually receives all of the above.

## Out of scope

- Changing the content or wording of the seven existing principles. Their text is an input to this task,
  not an output.
- Changing what a spec or a design is actually required to contain today. This task records that set and
  protects it; it neither adds to it nor removes from it.
- **Deciding from an edit's text whether to refuse it.** The refusal is page-wide by decision, with the
  prompt cost named and accepted; a narrower, content-keyed refusal was considered and rejected.
- **Refusing edits to a page that could mandate an element but today mandates none.** Such pages sit in
  the detection surface, not the refusal surface — see the near misses under § Technical constraints.
- **Widening the detection to every tracked file.** The detection is scoped to the named instruction
  surfaces — the project profile, the method documentation, the scaffolding a new project receives, the
  enforcement layer and the verification scripts. Three classes of tracked file sit outside it by
  decision, each with its reason: the plan documents of tasks, the learning record, and the repository's
  own mechanics — its configuration manifests, its ignore rules, its readme and its committed
  measurement data. This is a non-goal rather than a shortfall, and the plan documents carry the
  evidence rather than an assertion: they quote principle text by construction, as this very document
  does in reproducing all eight sentences verbatim under § Technical constraints, so a detection
  covering them is red on every task from the moment it lands. The learning record holds proposals
  rather than rules, and nothing among the repository's mechanics states a rule a spec or a design is
  held to. What the boundary costs is stated instead of hidden: a mandate planted in an excluded file is
  outside what this verification examines. That is why each exclusion is named with its reason and its
  size, and why a tracked file belonging to neither the examined corpus nor a named exclusion is counted
  and named — the boundary is a disclosed decision with a measured size, never an omission a reader has
  to detect.
- Judging, mechanically, whether a proposed new element passes the eighth principle's test, and more
  generally whether any reported change does harm. The mechanical part is that the change becomes
  **visible** and is named; the test is what a human then applies to what the verification surfaced.
- **Deciding, from a sentence's wording, whether it is a rule or a description of one.** Nothing here
  reads a sentence and rules on what kind of sentence it is: the verification knows only whether a
  statement matches the record. The evidence that this is a non-goal rather than a shortfall is under
  § Technical constraints.
- A retroactive sweep of already-approved plan documents for violations.
- Recalibrating the thresholds of the self-improvement escalation ladder.
- Protecting instruction material that defines neither a principle nor a required element of a spec or a
  design — review verdict vocabulary, the gate list itself, the learning-record entry format.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| A retroactive audit of committed plan documents against the principles and the enumerated element set | The historical corpus predates both; a red result there cannot be cleared without rewriting documents a human already approved | Yes, if wanted at all |
| Calibrating the three-occurrence escalation threshold now that a whole class of entries is routed away from it | Unrelated measurement debt, and routing a class away does not change the bar's basis | Already tracked as its own open question |
| Reach of the verification into a project that installs the toolkit, including that project's own profile | A shipped check is a different deliverable from a repository-local gate; the principles document and the contracts ship either way | Yes |

## Key decisions

| Question | Decision |
|---|---|
| Is a hunt for a principle's opposite sufficient | No, and this is the task's central correction to the ticket. The seven are negation-shaped, so an addition passes such a hunt green while changing the form of the document. An addition is the load-bearing case, and comparing a recorded statement inventory catches it without having to recognise it as either a contradiction or an addition |
| Does the verification judge a sentence, or compare two versions of one | Compare. A statement is new, gone, or textually changed — three answers a comparison gives exactly, against a question no mechanism that reads a sentence and rules on what kind of sentence it is answers reliably at this task's bar. One missed sentence is a silent landing, which is the single outcome this task exists to prevent. The published evidence for that bound, and the rules the comparison brings with it, are recorded once under § Technical constraints and not restated here |
| What the comparison costs, named and accepted | The first recorded inventory covers every surface in the detection corpus, so it is large; after it, every legitimate change to instruction material produces a report line that stands until a human reads it and the record is brought level. On the refused pages this is precision rather than new traffic — the author already approves every edit there, so the report upgrades "this page changed" to "this statement arrived". Outside the refused pages it IS new traffic, measured below, and it is accepted on the same ground as the refusal's own breadth: a surface left out of the report is a surface an addition can land on silently. What is left out is therefore left out by decision, with its reason and its size on the report, and never by a corpus nobody can see the edge of |
| What makes a change to form forbidden | Not that it is a change, but that it guarantees invented content at authoring time together with a review loop at the end that cannot converge. This is the eighth principle, and it generalises what the third already says for identifiers alone |
| Whose edits the refusal stops | **Every edit to a protected page, with no inspection of what the edit touches.** Settled by the author against a narrower recommendation, with the interruption cost named in advance and accepted. A later judgement that it is too noisy is a changed requirement travelling the amendment route, not a defect in what was built |
| Why the refusal cannot be narrowed to the automated path instead | Measured: the improvement pass only proposes diffs, and the confirmed edits are applied by the main thread itself because a spawned agent cannot edit an installed copy at all. At the instant of the write, an escalated rule change and a hand edit are the same act. A restriction aimed at the automated path can therefore live in the contract layer, where the proposal is made, but not in a refusal keyed on the file being written |
| Two surfaces, not one | The refusal covers the enumerated composition-defining pages; the detection covers a wider enumerated corpus holding all of them and this repository's near-miss pages beside them. A mandate landing on an examined page the refusal does not cover is caught and named even though its edit was not refused — the bar restated: not impossible, impossible silently. Where the detection stops is disclosed rather than implied: each class left out carries a reason and a file count in the report, and a tracked file in neither the corpus nor a named exclusion is counted and named |
| What makes a page a member of the refusal set | That it defines or enforces a required element of a spec or a design. The set is stated exactly below, and that rule is what makes membership derivable — so a page acquiring such a rule joins the set rather than becoming the unguarded route |
| Statements and element sets are compared, never counted | Measured on the one existing refusal that reads an edit's text: it counts headers and says so in its own message, which makes an in-place replacement of one header by another invisible to it. Replacing one required element with another is the same move, and so is swapping one sentence of a rule document for another. So the unit of comparison is the statement and the element, matched against the record, and never a tally of either |
| Who applies the eighth principle's test | A human. The verification makes an addition visible and names it; it does not rule on whether the addition is legitimate. The bar is unchanged: not impossible to add, impossible to add silently |
| Does a blocking review finding count as mandating an element | Yes. An element becomes required either by appearing in a document's required sections or by a review contract making its absence a blocking finding. Both routes are in the protected surface, because the second changes what the document must contain without touching any template |
| The exact text of the seven sentences | Adopted verbatim from the ticket, including each one-clause reason. Byte-stability is the point; a wording change travels the same authorisation route as a removal |
| Method surface or project profile | Method. The principles describe what a spec and a design ARE, which holds in every project, so the document ships with the toolkit rather than living in this repository's own profile |
| An indeterminate verification result | Not a pass. A verification that cannot decide reports that it could not, as an outcome distinct from both clean and red, and a caller treats it as not clean |
| Who may state a principle's text | The principles document is the single authority on the wording. Where another rule document states the same rule in its own words, the principles document governs on any disagreement |
| Why the enforcement layer is not simply refused along with the pages | The self-authorisation paradox already recorded against it among the near misses: that layer is where this task's own refusal registers, so a refusal covering it could not arrive without authorising its own arrival. The consequence is the asymmetry below, never an exemption — the layer stays OUT of the refusal and INSIDE the detection. Measured: the same answer covers every other enforcement-layer text for the same reason: none of it mandates an element today, and the inventory records that surface as it stands, so admitting all of it to the detection costs nothing at landing. What it costs afterwards is one report line per later change to it, named with the rest of the cost above |

## Technical constraints

**The seven existing sentences, verbatim — this is the text the protection is about.**

1. **One writer per artefact.** The orchestrator writes neither a spec nor a design; each is written only
   by its owning subagent. *Because a party that both writes a document and reports on it can close a
   finding by editing the evidence.*
2. **A spec is a behaviour contract, not an implementation plan.** A criterion may not spell a command,
   script, tool or test identifier. *Because a criterion naming its instrument asserts which instrument
   ran, not what the system does, and cannot survive a change of instrument.*
3. **A design states verification intent, never an identifier**, and the concrete check set lives outside
   the frozen base. *Because identifiers are chosen while the tests are written, after the document is
   agreed, so a document promising them diverges by construction.*
4. **The design is frozen at the design-review GO verdict.** After it, a divergence that does not break
   the agreed approach is a marker plus a log row, never a rewrite. *Because re-verifying an unchanged
   document every round is the cost this replaced.*
5. **A changed requirement goes to the spec; a changed artefact goes to the log; nothing is recorded in
   both places.** *Because two records of one fact is the drift the mechanism exists to reduce.*
6. **Neither document carries a record of superseded material, and no verdict may require one.** *Because
   every such passage is read in full by every later whole-repository review and none of it describes the
   system.*
7. **The closing fold runs once, after approval.** It authors the design afresh and collapses the spec to
   its record of deliberate absence. *Because an in-place edit leaves every sentence the editor did not
   touch, and what it does not touch is what nobody re-read.*

**The eighth, new and of a different kind — a test rather than a prohibition.**

8. **A required element of a spec or a design must be knowable at the time the document is authored.** An
   element whose content is only determined later is forbidden. *Because it guarantees two failures at
   once: invented content at authoring time, and a review loop at the end that cannot converge — the
   document is corrected against reality, reality moves on, and the correction reopens.*

**The generative case, measured rather than imagined.** The damage was a rule mandating, inside the
design, a per-test list carrying line numbers and expected results. Those identifiers do not exist when
the design is authored, so the author fabricated them; review then corrected the document against the
tree, the tree moved, and the correction reopened. The corrected form of exactly this rule is live today:
the design's per-criterion verification line states the verification intent and may not name a test
method, a file path or a command, and the concrete command, identifier and path are recorded outside the
design in a per-round section so they cannot falsify the frozen base. The eighth principle is that
correction stated as the general test.

### The protected page set — exactly, with a reason per member

**Measured rather than assumed.** A sweep of the instruction surface for either document's section
names, its mandatory-element rules and its blocking-absence rules returns **seven file paths**. The
arithmetic is not the finding. The finding is that the element lists are not only prose: they are also
carried **as data inside the verification that enforces them**, where a sweep of prose cannot see them.

**Why the paths appear in a spec at all.** Which pages interrupt an author is observable from outside and
was settled as an author-level decision, so this set is the requirement itself and not an implementation
choice. The role column is what keeps membership derivable if a path moves; the criteria below name no
path, only the rule that decides membership.

| Page | What about it defines or enforces a required element |
|---|---|
| The spec author's contract — `agents/spec-writer.md` | Enumerates the spec's required sections as a template, and separately states what a criterion may and may not contain. Both are composition |
| The design author's contract — `agents/design.md` | Enumerates the design's required sections as a template; mandates two further elements in its rules rather than in that template (a handoff plan for every decomposition, a verification line for every criterion); and names which spec sections survive the closing fold. Four loci in one file, and the measured damaging edit was of exactly this class |
| The design reviewer's contract — `agents/design-review.md` | Makes the absence of named elements a blocking finding under its own severity rubric. The quieter of the two routes to a new requirement: an element becomes mandatory here with no template changing anywhere |
| The closing fold's contract — `skills/redline-fold/SKILL.md` | Names the spec sections retained byte-identically and the design headings allowed to survive, so it defines what both documents contain after the fold |
| The task workflow's entry point — `skills/task/SKILL.md` | Its binding step rule requires the design's handoff-plan section to exist in order to operate at all |
| The task workflow's reference — `skills/task/reference.md` | Its step-gate checklists assert the presence of individual sections before a step may close; an element asserted there is required in practice whatever the templates say |
| The mechanical enforcer — `scripts/check-redline.sh` | Carries the retained-spec-section list, the surviving-design-heading list, the per-criterion verification-line requirement and the criterion-content rule as data. Widening a list here adds a required element without touching one word of prose |

### The near misses — pages that touch document composition and are deliberately left out

| Page | Why it is out |
|---|---|
| The in-task repository reviewer — `agents/self-review.md` | Reads only the criteria list from the spec, and reads the per-round check record for content. It mandates no element of either document today. It is also the most-edited of the candidate agent contracts, so admitting it on its capability alone would buy no protection at the highest price of any candidate |
| The post-merge repository pass — `agents/review-findings.md` | Makes an uncovered verification intent a blocking finding, which is about the coverage of an element already required rather than about requiring a new one |
| The per-round working record's format — `docs/templates/progress-format.md` | Defines the composition of the round record that deliberately sits OUTSIDE the frozen base, and is the sanctioned home for the identifiers the third principle keeps out of the design. Protecting it guards the relief valve, not the documents. It sits inside the detection surface, so removing the section that is the sanctioned home for those identifiers is reported as a statement departing rather than passing unseen — leaving it out of the refusal buys back an interruption and costs no blind spot |
| The method root — `docs/agents-method.md` | Measured: a sweep of the whole method-documentation directory for any section name of either document returns nothing, so it defines no element — and it is the single most-edited file in the tree |
| The enforcement layer — `hooks/hooks.json` and the shared code behind it under `hooks/lib/` | Out of the REFUSAL set, and out of that set only. Both mandate no element of either document today (measured below), and this is where this task's own refusal registers, so refusing edits here would make the protection unable to arrive without authorising its own arrival. The text this layer emits is instruction material the agents read, so it is INSIDE the detection surface. Whether the refusal's own registration is guarded against later removal is an open question below, with an in-tree precedent named |
| The verification suite's fixtures — `scripts/test-check-redline.sh` and its siblings | They reproduce both documents' section names as fixture text. A fixture asserts nothing about what a real document must contain, and the fixtures change with every change to the checks |
| The interview orchestration and the workflow description — `skills/interview/SKILL.md`, `docs/workflow.md` | Measured: neither enumerates a section of either document; both point at the contracts instead |
| A consuming project's own profile | Deferred above; a shipped check is a different deliverable from a repository-local gate |

**What the boundary buys, as a measured proxy.** Read every number as a lower bound: it counts commits
in this repository's 152-commit history that touched a path, and the refusal fires per EDIT, of which
one commit can carry several. Per path, the seven protected members: 4, 4, 3, 2, 8, 7, 2. The seven
pathed near misses, in the order of the table above: 9, 7, 5, 20, 23 for the enforcement layer's
registry and shared code together, 2, and 12 for the two orchestration files together. The comparison
that means anything is the UNION of the commit sets, because one commit touches several of these paths:
**13** commits touched the protected set against **37** for the pathed near misses. Both unions are
measured over exactly the paths the two tables above name, with the enforcement layer read as its
registry plus the whole shared-code directory, that directory's own test scripts included — the one
boundary choice either figure is sensitive to, so naming it is what lets the next reader reproduce the
numbers rather than re-derive the path set. So the boundary as drawn interrupts **roughly a third** of
the traffic the widest defensible set would have interrupted — a third on that union basis, and nearer
two fifths if per-path counts are summed, which double-counts every commit spanning two paths. That
ratio is the whole reason the set is specified here rather than left to the implementation.

### What the comparison may rest on, and what no mechanism may be asked to decide

**Evidence from published work outside this repository, recorded here because it bounds the whole design
space rather than merely informing it.**

- **A sentence that CHANGES a rule system and a sentence that DESCRIBES one cannot be told apart
  reliably.** The distinction is real — prescriptive against descriptive modality — but within natural
  language no sharp demarcation between normative and descriptive speech can be drawn. A protection
  whose bar is "nothing lands silently" may not rest on that distinction being decided for it, and a
  mechanism asked to decide it cannot be tightened to completion: there is no boundary for it to
  converge on.
- **Selecting rule sentences by the modal verbs they carry is insufficient in both directions**: some
  rules carry no modal verb, and some sentences that are not rules do. The same work records that
  heuristic methods of this family are inevitably incomplete, hold only on input restricted to one
  format or style, and are usually not evaluated over a broad input range. A learned replacement for
  that baseline measured about 16 points of precision and 25 points of recall above it, which is the
  size of what the baseline leaves on the table.
- **No approach of that family reaches zero misses.** The best reported classifiers of obligation
  sentences sit near 0.90 accuracy on contract text, with annotation precision reported up to about
  95.9%. So a criterion whose bar is "impossible to violate silently" cannot rest on a classifier at
  all — neither one built here nor a better one bought elsewhere.

**The proven architecture for this shape of problem is version comparison, and the rules it comes with
are binding here.** Segment each surface into statements, align the tree against the recorded inventory
by exact match first and by similarity only where exact match fails, and report the change map. Three
rules travel with it:

- **A similarity judgement may only ALIGN two versions of a statement.** It never casts the deciding
  vote on whether a change is present or whether it matters.
- **A judgement about whether one statement entails another is EVIDENCE put in front of a human, never
  the arbiter** — and where it is taken at all it is taken in both directions.
- **The deterministic comparison takes PRECEDENCE.** A disagreement between it and any judgement layer
  is surfaced in the report rather than resolved silently, and every reported line is traceable to the
  rule that produced it.

**This repository adds one constraint of its own, and it is the binding one: the verification runs before
a commit, so it must return the same verdict on the same tree without a network call.** A dependency on a
hosted model would pin a model version as data and introduce a threshold nobody here can calibrate. The
exact-match comparison needs no model at all, which is why it is the whole of what this task delivers; a
semantic layer is optional, is not delivered here, and if it is ever added may only surface evidence
beside the deterministic result.

**The unit of comparison is the statement, and its spelling is part of the contract rather than an
implementation detail.** A statement is one sentence, one list item, or one clause the author separated
with a semicolon, read as whitespace-normalised text joined across the lines of a hard-wrapped
paragraph — so re-wrapping a paragraph is not a change to the inventory while re-writing a sentence is.
Measured in this corpus: these documents hard-wrap, and a unit evaluated line by line is evaluated on a
wrap fragment.

**Constraints the tree imposes on how any of this can land.**

- **Refusals on both edit shapes already exist here.** The hook surface registers before-use refusals on
  the file-editing tools, on shell commands, on skill invocation and on every tool, so a refusal targeted
  at a file is a working shape and an edit applied through a shell command is coverable too.
- **The enforcement layer does not only refuse — it also SPEAKS, and this is measured rather than
  assumed.** Of the 20 registered session-start and before-use arms, 12 write prose into the model's
  context in their own text, and more do it through the 11 shared scripts they call. This is not a
  hypothesis about the mechanism: this very task's session opened with such a message instructing the
  main thread to read the method rules and the project profile before its first tool call, and every
  subagent start carries one too. So a rule of the form "every design carries this element" could live
  there, reach every agent that starts, and never appear on any page — which is why that text sits
  inside the detection surface. **Measured today, nothing there mandates an element of either
  document:** a sweep of every tracked executable under the enforcement and verification directories
  for either document's section names returns two paths — the mechanical enforcer already inside the
  protected set, and its own fixtures already named a near miss — and the only enforcement-layer prose
  mentioning a spec or a design at all governs who may START the workflow, not what either document
  contains. So admitting this surface costs nothing at landing: the record is the tree as this change
  leaves it, which is what makes a clean result there achievable rather than aspirational.
- **What a comparison costs after landing, measured on the same basis as the refusal's breadth.** Every
  legitimate change to instruction material produces a report line, and the line stands until a human
  has read it and the record has been brought level. On the refused pages that costs no new
  interruption — the author is already stopped on every edit there, so the report refines what the
  interruption says. Outside them it is traffic that nothing stops today, and the commit history gives
  its order: of 152 commits, the method root alone accounts for 20 and the enforcement layer for 23, and
  the union over the pathed near misses is 37. Read that as the order of the traffic and not its
  ceiling, because the detection surface is wider than the set those figures were measured over.
- **A refusal that reads an edit's text is also a working shape here, and its recorded bound is the
  warning this task must heed.** One existing refusal already decides on an edit's content rather than
  only its path. Its own message records that it COUNTS headers, so an in-place replacement of one header
  by another is invisible to it. The verification still needs content awareness even though the refusal
  no longer does, and it must compare statements and elements against a record rather than count either.
- **The pre-commit verification list is self-inventorying in both directions.** The single entry point
  derives its member set from the tree and cross-checks that derived set against the gate list recorded
  in this repository's profile — so a new member that is documented-and-unwired, or wired-and-
  undocumented, reddens the inventory. Exactly one verdict per member is required, so a member wired to
  another member's work leaves both totals unchanged and is caught.
- **The rule corpus deliberately quotes its own superseded wording and its own negative examples.** Any
  sweep for a principle's negation, or for a mandate outside the enumerated set, will land on those
  quotations. This is measured, not feared: the repository's existing form check records that "a fragment
  search for superseded material is actively misleading, not merely weak: a document that records its own
  corrections holds the superseded wording inside a quotation, so an absence proved from a fragment is a
  false positive." A comparison has no such exposure, and this is the strongest single reason the
  verification compares statements instead of searching for forbidden phrasings: a quotation already in
  the record is silent, and a quotation that arrives is reported with its text like anything else, for a
  human to read.
- **Byte-identity plus absence-checked-separately has precedent here.** The repository's reference check
  byte-compares the scaffolded learning-record contract against the live one, and reports a missing copy
  as a different finding from a divergent one — because a missing copy ships no contract at all, which is
  the worse case and the one a divergence check alone passes silently.
- **Deriving a refusal's coverage from the table that defines it also has precedent here.** One existing
  check derives the classes a reminder must fire on from the rule table beside it and asserts the
  registered arms agree in both directions, catching "the table gained a class and the refusal never
  learned about it". That is the shape the refusal-set agreement requirement can be met with.
- **Restating a rule that also lives in another rule document creates a propagation obligation.** This
  repository's propagation rule requires a named sync group — an anchor row naming every member plus one
  back-reference row — for a mechanism described in more than one file's vocabulary, because a sweep keyed
  on a changed token cannot reach a file that describes the same mechanism in different words. The
  propagation reminder's path classes are derived from that table and asserted by a check, so adding a
  group means re-running that check and reading the member count it reports, not only its status.
- **Plugin-loaded content requires a version bump in the same change**, because the install cache is
  keyed by version and an unbumped fix reaches nobody while reporting success.
- **This change edits protected pages while installing the protection.** Five of the seven members are
  plausible targets of this task's own work, so the authorisation route has to be usable by the author
  who is landing the protection, not only by a later one.

**One correction to the ticket's account.** The hazardous instruction the ticket blames was rewritten,
not removed: the spec author's contract still carries a bullet about turning a stated definition of done
into a permanent obligation, now explicitly qualified with "write the obligation, never the instrument".
The dangerous half — recording a machine-checkable guard IN the spec — is gone. This matters for the
second principle's protection: the surviving bullet is exactly the text a future escalation would
re-corrupt rather than have to re-invent, so it is inside the blast radius the contradiction half must
cover.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Each base principle is readable as a single numbered sentence carrying its one-clause reason, in one document that ships to every project installing the toolkit. |
| AC2 | That document carries the authoring-time test as a principle in its own right: a required element of a spec or a design whose content is only determined after the document is authored is forbidden, and the sentence names both failures it guarantees — invented content at authoring time, and an end-of-task review loop that cannot converge. |
| AC3 | Changing the wording of any one principle, with nothing else edited, turns the repository's pre-commit verification red, and the failure names which principle changed. |
| AC4 | Deleting a principle turns the verification red, and the failure reports it as an absence — a distinct outcome from a wording difference, because a vanished principle protects nothing while a reworded one still says something. |
| AC5 | Adding, to any rule document the agents read, a sentence asserting the opposite of a principle turns the verification red and puts that sentence's own text and the surface it landed on in front of a reader, so the contradiction cannot land unseen. Whether a reported sentence contradicts a principle is that reader's judgement; the verification reports the arrival, never a ruling on what the sentence means. |
| AC6 | The elements a spec and a design are required to contain are enumerated as protected material, and an instruction that mandates an element outside that enumeration turns the verification red and names the added element — including when it contradicts no principle, which is the case a contradiction hunt passes green. |
| AC7 | The verification's input is an enumerated corpus of named surfaces, wider than the enumerated set of pages the refusal protects and holding every one of those pages, so a mandate landing on a page that is examined but not refused is caught and named rather than falling into a gap between the two surfaces. What the corpus leaves out is not left to be discovered: every tracked file belonging to no examined surface is claimed by a named exclusion, and a tracked file claimed by neither is counted and named in the report, so a file this verification says nothing about cannot be carried silently. That count is a measurement of the tree rather than a constant — a tracked file in neither set moves it. |
| AC8 | An element made mandatory without any document template changing — by a review contract treating its absence as a blocking finding — is detected the same way and reported as an addition, so the quieter of the two routes to a new requirement is not the unguarded one. |
| AC9 | An addition landing in the instruction that tells the design author what to write is caught, not only one landing on the page that lists the principles, demonstrated against the shape of the edit that caused the measured damage. |
| AC10 | An edit that replaces one required element with another, leaving the number of required elements unchanged, is reported as an addition naming the element that arrived — so the one change a count of elements cannot see is not a change the verification cannot see. |
| AC11 | Every statement that arrived, departed, or changed its text is reported and named, with its own text and the surface it sits on, and on a changed statement with what it said before. No region of an examined surface is exempt: there is no class of passage the verification treats as harmless and leaves out of the report, so a change cannot be absent from the report for any reason other than not having happened. Whether a reported change does harm is a reader's judgement on that report. |
| AC12 | The verification reports, beside its verdict, how many surfaces it examined, how many statements it compared, and how many principles and enumerated required elements it found, so a run that silently examined fewer surfaces or compared fewer statements than the corpus holds is distinguishable from a clean one. |
| AC13 | A run that could not complete reports an outcome distinct from both clean and red, and whatever consumes that outcome treats it as not clean. |
| AC14 | The verification is clean over the repository as this change leaves it, so a later red result identifies an edit somebody made rather than material the corpus was already carrying. A change a reader has read and accepted can be taken into the record, after which the verification is clean again — so the verification has a steady state rather than turning red at the first legitimate change and staying red. |
| AC15 | An edit to a page that defines or enforces a required element of a spec or a design is refused until the author allows that edit, whatever the edit touches: a change to a paragraph with no bearing on either document's composition is refused exactly as a change to the required-element set is, and the refusal names the page and what would permit the edit. |
| AC16 | The set of pages the refusal covers and the set of pages that actually define or enforce a required element agree in both directions: a page carrying such a rule while uncovered is reported, and so is a covered page carrying no such rule — so neither an unguarded route nor a surplus interruption can sit there unnoticed. |
| AC17 | The author landing this protection can authorise an edit to a protected page and proceed, so installing the protection is possible without disabling it. |
| AC18 | A correction entry in the learning record whose remedy would change the composition of a spec or a design, or would change, weaken or remove a principle, is surfaced to the author as a decision and is not converted into an edit to any rule document; the automated improvement pass declines such a change and says that it declined. |
| AC19 | The principles document states the limit of what it achieves: a contradicting or adding edit is caught and named, never prevented. |
| AC20 | The repository's documented gate list and the list its single entry point actually runs agree in both directions after this change, so the new verification can be neither documented-and-unwired nor wired-and-undocumented. |
| AC21 | The shipped version of the toolkit is higher after this change than before it, so an already-installed copy receives the protection rather than reporting a successful update that changes nothing. |
| AC22 | A mandated element is caught whether the agents read it on a page they open or receive it in text handed to them as a session or a tool use begins. Starting from a tree the verification finds clean, a rule requiring a new element of a spec or a design that is carried only in text the agents receive — never written on any page they open — turns the verification red and names the added element, exactly as a mandate added to a page does. |
| AC23 | What was examined and what was not is stated in the report rather than left to inference. Every surface of the corpus is listed with its outcome, so a surface dropping out of what is examined cannot read as a clean result, and a surface that was not examined is distinguishable from one examined and found clean. Each class of file deliberately left out is listed in the same report with the reason it is out and how many files it holds — so leaving material unexamined is a disclosed decision with a size, and an exclusion can be neither unreasoned nor unsized nor invisible. |

## Open questions

- **Whether the refusal's page set is maintained as a list or derived from the pages themselves.**
  Precedent exists both ways in this tree, and AC16 constrains the answer without choosing it: a
  maintained list must be cross-checked against the tree in both directions, which is what the
  derived-arms precedent already does for another refusal.
- **How an accepted change is taken into the record.** AC14 states the property — the record can be
  brought level with a change a reader accepted, so the verification has a steady state — and
  deliberately not the route. A defensible default exists and this is the design's choice.
- **Whether the record the comparison reads is itself guarded against being brought level in the same
  pass as the change it would have reported.** On the refused pages the exposure is already closed, since
  no edit there lands without the author being stopped. It is open on the surfaces outside that set,
  where a change and a matching record update in one pass report nothing. The route to closing it is the
  derived-arms precedent named above; left open with that route recorded, as the same residual class as
  the refusal's own registration below.
- **Whether the refusal's own registration is protected against later removal.** Left open because the
  enforcement layer is deliberately outside the refusal set, and because the derived-arms precedent
  above is an available route if it should be. The comparison reports a departure as readily as an
  arrival, so a refusal whose own message sits inside the examined corpus does not go quietly — but
  whether it sits there is the design's to settle, and a registration carrying no text of its own is not
  reached that way. Revisit if an arm is ever found missing.
- **Whether a contradiction or an addition found in a consuming project's own profile is in remit.**
  Deferred above; the principles document and the contracts ship regardless.
- **How a ninth principle is admitted.** The same authorisation route as changing one, because an
  addition can contradict a sentence already there. Revisit when one is actually proposed.
