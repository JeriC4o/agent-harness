#!/usr/bin/env bash
#
# PreToolUse gate for skills that must not be STARTED BY A SUBAGENT and must be
# CONFIRMED BY THE USER when the main thread reaches for them.
#
# WHY THIS EXISTS RATHER THAN disable-model-invocation. That flag expresses one
# posture only: the model may never invoke the skill, with or without the user
# present. The posture wanted here is narrower -- the main agent MAY propose the
# workflow, the user confirms it, and a subagent may not start it at all. No
# frontmatter field expresses that, and a subagent `tools:` allowlist cannot
# either, because it binds on tools rather than on which skill is asked for.
#
# THE DISCRIMINATOR IS agent_id, AND IT IS MEASURED, NOT ASSUMED. The hooks
# reference states that PreToolUse input carries agent_id "only when the hook
# fires inside a subagent call". Verified on this build: a probe subagent
# recorded agent_id a601d47b93e8d7bc6 with agent_type general-purpose, while the
# main thread records neither field. A gate resting on a field that never
# arrives is a gate that cannot fail, so the test suite asserts BOTH branches.
#
# IT NEVER BREAKS THE TURN. Every path exits 0; a malformed payload, an absent
# jq or an unreadable field yields silence, which defers to the normal
# permission flow rather than blocking work on a gate that could not read its
# own input.
#
# THE GATED SET IS DATA, NOT LOGIC. HARNESS_SKILL_GATE holds a space-separated
# list of skill names, so adding a skill is a settings change rather than an
# edit here. Names are matched after the plugin prefix is stripped, because the
# same skill is `task` when it ships in a project and `harness:task` when it
# arrives through the plugin, and a gate that knew only one spelling would be
# silent on the other.
set -uo pipefail

GATED="${HARNESS_SKILL_GATE:-task}"

in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tool=$(printf '%s' "$in" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ "$tool" = "Skill" ] || exit 0

skill=$(printf '%s' "$in" | jq -r '.tool_input.skill // empty' 2>/dev/null) || exit 0
[ -n "$skill" ] || exit 0
bare="${skill##*:}"

hit=""
for g in $GATED; do
  [ "$bare" = "$g" ] || continue
  hit="$g"
  break
done
[ -n "$hit" ] || exit 0

# A non-string agent_id is treated as absent: an array or a number is not an
# agent, and reading one as present would deny the MAIN thread, which is the
# failure direction that costs the user their own workflow.
agent=$(printf '%s' "$in" | jq -r 'if (.agent_id | type) == "string" then .agent_id else "" end' 2>/dev/null) || exit 0

if [ -n "$agent" ]; then
  decision="deny"
  reason=$(printf 'BLOCKED: a subagent may not start /%s. This workflow owns branch state, spec and design artefacts, and commits; it is the MAIN thread that runs it, after the user confirms. Hand back with what you found and what you would run, and let the parent decide. Do not reproduce the workflow steps by hand instead -- a spec and a design written outside the skill are exactly what its subagent contract forbids.' "$hit")
else
  decision="ask"
  reason=$(printf 'CONFIRM: /%s starts the full ordered workflow -- interview, spec, design, design-review, implementation, verification, self-review -- and it writes planning artefacts and commits along the way. It runs only when the user says so, so this call is being put to them rather than taken. A skill the user typed reaches this gate too, because nothing in the payload separates a typed invocation from a proposed one.' "$hit")
fi

jq -nc --arg d "$decision" --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}' \
  2>/dev/null || exit 0

exit 0
