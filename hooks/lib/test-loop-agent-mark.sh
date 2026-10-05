#!/usr/bin/env bash
#
# Tests for loop-agent-mark.sh -- the SubagentStart attribution canary (GH-86).
# Run from anywhere:
#   bash hooks/lib/test-loop-agent-mark.sh
#
# Every guard carries its OWN positive control. For the TC2 failure paths the
# control is a one-field repair of the SAME payload: a case that writes no row
# proves nothing until the otherwise-identical valid payload is shown to write
# one, because "no row" is equally true of a fixture that was never a payload.
#
# THE PAYLOAD FIXTURE IS A LIVE MEASUREMENT, NOT A GUESS. Captured 2026-10-05
# from claude-code 2.1.273 by registering a stdin-dumping SubagentStart hook and
# spawning one general-purpose subagent: the event delivers exactly
# session_id, prompt_id, transcript_path, cwd, hook_event_name, agent_id,
# agent_type -- and NOT the `permission_mode` / `scratchpad_dir` the public docs
# list. `session_id` is the field the canary rests on, it arrives as a 36-char
# uuid string, and it is the SAME id loop-index.sh keys its ledger by, which is
# what puts the mark in the file the call rows are in. That last property is
# asserted below rather than trusted: a mark in a file of its own would be a
# second ledger wearing the first one's name.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
MARK="${HERE}/loop-agent-mark.sh"
HOOK="${HERE}/loop-index.sh"
HOOKS_JSON="${HERE}/../hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }

WORK=$(mktemp -d)
# A case below chmods a directory unwritable; without the restore the trap
# cannot remove it and the suite leaks a temp tree per run.
trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT INT TERM
export HARNESS_LOOP_DIR="${WORK}/loops"
# TMPDIR is redirected into the work tree because the unwritable-ledger report
# records "already said" as a marker there. Left pointing at the real temp dir,
# the first run would write a marker that SILENCED every later run of this
# suite -- green, and measuring nothing, which is the failure mode this whole
# task is about.
export TMPDIR="${WORK}/tmp"
mkdir -p "$TMPDIR"

SID="022331b5-7823-4737-82ae-4ea1c8309293"
AID="a17de311aa309cb52"

# The measured payload, with any one field overridable as raw JSON so the
# not-a-string shapes are reachable -- --arg can only produce a string, and the
# shapes worth testing are the ones that are not one.
payload() { # [field] [raw-json-value]
  jq -nc --arg s "$SID" --arg a "$AID" \
         --arg k "${1:-}" --argjson v "${2:-null}" \
    '{session_id:$s, prompt_id:"p-1",
      transcript_path:("/tmp/proj/" + $s + ".jsonl"), cwd:"/tmp/proj",
      hook_event_name:"SubagentStart", agent_id:$a, agent_type:"general-purpose"}
     | if $k == "" then . elif $v == null then del(.[$k]) else .[$k] = $v end'
}

ledger() { printf '%s/%s.jsonl' "$HARNESS_LOOP_DIR" "$1"; }
rows()   { if [ -f "$(ledger "$1")" ]; then wc -l < "$(ledger "$1")" | tr -d ' '; else printf '0'; fi; }
# A rejection has to be asserted over the WHOLE ledger dir, not over the file
# the valid payload would have used. Measured against a planted defect that
# replaced the session_id type test with `tostring`: every "no row" assertion
# below stayed green while an absent session_id wrote its row to `null.jsonl`
# and a numeric one to `12345.jsonl`. "Not in the expected file" is also true of
# "in a file nobody will ever read", which is the worse of the two outcomes.
all_rows() {
  if [ -d "$HARNESS_LOOP_DIR" ]; then
    find "$HARNESS_LOOP_DIR" -type f -name '*.jsonl' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0'
  fi
}
ledger_files() {
  if [ -d "$HARNESS_LOOP_DIR" ]; then
    find "$HARNESS_LOOP_DIR" -type f -name '*.jsonl' | wc -l | tr -d ' '
  else
    printf '0'
  fi
}
reset()  { chmod -R u+rwX "$HARNESS_LOOP_DIR" 2>/dev/null; rm -rf "$HARNESS_LOOP_DIR"; }

