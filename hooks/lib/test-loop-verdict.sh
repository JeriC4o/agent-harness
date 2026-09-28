#!/usr/bin/env bash
#
# Tests for loop-verdict.sh -- the COARSE stage of the cascade (GH-62, GH-67).
#   bash hooks/lib/test-loop-verdict.sh
#
# The ledger here is produced by RUNNING loop-index.sh, not hand-written. A
# hand-written fixture is how the previous suite stayed green while the reader
# counted a record shape the writer had stopped emitting: the fixture agreed with
# the test's idea of the format, and nothing compared that idea to production.
#
# The model is stubbed by putting a fake `claude` first on PATH. It is OFF by
# default, so most of this file asserts that it is never called.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
HOOK="${HERE}/loop-verdict.sh"
IDX="${HERE}/loop-index.sh"
HOOKS_JSON="${HERE}/../hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
export HARNESS_LOOP_DIR="${WORK}/loops"
# PINNED, NOT INHERITED. Every assertion below that requires the judging stage to
# stay quiet was relying on this variable being absent from the environment --
# which it is on a machine where the cascade was never switched on, and is NOT on
# a machine where it was. The suite then went red for a setting rather than for
# the code, and it did so in the section about the coarse gate, which says
# nothing about the model. A gate whose verdict moves with the developer's
# settings is not a gate. The shipped DEFAULT is still checked, once, explicitly,
# with the variable genuinely removed -- see the section at the end.
export HARNESS_T3_MODEL=off
mkdir -p "$WORK/bin"
SID="sess-t2"
LED="${HARNESS_LOOP_DIR}/${SID}.jsonl"
TP="${WORK}/${SID}.jsonl"

cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat > "${STUB_SEEN:-/dev/null}"
printf 'called\n' >> "${STUB_CALLS:-/dev/null}"
printf '%s\n' "${STUB_ANSWER:-CIRCLING it keeps re-running the same search}"
STUB
chmod +x "$WORK/bin/claude"
export PATH="$WORK/bin:$PATH"
export STUB_CALLS="${WORK}/claude-calls"

reset() { rm -rf "$HARNESS_LOOP_DIR"; mkdir -p "$HARNESS_LOOP_DIR"; : > "$TP"; : > "$STUB_CALLS"; }

# A real call, through the real tier-1 hook, so `bin` is derived in production.
CALLN=0
call() { # $1 command
  # ONE id for both sides. The ledger stores a pointer and the transcript holds
  # the detail; if the two ids differ the resolution silently finds nothing, and
  # every model-stage assertion then fails for a fixture reason rather than a
  # code one.
  CALLN=$((CALLN+1)); id="tu$CALLN"
  jq -nc --arg s "$SID" --arg c "$1" --arg tp "$TP" --arg id "$id" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:"Bash", tool_input:{command:$c}, tool_use_id:$id, cwd:"/p"}' \
  | bash "$IDX" >/dev/null 2>&1
  jq -nc --arg a "$1" --arg id "$id" \
     '{message:{content:[{type:"tool_use", id:$id, input:{command:$a}}]}}' >> "$TP"
}
stop()     { jq -nc --arg s "$SID" '{session_id:$s,hook_event_name:"Stop"}' | bash "$HOOK" 2>/dev/null; }
stop_err() { jq -nc --arg s "$SID" '{session_id:$s,hook_event_name:"Stop"}' | bash "$HOOK" 2>&1 >/dev/null; }
v2()   { jq -rs '[.[]|select(.kind=="verdict" and .tier==2)]|length' < "$LED"; }
v3()   { jq -rs '[.[]|select(.kind=="verdict" and .tier==3)]|length' < "$LED"; }
turns(){ jq -rs '[.[]|select(.kind=="turn")]|length' < "$LED"; }
calls(){ wc -l < "$STUB_CALLS" | tr -d ' '; }
n_of() { for i in $(seq 1 "$1"); do call "$2 arg$i"; done; }

printf '\n== every Stop marks the turn, whether or not anything fired ==\n'
reset; n_of 3 "grep -rn"
stop >/dev/null
check "a quiet Stop still writes a marker" "$(turns)" "1"
check "  and no verdict"                   "$(v2)" "0"
stop >/dev/null
check "two Stops, two markers"             "$(turns)" "2"

printf '\n== under the threshold, silent ==\n'
reset; n_of 7 "grep -rn"
out=$(stop); check "7 repeats of one bin is not 8" "$out" ""
check "  nothing recorded"                  "$(v2)" "0"

