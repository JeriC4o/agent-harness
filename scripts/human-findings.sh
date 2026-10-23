#!/usr/bin/env bash
# Exit 2 covers a partial tally too: a total missing pull requests must not read as a computed one.
set -uo pipefail

die() { printf 'human-findings: %s\n' "$1" >&2; exit 2; }
USAGE='usage: human-findings.sh (--pr <n> | --branch <name> | --merged [--limit <n>]) [--json]'

MODE=; ARG=; LIMIT=; AS_JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pr|--branch)
      [ -z "$MODE" ] || die "give one of --pr, --branch, --merged"
      MODE=${1#--}; shift
      [ $# -gt 0 ] || die "--$MODE needs a value"
      ARG=$1 ;;
    --merged)
      [ -z "$MODE" ] || die "give one of --pr, --branch, --merged"
      MODE=merged ;;
    --limit) shift; [ $# -gt 0 ] || die "--limit needs a number"; LIMIT=$1 ;;
    --json) AS_JSON=1 ;;
    -h|--help) printf '%s\n' "$USAGE"; exit 0 ;;
    *) die "unknown argument: $1. $USAGE" ;;
  esac
  shift
done
[ -n "$MODE" ] || die "$USAGE"
case $MODE in
  pr) case $ARG in ''|*[!0-9]*) die "--pr takes a pull request number, not '$ARG'" ;; esac ;;
esac
if [ -n "$LIMIT" ]; then
  [ "$MODE" = merged ] || die "--limit applies to --merged only"
  case $LIMIT in ''|*[!0-9]*|0) die "--limit takes a positive number, not '$LIMIT'" ;; esac
fi
LIMIT=${LIMIT:-30}

command -v jq >/dev/null 2>&1 || die "jq is required"
command -v gh >/dev/null 2>&1 \
  || die "gh is required: the count reads pull-request data from the hosting site, and without it nothing can be computed"
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"

PROFILE="$TOP/ai-docs/context.md"
BUMP_LINE=$(grep -m1 '^\*\*Version-bump paths:\*\*' "$PROFILE" 2>/dev/null) \
  || die "no **Version-bump paths:** line in $PROFILE: version-bump commits cannot be told from fixes, so the count would be wrong"
BUMP=$(printf '%s' "$BUMP_LINE" | grep -oE '`[^`]+`' | tr -d '`')
[ -n "$BUMP" ] || die "the **Version-bump paths:** line in $PROFILE names no path; write \`none\` when the project has none"
case $BUMP in *%*%*) die "the **Version-bump paths:** line in $PROFILE still carries an unfilled placeholder" ;; esac
[ "$BUMP" != none ] || BUMP=

T=$(mktemp -d) || die "cannot create a temp directory"
trap 'rm -rf "$T"' EXIT

unavailable() { jq -nc --argjson n "$1" --arg r "$2" '{pr: $n, available: false, reason: $r}'; }
errtext() { tr '\n' ' ' < "$T/err" | head -c 300; }
api() { gh api --paginate "repos/{owner}/{repo}/$1" 2>"$T/err" </dev/null; }

is_bump() {
  local f g hit
  [ -n "$BUMP" ] || return 1
  [ -s "$T/files" ] || return 1
  while IFS=$'\t' read -r _ f; do
    hit=
    while IFS= read -r g; do
      # shellcheck disable=SC2254
      case $f in $g) hit=1; break ;; esac
    done <<<"$BUMP"
    [ -n "$hit" ] || return 1
  done < "$T/files"
  return 0
}

