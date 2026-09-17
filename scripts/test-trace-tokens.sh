#!/usr/bin/env bash
#
# Tests for trace-tokens.sh — per-stage token accounting from session transcripts.
# Run from anywhere:  bash scripts/test-trace-tokens.sh
#
# Fixtures are SYNTHETIC. No real transcript is read by this suite: transcripts
# contain everything a session saw, and a test corpus that quotes them would
# recreate the exact leak the tracer exists to avoid.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
TRACE="${HERE}/trace-tokens.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3])" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected [$3])" ;; *) ok "$1" ;; esac; }

# --- fixture builders ---------------------------------------------------------
# amsg <file> <msgid> <ts> <in> <out> <cache_read> <cache_create> <attr|-> <sidechain> [text]
amsg() {
  local f=$1 id=$2 ts=$3 i=$4 o=$5 cr=$6 cc=$7 attr=$8 sc=$9 txt=${10:-hello}
  jq -cn --arg id "$id" --arg ts "$ts" --argjson i "$i" --argjson o "$o" \
        --argjson cr "$cr" --argjson cc "$cc" --arg attr "$attr" \
        --argjson sc "$sc" --arg txt "$txt" '
    { type:"assistant", timestamp:$ts, isSidechain:$sc,
      message:{ id:$id, role:"assistant", content:[{type:"text",text:$txt}],
                usage:{ input_tokens:$i, output_tokens:$o,
                        cache_read_input_tokens:$cr, cache_creation_input_tokens:$cc } } }
    | if $attr == "-" then . else . + {attributionSkill:$attr} end' >> "$f"
}
# uturn <file> <ts> <text>   — a human turn
uturn() {
  jq -cn --arg ts "$2" --arg t "$3" \
    '{type:"user",timestamp:$ts,isSidechain:false,message:{role:"user",content:$t}}' >> "$1"
}
# tresult <file> <ts> <text> — a tool result (NOT a human turn)
tresult() {
  jq -cn --arg ts "$2" --arg t "$3" \
    '{type:"user",timestamp:$ts,isSidechain:false,
      message:{role:"user",content:[{type:"tool_result",content:$t}]}}' >> "$1"
}

newsession() { # -> prints session jsonl path
  local d; d=$(mktemp -d); mkdir -p "$d/sess/subagents"; : > "$d/sess.jsonl"; printf '%s/sess.jsonl' "$d"
}

J() { bash "$TRACE" "$1" --json 2>/dev/null; }

printf '\n== a message split across lines is counted ONCE ==\n'
# The failure this pins: one API message becomes several JSONL lines (thinking,
# text, tool_use), and EVERY line repeats the whole usage object. Summing lines
# overcounts by ~60% on a real session.
S=$(newsession)
amsg "$S" m1 2026-01-01T00:00:00Z 11 100 100000 700 - false
amsg "$S" m1 2026-01-01T00:00:01Z 11 100 100000 700 - false
amsg "$S" m1 2026-01-01T00:00:02Z 11 100 100000 700 - false
amsg "$S" m2 2026-01-01T00:00:10Z 22 200 200000 800 - false
out=$(J "$S")
check "messages counted by id, not by line" "$(jq -r '.messages' <<<"$out")" "2"
check "duplicate lines are reported, not hidden" "$(jq -r '.duplicate_lines_discarded' <<<"$out")" "2"
check "fresh = input + output, deduped"          "$(jq -r '.totals.main.fresh' <<<"$out")" "333"
check "cache_read is separate from fresh"        "$(jq -r '.totals.main.cache_read' <<<"$out")" "300000"
check "cache_creation is separate too"           "$(jq -r '.totals.main.cache_creation' <<<"$out")" "1500"

