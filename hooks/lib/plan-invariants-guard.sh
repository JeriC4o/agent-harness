#!/usr/bin/env bash
#
# PreToolUse refusal on the pages that define or enforce a required element of a
# spec or a design. Registered on two matchers: the file-editing tools and the
# shell.
#
# Run:  fed a PreToolUse payload on stdin; emits an `ask` decision or nothing.
# Exit: always 0. A malformed payload, an absent jq or an unreadable field
#       yields silence, which defers to the normal permission flow rather than
#       blocking work on a guard that could not read its own input.
#
# THE REFUSAL IS PAGE-WIDE BY DECISION. Every edit to a protected page is put to
# the author, inspecting nothing about what the edit touches. A narrower
# content-keyed refusal was considered and rejected with the interruption cost
# named and accepted, so the breadth of PROTECTED is a requirement rather than a
# detail: every surplus member is a recurring interruption.
#
# THE PAGE LIST IS DATA. scripts/check-plan-invariants.sh extracts the covered
# set from PROTECTED below and compares it against the table in
# docs/plan-invariants.md in both directions, so an unguarded route and a
# surplus interruption are both reported rather than sitting there unnoticed.
#
# WHY THE SHELL ARM HAS TWO CONDITIONS. A command must carry a write CONSTRUCT
# and the resolved repo-relative path of one of that construct's write operands
# must be protected. Each answers a different escape and dropping either breaks
# the arm in its own direction. Resolution alone fires on a READ, and in this
# repository that is the common case rather than a corner one: the ambient
# working style reads through the shell, so an orientation read of these pages
# arrives as `cat`, `sed -n` or `grep`. A refusal that loud is the kind that
# gets switched off, which costs the whole protection rather than one prompt.
# A spelled-path match alone is walked around by `cd <dir> && <edit>`, which is
# permitted house style here; a bare basename over-fires on fourteen pages that
# mandate nothing, because `SKILL.md` and `reference.md` are not unique.
#
# WRITE CONSTRUCTS, NOT A READ-ONLY ALLOWLIST. The alternative was weighed on
# its failure DIRECTION. A read-only allowlist misses an unlisted reader and the
# cost is an interruption on a read, over a set that grows by one entry per new
# reading tool. A write-construct list misses an unlisted writer and the cost is
# that one writer escaping the refusal.
#
# THE SIX SILENT FORMS OF THE WRITE ARM, every one of them under-firing.
# Three never spell the protected path as a literal token, so no resolution
# rule reaches them: a glob, a command substitution that produces the path, and
# a target list read from a file. One follows from the write condition: a writer
# whose construct is not listed. Two follow from operand rules kept deliberately
# narrow -- an interpreter script's variable-indirected writer, and a directory
# change that is not a leading prefix. The escaped separator that used to be the
# seventh is closed: the neutralisation reaches a separator a BACKSLASH escapes
# outside any quoted span, as well as its quoted cousin. All six are asserted in
# the suite rather than claimed here.
#
# Tests: hooks/lib/test-plan-invariants-guard.sh

set -ufo pipefail

# [protected]
PROTECTED='agents/spec-writer.md
agents/design.md
agents/design-review.md
skills/redline-fold/SKILL.md
skills/task/SKILL.md
skills/task/reference.md
scripts/check-redline.sh'

HERE=$(cd -- "$(dirname -- "$0")" && pwd) || exit 0
"${HERE}/harness-managed.sh" || exit 0

in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

