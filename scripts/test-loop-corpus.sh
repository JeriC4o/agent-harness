#!/usr/bin/env bash
#
# The frozen-corpus replay gate for the tier-1 loop detector (GH-86 / GH-88).
# Run from anywhere:
#   bash scripts/test-loop-corpus.sh
#
# This is the only gate in the repo that measures the detector against rows the
# FIELD wrote rather than rows a test authored. It replays every call row of a
# real recorded session at a range of window widths, under the shipped rule and
# under the frozen pre-fix one, and compares both against committed expectations.
#
# WHY IT DRIVES THE AWK AND NOT THE HOOK. The ledger stores a djb2 hash of the
# tool arguments and never the arguments, so no synthetic payload can reproduce
# a recorded `fp`: a replay of real rows cannot go in through loop-index.sh.
# hooks/lib/loop-window.awk is therefore shared rather than copied -- one file
# is what stops this gate and the hook from measuring two different rules.
#
# The chunk-doubling loop in `fixed_verdict` is the SHELL half of the detector
# (loop-index.sh), replicated here for the same reason and for no other. It is
# controlled: the last section proves it agrees with a whole-prefix read, which
# needs no loop at all.
#
# Runtime is minutes, not seconds -- 1728 call rows replayed at 18 window
# width-passes across two legs: `replay` runs three times (frozen/real,
# fixed/real, fixed/repaired) over six widths each. There is deliberately no flag to narrow it: a gate
# that can quietly shrink its own input set is the failure this ticket is about.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)
LIB="${HERE}/hooks/lib"
AWK_LIVE="${LIB}/loop-window.awk"
WRAP="${LIB}/loop-window-prefix.sh"
FXDIR="${HERE}/ai-docs/fixtures/loop-corpus"
REAL="${FXDIR}/44f957de.real.jsonl"
MAP="${FXDIR}/44f957de.agents.tsv"
BASE="${FXDIR}/44f957de.baseline.json"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
yn()   { if [ "$1" -eq 0 ]; then printf no; else printf yes; fi; }

