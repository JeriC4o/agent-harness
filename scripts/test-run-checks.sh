#!/usr/bin/env bash
#
# Tests for run-checks.sh -- the single entry point for this repository's
# pre-commit gate list.
#
# Run: bash scripts/test-run-checks.sh
#
# WHY THESE LEGS. The runner's whole job is to run every member of the gate
# list and report a verdict per member, so each of its characteristic failures
# is a FALSE GREEN:
#
#   - a member fails and the runner still exits 0 -- the `for` loop that exits
#     with the LAST iteration's status, the exact hazard AGENTS.md check 4
#     records against three other spellings of the same gate;
#   - a member never ran, because its file is missing or because it is present
#     but untracked, and absence was read as success;
#   - the member LIST narrowed silently: a suite was added to the tree while the
#     runner derived from something stale, so the gate stopped covering it
#     without ever going red.
#
# So no leg here asserts "rc 0 on a clean tree" and stops. Each plants a defect
# whose correct answer is known independently and asserts BOTH the exit status
# AND which member is named: an rc-only assertion is satisfied by a runner that
# reddens on every member for an unrelated reason.
#
# THE FAKE TREE. Legs run against throwaway git repositories with stub members,
# never against this repository. Two hard constraints, not a preference: the
# real list takes ~290 s (one suite is ~240 s of it), and THIS FILE is itself a
# member of the real list, so executing the real list from inside it recurses.
# Only --list, which derives and checks but executes nothing, is ever pointed at
# the real root.

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
RUNNER="${HERE}/run-checks.sh"
ROOT=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3] in output" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 -- did not expect [$3] in output" ;; *) ok "$1" ;; esac; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM

run() { OUT=$(bash "$RUNNER" --root "$1" 2>&1); RC=$?; }

# Paths are staged explicitly because `git ls-files` reads the INDEX: staging is
# what makes a file visible to the runner at all, and no commit is needed, which
# also keeps every leg independent of git identity config.
make_tree() {
  local d=$1
  rm -rf "$d"; mkdir -p "$d/scripts" "$d/hooks/lib" "$d/.claude-plugin"
  printf '{}\n' > "$d/hooks/hooks.json"
  printf '{"name":"harness","version":"0.0.1"}\n' > "$d/.claude-plugin/plugin.json"
  printf '{"name":"agent-harness"}\n' > "$d/.claude-plugin/marketplace.json"
  local s
  for s in check-references check-readme-update check-propagation-arms check-release; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/scripts/$s.sh"
  done
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/scripts/test-alpha.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/hooks/lib/test-beta.sh"
  cat > "$d/AGENTS.md" <<'AGENTS_EOF'
## Build & Test

**Structural checks that stand in for a test suite** — run all of them:

1. `jq -e .` on every manifest.
2. `bash scripts/check-references.sh` — links resolve.
4. `bash -n` on every `*.sh`.
   Then every test suite green:
   `scripts/test-alpha.sh`, `hooks/lib/test-beta.sh`.
5. `bash scripts/check-readme-update.sh` — the README gate.
5a. `bash scripts/check-propagation-arms.sh` — the arms gate.

**Delivery gates** — below this heading, so the span must not reach them:
`bash scripts/check-release.sh`.
AGENTS_EOF
  git -C "$d" init -q
  git -C "$d" add AGENTS.md scripts hooks .claude-plugin
}

FAKE="$T/fake"

printf '\n== a clean tree: every member runs, and says so ==\n'
make_tree "$FAKE"
run "$FAKE"
check "clean tree -> rc 0" "$RC" "0"
has "  the manifests member reported"   "$OUT" "ok   manifests"
has "  the references member reported"  "$OUT" "ok   references"
has "  the shell-syntax member reported" "$OUT" "ok   shell-syntax"
has "  the readme member reported"      "$OUT" "ok   readme-update"
has "  the propagation member reported" "$OUT" "ok   propagation-arms"
has "  the inventory member reported"   "$OUT" "ok   gate-inventory"
has "  the first derived suite ran"     "$OUT" "ok   hooks/lib/test-beta.sh"
has "  the second derived suite ran"    "$OUT" "ok   scripts/test-alpha.sh"
# The count is the anti-narrowing assertion AGENTS.md check 4 demands: four
# structural stubs plus two stub suites are tracked, and a runner that processed
# fewer has silently reduced its own input set while exiting 0.
has "  and shell-syntax carries its file COUNT" "$OUT" "6 files"

