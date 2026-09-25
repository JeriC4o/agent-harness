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

# Fire the hook once. $1 tool, $2 command/arg payload, $3 transcript path.
fire() {
  jq -nc --arg s "$SID" --arg t "$1" --arg c "$2" --arg tp "$3" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:$t, tool_input:{command:$c}, tool_use_id:"toolu_x"}' \
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

printf '\n== fan-out: one hash, several agents, is a different finding ==\n'
reset
fire Bash "rg needle" "$MAIN_TP" >/dev/null
fire Bash "rg needle" "$SUB_TP" >/dev/null
o=$(fire Bash "rg needle" "/tmp/proj/${SID}/subagents/agent-zzz999.jsonl")
has "three agents, same call -> a decision" "$o" '"permissionDecision":"ask"'
has "  reported as fan-out, not as a loop" "$o" "fan-out duplication"
has "  naming how many agents" "$o" "3 different agents"

printf '\n== agent_id is a FIELD, never part of the key ==\n'
# If agent_id were in the key, the two lines above would not have matched and
# the fan-out case could not exist at all. Assert the ledger distinguishes them.
reset
fire Bash "rg needle" "$MAIN_TP" >/dev/null
fire Bash "rg needle" "$SUB_TP" >/dev/null
check "two agents recorded" "$(jq -r '.agent_id' < "$LED" | sort -u | tr '\n' ',' )" "abc123,main,"
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