pd=$(cd -- "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P) || exit 0
[ -n "$pd" ] || exit 0

fp=$(printf '%s' "$in" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
cmd=$(printf '%s' "$in" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

# Resolved physically, because a protected page reached through a symlinked or
# `..`-threaded spelling is the same page.
rel_of() {
  p=$1
  [ -n "$p" ] || { printf ''; return 0; }
  case "$p" in /*) ;; *) p="${pd}/${p}" ;; esac
  d=${p%/*}; b=${p##*/}
  [ "$d" = "$p" ] && d=.
  rd=$(cd -- "$d" 2>/dev/null && pwd -P) || rd=""
  [ -n "$rd" ] || rd=$d
  full="${rd}/${b}"
  case "$full" in
    "$pd"/*) printf '%s' "${full#"$pd"/}" ;;
    *) printf '' ;;
  esac
}

is_protected() {
  [ -n "${1:-}" ] || return 1
  for q in $PROTECTED; do [ "$1" = "$q" ] && return 0; done
  return 1
}

HITS=""
record_hit() {
  r=$(rel_of "$1")
  is_protected "$r" || return 0
  case " ${HITS} " in *" ${r} "*) return 0 ;; esac
  HITS="${HITS:+${HITS} }${r}"
}

emit() { # <marker-and-reason>
  jq -nc --arg r "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask",
                           permissionDecisionReason: $r}}' 2>/dev/null || exit 0
  exit 0
}

reason_for() { # <lead> <pages>
  r="${CLAUDE_PLUGIN_ROOT:-}"
  a=$("${HERE}/plugin-ref.sh" docs/plan-invariants.md 2>/dev/null)
  [ -n "$a" ] || a="${r:+$r/}docs/plan-invariants.md — correct operation of the plugin requires read access to the plugin directory${r:+ $r}"
  printf '%s -- %s. That page defines or enforces a required element of a spec or a design, so EVERY edit to it is put to you, whatever the edit touches: a typo fix in an unrelated paragraph is refused exactly as a change to the required-element set is. ALLOWING this call lets the edit proceed, which is the authorisation route rather than a way round it -- installing or repairing this protection never requires switching it off. What makes a page a member, the seven members with a reason each, and the near misses deliberately left out: %s.' \
    "$1" "$2" "$a"
}

if [ -n "$fp" ]; then
  record_hit "$fp"
  [ -n "$HITS" ] || exit 0
  emit "$(reason_for 'CONFIRM: this edit targets a protected plan-invariants page' "$HITS")"
fi

[ -n "$cmd" ] || exit 0

# Every form this arm reaches spells a guarded basename as a literal token, so
# a command carrying none of them cannot be one of those forms. The forms that
# hide the basename -- a glob, a substitution, a list read from a file -- are the
# stated residual, not something this fast path gives up.
seen_basename=0
for q in $PROTECTED; do
  case "$cmd" in *"${q##*/}"*) seen_basename=1; break ;; esac
done
[ "$seen_basename" = 1 ] || exit 0

# THE EIGHT SEGMENTATION CHARACTERS, as data, because three steps read them: the
# neutralisation below, the padding after it and the translation that feeds the
# segment loop. Spelled once so the three cannot be edited apart -- a character
# present in one and not the others reopens exactly the hole the neutralisation
# closes. The suite reads this assignment and sweeps every character in it, in
# both the quoted spelling and the escaped one.
SEGMENT_SEPARATORS=';&|(){}`'

# The command as ONE line first, because the walk below carries quote state
# across the whole of it: a newline inside a quoted span is a separator only to
# the translation that feeds the segment loop, and the walk has to have
# neutralised it before then.
joined=$(printf '%s' "$cmd" | tr '\n' ';')

# A SEPARATOR INSIDE A QUOTED SPAN IS NOT A SEPARATOR, and by segmentation time
# nothing recorded that it was quoted: the padding below replaces both quote
# characters with spaces, and the translation feeding the segment loop cuts on
# all eight. So `sed -i '' 's|a|b|g' <protected page>` put its in-place writer
# and its resolved path in different segments, each missing the other, and the
# arm went silent on every one of the eight and in both quote spellings.
# Neutralised here, while the quotes are still there to read, leaving the
# quoting itself intact and the eight characters meaningful wherever the shell
# would treat them as a separator. An inert character rather than a deletion,
# so the span stays the single token the shell would make of it.
#
# A SEPARATOR A BACKSLASH ESCAPES, OUTSIDE ANY QUOTED SPAN, IS NOT ONE EITHER,
# and the same walk closes it: the backslash is tracked left to right, so an
# escaped backslash followed by a real separator still segments. Inside a quoted
# span no escape rule is needed, because every separator there is neutralised
# already.
#
# THE WALK RUNS BEFORE THE PADDING, AND THAT ORDER IS THE WHOLE OF WHY THE
# ESCAPED FORM CLOSES. Measured with the walk after the padding instead: seven
# of the eight escaped forms closed and the statement separator stayed silent,
# because the padding had already put a space between the backslash and the
# character it escaped.
#
# Shrinking the separator set was the ruled-out repair: those characters are
# what makes a compound command segment at all, and the silences this guard
# deliberately keeps -- a read beside a write, a directory change that is not a
# leading prefix -- are read off that same segmentation.
#
# The fallback is to the UNTOUCHED text, never to an empty string: an awk that
# is absent or that fails would otherwise empty `padded` and silence the whole
# write arm, which is a wider silence than the one being closed.
neutralised=$(printf '%s' "$joined" | awk -v seps="$SEGMENT_SEPARATORS" '
{
  out = ""; q = ""; esc = 0
  for (i = 1; i <= length($0); i++) {
    c = substr($0, i, 1)
    if (esc) { esc = 0; if (index(seps, c) > 0) c = "_" }
    else if (q == "") {
      if (c == "\\") esc = 1
      else if (c == "\"" || c == "\47") q = c
    }
    else if (c == q) q = ""
    else if (index(seps, c) > 0) c = "_"
    out = out c
  }
  print out
}' 2>/dev/null) || neutralised=""
[ -n "$neutralised" ] && joined=$neutralised

# Separators are padded before the prefix walk so `cd <dir>; <edit>` and
# `cd <dir>&&<edit>` present the directory as a token of its own, the way the
# spaced spelling already does.
flat=$(printf '%s' "$joined" | sed -e 's/;/ ; /g' -e 's/&&/ \&\& /g')

# A leading directory change is resolved because `cd <dir> && <edit>` is
# permitted house style here and spells a real path -- just not the one this
# guard holds. A change spelled anywhere but the front is the named residual.
dirpfx=""
rest=$flat
while : ; do
  rest=${rest#"${rest%%[![:space:]]*}"}
  case "$rest" in 'cd '*|$'cd\t'*) ;; *) break ;; esac
  tail=${rest#cd}
  tail=${tail#"${tail%%[![:space:]]*}"}
  tok=${tail%%[[:space:]]*}
  tok=${tok#\"}; tok=${tok#\'}; tok=${tok%\"}; tok=${tok%\'}
  [ -n "$tok" ] || break
  after=${tail#"${tail%%[[:space:]]*}"}
  after=${after#"${after%%[![:space:]]*}"}
  case "$after" in
    '&&'*) after=${after#'&&'} ;;
    ';'*) after=${after#';'} ;;
    *) break ;;
  esac
  case "$tok" in /*) dirpfx=$tok ;; *) dirpfx="${dirpfx:+${dirpfx}/}${tok}" ;; esac
  rest=$after
done

join_dir() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s' "${dirpfx:+${dirpfx}/}$1" ;; esac; }

# [path-shaped]
path_shaped() {
  case "${1:-}" in
    ''|-*|@*@) return 1 ;;
    *=*) return 1 ;;
    */*|*.*) return 0 ;;
  esac
  return 1
}

# [padded]
padded=$(printf '%s' "$rest" | sed -e 's/>>/ @APPEND@ /g' -e 's/>/ @REDIR@ /g' -e "s/[\"']/ /g")

# [writer-words]
WRITER_WORDS=' patch truncate shred rm install ed tee '
GIT_WRITE_SUBS=' checkout restore rm mv '
# [inplace-cmds]
INPLACE_CMDS=' sed gsed perl ruby '

# [has-write-construct]
has_write_construct() { # <text>
  case "$1" in *'@REDIR@'*|*'@APPEND@'*) return 0 ;; esac
  for w in $WRITER_WORDS $INPLACE_CMDS dd mv cp; do
    case " $1 " in *" $w "*) return 0 ;; esac
  done
  return 1
}

# A loop word list is where the paths are spelled when the body's redirect
# target is a variable, which is the only place `for f in a b; do ... >> $f`
# names them at all.
case "$padded" in
  *' for '*' in '*|'for '*' in '*)
    body=${padded#*' do '}
    if [ "$body" != "$padded" ] && has_write_construct "$body"; then
      lst=${padded#*' in '}
      lst=${lst%%' do '*}
      lst=${lst//[;&]/ }
      for t in $lst; do
        path_shaped "$t" && record_hit "$(join_dir "$t")"
      done
    fi
    ;;
esac

while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  set -- $seg
  [ $# -gt 0 ] || continue

  prev=""
  for t in "$@"; do
    case "$prev" in
      '@REDIR@'|'@APPEND@') path_shaped "$t" && record_hit "$(join_dir "$t")" ;;
    esac
    prev=$t
  done

  words=""
  skip_next=0
  for t in "$@"; do
    [ "$skip_next" = 1 ] && { skip_next=0; continue; }
    case "$t" in
      '@REDIR@'|'@APPEND@') skip_next=1; continue ;;
    esac
    words="${words:+${words} }${t}"
  done
  set -- $words
  [ $# -gt 0 ] || continue

  c=${1##*/}
  shift
  sub=""
  if [ "$c" = "git" ]; then
    for t in "$@"; do case "$t" in -*) ;; *) sub=$t; break ;; esac; done
    case "$GIT_WRITE_SUBS" in *" $sub "*) c="git-write" ;; *) c="git-read" ;; esac
  fi

  inplace=0
  case "$INPLACE_CMDS" in
    *" $c "*)
      for t in "$@"; do
        case "$t" in
          --in-place|--in-place=*) inplace=1 ;;
          -[A-Za-z]*) case "$t" in *i*) inplace=1 ;; esac ;;
        esac
      done
      ;;
  esac

  case "$c" in
    tee|patch|truncate|shred|rm|install|ed|git-write)
      for t in "$@"; do path_shaped "$t" && record_hit "$(join_dir "$t")"; done ;;
    dd)
      for t in "$@"; do
        case "$t" in of=?*) record_hit "$(join_dir "${t#of=}")" ;; esac
      done ;;
    mv|cp)
      dest=""
      for t in "$@"; do case "$t" in -t) dest="PENDING" ;; -t?*) dest=${t#-t} ;; --target-directory=*) dest=${t#--target-directory=} ;; *) [ "$dest" = "PENDING" ] && dest=$t ;; esac; done
      if [ -n "$dest" ] && [ "$dest" != "PENDING" ]; then
        skip=0
        for t in "$@"; do
          [ "$skip" = 1 ] && { skip=0; continue; }
          case "$t" in -t) skip=1; continue ;; -*) continue ;; esac
          [ "$t" = "$dest" ] && continue
          path_shaped "$t" && record_hit "$(join_dir "${dest%/}/${t##*/}")"
        done
      else
        last=""
        for t in "$@"; do path_shaped "$t" && last=$t; done
        [ -n "$last" ] && record_hit "$(join_dir "$last")"
      fi ;;
  esac

  if [ "$inplace" = 1 ]; then
    for t in "$@"; do path_shaped "$t" && record_hit "$(join_dir "$t")"; done
  fi
done <<EOF
$(printf '%s' "$padded" | tr "$SEGMENT_SEPARATORS" '\n\n\n\n\n\n\n\n')
EOF

# The interpreter construct. Only the path-shaped tokens inside the write call's
# OWN argument list count. The wider rule -- every path-shaped token in the
# script -- was rejected on a measurement: reading a method page with an
# interpreter script and writing a scratch artefact is this repository's
# dominant analysis idiom, and under the wider rule every such read of a
# protected page is refused. What the wider rule bought was the
# variable-indirected writer, which is given up to the residual instead.
case "$flat" in
  *'<<'*) interp=1 ;;
  *) interp=0 ;;
