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

printf '\n== gate: t2 -- the rule-mode refusal trailer is byte-identical ==\n'
# Nothing asserted this string in either mode before t1/t2, so a reword was
# invisible. The assertion pins the gate's own half only: skills/improve/SKILL.md
# describes the same action in different words rather than quoting it, so no
# assertion here can see that file drift.
candidate "$P" trailer "The bug was in server/core/src/main/Foo.kt line 12."
out=$(bash "$CHECK" "$P/ai-docs/learnings/.promote/trailer.md" --project-dir "$P" 2>&1); rc=$?
check "t2  a rule-mode refusal -> 1" "$rc" "1"
case "$out" in
  *"  Rewrite the lesson so it names the SHAPE of the failure, not the instance."*)
    ok "  t2 keeps the rule-mode trailer byte-for-byte" ;;
  *) bad "  t2 keeps the rule-mode trailer byte-for-byte: $out" ;;
esac
case "$out" in
  *"let the user decide"*) bad "  t2 stays silent about the report-mode trailer: $out" ;;
  *) ok "  t2 stays silent about the report-mode trailer" ;;
esac

# ---- report mode ------------------------------------------------------------
# The suite pins its OWN harness root instead of letting the $0 derivation land
# on the worktree. A consuming project resolves the root to the installed
# plugin, and the two trees do not ship the same files -- skills/report-defect/
# exists in the worktree and in no released copy -- so a verdict measured
# against the worktree is not the verdict production gets.
FIXROOT=$(mktemp -d)
mkdir -p "$FIXROOT/.claude-plugin" "$FIXROOT/docs" "$FIXROOT/scripts" "$FIXROOT/hooks/lib" \
         "$FIXROOT/skills/inspect" "$FIXROOT/skills/report-defect" "$FIXROOT/ai-docs"
printf '{"name":"harness","version":"0.0.0"}\n' > "$FIXROOT/.claude-plugin/plugin.json"
printf '# method\n'                             > "$FIXROOT/docs/agents-method.md"
printf '#!/usr/bin/env bash\n'                  > "$FIXROOT/scripts/session-events.sh"
cp "$CHECK"                                       "$FIXROOT/scripts/check-candidate.sh"
printf '#!/usr/bin/env bash\n'                  > "$FIXROOT/hooks/lib/harness-managed.sh"
printf '# inspect\n'                            > "$FIXROOT/skills/inspect/SKILL.md"
printf '# report-defect\n'                      > "$FIXROOT/skills/report-defect/SKILL.md"
printf '# ctx\n'                                > "$FIXROOT/ai-docs/context.md"
printf '# agents\n'                             > "$FIXROOT/AGENTS.md"

R=$(mkproject reportville); mkdir -p "$R/ai-docs/feedback"

report() { # <path> <surface> <evidence>
  mkdir -p "$(dirname -- "$1")"
  cat > "$1" <<EOF
---
id: r
harness_version: 0.0.0
hash: 0123456789ab
created: 2026-09-25
---

**Symptom:** The gate stayed silent.

**Repro:** Run the gate twice.

**Expected:** A named refusal.

**Surface:** $2

**Evidence:** $3
EOF
}

ENVROOT=1; BRANCH=''
rrun() { # <report path> [args...]
  if [ "$ENVROOT" -eq 1 ]
    then CLAUDE_PLUGIN_ROOT="$FIXROOT" bash "$CHECK" "$@" --mode report 2>&1
    else env -u CLAUDE_PLUGIN_ROOT bash "$FIXROOT/scripts/check-candidate.sh" "$@" --mode report 2>&1
  fi
}

row() { # <label> <surface> <evidence> <want rc> <must name> <must not name>
  report "$R/ai-docs/feedback/row.md" "$2" "$3"
  out=$(rrun "$R/ai-docs/feedback/row.md" --project-dir "$R"); rc=$?
  check "${BRANCH}$1" "$rc" "$4"
  if [ -n "$5" ]; then
    case "$out" in *"$5"*) ok "  ${BRANCH}$1 names [$5]" ;; *) bad "  ${BRANCH}$1 names [$5]: $out" ;; esac
  fi
  if [ -n "$6" ]; then
    case "$out" in *"$6"*) bad "  ${BRANCH}$1 stays silent about [$6]: $out" ;; *) ok "  ${BRANCH}$1 stays silent about [$6]" ;; esac
  fi
}

