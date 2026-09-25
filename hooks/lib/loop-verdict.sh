#!/usr/bin/env bash
# Stop / SubagentStop loop verdict -- tier 2. GH-62.
#
# Tier 1 (loop-index.sh) catches BYTE-IDENTICAL repetition. This is the other
# class: one intent spelled different ways -- another path, a reworded prompt, a
# changed flag -- which djb2 cannot see by construction and which is the commoner
# shape of getting stuck.
#
# THE GATE IS NOT TIER 1, AND THAT IS THE WHOLE POINT. Gating this on a tier-1
# signal would mean only ever seeing the class tier 1 already caught, making this
# strictly redundant -- the defect ${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md
# § Testing names: a filter keyed on the property the qualifier separates on
# structurally excludes the case the qualifier exists to confirm. So the gate is
# keyed on the OPPOSITE of byte-identity: one tool repeated many times with many
# DISTINCT fingerprints, dominating the window.
#
# The model runs only on what survives that, because the structural signal cannot
# tell circling from methodical breadth -- ten Reads of ten different files look
# identical to it. Structure narrows; the model judges.
#
# IT NEVER BLOCKS. A Stop hook returning exit 2 forces the conversation to
# continue, so a loop detector spelled that way becomes the thing it exists to
# catch. Reporting is stderr plus a verdict line.
#
# THRESHOLDS ARE A HYPOTHESIS, NOT A SPECIFICATION. They cannot be validated
# without a corpus of real sessions. Each verdict records the values it fired
# under, so the first real runs are the measurement rather than the confirmation.
set -u

LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
WINDOW="${HARNESS_T2_WINDOW:-40}"        # steps of ledger to consider
MIN_CALLS="${HARNESS_T2_MIN_CALLS:-5}"   # of one tool, within the window
MIN_DISTINCT="${HARNESS_T2_MIN_FPS:-3}"  # distinct fingerprints among them
MODEL="${HARNESS_T2_MODEL:-haiku}"
MAX_ARG="${HARNESS_T2_MAX_ARG:-300}"     # chars of each argument shown to the model

in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$in" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
[ -n "$sid" ] || exit 0
ledger="${LEDGER_DIR}/${sid}.jsonl"
[ -s "$ledger" ] || exit 0

