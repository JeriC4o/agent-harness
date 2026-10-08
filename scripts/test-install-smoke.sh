#!/usr/bin/env bash
#
# Install smoke test: does this working tree actually install and LOAD as a
# plugin?
#
# Run: bash scripts/test-install-smoke.sh
#
# WHY THIS EXISTS. The other suites validate the repository's CONTENTS; none of
# them answers "will this install". Two bugs shipped straight through all of
# them:
#
#   - the manifest re-declared the default hooks path, so the plugin installed
#     and reported `failed to load` while its skills still appeared -- the only
#     symptom was that no hook ever fired;
#   - a fix merged without a version bump never reached an installed copy,
#     because the plugin cache is keyed by version and `marketplace update`
#     reports success either way.
#
# This gate runs the real install path -- add marketplace, install, inspect --
# against the working tree, so a plugin that cannot load fails here rather than
# on the first machine that installs it.
#
# ISOLATION: everything happens under a throwaway $CLAUDE_CONFIG_DIR, so the
# caller's own marketplaces, installed plugins and settings are never touched.
# The temp dir is removed on exit, including on failure.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }

# A gate that cannot run must say so, not pass quietly. Exit 2 keeps it
# distinguishable from a real failure (1).
command -v claude >/dev/null 2>&1 || {
  printf 'test-install-smoke: the `claude` CLI is not on PATH; this gate cannot run.\n' >&2
  printf '  It is the only check that exercises the install path -- do not treat its absence as a pass.\n' >&2
  exit 2
}

SANDBOX=$(mktemp -d)
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT INT TERM
export CLAUDE_CONFIG_DIR="$SANDBOX"

VERSION=$(jq -r '.version' "${ROOT}/.claude-plugin/plugin.json")
NAME=$(jq -r '.name' "${ROOT}/.claude-plugin/plugin.json")
MARKET=$(jq -r '.name' "${ROOT}/.claude-plugin/marketplace.json")

printf '\n== the sandbox starts empty ==\n'
out=$(claude plugin list 2>&1)
has "no plugins installed yet" "$out" "No plugins installed"

printf '\n== marketplace add from the working tree ==\n'
out=$(claude plugin marketplace add "$ROOT" 2>&1); rc=$?
if [ "$rc" = "0" ]; then ok "marketplace add succeeds"; else bad "marketplace add succeeds (rc=$rc): $out"; fi
has "  registers it under the manifest name" "$out" "$MARKET"

printf '\n== install ==\n'
out=$(claude plugin install "${NAME}@${MARKET}" 2>&1); rc=$?
if [ "$rc" = "0" ]; then ok "install succeeds"; else bad "install succeeds (rc=$rc): $out"; fi

printf '\n== it LOADS -- the check the other suites cannot make ==\n'
out=$(claude plugin list 2>&1)
has "status is enabled" "$out" "✔ enabled"
case "$out" in
  *"failed to load"*) bad "no load error (got: $(printf '%s' "$out" | grep -i 'Error:' | head -1))" ;;
  *)                  ok "no load error" ;;
esac
has "installed version matches the manifest" "$out" "$VERSION"

printf '\n== every component is present, not just the plugin ==\n'
det=$(claude plugin details "$NAME" 2>&1)
has "reports the manifest version" "$det" "$VERSION"
SKILLS=(task bugfix interview context-reset project-review pr-merged improve improve-global ai-audit harness-init inspect report-defect)
for comp in "${SKILLS[@]}"; do
  case "$det" in *"$comp"*) ok "skill: $comp" ;; *) bad "skill: $comp missing from the inventory" ;; esac
done
AGENTS=(spec-writer design design-review self-review review-findings self-improve learnings-escalation-audit inspector fix-scout fix-apply)
for comp in "${AGENTS[@]}"; do
  case "$det" in *"$comp"*) ok "agent: $comp" ;; *) bad "agent: $comp missing from the inventory" ;; esac
