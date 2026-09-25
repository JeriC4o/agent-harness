#!/usr/bin/env bash
#
# Tests for file-report.sh. Run from anywhere:
#   bash skills/report-defect/scripts/test-file-report.sh
#
# NO ISSUE IS EVER CREATED. `gh` is a recording stub on a per-case PATH for every
# case that reaches the filing branch, so "zero further invocations" is an
# assertion about a counted log rather than about an absence of errors.
#
# Every case that resolves a harness root resolves a FIXTURE one, never the tree
# this suite lives in: the manifest values asserted below are the fixture's, so a
# pass is a property of the fixture and not of whichever version happens to be
# checked out.
#
# The production branch is `$0` derivation with CLAUDE_PLUGIN_ROOT unset -- both
# plugin env vars are unset inside a Bash call -- so most cases run a COPY of the
# script placed inside the fixture root, and the env override gets its own cases.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
SRC="${HERE}/file-report.sh"
PASS=0
FAIL=0

ok()    { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in [$2]" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 -- did not expect [$3]" ;; *) ok "$1" ;; esac; }

FIX_VERSION="9.9.9-fixture"
FIX_REPO="https://example.invalid/acme/forked-harness"
FIX_SLUG="acme/forked-harness"
STUB_URL="https://example.invalid/acme/forked-harness/issues/31"

FIXROOT=$(mktemp -d)
mkdir -p "$FIXROOT/.claude-plugin" "$FIXROOT/docs" "$FIXROOT/skills/report-defect/scripts"
printf '{"name":"harness","version":"%s","repository":"%s"}\n' "$FIX_VERSION" "$FIX_REPO" \
  > "$FIXROOT/.claude-plugin/plugin.json"
printf '# method\n' > "$FIXROOT/docs/agents-method.md"
cp "$SRC" "$FIXROOT/skills/report-defect/scripts/file-report.sh"
PROD="$FIXROOT/skills/report-defect/scripts/file-report.sh"

BARE=$(mktemp -d)

report() { # <path> <symptom> <surface> <repro>
  mkdir -p -- "$(dirname -- "$1")"
  cat > "$1" <<EOF
---
harness_version: ${FIX_VERSION}
hash: pending
---

**Symptom:** $2

**Repro:** $4

**Expected:** The step completes without the extra prompt.

**Surface:** $3

**Evidence:** Seen on two consecutive runs of the same step.
EOF
}

SYM="The inspector is handed an input it never receives — the run stalls."
SURF="scripts/session-events.sh:14"
REP="Run the reduction step twice in a row."

mkproj() { # -> prints the project dir, holding ai-docs/feedback/r.md
  d=$(mktemp -d)
  report "$d/ai-docs/feedback/r.md" "$SYM" "$SURF" "$REP"
  printf '%s' "$d"
}

# The stub copies the body aside because file-report.sh deletes its temp dir on
# exit, so the emitted body is otherwise unreadable after the run.
mkstubbin() {
  d=$(mktemp -d)
  cat > "$d/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$GH_LOG"
prev=""
for a in "$@"; do
  [ "$prev" = "--body-file" ] && cp "$a" "$GH_BODY"
  prev="$a"
done
printf 'Creating issue in acme/forked-harness\n'
printf 'https://example.invalid/acme/forked-harness/issues/31\n'
EOF
  chmod +x "$d/gh"
  printf '%s' "$d"
}

# A PATH that keeps everything the script needs and drops gh. Symlinking the
# tools is the only form that holds: gh and jq share a directory under the usual
# package managers, so pruning that directory from PATH would take jq with it.
mkbin_no_gh() {
  d=$(mktemp -d)
  for t in bash env jq shasum sha256sum awk sed tr cut cat grep mktemp dirname basename date mkdir mv rm head; do
    p=$(command -v "$t" 2>/dev/null) && ln -s "$p" "$d/$t"
  done
  printf '%s' "$d"
}

STUBBIN=$(mkstubbin)
NOGHBIN=$(mkbin_no_gh)

prod() { env -u CLAUDE_PLUGIN_ROOT bash "$PROD" "$@"; }

