# Agent Rules — agent-harness (profile)

> **This repo is the harness itself**, so it plays two roles at once: it *ships* the method half
> (`docs/agents-method.md`, `skills/`, `agents/`, `rules/`, `hooks/`) and it *consumes* it while being
> developed. The method file is the authority on how to work here — read it first:
> [`docs/agents-method.md`](docs/agents-method.md). In an installed project the same file is at
> `${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md`.
>
> Everything below is this repo's own profile — the half a consuming project supplies for itself from
> [`templates/project/AGENTS.md`](templates/project/AGENTS.md).

## Build & Test

This repo ships instruction files and shell scripts; it has no compiler.

| Placeholder | Meaning | This project |
|---|---|---|
| `%BUILD_CMD%` | Compile the changed module | n/a — no build step |
| `%TEST_CMD%` | Run the checks a touched path selects | `bash scripts/run-checks.sh --only <member>[,<member>…]` — members named as `--list` prints them; the selection comes from § Touched-scope selection below. A `<module-path>` argument is accepted, **ignored, and reported as ignored**: the selection is `--only`'s alone |
| `%FULL_CHECK_CMD%` | Run the full check list, once, after review approves | `bash scripts/run-checks.sh` — the whole list below in one call |
| `%FORMAT_CMD%` | Auto-format changed files | n/a |
| `%LINT_CMD%` | Lint as the gate | `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` and `jq -e .` on every manifest — the `xargs` form is load-bearing, see check 4. `run-checks.sh` runs both as its `shell-syntax` and `manifests` members |
| `<module-path>` | How a module is addressed | a top-level dir: `skills/`, `agents/`, `docs/`, `rules/`, `hooks/` |

**Structural checks that stand in for a test suite** — run all nine before any commit that touches
instruction files.

**`bash scripts/run-checks.sh` runs every one of them in a single call**, reporting a verdict per member
and exiting 0 only when all passed (1 on any failure or list drift, 2 when it could not run — which is
not a pass). Prefer it: the no-masking rule forbids piping a gate, so running the list by hand costs one
bare tool call per member, and at the context a review round actually reaches, the re-read term alone is
roughly $0.20 a call. A checked-in script is where that rule explicitly permits the chain. The
enumeration below stays, for two reasons: it carries the rationale for each check's exact spelling, and
it is now machine-checked rather than decorative. The runner **derives** its suite list from the tree and
asserts that derived list matches item 4's, in both directions; it asserts that every `bash scripts/*.sh`
this section names between the **Structural checks** heading and the **Delivery gates** heading is one of
its own members, in both directions; and it requires exactly one verdict per member, because a member
wired to another member's work leaves both totals unchanged. Running members by hand remains correct; it
is the same commands.

> **The shape of this section is load-bearing.** Those two bold headings are the span the runner parses,
> and a structural check is recognised by being spelled `` `bash scripts/<name>.sh` `` inside it. Moving a
> gate across either heading, or respelling its invocation, changes what the `gate-inventory` member
> computes — re-run it after editing here and read which members it names, not only its exit status. The
> runner itself appears in that span as the way to RUN the list and is excluded from the comparison.

1. `jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json` — manifests parse.
2. `bash scripts/check-references.sh` — markdown links and `#anchor`s resolve; every
   `${CLAUDE_PLUGIN_ROOT}` path exists here; every bare `ai-docs/…` in a method file names a
   **documented** project-data root rather than a method file written in project spelling; and every
   `AGENTS.md § …` reference names a section a consuming project's `AGENTS.md` actually has; and the
   scaffolded copy of the learning-log contract is present and byte-identical to the live one — absence
   is checked separately from divergence, because a missing copy ships no contract at all and a guard
   that skipped it would pass silently in the worse case. That `AGENTS.md § …` class is why the script
   exists: the Propagation Rule's Spec-Amendment sync group pointed its final
   member at `ai-docs/workflow.md`, so that member was never once updated by a sweep, and neither
   hand-run check above could see it.
