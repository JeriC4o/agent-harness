#!/usr/bin/env bash
#
# Behaviour of hooks/lib/plan-invariants-guard.sh.
#
# Run: bash hooks/lib/test-plan-invariants-guard.sh
#
# EVERY CASE COMES WITH ITS OPPOSITE, because neither firing direction is
# observable from the other. A refusal that fires on a write to a protected page
# is worthless if it also fires on a READ of it: this repository's ambient style
# reads through the shell, so that surplus lands on nearly every orientation
# read of the most-read pages it protects, and a refusal that loud is the kind that
# gets switched off -- which costs the whole protection rather than one prompt.
# So each write assertion is paired with a read of the SAME page, and the pair is
# what discriminates rather than either half.
#
# THE OPERAND RULES ARE EACH PINNED BY A PAIR for the same reason. The in-place
# short-flag cluster, the `-t` destination and the narrowed interpreter operand
# all have a direction in which the obvious spelling fails, and a single-ended
# assertion cannot see it.
#
# THE SIX RESIDUAL FORMS ARE ASSERTED SILENT so the stated bound is a measured
# fact rather than a claim. Every one of them under-fires, which is the property
# that matters: there is no shape on which the house style meets a refusal it
# would want switched off.
#
# LEARNING MODE IS ON IN EVERY PAYLOAD UNLESS A CASE SAYS OTHERWISE. Each one
# names a transcript recording a run of /improve, so the shell-arm cases measure
# the arm itself. The learning-mode section pairs each arming shape with a
# transcript that only mentions the names, and the content-key section pairs
# each section change with an edit that leaves the sections alone.
#
# THE SEGMENTATION SWEEP READS ITS CHARACTERS OUT OF THE GUARD rather than out
# of a list retyped here, so a character added to the guard's segmentation list
# without an assertion beside it fails instead of passing in silence. Both
# lengths are read for the same reason: an extraction that came back one
# character long would shrink that sweep to a single assertion and nothing
# would fail.
set -ufo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/../.." && pwd -P)
GUARD="${HERE}/plan-invariants-guard.sh"
HOOKS="${ROOT}/hooks/hooks.json"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK" "$PROJ" "$PLAIN"' EXIT INT TERM

# Built under /tmp rather than $TMPDIR so the project directory and its physical
# spelling can diverge the way they do on a real checkout: /tmp is a symlink to
# /private/tmp here, and the guard resolves physically.
PROJ=$(mktemp -d /tmp/gh116-guard.XXXXXX)
PLAIN=$(mktemp -d /tmp/gh116-plain.XXXXXX)

# A mutant copy resolves its own siblings from its own directory, so the two it
# calls are copied beside it. Without them every mutant exits at the
# harness-managed guard and each control below passes while measuring nothing.
cp "${HERE}/harness-managed.sh" "${HERE}/plugin-ref.sh" "$WORK/"

# Session transcripts. ARMED carries a slash-command run of /improve and
# SKILLRUN a Skill tool call to /improve-global. MENTIONS carries the names in
# every place they appear WITHOUT a run: the skill listing, a tool result quoting
# the slash-command text, a tool call quoted in prose, a request typed in prose.
# LONG puts the run first and enough mentions after it that jq stops before grep
# finishes, the shape on which a verdict read from the pipeline status loses the
# run to SIGPIPE.
ARMED="${WORK}/armed.jsonl"
SKILLRUN="${WORK}/skillrun.jsonl"
MENTIONS="${WORK}/mentions.jsonl"
LONG="${WORK}/long.jsonl"
listing='{"type":"attachment","attachment":{"type":"skill_listing","content":"harness:improve harness:improve-global"}}'
slash='{"type":"user","message":{"content":"<command-message>harness:improve</command-message>\n<command-name>/harness:improve</command-name>"}}'
printf '%s\n' "$listing" "$slash" > "$ARMED"
printf '%s\n' "$listing" \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"harness:improve-global"}}]}}' \
  > "$SKILLRUN"
printf '%s\n' "$listing" \
  '{"type":"user","message":{"content":[{"type":"tool_result","content":"<command-message>harness:improve</command-message>"}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"next: {\"name\":\"Skill\",\"input\":{\"skill\":\"harness:improve\"}}"}]}}' \
  '{"type":"user","message":{"content":"run /harness:improve later"}}' \
  > "$MENTIONS"
{ printf '%s\n' "$slash"; i=0; while [ "$i" -lt 20000 ]; do printf '%s\n' "$listing"; i=$((i+1)); done; } > "$LONG"
TRANSCRIPT="$ARMED"

