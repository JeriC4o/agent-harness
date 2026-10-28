#!/usr/bin/env bash
#
# Print the archive listing: for every completed plan, its date, its task key,
# its document names, the spec's record of deliberate absence and the design's
# use cases -- and nothing else from either document.
#
# Run:  plan-archive.sh [<project-root>]
#       Without a root, the top level of the git work tree the current directory
#       sits in; outside a work tree, the current directory.
# Exit: 0 every plan listed, the trailer counting plans and documents
#       2 not complete -- which is NOT an empty archive. A run-level stop (no
#         archive, an unreadable or unparseable method input, a missing tool)
#         prints only its reason; a document it could not list leaves everything
#         else listed and the trailer naming each such document and why; a failed
#         write to standard output stops the run, naming the write on stderr.
#
# Tests: scripts/test-plan-archive.sh
#
# WHAT IT READS. The project's ai-docs/plans/done/, as it stands on every run,
# and two method inputs resolved from this script's own directory, so an
# installed copy lists the consuming project's archive: the spec's three
# section names, parsed from the RETAINED assignment in check-redline.sh so the
# record of deliberate absence stays one list, and the required-element record
# on docs/plan-invariants.md.
#
# WHY THE DESIGN'S SECTION NAME IS A STRING INSIDE THE AWK PROGRAM, and why no
# comment here names a section beside a presence word. The plan-invariants
# coverage sweep reads a page as element-defining by shape -- a shell assignment
# whose entries include a section name, or a quoted section name on a line that
# also carries a presence word -- and reports such a page outside the refusal's
# page set as an unguarded route. This listing reads sections and mandates
# none, so it keeps both shapes out of its own text. The cost is a name held
# in one more place; the cross-check against the required-element record makes
# a renamed template section a cannot-run instead of every later design reading
# as one with no cases.
#
# WHY SECTIONS ARE FRAMED BY A LINE COUNT. A section's text can hold anything --
# a rule, a fenced example, a line shaped like this listing's own framing -- so
# a delimiter recognised by its shape could be forged by the content it frames.
# A count cannot.

set -uo pipefail

# The C locale makes awk compare strings byte for byte. Under a UTF-8 locale the
# awk macOS ships compares by collation, which ignores some characters, so two
# different headings -- or a key and the same key with its separator still on
# it -- compare equal.
export LC_ALL=C

cannot() { printf 'plan-archive: cannot run: %s\n' "$1" >&2; exit 2; }

