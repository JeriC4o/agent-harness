#!/usr/bin/env bash
#
# Behavioural tests for hooks/hooks.json: every command is RUN, and what it
# emits is read.
#
# Run: bash scripts/test-hook-behaviour.sh
#
# WHY THIS SUITE EXISTS. The manifest's human-readable messages carried the
# literal string ${CLAUDE_PLUGIN_ROOT} in EVERY delivery ever measured, because
# they sat inside single-quoted printf formats where no shell expands anything.
# No delivery count is frozen here on purpose: the corpus it would come from
# keeps growing until the fixed version is installed, so any figure written
# down is stale the day after. Worse, the corpus CONTAMINATES ITSELF when
# measured: grepping the transcripts writes the grep into the transcripts, and
# the count was observed moving 83 -> 86 inside one review. If you re-derive
# one anyway, note that the obvious grep OVER-COUNTS -- matching
# "REQUIRED SESSION START: read " gave 90 hits against 81 actual deliveries,
# the other 9 being review commands and tool results quoting the string.
# Nothing ran a hook and read its output, so nothing could see it.
#
# COMMANDS ARE SELECTED BY THE MANIFEST TRIPLE -- event, matcher, index within
# the matcher's group -- passed as THREE values and never joined, because a
# matcher contains a pipe (Edit|Write) and any delimiter-joined key is
# ambiguous. statusMessage cannot serve: two of its values are duplicated and
# both duplicate pairs are byte-identical commands, so four of the nineteen are
# indistinguishable by output, message and basename alike.
#
# EVERY COMMAND NEEDS ITS OWN TRIGGER. Measured: 18 of 19 emit zero bytes on a
# generic payload, so an absence-only assertion is satisfied equally by a hook
# that ran and did nothing and by one that never ran. The trigger table below
# is therefore a deliverable, not scaffolding.
#
# STDOUT AND STDERR ARE CAPTURED SEPARATELY. loop-index.sh writes a line to
# stderr AND its decision JSON to stdout; `jq -e` over the merged stream returns
# rc 5 on the concatenation while the same expression over stdout alone returns
# rc 0. The absence assertion runs over the concatenation, the jq markers over
# stdout alone.
#
# A HOOK THAT ERRORS LOOKS EXACTLY LIKE A HOOK THAT FIRED, so no assertion here
# is "output is non-empty". An arm probe in this task reported all twelve paths
# firing, negative control included, because the extracted command file did not
# exist and every run printed an error to stderr.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd -P)
HOOKS="${ROOT}/hooks/hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

WORK=$(mktemp -d); trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT INT TERM
OUT="${WORK}/out"; ERR="${WORK}/err"

cmd_of(){ # <event> <matcher> <index>
  jq -r --arg e "$1" --arg m "$2" --argjson i "$3" \
    '.hooks[$e][] | select((.matcher // "-") == $m) | .hooks[$i].command' "$HOOKS"
}

# Several messages open with a deliberate blank line so an advisory stands clear
# of the tool output above it; anchoring on byte 0 would make every marker a
# property of that blank line instead.
first_line(){ awk 'NF{print; exit}' "$1"; }

anchored(){ # <label> <file> <marker>
  got=$(first_line "$2")
  case "$got" in
    "$3"*) ok "$1" ;;
    *) bad "$1 (first line [${got}] does not start with [$3])" ;;
  esac
}

