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

printf '\n== it counts the record classes apart ==\n'
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
# A ledger call as the HOOK writes it. agent_id defaults to "main" -- the value
# the live hook stored for every row, a subagent's included, so the recovery
# under test has something to correct. A caller that passes one is writing what a
# post-fix hook would have stored, which is what lets the two records disagree.
acall() { jq -nc --arg id "$1" --arg a "$2" \
          '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:$a,tool:"Bash",fp:"f",
            bin:"Bash:grep",tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/Users/me/work/alpha"}' >> "$3"; }
fcall() { acall "$1" "${2:-main}" "$FL"; }
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

# The counters are written to the LEDGER by the hook and asserted there by
# hooks/lib/test-loop-verdict.sh. That says nothing about whether they survive
# the reader: the $rows projection is an allowlist, and the inspector never opens
# the ledger -- it reads this JSON. Selected by tier rather than by index so the
# assertion does not depend on row order.
jq -nc '{ts:"2026-09-26T00:00:02Z",kind:"verdict",tier:3,signal:"semantic-repeat",
         bin:"Bash:grep",repeats:8,turn_calls:9,verdict:"progress",model:"m",
         reason:"PROGRESS ok",flagged_calls:8,unresolved_calls:5}' >> "$FL"
r=$(f "$MAINTX")
check "a tier-3 row reaches the reader with the evidence it rested on" \
      "$(printf '%s' "$r" | jq -r '.rows[] | select(.tier == 3) | .flagged_calls')" "8"
check "  and with how much of that evidence was missing" \
      "$(printf '%s' "$r" | jq -r '.rows[] | select(.tier == 3) | .unresolved_calls')" "5"

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
perl -0pe 's/if ids_of "\$s" "\$\{a#agent-\}"; then note_ok "\$\{a#agent-\}"; else note_bad "\$s"; fi/:/' "$READER" > "$M2"
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
has "  and the report says so, naming the likely cause" "$out" "transcript this reader never opened"
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

printf '\n== --for: a fully attributed session is complete, and says nothing alarming ==\n'
# THE BRANCH THAT DECIDES EVERY REAL SESSION. On live data `unattributed` is 0,
# so `$ua == 0 or ...` is the leg that answers -- and every other fixture in this
# file carries at least one unattributed call, which left it with no assertion at
# all. It is not protecting against an error: jq's `[] | min` is null and
# `null >= 0` is false, so without the short-circuit `complete` would be FALSE on
# every healthy session and the report would open with ATTRIBUTION IS INCOMPLETE.
CD="$W/clean"; mkdir -p "$CD/loops" "$CD/projects/-proj"
CTX="$CD/projects/-proj/sess7.jsonl"; CL="$CD/loops/sess7.jsonl"
: > "$CTX"; : > "$CL"
for i in c1 c2 c3; do
  tu "$CTX" "$i"
  jq -nc --arg id "$i" '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:"main",tool:"Bash",
    fp:"f",bin:"Bash:grep",tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/p"}' >> "$CL"
done
r=$(HARNESS_LOOP_DIR="$CD/loops" bash "$READER" --for "$CTX" --json)
check "no call is unattributed"    "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "0"
check "  the tail test holds"      "$(printf '%s' "$r" | jq -r '.attribution.unattributed_at_tail')" "true"
# A ledger written before the hook could tell the agents apart names only main,
# so the new leg has nothing to require and must not move this verdict.
check "  the read test holds vacuously, the ledger naming only main" \
      "$(printf '%s' "$r" | jq -r '.attribution.every_stored_agent_read')" "true"
check "  and the census is complete" "$(printf '%s' "$r" | jq -r '.attribution.complete')" "true"
out=$(HARNESS_LOOP_DIR="$CD/loops" bash "$READER" --for "$CTX")
case "$out" in
  *"ATTRIBUTION IS INCOMPLETE"*) bad "a fully attributed session was reported as incomplete" ;;
  *)                             ok  "and the report raises nothing" ;;
esac

M10="$W/mut-no-zero-guard.sh"
perl -0pe 's/\( \$ua == 0 or \(\$ua_idx \| min\)/( (\$ua_idx | min)/' "$READER" > "$M10"
check "the mutation applied" "$(grep -c '\$ua == 0 or' "$M10")" "0"
check "without the zero guard, a clean session reads as incomplete" \
      "$(HARNESS_LOOP_DIR="$CD/loops" bash "$M10" --for "$CTX" --json | jq -r '.attribution.complete')" "false"
