#!/usr/bin/env bash

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- unexpected [$3]" ;; *) ok "$1" ;; esac; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

command -v python3 >/dev/null 2>&1 || { printf 'cannot run: python3 absent\n' >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'cannot run: git absent\n' >&2; exit 2; }

T=$(mktemp -d); X=$(mktemp -d); trap 'rm -rf "$T" "$X"' EXIT INT TERM
mkdir -p "$T/scripts" "$T/plans"
cp "${HERE}/check-plan-links.sh" "${HERE}/check-plan-links.py" \
   "${HERE}/check-plan-convergence-holding.py" "${HERE}/check-redline.sh" "$T/scripts/"
git -C "$T" init -q
git -C "$T" add -A >/dev/null 2>&1
SUB="$T/scripts/check-plan-links.sh"
SPEC="$T/plans/a.spec.md"
DESIGN="$T/plans/a.design.md"
REC="$T/plans/a.links.md"

run() { bash "$SUB" "$SPEC" "$DESIGN" 2>&1; }

HEADER='| Id | End A | Quote A | End B | Quote B | Grounds |
|---|---|---|---|---|---|'
unstage() { git -C "$T" rm -q --cached --ignore-unmatch plans/a.links.md >/dev/null 2>&1; }
record() { # <rows>
  printf '# Declared links: a\n\n%s\n%s\n' "$HEADER" "$1" > "$REC"
  git -C "$T" add plans/a.links.md >/dev/null 2>&1
}
no_record() { unstage; rm -f "$REC"; }

SPEC_TEXT='# Spec

## Width

The window is forty rounds wide.

## Counting

Every run reports its count.'
DESIGN_TEXT='# Design

## Ledger

The ledger keeps a window forty rounds wide.

## Notes

A count is printed beside the verdict.'
pair() { printf '%s\n' "${1:-$SPEC_TEXT}" > "$SPEC"; printf '%s\n' "${2:-$DESIGN_TEXT}" > "$DESIGN"; }

L1='| L1 | spec § Width | The window is forty rounds wide. | design § Ledger | a window forty rounds wide | the design restates the width the spec sets |'
L2='| L2 | design § Ledger | The ledger keeps | design § Notes | A count is printed beside the verdict. | two statements of one document |'

printf '\n== the three outcomes ==\n'
pair; record "$L1
$L2"
out=$(run); rc=$?
check "every link silent -> rc 0" "$rc" "0"
has "  and the verdict says clean" "$out" 'check-plan-links: clean'
has "  and names the record" "$out" "record=${REC}"
has "  and counts links per state" "$out" 'links=2 silent=2 moved=0 re-confirm=0 ambiguous=0 skipped=0'
hasnt "  and a silent row prints nothing" "$out" 'L1'
record ''
out=$(run); rc=$?
check "a record with no row -> rc 0" "$rc" "0"
has "  and reads as a declared pair with no links" "$out" 'links=0'
out1=$(run); out2=$(run)
check "the same input gives the same result" "$out1" "$out2"

printf '\n== a moved link, in both directions ==\n'
pair "${SPEC_TEXT/forty/fifty}"; record "$L1"
out=$(run); rc=$?
check "a changed spec end -> rc 1" "$rc" "1"
has "  and the report names the spec end as changed and the design end as not re-confirmed" "$out" \
  'moved L1 -- end A (spec) changed; end B (design) was not re-confirmed'
has "  and names the changed end's recorded heading, found nowhere" "$out" 'end A: spec § Width, recorded there; found nowhere'
has "  and the headings the unchanged end was found under" "$out" 'end B: design § Ledger, recorded there; found under § Ledger'
has "  and counts it" "$out" 'moved=1'
pair "" "${DESIGN_TEXT/forty/fifty}"
out=$(run); rc=$?
check "a changed design end -> rc 1" "$rc" "1"
has "  and the report names the design end as changed and the spec end as not re-confirmed" "$out" \
  'moved L1 -- end B (design) changed; end A (spec) was not re-confirmed'

printf '\n== re-confirm and ambiguous ==\n'
pair "${SPEC_TEXT/forty/fifty}" "${DESIGN_TEXT/forty/fifty}"
out=$(run); rc=$?
check "both ends found nowhere -> rc 1" "$rc" "1"
has "  and the row is reported for re-confirmation" "$out" 're-confirm L1'
has "  and counted" "$out" 're-confirm=1'
pair "" "$DESIGN_TEXT

