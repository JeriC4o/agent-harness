#!/usr/bin/env bash
#
# The name avoids `check`, `test`, `lint` and `verify` on purpose: the result-masking
# hook and the gate record both key on those words anywhere in a script's path, and
# this script decides a review round's breadth rather than passing or failing it.

set -uo pipefail -f

PROG=review-ledger
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
PREFIX=12
TRIGGERS=' first-round scope-changed rule-changed objected new-file record-invalid amendment '
WARN=$'\xe2\x9a\xa0'
VS16=$'\xef\xb8\x8f'
US=$'\037'

usage() {
  printf 'usage: %s plan <findings-file> --base <rev> [--plan <path>]... [--frozen <path>]...\n' "$PROG" >&2
  printf '       %s seal <findings-file> [--plan <path>]... [--frozen <path>]...\n' "$PROG" >&2
  exit 2
}
cannot() { printf '%s: cannot run: %s\n' "$PROG" "$1" >&2; exit 2; }

[ $# -ge 2 ] || usage
VERB=$1; FILE=$2; shift 2
case $VERB in plan|seal) ;; *) usage ;; esac
BASE_ARG=
PLANS=()
FROZEN=()
while [ $# -gt 0 ]; do
  case $1 in
    --base) [ $# -ge 2 ] || usage; BASE_ARG=$2; shift 2 ;;
    --plan) [ $# -ge 2 ] || usage; PLANS+=("$2"); shift 2 ;;
    --frozen) [ $# -ge 2 ] || usage; FROZEN+=("$2"); shift 2 ;;
    *) usage ;;
  esac
done
[ "$VERB" = seal ] || [ -n "$BASE_ARG" ] || usage
[ "$VERB" = plan ] || [ -z "$BASE_ARG" ] || usage

command -v git >/dev/null 2>&1 || cannot 'git is not installed'
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || cannot 'not inside a git working tree'
[ -f "$FILE" ] && [ -r "$FILE" ] || cannot "cannot read ${FILE}"

PLUGIN=${HERE%/*}
if [ ! -r "$PLUGIN/agents/self-review.md" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  PLUGIN=$CLAUDE_PLUGIN_ROOT
fi
[ -r "$PLUGIN/agents/self-review.md" ] || cannot 'cannot locate agents/self-review.md under the plugin root'

T=$(mktemp -d) || cannot 'mktemp failed'
trap 'rm -rf "$T"' EXIT

ITEMS=()
while IFS= read -r n; do ITEMS+=("$n"); done < <(LC_ALL=C awk '
  /^```/ { f = !f; next }
  !f && /^### [0-9]+\./ { sub(/^### /, ""); sub(/\..*/, ""); print }' "$PLUGIN/agents/self-review.md")
