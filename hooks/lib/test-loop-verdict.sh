#!/usr/bin/env bash
#
# Tests for loop-verdict.sh -- tier 2 (GH-62). Run from anywhere:
#   bash hooks/lib/test-loop-verdict.sh
#
# The model is STUBBED by putting a fake `claude` first on PATH. A suite that
# called the real one would be slow, non-deterministic, and would pass or fail
# for reasons that have nothing to do with this code.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
HOOK="${HERE}/loop-verdict.sh"
HOOKS_JSON="${HERE}/../hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HARNESS_LOOP_DIR="${WORK}/loops"
mkdir -p "$HARNESS_LOOP_DIR" "$WORK/bin"
SID="sess-t2"
LED="${HARNESS_LOOP_DIR}/${SID}.jsonl"
TP="${WORK}/${SID}.jsonl"

# Stub `claude`: answers with whatever STUB_ANSWER holds, and records that it ran.
cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat > /dev/null
printf '%s\n' "${STUB_ANSWER:-CIRCLING
it keeps re-running the same search with a different pattern}"
printf 'called\n' >> "${STUB_CALLS:-/dev/null}"
STUB
chmod +x "$WORK/bin/claude"
export PATH="$WORK/bin:$PATH"
export STUB_CALLS="${WORK}/claude-calls"

reset() { : > "$LED"; : > "$TP"; : > "$STUB_CALLS"; }

# Append one call to the ledger AND its tool_use to the transcript.
add_call() { # $1 tool, $2 fp, $3 arg-text, $4 id
  jq -nc --arg t "$1" --arg f "$2" --arg id "$4" --arg tp "$TP" \
     '{ts:"2026-09-26T00:00:00Z", kind:"call", agent_id:"main", tool:$t, fp:$f,
       tool_use_id:$id, transcript:$tp}' >> "$LED"
  jq -nc --arg id "$4" --arg a "$3" \
     '{message:{content:[{type:"tool_use", id:$id, input:{pattern:$a}}]}}' >> "$TP"
}
# A window of one tool with DISTINCT fingerprints -- the tier-2 shape.
varied_window() { # $1 how many
  reset
  i=0; while [ "$i" -lt "$1" ]; do
    i=$((i+1)); add_call Grep "fp$i" "needle-variant-$i" "toolu_$i"
  done
}
fire() { jq -nc --arg s "$SID" '{session_id:$s, hook_event_name:"Stop"}' | bash "$HOOK" 2>/dev/null; }
fire_err() { jq -nc --arg s "$SID" '{session_id:$s, hook_event_name:"Stop"}' | bash "$HOOK" 2>&1 >/dev/null; }
verdicts() { jq -rs '[.[] | select(.kind=="verdict" and .tier==2)] | length' < "$LED"; }
stub_calls() { wc -l < "$STUB_CALLS" | tr -d ' '; }

printf '\n== below the structural gate, the model is never asked ==\n'
varied_window 4
fire >/dev/null
check "4 calls is under min_calls -- no verdict" "$(verdicts)" "0"
check "  and the model was not called at all"    "$(stub_calls)" "0"

printf '\n== identical fingerprints are tier 1 territory, not tier 2 ==\n'
reset
for i in 1 2 3 4 5 6; do add_call Grep "same" "needle" "toolu_$i"; done
fire >/dev/null
check "6 calls but 1 distinct fp -- not this detector" "$(verdicts)" "0"
check "  model not called"                             "$(stub_calls)" "0"

printf '\n== a varied window of one tool DOES reach the model ==\n'
varied_window 6
out=$(fire)
check "the model was asked exactly once" "$(stub_calls)" "1"
check "and a tier-2 verdict was written" "$(verdicts)" "1"
v=$(jq -c 'select(.kind=="verdict" and .tier==2)' < "$LED")
check "  signal"        "$(printf '%s' "$v" | jq -r '.signal')"        "semantic-repeat"
check "  tool"          "$(printf '%s' "$v" | jq -r '.tool')"          "Grep"
check "  calls"         "$(printf '%s' "$v" | jq -r '.calls')"         "6"
check "  distinct fps"  "$(printf '%s' "$v" | jq -r '.distinct_fps')"  "6"
check "  the verdict"   "$(printf '%s' "$v" | jq -r '.verdict')"       "circling"
check "  the model used" "$(printf '%s' "$v" | jq -r '.model')"        "haiku"
check "  and the settings it fired under" \
      "$(printf '%s' "$v" | jq -r '"\(.window)/\(.min_calls)/\(.min_distinct)"')" "40/5/3"
