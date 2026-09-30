#!/usr/bin/env bash
#
# Tests for loop-index.sh -- the PreToolUse loop detector (GH-60). Run from anywhere:
#   bash hooks/lib/test-loop-index.sh
#
# Every guard carries its OWN positive control: the control deletes or defeats
# one guard and requires the damage to reappear. A suite that only exercises the
# happy path produces a byte-identical result with the guard removed, so it
# cannot see the guard's absence -- which is the shape this repo keeps relearning.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
HOOK="${HERE}/loop-index.sh"
HOOKS_JSON="${HERE}/../hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected [$3])" ;; *) ok "$1" ;; esac; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HARNESS_LOOP_DIR="${WORK}/loops"

SID="sess-1"
MAIN_TP="/tmp/proj/${SID}.jsonl"
SUB_TP="/tmp/proj/${SID}/subagents/agent-abc123.jsonl"

# Fire the hook once. $1 tool, $2 command/arg payload, $3 transcript path,
# $4 agent_id, $5 agent_type. An empty argument means the field is ABSENT from
# the payload rather than empty in it -- the client omits all three, and a
# present-but-empty field takes a different branch in the hook.
fire() {
  jq -nc --arg s "$SID" --arg t "$1" --arg c "$2" --arg tp "${3:-}" \
         --arg aid "${4:-}" --arg aty "${5:-}" \
     '{session_id:$s, hook_event_name:"PreToolUse",
       tool_name:$t, tool_input:{command:$c}, tool_use_id:"toolu_x"}
      + (if $tp  == "" then {} else {transcript_path:$tp} end)
      + (if $aid == "" then {} else {agent_id:$aid}       end)
      + (if $aty == "" then {} else {agent_type:$aty}     end)' \
  | bash "$HOOK" 2>/dev/null
}
# $3 is the agent_id as raw JSON: --arg can only produce a string, and the
# shapes worth testing are the ones that are not one.
fire_aid_json() {
  jq -nc --arg s "$SID" --arg t "$1" --arg c "$2" --arg tp "$MAIN_TP" --argjson aid "$3" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:$t, tool_input:{command:$c}, tool_use_id:"toolu_x", agent_id:$aid}' \
  | bash "$HOOK" 2>/dev/null
}
fire_err() {
  jq -nc --arg s "$SID" --arg t "$1" --arg c "$2" --arg tp "$3" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:$t, tool_input:{command:$c}, tool_use_id:"toolu_x"}' \
  | bash "$HOOK" 2>&1 >/dev/null
}
reset() { rm -rf "$HARNESS_LOOP_DIR"; }

printf '\n== the ledger is written, and it is an INDEX not a copy ==\n'
reset
fire Bash "echo CANARY_SECRET_ARG" "$MAIN_TP" >/dev/null
LED="${HARNESS_LOOP_DIR}/${SID}.jsonl"
check "a ledger line is appended" "$( [ -s "$LED" ] && echo yes || echo no )" "yes"
check "one call, one line" "$(wc -l < "$LED" | tr -d ' ')" "1"
line=$(cat "$LED")
hasnt "the payload itself is NOT stored" "$line" "CANARY_SECRET_ARG"
has "but the pointer is" "$line" '"tool_use_id":"toolu_x"'
has "and the transcript, per entry" "$line" '"transcript":"/tmp/proj/sess-1.jsonl"'
has "and the tool" "$line" '"tool":"Bash"'
check "the line is valid JSON" "$(printf '%s' "$line" | jq -e . >/dev/null 2>&1 && echo yes || echo no)" "yes"