esac
if [ "$interp" = 0 ]; then
  for i in python3 python perl ruby node; do
    case "$flat" in
      *"$i "*'-c'*|*"$i "*'-e'*) interp=1; break ;;
    esac
  done
fi

if [ "$interp" = 1 ]; then
  while IFS= read -r spanline; do
    [ -n "$spanline" ] || continue
    for t in $(printf '%s' "$spanline" | tr -c 'A-Za-z0-9._/-' ' '); do
      path_shaped "$t" && record_hit "$(join_dir "$t")"
    done
  done <<EOF
$(printf '%s' "$cmd" | awk '
function arglist(s, op,   depth, i, ch) {
  depth = 0
  for (i = op; i <= length(s); i++) {
    ch = substr(s, i, 1)
    if (ch == "(") depth++
    else if (ch == ")") { depth--; if (depth == 0) return substr(s, op + 1, i - op - 1) }
  }
  return ""
}
function matching_open(s, cl,   depth, i, ch) {
  depth = 0
  for (i = cl; i >= 1; i--) {
    ch = substr(s, i, 1)
    if (ch == ")") depth++
    else if (ch == "(") { depth--; if (depth == 0) return i }
  }
  return 0
}
function emit_span(sp,   t) { t = sp; gsub(/[\n\r]/, " ", t); if (t != "") print t }
{ s = s $0 "\n" }
END {
  pos = 1
  while (1) {
    i = match(substr(s, pos), /open[ \t]*\(/)
    if (i == 0) break
    st = pos + i - 1
    pre = (st == 1) ? " " : substr(s, st - 1, 1)
    op = st + RLENGTH - 1
    if (pre !~ /[A-Za-z0-9_.]/) {
      a = arglist(s, op)
      if (a ~ /["\x27][rbt]*[wax+][rbt+]*["\x27]/) emit_span(a)
    }
    pos = op + 1
  }
  pos = 1
  while (1) {
    i = match(substr(s, pos), /\.write_text[ \t]*\(/)
    if (i == 0) break
    st = pos + i - 1
    cl = 0
    for (j = st - 1; j >= 1; j--) {
      c = substr(s, j, 1)
      if (c == ")") { cl = j; break }
      if (c != " " && c != "\t") break
    }
    if (cl > 0) {
      op2 = matching_open(s, cl)
      if (op2 > 0) emit_span(substr(s, op2 + 1, cl - op2 - 1))
    }
    pos = st + 1
  }
  pos = 1
  while (1) {
    i = match(substr(s, pos), /(os\.rename|shutil\.move)[ \t]*\(/)
    if (i == 0) break
    st = pos + i - 1
    op3 = st + RLENGTH - 1
    emit_span(arglist(s, op3))
    pos = op3 + 1
  }
}
')
EOF
fi

[ -n "$HITS" ] || exit 0
emit "$(reason_for 'CONFIRM: this command writes to a protected plan-invariants page' "$HITS")"
