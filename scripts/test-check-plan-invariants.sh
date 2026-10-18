#!/usr/bin/env bash
#
# Tests for check-plan-invariants.sh -- the verification that the base
# principles of a spec and a design are intact, that the tree's statement
# inventory still matches the record, that nothing has added a required element,
# and that the edit-time refusal still covers the pages that define one.
#
# Run: bash scripts/test-check-plan-invariants.sh
#
# WHY THESE LEGS. Every characteristic failure of a detector is a FALSE GREEN,
# so no leg here asserts "rc 1 on a mutated tree" and stops. Each plants one
# defect whose correct answer is known independently and asserts WHICH
# principle, element, page or statement the finding names: an rc-only assertion
# is satisfied by a check that reddens on everything, which is the same thing as
# a check that measures nothing.
#
# THE FIXTURE IS A COPY OF THE TRACKED TREE, STAGED, COMMITTED, AND THEN
# ACCEPTED. All four steps are load-bearing. The check takes its corpus from the
# git INDEX while reading eight files DIRECTLY for their data, so a file that is
# present but unstaged is read for data and never compared -- and the sweep then
# reports a clean run over a corpus that does not contain the planted defect.
# That happened once on the real tree, with the one page this check exists to
# protect left out of its own corpus, so the first leg below is a positive
# control on the fixture itself. The COMMIT matters because the comparison reads
# a blob the record names: a fixture whose objects are only loose and
# unreferenced is one garbage collection away from a cannot-run. And the
# ACCEPTANCE is what writes the record, so the fixture's expectation is built
# from the fixture's own tree rather than inherited from the real one.
#
# EVERY MUTATION IS POSITIVE-CONTROLLED, and that is measured rather than
# defensive: two mutations of the principles document matched nothing -- the
# document hard-wraps and the sentence being replaced did not -- and both legs
# went GREEN over an unmutated tree. `tweak` and `mutant` now report how many
# sites they changed and fail the leg at zero.
#
# ANY TEXT CHANGE ANYWHERE IN THE CORPUS REDDENS THE SECOND LEG, so no leg here
# asserts a clean verdict over a mutated tree. That is the point of the
# comparison rather than an inconvenience: a mutation that produced a clean
# verdict would be a statement that changed and was not reported.
#
# WHAT IS PINNED ELSEWHERE, so this suite does not claim it. The pre-commit
# entry point's reading of a member that exits non-zero is a leg in
# scripts/test-run-checks.sh; this suite pins the rc 2 outcome itself, not the
# runner's treatment of it. The guard's own firing and silence directions are
# legs in hooks/lib/test-plan-invariants-guard.sh.

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
CHECK="${HERE}/check-plan-invariants.sh"
# THE CHECK IS THREE FILES, so a mutant is three files. The entry point loads
# its payload from its OWN directory and that payload loads the second sibling
# from its own, so a mutant built by copying fewer than all three would run
# UNMUTATED code beside the real thing, and every mutation leg below would come
# back green against a defect it never planted.
PAYLOAD="${HERE}/check-plan-invariants.py"
REFUSAL="${HERE}/check-plan-invariants-refusal.py"
RECORD='ai-docs/fixtures/plan-invariants.inventory'

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in output" ;; esac; }
# LIKE has(), BUT $3 IS A GLOB rather than a literal. It exists for one shape:
# a roster line that must NAME a size without the size being pinned. A pinned
# count there is a false assertion waiting for the next commit -- the three
# excluded surfaces grow whenever anyone lands a plan document, a learning entry
# or a config file, and the plan-documents count broke on the very merge that
# shipped this suite, because that merge moved three plan documents into done/.
hasg() { case "$2" in $3) ok "$1" ;; *) bad "$1 -- expected [$3] to match the output" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3] in output" ;; *) ok "$1" ;; esac; }
gt()   { if [ "${2:-0}" -gt "$3" ]; then ok "$1"; else bad "$1 (got [$2], want more than $3)"; fi; }

T=$(mktemp -d); trap 'chmod -R u+rwX "$T" 2>/dev/null; rm -rf "$T"' EXIT INT TERM
BASE="$T/base"
W="$T/work"

# The tracked set is copied file by file rather than with `cp -R .`, so the
# fixture carries exactly the corpus the check would sweep here and nothing the
# working tree happens to leave lying about.
build_base() {
  mkdir -p "$BASE"
  git -C "$ROOT" ls-files -z | while IFS= read -r -d '' p; do
    mkdir -p "$BASE/$(dirname -- "$p")"
    cp "$ROOT/$p" "$BASE/$p"
  done
  git -C "$BASE" init -q
  git -C "$BASE" add -A
  ACCEPT_OUT=$(bash "$CHECK" --root "$BASE" --accept 2>&1); ACCEPT_RC=$?
  git -C "$BASE" add -A
  git -C "$BASE" -c user.email=fixture@example.invalid -c user.name=fixture \
    commit -q -m 'the fixture tree, with the record the comparison reads'
}

MUT="$T/mutant"
fresh() { rm -rf "$W"; cp -R "$BASE" "$W"; }
run()   { OUT=$(bash "$CHECK" --root "$W" 2>&1); RC=$?; }
runm()  { OUT=$(bash "$MUT/check-plan-invariants.sh" --root "$W" 2>&1); RC=$?; }
accept(){ OUT=$(bash "$CHECK" --root "$W" --accept 2>&1); RC=$?; }

figure() { printf '%s\n' "$OUT" | sed -n "s/^check-plan-invariants: .*$1=\([0-9]*\).*/\1/p"; }

tweak() {
  local n
  n=$(python3 - "$W/$1" "$2" "$3" <<'PY'
import re
import sys

path, pattern, replacement = sys.argv[1:4]
with open(path, encoding='utf-8') as fh:
    body = fh.read()
out, n = re.subn(pattern, replacement, body, flags=re.S | re.M)
print(n)
if n:
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(out)
PY
)
  if [ "${n:-0}" = "0" ]; then bad "  the mutation matched nothing in $1"; return 1; fi
  ok "  planted in $1 ($n site(s))"
}

plant() {
  if [ ! -f "$W/$1" ]; then bad "  no such page in the fixture: $1"; return 1; fi
  printf '\n%s\n' "$2" >> "$W/$1"
  ok "  planted in $1"
}

# Inside a fenced block, and inside a table row. Two of the four line-oriented
# shapes, chosen because they are the two a reader would most expect a detector
# to skip -- a fence is "code, not prose" and a row is "data, not a sentence".
plant_fence() { # <file> <text>
  python3 - "$W/$1" "$2" <<'PY'
import re
import sys

path, text = sys.argv[1:3]
body = open(path, encoding='utf-8').read()
m = re.search(r'(?ms)^```markdown\n(.*?)^```', body)
if not m:
    sys.exit('no markdown-tagged fence in %s, so this leg would measure nothing' % path)
open(path, 'w', encoding='utf-8').write(body[:m.end(1)] + text + '\n' + body[m.end(1):])
PY
  if [ $? -ne 0 ]; then bad "  could not plant inside a fence in $1"; return 1; fi
  ok "  planted inside the fenced block in $1"
}

