#!/usr/bin/env bash
#
# Tests for session-events.sh — the mechanical pre-pass behind /harness:inspect.
# Run from anywhere:  bash scripts/test-session-events.sh
#
# Fixtures are SYNTHETIC. A transcript holds everything a session saw, including
# ASK-gated files; a test corpus quoting one would recreate the leak this script
# is built to avoid.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
EV="${HERE}/session-events.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3])" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected [$3])" ;; *) ok "$1" ;; esac; }

# --- fixtures -----------------------------------------------------------------
newsession() { local d; d=$(mktemp -d); mkdir -p "$d/sess/subagents"; : > "$d/sess.jsonl"; printf '%s/sess.jsonl' "$d"; }

# tool <file> <ts> <tool> <input-json> [msgid]
tool() {
  jq -cn --arg ts "$2" --arg n "$3" --argjson inp "$4" --arg id "${5:-m$RANDOM}" \
    '{type:"assistant",timestamp:$ts,isSidechain:false,
      message:{id:$id,role:"assistant",
               content:[{type:"tool_use",id:("t"+$id),name:$n,input:$inp}],
               usage:{input_tokens:1,output_tokens:1,cache_read_input_tokens:0,cache_creation_input_tokens:0}}}' >> "$1"
}
# result <file> <ts> <is_error> <tool_use_id> <text>
# A real tool_result carries tool_use_id; that link is the only thing tying an
# error back to the call that caused it.
result() {
  jq -cn --arg ts "$2" --argjson e "$3" --arg u "$4" --arg t "$5" \
    '{type:"user",timestamp:$ts,isSidechain:false,
      message:{role:"user",content:[{type:"tool_result",tool_use_id:$u,is_error:$e,content:$t}]}}' >> "$1"
}
uturn() {
  jq -cn --arg ts "$2" --arg t "$3" \
    '{type:"user",timestamp:$ts,isSidechain:false,message:{role:"user",content:$t}}' >> "$1"
}
# spend <file> <ts> <msgid> <cache_read>
spend() {
  jq -cn --arg ts "$2" --arg id "$3" --argjson cr "$4" \
    '{type:"assistant",timestamp:$ts,isSidechain:false,
      message:{id:$id,role:"assistant",content:[{type:"text",text:"x"}],
               usage:{input_tokens:1,output_tokens:1,cache_read_input_tokens:$cr,cache_creation_input_tokens:0}}}' >> "$1"
}
S_() { bash "$EV" "$1" --signatures 2>/dev/null; }
sig() { jq -r --arg k "$2" '[.signatures[]|select(.kind==$k)]|length' <<<"$1"; }

printf '\n== the event stream is one line per event, and carries no content ==\n'
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"git status CANARY_CMD"}'
result "$S" 2026-01-01T00:00:11Z false tX "CANARY_RESULT"
uturn "$S" 2026-01-01T00:00:20Z "CANARY_PROMPT"
tool "$S" 2026-01-01T00:00:30Z Read '{"file_path":"/secret/CANARY_PATH.txt"}'
stream=$(bash "$EV" "$S" 2>&1)
sigs=$(bash "$EV" "$S" --signatures 2>&1)
for c in CANARY_CMD CANARY_RESULT CANARY_PROMPT CANARY_PATH; do
  hasnt "event stream withholds $c" "$stream" "$c"
  hasnt "signatures withhold   $c" "$sigs"   "$c"
done
has "names the tool"                "$stream" "Bash"
has "names the bash binary only"    "$stream" "git"
has "marks the prompt boundary"     "$stream" "prompt"

printf '\n== the bash label cannot smuggle a path out ==\n'
# Found by reading real output, not by reasoning: a command beginning with a
# variable assignment put "SP=/private/tmp/.../scratchpad;" straight into the
# label column. "First token only" is safe for `git status`; it is not safe for
# `VAR=/some/path cmd`, or for an absolute path invoked directly. The label is
# now a validated command NAME or nothing.
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"SECRET=/tmp/CANARY_ASSIGN/x make test"}' a
tool "$S" 2026-01-01T00:00:20Z Bash '{"command":"/opt/CANARY_ABS/tool run"}'             b
tool "$S" 2026-01-01T00:00:30Z Bash '{"command":"cd /tmp/CANARY_CD && ls"}'              c
tool "$S" 2026-01-01T00:00:40Z Bash '{"command":"git status"}'                           d
stream=$(bash "$EV" "$S" 2>&1)
hasnt "an assignment prefix does not leak"  "$stream" "CANARY_ASSIGN"
hasnt "an absolute binary path does not leak" "$stream" "CANARY_ABS"
hasnt "a cd target does not leak"           "$stream" "CANARY_CD"
has   "the real command behind an assignment still shows" "$stream" "make"
has   "and a plain command name survives"   "$stream" "git"

