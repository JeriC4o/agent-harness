#!/usr/bin/env bash
#
# The variation grid for the tier-1 loop detector (GH-86 / GH-88). Run from anywhere:
#   bash scripts/test-loop-grid.sh
#
# Nine axes, each a must-fire case PAIRED with the near-miss that must stay
# silent, scored into a per-axis confusion matrix. A grid of must-fire cases
# alone measures sensitivity only, so a detector that fires on everything passes
# it -- which is the complaint this ticket opens with. The near-miss column is
# what makes a precision number exist at all.
#
# The same nineteen cases also run against two planted detector stubs, one
# firing on everything and one on nothing, and the matrix is REQUIRED to go
# wrong. Without that a green run would be evidence about the scoring rather
# than about the detector.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)
LIB="${HERE}/hooks/lib"
HOOK="${LIB}/loop-index.sh"
WRAP="${LIB}/loop-window-prefix.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected [$3])" ;; *) ok "$1" ;; esac; }
yn()   { if [ "$1" -eq 0 ]; then printf no; else printf yes; fi; }

command -v jq >/dev/null 2>&1 || { printf 'jq is required\n' >&2; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FX="${WORK}/fx"; mkdir -p "$FX"
export HARNESS_LOOP_DIR="${WORK}/loops"
SID="grid-1"
LED="${HARNESS_LOOP_DIR}/${SID}.jsonl"
TP="/tmp/proj/${SID}.jsonl"
ERRF="${WORK}/stderr"
CASES="${WORK}/cases.psv"

payload() { # $1 tool, $2 command, $3 agent_id -- empty means the field is ABSENT
  jq -nc --arg s "$SID" --arg tp "$TP" --arg t "$1" --arg c "$2" --arg a "${3:-}" \
     '{session_id:$s, transcript_path:$tp, hook_event_name:"PreToolUse",
       tool_name:$t, tool_input:{command:$c}, tool_use_id:"toolu_incoming", cwd:"/p"}
      + (if $a == "" then {} else {agent_id:$a} end)'
}

