#!/usr/bin/env bash
# Stop / SubagentStop -- the COARSE stage of the loop cascade. GH-62, GH-67.
#
# The cascade is: exact hash -> coarse hash -> model -> deep analysis. Tier 1
# (loop-index.sh) catches byte-identical repetition on the way in. This stage
# catches the shape tier 1 cannot see -- one intent retried with another path,
# another pattern, another flag -- and its job in the cascade is to CUT OFF model
# runs, not to judge.
#
# WHAT THE FIRST REAL SESSION KILLED. The previous gate counted DISTINCT
# fingerprints and required one tool to dominate the window. Measured over 110
# calls in 5 turns it fired on healthy work and the model declined every time:
#   - distinctness does not discriminate. "Same intent, different bytes" yields
#     distinct fingerprints -- and so does ordinary varied work. Both read as
#     "all distinct", so the condition was satisfied MAXIMALLY by the healthy
#     case. Both verdicts recorded calls:20, distinct_fps:20.
#   - concentration is vacuous in a single-tool session: 77 of 78 calls were
#     Bash, 98.7%, so any threshold under ~98% passed automatically.
#
# WHAT REPLACED IT, also measured: repeats of the COARSE bin within ONE TURN.
# Per turn that session gave 11x grep, 5x sed, 4x, 3x, 2x -- a spread, where
# session-wide figures were identical for every turn and carried no information.
# The coarse bin is the discriminator because it requires ACTUAL repetition of a
# normalised form, which is the property the old gate lacked.
#
# THE TURN IS THE FRAME, and the marker is why. The ledger carries ts and session
# but no turn index, because PreToolUse does not know one. Stop IS the turn
# boundary, so this writes a kind:"turn" line on every stop and scopes the gate to
# the calls after the previous one. That also makes re-judging impossible by
# construction: a turn is judged once because the marker moves past it.
#
# THE MODEL IS OFF BY DEFAULT. Until the coarse gate has produced a distribution
# worth judging, paying for a verdict per turn is the cost this cascade exists to
# avoid. Set HARNESS_T3_MODEL to a model name to enable the judging stage.
#
# IT NEVER BLOCKS. A Stop hook returning exit 2 forces the conversation to
# continue, so a loop detector spelled that way becomes the thing it exists to
# catch.
#
# THRESHOLDS ARE A HYPOTHESIS FROM ONE SESSION. 8 was chosen to sit above that
# session's second-place turn (5x) and below its first (11x). Every verdict
# records the value it fired under, so the next sessions are the measurement.
set -u

HERE_JQ=$( { cd -- "$(dirname -- "$0")/../../scripts" && pwd; } 2>/dev/null ) || HERE_JQ=""
HERE_LIB=$( { cd -- "$(dirname -- "$0")" && pwd; } 2>/dev/null ) || HERE_LIB=""
LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"

# Every ledger append below goes through the shared helper, which also owns the
# one-per-session report when the ledger cannot be written.
#
# THE TRIGGER HERE IS NOT THE ONE loop-index.sh HAS, and a later reader will ask
# why both needed fixing. loop-index.sh leaks when the DIRECTORY is unwritable:
# the file does not exist yet, so the open fails. This file leaks when the FILE
# ITSELF is unwritable -- a mode change, a read-only mount, a ledger owned by
# another user. Narrower trigger, same mechanism. Measured on a mode-444 ledger:
# `[ -s "$ledger" ]` below passes (it tests existence and size, never
# writability), so the sites ARE reachable, and `mark_turn` then leaked 182
# bytes of `Permission denied` naming the path. The byte count scales with the
# path, so it is not a constant to assert on.
#
# It is also QUIETER than tier 1 and no less wrong: a Stop hook runs once per
# TURN, not once per tool call, so the old leak repeated per turn.
if [ -n "$HERE_LIB" ] && [ -r "${HERE_LIB}/ledger-write.sh" ]; then
  . "${HERE_LIB}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi
MIN_BIN="${HARNESS_T2_MIN_BIN:-8}"        # repeats of one bin within the turn
MODEL="${HARNESS_T3_MODEL:-off}"          # "off" disables the judging stage
MAX_ARG="${HARNESS_T3_MAX_ARG:-300}"      # chars of each argument shown to it

