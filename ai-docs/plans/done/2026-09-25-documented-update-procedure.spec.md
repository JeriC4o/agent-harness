# Documented update procedure does not update

**Source:** ticket GH-43
**Date:** 2026-09-25
**Tracked in:** GH-43

## Problem

`README.md` documents, in two places, how a consumer moves an installed copy of this plugin to a newer
version. Neither documented procedure does that. Measured on this machine today, not reasoned:

1. **`install` is not an upgrade path.** § Releasing gives
   `claude plugin marketplace update agent-harness` followed by
   `claude plugin install harness@agent-harness --scope user`. Against an existing installation, `install`
   short-circuits and prints `✔ Plugin "harness@agent-harness" is already installed (scope: user)`. Both
   commands report success; the cache is unchanged. The CLI has a separate verb the README never
   mentions — `claude plugin update <plugin>` ("Update a plugin to the latest version (restart required
   to apply)"). Running it moved this machine from `0.1.12` to `0.1.18`.
2. **§ Update is worse, and is the section aimed at consumers.** README line 164–168 gives only
   `/plugin marketplace update agent-harness` — a marketplace-metadata refresh with no install or update
   verb at all. The ticket's Fix list names § Releasing and does not name this section.
3. **"restart the session" is ambiguous, and the failing reading is the natural one.** § Releasing closes
   with *"Then restart the session — hooks are read at start."* A resumed session (`--resume`) re-reads
   the project's instruction files — verified: a reloaded `AGENTS.md` carried edits made minutes earlier —
   but the plugin's hooks stay on the version the session originally started with. Verified functionally,
   which is the point: with `0.1.17` present in the cache and carrying a widened `gate-pipe-guard`, a
   deliberately piped gate invocation ran to completion instead of being blocked. The file was installed;
   the rule was not in force. Reading `hooks.json` would have reported "updated".

**Measured consequence:** this machine's copy sat at `0.1.12` across five version bumps. Every fix in
`0.1.13`–`0.1.17` was merged, released, and never delivered. Following the documented procedure would not
have moved it once. The cache directory listing after the repair shows `0.1.13`–`0.1.16` were never
delivered to this machine at all.

**Why neither delivery gate sees it.** Both exist for the "merged but never delivered" class and both are
blind here by construction. `scripts/test-install-smoke.sh` installs into a throwaway
`$CLAUDE_CONFIG_DIR`, where there is no prior installation — so `install` behaves correctly, and the
failure needs an *existing* install to reproduce. `scripts/check-release.sh` checks that the version was
bumped; it was, five times. The repository's own evidence for "delivery works" is drawn from the one
configuration in which the documented command cannot fail.

## Scope

1. **One canonical update procedure, written once.** The corrected procedure lives in the
   consumer-facing `## Update` section (README line 164). It uses `claude plugin update` as the upgrade
   verb and states why `install` is not it — the "already installed" success message is the trap.
2. **`## Releasing` (README line 228) cross-links to `## Update` instead of repeating it.** Its current
   two-line `marketplace update` + `install` block is replaced by a link. Rationale the user chose on:
   no duplication means the two cannot drift apart again, which is exactly how `## Update` got left
   behind while `## Releasing` at least discussed the trap. § Releasing keeps its own subject — the
   bump-in-the-same-PR rule and why the cache is version-keyed.
3. **Split "restart" into its two meanings** in the canonical procedure, and say which is needed for
   what: resuming a session re-reads the *project profile* (`AGENTS.md`, `ai-docs/`); picking up a new
   *plugin version* requires a new session.
4. **Guard, arm A — a doc deny-list, as the fast always-run gate.** A machine-checkable assertion over
   README's whole update surface that fails on a README restored to today's wording. Runs with the
   structural checks; needs no `claude` CLI.
5. **Guard, arm B — an upgrade smoke test, as the slow delivery gate**, alongside (not folded into)
   `scripts/test-install-smoke.sh`. It installs an older version, runs the documented procedure, and
   asserts the installed payload moved.
6. **Register both new gates in `AGENTS.md` § Build & Test**, and bump
   `.claude-plugin/plugin.json`'s patch version because new files under `scripts/` are plugin-loaded.

## Out of scope

- **Runtime version-drift detection** — a notice when the installed copy silently lags the marketplace.
  Different mechanism (runtime notice) from a docs/CI gate. See Deferred.
- **§ Install (README line 13–28).** Those are first-time-install commands and are correct for that
  case. They may keep `claude plugin install`.