# AC4b. The granularity is an ARGUMENT, so an address-level claim cannot be
# discharged by a command-level witness: a marker proves the command fired and
# says nothing about any substring of what it printed. `address` therefore
# requires a witness that is itself an absolute path.
witness_ok(){ # <granularity> <witness>
  case "$1" in
    command) [ -n "$2" ] ;;
    address) case "$2" in /*) return 0 ;; *) return 1 ;; esac ;;
    *) return 1 ;;
  esac
}
assert_at(){ # <granularity> <label> <witness> <expected-prefix> <expected-suffix>
  if ! witness_ok "$1" "$3"; then
    bad "$2 -- a ${1}-level claim was offered a witness that cannot support it: [$3]"; return 1
  fi
  case "$3" in
    "$4"*) ;;
    *) bad "$2 (witness [$3] does not begin with [$4])"; return 1 ;;
  esac
  case "$3" in
    *"$5") ok "$2" ;;
    *) bad "$2 (witness [$3] does not end with [$5])"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Fixtures. Every one asserts its own precondition before anything is asserted
# about behaviour -- a suite running as root would find a chmod 000 file
# readable and measure nothing at all.
# ---------------------------------------------------------------------------

# AC11b. Built under /tmp rather than under $TMPDIR, because /tmp is a symlink
# to private/tmp on this platform and real transcripts carry the /private/tmp
# spelling. A fixture anywhere else makes the realpath-divergence case a
# simulation; here the divergent pair is real.
PROJ=$(mktemp -d /tmp/gh75-hookbeh.XXXXXX)
PROJ_PHYS=$(cd "$PROJ" && pwd -P)
MARKERLESS=$(mktemp -d)

setup_project(){
  git -C "$PROJ" init -q -b main
  git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
  mkdir -p "$PROJ/ai-docs/learnings" "$PROJ/docs" "$PROJ/scripts" \
           "$PROJ/.claude/skills/deploy" "$PROJ/agents" "$PROJ/rules" \
           "$PROJ/my-agents" "$PROJ/sub-agents" "$PROJ/src/docs" \
           "$PROJ/node_modules/x/docs" "$PROJ/vendor/scripts"
  : > "$PROJ/AGENTS.md"
  : > "$PROJ/.claude/skills/deploy/SKILL.md"
}
setup_project

run_hook(){ # <event> <matcher> <index> <payload>  [env assignments via RUN_ENV]
  c=$(cmd_of "$1" "$2" "$3")
  [ -n "$c" ] || { bad "no command at $1|$2|$3"; return 1; }
  printf '%s' "$4" | ( cd "${RUN_CWD:-$PROJ}" && eval "${RUN_ENV:-} bash -c \"\$c\"" ) > "$OUT" 2> "$ERR"
  return 0
}

# ---------------------------------------------------------------------------
printf '\n== AC2a: the selection key is the manifest triple, and it is unique ==\n'
# ---------------------------------------------------------------------------
jq -r '.hooks | to_entries[] | .key as $ev | .value[] | (.matcher // "-") as $m
       | .hooks | to_entries[] | [$ev, $m, (.key|tostring)] | @tsv' "$HOOKS" > "${WORK}/keys.tsv"
TOTAL=$(wc -l < "${WORK}/keys.tsv" | tr -d ' ')
DISTINCT=$(sort -u "${WORK}/keys.tsv" | wc -l | tr -d ' ')
check "every hook command has a triple" "$TOTAL" "20"
check "the ${TOTAL} triples are distinct" "$DISTINCT" "$TOTAL"
SM_DISTINCT=$(jq -r '.hooks[][] | .hooks[] | .statusMessage // "<none>"' "$HOOKS" | sort -u | wc -l | tr -d ' ')
[ "$SM_DISTINCT" -lt "$TOTAL" ] \
  && ok "statusMessage is NOT a usable key (${SM_DISTINCT} distinct values over ${TOTAL} commands)" \
  || bad "statusMessage now looks unique, so the stated reason for the triple no longer holds -- re-derive before trusting either key"

# ---------------------------------------------------------------------------
# The committed trigger inventory and marker table, covering all 19.
#
# The marker is the ANCHORED LEADING FORM of the emitted text -- a full first-line
# prefix, or a jq-extracted field read from stdout -- never a bare bracket and
# never a bare `BLOCKED:`. Six commands share that prefix and three share
# `[loop-index]`; for those three the separator is the SECOND FIELD after the
# bracket, not the stream, because loop-index.sh and loop-verdict.sh BOTH write
# a `[loop-index] ...` line to stderr.
#
# Fields: event | matcher | index | trigger-id | stream | marker
# stream: out = stdout, err = stderr, jq = a jq field read from stdout alone,
#         none = an accepted non-emitter proved behaviourally below.
# ---------------------------------------------------------------------------
TABLE='SessionStart|-|0|session|jq|REQUIRED SESSION START: read
PreToolUse|Bash|0|commit_on_default|err|BLOCKED: git commit/push on
PreToolUse|Bash|1|commit_dirty_learnings|err|[auto-stage-learnings]
PreToolUse|Bash|2|find_home|err|BLOCKED: broad find/bfs/grep -r over
PreToolUse|Bash|3|coauthor_trailer|err|BLOCKED: git commit message contains a Co-Authored-By trailer.
PreToolUse|Bash|4|three_dot_diff|err|BLOCKED: `git diff <base>...HEAD` on a branch with NO commits yet
PreToolUse|Bash|5|properties_filter|err|BLOCKED: this content search can surface deployed-config files
PreToolUse|Bash|6|piped_gate|err|BLOCKED: a gate (build / test / lint / format / shellcheck) is
PreToolUse|Edit|Write|0|member_path|err|[propagation-rule-reminder] You are editing
PreToolUse|Edit|Write|1|learnings_headers|err|[archive-protection-reminder]
PreToolUse|Skill|0|skill_task_main|jq|CONFIRM: /task starts the full ordered workflow
PreToolUse|*|0|repeated_call|jq|[loop-index] this exact call (same tool, same arguments) has run
PostToolUse|Write|Edit|0|misplaced_append|err|[learnings-append-check]
PostToolUse|Write|Edit|1|broken_sh|err|[sh-syntax-check]
PostToolUse|Bash|0|push_on_feature|err|[pr-body-sync]
PostToolUse|*|0|result_ok|none|
Stop|-|0|turn_verdict|err|[loop-index] coarse repeat:
SubagentStart|-|0|agent_mark|none|
SubagentStop|-|0|turn_verdict_sub|err|[loop-index] coarse repeat:
PostToolUseFailure|*|0|result_fail|none|'

# loop-index.sh emits TWICE and its stderr line is the half its own comment
# calls load-bearing, so it carries a second marker row of its own.
EXTRA_MARKER='[loop-index] loop: '

LEDGER="${WORK}/loops"
# A bare `wc -l < missing` makes the SHELL report the redirection, which no
# `2>/dev/null` on wc can suppress; the absence is an expected state here.
ledger_rows(){ if [ -f "${LEDGER}/$1.jsonl" ]; then wc -l < "${LEDGER}/$1.jsonl" | tr -d ' '; else printf '0'; fi; }

payload_for(){ # <trigger-id>  -> prints the payload, and may prepare fixture state
  case "$1" in
    session) printf '%s' '{"hook_event_name":"SessionStart","session_id":"s0"}' ;;
    commit_on_default)
      git -C "$PROJ" checkout -q main
      jq -nc '{tool_input:{command:"git commit -m seed"}}' ;;
    commit_dirty_learnings)
      printf 'x\n' > "$PROJ/ai-docs/learnings.md"; git -C "$PROJ" add -N ai-docs/learnings.md
      jq -nc '{tool_input:{command:"git commit -m seed"}}' ;;
    find_home) jq -nc --arg h "$HOME" '{tool_input:{command:("find " + $h)}}' ;;
    coauthor_trailer)
      jq -nc '{tool_input:{command:"git commit -m \"t\n\nCo-Authored-By: A <a@b>\""}}' ;;
    three_dot_diff)
      git -C "$PROJ" checkout -q main
      jq -nc '{tool_input:{command:"git diff main...HEAD"}}' ;;
    properties_filter)
      jq -nc '{tool_input:{command:"grep -r --include=*.properties token src"}}' ;;
    piped_gate)
      jq -nc '{tool_input:{command:"bash scripts/test-thing.sh | tail -3"}}' ;;
    member_path) jq -nc --arg p "$PROJ/AGENTS.md" '{tool_input:{file_path:$p}}' ;;
    learnings_headers)
      jq -nc --arg p "$PROJ/ai-docs/learnings.md" \
        '{tool_input:{file_path:$p, content:"### one\n### two\n"}}' ;;
    skill_task_main)
      # No agent_id: the MAIN-thread branch, which must ASK rather than deny.
      # The plugin spelling is used deliberately -- the gate strips the prefix,
      # and a fixture written as bare `task` would not exercise that.
      jq -nc '{tool_name:"Skill", tool_input:{skill:"harness:task"}}' ;;
    repeated_call)
      seed_repeat s-loop
      ledger_payload s-loop Bash "echo hi" PreToolUse tu-3 ;;
    misplaced_append) seed_misplaced; jq -nc --arg p "$PROJ/ai-docs/learnings.md" '{tool_input:{file_path:$p}}' ;;
    broken_sh)
      printf 'if [ 1 ]; then\n' > "$PROJ/scripts/broken.sh"
      jq -nc --arg p "$PROJ/scripts/broken.sh" '{tool_input:{file_path:$p}}' ;;
    push_on_feature)
      git -C "$PROJ" checkout -q -B feature-branch
      jq -nc '{tool_input:{command:"git push"}}' ;;
    result_ok)   ledger_payload s-result Bash "echo hi" PostToolUse tu-r1 ;;
    result_fail) ledger_payload s-result Bash "echo hi" PostToolUseFailure tu-r2 ;;
    # The session is `s-result` because the `none` branch's non-vacuity witness
    # is a DELTA on that one ledger. A canary row is still a row, so it serves
    # the same purpose -- and the live payload carries no tool_use_id, which is
    # why ledger_payload cannot build this one.
    agent_mark)
      jq -nc '{session_id:"s-result", hook_event_name:"SubagentStart",
               agent_id:"a17de311aa309cb52", agent_type:"general-purpose",
               prompt_id:"p-1", transcript_path:"/tmp/transcript.jsonl", cwd:"/tmp"}' ;;
    turn_verdict)     seed_turn s-turn;     printf '%s' '{"session_id":"s-turn","hook_event_name":"Stop"}' ;;
    turn_verdict_sub) seed_turn s-turn-sub; printf '%s' '{"session_id":"s-turn-sub","hook_event_name":"SubagentStop"}' ;;
    *) return 1 ;;
  esac
}

ledger_payload(){ # <session> <tool> <command> <event> <tool_use_id>
  jq -nc --arg s "$1" --arg t "$2" --arg c "$3" --arg e "$4" --arg u "$5" \
    '{session_id:$s, hook_event_name:$e, tool_name:$t, tool_input:{command:$c},
      tool_use_id:$u, transcript_path:"/tmp/transcript.jsonl"}'
}
feed_pretool(){ # <payload>
  c=$(cmd_of PreToolUse '*' 0)
  # The command spells the script path through the plugin root, so without it
  # exported the seeding runs nothing and every later assertion about a seeded
  # ledger measures a hook that was never reached.
  printf '%s' "$1" \
    | ( cd "$PROJ" && CLAUDE_PLUGIN_ROOT="$ROOT" HARNESS_LOOP_DIR="$LEDGER" bash -c "$c" ) >/dev/null 2>&1
}
# Two PRIOR occurrences, so the call under test is the third and the default
# threshold of 3 is reached by the run being measured rather than by the setup.
seed_repeat(){
  feed_pretool "$(ledger_payload "$1" Bash "echo hi" PreToolUse tu-1)"
  feed_pretool "$(ledger_payload "$1" Bash "echo hi" PreToolUse tu-2)"
}
# The coarse gate needs 8 repeats of one bin inside the turn; 9 clears it.
seed_turn(){
  i=1
  while [ "$i" -le 9 ]; do
    feed_pretool "$(ledger_payload "$1" Bash "ls dir${i}" PreToolUse "tv-${i}")"
    i=$((i+1))
  done
}
# The check reads `git diff -U0`, so the file has to be COMMITTED with its
# headings and then grown one in the middle.
seed_misplaced(){
  L="$PROJ/ai-docs/learnings.md"
  printf '# log\n\n### one\nbody\n\n### two\nbody\n' > "$L"
  git -C "$PROJ" add ai-docs/learnings.md
  git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m seed-learnings
  printf '# log\n\n### one\nbody\n\n### inserted\nbody\n\n### two\nbody\n' > "$L"
}

printf '\n== AC2 + AC3 + AC15b: every command runs against its own trigger ==\n'
covered=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  ev=${row%%|*}; rest=${row#*|}
  marker=${rest##*|}; rest=${rest%|*}
  stream=${rest##*|}; rest=${rest%|*}
  trig=${rest##*|}; matcher=${rest%|*}
  idx=${matcher##*|}; matcher=${matcher%|*}
  covered=$((covered+1))
  key="${ev}|${matcher}|${idx}"
  pay=$(payload_for "$trig") || { bad "${key}: no trigger defined for ${trig}"; continue; }

  RUN_ENV="HARNESS_LOOP_DIR=\"$LEDGER\" CLAUDE_PLUGIN_ROOT=\"$ROOT\" CLAUDE_PROJECT_DIR=\"$PROJ\""
  rows_before=$(ledger_rows s-result)
  run_hook "$ev" "$matcher" "$idx" "$pay" || continue

  case "$stream" in
    err) anchored "${key}: emits its own marker on stderr" "$ERR" "$marker" ;;
    out) anchored "${key}: emits its own marker on stdout" "$OUT" "$marker" ;;
    jq)
      ctx=$(jq -r '.hookSpecificOutput.additionalContext // .hookSpecificOutput.permissionDecisionReason // empty' "$OUT" 2>/dev/null)
      if [ -z "$ctx" ]; then bad "${key}: no jq-readable field on stdout alone"
      else case "$ctx" in "$marker"*) ok "${key}: the jq field carries its marker" ;;
                          *) bad "${key}: jq field [${ctx}] does not start with [${marker}]" ;; esac
      fi ;;
    none)
      emitted=$(( $(wc -c < "$OUT") + $(wc -c < "$ERR") ))
      rows_after=$(ledger_rows s-result)
      # Emptiness alone is true for three distinct no-op paths, so the ledger
      # row is the non-vacuity witness. It has to be a DELTA: "the ledger has
      # rows" is already true once the first command of the pair has run, so a
      # second command that no-opped would pass that reading.
      check "${key}: accepted non-emitter emits 0 bytes" "$emitted" "0"
      check "${key}: and THIS run added exactly one ledger row, so it ran rather than no-opped" \
        "$((rows_after - rows_before))" "1" ;;
  esac

  # AC2 leg (ii), over the CONCATENATION of both streams.
  if grep -qF 'CLAUDE_PLUGIN_ROOT' "$OUT" "$ERR"; then
    bad "${key}: an unexpanded plugin-root token reached the output"
    grep -oF -m1 'CLAUDE_PLUGIN_ROOT' "$OUT" "$ERR"
  else
    ok "${key}: no unexpanded plugin-root token in either stream"
  fi
done <<EOF
$TABLE
EOF
check "the trigger table covers every command" "$covered" "$TOTAL"

printf '\n== AC15a: the markers are pairwise disjoint over the distinguishable commands ==\n'
# The two byte-identical pairs are excluded from the pair requirement and
# separated by their selection key instead; loop-index.sh contributes both of
# its emissions.
MARKERS=$(printf '%s\n' "$TABLE" | awk -F'|' '{print $NF}' | grep -v '^$')
MARKERS=$(printf '%s\n%s' "$MARKERS" "$EXTRA_MARKER" | sort -u)
MCOUNT=$(printf '%s\n' "$MARKERS" | wc -l | tr -d ' ')
check "distinct marker strings in the table" "$MCOUNT" "17"
clash=0
while IFS= read -r a; do
  while IFS= read -r b; do
    [ "$a" = "$b" ] && continue
    case "$a" in *"$b"*) bad "marker [$b] is a substring of [$a]"; clash=1 ;; esac
  done <<EOF2
$MARKERS
EOF2
done <<EOF3
$MARKERS
EOF3
[ "$clash" -eq 0 ] && ok "no marker is a substring of another" || true

printf '\n== AC15: a near-miss output fails the right assertion ==\n'
printf 'BLOCKED: git commit/pus on main\n' > "${WORK}/nearmiss"
got=$(first_line "${WORK}/nearmiss")
case "$got" in
  'BLOCKED: git commit/push on '*) bad "a near-miss string satisfied the anchored marker" ;;
  *) ok "the anchored marker rejects a near-miss (one character short)" ;;
esac
printf 'NOT-STALE\n' > "${WORK}/nearmiss2"
case "$(first_line "${WORK}/nearmiss2")" in
  'STALE'*) bad "an anchored match treated NOT-STALE as STALE" ;;
  *) ok "and it rejects a substring that is not a prefix" ;;
esac

# ---------------------------------------------------------------------------
printf '\n== AC6: the six root states, on an unguarded site ==\n'
# ---------------------------------------------------------------------------
# sh-syntax-check carries no harness-managed guard, so the root states can be
# read without the guard deciding the outcome first.
PRINTED(){ # the emitted reference, between "See " and the sentence end
  sed -n 's/.*See \(.*\)$/\1/p' "$ERR" | tail -1
}
BROKEN="$PROJ/scripts/broken.sh"
printf 'if [ 1 ]; then\n' > "$BROKEN"
SH_PAYLOAD=$(jq -nc --arg p "$BROKEN" '{tool_input:{file_path:$p}}')
state(){ # <env prefix> -> fills $OUT/$ERR
  RUN_ENV="$1"; run_hook PostToolUse 'Write|Edit' 1 "$SH_PAYLOAD"
}

# A plugin tree of its own, because states 4 and 5 chmod it and the real one
# must not be touched.
FAKE="${WORK}/plugin"
mkdir -p "${FAKE}/hooks/lib" "${FAKE}/rules"
cp "${ROOT}/hooks/lib/plugin-ref.sh" "${FAKE}/hooks/lib/plugin-ref.sh"
chmod 755 "${FAKE}/hooks/lib/plugin-ref.sh"
printf 'x\n' > "${FAKE}/rules/ast-index.md"

state "CLAUDE_PLUGIN_ROOT=\"$FAKE\""
S1=$(PRINTED)
assert_at address "state 1 (set, readable) prints a resolved absolute address" \
  "${S1%.}" "${FAKE}/" "rules/ast-index.md"

state "env -u CLAUDE_PLUGIN_ROOT"
S2=$(PRINTED)
case "$S2" in /*) bad "state 2 (unset) printed an absolute path" ;; *) ok "state 2 (unset) prints no absolute path" ;; esac
case "$S2" in *' /docs/'*|*' /rules/'*) bad "state 2 printed a root-relative path as an address" ;; *) ok "state 2 carries no bare /docs/ or /rules/ address" ;; esac

state 'CLAUDE_PLUGIN_ROOT='
S3=$(PRINTED)
check "state 3 (empty string) is byte-identical to state 2" "$S3" "$S2"

TGT="${FAKE}/rules/ast-index.md"
chmod 000 "$TGT"
[ -r "$TGT" ] && bad "state 4 precondition: the target is still readable, so this state measures nothing" \
              || ok "state 4 precondition: the target is unreadable"
state "CLAUDE_PLUGIN_ROOT=\"$FAKE\""
S4=$(PRINTED)
chmod 644 "$TGT"
case "$S4" in *'read access to the plugin directory'*) ok "state 4 names the requirement" ;; *) bad "state 4 does not name the read requirement" ;; esac
case "$S4" in *"$FAKE"*) ok "state 4 names the plugin directory" ;; *) bad "state 4 does not name the directory" ;; esac
case "$S4" in *unset*|*'not set'*) bad "state 4 claims the variable is unset, which it is not" ;; *) ok "state 4 claims nothing about why" ;; esac

FAKE5="${WORK}/plugin5"
mkdir -p "${FAKE5}/hooks/lib" "${FAKE5}/rules"
cp "${ROOT}/hooks/lib/plugin-ref.sh" "${FAKE5}/hooks/lib/plugin-ref.sh"
chmod 755 "${FAKE5}/hooks/lib/plugin-ref.sh"
printf 'x\n' > "${FAKE5}/rules/ast-index.md"
chmod 000 "$FAKE5"
[ -x "$FAKE5" ] && bad "state 5 precondition: the root is still traversable" \
                || ok "state 5 precondition: the root is not traversable"
state "CLAUDE_PLUGIN_ROOT=\"$FAKE5\""
S5=$(PRINTED)
chmod 755 "$FAKE5"
check "state 5 (root unreadable) is byte-identical to state 4 with its own root" \
  "${S5//"$FAKE5"/R}" "${S4//"$FAKE"/R}"

# AC4a. The degenerate address is what an absence-only assertion cannot see.
FAKE6="${WORK}/plugin6"
mkdir -p "${FAKE6}/hooks/lib" "${FAKE6}/rules"
printf '#!/usr/bin/env bash\nexit 0\n' > "${FAKE6}/hooks/lib/plugin-ref.sh"
chmod 755 "${FAKE6}/hooks/lib/plugin-ref.sh"
printf 'x\n' > "${FAKE6}/rules/ast-index.md"
[ -z "$(bash "${FAKE6}/hooks/lib/plugin-ref.sh" rules/ast-index.md)" ] \
  && ok "state 6 precondition: the stand-in resolver exits 0 printing nothing" \
  || bad "state 6 precondition: the stand-in resolver printed something"
state "CLAUDE_PLUGIN_ROOT=\"$FAKE6\""
S6=$(PRINTED)
check "state 6 (silent resolver) is byte-identical to state 4 with its own root" \
  "${S6//"$FAKE6"/R}" "${S4//"$FAKE"/R}"
case "$S6" in '.') bad "state 6 emitted the degenerate 'See .'" ;; *) ok "state 6 emits a directory-naming address, not 'See .'" ;; esac

printf '\n== AC4a control: without the emptiness guard, state 6 degenerates ==\n'
# Degrading the OPERATOR: `||` is rebound to the ASSIGNMENT rc. Dropping the
# test but keeping the assignment would make the fallback unconditional, which
# is the vacuous shape Group A shipped once and caught.
C=$(cmd_of PostToolUse 'Write|Edit' 1)
# The pattern is passed QUOTED and the replacement BARE. Measured: an inline
# single-quoted pattern is re-expanded by bash and matches the wrong span, and a
# quoted replacement inserts its own quote characters into the command.
GUARD_PAT='2>/dev/null); [ -n "$a" ] ||'
GUARD_REPL='2>/dev/null) ||'
DEG=${C/"$GUARD_PAT"/$GUARD_REPL}
if [ "$DEG" = "$C" ]; then bad "the emptiness-guard degradation changed nothing"; else
  ok "emptiness-guard degradation applied"
  printf '%s' "$SH_PAYLOAD" | ( cd "$PROJ" && CLAUDE_PLUGIN_ROOT="$FAKE6" bash -c "$DEG" ) > "$OUT" 2> "${WORK}/deg.err"
  dg=$(sed -n 's/.*See \(.*\)$/\1/p' "${WORK}/deg.err" | tail -1)
  check "the degraded site emits the degenerate address" "$dg" "."
fi

printf '\n== AC4b: an address-level claim cannot be discharged by a command-level witness ==\n'
# The helper is the thing under test here: offering it the marker that proves
# the command fired, in place of the address, must be REJECTED rather than
# counted. Run in a subshell so the deliberate rejection does not score.
selfcheck=$( ok(){ :; }; bad(){ printf 'rejected\n'; }
  assert_at address "self-check" "[sh-syntax-check] " "/" "rules/ast-index.md" )
check "a command-level marker offered as an address witness is rejected" "$selfcheck" "rejected"
selfcheck2=$( ok(){ printf 'accepted\n'; }; bad(){ :; }
  assert_at address "self-check" "/plugin/rules/ast-index.md" "/" "rules/ast-index.md" )
check "and a real absolute address is accepted" "$selfcheck2" "accepted"
selfcheck3=$( ok(){ printf 'accepted\n'; }; bad(){ :; }
  assert_at command "self-check" "[sh-syntax-check] " "[sh-" "check] " )
check "a command-level claim IS dischargeable by a marker" "$selfcheck3" "accepted"

printf '\n== AC2 leg (ii) is load-bearing: a literal token in the output is caught ==\n'
# The original defect, reproduced: the resolved value is replaced in the printf
# ARGUMENT list by the literal token, exactly as the manifest carried it in
# every measured delivery.
TOK_PAT='"$a" >&2'
TOK_REPL="'\${CLAUDE_PLUGIN_ROOT}/rules/ast-index.md' >&2"
LEAK=${C/"$TOK_PAT"/$TOK_REPL}
if [ "$LEAK" = "$C" ]; then bad "the literal-token degradation changed nothing"; else
  ok "literal-token degradation applied"
  printf '%s' "$SH_PAYLOAD" | ( cd "$PROJ" && CLAUDE_PLUGIN_ROOT="$FAKE" bash -c "$LEAK" ) > "$OUT" 2> "$ERR"
  grep -qF 'CLAUDE_PLUGIN_ROOT' "$OUT" "$ERR" \
    && ok "and leg (ii) finds the unexpanded token, so its silence on the 19 is a measurement" \
    || bad "leg (ii) missed a literal token that IS in the output -- the absence assertion proves nothing"
fi

printf '\n== AC19 + AC20: plugin-ref.sh is reached the way production reaches it ==\n'
MODE=$(git -C "$ROOT" ls-files -s hooks/lib/plugin-ref.sh | awk '{print $1}')
check "plugin-ref.sh is committed executable" "$MODE" "100755"
"${ROOT}/hooks/lib/plugin-ref.sh" rules/ast-index.md > "${WORK}/bypath" 2>&1
check "it runs when invoked BY PATH, as the hooks invoke it" "$?" "0"
[ -s "${WORK}/bypath" ] && ok "and prints something on that path" || bad "by-path invocation printed nothing"
refs=$(jq -r '.hooks[][] | .hooks[] | .command' "$HOOKS" | grep -oF 'plugin-ref.sh' | wc -l | tr -d ' ')
pre=$(jq -r '.hooks[][] | .hooks[] | .command' "$HOOKS" | grep -oF '=$("$r"/hooks/lib/plugin-ref.sh' | wc -l | tr -d ' ')
check "every plugin-ref.sh reference is a captured call, never inlined into a format" "$pre" "$refs"

# ---------------------------------------------------------------------------
printf '\n== AC11a: the perturbed anchors ==\n'
# ---------------------------------------------------------------------------
PROP=$(cmd_of PreToolUse 'Edit|Write' 0)
# The un-normalised matcher, for the "silent before the fix" half. Both
# substitutions are asserted to have landed.
NORM_PAT='pd=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P)'
NORM_REPL='pd="${CLAUDE_PROJECT_DIR:-$PWD}"'
KEY_PAT='k="${kd:-$d}/$bn"'
KEY_REPL='k="$file_path"'
UNNORM=${PROP/"$NORM_PAT"/$NORM_REPL}
UNNORM=${UNNORM/"$KEY_PAT"/$KEY_REPL}
if [ "$UNNORM" = "$PROP" ]; then bad "the un-normalised variant is identical to the shipped command"; else
  ok "un-normalised variant built (both substitutions landed)"
fi

fire_prop(){ # <command> <anchor> <file_path> <cwd>
  printf '%s' "$(jq -nc --arg p "$3" '{tool_input:{file_path:$p}}')" \
    | ( cd "$4" && CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$2" bash -c "$1" ) > "$OUT" 2> "$ERR"
}
fired(){ grep -qF '[propagation-rule-reminder] You are editing' "$ERR"; }

fire_prop "$PROP" "${PROJ_PHYS}/" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
fired && ok "(a) trailing-slash anchor FIRES after normalisation" || bad "(a) trailing-slash anchor is silent"
fire_prop "$UNNORM" "${PROJ_PHYS}/" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
fired && bad "(a) the un-normalised matcher already fired, so normalisation is not what fixed it" \
      || ok "(a) and it was silent before normalisation"

[ "$PROJ" != "$PROJ_PHYS" ] \
  && ok "AC11b precondition: /tmp diverges from its physical spelling (${PROJ} vs ${PROJ_PHYS})" \
  || bad "AC11b precondition: /tmp does not diverge on this machine -- case (b) cannot be measured here, and this is a SKIP, not a pass"
if [ "$PROJ" != "$PROJ_PHYS" ]; then
  fire_prop "$PROP" "$PROJ" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
  fired && ok "(b) a /tmp anchor against a /private/tmp path FIRES after normalisation" || bad "(b) realpath divergence is silent"
  fire_prop "$UNNORM" "$PROJ" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
  fired && bad "(b) the un-normalised matcher already fired" || ok "(b) and it was silent before normalisation"
fi

fire_prop "$PROP" "$(basename "$PROJ_PHYS")" "${PROJ_PHYS}/AGENTS.md" "$(dirname "$PROJ_PHYS")"
fired && ok "(c) a relative anchor FIRES after normalisation" || bad "(c) relative anchor is silent"
fire_prop "$UNNORM" "$(basename "$PROJ_PHYS")" "${PROJ_PHYS}/AGENTS.md" "$(dirname "$PROJ_PHYS")"
fired && bad "(c) the un-normalised matcher already fired" || ok "(c) and it was silent before normalisation"

# (d) is NOT normalisable: a subdirectory is a valid absolute directory, just
# the wrong one. Recorded as a documented invocation condition and asserted as
# a silent-verdict control rather than claimed as fixed.
fire_prop "$PROP" "${PROJ_PHYS}/docs" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
fired && bad "(d) a non-root anchor fired, which the documented invocation condition says it cannot" \
      || ok "(d) a non-root anchor is silent -- the documented invocation condition, not a fix"

printf '\n== AC11a: the unusable-anchor diagnostic, in TWO parts ==\n'
# An end-to-end assertion here fails BY DESIGN: harness-managed.sh reads the
# same anchor expression and both its markers need it traversable, so on a
# broken anchor the hook exits before the diagnostic can run.
GUARD_PREFIX='"${CLAUDE_PLUGIN_ROOT}"/hooks/lib/harness-managed.sh || exit 0; '
POSTGUARD=${PROP#"$GUARD_PREFIX"}
if [ "$POSTGUARD" = "$PROP" ]; then
  bad "the guard prefix strip changed nothing -- part 1 would silently test the shadowed path and pass for the wrong reason"
else
  ok "guard-prefix strip applied, so part 1 tests the post-guard fragment"
  DIAG='[propagation-rule-reminder] anchor unusable: '
  fire_prop "$POSTGUARD" "${PROJ_PHYS}/no-such-anchor" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
  anchored "part 1: the post-guard fragment emits the diagnostic on an unusable anchor" "$ERR" "$DIAG"
  fire_prop "$POSTGUARD" "$PROJ_PHYS" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
  grep -qF "$DIAG" "$ERR" && bad "part 1: the diagnostic also fires on a USABLE anchor" \
                          || ok "part 1: and stays silent on a usable anchor"
fi
fire_prop "$PROP" "${PROJ_PHYS}/no-such-anchor" "${PROJ_PHYS}/AGENTS.md" "$PROJ_PHYS"
TOTAL_BYTES=$(( $(wc -c < "$OUT") + $(wc -c < "$ERR") ))
check "part 2: the FULL command emits 0 bytes on the same anchor (the shadowing is real)" "$TOTAL_BYTES" "0"

# ---------------------------------------------------------------------------
printf '\n== AC8 + AC13: the real hook on a class the pre-fix arms matched ==\n'
# ---------------------------------------------------------------------------
PREFIX_PATTERN=$(bash "${ROOT}/scripts/check-propagation-arms.sh" --print-prefix-pattern)
[ -n "$PREFIX_PATTERN" ] && ok "the pre-fix case pattern is a committed constant, read from one place" \
                         || bad "could not read the pre-fix pattern"
matched_before(){ CLAUDE_PLUGIN_ROOT="${WORK}/elsewhere/plugin" eval "case \"\$1\" in ${PREFIX_PATTERN}) return 0 ;; esac; return 1"; }
matched_before "${PROJ_PHYS}/.claude/skills/deploy/SKILL.md" \
  && ok "the pre-fix arms matched a project-local .claude/skills/*/SKILL.md" \
  || bad "the pre-fix arms no longer match that class, so AC13 has lost its witness"