3. (folded into 2)
4. `bash -n` on every `*.sh` — **as `git ls-files -z '*.sh' | xargs -0 -n1 bash -n`, and not otherwise.**
   The three natural spellings all report success on a file that does not parse, verified against a
   deliberately broken fixture: `-exec bash -n {} +` batches, so only the first file is parsed and the
   rest become positional parameters (rc 0, no output at all — the quietest possible false green);
   `-exec … \;` prints the error but `find` still exits 0; and a `for` loop exits with the LAST
   iteration's status, so an earlier failure is erased. Only the `xargs -0 -n1` form propagates a
   failure. **`git ls-files` lists TRACKED files only.** On a task that CREATES scripts, run
   `git add -N <new paths>` first and check the file COUNT the gate processed, not only its exit
   status — a gate that silently narrows its own input set is the quietest false green there is.
   Then every test suite green:
   `scripts/test-plugin-manifest.sh`, `scripts/test-promotion.sh`, `scripts/test-audit-project.sh`,
   `scripts/test-trace-tokens.sh`, `scripts/test-session-events.sh`,
   `scripts/test-backlog-metrics.sh`, `scripts/test-fold.sh`, `scripts/test-check-references.sh`,
   `scripts/test-check-readme-update.sh`, `scripts/test-loop-metrics.sh`,
   `scripts/test-bin-of.sh`, `scripts/test-loop-grid.sh`, `scripts/test-loop-corpus.sh`,
   `scripts/test-tree-digest.sh`, `scripts/test-review-ledger.sh`, `scripts/test-human-findings.sh`,
   `hooks/lib/test-harness-managed.sh`, `hooks/lib/test-loop-index.sh`,
   `hooks/lib/test-loop-agent-mark.sh`, `hooks/lib/test-ledger-write.sh`,
   `hooks/lib/test-loop-verdict.sh`, `hooks/lib/test-skill-gate.sh`,
   `hooks/lib/test-plan-invariants-guard.sh`, `hooks/lib/test-gate-record.sh`,
   `skills/harness-init/scripts/test-scaffold.sh`,
   `skills/report-defect/scripts/test-file-report.sh`,
   `skills/task/scripts/test-check-fix-plan.sh`,
   `scripts/test-check-plan-invariants.sh`, `scripts/test-check-propagation-arms.sh`,
   `scripts/test-check-redline.sh`, `scripts/test-check-release.sh`,
   `scripts/test-check-plan-convergence.sh`,
   `scripts/test-hook-behaviour.sh`,
   `scripts/test-run-checks.sh`, `scripts/test-check-method-purity.sh`,
   `scripts/test-check-instruction-size.sh`.
   **Both hazards in this item are mechanised by `scripts/run-checks.sh`**, which reports the processed
   file COUNT beside the syntax verdict and reddens a separate `untracked-shell` member on any `*.sh` the
   index cannot see — but only when it runs, so a hand-run still owes both reads.
   **`scripts/test-loop-corpus.sh` takes about four minutes** — 1728 real call rows replayed at 18
   window widths across two legs — and it deliberately ships no flag to narrow that, because an
   opt-out is the "gate that silently narrows its own input set" hazard one paragraph up. Budget for
   it; do not skip it.
5. `bash scripts/check-readme-update.sh` — refuses a `README.md` whose update surface names a verb that
   cannot upgrade: a fenced `plugin install` outside the Install section, a fenced `marketplace update`
   with no `plugin update` beside it, or an Update section carrying no upgrade verb at all. Needs no
   `claude` CLI, so it runs wherever the checks above it run.
5a. `bash scripts/check-propagation-arms.sh` — DERIVES the propagation reminder's path classes from the
   Propagation Rule table in `docs/propagation.md` and asserts the `case` arms in `hooks/hooks.json`
   agree: every derived class has an arm that fires on an absolute representative, every control stays
   silent, and no path the pre-fix arms matched is silent under the current set. Catches "a sync group
   was added to the table and the reminder never learned about it" — drift between a list and the table
   beside it, which no link check or syntax check can see. **Numbered `5a`, not `6`:** this list runs
   1–8 in one continuous sequence, so ANY structural check numbered in that sequence collides with the
   delivery gate already numbered 6; item 3's `(folded into 2)` is the precedent for a non-sequential
   entry here, and renumbering would break `AGENTS.md`'s own "invisible to gate 6" reference below. The
   same reasoning numbers the next one `5b`.
