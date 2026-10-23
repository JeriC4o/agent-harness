#!/usr/bin/env bash
#
# Run from anywhere:  bash scripts/test-tree-digest.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
TD="${HERE}/tree-digest.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
diff_() { if [ "$2" != "$3" ] && [ -n "$2" ] && [ -n "$3" ]; then ok "$1"; else bad "$1 (both [$2])"; fi; }

D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
R="$D/repo"
mkdir -p "$R/sub"
git -C "$R" init -q
git -C "$R" config user.email t@t
git -C "$R" config user.name t
printf 'notes.md\n' > "$R/.gitignore"
printf 'a\n' > "$R/a.txt"
printf 'b\n' > "$R/sub/b.txt"
git -C "$R" add .gitignore a.txt sub/b.txt
git -C "$R" commit -q -m init

dg() { bash "$TD" -C "$R" "$@"; }
objects() { find "$R/.git/objects" -type f | wc -l | tr -d ' '; }

printf '\n== shape and stability ==\n'
d0=$(dg)
case $d0 in
  [0-9a-f]*) [ ${#d0} -eq 40 ] && ok "40-hex digest" || bad "40-hex digest (got [$d0])" ;;
  *) bad "40-hex digest (got [$d0])" ;;
esac
same "two runs agree" "$(dg)" "$d0"
same "a subdirectory as -C gives the top-level digest" "$(bash "$TD" -C "$R/sub")" "$d0"

printf '\n== ignored files and staging do not move it ==\n'
printf 'progress\n' > "$R/notes.md"
same "an ignored file is invisible" "$(dg)" "$d0"
printf 'a2\n' > "$R/a.txt"
d1=$(dg)
diff_ "a tracked edit moves it" "$d1" "$d0"
git -C "$R" add a.txt
same "staging that edit does not" "$(dg)" "$d1"
printf 'a\n' > "$R/a.txt"
git -C "$R" add a.txt
same "reverting restores it" "$(dg)" "$d0"

printf '\n== untracked, deleted, mode ==\n'
printf 'n\n' > "$R/new.txt"
d2=$(dg)
diff_ "an untracked unignored file moves it" "$d2" "$d0"
printf 'n2\n' > "$R/new.txt"
diff_ "editing that untracked file moves it again" "$(dg)" "$d2"
rm "$R/new.txt"
same "removing it restores it" "$(dg)" "$d0"
rm "$R/sub/b.txt"
diff_ "deleting a tracked file moves it" "$(dg)" "$d0"
git -C "$R" checkout -q -- sub/b.txt
chmod +x "$R/a.txt"
diff_ "an executable-bit flip moves it" "$(dg)" "$d0"
chmod -x "$R/a.txt"
same "and back" "$(dg)" "$d0"

printf '\n== intent-to-add counts its content ==\n'
printf 'x\n' > "$R/ita.txt"
d3=$(dg)
git -C "$R" add -N ita.txt
same "git add -N leaves the digest" "$(dg)" "$d3"
printf 'y\n' > "$R/ita.txt"
diff_ "editing an intent-to-add file moves it" "$(dg)" "$d3"
git -C "$R" rm -q --cached ita.txt
rm "$R/ita.txt"

printf '\n== path-list mode ==\n'
p0=$(dg sub)
same "a directory path names its files" "$(dg sub/b.txt)" "$p0"
same "-- separates paths" "$(bash "$TD" -C "$R" -- sub)" "$p0"
printf 'a3\n' > "$R/a.txt"
same "an edit outside the list does not move it" "$(dg sub)" "$p0"
printf 'b2\n' > "$R/sub/b.txt"
diff_ "an edit inside the list does" "$(dg sub)" "$p0"
git -C "$R" checkout -q -- a.txt sub/b.txt
diff_ "a list digest differs from the whole-tree digest" "$(dg a.txt)" "$(dg)"

printf '\n== nothing reaches the object store ==\n'
before=$(objects)
printf 'm\n' > "$R/a.txt"
printf 'u\n' > "$R/untracked.txt"
dg > /dev/null
same "object count unchanged" "$(objects)" "$before"
git -C "$R" checkout -q -- a.txt
rm "$R/untracked.txt"

printf '\n== cannot run ==\n'
mkdir -p "$D/plain"
out=$(bash "$TD" -C "$D/plain" 2>"$D/err")
same "outside a repository exits 2" "$?" "2"
same "and prints no digest" "$out" ""
case $(cat "$D/err") in *'not inside a git working tree'*) ok "names the reason" ;; *) bad "names the reason" ;; esac
bash "$TD" -C 2>/dev/null
same "-C without a directory exits 2" "$?" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
