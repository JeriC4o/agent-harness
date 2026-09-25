# Design: Escalation channel from a consuming project back to the harness

**Ticket:** GH-29
**Date:** 2026-09-24
**Spec:** ai-docs/plans/2026-09-24-harness-feedback-channel.spec.md

## Approach

### 0. What was measured while writing this design

Every mechanism pinned below was executed before it was written down, per the harness rule that a gate
may not be named as an exit gate without having been run in both directions. The measurements are
reported inline where they decide something; the ones that decide the most:

| Measurement | Result |
|---|---|
| Naive widening (`scripts/` appended to the permit alternation) | `scripts/session-events.sh` → 0, `myproject/scripts/deploy-prod.sh` → 0 (**leaked**), `server/core/Merge.kt` → 1. Reproduces the spec's fixture triple exactly. |
| **Today's shipped gate on nine prose slash-pairs** | `read/write`, `client/server`, `GET/POST`, `he/she`, `TCP/IP`, `24/7`, `N/A` → **all REFUSED** as `file path`; only the two hardcoded literals `and/or` and `input/output` pass. A **pre-existing** trap, not one this design introduces — but it becomes load-bearing here; see § 1b. |
| Existence-check + path-claim prototype, 21 rows, against a **pinned fixture harness root** | all 21 verdicts as designed — table in § 1d below (r16, r17 and r21 pin the **three** residue directions of § 1b; r18, r19 and r20 pin the three contracts that a plausible wrong implementation would otherwise satisfy) |
| **The chosen mechanism against the rejected one, over the whole suite** | the existence check at `scripts/check-candidate.sh:147` swapped for the anchored alternation of § 1d on a scratch copy → `bash scripts/test-promotion.sh` **0 failed, and the pass count unchanged** at the **pre-amendment** total of 138. (138 is a snapshot of this branch *before* r20, r21, t1 and t2 land — each of those raises it. The invariant is `0 failed` plus the 25 assertions inherited from `main`, never the total; see § Test Design, AC4.) The suite could not see the substitution. The behaviour lost is real: `**Evidence:** scripts/deploy-prod.sh` against a root holding `scripts/session-events.sh` and no `scripts/deploy-prod.sh` → shipped gate **rc 1**, `file path: scripts/deploy-prod.sh (no such path under the harness root)`; mutant **rc 0, exported**. r2 cannot see it (its first segment is a project noun, so both mechanisms refuse it). Pinned as **row r20** |
| **The refusal trailer, both modes** | on a report-mode refusal the **pre-implementation** gate printed `Rewrite the lesson so it names the SHAPE of the failure, not the instance.` — the wrong noun, and an instruction to do the thing AC8 and `SKILL.md` § FORBIDDEN forbid. Measured, the *substring* `Rewrite the lesson` is **not** unique to the gate: `grep -rn 'Rewrite the lesson' scripts/ skills/ docs/` returned **two** hits — the `printf` at `scripts/check-candidate.sh:260` **and** `skills/improve/SKILL.md:118`; widening the pattern to also match `SHAPE of the failure` returned **three** (adding `skills/improve/SKILL.md:111`). **Both counts were measured before this increment:** t1 and t2 put the string into `scripts/test-promotion.sh` (`:125` and `:228`), so the same two commands now return **four** and **five** — that rise is the change this row argues for, not drift to be re-closed. **That second hit is a substring match, not a copy.** The exact trailer occurs **nowhere** under `skills/` or `docs/`: `grep -rn 'Rewrite the lesson so it names the SHAPE of the failure, not the instance' --include='*.md' skills/ docs/` → **zero hits**, with the positive control `grep -rn 'never edit the gate' --include='*.md' .` → `skills/improve/SKILL.md:118` proving the search is not mis-filtered. What `SKILL.md` carries is a **paraphrase split across two non-adjacent lines** — `:111` *"Write the SHAPE of the failure, never the instance."* and `:118` *"A refusal names the offending term. **Rewrite the lesson; never edit the gate…**"* — different verb, different negation, different order, seven lines apart. **Neither file quotes the other.** Rule mode keeps its line byte-for-byte because **AC4 requires default-mode behaviour to be unchanged**, a reason that is self-sufficient and depends on no other file; separately and more weakly, `skills/improve/SKILL.md` instructs the promoting agent *in its own words* to do what the trailer advises, so rewording the gate desynchronises a **description**, not a quotation (§ 3a). Separately measured, and phrased so its success is not an empty result: `grep -rc 'Rewrite the lesson'` over all twelve test scripts in the tree printed a line per file and every line read `:0`, while the identical `grep -rc check-candidate` over the same twelve prints `scripts/test-promotion.sh:5` — so the probe is proven able to come back non-zero, and **no test asserted the trailer in either mode**. **Measured before this increment; t1 and t2 now assert it, which is the change** — the same `-rc` probe reads `scripts/test-promotion.sh:2` once they land, so this is not a coverage gap awaiting a fix. Mode-aware prototype measured in both directions and over the whole suite — see § 3a |
| **The Surface contract, body-scoped vs line-scoped, over four rows** | r14 and r15 score **identically under both** (rc=1, `structure`) — so neither discriminates. A body carrying `**Surface:** read/write` *and* `Evidence: scripts/session-events.sh`: body-scoped → **rc=0, no finding**; line-scoped → **rc=1, `structure`**. That one row is the whole discriminator — see § 1a and row r18 |
| **The ledger read, five states, with `jq -r '.filed[$h].issue // empty'`** | valid+hit → the URL; **valid+miss, zero-byte, truncated and ABSENT → empty stdout, all four** (rc 0 / 0 / 5 / 2, discarded by the usual `2>/dev/null`). One indistinguishable "proceed to `gh`" over a miss and two damaged files — the fix and its measured replacement are in § 5 |
| **The `file` verb's write path, three runs against a recording `gh` stub** | run 1 on an **absent** ledger → `gh` invoked once, ledger created, row carries hash / issue / `harness_version`; run 2, same hash → refused, **`gh` total still 1** (zero further invocations), read from the ledger run 1 wrote; run 3 on a **truncated** ledger → **exit 2**, `gh` not invoked, file byte-identical |
| **The ambiguity warning, both directions, plus the counterfactual** | `ai-docs/context.md` (in both trees) → PASS **+ warning**; `scripts/check-candidate.sh` (harness only) → PASS, **no warning**. A warn-on-every-permitted-claim implementation warns on *both* — so the second row is what fails it, and the first is what proves the same grep can come back non-empty |
| **Root-side `pwd -P`, counterfactual** | with logical `pwd` on the **root** side, root-reached-through-a-symlink scores **0 — guard evaded** — for both the nested and the equal project. Physicalising both sides scores 2 for both. See § 1c |
| `CLAUDE_PLUGIN_ROOT` / `CLAUDE_SKILL_DIR` inside a Bash call | **both UNSET.** The `$0`-derived root is therefore the PRODUCTION path, not a testability nicety — see § 1c |
| Harness-root validation, **five** planted failures + **two** negative controls | unmarked (non-harness) dir → 2; unresolvable root → 2; root == project → 2, and still 2 **with markers planted** (containment, not markers); root strictly containing the project, markers present → 2; project reached through a **symlink** whose target is inside the root → 2. Negative controls: disjoint marked root → 0; shared-prefix sibling → 0. § 1c's table is the canonical list |
| Project-dir derivation on an `ai-docs/feedback/` path | **the pre-implementation derivation silently PASSED a report carrying a domain entity** — see § 2, the most serious finding in this design; § 2's guards 1 and 2 are what close it |
| Guard 2 in isolation (report at `…/ai-docs/feedback/sub/r.md`, no `--project-dir`) | **exit 2**, reason named — not 1, not 0. Without guard 2 the derivation lands on `<proj>/ai-docs` and the run goes green |
| **The path-claim test on three-or-more-term prose** | `read/write/execute`, `input/output/error`, `client/server/proxy`, `he/she/they` → **all four REFUSED** against the real fixture root, because `≥ 2 separators` makes a token a path claim regardless of shape. Residue in the STRICT direction — see § 1b, row r16 |
| **The containment comparison, four shapes** | naive prefix test refuses the *sibling* `…/base/root-proj` against root `…/base/root` (**false exit 2**); `/`-terminated `case` on `pwd -P` values → **0**. A project reached by symlink into `…/root/inner`: logical `pwd` → **0** (guard evaded), `pwd -P` → **2**. Equality and plain nesting still → 2 under the chosen form |
| **`file` against a ledger that already holds the hash** | exit 1, the three-line message, **0 `gh` invocations** (recording stub), ledger byte-identical; negative control on a miss → `gh` invoked once, exit 0 |
| **What an INSTALL actually contains** | sandbox install of the working tree lands at `$CLAUDE_CONFIG_DIR/plugins/cache/<market>/<name>/<version>/`; `docs/agents-method.md` and `.claude-plugin/plugin.json` both **present**, `skills/report-defect/SKILL.md` (**not yet written when this was measured**; Task 5 creates it) and a planted non-file both **absent** — so the inventory assertion is falsifiable |
| Full structural battery on `main` | manifests ok; `check-references` 0; `bash -n` clean; 10 suites green (`test-promotion` 25/0) |

### 1a. The permitted-path decision (the load-bearing part)

**Chosen mechanism: a path-claim test, then an existence check under the resolved harness root, plus
two syntactic refusals.** In `--mode report`, the file-path leg stops being an unanchored `grep -v`
alternation and becomes a per-token decision:

1. Extract slash tokens with a regex that, unlike the default mode's, **also captures a leading `/`**.
   The LEFT anchor is otherwise unchanged from default mode — start-of-line, whitespace or a backtick
   — so a token whose left neighbour is other punctuation is not extracted at all. That is deliberate
   for this increment, measured, and pinned as row r21; see § 1b's *loose by capture* direction and
   the matching Risks bullet.
2. Strip trailing sentence punctuation (`[.,;:)]*$`) from each token. (A `file:line` suffix needs no
   handling: `:` is outside the token character class, so `scripts/foo.sh:14` is captured as
   `scripts/foo.sh` — measured, row r1.)
3. Refuse a token that starts with `/` — *absolute path*.
4. Refuse a token containing `..` — *parent traversal*.
5. **Decide whether the token is a PATH CLAIM at all** (§ 1b). If it is not, it is prose: the leg says
   nothing about it and the token moves on to every other leg unchanged.
6. A path claim is permitted **only if `${HARNESS_ROOT}/<token>` exists**; else refused.
7. A permitted claim that *also* exists at the same relative path under `PROJECT_DIR` raises an
   **ambiguity warning** on stderr (§ 1e). Advisory, not a refusal — the exit code is untouched.

Additionally, report mode requires **`**Surface:**` to carry at least one PERMITTED path claim** — a
`structure` finding otherwise. That is what makes "`Surface` names a harness file" a contract rather
than a drafting habit, and it is measured in both directions (rows r14, r15).

**The contract is evaluated over the `**Surface:**` LINE only — not over the body — and that has to be
stated because rows r14 and r15 cannot tell the two apart.** The natural shortcut is to reuse the
permitted-claim list the path leg already computed for the whole body and ask whether it is non-empty.
That implementation satisfies **both** r14 and r15, because in each of them the whole body contains no
permitted claim either. But a *real* report carries a path in `Surface` **and** another in `Evidence`,
so the body-scoped form passes every real report regardless of what `Surface` actually says — which
silently voids § 1e's primary mitigation while the suite stays green. Measured over four inputs:

| Input | Body-scoped | Line-scoped |
|---|---|---|
| r14 — `**Surface:** myproject/src/Foo.kt` | rc=1, `structure` | rc=1, `structure` |
| r15 — `**Surface:** read/write` | rc=1, `structure` | rc=1, `structure` |
| **r18** — `**Surface:** read/write` **+** `**Evidence:** scripts/session-events.sh …` | **rc=0, no finding** | **rc=1, `structure`** |
| positive control — `**Surface:** scripts/session-events.sh` | rc=0 | rc=0 |

Only r18 separates them, so r18 is pinned as a row (§ 1d) rather than left as an implementation note.
The positive control is what stops "always emit a `structure` finding" from scoring as a pass.

Mechanically: the permitted-claim decision (steps 1–6) is a function over a piece of text; the
`Surface` contract applies it to `grep '^\*\*Surface:\*\*'` output, and the path leg applies it to the
body. One function, two inputs — not one result reused twice.

### 1b. The prose-slash class — a pre-existing trap that this mode has to stop walking into

Measured against **today's shipped gate**, unchanged, default mode:

```
read/write  REFUSED   client/server REFUSED   GET/POST REFUSED   he/she REFUSED
TCP/IP      REFUSED   24/7          REFUSED   N/A      REFUSED
and/or      PASSES    input/output  PASSES                 (the two hardcoded literals)
```

So ordinary English slash-pairs are **already** refused, and the two literals are the scar tissue
proving it bites. Nothing in this design causes that; the earlier draft of this document claimed those
two literals "survive" as though they were a feature, which was wrong on the facts (the five-step leg
had no literal-exemption step) and wrong on the framing.

**Why it nevertheless has to be solved here rather than left alone.** A promotion candidate is a terse
*rule*; a defect report is *prose describing behaviour*, and behaviour is where `read/write`,
`client/server`, `input/output` and `GET/POST` live. The class is unavoidable in the new payload in a
way it is avoidable in the old one. Patching two more literals back in is not the fix — it is the same
mistake at a larger size.