matched_before "${PROJ_PHYS}/agents/design.md" \
  && bad "the pre-fix arms matched agents/design.md, which they could not in a consuming project" \
  || ok "and they did NOT match agents/design.md -- the dead half of the old set, reproduced"

fire_prop "$PROP" "$PROJ_PHYS" "${PROJ_PHYS}/.claude/skills/deploy/SKILL.md" "$PROJ_PHYS"
fired && ok "the REAL hook fires on .claude/skills/deploy/SKILL.md" \
      || bad "the real hook is silent on the class the tenth arm restored"

printf '\n== AC11: the five bound controls stay silent through the real hook ==\n'
for c in my-agents/notes.md sub-agents/x.md src/docs/readme.md node_modules/x/docs/a.md vendor/scripts/build.sh; do
  : > "${PROJ_PHYS}/${c}"
  fire_prop "$PROP" "$PROJ_PHYS" "${PROJ_PHYS}/${c}" "$PROJ_PHYS"
  fired && bad "control ${c} fired through the real hook" || ok "control ${c} is silent"
done
SIB=$(mktemp -d /tmp/gh75-sibling.XXXXXX); SIB_PHYS=$(cd "$SIB" && pwd -P)
: > "${SIB_PHYS}/AGENTS.md"
fire_prop "$PROP" "$PROJ_PHYS" "${SIB_PHYS}/AGENTS.md" "$PROJ_PHYS"
fired && bad "a sibling project's AGENTS.md fired -- the anchor is not holding" \
      || ok "a sibling project's AGENTS.md is silent"