5b. `bash scripts/check-plan-invariants.sh` — three legs over the base principles of a spec and a design:
   each pinned sentence present and unchanged, with an ABSENCE reported distinctly from a WORDING
   difference; the required-element set derived from three loci and cross-checked against the
   enumeration on `docs/plan-invariants.md`, in both directions, so neither a widened template nor a
   widened enumeration moves on its own; and the live coverage of the edit-time refusal against that
   page's protected-page table, also in both directions. Exits
   `0 clean / 1 findings / 2 cannot run` — **a cannot-run is not a pass**, and an unreadable required
   input, a template that moved, an empty extraction, an unreadable corpus file and an untracked payload
   all take that branch rather than reading as agreement. Its verdict line carries the principle,
   element, surface, page, unaccounted and finding counts, followed by a roster marking each
   surface examined-clean, examined-with-findings or not-examined and naming the three excluded by design
   with their reason, so a run that silently examined fewer surfaces or fewer pages than the corpus holds
   is distinguishable from a clean one: **read those counts and that roster, not only the exit status.**
   `unaccounted` reads the other way from the four measurement figures beside it — those should be large
   and it should be zero, because a non-zero value names tracked files on no examined surface and
   in no named exclusion, about which the report then says nothing at all. It needs `python3` as its
   scanning tool and says so when it is absent — the host `grep` is not a substitute, having been
   measured answering `0` to a pattern it refused on a complexity limit.
   **Numbered `5b` for the reason item `5a` gives.**
5c. `bash scripts/check-method-purity.sh` — enforces the method/profile boundary in § Project-specific
   conventions. Two legs: every tracked `*.md` under `docs/`, `skills/`, `agents/`, `rules/` names no
   language, framework, build or doc tool, and uses no one language's syntax as its example; and no
   tracked text file anywhere carries a known identifier from another real codebase. The second leg's
   stems are stored hashed, so the gate does not itself carry the material it refuses. A new stem is
   added as its length and sha256 prefix. Exits `0 clean / 1 findings / 2 cannot run`, needs `python3`.
   **Numbered `5c` for the reason item `5a` gives.**
5d. `bash scripts/check-instruction-size.sh` — the size AXIOM in `docs/agents-method.md` § Build & Test,
   for the class it caps: every file that loads whole at agent start, here and in `templates/project/`.
   Red at the 35,000-character early warning rather than at the 40,000 cap, so a task cannot close
   without leaving the next one room to add a rule. Counts characters, not bytes. A page reached only by
   link is outside the class by design. Exits `0 clean / 1 findings / 2 cannot run`, needs `python3`.
   **Numbered `5d` for the reason item `5a` gives.**

**Delivery gates** — the checks above validate this repository's CONTENTS; these three validate that the
contents reach a consumer. The nine structural checks cannot see delivery by construction: the first two
gates exist because a bug got past every check there was at the time, the third because nothing above it
walks an upgrade against a *pre-existing* install:

6. `bash scripts/test-install-smoke.sh` — installs the working tree as a plugin in a throwaway
   `$CLAUDE_CONFIG_DIR` and requires `✔ enabled` plus a full component inventory. Catches "installs but
   refuses to load". Requires the `claude` CLI; **exits 2 when it cannot run, which is not a pass.**
7. `bash scripts/check-release.sh` — refuses a branch that changed shipped content without bumping
   `.claude-plugin/plugin.json`. Catches "merged but never delivered", which a sandbox install cannot see
   by construction. Run it before opening a PR. When its base is a remote-tracking ref — the default
   `origin/main` is one — it **needs the remote reachable**: a base that is not the remote's current tip
   reads the default branch's own changes and bump as this branch's, so a stale or unreachable base
   **exits 2 naming the fetch, which is not a pass.** A commit id or a local branch as the base is read as
   given, with no remote contact.
8. `bash scripts/test-upgrade-smoke.sh` — extracts `README.md`'s own documented update commands and runs
   them against a deliberately lowered install, then requires the installed payload to have moved.
   Catches "the documented procedure reports success and upgrades nothing" — invisible to gate 6, which
   installs into an EMPTY sandbox where the short-circuit that defines the failure cannot fire. Requires
   the `claude` CLI; **exits 2 when it cannot run, which is not a pass.**

`shellcheck` is **recommended but not required**, and deliberately not named as the gate: it is not
installed on every machine that edits this repo, and a gate that cannot run is worse than one that is
honestly absent. Run it when you have it.

### Touched-scope selection

Inside a loop only the members a touched path selects run, as `%TEST_CMD%`; the full list runs once after
review approves, as `%FULL_CHECK_CMD%` — [`docs/check-scope.md`](docs/check-scope.md). This subsection sits
after the delivery gates on purpose: it names members, and the span the `gate-inventory` member parses ends
at that heading.

**Path rule:**

