---
name: report-defect
description: "Report a defect in the HARNESS ITSELF from the project you are working in. Drafts a five-section report into ai-docs/feedback/, runs it through the redaction gate, shows it to you, and — only on your explicit approval — files it as an issue against the repository the installed plugin manifest names. An idempotency hash stops the same defect being filed twice."
disable-model-invocation: true
argument-hint: "[one line naming the harness file or step at fault]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(scripts/file-report.sh:*), Bash(scripts/check-candidate.sh:*), Bash(git branch:*), Bash(git status:*), Bash(ls:*), Bash(jq:*)
---

The route home for a defect **in the harness**, from a project that is not the harness. `/harness:bugfix`
fixes a bug in *your* code; `/harness:inspect` finds harness defects but cannot send them anywhere. This
sends one.

> Near-stateless: no `.progress.md` discipline applies; re-entry is re-invoking the skill.

> **Branch gate — first action.** `git branch --show-current`. This skill writes tracked project files,
> so AXIOM 1 binds. If it is the default branch, branch before Step 2.

**Nothing crosses the boundary silently.** The gate is a file selector, not a judgement call, and no
issue is filed without the user approving the exact text they were shown.

## Step 1: Learn the vocabulary BEFORE drafting

Read, in this order, and keep the terms in front of you while you write:

- the project directory name and the ticket-key prefix from `AGENTS.md`;
- every `## Entity` heading in `ai-docs/context.md`.

This is not preparation for a later check — it is the mitigation that keeps refusal rare. The gate
derives its deny vocabulary from exactly these sources, so a report drafted generically from the start
passes on the first run, and one drafted from a session transcript almost never does.

## Step 2: Draft the report

Write it to `ai-docs/feedback/<YYYY-MM-DD>-<slug>.md`, creating the directory if it is absent. The
file is committed with the project: it is the evidence the issue has a source.

````markdown
---
harness_version: <the installed version>
hash: pending
---

**Symptom:** What the harness did, in one or two sentences.

**Repro:** The sequence that produces it, in harness terms — the command, the step, the gate.

**Expected:** What it should have done instead.

**Surface:** <a path inside the harness tree, optionally with :line>

**Evidence:** What was observed — output shape, exit code, what ran and what did not.
````

Read the version rather than typing one:

```bash
jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
```

### Drafting rules — every one of these exists because the gate enforces it

1. **Write generically from the start.** Name harness files, harness steps and harness commands. Never
   a repository name, a ticket key, a domain entity, a service or a directory of the project you are
   working in. Rewriting afterwards to get past the gate is forbidden (see FORBIDDEN below).
2. **`Surface` names the harness file at fault, and nothing else.** It is the one field that carries a
   path, and it must resolve inside the installed harness tree. A project file that was merely
   *affected* is described **in words** in `Evidence` — never as a path.
3. **When the defect is that something is missing**, name the parent directory in `Surface` and say so
   in `Symptom`. A directory satisfies the gate's existence check; a path to a file that was never
   created does not.
4. **Never name the report's own path inside the report.** It lives in the project, so the gate refuses
   it, and the refusal will look mystifying.
5. **Never paste a URL.** Any `http://` or `https://` is refused outright. Describe the destination.
6. **Slash-joined runs of three or more words are written as separate words** — "read, write and
   execute", never `read/write/execute`. Three-term runs are classified as path claims by separator
   count, and that rule cannot be relaxed without re-opening a real project-path leak. Two-term pairs
   (`read/write`, `client/server`) are fine.

Then stamp the hash into the frontmatter, replacing `pending`:

```bash
"${CLAUDE_SKILL_DIR}"/scripts/file-report.sh hash ai-docs/feedback/<file>.md
```

## Step 3: Run the gate — with an explicit `--project-dir`

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-candidate.sh ai-docs/feedback/<file>.md \
  --mode report --project-dir "$(pwd)"
```

**`--project-dir` is passed explicitly every time.** The gate can derive it from the file's own depth,
but that derivation is a backstop for hand-runs: landing one level off makes every project-identifier
term resolve against the wrong tree, and the gate then runs, says nothing, and exports what it exists
to hold back.

**Exit 1 — refused.** **Abort.** Print the offending term the gate named, leave the file on disk, and
stop. Say plainly which drafting rule above it violates. The user decides what happens next.

**Exit 2 — usage error.** Read the reason; it names what could not be confirmed. Filing from inside the
harness repository itself is refused here by design — there, filing is one ordinary issue command.

## Step 4: Resolve any ambiguity warning — before Step 5, not after

The gate writes to stderr:

```
check-candidate: ambiguity warning: <path> exists in BOTH the harness and this project
```

Exit code 0; the report is clean. But a spelling that exists in both trees arrives at the harness
indistinguishable from one about the harness's own copy, and misrouted triage is the one failure this
channel cannot afford. **Every ambiguity warning is resolved before the report is shown for approval**,
by one of:

- rewriting `Surface` to a harness path that exists in the harness tree only; or
- adding one line to `Evidence` saying which tree is meant.

Re-run Step 3 after the edit. This is the only re-run this skill permits, and it is not a retry of a
refusal — the report already passed.

## Step 5: Show the whole report, and get explicit approval

Print the file's full text. Not a summary, not a diff — the text that will be filed. Then ask whether
to file it, and wait. Silence, "looks fine", or moving to another subject is **not** approval.

## Step 6: File

```bash
"${CLAUDE_SKILL_DIR}"/scripts/file-report.sh file ai-docs/feedback/<file>.md
```

The script reads the target repository and the version from the manifest of the tree that is actually
running, so a fork files against itself; it stamps the version, the hash and which tree the `Surface`
was checked against into the issue body; and it prefixes the title with the channel marker so the
channel's issues stay selectable. None of that is yours to supply.

**On success** it prints the issue URL and records the row in `ai-docs/feedback/filed.json` — the
ledger, committed with the project. Give the user the URL.

**On any failure** — no issue tool on `PATH`, unauthenticated, the create call rejected — it exits
non-zero, prints the full report text for manual pasting, leaves the report file on disk and writes
nothing to the ledger. **Pass that text and the failure on to the user.** A channel that fails quietly
is not used a second time.

## Already filed

The script refuses, before contacting anything, when the ledger already holds this report's hash. It
prints the issue that was filed, the harness version it was filed against alongside the current one,
and the one documented override:

> remove the hash's entry from `ai-docs/feedback/filed.json`, then run again.

That is a deliberate, visible, **user-performed** act — offer it, explain what the recorded version
implies (a stop from two versions ago may point at an issue closed against an older tree), and let the
user do it. There is no force flag, and adding one would defeat the purpose.

## FORBIDDEN

- **Rewriting the report to get past a refusal.** A gate the drafter may iterate against stops being a
  boundary. Abort, name the term, and let the user decide.
- Editing `check-candidate.sh`, or adding a term to any deny list, to make a refusal go away.
- Filing without showing the user the exact text, or treating anything short of a clear yes as approval.
- Filing the same defect twice by editing `Symptom` until the hash changes.
- Reporting a defect in the project's own code through this channel. That is `/harness:bugfix`.

Context from user (if any): $ARGUMENTS
