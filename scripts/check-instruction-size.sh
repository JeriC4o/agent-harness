#!/usr/bin/env bash
#
# Does every instruction file that loads whole at agent start keep the early-
# warning headroom the size AXIOM promises?
#
# Run:  check-instruction-size.sh [--root <dir>]
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-instruction-size.sh
#
# WHY THIS GATE EXISTS. docs/agents-method.md § Build & Test caps the files an
# agent loads whole at 40,000 characters, with a 35,000 early warning meant to
# leave the next task room to add a rule. The warning was prose, so six files
# drifted to within a few hundred characters of it and a one-clause edit pushed
# two past it. Reddening at the warning makes the headroom something a task
# cannot close without.
#
# WHAT IT READS. The whole-load class as that AXIOM lists it, here and in the
# scaffold a consuming project starts from. A page reached only by link is
# outside the class by design: it is where extracted text lands.
#
# CHARACTERS, NOT BYTES. The AXIOM counts characters; `wc -c` counts bytes, and
# the dashes and arrows these files use are three bytes each.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
WARN=35000
CAP=40000

while [ $# -gt 0 ]; do
  case $1 in
    --root)
      [ -d "${2:-}" ] || { printf 'check-instruction-size: no such directory: %s\n' "${2:-}" >&2; exit 2; }
      ROOT=$(cd -- "$2" && pwd); shift 2 ;;
    *) printf 'check-instruction-size: usage: check-instruction-size.sh [--root <dir>]\n' >&2; exit 2 ;;
  esac
done

for t in git python3; do
  command -v "$t" >/dev/null 2>&1 \
    || { printf 'check-instruction-size: cannot run -- %s is not on PATH. A missing tool is not a pass.\n' "$t" >&2; exit 2; }
done
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
  || { printf 'check-instruction-size: cannot run -- %s is not a git working tree\n' "$ROOT" >&2; exit 2; }

OUT=$(python3 -B -c '
import fnmatch, os, subprocess, sys

root, warn, cap = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
def listed(*extra):
    raw = subprocess.run(["git", "-C", root, "ls-files", "-z"] + list(extra),
                         capture_output=True, check=True).stdout
    return [p for p in raw.decode("utf-8", "replace").split("\0") if p]
paths = sorted(set(listed() + listed("-o", "--exclude-standard")))

WHOLE = ["AGENTS.md", "CLAUDE.md", "CLAUDE.local.md", "ai-docs/context.md",
         "docs/agents-method.md", "agents/*.md", "skills/*/SKILL.md",
         ".claude/agents/*.md", ".claude/skills/*/SKILL.md",
         "templates/project/AGENTS.md", "templates/project/CLAUDE.md",
         "templates/project/ai-docs/context.md"]
def whole(p):
    return any(fnmatch.fnmatchcase(p, g) and p.count("/") == g.count("/") for g in WHOLE)

rows, bad = [], []
for p in paths:
    if not whole(p) or not os.path.exists(root + "/" + p):
        continue
    try:
        with open(root + "/" + p, encoding="utf-8", newline="") as fh:
            n = len(fh.read())
    except (OSError, UnicodeDecodeError) as e:
        print("check-instruction-size: cannot read %s: %s" % (p, e), file=sys.stderr)
        sys.exit(2)
    rows.append((n, p))
    if n >= cap:
        bad.append("%s: %d chars -- over the %d cap" % (p, n, cap))
    elif n >= warn:
        bad.append("%s: %d chars -- inside the %d-%d warning band" % (p, n, warn, cap - 1))

for line in bad:
    print(line)
if not rows:
    print("check-instruction-size: verdict=cannot-run files=0 -- no whole-load file found")
    sys.exit(2)
top = max(rows)
print("check-instruction-size: verdict=%s files=%d over=%d largest=%s:%d headroom=%d"
      % ("findings" if bad else "clean", len(rows), len(bad), top[1], top[0], warn - top[0]))
sys.exit(1 if bad else 0)
' "$ROOT" "$WARN" "$CAP")
rc=$?
[ -n "$OUT" ] && printf '%s\n' "$OUT"
# A crash in the body also exits 1; without its verdict line that is a
# cannot-run, never a finding.
case $OUT in *'check-instruction-size: verdict='*) exit "$rc" ;; esac
printf 'check-instruction-size: cannot run -- the scan ended (rc %s) without a verdict\n' "$rc" >&2
exit 2
