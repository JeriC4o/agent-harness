#!/usr/bin/env bash
#
# Guards the plugin manifest against a class of error that loads silently wrong:
# re-declaring a component path that Claude Code already discovers by default.
#
#   "hooks": "./hooks/hooks.json"   ->  Duplicate hooks file detected
#
# The plugin then reports `failed to load` while its skills and agents still
# appear, so everything looks almost fine and the hooks are simply absent.
# Manifest keys exist to add NON-default locations; the defaults are automatic.
#
# Run: bash scripts/test-plugin-manifest.sh

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
M="${ROOT}/.claude-plugin/plugin.json"
MK="${ROOT}/.claude-plugin/marketplace.json"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT INT TERM

printf '\n== manifests parse ==\n'
jq -e . "$M"  >/dev/null 2>&1 && ok "plugin.json parses"      || bad "plugin.json parses"
jq -e . "$MK" >/dev/null 2>&1 && ok "marketplace.json parses" || bad "marketplace.json parses"

printf '\n== required identity ==\n'
[ "$(jq -r '.name' "$M")" = "harness" ] && ok "plugin name is 'harness' (skills invoke as /harness:<skill>)" \
                                        || bad "plugin name is 'harness'"
[ "$(jq -r '.plugins[0].source' "$MK")" = "./" ] && ok "marketplace points at the repo root" \
                                                 || bad "marketplace points at the repo root"
[ "$(jq -r '.plugins[0].name' "$MK")" = "$(jq -r '.name' "$M")" ] && ok "marketplace and plugin names agree" \
                                                                  || bad "marketplace and plugin names agree"

printf '\n== no default location is re-declared ==\n'
# key -> path Claude Code discovers on its own
for pair in "hooks:hooks/hooks.json" "skills:skills/" "agents:agents/" "commands:commands/" \
            "mcpServers:.mcp.json" "lspServers:.lsp.json"; do
  key="${pair%%:*}"; def="${pair#*:}"
  val=$(jq -r --arg k "$key" '.[$k] // empty | if type=="string" then . else (.[0] // empty) end' "$M")
  [ -n "$val" ] || { ok "$key not re-declared"; continue; }
  norm="${val#./}"; norm="${norm%/}"; defn="${def%/}"
  if [ "$norm" = "$defn" ]; then
    bad "$key re-declares the default location ($val) -- the plugin will refuse to load it twice"
  else
    ok "$key points somewhere non-default ($val)"
  fi
done

printf '\n== declared paths exist ==\n'
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -e "${ROOT}/${p#./}" ] && ok "exists: $p" || bad "declared path missing: $p"
done <<EOF
$(jq -r '[.skills?, .commands?, .agents?, .hooks?, .workflows?] | flatten | map(select(type=="string")) | .[]' "$M" 2>/dev/null)
EOF

printf '\n== no hook command carries an interior apostrophe ==\n'
# FOURTH recurrence of one hazard. A hook command is a shell program inside a
# JSON string, and its human-readable message is a single-quoted printf format.
# An apostrophe in "the agent's default" or "the row's bounds" CLOSES that
# string: the hook then dies on a syntax error at dispatch, so it silently
# stops gating while `jq .` still reports the manifest as valid JSON. Prose
# review does not catch it -- the sentence reads perfectly.
HOOKS="${ROOT}/hooks/hooks.json"
apos=$(jq -r '.hooks[][] | .hooks[] | .command' "$HOOKS" | grep -c "[A-Za-z]'[A-Za-z]" || true)
check "zero interior apostrophes across all hook commands" "$apos" "0"
if [ "$apos" != "0" ]; then jq -r '.hooks[][] | .hooks[] | .command' "$HOOKS" | grep -o ".\{0,40\}[A-Za-z]'[A-Za-z].\{0,40\}"; fi

printf '\n== and every hook command is syntactically valid shell ==\n'
# The positive control for the check above: an apostrophe-broken command fails
# HERE too, and this leg also catches every other way the string can break.
i=0
while IFS= read -r cmd; do
  i=$((i+1))
  printf '%s' "$cmd" > "${TMPD}/hook.$i.sh"
  if bash -n "${TMPD}/hook.$i.sh" 2>/dev/null; then ok "hook command $i parses"; else bad "hook command $i is not valid shell"; fi
done <<EOF
$(jq -r '.hooks[][] | .hooks[] | .command' "$HOOKS")
EOF

printf '\n== every plugin-root occurrence in a hook command is double-quoted ==\n'
# WHY THIS IS A PROPERTY OF EACH OCCURRENCE rather than an inference about
# quoting regions: exactly one of the 18 commands has ODD apostrophe parity
# (`tr -d "'"` inside double quotes), so a parity walk misclassifies the whole
# remainder of that command -- including the prose site it carries, which is the
# class of site this check exists for.
#
# IT KEYS ON THE BRACED TOKEN, CLOSING BRACE INCLUDED. The uniform resolver call
# introduces `${CLAUDE_PLUGIN_ROOT:-}`, a legitimate default-expansion form that
# a bare-name grep flags as non-conforming -- keyed on the bare name this check
# is RED on correct code. The decomposition is asserted below so the two forms
# stay distinguished by measurement rather than by this comment.
BRACED='${CLAUDE_PLUGIN_ROOT}'
DEFAULTED='${CLAUDE_PLUGIN_ROOT:-}'
CMDFILE="${TMPD}/commands.txt"
jq -r '.hooks[][] | .hooks[] | .command' "$HOOKS" > "$CMDFILE"

