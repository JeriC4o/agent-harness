#!/usr/bin/env bash
#
# Tests for ledger-write.sh -- the shared ledger append and its one-per-session
# failure report (GH-86). Run from anywhere:
#   bash hooks/lib/test-ledger-write.sh
#
# WHAT IS ACTUALLY UNDER TEST, because it is easy to write a suite that misses
# it. The old behaviour was not "silent" and it was not "explicit" either: a
# failed OPEN produced a raw shell error naming a path, on every tool call for
# the rest of the session, while a failed WRITE produced nothing at all. So the
# three properties here are that BOTH failure modes are detected, that the
# report is one readable sentence rather than a shell error, and that it
# happens ONCE -- across separate hook PROCESSES, which is the only reason the
# marker is a file.
#
# Every guard carries its own positive control, and the controls plant the
# defect in the SHIPPED helper rather than in a paraphrase of it.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
LIB="${HERE}/ledger-write.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }

WORK=$(mktemp -d)
trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT INT TERM

[ -r "$LIB" ] || { printf 'test-ledger-write: %s is not readable\n' "$LIB" >&2; exit 2; }
# shellcheck source=/dev/null
. "$LIB"

# Each case gets its own TMPDIR so a marker from one case cannot silence the
# next, and so the suite never writes a marker into the real temp dir -- where
# it would survive the run and silence the NEXT one.
fresh_tmp() { TMPDIR=$(mktemp -d "${WORK}/tmp.XXXXXX"); export TMPDIR; }

OUT="${WORK}/out"; ERR="${WORK}/err"
# Status and streams are kept apart: the whole point of this helper is what it
# says, so a suite that read only the return value would measure the half that
# was never broken.
call_append() { # <sid> <ledger> <line>
  RC=0
  harness_ledger_append "$1" "$2" "$3" > "$OUT" 2> "$ERR" || RC=$?
}
errbytes() { wc -c < "$ERR" | tr -d ' '; }
outbytes() { wc -c < "$OUT" | tr -d ' '; }

# ---------------------------------------------------------------------------
printf '\n== the happy path writes the line and says nothing ==\n'
# ---------------------------------------------------------------------------
fresh_tmp
GOOD="${WORK}/good.jsonl"
call_append sess-good "$GOOD" '{"kind":"call"}'
check "returns 0" "$RC" "0"
check "the line is on disk" "$(cat "$GOOD")" '{"kind":"call"}'
check "nothing on stderr" "$(errbytes)" "0"
check "nothing on stdout either -- a hook's stdout is its protocol channel" "$(outbytes)" "0"
call_append sess-good "$GOOD" '{"kind":"result"}'
check "it APPENDS rather than truncating" "$(wc -l < "$GOOD" | tr -d ' ')" "2"

# ---------------------------------------------------------------------------
printf '\n== mode 1: the open fails, and the report is a SENTENCE, not a shell error ==\n'
# ---------------------------------------------------------------------------
fresh_tmp
RO="${WORK}/readonly"
mkdir -p "$RO"
chmod 500 "$RO"
if [ -w "$RO" ]; then
  # Running as root makes a 500 directory writable, so the case would measure
  # nothing while reporting a pass.
  bad "precondition: a chmod 500 directory is still writable here, so this case cannot run"
else
  ok "precondition: the directory really is unwritable"
  call_append sess-ro "${RO}/x.jsonl" '{"kind":"call"}'
  check "returns 1, so the caller can skip what depended on the write" "$RC" "1"
  check "  and nothing reaches stdout" "$(outbytes)" "0"
  err=$(cat "$ERR")
  has "the report names the consequence first" "$err" "LOOP DETECTION IS DISABLED for this session"
  has "  names the path" "$err" "${RO}/x.jsonl"
  has "  says a quiet run is not evidence" "$err" "not evidence that nothing looped"
  has "  tells the reader what to do" "$err" "HARNESS_LOOP_DIR"
  has "  and says it will not repeat" "$err" "once per session"
  # The failure this replaces was the shell's own error leaking out beside
  # whatever else was printed. One line, from us, or the fix is half done.
  check "exactly one line on stderr" "$(wc -l < "$ERR" | tr -d ' ')" "1"
  case "$err" in
    *"ermission denied"*|*"No such file"*)
      bad "a raw shell error leaked through beside the sentence" ;;
    *) ok "no raw shell error leaked through" ;;
  esac
fi

printf '\n-- and it is said ONCE, which is the part that needs a file --\n'
call_append sess-ro "${RO}/x.jsonl" '{"kind":"call"}'
check "the second append still returns 1" "$RC" "1"
check "  but says nothing" "$(errbytes)" "0"
call_append sess-ro "${RO}/other.jsonl" '{"kind":"call"}'
check "and a different FILE in the same session is silent too -- the key is the session" \
      "$(errbytes)" "0"

printf '\n-- a different session is a different marker, so it DOES report --\n'
call_append sess-other "${RO}/x.jsonl" '{"kind":"call"}'
has "the second session gets its own report" "$(cat "$ERR")" "LOOP DETECTION IS DISABLED"

printf '\n-- the marker is a real file in TMPDIR, and it is named per session --\n'
check "two markers for two sessions" \
      "$(find "$TMPDIR" -maxdepth 1 -name 'harness-ledger-warned-*' | wc -l | tr -d ' ')" "2"
check "  and neither is beside the ledger, which is the unwritable thing" \
      "$(find "$RO" -name 'harness-ledger-warned-*' 2>/dev/null | wc -l | tr -d ' ')" "0"

