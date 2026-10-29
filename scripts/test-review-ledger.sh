#!/usr/bin/env bash

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case $2 in *"$3"*) ok "$1" ;; *) bad "$1 (no [$3] in: $2)" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1 (found [$3] in: $2)" ;; *) ok "$1" ;; esac; }

D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

P="$D/plugin"
mkdir -p "$P/scripts" "$P/agents"
cp "$HERE/review-ledger.sh" "$HERE/tree-digest.sh" "$HERE/plan-freeze.sh" "$P/scripts/"
cat > "$P/agents/self-review.md" <<'EOF'
# Reviewer
## Checklist
### 1. Spec conformance
Every criterion.
### 5. Style
No narration.
### 7. Objection quality (round > 1 only)
Reasons.
## Rules
EOF
RL="$P/scripts/review-ledger.sh"

R="$D/repo"
mkdir -p "$R/src" "$R/plans"
cd "$R" || exit 2
git init -q
git config user.email t@t
git config user.name t
printf 'progress.md\n*.bak\n' > .gitignore
printf 'a\n' > src/a.sh
printf 'b\n' > src/b.sh
cat > rules.md <<'EOF'
# Rules
## 1. Alpha rule
alpha text
## 2. Beta rule
beta text
### 2.1 Beta detail
detail
## 3. Gamma
gamma
EOF
printf '# Spec\nCriterion one.\n' > plans/x.spec.md
printf '# Design\nItem one.\n' > plans/x.design.md
git add .gitignore src rules.md plans
git commit -q -m base
BASE=$(git rev-parse HEAD)
printf 'a changed\n' > src/a.sh
printf 'b changed\n' > src/b.sh