# The default edit adds a heading, so it changes the element signature.
NEWHEAD=$'## Approach\n## Verification'

PROTECTED_PAGES='agents/spec-writer.md
agents/design.md
agents/design-review.md
skills/task/SKILL.md
skills/task/reference.md
scripts/deliberate-absence.sh'

NEAR_MISSES='agents/self-review.md
agents/review-findings.md
docs/templates/progress-format.md
docs/agents-method.md
hooks/hooks.json
scripts/check-redline.sh
scripts/test-check-redline.sh
skills/interview/SKILL.md
docs/workflow.md'

build_tree(){ # <root>
  for rel in $PROTECTED_PAGES $NEAR_MISSES SKILL.md; do
    case "$rel" in */*) mkdir -p "$1/${rel%/*}" ;; esac
    : > "$1/$rel"
  done
}
build_tree "$PROJ"
build_tree "$PLAIN"
: > "$PROJ/AGENTS.md"
check "the managed fixture carries the marker the guard keys on" \
  "$( [ -f "$PROJ/AGENTS.md" ] && echo yes || echo no )" "yes"
check "the unmanaged fixture carries neither marker" \
  "$( { [ -f "$PLAIN/AGENTS.md" ] || [ -d "$PLAIN/ai-docs" ]; } && echo yes || echo no )" "no"

# Invoked BY PATH, the way hooks.json invokes it -- `bash <path>` would pass
# without the execute bit the manifest depends on.
fire(){ # <payload> [root] [guard]
  printf '%s' "$1" \
    | ( cd "${2:-$PROJ}" && CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="${2:-$PROJ}" "${3:-$GUARD}" ) \
      2>"${WORK}/err"
}
decision(){ printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }
reason(){ printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
with_t(){ jq -c --arg t "$1" 'if $t == "" then . else . + {transcript_path: $t} end'; }
sh_payload(){ # <command> [transcript]
  jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | with_t "${2-$TRANSCRIPT}"; }
ed_payload(){ # <path> [old] [new] [transcript]
  jq -nc --arg p "$1" --arg o "${2-## Approach}" --arg n "${3-$NEWHEAD}" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}' | with_t "${4-$TRANSCRIPT}"; }
wr_payload(){ # <path> <content> [transcript]
  jq -nc --arg p "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$p,content:$c}}' \
    | with_t "${3-$TRANSCRIPT}"; }

asks(){ # <label> <payload> [root] [guard]
  d=$(decision "$(fire "$2" "${3:-$PROJ}" "${4:-$GUARD}")")
  check "$1" "${d:-silent}" "ask"
}
silent(){ # <label> <payload> [root] [guard]
  n=$(fire "$2" "${3:-$PROJ}" "${4:-$GUARD}" | wc -c | tr -d ' ')
  check "$1" "$n" "0"
}
sh_asks(){   asks   "$1" "$(sh_payload "$2")" ;}
sh_silent(){ silent "$1" "$(sh_payload "$2")" ;}

printf '\n== the tool arm: every protected page, on an edit that adds a heading ==\n'
for rel in $PROTECTED_PAGES; do
  asks "an edit to ${rel} is put to the author" "$(ed_payload "${PROJ}/${rel}")"
done

printf '\n== the tool arm: the near misses and the outside are silent ==\n'
for rel in $NEAR_MISSES; do
  silent "an edit to the near miss ${rel} is not" "$(ed_payload "${PROJ}/${rel}")"
done
silent "an edit to a path outside the project is not" "$(ed_payload "/private/tmp/design.md")"
silent "an edit to a same-basename unprotected page is not" "$(ed_payload "${PROJ}/SKILL.md")"

printf '\n== the refusal is an ASK, and the reason names the page and the way through ==\n'
out=$(fire "$(ed_payload "${PROJ}/agents/design.md")")
check "the decision is ask, never deny -- an ask proceeds once the author allows it" \
  "$(decision "$out")" "ask"
check "the event name is echoed, as PreToolUse output requires" \
  "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" "PreToolUse"
case "$(reason "$out")" in
  *'agents/design.md'*) ok "the reason names the page" ;;
  *) bad "the reason does not name the page: [$(reason "$out")]" ;;
esac
case "$(reason "$out")" in
  *ALLOWING*proceed*) ok "and it names what would permit the edit" ;;
  *) bad "the reason does not say that allowing it lets the edit proceed" ;;
esac
case "$(reason "$out")" in
  *'/improve'*'adds, removes or renames'*) ok "and it says why it fired: learning mode, and a section changed" ;;
  *) bad "the reason does not name learning mode and the section change: [$(reason "$out")]" ;;
esac
case "$(reason "$out")" in
  *plan-invariants.md*) ok "and it points at the page that holds the membership rule" ;;
  *) bad "the reason cites no authority for the page set" ;;
esac
if grep -qF 'CLAUDE_PLUGIN_ROOT' <<EOF
$out
EOF
then bad "an unexpanded plugin-root token reached the reason"
else ok "no unexpanded plugin-root token in the reason" ; fi

printf '\n== learning mode: armed only in a session that ran /improve or /improve-global ==\n'
P="${PROJ}/agents/design.md"
asks   "a slash-command run of /improve arms it" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$ARMED")"
asks   "a Skill tool call to /improve-global arms it" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$SKILLRUN")"
asks   "a run early in a long transcript still arms it" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$LONG")"
check  "  and the long transcript does stop grep early, so it measures the SIGPIPE shape" \
       "$(grep -F improve "$LONG" | jq -n -R 'any(inputs; true)' >/dev/null 2>&1 && echo no || echo yes)" "yes"
silent "a transcript that only MENTIONS the learning skills does not" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$MENTIONS")"
silent "a payload naming no transcript does not" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" '')"
silent "an unreadable transcript does not" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "${WORK}/absent.jsonl")"
silent "outside learning mode a shell write to a protected page is silent too" \
       "$(sh_payload 'printf x >> agents/design.md' "$MENTIONS")"

printf '\n== learning mode: which runs arm it, by name ==\n'
BARE="${WORK}/bare.jsonl"
AUDIT="${WORK}/audit.jsonl"
OTHER="${WORK}/other.jsonl"
printf '%s\n' '{"type":"user","message":{"content":"<command-message>improve</command-message>"}}' > "$BARE"
printf '%s\n' '{"type":"user","message":{"content":"<command-message>harness:ai-audit</command-message>"}}' > "$AUDIT"
printf '%s\n' '{"type":"user","message":{"content":"<command-message>harness:improve-docs</command-message>"}}' > "$OTHER"
asks   "a run under the bare skill name arms it" "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$BARE")"
asks   "a run of /ai-audit arms it -- its escalation audit edits instruction files" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$AUDIT")"
silent "a run of a skill whose name only STARTS with improve does not" \
       "$(ed_payload "$P" '## Approach' "$NEWHEAD" "$OTHER")"

printf '\n== while armed, an Edit asks only when it changes the page element signature ==\n'
# The page carries every text the cases below replace, so each one is judged by
# the page before it against the page after it -- the route a real edit takes.
printf '%s\n' '## Approach' 'a typo teh' '## Risks' 'old text' \
  'the Collisions section must exist' 'blocking when absent' \
  'a missing `## Risks` is blocking' > "$P"
R="${PROJ}/scripts/deliberate-absence.sh"
printf '%s\n' '# old note' "RETAINED='## Out of scope'" > "$R"
silent "a prose fix touching no heading and no element name is silent" \
       "$(ed_payload "$P" 'a typo teh' 'a typo the')"
silent "an edit under a heading that keeps the heading is silent" \
       "$(ed_payload "$P" $'## Risks\nold text' $'## Risks\nnew text')"
silent "a one-hash comment edit in a script is silent" "$(ed_payload "$R" '# old note' '# new note')"
asks   "a renamed heading asks" "$(ed_payload "$P" '## Risks' '## Hazards')"
asks   "a heading renamed by replacing only the words after the marker asks" \
       "$(ed_payload "$P" $'Risks\nold text' $'Risks and mitigations\nold text')"
asks   "a removed heading asks" "$(ed_payload "$P" $'## Risks\nold text' 'old text')"
asks   "a deeper heading added asks" "$(ed_payload "$P" 'old text' $'old text\n### Rollout')"
asks   "an element name dropped from prose asks" \
       "$(ed_payload "$P" 'the Collisions section must exist' 'the section must exist')"
asks   "an element name added to prose asks" \
       "$(ed_payload "$P" 'blocking when absent' 'blocking when Use cases is absent')"
asks   "a backticked heading added to a rubric asks" \
       "$(ed_payload "$P" 'a missing `## Risks` is blocking' 'a missing `## Risks` or `## Rollout` is blocking')"
silent "  while a prose edit on the same line, after the backticked heading, is silent" \
       "$(ed_payload "$P" 'a missing `## Risks` is blocking' 'a missing `## Risks` is a blocking finding')"
asks   "a quoted list entry added to a script asks" \
       "$(ed_payload "$R" "RETAINED='## Out of scope'" $'RETAINED=\'## Out of scope\n## Rollout\'')"
asks   "an edit whose text is not on the page is judged by its own text: a heading added asks" \
       "$(ed_payload "$P" 'not on the page' $'not on the page\n## Rollout')"
silent "  and the same with no section change is silent" \
       "$(ed_payload "$P" 'not on the page' 'not on this page')"
# replace_all decides which occurrences move: the first one here is prose, the
# second is a heading, so only the replace-every edit changes a section.
RA="${PROJ}/skills/task/reference.md"
printf '%s\n' 'each mitigation is named' '## Hazard mitigation' > "$RA"
ra_payload(){ # <replace_all>
  jq -nc --arg p "$RA" --arg t "$ARMED" --argjson a "$1" \
    '{tool_name:"Edit",tool_input:{file_path:$p,old_string:"mitigation",new_string:"rollback",replace_all:$a},transcript_path:$t}'; }
asks   "a replace_all edit that reaches a heading asks" "$(ra_payload true)"
silent "  while the same edit replacing only the first occurrence, in prose, is silent" "$(ra_payload false)"
: > "$RA"

printf '\n== while armed, a Write is judged against the page it replaces ==\n'
W="${PROJ}/agents/spec-writer.md"
printf '## Scope\nold text\n' > "$W"
silent "a Write that keeps every heading is silent" "$(wr_payload "$W" $'## Scope\nnew text\n')"
asks   "a Write that adds a heading asks" "$(wr_payload "$W" $'## Scope\n## Rollout\n')"
: > "$W"

printf '\n== while armed, a change it cannot read is put to the author ==\n'
mkdir -p "${WORK}/no-record"
out=$(printf '%s' "$(ed_payload "$P" 'teh' 'the')" \
  | ( cd "$PROJ" && CLAUDE_PLUGIN_ROOT="${WORK}/no-record" CLAUDE_PROJECT_DIR="$PROJ" "$GUARD" ) 2>/dev/null)
check  "an unreadable element record fails toward asking" "$(decision "$out")" "ask"
asks   "an edit payload carrying neither content nor strings asks" \
       "$(jq -nc --arg p "$P" --arg t "$ARMED" '{tool_name:"Edit",tool_input:{file_path:$p},transcript_path:$t}')"
chmod 000 "$P"
asks   "an edit to a page that cannot be read asks" "$(ed_payload "$P" 'a typo teh' 'a typo the')"
chmod 644 "$P"
: > "$P"; : > "$R"

printf '\n== the shell arm, direct write forms ==\n'
sh_asks   "an in-place edit fires"            "sed -i '' agents/design.md"
sh_asks   "an append redirect fires"          "printf x >> agents/design.md"
sh_asks   "a truncating redirect fires"       "printf x > agents/design.md"
sh_asks   "a tee -a fires"                    "printf x | tee -a agents/design.md"
sh_asks   "an mv onto a protected page fires" "mv /private/tmp/new.md agents/design.md"
sh_asks   "a dd of= fires"                    "dd if=/dev/null of=agents/design.md"
sh_asks   "an rm fires"                       "rm agents/design.md"
sh_asks   "a git checkout -- fires"           "git checkout -- agents/design.md"

printf '\n== the shell arm, each directory-change-completed form ==\n'
sh_asks   "cd <dir> && <write> fires"         "cd agents && printf x >> design.md"
sh_asks   "cd <dir>; <write> fires too"       "cd agents; printf x >> design.md"
sh_asks   "a chained cd a && cd b fires"      "cd skills && cd task && printf x >> SKILL.md"
sh_asks   "an absolute cd under the project fires" "cd ${PROJ}/agents && printf x >> design.md"
sh_asks   "a loop body inside the changed directory fires" \
          'cd agents && for f in design.md spec-writer.md; do printf x >> $f; done'
sh_asks   "a ../-relative path leading back out fires" \
          "cd skills/task && printf x >> ../../agents/design.md"

printf '\n== PAIRED: a read-only command on the SAME page, per shape the house style uses ==\n'
# Each line below reads the page the line above writes. The pair is the
# assertion: either half alone passes for a guard that is simply always silent,
# or always loud.
sh_silent "a cat is silent"                   "cat agents/design.md"
sh_silent "a sed -n range is silent"          "sed -n '1,20p' agents/design.md"
sh_silent "a grep -n is silent"               "grep -n Approach agents/design.md"
sh_silent "a read-only interpreter script is silent" \
          "python3 -c \"print(open('agents/design.md').read())\""
sh_silent "a cd <dir> && cat <basename> is silent" "cd agents && cat design.md"
sh_silent "a wc over two protected pages is silent" \
          "wc -l agents/design.md agents/spec-writer.md"
sh_silent "a git show of a protected page is silent" "git show HEAD:agents/design.md"
sh_silent "a diff between two protected pages is silent" \
          "diff agents/design.md agents/design-review.md"

printf '\n== the write-operand rule: a write construct is not enough on its own ==\n'
sh_silent "a read whose redirect target resolves outside the project is silent" \
          "cat agents/design.md > /private/tmp/x"
sh_silent "a cp whose SOURCE is protected is silent" \
          "cp agents/design.md /private/tmp/x"
sh_silent "a write to an unprotected page is silent" \
          "printf x >> agents/self-review.md"
sh_silent "a write to a path outside the project is silent" \
          "printf x >> /private/tmp/design.md"

printf '\n== PAIRED: the bundled in-place short-flag cluster ==\n'
sh_asks   "perl -pi -e fires"                 "perl -pi -e 's/a/b/' agents/design.md"
sh_asks   "sed -Ei fires"                     "sed -Ei 's/a/b/' agents/design.md"
sh_silent "perl -ne on the same page is silent" "perl -ne 'print' agents/design.md"
sh_silent "sed -n on the same page is silent"   "sed -n 1p agents/design.md"

printf '\n== PAIRED: the -t destination, which reads the operand list backwards if mistaken ==\n'
sh_asks   "cp -t <protected dir> <source> fires" "cp -t agents /private/tmp/design.md"
sh_silent "cp -t <outside dir> <protected source> is silent" \
          "cp -t /private/tmp agents/design.md"

printf '\n== PAIRED: the narrowed interpreter operand, which the house analysis idiom walks into ==\n'
sh_silent "a script that READS a protected page and writes a scratch artefact is silent" \
          "python3 -c \"open('/private/tmp/o','w').write(open('agents/design.md').read())\""
sh_asks   "a script that opens the SAME page for writing fires" \
          "python3 -c \"open('agents/design.md','w').write('x')\""
sh_asks   "a heredoc script that opens it for writing fires" \
          "$(printf 'python3 <<%s\nopen(%sagents/design.md%s,%sw%s).write(%sx%s)\nPY\n' "'PY'" "'" "'" "'" "'" "'" "'")"
sh_silent "a read-only heredoc script is silent" \
          "$(printf 'python3 <<%s\nprint(open(%sagents/design.md%s).read())\nPY\n' "'PY'" "'" "'")"
sh_asks   "a write_text onto a protected page fires" \
          "python3 -c \"import pathlib; pathlib.Path('agents/design.md').write_text('x')\""
sh_asks   "an os.rename onto a protected page fires" \
          "python3 -c \"import os; os.rename('/private/tmp/a','agents/design.md')\""
sh_asks   "a shutil.move onto a protected page fires" \
          "python3 -c \"import shutil; shutil.move('/private/tmp/a','agents/design.md')\""

printf '\n== PAIRED: a separator inside a quoted span, every character and both quote spellings ==\n'
# The characters come from the guard's own assignment, not from a list retyped
# here. Each in-place write below was silent before the neutralisation existed:
# the padding replaces both quote characters with spaces and the translation
# feeding the segment loop cuts on all eight, so the in-place writer and the
# resolved path landed in different segments, each missing the other. Each one
# is paired with a READ of the same page in the same spelling, because a repair
# that bought its confirmations by firing on reads would cost more than the hole.
SEPS=$(sed -n "s/^SEGMENT_SEPARATORS='\(.*\)'\$/\1/p" "$GUARD")
TRREPL=$(sed -n 's/.*tr "$SEGMENT_SEPARATORS" .\(.*\).).*/\1/p' "$GUARD")
check "the segmentation characters were read out of the guard" \
  "$( [ -n "$SEPS" ] && echo yes || echo no )" "yes"
# Both presences are asserted before the lengths are compared, because two empty
# extractions agree at zero and that agreement would read exactly like the real
# one while the sweep below ran no assertion at all.
check "and so was the translation's replacement it has to agree with" \
  "$( [ -n "$TRREPL" ] && echo yes || echo no )" "yes"
check "the list and the translation's replacement agree in length" \
  "${#SEPS}" "$(( ${#TRREPL} / 2 ))"
# `sep` and `esc`, not the obvious short names: `asks` assigns `d` and the loop
# body calls it between building the write shape and building the paired read,
# so a loop variable named `d` is empty by the time the read is spelled. Measured
# -- the read half of every pair ran against a delimiter-free command and passed
# for the wrong reason, which the label printing an empty [] is what exposed.
k=1
while [ "$k" -le "${#SEPS}" ]; do
  sep=$(printf '%s' "$SEPS" | cut -c"$k")
  # A literal backtick inside a double-quoted span is spelled escaped, which is
  # how a shell carries one there; unescaped it opens a command substitution and
  # the shape stops being a command anybody would run.
  case "$sep" in '`') esc="\\${sep}" ;; *) esc="$sep" ;; esac
  sh_asks   "an in-place write whose script is delimited by [${sep}] fires" \
            "sed -i '' 's${sep}a${sep}b${sep}g' agents/design.md"
  sh_asks   "  and so does the double-quoted spelling of it, [${esc}]" \
            "sed -i '' \"s${esc}a${esc}b${esc}g\" agents/design.md"
  sh_silent "  while a READ of the same page delimited by [${sep}] is silent" \
            "sed -n 's${sep}a${sep}b${sep}p' agents/design.md"
  sh_silent "  and so is the double-quoted read, [${esc}]" \
            "sed -n \"s${esc}a${esc}b${esc}p\" agents/design.md"
  k=$((k+1))
