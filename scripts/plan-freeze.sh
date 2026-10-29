#!/usr/bin/env bash
#
# The name avoids `check`, `test`, `lint` and `verify` on purpose: the
# result-masking hook and the gate record key on those words anywhere in a
# script's path, and this script computes an input rather than passing or
# failing anything. For the same reason it never exits 1, the findings code:
# 0 when the change was computed, changed or unchanged alike, 2 when it could
# not be, which a reader must never take for "unchanged".

set -uo pipefail

PROG=plan-freeze
KEY=Plan-Freeze
PLANS_DIR=ai-docs/plans

usage() {
  printf 'usage: %s find <plan-document>\n' "$PROG" >&2
  printf '       %s show <plan-document>\n' "$PROG" >&2
  printf '       %s diff <plan-document>...\n' "$PROG" >&2
  exit 2
}

VERB=${1:-}
case $VERB in find|show|diff) ;; *) usage ;; esac
shift
[ $# -ge 1 ] || usage
[ "$VERB" = diff ] || [ $# -eq 1 ] || usage

# `show`'s standard output IS the document, so its reason goes to stderr, where a
# caller hashing that output cannot take it for text.
cannot() {
  local line="${PROG}: ${VERB} verdict=could-not-compute reason=$1"
  if [ "$VERB" = show ]; then printf '%s\n' "$line" >&2; else printf '%s\n' "$line"; fi
  exit 2
}

for tool in git diff awk mktemp dirname basename; do
  command -v "$tool" >/dev/null 2>&1 || cannot "${tool} is not on PATH"
done

spec_base() {
  local name
  name=$(basename -- "$1")
  case $name in
    ?*.spec.md) printf '%s' "${name%.spec.md}" ;;
    ?*.design.md) printf '%s' "${name%.design.md}" ;;
    *) return 1 ;;
  esac
}

BASE=
TOP=
for doc in "$@"; do
  [ -f "$doc" ] && [ -r "$doc" ] || cannot "cannot read ${doc}"
  b=$(spec_base "$doc") || cannot "${doc} is neither a spec nor a design, so it names no plan"
  [ -z "$BASE" ] || [ "$b" = "$BASE" ] || cannot "${doc} belongs to plan ${b}, not ${BASE}; one call reads one plan's freeze"
  BASE=$b
  t=$(git -C "$(dirname -- "$doc")" rev-parse --show-toplevel 2>/dev/null) \
    || cannot "${doc} is not inside a git work tree"
  [ -z "$TOP" ] || [ "$t" = "$TOP" ] || cannot "${doc} is in another repository than the documents before it"
  TOP=$t
done
git -C "$TOP" rev-parse --verify -q HEAD >/dev/null || cannot 'the repository has no commit, so nothing can carry a freeze'

T=$(mktemp -d) || cannot 'mktemp -d failed'
trap 'rm -rf "$T"' EXIT

# The grep only narrows what git prints. Whether a commit IS a freeze is decided
# by its parsed trailers, so a body line merely mentioning the key matches nothing,
# and the value must equal the spec base exactly, so another plan's freeze on the
# same branch -- a longer name sharing this one as a prefix included -- never does.
# A git too old for the placeholder prints it back literally, which is a
# could-not-compute rather than a branch with no freeze.
git -C "$TOP" log -i -F --grep="$KEY" \
  --format="%x1e%H%n%(trailers:key=${KEY},unfold)" HEAD > "$T/log" 2> "$T/err" \
  || cannot "git log failed: $(head -n 1 "$T/err")"
if grep -qF '%(trailers' "$T/log"; then
  cannot 'this git has no trailer placeholder filtered by key, so no freeze can be found'
fi
FREEZE=$(LC_ALL=C awk -v RS='\036' -v key="$KEY" -v want="$BASE" '
  { n = split($0, L, "\n")
    for (i = 2; i <= n; i++) {
      p = index(L[i], ":")
      if (!p) continue
      k = substr(L[i], 1, p - 1); v = substr(L[i], p + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (tolower(k) == tolower(key) && v == want) { print L[1]; exit }
    }
  }' "$T/log")
[ -n "$FREEZE" ] || cannot "no commit reachable from HEAD carries the trailer ${KEY}: ${BASE}"

# The plan moves into the archive after it is frozen, and that move must read as
# no change, so the document's path at the freeze is not assumed to be today's:
# today's is tried first, then its file name anywhere under the plans directory.
frozen_path() {
  local doc=$1 name prefix hits
  name=$(basename -- "$doc")
  prefix=$(git -C "$(dirname -- "$doc")" rev-parse --show-prefix 2>/dev/null) || prefix=
  if git -C "$TOP" cat-file -e "${FREEZE}:${prefix}${name}" 2>/dev/null; then
    printf '%s' "${prefix}${name}"
    return 0
  fi
  hits=$(git -C "$TOP" ls-tree -r --name-only "$FREEZE" -- "$PLANS_DIR" \
         | LC_ALL=C awk -v want="$name" '{ n = split($0, P, "/"); if (P[n] == want) print }')
  case $hits in
    '') cannot "the freeze ${FREEZE} holds no ${name}" ;;
    *$'\n'*) cannot "the freeze ${FREEZE} holds ${name} at more than one path under ${PLANS_DIR}" ;;
  esac
  printf '%s' "$hits"
}

case $VERB in
  find)
    printf '%s: find verdict=found freeze=%s plan=%s\n' "$PROG" "$FREEZE" "$BASE"
    ;;
  show)
    fp=$(frozen_path "$1") || exit 2
    git -C "$TOP" cat-file blob "${FREEZE}:${fp}" || cannot "cannot read ${fp} at ${FREEZE}"
    ;;
  diff)
    compared=0; changed=0
    for doc in "$@"; do
      fp=$(frozen_path "$doc") || { printf '%s\n' "$fp"; exit 2; }
      git -C "$TOP" cat-file blob "${FREEZE}:${fp}" > "$T/frozen" \
        || cannot "cannot read ${fp} at ${FREEZE}"
      diff -u -L "${fp} (freeze ${FREEZE})" -L "$doc" "$T/frozen" "$doc"
      rc=$?
      case $rc in
        0) ;;
        1) changed=$((changed + 1)) ;;
        *) cannot "diff failed on ${doc}" ;;
      esac
      compared=$((compared + 1))
    done
    if [ "$changed" -eq 0 ]; then word=unchanged; else word=changed; fi
    printf '%s: diff verdict=%s freeze=%s documents=%d changed=%d\n' \
      "$PROG" "$word" "$FREEZE" "$compared" "$changed"
    ;;
esac
exit 0
