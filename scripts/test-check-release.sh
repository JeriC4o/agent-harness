#!/usr/bin/env bash
#
# Tests for check-release.sh.
#
# Run: bash scripts/test-check-release.sh
#
# check-release.sh takes its root from its own location, so each fixture is a
# repository carrying its own copy of the gate and of ref-current.sh under
# scripts/, invoked by path so the execute bit is exercised as shipped. A bare
# repository stands in for the remote, so no leg touches the network.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in [$2]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3]" ;; *) ok "$1" ;; esac; }

command -v jq >/dev/null 2>&1 || { printf 'cannot run: jq is not on PATH\n' >&2; exit 2; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
C="${W}/c"
D="${W}/d"

g() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
run() { OUT=$("${C}/scripts/check-release.sh" "$@" 2>&1); RC=$?; }
version() { printf '{ "name": "x", "version": "%s" }\n' "$2" > "$1/.claude-plugin/plugin.json"; }
snap() { git -C "$C" for-each-ref; (cd "${C}/.git" && find . | sort); }
reset_c() { g "$C" checkout -q -- .; g "$C" clean -qfd; }

git init -q --bare -b main "${W}/b.git"
git init -q -b main "$C"
mkdir -p "${C}/scripts" "${C}/skills" "${C}/.claude-plugin"
cp "${HERE}/check-release.sh" "${HERE}/ref-current.sh" "${C}/scripts/"
chmod +x "${C}/scripts/check-release.sh" "${C}/scripts/ref-current.sh"
printf 'one\n' > "${C}/skills/a.md"
version "$C" 1.0.0
g "$C" add -A; g "$C" commit -qm base
g "$C" remote add origin "${W}/b.git"
g "$C" push -q -u origin main 2>/dev/null
git clone -q "${W}/b.git" "$D" 2>/dev/null

printf '\n== a current remote-tracking base: verdicts as before ==\n'
run
check "no shipped change against the default base: fine" "$RC" "0"
has   "  says no bump needed" "$OUT" "no bump needed"

printf 'two\n' > "${C}/skills/a.md"
run origin/main
check "shipped change, version unchanged: refused" "$RC" "1"
has   "  with the refusal" "$OUT" "REFUSED"

version "$C" 1.0.1
run origin/main
check "shipped change, version bumped: fine" "$RC" "0"
has   "  naming both versions" "$OUT" "1.0.0 -> 1.0.1"
reset_c

printf '\n== a stale remote-tracking base: cannot-run, whatever the branch holds ==\n'
printf 'three\n' > "${D}/skills/a.md"; version "$D" 1.0.1
g "$D" commit -qam moved; g "$D" push -q 2>/dev/null

BEFORE=$(snap)
run
check "stale default base, no change of the branch's own: exit 2, not 'no bump needed'" "$RC" "2"
hasnt "  and no verdict is claimed" "$OUT" "no bump needed"
has   "  names the ref" "$OUT" "origin/main"
has   "  names the remote" "$OUT" "remote origin"
has   "  names the fetch that fixes it" "$OUT" "git fetch origin"
check "  and no ref or .git entry moved" "$(snap)" "$BEFORE"

printf 'four\n' > "${C}/skills/a.md"
run origin/main
check "stale base, shipped change without a bump: exit 2, not refused" "$RC" "2"
hasnt "  and no refusal is claimed" "$OUT" "REFUSED"

version "$C" 1.0.1
run origin/main
check "stale base, the remote's own bump read as this branch's: exit 2, not OK" "$RC" "2"
hasnt "  and no OK is claimed" "$OUT" "OK."
reset_c

g "$C" fetch -q
SAVED=$(git -C "$C" rev-parse origin/main)
AHEAD=$(g "$C" commit-tree -p "$SAVED" -m ahead "$(git -C "$C" rev-parse "${SAVED}^{tree}")")
git -C "$C" update-ref refs/remotes/origin/main "$AHEAD"
run origin/main
check "a base AHEAD of its remote is exit 2 too" "$RC" "2"
has   "  naming the fetch" "$OUT" "git fetch origin"
git -C "$C" update-ref refs/remotes/origin/main "$SAVED"

git -C "$C" update-ref refs/remotes/zz/main "$SAVED"
run zz/main
check "a tracking base no configured remote maps is exit 2" "$RC" "2"
has   "  names the ref" "$OUT" "zz/main"
has   "  says no configured remote maps it" "$OUT" "no configured remote maps"
has   "  remedy: configure the remote, or pass a commit id" "$OUT" "configure the remote, or pass a commit id"
hasnt "  and names no fetch, there being no remote" "$OUT" "git fetch"
git -C "$C" update-ref -d refs/remotes/zz/main

printf '\n== an unreachable remote: no fallback for a tracking base, none needed otherwise ==\n'
BASE_ID=$(git -C "$C" rev-parse HEAD)
git -C "$C" branch -q local-base "$BASE_ID"
g "$C" remote set-url origin "${W}/no-such-remote.git"
printf 'five\n' > "${C}/skills/a.md"
BEFORE=$(snap)
run origin/main
check "unreachable remote: exit 2, not read from the local copy" "$RC" "2"
hasnt "  no refusal from the local copy" "$OUT" "REFUSED"
has   "  says the remote could not be reached" "$OUT" "could not be reached"
has   "  names the ref" "$OUT" "origin/main"
has   "  names the remote and the fetch" "$OUT" "git fetch origin"
check "  and no ref or .git entry moved" "$(snap)" "$BEFORE"

run "$BASE_ID"
check "unreachable remote: a commit id base is read as given" "$RC" "1"
has   "  with the old verdict" "$OUT" "REFUSED"
run local-base
check "unreachable remote: a local branch base is read as given" "$RC" "1"
has   "  with the old verdict" "$OUT" "REFUSED"
reset_c
g "$C" remote set-url origin "${W}/b.git"

git -C "${W}/b.git" update-ref -d refs/heads/main
run origin/main
check "a branch the remote no longer has is exit 2" "$RC" "2"
has   "  says so" "$OUT" "no longer has"
has   "  and names the fetch" "$OUT" "git fetch origin"
git -C "${W}/b.git" update-ref refs/heads/main "$SAVED"

printf '\n== the helper is a dependency: its absence or failure is a cannot-run ==\n'
run "$BASE_ID"
check "control: the commit-id base passes with the helper in place" "$RC" "0"

mv "${C}/scripts/ref-current.sh" "${W}/ref-current.sh"
run "$BASE_ID"
check "a missing helper is exit 2, never a pass" "$RC" "2"
has   "  and names the helper" "$OUT" "ref-current.sh is missing or not executable"

cp "${W}/ref-current.sh" "${C}/scripts/ref-current.sh"; chmod -x "${C}/scripts/ref-current.sh"
run "$BASE_ID"
check "a non-executable helper is exit 2" "$RC" "2"

printf '#!/bin/sh\nexit 1\n' > "${C}/scripts/ref-current.sh"; chmod +x "${C}/scripts/ref-current.sh"
run "$BASE_ID"
check "a helper status of 1 is mapped to exit 2, never read as a missing bump" "$RC" "2"
has   "  and the status is named when the helper gave no reason" "$OUT" "returned status 1"
hasnt "  and no refusal is claimed" "$OUT" "REFUSED"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
