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

printf '\n== --for: the single-session view /inspect reads ==\n'
FD="$W/for"; mkdir -p "$FD/loops" "$FD/projects/-proj/sess1/subagents"
MAINTX="$FD/projects/-proj/sess1.jsonl"
SUBTX="$FD/projects/-proj/sess1/subagents/agent-AAA.jsonl"
FL="$FD/loops/sess1.jsonl"
# A transcript line as the client writes it: the tool_use id is the join key.
tu()    { jq -nc --arg i "$2" \
          '{message:{content:[{type:"tool_use",id:$i,name:"Bash",input:{command:"x"}}]}}' >> "$1"; }
# A ledger call as the HOOK writes it -- agent_id "main" on every row, which is
# what the live hook actually stores for a subagent's call too. The fixture has
# to carry that wrong value, or the recovery under test has nothing to correct.
fcall() { jq -nc --arg id "$1" \
          '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:"Bash",fp:"f",
            bin:"Bash:grep",tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/Users/me/work/alpha"}' >> "$FL"; }
: > "$MAINTX"; : > "$SUBTX"; : > "$FL"
tu "$MAINTX" t1; tu "$MAINTX" t2
tu "$SUBTX" t3
fcall t1; fcall t2; fcall t3; fcall t4
f() { HARNESS_LOOP_DIR="$FD/loops" bash "$READER" --for "$1" --json; }

r=$(f "$MAINTX")
check "it resolves the ledger from a transcript path" \
      "$(printf '%s' "$r" | jq -r '.available')" "true"
check "  naming the session" "$(printf '%s' "$r" | jq -r '.session')" "sess1"
check "attribution: the main agent's calls" \
      "$(printf '%s' "$r" | jq -r '.attribution.by_agent.main')" "2"
check "attribution: the subagent's, which the stored agent_id cannot give" \
      "$(printf '%s' "$r" | jq -r '.attribution.by_agent.AAA')" "1"
check "a call in no transcript stays unattributed, never folded into main" \
      "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "1"
check "  and the stored field is shown beside it, wrong and visible" \
      "$(printf '%s' "$r" | jq -r '.attribution.stored_agent_ids | join(",")')" "main"

r=$(f "$SUBTX")
check "a SUBAGENT transcript resolves to its PARENT session" \
      "$(printf '%s' "$r" | jq -r '.session')" "sess1"
check "  reaching the same ledger, not none" "$(printf '%s' "$r" | jq -r '.calls')" "4"

# A REAL transcript whose session never got a ledger. The two absences are
# different questions and get different answers: a transcript that is not there
# is the caller handing over a path that does not resolve, and it stops the run;
# a ledger that is not there is a fact about the session, and it is reported.
MISS="$FD/projects/-proj/nope.jsonl"
tu "$MISS" z1
r=$(HARNESS_LOOP_DIR="$FD/loops" bash "$READER" --for "$MISS" --json)
check "an absent ledger is a REPORTED unavailable" \
      "$(printf '%s' "$r" | jq -r '.available')" "false"
has "  whose reason refuses to be read as clean" \
    "$(printf '%s' "$r" | jq -r '.reason')" "NOT a clean result"
check "  at rc 0, so /inspect goes on to its other passes" \
      "$(HARNESS_LOOP_DIR="$FD/loops" bash "$READER" --for "$MISS" >/dev/null 2>&1; echo $?)" "0"

# A verdict has to be LOCATABLE, not merely counted: without these fields the
# reader knows something fired and cannot go and read the turn it fired on.
jq -nc '{ts:"2026-09-26T00:00:01Z",kind:"verdict",tier:2,signal:"coarse-repeat",
         bin:"Bash:grep",repeats:8,turn_calls:9,scope:"turn",min_bin_repeats:8,judged:false}' >> "$FL"
r=$(f "$MAINTX")
check "a verdict row carries the ts that locates it in the run" \
      "$(printf '%s' "$r" | jq -r '.rows[0].ts')" "2026-09-26T00:00:01Z"
