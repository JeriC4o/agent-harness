# Design: Hook path resolution — emit addresses that resolve, match paths that occur

**Ticket:** GH-75
**Date:** 2026-10-01
**Amended:** 2026-10-01 (round 3) — against the amended spec, 41,514 chars, **32 criteria** (AC1–AC22
contiguous plus AC2a, AC4a/b, AC11a/b, AC15a/b, AC18a/b/c). Review round 2's five majors are answered
below; four became criteria, the fifth (`loop-result`) was mine alone and is replaced, not patched.
Defect 3/3b live on **GH-77**, defect 4 and the L2 gate on **GH-76**.
**Amended:** 2026-10-01 (Design Amendment, post-Group-A) — implementation revealed three things this
design had wrong: the arms dropped a consuming project's own skill (**restored as a tenth arm on the
user's decision**), the unusable-anchor diagnostic is **guard-shadowed** and its stated trigger condition
was false in effect, and § M2's control tally said 11 over an enumeration of 10. Group A's measurements
also pin four details the design showed loosely. Every figure below re-derived against the working tree.
**Spec:** ai-docs/plans/2026-09-30-hook-path-resolution.spec.md

> **Notation, binding on this file.** `${CLAUDE_PLUGIN_ROOT}` written as a dollar-brace token means the
> literal variable reference as it appears in `hooks/hooks.json`, never the directory it expands to.
> Where the expanded value is meant, this design writes *the resolved install path*. A quotation showing
> an absolute path where the manifest holds the variable was mangled in transit — re-derive from
> `hooks/hooks.json`.

> **Every figure below is stated with the command that yields it**, per § Technical constraints → record
> the derivation, not the derived value. Numbers written beside a derivation are illustrative; anything a
> gate depends on is re-derived at run time. This document holds **zero** occurrences of this
> repository's absolute path, so it needs no exemption under any path gate.
>
> **Sharper form of that rule, and the tenth instance is what forced it: when the value is a LENGTH, a
> COUNT or a SIZE, state the derivation AND ITS INPUTS.** "124 bytes" sat inside an executable
> instruction in the paragraph announcing that every figure comes with its derivation — and the length is
> a function of the fixture's anchor path, so the number was never a property of the thing being
> asserted. A derivation without its inputs is a constant wearing a derivation's clothes.
>
> **Verification records live in
> [`2026-09-30-hook-path-resolution.design-evidence.md`](2026-09-30-hook-path-resolution.design-evidence.md).**
> This file carries the contract; that one carries the samples. Where an enumeration moved there, its
> count moved with it — a pointer plus a bare count is the configuration that produced "11 controls" over
> an enumeration of ten.

---

## What review round 2 changed

| # | Finding | Answer |
|---|---|---|
| 1 | **`loop-result` exemption was a denylist masquerading as a proof**, and the grep it proposed is red on its own file. | § M3 → the acceptance is now **behavioural**: run both commands and assert **emitted == 0 bytes AND the ledger grew**. Replaced, not refined |
| 2 | **AC2a — the selection key.** Two `statusMessage` values are duplicated and both duplicate pairs are byte-identical commands, so four commands are indistinguishable by output, message *and* basename. | § M3 → keyed on the manifest triple (event, matcher, index-in-group), measured unique 18/18 |
| 3 | **AC15a/b — the marker landscape.** 6 distinct bracketed, 6 sharing `BLOCKED:`, 3 sharing `[loop-index]` across two scripts, 2 unmarked, 1 JSON. | § M3 → a marker table covering all 18, disjointness scoped to the 16 distinguishable, achieved with **no lib-script change** |
| 4 | **AC4a/b — a positive assertion on the address.** An absence-only formulation passes on `… See .` | § M1 → the product is hardened so the state cannot occur, **and** the suite asserts the address positively |
| 5 | **AC11a/b — four fail-open anchoring inputs.** The anchor is a glob prefix, so it tolerates neither a trailing slash nor a divergent spelling. | § M2 → both sides normalised to physical absolute form; three cases fixed, the fourth documented, all four controlled |

**Finding 1 was mine and it is worth naming precisely, because the mechanism recurred.** The design's
prose described a gate ("grep for an unredirected `printf`/`echo` and for `>&2`, require zero hits")
whose literal implementation returns **2** hits on `hooks/lib/loop-result.sh` — at the piped
`printf '%s' "$in" | jq …` and at `IFS=$(printf '\t')`. My § Measurements reported "the one hit is
`IFS=…`" because I had added a `| grep -v '| *jq'` filter while exploring and then wrote down the
*filtered* result as if it were the gate's result. A correct mechanism arriving with a wrong count, for
the third time in this task — and here the wrong count would have shipped a red gate that an implementer
loosens until it passes, which is how an exemption stops detecting anything. The replacement is a
measurement rather than a pattern, so it cannot be loosened into agreement.

I also mis-cited the supporting sentence: `loop-result.sh`'s "every failure path here exits 0 in silence"
is scoped to failure paths. The sentence that carries the global claim is the next one — "it can still
cost a turn if it hangs or shouts, and it does neither."

---

## Measurements re-derived for round 3

| Fact | Derivation | Result |
|---|---|---|
| Occurrences / commands | `grep -o` over `jq -r '.hooks[][] \| .hooks[] \| .command'` | **25** across **18** |
| Occurrence classification | `grep -o '.\{1\}\${CLAUDE_PLUGIN_ROOT}.\{1\}'` on that stream | `"${CLAUDE_PLUGIN_ROOT}"` ×11; `<space>…/` ×9; `(…/` ×3; `*…/` ×2 |
| **Selection key uniqueness** | `jq -r '… "\($ev)\|\($m)\|\(.key)"'` piped to `sort -u \| wc -l` | **18 triples, 18 distinct.** Matchers are unique within each event (`PreToolUse`: Bash, Edit\|Write, *; `PostToolUse`: Write\|Edit, Bash, *), so the group index is redundant |
| `statusMessage` collisions | `jq -r … \| sort \| uniq -c \| sort -rn` | **16** distinct values; `Recording the call outcome...` ×2 and `Judging whether this stretch was circling...` ×2 |
| Identical command strings | `jq -r … \| sort \| uniq -c` | two pairs, byte-identical: `loop-result.sh` (`PostToolUse/*`, `PostToolUseFailure/*`) and `loop-verdict.sh` (`Stop`, `SubagentStop`) |
| The command with **no** `statusMessage` | same listing | `PostToolUse\|Write\|Edit\|1` — `sh-syntax-check`, a **path matcher**. All five delegations *do* carry one. Round 2's design said the opposite in both halves |
| Marker forms | `grep -oE '(BLOCKED:\|\[[a-z][a-z-]*\]\|hookSpecificOutput)'` per command, plus the lib scripts | 6 `BLOCKED:`, 6 distinct bracketed, 1 JSON, 3 `[loop-index]` (2 scripts), 2 none |
| `loop-index.sh` emission form | `grep -n permissionDecision` | JSON on **stdout** with a `permissionDecisionReason` |
| `loop-verdict.sh` emission form | `grep -n '>&2'` | plain **stderr** lines, `[loop-index] coarse repeat: …` and `[loop-index] tier 3: …` |
| `loop-result.sh` emits nothing | both commands run against a real payload with `HARNESS_LOOP_DIR` set | **0 bytes** each, and **2 ledger rows** written |
| Emit on a generic payload | every command via `bash -c "$cmd"`, generic `tool_input`, marker dir present | **17 of 18 emit 0 bytes**; `SessionStart` emits a non-empty message, being the only unconditional one. With no harness marker, all 18 emit 0. **No byte count is recorded or asserted** — the length is a function of the root path, and two independent measurements of this one disagreed by a byte over trailing-newline capture, exactly as for the diagnostic. **Markers are anchored prefixes of the first NON-EMPTY line**, because five messages open with a deliberate `\n` |
| **`/tmp` divergence** | `realpath /tmp`; `ls -ld /tmp` | `/private/tmp`; `/tmp -> private/tmp`, a symlink |
| Anchor fail-open, all four | the arm `case` run with a perturbed anchor | trailing slash → **silent**; relative anchor → **silent**; `/tmp` anchor vs `/private/tmp` path → **silent**; non-root cwd → silent. No diagnostic in any case |
| **Check-count claims (AC18a)** | `grep -rniE 'five structural\|all five\|three delivery\|five checks'` over `AGENTS.md README.md ai-docs docs scripts skills` | **27 raw hits in 14 files; 4 dependents.** The search is a candidate generator — the triage rule is in § M4 → AC18a and is load-bearing, because "update every hit" edits five unrelated files and one append-only one |
| **Numbered cross-references** | `grep -rnoE 'check [1-8]\|gate [1-8]\|structural checks [1-8]'` | 4: `AGENTS.md:21` (check 4), `AGENTS.md:76` (gate 6), `docs/instruction-file-validation.md:37` (check 1), `check-references.sh:8` (checks 2 and 3). The third was in no prior list either |
| `context.md` in the Propagation Rule table | section-extract + `grep` | **0** occurrences — but it *is* named on the `> Applies to:` instruction-file line |
| Permission surfaces | `jq '.permissions.allow\|length'` / `.deny\|length`, each printed beside its own filename | no `Read(...)` on either; **template allow=21 deny=16**, **repo allow=10 deny=16**; deny lists byte-identical |
| Committed modes | `git ls-files -s scripts/` | `check-references.sh`, `check-release.sh` **100644**; `test-plugin-manifest.sh` **100755** |
| Version | `.claude-plugin/plugin.json` | `0.1.30` → **`0.1.31`** |

