#!/usr/bin/env bash
# PostToolUse / PostToolUseFailure on Bash: record every covered gate in the session's
# loop ledger with the tree digest it ran against, and tell the calling agent. A repeat
# (same gate, arguments and digest) and a contradiction (same gate, artefact and digest,
# opposite verdict) are flagged at any distance and across agents. It never blocks:
# every path exits 0.
set -u

HERE=$( { cd -- "$(dirname -- "$0")" && pwd -P; } 2>/dev/null ) || exit 0
PLUGIN=${HERE%/hooks/lib}
LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"

# The guard runs before the source: a `.` that cannot open its file is a special-builtin
# error, which ends a POSIX shell before a trailing `|| exit 0` is reached.
G=; f="$HERE/gate-pattern.sh"; [ -r "$f" ] || exit 0; . "$f"; [ -n "$G" ] || exit 0
# Each segment is matched from its start, so a separator inside a quoted argument
# (`echo "x; bash t.sh"`) cannot make a gate the shell never runs.
G0='(^|[;&|(`])'
case $G in "$G0"*) G0="^${G#"$G0"}" ;; *) G0=$G ;; esac

if [ -r "$HERE/ledger-write.sh" ]; then
  . "$HERE/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi

in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$in" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
printf '%s' "$cmd" | grep -qE "$G|test|check|lint|verify" || exit 0

meta=$(printf '%s' "$in" | jq -r '[ (.session_id // "-"), (.tool_use_id // "-"), (.hook_event_name // "-"),
    (if (.agent_id | type) == "string" and .agent_id != "" then .agent_id else "main" end),
    (.cwd // "-") ] | map(gsub("\t"; " ")) | @tsv' 2>/dev/null) || exit 0
IFS=$'\t' read -r sid tuid ev agent pcwd <<<"$meta"
case $ev in
  PostToolUse) rcz=1 ;;
  PostToolUseFailure) rcz=0 ;;
  *) exit 0 ;;
esac

US=$'\037'
EFF=$PWD
[ "$pcwd" != - ] && [ -d "$pcwd" ] && EFF=$pcwd
EFF=$(cd -- "$EFF" 2>/dev/null && pwd -P) || exit 0
PLUGR=$(cd -- "$PLUGIN" 2>/dev/null && pwd -P) || PLUGR=

# One line per segment: the operator before it, the operator after it, the command
# text with assignments and redirections removed (what G is matched against, as the
# masking hook matches it), and the words with quotes removed and the variables this
# environment can expand expanded. Redirection targets are dropped so that an output
# file never becomes an argument whose content differs on every run.
segments() {
  LC_ALL=C awk -v US="$US" '
    BEGIN { RS = "\001" }
    function flush(nx) {
      if (seg ~ /^[ \t\n]*$/) { seg = ""; return }
      words(seg)
      if (nw > 0) printf "%s\t%s\t%s\t%s\n", prev, nx, rawj, expj
      prev = nx; seg = ""
    }
    function expand(t,   out, m, name, k) {
      out = ""
      while (match(t, /\$(\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)/)) {
        name = substr(t, RSTART + 1, RLENGTH - 1); gsub(/[{}]/, "", name)
        out = out substr(t, 1, RSTART - 1)
        out = out ((name in ENVIRON) ? ENVIRON[name] : substr(t, RSTART, RLENGTH))
        t = substr(t, RSTART + RLENGTH)
      }
      return out t
    }
    function words(t,   i, c, n, q, raw, ex, chunk, have, skipnext, k, rw) {
      nw = 0; rawj = ""; expj = ""; n = length(t); q = ""; raw = ""; ex = ""; chunk = ""; have = 0
      skipnext = 0
      for (i = 1; i <= n + 1; i++) {
        c = (i <= n) ? substr(t, i, 1) : " "
        if (q == "\047") { raw = raw c; if (c == "\047") q = ""; else ex = ex c; continue }
        if (q == "\"") {
          raw = raw c
          if (c == "\\" && i < n) { i++; raw = raw substr(t, i, 1); chunk = chunk substr(t, i, 1); continue }
          if (c == "\"") { q = ""; ex = ex expand(chunk); chunk = "" } else chunk = chunk c
          continue
        }
        if (c == "\\" && i < n) {
          i++; raw = raw c substr(t, i, 1); ex = ex expand(chunk) substr(t, i, 1); chunk = ""; have = 1; continue
        }
        if (c == "\047" || c == "\"") { ex = ex expand(chunk); chunk = ""; q = c; raw = raw c; have = 1; continue }
        if (c ~ /[ \t\n]/) {
          if (!have && raw == "") continue
          ex = ex expand(chunk); chunk = ""
          if (skipnext) skipnext = 0
          else if (nw == 0 && rawj == "" && raw ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { }
          else if (raw ~ /^[0-9]*(>>?|<|&>>?|>&|<&)$/) skipnext = 1
          else if (raw ~ /^[0-9]*(>>?|<|&>>?|>&|<&)/) { }
          else {
            gsub(/[\t\n]/, " ", ex); gsub(/[\t\n]/, " ", raw)
            rawj = rawj (nw ? " " : "") raw
            expj = expj (nw ? US : "") ex
            nw++
          }
          raw = ""; ex = ""; have = 0
          continue
        }
        raw = raw c; chunk = chunk c; have = 1
      }
    }
    {
      s = $0; n = length(s); q = ""; depth = 0; bt = 0; seg = ""; prev = "^"
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q == "\047") { seg = seg c; if (c == "\047") q = ""; continue }
        if (q == "\"") {
          seg = seg c
          if (c == "\\") { i++; seg = seg substr(s, i, 1); continue }
          if (c == "\"") q = ""
          continue
        }
        if (c == "\\") { seg = seg c substr(s, i + 1, 1); i++; continue }
        if (c == "\047" || c == "\"") { q = c; seg = seg c; continue }
        if (c == "`") { bt = !bt; seg = seg c; continue }
        if (c == "(") { depth++; seg = seg c; continue }
        if (c == ")") { if (depth > 0) depth--; seg = seg c; continue }
        if (depth > 0 || bt) { seg = seg c; continue }
        op = ""
        if (c == "\n" || c == ";") op = ";"
        else if (c == "&") {
          nx = substr(s, i + 1, 1); pv = substr(s, i - 1, 1)
          if (nx == "&") { op = "&&"; i++ }
          else if (pv == ">" || pv == "<" || nx == ">") { seg = seg c; continue }
          else op = "&"
        } else if (c == "|") {
          nx = substr(s, i + 1, 1)
          if (nx == "|") { op = "||"; i++ }
          else { op = "|"; if (nx == "&") i++ }
        }
        if (op == "") { seg = seg c; continue }
        flush(op)
      }
      flush("$")
    }'
}