plant_row() { # <file> <row>
  python3 - "$W/$1" "$2" <<'PY'
import sys

path, row = sys.argv[1:3]
lines = open(path, encoding='utf-8').read().split('\n')
for i, line in enumerate(lines):
    if line.startswith('> |') and i > 20:
        lines.insert(i + 1, row)
        break
else:
    sys.exit('no quoted table row in %s, so this leg would measure nothing' % path)
open(path, 'w', encoding='utf-8').write('\n'.join(lines))
PY
  if [ $? -ne 0 ]; then bad "  could not plant a table row in $1"; return 1; fi
  ok "  planted a table row in $1"
}

# A WHOLE PARAGRAPH, because a statement is the unit. Deleting one hard-wrapped
# LINE of a paragraph changes that paragraph's joined text, which the comparison
# reports as a change rather than as a departure -- correctly, and not what a
# leg about departures should be measuring.
drop_para() { # <file> <phrase>
  local n
  n=$(python3 - "$W/$1" "$2" <<'PY'
import sys

path, phrase = sys.argv[1:3]
paras = open(path, encoding='utf-8').read().split('\n\n')
keep = [p for p in paras if phrase not in p]
print(len(paras) - len(keep))
if len(keep) != len(paras):
    open(path, 'w', encoding='utf-8').write('\n\n'.join(keep))
PY
)
  if [ "${n:-0}" = "0" ]; then bad "  no paragraph in $1 carries [$2]"; return 1; fi
  ok "  dropped $n paragraph(s) from $1"
}

# The three files the check IS, copied whole, so a mutant is a complete check
# and not a mutated half running beside an unmutated one. Named once here and
# used by `mutant` below and by the load-guard legs, which break one of the
# three on purpose.
mutant_copy() {
  rm -rf "$MUT"; mkdir -p "$MUT"
  cp "$CHECK" "$MUT/check-plan-invariants.sh"
  cp "$PAYLOAD" "$MUT/check-plan-invariants.py"
  cp "$REFUSAL" "$MUT/check-plan-invariants-refusal.py"
}

# The replacement goes into every copy and the sites are TOTALLED, so a leg
# does not have to know which of the three its target text lives in -- while a
# target that has MOVED between them still reports zero sites rather than
# building a mutant that mutates nothing.
mutant() {
  local n
  mutant_copy
  n=$(python3 - "$MUT" "$1" "$2" <<'PY'
import os
import sys

where, old, new = sys.argv[1:4]
total = 0
for name in sorted(os.listdir(where)):
    target = os.path.join(where, name)
    with open(target, encoding='utf-8') as fh:
        body = fh.read()
    seen = body.count(old)
    if not seen:
        continue
    total += seen
    with open(target, 'w', encoding='utf-8') as fh:
        fh.write(body.replace(old, new))
print(total)
PY
)
  if [ "${n:-0}" = "0" ]; then bad "  the check mutant changed nothing"; return 1; fi
  ok "  check mutant built ($n site(s))"
}

# EVERY ELEMENT-SHAPED TOKEN BELOW IS ASSEMBLED, never spelled. Measured on the
# live tree: a token spelled literally here is a token this file plants in the
# very corpus the check sweeps, so it arrives as a statement of this file and is
# reported against this file. The assembly keeps the suite out of its own
# subject matter.
H='##'
ARRIVED="$H Rollout ledger"
LATE="$H Per-test line numbers"
ENUM_ELEM="$H Risks"

printf '\n== the fixture: the tracked tree, copied, STAGED, committed and accepted ==\n'
build_base
check "the acceptance run that writes the record completes" "$ACCEPT_RC" "0"
has "  and reports what it recorded" "$ACCEPT_OUT" "ACCEPTED -- the record now names this tree"
INDEX=$(git -C "$BASE" ls-files)
for p in docs/plan-invariants.md hooks/lib/plan-invariants-guard.sh agents/spec-writer.md \
         agents/design.md agents/design-review.md scripts/check-redline.sh hooks/hooks.json \
         scripts/check-plan-invariants.py; do
  has "the index carries $p, so its own text is compared and not merely read" "$INDEX" "$p"
done
has "the index carries the record itself, so no other clone is left on a cannot-run" "$INDEX" "$RECORD"

printf '\n== the clean case, and the figures a narrowed run cannot fake ==\n'
fresh; run
check "an unmutated copy of the tree -> rc 0" "$RC" "0"
has "  the verdict says clean rather than silent" "$OUT" "check-plan-invariants: clean"
has "  all eight principles counted"              "$OUT" "principles=8"
BASE_PAGES=$(figure pages)
BASE_STMT=$(figure statements)
BASE_ELEM=$(figure elements)
gt "  the corpus is the method surface, not a handful of files" "$BASE_PAGES" "100"
gt "  and the sweep compared statements rather than none"       "$BASE_STMT"  "10000"
check "  five surfaces were examined" "$(figure surfaces)" "5"
has "  the profile surface was examined"      "$OUT" "surface profile      examined-clean"
has "  the method surface was examined"       "$OUT" "surface method       examined-clean"
has "  the scaffolding surface was examined"  "$OUT" "surface scaffolding  examined-clean"
has "  the enforcement surface was examined, though the refusal covers none of it" \
    "$OUT" "surface enforcement  examined-clean"
has "  the verification surface was examined, though the refusal covers one file of it" \
    "$OUT" "surface verification examined-clean"
hasg "  and the three surfaces deliberately out are NAMED with their size, not omitted" \
    "$OUT" "*surface plan-documents not-examined ([0-9]* files, excluded by design*"
hasg "  the learning record among them" \
    "$OUT" "*surface learning-record not-examined ([0-9]* files, excluded by design*"
hasg "  and the repository's own mechanics" \
    "$OUT" "*surface repository-mechanics not-examined ([0-9]* files, excluded by design*"

printf '\n== leg 1: a reworded principle, and a removed one, read differently ==\n'
fresh
tweak docs/plan-invariants.md 'nothing is recorded in\s+both places' 'nothing is recorded in either place'
run
check "one principle reworded, nothing else touched -> rc 1" "$RC" "1"
has "  the finding names WHICH principle changed" "$OUT" "finding leg1-wording: principle 5"
has "  and prints the pinned sentence to compare against" "$OUT" "pinned:"
hasnt "  it is not reported as an absence" "$OUT" "leg1-absence: principle 5"

