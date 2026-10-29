#!/usr/bin/env bash
#
# May <ref>'s tree be read as its remote's tree?
#
# Run:  ref-current.sh <dir> <ref>
# Exit: 0 readable, printing nothing; 2 cannot run, printing ONE reason line on
#       stdout. Never 1: a ref that cannot be shown current is no comparand, so
#       no caller may turn it into a finding.
#
# Used by: check-release.sh (its base).
#
# A remote-tracking ref that RESOLVES is only the last fetch's copy, so a
# caller that skipped the fetch would read an old tree and report on it. Only
# the remote can say whether the copy is current, so a remote-tracking ref is
# compared with the remote's advertised tip -- read-only, `ls-remote` writes no
# ref, object or FETCH_HEAD. A commit id, a local branch and any expression git
# reports no full name for are read as given with no remote contact.
#
# The name carries no `check-` prefix on purpose: run-checks.sh derives every
# tracked check-*.sh as a gate that must be a member or exempted, and this is
# a dependency of a gate, not a gate.

set -uo pipefail

dir=${1:-}
ref=${2:-}

cannot() { printf '%s\n' "$1"; exit 2; }

{ [ -n "$dir" ] && [ -n "$ref" ]; } || cannot 'usage: ref-current.sh <dir> <ref>'
[ -d "$dir" ] || cannot "no such directory: ${dir}"

# An ambiguous name prints a warning and an error here yet exits 0 with empty
# output; `rev-parse --verify` then reads the LOCAL branch, so as-given is right
# and the two stderr lines would only leak into the caller's output.
full=$(git -C "$dir" rev-parse --symbolic-full-name "$ref" 2>/dev/null) \
  || cannot "cannot classify ref ${ref}, so it cannot be shown current"
case $full in
  refs/remotes/*) ;;
  *) exit 0 ;;
esac

# Reverse-map the fetch refspecs rather than split the name at its first `/`:
# a remote name may contain `/`, and a single-branch clone carries an explicit
# refspec instead of the wildcard.
remote='' src=''
map() {
  local r spec s d dpre dsuf mid
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    while IFS= read -r spec; do
      spec=${spec#+}
      case $spec in ''|^*) continue ;; *:*) ;; *) continue ;; esac
      s=${spec%%:*}
      d=${spec#*:}
      case $d in
        *'*'*)
          dpre=${d%%\**}
          dsuf=${d#*\*}
          [ "${#full}" -ge $(( ${#dpre} + ${#dsuf} )) ] || continue
          case $full in "$dpre"*"$dsuf") ;; *) continue ;; esac
          mid=${full#"$dpre"}
          mid=${mid%"$dsuf"}
          src="${s%%\**}${mid}${s#*\*}"
          ;;
        *)
          [ "$d" = "$full" ] || continue
          src=$s
          ;;
      esac
      remote=$r
      return 0
    done <<EOF
$(git -C "$dir" config --get-all "remote.${r}.fetch" 2>/dev/null)
EOF
  done <<EOF
$(git -C "$dir" remote 2>/dev/null)
EOF
  return 1
}
map || cannot "${ref} is a remote-tracking ref (${full}) that no configured remote maps, so there is no remote\
 to compare it with -- configure the remote, or pass a commit id"

# `ls-remote` patterns match on the TAIL, so `main` also returns
# `refs/heads/x/main`; only the exact second field counts.
adv=$(GIT_TERMINAL_PROMPT=0 git -C "$dir" ls-remote -- "$remote" "$src" 2>/dev/null) \
  || cannot "remote ${remote} could not be reached, so ${ref} cannot be shown current -- run: git fetch ${remote}"
tip=$(printf '%s\n' "$adv" | awk -v want="$src" '$2 == want { print $1; exit }')
[ -n "$tip" ] \
  || cannot "remote ${remote} no longer has ${src}, so ${ref} cannot be shown current -- run: git fetch ${remote}"
here=$(git -C "$dir" rev-parse --verify --quiet "$full")
[ "$tip" = "$here" ] \
  || cannot "${ref} is at ${here}, but ${src} on remote ${remote} is at ${tip}, so ${ref} is not the remote's tree\
 -- run: git fetch ${remote}"
exit 0