printf '\n== subagent spend is found at all, and kept separate ==\n'
# The failure this pins: subagents are NOT inline in the session transcript --
# they live in <session>/subagents/*.jsonl. A tracer reading only the session
# file reports subagent cost as zero, which is exactly backwards: the spawning
# stage looks cheap precisely when it was expensive.
S=$(newsession); D=$(dirname "$S")
amsg "$S" m1 2026-01-01T00:00:00Z 11 100 100000 700 - false
amsg "$D/sess/subagents/agent-aaa.jsonl" s1 2026-01-01T00:00:05Z 3 30 50000 60 - true
out=$(J "$S")
check "subagent files are discovered"      "$(jq -r '.totals.subagents.count' <<<"$out")" "1"
check "subagent fresh is attributed to it" "$(jq -r '.totals.subagents.fresh' <<<"$out")" "33"
check "main total excludes subagent spend" "$(jq -r '.totals.main.fresh' <<<"$out")" "111"
check "all = main + subagents"             "$(jq -r '.totals.all.fresh' <<<"$out")" "144"

printf '\n== turns are the unit, and a human prompt is what opens one ==\n'
# WHY TURNS, not "stages". Measured against a real session, both stage models
# failed. Terminating a skill span at a human turn dumped 95% of spend into
# "(no skill)" -- the user answering /task's own questions ended the stage.
# Terminating it at the next Skill call instead let one skill absorb 392
# messages of unrelated later work. The runtime's `attributionSkill` is the only
# ground truth and it is sparse, so anything built on top of it across turns is
# a guess. A turn boundary is not a guess: the user pressed enter.
S=$(newsession)
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 - false
uturn "$S"    2026-01-01T00:02:00Z "second thing"
amsg "$S" m2 2026-01-01T00:03:00Z 22 200 0 0 - false
amsg "$S" m3 2026-01-01T00:04:00Z 33 300 0 0 - false
out=$(J "$S")
check "one turn per human prompt, plus the opening turn" "$(jq -r '.turns|length' <<<"$out")" "2"
check "the opening turn holds pre-prompt work"           "$(jq -r '.turns[0].fresh' <<<"$out")" "111"
check "the second turn accumulates its own messages"     "$(jq -r '.turns[1].fresh' <<<"$out")" "555"
check "turn message counts are per turn"                 "$(jq -r '.turns[1].messages' <<<"$out")" "2"

printf '\n== a tool result does not open a turn ==\n'
# The session talking to itself is not the user talking. Treating a tool_result
# as a boundary would shatter every turn into one-message fragments.
S=$(newsession)
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 - false
tresult "$S" 2026-01-01T00:01:30Z "some tool output"
amsg "$S" m2 2026-01-01T00:02:00Z 22 200 0 0 - false
out=$(J "$S")
check "tool results stay inside the turn" "$(jq -r '.turns|length' <<<"$out")" "1"
check "and their work is counted there"   "$(jq -r '.turns[0].fresh' <<<"$out")" "333"

printf '\n== a skill label attaches to the turn the runtime tagged ==\n'
S=$(newsession)
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 harness:task false
amsg "$S" m2 2026-01-01T00:02:00Z 22 200 0 0 -           false
out=$(J "$S")
check "the turn carries the skill name" "$(jq -r '.turns[0].skill' <<<"$out")" "harness:task"
check "runtime-tagged spend is exact"   "$(jq -r '.turns[0].fresh_attributed' <<<"$out")" "111"
check "the untagged tail is carried WITHIN the turn" "$(jq -r '.turns[0].fresh_carried' <<<"$out")" "222"
check "and the turn total is both"      "$(jq -r '.turns[0].fresh' <<<"$out")" "333"

printf '\n== carry-forward NEVER crosses a turn boundary ==\n'
# This is the bound that keeps the inference honest. Without it one skill
# invocation bills for every unrelated thing the user asks afterwards.
S=$(newsession)
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 harness:task false
uturn "$S"    2026-01-01T00:02:00Z "something unrelated"
amsg "$S" m2 2026-01-01T00:03:00Z 22 200 0 0 - false
out=$(J "$S")
check "the next turn is unlabelled, not billed to the skill" "$(jq -r '.turns[1].skill // "null"' <<<"$out")" "null"
check "its spend stays its own"                              "$(jq -r '.turns[1].fresh' <<<"$out")" "222"
check "the skill total excludes the later turn"              "$(jq -r '[.skills[]|select(.skill=="harness:task")]|.[0].fresh' <<<"$out")" "111"