# A MUTANT IS THE WHOLE CHECK, and this is the leg that measures it rather than
# the header comment claiming it. The same reworded tree is put to a mutant
# whose payload cannot emit a wording finding: if the copy were the entry point
# alone, the mutant would load the real payload from the real directory and
# report the finding anyway. The mutant must also still redden, because an empty
# result is what a mutant that never ran produces.
mutant 'if norm(got) != norm(want):' 'if False and norm(got) != norm(want):'
runm
check "  the two-file mutant still runs, so its silence is a measurement" "$RC" "1"
hasnt "  and with the wording arm taken away it reports no wording finding" \
    "$OUT" "finding leg1-wording: principle 5"

fresh
tweak docs/plan-invariants.md '^5\. \*\*A changed requirement.*?(?=^6\. )' ''
run
check "the same principle REMOVED -> rc 1" "$RC" "1"
has "  reported as an absence: a vanished principle protects nothing" "$OUT" "finding leg1-absence: principle 5"
has "  naming the sentence that should have been there" "$OUT" 'Expected lead: "A changed requirement'
hasnt "  and not as a wording difference" "$OUT" "leg1-wording: principle 5"

fresh
tweak docs/plan-invariants.md '\*Because every sentence a design could write[^*]*\*' ''
run
check "a principle stripped of its one-clause reason -> rc 1" "$RC" "1"
has "  it is not counted as present"      "$OUT" "finding leg1-reason: principle 3"
has "  and the verdict's own count drops" "$OUT" "principles=7"

# EVERY GAP IN THESE TWO PATTERNS IS `\s+`, including the ones that are a single
# space on today's page. The page hard-wraps and the comparison collapses
# internal whitespace on purpose, so where a line break falls inside a sentence
# is not a fact about the page -- but a literal space in a mutation pattern pins
# it anyway, and `tweak` on a pattern that has stopped matching reports its own
# failure rather than a silent no-op. Spelling every gap this way is what keeps
# the next re-wrap of this paragraph from reddening a leg about something else.
fresh
tweak docs/plan-invariants.md 'two\s+failures\s+at\s+once:\s+invented\s+content\s+at\s+authoring\s+time,\s+and\s+a\s+review\s+loop' \
                              'one failure: a review loop'
run
check "the eighth principle naming only one of its two failures -> rc 1" "$RC" "1"
has "  reported as a wording difference on principle 8" "$OUT" "finding leg1-wording: principle 8"
has "  and the pinned sentence names the failure that went missing" "$OUT" "invented content at authoring time"

# The eighth principle's second half -- the provenance obligation over a stated
# number -- is pinned by the same mechanism as the first, and this is what shows
# it. Without it the half could be reworded on the page and in the pinned copy
# apart from one another with nothing here objecting, which is the state the
# two-co-ordinated-edits authorisation route depends on not being in.
fresh
tweak docs/plan-invariants.md 'a\s+threshold\s+the\s+task\s+handed\s+down,\s+an\s+estimate\s+derived\s+in\s+place\s+with\s+its\s+derivation\s+shown' \
                              'a threshold'
run
check "the eighth principle dropping two of its three admitted kinds of number -> rc 1" "$RC" "1"
has "  reported as a wording difference on principle 8" "$OUT" "finding leg1-wording: principle 8"
has "  and the pinned sentence names the kind that went missing" "$OUT" "an estimate derived in place"

printf '\n== leg 2: the three sentences a shape-reading mechanism cannot be trusted with ==\n'
# These three are the measured holes of the superseded classifier, which
# reported TWO of them clean on this very page. Each must arrive as exactly ONE
# statement carrying its own text, and each is paired with the control that the
# unmutated copy of the same page is clean -- a plant that reddens proves
# nothing on its own, and the pair is what shows the plant is responsible.
#
# The first is a required part of the design whose content cannot exist when the
# document is authored; the second states the same mandate beside a reading
# verb; the third names a section the enumeration already carries. Those three
# shapes are what defeated government-by-position, and the comparison reads none
# of them -- it only knows whether a statement is in the record.
while IFS= read -r sentence; do
  fresh; run
  check "the unmutated page is clean before this plant" "$RC" "0"
  fresh
  plant agents/design.md "$sentence"
  run
  check "that mandate planted on agents/design.md -> rc 1" "$RC" "1"
  check "  exactly ONE arrival, not a page-wide report" \
        "$(printf '%s\n' "$OUT" | grep -c '^finding leg2-arrival')" "1"
  has  "  carrying the sentence's own text" "$OUT" "$sentence"
  has  "  with its surface and the rule that produced it" \
       "$OUT" "finding leg2-arrival: method agents/design.md: a statement ARRIVED [exact match]"
  check "  and the statement total moved by exactly one" "$(figure statements)" "$((BASE_STMT + 1))"
done <<'SENTENCES'
Every design carries a list of tests with their line numbers and expected results.
The self-review reads the progress file, and every design carries a per-criterion table of test line numbers.
Every design carries a per-test line number and an expected result for each item in its ## Test Design section.
SENTENCES

printf '\n== leg 2: re-wrapping a paragraph is not a change to the inventory ==\n'
# THE 56-OF-56 PROPERTY, pinned here rather than left asserted in the design.
# The instrument reflows a run of non-blank lines only when EVERY line in it is
# ordinary prose, so the one transformation applied is a true paragraph reflow;
# two cruder instruments were tried first and both reported differences that
# traced to themselves, the giveaway each time being the statement TOTAL moving,
# which a reflow cannot do.
#
# The file set is the CORPUS's markdown, not every tracked `*.md`: README.md
# belongs to no surface and the check never reads it, while ai-docs/context.md
# is the profile surface. Getting that set wrong is how a run covers 54 files
# and reports success for 56, so the set's size and both edges are asserted.
corpus_md() {
  { git -C "$W" ls-files '*.md' | grep -Ev '^(ai-docs/|README\.md$)'
    git -C "$W" ls-files 'ai-docs/context.md'; } | sort -u
}

rewrap_all() { # <width> -> paragraphs reflowed
  local n=0 f
  for f in $(corpus_md); do
    n=$((n + $(python3 - "$W/$f" "$1" <<'PY'
import re
import sys
import textwrap

col = int(sys.argv[2])
lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
out, run = [], []
in_fence = False
in_front = bool(lines) and lines[0].strip() == '---'
reflowed = 0
SPECIAL = re.compile(r'^(?:#|\||>|[-*+]\s|\d+[.)]\s|---\s*$|===)')


def special(line):
    return bool(SPECIAL.match(line.strip())) or line.startswith(('    ', '\t'))


def flush():
    global reflowed
    if not run:
        return
    if any(special(x) for x in run) or len(run) < 2:
        out.extend(run)
    else:
        out.extend(textwrap.wrap(' '.join(x.strip() for x in run), col,
                                 break_long_words=False, break_on_hyphens=False))
        reflowed += 1
    del run[:]


for idx, line in enumerate(lines):
    s = line.strip()
    if in_front:
        out.append(line)
        if idx > 0 and s == '---':
            in_front = False
        continue
    if s.startswith(('```', '~~~')):
        flush()
        in_fence = not in_fence
        out.append(line)
        continue
    if in_fence or not s:
        flush()
        out.append(line)
        continue
    run.append(line)
flush()
open(sys.argv[1], 'w', encoding='utf-8').write('\n'.join(out))
print(reflowed)
PY
)))
  done
  printf '%s' "$n"
}