# A working copy of the shipped tree at a different absolute path. loop-index.sh
# resolves both scripts/bin-of.jq and loop-window.awk from $0, so a copy of the
# one script resolves neither, its single jq fails, and it exits 0 having
# written nothing -- silent for a reason that has nothing to do with the stub
# under test.
relocate() { # $1 destination root
  mkdir -p "$1/hooks/lib" "$1/scripts" || return 1
  cp "${LIB}"/*.sh "${LIB}"/*.awk "$1/hooks/lib/" || return 1
  cp "${HERE}/scripts/bin-of.jq" "$1/scripts/" || return 1
  chmod +x "$1/hooks/lib/loop-index.sh"
}

printf '\n== the entry points are driven the way production drives them ==\n'
check "the hook hooks.json invokes by path is executable" "$( [ -x "$HOOK" ] && echo yes || echo no )" "yes"
check "the frozen control the suites invoke by path is too" "$( [ -x "$WRAP" ] && echo yes || echo no )" "yes"

# The matched fingerprint comes from the HOOK, never from a second djb2 written
# here: a hand-computed fp that is one byte wrong matches nothing, and then
# every must-fire case fails while every near-miss passes.
TARGET_CMD="rg --files-with-matches needle src"
rm -rf "$HARNESS_LOOP_DIR"
payload Bash "$TARGET_CMD" "" | "$HOOK" >/dev/null 2>&1
FP_T=$(jq -r 'select(.kind=="call") | .fp' < "$LED" 2>/dev/null | head -1)
rm -rf "$HARNESS_LOOP_DIR"
check "the grid's fingerprint was produced by the hook itself" \
      "$( [ -n "$FP_T" ] && echo yes || echo no )" "yes"
OTHER_FP="other-fp"
check "and the near-miss fingerprint really differs from it" \
      "$( [ "$FP_T" != "$OTHER_FP" ] && echo yes || echo no )" "yes"

# ---------------------------------------------------------------------------
# Fixtures. Every row is one line of COMPACT JSON because the detector matches
# with anchored regexes over the raw line -- `"kind":"call"`, no space. A
# pretty-printed fixture matches nothing, so every row is skipped and every
# expect=silent case passes while the grid measures zero.
#
# Token vocabulary, one row each:
#   m[:agent]  the matched call  (Bash, FP_T)      g  Read carrying FP_T
#   d          Bash carrying a different fp        f  a filler Read, unique fp
#   E          an Edit, i.e. a mutation            T  a turn marker
#   ok / err   a result row for the preceding call V  a tier-1 verdict row
#   nk         a matched call from a build that wrote no `kind` field
# ---------------------------------------------------------------------------
TS_STEP=0
ROW_I=0
LAST_ID=""
row_call() { # $1 tool, $2 fp, $3 agent
  LAST_ID="u${ROW_I}"
  printf '{"ts":"2026-10-05T00:%02d:00Z","kind":"call","agent_id":"%s","agent_type":"-","tool":"%s","fp":"%s","bin":"rg","tool_use_id":"%s","transcript":"-","cwd":"/p"}\n' \
         "$((ROW_I * TS_STEP))" "$3" "$1" "$2" "$LAST_ID"
}
row_result() { printf '{"ts":"2026-10-05T00:00:00Z","kind":"result","tool_use_id":"%s","ok":%s}\n' "$LAST_ID" "$1"; }
row_turn()   { printf '%s\n' '{"ts":"2026-10-05T00:00:00Z","kind":"turn"}'; }
row_verdict(){ printf '{"ts":"2026-10-05T00:00:00Z","kind":"verdict","tier":1,"signal":"loop","tool":"Bash","fp":"%s","count":3,"agents":1,"decision":"ask","window":20,"window_unit":"calls","threshold":3}\n' "$FP_T"; }
row_nokind() { printf '{"ts":"2026-10-05T00:00:00Z","agent_id":"main","tool":"Bash","fp":"%s","tool_use_id":"u%s"}\n' "$FP_T" "$ROW_I"; }

seed() { # $1 destination, then tokens
  local out="$1" tok agent
  shift
  ROW_I=0; LAST_ID=""
  : > "$out"
  for tok in "$@"; do
    ROW_I=$((ROW_I+1))
    agent=main
    case "$tok" in m:*) agent="${tok#m:}"; tok=m ;; esac
    case "$tok" in
      m)   row_call Bash "$FP_T"    "$agent" ;;
      d)   row_call Bash "$OTHER_FP" main ;;
      g)   row_call Read "$FP_T"    main ;;
      f)   row_call Read "filler-${ROW_I}" main ;;
      E)   row_call Edit "edit-${ROW_I}"   main ;;
      ok)  row_result true ;;
      err) row_result false ;;
      T)   row_turn ;;
      V)   row_verdict ;;
      nk)  row_nokind ;;
      *)   bad "seed: unknown token [$tok]"; return 1 ;;
    esac >> "$out"
  done
}

# AC1 / AC2 / AC8. 24 lines over 10 calls -- the measured corpus ratio -- with
# the two matched calls at call ordinals 5 and 6, which are lines 11 and 13. So
# a 6-CALL window reaches them and a 6-LINE window does not, and that
# disagreement is the whole of defect 1. The verdict row carries the matched
# tool and fp, so a reader that skips the kind filter counts it.
seed "${FX}/ratio-2.4.jsonl"        f ok f ok T f ok f ok T m    ok m    ok V f ok f ok T f ok f ok
seed "${FX}/ratio-2.4-fanout.jsonl" f ok f ok T f ok f ok T m:a1 ok m:a2 ok V f ok f ok T f ok f ok
seed "${FX}/ratio-2.4-retry.jsonl"  f ok f ok T f ok f ok T m err  m err  V f ok f ok T f ok f ok

# AC2b. Same ten calls with the matches at ordinals 9 and 10 on all three, so
# the only difference between them is how many non-call lines sit in between:
# 1.0, 2.4 and 5.0 lines per call. ratio-5 is the one that cannot be read in a
# single chunk, so it is the fixture the RETRY path exists for.
seed "${FX}/ac2b-r1.0.jsonl" f f f f f f f f m m
seed "${FX}/ac2b-r2.4.jsonl" f ok f ok T f ok f ok T f ok f ok T f ok f ok T m ok m ok
seed "${FX}/ac2b-r5.0.jsonl" f T T T T f T T T T f T T T T f T T T T f T T T T \
                             f T T T T f T T T T f T T T T m T T T T m T T T T

seed "${FX}/ident-diff-fp.jsonl"   d ok d ok
seed "${FX}/ident-diff-tool.jsonl" g ok g ok
seed "${FX}/mut-outside.jsonl"     E m ok m ok
seed "${FX}/mut-between.jsonl"     m ok E m ok
# The outcome pair differs in ONE byte of one row: the second result's `ok`.
# Two failures fire through the Edit, one failure does not -- which is AC5's
# content, and the reason the near-miss here carries a mutation at all.
seed "${FX}/out-fail2.jsonl"       m err E m err
seed "${FX}/out-fail1.jsonl"       m err E m ok
seed "${FX}/fanout3.jsonl"         m:a1 ok m:a2 ok
seed "${FX}/loop1agent.jsonl"      m ok m ok
seed "${FX}/sparse.jsonl"          m f f f m f f f m
seed "${FX}/clus-tail.jsonl"       f f f m m
seed "${FX}/clus-buried.jsonl"     f f f m m f f f f f
seed "${FX}/schema-kind.jsonl"     m m
seed "${FX}/schema-nokind.jsonl"   nk nk
# AC3's positive control. 15 rows, all of them calls, so lines and calls are the
# same number here and the UNIT change cannot be what makes it pass: the fixture
# isolates the anchor. An old match at ordinal 2, a mutation right after it, ten
# fillers, then a tight cluster at the tail.
seed "${FX}/anchor-15.jsonl"       f m E f f f f f f f f f f m m
seed "${FX}/anchor-inside.jsonl"   m m E m
seed "${FX}/time-same.jsonl"       m ok m ok
TS_STEP=7
seed "${FX}/time-spread.jsonl"     m ok m ok
TS_STEP=0

printf '\n== AC10/A10: every fixture parses, or the grid refuses to run ==\n'
for fxf in "$FX"/*.jsonl; do
  base=$(basename "$fxf")
  n=$(grep -c '"kind":"call"' "$fxf")
  jq -e . "$fxf" >/dev/null 2>&1 || { bad "$base is not well-formed JSONL"; printf '\nABORT: %s\n' "$base"; exit 1; }
  case "$base" in
    schema-nokind.jsonl)
      # The one fixture whose premise is that it does NOT parse: rows from a
      # build that wrote no `kind` are skipped rather than guessed at (TC3), so
      # here zero is the assertion rather than the abort.
      check "$base carries no parseable call row, which is its premise" "$n" "0" ;;
    *)
      if [ "$n" -ge 1 ]; then ok "$base yields $n parsed call rows"
      else
        bad "$base yields NO parsed kind:\"call\" row"
        printf '\nABORT: %s is not compact JSON; every silent case would pass vacuously\n' "$base"
        exit 1
      fi ;;
  esac
done

# ---------------------------------------------------------------------------
# The grid itself.
# ---------------------------------------------------------------------------
cat > "$CASES" <<EOF
call identity|fire:loop|same tool and fp, three times inside the window|ratio-2.4|6|Bash|${TARGET_CMD}|
call identity|silent|the same tool with a different fp is not the same call|ident-diff-fp|20|Bash|${TARGET_CMD}|
call identity|silent|a different tool carrying the same fp is not either|ident-diff-tool|20|Bash|${TARGET_CMD}|
intervening mutation|fire:loop|succeeded repeats with no mutation in the counted span|mut-outside|20|Bash|${TARGET_CMD}|
intervening mutation|silent|an Edit between the counted matches dismisses them|mut-between|20|Bash|${TARGET_CMD}|
outcome|fire:error-retry|two recorded failures fire, the Edit between them notwithstanding|out-fail2|20|Bash|${TARGET_CMD}|
outcome|silent|one failure only, and the Edit still dismisses|out-fail1|20|Bash|${TARGET_CMD}|
agent multiplicity|fire:fanout|one fp reached by three different agents|fanout3|20|Bash|${TARGET_CMD}|a3
agent multiplicity|fire:loop|the same three calls from one agent is a loop, not fan-out|loop1agent|20|Bash|${TARGET_CMD}|
sparsity|fire:loop|three matches inside K calls|sparse|9|Bash|${TARGET_CMD}|
sparsity|silent|the same three matches spanning more than K calls|sparse|3|Bash|${TARGET_CMD}|
cluster position|fire:loop|the cluster at the ledger tail|clus-tail|5|Bash|${TARGET_CMD}|
cluster position|silent|the same cluster followed by K unrelated calls|clus-buried|5|Bash|${TARGET_CMD}|
time|fire:loop|rows written at one instant|time-same|20|Bash|${TARGET_CMD}|
time|fire:loop|the same rows written minutes apart|time-spread|20|Bash|${TARGET_CMD}|
ledger schema|fire:loop|rows carrying kind are counted|schema-kind|20|Bash|${TARGET_CMD}|
ledger schema|silent|rows from a build that wrote no kind are skipped, not guessed at|schema-nokind|20|Bash|${TARGET_CMD}|
dismissal anchor|fire:loop|old match, mutation after it, tight recent cluster, at K = 14|anchor-15|14|Bash|${TARGET_CMD}|
dismissal anchor|silent|the same shape with the mutation inside the recent cluster|anchor-inside|20|Bash|${TARGET_CMD}|
EOF

A_TP=0; A_FP=0; A_TN=0; A_FN=0
G_TP=0; G_FP=0; G_TN=0; G_FN=0
OUT=""; SIG=""

# Restores the fixture before every run, because the hook APPENDS: a second run
# against the ledger the first one left behind is a different ledger, which is
# also what makes AC7's replay a restore rather than a re-fire.
drive() { # $1 hook, $2 fixture basename, $3 K ("default" = the shipped setting), $4 tool, $5 cmd, $6 agent
  rm -rf "$HARNESS_LOOP_DIR"; mkdir -p "$HARNESS_LOOP_DIR"
  cp "${FX}/$2.jsonl" "$LED"
  : > "$ERRF"
  if [ "$3" = default ]; then
    OUT=$(payload "$4" "$5" "${6:-}" | "$1" 2>"$ERRF")
  else
    OUT=$(payload "$4" "$5" "${6:-}" | HARNESS_LOOP_TAIL="$3" "$1" 2>"$ERRF")
  fi
  # The arm is read off the stderr marker rather than off the prose or off the
  # ledger: the fixtures carry verdict rows of their own, so "the last verdict
  # row" is not necessarily the one this run wrote.
  SIG=$(sed -n 's/^\[loop-index\] \([a-z-]*\):.*/\1/p' "$ERRF" | tail -1)
}

