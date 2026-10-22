#!/usr/bin/env bash
#
# Tests for check-plan-invariants.sh -- the verification that the base
# principles of a spec and a design are intact, that nothing has added a
# required element, and that the edit-time refusal still covers the pages that
# define one.
#
# Run: bash scripts/test-check-plan-invariants.sh
#
# WHY THESE LEGS. Every characteristic failure of a detector is a FALSE GREEN,
# so no leg here asserts "rc 1 on a mutated tree" and stops. Each plants one
# defect whose correct answer is known independently and asserts WHICH
# principle, element or page the finding names: an rc-only assertion is
# satisfied by a check that reddens on everything, which is the same thing as a
# check that measures nothing.
#
# THE FIXTURE IS A COPY OF THE TRACKED TREE, STAGED. Both steps are
# load-bearing. The check takes its corpus from the git INDEX while reading
# seven files DIRECTLY for their data, so a file that is present but unstaged is
# read for data and never swept -- and the sweep then reports a clean run over a
# corpus that does not contain the planted defect. That happened once on the
# real tree, with the one page this check exists to protect left out of its own
# corpus, so the first leg below is a positive control on the fixture itself.
#
# EVERY MUTATION IS POSITIVE-CONTROLLED, and that is measured rather than
# defensive: two mutations of the principles document matched nothing -- the
# document hard-wraps and the sentence being replaced did not -- and both legs
# went GREEN over an unmutated tree. `tweak` and `mutant` now report how many
# sites they changed and fail the leg at zero.
#
# EACH LEG STANDS ON ITS OWN ANSWER rather than on the tree having been mutated
# at all. A planted defect the targeted leg does not see leaves the verdict
# clean, so every leg below asserts WHICH finding it got and not only that the
# run reddened.
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
}

MUT="$T/mutant"
fresh() { rm -rf "$W"; cp -R "$BASE" "$W"; }
run()   { OUT=$(bash "$CHECK" --root "$W" 2>&1); RC=$?; }
runm()  { OUT=$(bash "$MUT/check-plan-invariants.sh" --root "$W" 2>&1); RC=$?; }

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

# EVERY ELEMENT-SHAPED TOKEN BELOW IS ASSEMBLED, never spelled. A token spelled
# literally here is a token this file carries in the very corpus the check
# sweeps. The per-page locus sweep skips every `test-*.sh`, so nothing reads one
# today -- and the assembly is what keeps that exclusion from being the only
# thing between this suite and its own subject matter.
H='##'
ARRIVED="$H Rollout ledger"
LATE="$H Per-test line numbers"
ENUM_ELEM="$H Risks"

printf '\n== the fixture: the tracked tree, copied and STAGED ==\n'
build_base
INDEX=$(git -C "$BASE" ls-files)
for p in docs/plan-invariants.md hooks/lib/plan-invariants-guard.sh agents/spec-writer.md \
         agents/design.md agents/design-review.md scripts/check-redline.sh hooks/hooks.json \
         scripts/check-plan-invariants.py; do
  has "the index carries $p, so its own text is swept and not merely read" "$INDEX" "$p"
done

printf '\n== the clean case, and the figures a narrowed run cannot fake ==\n'
fresh; run
check "an unmutated copy of the tree -> rc 0" "$RC" "0"
has "  the verdict says clean rather than silent" "$OUT" "check-plan-invariants: clean"
has "  every principle counted"                   "$OUT" "principles=10"
BASE_PAGES=$(figure pages)
BASE_ELEM=$(figure elements)
gt "  the corpus is the method surface, not a handful of files" "$BASE_PAGES" "100"
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
# alone, the mutant would load the real payload from the real directory, report
# the finding anyway, and fail the clean verdict asserted here. The verdict and
# the principle count are asserted beside the silence, because an empty result
# is what a mutant that never ran produces.
mutant 'if norm(got) != norm(want):' 'if False and norm(got) != norm(want):'
runm
check "  with the wording arm taken away the mutant has nothing left to report -> rc 0" "$RC" "0"
has "  while still reaching a verdict of its own" "$OUT" "check-plan-invariants: clean"
has "  over the whole corpus, so the silence is not a narrowed run" "$OUT" "principles=10"
hasnt "  and it reports no wording finding" "$OUT" "finding leg1-wording: principle 5"

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
has "  and the verdict's own count drops" "$OUT" "principles=9"

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
                                       or p in ('.gitignore', 'README.md',
                                                'ai-docs/fixtures/positional-references.baseline',
                                                'ai-docs/fixtures/plan-convergence-planted.md')),
}
none, many = [], []
for p in tracked:
    if surfaced(p):
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