- **Changing the release/bump policy itself.** The bump is not where delivery breaks.
- **Any change to the `claude` CLI's behaviour.** `install` short-circuiting on an existing install is
  upstream behaviour this repo documents around, not a bug to fix here.
- **Folding arm B into `scripts/test-install-smoke.sh`.** That gate's empty-sandbox premise is load-
  bearing for what it does check; the upgrade case needs a *pre-existing* install and is a separate
  script.

## Deferred

- **Runtime version-drift detection** — surface a notice when the installed plugin version lags the
  marketplace's | a corrected procedure only helps a reader who re-reads it, and the measured failure was
  five bumps of silent drift; but the mechanism is a runtime notice, unrelated to a docs fix or a CI
  gate | **yes — propose a follow-up ticket to the user at delivery time; do not create it inside this
  task.** Proposed title: *"Surface installed-vs-latest version drift at session start"*.
- #41 — the loop detector has never been shown a loop it could miss | same shape one level out (green
  drawn from the configuration in which the check cannot fail) | already ticketed, do not fold in.
- #49 — three checks that ran and could not fail | same shape two levels out | already ticketed.
- Generalising "a gate whose green comes from the one configuration where it cannot fail" into a method
  rule or a learning-log entry | belongs to the `/harness:improve` surface, not to this fix | would need
  its own ticket.

## Key decisions

| Question | Decision |
|---|---|
| Is `claude plugin update` real and does it take a scope? | Verified first-hand: `claude plugin update [options] <plugin>`, "Update a plugin to the latest version (restart required to apply)", supports `-s, --scope <scope>` accepting `user`, `project`, `local`, `managed`. |
| Does `marketplace update` alone ever move the payload? | No. Verified: it printed "Successfully updated marketplace" and left the installed payload at `0.1.12`. |
| Does a resumed session pick up a new plugin version? | No. Verified functionally (installed-but-not-in-force hook). Project instruction files *are* re-read on resume. |
| Which sections get corrected, and how? | **Both, one canonical.** Procedure written once in § Update; § Releasing cross-links. No duplication, so the two cannot drift apart again. (Round 1, Q2.) |
| Does a guard get added, and of what kind? | **Both kinds.** Deny-list as the fast always-run gate, *and* an upgrade smoke test as the slow delivery gate alongside `test-install-smoke.sh`. Neither arm is conditional. (Round 1, Q1.) |
| Is drift detection in scope? | **No.** Out of scope for GH-43; recorded in Deferred with a proposed follow-up ticket the user decides on later. (Round 1, Q3.) |
| Can the smoke test install a pinned older version by argument? | **No — verified against `--help` for both verbs.** See Technical constraints; the temp-copy route is the only one. |

## Technical constraints

These are verified facts, not preferences. They bound the design space; do not re-derive them.

- **Neither `claude plugin install` nor `claude plugin update` accepts a version pin.** Checked against
  `--help` for both. The only options are `--accept-command`, `--config` (install only), `--json`,
  `-s/--scope`, `-y/--yes`. There is no version argument. So "install an older version first" **cannot**
  be done by argument.
- **The only route to an older version is the temp-copy trick**, along the path
  `scripts/test-install-smoke.sh:59` already uses: `claude plugin marketplace add "$ROOT"` takes a
  **filesystem path**. So the upgrade smoke test must: copy the tree to a temp dir, *lower*
  `plugin.json`'s version in the copy, add that copy as a marketplace and install it, then *raise* the
  version in the copy, and only then run the documented procedure and assert the installed payload moved.
- **A gate that cannot run must not report a pass.** Any `claude`-dependent gate exits **2** (not 0, not
  1) when the CLI is unavailable, matching `scripts/test-install-smoke.sh` and the exit-2 contract
  already documented in `AGENTS.md` § Build & Test.
- **`README.md` is not plugin-loaded content, but `scripts/` is.** Per `ai-docs/context.md` the shipping
  set is `skills/ agents/ rules/ hooks/ docs/ scripts/ templates/`. A README-only change would need no
  bump; adding scripts under `scripts/` **does**, and `bash scripts/check-release.sh` will refuse this
  branch without a `.claude-plugin/plugin.json` patch bump.
- **An unregistered gate script is a check nobody invokes.** Both new gates must be named in
  `AGENTS.md` § Build & Test — the deny-list among the structural checks, the upgrade smoke among the
  delivery gates. The section's existing prose ("run all four", the numbered delivery-gate list) has to
  stay internally consistent after the additions.