# ---------------------------------------------------------------------------
printf '\n== mode 2: the open SUCCEEDS and the write fails ==\n'
# ---------------------------------------------------------------------------
# There is no /dev/full on this platform, so the write is failed directly:
# `printf` is shadowed for the one argument that carries the sentinel and
# delegates to the builtin for everything else, including the report's own
# printf. The redirection still runs, so the ledger file IS opened and the
# status is non-zero with nothing written -- which is exactly the shape of an
# ENOSPC append, and exactly the shape an open-only check cannot see.
SENTINEL='__MIDWRITE__'
printf() {
  case "$*" in
    *"$SENTINEL"*) return 1 ;;
  esac
  builtin printf "$@"
}
fresh_tmp
MW="${WORK}/midwrite.jsonl"
: > "$MW"
check "precondition: the ledger exists and its directory is writable" \
      "$( [ -f "$MW" ] && [ -w "$(dirname "$MW")" ] && echo yes || echo no )" "yes"
call_append sess-mw "$MW" "{\"kind\":\"call\",\"x\":\"${SENTINEL}\"}"
check "a failed write returns 1" "$RC" "1"
has "  and reports, although the open was fine" "$(cat "$ERR")" "LOOP DETECTION IS DISABLED"
check "  with nothing actually written" "$(wc -c < "$MW" | tr -d ' ')" "0"

# THE SAME FAILURE ON A LEDGER THAT ALREADY HAS ROWS, which is the realistic
# case: a session fills the disk after writing for an hour. It is a separate
# assertion because the empty-file case above does NOT discriminate between
# reading the write's status and testing `[ -s "$ledger" ]` -- both call an
# empty file a failure. Found by planting `[ -s ]` and watching the suite stay
# green, which is the one plant in this task that revealed a gap in the SUITE
# rather than confirming it.
fresh_tmp
MWF="${WORK}/midwrite-full.jsonl"
printf '{"kind":"call","seeded":true}\n' > "$MWF"
check "precondition: this ledger is NOT empty" \
      "$( [ -s "$MWF" ] && echo yes || echo no )" "yes"
call_append sess-mwf "$MWF" "{\"kind\":\"call\",\"x\":\"${SENTINEL}\"}"
check "a failed write on a non-empty ledger returns 1 too" "$RC" "1"
has "  and still reports" "$(cat "$ERR")" "LOOP DETECTION IS DISABLED"
check "  and the earlier rows are untouched" "$(wc -l < "$MWF" | tr -d ' ')" "1"
unset -f printf
check "control: the shadow is gone, so the next assertions measure the real builtin" \
      "$(printf 'live')" "live"
# And the control that makes the case mean something: the SAME scenario against
# an open-only check is silent. This is the pre-fix behaviour, written out, so
# the difference is demonstrated rather than asserted.
open_only_append() { ( : >> "$2" ) 2>/dev/null || return 1; return 0; }
fresh_tmp
call_append_openonly() { RC=0; open_only_append "$1" "$2" "$3" > "$OUT" 2> "$ERR" || RC=$?; }
call_append_openonly sess-oo "$MW" "{\"x\":\"${SENTINEL}\"}"
check "control: an open-only check calls the same failure a SUCCESS" "$RC" "0"
check "control: and therefore says nothing at all" "$(errbytes)" "0"

# ---------------------------------------------------------------------------
printf '\n== an unwritable TMPDIR degrades to silence, never to a crash ==\n'
# ---------------------------------------------------------------------------
fresh_tmp
chmod 500 "$TMPDIR"
if [ -w "$TMPDIR" ]; then
  bad "precondition: a chmod 500 TMPDIR is still writable here, so this case cannot run"
else
  ok "precondition: TMPDIR really is unwritable"
  call_append sess-notmp "${RO}/x.jsonl" '{"kind":"call"}'
  check "the append still returns 1" "$RC" "1"
  # With nowhere to record "already said", the alternatives are to repeat the
  # sentence on every tool call or to say nothing. Silence is the one that
  # cannot make a bad situation worse.
  check "  and with nowhere to record the marker, it stays quiet" "$(errbytes)" "0"
  call_append sess-notmp "${RO}/x.jsonl" '{"kind":"call"}'
  check "  on the second call too, rather than once per call forever" "$(errbytes)" "0"
fi
chmod 700 "$TMPDIR"

# ---------------------------------------------------------------------------
printf '\n== a session id is not trusted to be a filename ==\n'
# ---------------------------------------------------------------------------
fresh_tmp
ESCAPE="../../escaped"
call_append "$ESCAPE" "${RO}/x.jsonl" '{"kind":"call"}'
has "it still reports" "$(cat "$ERR")" "LOOP DETECTION IS DISABLED"
check "and the marker landed inside TMPDIR, not above it" \
      "$(find "$TMPDIR" -maxdepth 1 -name 'harness-ledger-warned-*' | wc -l | tr -d ' ')" "1"
# `.` is IN the safe set, so `../../escaped` sanitises to `.._.._escaped`, not
# to all underscores. That is still safe and it is the point: what has to go is
# the SEPARATOR, since a dot run with no slash cannot traverse anywhere. The
# assertion names the real string rather than the one that was predicted.
check "  with the separators replaced rather than honoured" \
      "$(find "$TMPDIR" -maxdepth 1 -name 'harness-ledger-warned-.._.._escaped' | wc -l | tr -d ' ')" "1"
check "  and no marker name carries a path separator at all" \
      "$(find "$TMPDIR" -maxdepth 1 -name 'harness-ledger-warned-*' -exec basename {} \; | grep -c '/' || true)" "0"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