printf '\n== a failing suite: red, named, and the rest still run ==\n'
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAKE/scripts/test-alpha.sh"
run "$FAKE"
check "a suite exiting 1 -> rc 1" "$RC" "1"
has "  the failing suite is named"  "$OUT" "FAIL scripts/test-alpha.sh"
# The loop-status hazard, asserted positively: a runner that stopped at the
# first failure, or that kept only the last member's status, cannot show this.
has "  a LATER member still ran"    "$OUT" "ok   hooks/lib/test-beta.sh"
has "  and the summary counts it"   "$OUT" "1 failed"

printf '\n== a suite failing LAST does not get its status overwritten ==\n'
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAKE/hooks/lib/test-beta.sh"
run "$FAKE"
check "the last-but-one member failing -> rc 1" "$RC" "1"
has "  it is named"                 "$OUT" "FAIL hooks/lib/test-beta.sh"
has "  and an earlier member passed" "$OUT" "ok   scripts/test-alpha.sh"

printf '\n== a tracked shell file that does not parse ==\n'
# This is the leg that proves the runner uses a form which PROPAGATES the
# failure. Three natural spellings of this gate report success here.
#
# The fixture is an unterminated `if`, and that spelling is load-bearing: the
# first draft of this leg planted `if [ 1 = 1 ; then echo no; fi`, which `bash
# -n` accepts (rc 0) because an unclosed `[` is a RUNTIME failure of the `[`
# command, not a parse error. The leg passed against a runner that could not
# have caught anything. So the plant is verified below rather than assumed: a
# defect nobody confirmed is a green that measures nothing.
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nif true; then\n  echo unterminated\n' > "$FAKE/scripts/broken.sh"
if bash -n "$FAKE/scripts/broken.sh" 2>/dev/null; then
  bad "the planted defect does not actually fail bash -n"
else
  ok "the planted defect fails bash -n on its own"
fi
git -C "$FAKE" add scripts/broken.sh
run "$FAKE"
check "a syntax error -> rc 1" "$RC" "1"
has "  the shell-syntax member is red" "$OUT" "FAIL shell-syntax"

printf '\n== a shell file present but UNTRACKED ==\n'
# `git ls-files` lists tracked files only, so an unstaged script is invisible to
# the syntax gate. Staying quiet about it is how the gate narrows itself on
# exactly the task that adds scripts.
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE/scripts/test-gamma.sh"
run "$FAKE"
check "an untracked suite -> rc 1" "$RC" "1"
has "  the untracked member is red" "$OUT" "FAIL untracked-shell"
has "  and the file is named"       "$OUT" "scripts/test-gamma.sh"

printf '\n== a member whose file is missing ==\n'
make_tree "$FAKE"
rm -f "$FAKE/scripts/check-readme-update.sh"
git -C "$FAKE" rm -q --cached scripts/check-readme-update.sh
run "$FAKE"
check "a missing member -> rc 1, never 0" "$RC" "1"
has "  it is reported missing, not passed" "$OUT" "MISSING readme-update"

printf '\n== a structural member that fails ==\n'
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAKE/scripts/check-references.sh"
run "$FAKE"
check "the references gate failing -> rc 1" "$RC" "1"
has "  it is named"                  "$OUT" "FAIL references"
has "  and later members still ran"  "$OUT" "ok   propagation-arms"

