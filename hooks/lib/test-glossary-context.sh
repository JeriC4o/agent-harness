#!/usr/bin/env bash
#
# Behaviour of hooks/lib/glossary-context.sh, and of its registrations in
# hooks/hooks.json. Fixture pages carry invented names only.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/../.." && pwd -P)
HOOK="${HERE}/glossary-context.sh"
HOOKS="${ROOT}/hooks/hooks.json"
CAP=10000
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT INT TERM

page() {
  {
    printf '# Glossary\n\nAn invented page.\n\n## Text for a person\n\nWrite plainly.\n'
    g=1
    while [ "$g" -le "$3" ]; do
      printf '\n## Group %s\n\n| Canonical name | Other names | What it is | What it does | Defined at |\n|---|---|---|---|---|\n' "$g"
      r=1
      while [ "$r" -le "$2" ]; do
        printf '| doohickey %s-%s | "gizmo %s-%s" | A made-up thing used only to fill this page to a size. | It does nothing at all except take up room in a row. | planned |\n' "$g" "$r" "$g" "$r"
        r=$((r+1))
      done
      g=$((g+1))
    done
    printf '\n## Retired names\n\n| Retired name | What it named |\n|---|---|\n| thingamajig | An old made-up thing. |\n'
  } > "$1"
}
piece() { HARNESS_GLOSSARY_PAGE="$1" "$HOOK" piece "$2" "$3"; }
context() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

printf '\n== a small page is one piece ==\n'
page "$W/small.md" 3 2
out=$(piece "$W/small.md" 1 5)
check "the event name is echoed" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" "SessionStart"
has "piece 1 says it is the only one" "$(context "$out")" "Glossary of the harness, part 1 of 1"
has "  and carries the last row" "$(context "$out")" "| thingamajig |"
check "piece 2 of a one-piece page prints nothing" "$(piece "$W/small.md" 2 5)" ""

printf '\n== a large page splits between entries, each piece under the cap ==\n'
page "$W/large.md" 60 5
n=1; rows=""; maxlen=0
while out=$(piece "$W/large.md" "$n" 9) && [ -n "$out" ]; do
  t=$(context "$out")
  len=$(printf '%s' "$t" | wc -m | tr -d ' ')
  [ "$len" -gt "$maxlen" ] && maxlen=$len
  first=$(printf '%s\n' "$t" | awk 'NR > 2 && NF { print; exit }')
  case "$n:$first" in
    1:*|*:"## "*) ok "piece $n opens on a heading or the page head" ;;
    *) bad "piece $n opens mid-table without its heading: [$first]" ;;
  esac
  rows="$rows$(printf '%s\n' "$t" | grep -E '^\| (doohickey|thingamajig) ')
"
  n=$((n+1))
done
pieces=$((n-1))
[ "$pieces" -gt 3 ] && ok "the large page needs $pieces pieces" || bad "the large page fit in $pieces pieces, so the split is untested"
[ "$maxlen" -lt "$CAP" ] && ok "the longest piece, $maxlen characters, is under the host cap" \
                         || bad "a piece of $maxlen characters is over the host cap"
want=$(grep -cE '^\| (doohickey|thingamajig) ' "$W/large.md")
got=$(printf '%s' "$rows" | grep -cE '^\| ')
check "every entry arrives exactly once across the pieces" "$got" "$want"
check "  and none twice" "$(printf '%s' "$rows" | sed '/^$/d' | sort | uniq -d | wc -l | tr -d ' ')" "0"
has "a piece opening inside a table repeats the header" "$(context "$(piece "$W/large.md" 2 9)")" \
  "| Canonical name | Other names | What it is | What it does | Defined at |"
has "the last registered piece names the parts left unloaded" "$(context "$(piece "$W/large.md" 2 2)")" \
  "Parts 3 to $pieces were not loaded"

printf '\n== the registrations hold a page at the size limit ==\n'
reg=$(jq '[.hooks.SessionStart[] | .hooks[] | select(.command | test("glossary-context.sh piece"))] | length' "$HOOKS")
[ "$reg" -gt 0 ] && ok "$reg pieces are registered" || bad "no piece is registered"
i=1
while [ "$i" -le "$reg" ]; do
  c=$(jq -r --argjson i "$i" '[.hooks.SessionStart[] | .hooks[] | select(.command | test("glossary-context.sh piece"))][$i - 1].command' "$HOOKS")
  case "$c" in
    *harness-managed.sh*"glossary-context.sh piece $i $reg") ok "registration $i asks for piece $i of $reg, behind the guard" ;;
    *) bad "registration $i is [$c]" ;;
  esac
  i=$((i+1))