check "  the shape it fired on"      "$(printf '%s' "$r" | jq -r '.rows[0].bin')" "Bash:grep"
check "  the count it fired at"      "$(printf '%s' "$r" | jq -r '.rows[0].repeats')" "8"
check "  the threshold it fired under" \
      "$(printf '%s' "$r" | jq -r '.rows[0].settings.min_bin_repeats')" "8"

printf '\n== --for: a positive control per guard ==\n'
# Each control deletes ONE guard and requires the damage to reappear. Without
# them every assertion above passes byte-identically with the guard removed.
M1="$W/mut-subagent-path.sh"
perl -0pe 's/SESSION=\$\(basename "\$\(dirname "\$\(dirname "\$TRANSCRIPT"\)"\)"\)/SESSION=\$(basename "\$TRANSCRIPT" .jsonl)/' \
  "$READER" > "$M1"
check "the mutation applied" "$(grep -c 'dirname "\$(dirname' "$M1")" "1"
check "without the subagent-path arm, a subagent transcript finds no ledger at all" \
      "$(HARNESS_LOOP_DIR="$FD/loops" bash "$M1" --for "$SUBTX" --json | jq -r '.available')" "false"

M2="$W/mut-no-subagent-scan.sh"
perl -0pe 's/ids_of "\$s" "\$\{a#agent-\}" \|\| note_bad "\$s"/:/' "$READER" > "$M2"
check "the mutation applied" "$(grep -c 'ids_of "\$s"' "$M2")" "0"
r=$(HARNESS_LOOP_DIR="$FD/loops" bash "$M2" --for "$MAINTX" --json)
check "without the subagent scan, the subagent's calls vanish from the census" \
      "$(printf '%s' "$r" | jq -r '.attribution.by_agent.AAA // "absent"')" "absent"
check "  and are counted as unattributed rather than as main's" \
      "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "2"

M3="$W/mut-stored-agent.sh"
perl -0pe 's/\$by_id\[\.tool_use_id\] \/\/ "unattributed"/.agent_id/' "$READER" > "$M3"
check "the mutation applied" "$(grep -c 'by_id\[.tool_use_id\] \/\/ "unattributed"' "$M3")" "0"
check "reading the STORED agent_id instead puts every call on main -- the live defect" \
      "$(HARNESS_LOOP_DIR="$FD/loops" bash "$M3" --for "$MAINTX" --json | jq -r '.attribution.by_agent.main')" "4"

M4="$W/mut-no-unavailable.sh"
perl -0pe 's/if \[ ! -s "\$LEDGER" \]; then/if false; then/' "$READER" > "$M4"
check "the mutation applied" "$(grep -c 'if false; then' "$M4")" "1"
out=$(HARNESS_LOOP_DIR="$FD/loops" bash "$M4" --for "$MISS" 2>&1)
case "$out" in
  *"NOT a clean result"*) bad "without the guard, an absent ledger still named itself" ;;
  *)                      ok  "without the guard, an absent ledger says nothing that names itself" ;;
esac

printf '\n== --for: an ABSENT transcript is loud, not a confident wrong census ==\n'
# Attribution is a lookup in that file. With the file gone every id resolves to
# nothing, so the census reads 100% unattributed while the call and verdict
# counts beside it stay correct -- the one figure that is wrong is the one with
# no other figure to contradict it.
# Same BASENAME as the real transcript, so the session still resolves to a
# ledger that exists -- otherwise the control would be stopped by the absent
# ledger instead and would prove nothing about the absent transcript.
GONE="$FD/gone/sess1.jsonl"
check "a transcript that does not exist -> 2" \
      "$(HARNESS_LOOP_DIR="$FD/loops" bash "$READER" --for "$GONE" >/dev/null 2>&1; echo $?)" "2"
