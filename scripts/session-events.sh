#!/usr/bin/env bash
#
# Reduce a session transcript to a compact event stream, and flag the loop
# signatures a script can decide. The mechanical pre-pass behind
# /harness:inspect: a script counts, an agent judges.
#
# Usage:
#   session-events.sh <session.jsonl> [--json]
#   session-events.sh <session.jsonl> --signatures [--json]
#                     [--window N] [--min-repeats N] [--spike-factor N]
#
# Exit: 0 on success (an empty transcript is success), 2 on usage error.
#
# WHY A PRE-PASS. A real session runs to thousands of entries; handing that to a
# model is not an option, and most of it is content the inspector must not see
# anyway. This emits one line per event -- tool name, argument fingerprint, turn,
# skill, error flag -- so the agent reasons over a few hundred lines.
#
# PRIVACY: a transcript holds everything the session saw, including ASK-gated
# files. This script emits tool NAMES, the first token of a Bash command, one-way
# fingerprints, timestamps and counts. It never emits a command line, a file
# path, a prompt, or any tool output. The fingerprint exists precisely so
# repetition can be detected without reproducing what was repeated.
#
# LOOP-SHAPED IS NOT LOOP. Every repetition signature carries a TIME qualifier:
# enough of the repeats must fall inside one window. The window SLIDES -- the
# question is whether the threshold is met in ANY window, not whether the whole
# group fits in one. Asking the latter can only pass a call that occurs nowhere
# else in the session, so on a real transcript it discarded every candidate
# there was; a row therefore reports `count` (the burst) beside
# `total_in_session` (the group). Only repeated-tool-call also carries the STATE
# qualifier (no Edit/Write inside the burst -- re-running a gate after changing a
# file is the workflow working, not a loop); error-retry-loop and
# repeated-agent-spawn get the window alone. Each row therefore reports the
# `filters` that actually ran on it and the `threshold` it fired at, because a
# judge told a check ran when it did not reads every candidate toward confirm --
# and a check that cries wolf is a failure this repo has shipped twice already.
#
# THRESHOLDS ARE CALIBRATED AGAINST REAL SESSIONS, not guessed. The depth
# factor defaults to 5x the median turn, because 3x flagged 15 of 67 turns on a
# real session -- one turn in five is a list nobody reads. At 5x it flags 6,
# and those are the turns that actually went round. Tune with --spike-factor.
#
# A SIGNATURE WITH NO INPUT SAYS SO. `step-regression` needs progress-file
# writes; no transcript on this machine has one. It is reported under
# `unavailable` with a reason rather than returning a silent zero, because a
# silent zero is indistinguishable from "clean" and is how a dead check earns
# trust it has not got.
#
# Tests: scripts/test-session-events.sh

set -uo pipefail

die()  { printf 'session-events: %s\n' "$1" >&2; exit 2; }
warn() { printf 'session-events: %s\n' "$1" >&2; }

SESSION=""; AS_JSON=0; MODE=events
WINDOW=600; MIN_REPEATS=3; SPIKE=5
while [ $# -gt 0 ]; do
  case "$1" in
    --json)        AS_JSON=1 ;;
    --signatures)  MODE=signatures ;;
    --window)      shift; [ $# -gt 0 ] || die "--window needs a number"; WINDOW="$1" ;;
    --min-repeats) shift; [ $# -gt 0 ] || die "--min-repeats needs a number"; MIN_REPEATS="$1" ;;
    --spike-factor)shift; [ $# -gt 0 ] || die "--spike-factor needs a number"; SPIKE="$1" ;;
    -h|--help)     sed -n '2,10p' "$0"; exit 0 ;;
    -*)            die "unknown option: $1" ;;
    *)  [ -z "$SESSION" ] || die "more than one transcript given"; SESSION="$1" ;;
  esac
  shift
done
for v in "$WINDOW" "$MIN_REPEATS" "$SPIKE"; do
  case "$v" in ''|*[!0-9]*) die "thresholds must be whole numbers, got: $v" ;; esac
done

