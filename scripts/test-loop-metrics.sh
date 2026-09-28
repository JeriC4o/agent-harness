#!/usr/bin/env bash
#
# Tests for loop-metrics.sh -- the ledger reader (GH-64). Run from anywhere:
#   bash scripts/test-loop-metrics.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
READER="${HERE}/loop-metrics.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
L="$W/sess-a.jsonl"
new() { : > "$L"; }
# Every fixture line carries the SAME ts on purpose: it is what a real ledger
# looks like at one-second resolution, and it is the input under which a reader
# keyed on time silently reports went_ahead for everything.
call() { jq -nc --arg t "$1" --arg f "$2" --arg id "$3" \
         '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:$t,fp:$f,
           tool_use_id:$id,transcript:"/tmp/x.jsonl"}' >> "$L"; }
# Same, but carrying cwd -- the exact project, as the hook records it today.
callp() { jq -nc --arg t "$1" --arg f "$2" --arg id "$3" --arg c "$4" \
         '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:$t,fp:$f,
           tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:$c}' >> "$L"; }
v1()   { jq -nc --arg t "$1" --arg f "$2" \
         '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:1,signal:"loop",tool:$t,
           fp:$f,count:3,agents:1,decision:"ask",window:20,threshold:3}' >> "$L"; }
# The COARSE gate firing: tier 2, no model verdict. This is what the hook writes.
v2()   { jq -nc --arg b "$1" --argjson j "$2" \
         '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:2,signal:"coarse-repeat",
           bin:$b,repeats:8,turn_calls:8,scope:"turn",min_bin_repeats:8,judged:$j}' >> "$L"; }
# The MODEL verdict on what tier 2 flagged: tier 3.
v3()   { jq -nc --arg b "$1" --arg v "$2" \
         '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:3,signal:"semantic-repeat",
           bin:$b,repeats:8,turn_calls:8,verdict:$v,model:"haiku",reason:"r"}' >> "$L"; }
turn() { jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"turn"}' >> "$L"; }
j() { bash "$READER" "$L" --json; }

printf '\n== it counts the two record classes apart ==\n'
new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a
r=$(j)
check "calls"    "$(printf '%s' "$r" | jq -r '.totals.calls')"    "3"
check "verdicts" "$(printf '%s' "$r" | jq -r '.totals.verdicts')" "1"
check "a verdict is not counted as a call" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].calls')" "3"

printf '\n== the outcome is derived from POSITION, not from the clock ==\n'
# Three calls then the verdict, nothing after: the verdict's own trigger must NOT
# count as a call that followed it.
new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a
check "no call after the verdict -> abandoned" \
      "$(j | jq -r '.projects[0].outcomes.abandoned')" "1"
check "  and not went_ahead" "$(j | jq -r '.projects[0].outcomes.went_ahead // 0')" "0"

new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a; call Bash a t4
check "the same fp afterwards -> went_ahead" \
      "$(j | jq -r '.projects[0].outcomes.went_ahead')" "1"

new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a; call Bash b t4
check "a different fp on the same tool -> reformulated" \
      "$(j | jq -r '.projects[0].outcomes.reformulated')" "1"

new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a; call Grep z t4
check "a call to ANOTHER tool does not decide it" \
      "$(j | jq -r '.projects[0].outcomes.abandoned')" "1"

printf '\n== POSITIVE CONTROL: key the outcome on ts, everything reads as went_ahead ==\n'
# Every fixture line shares a ts, so a reader comparing ts >= verdict.ts readmits
# the triggering call. This is the defect the reader shipped with until the
# fixture above caught it; without this control the position logic is untested.
MUT="$W/mut-ts.sh"
perl -0pe 's/select\(\.i > \$vi\.i and \.e\.kind == "call" and \.e\.tool == \$v\.tool\)/select(.e.kind == "call" and .e.tool == \$v.tool and .e.ts >= \$v.ts)/' \
  "$READER" > "$MUT"
check "the mutation applied" "$(grep -c '\.e\.ts >= \$v\.ts' "$MUT")" "1"
new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a
check "with position, the abandoned case is seen" "$(j | jq -r '.projects[0].outcomes.abandoned')" "1"
check "keyed on ts, the same ledger reads as went_ahead" \
      "$(bash "$MUT" "$L" --json | jq -r '.projects[0].outcomes.went_ahead')" "1"

printf '\n== the coarse gate and the model are counted SEPARATELY ==\n'
# They answer different questions: how often the cheap gate fires decides whether
# the judging stage is worth paying for, and what the model then says decides
# whether the gate is tuned right. One counter for both would conflate them.
new; turn; call Grep a t1; v2 grep false; turn; call Grep b t2; v2 grep true; v3 grep progress
r=$(j)
check "coarse firings" "$(printf '%s' "$r" | jq -r '.projects[0].tier2.fired')"  "2"
check "  of which judged" "$(printf '%s' "$r" | jq -r '.projects[0].tier2.judged')" "1"
check "  the busiest bin" "$(printf '%s' "$r" | jq -r '.projects[0].tier2.top_bin')" "grep"
check "turns counted"  "$(printf '%s' "$r" | jq -r '.projects[0].turns')"        "2"
check "model asked"    "$(printf '%s' "$r" | jq -r '.projects[0].tier3.asked')"    "1"
check "  and declining" "$(printf '%s' "$r" | jq -r '.projects[0].tier3.progress')" "1"
check "a verdict with no fp has no invented outcome" \
      "$(printf '%s' "$r" | jq -r '.projects[0].outcomes["n/a"]')" "3"

