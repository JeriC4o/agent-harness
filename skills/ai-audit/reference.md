# `/ai-audit` reference

Static reference content extracted from `SKILL.md`. Loaded on demand when `/ai-audit` Phase 2 Step 2.3 hits a specific checklist letter, or when Step 2.6 needs to re-verify cross-references anchor-aware.

## Checklist A — Cross-reference integrity

- Every relative link (`../`, `./`, file references in prose) resolves to an existing file.
- Every `[text](file.md)` and bare `file.md` mentioned in instructions points to a file that exists.
- Every Skill or Subagent named in another Skill/Subagent (e.g., `project-review` references `review-findings`, `self-review`) actually has a matching file.

## Checklist B — Conflicting / duplicated rules

- The same topic must not have contradictory guidance in two places (e.g., commit policy in AGENTS.md vs. in a skill).
- Verbatim-duplicated rules across files → consolidate to one canonical home + reference.
- Rule says "see `<other-file>`" — confirm the target file actually contains that rule.

## Checklist C — Dead references

- Skills/agents named in `${CLAUDE_PLUGIN_ROOT}/docs/propagation.md` sync-group rows must exist. **The table is in that extracted reference page — not in `AGENTS.md`, and no longer in `agents-method.md`, which keeps only the AXIOM** — looking for it in the profile finds nothing and the check silently passes.
- Agent names referenced in skills must match a file under `${CLAUDE_PLUGIN_ROOT}/agents/`.
- **A reference in a Subagent checklist that names an ENTITY resolves to an entity that exists, and this check reports how many such references it resolved.** The count is part of the result: a clause that examined nothing reads exactly like a clause that found nothing. A reference naming only the completed-plans directory asserts that a directory exists, which cannot fail — which is why this bullet reads the ENTITY a reference names and not the directory it sits in. **It claims no coverage of the positions already stored in that directory, deliberately.** A position resolves to whatever now sits there, in the worst case to something of the same kind and the same shape stating the opposite of what the citation promised; whether the prohibition reaches backwards into the completed plans is not decided here. **There is no mechanical backstop for the count** — this is a checklist letter a reader runs, so a pass that forgets to print how many it resolved reads clean and nothing catches it.

## Checklist D — Frontmatter conformance (skills)

Per the official Claude Code docs:

- Every `SKILL.md` has YAML frontmatter with at minimum `name` and `description`.
- `description` should make trigger conditions clear (when to invoke).
- `disable-model-invocation: true` ↔ skill is user-only — verify intent matches.
- `argument-hint` style is consistent across skills.
- `allowed-tools` syntax matches `ToolName(pattern)` form documented at `code.claude.com/docs/en/skills`.

## Checklist E — Frontmatter conformance (agents)

- Every `${CLAUDE_PLUGIN_ROOT}/agents/*.md` starts with YAML frontmatter (`---`-delimited block at top of file). A file in `${CLAUDE_PLUGIN_ROOT}/agents/` without frontmatter is not a Subagent — it's a stray document.
- `name` field equals the file basename.
- `description` is one line and tells the orchestrator when to spawn this Subagent.

## Checklist F — Hooks (`${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`)

- Each hook event name is one of the documented set (`SessionStart`, `PreToolUse`, `PostToolUse`, etc. — confirm against `hooks-guide`).
- Matchers are valid tool name patterns.
- Hook commands fail closed (`exit 2` for blocking) where intended; non-blocking informational hooks use stderr without `exit 2`.
- Timeouts are reasonable (≤30s default, longer only when the work demands it).
- Commands quote `$CLAUDE_PROJECT_DIR` and other env vars correctly — no shell injection footguns.

## Checklist G — `propagation.md` coherence