fresh
check "the corpus carries 56 markdown files, which is the set this property is about" \
      "$(corpus_md | wc -l | tr -d ' ')" "56"
check "  README.md is NOT in it -- it belongs to no surface" "$(corpus_md | grep -c '^README.md$')" "0"
check "  ai-docs/context.md IS in it -- the profile surface" \
      "$(corpus_md | grep -c '^ai-docs/context.md$')" "1"
for col in 72 88 110; do
  fresh
  n=$(rewrap_all "$col")
  gt "every corpus markdown file re-wrapped at $col columns reflowed paragraphs" "$n" "100"
  run
  check "  the inventory is unchanged -> rc 0" "$RC" "0"
  check "  and the statement total did not move" "$(figure statements)" "$BASE_STMT"
  check "  with no arrival, departure or change reported" \
        "$(printf '%s\n' "$OUT" | grep -c '^finding leg2-')" "0"
done

printf '\n== every surfaceless tracked file belongs to exactly one named exclusion ==\n'
# IN BOTH DIRECTIONS, because one direction alone is satisfiable by the wrong
# thing. Every tracked file with no surface must be claimed by an exclusion --
# otherwise the report says nothing whatever about it, which is the state eight
# of them sat in while a mandate appended to README.md gave a clean verdict --
# and no file may be claimed by two, which is what would let a widened
# exclusion quietly swallow another's members. The check's own `unaccounted`
# figure is the first direction; the second is computed here from the fixture's
# index, so neither the corpus rule nor the exclusion set moves on its own.
#
# The README.md pin above is the same property from the other end: that file is
# deliberately outside the corpus, so what accounts for it has to be an
# exclusion and nothing else.
fresh
run
check "the check reports no unaccounted file -> rc 0" "$RC" "0"
check "  unaccounted=0 on the verdict line" "$(figure unaccounted)" "0"
hasnt "  and no UNACCOUNTED block in the report" "$OUT" "UNACCOUNTED"
EXCL=$(python3 - "$W" <<'PY'
import re
import subprocess
import sys

root = sys.argv[1]
out = subprocess.run(['git', '-C', root, 'ls-files', '-z'],
                     capture_output=True, check=True).stdout
tracked = [p for p in out.decode('utf-8').split('\0') if p]
# The surface rule and the three membership rules, spelled here INDEPENDENTLY of
# the payload: a leg that imported them would compare the payload against itself
# and could not detect either one being wrong.
PROFILE = ('AGENTS.md', 'CLAUDE.md', 'ai-docs/context.md')
RECORD = 'ai-docs/fixtures/plan-invariants.inventory'


def surfaced(p):
    return (p in PROFILE
            or p.startswith(('templates/', 'hooks/', 'scripts/', 'docs/', 'agents/',
                             'skills/', 'rules/'))
            or bool(re.match(r'^skills/[^/]+/scripts/', p)))


RULES = {
    'plan-documents': lambda p: p.startswith('ai-docs/plans/'),
    'learning-record': lambda p: p == 'ai-docs/learnings.md' or p.startswith('ai-docs/learnings/'),
    'repository-mechanics': lambda p: (p.startswith(('.claude-plugin/', '.claude/',
                                                     'ai-docs/fixtures/loop-corpus/'))
                                       or p in ('.gitignore', 'README.md')),
}
none, many = [], []
for p in tracked:
    if surfaced(p) or p == RECORD:
        continue
    hit = [name for name, rule in RULES.items() if rule(p)]
    if not hit:
        none.append(p)
    elif len(hit) > 1:
        many.append(p)
print('%d %d' % (len(none), len(many)))
PY
)
check "  no surfaceless tracked file is claimed by NO exclusion" "${EXCL% *}" "0"
check "  and none is claimed by MORE THAN ONE" "${EXCL#* }" "0"
has "  the roster names all three with a reason" "$OUT" "surface repository-mechanics not-examined"
has "  including the plan documents" "$OUT" "surface plan-documents not-examined"
has "  and the learning record" "$OUT" "surface learning-record not-examined"

# The other direction of the same property: a file that belongs to no exclusion
# IS reported, so `unaccounted=0` above is a measurement rather than a constant.
fresh
printf 'x\n' > "$W/UNCLASSIFIED.txt"
git -C "$W" add -A
run
check "a tracked file in neither a surface nor an exclusion -> rc 0 but counted" "$RC" "0"
check "  unaccounted=1" "$(figure unaccounted)" "1"
has "  and the report names the file rather than only counting it" "$OUT" "UNCLASSIFIED.txt"

printf '\n== leg 2: a relocation inside a CODE file is a change; inside PROSE it is not ==\n'
# Both mutations below were measured reporting NOTHING before this leg existed,
# and the first of them is why the answer set has a fourth member: it moves one
# line and makes three cannot-run guards unreachable while leaving the file's
# line multiset identical, so a multiset comparison is silent by construction.
#
# THE SECOND IS NOT THE SAME LEG WITH A DIFFERENT FILE. It pins the BOUND: for
# prose the comparison stays position-independent, which the 56-of-56 re-wrap
# property above depends on, so the same class of mutation in markdown is
# deliberately NOT reported. A fully positional comparison was the rejected
# variant, and this leg is what would redden if someone took it.
relocate() { # <file> <line-to-move> <line-to-insert-before>
  local n
  n=$(python3 - "$W/$1" "$2" "$3" <<'PY'
import sys

path, needle, before = sys.argv[1:4]
lines = open(path, encoding='utf-8').read().split('\n')
src = [i for i, l in enumerate(lines) if l.strip() == needle]
dst = [i for i, l in enumerate(lines) if l.strip() == before]
if len(src) != 1 or len(dst) != 1:
    print(0)
    sys.exit(0)
moved = lines.pop(src[0])
dst = [i for i, l in enumerate(lines) if l.strip() == before]
lines.insert(dst[0], moved)
open(path, 'w', encoding='utf-8').write('\n'.join(lines))
print(1)
PY
)
  if [ "${n:-0}" = "0" ]; then bad "  the line to move was not uniquely found in $1"; return 1; fi
  ok "  moved one line in $1, leaving its line multiset identical"
}

fresh
run
check "the control: nothing moved yet -> rc 0" "$RC" "0"
relocate scripts/check-plan-invariants.sh \
  'exec python3 -B "$PAYLOAD" "$ROOT" "$MODE" "$RECORD"' \
  'if [ "$MODE" != accept ]; then'
