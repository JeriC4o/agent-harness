#!/usr/bin/env bash
#
# Tests for scripts/check-propagation-arms.sh.
#
# Run: bash scripts/test-check-propagation-arms.sh
#
# Every planted defect is applied to a COPY in a temp tree, never to the live
# method file -- a gate whose own tests mutate the documents it reads is one
# interrupted run away from corrupting them.
#
# Each degradation is followed by a changed-guard: if the edit produced a
# byte-identical file the suite FAILS instead of reporting a green control.
# That guard caught two no-op degradations while this suite was being written,
# both of which would have read as the control passing.

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd -P)
GATE="${ROOT}/scripts/check-propagation-arms.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT INT TERM

# `md5sum` where it exists, `md5 -q` on this platform.
md5_of(){ if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | cut -d' ' -f1; else md5 -q "$1"; fi; }
for f in docs/agents-method.md hooks/hooks.json; do
  printf '%s  %s\n' "$(md5_of "${ROOT}/${f}")" "$f" >> "${TMPD}/before.md5"
done

# Fields 1 and 2 of the gate's own summary line, so a drift in either is read
# from the gate rather than pinned here as a constant.
counts_of(){ sed -n 's/^.*: \([0-9]*\) derived members all fire, \([0-9]*\) controls all silent.*/\1 \2/p' "$1"; }

mk_fixture(){ # <dir>
  mkdir -p "$1/docs/templates" "$1/agents" "$1/hooks" "$1/scripts"
  cp "${ROOT}/docs/agents-method.md" "$1/docs/agents-method.md"
  cp "${ROOT}/hooks/hooks.json" "$1/hooks/hooks.json"
  # The files the table's three bare filenames resolve against, plus the root
  # AGENTS.md the harvest treats as a class rather than a reference.
  touch "$1/AGENTS.md" "$1/docs/claude-tools-hierarchy.md" \
        "$1/docs/templates/learnings-entry-format.md" "$1/agents/spec-writer.md" \
        "$1/scripts/check-readme-update.sh"
}

changed(){ # <label> <original> <mutated>
  if cmp -s "$2" "$3"; then bad "$1 -- the planted edit changed NOTHING, so whatever follows proves nothing"; return 1; fi
  ok "$1 -- planted edit applied"; return 0
}

plant_row(){ # <fixture> <row text>
  awk -v row="$2" '/^> \| `AGENTS\.md` \(rule add/{print row} {print}' \
    "$1/docs/agents-method.md" > "$1/t" && mv "$1/t" "$1/docs/agents-method.md"
}

drop_arm(){ # <fixture> <arm text>
  jq --arg a "$2" '(.hooks.PreToolUse[] | select(.matcher=="Edit|Write") | .hooks[0].command) |= (split($a) | join(""))' \
    "$1/hooks/hooks.json" > "$1/t" && mv "$1/t" "$1/hooks/hooks.json"
}

# A degraded COPY of the gate, so the control degrades the gate's own operator
# rather than only its input. Group A shipped a control that removed a guard's
# test but kept its assignment and so passed vacuously; the changed-guard plus
# an explicit assertion on the degraded run's verdict is what stops that here.
#
# The line is located by FIXED substring and replaced by number, because the
# gate's own lines are full of regex metacharacters and `awk -v` eats
# backslashes -- an anchor spelled as a pattern matched nothing twice here, and
# a degradation that silently applies to no line is the quietest vacuous
# control there is.
anchor_line(){ # <fixed substring> -> the single line number it occurs on
  hits=$(grep -cF -- "$1" "$GATE")
  [ "$hits" = "1" ] || { printf 'test-check-propagation-arms: anchor matched %s lines, not 1: %s\n' "$hits" "$1" >&2; return 1; }
  grep -nF -- "$1" "$GATE" | cut -d: -f1
}
gate_replace(){ # <out> <fixed substring> <replacement line>
  n=$(anchor_line "$2") || return 1
  awk -v n="$n" -v new="$3" 'NR==n{print new; next} {print}' "$GATE" > "$1"
}
gate_delete(){ # <out> <fixed substring>
  n=$(anchor_line "$2") || return 1
  awk -v n="$n" 'NR==n{next} {print}' "$GATE" > "$1"
}