case "$(HARNESS_LOOP_DIR="$CD/loops" bash "$M10" --for "$CTX")" in
  *"ATTRIBUTION IS INCOMPLETE"*) ok "and every healthy session opens with a false alarm" ;;
  *)                             bad "the control did not reproduce the false alarm" ;;
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
# Reproduce the bug by its EFFECT, which is what it was: the separator expanded
# to nothing. Rewriting the line to the literal pre-fix spelling would have to
# smuggle an apostrophe through a single-quoted perl program, and the escaping
# that survives that emits a two-character backslash-n instead -- a mutant that
# fails the assertion for a different reason than the one it claims.
perl -0pe 's/\$\{BAD_TX:\+\$NL\}/\$\{BAD_TX:+\}/' "$READER" > "$M9"
check "the mutation applied" "$(grep -c 'BAD_TX:+\$NL' "$M9")" "0"
check "with the separator stripped, three paths collapse into one" \
      "$(HARNESS_LOOP_DIR="$TD/loops" bash "$M9" --for "$TTX" --json | jq -r '.attribution.unreadable_transcripts | length')" "1"

printf '\n== --for: the stored agent_id is CHECKED against the transcripts, not just shown ==\n'
# Two records answer the same question from opposite ends -- the hook wrote who
# it thought was calling, the transcripts say who was. A reader that only prints
# the stored value can be wrong in exactly one direction and never say so.
AG="$W/agree"; mkdir -p "$AG/loops" "$AG/projects/-proj/sess8/subagents"
AGTX="$AG/projects/-proj/sess8.jsonl"; AGL="$AG/loops/sess8.jsonl"
AGSUB="$AG/projects/-proj/sess8/subagents"
: > "$AGTX"; : > "$AGL"
tu "$AGTX" a1; tu "$AGTX" a2
tu "$AGSUB/agent-AAA.jsonl" a3; tu "$AGSUB/agent-AAA.jsonl" a4
tu "$AGSUB/agent-BBB.jsonl" a5
acall a1 main "$AGL"; acall a2 AAA "$AGL"; acall a3 AAA "$AGL"
acall a4 main "$AGL"; acall a5 BBB "$AGL"; acall a9 main "$AGL"
r=$(HARNESS_LOOP_DIR="$AG/loops" bash "$READER" --for "$AGTX" --json)
check "every call with a recovered agent is checked" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.checked')" "5"
check "  the ones the hook got right are confirmed" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.confirmed')" "3"
check "  the ones it got wrong are refuted" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.refuted')" "2"
check "  and a refutation names the call it is about" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.refutations[0].tool_use_id')" "a2"
check "  carrying what was stored" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.refutations[0].stored')" "AAA"
check "  and what was recovered" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.refutations[0].recovered')" "main"
check "a call no transcript accounts for stays unattributed" \
      "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "1"
# The comparison has nothing to say about a call it could not recover, so
# counting it either way would turn an absence into a confirmation or a fault.
check "  and is counted in none of the three" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.checked + .attribution.unattributed == .calls')" "true"
check "every stored agent had its transcript read" \
      "$(printf '%s' "$r" | jq -r '.attribution.every_stored_agent_read')" "true"
check "  so none is listed as unread" \
      "$(printf '%s' "$r" | jq -r '.attribution.stored_agents_unread | length')" "0"
out=$(HARNESS_LOOP_DIR="$AG/loops" bash "$READER" --for "$AGTX")
has "the human report names a disagreeing call" "$out" "a2"
has "  with both values, so it can be gone and checked" "$out" "stored=AAA recovered=main"
case "$out" in
  *"NOTE: this ledger was written"*) bad "the blind-ledger note fired on a ledger carrying real agent ids" ;;
  *)                                 ok  "and the blind-ledger note is withheld" ;;
esac
pre=$(HARNESS_LOOP_DIR="$FD/loops" bash "$READER" --for "$MAINTX")
has "the note still fires where every stored row says main" "$pre" "written by a build that stored agent_id=main"
has "  and dates the blindness to that build, not this reader" "$pre" "when these rows were written"
has "  saying the attribution beside it was recovered here" "$pre" "recovered at read time"

