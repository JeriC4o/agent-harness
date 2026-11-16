#!/usr/bin/env bash
#
# Behaviour of hooks/lib/plain-words.sh. The model is a stub on PATH and never a real
# one; the glossary, the profile and every name in it are invented.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
HOOK="${HERE}/plain-words.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3]" ;; *) ok "$1" ;; esac; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT INT TERM
mkdir -p "$W/bin" "$W/proj" "$W/loops"

cat > "$W/glossary.md" <<'EOF'
# Glossary

## Things

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| widget ledger | "gadget book", "sprocket log" | A made-up record of widgets. | It holds one made-up row per widget. | planned |

## Retired names

| Retired name | What it named |
|---|---|
| doodad fold | A made-up step nobody runs any more. |
EOF
printf '| Setting | Value |\n|---|---|\n| Posting commands | `ticketctl post --text -t --text-file:file -F:file` `ticketctl note --body -b` |\n' > "$W/proj/AGENTS.md"

cat > "$W/bin/claude" <<EOF
#!/usr/bin/env bash
cat > "$W/last-prompt"
printf '%s\n' "\${HARNESS_MODEL_CALL:-unset}" >> "$W/calls"
{ pwd; printf '<%s>' "\$@"; printf '\n'; } > "$W/last-call"
[ -s "$W/sleep" ] && sleep "\$(cat "$W/sleep")"
cat "$W/answer" 2>/dev/null
exit "\$(cat "$W/rc" 2>/dev/null || echo 0)"
EOF
chmod +x "$W/bin/claude"
answer() { printf '%s\n' "$1" > "$W/answer"; printf '%s' "${2:-0}" > "$W/rc"; : > "$W/sleep"; }
answer NONE