path_table() {
  row "r1  scripts/session-events.sh:14 (AC5 row 1)" 'scripts/session-events.sh:14' 'The run ended at zero.'          "0" '' ''
  row "r2  myproject/scripts/deploy-prod.sh (AC5 row 2)" 'scripts/session-events.sh' 'Also in myproject/scripts/deploy-prod.sh here.' "1" 'myproject/scripts/deploy-prod.sh' ''
  row "r3  server/core/Merge.kt (AC5 row 3)"         'scripts/session-events.sh' 'Also in server/core/Merge.kt here.' "1" 'server/core/Merge.kt' ''
  row "r4  .claude-plugin/plugin.json"               '.claude-plugin/plugin.json' 'The manifest was not read.'        "0" '' ''
  row "r5  hooks/lib/harness-managed.sh"             'hooks/lib/harness-managed.sh' 'The helper returned nothing.'    "0" '' ''
  row "r6  ../../etc/passwd"                         'scripts/session-events.sh' 'It then read ../../etc/passwd too.' "1" 'parent traversal' ''
  row "r7  trailing sentence punctuation"            'scripts/session-events.sh' 'The fault is in scripts/session-events.sh.' "0" '' ''
  row "r8  /Users/someone/acmecorp/src/Foo.kt"       'scripts/session-events.sh' 'It read /Users/someone/acmecorp/src/Foo.kt first.' "1" 'absolute path' ''
  row "r9  nine prose slash pairs"                   'scripts/session-events.sh' 'read/write and/or client/server GET/POST input/output he/she N/A 24/7 TCP/IP' "0" '' ''
  row "r10 skills/inspect/SKILL.md"                  'skills/inspect/SKILL.md' 'The skill never loaded.'              "0" '' ''
  row "r11 skills/report-defect/SKILL.md"            'skills/report-defect/SKILL.md' 'The skill never loaded.'        "0" '' ''
  row "r12 2026/09/24 is a date"                     'scripts/session-events.sh' 'First seen on 2026/09/24 in a run.' "0" '' ''
  row "r13 ai-docs/context.md:14 warns"              'scripts/session-events.sh' 'It also read ai-docs/context.md:14 there.' "0" 'ambiguity warning' ''
  row "r14 Surface names a project path"             'myproject/src/Foo.kt' 'The run ended at zero.'                  "1" 'Surface names no path' ''
  row "r15 Surface names prose"                      'read/write' 'The run ended at zero.'                            "1" 'Surface names no path' 'file path'
  row "r16 three-term prose runs"                    'scripts/session-events.sh' 'read/write/execute input/output/error client/server/proxy he/she/they' "1" 'file path' ''
  row "r17 services/billing"                         'scripts/session-events.sh' 'The services/billing step ran late.' "0" '' ''
  row "r18 prose Surface, permitted Evidence"        'read/write' 'The file scripts/session-events.sh never ran.'     "1" 'Surface names no path' ''
  row "r19 permitted claim, no warning"              'scripts/check-candidate.sh' 'The run ended at zero.'            "0" '' 'ambiguity warning'
  # r20 is the only row that reads on the existence check itself: its first
  # segment IS a harness directory name, so the rejected anchored alternation
  # permits it while the shipped gate refuses it. r1 is its positive control --
  # same first segment, token present.
  row "r20 scripts/deploy-prod.sh, absent under the root" 'scripts/session-events.sh' 'Also in scripts/deploy-prod.sh here.' "1" 'scripts/deploy-prod.sh' ''
  # r21 and its control differ by one punctuation character, so the pair reads on
  # the token regex's left anchor and on nothing else. The fixture project's
  # vocabulary holds none of src/main/billing/Invoice, or the vocabulary leg
  # would refuse the token whatever the anchor did.
  row "r21 parenthesised non-harness path"           'scripts/session-events.sh' 'Also in (src/main/billing/Invoice.kt) here.' "0" '' 'src/main/billing/Invoice.kt'
  row "r21 control: unparenthesised"                 'scripts/session-events.sh' 'Also in src/main/billing/Invoice.kt here.' "1" 'src/main/billing/Invoice.kt' ''
  row "t1  report-mode refusal trailer"              'scripts/session-events.sh' 'Also in scripts/deploy-prod.sh here.' "1" 'let the user decide' 'Rewrite the lesson'
  row "positive control: Surface names a harness path" 'scripts/session-events.sh' 'The run ended at zero.'           "0" '' 'structure'
}

