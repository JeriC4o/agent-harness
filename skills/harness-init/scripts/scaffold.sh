#!/usr/bin/env bash
#
# Scaffold the agent-harness PROJECT PROFILE into a target repo and register
# the project so cross-project commands can find it.
#
# Usage:
#   scaffold.sh <project-dir> [--name <name>] [--ticket-prefix <PFX>]
#               [--scope shared|local] [--dry-run]
#
# Copies templates/project/** into <project-dir>, substituting %PROJECT_NAME%.
# NEVER overwrites an existing file -- an already-scaffolded repo is a supported
# re-run, and a hand-edited AGENTS.md must survive it. Appends the gitignore
# snippet once, keyed on its marker line. Upserts one registry entry per path.
#
# Registry: $HARNESS_REGISTRY, else ~/.claude/harness/registry.json
#   { "version": 1, "projects": [ {path,name,ticket_prefix,scope,
#                                  harness_version,registered_at} ] }
#   scope=shared -> included in cross-project sweeps; local -> excluded.
#
# Exit: 0 done (including "everything already present"), 2 usage error.
# Tests: scripts/test-scaffold.sh

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(cd -- "${HERE}/../../.." && pwd)
TEMPLATE_DIR="${PLUGIN_ROOT}/templates/project"
REGISTRY="${HARNESS_REGISTRY:-${HOME}/.claude/harness/registry.json}"
GITIGNORE_MARKER='# --- agent harness:'

die() { printf 'harness-init: %s\n' "$1" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "jq is required (registry is JSON)"
[ -d "$TEMPLATE_DIR" ] || die "template dir not found: $TEMPLATE_DIR"

PROJECT_DIR=""; NAME=""; TICKET_PREFIX=""; SCOPE=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name)          NAME="${2:-}"; shift 2 ;;
    --ticket-prefix) TICKET_PREFIX="${2:-}"; shift 2 ;;
    --scope)         SCOPE="${2:-}"; shift 2 ;;
    --dry-run)       DRY=1; shift ;;
    -h|--help)       sed -n '3,20p' "$0"; exit 0 ;;
    -*)              die "unknown flag: $1" ;;
    *)               [ -z "$PROJECT_DIR" ] || die "unexpected argument: $1"
                     PROJECT_DIR="$1"; shift ;;
  esac
done

[ -n "$PROJECT_DIR" ] || die "usage: scaffold.sh <project-dir> [--name <name>] [--ticket-prefix <PFX>] [--scope shared|local] [--dry-run]"
[ -d "$PROJECT_DIR" ] || die "no such directory: $PROJECT_DIR"
case "$SCOPE" in shared|local|"") ;; *) die "--scope must be shared or local (got: $SCOPE)" ;; esac