printf '\n== hash: determinism and the narrow key ==\n'
P=$(mkproj); R="$P/ai-docs/feedback/r.md"
H1=$(prod hash "$R"); H2=$(prod hash "$R"); H3=$(prod hash "$R")
check "3 runs agree (1 vs 2)" "$H1" "$H2"
check "3 runs agree (1 vs 3)" "$H1" "$H3"
case "$H1" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ok "12 hex characters" ;;
  *) bad "12 hex characters (got [$H1])" ;;
esac

report "$P/ai-docs/feedback/repro.md" "$SYM" "$SURF" "An entirely different set of steps, reworded."
check "stable under a rewritten Repro" "$(prod hash "$P/ai-docs/feedback/repro.md")" "$H1"

report "$P/ai-docs/feedback/case.md" "THE INSPECTOR IS HANDED an input   it NEVER receives — the run stalls!!" "$SURF" "$REP"
check "stable under case, punctuation and whitespace" "$(prod hash "$P/ai-docs/feedback/case.md")" "$H1"

report "$P/ai-docs/feedback/line.md" "$SYM" "scripts/session-events.sh:117" "$REP"
check "stable under a changed line number" "$(prod hash "$P/ai-docs/feedback/line.md")" "$H1"

report "$P/ai-docs/feedback/sym.md" "A different defect entirely in the same file." "$SURF" "$REP"
if [ "$(prod hash "$P/ai-docs/feedback/sym.md")" != "$H1" ]; then ok "differs on a changed Symptom"; else bad "differs on a changed Symptom"; fi

report "$P/ai-docs/feedback/surf.md" "$SYM" "scripts/trace-tokens.sh:14" "$REP"
if [ "$(prod hash "$P/ai-docs/feedback/surf.md")" != "$H1" ]; then ok "differs on a changed Surface"; else bad "differs on a changed Surface"; fi

printf '\n== check: the five ledger states ==\n'
P=$(mkproj); R="$P/ai-docs/feedback/r.md"; L="$P/ai-docs/feedback/filed.json"
out=$(prod check "$R" 2>&1); rc=$?
check "absent ledger exits 0" "$rc" "0"
check "absent ledger prints nothing" "$out" ""

printf '{"version":1,"filed":{}}\n' > "$L"
out=$(prod check "$R" 2>&1); rc=$?
check "empty ledger exits 0" "$rc" "0"
check "empty ledger prints nothing" "$out" ""

H=$(prod hash "$R")
printf '{"version":1,"filed":{"%s":{"issue":"%s","title":"t","report":"r.md","harness_version":"0.1.2","filed":"2026-09-01"}}}\n' \
  "$H" "$STUB_URL" > "$L"
out=$(prod check "$R" 2>&1); rc=$?
check "a hit exits non-zero" "$rc" "1"
has "  names the recorded issue URL"        "$out" "$STUB_URL"
has "  names the recorded harness_version"  "$out" "filed against harness_version 0.1.2"
has "  names the version of this run"       "$out" "(this run: ${FIX_VERSION})"
has "  gives the ledger-row override"       "$out" "entry from"
has "  names the ledger file"               "$out" "filed.json"
has "  names the row to remove"             "$out" "$H"

printf '%s' '{"version":1,"filed":{"abc' > "$L"
out=$(prod check "$R" 2>&1); rc=$?
check "a truncated ledger exits 2" "$rc" "2"
has "  the reason is this script's, not jq's" "$out" "is not a readable ledger"
hasnt "  jq's own parse trace is suppressed"  "$out" "parse error"

: > "$L"
out=$(prod check "$R" 2>&1); rc=$?
check "a zero-byte ledger exits 2" "$rc" "2"
has "  reason named" "$out" "is not a readable ledger"

