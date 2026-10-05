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
# TMPDIR is redirected into the work tree because the unwritable-ledger report
# records "already said" as a marker there. Left pointing at the real temp dir,
# the first run would leave a marker that silenced every later run of this
# suite -- green, and measuring nothing.
#
# AND IT IS REFRESHED PER CASE, inside reset(), which is the part that was wrong
# the first time. THE ONCE-PER-SESSION MARKER IS AN ADMISSION FILTER KEYED ON
# THE EXACT PROPERTY EVERY ASSERTION ABOUT THE REPORT DEPENDS ON, and it
# persists across processes by design. So a case that asserts "no report" is
# satisfied by a marker any EARLIER case left behind: the negative control below
# passed for that reason, with the marker from the unwritable block still in
# place, and a probe printed `[harness-ledger-warned-sess-t2 ]` at exactly that
# point. The feature introduced to make silent degradation detectable thereby
# built a second way for a test to go silently vacuous -- which is the hazard
# this repo names, arriving from the direction nobody was watching.
#
# A fresh TMPDIR per case is the fix, matching hooks/lib/test-ledger-write.sh's
# `fresh_tmp()` ("so a marker from one case cannot silence the next"). It must
# live in reset() rather than per assertion, because the one case that NEEDS the
# marker to persist -- the second turn, proving the report does not repeat --
# calls no reset between its two runs.
export TMPDIR="${WORK}/tmp"
mkdir -p "$TMPDIR"
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

reset() {
  rm -rf "$HARNESS_LOOP_DIR"; mkdir -p "$HARNESS_LOOP_DIR"; : > "$TP"; : > "$STUB_CALLS"
  # The marker namespace is per case, for the reason above. Clearing the ledger
  # dir is NOT enough: the marker lives in TMPDIR precisely because the ledger
  # directory is the thing that may be unwritable.
  TMPDIR=$(mktemp -d "${WORK}/tmp.XXXXXX"); export TMPDIR
}

# A real call, through the real tier-1 hook, so `bin` is derived in production.
CALLN=0
call() { # $1 command, $2 agent_id (empty = main thread), $3 "noline" = write no transcript line
  # ONE id for both sides. The ledger stores a pointer and the transcript holds
  # the detail; if the two ids differ the resolution silently finds nothing, and
  # every model-stage assertion then fails for a fixture reason rather than a
  # code one.
  #
  # The two optional arguments build the two ways resolution can fail. $2 makes
  # tier 1 store a pointer at the subagent's own transcript, which nothing has
  # written yet -- an absent file. $3 leaves the id out of a transcript that IS
  # on disk, which is the shape a [ -f ] guard cannot tell from a hit.
  CALLN=$((CALLN+1)); id="tu$CALLN"
  jq -nc --arg s "$SID" --arg c "$1" --arg tp "$TP" --arg id "$id" --arg aid "${2:-}" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:"Bash", tool_input:{command:$c}, tool_use_id:$id, cwd:"/p"}
      + (if $aid == "" then {} else {agent_id:$aid} end)' \
  | bash "$IDX" >/dev/null 2>&1
  [ "${3:-}" = noline ] || jq -nc --arg a "$1" --arg id "$id" \
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

printf '\n== tier 3 records the VOLUME of evidence it answered on ==\n'
# The section above turned the model off again, so this one turns it back on --
# without that the stage never runs, no tier-3 row is written, and every
# assertion here would fail for a fixture reason. The value is any name that is
# not "off"; the stub answers whatever it is handed.
#
# "Resolved" is "this call contributed argument text", never "its file exists".
# The stored pointer can name a file that is on disk and holds no such call --
# the common shape for a subagent call -- and only the stronger question can
# tell that from a hit.
export HARNESS_T3_MODEL=stub-model
t3_of() { jq -rs --arg f "$1" '[.[]|select(.kind=="verdict" and .tier==3)][0][$f]' < "$LED"; }

