#!/usr/bin/env bash
#
# Does the ticket tail grow faster than the work ships?
#
# Usage:
#   backlog-metrics.sh [--repo <owner/repo>] [--json] [--burst-threshold N]
#   backlog-metrics.sh --issues-file <json> --prs-file <json> [--now <iso>] [--json]
#
# Exit: 0 on success, 2 on usage error.
#
# WHAT THIS IS FOR. An agent that cannot make a task converge has a cheap way
# out: file a ticket and move on. Deferring costs less than admitting the thing
# did not work, so the tail grows. That is a real failure mode and it is worth
# counting.
#
# THE CONFOUND, WHICH IS THE WHOLE DIFFICULTY. A growing backlog is ALSO what a
# healthy project start looks like: scope genuinely expands as the work is
# understood. Backlog growth on its own therefore means nothing. Four signals
# separate the two, and this script reports all four rather than one score:
#
#   ratio    tickets opened per PR merged. Sustained above 1, the tail outruns
#            delivery. Below it, the backlog is being worked off.
#   cadence  a BURST (several tickets in one day) is a planning pass -- scope
#            discovery. A DRIP (one at a time, spread out) is what parking work
#            looks like. The drip share is the suspicious half.
#   age      a healthy backlog churns. A median open age that only climbs means
#            tickets are filed and never returned to.
#   volume   opened vs closed over the same window.
#
# WHAT IT DELIBERATELY DOES NOT DO. It does not emit a verdict or a score.
# Deferral is a SHAPE OVER TIME; a single run is a snapshot, and a snapshot
# cannot tell "parking work" from "week one". Every run says so in `notes`.
#
# Tests: scripts/test-backlog-metrics.sh (no network -- fixtures via --*-file)

set -uo pipefail

die() { printf 'backlog-metrics: %s\n' "$1" >&2; exit 2; }

REPO=""; AS_JSON=0; BURST=3; ISSUES_FILE=""; PRS_FILE=""; NOW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)            shift; [ $# -gt 0 ] || die "--repo needs a value"; REPO="$1" ;;
    --json)            AS_JSON=1 ;;
    --burst-threshold) shift; [ $# -gt 0 ] || die "--burst-threshold needs a number"; BURST="$1" ;;
    --issues-file)     shift; [ $# -gt 0 ] || die "--issues-file needs a path"; ISSUES_FILE="$1" ;;
    --prs-file)        shift; [ $# -gt 0 ] || die "--prs-file needs a path"; PRS_FILE="$1" ;;
    --now)             shift; [ $# -gt 0 ] || die "--now needs an ISO timestamp"; NOW="$1" ;;
    -h|--help)         sed -n '2,8p' "$0"; exit 0 ;;
    *)                 die "unknown argument: $1" ;;
  esac
  shift
done
case "$BURST" in ''|*[!0-9]*) die "--burst-threshold must be a whole number, got: $BURST" ;; esac
command -v jq >/dev/null 2>&1 || die "jq is required"

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT INT TERM

if [ -n "$ISSUES_FILE" ] || [ -n "$PRS_FILE" ]; then
  [ -n "$ISSUES_FILE" ] && [ -n "$PRS_FILE" ] || die "--issues-file and --prs-file go together"
  [ -f "$ISSUES_FILE" ] || die "no such file: $ISSUES_FILE"
  [ -f "$PRS_FILE" ]    || die "no such file: $PRS_FILE"
  cp "$ISSUES_FILE" "$WORK/issues.json"; cp "$PRS_FILE" "$WORK/prs.json"
  SOURCE="${ISSUES_FILE}"
else
  command -v gh >/dev/null 2>&1 || die "gh is required (or pass --issues-file/--prs-file)"
  set -- --state all --limit 1000
  if [ -n "$REPO" ]; then set -- --repo "$REPO" "$@"; fi
  gh issue list "$@" --json number,state,createdAt,closedAt > "$WORK/issues.json" \
    || die "gh issue list failed"
  gh pr list "$@" --json number,state > "$WORK/prs.json" \
    || die "gh pr list failed"
  SOURCE="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'current repo')}"