---

## Approach

### M1 — the resolver, hardened so the degenerate address cannot occur

**New `hooks/lib/plugin-ref.sh <relative-path>`.** Prints the resolved absolute path; when the target is
unreadable, prints it plus a clause naming the plugin directory and stating that correct operation
requires read access to it. Always exits 0 — callers detect failure by **empty output**, never by rc,
because a hook that treated a non-zero rc as fatal would lose the whole message.

> **The readable branch needs an `[ -n "$root" ]` guard, and this design did not show it.** Group A
> found that without it an unset root makes the readability test resolve the bare relative path against
> the **caller's working directory**, so a same-named PROJECT file gets printed as the plugin's address.
> That is a wrong address that looks right — the same failure class as the degenerate `See .`, and states
> 2 and 3 below depend on the guard being present. The shipped condition is
> `[ -n "$root" ] && [ -n "$rel" ] && [ -r "$addr" ]`.

Each message site uses one uniform construct:

```
r="${CLAUDE_PLUGIN_ROOT:-}"; a=$("$r"/hooks/lib/plugin-ref.sh docs/agents-method.md 2>/dev/null); [ -n "$a" ] || a="${r:+$r/}docs/agents-method.md — correct operation of the plugin requires read access to the plugin directory${r:+ $r}"
```

…and `a` reaches the message as a `printf` **argument**, never in the format (AC20).

> **Position matters and this design showed the construct without placing it.** The block sits **inside
> each hook's firing branch**, never as an unconditional prefix: 17 of 18 commands emit nothing on a
> generic payload, so a prefix would spawn two processes per tool call to build a message almost never
> printed. Group A placed it correctly; recorded here so a later edit does not "simplify" it to a prefix.

**Two counts differ on purpose — 11 and 12.** Re-derived from the working tree: **11** resolver call
sites, **11** emptiness guards, **11** fallback strings, but **12** message references. The propagation
reminder resolves two files and passes one of them as **two** printf arguments (the table's location and
the section reference), so references exceed call sites by one. Stated because a later reader meeting the
mismatch would otherwise read it as a missing site.

**`[ -n "$a" ] ||` rather than `||` — this is finding 4's fix in the product, not only in the suite.**
The resolver's contract is always-exit-0, so an `||` fallback fires when the resolver is *unreachable*
and never when it *fails*. Demonstrated: with a resolver present that prints nothing, the site emits
`See .` — a degenerate address that satisfies every absence-only assertion. Testing an emptiness guard
on the captured value closes both doors. Verified: with the same silent resolver the hardened construct
emits the full directory-naming message instead of `See .`.

**One cause-agnostic fallback string.** `${r:+…}` makes the same text correct whether or not the root is
known: with `r` set it names the directory twice (address and requirement); with `r` empty it names
neither and emits no leading slash. It asserts **nothing** about why the path is unavailable — the
round-2 wording claimed the variable was unset in a state where it is set.

**Six states, each run this round on an unguarded site (`sh-syntax-check` shape)** — the sixth is the one
that closes review finding 4, so it is counted, not appended:

| # | state | fixture | AC |
|---|---|---|---|
| 1 | set, readable | normal plugin tree | AC1, AC4a |
| 2 | **unset** | `env -u CLAUDE_PLUGIN_ROOT` | AC4 |
| 3 | **empty string** | `CLAUDE_PLUGIN_ROOT=` | AC4 |
| 4 | set, **target file** unreadable (root traversable, resolver reachable) | `chmod 000` the target | AC5 |
| 5 | set, **root** unreadable (resolver unreachable, fallback fires) | `chmod 000` the root | AC5 |
| 6 | set, resolver reachable but **silent** | a resolver that exits 0 printing nothing | AC4a |

