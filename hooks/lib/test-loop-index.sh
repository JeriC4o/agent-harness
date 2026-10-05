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
WRAP="${HERE}/loop-window-prefix.sh"
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

# A working copy of the shipped tree at a DIFFERENT absolute path. loop-index.sh
# resolves scripts/bin-of.jq AND loop-window.awk from $0, so the SHAPE has to
# come along: a bare copy of the one script resolves neither, its single jq
# fails, and it exits 0 having written nothing -- silent for a reason that has
# nothing to do with whatever the case was testing. Measured: the pre-extraction
# mutation control below copied the hook alone and was vacuous for exactly that
# reason.
relocate() { # $1 destination root
  mkdir -p "$1/hooks/lib" "$1/scripts" || return 1
  cp "${HERE}"/*.sh "${HERE}"/*.awk "$1/hooks/lib/" || return 1
  cp "${HERE}/../../scripts/bin-of.jq" "$1/scripts/" || return 1
  chmod +x "$1/hooks/lib/loop-index.sh"
}
# Fire an arbitrary copy of the hook. $1 hook path, $2 tool, $3 command.
fire_at() {
  jq -nc --arg s "$SID" --arg t "$2" --arg c "$3" --arg tp "$MAIN_TP" --arg id "${4:-toolu_x}" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:$t, tool_input:{command:$c}, tool_use_id:$id, cwd:"/p"}' \
  | bash "$1" 2>/dev/null
}

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
# THE MODAL FIRING, and the one that catches a span defined over prior calls
# alone: two prior repeats plus this one is three calls, and "3 times within the
# last 2 calls" is not true of anything.
has "  within a span the count fits inside" "$o3" "within the last 3 calls"
# The call being reported has NOT run -- it was interrupted at dispatch -- so
# the message says outright which calls its numbers count, rather than leaving
# the reader to infer it from two bare integers.
has "  and it says which calls those numbers count" "$o3" \
    "(both numbers counting this call, which has not run yet)"
# THE NOUN IS PINNED, not just the digits. "steps" is the word that carried the
# original falsehood -- the message said "in the last 20 steps" while the number
# counted ledger LINES -- so a drift back to it is a regression even when the
# number is right, and a reader of the old noun cannot tell lines from calls
# from model turns. Asserted on all three arms, which must agree.
hasnt "  and never says steps, the noun that hid the unit" "$o3" "steps"
e3=$(fire_err Bash "git status" "$MAIN_TP")
has "  the stderr half carries it too" "$e3" "[loop-index] loop"

printf '\n== five record classes, and the reader must filter on kind ==\n'
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
# `window` is the REQUESTED setting, and after GH-86 that number means calls in
# new rows and lines in old ones with nothing in the number to separate them.
# A reader that assumes one unit silently mis-reads half the corpus.
check "  with the unit it was counted in, because the meaning changed" \
      "$(printf '%s' "$v" | jq -r '.window_unit')" "calls"
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
# 4 prior calls are in the ledger, not the 20 that were requested. Quoting 20
# here would be defect 1 relocated into the sentence the agent actually reads.
# 4 prior calls plus this one is 5 calls of judgement, not the 20 requested.
has "  quoting the span it COUNTED, not the window it asked for" "$o" "in the last 5 calls"
hasnt "  so the requested 20 never reaches the agent"            "$o" "in the last 20 calls"
# THE ASYMMETRY, and the reason the parenthetical is not uniform across arms.
# This arm's count is `fails` -- recorded error outcomes, every one of them
# PRIOR, because a call that has not run cannot have failed. The span still
# counts the interrupted call. A blanket "including the current one" here would
# be false, so this arm gets wording of its own.
has "  naming the failures as PRIOR, since this call has not run" "$o" \
    "(the failures are all prior; this call has not run yet, though the call count includes it)"
# The substantive negative: 2 results were recorded as errors, so 3 would mean
# the arm had folded the interrupted call into its own failure count.
hasnt "  and it never counts the interrupted call among the failures" "$o" "FAILED 3 times"
hasnt "  nor borrows the other arms' blanket clause"                  "$o" "numbers counting this call"
hasnt "  nor the fanout one"                                          "$o" "all three numbers including this call"
hasnt "  and it counts in calls, never in steps"                      "$o" "steps"
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
#
# The mutation lands in loop-window.awk, where the program now lives, and the
# whole tree is relocated so the mutated copy still resolves its own detector
# and bin-of.jq. BOTH arms are asserted, because "silent" is the cheapest thing
# in this file to get for free: a copy that cannot resolve its siblings is also
# silent, and the version of this control that copied the hook alone passed for
# that reason rather than for the mutation's.
fixbreak() { # $1 hook path -- test, edit, test, edit, test; echoes the 5th
  reset
  rid; fire_at "$1" Bash "npm test"  "$RID" >/dev/null; outcome "$RID" PostToolUseFailure
  rid; fire_at "$1" Edit "src/a.ts"  "$RID" >/dev/null; outcome "$RID" PostToolUse
  rid; fire_at "$1" Bash "npm test"  "$RID" >/dev/null; outcome "$RID" PostToolUseFailure
  rid; fire_at "$1" Edit "src/a.ts"  "$RID" >/dev/null; outcome "$RID" PostToolUse
  rid; fire_at "$1" Bash "npm test"  "$RID"
}
# Which of the two tests comes FIRST is the mutation; both strings are present
# either way, so a grep for one of them cannot tell the builds apart -- and the
# pre-extraction spelling of this check was a grep for one of them.
order() { awk '/if \(changed > [a-z]+\) exit/ {c=NR} /if \(fails \+ 0 >= retry\)/ {r=NR}
               END { print (c < r) ? "edit-first" : "retry-first" }' "$1"; }

MUTT="${WORK}/mut-editfilter"
relocate "$MUTT"
MUTF="${MUTT}/hooks/lib/loop-index.sh"
MUTAWK="${MUTT}/hooks/lib/loop-window.awk"
check "the relocated copy starts out unmutated" "$(order "$MUTAWK")" "retry-first"
o=$(fixbreak "$MUTF")
has "  and fires, so the tree it resolves from is intact" "$o" "already FAILED 2 times"

# Swap the retry block with everything up to and including the dismissal, and
# quote the body of neither. A mutation spelled as a literal of the code it
# edits stops applying the next time that code is touched for an unrelated
# reason, and a mutation that does not apply makes this control measure the
# UNMUTATED build -- which is why `order()` above asserts the swap landed
# instead of grepping for a string both builds contain. Group 2 is deliberately
# "whatever lies between", because the dismissal's own set-up lines and comments
# have to travel with it or `anchor` is unset where it is read.
perl -0pi -e 's/(^[ ]{6}if \(fails \+ 0 >= retry\) \{\n(?:.*\n)*?[ ]{6}\}\n)((?:.*\n)*?[ ]{6}if \(changed > [a-z]+\) exit\n)/$2$1/m' "$MUTAWK"
check "the mutation applied" "$(order "$MUTAWK")" "edit-first"
o=$(fixbreak "$MUTF")
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
# The span includes the call being judged, so the count can never exceed it.
# Without that, this very case reads "3 times in the last 2 calls".
has "  and a span the count fits inside" "$o" "3 times in the last 3 calls"
# Three numbers on this arm, and the current call is in every one: na counts
# `cur`, count is n + 1, span is prior + 1. The clause has to say so for all
# three, not for the two in the parenthesis.
has "  declaring the convention for all three numbers" "$o" \
    "all three numbers including this call, which has not run yet"
hasnt "  in calls, the same noun the other two arms use" "$o" "steps"
# AC14. The old closing line told a sibling subagent to "check whether one
# result can be reused" -- an action it has no handle on, in its own context,
# with no access to another agent's result. The replacement names two it does
# have. The arm stays an `ask`: fanout is not a quieter signal than loop.
hasnt "  and no longer advises an action its reader cannot take" "$o" "one result can be reused"
has "  it says to narrow the call instead"   "$o" "narrow this call to the part your own task needs"
has "  or to report it upwards if it cannot" "$o" "so the parent can stop re-issuing it"
has "  and the arm is still an ask"          "$o" '"permissionDecision":"ask"'
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

printf '\n== the window counts CALLS, and most of the ledger is not calls ==\n'
# TC11, the production shape: loop-result.sh writes a result row per call, so a
# 20-LINE tail was 20 steps when the ledger carried calls only and is roughly 8
# now. The window section above cannot see this -- it has no result rows, where
# lines and calls are the same number and every unit agrees.
reset
rid; rcall Bash "same call" >/dev/null; outcome "$RID" PostToolUse
rid; rcall Bash "same call" >/dev/null; outcome "$RID" PostToolUse
for i in 1 2 3 4 5; do rid; rcall Read "filler-$i" >/dev/null; outcome "$RID" PostToolUse; done
check "7 calls in the ledger" "$(grep -c '"kind":"call"' "$LED")" "7"
check "  spread over 14 lines" "$(wc -l < "$LED" | tr -d ' ')" "14"
WANTFP=$(jq -r 'select(.kind=="call" and .tool=="Bash") | .fp' < "$LED" | head -1)
cp "$LED" "${WORK}/interleaved.jsonl"
rid; o=$(HARNESS_LOOP_TAIL=7 rcall Bash "same call")
has "a 7-CALL window reaches both repeats" "$o" '"permissionDecision":"ask"'
# POSITIVE CONTROL. The frozen pre-fix pair, fed the SAME ledger at the SAME K
# but in LINES, sees the last 7 lines -- which hold no matching call at all.
# That silence IS defect 1, and it is why the control is this wrapper and not a
# restored `tail -n` (the awk is call-bounded now, so a narrow chunk would just
# emit RETRY and the shell would widen back to the right answer).
check "POSITIVE CONTROL: at K = 7 LINES the frozen pair sees no repeat" \
      "$("$WRAP" 7 "${WORK}/interleaved.jsonl" "$WANTFP" Bash)" ""
# Three fields, not four: the frozen pair predates the counted span and must
# never grow it. A fourth field here would mean someone updated the control.
check "  and it is not silent for want of a working control -- 14 lines reach both" \
      "$("$WRAP" 14 "${WORK}/interleaved.jsonl" "$WANTFP" Bash)" "loop 3 1"

printf '\n== a chunk too narrow to hold the window is widened, not guessed at ==\n'
# The chunk is TAIL_N * 3 lines, sized from the measured 1.04 .. 2.37 ratio. A
# turn-heavy session breaks that hint, and awk can tell "I ran out of FILE" from
# "I ran out of CHUNK" -- NR < chunk against NR == chunk -- so it says RETRY and
# the shell doubles, rather than reporting a short count as the whole window.
# Seeded with the hook's OWN fingerprint for the payload fired below, because a
# hand-written fp would match nothing and every case here would pass vacuously.
reset
fire Bash "turn heavy" "$MAIN_TP" >/dev/null
HEAVY_FP=$(jq -r '.fp' < "$LED")
seed_turn_heavy() { # 5 calls, 4 turn rows after each: 25 lines, calls at 1/6/11/16/21
  mkdir -p "$HARNESS_LOOP_DIR"
  { for c in 1 2 3 4 5; do
      if [ "$c" -le 2 ]; then
        printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"%s","tool_use_id":"m%s"}\n' "$HEAVY_FP" "$c"
      else
        printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Read","fp":"filler%s","tool_use_id":"f%s"}\n' "$c" "$c"
      fi
      for _ in 1 2 3 4; do printf '%s\n' '{"ts":"t","kind":"turn"}'; done
    done; } > "$LED"
}
reset; seed_turn_heavy
check "25 lines carrying 5 calls" \
      "$(printf '%s/%s' "$(wc -l < "$LED" | tr -d ' ')" "$(grep -c '"kind":"call"' "$LED")")" "25/5"
check "  and the first chunk at TAIL_N=5 is 15 lines, holding only 3 of them" \
      "$(tail -n 15 "$LED" | grep -c '"kind":"call"')" "3"
o=$(HARNESS_LOOP_TAIL=5 fire Bash "turn heavy" "$MAIN_TP")
has "the hook widens and finds both repeats anyway" "$o" '"permissionDecision":"ask"'
has "  reporting all three occurrences" "$o" "3 times"

printf '\n== POSITIVE CONTROL: delete the RETRY branch, the short chunk answers short ==\n'
# Without it the detector reports whatever the first chunk happened to hold --
# here three Read calls and no repeat. A silent miss whose size depends on how
# many turn rows the session logged, which is defect 1 wearing a new hat.
NORETRY="${WORK}/no-retry"
relocate "$NORETRY"
perl -0pi -e 's/^[ ]{6}if \(calls < want_calls && NR == chunk\) \{ print "RETRY"; exit \}\n//m' \
     "${NORETRY}/hooks/lib/loop-window.awk"
check "the mutation applied" \
      "$(grep -c 'print "RETRY"' "${NORETRY}/hooks/lib/loop-window.awk")" "0"
reset; seed_turn_heavy
o=$(HARNESS_LOOP_TAIL=5 fire_at "${NORETRY}/hooks/lib/loop-index.sh" Bash "turn heavy")
check "with no retry the same ledger reports nothing at all" "$o" ""

printf '\n== the dismissal is anchored on the evidence that would FIRE ==\n'
# 15 rows, ALL of them calls: a filler, an old match, a mutation, 10 fillers,
# then a tight cluster of two recent matches. Every row being a call is the
# point -- lines and calls are the same number here, so this fixture isolates
# the ANCHOR from the UNIT, and the unit change cannot be what makes it pass.
#
# Anchored on the OLDEST match, widening the window past row 2 drags the anchor
# back behind the mutation at row 3 and the detector goes silent: a wider window
# finds LESS. That is the defect, and it is the only shape here that breaks the
# pre-fix rule at a width anyone would type. The narrow sweeps prove nothing --
# over K = 1..80 on the real ledger the pre-fix rule scores zero violations too.
reset
fire Bash "anchored" "$MAIN_TP" >/dev/null
ANCH_FP=$(jq -r '.fp' < "$LED")
seed_anchor15() {
  mkdir -p "$HARNESS_LOOP_DIR"
  { for i in $(seq 1 15); do
      case $i in
        2|14|15) printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"%s","tool_use_id":"m%s"}\n' "$ANCH_FP" "$i" ;;
              3) printf '%s\n' '{"ts":"t","kind":"call","agent_id":"main","tool":"Edit","fp":"e1","tool_use_id":"e3"}' ;;
              *) printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Read","fp":"f%s","tool_use_id":"r%s"}\n' "$i" "$i" ;;
      esac
    done; } > "$LED"
}
reset; seed_anchor15
cp "$LED" "${WORK}/anchor15.jsonl"
check "15 rows, every one of them a call" \
      "$(printf '%s/%s' "$(wc -l < "$LED" | tr -d ' ')" "$(grep -c '"kind":"call"' "$LED")")" "15/15"
check "  three of them matching, with the mutation after the oldest" \
      "$(grep -c "\"fp\":\"${ANCH_FP}\"" "$LED")" "3"

# 1 where the window fires, 0 where it is silent, read left to right over
# widening K. Monotonicity is the property: a wider window may only find MORE.
sweep() { # $1: fixed | frozen
  out=""
  for K in 3 5 10 13 14 15; do
    if [ "$1" = frozen ]; then
      r=$("$WRAP" "$K" "${WORK}/anchor15.jsonl" "$ANCH_FP" Bash)
    else
      reset; mkdir -p "$HARNESS_LOOP_DIR"; cp "${WORK}/anchor15.jsonl" "$LED"
      r=$(HARNESS_LOOP_TAIL="$K" fire Bash "anchored" "$MAIN_TP")
    fi
    out="${out}$( [ -n "$r" ] && printf 1 || printf 0 )"
  done
  printf '%s' "$out"
}
check "firing is non-decreasing as the window widens (K = 3/5/10/13/14/15)" \
      "$(sweep fixed)" "111111"
check "POSITIVE CONTROL: the pre-fix pair goes SILENT at K = 14 and again at 15" \
      "$(sweep frozen)" "111100"
reset; mkdir -p "$HARNESS_LOOP_DIR"; cp "${WORK}/anchor15.jsonl" "$LED"
o=$(fire Bash "anchored" "$MAIN_TP")
has "at the shipped default the loop is reported" "$o" '"permissionDecision":"ask"'
has "  counting all four occurrences" "$o" "4 times"
has "  over the 15 calls that existed plus this one, not the 20 requested" "$o" "last 16 calls"

printf '\n== the near-miss: a mutation INSIDE the recent cluster still dismisses ==\n'
# The anchor was re-anchored, not removed. Move the mutation between the two
# repeats that would fire and the dismissal is correct again -- both rules agree,
# which is what keeps this a qualifier rather than a deletion.
reset; mkdir -p "$HARNESS_LOOP_DIR"
{ printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"%s","tool_use_id":"m1"}\n' "$ANCH_FP"
  printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"%s","tool_use_id":"m2"}\n' "$ANCH_FP"
  printf '%s\n' '{"ts":"t","kind":"call","agent_id":"main","tool":"Edit","fp":"e1","tool_use_id":"e3"}'
  printf '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"%s","tool_use_id":"m4"}\n' "$ANCH_FP"
} > "$LED"
cp "$LED" "${WORK}/anchor-inside.jsonl"
o=$(fire Bash "anchored" "$MAIN_TP")
check "a write after the second-most-recent match dismisses it" "$o" ""
check "  and the pre-fix pair agrees, so the rules differ only where the defect was" \
      "$("$WRAP" 4 "${WORK}/anchor-inside.jsonl" "$ANCH_FP" Bash)" ""

printf '\n== the threshold is tunable ==\n'
reset
fire Bash "twice only" "$MAIN_TP" >/dev/null
o=$(HARNESS_LOOP_THRESHOLD=2 fire Bash "twice only" "$MAIN_TP")
has "two calls is a loop at threshold 2" "$o" '"permissionDecision":"ask"'

printf '\n== the detector is a FILE, and that is a dependency with its own failures ==\n'
# `bash -n` and shellcheck both skip *.awk, so an unparseable detector reaches
# production unless something here parses it. These two cases ARE that gate.
AWK_LIVE="${HERE}/loop-window.awk"
AWK_FROZEN="${HERE}/loop-window-prefix.awk"
check "loop-window.awk parses" \
      "$(awk -f "$AWK_LIVE" -v want_fp=x -v want_tool=y -v thr=3 -v retry=2 -v cur=main \
           </dev/null >/dev/null 2>&1; echo $?)" "0"
check "loop-window-prefix.awk parses too" \
      "$(awk -f "$AWK_FROZEN" -v want_fp=x -v want_tool=y -v thr=3 -v retry=2 -v cur=main \
           </dev/null >/dev/null 2>&1; echo $?)" "0"

# A missing detector costs the VERDICT and must cost nothing else. If the append
# went with it, the window a later call reads would be missing rows too, so one
# unreadable file would degrade the index itself rather than just this call.
GONE="${WORK}/no-detector"
relocate "$GONE"
mv "${GONE}/hooks/lib/loop-window.awk" "${GONE}/hooks/lib/loop-window.awk.bak"
reset
fire_at "${GONE}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null
fire_at "${GONE}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null
o=$(fire_at "${GONE}/hooks/lib/loop-index.sh" Bash "git status")
rc=$(fire_at "${GONE}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null 2>&1; echo $?)
check "with the detector renamed away, no verdict is emitted" "$o" ""
check "  the exit status is still 0"     "$rc" "0"
check "  and every call still wrote its row" "$(wc -l < "$LED" | tr -d ' ')" "4"

# $0-resolution, which is the risk the move introduces: the plugin installs to a
# variable path, so a detector found only at the development path is a detector
# that is absent everywhere it ships.
RELOC="${WORK}/reloc"
relocate "$RELOC"
reset
fire_at "${RELOC}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null
fire_at "${RELOC}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null
o=$(fire_at "${RELOC}/hooks/lib/loop-index.sh" Bash "git status")
has "run from a relocated tree, it still finds its detector" "$o" '"permissionDecision":"ask"'

# A detector OLDER than this caller emits three fields, not four. Read bare,
# `set -u` turns that into an abort -- the ledger row is already written, but
# the agent gets a bash error instead of a verdict and the hook exits non-zero.
# The contract is that no failure path costs the session a tool call, so the
# three-field case degrades to the requested window and stays quiet.
LEGACY="${WORK}/legacy-detector"
relocate "$LEGACY"
cp "${HERE}/loop-window-prefix.awk" "${LEGACY}/hooks/lib/loop-window.awk"
reset
fire_at "${LEGACY}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null
fire_at "${LEGACY}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null
o=$(fire_at "${LEGACY}/hooks/lib/loop-index.sh" Bash "git status")
rc=$(fire_at "${LEGACY}/hooks/lib/loop-index.sh" Bash "git status" >/dev/null 2>&1; echo $?)
has "a three-field detector still produces a verdict" "$o" '"permissionDecision":"ask"'
has "  falling back to the requested window" "$o" "within the last 20 calls"
check "  at exit status 0" "$rc" "0"

printf '\n== the frozen control is TWO halves, and the wrapper carries the other one ==\n'
# loop-window-prefix.awk holds only the dismissal rule. The pre-fix WINDOW was
# `tail -n "$TAIL_N"` in the shell -- LINES. This ledger has 6 lines and 2
# matching calls, so the two units disagree about every K between them, and that
# disagreement is the whole assertion: at K = 4 a LINE window sees four result
# rows and nothing else, while a CALL window would see both calls and fire.
PRELED="${WORK}/prefix.jsonl"
{ printf '%s\n' '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"111","tool_use_id":"t1"}'
  printf '%s\n' '{"ts":"t","kind":"call","agent_id":"main","tool":"Bash","fp":"111","tool_use_id":"t2"}'
  printf '%s\n' '{"ts":"t","kind":"result","tool_use_id":"t1","ok":true}'
  printf '%s\n' '{"ts":"t","kind":"result","tool_use_id":"t2","ok":true}'
  printf '%s\n' '{"ts":"t","kind":"result","tool_use_id":"t3","ok":true}'
  printf '%s\n' '{"ts":"t","kind":"result","tool_use_id":"t4","ok":true}'
} > "$PRELED"
check "the fixture is 6 lines" "$(wc -l < "$PRELED" | tr -d ' ')" "6"
check "  carrying 2 parsed call rows" \
      "$(grep -c '"kind":"call"' "$PRELED")" "2"
check "K is in LINES: at 4 the window holds no call at all" \
      "$("$WRAP" 4 "$PRELED" 111 Bash)" ""
check "  at 6 it reaches both and fires" \
      "$("$WRAP" 6 "$PRELED" 111 Bash)" "loop 3 1"
check "  and unbounded is spelled as a word, because tail -n 0 prints nothing" \
      "$("$WRAP" unbounded "$PRELED" 111 Bash)" "loop 3 1"
check "the wrapper is executable, since that is how the suites invoke it" \
      "$( [ -x "$WRAP" ] && echo yes || echo no )" "yes"

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
# WAS: `an unwritable ledger dir -> 0, silently`, asserting the exit code with
# both streams sent to /dev/null. The word "silently" in that name was checked
# by NOTHING, and the hook was in fact neither silent nor loud -- it leaked a
# raw shell error on every call. Same vacuous shape Group A found and repaired
# in the edit-filter control: a name that claims more than the assertion makes.
#
# An unwritable ledger is not an ordinary swallowed failure. It DISABLES tier 1
# and tier 2 for the whole session while every tool call still succeeds, so the
# hook says so once -- on stderr, at rc 0, never as a permissionDecision.
printf '\n== an unwritable ledger is REPORTED once, not swallowed and not repeated ==\n'
UW="${WORK}/unwritable"
mkdir -p "$UW"
chmod 500 "$UW"
UWTMP="${WORK}/uwtmp"; mkdir -p "$UWTMP"
if [ -w "$UW" ]; then
  bad "precondition: a chmod 500 ledger dir is still writable here, so this case cannot run"
else
  ok "precondition: the ledger dir really is unwritable"
  uw_fire() { # -> rc in UWRC, stderr in $WORK/uwerr
    UWRC=0
    jq -nc --arg s "uw-session" --arg tp "$MAIN_TP" \
       '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
         tool_name:"Bash", tool_input:{command:"y"}, tool_use_id:"toolu_uw"}' \
      | HARNESS_LOOP_DIR="${UW}/loops" TMPDIR="$UWTMP" bash "$HOOK" \
        > "${WORK}/uwout" 2> "${WORK}/uwerr" || UWRC=$?
  }
  uw_fire
  check "it still exits 0 -- a broken ledger must never cost a tool call" "$UWRC" "0"
  check "  and writes nothing to stdout, which is the protocol channel" \
        "$(wc -c < "${WORK}/uwout" | tr -d ' ')" "0"
  uwerr=$(cat "${WORK}/uwerr")
  has "it names the consequence rather than the errno" "$uwerr" "LOOP DETECTION IS DISABLED"
  has "  and tells the reader a quiet run proves nothing" "$uwerr" "not evidence that nothing looped"
  case "$uwerr" in
    *"ermission denied"*) bad "the raw shell error still leaks beside the sentence" ;;
    *)                    ok "no raw shell error leaks beside it" ;;
  esac
  # THE SECOND CALL IS A SEPARATE PROCESS. That is the whole reason the marker
  # is a file, and asserting it inside one shell would measure nothing.
  uw_fire
  check "the SECOND call -- a different process -- exits 0 too" "$UWRC" "0"
  check "  and is silent, so the warning does not repeat for the rest of the session" \
        "$(wc -c < "${WORK}/uwerr" | tr -d ' ')" "0"
fi
chmod 700 "$UW"

printf '\n== it is wired into hooks.json as a PreToolUse hook for every tool ==\n'
wired=$(jq -r '[.hooks.PreToolUse[] | select(.matcher == "*") | .hooks[]
                | select(.command | test("loop-index.sh"))] | length' "$HOOKS_JSON")
check "registered under matcher *" "$wired" "1"
check "and it is NOT guarded -- a loop is never project-specific" \
      "$(jq -r '[.hooks.PreToolUse[] | .hooks[] | select(.command | test("loop-index.sh"))
                 | select(.command | test("harness-managed"))] | length' "$HOOKS_JSON")" "0"
check "the entry point the hook invokes by full path is executable" \
      "$( [ -x "$HOOK" ] && echo yes || echo no )" "yes"
# The frozen control must stay out of the live path. Wired in, it would be a
# second detector running the pre-fix rule beside the fixed one.
check "no hook names the frozen pre-fix control" \
      "$(grep -c 'loop-window-prefix' "$HOOKS_JSON")" "0"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