printf '\n== --for: the refutation list is capped; the count is not ==\n'
# A session that fans out wide can disagree on every call. The list is evidence,
# so it is bounded; the count is the measurement, so it is not.
CP="$W/cap"; mkdir -p "$CP/loops" "$CP/projects/-proj/sess9/subagents"
CPTX="$CP/projects/-proj/sess9.jsonl"; CPL="$CP/loops/sess9.jsonl"
: > "$CPTX"; : > "$CPL"; : > "$CP/projects/-proj/sess9/subagents/agent-ZZZ.jsonl"
for i in 1 2 3 4 5 6 7; do tu "$CPTX" "r$i"; acall "r$i" ZZZ "$CPL"; done
r=$(HARNESS_LOOP_DIR="$CP/loops" bash "$READER" --for "$CPTX" --json)
check "seven disagreements are seven refutations" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.refuted')" "7"
check "  of which the list carries five" \
      "$(printf '%s' "$r" | jq -r '.attribution.agreement.refutations | length')" "5"
# Opened, parsed, and it held no tool call -- which is why the list of transcripts
# read cannot be inferred from the ids recovered out of them.
check "a transcript that parses and yields no id still counts as read" \
      "$(printf '%s' "$r" | jq -r '.attribution.every_stored_agent_read')" "true"

printf '\n== --for: a stored agent whose transcript was never opened is named ==\n'
# The live shape: a subagent whose transcript file lags. Every other completeness
# test passes here, so a leg that cannot explain its own false branch would open
# the report with an alarm and point the reader at a count of zero.
UR="$W/unread"; mkdir -p "$UR/loops" "$UR/projects/-proj/sess10"
URTX="$UR/projects/-proj/sess10.jsonl"; URL="$UR/loops/sess10.jsonl"
: > "$URTX"; : > "$URL"
tu "$URTX" m1; tu "$URTX" m2
acall m1 main "$URL"; acall m2 CCC "$URL"
r=$(HARNESS_LOOP_DIR="$UR/loops" bash "$READER" --for "$URTX" --json)
check "the main transcript WAS read"   "$(printf '%s' "$r" | jq -r '.attribution.main_transcript_read')" "true"
check "  nothing failed to parse"      "$(printf '%s' "$r" | jq -r '.attribution.unreadable_transcripts | length')" "0"
check "  no call is unattributed"      "$(printf '%s' "$r" | jq -r '.attribution.unattributed')" "0"
check "  yet a stored agent was never read" \
      "$(printf '%s' "$r" | jq -r '.attribution.every_stored_agent_read')" "false"
check "  and the record names which"   "$(printf '%s' "$r" | jq -r '.attribution.stored_agents_unread | join(",")')" "CCC"
check "  so the census is not complete" "$(printf '%s' "$r" | jq -r '.attribution.complete')" "false"
out=$(HARNESS_LOOP_DIR="$UR/loops" bash "$READER" --for "$URTX")
has "the report says the census is wrong" "$out" "ATTRIBUTION IS INCOMPLETE"
has "  gives this leg's own reason"       "$out" "whose transcript was never opened"
has "  and names the agent"               "$out" "CCC"

printf '\n== --for a positive control per new guard ==\n'
M11="$W/mut-no-agreement.sh"
perl -0pe 's/select\(\.stored != \.recovered\)/select(false)/' "$READER" > "$M11"
check "the mutation applied" "$(grep -c 'select(.stored != .recovered)' "$M11")" "0"
check "without the comparison, two wrong stored ids read as agreement" \
      "$(HARNESS_LOOP_DIR="$AG/loops" bash "$M11" --for "$AGTX" --json | jq -r '.attribution.agreement.refuted')" "0"
case "$(HARNESS_LOOP_DIR="$AG/loops" bash "$M11" --for "$AGTX")" in
  *"stored=AAA recovered=main"*) bad "the control did not remove the disagreement line" ;;
  *)                             ok  "and the human report stops naming the call it got wrong" ;;
esac

