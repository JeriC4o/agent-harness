#!/usr/bin/env bash
#
# Callers detect failure by EMPTY OUTPUT, never by rc — hence the unconditional
# exit 0. A hook that treated a non-zero rc as fatal would lose its whole
# message, and the message is the only thing the user ever sees.
#
# The unreadable-target wording is byte-identical to the fallback string in
# hooks/hooks.json. An unreadable root makes this script itself unreachable, so
# the fallback fires there and the unreadable-target branch fires here; the two
# states must emit the same bytes. Changing either wording alone splits them.
#
# The root is read from the environment rather than derived from this script's
# own location, so the printed address is spelled exactly as the caller spells
# it — the byte-identity above depends on that.

set -u

rel="${1:-}"
root="${CLAUDE_PLUGIN_ROOT:-}"
addr="${root:+${root}/}${rel}"

# Without a root there is no plugin directory to probe, and an unguarded -r
# would resolve the bare relative path against the caller's CWD and report a
# same-named project file as the plugin's own.
if [ -n "$root" ] && [ -n "$rel" ] && [ -r "$addr" ]; then
  printf '%s\n' "$addr"
else
  printf '%s — correct operation of the plugin requires read access to the plugin directory%s\n' "$addr" "${root:+ ${root}}"
fi

exit 0