OUT="${WORK}/out"; ERR="${WORK}/err"
# Status and both streams are kept apart: a hook that ERRORS looks exactly like
# a hook that worked if only the exit code is read, and TC2 is a claim about
# silence as much as about rc 0.
run_mark() { # <payload>  -> sets RC, writes $OUT / $ERR
  printf '%s' "$1" > "${WORK}/stdin"
  RC=0
  "$MARK" < "${WORK}/stdin" > "$OUT" 2> "$ERR" || RC=$?
}
bytes() { printf '%s' "$(( $(wc -c < "$OUT") + $(wc -c < "$ERR") ))"; }

# ---------------------------------------------------------------------------
printf '\n== the arm is registered, and it is the one hooks.json actually runs ==\n'
# ---------------------------------------------------------------------------
check "hooks.json registers a SubagentStart event" \
  "$(jq -r 'if .hooks.SubagentStart then "yes" else "no" end' "$HOOKS_JSON")" "yes"
check "exactly one SubagentStart command, and it names loop-agent-mark.sh" \
  "$(jq -r '[.hooks.SubagentStart[].hooks[] | select(.command | test("loop-agent-mark\\.sh"))] | length' "$HOOKS_JSON")" "1"
# hooks.json invokes the script BY PATH, so the committed mode is part of the
# contract; the convenient `bash <path>` spelling does not need the bit and
# would be green on a file the real caller cannot execute.
check "the script hooks.json invokes by path is executable" \
  "$( [ -x "$MARK" ] && echo yes || echo no )" "yes"
# A SubagentStart hook has no permissionDecision at all, so an arm that tried to
# gate a spawn would be writing a field the client drops in silence.
check "the arm declares no permission decision, which the event cannot carry" \
  "$(jq -r '[.hooks.SubagentStart[].hooks[] | select(.command | test("permissionDecision"))] | length' "$HOOKS_JSON")" "0"

# ---------------------------------------------------------------------------
printf '\n== the measured payload writes exactly one row, in the call rows own file ==\n'
# ---------------------------------------------------------------------------
reset
run_mark "$(payload)"
check "rc 0" "$RC" "0"
check "and it says nothing on either stream" "$(bytes)" "0"
check "one row appended" "$(rows "$SID")" "1"
row=$(cat "$(ledger "$SID")")
check "kind is agent-mark" "$(printf '%s' "$row" | jq -r '.kind')" "agent-mark"
check "agent_id is the one the payload carried" "$(printf '%s' "$row" | jq -r '.agent_id')" "$AID"
check "agent_type likewise" "$(printf '%s' "$row" | jq -r '.agent_type')" "general-purpose"
check "ts is an ISO instant jq can parse back" \
  "$(printf '%s' "$row" | jq -r 'try (.ts | fromdate | if . > 0 then "yes" else "no" end) catch "no"')" "yes"
# The row is a COUNT of starts, never a join key. Recording the fields a reader
# could join on would be the deferred reading of this ticket arriving by the
# back door, so the shape is pinned: four keys, and none of them tool_use_id.
check "four keys, so nothing joinable crept in" \
  "$(printf '%s' "$row" | jq -r '[keys[]] | sort | join(",")')" "agent_id,agent_type,kind,ts"

# The whole canary rests on this: the ledger loop-index.sh writes call rows to
# is keyed by the same session_id the SubagentStart payload carries. If the two
# ever keyed differently, every contradiction check would compare a mark count
# in one file against a call count in another and read as "no subagents".
printf '%s' "$(jq -nc --arg s "$SID" '{session_id:$s, hook_event_name:"PreToolUse",
   tool_name:"Bash", tool_input:{command:"echo hi"}, tool_use_id:"toolu_1",
   transcript_path:"/tmp/proj/x.jsonl"}')" | bash "$HOOK" >/dev/null 2>&1
