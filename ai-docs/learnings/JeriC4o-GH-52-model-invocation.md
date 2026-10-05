### 2026-10-05 — tooling — called a defect "live" from a corpus whose rows were written by an older build
**What happened:** Asked whether the loop ledger's agent attribution was a live defect or a stale-session
artefact, I measured two sessions that *started* after the fix merged, found every call recorded as
`main`, and reported the defect as live — in chat and in a comment on the issue. It was wrong. The rows
carried their own writer's signature: `(.agent_type // "-")` and the payload `agent_id` read landed in
one commit, so a row with `agent_type: null` predates the fix and a row with `"-"` follows it. Only one
of eleven ledgers writes `"-"`. Both sessions I cited were running an installed plugin older than the
fix, because the install cache is version-keyed and moves only on an explicit update. The `null` was
visible in the row I quoted and I read past it. What prompted the re-read was the official documentation
stating the opposite of my conclusion.
**Rule:** A session's START TIME does not date the code that ran in it. Before attributing observed
behaviour to current code, date the DATA: find a field whose spelling changed with the fix and partition
the corpus by it. Where no such field exists, say the corpus cannot answer the question instead of
answering it. And when a documented contract contradicts a measurement, the measurement is the thing to
re-examine first — the contradiction is evidence about my reading, not yet about the product.
**Kind:** correction
**Escalated?** no
