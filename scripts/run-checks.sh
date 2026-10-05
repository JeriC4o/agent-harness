#!/usr/bin/env bash
#
# Run this repository's whole pre-commit gate list, one member at a time, and
# report a verdict per member.
#
# Run:  run-checks.sh [--root <dir>] [--list]
# Exit: 0 every member passed
#       1 at least one member failed, is missing, or the list drifted
#       2 cannot run (a required tool absent, a root that is not this repo, a
#         usage error) -- which is NOT a pass
#
# WHY THIS EXISTS. The list in AGENTS.md § Build & Test is ~28 members, and the
# no-masking rule forbids piping a gate, so running the list by hand costs ~28
# bare tool calls. At the late-session context where a review round actually
# happens, the re-read term alone is roughly $0.20 per call -- so a full
# validation ran by hand costs several dollars in nothing but re-reading,
# several times per task. A checked-in script is the one place the rule
# explicitly permits the chain ("any chain inside a hook or checked-in .sh"), so
# the cost collapses to one call without weakening anything.
#
# WHAT IT MUST NOT DO. Every characteristic failure of a runner is a FALSE
# GREEN, so three properties are load-bearing and each has a leg in
# test-run-checks.sh:
#
#   - NO SHORT-CIRCUIT, NO LAST-STATUS. Every member runs, every member's status
#     is kept. A `for` loop over gates exits with the LAST iteration's status,
#     which erases an earlier failure -- the hazard AGENTS.md check 4 records.
#   - THE MEMBER LIST IS DERIVED, NEVER DECLARED. Suites come from the tree
#     (`git ls-files`), so a suite added to the tree is covered the day it lands.
#     A hardcoded list is how a gate stops covering something while staying
#     green -- the same drift check-propagation-arms.sh exists to catch between
#     the hook arms and the propagation table.
#   - ABSENCE IS NEVER SUCCESS. A member whose file is gone is MISSING (red), a
#     tracked-file set of zero is red, an untracked `*.sh` is red because
#     `git ls-files` cannot see it, and a gate that exits 0 having processed
#     fewer files than are tracked is red: a gate that silently narrows its own
#     input set is the quietest false green there is.
#
# NO FLAG NARROWS THE RUN. There is deliberately no --only / --skip: an opt-out
# is the hazard above wearing a convenience's clothes, which is also why the
# four-minute corpus suite ships none. --list derives and checks the list and
# executes nothing, which is a different thing from running part of it.
#
# NOT IN SCOPE: the three delivery gates (install smoke, release check, upgrade
# smoke). They answer "does this reach a consumer", run once before a PR rather
# than before every commit, need the `claude` CLI, and exit 2 when they cannot
# run. Keeping them out means this script's rc 2 has exactly one meaning.

set -uo pipefail

die() { printf '%s\n' "$2" >&2; exit "$1"; }

# Every external tool this script invokes, checked by name BEFORE the first one
# is used: `dirname` is on the list because the ROOT default below calls it, and
# a preflight that ran after its own dependency would be theatre. The list is
# not cosmetic — `mktemp` was once used by the inventory member and missing from
# here, so on a machine without it that member returned empty, which this script
# reads as agreement, and the runner exited 0 over a tree that really had
# drifted. test-run-checks.sh derives the tools the body invokes and requires
# each to appear here, but it reads a CLOSED vocabulary of tool names: that leg
# is a net for the tools it knows, never a proof about every possible command.
for t in bash git jq sed grep sort comm xargs wc tr dirname; do
  command -v "$t" >/dev/null 2>&1 || die 2 "cannot run: $t is not on PATH. A missing tool is not a pass."
done

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
LIST_ONLY=0
IGNORED_ARG=''

while [ $# -gt 0 ]; do
  case $1 in
    --root)
      [ $# -ge 2 ] || die 2 "usage: --root needs a directory"
      [ -d "$2" ] || die 2 "usage: --root: no such directory: $2"
      ROOT=$(cd -- "$2" && pwd); shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die 2 "usage: run-checks.sh [--root <dir>] [--list]" ;;
    *)
      # AGENTS.md resolves %TEST_CMD% to this script and skills invoke that as
      # `%TEST_CMD% <module-path>`. Refusing would read as a broken project
      # profile; narrowing to the path would be the opt-out this script refuses
      # to have. So it runs everything and SAYS it ignored the path -- running
      # more than was asked is the safe direction, staying quiet is not.
      IGNORED_ARG="${IGNORED_ARG}${IGNORED_ARG:+ }$1"; shift ;;
  esac