**The fix: a path-claim test, so the existence check is only ever applied to tokens that assert a
file.** A slash token is a path claim when

- its final segment carries an extension — `\.[A-Za-z0-9]{1,4}$` — **or**
- it contains two or more `/`,

and **not** when every segment is purely numeric (`2026/09/24` is a date, not a path).

Everything else is prose and is not path-checked. Measured: all nine pairs above pass in report mode
(row r9), while every fixture the spec requires refused is still refused (r2, r3). **The default
mode's behaviour is unchanged — AC4** — including its refusal of `read/write` and its two literals;
report mode is a separate branch and the alternation is not used in it at all.

**What this test actually admits, stated at its real size: two-term prose pairs, not "the prose
class".** The nine-pair row is nine *two-term* pairs, and that is the whole of what the test relieves.
A three-or-more-term slash run trips the `≥ 2 separators` clause, is classified as a path claim
regardless of its shape, and is **refused** — measured against the real fixture root:

```
read/write/execute  REFUSED   input/output/error REFUSED
client/server/proxy REFUSED   he/she/they        REFUSED
```

Those are the same "prose describing behaviour" register this section argues is unavoidable in a
defect report, so this is residue, not a corner. It is one of three directions of residue this section
carries — see the table below. It is named here, pinned as row r16, named again
under Risks, and handled by a drafting rule rather than by a lexical fix.

**No lexical fix is available, and none should be invented.** Any relaxation of the `≥ 2 separators`
clause re-opens `myproject/scripts/deploy-prod.sh` (row r2) — the exact leak the spec's fixture triple
exists to close — because that token's own discriminator is precisely its separator count. The two
cases are the same shape to any rule that reads only the token. Weakening the clause to buy back
`read/write/execute` would trade a measured project-path leak for a drafting convenience, which is the
wrong direction.

**The residue this section opens runs in THREE directions — and two of them are loose by DIFFERENT
mechanisms, which is why they are listed as separate rows rather than merged into one.** A reader
should not have to assemble the tradeoff from several places:

| Direction | Shape | Verdict | Consequence |
|---|---|---|---|
| **Loose, by classification** (report mode weaker than default) | one slash, no extension, non-numeric — `services/billing` | **PASS** (r17) | the token IS captured, and the path-claim test then rules it prose |
| **Loose, by capture** (report mode identical to default) | any path token whose LEFT neighbour is punctuation — a parenthesis, a double quote, a square bracket, an angle bracket or an em-dash, as in the parenthesised `(src/main/billing/Invoice.kt)` | **PASS** (r21) | the token is never extracted at all, so the path leg never classifies it — a silent escape |
| **Strict** (report mode stronger than default) | three or more slash-joined prose terms — `read/write/execute` | **REFUSED** (r16) | a legitimate report is refused until reworded |

All three are accepted, for reasons that are not "it is unlikely":

- *The loose-by-classification direction (r17).* Such a token is still subject to the
  derived-vocabulary leg, the `KEY-123` leg and the URL leg, which are the legs that actually carry
  project identity; a lexical discriminator that could separate `client/server` from `acme/billing`
  would need a dictionary, which is not portable and would be a silent-failure machine of its own; and
  the alternative — keeping the blanket refusal — makes the channel unusable, which the spec names as
  its own top failure mode.
- *The loose-by-capture direction (r21) — and why it is NOT the row above it.* In the
  loose-by-classification direction the token **is** captured and is then ruled prose by the
  path-claim test of this section. Here the token is **never captured**, so no classification is
  attempted and the path-claim test is never reached. Same verdict, two different mechanisms: a change
  to the path-claim test moves r17 and leaves r21 exactly where it is, and a change to the token regex
  moves r21 and leaves r17 exactly where it is. Merging the two rows would let a fix to either one read
  as a fix to both, which is the failure this document's own trailer warns about.

  **Measured against the running gate, not against the regex alone.** Report mode's token regex
  (`scripts/check-candidate.sh:138`) admits only start-of-line, whitespace or a backtick immediately
  before a token. A complete report carrying `**Evidence:** (src/main/billing/Invoice.kt)`, run
  against a purpose-built fixture root, scores **rc 0 with nothing on stderr** — the token is
  exported. So do the double-quoted, square-bracketed, angle-bracketed and em-dashed spellings: **five
  shapes, five rc 0, five silent.** The control is the same token with the punctuation removed, which
  scores **rc 1**, `file path: src/main/billing/Invoice.kt (no such path under the harness root)`.
  **Default mode scores the identical six**: its own regex (`scripts/check-candidate.sh:239`) carries
  the same left anchor, and a rule-shaped candidate over the same six inputs gave five rc 0 and one
  rc 1 naming the token. So this is **parity with the shipped gate, not a regression this branch
  introduces.**

  **Why parity is not on its own the argument, and what the real reason to defer is.** Parity would be
  too weak a defence here: § 1b relaxes the prose class *because report mode's payload is markdown
  prose about a codebase*, and a parenthesised or quoted path is that same register — this document
  may not invoke that premise when it cuts toward relaxation and decline it when it cuts toward a
  leak. The reason to defer is a **measured interaction**, not the parity. Widening the left anchor to
  `(^|[^A-Za-z0-9_.-])` does buy back all five punctuation shapes; it **also** begins capturing
  `//host/wiki/page` out of `see https://host/wiki/page for more` — measured, the two regexes run side
  by side on the same string, today's capturing nothing and the widened one capturing that token. It
  begins with `/`, so step 3 of § 1a refuses it as an **absolute path**, which means a URL-bearing
  report that today yields only a `url` finding (the leg at `scripts/check-candidate.sh:245`) would
  additionally yield a `file path` one. A widening therefore reclassifies URL-bearing text and needs
  its own rows and its own fixture cases. That is a separate change, not a free one — so it is
  **deferred rather than declared harmless**, pinned as row **r21** so a later widening is deliberate
  and visible, named under Risks, and mitigated at draft time by Task 5's rule that `Evidence`
  describes project files in words rather than naming them as paths.
- *The strict direction (r16).* The failure is **loud and recoverable**: the gate names the offending token
  and the drafter rewrites `read/write/execute` as "read, write and execute", which costs nothing and
  loses no meaning. A false refusal that prints the token it refused is a different class of harm from
  a silent export. Task 5 therefore carries the drafting rule — **slash-joined runs of three or more
  words are written as separate words** — so the case is handled at draft time rather than rediscovered
  at gate time.

The asymmetry is deliberate: errors in **both** loose directions are silent and bounded by the other
legs — the derived-vocabulary, `KEY-123` and URL legs run over the same text in either case; errors in
the strict direction are visible and fixable by the drafter in one edit.

### 1c. Resolving the harness root

`HARNESS_ROOT` is **derived from the running script as `dirname "$0"/..` — and that is the PRIMARY,
production branch**, not a testability accommodation. Measured: `CLAUDE_PLUGIN_ROOT` and
`CLAUDE_SKILL_DIR` are both **unset inside a Bash call**, so in a real consuming-project run nothing
supplies the env var and the derivation is what actually executes. `${CLAUDE_PLUGIN_ROOT}` is honoured
as an **override** when set and non-empty — which is how the test suite pins the root (§ Test Design)
— and it takes precedence, because an explicit value should. The derivation is self-consistent: the
gate always lives at `<root>/scripts/check-candidate.sh`, so `<script dir>/..` is the root of whichever
copy is running.

**Because the derived value is production, it gets the same guard-2 doctrine the project-dir
derivation gets (§ 2): a derivation that cannot be confirmed is a usage error, never a silent pass.**
Both branches — env and derived — go through one validation:

1. The root must resolve (`cd … && pwd`), else exit 2.
2. It must carry harness markers: `.claude-plugin/plugin.json` and `docs/agents-method.md`, both
   verified present in installed `0.1.12`. Absent → exit 2, "not a harness install".
3. **Markers are necessary but not sufficient**, and this repository is the proof: it ships them and
   is *simultaneously* a consuming project. So the root is also refused when it **equals or contains**
   `PROJECT_DIR` — report mode cannot check a project against itself. Exit 2.

**How "contains" is compared — specified, because the naive form is wrong in both directions.** An
earlier draft mandated the refusal without saying how the comparison is made, and the obvious
implementation (a bare string-prefix test on `cd … && pwd` values) is wrong twice over. Measured:

- **A bare prefix test refuses a sibling.** Root `…/base/root`, project `…/base/root-proj`: the
  project path begins with the root path, so `case "$PD" in "$HR"*)` matches and the run exits 2 — a
  **false exit 2 that makes the channel unusable for that project**, which is the spec's own top
  failure mode. The two directories are unrelated.
- **`cd … && pwd` is LOGICAL, so a symlink evades the guard.** A project reached through a symlink
  whose target sits *inside* the harness root reports the link path (`…/base/link-proj`) while a
  `$0`-derived root is physical, so the containment test compares two incomparable strings and returns
  **0** — a genuinely nested pair passes. Measured: `cd …/link-proj && pwd` → `…/base/link-proj`,
  `pwd -P` → `…/base/root/inner`.

Neither is visible to the existing negative control, because both `mktemp -d` fixtures are disjoint
and share no prefix — so the suite would have gone green over both.

**The comparison, fixed:** inside the report-mode guard, resolve **both** sides physically and compare
`/`-terminated paths.

```sh
HARNESS_ROOT=$(cd -- "$HARNESS_ROOT" 2>/dev/null && pwd -P) || die "harness root does not resolve"
PHYS_PROJECT=$(cd -- "$PROJECT_DIR" && pwd -P)
case "$PHYS_PROJECT/" in "$HARNESS_ROOT"/*) die "harness root equals or contains the project dir" ;; esac
```

**`pwd -P` is applied to the ROOT side too, and that — not the project side — is what makes the
symlink mirrors hold.** The measured evasion above is stated from the project side, but the same shape
runs the other way: a root reached *through* a symlink while the project is physical. Both directions
are covered because the assignment above physicalises `HARNESS_ROOT` itself. Measured, and measured
counterfactually: with logical `pwd` on the root side, root `…/base/link-root` against project
`…/base/root/inner` scores **0 — evaded** — and so does the equal case (root `…/base/link-root`,
project `…/base/root`); with `pwd -P` on both sides both score **2**. Project-is-the-root scores 2 the
same way.

**The guard is deliberately ONE-DIRECTIONAL, and that is not an oversight.** The reverse containment —
a *project* that contains the harness root — **passes**: root `…/base/root/inner` against project
`…/base/root` → **0**, measured. That is correct for the shape this guard exists to catch. A real
install lives under `$HOME/.claude/plugins/cache/…`, which no consuming project contains; and this
repository's own self-hosting shape is root **equal to** project, which the guard *does* refuse. A
project that genuinely contains an install directory is a project vendoring the harness, where the
project's own vocabulary legs are the right defence, not a refusal to run at all. Widening the guard to
bite in both directions would buy nothing measurable and would add a second false-exit-2 shape of the
kind the sibling case already shows is fatal to the channel.

`pwd -P` is confined to the report-mode guard and to a **local** `PHYS_PROJECT`. **Line 87's
`PROJECT_DIR=$(cd -- "$PROJECT_DIR" && pwd)` is not touched** — it is default-mode code on the shared
path, and changing it would put AC4 at risk for a comparison that only report mode makes. The
`/`-termination is what separates the sibling from the descendant; equality still refuses, because
`"$HR"/*` matches `"$HR/"` with `*` empty (measured).

Planted failures, all measured, all exit 2 with the reason named — plus the two negative controls the
comparison now needs:

| Planted root | Result | What it isolates |
|---|---|---|
| a `mktemp -d` with no markers | 2 — "no `.claude-plugin/plugin.json`; not a harness install" | marker check |
| root == `PROJECT_DIR`, **markers planted into it** | 2 — "equals or contains the project dir" | containment, with the marker check satisfied — proves markers alone would have passed it |
| root strictly **containing** `PROJECT_DIR`, markers present | 2 — same reason | the self-hosting shape |
| a path that does not exist | 2 — "does not resolve" | resolution |
| **negative control:** the same marked root against a *disjoint* project | **0** | the guard is not a blanket refusal |
| **negative control:** root `…/base/root`, project `…/base/root-proj` — a **shared-prefix sibling** | **0** | the `/`-termination; a bare prefix test scores 2 here and the channel dies for that project |
| **planted failure:** project reached through a **symlink** whose target is `…/base/root/inner` | **2** — "equals or contains the project dir" | `pwd -P` on both sides; with logical `pwd` this scores 0 and a nested pair passes |

Consequence worth naming: filing from inside the harness repository itself is now refused at exit 2
rather than half-working. That is correct — from inside this repo, filing is one `gh` command — and it
is recorded under Risks.

**Why steps 3 and 4 are not optional, and why the spec's fixture triple alone would not have found
them.** Both are bugs the existence check *introduces* and that a three-row fixture cannot see:

- Without step 4, the token `../../etc/passwd` resolves to a real file, so `[ -e ]` returns true and an
  arbitrary out-of-tree path is **permitted**. The existence check turns `..` into an escape hatch that
  the alternation never had.