run
check "the exec moved above the record preflights -> rc 1" "$RC" "1"
has "  reported as a relocation and not as an arrival or a departure" "$OUT" "finding leg2-relocation"
has "  naming the statement that moved" "$OUT" 'exec python3 -B "$PAYLOAD"'
has "  and where it moved from and to" "$OUT" "MOVED from statement"
check "  with the statement total unmoved, so no text changed" "$(figure statements)" "$BASE_STMT"
check "  and nothing reported as arrived, departed or changed" \
      "$(printf '%s\n' "$OUT" | grep -cE '^finding leg2-(arrival|departure|change)')" "0"

fresh
relocate agents/self-review.md \
  '- Build / test gates — enforced during Implementation and Verify steps.' \
  '### 1. Spec conformance'
run
check "the same class of move inside PROSE -> rc 0, the disclosed bound" "$RC" "0"
check "  statements unmoved, so the mutation really was a pure move" "$(figure statements)" "$BASE_STMT"
hasnt "  and no relocation reported, which is what prose re-wrap stability needs" "$OUT" "leg2-relocation"
# The control for the bound: the same file, EDITED rather than moved, is
# reported -- so the silence above is about position and not about the file.
plant agents/self-review.md 'A planted mandate in the prose control file.'
run
check "  while a text change in that same file IS reported -> rc 1" "$RC" "1"
has "  as an arrival carrying its own text" "$OUT" "A planted mandate in the prose control file."

# A DE-INDENT IS THE SECOND WAY A CODE FILE CHANGES WITH EVERY WORD STANDING
# STILL, and it was measured reporting nothing while the code spelling stripped.
# The prose half is the BOUND rather than the same leg twice: a prose statement
# is a paragraph joined from normalised lines, so a re-indented paragraph must
# stay silent or the re-wrap property above goes with it.
shift_indent() { # <file> <first-line-of-block> <lines> <columns, negative de-indents>
  local n
  n=$(python3 - "$W/$1" "$2" "$3" "$4" <<'PY'
import sys

path, needle, count, cols = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
lines = open(path, encoding='utf-8').read().split('\n')
hit = [i for i, l in enumerate(lines) if l.strip() == needle]
done = 0
if len(hit) == 1:
    for i in range(hit[0], hit[0] + count):
        if cols < 0 and not lines[i].startswith(' ' * -cols):
            break
        lines[i] = lines[i][-cols:] if cols < 0 else ' ' * cols + lines[i]
        done += 1
if done == count:
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))
print(done)
PY
)
  if [ "${n:-0}" != "$3" ]; then bad "  no $3-line block starting [$2] to shift in $1"; return 1; fi
  ok "  shifted $n line(s) by $4 columns in $1, every word unchanged"
}
# The four columns the block below loses, so the assertion can require them back
# INSIDE the recorded statement rather than counting spaces by hand.
IND4='    '

fresh
run
check "the control: nothing re-indented yet -> rc 0" "$RC" "0"
shift_indent scripts/check-plan-invariants.py 'if not paths:' 2 -4
run
check "a two-line block de-indented out of its branch -> rc 1" "$RC" "1"
has "  reported on the file whose indentation moved" \
    "$OUT" "finding leg2-change: verification scripts/check-plan-invariants.py"
has "  with the statement it replaced carrying the indent it had" \
    "$OUT" "previously: ${IND4}if not paths:"
check "  and the statement total unmoved -- the TEXT moved, not the count" \
      "$(figure statements)" "$BASE_STMT"

fresh
shift_indent docs/workflow.md \
  'directory. That address is actionable only if the agent may open it, so the directory is read-allowed and' 2 4
run
check "the same shift inside a hard-wrapped PROSE paragraph -> rc 0" "$RC" "0"
check "  statements unmoved, so the paragraph is still one statement" "$(figure statements)" "$BASE_STMT"
hasnt "  and nothing reported, which the paragraph-joined spelling needs" "$OUT" "finding leg2-"

printf '\n== leg 2: a MULTISET, and the one failure a set could not see ==\n'
# The design's most load-bearing measured decision: 111 of the 122 corpus files
# carry a repeated normalised statement, so under set semantics the removal of
# ONE of several identical lines is invisible. This is the leg that makes that
# a measurement rather than a claim -- two identical statements are accepted
# into the record and then one is removed, which the real check reports and a
# set-semantics mutant of it does not.
DUP='A planted statement that appears twice over.'
fresh
plant docs/workflow.md "$DUP"
plant docs/workflow.md "$DUP"
accept
check "two identical statements accepted into the record" "$RC" "0"
python3 - "$W/docs/workflow.md" "$DUP" <<'PY'
import sys

path, dup = sys.argv[1:3]
body = open(path, encoding='utf-8').read()
if body.count(dup) != 2:
    sys.exit('expected the planted statement twice, found %d' % body.count(dup))
open(path, 'w', encoding='utf-8').write(body.replace(dup + '\n', '', 1))
PY
check "  one of the two removed" "$?" "0"
run
check "the real check reports the removal -> rc 1" "$RC" "1"
has "  as a departure carrying the statement that went" "$OUT" "DEPARTED [exact match]"
has "  which is the text in question" "$OUT" "$DUP"

mutant 'now = collections.Counter(now_units)
        was = collections.Counter(was_units)' \
       'now = collections.Counter(set(now_units))
        was = collections.Counter(set(was_units))'
runm
check "a SET-semantics mutant on the same tree -> clean, so the removal vanishes" "$RC" "0"
hasnt "  nothing is reported at all" "$OUT" "finding leg2-"

printf '\n== leg 2: a reworded statement reports what it said BEFORE ==\n'
fresh
tweak docs/workflow.md 'A divergence found while the code is being written has no round number' \
                       'A divergence found while the code is being authored has no round number'
run
check "one word changed in one prose sentence -> rc 1" "$RC" "1"
has "  reported as a CHANGE rather than as an unrelated pair" \
    "$OUT" "finding leg2-change: method docs/workflow.md: a statement CHANGED"
has "  naming the rule and the ratio it was paired at" "$OUT" "[aligned at a token overlap of 0."
has "  carrying the new text"        "$OUT" "while the code is being authored has no round number"
has "  and what it said before"      "$OUT" "previously: A divergence found while the code is being written"
check "  the statement total is unchanged, because a change is a pair and not an addition" \
      "$(figure statements)" "$BASE_STMT"

printf '\n== leg 2: a departure carries the departed text ==\n'
fresh
drop_para agents/self-improve.md 'declined — surfaced to the author'
run
check "the declining contract's paragraph removed -> rc 1" "$RC" "1"
has "  reported as a departure on the page it left" \
    "$OUT" "finding leg2-departure: method agents/self-improve.md: a statement DEPARTED"
has "  naming the rule that produced it" "$OUT" "DEPARTED [exact match]"
has "  carrying the text that went, so the weakening cannot be read as nothing" \
    "$OUT" "declined — surfaced to the author"