score() { # $1 expect, $2 desc, $3 mode
  local want
  case "$1" in
    silent)
      if [ -z "$OUT" ]; then
        A_TN=$((A_TN+1)); [ "$3" = assert ] && ok "tn    $2"
      else
        A_FP=$((A_FP+1)); [ "$3" = assert ] && bad "fp    $2 -- fired [$SIG] where silence was required"
      fi ;;
    fire:*)
      want="${1#fire:}"
      if [ "$SIG" = "$want" ]; then
        A_TP=$((A_TP+1)); [ "$3" = assert ] && ok "tp    $2 -> $SIG"
      elif [ -z "$OUT" ]; then
        A_FN=$((A_FN+1)); [ "$3" = assert ] && bad "fn    $2 -- silent where [$want] was required"
      else
        # A wrong ARM counts in both columns: the finding it owed was missed AND
        # one it did not owe was emitted. Scoring it once would let a detector
        # that answers every question with the same arm keep a clean precision
        # column while being wrong about every arm but one.
        A_FN=$((A_FN+1)); A_FP=$((A_FP+1))
        [ "$3" = assert ] && bad "fn+fp $2 -- fired [$SIG], wanted [$want]"
      fi ;;
  esac
  return 0
}

# The committed per-axis expectation. Perfect precision and recall everywhere,
# plus a floor on how many cases of each kind must actually have scored -- an
# axis whose cases all failed to run would otherwise divide zero by zero and
# read as 100%.
axis_min() { # echoes "<min_tp> <min_tn>"
  case "$1" in
    "call identity")      printf '1 2' ;;
    # Both cases here are positive: the near-miss is a different ARM rather than
    # silence, because three calls from one agent is still a loop.
    "agent multiplicity") printf '2 0' ;;
    # No silent case by design -- the control is that a time gap changes
    # NOTHING, which is a non-difference and is asserted after the grid.
    "time")               printf '2 0' ;;
    *)                    printf '1 1' ;;
  esac
}

