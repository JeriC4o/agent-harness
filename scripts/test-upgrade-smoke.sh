#!/usr/bin/env bash
#
# Upgrade smoke test: does README.md section Update actually move an installed
# payload?
#
# Run: bash scripts/test-upgrade-smoke.sh
#
# WHY THIS EXISTS. Section Update told readers to run
# `/plugin marketplace update agent-harness` and nothing else, and section
# Releasing told them `claude plugin install harness@agent-harness`. Both print
# success. Neither moves the installed payload: the first refreshes catalog
# metadata, the second short-circuits with `already installed` against an
# existing install. This machine sat five versions behind on the documented
# procedure, and every existing gate called the repository clean.
#
# They were each right about what they check. test-install-smoke.sh installs
# into an EMPTY sandbox, so the short-circuit it would have to hit never fires;
# check-release.sh sees the version bump land in the manifest, not whether it
# reaches a machine. An upgrade against a PRE-EXISTING install is the one path
# neither walks.
#
# WHAT MAKES THIS GATE HONEST: it does not retype the procedure. It EXTRACTS
# the fenced `claude …` lines out of README.md section Update and runs those, so
# a README that documents a no-op turns this red by construction, and a README
# that drifts away from what the gate expects fails rather than diverging
# quietly. Its companion, scripts/check-readme-update.sh, polices the same
# surface by wording alone and needs no CLI, so the structural checks stay
# runnable on a machine without one.
#
# The negative control is the trap itself: before running the procedure, the
# gate runs `plugin install` against the existing install and requires it to
# report success while the payload stays put. Without that leg, a green here
# could not be told from a gate that passes in the one configuration where it
# cannot fail -- which is the defect this whole ticket is about.
#
# ISOLATION: everything happens under a throwaway $CLAUDE_CONFIG_DIR against a
# temp copy of the working tree. The caller's own marketplaces, installed
# plugins and settings are never touched, and both temp dirs are removed on
# exit, including on failure.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- unexpected [$3]" ;; *) ok "$1" ;; esac; }

# A gate that cannot run must say so, not pass quietly. Exit 2 keeps it
# distinguishable from a real failure (1).
command -v claude >/dev/null 2>&1 || {
  printf 'test-upgrade-smoke: the `claude` CLI is not on PATH; this gate cannot run.\n' >&2
  printf '  It is the only check that exercises the documented update procedure -- do not treat its absence as a pass.\n' >&2
  exit 2
}

# Fixed sentinels rather than arithmetic on the real version: the patch
# component can be 0, and a version string is not a number.
LOW=0.0.1
HIGH=0.0.2

SANDBOX=$(mktemp -d)
TREE=$(mktemp -d)
cleanup() { rm -rf "$SANDBOX" "$TREE"; }
trap cleanup EXIT INT TERM
export CLAUDE_CONFIG_DIR="$SANDBOX"

printf '\n== a copy of the working tree, including files this PR has not committed ==\n'
# --others --exclude-standard is load-bearing: a tracked-only copy omits the
# very scripts a branch is adding, so the gate would exercise the previous
# release instead of the change under test.
( cd "$ROOT" && git ls-files -z --cached --others --exclude-standard ) \
  | ( cd "$ROOT" && xargs -0 -I{} sh -c 'mkdir -p "$1/$(dirname "$2")" && cp "$2" "$1/$2"' _ "$TREE" {} )

# A copy that comes back empty -- no git, a non-repo root, a broken xargs --
# otherwise produces a cascade of confusing assertion failures instead of one
# honest environment error.
[ -f "$TREE/.claude-plugin/plugin.json" ] || {
  printf 'test-upgrade-smoke: the working-tree copy under %s has no .claude-plugin/plugin.json.\n' "$TREE" >&2
  printf '  The gate cannot run against an empty copy; this is an environment error, not a pass.\n' >&2
  exit 2
}
NAME=$(jq -r '.name' "$TREE/.claude-plugin/plugin.json")
MARKET=$(jq -r '.name' "$TREE/.claude-plugin/marketplace.json")
CACHE="${SANDBOX}/plugins/cache/${MARKET}/${NAME}"
ok "the copy carries a plugin manifest ($NAME@$MARKET)"

