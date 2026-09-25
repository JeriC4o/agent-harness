#!/usr/bin/env bash
#
# Tests for check-readme-update.sh.
#
# Run: bash scripts/test-check-readme-update.sh
#
# The checker it covers is a deny-list, and a deny-list has one characteristic
# failure: it stops matching and goes quiet, which reads exactly like a clean
# repository. So every leg here plants a defect whose correct answer is known
# independently, and asserts on the finding CLASS and the SECTION it names --
# not merely on the exit status, which every leg would share.
#
# Two kinds of input, deliberately:
#
#   - a FROZEN heredoc of the README as it stood at bb81cd6 (the commit this
#     branch forked from, identical to origin/main at the time). That is the
#     historical defect this ticket exists for, and it must not track the
#     README: once this PR merges the live file is the CORRECTED text, and a
#     fixture regenerated from it would invert the leg it anchors.
#   - MUTATIONS generated from the live README.md at run time. These cannot
#     rot: each run re-copies the shipped file before mutating the copy, so a
#     checker that stopped seeing the real file fails here rather than passing.
#     Each mutation is verified to have actually changed something -- a
#     mutation leg that mutated nothing is a green that measures nothing.
#
# The live README.md is never edited: mutations happen on copies inside a temp
# tree reached through the checker's own --root flag.

set -uo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-readme-update.sh"
ROOT=$(cd -- "${HERE}/.." && pwd)

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- expected [$3]" ;; esac; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

# Findings arrive as CLASS|line|message. Line numbers move with every README
# edit, so they are dropped; class plus the first word of the message (the
# section name, or "section" for the file-scoped D3) is the stable identity.
classes() {
  printf '%s\n' "$1" \
    | sed -n 's/^ *\([A-Z][0-9]\)|[0-9]*|\([A-Za-z]*\).*/\1:\2/p' \
    | sort -u | tr '\n' ' ' | sed 's/ *$//'
}

