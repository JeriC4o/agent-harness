# Escalation channel from a consuming project back to the harness

**Source:** ticket GH-29
**Date:** 2026-09-24
**Tracked in:** GH-29

## Problem

A project that hits a defect **in the harness itself** has no route to report it. The only existing
project→harness path is `ai-docs/learnings/.promote/`, swept by `scripts/collect-candidates.sh` through
`~/.claude/harness/registry.json`, and it is the wrong shape three times over:

1. **Same-machine only** — the sweep reads local paths from a local registry.
2. **Wrong payload** — it carries abstracted RULES, not defect REPORTS. `scripts/check-candidate.sh`
   refuses any file path outside a small permit-list, so a report naming a harness script is refused *by
   construction*.
3. **Wrong trigger** — promotion is gated on ≥2 distinct projects plus a human running
   `/harness:improve-global`.

Live evidence: a `/harness:inspect` run found three defects in the inspection path plus a non-executable
entry point. All four were found INSIDE the harness repository, where filing is one command. From a
consuming project, none of them had a route home.

## Scope

1. **A second MODE of the existing redaction gate `scripts/check-candidate.sh`** that permits the
   harness's own paths while keeping every project-identifier check intact, and that checks the
   REPORT's required sections instead of the rule-shaped ones.
2. **A skill, shipped with the plugin**, that drafts a defect report into a local file inside the
   consuming project, runs it through that gate, shows it to the user, and — on explicit approval —
   files it with `gh issue create` against the repository named in the plugin manifest.
3. **The report carries the installed plugin version and an idempotency hash**, both read/computed at
   runtime. A `file:line` means nothing without a version; the hash is what stops the same project
   filing the same report twice.
4. **Every issue this channel files is marked as channel-filed**, so the channel's corpus can be
   selected later for harness-side triage.
5. **Failure is loud.** When `gh` cannot reach the repo, the local report file stays on disk AND the
   report text is printed for the user to paste manually. A channel that fails silently is not used
   twice.
6. **Tests for the new gate mode** in `scripts/test-promotion.sh`, including a positive control.
7. **A new documented project-data root `ai-docs/feedback/`** for the local report file, registered in
   `check-references.sh`'s `DOC_ROOTS` and mirrored into `docs/agents-method.md` § Agent Docs.

> **Withdrawn in round 3: a corpus-wide `check-references.sh` guard against hardcoded repository
> URL / owner / version in method files.** See Deferred for the full reasoning, which is recorded so it
> is not re-argued.

## Out of scope

- Wiring `/harness:inspect` and `/harness:ai-audit` to produce reports automatically. That comes after
  the channel exists and has been used at least once.
- **Any similarity search on the filing side.** Recognising that several projects hit one underlying
  defect is CLUSTERING, it is semantic, and it cannot be solved where the filing happens: a consuming
  project does not hold the harness's issue corpus. It belongs to harness-side triage and is out of
  this increment by construction. Do not spend an AC on searching before filing.
- Any change to the existing `.promote/` rule-promotion channel's behaviour in its default mode.
- Reading or changing `~/.claude/harness/registry.json`; this channel is registry-independent.
- **Any new `check-references.sh` leg about hardcoded repository URL / owner / version.** Withdrawn
  in round 3 — see Deferred.
- **Editing the two pre-existing hits found while scoping that guard** —
  `skills/harness-init/scripts/scaffold.sh:3` (bare repository name in a comment) and
  `skills/harness-init/SKILL.md:88` (`"harness_version": "0.1.0"` in an illustrative registry JSON
  block). With the guard withdrawn these are **no longer findings**. They need no edit in this task and
  are not left dangling as open questions.

## Deferred

- **A guard against a hardcoded harness VERSION in a method file** | The round-3 decision, recorded so
  it is not re-argued: the two-surfaces rule protects against a method file making assumptions about the
  CONSUMING project — its language, build tool, domain entity, ticket prefix. **The harness's own
  repository is not a fact about a consuming project**; it is the identity of the plugin the user chose
  to install from that forge. Someone who installs from a GitHub source has no problem with reports
  going back to that same source. So a hardcoded repository URL is an **EXCEPTION, not a violation**,
  and a guard against it defends a breach that does not exist. With the URL exempt, only the version leg
  would remain, covering a mild documentation-drift hazard at the cost of a script leg, a test leg and
  rewriting an illustrative example — which does not earn two files in this increment. | no ticket yet;
  raise one only if version drift is ever observed in practice.