# AC18's own closure: the contract that routes this class to the author is
# instruction text, and this is what makes weakening it loud. The control is
# that the unmutated page is clean, which the leg above the first plant
# establishes for the whole tree.
gt "  and more than one statement of that paragraph is reported" \
   "$(printf '%s\n' "$OUT" | grep -c '^finding leg2-departure')" "1"

printf '\n== leg 2: no region is exempt -- a fence, a table row, and emitted text ==\n'
fresh
plant_fence agents/design.md 'a planted line inside a fenced block'
run
check "an arrival inside a FENCED block -> rc 1" "$RC" "1"
has "  reported with its own text like any other statement" \
    "$OUT" "a planted line inside a fenced block"
check "  and counted" "$(figure statements)" "$((BASE_STMT + 1))"

fresh
plant_row docs/propagation.md '> | a planted trigger cell | a planted sync-group cell |'
run
check "an arrival inside a TABLE ROW -> rc 1" "$RC" "1"
has "  reported with the row's own text" \
    "$OUT" "> | a planted trigger cell | a planted sync-group cell |"

fresh
tweak hooks/hooks.json 'REQUIRED SESSION START: read ' \
  'REQUIRED SESSION START: every design carries a per-test list with its line numbers. Read '
run
check "a mandate carried only in the text a session BEGINS with -> rc 1" "$RC" "1"
has "  reported on the layer that writes it into an agent's context" \
    "$OUT" "finding leg2-change: enforcement hooks/hooks.json: a statement CHANGED"
has "  carrying the mandate's own words" "$OUT" "every design carries a per-test list with its line numbers"
has "  and what that message said before" "$OUT" "previously:"

printf '\n== leg 3: an element arriving, by each route that can make one required ==\n'
fresh
tweak agents/design.md '^## Use cases$' "$LATE\\n## Use cases"
run
check "the design template gains an element -> rc 1" "$RC" "1"
has "  named with the document it was mandated of" \
    "$OUT" "finding leg3-arrival: a page mandates the design element \`$LATE\`"
has "  and reported as an arrival" "$OUT" "an element has ARRIVED"

fresh
tweak agents/design-review.md '^   - \*\*Risks\*\* —' \
  "   - **Rollout** — a design missing \`$ARRIVED\` = \`major\`.\\n   - **Risks** —"
run
check "an element made mandatory by a blocking-absence rule alone -> rc 1" "$RC" "1"
has "  reported as an addition, with no template altered anywhere" \
    "$OUT" "finding leg3-arrival: a page mandates the design element \`$ARRIVED\`"

fresh
tweak agents/design.md '^## Risks$' "$ARRIVED"
run
check "one required element replaced by another -> rc 1" "$RC" "1"
has "  the arrival is named"   "$OUT" "finding leg3-arrival: a page mandates the design element \`$ARRIVED\`"
has "  the departure is named" "$OUT" "finding leg3-departure: the record in docs/plan-invariants.md carries the design element \`$ENUM_ELEM\`"
check "  while the element COUNT is exactly what it was, so only a set comparison sees it" \
      "$(figure elements)" "$BASE_ELEM"

fresh
tweak scripts/check-redline.sh "\^## Open questions'" "^## Open questions|^$ARRIVED'"
run
check "the fold's removal list widened -> rc 1" "$RC" "1"
has "  reported as a prohibition arriving rather than joining the element set" \
    "$OUT" "finding leg3-prohibition: the fold is now required to REMOVE \`$ARRIVED\`"

printf '\n== leg 4: the refusal against the table, in both directions ==\n'
fresh
tweak hooks/lib/plan-invariants-guard.sh '^skills/task/reference.md\n' ''
run
check "a table member the refusal stopped covering -> rc 1" "$RC" "1"
has "  the uncovered page is named as an unguarded route" \
    "$OUT" "finding leg4-uncovered: the protected-page table names skills/task/reference.md"

# The direction the set comparison cannot see: drop the page from the table as
# well and the two agree, while the page still carries the locus that put it
# there. Only the per-page locus test reports that.
fresh
tweak hooks/lib/plan-invariants-guard.sh '^skills/task/reference.md\n' ''
tweak docs/plan-invariants.md '^\| `\$\{CLAUDE_PLUGIN_ROOT\}/skills/task/reference\.md`[^\n]*\n' ''
run
check "that page dropped from the guard AND the table -> rc 1" "$RC" "1"
has "  the locus it still carries is what reports it" \
    "$OUT" "finding leg4-unguarded: skills/task/reference.md carries an element-defining locus"
hasnt "  and the two sets agree, so the comparison says nothing" \
    "$OUT" "finding leg4-uncovered: the protected-page table names skills/task/reference.md"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" \
  "scripts/check-redline.sh\ndocs/considerations-link-reading.md'"
tweak docs/plan-invariants.md '\| `\$\{CLAUDE_PLUGIN_ROOT\}/scripts/check-redline.sh` \| Carries the retained' \
  '| `${CLAUDE_PLUGIN_ROOT}/docs/considerations-link-reading.md` | Added by hand, defining nothing |\n| `${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh` | Carries the retained'
run
check "a page covered AND tabled that defines no element -> rc 1" "$RC" "1"
has "  reported as a surplus interruption, which the set comparison agrees about" \
    "$OUT" "finding leg4-no-locus: docs/considerations-link-reading.md is in the protected-page table"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" "scripts/check-redline.sh\ndocs/workflow.md'"
run
check "the refusal widened past the table -> rc 1" "$RC" "1"
has "  every surplus member is named, because each one is a recurring interruption" \
    "$OUT" "finding leg4-surplus: the refusal covers docs/workflow.md"

fresh
tweak hooks/hooks.json 'hooks/lib/plan-invariants-guard\.sh' 'hooks/lib/not-registered.sh'
run
check "the refusal unregistered -> rc 1" "$RC" "1"
has "  its page list is not coverage, on the editing matcher" \
    "$OUT" "finding leg4-registration: the refusal is not registered on the Edit|Write matcher"
has "  nor on the shell matcher" \
    "$OUT" "finding leg4-registration: the refusal is not registered on the Bash matcher"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" "scripts/check-redline.sh\nagents/self-review.md'"
run
check "a documented near miss that the refusal covers anyway -> rc 1" "$RC" "1"
has "  the near-miss control reports it" \
    "$OUT" "finding leg4-near-miss: agents/self-review.md is documented as a deliberate near miss"
has "  and the set comparison reports it too, while they still disagree" \
    "$OUT" "finding leg4-surplus: the refusal covers agents/self-review.md"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" "scripts/check-redline.sh\nagents/self-review.md'"
tweak docs/plan-invariants.md '\| `\$\{CLAUDE_PLUGIN_ROOT\}/scripts/check-redline.sh` \| Carries the retained' \
  '| `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` | Added by hand, and still a documented near miss |\n| `${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh` | Carries the retained'
