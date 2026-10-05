#!/usr/bin/env bash
# SubagentStart -- append one `agent-mark` row per spawn. GH-86.
#
# WHY THIS EXISTS, AND WHAT IT IS NOT. This is a CANARY, not a second source of
# attribution. PreToolUse already supplies a real `agent_id` on the current
# build (measured), so nothing here improves who a call is attributed to.
#
# What it buys is a contradiction. When `agent_id` is absent or non-string,
# loop-index.sh degrades it to the literal "main" -- indistinguishable from a
# genuine main-agent call, which is how ten of twelve field ledgers recorded
# every subagent as `main` with no symptom at all. A dispatch-time record of a
# subagent STARTING makes "N subagents started, zero non-`main` call rows" a
# self-contradictory ledger, and therefore detectable from the ledger alone.
#
# SO A COUNT IS THE PRODUCT, NOT AN IDENTITY. `agent_id` and `agent_type` ride
# along because the verified payload hands them over free and they say WHICH
# agent type went missing once the canary fires. The boundary, stated so it is
# not crossed later: no reader may join an `agent-mark` row to a `call` row.
# That join is read-time attribution, which this ticket puts out of scope.
#
# ONE-DIRECTIONAL BY CONSTRUCTION. Zero recorded starts cannot separate "no
# subagent ran" from "this script is not firing". The readers say so in their
# own prose rather than implying coverage that does not exist.
#
# A NEW `kind` IS INVISIBLE TO THE DETECTOR FOR FREE. loop-window.awk admits
# `kind == "call"` only, so this row can never enter a window or a count.
set -u

LEDGER_DIR="${HARNESS_LOOP_DIR:-${HOME}/.claude/harness/loops}"

# Shared with the other ledger writers, including the one-per-session report
# when the ledger cannot be written; see hooks/lib/ledger-write.sh. The guard
# mirrors loop-index.sh's: an absent helper costs the warning, never the row.
HERE_LIB=$( { cd -- "$(dirname -- "$0")" && pwd; } 2>/dev/null ) || HERE_LIB=""
if [ -n "$HERE_LIB" ] && [ -r "${HERE_LIB}/ledger-write.sh" ]; then
  . "${HERE_LIB}/ledger-write.sh"
else
  harness_ledger_append() { { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; }
  harness_ledger_report_once() { :; }
fi

# A hook that breaks is worse than one that is absent; every failure path here
# exits 0, unconditionally, and silence is the default rather than the
# guarantee -- the unwritable ledger reports once per session, per
# hooks/lib/ledger-write.sh. A SubagentStart hook has no `permissionDecision` and so
# cannot block a spawn even deliberately -- but a non-zero exit still becomes a
# hook_blocking_error attachment on the turn, so the discipline still binds.
in=$(cat 2>/dev/null) || exit 0
[ -n "$in" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

out=$(printf '%s' "$in" | jq -r '
    (if (.session_id | type) == "string" then .session_id else "" end) as $sid
    | ($sid),
      ({ts: (now | todate), kind: "agent-mark",
        agent_id:   (if (.agent_id   | type) == "string" then .agent_id   else null end),
        agent_type: (if (.agent_type | type) == "string" then .agent_type else null end)} | tojson)
  ' 2>/dev/null) || exit 0

sid=$(printf '%s\n' "$out" | sed -n 1p)
entry=$(printf '%s\n' "$out" | sed -n 2p)
[ -n "${sid:-}" ] || exit 0
[ -n "${entry:-}" ] || exit 0

# A non-string id in the payload becomes `null` in the row rather than a
# placeholder string: the reader counts DISTINCT ids, and a placeholder would
# inflate that count while claiming to measure identities.
# `mkdir -p` cannot stand in for the write check: it returns 0 on a directory
# that already exists whatever its mode, and an unwritable directory still
# permits an append to a ledger file created while it was writable. So both are
# checked, and both route to the same one-per-session report.
ledger="${LEDGER_DIR}/${sid}.jsonl"
mkdir -p "$LEDGER_DIR" 2>/dev/null || { harness_ledger_report_once "$sid" "$ledger"; exit 0; }
harness_ledger_append "$sid" "$ledger" "$entry" || true
exit 0
