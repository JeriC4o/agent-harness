#!/usr/bin/env bash
# The ONE place a harness hook appends to the loop ledger, and the only place
# that decides what happens when it cannot. GH-86.
#
# SOURCED, NEVER EXECUTED, and the reason it is a file rather than two lines
# copied four times is the "once per session" part: each hook runs as its own
# process, so the fact that the warning has already been given cannot live in a
# shell variable. It lives in a marker directory, and a shared marker needs a
# shared naming rule.
#
# WHY THIS REPORTS INSTEAD OF SWALLOWING. Every other failure path in these
# hooks exits 0 in silence, and that is right: a malformed payload costs one
# row and the next call is unaffected. An unwritable ledger is different in
# KIND. Tier 1 and tier 2 both read that file to decide anything at all, so
# losing it disables detection for the whole session while every tool call
# still succeeds and nothing anywhere looks wrong. A detector that dies where
# nobody notices is the precise failure this change exists to fix; silencing
# its own death would be the first instance of it.
#
# WHAT IT STILL WILL NOT DO, because the contract is unchanged: it never exits
# non-zero, never emits a permissionDecision, never retries, and never costs
# the session a tool call. One sentence on stderr, once, and then the session
# carries on without a detector.

# Append one line to the ledger; report the first failure of the session.
#   harness_ledger_append <session_id> <ledger_path> <line>
# Returns 0 on success and 1 on failure. A caller must not turn that 1 into a
# non-zero exit -- it is there to let the caller skip work that depended on the
# write, nothing more.
harness_ledger_append() {
  # THE BRACES ARE LOAD-BEARING. Redirections apply left to right, so
  # `printf … >> "$f" 2>/dev/null` opens $f BEFORE stderr is diverted, and a
  # failed open is announced by the shell itself as a raw error naming the path.
  # Measured at 184 bytes from one read-only ledger dir, and at 166 / 102 / 101
  # from three others -- THE LENGTH IS A PROPERTY OF THE PATH, never of the
  # defect, so it is recorded as a mechanism and must not be asserted on.
  # Grouping diverts the open as well, which is what makes the sentence below
  # the only thing a human sees rather than the second thing.
  #
  # AND THE STATUS IS READ, not just the open. A successful open followed by a
  # failed WRITE -- a full disk, a quota, a vanished mount -- returns non-zero
  # from printf with nothing on stderr at all. An open-only check is an alarm
  # for one failure mode out of several, which is worse than it looks: the mode
  # it misses is the one that arrives on a machine that was working yesterday.
  if { printf '%s\n' "$3" >> "$2"; } 2>/dev/null; then
    return 0
  fi
  harness_ledger_report_once "$1" "$2"
  return 1
}

# Say once, per session, that the ledger cannot be written.
#   harness_ledger_report_once <session_id> <ledger_path>
# Always returns 0.
harness_ledger_report_once() {
  local tmp key marker
  # THE MARKER CANNOT LIVE BESIDE THE LEDGER, because the ledger directory is
  # the thing that is unwritable. The system temp dir is the one location a
  # hook can still expect to write once the configured one has failed.
  tmp="${TMPDIR:-/tmp}"
  # A session id arrives from a hook payload, so it is not trusted to be a
  # filename. Anything outside the safe set becomes `_` rather than a path
  # separator that would put the marker somewhere else entirely -- or, with the
  # right id, somewhere that matters.
  key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' 2>/dev/null)
  [ -n "$key" ] || key="unknown"
  marker="${tmp%/}/harness-ledger-warned-${key}"
  # mkdir IS the test-and-set: it succeeds exactly once and it is atomic, which
  # matters because PostToolUse and SubagentStart can be in flight together.
  #
  # It also fails when the TEMP dir itself is unwritable, and that case shares
  # this branch deliberately. With nowhere to record "already said", the only
  # two options are to repeat the sentence on every tool call for the rest of
  # the session or to say nothing; nothing is the one that cannot make a bad
  # situation worse.
  mkdir "$marker" 2>/dev/null || return 0
  printf '[loop-index] LOOP DETECTION IS DISABLED for this session: the ledger %s could not be written. Tier 1 and tier 2 both read that file, so no repeated-call, fan-out or retry finding can fire until it is writable again -- a quiet run from here is not evidence that nothing looped. Fix the permissions on that directory, or point HARNESS_LOOP_DIR at a writable one. Reported once per session.\n' \
    "$2" >&2
  return 0
}
