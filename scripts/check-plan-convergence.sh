#!/usr/bin/env bash
#
# Does a plan pair converge -- does every number name its own origin, and does
# every relation the documents state actually hold?
#
# Run:  check-plan-convergence.sh [--root <dir>] <spec> <design>
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-plan-convergence.sh
#
# WHY IT IS ITS OWN CHECK rather than a verb of the plan-document gate or a leg
# of the plan-invariants verification. The verification's payload is at this
# repository's hard line limit, so it has no room. The plan-document gate is a
# protected page, so every edit to it costs an authorisation -- and it is
# protected because it carries element data, which is the one thing this check
# must not acquire: a check that must stay OUT of that set cannot be grown
# inside one that is in it.
#
# IT IS EXEMPT FROM THE GATE RUNNER'S MEMBER LIST, by name, for the reason
# scripts/check-redline.sh is: a member is invoked with no arguments and both of
# the paths below are required, so a documented member would report cannot-run
# on every run. The exemption lives in EXEMPT_CHECKS there. Its consequence is
# worth stating: this check's entire mechanical coverage is its own test suite,
# which the runner DOES derive from the tree.
#
# AND ITS NAME MUST NOT APPEAR IN THE PROFILE'S STRUCTURAL-CHECKS SPAN in the
# `bash scripts/<name>.sh` spelling. That span is parsed by the runner's gate
# inventory, which compares it against the member table in both directions, so a
# check named there while exempt from membership reddens the inventory in one
# direction and could never be made to agree. The existing path-argument gate is
# named nowhere in that span for the same reason.
#
# THE THREE-OUTCOME CONVENTION IS THE CONTRACT. A caller refuses on anything
# that is not a clean 0 and says WHICH of the two it got, because the two have
# different remedies: findings are fixed or excused in the plan, while a
# cannot-run means this check examined less than it reported and nothing about
# the plan has been established.
#
# WHAT A CLEAN VERDICT MEANS, and the bound is the point of saying it: no figure
# in either document sits in a clause silent about its origin, and no relation
# the classes can evaluate disagrees with its operands. It does NOT mean a
# stated origin is honest, or that a relation stated only in prose holds -- the
# first is a reading and the second is counted as not evaluable. Read the counts
# and the per-class roster, not the exit status alone.
#
# THE SCANNING TOOL IS PREFLIGHTED BEFORE THE FIRST SWEEP. The host `grep` on
# the machine this was built on answered 0 to a pattern it had in fact REFUSED
# on a complexity limit, and a refusal that a summing pipeline reports as a
# clean zero is the failure mode this whole check exists to catch in documents.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd -P)
USAGE='usage: check-plan-convergence.sh [--root <dir>] <spec> <design>'

SPEC=''
DESIGN=''
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ -d "${2:-}" ] || { printf 'check-plan-convergence: no such directory: %s\n' "${2:-}" >&2; exit 2; }
            ROOT=$(cd -- "$2" && pwd -P); shift 2 ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) printf 'check-plan-convergence: %s\n' "$USAGE" >&2; exit 2 ;;
    *)  if [ -z "$SPEC" ]; then SPEC=$1
        elif [ -z "$DESIGN" ]; then DESIGN=$1
        else printf 'check-plan-convergence: %s\n' "$USAGE" >&2; exit 2
        fi
        shift ;;
  esac
done

[ -n "$SPEC" ] && [ -n "$DESIGN" ] \
  || { printf 'check-plan-convergence: %s\n' "$USAGE" >&2; exit 2; }

# Each of these is a cannot-run rather than a finding, because a document that
# is not there was not examined, and an unexamined document is not a clean one.
for f in "$SPEC" "$DESIGN"; do
  [ -e "$f" ] || { printf 'check-plan-convergence: cannot run -- no such plan document: %s\n' "$f" >&2; exit 2; }
  [ -r "$f" ] || { printf 'check-plan-convergence: cannot run -- the plan document %s is unreadable\n' "$f" >&2; exit 2; }
done

command -v git >/dev/null 2>&1 \
  || { printf 'check-plan-convergence: cannot run -- git is needed to establish that the record the section names are derived from is in the index\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { printf 'check-plan-convergence: cannot run -- python3 is the scanning tool, and the host grep is not a substitute: it has been measured answering 0 to a pattern it refused on a complexity limit\n' >&2; exit 2; }

# A payload that EXISTS but cannot be loaded reports as findings rather than as
# a cannot-run unless something stops it, and rc 1 is the one outcome a run that
# could not complete may not report. Absent and unreadable are caught here,
# before python3 starts; an unparseable payload is caught by a leg of the suite,
# which parses it as its own assertion.
PAYLOAD="${HERE}/check-plan-convergence.py"
[ -r "$PAYLOAD" ] \
  || { printf 'check-plan-convergence: cannot run -- the payload %s is missing or unreadable, and an absent payload is not a clean sweep\n' "$PAYLOAD" >&2; exit 2; }

# `-B`: a gate must not leave a build artefact in the tree it just swept.
# Without it the first run writes scripts/__pycache__/, which nothing tracks,
# nothing ignores, and both tree-walking gates would eventually trip over.
exec python3 -B "$PAYLOAD" "$ROOT" "$SPEC" "$DESIGN"