command -v jq >/dev/null 2>&1 || { printf 'jq is required\n' >&2; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PRE="${WORK}/prefix.jsonl"
IDX="${WORK}/callidx.tsv"
REPAIRED="${WORK}/44f957de.repaired.jsonl"
TAB=$'\t'

# Larger than any ledger this gate will see, which is what makes `unbounded`
# expressible as a number here: `want_calls` beyond the call count disables the
# window, and `chunk` beyond the line count means NR < chunk, so RETRY cannot
# fire and the whole prefix is read.
BIG=10000000

printf '\n== AC18: no fixture names an author home directory ==\n'
# FIRST, before anything reads the rows. Scoped to the fixture directory and not
# to the repo: README.md already carries this repo's own absolute path in a
# --plugin-dir example, so a repo-wide grep is a guaranteed red that says nothing
# about the fixtures. The scope covers the mapping file's provenance header as
# well as the rows -- that header documents the scrub, and a literal path in it
# would be the needle planted by its own documentation.
for needle in '/Users/' '-Users-'; do
  n=$(grep -rlF -- "$needle" "$FXDIR" | grep -c .)
  check "no fixture carries [$needle]" "$n" "0"
done
n=$(grep -rlF -- "$HOME" "$FXDIR" | grep -c .)
check "nor this machine's \$HOME" "$n" "0"
# The scrub needed TWO spellings: the transcript directory encodes the project
# path with "/" replaced by "-", so a slash-only scrub leaves the username in
# every row. Both forms are asserted above; this one proves the rows that
# CARRIED them are still there and were rewritten rather than dropped.
check "and the rewritten form is present, so the rows were scrubbed not deleted" \
      "$(grep -c '"cwd":"/home/u/projects/agent-harness"' "$REAL")" "1728"
check "  in the dash spelling too" \
      "$(grep -c -- '-home-u-projects-agent-harness' "$REAL")" "1728"

printf '\n== the fixtures are present, compact, and the baseline belongs to THIS one ==\n'
for f in "$REAL" "$MAP" "$BASE"; do
  check "$(basename "$f") is present and non-empty" "$( [ -s "$f" ] && echo yes || echo no )" "yes"
done
check "the detector is readable"      "$( [ -r "$AWK_LIVE" ] && echo yes || echo no )" "yes"
check "the frozen control is executable, since this gate invokes it by path" \
      "$( [ -x "$WRAP" ] && echo yes || echo no )" "yes"
# § A10. The detector's regexes are whitespace-sensitive -- `"kind":"call"`, no
# space -- so a reformatted fixture matches NOTHING and every assertion that
# expects silence passes while the gate measures zero.
CALLS=$(grep -c '"kind":"call"' "$REAL")
if [ "$CALLS" -lt 1 ]; then
  bad "the real leg yields NO parsed kind:\"call\" row"
  printf '\nABORT: %s is not compact JSON; every silence this gate asserts would be vacuous\n' "$REAL"
  exit 1
fi
ok "the real leg yields $CALLS parsed call rows"
check "the row inventory is the one the baseline was measured against" \
      "$(printf '%s/%s/%s/%s/%s' "$(wc -l < "$REAL" | tr -d ' ')" "$CALLS" \
         "$(grep -c '"kind":"result"' "$REAL")" "$(grep -c '"kind":"turn"' "$REAL")" \
         "$(grep -c '"kind":"verdict"' "$REAL")")" \
      "$(jq -r '._fixture_rows | "\(.total)/\(.call)/\(.result)/\(.turn)/\(.verdict)"' "$BASE")"
# The sha is what makes AC10 a diff rather than a coincidence: a regenerated
# fixture fails HERE, naming the cause, instead of further down as a changed
# firing count that reads like a detector regression.
check "the committed baseline names this exact fixture" \
      "$(shasum -a 256 "$REAL" | awk '{print $1}')" \
      "$(jq -r '._fixture_sha256' "$BASE")"

# ---------------------------------------------------------------------------
# The replay driver.
# ---------------------------------------------------------------------------
call_index() { # $1 ledger -> line, fp, tool, agent_id for every call row
  awk '/"kind":"call"/ {
         fp=""; tool=""; ag=""
         if (match($0, /"fp":"[^"]*"/))       fp   = substr($0, RSTART+6,  RLENGTH-7)
         if (match($0, /"tool":"[^"]*"/))     tool = substr($0, RSTART+8,  RLENGTH-9)
         if (match($0, /"agent_id":"[^"]*"/)) ag   = substr($0, RSTART+12, RLENGTH-13)
         printf "%d\t%s\t%s\t%s\n", NR, fp, tool, ag
       }' "$1"
}

# loop-index.sh's own read, transposed: size a chunk in LINES as a performance
# hint, let the awk bound the window in CALLS, and widen on RETRY until tail
# runs out of file.
fixed_verdict() { # $1 prefix file, $2 K in calls or 'unbounded', $3 fp, $4 tool, $5 cur
  local wc chunk v
  if [ "$2" = unbounded ]; then wc="$BIG"; chunk="$BIG"; else wc="$2"; chunk=$(( $2 * 3 )); fi
  while :; do
    v=$(tail -n "$chunk" "$1" | awk -v want_fp="$3" -v want_tool="$4" -v thr=3 -v retry=2 \
          -v cur="$5" -v want_calls="$wc" -v chunk="$chunk" -f "$AWK_LIVE" 2>/dev/null)
    [ "$v" = RETRY ] || break
    chunk=$(( chunk * 2 ))
  done
  printf '%s' "$v"
}

# The same question with no chunking at all: the whole prefix, window disabled by
# a want_calls beyond the call count. Used only as the control on fixed_verdict.
whole_prefix_verdict() { # $1 prefix file, $2 K in calls or 'unbounded', $3 fp, $4 tool, $5 cur
  local wc
  if [ "$2" = unbounded ]; then wc="$BIG"; else wc="$2"; fi
  awk -v want_fp="$3" -v want_tool="$4" -v thr=3 -v retry=2 -v cur="$5" \
      -v want_calls="$wc" -v chunk="$BIG" -f "$AWK_LIVE" < "$1" 2>/dev/null
}

# One pass over the leg's call rows, every width judged against the same prefix.
# Emits one row per FIRING: width, call ordinal, verdict line.
replay() { # $1 leg, $2 fixed|frozen, $3 output tsv, then the widths
  local leg="$1" rule="$2" out="$3"
  shift 3
  local ln fp tool ag w v ord=0
  : > "$out"
  call_index "$leg" > "$IDX"
  while IFS="$TAB" read -r ln fp tool ag; do
    ord=$((ord+1))
    [ "$ln" -gt 1 ] || continue
    head -n $((ln-1)) "$leg" > "$PRE"
    for w in "$@"; do
      if [ "$rule" = frozen ]; then
        v=$("$WRAP" "$w" "$PRE" "$fp" "$tool" 3 2 "$ag")
      else
        v=$(fixed_verdict "$PRE" "$w" "$fp" "$tool" "$ag")
      fi
      if [ -n "$v" ]; then printf '%s\t%s\t%s\n' "$w" "$ord" "$v" >> "$out"; fi
    done
  done < "$IDX"
}

# grep -c reports a property of the INPUT, not the health of the run: a
# legitimate zero exits non-zero. The value is captured and compared; nothing
# chains on the status.
fired_at() { grep -c "^$2${TAB}" "$1"; }
# The firing indicators across a width list, left to right, as a string -- "10"
# anywhere in it is a wider window finding LESS.
counts_at() { local out="$1" w acc=""; shift; for w in "$@"; do acc="${acc}$(fired_at "$out" "$w") "; done; printf '%s' "$acc"; }

FIXED_W="20 26 40 100 343 unbounded"
FROZEN_W="20 40 100 759 760 unbounded"

printf '\n== CONTROL OF THE CONTROL: the frozen pair still reproduces the field measurement ==\n'
# Everything the pre-fix legs claim rests on this pair being the rule that
# actually shipped, so it is checked before it is used. K is in LINES, which is
# the half of the control that lives in the wrapper: fed CALLS the same awk
# gives 2/3/3 and this check fails outright, which is the point of it.
printf '  (replaying %s call rows at %s line-widths, this takes a minute)\n' "$CALLS" "$(printf '%s' "$FROZEN_W" | wc -w | tr -d ' ')"
FROZEN_OUT="${WORK}/frozen.tsv"
# shellcheck disable=SC2086
replay "$REAL" frozen "$FROZEN_OUT" $FROZEN_W
check "K =  20 LINES -> 0 firings" "$(fired_at "$FROZEN_OUT" 20)"  "0"
check "K =  40 LINES -> 2 firings" "$(fired_at "$FROZEN_OUT" 40)"  "2"
check "K = 100 LINES -> 3 firings" "$(fired_at "$FROZEN_OUT" 100)" "3"
check "unbounded -> 0 firings, the non-monotonicity that produced this ticket" \
      "$(fired_at "$FROZEN_OUT" unbounded)" "0"
# THREE fields and never four. The frozen pair predates the counted span, so a
# fourth field here means someone updated the control -- which the freeze
# forbids, and which would silently destroy every leg built on it.
check "every frozen verdict carries three fields, which is itself the freeze check" \
      "$(awk -F"$TAB" '{print split($3, a, " ")}' "$FROZEN_OUT" | sort -u | tr '\n' ',')" "3,"

printf '\n== AC9: the validation leg reproduces what the field recorded ==\n'
# GOVERNS THE PRE-FIX RULES ONLY. "0 firings at the shipped window" is what the
# broken detector did, not a cap on the fixed one -- the fixed rule is ALLOWED
# to find more here, and AC10 below is where its reach is recorded.
check "under the pre-fix rules at the shipped window, the real session fired nothing" \
      "$(fired_at "$FROZEN_OUT" 20)" "0"
check "  and the leg is not empty for want of a working replay -- 100 lines finds three" \
      "$(fired_at "$FROZEN_OUT" 100)" "3"

printf '\n== AC3 (corpus half): the pre-fix rule breaks past K = 760 LINES ==\n'
# THE SWEEP RANGE IS PART OF THE ASSERTION. Confined to small K the pre-fix rule
# scores zero violations -- measured over K = 1..80 -- so a narrow sweep is
# satisfied by the broken rule and proves nothing. 760 is the true first break,
# measured at step 1; the 761 that appeared in an earlier draft was an artefact
# of a step-10 sweep.
check "759 LINES still finds three" "$(fired_at "$FROZEN_OUT" 759)" "3"
check "760 LINES finds two -- a wider window finding LESS" "$(fired_at "$FROZEN_OUT" 760)" "2"
FROZEN_SERIES=$(counts_at "$FROZEN_OUT" $FROZEN_W)
ok "pre-fix firings across $FROZEN_W: $FROZEN_SERIES"
check "POSITIVE CONTROL: the pre-fix series is NOT monotonic, so this sweep discriminates" \
      "$(printf '%s' "$FROZEN_SERIES" | awk '{d=0; for(i=2;i<=NF;i++) if ($i+0 < $(i-1)+0) d=1; print d}')" "1"

printf '\n== AC10: the fixed rule against the committed baseline ==\n'
printf '  (replaying %s call rows at %s call-widths)\n' "$CALLS" "$(printf '%s' "$FIXED_W" | wc -w | tr -d ' ')"
FIXED_OUT="${WORK}/fixed.tsv"
# shellcheck disable=SC2086
replay "$REAL" fixed "$FIXED_OUT" $FIXED_W
for w in $FIXED_W; do
  check "K = $w calls" "$(fired_at "$FIXED_OUT" "$w")" "$(jq -r --arg w "$w" '.firings[$w]' "$BASE")"
done
check "the baseline names every width this gate sweeps, and no others" \
      "$(jq -r '.firings | keys_unsorted | join(" ")' "$BASE")" "$FIXED_W"

printf '\n== AC3 (corpus half): the fixed rule is non-decreasing over the same leg ==\n'
FIXED_SERIES=$(counts_at "$FIXED_OUT" $FIXED_W)
ok "fixed firings across $FIXED_W: $FIXED_SERIES"
check "no width finds less than a narrower one" \
      "$(printf '%s' "$FIXED_SERIES" | awk '{d=0; for(i=2;i<=NF;i++) if ($i+0 < $(i-1)+0) d=1; print d}')" "0"
# 343 is where the HYBRID feed breaks -- the frozen awk fed calls instead of
# lines. The fixed rule is swept through it deliberately: a repair that merely
# moved the break rather than removing it would show here.
check "including 343, where the call-fed hybrid breaks" \
      "$(fired_at "$FIXED_OUT" 343)" "$(fired_at "$FIXED_OUT" 100)"

printf '\n== the repaired leg is DERIVED from the committed inputs, not committed ==\n'
# A committed second copy would assert that the derivation was once performed.
# A derivation the gate performs every run is the derivation under test.
awk -F"$TAB" '
  NR==FNR { if ($0 !~ /^#/ && NF == 2) map[$1] = $2; next }
  /"kind":"call"/ {
    for (id in map)
      if (index($0, "\"tool_use_id\":\"" id "\"")) {
        sub(/"agent_id":"main"/, "\"agent_id\":\"" map[id] "\"")
        break
      }
  }
  { print }
' "$MAP" "$REAL" > "$REPAIRED"
check "the mapping carries five pairs" \
      "$(awk -F"$TAB" '$0 !~ /^#/ && NF == 2' "$MAP" | grep -c .)" "5"
check "the repaired leg has the same line count as the real one" \
      "$(wc -l < "$REPAIRED" | tr -d ' ')" "$(wc -l < "$REAL" | tr -d ' ')"
check "exactly five rows differ, so only agent_id moved" \
      "$(diff "$REAL" "$REPAIRED" | grep -c '^>')" "5"
check "  and they carry five DISTINCT agents" \
      "$(jq -rs '[.[] | select(.kind=="call" and .agent_id != "main") | .agent_id] | unique | length' < "$REPAIRED")" "5"
check "the real leg records all of them as main, which is the collapse being repaired" \
      "$(jq -rs '[.[] | select(.kind=="call" and .agent_id != "main")] | length' < "$REAL")" "0"
check "the stored transcript pointers are untouched" \
      "$(diff "$REAL" "$REPAIRED" | grep -c 'subagents/agent-')" "0"

printf '\n== AC11: the repaired leg classifies the cluster as fan-out, at BOTH windows ==\n'
printf '  (replaying %s call rows at %s call-widths)\n' "$CALLS" "$(printf '%s' "$FIXED_W" | wc -w | tr -d ' ')"
REP_OUT="${WORK}/repaired.tsv"
# shellcheck disable=SC2086
replay "$REPAIRED" fixed "$REP_OUT" $FIXED_W
# K = 20 is the setting the branch SHIPS with. The cluster spans 26 calls, so
# na = 5 is unreachable there and pinning only K = 40 would leave the shipped
# default untested; the pair also shows the count tracking the window rather
# than a fixture constant, which one assertion cannot distinguish from a
# hard-coded 5.
check "at the shipped K = 20 there are two fanout firings" \
      "$(awk -F"$TAB" '$1=="20" && $3 ~ /^fanout /' "$REP_OUT" | grep -c .)" "2"
check "  each naming three agents" \
      "$(awk -F"$TAB" '$1=="20" {split($3,a," "); print a[3]}' "$REP_OUT" | sort -u | tr '\n' ',')" "3,"
check "at K = 40 there are three firings" "$(fired_at "$REP_OUT" 40)" "3"
check "  and the last of them names five agents" \
      "$(awk -F"$TAB" '$1=="40" && $2=="1471" {split($3,a," "); print a[3]}' "$REP_OUT")" "5"
check "  which is the five-subagent cluster, classified as fan-out" \
      "$(awk -F"$TAB" '$1=="40" && $2=="1471" {split($3,a," "); print a[1]}' "$REP_OUT")" "fanout"
check "no firing on this leg is a plain loop" \
      "$(awk -F"$TAB" '$3 ~ /^loop /' "$REP_OUT" | grep -c .)" "0"

printf '\n== AC12: the same rows, the two legs, the two findings ==\n'
# The pre-/post-4c1cd0a distinction as a tested property: a change that silently
# reintroduces the collapse flips this pair rather than a field report.
for ord in 1458 1470 1471; do
  check "ordinal $ord is loop on the real leg" \
        "$(awk -F"$TAB" -v o="$ord" '$1=="40" && $2==o {split($3,a," "); print a[1]}' "$FIXED_OUT")" "loop"
  check "  and fanout on the repaired one" \
        "$(awk -F"$TAB" -v o="$ord" '$1=="40" && $2==o {split($3,a," "); print a[1]}' "$REP_OUT")" "fanout"
done
check "the real leg sees one agent throughout" \
      "$(awk -F"$TAB" '$1=="40" {split($3,a," "); print a[3]}' "$FIXED_OUT" | sort -u | tr '\n' ',')" "1,"
# The repair changes the ARM and never whether a row fires, so the two legs must
# agree width for width. A difference here means the derivation moved something
# it had no business moving.
check "and the repair moved no firing COUNT at any width" \
      "$(counts_at "$REP_OUT" $FIXED_W)" "$(counts_at "$FIXED_OUT" $FIXED_W)"

printf '\n== AC3 (corpus half): the repaired leg is non-decreasing too ==\n'
REP_SERIES=$(counts_at "$REP_OUT" $FIXED_W)
ok "repaired firings across $FIXED_W: $REP_SERIES"
check "no width finds less than a narrower one" \
      "$(printf '%s' "$REP_SERIES" | awk '{d=0; for(i=2;i<=NF;i++) if ($i+0 < $(i-1)+0) d=1; print d}')" "0"

printf '\n== CONTROL: the chunked read agrees with a whole-prefix read ==\n'
# fixed_verdict replicates loop-index.sh's chunk-doubling loop, which is the one
# piece of the detector this gate does not share with the hook. The equality
# below is why that is safe: the adaptive read and a read of the entire prefix
# must answer identically, because the loop terminates exactly when it holds
# want_calls calls or runs out of file. Sampled at the three firing ordinals and
# at three that must stay silent, so the control sees both answers.
call_index "$REAL" > "$IDX"
for probe in 1458 1470 1471 1457 1200 17; do
  row=$(awk -F"$TAB" -v o="$probe" 'NR==o' "$IDX")
  ln=$(printf '%s' "$row" | cut -f1); fp=$(printf '%s' "$row" | cut -f2)
  tool=$(printf '%s' "$row" | cut -f3); ag=$(printf '%s' "$row" | cut -f4)
  head -n $((ln-1)) "$REAL" > "$PRE"
  for w in 20 40; do
    check "ordinal $probe at K = $w: chunked == whole-prefix" \
          "$(fixed_verdict "$PRE" "$w" "$fp" "$tool" "$ag")" \
          "$(whole_prefix_verdict "$PRE" "$w" "$fp" "$tool" "$ag")"
  done
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