done

for f in AGENTS.md hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  [ -f "$ROOT/$f" ] || die 2 "cannot run: $ROOT is not this repository ($f is absent)."
done
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
  || die 2 "cannot run: $ROOT is not a git working tree, so the tracked-file set cannot be derived."

# One list, read by the run sequence, by --list, and by the stray-script check,
# so adding an entry adds a run rather than silencing a finding. Format:
# `name|kind:target`, in run order, where kind is `fn` (target is a shell
# function) or `sh` (target is a script run through script_member).
#
# The kind prefix closes the ACCIDENTAL version of a silencer: when every entry
# carried a bare script field and four of them were dispatched by name, those
# four fields were never run and yet the stray-script check still read them as
# exemptions, so a field could silence a finding while costing nothing. A
# function entry now has no script field to abuse, and `member_scripts` sees
# only `sh:` targets.
#
# It does NOT close the deliberate version, and nothing at runtime can: repoint
# a member at another script and its own gate stops running while the member
# name still claims otherwise. Measured, not assumed — a mutation leg in
# test-run-checks.sh shows that run exiting 0. What covers it is the pinned
# member table in that same suite: this list is asserted verbatim, so changing
# it on purpose means changing the assertion.
MEMBERS='manifests|fn:manifests_member
references|sh:scripts/check-references.sh
shell-syntax|fn:syntax_member
untracked-shell|fn:untracked_member
gate-inventory|fn:inventory_member
readme-update|sh:scripts/check-readme-update.sh
propagation-arms|sh:scripts/check-propagation-arms.sh'

member_names()   { printf '%s\n' "$MEMBERS" | sed 's/|.*//'; }
member_scripts() { printf '%s\n' "$MEMBERS" | sed -n 's/^[^|]*|sh:\(..*\)$/\1/p'; }

# An entry naming a kind nobody dispatches, or a function that does not exist,
# is a member that cannot run. It is reported as a finding rather than skipped.
members_findings() {
  local name spec kind target
  while IFS='|' read -r name spec; do
    [ -n "$name" ] || continue
    kind=${spec%%:*}; target=${spec#*:}
    case $kind in
      fn)
        # `declare -F`, not `command -v`: the latter resolves external commands
        # too, so `fn:true` passed the check and then ran `true` — the member
        # printed no verdict at all and the run exited 0 one member short.
        declare -F "$target" >/dev/null 2>&1 \
          || printf 'member %s names function %s, which is not a shell function here\n' "$name" "$target" ;;
      sh)
        [ -n "$target" ] || printf 'member %s names no script\n' "$name" ;;
      *)
        printf 'member %s has kind [%s], which the dispatch does not know\n' "$name" "$kind" ;;
    esac
  done <<MEMBERS_EOF
$MEMBERS
MEMBERS_EOF
}

# Delivery gates run at a different moment and have a different rc contract, so
# they are exempt BY NAME: adding a third one is then a decision, not an
# omission that nothing reports.
EXEMPT_SUITES='scripts/test-install-smoke.sh scripts/test-upgrade-smoke.sh'
# A delivery gate, and the promotion gate a skill calls on its own.
EXEMPT_CHECKS='scripts/check-release.sh scripts/check-candidate.sh'

in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

tracked_sh() { git -C "$ROOT" ls-files -z '*.sh' | tr '\0' '\n'; }

derived_suites() {
  local p
  tracked_sh | grep -E '(^|/)test-[A-Za-z0-9._-]*\.sh$' | sort -u | while IFS= read -r p; do
    in_list "$p" "$EXEMPT_SUITES" || printf '%s\n' "$p"
  done
}