fi
[ -n "$NOW" ] || NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

jq -n \
  --slurpfile issues "$WORK/issues.json" \
  --slurpfile prs "$WORK/prs.json" \
  --arg source "$SOURCE" \
  --arg now "$NOW" \
  --argjson burst "$BURST" '
  ($issues[0] // []) as $iss
  | ($prs[0] // []) as $pr
  | ($now | fromdateiso8601) as $t

  | ($iss | length) as $opened
  | ([ $iss[] | select(.state == "CLOSED") ] | length) as $closed
  | ([ $iss[] | select(.state != "CLOSED") ] ) as $open_now
  | ([ $pr[] | select(.state == "MERGED") ] | length) as $merged

  # Group by CALENDAR DAY of creation. A day at or over the threshold is a
  # planning pass; anything else is a drip, which is the shape deferral takes.
  | ( $iss | group_by(.createdAt[0:10])
           | map({date: .[0].createdAt[0:10], count: length}) ) as $days
  | ( $days | map(select(.count >= $burst)) ) as $bursts
  | ( $bursts | map(.count) | add // 0 ) as $burst_issues
  | ( $opened - $burst_issues ) as $drip_issues

  | ( $open_now | map((($t - (.createdAt | fromdateiso8601)) / 86400) | floor) | sort ) as $ages

  | { source: $source,
      measured_at: $now,
      burst_threshold: $burst,
      issues: { opened: $opened, closed: $closed, open_now: ($open_now | length) },
      prs: { merged: $merged },
      ratio_opened_per_merged:
        ( if $merged == 0 then null
          else (($opened / $merged) * 100 | round) / 100 end ),
      open_age_days:
        { median: (if ($ages | length) == 0 then null else $ages[(($ages | length) / 2 | floor)] end),
          max:    (if ($ages | length) == 0 then null else ($ages | max) end) },
      cadence:
        { bursts: $bursts,
          burst_issues: $burst_issues,
          drip_issues: $drip_issues,
          drip_share: (if $opened == 0 then null
                       else (($drip_issues / $opened) * 100 | round) / 100 end) },
      notes:
        ( [ "A single run is a snapshot; deferral is a shape over time, and one ratio cannot tell parking work from week one of a project." ]
          + ( if $merged == 0
              then [ "Ratio is undefined rather than infinite: there are no merged PRs in this window." ]
              else [] end )
          + ( if $merged > 0 and ($opened / $merged) > 1
              then [ "Tickets are being opened faster than work is shipping (\($opened) opened per \($merged) merged)." ]
              else [] end )
          + ( if $opened > 0 and ($drip_issues / $opened) > 0.5 and $drip_issues >= 3
              then [ "Most tickets arrived one at a time rather than in a planning pass, which is the cadence deferral has." ]
              else [] end ) ) }
  ' > "$WORK/report.json" || die "failed to build the report"

if [ "$AS_JSON" = "1" ]; then cat "$WORK/report.json"; exit 0; fi

jq -r '
  def n: if . == null then "n/a" else tostring end;
  "Backlog: \(.source)   measured \(.measured_at[0:10])",
  "",
  "  issues opened      \(.issues.opened)",
  "  issues closed      \(.issues.closed)",
  "  open now           \(.issues.open_now)",
  "  PRs merged         \(.prs.merged)",
  "",
  "  ratio              \(.ratio_opened_per_merged | n) tickets opened per merged PR",
  "  open age (days)    median \(.open_age_days.median | n), oldest \(.open_age_days.max | n)",
  "  cadence            \(.cadence.burst_issues) in planning bursts, \(.cadence.drip_issues) one at a time (drip share \(.cadence.drip_share | n))",
  ( if (.cadence.bursts | length) > 0
    then "  bursts             " + (.cadence.bursts | map("\(.date) x\(.count)") | join(", "))
    else "  bursts             none at threshold \(.burst_threshold)" end ),
  "",
  ( .notes[] | "  note: " + . )
' "$WORK/report.json"