[ $# -le 1 ] || cannot 'usage: plan-archive.sh [<project-root>]'

for tool in awk sort mktemp dirname cat rm; do
  command -v "$tool" >/dev/null 2>&1 || cannot "${tool} is not on PATH"
done

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ENFORCER="${HERE}/check-redline.sh"
RECORD="${HERE}/../docs/plan-invariants.md"

if [ $# -eq 1 ]; then
  [ -d "$1" ] || cannot "no such project root: $1"
  root=$(cd -- "$1" && pwd)
else
  command -v git >/dev/null 2>&1 \
    || cannot 'git is not on PATH, so the project root cannot be found; pass it as the argument'
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$(pwd)
fi
archive="${root}/ai-docs/plans/done"

WORK=$(mktemp -d) || cannot 'mktemp -d failed'
trap 'rm -rf "$WORK"' EXIT

# <role> <state> <document label> <why> <file>
# role: spec | design | heading. state: read | missing | unlisted.
extract() {
  awk -v role="$1" -v state="$2" -v doc="$3" -v why="$4" \
      -v keyout="${WORK}/key" -v errout="${WORK}/err" '
    function rtrim(s) { sub(/[ \t\r]+$/, "", s); return s }
    function hashes(s,   k) {
      k = 0
      while (substr(s, k + 1, 1) == "#") k++
      if (k < 1 || k > 6) return 0
      if (substr(s, k + 1, 1) != " " && substr(s, k + 1, 1) != "\t") return 0
      return k
    }
    function fence_run(s, closing,   ind, ch, k, rest) {
      ind = 0
      while (substr(s, ind + 1, 1) == " ") ind++
      if (ind > 3) return 0
      s = substr(s, ind + 1)
      ch = substr(s, 1, 1)
      if (ch != bt && ch != "~") return 0
      if (closing && ch != fch) return 0
      k = 0
      while (substr(s, k + 1, 1) == ch) k++
      if (k < 3) return 0
      if (closing) {
        rest = substr(s, k + 1)
        if (k < flen || rest !~ /^[ \t\r]*$/) return 0
        return k
      }
      fch = ch
      return k
    }
    function strip_value(v,   prev) {
      do {
        prev = v
        v = rtrim(v)
        if (v ~ /[,;|]$/) v = substr(v, 1, length(v) - 1)
        else if (has_suffix(v, "·")) v = substr(v, 1, length(v) - length("·"))
        else if (has_suffix(v, "—")) v = substr(v, 1, length(v) - length("—"))
        else if (has_suffix(v, "–")) v = substr(v, 1, length(v) - length("–"))
      } while (v != prev)
      sub(/^[ \t]+/, "", v)
      return v
    }
    function has_suffix(s, t) {
      return length(s) >= length(t) && substr(s, length(s) - length(t) + 1) == t
    }
    function frame(h, what) { printf "--- %s: %s (%s)\n", doc, h, what }
    BEGIN {
      bt = sprintf("%c", 96)
      design_heading = "## Use cases"
      if (role == "heading") { print design_heading; stop = 1; exit }
      if (role == "spec") {
        label = "**Tracked in:**"
        nw = split(ENVIRON["PLAN_ARCHIVE_SPEC_HEADINGS"], want, "\n")
      } else {
        label = "**Ticket:**"
        nw = 1
        want[1] = design_heading
      }
      if (state != "read") {
        for (i = 1; i <= nw; i++)
          frame(want[i], state == "missing" ? "absent" : "not listed: " why)
        stop = 1
        exit
      }
    }
    {
      n = NR
      line[n] = $0
      inside[n] = infence
      level[n] = 0
      if (infence) {
        if (fence_run($0, 1)) infence = 0
        next
      }
      if (fence_run($0, 0)) {
        flen = fence_run($0, 0)
        infence = 1
        fstart = n
        inside[n] = 1
        next
      }
      level[n] = hashes($0)
      if (level[n] >= 2) inhead_done = 1
      if (!inhead_done && key == "" && index($0, label)) {
        v = substr($0, index($0, label) + length(label))
        c = index(v, "**")
        if (c) v = substr(v, 1, c - 1)
        key = strip_value(v)
      }
    }
    END {
      if (stop) exit
      if (infence) {
        printf "a fenced block opened at line %d never closes, so every section after it would read as absent\n", fstart > errout
        exit 3
      }
      printf "%s\n", key > keyout
      for (i = 1; i <= nw; i++) {
        h = want[i]
        lv = hashes(h)
        found = 0
        for (j = 1; j <= n; j++) {
          if (inside[j] || level[j] == 0 || rtrim(line[j]) != h) continue
          e = j + 1
          while (e <= n && (inside[e] || level[e] == 0 || level[e] > lv)) e++
          frame(h, e - j == 1 ? "1 line follows" : (e - j) " lines follow")
          for (k = j; k < e; k++) print line[k]
          found = 1
        }
        if (!found) frame(h, "absent")
      }
    }
  ' "$5"
}

[ -f "$ENFORCER" ] && [ -r "$ENFORCER" ] \
  || cannot "${ENFORCER} cannot be read, and the spec's sections are read from its RETAINED assignment"
spec_headings=$(awk -v q="'" '
  !on {
    if (index($0, "RETAINED=" q) != 1) next
    on = 1
    $0 = substr($0, length("RETAINED=" q) + 1)
  }
  {
    c = index($0, q)
    s = c ? substr($0, 1, c - 1) : $0
    gsub(/^[ \t]+|[ \t]+$/, "", s)
    if (s != "") print s
    if (c) { closed = 1; exit }
  }
  END { if (!closed) exit 3 }
' "$ENFORCER")
st=$?
[ "$st" -eq 0 ] && [ -n "$spec_headings" ] \
  || cannot "${ENFORCER} carries no readable RETAINED assignment, so there is no list of the spec's sections to extract"
export PLAN_ARCHIVE_SPEC_HEADINGS="$spec_headings"

[ -f "$RECORD" ] && [ -r "$RECORD" ] \
  || cannot "${RECORD} cannot be read, and the design's section is cross-checked against its required-element record"
recorded=$(awk -v sect='## The required elements of a spec and of a design' '
  { t = $0; sub(/[ \t\r]+$/, "", t) }
  t == sect { on = 1; next }
  on && /^## / { exit }
  on && /^\|/ {
    split($0, c, "|")
    d = c[2]; e = c[3]
    gsub(/^[ \t]+|[ \t]+$/, "", d)
    gsub(sprintf("%c", 96), "", e)
    gsub(/^[ \t]+|[ \t]+$/, "", e)
    if (d == "design" && e != "") print e
  }
' "$RECORD") || cannot "${RECORD} could not be read"
[ -n "$recorded" ] \
  || cannot "${RECORD} carries no required-element record with a design row, so the design's section cannot be confirmed"
design_heading=$(extract heading read - - /dev/null)
case "
${recorded}
" in
  *"
${design_heading}
"*) ;;
  *) cannot "the design section this listing extracts, [${design_heading}], is not a design element in the record on ${RECORD} -- a renamed template section would list every later design without one" ;;
esac

[ -d "$archive" ] || cannot "no archive at ${archive}"
[ -r "$archive" ] && [ -x "$archive" ] || cannot "the archive at ${archive} cannot be read"

for f in "$archive"/*.spec.md "$archive"/*.design.md; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  b=${f##*/}
  case $b in
    *.spec.md) printf '%s\n' "${b%.spec.md}" ;;
    *) printf '%s\n' "${b%.design.md}" ;;
  esac