- Harness-side semantic clustering over the channel-filed corpus | needs the corpus to exist first, and
  is a harness-side concern, not a filing-side one | **yes, separate harness-side ticket.** Note for
  whoever writes it: GH-15 argues against a vector index, but that argument is about CODE SEARCH, where
  a silent miss yields a wrong conclusion. Here a false cluster is visible and cheap to correct, and a
  missed cluster merely yields a duplicate issue — which is today's behaviour. **The GH-15 reasoning
  does not transfer automatically** and must be re-argued on this problem's own terms.
- Auto-generating reports from `/harness:inspect` and `/harness:ai-audit` findings | the channel must
  exist and be exercised once first | yes, separate ticket after this lands.
- Any back-channel from the harness to the reporting project (status of the filed issue) | not needed
  for the first increment; `gh issue create` returns a URL the user can follow | no ticket yet.

## Key decisions

| Question | Decision |
|---|---|
| Issue-create vs PR into a feedback directory | **Issue-create** (`gh issue create`). Pre-decided in the ticket; do not re-open. |
| Second gate vs second MODE of the existing gate | **Second MODE** of `scripts/check-candidate.sh`. Pre-decided in the ticket; do not re-open. |
| How the skill is delivered | **Shipped in the plugin.** No scaffolding into the project, no profile override. |
| **Why the repository URL and version are READ at runtime rather than written into the skill** | **FORK CORRECTNESS — this is the load-bearing argument, and it is not a purity argument.** A hardcoded upstream URL sends a fork's reports to somebody else's repository. Reading `repository` from the installed `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` follows the fork automatically. The same read supplies `version` for scope item 3. (Both fields verified present — see Technical constraints.) This reason survives the withdrawal of the corpus guard and is why the mechanism stays. |
| Is a hardcoded harness repository URL in a method file a two-surfaces violation | **No — it is an exception.** The harness's own repository is not a fact about a consuming project. See Deferred for the full reasoning. The runtime read is kept for fork correctness, not because a literal would breach the rule. |
| Required sections of a defect report | **Symptom / Repro / Expected / Surface / Evidence.** `Surface` names the harness `file:line` — the whole point of the path permit — and `Evidence` carries what was observed. The report arrives already triaged rather than as a bare complaint. The new gate mode enforces these structurally. |
| Which harness paths the new mode must newly permit | `scripts/` and `.claude-plugin/` only — see Technical constraints; `hooks/` already passes today. A two-entry widening. |
| Do the project-identifier checks survive in the new mode | **Yes, all of them** — derived vocabulary (project dir name, registry name, ticket prefix, `ai-docs/context.md` entity headings, `deny-extra.txt`), the `KEY-123` structural check, and the URL-host check. Only the file-path permit and the section list change. |
| **Is the path permit a bare name match, or an existence check** | **An existence check (or an equivalent tightening) is REQUIRED — not an option design may refute.** A naive widening of the permit alternation was measured and it leaks project paths; see Technical constraints for the fixture triple. Design may substitute a different mechanism only if that mechanism reproduces the same three fixture verdicts. |
| How duplicate filing is prevented | **An idempotency hash carried in the report**, computed locally. Deterministic, no search, no recall/precision tradeoff. This solves IDEMPOTENCY (do not file the same report twice from the same project) and is explicitly NOT an attempt at clustering. |
| How the channel-filed corpus is selected later | Every filed issue carries a **stable marker** — a title prefix and/or a label. Default for design to defend: a **title prefix**, because it always works, whereas `gh issue create --label` errors when the label does not exist in the target repo, and scope item 5 requires failure to be loud rather than routine. A label may be added best-effort on top. |
| What the skill does when the gate refuses the drafted report | **Abort immediately**, naming the offending term, leaving the local file on disk. Not for convenience: an agent that rewrites its own report until the gate stops complaining is optimising AGAINST the gate, which `.promote/README.md` forbids in as many words. A gate the drafter may iterate against stops being a boundary. **Required mitigation so abort is rare rather than routine:** the drafting step knows the project name and ticket prefix and MUST write generically from the start. |
| Is a report ever filed without the user seeing it | **No.** The `.promote/README.md` doctrine holds: the boundary is a file selector, not a judgement call, and nothing crosses silently. |
| Where the local report file lives | **`ai-docs/feedback/`** — its own documented project-data root, registered in `DOC_ROOTS` and mirrored into `docs/agents-method.md`. **Not under `ai-docs/learnings/`**: that root carries rule-shaped payloads, and GH-29 names "it becomes a second learnings channel" as a risk to avoid. The name becomes sticky once it is scaffolded into consuming projects, so it is chosen deliberately here rather than left to design. |
| Local report file: committed or gitignored | **Committed with the project** (default, mirroring `.promote/README.md` lifecycle step 3 — the candidate is the evidence the report has a source). |

