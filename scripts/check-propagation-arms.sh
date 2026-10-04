#!/usr/bin/env bash
#
# Does the propagation-rule hook's `case` arm set still agree with the
# Propagation Rule table it is supposed to mirror?
#
# Run:  check-propagation-arms.sh [--root <dir>] [--print-prefix-pattern]
# Exit: 0 clean, 1 findings, 2 usage error.
#
# Tests: scripts/test-check-propagation-arms.sh
#
# WHY THIS GATE EXISTS. The arm list in hooks/hooks.json and the sync-group
# table in docs/agents-method.md are two spellings of one fact, and nothing
# connected them: the table grew members for months while the arms did not. The
# defect IS the drift, so the gate derives the member set from the table and
# asserts the live arms fire on every member and on none of the controls.
#
# WHY IT ASSERTS AGREEMENT RATHER THAN GENERATING THE ARMS. Steps 3, 5 and 7
# below are irreducibly judgement, so generation still needs a hand-written
# token->glob transform and adds a stale-artefact failure mode on top. A runtime
# single source would put a markdown parse on the hot path of every Edit/Write.
# Asserting agreement is the only option whose failure mode is a loud gate.
#
# WHY THE HARVEST READS BOTH CELLS. Measured: a left-cell-only harvest drops
# scripts/*.sh entirely, because the Inspect group names its two script output
# contracts only on the anchor row's RIGHT cell -- which is the table's own
# documented convention ("Name every member on the anchor row").
#
# WHY A CARVE-IN EXISTS AT ALL. The table's final row is prose -- "Any other
# instruction file" -- so a token-faithful harvest is SYSTEMATICALLY narrower
# than the table's meaning, and no amount of token extraction closes the gap.
# One class arrives through that row and through no token: a consuming project's
# own `.claude/skills/*/SKILL.md`. It is named below with its provenance.
#
# WHY THE CARVE-IN IS NOT SELF-CERTIFYING. Step 8 synthesises each class's
# representative FROM THE CLASS STRING, so a carve-in asserted that way compares
# a claim against itself and cannot detect being WRONG -- only being absent.
# The pre-fix pattern below is the independent witness: it is a record of
# behaviour that shipped, authored before this gate existed, so step 9 can ask
# whether the new arms still cover what the old ones covered. That question is
# what would have caught the missing tenth arm with nobody checking by hand.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
PRINT_PREFIX=0

# The arm set as it shipped BEFORE this task, verbatim from hooks/hooks.json at
# the merge-base. Two of its four arms interpolate the plugin root, so in a
# consuming project they cannot match a project file at all -- that dead half is
# the defect this task repairs, and reproducing it faithfully is the point: the
# regression question is only meaningful against what the old arms REALLY did.
PREFIX_PATTERN='*AGENTS.md|*.claude/skills/*/SKILL.md|*${CLAUDE_PLUGIN_ROOT}/agents/*.md|*${CLAUDE_PLUGIN_ROOT}/rules/*.md'

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ -d "${2:-}" ] || { printf 'check-propagation-arms: no such directory: %s\n' "${2:-}" >&2; exit 2; }
            ROOT=$(cd -- "$2" && pwd -P); shift 2 ;;
    --print-prefix-pattern) PRINT_PREFIX=1; shift ;;
    *) printf 'check-propagation-arms: usage: check-propagation-arms.sh [--root <dir>] [--print-prefix-pattern]\n' >&2; exit 2 ;;
  esac
done

if [ "$PRINT_PREFIX" = "1" ]; then printf '%s\n' "$PREFIX_PATTERN"; exit 0; fi