- Every sync group listed in `${CLAUDE_PLUGIN_ROOT}/docs/propagation.md` still has all listed members present and cross-referenced — and, **for a group of three or more members** (the size at which `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` Procedure 5 requires the anchor-plus-back-reference shape), that **every non-anchor member appears as a KEY on that back-reference row**. A two-member group names its partner directly and has no back-reference row by design — do not flag it. Checking only that a back-reference row exists tests shape, not coverage, and passes on a group whose row omits half its members — which is exactly how a member goes unreachable while the table looks complete.
- Behaviors described in AGENTS.md and replicated in Subagent checklists agree (e.g., file-size hard/soft limits in `review-findings.md` match AGENTS.md / `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md`).
- Exemptions in AGENTS.md appear in every enforcement file.

## Checklist H — Documentation conformance pointers

- `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` is referenced by `review-findings.md` and `self-review.md`. Confirm relative paths resolve.
- The canonical section order listed in `doc-convention.md` matches references in `self-review.md` Checklist 6 and `review-findings.md` Checklist 6.

## Checklist I — File-size & structure (instruction files)

- **`SKILL.md` line count belongs to Checklist K, not here** — K.1 owns the soft target and the exemption index at `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md`, and **the figure lives there alone**: a second copy of it on this line is how the two came to disagree, and Checklist B of this same list is "conflicting / duplicated rules". **This sentence sits in a THREE-member sync group** (`${CLAUDE_PLUGIN_ROOT}/docs/propagation.md`, the ai-audit group), which names them in this order: the Step 2.3 letter table in `SKILL.md`, these checklist detail bodies, and the `**Reference:**` footer letter range. A change that stops at one member leaves the old threshold live one file over, which is this very defect's own shape — so read the group off that table rather than off this sentence, and sweep all three. Checklist I keeps only what K does not cover: a **Subagent** file past ~500 lines with no sectioning, and the structural expectation that a long skill splits into a thin `SKILL.md` + reference file (`task`, `ai-audit`, `bugfix`, `interview` use this pattern).
- Each skill directory contains exactly one `SKILL.md` (plus optional reference / scripts subdirectories).
- Method AXIOM: every file in the audited corpus that loads whole at agent start stays under 40,000 chars; 35,000–39,999 is a `minor` warning band. A page reached only by link carries no cap.

## Checklist J — Allow-list / permission consistency

- Tools used in skills' `allowed-tools` should be present (or coverable by) the `permissions.allow` list in `settings.json` — otherwise the user gets a prompt every time.
- Conversely: any allow-listed pattern that no skill actually uses is dead and should be reviewed.

## Checklist K — Skill-directory layout (SKILL.md + supporting files + scripts/)

A skill directory may contain SKILL.md plus supporting files. Audit checks:

1. **Oversized SKILL.md — exemption check + drift detection.** Two additive findings fire from the same pass; both severity `minor`. Source of truth: `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md`.

   - (a) **Parse the index.** Read `${CLAUDE_PLUGIN_ROOT}/docs/skill-size-exemptions.md` and extract, for each row in the exemption table, the SKILL path and the cited `wc -l at audit time` numeric value.
   - (b) **Oversized + no exemption.** Run `wc -l ${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` against the live tree. For each file > 200 lines whose path is NOT in the parsed index, emit a `minor` finding: scan for *reference content* sections (format specs, parser rules, lookup tables, long checklists, embedded templates) — material referenced once or twice but loaded into context on every invocation — and propose extraction to a supporting file OR addition of an exemption entry.
   - (c) **Drift detection.** For each SKILL path listed in the index, compare cited `wc -l` against live `wc -l`. Mismatch → `minor` finding: `` `<path>`: index cites X lines, live is Y lines ``.

2. **Multi-consumer supporting files belong in `ai-docs/templates/`.** When a supporting file is referenced from > 1 Skill or Subagent, propose moving it from the owning Skill's directory to `ai-docs/templates/<file>.md`. Severity `minor`.

