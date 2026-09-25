#!/usr/bin/env bash
#
# Files one already-approved defect report about the harness as an issue on the
# harness's own repository.
#
# Usage:
#   file-report.sh hash  <report.md>
#   file-report.sh check <report.md> [--ledger <path>]
#   file-report.sh file  <report.md> [--ledger <path>] [--title <text>]
#
# Exit: 0 clean, 1 refused (already filed) or the filing failed, 2 usage error.
#
# WHY A SCRIPT RATHER THAN INSTRUCTIONS. "The issue carries the version", "the
# issue carries the channel marker", "a failure is never swallowed" and "the
# same defect is never filed twice" are all claims about what happens at filing
# time. Written as prose in a skill they are unfalsifiable; written here they
# are a test case each. The skill keeps only what a script cannot own: drafting
# the report, showing it, and obtaining approval. This runs after that.
#
# WHY THE REPOSITORY AND VERSION ARE READ AT RUNTIME. A hardcoded upstream URL
# sends a fork's reports to somebody else's repository. Both come from the
# manifest of whichever tree is running, so a fork files against itself.
#
# THE DUPLICATE STOP LIVES IN `file`, NOT ONLY IN `check`. A stop that lived in
# `check` alone would rest on the caller remembering to run it first, which is a
# claim about agent behaviour and cannot be asserted. `file` re-reads the ledger
# as its first act and refuses before any `gh` invocation. `check` stays as the
# cheap pre-flight that saves drafting work, not as the guard.
#
# Tests: skills/report-defect/scripts/test-file-report.sh

set -uo pipefail

die() { printf 'file-report: %s\n' "$1" >&2; exit 2; }

VERB="${1:-}"; shift 2>/dev/null
case "$VERB" in
  hash|check|file) ;;
  -h|--help) sed -n '3,12p' "$0"; exit 0 ;;
  *) die "usage: file-report.sh hash|check|file <report.md> [--ledger <path>] [--title <text>]" ;;
esac

FILE=""; LEDGER=""; TITLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ledger) LEDGER="${2:-}"; shift 2 ;;
    --title)  TITLE="${2:-}"; shift 2 ;;
    -*)       die "unknown flag: $1" ;;
    *)        [ -z "$FILE" ] || die "unexpected argument: $1"; FILE="$1"; shift ;;
  esac
done

[ -n "$FILE" ] || die "usage: file-report.sh $VERB <report.md>"
[ -f "$FILE" ] || die "no such file: $FILE"

# ---- the harness root --------------------------------------------------------
# $0 is the PRIMARY branch: both plugin env vars are unset inside a Bash call, so
# in a real consuming-project run nothing supplies one and the derivation is what
# executes. This script always lives at <root>/skills/<name>/scripts/, so three
# levels up from its own directory is the root of whichever copy is running.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  ROOT_BRANCH="CLAUDE_PLUGIN_ROOT override"
  HARNESS_ROOT="$CLAUDE_PLUGIN_ROOT"
else
  ROOT_BRANCH="\$0 derivation"
  HARNESS_ROOT="$(dirname -- "$0")/../../.."
fi
HARNESS_ROOT=$(cd -- "$HARNESS_ROOT" 2>/dev/null && pwd -P) || die "harness root does not resolve"
for marker in .claude-plugin/plugin.json docs/agents-method.md; do
  [ -e "$HARNESS_ROOT/$marker" ] || die "no $marker under $HARNESS_ROOT; not a harness install"
done
MANIFEST="$HARNESS_ROOT/.claude-plugin/plugin.json"

command -v jq >/dev/null 2>&1 || die "jq is not on PATH"
VERSION=$(jq -r '.version // empty' "$MANIFEST")
REPOSITORY=$(jq -r '.repository // empty' "$MANIFEST")
[ -n "$VERSION" ] || die "no version in $MANIFEST"

# ---- the idempotency hash ----------------------------------------------------
# A narrow, stable key: the file at fault plus the symptom wording. A whole-report
# hash would collide only on a copy-paste, and the thing that must be stopped is a
# REDRAFT of the same defect in new words. The line number is volatile metadata,
# not identity, so it is stripped; the harness version is deliberately absent,
# because the same defect surviving an upgrade is still the same defect.
field() {
  LC_ALL=C awk -v key="**$1:**" '
    index($0, key) == 1 { grab = 1; sub(/^\*\*[A-Za-z_]+:\*\*[ \t]*/, ""); print; next }
    grab && /^\*\*[A-Za-z_]+:\*\*/ { grab = 0 }
    grab { print }
  ' "$2"
}

# LC_ALL=C is not decoration: without it `tr -c` is unreliable on multi-byte
# input, and defect reports contain em-dashes.
norm() {
  LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -c 'a-z0-9' ' ' | LC_ALL=C tr -s ' ' \
    | sed -e 's/^ //' -e 's/ $//'
}

if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum; }
else
  die "neither shasum nor sha256sum is on PATH; cannot compute the idempotency hash"
fi

SURFACE=$(field Surface "$FILE" | sed -E 's/[[:space:]]+$//' | sed -E 's/:[0-9]+$//' | norm)
SYMPTOM=$(field Symptom "$FILE" | norm)
HASH=$(printf '%s\n%s\n' "$SURFACE" "$SYMPTOM" | sha256 | cut -c1-12)