done

printf '\n== PAIRED: a separator a BACKSLASH escapes, outside any quoted span ==\n'
# The cousin of the loop above, and the seventh residual form until the walk
# learned the escape: the separator is data to the shell here too, but it sits
# in no quoted span, so a walk reading quote state alone never reached it. Swept
# over the same characters, read out of the guard rather than retyped, and every
# write PAIRED with a READ in the identical spelling -- a repair that bought its
# confirmations by firing on reads would cost more than the hole.
#
# THE ORDER INSIDE THE GUARD IS WHAT MAKES THIS CLOSE. Measured with the walk
# after the padding instead: seven of these eight fired and the statement
# separator alone stayed silent, because the padding had already put a space
# between the backslash and the character it escaped.
k=1
while [ "$k" -le "${#SEPS}" ]; do
  sep=$(printf '%s' "$SEPS" | cut -c"$k")
  sh_asks   "an in-place write whose script delimiter is an escaped [${sep}] fires" \
            "sed -i '' s\\${sep}a\\${sep}b\\${sep}g agents/design.md"
  sh_silent "  while a READ of the same page in that spelling is silent" \
            "sed -n s\\${sep}a\\${sep}b\\${sep}p agents/design.md"
  k=$((k+1))
done

printf '\n== PAIRED: the same blindness in the other spellings the house style reaches for ==\n'
sh_asks   "an alternate script flag carries it"               "sed -i '' -e 's|a|b|g' agents/design.md"
sh_silent "  while the read spelling of that is silent"       "sed -n -e 's|a|b|p' agents/design.md"
sh_asks   "a brace-delimited address block carries it"        "sed -i '' '1{s/a/b/;}' agents/design.md"
sh_silent "  while a brace-delimited read is silent"          "sed -n '1,5{p;}' agents/design.md"
sh_asks   "an interpreter spelling of the same edit fires"    "perl -pi -e 's|a|b|' agents/design.md"
sh_silent "  while the interpreter's read spelling is silent" "perl -ne 's|a|b|' agents/design.md"
sh_asks   "backticked text replaced inside a double-quoted script fires" \
          "sed -i '' \"s/\\\`old\\\`/\\\`new\\\`/g\" agents/design.md"