M12="$W/mut-no-read-leg.sh"
perl -0pe 's/\$every_read and \$ua_tail/\$ua_tail/' "$READER" > "$M12"
check "the mutation applied" "$(grep -c 'every_read and \$ua_tail' "$M12")" "0"
check "without the leg, a ledger naming an unread agent reads as complete" \
      "$(HARNESS_LOOP_DIR="$UR/loops" bash "$M12" --for "$URTX" --json | jq -r '.attribution.complete')" "true"

M13="$W/mut-no-unread-clause.sh"
perl -0pe 's/\+ \(if \.every_stored_agent_read then "" else [^\n]*end\)\n//' "$READER" > "$M13"
check "the mutation applied" "$(grep -c 'whose transcript was never opened' "$M13")" "0"
# The reason arm comes FIRST. Asking only whether the header and the closing
# sentence are both present matches the unmutated reader too, which prints the
# reason between them -- a control that passes whether or not it mutated.
case "$(HARNESS_LOOP_DIR="$UR/loops" bash "$M13" --for "$URTX")" in
  *"whose transcript was never opened"*) bad "the control did not remove the fourth clause" ;;
  *"ATTRIBUTION IS INCOMPLETE"*"Treat the 0 unattributed call(s)"*)
      ok "without the fourth clause the alarm returns with no reason and a count of zero" ;;
  *)  bad "the control did not reproduce the reasonless INCOMPLETE line" ;;
esac

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

# ---------------------------------------------------------------------------
printf '\n== the attribution canary: starts recorded, no non-main caller ==\n'
# ---------------------------------------------------------------------------
# WHY THIS EXISTS. An absent or non-string agent_id degrades to the literal
# "main" in the hook, which is indistinguishable from a genuine main-agent call.
# Ten of twelve field ledgers recorded every subagent that way with no symptom.
# A count of subagent STARTS makes "N started, zero non-main call rows"
# self-contradictory, and that is the only thing the canary claims.
mark() { # <agent_id> <ledger>
  jq -nc --arg a "$1" \
    '{ts:"2026-09-26T00:00:00Z",kind:"agent-mark",agent_id:$a,agent_type:"general-purpose"}' >> "$2"
}
mcall() { # <tool_use_id> <agent_id> <ledger>
  jq -nc --arg id "$1" --arg a "$2" \
    '{ts:"2026-09-26T00:00:00Z",kind:"call",agent_id:$a,tool:"Bash",fp:"f",
      tool_use_id:$id,transcript:"/tmp/x.jsonl",cwd:"/Users/me/work/canary"}' >> "$3"
}

CN="$W/canary"; mkdir -p "$CN/loops"
CNL="$CN/loops/sess-degraded.jsonl"
: > "$CNL"
mcall c1 main "$CNL"; mark AAA "$CNL"; mcall c2 main "$CNL"; mark BBB "$CNL"; mcall c3 main "$CNL"
# AC16's "without scanning any transcript" is asserted by the FIXTURE, not by a
# sentence about the code: the directory holds the ledger and nothing else, so a
# reader that needed a transcript could not have read one.
check "precondition: the fixture tree holds the ledger and no transcript at all" \
      "$(find "$CN" -name '*.jsonl' | wc -l | tr -d ' ')" "1"
r=$(HARNESS_LOOP_DIR="$CN/loops" bash "$READER" --all --json)
check "the starts are counted" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].agent_marks')" "2"
check "  and their distinct ids" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].agent_mark_ids')" "2"
check "  while no call row names a non-main agent" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].call_agents_sub')" "0"
check "the agent-mark rows are NOT counted as calls" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].calls')" "3"
out=$(HARNESS_LOOP_DIR="$CN/loops" bash "$READER" --all)
has "the contradiction is printed in --all, the view with no transcript access at all" \
    "$out" "ATTRIBUTION CANARY: 2 subagent start(s) recorded"
has "  and the bound is stated rather than left to be inferred" \
    "$out" "zero recorded starts cannot separate"