printf '\n== subcommands, because "gh" alone cannot tell filing from reading ==\n'
# The label used to be the first token only, which made `gh issue create`
# indistinguishable from `gh pr view` -- so the privacy rule blocked the very
# measurement it was needed for. Up to two further tokens are now kept, each of
# which must be a KNOWN SUBCOMMAND VERB. An allowlist rather than a pattern is
# the point: a branch name matches any reasonable pattern, and a branch name can
# carry a project identifier.
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"git status"}'                          a
tool "$S" 2026-01-01T00:00:20Z Bash '{"command":"git checkout CANARY-secret-branch"}'   b
tool "$S" 2026-01-01T00:00:30Z Bash '{"command":"gh issue create --title CANARY_TITLE"}' c
tool "$S" 2026-01-01T00:00:40Z Bash '{"command":"git commit -m CANARY_MSG"}'            d
stream=$(bash "$EV" "$S" 2>&1)
has   "a known subcommand is kept"        "$stream" "git status"
has   "two levels deep for gh"            "$stream" "gh issue create"
has   "and the verb before a flag"        "$stream" "git commit"
hasnt "a branch name is not a subcommand" "$stream" "CANARY-secret-branch"
hasnt "nor is a commit message"           "$stream" "CANARY_MSG"
hasnt "nor a ticket title"                "$stream" "CANARY_TITLE"

printf '\n== filing a ticket from inside a struggling turn ==\n'
# The failure mode: a task will not converge, so the agent files a ticket and
# moves on -- deferring is cheaper than admitting it did not work. A ticket
# filed during a normal turn is ordinary planning and must NOT be flagged; one
# filed inside a turn that already went round and round is the suspicious shape.
S=$(newsession)
i=1
while [ $i -le 6 ]; do
  uturn "$S" "2026-01-01T00:0${i}:00Z" "turn $i"
  spend "$S" "2026-01-01T00:0${i}:30Z" "s$i" 1000
  i=$((i+1))
done
uturn "$S" 2026-01-01T00:07:00Z "the one that would not converge"
j=1
while [ $j -le 20 ]; do spend "$S" "2026-01-01T00:07:${j}0Z" "d$j" 1000; j=$((j+1)); done
tool "$S" 2026-01-01T00:07:55Z Bash '{"command":"gh issue create --title later"}' zz
out=$(S_ "$S")
check "a ticket filed in a deep turn is flagged" "$(sig "$out" deferral-candidate)" "1"
check "and it names the turn" \
  "$(jq -r '[.signatures[]|select(.kind=="deferral-candidate")]|.[0].turn' <<<"$out")" "7"

S=$(newsession)
i=1
while [ $i -le 6 ]; do
  uturn "$S" "2026-01-01T00:0${i}:00Z" "turn $i"
  spend "$S" "2026-01-01T00:0${i}:30Z" "s$i" 1000
  i=$((i+1))
done
uturn "$S" 2026-01-01T00:07:00Z "plan some work"
spend "$S" 2026-01-01T00:07:10Z p1 1000
tool "$S" 2026-01-01T00:07:20Z Bash '{"command":"gh issue create --title planned"}' zz
check "a ticket filed in a normal turn is not" "$(sig "$(S_ "$S")" deferral-candidate)" "0"

printf '\n== fingerprints are stable and discriminating ==\n'
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"git status"}' a
tool "$S" 2026-01-01T00:00:20Z Bash '{"command":"git status"}' b
tool "$S" 2026-01-01T00:00:30Z Bash '{"command":"git log"}'    c
fps=$(bash "$EV" "$S" --json 2>/dev/null | jq -r '[.events[]|select(.kind=="tool")|.fingerprint]')
check "identical inputs share a fingerprint" "$(jq -r '.[0] == .[1]' <<<"$fps")" "true"
check "different inputs do not"              "$(jq -r '.[0] == .[2]' <<<"$fps")" "false"

printf '\n== repeated-tool-call fires on a real loop ==\n'
S=$(newsession)
for t in 10 20 30; do tool "$S" "2026-01-01T00:00:${t}Z" Bash '{"command":"make test"}' "m$t"; done
out=$(S_ "$S")
check "three identical calls in 20s is a loop" "$(sig "$out" repeated-tool-call)" "1"
check "it reports the count"      "$(jq -r '[.signatures[]|select(.kind=="repeated-tool-call")]|.[0].count' <<<"$out")" "3"
check "it reports the span"       "$(jq -r '[.signatures[]|select(.kind=="repeated-tool-call")]|.[0].span_seconds' <<<"$out")" "20"

