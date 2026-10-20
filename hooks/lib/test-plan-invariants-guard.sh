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
# read of the seven most-read pages, and a refusal that loud is the kind that
# gets switched off -- which costs the whole protection rather than one prompt.
# So each write assertion is paired with a read of the SAME page, and the pair is
# what discriminates rather than either half.
#
# THE OPERAND RULES ARE EACH PINNED BY A PAIR for the same reason. The in-place
# short-flag cluster, the `-t` destination and the narrowed interpreter operand
# all have a direction in which the obvious spelling fails, and a single-ended
# assertion cannot see it.
#
# THE SEVEN RESIDUAL FORMS ARE ASSERTED SILENT so the stated bound is a measured
# fact rather than a claim. Every one of them under-fires, which is the property
# that matters: there is no shape on which the house style meets a refusal it
# would want switched off.
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

PROTECTED_PAGES='agents/spec-writer.md
agents/design.md
agents/design-review.md
skills/redline-fold/SKILL.md
skills/task/SKILL.md
skills/task/reference.md
scripts/check-redline.sh'

NEAR_MISSES='agents/self-review.md
agents/review-findings.md
docs/templates/progress-format.md
docs/agents-method.md
hooks/hooks.json
scripts/test-check-redline.sh
skills/interview/SKILL.md
docs/workflow.md'

# The record is guarded by a list of its own, so it is named here by itself. It
# is NOT one of the protected pages: it defines no required element, and the
# verification's refusal-agreement leg would report it as a surplus
# interruption if the guard carried it in that list.
RECORD='ai-docs/fixtures/plan-invariants.inventory'
VERIFICATION='scripts/check-plan-invariants.sh'