## Technical constraints

- **Two surfaces.** A file under `docs/`, `skills/`, `agents/`, `rules/` is METHOD and may not name a
  language, build tool, domain entity, or ticket prefix (AGENTS.md § Project-specific conventions). The
  harness's own repository identity is an **exception** to this (see Key decisions / Deferred), so the
  skill is not *forbidden* to name it — but it must still **read** `repository` and `version` at runtime
  for fork correctness. Verified present in `.claude-plugin/plugin.json` on 2026-09-24: `repository`
  (`https://github.com/JeriC4o/agent-harness`) and `version` (`0.1.17`). The literal-vs-read
  distinction therefore governs **only what the skill itself does** — there is no corpus-wide guard in
  this increment.

- **Verified 2026-09-24 against the live gate** (fixture run of `scripts/check-candidate.sh`):
  | Path in a candidate | Verdict today |
  |---|---|
  | `scripts/session-events.sh` | REFUSED — `file path` |
  | `.claude-plugin/plugin.json` | REFUSED — `file path` |
  | `hooks/lib/harness-managed.sh` | PASSES (the permit-list already carries `hooks/`) |
  | `skills/inspect/SKILL.md` | PASSES |
  So the widening is exactly `scripts/` and `.claude-plugin/`. Note `.claude-plugin/` is NOT covered by
  the existing `\.claude/` permit pattern.

- **MEASURED: the naive widening leaks project paths — this is a result, not a hypothesis.** The permit
  is an *unanchored substring alternation*, not a leading-segment match: the check greps the extracted
  path token against `ai-docs/|\.claude/|docs/|skills/|agents/|rules/|hooks/|templates/`. Adding
  `scripts/` to that alternation was measured on 2026-09-24 against three fixtures:
  | Fixture | Verdict under the naive widening | What it proves |
  |---|---|---|
  | `scripts/session-events.sh` | PASSES | the intended target is admitted |
  | `myproject/scripts/deploy-prod.sh` | **PASSES — leaked** | a PROJECT path is admitted; the defect |
  | `server/core/Merge.kt` | REFUSED | **negative control**: the check is still refusing, so the other two verdicts are not a blanket pass |
  The unanchored alternation is the cause. A tightening is therefore **required for the mode to be
  admissible at all**. The named candidate is: additionally require the named file to **exist under
  `${CLAUDE_PLUGIN_ROOT}`**, converting the permit from a name match into an existence check. Design
  may substitute an equivalent (e.g. anchoring the alternation at the start of the token) only if it
  reproduces all three verdicts above with the middle row flipped to REFUSED.

- **The existence check is feasible from a consuming project — verified.** `${CLAUDE_PLUGIN_ROOT}` at
  filing time is the installed plugin directory, and the installed copy was confirmed on 2026-09-24
  (install `0.1.12`) to ship `scripts/`, `.claude-plugin/`, `hooks/`, `docs/` and `skills/`, with
  `scripts/check-candidate.sh` itself among them. So an existence check does **not** refuse legitimate
  reports about `scripts/` from a consuming project. This removes the one way the required tightening
  could have been unimplementable.

- **Project-data roots are a closed, mirrored list.** `check-references.sh`'s `L4` refuses any bare
  `ai-docs/…` path in a method file that is not in `DOC_ROOTS`, which today is exactly
  `ai-docs/context.md ai-docs/plans ai-docs/bugfix ai-docs/learnings.md ai-docs/learnings`, and
  `--audit-roots` proves that list mirrors `docs/agents-method.md` § Agent Docs. The skill is a method
  file and names `ai-docs/feedback/`, so that root **must** be added to `DOC_ROOTS` **and** to the
  method doc, or `L4` refuses the skill itself.