check "a call row lands in the SAME file as the mark" "$(rows "$SID")" "2"
check "  and the pair is one mark plus one call" \
  "$(jq -r '.kind' "$(ledger "$SID")" | sort | tr '\n' ',')" "agent-mark,call,"

# ---------------------------------------------------------------------------
printf '\n== TC2: every failure path is rc 0, silent, and writes nothing ==\n'
# ---------------------------------------------------------------------------
quiet_case() { # <label> <payload-bytes>
  reset
  run_mark "$2"
  check "$1: rc 0" "$RC" "0"
  check "$1: silent" "$(bytes)" "0"
  check "$1: no row ANYWHERE under the ledger dir" "$(all_rows)" "0"
  check "$1: and no ledger file was created at all" "$(ledger_files)" "0"
}
quiet_case "empty stdin" ""
quiet_case "malformed JSON" '{"session_id":"'
quiet_case "a JSON scalar rather than an object" '"nope"'
quiet_case "session_id absent" "$(payload session_id)"
quiet_case "session_id null" "$(payload session_id 'null')"
# `del` is what an absent field needs and a null value is what an explicit null
# needs, so the two cases above are built differently on purpose; this third one
# proves the type test and not merely the emptiness test.
quiet_case "session_id a number" "$(payload session_id '12345')"
quiet_case "session_id an object" "$(payload session_id '{"a":1}')"
quiet_case "session_id the empty string" "$(payload session_id '""')"

printf '\n-- the controls: the same payload, one field repaired, DOES write --\n'
# Without these the eight cases above are satisfied by a script that writes
# nothing ever, which is the exact failure a silent canary would be.
reset
run_mark "$(payload)"
check "control: the valid payload writes a row, so the eight above fail for their stated reason" \
  "$(rows "$SID")" "1"
reset
run_mark "$(payload agent_id 'null')"
check "control: a non-string agent_id still writes the row -- the COUNT must not depend on identity" \
  "$(rows "$SID")" "1"
check "  and its agent_id is null rather than a placeholder that would inflate a distinct-id count" \
  "$(cat "$(ledger "$SID")" | jq -r '.agent_id | type')" "null"
reset
run_mark "$(payload agent_type)"
check "control: an absent agent_type writes the row too" "$(rows "$SID")" "1"

printf '\n-- an unwritable ledger dir --\n'
# The session is a FRESH one, because an unwritable DIRECTORY still permits an
# append to a file that already exists inside it -- measured: with the usual
# session the row went through and `mkdir -p` on an existing directory returns 0,
# so the first spelling of this case asserted the opposite of the truth. What
# the mode actually blocks is CREATING the ledger, which is the state a canary
# meets on a machine whose loops dir is read-only.
reset
mkdir -p "$HARNESS_LOOP_DIR"
run_mark "$(payload)"
check "precondition: the valid payload writes when the dir is writable" "$(rows "$SID")" "1"
chmod 500 "$HARNESS_LOOP_DIR"
if [ -w "$HARNESS_LOOP_DIR" ]; then
  # Running as root makes a 500 directory writable, so the case would measure
  # nothing while reporting a pass.
  bad "precondition: a chmod 500 ledger dir is still writable here, so this case cannot run"
else
  NEW="fresh-session-id"
  run_mark "$(payload session_id "\"${NEW}\"")"
  check "unwritable dir: rc 0" "$RC" "0"
  check "unwritable dir: nothing on stdout" "$(wc -c < "$OUT" | tr -d ' ')" "0"
  # NOT silent, and deliberately so. An unwritable ledger disables the detector
  # for the session; every OTHER failure path here costs one row and is
  # swallowed, but this one is reported once on stderr. See ledger-write.sh.
  has "unwritable dir: it SAYS the detector is disabled" "$(cat "$ERR")" "LOOP DETECTION IS DISABLED"
  case "$(cat "$ERR")" in
    *"ermission denied"*) bad "unwritable dir: a raw shell error leaked beside the sentence" ;;
    *)                    ok "unwritable dir: no raw shell error beside it" ;;
  esac
  run_mark "$(payload session_id "\"${NEW}\"")"
  check "unwritable dir: the second spawn is silent -- once per session, across processes" \
        "$(wc -c < "$ERR" | tr -d ' ')" "0"
  check "unwritable dir: the ledger was not created" "$(rows "$NEW")" "0"
  check "  and no ledger file appeared under any other name either" "$(ledger_files)" "1"
  check "  and the pre-existing ledger is untouched" "$(rows "$SID")" "1"
