#!/usr/bin/env bash
#
# Tests for check-references.sh.
#
# Run: bash scripts/test-check-references.sh
#
# The suite runs the checker against a synthetic tree in which every finding
# class is planted deliberately, then against this repository, where it must be
# silent. A checker is a claim-producing instrument: its first output is a
# statement about the repo that someone will act on, so each class needs an
# input whose correct answer is known independently.

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-references.sh"
ROOT=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- unexpected [$3]" ;; *) ok "$1" ;; esac; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/docs" "$T/skills/demo" "$T/agents" "$T/ai-docs/learnings"

cat > "$T/docs/real.md" <<'EOF'
# Real Target

## Build & Test

Content.

## Fold contract — owned by `/improve`

More.
EOF

# Assembled, never written literally: a bare ${CLAUDE_PLUGIN_ROOT}/... in this
# file would be scanned as a real reference and reported as broken -- the suite
# would flag its own fixtures. The closing brace before the quote keeps this
# assignment itself off the scanner's regex, which requires a following slash.
PR='${CLAUDE_PLUGIN_ROOT}'
cat > "$T/docs/subject.md" <<EOF
# Subject

Good relative link: [real](real.md)
Good anchor, ampersand collapses to two hyphens: [bt](real.md#build--test)
Good anchor, em dash: [fold](real.md#fold-contract--owned-by-improve)
Dead link: [nope](does-not-exist.md)
Dead anchor: [bad](real.md#no-such-heading)
Issue link, GitHub repo-relative, must be ignored: [i12](../../issues/12)
Good plugin path: $PR/docs/real.md
Dead plugin path: $PR/docs/ghost.md
External, must be ignored: [claude](https://code.claude.com/docs/en/skills)
Fragment-only, must be ignored: [top](#subject)
EOF

cat > "$T/agents/paths.md" <<'EOF'
# Paths

Documented project data, fine: `ai-docs/context.md`, `ai-docs/learnings.md`,
`ai-docs/plans/done/`, `ai-docs/bugfix/trace-2026-01-01-x.md`.
Templated, must be skipped: `ai-docs/plans/YYYY-MM-DD-name.spec.md`,
`ai-docs/learnings/<username>-<branch>.md`, `ai-docs/plans/*.progress.md`.
Undocumented root, a method file writing project-data spelling: `ai-docs/workflow.md`
EOF

# A profile file is NOT method: its ai-docs spellings are its own business.
printf '# Log\n\nSee `ai-docs/whatever-i-like.md`.\n' > "$T/ai-docs/learnings/alice-x.md"

# L5 needs both heading sets: what a consumer's AGENTS.md really has, and what
# only the method file has.
mkdir -p "$T/templates/project"
printf '# Project\n\n## Build & Test\n\n## Permissions — project specifics\n\n## VCS\n' > "$T/templates/project/AGENTS.md"
printf '# Method\n\n## Build & Test\n\n## Permissions\n\n## Tooling\n\n## Learning Log\n\n## Workflow\n' > "$T/docs/agents-method.md"

cat > "$T/skills/demo/SKILL.md" <<'EOF'
# Demo

Method-only section addressed as project: `AGENTS.md § Tooling`.
Another, with trailing prose: AGENTS.md § Learning Log Boundary rule 1 Exception.
The "section" spelling, as a hook message would write it: AGENTS.md section Workflow.
Ambiguous — method has it, the project heading is longer: `AGENTS.md § Permissions`.
Genuinely project-side, both files have it: `AGENTS.md § Build & Test`.
  and with trailing words: AGENTS.md § Build & Test table.
Plain English, not a section reference: a `## Patterns` block in any skill / agent / AGENTS.md section.
EOF

out=$(bash "$CHECK" --root "$T" 2>&1); rc=$?

printf '\n== each planted defect is found ==\n'
has "dead relative link"                 "$out" "does-not-exist.md"
has "dead anchor"                        "$out" "no-such-heading"
has "dead \${CLAUDE_PLUGIN_ROOT} path"    "$out" "ghost.md"
has "undocumented ai-docs root"          "$out" "ai-docs/workflow.md"

printf '\n== and nothing else is ==\n'
hasnt "a resolving relative link"        "$out" "real.md#build--test"
hasnt "an external URL"                  "$out" "code.claude.com"
hasnt "a fragment-only link"             "$out" "#subject"
hasnt "a GitHub issue link"              "$out" "issues/12"
hasnt "a templated project path"         "$out" "YYYY-MM-DD-name"
hasnt "  a placeholder-bracketed path"   "$out" "<username>"
hasnt "  a globbed path"                 "$out" "plans/*.progress.md"
hasnt "documented project data"          "$out" "ai-docs/context.md"
hasnt "a PROFILE file's ai-docs spelling" "$out" "whatever-i-like"
check "findings -> rc 1" "$rc" "1"

printf '\n== L5: an AGENTS.md section reference names a section a consumer HAS ==\n'
has  "method-only section flagged"          "$out" "AGENTS.md § Tooling"
has  "  even with trailing prose"           "$out" "Learning Log"
has  "  the 'section' spelling too"         "$out" "Workflow"
has  "ambiguous name flagged"               "$out" "Permissions"
hasnt "a section BOTH files have"           "$out" "Build & Test"
hasnt "plain-English 'AGENTS.md section'"   "$out" "any skill / agent"

printf '\n== anchor slugs follow the real rule, not a guessed one ==\n'
# "Build & Test" -> build--test: punctuation is dropped and each REMAINING
# space becomes one hyphen; runs are NOT collapsed. Guessing the other way
# reported 20 false dead anchors on this repo once.
hasnt "ampersand heading resolves"       "$out" "real.md#build--test"
hasnt "em-dash heading resolves"         "$out" "fold-contract--owned-by-improve"

printf '\n== the documented-roots list is checked against its source of truth ==\n'
# The allowed ai-docs roots mirror docs/agents-method.md section Agent Docs.
# Hardcoding them is fine; letting them drift from the table is not.
drift=$(bash "$CHECK" --root "$ROOT" --audit-roots 2>&1); rc2=$?
check "every hardcoded root appears in the Agent Docs table" "$rc2" "0"
[ "$rc2" = "0" ] || printf '%s\n' "$drift"

printf '\n== L6: the scaffolded learnings contract mirrors the live one ==\n'
# The Propagation Rule cannot name the scaffolded copy -- sync groups live in a
# method file and templates/ does not exist in a consuming project -- so this
# comparison is the only thing between an edit and a stale contract shipping to
# every scaffolded project. A control that only ever sees them matching cannot
# tell the check from a no-op, so the divergence is planted.
MIRROR=$(mktemp -d)
cp -R "$ROOT/ai-docs" "$ROOT/templates" "$ROOT/docs" "$MIRROR/" 2>/dev/null
if [ -f "$MIRROR/templates/project/ai-docs/learnings/README.md" ]; then
  printf 'STRAY\n' >> "$MIRROR/templates/project/ai-docs/learnings/README.md"
  out=$(bash "$CHECK" --root "$MIRROR" 2>&1)
  case "$out" in *L6*) ok "a diverged scaffolded copy is flagged" ;; *) bad "a diverged scaffolded copy is flagged" ;; esac
  cp "$MIRROR/ai-docs/learnings/README.md" "$MIRROR/templates/project/ai-docs/learnings/README.md"
  out=$(bash "$CHECK" --root "$MIRROR" 2>&1)
  case "$out" in *L6*) bad "and a matching copy is not" ;; *) ok "and a matching copy is not" ;; esac
  # Absence is the worse half: a stale copy ships an out-of-date contract, a
  # missing one ships none at all. A presence guard around the comparison would
  # pass silently here, which is why this leg exists and why it is separate.
  rm -f "$MIRROR/templates/project/ai-docs/learnings/README.md"
  out=$(bash "$CHECK" --root "$MIRROR" 2>&1)
  case "$out" in *L6*) ok "a MISSING scaffolded copy is flagged too" ;; *) bad "a MISSING scaffolded copy is flagged too" ;; esac
  # And the same the other way round, which is the WORSE case by the severity
  # ordering the check itself states: no live contract at all. Guarding on the
  # live file was the same defect pointed the other way, and it survived a round
  # of review because only the copy side had a leg here.
  cp "$MIRROR/ai-docs/learnings/README.md" "$MIRROR/templates/project/ai-docs/learnings/README.md"
  rm -f "$MIRROR/ai-docs/learnings/README.md"
  out=$(bash "$CHECK" --root "$MIRROR" 2>&1)
  case "$out" in *L6*) ok "a MISSING live contract is flagged" ;; *) bad "a MISSING live contract is flagged" ;; esac
  # Neither present is silent: nothing to mirror.
  rm -f "$MIRROR/templates/project/ai-docs/learnings/README.md"
  out=$(bash "$CHECK" --root "$MIRROR" 2>&1)
  case "$out" in *L6*) bad "but a tree with neither is silent" ;; *) ok "but a tree with neither is silent" ;; esac
else
  bad "L6 fixture: the scaffolded copy was not found"
fi
rm -rf "$MIRROR"

printf '\n== this repository is clean ==\n'
out=$(bash "$CHECK" 2>&1); rc=$?
check "repo -> rc 0" "$rc" "0"
[ "$rc" = "0" ] || printf '%s\n' "$out"

printf '\n== usage ==\n'
bash "$CHECK" --root /nonexistent >/dev/null 2>&1; check "missing root -> 2" "$?" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