# The sync-group table lives in docs/propagation.md, extracted out of
# agents-method.md so the file every agent loads at session start does not carry
# a reference table that grows by a row per group. THIS GATE IS THE REASON that
# extraction is not free: it derives its expected arm set from that table, so the
# table's location is a dependency of the gate and not a documentation detail.
TABLE="${ROOT}/docs/propagation.md"
# agents-method.md is STILL an input, for a different list: the size AXIOM's
# "Applies to:" enumeration, which is what the catch-all row resolves against.
# Two inputs, two files, two existence checks -- a single rename collapsed this
# gate's derived set to ZERO once, and it reported findings rather than a pass.
METHOD="${ROOT}/docs/agents-method.md"
HOOKS="${ROOT}/hooks/hooks.json"
[ -f "$METHOD" ] || { printf 'check-propagation-arms: no docs/agents-method.md under %s -- the catch-all row resolves against its "Applies to:" list\n' "$ROOT" >&2; exit 2; }
[ -f "$TABLE" ] || { printf 'check-propagation-arms: no docs/propagation.md under %s -- the sync-group table is the input this gate derives from, so its absence is a could-not-run, never a pass\n' "$ROOT" >&2; exit 2; }
[ -f "$HOOKS" ]  || { printf 'check-propagation-arms: no hooks/hooks.json under %s\n' "$ROOT" >&2; exit 2; }

# The one reasoned exclusion. § Learning Log Boundary rule 2 FORBIDS the
# follow-on instruction-file edits the reminder asks for, so firing here would
# advise a rule violation -- a semantic conflict, not an opinion about
# membership. Step 7 fails if it ever stops matching anything, so it cannot rot
# into a silencer.
EXCLUDE='ai-docs/learnings/*-*.md'

# Provenance in the header: this arrives from the catch-all row, and no token in
# the table can produce it.
CARVE_IN='.claude/skills/*/SKILL.md'

# AC11's five bound controls are first: the false-positive bound is DEFINED by
# them rather than sampled from them. 11 and 12 separate the shipped
# `*/SKILL.md` spelling from the rejected `*.md` one, which fires on both.
# 13 is the cross-project false positive the old unanchored arm had.
CONTROLS='my-agents/notes.md
sub-agents/x.md
src/docs/readme.md
node_modules/x/docs/a.md
vendor/scripts/build.sh
ai-docs/plans/x.spec.md
ai-docs/learnings/probe-probe.md
README.md
hooks/hooks.json
@SIBLING@/docs/a.md
.claude/skills/deploy/reference.md
.claude/skills/notes.md
@SIBLING@/.claude/skills/deploy/SKILL.md'

# Every entry is INSIDE the project, because narrowing the cross-project matches
# was an intended part of the fix and must not read as a regression.
REGRESSION_PROBES='AGENTS.md
CLAUDE.md
agents/design.md
rules/ast-index.md
skills/task/SKILL.md
docs/agents-method.md
scripts/session-events.sh
ai-docs/context.md
ai-docs/learnings/README.md
.claude/skills/deploy/SKILL.md
.claude/skills/deploy/reference.md
.claude/agents/x.md'

findings=0
finding() { printf 'FINDING %s: %s\n' "$1" "$2"; findings=$((findings+1)); }

PD="$ROOT"
# Guaranteed outside "$PD"/ whatever shape the root has, which `dirname` plus a
# name cannot promise when the root is itself a filesystem root.
SIBLING="${PD}-sibling"

LIVE_CMD=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Edit|Write") | .hooks[0].command' "$HOOKS")
LIVE_PATTERN=$(printf '%s' "$LIVE_CMD" | sed -n 's/.*case "\$k" in \(.*\)) r=.*/\1/p')
[ -n "$LIVE_PATTERN" ] || { printf 'check-propagation-arms: could not extract the arm pattern from %s\n' "$HOOKS" >&2; exit 2; }

pd="$PD"
fires() { eval "case \"\$1\" in ${LIVE_PATTERN}) return 0 ;; esac; return 1"; }

# The old arms are evaluated with a plugin root that is NOT the project root,
# because that is where an installed plugin lives. Setting it to the project
# root would hand the two interpolating arms a reach they never had in
# production and invent regressions that cannot exist.
fired_before() {
  CLAUDE_PLUGIN_ROOT="${SIBLING}/plugin-cache/harness" \
    eval "case \"\$1\" in ${PREFIX_PATTERN}) return 0 ;; esac; return 1"
}

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM

# ---- steps 1-2 ---------------------------------------------------------------
grep -qF '**AXIOM — Edits to one instruction file MUST propagate' "$TABLE" \
  || { printf 'check-propagation-arms: %s carries no propagation AXIOM -- wrong file or the page was restructured\n' "$TABLE" >&2; exit 2; }
cp "$TABLE" "$TMP/section.md"
grep -E '^> \|' "$TMP/section.md" | grep -vE '^> \|[ -]*\|[ -]*\|?[ ]*$' | grep -vF 'If you edit' > "$TMP/rows.txt" || true
[ -s "$TMP/rows.txt" ] || { printf 'check-propagation-arms: docs/propagation.md has no table rows\n' >&2; exit 2; }
tr '|' '\n' < "$TMP/rows.txt" > "$TMP/cells.txt"

# ---- steps 3-5 ---------------------------------------------------------------
# `<...>` becomes `*` rather than being skipped, because `rules/<file>.md` is the
# ONLY source of the rules/*.md arm -- skip-if-templated would drop the arm's
# sole justification and the gate would then pass on its removal.
classify() {
  sed 's/^`//; s/`$//' \
  | sed -E 's/ §[^`]*$//' \
  | sed -E 's|^\$\{CLAUDE_PLUGIN_ROOT\}/||' \
  | sed -E 's/<[^>]*>/*/g; s/\*\*/*/g'
}

grep -oE '`[^`]+`' "$TMP/cells.txt" | classify | grep -E '\.(md|sh|json)$' | sort -u > "$TMP/tokens.txt"

# A bare filename is a reference to a file somewhere in the tree, and the arms
# are path-anchored, so an unresolved one is a FINDING rather than a silent drop
# -- that is how `scripts/*.sh` stayed invisible for months.
# `git ls-files` is the preferred index because it is tracked-only; a --root
# fixture is not a git work tree, so the gate falls back to the tree itself
# rather than quietly resolving nothing there.
if git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
  git -C "$ROOT" ls-files > "$TMP/index.txt"
else
  (cd "$ROOT" && find . -type f -not -path './.git/*' | sed 's|^\./||') > "$TMP/index.txt"
fi

: > "$TMP/classes.txt"
while IFS= read -r t; do
  [ -n "$t" ] || continue
  case "$t" in
    */*) printf '%s\n' "$t" >> "$TMP/classes.txt"; continue ;;
  esac
  # A token that already names a file at the project root is a class, not an
  # unqualified reference -- AGENTS.md otherwise resolves ambiguously against
  # the scaffolding copy under templates/project/.
  if [ -f "${ROOT}/${t}" ]; then printf '%s\n' "$t" >> "$TMP/classes.txt"; continue; fi
  n=$(grep -cE "(^|/)$(printf '%s' "$t" | sed 's/[.[\*^$]/\\&/g')$" "$TMP/index.txt" || true)
  if [ "$n" = "0" ]; then
    finding major "bare filename '${t}' in the Propagation Rule table resolves to no file in the tree"
  elif [ "$n" != "1" ]; then
    finding major "bare filename '${t}' in the Propagation Rule table is ambiguous (${n} candidates)"
  else
    grep -E "(^|/)$(printf '%s' "$t" | sed 's/[.[\*^$]/\\&/g')$" "$TMP/index.txt" >> "$TMP/classes.txt"
  fi
done < "$TMP/tokens.txt"

# ---- step 6: the catch-all row ----------------------------------------------
# The `> Applies to:` line is the only place in the method file that names
# CLAUDE.md -- and ai-docs/context.md -- as instruction files, and it lives in
# section Build & Test rather than in the table, so it is read from the whole
# file. Both are asserted present below, so losing this leg fails loudly.
if grep -qiF 'Any other instruction file' "$TMP/rows.txt"; then
  grep -F 'Applies to:' "$METHOD" | grep -oE '`[^`]+`' | classify \
    | grep -E '\.(md|sh|json)$' >> "$TMP/classes.txt"
else
  finding major 'the Propagation Rule table has no "Any other instruction file" catch-all row -- the instruction-file enumeration is no longer reachable'
fi

sort -u "$TMP/classes.txt" -o "$TMP/classes.txt"

for req in CLAUDE.md ai-docs/context.md; do
  grep -qxF "$req" "$TMP/classes.txt" \
    || finding major "the catch-all leg did not yield '${req}' -- AC10 requires both it and CLAUDE.md to arrive this way"
done

# ---- step 7: the exclusion, then the carve-in -------------------------------
if grep -qxF "$EXCLUDE" "$TMP/classes.txt"; then
  grep -vxF "$EXCLUDE" "$TMP/classes.txt" > "$TMP/members.txt" || true
else
  finding major "the exclusion '${EXCLUDE}' matches nothing in the derived set -- a dead exclusion silences a class nobody is tracking any more"
  cp "$TMP/classes.txt" "$TMP/members.txt"
fi

if grep -qxF "$CARVE_IN" "$TMP/members.txt"; then
  finding major "the carve-in '${CARVE_IN}' is now derivable from the table -- delete the carve-in rather than double-counting it"
else
  printf '%s\n' "$CARVE_IN" >> "$TMP/members.txt"
fi
sort -u "$TMP/members.txt" -o "$TMP/members.txt"

# ---- step 8: absolute representatives, then the controls --------------------
# Absolute by construction, so round 1's relative-representative error -- every
# arm silent because tool_input.file_path is always absolute -- cannot recur
# inside the gate.
represent() { printf '%s/%s\n' "$PD" "$(printf '%s' "$1" | sed 's/\*-\*/probe-probe/g; s/\*/probe/g')"; }

