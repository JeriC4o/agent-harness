#!/usr/bin/env bash
#
# Tests for the promotion boundary: check-candidate.sh (the redaction gate) and
# collect-candidates.sh (the cross-project sweep). Run from anywhere:
#   bash scripts/test-promotion.sh
#
# The contract under test: a lesson may cross from one project into the shared
# harness ONLY as an abstracted candidate carrying no project identifier, and
# the sweep may read NOTHING except candidate files that pass the gate.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
CHECK="${HERE}/check-candidate.sh"
COLLECT="${HERE}/collect-candidates.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want [$3], got [$2])"; fi; }

# A project whose vocabulary the gate must learn: name, ticket prefix, entities.
mkproject() { # <name> -> prints dir
  d=$(mktemp -d)/"$1"; mkdir -p "$d/ai-docs/learnings/.promote"
  git -C "$(dirname "$d")" init -q -b main 2>/dev/null || true
  cat > "$d/ai-docs/context.md" <<'CTX'
# ctx
# System Entities
## DiffSet
- **What it is.** A thing.
## ReviewRequest
- **What it is.** Another thing.
CTX
  printf '%s' "$d"
}

candidate() { # <dir> <slug> <body>
  cat > "$1/ai-docs/learnings/.promote/$2.md" <<EOF
---
id: $2
category: tooling
kind: correction
created: 2026-09-14
---

**Rule:** $3

**Why:** A gate that cannot fail is not a gate.

**Signal:** A verification command whose failure mode is empty output.
EOF
}

P=$(mkproject widgetron)

printf '\n== gate: a clean candidate passes ==\n'
candidate "$P" clean-one "Run every verification command against input engineered to make it fail."
bash "$CHECK" "$P/ai-docs/learnings/.promote/clean-one.md" --project-dir "$P" >/dev/null 2>&1
check "clean candidate -> 0" "$?" "0"

printf '\n== gate: project identifiers are refused ==\n'
refuse() { # <slug> <body> <label>
  candidate "$P" "$1" "$2"
  out=$(bash "$CHECK" "$P/ai-docs/learnings/.promote/$1.md" --project-dir "$P" 2>&1); rc=$?
  if [ "$rc" = "1" ]; then ok "refuses $3"; else bad "refuses $3 (rc=$rc)"; fi
  case "$out" in *"$4"*) ok "  names the offending term ($4)" ;; *) bad "  names the offending term ($4): $out" ;; esac
}
refuse repo-name  "The widgetron build caches aggressively, so always clean first." "the repo name"   "widgetron"
refuse ticket-key "Seen in WIDG-4471 where the gate never ran."                     "a ticket key"    "WIDG-4471"
refuse file-path  "The bug was in server/core/src/main/Foo.kt line 12."              "a file path"     "server/core"
refuse entity     "A DiffSet must never be mutated after finalisation."             "a domain entity" "DiffSet"
refuse url        "See https://internal.example.com/wiki/page for the details."      "an internal URL" "internal.example.com"

printf '\n== gate: terms match as WORDS, not substrings ==\n'
# A short ticket prefix (ORD) must not refuse ordinary words that contain it
# (record, coordinate, order) -- that would make the gate unusable for any
# project with a 3-letter prefix. The KEY-123 form is still caught, both by
# word-boundary matching and by the structural ticket-key check.
W=$(mkproject orderflow)
printf '%s' "$W" >/dev/null
cat > "$W/ai-docs/learnings/.promote/wordy.md" <<'EOF'
---
id: wordy
category: process
kind: correction
created: 2026-09-14
---

**Rule:** Record the decision before you coordinate the rollout, in that order.

**Why:** An unrecorded decision is re-litigated.

