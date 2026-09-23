#!/usr/bin/env bash
#
# Do the repository's cross-references actually resolve?
#
# Run:  check-references.sh [--root <dir>] [--audit-roots]
# Exit: 0 clean, 1 findings, 2 usage error.
#
# Mechanises structural checks 2 and 3 from AGENTS.md section Build & Test, and
# adds a third class those two could not see.
#
# Checks:
#   L1  markdown relative link -- the target file exists
#   L2  markdown #anchor -- a heading in the target slugifies to it
#   L3  ${CLAUDE_PLUGIN_ROOT}/<path> -- the file exists in this repo
#   L4  bare `ai-docs/<path>` in a METHOD file -- names a documented project-data
#       root, not an invented one
#   L5  `AGENTS.md § <Section>` in a METHOD file -- names a section a consuming
#       project's AGENTS.md actually has, not one that exists only in the method file
#
# WHY L4 EXISTS. A method file addresses project data as `ai-docs/...` and its
# own siblings as `${CLAUDE_PLUGIN_ROOT}/docs/...`. Writing the first spelling
# where the second was meant produces a path that resolves in NO project: the
# Propagation Rule's Spec-Amendment sync group pointed its last member at
# `ai-docs/workflow.md` for exactly this reason, so that member was never once
# updated by a sweep. L1-L3 cannot see it -- it is not a markdown link, carries
# no ${CLAUDE_PLUGIN_ROOT}, and "does the file exist" is the wrong question
# anyway, since ai-docs/ belongs to whichever project is open.
#
# The question L4 asks instead is whether the path matches a root that section
# Agent Docs documents as project data. --audit-roots checks that hardcoded list
# against that table, so the two cannot drift apart silently.
#
# WHY L5 EXISTS. Before the profile/method split there was one AGENTS.md. After
# it, § Tooling, § Learning Log, § Test Conventions, § Workflow, § Propagation
# Rule and § Agent Docs live ONLY in docs/agents-method.md -- a consumer's
# AGENTS.md has none of them. References were never updated, so a reader in a
# consuming project looks in their AGENTS.md and finds nothing. Observed in a
# live run: two Learning Log entries cited "AGENTS.md § Tooling" against a
# project whose AGENTS.md has no § Tooling at all.
#
# L5 only fires on a name it RECOGNISES as a method section. An unrecognised
# name is prose ("a Patterns block in any skill / agent / AGENTS.md section"),
# not a reference -- so a typo'd section name is invisible to this check. That
# is the deliberate trade: no false positives on English, at the cost of not
# catching an invented section name.
#
# Tests: scripts/test-check-references.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
AUDIT_ROOTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ -d "${2:-}" ] || { printf 'check-references: no such directory: %s\n' "${2:-}" >&2; exit 2; }
            ROOT=$(cd -- "$2" && pwd); shift 2 ;;
    --audit-roots) AUDIT_ROOTS=1; shift ;;
    *) printf 'check-references: usage: check-references.sh [--root <dir>] [--audit-roots]\n' >&2; exit 2 ;;
  esac
done

# Project-data roots a method file may legitimately name. Mirrors
# docs/agents-method.md section Agent Docs; --audit-roots proves the mirror holds.
DOC_ROOTS='ai-docs/context.md ai-docs/plans ai-docs/bugfix ai-docs/learnings.md ai-docs/learnings'

# Known-absent by design. Every entry needs a reason, because an allowlist with
# no reason is indistinguishable from a bug someone silenced.
#   ai-docs/templates  -- the `templates:` escalation target is ambiguous between
#                         ${CLAUDE_PLUGIN_ROOT}/docs/templates/ (method) and a
#                         project-side ai-docs/templates/ that
#                         skills/ai-audit/reference.md independently mandates.
#                         Neither is scaffolded. Decision pending; not silenced.
ALLOW='ai-docs/templates'

findings=0
finding() { printf '%s|%s|%s\n' "$1" "$2" "$3"; findings=$((findings+1)); }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM

md_files() { find "$ROOT" -name '*.md' -not -path '*/.git/*' | sort; }

# GitHub's slug: lower-case, drop everything outside [a-z0-9 _-], then map each
# REMAINING space to one hyphen -- runs are not collapsed, which is why
# "Build & Test" is #build--test. LC_ALL=C makes awk byte-oriented so a
# multi-byte dash is stripped byte by byte instead of surviving as garbage.
headings_of() {
  LC_ALL=C awk '
    /^```/ { fence = !fence; next }
    !fence && /^#{1,6}[ \t]/ {
      sub(/^#{1,6}[ \t]+/, ""); sub(/[ \t]+$/, "")
      s = tolower($0); gsub(/<[^>]*>/, "", s); gsub(/[^a-z0-9 _-]/, "", s); gsub(/ /, "-", s)
      print s
    }' "$1"
}

is_templated() { case "$1" in *'<'*|*'*'*|*YYYY*|*MM-DD*|*TODAY*|*'...'*) return 0 ;; *) return 1 ;; esac; }

if [ "$AUDIT_ROOTS" = "1" ]; then
  table="${ROOT}/docs/agents-method.md"
  [ -f "$table" ] || { printf 'check-references: no docs/agents-method.md under %s\n' "$ROOT" >&2; exit 2; }
  for r in $DOC_ROOTS; do
    grep -q -- "$r" "$table" \
      || finding major L4 "documented-root list names '${r}', absent from docs/agents-method.md -- the mirror has drifted"
  done
  [ "$findings" -eq 0 ] && printf 'check-references: %s documented roots all present in section Agent Docs.\n' "$(printf '%s' "$DOC_ROOTS" | wc -w | tr -d ' ')"
  exit $([ "$findings" -gt 0 ] && echo 1 || echo 0)
fi

# ---- L1 + L2 -----------------------------------------------------------------
while IFS= read -r md; do
  rel=${md#"$ROOT"/}
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    ln=${m%%:*}; link=${m#*:}
    href=${link#*](}; href=${href%)}
    case "$href" in
      http://*|https://*|mailto:*|'#'*|'') continue ;;
      path|file.md) continue ;;                       # literal words inside prose examples
      ../../issues/*|../../pull/*) continue ;;        # GitHub repo-relative: resolves on the host, never on disk
    esac
    frag=""; case "$href" in *'#'*) frag=${href#*#}; href=${href%%#*} ;; esac
    [ -n "$href" ] || continue
    case "$href" in
      '${CLAUDE_PLUGIN_ROOT}/'*) tgt="${ROOT}/${href#'${CLAUDE_PLUGIN_ROOT}/'}" ;;
      /*)                        tgt="$href" ;;
      *)                         tgt="$(dirname "$md")/$href" ;;
    esac
    if [ ! -e "$tgt" ]; then
      finding blocker L1 "${rel}:${ln}: link target does not exist -> ${href}"
      continue
    fi
    [ -n "$frag" ] || continue
    case "$tgt" in *.md) ;; *) continue ;; esac
    if ! headings_of "$tgt" | grep -qxF -- "$frag"; then
      finding blocker L2 "${rel}:${ln}: no heading in ${href} slugifies to #${frag}"
    fi
  done <<EOF
$(grep -noE '\[[^]]*\]\([^) ]*\)' "$md" || true)
EOF
done <<EOF
$(md_files)
EOF

# ---- L3 ----------------------------------------------------------------------
while IFS= read -r f; do
  rel=${f#"$ROOT"/}
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    ln=${m%%:*}; p=${m#*:}; p=${p#'${CLAUDE_PLUGIN_ROOT}/'}
    is_templated "$p" && continue
    [ -e "${ROOT}/${p}" ] \
      || finding blocker L3 "${rel}:${ln}: \${CLAUDE_PLUGIN_ROOT}/${p} does not exist in this repo"
  done <<EOF
$(grep -noE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/*<>-]+' "$f" | sed 's/[.,;:)]*$//' || true)
EOF
done <<EOF
$(find "$ROOT" \( -name '*.md' -o -name '*.json' -o -name '*.sh' \) -not -path '*/.git/*' | sort)
EOF

# ---- L4 ----------------------------------------------------------------------
# Method surfaces only. A profile file's ai-docs spellings describe its own repo
# and are not this check's business.
for dir in docs skills agents rules hooks; do
  [ -d "${ROOT}/${dir}" ] || continue
  while IFS= read -r f; do
    rel=${f#"$ROOT"/}
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      ln=${m%%:*}; p=${m#*:}; p=${p%/}
      is_templated "$p" && continue
      [ "$p" = "ai-docs" ] && continue
      skip=0
      for a in $ALLOW; do case "$p" in "$a"|"$a"/*) skip=1 ;; esac; done
      [ "$skip" = "1" ] && continue
      for r in $DOC_ROOTS; do case "$p" in "$r"|"$r"/*) skip=1 ;; esac; done
      [ "$skip" = "1" ] && continue
      finding major L4 "${rel}:${ln}: '${p}' is not a documented project-data path -- did you mean \${CLAUDE_PLUGIN_ROOT}/...?"
    done <<EOF
$(grep -noE 'ai-docs/[A-Za-z0-9._/*<>-]+' "$f" | sed 's/[.,;:)]*$//' || true)
EOF
  done <<EOF
$(find "${ROOT}/${dir}" -name '*.md' -o -name '*.json' | sort)
EOF
done

# ---- L5 ----------------------------------------------------------------------
PROJ="${ROOT}/templates/project/AGENTS.md"
METH="${ROOT}/docs/agents-method.md"
if [ -f "$PROJ" ] && [ -f "$METH" ]; then
  # Longest first, so "Build & Test table" matches "Build & Test" and not a
  # shorter heading that happens to share a prefix.
  awk '/^## /{sub(/^## /,""); print length($0)"\t"$0}' "$PROJ" | sort -rn | cut -f2- > "$TMP/proj.txt"
  awk '/^## /{sub(/^## /,""); print length($0)"\t"$0}' "$METH" | sort -rn | cut -f2- > "$TMP/meth.txt"

  starts_with_any() { # <ref> <headings-file>
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      case "$1" in "$h"*) return 0 ;; esac
    done < "$2"
    return 1
  }

  for dir in docs skills agents rules hooks; do
    [ -d "${ROOT}/${dir}" ] || continue
    while IFS= read -r f; do
      rel=${f#"$ROOT"/}
      case "$rel" in docs/agents-method.md) ;; esac
      while IFS= read -r m; do
        [ -n "$m" ] || continue
        ln=${m%%:*}; ref=${m#*:}
        ref=${ref#AGENTS.md}
        ref=${ref#"${ref%%[!  ]*}"}
        ref=${ref#§}; ref=${ref#section}
        ref=${ref#"${ref%%[!  ]*}"}
        ref=${ref#\`}
        [ -n "$ref" ] || continue
        starts_with_any "$ref" "$TMP/proj.txt" && continue     # a consumer really has it
        starts_with_any "$ref" "$TMP/meth.txt" || continue     # not a section name at all -- prose
        finding major L5 "${rel}:${ln}: 'AGENTS.md § ${ref}' names a section only the METHOD file has -- a consumer's AGENTS.md does not"
      done <<EOF
$(grep -noE 'AGENTS\.md[ ]*(§|section)[ ]*[^\`)*.,"\\]{1,60}' "$f" || true)
EOF
    done <<EOF
$(find "${ROOT}/${dir}" \( -name '*.md' -o -name '*.json' \) | sort)
EOF
  done
fi

[ "$findings" -eq 0 ] && printf 'check-references: links, anchors, plugin-root paths, project-data spellings and AGENTS.md section references all resolve.\n'
exit $([ "$findings" -gt 0 ] && echo 1 || echo 0)