- **Method/profile split.** Anything added under `docs/`, `skills/`, `agents/`, `rules/`, `hooks/` must
  hold in every project and may not name this repo, its marketplace, or its ticket prefix. The update
  procedure names `agent-harness` and `harness@agent-harness`, so it is **profile** content and belongs
  in `README.md` — not in a method file. A `scripts/` gate that greps this repo's own `README.md` is
  likewise repo-specific by construction; that is acceptable for `scripts/`, which is not a method
  surface.
- **Existing anchor dependency.** `AGENTS.md:127` links `README.md#releasing`. The § Releasing heading
  must survive verbatim, and the new § Releasing → § Update cross-link must itself resolve, because
  `bash scripts/check-references.sh` resolves markdown links and `#anchor`s.
- **Shell lint form.** Any new `*.sh` must pass `bash -n` via the mandated
  `git ls-files -z '*.sh' | xargs -0 -n1 bash -n` form.
- **Branch:** `GH-43-documented-update-procedure`, already checked out.

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | `README.md` § Update contains the canonical upgrade procedure and uses `claude plugin update` as the upgrade verb. It is the only place in the README where the upgrade command sequence appears. |
| AC2 | § Update states in prose that `claude plugin install` short-circuits on an existing installation, prints an "already installed" success message, and does **not** move the payload — and that `marketplace update` alone refreshes metadata only. |
| AC3 | § Update distinguishes the two restarts explicitly: resuming a session re-reads the project profile (`AGENTS.md`, `ai-docs/`); a **new** session is required for a new plugin version to be in force. The text says which is needed for what. |
| AC4 | § Releasing no longer contains an upgrade command block. It links to § Update instead, and that link resolves under `bash scripts/check-references.sh`. The § Releasing heading (and therefore the `README.md#releasing` anchor `AGENTS.md:127` depends on) is unchanged. |
| AC5 | No block anywhere in `README.md` tells a reader to *upgrade* an existing installation via `claude plugin install` or via `marketplace update` alone. § Install's first-time-install commands are exempt and may keep `install`. |
| AC6 | A deny-list guard runs without the `claude` CLI, scans the **whole** of `README.md` (not one named section), and exits non-zero on a README whose update surface reintroduces `install`-as-upgrade or `marketplace update`-alone. It is proven to fail against a fixture carrying today's wording, and to pass against the corrected README. |
| AC7 | An upgrade smoke test, in its own script separate from `scripts/test-install-smoke.sh`, installs a lowered-version copy of the tree into a throwaway `$CLAUDE_CONFIG_DIR`, raises the copy's version, runs the documented procedure from § Update, and asserts the installed payload moved to the raised version. It exits **2** (not 0, not 1) when `claude` is unavailable, and touches no marketplace, plugin or setting outside its sandbox. |
| AC8 | Both new gates are named in `AGENTS.md` § Build & Test — the deny-list with the structural checks, the upgrade smoke with the delivery gates — and that section's counts and numbering are internally consistent afterwards. |
| AC9 | `.claude-plugin/plugin.json`'s patch version is bumped in this PR and `bash scripts/check-release.sh` passes. |
| AC10 | `jq -e .` on the manifests, `bash scripts/check-references.sh`, `git ls-files -z '*.sh' \| xargs -0 -n1 bash -n`, and every suite named in `AGENTS.md` § Build & Test are green. |
| AC11 | A follow-up ticket for runtime version-drift detection is **proposed to the user** at delivery (title and one-line rationale), not created inside this task. |

## Open questions

Each has a defensible default the `design` subagent may take or overturn; none blocks design.

- Which argument form the README documents: `claude plugin update harness` or
  `claude plugin update harness@agent-harness`. Both appear to work; pick one and use it consistently
  across README and the upgrade smoke test. Design can verify first-hand.
- Whether `--scope user` is carried on the documented `update` command. The verb accepts `-s/--scope`;
  omitting it worked here. Note that § Install already presents scope as a deliberate choice, so the
  update procedure arguably should mirror whichever scope the reader installed with.
- Whether the documented procedure should tell the reader how to *confirm* the move landed. Caveat if
  it does: `claude plugin list` reporting the new version is **not** evidence the running session uses
  it — the session in which this was diagnosed is the proof. Design's call whether to state that.
- How the deny-list guard is packaged: a new `scripts/check-*.sh`, or an assertion added to
  `scripts/check-references.sh` / an existing suite. Design's call; AC6 constrains behaviour, not file
  layout. Note that a brand-new script and an edit to an existing one both live under `scripts/` and so
  both trigger AC9.
- Whether the upgrade smoke test asserts on the cache directory listing, on `claude plugin list` output,
  or both. AC7 says "the installed payload moved"; design picks the observable.