run
check "that near miss added to the guard AND the table -> rc 1" "$RC" "1"
has "  the page set is reported as contradicting itself" \
    "$OUT" "finding leg4-near-miss: agents/self-review.md is in BOTH the protected-page table and the near-miss table"
hasnt "  which the covered-versus-table comparison cannot see, because both of those now agree" \
    "$OUT" "finding leg4-surplus: the refusal covers agents/self-review.md"

printf '\n== cannot run, which is not a pass ==\n'
fresh
chmod 000 "$W/agents/design.md"
run
check "a required input unreadable -> rc 2" "$RC" "2"
has "  an outcome distinct from both clean and red" "$OUT" "CANNOT RUN -- which is not a pass"
has "  naming the input and what it was needed for" "$OUT" "cannot run: agents/design.md is unreadable"
hasnt "  and no clean verdict is printed"           "$OUT" "check-plan-invariants: clean"
chmod 644 "$W/agents/design.md"

fresh
tweak agents/spec-writer.md '^```markdown\n.*?^```' '```markdown\nnothing\n```'
run
check "a template that MOVED -> rc 2, not an empty element set" "$RC" "2"
has "  the empty extraction is reported rather than read as agreement" \
    "$OUT" "yielded no bare section line inside a markdown-tagged fence"

fresh
git -C "$W" rm --cached -q docs/plan-invariants.md
run
check "a file read for its data but left out of the tracked corpus -> rc 2" "$RC" "2"
has "  the narrowing is named rather than swept past" \
    "$OUT" "docs/plan-invariants.md is read for its data but the tracked corpus does not carry it"

# A page leaving the index used to be a clean run with a smaller page count, and
# the figure beside the verdict was the only way to see it. Under the comparison
# the record still names the path, so the whole file reports as departed and the
# VERDICT moves as well -- the narrowing is now visible in two places rather
# than one, and the figure is the weaker of the two signals.
fresh
git -C "$W" rm --cached -q docs/workflow.md
run
check "a page dropped from the corpus -> rc 1, because the record still names it" "$RC" "1"
check "  and the page count in the verdict moved too" "$(figure pages)" "$((BASE_PAGES - 1))"
has "  every statement of the departed file is reported, naming the rule that produced it" \
    "$OUT" "finding leg2-departure: method docs/workflow.md: a statement DEPARTED [exact match, and the record names a path the corpus no longer carries"

mkdir -p "$T/bare"; git -C "$T/bare" init -q
OUT=$(bash "$CHECK" --root "$T/bare" 2>&1); RC=$?
check "a tree with no tracked file at all -> rc 2" "$RC" "2"
has "  and the absent record is what names it first" "$OUT" "does not exist"

# The same tree WITH a record, so the empty-corpus branch is reached rather than
# shadowed by the preflight above. Two different reasons for one outcome, and
# each one has to be shown to be live.
mkdir -p "$T/bare/$(dirname -- "$RECORD")"
cp "$BASE/$RECORD" "$T/bare/$RECORD"
git -C "$T/bare" add -A
OUT=$(bash "$CHECK" --root "$T/bare" 2>&1); RC=$?
check "a tree carrying the record and nothing else -> rc 2" "$RC" "2"
has "  an empty corpus must not read as a clean sweep" "$OUT" "the detection corpus came back empty"

printf '\n== a surface not examined is not a surface examined and clean ==\n'
# An unreadable corpus file is a run that compared fewer statements than the
# corpus holds, which is this approach's own false green, so it is a cannot-run
# rather than a completed run with a quieter roster. The roster still prints,
# because that is what tells a surface not examined apart from one examined and
# found clean -- and a cannot-run is exactly the outcome where the distinction
# is live.
fresh
chmod 000 "$W/docs/considerations-link-reading.md"
run
check "one page of an examined surface unreadable -> rc 2" "$RC" "2"
has "  reported as a run that could not complete" "$OUT" "CANNOT RUN -- which is not a pass"
has "  naming the file whose statements were never compared" \
    "$OUT" "cannot run: docs/considerations-link-reading.md is in the corpus and could not be read"
has "  the surface is reported as NOT examined, on the cannot-run path" \
    "$OUT" "surface method       not-examined"
hasnt "  so it is not counted among the examined-clean" "$OUT" "surface method       examined-clean"
has "  while the surfaces that were read still report cleanly" "$OUT" "surface profile      examined-clean"
chmod 644 "$W/docs/considerations-link-reading.md"

printf '\n== a surface WITH findings is not a surface examined and clean either ==\n'
# THE THIRD ROSTER STATE, and the one that shipped broken. The comparison leg
# had its surface, interpolated it into the finding's TEXT, and then called
# `finding` with two arguments -- so no leg-2 finding ever reached the red set
# and the surface carrying every finding of a run read as examined-clean.
# Reproduced on the real tree before the fix: 17 arrivals on the profile
# surface, verdict `17 findings`, rc 1, and `surface profile      examined-clean`
# underneath them. The verdict and the exit code were both right, which is what
# kept it invisible -- an rc-only leg could never have seen it.
#
# All three parts are needed. The firing direction alone is satisfied by a
# roster that reddens everything, so a surface with no finding in the SAME run
# is asserted clean beside it; and the mutant is what makes the pair falsifiable.
fresh
plant agents/design.md 'A roster that cannot say which surface the findings are on is a roster that says nothing.'
run
check "one statement planted on a method page -> rc 1" "$RC" "1"
check "  exactly ONE arrival, so every other surface's silence is about this plant" \
      "$(printf '%s\n' "$OUT" | grep -c '^finding leg2-arrival')" "1"
has "  the finding names the method surface in its own text" \
    "$OUT" "finding leg2-arrival: method agents/design.md: a statement ARRIVED"
has "  and the ROSTER reports that surface as examined-with-findings" \
    "$OUT" "surface method       examined-with-findings"
hasnt "  so it is not counted among the examined-clean" "$OUT" "surface method       examined-clean"
has "  the profile surface, which carries no finding here, is still clean" \
    "$OUT" "surface profile      examined-clean"
has "  and so is scaffolding"  "$OUT" "surface scaffolding  examined-clean"
has "  and enforcement"        "$OUT" "surface enforcement  examined-clean"
has "  and verification"       "$OUT" "surface verification examined-clean"

# The mutant takes back the one argument the fix added -- the surface is still
# computed and still interpolated, which is exactly why the defect read as
# correct at a glance. It must still redden and still name the finding, because
# an empty result is what a mutant that never ran produces.
mutant 'finding(leg, line, surf)' 'finding(leg, line)'
runm
check "  a mutant that interpolates the surface but does not PASS it -> still rc 1" "$RC" "1"
has "  still reporting the finding, so its silence is about the roster alone" \
    "$OUT" "finding leg2-arrival: method agents/design.md: a statement ARRIVED"
