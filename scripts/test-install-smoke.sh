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
for comp in task bugfix interview context-reset project-review pr-merged improve improve-global ai-audit harness-init inspect; do
  case "$det" in *"$comp"*) ok "skill: $comp" ;; *) bad "skill: $comp missing from the inventory" ;; esac
done
for comp in spec-writer design design-review self-review review-findings self-improve learnings-escalation-audit inspector; do
  case "$det" in *"$comp"*) ok "agent: $comp" ;; *) bad "agent: $comp missing from the inventory" ;; esac
done
# Hooks are the component that silently vanished in the bug this gate exists for.
for ev in SessionStart PreToolUse PostToolUse; do
  case "$det" in *"$ev"*) ok "hook event: $ev" ;; *) bad "hook event: $ev not registered" ;; esac
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