has "  and the message says the ledger is still readable on its own" \
    "$(HARNESS_LOOP_DIR="$FD/loops" bash "$READER" --for "$GONE" 2>&1)" "read the ledger directly"

M5="$W/mut-no-transcript-check.sh"
perl -0pe 's/if \[ ! -f "\$TRANSCRIPT" \]; then/if false; then/' "$READER" > "$M5"
check "the mutation applied" "$(grep -c 'if false; then' "$M5")" "1"
r=$(HARNESS_LOOP_DIR="$FD/loops" bash "$M5" --for "$GONE" --json 2>/dev/null)
check "without the check it answers at rc 0" \
      "$(HARNESS_LOOP_DIR="$FD/loops" bash "$M5" --for "$GONE" >/dev/null 2>&1; echo $?)" "0"
check "  with every call unattributed -- the whole census wrong" \
      "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "4"
check "  while the call count beside it stays right" \
      "$(printf '%s' "$r" | jq -r '.calls')" "4"

printf '\n== --for: a transcript jq cannot parse is reported, not absorbed ==\n'
# jq stops at the first bad line, so everything after it silently disappears
# from the census and reappears as "unattributed" -- which the reader is
# otherwise told to read as a call in flight.
BD="$W/bad"; mkdir -p "$BD/loops" "$BD/projects/-proj"
BTX="$BD/projects/-proj/sess3.jsonl"; BL="$BD/loops/sess3.jsonl"
: > "$BTX"; : > "$BL"
jq -nc '{message:{content:[{type:"tool_use",id:"t1",name:"Bash",input:{}}]}}' >> "$BTX"
printf '{ this is not json\n' >> "$BTX"
jq -nc '{message:{content:[{type:"tool_use",id:"t2",name:"Bash",input:{}}]}}' >> "$BTX"
for i in t1 t2; do
  jq -nc --arg id "$i" '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:"Bash",
    fp:"f",bin:"Bash:grep",tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/p"}' >> "$BL"
done
r=$(HARNESS_LOOP_DIR="$BD/loops" bash "$READER" --for "$BTX" --json)
check "the unparseable transcript is named" \
      "$(printf '%s' "$r" | jq -r '.attribution.unreadable_transcripts | length')" "1"
check "  so the census declares itself incomplete" \
      "$(printf '%s' "$r" | jq -r '.attribution.complete')" "false"
has "  and the human report says the census is wrong, not partial" \
    "$(HARNESS_LOOP_DIR="$BD/loops" bash "$READER" --for "$BTX")" "ATTRIBUTION IS INCOMPLETE"
case "$(HARNESS_LOOP_DIR="$BD/loops" bash "$READER" --for "$BTX")" in
  *"one in flight"*) bad "the benign in-flight gloss was offered on an incomplete census" ;;
  *)                 ok  "and the benign in-flight gloss is withheld" ;;
esac

M6="$W/mut-swallow-parse-error.sh"
perl -0pe 's/ids_of "\$MAIN" main \|\| note_bad "\$MAIN"/ids_of "\$MAIN" main || true/' "$READER" > "$M6"
check "the mutation applied" "$(grep -c 'note_bad "\$MAIN"' "$M6")" "0"
r=$(HARNESS_LOOP_DIR="$BD/loops" bash "$M6" --for "$BTX" --json)
check "swallowing jq's status reports a complete census over truncated input" \
      "$(printf '%s' "$r" | jq -r '.attribution.complete')" "true"
check "  while a call really did fall out of it" \
      "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "1"

printf '\n== --for: unattributed is a bucket, not an agent ==\n'
# A single-agent LIVE session always has a call in flight. Counting that bucket
# as an agent turns it into a false report of two agents and fires the fan-out
# note on a session that never spawned anything.
SD="$W/solo"; mkdir -p "$SD/loops" "$SD/projects/-proj"
STX="$SD/projects/-proj/sess4.jsonl"; SL="$SD/loops/sess4.jsonl"
: > "$STX"; : > "$SL"
jq -nc '{message:{content:[{type:"tool_use",id:"t1",name:"Bash",input:{}}]}}' >> "$STX"
for i in t1 t9; do
  jq -nc --arg id "$i" '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:"Bash",
    fp:"f",bin:"Bash:grep",tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/p"}' >> "$SL"
