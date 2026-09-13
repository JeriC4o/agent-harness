#!/usr/bin/env bash
#
# Is the current project harness-managed?
#
#   exit 0 -> yes, a harness profile is present; the calling hook should run
#   exit 1 -> no; the calling hook must no-op
#
# Used as a guard prefix by every hook that assumes a harness profile:
#
#   "${CLAUDE_PLUGIN_ROOT}"/hooks/lib/harness-managed.sh || exit 0
#
# Rationale: installed at user scope the plugin is active in EVERY repo, most
# of which never opted in. A hook that blocks a commit or prints a reminder
# about AGENTS.md rules there is noise at best and an obstruction at worst.
# Hooks that encode pure method (do not mask a gate; do not scan $HOME) carry
# no guard on purpose -- they hold everywhere.
#
# A project counts as managed when it carries either marker the scaffolder
# writes. Both are checked because a repo may legitimately keep the rule file
# without the docs tree, or vice versa during setup.
#
# Tests: hooks/lib/test-harness-managed.sh

set -u

root="${CLAUDE_PROJECT_DIR:-$PWD}"

[ -d "${root}/ai-docs" ] && exit 0
[ -f "${root}/AGENTS.md" ] && exit 0

exit 1