rm -rf "$SIB"

# ---------------------------------------------------------------------------
printf '\n== AC14: a guarded hook no-ops in a marker-free directory, and says so by not firing ==\n'
# ---------------------------------------------------------------------------
GUARDED=$(jq -r '.hooks | to_entries[] | .key as $ev | .value[] | (.matcher // "-") as $m
                 | .hooks | to_entries[] | select(.value.command|test("harness-managed"))
                 | [$ev, $m, (.key|tostring)] | @tsv' "$HOOKS")
gn=$(printf '%s\n' "$GUARDED" | wc -l | tr -d ' ')
[ "$gn" -gt 0 ] && ok "${gn} commands carry the harness-managed guard" || bad "no command carries the guard"
while IFS=$(printf '\t') read -r ev matcher idx; do
  [ -n "${ev:-}" ] || continue
  key="${ev}|${matcher}|${idx}"
  # The guard reads CLAUDE_PROJECT_DIR, so the marker-free dir has to be the
  # anchor as well as the cwd or the guard would still find the real project.
  c=$(cmd_of "$ev" "$matcher" "$idx")
  pay=$(jq -nc --arg p "${MARKERLESS}/AGENTS.md" '{tool_input:{file_path:$p, command:"git commit -m x", content:"### x\n"}, hook_event_name:"SessionStart", session_id:"s-guard"}')
  printf '%s' "$pay" | ( cd "$MARKERLESS" && CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$MARKERLESS" bash -c "$c" ) > "$OUT" 2> "$ERR"
  rc=$?
  n=$(( $(wc -c < "$OUT") + $(wc -c < "$ERR") ))
  if [ "$rc" -eq 0 ] && [ "$n" -eq 0 ]; then ok "${key}: silent and rc 0 in a marker-free directory"
  else bad "${key}: emitted ${n} bytes / rc ${rc} in a marker-free directory"; fi
done <<EOF4
$GUARDED
EOF4
[ -f "${MARKERLESS}/AGENTS.md" ] && bad "the marker-free fixture is not marker-free" \
                                 || ok "the marker-free fixture carries neither marker, so the silence above is the guard"

# ---------------------------------------------------------------------------
printf '\n== AC7 + AC17: the read allowance, and the method bullets that state it ==\n'
# ---------------------------------------------------------------------------
# An address the agent may not open is no better than the literal token this
# task removed, so the allowance is part of the fix rather than paperwork.
# Everything below runs `case` against the glob as the shell sees it; `*` and
# `**` both cross slashes there, which is the behaviour the permission entry
# relies on.
TPL="${ROOT}/templates/project/.claude/settings.json"
# Everything after this reads the parsed copy, so a template that does not
# parse cannot reach the assertions as an empty allow list.
jq -e . "$TPL" > "${WORK}/tpl.json" && ok "the shipped template parses" || bad "the shipped template does not parse"
jq -r '.permissions.allow[] | select(startswith("Read(")) | select(test("plugins/cache"))' "${WORK}/tpl.json" > "${WORK}/cache-allow.txt"
n_cache=$(grep -c . "${WORK}/cache-allow.txt")
check "exactly one cache-rooted Read allowance ships in the template" "$n_cache" "1"
ENTRY=$(head -1 "${WORK}/cache-allow.txt")

# 14 version directories coexist in the live cache, so a version literal here
# would break on the next upgrade rather than at install time. The emptiness
# guard comes first because every pattern below is satisfied by an empty entry.
if [ -z "$ENTRY" ]; then bad "no cache-rooted allowance to examine -- the assertions below would be vacuous"; else
  case "$ENTRY" in
    *[0-9]*) bad "the allowance carries a version literal: [${ENTRY}]" ;;
    *) ok "the allowance carries no version literal" ;;
  esac