run() { # <moment> <payload>
  printf '%s' "$2" | PATH="$W/bin:$PATH" HARNESS_GLOSSARY_PAGE="$W/glossary.md" HARNESS_LOOP_DIR="$W/loops" \
    HARNESS_PLAIN_WORDS_TIMEOUT="${LIMIT:-5}" CLAUDE_PROJECT_DIR="$W/proj" bash "$HOOK" "$1"
}
question() { # <session> <question text>
  run question "$(jq -nc --arg s "$1" --arg q "$2" '{session_id: $s, tool_input: {questions: [{question: $q, header: "Pick", options: [{label: "Yes", description: "Go on"}]}]}}')"
}
post() { # <session> <command>
  run post "$(jq -nc --arg s "$1" --arg c "$2" --arg d "$W" '{session_id: $s, cwd: $d, tool_input: {command: $c}}')"
}
stop() { # <session> <transcript> <final message> [<continuation flag>]
  run turn-end "$(jq -nc --arg s "$1" --arg t "$2" --arg f "$3" --argjson a "${4:-false}" '{session_id: $s, transcript_path: $t, last_assistant_message: $f, stop_hook_active: $a}')"
}
decision() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // .decision // empty'; }
reason()   { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // .reason // empty'; }
notice()   { printf '%s' "$1" | jq -r '.systemMessage // empty'; }
rows()     { jq -c 'select(.kind == "plain-words")' "$W/loops/$1.jsonl" 2>/dev/null; }
lastrow()  { rows "$1" | tail -n 1; }
calls()    { [ -f "$W/calls" ] && wc -l < "$W/calls" | tr -d ' ' || printf 0; }

printf '\n== a question: listed names outside quotation and code marks ==\n'
out=$(question q1 'Shall I update the gadget book now?')
check "a listed name used as a term is refused" "$(decision "$out")" "deny"
has "  the refusal names the word found" "$(reason "$out")" '"gadget book" is a name the glossary lists as another name for "widget ledger"'
has "  and tells the agent to ask again" "$(reason "$out")" "ask again"
check "  the record says the names refused it" "$(lastrow q1 | jq -r '.outcome + " " + .by')" "refused names"
out=$(question q1 'The old doodad folds are gone.')
has "a retired name, in a verb form, is refused" "$(reason "$out")" '"doodad fold" is a name the glossary lists as retired'
out=$(question q1 'The tool still calls it `gadget book`, and the page says "sprocket log".')
check "a name inside code marks or quotation marks is a mention" "$(decision "$out")" ""
check "  and its reading is recorded as passed" "$(lastrow q1 | jq -r .outcome)" "passed"
out=$(question q1 'Shall I update the gadget-book?')
check "a hyphen between the words still matches" "$(decision "$out")" "deny"
check "the model was called under the model-call marker" "$(sort -u "$W/calls")" "1"
has "  and was handed the glossary" "$(cat "$W/last-prompt")" "| widget ledger |"
out=$(cd "$W/proj" && question q1 'Shall I go on?')
hasnt "  started outside the project directory the hook runs in" "$(sed -n 1p "$W/last-call")" "$W/proj"
has "  in the client's safe mode" "$(sed -n 2p "$W/last-call")" "<--safe-mode>"
has "  with no tools" "$(sed -n 2p "$W/last-call")" "<--tools><>"
has "  and no saved session" "$(sed -n 2p "$W/last-call")" "<--no-session-persistence>"

printf '\n== a question: the model reading, and its refusal bound ==\n'
answer 'INVENTED | the side shelf | a name for a concept the person has never seen'
out=$(question q2 'Should the side shelf take the rows?')
check "a model finding alone refuses the question" "$(decision "$out")" "deny"
has "  naming the kind and the words" "$(reason "$out")" 'invented: "the side shelf"'
check "  recorded as refused by the model" "$(lastrow q2 | jq -r '.outcome + " " + .by')" "refused model"
out=$(question q2 'Should the side shelf take the rows, then?')
check "the next question in the turn is not refused on the model reading" "$(decision "$out")" ""
check "  its record says the model reading was skipped" "$(lastrow q2 | jq -r '.model_state + " " + .outcome')" "exempt passed"
out=$(question q2 'And the side shelf after that?')
check "a later question is read and refused again" "$(decision "$out")" "deny"
out=$(question q2 'Should the gadget book take the rows?')
check "after a model refusal, a listed name is still refused" "$(decision "$out")" "deny"
check "  by the names, the model reading skipped" "$(lastrow q2 | jq -r '.by + " " + .model_state')" "names exempt"
out=$(question q2 'The side shelf once more?')
check "  and the question after that is read by the model again" "$(decision "$out")" "deny"
answer NONE
stop q2 "$W/none.jsonl" "All set." >/dev/null
answer 'INVENTED | the side shelf | coined'
question q2 'Side shelf?' >/dev/null
out=$(question q2 'Side shelf again?')
check "the bound is per turn: the model reading in a new turn starts afresh" "$(decision "$out")" ""

printf '\n== a post: only a declared posting command, its text from the declared flags ==\n'
answer NONE
out=$(post p1 'ticketctl post --title x --text "The gadget book is ready."')
check "a declared command with a listed name in its text flag is refused" "$(decision "$out")" "deny"
has "  and told to post again" "$(reason "$out")" "post again"
printf 'Line one.\nThe sprocket log moved.\n' > "$W/body.md"
out=$(post p1 'ticketctl post --text-file body.md')
check "the text in a file a flag names is read" "$(decision "$out")" "deny"
out=$(post p1 'ticketctl note --body="all fine here"')
check "a flag written with = is read, and plain text passes" "$(decision "$out")" ""
check "  with a record" "$(lastrow p1 | jq -r '.moment + " " + .outcome')" "post passed"
n=$(rows p1 | wc -l | tr -d ' ')
out=$(post p1 'echo "the gadget book" | grep gadget')
check "a line with no declared command is not read" "$(decision "$out")" ""
check "  and leaves no record" "$(rows p1 | wc -l | tr -d ' ')" "$n"
out=$(post p1 'echo "the gadget book" && ticketctl post --text hi')
check "a declared command later in the line is read for its own text only" "$(decision "$out")" ""
check "  and recorded" "$(rows p1 | wc -l | tr -d ' ')" "$((n + 1))"
mkdir -p "$W/sub"; printf 'The sprocket log is gone.\n' > "$W/sub/note.md"
out=$(post p1 'cd sub && ticketctl post --text-file note.md')
check "a declared command after cd ... && is read, its file found where cd moved" "$(decision "$out")" "deny"
out=$(post p1 'git status; ticketctl post --text "The gadget book is ready."')
check "a declared command after ; is read" "$(decision "$out")" "deny"
out=$(post p1 'git status
ticketctl note --body "the doodad fold"')
check "a declared command on a later line is read" "$(decision "$out")" "deny"
out=$(post p1 'ticketctl note -b "the gadget book"')
check "a short text flag is read" "$(decision "$out")" "deny"
out=$(post p1 'ticketctl post -F body.md')
check "a short file flag is read" "$(decision "$out")" "deny"
out=$(post p1 'ticketctl post -t"The gadget book is ready."')
check "a short flag with its value attached is read" "$(decision "$out")" "deny"
printf '| Setting | Value |\n|---|---|\n| Posting commands | none |\n' > "$W/proj/AGENTS.md"
out=$(post p2 'ticketctl post --text "the gadget book"')
check "a profile declaring none reads no post" "$out" ""
printf '| Setting | Value |\n|---|---|\n' > "$W/proj/AGENTS.md"
out=$(post p3 'ls')
has "a profile with no Posting commands row tells the person once" "$(notice "$out")" "does not say which commands post"
check "  recorded as a could-not-run" "$(lastrow p3 | jq -r '.outcome + " " + (.notice|tostring)')" "could-not-run true"
check "  and only once a session" "$(post p3 'ls')" ""
printf '| Setting | Value |\n|---|---|\n| Posting commands | `ticketctl post --text -t --text-file:file -F:file` `ticketctl note --body -b` |\n' > "$W/proj/AGENTS.md"

printf '\n== the turn end: the chat text since the person last wrote ==\n'
cat > "$W/t1.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"Earlier question about the gadget book."},"timestamp":"2999-01-01T00:00:00.000Z"}
{"type":"assistant","message":{"content":[{"type":"text","text":"An earlier turn mentioned the sprocket log."}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Now do the work."}]},"timestamp":"2999-01-01T00:00:01.000Z"}
{"type":"assistant","message":{"content":[{"type":"text","text":"Working on it."},{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"the gadget book"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"Done with the plain part."}]}}
EOF
answer NONE
out=$(stop s1 "$W/t1.jsonl" "Done with the plain part.")
check "plain chat since the person's last message ends the turn" "$out" ""
check "  with a turn-end record" "$(lastrow s1 | jq -r '.moment + " " + .outcome')" "turn-end passed"
chat=$(awk '/^<text kind=/ { on = 1 } on' "$W/last-prompt")
has "  the text read is this turn's" "$chat" "Working on it."
hasnt "  not the earlier turn" "$chat" "sprocket log"
hasnt "  nor a tool result" "$chat" "the gadget book"
out=$(stop s1b "$W/t1.jsonl" "Also, the gadget book is updated.")
check "a listed name in the final message the event carries makes the agent restate" "$(decision "$out")" "block"
has "  in plain words, asking nothing" "$(reason "$out")" "Ask nothing and call no tool"
check "  recorded as a restatement" "$(lastrow s1b | jq -r .outcome)" "restate"
check "a turn end the host flags as a continuation reads nothing" "$(stop s1b "$W/t1.jsonl" "the gadget book again" true)" ""
check "  and records nothing" "$(lastrow s1b | jq -r .outcome)" "restate"
sed 's/2999-01-01T00:00:01/2000-01-01T00:00:01/' "$W/t1.jsonl" > "$W/t-old.jsonl"
check "a continuation the host does not flag is still not read twice" "$(stop s1b "$W/t-old.jsonl" "the gadget book again")" ""
check "  but once the person writes again, the next turn is read" "$(decision "$(stop s1b "$W/t1.jsonl" "the gadget book again")")" "block"
answer 'TRANSLATED | Glossar-Buch | the name rendered word for word'
out=$(stop s1c "$W/t1.jsonl" "Done with the plain part.")
check "a model finding in chat makes the agent restate" "$(decision "$out")" "block"
has "  naming it" "$(reason "$out")" 'translated: "Glossar-Buch"'

printf '\n== could not run: the text goes through, the person is told once ==\n'
answer 'NONE' 1
out=$(question c1 'Shall I carry on?')
check "a failed model call lets the question through" "$(decision "$out")" ""
has "  and tells the person the text is not being checked" "$(notice "$out")" "not being checked"
has "  naming why" "$(notice "$out")" "the model call failed"
check "  recorded as a could-not-run, never as passed" "$(lastrow c1 | jq -r '.outcome + " " + .model_state')" "could-not-run cannot"
out=$(question c1 'Shall I carry on again?')
check "  the notice comes once a session" "$(notice "$out")" ""
check "  and the second reading is still recorded" "$(lastrow c1 | jq -r .outcome)" "could-not-run"
answer NONE 1
out=$(question c1b 'Shall I update the gadget book?')
check "  a listed name goes through while the model cannot run" "$(decision "$out")" ""
has "  the person is told" "$(notice "$out")" "the model call failed"
check "  the record is a could-not-run, never a pass" "$(lastrow c1b | jq -r '.outcome + " " + .model_state')" "could-not-run cannot"
check "  and it records the name the names reading found" "$(lastrow c1b | jq -r '.by + " " + .names[0].name')" "names gadget book"
answer NONE; before=$(calls)
out=$(post c1c 'ticketctl post --text-file gone.md')
check "a file a declared flag names that cannot be read lets the post through" "$(decision "$out")" ""
has "  tells the person, naming the file" "$(notice "$out")" "gone.md"
check "  recorded as a could-not-run" "$(lastrow c1c | jq -r .outcome)" "could-not-run"
check "  and the model is not called" "$(calls)" "$before"
post c1d 'ticketctl post --text "all fine" --text-file -' >/dev/null
check "text from standard input is a could-not-run, never passed" "$(lastrow c1d | jq -r .outcome)" "could-not-run"
before=$(calls)
out=$(post c1e 'ticketctl post --text "$BODY"')
check "a text flag's value the shell expands lets the post through" "$(decision "$out")" ""
check "  recorded as a could-not-run, never passed" "$(lastrow c1e | jq -r .outcome)" "could-not-run"
has "  tells the person, naming the flag" "$(notice "$out")" "the value of --text is changed by the shell"
check "  and the model is not called" "$(calls)" "$before"
post c1f 'ticketctl post --text "$(cat body.md)"' >/dev/null
check "a command substitution in a text flag is a could-not-run" "$(lastrow c1f | jq -r .outcome)" "could-not-run"
post c1g 'ticketctl post --text "`cat body.md`"' >/dev/null
check "a backtick substitution in a text flag is a could-not-run" "$(lastrow c1g | jq -r .outcome)" "could-not-run"
post c1h 'ticketctl post -t"$BODY"' >/dev/null
check "an expansion in an attached short value is a could-not-run" "$(lastrow c1h | jq -r .outcome)" "could-not-run"
post c1i 'ticketctl post --text Ready?' >/dev/null
check "an unquoted pattern character is a could-not-run" "$(lastrow c1i | jq -r .outcome)" "could-not-run"
out=$(post c1j "ticketctl post --text 'The gadget book costs \$5.'")
check "a dollar inside single quotes is literal: the text is read and refused" "$(decision "$out")" "deny"
cat > "$W/heredoc-cmd" <<'EOF'
ticketctl post --text "$(cat <<'EOT'
The gadget book's "owner tag" costs $5.
EOT
)"
EOF
out=$(post c1k "$(cat "$W/heredoc-cmd")")
check "a cat of a here-document with a quoted delimiter is read as its body and refused" "$(decision "$out")" "deny"
sed "s/<<'EOT'/<<EOT/" "$W/heredoc-cmd" > "$W/heredoc-open"
post c1l "$(cat "$W/heredoc-open")" >/dev/null
check "  with an unquoted delimiter it is a could-not-run" "$(lastrow c1l | jq -r .outcome)" "could-not-run"
out=$(post c1m 'ticketctl post --text "the gadget book" -dt "all fine"')
check "a declared one-letter flag grouped behind another letter lets the post through" "$(decision "$out")" ""
check "  recorded as a could-not-run, the name the readable flag carried beside it" "$(lastrow c1m | jq -r '.outcome + " " + .names[0].name')" "could-not-run gadget book"
answer 'Sure, looks fine to me.'
out=$(question c2 'Shall I carry on?')
check "an answer the hook cannot read is a could-not-run" "$(lastrow c2 | jq -r .outcome)" "could-not-run"
has "  said so" "$(notice "$out")" "could not be read"
answer NONE; printf '3' > "$W/sleep"
out=$(LIMIT=1 question c3 'Shall I carry on?')
check "a model over the time limit is a could-not-run" "$(lastrow c3 | jq -r .outcome)" "could-not-run"
has "  said so" "$(notice "$out")" "did not answer within 1 seconds"
: > "$W/sleep"
cp "$W/glossary.md" "$W/good.md"
printf '| broken | row |\n' >> "$W/glossary.md"
sed -i.bak 's/^| widget ledger | "gadget book", "sprocket log" |/| widget ledger | gadget book |/' "$W/glossary.md"
before=$(calls)
out=$(question c4 'Shall I update the gadget book?')
check "unreadable names let even a listed name through" "$(decision "$out")" ""
has "  and tell the person" "$(notice "$out")" "names the glossary lists could not be read"
check "  and the model never reads a text the names were not matched against" "$(calls)" "$before"
cp "$W/good.md" "$W/glossary.md"
out=$(HARNESS_PLAIN_WORDS_MODEL=off run question "$(jq -nc '{session_id: "c5", tool_input: {questions: [{question: "Go?"}]}}')")
has "a model reading switched off is a could-not-run, told" "$(notice "$out")" "switched off"

printf '\n== inside a model call made by a harness hook, nothing ==\n'
out=$(printf '%s' '{"session_id":"m1","tool_input":{"questions":[{"question":"the gadget book?"}]}}' \
      | HARNESS_MODEL_CALL=1 HARNESS_GLOSSARY_PAGE="$W/glossary.md" HARNESS_LOOP_DIR="$W/loops" bash "$HOOK" question)
check "the marker silences the check" "$out" ""
check "  and leaves no record" "$(rows m1 | wc -l | tr -d ' ')" "0"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