printf '\n== install the LOWERED copy, so there is something to upgrade ==\n'
jq --arg v "$LOW" '.version = $v' "$TREE/.claude-plugin/plugin.json" > "$TREE/.claude-plugin/plugin.json.tmp" \
  && mv "$TREE/.claude-plugin/plugin.json.tmp" "$TREE/.claude-plugin/plugin.json"
out=$(claude plugin marketplace add "$TREE" 2>&1); rc=$?
if [ "$rc" = "0" ]; then ok "marketplace add succeeds"; else bad "marketplace add succeeds (rc=$rc): $out"; fi
out=$(claude plugin install "${NAME}@${MARKET}" -y 2>&1); rc=$?
if [ "$rc" = "0" ]; then ok "install succeeds"; else bad "install succeeds (rc=$rc): $out"; fi
if [ -d "${CACHE}/${LOW}" ]; then ok "cache carries $LOW"; else bad "cache carries $LOW (has: $(ls "$CACHE" 2>&1 | tr '\n' ' '))"; fi
out=$(claude plugin list 2>&1)
has "plugin list reports $LOW" "$out" "$LOW"

printf '\n== raise the source, then the negative control: install is NOT an upgrade ==\n'
jq --arg v "$HIGH" '.version = $v' "$TREE/.claude-plugin/plugin.json" > "$TREE/.claude-plugin/plugin.json.tmp" \
  && mv "$TREE/.claude-plugin/plugin.json.tmp" "$TREE/.claude-plugin/plugin.json"
out=$(claude plugin install "${NAME}@${MARKET}" --scope user -y 2>&1); rc=$?
# Success plus an unmoved payload is the whole defect, reproduced on purpose.
if [ "$rc" = "0" ]; then ok "install against an existing install still exits 0"; else bad "install against an existing install still exits 0 (rc=$rc): $out"; fi
has "  and reports success" "$out" "already installed"
if [ -d "${CACHE}/${HIGH}" ]; then bad "  but the payload did NOT move -- $HIGH appeared in the cache"; else ok "  but the payload did NOT move"; fi
out=$(claude plugin list 2>&1)
hasnt "  and plugin list still does not report $HIGH" "$out" "$HIGH"

printf '\n== the documented procedure, EXTRACTED from README section Update ==\n'
STEPS=$(awk '/^## /{s=substr($0,4)} /^```/{f=!f;next} f&&s=="Update"&&/^claude /' "$ROOT/README.md")
# An empty extraction is the one result that must never be read as a skip: it
# means the section was renamed, reworded, or lost its fence, and the gate then
# measures nothing at all.
if [ -z "$STEPS" ]; then
  bad "section Update carries no runnable claude command"
  printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
  exit 1
fi
while IFS= read -r step; do
  [ -n "$step" ] || continue
  # Text lifted out of a file is not trusted input. The guard admits only what a
  # plugin command needs; word-split invocation, never eval, does the rest.
  case "$step" in
    *[!A-Za-z0-9\ @._-]*) bad "refusing a step carrying shell metacharacters: $step"; continue ;;
  esac
  # shellcheck disable=SC2086
  out=$($step 2>&1); rc=$?
  if [ "$rc" = "0" ]; then ok "ran: $step"; else bad "ran: $step (rc=$rc): $out"; fi
done <<< "$STEPS"

printf '\n== and the payload moved -- both observables ==\n'
if [ -d "${CACHE}/${HIGH}" ]; then ok "cache carries $HIGH"; else bad "cache carries $HIGH (has: $(ls "$CACHE" 2>&1 | tr '\n' ' '))"; fi
out=$(claude plugin list 2>&1)
has "plugin list reports $HIGH" "$out" "$HIGH"
has "  and the plugin is still enabled" "$out" "✔ enabled"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