sh_silent "  while a grep over backticked text is silent"     "grep -n \"a\\\`b\\\`c\" agents/design.md"
sh_asks   "reached through a leading cd it still fires"       "cd agents && sed -i '' 's|a|b|g' design.md"
sh_silent "  while the same cd with a read is silent"         "cd agents && grep -n 'a|b' design.md"

printf '\n== the basename collision the resolution exists to get right ==\n'
# SKILL.md names two protected pages and eleven unprotected ones; reference.md
# one of four. A basename arm would over-fire on all of the rest.
sh_asks   "cd skills/task && write to SKILL.md fires"  "cd skills/task && printf x >> SKILL.md"
sh_silent "cd skills/interview && write to SKILL.md is silent" \
          "cd skills/interview && printf x >> SKILL.md"
sh_silent "a write to a root-level SKILL.md is silent" "printf x >> SKILL.md"
sh_silent "a mixed-directory command whose write targets a root-level file is silent" \
          "printf x >> SKILL.md && cd skills/task && cat reference.md"

printf '\n== every near miss is silent through the shell too ==\n'
for rel in $NEAR_MISSES; do
  sh_silent "a write to the near miss ${rel} is silent" "printf x >> ${rel}"
done
sh_silent "and so is a write to a near miss reached through a cd" \
          "cd skills/interview && printf x >> SKILL.md"