# The suite list as AGENTS.md § Build & Test states it: the span from the line
# that introduces it to the next numbered item. Parsed rather than trusted --
# a list and the tree beside it are exactly what drifts, and nothing else in the
# gate set can see that. The range end excludes anything a later item names;
# today's items below 4 happen to spell their scripts as `bash scripts/…`, which
# this token pattern cannot match anyway, so the end is defensive rather than
# load-bearing.
documented_suites() {
  sed -n '/Then every test suite green:/,/^5\./p' "$ROOT/AGENTS.md" \
    | grep -o '`[A-Za-z0-9._/-]*test-[A-Za-z0-9._-]*\.sh`' \
    | tr -d '`' | sort -u
}

stray_checks() {
  local p members
  members=$(member_scripts | tr '\n' ' ')
  tracked_sh | grep -E '(^|/)check-[A-Za-z0-9._-]*\.sh$' | sort -u | while IFS= read -r p; do
    in_list "$p" "$EXEMPT_CHECKS" && continue
    in_list "$p" "$members" && continue
    printf '%s\n' "$p"
  done
}

# Empty output means agreement, so every way of producing nothing has to be
# ruled out before the comparison rather than after it.
inventory_findings() {
  local doc der
  members_findings
  der=$(derived_suites | sed '/^$/d')
  doc=$(documented_suites | sed '/^$/d')
  if [ -z "$doc" ]; then
    printf 'AGENTS.md carries no suite list: the span introduced by "Then every test suite green:" was not found, and an empty list must not read as agreement.\n'
    return 0
  fi
  if [ -z "$der" ]; then
    printf 'no test suite was derived from the tree, and an empty derivation must not read as agreement.\n'
    return 0
  fi
  comm -23 <(printf '%s\n' "$der") <(printf '%s\n' "$doc") \
    | sed 's|^|in the tree but not named in AGENTS.md: |'
  comm -13 <(printf '%s\n' "$der") <(printf '%s\n' "$doc") \
    | sed 's|^|named in AGENTS.md but not in the tree: |'
  stray_checks | sed 's|^|a tracked check script that is neither a member nor exempt: |'
}

PASSED=0; FAILED=0; FAILED_NAMES=''

report_ok() {
  PASSED=$((PASSED+1))
  printf 'ok   %s%s\n' "$1" "${2:+ — $2}"
  return 0
}
report_fail() {
  FAILED=$((FAILED+1))
  FAILED_NAMES="${FAILED_NAMES}${FAILED_NAMES:+, }$1"
  printf 'FAIL %s%s\n' "$1" "${2:+ — $2}"
  if [ -n "${3:-}" ]; then printf '%s\n' "$3" | sed 's/^/     | /'; fi
  return 0
}
report_missing() {
  FAILED=$((FAILED+1))
  FAILED_NAMES="${FAILED_NAMES}${FAILED_NAMES:+, }$1"
  printf 'MISSING %s — %s\n' "$1" "$2"
  return 0
}

# Every member function is invoked BARE, never as `out=$(member)`: a command
# substitution is a subshell, so the counters the report helpers increment would
# be discarded there while the exit status still looked right.