# Sets UNW, WIN and NONCONF. Invoked BARE and the globals read afterwards: a
# command substitution is a subshell and would discard all three.
count_occurrences(){ # <file, one command per line>
  UNW=$(grep -oF -- "$BRACED" "$1" | wc -l | tr -d ' ')
  WIN=$(grep -o '.\{1\}\${CLAUDE_PLUGIN_ROOT}.\{1\}' "$1" | wc -l | tr -d ' ')
  NONCONF=$(grep -o '.\{1\}\${CLAUDE_PLUGIN_ROOT}.\{1\}' "$1" | grep -cvF -- "\"${BRACED}\"" || true)
}

bare=$(grep -oF -- 'CLAUDE_PLUGIN_ROOT' "$CMDFILE" | wc -l | tr -d ' ')
defaulted=$(grep -oF -- "$DEFAULTED" "$CMDFILE" | wc -l | tr -d ' ')
count_occurrences "$CMDFILE"
check "bare-name occurrences decompose into braced plus default-expansion" "$bare" "$((UNW + defaulted))"
ok "  (bare $bare = braced $UNW + default-expansion $defaulted)"

# AC12's CONSERVATION ASSERTION. A one-character window cannot see an occurrence
# at the very start or the very end of a command, so an occurrence that slipped
# to either boundary would be classified by nobody and the property would hold
# over a smaller set than it claims. Counts are compared BEFORE classifying.
check "windowed count equals unwindowed count (no occurrence escapes classification)" "$WIN" "$UNW"
check "every classified occurrence is double-quoted" "$NONCONF" "0"
if [ "$NONCONF" != "0" ]; then grep -o '.\{1\}\${CLAUDE_PLUGIN_ROOT}.\{1\}' "$CMDFILE" | grep -vF -- "\"${BRACED}\""; fi

printf '\n== and both halves of that property are shown able to FAIL ==\n'
# Control 1: an occurrence that is present and NOT double-quoted. It is the
# defect this leg exists for -- an unquoted expansion word-splits on a root
# containing a space, which is the normal shape of an install path on a Mac.
cp "$CMDFILE" "${TMPD}/planted.txt"
printf 'echo %s/docs/agents-method.md\n' "$BRACED" >> "${TMPD}/planted.txt"
count_occurrences "${TMPD}/planted.txt"
check "a planted unquoted occurrence raises the unwindowed count by one" "$UNW" "$((bare - defaulted + 1))"
check "  and is reported as non-conforming" "$NONCONF" "1"
check "  while conservation still holds, so the two legs are independent" "$WIN" "$UNW"

# Control 2: a BOUNDARY occurrence, first character of its command. The
# classifier is structurally blind to it, which is the whole reason conservation
# is asserted rather than assumed.
cp "$CMDFILE" "${TMPD}/boundary.txt"
printf '%s/hooks/lib/x.sh arg\n' "$BRACED" >> "${TMPD}/boundary.txt"
count_occurrences "${TMPD}/boundary.txt"
check "a boundary occurrence at position 0 is counted unwindowed" "$UNW" "$((bare - defaulted + 1))"
check "  but the classifier cannot see it" "$WIN" "$((bare - defaulted))"
[ "$WIN" -ne "$UNW" ] && ok "  so conservation FAILS on it, which is what makes the assertion load-bearing" \
                      || bad "  conservation did not fail on a boundary occurrence -- the assertion proves nothing"

printf '\n== AC20: the resolved path reaches every message as an ARGUMENT ==\n'
# A path interpolated into a printf FORMAT is re-scanned for % directives, so a
# root containing one would consume the next argument. Every reference is
# therefore a captured call assigned to a variable, and the variable is what the
# format receives.
refs=$(grep -oF -- 'plugin-ref.sh' "$CMDFILE" | wc -l | tr -d ' ')
captured=$(grep -oF -- '=$("$r"/hooks/lib/plugin-ref.sh' "$CMDFILE" | wc -l | tr -d ' ')
check "every plugin-ref.sh reference is a captured call, never inlined" "$captured" "$refs"
# The variable alphabet is DERIVED from the captures, never enumerated. A
# hard-coded [ab] made this leg blind to a third resolved address the moment one
# was added: the guard and reference counts stopped reconciling with the call
# sites, which is a loud failure rather than a silent pass -- but only because
# three numbers are cross-checked here. Derive it, and the next address is free.
VARS=$(grep -oE '[A-Za-z_][A-Za-z0-9_]*=\$\("\$r"/hooks/lib/plugin-ref\.sh' "$CMDFILE" \
         | sed 's/=.*//' | sort -u | tr -d '\n')
if [ -z "$VARS" ]; then bad "no plugin-ref.sh capture variables found -- the legs below would count nothing"; else
  ok "capture-variable alphabet derived from the manifest: [$VARS]"
fi
guards=$(grep -oE "\\[ -n \"\\\$[${VARS}]\" \\] \\|\\|" "$CMDFILE" | wc -l | tr -d ' ')
check "each captured call carries an emptiness guard" "$guards" "$refs"
fallbacks=$(grep -oF -- 'correct operation of the plugin requires read access to the plugin directory' "$CMDFILE" | wc -l | tr -d ' ')
check "and a cause-agnostic fallback string" "$fallbacks" "$refs"
# TWO NUMBERS, never one. The RAW count of `"$a"` / `"$b"` occurrences includes
# the emptiness guards; the TRIAGED count is the printf arguments alone, and
# only that one is the message-reference count. A single number here cannot say
# whether the subtraction happened.
raw_refs=$(grep -oE "\"\\\$[${VARS}]\"" "$CMDFILE" | wc -l | tr -d ' ')
msg_refs=$((raw_refs - guards))
check "message references exceed call sites by exactly one" "$msg_refs" "$((refs + 1))"
ok "  ($refs call sites; $raw_refs raw \$a/\$b occurrences minus $guards guards = $msg_refs message references -- the propagation reminder passes one resolved path as two printf arguments)"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