round() {
  cat >> progress.md <<EOF

## Self-Review (Round $1)

**Verdict:** REJECT

| # | File:line | Severity | Finding | Status |
|---|-----------|----------|---------|--------|
| 1 | src/a.sh:1 | major | one | ⬜ Open |
| 2 | src/b.sh:1 | minor | two | ⬜ Open |

### Checklist ledger

**Plan digest:**
**Base:** \`$BASE\`

| Item | Scope | Rule | Digest | Findings | State | Trigger |
|---|---|---|---|---|---|---|
| 1 | diff | \${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#1-spec-conformance |  | — | swept | first-round |
| 5 | src/a.sh | \${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#5-style rules.md#1 |  | 1 | swept | first-round |
| 5 | src | \${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#5-style rules.md#2-beta-rule |  | 2 | swept | first-round |
EOF
}
plan() { bash "$RL" plan progress.md --base "$BASE" "$@"; }
seal() { bash "$RL" seal progress.md "$@"; }

printf '\n== absent ledger ==\n'
: > progress.md
out=$(plan); rc=$?
same "plan over an empty findings file exits 0" "$rc" 0
has "every item swept record-invalid (1)" "$out" "sweep record-invalid 1"
has "every item swept record-invalid (7)" "$out" "sweep record-invalid 7"
has "every changed path listed" "$out" "new-file src/a.sh"
has "verdict names the reset" "$out" "whole list reset: yes (no ledger)"

printf '\n== seal fills the blanks and nothing else ==\n'
round 1
cp progress.md "$D/before"
out=$(seal --plan plans/x.spec.md --plan plans/x.design.md); rc=$?
same "seal exits 0" "$rc" 0
has "seal reports the filled count" "$out" "3 digests filled"
pd=$(grep -E '^\*\*Plan digest:\*\* ' progress.md | sed 's/^\*\*Plan digest:\*\* //')
case $pd in [0-9a-f]*) same "plan digest filled with a 12-hex prefix" "${#pd}" 12 ;; *) bad "plan digest filled (got [$pd])" ;; esac
changed=$(diff "$D/before" progress.md | grep -cE '^>')
same "exactly four lines rewritten" "$changed" 4
dg=$(grep -E '^\| 5 \| src/a.sh' progress.md | awk -F'|' '{ gsub(/ /, "", $5); print $5 }')
case $dg in [0-9a-f]*.[0-9a-f]*) same "digest is two 12-hex halves" "${#dg}" 25 ;; *) bad "digest shape (got [$dg])" ;; esac
cp progress.md "$D/sealed"
out=$(seal --plan plans/x.spec.md --plan plans/x.design.md); rc=$?
same "a second seal exits 0" "$rc" 0
has "and writes nothing" "$out" "nothing to write"
same "file unchanged by the second seal" "$(cmp -s "$D/sealed" progress.md && echo same)" same

printf '\n== unchanged tree carries every row ==\n'
out=$(plan --plan plans/x.design.md --plan plans/x.spec.md); rc=$?
same "plan exits 0" "$rc" 0
has "diff row carried" "$out" "carry 1 diff"
has "file row carried" "$out" "carry 5 src/a.sh"
has "directory row carried" "$out" "carry 5 src"
hasnt "no new-file for covered paths" "$out" "new-file src/"
has "verdict" "$out" "3 rows, 3 carried, 0 swept, 0 new-file paths; whole list reset: no"

printf '\n== an ignored file and staging move nothing ==\n'
git add src/a.sh
cp progress.md "$D/pre-note"
printf 'note\n' >> progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "still all carried" "$out" "3 carried, 0 swept"
git reset -q src/a.sh
cp "$D/pre-note" progress.md

printf '\n== one-file fix resets only its rows ==\n'
printf 'a fixed\n' > src/a.sh
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "the file's row is scope-changed" "$out" "sweep scope-changed 5 src/a.sh"
has "the directory row covering it too" "$out" "sweep scope-changed 5 src"
has "the diff row too" "$out" "sweep scope-changed 1 diff"
printf 'a changed\n' > src/a.sh
printf 'b fixed\n' > src/b.sh
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "an edit outside a row's scope leaves it carried" "$out" "carry 5 src/a.sh"
printf 'b changed\n' > src/b.sh

printf '\n== rule text ==\n'
sed -i.bak 's/alpha text/alpha text, stricter/' rules.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a changed rule section gives rule-changed" "$out" "sweep rule-changed 5 src/a.sh"
has "a row citing another section carries" "$out" "carry 5 src"
mv rules.md.bak rules.md
sed -i.bak 's/^detail$/detail, stricter/' rules.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a nested subsection belongs to its parent's section" "$out" "sweep rule-changed 5 src"
mv rules.md.bak rules.md
sed -i.bak 's/^gamma$/gamma, stricter/' rules.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a sibling section after it does not" "$out" "carry 5 src"
mv rules.md.bak rules.md

printf '\n== where a rule reference resolves ==\n'
cp "$P/agents/self-review.md" "$D/sr"
sed -i.bak 's/^No narration\.$/No narration, stricter./' "$P/agents/self-review.md"
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a \${CLAUDE_PLUGIN_ROOT}/ reference hashes the plugin's copy" "$out" "sweep rule-changed 5 src/a.sh"
cp "$D/sr" "$P/agents/self-review.md"
cp rules.md "$P/rules.md"
sed -i.bak 's/alpha text/alpha text, stricter/' rules.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a bare reference hashes the project's copy, not the plugin's" "$out" "sweep rule-changed 5 src/a.sh"
mv rules.md.bak rules.md
rm "$P/rules.md"
cp progress.md "$D/pre-ref"
sed -i.bak 's#| ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md\#5-style rules.md\#1 |#| agents/self-review.md\#5-style rules.md\#1 |#' \
  progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a bare reference to a plugin-only page does not resolve" "$out" "sweep record-invalid 5 src/a.sh"
cp "$D/pre-ref" progress.md
PR='${CLAUDE_PLUGIN_ROOT}'
sed -i.bak "s#rules.md\\#1 |#${PR}/rules.md\\#1 |#" progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a \${CLAUDE_PLUGIN_ROOT}/ reference to a project-only page does not" "$out" "sweep record-invalid 5 src/a.sh"
cp "$D/pre-ref" progress.md

printf '\n== objected finding ==\n'
cp progress.md "$D/pre-obj"
sed -i.bak 's/| 2 | src\/b.sh:1 | minor | two | ⬜ Open |/| 2 | src\/b.sh:1 | minor | two | ⚠️ Objected — by design |/' progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a row whose finding is objected is swept" "$out" "sweep objected 5 src"
has "a row whose finding is not stays carried" "$out" "carry 5 src/a.sh"
cp "$D/pre-obj" progress.md

printf '\n== new file in the change ==\n'
printf 'c\n' > src/c.sh
printf 'n\n' > new.sh
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a path covered by a directory scope is not new" "$out" "sweep scope-changed 5 src"
hasnt "so src/c.sh is not listed" "$out" "new-file src/c.sh"
has "a path covered only by the diff row is listed" "$out" "new-file new.sh"
has "and the diff row resets on the moved path set" "$out" "sweep scope-changed 1 diff"
rm src/c.sh new.sh

printf '\n== plan digest ==\n'
printf '# Design\nItem one, amended.\n' > plans/x.design.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "an amendment sweeps every row" "$out" "3 swept"
has "as amendment" "$out" "sweep amendment 5 src/a.sh"
has "and says the whole list reset" "$out" "whole list reset: yes (plan digest changed)"
git checkout -q -- plans/x.design.md
out=$(plan)
has "no plan documents against a recorded digest is an amendment" "$out" "sweep amendment 1 diff"

printf '\n== the objections row ==\n'
cp progress.md "$D/pre-o"
printf '| 7 | objections | ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#7 | — | — | swept | objected |\n' >> progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "always swept as objected" "$out" "sweep objected 7 objections"
has "while the rest carry" "$out" "carry 5 src/a.sh"
out=$(plan)
has "even under an amendment" "$out" "sweep objected 7 objections"
cp "$D/pre-o" progress.md

printf '\n== an edited or broken record is swept ==\n'
cp progress.md "$D/pre-t"
sed -i.bak -E 's/^(\| 5 \| src\/a.sh \| [^|]+\| )[0-9a-f]{12}/\1000000000000/' progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a digest edited to no longer match is swept" "$out" "sweep scope-changed 5 src/a.sh"
cp "$D/pre-t" progress.md
sed -i.bak -E 's/^(\| 5 \| src\/a.sh \| [^|]+\| )[0-9a-f]{12}\./\1zz./' progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a digest out of shape is record-invalid" "$out" "sweep record-invalid 5 src/a.sh"
cp "$D/pre-t" progress.md
sed -i.bak 's/| 1 | swept | first-round |/| swept | first-round |/' progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a row with a missing cell is record-invalid" "$out" "sweep record-invalid 5 src/a.sh"
cp "$D/pre-t" progress.md
sed -i.bak 's/rules.md#1 /rules.md#9-nowhere /' progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "an unresolvable rule is record-invalid" "$out" "sweep record-invalid 5 src/a.sh"
cp "$D/pre-t" progress.md
sed -i.bak 's/^\*\*Plan digest:\*\* .*/**Plan digest:**/' progress.md
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a blank plan digest invalidates the ledger" "$out" "whole list reset: yes (ledger header invalid)"
cp "$D/pre-t" progress.md

printf '\n== the latest round is the one read ==\n'
cat >> progress.md <<'EOF'

## Self-Review (Round 2)

**Verdict:** APPROVE
EOF
out=$(plan --plan plans/x.spec.md --plan plans/x.design.md)
has "a later round without a ledger reads as absent" "$out" "whole list reset: yes (no ledger)"
cp "$D/pre-t" progress.md

printf '\n== seal refusals write nothing ==\n'
refused() {
  local name=$1 expr=$2 want=$3
  : > progress.md; round 1
  sed -i.bak "$expr" progress.md
  cp progress.md "$D/r"
  out=$(seal); rc=$?
  same "$name exits 1" "$rc" 1
  has "$name names the reason" "$out" "$want"
  same "$name leaves the file" "$(cmp -s "$D/r" progress.md && echo same)" same
}
refused "unknown trigger" 's/| 2 | swept | first-round |/| 2 | swept | because |/' "trigger 'because' is not in the closed set"
refused "carried with a trigger" 's/| 2 | swept | first-round |/| 2 | carried | first-round |/' "a carried row has no trigger"
refused "unknown state" 's/| 2 | swept | first-round |/| 2 | skipped | |/' "neither swept nor carried"
refused "item outside the checklist" 's/^| 5 | src |/| 6 | src |/' "item 6 is not a checklist item"
refused "unresolvable rule" 's/rules.md#2-beta-rule/rules.md#nope/' "rule reference rules.md#nope does not resolve"
refused "typed digest" 's/rules.md#1 |  |/rules.md#1 | 111111111111.222222222222 |/' "does not match the tree"
refused "missing base" 's/^\*\*Base:\*\* .*/**Base:**/' "no **Base:** value"
refused "absolute scope" 's/^| 5 | src |/| 5 | \/etc |/' "not repo-relative"
refused "objections row with a digest" '$ a\
| 7 | objections | ${CLAUDE_PLUGIN_ROOT}/agents/self-review.md#7 | abc | — | swept | objected |
' "the objections row's digest is —"
: > progress.md; printf '## Self-Review (Round 1)\n' > progress.md
out=$(seal); rc=$?
same "a round with no ledger refuses" "$rc" 1

printf '\n== seal with no plan documents ==\n'
: > progress.md; round 1
seal > /dev/null
has "writes none" "$(grep -E '^\*\*Plan digest:\*\*' progress.md)" "**Plan digest:** none"
out=$(plan)
has "and plan with none passed carries" "$out" "3 carried"

printf '\n== CLAUDE_PLUGIN_ROOT locates the contract ==\n'
mkdir -p "$D/bare"
cp "$RL" "$P/scripts/tree-digest.sh" "$D/bare/"
out=$(CLAUDE_PLUGIN_ROOT="$P" bash "$D/bare/review-ledger.sh" plan progress.md --base "$BASE"); rc=$?
same "a script outside the plugin finds it through the variable" "$rc" 0
out=$(env -u CLAUDE_PLUGIN_ROOT bash "$D/bare/review-ledger.sh" plan progress.md --base "$BASE" 2>&1); rc=$?
same "and without it cannot run" "$rc" 2

printf '\n== cannot run ==\n'
bash "$RL" plan missing.md --base "$BASE" 2>/dev/null
same "a missing findings file exits 2" "$?" 2
bash "$RL" plan progress.md --base nosuchrev 2>/dev/null
same "a base that is no commit exits 2" "$?" 2
bash "$RL" plan progress.md 2>/dev/null
same "plan without --base exits 2" "$?" 2
bash "$RL" plan progress.md --base "$BASE" --plan missing.md 2>/dev/null
same "a missing plan document exits 2" "$?" 2
bash "$RL" frob progress.md 2>/dev/null
same "an unknown verb exits 2" "$?" 2
cp progress.md "$D/out.md"
(cd "$D" && bash "$RL" plan out.md --base "$BASE" 2>/dev/null)
same "outside a repository exits 2" "$?" 2

printf '\n== the plan digest over the frozen plan ==\n'
R2="$D/frozen-repo"
mkdir -p "$R2/src" "$R2/ai-docs/plans/done"
cp rules.md "$R2/rules.md"
cd "$R2" || exit 2
git init -q
git config user.email t@t
git config user.name t
printf 'progress.md\n' > .gitignore
printf 'a\n' > src/a.sh
printf 'b\n' > src/b.sh
FS=ai-docs/plans/x.spec.md
FD=ai-docs/plans/x.design.md
printf '# Spec\nCriterion one.\n' > "$FS"
printf '# Design\nItem one.\n' > "$FD"
git add -A
git commit -q -m base
BASE=$(git rev-parse HEAD)
git commit -q --allow-empty -m freeze -m 'Plan-Freeze: x'
printf 'a changed\n' > src/a.sh
printf 'b changed\n' > src/b.sh
: > progress.md; round 1
out=$(seal --plan "$FS" --frozen "$FS" --frozen "$FD"); rc=$?
same "seal over the frozen plan exits 0" "$rc" 0
out=$(plan --plan "$FS" --frozen "$FS" --frozen "$FD")
has "an untouched plan carries" "$out" "whole list reset: no"
printf '# Design\nItem one, as shipped.\n' > "$FD"
out=$(plan --plan "$FS" --frozen "$FS" --frozen "$FD")
has "a design corrected in place leaves the digest" "$out" "whole list reset: no"
printf '# Spec\nCriterion one, amended.\n' > "$FS"
out=$(plan --plan "$FS" --frozen "$FS" --frozen "$FD")
has "an approved spec change moves the live half" "$out" "whole list reset: yes (plan digest changed)"
git checkout -q -- "$FS"
git add "$FD"
git commit -q -m work
git mv "$FS" ai-docs/plans/done/
git mv "$FD" ai-docs/plans/done/
git commit -q -m archive
AS=ai-docs/plans/done/x.spec.md
AD=ai-docs/plans/done/x.design.md
out=$(plan --plan "$AS" --frozen "$AS" --frozen "$AD")
has "the move into the archive leaves the digest" "$out" "whole list reset: no"
git commit -q --allow-empty -m refreeze -m 'Plan-Freeze: x'
out=$(plan --plan "$AS" --frozen "$AS" --frozen "$AD")
has "a new freeze moves the frozen half" "$out" "whole list reset: yes (plan digest changed)"
printf '# Design\n' > ai-docs/plans/y.design.md
bash "$RL" plan progress.md --base "$BASE" --frozen ai-docs/plans/y.design.md > "$D/nf" 2>&1
same "a frozen document with no freeze is a cannot-run" "$?" 2
has "  naming the document" "$(cat "$D/nf")" "could not resolve the frozen text of ai-docs/plans/y.design.md"
: > progress.md; round 1
cp progress.md "$D/pre-nf"
bash "$RL" seal progress.md --frozen ai-docs/plans/y.design.md > "$D/nf" 2>&1
same "and a seal filling the digest from it cannot run either" "$?" 2
same "  writing nothing" "$(cmp -s "$D/pre-nf" progress.md && echo same)" same

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