axis_done() { # $1 axis, $2 mode
  local pr=0 rc=0 mins mintp mintn
  if [ $((A_TP + A_FP)) -gt 0 ]; then pr=$(( 100 * A_TP / (A_TP + A_FP) )); fi
  if [ $((A_TP + A_FN)) -gt 0 ]; then rc=$(( 100 * A_TP / (A_TP + A_FN) )); fi
  printf '  matrix %-21s tp=%d fp=%d tn=%d fn=%d  precision=%d%% recall=%d%%\n' \
         "$1" "$A_TP" "$A_FP" "$A_TN" "$A_FN" "$pr" "$rc"
  if [ "$2" = assert ]; then
    mins=$(axis_min "$1"); mintp="${mins% *}"; mintn="${mins#* }"
    check "  [$1] precision" "$pr" "100"
    check "  [$1] recall"    "$rc" "100"
    check "  [$1] scored its ${mintp} must-fire case(s)" "$(yn "$(( A_TP >= mintp ))")" "yes"
    check "  [$1] scored its ${mintn} near-miss case(s)" "$(yn "$(( A_TN >= mintn ))")" "yes"
  fi
  G_TP=$((G_TP+A_TP)); G_FP=$((G_FP+A_FP)); G_TN=$((G_TN+A_TN)); G_FN=$((G_FN+A_FN))
  A_TP=0; A_FP=0; A_TN=0; A_FN=0
}

