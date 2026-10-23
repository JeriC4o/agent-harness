#!/usr/bin/env bash

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "$HERE/../.." && pwd)
PASS=0; FAIL=0
ok()    { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
same()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()   { case $2 in *"$3"*) ok "$1" ;; *) bad "$1 (no [$3] in: $2)" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1 (found [$3] in: $2)" ;; *) ok "$1" ;; esac; }

D=$(mktemp -d)
trap 'chmod -R u+rwX "$D" 2>/dev/null; rm -rf "$D"' EXIT

P="$D/plugin"
mkdir -p "$P/hooks/lib" "$P/scripts" "$P/skills/x/scripts"
cp "$HERE/gate-record.sh" "$HERE/gate-pattern.sh" "$HERE/ledger-write.sh" "$P/hooks/lib/"
cp "$ROOT/scripts/tree-digest.sh" "$P/scripts/"
printf 'exit 0\n' > "$P/skills/x/scripts/check-y.sh"
H="$P/hooks/lib/gate-record.sh"

R="$D/repo"
mkdir -p "$R/scripts" "$R/mod/a" "$R/mod/b"
git -C "$R" init -q
printf 'progress.md\n' > "$R/.gitignore"
printf 'exit 0\n' > "$R/scripts/test-a.sh"
printf 'exit 0\n' > "$R/scripts/run.sh"
printf 'a\n' > "$R/mod/a/f"; printf 'b\n' > "$R/mod/b/f"
printf 'src\n' > "$R/src.txt"
git -C "$R" add .
git -C "$R" -c user.email=t@t -c user.name=t commit -qm base

LD="$D/loops"
SID=s1
fire() { # <event> <command> [agent] [cwd] -> stdout of the hook in $OUT, rc in $RC
  local ag=${3:-} cwd=${4:-$R}
  N=$((N + 1))
  jq -nc --arg e "$1" --arg c "$2" --arg t "tu-$N" --arg cwd "$cwd" --arg a "$ag" --arg s "$SID" \
    '{session_id:$s, hook_event_name:$e, tool_use_id:$t, cwd:$cwd, tool_input:{command:$c}}
     + (if $a == "" then {} else {agent_id:$a} end)' > "$D/pay.json"
  OUT=$(HARNESS_LOOP_DIR="$LD" bash "$H" < "$D/pay.json" 2> "$D/err"); RC=$?
  CTX=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}
N=0
pass() { fire PostToolUse "$@"; }
fail() { fire PostToolUseFailure "$@"; }
lastrow() { tail -n 1 "$LD/$SID.jsonl"; }
field() { lastrow | jq -c "$1"; }
fresh() { SID=$1; rm -f "$LD/$SID.jsonl"; }

printf '\n== what is a covered gate ==\n'
fresh plain
pass 'bash scripts/test-a.sh'
same "a shell suite exits 0" "$RC" 0
has "and tells the agent the gate, the exit and the digest" "$CTX" "[gate-record] scripts/test-a.sh exited zero; tree digest "
same "the event name is echoed" "$(printf '%s' "$OUT" | jq -r .hookSpecificOutput.hookEventName)" PostToolUse
same "one gate row" "$(grep -c '"kind":"gate"' "$LD/plain.jsonl")" 1
same "the row carries the fields" \
  "$(field '[has("ts","gate","args","artefact","repo","digest","ok","agent_id","tool_use_id","cwd","signal")] | all')" true
same "a main-thread row is agent main" "$(field .agent_id)" '"main"'
for c in 'ls -la' 'grep -n check src.txt' 'git check-ignore src.txt' '/usr/bin/test -f src.txt' 'bash scripts/run.sh'; do
  pass "$c"
  same "not a gate: $c" "$OUT" ""
done
pass './scripts/test-a.sh'
has "a checked-in script with a gate word, run directly, is a gate" "$CTX" "[gate-record] scripts/test-a.sh"
CLAUDE_SKILL_DIR="$P/skills/x" pass '"${CLAUDE_SKILL_DIR}/scripts/check-y.sh" src.txt'
PR='${CLAUDE_PLUGIN_ROOT}'
has "so is a plugin script reached through its directory variable" "$CTX" "${PR}/skills/x/scripts/check-y.sh"
pass 'jq -e . src.txt'
has "a jq exit-status parse is a gate named by tool and first word" "$CTX" "[gate-record] jq . exited"

printf '\n== identity does not depend on spelling ==\n'
fresh spell
pass 'bash scripts/test-a.sh'
pass "cd $R/scripts && FOO=1 bash ./test-a.sh > $D/out.txt 2>&1"
has "a cd, an assignment and a redirect make the same gate: a repeat" "$CTX" "REPEAT"
same "the redirect target is no argument" "$(field .args)" '[]'
pass "bash $R/scripts/test-a.sh"
has "an absolute spelling is the same gate" "$CTX" "REPEAT"

