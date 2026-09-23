#!/usr/bin/env bash
#
# Tests for the /improve FOLD — the shell block in skills/improve/SKILL.md that
# collapses merged per-branch learning files back into ai-docs/learnings.md.
#
# Run: bash scripts/test-fold.sh
#
# WHY THIS EXISTS. The fold had no gate of any kind, while its own commentary
# reasoned at length about what "a gate that exercises only a working
# derive_name" would and would not catch. That gap shipped a real defect:
# `git ls-tree -r` recurses, the keeper guard matched a literal path, and so
# every file under ai-docs/learnings/.promote/ -- promotion candidates, the
# directory contract, deny-extra.txt -- was appended into the append-only
# archive and deleted from the tree. Silently: the fold reported success.
#
# The archive is the ONE file /harness:improve-global is guaranteed never to
# open, so a candidate that lands there cannot be recovered by the sweep it was
# written for. Three correct guarantees composed into permanent loss.
#
# THE BLOCK IS EXTRACTED FROM SKILL.md, NOT COPIED HERE. A second copy of the
# algorithm would drift, and a gate that tests the copy proves nothing about
# what ships.
#
# Every guard gets a POSITIVE CONTROL: the suite re-runs the block with that
# guard deleted and requires the damage to reappear. Without the control a guard
# can be "simplified away" and the fixture still passes byte-identically -- the
# exact failure mode that let the nesting bug through.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
SKILL="${ROOT}/skills/improve/SKILL.md"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { if grep -q -- "$3" "$2"; then ok "$1"; else bad "$1 (missing [$3] in $2)"; fi; }
hasnt(){ if grep -q -- "$3" "$2"; then bad "$1 (unexpected [$3] in $2)"; else ok "$1"; fi; }
exists(){ if [ -e "$2" ]; then ok "$1"; else bad "$1 ($2 is gone)"; fi; }
gone() { if [ -e "$2" ]; then bad "$1 ($2 survives)"; else ok "$1"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

# ---- extract the shipped block -----------------------------------------------
# The fenced ```sh block that carries the ls-tree loop. Anchored on the loop
# itself rather than on "the first sh block", so reordering the file cannot
# silently hand the suite some other snippet.
BLOCK="${TMP}/fold.sh"
awk '
  /^```sh$/          { inb=1; buf=""; next }
  inb && /^```$/     { if (buf ~ /git ls-tree -r --name-only/) { printf "%s", buf; exit 0 }
                       inb=0; next }
  inb                { buf = buf $0 "\n" }
' "$SKILL" > "$BLOCK"

printf '\n== the block under test was actually found ==\n'
if [ -s "$BLOCK" ]; then ok "extracted the fold block from skills/improve/SKILL.md"
else bad "extracted the fold block -- no fenced sh block contains the ls-tree loop"; printf '\n0 passed, 1 failed\n'; exit 1; fi
if grep -q 'cat "\$f" >> "\$ARCHIVE"' "$BLOCK"; then ok "  it is the block that appends to the archive"
else bad "  it is the block that appends to the archive"; fi

# ---- fixture -----------------------------------------------------------------
# An upstream repo holding the merged state, cloned to a working copy -- so
# `origin/HEAD`, `git ls-tree origin/main` and `git show origin/main:<f>` are all
# real rather than simulated.
#
# The archive and the FIRST merged file both end WITHOUT a newline: that is the
# seam N1 and N2 exist for, and it is invisible to any byte comparison of the
# appended chunk.
make_fixture() { # -> path to the working copy
  d=$(mktemp -d)
  up="$d/upstream"; work="$d/work"
  mkdir -p "$up/ai-docs/learnings/.promote"
  git -C "$up" init -q -b main
  git -C "$up" config user.email t@t; git -C "$up" config user.name t

  printf '# Archive\n\n### 2026-01-01 — process — first entry'     > "$up/ai-docs/learnings.md"
  printf 'keeper\n'                                                > "$up/ai-docs/learnings/README.md"
  printf 'promote-readme-marker\n'                                 > "$up/ai-docs/learnings/.promote/README.md"
  printf -- '---\nid: candidate-marker\n---\n\n**Rule:** A gate that cannot fail is not a gate.\n' \
                                                                   > "$up/ai-docs/learnings/.promote/candidate-marker.md"
  printf 'denyextra-marker\n'                                      > "$up/ai-docs/learnings/.promote/deny-extra.txt"
  printf '### 2026-02-01 — process — merged-a-marker'              > "$up/ai-docs/learnings/alice-merged-a.md"
  printf '### 2026-02-02 — process — merged-b-marker\n'            > "$up/ai-docs/learnings/alice-merged-b.md"
  printf '### 2026-02-03 — process — open-marker\n'                > "$up/ai-docs/learnings/alice-open.md"
  printf '### 2026-02-04 — process — self-marker\n'                > "$up/ai-docs/learnings/alice-self.md"

  git -C "$up" add -A >/dev/null 2>&1
  git -C "$up" commit -qm seed >/dev/null 2>&1
  git clone -q "$up" "$work" >/dev/null 2>&1
  git -C "$work" config user.email t@t; git -C "$work" config user.name t

  # A still-open branch appended locally: differs from main, must be skipped.
  printf '### 2026-02-05 — process — open-local-marker\n' >> "$work/ai-docs/learnings/alice-open.md"

  printf '%s' "$work"
}

# Compose <derive_name stub> + <block> into a runnable script and execute it in
# the working copy. Written to a file rather than piped: the block contains a
# `cmp -s -` whose stdin must stay the pipe it is given.
# Sets OUT and RC in the CALLER's shell, so it must never be invoked inside a
# command substitution -- that is a subshell and the exit status would be lost.
run_fold() { # <workdir> <stub-source> <block-file> -> sets OUT, RC
  runner="${TMP}/run.$$.sh"
  { printf '%s\n' "$2"; cat "$3"; } > "$runner"
  OUT=$(cd "$1" && sh "$runner" 2>&1); RC=$?
}

STUB_OK='derive_name() { printf "alice-self.md"; }'

# A control that deletes nothing is not a control. Every stripped variant must
# differ from the shipped block, or the "damage reappears" leg is vacuous.
# Sets STRIPPED rather than printing it: `bad` mutates the pass/fail counters, so
# calling it inside a command substitution would both lose the count and splice
# the failure text into the path.
strip() { # <grep -v pattern> <label> -> sets STRIPPED
  STRIPPED="${TMP}/stripped.$2.sh"
  grep -v -- "$1" "$BLOCK" > "$STRIPPED"
  if cmp -s "$BLOCK" "$STRIPPED"; then bad "positive control [$2] removes a line (pattern matched nothing)"; fi
}

# ================================================================= happy path ==
printf '\n== the fold folds what is merged, and only what is merged ==\n'
W=$(make_fixture)
run_fold "$W" "$STUB_OK" "$BLOCK"
check "exits 0" "$RC" "0"
A="$W/ai-docs/learnings.md"
has   "archive gains the first merged entry"  "$A" "merged-a-marker"
has   "archive gains the second"              "$A" "merged-b-marker"
gone  "folded source a is deleted"            "$W/ai-docs/learnings/alice-merged-a.md"
gone  "folded source b is deleted"            "$W/ai-docs/learnings/alice-merged-b.md"

printf '\n== a locally-diverged file, the self file and the keeper are left alone ==\n'
hasnt  "open branch is not folded"            "$A" "open-local-marker"
exists "  its file survives"                  "$W/ai-docs/learnings/alice-open.md"
hasnt  "self file is not folded"              "$A" "self-marker"
exists "  its file survives"                  "$W/ai-docs/learnings/alice-self.md"
hasnt  "keeper README is not folded"          "$A" "keeper"
exists "  it survives"                        "$W/ai-docs/learnings/README.md"

# ================================================== the nesting guard (G1a) ====
# The defect this suite was written for. `git ls-tree -r` recurses; a guard that
# names one literal path cannot cover a subdirectory.
printf '\n== nothing under .promote/ is ever a fold candidate ==\n'
hasnt  "the .promote contract is not folded"  "$A" "promote-readme-marker"
hasnt  "a promotion candidate is not folded"  "$A" "candidate-marker"
hasnt  "deny-extra.txt is not folded"         "$A" "denyextra-marker"
exists "candidate file survives on disk"      "$W/ai-docs/learnings/.promote/candidate-marker.md"
exists "  .promote/README.md survives"        "$W/ai-docs/learnings/.promote/README.md"
exists "  deny-extra.txt survives"            "$W/ai-docs/learnings/.promote/deny-extra.txt"
tracked=$(git -C "$W" ls-files ai-docs/learnings/.promote | wc -l | tr -d ' ')
check  "all three stay tracked (not git rm-ed)" "$tracked" "3"

printf '\n== POSITIVE CONTROL: delete the nesting guard, the loss returns ==\n'
strip 'ai-docs/learnings/\*/\*' nested; V="$STRIPPED"
W2=$(make_fixture)
run_fold "$W2" "$STUB_OK" "$V"
A2="$W2/ai-docs/learnings.md"
has  "without it, a candidate lands in the archive" "$A2" "candidate-marker"
gone "without it, the candidate file is deleted"    "$W2/ai-docs/learnings/.promote/candidate-marker.md"

# ============================================== the newline seam (N1 and N2) ===
# Three entries were archived (one pre-existing + two folded). A missing
# normalization glues a `### ` header onto the previous line, where it stops
# being a header -- so the count, not a byte comparison, is what can see it.
printf '\n== the trailing-newline normalization keeps entry headers intact ==\n'
n=$(grep -c '^### ' "$A")
check "three entry headers survive the fold" "$n" "3"
if [ "$(tail -c 1 "$A" | wc -l)" -eq 1 ]; then ok "archive ends with a newline"
else bad "archive ends with a newline"; fi

printf '\n== POSITIVE CONTROL: delete N1 (above the loop), headers are lost ==\n'
strip 'N1 — ONCE' n1; V="$STRIPPED"
W3=$(make_fixture)
run_fold "$W3" "$STUB_OK" "$V"
n=$(grep -c '^### ' "$W3/ai-docs/learnings.md")
if [ "$n" -lt 3 ]; then ok "without N1 an entry header is swallowed (got $n of 3)"
else bad "without N1 an entry header is swallowed (still $n)"; fi

printf '\n== POSITIVE CONTROL: delete N2 (inside the loop), headers are lost ==\n'
strip 'N2 — after EVERY append' n2; V="$STRIPPED"
W4=$(make_fixture)
run_fold "$W4" "$STUB_OK" "$V"
n=$(grep -c '^### ' "$W4/ai-docs/learnings.md")
if [ "$n" -lt 3 ]; then ok "without N2 an entry header is swallowed (got $n of 3)"
else bad "without N2 an entry header is swallowed (still $n)"; fi

# ================================================== the derive_name guards =====
# Five stubs, because four cannot tell `|| abort` from dead code: the shape that
# uniquely needs it is NON-ZERO RC *WITH* OUTPUT, where `[ -n "$name" ]` passes
# and a plausible-but-wrong $self disables the skip-self guard.
printf '\n== a failed name derivation aborts before touching anything ==\n'
pristine="${TMP}/pristine.md"
W5=$(make_fixture); cp "$W5/ai-docs/learnings.md" "$pristine"

abort_case() { # <label> <stub-source>
  w=$(make_fixture)
  run_fold "$w" "$2" "$BLOCK"
  check  "$1: exits 1" "$RC" "1"
  if cmp -s "$w/ai-docs/learnings.md" "$pristine"; then ok "$1: archive untouched"
  else bad "$1: archive untouched"; fi
  exists "$1: the self file survives" "$w/ai-docs/learnings/alice-self.md"
}
abort_case "empty output, rc 0"   'derive_name() { printf ""; }'
abort_case "rc 7, no output"      'derive_name() { return 7; }'
abort_case "rc 3, WITH output"    'derive_name() { printf "alice-se"; return 3; }'
abort_case "undefined"            '# derive_name is deliberately not defined'

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