grid_cases() { # $1 hook, $2 mode (assert | tally)
  local axis expect desc fxn K tool cmd agent prev=""
  G_TP=0; G_FP=0; G_TN=0; G_FN=0
  A_TP=0; A_FP=0; A_TN=0; A_FN=0
  while IFS='|' read -r axis expect desc fxn K tool cmd agent; do
    [ -n "$axis" ] || continue
    if [ -n "$prev" ] && [ "$axis" != "$prev" ]; then axis_done "$prev" "$2"; fi
    prev="$axis"
    drive "$1" "$fxn" "$K" "$tool" "$cmd" "$agent"
    score "$expect" "$desc" "$2"
  done < "$CASES"
  axis_done "$prev" "$2"
}

printf '\n== AC6: nine axes, each paired with its near-miss ==\n'
grid_cases "$HOOK" assert
printf '  TOTAL tp=%d fp=%d tn=%d fn=%d\n' "$G_TP" "$G_FP" "$G_TN" "$G_FN"
check "every declared case scored" "$((G_TP + G_FP + G_TN + G_FN))" "19"
check "no false positive anywhere in the grid" "$G_FP" "0"
check "no false negative either"               "$G_FN" "0"

printf '\n== AC6: the GATE is shown non-zero against a planted detector ==\n'
# A detector stub, not a mutated rule: the question here is whether the SCORING
# can see a wrong detector at all. Each stub is wrong in one direction only, so
# the two columns fail separately and neither failure can stand in for the other.
ALLFIRE="${WORK}/stub-allfire"
relocate "$ALLFIRE"
printf '%s\n' 'END { print "loop 3 1 4" }' > "${ALLFIRE}/hooks/lib/loop-window.awk"
grid_cases "${ALLFIRE}/hooks/lib/loop-index.sh" tally
check "a detector that fires on everything loses precision" "$(yn "$(( G_FP > 0 ))")" "yes"
check "  and reaches no true negative at all"               "$G_TN" "0"
NEVER="${WORK}/stub-never"
relocate "$NEVER"
printf '%s\n' 'END { }' > "${NEVER}/hooks/lib/loop-window.awk"
grid_cases "${NEVER}/hooks/lib/loop-index.sh" tally
check "a detector that never fires loses recall" "$(yn "$(( G_FN > 0 ))")" "yes"
check "  and scores no true positive at all"     "$G_TP" "0"

printf '\n== AC1: the window counts CALLS, and the pre-fix pair fails the same case ==\n'
R24F="${FX}/ratio-2.4.jsonl"
check "the fixture is 24 lines over 10 calls" \
      "$(printf '%s/%s' "$(wc -l < "$R24F" | tr -d ' ')" "$(grep -c '"kind":"call"' "$R24F")")" "24/10"
