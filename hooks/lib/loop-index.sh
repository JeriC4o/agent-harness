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
# finding cannot be expanded into detail later.
#
# THE KEY IS THE HASH ALONE; agent_id is a FIELD beside it. Putting agent_id in
# the key would stop the same hash from two agents matching, which defeats the
# one case a shared ledger exists for. One index then answers two questions:
#   one hash, one agent_id, N times  -> a loop
#   one hash, N distinct agent_ids   -> fan-out duplication (siblings each
#                                       doing the same work once, burning N x
#                                       the tokens while no local detector fires)
#
# NO TRUNCATION. A line carries no content, so a 500-call session is 500 short
# lines; the hot path reads the tail. That makes the window a parameter of
# READING rather than a property of storage -- a ring buffer would make a loop
# spanning more steps than the ring partly invisible, and would throw away the
# history deep analysis wants.
set -u

LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
TAIL_N="${HARNESS_LOOP_TAIL:-20}"
THRESHOLD="${HARNESS_LOOP_THRESHOLD:-3}"

# A hook that breaks is worse than a hook that is absent. Every failure path
# below exits 0 and stays silent, so a malformed payload, an absent jq or an
# unwritable ledger can never cost the session a tool call.
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
out=$(printf '%s' "$in" | jq -r '
    def fp: tostring | explode
            | reduce .[] as $c (5381; ((. * 33) + $c) % 4294967296)
            | tostring;
    (.transcript_path // "-") as $tp
    | (if ($tp | test("/subagents/agent-.*\\.jsonl$"))
       then ($tp | sub("^.*/agent-"; "") | sub("\\.jsonl$"; ""))
       else "main" end) as $agent
    | ((.tool_input // {}) | fp) as $f
    | (.tool_name // "-") as $tool
    | ([(.session_id // "-"), $tool, $f, $agent] | @tsv),
      ({ts: (now | todate), agent_id: $agent, tool: $tool, fp: $f,
        tool_use_id: (.tool_use_id // "-"), transcript: $tp} | tojson)
  ' 2>/dev/null) || exit 0
[ -n "$out" ] || exit 0

meta=$(printf '%s\n' "$out" | sed -n 1p)
entry=$(printf '%s\n' "$out" | sed -n 2p)
[ -n "$meta" ] || exit 0
[ -n "$entry" ] || exit 0

IFS=$(printf '\t') read -r sid tool fp agent <<<"$meta"
if [ -z "${sid:-}" ] || [ "$sid" = "-" ]; then exit 0; fi
if [ -z "${tool:-}" ] || [ "$tool" = "-" ]; then exit 0; fi

mkdir -p "$LEDGER_DIR" 2>/dev/null || exit 0
ledger="${LEDGER_DIR}/${sid}.jsonl"

# Read BEFORE appending, so the count is of PRIOR occurrences and the current
# call is added to it explicitly. Appending first and then counting would make
# the threshold quietly off by one.
verdict=""
if [ -s "$ledger" ]; then
  verdict=$(tail -n "$TAIL_N" "$ledger" 2>/dev/null | awk \
      -v want_fp="$fp" -v want_tool="$tool" -v thr="$THRESHOLD" -v cur="$agent" '
    BEGIN { n = 0; first = 0; changed = 0 }
    {
      t = ""; f = ""; a = ""
      if (match($0, /"tool":"[^"]*"/))     { t = substr($0, RSTART + 8,  RLENGTH - 9)  }
      if (match($0, /"fp":"[^"]*"/))       { f = substr($0, RSTART + 6,  RLENGTH - 7)  }
      if (match($0, /"agent_id":"[^"]*"/)) { a = substr($0, RSTART + 12, RLENGTH - 13) }
      # STATE qualifier, free because EVERY step is in the ledger, not only the
      # matched ones: a write between the repeats means the world changed, so
      # the same call is not the same question.
      if (t == "Edit" || t == "Write" || t == "NotebookEdit") { changed = NR }
      if (t == want_tool && f == want_fp) { n++; if (first == 0) first = NR; seen[a] = 1 }
    }
    END {
      if (n == 0) exit
      if (changed > first) exit
      seen[cur] = 1
      na = 0; for (k in seen) na++
      if (n + 1 >= thr) { printf "%s %d %d\n", (na > 1 ? "fanout" : "loop"), n + 1, na }
    }')
fi

printf '%s\n' "$entry" >> "$ledger" 2>/dev/null

[ -n "$verdict" ] || exit 0
set -- $verdict
kind="$1"; count="$2"; agents="$3"

if [ "$kind" = "fanout" ]; then
  why=$(printf 'the SAME call has now been made by %s different agents (%s times in the last %s steps). That is fan-out duplication, not progress: each sibling pays full price for work a sibling already did. Before approving, check whether one result can be reused.' \
        "$agents" "$count" "$TAIL_N")
else
  why=$(printf 'this exact call (same tool, same arguments) has run %s times within the last %s steps, with no Edit or Write in between -- so nothing it depends on has changed and the answer will be the answer it already gave. Before approving, say what is expected to differ this time; if nothing is, the loop is the finding.' \
        "$count" "$TAIL_N")
fi

# `ask`, not `deny`. The project rule is that the inspector is a diagnostic ally
# rather than a gate, and a first-tier detector keyed on an exact hash is exactly
# where a false positive is affordable and a wrong block is not. NOTE that `ask`
# routes into the normal permission flow, so an already-allow-listed command can
# pass straight through -- and allow-listed commands are the ones that loop. The
# stderr line below is therefore the load-bearing half of this report, not decoration.
printf '[loop-index] %s: %s\n' "$kind" "$why" >&2
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"[loop-index] %s"}}\n' "$why"
exit 0