printf '\n== at the threshold, the coarse gate fires ==\n'
reset; n_of 8 "grep -rn"
stop >/dev/null
check "8 repeats fires" "$(v2)" "1"
v=$(jq -c 'select(.kind=="verdict" and .tier==2)' < "$LED")
check "  signal"        "$(printf '%s' "$v" | jq -r '.signal')"          "coarse-repeat"
check "  the bin"       "$(printf '%s' "$v" | jq -r '.bin')"             "grep"
check "  repeats"       "$(printf '%s' "$v" | jq -r '.repeats')"         "8"
check "  the scope"     "$(printf '%s' "$v" | jq -r '.scope')"           "turn"
check "  the threshold it fired under" "$(printf '%s' "$v" | jq -r '.min_bin_repeats')" "8"
check "  and that the model did NOT judge" "$(printf '%s' "$v" | jq -r '.judged')" "false"
check "the model was never called"         "$(calls)" "0"

printf '\n== THE DISCRIMINATION THE OLD GATE LACKED ==\n'
# The previous gate counted distinct fingerprints and required one tool to
# dominate. Measured on a real session it fired on healthy work every time,
# because both circling AND ordinary varied work are "all fingerprints distinct"
# in a shell-driven project where one tool is 98% of calls. These three cases
# have the SAME call count and the same distinctness; only the shape differs.
reset; for c in "ls a" "cat b" "wc c" "sed -i x d" "jq . e" "git status" "rg f" "python3 g"; do call "$c"; done
out=$(stop); check "8 calls of 8 DIFFERENT shapes is not a finding" "$out" ""
check "  and nothing recorded"                                     "$(v2)" "0"
reset; n_of 8 "grep -rn"
stop >/dev/null
check "8 calls of ONE shape is" "$(v2)" "1"

printf '\n== the turn is the frame: repeats do not cross it ==\n'
reset; n_of 5 "grep -rn"; stop >/dev/null; n_of 5 "grep -rn"
out=$(stop)
check "5 + 5 across two turns does not reach 8" "$out" ""
check "  no verdict"                            "$(v2)" "0"
check "  but both turns are marked"             "$(turns)" "2"

printf '\n== POSITIVE CONTROL: drop the turn reset, the frames merge ==\n'
MUT="${WORK}/mut-turn.sh"
perl -0pe 's/if \(k == "turn"\) \{ delete c; n = 0; next \}/if (k == "turn") { next }/' "$HOOK" > "$MUT"
check "the mutation applied" "$(grep -c 'delete c; n = 0' "$MUT")" "0"
reset; n_of 5 "grep -rn"
jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT" >/dev/null 2>&1
n_of 5 "grep -rn"
jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT" >/dev/null 2>&1
check "without it, 5 + 5 becomes 10 and fires" "$(v2)" "1"

printf '\n== POSITIVE CONTROL: drop the kind filter, verdicts inflate the gate ==\n'
MUT2="${WORK}/mut-kind.sh"
perl -0pe 's/    if \(k != "call"\) next\n    b = ""/    b = ""/' "$HOOK" > "$MUT2"
check "the mutation applied" "$(grep -c 'if (k != "call") next' "$MUT2")" "1"
# 7 calls -- under the gate -- plus verdict lines carrying the same bin. EACH
# arm gets its own ledger: a Stop writes a turn marker, which resets the count,
# so running the real hook first would leave the mutated arm nothing to count and
# the control would report "not caught" for a reason unrelated to the guard.
seed() { reset; n_of 7 "grep -rn"
         for _ in 1 2; do
           jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:2,bin:"grep"}' >> "$LED"
         done; }
seed; out=$(stop); check "with the filter, 7 calls stay under" "$out" ""
seed; jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT2" >/dev/null 2>&1
check "without it, the verdict lines push it over" "$(v2)" "3"

printf '\n== the model, when switched on ==\n'
reset; n_of 8 "grep -rn"
export HARNESS_T3_MODEL=haiku
export STUB_SEEN="${WORK}/seen"
stop >/dev/null
check "the coarse verdict still lands"  "$(v2)" "1"
check "  and records that it was judged" \
      "$(jq -rs '[.[]|select(.tier==2)][0].judged' < "$LED")" "true"
check "the model was called once"       "$(calls)" "1"
check "a tier-3 verdict is written"     "$(v3)" "1"
t3=$(jq -c 'select(.tier==3)' < "$LED")
check "  the verdict"  "$(printf '%s' "$t3" | jq -r '.verdict')" "circling"
check "  the model"    "$(printf '%s' "$t3" | jq -r '.model')"   "haiku"
has   "  the reason, taken from the FIRST line" "$(printf '%s' "$t3" | jq -r '.reason')" "re-running the same search"
seen=$(cat "$WORK/seen")
has "the prompt carries a resolved argument" "$seen" "arg3"
has "  and the bin"                          "$seen" "grep"

reset; n_of 8 "grep -rn"
STUB_ANSWER="PROGRESS each call searched a different module" stop >/dev/null
check "PROGRESS is recorded, not dropped" "$(v3)" "1"
check "  as progress"                     "$(jq -rs '[.[]|select(.tier==3)][0].verdict' < "$LED")" "progress"
reset; n_of 8 "grep -rn"
STUB_ANSWER="I am not sure" stop >/dev/null
check "an answer that is neither records no tier-3 verdict" "$(v3)" "0"
check "  but the coarse verdict stands"                     "$(v2)" "1"
# Back to off EXPLICITLY. `unset` would hand the rest of the suite back to the
# ambient environment, which is the hazard the preamble exists to close.
export HARNESS_T3_MODEL=off; unset STUB_SEEN