build_tree(){ # <root>
  for rel in $PROTECTED_PAGES $NEAR_MISSES $VERIFICATION SKILL.md; do
    case "$rel" in */*) mkdir -p "$1/${rel%/*}" ;; esac
    : > "$1/$rel"
  done
}
build_tree "$PROJ"
build_tree "$PLAIN"
: > "$PROJ/AGENTS.md"
# The record is created in the MANAGED fixture only. Its directory is one of the
# two markers the harness-managed guard keys on, so creating it in the unmanaged
# fixture would make that fixture managed and every no-op assertion below would
# pass for the wrong reason -- measured, by doing exactly that.
mkdir -p "$PROJ/${RECORD%/*}"
: > "$PROJ/$RECORD"
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
sh_payload(){ jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
ed_payload(){ jq -nc --arg p "$1" '{tool_name:"Edit",tool_input:{file_path:$p}}'; }

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

printf '\n== the tool arm: every protected page, whatever the edit touches ==\n'
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
  *'whatever the edit touches'*) ok "and it says the refusal inspects nothing about the edit" ;;
  *) bad "the reason does not state that the refusal is page-wide" ;;
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

printf '\n== the record: both firing directions, because neither is observable from the other ==\n'
asks   "an edit to the record is put to the author" "$(ed_payload "${PROJ}/${RECORD}")"
sh_asks "a shell write to the record fires"         "printf x >> ${RECORD}"
sh_silent "a READ of the record is silent"          "cat ${RECORD}"
sh_silent "and so is a sed -n range over it"        "sed -n '1,5p' ${RECORD}"

out=$(fire "$(ed_payload "${PROJ}/${RECORD}")")
case "$(reason "$out")" in
  *"$RECORD"*) ok "the reason names the record" ;;
  *) bad "the reason does not name the record: [$(reason "$out")]" ;;
esac
# The record is refused for a different reason from a protected page, so the
# message carries that reason rather than one that covers both loosely.
case "$(reason "$out")" in
  *'recorded statement inventory'*) ok "and says why levelling it is what is being authorised" ;;
  *) bad "the record's refusal does not say why the record is guarded" ;;
esac
case "$(reason "$out")" in
  *'defines or enforces a required element'*)
    bad "the record's refusal claims it defines a required element, which it does not" ;;
  *) ok "and does not claim the record defines a required element" ;;
esac

printf '\n== the acceptance route: a third condition class, matching the INVOCATION ==\n'
# An acceptance run rewrites the record with no write construct anywhere in the
# command, so neither of the arm's other two conditions can see it.
sh_asks "an acceptance run fires"                      "bash ${VERIFICATION} --accept"
sh_asks "and so does one with a root override first"   "bash ${VERIFICATION} --root . --accept"
sh_asks "and one reached through a leading cd"         "cd scripts && bash check-plan-invariants.sh --accept"
sh_silent "while an ORDINARY run of the same check is silent" "bash ${VERIFICATION}"
sh_silent "and a read of the entry point is silent"    "cat ${VERIFICATION}"
sh_silent "and an edit to the entry point is not refused -- it is not guarded" \
          "printf x >> ${VERIFICATION}"

# The fast path returns early on a command naming no guarded basename, and an
# acceptance invocation names the verification rather than the record. If the
# entry point's own basename were not in that token set, every assertion above
# would pass for the wrong reason -- the mutant shows the token set is what
# carries them.
MUT_A="${WORK}/no-verification-token.sh"
sed 's@^for q in \$PROTECTED \$GUARDED_RECORD \$VERIFICATION; do$@for q in $PROTECTED $GUARDED_RECORD; do@' \
  "$GUARD" > "$MUT_A"
chmod +x "$MUT_A"
if cmp -s "$GUARD" "$MUT_A"; then
  bad "the fast-path mutation did not apply, so this control measures nothing"
else
  ok "the mutation applied"
  d=$(decision "$(fire "$(sh_payload "printf x >> ${RECORD}")" "$PROJ" "$MUT_A")")
  check "  the mutant still fires on a write to the record, so it is running" "${d:-silent}" "ask"
  n=$(fire "$(sh_payload "bash ${VERIFICATION} --accept")" "$PROJ" "$MUT_A" | wc -c | tr -d ' ')
  check "  and without the entry point's token the acceptance run walks straight past" "$n" "0"
fi

printf '\n== the acceptance condition'"'"'s two residuals, both under-firing ==\n'
sh_silent "1. the payload invoked directly never spells the entry point" \
          "python3 scripts/check-plan-invariants.py . accept ${RECORD}"
sh_silent "2. the acceptance flag reached through a variable set in another call" \
          "bash ${VERIFICATION} \"\$ACCEPT_FLAG\""
# The neighbouring case that is NOT a residual, and the pair is what shows where
# the boundary sits: assigning the flag in the SAME command still spells it in
# the string this condition matches, so that spelling fires. The residual is
# only a flag the command string does not carry at all.
sh_asks "while assigning the flag in the same command still fires" \
        "F=--accept; bash ${VERIFICATION} \$F"

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
sh_asks   "and it fires on the guarded record, which the same arm reads" \
          "sed -i '' 's|a|b|g' ${RECORD}"
sh_silent "  while a read of the record in that spelling is silent" "grep -n 'a|b' ${RECORD}"

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

printf '\n== the record is guarded by a list of its OWN, not by the protected-page list ==\n'
# The verification compares PROTECTED against the protected-page table in both
# directions, so a record admitted to that list would be reported as a surplus
# interruption. Asserted here as well as there, because this is the file whose
# data the other one reads.
PROT=$(sed -n "/^PROTECTED='/,/'$/p" "$GUARD")
case "$PROT" in
  *"$RECORD"*) bad "the record is inside PROTECTED, which the refusal-agreement leg will report as surplus" ;;
  *) ok "the record is absent from PROTECTED" ;;
esac
REC=$(sed -n "/^GUARDED_RECORD='/,/'$/p" "$GUARD")
case "$REC" in
  *"$RECORD"*) ok "and present in the one-member list of its own" ;;
  *) bad "GUARDED_RECORD does not name the record: [$REC]" ;;
esac
case "$PROT" in
  *'agents/design.md'*) ok "while PROTECTED still carries the pages that do define an element" ;;
  *) bad "PROTECTED no longer carries agents/design.md, so the extraction above is reading nothing" ;;
esac

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