fi
chmod 700 "$HARNESS_LOOP_DIR"

printf '\n-- jq absent from PATH --\n'
# A PATH holding nothing at all does not test this: /usr/bin/env cannot find
# `bash`, the script never starts, and the 127 plus the error text read exactly
# like a hook that shouted. Measured on the first run of this suite, where both
# the case and its control reported the same 37 bytes from env rather than
# anything either was asserting about. So the sandbox carries every tool the
# script uses EXCEPT jq.
NOJQ="${WORK}/nojq"
mkdir -p "$NOJQ"
# EVERY tool the script uses except jq. The list is not decoration: a sandbox
# missing `bash` made /usr/bin/env fail and its 37 bytes read as the script's
# own output, and a sandbox missing `dirname` later did the same with 99 bytes
# once the script began resolving a sibling. A case that strips more than the
# one thing under test measures the strip, not the case.
for t in bash cat sed mkdir dirname tr; do
  p=$(command -v "$t") || { bad "precondition: $t is not on PATH, so the sandbox cannot be built"; continue; }
  ln -sf "$p" "${NOJQ}/${t}"
done
check "precondition: the sandbox resolves bash, so the script will actually run" \
  "$( PATH="$NOJQ" command -v bash >/dev/null 2>&1 && echo yes || echo no )" "yes"
check "precondition: and it resolves no jq, which is the condition under test" \
  "$( PATH="$NOJQ" command -v jq >/dev/null 2>&1 && echo yes || echo no )" "no"
reset
printf '%s' "$(payload)" > "${WORK}/stdin"
RC=0
PATH="$NOJQ" "$MARK" < "${WORK}/stdin" > "$OUT" 2> "$ERR" || RC=$?
check "absent jq: rc 0" "$RC" "0"
check "absent jq: silent" "$(bytes)" "0"
check "absent jq: no row anywhere" "$(all_rows)" "0"
# The control is the sandbox with jq ADDED, nothing else changed. Without it the
# three assertions above are equally satisfied by a PATH that broke something
# other than jq -- which is what the first spelling of this case did, with
# /usr/bin/env unable to find bash and 37 bytes of its complaint being read as
# the script's own.
reset
ln -sf "$(command -v jq)" "${NOJQ}/jq"
RC=0
PATH="$NOJQ" "$MARK" < "${WORK}/stdin" > "$OUT" 2> "$ERR" || RC=$?
check "control: the SAME sandbox with jq restored writes the row" "$(rows "$SID")" "1"
rm -f "${NOJQ}/jq"

printf '\n-- a jq that is present but FAILS, which the command -v guard cannot see --\n'
# The guard answers "is jq installed"; it says nothing about a jq that runs and
# errors -- a broken build, an unreadable library path, a filter the installed
# version rejects. That path is carried by the jq call's own redirection plus
# `|| exit 0`, so it needs a case of its own: a stub that shouts and exits 1.
printf '#!/bin/sh\nprintf "jq: fatal: simulated failure\\n" >&2\nexit 1\n' > "${NOJQ}/jq"
chmod +x "${NOJQ}/jq"
check "precondition: the stub really does fail noisily" \
  "$( PATH="$NOJQ" jq . < "${WORK}/stdin" >/dev/null 2>/dev/null && echo zero || echo nonzero )" "nonzero"