member_count=0
printf '== members derived from the Propagation Rule table ==\n'
while IFS= read -r c; do
  [ -n "$c" ] || continue
  member_count=$((member_count+1))
  rep=$(represent "$c")
  if fires "$rep"; then printf '  fires   %s\n' "$c"
  else finding blocker "no arm fires on derived class '${c}' (representative ${rep})"; fi
done < "$TMP/members.txt"
printf '   %s members, enumerated above\n' "$member_count"

control_count=0
printf '== controls that must stay silent ==\n'
while IFS= read -r c; do
  [ -n "$c" ] || continue
  control_count=$((control_count+1))
  case "$c" in @SIBLING@/*) rep="${SIBLING}/${c#@SIBLING@/}" ;; *) rep=$(represent "$c") ;; esac
  if fires "$rep"; then finding blocker "an arm fires on control '${c}' (representative ${rep})"
  else printf '  silent  %s\n' "$c"; fi
done <<EOF
$CONTROLS
EOF
printf '   %s controls, enumerated above\n' "$control_count"

# ---- step 9: the independent witness ----------------------------------------
# Asked of the OLD pattern, not of the class strings: whatever the old arms
# matched inside the project, the new arms must still match. The carve-in's
# reason-for-existing is testable here and nowhere else.
printf '== regression against the pre-fix arms ==\n'
before=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  rep="${PD}/${c}"
  fired_before "$rep" || continue
  before=$((before+1))
  if fires "$rep"; then printf '  kept    %s\n' "$c"
  else finding blocker "'${c}' matched the pre-fix arms and is SILENT under the new set -- a regression"; fi
done <<EOF
$REGRESSION_PROBES
EOF
printf '   %s probes matched the pre-fix arms\n' "$before"

# A corpus that nothing in it reaches would make step 9 pass by vacuity, and the
# named path is the one the whole carve-in exists for.
[ "$before" -gt 0 ] || finding major 'no regression probe matched the pre-fix arms -- step 9 proved nothing'
fired_before "${PD}/.claude/skills/deploy/SKILL.md" \
  || finding major 'the pre-fix pattern no longer matches .claude/skills/deploy/SKILL.md -- the carve-in has lost its independent witness'

if [ "$findings" -eq 0 ]; then
  printf '\ncheck-propagation-arms: %s derived members all fire, %s controls all silent, %s pre-fix matches all kept.\n' \
    "$member_count" "$control_count" "$before"
fi
exit $([ "$findings" -gt 0 ] && echo 1 || echo 0)