printf '\n== the live tree is clean ==\n'
bash "$GATE" > "${TMPD}/real.out" 2>&1
if [ $? -eq 0 ]; then ok "check-propagation-arms is green on the working tree"; else bad "check-propagation-arms is RED on the working tree"; sed -n '/^FINDING/p' "${TMPD}/real.out"; fi
REAL_COUNTS=$(counts_of "${TMPD}/real.out")
[ -n "$REAL_COUNTS" ] && ok "the gate reports its member and control counts beside their enumerations (${REAL_COUNTS})" \
                      || bad "the gate printed no summary counts"

printf '\n== the enumeration carries the classes only one leg can produce ==\n'
for c in scripts/session-events.sh scripts/loop-metrics.sh docs/agents-method.md rules/'*'.md \
         CLAUDE.md ai-docs/context.md .claude/skills/'*'/SKILL.md; do
  grep -qF "  fires   ${c}" "${TMPD}/real.out" && ok "derived: ${c}" || bad "derived set is missing ${c}"
done
grep -qF '  silent  ai-docs/learnings/probe-probe.md' "${TMPD}/real.out" \
  && ok "the excluded learning-log class stays silent under the arms" \
  || bad "the excluded learning-log class is not reported silent"

printf '\n== the clean fixture reproduces the live run ==\n'
F="${TMPD}/clean"; mk_fixture "$F"
bash "$GATE" --root "$F" > "${TMPD}/clean.out" 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "--root on an unmutated copy is green" || { bad "--root on an unmutated copy is RED"; sed -n '/^FINDING/p' "${TMPD}/clean.out"; }
[ "$(counts_of "${TMPD}/clean.out")" = "$REAL_COUNTS" ] \
  && ok "the fixture derives the same member and control counts as the live tree" \
  || bad "fixture counts [$(counts_of "${TMPD}/clean.out")] differ from live [$REAL_COUNTS] -- the fixture is not a copy of the thing under test"

printf '\n== AC9: a planted member row the arms do not cover ==\n'
F="${TMPD}/ac9"; mk_fixture "$F"
plant_row "$F" '> | `${CLAUDE_PLUGIN_ROOT}/templates/project/AGENTS.md` | a member class no arm matches |'
if changed "AC9 fixture" "${ROOT}/docs/agents-method.md" "$F/docs/agents-method.md"; then
  bash "$GATE" --root "$F" > "${TMPD}/ac9.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS on an uncovered member class" || bad "the gate passed with an uncovered member class"
  grep -qF "no arm fires on derived class 'templates/project/AGENTS.md'" "${TMPD}/ac9.out" \
    && ok "and it names the class" || bad "it failed without naming the uncovered class"
fi

printf '\n== AC10: the catch-all row is the only source of CLAUDE.md and ai-docs/context.md ==\n'
F="${TMPD}/ac10"; mk_fixture "$F"
grep -vF 'Any other instruction file' "$F/docs/agents-method.md" > "$F/t" && mv "$F/t" "$F/docs/agents-method.md"
if changed "AC10 fixture" "${ROOT}/docs/agents-method.md" "$F/docs/agents-method.md"; then
  bash "$GATE" --root "$F" > "${TMPD}/ac10.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS with the catch-all row deleted" || bad "the gate passed with the catch-all row deleted"
  for req in CLAUDE.md ai-docs/context.md; do
    grep -qF "the catch-all leg did not yield '${req}'" "${TMPD}/ac10.out" \
      && ok "and it names ${req}" || bad "it did not name ${req} as lost"
  done
fi

printf '\n== the exclusion cannot rot into a silencer ==\n'
F="${TMPD}/dead"; mk_fixture "$F"
sed 's|ai-docs/learnings/<username>-<branch>\.md|ai-docs/learnings/README.md|g' \
  "$F/docs/agents-method.md" > "$F/t" && mv "$F/t" "$F/docs/agents-method.md"
