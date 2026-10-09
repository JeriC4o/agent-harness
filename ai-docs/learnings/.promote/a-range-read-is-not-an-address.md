---
id: a-range-read-is-not-an-address
category: tooling
kind: correction
created: 2026-10-09
---

**Rule:** A range read produces content, never addresses. Cite a line number only from a command that
printed that number for the token you are citing, and address a row for editing by a token that
identifies it rather than by its ordinal.

**Why:** Reading a span, or stitching several spans into one dump, leaves the line numbers to be
reconstructed by counting — the arithmetic every anchor rule already forbids, reintroduced by the reading
tool rather than by carelessness. A stitched dump is the shape that makes the counting feel safest,
because the content is right there in front of you. And a line number is stale the moment anyone edits
the file, where the likeliest editor is yourself one call ago: a read and a write separated by your own
unrelated edit to the same file have nothing to signal the invalidation. An ordinal address that matches
nothing is a silent success.

**Signal:** A citation whose only source is a span read earlier. Several spans concatenated into one
output. An in-place edit addressed by line number. Any anchor you did not watch a search command print.