printf '\n== file (a): the success path WRITES the row, on an ABSENT ledger ==\n'
P=$(mkproj); R="$P/ai-docs/feedback/r.md"; L="$P/ai-docs/feedback/filed.json"
H=$(prod hash "$R")
export GH_LOG="$P/gh.log"; export GH_BODY="$P/gh.body"; : > "$GH_LOG"
out=$(PATH="${STUBBIN}:${PATH}" env -u CLAUDE_PLUGIN_ROOT bash "$PROD" file "$R" 2>&1); rc=$?
check "exit 0" "$rc" "0"
check "gh invoked exactly once" "$(wc -l < "$GH_LOG" | tr -d ' ')" "1"
[ -f "$L" ] && ok "the ledger was created" || bad "the ledger was created"
check "the row's issue is the URL gh returned" "$(jq -r --arg h "$H" '.filed[$h].issue' "$L")" "$STUB_URL"
check "the row's harness_version is the manifest's" "$(jq -r --arg h "$H" '.filed[$h].harness_version' "$L")" "$FIX_VERSION"
check "the row is keyed by the hash" "$(jq -r --arg h "$H" '.filed | has($h)' "$L")" "true"
check "the row records the report file" "$(jq -r --arg h "$H" '.filed[$h].report' "$L")" "r.md"
has "reports where it filed" "$out" "$STUB_URL"

printf '\n== file: what reached gh ==\n'
ghargs=$(cat "$GH_LOG")
has "the title carries the channel marker" "$ghargs" "[harness-feedback]"
has "-R comes from the manifest repository" "$ghargs" "-R ${FIX_SLUG}"
body=$(cat "$GH_BODY")
has "the body carries the report text"      "$body" "$SYM"
has "the body carries the manifest version" "$body" "harness version: ${FIX_VERSION}"
has "the body carries the hash"             "$body" "report hash: ${H}"
has "the body names the root-resolution branch" "$body" 'resolved via $0 derivation'
hasnt "  and not the other branch"          "$body" "resolved via CLAUDE_PLUGIN_ROOT override"
has "the body names the root it resolved"   "$body" "$FIXROOT"

printf '\n== file (b): the same call again, against ONLY the ledger (a) wrote ==\n'
out=$(PATH="${STUBBIN}:${PATH}" env -u CLAUDE_PLUGIN_ROOT bash "$PROD" file "$R" 2>&1); rc=$?
if [ "$rc" != 0 ]; then ok "the second run exits non-zero"; else bad "the second run exits non-zero"; fi
check "gh total is STILL 1 -- zero further invocations" "$(wc -l < "$GH_LOG" | tr -d ' ')" "1"
has "  names the issue the first run filed" "$out" "$STUB_URL"
has "  names the recorded harness_version"  "$out" "filed against harness_version ${FIX_VERSION}"
has "  gives the ledger-row override"       "$out" "entry from"

printf '\n== file (c): a pre-seeded hit refuses before any gh call ==\n'
P=$(mkproj); R="$P/ai-docs/feedback/r.md"; L="$P/ai-docs/feedback/filed.json"
H=$(prod hash "$R")
printf '{"version":1,"filed":{"%s":{"issue":"%s","harness_version":"0.1.2"}}}\n' "$H" "$STUB_URL" > "$L"
before=$(shasum "$L" | cut -d' ' -f1)
export GH_LOG="$P/gh.log"; export GH_BODY="$P/gh.body"; : > "$GH_LOG"
out=$(PATH="${STUBBIN}:${PATH}" env -u CLAUDE_PLUGIN_ROOT bash "$PROD" file "$R" 2>&1); rc=$?
if [ "$rc" != 0 ]; then ok "exits non-zero"; else bad "exits non-zero"; fi
check "gh invoked ZERO times" "$(wc -l < "$GH_LOG" | tr -d ' ')" "0"
check "the ledger is byte-identical afterwards" "$(shasum "$L" | cut -d' ' -f1)" "$before"
has "  the three-line message" "$out" "already filed: ${STUB_URL}"

printf '\n== file (d): a damaged ledger is exit 2, no gh call, no write ==\n'
for shape in truncated zero-byte; do
  P=$(mkproj); R="$P/ai-docs/feedback/r.md"; L="$P/ai-docs/feedback/filed.json"
  case "$shape" in
    truncated) printf '%s' '{"version":1,"filed":{"abc' > "$L" ;;
    zero-byte) : > "$L" ;;
  esac
  before=$(shasum "$L" | cut -d' ' -f1)
  export GH_LOG="$P/gh.log"; export GH_BODY="$P/gh.body"; : > "$GH_LOG"
  out=$(PATH="${STUBBIN}:${PATH}" env -u CLAUDE_PLUGIN_ROOT bash "$PROD" file "$R" 2>&1); rc=$?
  check "${shape}: exit 2" "$rc" "2"
  has   "${shape}: reason named" "$out" "is not a readable ledger"
  check "${shape}: gh invoked ZERO times" "$(wc -l < "$GH_LOG" | tr -d ' ')" "0"
  check "${shape}: the file is byte-identical" "$(shasum "$L" | cut -d' ' -f1)" "$before"