printf '\n== the by-skill roll-up counts only labelled turns ==\n'
S=$(newsession)
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 harness:task false
uturn "$S"    2026-01-01T00:02:00Z "next"
amsg "$S" m2 2026-01-01T00:03:00Z 22 200 0 0 harness:task false
uturn "$S"    2026-01-01T00:04:00Z "unrelated"
amsg "$S" m3 2026-01-01T00:05:00Z 33 300 0 0 -           false
out=$(J "$S")
check "two turns of the same skill roll up" \
  "$(jq -r '[.skills[]|select(.skill=="harness:task")]|.[0].fresh' <<<"$out")" "333"
check "unlabelled work is not invented into a skill" \
  "$(jq -r '[.skills[]|select(.skill=="harness:task")]|.[0].turns' <<<"$out")" "2"

printf '\n== the by-skill roll-up adds up ==\n'
# A turn can begin before its skill is invoked: the model reads the prompt and
# decides to call the Skill, and that opening work is not the skill's. Rolling
# it into the skill total printed `29,997 = 17,205 + 0` on a real session -- a
# row that does not add up reads as an arithmetic bug and costs the reader all
# trust in the rest of the table.
S=$(newsession)
amsg "$S" m0 2026-01-01T00:01:00Z 5 50 0 0 -           false
amsg "$S" m1 2026-01-01T00:02:00Z 11 100 0 0 harness:task false
amsg "$S" m2 2026-01-01T00:03:00Z 22 200 0 0 -           false
out=$(J "$S")
check "the turn total still counts everything in the turn" "$(jq -r '.turns[0].fresh' <<<"$out")" "388"
check "the skill total excludes the pre-invocation opening" \
  "$(jq -r '[.skills[]|select(.skill=="harness:task")]|.[0].fresh' <<<"$out")" "333"
check "and exact + carried equals the skill total" \
  "$(jq -r '[.skills[]|select(.skill=="harness:task")]|.[0]|(.fresh_attributed + .fresh_carried)' <<<"$out")" "333"

printf '\n== a prompt that produced no assistant message is still a prompt ==\n'
# Turn indices come from prompts; rows come from spend. Reporting only the row
# count printed "61 turns" beside a row numbered 78.
S=$(newsession)
uturn "$S" 2026-01-01T00:01:00Z "one"
uturn "$S" 2026-01-01T00:02:00Z "two"
amsg "$S" m1 2026-01-01T00:03:00Z 11 100 0 0 - false
out=$(J "$S")
check "turns with spend are counted"     "$(jq -r '.turns_total' <<<"$out")" "1"
check "prompts are counted separately"   "$(jq -r '.prompts_total' <<<"$out")" "2"
check "the surviving turn keeps its index" "$(jq -r '.turns[0].index' <<<"$out")" "2"

printf '\n== a subagent is billed to the turn it was spawned in ==\n'
S=$(newsession); D=$(dirname "$S")
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 harness:task false
amsg "$D/sess/subagents/agent-aaa.jsonl" s1 2026-01-01T00:01:30Z 3 30 0 0 - true
uturn "$S"    2026-01-01T00:02:00Z "later"
amsg "$S" m2 2026-01-01T00:03:00Z 22 200 0 0 - false
out=$(J "$S")
check "the spawning turn carries the count"   "$(jq -r '.turns[0].subagents' <<<"$out")" "1"
check "the later turn does not"               "$(jq -r '.turns[1].subagents' <<<"$out")" "0"
check "the subagent row names its turn"       "$(jq -r '.subagents[0].turn' <<<"$out")" "0"
check "and the skill it ran under"            "$(jq -r '.subagents[0].skill' <<<"$out")" "harness:task"
check "subagent id is unique, not the slug"   "$(jq -r '.subagents[0].agent_id' <<<"$out")" "aaa"

