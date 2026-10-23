#!/usr/bin/env bash
set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
SCRIPT="${HERE}/human-findings.sh"
PASS=0; FAIL=0
ok()    { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()   { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in [$2])" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpected [$3] in [$2])" ;; *) ok "$1" ;; esac; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
FIX="$W/fix"; BIN="$W/bin"; REPO="$W/repo"
mkdir -p "$FIX" "$BIN" "$REPO/ai-docs"
git -C "$REPO" init -q
profile() { printf '# ctx\n\n%s\n' "$1" > "$REPO/ai-docs/context.md"; }
profile '**Version-bump paths:** `.claude-plugin/plugin.json` `.claude-plugin/marketplace.json`'

cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
[ ! -f "$FIX/fail" ] || { echo "HTTP 502: Bad Gateway" >&2; exit 1; }
case "$1 $2" in
  "pr list")
    case " $* " in
      *" --head "*) cat "$FIX/prlist-head.json" ;;
      *) cat "$FIX/prlist-merged.json" ;;
    esac
    exit 0 ;;
esac
ep=
for a in "$@"; do case $a in repos/*) ep=$a ;; esac; done
key=$(printf '%s' "$ep" | sed 's|^repos/{owner}/{repo}/||; s|[?&]per_page=100||' | tr -c 'A-Za-z0-9\n' '_')
[ -f "$FIX/$key.json" ] || { echo "HTTP 404: Not Found ($ep)" >&2; exit 1; }
cat "$FIX/$key.json"
STUB
chmod +x "$BIN/gh"

put() { printf '%s\n' "$2" > "$FIX/$1.json"; }
Z=0000000000000000000000000000000000000000
human() { printf '{"user":{"login":"%s","type":"User"},"body":"%s"}' "$1" "$2"; }

put pulls_7 '{"created_at":"2026-10-01T10:00:00Z","head":{"ref":"feat"},"base":{"sha":"b0"}}'
put issues_7_comments "[$(human alice 'please rename'),{\"user\":{\"login\":\"ci\",\"type\":\"Bot\"},\"body\":\"green\"}]"
put pulls_7_reviews "[$(human bob 'one thing'),$(human bob ''),{\"user\":{\"login\":\"helper[bot]\",\"type\":\"User\"},\"body\":\"auto\"}]"
put pulls_7_comments '[]'
put activity_ref_refs_heads_feat "[
  {\"activity_type\":\"force_push\",\"timestamp\":\"2026-10-01T11:30:00Z\",\"before\":\"x9\",\"after\":\"c4\"},
  {\"activity_type\":\"push\",\"timestamp\":\"2026-10-01T11:00:00Z\",\"before\":\"c3\",\"after\":\"c4\"},
  {\"activity_type\":\"push\",\"timestamp\":\"2026-10-01T10:30:00Z\",\"before\":\"c0\",\"after\":\"c3\"},
  {\"activity_type\":\"branch_creation\",\"timestamp\":\"2026-10-01T09:50:00Z\",\"before\":\"$Z\",\"after\":\"c0\"}]"
cm() { printf '{"sha":"%s","parents":[%s]}' "$1" "$2"; }
put compare_b0___c0 "{\"commits\":[$(cm c0 '{}')]}"
put compare_c0___c3 "{\"commits\":[$(cm c1 '{}'),$(cm c2 '{}'),$(cm c3 '{}')]}"
put compare_c3___c4 "{\"commits\":[$(cm c4 '{},{}')]}"
put compare_x9___c4 "{\"commits\":[$(cm c1 '{}'),$(cm c4 '{},{}')]}"
put commits_c0 '{"files":[{"status":"added","filename":"src/a.sh"}]}'
put commits_c1 '{"files":[{"status":"modified","filename":"src/a.sh"}]}'
put commits_c2 '{"files":[{"status":"removed","filename":"ai-docs/plans/x.redline.md"},
                           {"status":"modified","filename":"ai-docs/plans/x.design.md"}]}'
put commits_c3 '{"files":[{"status":"modified","filename":".claude-plugin/plugin.json"}]}'

put pulls_8 '{"created_at":"2026-09-01T10:00:00Z","head":{"ref":"old"},"base":{"sha":"b0"}}'
put issues_8_comments '[]'
put pulls_8_reviews '[]'
put pulls_8_comments '[]'
put activity_ref_refs_heads_old '[{"activity_type":"push","timestamp":"2026-09-20T10:00:00Z","before":"c0","after":"c3"}]'

put pulls_9 '{"created_at":"2026-10-05T10:00:00Z","head":{"ref":"nobefore"},"base":{"sha":"b0"}}'
put issues_9_comments '[]'
put pulls_9_reviews '[]'
put pulls_9_comments '[]'
put activity_ref_refs_heads_nobefore '[{"activity_type":"push","timestamp":"2026-10-05T09:00:00Z","before":"c0","after":"c0"},
  {"activity_type":"push","timestamp":"2026-10-05T11:00:00Z","before":null,"after":"c1"}]'
put compare_b0___c1 "{\"commits\":[$(cm c1 '{}')]}"

put prlist-head '[{"number":3,"createdAt":"2026-08-01T00:00:00Z"},{"number":7,"createdAt":"2026-10-01T10:00:00Z"}]'
put prlist-merged '[{"number":7},{"number":8}]'

run() { (cd "$REPO" && PATH="$BIN:$PATH" FIX="$FIX" bash "$SCRIPT" "$@"); }

printf '\n== one pull request: comments by people, fixes pushed after opening ==\n'
r=$(run --pr 7 --json); rc=$?
check "computed -> rc 0" "$rc" "0"
check "two human comments, one human commit: three findings" "$(jq -r '.count' <<<"$r")" "3"
check "  a bot by type and a bot by login are not people; an empty review body is no comment" \
      "$(jq -r '[.comments.issue, .comments.review, .comments.inline] | join(",")' <<<"$r")" "1,1,0"
check "  the fix commit, counted once although two pushes introduced it" "$(jq -r '.commits.counted | join(",")' <<<"$r")" "c1"
check "  the fold excluded by its redline deletion" "$(jq -r '.commits.fold | join(",")' <<<"$r")" "c2"
check "  the bump excluded by the profile's paths" "$(jq -r '.commits.version_bump | join(",")' <<<"$r")" "c3"
check "  the merge commit excluded by its two parents" "$(jq -r '.commits.merge | join(",")' <<<"$r")" "c4"
check "  the commit pushed before opening is not counted" "$(jq -r '[.commits[][]] | index("c0")' <<<"$r")" "null"
check "  the biases ride along" "$(jq -r '.caveats | length' <<<"$r")" "2"
out=$(run --pr 7)
has "the text view names the count" "$out" "PR #7 (feat): 3 human finding(s)"
has "  and states the biases in its header" "$out" "note: A rebase or amend pushed after the pull request opened"

printf '\n== a push with no before falls back to the pull request base ==\n'
r=$(run --pr 9 --json); rc=$?
check "computed -> rc 0" "$rc" "0"
check "  the commit compared from the base is counted" "$(jq -r '.commits.counted | join(",")' <<<"$r")" "c1"

printf '\n== --branch resolves the latest pull request with that head ==\n'
check "branch feat -> PR #7" "$(run --branch feat --json | jq -r '.pr')" "7"

printf '\n== a push record that does not reach the opening is a cannot-compute, never a count ==\n'
out=$(run --pr 8 2>&1); rc=$?
check "rc 2" "$rc" "2"
has "  naming the reach" "$out" "starts at 2026-09-20T10:00:00Z, after the pull request opened at 2026-09-01T10:00:00Z"
hasnt "  and printing no count" "$out" "human finding(s)"

printf '\n== the tally lists what it could not read and says it is partial ==\n'
r=$(run --merged --limit 2 --json); rc=$?
check "partial -> rc 2" "$rc" "2"
check "  total over the readable one" "$(jq -r '[.total, .read, .partial] | join(",")' <<<"$r")" "3,1,true"
check "  the unread one named" "$(jq -r '.unread[0].pr' <<<"$r")" "8"
out=$(run --merged --limit 2 2>&1)
has "  the text says PARTIAL and names it" "$out" "PARTIAL: 1 pull request(s) could not be read: #8"

printf '\n== the site unreachable ==\n'
: > "$FIX/fail"
out=$(run --pr 7 2>&1); rc=$?
rm -f "$FIX/fail"
check "rc 2" "$rc" "2"
has "  with the reason" "$out" "HTTP 502"
hasnt "  and no count" "$out" "human finding(s)"

printf '\n== gh absent ==\n'
NOGH="$W/nogh"; mkdir -p "$NOGH"
for t in bash jq git grep tr head sed sort mktemp rm cat dirname; do ln -s "$(command -v "$t")" "$NOGH/$t"; done
out=$( (cd "$REPO" && PATH="$NOGH" bash "$SCRIPT" --pr 7) 2>&1); rc=$?
check "rc 2" "$rc" "2"
has "  naming gh" "$out" "gh is required"

printf '\n== the version-bump profile line ==\n'
profile 'no line here'
out=$(run --pr 7 2>&1); rc=$?
check "missing -> rc 2" "$rc" "2"
has "  naming the line" "$out" "no **Version-bump paths:** line"
profile '**Version-bump paths:** `%VERSION_BUMP_PATHS%`'
out=$(run --pr 7 2>&1); rc=$?
check "unfilled -> rc 2" "$rc" "2"
has "  naming the placeholder" "$out" "unfilled placeholder"
profile '**Version-bump paths:** `none`'
check "none -> the bump commit counts as a fix" "$(run --pr 7 --json | jq -r '.commits.counted | join(",")')" "c1,c3"
profile '**Version-bump paths:** `.claude-plugin/*.json`'
check "a glob matches" "$(run --pr 7 --json | jq -r '.commits.version_bump | join(",")')" "c3"
profile '**Version-bump paths:** `.claude-plugin/plugin.json` `.claude-plugin/marketplace.json`'

printf '\n== usage ==\n'
out=$(run --pr seven 2>&1); rc=$?
check "a non-number pull request -> rc 2" "$rc" "2"
out=$(run --pr 7 --limit 3 2>&1); rc=$?
check "--limit outside --merged -> rc 2" "$rc" "2"
out=$(run 2>&1); rc=$?
check "no mode -> rc 2" "$rc" "2"

printf '\n== positive controls: each guard, removed, is caught ==\n'
mutate() { perl -0pe "$2" "$SCRIPT" > "$W/$1.sh"; grep -c "$3" "$W/$1.sh"; }
runm() { local m=$1; shift; (cd "$REPO" && PATH="$BIN:$PATH" FIX="$FIX" bash "$W/$m.sh" "$@"); }
check "the mutation applied" \
      "$(mutate no-time 's/\n *and \(\.timestamp \| ts\) > \(\$c \| ts\)\)/)/' 'branch_creation"))$')" "1"
check "pushes before opening counted -> caught" "$(runm no-time --pr 7 --json | jq -r '.count')" "4"
check "the mutation applied" "$(mutate no-dedup 's/sort -u -k1,1/sort -k1,1/' 'sort -k1,1 ')" "1"
check "a commit two pushes introduced counted twice -> caught" "$(runm no-dedup --pr 7 --json | jq -r '.count')" "4"
check "the mutation applied" "$(mutate no-reach 's/\(\$o \| ts\) > \(\$c \| ts\)/false/' "' false'")" "1"
check "the unreached record read as whole -> caught" "$(runm no-reach --pr 8 --json | jq -r '.available')" "true"
check "the mutation applied" "$(mutate no-bot 's/ and \(\(\.user\.login \/\/ ""\) \| endswith\("\[bot\]"\) \| not\)//' 'endswith')" "0"
check "a bot by login counted -> caught" "$(runm no-bot --pr 7 --json | jq -r '.comments.review')" "2"

printf '\n== the entry point is executable ==\n'
check "human-findings.sh carries the execute bit" "$( [ -x "$SCRIPT" ] && echo yes || echo no )" "yes"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