done

printf '\n== file: gh absent from PATH -- loud, never swallowed ==\n'
P=$(mkproj); R="$P/ai-docs/feedback/r.md"; L="$P/ai-docs/feedback/filed.json"
printf '{"version":1,"filed":{}}\n' > "$L"
before=$(shasum "$L" | cut -d' ' -f1)
out=$(PATH="$NOGHBIN" env -u CLAUDE_PLUGIN_ROOT bash "$PROD" file "$R" 2>/dev/null); rc=$?
err=$(PATH="$NOGHBIN" env -u CLAUDE_PLUGIN_ROOT bash "$PROD" file "$R" 2>&1 >/dev/null); rc2=$?
if [ "$rc" != 0 ]; then ok "exits non-zero"; else bad "exits non-zero"; fi
has "the failure is named on stderr" "$err" "gh is not on PATH"
has "the full report text goes to stdout" "$out" "$SYM"
has "  including every required section"  "$out" "**Evidence:**"
has "  and the title to paste"            "$err" "[harness-feedback]"
[ -f "$R" ] && ok "the report file is still on disk" || bad "the report file is still on disk"
check "the ledger is unchanged" "$(shasum "$L" | cut -d' ' -f1)" "$before"

printf '\n== the env override is the second branch, and it is honoured ==\n'
P=$(mkproj); R="$P/ai-docs/feedback/r.md"
export GH_LOG="$P/gh.log"; export GH_BODY="$P/gh.body"; : > "$GH_LOG"
out=$(PATH="${STUBBIN}:${PATH}" CLAUDE_PLUGIN_ROOT="$FIXROOT" bash "$SRC" file "$R" 2>&1); rc=$?
check "exit 0 through the worktree copy pinned to the fixture root" "$rc" "0"
body=$(cat "$GH_BODY")
has "the body names the override branch" "$body" "resolved via CLAUDE_PLUGIN_ROOT override"
hasnt "  and not the derived one"        "$body" 'resolved via $0 derivation'
has "the manifest version is the fixture's, not this repo's" "$body" "harness version: ${FIX_VERSION}"

printf '\n== a root without the harness markers is exit 2 ==\n'
out=$(CLAUDE_PLUGIN_ROOT="$BARE" bash "$SRC" hash "$R" 2>&1); rc=$?
check "exit 2" "$rc" "2"
has "  names the missing marker" "$out" "not a harness install"
printf '{"x":1}\n' > "$BARE/.claude-plugin-not-it.json"
mkdir -p "$BARE/.claude-plugin"; printf '{"version":"1"}\n' > "$BARE/.claude-plugin/plugin.json"
out=$(CLAUDE_PLUGIN_ROOT="$BARE" bash "$SRC" hash "$R" 2>&1); rc=$?
check "one marker is not enough" "$rc" "2"
has "  names the one still missing" "$out" "docs/agents-method.md"
out=$(CLAUDE_PLUGIN_ROOT="${BARE}/nope" bash "$SRC" hash "$R" 2>&1); rc=$?
check "an unresolvable root is exit 2" "$rc" "2"
has "  reason named" "$out" "does not resolve"

printf '\n== the entry point the skill invokes by full path is executable ==\n'
# SKILL.md invokes this script directly, not via `bash <path>`, while every case
# above runs it as `bash "$PROD"` — which masks a missing execute bit completely.
# Without the bit a consumer following the skill gets exit 126 on the first step.
if [ -x "$SRC" ]; then ok "file-report.sh carries the execute bit"
else bad "file-report.sh carries the execute bit"; fi

printf '\n== usage ==\n'
out=$(prod bogus "$R" 2>&1); rc=$?
check "an unknown verb is exit 2" "$rc" "2"
out=$(prod hash "${R}.nope" 2>&1); rc=$?
check "a missing report file is exit 2" "$rc" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