has "  while the roster calls the surface carrying it examined-clean" \
    "$OUT" "surface method       examined-clean"
hasnt "  which is the false clean claim this leg exists to catch" \
    "$OUT" "surface method       examined-with-findings"

printf '\n== the record: every way it can stop being an expectation ==\n'
# Four ways, each a cannot-run rather than a clean sweep or a red verdict,
# because a run with no usable expectation has compared nothing. The fourth is
# paired with the one exit the design builds for it.
fresh; rm "$W/$RECORD"; run
check "the record absent -> rc 2" "$RC" "2"
has "  naming it, and naming the route that creates it" "$OUT" "--accept"

fresh; : > "$W/$RECORD"; run
check "the record empty -> rc 2" "$RC" "2"
has "  an empty record must not read as a tree with nothing in it" "$OUT" "is empty"

fresh; chmod 000 "$W/$RECORD"; run
check "the record unreadable -> rc 2" "$RC" "2"
chmod 644 "$W/$RECORD"

fresh; printf 'method\tnot-a-sha\tdocs/workflow.md\n' > "$W/$RECORD"; run
check "a malformed row -> rc 2" "$RC" "2"
has "  the row is quoted rather than skipped" "$OUT" "is not a"

# THE UNRECOVERABLE BLOB, and the pair that makes the degrade rule a measured
# fact. The ordinary verification cannot report what a statement said before if
# the object is gone, so it is a cannot-run; the acceptance run needs no previous
# text, so it completes and clears the state. Without that asymmetry the single
# entry point reads the cannot-run as a failure, nothing commits, and the
# documented escape is the thing being blocked.
fresh
python3 - "$W/$RECORD" <<'PY'
import sys
path = sys.argv[1]
rows = open(path, encoding='utf-8').read().split('\n')
hit = 0
for i, r in enumerate(rows):
    if r.endswith('\tdocs/workflow.md'):
        c = r.split('\t')
        rows[i] = '%s\t%s\t%s' % (c[0], '0' * 40, c[2])
        hit += 1
if not hit:
    sys.exit('no row for docs/workflow.md, so this leg would measure nothing')
open(path, 'w', encoding='utf-8').write('\n'.join(rows))
PY
run
check "a row naming an object the repository cannot produce -> rc 2" "$RC" "2"
has "  naming the row rather than treating absent text as a whole-file departure" \
    "$OUT" "cannot produce it"
accept
check "  and an acceptance run over the SAME tree completes" "$RC" "0"
has "  reporting the row as having no previous text available" "$OUT" "previous text unavailable"
run
check "  after which the ordinary verification is clean again" "$RC" "0"

printf '\n== the three files it reads for data, each asserted its own way ==\n'
# Two different shapes, because the files differ by design. Both payload
# siblings are on the verification surface, so they ARE corpus and take the
# corpus test. The record has no surface by design, so corpus membership is a
# test it could never pass and it takes the INDEX test instead. An untracked
# file of either kind reads green here and leaves every other clone on a
# cannot-run.
fresh; git -C "$W" rm --cached -q scripts/check-plan-invariants.py; run
check "the payload left out of the tracked corpus -> rc 2" "$RC" "2"
has "  named as read for its data but never compared" \
    "$OUT" "scripts/check-plan-invariants.py is read for its data but the tracked corpus does not carry it"

fresh; git -C "$W" rm --cached -q scripts/check-plan-invariants-refusal.py; run
check "the second payload sibling left out of the tracked corpus -> rc 2" "$RC" "2"
has "  named as read for its data but never compared" \
    "$OUT" "scripts/check-plan-invariants-refusal.py is read for its data but the tracked corpus does not carry it"

fresh; git -C "$W" rm --cached -q "$RECORD"; run
check "the record left out of the index -> rc 2" "$RC" "2"
has "  named as a file no other clone has" "$OUT" "is not in the index"

printf '\n== both payload siblings parse, so a gate the single entry point runs does parse them ==\n'
# Neither the syntax member nor the untracked member of the pre-commit list
# globs anything but `*.sh`, so nothing else in that list reads either file as
# code at all.
python3 -c "import ast,sys; ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$PAYLOAD"
check "the payload is syntactically valid Python" "$?" "0"
python3 -c "import ast,sys; ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$REFUSAL"
check "the second payload sibling is syntactically valid Python" "$?" "0"

printf '\n== the load guard: a sibling that cannot be loaded is a CANNOT-RUN, never findings ==\n'
# THE LEG THAT MAKES THE SPLIT DEFENSIBLE. The design chose a single payload
# because a sibling that exists but cannot be loaded reports as FINDINGS rather
# than as a cannot-run: uncaught, `FileNotFoundError` and `SyntaxError` come out
# of `exec_module` and exit 1, which IS the findings code, so a check that could
# not load half of itself would read as a check that found problems. Measured on
# the two-sibling variant that shipped earlier in this task: a loader guarding
# `spec_from_file_location` for a `None` spec or a `None` loader caught NEITHER
# case, both tests false across all three probes.
#
# EACH LEG ASSERTS rc 2 AND, SEPARATELY, NOT rc 1. The second assertion is not
# redundant with the first: a leg that checked only for a non-zero exit would
# have passed against the exact defect above, which is why the distinction is
# spelled rather than implied.
not_findings() { if [ "$1" = "1" ]; then printf 'findings'; else printf 'not-findings'; fi; }

fresh
mutant_copy; runm
check "the control: all three files present, the fixture unmutated -> rc 0" "$RC" "0"
hasnt "  so the two legs below cannot pass vacuously" "$OUT" "could not be loaded"

mutant_copy; rm -f "$MUT/check-plan-invariants-refusal.py"; runm
check "the sibling ABSENT -> rc 2" "$RC" "2"
check "  and NOT rc 1, the findings code" "$(not_findings "$RC")" "not-findings"
has "  caught by the entry point, before python3 starts" "$OUT" "does not exist, so the leg it carries would never run"

# The case no shell test can see, which is why the loader exists at all.
mutant_copy; printf '\ndef (\n' >> "$MUT/check-plan-invariants-refusal.py"; runm
check "the sibling UNPARSEABLE -> rc 2" "$RC" "2"
check "  and NOT rc 1, the findings code" "$(not_findings "$RC")" "not-findings"
has "  caught by the loader, naming the sibling and the exception" "$OUT" "SyntaxError"
has "  and saying the leg never ran" "$OUT" "so the leg it carries never ran"

printf '\n== usage ==\n'
bash "$CHECK" --root /nonexistent >/dev/null 2>&1; check "a root that does not exist -> 2" "$?" "2"
bash "$CHECK" --nonsense        >/dev/null 2>&1; check "an unknown flag -> 2"            "$?" "2"
bash "$CHECK" --root            >/dev/null 2>&1; check "a valueless --root -> 2"         "$?" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
