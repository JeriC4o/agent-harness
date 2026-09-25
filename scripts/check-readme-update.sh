#!/usr/bin/env bash
#
# Does README.md document an upgrade path that cannot upgrade?
#
# Run:  check-readme-update.sh [--root <dir>]
# Exit: 0 clean, 1 findings, 2 usage error.
#
# WHY THIS EXISTS. Section Update told readers to run
# `/plugin marketplace update agent-harness` and nothing else; section Releasing
# told them `claude plugin install harness@agent-harness --scope user`. The
# first refreshes catalog metadata and never touches the installed payload. The
# second, against an existing install, short-circuits with `already installed`
# and exits 0. Both print success, neither upgrades anything, and this machine
# sat five versions behind on the documented procedure.
#
# Every existing gate called that README clean, and each was right about what it
# checks: the manifests parsed, the links resolved, every script parsed, the
# plugin installed into an EMPTY sandbox and loaded, and the version bumped. An
# upgrade against a PRE-EXISTING install is the one path none of them walks, and
# a procedure written in English is not a path any of them reads.
#
# The companion gate is scripts/test-upgrade-smoke.sh, which executes section
# Update's own commands against a lowered install and requires the payload to
# move. That one is stronger, and it is the one that would have caught the
# original defect -- but it costs ~20 s and a `claude` CLI. This check needs
# neither, so it can run wherever the structural checks run.
#
# WHOLE FILE, NOT ONE SECTION. The defect was in section Releasing too, and a
# future section Upgrading would be invisible to a check scoped to Update.
# Install is the single exempt section: installing is what it documents.
#
# Findings, printed to stderr as CLASS|line|message:
#   D1  a fenced line outside Install runs `plugin install` -- a command in a
#       fence is an instruction to run, and this one reports success without
#       moving the payload
#   D2  a fenced BLOCK outside Install carries `marketplace update` with no
#       `plugin update` -- a metadata refresh dressed as an upgrade
#   D3  section Update carries no fenced `plugin update` at all -- the positive
#       requirement, without which deleting the fence would satisfy D1 and D2
#
# D2 is block-scoped rather than line-scoped because the two commands of a
# correct procedure sit on separate lines of one fence, which a line-scoped rule
# would flag. The two patterns cannot overlap: `claude plugin marketplace
# update` contains `plugin marketplace update`, never `plugin update`.
#
# Tests: scripts/test-check-readme-update.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ -d "${2:-}" ] || { printf 'check-readme-update: no such directory: %s\n' "${2:-}" >&2; exit 2; }
            ROOT=$(cd -- "$2" && pwd); shift 2 ;;
    *) printf 'check-readme-update: usage: check-readme-update.sh [--root <dir>]\n' >&2; exit 2 ;;
  esac
done

README="${ROOT}/README.md"
[ -f "$README" ] || { printf 'check-readme-update: no README.md under %s\n' "$ROOT" >&2; exit 2; }

EXEMPT='Install'

# A gate that cannot run must not report a pass -- the defect this whole branch
# exists to remove. `out` being empty means "no findings" AND "awk never ran",
# so awk's status is read explicitly rather than inferred from the output.
command -v awk >/dev/null 2>&1 || {
  printf 'check-readme-update: `awk` is not on PATH; this gate cannot run.\n' >&2
  printf '  It is the only check that reads the README update surface -- do not treat its absence as a pass.\n' >&2
  exit 2
}

out=$(awk -v exempt="$EXEMPT" '
  function flush(  ) {
    if (nblock > 0 && sec != exempt && mktup && !plugup)
      printf "D2|%d|%s: a fenced block gives `marketplace update` with no `plugin update` -- metadata refresh only, the payload never moves\n", bstart, sec
    nblock = 0; mktup = 0; plugup = 0
  }
  !fence && /^## / { flush(); sec = substr($0, 4); sub(/[ \t]+$/, "", sec) }
  /^[ \t]*(```|~~~)/ { if (fence) flush(); else bstart = NR; fence = !fence; next }
  fence {
    nblock++
    if ($0 ~ /plugin[ \t]+install/ && sec != exempt)
      printf "D1|%d|%s: a fenced command upgrades via `plugin install` -- against an existing install it short-circuits and reports success\n", NR, sec
    if ($0 ~ /marketplace[ \t]+update/) mktup = 1
    if ($0 ~ /(^|[^a-z])plugin[ \t]+update/) { plugup = 1; if (sec == "Update") update_verb = 1 }
  }
  END {
    flush()
    if (!update_verb)
      printf "D3|0|section Update carries no fenced `plugin update` command -- the canonical upgrade verb is absent\n"
  }
' "$README")
awk_rc=$?

# Catches what the preflight cannot: a broken awk implementation, a program it
# rejects, an unreadable README. Any of those leave `out` empty and would
# otherwise print the success message.
[ "$awk_rc" -eq 0 ] || {
  printf 'check-readme-update: awk exited %d; the README was not analysed.\n' "$awk_rc" >&2
  printf '  This is an environment failure, not a clean result -- do not treat it as a pass.\n' >&2
  exit 2
}

if [ -n "$out" ]; then
  printf 'check-readme-update: REFUSED -- README.md documents an upgrade path that does not upgrade.\n\n' >&2
  printf '%s\n' "$out" | sed 's/^/  /' >&2
  printf '\nThe canonical procedure is README.md section Update. Section %s is the only one\n' "$EXEMPT" >&2
  printf 'allowed to put an install command in a fence.\n' >&2
  exit 1
fi

printf 'check-readme-update: the README update surface names the upgrade verb and nothing that silently no-ops.\n'
exit 0