- Without step 3 and the widened token regex, an absolute project path is not *permitted* — it is
  never even captured. The default mode's token regex requires start-of-line or whitespace/backtick
  immediately before the first segment, so in `See /Users/someone/acmecorp/src/Foo.kt` nothing matches:
  `/` is not whitespace, and `^` does not hold mid-line. Today that hole is covered incidentally by the
  vocabulary leg (`acmecorp` is a word, `/` is a word boundary), but that is coverage by accident, and
  an absolute path with no project noun in it passes. Report mode captures it and refuses it outright.

  **Step 3 closes ONE instance of that anchor's blind spot, not the shape.** The same "the left
  neighbour is not whitespace and `^` does not hold mid-line" reasoning applies to every other
  punctuation neighbour — `(`, `"`, `[`, `<`, an em-dash — and step 3's widening buys back only the
  leading `/`. The remaining shapes are **measured, tolerated, and pinned as row r21**; the direction
  is named in § 1b's residue table as *loose by capture* and under Risks. It is recorded here so this
  paragraph is not read as having closed the class it names.

Both were planted as failures and both fire — rows r6 and r8 below.

### 1d. Measured verdicts — against a PINNED fixture harness root

**The table below is a property of a fixture, not of whatever tree happens to be installed.** That is
the correction: an earlier draft measured against installed `0.1.12` while `scripts/test-promotion.sh`
sets `CHECK` to the *worktree* copy, so under the `$0` derivation the suite would have resolved
`HARNESS_ROOT` to the **worktree** and the two trees agreed only by luck. The failure is concrete, not
theoretical: Task 5 creates `skills/report-defect/SKILL.md`, which exists in the worktree and in **no
installed copy** (verified absent from `0.1.12`), so a report naming it would pass in the suite and be
refused in production.

**Pinning.** The suite builds a fixture harness root holding **exactly these nine files. This list
is the single authority on the fixture root's inventory — no other section re-counts it, and two of the
nine ARE the markers rather than being additional to the path fixtures, so the root is nine files, not
eleven:**

1. `.claude-plugin/plugin.json` — root marker (§ 1c); also backs r4.
2. `docs/agents-method.md` — root marker (§ 1c); backs no table row.
3. `scripts/session-events.sh` — r1, r7, and the `**Evidence:**` half of r18.
4. `scripts/check-candidate.sh` — r19; present in the fixture **root** and **not** in the fixture
   project, which is what makes "permitted, and no ambiguity warning" reachable at all.
5. `hooks/lib/harness-managed.sh` — r5.
6. `skills/inspect/SKILL.md` — r10.
7. `skills/report-defect/SKILL.md` — r11; the row that proves the pinning matters.
8. `ai-docs/context.md` — r13; also written under the fixture **project**, which is what raises the
   ambiguity warning of § 1e.
9. `AGENTS.md` — backs no table row; it is there so the fixture root reads as a plausible harness tree.

**Neither r20 nor r21 adds anything to that list, and neither must.** r21's token
`src/main/billing/Invoice.kt` is a **non-harness** path: its parenthesised form is never captured and
its bare control is refused *because the path is absent from the root*, so both halves of the row are
backed by an absence as well. Creating the file would invert the control. As for r20: its token
`scripts/deploy-prod.sh` is refused
*because* it is absent from the root, so the row is backed by an **absence** rather than by a file —
the nine-file inventory above is unchanged, and item 3's `scripts/session-events.sh` already supplies
r20's positive control (r1). Writing the file would invert the row.

The suite exports `CLAUDE_PLUGIN_ROOT` to that root, alongside a fixture project that is **disjoint**
from it. Verdicts then depend on the fixture and on nothing else. The derived branch, being production, is pinned the
same way and separately exercised: a copy of the gate is placed at `<fixture root>/scripts/` and run
with `CLAUDE_PLUGIN_ROOT` **unset**, so `$0` derives the same fixture root. Measured: identical
verdicts.

| # | Token in the report | Verdict | Role |
|---|---|---|---|
| r1 | `scripts/session-events.sh:14` | **PASS** | AC5 row 1 — the intended target; also proves the `:14` suffix needs no stripping |
| r2 | `myproject/scripts/deploy-prod.sh` | **REFUSED** — `file path`, no such path under the root | AC5 row 2 — **the measured leak, closed** |
| r3 | `server/core/Merge.kt` | **REFUSED** — `file path` | AC5 row 3 — negative control; the leg still refuses, so r1 is not a blanket pass |
| r4 | `.claude-plugin/plugin.json` | PASS | AC1 second half |
| r5 | `hooks/lib/harness-managed.sh` | PASS | no regression on a path that passes today |
| r6 | `../../etc/passwd` | REFUSED — parent traversal | **planted failure** for step 4 |
| r7 | `scripts/session-events.sh.` (sentence-final) | PASS | punctuation strip; false-refusal guard |
| r8 | `/Users/someone/acmecorp/src/Foo.kt` | REFUSED — absolute path | **planted failure** for step 3 |
| r9 | `read/write and/or client/server GET/POST input/output he/she N/A 24/7 TCP/IP` — **all nine in one body** | **PASS** | **the false-refusal row**: the prose class of § 1b, admitted without literal exemptions |
| r10 | `skills/inspect/SKILL.md` | PASS | no regression on a path that passes today |
| r11 | `skills/report-defect/SKILL.md` | PASS **only because the fixture root ships it** | the row that proves the pinning matters — it would be REFUSED against installed `0.1.12` |
| r12 | `2026/09/24` | PASS | all-numeric segments are a date, not a path claim |
| r13 | `ai-docs/context.md:14` | PASS **+ ambiguity warning on stderr** | § 1e; exit code 0, warning fires |
| r14 | `**Surface:** myproject/src/Foo.kt` | REFUSED — `file path` **and** `structure: Surface names no path that exists under the harness root` | the Surface contract, positive control |
| r15 | `**Surface:** read/write` | REFUSED — `structure` only | Surface contract against a *prose* token: passing the path leg is not enough |
| r16 | `read/write/execute input/output/error client/server/proxy he/she/they` — all four in one body | **REFUSED** — `file path`, no such path under the root | **the strict-direction residue of § 1b, pinned rather than rediscovered.** Three-or-more-term prose trips the `≥ 2 separators` clause. Task 5's drafting rule is what keeps it out of real reports |
| r17 | `services/billing` | **PASS** | **the loose-by-*classification* residue of § 1b, pinned in the contract and not only in prose** (distinct from r21, which is loose by *capture*: there the token never reaches this test at all): one slash, no extension, non-numeric → prose to this leg. The vocabulary, `KEY-123` and URL legs still run over it |
| r18 | `**Surface:** read/write` **together with** `**Evidence:** scripts/session-events.sh …` in one body | **REFUSED** — `structure` (the path leg itself says nothing: `read/write` is prose, `scripts/session-events.sh` is permitted) | **the Surface-contract discriminator.** r14 and r15 score identically under a body-scoped and a line-scoped implementation, so neither can fail the shortcut; this row fails the body-scoped one (measured rc=0) and passes the line-scoped one (rc=1). § 1a |
| r19 | `scripts/check-candidate.sh` | **PASS**, and **stderr carries NO ambiguity warning** | **the negative direction of the § 1e warning.** The token exists under the fixture root and **not** under the fixture project. r13 alone scores a warn-on-every-permitted-claim implementation as a pass; this row fails it (measured: the bad implementation warns on both). Conversely r13 is this row's falsifiability proof — the same `grep 'ambiguity warning'` on the same code path comes back non-empty there, so "no warning" is not an assertion that can never fail |
| r20 | `scripts/deploy-prod.sh` — a token whose **first segment IS a harness directory name** and which does **not** exist under the resolved root | **REFUSED** — `file path`, no such path under the harness root | **the mechanism discriminator: it separates the existence check from the rejected anchored alternation.** Under the chosen mechanism the token is refused because `${HARNESS_ROOT}/scripts/deploy-prod.sh` does not exist; under a first-segment *name* match it is permitted and **exported** (measured: shipped gate rc=1 naming the token, mutant rc=0 silent). r2 cannot stand in for it — `myproject/scripts/deploy-prod.sh` has a project noun in the first segment, so **both** mechanisms refuse it, and the whole suite scored **0 failed** at the **pre-amendment** total of 138 passed under the substitution. Its positive control is r1: the same first segment, a token that **does** exist → PASS, so "refuse everything under `scripts/`" does not score as a pass either |
| r21 | `**Evidence:** Also in (src/main/billing/Invoice.kt) here.` — a non-harness path token whose LEFT neighbour is a parenthesis | **PASS** — rc 0, no finding, **nothing on stderr** | **the loose-by-*capture* residue of § 1b, pinned rather than left implicit.** The token regex (`scripts/check-candidate.sh:138`) admits only start-of-line, whitespace or a backtick before a token, so a path preceded by punctuation is never extracted and the path leg never runs on it. Measured against the real gate in report mode: the parenthesised, double-quoted, square-bracketed, angle-bracketed and em-dashed spellings all score **rc 0, silent**, and default mode (`:239`) scores the identical five — **parity, not a regression**. Its positive control is the **same token unparenthesised**, which scores **rc 1** naming `src/main/billing/Invoice.kt (no such path under the harness root)`, so an "always pass" leg does not score as a pass; and because the two rows differ only in one punctuation character, the pair reads on the left anchor and on nothing else. The row exists so that widening the anchor later is a **deliberate, visible** change — it flips r21 and must be argued — rather than a silent one. Note the fixture project's vocabulary must not contain `src`, `main`, `billing` or `Invoice`, or the row would pass for the wrong reason — the vocabulary leg would refuse the token whatever the anchor did, and the pair would stop reading on the left anchor at all. The pinned fixture satisfies this: `mkproject reportville` gives the derived vocabulary `reportville` plus the entities `DiffSet` / `ReviewRequest`, and the `orderflow` / `ORD` registry fixture is exported only for the AC2 identifier cases, not for the path table. **The control stays inside r21 and is deliberately NOT promoted to its own row identifier:** the suite already carries an unnumbered control beside a numbered trio (`row "positive control: Surface names a harness path"` sits next to r14/r15/r18 in `scripts/test-promotion.sh`), so an unnumbered control is the established in-tree idiom and this design does not invent a second shape for the same job. It does get a **stable label in the suite's own output** — `row "r21 control: unparenthesised" …` — so deleting it shows up as a removed `ok` line in a suite diff: the visibility of a separate identifier without splitting the atomic pair |

**Alternative considered and rejected: anchoring the alternation at the start of the token**
(`grep -vE '^(ai-docs|scripts|docs|skills|...)/'`). It reproduces the three spec rows, so the spec
would admit it. It is rejected because it is a *name* match: it permits any first segment spelled like
a harness directory, so a consuming project that has its own `scripts/`, `docs/` or `agents/`
directory — which is most of them — gets every path under it exported. It closes the exact fixture and
leaves the class open. The existence check is the same cost and closes the class.

**That rejection is now pinned by a row rather than argued in prose only — which is the whole reason
r20 exists.** It was argued in prose here through four review rounds while the suite could not tell the
two mechanisms apart: substituting the anchored alternation for the existence check at
`scripts/check-candidate.sh:147` left `scripts/test-promotion.sh` at **0 failed**, at its
pre-amendment total of 138 passed. **All nineteen rows that existed at that point (r1–r19)**, and not
one of them read on the central decision of § 1a. The gap is structural, not an
oversight in row selection: every row that involves a project path puts a project noun in the FIRST
segment (r2, r3, r14), which both mechanisms refuse, and every row with a harness first segment names a
token that EXISTS (r1, r4, r5, r7, r10, r11, r13, r19), which both mechanisms permit. The uncovered quadrant —
harness-shaped first segment, token absent from the root — is exactly r20, and it is the only shape in
which the two mechanisms disagree. A prose-only rejection is a decision the next change can undo
silently; a row is one it cannot.

### 1e. Coincident spellings — and why the earlier justification for tolerating them was wrong

The existence check permits a project path whose spelling *coincides* with a real harness path. An
earlier draft dismissed this on the grounds that "the only string that escapes is simultaneously a
harness file name, so it carries no project-specific information." **That is true of the string and
false of the referent, and the difference is the whole point of the channel.** The installed tree
ships `ai-docs/context.md`, `AGENTS.md`, `CLAUDE.md`, `ai-docs/learnings.md`, `ai-docs/learnings/`,
`ai-docs/plans/` — all verified present in `0.1.12` — and `ai-docs/context.md` is **the** project-data
file in every consuming project. So `Surface: ai-docs/context.md:14` *meaning the project's file*
passes, and arrives indistinguishable from one about the harness. It misroutes triage, which is the
channel's purpose. This is parity with today rather than a regression, but it may not stand as a
justification, because the next change will be built on it.

**Rejected mitigation: refusing the ambiguous token.** Measured against the installed tree,
`ai-docs/learnings/.promote/` exists in the harness *and* in every consuming project — and a defect in
the promotion channel is among the likeliest reports this channel will ever carry. An ambiguity
refusal would false-refuse it. Rejected on evidence, not on taste.

**Chosen mitigation, three parts, each mechanical:**

1. **Structural.** `**Surface:**` must carry a path claim that exists under the resolved harness root,
   **evaluated over the `**Surface:**` line only** (§ 1a, the requirement stated after step 7; rows
   r14, r15, and **r18**, which is the only one of the three that fails a body-scoped implementation —
   without it this mitigation can be silently voided while the suite stays green). `Surface` is
   *definitionally* a harness path — the
   ambiguity is reduced to a drafting error rather than an open question about what the field means.