printf '\n== repeat and contradiction ==\n'
fresh sig
pass 'bash scripts/test-a.sh src.txt --fast'
same "first run raises nothing" "$(field .signal)" null
pass 'bash scripts/test-a.sh src.txt --fast'
same "same gate, args and digest is a repeat" "$(field .signal)" '"repeat"'
same "naming the earlier invocation" "$(field .prior_tool_use_id)" "\"tu-$((N - 1))\""
fail 'bash scripts/test-a.sh src.txt --slow' agent-b
same "same artefact, opposite verdict, another mode: contradiction" "$(field .signal)" '"contradiction"'
has "the sentence names the earlier command" "$CTX" '`bash scripts/test-a.sh src.txt --fast`'
same "the row carries the other agent" "$(field .agent_id)" '"agent-b"'
same "the prior row's agent is named" "$(field .prior_agent_id)" '"main"'
fail 'bash scripts/test-a.sh src.txt --slow'
same "a contradiction outranks a repeat" "$(field .signal)" '"contradiction"'

fresh fix
fail 'bash scripts/test-a.sh'
printf 'src fixed\n' > "$R/src.txt"
pass 'bash scripts/test-a.sh'
same "fail, fix, pass is silent: the digest moved" "$(field .signal)" null
git -C "$R" checkout -q -- src.txt

fresh ignored
printf 'plan v1\n' > "$R/progress.md"
fail 'bash scripts/test-a.sh progress.md'
printf 'plan v2\n' > "$R/progress.md"
pass 'bash scripts/test-a.sh progress.md'
same "a rewritten ignored file argument is a new input" "$(field .signal)" null
printf 'note\n' >> "$R/progress.md"
pass 'bash scripts/test-a.sh src.txt'
pass 'bash scripts/test-a.sh src.txt'
same "an ignored-file edit between runs leaves the digest: repeat" "$(field .signal)" '"repeat"'
rm -f "$R/progress.md"

fresh dirs
pass 'bash scripts/test-a.sh mod/a'
fail 'bash scripts/test-a.sh mod/b'
same "module A passes, module B fails: silent" "$(field .signal)" null
same "a directory is keyed by its path" "$(field .artefact)" '["dir:mod/b"]'
fail 'bash scripts/test-a.sh mod/a/'
same "the same directory spelled differently contradicts" "$(field .signal)" '"contradiction"'

printf '\n== the selection flag ==\n'
printf '**Selection flag:** `--only`\n' > "$R/AGENTS.md"
git -C "$R" add AGENTS.md; git -C "$R" -c user.email=t@t -c user.name=t commit -qm flag
fresh sel
pass 'bash scripts/test-a.sh --only b,a'
same "the value is split, sorted and classed as selection" "$(field .artefact)" '["sel:a","sel:b"]'
fail 'bash scripts/test-a.sh --only=a,b'
same "the joined spelling is the same artefact" "$(field .signal)" '"contradiction"'
fresh scoped
pass 'bash scripts/test-a.sh --only a'
fail 'bash scripts/test-a.sh'
same "a scoped pass then a failing full run is silent" "$(field .signal)" null
printf '**Selection flag:** `%%SELECTION_FLAG%%`\n' > "$R/AGENTS.md"
git -C "$R" -c user.email=t@t -c user.name=t commit -qam unfilled
fresh unfilled
pass 'bash scripts/test-a.sh --only a'
fail 'bash scripts/test-a.sh'
same "an unfilled flag classes nothing as selection" "$(field .signal)" '"contradiction"'
pass 'bash scripts/test-a.sh %SELECTION_FLAG% a'
same "not even the placeholder token itself" "$(field .artefact)" '[]'
printf '**Selection flag:** none\n' > "$R/AGENTS.md"
git -C "$R" -c user.email=t@t -c user.name=t commit -qam none
pass 'bash scripts/test-a.sh --only a'
same "and none means the same" "$(field .artefact)" '[]'