reset
for i in 1 2 3 4 5; do call "grep -rn arg$i"; done
for i in 6 7 8;     do call "grep -rn arg$i" "" noline; done
stop >/dev/null
check "a verdict is still written on partial evidence" "$(v3)" "1"
check "  flagged_calls counts every flagged row"       "$(t3_of flagged_calls)" "8"
check "  unresolved_calls counts the three that gave nothing" "$(t3_of unresolved_calls)" "3"

reset; n_of 8 "grep -rn"
stop >/dev/null
check "with every flagged call resolved the counter is 0" "$(t3_of unresolved_calls)" "0"
check "  and flagged_calls is unmoved by that"            "$(t3_of flagged_calls)" "8"

printf '\n== a transcript that EXISTS but holds no such call is unresolved ==\n'
# [ -f "$tpath" ] || continue passes here -- the file is the parent's and is on
# disk -- so a resolution notion built on it counts this call as evidence the
# model never saw.
reset
for i in 1 2 3 4 5 6 7; do call "grep -rn arg$i"; done
call "grep -rn arg8" "" noline
stop >/dev/null
check "the pointer's file is on disk"       "$( [ -f "$TP" ] && echo yes || echo no )" "yes"
check "  yet that call counts as unresolved" "$(t3_of unresolved_calls)" "1"

printf '\n== a derived pointer that names nothing is unresolved too ==\n'
reset
for i in 1 2 3 4 5 6 7; do call "grep -rn arg$i"; done
call "grep -rn arg8" "sub9"
sub_ptr=$(jq -rs '[.[]|select(.kind=="call")][-1].transcript' < "$LED")
stop >/dev/null
check "the subagent's transcript is not there" \
      "$( [ ! -e "$sub_ptr" ] && echo absent || echo present )" "absent"
check "  so its call resolved nothing"         "$(t3_of unresolved_calls)" "1"

printf '\n== the counter records; it decides nothing ==\n'
reset; n_of 8 "grep -rn"
STUB_ANSWER="PROGRESS each call searched a different module" stop >/dev/null
full_v=$(t3_of verdict); full_u=$(t3_of unresolved_calls)
reset
for i in 1 2 3 4 5; do call "grep -rn arg$i"; done
for i in 6 7 8;     do call "grep -rn arg$i" "" noline; done
STUB_ANSWER="PROGRESS each call searched a different module" stop >/dev/null
check "the same answer yields the same verdict on partial evidence" "$(t3_of verdict)" "$full_v"
# Two absences compare equal, so the invariance above needs the value pinned.
check "  and that verdict is a real one" "$full_v" "progress"
# Without this the invariance above is satisfied by two turns that carried the
# SAME evidence, which is a comparison of a thing with itself.
check "  and the two turns really did differ in evidence" \
      "$( [ "$full_u" != "$(t3_of unresolved_calls)" ] && echo differ || echo same )" "differ"

# Back to off explicitly, for the reason the comment above the model section
# gives: unset would hand the rest of the suite to the ambient environment.
export HARNESS_T3_MODEL=off

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

# ---------------------------------------------------------------------------
printf '\n== an unwritable ledger FILE is reported ONCE per session, not once per write ==\n'
# ---------------------------------------------------------------------------
# THE TRIGGER HERE IS NOT loop-index.sh's. That file leaks when the DIRECTORY is
# unwritable, because the ledger does not exist yet and the open fails. This one
# leaks when the FILE is unwritable -- a mode change, a read-only mount, a
# ledger owned by someone else.
#
# THE FIXTURE MUST BE NON-EMPTY AND UNWRITABLE, both. `[ -s "$ledger" ] || exit 0`
# near the top of the hook tests existence and SIZE, never writability, so an
# empty fixture takes the early exit and measures nothing at all -- the same trap
# as the mid-write case that passed against a planted defect because its ledger
# happened to be empty.
reset; n_of 8 "grep -rn"
before=$(wc -l < "$LED" | tr -d ' ')
chmod 444 "$LED"
if [ -w "$LED" ]; then
  bad "precondition: a chmod 444 ledger is still writable here, so this case cannot run"