printf '\n== the SIX residual forms, every one of them under-firing ==\n'
sh_silent "1. a glob never spells the path as a literal token" \
          "printf x >> agents/design*.md"
sh_silent "2. a command substitution that produces the path" \
          "printf x >> \$(ls agents/de*.md)"
sh_silent "3. a target list read from a file and piped in" \
          "xargs -0 -n1 sed -i '' < targets.txt"
sh_silent "4. a writer whose construct is not on the list" \
          "ex -sc wq agents/design.md"
sh_silent "5. an interpreter script's variable-indirected writer" \
          "python3 -c \"p='agents/design.md'; open(p,'w').write('x')\""
sh_silent "6a. a directory change that is not a leading prefix -- subshell" \
          "(cd agents && printf x >> design.md)"
sh_silent "6b. the same, behind a guard command" \
          "true && cd agents && printf x >> design.md"

printf '\n== POSITIVE CONTROL: drop the write condition, a read is refused ==\n'
MUT_W="${WORK}/no-write-condition.sh"
sed 's@^    tee|patch|truncate|shred|rm|install|ed|git-write)$@    *)@' "$GUARD" > "$MUT_W"
chmod +x "$MUT_W"
if cmp -s "$GUARD" "$MUT_W"; then
  bad "the write-condition mutation did not apply, so this control measures nothing"