printf '\n== leg 2: an element arriving, by each route that can make one required ==\n'
fresh
tweak agents/design.md '^## Use cases$' "$LATE\\n## Use cases"
run
check "the design template gains an element -> rc 1" "$RC" "1"
has "  named with the document it was mandated of" \
    "$OUT" "finding leg2-arrival: a page mandates the design element \`$LATE\`"
has "  and reported as an arrival" "$OUT" "an element has ARRIVED"

fresh
tweak agents/design-review.md '^   - \*\*Risks\*\* —' \
  "   - **Rollout** — a design missing \`$ARRIVED\` = \`major\`.\\n   - **Risks** —"
run
check "an element made mandatory by a blocking-absence rule alone -> rc 1" "$RC" "1"
has "  reported as an addition, with no template altered anywhere" \
    "$OUT" "finding leg2-arrival: a page mandates the design element \`$ARRIVED\`"

fresh
tweak agents/design.md '^## Risks$' "$ARRIVED"
run
check "one required element replaced by another -> rc 1" "$RC" "1"
has "  the arrival is named"   "$OUT" "finding leg2-arrival: a page mandates the design element \`$ARRIVED\`"
has "  the departure is named" "$OUT" "finding leg2-departure: the record in docs/plan-invariants.md carries the design element \`$ENUM_ELEM\`"
check "  while the element COUNT is exactly what it was, so only a set comparison sees it" \
      "$(figure elements)" "$BASE_ELEM"

fresh
tweak scripts/check-redline.sh "\^## Open questions'" "^## Open questions|^$ARRIVED'"
run
check "the fold's removal list widened -> rc 1" "$RC" "1"
has "  reported as a prohibition arriving rather than joining the element set" \
    "$OUT" "finding leg2-prohibition: the fold is now required to REMOVE \`$ARRIVED\`"

printf '\n== leg 3: the refusal against the table, in both directions ==\n'
fresh
tweak hooks/lib/plan-invariants-guard.sh '^skills/task/reference.md\n' ''
run
check "a table member the refusal stopped covering -> rc 1" "$RC" "1"
has "  the uncovered page is named as an unguarded route" \
    "$OUT" "finding leg3-uncovered: the protected-page table names skills/task/reference.md"

# The direction the set comparison cannot see: drop the page from the table as
# well and the two agree, while the page still carries the locus that put it
# there. Only the per-page locus test reports that.
fresh
tweak hooks/lib/plan-invariants-guard.sh '^skills/task/reference.md\n' ''
tweak docs/plan-invariants.md '^\| `\$\{CLAUDE_PLUGIN_ROOT\}/skills/task/reference\.md`[^\n]*\n' ''
run
check "that page dropped from the guard AND the table -> rc 1" "$RC" "1"
has "  the locus it still carries is what reports it" \
    "$OUT" "finding leg3-unguarded: skills/task/reference.md carries an element-defining locus"
hasnt "  and the two sets agree, so the comparison says nothing" \
    "$OUT" "finding leg3-uncovered: the protected-page table names skills/task/reference.md"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" \
  "scripts/check-redline.sh\ndocs/considerations-link-reading.md'"
tweak docs/plan-invariants.md '\| `\$\{CLAUDE_PLUGIN_ROOT\}/scripts/check-redline.sh` \| Carries the retained' \
  '| `${CLAUDE_PLUGIN_ROOT}/docs/considerations-link-reading.md` | Added by hand, defining nothing |\n| `${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh` | Carries the retained'