printf '\n== the threshold is tunable ==\n'
reset; n_of 3 "grep -rn"
HARNESS_T2_MIN_BIN=3 stop >/dev/null
check "3 repeats fires at a threshold of 3" "$(v2)" "1"
check "  and the verdict records that 3 was in force" \
      "$(jq -rs '[.[]|select(.tier==2)][0].min_bin_repeats' < "$LED")" "3"

printf '\n== nothing it does can break the turn ==\n'
reset; n_of 8 "grep -rn"
check "a firing still exits 0"  "$(stop >/dev/null 2>&1; echo $?)" "0"
check "empty stdin -> 0"        "$(printf '' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON -> 0"     "$(printf '{nope' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "no session_id -> 0"      "$(printf '{}' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "absent ledger -> 0"      "$(jq -nc '{session_id:"nosuch"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
reset
check "empty ledger -> 0"       "$(stop >/dev/null 2>&1; echo $?)" "0"
reset; n_of 8 "grep -rn"
check "model on but claude absent -> 0" \
      "$(HARNESS_T3_MODEL=haiku PATH=/usr/bin:/bin stop >/dev/null 2>&1; echo $?)" "0"
check "  the coarse verdict is still recorded" "$(v2)" "1"
check "  and no tier-3 verdict is invented"    "$(v3)" "0"

printf '\n== the report reaches the agent ==\n'
reset; n_of 8 "grep -rn"
e=$(stop_err)
has "stderr names the bin"      "$e" "grep"
has "  and the repeat count"    "$e" "8 times"
has "  and says the arguments differed" "$e" "different arguments"

printf '\n== INTEGRATION: the reader parses what this actually writes ==\n'
# The guard against the drift that let the old suite pass: a hand-written fixture
# agrees with the test's idea of the format, never with production.
reset; n_of 8 "grep -rn"; stop >/dev/null
R="${HERE}/../../scripts/loop-metrics.sh"
rep=$(bash "$R" "$LED" --json 2>/dev/null)
check "the reader reads it"            "$( [ -n "$rep" ] && echo yes || echo no )" "yes"
check "  and counts the calls"         "$(printf '%s' "$rep" | jq -r '.totals.calls')" "8"
check "  and the coarse firing"        "$(printf '%s' "$rep" | jq -r '.projects[0].tier2.fired')" "1"
check "  and the turn"                 "$(printf '%s' "$rep" | jq -r '.projects[0].turns')" "1"

printf '\n== the SHIPPED default is off, checked with the variable truly absent ==\n'
# The preamble pins the variable so no assertion depends on the machine. That
# pinning would also hide a change to the hook's own default, so the default is
# asserted here in the one place it can be: with the variable removed outright.
reset; n_of 8 "grep -rn"
env -u HARNESS_T3_MODEL bash "$HOOK" >/dev/null 2>&1 \
  <<<"$(jq -nc --arg s "$SID" '{session_id:$s,hook_event_name:"Stop"}')"
check "with no setting at all, the coarse gate still fires" "$(v2)" "1"
check "  and records that it did NOT judge" \
      "$(jq -rs '[.[]|select(.tier==2)][0].judged' < "$LED")" "false"
check "  and the model was never called"    "$(calls)" "0"

printf '\n== POSITIVE CONTROL: the pin is load-bearing, not decoration ==\n'
# Without the pin the two assertions above read the AMBIENT setting. Set it here
# deliberately and they invert -- which is exactly what a developer with the
# cascade switched on used to get, in a section that says nothing about a model.
reset; n_of 8 "grep -rn"
HARNESS_T3_MODEL=haiku stop >/dev/null
check "with the model on, the same input records judged true" \
      "$(jq -rs '[.[]|select(.tier==2)][0].judged' < "$LED")" "true"
check "  and the model IS called" "$(calls)" "1"

printf '\n== wired into hooks.json on both stop events, unguarded ==\n'
for ev in Stop SubagentStop; do
  n=$(jq -r --arg e "$ev" '[.hooks[$e][]?.hooks[]? | select(.command | test("loop-verdict.sh"))] | length' "$HOOKS_JSON")
  check "registered on $ev" "$n" "1"
done
check "not guarded -- circling is never project-specific" \
      "$(jq -r '[.hooks[][]?.hooks[]? | select(.command | test("loop-verdict.sh"))
                 | select(.command | test("harness-managed"))] | length' "$HOOKS_JSON")" "0"
check "the entry point invoked by full path is executable" \
      "$( [ -x "$HOOK" ] && echo yes || echo no )" "yes"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