printf '\n-- the negative control: starts and non-main call rows AGREE --\n'
AGREE="$W/canary-ok"; mkdir -p "$AGREE/loops"
AGL="$AGREE/loops/sess-fine.jsonl"
: > "$AGL"
mcall c1 main "$AGL"; mark AAA "$AGL"; mcall c2 AAA "$AGL"; mcall c3 main "$AGL"
r=$(HARNESS_LOOP_DIR="$AGREE/loops" bash "$READER" --all --json)
check "the start is counted here too" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].agent_marks')" "1"
check "  and a non-main caller IS on the record, so there is no contradiction" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].call_agents_sub')" "1"
out=$(HARNESS_LOOP_DIR="$AGREE/loops" bash "$READER" --all)
case "$out" in
  *"ATTRIBUTION CANARY"*) bad "the canary fired on a session whose records agree" ;;
  *)                      ok "nothing is printed when the two records agree" ;;
esac

printf '\n-- zero starts says nothing either way, and the report admits it --\n'
NONE="$W/canary-none"; mkdir -p "$NONE/loops"
NL2="$NONE/loops/sess-quiet.jsonl"
: > "$NL2"
mcall c1 main "$NL2"; mcall c2 main "$NL2"
out=$(HARNESS_LOOP_DIR="$NONE/loops" bash "$READER" --all)
case "$out" in
  *"ATTRIBUTION CANARY"*) bad "the canary fired with no starts recorded, which it cannot know anything about" ;;
  *)                      ok "no starts recorded -> no claim made" ;;
esac
has "  and the one-directional bound is printed anyway, which is where it matters" \
    "$out" "the canary itself is not firing"

printf '\n-- POSITIVE CONTROL: admit main into the non-main count and the canary goes blind --\n'
# This is the exact hazard the method's test conventions name: a filter keyed on
# the property that separates a real finding from a dismissable one structurally
# excludes the case the finding exists to confirm. Here the property IS the
# "main" literal, so admitting it is the one-token defect that silences the
# canary on every session it was built for.
MC1="$W/mut-canary-admits-main.sh"
# Anchored on `call_agents_sub`, because the same filter spelling appears twice
# in the reader -- here and in the --for unread-agent census -- and an unanchored
# substitution silently mutates whichever comes first. The count assertion that
# went with the unanchored form read 1 remaining and failed while the mutation
# had in fact landed, which is the weaker half of the same confusion.
perl -0pe 's/(call_agents_sub: .*?)select\(\. != null and \. != "main"\)/$1select(. != null)/s' "$READER" > "$MC1"
check "the mutation applied to the canary field and not to its namesake" \
      "$(grep -c 'call_agents_sub: (\[ $calls\[\] | .agent_id | select(. != null) \]' "$MC1")" "1"
check "  and the --for census kept its own copy of the filter" \
      "$(grep -c 'select(. != null and . != "main")' "$MC1")" "1"
r=$(HARNESS_LOOP_DIR="$CN/loops" bash "$MC1" --all --json)
check "without the main exclusion, the degraded session reports a non-main caller" \
      "$(printf '%s' "$r" | jq -r '.sessions[0].call_agents_sub')" "1"
case "$(HARNESS_LOOP_DIR="$CN/loops" bash "$MC1" --all)" in
  *"ATTRIBUTION CANARY"*) bad "the mutated reader still fired, so the exclusion is not what makes it work" ;;
  *)                      ok "and the contradiction disappears -- the exclusion is load-bearing" ;;
esac

printf '\n-- POSITIVE CONTROL: count agent-mark rows as calls and the contradiction self-cancels --\n'
MC2="$W/mut-canary-marks-are-calls.sh"
perl -0pe 's/select\(\.kind == "agent-mark"\) \] \| length\)/select(.kind == "agent-mark" or .kind == "call") ] | length)/' "$READER" > "$MC2"
check "the mutation applied" "$(grep -c 'agent-mark" or .kind == "call"' "$MC2")" "1"
check "a mark count that also counts calls reads 5 where the truth is 2" \
      "$(HARNESS_LOOP_DIR="$CN/loops" bash "$MC2" --all --json | jq -r '.sessions[0].agent_marks')" "5"

