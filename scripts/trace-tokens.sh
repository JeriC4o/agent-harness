#!/usr/bin/env bash
#
# Attribute token spend to turns and skills, from a session transcript.
#
# Usage:  trace-tokens.sh <session.jsonl> [--json] [--top N]
#
#   Transcripts live at ~/.claude/projects/<project-slug>/<session-id>.jsonl.
#   Find the most recent one with:  ls -t ~/.claude/projects/*/*.jsonl | head -1
#
# Exit: 0 on success (an empty transcript is success), 2 on usage error.
#
# THREE NUMBERS, NEVER ONE:
#
#   fresh (input + output)  what the work actually cost
#   cache_read              context re-read volume -- a LOOP signal, not a cost
#                           signal. On a real session it ran 150,000,000 against
#                           580,000 fresh; summing them into one "tokens" figure
#                           buries everything actionable under cache traffic.
#   cache_creation          what was paid to put context into the cache
#
# FOUR THINGS THIS GETS RIGHT THAT A NAIVE READING DOES NOT:
#
#   1. One API message becomes SEVERAL JSONL lines -- one per content block --
#      and every line repeats the FULL usage object. Measured: 1,021 lines for
#      558 messages. Summing lines overcounts by ~45%. Messages are deduplicated
#      by `message.id`, and the discarded count is reported, not hidden.
#
#   2. Subagent turns are NOT in the session transcript. They live in
#      <session-id>/subagents/agent-*.jsonl beside it; the session file itself is
#      100% `isSidechain: false`. A tracer reading only the session file reports
#      subagent spend as ZERO -- inverting the finding, because a turn that
#      spawned five agents then looks cheap exactly when it was expensive.
#
#   3. The unit is a TURN, not a "workflow stage". Two stage models were tried
#      against a real session and both failed. Ending a skill's span at the next
#      human turn dumped 95% of spend into "(no skill)", because the user
#      answering /task's own questions ended the stage. Ending it at the next
#      Skill call instead let one skill absorb 392 messages of unrelated later
#      work. A turn boundary is the one thing here that is not a guess: the user
#      pressed enter.
#
#   4. `attributionSkill` is ground truth but SPARSE -- it marks the opening
#      stretch of a skill and then stops (47 of 558 messages on a real session).
#      Taking it at face value undercounts a skill tenfold. The untagged
#      remainder of the SAME TURN is carried and reported separately as
#      `carried`, so an inference is never printed as a measurement, and the
#      carry can never leak into a turn the user started for something else.
#
# PRIVACY: transcripts contain everything the session saw, including files under
# an ASK gate. This script emits COUNTS, SKILL NAMES, TIMESTAMPS and AGENT IDS
# only -- never message text, tool input, or tool output. Keep it that way.
#
# Tests: scripts/test-trace-tokens.sh

set -uo pipefail

die()  { printf 'trace-tokens: %s\n' "$1" >&2; exit 2; }
warn() { printf 'trace-tokens: %s\n' "$1" >&2; }

SESSION=""; AS_JSON=0; TOP=10
while [ $# -gt 0 ]; do
  case "$1" in
    --json) AS_JSON=1 ;;
    --top)  shift; [ $# -gt 0 ] || die "--top needs a number"
            case "$1" in ''|*[!0-9]*) die "--top needs a number, got: $1" ;; esac
            TOP="$1" ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)  [ -z "$SESSION" ] || die "more than one transcript given"; SESSION="$1" ;;
  esac
  shift
done

[ -n "$SESSION" ] || die "usage: trace-tokens.sh <session.jsonl> [--json] [--top N]"
[ -f "$SESSION" ] || die "no such transcript: $SESSION"
command -v jq >/dev/null 2>&1 || die "jq is required"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT INT TERM

# Lines that are not JSON are counted and reported -- never silently skipped. A
# transcript this script cannot fully read yields a number that is quietly too
# small, which is the failure mode hardest to notice.
count_unparseable() {
  jq -R '. as $l
         | if ($l|test("\\S")) and ((try ($l|fromjson|true) catch false)|not)
           then 1 else empty end' "$1" 2>/dev/null | awk 'END{print NR+0}'
}
parse_into() { jq -R -c 'fromjson? // empty' "$1" 2>/dev/null > "$2"; }