done
# THE CONVERSE ASSERTION for both lists above -- the same check the hook events
# get below, and it exists for the same reason: each loop is PRESENCE-ONLY, so a
# component the plugin ships and the list omits leaves this gate GREEN. Measured
# as a real gap, not a hypothetical: `fix-scout` and `fix-apply` were added under
# agents/ and every assertion in this file stayed green while the inventory
# checked eight agents against the ten the tree ships. The counts are DERIVED
# from the tree, so the NEXT new component announces itself here instead of
# relying on whoever edits this file next having read a comment.
covers_tree() { # <label> <declared count> <subdir> <find predicate...>
  local label="$1" declared="$2" dir="$3"; shift 3
  local found
  found=$(find "${ROOT}/${dir}" -mindepth 1 -maxdepth 1 "$@" | wc -l | tr -d ' ')
  # A count that could not be read must SAY so. An empty or zero comparand turns
  # a count assertion into a string comparison that names no number and reports
  # nothing useful -- the quietest way for this check to stop checking, and the
  # same hazard the event count below documents.
  case "$found" in
    ''|0|*[!0-9]*)
      bad "could not count ${dir}/ under ${ROOT} -- the ${label} coverage assertion cannot run"
      return ;;
  esac
  # The DECLARED side needs the same guard, and it did not until a review pass
  # measured why: this comparand used to be `${#ARRAY[@]}`, an arithmetic
  # expansion that CANNOT fail, and is now a four-stage pipeline that can --
  # break one stage and the assignment lands empty at rc=127 with the script
  # still running, because there is no `set -e`. The comparison then still
  # FAILS (the found side is a guarded positive integer, so nothing compares
  # equal to an empty string), but its message names no number on the declared
  # side -- the hazard this file states twice and guarded for `found` alone.
  case "$declared" in
    ''|0|*[!0-9]*)
      bad "could not read the declared ${label} count -- the ${label} coverage assertion cannot run"
      return ;;
  esac
  if [ "$declared" = "$found" ]; then
    ok "the ${label} list covers every ${label} the tree ships (${found})"
  else
    bad "the ${label} list checks ${declared} distinct ${label}(s) but the tree ships ${found} -- a shipped ${label} missing from the list above leaves this gate green: $(find "${ROOT}/${dir}" -mindepth 1 -maxdepth 1 "$@" | tr '\n' ' ')"
  fi
}
# A LENGTH is not a count of DISTINCT names, and the difference is the whole
# assertion: an array holding one name twice and another dropped has the same
# length as a complete one, so the comparison would pass while the dropped
# component is checked by nothing -- reinstating exactly the blindness this
# arm closes. Probed rather than reasoned: with `fix-scout` duplicated and one
# agent dropped, the length is 10 against a ten-file tree and the comparison
# goes green. Both comparands are therefore counts of distinct names; `find`
# and `jq ... | keys` cannot repeat one, so only the declared side needs it.
declared_skills=$(printf '%s\n' "${SKILLS[@]}" | sort -u | wc -l | tr -d ' ')
declared_agents=$(printf '%s\n' "${AGENTS[@]}" | sort -u | wc -l | tr -d ' ')
covers_tree skill "$declared_skills" skills -type d
covers_tree agent "$declared_agents" agents -name '*.md'
# Hooks are the component that silently vanished in the bug this gate exists for.
EVENTS=(SessionStart PreToolUse PostToolUse PostToolUseFailure Stop SubagentStart SubagentStop)
for ev in "${EVENTS[@]}"; do
  case "$det" in *"$ev"*) ok "hook event: $ev" ;; *) bad "hook event: $ev not registered" ;; esac
done
# THE CONVERSE ASSERTION, and the loop above is worthless without it. Every
# check in that loop is PRESENCE-ONLY: an event the manifest registers and this
# list omits leaves the gate GREEN, so until this line existed the list was a
# gate on the install and never on the manifest. Measured as a real gap, not a
# hypothetical: the `SubagentStart` arm was added to hooks.json and every
# assertion in this file stayed green. The count is derived from the manifest so
# the NEXT new event announces itself here instead of relying on whoever edits
# the file next having read this comment.
MANIFEST_EVENTS=$(jq -r '.hooks | keys | length' "${ROOT}/hooks/hooks.json" 2>/dev/null)
# A count that could not be read must SAY so. An unreadable manifest leaves this
# empty, and an empty comparand silently turns a count assertion into a string
# mismatch whose message names no number -- observed while falsifying this very
# assertion from a relocated copy, where ROOT pointed outside the repo.
case "$MANIFEST_EVENTS" in
  ''|*[!0-9]*)
    bad "could not read the event count from ${ROOT}/hooks/hooks.json -- the assertion below cannot run"
    MANIFEST_EVENTS="unreadable" ;;
esac
# Distinct names, not array length, for the reason spelled out above the two
# component counts: a duplicated event name would make a short list measure
# long. Carried here as well rather than left as the narrower fix, because the
# two arms are the same check over different inventories.
declared_events=$(printf '%s\n' "${EVENTS[@]}" | sort -u | wc -l | tr -d ' ')
# Same guard as the two component arms get inside `covers_tree`, and for the
# same measured reason: a pipeline comparand can land empty while the script
# runs on, and an empty one turns this into a comparison whose message names no
# number. Unlike `MANIFEST_EVENTS` above, an empty value here cannot compare
# equal to anything the manifest reports, so the cost is diagnostic only.
case "$declared_events" in
  ''|0|*[!0-9]*)
    bad "could not read the declared event count -- the event coverage assertion cannot run"
    declared_events="unreadable" ;;
esac
if [ "$declared_events" = "$MANIFEST_EVENTS" ]; then
  ok "the event list covers every event hooks.json registers (${MANIFEST_EVENTS})"
else
  bad "the event list checks ${declared_events} distinct event(s) but hooks.json registers ${MANIFEST_EVENTS} -- a registered event missing from the list above leaves this gate green: $(jq -r '.hooks | keys | join(", ")' "${ROOT}/hooks/hooks.json")"
fi

# The loops above enumerate COMPONENTS; nothing above asserts that a FILE reached
# the install. The gate's report mode refuses to run without these two -- it reads
# them as the marker that a directory is a harness install -- so if either stopped
# shipping, every report-mode run in a consuming project would exit 2 while every
# suite here, each building its own fixture root, stayed green.
printf '\n== the files report mode needs are IN the install, not just in the repo ==\n'
INSTALLED="${CLAUDE_CONFIG_DIR}/plugins/cache/${MARKET}/${NAME}/${VERSION}"
for f in docs/agents-method.md .claude-plugin/plugin.json; do
  if [ -f "${INSTALLED}/${f}" ]; then ok "installed file: $f"; else bad "installed file: $f absent under ${INSTALLED}"; fi
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