3. **Inline-script extraction candidates.** Identify `SKILL.md` sections containing self-contained `bash` blocks — a complete, executable recipe with at most one or two `<placeholder>` substitutions, NOT orchestration guidance the Subagent reconstructs dynamically per call. For each, propose extraction to `skills/<skill>/scripts/<descriptive-name>.sh`. Severity `minor`.

   **Invocation form — the harness ships as a PLUGIN, so the portable form is the rule, not the exception.** An installed skill's absolute location varies (`${CLAUDE_PLUGIN_ROOT}/skills/<skill>/…`), so the SKILL body MUST invoke its script through `${CLAUDE_SKILL_DIR}/scripts/<name>` — a repo-relative invocation resolves against the *consuming project's* CWD and will not find the file. `allowed-tools` keeps the relative `Bash(scripts/<name>:*)` form, because the variable is NOT substituted in `allowed-tools` patterns; the accepted tradeoff is that such calls prompt per use. Flag the inverse — a body invoking a repo-relative `skills/<skill>/scripts/…` path — as `major`: it silently breaks for every consumer of the plugin while still working in the harness repo, which is the worst failure shape available.

   **Counter-rule.** Bash snippets that are orchestration guidance — every call has different placeholder values that the Subagent constructs — are NOT script-extraction candidates. Skip those.

## Checklist L — Learning-Log field coherence