is_fold() {
  local s f
  while IFS=$'\t' read -r s f; do
    [ "$s" = removed ] || continue
    case $f in ai-docs/plans/*.redline.md) return 0 ;; esac
  done < "$T/files"
  return 1
}

count_pr() {
  local n=$1 pr created head base raw all oldest before after sha merge
  pr=$(api "pulls/$n") || { unavailable "$n" "cannot read pull request #$n: $(errtext)"; return 2; }
  created=$(jq -r '.created_at' <<<"$pr"); head=$(jq -r '.head.ref' <<<"$pr"); base=$(jq -r '.base.sha' <<<"$pr")

  local human='def human: (.user.type // "") != "Bot" and ((.user.login // "") | endswith("[bot]") | not);'
  raw=$(api "issues/$n/comments?per_page=100") || { unavailable "$n" "cannot read issue comments: $(errtext)"; return 2; }
  local c_issue c_review c_inline
  c_issue=$(jq -s "$human"' add // [] | map(select(human)) | length' <<<"$raw")
  raw=$(api "pulls/$n/reviews?per_page=100") || { unavailable "$n" "cannot read reviews: $(errtext)"; return 2; }
  c_review=$(jq -s "$human"' add // [] | map(select(human and ((.body // "") != ""))) | length' <<<"$raw")
  raw=$(api "pulls/$n/comments?per_page=100") || { unavailable "$n" "cannot read review comments: $(errtext)"; return 2; }
  c_inline=$(jq -s "$human"' add // [] | map(select(human)) | length' <<<"$raw")

  # A commit records when it was made, not when it was pushed, so push times come from the site's activity record.
  raw=$(api "activity?ref=refs/heads/$head&per_page=100") \
    || { unavailable "$n" "cannot read the push-activity record for $head: $(errtext)"; return 2; }
  local tsdef='def ts: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;'
  all=$(jq -cs 'add // []' <<<"$raw")
  oldest=$(jq -r "$tsdef"' if length == 0 then "" else (map(.timestamp) | min_by(ts)) end' <<<"$all")
  [ -n "$oldest" ] || { unavailable "$n" "the push-activity record holds no entry for $head"; return 2; }
  if jq -ne --arg o "$oldest" --arg c "$created" "$tsdef"' ($o | ts) > ($c | ts)' >/dev/null; then
    unavailable "$n" "the push-activity record for $head starts at $oldest, after the pull request opened at $created;\
 pushes in between may be missing"
    return 2
  fi

  : > "$T/commits"
  # '|' rather than a tab: read collapses a leading whitespace IFS, so an empty `before` would take `after`.
  while IFS='|' read -r before after; do
    case $before in *[!0]*) ;; *) before=$base ;; esac
    raw=$(api "compare/${before}...${after}?per_page=100") \
      || { unavailable "$n" "cannot compare ${before}...${after}: $(errtext)"; return 2; }
    jq -rs '.[].commits[] | [.sha, ((.parents | length) > 1)] | @tsv' <<<"$raw" >> "$T/commits"
  done < <(jq -r --arg c "$created" "$tsdef"'
      .[] | select((.activity_type == "push" or .activity_type == "force_push" or .activity_type == "branch_creation")
                   and (.timestamp | ts) > ($c | ts))
      | [.before // "", .after] | join("|")' <<<"$all")

  local counted=() folds=() bumps=() merges=()
  while IFS=$'\t' read -r sha merge; do
    [ -n "$sha" ] || continue
    if [ "$merge" = true ]; then merges+=("$sha"); continue; fi
    raw=$(api "commits/$sha?per_page=100") || { unavailable "$n" "cannot read commit $sha: $(errtext)"; return 2; }
    jq -rs '.[].files[] | [.status, .filename] | @tsv' <<<"$raw" > "$T/files"
    if is_fold; then folds+=("$sha")
    elif is_bump; then bumps+=("$sha")
    else counted+=("$sha"); fi
  done < <(sort -u -k1,1 "$T/commits")

  jq -nc --argjson n "$n" --arg b "$head" --arg c "$created" \
     --argjson ci "$c_issue" --argjson cr "$c_review" --argjson cl "$c_inline" \
     --arg counted "${counted[*]:-}" --arg folds "${folds[*]:-}" --arg bumps "${bumps[*]:-}" --arg merges "${merges[*]:-}" '
    def list: split(" ") | map(select(. != ""));
    {pr: $n, available: true, branch: $b, created_at: $c,
     comments: {issue: $ci, review: $cr, inline: $cl, total: ($ci + $cr + $cl)},
     commits: {counted: ($counted | list), fold: ($folds | list), version_bump: ($bumps | list), merge: ($merges | list)}}
    | .count = .comments.total + (.commits.counted | length)'
}

CAVEATS=$(jq -nc '[
  "A comment an agent posts through a person\u0027s own account counts as human.",
  "A rebase or amend pushed after the pull request opened introduces every rewritten commit again, and each counts."]')

text_pr() {
  jq -r 'if .available then
      "PR #\(.pr) (\(.branch)): \(.count) human finding(s) -- \(.comments.total) comment(s) "
      + "[issue \(.comments.issue), review \(.comments.review), inline \(.comments.inline)], "
      + "\(.commits.counted | length) fix commit(s) pushed after opening; excluded: "
      + "\(.commits.fold | length) fold, \(.commits.version_bump | length) version bump, \(.commits.merge | length) merge"
    else "PR #\(.pr): COULD NOT BE COMPUTED -- \(.reason)" end'
}

header() { jq -r '.[] | "note: " + .' <<<"$CAVEATS"; }

single() {
  local out rc
  out=$(count_pr "$1"); rc=$?
  if [ "$AS_JSON" -eq 1 ]; then
    jq -c --argjson cav "$CAVEATS" '. + {caveats: $cav}' <<<"$out"
  else
    header; text_pr <<<"$out"
  fi
  [ "$rc" -eq 0 ] || { printf 'human-findings: %s\n' "$(jq -r '.reason' <<<"$out")" >&2; exit 2; }
  exit 0
}

case $MODE in
  pr) single "$ARG" ;;
  branch)
    raw=$(gh pr list --head "$ARG" --state all --limit 100 --json number,createdAt 2>"$T/err") \
      || die "cannot list pull requests for branch $ARG: $(errtext)"
    n=$(jq -r 'sort_by(.createdAt) | last | .number // empty' <<<"$raw")
    [ -n "$n" ] || die "no pull request has $ARG as its head branch"
    single "$n" ;;
  merged)
    raw=$(gh pr list --state merged --limit "$LIMIT" --json number 2>"$T/err") \
      || die "cannot list merged pull requests: $(errtext)"
    : > "$T/rows"
    while IFS= read -r n; do
      count_pr "$n" >> "$T/rows"
    done < <(jq -r '.[].number' <<<"$raw")
    tally=$(jq -cs --argjson cav "$CAVEATS" '
      {pull_requests: ., caveats: $cav,
       read: (map(select(.available)) | length),
       unread: map(select(.available | not) | {pr, reason}),
       total: (map(select(.available) | .count) | add // 0)}
      | .partial = ((.unread | length) > 0)' "$T/rows")
    if [ "$AS_JSON" -eq 1 ]; then
      printf '%s\n' "$tally"
    else
      header
      jq -c '.pull_requests[]' <<<"$tally" | while IFS= read -r row; do text_pr <<<"$row"; done
      jq -r 'if .partial then
          "total: \(.total) human finding(s) over \(.read) pull request(s) -- PARTIAL: "
          + "\(.unread | length) pull request(s) could not be read: "
          + (.unread | map("#\(.pr)") | join(", "))
        else "total: \(.total) human finding(s) over \(.read) pull request(s)" end' <<<"$tally"
    fi
    if jq -e '.partial' <<<"$tally" >/dev/null; then exit 2; fi
    exit 0 ;;
esac
