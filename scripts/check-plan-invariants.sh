#!/usr/bin/env bash
#
# Are the base principles of a spec and a design intact, does the tree's
# statement inventory still match the record, has nothing added a required
# element, and does the edit-time refusal still cover the pages that define one?
#
# Run:  check-plan-invariants.sh [--root <dir>] [--accept]
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-plan-invariants.sh
#
# FOUR LEGS, because what the task asks for decomposes into four mechanically
# distinct questions:
#
#   1  principle integrity -- each pinned sentence present, unchanged. A
#      vanished principle is an ABSENCE; a reworded one is a WORDING
#      DIFFERENCE. Different findings, because a vanished principle protects
#      nothing while a reworded one still says something.
#   2  the inventory comparison -- every statement in the corpus matched
#      against a recorded inventory, and everything that arrived, departed,
#      changed or (in a file taking the code spelling) MOVED reported with its
#      own text, its surface, and on a change what it said before. The fourth
#      answer is narrower than the other three on purpose: in a script a line's
#      position is semantics -- as is its indentation, which the code spelling
#      therefore keeps inside the statement -- while a moved paragraph is a
#      re-wrap and not a change. It reads no sentence and rules on nothing.
#   3  addition -- the required-element set derived from three loci and compared
#      against the record in the principles document in BOTH directions, with
#      the fold's heading prohibition read on its own arm.
#   4  refusal agreement -- the live covered set against the protected-page
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
# intends to freeze at a column. A file taking the code spelling keeps its
# LEADING whitespace as part of the statement, because an indent in a script is
# scope: a de-indented block has identical words and different behaviour.
#
# NOTHING IS SET ASIDE BY THE SECOND LEG. There is no class of passage it treats
# as harmless, so a change can be absent from its report only by not having
# happened. What a reported change MEANS is a reader's judgement on the report.
#
# THE BOUND, stated here because every other check in this tree states its own:
# the comparison reports a change to a statement's TEXT, never a meaning. A
# mandate a reader infers from a statement whose words did not move is not an
# arrival and is not reported. A clean verdict therefore means that no statement
# in the corpus differs from the record -- never that no instruction implies a
# new requirement.
#
# BRINGING THE RECORD LEVEL IS AN EXPLICIT ACT. `--accept` prints the report it
# is about to take in and then rewrites the record from the current tree,
# writing each blob it names so the object exists from that moment. No other
# command and no part of an ordinary gate run advances the record. Acceptance
# DEGRADES rather than blocking: a row whose recorded blob the repository can no
# longer produce is reported as having no previous text available and the record
# is still rewritten, because previous text is what a REPORT needs and not what
# a REWRITE needs -- and an acceptance run that needs no previous text is the
# only exit from that state which the state itself cannot block.
#
# THE SCANNING TOOL IS PREFLIGHTED BEFORE THE FIRST SWEEP, and that is not
# ceremony: the host `grep` on the machine this was built on answered 0 to a
# pattern it had in fact REFUSED on a complexity limit, and a refusal a summing
# pipeline reports as a clean zero.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd -P)
MODE=verify

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ -d "${2:-}" ] || { printf 'check-plan-invariants: no such directory: %s\n' "${2:-}" >&2; exit 2; }
            ROOT=$(cd -- "$2" && pwd -P); shift 2 ;;
    --accept) MODE=accept; shift ;;
    *) printf 'check-plan-invariants: usage: check-plan-invariants.sh [--root <dir>] [--accept]\n' >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 \
  || { printf 'check-plan-invariants: cannot run -- git is needed to enumerate the tracked corpus and to resolve the blobs the record names\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 \
  || { printf 'check-plan-invariants: cannot run -- python3 is the scanning tool, and the host grep is not a substitute: it has been measured answering 0 to a pattern it refused on a complexity limit\n' >&2; exit 2; }

# THE PAYLOAD IS TWO SIBLINGS BESIDE THIS FILE rather than a heredoc: the single
# file measured 1010 lines against this repository's hard 1000-line limit, which
# ships no exemption for a script, and the first sibling went back over that
# limit once both of Round 2's corrections were in it. The second holds leg 4 and
# nothing else.
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

# THE RECORD'S PATH IS SPELLED ONCE, HERE, and handed to the payload: two
# spellings of one path are two things that can come to disagree. It sits under
# the project-data fixtures root because that is the only admitted root a method
# file may name it from -- the least-bad fit among them rather than a match, with
# the divergence named in the design.
RECORD='ai-docs/fixtures/plan-invariants.inventory'

# The record's own preflights, and they are skipped for an acceptance run
# because the first one CREATES the file. Each is a cannot-run: an absent,
# unreadable or empty record is not a tree with nothing in it.
if [ "$MODE" != accept ]; then
  [ -e "${ROOT}/${RECORD}" ] \
    || { printf 'check-plan-invariants: cannot run -- the comparison record %s does not exist, so there is no inventory to compare the tree against. An acceptance run creates it: check-plan-invariants.sh --accept\n' "$RECORD" >&2; exit 2; }
  [ -r "${ROOT}/${RECORD}" ] \
    || { printf 'check-plan-invariants: cannot run -- the comparison record %s is unreadable\n' "$RECORD" >&2; exit 2; }
  [ -s "${ROOT}/${RECORD}" ] \
    || { printf 'check-plan-invariants: cannot run -- the comparison record %s is empty, and an empty record must not read as a tree with nothing in it\n' "$RECORD" >&2; exit 2; }
fi

# `-B`: a gate must not leave a build artefact in the tree it just swept. Without
# it the first run writes scripts/__pycache__/, which nothing tracks, nothing
# ignores and both tree-walking gates would eventually trip over. Suppressing the
# write leaves nothing to ignore, which is why this is the remedy rather than a
# .gitignore entry.
exec python3 -B "$PAYLOAD" "$ROOT" "$MODE" "$RECORD"
