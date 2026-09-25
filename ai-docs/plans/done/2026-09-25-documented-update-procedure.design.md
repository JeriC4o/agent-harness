# Design: Documented update procedure does not update

**Ticket:** GH-43
**Date:** 2026-09-25
**Spec:** ai-docs/plans/2026-09-25-documented-update-procedure.spec.md

## Approach

### Shape

One canonical procedure in `README.md` § Update, a cross-link from § Releasing, and two new gates that
between them cover the doc's *wording* and the doc's *effect*:

| Arm | Script | Needs `claude`? | What it can see |
|---|---|---|---|
| A — deny-list | `scripts/check-readme-update.sh` (new) | no | the README names a verb that cannot upgrade |
| B — upgrade smoke | `scripts/test-upgrade-smoke.sh` (new) | yes, else exit 2 | the README's own commands, executed, fail to move the payload |

Arm B is the stronger of the two and the one that would have caught the original defect: it does not
re-type the procedure, it **extracts the fenced `claude …` lines out of § Update and runs them**, then
asserts the installed payload moved. A README that documents a no-op turns arm B red by construction.
Arm A exists because arm B costs ~20 s and a `claude` CLI, and the structural checks must stay runnable
on a machine with neither.

### Everything below was measured in this session, not reasoned

Every claim this design pins as a contract was executed against the real `claude` CLI (2.1.273) in a
throwaway `$CLAUDE_CONFIG_DIR`. Reference prototypes of both new scripts, in the state they were proven,
are at `/private/tmp/claude-501/-Users-jc-projects-agent-harness/8695f91b-f0f2-4045-a512-f1f26c5d1880/scratchpad/check-readme-update.sh`
and `…/scratchpad/test-upgrade-smoke.sh`. The design is self-contained; the prototypes are corroboration,
not an input.

| Observation | Measured |
|---|---|
| `claude plugin update harness` (bare) | works — `✔ Plugin "harness" updated from 0.0.1 to 0.0.2 for scope user. Restart to apply changes.` |
| `claude plugin update harness@agent-harness` | works identically |
| `claude plugin update harness@agent-harness --scope user` | works; `--help` says `-s, --scope <scope>` already **defaults to `user`** |
| `claude plugin install harness@agent-harness --scope user -y` against an existing install | rc **0**, `✔ Plugin "harness@agent-harness" is already installed (scope: user)`, cache **unchanged** |
| `claude plugin update` with no prior `marketplace update`, filesystem marketplace | moved the payload — the catalog is re-read from the path |
| `claude plugin update` when already current | rc 0, `✔ harness is already at the latest version (0.0.2).` — a clean no-op |
| `claude plugin update nosuchplugin` | rc **1**, `✘ … is not installed` — the verb fails loudly, so arm B has no silent-pass mode |
| cache after a successful update | `0.0.1` **and** `0.0.2` both present — the old directory is **not** removed |
| `claude plugin marketplace add file:///…/repo.git` | **rejected** — `✘ Invalid marketplace source format. Try: owner/repo, https://..., or ./path` |

### Decisions taken, with one-line reasons

The full interrogation of each (alternatives weighed, evidence quoted) is in the git history of this
file at review rounds 1–2; what an implementer needs is the decision and why it cannot be casually
reversed. Every "measured" below is in the table above or in the per-task leg tables.

| # | Decision | Reason it is not arbitrary |
|---|---|---|
| Q1 | Document `harness@agent-harness`, not bare `harness` | Both measured working. Consistency with README.md:16/:25/:26 — a reader copies patterns — and unambiguous against a second marketplace offering a `harness`. |
| Q2 | **No** `--scope` on the documented command; scope covered in prose | The verb already defaults to `user` (`--help`). Hard-coding it is *silently wrong* for a reader who took § Install's `--scope project` row — the same silent-success class this ticket exists to remove. |
| Q3 | Document how to confirm, in two separate halves | `claude plugin list` is evidence the **cache** moved (measured, pre-restart); the only evidence about the **session** is that it started after the update. Confirmation without that caveat installs the exact false confidence that let this machine sit five versions behind. |
| Q4 | Deny-list as a **new** `scripts/check-readme-update.sh` | Grafting it onto `check-references.sh` would falsify that script's own header ("mechanises checks 2 and 3") and force every synthetic fixture tree to carry a README. A separate script earns its own numbered entry (AC8) and its own exit code. Its `--root` flag is what makes the AC6 proof run the *real* checker against a synthetic tree. |
| Q5 | Smoke test asserts on **both** observables plus a negative control | Measured: the cache keeps *both* versions after an update, so a cache-only assertion cannot say which is live; `plugin list` can. The negative control is what gives the gate a leg that reproduces the bug. |

### Rejected, so they are not re-litigated