The archive keeps a window forty rounds wide too."
out=$(run); rc=$?
check "a quote found twice -> rc 1" "$rc" "1"
has "  and the row is ambiguous" "$out" 'ambiguous L1'
has "  and the report says how often and where" "$out" 'found 2 times, under § Ledger, § Notes'
pair "${SPEC_TEXT/forty/fifty}" "$DESIGN_TEXT

The archive keeps a window forty rounds wide too."
out=$(run)
has "ambiguous takes precedence over moved" "$out" 'ambiguous L1'
hasnt "  so the row is not also reported moved" "$out" 'moved L1'

printf '\n== normalisation: a re-wrap, emphasis or a marker never moves a link ==\n'
pair "" '# Design

## Ledger

The ledger keeps a window
forty rounds wide.

## Notes

A count is printed beside the verdict.'
record "$L1
$L2"
out=$(run); rc=$?
check "a re-wrapped quote is still found" "$rc" "0"
pair "" "${DESIGN_TEXT/forty rounds/**forty** rounds}"
out=$(run); rc=$?
check "a change of emphasis is still found" "$rc" "0"
pair "" "${DESIGN_TEXT/window forty/window forty **[REDLINE S8.1]**}"
out=$(run); rc=$?
check "a redline marker inside the quoted words is still found" "$rc" "0"
pair "" "$DESIGN_TEXT

The cap | floor pair holds."
record '| L1 | design § Ledger | The ledger keeps | design § Notes | The cap \| floor pair | an escaped pipe |'
out=$(run); rc=$?
check "an escaped pipe in a quote matches a literal one" "$rc" "0"
pair "" "$DESIGN_TEXT

| Bound | Value |
|---|---|
| The cap \| floor pair | two |"
out=$(run); rc=$?
check "  and an escaped one in a document's table cell" "$rc" "0"

printf '\n== sections: a fenced heading is not one, a blockquoted heading is ==\n'
record "$L1"
pair "${SPEC_TEXT/forty/fifty}" '# Design

## Ledger

```
## Fenced
```

The ledger keeps a window forty rounds wide.'
out=$(run)
has "a heading inside a fence does not start a section" "$out" 'found under § Ledger'
hasnt "  so the fenced line is never reported as one" "$out" '§ Fenced'
pair "${SPEC_TEXT/forty/fifty}" '# Design

> ## Quoted
>
> The ledger keeps a window forty
> rounds wide.'
out=$(run)
has "a heading through a blockquote marker starts a section, and the quote spans the marked lines" "$out" \
  'found under § Quoted'

printf '\n== could-not-run, never clean ==\n'
pair; no_record
out=$(run); rc=$?
check "an absent record -> rc 2" "$rc" "2"
has "  and says it is not a pass" "$out" 'CANNOT RUN'
has "  and names the record it looked for" "$out" "$REC"
record "$L1"; unstage
out=$(run); rc=$?
check "a record not in the index -> rc 2" "$rc" "2"
has "  and names it" "$out" "${REC} exists and is not in the index"
printf '# Declared links: a\n\nNo table.\n' > "$REC"; git -C "$T" add plans/a.links.md >/dev/null 2>&1
out=$(run); rc=$?
check "a record with no table header -> rc 2" "$rc" "2"
has "  and names the record" "$out" "$REC"
record '| L1 | spec § Width | The window is forty rounds wide. | design § Ledger |  | the grounds |'
out=$(run); rc=$?
check "a row with an empty cell -> rc 2" "$rc" "2"
has "  and names the row" "$out" 'row L1'
record '| L1 | spec § Width | The window is forty rounds wide. | design § Ledger | a window |'
out=$(run); rc=$?
check "a row with the wrong number of cells -> rc 2" "$rc" "2"
has "  and says so" "$out" 'cells'
record '| L1 | ticket § Width | The window is forty rounds wide. | design § Ledger | a window | the grounds |'
out=$(run); rc=$?
check "an end naming neither the spec nor the design -> rc 2" "$rc" "2"
has "  and names the row" "$out" 'row L1'
record '| L1 | spec § Width | ** | design § Ledger | a window | the grounds |'
out=$(run); rc=$?
check "a quote that normalises to nothing -> rc 2" "$rc" "2"
has "  and names the row" "$out" 'row L1'
record "$L1"
bash "$SUB" "$SPEC" >/dev/null 2>&1
check "one path only -> rc 2" "$?" "2"
cp "$SPEC" "$T/plans/a.md"
bash "$SUB" "$T/plans/a.md" "$DESIGN" >/dev/null 2>&1
check "a spec whose name gives no record path -> rc 2" "$?" "2"
cp "$SPEC" "$X/b.spec.md"; cp "$DESIGN" "$X/b.design.md"
out=$(bash "$SUB" "$X/b.spec.md" "$X/b.design.md" 2>&1); rc=$?
check "a spec outside a git work tree -> rc 2" "$rc" "2"
for payload in check-plan-links.py check-plan-convergence-holding.py; do
  mv "$T/scripts/${payload}" "$T/scripts/hidden.py"
  out=$(run); rc=$?
  check "an absent ${payload} -> rc 2, never rc 1" "$rc" "2"
  has "  and the message names it" "$out" "$payload"
  mv "$T/scripts/hidden.py" "$T/scripts/${payload}"
