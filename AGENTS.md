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
| `%TEST_CMD%` | Run a module's tests | `bash scripts/run-checks.sh` — the whole list below in one call. It takes no module path: a `<module-path>` argument is accepted, **ignored, and reported as ignored**, because this gate list is undivided by design |
| `%FORMAT_CMD%` | Auto-format changed files | n/a |
| `%LINT_CMD%` | Lint as the gate | `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n` and `jq -e .` on every manifest — the `xargs` form is load-bearing, see check 4. `run-checks.sh` runs both as its `shell-syntax` and `manifests` members |
| `<module-path>` | How a module is addressed | a top-level dir: `skills/`, `agents/`, `docs/`, `rules/`, `hooks/` |

**Structural checks that stand in for a test suite** — run all six before any commit that touches
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
   `hooks/lib/test-harness-managed.sh`, `hooks/lib/test-loop-index.sh`,
   `hooks/lib/test-loop-agent-mark.sh`, `hooks/lib/test-ledger-write.sh`,
   `hooks/lib/test-loop-verdict.sh`, `hooks/lib/test-skill-gate.sh`,
   `skills/harness-init/scripts/test-scaffold.sh`,
   `skills/report-defect/scripts/test-file-report.sh`,
   `scripts/test-check-propagation-arms.sh`, `scripts/test-hook-behaviour.sh`,
   `scripts/test-run-checks.sh`.
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
   1–8 in one continuous sequence, so a sixth structural check collides with the delivery gate already
   numbered 6; item 3's `(folded into 2)` is the precedent for a non-sequential entry here, and
   renumbering would break `AGENTS.md`'s own "invisible to gate 6" reference below.

**Delivery gates** — the checks above validate this repository's CONTENTS; these three validate that the
contents reach a consumer. The six structural checks cannot see delivery by construction: the first two
gates exist because a bug got past every check there was at the time, the third because nothing above it
walks an upgrade against a *pre-existing* install:

6. `bash scripts/test-install-smoke.sh` — installs the working tree as a plugin in a throwaway
   `$CLAUDE_CONFIG_DIR` and requires `✔ enabled` plus a full component inventory. Catches "installs but
   refuses to load". Requires the `claude` CLI; **exits 2 when it cannot run, which is not a pass.**
7. `bash scripts/check-release.sh` — refuses a branch that changed shipped content without bumping
   `.claude-plugin/plugin.json`. Catches "merged but never delivered", which a sandbox install cannot see
   by construction. Run it before opening a PR.
8. `bash scripts/test-upgrade-smoke.sh` — extracts `README.md`'s own documented update commands and runs
   them against a deliberately lowered install, then requires the installed payload to have moved.
   Catches "the documented procedure reports success and upgrades nothing" — invisible to gate 6, which
   installs into an EMPTY sandbox where the short-circuit that defines the failure cannot fire. Requires
   the `claude` CLI; **exits 2 when it cannot run, which is not a pass.**

`shellcheck` is **recommended but not required**, and deliberately not named as the gate: it is not
installed on every machine that edits this repo, and a gate that cannot run is worse than one that is
honestly absent. Run it when you have it.

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
plus POSIX shell; no compiled sources.

## Project-specific conventions

- **Two surfaces, two audiences.** A file under `docs/`, `skills/`, `agents/`, `rules/` is **method** —
  it must hold in every project, so it may not name a language, a build tool, a domain entity, or a
  ticket prefix. A file under `ai-docs/` or `templates/project/` is **profile** — project facts live
  there. A method file that acquires a project fact is a `major` finding.
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
- **Any PR touching plugin-loaded content bumps `.claude-plugin/plugin.json`'s patch version.** The
  install cache is keyed by version, so an unbumped fix silently never reaches an installed copy. See
  [`README.md` § Releasing](README.md#releasing).