2. **Advisory in the gate, mandatory in the skill — and therefore consumed.** A permitted claim that
   also exists under `PROJECT_DIR` raises a named stderr warning — "exists in BOTH the harness and
   this project" — with the exit code untouched. **Both directions are pinned as rows**: r13 (warning
   fires, `rc=0`) and **r19** (`scripts/check-candidate.sh` permitted, `rc=0`, **no** warning). r13
   alone would score a warn-on-every-permitted-claim implementation as a pass, and r19 is what fails
   it. A warning nothing reads is not a
   mitigation, so it has a **named consumer**: `SKILL.md` (Task 5) carries the instruction that **a
   Surface ambiguity warning must be resolved — by rewriting `Surface` to a harness path that is
   unambiguous, or by confirming in one line which tree is meant — BEFORE the report is shown to the
   user for approval.** That instruction is asserted by a non-empty grep in the AC7 group (the shape
   already measured falsifiable: `grep -n 'ambiguity warning' skills/report-defect/SKILL.md` returns a
   line on a file that carries it and rc=1 on one that does not). The nudge lands at draft time, on the
   agent that knows which file it meant, which is the only place the ambiguity is resolvable — and now
   it lands on a step that is obliged to act on it.
3. **Provenance.** `file-report.sh` stamps into the filed issue body the resolved harness `version`
   **and which branch resolved the root** (`CLAUDE_PLUGIN_ROOT` override vs `$0`-derived), so a
   triager can see which tree the `Surface` was checked against instead of inferring it.

Plus the drafting rule in `SKILL.md`: **`Surface` names the harness file that is at fault; a project
file that was merely affected is described in words in `Evidence`, never as a path.**

**Third residual limit.** On a case-insensitive filesystem, `SCRIPTS/session-events.sh` satisfies
`[ -e ]`. The escaping string is still a harness path spelling; the § 1e argument applies to it too.

### 2. The project-dir derivation — a measured silent failure, and the belt-and-braces fix

`check-candidate.sh` derives `PROJECT_DIR` from the candidate's own depth, hardcoded to the
`.promote/` layout: `dirname "$FILE"/../../..`. A report lives at `<proj>/ai-docs/feedback/<file>.md`,
which is **one level shallower**. Measured consequence, on a fixture project whose
`ai-docs/context.md` declares the entity `DiffSet`:

- report at `.../acmeproj/ai-docs/feedback/r.md` containing `A DiffSet must not be mutated.`
- run with no `--project-dir` → derived root is `.../deriv` (the parent of the project) → **exit 0,
  no output**: the domain entity was exported.
- same file, `--project-dir .../acmeproj` → `REFUSED … project identifier: DiffSet`.

This is the exact failure shape this repo names as worse than an absent gate: a check that runs, says
nothing, and cannot fire where it matters. It would have shipped green under any test that passes
`--project-dir`, which every existing test does. Three independent guards:

1. **Report mode derives `dirname "$FILE"/../..`** — correct for the `ai-docs/feedback/` layout.
2. **Report mode validates the derivation and dies loudly (exit 2) if it does not hold** — the file
   must sit under `<derived>/ai-docs/feedback/`, and `<derived>/ai-docs` must be a directory.
   A derivation that cannot be confirmed is a usage error, never a silent pass.
3. **The skill always passes `--project-dir` explicitly**, so the derivation is a backstop for
   hand-runs rather than the primary path.

The three are genuinely independent — guard 1 is correctness, guard 2 is loud failure, guard 3 is the
production path — and **each therefore needs its own assertion.** The earlier draft asserted only
guard 1, which means deleting guard 2 would have left the suite green. That is the exact shape this
branch already shipped once, so it is not a hypothetical objection.

| Guard | Assertion | Measured |
|---|---|---|
| 1 | report at `<proj>/ai-docs/feedback/r.md` naming a `context.md` entity, **no** `--project-dir` → REFUSED, `DiffSet` named | yes — the § 2 fixture above; a **planted failure**, not a clean pass |
| 2 | report at `<proj>/ai-docs/feedback/**sub**/r.md`, **no** `--project-dir` → **exit 2**, reason named; explicitly **not 1** and **not 0** | yes — `derived project dir <proj>/ai-docs does not hold … at ai-docs/feedback/; pass --project-dir`. Without guard 2 the derivation lands on `<proj>/ai-docs`, the run goes green, and guard 1's case still passes |
| 3 | `grep -n -- '--project-dir' skills/report-defect/SKILL.md` returns **non-empty** | folded into AC7's verification |

Guard 1 without guard 2 would be the same bug pointed one level the other way the first time someone
puts a report somewhere else — and guard 2's case is the one that proves the failure is *loud* rather
than merely *different*, since a wrong-but-plausible derivation would exit 1 and look like a working
gate.

### 3. Mode selection and the structure leg

A new flag `--mode rule|report`, defaulting to `rule`. Verified that every existing caller —
`scripts/collect-candidates.sh`, `skills/improve/SKILL.md`, `skills/improve-global/SKILL.md`,
`skills/ai-audit/reference.md`, `.promote/README.md` — invokes the gate with no mode flag, so the
default keeps AC4 by construction rather than by care. An unrecognised `--mode` value exits 2.

Report mode swaps the structure list: frontmatter (unchanged mechanism) plus `**Symptom:**`,
`**Repro:**`, `**Expected:**`, `**Surface:**`, `**Evidence:**`. It additionally requires the
frontmatter keys `harness_version:` and `hash:`, which is what makes AC9 structural rather than a
promise about what the drafter remembered to include, and it requires `**Surface:**` to carry a
permitted harness path claim (§ 1a, § 1e). The `**Rule:** / **Why:** / **Signal:**` requirement does
not run in report mode.

**Known limit of "structural", recorded so the next change does not over-read it.** The two
frontmatter-key checks are whole-**body** substring tests — the same `case "$BODY" in *"…"*` shape as
the five existing section checks (`scripts/check-candidate.sh:157-158`), which is exactly why § 3 can
call the mechanism unchanged. So a report that writes `hash:` in its prose but omits it from the
frontmatter passes the leg. **This is parity with the existing checks, not a regression, and it is
deliberately NOT fixed here**: narrowing these two keys to a frontmatter-scoped test while the five
section checks stay body-scoped would put two spellings of "structure" in one gate. What AC9 buys is
therefore "the key is present somewhere in the file", not "the key is present in the frontmatter" —
enough to stop a silently key-less report, and the guarantee a later change should start from.

**Apart from the structure leg described just above, the path leg is the ONLY findings-producing leg
that branches by mode.** The exception is named in the sentence rather than left to the paragraph that
follows, because an unqualified "ONLY" is a claim this document's own next paragraph has to walk back
— and a contract a reader has to repair as they go is not a contract. Every other leg is untouched and
runs in both:
derived vocabulary (project dir name, registry `name`, ticket prefix, `context.md` entity headings,
`deny-extra.txt`), the `KEY-123` structural check, and the URL-host check. That is AC2, and it is
satisfied by *not* branching, which is the cheapest way to satisfy it and the only way that cannot
drift. Naming the branch narrowly matters for AC4: the default mode's path leg — alternation, two
literals, no existence check, no path-claim test, `../../..` derivation, no harness root at all — is
reached only when `--mode` is absent or `rule`, and every existing caller is in that case (verified
above).

**Scope of that claim — it is about CHECKS, not about the script's output.** A "leg" here is a
findings-producing check: something that can add to `findings` and therefore decide the exit code. The
sentence is read narrowly on purpose, and it has to be. The structure leg described two paragraphs
above **also** branches by mode — that branch is the subject of this section, not a counterexample to
it — which is why the sentence now carries the exception in its own text rather than relying on this
paragraph to supply it. What the claim actually forbids is a **second identifier check** that
behaves differently in the two modes: that is the drift AC2 exists to prevent, because an identifier
check which is weaker in report mode is a silent export, and one which is weaker in rule mode is a
silent regression of AC4.

The refusal **trailer** is outside that claim entirely. It adds no finding, is printed only after the
verdict is already decided, and cannot change an exit code in either direction — `QUIET` already
suppresses it without altering the result. So making the trailer mode-aware (§ 3a) is not a second
thing that varies by *mode* in the sense the claim is about, and the sentence stands unamended. The
cost of the narrow reading is that it is easy to misread later, which is why this paragraph exists and
why § 3a's behaviour is pinned by two assertions rather than left to the reading.

### 3a. The refusal trailer — the gate currently tells a report drafter to do what the skill forbids

**Measured, on a report-mode refusal against the pinned fixture root.** After the finding, the gate
prints (`scripts/check-candidate.sh`):

```
  Rewrite the lesson so it names the SHAPE of the failure, not the instance.
```

Two faults, and the second is the one that decides this section:

1. **Wrong noun.** The payload in report mode is a defect report, not a lesson.
2. **It instructs a rewrite-and-retry, which is the loop the spec forbids.** Spec AC8 requires that the
   skill "aborts without retrying … No rewrite-and-recheck loop exists in the skill's instructions",
   `skills/report-defect/SKILL.md` § FORBIDDEN lists "rewriting the report to get past a refusal", and
   § 7's whole division of labour rests on the gate being a boundary rather than something a drafter
   may iterate against. So the most authoritative-looking source in the transcript — the tool's own
   stderr — currently issues the opposite instruction to the one the skill carries.

   **Scope, stated so the next reader does not over-read it.** AC8's literal subject is *the skill's
   instructions*; the gate's stderr is not one of them, so AC8 is already satisfiable without touching
   the trailer. t1 is therefore a guard this design **adds beyond** the spec AC, not a sign the spec
   was written wrong — see the AC8 row of § Test Design. **No spec amendment follows from this
   section.**

**Decision: the trailer becomes mode-aware; rule mode keeps its line byte-for-byte.**

```sh
if [ "$MODE" = report ]
  then printf '  Do not rewrite the report to get past this. Abort, name the term above, and let the user decide.\n' >&2
  else printf '  Rewrite the lesson so it names the SHAPE of the failure, not the instance.\n' >&2
fi
```

**The two rejected options, and why neither survives contact with the measurement.**

- *Leave it and argue AC8 survives anyway.* The argument would be that AC8 is a property of
  `SKILL.md`, which is asserted by grep, and that the gate's stderr is advisory. It fails on the
  channel's own terms: the skill's Step 3 hands the agent a refusal and the agent reads the gate's
  output in the same breath. An instruction that contradicts the skill, emitted by the thing the skill
  just invoked, is the single likeliest way the forbidden loop gets run — and it would be run
  *without* any instruction file having been edited, so no review of `SKILL.md` would ever catch it.
  This design refuses that shape everywhere else (§ 2's silent derivation, § 5's silent duplicate); it
  cannot accept it here because the fix is four lines.
- *Make the trailer mode-aware and leave it unasserted.* Rejected under this document's own rule: at the
  time of writing the string was **unasserted by any test, in either mode** — t1 and t2 below are
  the assertions this section adds, and they are what change that. That is a narrower statement than "the
  string occurs once in the tree", which an earlier draft of this document asserted and which is
  **false**. What was actually run, and what each command returned — **every count in the four
  bullets below was measured BEFORE this increment.** t1 and t2 add the string to
  `scripts/test-promotion.sh` (`:125` and `:228`), so the first, second and fourth bullets now read
  four hits, five hits and `scripts/test-promotion.sh:2`. That rise is exactly what this section
  prescribes; the third bullet's **zero** is the one that has to stay zero, and it does:

  - `grep -rn 'Rewrite the lesson' scripts/ skills/ docs/` → **two** hits:
    `scripts/check-candidate.sh:260` (the `printf`) and `skills/improve/SKILL.md:118`. **Both of those
    are counts of a four-word *substring*, and the second is not a copy of the trailer** — see the
    next bullet.
  - `grep -rn 'Rewrite the lesson\|SHAPE of the failure' scripts/ skills/ docs/` → **three** hits: the
    two above, plus `skills/improve/SKILL.md:111` (`Write the SHAPE of the failure, never the
    instance.`).
  - The **full-sentence** probe, which is the one that settles whether either file quotes the other:
    `grep -rn 'Rewrite the lesson so it names the SHAPE of the failure, not the instance' --include='*.md' skills/ docs/`
    → **zero hits**. Positive control for the same command form:
    `grep -rn 'never edit the gate' --include='*.md' .` → `skills/improve/SKILL.md:118`, so the probe
    is proven able to come back non-empty and its empty result is a finding rather than a mis-filtered
    search.
  - `grep -rc 'Rewrite the lesson'` over the twelve test scripts in the tree
    (`hooks/lib/test-harness-managed.sh`, `scripts/test-*.sh`, `skills/*/scripts/test-*.sh`) → one line
    per file, **every line `:0`**. The probe is proven able to come back non-zero: the identical
    `grep -rc check-candidate` over the same twelve files prints `scripts/test-promotion.sh:5`. The
    `-rc` form is deliberate — an assertion whose evidence is *empty* grep output is the shape this
    repo forbids, so the evidence here is a non-empty listing whose **contents** are the finding.

  A behaviour change with no assertion is the shape every other section of this design was rewritten to
  remove.

  **The second hit is a paraphrase, not a quotation — and the distinction changes what t2 is for.**
  `skills/improve/SKILL.md` instructs the promoting agent to do what the trailer advises, but it does so
  **in its own words**, across two non-adjacent lines: `:111` *"Write the SHAPE of the failure, never
  the instance."* and `:118` *"A refusal names the offending term. **Rewrite the lesson; never edit the
  gate…**"*. Different verb (`Write` / `names`), different negation (`never` / `not`), different order,
  seven lines apart. The full-sentence probe above returns **zero hits**: **no verbatim copy of the
  trailer exists in either direction.**

  So the correct reason t2 pins the rule-mode line **byte-for-byte** is the simple one, and it is
  self-sufficient: **AC4 requires default-mode behaviour to be unchanged**, and byte-for-byte is what
  "unchanged" means for an observable string. That reason stands on its own and depends on no other
  file.

  Separately and **more weakly**, there is a real coupling worth naming at its real strength: rewording
  the `printf` would leave `skills/improve/SKILL.md` describing advice the gate no longer gives — it
  desynchronises a **description**, not a quotation. This is a documentation-consistency hazard, not a
  contract break, and it is **not** what t2 detects. See the honest statement of t2's reach below.

