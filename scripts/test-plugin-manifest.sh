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

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
