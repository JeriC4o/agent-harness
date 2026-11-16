#!/usr/bin/env bash
#
# Read what the agent writes to a person for names the glossary lists and for
# words a person cannot follow, at the three moments the host allows.
#
# Run:  plain-words.sh question   PreToolUse on the question tool
#       plain-words.sh post       PreToolUse on Bash; reads only a posting command
#                                 the profile's Posting commands row declares
#       plain-words.sh turn-end   Stop; the main agent's chat text of the turn
# Exit: always 0. A refusal, a restatement and the notice travel in the JSON answer.
#
# TWO READINGS SIDE BY SIDE. The listed names are matched outside quotation and code
# marks, through the glossary's own reader; a model reads the text with the glossary
# for three breaches. The model never reads a text the names were not matched against.
#
# THE MODEL CANNOT HOLD THE AGENT AWAY FROM THE PERSON. After each refusal made by the
# model's reading alone, only the next question or post in that turn skips the model's
# reading; a later one is read and refusable again. A listed name used as a term is
# refused every time, because the agent can always remove it. Chat is restated at most
# once a turn.
#
# A COULD-NOT-RUN IS NEVER A PASS. When the names or the model cannot be read the text
# goes through, the record says could-not-run with any listed name found beside it, and
# the person is told once a session.
#
# ITS OWN RECORDS ARE ITS MEMORY. Each hook run is its own process, so whether the
# previous question was refused, whether this turn was restated and whether the person
# was told live in the plain-words rows of the session ledger; its turn-end row bounds a
# turn.
#
# Written for bash 3.2: an empty array is never expanded bare under set -u.

set -uo pipefail

[ -z "${HARNESS_MODEL_CALL:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

HERE=$( { cd -- "$(dirname -- "$0")" && pwd; } 2>/dev/null ) || exit 0
PAGE=${HARNESS_GLOSSARY_PAGE:-${HERE}/../../docs/glossary.md}
READER="${HERE}/glossary-names.sh"
MODEL=${HARNESS_PLAIN_WORDS_MODEL:-haiku}
LIMIT=${HARNESS_PLAIN_WORDS_TIMEOUT:-40}
LEDGER_DIR=${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}

if [ -r "${HERE}/ledger-write.sh" ]; then
  . "${HERE}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
fi

MOMENT=${1:-}
case $MOMENT in question|post|turn-end) ;; *) exit 0 ;; esac
IN=$(cat 2>/dev/null) || exit 0
[ -n "$IN" ] || exit 0
SID=$(printf '%s' "$IN" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
[ -n "$SID" ] || exit 0
SAFE=$(printf '%s' "$SID" | tr -c 'A-Za-z0-9._-' '_')
LEDGER="${LEDGER_DIR}/${SAFE}.jsonl"
PROJECT=${CLAUDE_PROJECT_DIR:-$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null)}
[ -n "$PROJECT" ] || PROJECT=$PWD

WORK=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$WORK"' EXIT INT TERM

load_own() {
  : > "$WORK/own"
  [ -s "$LEDGER" ] && jq -c 'select(.kind? == "plain-words")' "$LEDGER" > "$WORK/own" 2>/dev/null
  return 0
}
own_turn() {
  awk '/"moment":"turn-end"/ { n = 0; delete r; next } { r[++n] = $0 }
       END { for (i = 1; i <= n; i++) print r[i] }' "$WORK/own"
}
told() { grep -q '"notice":true' "$WORK/own"; }

record() { # <outcome> <by> <model state> <names json> <model json> <notice> [<reason>]
  local row
  row=$(jq -nc --arg m "$MOMENT" --arg o "$1" --arg b "$2" --arg s "$3" \
          --argjson n "$4" --argjson f "$5" --argjson t "$6" --arg r "${7:-}" \
    '{ts: (now|todate), kind: "plain-words", moment: $m, outcome: $o, by: $b, model_state: $s,
      names: $n, model: $f, notice: $t} + (if $r == "" then {} else {reason: $r} end)' 2>/dev/null) || return 0
  mkdir -p "$LEDGER_DIR" 2>/dev/null
  harness_ledger_append "$SID" "$LEDGER" "$row" || true
}