# ---------------------------------------------------------------------------
printf '\n== AC17: the report is unchanged except for the three new fields ==\n'
# ---------------------------------------------------------------------------
# The same ledger with and without the marks, with the three fields deleted from
# both: anything else that moved is a reading the new row class disturbed.
A17="$W/ac17-with"; B17="$W/ac17-without"
mkdir -p "$A17/loops" "$B17/loops"
AL="$A17/loops/sess-x.jsonl"; BL="$B17/loops/sess-x.jsonl"
: > "$AL"; : > "$BL"
for led in "$AL" "$BL"; do
  mcall c1 main "$led"; mcall c2 main "$led"; mcall c3 main "$led"
  jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"result",tool_use_id:"c1",ok:true}' >> "$led"
  jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"turn"}' >> "$led"
  jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:1,signal:"loop",tool:"Bash",
           fp:"f",count:3,agents:1,decision:"ask",window:20,window_unit:"calls",threshold:3}' >> "$led"
done
mark AAA "$AL"; mark BBB "$AL"; mark CCC "$AL"
strip='del(.sessions[].agent_marks, .sessions[].agent_mark_ids, .sessions[].call_agents_sub)'
wa=$(HARNESS_LOOP_DIR="$A17/loops" bash "$READER" --all --json | jq -S "$strip")
wo=$(HARNESS_LOOP_DIR="$B17/loops" bash "$READER" --all --json | jq -S "$strip")
if [ "$wa" = "$wo" ]; then
  ok "three marks change nothing else in the whole report"
else
  bad "a field other than the three moved when agent-mark rows were added"
  printf '%s\n' "$wa" > "$W/ac17-a.json"; printf '%s\n' "$wo" > "$W/ac17-b.json"
  diff "$W/ac17-a.json" "$W/ac17-b.json" | sed -n '1,12p'
fi
# The converse control: without it the comparison above is also what a reader
# that cannot see the marks at all would report.
check "control: the marks WERE present and were counted" \
      "$(HARNESS_LOOP_DIR="$A17/loops" bash "$READER" --all --json | jq -r '.sessions[0].agent_marks')" "3"
check "control: and absent from the other leg" \
      "$(HARNESS_LOOP_DIR="$B17/loops" bash "$READER" --all --json | jq -r '.sessions[0].agent_marks')" "0"

# ---------------------------------------------------------------------------
printf '\n== settings.window_unit survives the allowlist projection ==\n'
# ---------------------------------------------------------------------------
# `window` changed meaning without changing shape, so a projection that drops
# the unit hands the reader two incomparable numbers under one name.
check "a post-change verdict row carries its unit through" \
      "$(HARNESS_LOOP_DIR="$A17/loops" bash "$READER" --all --json | jq -r '.sessions[0].rows[0].settings.window_unit')" "calls"
check "  beside the window it qualifies" \
      "$(HARNESS_LOOP_DIR="$A17/loops" bash "$READER" --all --json | jq -r '.sessions[0].rows[0].settings.window')" "20"
LEG="$W/legacy-unit"; mkdir -p "$LEG/loops"
LGL="$LEG/loops/sess-old.jsonl"
: > "$LGL"
mcall c1 main "$LGL"
jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:1,signal:"loop",tool:"Bash",
         fp:"f",count:3,agents:1,decision:"ask",window:20,threshold:3}' >> "$LGL"
# A ROW WITH A WINDOW AND NO UNIT READS "lines", and that is an inference from a
# build marker rather than a guess: only a pre-change build wrote a window with
# no unit beside it, and that build counted LINES. Reading it as "calls" would
# assert the one thing false of every pre-change row; reading it as null would
# discard a fact the row carries and leave "written before the change"
# indistinguishable from "this reader does not know", which is exactly the
# distinction the field was added to make. Both wrong answers are asserted
# against below, because a test that only rules out "calls" would have accepted
# the null this suite previously pinned.
unit_of() { HARNESS_LOOP_DIR="$1" bash "$READER" --all --json | jq -r '.sessions[0].rows[0].settings.window_unit'; }
check "a pre-change row reads \"lines\", inferred from the window it does carry" \
      "$(unit_of "$LEG/loops")" "lines"
check "  and specifically NOT null, which would discard the inference" \
      "$( [ "$(unit_of "$LEG/loops")" = "null" ] && echo discarded || echo kept )" "kept"
check "  and NOT \"calls\", which is the one thing false of every pre-change row" \
      "$( [ "$(unit_of "$LEG/loops")" = "calls" ] && echo wrong || echo right )" "right"

