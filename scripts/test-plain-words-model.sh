#!/usr/bin/env bash
#
# Each text goes through the check itself, as a question, under a session of its own
# and a scratch ledger directory: one session would let a model refusal exempt the
# next reading and the once-a-session notice hide a could-not-run.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/../hooks/lib/plain-words.sh"
READINGS=5
HEALTHY='every reading of the unchanged text gives the same answer'

usage() { printf 'usage: bash scripts/test-plain-words-model.sh [--readings N], N at least 2\n' >&2; exit 2; }
while [ $# -gt 0 ]; do
  case $1 in
    --readings)
      [ $# -ge 2 ] || usage
      case $2 in ''|*[!0-9]*) usage ;; esac
      [ "$2" -ge 2 ] || usage
      READINGS=$2; shift 2 ;;
    *) usage ;;
  esac
done

cannot() { printf 'plain-words-model: cannot-run -- %s\n' "$1"; exit 2; }
command -v jq >/dev/null 2>&1 || cannot 'jq is not on PATH'
[ -r "$CHECK" ] || cannot "the check cannot be read at ${CHECK}"

unset HARNESS_MODEL_CALL HARNESS_GLOSSARY_PAGE
MODEL=${HARNESS_PLAIN_WORDS_MODEL:-haiku}
LOOPS=$(mktemp -d) || cannot 'no scratch directory'
trap 'rm -rf "$LOOPS"' EXIT INT TERM

KINDS='translated invented unexplained'
TEXT_translated='Die Haltungsklasse hat die Konvergenzprüfung angehalten, also habe ich den Akzeptanzakt ausgeführt, und die Nachbesserungsschleife meldet jetzt MATCH.'
TEXT_invented='I parked the two risky edits in the quiet lane and ran the shelf sweep over them; the side tally is clean now, so the drift latch can open.'
TEXT_unexplained='The holding class stopped the plan freeze, so I ran the accepting act; the post-apply micro-loop came back MATCH and the checklist ledger carried every row.'
TEXT_unchanged='I changed the check so that a question carrying a word you might not know is stopped before you see it, and the agent is told to say the same thing in plain words. Its tests pass and nothing else changed. Shall I open the pull request now?'

N=0
read_one() {
  local sid row
  N=$((N + 1)); sid="plain-words-model-$$-${N}"
  printf '  reading %s ...\n' "$N" >&2
  jq -nc --arg s "$sid" --arg q "$1" '{session_id: $s, tool_input: {questions: [{question: $q}]}}' \
    | HARNESS_LOOP_DIR="$LOOPS" bash "$CHECK" question > "$LOOPS/out"
  row=$(jq -c 'select(.kind? == "plain-words")' "$LOOPS/${sid}.jsonl" 2>/dev/null | tail -n 1)
  [ -n "$row" ] || cannot "the check left no record of reading ${N}"
  [ "$(printf '%s' "$row" | jq -r '.model_state')" = read ] \
    || cannot "reading ${N}: $(printf '%s' "$row" | jq -r '.reason // "the model could not read"')"
  [ "$(printf '%s' "$row" | jq '.names | length')" = 0 ] \
    || cannot "reading ${N}: the text carries a name the glossary lists, so the names reading would decide it"
  ANSWER=$(printf '%s' "$row" | jq -r '[.model[].kind] | unique | if length == 0 then "none" else join(",") end')
  DETAIL=$(printf '%s' "$row" | jq -r '.model[] | "      " + .kind + " | " + .words + " | " + .why')
}

printf 'plain-words-model: model %s, %s readings of the unchanged text\n' "$MODEL" "$READINGS" >&2
CAUGHT=0; TOTAL=0; COVERAGE=''; PLANTED=''
for k in $KINDS; do
  name="TEXT_${k}"; text=${!name}; TOTAL=$((TOTAL + 1))
  read_one "$text"
  case ",${ANSWER}," in *",${k},"*) word=covered; CAUGHT=$((CAUGHT + 1)) ;; *) word=uncovered ;; esac
  COVERAGE="${COVERAGE:+${COVERAGE}, }${k} ${word}"
  PLANTED="${PLANTED}  ${k}: ${word}, answer ${ANSWER}
    text: ${text}
${DETAIL:+${DETAIL}
}"
done

: > "$LOOPS/unchanged"; UNCHANGED=''
i=0
while [ "$i" -lt "$READINGS" ]; do
  i=$((i + 1))
  read_one "$TEXT_unchanged"
  printf '%s\n' "$ANSWER" >> "$LOOPS/unchanged"
  UNCHANGED="${UNCHANGED}  reading ${i}: ${ANSWER}
${DETAIL:+${DETAIL}
}"
done
TALLY=$(sort "$LOOPS/unchanged" | uniq -c | sort -rn)
TOP=$(printf '%s\n' "$TALLY" | awk 'NR == 1 { print $1 }')
MODAL=$(printf '%s\n' "$TALLY" | awk 'NR == 1 { print $2 }')
ANSWERS=$(printf '%s\n' "$TALLY" | awk '{ printf "%s%s x%s", (NR > 1 ? ", " : ""), $2, $1 }')

verdict=clean; [ "$CAUGHT" -eq "$TOTAL" ] || verdict=findings
printf 'plain-words-model: %s model=%s caught=%s/%s agreement=%s/%s\n' "$verdict" "$MODEL" "$CAUGHT" "$TOTAL" "$TOP" "$READINGS"
printf '  healthy agreement: %s\n' "$HEALTHY"
printf '  coverage: %s\n' "$COVERAGE"
printf '  agreement: %s of %s readings of the unchanged text gave the most common answer, %s\n' "$TOP" "$READINGS" "$MODAL"
printf '  answers: %s\n' "$ANSWERS"
printf '\nplanted texts, one per kind\n%s' "$PLANTED"
printf '\nthe unchanged text\n    text: %s\n%s' "$TEXT_unchanged" "$UNCHANGED"
[ "$verdict" = clean ]