| Rejected | Why |
|---|---|
| Fold arm B into `test-install-smoke.sh` | Out of scope per the spec, and correctly: that gate's empty-sandbox premise is load-bearing for what it *does* check. |
| Blanket "README must not contain `plugin install`" | § Install legitimately carries it (README.md:16, :25, :26) and AC2 *requires* § Update to name it in prose. |
| Deny-list scoped to § Update only | AC6 forbids it, and rightly — the defect was in § Releasing too, and a future § Upgrading would be invisible. |
| Deny-list also policing AC3's restart wording | Brittle wording lock outside AC6's scope, and unnecessary: today's § Update trips D2/D3 without it. |
| Arm B retyping the documented commands | Then script and README can drift and the gate passes against a README nobody can follow. Extraction is what couples them. |
| `eval` on the extracted lines | Executing text lifted from a file. Replaced by a character-class guard + word-split invocation; measured against an injected `&& rm -rf /tmp/x`. |
| Version sentinels derived from the real version | Patch can be 0; arithmetic on a version string is a needless failure mode. Fixed `0.0.1` → `0.0.2`. |
| A committed fixture README under `scripts/fixtures/` | `scripts/test-check-references.sh` builds fixtures as heredocs; following it keeps a frozen defect snapshot out of the shipped payload. |
| Reusing the vacant `3. (folded into 2)` slot | Would falsify `check-references.sh:8` and erase a deliberate historical marker. New check is **5**; delivery gates renumber to 6/7/8. |

### The recurring failure — read this before adding any guard

Across two review rounds, **every** finding against this design has been a claim about *what a check can
see*, never about what the fix does. The substance has survived every falsification attempt: extract the
commands out of § Update rather than retyping them; the file-qualified `README.md#update` anchor; count
processed files rather than reading an exit status; the install-short-circuit negative control. What kept
slipping was the reach of the small greps added to police it — twice, in the same direction:

| Round | The guard | Why it passed vacuously |
|---|---|---|
| 1 | a prose list of "two further sites" | `README.md:287` (§ Roadmap) was never in it |
| 2 | `grep -rn 'two delivery gates\|four structural checks' …` must be empty | literal phrases, line-based: missed `README.md:258` (the phrase **spans a line break**), `ai-docs/context.md:86` ("structural **ones**") and `:89` ("**structural four**" — reversed word order) |

Both times the guard would have gone green over three stale clauses. **The rule, stated plainly: a guard
whose pass condition is empty output must be shown non-empty on the tree it will actually run against,
in EVERY SPELLING the target text uses — not once, in the spelling the author had in mind.** Where the
target set is known and finite, prefer an *enumerate-and-read* check, whose failure mode is a wrong count
rather than a silence that cannot be told from success.

**And it generalises one step further than the two rounds above.** The GO review found this document's
own R13 and Decomposition row 6 still saying "four sites" after the table had gone to seven — a
count-stating sentence left behind *while fixing count-stating sentences left behind*, the fourth
occurrence of the class in three rounds. So: **a document that states a count in more than one place
needs a probe — including this one.**

### The one finding that changes a stated AC

**AC4's "that link resolves under `bash scripts/check-references.sh`" is vacuous unless the cross-link is
file-qualified.** `scripts/check-references.sh:121` skips fragment-only hrefs:

```
      http://*|https://*|mailto:*|'#'*|'') continue ;;
```

Measured on a full copy of this tree with the corrected README: `[§ Update](#update)` → rc 0, and
`[§ Update](#updatez)` → **also rc 0**. With `[§ Update]\(README.md#update)` → rc 0, and
`[§ Update]\(README.md#updatez)` → rc 1, `blocker|L2|README.md:266: no heading in README.md slugifies to
#updatez`. So § Releasing must link `[§ Update]\(README.md#update)`. Same-file anchors are otherwise
unchecked in this repo; extending `check-references.sh` to resolve them is a separate concern and is not
done here.

### The one claim this design does NOT verify

Whether `claude plugin marketplace update` is **required** before `plugin update` for a *remote*
(GitHub-backed) marketplace. It was measured to be unnecessary for a filesystem marketplace and to be a
harmless no-op when the catalog is already current. An attempt to stage a git-backed marketplace locally
was refused by the CLI (`file://` is not an accepted source form), so the remote case was not reachable in
a sandbox. The CLI's own error text treats the catalog as a local copy that goes stale — `Plugin "harness"
not found in marketplace "agent-harness". Your local copy may be out of date — try 'claude plugin
marketplace update agent-harness'` — which is evidence, not proof. **The decision does not rest on it**:
documenting the refresh step is justified by its measured harmlessness alone, and the README describes it
as "refreshes this machine's local copy of the marketplace catalog" rather than asserting it is required.

## Decomposition

| # | Task | Files | Depends on |
|---|------|-------|------------|
| 1 | Rewrite § Update as the canonical procedure: two-command fence, the `install`/`marketplace update` trap in **prose** (never in a fence), the scope sentence, the two-restarts table, the `plugin list` caveat; keep the existing "your project profile is untouched" paragraph | `README.md` (replacing lines 164–172) | — |
| 2 | Replace § Releasing's command fence and its "Then restart the session" line with one file-qualified cross-link; heading and the rest of the section untouched | `README.md` (replacing lines 239–246) | 1 |
| 3 | New deny-list gate, `--root <dir>`, awk-based, exit 0/1/2, findings D1/D2/D3 | `scripts/check-readme-update.sh` | 1, 2 |
| 4 | Test suite for the deny-list: heredoc fixtures, mutation legs, the frozen today's-wording negative control, this repo as the positive control | `scripts/test-check-readme-update.sh` | 3 |
| 5 | New upgrade smoke gate: sandbox, lowered temp copy, install-short-circuit negative control, README-extracted procedure, both observables, exit 2 without `claude` | `scripts/test-upgrade-smoke.sh` | 1 |
| 6 | Register both gates and propagate the counts: new structural check **5**, delivery gates renumbered **6/7** and new **8**; add the new suite to check 4's list; update **all seven** sites that state the gate counts | `AGENTS.md` (§ Build & Test), `README.md` (§ Developing the harness itself **and § Roadmap**), `ai-docs/context.md` (§ Build & test commands) | 3, 5 |
| 7 | `git add -N` the three new scripts **first**; bump `.claude-plugin/plugin.json` 0.1.18 → 0.1.19; run the whole gate set and record the file count each index-driven gate processed; draft the AC11 follow-up ticket proposal for delivery | `.claude-plugin/plugin.json` | 1–6 |

