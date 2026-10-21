#!/usr/bin/env bash
#
# PreToolUse(Bash): refuse a content search that could put the bytes of a
# deployed-configuration file into context.
#
# THE RULE IS THE METHOD SURFACE'S, NOT THIS FILE'S. Deployed configuration is
# ASK-gated in docs/agents-method.md section Permissions, and that gate binds on
# ANY tool that surfaces a file's CONTENTS -- a content search IS a read of it,
# and an allow-listed search tool prompts for nothing. This script is the
# machine half of that honour-system rule.
#
# WHY THE FILE CLASS IS NOT WRITTEN DOWN HERE. It used to be: two arms keyed to
# one stack's configuration filenames and one build tool's source layout, in a
# file that ships to every project. Three costs, all measured. A project whose
# environment-specific values live anywhere else got no gate at all. A project
# built the same way as the author's got a gate whose remedy handed it that
# stack's file globs. And the filename appearing ANYWHERE in the command string
# fired the refusal, so a legitimate verification search was refused for
# QUOTING the name in its pattern -- the detection could not tell a mention from
# a read. The class is now the project's own declaration, read at search time
# from the `Deployed-config globs` line of its ai-docs/context.md, and the
# detection keys on FILE FILTERS and on operands that name a file which exists,
# never on a bare occurrence of a name.
#
# A project that declares nothing, or declares `none`, is silent here. That is
# deliberate: a class this script invented would be the defect above wearing a
# default's clothes, and the honour-system rule binds on the agent either way.
#
# Exit: 0 silent, 2 refused.
#
# Behaviour is asserted by scripts/test-hook-behaviour.sh, which runs this
# command through its manifest triple and controls the mention-is-not-a-read
# case the rewrite exists for.

set -uo pipefail

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$CMD" ] || exit 0

# Quotes come off so a quoted filter reads the same as a bare one.
C=$(printf '%s' "$CMD" | tr -d '"' | tr -d "'")

# Only a content search can surface a file's bytes this way.
printf '%s' "$C" | grep -qE '(^|[ ;&|`])(grep|rg|git[[:space:]]+grep)([[:space:]]|$)' || exit 0

PROFILE="${CLAUDE_PROJECT_DIR:-$PWD}/ai-docs/context.md"
# An unfilled template placeholder is not a declaration, and reading one as a
# glob would give the guard a class that can match nothing while reporting that
# it has one. A scaffolded project that has not filled the row is silent here,
# and the project audit is what flags the unresolved placeholder.
GLOBS=$(grep '^\*\*Deployed-config globs:\*\*' "$PROFILE" 2>/dev/null \
        | head -1 | grep -oE '`[^`]+`' | tr -d '`' | grep -v '^%.*%$')
[ -n "$GLOBS" ] || exit 0
case " $(printf '%s' "$GLOBS" | tr '\n' ' ') " in *' none '*) exit 0 ;; esac

# One unanchored ERE per declared glob, alternated. Escaping runs BEFORE `*`
# becomes `.*`, so a literal dot in a declared name cannot survive as a
# wildcard. Unanchored on purpose: the comparison is between two GLOBS, and a
# filter spelled `*<class>*` shares no anchor with the class it names while
# plainly naming it.
PAT=$(printf '%s\n' "$GLOBS" \
      | sed -e 's/[][\\^$.|?+(){}]/\\&/g' -e 's/\*/.*/g' \
      | tr '\n' '|' | sed 's/|$//')
[ -n "$PAT" ] || exit 0

# Every file-filter value in the command, tagged `inc` or `exc`. A flag may
# carry its value joined (`--include=X`, `-gX`) or as the next token
# (`--include X`, `-g X`), and a value prefixed `!` is a NEGATED glob whatever
# flag carried it -- which is an exclusion, so it is retagged rather than read
# as a filter that selects the class.
FILTERS=$(printf '%s\n' "$C" | tr ' \t' '\n\n' | awk '
  function emit(k, v) { if (v ~ /^!/) { k = "exc"; sub(/^!/, "", v) } print k " " v }
  BEGIN { pend = 0; kind = "" }
  {
    t = $0
    if (t == "") next
    if (pend) { emit(kind, t); pend = 0; next }
    if (t ~ /^--(include|exclude|glob|iglob)=/) {
      kind = (t ~ /^--exclude=/) ? "exc" : "inc"
      sub(/^--[a-z]+=/, "", t); emit(kind, t); next
    }
    if (t ~ /^--(include|exclude|glob|iglob)$/) {
      kind = (t == "--exclude") ? "exc" : "inc"; pend = 1; next
    }
    if (t ~ /^-g./) { sub(/^-g/, "", t); emit("inc", t); next }
    if (t == "-g")  { kind = "inc"; pend = 1; next }
  }')

# An explicit exclusion of the class is the sanctioned way past this gate.
printf '%s\n' "$FILTERS" | sed -n 's/^exc //p' | grep -qE "$PAT" && exit 0

HIT=''
printf '%s\n' "$FILTERS" | sed -n 's/^inc //p' | grep -qE "$PAT" \
  && HIT='a file filter that can match a declared deployed-config glob'

# The operand arm. A token that matches the class is read as a PATH only when a
# file of that name exists, which is what separates an operand from a search
# pattern that quotes the name -- the distinction the old spelling could not
# make. Flags are skipped so a filter value is not counted twice.
if [ -z "$HIT" ]; then
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case "$t" in -*) continue ;; esac
    printf '%s' "$t" | grep -qE "$PAT" || continue
    [ -f "$t" ] || continue
    HIT='an operand naming an existing deployed-config file'
    break
  done <<TOKENS
$(printf '%s\n' "$C" | tr ' \t' '\n\n')
TOKENS
fi

[ -n "$HIT" ] || exit 0

r="${CLAUDE_PLUGIN_ROOT:-}"
a=$("$r"/hooks/lib/plugin-ref.sh docs/agents-method.md 2>/dev/null)
[ -n "$a" ] || a="${r:+$r/}docs/agents-method.md — correct operation of the plugin requires read access to the plugin directory${r:+ $r}"

printf 'BLOCKED: this content search can surface deployed-config files (%s) — ASK-gated in %s section Permissions. The gate binds on ANY tool that puts the file bytes in context, not just Read.\n\nThe gated class is THIS PROJECT'"'"'S OWN declaration, read from the `Deployed-config globs` line of ai-docs/context.md: %s\n\nDo one of:\n  1. Narrow the filter to the project'"'"'s own SOURCE extensions, as its profile records them, so no declared glob can match.\n  2. Exclude it explicitly. MIND THE SPELLING PER TOOL: a glob-valued exclude flag takes a glob (--exclude=config*.env); ripgrep takes a NEGATED glob (-g "!config*.env"); a REGEX-valued exclude flag needs config.*[.]env$ instead. The glob spelling passed to a regex flag silently misses the environment variants (config-ENVIRONMENT.env), which are the ones carrying deployed overrides.\n  3. For a setting DEFAULT, read the declared default in source — ungated, authoritative, and it does not drift with the deployed file.\n  4. If the DEPLOYED value is genuinely needed, ASK THE USER FIRST, then Read the file directly. The method file gates this on the HONOUR SYSTEM — settings.json has no ask/deny entry for it, so no prompt will stop you. The ask is yours to make.\n\nA clean run of this hook is NOT clearance: it does not catch a bare unfiltered search whose pattern matches a config key, nor a filter so wide that no declared glob appears in it.\n' \
  "$HIT" "$a" "$(printf '%s' "$GLOBS" | tr '\n' ' ')" >&2
exit 2
