#!/usr/bin/env bash
#
# The spec's record of deliberate absence: the sections a collapsed spec keeps,
# and the sections the archive listing extracts from every completed spec. This
# is the one list of them, and no reader names them itself.
#
# Data, never an entry point. Every reader parses the assignment below as text,
# from `RETAINED='` at the start of a line to the closing quote, so reshaping or
# moving it changes all of their inputs at once, and none of them reads a
# missing assignment as an empty list:
#   scripts/check-plan-invariants.py, the element derivation;
#   retained_sections() in scripts/check-plan-convergence-holding.py, which the
#     declared-link check also reaches through folded_spec();
#   scripts/plan-archive.sh, the spec sections the listing extracts;
#   scripts/test-check-plan-convergence.sh and scripts/test-check-plan-links.sh,
#     which build their collapsed-spec fixtures from it.

# [retained-list]
RETAINED='## Out of scope
## Deferred
## Key decisions'