NOTICE_HEAD='What the agent writes to you is not being checked for words you cannot follow in this session'
notice_json() { jq -nc --arg t "${NOTICE_HEAD}: $1." '{systemMessage: $t}'; }

# Sets NAMES_STATE (read | cannot) and NAMES, the listed names found outside quotation
# and code marks as a JSON array.
names_found() { # <text file>
  NAMES='[]'; NAMES_STATE=cannot
  bash "$READER" "$PAGE" > "$WORK/names" 2>/dev/null || return 0
  NAMES=$(jq -n --rawfile text "$1" --rawfile rows "$WORK/names" '
    def esc: gsub("(?<c>[.^$*+?()\\[\\]{}|\\\\/])"; "\\\(.c)");
    ($text
     | gsub("```[\\s\\S]*?```"; " ")
     | gsub("`[^`\\n]*`"; " ")
     | gsub("\"[^\"\\n]*\""; " ")
     | gsub("\u201c[^\u201d\\n]*\u201d"; " ")
     | gsub("\u00ab[^\u00bb\\n]*\u00bb"; " ")) as $plain
    | [ $rows | split("\n")[] | select(length > 0) | split("\t")
        | select(.[0] == "other" or .[0] == "retired")
        | {name: .[1], canonical: (if .[0] == "other" then .[2] else null end)} as $n
        | ($n.name | ascii_downcase | [splits("[\\s-]+")] | map(select(length > 0) | esc) | join("[\\s-]+")) as $re
        | select($plain | test("(?<![A-Za-z0-9_])" + $re + "(?:s|es|ed|d|ing|\u0027s)?(?![A-Za-z0-9_])"; "i"))
        | $n ] | unique_by(.name | ascii_downcase)' 2>/dev/null) || { NAMES='[]'; return 0; }
  NAMES_STATE=read
}

# Sets MODEL_STATE (read | cannot), MODEL_FINDINGS (a JSON array) and MODEL_WHY.
# Called bare, never inside a command substitution, so the globals survive.
model_read() { # <what the text is> <text file>
  MODEL_STATE=cannot; MODEL_FINDINGS='[]'
  [ "$MODEL" != off ] || { MODEL_WHY='the model reading is switched off'; return 0; }
  command -v claude >/dev/null 2>&1 || { MODEL_WHY='no model client is available'; return 0; }
  {
    printf 'You check text that an AI agent wrote to a person, using the glossary below. The person has never opened the files of the harness the glossary describes.\n'
    printf 'Report each breach of these three kinds and nothing else:\n'
    printf 'TRANSLATED: a harness name translated word for word into another language and used as a term.\n'
    printf 'INVENTED: a name the agent made up for a concept and uses as if the person knew it.\n'
    printf 'UNEXPLAINED: a harness name carrying the meaning of a sentence with no plain description of it beside it.\n'
    printf 'A name inside quotation marks or code marks, written to talk about the name itself, is a mention and not a breach. Ordinary words in their ordinary sense are not breaches.\n'
    printf 'Answer with one line per breach, in the form: KIND | the words | why. When there is none, answer with the single word NONE.\n\n'
    printf '<glossary>\n'; cat "$PAGE"; printf '\n</glossary>\n\n<text kind="%s">\n' "$1"
    cat "$2"; printf '\n</text>\n'
  } > "$WORK/prompt" 2>/dev/null || { MODEL_WHY='the glossary could not be read'; return 0; }
  # The marker keeps the session this call starts from loading the glossary and from
  # reading its own answer here, which would call the model again.
  HARNESS_MODEL_CALL=1 claude -p --model "$MODEL" < "$WORK/prompt" > "$WORK/answer" 2>/dev/null &
  local pid=$! ticks=0 rc
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge $((LIMIT * 10)) ]; then
      kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      MODEL_WHY="the model did not answer within ${LIMIT} seconds"; return 0
    fi
    sleep 0.1; ticks=$((ticks + 1))
  done
  wait "$pid"; rc=$?
  [ "$rc" -eq 0 ] || { MODEL_WHY="the model call failed (exit ${rc})"; return 0; }
  grep -E '^[[:space:]]*(TRANSLATED|INVENTED|UNEXPLAINED)[[:space:]]*\|' "$WORK/answer" > "$WORK/breaches"
  if [ -s "$WORK/breaches" ]; then
    MODEL_FINDINGS=$(jq -R -s '[split("\n")[] | select(length > 0) | split("|") | map(gsub("^\\s+|\\s+$"; ""))
                               | {kind: (.[0] | ascii_downcase), words: (.[1] // ""), why: (.[2:] | join("|"))}]' \
                       "$WORK/breaches" 2>/dev/null) \
      || { MODEL_FINDINGS='[]'; MODEL_WHY='the answer of the model could not be read'; return 0; }
    MODEL_STATE=read
  elif awk 'NF { print; exit }' "$WORK/answer" | grep -qE '^[[:space:]]*NONE[[:space:]]*\.?[[:space:]]*$'; then
    MODEL_STATE=read
  else
    MODEL_WHY='the answer of the model could not be read'
  fi
}

# Sets OUTCOME, BY, NOTICE and WHY; called bare for the same reason as model_read.
judge() { # <what the text is> <text file> <model exempt: 1 or empty> <outcome on a finding>
  MODEL_STATE=cannot; MODEL_FINDINGS='[]'; MODEL_WHY=''
  names_found "$2"
  if [ "$NAMES_STATE" = cannot ]; then
    MODEL_WHY='the names the glossary lists could not be read'
  elif [ -n "$3" ]; then
    MODEL_STATE=exempt
  else
    model_read "$1" "$2"
  fi
  local nn nf
  nn=$(printf '%s' "$NAMES" | jq 'length'); nf=$(printf '%s' "$MODEL_FINDINGS" | jq 'length')
  BY=''
  [ "$nn" -gt 0 ] && BY=names
  [ "$nf" -gt 0 ] && BY=${BY:+$BY+}model
  NOTICE=false; WHY=''
  if [ "$MODEL_STATE" = cannot ]; then OUTCOME=could-not-run; WHY=$MODEL_WHY
  elif [ -n "$BY" ]; then OUTCOME=$4
  else OUTCOME=passed
  fi
  if [ "$MODEL_STATE" = cannot ] && ! told; then NOTICE=true; WHY=$MODEL_WHY; fi
  record "$OUTCOME" "$BY" "$MODEL_STATE" "$NAMES" "$MODEL_FINDINGS" "$NOTICE" "$WHY"
}

findings_text() {
  jq -nr --argjson n "$NAMES" --argjson f "$MODEL_FINDINGS" '
    ($n | map("\"" + .name + "\" is a name the glossary lists"
              + (if .canonical then " as another name for \"" + .canonical + "\"" else " as retired" end))) +
    ($f | map(.kind + ": \"" + .words + "\"" + (if .why == "" then "" else " -- " + .why end)))
    | join("; ")'
}

refuse_or_pass() { # <question | post>
  local prev exempt='' verb=post
  [ "$1" = question ] && verb=ask
  load_own
  prev=$(own_turn | grep -E '"moment":"(question|post)"' | tail -n 1)
  case $prev in *'"outcome":"refused","by":"model"'*) exempt=1 ;; esac
  judge "$1" "$WORK/text" "$exempt" refused
  if [ "$OUTCOME" = refused ]; then
    jq -nc --arg r "[plain-words] This $1 was not sent, because a person could not follow it: $(findings_text). Say what each thing is and does in plain words -- the glossary's entry describes it -- and ${verb} again." \
          --argjson t "$NOTICE" --arg m "${NOTICE_HEAD}: ${WHY}." '
      {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}
      + (if $t then {systemMessage: $m} else {} end)'
  elif [ "$NOTICE" = true ]; then
    notice_json "$WHY"
  fi
}

# The profile's Posting commands row holds backticked entries, each the command's
# leading words and then the flags carrying the text, a flag ending in :file naming a
# file that holds it; or the word none. Sets POSTING (undeclared | none | declared |
# matched) and, on a match, writes the text to $WORK/text.
SEP=$'\035'
posting_text() { # <command line> <directory a relative file is read from>
  local row s e nw base d
  local -a words
  row=$(awk -F'|' '/^\|[[:space:]]*Posting commands[[:space:]]*\|/ { print $3; exit }' "${PROJECT}/AGENTS.md" 2>/dev/null)
  if [ -z "$(printf '%s' "$row" | tr -d '[:space:]')" ]; then POSTING=undeclared; return 0; fi
  case $row in *'`'*) ;; *) POSTING=none; return 0 ;; esac
  POSTING=declared
  printf '%s' "$row" | grep -o '`[^`]*`' | tr -d '`' > "$WORK/entries"
  # Words the way the shell would quote them, without running anything inside: single
  # and double quotes and a backslash escape. An unquoted ;, &, | or line break ends a
  # command, so a posting command is read wherever it sits in the line.
  printf '%s' "$1" | LC_ALL=C awk 'BEGIN { RS = "\001" } {
      s = $0; n = length(s); w = ""; inw = 0; q = ""
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q == "\047") { if (c == "\047") q = ""; else w = w c; continue }
        if (q == "\"") {
          if (c == "\\" && i < n && index("\"\\$`", substr(s, i + 1, 1))) { w = w substr(s, ++i, 1); continue }
          if (c == "\"") q = ""; else w = w c
          continue
        }
        if (c == "\047" || c == "\"") { q = c; inw = 1; continue }
        if (c == "\\" && i < n) { w = w substr(s, ++i, 1); inw = 1; continue }
        if (c ~ /[ \t]/) { if (inw) printf "%s\036", w; w = ""; inw = 0; continue }
        if (c == "\n" || c == ";" || c == "&" || c == "|") {
          if (inw) printf "%s\036", w
          w = ""; inw = 0; printf "\035\036"; continue
        }
        w = w c; inw = 1
      }
      if (inw) printf "%s\036", w
    }' > "$WORK/words"
  words=()
  IFS=$'\036' read -r -d '' -a words < "$WORK/words"
  nw=${#words[@]}
  : > "$WORK/text"
  base=$2
  s=0
  while [ "$s" -lt "$nw" ]; do
    e=$s
    while [ "$e" -lt "$nw" ] && [ "${words[$e]}" != "$SEP" ]; do e=$((e + 1)); done
    if [ "$e" -gt "$s" ] && [ "${words[$s]}" = cd ]; then
      d=''; [ $((s + 1)) -lt "$e" ] && d=${words[$((s + 1))]}
      case $d in '') ;; /*) base=$d ;; *) base="$base/$d" ;; esac
    elif [ "$e" -gt "$s" ]; then
      command_text "$s" "$e" "$base"
    fi
    s=$((e + 1))
  done
}

# The declared text of the command in words[first .. past), when an entry declares it.
command_text() { # <first word> <past the last word> <directory a relative file is read from>
  local entry word i k val f file
  local -a spec prefix flags
  while IFS= read -r entry; do
    spec=(); prefix=(); flags=()
    read -r -a spec <<< "$entry"
    for word in ${spec[@]+"${spec[@]}"}; do
      case $word in -*) flags+=("$word") ;; *) prefix+=("$word") ;; esac
    done
    [ "${#prefix[@]}" -gt 0 ] && [ $(($2 - $1)) -ge "${#prefix[@]}" ] || continue
    k=0
    while [ "$k" -lt "${#prefix[@]}" ] && [ "${words[$(($1 + k))]}" = "${prefix[$k]}" ]; do k=$((k + 1)); done
    [ "$k" -eq "${#prefix[@]}" ] || continue
    POSTING=matched
    i=$(($1 + k))
    while [ "$i" -lt "$2" ]; do
      for f in ${flags[@]+"${flags[@]}"}; do
        file=''; [ "${f%:file}" = "$f" ] || file=1
        f=${f%:file}; val=''
        if [ "${words[$i]}" = "$f" ] && [ $((i + 1)) -lt "$2" ]; then val=${words[$((i + 1))]}
        else case ${words[$i]} in "$f="*) val=${words[$i]#"$f="} ;; esac
        fi
        [ -n "$val" ] || continue
        if [ -n "$file" ]; then
          case $val in /*) ;; *) val="$3/$val" ;; esac
          [ -r "$val" ] && { cat "$val"; printf '\n'; } >> "$WORK/text"
        else
          printf '%s\n' "$val" >> "$WORK/text"
        fi
      done
      i=$((i + 1))
    done
    return 0
  done < "$WORK/entries"
}

case $MOMENT in
  question)
    printf '%s' "$IN" | jq -r '[.tool_input | .. | strings] | join("\n")' > "$WORK/text" 2>/dev/null || exit 0
    [ -n "$(tr -d '[:space:]' < "$WORK/text")" ] || exit 0
    refuse_or_pass question
    ;;
  post)
    cmd=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    cwd=$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null); [ -n "$cwd" ] || cwd=$PROJECT
    POSTING=''
    posting_text "$cmd" "$cwd"
    case $POSTING in
      undeclared)
        load_own
        told && exit 0
        why='the profile of this project does not say which commands post text to the review surface or the tracker'
        record could-not-run '' cannot '[]' '[]' true "$why"
        notice_json "$why"
        ;;
      matched)
        [ -n "$(tr -d '[:space:]' < "$WORK/text")" ] || exit 0
        refuse_or_pass post
        ;;
    esac
    ;;
  turn-end)
    [ "$(printf '%s' "$IN" | jq -r '.stop_hook_active // false' 2>/dev/null)" = true ] && exit 0
    load_own
    tpath=$(printf '%s' "$IN" | jq -r '.transcript_path // empty' 2>/dev/null)
    final=$(printf '%s' "$IN" | jq -r '.last_assistant_message // empty' 2>/dev/null)
    # The chat text since the person last wrote: the transcript's assistant text after
    # the last user entry carrying text, plus the final message the event carries, which
    # the transcript may not hold yet. A tool result is not the person writing.
    printf '{"at":"","texts":[]}' > "$WORK/turn.json"
    if [ -n "$tpath" ] && [ -r "$tpath" ]; then
      jq -cs '
        def person: .type? == "user" and (.isMeta? | not)
          and ((.message.content? | type) == "string"
               or ([.message.content[]? | select(.type? == "text")] | length > 0));
        (to_entries | map(select(.value | person)) | last | .key // -1) as $k
        | {at: (if $k < 0 then "" else (.[$k].timestamp? // "") end),
           texts: [.[$k + 1:][] | select(.type? == "assistant") | .message.content[]? | select(.type? == "text") | .text]}' \
        "$tpath" > "$WORK/turn.json.new" 2>/dev/null && mv "$WORK/turn.json.new" "$WORK/turn.json"
    fi
    asked=$(jq -r '.at' "$WORK/turn.json" | cut -c1-19)
    # The continuation flag is the first guard; this is the second, for a host that does
    # not set it: a restatement already recorded since the person last wrote.
    last=$(tail -n 1 "$WORK/own")
    case $last in *'"moment":"turn-end","outcome":"restate"'*)
      at=$(printf '%s' "$last" | jq -r '.ts // empty' | cut -c1-19)
      if [ -z "$asked" ] || [ ! "$at" \< "$asked" ]; then exit 0; fi ;;
    esac
    jq -r --arg f "$final" '.texts as $t
      | (if $f == "" or (($t | last // "") | gsub("\\s+$"; "")) == ($f | gsub("\\s+$"; "")) then $t else $t + [$f] end)
      | join("\n\n")' "$WORK/turn.json" > "$WORK/text"
    if [ -z "$(tr -d '[:space:]' < "$WORK/text")" ]; then
      record empty '' none '[]' '[]' false
      exit 0
    fi
    judge chat "$WORK/text" '' restate
    if [ "$OUTCOME" = restate ]; then
      jq -nc --arg r "[plain-words] Your reply this turn uses words the person cannot follow: $(findings_text). Restate each affected sentence in plain words, in the person's language, saying what each thing is and does. Ask nothing and call no tool." \
            --argjson t "$NOTICE" --arg m "${NOTICE_HEAD}: ${WHY}." '
        {decision: "block", reason: $r} + (if $t then {systemMessage: $m} else {} end)'
    elif [ "$NOTICE" = true ]; then
      notice_json "$WHY"
    fi
    ;;
esac
exit 0