done
out=$(HARNESS_LOOP_DIR="$SD/loops" bash "$READER" --for "$STX")
case "$out" in
  *"transcripts show"*) bad "the fan-out note fired on a session with one agent" ;;
  *)                    ok  "one agent plus a call in flight is not two agents" ;;
esac
has "  and the in-flight call is still reported" "$out" "consistent with work in flight"

M7="$W/mut-bucket-as-agent.sh"
perl -0pe 's/\(\.by_agent \| keys \| map\(select\(\. != "unattributed"\)\) \| length\) as \$n/(.by_agent | keys | length) as \$n/' \
  "$READER" > "$M7"
check "the mutation applied" "$(grep -c 'select(. != "unattributed")' "$M7")" "0"
case "$(HARNESS_LOOP_DIR="$SD/loops" bash "$M7" --for "$STX")" in
  *"transcripts show 2 agent"*) ok "counting the bucket as an agent invents a second one" ;;
  *)                            bad "the control did not reproduce the false fan-out note" ;;
esac

printf '\n== --for: an unattributed call in the MIDDLE is not work in flight ==\n'
# The case `complete` could not see before: a subagent transcript that is simply
# ABSENT is invisible to both "was the main file read" and "did anything fail to
# parse". Position is the thing that can be checked -- a call with no transcript
# record because it is still executing is necessarily among the LAST in the
# ledger, so one in the middle is a transcript nobody opened.
GD="$W/gap"; mkdir -p "$GD/loops" "$GD/projects/-proj/sess5/subagents"
GTX="$GD/projects/-proj/sess5.jsonl"; GL="$GD/loops/sess5.jsonl"
: > "$GTX"; : > "$GL"
gcall() { jq -nc --arg id "$1" '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:"Bash",
    fp:"f",bin:"Bash:grep",tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/p"}' >> "$GL"; }
# The main transcript accounts for the first and last call; the six in between
# were a subagent whose transcript is not there.
tu "$GTX" g1
for i in g1 s1 s2 s3 s4 s5 s6 g2; do gcall "$i"; done
tu "$GTX" g2
r=$(HARNESS_LOOP_DIR="$GD/loops" bash "$READER" --for "$GTX" --json)
check "the main transcript WAS read"       "$(printf '%s' "$r" | jq -r '.attribution.main_transcript_read')" "true"
check "nothing failed to parse"            "$(printf '%s' "$r" | jq -r '.attribution.unreadable_transcripts | length')" "0"
check "  yet the census is declared wrong" "$(printf '%s' "$r" | jq -r '.attribution.complete')" "false"
check "  because the gap is not at the tail" \
      "$(printf '%s' "$r" | jq -r '.attribution.unattributed_at_tail')" "false"
out=$(HARNESS_LOOP_DIR="$GD/loops" bash "$READER" --for "$GTX")
has "  and the report says so, naming the cause" "$out" "not work in flight"
case "$out" in
  *"consistent with work in flight"*) bad "the benign gloss fired on a mid-ledger gap" ;;
  *)                                  ok  "and the benign gloss is withheld" ;;
esac

M8="$W/mut-no-tail-test.sh"
perl -0pe 's/and \$ua_tail\),/),/' "$READER" > "$M8"
check "the mutation applied" "$(grep -c 'and \$ua_tail),' "$M8")" "0"
r=$(HARNESS_LOOP_DIR="$GD/loops" bash "$M8" --for "$GTX" --json)
check "without the position test, six misattributed calls read as complete" \
      "$(printf '%s' "$r" | jq -r '.attribution.complete')" "true"