check "  so 2.4 lines per call, the ratio the real corpus sits at" \
      "$(awk -v l="$(wc -l < "$R24F")" -v c="$(grep -c '"kind":"call"' "$R24F")" 'BEGIN{printf "%.1f", l/c}')" "2.4"
check "  with the matches at call ordinals 5 and 6" \
      "$(awk -v fp="$FP_T" '/"kind":"call"/{c++} index($0,"\"fp\":\""fp"\"") && /"kind":"call"/{o=o c" "} END{print o}' "$R24F")" "5 6 "
drive "$HOOK" ratio-2.4 6 Bash "$TARGET_CMD" ""
has "a 6-CALL window reaches both repeats" "$OUT" '"permissionDecision":"ask"'
drive "$HOOK" ratio-2.4 5 Bash "$TARGET_CMD" ""
check "a 5-CALL window leaves the older of them out" "$OUT" ""
check "POSITIVE CONTROL: at K = 6 LINES the frozen pre-fix pair sees no repeat" \
      "$("$WRAP" 6 "$R24F" "$FP_T" Bash)" ""
check "  and it is not silent for want of a working control -- all 24 lines fire" \
      "$("$WRAP" 24 "$R24F" "$FP_T" Bash)" "loop 3 1"
# THREE fields is itself the freeze check: the control predates the counted span
# and a fourth field here would mean someone updated it, which the freeze forbids.
check "  in three fields, because the control predates the span" \
      "$("$WRAP" 24 "$R24F" "$FP_T" Bash | awk '{print NF}')" "3"

printf '\n== AC2: the number the agent is shown is the span actually counted ==\n'
# span = min(calls in the chunk, K) + 1 -- prior calls examined plus the call
# being judged. At K = 6 over this fixture that is 7 on every arm, so the arm
# cannot be what decides the unit.
drive "$HOOK" ratio-2.4 6 Bash "$TARGET_CMD" ""
has   "loop quotes the counted span"              "$OUT" "3 times within the last 7 calls"
hasnt "  not the window it requested"             "$OUT" "last 20 calls"
hasnt "  and never in steps, the noun that hid the unit" "$OUT" "steps"
drive "$HOOK" ratio-2.4-fanout 6 Bash "$TARGET_CMD" a3
has   "fanout quotes the same span"               "$OUT" "3 times in the last 7 calls"
has   "  naming the agents"                       "$OUT" "3 different agents"
hasnt "  in calls, not steps"                     "$OUT" "steps"
drive "$HOOK" ratio-2.4-retry 6 Bash "$TARGET_CMD" ""
has   "error-retry quotes the same span"          "$OUT" "FAILED 2 times in the last 7 calls"
hasnt "  in calls, not steps"                     "$OUT" "steps"

printf '\n== AC2b: the reach is the same count of CALLS on every ledger shape ==\n'
for r in 1.0 2.4 5.0; do
  f="${FX}/ac2b-r${r}.jsonl"
  check "ac2b-r${r} is ${r} lines per call over 10 calls" \
        "$(awk -v l="$(wc -l < "$f")" -v c="$(grep -c '"kind":"call"' "$f")" 'BEGIN{printf "%.1f/%d", l/c, c}')" "${r}/10"
done
A2B=""
for r in 1.0 2.4 5.0; do
  drive "$HOOK" "ac2b-r${r}" 3 Bash "$TARGET_CMD" ""
  has "ac2b-r${r} at K = 3 counts three calls" "$OUT" "3 times within the last 4 calls"
  A2B="${A2B}${OUT}"$'\n'
done
check "and the three shapes produced the same sentence" \
      "$(printf '%s' "$A2B" | sort -u | grep -c 'within the last 4 calls')" "1"
# POSITIVE CONTROL. The chunk is K * 3 LINES, which on a 5-lines-per-call ledger
# holds one call where three were asked for. Without RETRY the detector reports
# whatever that first chunk happened to hold -- a silent miss whose size depends
# on how many turn rows the session logged, which is defect 1 in a new hat.
NORETRY="${WORK}/no-retry"
relocate "$NORETRY"
perl -0pi -e 's/^[ ]{6}if \(calls < want_calls && NR == chunk\) \{ print "RETRY"; exit \}\n//m' \
     "${NORETRY}/hooks/lib/loop-window.awk"