printf '\n== drift between the tree and the documented list ==\n'
# The inventory member is the one check here that no link check, syntax check or
# suite can see: a list and the tree beside it disagreeing.
make_tree "$FAKE"
sed 's|, `hooks/lib/test-beta.sh`||' "$FAKE/AGENTS.md" > "$FAKE/AGENTS.md.new"
mv "$FAKE/AGENTS.md.new" "$FAKE/AGENTS.md"
run "$FAKE"
check "a suite in the tree the rules do not name -> rc 1" "$RC" "1"
has "  the inventory member is red" "$OUT" "FAIL gate-inventory"
has "  and the unnamed suite is named" "$OUT" "hooks/lib/test-beta.sh"

make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE/scripts/test-alpha.sh"
rm -f "$FAKE/hooks/lib/test-beta.sh"
git -C "$FAKE" rm -q --cached hooks/lib/test-beta.sh
run "$FAKE"
check "a suite the rules name but the tree lacks -> rc 1" "$RC" "1"
has "  the inventory member is red" "$OUT" "FAIL gate-inventory"
has "  and the phantom suite is named" "$OUT" "hooks/lib/test-beta.sh"

make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE/scripts/check-newthing.sh"
git -C "$FAKE" add scripts/check-newthing.sh
run "$FAKE"
check "a new check-*.sh that is neither member nor exempt -> rc 1" "$RC" "1"
has "  the inventory member is red" "$OUT" "FAIL gate-inventory"
has "  and it is named"             "$OUT" "scripts/check-newthing.sh"

make_tree "$FAKE"
grep -v 'Then every test suite green:' "$FAKE/AGENTS.md" > "$FAKE/AGENTS.md.new"
mv "$FAKE/AGENTS.md.new" "$FAKE/AGENTS.md"
run "$FAKE"
check "the documented list gone entirely -> rc 1" "$RC" "1"
has "  not treated as an empty-and-therefore-matching list" "$OUT" "FAIL gate-inventory"

printf '\n== the delivery gate stays exempt, asserted positively ==\n'
# This leg is reachable rather than vacuous -- un-exempting check-release.sh
# turns it red -- but note WHICH direction it covers: it fires because the
# inventory's finding text names the file, so it catches the exemption list
# NARROWING. A list that widens to swallow a real member is behaviourally
# inert here and no leg can see it; that is a known gap, not a covered one.
make_tree "$FAKE"
run "$FAKE"
check "an unmutated tree is clean" "$RC" "0"
hasnt "  and the delivery gate was not run as a member" "$OUT" "check-release"

