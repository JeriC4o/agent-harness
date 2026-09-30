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

HERE_JQ=$(cd -- "$(dirname -- "$0")/../../scripts" 2>/dev/null && pwd) || HERE_JQ=""
LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
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
  jq -nc '{ts: (now|todate), kind: "turn"}' >> "$ledger" 2>/dev/null
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
jq -nc --arg b "$bin" --argjson r "$repeats" --argjson n "$turn_calls" \
       --argjson mb "$MIN_BIN" --arg m "$MODEL" \
   '{ts: (now|todate), kind: "verdict", tier: 2, signal: "coarse-repeat",
     bin: $b, repeats: $r, turn_calls: $n, scope: "turn",
     min_bin_repeats: $mb, judged: ($m != "off")}' >> "$ledger" 2>/dev/null

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
  printf '%s\n' "$args" >> "$WORK/detail"
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

jq -nc --arg b "$bin" --arg v "$v" --arg m "$MODEL" --arg r "$line1" \
       --argjson rep "$repeats" --argjson n "$turn_calls" \
       --argjson fc "$flagged" --argjson uc "$unresolved" \
   '{ts: (now|todate), kind: "verdict", tier: 3, signal: "semantic-repeat",
     bin: $b, repeats: $rep, turn_calls: $n, verdict: $v, model: $m, reason: $r,
     flagged_calls: $fc, unresolved_calls: $uc}' \
   >> "$ledger" 2>/dev/null

[ "$v" = circling ] && \
  printf '[loop-index] tier 3: judged as one intent retried rather than distinct steps. %s\n' "$line1" >&2

mark_turn