check "the mutation applied" "$(grep -c 'print "RETRY"' "${NORETRY}/hooks/lib/loop-window.awk")" "0"
drive "${NORETRY}/hooks/lib/loop-index.sh" ac2b-r1.0 3 Bash "$TARGET_CMD" ""
has "with no retry the 1.0 shape is unaffected, so the tree it resolves from is intact" \
    "$OUT" "3 times within the last 4 calls"
drive "${NORETRY}/hooks/lib/loop-index.sh" ac2b-r5.0 3 Bash "$TARGET_CMD" ""
check "  but the 5.0 shape comes out short and says nothing" "$OUT" ""

printf '\n== AC3: firing is non-decreasing as the window widens ==\n'
# A sweep confined to small K is satisfied by the BROKEN rule -- measured, over
# K = 1..80 on the real ledger the pre-fix rule scores zero violations -- so the
# range is part of the assertion. On anchor-15 the discriminating width is
# K = 14, where the old match enters the window, drags the anchor back behind
# the mutation at ordinal 3, and the whole recent cluster is dismissed: a wider
# window finding LESS.
sweep() { # $1 fixture basename, $2 fixed|frozen, then the K list
  local fxn="$1" rule="$2" K r out=""
  shift 2
  for K in "$@"; do
    if [ "$rule" = frozen ]; then
      r=$("$WRAP" "$K" "${FX}/${fxn}.jsonl" "$FP_T" Bash)
    else
      drive "$HOOK" "$fxn" "$K" Bash "$TARGET_CMD" ""
      r="$OUT"
    fi
    if [ -n "$r" ]; then out="${out}1"; else out="${out}0"; fi
  done
  printf '%s' "$out"
}
check "anchor-15 fires at every width (K = 3/5/10/13/14/20)" \
      "$(sweep anchor-15 fixed 3 5 10 13 14 20)" "111111"
check "POSITIVE CONTROL: the pre-fix pair goes silent at K = 14 and stays silent" \
      "$(sweep anchor-15 frozen 3 5 10 13 14 20)" "111100"