else
  ok "the mutation applied"
  d=$(decision "$(fire "$(sh_payload 'cat agents/design.md')" "$PROJ" "$MUT_W")")
  check "  without it, a cat of a protected page is put to the author" "${d:-silent}" "ask"
fi

printf '\n== POSITIVE CONTROL: drop the resolution, the cd-completed write escapes ==\n'
MUT_R="${WORK}/no-resolution.sh"
sed 's@^join_dir() {.*@join_dir() { printf %s "$1"; }@' "$GUARD" > "$MUT_R"
chmod +x "$MUT_R"
if cmp -s "$GUARD" "$MUT_R"; then
  bad "the resolution mutation did not apply, so this control measures nothing"
else
  ok "the mutation applied"
  # The direct spelling is the non-vacuity witness: an empty result is also what
  # a mutant that died before reading its input produces, and that reading would
  # satisfy the silence below without measuring the resolution at all.
  d=$(decision "$(fire "$(sh_payload 'printf x >> agents/design.md')" "$PROJ" "$MUT_R")")
  check "  the mutant still fires on the directly spelled path, so it is running" "${d:-silent}" "ask"
  n=$(fire "$(sh_payload 'cd agents && printf x >> design.md')" "$PROJ" "$MUT_R" | wc -c | tr -d ' ')
  check "  and without the resolution, cd <dir> && <write> walks straight past it" "$n" "0"