printf '\n== loop-shaped is not loop: the TIME qualifier ==\n'
# Three identical `git status` calls across an hour of work are fine; three in
# ninety seconds are not. Without this the inspector becomes the thing that
# cries wolf -- the failure this repo has already hit twice with its own checks.
S=$(newsession)
tool "$S" 2026-01-01T00:00:00Z Bash '{"command":"git status"}' a
tool "$S" 2026-01-01T01:00:00Z Bash '{"command":"git status"}' b
tool "$S" 2026-01-01T02:00:00Z Bash '{"command":"git status"}' c
check "spread across hours is not a loop" "$(sig "$(S_ "$S")" repeated-tool-call)" "0"

printf '\n== loop-shaped is not loop: the STATE qualifier ==\n'
# Re-running a gate after editing a file is the workflow working. Re-running it
# with nothing changed in between is the loop.
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"make test"}' a
tool "$S" 2026-01-01T00:00:15Z Edit '{"file_path":"/x.c","old_string":"a","new_string":"b"}' e1
tool "$S" 2026-01-01T00:00:20Z Bash '{"command":"make test"}' b
tool "$S" 2026-01-01T00:00:25Z Edit '{"file_path":"/x.c","old_string":"b","new_string":"c"}' e2
tool "$S" 2026-01-01T00:00:30Z Bash '{"command":"make test"}' c
out=$(S_ "$S")
check "an intervening edit clears the loop" "$(sig "$out" repeated-tool-call)" "0"

printf '\n== error-retry loops ==\n'
S=$(newsession)
for t in 10 20 30; do
  tool   "$S" "2026-01-01T00:00:${t}Z" Bash '{"command":"cargo build"}' "m$t"
  result "$S" "2026-01-01T00:00:${t}Z" true "tm$t" "boom"
done
out=$(S_ "$S")
check "repeated failing calls are flagged" "$(sig "$out" error-retry-loop)" "1"
check "the failure count is reported" \
  "$(jq -r '[.signatures[]|select(.kind=="error-retry-loop")]|.[0].errors' <<<"$out")" "3"

printf '\n== repeated subagent spawns ==\n'
S=$(newsession)
for t in 10 20 30; do tool "$S" "2026-01-01T00:0${t:0:1}:${t}Z" Agent "{\"subagent_type\":\"harness:self-review\",\"prompt\":\"round\"}" "m$t"; done
out=$(S_ "$S")
check "a review round cap looks like this" "$(sig "$out" repeated-agent-spawn)" "1"
check "it names the agent type" \
  "$(jq -r '[.signatures[]|select(.kind=="repeated-agent-spawn")]|.[0].subagent_type' <<<"$out")" "harness:self-review"

printf '\n== subagent spawns get the TIME qualifier too ==\n'
# Twelve general-purpose spawns across a whole session is normal work. Three in
# two minutes is a cap-hitting loop. The window is what tells them apart -- it
# was missing here at first, and a real session duly reported a loop that was
# just a productive afternoon.
S=$(newsession)
tool "$S" 2026-01-01T00:00:00Z Agent '{"subagent_type":"general-purpose","prompt":"a"}' a
tool "$S" 2026-01-01T03:00:00Z Agent '{"subagent_type":"general-purpose","prompt":"b"}' b
tool "$S" 2026-01-01T06:00:00Z Agent '{"subagent_type":"general-purpose","prompt":"c"}' c
check "spawns spread over hours are not a loop" "$(sig "$(S_ "$S")" repeated-agent-spawn)" "0"

printf '\n== turn depth, because the cache_read proxy does not survive real data ==\n'
# GH-14 proposed cache_read spikes as the proxy for "the agent re-read the same
# context again". Measured on a real session, cache_read TRENDS: early turns ran
# ~100k, late turns ~14M, because context grows all session. A whole-session
# median therefore flags most late turns -- 18 of 84, one turn in five, which is
# noise, not signal. Normalising per message flattens it so far that nothing is
# an outlier (24k..588k against a 244k median). What does separate is the number
# of messages in a turn: median 5, max 75. A turn that took 75 model calls IS
# the agent going round and round, and that is what gets flagged.
S=$(newsession)
i=1
while [ $i -le 6 ]; do
  uturn "$S" "2026-01-01T00:0${i}:00Z" "turn $i"
  spend "$S" "2026-01-01T00:0${i}:30Z" "s$i" 1000
  i=$((i+1))