if changed "dead-exclusion fixture" "${ROOT}/docs/agents-method.md" "$F/docs/agents-method.md"; then
  bash "$GATE" --root "$F" > "${TMPD}/dead.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS when the exclusion matches nothing" || bad "a dead exclusion passed"
  grep -qF "matches nothing in the derived set" "${TMPD}/dead.out" \
    && ok "and it says the exclusion is dead" || bad "it failed for some other reason"
  # Degrading the GUARD, not its input: the subtraction stays, only the test
  # that the exclusion still matches goes.
  gate_replace "${TMPD}/g-noexcl.sh" 'if grep -qxF "$EXCLUDE"' 'if true; then'
  if changed "exclusion-guard degradation" "$GATE" "${TMPD}/g-noexcl.sh"; then
    bash "${TMPD}/g-noexcl.sh" --root "$F" > "${TMPD}/noexcl.out" 2>&1
    [ $? -eq 0 ] && ok "and without that guard the same fixture goes GREEN -- the guard is load-bearing" \
                 || bad "the degraded gate still failed, so the dead-exclusion verdict comes from elsewhere"
  fi
fi

printf '\n== the carve-in cannot double-count ==\n'
F="${TMPD}/carve"; mk_fixture "$F"
plant_row "$F" '> | `${CLAUDE_PLUGIN_ROOT}/.claude/skills/<name>/SKILL.md` | a token that now yields the carve-in |'
if changed "dead-carve-in fixture" "${ROOT}/docs/agents-method.md" "$F/docs/agents-method.md"; then
  bash "$GATE" --root "$F" > "${TMPD}/carve.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS once the table itself yields the carve-in" || bad "a derivable carve-in passed"
  grep -qF 'is now derivable from the table' "${TMPD}/carve.out" \
    && ok "and it says to delete the carve-in" || bad "it failed for some other reason"
fi

printf '\n== AC13: the pre-fix arms are the carve-in independent witness ==\n'
F="${TMPD}/arm"; mk_fixture "$F"
drop_arm "$F" '|"$pd"/.claude/skills/*/SKILL.md'
if changed "dropped-arm fixture" "${ROOT}/hooks/hooks.json" "$F/hooks/hooks.json"; then
  [ "$(grep -cF '.claude/skills' "$F/hooks/hooks.json")" = "0" ] \
    && ok "the fixture manifest carries no .claude/skills arm" \
    || bad "the arm is still in the fixture manifest"
  bash "$GATE" --root "$F" > "${TMPD}/arm.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS with the tenth arm removed" || bad "the gate passed with the tenth arm removed"
  grep -qF "matched the pre-fix arms and is SILENT under the new set" "${TMPD}/arm.out" \
    && ok "and the regression leg names it" || bad "the regression leg stayed quiet"

  # THE assertion the whole carve-in exists for. With the carve-in absent from
  # the gate the member leg is blind to the class, so if the gate still fails
  # here the verdict came from the pre-fix pattern alone -- evidence authored
  # before this gate existed, which is what stops the carve-in certifying
  # itself from its own class string.
  gate_replace "${TMPD}/g-nocarve.sh" 'CARVE_IN" >> ' '  :'
  if changed "carve-in-blind gate" "$GATE" "${TMPD}/g-nocarve.sh"; then
    bash "${TMPD}/g-nocarve.sh" --root "$F" > "${TMPD}/nocarve.out" 2>&1
    rc=$?
    [ "$rc" -ne 0 ] && ok "a carve-in-blind gate STILL fails on the dropped arm" \
                    || bad "a carve-in-blind gate passed on the dropped arm -- the witness is not independent"
    grep -qF "no arm fires on derived class '.claude/skills/*/SKILL.md'" "${TMPD}/nocarve.out" \
      && bad "the member leg still saw the class, so this run does not isolate the witness" \
      || ok "and the member leg is silent about it, so the verdict is the witness alone"
    bash "${TMPD}/g-nocarve.sh" --root "${TMPD}/clean" > "${TMPD}/nocarve2.out" 2>&1
    [ $? -eq 0 ] && ok "the carve-in-blind gate is still green on an unmutated copy" \
                 || bad "the carve-in-blind gate fails everywhere, so it discriminates nothing"
  fi
fi

printf '\n== the controls bound the arms, not just decorate them ==\n'
F="${TMPD}/wide"; mk_fixture "$F"
jq '(.hooks.PreToolUse[] | select(.matcher=="Edit|Write") | .hooks[0].command) |= (split("\"$pd\"/.claude/skills/*/SKILL.md") | join("\"$pd\"/.claude/skills/*.md"))' \
  "$F/hooks/hooks.json" > "$F/t" && mv "$F/t" "$F/hooks/hooks.json"
