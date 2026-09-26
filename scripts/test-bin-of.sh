#!/usr/bin/env bash
#
# Tests for scripts/bin-of.jq, and for its AGREEMENT with the copy inside
# scripts/session-events.sh. Run from anywhere:
#   bash scripts/test-bin-of.sh
#
# The agreement leg is the point of this file. Two definitions of "the same
# shape of command" that drift make /inspect and the loop index disagree about
# what a repeat IS, while both keep reporting repeats -- the quiet kind of wrong.
# It is checked by RUNNING both over the same commands, never by comparing their
# source text: identical text is not the claim, identical output is.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
MOD="$HERE"
SE="${HERE}/session-events.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

# The fixture set. Each entry exercises one decision in the normalisation.
CMDS=(
  "git status --short"
  "git log --oneline -5"
  "gh issue view 67"
  "gh pr create --base main"
  "grep -rn needle src/"
  "sed -i '' s/a/b/ f.txt"
  "FOO=1 pytest tests/x"
  "A=1 B=2 make build"
  "./scripts/run.sh --flag"
  "for f in a b; do echo \$f; done"
  "cargo test --all"
  "jq -e . x.json"
  "npm install"
  "docker compose up"
  "cat README.md"
)

bin_mod() { jq -rn -L "$MOD" --arg c "$1" 'include "bin-of"; $c | bin_of'; }

printf '\n== the module classifies each decision it makes ==\n'
check "a subcommand host keeps its verb"      "$(bin_mod 'git status --short')"    "git status"
check "  a second verb from the same host"    "$(bin_mod 'gh issue view 67')"      "gh issue view"
check "a plain binary is itself"              "$(bin_mod 'grep -rn needle src/')"  "grep"
check "a VAR= prefix is not the binary"       "$(bin_mod 'FOO=1 pytest tests/x')"  "pytest"
check "  several of them are skipped too"     "$(bin_mod 'A=1 B=2 make build')"    "make build"
check "a path is not a bin of its own"        "$(bin_mod './scripts/run.sh')"      "(other)"
check "an empty command is (other), not empty" "$(bin_mod '')"                     "(other)"
# A shell keyword IS a shape and bins as itself -- a turn full of `for` loops is
# a recognisable kind of work, so grouping them is wanted, not a leak. Asserted
# because it looks like an unclassified case and is not one.
check "a shell keyword bins as itself"        "$(bin_mod 'for f in a b; do :; done')" "for"
check "  and so does the other one"           "$(bin_mod 'if [ -f x ]; then :; fi')"  "if"

printf '\n== a non-Bash tool bins as its own name ==\n'
check "Read"  "$(jq -rn -L "$MOD" 'include "bin-of"; {file_path:"/x"} | bin_for("Read")')"  "Read"
check "Agent" "$(jq -rn -L "$MOD" 'include "bin-of"; {subagent_type:"gp"} | bin_for("Agent")')" "Agent gp"
check "Skill" "$(jq -rn -L "$MOD" 'include "bin-of"; {skill:"task"} | bin_for("Skill")')" "Skill task"

printf '\n== AGREEMENT with the copy inside session-events.sh ==\n'
# Build a transcript whose assistant messages carry exactly these commands, run
# the real script over it, and compare the bins it derives to the module's.
T="$W/t.jsonl"; : > "$T"
i=0
for c in "${CMDS[@]}"; do
  i=$((i+1))
  jq -nc --arg c "$c" --arg id "tu$i" \
    '{type:"assistant", timestamp:"2026-09-26T00:00:00.000Z",
      message:{content:[{type:"tool_use", name:"Bash", id:$id, input:{command:$c}}]}}' >> "$T"
done
bash "$SE" "$T" --json > "$W/ev.json" 2>"$W/ev.err"
check "session-events.sh read the fixture" "$?" "0"
se_bins=$(jq -r '[.events[] | select(.kind=="tool") | .bin] | join("|")' "$W/ev.json")
mod_bins=$(for c in "${CMDS[@]}"; do bin_mod "$c"; done | paste -sd'|' -)
check "both derive the same bin for every command" "$mod_bins" "$se_bins"
if [ "$mod_bins" != "$se_bins" ]; then
  printf '    module: %s\n    script: %s\n' "$mod_bins" "$se_bins"
fi
check "  and the fixture actually produced bins" \
      "$( [ -n "$se_bins" ] && echo yes || echo no )" "yes"

printf '\n== POSITIVE CONTROL: perturb the module, the agreement leg fails ==\n'
# Without this the agreement check could pass by both sides being empty, or by
# the comparison never running. Break one classification and require a mismatch.
MUT="$W/mut"; mkdir -p "$MUT"
perl -0pe 's/then "\(other\)"/then "UNCLASSIFIED"/' "$HERE/bin-of.jq" > "$MUT/bin-of.jq"
check "the mutation applied" "$(grep -c 'UNCLASSIFIED' "$MUT/bin-of.jq")" "1"
mut_bins=$(for c in "${CMDS[@]}"; do
             jq -rn -L "$MUT" --arg c "$c" 'include "bin-of"; $c | bin_of'; done | paste -sd'|' -)
check "the perturbed module disagrees" \
      "$( [ "$mut_bins" != "$se_bins" ] && echo differs || echo same )" "differs"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
