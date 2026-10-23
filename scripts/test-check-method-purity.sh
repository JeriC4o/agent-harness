#!/usr/bin/env bash
#
# Suite for scripts/check-method-purity.sh. Each leg builds a throwaway git tree,
# stages its files (the gate reads the index, not the disk) and asserts the exit
# status together with the line that proves WHY -- an rc alone cannot tell a
# finding from a cannot-run.

set -uo pipefail

GATE="$(cd -- "$(dirname -- "$0")" && pwd)/check-method-purity.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in output" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3] in output" ;; *) ok "$1" ;; esac; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM

# tree <dir> -- a minimal tree with one clean method file, staged.
tree() {
  rm -rf "$1"; mkdir -p "$1/agents" "$1/ai-docs" "$1/scripts"
  printf '# Agent\n\nRead the profile, then run `jq` and `python3` as the gate needs.\n' > "$1/agents/a.md"
  git -C "$1" init -q
  git -C "$1" add -A
}
put() { mkdir -p "$(dirname -- "$1/$2")"; printf '%s\n' "$3" > "$1/$2"; git -C "$1" add -- "$2"; }
run() { OUT=$(METHOD_PURITY_EXTRA_STEMS="${STEMS:-}" bash "$GATE" --root "$1" 2>&1); RC=$?; }

D="$T/t"

printf '\n== clean tree ==\n'
tree "$D"; run "$D"
check "clean tree -> rc 0" "$RC" "0"
has "  verdict line says clean and counts the method file" "$OUT" "verdict=clean method_files=1"
hasnt "  the harness's own tools are not stack names" "$OUT" "stack name"

printf '\n== stack leg: each class fires in a method file ==\n'
for row in "stack name|Prefer the Kotlin idiom here." \
           "stack name|Run gradle before the commit." \
           "language syntax|Methods inside \`override fun\` are exempt." \
           "language syntax|A \`@Suppress\` without a reason." \
           "language syntax|Throws \`IllegalStateException\` on misuse." \
           "language syntax|A public function calling \`require(…)\` documents it." \
           "stack name|Written in Python." \
           "stack name|Tests run under JUnit5." \
           "stack name|Build it with npm first." \
           "stack name|A C# project." \
           "source path|The entry point is main.py." \
           "source path|See src/app/OrderRepo.kt for it." \
           "source path|Every *.kt file is a module." \
           "source path|The idiom lives in OrderRepo.java already."; do
  label=${row%%|*}; text=${row#*|}
  tree "$D"; put "$D" "skills/s/SKILL.md" "$text"; run "$D"
  check "[$text] -> rc 1" "$RC" "1"
  has "  reported as $label at its line" "$OUT" "skills/s/SKILL.md:1: $label"
done

printf '\n== stack leg: scope is the method surface only ==\n'
tree "$D"; put "$D" "ai-docs/context.md" "Primary language: Kotlin, built with gradle."
put "$D" "templates/project/notes.md" "Kotlin"; put "$D" "docs/notes.txt" "Kotlin"
run "$D"
check "a stack name in profile data, a template or a non-md doc -> rc 0" "$RC" "0"
tree "$D"; put "$D" "scripts/own.py" "pass"
put "$D" "rules/r.md" "guard rails, a rusty bolt, a swift fix in the spring, rust-free; python3 runs own.py"
run "$D"
check "ordinary words, and a path to one of the tree's own files -> rc 0" "$RC" "0"

printf '\n== foreign leg: every tracked text file, substring of a token ==\n'
tree "$D"; put "$D" "ai-docs/plan.md" "Idiom at SprocketWheelDao and nowhere else."
put "$D" "scripts/x.sh" "echo sprocketwheel"
STEMS="SprocketWheel" run "$D"
check "a configured stem inside a longer token -> rc 1" "$RC" "1"
has "  found in profile data" "$OUT" "ai-docs/plan.md:1: foreign identifier: SprocketWheelDao"
has "  found in a script, case-insensitively" "$OUT" "scripts/x.sh:1: foreign identifier: sprocketwheel"
has "  counted on the verdict line" "$OUT" "foreign_hits=2"
STEMS="" run "$D"
check "same tree without the stem -> rc 0" "$RC" "0"

n=$(grep -oE '\([0-9]+, "[0-9a-f]{16}"\)' "$GATE" | wc -l | tr -d ' ')
check "the built-in stem list is non-empty and hashed (4 entries)" "$n" "4"
if grep -qiE 'stems? *= *\[?["'"'"'][a-z]{5,}' "$GATE"; then
  bad "a stem is spelled out in the gate"
else
  ok "no stem is spelled out in the gate"
fi

printf '\n== what is not read ==\n'
tree "$D"; printf 'Kotlin\0binary' > "$D/agents/blob.md"; git -C "$D" add agents/blob.md; run "$D"
check "a binary file is skipped -> rc 0" "$RC" "0"
tree "$D"; printf 'Kotlin\n' > "$D/agents/new.md"; run "$D"
check "an untracked, unignored method file is read -> rc 1" "$RC" "1"
tree "$D"; printf 'new.md\n' > "$D/.gitignore"; printf 'Kotlin\n' > "$D/agents/new.md"; run "$D"
check "an ignored file is not read -> rc 0" "$RC" "0"
tree "$D"; put "$D" "skills/s/SKILL.md" "See OrderRepo.kt."; printf 'x\n' > "$D/OrderRepo.kt"; run "$D"
check "an UNTRACKED file does not exempt a path naming it -> rc 1" "$RC" "1"
tree "$D"; sed "s/^import hashlib/import hashlib; raise SystemExit(1)  #/" "$GATE" > "$T/crash.sh"
OUT=$(bash "$T/crash.sh" --root "$D" 2>&1); RC=$?
check "a body that ends without a verdict -> rc 2, not findings" "$RC" "2"

printf '\n== cannot run is not a pass ==\n'
tree "$D"; git -C "$D" rm -qf agents/a.md; run "$D"
check "no method file tracked -> rc 2" "$RC" "2"
has "  and says so" "$OUT" "verdict=cannot-run"
mkdir -p "$T/plain"; run "$T/plain"
check "not a git tree -> rc 2" "$RC" "2"
OUT=$(bash "$GATE" --bogus 2>&1); RC=$?
check "unknown flag -> rc 2" "$RC" "2"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