run
check "a page covered AND tabled that defines no element -> rc 1" "$RC" "1"
has "  reported as a surplus interruption, which the set comparison agrees about" \
    "$OUT" "finding leg3-no-locus: docs/considerations-link-reading.md is in the protected-page table"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" "scripts/check-redline.sh\ndocs/workflow.md'"
run
check "the refusal widened past the table -> rc 1" "$RC" "1"
has "  every surplus member is named, because each one is a recurring interruption" \
    "$OUT" "finding leg3-surplus: the refusal covers docs/workflow.md"

fresh
tweak hooks/hooks.json 'hooks/lib/plan-invariants-guard\.sh' 'hooks/lib/not-registered.sh'
run
check "the refusal unregistered -> rc 1" "$RC" "1"
has "  its page list is not coverage, on the editing matcher" \
    "$OUT" "finding leg3-registration: the refusal is not registered on the Edit|Write matcher"
has "  nor on the shell matcher" \
    "$OUT" "finding leg3-registration: the refusal is not registered on the Bash matcher"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" "scripts/check-redline.sh\nagents/self-review.md'"
run
check "a documented near miss that the refusal covers anyway -> rc 1" "$RC" "1"
has "  the near-miss control reports it" \
    "$OUT" "finding leg3-near-miss: agents/self-review.md is documented as a deliberate near miss"
has "  and the set comparison reports it too, while they still disagree" \
    "$OUT" "finding leg3-surplus: the refusal covers agents/self-review.md"

fresh
tweak hooks/lib/plan-invariants-guard.sh "scripts/check-redline.sh'" "scripts/check-redline.sh\nagents/self-review.md'"
tweak docs/plan-invariants.md '\| `\$\{CLAUDE_PLUGIN_ROOT\}/scripts/check-redline.sh` \| Carries the retained' \
  '| `${CLAUDE_PLUGIN_ROOT}/agents/self-review.md` | Added by hand, and still a documented near miss |\n| `${CLAUDE_PLUGIN_ROOT}/scripts/check-redline.sh` | Carries the retained'
run
check "that near miss added to the guard AND the table -> rc 1" "$RC" "1"
has "  the page set is reported as contradicting itself" \
    "$OUT" "finding leg3-near-miss: agents/self-review.md is in BOTH the protected-page table and the near-miss table"
hasnt "  which the covered-versus-table comparison cannot see, because both of those now agree" \
    "$OUT" "finding leg3-surplus: the refusal covers agents/self-review.md"

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

# A page leaving the index is a clean run over a narrower corpus, and the page
# figure beside the verdict is the only thing that moves. Nothing the three legs
# answer changes its verdict, because each of them reports an identity rather
# than a text difference -- so this leg is what makes that figure load-bearing.
fresh
git -C "$W" rm --cached -q docs/workflow.md
run
check "a page dropped from the corpus -> rc 0, with no leg reporting it" "$RC" "0"
check "  and the page count in the verdict is the only signal" "$(figure pages)" "$((BASE_PAGES - 1))"

mkdir -p "$T/bare"; git -C "$T/bare" init -q
OUT=$(bash "$CHECK" --root "$T/bare" 2>&1); RC=$?
check "a tree with no tracked file at all -> rc 2" "$RC" "2"
has "  an empty corpus must not read as a clean sweep" "$OUT" "the detection corpus came back empty"

printf '\n== a surface not examined is not a surface examined and clean ==\n'
# An unreadable corpus file is a run that examined fewer files than the corpus
# holds, which is this approach's own false green, so it is a cannot-run
# rather than a completed run with a quieter roster. The roster still prints,
# because that is what tells a surface not examined apart from one examined and
# found clean -- and a cannot-run is exactly the outcome where the distinction
# is live.
fresh
chmod 000 "$W/docs/considerations-link-reading.md"
run
check "one page of an examined surface unreadable -> rc 2" "$RC" "2"
has "  reported as a run that could not complete" "$OUT" "CANNOT RUN -- which is not a pass"
has "  naming the file that was never swept" \
    "$OUT" "cannot run: docs/considerations-link-reading.md is in the corpus and could not be read"
