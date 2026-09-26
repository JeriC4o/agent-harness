#!/usr/bin/env bash
#
# Read the loop ledger. GH-64.
#
#   scripts/loop-metrics.sh [<ledger.jsonl> | --all] [--json]
#
# The ledger written by hooks/lib/loop-index.sh and hooks/lib/loop-verdict.sh was
# write-only: nothing read it, so the effectiveness question it exists to answer
# could not be asked. "Outcome is derivable from the observations that follow a
# verdict" was a property of the FORMAT that no code exercised, and derivable is
# not derived. This derives it.
#
# THE OUTCOME IS NEVER STORED, AND THAT IS DELIBERATE. A hook cannot observe its
# own effect -- `ask` hands the decision to the permission system and hears
# nothing back -- so anything it wrote about the result would be a guess. What
# follows the verdict is not a guess:
#
#   the same fp again on the same tool    -> went_ahead   (the call was made)
#   nothing more with that fp             -> abandoned    (it was dropped)
#   a different fp, same tool             -> reformulated (it was changed)
#
# ABANDONMENT IS THE HEADLINE. It is the closest available stand-in for "tokens
# not spent"; everything else here is indirect. Read it as a rate, never as a
# total: a session with two verdicts and one abandonment says almost nothing, and
# the script prints the denominator next to it for that reason.
#
# NOT COMPUTED HERE, ON PURPOSE:
#   - token cost. scripts/trace-tokens.sh already derives per-turn spend; a
#     verdict carries ts and transcript to join on. Duplicating that arithmetic
#     would give a second number that drifts from the first.
#   - hook latency. The ledger records that a call happened, never how long the
#     hook took. Overhead has to be measured directly, not read -- a detector
#     justified by saving tokens should not quietly cost time on every call, but
#     this file cannot see that and does not pretend to.
set -uo pipefail

die() { printf 'loop-metrics: %s\n' "$1" >&2; exit 2; }

LEDGER=""; ALL=0; AS_JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)  ALL=1 ;;
    --json) AS_JSON=1 ;;
    -h|--help)
      printf 'usage: loop-metrics.sh [<ledger.jsonl> | --all] [--json]\n'; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *)  [ -z "$LEDGER" ] || die "more than one ledger given"; LEDGER="$1" ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || die "jq is required"

DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"
if [ "$ALL" -eq 1 ]; then
  [ -z "$LEDGER" ] || die "--all takes no ledger argument"
  [ -d "$DIR" ] || die "no ledger directory at $DIR"
  set -- "$DIR"/*.jsonl
  [ -e "$1" ] || die "no ledgers in $DIR"
  FILES=("$@")
elif [ -n "$LEDGER" ]; then
  [ -f "$LEDGER" ] || die "no such ledger: $LEDGER"
  FILES=("$LEDGER")
else
  die "give a ledger path or --all"
fi

# One jq pass per ledger, emitting a per-session object; the roll-up is a second
# pass over those. Sessions stay separate in the output because a rate pooled
# across sessions hides the one session that produced every finding.
per_session() {
  jq -s --arg sid "$(basename "${1%.jsonl}")" '
    # Ignore any line whose kind this build does not know: the two classes are
    # "call" and "verdict", and a future third must not silently join a count.
    . as $all
    # POSITION, NOT TIME, and this is load-bearing rather than pedantic. A verdict
    # is appended immediately after the call that triggered it, so at one-second
    # resolution the two share a ts -- filtering the "following" calls on
    # `ts >= verdict.ts` readmits the triggering call and every verdict then reads
    # as went_ahead, whatever actually happened. Order is what the append
    # guarantees; the clock is not.
    | [ range(0; ($all | length)) | { i: ., e: $all[.] } ] as $idx
    | ( [ $idx[] | select(.e.kind == "call")    | .e ] ) as $calls
    | ( [ $idx[] | select(.e.kind == "verdict") ] )      as $verdicts
    | ( [ range(0; ($verdicts | length)) as $n
          | $verdicts[$n] as $vi
          | $vi.e as $v
          | ( [ $idx[] | select(.i > $vi.i and .e.kind == "call" and .e.tool == $v.tool) | .e ] ) as $after
          | { tier: $v.tier, signal: $v.signal, tool: $v.tool,
              verdict: ($v.verdict // "-"),
              outcome:
                ( if ($v.fp // null) == null then "n/a"        # tier 2 keys on the tool, not one fp
                  elif ($after | any(.fp == $v.fp)) then "went_ahead"
                  elif ($after | length) > 0 then "reformulated"
                  else "abandoned" end ),
              settings: { window: $v.window, threshold: ($v.threshold // null),
                          min_calls: ($v.min_calls // null),
                          min_distinct: ($v.min_distinct // null) } } ] ) as $rows
    # A session belongs to ONE project, so the project is read off the session
    # rather than stored on every line twice. cwd is exact; the transcript path
    # is the fallback for lines written before cwd was recorded, and it is only a
    # fallback because its directory encodes the path by replacing "/" with "-",
    # which a directory name containing a hyphen makes ambiguous with no sign.
    | ( [ $calls[] | .cwd? // empty | select(. != "-") ] | first ) as $cwd
    | ( [ $calls[] | .transcript? // empty ] | first ) as $tp0
    | { session: $sid,
        project: ( $cwd
                   // ( $tp0 | if . == null then "unknown"
                        else (split("/") | if length > 1 then .[-2] else "unknown" end) end ) ),
        project_exact: ($cwd != null),
        calls: ($calls | length),
        tools: ($calls | map(.tool) | unique | length),
        agents: ($calls | map(.agent_id) | unique | length),
        verdicts: ($verdicts | length),
        by_tier:   ($verdicts | map(.e) | group_by(.tier)   | map({ (.[0].tier   | tostring): length }) | add // {}),
        by_signal: ($verdicts | map(.e) | group_by(.signal) | map({ (.[0].signal | tostring): length }) | add // {}),
        turns: ([ $all[] | select(.kind == "turn") ] | length),
        # Tier 2 is the COARSE structural gate: how often it fires is the number
        # that decides whether the judging stage is worth paying for. Tier 3 is
        # the verdict of the model on what tier 2 flagged, off by default -- so
        # `judged` separates "the gate fired and nobody asked" from "the gate
        # fired and the model was consulted" -- different observations.
        # A tier-2 line is a coarse firing only when its signal SAYS SO. Before
        # the gate was replaced, tier 2 carried the model verdict itself under
        # signal "semantic-repeat"; counting those as coarse firings would inflate
        # this number with records from a detector that no longer exists. They are
        # not discarded either -- they are real model verdicts that were really
        # paid for, so they are counted below where they belong.
        tier2: { fired:  ([ $verdicts[] | .e | select(.tier == 2 and .signal == "coarse-repeat") ] | length),
                 judged: ([ $verdicts[] | .e | select(.tier == 2 and .signal == "coarse-repeat" and .judged == true) ] | length),
                 top_bin: ( [ $verdicts[] | .e | select(.tier == 2 and .signal == "coarse-repeat") | .bin // empty ]
                            | if length == 0 then null
                              else (group_by(.) | max_by(length) | .[0]) end ) },
        # A high progress share means the coarse gate is still loose; a zero share
        # means the model only ever agrees and adds nothing. Both extremes argue
        # for dropping a stage rather than tuning one.
        # Tier 3, PLUS the legacy tier-2 model verdicts. Those cost real model
        # calls and carry a real answer, so they belong in this rate rather than
        # being thrown away for having been written under an older schema.
        tier3: { asked:    ([ $verdicts[] | .e | select(.tier == 3 or (.tier == 2 and .signal == "semantic-repeat")) ] | length),
                 circling: ([ $verdicts[] | .e | select(.tier == 3 or (.tier == 2 and .signal == "semantic-repeat")) | select(.verdict == "circling") ] | length),
                 progress: ([ $verdicts[] | .e | select(.tier == 3 or (.tier == 2 and .signal == "semantic-repeat")) | select(.verdict == "progress") ] | length) },
        outcomes: ($rows | map(.outcome) | group_by(.) | map({ (.[0]): length }) | add // {}),
        rows: $rows }
  ' "$1"
}

tmp=$(mktemp) || die "cannot create a temp file"
trap 'rm -f "$tmp"' EXIT
for f in "${FILES[@]}"; do
  [ -s "$f" ] || continue
  per_session "$f" >> "$tmp" || die "could not read $f"
done
[ -s "$tmp" ] || die "every ledger was empty"

# PROJECTS ARE NEVER POOLED. A rate over a mixed corpus answers no question: the
# thresholds that fit one codebase say nothing about another, and a single busy
# project would dominate every figure while looking like a general result. The
# roll-up therefore groups first and totals only inside a group.
report=$(jq -s '
  ( group_by(.project) | map({ project: .[0].project,
                               exact: .[0].project_exact,
                               sessions: length,
                               calls:    (map(.calls)    | add // 0),
                               turns:    (map(.turns)    | add // 0),
                               verdicts: (map(.verdicts) | add // 0),
                               tier2: { fired:  (map(.tier2.fired)  | add // 0),
                                        judged: (map(.tier2.judged) | add // 0),
                                        top_bin: ( [ .[] | .tier2.top_bin | select(. != null) ]
                                                   | if length == 0 then null
                                                     else (group_by(.) | max_by(length) | .[0]) end ) },
                               tier3: { asked:    (map(.tier3.asked)    | add // 0),
                                        circling: (map(.tier3.circling) | add // 0),
                                        progress: (map(.tier3.progress) | add // 0) },
                               outcomes: ( map(.outcomes) | map(to_entries) | add // []
                                           | group_by(.key)
                                           | map({ (.[0].key): (map(.value) | add) }) | add // {} ) })
  ) as $projects
  | { projects:
        # A rate needs its denominator beside it or it invites being read as a
        # result -- and it belongs to ONE project, never to a mixed corpus.
        ( $projects | map( . + { abandonment:
            ( (.outcomes.abandoned // 0) as $a
              | ( [ .outcomes | to_entries[] | select(.key != "n/a") | .value ] | add // 0 ) as $d
              | if $d == 0 then null else { abandoned: $a, of: $d } end ) } ) ),
      sessions: .,
      # Totals are an INVENTORY, deliberately: how much was seen, never a rate
      # over it. Outcome shares, tier-2 agreement and abandonment live per
      # project above, because pooling them would let one busy codebase set a
      # figure that reads as general.
      totals: { sessions: length,
                projects: ($projects | length),
                calls:    (map(.calls)    | add // 0),
                verdicts: (map(.verdicts) | add // 0) } }
' "$tmp") || die "could not roll up"

if [ "$AS_JSON" -eq 1 ]; then
  printf '%s\n' "$report"
  exit 0
fi

printf '%s' "$report" | jq -r '
  . as $r
  | "loop ledger -- \($r.totals.projects) project(s), \($r.totals.sessions) session(s), " +
    "\($r.totals.calls) call(s), \($r.totals.verdicts) verdict(s)",
  "",
  ( $r.projects[]
    | "\(.project)\(if .exact then "" else "   [recovered from the transcript path; may be wrong where a directory name contains a hyphen]" end)",
      "  \(.sessions) session(s), \(.calls) call(s), \(.verdicts) verdict(s)",
      ( if .verdicts == 0 then
          "  nothing fired -- a result, not an empty report: \(.calls) calls passed without a repeat"
        else
          ( "  outcome of each verdict, from the calls that follow it:",
            ( .outcomes | to_entries[] | "    \(.key): \(.value)" ),
            ( if .abandonment == null then "  abandonment: not computable here -- no verdict carried a derivable outcome"
              else "  abandonment: \(.abandonment.abandoned) of \(.abandonment.of) -- the nearest stand-in for calls not made"
              end ),
            ( if .turns == 0 then
                "  coarse gate: no turn markers in this ledger -- it was written before the turn-scoped gate existed, so the counts below are all there is"
              else
                "  coarse gate: fired \(.tier2.fired) time(s) over \(.turns) turn(s)\(if .tier2.top_bin then ", most often on \(.tier2.top_bin)" else "" end)"
              end ),
            ( if .turns > 0 and .tier2.fired >= .turns then "    it fires on every turn -- that is the shape of a gate that does not discriminate, not of a session that loops"
              else "" end ),
            "  model: asked \(.tier3.asked), circling \(.tier3.circling), progress \(.tier3.progress)",
            ( if .tier3.asked == 0 and .tier2.judged == 0 then "    the judging stage is switched off; the coarse counts above are the calibration"
              elif .tier3.asked == 0 then "    it was enabled but never reached a verdict"
              elif .tier3.progress == 0 then "    it agreed every time -- check whether its verdict adds anything"
              elif .tier3.circling == 0 then "    it declined every time -- the coarse gate is still too loose"
              else "    both answers occur, which is what makes the rate meaningful"
              end ) )
        end ),
      "" ),
  "per session:",
  ( $r.sessions[] | "  [\(.project)] \(.session): \(.calls) calls, \(.tools) tool(s), \(.agents) agent(s), \(.verdicts) verdict(s)" ),
  "",
  "Rates are per project and are never pooled: thresholds that fit one codebase say nothing about another.",
  "One run is not a trend. Thresholds are recorded per verdict; compare them before comparing rates."
'