**Why rule mode is not touched.** Its trailer is correct there: `skills/improve/SKILL.md:118` tells the
promoting agent "a refusal names the offending term. **Rewrite the lesson**; never edit the gate" — so
in rule mode rewrite-and-recheck is the *documented* workflow, and the two modes genuinely want
opposite advice. That asymmetry is the reason the trailer branches rather than being replaced by one
neutral sentence that would be wrong for both.

**This is the same `skills/improve/SKILL.md:118` counted in the grep above** — the file is both the
reason rule mode wants the opposite advice *and* the second hit that makes the four-word *substring*
non-unique. The two facts are one fact.

**What t2 can and cannot see, stated honestly.** t2 asserts the rule-mode line **byte-for-byte** rather
than merely asserting that *a* trailer is printed because **AC4 requires default-mode behaviour to be
unchanged**, and only a byte-for-byte assertion can see an "unchanged" string change. That is the whole
of t2's subject. **t2 pins the gate's half only.** Because `skills/improve/SKILL.md` holds no copy of
the string, **no assertion on the gate's stderr can detect that file drifting** — a reword of the
skill's paraphrase leaves t2 green, and always will. The skill-side consistency is maintained by review,
not by this test, and this design does not claim otherwise.

**Pinned in both directions, and neither assertion can be satisfied by deleting the other:**