printf '\n== the fingerprint agrees with scripts/session-events.sh ==\n'
# If these two drift, /inspect and this hook both say "fingerprint" and mean
# different numbers. Recompute djb2 from the OTHER file's definition and compare.
SE="${HERE}/../../scripts/session-events.sh"
if [ -f "$SE" ]; then
  se_fp=$(jq -rn --slurpfile _ /dev/null '
      def fp: tostring | explode
              | reduce .[] as $c (5381; ((. * 33) + $c) % 4294967296)
              | tostring;
      ({command:"echo hi"} | fp)')
  reset; fire Bash "echo hi" "$MAIN_TP" >/dev/null
  mine=$(jq -r '.fp' < "$LED")
  check "same input -> same fingerprint" "$mine" "$se_fp"
  check "the definition is still present in session-events.sh" \
        "$(grep -c 'reduce .\[\] as \$c (5381' "$SE")" "1"
else
  bad "session-events.sh is missing; cannot check fingerprint agreement"
fi

printf '\n== below the threshold, nothing is said ==\n'
reset
o1=$(fire Bash "git status" "$MAIN_TP"); check "1st call is silent" "$o1" ""
o2=$(fire Bash "git status" "$MAIN_TP"); check "2nd call is silent" "$o2" ""

printf '\n== at the threshold, it asks ==\n'
o3=$(fire Bash "git status" "$MAIN_TP")
has "3rd identical call returns a decision" "$o3" '"permissionDecision":"ask"'
has "  and names it a loop" "$o3" "loop-index"
has "  and reports the count" "$o3" "3 times"
e3=$(fire_err Bash "git status" "$MAIN_TP")
has "  the stderr half carries it too" "$e3" "[loop-index] loop"

printf '\n== two record classes, and the reader must filter on kind ==\n'
reset
fire Bash "git status" "$MAIN_TP" >/dev/null
check "an observation declares its kind" "$(jq -r '.kind' < "$LED")" "call"
fire Bash "git status" "$MAIN_TP" >/dev/null
fire Bash "git status" "$MAIN_TP" >/dev/null   # this one fires
check "a firing appends a verdict line too" "$(jq -r 'select(.kind=="verdict") | .kind' < "$LED")" "verdict"
v=$(jq -c 'select(.kind=="verdict")' < "$LED")
check "  it records the tier"      "$(printf '%s' "$v" | jq -r '.tier')"      "1"
check "  the signal"               "$(printf '%s' "$v" | jq -r '.signal')"    "loop"
check "  the decision"             "$(printf '%s' "$v" | jq -r '.decision')"  "ask"
check "  and the settings it fired under" \
      "$(printf '%s' "$v" | jq -r '"\(.window)/\(.threshold)"')" "20/3"
check "the verdict lands AFTER the call it is about" \
      "$(jq -r '.kind' < "$LED" | tr '\n' ',')" "call,call,call,verdict,"

# THE COUPLING. A verdict line carries "tool" and "fp", so a reader that does not
# filter on kind counts it as a call -- and then every firing makes the next one
# more likely, a detector that feeds itself. The 4th identical call must report 4.
o=$(fire Bash "git status" "$MAIN_TP")
has "the verdict is NOT counted as a call" "$o" "4 times"
hasnt "  (5 would mean it counted itself)" "$o" "5 times"

printf '\n== POSITIVE CONTROL: drop the kind filter, the detector feeds itself ==\n'
# Without the filter the same sequence reports 5, because the verdict line it
# just wrote is indistinguishable from a call. Asserted by re-reading the same
# ledger through an awk that omits the guard.
tally() { # $1: 1 = with the kind filter, 0 = without
  tail -n 20 "$LED" | awk -v want_fp="$(jq -r 'select(.kind=="call") | .fp' < "$LED" | tail -1)" \
                          -v filter="$1" '
    { k=""; if (match($0, /"kind":"[^"]*"/)) k=substr($0,RSTART+8,RLENGTH-9)
      if (filter == 1 && k != "call") next
      f=""; if (match($0, /"fp":"[^"]*"/)) f=substr($0,RSTART+6,RLENGTH-7)
      if (f == want_fp) n++ }
    END { print n+0 }'
}
# 4 calls; the 3rd and the 4th each fired, so there are 2 verdict lines carrying
# the same fp. Unfiltered that reads as 6 -- the excess IS the self-feeding.
check "with the filter, the ledger holds 4 calls" "$(tally 1)" "4"
check "without it, the same ledger reads as 6"    "$(tally 0)" "6"
check "  and the excess is exactly the verdicts" \
      "$(jq -rs '[.[] | select(.kind=="verdict")] | length' < "$LED")" "2"

printf '\n== the outcome recorder writes a joinable row, and only for the two events ==\n'
RES="${HERE}/loop-result.sh"
RN=0
rid() { RN=$((RN+1)); RID="r$RN"; }   # assigned by the CALLER: $(...) is a subshell
rcall() { # $1 tool, $2 command -- uses $RID
  jq -nc --arg s "$SID" --arg t "$1" --arg c "$2" --arg id "$RID" --arg tp "$MAIN_TP" \
     '{session_id:$s, transcript_path:$tp, tool_name:$t, tool_input:{command:$c},
       tool_use_id:$id, cwd:"/p"}' | bash "$HOOK" 2>/dev/null
}
outcome() { # $1 id, $2 event
  jq -nc --arg s "$SID" --arg id "$1" --arg e "$2" \
     '{session_id:$s, tool_use_id:$id, hook_event_name:$e}' | bash "$RES" >/dev/null 2>&1
}
reset; rid; rcall Bash "npm test" >/dev/null; outcome "$RID" PostToolUseFailure
r=$(jq -c 'select(.kind=="result")' < "$LED")
check "a failure writes a result row"  "$(printf '%s' "$r" | jq -r '.kind')" "result"
check "  keyed by tool_use_id"         "$(printf '%s' "$r" | jq -r '.tool_use_id')" "$RID"
check "  and ok is false"              "$(printf '%s' "$r" | jq -r '.ok')" "false"
outcome "$RID" PostToolUse
check "a success writes ok true" \
      "$(jq -rs '[.[]|select(.kind=="result")][-1].ok' < "$LED")" "true"
before=$(wc -l < "$LED" | tr -d ' ')
outcome "$RID" SomeOtherEvent
check "an event it was not wired to writes nothing" "$(wc -l < "$LED" | tr -d ' ')" "$before"
outcome "" PostToolUse
check "a result with no id writes nothing"          "$(wc -l < "$LED" | tr -d ' ')" "$before"
check "empty stdin -> 0"   "$(printf '' | bash "$RES" >/dev/null 2>&1; echo $?)" "0"
check "malformed -> 0"     "$(printf '{nope' | bash "$RES" >/dev/null 2>&1; echo $?)" "0"

printf '\n== THE FIX-BREAK CYCLE: edits between FAILURES do not clear it ==\n'
# test -> edit -> test -> edit -> test. Before GH-69 the intervening-edit filter
# dismissed this at every round, so the commonest logical loop was invisible
# however long it ran. An edit between two failures of the same call is an
# ATTEMPT that did not work: evidence for the loop, not an exemption from it.
reset
rid; rcall Bash "npm test" >/dev/null; outcome "$RID" PostToolUseFailure
rid; rcall Edit "src/a.ts" >/dev/null; outcome "$RID" PostToolUse
rid; o=$(rcall Bash "npm test");       outcome "$RID" PostToolUseFailure
check "one prior failure is not yet a retry loop" "$o" ""
rid; rcall Edit "src/a.ts" >/dev/null; outcome "$RID" PostToolUse
rid; o=$(rcall Bash "npm test")
has "two prior failures fire, edits notwithstanding" "$o" '"permissionDecision":"ask"'
has "  named as a retry, not as a loop"             "$o" "already FAILED 2 times"
has "  and it says why the edits do not excuse it"  "$o" "attempt that did not work"
check "the verdict records the signal" \
      "$(jq -rs '[.[]|select(.kind=="verdict")][-1].signal' < "$LED")" "error-retry"
check "  and the retry threshold, not the loop one" \
      "$(jq -rs '[.[]|select(.kind=="verdict")][-1].threshold' < "$LED")" "2"

printf '\n== CONTROL: the same shape, but the calls SUCCEED ==\n'
# Identical interleaving; only the outcome differs. Re-running a gate after an
# edit is work, and this is the case the edit filter exists for.
reset
for _ in 1 2 3; do
  rid; o=$(rcall Bash "npm test"); outcome "$RID" PostToolUse
  rid; rcall Edit "src/a.ts" >/dev/null; outcome "$RID" PostToolUse
done
check "three successful runs around edits stay silent" "$o" ""
check "  and nothing is recorded" \
      "$(jq -rs '[.[]|select(.kind=="verdict")]|length' < "$LED")" "0"

printf '\n== POSITIVE CONTROL: make the edit filter unconditional again ==\n'
# The defect this fixes, reinstated: move the edit check above the failure check
# and the fix-break cycle goes silent again while the control above is unaffected.
MUTF="${WORK}/mut-editfilter.sh"
perl -0pe 's/      if \(fails \+ 0 >= retry\) \{\n        printf "%s %d %d\\n", "error-retry", fails, na\n        exit\n      \}\n      if \(changed > first\) exit/      if (changed > first) exit\n      if (fails + 0 >= retry) {\n        printf "%s %d %d\\n", "error-retry", fails, na\n        exit\n      }/' "$HOOK" > "$MUTF"
check "the mutation applied" \
      "$(grep -c 'if (changed > first) exit' "$MUTF")" "1"
reset
rid; jq -nc --arg s "$SID" --arg id "$RID" --arg tp "$MAIN_TP" \
      '{session_id:$s,transcript_path:$tp,tool_name:"Bash",tool_input:{command:"npm test"},tool_use_id:$id,cwd:"/p"}' \
    | bash "$MUTF" >/dev/null 2>&1; outcome "$RID" PostToolUseFailure
rid; jq -nc --arg s "$SID" --arg id "$RID" --arg tp "$MAIN_TP" \
      '{session_id:$s,transcript_path:$tp,tool_name:"Edit",tool_input:{command:"src/a.ts"},tool_use_id:$id,cwd:"/p"}' \
    | bash "$MUTF" >/dev/null 2>&1; outcome "$RID" PostToolUse
rid; jq -nc --arg s "$SID" --arg id "$RID" --arg tp "$MAIN_TP" \
      '{session_id:$s,transcript_path:$tp,tool_name:"Bash",tool_input:{command:"npm test"},tool_use_id:$id,cwd:"/p"}' \
    | bash "$MUTF" >/dev/null 2>&1; outcome "$RID" PostToolUseFailure
rid; jq -nc --arg s "$SID" --arg id "$RID" --arg tp "$MAIN_TP" \
      '{session_id:$s,transcript_path:$tp,tool_name:"Edit",tool_input:{command:"src/a.ts"},tool_use_id:$id,cwd:"/p"}' \
    | bash "$MUTF" >/dev/null 2>&1; outcome "$RID" PostToolUse
rid; o=$(jq -nc --arg s "$SID" --arg id "$RID" --arg tp "$MAIN_TP" \
      '{session_id:$s,transcript_path:$tp,tool_name:"Bash",tool_input:{command:"npm test"},tool_use_id:$id,cwd:"/p"}' \
    | bash "$MUTF" 2>/dev/null)
check "with the edit filter first, the fix-break cycle is dismissed again" "$o" ""

printf '\n== a DIFFERENT call never counts toward it ==\n'
reset
fire Bash "git status" "$MAIN_TP" >/dev/null
fire Bash "git status" "$MAIN_TP" >/dev/null
o=$(fire Bash "git log" "$MAIN_TP")
check "a different argument is not the same call" "$o" ""
o=$(fire Read "git status" "$MAIN_TP")
check "a different TOOL with the same argument is not either" "$o" ""

printf '\n== STATE qualifier: an intervening write clears it ==\n'
reset
fire Bash "npm test" "$MAIN_TP" >/dev/null
fire Bash "npm test" "$MAIN_TP" >/dev/null
fire Write "src/a.ts" "$MAIN_TP" >/dev/null
o=$(fire Bash "npm test" "$MAIN_TP")
check "re-running a gate after an edit is work, not a loop" "$o" ""

printf '\n== POSITIVE CONTROL: defeat the STATE qualifier, the false positive returns ==\n'
# Same three calls, but the write is replaced by a read -- which changes nothing,
# so the qualifier must NOT clear and the loop must be reported. Without the
# qualifier both cases report, and the test above could not tell them apart.
reset
fire Bash "npm test" "$MAIN_TP" >/dev/null
fire Bash "npm test" "$MAIN_TP" >/dev/null
fire Read "src/a.ts" "$MAIN_TP" >/dev/null
o=$(fire Bash "npm test" "$MAIN_TP")
has "a non-mutating call in between does NOT clear the loop" "$o" '"permissionDecision":"ask"'

printf '\n== the agent comes from the PAYLOAD, not from the transcript path ==\n'
reset
fire Bash "rg needle" "$MAIN_TP" "a1b2c3" "general-purpose" >/dev/null
row=$(cat "$LED")
has "the payload's agent_id is what the row carries" "$row" '"agent_id":"a1b2c3"'
has "  agent_type rides beside it" "$row" '"agent_type":"general-purpose"'
has "  and the pointer names the subagent's own file" "$row" \
    "\"transcript\":\"/tmp/proj/${SID}/subagents/agent-a1b2c3.jsonl\""
reset
fire Bash "rg needle" "$MAIN_TP" "a1b2c3" >/dev/null
check "an absent agent_type takes the file's absent-field convention" \
      "$(jq -r '.agent_type' < "$LED")" "-"
reset
fire Bash "rg needle" "" "a1b2c3" >/dev/null
check "with no transcript_path there is no pointer to derive" \
      "$(jq -r '.transcript' < "$LED")" "-"

printf '\n== AC6: the pointer is stored without being stat-ed ==\n'
# At PreToolUse the subagent's transcript may not be on disk yet -- the first
# call in a subagent precedes the file. Storing the pointer anyway is the
# decision; a [ -f ] guard here would store a knowingly-wrong path instead.
reset
fire Bash "rg needle" "$MAIN_TP" "notyet1" >/dev/null
derived=$(jq -r '.transcript' < "$LED")
check "the derived pointer is stored" "$derived" "/tmp/proj/${SID}/subagents/agent-notyet1.jsonl"
check "  with nothing at the other end of it" \
      "$( [ ! -e "$derived" ] && echo absent || echo present )" "absent"

printf '\n== AC5: a subagent-SHAPED transcript_path is not an agent_id ==\n'
# The pre-fix hook read the agent out of this path. In production that path is
# always the PARENT's, so the read never once succeeded -- and a payload of this
# shape, carrying no agent_id, must be recorded as the main thread.
reset
fire Bash "rg needle" "$SUB_TP" >/dev/null
check "no agent_id in the payload -> main" "$(jq -r '.agent_id' < "$LED")" "main"
check "  and the path is stored verbatim, not re-derived" \
      "$(jq -r '.transcript' < "$LED")" "$SUB_TP"

printf '\n== a malformed agent_id degrades to main, and still writes a row ==\n'
# Without the type guard a non-string agent_id aborts the single hot-path jq and
# the hook exits 0 having written NOTHING -- measured against the pre-guard build.
# Both builds exit 0, so the difference is invisible to an exit-status assertion
# and these read the ledger instead.
reset
fire_aid_json Bash "rg needle" '12345' >/dev/null
row=$(cat "$LED" 2>/dev/null)
check "a number is not an agent" "$(printf '%s' "$row" | jq -r '.agent_id' 2>/dev/null)" "main"
check "  the pointer is left alone" "$(printf '%s' "$row" | jq -r '.transcript' 2>/dev/null)" "$MAIN_TP"
check "  and a row was written at all" "$( [ -n "$row" ] && echo yes || echo no )" "yes"
reset
fire_aid_json Bash "rg needle" '["x"]' >/dev/null
row=$(cat "$LED" 2>/dev/null)
check "an array is not either" "$(printf '%s' "$row" | jq -r '.agent_id' 2>/dev/null)" "main"
check "  and that row was written too" "$( [ -n "$row" ] && echo yes || echo no )" "yes"

printf '\n== fan-out: one hash, several agents, is a different finding ==\n'
# Production shape: every payload carries the PARENT's transcript_path, because
# that is what the client sends for a call made inside a subagent. The rows
# differ in agent_id and in nothing else.
reset
fire Bash "rg needle" "$MAIN_TP" "a1" "general-purpose" >/dev/null
fire Bash "rg needle" "$MAIN_TP" "a2" "general-purpose" >/dev/null
o=$(fire Bash "rg needle" "$MAIN_TP" "a3" "general-purpose")
has "three agents, same call -> a decision" "$o" '"permissionDecision":"ask"'
has "  reported as fan-out, not as a loop" "$o" "fan-out duplication"
has "  naming how many agents" "$o" "3 different agents"
check "  and every pointer resolves under the ONE parent transcript" \
      "$(jq -rs "[.[] | select(.kind==\"call\") | .transcript
                  | select(startswith(\"/tmp/proj/${SID}/subagents/agent-\"))] | length" < "$LED")" "3"

printf '\n== agent_id is a FIELD, never part of the key ==\n'
# If agent_id were in the key, the two lines above would not have matched and
# the fan-out case could not exist at all. Assert the ledger distinguishes them.
reset
fire Bash "rg needle" "$MAIN_TP" "a1" >/dev/null
fire Bash "rg needle" "$MAIN_TP" "a2" >/dev/null
check "two agents recorded" "$(jq -r '.agent_id' < "$LED" | sort -u | tr '\n' ',' )" "a1,a2,"
check "under ONE fingerprint" "$(jq -r '.fp' < "$LED" | sort -u | wc -l | tr -d ' ')" "1"

printf '\n== the window bounds what is counted ==\n'
reset
fire Bash "same call" "$MAIN_TP" >/dev/null
fire Bash "same call" "$MAIN_TP" >/dev/null
for i in 1 2 3 4 5; do fire Read "filler-$i" "$MAIN_TP" >/dev/null; done
o=$(HARNESS_LOOP_TAIL=4 fire Bash "same call" "$MAIN_TP")
check "repeats older than the window are not counted" "$o" ""
o=$(HARNESS_LOOP_TAIL=50 fire Bash "same call" "$MAIN_TP")
has "  but a wider window still sees them" "$o" '"permissionDecision":"ask"'

printf '\n== the threshold is tunable ==\n'
reset
fire Bash "twice only" "$MAIN_TP" >/dev/null
o=$(HARNESS_LOOP_THRESHOLD=2 fire Bash "twice only" "$MAIN_TP")
has "two calls is a loop at threshold 2" "$o" '"permissionDecision":"ask"'

printf '\n== nothing the hook does can cost the session a tool call ==\n'
reset
check "empty stdin -> 0"          "$(printf '' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON -> 0"       "$(printf '{oh no' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "no session_id -> 0"        "$(printf '{\"tool_name\":\"Bash\"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "  and writes no ledger"    "$( [ -d "$HARNESS_LOOP_DIR" ] && echo some || echo none )" "none"
check "a reported loop still exits 0" \
      "$(reset; fire Bash x "$MAIN_TP" >/dev/null; fire Bash x "$MAIN_TP" >/dev/null;
         jq -nc --arg s "$SID" --arg tp "$MAIN_TP" \
           '{session_id:$s,transcript_path:$tp,tool_name:"Bash",tool_input:{command:"x"}}' \
         | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "an unwritable ledger dir -> 0, silently" \
      "$(HARNESS_LOOP_DIR=/proc/nope/loops fire Bash y "$MAIN_TP" >/dev/null 2>&1; echo $?)" "0"

printf '\n== it is wired into hooks.json as a PreToolUse hook for every tool ==\n'
wired=$(jq -r '[.hooks.PreToolUse[] | select(.matcher == "*") | .hooks[]
                | select(.command | test("loop-index.sh"))] | length' "$HOOKS_JSON")
check "registered under matcher *" "$wired" "1"
check "and it is NOT guarded -- a loop is never project-specific" \
      "$(jq -r '[.hooks.PreToolUse[] | .hooks[] | select(.command | test("loop-index.sh"))
                 | select(.command | test("harness-managed"))] | length' "$HOOKS_JSON")" "0"
check "the entry point the hook invokes by full path is executable" \
      "$( [ -x "$HOOK" ] && echo yes || echo no )" "yes"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