printf '\n== cannot run is not a pass ==\n'
# A thin PATH, built from a named tool list, is the only way to make a tool
# genuinely absent. The control leg below is what makes the jq leg mean
# anything: without it, rc 2 could be the thin PATH breaking something else.
BIN="$T/thin-bin"; mkdir -p "$BIN"
for b in bash git sed grep sort uniq comm mktemp rm cat dirname xargs tr wc env awk head; do
  p=$(command -v "$b") && case "$p" in /*) ln -s "$p" "$BIN/$b" ;; esac
done
make_tree "$FAKE"
jq_path=$(command -v jq) && ln -s "$jq_path" "$BIN/jq"
ctl=$(env -i PATH="$BIN" HOME="$HOME" bash "$RUNNER" --root "$FAKE" 2>&1); ctl_rc=$?
check "control: the thin PATH itself reaches a verdict" "$ctl_rc" "0"
rm -f "$BIN/jq"
nojq=$(env -i PATH="$BIN" HOME="$HOME" bash "$RUNNER" --root "$FAKE" 2>&1); nojq_rc=$?
check "jq absent -> 2, not a pass" "$nojq_rc" "2"
has "  and it names what is missing" "$nojq" "jq"

# The inventory member's own machinery, which is the part that went wrong once:
# `mktemp` was used there and absent from the runner's required-tool list, so on
# a machine without it the member returned empty -- and empty is how the runner
# spells agreement. It reported ok and the whole run exited 0 over a tree that
# had really drifted. The comparison no longer needs mktemp, and this leg pins
# the general property: a tool the inventory depends on, taken away, must reach
# rc 2 rather than a green verdict.
ln -s "$jq_path" "$BIN/jq"
rm -f "$BIN/comm"
nocomm=$(env -i PATH="$BIN" HOME="$HOME" bash "$RUNNER" --root "$FAKE" 2>&1); nocomm_rc=$?
check "comm absent -> 2, not a green inventory" "$nocomm_rc" "2"
has "  and it names what is missing" "$nocomm" "comm"
hasnt "  and no member reported a verdict" "$nocomm" "ok   gate-inventory"

printf '\n== the required-tool list covers every tool the body invokes ==\n'
# The mktemp defect was a LIST drifting from the code beside it, so the check is
# the same shape as gate-inventory itself: derive what the body uses, compare it
# against what the preflight demands. Comment lines are stripped first -- a tool
# named in prose is not an invocation.
body=$(grep -v '^[[:space:]]*#' "$RUNNER")
required=$(printf '%s\n' "$body" | sed -n 's/^for t in \(.*\); do$/\1/p')
# The declaration line is REMOVED from the text the invocations are derived
# from. Leaving it in put every required tool into `used` by construction, so
# the containment check could not fail on a required tool and the positive
# control below could not tell "found real invocations" from "found the
# declaration". With it stripped, the derivation sees only genuine call sites --
# which is how `dirname`, invoked by the ROOT default and absent from both the
# list and this vocabulary, stayed hidden through a whole review round.
invocations=$(printf '%s\n' "$body" | grep -v '^for t in ')
if [ -z "$required" ]; then
  bad "the required-tool list could not be located, so this leg measures nothing"
else
  ok "the required-tool list is where this leg expects it"
  used=$(printf '%s\n' "$invocations" \
    | grep -owE 'mktemp|comm|sort|sed|grep|tr|wc|xargs|jq|git|uniq|awk|head|tail|cut|date|find|rm|cp|mv|cmp|tee|realpath|dirname|basename|bash|env|chmod|diff' \
    | sort -u)
  unlisted=''
  for tool in $used; do
    listed=0
    for r in $required; do [ "$r" = "$tool" ] && listed=1; done
    [ "$listed" -eq 1 ] || unlisted="${unlisted}${unlisted:+ }$tool"
  done
  check "every invoked tool is demanded up front" "$unlisted" ""
  # Without this, an empty `used` would satisfy the line above while measuring
  # nothing -- the same vacuous-green shape this file exists to refuse. It is a
  # real control only because the declaration line was stripped above: `dirname`
  # is reachable ONLY from a call site, so requiring it here proves the
  # derivation read call sites rather than the list it is compared against.
  case "$used" in *dirname*) ok "  and the derivation read call sites, not the list" ;;
                  *) bad "  the tool derivation did not reach the ROOT default's dirname" ;; esac
fi

# The legs below run a MUTATED COPY of the runner, because expressing these
# defects needs a source edit -- which is also why their severity is lower than
# an environment-triggered one. Note which line each mutation targets: the
# FIRST member sits on the `MEMBERS='` line, so a pattern anchored at `^manifests`
# matches nothing. Two earlier attempts died there, mine and the reviewer's, and
# the apply-proof below is what turned both into a red leg instead of a green one.
MUT="$T/mutant.sh"

# Apply-proof, and the reason it is this strict: the first version of these legs
# used `|` as sed's delimiter inside a pattern that contains `|`, so sed errored
# and wrote a truncated file -- and a guard that only asked "does the output
# differ from the original?" called that a successfully applied mutation. The
# proof has to be of the INTENDED change: the new text present in the mutant,
# absent from the original, and the mutant still parsing.
mutate_runner() {
  local why changed
  why=$(sed "s#^$2\$#$3#" "$RUNNER" 2>&1 >"$1")
  [ -z "$why" ] || { printf '       sed said: %s\n' "$why"; return 1; }
  grep -qF "$3" "$1" || return 1
  grep -qF "$3" "$RUNNER" && return 1
  bash -n "$1" || return 1
  # A one-line substitution changes exactly one line, which diff reports as one
  # removal plus one addition. Without this clause a mutant that lands the new
  # text and then loses its tail at a statement boundary satisfies every other
  # clause -- `bash -n` is happy with a truncated-but-valid script.
  changed=$(diff "$RUNNER" "$1" | grep -c '^[<>]')
  [ "$changed" = "2" ] || { printf '       %s lines changed, expected 2\n' "$changed"; return 1; }
  return 0
}

printf '\n== the dispatch refuses an entry it cannot run ==\n'
if mutate_runner "$MUT" 'gate-inventory|fn:inventory_member' 'gate-inventory|fn:no_such_function'; then
  ok "the missing-function mutation applied and the mutant parses"
  make_tree "$FAKE"
  OUT=$(bash "$MUT" --root "$FAKE" 2>&1); RC=$?
  check "a member naming a function that does not exist -> rc 1" "$RC" "1"
  has "  and the member is named, not skipped" "$OUT" "no_such_function"
else
  bad "the missing-function mutation did not apply, so its leg would measure nothing"
fi

# The predicate matters here, not just the arm: `command -v` resolves external
# commands, so `fn:true` passed the earlier check, ran `true`, printed no
# verdict line at all, and the run exited 0 one member short of its own list.
# `declare -F` is the discriminating one -- verified under bash 3.2 directly:
# `true` and `ls` answer yes to `command -v` and no to `declare -F`.
if mutate_runner "$MUT" 'untracked-shell|fn:untracked_member' 'untracked-shell|fn:true'; then
  ok "the external-command mutation applied and the mutant parses"
  make_tree "$FAKE"
  OUT=$(bash "$MUT" --root "$FAKE" 2>&1); RC=$?
  check "a member naming an external command, not a function -> rc 1" "$RC" "1"
  has "  and it is named rather than silently skipped" "$OUT" "untracked-shell"
else
  bad "the external-command mutation did not apply, so its leg would measure nothing"
fi

if mutate_runner "$MUT" 'shell-syntax|fn:syntax_member' 'shell-syntax|xx:syntax_member'; then
  ok "the unknown-kind mutation applied and the mutant parses"
  make_tree "$FAKE"
  OUT=$(bash "$MUT" --root "$FAKE" 2>&1); RC=$?
  check "a member with a kind the dispatch does not know -> rc 1" "$RC" "1"
  has "  and the kind is named" "$OUT" "xx"
else
  bad "the unknown-kind mutation did not apply, so its leg would measure nothing"
fi

printf '\n== one verdict per member, which the totals cannot show ==\n'
# Repointing a member at ANOTHER member's function: two verdicts under one name,
# none under the other, and both totals unchanged. The counts are blind to it by
# construction, so the check is on the names that reported.
if mutate_runner "$MUT" 'untracked-shell|fn:untracked_member' 'untracked-shell|fn:manifests_member'; then
  ok "the cross-wiring mutation applied and the mutant parses"
  make_tree "$FAKE"
  OUT=$(bash "$MUT" --root "$FAKE" 2>&1); RC=$?
  check "a member wired to another member's function -> rc 1" "$RC" "1"
  has "  the verdict roll-call is what catches it" "$OUT" "FAIL member-verdicts"
  has "  and the silent member is named in the expectation" "$OUT" "untracked-shell"
else
  bad "the cross-wiring mutation did not apply, so its leg would measure nothing"
fi

printf '\n== a structural check can be documented and never wired in ==\n'
# The reverse direction of the suite-list check: AGENTS.md naming a gate the
# runner does not run. Nothing else in the gate set can see that — the script
# exists, parses, and is simply never invoked.
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE/scripts/check-newgate.sh"
git -C "$FAKE" add scripts/check-newgate.sh
sed 's|^5a\. `bash scripts/check-propagation-arms.sh` — the arms gate.|&\n5b. `bash scripts/check-newgate.sh` — a gate nobody runs.|' \
  "$FAKE/AGENTS.md" > "$FAKE/AGENTS.md.new"
mv "$FAKE/AGENTS.md.new" "$FAKE/AGENTS.md"
if grep -q 'check-newgate' "$FAKE/AGENTS.md"; then
  ok "the fixture now documents a gate that is not a member"
else
  bad "the fixture edit did not land, so the leg below measures nothing"
fi
run "$FAKE"
check "a documented structural check that is not a member -> rc 1" "$RC" "1"
has "  and it is named as documented-but-not-wired" "$OUT" "not a runner member: scripts/check-newgate.sh"

make_tree "$FAKE"
grep -v 'check-readme-update.sh` — the README gate' "$FAKE/AGENTS.md" > "$FAKE/AGENTS.md.new"
mv "$FAKE/AGENTS.md.new" "$FAKE/AGENTS.md"
run "$FAKE"
check "a member AGENTS.md stops naming -> rc 1" "$RC" "1"
has "  and the member is named" "$OUT" "does not name as a structural check: scripts/check-readme-update.sh"

make_tree "$FAKE"
grep -v '^\*\*Structural checks' "$FAKE/AGENTS.md" > "$FAKE/AGENTS.md.new"
mv "$FAKE/AGENTS.md.new" "$FAKE/AGENTS.md"
run "$FAKE"
check "the structural heading gone -> rc 1, not an empty-and-matching parse" "$RC" "1"
has "  and the empty parse is named as such" "$OUT" "names no structural check script"

printf '\n== the member table is pinned, because repointing cannot be caught at runtime ==\n'
# What the runtime checks now cover, and what is left. Repointing a member at an
# UNDOCUMENTED script reddens on the documented-checks comparison -- and NOT on
# the stray-script finding, which that same repointing SILENCES: `stray_checks`
# exempts any path that has become a member script, which was the whole content
# of the round-2 finding. The two findings swap, they do not stack, so neither is
# a backstop for the other. Repointing at another member's FUNCTION reddens on
# the verdict roll-call instead. Both cases were silent before those two checks
# existed.
#
# This is the case none of them can see: a member repointed at another script
# that AGENTS.md DOES name as a structural check. Every list still agrees, every
# member name still reports exactly once, and the repointed member's own gate
# simply never runs. The member's NAME is the only thing that says what it was
# supposed to check, so the table itself is pinned below.
# A paired control on ONE tree: it carries an unstaged script, which only the
# untracked member can see. Unmutated, that member reddens. Repointed at a
# documented check, the same tree passes -- so the gate stopped running and
# every list still agrees.
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE/scripts/unstaged-helper.sh"
run "$FAKE"
check "control: the untracked member catches an unstaged script" "$RC" "1"
has "  and it is the untracked member that reddens" "$OUT" "FAIL untracked-shell"
if mutate_runner "$MUT" 'untracked-shell|fn:untracked_member' 'untracked-shell|sh:scripts/check-references.sh'; then
  ok "the documented-target repointing applied and the mutant parses"
  OUT=$(bash "$MUT" --root "$FAKE" 2>&1); RC=$?
  check "the same tree now PASSES — the gate silently stopped running" "$RC" "0"
  has "  and the member name still reports, so only the pin can see it" "$OUT" "ok   untracked-shell"
else
  bad "the documented-target mutation did not apply, so the claim above is unmeasured"
fi

table=$(sed -n "/^MEMBERS='/,/'\$/p" "$RUNNER" | sed "s/^MEMBERS='//; s/'\$//")
expected='manifests|fn:manifests_member
references|sh:scripts/check-references.sh
shell-syntax|fn:syntax_member
untracked-shell|fn:untracked_member
gate-inventory|fn:inventory_member
readme-update|sh:scripts/check-readme-update.sh
propagation-arms|sh:scripts/check-propagation-arms.sh'
check "the member table is exactly the pinned seven, in order" "$table" "$expected"

printf '\n== a module path is accepted, ignored, and SAID to be ignored ==\n'
# AGENTS.md resolves %TEST_CMD% to this runner, and skills invoke that as
# `%TEST_CMD% <module-path>`. Refusing would read as a broken project profile;
# narrowing to the path would be the opt-out this gate refuses to have. The
# third option is the one asserted here, and the "said so" half is the point:
# accepting-and-ignoring in silence is indistinguishable from narrowing.
make_tree "$FAKE"
OUT=$(bash "$RUNNER" --root "$FAKE" skills/ 2>&1); RC=$?
check "a bare module path -> still rc 0" "$RC" "0"
has "  the ignored argument is named" "$OUT" "skills/"
has "  and the whole list still ran"  "$OUT" "ok   hooks/lib/test-beta.sh"
has "  with the derived suite count beside the verdict" "$OUT" "2 suites derived"

# --list took the same path and said nothing at all about it, which is the
# quiet-acceptance the run branch's own comment rules out.
OUT=$(bash "$RUNNER" --root "$FAKE" --list skills/ 2>&1); RC=$?
check "a bare module path with --list -> still rc 0" "$RC" "0"
has "  and --list names the ignored argument too" "$OUT" "skills/"

printf '\n== usage ==\n'
bash "$RUNNER" --root /nonexistent >/dev/null 2>&1; check "missing root -> 2" "$?" "2"
mkdir -p "$T/empty"
bash "$RUNNER" --root "$T/empty" >/dev/null 2>&1; check "a root that is not this repo -> 2" "$?" "2"
bash "$RUNNER" --nonsense >/dev/null 2>&1; check "unknown flag -> 2" "$?" "2"
bash "$RUNNER" --root >/dev/null 2>&1; check "valueless --root -> 2" "$?" "2"

printf '\n== --list derives and checks, and executes nothing ==\n'
make_tree "$FAKE"
list=$(bash "$RUNNER" --root "$FAKE" --list 2>&1); list_rc=$?
check "--list on a clean tree -> 0" "$list_rc" "0"
has "  it prints a derived suite"  "$list" "scripts/test-alpha.sh"
has "  and the structural members" "$list" "manifests"
hasnt "  and it ran nothing"       "$list" "ok   "
# A canary on the stub: if --list ever starts executing, this records it.
make_tree "$FAKE"
printf '#!/usr/bin/env bash\ntouch "%s/ran"\nexit 0\n' "$FAKE" > "$FAKE/scripts/test-alpha.sh"
bash "$RUNNER" --root "$FAKE" --list >/dev/null 2>&1
if [ -e "$FAKE/ran" ]; then bad "--list executed a suite"; else ok "--list executed no suite"; fi
make_tree "$FAKE"
sed 's|, `hooks/lib/test-beta.sh`||' "$FAKE/AGENTS.md" > "$FAKE/AGENTS.md.new"
mv "$FAKE/AGENTS.md.new" "$FAKE/AGENTS.md"
bash "$RUNNER" --root "$FAKE" --list >/dev/null 2>&1
check "--list reddens on drift too" "$?" "1"

# The case that made --list return 0 on the very branch that adds a suite: an
# unstaged file is missing from BOTH sides of the comparison, so the two sides
# agree and nothing is reported. Found by this suite's own real-root leg below.
make_tree "$FAKE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE/scripts/test-delta.sh"
list=$(bash "$RUNNER" --root "$FAKE" --list 2>&1); list_rc=$?
check "--list reddens on an UNTRACKED suite" "$list_rc" "1"
has "  and names it"                 "$list" "scripts/test-delta.sh"

printf '\n== this repository agrees with its own documented list ==\n'
# The real-root leg. --list executes nothing, so this costs nothing and is safe
# to run from inside a file that is itself a member.
real=$(bash "$RUNNER" --list 2>&1); real_rc=$?
check "the live tree and AGENTS.md agree" "$real_rc" "0"
[ "$real_rc" = "0" ] || printf '%s\n' "$real"
has "  the four-minute suite is a member" "$real" "scripts/test-loop-corpus.sh"
has "  this file is a member"             "$real" "scripts/test-run-checks.sh"
has "  and so is the runner's own gate list head" "$real" "manifests"
# Delivery gates run at a different moment (before opening a PR, not before
# every commit) and exit 2 when the claude CLI is absent, which this runner
# would have to translate. They are exempt BY NAME, so assert that.
hasnt "  the install smoke test is not a member" "$real" "test-install-smoke.sh"
hasnt "  the upgrade smoke test is not a member" "$real" "test-upgrade-smoke.sh"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