**Signal:** Two people describing the same choice differently.
EOF
HARNESS_REGISTRY=$(mktemp -d)/r.json
printf '{"version":1,"projects":[{"path":"%s","name":"orderflow","ticket_prefix":"ORD","scope":"shared"}]}' "$W" > "$HARNESS_REGISTRY"
HARNESS_REGISTRY="$HARNESS_REGISTRY" bash "$CHECK" "$W/ai-docs/learnings/.promote/wordy.md" --project-dir "$W" >/dev/null 2>&1
check "prefix ORD does not refuse 'record'/'coordinate'/'order'" "$?" "0"
candidate "$W" realkey "The check was skipped in ORD-91 and nobody noticed."
HARNESS_REGISTRY="$HARNESS_REGISTRY" bash "$CHECK" "$W/ai-docs/learnings/.promote/realkey.md" --project-dir "$W" >/dev/null 2>&1
check "but ORD-91 is still refused" "$?" "1"

printf '\n== gate: extra deny terms are honoured ==\n'
printf 'projectcodename\n' > "$P/ai-docs/learnings/.promote/deny-extra.txt"
candidate "$P" extra-term "The projectcodename pipeline needs a positive control."
bash "$CHECK" "$P/ai-docs/learnings/.promote/extra-term.md" --project-dir "$P" >/dev/null 2>&1
check "deny-extra.txt term refused" "$?" "1"
rm -f "$P/ai-docs/learnings/.promote/deny-extra.txt"

printf '\n== gate: structure is required ==\n'
printf -- '---\nid: x\n---\n\njust prose\n' > "$P/ai-docs/learnings/.promote/broken.md"
bash "$CHECK" "$P/ai-docs/learnings/.promote/broken.md" --project-dir "$P" >/dev/null 2>&1
check "missing Rule/Why/Signal -> 1" "$?" "1"
bash "$CHECK" >/dev/null 2>&1; check "no args -> 2" "$?" "2"
bash "$CHECK" /nope.md --project-dir "$P" >/dev/null 2>&1; check "missing file -> 2" "$?" "2"

printf '\n== sweep: only shared, existing projects, only passing candidates ==\n'
REG=$(mktemp -d)/registry.json
Q=$(mkproject fabricator)
L=$(mkproject clientwork)
candidate "$Q" clean-one "Run every verification command against input engineered to make it fail."
candidate "$L" clean-one "Run every verification command against input engineered to make it fail."
candidate "$Q" leaky     "The fabricator release step is the one that matters."
jq -n --arg p "$P" --arg q "$Q" --arg l "$L" '{version:1,projects:[
   {path:$p,name:"widgetron",ticket_prefix:"WIDG",scope:"shared"},
   {path:$q,name:"fabricator",ticket_prefix:"FAB",scope:"shared"},
   {path:$l,name:"clientwork",ticket_prefix:"CW",scope:"local"},
   {path:"/nonexistent/gone",name:"gone",ticket_prefix:"X",scope:"shared"}]}' > "$REG"

out=$(HARNESS_REGISTRY="$REG" bash "$COLLECT" 2>/dev/null)
n=$(printf '%s' "$out" | jq -s 'length')
check "emits only passing candidates from shared, existing projects" "$n" "3"
printf '%s' "$out" | jq -se 'map(.project) | sort | join(",")' | grep -q 'fabricator' && ok "includes a shared project" || bad "includes a shared project"
printf '%s' "$out" | grep -q 'clientwork' && bad "excludes scope:local" || ok "excludes scope:local"
printf '%s' "$out" | grep -q 'fabricator release step' && bad "excludes a candidate that fails the gate" || ok "excludes a candidate that fails the gate"

warn=$(HARNESS_REGISTRY="$REG" bash "$COLLECT" 2>&1 >/dev/null)
case "$warn" in *gone*)   ok "warns about a missing project path" ;; *) bad "warns about a missing project path" ;; esac
case "$warn" in *leaky*)  ok "warns about a rejected candidate" ;;   *) bad "warns about a rejected candidate" ;; esac

printf '\n== sweep: empty registry is not an error ==\n'
EMPTY=$(mktemp -d)/r.json; printf '{"version":1,"projects":[]}' > "$EMPTY"
out=$(HARNESS_REGISTRY="$EMPTY" bash "$COLLECT" 2>/dev/null); rc=$?
check "empty registry -> 0" "$rc" "0"
check "empty registry -> no output" "$out" ""

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
