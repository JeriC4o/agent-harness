# /bugfix — reference

Detail bodies extracted from `SKILL.md` to keep the workflow under the 200-line soft target. Loaded on demand.

## Explore subagent prompt (Step 1 trace)

Spawn the `Explore` Subagent via the `Agent` Tool to trace the actual execution path. `Explore` is read-only; the orchestrator writes the trace artefact from `Explore`'s output.

```
Agent(subagent_type="Explore", prompt="
  Trace the actual execution path for this bug and return:
  (1) ASCII sequence diagram matching the template;
  (2) file:line citations supporting each arrow.

  Template to fill:
  [ACTUAL]
  Caller -(method())-> ServiceA -(query())-> DaoB
  DaoB -(N records)-> ServiceA
  ServiceA: applies logic X, but expected logic Y
  ServiceA -(wrong result)-> Caller

  [EXPECTED]
  Caller -(method())-> ServiceA
  ServiceA -(correct result)-> Caller

  (3) the INPUT axis the code branches on, and a fixture for BOTH sides of it.
  A reproduction is complete when it varies the INPUT, not the COMMAND: a wide matrix over a
  single fixture measures the command surface and hides half the failure modes. Name the axis
  explicitly (does this filename also resolve at the other candidate location? does this value
  hit the fallback? is this key colliding or unique?) and cover both sides. Before reporting that
  a wrong form 'fails loudly', prove it cannot ALSO fail silently — a tool that answers a bad
  argument with empty output and rc=0 turns every gate built on it into a silent pass.

  Use the Grep tool (ripgrep) for code search and carry a path filter by default — the bare
  unfiltered form is permitted ONLY when the pattern cannot appear in a deployed-config file,
  which is ASK-gated. Hidden dirs are skipped unless you pass --hidden. Before reading any file
  >500 lines, run a heading scan first. Full rules: .claude/rules/ast-index.md
")
```

## Trace artifact schema (Step 1)

Create artifact `ai-docs/bugfix/trace-YYYY-MM-DD-<short-name>.md`:

```markdown
# Bugfix Trace: <bug description>
Date: YYYY-MM-DD
Reporter: <quote from user message>

**current_step:** Step 1: Reproduce and Trace
**last_passed_gate:** (none yet)
**parent_skill:** /task    <!-- only when /bugfix is invoked from /task Step 8; omit otherwise -->
**entry_args:** <$ARGUMENTS at trace creation; omit if empty>

## Actual behaviour
<ASCII sequence diagram showing what DID happen, divergence point labelled>

## Expected behaviour
<ASCII sequence diagram showing what SHOULD happen>

## Confirmed by user: ⏳ PENDING

## Decisions log

- Step 1: <one-line description of any non-trivial decision>
```

## self-review subagent prompt (Step 6.5)

```
Agent(subagent_type="general-purpose", prompt="
  Read .claude/agents/self-review.md and follow it.
  This is a /bugfix self-review (no /task spec; no design doc).

  Spec-equivalent: ai-docs/bugfix/trace-YYYY-MM-DD-<name>.md
    — use the trace's 'Actual behaviour', 'Expected behaviour', and
      'Root Cause' sections as the AC-equivalent. The fix is correct iff
      the diff makes Actual match Expected at the labelled divergence
      point and addresses exactly the documented Root Cause.

  Out-of-scope reminder: this self-review is scoped to fitness-against-
  the-bug, NOT fitness-against-some-broader-task.

  Diff window: git diff <base_commit> HEAD
  Progress file (write findings here): ai-docs/bugfix/trace-YYYY-MM-DD-<name>.md
    — append a '## Self-Review (Round N)' section.
")
```

## Anti-pattern: fix-break cycle

```
Bug report → Edit → regression → bug report → Edit → regression → ...
```

**Signs you're in a loop:**

- User describes a similar symptom for the second time.
- You're changing the same file >2 times.
- User asks "why did you decide to do it that way?"

**Breaking the loop:**

1. STOP — close all Edits.
2. Draw a full system diagram: all components + data flow + interactions.
3. Show to user.
4. Wait for understanding confirmation.
5. Only then continue.