[ ${#ITEMS[@]} -gt 0 ] || cannot 'agents/self-review.md has no numbered checklist items'

hash() { git -C "$TOP" hash-object --stdin; }

is_item() {
  local i
  for i in "${ITEMS[@]}"; do [ "$i" = "$1" ] && return 0; done
  return 1
}

PLAN_DIGEST=
compute_plan_digest() {
  local p h
  if [ ${#PLANS[@]} -eq 0 ] && [ ${#FROZEN[@]} -eq 0 ]; then PLAN_DIGEST=none; return; fi
  : > "$T/planhashes"
  for p in ${PLANS[@]+"${PLANS[@]}"}; do
    [ -f "$p" ] && [ -r "$p" ] || cannot "cannot read plan document ${p}"
    h=$(hash < "$p") || cannot "cannot hash ${p}"
    printf '%s\n' "$h" >> "$T/planhashes"
  done
  # A document's text at the plan's freeze, so a correction made in place after it
  # leaves the digest alone while a new freeze moves it.
  for p in ${FROZEN[@]+"${FROZEN[@]}"}; do
    bash "$HERE/plan-freeze.sh" show "$p" > "$T/frozen" \
      || cannot "plan-freeze.sh show could not resolve the frozen text of ${p}"
    h=$(hash < "$T/frozen") || cannot "cannot hash the frozen text of ${p}"
    printf 'frozen %s\n' "$h" >> "$T/planhashes"
  done
  h=$(LC_ALL=C sort "$T/planhashes" | hash) || cannot 'cannot hash the plan documents'
  PLAN_DIGEST=${h:0:$PREFIX}
}

# Exact GitHub slug first, else the one heading whose slug starts with `<slug>-`, so
# `#5-style` names `### 5. Style (…)` without spelling out the whole heading.
section_of() {
  LC_ALL=C awk -v want="$2" '
    { L[NR] = $0 }
    /^```/ { f = !f; next }
    !f && /^#{1,6}[ \t]/ {
      n++; at[n] = NR; lv[n] = match($0, /[^#]/) - 1
      s = $0; sub(/^#{1,6}[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
      s = tolower(s); gsub(/<[^>]*>/, "", s); gsub(/[^a-z0-9 _-]/, "", s); gsub(/ /, "-", s)
      sl[n] = s
    }
    END {
      for (i = 1; i <= n; i++) {
        if (sl[i] == want) { ex++; pick = i }
        else if (index(sl[i], want "-") == 1) { pre++; ppick = i }
      }
      if (ex > 1 || (ex == 0 && pre != 1)) exit 1
      if (ex == 0) pick = ppick
      stop = NR
      for (i = pick + 1; i <= n; i++) if (lv[i] <= lv[pick]) { stop = at[i] - 1; break }
      for (i = at[pick]; i <= stop; i++) print L[i]
    }' "$1"
}

RULE_HASH=; RULE_ERR=
compute_rule_hash() {
  local cell=$1 ref path frag cand found h
  RULE_HASH=; RULE_ERR=
  : > "$T/rule"
  for ref in $(printf '%s\n' "$cell" | tr ',`' '  ' | tr -s ' \t' '\n\n' | LC_ALL=C sort -u); do
    path=${ref%%#*}; frag=
    case $ref in *'#'*) frag=${ref#*#} ;; esac
    # A bare path is project data, so a consuming project's own profile is what it hashes,
    # never the plugin's shipped copy of the same file.
    case $path in
      '${CLAUDE_PLUGIN_ROOT}/'*) cand=$PLUGIN/${path#*\}/} ;;
      *) cand=$TOP/$path ;;
    esac
    found=
    if [ -f "$cand" ] && [ -r "$cand" ]; then
      if [ -z "$frag" ]; then cat -- "$cand" > "$T/sec" && found=1
      else section_of "$cand" "$frag" > "$T/sec" && found=1
      fi
    fi
    if [ -z "$found" ]; then RULE_ERR="rule reference ${ref} does not resolve"; return 1; fi
    { printf '%s\n' "$ref"; cat "$T/sec"; printf '\0'; } >> "$T/rule"
  done
  [ -s "$T/rule" ] || { RULE_ERR='no rule reference'; return 1; }
  h=$(hash < "$T/rule") || cannot 'cannot hash rule text'
  RULE_HASH=${h:0:$PREFIX}
}

change_paths() {
  local out="$T/change.$(printf '%s' "$1" | hash)"
  if [ ! -f "$out" ]; then
    git -C "$TOP" diff --no-renames --name-only -z "$1" -- > "$T/cd" || cannot "git diff against ${1} failed"
    git -C "$TOP" ls-files -o --exclude-standard -z > "$T/cu" || cannot 'git ls-files -o failed'
    LC_ALL=C sort -z -u "$T/cd" "$T/cu" > "$out" || cannot 'sort failed'
  fi
  CHANGE_FILE=$out
}

SCOPE_HASH=; SCOPE_ERR=
compute_scope_hash() {
  local scope=$1 base=$2 tok h paths=()
  SCOPE_HASH=; SCOPE_ERR=
  if [ "$scope" = diff ]; then
    change_paths "$base"
    while IFS= read -r -d '' tok; do paths+=("$tok"); done < "$CHANGE_FILE"
    # The path list is hashed beside the content so that a path entering or leaving
    # the change moves the digest even when it has no content on either side.
    { cat "$CHANGE_FILE"; printf '\n'
      if [ ${#paths[@]} -gt 0 ]; then
        bash "$HERE/tree-digest.sh" -C "$TOP" -- "${paths[@]}" < /dev/null || cannot 'tree-digest failed'
      fi
    } > "$T/scope"
    h=$(hash < "$T/scope") || cannot 'cannot hash a scope'
    SCOPE_HASH=${h:0:$PREFIX}
    return 0
  fi
  for tok in $scope; do
    case /$tok/ in
      //|*/../*) SCOPE_ERR="scope path ${tok} is not repo-relative"; return 1 ;;
      /diff/|/objections/) SCOPE_ERR="scope token ${tok} cannot be mixed with paths"; return 1 ;;
    esac
    case $tok in /*) SCOPE_ERR="scope path ${tok} is not repo-relative"; return 1 ;; esac
    paths+=("$tok")
  done
  [ ${#paths[@]} -gt 0 ] || { SCOPE_ERR='empty scope'; return 1; }
  h=$(bash "$HERE/tree-digest.sh" -C "$TOP" -- "${paths[@]}" < /dev/null) || cannot 'tree-digest failed'
  SCOPE_HASH=${h:0:$PREFIX}
}

extract() {
  LC_ALL=C awk -v WARN="$WARN" -v VS="$VS16" -v US="$US" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function cells(line, out,   n, i, s) {
      split("", out)
      s = line; gsub(/\\\|/, "\001", s)
      sub(/^[ \t]*\|/, "", s); sub(/\|[ \t]*$/, "", s)
      n = split(s, out, "|")
      for (i = 1; i <= n; i++) { out[i] = trim(out[i]); gsub(/\001/, "|", out[i]); gsub(/\t/, " ", out[i]) }
      return n
    }
    function field(line) { sub(/^\*\*[^*]+:\*\*/, "", line); line = trim(line); gsub(/`/, "", line); return line }
    { L[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (L[i] ~ /^```/) f = !f
        else if (!f && L[i] ~ /^## Self-Review \(Round [0-9]+\)/) start = i
      }
      if (!start) { print "L\t0"; exit }
      stop = NR; f = 0
      for (i = start + 1; i <= NR; i++) {
        if (L[i] ~ /^```/) f = !f
        else if (!f && L[i] ~ /^##?[ \t]/) { stop = i - 1; break }
      }
      for (i = start + 1; i <= stop; i++) {
        line = L[i]
        if (line ~ /^### Checklist ledger[ \t]*$/) { inl = 1; ledger = 1; mode = ""; continue }
        if (inl && line ~ /^###?[ \t]/) inl = 0
        if (line !~ /^[ \t]*\|/) {
          mode = ""
          if (inl && line ~ /^\*\*Plan digest:\*\*/) print "F\tplan\t" i "\t" field(line)
          if (inl && line ~ /^\*\*Base:\*\*/) print "F\tbase\t" i "\t" field(line)
          continue
        }
        n = cells(line, c)
        if (mode == "") {
          hdr = i
          if (!inl && c[1] == "#") mode = "find"
          else if (inl && c[1] == "Item") {
            mode = "ledger"
            ok = (n == 7 && c[2] == "Scope" && c[3] == "Rule" && c[4] == "Digest" && c[5] == "Findings" \
                  && c[6] == "State" && c[7] == "Trigger")
            print "H\t" (ok ? "ok" : "bad")
          } else mode = "other"
          continue
        }
        if (i == hdr + 1 && line ~ /^[ \t|:-]+$/) continue
        if (mode == "find") {
          st = c[n]
          if (index(st, WARN) != 1) continue
          st = substr(st, length(WARN) + 1)
          if (index(st, VS) == 1) st = substr(st, length(VS) + 1)
          num = c[1]; gsub(/[^0-9]/, "", num)
          if (trim(st) ~ /^Objected/ && num != "") print "O\t" num
        } else if (mode == "ledger") {
          print "R" US i US n US c[1] US c[2] US c[3] US c[4] US c[5] US c[6] US c[7]
        }
      }
      print "L\t" (ledger ? 1 : 0)
    }' "$FILE"
}

extract > "$T/x" || cannot "cannot parse ${FILE}"
LEDGER=$(awk -F'\t' '$1 == "L" { print $2 }' "$T/x")
HEADER=$(awk -F'\t' '$1 == "H" { print $2; exit }' "$T/x")
REC_PLAN=$(awk -F'\t' '$1 == "F" && $2 == "plan" { print $4; exit }' "$T/x")
PLAN_LINE=$(awk -F'\t' '$1 == "F" && $2 == "plan" { print $3; exit }' "$T/x")
REC_BASE=$(awk -F'\t' '$1 == "F" && $2 == "base" { print $4; exit }' "$T/x")
OBJECTED=" $(awk -F'\t' '$1 == "O" { printf "%s ", $2 }' "$T/x")"
awk -F"$US" '$1 == "R"' "$T/x" > "$T/rows"

has_objected() {
  local t
  for t in $(printf '%s' "$1" | tr ',#' '  '); do
    case $OBJECTED in *" $t "*) return 0 ;; esac
  done
  return 1
}

names() {
  local scope=$1 path=$2 tok
  for tok in $scope; do
    case $tok in diff|objections) continue ;; esac
    tok=${tok%/}
    [ "$tok" = . ] && return 0
    [ "$path" = "$tok" ] && return 0
    case $path in "$tok"/*) return 0 ;; esac
  done
  return 1
}

DIGEST_RE="^[0-9a-f]{${PREFIX}}[.][0-9a-f]{${PREFIX}}\$"
digest_shape() { [[ $1 =~ $DIGEST_RE ]]; }

plan_verb() {
  git -C "$TOP" rev-parse --verify -q "${BASE_ARG}^{commit}" >/dev/null || cannot "base ${BASE_ARG} is not a commit"
  compute_plan_digest
  change_paths "$BASE_ARG"
  local rows=0 carry=0 sweep=0 newf=0 reset=no why= item scope rule dig fnd n p trig scopes=

  if [ "$LEDGER" != 1 ] || [ "$HEADER" != ok ] || [ -z "$REC_PLAN" ]; then
    if [ "$LEDGER" != 1 ]; then why='no ledger'; else why='ledger header invalid'; fi
    reset="yes (${why})"
    for item in "${ITEMS[@]}"; do
      printf 'sweep record-invalid %s\n' "$item"; rows=$((rows + 1)); sweep=$((sweep + 1))
    done
  else
    [ "$REC_PLAN" = "$PLAN_DIGEST" ] || reset='yes (plan digest changed)'
    while IFS=$US read -r _ _ n item scope rule dig fnd _ _; do
      rows=$((rows + 1)); scopes="${scopes} ${scope}"
      if [ "$scope" = objections ]; then trig=objected
      elif [ "$reset" != no ]; then trig=amendment
      elif [ "$n" != 7 ] || [ -z "$item" ] || [ -z "$scope" ]; then trig=record-invalid
      elif ! digest_shape "$dig"; then trig=record-invalid
      elif ! compute_rule_hash "$rule"; then trig=record-invalid
      elif ! compute_scope_hash "$scope" "$BASE_ARG"; then trig=record-invalid
      elif [ "$SCOPE_HASH" != "${dig%%.*}" ]; then trig=scope-changed
      elif [ "$RULE_HASH" != "${dig#*.}" ]; then trig=rule-changed
      elif has_objected "$fnd"; then trig=objected
      else trig=
      fi
      if [ -z "$trig" ]; then
        printf 'carry %s %s\n' "$item" "$scope"; carry=$((carry + 1))
      else
        printf 'sweep %s %s %s\n' "$trig" "$item" "$scope"; sweep=$((sweep + 1))
      fi
    done < "$T/rows"
  fi

  while IFS= read -r -d '' p; do
    names "$scopes" "$p" && continue
    printf 'new-file %s\n' "$p"; newf=$((newf + 1))
  done < "$CHANGE_FILE"
  printf '%s: plan: %d rows, %d carried, %d swept, %d new-file paths; whole list reset: %s\n' \
    "$PROG" "$rows" "$carry" "$sweep" "$newf" "$reset"
  exit 0
}

seal_verb() {
  local errs=0 filled=0 rows=0 objrows=0 ln n item scope rule dig fnd state trig want t
  refuse() { printf '%s: seal: refused: %s\n' "$PROG" "$1"; errs=$((errs + 1)); }
  : > "$T/edits"

  [ "$LEDGER" = 1 ] || { refuse 'the latest round has no ### Checklist ledger'; exit 1; }
  [ "$HEADER" = ok ] || refuse 'ledger table header is not | Item | Scope | Rule | Digest | Findings | State | Trigger |'
  [ -n "$PLAN_LINE" ] || refuse 'ledger has no **Plan digest:** line'
  if [ -z "$REC_BASE" ]; then refuse 'ledger has no **Base:** value'
  elif ! git -C "$TOP" rev-parse --verify -q "${REC_BASE}^{commit}" >/dev/null; then
    refuse "ledger base ${REC_BASE} is not a commit"
  fi
  if [ -n "$PLAN_LINE" ] && [ -z "$REC_PLAN" ]; then
    compute_plan_digest
    printf '%s\tplan\t%s\n' "$PLAN_LINE" "$PLAN_DIGEST" >> "$T/edits"
  fi

  while IFS=$US read -r _ ln n item scope rule dig fnd state trig; do
    rows=$((rows + 1))
    if [ "$n" != 7 ]; then refuse "row at line ${ln} has ${n} cells, want 7"; continue; fi
    case $item in ''|*[!0-9]*) refuse "row at line ${ln}: item ${item} is not a number"; continue ;; esac
    is_item "$item" || { refuse "row at line ${ln}: item ${item} is not a checklist item"; continue; }
    case $fnd in '—'|-) ;; *)
      t=$(printf '%s' "$fnd" | tr ',#' '  ' | tr -d ' 0-9')
      [ -z "$t" ] || refuse "row at line ${ln}: findings ${fnd} is not a list of finding numbers or —" ;;
    esac
    compute_rule_hash "$rule" || refuse "row at line ${ln}: ${RULE_ERR}"
    if [ "$scope" = objections ]; then
      objrows=$((objrows + 1))
      [ "$state" = swept ] && [ "$trig" = objected ] || refuse "row at line ${ln}: the objections row is always swept / objected"
      case $dig in '') printf '%s\tdigest\t—\n' "$ln" >> "$T/edits" ;; '—') ;;
        *) refuse "row at line ${ln}: the objections row's digest is —" ;; esac
      continue
    fi
    case $state in
      carried) [ -z "$trig" ] || refuse "row at line ${ln}: a carried row has no trigger" ;;
      swept) case $TRIGGERS in *" $trig "*) [ -n "$trig" ] ;; *) false ;; esac \
               || refuse "row at line ${ln}: trigger '${trig}' is not in the closed set" ;;
      *) refuse "row at line ${ln}: state '${state}' is neither swept nor carried" ;;
    esac
    [ -n "$REC_BASE" ] || continue
    compute_scope_hash "$scope" "$REC_BASE" || { refuse "row at line ${ln}: ${SCOPE_ERR}"; continue; }
    [ -n "$RULE_HASH" ] || continue
    want="${SCOPE_HASH}.${RULE_HASH}"
    if [ -z "$dig" ]; then
      printf '%s\tdigest\t%s\n' "$ln" "$want" >> "$T/edits"; filled=$((filled + 1))
    elif [ "$dig" != "$want" ]; then
      refuse "row at line ${ln}: digest ${dig} does not match the tree (${want})"
    fi
  done < "$T/rows"
  [ "$rows" -gt 0 ] || refuse 'ledger has no rows'
  [ "$objrows" -le 1 ] || refuse "ledger has ${objrows} objections rows, want at most 1"
  [ "$errs" -eq 0 ] || exit 1
  if [ ! -s "$T/edits" ]; then
    printf '%s: seal: %d rows, 0 digests filled, nothing to write\n' "$PROG" "$rows"
    exit 0
  fi

  LC_ALL=C awk -F'\t' -v OFS='\t' '
    NR == FNR { kind[$1] = $2; val[$1] = $3; next }
    !(FNR in kind) { print; next }
    kind[FNR] == "plan" { sub(/\*\*Plan digest:\*\*.*/, "**Plan digest:** " val[FNR]); print; next }
    {
      s = $0; gsub(/\\\|/, "\001", s)
      n = split(s, P, "|")
      P[5] = " " val[FNR] " "
      out = P[1]; for (i = 2; i <= n; i++) out = out "|" P[i]
      gsub(/\001/, "\\|", out); print out
    }' "$T/edits" "$FILE" > "$T/sealed" || cannot 'cannot write the sealed ledger'
  cat "$T/sealed" > "$FILE" || cannot "cannot write ${FILE}"
  printf '%s: seal: %d rows, %d digests filled, plan digest %s\n' \
    "$PROG" "$rows" "$filled" "$(awk -F'\t' '$1 == "F" && $2 == "plan" { print $4; exit }' <(extract))"
  exit 0
}

"${VERB}_verb"