printf '\n== verdict attribution ==\n'
verdicts() { grep '"kind":"gate"' "$LD/$SID.jsonl" | tail -n "$1" | jq -r .ok | tr '\n' ' '; }
fresh v1; pass 'bash scripts/test-a.sh && bash scripts/test-a.sh --x'
same "an all-&& chain that exits zero: every gate passed" "$(verdicts 2)" 'true true '
fresh v2; fail 'bash scripts/test-a.sh && bash scripts/test-a.sh --x'
same "a failing && chain of gates: neither attributable" "$(verdicts 2)" 'null null '
fresh v3; fail "cd $D && git -C $R fetch && cd $R && bash scripts/test-a.sh"
same "a failing && run with no earlier gate: the gate failed" "$(verdicts 1)" 'false '
fresh v4; fail 'echo start; bash scripts/test-a.sh'
same "after ; the status is the gate's own" "$(verdicts 1)" 'false '
fresh v5; pass 'bash scripts/test-a.sh --x; bash scripts/test-a.sh'
same "an earlier gate followed by a segment is null, the last is attributed" "$(verdicts 2)" 'null true '
fresh v6; pass 'bash scripts/test-a.sh | cat'
same "a gate in a pipeline is null" "$(verdicts 1)" 'null '
fresh v7; fail 'true || bash scripts/test-a.sh'
same "a gate after || is null" "$(verdicts 1)" 'null '
fresh v8; pass 'bash scripts/test-a.sh &'
same "a gate backgrounded by a lone & is null, even as the only segment" "$(verdicts 1)" 'null '
fresh v8p; pass 'sleep 0 & bash scripts/test-a.sh'
same "a gate after a lone & takes the exit status as its own: passed" "$(verdicts 1)" 'true '
fresh v8f; fail 'sleep 0 & bash scripts/test-a.sh'
same "a gate after a lone & takes the exit status as its own: failed" "$(verdicts 1)" 'false '
pass 'echo "x; bash scripts/test-a.sh"'
same "a separator inside quotes starts no segment" "$OUT" ""
pass 'echo $(bash scripts/test-a.sh)'
same "nor does a command substitution" "$OUT" ""
pass '( bash scripts/test-a.sh )'
has "a subshell is still a gate" "$CTX" "[gate-record] scripts/test-a.sh"
fresh v9; fail 'bash scripts/test-a.sh src.txt'
fail 'bash scripts/test-a.sh src.txt | cat'
same "a null verdict takes part in repeats" "$(field .signal)" '"repeat"'
pass 'bash scripts/test-a.sh src.txt | cat'
same "and never in a contradiction" "$(field .signal)" '"repeat"'

printf '\n== another repository at the same tree digest ==\n'
git clone -q "$R" "$D/repo2"
fresh rp; pass 'bash scripts/test-a.sh'; pass 'bash scripts/test-a.sh' '' "$D/repo2"
same "a clone at the same state has the same digest" "$(jq -r .digest "$LD/rp.jsonl" | sort -u | wc -l | tr -d ' ')" 1
same "and the same gate there is no repeat" "$(field .signal)" null
fresh rc; pass 'bash scripts/test-a.sh'; fail 'bash scripts/test-a.sh' '' "$D/repo2"
same "nor an opposite verdict a contradiction" "$(field .signal)" null

printf '\n== outside a repository, and broken surroundings ==\n'
fresh out
mkdir -p "$D/norepo/scripts"; printf 'exit 0\n' > "$D/norepo/scripts/test-z.sh"
pass 'bash scripts/test-z.sh' '' "$D/norepo"
has "outside a repository the digest is none" "$CTX" "tree digest none (not in a repository)"
same "and the row's digest is null" "$(field .digest)" null
pass 'bash scripts/test-z.sh' '' "$D/norepo"
same "a null digest raises no signal" "$(field .signal)" null
printf 'not json\n' >> "$LD/out.jsonl"
pass 'bash scripts/test-a.sh'
pass 'bash scripts/test-a.sh'
same "a malformed ledger line is skipped" "$(field .signal)" '"repeat"'
mkdir -p "$D/ro"; chmod 555 "$D/ro"
if [ -w "$D/ro" ]; then bad "the read-only fixture is writable; the leg measures nothing"; else
  jq -nc --arg c 'bash scripts/test-a.sh' --arg cwd "$R" \
    '{session_id:"ro", hook_event_name:"PostToolUse", tool_use_id:"t", cwd:$cwd, tool_input:{command:$c}}' > "$D/pay.json"
  OUT=$(HARNESS_LOOP_DIR="$D/ro/x" TMPDIR="$D" bash "$H" < "$D/pay.json" 2> "$D/err"); RC=$?
  same "an unwritable ledger still exits 0" "$RC" 0
  has "and still tells the agent" "$OUT" "[gate-record] scripts/test-a.sh"
fi
fire PreToolUse 'bash scripts/test-a.sh'
same "an unexpected event records nothing" "$OUT" ""

printf '\n== the shared vocabulary file fails open ==\n'
mv "$P/hooks/lib/gate-pattern.sh" "$D/gp"
pass 'bash scripts/test-a.sh'
same "absent: exit 0" "$RC" 0
same "absent: nothing emitted" "$OUT" ""
printf 'B=x\n' > "$P/hooks/lib/gate-pattern.sh"
pass 'bash scripts/test-a.sh'
same "G left empty: nothing emitted" "$OUT$RC" "0"
cp "$D/gp" "$P/hooks/lib/gate-pattern.sh"; chmod 000 "$P/hooks/lib/gate-pattern.sh"
if [ -r "$P/hooks/lib/gate-pattern.sh" ]; then bad "the unreadable fixture is readable; the leg measures nothing"; else
  pass 'bash scripts/test-a.sh'
  same "unreadable: nothing emitted" "$OUT$RC" "0"
fi
chmod 644 "$P/hooks/lib/gate-pattern.sh"
pass 'bash scripts/test-a.sh'
has "restored: recorded again" "$CTX" "[gate-record]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
