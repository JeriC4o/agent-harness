# Protect the base terms and the form of the spec and design from the self-improvement path

**Source:** ticket GH-116
**Date:** 2026-10-11
**Tracked in:** GH-116

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