printf '\n== it emits COUNTS, never content ==\n'
# Transcripts hold everything the session saw, including ASK-gated files. A
# tracer that echoed any of it would be a worse leak than the one it measures.
S=$(newsession); D=$(dirname "$S")
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 - false "CANARY_IN_ASSISTANT_TEXT"
uturn "$S" 2026-01-01T00:02:00Z "CANARY_IN_USER_PROMPT"
tresult "$S" 2026-01-01T00:02:30Z "CANARY_IN_TOOL_RESULT"
amsg "$D/sess/subagents/agent-aaa.jsonl" s1 2026-01-01T00:03:00Z 3 30 0 0 - true "CANARY_IN_SUBAGENT"
human=$(bash "$TRACE" "$S" 2>&1)
json=$(bash "$TRACE" "$S" --json 2>&1)
for c in CANARY_IN_ASSISTANT_TEXT CANARY_IN_USER_PROMPT CANARY_IN_TOOL_RESULT CANARY_IN_SUBAGENT; do
  hasnt "human output withholds $c" "$human" "$c"
  hasnt "json output withholds  $c" "$json"  "$c"
done

printf '\n== malformed and missing input ==\n'
S=$(newsession)
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 0 0 - false
printf 'this is not json\n' >> "$S"
jq -cn '{type:"assistant",timestamp:"2026-01-01T00:02:00Z",isSidechain:false,message:{id:"m9",role:"assistant"}}' >> "$S"
out=$(bash "$TRACE" "$S" --json 2>/dev/null)
check "a message with no usage block does not crash it" "$(jq -r '.totals.main.fresh' <<<"$out")" "111"
has   "the unparseable line is reported, not swallowed" "$(bash "$TRACE" "$S" 2>&1)" "unparseable"

printf '\n== usage ==\n'
bash "$TRACE" >/dev/null 2>&1;              check "no args -> 2"      "$?" "2"
bash "$TRACE" /nonexistent.jsonl >/dev/null 2>&1; check "missing file -> 2" "$?" "2"
E=$(newsession)
bash "$TRACE" "$E" >/dev/null 2>&1;         check "an empty transcript is not an error" "$?" "0"

printf '\n== the human report is readable ==\n'
S=$(newsession); D=$(dirname "$S")
amsg "$S" m1 2026-01-01T00:01:00Z 11 100 1000 0 harness:task false
amsg "$D/sess/subagents/agent-aaa.jsonl" s1 2026-01-01T00:01:30Z 3 30 500 0 - true
rep=$(bash "$TRACE" "$S" 2>&1)
has "names the three numbers separately" "$rep" "cache_read"
has "shows a subagent section"           "$rep" "Subagents"
has "shows the skill"                    "$rep" "harness:task"
has "shows a per-turn table"             "$rep" "turn"

printf '\n== --top bounds the turn table without changing the totals ==\n'
# A 500-turn session must not print 500 rows, and trimming the VIEW must never
# trim the ARITHMETIC -- a total that shrinks when you narrow the display is the
# quietest way for this tool to lie.
S=$(newsession)
i=1
while [ $i -le 6 ]; do
  uturn "$S" "2026-01-01T00:0${i}:00Z" "turn $i"
  amsg "$S" "mm$i" "2026-01-01T00:0${i}:30Z" 10 "$((i * 100))" 0 0 - false
  i=$((i+1))
done
full=$(bash "$TRACE" "$S" --json | jq -r '.totals.main.fresh')
rep=$(bash "$TRACE" "$S" --top 2 2>&1)
rows=$(printf '%s\n' "$rep" | awk '/^== Costliest turns/{f=1;next} f&&/^$/{exit} f&&/^ +[0-9]+ +[0-9]/{c++} END{print c+0}')
# No work precedes the first prompt here, so there is no opening turn 0: six
# prompts produce exactly six turns.
check "the JSON keeps every turn"      "$(bash "$TRACE" "$S" --json | jq -r '.turns|length')" "6"
check "--top trims the rows shown"     "$rows" "2"
check "totals are unchanged by --top"  "$(bash "$TRACE" "$S" --top 2 --json | jq -r '.totals.main.fresh')" "$full"
has   "the report says what it hid"    "$rep" "of 6 turns"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