fi

GLOB=${ENTRY#Read(}; GLOB=${GLOB%)}
GLOB="${HOME}${GLOB#\~}"
case "$GLOB" in
  "${HOME}/"*) ok "the allowance expands to an absolute glob under \$HOME: [${GLOB}]" ;;
  *) bad "the allowance does not expand under \$HOME: [${GLOB}]" ;;
esac

# CLAUDE_PLUGIN_ROOT is accepted ONLY when it already names a cache install.
# Under this repo's own documented dev mode (`claude --plugin-dir <source
# tree>`) it names the SOURCE TREE, which no cache-rooted glob can match -- so
# taking it unconditionally turns the documented dev setup into a false RED
# (measured: 2 of these legs fail under it). Falling through reaches the glob
# loop below, which has its own loud could-not-run branch.
live_root=""
case "${CLAUDE_PLUGIN_ROOT:-}" in
  # The `*` crosses slashes, so the pattern alone gates on the path's SHAPE and
  # admits a cache-shaped directory that does not exist, or another plugin's
  # install. Measured without the readability test: a non-existent
  # .../cache/fake-market/harness/9.9.9 gave 119/0 while printing "the live
  # install root resolved" -- a false GREEN on a liveness claim the message
  # makes in words; another plugin's install reddened the two glob legs instead
  # of falling through. The `-r` test is the same precondition the glob loop
  # below already applies, so both paths now agree on what "live" means.
  "${HOME}"/.claude/plugins/cache/*)
    [ -r "${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md" ] && live_root="${CLAUDE_PLUGIN_ROOT}" ;;
esac
if [ -z "$live_root" ]; then
  for m in "${HOME}"/.claude/plugins/cache/*/harness/*/docs/agents-method.md; do
    [ -r "$m" ] || continue
    live_root=$(cd -- "$(dirname -- "$m")/.." && pwd); break
  done
fi
if [ -n "$live_root" ]; then
  # Labelled "an installed root", not "the live one". The loop above breaks on
  # the first readable match of an UNORDERED glob, and the shell's order is not
  # the version order -- on a machine with several cached roots it picks the
  # lowest-sorting one, which is almost never the running version. That is
  # harmless for what this leg tests (the allowance is version-agnostic by
  # construction) but the old label claimed more than was measured.
  ok "an installed harness root resolved: ${live_root}"
  case "$live_root" in
    $GLOB) ok "the allowance matches that installed root" ;;
    *) bad "the allowance does not match the installed root [${live_root}]" ;;
  esac
  case "${live_root}/docs/agents-method.md" in
    $GLOB) ok "and it matches a method file inside that root, which is what gets read" ;;
    *) bad "the allowance does not match a method file under that root" ;;
  esac

  # Stronger than the single representative above and still fixed-count: EVERY
  # cached harness root must match, so a pass cannot depend on which one the
  # glob loop happened to reach first. No root count is written down here -- it
  # is a property of whoever's machine runs this.
  miss=""; nroots=0
  for m in "${HOME}"/.claude/plugins/cache/*/harness/*/docs/agents-method.md; do
    [ -r "$m" ] || continue
    r=$(cd -- "$(dirname -- "$m")/.." && pwd); nroots=$((nroots + 1))
    case "$r" in $GLOB) ;; *) miss="${miss} ${r}" ;; esac
  done
  if [ "$nroots" = 0 ]; then
    bad "no cached harness root to check the allowance against -- not a pass"
  elif [ -n "$miss" ]; then
    bad "the allowance misses installed roots:${miss}"
  else
    ok "the allowance matches ALL ${nroots} cached harness roots"
  fi
else
  bad "AC7's installed-root leg could not run: no readable harness under ~/.claude/plugins/cache -- not a pass"
fi

# The marketplace segment is deliberately a name no marketplace here uses, so a
# pass proves the `*` is a wildcard and not a coincidence with the real one.
for v in 0.0.1 99.99.99; do
  synth="${HOME}/.claude/plugins/cache/some-marketplace/harness/${v}/docs/agents-method.md"
  case "$synth" in
    $GLOB) ok "the allowance survives an upgrade to ${v}" ;;
    *) bad "the allowance misses version ${v}: [${synth}]" ;;
  esac
done

for neg in "${HOME}/.ssh/config" "${HOME}/.claude/plugins/cache/some-marketplace/other-plugin/0.1.0/docs/x.md"; do
  case "$neg" in
    $GLOB) bad "the allowance reaches outside the harness install: [${neg}]" ;;
    *) ok "control: the allowance does not reach ${neg}" ;;
  esac
done

# A preserved control. What is degraded is the glob ITSELF: degrading a nearby
# token would leave the allowance version-agnostic and the control would pass
# while measuring nothing. Changing this invalidates AC7.
PIN_PAT='/harness/**'
PIN_REPL='/harness/0.0.1/**'
PINNED=${GLOB/"$PIN_PAT"/$PIN_REPL}
if [ "$PINNED" = "$GLOB" ]; then bad "the version-pinned degradation did not land -- the control measures nothing"; else
  ok "version-pinned degradation built"
  later="${HOME}/.claude/plugins/cache/some-marketplace/harness/99.99.99/docs/agents-method.md"
  case "$later" in
    $PINNED) bad "the version-pinned variant still matched a later version, so this control cannot fail" ;;
    *) ok "the version-pinned variant is BLIND to a later version -- the specific defect the glob avoids" ;;
  esac
fi

# The oracle for "deny byte-untouched" is an ENUMERATED committed constant.
# Not the other settings file: an identical edit to BOTH would satisfy a
# cross-file comparison while the list changed. Not `git show HEAD:` either --
# that goes vacuous the moment this change is committed, because HEAD then
# holds the new content and the leg compares it against itself. Sixteen
# enumerated entries fail whenever anyone edits the list, at any later date.
DENY_EXPECTED=$(jq -Sc . <<'DENYJSON'
[ "Edit(**/.env)",
  "Edit(**/secrets.json)",
  "Read(**/.env)",
  "Read(**/*.keys)",
  "Read(**/secrets.json)",
  "Read(**/GoogleService-Info.plist)",
  "Read(**/*Keys*.swift)",
  "Read(**/*Secrets*)",
  "Read(**/.DS_Store)",
  "Read(**/*.log)",
  "Read(.idea/**)",
  "Read(.vscode/**)",
  "Read(out/**)",
  "Read(build/**)",
  "Read(target/**)",
  "Read(node_modules/**)" ]