has "  the surface is reported as NOT examined, on the cannot-run path" \
    "$OUT" "surface method       not-examined"
hasnt "  so it is not counted among the examined-clean" "$OUT" "surface method       examined-clean"
has "  while the surfaces that were read still report cleanly" "$OUT" "surface profile      examined-clean"
chmod 644 "$W/docs/considerations-link-reading.md"

printf '\n== a surface WITH findings is not a surface examined and clean either ==\n'
# THE THIRD ROSTER STATE, and the one that shipped broken. A leg computed the
# surface its finding belonged to and then called `finding` with two arguments,
# so no finding of that leg ever reached the red set and the surface carrying
# every finding of the run read as examined-clean. The verdict and the exit code
# were both right, which is what kept it invisible -- an rc-only leg could never
# have seen it.
#
# All three parts are needed. The firing direction alone is satisfied by a
# roster that reddens everything, so the four surfaces carrying no finding in
# the SAME run are asserted clean beside it; and the mutant is what makes the
# pair falsifiable.
fresh
tweak docs/plan-invariants.md 'nothing is recorded in\s+both places' 'nothing is recorded in either place'
run
check "one principle reworded on a method page -> rc 1" "$RC" "1"
check "  exactly ONE finding, so every other surface's silence is about this one" \
      "$(printf '%s\n' "$OUT" | grep -c '^finding ')" "1"
has "  the finding names which principle differs" \
    "$OUT" "finding leg1-wording: principle 5"
has "  and the ROSTER reports the surface that page is on as examined-with-findings" \
    "$OUT" "surface method       examined-with-findings"
hasnt "  so it is not counted among the examined-clean" "$OUT" "surface method       examined-clean"
has "  the profile surface, which carries no finding here, is still clean" \
    "$OUT" "surface profile      examined-clean"
has "  and so is scaffolding"  "$OUT" "surface scaffolding  examined-clean"
has "  and enforcement"        "$OUT" "surface enforcement  examined-clean"
has "  and verification"       "$OUT" "surface verification examined-clean"

# The mutant takes back the one argument the call site passes, leaving the
# surface still computed -- which is exactly why the omission read as correct at
# a glance. It must still redden and still name the finding, because an empty
# result is what a mutant that never ran produces.
mutant '% (idx, lead, norm(want), norm(got)), surface_of(PRINCIPLES_DOC))' \
       '% (idx, lead, norm(want), norm(got)))'
runm
check "  a mutant that computes the surface but does not PASS it -> still rc 1" "$RC" "1"
has "  still reporting the finding, so its silence is about the roster alone" \
    "$OUT" "finding leg1-wording: principle 5"
has "  while the roster calls the surface carrying it examined-clean" \
    "$OUT" "surface method       examined-clean"
hasnt "  which is the false clean claim this leg exists to catch" \
    "$OUT" "surface method       examined-with-findings"

printf '\n== both payload siblings are corpus, and an untracked one narrows the sweep ==\n'
# Both siblings are on the verification surface, so they ARE corpus and take the
# corpus test. One left out of the index is never swept, so the run's green
# would be a statement about a narrower input set than the one reported, and
# every other clone would be on a cannot-run.
fresh; git -C "$W" rm --cached -q scripts/check-plan-invariants.py; run
check "the payload left out of the tracked corpus -> rc 2" "$RC" "2"
has "  named as read for its data but never swept" \
    "$OUT" "scripts/check-plan-invariants.py is read for its data but the tracked corpus does not carry it"

fresh; git -C "$W" rm --cached -q scripts/check-plan-invariants-refusal.py; run
check "the second payload sibling left out of the tracked corpus -> rc 2" "$RC" "2"
has "  named as read for its data but never swept" \
    "$OUT" "scripts/check-plan-invariants-refusal.py is read for its data but the tracked corpus does not carry it"

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