check "it does not block -- Stop hooks that block force a continue" \
      "$(varied_window 6; fire >/dev/null 2>&1; echo $?)" "0"

printf '\n== the arguments reach the model, resolved from the transcript ==\n'
varied_window 6
cat > "$WORK/bin/claude" <<'SPY'
#!/usr/bin/env bash
cat > "${STUB_SEEN:?}"
printf 'PROGRESS\nfine\n'
SPY
chmod +x "$WORK/bin/claude"
STUB_SEEN="${WORK}/seen" fire >/dev/null
seen=$(cat "${WORK}/seen")
has "the prompt carries a resolved argument" "$seen" "needle-variant-3"
has "  and names the tool"                   "$seen" "Grep"
has "  and asks for a one-word answer"       "$seen" "CIRCLING"
# restore the answering stub
cat > "$WORK/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat > /dev/null
printf '%s\n' "${STUB_ANSWER:-CIRCLING
it keeps re-running the same search with a different pattern}"
printf 'called\n' >> "${STUB_CALLS:-/dev/null}"
STUB
chmod +x "$WORK/bin/claude"

printf '\n== the model can say no, and no is recorded rather than dropped ==\n'
varied_window 6
STUB_ANSWER="PROGRESS
each call searched a different module" fire >/dev/null
check "a decline still writes a verdict line" "$(verdicts)" "1"
d=$(jq -c 'select(.kind=="verdict" and .tier==2)' < "$LED")
check "  recorded as progress"   "$(printf '%s' "$d" | jq -r '.verdict')" "progress"
check "  with the reason"        "$(printf '%s' "$d" | jq -r '.reason')" "each call searched a different module"
e=$(STUB_ANSWER="PROGRESS
nothing to see" fire_err)
check "  and reported to nobody -- a decline is data, not news" "$e" ""

printf '\n== a DECLINED window is not re-asked either ==\n'
# The already-judged guard keys on a tier-2 verdict line existing. While a decline
# wrote none, the same window was re-judged on EVERY Stop until it slid out --
# measured at one model call per Stop, against one for the whole window when the
# answer was circling. Progress is the common case, so it was paid constantly.
varied_window 6
: > "$STUB_CALLS"
STUB_ANSWER="PROGRESS
distinct steps" fire >/dev/null
STUB_ANSWER="PROGRESS
distinct steps" fire >/dev/null
STUB_ANSWER="PROGRESS
distinct steps" fire >/dev/null
STUB_ANSWER="PROGRESS
distinct steps" fire >/dev/null
check "four Stops, one model call" "$(stub_calls)" "1"
check "  and one verdict"          "$(verdicts)" "1"

printf '\n== POSITIVE CONTROL: drop the decline record, the model is re-asked ==\n'
MUT0="${WORK}/mut-decline.sh"
perl -0pe 's/  \*PROGRESS\*\) call_it=progress ;;/  *PROGRESS*) exit 0 ;;/' "$HOOK" > "$MUT0"
check "the mutation applied" "$(grep -c 'call_it=progress' "$MUT0")" "0"
varied_window 6
: > "$STUB_CALLS"
# EXPORTED, not prefixed to the jq on the left of the pipe: a var assignment
# there applies to jq and never reaches the hook, which would leave the stub on
# its default CIRCLING answer -- the control would then be blocked by the
# already-judged guard instead of by the thing under test, and report 1.
export STUB_ANSWER="PROGRESS
distinct steps"
for _ in 1 2 3 4; do
  jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT0" >/dev/null 2>&1
done
unset STUB_ANSWER
check "without it, four Stops -> four model calls" "$(stub_calls)" "4"
check "  and nothing recorded to calibrate against" "$(verdicts)" "0"

printf '\n== an unparseable answer is neither, and records nothing ==\n'
varied_window 6
STUB_ANSWER="I am not sure, possibly" fire >/dev/null
check "no verdict for an answer that is not a verdict" "$(verdicts)" "0"

printf '\n== the same window is judged once, not on every Stop ==\n'
varied_window 6
fire >/dev/null
fire >/dev/null
fire >/dev/null
check "three Stops, one verdict" "$(verdicts)" "1"
check "  and one model call"     "$(stub_calls)" "1"

printf '\n== POSITIVE CONTROL: drop the already-judged check, it re-asks every Stop ==\n'
MUT="${WORK}/mut-dedup.sh"
perl -0pe 's/\[ "\$\{already:-0\}" -eq 0 \] \|\| exit 0//' "$HOOK" > "$MUT"
check "the mutation applied (the guard is gone)" \
      "$(grep -c 'already:-0' "$MUT")" "0"
varied_window 6
for _ in 1 2 3; do jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT" >/dev/null 2>&1; done
check "without it, three Stops -> three verdicts" "$(verdicts)" "3"

printf '\n== POSITIVE CONTROL: drop the concentration check, breadth trips the gate ==\n'
MUT2="${WORK}/mut-conc.sh"
perl -0pe 's/if \(bestn \* 100 < total \* 60\) exit//' "$HOOK" > "$MUT2"
# A window where the dominant tool is a minority: ordinary varied work.
reset
for i in 1 2 3 4 5; do add_call Grep "g$i" "pattern-$i" "toolu_g$i"; done
for i in 1 2 3 4 5 6 7 8; do add_call Read "r$i" "file-$i" "toolu_r$i"; done
for i in 1 2 3 4 5; do add_call Bash "b$i" "cmd-$i" "toolu_b$i"; done
fire >/dev/null
check "with it, a diverse window is not a finding" "$(verdicts)" "0"
jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT2" >/dev/null 2>&1
check "without it, the same window fires" "$(verdicts)" "1"

printf '\n== POSITIVE CONTROL: drop the kind filter, verdicts inflate the gate ==\n'
MUT3="${WORK}/mut-kind.sh"
perl -0pe 's/    if \(k != "call"\) next\n    t = ""; if \(match\(\$0, \/"tool"/    t = ""; if (match(\$0, \/"tool"/' "$HOOK" > "$MUT3"
check "the mutation applied (the guard is gone)" \
      "$(grep -c 'if (k != "call") next' "$MUT3")" "0"
# Four calls -- one under the gate -- plus two TIER-1 verdict lines, which carry
# tool and fp exactly like a call. Tier 1 deliberately, not tier 2: a tier-2 line
# would trip the already-judged guard and stop the control firing for the wrong
# reason, hiding what this control is supposed to show.
reset
for i in 1 2 3 4; do add_call Grep "v$i" "p-$i" "toolu_v$i"; done
for i in 1 2; do
  jq -nc --argjson n "$i" \
     '{ts:"2026-09-26T00:00:00Z", kind:"verdict", tier:1, signal:"loop",
       tool:"Grep", fp:("x"+($n|tostring))}' >> "$LED"
