#!/usr/bin/env bash
# PreToolUse loop index -- catches a repeat BEFORE the call. GH-60.
#
# scripts/session-events.sh already finds loops, but it reads a FINISHED
# transcript under /inspect: it explains where the tokens went after they went.
# This runs on the way in, so a loop can be stopped while stopping it is cheap.
#
# THE LEDGER IS AN INDEX, NOT A COPY. Each line carries the fingerprint plus a
# POINTER -- tool_use_id and the transcript path -- because the transcript
# already holds the full JSON (arguments, result, timings). Deep analysis
# resolves the pointer; nothing is duplicated, and the ledger stays small enough
# that the hot path is a tail read.
#
# `transcript` is stored PER ENTRY and is not derivable from session_id: a
# subagent writes its own file (<session-id>/subagents/agent-*.jsonl), so one
# session maps to several transcripts, and without this field a cross-agent
# finding cannot be expanded into detail later. The payload's transcript_path is
# the PARENT's even for a call made inside a subagent, so the stored pointer is
# that path with the payload's own agent_id folded back in; with no agent_id
# there is nothing to fold and it is stored unchanged. The pointer is NOT
# checked against the disk -- at PreToolUse the subagent's file may not exist
# yet, and the first call in a subagent is exactly when it does not.
#
# `cwd` is stored because the ledger is GLOBAL -- one directory for every project
# -- and pooling projects is meaningless: thresholds that fit one codebase say
# nothing about another. The project is technically recoverable from the
# transcript path, whose directory encodes it by replacing "/" with "-", but that
# encoding is LOSSY: a directory whose own name contains a hyphen is
# indistinguishable from a path separator, so the recovered path can be wrong
# without any sign that it is. cwd arrives exact.
#
# THE KEY IS THE HASH ALONE; agent_id is a FIELD beside it. Putting agent_id in
# the key would stop the same hash from two agents matching, which defeats the
# one case a shared ledger exists for. One index then answers two questions:
#   one hash, one agent_id, N times  -> a loop
#   one hash, N distinct agent_ids   -> fan-out duplication (siblings each
#                                       doing the same work once, burning N x
#                                       the tokens while no local detector fires)
#
# agent_id is READ FROM THE PAYLOAD, and it is the only field that can tell a
# subagent call from a main-thread one. The agent TYPE stored beside it cannot:
# the client sends that on the main thread of an --agent session too, so a
# detector branching on it would read that thread as a subagent. It is a
# diagnostic here and nothing reads it -- which is why the token appears
# exactly once in this file, in the ledger entry. transcript_path cannot serve
# either: it is the parent's on both. A malformed agent_id degrades to "main"
# rather than aborting, because the single jq below carries the whole entry and
# its failure would drop the row from the index altogether.
#
# NO TRUNCATION. A line carries no content, so a 500-call session is 500 short
# lines; the hot path reads the tail. That makes the window a parameter of
# READING rather than a property of storage -- a ring buffer would make a loop
# spanning more steps than the ring partly invisible, and would throw away the
# history deep analysis wants.
set -u

# The coarse normalisation lives in one file, shared with the reader and pinned
# against session-events.sh's copy by scripts/test-bin-of.sh. Resolved from this
# script's own location so it works from an installed plugin, whose root is not
# a fixed path.
# The stderr redirect wraps the GROUP, not just `cd`: spelled
# `cd … 2>/dev/null && pwd`, a `dirname` that is missing from PATH reports
# itself on the terminal while the assignment still falls back correctly -- a
# leak with no consequence attached, which is the shape this file otherwise
# does not have.
HERE_JQ=$( { cd -- "$(dirname -- "$0")/../../scripts" && pwd; } 2>/dev/null ) || HERE_JQ=""
HERE_LIB=$( { cd -- "$(dirname -- "$0")" && pwd; } 2>/dev/null ) || HERE_LIB=""