- **The gate's structure check is rule-shaped, not report-shaped.** It currently requires frontmatter
  plus `**Rule:**`, `**Why:**` and `**Signal:**`. The new mode must check the report's own required
  sections instead, and a report missing one must still be REFUSED — same "never promoted half-read"
  principle.

- **`.promote/README.md` doctrine applies unchanged:** the boundary is a file selector, not a
  judgement call; a candidate is never written silently; a refusal names the offending term and the
  response is to rewrite, not to argue with the gate.

- **Tests** live in `scripts/test-promotion.sh`. They need a **positive control**: a project identifier
  must still be REFUSED in the new mode. Proven by an asserted refusal, not by reading the code. A mode
  that permits everything is not a mode.

- **Any PR touching plugin-loaded content bumps `.claude-plugin/plugin.json`'s patch version**
  (AGENTS.md § Project-specific conventions).

- **`gh` is the review surface** for this repo; the skill may assume `gh` is the tool but must handle
  its absence/failure per scope item 5.

## Acceptance Criteria

> AC13–AC16 belonged to the corpus-wide hardcode guard withdrawn in round 3. The numbers are left
> vacant rather than reused, so references made during the interview still resolve.

| # | Criterion |
|---|-----------|
| AC1 | In the new mode, `scripts/check-candidate.sh` exits 0 for a report naming `scripts/session-events.sh` and for one naming `.claude-plugin/plugin.json`; in the default mode both still exit 1 with a `file path` finding. |
| AC2 | In the new mode, every project-identifier refusal still fires: project directory name, registry `name`, ticket prefix, a `KEY-123`-shaped token, an `ai-docs/context.md` entity heading, a `deny-extra.txt` term, and a URL host each produce exit 1. Asserted per class by an observed refusal (positive control), not spot-checked. |
| AC3 | In the new mode, a report missing any of Symptom / Repro / Expected / Surface / Evidence is REFUSED with a `structure` finding. |
| AC4 | The default mode's existing behaviour is unchanged: `scripts/test-promotion.sh`'s pre-existing cases pass untouched. |
| AC5 | **The permit-leak fixture triple.** In the new mode the gate returns: `scripts/session-events.sh` → PASS; `myproject/scripts/deploy-prod.sh` → **REFUSED** (the leak measured under the naive widening is closed); `server/core/Merge.kt` → REFUSED (negative control — proves the first row is not a blanket pass). All three asserted in `scripts/test-promotion.sh`. |
| AC6 | `scripts/test-promotion.sh` covers AC1–AC5 and exits 0. |
| AC7 | The skill writes the drafted report to a local file under `ai-docs/feedback/` in the consuming project and runs the gate against it before showing it to the user. No issue is filed without the user's explicit approval of the shown text. |
| AC8 | When the gate refuses the draft, the skill aborts without retrying, prints the gate's offending term, and leaves the local file on disk. No rewrite-and-recheck loop exists in the skill's instructions. |
| AC9 | The filed report contains the installed plugin version and the idempotency hash, both obtained at runtime rather than hardcoded; the target repository is likewise read from the installed manifest's `repository`, so a fork files against itself. |
| AC10 | Filing the same report twice from the same project does not create a second issue: the second attempt is stopped by the hash and the user is told, with a pointer to the first filing. |
| AC11 | Every issue the channel files carries the channel marker, so the channel-filed corpus is selectable by a single query. |
| AC12 | When `gh` is missing, unauthenticated, or the create call fails, the local report file is left on disk AND the full report text is printed to the transcript for manual pasting; the failure is reported, never swallowed. |
| AC17 | `ai-docs/feedback` is added to `check-references.sh`'s `DOC_ROOTS` **and** to `docs/agents-method.md` § Agent Docs, and `check-references.sh --audit-roots` exits 0. |
| AC18 | All AGENTS.md § Build & Test structural checks pass (`bash scripts/check-references.sh` exits 0 included), and `.claude-plugin/plugin.json`'s patch version is bumped. |

## Open questions

- **What the idempotency hash is computed over** — the whole normalised report, or a narrower
  stable key (e.g. Surface + Symptom). Narrower catches a reworded re-file; wider is simpler and never
  false-positives. Design's call, with the tradeoff recorded.
- **Where the record of "already filed" lives** in the consuming project, and whether it stores the
  filed issue URL so AC10 can point at the first filing. Design's call; the local report file under
  `ai-docs/feedback/` is the obvious carrier.
- **Skill / command naming** (`/harness:<name>`). Design's call.