if [ "$VERB" = hash ]; then printf '%s\n' "$HASH"; exit 0; fi

# ---- the ledger --------------------------------------------------------------
[ -n "$LEDGER" ] || LEDGER="$(cd -- "$(dirname -- "$FILE")" && pwd)/filed.json"

# Absent is the first run in every project and must not be an error. Present but
# damaged must not be one either: a zero-byte, truncated, null or `filed`-less
# ledger all return empty stdout from the obvious lookup, so a naive read turns a
# corrupt ledger into a silent duplicate filing whose success-path write then
# clobbers a file committed with the project. The discriminator below is the one
# form that separates all four at once. Its own stderr is suppressed because the
# call is made FOR its exit status -- that discards no signal, and it keeps jq's
# raw parse trace from appearing beside the reason this script names.
LEDGER_ROW=""
read_ledger() {
  [ -f "$LEDGER" ] || return 0
  jq -e 'type == "object" and (.filed | type) == "object"' "$LEDGER" >/dev/null 2>&1 \
    || die "$LEDGER is not a readable ledger (want a JSON object carrying a \"filed\" object); refusing to read it"
  LEDGER_ROW=$(jq -c --arg h "$HASH" '.filed[$h] // empty' "$LEDGER")
}

already_filed() {
  url=$(printf '%s' "$LEDGER_ROW" | jq -r '.issue // "(none recorded)"')
  was=$(printf '%s' "$LEDGER_ROW" | jq -r '.harness_version // "(none recorded)"')
  {
    printf 'already filed: %s\n' "$url"
    printf '  filed against harness_version %s   (this run: %s)\n' "$was" "$VERSION"
    printf '  if the defect is still live on this version, re-file by removing the\n'
    printf '  "%s" entry from %s, then run again\n' "$HASH" "$LEDGER"
  } >&2
}

read_ledger
if [ -n "$LEDGER_ROW" ]; then already_filed; exit 1; fi
[ "$VERB" = check ] && exit 0

# ---- file --------------------------------------------------------------------
[ -n "$REPOSITORY" ] || die "no repository in $MANIFEST"
SLUG=${REPOSITORY#*://}; SLUG=${SLUG#*/}; SLUG=${SLUG%.git}; SLUG=${SLUG%/}

if [ -z "$TITLE" ]; then
  TITLE="[harness-feedback] $(field Symptom "$FILE" | head -1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -c1-120)"
fi
case "$TITLE" in "[harness-feedback] "*) ;; *) TITLE="[harness-feedback] $TITLE" ;; esac

TMPDIR_RUN=$(mktemp -d) || die "cannot create a temp dir"
trap 'rm -rf "$TMPDIR_RUN"' EXIT INT TERM
BODY="$TMPDIR_RUN/body.md"
{
  cat "$FILE"
  printf '\n---\n\n'
  printf 'Filed by the harness feedback channel.\n\n'
  printf -- '- harness version: %s\n' "$VERSION"
  printf -- '- report hash: %s\n' "$HASH"
  printf -- '- harness root resolved via %s: %s\n' "$ROOT_BRANCH" "$HARNESS_ROOT"
} > "$BODY"

# A channel that fails silently is not used twice: on every failure the report
# stays on disk, its full text goes to stdout for manual pasting, and nothing is
# written to the ledger.
fail_loudly() {
  printf 'file-report: %s\n' "$1" >&2
  printf 'file-report: the report is still at %s; paste the text below manually.\n' "$FILE" >&2
  printf 'file-report: title: %s\n' "$TITLE" >&2
  cat "$BODY"
  exit 1
}

command -v gh >/dev/null 2>&1 || fail_loudly "gh is not on PATH, so the issue was not filed"

OUT=$(gh issue create -R "$SLUG" --title "$TITLE" --body-file "$BODY" 2>&1); rc=$?
URL=$(printf '%s' "$OUT" | grep -oE 'https?://[^[:space:]]+' | tail -1)
if [ "$rc" != 0 ] || [ -z "$URL" ]; then
  fail_loudly "gh issue create failed (rc=$rc): $(printf '%s' "$OUT" | tr '\n' ' ')"
fi

# Temp file plus mv, so a killed run leaves the previous ledger intact rather
# than a half-written one. The ledger is committed with the project.
mkdir -p -- "$(dirname -- "$LEDGER")"
existing='{"version":1,"filed":{}}'
[ -f "$LEDGER" ] && existing=$(cat "$LEDGER")
tmp=$(mktemp "${LEDGER}.XXXXXX") || die "cannot create a temp file beside $LEDGER"
if printf '%s' "$existing" | jq --arg h "$HASH" --arg i "$URL" --arg t "$TITLE" \
     --arg r "$(basename -- "$FILE")" --arg v "$VERSION" --arg d "$(date -u '+%Y-%m-%d')" \
     '.version = (.version // 1)
      | .filed[$h] = {issue: $i, title: $t, report: $r, harness_version: $v, filed: $d}' \
     > "$tmp"
then
  mv -- "$tmp" "$LEDGER"
else
  rm -f -- "$tmp"
  printf 'file-report: the issue was filed at %s but the ledger write failed; add the row by hand.\n' "$URL" >&2
  exit 1
fi

printf 'filed: %s\n' "$URL"
printf 'recorded in %s under %s\n' "$LEDGER" "$HASH"
exit 0