PROJECT_DIR=$(cd -- "$PROJECT_DIR" && pwd)
[ -n "$NAME" ] || NAME=$(basename "$PROJECT_DIR")
HARNESS_VERSION=$(jq -r '.version // "unknown"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || printf 'unknown')

[ -d "${PROJECT_DIR}/.git" ] || printf 'harness-init: note: %s is not a git repo; the workflow assumes git.\n' "$PROJECT_DIR" >&2

created=0; skipped=0

# ---- 1. copy the profile, never clobbering ----------------------------------
while IFS= read -r src; do
  rel="${src#"$TEMPLATE_DIR"/}"
  [ "$rel" = "gitignore.snippet" ] && continue
  dst="${PROJECT_DIR}/${rel}"
  if [ -e "$dst" ]; then
    printf '  skip    %s (already present)\n' "$rel"
    skipped=$((skipped+1))
    continue
  fi
  printf '  create  %s\n' "$rel"
  created=$((created+1))
  [ "$DRY" -eq 1 ] && continue
  mkdir -p "$(dirname "$dst")"
  if [ -s "$src" ]; then
    sed -e "s/%PROJECT_NAME%/${NAME}/g" "$src" > "$dst"
  else
    : > "$dst"
  fi
done <<EOF
$(find "$TEMPLATE_DIR" -type f | sort)
EOF

# ---- 2. gitignore, appended once --------------------------------------------
GI="${PROJECT_DIR}/.gitignore"
if [ -f "$GI" ] && grep -qF "$GITIGNORE_MARKER" "$GI"; then
  printf '  skip    .gitignore (harness block already present)\n'
  skipped=$((skipped+1))
else
  printf '  append  .gitignore\n'
  if [ "$DRY" -eq 0 ]; then
    [ -f "$GI" ] && [ -s "$GI" ] && [ "$(tail -c 1 "$GI" | wc -l)" -eq 0 ] && printf '\n' >> "$GI"
    cat "${TEMPLATE_DIR}/gitignore.snippet" >> "$GI"
  fi
fi

# ---- 3. registry upsert ------------------------------------------------------
if [ "$DRY" -eq 0 ]; then
  mkdir -p "$(dirname "$REGISTRY")"
  [ -f "$REGISTRY" ] || printf '{"version":1,"projects":[]}\n' > "$REGISTRY"
  tmp="${REGISTRY}.tmp.$$"
  # An omitted flag must NOT wipe a value a previous run recorded: a re-run is
  # an upgrade, not a reset. Only explicitly-passed flags override; everything
  # else falls back to the existing entry, then to the documented default.
  if jq --arg p "$PROJECT_DIR" --arg n "$NAME" --arg t "$TICKET_PREFIX" \
        --arg s "$SCOPE" --arg v "$HARNESS_VERSION" --arg d "$(date -u +%Y-%m-%d)" '
       (.projects // []) as $all
       | ($all | map(select(.path == $p)) | first // {}) as $old
       | .version = 1
       | .projects = ($all | map(select(.path != $p)))
         + [{ path: $p,
              name:           (if $n != "" then $n else ($old.name // ($p | split("/") | last)) end),
              ticket_prefix:  (if $t != "" then $t else ($old.ticket_prefix // "none") end),
              scope:          (if $s != "" then $s else ($old.scope // "shared") end),
              harness_version: $v,
              registered_at:  ($old.registered_at // $d),
              updated_at:     $d }]
       | .projects |= sort_by(.path)
     ' "$REGISTRY" > "$tmp"; then
    mv "$tmp" "$REGISTRY"
    printf '  register %s -> %s\n' "$NAME" "$REGISTRY"
  else
    rm -f "$tmp"
    die "registry update failed; $REGISTRY left unchanged"
  fi
fi

# ---- 4. build-system suggestions ---------------------------------------------
printf '\nDetected build system:\n'
suggest() { printf '  %-14s %s\n' "$1" "$2"; }
if   [ -f "${PROJECT_DIR}/gradlew" ] || ls "${PROJECT_DIR}"/build.gradle* >/dev/null 2>&1; then
  suggest "gradle" "%BUILD_CMD%=./gradlew :<module>:assemble  %TEST_CMD%=./gradlew :<module>:test --tests '<Class>.<method>'"
elif [ -f "${PROJECT_DIR}/pom.xml" ]; then
  suggest "maven" "%BUILD_CMD%=mvn -pl <module> compile  %TEST_CMD%=mvn -pl <module> test -Dtest='<Class>#<method>'"
elif [ -f "${PROJECT_DIR}/Cargo.toml" ]; then
  suggest "cargo" "%BUILD_CMD%=cargo build -p <crate>  %TEST_CMD%=cargo test -p <crate> <filter>  %FORMAT_CMD%=cargo fmt  %LINT_CMD%=cargo clippy -- -D warnings"
elif [ -f "${PROJECT_DIR}/go.mod" ]; then
  suggest "go" "%BUILD_CMD%=go build ./<pkg>/...  %TEST_CMD%=go test ./<pkg>/... -run '<Name>'  %FORMAT_CMD%=gofmt -w  %LINT_CMD%=go vet ./..."
elif [ -f "${PROJECT_DIR}/package.json" ]; then
  pm=npm
  [ -f "${PROJECT_DIR}/pnpm-lock.yaml" ] && pm=pnpm
  [ -f "${PROJECT_DIR}/yarn.lock" ] && pm=yarn
  suggest "$pm" "%BUILD_CMD%=$pm run build  %TEST_CMD%=$pm test -- <filter>  %FORMAT_CMD%=$pm run format  %LINT_CMD%=$pm run lint"
elif [ -f "${PROJECT_DIR}/pyproject.toml" ] || [ -f "${PROJECT_DIR}/setup.py" ]; then
  suggest "python" "%BUILD_CMD%=python -m compileall <pkg>  %TEST_CMD%=pytest <path> -k '<expr>'  %FORMAT_CMD%=ruff format  %LINT_CMD%=ruff check"
elif [ -f "${PROJECT_DIR}/Makefile" ]; then
  suggest "make" "%BUILD_CMD%=make build  %TEST_CMD%=make test  %LINT_CMD%=make lint"
else
  suggest "unknown" "no marker file found -- ask the user for all four commands"
fi

printf '\n%s created, %s left alone.\n' "$created" "$skipped"
[ "$DRY" -eq 1 ] && printf 'DRY RUN: nothing was written.\n'
printf 'Next: fill every %%PLACEHOLDER%% in AGENTS.md and ai-docs/context.md. An unresolved one is a STOP.\n'
exit 0