printf '\n== a ledger from the PREVIOUS schema is read, not miscounted ==\n'
# Before the gate was replaced, tier 2 carried the model verdict itself under
# signal "semantic-repeat". Six such records exist in a real ledger. Counting them
# as coarse firings would credit a detector that no longer exists; discarding them
# would throw away model calls that were really paid for and really answered.
new
for _ in 1 2 3; do
  jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:2,signal:"semantic-repeat",
           tool:"Bash",calls:20,distinct_fps:20,verdict:"progress",model:"haiku"}' >> "$L"
done
call Bash a t1
r=$(j)
check "no coarse firings are credited" "$(printf '%s' "$r" | jq -r '.projects[0].tier2.fired')" "0"
check "but the model verdicts are kept" "$(printf '%s' "$r" | jq -r '.projects[0].tier3.asked')" "3"
check "  as declines"                   "$(printf '%s' "$r" | jq -r '.projects[0].tier3.progress')" "3"
out=$(bash "$READER" "$L")
has "the report says why there are no turns" "$out" "before the turn-scoped gate existed"

printf '\n== outcomes are counted, and a missing one is NOT a pass ==\n'
# The recorder is newer than the index, so an older ledger has no result rows at
# all. Counting those calls as successes would invent a clean run out of absence.
res() { jq -nc --arg id "$1" --argjson k "$2" \
        '{ts:"2026-09-26T00:00:00Z",kind:"result",tool_use_id:$id,ok:$k}' >> "$L"; }
new; call Bash a t1; res t1 true; call Bash b t2; res t2 false; call Bash c t3
r=$(j)
check "ok"       "$(printf '%s' "$r" | jq -r '.projects[0].results.ok')"      "1"
check "failed"   "$(printf '%s' "$r" | jq -r '.projects[0].results.failed')"  "1"
check "unknown"  "$(printf '%s' "$r" | jq -r '.projects[0].results.unknown')" "1"
check "a result row is not counted as a call" \
      "$(printf '%s' "$r" | jq -r '.projects[0].calls')" "3"
out=$(bash "$READER" "$L")
has "the report names the failures" "$out" "1 failed"
has "  and says an outcome is missing" "$out" "no outcome recorded"

printf '\n== the report calls out a gate that fires every turn ==\n'
# The shape that killed the previous gate: firing once per turn is the signature
# of a filter that does not discriminate, not of a session that loops.
new; turn; call Grep a t1; v2 grep false
out=$(bash "$READER" "$L")
has "it names the shape rather than reporting a finding" "$out" "does not discriminate"
new; turn; turn; turn; call Grep a t1; v2 grep false
out=$(bash "$READER" "$L")
case "$out" in *"does not discriminate"*) bad "1 firing over 3 turns is not that shape" ;;
                                       *) ok "1 firing over 3 turns is not flagged" ;; esac
has "  and it says the judging stage is off" "$out" "switched off"

printf '\n== the abandonment rate carries its denominator ==\n'
new; call Bash a t1; v1 Bash a; call Bash a t2; call Bash c t3; v1 Bash c
r=$(j)
check "abandoned count" "$(printf '%s' "$r" | jq -r '.projects[0].abandonment.abandoned')" "1"
check "out of"          "$(printf '%s' "$r" | jq -r '.projects[0].abandonment.of')"        "2"
check "n/a rows are excluded from the denominator" \
      "$(new; call Grep a t1; v2 grep false; j | jq -r '.projects[0].abandonment')" "null"

printf '\n== an unknown kind never joins a count ==\n'
new; call Bash a t1; call Bash a t2
printf '%s\n' '{"ts":"2026-09-26T00:00:00Z","kind":"future","tool":"Bash","fp":"a"}' >> "$L"
r=$(j)
check "calls unchanged"    "$(printf '%s' "$r" | jq -r '.totals.calls')"    "2"
check "verdicts unchanged" "$(printf '%s' "$r" | jq -r '.totals.verdicts')" "0"

printf '\n== a quiet ledger is a result, not an empty report ==\n'
new; call Bash a t1; call Read b t2
out=$(bash "$READER" "$L")
has "it says nothing fired" "$out" "nothing fired"
has "  and how many calls passed" "$out" "2 calls"
has "  and refuses to read one run as a trend" "$out" "not a trend"