else
  ok "precondition: the ledger is unwritable"
  check "precondition: and NON-empty, so the early size exit is not what is being measured" \
        "$( [ -s "$LED" ] && echo yes || echo no )" "yes"
  VRC=0
  jq -nc --arg s "$SID" '{session_id:$s,hook_event_name:"Stop"}' \
    | HARNESS_T3_MODEL=haiku bash "$HOOK" > "${WORK}/vout" 2> "${WORK}/verr" || VRC=$?
  check "the hook still exits 0 -- a Stop hook returning non-zero forces the turn to continue" \
        "$VRC" "0"
  verr=$(cat "${WORK}/verr")
  has "it names the consequence" "$verr" "LOOP DETECTION IS DISABLED"
  case "$verr" in
    *"ermission denied"*) bad "the raw shell error still leaks beside the sentence" ;;
    *)                    ok "no raw shell error leaks beside it" ;;
  esac
  # THREE writes failed in this one run -- the turn marker, the tier-2 verdict
  # and the tier-3 verdict -- and the report is a property of the SESSION, not
  # of the write. One sentence, or the "once" is not implemented.
  n=$(grep -c 'LOOP DETECTION IS DISABLED' "${WORK}/verr" || true)
  check "exactly ONE sentence although three separate writes failed" "$n" "1"
  # The finding itself still reaches the human. Losing the ability to RECORD a
  # verdict must not lose the advisory that the verdict was reached.
  has "the coarse-repeat advisory is still printed" "$verr" "[loop-index] coarse repeat:"
  check "and nothing went to stdout" "$(wc -c < "${WORK}/vout" | tr -d ' ')" "0"
  # The converse: every one of those writes really did fail, so the three sites
  # are all exercised rather than one of them standing in for the others.
  check "the ledger grew by nothing at all" "$(wc -l < "$LED" | tr -d ' ')" "$before"
  check "  so no turn marker was recorded" "$(turns)" "0"
  check "  no tier-2 verdict"              "$(v2)" "0"
  check "  and no tier-3 verdict"          "$(v3)" "0"
  VRC=0
  jq -nc --arg s "$SID" '{session_id:$s,hook_event_name:"Stop"}' \
    | HARNESS_T3_MODEL=haiku bash "$HOOK" > "${WORK}/vout" 2> "${WORK}/verr2" || VRC=$?
  check "the SECOND turn -- a separate process -- exits 0 too" "$VRC" "0"
  case "$(cat "${WORK}/verr2")" in
    *"LOOP DETECTION IS DISABLED"*) bad "the second turn repeated the warning" ;;
    *)                              ok "and does not repeat the warning" ;;
  esac
  has "  while still printing the finding itself" "$(cat "${WORK}/verr2")" "[loop-index] coarse repeat:"
fi
chmod 644 "$LED"

printf '\n-- and a writable ledger is unaffected, which is what makes the above a finding --\n'
reset; n_of 8 "grep -rn"
# The slot is freed IMMEDIATELY BEFORE the measured call, not merely at the top
# of the case. reset() gives this case a private namespace, but the seeding
# `n_of 8` calls run the tier-1 hook eight times and any one of them could claim
# the slot under a defect that reports on success -- which is precisely what
# happens, so without this the control is blind to that defect while its
# precondition is the only thing that notices. Clearing here makes a spurious
# report at the measured call visible as itself.
rm -rf "$TMPDIR"/harness-ledger-warned-* 2>/dev/null
check "precondition: the report slot is free, so a spurious report would be visible" \
      "$(find "$TMPDIR" -maxdepth 1 -name 'harness-ledger-warned-*' | wc -l | tr -d ' ')" "0"
out=$(stop_err)
case "$out" in
  *"LOOP DETECTION IS DISABLED"*) bad "the report fired on a perfectly writable ledger" ;;
  *)                              ok "nothing is reported when the ledger is writable" ;;
esac
check "  and the turn marker IS recorded" "$(turns)" "1"
check "  beside the tier-2 verdict"       "$(v2)" "1"

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