if changed "rejected-spelling fixture" "${ROOT}/hooks/hooks.json" "$F/hooks/hooks.json"; then
  bash "$GATE" --root "$F" > "${TMPD}/wide.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS on the rejected .claude/skills/*.md spelling" || bad "the rejected spelling passed"
  for c in .claude/skills/deploy/reference.md .claude/skills/notes.md; do
    grep -qF "an arm fires on control '${c}'" "${TMPD}/wide.out" \
      && ok "and it names control ${c}" || bad "control ${c} did not fire on the widened arm"
  done
fi

printf '\n== a bare filename is resolved, and an unresolvable one is a finding ==\n'
F="${TMPD}/bare"; mk_fixture "$F"
plant_row "$F" '> | `no-such-file-gh75.md` | a bare name matching nothing |'
plant_row "$F" '> | `check-readme-update.sh` | a bare name that resolves |'
if changed "bare-name fixture" "${ROOT}/docs/agents-method.md" "$F/docs/agents-method.md"; then
  bash "$GATE" --root "$F" > "${TMPD}/bare.out" 2>&1
  [ $? -ne 0 ] && ok "the gate FAILS on an unresolvable bare filename" || bad "an unresolvable bare filename was dropped silently"
  grep -qF "bare filename 'no-such-file-gh75.md'" "${TMPD}/bare.out" \
    && ok "and it names the unresolved token" || bad "it did not name the unresolved token"
  grep -qF '  fires   scripts/check-readme-update.sh' "${TMPD}/bare.out" \
    && ok "a resolvable bare filename becomes its full path" || bad "the resolvable bare filename did not resolve"
fi

printf '\n== both cells are harvested, and the right cell is the only source of two classes ==\n'
gate_replace "${TMPD}/g-leftcell.sh" 'tr '"'"'|'"'"' ' 'cut -d'"'"'|'"'"' -f2 "$TMP/rows.txt" > "$TMP/cells.txt"'
if changed "left-cell-only harvest" "$GATE" "${TMPD}/g-leftcell.sh"; then
  bash "${TMPD}/g-leftcell.sh" > "${TMPD}/leftcell.out" 2>&1
  for c in scripts/session-events.sh scripts/loop-metrics.sh; do
    grep -qF "  fires   ${c}" "${TMPD}/leftcell.out" \
      && bad "${c} survived a left-cell-only harvest, so the both-cell harvest is not load-bearing" \
      || ok "a left-cell-only harvest loses ${c}"
  done
fi

printf '\n== the section-suffix strip and the <...> normalisation are each load-bearing ==\n'
gate_delete "${TMPD}/g-nosec.sh" 's/ §[^`]*$//'
if changed "section-suffix strip removed" "$GATE" "${TMPD}/g-nosec.sh"; then
  bash "${TMPD}/g-nosec.sh" > "${TMPD}/nosec.out" 2>&1
  grep -qF '  fires   docs/agents-method.md' "${TMPD}/nosec.out" \
    && bad "docs/agents-method.md survived without the suffix strip" \
    || ok "without the strip the Learning-Log row fails the extension filter and docs/agents-method.md is lost"
fi
gate_replace "${TMPD}/g-tmpl.sh" 's/<[^>]*>/*/g' "  | grep -v '<' | sed -E 's/[*][*]/*/g'"
if changed "<...> normalisation replaced by skip-if-templated" "$GATE" "${TMPD}/g-tmpl.sh"; then
  bash "${TMPD}/g-tmpl.sh" > "${TMPD}/tmpl.out" 2>&1
  grep -qF '  fires   rules/*.md' "${TMPD}/tmpl.out" \
    && bad "rules/*.md survived skip-if-templated" \
    || ok "skip-if-templated loses rules/*.md, whose only source is rules/<file>.md"
fi

printf '\n== the live files this suite reads were never written ==\n'
# Against a snapshot taken before the first fixture, not against git: the
# working tree legitimately carries uncommitted changes to both files, so
# `git diff --quiet` would report this suite's innocence as guilt.
for f in docs/agents-method.md hooks/hooks.json; do
  [ "$(md5_of "${ROOT}/${f}")" = "$(grep "  ${f}$" "${TMPD}/before.md5" | cut -d' ' -f1)" ] \
    && ok "${f} is byte-for-byte what it was when the suite started" \
    || bad "the suite mutated ${f}"
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