done
fire >/dev/null
check "with the filter, 4 calls stay under the gate" "$(verdicts)" "0"
jq -nc --arg s "$SID" '{session_id:$s}' | bash "$MUT3" >/dev/null 2>&1
check "without it, the verdict lines push it over" "$(verdicts)" "1"

printf '\n== nothing it does can break the turn ==\n'
varied_window 6
check "no claude on PATH -> 0, silently" \
      "$(PATH=/usr/bin:/bin fire >/dev/null 2>&1; echo $?)" "0"
check "  and no verdict is invented" "$(verdicts)" "0"
check "empty stdin -> 0"     "$(printf '' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON -> 0"  "$(printf '{nope' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "no session_id -> 0"   "$(printf '{}' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
check "absent ledger -> 0"   "$(jq -nc '{session_id:"nosuch"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)" "0"
reset
check "empty ledger -> 0"    "$(fire >/dev/null 2>&1; echo $?)" "0"
varied_window 6
: > "$TP"
check "an unresolvable transcript -> 0, no verdict" \
      "$(fire >/dev/null 2>&1; echo $?)" "0"
check "  and the model was spared" "$(stub_calls)" "0"

printf '\n== the report reaches the agent ==\n'
varied_window 6
e=$(fire_err)
has "stderr names the tier"   "$e" "tier 2"
has "  and the tool"          "$e" "Grep"
has "  and carries the reason" "$e" "re-running the same search"

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
