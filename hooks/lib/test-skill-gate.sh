#!/usr/bin/env bash
#
# Behaviour of hooks/lib/skill-gate.sh.
#
# THE POINT OF THIS SUITE IS THE PAIR, NOT THE DENY. A gate that denies a
# subagent is worthless if it also denies the main thread, and a gate that asks
# the main thread is worthless if the subagent slips through. Every case below
# therefore comes with its opposite, and the agent_id type check -- the one line
# that decides which branch a malformed payload takes -- carries a positive
# control that shows the suite can see its removal.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/../.." && pwd -P)
GATE="${HERE}/skill-gate.sh"
HOOKS="${ROOT}/hooks/hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT INT TERM

# Invoked BY PATH, the way hooks.json invokes it -- not as `bash <path>`, which
# would pass without the execute bit the manifest depends on.
fire(){ # <payload> [env assignment...]
  printf '%s' "$1" | ( shift 2>/dev/null; env "$@" "$GATE" ) 2>"${WORK}/err"
}
decision(){ printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }
reason(){ printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }

MAIN='{"tool_name":"Skill","tool_input":{"skill":"harness:task"}}'
BARE='{"tool_name":"Skill","tool_input":{"skill":"task"}}'
SUB='{"tool_name":"Skill","tool_input":{"skill":"task"},"agent_id":"a601d47b93e8d7bc6","agent_type":"general-purpose"}'

printf '\n== the main thread is ASKED, never denied ==\n'
out=$(fire "$MAIN")
check "main thread -> ask" "$(decision "$out")" "ask"
case "$(reason "$out")" in
  CONFIRM:*task*) ok "  the reason names the skill it is about" ;;
  *) bad "  the reason does not name the skill: [$(reason "$out")]" ;;
esac
check "the event name is echoed, as PreToolUse output requires" \
  "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" "PreToolUse"

printf '\n== a subagent is DENIED, with a reason it can act on ==\n'
out=$(fire "$SUB")
check "subagent -> deny" "$(decision "$out")" "deny"
case "$(reason "$out")" in
  BLOCKED:*) ok "  the reason is a refusal, not a prompt" ;;
  *) bad "  the refusal does not read as one: [$(reason "$out")]" ;;
esac
# The commonest way a blocked skill does damage anyway is the agent deciding to
# perform the workflow by hand, so the refusal has to say not to.
case "$(reason "$out")" in
  *"Do not reproduce the workflow steps"*) ok "  and it forbids doing the work by hand instead" ;;
  *) bad "  the refusal does not close the by-hand route" ;;
esac

printf '\n== both spellings of the same skill are gated ==\n'
check "plugin-prefixed name is gated" "$(decision "$(fire "$MAIN")")" "ask"
check "bare name is gated too"       "$(decision "$(fire "$BARE")")" "ask"

printf '\n== everything else is silent, and silence means zero bytes ==\n'
# The fourth payload is the one that DISCRIMINATES the tool_name guard: it is
# not a Skill call yet carries a `skill` key, so it is refused by the tool check
# and by nothing else. The `command:"ls"` form beside it cannot do that job --
# with the tool check removed it still stops at the empty-skill guard, so it
# passes whether the guard exists or not.
for p in '{"tool_name":"Skill","tool_input":{"skill":"bugfix"}}' \
         '{"tool_name":"Skill","tool_input":{"skill":"harness:interview"}}' \
         '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
         '{"tool_name":"Bash","tool_input":{"skill":"task"}}' \
         '{"tool_name":"Skill","tool_input":{}}'; do
  n=$(fire "$p" | wc -c | tr -d ' ')
  check "silent on: ${p}" "$n" "0"
done

printf '\n== POSITIVE CONTROL: drop the tool check, a non-Skill call is judged ==\n'
MUT2="${WORK}/mutated-tool.sh"
sed 's@^\[ "\$tool" = "Skill" \] || exit 0$@: @' "$GATE" > "$MUT2"
chmod +x "$MUT2"
if cmp -s "$GATE" "$MUT2"; then
  bad "the tool-check mutation did not apply, so this control measures nothing"