DENYJSON
)
check "the template's deny list is exactly the committed 16 entries" \
  "$(jq -Sc '.permissions.deny' "$TPL")" "$DENY_EXPECTED"

# Secondary, and REPORTED rather than asserted. The two files' deny lists were
# measured identical before this change, but the spec records that as an
# observation about a pair with no sync group -- so a failing `check` here
# would be a contract, blocking a suite in AGENTS.md check 4's list on a
# property no artefact stands behind. It prints its finding and never fails;
# the enumerated leg above is what guards the property the change was approved
# under. Make this a `check` only once the pair is a declared sync group.
if [ "$(jq -Sc '.permissions.deny' "$TPL")" = "$(jq -Sc '.permissions.deny' "${ROOT}/.claude/settings.json")" ]; then
  printf '  note the template deny list still agrees with this repo own -- observation, not asserted\n'
else
  printf '  note the template and this repo deny lists have DIVERGED -- observation, not asserted; see the spec Open observations row\n'
fi

awk '/^## Permissions$/{f=1;next} /^## /{f=0} f' "${ROOT}/docs/agents-method.md" > "${WORK}/perms.md"
[ -s "${WORK}/perms.md" ] && ok "the method's § Permissions section extracted" \
                          || bad "could not extract § Permissions from docs/agents-method.md"
grep -qF 'read access to the installed plugin directory' "${WORK}/perms.md" \
  && ok "§ Permissions names the plugin directory as read-allowed (AC7)" \
  || bad "§ Permissions carries no read-allowance bullet for the plugin directory"
grep -qF 'installed copy' "${WORK}/perms.md" \
  && grep -qF 'registry.json' "${WORK}/perms.md" \
  && ok "§ Permissions carries the source-repository boundary, naming the registry (AC17)" \
  || bad "§ Permissions carries no installed-copy boundary bullet naming registry.json"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
