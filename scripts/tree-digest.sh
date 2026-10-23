#!/usr/bin/env bash
#
# Digest of the working tree as version control sees it: every path git does not
# ignore, tracked files as they stand on disk and untracked files no ignore rule
# covers. Staging moves nothing, an ignored file moves nothing, and nothing is
# written to the object store.
#
# Run:  tree-digest.sh [-C <dir>] [--] [<repo-relative path>…]
#       With paths, only what they name (a directory names everything under it).
# Exit: 0 printing one 40-hex line; 2 cannot run, the reason on stderr.
#
# A clean tracked file takes its index blob id, which equals its on-disk content
# hash, so only modified and untracked files are hashed -- by `hash-object`
# without `-w`, which writes no object. That keeps the cost proportional to the
# change set rather than the tree, which matters because a hook runs this on
# every gate call.

set -uo pipefail

cannot() { printf 'tree-digest: cannot run: %s\n' "$1" >&2; exit 2; }

dir=.
if [ "${1:-}" = -C ]; then
  [ $# -ge 2 ] || cannot 'usage: tree-digest.sh [-C <dir>] [--] [<path>…]'
  dir=$2
  shift 2
fi
[ "${1:-}" = -- ] && shift

command -v git >/dev/null 2>&1 || cannot 'git is not installed'
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || cannot "${dir} is not inside a git working tree"

T=$(mktemp -d) || cannot 'mktemp failed'
trap 'rm -rf "$T"' EXIT

specs=()
for p in "$@"; do specs+=(":(literal)${p}"); done

git -C "$top" diff --no-renames --name-only -z -- ${specs[@]+"${specs[@]}"} > "$T/dirty" \
  || cannot 'git diff failed'
git -C "$top" ls-files -o --exclude-standard -z -- ${specs[@]+"${specs[@]}"} > "$T/untracked" \
  || cannot 'git ls-files -o failed'

# With no paths given, a pathspec of excludes alone still means "everything
# except", so the clean-file listing needs no special case.
excl=()
: > "$T/computed"
while IFS= read -r -d '' p; do
  excl+=(":(exclude,literal)${p}")
  f="${top}/${p}"
  if [ -L "$f" ]; then
    m=120000
    h=$(printf '%s' "$(readlink -- "$f")" | git -C "$top" hash-object --stdin) || cannot "cannot hash ${p}"
  elif [ -d "$f" ]; then
    m=160000
    h=$(git -C "$f" rev-parse HEAD 2>/dev/null) || h=unborn
  elif [ -f "$f" ]; then
    if [ -x "$f" ]; then m=100755; else m=100644; fi
    h=$(git -C "$top" hash-object -- "$p") || cannot "cannot hash ${p}"
  else
    m=000000
    h=deleted
  fi
  printf '%s %s 0\t%s\0' "$m" "$h" "$p" >> "$T/computed"
done < <(cat "$T/dirty" "$T/untracked")

git -C "$top" ls-files -s -z -- ${specs[@]+"${specs[@]}"} ${excl[@]+"${excl[@]}"} > "$T/clean" \
  || cannot 'git ls-files -s failed'

cat "$T/clean" "$T/computed" | LC_ALL=C sort -z -u | git -C "$top" hash-object --stdin \
  || cannot 'git hash-object failed'