fi

printf '\n== POSITIVE CONTROL: drop the neutralisation, the quoted separator escapes again ==\n'
MUT_Q="${WORK}/no-separator-neutralisation.sh"
sed 's@^\[ -n "$neutralised" \].*@: @' "$GUARD" > "$MUT_Q"
chmod +x "$MUT_Q"
if cmp -s "$GUARD" "$MUT_Q"; then
  bad "the neutralisation mutation did not apply, so this control measures nothing"
else
  ok "the mutation applied"
  # The slash-delimited spelling is the non-vacuity witness: an empty result is
  # also what a mutant that died before reading its input produces, and that
  # reading would satisfy both silences below while measuring nothing.
  d=$(decision "$(fire "$(sh_payload "sed -i '' 's/a/b/g' agents/design.md")" "$PROJ" "$MUT_Q")")
  check "  the mutant still fires on the slash-delimited spelling, so it is running" "${d:-silent}" "ask"
  n=$(fire "$(sh_payload "sed -i '' 's|a|b|g' agents/design.md")" "$PROJ" "$MUT_Q" | wc -c | tr -d ' ')
  check "  and without it the single-quoted separator walks straight past" "$n" "0"
  n=$(fire "$(sh_payload "sed -i '' \"s|a|b|g\" agents/design.md")" "$PROJ" "$MUT_Q" | wc -c | tr -d ' ')
  check "  and so does the double-quoted spelling" "$n" "0"
  # The paired read was silent under the mutant too, which is what makes the
  # pair a discriminator rather than two readings of one state.
  n=$(fire "$(sh_payload "sed -i '' s\\|a\\|b\\|g agents/design.md")" "$PROJ" "$MUT_Q" | wc -c | tr -d ' ')
  check "  and so does the backslash-escaped spelling, which the same walk closes" "$n" "0"
  n=$(fire "$(sh_payload "sed -n 's|a|b|p' agents/design.md")" "$PROJ" "$MUT_Q" | wc -c | tr -d ' ')
  check "  while the paired read was already silent, so the pair is what discriminates" "$n" "0"