printf '\n== gate: report-mode path table, CLAUDE_PLUGIN_ROOT pinned to the fixture root ==\n'
ENVROOT=1; BRANCH=''; path_table

printf '\n== gate: the same table through the production $0 derivation ==\n'
ENVROOT=0; BRANCH='$0: '; path_table
ENVROOT=1; BRANCH=''

printf '\n== gate: AC1 -- the two new paths in both modes ==\n'
candidate "$P" ac1-script "The fault is in scripts/session-events.sh line 14."
out=$(bash "$CHECK" "$P/ai-docs/learnings/.promote/ac1-script.md" --project-dir "$P" 2>&1); rc=$?
check "rule mode still refuses scripts/session-events.sh" "$rc" "1"
case "$out" in *"file path"*) ok "  as a file path finding" ;; *) bad "  as a file path finding: $out" ;; esac
candidate "$P" ac1-manifest "The fault is in .claude-plugin/plugin.json instead."
out=$(bash "$CHECK" "$P/ai-docs/learnings/.promote/ac1-manifest.md" --project-dir "$P" 2>&1); rc=$?
check "rule mode still refuses .claude-plugin/plugin.json" "$rc" "1"
case "$out" in *"file path"*) ok "  as a file path finding" ;; *) bad "  as a file path finding: $out" ;; esac

printf '\n== gate: AC2 -- every identifier class still refuses in report mode ==\n'
RREG=$(mktemp -d)/r.json
printf '{"version":1,"projects":[{"path":"%s","name":"orderflow","ticket_prefix":"ORD","scope":"shared"}]}' "$R" > "$RREG"
ident() { # <label> <evidence> <must name>
  report "$R/ai-docs/feedback/ident.md" 'scripts/session-events.sh' "$2"
  out=$(HARNESS_REGISTRY="$RREG" CLAUDE_PLUGIN_ROOT="$FIXROOT" bash "$CHECK" "$R/ai-docs/feedback/ident.md" --mode report --project-dir "$R" 2>&1); rc=$?
  if [ "$rc" = "1" ]; then ok "report mode refuses $1"; else bad "report mode refuses $1 (rc=$rc) $out"; fi
  case "$out" in *"$3"*) ok "  names the offending term ($3)" ;; *) bad "  names the offending term ($3): $out" ;; esac
}
ident "the project dir name" "The reportville checkout is where it happened." "reportville"
ident "the registry name"    "The orderflow checkout is where it happened."   "orderflow"
ident "the ticket prefix"    "Filed under the ORD prefix by the reporter."    "ORD"
ident "a KEY-123 token"      "Filed as ZZQ-4471 by the reporter."             "ZZQ-4471"
ident "a context.md entity"  "A DiffSet was mutated after finalisation."      "DiffSet"
printf 'projectcodename\n' > "$R/ai-docs/learnings/.promote/deny-extra.txt"
ident "a deny-extra.txt term" "The projectcodename pipeline stalled."         "projectcodename"
rm -f "$R/ai-docs/learnings/.promote/deny-extra.txt"
ident "a URL host"           "See https://internal.example.com/wiki/page too." "internal.example.com"

printf '\n== gate: AC3 -- each required section and frontmatter key, omitted in turn ==\n'
omit() { # <marker>
  report "$R/ai-docs/feedback/omit.md" 'scripts/session-events.sh' 'The run ended at zero.'
  grep -vF -- "$1" "$R/ai-docs/feedback/omit.md" > "$R/ai-docs/feedback/omit.tmp"
  mv "$R/ai-docs/feedback/omit.tmp" "$R/ai-docs/feedback/omit.md"
  out=$(CLAUDE_PLUGIN_ROOT="$FIXROOT" bash "$CHECK" "$R/ai-docs/feedback/omit.md" --mode report --project-dir "$R" 2>&1); rc=$?
  if [ "$rc" = "1" ]; then ok "refuses a report missing $1"; else bad "refuses a report missing $1 (rc=$rc) $out"; fi
  case "$out" in *"structure"*"$1"*) ok "  as a structure finding naming $1" ;; *) bad "  as a structure finding naming $1: $out" ;; esac
}
omit '**Symptom:**'
omit '**Repro:**'
omit '**Expected:**'
omit '**Surface:**'
omit '**Evidence:**'
omit 'harness_version:'
omit 'hash:'