parse_into "$SESSION" "$WORK/main.jsonl"
BAD=$(count_unparseable "$SESSION")

SUBDIR="${SESSION%.jsonl}/subagents"
: > "$WORK/subs.json"
sub_count=0
if [ -d "$SUBDIR" ]; then
  for f in "$SUBDIR"/*.jsonl; do
    [ -f "$f" ] || continue
    sub_count=$((sub_count+1))
    BAD=$((BAD + $(count_unparseable "$f")))
    parse_into "$f" "$WORK/one.jsonl"
    # `slug` is NOT unique -- five agents in one real session shared one slug.
    # agentId is, so it is what labels a row.
    jq -s -c --arg file "$(basename "$f")" '
      ( [ .[] | select(.agentId != null) | .agentId ] | first ) as $aid
      | ( [ .[] | select(.slug != null) | .slug ] | first ) as $slug
      | [ .[] | select(.type=="assistant" and (.message.id != null)) ]
      | ( reduce .[] as $e ({seen:{}, keep:[]};
            if .seen[$e.message.id] then .
            else .seen[$e.message.id] = true | .keep += [$e] end) ).keep
      | { agent_id: ($aid // ($file | sub("^agent-";"") | sub("\\.jsonl$";""))),
          slug: $slug,
          first_ts: ( [ .[] | .timestamp ] | sort | first ),
          messages: length,
          input:          ( [ .[] | .message.usage.input_tokens // 0 ]                | add // 0 ),
          output:         ( [ .[] | .message.usage.output_tokens // 0 ]               | add // 0 ),
          cache_read:     ( [ .[] | .message.usage.cache_read_input_tokens // 0 ]     | add // 0 ),
          cache_creation: ( [ .[] | .message.usage.cache_creation_input_tokens // 0 ] | add // 0 ) }
      | .fresh = (.input + .output)' "$WORK/one.jsonl" >> "$WORK/subs.json"
  done
fi

[ "$BAD" -gt 0 ] && warn "${BAD} unparseable line(s) skipped; the totals below are incomplete by that much"

jq -n \
  --slurpfile main "$WORK/main.jsonl" \
  --slurpfile subs "$WORK/subs.json" \
  --arg session "$(basename "${SESSION%.jsonl}")" \
  --arg path "$SESSION" \
  --argjson bad "$BAD" \
  --argjson subfiles "$sub_count" '

  # A human prompt opens a turn. A tool_result does NOT -- that is the session
  # talking to itself, and treating it as a boundary would shatter every turn
  # into one-message fragments. Runtime-injected prompts are not the user
  # either, so they do not open a turn.
  def is_human_turn:
    .type == "user"
    and (.isSidechain != true)
    and ((.message.content | type) == "string")
    and (( .message.content
           | startswith("<task-notification>")
             or startswith("<local-command-")
             or startswith("<system-reminder>") ) | not);

  ( reduce $main[] as $e ({turn: 0, started: null, carry: null, seen: {}, dups: 0, out: [], starts: {}};
      if ($e | is_human_turn)
      then .turn += 1 | .carry = null | .starts[(.turn|tostring)] = $e.timestamp
      elif $e.type == "assistant" then
        ( if ($e.attributionSkill // null) != null then .carry = $e.attributionSkill else . end)
        | .attr = ( if ($e.attributionSkill // null) != null then "attributed"
                    elif .carry != null then "carried"
                    else "unattributed" end )
        | if ($e.message.id // null) == null then .
          elif (.seen[$e.message.id] // false) then .dups += 1
          else .seen[$e.message.id] = true
             | .out += [ { id: $e.message.id, ts: $e.timestamp, turn: .turn,
                           skill: .carry, attribution: .attr,
                           u: ($e.message.usage // {}) } ]
          end
      else . end ) ) as $st

  | $st.out as $msgs

  # A subagent is billed to whatever turn was running when it started: the last
  # main-session message at or before its first timestamp.
  | ( $subs | map( . as $s
        | ( [ $msgs[] | select(.ts != null and $s.first_ts != null and .ts <= $s.first_ts) ] | last ) as $a
        | . + { turn: ($a.turn // 0), skill: ($a.skill // null) } ) ) as $subrows

  | def sum(f): map(f) | add // 0;
    def fresh_of: (.u.input_tokens // 0) + (.u.output_tokens // 0);

    ( $msgs
      | group_by(.turn)
      | map( . as $g
             | ( [ $subrows[] | select(.turn == $g[0].turn) ] ) as $mine
             | { index: $g[0].turn,
                 started: ($st.starts[($g[0].turn|tostring)] // ($g | map(.ts) | sort | first)),
                 skill: ( [ $g[] | .skill ] | map(select(. != null)) | first ),
                 messages: ($g | length),
                 messages_skill: ($g | map(select(.attribution != "unattributed")) | length),
                 fresh:            ($g | sum(fresh_of)),
                 fresh_attributed: ($g | map(select(.attribution=="attributed")) | sum(fresh_of)),
                 fresh_carried:    ($g | map(select(.attribution=="carried"))    | sum(fresh_of)),
                 cache_read:       ($g | sum(.u.cache_read_input_tokens // 0)),
                 cache_creation:   ($g | sum(.u.cache_creation_input_tokens // 0)),
                 subagents: ($mine | length),
                 subagent_fresh: ($mine | sum(.fresh)),
                 subagent_cache_read: ($mine | sum(.cache_read)) } )
      | sort_by(.index) ) as $turns

  | { session: $session,
      transcript: $path,
      messages: ($msgs | length),
      turns_total: ($turns | length),
      prompts_total: $st.turn,
      duplicate_lines_discarded: $st.dups,
      unparseable_lines: $bad,
      totals: {
        main: {
          messages:       ($msgs | length),
          input:          ($msgs | sum(.u.input_tokens // 0)),
          output:         ($msgs | sum(.u.output_tokens // 0)),
          fresh:          ($msgs | sum(fresh_of)),
          cache_read:     ($msgs | sum(.u.cache_read_input_tokens // 0)),
          cache_creation: ($msgs | sum(.u.cache_creation_input_tokens // 0)) },
        subagents: {
          count:          $subfiles,
          messages:       ($subrows | sum(.messages)),
          fresh:          ($subrows | sum(.fresh)),
          cache_read:     ($subrows | sum(.cache_read)),
          cache_creation: ($subrows | sum(.cache_creation)) } },
      turns: $turns,
      skills: ( $turns
                | map(select(.skill != null))
                | group_by(.skill)
                | map({ skill: .[0].skill,
                        turns: length,
                        messages: sum(.messages_skill),
                        fresh: (sum(.fresh_attributed) + sum(.fresh_carried)),
                        fresh_attributed: sum(.fresh_attributed),
                        fresh_carried: sum(.fresh_carried),
                        cache_read: sum(.cache_read),
                        subagents: sum(.subagents) })
                | sort_by(-.fresh) ),
      subagents: ( $subrows | map({agent_id, slug, turn, skill, messages,
                                   fresh, cache_read, cache_creation})
                            | sort_by(.turn) ) }
  | .totals.all = { fresh:          (.totals.main.fresh + .totals.subagents.fresh),
                    cache_read:     (.totals.main.cache_read + .totals.subagents.cache_read),
                    cache_creation: (.totals.main.cache_creation + .totals.subagents.cache_creation) }
  ' > "$WORK/report.json" || die "failed to build the report"

if [ "$AS_JSON" = "1" ]; then
  cat "$WORK/report.json"
  exit 0
fi

# Human report. Every field printed is a count, a skill name, a timestamp or an
# agent id. --top trims the VIEW only: the totals above it are computed over
# every turn, because a total that shrinks when you narrow the display is the
# quietest way for this tool to lie.
jq -r --argjson top "$TOP" '
  def n: tostring | if length > 3
    then ( explode | reverse | to_entries
           | map(if (.key > 0 and .key % 3 == 0) then [44, .value] else [.value] end)
           | flatten | reverse | implode )
    else . end;
  def pad(w): . + (" " * (w - length));
  def lpad(w): (" " * (w - length)) + .;
  def clock: if . == null then "--:--:--" else .[11:19] end;

  "Session:    \(.session)",
  "Transcript: \(.transcript)",
  "Messages:   \(.messages | n) across \(.turns_total | n) turn(s) with spend, of \(.prompts_total | n) prompt(s)   (\(.duplicate_lines_discarded | n) duplicate content-block lines discarded" +
    (if .unparseable_lines > 0 then ", \(.unparseable_lines | n) unparseable" else "" end) + ")",
  "",
  "== Totals ==",
  "  " + ("" | pad(14)) + ("fresh(in+out)" | lpad(15)) + ("cache_read" | lpad(16)) + ("cache_create" | lpad(15)),
  "  " + ("main" | pad(14)) + ((.totals.main.fresh|n) | lpad(15)) + ((.totals.main.cache_read|n) | lpad(16)) + ((.totals.main.cache_creation|n) | lpad(15)),
  "  " + ("subagents(\(.totals.subagents.count))" | pad(14)) + ((.totals.subagents.fresh|n) | lpad(15)) + ((.totals.subagents.cache_read|n) | lpad(16)) + ((.totals.subagents.cache_creation|n) | lpad(15)),
  "  " + ("TOTAL" | pad(14)) + ((.totals.all.fresh|n) | lpad(15)) + ((.totals.all.cache_read|n) | lpad(16)) + ((.totals.all.cache_creation|n) | lpad(15)),
  "",
  "== Costliest turns ==   (showing \([$top, .turns_total] | min) of \(.turns_total) turns, by fresh spend)",
  "  " + ("turn" | lpad(5)) + "  " + ("started" | pad(10)) + ("skill" | pad(22)) + ("msgs" | lpad(6)) + ("fresh" | lpad(13)) + ("cache_read" | lpad(16)) + ("agents" | lpad(12)),
  ( .turns | sort_by(-.fresh) | .[0:$top] | .[]
    | "  " + ((.index|tostring) | lpad(5)) + "  " + ((.started | clock) | pad(10))
      + ((.skill // "-") | pad(22)) + ((.messages|n) | lpad(6))
      + ((.fresh|n) | lpad(13)) + ((.cache_read|n) | lpad(16))
      + ((if .subagents > 0 then "\(.subagents) (\(.subagent_fresh|n))" else "-" end) | lpad(12)) ),
  "",
  ( if (.skills | length) == 0 then "== By skill ==   no turn carried a runtime skill attribution"
    else ( "== By skill ==   (exact = runtime-tagged; carried = inferred within the same turn)",
           "  " + ("skill" | pad(24)) + ("turns" | lpad(6)) + ("msgs" | lpad(6)) + ("fresh" | lpad(13)) + ("  = exact" | pad(14)) + ("+ carried" | pad(14)) + ("cache_read" | lpad(16)) ),
         ( .skills[]
           | "  " + (.skill | pad(24)) + ((.turns|n) | lpad(6)) + ((.messages|n) | lpad(6))
             + ((.fresh|n) | lpad(13)) + ("  = " + (.fresh_attributed|n) | pad(14))
             + ("+ " + (.fresh_carried|n) | pad(14)) + ((.cache_read|n) | lpad(16)) )
    end ),
  "",
  ( if (.subagents | length) == 0 then "== Subagents ==   none spawned in this session"
    else ( "== Subagents ==",
           "  " + ("agent" | pad(20)) + ("turn" | lpad(5)) + "  " + ("skill" | pad(22)) + ("msgs" | lpad(6)) + ("fresh" | lpad(13)) + ("cache_read" | lpad(16)) ),
         ( .subagents[]
           | "  " + (.agent_id | pad(20)) + ((.turn|tostring) | lpad(5)) + "  " + ((.skill // "-") | pad(22))
             + ((.messages|n) | lpad(6)) + ((.fresh|n) | lpad(13)) + ((.cache_read|n) | lpad(16)) )
    end )
' "$WORK/report.json"
