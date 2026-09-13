#!/usr/bin/env bash
#
# Tests for audit-project.sh — the mechanical half of a project-scope audit.
# Run from anywhere:  bash scripts/test-audit-project.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
AUDIT="${HERE}/audit-project.sh"
SCAFFOLD="${HERE}/../skills/harness-init/scripts/scaffold.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing [$3] in: $2)" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected [$3])" ;; *) ok "$1" ;; esac; }

REG=$(mktemp -d)/registry.json
fresh() { # -> scaffolded project dir
  d=$(mktemp -d)/proj; mkdir -p "$d"; git -C "$d" init -q -b main
  printf 'all:\n' > "$d/Makefile"
  HARNESS_REGISTRY="$REG" bash "$SCAFFOLD" "$d" --name proj --ticket-prefix PRJ >/dev/null 2>&1
  printf '%s' "$d"
}
audit() { HARNESS_REGISTRY="$REG" bash "$AUDIT" "$1" 2>&1; }

printf '\n== a freshly scaffolded project is full of placeholders, and says so ==\n'
P=$(fresh)
out=$(audit "$P"); rc=$?
check "blockers present -> rc 1" "$rc" "1"
has "flags unresolved placeholders" "$out" "placeholder"
has "  names AGENTS.md"             "$out" "AGENTS.md"

printf '\n== a filled-in profile passes ==\n'
Q=$(fresh)
python3 - "$Q" <<'PY'
import sys,re,pathlib
d=pathlib.Path(sys.argv[1])
a=d/'AGENTS.md'; t=a.read_text()
t=t.replace('| `%BUILD_CMD%` | Compile the changed module | `%FILL_ME%` |','| `%BUILD_CMD%` | Compile the changed module | `make build` |')
t=t.replace("| `%TEST_CMD%` | Run a module's tests (+ the filter syntax for one test) | `%FILL_ME%` |","| `%TEST_CMD%` | Run a module's tests | `make test` |")
t=t.replace('| `%FORMAT_CMD%` | Auto-format changed files (NOT a gate) | `%FILL_ME%` |','| `%FORMAT_CMD%` | Auto-format changed files | `make fmt` |')
t=t.replace('| `%LINT_CMD%` | Lint as the gate (exits non-zero on violations) | `%FILL_ME%` |','| `%LINT_CMD%` | Lint as the gate | `make lint` |')
t=t.replace('| `<module-path>` | How a module is addressed on the command line | `%FILL_ME%` |','| `<module-path>` | How a module is addressed | `a directory` |')
t=t.replace('%TICKET_PREFIX%','PRJ')
a.write_text(t)
c=d/'ai-docs'/'context.md'; x=c.read_text()
x=re.sub(r'%[A-Z_]+%','filled',x)
c.write_text(x)
PY
out=$(audit "$Q"); rc=$?
check "no blockers -> rc 0" "$rc" "0"
hasnt "no placeholder finding" "$out" "unresolved placeholder"

printf '\n== command liveness is checked, not assumed ==\n'
R=$(fresh)
sed -i '' 's/| `%BUILD_CMD%` | Compile the changed module | `%FILL_ME%` |/| `%BUILD_CMD%` | Compile the changed module | `definitelynotarealbinary build` |/' "$R/AGENTS.md"
out=$(audit "$R")
has "flags a command whose binary does not exist" "$out" "definitelynotarealbinary"

printf '\n== registry coherence ==\n'
S=$(mktemp -d)/unregistered; mkdir -p "$S"; git -C "$S" init -q -b main
HARNESS_REGISTRY="$REG" bash "$SCAFFOLD" "$S" --name unreg >/dev/null 2>&1
jq 'del(.projects[] | select(.name=="unreg"))' "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
out=$(audit "$S")
has "flags a project missing from the registry" "$out" "registry"

printf '\n== promotion candidates are re-gated ==\n'
T=$(fresh)
cat > "$T/ai-docs/learnings/.promote/leaky.md" <<'EOF'
---
id: leaky
category: tooling
kind: correction
created: 2026-09-14
---

**Rule:** The proj pipeline needs a positive control.

**Why:** Because.

**Signal:** A thing.
EOF
out=$(audit "$T")
has "flags a candidate that fails the gate" "$out" "leaky"

printf '\n== gitignore coverage is verified against git, not by reading ==\n'
U=$(fresh)
printf 'node_modules/\n' > "$U/.gitignore"   # harness block removed
out=$(audit "$U")
has "flags a missing gitignore block" "$out" "gitignore"

printf '\n== usage ==\n'
bash "$AUDIT" >/dev/null 2>&1;              check "no args -> 2" "$?" "2"
bash "$AUDIT" /nonexistent >/dev/null 2>&1; check "missing dir -> 2" "$?" "2"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
