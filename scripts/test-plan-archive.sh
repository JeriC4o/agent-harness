#!/usr/bin/env bash
#
# Tests for plan-archive.sh.
#
# Run: bash scripts/test-plan-archive.sh
#
# The listing is invoked BY PATH, as a skill invokes it, so a lost execute bit
# fails here rather than in the review that depends on it. Fixture archives are
# built in throwaway project roots; the method inputs are the live ones beside
# the script, except in the legs that break them, which run a copy of the
# plugin layout.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
LIST="${HERE}/plan-archive.sh"
REPO=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in [$2]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3]" ;; *) ok "$1" ;; esac; }

D=$(cd -- "$(mktemp -d)" && pwd -P)
trap 'chmod -R u+rwx "$D" 2>/dev/null; rm -rf "$D"' EXIT

run()  { OUT=$("$LIST" "$@" 2>"${D}/stderr"); RC=$?; ERR=$(cat "${D}/stderr"); }
runp() { local p=$1; shift; OUT=$("$p" "$@" 2>"${D}/stderr"); RC=$?; ERR=$(cat "${D}/stderr"); }

# <listing> <frame line prefix> -> the lines that frame states follow it
body_of() {
  printf '%s\n' "$1" | awk -v want="$2" '
    take > 0 { print; take--; next }
    index($0, want) == 1 { n = $0; sub(/.*\(/, "", n); sub(/ line.*/, "", n); take = n + 0 }'
}

new_root() { R="${D}/$1"; A="${R}/ai-docs/plans/done"; mkdir -p "$A"; }

SPEC_FULL='# A plan

**Source:** ticket T-1
**Date:** 2026-01-01
**Tracked in:** T-1

## Scope

1. Scope text that must not be listed.

## Out of scope

- Left out on purpose.

```text
## Deferred
```

### A subsection stays inside

## Deferred

| What | Why |
|---|---|
| Later | Not now |

## Key decisions

| Question | Decision |
|---|---|
| Which? | This one. |

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Criterion text that must not be listed. |'

SPEC_COLLAPSED='## Out of scope

- Left out on purpose.

```text
## Deferred
```

### A subsection stays inside

## Deferred

| What | Why |
|---|---|
| Later | Not now |

## Key decisions

| Question | Decision |
|---|---|
| Which? | This one. |'

DESIGN_QUOTING='# Design: a plan

**Ticket:** T-9 **Date:** 2026-02-02 **Spec:** ai-docs/plans/done/x.spec.md

## Approach

Approach text that must not be listed. A template reads:

~~~markdown
## Use cases

- a quoted case that is not real
~~~

## Use cases

- the real case
- a second real case

# A level-one heading ends it

trailing text that must not be listed'

printf '\n== every plan is listed, with date, key and document names ==\n'
new_root r1
printf '%s\n' "$SPEC_FULL" > "${A}/2026-01-01-both.spec.md"
printf '%s\n' "$DESIGN_QUOTING" > "${A}/2026-01-01-both.design.md"
printf '%s\n' "$SPEC_FULL" > "${A}/2026-01-02-spec-only.spec.md"
printf '%s\n' "$DESIGN_QUOTING" > "${A}/2026-01-03-design-only.design.md"
printf '# Bare\n\nNothing here.\n' > "${A}/2026-01-04-bare.spec.md"
printf '# Bare\n\nNothing here.\n' > "${A}/2026-01-04-bare.design.md"
printf '# Undated\n' > "${A}/undated.design.md"
for ignored in 2026-01-01-both.links.md 2026-01-01-both.progress.md 2026-01-01-both.redline.md 2026-01-01-both.design-evidence.md; do
  printf '## Out of scope\n\nnot a plan document\n' > "${A}/${ignored}"
done
run "$R"
check "a complete listing is exit 0" "$RC" "0"
has   "  the trailer counts the plans and the documents" "$OUT" "plan-archive: complete archive=${A} plans=5 documents=7"
check "  nothing on stderr" "$ERR" ""
check "  plans print in stem order" \
      "$(printf '%s\n' "$OUT" | sed -n 's/^=== plan //p' | tr '\n' ' ')" \
      "2026-01-01-both 2026-01-02-spec-only 2026-01-03-design-only 2026-01-04-bare undated "
has   "  a plan with no section is still listed" "$OUT" "=== plan 2026-01-04-bare"
has   "  a missing design shows as missing" "$OUT" "=== plan 2026-01-02-spec-only
date: 2026-01-02
key: T-1
spec: 2026-01-02-spec-only.spec.md
design: missing"
has   "  a missing spec shows as missing, the key coming from the design" "$OUT" "=== plan 2026-01-03-design-only
date: 2026-01-03
key: T-9
spec: missing
design: 2026-01-03-design-only.design.md"
has   "  a stem without a date shows the date as absent" "$OUT" "=== plan undated
date: absent"
hasnt "  no other file in the archive is listed" "$OUT" "not a plan document"
hasnt "  nor named" "$OUT" ".links.md"

printf '\n== sections: verbatim, heading included, naming their document ==\n'
check "the spec's record of deliberate absence, verbatim" \
      "$(body_of "$OUT" '--- spec 2026-01-01-both.spec.md: ## Out of scope')" \
      "$(printf '%s\n' "$SPEC_COLLAPSED" | sed -n '/^## Out of scope$/,/^### A subsection stays inside$/p')"
check "  the deferred section ends at the next heading of its level" \
      "$(body_of "$OUT" '--- spec 2026-01-01-both.spec.md: ## Deferred')" \
      "## Deferred

| What | Why |
|---|---|
| Later | Not now |"
check "  the last section runs to the next heading of its level" \
      "$(body_of "$OUT" '--- spec 2026-01-01-both.spec.md: ## Key decisions')" \
      "## Key decisions

| Question | Decision |
|---|---|
| Which? | This one. |"
check "  a section's stated count is the number of lines it frames" \
      "$(printf '%s\n' "$OUT" | grep -c '^--- spec 2026-01-01-both.spec.md: ## Out of scope (10 lines follow)$')" "1"
check "  the spec's three come in the order the fold's list gives, then the design's" \
      "$(printf '%s\n' "$OUT" | sed -n '/^=== plan 2026-01-01-both$/,/^=== plan 2026-01-02/p' | sed -n 's/^--- \([a-z]*\) [^:]*: \(.*\) (.*/\1 \2/p' | tr '\n' '|')" \
      "spec ## Out of scope|spec ## Deferred|spec ## Key decisions|design ## Use cases|"

printf '\n== a heading inside a fenced block neither starts nor ends a section ==\n'
check "the design lists its real use cases only, ended by a level-one heading" \
      "$(body_of "$OUT" '--- design 2026-01-01-both.design.md: ## Use cases')" \
      "## Use cases

- the real case
- a second real case"
check "  one use-case section, not two" \
      "$(printf '%s\n' "$OUT" | grep -c '^--- design 2026-01-01-both.design.md: ## Use cases')" "1"
hasnt "  the quoted case never appears" "$OUT" "a quoted case that is not real"
has   "  a quoted heading inside the spec's section stays in it, and a deeper heading does not end it" \
      "$(body_of "$OUT" '--- spec 2026-01-01-both.spec.md: ## Out of scope')" '```text
## Deferred
```

### A subsection stays inside'

printf '\n== absent and empty read differently ==\n'
has   "a section a document does not carry is absent" "$OUT" \
      "--- spec 2026-01-04-bare.spec.md: ## Out of scope (absent)"
has   "  every section of a missing document is absent" "$OUT" \
      "--- design missing: ## Use cases (absent)"
new_root r2
printf '# S\n\n## Out of scope\n\n## Deferred\n\nx\n' > "${A}/2026-03-01-empty.spec.md"
run "$R"
has   "a section with nothing under its heading prints its heading line alone" "$OUT" \
      "--- spec 2026-03-01-empty.spec.md: ## Out of scope (2 lines follow)
## Out of scope
"
check "  a heading followed directly by the next is one line" \
      "$(printf '# S\n## Out of scope\n## Deferred\n' > "${A}/2026-03-01-empty.spec.md"; run "$R"; body_of "$OUT" '--- spec 2026-03-01-empty.spec.md: ## Out of scope')" \
      "## Out of scope"
has   "  and says one line follows" "$("$LIST" "$R")" "## Out of scope (1 line follows)"

printf '\n== nothing beyond the date, key, names and the four sections ==\n'
run "${D}/r1"
hasnt "the scope never appears" "$OUT" "Scope text that must not be listed"
hasnt "  nor the criteria" "$OUT" "Criterion text that must not be listed"
hasnt "  nor the approach" "$OUT" "Approach text that must not be listed"
hasnt "  nor the title or header fields" "$OUT" "**Source:**"
hasnt "  nor text after the section's end" "$OUT" "trailing text that must not be listed"

printf '\n== a collapsed spec lists as a full one does ==\n'
new_root r3
printf '%s\n' "$SPEC_FULL" > "${A}/2026-04-01-full.spec.md"
printf '%s\n\n' "$SPEC_COLLAPSED" > "${A}/2026-04-02-folded.spec.md"
printf '%s\n' "$DESIGN_QUOTING" > "${A}/2026-04-02-folded.design.md"
cp "${A}/2026-04-02-folded.spec.md" "${D}/folded-before"
run "$R"
for h in '## Out of scope' '## Deferred' '## Key decisions'; do
  check "the same listed text for ${h}" \
        "$(body_of "$OUT" "--- spec 2026-04-02-folded.spec.md: ${h}")" \
        "$(body_of "$OUT" "--- spec 2026-04-01-full.spec.md: ${h}")"
done
check "  with the same line counts, so no trailing line was dropped" \
      "$(printf '%s\n' "$OUT" | sed -n 's/^--- spec 2026-04-02-folded.spec.md: //p')" \
      "$(printf '%s\n' "$OUT" | sed -n 's/^--- spec 2026-04-01-full.spec.md: //p')"
has   "  the collapsed spec's plan takes its date from the file name and its key from the design" "$OUT" \
      "=== plan 2026-04-02-folded
date: 2026-04-02
key: T-9"
check "  and the archived document is not edited" "$(cmp -s "${A}/2026-04-02-folded.spec.md" "${D}/folded-before"; echo $?)" "0"

printf '\n== the key is shown alone, or as absent ==\n'
has   "a key sharing its line with other fields is shown alone" "$OUT" "key: T-9
spec:"
new_root r4
printf '# S\n\n**Tracked in:**   \n\n## Scope\n\n**Tracked in:** NOT-THE-HEAD\n' > "${A}/2026-05-01-nokey.spec.md"
printf '# D\n\n```text\n**Ticket:** IN-A-FENCE\n```\n\n## Approach\n\n**Ticket:** NOT-THE-HEAD\n' > "${A}/2026-05-01-nokey.design.md"
printf '# S\n\n**Tracked in:** K-7 ·\n' > "${A}/2026-05-02-separator.spec.md"
printf '# S\n\n**Tracked in:** K-8, \n' > "${A}/2026-05-03-comma.spec.md"
run "$R"
has   "a plan naming its key in neither document shows the key as absent" "$OUT" "=== plan 2026-05-01-nokey
date: 2026-05-01
key: absent"
hasnt "  a label past the head is not read" "$OUT" "NOT-THE-HEAD"
hasnt "  nor one inside a fenced block in the head" "$OUT" "IN-A-FENCE"
has   "a trailing separator is trimmed" "$OUT" "key: K-7
"
has   "  a trailing comma too" "$OUT" "key: K-8
"

printf '\n== every run reads the archive as it stands ==\n'
new_root r5
printf '# S\n\n## Deferred\n\nfirst\n' > "${A}/2026-06-01-a.spec.md"
run "$R"
has   "the first read" "$OUT" "first"
printf '# S\n\n## Deferred\n\nsecond\n' > "${A}/2026-06-01-a.spec.md"
printf '# S\n\n**Tracked in:** NEW-1\n' > "${A}/2026-06-02-b.spec.md"
run "$R"
has   "  a changed plan appears as it now is" "$OUT" "second"
hasnt "  and not as it was" "$OUT" "first"
has   "  a newly archived plan appears" "$OUT" "key: NEW-1"

printf '\n== the root: argument, work tree, current directory ==\n'
new_root r6
git -C "$R" init -q
printf '# S\n\n**Tracked in:** WT-1\n' > "${A}/2026-07-01-wt.spec.md"
mkdir -p "${R}/deep/er"
OUT=$(cd "${R}/deep/er" && "$LIST" 2>&1); RC=$?
check "without an argument, the work tree's top level" "$RC" "0"
has   "  lists that project's archive" "$OUT" "key: WT-1"
new_root r7
printf '# S\n\n**Tracked in:** CWD-1\n' > "${A}/2026-07-02-cwd.spec.md"
OUT=$(cd "$R" && GIT_CEILING_DIRECTORIES="$D" "$LIST" 2>&1); RC=$?
check "outside a work tree, the current directory" "$RC" "0"
has   "  lists its archive" "$OUT" "key: CWD-1"

# An installed copy: the plugin layout somewhere else, the project its own tree.
P="${D}/plugin"
mkdir -p "${P}/scripts" "${P}/docs"
cp "$LIST" "${REPO}/scripts/check-redline.sh" "${P}/scripts/"
cp "${REPO}/docs/plan-invariants.md" "${P}/docs/"
OUT=$(cd "${D}/r6" && "${P}/scripts/plan-archive.sh" 2>&1); RC=$?
check "an installed copy run in a project" "$RC" "0"
has   "  lists the project's archive, not its own" "$OUT" "archive=${D}/r6/ai-docs/plans/done plans=1"

printf '\n== the two outcomes ==\n'
new_root r8
run "$R"
check "an empty archive is complete" "$RC" "0"
has   "  with a plan count of zero" "$OUT" "plans=0 documents=0"
run "${D}/nowhere"
check "a root that does not exist is exit 2" "$RC" "2"
mkdir -p "${D}/noarchive"
run "${D}/noarchive"
check "no archive directory is exit 2" "$RC" "2"
check "  printing only the reason, nothing on standard output" "$OUT" ""
has   "  and the reason names the archive" "$ERR" "no archive at ${D}/noarchive/ai-docs/plans/done"
run "${D}/r1" extra
check "two arguments are a usage error, exit 2" "$RC" "2"
"$LIST" "${D}/r1" >&- 2>"${D}/stderr"; RC=$?; ERR=$(cat "${D}/stderr")
check "a listing it cannot write is exit 2" "$RC" "2"
has   "  naming the failed write on stderr" "$ERR" "to standard output failed"
hasnt "  and never the complete trailer" "$ERR" "plan-archive: complete archive="
new_root r14
awk 'BEGIN { print "# S\n\n## Deferred\n"; for (i = 0; i < 15; i++) print "a line that carries the listing past the cap" }' \
  > "${A}/2026-01-01-z.spec.md"
# A closed descriptor fails the header's write. A 1024-byte cap with SIGXFSZ
# ignored fails a later one with EFBIG, as a full volume does. The cap binds the
# listing's own temporary files too, so the section alone must fit under it.
( ulimit -f 1; trap '' XFSZ; "$LIST" "$R" > "${D}/capped" 2>"${D}/stderr" ); RC=$?
OUT=$(cat "${D}/capped"); ERR=$(cat "${D}/stderr")
check "a write failing after the header is exit 2" "$RC" "2"
has   "  the header got through" "$OUT" "plan-archive: completed plans in ${A}"
has   "  naming the plan whose write failed" "$ERR" "writing plan 2026-01-01-z to standard output failed"
hasnt "  no complete trailer on standard output" "$OUT" "plan-archive: complete archive="
hasnt "  nor on stderr" "$ERR" "plan-archive: complete archive="

new_root r9
printf '# S\n\n**Tracked in:** OK-1\n\n## Deferred\n\nfine\n' > "${A}/2026-08-01-good.spec.md"
printf '# S\n\n**Tracked in:** BAD-1\n\n## Out of scope\n\n````text\n## Deferred\n```\n' > "${A}/2026-08-02-open.spec.md"
printf '# D\n\n**Ticket:** BAD-1\n\n## Use cases\n\n- a case\n' > "${A}/2026-08-02-open.design.md"
run "$R"
check "a fenced block that never closes is exit 2" "$RC" "2"
has   "  everything else is still listed" "$OUT" "fine"
has   "  the trailer counts the unlisted documents" "$OUT" "plan-archive: incomplete archive=${A} plans=2 documents=3 unlisted=1"
opened=$(grep -n '^````text$' "${A}/2026-08-02-open.spec.md" | cut -d: -f1)
has   "  and names the document and why" "$OUT" "plan-archive: unlisted ${A}/2026-08-02-open.spec.md: a fenced block opened at line ${opened} never closes"
has   "  the trailer reaches stderr too" "$ERR" "unlisted ${A}/2026-08-02-open.spec.md"
has   "  its sections read as not listed, never as absent" "$OUT" "--- spec 2026-08-02-open.spec.md: ## Deferred (not listed: a fenced block"
hasnt "  none of them reads as absent" "$OUT" "--- spec 2026-08-02-open.spec.md: ## Deferred (absent)"
has   "  the plan's key falls through to its design" "$OUT" "=== plan 2026-08-02-open
date: 2026-08-02
key: BAD-1"
hasnt "  no complete trailer" "$OUT" "plan-archive: complete archive="

new_root r13
printf '# S\n\n**Tracked in:** OK-2\n' > "${A}/2026-01-01-ok.spec.md"
ln -s "${A}/nowhere.md" "${A}/2026-01-02-lost.spec.md"
run "$R"
check "a plan whose only document is a dangling link is exit 2" "$RC" "2"
has   "  the plan is still counted" "$OUT" "plans=2 documents=2 unlisted=1"
has   "  and the link is named in the trailer" "$OUT" "unlisted ${A}/2026-01-02-lost.spec.md: it is not a regular file"

if [ "$(id -u)" -ne 0 ]; then
  new_root r10
  printf '# S\n\n## Deferred\n\nx\n' > "${A}/2026-09-01-locked.spec.md"
  chmod 000 "${A}/2026-09-01-locked.spec.md"
  run "$R"
  check "an unreadable document is exit 2" "$RC" "2"
  has   "  named in the trailer" "$OUT" "unlisted ${A}/2026-09-01-locked.spec.md: it cannot be read"
  chmod 644 "${A}/2026-09-01-locked.spec.md"
else
  bad "the unreadable-document leg cannot run as root, and a skipped leg is not a pass"
fi

printf '\n== the framing cannot be forged by the content it frames ==\n'
new_root r11
printf '# S\n\n## Out of scope\n\n--- spec 2026-10-01-forge.spec.md: ## Deferred (absent)\n=== plan forged\n\n## Deferred\n\nreal\n' \
  > "${A}/2026-10-01-forge.spec.md"
run "$R"
check "a framing-shaped line inside a section is counted as its text" \
      "$(body_of "$OUT" '--- spec 2026-10-01-forge.spec.md: ## Out of scope')" \
      "## Out of scope

--- spec 2026-10-01-forge.spec.md: ## Deferred (absent)
=== plan forged"
has   "  and the real section that follows is listed" "$OUT" "--- spec 2026-10-01-forge.spec.md: ## Deferred (3 lines follow)"

printf '\n== a heading carried twice prints both, in document order ==\n'
new_root r12
printf '# S\n\n## Deferred\n\none\n\n## Scope\n\n## Deferred\n\ntwo\n' > "${A}/2026-11-01-twice.spec.md"
run "$R"
check "both occurrences are framed" \
      "$(printf '%s\n' "$OUT" | grep -c '^--- spec 2026-11-01-twice.spec.md: ## Deferred (')" "2"
check "  the first before the second" \
      "$(printf '%s\n' "$OUT" | grep -E '^(one|two)$' | tr '\n' ' ')" "one two "

printf '\n== the method inputs: read from beside the script, refused when unusable ==\n'
P2="${D}/plugin2"
mkdir -p "${P2}/scripts" "${P2}/docs"
cp "$LIST" "${P2}/scripts/"
cp "${REPO}/docs/plan-invariants.md" "${P2}/docs/"
runp "${P2}/scripts/plan-archive.sh" "${D}/r1"
check "no fold gate beside the script is exit 2" "$RC" "2"
has   "  naming it" "$ERR" "check-redline.sh cannot be read"
printf '#!/usr/bin/env bash\nOTHER=1\n' > "${P2}/scripts/check-redline.sh"
runp "${P2}/scripts/plan-archive.sh" "${D}/r1"
check "a fold gate with no list of the spec's sections is exit 2" "$RC" "2"
has   "  naming the assignment" "$ERR" "no readable RETAINED assignment"
check "  and listing nothing" "$OUT" ""
cp "${REPO}/scripts/check-redline.sh" "${P2}/scripts/"
sed 's/^| design | `## Use cases` |$/| design | `## Usage` |/' "${REPO}/docs/plan-invariants.md" > "${P2}/docs/plan-invariants.md"
check "the fixture renamed the record's row" "$(grep -c '`## Usage`' "${P2}/docs/plan-invariants.md")" "1"
runp "${P2}/scripts/plan-archive.sh" "${D}/r1"
check "a design section the record does not carry is exit 2" "$RC" "2"
has   "  naming the section and the record" "$ERR" "is not a design element in the record"
rm "${P2}/docs/plan-invariants.md"
runp "${P2}/scripts/plan-archive.sh" "${D}/r1"
check "no principles page is exit 2" "$RC" "2"
printf '# Principles\n\nNo record here.\n' > "${P2}/docs/plan-invariants.md"
runp "${P2}/scripts/plan-archive.sh" "${D}/r1"
check "a principles page with no record is exit 2" "$RC" "2"
has   "  naming the record" "$ERR" "carries no required-element record"

printf '\n== the live archive ==\n'
OUT=$("$LIST" "$REPO" 2>&1); RC=$?
check "the repository's own archive lists completely" "$RC" "0"
stems=$(for f in "${REPO}"/ai-docs/plans/done/*.spec.md "${REPO}"/ai-docs/plans/done/*.design.md; do
          b=${f##*/}; b=${b%.spec.md}; printf '%s\n' "${b%.design.md}"; done | sort -u | awk 'END { print NR }')
has   "  every plan in it, counted independently" "$OUT" "plans=${stems} "

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