## Handoff plan

M = 7. Maximum group size is 3 consecutive subtasks; non-terminal groups are exactly 3; the terminal group
must land in 1..3.

- **Entry into Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md` before starting subtask 1.
- **Group A:** subtasks 1–3 — the README correction and the deny-list gate it must satisfy.
- **Handoff after Group A:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group B with fresh
  context.
- **Group B:** subtasks 4–6 — the deny-list suite, the upgrade smoke gate, and gate registration.
- **Handoff after Group B:** spawn `/context-reset` per
  `${CLAUDE_PLUGIN_ROOT}/skills/context-reset/SKILL.md`. Parent `/task` resumes in Group C with fresh
  context.
- **Group C:** subtask 7 — terminal group (1 subtask; within the 1..3 range).

### Two things each group must do before believing its own gate

**Group B, on Task 6's seven-site propagation:** run the AC8 probe **before** editing (expect 7 lines
reading *four* / *two*, stale-count 7) and **after** (expect 7 lines reading *five* / *three*,
stale-count 0), and **record both outputs**. Running it only afterwards is how you get a green from a
probe that was already broken — the before-run is what proves the instrument works on this tree.

**Group C, on Task 7 step 0:** `git add -N` the three new scripts, then confirm
`git ls-files '*.sh' | wc -l` reads **27** *before* believing any gate result. 24 tracked today,
re-measured at GO. A gate that ran over 24 files has not seen this task's work, whatever it exited with.

## Task detail

### Task 1 — § Update, the canonical procedure

Replaces `README.md` lines 164–172 (heading, the lone `/plugin marketplace update` fence, and the
"Your project profile is untouched" paragraph — the paragraph is **kept**, moved to the end). This exact
text was run through both new gates and through `check-references.sh` before being written down:

````markdown
## Update

Moving an installed copy to a newer version takes **two** commands, in this order:

```bash
claude plugin marketplace update agent-harness
claude plugin update harness@agent-harness
```

The first refreshes this machine's local copy of the marketplace catalog; the second is the one that
moves the installed payload.

**`claude plugin install` is not an upgrade path.** Against an existing installation it short-circuits,
prints `✔ Plugin "harness@agent-harness" is already installed (scope: user)`, and exits 0 — a success
message with the payload untouched. `claude plugin marketplace update` on its own refreshes catalog
metadata and nothing else. Run together they read like an upgrade and are not one.

`update` applies to the scope you installed into and defaults to `user`. If you installed with
`--scope project`, pass `--scope project` here too.

**Then start a *new* session.** Two different things get called "restarting", and only one of them
picks up a new plugin version:

| What you do | What it picks up |
|---|---|
| Resume a session (`claude --resume`) | your **project profile** — `AGENTS.md`, `ai-docs/` — re-read on resume |
| Start a **new** session | the **plugin** — skills, agents and hooks, at the newly installed version |

A resumed session keeps the plugin version it started with, however many times it re-reads your project
files. `claude plugin list` reports the new version as soon as the update lands — but that is a statement
about the cache on disk, not about the session you are sitting in. The only confirmation that a session
is running the new version is that the session was started after the update.

Your project profile is untouched by an update — it lives in your repo, not in the plugin. If a new
harness version adds template files, `/harness:harness-init` picks them up on a re-run without disturbing
anything you have edited.
````

**Authoring constraint the gate enforces:** the commands that do *not* work appear only as inline code
spans in prose. Putting `claude plugin install …` in a fence anywhere outside § Install trips D1.

### Task 2 — § Releasing, cross-link

Replaces `README.md` lines 239–246 ("Consumers update with:", the two-line fence, and "Then restart the
session — hooks are read at start.") with exactly one line — **the `\` before `(` is not part of it**:

```markdown
Consumers update with the procedure in [§ Update]\(README.md#update): `claude plugin update`, then a new session.
```

Drop that backslash when writing `README.md`. It is present here only so this design file does not itself
trip `check-references.sh` L1: the scanner is line-based and does not skip fenced blocks, so a real
markdown link written anywhere in `ai-docs/plans/` resolves `README.md` against that directory and fails.
Measured: the plain form is flagged, `]\(` and `] (` are not. The same reason
`scripts/test-check-references.sh:40–44` assembles its `${CLAUDE_PLUGIN_ROOT}` fixtures from a variable.

The `README.md#update` qualifier is **not** stylistic — see § Approach, "The one finding that changes a
stated AC". `## Releasing` and everything above "Consumers update with:" stay byte-identical, so
`AGENTS.md:127`'s `README.md#releasing` keeps resolving.

### Task 3 — `scripts/check-readme-update.sh`

Interface, mirroring `check-references.sh`: `check-readme-update.sh [--root <dir>]`, exit **0** clean,
**1** findings, **2** usage/environment error (no such directory, no `README.md` under the root). Findings
print to stderr as `CLASS|line|message`, one per line, under a `REFUSED` banner.

One `awk` pass tracks the current `## ` section and whether it is inside a fence. `Install` is the single
exempt section — AC5 grants it explicitly. Three finding classes:

| Class | Fires when | Rationale |
|---|---|---|
| **D1** | a fenced line in a non-exempt section matches `plugin[ \t]+install` | a command in a fence is an instruction to run; catches `/plugin install` and `claude plugin install` alike |
| **D2** | a fenced **block** in a non-exempt section contains `marketplace[ \t]+update` but no `plugin[ \t]+update` | metadata refresh with no upgrade verb — today's § Update exactly |
| **D3** | no fenced line anywhere in § Update matches `plugin[ \t]+update` | the positive requirement; without it, deleting the fence would pass D1 and D2 |

D2 is block-scoped, not line-scoped — the two commands sit on separate lines of one fence, so a
line-scoped rule would flag the corrected README. `marketplace update` and `plugin update` do not overlap
as substrings: `claude plugin marketplace update` contains `plugin marketplace update`, never
`plugin update`.

**Proven, at design time, with the real script against real trees:**

| Leg | Result |
|---|---|
| today's `README.md` | rc **1** — D2 §Update:166, D1 §Releasing:243, D2 §Releasing:241, D3 |
| the corrected README (Tasks 1+2 applied) | rc **0** |
| corrected, `install` swapped into the § Update fence | rc 1 — D1, D2, D3 |
| corrected, upgrade verb deleted from the fence | rc 1 — D2, D3 |
| corrected, a **new** `## Upgrading` section with an `install` fence | rc 1 — D1 (proves whole-file scanning) |
| corrected, the old block restored into § Releasing | rc 1 — D1, D2 |
| corrected, unmodified (§ Install keeps its `install` fences) | rc **0** — the exemption holds |
| `--root /nonexistent` / root without a README / unknown flag | rc **2**, **2**, **2** |

### Task 4 — `scripts/test-check-readme-update.sh`

Follows `scripts/test-check-references.sh`: `ok`/`bad`/`has`/`hasnt`/`check` helpers, a `mktemp -d`
fixture tree with a `trap` cleanup, planted defects, and this repository as the final positive control.

**How the AC6 fixture lives.** A heredoc inside the suite, carrying today's § Update and § Releasing
**verbatim** — lifted at implementation time from `git show origin/main:README.md` — with the source
commit named in a header comment. It is deliberately **frozen**: it is a regression snapshot of a known
defect, so it must not track the README. A `git show`-at-runtime fixture was rejected because the moment
this PR merges, `origin/main:README.md` becomes the *corrected* text and the negative leg would invert.

**How the proof is run.** The suite calls the real `check-readme-update.sh --root "$FIXTURE"`. Legs:

1. **The frozen negative control** — a tree whose README is today's wording: expect rc 1 and a `D2`
   finding naming `Update`.
2. **Mutation legs.** The live `README.md` is **copied into the fixture tree and mutated there** — the
   file under test is never edited in place. These legs cannot rot, because each run re-copies the
   shipped file before mutating the copy:
   `install` swapped into the § Update fence; upgrade verb deleted; a new `## Upgrading` section with an
   `install` fence; the old block restored into § Releasing. Each must be caught, and each leg asserts on
   the finding *class*, not merely on rc.
3. **The exemption control** — an unmutated copy of the live `README.md`: rc 0, and § Install still
   carries `plugin install` in a fence (assert that, so a leg that passed because the fence vanished is distinguishable
   from one that passed because the exemption worked).
4. **Usage** — `--root /nonexistent` → 2; an empty root → 2; an unknown flag → 2.

Leg 2 is what stops the checker degenerating into a no-op; leg 1 is what ties it to the historical defect.

### Task 5 — `scripts/test-upgrade-smoke.sh`

Sequence, all of it measured end-to-end:

1. `command -v claude` or **exit 2** with the `test-install-smoke.sh` wording ("this gate cannot run …
   do not treat its absence as a pass"). Verified: `PATH=/usr/bin:/bin` → rc 2.
2. `SANDBOX=$(mktemp -d)`, `TREE=$(mktemp -d)`, `trap 'rm -rf …' EXIT INT TERM`,
   `export CLAUDE_CONFIG_DIR="$SANDBOX"`. Nothing outside the sandbox is written.
3. Copy the working tree into `$TREE` with
   `git ls-files -z --cached --others --exclude-standard | xargs -0 …` — tracked **plus** untracked-but-
   not-ignored, so the scripts added by this very PR are in the copy before they are committed (98 files
   here; the tracked-only form gives 97 and would miss them).
4. **Guard the copy**: if `$TREE/.claude-plugin/plugin.json` is absent, **exit 2**. Observed during
   prototyping — a copy that silently comes back empty produces eleven confusing downstream failures
   instead of one honest environment error.
5. `jq` the version down to `0.0.1`; `claude plugin marketplace add "$TREE"`;
   `claude plugin install harness@agent-harness -y`. Assert `…/cache/agent-harness/harness/0.0.1` exists
   and `plugin list` reports `0.0.1`.
6. `jq` the copy's version **up** to `0.0.2`.
7. **Negative control — the trap, measured rather than asserted in prose:**
   `claude plugin install harness@agent-harness --scope user -y` must exit **0**, must print
   `already installed`, must leave `…/harness/0.0.2` **absent**, and `plugin list` must still not mention
   `0.0.2`.
8. **The documented procedure, extracted not retyped.** Pull the fenced `claude …` lines out of § Update
   of the repo's own `README.md`:
   `awk '/^## /{s=substr($0,4)} /^```/{f=!f;next} f&&s=="Update"&&/^claude /' README.md`.
   If the extraction is **empty, FAIL and stop** — do not skip, do not pass. Run each line after a
   character-class guard (`case "$step" in *[!A-Za-z0-9\ @._-]*) bad …; continue ;; esac`) and invoke it
   word-split, **without `eval`**.
9. Assert **both** observables: `…/cache/agent-harness/harness/0.0.2` exists, `plugin list` reports
   `0.0.2`, and the plugin is still `✔ enabled`.

**Proven, at design time:**

| Leg | Result |
|---|---|
| against a tree with the corrected README | **0 failed**, rc 0 (the prototype reported `13 passed`; see the note below before pinning that number) |
| against a tree with **today's** § Update | rc 1 — `FAIL section Update carries no runnable claude command` (the empty-extraction guard, loud not silent) |
| against a tree whose § Update documents `claude plugin install` as the upgrade | rc 1 — every command exits 0, and the gate fails on `cache carries 0.0.2 (has: 0.0.1)` and `plugin list reports 0.0.2`. **This is the original GH-43 defect, reproduced.** |
| `PATH=/usr/bin:/bin` (no `claude`) | rc **2** |
| § Update fence carrying `claude plugin update harness && rm -rf /tmp/x` | refused by the metacharacter guard, and the run fails |

**The pass count is `0 failed`, not `13 passed`.** The `13` came from the prototype, which is *not* the
script Task 5 specifies: it lacks step 4's `plugin.json` guard and carries only the first line of the
exit-2 message, where step 1 mandates `test-install-smoke.sh:40`'s second line as well ("It is the only
check that exercises the install path -- do not treat its absence as a pass." — adapted to name this
gate). Neither addition is an `ok`/`bad` call — the guard exits 2 before any assertion runs, and the
message is a `printf` — so the count *should* still land on 13. But it is a prediction about a script
nobody has run, so **the gate is `0 failed`**; treat 13 as a corroborating detail, not a contract.

**Two shell hazards proven the hard way.** (a) A backtick inside a double-quoted message string is a
command substitution when the script runs: `ok "section Update carries runnable \`claude\` commands"`
silently executed bare `claude`, which sat 3 s on stdin and emitted `Error: Input must be provided …`.
No backticks in message strings. (b) `( cd "$ROOT" && git ls-files … )` against a non-repo prints
`fatal: not a git repository` to stderr and returns nothing — hence the step-4 guard.

### Task 6 — registration and count propagation

`AGENTS.md` § Build & Test:

- line 24: "run all four" → "run all five".
- new entry **5** after the check-4 block: `bash scripts/check-readme-update.sh` — refuses a README whose
  update surface names a verb that cannot upgrade; needs no `claude` CLI.
- check 4's suite list (lines 46–51) gains `scripts/test-check-readme-update.sh`.
- line 53: "these two validate" → "these three validate"; line 54's "Both exist because a bug got past all
  four structural checks" is reworded — the third gate exists for a different reason (both existing
  delivery gates are blind to an upgrade against a *pre-existing* install).
- `5.` → `6.` (install smoke), `6.` → `7.` (check-release), new `8.` `bash scripts/test-upgrade-smoke.sh`
  — runs § Update's own commands against a lowered install and requires the payload to move; exits 2
  without the `claude` CLI.

Numbering is deliberate: **check 4 keeps its number**, because line 21's `%LINT_CMD%` row says "see check
4" and two Learning Log entries cite "AGENTS.md check 4"
(`ai-docs/learnings/JeriC4o-GH-29-harness-feedback-channel.md:45,57`). The `3. (folded into 2)` marker
stays, because `scripts/check-references.sh:8` describes itself as mechanising "structural checks 2 and
3". A repo-wide grep found **no** reference to delivery gates 5 or 6 by number outside `AGENTS.md`, so
renumbering them is safe.

**Propagation — SEVEN sites state the counts and every one of them ships false unless updated.** This
list took three rounds to get right; the two earlier drafts are recorded in § The recurring failure,
because *how* they were wrong is the lesson. The sites, each verified verbatim at amendment time:

| # | Site | Says today | Must say |
|---|---|---|---|
| 1 | `README.md:257` (§ Developing the harness itself) | "The gate is **four** structural checks" | **five** |
| 2 | `README.md:258` — *same sentence*, wrapped | "plus **two** delivery ⏎ gates:" | **three**, with the deny-list added to :257's inline enumeration and the upgrade smoke to the gate list |
| 3 | `README.md:287` (§ **Roadmap**) | "hook guards, and **two** delivery gates." | **three** delivery gates |
| 4 | `AGENTS.md:54` | "Both exist because a bug got past all **four** structural checks" | reworded for **five** checks and **three** gates — inside the section Task 6 already rewrites, but named here so it is not lost among the renumbering |
| 5 | `ai-docs/context.md:86` | "**four** structural **ones** over the repo's" | **five** |
| 6 | `ai-docs/context.md:87` — *same sentence* | "plus **two** delivery gates (`test-install-smoke.sh`, `check-release.sh`)" | **three**, naming both new scripts |
| 7 | `ai-docs/context.md:89` | "mechanising the **structural four** as a script is an open task" | **structural five** — but see the caveat below: this sentence is partly obsolete beyond its numeral, because two of the five *are* scripts after this task |

**The `:89` tension, resolved here rather than left to the implementer.** Row 7 may legitimately be
reworded to drop its count instead of swapping the numeral — the sentence claims the structural checks
are unmechanised, which this task makes false for two of them. If that happens the probe prints **6**,
not 7, and AC8's line-count leg goes red as a **false** red. That is allowed, on one condition, mirroring
R12's treatment of the `27`: **change the expected count to 6 deliberately, in the same commit, with the
reason recorded** — "site 7 was reworded to drop its count because two of the five are now scripts". Do
**not** silently edit 7 to match whatever the run printed. The stale-count leg is unaffected either way:
it reads 0 whether `:89` says "structural five" or says nothing about counts at all.

Seven sites, fewer than seven edits: 1+2 are one sentence, and 5+6 are one sentence. `AGENTS.md:53`
("these **two** validate") is handled by Task 6's own bullet list above and is not repeated here.
`ai-docs/context.md:70` ("Test | structural checks — see `AGENTS.md § Build & Test`") states **no count**
and is deliberately excluded. Neither README section carries a fence with an upgrade command, so the
deny-list stays quiet across all of this.

**Machine-checked, not remembered — and the check ENUMERATES rather than expecting silence.** See the
AC8 propagation row in § Test Design. Its pass condition is "seven lines print, and every printed count
is the post-change count", so an empty result is a **failure** (the probe broke) rather than a pass. A
propagation list that is only prose is exactly how the Spec-Amendment sync group pointed its last member
at a path that resolves in no project — but an empty-output guard policing it is how *this* design got it
wrong twice, which is why the remedy is an enumeration.

### Task 7 — bump and gate run

**Step 0, before anything else — make the new files visible to the gates:**

```bash
git add -N scripts/check-readme-update.sh scripts/test-check-readme-update.sh scripts/test-upgrade-smoke.sh
```

**This is not hygiene, it is the difference between the gate running and the gate lying.** Both AC9's and
AC10's gates enumerate from the **git index**, not from the filesystem, so a new-but-untracked script is
invisible to them. Measured in this working tree at amendment time, with a deliberately unparseable
`scripts/zz-broken.sh`:

| | `git ls-files '*.sh' \| wc -l` | `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` | `bash scripts/check-release.sh` |
|---|---|---|---|
| untracked | **24** | silent, rc 0 — the broken file is never parsed | `no shipped content changed -- no bump needed`, rc **0** |
| after `git add -N` | **25** | `scripts/zz-broken.sh: line 2: syntax error near unexpected token 'then'` | `REFUSED`, rc **1** |

**This is a recorded recurrence, not a hypothetical.** `ai-docs/learnings/JeriC4o-GH-29-harness-feedback-channel.md:57–68`
logs the identical failure on the immediately preceding ticket — "with two new scripts created and not yet
added, the gate covered 22 files and silently skipped exactly the two it most needed to check" — and its
rule is binding here: *run `git add -N <new paths>` before treating any `git ls-files`-driven gate as
having covered the change, and check the file COUNT the gate processed, not just its exit status.*

So Task 7 records the count, not merely the exit status: `git ls-files '*.sh' | wc -l` must read **27**
(24 today + the three new scripts). A run reporting 24 has not seen this task's work, whatever its exit
status says. A design whose entire subject is "green drawn from the one configuration where the check
cannot fail" must not ship one of its own.

Then `.claude-plugin/plugin.json` `0.1.18` → `0.1.19`. Verified that `check-release.sh` currently reports
"no shipped content changed" on this branch and that it returns **rc 1** the moment a file under
`scripts/` is touched *and staged* without a bump — so this gate can fail, and will, until the bump lands.

AC11 is a delivery-time action, not an edit: propose the follow-up ticket *"Surface installed-vs-latest
version drift at session start"* to the user, with its one-line rationale, and do **not** create it.

## Risks

- **R1 — AC4 satisfied vacuously.** A fragment-only `[§ Update](#update)` is skipped by
  `check-references.sh:121`, so the "link resolves" clause would be trivially true. *Mitigation:* the
  cross-link is file-qualified `README.md#update`; both directions measured (§ Approach).
- **R2 — the deny-list degenerates into a no-op** after a future README edit moves the fences around.
  *Mitigation:* D3 is a positive requirement, and Task 4's mutation legs regenerate their input from the
  live README every run, so a checker that stopped seeing the file fails rather than passes.
- **R3 — the upgrade smoke green in a configuration where it cannot fail** — the exact shape this ticket
  is about, one level out. *Mitigation:* step 7's negative control (the `install` short-circuit) and the
  proven RUN C leg, where a README documenting `install` turns the gate red.
- **R4 — empty extraction reads as success.** If § Update's fence is renamed, reworded, or the section
  heading changes, the `awk` extraction returns nothing. *Mitigation:* explicit `FAIL and stop` on an
  empty block; measured (RUN B).
- **R5 — the temp copy comes back empty** (no `git`, a non-repo `$ROOT`, a broken `xargs`), producing a
  cascade of misleading failures. *Mitigation:* the step-4 `plugin.json` guard, exit 2.
- **R6 — the cache keeps the old version**, so "the lowered directory is gone" is a false assertion.
  *Mitigation:* assert presence of the raised directory only; measured (`0.0.1 0.0.2` both present).
- **R7 — running text lifted from a file.** *Mitigation:* character-class guard, no `eval`, word-split
  invocation; measured against an injected `&& rm -rf /tmp/x`.
- **R8 — `marketplace update` necessity for a remote marketplace is unverified.** *Mitigation:* the
  README words it as "refreshes this machine's local copy of the marketplace catalog", which is true and
  measured, rather than "required"; the step is measured harmless when already current.
- **R9 — AGENTS.md renumbering breaks a citation.** *Mitigation:* check 4 and the folded slot 3 are left
  alone; a repo-wide grep for `check N` / `gate N` confirmed the only back-reference is line 21's "see
  check 4".
- **R10 — `test-install-smoke.sh` and `test-upgrade-smoke.sh` both add a marketplace named
  `agent-harness`.** They use separate `$CLAUDE_CONFIG_DIR` sandboxes and never run concurrently in the
  documented sequence; neither touches the caller's real config. Measured: the real
  `~/.claude` config was untouched across every prototype run.
- **R12 — an index-driven gate cannot see the files this task creates.** `git ls-files`-driven lint and
  `check-release.sh` both enumerate from the index, so all three new scripts are invisible until staged —
  measured (Task 7), and already logged as a live failure on the preceding ticket
  (`ai-docs/learnings/JeriC4o-GH-29-harness-feedback-channel.md:57–68`). *Mitigation:* Task 7 step 0's
  `git add -N`, plus AC9's and AC10's rows making the processed **file count** part of the pass
  condition rather than the exit status alone. **Caveat: `27` is a one-shot figure**, valid only for the
  three scripts this design specifies. If implementation adds a fourth `.sh` — a helper, a fixture
  generator — the expected count moves with it. Update the AC10 row deliberately and say why; do not
  quietly edit the number to match whatever the run printed, which would convert the one assertion that
  makes this gate honest back into a tautology.
- **R13 — a count-stating sentence left behind.** **Seven** sites state the gate counts (§ Task 6); the
  first draft of this design found two of them, the second four. *Mitigation:* the AC8 **enumerate-and-
  read** leg — the probe must print **seven lines**, every printed count must read *five* structural /
  *three* delivery, and the stale-count grep must read **0**. **An empty result is a FAILURE, not a
  pass.** Do not rebuild the round-2 guard (a grep required to come back empty) from this entry; § The
  recurring failure is why.
- **R11 — arm B's runtime.** ~20 s and a `claude` CLI. It is a *delivery* gate, run before a PR, not on
  every commit; arm A carries the always-run duty.

## Test Design

This repo has no compiler and no `%TEST_CMD%`; its suites are shell scripts run directly. Two new suites,
both following `scripts/test-check-references.sh` — `ok`/`bad`/`has`/`hasnt`/`check` helpers, a
`mktemp -d` fixture with `trap` cleanup, a planted defect for every class, and this repository as the
final control.

**`scripts/test-check-readme-update.sh`** — see § Task 4. Entry point: `check-readme-update.sh --root
<dir>`. Fixtures: a frozen heredoc of today's § Update / § Releasing, plus four mutations generated from
the live `README.md` at run time. Scenarios: each finding class fires on its own defect; the § Install
exemption holds and is asserted positively; rc 2 on all three usage errors.

**`scripts/test-upgrade-smoke.sh`** *is* the test — it has no separate suite, in the same way
`test-install-smoke.sh` has none. Its own negative control is built in (step 7). Fixtures: a temp copy of
the working tree with a `jq`-rewritten version; entry point: the `claude` CLI against a throwaway
`$CLAUDE_CONFIG_DIR`.

Every command below was executed while writing this design — once as written against the corrected
README, and once against input that must trip it. The "trips on" column is the measured failing input, so
none of these is an unproven gate.

| AC | verified by | expected | trips on |
|---|---|---|---|
| **AC1** | ``awk '/^## /{s=substr($0,4)} /^```/{f=!f;next} f&&/plugin[ \t]+update/{print s}' README.md \| sort -u`` | exactly `Update` | today's README → **empty output** |
| **AC2** | `awk '/^## /{c=(substr($0,4)=="Update")} c' README.md \| tr '\n' ' ' \| grep -c 'already installed'` and the same pipe with `grep -c 'refreshes catalog metadata and nothing else'` | `1` and `1` | today's README → `0` and `0` |
| **AC3** | **the § Update `awk` WITHOUT the `tr`** — `awk '/^## /{c=(substr($0,4)=="Update")} c' README.md` piped separately into `grep -c -- '--resume'`, `grep -ci 'new\*\* session\|\*new\* session'`, `grep -c 'project profile'` | `1`, `2`, `2` | today's README → `0`, `0`, `1` |
| **AC4** | `grep -c '^## Releasing$' README.md`; ``awk -v s=Releasing '/^## /{c=(substr($0,4)==s)} c&&/^```/' README.md \| wc -l``; the § Releasing pipe with `grep -c 'README\.md#update'`; `bash scripts/check-references.sh` | `1`; `0`; `1`; rc `0` | today's README → `1`, **`2`**, `0`. And `check-references.sh` measured rc **1** with `blocker\|L2\|README.md:266: no heading in README.md slugifies to #updatez` when the anchor is broken — the proof it is not vacuous |
| **AC5** | ``awk '/^## /{s=substr($0,4)} /^```/{f=!f;next} f&&/plugin[ \t]+install/{print s}' README.md \| sort -u``; `bash scripts/check-readme-update.sh` | exactly `Install`; rc `0` | today's README → `Install` **and** `Releasing`; checker rc `1` with D1 at `Releasing:243` |
| **AC6** | `bash scripts/test-check-readme-update.sh` | `0 failed` | measured directly on the checker: today's README → rc 1 (D2/D1/D2/D3); each of the four mutations → rc 1 with its own class; unmutated → rc 0 |
| **AC7** | `bash scripts/test-upgrade-smoke.sh`; then `env PATH=/usr/bin:/bin bash scripts/test-upgrade-smoke.sh; echo $?` | `0 failed`, rc `0`; then `2`. (**Not** a pinned pass count — see § Task 5) | § Update restored to today's wording → rc 1, `no runnable claude command`; § Update documenting `install` → rc 1, `cache carries 0.0.2 (has: 0.0.1)` |
| **AC8** | `grep -n 'run all five' AGENTS.md`; `grep -cE '^[5-8]\. ' AGENTS.md`; `grep -c 'check-readme-update' AGENTS.md`; `grep -c 'test-upgrade-smoke' AGENTS.md`; `grep -n 'these three validate' AGENTS.md` | one hit; `4`; `2` (check 5 + check 4's suite list); `1`; one hit | before Task 6 → `grep 'run all five'` empty, `grep -cE '^[5-8]\. '` = `2`, both script greps `0` |
| **AC8** (propagation leg — the seven count-stating sites) | an **enumerate-and-read** probe, *not* an empty-output one: `for f in README.md AGENTS.md ai-docs/context.md; do tr '\n' ' ' < "$f" \| grep -oE '\b((one\|two\|three\|four\|five\|[0-9]+) +(structural\|delivery)\|(structural\|delivery) +(one\|two\|three\|four\|five\|[0-9]+)\b)[a-z ]*' \| sed "s\|^\|$f: \|"; done`; then `bash scripts/check-references.sh` | **two legs, both non-empty by construction.** (a) the probe prints **exactly 7 lines**; (b) `<probe> \| grep -cE '(four\|two) +(structural\|delivery)\|(structural\|delivery) +(four\|two)'` reads **`0`**. Then rc `0` from `check-references.sh`. **An empty probe result is a FAILURE** — it means the probe broke, not that the tree is clean | measured on the live un-propagated tree: 7 lines / stale-count **7**, printing `four structural checks`, `two delivery gates` (×2), `four structural checks`, `four structural ones over the repo`, `two delivery gates`, `structural four as a script is an open task`. On a fully-propagated tree: 7 lines / stale-count **0**. Reverting any single site: 7 lines / stale-count **1** — measured on `ai-docs/context.md:89`, the reversed-order one that defeated round 2 |
| **AC9** | **After Task 7 step 0's `git add -N`**: `bash scripts/check-release.sh` | rc `0`, prints `version 0.1.18 -> 0.1.19` | measured two ways: touching a tracked `scripts/*.sh` with no bump → rc **1**, `REFUSED -- shipped content changed but the version is still 0.1.18`; and a **new untracked** `scripts/*.sh` → rc **0**, `no shipped content changed -- no bump needed`, which is why step 0 is a precondition of this row rather than a nicety |
| **AC10** | **After Task 7 step 0's `git add -N`**: first `git ls-files '*.sh' \| wc -l`, then `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json`; `bash scripts/check-references.sh`; `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n`; then every suite named in `AGENTS.md` § Build & Test check 4, plus the three delivery gates | **count reads `27`** (24 → 27), *then* all rc `0` / `0 failed` | measured: an unparseable **untracked** `scripts/*.sh` leaves the count at 24 and the lint silent at rc 0; `git add -N` takes it to 25 and the syntax error appears. `check-references.sh` measured able to return rc 1 (AC4 row); `check-release.sh` able to return rc 1 (AC9 row); both new suites able to return rc 1 (AC6, AC7 rows) |
| **AC11** | not a command — at delivery, state to the user: *"Surface installed-vs-latest version drift at session start"*, rationale: a corrected procedure only helps a reader who re-reads it, and the measured failure was five bumps of silent drift. Do **not** create the issue. | the proposal appears in the delivery message | — |

**Why AC2's pipe keeps the `tr` and AC3's must not.** `tr '\n' ' '` collapses § Update to a single line,
so `grep -c` over it can only ever return 0 or 1. AC2 needs that collapse — "refreshes catalog metadata
and nothing else" spans a line break in the drafted text, and without the `tr` its count is `0`, a false
red. AC3 counts *occurrences* and needs the lines intact: measured, with the `tr` → `1, 1, 1`; without →
`1, 2, 2`. Reusing AC2's pipe for AC3, as an earlier draft did, made AC3's stated `1, 2, 2` unreachable.

### Sequencing note for Step 8

Tasks 3 and 5 are written **after** Tasks 1–2, so both gates are green on first run. If either is written
first it will be red against the uncorrected README — which is correct behaviour, not a defect, but it
makes "is this red for the right reason?" an extra judgement call in the middle of the group.

## Open questions

None blocking. The spec's five design-resolvable questions are resolved in § Approach with reasons; every
claim they rest on was measured this session. Two items are recorded but deliberately not acted on:

- **Same-file `#anchor` links are unchecked repo-wide.** `check-references.sh:121` skips them, so every
  intra-document anchor in this repository is unverified — not just § Releasing's. This design works
  around it with a file-qualified link. Widening `check-references.sh` to resolve same-file fragments is a
  real gap and a plausible follow-up, but it is outside GH-43's scope and would change a gate the whole
  repo depends on.
- **Whether `marketplace update` is required before `plugin update` for a remote marketplace** — see
  § Approach, "The one claim this design does NOT verify". No decision here rests on it.