NORM=
norm() {
  local p=$1 d full parent
  case $p in /*) ;; *) p=$EFF/$p ;; esac
  if [ -d "$p" ]; then
    full=$(cd -- "$p" 2>/dev/null && pwd -P) || full=$p
  elif [ -e "$p" ]; then
    d=$(cd -- "${p%/*}" 2>/dev/null && pwd -P) || d=${p%/*}
    full=$d/${p##*/}
  else
    parent=${p%/*}; NORM=${parent##*/}/${p##*/}
    return
  fi
  if [ -n "$TOPR" ] && { [ "$full" = "$TOPR" ] || [ "${full#"$TOPR"/}" != "$full" ]; }; then
    NORM=${full#"$TOPR"}; NORM=${NORM#/}; [ -n "$NORM" ] || NORM=.
  elif [ -n "$PLUGR" ] && [ "${full#"$PLUGR"/}" != "$full" ]; then
    NORM='${CLAUDE_PLUGIN_ROOT}/'${full#"$PLUGR"/}
  else
    NORM=$full
  fi
}

TOPR=; SELFLAG=; DIGEST=
set_repo() {
  local t
  t=$(git -C "$EFF" rev-parse --show-toplevel 2>/dev/null) || t=
  [ -n "$t" ] && t=$(cd -- "$t" 2>/dev/null && pwd -P)
  [ "$t" = "$TOPR" ] && [ -n "$t" ] && return
  TOPR=$t; SELFLAG=; DIGEST=
  [ -n "$TOPR" ] || return
  if [ -r "$TOPR/AGENTS.md" ]; then
    SELFLAG=$(LC_ALL=C awk '/^\*\*Selection flag:\*\*/ { sub(/^\*\*Selection flag:\*\*[ \t]*/, ""); gsub(/`/, "");
      sub(/[ \t].*/, ""); print; exit }' "$TOPR/AGENTS.md" 2>/dev/null)
    case $SELFLAG in none|*%*) SELFLAG= ;; esac
  fi
  if [ -r "$PLUGIN/scripts/tree-digest.sh" ]; then
    DIGEST=$(bash "$PLUGIN/scripts/tree-digest.sh" -C "$TOPR" 2>/dev/null < /dev/null) || DIGEST=
  fi
}

ARGS=(); ART=()
classify() {
  local w v h p i=0 n=$# sel=() paths=() modes=() vs=()
  local -a a=("$@")
  while [ "$i" -lt "$n" ]; do
    w=${a[$i]}; i=$((i + 1))
    if [ -n "$SELFLAG" ] && [ "$w" = "$SELFLAG" ] && [ "$i" -lt "$n" ]; then
      v=${a[$i]}; i=$((i + 1))
    elif [ -n "$SELFLAG" ] && [ "${w#"$SELFLAG"=}" != "$w" ]; then
      v=${w#"$SELFLAG"=}
    else
      v=
      case $w in /*) p=$w ;; *) p=$EFF/$w ;; esac
      if [ -n "$w" ] && [ -f "$p" ]; then
        norm "$w"; h=$(git hash-object --no-filters -- "$p" 2>/dev/null) || h=unreadable
        paths+=("file:${NORM}@${h:0:12}")
      elif [ -n "$w" ] && [ -d "$p" ]; then
        norm "$w"; paths+=("dir:${NORM}")
      else
        modes+=("mode:${w}")
      fi
      continue
    fi
    IFS=, read -r -a vs <<<"$v"
    for w in ${vs[@]+"${vs[@]}"}; do [ -n "$w" ] && sel+=("sel:${w}"); done
  done
  ART=()
  while IFS= read -r w; do [ -n "$w" ] && ART+=("$w"); done < <(
    printf '%s\n' ${paths[@]+"${paths[@]}"} ${sel[@]+"${sel[@]}"} | LC_ALL=C sort)
  ARGS=(${ART[@]+"${ART[@]}"} ${modes[@]+"${modes[@]}"})
}

json_array() { if [ $# -eq 0 ]; then printf '[]'; else printf '%s\n' "$@" | jq -R . | jq -sc .; fi; }

segs=$(printf '%s' "$cmd" | segments 2>/dev/null) || exit 0
[ -n "$segs" ] || exit 0

PREV=(); NEXT=(); GATE=(); GARGS=(); GART=(); GREPO=(); GDIG=()
allamp=1; idx=0
while IFS=$'\t' read -r pv nx raw exp; do
  PREV[$idx]=$pv; NEXT[$idx]=$nx; GATE[$idx]=
  [ "$pv" = '^' ] || [ "$pv" = '&&' ] || allamp=0
  [ "$nx" != '&' ] || allamp=0
  IFS=$US read -r -a W <<<"$exp"
  while [ ${#W[@]} -gt 0 ] && [ "${W[0]#(}" != "${W[0]}" ]; do
    W[0]=${W[0]#(}; [ -n "${W[0]}" ] || W=("${W[@]:1}")
  done
  if [ ${#W[@]} -eq 0 ]; then idx=$((idx + 1)); continue; fi
  if [ "${W[0]}" = cd ]; then
    t=${W[1]:-$HOME}; case $t in -P|-L) t=${W[2]:-$HOME} ;; esac
    case $t in /*) ;; *) t=$EFF/$t ;; esac
    [ -d "$t" ] && EFF=$(cd -- "$t" 2>/dev/null && pwd -P)
    idx=$((idx + 1)); continue
  fi
  raw=${raw#"${raw%%[!( ]*}"}
  kind=
  if printf '%s' "$raw" | grep -qE "$G0"; then
    case ${W[0]} in bash|sh|zsh) kind=shell ;; *) kind=tool ;; esac
  elif case ${W[0]} in */*) true ;; *) false ;; esac \
    && case ${W[0]} in *test*|*check*|*lint*|*verify*) true ;; *) false ;; esac; then
    case ${W[0]} in /*) p=${W[0]} ;; *) p=$EFF/${W[0]} ;; esac
    [ -f "$p" ] && kind=direct
  fi
  if [ -z "$kind" ]; then idx=$((idx + 1)); continue; fi
  set_repo
  gate=; rest=()
  j=1; while [ "$j" -lt ${#W[@]} ] && [ "${W[$j]#-}" != "${W[$j]}" ]; do j=$((j + 1)); done
  case $kind in
    shell)
      if [ "$j" -lt ${#W[@]} ]; then norm "${W[$j]}"; gate=$NORM; rest=("${W[@]:$((j + 1))}"); fi ;;
    tool)
      gate=${W[0]}; rest=("${W[@]:1}")
      if [ "$j" -lt ${#W[@]} ]; then
        gate="${W[0]} ${W[$j]}"; rest=("${W[@]:1:$((j - 1))}" "${W[@]:$((j + 1))}")
      fi ;;
    direct)
      # Checked in means inside the repository or the plugin; a system binary such as
      # /usr/bin/test normalises to an absolute path and is not a gate.
      norm "${W[0]}"
      case $NORM in /*) ;; *) gate=$NORM; rest=("${W[@]:1}") ;; esac ;;
  esac
  if [ -n "$gate" ]; then
    classify ${rest[@]+"${rest[@]}"}
    GATE[$idx]=$gate
    GARGS[$idx]=$(json_array ${ARGS[@]+"${ARGS[@]}"})
    GART[$idx]=$(json_array ${ART[@]+"${ART[@]}"})
    GREPO[$idx]=$TOPR; GDIG[$idx]=$DIGEST
  fi
  idx=$((idx + 1))
done <<<"$segs"
last=$((idx - 1))
[ "$last" -ge 0 ] || exit 0

verdict() {
  local i=$1 k
  if [ "$allamp" = 1 ] && [ "$rcz" = 1 ]; then printf true; return; fi
  if [ "$i" -ne "$last" ] || [ "${NEXT[$i]}" = '&' ]; then printf null; return; fi
  case ${PREV[$i]} in
    '^'|';'|'&') if [ "$rcz" = 1 ]; then printf true; else printf false; fi ;;
    '&&')
      if [ "$rcz" = 1 ]; then printf true; return; fi
      k=$((i - 1))
      while [ "$k" -ge 0 ]; do
        [ -n "${GATE[$k]}" ] && { printf null; return; }
        [ "${PREV[$k]}" = '&&' ] || break
        k=$((k - 1))
      done
      printf false ;;
    *) printf null ;;
  esac
}

ledger=
if [ "$sid" != - ] && [ -n "$sid" ]; then
  ledger="${LEDGER_DIR}/${sid}.jsonl"
  mkdir -p "$LEDGER_DIR" 2>/dev/null || { harness_ledger_report_once "$sid" "$ledger"; ledger=; }
fi
if [ "$rcz" = 1 ]; then status=zero; else status=non-zero; fi

ctx=
i=0
while [ "$i" -le "$last" ]; do
  if [ -z "${GATE[$i]:-}" ]; then i=$((i + 1)); continue; fi
  ok=$(verdict "$i")
  repo=${GREPO[$i]}; dig=${GDIG[$i]}
  prior=
  if [ -n "$ledger" ] && [ -n "$repo" ] && [ -n "$dig" ] && [ -f "$ledger" ]; then
    prior=$(jq -Rnr --arg repo "$repo" --arg g "${GATE[$i]}" --arg d "$dig" \
        --argjson a "${GARGS[$i]}" --argjson art "${GART[$i]}" --argjson ok "$ok" '
      [inputs | fromjson? | select(type == "object" and .kind == "gate" and .repo == $repo
        and .gate == $g and .digest == $d)] as $rows
      | ([$rows[] | select(.artefact == $art and $ok != null and .ok != null and .ok != $ok)] | last) as $c
      | ([$rows[] | select(.args == $a)] | last) as $r
      | if $c != null then ["contradiction", $c]
        elif $r != null then ["repeat", $r] else empty end
      | [.[0], (.[1].tool_use_id // "-"), (.[1].ts // "-"), (.[1].agent_id // "-"),
         (.[1].ok | tostring), (.[1].command // "-")] | map(gsub("[\t\n]"; " ")) | @tsv
    ' < "$ledger" 2>/dev/null) || prior=
  fi
  signal=; ptu=; pts=; pag=; pok=; pcmd=
  [ -n "$prior" ] && IFS=$'\t' read -r signal ptu pts pag pok pcmd <<<"$prior"
  if [ -n "$ledger" ]; then
    row=$(jq -nc --arg g "${GATE[$i]}" --argjson a "${GARGS[$i]}" --argjson art "${GART[$i]}" \
        --arg repo "$repo" --arg d "$dig" --argjson ok "$ok" --arg ag "$agent" --arg tu "$tuid" \
        --arg cwd "$pcwd" --arg c "$cmd" --arg s "$signal" --arg ptu "$ptu" --arg pts "$pts" --arg pag "$pag" '
      {ts: (now | todate), kind: "gate", gate: $g, args: $a, artefact: $art,
       repo: (if $repo == "" then null else $repo end), digest: (if $d == "" then null else $d end),
       ok: $ok, agent_id: $ag, tool_use_id: $tu, cwd: $cwd, command: $c,
       signal: (if $s == "" then null else $s end)}
      + (if $s == "" then {} else {prior_tool_use_id: $ptu, prior_ts: $pts, prior_agent_id: $pag} end)
    ' 2>/dev/null) || row=
    [ -z "$row" ] || harness_ledger_append "$sid" "$ledger" "$row" || true
  fi
  line="[gate-record] ${GATE[$i]} exited ${status}; tree digest ${dig:-none (not in a repository)}."
  case $signal in
    contradiction)
      line="$line CONTRADICTION: the same gate over the same artefact and the same tree digest recorded ok=${pok}"
      line="$line at ${pts} (agent ${pag}, tool_use_id ${ptu}): \`${pcmd}\` -- now \`${cmd}\`." ;;
    repeat)
      line="$line REPEAT: the same gate with the same arguments already ran over this tree digest"
      line="$line at ${pts} (agent ${pag}, tool_use_id ${ptu}): \`${pcmd}\`." ;;
  esac
  ctx=${ctx:+$ctx$'\n'}$line
  i=$((i + 1))
done

[ -n "$ctx" ] || exit 0
jq -nc --arg e "$ev" --arg c "$ctx" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}' 2>/dev/null
exit 0