[ -n "$SESSION" ] || die "usage: session-events.sh <session.jsonl> [--signatures] [--json]"
[ -f "$SESSION" ] || die "no such transcript: $SESSION"
command -v jq >/dev/null 2>&1 || die "jq is required"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT INT TERM

BAD=$(jq -R '. as $l
        | if ($l|test("\\S")) and ((try ($l|fromjson|true) catch false)|not)
          then 1 else empty end' "$SESSION" 2>/dev/null | awk 'END{print NR+0}')
[ "$BAD" -gt 0 ] && warn "${BAD} unparseable line(s) skipped; the stream below is incomplete by that much"
jq -R -c 'fromjson? // empty' "$SESSION" 2>/dev/null > "$WORK/main.jsonl"

jq -n \
  --slurpfile main "$WORK/main.jsonl" \
  --arg session "$(basename "${SESSION%.jsonl}")" \
  --arg path "$SESSION" \
  --argjson bad "$BAD" \
  --argjson window "$WINDOW" \
  --argjson minrep "$MIN_REPEATS" \
  --argjson spike "$SPIKE" '

  # An ALLOWLIST, not a pattern. A branch name matches any reasonable pattern,
  # and a branch name can carry a project identifier -- so only known subcommand
  # VERBS survive, and at most two of them. Everything else (flags, paths,
  # titles, messages, refs) is dropped. This exists because "gh" alone cannot
  # tell filing a ticket from reading one, which blocked the measurement the
  # label was needed for in the first place.
  [ "git", "gh", "make", "cargo", "npm", "yarn", "pnpm", "go", "docker", "jq" ] as $subcmd_hosts
  | [ "status", "commit", "push", "pull", "fetch", "merge", "rebase", "checkout",
      "switch", "branch", "diff", "log", "add", "show", "stash", "tag", "remote",
      "init", "clone", "restore", "worktree", "revert", "cherry-pick", "blame",
      "issue", "pr", "repo", "api", "release", "run", "auth", "workflow",
      "create", "list", "view", "edit", "close", "reopen", "comment", "ready",
      "build", "test", "lint", "fmt", "check", "install", "start", "publish",
      "clippy", "doc", "bench", "update", "upgrade", "clean", "compose" ] as $subcmds
  |
  # djb2 over the serialised tool input. One-way and content-free: it lets
  # repetition be COUNTED without the thing repeated ever being printed.
  def fp: tostring | explode
          | reduce .[] as $c (5381; ((. * 33) + $c) % 4294967296)
          | tostring;

  def is_human_turn:
    .type == "user" and (.isSidechain != true)
    and ((.message.content | type) == "string")
    and (( .message.content
           | startswith("<task-notification>") or startswith("<local-command-")
             or startswith("<system-reminder>") ) | not);

  # A transcript timestamp carries milliseconds ("…:22.267Z") and fromdateiso8601
  # rejects that spelling, so the fractional part is stripped before the parse.
  # What a FAILED parse yields is the load-bearing half: null, never 0. A 0 fed
  # into the `<= $window` comparisons below turns an unreadable timestamp into a
  # maximally-qualifying row -- the candidate confirmed BECAUSE its input could
  # not be read. A null drops the row from the slide in `densest` instead.
  def secs: if . == null then null
            else ( try (sub("\\.[0-9]+"; "") | fromdateiso8601) catch null ) end;

  # error-retry-loop fires at two, while $minrep (3) governs the repeat shapes.
  # Two failures of the same call is already a retry loop; a third is the bar for
  # calls that SUCCEEDED. The number is named so the report can state it per
  # signature instead of advertising one min_repeats that this shape ignores.
  def retry_min: 2;

  # A Bash command contributes a validated command NAME or nothing. "git" is the
  # same risk class as the command table in AGENTS.md; the full line is not, and
  # a transcript is full of lines that must never be reprinted.
  #
  # Taking the literal first token is NOT enough, which real output proved: a
  # command beginning with an assignment put an absolute scratchpad path into the
  # label. Leading NAME=value pairs are dropped (their values are often paths),
  # a leading ./ is stripped, and what remains must look like a bare command name
  # or it is replaced wholesale.
  def bin_of:
    ( (.input.command // "") | split(" ") | map(select(length > 0))
      | ( reduce .[] as $tok ({done: false, rest: []};
            if .done then .rest += [$tok]
            elif ($tok | test("^[A-Za-z_][A-Za-z0-9_]*=")) then .
            else .done = true | .rest += [$tok] end ) ).rest ) as $toks
    | ( ($toks[0] // "") | sub("^\\./"; "") ) as $cmd
    | if ($cmd | test("^[A-Za-z0-9][A-Za-z0-9._+-]{0,23}$") | not) then "(other)"
      elif ($cmd | IN($subcmd_hosts[])) then
        ( [ $cmd ] + ( $toks[1:3] | map(select(IN($subcmds[]))) ) ) | join(" ")
      else $cmd end;

  # ---- pass 1: flatten to events ------------------------------------------
  ( reduce $main[] as $e ({turn: 0, skill: null, seq: 0, out: []};
      if ($e | is_human_turn)
      then .turn += 1 | .seq += 1
         | .out += [{seq: .seq, ts: $e.timestamp, turn: .turn, skill: null,
                     kind: "prompt", tool: null, bin: null, fingerprint: null}]
      elif $e.type == "assistant" then
        ( if ($e.attributionSkill // null) != null then .skill = $e.attributionSkill else . end)
        | . as $acc
        | reduce ($e.message.content[]? | select(.type == "tool_use")) as $t (.;
            .seq += 1
            | .out += [{ seq: .seq, ts: $e.timestamp, turn: $acc.turn, skill: $acc.skill,
                         kind: "tool",
                         tool: $t.name,
                         bin: (if $t.name == "Bash" then ($t | bin_of)
                               elif $t.name == "Agent" then ($t.input.subagent_type // "default")
                               elif $t.name == "Skill" then ($t.input.skill // "?")
                               else null end),
                         tool_use_id: $t.id,
                         progress_step: ( if (($t.input.file_path // "") | test("\\.progress\\.md$"))
                                          then ( ($t.input.content // $t.input.new_string // "")
                                                 | (try (capture("current_step:\\*\\*\\s*Step\\s+(?<n>[0-9]+)").n | tonumber) catch null) )
                                          else null end ),
                         fingerprint: ($t.input | fp) }])
      elif $e.type == "user" then
        # Errors ride on the tool_result, which is a separate entry from the call.
        reduce ($e.message.content[]? | select(.type == "tool_result" and .is_error == true)) as $r (.;
          .out = ( .out | map(if .tool_use_id == $r.tool_use_id then .is_error = true else . end) ))
      else . end ) ) as $p

  | ($p.out | map(del(.tool_use_id))) as $events

  # ---- pass 2: signatures --------------------------------------------------
  | ( $events | map(select(.kind == "tool")) | map(. + {ts_s: (.ts | secs)}) ) as $tools
  | ( $tools | map(select(.tool == "Edit" or .tool == "Write" or .tool == "NotebookEdit")) ) as $edits

  | def with_edits: map( . as $r
      | $r + { intervening_edits:
                 ( [ $edits[] | select(.seq > $r.first_seq and .seq < $r.last_seq) ] | length ) } );

    # THE WINDOW IS A SUB-WINDOW, NOT THE WHOLE EXTENT OF A GROUP. Asking
    # whether the FIRST and LAST occurrence of a group fall within $window can
    # only ever pass a call that occurs nowhere else in the session -- so in a
    # session of any length the filter rejects every candidate, including the
    # ones it exists to catch. Measured on a real transcript before this was
    # written: 6 of 6 tool-call groups and 5 of 5 agent groups discarded, among
    # them a design + design-review pair that spawned 11 and 6 times. The
    # question is instead whether $threshold of them fall inside ANY $window,
    # which is the densest run: slide the window to each member timestamp and
    # keep the fullest. A burst is then found wherever it sits in the session,
    # and the earlier or later occurrences of the same call no longer veto it.
    #
    # Fails closed: a member whose timestamp would not parse is dropped before
    # the slide rather than defaulting to a qualifying value -- the same
    # discipline the `secs` guard above exists for.
    def densest: map(select(.ts_s != null))
      | if length == 0 then null
        else sort_by(.ts_s) as $s
             | [ range(0; $s | length) as $i
                 | [ $s[] | select(.ts_s >= $s[$i].ts_s
                                   and .ts_s <= ($s[$i].ts_s + $window)) ] ]
               | max_by(length)
        end;

    # The reported row describes the BURST; `total_in_session` keeps the full
    # size of the group visible, so a judge can see that the burst is a slice of
    # something larger rather than everything there was.
    def burst_row: . as $all | (densest) as $w
      | if $w == null then empty
        else { count: ($w | length),
               total_in_session: ($all | length),
               turn: $w[0].turn, skill: $w[0].skill,
               first_seq: ($w | map(.seq) | min), last_seq: ($w | map(.seq) | max),
               first: ($w | map(.ts) | sort | first), last: ($w | map(.ts) | sort | last),
               span_seconds: (($w | map(.ts_s) | max) - ($w | map(.ts_s) | min)),
               window_members: $w }
        end;

    ( $tools | map(select(.tool != "Agent")) | group_by([.tool, .fingerprint])
      | map( burst_row
             | select(.count >= $minrep)
             | . + { kind: "repeated-tool-call",
                     tool: .window_members[0].tool,
                     bin: .window_members[0].bin,
                     fingerprint: .window_members[0].fingerprint,
                     errors: (.window_members | map(select(.is_error == true)) | length),
                     threshold: $minrep, filters: ["window", "intervening-edits"] } )
      | with_edits
      | map(select(.intervening_edits == 0))
      | map(del(.window_members)) ) as $repeats

  | ( $tools | map(select(.tool != "Agent" and .is_error == true))
      | group_by([.tool, .fingerprint])
      | map( burst_row
             | select(.count >= retry_min)
             | . + { kind: "error-retry-loop",
                     tool: .window_members[0].tool,
                     bin: .window_members[0].bin,
                     fingerprint: .window_members[0].fingerprint,
                     errors: .count,
                     threshold: retry_min, filters: ["window"] } )
      | map(del(.window_members)) ) as $retries

  | ( $tools | map(select(.tool == "Agent")) | group_by(.bin)
      | map( burst_row
             | select(.count >= $minrep)
             | . + { kind: "repeated-agent-spawn",
                     subagent_type: .window_members[0].bin,
                     threshold: $minrep, filters: ["window"] } )
      | map(del(.window_members)) ) as $spawns

  # ---- turn depth (the GH-13 signal, recalibrated) -------------------------
  # GH-14 proposed cache_read spikes. Measured, cache_read TRENDS -- early turns
  # ran ~100k and late turns ~14M purely because context grows -- so a whole-
  # session median flagged one turn in five. Per-message normalisation flattens
  # it until nothing is an outlier. Message count per turn is what actually
  # separates: median 5, max 75 on the same session. A turn that took 75 model
  # calls is the agent going round and round, which is the thing being looked for.
  | ( reduce $main[] as $e ({turn: 0, seen: {}, rows: []};
        if ($e | is_human_turn) then .turn += 1
        elif $e.type == "assistant" and ($e.message.id != null)
             and ((.seen[$e.message.id] // false) | not)
        then .seen[$e.message.id] = true
           | .rows += [{turn: .turn, cr: ($e.message.usage.cache_read_input_tokens // 0)}]
        else . end ) ).rows as $msgs
  | ( $msgs | group_by(.turn)
            | map({turn: .[0].turn, messages: length,
                   cache_read: (map(.cr) | add // 0)}) ) as $turnrows
  | ( $turnrows | map(.messages) | sort ) as $depths
  | ( if ($depths | length) < 5 then null
      else $depths[ (($depths | length) / 2 | floor) ] end ) as $median_depth
  | ( if $median_depth == null or $median_depth == 0 then []
      else $turnrows
           | map(select(.messages >= ($median_depth * $spike) and .messages >= 10))
           | map({ kind: "turn-depth-spike", turn: .turn, messages: .messages,
                   median_turn_messages: $median_depth,
                   factor: ((.messages / $median_depth) | floor),
                   cache_read: .cache_read,
                   cache_read_per_message: ((.cache_read / .messages) | floor) })
      end ) as $spikes

  # ---- deferral candidates -------------------------------------------------
  # A task that will not converge has a cheap exit: file a ticket and move on.
  # A ticket filed during an ordinary turn is planning and is NOT flagged; one
  # filed inside a turn that already went round and round is the shape worth a
  # second look. The turn-depth threshold is the same one used above, so the two
  # signals cannot disagree about what "struggling" means.
  | ( $spikes | map(.turn) ) as $deep_turns
  | ( $tools
      | map(select((.bin // "") | startswith("gh issue create")))
      | map(select(.turn | IN($deep_turns[])))
      # $tn is bound BEFORE the spike iteration: inside select(...) the input is
      # the spike, so `.turn == .turn` compares the spike against itself, which
      # holds for every spike and silently yields the FIRST one in the session
      # instead of the matching turn.
      | map( .turn as $tn
             | { kind: "deferral-candidate", turn: $tn, skill: .skill, seq: .seq, at: .ts,
                 turn_messages: ( [ $spikes[] | select(.turn == $tn) ] | first | .messages ) })
    ) as $deferrals

  # ---- step regression -----------------------------------------------------
  | ( $tools | map(select(.progress_step != null)) ) as $steps
  | ( if ($steps | length) < 2 then []
      else [ range(1; $steps | length) as $i
             | select($steps[$i].progress_step < $steps[$i-1].progress_step)
             | { kind: "step-regression",
                 from: $steps[$i-1].progress_step, to: $steps[$i].progress_step,
                 at: $steps[$i].ts, turn: $steps[$i].turn, skill: $steps[$i].skill } ]
      end ) as $regressions

  | { session: $session, transcript: $path,
      events_total: ($events | length),
      tool_calls: ($tools | length),
      turns: (($events | map(.turn) | max) // 0),
      unparseable_lines: $bad,
      window_seconds: $window, min_repeats: $minrep, spike_factor: $spike,
      events: $events,
      signatures: ($repeats + $retries + $spawns + $spikes + $deferrals + $regressions),
      unavailable: (
        ( if ($steps | length) < 2
          then [{ kind: "step-regression",
                  reason: "no .progress.md writes in this transcript, so step ordering cannot be checked -- this is NOT a clean result" }]
          else [] end ) +
        ( if ($depths | length) < 5
          then [{ kind: "turn-depth-spike",
                  reason: "fewer than 5 turns with spend; a median over this few turns is not a baseline" }]
          else [] end ) ) }
  ' > "$WORK/report.json" || die "failed to build the report"

if [ "$MODE" = "signatures" ]; then
  if [ "$AS_JSON" = "1" ]; then jq 'del(.events)' "$WORK/report.json"; exit 0; fi
  jq 'del(.events)' "$WORK/report.json"
  exit 0
fi

if [ "$AS_JSON" = "1" ]; then cat "$WORK/report.json"; exit 0; fi

jq -r '
  def pad(w): . + (" " * (if (w - length) > 0 then w - length else 0 end));
  def lpad(w): (" " * (if (w - length) > 0 then w - length else 0 end)) + .;
  def clock: if . == null then "--:--:--" else .[11:19] end;
  "Session: \(.session)   events: \(.events_total)   tool calls: \(.tool_calls)   turns: \(.turns)",
  "",
  "  " + ("seq"|lpad(6)) + "  " + ("time"|pad(10)) + ("turn"|lpad(5)) + "  " + ("skill"|pad(20))
       + ("kind"|pad(12)) + ("tool"|pad(16)) + ("what"|pad(18)) + "fingerprint",
  ( .events[]
    | "  " + ((.seq|tostring)|lpad(6)) + "  " + ((.ts|clock)|pad(10)) + ((.turn|tostring)|lpad(5)) + "  "
      + ((.skill // "-")|pad(20))
      + ((if .is_error == true then "tool_error" else .kind end)|pad(12))
      + ((.tool // "-")|pad(16)) + ((.bin // "-")|pad(18)) + (.fingerprint // "-") )
' "$WORK/report.json"
