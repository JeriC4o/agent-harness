#!/usr/bin/env bash
#
# Does a plan pair converge -- does every number name its own origin, and does
# every relation the documents state actually hold?
#
# Run:  check-plan-convergence.sh <spec> <design>
#       check-plan-convergence.sh --excuse '<class>|<spot>|<subject>' --grounds '<why>' <spec> <design>
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
# Core: check-plan-convergence.py <method root> <method-indexed 0|1> <project root>
#       <spec> <design> <excuse key> <grounds> -- the first three are resolved here.
#
# Tests: scripts/test-check-plan-convergence.sh
#
# THE GRANT ACT IS A FLAG AND NOT A SECOND ENTRY POINT, because it must see the
# finding before it waives it: it runs every class with excusing suspended,
# prints the finding carrying the key in full, and only then appends a row to
# the record beside the plan. An ordinary run writes nothing, ever. The key is
# copied off a finding line, which carries it, so neither half is retyped.
#
# WHY IT IS ITS OWN CHECK rather than a verb of the plan-document gate. The
# plan-document gate is a protected page, so every edit to it costs an
# authorisation -- and it is protected because it carries element data, which is
# the one thing this check must not acquire: a check that must stay OUT of that
# set cannot be grown inside one that is in it.
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
# the plan has been established. A 0 is not always the word `clean`: a plan
# whose every finding is excused also exits 0 and says so in those terms, so a
# caller that treats 0 as nothing-to-see loses the waivers.
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
METHOD_ROOT=$(cd -- "${HERE}/.." && pwd -P)
USAGE='usage: check-plan-convergence.sh [--excuse <key> --grounds <why>] <spec> <design>'

SPEC=''
DESIGN=''
EXCUSE=''
GROUNDS=''
while [ $# -gt 0 ]; do
  case "$1" in
    --excuse)  EXCUSE=${2:-}; shift 2 ;;
    --grounds) GROUNDS=${2:-}; shift 2 ;;
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

# Grounds a later reader can check are half of what the act records, so neither
# flag is any use without the other and an act missing one writes nothing.
if [ -n "$EXCUSE" ] && [ -z "$GROUNDS" ]; then
  printf 'check-plan-convergence: cannot run -- --excuse needs --grounds, in terms a later reader can check\n' >&2; exit 2
fi
if [ -n "$GROUNDS" ] && [ -z "$EXCUSE" ]; then
  printf 'check-plan-convergence: cannot run -- --grounds excuses nothing without --excuse naming the finding\n' >&2; exit 2
fi

# Each of these is a cannot-run rather than a finding, because a document that
# is not there was not examined, and an unexamined document is not a clean one.
for f in "$SPEC" "$DESIGN"; do
  [ -e "$f" ] || { printf 'check-plan-convergence: cannot run -- no such plan document: %s\n' "$f" >&2; exit 2; }
  [ -r "$f" ] || { printf 'check-plan-convergence: cannot run -- the plan document %s is unreadable\n' "$f" >&2; exit 2; }
done

command -v git >/dev/null 2>&1 \
  || { printf 'check-plan-convergence: cannot run -- git is needed, because the project roster is a git index\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { printf 'check-plan-convergence: cannot run -- python3 is the scanning tool, and the host grep is not a substitute: it has been measured answering 0 to a pattern it refused on a complexity limit\n' >&2; exit 2; }

# THE PAYLOAD IS THREE FILES BESIDE THIS ONE, because the single file reached
# 1,447 lines against this repository's hard 1000-line limit, whose two
# documented exemptions -- auto-generated code and single large expressions --
# fit no hand-written script. A per-file route does exist and the verification
# payload took it: the Thousand-line exemption row in ai-docs/context.md. The
# six classes moved out in the two groups this check already states as data:
# the ones that HOLD a plan into one sibling, the ones whose findings are a
# report into the other. What the core keeps is what both groups read.
#
# A payload that EXISTS but cannot be loaded reports as findings rather than as
# a cannot-run unless something stops it, and rc 1 is the one outcome a run that
# could not complete may not report. Absent and unreadable are caught here,
# before python3 starts, separately and per file, and every message NAMES the
# path it is about -- a cannot-run that cannot say what is missing is this
# repository's own recurring defect. The unparseable case is caught by the
# core payload's own loader, which wraps the module EXECUTION rather than the
# spec lookup, and by a leg of the suite that parses all three.
PAYLOAD="${HERE}/check-plan-convergence.py"
[ -r "$PAYLOAD" ] \
  || { printf 'check-plan-convergence: cannot run -- the payload %s is missing or unreadable, and an absent payload is not a clean sweep\n' "$PAYLOAD" >&2; exit 2; }
HOLDING_PAYLOAD="${HERE}/check-plan-convergence-holding.py"
[ -e "$HOLDING_PAYLOAD" ] \
  || { printf 'check-plan-convergence: cannot run -- the payload sibling %s does not exist, so the classes that HOLD a plan would never run and a verdict without them is not a clean sweep\n' "$HOLDING_PAYLOAD" >&2; exit 2; }
[ -r "$HOLDING_PAYLOAD" ] \
  || { printf 'check-plan-convergence: cannot run -- the payload sibling %s is unreadable\n' "$HOLDING_PAYLOAD" >&2; exit 2; }
REPORTING_PAYLOAD="${HERE}/check-plan-convergence-reporting.py"
[ -e "$REPORTING_PAYLOAD" ] \
  || { printf 'check-plan-convergence: cannot run -- the payload sibling %s does not exist, so the classes whose findings are a report would never run and a verdict without them is not a clean sweep\n' "$REPORTING_PAYLOAD" >&2; exit 2; }
[ -r "$REPORTING_PAYLOAD" ] \
  || { printf 'check-plan-convergence: cannot run -- the payload sibling %s is unreadable\n' "$REPORTING_PAYLOAD" >&2; exit 2; }

# TWO ROOTS, because an installed copy sits in a plugin cache that is no
# repository. The method inputs ship with this file and are read from its
# parent; the project data -- the roster, the baseline, the excuse record beside
# the spec -- belongs to the work tree holding the spec. One root serving both
# made every installed run a cannot-run before any class examined anything.
SPEC_DIR=$(cd -- "$(dirname -- "$SPEC")" && pwd -P)
PROJECT_TOP=$(git -C "$SPEC_DIR" rev-parse --show-toplevel 2>/dev/null)
[ -n "$PROJECT_TOP" ] \
  || { printf 'check-plan-convergence: cannot run -- %s is not in a git work tree git will read, %s\n' \
         "$SPEC_DIR" 'and the project roster is a git index' >&2; exit 2; }
PROJECT_ROOT=$(cd -- "$PROJECT_TOP" && pwd -P)
# Indexed only when the method root IS a top level: a plugin directory inside an
# unrelated repository has an index that never lists the plugin's files, and
# guarding on it would refuse every run there.
METHOD_INDEXED=0
METHOD_TOP=$(git -C "$METHOD_ROOT" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$METHOD_TOP" ] && [ "$(cd -- "$METHOD_TOP" && pwd -P)" = "$METHOD_ROOT" ]; then
  METHOD_INDEXED=1
fi

# `-B`: a gate must not leave a build artefact in the tree it just swept.
# Without it the first run writes scripts/__pycache__/, which nothing tracks,
# nothing ignores, and both tree-walking gates would eventually trip over.
exec python3 -B "$PAYLOAD" "$METHOD_ROOT" "$METHOD_INDEXED" "$PROJECT_ROOT" \
  "$SPEC" "$DESIGN" "$EXCUSE" "$GROUNDS"
