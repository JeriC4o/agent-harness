#!/usr/bin/env bash
# NEVER UPDATE THIS FILE TO TRACK loop-index.sh. With loop-window-prefix.awk it
# is the frozen pre-fix detector, and a control that is kept in step with its
# subject controls nothing.
#
# THIS IS THE OTHER HALF. The pre-fix window was bound HERE, in the shell, by
# `tail -n "$TAIL_N"` -- LINES, not calls. The .awk beside this file carries
# only the dismissal rule, so invoking it on its own reverts the anchor while
# keeping the new call-counted unit: a hybrid that existed in no build and that
# no acceptance criterion describes. Fed lines, the pair reproduces the field
# measurement (K = 20/40/100 -> 0/2/3, first monotonicity break at 760); fed
# calls it gives 2/3/3 with its break at 343. Every suite invokes THIS file.
#
# Usage: loop-window-prefix.sh <K|unbounded> <ledger> <want_fp> <want_tool> \
#                              [threshold] [retry_min] [current_agent]
# K is a LINE count. `unbounded` reads the whole ledger -- `tail -n 0` prints
# nothing, so the no-window case cannot be spelled as a K.
set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd) || exit 1
K="${1:?K (lines) required}"
LEDGER="${2:?ledger path required}"

if [ "$K" = unbounded ]; then cat "$LEDGER"; else tail -n "$K" "$LEDGER"; fi \
  | awk -v want_fp="${3:?want_fp required}" -v want_tool="${4:?want_tool required}" \
        -v thr="${5:-3}" -v retry="${6:-2}" -v cur="${7:-main}" \
        -f "${HERE}/loop-window-prefix.awk"
