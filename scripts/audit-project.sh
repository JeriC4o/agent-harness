#!/usr/bin/env bash
#
# The mechanical half of a project-scope audit (/harness:ai-audit project).
# Checks the things about a consuming project's PROFILE that a script can
# decide; the skill handles everything needing judgement.
#
# Usage:  audit-project.sh <project-dir>
#
# Emits one finding per line:  <severity>|<check>|<message>
# Exit: 0 no blockers, 1 at least one blocker, 2 usage error.
#
# Checks (letters match the skill's checklist):
#   Q  profile completeness  -- no unresolved %PLACEHOLDER% in the profile
#   R  command liveness      -- the binary each %*_CMD% names actually exists
#   S  registry coherence    -- this project is registered, at this path
#   T  candidate hygiene     -- every .promote/*.md still passes the gate
#   U  gitignore coverage    -- progress/state files are really ignored
#
# R and U are deliberately EXECUTED rather than read: a command table that
# names a binary nobody has, and an ignore block that does not actually match,
# both look correct on the page. Asking git and the filesystem is the only way
# to tell.
#
# Tests: scripts/test-audit-project.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-candidate.sh"
REGISTRY="${HARNESS_REGISTRY:-${HOME}/.claude/harness/registry.json}"

die() { printf 'audit-project: %s\n' "$1" >&2; exit 2; }
[ $# -ge 1 ] || die "usage: audit-project.sh <project-dir>"
[ -d "$1" ] || die "no such directory: $1"
DIR=$(cd -- "$1" && pwd)

blockers=0
finding() { # <severity> <check> <message>
  printf '%s|%s|%s\n' "$1" "$2" "$3"
  [ "$1" = "blocker" ] && blockers=$((blockers+1))
  return 0
}

# ---- Q: profile completeness -------------------------------------------------
# Some %TOKENS% are permanent LABELS, not values waiting to be filled: the left
# column of the command table names each placeholder, and the prose refers to
# them. Only a token outside that allowlist is an unfilled value.
LABELS='%PLACEHOLDER%|%BUILD_CMD%|%TEST_CMD%|%FORMAT_CMD%|%LINT_CMD%|%PROJECT_NAME%'
for f in AGENTS.md ai-docs/context.md; do
  [ -f "${DIR}/${f}" ] || { finding blocker Q "missing profile file: ${f} -- run /harness:harness-init"; continue; }
  unfilled=$(grep -oE '%[A-Z_]+%' "${DIR}/${f}" | grep -vE "^(${LABELS})$" | sort -u | tr '\n' ' ')
  [ -n "$unfilled" ] && finding blocker Q "${f}: unresolved placeholder(s): ${unfilled}-- an unresolved placeholder is a STOP, not a default"
done

# ---- R: command liveness -----------------------------------------------------
# Resolve the first token of each recorded command and ask whether it can run.
#
# TWO OUTCOMES, deliberately distinguished, because the remedy differs:
#   - absent everywhere                     -> major: install it; the gate cannot run
#   - present in a login shell but not in
#     THIS session's PATH                   -> minor: restart the session
#
# The second case is the common one for per-user toolchains (rustup, nvm, pyenv,
# sdkman) whose PATH export lives in a shell rc file: a long-lived session can
# predate the line that exports them. Reporting that as "command not found"
# sends the reader off to install something they already have -- the cry-wolf
# failure this repo has already hit twice with its own checks.
#
# One finding per BINARY, not per table row: four rows naming the same missing
# tool are one problem, and printing it four times buries the other findings.
LOGIN_SHELL="${HARNESS_LOGIN_SHELL:-${SHELL:-/bin/sh}}"
seen_bins=""
if [ -f "${DIR}/AGENTS.md" ]; then
  while IFS= read -r line; do
    case "$line" in *'%FILL_ME%'*|*'n/a'*) continue ;; esac
    val=$(printf '%s' "$line" | awk -F'|' '{print $4}' | tr -d '`' | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$val" ] || continue
    case "$val" in 'This project'|'') continue ;; esac
    bin=$(printf '%s' "$val" | awk '{print $1}')
    case " ${seen_bins} " in *" ${bin} "*) continue ;; esac
    seen_bins="${seen_bins} ${bin}"
    case "$bin" in
      ./*|/*)
        [ -x "${DIR}/${bin#./}" ] || [ -x "$bin" ] \
          || finding major R "AGENTS.md: '${bin}' is not executable in this repo"
        ;;
      a|the|none|n/a) ;;
      *)
        if command -v "$bin" >/dev/null 2>&1; then
          :
        elif "$LOGIN_SHELL" -lc "command -v ${bin}" >/dev/null 2>&1; then
          finding minor R "AGENTS.md: '${bin}' resolves in a login shell but is absent from this session PATH -- the session predates the profile line that exports it; restart the session rather than installing anything"
        else
          finding major R "AGENTS.md: command '${bin}' not found on PATH or in a login shell -- the gate it defines cannot run"
        fi
        ;;
    esac
  done <<EOF
$(grep -E '^\| *`%[A-Z_]+%`' "${DIR}/AGENTS.md" || true)
EOF
fi

# ---- S: registry coherence ---------------------------------------------------
if [ ! -f "$REGISTRY" ]; then
  finding minor S "no registry at ${REGISTRY}; cross-project sweeps will not see this project"
elif command -v jq >/dev/null 2>&1; then
  entry=$(jq -r --arg p "$DIR" '.projects[]? | select(.path==$p) | .name' "$REGISTRY" 2>/dev/null)
  if [ -z "$entry" ]; then
    finding major S "this path is absent from the registry (${REGISTRY}) -- re-run /harness:harness-init to register it"
  else
    scope=$(jq -r --arg p "$DIR" '.projects[]? | select(.path==$p) | .scope // "shared"' "$REGISTRY")
    case "$scope" in shared|local) ;; *) finding minor S "registry scope for '${entry}' is '${scope}'; expected shared or local" ;; esac
  fi
fi

# ---- T: promotion-candidate hygiene ------------------------------------------
promo="${DIR}/ai-docs/learnings/.promote"
if [ -d "$promo" ]; then
  for f in "$promo"/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in README.md) continue ;; esac
    bash "$CHECK" "$f" --project-dir "$DIR" --quiet 2>/dev/null \
      || finding major T "candidate $(basename "$f" .md) is refused by the redaction gate; it will never be swept"
  done
fi

# ---- U: gitignore coverage ---------------------------------------------------
if [ -d "${DIR}/.git" ]; then
  probe="ai-docs/plans/__audit_probe.progress.md"
  mkdir -p "${DIR}/ai-docs/plans"
  : > "${DIR}/${probe}"
  if ! git -C "$DIR" check-ignore -q "$probe" 2>/dev/null; then
    finding blocker U ".gitignore does not ignore ai-docs/plans/**/*.progress.md -- working state would be committed"
  fi
  rm -f "${DIR}/${probe}"
else
  finding minor U "not a git repo; gitignore coverage unverified"
fi

exit $([ "$blockers" -gt 0 ] && echo 1 || echo 0)