# Every grid fixture, not only the one built to break: a 1 followed by a 0 is a
# wider window finding less, which is the property regardless of fixture.
for fxf in "$FX"/*.jsonl; do
  base=$(basename "$fxf" .jsonl)
  s=$(sweep "$base" fixed 1 2 3 5 8 13 21 999)
  case "$s" in
    *10*) bad "monotonicity: $base scores [$s] over K = 1/2/3/5/8/13/21/999" ;;
    *)    ok  "monotonicity: $base scores [$s]" ;;
  esac
done

printf '\n== AC4: the STATE qualifier still dismisses, and only where it should ==\n'
drive "$HOOK" mut-between 20 Bash "$TARGET_CMD" ""
check "an Edit between the counted matches dismisses them" "$OUT" ""
check "  and the pre-fix pair agrees, so the rules differ only where the defect was" \
      "$("$WRAP" unbounded "${FX}/mut-between.jsonl" "$FP_T" Bash)" ""
drive "$HOOK" mut-outside 20 Bash "$TARGET_CMD" ""
has "an Edit outside the counted span does not" "$OUT" '"permissionDecision":"ask"'

printf '\n== AC5: the error-retry arm reads the same under both rules ==\n'
# "Unchanged" is only testable once each side's window is pinned in its OWN
# unit: `fails` is counted over the result rows the window admits, so a
# call-counted K and a line-counted K are not the same question at the same
# number. Each side is given the whole fixture instead.
for fxn in out-fail2 out-fail1; do
  drive "$HOOK" "$fxn" 999 Bash "$TARGET_CMD" ""
  frozen=$("$WRAP" unbounded "${FX}/${fxn}.jsonl" "$FP_T" Bash | awk '{print $1}')
  check "$fxn: the shipped hook and the frozen pair agree on the arm" "$SIG" "$frozen"
done
drive "$HOOK" out-fail2 999 Bash "$TARGET_CMD" ""
has "two failures fire as a retry even with an Edit between them" "$OUT" "already FAILED 2 times"
hasnt "  and the interrupted call is not counted among the failures" "$OUT" "FAILED 3 times"

printf '\n== AC7: the same ledger replayed twice yields the same verdict ==\n'
drive "$HOOK" ratio-2.4 6 Bash "$TARGET_CMD" ""
first="$OUT"
drive "$HOOK" ratio-2.4 6 Bash "$TARGET_CMD" ""
check "a loop verdict is byte-identical on replay" "$OUT" "$first"
drive "$HOOK" mut-between 20 Bash "$TARGET_CMD" ""
first="$OUT"
drive "$HOOK" mut-between 20 Bash "$TARGET_CMD" ""
check "and so is a dismissal" "$OUT" "$first"

printf '\n== AC8: a verdict row is never counted as a call ==\n'
# ratio-2.4's verdict row carries the matched tool and fp, so a reader that does
# not filter on kind counts it -- and then every firing makes the next one more
# likely, a detector that feeds itself.
check "the fixture holds 3 rows carrying the matched fp" \
      "$(grep -c "\"fp\":\"${FP_T}\"" "$R24F")" "3"
check "  of which 2 are calls" \
      "$(jq -rs "[.[] | select(.kind==\"call\" and .fp==\"${FP_T}\")] | length" < "$R24F")" "2"
drive "$HOOK" ratio-2.4 default Bash "$TARGET_CMD" ""
has   "so the count is 3"                "$OUT" "3 times"
hasnt "  and 4 would mean it counted the verdict" "$OUT" "4 times"
# The same property through the live hook, where the verdict rows are the ones
# the hook itself just wrote rather than fixture rows.
rm -rf "$HARNESS_LOOP_DIR"
for _ in 1 2 3; do payload Bash "$TARGET_CMD" "" | "$HOOK" >/dev/null 2>&1; done
OUT=$(payload Bash "$TARGET_CMD" "" | "$HOOK" 2>/dev/null)
has   "four live calls report 4"             "$OUT" "4 times"
hasnt "  not 5"                              "$OUT" "5 times"
check "  though the ledger holds 6 rows carrying that fp" \
      "$(grep -c "\"fp\":\"${FP_T}\"" "$LED")" "6"
check "  2 of them verdicts" \
      "$(jq -rs '[.[] | select(.kind=="verdict")] | length' < "$LED")" "2"

printf '\n== AC13: a planted true loop fires at the shipped default ==\n'
rm -rf "$HARNESS_LOOP_DIR"
o1=$(payload Bash "$TARGET_CMD" "" | "$HOOK" 2>/dev/null)
o2=$(payload Bash "$TARGET_CMD" "" | "$HOOK" 2>/dev/null)
check "the first call is silent"  "$o1" ""
check "the second is too"         "$o2" ""
OUT=$(payload Bash "$TARGET_CMD" "" | "$HOOK" 2>/dev/null)
has "the third asks, with no HARNESS_LOOP_TAIL set at all" "$OUT" '"permissionDecision":"ask"'
# Two prior calls existed, so the counted span is 3 and not the shipped 20.
has   "  quoting the span it counted"     "$OUT" "3 times within the last 3 calls"
hasnt "  never the window it requested"   "$OUT" "last 20 calls"
hasnt "  and never in steps"              "$OUT" "steps"

printf '\n== the time axis is a non-difference, not a near-miss ==\n'
# Tier 1 keys on POSITION in the ledger and never on `ts`, so a time gap must
# change nothing. That is not a case the matrix can hold -- there is no silent
# half -- so it is asserted as an equality between two runs.
check "the two fixtures really differ in ts" \
      "$(yn "$(( $(jq -rs '[.[]|.ts]|unique|length' < "${FX}/time-same.jsonl") \
                 != $(jq -rs '[.[]|.ts]|unique|length' < "${FX}/time-spread.jsonl") ))")" "yes"
drive "$HOOK" time-same 20 Bash "$TARGET_CMD" ""
same="$OUT"
drive "$HOOK" time-spread 20 Bash "$TARGET_CMD" ""
check "rows minutes apart yield the identical verdict" "$OUT" "$same"
has   "  and it is a firing, not a shared silence" "$same" '"permissionDecision":"ask"'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
