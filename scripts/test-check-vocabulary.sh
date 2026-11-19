#!/usr/bin/env bash
#
# Suite for scripts/check-vocabulary.sh and the glossary reader it shares with the
# hooks. Each leg builds a throwaway git tree with a glossary of invented names,
# stages its files, and asserts the exit status together with the line that says
# why -- an rc alone cannot tell a finding from a could-not-run.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
GATE="${HERE}/check-vocabulary.sh"
READER="${HERE}/../hooks/lib/glossary-names.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in output" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3] in output" ;; *) ok "$1" ;; esac; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM

HEAD='| Canonical name | Other names | What it is | What it does | Defined at |'
glossary() {
  cat <<EOF
# Glossary

## Gadgets

$HEAD
|---|---|---|---|---|
| gadget ledger | "widget ledger", "sprocket-log" | A table of gadgets. | It counts them. | \`docs/guide.md\` § Gadgets |
| tally pass | "frob round" | One counting pass. | It adds the gadgets up. | planned |

## Retired names

| Retired name | What it named |
|---|---|
| frobnicator | The old counter. |
EOF
}

# tree <dir> -- one clean file on every covered surface, plus the glossary, staged.
tree() {
  rm -rf "$1"; mkdir -p "$1/docs" "$1/agents" "$1/hooks/lib" "$1/scripts" "$1/ai-docs/learnings" \
    "$1/templates/project" "$1/.claude-plugin"
  glossary > "$1/docs/glossary.md"
  printf '# Guide\n\n## Gadgets\n\nThe gadget ledger counts gadgets.\n' > "$1/docs/guide.md"
  printf '# Agent\n\nRead the guide.\n' > "$1/agents/a.md"
  printf '#!/usr/bin/env bash\necho "counting gadgets"\n' > "$1/hooks/lib/h.sh"
  printf '#!/usr/bin/env bash\necho "tally done"\n' > "$1/scripts/s.sh"
  printf '# Rules\n' > "$1/AGENTS.md"
  printf '# Context\n' > "$1/ai-docs/context.md"
  printf '# Contract\n' > "$1/ai-docs/learnings/README.md"
  printf '# Template\n' > "$1/templates/project/AGENTS.md"
  printf '# Read me\n' > "$1/README.md"
  printf '{"description": "counts gadgets"}\n' > "$1/.claude-plugin/plugin.json"
  git -C "$1" init -q
  git -C "$1" add -A
}
put() { mkdir -p "$(dirname -- "$1/$2")"; printf '%s\n' "$3" > "$1/$2"; git -C "$1" add -- "$2"; }
run() { OUT=$(bash "$GATE" --root "$1" 2>&1); RC=$?; }

D="$T/t"

printf '\n== clean tree ==\n'
tree "$D"; run "$D"
check "clean tree -> rc 0" "$RC" "0"
has "  verdict line counts names, entries and files" "$OUT" "verdict=clean names=4 entries=2 files=10 findings=0"
has "  the roster names the method surface" "$OUT" "surface method       read (2 files)"
has "  and the user-facing surface" "$OUT" "surface user-facing  read (2 files)"
has "  and says the glossary is excluded" "$OUT" "excluded glossary"
hasnt "  canonical names are not refused" "$OUT" ": listed name"

printf '\n== a listed name is refused on every covered surface ==\n'
for path in "agents/b.md" "skills/x/SKILL.md" "rules/r.md" "hooks/lib/m.sh" "scripts/p.sh" "AGENTS.md" \
            "ai-docs/context.md" "ai-docs/learnings/README.md" "templates/project/notes.md" "README.md"; do
  tree "$D"; put "$D" "$path" "The widget ledger is gone."; run "$D"
  check "[$path] -> rc 1" "$RC" "1"
  has "  named at its file and line" "$OUT" "$path:1: listed name \"widget ledger\" (other name of \"gadget ledger\")"
done
tree "$D"; printf '{"description": "keeps the widget ledger"}\n' > "$D/.claude-plugin/marketplace.json"
git -C "$D" add .claude-plugin/marketplace.json; run "$D"
check "the installed description -> rc 1" "$RC" "1"
tree "$D"; put "$D" "hooks/lib/m.sh" "printf 'the frobnicator ran\\n'"; run "$D"
check "a retired name in a printed message -> rc 1" "$RC" "1"
has "  reported as retired" "$OUT" "listed name \"frobnicator\" (retired name)"

printf '\n== forms of a listed name ==\n'
for text in "Two widget-ledgers." "THE WIDGET LEDGER" "the sprocket log" "the widget
ledger" "> a widget
> ledger" "two frob rounds" "three frobnicators" "\`widget ledger\`" "\"frob round\""; do
  tree "$D"; put "$D" "docs/n.md" "$text"; run "$D"
  check "[$text] -> rc 1" "$RC" "1"
done
for text in "widget_ledger" "awidget ledger" "the widget ledgerx" "a frob roundabout"; do
  tree "$D"; put "$D" "docs/n.md" "$text"; run "$D"
  check "[$text] is not the name -> rc 0" "$RC" "0"
done

printf '\n== what is not read ==\n'
tree "$D"
for p in ai-docs/plans/x.spec.md ai-docs/plans/done/y.design.md ai-docs/learnings/someone-branch.md \
         ai-docs/fixtures/f.txt .claude/settings.json src/x.md; do
  put "$D" "$p" "the widget ledger"
done
glossary > "$D/docs/glossary.md"; printf 'the widget ledger is listed here\n' >> "$D/docs/glossary.md"
git -C "$D" add docs/glossary.md; run "$D"
check "plans, log entries, fixtures, other paths and the glossary itself -> rc 0" "$RC" "0"
tree "$D"; printf 'the widget ledger\n' > "$D/docs/new.md"; run "$D"
check "an untracked, unignored covered file is read -> rc 1" "$RC" "1"
tree "$D"; printf 'docs/new.md\n' > "$D/.gitignore"; printf 'the widget ledger\n' > "$D/docs/new.md"; run "$D"
check "an ignored file is not read -> rc 0" "$RC" "0"
tree "$D"; printf 'the widget ledger\0binary' > "$D/docs/blob.md"; git -C "$D" add docs/blob.md; run "$D"
check "a binary file is skipped -> rc 0" "$RC" "0"

printf '\n== a script keeps the names it gives itself ==\n'
tree "$D"; put "$D" "scripts/v.sh" 'frobnicator=1; echo "$frobnicator ${frobnicator}"
frob-round() { :; }
local frobnicator=2'
run "$D"
check "shell variable and function names -> rc 0" "$RC" "0"
tree "$D"; put "$D" "scripts/v.sh" 'frobnicator=1; echo "the frobnicator is $frobnicator"'; run "$D"
check "the same word in the printed text -> rc 1" "$RC" "1"
has "  found once, in the message" "$OUT" "findings=1"
tree "$D"; put "$D" "scripts/v.py" 'frobnicator = 1
def frob_round(frobnicator):
    return frobnicator.frobnicator'
run "$D"
check "python identifiers -> rc 0" "$RC" "0"
tree "$D"; put "$D" "scripts/v.py" 'x = "the frobnicator"  # a frob round'; run "$D"
check "python string and comment -> rc 1" "$RC" "1"
has "  both found" "$OUT" "findings=2"
tree "$D"; put "$D" "scripts/v.awk" 'function frobnicator(x) { return x }'; run "$D"
check "an awk function name -> rc 0" "$RC" "0"
tree "$D"; put "$D" "scripts/v.sh" '# [frobnicator] the id a document cites'; put "$D" "docs/d.md" 'Cites [frobnicator].'
run "$D"
check "bracketed ids, on both sides -> rc 0" "$RC" "0"
tree "$D"; put "$D" "docs/d.md" 'See [frobnicator](x.md).'; run "$D"
check "a markdown link text is not an id -> rc 1" "$RC" "1"

printf '\n== the internals mark ==\n'
tree "$D"; put "$D" "scripts/v.sh" 'grep -q "frobnicator" "$f"  # vocabulary-internal: older files carry it'; run "$D"
check "a marked line -> rc 0" "$RC" "0"
tree "$D"; put "$D" "scripts/v.sh" '# vocabulary-internal: a planted copy of older text
printf "the widget ledger\n"
printf "the frobnicator\n"

echo "the frobnicator"'
run "$D"
check "a mark alone on its line covers to the blank line, not past it -> rc 1" "$RC" "1"
has "  only the line after the blank is found" "$OUT" "scripts/v.sh:5:"
has "  once" "$OUT" "findings=1"
tree "$D"; put "$D" "scripts/v.sh" 'echo frobnicator  # vocabulary-internal:'; run "$D"
check "a mark giving no reason -> rc 1" "$RC" "1"
has "  says so" "$OUT" "internals mark gives no reason"
tree "$D"; put "$D" "docs/d.md" 'The frobnicator.  # vocabulary-internal: prose may not hide a name'; run "$D"
check "a mark in prose does nothing -> rc 1" "$RC" "1"

printf '\n== the glossary holds together ==\n'
bad_row() {
  tree "$D"
  awk -v row="$1" '{ print } /^\|---\|---\|---\|---\|---\|$/ { print row }' "$D/docs/glossary.md" > "$D/g"
  mv "$D/g" "$D/docs/glossary.md"; git -C "$D" add docs/glossary.md; run "$D"
}
bad_row '| gadget ledger | — | Again. | Again. | planned |'
check "a canonical name twice -> rc 1" "$RC" "1"
has "  named as a collision" "$OUT" "name collision: \"gadget ledger\""
bad_row '| doohickey | "widget ledger" | One. | Two. | planned |'
check "an other name in two entries -> rc 1" "$RC" "1"
has "  both owners named" "$OUT" "an other name of \"doohickey\""
bad_row '| frobnicator | — | One. | Two. | planned |'
check "a retired name made canonical -> rc 1" "$RC" "1"
bad_row '| doohickey | "Tally-Pass" | One. | Two. | planned |'
check "a canonical name, spelled otherwise, as another's other name -> rc 1" "$RC" "1"
bad_row '| doohickey | — | One. | Two. | `docs/missing.md` § Gadgets |'
check "defined at a missing page -> rc 1" "$RC" "1"
has "  says the page does not exist" "$OUT" "docs/missing.md, which does not exist"
bad_row '| doohickey | — | One. | Two. | `docs/guide.md` § Doohickeys |'
check "defined at a missing heading -> rc 1" "$RC" "1"
has "  says the heading is missing" "$OUT" "section \"Doohickeys\", which it does not have"

printf '\n== could not run is not a pass ==\n'
bad_row '| doohickey | — | One. | planned |'
check "an entry with four cells -> rc 2" "$RC" "2"
has "  the reader names the line" "$OUT" "an entry row needs exactly five cells"
has "  and the verdict says so" "$OUT" "verdict=cannot-run"
bad_row '| doohickey | widget, sprocket | One. | Two. | planned |'
check "unquoted other names -> rc 2" "$RC" "2"
bad_row '| doohickey | — | One. | Two. | docs/guide.md |'
check "a defined-at in no known form -> rc 2" "$RC" "2"
tree "$D"; git -C "$D" rm -qf docs/glossary.md; run "$D"
check "no glossary -> rc 2" "$RC" "2"
tree "$D"; printf '# Glossary\n\nNo tables.\n' > "$D/docs/glossary.md"; git -C "$D" add docs/glossary.md; run "$D"
check "a glossary yielding no names -> rc 2" "$RC" "2"
tree "$D"; put "$D" "scripts/v.py" 'x = """unterminated'; run "$D"
check "a python file the tokenizer refuses -> rc 2" "$RC" "2"
has "  and names it" "$OUT" "scripts/v.py"
mkdir -p "$T/plain"; run "$T/plain"
check "not a git tree -> rc 2" "$RC" "2"
OUT=$(bash "$GATE" --bogus 2>&1); RC=$?
check "unknown flag -> rc 2" "$RC" "2"
tree "$D"; sed "s/^import /raise SystemExit(1)  # import /" "$GATE" > "$T/crash.sh"
cmp -s "$GATE" "$T/crash.sh" && bad "the crash mutant did not apply"
OUT=$(bash "$T/crash.sh" --root "$D" 2>&1); RC=$?
check "a body that ends without a verdict -> rc 2, not findings" "$RC" "2"

printf '\n== the reader ==\n'
tree "$D"
OUT=$(bash "$READER" "$D/docs/glossary.md" 2>&1); RC=$?
check "a well-formed page -> rc 0" "$RC" "0"
has "  a canonical row" "$OUT" "canonical	gadget ledger	gadget ledger	"
has "  an other row, with its owner" "$OUT" "other	sprocket-log	gadget ledger	"
has "  a retired row" "$OUT" "retired	frobnicator	-	"
has "  a defined-at row, page and heading apart" "$OUT" "	docs/guide.md	7	Gadgets"
has "  a planned row" "$OUT" "planned	tally pass	-	"
bad_row '| doohickey | "x" "y" | One. | Two. | planned |'
OUT=$(bash "$READER" "$D/docs/glossary.md" 2>/dev/null); RC=$?
check "a malformed page -> rc 2" "$RC" "2"
check "  with nothing on stdout, never a partial list" "$OUT" ""

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