printf '\n== gate: the harness root is validated, and not by a blanket refusal ==\n'
markroot() { mkdir -p "$1/.claude-plugin" "$1/docs"; printf '{}\n' > "$1/.claude-plugin/plugin.json"; printf '# m\n' > "$1/docs/agents-method.md"; }
rootcase() { # <label> <root> <project dir> <report path> <want rc> <must name>
  out=$(CLAUDE_PLUGIN_ROOT="$2" bash "$CHECK" "$4" --mode report --project-dir "$3" 2>&1); rc=$?
  check "$1" "$rc" "$5"
  if [ -n "$6" ]; then
    case "$out" in *"$6"*) ok "  names the reason ($6)" ;; *) bad "  names the reason ($6): $out" ;; esac
  fi
}
report "$R/ai-docs/feedback/root.md" 'scripts/session-events.sh' 'The run ended at zero.'
rootcase "an unmarked root -> 2" "$(mktemp -d)" "$R" "$R/ai-docs/feedback/root.md" "2" "not a harness install"
rootcase "a root that does not resolve -> 2" "/nonexistent/harness" "$R" "$R/ai-docs/feedback/root.md" "2" "does not resolve"
rootcase "negative control: a disjoint marked root -> 0" "$FIXROOT" "$R" "$R/ai-docs/feedback/root.md" "0" ""

SELF=$(mktemp -d); markroot "$SELF"
report "$SELF/ai-docs/feedback/root.md" 'docs/agents-method.md' 'The run ended at zero.'
rootcase "root == project dir, markers planted -> 2" "$SELF" "$SELF" "$SELF/ai-docs/feedback/root.md" "2" "equals or contains"

BASE=$(mktemp -d); markroot "$BASE/root"
report "$BASE/root/inner/ai-docs/feedback/root.md" 'docs/agents-method.md' 'The run ended at zero.'
rootcase "root strictly containing the project -> 2" "$BASE/root" "$BASE/root/inner" "$BASE/root/inner/ai-docs/feedback/root.md" "2" "equals or contains"
report "$BASE/root-proj/ai-docs/feedback/root.md" 'docs/agents-method.md' 'The run ended at zero.'
rootcase "negative control: a shared-prefix sibling -> 0" "$BASE/root" "$BASE/root-proj" "$BASE/root-proj/ai-docs/feedback/root.md" "0" ""
ln -sfn "$BASE/root/inner" "$BASE/link-proj"
rootcase "a project symlinked into the root -> 2" "$BASE/root" "$BASE/link-proj" "$BASE/link-proj/ai-docs/feedback/root.md" "2" "equals or contains"

printf '\n== gate: the report-mode project-dir derivation, both guards ==\n'
report "$R/ai-docs/feedback/g1.md" 'scripts/session-events.sh' 'A DiffSet was mutated after finalisation.'
out=$(CLAUDE_PLUGIN_ROOT="$FIXROOT" bash "$CHECK" "$R/ai-docs/feedback/g1.md" --mode report 2>&1); rc=$?
check "guard 1: the derivation finds the project without --project-dir" "$rc" "1"
case "$out" in *DiffSet*) ok "  names the entity it would otherwise have exported" ;; *) bad "  names the entity it would otherwise have exported: $out" ;; esac
report "$R/ai-docs/feedback/sub/g2.md" 'scripts/session-events.sh' 'The run ended at zero.'
out=$(CLAUDE_PLUGIN_ROOT="$FIXROOT" bash "$CHECK" "$R/ai-docs/feedback/sub/g2.md" --mode report 2>&1); rc=$?
check "guard 2: a report outside ai-docs/feedback/ -> 2, not 1 and not 0" "$rc" "2"
# Pinned to the containment clause's own wording. All three derivation die
# messages end in "pass --project-dir", so matching that tail alone let the
# clause be deleted while its sibling produced a different reason and the
# assertion still passed.
case "$out" in
  *"does not hold"*"at ai-docs/feedback/; pass --project-dir"*)
    ok "  names the containment clause as the reason" ;;
  *) bad "  names the containment clause as the reason: $out" ;;
esac

bash "$CHECK" "$R/ai-docs/feedback/row.md" --mode bogus --project-dir "$R" >/dev/null 2>&1
check "an unknown --mode value -> 2" "$?" "2"

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