# THE INFERENCE IS KEYED ON THE WINDOW, so a row that carries no window has
# nothing to infer from and must stay null. Without this, "default to lines"
# would quietly stamp a unit onto tier-2 and tier-3 rows, which have no window
# and for which "lines" is not wrong so much as meaningless.
NOW2="$W/nowindow"; mkdir -p "$NOW2/loops"
NWL="$NOW2/loops/sess-nw.jsonl"
: > "$NWL"
mcall c1 main "$NWL"
jq -nc '{ts:"2026-09-26T00:00:00Z",kind:"verdict",tier:2,signal:"coarse-repeat",
         bin:"Bash:grep",repeats:8,turn_calls:8,scope:"turn",min_bin_repeats:8,judged:false}' >> "$NWL"
check "precondition: that row really carries no window" \
      "$(HARNESS_LOOP_DIR="$NOW2/loops" bash "$READER" --all --json | jq -r '.sessions[0].rows[0].settings.window // "absent"')" "absent"
check "a row with no window has no unit to infer, and stays null" \
      "$(unit_of "$NOW2/loops")" "null"

MC3="$W/mut-no-window-unit.sh"
perl -0pe 's/window_unit: \(\$v\.window_unit\n *\/\/ \(if \(\$v\.window \/\/ null\) == null then null else "lines" end\)\),\n *//' "$READER" > "$MC3"
check "the mutation applied" "$(grep -c 'window_unit: (\$v.window_unit' "$MC3")" "0"
check "dropped from the projection, the unit is gone even though the row carries it" \
      "$(HARNESS_LOOP_DIR="$A17/loops" bash "$MC3" --all --json | jq -r '.sessions[0].rows[0].settings.window_unit // "absent"')" "absent"
# The second mutation: keep the field but drop the INFERENCE, which is the exact
# form this suite shipped before the design was re-read. It must not pass.
MC4="$W/mut-no-lines-inference.sh"
perl -0pe 's/\(\$v\.window_unit\n *\/\/ \(if \(\$v\.window \/\/ null\) == null then null else "lines" end\)\)/(\$v.window_unit \/\/ null)/' "$READER" > "$MC4"
check "the mutation applied" "$(grep -c 'window_unit: (\$v.window_unit // null)' "$MC4")" "1"
check "without the inference a pre-change row reads null again -- the shipped defect" \
      "$(HARNESS_LOOP_DIR="$LEG/loops" bash "$MC4" --all --json | jq -r '.sessions[0].rows[0].settings.window_unit')" "null"

# ---------------------------------------------------------------------------
printf '\n== --for prints the same contradiction, computed once ==\n'
# ---------------------------------------------------------------------------
# --for slurps per_session's output as its base, so the two views cannot
# disagree about the number -- but the LINE is a second piece of code and gets
# its own case. The transcripts here are complete, so the canary is not standing
# in for a failed recovery: both records are present and they disagree.
CF="$W/canary-for"; mkdir -p "$CF/loops" "$CF/projects/-proj/sess9/subagents"
CFTX="$CF/projects/-proj/sess9.jsonl"
CFL="$CF/loops/sess9.jsonl"
: > "$CFTX"; : > "$CFL"
tu "$CFTX" c1; tu "$CFTX" c2
mcall c1 main "$CFL"; mcall c2 main "$CFL"; mark AAA "$CFL"
r=$(HARNESS_LOOP_DIR="$CF/loops" bash "$READER" --for "$CFTX" --json)
check "--for carries the three fields, read off the same per_session output" \
      "$(printf '%s' "$r" | jq -r '[.agent_marks, .agent_mark_ids, .call_agents_sub] | join(",")')" "1,1,0"
check "  and its attribution census is complete, so the canary is not a stand-in for a failed scan" \
      "$(printf '%s' "$r" | jq -r '.attribution.complete')" "true"
out=$(HARNESS_LOOP_DIR="$CF/loops" bash "$READER" --for "$CFTX")
has "the contradiction prints in --for too" "$out" "ATTRIBUTION CANARY: 1 subagent start(s) recorded"
has "  naming the distinct ids it saw" "$out" "(1 distinct agent id(s))"
has "  and the bound is on this view as well" "$out" "the canary itself is not firing"

printf '\n== the entry point is executable ==\n'
check "loop-metrics.sh carries the execute bit" "$( [ -x "$READER" ] && echo yes || echo no )" "yes"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
