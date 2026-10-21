#!/usr/bin/env bash
#
# Are the base principles of a spec and a design intact, has nothing added a
# required element, and does the edit-time refusal still cover the pages that
# define one?
#
# Run:  check-plan-invariants.sh [--root <dir>]
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-plan-invariants.sh
#
# THREE LEGS, because what the task asks for decomposes into three mechanically
# distinct questions:
#
#   1  principle integrity -- each pinned sentence present, unchanged. A
#      vanished principle is an ABSENCE; a reworded one is a WORDING
#      DIFFERENCE. Different findings, because a vanished principle protects
#      nothing while a reworded one still says something.
#   2  addition -- the required-element set derived from three loci and compared
#      against the record in the principles document in BOTH directions, with
#      the fold's heading prohibition read on its own arm.
#   3  refusal agreement -- the live covered set against the protected-page
#      table, in both directions.
#
# WHY LEG 1 NEEDS A SECOND COPY OF THE SENTENCES. A document compared only
# against itself cannot detect its own rewording. The pinned copy in the payload
# is an EXPECTATION WITH PROVENANCE, not a second authority:
# docs/plan-invariants.md governs the wording, and that copy exists only so a
# divergence is loud. The consequence is stated rather than hidden -- an edit
# that changes the document AND that copy together passes, which is the
# authorisation route, because a deliberate change to a principle is then two
# co-ordinated edits whose diff a human reads.
#
# COMPARISON COLLAPSES INTERNAL WHITESPACE. These documents hard-wrap, so a
# reflow is not a wording change while any change to the words is. A
# byte-for-byte comparison would pin the wrap column of a document nobody
# intends to freeze at a column.
#
# THE BOUND, stated here because every other check in this tree states its own.
# Two classes of change are from now on caught by the pull-request diff and by
# nothing mechanical: a mandate arriving on an examined page that the element
# derivation does not read, in words the coverage sweep does not recognise; and
# a change to prose that is not one of the principles' own numbered sentences,
# those sentences being the only prose any surviving comparison pins, so the
# explanatory paragraphs around them, and prose anywhere else on the examined
# surfaces, are pinned by nothing.
#
# THE SCANNING TOOL IS PREFLIGHTED BEFORE THE FIRST SWEEP, and that is not
# ceremony: the host `grep` on the machine this was built on answered 0 to a
# pattern it had in fact REFUSED on a complexity limit, and a refusal a summing
# pipeline reports as a clean zero.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd -P)

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ -d "${2:-}" ] || { printf 'check-plan-invariants: no such directory: %s\n' "${2:-}" >&2; exit 2; }
            ROOT=$(cd -- "$2" && pwd -P); shift 2 ;;
    *) printf 'check-plan-invariants: usage: check-plan-invariants.sh [--root <dir>]\n' >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 \
  || { printf 'check-plan-invariants: cannot run -- git is needed to enumerate the tracked corpus\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { printf 'check-plan-invariants: cannot run -- python3 is the scanning tool, and the host grep is not a substitute: it has been measured answering 0 to a pattern it refused on a complexity limit\n' >&2; exit 2; }

# THE PAYLOAD IS TWO SIBLINGS BESIDE THIS FILE rather than a heredoc: the single
# file crossed this repository's hard 1000-line limit, whose two documented
# exemptions -- auto-generated code and single large expressions -- fit no
# hand-written script, so one leg moved out. The second sibling holds leg 3 and
# nothing else; the ground for it being that leg is in its own header.
#
# THE FAILURE MODE THAT ARGUED FOR ONE FILE IS GUARDED RATHER THAN ABSENT. A
# sibling that exists but cannot be loaded reports as findings rather than as a
# cannot-run unless something stops it: the existence and readability cases are
# caught here, before python3 starts, and the unparseable case -- which no shell
# test can see -- is caught by the loader in the first sibling, which wraps the
# module EXECUTION and not the spec lookup. Each is rc 2, and a suite leg asserts
# rc 2 and NOT rc 1 for exactly that reason.
PAYLOAD="${HERE}/check-plan-invariants.py"
[ -r "$PAYLOAD" ] \
  || { printf 'check-plan-invariants: cannot run -- the payload %s is missing or unreadable, and an absent payload is not a clean sweep\n' "$PAYLOAD" >&2; exit 2; }
REFUSAL="${HERE}/check-plan-invariants-refusal.py"
[ -e "$REFUSAL" ] \
  || { printf 'check-plan-invariants: cannot run -- the payload sibling %s does not exist, so the leg it carries would never run and a report without it is not a clean sweep\n' "$REFUSAL" >&2; exit 2; }
[ -r "$REFUSAL" ] \
  || { printf 'check-plan-invariants: cannot run -- the payload sibling %s is unreadable\n' "$REFUSAL" >&2; exit 2; }

# `-B`: a gate must not leave a build artefact in the tree it just swept. Without
# it the first run writes scripts/__pycache__/, which nothing tracks, nothing
# ignores and both tree-walking gates would eventually trip over. Suppressing the
# write leaves nothing to ignore, which is why this is the remedy rather than a
# .gitignore entry.
exec python3 -B "$PAYLOAD" "$ROOT"