# --- structural gate -------------------------------------------------------
# One pass over the tail. Only kind:"call" lines count -- a verdict carries tool
# and fp too, and counting one would let each firing make the next more likely.
gate=$(tail -n "$WINDOW" "$ledger" 2>/dev/null | awk \
    -v min_calls="$MIN_CALLS" -v min_fps="$MIN_DISTINCT" '
  {
    k = ""; if (match($0, /"kind":"[^"]*"/)) k = substr($0, RSTART + 8, RLENGTH - 9)
    if (k != "call") next
    t = ""; if (match($0, /"tool":"[^"]*"/)) t = substr($0, RSTART + 8, RLENGTH - 9)
    f = ""; if (match($0, /"fp":"[^"]*"/))   f = substr($0, RSTART + 6, RLENGTH - 7)
    if (t == "" || f == "") next
    calls[t]++; total++
    if (!((t SUBSEP f) in seenfp)) { seenfp[t SUBSEP f] = 1; fps[t]++ }
  }
  END {
    if (total == 0) exit
    best = ""; bestn = 0
    for (t in calls) if (calls[t] > bestn) { bestn = calls[t]; best = t }
    if (best == "") exit
    # Many calls AND many DISTINCT fingerprints: the same tool tried different
    # ways. Either alone is ordinary -- five identical calls are tier 1 work, and
    # five distinct ones spread across a varied window are just breadth.
    if (bestn < min_calls) exit
    if (fps[best] < min_fps) exit
    # Concentration, the cheap stand-in for "this turn went round on one thing".
    # Without it a long productive turn trips the gate purely by being long.
    if (bestn * 100 < total * 60) exit
    printf "%s %d %d %d\n", best, bestn, fps[best], total
  }')
[ -n "$gate" ] || exit 0
set -- $gate
tool="$1"; calls="$2"; distinct="$3"; total="$4"

# --- do not re-judge a window already judged -------------------------------
# Every Stop would otherwise re-flag the same tail and call the model again: a
# loop detector in a loop. A tier-2 verdict for this tool inside the window means
# the question has been asked.
already=$(tail -n "$WINDOW" "$ledger" 2>/dev/null | awk -v t="$tool" '
  { k=""; if (match($0, /"kind":"[^"]*"/)) k=substr($0,RSTART+8,RLENGTH-9)
    if (k != "verdict") next
    if ($0 !~ /"tier":2/) next
    tt=""; if (match($0, /"tool":"[^"]*"/)) tt=substr($0,RSTART+8,RLENGTH-9)
    if (tt == t) n++ }
  END { print n+0 }')
[ "${already:-0}" -eq 0 ] || exit 0

# --- resolve the pointers into detail --------------------------------------
# The ledger stores an INDEX; the arguments live in the transcript. Resolve per
# entry against its OWN transcript, because a subagent writes its own file.
detail=$(tail -n "$WINDOW" "$ledger" 2>/dev/null \
  | jq -r --arg t "$tool" 'select(.kind == "call" and .tool == $t)
                           | "\(.tool_use_id)\t\(.transcript)"' 2>/dev/null \
  | while IFS=$(printf '\t') read -r tuid tpath; do
      [ -f "$tpath" ] || continue
      jq -r --arg id "$tuid" --argjson n "$MAX_ARG" '
        select(.message.content? != null)
        | .message.content
        | if type == "array" then .[] else empty end
        | select(.type? == "tool_use" and .id? == $id)
        | (.input | tostring)[0:$n]' "$tpath" 2>/dev/null
    done)
[ -n "$detail" ] || exit 0

# --- the model judges ------------------------------------------------------
# Absent CLI, a failure, or an unparseable answer all end the run silently: a
# hook that breaks is worse than one that is absent, and the structural signal
# alone is not strong enough to report on its own.
command -v claude >/dev/null 2>&1 || exit 0

prompt=$(printf '%s\n\n%s\n\n%s\n%s\n' \
  "Below are the arguments of ${calls} calls to the ${tool} tool made by a coding agent within one stretch of work, in order. ${distinct} of them are textually distinct." \
  "$detail" \
  "Question: are these calls one intent being retried with variations -- the agent circling the same sub-goal without new information -- or are they distinct steps of deliberate work?" \
  "Answer with exactly one word on the first line: CIRCLING or PROGRESS. On a second line give one short sentence of reason.")

answer=$(printf '%s' "$prompt" | claude -p --model "$MODEL" 2>/dev/null) || exit 0
[ -n "$answer" ] || exit 0

first=$(printf '%s\n' "$answer" | sed -n 1p | tr '[:lower:]' '[:upper:]')
reason=$(printf '%s\n' "$answer" | sed -n 2p)
case "$first" in
  *CIRCLING*) call_it=circling ;;
  *PROGRESS*) call_it=progress ;;
  *)          exit 0 ;;   # an unparseable answer is neither, so record nothing
esac

# A DECLINE IS RECORDED TOO, and that is not a reversal of "non-firings are not
# logged". For tier 1 that rule holds: every call is a line, so an absent
# adjacent verdict IS the non-firing. Here the gate firing is itself unrecorded,
# so a decline would leave no trace anywhere -- and it costs twice. The
# already-judged guard keys on a tier-2 verdict line existing, so without this
# the SAME window is re-judged on every Stop until it slides out; measured, that
# is one model call per Stop against one for the whole window when the answer is
# circling. Progress is the common case, so it is paid constantly -- a loop
# detector asking the same question in a loop. And it costs the calibration
# number that matters most: how often the structural gate fires and the model
# disagrees is the gate's false-positive rate, unmeasurable while a decline is
# silent.
jq -nc --arg t "$tool" --arg r "$reason" --arg m "$MODEL" --arg v "$call_it" \
       --argjson c "$calls" --argjson d "$distinct" --argjson tot "$total" \
       --argjson w "$WINDOW" --argjson mc "$MIN_CALLS" --argjson mf "$MIN_DISTINCT" \
   '{ts: (now|todate), kind: "verdict", tier: 2, signal: "semantic-repeat",
     tool: $t, calls: $c, distinct_fps: $d, window_calls: $tot, verdict: $v,
     model: $m, reason: $r, window: $w, min_calls: $mc, min_distinct: $mf}' \
   >> "$ledger" 2>/dev/null

# Only a finding is reported; a decline is data, not news.
[ "$call_it" = circling ] || exit 0

printf '[loop-index] tier 2: %s calls to %s in this stretch, %s of them textually distinct, judged as one intent retried rather than distinct steps. %s\nIf that is wrong, the thresholds are in the verdict line and are meant to be tuned. If it is right, say what new information the next attempt would use.\n' \
  "$calls" "$tool" "$distinct" "$reason" >&2
exit 0
