#!/usr/bin/env bash
#
# Tests for backlog-metrics.sh — does the ticket tail grow faster than work ships?
# Run from anywhere:  bash scripts/test-backlog-metrics.sh
#
# No network. Every case feeds pre-fetched JSON through --issues-file / --prs-file,
# and pins "now" with --now, so the numbers are reproducible next year.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
BM="${HERE}/backlog-metrics.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3])" ;; esac; }

D=$(mktemp -d)
# issues <file> <spec...>   spec = number:state:createdDate[:closedDate]
issues() {
  local f="$D/$1"; shift; : > "$f.in"
  for s in "$@"; do printf '%s\n' "$s" >> "$f.in"; done
  jq -R -s 'split("\n") | map(select(length>0)) | map(split(":")) |
    map({number:(.[0]|tonumber), state:.[1],
         createdAt:(.[2]+"T00:00:00Z"),
         closedAt:(if (.[3] // "") == "" then null else .[3]+"T00:00:00Z" end)})' "$f.in" > "$f"
  printf '%s' "$f"
}
# prs <file> <count-merged> [count-open]
prs() {
  local f="$D/$1"
  jq -n --argjson m "$2" --argjson o "${3:-0}" \
    '[range($m)|{state:"MERGED"}] + [range($o)|{state:"OPEN"}]' > "$f"
  printf '%s' "$f"
}
run() { bash "$BM" --issues-file "$1" --prs-file "$2" --now "${3:-2026-09-18T00:00:00Z}" --json 2>/dev/null; }

printf '\n== counts come from the data, not from the state field alone ==\n'
I=$(issues i1 "1:CLOSED:2026-09-01:2026-09-05" "2:OPEN:2026-09-02" "3:OPEN:2026-09-02")
P=$(prs p1 4)
out=$(run "$I" "$P")
check "opened"   "$(jq -r '.issues.opened' <<<"$out")"   "3"
check "closed"   "$(jq -r '.issues.closed' <<<"$out")"   "1"
check "open now" "$(jq -r '.issues.open_now' <<<"$out")" "2"
check "merged prs" "$(jq -r '.prs.merged' <<<"$out")"    "4"

printf '\n== the headline number: tickets opened per PR shipped ==\n'
# Sustained above 1 means the tail grows faster than the work ships. Below it,
# the backlog is being worked off.
check "3 issues over 4 merged PRs" "$(jq -r '.ratio_opened_per_merged' <<<"$(run "$I" "$P")")" "0.75"
I2=$(issues i2 "1:OPEN:2026-09-01" "2:OPEN:2026-09-02" "3:OPEN:2026-09-03" "4:OPEN:2026-09-04")
check "4 issues over 2 merged PRs" "$(jq -r '.ratio_opened_per_merged' <<<"$(run "$I2" "$(prs p2 2)")")" "2"

printf '\n== a burst is planning; a drip is deferral ==\n'
# This is the whole point. Backlog growth on its own is ambiguous -- it is also
# what a project start looks like. Five tickets filed in one planning pass is
# scope discovery; five filed one-per-day during implementation is an agent
# parking work it could not converge on.
B=$(issues burst "1:OPEN:2026-09-14" "2:OPEN:2026-09-14" "3:OPEN:2026-09-14" "4:OPEN:2026-09-14" "5:OPEN:2026-09-14")
out=$(run "$B" "$(prs pb 3)")
check "one day, five tickets -> one burst" "$(jq -r '.cadence.bursts|length' <<<"$out")" "1"
check "all five are burst issues"          "$(jq -r '.cadence.burst_issues' <<<"$out")" "5"
check "none are drip"                      "$(jq -r '.cadence.drip_issues' <<<"$out")" "0"
check "drip share is zero"                 "$(jq -r '.cadence.drip_share' <<<"$out")" "0"

R=$(issues drip "1:OPEN:2026-09-01" "2:OPEN:2026-09-03" "3:OPEN:2026-09-05" "4:OPEN:2026-09-07")
out=$(run "$R" "$(prs pd 3)")
check "one at a time -> no burst"  "$(jq -r '.cadence.bursts|length' <<<"$out")" "0"
check "all of them are drip"       "$(jq -r '.cadence.drip_issues' <<<"$out")" "4"
check "drip share is total"        "$(jq -r '.cadence.drip_share' <<<"$out")" "1"

printf '\n== the burst threshold is tunable and reported ==\n'
out=$(run "$B" "$(prs pb2 3)")
check "default burst threshold is reported" "$(jq -r '.burst_threshold' <<<"$out")" "3"
out=$(bash "$BM" --issues-file "$B" --prs-file "$(prs pb3 3)" --now 2026-09-18T00:00:00Z --burst-threshold 6 --json 2>/dev/null)
check "raising it past the day count dissolves the burst" "$(jq -r '.cadence.bursts|length' <<<"$out")" "0"
check "and the issues become drip"                        "$(jq -r '.cadence.drip_issues' <<<"$out")" "5"

printf '\n== age of the open tail ==\n'
A=$(issues age "1:OPEN:2026-09-08" "2:OPEN:2026-09-13" "3:OPEN:2026-09-16" "4:CLOSED:2026-01-01:2026-01-02")
out=$(run "$A" "$(prs pa 1)")
check "median age of OPEN issues only" "$(jq -r '.open_age_days.median' <<<"$out")" "5"
check "oldest open issue"              "$(jq -r '.open_age_days.max' <<<"$out")" "10"
check "a closed issue does not age"    "$(jq -r '.issues.open_now' <<<"$out")" "3"

printf '\n== it flags, and says why, rather than scoring ==\n'
out=$(run "$I2" "$(prs pf 2)")
has "a ratio above 1 is called out" "$(jq -r '.notes|join(" ")' <<<"$out")" "faster than"
out=$(run "$I" "$P")
check "a healthy ratio raises nothing" "$(jq -r '[.notes[]|select(test("faster than"))]|length' <<<"$out")" "0"

printf '\n== one measurement is not a trend, and it says so ==\n'
# The number this script prints is a snapshot. Deferral is a SHAPE OVER TIME --
# a single ratio cannot distinguish "parking work" from "week one of a project".
has "every run carries the trend caveat" "$(run "$I" "$P" | jq -r '.notes|join(" ")')" "snapshot"

printf '\n== degenerate input does not divide by zero ==\n'
out=$(run "$(issues none)" "$(prs pz 0)")
check "no issues, no PRs -> ratio null" "$(jq -r '.ratio_opened_per_merged' <<<"$out")" "null"
check "and no crash"                    "$(jq -r '.issues.opened' <<<"$out")" "0"
out=$(run "$I" "$(prs pz2 0)")
check "issues but zero merged PRs -> null, not infinity" "$(jq -r '.ratio_opened_per_merged' <<<"$out")" "null"
has  "and that is explained"  "$(jq -r '.notes|join(" ")' <<<"$out")" "no merged"

printf '\n== usage ==\n'
bash "$BM" --issues-file /nonexistent --prs-file "$P" >/dev/null 2>&1; check "missing file -> 2" "$?" "2"
bash "$BM" --burst-threshold x --issues-file "$I" --prs-file "$P" >/dev/null 2>&1; check "non-numeric threshold -> 2" "$?" "2"
bash "$BM" --issues-file "$I" --prs-file "$P" --now 2026-09-18T00:00:00Z >/dev/null 2>&1; check "human output works" "$?" "0"
has "human output names the ratio" "$(bash "$BM" --issues-file "$I" --prs-file "$P" --now 2026-09-18T00:00:00Z 2>&1)" "per merged PR"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