- A touched `<dir>/<name>.sh`, or one of its payload siblings, selects `<dir>/test-<name>.sh` where that
  exists.
- A touched suite selects itself.
- Any touched `*.sh` selects `shell-syntax` and `untracked-shell`.
- A touched manifest selects `manifests`.
- Any touched `*.md` selects `references`.

**Mapping** — derived by reading which files each member opens:

| Touched path | Selects |
|---|---|
| `hooks/hooks.json` | `scripts/test-hook-behaviour.sh`, `propagation-arms`, `plan-invariants`, `scripts/test-plugin-manifest.sh` |
| `hooks/hooks.json` | `hooks/lib/test-harness-managed.sh`, `hooks/lib/test-loop-index.sh`, `hooks/lib/test-loop-verdict.sh` |
| `hooks/hooks.json` | `hooks/lib/test-loop-agent-mark.sh`, `hooks/lib/test-skill-gate.sh`, `hooks/lib/test-plan-invariants-guard.sh` |
| `docs/propagation.md` | `propagation-arms` |
| `README.md` | `readme-update` |
| `docs/plan-invariants.md`, any instruction file on the surfaces it examines, `hooks/lib/plan-invariants-guard.sh` | `plan-invariants` |
| `AGENTS.md` § Build & Test, or a `test-*.sh` added or removed | `gate-inventory`, `scripts/test-run-checks.sh` |
| `hooks/lib/loop-*`, `scripts/bin-of.jq`, `ai-docs/fixtures/loop-corpus/` | `scripts/test-loop-grid.sh`, `scripts/test-loop-corpus.sh` |
| `scripts/tree-digest.sh` | `scripts/test-review-ledger.sh`, `hooks/lib/test-gate-record.sh` |
| `hooks/lib/gate-pattern.sh` | `hooks/lib/test-gate-record.sh`, `scripts/test-hook-behaviour.sh`, `hooks/lib/test-harness-managed.sh` |
| any tracked text file — the foreign-identifier leg reads the whole tree | `method-purity` |
| `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, `ai-docs/context.md`, `docs/agents-method.md`, `agents/*.md`, `skills/*/SKILL.md`, `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`, their `templates/project/` copies | `instruction-size` |
| `templates/project/**` | `skills/harness-init/scripts/test-scaffold.sh`, `scripts/test-audit-project.sh` |

**Selection flag:** `--only`

## VCS

| Setting | Value |
|---|---|
| Default branch | `main` |
| Branch naming | `<TICKET-KEY>-<slug>`, or `chore/<slug>` for work with no issue |
| Ticket key format | `GH-<issue number>` |
| Review surface | GitHub PR via `gh` |

**GitHub Issues have no key prefix** — an issue is a bare `#N`, and PRs share the same counter, so the
numbering is contiguous across both. `GH-` is a *local* prefix this repo adds so an issue number can ride
in a branch name and a spec header, where a bare `#` does not belong. It maps one-to-one:

| Surface | Form |
|---|---|
| The issue itself | `#10` |
| Branch | `GH-10-<slug>` |
| Spec header | `**Tracked in:** GH-10` |
| PR title | `GH-10: <conventional-commits header>` |
| Any `gh` command | `gh issue view 10` — **strip the prefix**; `gh` knows nothing about `GH-` |

> **Carve-out — `Closes #N` is permitted in a PR body**, and is the one trailer this repo allows despite
> the summary-only rule. It is an ACTION, not a reference: GitHub closes the issue when the PR merges.
> That is the intended behaviour here, and the softer cousin of the hazard
> [`docs/workflow.md` § PR title + body shape](${CLAUDE_PLUGIN_ROOT}/docs/workflow.md#pr-title--body-shape)
> warns about — write it only for the issue the PR actually resolves, never for one it merely mentions.

## Permissions — project specifics

- **DENY:** editing `~/.claude/plugins/**` from this repo. An installed copy of this harness is a build
  artefact; the source of truth is this working tree.

## Language profile

See [`ai-docs/context.md`](ai-docs/context.md) § Language profile. In short: Markdown instruction files
plus POSIX shell, with eight non-shell payload files in three other languages — two `awk`, one `jq` and
five `python3`; no compiled sources. Each is a SIBLING a `.sh` entry point loads from its own directory,
never an entry point itself, so every caller still invokes a shell script. **The count in this sentence
moves whenever a payload sibling is added**, and nothing derives it — the sibling list it summarises is on
the profile page, and the two have already fallen out of step once.

## Project-specific conventions

- **Two surfaces, two audiences.** A file under `docs/`, `skills/`, `agents/`, `rules/` is **method** —
  it must hold in every project, so it may not name a language, a build tool, a domain entity, or a
  ticket prefix; check `5c` enforces the first two. A file under `ai-docs/` or `templates/project/` is
  **profile** — project facts live there. A method file that acquires a project fact is a `major` finding.
- **Paths inside method files are `${CLAUDE_PLUGIN_ROOT}`-relative; paths to project data are
  repo-relative.** `${CLAUDE_PLUGIN_ROOT}/docs/workflow.md` is method; `ai-docs/plans/…` is data and
  resolves against whichever project is open. Mixing them is the one mistake that breaks the harness for
  every consumer while still working here.
- **A skill script is invoked as `${CLAUDE_SKILL_DIR}/scripts/<name>`**, never by a repo-relative path —
  the plugin installs to a variable location.
- **`templates/project/ai-docs/learnings/README.md` is a byte-identical copy of this repo's own
  `ai-docs/learnings/README.md`, and the Fold group cannot name it.** That group lives in a method file,
  and `templates/` does not exist in a consuming project — so the obligation is recorded here instead:
  **any** edit to `ai-docs/learnings/README.md` mirrors to it. Not "whenever the fold contract
  changes" — that file is a Learning-Log group member as well, so a boundary-rule or entry-format
  change lands there just as readily, and a trigger naming only the fold is the narrower-and-still-wrong
  shape. `scripts/check-references.sh` enforces the mirror, so this is a gate rather than a hope. The
  copy is what every scaffolded project receives, so a gap there reaches consumers who cannot see the
  implementation it describes.
- **This repository's `AGENTS.md` § Build & Test and `templates/project/AGENTS.md` § Build & Test keep one
  shape** — the placeholder rows, including `%FULL_CHECK_CMD%`, and the "Touched-scope selection"
  subsection with its path rule, mapping and `**Selection flag:**` line. The method cannot name
  `templates/`, so the obligation is recorded here, as the learning-log mirror's is: an edit to either
  side's shape lands on the other in the same change. Nothing checks it mechanically.
- **Any PR touching plugin-loaded content bumps `.claude-plugin/plugin.json`'s patch version.** The
  install cache is keyed by version, so an unbumped fix silently never reaches an installed copy. See
  [`README.md` § Releasing](README.md#releasing).
- **Renaming a `## ` heading in `templates/project/ai-docs/context.md` updates the heading exclusion in
  `scripts/check-candidate.sh` in the same act.** That gate derives a promotion candidate's deny
  vocabulary from the project's own `ai-docs/context.md`, which starts life as a copy of that template,
  and subtracts a hand-written list of generic section names. Nothing derives either list from the other.
  Today most arms are inert, because a later stage of the same pipeline admits only single-word tokens —
  the live ones are `%`, `Overview`, `Registry` and `Layout`. The hazard is forward: rename a heading to
  a **single word** and it silently becomes a deny term, refusing any candidate that contains that common
  word, with no visible cause. This is recorded here rather than beside the Propagation Rule's sync
  groups for the same reason as the learning-log mirror above — the gate is a method file and
  `templates/` does not exist in a consuming project, so no method page may name the other side. The
  script carries the full rationale, including why the list is stated rather than derived.

## Register

**Dry, technical, direct. No apologies, no disclaimers, no safety warnings, no paranoia about rules, no
lectures.** Confident, to the point, and without surplus politeness.

- **Cut entirely:** apologies, self-criticism, preambles, closing pleasantries, restatements of what is
  about to be done, and any paragraph whose subject is the agent's own process. A correction is made, not
  narrated — fix it in the same sentence and move on.
- **Cut:** hedges about rules, permissions and procedure. Do not announce that a rule exists, that a gate
  binds, that something is someone else's to authorise, or that care is being taken. Where a rule actually
  blocks an action, say what is blocked and what unblocks it, in one line. Nothing else.
- **On a doubtful request:** do it, or name the error in one line. No lecture, no options table, no risk
  inventory. If it is restated, it is the user's call — do it and stop commenting.
- **Lead with the answer or the result.** State findings as facts, not as discoveries.

A concession that immediately rebuilds a narrower version of the thing conceded is not a concession, and
is the shape that provoked this rule.