| # | Case | Assertion | Measured |
|---|---|---|---|
| **t1** | any report-mode refusal (r20's body reused) | stderr **carries** `let the user decide` **and does NOT carry** `Rewrite the lesson` | yes — prototype rc=1 printing only the report line; **falsifiable**: today's shipped gate prints `Rewrite the lesson` on the identical input, so t1 is red before the change |
| **t2** | any rule-mode refusal (an existing `refuse()` case) | stderr **carries** `Rewrite the lesson so it names the SHAPE of the failure, not the instance.` **and does NOT carry** `let the user decide` | yes — prototype output byte-identical to today's; **falsifiable**: a gate with the trailer deleted prints neither line and t2 goes red (measured on a trailer-stripped copy) |

t1's "must not" is what fails "leave it alone"; t2's "must" is what fails "just delete the trailer";
t2's "must not" and t1's "must not" together fail "print both lines always". The `row` helper in
`scripts/test-promotion.sh` already takes a *must-name* and a *must-not-name* argument (used by r15 and
r19), so t1 needs no new harness; t2 is an assertion added beside an existing rule-mode refusal case.

**AC4 is untouched**, and now more strongly than before: the default mode's observable output is
byte-identical, and t2 is the first assertion in the tree that says so. Whole-suite regression measured
with the change applied: `bash scripts/test-promotion.sh` → **0 failed**, at this branch's
**pre-amendment** total of 138 passed. The total is deliberately not the invariant — r20, r21, t1 and
t2 each add assertions and raise it. What must hold is `0 failed` **and** the 25 pre-existing
assertions inherited from `main` (measured there: `25 passed, 0 failed`) all still present and green.

### 4. Idempotency hash — open question 1

**Decision: a narrow stable key — normalised `Surface` (with any `:<line>` suffix stripped) plus
normalised `Symptom`, SHA-256, first 12 hex characters.**

Normalisation: `LC_ALL=C`, lowercase, every non-`[a-z0-9]` byte to a space, runs collapsed, trimmed.
`LC_ALL=C` is not decoration — without it `tr -c` is unreliable on multi-byte input, and defect
reports contain em-dashes.

Measured behaviour of the prototype:

| Pair | Result | Why it is the wanted behaviour |
|---|---|---|
| same Surface + Symptom, **rewritten Repro** | **same hash** | catches the real failure mode: an agent redrafting the same defect in new words |
| same text, different case/punctuation/whitespace | same hash | normalisation holds |
| same Surface, `:109` → `:117` | **same hash** | a line number is volatile metadata, not identity |
| different Symptom | different hash | distinct defects in one file stay distinct |
| different Surface | different hash | |
| same input, 3 runs | identical | deterministic |

**Tradeoff recorded.** The narrow key is the right call against the *whole normalised report* because
the thing it must stop is a re-file, and a re-file is almost never byte-identical — a whole-report
hash would collide only with a copy-paste and would therefore stop nothing real. The cost is that two
genuinely different defects sharing a file *and* a symptom wording collide; the Symptom text, not just
the file, is in the key precisely to make that narrow, and a false stop is visible and overridable — see
§ 5, where the override stops being an unwritten escape hatch and becomes something `check` prints,
`SKILL.md` documents and the suite asserts. The opposite error — a duplicate issue on the harness —
is silent and accumulates.

The harness version is deliberately **not** in the key: the same defect surviving an upgrade is still
the same defect and should not re-file. The version of the first filing is recorded in the ledger —
and, per § 5, printed on every stop, because an upgrade is exactly when a stop needs explaining.

The ledger is per-project, so there is no cross-version collision to worry about: two projects on two
harness versions keep two ledgers. What *does* arise is narrower and real — after an upgrade, a
re-file of a still-live defect is stopped and pointed at an issue that may have been closed against an
older version. § 5 is what makes that recoverable rather than a dead end.

### 5. Where "already filed" lives, and the URL — open question 2

**Decision: a separate ledger, `ai-docs/feedback/filed.json`, keyed by hash; the issue URL lives only
there, never in the report `.md`.**

The obvious carrier — stamping the issue URL back into the report's frontmatter — is wrong, and the
reason is mechanical rather than aesthetic: the gate's URL-host leg refuses any `https?://`. A report
that is gate-clean at filing time would become permanently gate-refused the moment it recorded where
it went, so the artefact could never be re-checked. Splitting the ledger out keeps the report file
gate-clean for its whole life and keeps the one file that carries a URL off the gate's input entirely.

Shape (`filed` keyed by hash, so a lookup is one `jq` and never a scan):

```json
{"version": 1,
 "filed": {"522bbda40920": {"issue": "https://github.com/<owner>/<repo>/issues/31",
                            "title": "...", "report": "2026-09-24-<slug>.md",
                            "harness_version": "0.1.17", "filed": "2026-09-24"}}}
```

Committed with the project, mirroring `.promote/README.md` lifecycle step 3 — the ledger is the
evidence the report has a destination. Nothing is added to `templates/project/gitignore.snippet`.

**What the two READS do with a ledger that is not a clean hit — specified, because the naive lookup
cannot tell four different situations apart.** Measured, with `jq -r --arg h "$H"
'.filed[$h].issue // empty'`:

| Ledger state | stdout | `jq` rc | What the naive form concludes |
|---|---|---|---|
| valid, hash present | the URL | 0 | already filed — correct |
| valid, hash absent (`{"filed":{}}`) | **empty** | 0 | proceed to `gh` — correct |
| **zero-byte file** | **empty** | 4 | proceed to `gh` — **wrong** |
| **truncated / unparseable** | **empty** | 5 | proceed to `gh` — **wrong** |
| **absent file** | **empty** | 2 | proceed to `gh` — right answer, wrong reason |

Four inputs, one indistinguishable verdict, and the `2>/dev/null` that a lookup of this shape normally
carries discards the one signal that separates them. A corrupt ledger is therefore a **silent
duplicate filing**, and the success-path write that follows it then **clobbers a file committed with
the project**. So the two states are separated explicitly, before the lookup, by the same doctrine
§ 1c and § 2 apply to the two derivations — *a state that cannot be confirmed is a usage error, never
a silent pass*:

- **Absent ⇒ treated as empty, and CREATED by `file` on its first success.** This is the first run in
  every project and must not be an error. `check` prints nothing and exits 0. No read is attempted.
- **Present but not a readable ledger ⇒ exit 2 with a named reason, never a proceed and never a
  write.** The test is `jq -e 'type == "object" and (.filed | type) == "object"' "$LEDGER"
  >/dev/null 2>&1`, which is the one form that catches all four damaged shapes at once. **The
  discriminator's own stderr is suppressed, and the named reason is the script's, not `jq`'s** — on a
  damaged ledger `jq` writes its own diagnostic (measured: `jq: parse error: Unfinished JSON term at
  EOF at line 1, column 49`), and unsuppressed the user would read that raw trace beside the reason
  this design promised. `2>/dev/null` here is safe in the way the naive lookup's was not: this call is
  run *for* its exit status and the status is what is branched on, so suppression discards no signal.
  Measured: zero-byte → 2, truncated → 2, a literal
  `null` → 2, a `{"version":1}` with no `filed` key → 2; `{"version":1,"filed":{}}` → 0 and
  `{"filed":{"<hash>":…}}` → the hit. A `filed`-less object is hand-damage, not a state the `file`
  verb can produce, so refusing it is right.

This also resolves the ambiguity in `check`'s "empty ledger" case, which previously did not say whether
it meant absent or `{"filed":{}}`: **both are exit 0, and they are two separate test cases.**

**The write is what AC10 actually rests on, and it needs its own assertion.** Every `check`/`file` case
otherwise PRE-SEEDS `filed.json`, so a `file` verb that never writes the ledger would pass the whole
suite and fail AC10 only in production — one unverified link swapped for another, the shape this
section exists to close. On a `gh` success, `file` creates the ledger if absent and sets
`.filed[<hash>]` to an object carrying `issue`, `title`, `report`, `harness_version` and `filed`,
written through a temp file and `mv` so a killed run cannot leave a half-written ledger. Measured
end-to-end against a recording `gh` stub, three runs:

| Run | Input | Result |
|---|---|---|
| 1 | ledger **absent**, hash not filed | `gh` invoked **once**; ledger created; the row's `issue` and `harness_version` match what was filed |
| 2 | **same hash again**, same ledger | refused, `gh` total **still 1** — zero further invocations — decided **only** from the ledger run 1 wrote |
| 3 | **truncated** ledger | **exit 2**, `gh` **not** invoked, file **byte-identical** afterwards |

Run 2 is the one that closes the gap: it never touches a pre-seeded fixture, so it fails an
implementation that reads the ledger correctly but never writes it.

**What `check` prints on a hit, and why the override is part of the design rather than an aside.** The
earlier draft leaned on "overridable by deleting the ledger row", which appeared in no AC, no test and
no `SKILL.md` instruction — an escape hatch that exists only in a design document is not an escape
hatch. On a hit, `check` exits non-zero and prints **three** things, all from the ledger row:

```
already filed: https://github.com/<owner>/<repo>/issues/31
  filed against harness_version 0.1.15   (this run: 0.1.17)
  if the defect is still live on this version, re-file by removing the
  "522bbda40920" entry from ai-docs/feedback/filed.json, then run again
```

The recorded `harness_version` next to the current one is what turns "stopped, and I don't know why"
into "stopped by a filing from two versions ago, which may have been closed" — the upgrade case above.
All three lines are asserted in the Task 4 case that already covers `check` on a hit, and the override
is repeated as an instruction in `SKILL.md` (Task 5). Removing a row is the deliberate, visible,
user-performed act the `.promote/` doctrine wants; there is no `--force` flag, because a flag on the
filing script is a thing an agent can reach for and a hand-edit is not.

**The stop lives in `file` as well as in `check`, because AC10 is a system property.** An earlier
draft put the ledger read only in `check`, which made "the same defect is never filed twice" rest on
the skill remembering to call `check` before `file` — an unverifiable claim about agent behaviour,
which is exactly the shape § 7 rejects for AC11 and AC12. No sequencing instruction can be asserted
mechanically, and Task 5 pins no check-then-file order. So:

**`file` re-reads the ledger as its first act and refuses on a hit with the same three-line message**,
before any `gh` invocation and before the body is built. `check` stays — it is the cheap pre-flight
that lets the skill stop before drafting work is wasted — but it is now an optimisation, not the
guard. With no `--force` flag this is also the consistent choice: the single documented override
(remove the ledger row) is the same for both verbs, so the two cannot disagree.

Measured, with a recording `gh` stub on `PATH`: against a ledger already holding the hash, `file`
exits 1, prints the three lines, makes **0** `gh` invocations, and leaves the ledger byte-identical;
the negative control — the same call with a hash the ledger does not hold — invokes `gh` once and
exits 0, so the guard is not a blanket refusal.

### 6. Skill name — open question 3

**Decision: `/harness:report-defect`, directory `skills/report-defect/`.**

Rejected: `/harness:feedback` (reads like a satisfaction survey and does not say the payload is a
defect); `/harness:report` (collides conceptually with review and audit reports, of which this repo
has several); `/harness:file-issue` (names the transport, and the transport is the one part the spec
says may change); `/harness:harness-report` (stutters against the `harness:` prefix). `report-defect`
is also unambiguous against `/harness:bugfix`, which fixes a bug in *your* project, and against
`/harness:inspect`, which finds harness defects but cannot send them anywhere.

### 7. Division of labour: what is a script and what is an instruction

The filing itself lives in **`skills/report-defect/scripts/file-report.sh`** with three verbs
(`hash`, `check`, `file`), not in prose in `SKILL.md`. This is the decision that makes AC9, AC11 and
AC12 *testable* instead of trusted:

- **AC9** — the script reads `repository` and `version` from `<harness root>/.claude-plugin/plugin.json`.
  It resolves that root exactly as the gate does (§ 1c): **`dirname "$0"/../../..` is the primary,
  production branch** — the depth verified for a `skills/<name>/scripts/` script, and measured as the
  only branch that runs, since `CLAUDE_PLUGIN_ROOT` and `CLAUDE_SKILL_DIR` are unset inside a Bash
  call — with `${CLAUDE_PLUGIN_ROOT}` honoured as an override and the same marker validation applied
  to both. A fork files against itself because the read is the only source, not because the drafter
  was reminded.
- **Provenance (§ 1e part 3)** — the emitted issue body carries the resolved `version` *and* which
  branch resolved the root, so a `Surface` can be read against a known tree. This is a two-line
  addition to the body the script already builds, not a new mechanism.
- **AC11** — the title prefix is emitted by the script, so it cannot be forgotten.
- **AC12** — a `gh`-absent run is a real test case (measured: a `PATH` stub that keeps `jq` and drops
  `gh` exercises the branch), instead of an unverifiable claim about what an agent would do.

`SKILL.md` keeps exactly what a script cannot own: drafting the report generically, showing it to the
user, and obtaining explicit approval. The boundary of the `.promote/` doctrine is preserved — the
script is only invoked *after* approval, and it never drafts.

**Channel marker: a title prefix `[harness-feedback]`, and no label.** Defended, not merely adopted:
`gh issue create --label` fails when the label is absent from the target repo, and scope item 5 makes
failure loud, so a missing label would abort a filing that had nothing wrong with it. A best-effort
post-create `--add-label` was considered and rejected as YAGNI — it would create two selection queries
where one suffices, and the second would be silently incomplete. Verified that the marker query shape
runs against the target repo, and verified in the other direction that the same query shape returns
non-empty when something matches (searching an existing title token returned issues), so the
selection mechanism is not an empty-output gate that has never been shown able to fire. **The count is
deliberately not recorded** — it is a property of the repository's live issue list on the day it was
run, not of the mechanism, and pinning it would date the design for no gain. The property is
"non-empty is reachable", and that is what was measured.

- **AC10** — the duplicate stop is enforced by the `file` verb itself (§ 5), so it is a property of the
  script rather than of the order in which the skill happens to call two verbs. Asserted by a case in
  which the ledger already holds the hash: `file` exits non-zero, a recording `gh` stub logs **zero**
  invocations, and the ledger is byte-identical afterwards.

**No pre-filing search.** The spec forbids it and the duplicate stop is local (the ledger). AC10 is
satisfied without any network read.

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | Add `--mode rule\|report` to the gate: report-mode section list (+ required `harness_version:` / `hash:` frontmatter keys + `**Surface:**` must carry a permitted harness path claim), report-mode path leg (token regex widened **only** to capture a leading `/` — the LEFT anchor stays as default mode's, per § 1b's *loose by capture* direction and row r21 — trailing punctuation strip, absolute + `..` refusal, **path-claim test**, existence check under `HARNESS_ROOT`, **ambiguity warning**), **harness-root resolution with `$0` primary and marker + disjointness validation (exit 2)**, report-mode project-dir derivation (`../..`) with loud exit-2 validation, **and the mode-aware refusal trailer of § 3a** (report mode says abort-and-tell-the-user; rule mode keeps its line byte-for-byte). Default mode byte-for-byte unchanged. | `scripts/check-candidate.sh` | — |
| 2 | Gate tests, **all against a fixture harness root the suite builds and pins** (§ Test Design): AC1 (both paths, both modes), AC2 (seven identifier classes, each an observed refusal), AC3 (each of five sections missing in turn, **plus `harness_version:` and `hash:` omitted in turn**), AC5 (the fixture triple), the 21-row path table including the **nine-pair prose false-refusal row**, all **three** residue rows (**r16 strict, r17 loose-by-classification, r21 loose-by-capture — r21 with its unparenthesised control, which keeps r21's identifier, carries the stable output label `r21 control: unparenthesised`, and requires a fixture project whose derived vocabulary holds none of `src`, `main`, `billing`, `Invoice`**), all three Surface-contract rows (**r14, r15 and r18 — r18 being the only one that fails a body-scoped implementation**), **r19, the no-warning negative**, and **r20, the mechanism discriminator — the only row that separates the existence check from the rejected anchored alternation, under which every other row scores identically and the whole suite stays at 0 failed**, the **two trailer assertions t1 and t2 of § 3a**, the five harness-root planted failures of § 1c (unmarked root, unresolvable root, root == project, root strictly containing the project, and the **symlinked project**) plus the **two** negative controls (disjoint project, shared-prefix sibling), the derived-`$0` branch, and **separate assertions for project-dir guards 1 and 2**. | `scripts/test-promotion.sh` | 1 |
| 3 | Register the `ai-docs/feedback` project-data root: `DOC_ROOTS`, the § Agent Docs table row, and the matching verbose body. | `scripts/check-references.sh`, `docs/agents-method.md`, `docs/agent-docs-index.md` | — |
| 4 | `file-report.sh` (`hash` / `check` / `file`) + its test suite; **`file` re-reads the ledger first and refuses on a hit before any `gh` call** (§ 5); **an absent ledger is empty and is created by `file` on first success, an unparseable one is exit 2 with a named reason and no write** (§ 5); **the success path writes the row** (hash / issue / `harness_version`); `check`-on-a-hit prints **URL + recorded `harness_version` + the override instruction**; `file` stamps **version and root-resolution branch** into the issue body. Register the suite in AGENTS.md § Build & Test item 4. | `skills/report-defect/scripts/file-report.sh`, `skills/report-defect/scripts/test-file-report.sh`, `AGENTS.md` | — |
| 5 | The skill: frontmatter + `allowed-tools`, drafting rules (write generically from the start; never name the local report path, never paste a URL; **`Surface` names the harness file at fault, an affected project file is described in words in `Evidence`**; **slash-joined runs of three or more words are written as separate words — "read, write and execute", never `read/write/execute`**, per § 1b / r16), **resolve any Surface ambiguity warning before the show-and-approve step** (§ 1e part 2), gate invocation with **explicit `--project-dir`**, abort-on-refusal with no retry loop, show-and-approve, the **ledger-row override** instruction, then the script. ≤ 200 lines. | `skills/report-defect/SKILL.md` | 1, 3, 4 |
| 6 | Delivery: bump `.claude-plugin/plugin.json` patch version; add `report-defect` to the hardcoded skill inventory in the install smoke test, **and assert that `docs/agents-method.md` and `.claude-plugin/plugin.json` are present in the installed tree** (§ Test Design, Task 6). | `.claude-plugin/plugin.json`, `scripts/test-install-smoke.sh` | 5 |

**Task 1's natural seam, recorded but NOT taken.** Task 1 is the largest item here, and if it proves
too large to land as one change the seam is **harness-root resolution + validation (§ 1c)** versus
**the report-mode path leg (§ 1a, § 1b)**. The first is a precondition of the second — the existence
check has nothing to check against until a validated root exists — and it carries its own five planted
failures plus two controls, so it is independently verifiable rather than a fragment. The
decomposition is **left at six tasks**: splitting pre-emptively would add a handoff boundary and a
second round of fixture setup for a size problem that has not been observed. This is recorded so a
later split is a known seam rather than an improvisation.

Task 6 is not bookkeeping, and it now covers two gaps rather than one. `scripts/test-install-smoke.sh`
enumerates skills by name in a hardcoded loop; a new skill that is not added to it is never proven to
load in an installed copy — the exact class of bug that delivery gate was written for. It also
enumerates **components only** — skills, agents, hook events — and asserts nothing about the files an
install actually contains. That leaves a hole this branch opens: report mode's marker check requires
`docs/agents-method.md` and `.claude-plugin/plugin.json` *in the install*, so if either stopped
shipping, every production report-mode run would exit 2 "not a harness install" while the pinned test
suite — which builds its own fixture root — stayed green. Pinning removed one blind spot and would
otherwise have left this smaller one. Measured install layout and both directions of the assertion are
in § Test Design, Task 6.

## Handoff plan

`M = 6` → two groups of 3. Non-terminal groups are exactly 3; the terminal group is 3, inside the
permitted `1..3`.

- **Handoff into Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` before starting subtask 1.
- **Group A:** subtasks 1–3 — the gate mode, its tests, and the documented-root registration. Group A
  is self-contained: nothing in it depends on the skill existing.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. The parent `/task` resumes in Group B with
  fresh context.
- **Group B:** subtasks 4–6 — the filing script and its tests, the skill, and delivery. Terminal group
  (3 subtasks; within the 1..3 range). Step 8 completes inside this group's own `/context-reset`
  subagent.

## Risks

- **The existence check refuses a report about a file that does not exist** (a missing entry point, a
  deleted script — a real and likely defect class). *Mitigation:* `[ -e ]` accepts directories, so the
  `Surface` names the parent directory; the skill says so explicitly, and the absence is described in
  `Symptom`, which is where it belongs.
- **The skill's own local path `ai-docs/feedback/<file>.md` is not under the plugin root, so naming it
  inside a report is refused.** *Mitigation:* the skill's drafting rules forbid naming the report's own
  path; the gate refusal is loud, and abort-without-retry means the user sees it rather than an agent
  quietly working around it.
- **Refusal becomes routine and the channel goes unused** — the spec's own stated failure mode.
  *Mitigation:* the drafting step knows the project name, ticket prefix and `context.md` entities
  before it writes, and is instructed to write generically from the start; the five required sections
  steer toward harness-side nouns; `Surface` is the only field that carries a path.
- **Filing from the harness repository itself is now refused at exit 2**, by the disjointness rule of
  § 1c, before the vocabulary leg is even reached. (The vocabulary leg would also have caught the token
  `agent-harness`, but only sometimes.) Not a real constraint — from inside this repo filing is one
  `gh` command — and the exit-2 reason says so. It is, however, why the *test suite* must build a
  fixture root disjoint from its fixture project rather than pointing at the worktree.
- **The prose-slash residue, LOOSE-BY-CLASSIFICATION direction: a one-slash, no-extension, non-numeric token
  (`services/billing`) is prose to report mode and passes.** Report mode is deliberately looser than
  default mode here. *Mitigation:* the derived-vocabulary, `KEY-123` and URL legs still run unchanged
  over the same text, and the drafting rules steer `Evidence` toward described behaviour rather than
  named paths. Argued at length in § 1b; pinned as row r17 so it is a contract rather than a remark.
- **The prose-slash residue, LOOSE-BY-CAPTURE direction: a path token whose LEFT neighbour is
  punctuation escapes the path leg entirely** — a parenthesis, a double quote, a square bracket, an
  angle bracket or an em-dash. The token regex (`scripts/check-candidate.sh:138`) admits only
  start-of-line, whitespace or a backtick there, so `(src/main/billing/Invoice.kt)` is never extracted
  and is **exported silently**. Measured against the running gate: all five spellings **rc 0, no
  stderr**; the same token unparenthesised **rc 1**, naming it. This is a **different mechanism** from
  the r17 residue above — there the token is captured and then ruled prose, here it is never captured
  — so a fix to one does not touch the other. *Mitigation, in three parts:* (a) it is **parity with
  default mode**, whose own regex (`:239`) carries the same left anchor and scored the identical five
  rc 0 on the same inputs, so this branch neither introduces nor widens the hole; (b) the lexical
  widening is **deferred, not free** — measured, widening the left anchor to `(^|[^A-Za-z0-9_.-])`
  also starts capturing `//host/wiki/page` out of `https://host/wiki/page`, which step 3 then refuses
  as an **absolute path**, so text that today produces only a `url` finding would additionally produce
  a `file path` one; that reclassification needs its own rows and fixture cases and is a separate
  change; (c) at draft time, Task 5's rule that `Evidence` **describes** project files in words rather
  than naming them as paths keeps the shape out of real reports in the first place. Pinned as row
  **r21**, with its unparenthesised control, so a later widening is deliberate and visible rather than
  silent.
- **The prose-slash residue, STRICT direction: three or more slash-joined prose words
  (`read/write/execute`, `input/output/error`, `client/server/proxy`, `he/she/they`) are classified as
  path claims by the `≥ 2 separators` clause and are REFUSED.** Measured, all four. This is the same
  "prose describing behaviour" register a defect report is written in, so it will be met in practice.
  *Mitigation, in three parts, none of which is a lexical relaxation:* (a) **no lexical fix is
  available** — any weakening of the `≥ 2 separators` clause re-opens row r2
  (`myproject/scripts/deploy-prod.sh`), so the clause stays as it is and the residue is **accepted**;
  (b) the failure is **loud** — the gate names the refused token, so a drafter is never left guessing,
  which is a different class of harm from a silent export; (c) Task 5 carries the drafting rule that
  such runs are written as separate words ("read, write and execute"), which costs nothing and loses no
  meaning. Pinned as row r16 so a later change cannot silently alter the behaviour.
- **The path-claim test is an extension heuristic, so a harness file with no extension in its final
  segment** (a directory `Surface`, `skills/report-defect`) is prose unless it has two separators.
  *Mitigation:* every harness *file* worth naming has an extension, and a directory `Surface` is the
  documented shape for "this file is missing" (see the first risk) and reaches ≥2 separators in every
  real case (`skills/report-defect/scripts`). Named rather than hidden; row r10's shape covers it.
- **`shasum` vs `sha256sum` portability.** Both present on this machine; the script prefers `shasum
  -a 256`, falls back to `sha256sum`, and exits 2 with a named reason if neither is on `PATH` rather
  than emitting an empty hash.
- **A ledger row written for a filing that did not happen, or omitted for one that did.** *Mitigation:*
  the `file` verb writes the ledger **only** after `gh issue create` returns 0 and a URL; on any other
  outcome it writes nothing, leaves the report on disk, prints the full report text, and exits
  non-zero. The write goes through a temp file and `mv`, so a killed run leaves the previous ledger
  intact rather than a half-written one.
- **A damaged `filed.json` reads as "nothing filed yet", so the defect is filed twice and the damaged
  file is then overwritten** — the ledger is committed with the project, so a bad merge or a truncated
  write is a realistic way in. Measured: the naive lookup returns empty stdout on a zero-byte file, a
  truncated file and an absent file alike, which is one verdict over three different situations.
  *Mitigation:* § 5 separates the states before the lookup — absent is empty and is created on first
  success; present-but-unparseable is **exit 2 with a named reason, no `gh` call and no write** — and
  cases (a), (c) and (d) of Task 4 assert all three directions.
- **`.claude-plugin/` is not covered by the existing `\.claude/` permit pattern** (spec, verified).
  Irrelevant under the chosen mechanism — the alternation is not used in report mode at all — but it
  is the reason an alternation-based fix would have needed a third entry and a reviewer should not be
  surprised by its absence.

## Test Design

Runner for tasks 1–3: `bash scripts/test-promotion.sh` and `bash scripts/check-references.sh`. Runner
for task 4: `bash skills/report-defect/scripts/test-file-report.sh`. All three follow the in-repo
suite shape (`ok`/`bad` counters, a trailing `[ "$FAIL" -eq 0 ]`), so a failure prints a `FAIL` line
and exits non-zero — **not** an empty-output gate. The existing `scripts/test-promotion.sh` positive
controls (`refuse()` asserting both `rc=1` *and* that the offending term is named) are the pattern the
new identifier cases follow.

**Task 1 + 2 — gate, `scripts/test-promotion.sh`**

**Pinning comes first, because without it the suite's verdicts are not the suite's property.**
`test-promotion.sh` sets `CHECK="${HERE}/check-candidate.sh"` — the worktree copy — so under the `$0`
derivation every report-mode case would resolve `HARNESS_ROOT` to the **worktree**, while a consuming
project resolves it to the **installed plugin**. Those two trees agree today only by luck, and Task 5
breaks the luck: it creates `skills/report-defect/SKILL.md`, present in the worktree and absent from
installed `0.1.12` (verified), so a report naming it would pass in the suite and be refused in
production. The suite therefore:

- builds a **fixture harness root** under `mktemp -d` containing exactly the nine files enumerated in
  § 1d — **that list is the authority on the inventory and this section deliberately does not re-count
  it**; note in particular that the two root markers are two OF the nine, not two more on top of them,
  and that `scripts/check-candidate.sh` is in the root and not in the fixture project, which is what
  makes r19's "permitted, no warning" reachable — and **exports `CLAUDE_PLUGIN_ROOT` to it** for every
  report-mode case;
- builds the fixture project **disjoint** from that root (a sibling, not a descendant), so the
  § 1c disjointness guard does not fire on the ordinary cases. **Two extra fixtures exist only for the
  containment comparison, because the ordinary pair cannot see it:** both `mktemp -d` trees share no
  prefix, so neither the sibling false-positive nor the symlink evasion is reachable from them. The
  suite therefore builds one `base/` holding `base/root` (marked) and a **shared-prefix sibling**
  `base/root-proj`, plus a symlink `base/link-proj` → `base/root/inner`;
- **separately** exercises the production `$0` branch by copying the gate to
  `<fixture root>/scripts/check-candidate.sh` and running it with `CLAUDE_PLUGIN_ROOT` **unset** —
  the derivation then lands on the same fixture root, so that branch is pinned too. Measured:
  identical verdicts on the whole table.

Fixtures: extend the existing `mkproject` helper with a `report()` writer for
`<proj>/ai-docs/feedback/<slug>.md`; reuse the existing `DiffSet` / `ReviewRequest` context and the
`orderflow` / `ORD` registry fixture for the prefix cases.

Scenarios:
- both modes on both new paths; each of the seven identifier classes; each of the five sections
  omitted in turn; an unknown `--mode` value → 2;
- **the two required frontmatter keys, each omitted in turn** — a report otherwise complete but
  missing `harness_version:` → `rc=1` with a `structure` finding naming the key, and the same for
  `hash:`. § 3 makes these keys "what makes AC9 structural", but without these two cases the
  requirement could be deleted from the gate and nothing would fail — AC9's other assertions all live
  in `test-file-report.sh` and none of them reads the gate. Same `case "$BODY" in *"…"*` shape as the
  five existing section checks (`scripts/check-candidate.sh:157-158`), so the assertion follows the
  existing `refuse()` pattern: `rc=1` **and** the term named;
- **the 21-row path table of § 1d, row by row** — including r9 (nine prose pairs in one body → PASS),
  r11 (`skills/report-defect/SKILL.md` → PASS, which only holds because the root is pinned), r12
  (date), r13 (PASS **and** the ambiguity warning present on stderr), r14 and r15 (the Surface
  contract, from both directions), **r16 (four three-term prose runs in one body → REFUSED, the strict
  residue), r17 (`services/billing` → PASS, the loose-by-classification residue) and r21
  (`(src/main/billing/Invoice.kt)` → PASS, the loose-by-capture residue)** — the **three** rows that
  stop § 1b's tradeoff from being prose only, and that make a later relaxation of the `≥ 2 separators`
  clause (r16/r17) or of the token regex's left anchor (r21) fail the suite rather than pass it
  silently — **plus the two rows that discriminate a plausible wrong implementation from a right
  one**:
  - **r18** — `**Surface:** read/write` in a body that *also* carries
    `**Evidence:** scripts/session-events.sh` → `rc=1`, `structure`. Measured: a body-scoped
    permitted-claim test returns **rc=0** here and r14/r15 cannot tell the two apart, so this is the
    only case in the suite that fails the shortcut. Its positive control is the ordinary
    `**Surface:** scripts/session-events.sh` row, so "always emit a `structure` finding" does not
    score as a pass;
  - **r19** — `scripts/check-candidate.sh` → `rc=0` **and stderr carries no ambiguity warning**,
    asserted symmetrically with r13. Measured falsifiable: the same `grep 'ambiguity warning'` returns
    non-empty on r13's run, so this is not an assertion that can never fail, and a
    warn-on-every-permitted-claim implementation (which r13 alone passes) fails it;
  - **r20** — `**Evidence:** Also in scripts/deploy-prod.sh here.` with `**Surface:**
    scripts/session-events.sh` → `rc=1` naming `scripts/deploy-prod.sh`. Measured: the anchored
    alternation of § 1d returns **rc=0, no output** here, and returns the *same* verdict as the
    existence check on **every other row then in the table (r1–r19)** — the whole suite stayed at
    **0 failed**, at the pre-amendment total of 138 passed, under the substitution, so this is the
    only case that reads on the central decision of § 1a. Its positive
    control is r1 (same first segment, token present → PASS), so a leg that refused everything under a
    harness directory name would not score as a pass either;
  - **r21** — `**Evidence:** Also in (src/main/billing/Invoice.kt) here.` with `**Surface:**
    scripts/session-events.sh` → `rc=0` and **no output at all**, asserted as a *pair* with its
    control: the same body with the parentheses removed → `rc=1` naming
    `src/main/billing/Invoice.kt`. The pair is the whole point — the two bodies differ by one
    punctuation character, so the assertion reads on the token regex's left anchor
    (`scripts/check-candidate.sh:138`) and on nothing else, and an "always pass" leg fails the
    control. Measured in both directions against the running gate, and in default mode too (`:239`,
    identical verdicts), so the row records **parity with the shipped gate rather than a regression**.
    Its purpose is to make a later widening of the anchor **visible**: such a change flips r21 and
    must then be argued, instead of silently reclassifying URL text (§ 1b, Risks).
    **Fixture constraint, restated here because this bullet is where the fixture is specified:** the
    fixture project's derived vocabulary must hold none of `src`, `main`, `billing` or `Invoice`, or
    the row passes for the wrong reason — the vocabulary leg would refuse the token whatever the
    anchor did, and the pair would stop reading on the anchor. The pinned fixture satisfies this
    (`mkproject reportville` → vocabulary `reportville`, entities `DiffSet` / `ReviewRequest`; the
    `orderflow` / `ORD` registry fixture is exported only for the AC2 identifier cases, not for the
    path table). **The control keeps r21's identifier rather than taking one of its own** — the
    suite's existing unnumbered `row "positive control: Surface names a harness path"` beside
    r14/r15/r18 is the in-tree idiom — but it carries the stable output label
    `row "r21 control: unparenthesised" …`, so deleting it shows as a removed `ok` line in a suite
    diff;
- **the two refusal-trailer assertions of § 3a**, which are the first assertions in the tree to read
  that output at all — measured as a non-empty listing rather than as empty grep output:
  **before this increment,** `grep -rc 'Rewrite the lesson'` over the twelve test scripts printed one
  line per file and **every line read `:0`**, against the control `grep -rc check-candidate` over the
  same twelve, which prints `scripts/test-promotion.sh:5`. The four-word *substring*
  `Rewrite the lesson` then occurred **twice** in the tree — at `scripts/check-candidate.sh:260` and
  at `skills/improve/SKILL.md:118` — and the **full trailer** only in the gate (full-sentence `grep`
  over `skills/` and `docs/` → zero hits, against a proven-non-empty positive control; § 3a).
  **t1 and t2 are what move both counts, and that is the change rather than drift:** landing them puts
  the substring at `scripts/test-promotion.sh:125` and `:228` and the full trailer at `:125`, so the
  `-rc` probe reads `scripts/test-promotion.sh:2`. The `skills/`/`docs/` full-sentence probe stays at
  **zero**, which is the claim t2's reach actually rests on. t2's byte-for-byte assertion therefore
  pins the **gate's half only**, and it does so because **AC4 requires default-mode behaviour to be
  unchanged** — it cannot and does not detect `skills/improve/SKILL.md` drifting (§ 3a): **t1** — a report-mode refusal's stderr carries `let the user decide` and **not** `Rewrite the
  lesson` (red against the pre-implementation gate, measured); **t2** — a rule-mode refusal's stderr still carries
  `Rewrite the lesson so it names the SHAPE of the failure, not the instance.` and **not** `let the
  user decide` (red against a trailer-stripped gate, measured). t1 uses the `row` helper's existing
  must-name / must-not-name arguments; t2 is added beside an existing rule-mode `refuse()` case;
- **the five harness-root planted failures of § 1c** — the **unmarked root**, the root that **does not
  resolve**, **root == project**, root **strictly containing** the project, and the **symlinked
  project** whose target is inside the root → **2** (logical `pwd` scores 0 here, so this case is what
  fails a non-`pwd -P` implementation) — each asserting exit **2** and the reason named, plus the
  **two** negative controls the containment comparison needs: the **disjoint negative control** → 0
  (without which "always exit 2" would score as a pass) and the **shared-prefix sibling**
  (`base/root` vs `base/root-proj`) → **0** (a bare prefix test scores 2 here, so this case is what
  fails a naive implementation). The shared-prefix sibling (→ 0) and the symlinked project (→ 2) point
  in opposite directions on purpose: satisfying one by dropping the other is not possible;
- **project-dir guards 1 and 2 as two separate cases** (§ 2 table): guard 1 → exit 1 with `DiffSet`
  named; guard 2 (`ai-docs/feedback/sub/r.md`, no `--project-dir`) → exit **2** with the reason named,
  asserted as `= 2` so that neither 1 nor 0 scores as a pass.

Directionality: every new leg has a case that must FAIL as well as one that must pass. The planted
failures are `..`, the absolute path, the three Surface rows (r14, r15, **r18**), the two omitted
frontmatter keys, the five root failures (the symlinked project among them), r16, **r20**, **r21's
unparenthesised control** (`rc=1` naming the token — without it r21 alone would be satisfied by a leg
that passes everything), **t1**, both project-dir guards, and the identifier positive controls. The
mirror-image controls are r9, r17 and **r21** (a leg that refuses everything would fail all three),
**r19** (a leg that warns on everything would fail it),
**r1 as r20's control** (a leg that refused every token under a harness directory name would fail it),
**t2** (a gate that simply deleted the trailer, or printed the report-mode line in both modes, would
fail it), the `**Surface:** scripts/session-events.sh` control (a contract that always finds
`structure` would fail it) and the shared-prefix sibling (a containment test that refuses everything
shared-looking would fail it).

**Task 4 — `skills/report-defect/scripts/test-file-report.sh`**
- Scenarios: `hash` determinism across 3 runs; `hash` stable under a rewritten `Repro`, a case change
  and a line-number change; `hash` differing on a changed `Symptom` and on a changed `Surface`;
  `check` exit 0 on an empty ledger — **as two separate cases, an ABSENT `filed.json` and a present
  `{"version":1,"filed":{}}`, because the naive lookup cannot tell them apart and the first is the
  first run in every project** — and non-zero on a hit **printing all three of the URL, the
  recorded `harness_version` alongside the current one, and the ledger-row override instruction**
  (three separate assertions on the one case — § 5);
  **the three ledger-state cases of § 5, which are the ones that do NOT pre-seed the ledger** — every
  other case here seeds it, so without these three a `file` verb that never writes would pass the whole
  suite and fail AC10 only in production:
  - **(a) success path writes the row.** Ledger absent, hash not filed, `gh` stubbed → exit 0, the
    ledger now **exists**, and `.filed[<hash>]` carries an `issue` equal to the stub's URL and a
    `harness_version` equal to the manifest's (three assertions; measured);
  - **(b) `file` twice in a row.** The same call repeated immediately after (a), against **only the
    ledger (a) wrote** → the second exits non-zero with the three-line message and the recording stub's
    log holds **zero further invocations** (total still 1; measured). This is the case that proves read
    and write agree on the same key — a pre-seeded fixture cannot;
  - **(c) truncated `filed.json`.** A deliberately truncated ledger → **exit 2** with the reason named,
    `gh` **not** invoked, and the file **byte-identical** afterwards (checksummed before and after;
    measured). A zero-byte file is asserted the same way, since it is the likelier real-world shape;
  **`file` against a ledger that already holds the hash, with `gh` stubbed on `PATH` as a recorder →
  exits non-zero, the stub's log holds ZERO invocations, and the ledger file is byte-identical
  afterwards** (three assertions; this is AC10's verification, and it is what makes the duplicate stop
  a property of the script rather than of the order the skill calls two verbs — § 5). Its negative
  control is the ordinary success case below, where the same stub IS invoked once, so "never files" does
  not score as a pass;
  `file` with `gh` absent from `PATH` → non-zero, report text printed, report file still on disk,
  **ledger unchanged**; `file` emitting the `[harness-feedback]` title prefix, the manifest's
  `version` and `repository`, and the **root-resolution provenance line** (§ 1e part 3); manifest read
  via the `$0` derivation with `CLAUDE_PLUGIN_ROOT` unset — **the production branch**, so it is the
  one asserted first — and via the env override; and the same marker validation as the gate, with a
  planted non-harness root asserting exit 2.
- `gh` is stubbed on `PATH` for the success path so no issue is created by the suite. The
  `gh`-absent shape is measured and works: a `PATH` that keeps `jq` and drops `gh` exercises the
  branch.

**Task 5 — the skill.** Not mechanically testable in full; the honest verification is a positive grep
(non-empty output required) plus review, stated as such rather than dressed up as a gate. Three greps
carry content this design depends on and each must return a line: `--project-dir` (guard 3 of § 2),
`ambiguity warning` (§ 1e part 2's consumer), and `filed.json` (the override). The shape is measured
falsifiable — on a file carrying the phrase `grep -n` printed the line and exited 0; on one without it
printed nothing and exited 1.

**Task 6 — the install inventory, `scripts/test-install-smoke.sh`.** The existing loops assert
*components* against `claude plugin details` output; **before this increment** nothing asserted that a
**file** reached the install. Report mode's marker check depends on two, so both are asserted directly against the
installed tree. Measured layout: a sandbox install of the working tree lands at
`${CLAUDE_CONFIG_DIR}/plugins/cache/${MARKET}/${NAME}/${VERSION}/`, where all three variables are
already computed at the top of the script from the two manifests.

- assert `docs/agents-method.md` and `.claude-plugin/plugin.json` exist under that path — both
  measured **present** in a real sandbox install;
- falsifiability measured in the same install: `skills/report-defect/SKILL.md` (**not yet written when
  this was measured** — Task 5 creates it, after which the planted path is the standing falsifier) and
  a planted `docs/no-such-file.md` both came back **absent**, so the assertion can fail and is not an
  always-true probe;
- the `report-defect` skill row goes in the existing hardcoded component loop as before.

This gate is `exit 2` when the `claude` CLI is absent (AGENTS.md § Build & Test item 5 — **not a
pass**), which is unchanged by this addition.

**AC verification**

Every report-mode row below runs against the **pinned fixture harness root** described above, so its
verdict is a property of the fixture and not of whichever tree happens to be installed.

| AC | Verified by |
|---|---|
| AC1 | `bash scripts/test-promotion.sh` — cases `report mode admits scripts/…`, `report mode admits .claude-plugin/…`, `rule mode still refuses both with a file path finding` |
| AC2 | `bash scripts/test-promotion.sh` — seven `refuse()`-shaped cases in report mode, each asserting `rc=1` *and* that the term is named (dir name, registry `name`, ticket prefix, `KEY-123`, `context.md` entity, `deny-extra.txt`, URL host) |
| AC3 | `bash scripts/test-promotion.sh` — five cases, one per omitted section, each asserting `rc=1` and a `structure` finding, **plus two more for the required frontmatter keys `harness_version:` and `hash:`, each omitted in turn** (§ 3; see AC9) |
| AC4 | `bash scripts/test-promotion.sh` — the 25 pre-existing assertions, untouched (baseline measured green on `main`: `25 passed, 0 failed`). The default mode's path leg keeps its alternation **and its two literal exemptions**: `and/or` and `input/output` still pass and `read/write` is still refused there, exactly as measured today. Report mode is a separate branch and changes none of it. **The rule-mode refusal trailer is likewise byte-identical, and case t2 (§ 3a) is the first assertion in the tree that says so** — measured green with § 3a applied: **`0 failed`**. The pass TOTAL is not the invariant and must not be pinned: the pre-amendment total on this branch is 138 and r20, r21, t1 and t2 each raise it. What AC4 requires is `0 failed` plus all **25** `main` assertions still present and green |
| AC5 | `bash scripts/test-promotion.sh` — the three fixture rows asserted individually: `scripts/session-events.sh` → 0, `myproject/scripts/deploy-prod.sh` → 1, `server/core/Merge.kt` → 1. **Plus r20 (§ 1d), which the spec does not require and which is what makes AC5 a test of the chosen mechanism rather than of any mechanism reproducing three rows**: the rejected anchored alternation satisfies all three of these and the rest of the suite (measured: **0 failed**, at the pre-amendment total of 138 passed) while exporting `scripts/deploy-prod.sh` |
| AC6 | `bash scripts/test-promotion.sh` exits 0 |
| AC7 | `bash skills/report-defect/scripts/test-file-report.sh` (`check` / ledger behaviour) + `grep -n 'ai-docs/feedback' skills/report-defect/SKILL.md` returning **non-empty** + **`grep -n -- '--project-dir' skills/report-defect/SKILL.md` returning non-empty** (guard 3 of § 2, which is otherwise the one guard with no assertion at all) + **`grep -n 'ambiguity warning' skills/report-defect/SKILL.md` returning non-empty** (§ 1e part 2's consumer: the instruction that a Surface ambiguity warning is resolved *before* show-and-approve — without it the warning is emitted and read by nothing), plus review of the show-and-approve step |
| AC8 | `grep -n 'Abort' skills/report-defect/SKILL.md` returning **non-empty**; the absence of a retry loop in the *skill* stays a review item, recorded as a review item and not as a mechanical gate — a grep whose success is empty output is the shape this repo forbids. **Plus the gate-side half, which is mechanical: `bash scripts/test-promotion.sh` case t1 (§ 3a) — a report-mode refusal's stderr carries `let the user decide` and does NOT carry `Rewrite the lesson`.** Without it the gate keeps instructing the drafter to run the loop AC8 forbids, and no review of `SKILL.md` could see it, because the instruction is not in `SKILL.md`. **Scope note — t1 is a guard this design ADDS beyond AC8; it is not evidence that AC8 is mis-specified.** Spec AC8's literal scope is *the skill's instructions*, and the gate's stderr is not among them, so on the spec's own terms AC8 is satisfied by the `SKILL.md` half alone. t1 exists because the gate's output reaches the same agent in the same breath and contradicts those instructions — a hole the spec's wording does not cover and does not need to cover. **The spec is not to be amended for this** |
| AC9 | `bash skills/report-defect/scripts/test-file-report.sh` — cases asserting the emitted body carries the manifest `version`, the computed hash and the root-provenance line, and that the `-R` argument comes from the manifest `repository`. Asserted **first with `CLAUDE_PLUGIN_ROOT` unset**, since the `$0` derivation is the production branch (measured: both plugin env vars are unset inside a Bash call), then again with the override set. **Plus `bash scripts/test-promotion.sh` — the two frontmatter-key cases (`harness_version:` and `hash:` omitted in turn → `rc=1`, `structure`).** Without them AC9's "structural" half rests on a gate requirement no test reads: every other AC9 assertion lives in `test-file-report.sh`, which never invokes the gate, so the requirement could be deleted from `check-candidate.sh` and the whole suite would stay green |
| AC10 | `bash skills/report-defect/scripts/test-file-report.sh` — **the four cases of § 5 together, because the stop is only as good as the write it reads: (a) success on an ABSENT ledger → `gh` invoked once, the ledger is created, and the row's hash / issue / `harness_version` match; (b) the same `file` call repeated against only the ledger (a) wrote → non-zero, and the recording stub logs ZERO further invocations; (c) a pre-seeded hit → non-zero, ZERO invocations, ledger byte-identical; (d) a truncated ledger → exit 2, `gh` not invoked, file byte-identical.** (b) is the load-bearing one: every other case pre-seeds `filed.json`, so a `file` verb that reads correctly and never writes passes them all and fails AC10 only in production. (c) is the assertion AC10 was previously resting on alone, because it makes the stop a property of the script rather than of the skill remembering to call `check` first — no sequencing instruction is mechanically assertable, and § 7 rejects that shape for AC11 and AC12. Negative control for all three refusals: case (a), where the same stub **is** invoked once, so "never files anything" does not score as a pass. Secondarily, the `check`-on-a-hit case prints **three** things, each its own assertion (recorded issue URL, recorded `harness_version` next to the current one, ledger-row override instruction), and `grep -n 'filed.json' skills/report-defect/SKILL.md` returns **non-empty** so the override exists as an instruction and not only in this document |
| AC11 | `bash skills/report-defect/scripts/test-file-report.sh` — the title passed to `gh` starts with `[harness-feedback]`. Selection proven runnable and proven able to return non-empty: `gh issue list -R <slug> -S '"[harness-feedback]" in:title'` |
| AC12 | `bash skills/report-defect/scripts/test-file-report.sh` — `gh` removed from `PATH`: non-zero exit, full report text on stdout, report file still present, ledger unchanged |
| AC17 | `bash scripts/check-references.sh --audit-roots` exits 0 — measured in both directions on a throwaway copy of the tree: with `ai-docs/feedback` in `DOC_ROOTS` and **not** in the § Agent Docs table it reports `the mirror has drifted` and exits 1; with the table row added it prints `6 documented roots all present` and exits 0 |
| AC18 | `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json`; `bash scripts/check-references.sh`; `bash -n` on every `*.sh`; the ten suites in AGENTS.md § Build & Test item 4 plus the new `skills/report-defect/scripts/test-file-report.sh`; `bash scripts/test-install-smoke.sh` (AGENTS.md item 5 — Task 6 extends its inventory; **its exit 2 when the `claude` CLI is absent is not a pass**); `bash scripts/check-release.sh` for the version bump. Baseline measured green on `main` before any change, so a later red is attributable to this branch |

## Open questions

None blocking. The three the spec delegated are decided above (§ 4, § 5, § 6) with the tradeoffs
recorded. Two items are noted for the reviewer rather than asked:

- `docs/agent-docs-index.md` is documented as carrying "the verbose body of each row" of § Agent Docs
  but the mirror is not mechanically enforced, and it already has fewer bodies than the table has
  rows. Task 3 adds the body for the new row; **closing the pre-existing gap is not in this task** and
  should not be widened into it.
- `ai-docs/feedback/` is deliberately **not** added to `templates/project/` or to `scaffold.sh`. An
  empty directory cannot be committed to git, so there would be nothing to scaffold; the skill creates
  the directory on first use. This is a decision, not an omission.
- **`CLAUDE_PLUGIN_ROOT` and `CLAUDE_SKILL_DIR` are both unset inside a Bash call** — measured, and the
  reason § 1c makes the `$0` derivation primary. It also means AGENTS.md § Project-specific
  conventions' "a skill script is invoked as `${CLAUDE_SKILL_DIR}/scripts/<name>`" does not resolve
  through the shell. Nothing in this task depends on it resolving: both scripts derive their root from
  `$0` and validate it, so the invocation only has to be a real path. **Whether that convention needs
  restating is out of scope here and is a finding for a separate ticket** — recorded so it is not
  quietly absorbed into this branch.