# Every ledger append in this file goes through ledger-write.sh, which also owns
# the one-per-session report when the ledger cannot be written. Guarded like the
# detector program is: an absent helper must cost the WARNING and nothing else,
# so the fallback still appends and still keeps a failed open off the terminal.
# It deliberately does NOT re-implement the report -- a second reporter is the
# drift this file exists to avoid, and a broken install is gate 6's job.
if [ -n "$HERE_LIB" ] && [ -r "${HERE_LIB}/ledger-write.sh" ]; then
  . "${HERE_LIB}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi

LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
TAIL_N="${HARNESS_LOOP_TAIL:-20}"
THRESHOLD="${HARNESS_LOOP_THRESHOLD:-3}"
# Two failures of one call is already a retry loop; three is the bar for calls
# that succeeded. Mirrors retry_min in scripts/session-events.sh, deliberately:
# the two detectors must not disagree about what counts as a retry.
RETRY_MIN="${HARNESS_LOOP_RETRY_MIN:-2}"

# A hook that breaks is worse than a hook that is absent. Every failure path
# below exits 0, unconditionally, so a malformed payload, an absent jq or an
# unwritable ledger can never cost the session a tool call.
#
# SILENCE IS THE DEFAULT AND NOT THE GUARANTEE. The one deliberate exception is
# the unwritable ledger, which says so once per session -- losing that file
# disables this detector entirely, which is not a cost of one row. See
# hooks/lib/ledger-write.sh.
in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# ONE jq invocation. This runs before EVERY tool call, so per-call cost is the
# whole design constraint. It emits two lines: the fields the shell reasons over,
# then the ledger entry itself -- built by jq so a path carrying a quote or a
# backslash is escaped correctly rather than corrupting the line.
#
# fp is djb2, byte-identical to the definition in scripts/session-events.sh.
# The two MUST agree: if they drift, /inspect and this hook are talking about
# different fingerprints while both calling them fingerprints.
out=$(printf '%s' "$in" | jq -r -L "${HERE_JQ}" 'include "bin-of";
    def fp: tostring | explode
            | reduce .[] as $c (5381; ((. * 33) + $c) % 4294967296)
            | tostring;
    (.transcript_path // "-") as $tp
    | (if (.agent_id | type) == "string" then .agent_id else "" end) as $aid
    | (if $aid == "" then "main" else $aid end) as $agent
    | (if $aid == "" or $tp == "-" then $tp
       else (($tp | sub("\\.jsonl$"; "")) + "/subagents/agent-" + $aid + ".jsonl") end) as $tref
    | ((.tool_input // {}) | fp) as $f
    | (.tool_name // "-") as $tool
    | ([(.session_id // "-"), $tool, $f, $agent] | @tsv),
      ({ts: (now | todate), kind: "call", agent_id: $agent,
        agent_type: (.agent_type // "-"), tool: $tool, fp: $f,
        bin: ((.tool_input // {}) | bin_for($tool)),
        tool_use_id: (.tool_use_id // "-"), transcript: $tref,
        cwd: (.cwd // "-")} | tojson)
  ' 2>/dev/null) || exit 0
[ -n "$out" ] || exit 0

meta=$(printf '%s\n' "$out" | sed -n 1p)
entry=$(printf '%s\n' "$out" | sed -n 2p)
[ -n "$meta" ] || exit 0
[ -n "$entry" ] || exit 0

IFS=$(printf '\t') read -r sid tool fp agent <<<"$meta"
if [ -z "${sid:-}" ] || [ "$sid" = "-" ]; then exit 0; fi
if [ -z "${tool:-}" ] || [ "$tool" = "-" ]; then exit 0; fi

ledger="${LEDGER_DIR}/${sid}.jsonl"
# A ledger directory that cannot be CREATED disables the detector exactly as
# surely as one that cannot be written, so it reports through the same path
# rather than exiting quietly. Covering one and not the other is the partial
# alarm this change is replacing.
mkdir -p "$LEDGER_DIR" 2>/dev/null || { harness_ledger_report_once "$sid" "$ledger"; exit 0; }

# Read BEFORE appending, so the count is of PRIOR occurrences and the current
# call is added to it explicitly. Appending first and then counting would make
# the threshold quietly off by one.
#
# The detector lives in a file rather than inline so scripts/test-loop-corpus.sh
# can drive the SAME program over real ledger rows; loop-window.awk's header has
# why a replay cannot come in through this hook. An unreadable program costs the
# verdict and nothing else -- the append below still runs, so the window a later
# call reads is intact.
#
# TAIL_N is a count of CALLS; the chunk below is a count of LINES, and the
# factor is a performance hint with nothing resting on it. The measured
# line-per-call ratio across real ledgers runs 1.04 .. 2.37, so 3 covers the
# range in one read -- and where it does not, awk says RETRY instead of
# guessing and the chunk doubles until tail runs out of file. A FIXED factor
# with no retry is the hazard this replaces: it is the same silent coupling as
# `tail -n "$TAIL_N"`, one level up, and it broke the moment loop-result.sh
# started writing a row per call.
verdict=""
if [ -s "$ledger" ] && [ -r "${HERE_LIB}/loop-window.awk" ]; then
  chunk=$((TAIL_N * 3))
  while :; do
    verdict=$(tail -n "$chunk" "$ledger" 2>/dev/null | awk \
        -v want_fp="$fp" -v want_tool="$tool" -v thr="$THRESHOLD" \
        -v retry="$RETRY_MIN" -v cur="$agent" \
        -v want_calls="$TAIL_N" -v chunk="$chunk" \
        -f "${HERE_LIB}/loop-window.awk" 2>/dev/null)
    [ "$verdict" = "RETRY" ] || break
    chunk=$((chunk * 2))
  done
fi

harness_ledger_append "$sid" "$ledger" "$entry" || true

[ -n "$verdict" ] || exit 0
set -- $verdict
# span falls back to the requested window rather than being read bare: under
# `set -u` a bare "$4" ABORTS on a three-field verdict line, and this file's
# contract is that no failure path costs the session a tool call. A three-field
# line means a detector older than this caller, whose unit was the requested
# window anyway -- so the fallback is also the right answer.
kind="$1"; count="$2"; agents="$3"; span="${4:-$TAIL_N}"

# The number the AGENT is shown is $span, the window actually counted -- never
# $TAIL_N, the window requested. The two differ on a young ledger, and quoting
# 20 when 8 calls existed is the defect this change fixes, relocated into the
# message. The verdict row below keeps $TAIL_N for the opposite reason: a later
# reader of the ledger is asking which SETTING was in force, and that setting
# did not change because the ledger was short. Neither is derived from the
# other, so making them agree breaks whichever question it was answering.
#
# ALL THREE ARMS COUNT IN "CALLS", AND THE NOUN IS LOAD-BEARING. "steps" is the
# word that carried the original falsehood: the message said "in the last 20
# steps" while the number was a count of ledger LINES, and the vague noun is
# what let the two pass for each other. The quantity is a count of calls now,
# so "calls" is the noun that makes the sentence true -- and a reader of an old
# verdict row has no way to tell whether "steps" meant lines, calls or model
# turns, which is why the word does not survive anywhere in these three strings.
#
# EVERY ARM ALSO SAYS WHICH CALLS ITS NUMBERS COUNT, because the call being
# reported has NOT run -- it was interrupted at dispatch -- and a bare "3 times
# in the last 3 calls" leaves the reader to guess whether the interrupted call
# is in there. It is, in the span, always. The CLAUSE IS NOT UNIFORM and must not be
# made so: `loop` and `fanout` count the current call in every number they
# print (count is n + 1, span is prior + 1, and na includes cur), while
# `error-retry`'s count is `fails` -- recorded error outcomes, all of them
# PRIOR, because this call cannot have failed before running. A blanket
# "including the current one" on that arm would be false.
if [ "$kind" = "error-retry" ]; then
  why=$(printf 'this exact call has already FAILED %s times in the last %s calls (the failures are all prior; this call has not run yet, though the call count includes it). Edits in between do not clear it -- an edit between two failures of the same call is an attempt that did not work, which is the evidence for the loop rather than an exemption from it. Before approving a further attempt, say what about THIS change makes the failure different; if the answer is only that something was changed, the loop is the finding.' \
        "$count" "$span")
elif [ "$kind" = "fanout" ]; then
  # The old closing advice -- "check whether one result can be reused" -- named
  # an action its reader cannot take. This is shown to a sibling subagent in its
  # own context, which has no handle on another agent's result and no way to
  # reach for it. What it CAN do is narrow its own call, or report the
  # duplication upwards to the one party that can stop re-issuing it.
  why=$(printf 'the SAME call has now been made by %s different agents (%s times in the last %s calls, all three numbers including this call, which has not run yet). That is fan-out duplication, not progress: each sibling pays full price for work a sibling already did. Before approving, narrow this call to the part your own task needs -- and if you cannot, say in your hand-back that a sibling already ran it, so the parent can stop re-issuing it.' \
        "$agents" "$count" "$span")
else
  why=$(printf 'this exact call (same tool, same arguments) has run %s times within the last %s calls (both numbers counting this call, which has not run yet), with no Edit or Write in between -- so nothing it depends on has changed and the answer will be the answer it already gave. Before approving, say what is expected to differ this time; if nothing is, the loop is the finding.' \
        "$count" "$span")
fi

# The verdict line goes in AFTER the observation it is about, which is what makes
# the OUTCOME derivable without ever writing one: a hook cannot see its own effect
# (`ask` hands the decision to the permission system and hears nothing back), but
# the observations that follow are the answer -- the same fp again means the call
# went ahead, its absence means it was abandoned, a different fp on the same tool
# means it was reformulated. window/threshold are recorded because a later reader
# otherwise cannot tell a wrong call from a since-changed setting.
#
# window_unit exists because `window` changed MEANING without changing shape:
# rows written before this change counted lines, rows after it count calls, and
# nothing in the number separates them. A reader that assumes one unit silently
# mis-reads half the corpus. The precedent for adding nothing was agent_type's
# null-versus-"-" accident, which worked as a build marker only because nobody
# planned it; leaning on that twice is a choice rather than an accident.
# Built first, appended second, so the write goes through the shared helper
# like every other one. An empty row is never appended: a jq that failed would
# otherwise put a blank line in an append-only file, which every reader then
# has to tolerate forever.
vrow=$(jq -nc --arg s "$kind" --arg t "$tool" --arg f "$fp" \
       --argjson c "$count" --argjson a "$agents" \
       --argjson w "$TAIL_N" \
       --argjson th "$( [ "$kind" = "error-retry" ] && printf '%s' "$RETRY_MIN" || printf '%s' "$THRESHOLD" )" \
   '{ts: (now|todate), kind: "verdict", tier: 1, signal: $s, tool: $t, fp: $f,
     count: $c, agents: $a, decision: "ask", window: $w, window_unit: "calls",
     threshold: $th}' 2>/dev/null) || vrow=""
[ -z "$vrow" ] || harness_ledger_append "$sid" "$ledger" "$vrow" || true

# `ask`, not `deny`. The project rule is that the inspector is a diagnostic ally
# rather than a gate, and a first-tier detector keyed on an exact hash is exactly
# where a false positive is affordable and a wrong block is not. NOTE that `ask`
# routes into the normal permission flow, so an already-allow-listed command can
# pass straight through -- and allow-listed commands are the ones that loop. The
# stderr line below is therefore the load-bearing half of this report, not decoration.
printf '[loop-index] %s: %s\n' "$kind" "$why" >&2
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"[loop-index] %s"}}\n' "$why"
exit 0
