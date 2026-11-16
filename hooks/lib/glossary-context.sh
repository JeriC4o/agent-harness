#!/usr/bin/env bash
#
# Put the glossary into an agent's context.
#
# Run:  glossary-context.sh piece <n> <registered>   SessionStart: piece n of the page
#       glossary-context.sh brief                    PreToolUse on the agent tool: the page
#                                                    appended to the brief of the spec writer,
#                                                    the design author or the design reviewer
# Exit: always 0. A page it cannot read leaves the session as it was.
#
# WHY PIECES. The host cuts one hook message over its size cap down to a file path
# and a short preview, so the page goes in several messages, each under the cap and
# split between entries; a piece that starts inside a table repeats the table's
# heading and header so it reads alone. The manifest registers one call per piece,
# enough for a page at the size limit; the last registered piece names the page if
# more remain, so a page that outgrew the registrations is never cut silently.
#
# WHY THE BRIEF AND NOT THE AGENT TYPE. The interview and task skills start these
# three agents as general-purpose agents whose brief names the agent's page, so the
# type alone does not pick them out.
#
# HARNESS_MODEL_CALL is the model-call marker: a harness hook calling a model sets it
# in that call's environment, and the session that call starts loads nothing here.

set -uo pipefail

[ -z "${HARNESS_MODEL_CALL:-}" ] || exit 0
PAGE=${HARNESS_GLOSSARY_PAGE:-$(cd -- "$(dirname -- "$0")/../.." && pwd)/docs/glossary.md}
CAP=9500
LEAD='The harness glossary follows. Its rule for text for a person binds what you write to a person.'
[ -r "$PAGE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

pieces() {
  LC_ALL=C awk -v want="$1" -v reg="$2" -v cap="$CAP" -v page="$PAGE" '
    function add(s) { buf = buf s "\n"; blen += length(s) + 1 }
    function flush() { if (blen) { piece[++np] = buf; buf = ""; blen = 0 } }
    /^\| (Canonical name|Retired name) \|/ { header = $0; getline sep; add($0); add(sep); next }
    /^\|/ && blen + length($0) + 1 > cap { flush(); add(heading); add(""); add(header); add(sep) }
    /^## / { if (blen + length($0) > cap - 400) flush(); heading = $0 }
    !/^\|/ { header = "" }
    { add($0) }
    END {
      flush()
      if (want > np) exit
      printf "Glossary of the harness, part %d of %d (%s).\n\n%s", want, np, page, piece[want]
      if (want == reg && np > reg) printf "\nParts %d to %d were not loaded; read the rest at %s.\n", reg + 1, np, page
    }' "$PAGE"
}

case "${1:-}" in
  piece)
    text=$(pieces "${2:-1}" "${3:-1}") || exit 0
    [ -n "$text" ] || exit 0
    jq -nc --arg t "$text" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $t}}' 2>/dev/null
    ;;
  brief)
    in=$(cat 2>/dev/null) || exit 0
    [ -n "$in" ] || exit 0
    type=$(printf '%s' "$in" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null) || exit 0
    prompt=$(printf '%s' "$in" | jq -r '.tool_input.prompt // empty' 2>/dev/null) || exit 0
    hit=""
    case "${type##*:}" in spec-writer|design|design-review) hit=1 ;; esac
    case "$prompt" in *agents/spec-writer.md*|*agents/design.md*|*agents/design-review.md*) hit=1 ;; esac
    [ -n "$hit" ] || exit 0
    case "$prompt" in *"$LEAD"*) exit 0 ;; esac
    printf '%s' "$in" | jq -c --arg lead "$LEAD" --rawfile page "$PAGE" '
      {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow",
        updatedInput: (.tool_input | .prompt = (.prompt + "\n\n" + $lead + "\n\n" + $page))}}' 2>/dev/null
    ;;
esac
exit 0