fi

printf '\n== an unmanaged project is a no-op, and the guard is what makes it one ==\n'
silent "a protected-shaped edit in an unmanaged project is silent" \
  "$(ed_payload "${PLAIN}/agents/design.md")" "$PLAIN"
silent "and so is a protected-shaped write through the shell" \
  "$(sh_payload 'printf x >> agents/design.md')" "$PLAIN"
MUT_M="${WORK}/unguarded.sh"
sed 's@^"${HERE}/harness-managed.sh" || exit 0$@: @' "$GUARD" > "$MUT_M"
chmod +x "$MUT_M"
if cmp -s "$GUARD" "$MUT_M"; then
  bad "the managed-guard mutation did not apply, so the no-op above measures nothing"
else
  ok "the mutation applied"
  d=$(decision "$(fire "$(ed_payload "${PLAIN}/agents/design.md")" "$PLAIN" "$MUT_M")")
  check "  without the guard, the same edit in the same unmanaged project IS judged" "${d:-silent}" "ask"
fi

printf '\n== nothing it does can cost the session a tool call ==\n'
check "empty stdin -> 0"    "$(printf '' | "$GUARD" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON -> 0" "$(printf 'not json' | "$GUARD" >/dev/null 2>&1; echo $?)" "0"
check "malformed JSON emits nothing" \
  "$(printf 'not json' | "$GUARD" 2>/dev/null | wc -c | tr -d ' ')" "0"
check "an ask still exits 0" \
  "$(printf '%s' "$(ed_payload "${PROJ}/agents/design.md")" | ( cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" CLAUDE_PLUGIN_ROOT="$ROOT" "$GUARD" ) >/dev/null 2>&1; echo $?)" "0"
silent "a payload carrying neither a path nor a command is silent" '{"tool_name":"Bash","tool_input":{}}'

printf '\n== it is wired into the manifest on BOTH matchers ==\n'
# An unregistered guard's page list would otherwise read as coverage, so the
# agreement leg of scripts/check-plan-invariants.sh depends on this pair.
for m in 'Edit|Write' 'Bash'; do
  n=$(jq -r --arg m "$m" \
    '[.hooks.PreToolUse[] | select(.matcher==$m) | .hooks[].command
      | select(test("hooks/lib/plan-invariants-guard\\.sh"))] | length' "$HOOKS")
  check "registered under matcher ${m}" "$n" "1"
done
for m in 'Edit|Write' 'Bash'; do
  c=$(jq -r --arg m "$m" \
    '.hooks.PreToolUse[] | select(.matcher==$m) | .hooks[].command
     | select(test("plan-invariants-guard"))' "$HOOKS")
  check "the ${m} entry yielded a command to inspect" "$( [ -n "$c" ] && echo yes || echo no )" "yes"
  case "$c" in
    *'"${CLAUDE_PLUGIN_ROOT}"/hooks/lib/plan-invariants-guard.sh'*)
      ok "  invoked by its plugin-root path, double-quoted" ;;
    *) bad "  the ${m} command is not the quoted plugin-root path: [$c]" ;;
  esac
done
# The propagation gate extracts the FIRST entry of this group and reads its
# inline arm pattern, so appending is the registration that leaves what that
# gate computes untouched.
FIRST=$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Edit|Write") | .hooks[0].command' "$HOOKS")
case "$FIRST" in
  *'propagation-rule-reminder'*) ok "the file-editing group's first entry is still the propagation reminder" ;;
  *) bad "the guard was inserted ahead of the propagation reminder, which changes what the arms gate extracts" ;;
esac
check "the entry point the manifest invokes by path is executable" \
  "$(git -C "$ROOT" ls-files -s hooks/lib/plan-invariants-guard.sh | awk '{print $1}')" "100755"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