done
uturn "$S" 2026-01-01T00:07:00Z "the long one"
j=1
while [ $j -le 20 ]; do spend "$S" "2026-01-01T00:07:${j}0Z" "d$j" 1000; j=$((j+1)); done
out=$(S_ "$S")
check "a turn that went round 20 times is flagged" "$(sig "$out" turn-depth-spike)" "1"
check "and it names the turn"  "$(jq -r '[.signatures[]|select(.kind=="turn-depth-spike")]|.[0].turn' <<<"$out")" "7"
check "reporting its depth"    "$(jq -r '[.signatures[]|select(.kind=="turn-depth-spike")]|.[0].messages' <<<"$out")" "20"

S=$(newsession)
i=1
while [ $i -le 6 ]; do
  uturn "$S" "2026-01-01T00:0${i}:00Z" "turn $i"
  spend "$S" "2026-01-01T00:0${i}:30Z" "s$i" 1000
  i=$((i+1))
done
check "an even session has no depth spike" "$(sig "$(S_ "$S")" turn-depth-spike)" "0"

printf '\n== a growing cache_read is NOT a finding on its own ==\n'
# The regression guard for the bug above: cache_read rising tenfold across a
# session is normal context growth and must not produce a signature by itself.
S=$(newsession)
i=1
while [ $i -le 8 ]; do
  uturn "$S" "2026-01-01T00:0${i}:00Z" "turn $i"
  spend "$S" "2026-01-01T00:0${i}:30Z" "g$i" "$((i * i * 100000))"
  i=$((i+1))
done
out=$(S_ "$S")
check "monotonic context growth flags nothing" "$(jq -r '.signatures|length' <<<"$out")" "0"

printf '\n== step regression: honest about having no data ==\n'
# No transcript on this machine contains a real progress-file write. A signature
# with no input must SAY so: a silent zero is indistinguishable from "clean",
# and that is how a dead check gets trusted for years.
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"git status"}' a
out=$(S_ "$S")
check "unavailability is declared, not implied" \
  "$(jq -r '[.unavailable[]|select(.kind=="step-regression")]|length' <<<"$out")" "1"
has "with the reason" "$(jq -r '.unavailable[0].reason' <<<"$out")" "progress"

printf '\n== step regression: fires when the data IS there ==\n'
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Write '{"file_path":"ai-docs/plans/x.progress.md","content":"**current_step:** Step 8 — impl"}' a
tool "$S" 2026-01-01T00:00:20Z Write '{"file_path":"ai-docs/plans/x.progress.md","content":"**current_step:** Step 9 — verify"}' b
tool "$S" 2026-01-01T00:00:30Z Write '{"file_path":"ai-docs/plans/x.progress.md","content":"**current_step:** Step 6 — design"}' c
out=$(S_ "$S")
check "a backwards step is flagged"  "$(sig "$out" step-regression)" "1"
check "from"  "$(jq -r '[.signatures[]|select(.kind=="step-regression")]|.[0].from' <<<"$out")" "9"
check "to"    "$(jq -r '[.signatures[]|select(.kind=="step-regression")]|.[0].to' <<<"$out")" "6"
check "and it is no longer listed unavailable" \
  "$(jq -r '[.unavailable[]|select(.kind=="step-regression")]|length' <<<"$out")" "0"
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Write '{"file_path":"ai-docs/plans/x.progress.md","content":"**current_step:** Step 8 — impl"}' a
tool "$S" 2026-01-01T00:00:20Z Write '{"file_path":"ai-docs/plans/x.progress.md","content":"**current_step:** Step 9 — verify"}' b
check "forward progress is not a finding" "$(sig "$(S_ "$S")" step-regression)" "0"

printf '\n== thresholds are tunable, and saying so is the point ==\n'
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"ls"}' a
tool "$S" 2026-01-01T00:00:20Z Bash '{"command":"ls"}' b
check "two calls is not a loop by default" "$(sig "$(S_ "$S")" repeated-tool-call)" "0"
out=$(bash "$EV" "$S" --signatures --min-repeats 2 2>/dev/null)
check "but --min-repeats 2 makes it one"   "$(sig "$out" repeated-tool-call)" "1"
out=$(bash "$EV" "$S" --signatures --json 2>/dev/null)
check "the thresholds used are reported"   "$(jq -r '.min_repeats' <<<"$out")" "3"

printf '\n== usage ==\n'
bash "$EV" >/dev/null 2>&1;                       check "no args -> 2"      "$?" "2"
bash "$EV" /nonexistent.jsonl >/dev/null 2>&1;    check "missing file -> 2" "$?" "2"
E=$(newsession)
bash "$EV" "$E" >/dev/null 2>&1;                  check "empty transcript is not an error" "$?" "0"
S=$(newsession)
tool "$S" 2026-01-01T00:00:10Z Bash '{"command":"ls"}' a
printf 'not json\n' >> "$S"
has "unparseable lines are reported" "$(bash "$EV" "$S" 2>&1)" "unparseable"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