run() { OUT=$(bash "$CHECK" --root "$1" 2>&1); RC=$?; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM

printf '\n== the frozen defect: README.md as of bb81cd6 ==\n'
FROZEN="$T/frozen"; mkdir -p "$FROZEN"
cat > "$FROZEN/README.md" <<'FIXTURE_EOF'
# agent-harness

## Install

One-time, per machine:

```bash
/plugin marketplace add JeriC4o/agent-harness
/plugin install harness@agent-harness
```

| Scope | Command | Use when |
|---|---|---|
| User | `claude plugin install harness@agent-harness --scope user` | You work across many repos. |

## Update

```bash
/plugin marketplace update agent-harness
```

Your project profile is untouched by an update — it lives in your repo, not in the plugin. If a new
harness version adds template files, `/harness:harness-init` picks them up on a re-run without disturbing
anything you have edited.

## Releasing

**Bump the patch version in the same PR as any change to plugin-loaded content** — `skills/`, `agents/`,
`rules/`, `hooks/`, `docs/`, `scripts/`, `templates/`.

Consumers update with:

```bash
claude plugin marketplace update agent-harness
claude plugin install harness@agent-harness --scope user
```

Then restart the session — hooks are read at start.
FIXTURE_EOF

run "$FROZEN"
check "the historical README is refused" "$RC" "1"
check "  every class it earned, and no more" "$(classes "$OUT")" "D1:Releasing D2:Releasing D2:Update D3:section"

printf '\n== mutations of the live README.md ==\n'
UPDATE_VERB='claude plugin update harness@agent-harness'
mutate() {
  if cmp -s "$ROOT/README.md" "$T/README.md"; then
    bad "$1 -- the mutation changed nothing; the README no longer carries what it edits"
    return 1
  fi
  return 0
}

mkdir -p "$T/m"
sed "s|^${UPDATE_VERB}\$|claude plugin install harness@agent-harness|" "$ROOT/README.md" > "$T/README.md"
if mutate "the upgrade verb swapped for install"; then
  cp "$T/README.md" "$T/m/README.md"; run "$T/m"
  check "the upgrade verb swapped for install" "$RC" "1"
  check "  D1, and the section left with no verb" "$(classes "$OUT")" "D1:Update D2:Update D3:section"
fi

sed "/^${UPDATE_VERB}\$/d" "$ROOT/README.md" > "$T/README.md"
if mutate "the upgrade verb deleted outright"; then
  cp "$T/README.md" "$T/m/README.md"; run "$T/m"
  check "the upgrade verb deleted outright" "$RC" "1"
  check "  a bare metadata refresh, and D3" "$(classes "$OUT")" "D2:Update D3:section"
fi

# A section that does not exist yet is the case a check scoped to Update would
# miss entirely, which is why this checker reads the whole file.
cp "$ROOT/README.md" "$T/README.md"
cat >> "$T/README.md" <<'UPGRADING_EOF'

## Upgrading

```bash
claude plugin install harness@agent-harness
```
UPGRADING_EOF
if mutate "a NEW section documents install as the upgrade"; then
  cp "$T/README.md" "$T/m/README.md"; run "$T/m"
  check "a NEW section documents install as the upgrade" "$RC" "1"
  check "  named by its own heading" "$(classes "$OUT")" "D1:Upgrading"
fi

cat > "$T/old-releasing.txt" <<'RELEASING_EOF'
Consumers update with:

```bash
claude plugin marketplace update agent-harness
claude plugin install harness@agent-harness --scope user
```

Then restart the session — hooks are read at start.
RELEASING_EOF
awk -v repl="$T/old-releasing.txt" '
  /^Consumers update with the procedure/ { while ((getline l < repl) > 0) print l; next }
  { print }
' "$ROOT/README.md" > "$T/README.md"
if mutate "the old block restored into Releasing"; then
  cp "$T/README.md" "$T/m/README.md"; run "$T/m"
  check "the old block restored into Releasing" "$RC" "1"
  check "  caught outside Update too" "$(classes "$OUT")" "D1:Releasing D2:Releasing"
fi

printf '\n== the Install exemption, asserted positively ==\n'
cp "$ROOT/README.md" "$T/m/README.md"; run "$T/m"
check "an unmutated copy is clean" "$RC" "0"
check "  with nothing reported" "$(classes "$OUT")" ""
# Without this, a green above is indistinguishable from one earned by the fence
# having been deleted: the exemption would be covering nothing.
fenced_install=$(awk '/^## /{s=substr($0,4)} /^```/{f=!f;next} f&&s=="Install"&&/plugin[ \t]+install/' "$ROOT/README.md")
has "  and section Install still fences an install command" "$fenced_install" "plugin install harness@agent-harness"

printf '\n== fences the scanner must not be blind to ==\n'
# A deny-list keyed on one fence spelling is a deny-list with a documented way
# round it. Neither spelling appears in the README today, which is exactly why
# a reader adding one would get a green.
cp "$ROOT/README.md" "$T/m/README.md"
cat >> "$T/m/README.md" <<'TILDE_EOF'

## Upgrading

~~~bash
claude plugin install harness@agent-harness --scope user
~~~
TILDE_EOF
run "$T/m"
check "a tilde fence still hides nothing" "$RC" "1"
check "  named by its own heading" "$(classes "$OUT")" "D1:Upgrading"

cp "$ROOT/README.md" "$T/m/README.md"
cat >> "$T/m/README.md" <<'INDENT_EOF'

## Upgrading

- first, upgrade:

   ```bash
   claude plugin install harness@agent-harness --scope user
   ```
INDENT_EOF
run "$T/m"
check "an indented fence still hides nothing" "$RC" "1"
check "  named by its own heading" "$(classes "$OUT")" "D1:Upgrading"

printf '\n== the analyser must run, or the gate must refuse ==\n'
# The characteristic failure of `out=$(awk ...)`: an empty `out` means both "no
# findings" and "awk never ran". The gate carries two guards against it, and
# they are NOT redundant -- a preflight cannot see an awk that exists and then
# fails, nor one present but not executable (`command -v` succeeds, the run
# exits 126). Each leg is keyed to a string emitted by exactly ONE branch of the
# gate: `its absence` by the preflight, `not a clean result` by the awk_rc
# guard. That coupling is what makes a dropped guard redden its own leg. Reword
# either message, or reduce a leg to an rc check, and the leg stops
# discriminating -- silently, in the delete-the-preflight direction, where the
# surviving guard also returns 2.
BIN="$T/thin-bin"; mkdir -p "$BIN"
for b in bash sed dirname cat; do
  p=$(command -v "$b") && case "$p" in /*) ln -s "$p" "$BIN/$b" ;; esac
done

noawk=$(env PATH="$BIN" bash "$CHECK" 2>&1); noawk_rc=$?
check "no awk on PATH -> 2, not a pass" "$noawk_rc" "2"
has "  and it names the absent analyser" "$noawk" "do not treat its absence as a pass"

# awk PRESENT but failing -- unreachable by the preflight, so this leg is the
# only thing standing between a broken awk and a success message.
printf '#!/bin/sh\nexit 3\n' > "$BIN/awk"; chmod +x "$BIN/awk"
brokenawk=$(env PATH="$BIN" bash "$CHECK" 2>&1); brokenawk_rc=$?
check "awk present but failing -> 2, not a pass" "$brokenawk_rc" "2"
has "  and it says the README went unread" "$brokenawk" "not a clean result"

printf '\n== usage ==\n'
bash "$CHECK" --root /nonexistent >/dev/null 2>&1; check "missing root -> 2" "$?" "2"
mkdir -p "$T/empty"
bash "$CHECK" --root "$T/empty" >/dev/null 2>&1; check "root without a README -> 2" "$?" "2"
bash "$CHECK" --nonsense >/dev/null 2>&1; check "unknown flag -> 2" "$?" "2"
bash "$CHECK" --root >/dev/null 2>&1; check "valueless --root -> 2" "$?" "2"

printf '\n== this repository is clean ==\n'
out=$(bash "$CHECK" 2>&1); rc=$?
check "repo -> rc 0" "$rc" "0"
[ "$rc" = "0" ] || printf '%s\n' "$out"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