**The REQUIREMENTS on this table are 2 ≡ 3, 4 ≡ 5 ≡ 6, and that no state emits the degenerate address.**
Those are contract. The emitted tails are samples and live in
[§ M1 of the evidence file](2026-09-30-hook-path-resolution.design-evidence.md#-m1--the-six-root-states-emitted-tails).

**The state-4 ≡ state-5 identity is now a CONSTRAINT, not an observation.** Round 2 asserted it without
stating what makes it true. It holds only because the resolver's unreadable-branch format and the
caller's fallback string produce the same bytes after substitution. That is now a design requirement, and
the suite asserts `state4_output = state5_output` as an exact string comparison — so a future edit to
either wording fails a test instead of silently splitting the two messages.

Each fixture asserts its own precondition first (`[ -r … ]` / `[ -x … ]` must be false); a suite running
as root would otherwise find the file readable and measure nothing.

**`SessionStart` moves to `jq -cn --arg`** rather than `echo '<JSON literal>'` — injecting a path into a
hand-built JSON string is an escaping hazard, and `jq` is already a dependency of nearly every hook. Run:
valid JSON, resolved path in `additionalContext`, no interior apostrophe.

**No sibling suite for the resolver** — ~20 lines, under the 50-line threshold, and every branch is
exercised through a real hook by M3's L3 suite, which is how production reaches it.

### M2 — arms anchored and normalised, and `context.md` admitted

**Round 2's arms were anchored but the anchor was a raw glob prefix, and four ordinary inputs silenced
every arm with no diagnostic.** Measured, all four:

| case | anchor | incoming path | verdict |
|---|---|---|---|
| (a) trailing slash | `<root>/` | `<root>/AGENTS.md` | **silent** |
| (b) realpath divergence | `/tmp/proj` | `/private/tmp/proj/AGENTS.md` | **silent** |
| (c) relative anchor | `proj` | `<root>/CLAUDE.md` | **silent** |
| (d) non-root cwd | a subdirectory | any member | silent |

Case (b) is not hypothetical on this platform: `/tmp` is a symlink to `private/tmp`, so a captured
`/tmp/...` anchor and a `/private/tmp/...` payload name one directory and share no prefix.

**Both sides are normalised to physical absolute form before matching:**

```
pd=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P)
[ -n "$pd" ] || { printf '\n[propagation-rule-reminder] anchor unusable: %s does not resolve to a directory, so no arm can match.\n' "${CLAUDE_PROJECT_DIR:-$PWD}" >&2; exit 0; }
kd=$(cd "$(dirname "$f")" 2>/dev/null && pwd -P); k="${kd:-$(dirname "$f")}/$(basename "$f")"
case "$k" in "$pd"/AGENTS.md|"$pd"/CLAUDE.md|"$pd"/agents/*.md|"$pd"/rules/*.md|"$pd"/skills/*.md|"$pd"/.claude/skills/*/SKILL.md|"$pd"/docs/*.md|"$pd"/scripts/*.sh|"$pd"/ai-docs/learnings/README.md|"$pd"/ai-docs/context.md) … ;; esac
```

#### The tenth arm — a consuming project's own skill, restored by user decision

**The class the nine-arm set dropped and the old arms caught:**
`<project>/.claude/skills/deploy/SKILL.md`. Every skill row in the Propagation Rule table is spelled with
the plugin-root prefix and therefore resolves to the *harness's* layout (`skills/<name>/SKILL.md`), never
to a consumer's `.claude/skills/`. The derivation was faithful to the table's **tokens** and narrower
than the table's **meaning** — the catch-all row says *Any other instruction file*, and a project's own
skill answers that description. **The shipped ten-arm set fires on it** (measured).

**The pattern is the finding, and it has now produced four instances.** `CLAUDE.md` (AC10),
`ai-docs/context.md` (AC18c), this class, and — by the same mechanism — the three further project-side
mirrors named in the bounded gap below. A token-faithful derivation over a table whose final row is prose
is **systematically** narrower than the table, and cannot be closed by token harvesting at all. Every
future member class arriving through that row needs explicit treatment.

**The user approved restoring it as a tenth arm. The shipped spelling is
`"$pd"/.claude/skills/*/SKILL.md`, and the narrower spelling is the point.** Measured, the rejected
`"$pd"/.claude/skills/*.md` fires on `.claude/skills/deploy/reference.md` and `.claude/skills/notes.md`
where **the old arms were silent** — so it widens past the regression it exists to repair. That is the
exact ground on which the bounded gap below excludes the rest of `<pd>/.claude/**`, and one line cannot
be invoked to reject one gap and crossed in the fix for another. Both distinguishing paths are committed
controls.

Verified with the arm landed: **MEMBERS 14 fired of 14 probed; CONTROLS 13 silent of 13 probed** — both
enumerations in
[§ M2 of the evidence file](2026-09-30-hook-path-resolution.design-evidence.md#-m2--arm-membership-measured-with-the-ten-arm-set-landed).
The controls grew from ten because three were added: the two that distinguish the spellings, and **a
sibling project's `.claude/skills/deploy/SKILL.md` — on which the old UNANCHORED arm fired and the
root-anchored one does not.** Worth stating: restoring the class did **not** restore the cross-project
false positive, because the anchor does that work independently of which class is admitted.

> **What it costs, stated plainly.** This arm arrives from the **catch-all row**, not from any explicit
> path token, so the token harvest cannot produce it. The agreement gate therefore needs an **explicit
> carve-in**: a named entry asserting that this arm is expected and is *not* derivable, with its reason.
> **A gate with an undocumented exception is the shape this task exists to remove**, so the carve-in is
> named in the gate, carries its provenance, and is covered by the dead-entry guard — if the table ever
> grows a token that *does* produce this arm, the carve-in goes dead and the gate fails rather than
> silently double-counting.
>
> **But the dead-entry guard is NOT sufficient, and the gap is a tautology.** It catches the carve-in
> becoming *redundant*; it cannot catch the carve-in becoming *wrong*, because gate step 8 synthesises
> each class's representative **from the class string itself** — so for the carve-in it generates a path
> from the carve-in entry and then asserts the arm matches it. Claim and evidence are the same string:
> an exception that cannot detect its own invalidation. **The remedy uses evidence the design already
> commits:** AC13's pre-fix `case` pattern is an independent record of prior behaviour, so the gate
> additionally asserts that **no path the OLD arms matched is silent under the new set**. That makes the
> carve-in's reason-for-existing testable rather than self-certifying — and it would have caught the
> near-miss below with nobody checking by hand.

**A known, bounded gap is NOT being closed here, and it is a CLASS rather than a member.** The
`> Applies to:` enumeration is written in plugin-root spelling, so **every class it names has a
project-side `<pd>/.claude/**` mirror the token harvest cannot reach**. Measured silent under the shipped
arms: `<pd>/.claude/agents/*.md`, `<pd>/.claude/rules/**/*.md` and `<pd>/.claude/commands/*.md` —
**three** besides the carve-in. The old arms never matched any of them, so admitting them would be a
widening rather than a restoration, and widening is the ground this design just used to reject the
`*.md` spelling. All three stay out, as one decision about the class rather than three about members —
named so the next reader finds a decision instead of rediscovering the trap a fifth time.

`cd … && pwd -P` in a command substitution is a subshell, so it cannot disturb the rest of the hook. It
fixes (a), (b) and (c) at once — `pwd -P` has no trailing slash, is always absolute, and is always the
physical spelling. Case (d) is **not** normalisable: a subdirectory is a valid absolute directory, just
the wrong one, so it is recorded as a documented invocation condition (the hook requires
`CLAUDE_PROJECT_DIR`, which the client sets) rather than claimed as fixed.

**Round 2's risk entry was wrong in its reasoning, which is worth recording.** It said the anchor "gains
no new input" because `harness-managed.sh` already uses the same value. True of the *input* and false of
the *sensitivity*: the guard uses it as a **path**, which tolerates a trailing slash and any spelling
that still resolves; the arms use it as a **glob pattern**, which tolerates neither. Sharing an input is
not sharing a contract.

#### The unusable-anchor diagnostic is GUARD-SHADOWED — the prior claim was false in effect

This design said the diagnostic "fires only when `cd` on the anchor fails — a genuinely broken state".
**In that state the hook has already stopped.** `hooks/lib/harness-managed.sh` reads the *same* anchor
expression, `root="${CLAUDE_PROJECT_DIR:-$PWD}"`, and both its markers test
`[ -d "${root}/ai-docs" ]` / `[ -f "${root}/AGENTS.md" ]` — each requiring the anchor to be traversable.
An unusable anchor makes both fail, the guard exits non-zero, and the hook's own
`harness-managed.sh || exit 0` prefix stops it **before** the diagnostic can run. Group A measured four
anchor-breaking kinds — non-existent, dangling symlink, plain file, no execute bit — and `cd` fails in
all four, so the guard exits in all four.

**Confirmed by execution this round**, on the real command from the working tree with a non-existent
anchor: the full command emits **exactly 0 bytes** (the guard stopped it); the same command with the
guard prefix stripped emits the diagnostic, correctly worded. So the code path is right and only its
reachability is not.

> **No byte count for that message is assertable, and the prior draft's "124 bytes" is the tenth
> instance of a figure stated without its input.** The length is a function of the fixture's anchor
> path — it grows one-for-one with it — so an implementer using a different fixture gets a failing
> assertion against a design-specified constant. Two independent measurements of the constant disagreed
> by one byte, because neither recorded whether the trailing newline was captured; the disagreement is
> the argument. **Assert the anchored marker prefix, never a length.** Relationship recorded in the
> [evidence file](2026-09-30-hook-path-resolution.design-evidence.md#the-diagnostics-length-is-a-function-of-its-input).

**What the diagnostic actually is: a TOCTOU backstop.** The only state that reaches it is an anchor that
was usable when the guard ran and became unusable before the arms matched. That is a real state, worth
keeping, and vanishingly rare — but it is not "a genuinely broken anchor", and the difference is the
whole of AC11a's diagnostic leg.

> **Executable instruction for Group B — do not assert this leg end-to-end.** Running the real command
> with an unusable anchor emits 0 bytes, so an end-to-end assertion **will fail** and the implementer
> will not know whether the failure is theirs. Assert it in **two parts instead**:
> 1. **The diagnostic works** — assert the **anchored marker prefix**
>    `[propagation-rule-reminder] anchor unusable: ` against the **post-guard fragment** (the command with
>    the `harness-managed.sh || exit 0` prefix removed), present with an unusable anchor and absent with a
>    usable one. **Never a byte count.** And **assert the strip actually changed the command** — compare
>    the stripped string against the original and fail if they are equal, or a later rewording of the
>    guard prefix leaves part 1 silently testing the shadowed path and passing for the wrong reason.
> 2. **The shadowing is real** — assert the **full** command emits exactly 0 bytes with an unusable
>    anchor. **This is the valuable half:** it makes the shadowing a tested property, so removing the
>    `harness-managed.sh` guard later surfaces as a changed test rather than as a diagnostic that quietly
>    starts firing.
>
> Both assertions are required. Part 1 alone would claim a reachability the hook does not have; part 2
> alone would look like the diagnostic is dead code.

> **THE NEAR-MISS, recorded because it is the strongest argument for the regression assertion above.**
> This design marked decomposition row 3 **DONE** for the ten-arm set while the tree carried **nine** —
> `grep -cF '.claude/skills' hooks/hooks.json` returned **0**. The tenth arm was approved *after* Group A
> handed back, and the row was marked done on the strength of the amendment *specifying* it. That is the
> tenth instance in this task of an artefact asserting work nobody executed, and the most consequential,
> because **no gate could see it**: nothing tests arm membership today, and the gate that would is
> subtask 4 — which would have been written against the claim and failed against a correct tree. The
> arm has since landed. The lesson is not "check before writing DONE"; it is that **a claim about the
> tree must be answered by the tree**, and the old-arms regression assertion is the only mechanism here
> that would have answered it unprompted.

**Verified with a real fixture tree built under the symlinked path. Count and enumeration always travel
together** — the prior draft said "11 controls" over an enumeration of ten, which was the ninth instance
in this task of a correct mechanism carrying a wrong tally. Both enumerations now live in the evidence
file with their counts beside them.

**The member enumeration and its count both live in the
[evidence file](2026-09-30-hook-path-resolution.design-evidence.md#-m2--arm-membership-measured-with-the-ten-arm-set-landed)**,
together rather than split. One member stays here because it is contract rather than sample:
`.claude/skills/deploy/SKILL.md`, the carve-in's representative.

**Five controls stay here because AC11 names them as required and the false-positive bound is DEFINED by
them rather than sampled from them:** `my-agents/notes.md`, `sub-agents/x.md`, `src/docs/readme.md`,
`node_modules/x/docs/a.md`, `vendor/scripts/build.sh`. The full control enumeration and its count are in
the evidence file.

All four perturbed anchors resolve. The diagnostic's own verification is two-part — see the guard-shadow
instruction above; it is **not** reachable end-to-end.

**Residual limit, stated precisely rather than as a blanket.** A `Write` whose *parent directory* does
not yet exist cannot be normalised — there is nothing to `cd` into — so `k` falls back to the raw path.
**That fallback is conservative in the safe direction, and the precise boundary matters:** because the
arm glob crosses `/`, the arms still **fire** whenever the incoming path is already physical-absolute,
which is the normal case. The degradation bites only when the path is *both* inside a not-yet-created
directory *and* spelled non-physically — and even then it fails silent, never false-positive. Inherent
to path normalisation; not a case the suite can remove.

#### `ai-docs/context.md` is ADMITTED, which answers AC18c's tension with AC10

AC18c asks why the catch-all row *Any other instruction file* admits `CLAUDE.md` and not
`ai-docs/context.md`, when context.md answers that description too. **It does not, and the honest answer
is to admit both.** Round 2 excluded context.md as a "profile surface in no sync group"; that was a
judgement, not a derivation, and AC18c's own evidence refutes it — context.md demonstrably carries text
that must move when `AGENTS.md § Build & Test` changes (it holds both the structural and the delivery
counts, `:86` and `:87`), and **three independent safety nets missed it**. Admitting it makes the arms
the fourth net and the only mechanical one. It is also what the derivation already produces: the
`> Applies to:` line the catch-all resolves against names `ai-docs/context.md` explicitly, so excluding
it required a hand-written subtraction.

**So the exclusion list shrinks to one entry, and that one stands on a rule rather than a judgement:**
`ai-docs/learnings/*-*.md` is excluded because § Learning Log Boundary rule 2 **forbids** the follow-on
instruction-file edits the reminder asks for — firing there would advise a rule violation. That is a
semantic conflict, not an opinion about membership. The gate still fails on a **dead** exclusion (one
matching nothing in the derived set), so the entry cannot rot into a silencer.

#### The derivation gate — `scripts/check-propagation-arms.sh`

Each step prototyped and run:

1. Section-extract `## Propagation Rule` from `docs/agents-method.md`.
2. Harvest table rows, **both cells**. Forced by measurement: a left-cell-only harvest **drops
   `scripts/*.sh`**, because the Inspect group names its two script output contracts only on the anchor
   row's *right* cell — the table's own convention ("Name every member on the anchor row").
3. Token-extract backticked spans; strip a trailing ` § …` qualifier (otherwise the Learning-Log row
   fails the extension filter); strip the `${CLAUDE_PLUGIN_ROOT}/` prefix; normalise `<…>` → `*` and
   `**` → `*` — **not** skip-if-templated, since `rules/<file>.md` is the only source of `rules/*.md`.
4. Keep tokens ending `.md` / `.sh` / `.json`.
5. Resolve a bare unqualified filename against `git ls-files`; unresolvable → **finding**, never a silent
   drop.
6. **Catch-all leg (AC10):** when a left cell matches *Any other instruction file*, union in the
   instruction-file enumeration from the `> Applies to:` line. That line is the only place in the file
   naming `CLAUDE.md` — and `ai-docs/context.md` — as instruction files. A dedicated assertion requires
   **both** to be present via this leg, so removing it fails loudly.
7. Subtract the single reasoned exclusion above; fail on a dead exclusion. **Then add the one named
   carve-in** — `"$pd"/.claude/skills/*/SKILL.md`, which arrives from the catch-all row and which the token
   harvest provably cannot produce, since every skill row is spelled with the plugin-root prefix. The
   carve-in carries its provenance in the gate and is covered by the same dead-entry guard: if the table
   ever grows a token that *does* yield this arm, the carve-in goes dead and the gate fails rather than
   double-counting. **The gate has exactly one exclusion and exactly one carve-in, both documented in
   place** — an undocumented exception is the shape this task exists to remove.
8. For each surviving class, synthesise **an absolute representative** — `<physical project root>/<class>`
   with the wildcard filled — and assert the live `case` pattern extracted from `hooks/hooks.json` fires
   on it; then assert every control stays silent. The representative is absolute by construction, so
   round 1's relative-representative error cannot recur inside the gate.

**Chosen over the two alternatives the spec leaves open.** Generation still needs a hand-written
token→glob transform (steps 3, 5, 7 are irreducibly judgement), so it buys nothing over asserting
agreement and adds a stale-artefact failure mode. A runtime single source puts a markdown parse on the
hot path of every `Edit`/`Write`. Asserting agreement is the only option whose failure mode is a loud
gate.

### M3 — the two test levels

#### L1 — static, in `scripts/test-plugin-manifest.sh`

Every occurrence of the variable in a hook command must be exactly `"${CLAUDE_PLUGIN_ROOT}"` — a property
of each occurrence, not an inference about quoting regions. The parity approach is unsound: exactly one of
the 18 commands has odd apostrophe parity (`tr -d "'"` inside double quotes), misclassifying the rest of
that command including the prose site it carries.

> **The property keys on the BRACED token, closing brace included — `${CLAUDE_PLUGIN_ROOT}` — not on the
> bare name.** Group A's own uniform construct introduces `${CLAUDE_PLUGIN_ROOT:-}`, a legitimate
> default-expansion form that a bare-name grep flags as non-conforming. Measured on the working tree:
> **20** bare-name occurrences = **11** braced-token + **9** `:-}` default-expansion. Keyed on the braced
> token the property holds for all **11**, with windowed == unwindowed == **11** and **0**
> non-conforming. Subtask 6 depends on this distinction; keyed on the bare name the gate is red on
> correct code.

**Conservation assertion (AC12).** A one-character-window `grep -o` cannot see an occurrence at the very
start or end of a command, so the gate asserts **windowed count == unwindowed count** before classifying.
Two controls: a planted non-conforming occurrence, and a planted **boundary** occurrence at position 0.

> **A degradation control must bind the OPERATOR to the thing it guards, not delete a token near it.**
> Group A's first attempt at the emptiness-guard control **passed vacuously**: it removed the `[ -n … ]`
> test but kept the assignment, which made the fallback unconditional rather than unguarded — so the
> site still emitted a correct message and the control proved nothing. It caught this itself and re-ran.
> This is the **third** occurrence of a vacuous control in this task, after the L2 empty-result case and
> the arm probe that read stderr as signal, so it is recorded as a rule: a control that degrades a guard
> must degrade the **guard**, and the suite asserts the degraded variant produces the specific wrong
> output — never merely that it still runs.
>
> **A CONTROL NEEDS ITS OWN CONTROL, and this generalises past degradations.** Group B shipped two more
> vacuous controls — spelled as line patterns that silently matched nothing, so each "control" reported
> passing while the code it was meant to perturb stood unmodified. They were caught only by adding a
> **changed-guard**: a requirement that the degrading edit actually changed the file. That is the fifth
> and sixth vacuous control here, and the count is the argument — the rule is not "write better
> patterns" but **assert that the perturbation landed**, because a control is itself a mechanism and
> every mechanism in this task that was not checked turned out to be checking nothing.

> **Reading your own code for narration makes you read it.** Group C's comment-hygiene pass found two
> real correctness defects in its own new code: a parse check that wrote a file nothing read, so the
> extraction ran against the raw template and a malformed one would have reached the assertions as an
> empty allow list; and a `case` arm printing a vacuous `ok` on an empty entry, visible in the RED
> output. Both now carry guards, and the second guard was re-proved by a degradation. Worth one sentence
> because it is the cheapest defect-finding pass in the task and it was not looking for defects.

#### L3 — behavioural, in the new `scripts/test-hook-behaviour.sh`

**Selection key (AC2a).** Commands are selected by the manifest triple — event, matcher, index within the
matcher's group — measured unique 18/18. Round 2's selector keyed on `statusMessage`, which cannot work:
two values are duplicated and both duplicate pairs are byte-identical commands. **The triple is passed as
three separate values, never as a joined string**, because a matcher contains `|` (`Edit|Write`) and any
delimiter-joined key is ambiguous. Equivalently the `jq` path is used; both are free.

**The trigger inventory is a deliverable (AC3).** Measured: 17 of 18 commands emit 0 bytes on a generic
payload, so an absence assertion alone is satisfied both by a hook that ran and did nothing and by one
that failed to run. The suite carries a committed table of one triggering input per command.

**The suite captures stdout and stderr SEPARATELY, and the two legs read different streams.** A `jq`
marker is evaluated **against stdout alone**; AC2 leg (ii)'s absence assertion runs over the
**concatenation** of both. This is not tidiness: `loop-index.sh` writes *both* a `[loop-index] …` line to
stderr and its decision JSON to stdout, and `jq -e` over the merged stream returns **rc 5**
("Invalid numeric literal at line 1, column 12") while the same expression over stdout alone returns rc 0
and `"ask"` — both measured. Merging the streams would fail leg (i) for the one command whose collision
the JSON marker exists to resolve.

**Marker table, covering all 18 (AC15b).** The marker is the **anchored leading form** of the emitted
text — a full first-line prefix, or a `jq`-extracted field read from stdout — never a bare bracket or a
bare `BLOCKED:`, because 6 commands share that prefix and 3 share `[loop-index]`.

| selection key | trigger | asserted marker |
|---|---|---|
| `SessionStart\|-\|0` | any payload, marker dir present | **stdout:** `jq -e .hookSpecificOutput.additionalContext` non-empty, then the address assertion |
| `PreToolUse\|Bash\|0` | `git commit` on the default branch | `BLOCKED: git commit/push on ` … |
| `PreToolUse\|Bash\|1` | `git commit` with a dirty `ai-docs/learnings` | `[auto-stage-learnings] ` |
| `PreToolUse\|Bash\|2` | `find $HOME` | `BLOCKED: broad find/bfs/grep -r over ` |
| `PreToolUse\|Bash\|3` | a `Co-Authored-By` trailer | `BLOCKED: git commit message contains a Co-Authored-By trailer.` |
| `PreToolUse\|Bash\|4` | three-dot diff on a commitless branch | `BLOCKED: ` + the empty-diff sentence |
| `PreToolUse\|Bash\|5` | a `.properties` search filter | `BLOCKED: this content search can surface deployed-config files ` |
| `PreToolUse\|Bash\|6` | a piped gate | `BLOCKED: a gate (build / test / lint / format / shellcheck) is ` |
| `PreToolUse\|Edit\|Write\|0` | a member `file_path` | `[propagation-rule-reminder] You are editing ` |
| `PreToolUse\|Edit\|Write\|1` | a write adding a `### ` header to `ai-docs/learnings.md` | `[archive-protection-reminder] ` |
| `PreToolUse\|*\|0` | seeded ledger, repeated call | **two emissions, both asserted.** *stdout:* `jq -e .hookSpecificOutput.permissionDecision`. *stderr:* one of the anchored forms `[loop-index] error-retry: `, `[loop-index] fanout: `, `[loop-index] loop: ` — its own comment calls that stderr line "the load-bearing half of this report, not decoration" |
| `PostToolUse\|Write\|Edit\|0` | a `### ` added not-last | `[learnings-append-check] ` |
| `PostToolUse\|Write\|Edit\|1` | a `.sh` failing `bash -n` (606 bytes when supplied, 0 otherwise) | `[sh-syntax-check] ` |
| `PostToolUse\|Bash\|0` | `git push` on a feature branch | `[pr-body-sync] ` |
| `PostToolUse\|*\|0` | real payload + `HARNESS_LOOP_DIR` | **none** — accepted non-emitter, proved behaviourally |
| `Stop\|-\|0` | seeded ledger, repeating bin | **stderr:** `[loop-index] coarse repeat: ` or `[loop-index] tier 3: ` — the second field, not the stream, is what separates these from `PreToolUse\|*\|0` |
| `SubagentStop\|-\|0` | same | same — byte-identical to `Stop`, separated by selection key |
| `PostToolUseFailure\|*\|0` | real payload + `HARNESS_LOOP_DIR` | **none** — accepted non-emitter |

**Disjointness (AC15a) is satisfiable with no change to any lib script — but NOT for the reason round 3
gave.** That draft said the stream separates `loop-index.sh` from `loop-verdict.sh`. It does not:
**both write a `[loop-index] …` line to stderr**, and `loop-index.sh:226` is the line its own comment
calls load-bearing. A maintainer holding the stream model would believe the suite safe for a reason that
is false, and the assertion as drafted compared a `jq` field against a stderr prefix and so never
examined the collision that actually exists.

**The separator is the SECOND FIELD after the bracket**, and the five values are pairwise distinct across
the two scripts — measured: `error-retry`, `fanout`, `loop` (`loop-index.sh`, from the `kind` it prints
at `:226`) versus `coarse repeat`, `tier 3` (`loop-verdict.sh`). So disjointness is asserted over
anchored `[loop-index] <field>: ` prefixes, with **both** of `loop-index.sh`'s emissions in the table.
Scoped to the 16 distinguishable commands and asserted pairwise over the marker column: the six
`BLOCKED:` commands differ after the prefix, the three `[loop-index]` commands differ in the second
field, and the two byte-identical pairs are excluded from the pair requirement by AC15a and separated by
their selection key instead. No marker is renamed, so the spec's "`hooks/lib/*.sh` internals are out of
scope" boundary stays intact.

**The `loop-result` acceptance is behavioural, replacing the denylist (finding 1).** Both commands are
run against the same seeded-ledger fixture task 5 already builds, and the acceptance is two-part:
**emitted output is exactly 0 bytes AND the ledger gained one row.** Measured this round: 0 bytes each,
2 rows written. The second leg is the non-vacuity witness — it proves the command ran rather than
no-opped, which a bare emptiness assertion could not. This detects any new emit path regardless of
spelling, which the grep could not: the reviewer's own refinement of it went green on the real file yet
missed `cat <<<"…"` and, by construction, anything not spelled `printf`/`echo`/`>&2`. The grep survives
only as an optional cheap second leg, never as the acceptance. Anything else that cannot be made to emit
is a plain finding, reported and not counted green.

**Granularity rule (AC4b), binding on the whole suite.** AC2 leg (i)'s marker is at **command**
granularity; an assertion about a substring of the output needs a witness at **that substring's**
granularity. So every address assertion is positive and address-scoped: the emitted reference must be an
absolute path that **begins with the root under test** and **ends in the expected method-file name**
(AC4a). The suite's assertion helper takes the expected granularity explicitly, so a command-level
marker cannot be offered as the witness for an address-level claim.

**Marker discipline (AC15).** Every assertion is an exact comparison or an anchored match, never a bare
substring test — verified on the shape that prompted the rule, where `STALE` is a substring of
`NOT-STALE` and both a bare `grep` and a glob `case` match the wrong verdict. A control feeds a near-miss
string to show the wrong output fails the right assertion.

**A hook that errors looks exactly like a hook that fired.** An arm probe in this task reported all
twelve paths firing, *including the negative control*, because the extracted command file did not exist
and every run printed an error to stderr. Hence no assertion is "output is non-empty", and the
guard-passed proof (AC14) is explicit: a guarded hook in a marker-free directory exits 0 in silence,
measured.

**AC7 rides with L3**, because the read allowance exists on account of what the hooks emit: the template
settings file must hold a `Read(` entry rooted at the install cache with no version literal, and that
pattern must `case`-match the live root. Measured: `Read(~/.claude/plugins/cache/*/harness/**)` matches
`…/cache/agent-harness/harness/0.1.29`, a future version's file, and a differently-named marketplace, and
does not match `~/.claude/settings.json` or the source tree.

### M4 — permissions, boundary, and registering the gate

- `templates/project/.claude/settings.json` gains `"Read(~/.claude/plugins/cache/*/harness/**)"`.
- `docs/agents-method.md § Permissions` gains **two short honour-system bullets** — the plugin directory
  is read-allowed (AC7), and the boundary (AC17): an agent in a consuming project works from the
  installed copy and never from the harness source repository, even when
  `~/.claude/harness/registry.json` makes its path known. Reasoning goes into an anchored subsection of
  `docs/workflow.md`. **Budget ≤ 400 chars**; the file is inside the size AXIOM's `minor` band, so
  `wc -c` after the edit is part of the task. Neither bullet may add an `AGENTS.md § …` reference naming
  a method-only section.
- `docs/claude-tools-hierarchy.md` § Project-defined Hooks: the line describing the reminder's arms
  becomes false when M2 lands, and the Propagation Rule routes any Hook-contract change there.

#### AC18b — the gate is numbered `5a`, and nothing renumbers

`AGENTS.md § Build & Test` numbers 1–8 continuously (1–5 structural, 6–8 delivery), so **numbering the
new gate 6 collides with the install-smoke gate that is already 6.** Two options were measured against
each other:

| | renumber (insert at 6, gates → 7–9) | **tombstone-style label `5a`** |
|---|---|---|
| count claims to update | 4 | **4** — identical; the count changes either way |
| numbered cross-references broken | **1** (`AGENTS.md:76` "invisible to gate 6") | **0** |
| delivery-count claims (`three delivery gates`, ×3) | stay true | stay true |
| precedent in the same list | — | item 3 reads `(folded into 2)`, a tombstone that held the numbering stable through a removal |

**`5a` is chosen**: strictly less churn, zero cross-reference breakage, and it follows the convention this
very spec used to grow from 22 criteria to 32 without moving a single existing id. It is a numbered entry
under AC18's plain reading, and the list already tolerates a non-sequential one. Round 2's rejection of
reusing slot 3 stands and is unaffected — `check-references.sh:8`'s "Mechanises structural checks 2 and
3" is true only while 3 stays a tombstone, and it does.

#### AC18a — discharged by search, and the search is a CANDIDATE GENERATOR, not an edit list

> **The search does NOT define the edit set. Never "update every hit".** The prior draft of this
> subsection said exactly that, and run verbatim it is **destructive**: it edits unrelated method files —
> three of them `ai-audit` sync-group members, whose "all five mandatory locations" is about Learning-Log
> field targets and not about checks at all — and it edits `ai-docs/learnings.md`, where § Learning Log
> Boundary rule 1 forbids editing a committed entry outright. The word "real" in the prior draft's
> "7 real hits" silently carried a triage that the instruction then dropped.

**Always two numbers, never one: the RAW hit count and the TRIAGED dependent count.** A single number
cannot say whether a triage happened, which is how the filtered figure got written down as the unfiltered
one. Both are re-derived at implementation time; the figures below are illustrative.

**Triage rule — a hit is a dependent if and only if it asserts the STRUCTURAL-CHECK count.** Everything
else is named and left alone:

| disposition | why | examples from this round's run |
|---|---|---|
| **dependent — edit** | asserts the structural-check count, which `5a` changes from five to six | `AGENTS.md` ×2 ("run all five", "The five structural checks"), `README.md` (count **plus** its enumeration), `ai-docs/context.md` ×2 — **five dependents, not the four AC18a records.** All five are now `six` in the tree and the search returns **zero** remaining `five` claims |
| triaged out — **delivery** count | `5a` renumbers nothing, so "three delivery gates" stays true | `README.md:285`, `README.md:315`, `ai-docs/context.md:87` |
| triaged out — `all five <non-check-noun>` | a different five entirely | `skills/ai-audit/SKILL.md` and `skills/ai-audit/reference.md` ("all five mandatory locations" / "all five targets" — Learning-Log field coverage), `skills/improve/SKILL.md`, `scripts/test-backlog-metrics.sh` ("all five are burst issues") |
| triaged out — **forbidden to edit** | append-only surface; Boundary rule 1 | `ai-docs/learnings.md` ("all five tickets") |
| triaged out — planning artefacts | self-referential, including this task's own spec and design | `ai-docs/plans/**` |

The raw-to-dependent ratio, not the tally, is the point; both numbers are re-derived at run time. Either
narrow the regex to the check context (e.g. requiring `structural` on the line) or apply the table above
hit by hit; the design permits both and requires that the disposition of every raw hit be recorded.

> **AC18a says "the true set is four". It is FIVE, and the reason the fifth was missed is the
> generalisable part.** `ai-docs/context.md` carries a second count claim — "wrapping the structural
> **five** in a single command" — where **the number FOLLOWS the noun**. Every pattern used to find these
> (`five structural`, `all five`, `five checks`) assumes the count-word comes first, so no
> count-word-adjacency regex reaches it. It is the **third independent miss of that same file**, and it
> vindicates the discharge-by-search mandate precisely by embarrassing its tally: the mandate was right
> about the mechanism and wrong about the number, twice. The durable form of the rule is therefore
> **search for the NOUN and triage, never for the noun-plus-count collocation** — a count claim can be
> spelled in any word order, and a regex that assumes one of them is a filter pretending to be a census.

**The companion search has the same shape, and its real set is smaller than recorded.**
`grep -rnoE 'check [1-8]|gate [1-8]|structural checks [1-8]'` returns, after triage,
`AGENTS.md` (check 4), `AGENTS.md` (gate 6) and `check-references.sh:8` (checks 2 and 3).
**`docs/instruction-file-validation.md` is a false positive** — it reads "Checklist M sub-check 1/2",
the same `Sub-check` class already triaged out of `skills/ai-audit`, so the prior "four real hits" was
one too many. Under `5a` **none of the real ones moved**, so the companion search's dependent set is
empty as predicted, and its job is to *prove* that — see AC18b's verification row. No count is pinned
here; the enumeration is the artefact and the count is re-derived with it.

**One spec sentence goes numerically stale and is deliberately NOT edited.** The spec's own AC21 reads
"All five structural checks green"; with `5a` there are six, and running six satisfies the criterion a
fortiori. It is a planning artefact, triaged out by the table above, and amending it is not design's to
do. Recorded here so a later reader sees a decision rather than an oversight.

**Two prior lists were each incomplete**, which is why the obligation is the rule rather than an
enumeration: `README.md:315` appeared in no list before this design, and
`docs/instruction-file-validation.md:37` appeared in none before the companion search was run.

#### AC18c — recorded decision

`ai-docs/context.md` is **admitted to the arms**, not excluded — see § M2. The decision and its reasoning
are recorded there, and the propagation of its check-count text is additionally covered by AC18a's
search. So context.md gains two independent nets rather than the hand-enumeration the AC offered as the
fallback.

---

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | **DONE (Group A).** The resolver: resolved path; read-access clause naming the directory when the target is unreadable; always exit 0. Readable branch guarded by `[ -n "$root" ]` so an unset root cannot print a project file as the plugin's address. Unreadable-branch output **byte-identical** to task 2's fallback string. Committed executable. | `hooks/lib/plugin-ref.sh` | — |
| 2 | **DONE (Group A).** Rewrote the message sites — **11** resolver call sites / guards / fallbacks feeding **12** message references — each block inside its hook's **firing branch**, never as a prefix. Uniform resolver call, `[ -n "$a" ] \|\|` emptiness guard, one cause-agnostic fallback, path passed as a `printf` argument. `SessionStart` to `jq -cn --arg`. No interior apostrophe; every command parses under `bash -n`. | `hooks/hooks.json` | 1 |
| 3 | **DONE (Group A, in two passes).** Replaced the `case` arms with the normalised, root-anchored **ten-arm set** — `ai-docs/context.md` plus the restored `"$pd"/.claude/skills/*/SKILL.md`, landed in a reopened second pass after the user approved it — added the unusable-anchor diagnostic, and corrected the hook-inventory line (which the first pass had left reading "Nine arms"). Verified against the tree: `grep -cF '.claude/skills' hooks/hooks.json` → 1. | `hooks/hooks.json`, `docs/claude-tools-hierarchy.md` | 2 |
| 4 | **DONE (Group B).** The derivation gate + its test: both-cell harvest, `§`-suffix strip, `<…>`→`*`, bare-filename resolution, catch-all leg asserting **both** `CLAUDE.md` and `ai-docs/context.md`, the single reasoned exclusion **and the single named carve-in** (`.claude/skills/*/SKILL.md`) under the dead-entry guard, **plus the old-arms regression assertion that stops the carve-in self-certifying**, absolute synthesised representatives, all controls. | `scripts/check-propagation-arms.sh`, `scripts/test-check-propagation-arms.sh` | 3 |
| 5 | **DONE (Group B; AC7's leg deferred to 7 — see the circularity note).** L3: selection by the manifest triple, the committed trigger inventory and marker table for all 18, two-part assertions, the six root states, address-granularity assertions, pairwise disjointness over the 16, the behavioural non-emitter acceptance, the four anchor controls, guard-passed proofs, the pre-fix-pattern fixture. | `scripts/test-hook-behaviour.sh` | 1, 2, 3 |
| 6 | **DONE (Group B).** L1: the every-occurrence property, the conservation assertion, two controls, and the AC20 format-argument leg. | `scripts/test-plugin-manifest.sh` | 2 |
| 7 | **DONE (Group C), verified against the tree:** template entry present (allow 21→22, deny byte-untouched, this repo's own `settings.json` unchanged); both `§ Permissions` bullets; `docs/workflow.md § Installed method half`; check `5a` registered with its non-sequential-numbering reasoning **and** the old-arms regression assertion in its description; check 4's suite list extended by two; **five** count claims now read `six` with **zero** `five` claims remaining; `plugin.json` at `0.1.31`. | `templates/project/.claude/settings.json`, `docs/agents-method.md`, `docs/workflow.md`, `AGENTS.md`, `README.md`, `ai-docs/context.md`, `.claude-plugin/plugin.json` | 1–6 |

> **Rows 5 and 7 were CIRCULAR on AC7, and that was a design defect rather than an implementation one.**
> Row 5 listed AC7's permission leg; row 7 listed the allowance that leg asserts. Group B, holding row 5,
> correctly refused to ship a knowingly-red suite and deferred the leg; Group C owned both halves and
> resolved it **RED-first** — the assertion written against the unchanged tree gave **108 passed / 9
> failed**, each failure naming its half, and the allowance plus the two method bullets then took it to
> **118/0**. The lesson for a future decomposition: **an assertion and the thing it asserts must sit in
> the same subtask, or the earlier one cannot be green at its own boundary.** RED-first is the resolution
> when they have already been split, because it converts a circular dependency into an ordered one.

Seven tasks, one purpose each. Task 7 is last by dependency: AC18a's searches and AC19's mode table
enumerate what tasks 1–6 create.

## Handoff plan

`M = 7`, recomputed. Maximum group size 3; non-terminal groups exactly 3; terminal group within 1..3.
`7 = 3 + 3 + 1`.

- **Entry into Group A:** spawn `/context-reset` per `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`
  before subtask 1 — bound at the start of every group, including the first.
- **Group A:** subtasks 1–3 — the resolver and both `hooks/hooks.json` rewrites. Exactly 3; non-terminal.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh
  context.
- **Group B:** subtasks 4–6 — the derivation gate, L3, L1. Exactly 3; non-terminal.
- **Handoff after Group B:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group C with fresh
  context.
- **Group C:** subtask 7 — terminal group (1 subtask; within the 1..3 range).

## Risks

- **The trigger inventory is the largest new surface, and a wrong trigger fails in the safe-looking
  direction.** A payload that does not trigger its hook yields 0 bytes — which AC2 leg (i) now catches, so
  a mis-built trigger surfaces as a failed marker assertion rather than a vacuous pass.
- **Normalisation adds two subshells per `Edit`/`Write`.** The hook already execs `harness-managed.sh` and
  `jq`; this is a bounded increase on an advisory hook. If it ever matters the remedy is to try the raw
  match first and normalise only on a miss — not to drop normalisation.
- **A `Write` into a not-yet-existing directory cannot be normalised** and falls back to raw matching.
  Bounded: the arms still fire for an already-physical-absolute path, so the degradation needs a
  non-physical spelling *as well*, and it fails silent. Precise boundary in § M2.
- **Case (d) has a cheap improvement that is deliberately NOT built now.** Instead of trusting the
  anchor, walk up from it looking for a harness marker — which is what `harness-managed.sh` is really
  testing. `design-review` judged the current concession honest and controlled and did not require it.
  Recorded here so it is findable if the documented invocation condition ever proves insufficient.
- **Case (d) is unfixable by construction**, so the hook depends on `CLAUDE_PROJECT_DIR` being the project
  root. Documented as an invocation condition and asserted as a control, not claimed as fixed.
- **Admitting `ai-docs/context.md` widens the reminder into a profile file.** Intended: it is an
  instruction file by the size AXIOM's own enumeration and demonstrably carries propagating text. The
  cost is one advisory line when a consumer edits their context file.
- **The `5a` label is unusual and a later reader may "tidy" it into 6.** The rejected alternative and its
  measured cost (one broken cross-reference) are recorded beside the list entry so the tidy-up has to
  argue with the measurement.
- **The AC9 control mutates a method file.** Planting a member row happens against a **copy** in a temp
  tree — the gate takes a `--root`, as `check-references.sh` does — never the live doc.
- **Check 4 lists TRACKED files only and this task creates four scripts.** `git add -N` on every new path
  first, and the **file COUNT** recorded alongside the exit status.
- **Four controls are committed artefacts that look like defects** — L1's planted boundary occurrence,
  L3's pre-fix `case` pattern, the degenerate-resolver fixture, and the perturbed anchors. Each sits in a
  named function whose comment says it is a preserved control and that changing it invalidates its AC.
- **`docs/agents-method.md` is inside the size AXIOM's `minor` band.** The ≤400-char budget keeps it
  there; `wc -c` after the edit is part of task 7.

## Test Design

No test framework; validation is `AGENTS.md § Build & Test`. Every command below was run this round in the
form given, and each gate was shown able to return non-empty.

**Task 1 — the resolver.** No sibling suite (under the 50-line threshold); branches exercised through real
hooks by task 5.

**Tasks 2/3 — `hooks/hooks.json`.** Entry point: each command via `bash -c "$cmd"` with a JSON payload on
stdin and `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PROJECT_DIR` / `HARNESS_LOOP_DIR` exported — the idiom
`hooks/lib/test-harness-managed.sh` already uses. Commands selected by the manifest triple.

**Task 4 — `check-propagation-arms.sh`.** Scenarios: real tree → clean; `--root` fixture with a planted
member row → fails naming the unmatched class; catch-all row deleted → fails on the missing `CLAUDE.md`
*and* `ai-docs/context.md`; an exclusion matching nothing → fails as dead drift; every control → silent.

**Task 5 — `test-hook-behaviour.sh`.** Fixtures: a dir carrying `AGENTS.md` (guard passes); a marker-free
dir (guard no-ops, asserted silent); a plugin tree with the target file unreadable; the same with the root
unreadable; a resolver that exits 0 printing nothing; a seeded ledger; a fixture project tree built under
the symlinked `/tmp` path so case (b) is real rather than simulated; and four perturbed anchors. Every
fixture asserts its own precondition before asserting behaviour.

**Task 6 — L1 legs.** The existing suite already iterates hook commands and carries an apostrophe leg with
its own positive control; the new legs join it rather than forming a new file.

| AC | verified by |
|---|---|
| AC1 | `bash scripts/test-hook-behaviour.sh` — `SessionStart` with the root set to a temp dir; `additionalContext` extracted by `jq -e`, then the AC4a address assertion; no dollar-brace |
| AC2 | `bash scripts/test-hook-behaviour.sh` — per command over all 18, with **stdout and stderr captured separately**: leg (i) the command's own anchored marker, read from **stdout alone** where the marker is a `jq` field and from **stderr** where it is a printed prefix; leg (ii) no dollar-brace over the **concatenation** of both streams. A merged capture returns `jq` rc 5 for `PreToolUse\|*\|0`, so the split is load-bearing, not tidiness. For the two accepted non-emitters leg (i) is the behavioural acceptance and leg (ii) is discharged by L1 |
| AC2a | `bash scripts/test-hook-behaviour.sh` — selection by the (event, matcher, index) triple passed as three values; a suite assertion re-derives `sort -u` over the 18 keys and requires 18 distinct |
| AC3 | `bash scripts/test-hook-behaviour.sh` — the trigger table is a committed constant driving the run; any command with no emit and no derived acceptance is reported as a finding |
| AC4 | `bash scripts/test-hook-behaviour.sh` — states 2 and 3 on the unguarded `sh-syntax-check`; asserts the emitted reference is not absolute and carries no ` /docs/` or ` /rules/` |
| AC4a | `bash scripts/test-hook-behaviour.sh` — positive, address-granularity: the reference begins with the root under test and ends in the expected filename. Control: state 6, a resolver that exits 0 printing nothing, asserted to produce the full message and **not** `See .` |
| AC4b | `bash scripts/test-hook-behaviour.sh` — the assertion helper takes the witness granularity explicitly; a suite self-check rejects an address-level claim offered with a command-level witness |
| AC5 | `bash scripts/test-hook-behaviour.sh` — states 4 and 5; message contains `read access to the plugin directory` **and** the root path, and no claim that the variable is unset; plus an exact `state4 == state5` comparison |
| AC6 | `bash scripts/test-hook-behaviour.sh` — the four root states as named assertion groups, each with its precondition asserted |
| AC7 | `bash scripts/test-hook-behaviour.sh` — the permission leg: a `Read(` entry rooted at the cache with no version literal, `case`-matching the live root; plus the method `§ Permissions` bullet present |
| AC8 | `bash scripts/check-propagation-arms.sh` — every derived class's **absolute** representative against the live `case` pattern, with the member count and enumeration asserted **together** and both re-derived at run time (no count is pinned here; the measured pair is in the evidence file), the carve-in's representative (`.claude/skills/*/SKILL.md`) among them; plus `bash scripts/test-hook-behaviour.sh` running the real hook for at least one previously-silent class |
| AC9 | `bash scripts/test-check-propagation-arms.sh` — `--root` fixture with a planted member row; gate asserted to FAIL and to name the class |
| AC10 | `bash scripts/test-check-propagation-arms.sh` — `CLAUDE.md` **and** `ai-docs/context.md` present via the catch-all leg; deleting the catch-all row from the fixture drops both and fails the gate |
| AC11 | `bash scripts/check-propagation-arms.sh` — the **13** controls all silent (gate `5a` reports 13 silent against 35 derived members), count and enumeration both asserted so a tally drift fails rather than passes; `ai-docs/plans/*.spec.md` and the five bound paths are among them; re-asserted in its test |
| AC11a | `bash scripts/test-hook-behaviour.sh` — (a) trailing slash, (b) realpath divergence, (c) relative anchor each asserted **FIRING** after normalisation and **silent** against the un-normalised matcher, so a fail-open is a failed test; (d) asserted as the documented invocation condition plus a silent-verdict control. **The diagnostic leg is two-part and NOT end-to-end** (§ M2 → guard-shadow): the **post-guard fragment** asserted to emit the diagnostic on an unusable anchor and stay silent on a usable one, **and** the **full** command asserted to emit exactly 0 bytes on the same unusable anchor, so the shadowing is a tested property. An end-to-end assertion here fails by design and must not be written |
| AC11b | `bash scripts/test-hook-behaviour.sh` — the fixture project tree is built under the symlinked `/tmp` path and the payload is spelled `/private/tmp/…`, so the divergent pair is real; `realpath /tmp` is asserted to differ from `/tmp` as the fixture precondition, and the suite skips loudly rather than passing if it ever does not |
| AC12 | `bash scripts/test-plugin-manifest.sh` — the property keyed on the **braced** token `${CLAUDE_PLUGIN_ROOT}` (never the bare name, which flags the legitimate `${CLAUDE_PLUGIN_ROOT:-}` form), plus windowed == unwindowed; on the working tree all three figures are **11** with **0** non-conforming. Controls: a planted non-conforming occurrence and a planted boundary occurrence, each degrading the **operator** rather than deleting a nearby token |
| AC13 | `bash scripts/test-hook-behaviour.sh` — the pre-fix `case` pattern as a committed in-suite constant, asserted to match only `AGENTS.md` of the member classes. **Extended per review issue 3:** the same constant is the independent source for a **regression assertion — no path the OLD arms matched is silent under the new set** — which is what stops the carve-in certifying itself from its own class string, and which would have caught the missing tenth arm unprompted |
| AC14 | `bash scripts/test-hook-behaviour.sh` — per guarded hook, an assertion that fails if it had silently no-opped, paired with a marker-free-dir run asserted silent |
| AC15 | `bash scripts/test-hook-behaviour.sh` — exact or anchored throughout, plus a near-miss control showing the wrong output fails the right assertion |
| AC15a | `bash scripts/test-hook-behaviour.sh` — pairwise non-substring over the marker column of the **16** distinguishable commands, including **both** of `loop-index.sh`'s emissions, so the three `[loop-index]` commands are compared on their second field (`error-retry` / `fanout` / `loop` / `coarse repeat` / `tier 3`) and not on their stream; the two byte-identical pairs asserted distinguished by selection key instead |
| AC15b | `bash scripts/test-hook-behaviour.sh` — the marker table covers all 18 rows; the two unmarked commands carry their behavioural acceptance in the same table, so no command is silently absent |
| AC16 | the six controls are committed constants or in-suite planted cases, re-runnable: AC4a (degenerate resolver), AC9 (planted table member), AC11a (three perturbed anchors), AC12 (planted unexpanded + boundary occurrences), AC13 (pre-fix pattern), AC15 (near-miss output) — across `bash scripts/test-hook-behaviour.sh`, `bash scripts/test-check-propagation-arms.sh`, `bash scripts/test-plugin-manifest.sh` |
| AC17 | `bash scripts/check-references.sh` green; plus `grep -n 'installed copy' docs/agents-method.md` returning the boundary bullet |
| AC18 | `grep -n` in `AGENTS.md § Build & Test` showing the gate as numbered check `5a` with its own body |
| AC18a | both searches **re-run** at implementation time, each recording **two numbers — raw hits and triaged dependents** — and the disposition of every raw hit per § M4's triage table. **Only structural-check-count hits are edited**; delivery-count hits, `all five <non-check-noun>` hits, `ai-docs/learnings.md` (append-only) and `ai-docs/plans/**` are named and left alone. "Update every hit" is forbidden: run verbatim it edits five unrelated files and one it is forbidden to touch |
| AC18b | after the `5a` edit, every real numbered cross-reference is **unchanged** — `AGENTS.md` (check 4), `AGENTS.md` (gate 6) and `check-references.sh` (checks 2 and 3), with `docs/instruction-file-validation.md` and `skills/ai-audit`'s `Sub-check` hits triaged out as false positives — so the dependent set is proved empty rather than assumed; enumeration asserted, count re-derived; and `bash scripts/check-references.sh` + `bash scripts/check-readme-update.sh` are green |
| AC18c | `bash scripts/check-propagation-arms.sh` deriving `ai-docs/context.md` and the arms firing on it (AC10's assertion), plus the recorded decision in § M2 |
| AC19 | `git ls-files -s` on the four new paths — `hooks/lib/plugin-ref.sh` **100755** (production invokes it by path), the three `scripts/` entries **100644** (invoked `bash scripts/…`); `plugin-ref.sh` exercised by path in `test-hook-behaviour.sh` |
| AC20 | `bash scripts/test-plugin-manifest.sh` — apostrophe count stays 0; every command parses under `bash -n`; plus a leg asserting every `plugin-ref.sh` occurrence is preceded by `=$("$r"/hooks/lib/`, which forbids inlining a path into a format |
| AC21 | `jq -e .` on the three manifests; `bash scripts/check-references.sh`; `bash scripts/check-propagation-arms.sh`; `git add -N <new paths>` then `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` with the processed COUNT recorded; every suite in check 4's list; `bash scripts/check-readme-update.sh` |
| AC22 | `.claude-plugin/plugin.json` reads `0.1.31`; `bash scripts/check-release.sh` |

## Open questions

None, and the two items this section carried in round 2 are closed:

- **`scripts/check-release.sh:20` does not sit in the spec's § Deferred** — round 2 said it did. Verified:
  § Deferred now holds a single unrelated row (the `settings.json` pair), and `check-release.sh:20` went
  to **GH-77** with the rest of the `origin/main` disposition. Nothing in this design depends on it.
- **The state-4/state-5 byte-identity claim is no longer unasserted** — it is a design constraint on the
  resolver's and the fallback's wording, and an exact string comparison in the suite (§ M1, AC5).

The one item the spec leaves to design — where AC9's derivation lives — is answered in § M2: a gate that
parses the table and asserts agreement, chosen over generation and over a runtime single source, with the
reasons recorded there.