in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$in" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
[ -n "$sid" ] || exit 0
ledger="${LEDGER_DIR}/${sid}.jsonl"
[ -s "$ledger" ] || exit 0

mark_turn() {
  # Built first, appended second, so the write goes through the shared helper.
  # This is the site every turn reaches, firing or not, so it is the one that
  # decides whether an unwritable ledger is ever mentioned at all.
  row=$(jq -nc '{ts: (now|todate), kind: "turn"}' 2>/dev/null) || row=""
  [ -z "$row" ] || harness_ledger_append "$sid" "$ledger" "$row" || true
  exit 0
}

# --- the coarse gate, scoped to this turn ----------------------------------
# The WHOLE ledger is read, not a tail: this runs once per turn, not per call,
# and a tail deep enough for a long turn is a guess. One turn in the measured
# session held 54 calls.
#
# Only kind:"call" lines count. A verdict carries tool and bin too, and counting
# one would let each firing make the next more likely.
gate=$(awk -v minbin="$MIN_BIN" '
  { k = ""; if (match($0, /"kind":"[^"]*"/)) k = substr($0, RSTART + 8, RLENGTH - 9)
    if (k == "turn") { delete c; n = 0; next }        # a new turn starts here
    if (k != "call") next
    b = ""; if (match($0, /"bin":"[^"]*"/)) b = substr($0, RSTART + 7, RLENGTH - 8)
    if (b == "") next
    c[b]++; n++ }
  END {
    if (n == 0) exit
    best = ""; bestn = 0
    for (b in c) if (c[b] > bestn) { bestn = c[b]; best = b }
    if (bestn < minbin) exit
    printf "%s\t%d\t%d\n", best, bestn, n
  }' "$ledger")
[ -n "$gate" ] || mark_turn

IFS=$(printf '\t') read -r bin repeats turn_calls <<<"$gate"
[ -n "${bin:-}" ] || mark_turn

# --- record the structural firing ------------------------------------------
# Recorded even with the model off: how often this gate fires IS the calibration
# the previous design could not produce, and it is the number that decides
# whether the judging stage is worth enabling at all.
t2row=$(jq -nc --arg b "$bin" --argjson r "$repeats" --argjson n "$turn_calls" \
       --argjson mb "$MIN_BIN" --arg m "$MODEL" \
   '{ts: (now|todate), kind: "verdict", tier: 2, signal: "coarse-repeat",
     bin: $b, repeats: $r, turn_calls: $n, scope: "turn",
     min_bin_repeats: $mb, judged: ($m != "off")}' 2>/dev/null) || t2row=""
[ -z "$t2row" ] || harness_ledger_append "$sid" "$ledger" "$t2row" || true

printf '[loop-index] coarse repeat: %s ran %s times in this turn of %s calls, under different arguments each time. Same shape of command, no exact repeat -- which is what retrying one intent looks like. If that is what happened, say what the next attempt would do differently; if it was distinct work, the threshold is in the verdict line and is meant to be tuned.\n' \
  "$bin" "$repeats" "$turn_calls" >&2

[ "$MODEL" != "off" ] || mark_turn

# --- tier 3: the model judges what the coarse stage flagged -----------------
# THE LOOP READS FROM A FILE, NEVER FROM A PIPE. Piping into `while` runs the
# body in a subshell, so the two counters below would be discarded when it exits
# and the row would report 0 forever while every assertion about it passed.
# Measured on a reduced copy of the earlier shape: n=0 beside three lines of
# detail.
WORK=$(mktemp -d) || mark_turn
trap 'rm -rf "$WORK"' EXIT INT TERM

awk '
  { k = ""; if (match($0, /"kind":"[^"]*"/)) k = substr($0, RSTART + 8, RLENGTH - 9)
    if (k == "turn") { delete keep; m = 0; next }
    if (k != "call") next
    keep[++m] = $0 }
  END { for (i = 1; i <= m; i++) print keep[i] }' "$ledger" \
  | jq -r --arg b "$bin" 'select(.bin == $b) | "\(.tool_use_id)\t\(.transcript)"' 2>/dev/null \
  > "$WORK/rows"

flagged=0
unresolved=0
: > "$WORK/detail"
while IFS=$(printf '\t') read -r tuid tpath; do
  # Once per flagged ROW, before any guard -- one call can contribute several
  # lines of detail, so counting lines inflates on exactly the subagent fan-out
  # this stage is about.
  flagged=$((flagged+1))
  [ -f "$tpath" ] || { unresolved=$((unresolved+1)); continue; }
  args=$(jq -r --arg id "$tuid" --argjson n "$MAX_ARG" '
    select(.message.content? != null) | .message.content
    | if type == "array" then .[] else empty end
    | select(.type? == "tool_use" and .id? == $id)
    | (.input | tostring)[0:$n]' "$tpath" 2>/dev/null)
  # A transcript that is on disk but carries no call with this id -- today's
  # common shape -- hides the evidence just as completely as an absent file, so
  # resolution is "contributed argument text", not "the file exists".
  [ -n "$args" ] || { unresolved=$((unresolved+1)); continue; }
  # DELIBERATELY NOT the ledger helper, and not reported. This is a scratch file
  # in a mktemp dir this script just created and owns, so a failure here is not
  # "the ledger is unwritable" -- the helper's sentence would be false, and it
  # names a consequence that does not follow: tier 1 and tier 2 are untouched
  # and the ledger a reader inspects is intact. What a failure actually costs is
  # the tier-3 detail for ONE turn, which the `[ -n "$detail" ]` guard below
  # already turns into `mark_turn`, i.e. the same graceful degradation as the
  # five other silent exits in this block (model off, claude absent, empty
  # answer, unparseable answer, no resolvable rows). Making this one loud while
  # those stay quiet would be an asymmetry with no reason behind it.
  #
  # The braces are still needed: without them a failed open leaks a raw shell
  # error, which is noise in exchange for nothing.
  { printf '%s\n' "$args" >> "$WORK/detail"; } 2>/dev/null
done < "$WORK/rows"
detail=$(cat "$WORK/detail")
[ -n "$detail" ] || mark_turn
command -v claude >/dev/null 2>&1 || mark_turn

prompt=$(printf '%s\n\n%s\n\n%s\n%s\n' \
  "A coding agent made ${repeats} calls of the same shape (${bin}) within one stretch of work, each with different arguments. Their arguments follow, in order." \
  "$detail" \
  "Question: is this one intent being retried with variations -- circling the same sub-goal without new information -- or distinct steps of deliberate work?" \
  "Answer with exactly one word on the first line: CIRCLING or PROGRESS. Then one short sentence of reason on the same line, after a space.")

answer=$(printf '%s' "$prompt" | claude -p --model "$MODEL" 2>/dev/null) || mark_turn
[ -n "$answer" ] || mark_turn

# The reason is taken from the WHOLE first line, not from a second line: asking
# for line 2 lost it every time, because the model answers on one line.
line1=$(printf '%s\n' "$answer" | sed -n 1p)
upper=$(printf '%s' "$line1" | tr '[:lower:]' '[:upper:]')
case "$upper" in
  *CIRCLING*) v=circling ;;
  *PROGRESS*) v=progress ;;
  *)          mark_turn ;;    # an answer that is neither is not a verdict
esac

t3row=$(jq -nc --arg b "$bin" --arg v "$v" --arg m "$MODEL" --arg r "$line1" \
       --argjson rep "$repeats" --argjson n "$turn_calls" \
       --argjson fc "$flagged" --argjson uc "$unresolved" \
   '{ts: (now|todate), kind: "verdict", tier: 3, signal: "semantic-repeat",
     bin: $b, repeats: $rep, turn_calls: $n, verdict: $v, model: $m, reason: $r,
     flagged_calls: $fc, unresolved_calls: $uc}' 2>/dev/null) || t3row=""
[ -z "$t3row" ] || harness_ledger_append "$sid" "$ledger" "$t3row" || true

[ "$v" = circling ] && \
  printf '[loop-index] tier 3: judged as one intent retried rather than distinct steps. %s\n' "$line1" >&2

mark_turn
