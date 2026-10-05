#!/usr/bin/env bash
# PostToolUse / PostToolUseFailure -- record the OUTCOME of a call. GH-69.
#
# WHY THIS EXISTS. PreToolUse cannot know an outcome: the call has not run. So
# the ledger had no result field, and the live detector could not tell a failing
# repeat from a succeeding one -- which made it apply the intervening-edits
# filter to both and dismiss the fix-break cycle, the commonest LOGICAL loop
# there is. `test -> edit -> test -> edit -> test` was never flagged however many
# rounds it ran, because each edit looked like the question had changed. It had
# not: an edit between two failures of the same call is an ATTEMPT, which is
# evidence for the loop rather than an exemption from it.
#
# THE EVENT NAME IS THE ANSWER, not a field. PostToolUse fires after a call
# SUCCEEDS and PostToolUseFailure after one FAILS, so nothing here has to guess
# at the shape of a tool response -- which differs per tool and would be a
# silent-drift surface the moment one of them changed.
#
# APPEND, NEVER AMEND. The result is a row of its own keyed by tool_use_id, not a
# rewrite of the call row. The ledger is append-only by contract, an in-place
# edit would race with the next PreToolUse, and a reader that joins is cheaper
# than a writer that seeks.
set -u

LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"

# The append and its one-per-session failure report are shared with the other
# ledger writers; see hooks/lib/ledger-write.sh for why an unwritable ledger is
# the one failure here that is not swallowed. The guard mirrors loop-index.sh's:
# an absent helper costs the warning, never the row.
HERE_LIB=$( { cd -- "$(dirname -- "$0")" && pwd; } 2>/dev/null ) || HERE_LIB=""
if [ -n "$HERE_LIB" ] && [ -r "${HERE_LIB}/ledger-write.sh" ]; then
  . "${HERE_LIB}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi

# A hook that breaks is worse than one that is absent; every failure path here
# exits 0, unconditionally, and silence is the default rather than the
# guarantee -- the unwritable ledger reports once per session, per
# hooks/lib/ledger-write.sh. This one runs AFTER the tool, so it cannot cost a
# call; it can still cost a turn by hanging, and it does not.
in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

line=$(printf '%s' "$in" | jq -r '
    [ (.session_id // "-"), (.tool_use_id // "-"), (.hook_event_name // "-") ] | @tsv
  ' 2>/dev/null) || exit 0
[ -n "$line" ] || exit 0

IFS=$(printf '\t') read -r sid tuid ev <<<"$line"
if [ -z "${sid:-}" ] || [ "$sid" = "-" ]; then exit 0; fi
# Without an id the row cannot be joined to anything, so it would be noise in an
# append-only file rather than data. Drop it.
if [ -z "${tuid:-}" ] || [ "$tuid" = "-" ]; then exit 0; fi

case "$ev" in
  PostToolUse)        ok=true  ;;
  PostToolUseFailure) ok=false ;;
  # Wired to exactly two events. Anything else means the wiring changed and this
  # script has not been told; recording a guess would be worse than recording
  # nothing, because a wrong outcome flips a signal rather than omitting one.
  *) exit 0 ;;
esac

ledger="${LEDGER_DIR}/${sid}.jsonl"
mkdir -p "$LEDGER_DIR" 2>/dev/null || { harness_ledger_report_once "$sid" "$ledger"; exit 0; }
row=$(jq -nc --arg t "$tuid" --argjson k "$ok" \
   '{ts: (now|todate), kind: "result", tool_use_id: $t, ok: $k}' 2>/dev/null) || row=""
[ -z "$row" ] || harness_ledger_append "$sid" "$ledger" "$row" || true
exit 0