When ${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Learning Log's *Entry format* lists a field maintained by `/improve` and `/ai-audit` (currently `Escalated?` and `Superseded by:`), verify each field is covered in **all five** mandatory locations:

| Location | Required content |
|---|---|
| AGENTS.md *Boundary rule 1 Exception* | Explicit authorization to edit the field in-place, on **both** Learning Log surfaces (`ai-docs/learnings.md` and `ai-docs/learnings/*.md`) |
| AGENTS.md *Boundary rule 2 Exception* | Explicit authorization for the field's edits to coexist with instruction-file edits in the same `/improve` / `/ai-audit` turn |
| `${CLAUDE_PLUGIN_ROOT}/agents/self-improve.md` Step 5 (Commit B backfill) | Workflow describing when and how `/improve` writes the field |
| `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` Steps 2/3/4 | Verification recipe + Category-1 drift fixes, applied to whichever union file the entry lives in |
| `${CLAUDE_PLUGIN_ROOT}/docs/templates/learnings-entry-format.md` *Entry template* | Field mirror — ${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md § Learning Log designates this the DEFAULT read for the entry shape, so a field missing here is invisible to every writer |

A field added to the entry format without parallel coverage in all five targets → `major` finding.

**Declared-schema fields (no `/improve`-time mutation).** Some fields (currently: `Kind:`) are *declared* and *parsed* but **never** mutated. For each such field verify BOTH legs — a declared enum whose values are never checked is not enforced.

**Leg 1 — value conformance across every entry in the union (`ai-docs/learnings.md` + `ai-docs/learnings/*.md`):** `grep -Hn '^\*\*Kind:\*\*' ai-docs/learnings.md ai-docs/learnings/*.md | grep -vE '\*\*Kind:\*\*[[:space:]]+(correction|validation)[[:space:]]*$'`. Both operands and the `-H` are load-bearing: an off-schema `Kind:` in a per-branch file is exactly as invisible to `/improve` as one in the archive, and with a single readable operand grep drops the `filename:` prefix. This command string is held character-identical with the copy in `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` Step 1 — change one and change the other. The `## Format` template block at the top of the archive is an EXPECTED hit (enum declaration, not an entry value); every OTHER hit is `major` — it removes the entry from both `/improve` passes while looking well-formed. Report the ENTRY — its date, its category and its short description, which is the identity the entry's own heading declares — and never a line number. The reason is the same reason the report exists: Boundary rule 1 forbids fixing `Kind:` in place, so the report cannot be a fix and must identify the entry it is about. That report travels the same applying step as every other finding here, including the route that writes into the committed learning record, which outlives the pass and which nobody re-derives — so a position would be stored where no reader re-derives it. Use a position freely while acting on the file in front of you; never let one travel into the entry. **Falsify the sweep before trusting a clean result:** the shorter `:\s*(correction|validation)\s*$` form is broken (its `:` binds inside `**Kind:**`, so nothing matches and the inverted grep flags every entry) — run it once against a known-good entry and confirm silence.

**Leg 2 — documentation coverage in:**

| Location | Required content |
|---|---|
| AGENTS.md `## Learning Log` *Entry format* | Declaration of field name, allowed values, default-when-omitted semantics |
| `${CLAUDE_PLUGIN_ROOT}/agents/self-improve.md` Step 5 | Mention where the workflow branches on its value |
| `${CLAUDE_PLUGIN_ROOT}/agents/learnings-escalation-audit.md` Steps 2/3/4 | Parse-site usage (verdict routing, sweep predicates) |
| `${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md` field glossary | Declaration mirror — same allowed-values list, same default-when-omitted note |

## Checklist M — `agent-writing-style.md` conformance

`${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md` is the canonical style reference for fail-loud rules in instruction files. Checklist M sweeps the audited corpus for drift against the Patterns + Anti-patterns. **Audited corpus**: `AGENTS.md` + every `skills/**/SKILL.md` + every `${CLAUDE_PLUGIN_ROOT}/agents/**.md` + `${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` + `${CLAUDE_PLUGIN_ROOT}/docs/doc-convention.md` + `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md` + `${CLAUDE_PLUGIN_ROOT}/docs/corrections-log.md` + `${CLAUDE_PLUGIN_ROOT}/rules/**/*.md`.

| # | Sub-check | Severity |
|---|---|---|
| 1 | **Pattern 1 (binary rules)** — IF/THEN tables or AXIOM blockquotes; every `> **AXIOM —` block must be followed by an action table within the same blockquote. | `major` |
| 2 | **Pattern 2 (fail-loud AXIOM)** — stick rules use stick verbs (*MUST* / *NEVER* / *MUST NOT* / *FORBIDDEN*); carrot rules use carrot verbs (*Default to* / *Prefer*). | `minor` |
| 3 | **Pattern 3 (action-table column)** — right column of every `\| If you see... \| Action \|` table starts with an action verb (imperative form). | `minor` |
| 4 | **Pattern 4 (explicit file lists)** — fail-loud lists that enumerate files spell out each path; no glob-as-entire-list. | `major` |
| 5 | **Pattern 5 (lock-step verbs)** — verb shape matches rule shape. Stick verbs on carrot rules / carrot verbs on stick rules → `major`. |
| 6 | **Pattern 6 (link, don't duplicate)** — cross-surface duplicate rule with `[link]` to canonical sibling. | `minor` |
| 7 | **Pattern 7 (extract verbose detail)** — body > 5KB and no extraction anchor in `ai-docs/` → `nit`. |
| 8 | **Pattern 8 (file-size cap)** — every instruction file that loads whole at agent start < 40,000 chars; 35,000–39,999 is `minor`. | see body |
| 9 | **Anti-patterns table audit** — no row of the Anti-patterns table appears verbatim as a positive rule. | `major` |
| 10 | **Cross-shape verbs** — carrot blocks must NOT use stick verbs; stick blocks must NOT use carrot verbs. | `major` |
| 11 | **Compaction-recovery callout consistency** — role-aware presence of the locked invariant tiers across the callout-carrying skills, whose population is DERIVED (see detail note below). | `major` |

### Sub-check 11 — compaction-recovery callout consistency

Keys on **role-aware invariant tiers** — NOT byte-equality.

**Derive the population; do not read a number off this page.**

```bash
grep -rln 'Compaction recovery check' ${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md
```

**The `*/SKILL.md` operand is load-bearing.** The same pattern over `skills/` also matches THIS reference
page, which *describes* the callout rather than carrying it — a population inflated by one makes every
tier count below wrong, and that is how this sub-check came to state its own size as four different
numbers. At the last derivation it returned five carriers: `task`, `project-review`, `bugfix`,
`interview`, `context-reset`. Two tiers:

| Tier | Scope | Invariant that MUST be present |
|---|---|---|
| **Tier 1** | every carrier the derivation returns (five at the last measurement) | the opening line `> **⚡ Compaction recovery check — read FIRST on every invocation.**` |
| **Tier 2** | the **consumer** carriers only — the derived set MINUS `context-reset`, which is **EXEMPT** as the rationale carrier (four at the last measurement) | the cross-link substring `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md § Compaction recovery (re-entry)` |

A missing Tier-1 or Tier-2 invariant, or an invented variant of either, is `major`.

**NOT keyed — documented acceptable variance.** Three phrases vary by role and are NOT keyed: `STOP before any tool call`; `top-to-bottom in one pass`; `Re-enter this skill from the top of its body`. Keying them would false-positive on `context-reset` (carrier variant).

**Refinement note (vs the spec).** The spec Key-decisions row lists 5 phrases as "invariant", but live audit found only the opening line (every carrier) + the cross-link (the consumer carriers only) are truly universal — the other 3 are acceptable variance, not keyed.

**False-positive guard.** The sub-check MUST produce ZERO findings against `context-reset` (a correct-by-design carrier variant).

### Sub-check 8 — file-size AXIOM conformance

Detection mechanism:

```bash
wc -m AGENTS.md CLAUDE.md CLAUDE.local.md ai-docs/context.md ${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md \
      ${CLAUDE_PLUGIN_ROOT}/agents/*.md ${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md \
      .claude/agents/*.md .claude/skills/*/SKILL.md
```

| Reported size (chars) | Finding | Severity |
|---|---|---|
| `< 35,000` | none | — |
| `35,000–39,999` | `<path>: <count> chars — early warning (≥ 35,000)` | `minor` (**actionable** — present extraction plan in same pass) |
| `≥ 40,000` | `<path>: <count> chars — AXIOM violation (≥ 40,000)` | `major` |

The 35,000–39,999 band is actionable, NOT a passive heads-up. Recurring misclassification: large instruction files (e.g. AGENTS.md around 36k chars) get tagged "Heads-up surfaced — no fix this pass" and extraction is deferred. When the band fires, propose a concrete extraction plan in the same `/ai-audit` pass — list candidate verbose subsections + the page reached by link each moves to + the anchored pointers to leave behind — and ask the user to approve via the SKILL.md Step 2.5 `minor` rule. The point of the band (separate from the 40k hard cap) is to give one full `/task` cycle of headroom; deferring to "next `/ai-audit`" wastes that headroom.

## Checklist N — Bidirectional `## Patterns` ↔ `Kind: validation` coherence

The carrot-side analog of Checklist C. Every promoted-from-validation carrot must round-trip in both directions:

**Forward direction.** Every `### N. <Name>` entry under a `## Patterns` section in the audited corpus whose **body uses carrot verbs** (`Default to` / `Prefer`) MUST back-link to at least one `Kind: validation` entry in the union — `ai-docs/learnings.md` or any `ai-docs/learnings/*.md`. Detection: for each `### N. <Name>` block, grep its body for `Default to` or `Prefer`; if found, also grep for a Learning Log back-link (either surface's path + a date-slug citation) within the same block.

**Forward-sweep carrier-vs-template exemption.** Entries WITHOUT carrot verbs are out of scope. Named exempt source: `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md § Patterns` (template source, not a promoted-from-validation carrier).

**Reverse direction.** Every `Kind: validation` entry in the union (`ai-docs/learnings.md` + `ai-docs/learnings/*.md`) whose `Escalated?` ≠ `no` MUST have a corresponding `## Patterns` block in each named target file. Multi-target: the `Escalated?` field may name multiple comma-separated targets; the reverse sweep iterates each independently — a validation entry escalated to two targets must have a `## Patterns` block in BOTH files.

| Direction | Trigger | Action |
|---|---|---|
| Forward | `### N. <Name>` block in `## Patterns` uses carrot verb AND no Learning Log back-link (`ai-docs/learnings.md` or `ai-docs/learnings/*.md`) in the same block | flag (`major`) |
| Forward (exemption) | `### N. <Name>` block has no carrot verb in its body | no flag |
| Forward (named exempt source) | The audited file is `${CLAUDE_PLUGIN_ROOT}/docs/agent-writing-style.md` | no flag |
| Reverse | `Kind: validation` entry with `Escalated? ≠ no` AND named target file lacks `## Patterns` block OR back-linking entry | flag (`major`) |
| Reverse (predicate gate) | `Kind: validation` entry with `Escalated? no` | no flag |

> **Carve-out — inherited Patterns after a corpus reset.** The reverse leg assumes every `## Patterns`
> entry was promoted from a `Kind: validation` entry in THIS repo's log. A harness distributed as a
> template starts with an empty Learning Log while carrying Patterns blocks inherited from wherever the
> method was originally learned, so the reverse leg cannot hold for them and reports every block as
> orphaned. That is expected, not a finding. **Do not resolve it by writing validation entries** — those
> lessons were not learned here, and a fabricated entry corrupts the one artefact `/improve` reasons
> over. The reverse leg becomes meaningful again for Patterns promoted after the reset; audit those.

## Checklist O — Embedded-name clash scan

Enforces the `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Naming clash-rename AXIOM. Project-defined Tool / Subagent / Skill / Hook names MUST NOT clash with embedded names enumerated in `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md` §§1a/1b/2a/3a/3b. Any match → `major` finding (project side renames; the embedded name is never renamed).

**Recipe.** Enumerate two sorted lists and intersect them; empty intersection passes.

1. **Project names** — collect every name the project DEFINES:
   - Subagent names: `awk 'FNR==1{f=0} /^---$/{f=!f; next} f && /^name:/{print $2}' ${CLAUDE_PLUGIN_ROOT}/agents/*.md`
   - Skill names: `awk 'FNR==1{f=0} /^---$/{f=!f; next} f && /^name:/{print $2}' ${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md`
   - Hook event names: `jq -r '.hooks | keys[]' ${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`
   - Sort + dedupe → `project-names.txt`.
2. **Embedded names** — extract names from the FIRST column of `${CLAUDE_PLUGIN_ROOT}/docs/claude-tools-hierarchy.md` §§1a + 1b + 2a + 3a + 3b table rows. Namespaced names count as ONE token; do NOT split on `:`.
3. **Intersection** — `comm -12 <(sort -u project-names.txt) <(sort -u embedded-names.txt)` MUST return empty.

| Trigger | Action |
|---|---|
| `comm -12` output is empty | no flag — clash-scan baseline holds |
| `comm -12` output is non-empty | `major` finding per name: "Project-defined `<name>` clashes with embedded `<name>` enumerated at `claude-tools-hierarchy.md` §§<sections>. Rename the project side." |

Severity `major` — the clash makes ambiguous which name resolves at dispatch time.

## Checklist P — Frontmatter/config improvement recommendations

The recipe lives on its own page:
[`${CLAUDE_PLUGIN_ROOT}/docs/frontmatter-recommendations.md`](${CLAUDE_PLUGIN_ROOT}/docs/frontmatter-recommendations.md)
— the schema source and the instruction not to spawn a second fetch, the six legal values with the four
that are recommendation verbs, the per-field gates on an **add**, the two-way model-posture taxonomy with
its exhaustiveness clause, and the shape of the table the run emits. The heading stays here so the letter
keeps its place in the sequence and this page's inbound references keep resolving. Letter P's scope is
unchanged, which is why the footer's letter range is unchanged with it.
## Step 2.6 sub-step 4 — Cross-reference re-verification (anchor-aware)

For every relative link the audit touched, confirm the target file exists AND the anchor (if present) matches a heading slug. Anchor-aware check rather than naive `realpath -m`:

> **This block is a checker, so it is a gate** ([`${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md` § Propagation sweep, item 3](${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md)). As written it reports through `echo` and always exits 0, so a caller cannot tell "no dead anchors" from "the slugifier matched nothing". Before reading its output as findings: run it once against a link you KNOW is broken and confirm it prints, and collect the misses into a counter the block exits non-zero on. **This block hits three of the masking shapes at once** — a `for` loop, `>/dev/null`, and `|| echo` — and [`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Tooling](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md) names **search** among the gates, so `grep -Fx` is one. The block is not carved out: it is a gate written in a forbidden shape, kept here only because rewriting a documented recipe is a separate change. Do not read it as licence for the shape anywhere else, and do not "fix" it by adding a counter incremented inside the `while` — that `while` is the TAIL of a pipeline, which `bash` runs in a SUBSHELL (shape 4), so the counter reads back as 0 while looking repaired; measured, `bash` gives 0 where `zsh` gives 2. Write misses to a FILE and exit on its size, or restructure the loop over a here-string.

```bash
for f in <changed-files>; do
  grep -oE '\(\.\./[./]*[^)#]+(#[^)]*)?\)' "$f" | sort -u | while read ref; do
    path_with_anchor=$(echo "$ref" | tr -d '()')
    path=${path_with_anchor%%#*}
    anchor=${path_with_anchor#*#}; [ "$anchor" = "$path_with_anchor" ] && anchor=""
    src_dir=$(dirname "$f")
    abs=$(realpath -m "$src_dir/$path")
    [ -e "$abs" ] || { echo "FILE MISSING: $f -> $path"; continue; }
    [ -z "$anchor" ] && continue
    # heading-slug match: lowercase, strip non-alnum-non-hyphen, spaces->hyphens
    awk '/^#{1,6}\s/{line=$0; gsub(/^#+\s+/,"",line); line=tolower(line); gsub(/[^a-z0-9 -]/,"",line); gsub(/ /,"-",line); gsub(/-+/,"-",line); sub(/^-+/,"",line); sub(/-+$/,"",line); print line}' "$abs" | grep -Fx "$anchor" >/dev/null || echo "ANCHOR MISSING: $f -> $path#$anchor"
  done
done
```

## Checklist Q — Profile completeness (project surface)

Mechanical, via `${CLAUDE_PLUGIN_ROOT}/scripts/audit-project.sh`.

- No unresolved `%PLACEHOLDER%` in `AGENTS.md` or `ai-docs/context.md` → `blocker`.
- **Label tokens are not findings.** The left column of the Build & Test table names each placeholder
  (`%BUILD_CMD%`, …) and the prose refers to `%PLACEHOLDER%` generically; those are permanent labels. Only
  a token outside that allowlist is an unfilled value. A checker that flags the labels cries wolf on every
  correctly-filled profile, which is how a real finding gets ignored.

## Checklist R — Command liveness (project surface)

For each recorded `%*_CMD%` value, take the first token and resolve it (`command -v`, or an executable
check for a `./`-relative path). Missing → `major`.

This check is **executed, never read**. A command table naming a binary nobody has looks perfectly correct
on the page, and every later "the gate passed" claim inherits the defect. The reasoning is the general
one, and the example it used to cite is gone: `design-review` no longer has a rule about running a gate
the design pins, because a design pins no command.

## Checklist S — Registry coherence (project surface)

The project's absolute path appears in `~/.claude/harness/registry.json` (or `$HARNESS_REGISTRY`), with
`scope` ∈ {`shared`, `local`}. Absent → `major` (cross-project sweeps will not see it). No registry at
all → `minor`.

## Checklist T — Candidate hygiene (project surface)

Every `ai-docs/learnings/.promote/*.md` still passes `check-candidate.sh`. A refused candidate → `major`:
it will never be swept, and nothing else reports that, so the lesson sits there looking promoted while
being invisible. Re-checked here because a candidate can be hand-edited after it first passed.

## Checklist U — Gitignore coverage (project surface)

`git check-ignore` against a real probe path under `ai-docs/plans/`. Not ignored → `blocker`: working
state would be committed. Verified by asking git rather than by reading `.gitignore`, because a pattern
that looks right and does not match is exactly the failure this check exists to catch.