done
cp "$T/scripts/check-plan-convergence-holding.py" "$X/holding.py"
printf 'def broken(:\n' >> "$T/scripts/check-plan-convergence-holding.py"
out=$(run); rc=$?
check "an unparseable holding sibling -> rc 2, never rc 1" "$rc" "2"
has "  and the message names it" "$out" 'check-plan-convergence-holding.py could not be loaded'
cp "$X/holding.py" "$T/scripts/check-plan-convergence-holding.py"
mv "$T/scripts/check-redline.sh" "$T/scripts/gone-redline.sh"
out=$(run); rc=$?
check "an unreadable source for the kept sections -> rc 2" "$rc" "2"
has "  and says they are borrowed" "$out" 'borrowed'
mv "$T/scripts/gone-redline.sh" "$T/scripts/check-redline.sh"

printf '\n== a folded spec is skipped, never clean ==\n'
KEPT=$(sed -n "/^RETAINED='/,/'\$/p" "$T/scripts/check-redline.sh" | sed "s/^RETAINED='//; s/'\$//")
[ "$(printf '%s\n' "$KEPT" | grep -c .)" -ge 2 ] \
  && ok "the kept sections were derived from the fold's gate" \
  || bad "the kept sections were derived from the fold's gate"
FOLDED=$(printf '%s\n' "$KEPT" | while IFS= read -r h; do printf '%s\n\n- Kept.\n\n' "$h"; done)
pair "$FOLDED"; record "$L1
$L2"
out=$(run); rc=$?
check "a folded spec with every examined link silent -> rc 2" "$rc" "2"
has "  and the verdict word is skipped" "$out" 'check-plan-links: skipped'
has "  and the spec-end link is reported skipped, not moved" "$out" 'skipped L1'
hasnt "  and never as moved" "$out" 'moved L1'
has "  and the design-to-design link was still examined" "$out" 'silent=1'
has "  and the skip is counted" "$out" 'skipped=1'
pair "$FOLDED" "${DESIGN_TEXT/A count/One count}"
out=$(run); rc=$?
check "a folded spec with a moved design-to-design link -> rc 1" "$rc" "1"
has "  and the link is reported" "$out" 'moved L2'
pair "$FOLDED"; no_record
out=$(run); rc=$?
check "a folded spec with no record -> rc 2" "$rc" "2"
has "  and reads skipped, not cannot-run" "$out" 'check-plan-links: skipped'
record "$L1"; unstage
out=$(run); rc=$?
check "a folded spec with an unstaged record -> rc 2" "$rc" "2"
has "  and that is a cannot-run" "$out" 'CANNOT RUN'
pair "$FOLDED

## Width

The window is forty rounds wide."; record "$L1"
out=$(run); rc=$?
check "control: one heading beyond the kept ones and the spec is read as a plan" "$rc" "0"

printf '\n== the record suffix against THIS repository own ignore rules ==\n'
# Run rather than reasoned about: the working record beside it is swallowed, and this one must not be.
git -C "$ROOT" check-ignore -q "ai-docs/plans/probe.progress.md" \
  && ok "the working record's suffix IS ignored here" \
  || bad "the working record's suffix IS ignored here"
git -C "$ROOT" check-ignore -q "ai-docs/plans/probe.links.md" \
  && bad "the record of declared links' suffix is NOT ignored here" \
  || ok "the record of declared links' suffix is NOT ignored here"

printf '\n== hygiene ==\n'
[ ! -e "$T/scripts/__pycache__" ] && ok "no bytecode cache is left in the tree it ran from" \
  || bad "no bytecode cache is left in the tree it ran from"
python3 -B -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' \
  "${HERE}/check-plan-links.py" 2>/dev/null
check "the payload parses" "$?" "0"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
