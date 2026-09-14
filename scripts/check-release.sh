#!/usr/bin/env bash
#
# Did this branch change what ships, without bumping the version?
#
# Run: bash scripts/check-release.sh [base-ref]      (default: origin/main)
# Exit: 0 fine, 1 a bump is required and missing, 2 usage/environment error.
#
# The install smoke test proves the plugin LOADS; it installs into a clean
# sandbox, so by construction it can never catch the other delivery failure:
# content changed, version did not, and an already-installed copy silently keeps
# the old payload while `marketplace update` reports success.
#
# Shipped paths are the ones a consumer receives. README.md and ai-docs/ are
# this repo's own profile -- they do not travel, so they need no bump.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
BASE="${1:-origin/main}"
MANIFEST=".claude-plugin/plugin.json"
SHIPPED='^(skills/|agents/|rules/|hooks/|docs/|scripts/|templates/|\.claude-plugin/)'

cd "$ROOT" || exit 2
git rev-parse --git-dir >/dev/null 2>&1 || { printf 'check-release: not a git repo\n' >&2; exit 2; }
git rev-parse --verify --quiet "$BASE" >/dev/null || {
  printf 'check-release: base ref %s does not exist (fetch first?)\n' "$BASE" >&2; exit 2; }

changed=$(git diff --name-only "${BASE}...HEAD" -- . | grep -E "$SHIPPED" || true)
if [ -z "$changed" ]; then
  printf 'check-release: no shipped content changed against %s -- no bump needed.\n' "$BASE"
  exit 0
fi

here_version=$(jq -r '.version' "$MANIFEST")
base_version=$(git show "${BASE}:${MANIFEST}" 2>/dev/null | jq -r '.version' 2>/dev/null)

if [ -z "$base_version" ] || [ "$base_version" = "null" ]; then
  printf 'check-release: cannot read the version at %s; treating as first release.\n' "$BASE"
  exit 0
fi

if [ "$here_version" = "$base_version" ]; then
  printf 'check-release: REFUSED -- shipped content changed but the version is still %s.\n\n' "$here_version" >&2
  printf '%s\n' "$changed" | sed 's/^/  /' >&2
  printf '\nThe install cache is keyed by version: without a bump this reaches nobody, and\n' >&2
  printf '`marketplace update` will report success while leaving the old payload in place.\n' >&2
  printf 'Bump the patch version in %s (see README.md section Releasing).\n' "$MANIFEST" >&2
  exit 1
fi

printf 'check-release: shipped content changed; version %s -> %s. OK.\n' "$base_version" "$here_version"
exit 0