printf '\n== the human report names what it found ==\n'
new; call Bash a t1; call Bash a t2; call Bash a t3; v1 Bash a
out=$(bash "$READER" "$L")
has "abandonment is labelled as a stand-in, not a saving" "$out" "nearest stand-in"
has "per-session breakdown"                               "$out" "per session:"
has "and the session is named"                            "$out" "sess-a"

printf '\n== --all reads a directory, and sessions stay separate ==\n'
D="$W/loops"; mkdir -p "$D"
L="$D/s1.jsonl"; new; call Bash a t1; call Bash a t2
L="$D/s2.jsonl"; new; call Grep z t1
r=$(HARNESS_LOOP_DIR="$D" bash "$READER" --all --json)
check "both sessions"     "$(printf '%s' "$r" | jq -r '.totals.sessions')" "2"
check "calls are summed"  "$(printf '%s' "$r" | jq -r '.totals.calls')"    "3"
check "and not pooled -- a per-session row survives" \
      "$(printf '%s' "$r" | jq -r '[.sessions[].session] | sort | join(",")')" "s1,s2"
L="$W/sess-a.jsonl"

printf '\n== the project comes from cwd, exactly ==\n'
new; callp Bash a t1 /Users/me/work/alpha; callp Bash a t2 /Users/me/work/alpha
r=$(j)
check "the project is the cwd verbatim" \
      "$(printf '%s' "$r" | jq -r '.projects[0].project')" "/Users/me/work/alpha"
check "  and it is flagged as exact"   "$(printf '%s' "$r" | jq -r '.projects[0].exact')" "true"

printf '\n== without cwd it degrades, and SAYS it degraded ==\n'
new; call Bash a t1
r=$(j)
check "falls back to the transcript path" "$(printf '%s' "$r" | jq -r '.projects[0].project')" "tmp"
check "  and is NOT flagged exact"        "$(printf '%s' "$r" | jq -r '.projects[0].exact')" "false"
out=$(bash "$READER" "$L")
has "the report admits the recovery may be wrong" "$out" "may be wrong"

printf '\n== PROJECTS ARE NEVER POOLED ==\n'
# Two projects in one directory, each with its own verdict. A pooled rate would
# report one figure over both and read as a general result; the point of the
# ledger is per-codebase thresholds, so a mixed rate answers no question.
D2="$W/mixed"; mkdir -p "$D2"
L="$D2/alpha.jsonl"; new
callp Bash a t1 /Users/me/work/alpha; callp Bash a t2 /Users/me/work/alpha
callp Bash a t3 /Users/me/work/alpha; v1 Bash a
L="$D2/beta.jsonl";  new
callp Grep z t1 /Users/me/work/beta; callp Grep z t2 /Users/me/work/beta
callp Grep z t3 /Users/me/work/beta; v1 Grep z; callp Grep z t4 /Users/me/work/beta
r=$(HARNESS_LOOP_DIR="$D2" bash "$READER" --all --json)
check "two projects, kept apart" "$(printf '%s' "$r" | jq -r '.totals.projects')" "2"
check "alpha abandoned its call" \
      "$(printf '%s' "$r" | jq -r '.projects[] | select(.project|endswith("alpha")) | .outcomes.abandoned')" "1"
check "beta went ahead with its" \
      "$(printf '%s' "$r" | jq -r '.projects[] | select(.project|endswith("beta")) | .outcomes.went_ahead')" "1"
check "abandonment is per project, not one pooled figure" \
      "$(printf '%s' "$r" | jq -r '[.projects[].abandonment.of] | join(",")')" "1,1"
check "totals stay an INVENTORY -- no pooled rate exists to misread" \
      "$(printf '%s' "$r" | jq -r '.totals | has("abandonment") or has("outcomes")')" "false"
out=$(HARNESS_LOOP_DIR="$D2" bash "$READER" --all)
has "and the report says rates are never pooled" "$out" "never pooled"
has "  naming the first project"  "$out" "/Users/me/work/alpha"
has "  and the second"            "$out" "/Users/me/work/beta"
L="$W/sess-a.jsonl"

printf '\n== usage errors are loud ==\n'
check "no argument -> 2"        "$(bash "$READER" >/dev/null 2>&1; echo $?)" "2"
check "missing file -> 2"       "$(bash "$READER" /nope/x.jsonl >/dev/null 2>&1; echo $?)" "2"
check "unknown flag -> 2"       "$(bash "$READER" --wat >/dev/null 2>&1; echo $?)" "2"
check "--all with a path -> 2"  "$(bash "$READER" --all "$L" >/dev/null 2>&1; echo $?)" "2"
check "--all with no dir -> 2"  "$(HARNESS_LOOP_DIR=/nope bash "$READER" --all >/dev/null 2>&1; echo $?)" "2"
new
check "an empty ledger -> 2, not a silent zero" "$(bash "$READER" "$L" >/dev/null 2>&1; echo $?)" "2"

printf '\n== the entry point is executable ==\n'
check "loop-metrics.sh carries the execute bit" "$( [ -x "$READER" ] && echo yes || echo no )" "yes"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
