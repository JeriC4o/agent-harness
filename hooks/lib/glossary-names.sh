#!/usr/bin/env bash
#
# Print the names the glossary holds, one per line, tab-separated:
#   canonical <name>      <name>       <line>
#   other     <name>      <canonical>  <line>
#   retired   <name>      -            <line>
#   defined   <canonical> <page>       <line>  <heading>
#   planned   <canonical> -            <line>
#
# Run:  glossary-names.sh [<glossary page>]   (default: docs/glossary.md beside this plugin)
# Exit: 0 printed; 2 cannot read the page, a malformed entry, or no names -- and then nothing
#       on stdout, never a partial list.
#
# ONE SOURCE. Every check that refuses a listed name reads it through this script, so the
# page is the only list. A malformed row stops the whole read rather than being skipped: a
# check working from a list with a row silently missing would pass the name that row held.
#
# LC_ALL=C because the page's dash and section sign are matched as bytes; under a UTF-8
# locale some awks count them as one character and the heading offset shifts.

set -uo pipefail

PAGE=${1:-$(cd -- "$(dirname -- "$0")/../.." && pwd)/docs/glossary.md}
[ -r "$PAGE" ] || { printf 'glossary-names: cannot read %s\n' "$PAGE" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { printf 'glossary-names: awk is not on PATH\n' >&2; exit 2; }

LC_ALL=C awk -F'|' -v page="$PAGE" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function bad(why) { printf "glossary-names: %s:%d: %s\n", page, NR, why > "/dev/stderr"; failed = 1; exit 2 }
function emit(s) { out = out s "\n" }
/^\| Canonical name \| Other names \| What it is \| What it does \| Defined at \|$/ { mode = "entry"; next }
/^\| Retired name \| What it named \|$/ { mode = "retired"; next }
!/^\|/ { mode = ""; next }
/^\|[-| :]+\|$/ { next }
mode == "entry" {
  if (NF != 7) bad("an entry row needs exactly five cells")
  name = trim($2); others = trim($3); at = trim($6)
  if (name == "" || name ~ /["`]/) bad("an entry needs a plain canonical name")
  if (trim($4) == "" || trim($5) == "") bad("entry \"" name "\" lacks what it is or what it does")
  emit("canonical\t" name "\t" name "\t" NR); names++
  if (others != "\342\200\224") {
    rest = others
    while (rest != "") {
      if (!match(rest, /^"[^"]+"/)) bad("entry \"" name "\": other names are double-quoted and comma-separated, or a dash")
      emit("other\t" substr(rest, 2, RLENGTH - 2) "\t" name "\t" NR); names++
      rest = substr(rest, RLENGTH + 1)
      if (rest != "" && !sub(/^, /, "", rest)) bad("entry \"" name "\": other names are separated by a comma and a space")
    }
  }
  sep = "` \302\247 "
  if (at == "planned") emit("planned\t" name "\t-\t" NR)
  else if (at ~ /^`[^`]+` \302\247 ./) {
    i = index(at, sep)
    emit("defined\t" name "\t" substr(at, 2, i - 2) "\t" NR "\t" substr(at, i + length(sep)))
  } else bad("entry \"" name "\": defined at is a backticked page, the section sign and a heading, or planned")
  next
}
mode == "retired" {
  if (NF != 4) bad("a retired-name row needs exactly two cells")
  name = trim($2)
  if (name == "" || trim($3) == "") bad("a retired name needs what it named")
  emit("retired\t" name "\t-\t" NR); names++
  next
}
END {
  if (failed) exit 2
  if (names == 0) { printf "glossary-names: %s yields no names\n", page > "/dev/stderr"; exit 2 }
  printf "%s", out
}
' "$PAGE"