case "$(HARNESS_LOOP_DIR="$GD/loops" bash "$M8" --for "$GTX")" in
  *"consistent with work in flight"*) ok "and the benign gloss returns to explain them away" ;;
  *)                                  bad "the control did not reproduce the false reassurance" ;;
esac

printf '\n== --for: two unreadable transcripts are two paths, not one ==\n'
# Command substitution strips trailing newlines, so a separator spelled
# $(printf '\n') is the empty string and the paths concatenate into one that
# exists nowhere -- printed verbatim as the file to go and look at. A fixture
# with ONE bad transcript is byte-identical either way.
TD="$W/two"; mkdir -p "$TD/loops" "$TD/projects/-proj/sess6/subagents"
TTX="$TD/projects/-proj/sess6.jsonl"; TL="$TD/loops/sess6.jsonl"
: > "$TTX"; : > "$TL"
printf '{ not json\n' >> "$TTX"
for a in AAA BBB; do printf '{ not json\n' > "$TD/projects/-proj/sess6/subagents/agent-$a.jsonl"; done
jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:"Bash",fp:"f",bin:"Bash:grep",
         tool_use_id:"x1",transcript:"/tmp/x.jsonl",cwd:"/p"}' >> "$TL"
r=$(HARNESS_LOOP_DIR="$TD/loops" bash "$READER" --for "$TTX" --json)
check "three unreadable transcripts are three entries" \
      "$(printf '%s' "$r" | jq -r '.attribution.unreadable_transcripts | length')" "3"
check "  and every entry is a path that exists" \
      "$(printf '%s' "$r" | jq -r '[.attribution.unreadable_transcripts[]] | length')" \
      "$(printf '%s' "$r" | jq -r '[.attribution.unreadable_transcripts[] | select(test("^/"))] | length')"

M9="$W/mut-empty-separator.sh"
perl -0pe 's/note_bad\(\) \{ BAD_TX="\$\{BAD_TX\}\$\{BAD_TX:\+\$NL\}\$1"; \}/note_bad() { BAD_TX="\${BAD_TX}\${BAD_TX:+\$(printf \x27\\\\n\x27)}\$1"; }/' \
  "$READER" > "$M9"
check "the mutation applied" "$(grep -c 'BAD_TX:+\$NL' "$M9")" "0"
check "with the separator stripped, three paths collapse into one" \
      "$(HARNESS_LOOP_DIR="$TD/loops" bash "$M9" --for "$TTX" --json | jq -r '.attribution.unreadable_transcripts | length')" "1"

printf '\n== --for: usage errors are loud, and say WHICH ==\n'
# `bash <script>` also exits 2 on a SYNTAX error, so an exit-status assertion on
# its own passes identically against a script that does not parse. This one
# assertion makes every rc-2 check in the file mean what it says; the message
# checks below pin each one to its own cause rather than to a shared 2.
check "the reader parses at all" "$(bash -n "$READER" 2>&1; echo $?)" "0"
rc2() { # $1 label, $2 expected message fragment, rest: args
  local label="$1" want="$2"; shift 2
  local err rc
  err=$(bash "$READER" "$@" 2>&1 >/dev/null); rc=$?
  if [ "$rc" != "2" ]; then bad "$label (want rc 2, got $rc)"; return; fi
  case "$err" in *"$want"*) ok "$label" ;; *) bad "$label (rc 2 but message was [$err])" ;; esac
}
rc2 "--for with no path -> 2, naming the missing argument" "needs a transcript path" --for
rc2 "--for with --all -> 2, naming the conflict"           "different questions" --for "$MAINTX" --all
rc2 "--for with a ledger too -> 2, naming the confusion"   "not the ledger"      --for "$MAINTX" "$FL"

printf '\n== the entry point is executable ==\n'
check "loop-metrics.sh carries the execute bit" "$( [ -x "$READER" ] && echo yes || echo no )" "yes"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