reset
RC=0
PATH="$NOJQ" "$MARK" < "${WORK}/stdin" > "$OUT" 2> "$ERR" || RC=$?
check "failing jq: rc 0" "$RC" "0"
check "failing jq: silent" "$(bytes)" "0"
check "failing jq: no row anywhere" "$(all_rows)" "0"
rm -f "${NOJQ}/jq"

# ---------------------------------------------------------------------------
printf '\n== AC17: an agent-mark row is invisible to the tier-1 detector ==\n'
# ---------------------------------------------------------------------------
# The window is bound to three CALLS here, so the chunk the shell reads is nine
# LINES. Six interleaved marks therefore crowd the chunk out of the file and the
# RETRY path has to widen it -- which is the case worth testing, because a new
# row class that merely fits inside a generous chunk tests nothing.
export HARNESS_LOOP_TAIL=3

seed_call() { # <session> <tool_use_id>
  printf '%s' "$(jq -nc --arg s "$1" --arg u "$2" '{session_id:$s,
     hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"echo loop"},
     tool_use_id:$u, transcript_path:"/tmp/proj/x.jsonl"}')" \
    | bash "$HOOK" >/dev/null 2>&1
}
judge_call() { # <session> -> combined stdout+stderr of the judged call
  printf '%s' "$(jq -nc --arg s "$1" '{session_id:$s,
     hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"echo loop"},
     tool_use_id:"toolu_judge", transcript_path:"/tmp/proj/x.jsonl"}')" \
    | bash "$HOOK" 2>&1
}
seed_mark() { # <session>
  printf '%s' "$(jq -nc --arg s "$1" --arg a "$AID" '{session_id:$s,
     hook_event_name:"SubagentStart", agent_id:$a, agent_type:"general-purpose"}')" \
    | "$MARK" >/dev/null 2>&1
}

reset
seed_call plain t1
seed_call plain t2
plain=$(judge_call plain)
has "the baseline fires without any mark present" "$plain" "[loop-index] loop:"
has "  and it counts 3 in a span of 3 calls" "$plain" "has run 3 times within the last 3 calls"

reset
seed_call marked t1
seed_mark marked; seed_mark marked; seed_mark marked
seed_call marked t2
seed_mark marked; seed_mark marked; seed_mark marked
marked=$(judge_call marked)
check "precondition: six marks really are in the marked ledger" \
  "$(grep -c '"kind":"agent-mark"' "$(ledger marked)" | tr -d ' ')" "6"
check "precondition: and they outnumber the 9-line chunk the shell first reads" \
  "$( [ "$(rows marked)" -gt 9 ] && echo yes || echo no )" "yes"
if [ "$marked" = "$plain" ]; then
  ok "the verdict is byte-identical with six agent-mark rows interleaved"
else
  bad "the verdict moved when agent-mark rows were added"
  printf '    plain : %s\n    marked: %s\n' "$plain" "$marked"
fi

# The converse control. Without it, "identical" is also what a comparison that
# cannot see the ledger at all would report.
reset
seed_call extra t1
seed_call extra t2
seed_call extra t3
seed_call extra t4
extra=$(judge_call extra)
if [ "$extra" = "$plain" ]; then
  bad "control: four extra CALL rows left the verdict unchanged, so the comparison is blind"
else
  ok "control: extra CALL rows DO move the verdict, so the comparison can see the ledger"
fi

# And the strict-kind filter stated as its own assertion rather than inferred
# from the byte comparison: a mark must not raise the count.
reset
seed_call solo t1
seed_mark solo; seed_mark solo; seed_mark solo; seed_mark solo
solo=$(judge_call solo)
# A `case` cannot live inside $( ) here: its pattern-closing `)` ends the
# substitution, and bash reports a syntax error from inside the assertion rather
# than failing it. The verdict goes through a function instead.
fired_or_silent() { case "$1" in *'[loop-index]'*) printf 'fired' ;; *) printf 'silent' ;; esac; }
check "one prior call plus four marks stays BELOW the threshold" \
  "$(fired_or_silent "$solo")" "silent"
check "control: that reading calls the baseline firing what it is" \
  "$(fired_or_silent "$plain")" "fired"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