manifests_member() {
  local out rc t0=$SECONDS
  out=$(cd "$ROOT" && jq -e . hooks/hooks.json .claude-plugin/plugin.json .claude-plugin/marketplace.json 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then report_ok manifests "$((SECONDS-t0))s"
  else report_fail manifests "rc $rc, $((SECONDS-t0))s" "$out"; fi
}

syntax_member() {
  local out errs rc parsed tracked t0=$SECONDS
  tracked=$(tracked_sh | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "${tracked:-0}" -eq 0 ]; then
    report_fail shell-syntax "no tracked *.sh files — the gate narrowed its own input set to nothing"
    return 0
  fi
  # `-t` makes xargs echo each invocation, so the processed count comes from the
  # gate's OWN execution rather than from a second `git ls-files` that merely
  # shares its pathspec. Comparing it against the tracked count is what turns
  # "exit 0" into "exit 0 having actually parsed every file".
  out=$(cd "$ROOT" && git ls-files -z '*.sh' | xargs -0 -n1 -t bash -n 2>&1); rc=$?
  parsed=$(printf '%s\n' "$out" | grep -c '^bash -n ' | tr -d ' ')
  errs=$(printf '%s\n' "$out" | grep -v '^bash -n ')
  if [ "$rc" -ne 0 ]; then
    report_fail shell-syntax "rc $rc, $parsed of $tracked files parsed" "$errs"
  elif [ "$parsed" != "$tracked" ]; then
    report_fail shell-syntax "exit 0 but only $parsed of $tracked tracked files were parsed" "$errs"
  else
    report_ok shell-syntax "$parsed files parsed, $((SECONDS-t0))s"
  fi
}

untracked_member() {
  local out
  out=$(git -C "$ROOT" ls-files -o --exclude-standard '*.sh')
  if [ -z "$out" ]; then report_ok untracked-shell
  else report_fail untracked-shell "the syntax gate reads the INDEX, so these were never parsed; run git add -N on them" "$out"; fi
}

inventory_member() {
  local out
  out=$(inventory_findings)
  if [ -z "$out" ]; then report_ok gate-inventory
  else report_fail gate-inventory "the derived list and AGENTS.md disagree" "$out"; fi
}

script_member() {
  local name=$1 rel=$2 out rc t0=$SECONDS
  if [ ! -f "$ROOT/$rel" ]; then report_missing "$name" "$rel is absent, and absence is not a pass"; return 0; fi
  out=$(cd "$ROOT" && bash "$rel" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then report_ok "$name" "$((SECONDS-t0))s"
  else report_fail "$name" "rc $rc, $((SECONDS-t0))s" "$out"; fi
}

if [ "$LIST_ONLY" -eq 1 ]; then
  if [ -n "$IGNORED_ARG" ]; then
    printf 'note: [%s] ignored — this gate list is undivided, so --list describes all of it.\n' "$IGNORED_ARG" >&2
  fi
  member_names
  derived_suites
  # An untracked suite is reported here too, and that is not decoration: the
  # derivation reads the INDEX, so a suite that exists but was never staged is
  # absent from both sides of the comparison and the two sides AGREE. Without
  # this, --list returns 0 on precisely the task that adds a suite.
  findings=$(
    inventory_findings
    git -C "$ROOT" ls-files -o --exclude-standard '*.sh' \
      | sed 's|^|untracked, so invisible to the derivation (run git add -N): |'
  )
  if [ -n "$findings" ]; then
    printf '\nthe derived list and AGENTS.md disagree:\n%s\n' "$findings" >&2
    exit 1
  fi
  exit 0
fi

printf 'gate list for %s\n' "$ROOT"
if [ -n "$IGNORED_ARG" ]; then
  printf 'note: [%s] ignored — this gate list is undivided, so the whole list runs.\n' "$IGNORED_ARG"
fi
printf '\n'

while IFS='|' read -r name spec; do
  [ -n "$name" ] || continue
  printf '.. %s\n' "$name"
  kind=${spec%%:*}; target=${spec#*:}
  case $kind in
    fn)
      if declare -F "$target" >/dev/null 2>&1; then "$target"
      else report_fail "$name" "names function $target, which is not a shell function here"; fi ;;
    sh) script_member "$name" "$target" ;;
    *)  report_fail "$name" "has kind [$kind], which the dispatch does not know" ;;
  esac
done <<MEMBERS_EOF
$MEMBERS
MEMBERS_EOF

# Suites run in sorted order with a progress line each, because one of them
# takes about four minutes and silence there reads as a hang.
while IFS= read -r suite; do
  [ -n "$suite" ] || continue
  printf '.. %s\n' "$suite"
  script_member "$suite" "$suite"
done <<SUITES_EOF
$(derived_suites)
SUITES_EOF

# The counts are part of the verdict, not decoration: "0 failed" over a member
# set that quietly shrank is the false green this whole script is built against.
suite_count=$(derived_suites | sed '/^$/d' | wc -l | tr -d ' ')
printf '\n%s ok, %s failed — %s suites derived from the tree\n' "$PASSED" "$FAILED" "$suite_count"
if [ "$FAILED" -gt 0 ]; then
  printf 'failed: %s\n' "$FAILED_NAMES"
  exit 1
fi
exit 0