done
check "the pieces load at start, after clear and after compaction" \
  "$(jq -r '.hooks.SessionStart[] | select(any(.hooks[]; .command | test("glossary-context.sh"))) | .matcher' "$HOOKS")" \
  "startup|clear|compact"
page "$W/big.md" 25 11
LC_ALL=C awk '{ n += length($0) + 1; if (n >= 40000) exit; print }' "$W/big.md" > "$W/limit.md"
size=$(wc -m < "$W/limit.md" | tr -d ' ')
[ "$size" -gt 39000 ] && ok "the limit page is $size characters, just under the cap" || bad "the limit page is only $size characters"
last=$(piece "$W/limit.md" "$reg" "$reg")
has "a page at the 40,000-character limit fits in the registered pieces" "$(context "$last")" "part $reg of"
case "$(context "$last")" in
  *"were not loaded"*) bad "  but parts were left unloaded" ;;
  *) ok "  with nothing left unloaded" ;;
esac
real=$(piece "$ROOT/docs/glossary.md" 1 "$reg")
has "the shipped page loads" "$(context "$real")" "Glossary of the harness, part 1 of"
case "$(context "$(piece "$ROOT/docs/glossary.md" "$reg" "$reg")")" in
  *"were not loaded"*) bad "the shipped page outgrew the registrations" ;;
  *) ok "the shipped page fits the registrations" ;;
esac

printf '\n== the brief of the three agents takes the page ==\n'
brief() { printf '%s' "$1" | HARNESS_GLOSSARY_PAGE="$W/small.md" "$HOOK" brief; }
pay() { jq -nc --arg t "$1" --arg p "$2" '{tool_name: "Agent", tool_input: {subagent_type: $t, description: "d", prompt: $p}}'; }
LEAD='The harness glossary follows. Its rule for text for a person binds what you write to a person.'
for t in spec-writer harness:design design-review; do
  out=$(brief "$(pay "$t" "Write it.")")
  has "type $t: the page is appended" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt')" "$LEAD"
done
out=$(brief "$(pay general-purpose "Read /x/agents/design.md and follow it.")")
p=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt')
case "$p" in "Read /x/agents/design.md and follow it."*"$LEAD"*"| thingamajig |"*) ok "a general-purpose brief naming the page: brief kept, then the page" ;;
  *) bad "the rewritten brief is [$p]" ;; esac
check "  the other input fields are kept" "$(printf '%s' "$out" | jq -c '.hookSpecificOutput.updatedInput | [.subagent_type, .description]')" '["general-purpose","d"]'
check "  and the call is allowed, as a rewritten input needs" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" "allow"
out=$(brief "$(pay general-purpose "Read /x/agents/design-review.md")")
has "a brief naming the reviewer's page" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt')" "$LEAD"
check "a brief naming another agent's page is left alone" "$(brief "$(pay general-purpose "Read /x/agents/self-review.md")")" ""
check "another agent type is left alone" "$(brief "$(pay Explore "Find it.")")" ""
check "a brief that already carries the page is left alone" "$(brief "$(pay spec-writer "x $LEAD")")" ""
check "an empty payload is silent" "$(printf '' | "$HOOK" brief)" ""
check "a malformed payload is silent" "$(printf '{not json' | "$HOOK" brief)" ""

printf '\n== the model-call marker and an unreadable page ==\n'
check "a piece inside a model call is silent" "$(HARNESS_MODEL_CALL=1 HARNESS_GLOSSARY_PAGE="$W/small.md" "$HOOK" piece 1 5)" ""
check "a brief inside a model call is left alone" \
  "$(pay spec-writer "Write it." | HARNESS_MODEL_CALL=1 HARNESS_GLOSSARY_PAGE="$W/small.md" "$HOOK" brief)" ""
out=$(piece "$W/missing.md" 1 5); rc=$?
check "a missing page prints nothing" "$out" ""
check "  and exits 0" "$rc" "0"
c=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Agent") | .hooks[0].command' "$HOOKS")
case "$c" in *harness-managed.sh*"glossary-context.sh brief") ok "the agent tool's registration runs the brief, behind the guard" ;;
  *) bad "the agent tool's registration is [$c]" ;; esac

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