else
  ok "the mutation applied"
  m2=$(printf '%s' '{"tool_name":"Bash","tool_input":{"skill":"task"}}' | "$MUT2" 2>/dev/null)
  check "  without it, a Bash call carrying a skill key is judged" "$(decision "$m2")" "ask"
fi

printf '\n== nothing it does can cost the session a tool call ==\n'
check "empty stdin -> 0"     "$(printf '' | "$GATE" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON -> 0"  "$(printf 'not json' | "$GATE" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON emits nothing" "$(printf 'not json' | "$GATE" 2>/dev/null | wc -c | tr -d ' ')" "0"
check "a deny still exits 0" "$(printf '%s' "$SUB" | "$GATE" >/dev/null 2>&1; echo $?)" "0"

printf '\n== a malformed agent_id fails toward the USER, not against them ==\n'
# A number or an array is not an agent. Treating it as present would deny the
# main thread its own workflow, which is the expensive direction to be wrong in.
for bogus in '42' '["a"]' 'null' '{}'; do
  p=$(jq -nc --argjson a "$bogus" '{tool_name:"Skill", tool_input:{skill:"task"}, agent_id:$a}')
  check "agent_id ${bogus} -> ask, not deny" "$(decision "$(fire "$p")")" "ask"
done

printf '\n== POSITIVE CONTROL: drop the type check, the main thread gets denied ==\n'
MUT="${WORK}/mutated.sh"
# @ as the delimiter: the filter being replaced contains a jq pipe, and `|` as a
# sed delimiter would cut the pattern in half -- which is how this control
# reported "mutation applied" while producing a file that did nothing.
sed 's@if (.agent_id | type) == "string" then .agent_id else "" end@.agent_id // ""@' "$GATE" > "$MUT"
chmod +x "$MUT"
if cmp -s "$GATE" "$MUT"; then
  bad "the mutation did not apply, so this control measures nothing"
else
  ok "the mutation applied"
  p=$(jq -nc '{tool_name:"Skill", tool_input:{skill:"task"}, agent_id:42}')
  mout=$(printf '%s' "$p" | "$MUT" 2>/dev/null)
  check "  without it, a numeric agent_id denies the main thread" "$(decision "$mout")" "deny"
fi

printf '\n== the gated set is data: HARNESS_SKILL_GATE is honoured ==\n'
check "a skill added to the list is gated" \
  "$(decision "$(fire '{"tool_name":"Skill","tool_input":{"skill":"project-review"}}' HARNESS_SKILL_GATE='task project-review')")" "ask"
check "and with task removed from the list it is silent" \
  "$(fire "$MAIN" HARNESS_SKILL_GATE='project-review' | wc -c | tr -d ' ')" "0"

printf '\n== it is wired into the manifest the way it is meant to be ==\n'
WIRED=$(jq -r '[.hooks.PreToolUse[] | select(.matcher=="Skill") | .hooks[].command] | length' "$HOOKS")
check "registered under matcher Skill" "$WIRED" "1"
CMD=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Skill") | .hooks[0].command' "$HOOKS")
# Asserted before it is pattern-matched: an empty CMD satisfies the `not guarded`
# case below by accident, and a vacuous pass there is worse than no check.
check "the manifest yielded a command to inspect" "$( [ -n "$CMD" ] && echo yes || echo no )" "yes"
case "$CMD" in
  *'"${CLAUDE_PLUGIN_ROOT}"/hooks/lib/skill-gate.sh'*) ok "invoked by its plugin-root path, double-quoted" ;;
  *) bad "the manifest command is not the quoted plugin-root path: [$CMD]" ;;
esac
case "$CMD" in
  *harness-managed*) bad "the gate is guarded -- it must fire wherever the skill exists" ;;
  *) ok "and it is NOT guarded: the skill ships with the plugin, so the gate is never project-specific" ;;
esac
check "the entry point the manifest invokes by path is executable" \
  "$(git -C "$ROOT" ls-files -s hooks/lib/skill-gate.sh | awk '{print $1}')" "100755"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