done | sort -u > "${WORK}/stems"

PLANS=0
DOCUMENTS=0
UNLISTED=''
DOC_KEY=''
DOC_NAME=''

# Invoked bare, because a subshell would discard the four globals it sets:
# DOC_KEY, DOC_NAME, DOCUMENTS and UNLISTED.
render_doc() { # <role> <stem> <out>
  local role=$1 stem=$2 out=$3 file why=''
  file="${archive}/${stem}.${role}.md"
  DOC_KEY=''
  DOC_NAME=missing
  if [ ! -e "$file" ] && [ ! -L "$file" ]; then
    extract "$role" missing "${role} missing" - /dev/null > "$out"
    return 0
  fi
  DOC_NAME="${stem}.${role}.md"
  DOCUMENTS=$((DOCUMENTS + 1))
  rm -f "${WORK}/key" "${WORK}/err"
  if [ ! -f "$file" ]; then
    why='it is not a regular file'
  elif [ ! -r "$file" ]; then
    why='it cannot be read'
  elif ! extract "$role" read "${role} ${stem}.${role}.md" - "$file" > "$out" 2> "${WORK}/awk-err"; then
    why=$(cat "${WORK}/err" 2>/dev/null)
    [ -n "$why" ] || why="it could not be read: $(cat "${WORK}/awk-err")"
  fi
  if [ -n "$why" ]; then
    UNLISTED="${UNLISTED}plan-archive: unlisted ${file}: ${why}
"
    extract "$role" unlisted "${role} ${stem}.${role}.md" "$why" /dev/null > "$out"
    return 0
  fi
  DOC_KEY=$(cat "${WORK}/key")
}

# Every write to standard output is checked: a listing cut short on a full
# volume or a closed descriptor would otherwise exit 0, the one status a reader
# takes as every plan listed.
write_failed() {
  printf 'plan-archive: cannot finish: writing %s to standard output failed\n' "$1" >&2
  exit 2
}

printf 'plan-archive: completed plans in %s\n' "$archive" \
  && printf 'plan-archive: a "---" line naming a section is followed by exactly the number of lines it states, whatever they contain\n' \
  || write_failed 'the header'
while IFS= read -r stem; do
  PLANS=$((PLANS + 1))
  render_doc spec "$stem" "${WORK}/spec.out"
  key=$DOC_KEY
  spec_name=$DOC_NAME
  render_doc design "$stem" "${WORK}/design.out"
  [ -n "$key" ] || key=$DOC_KEY
  design_name=$DOC_NAME
  case $stem in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]|[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) date=${stem%"${stem#??????????}"} ;;
    *) date=absent ;;
  esac
  printf '\n=== plan %s\n' "$stem" \
    && printf 'date: %s\n' "$date" \
    && printf 'key: %s\n' "${key:-absent}" \
    && printf 'spec: %s\n' "$spec_name" \
    && printf 'design: %s\n' "$design_name" \
    && cat "${WORK}/spec.out" "${WORK}/design.out" \
    || write_failed "plan ${stem}"
done < "${WORK}/stems"

printf '\n' || write_failed 'the trailer'
if [ -z "$UNLISTED" ]; then
  printf 'plan-archive: complete archive=%s plans=%s documents=%s\n' "$archive" "$PLANS" "$DOCUMENTS" \
    || write_failed 'the trailer'
  exit 0
fi
n_unlisted=$(printf '%s' "$UNLISTED" | awk 'END { print NR }')
trailer=$(printf 'plan-archive: incomplete archive=%s plans=%s documents=%s unlisted=%s\n%s' \
  "$archive" "$PLANS" "$DOCUMENTS" "$n_unlisted" "$UNLISTED")
printf '%s\n' "$trailer" || write_failed 'the trailer'
printf '%s\n' "$trailer" >&2
exit 2
