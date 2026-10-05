# NEVER UPDATE THIS FILE TO MATCH loop-window.awk. It is a frozen copy of the
# detector as it stood before GH-86, and every control built on it dies the
# moment the two agree. It is not a second implementation of the current rule --
# it is a historical one that must DISAGREE.
#
# It is HALF of the pre-fix detector. The other half was a window bound in the
# SHELL (`tail -n "$TAIL_N"`, i.e. LINES), so this file alone reverts the
# dismissal anchor while keeping the new call-counted unit -- a hybrid that
# existed in no build. Fed lines it reproduces the field measurement
# (K = 20/40/100 -> 0/2/3); fed calls it gives 2/3/3 and every control that
# rests on it is measuring nothing. Run it ONLY through
# hooks/lib/loop-window-prefix.sh, which carries the other half.
#
# No hook names this file; only the suites read it. Its correctness bar is the
# field measurement above, which scripts/test-loop-corpus.sh asserts first, so
# bit-rot surfaces as a failure rather than as a weaker gate.
#
# Signature, which awk gives no other place to state --
#   -v want_fp -v want_tool -v thr -v retry -v cur, ledger lines on stdin;
#   prints "<kind> <count> <agents>" on one line, or nothing.
    BEGIN { n = 0; first = 0; changed = 0; m = 0 }
    {
      # A result row carries the OUTCOME of an earlier call, joined by
      # tool_use_id. It is collected on the way past and resolved at END, because
      # it is written after the call it describes.
      if (match($0, /"kind":"result"/)) {
        id = ""; if (match($0, /"tool_use_id":"[^"]*"/)) id = substr($0, RSTART + 16, RLENGTH - 17)
        if (id != "") res[id] = ($0 ~ /"ok":true/) ? "ok" : "err"
        next
      }
      # TWO RECORD CLASSES SHARE THIS FILE, so every reader must filter on kind.
      # A verdict line carries "tool" and "fp" too: counted as a call it would
      # inflate the very count that produced it, and each firing would make the
      # next one more likely. Strict, not tolerant -- a line whose kind this
      # build does not know is skipped rather than guessed at, so a future kind
      # cannot silently enter the count. The cost is that a ledger written by a
      # build with no kind field is ignored, i.e. a session in flight across an
      # upgrade restarts its window. That is the safe direction.
      k = ""
      if (match($0, /"kind":"[^"]*"/))     { k = substr($0, RSTART + 8,  RLENGTH - 9)  }
      if (k != "call") next
      t = ""; f = ""; a = ""
      if (match($0, /"tool":"[^"]*"/))     { t = substr($0, RSTART + 8,  RLENGTH - 9)  }
      if (match($0, /"fp":"[^"]*"/))       { f = substr($0, RSTART + 6,  RLENGTH - 7)  }
      if (match($0, /"agent_id":"[^"]*"/)) { a = substr($0, RSTART + 12, RLENGTH - 13) }
      # STATE qualifier, free because EVERY step is in the ledger, not only the
      # matched ones: a write between the repeats means the world changed, so
      # the same call is not the same question.
      if (t == "Edit" || t == "Write" || t == "NotebookEdit") { changed = NR }
      if (t == want_tool && f == want_fp) {
        n++; if (first == 0) first = NR; seen[a] = 1
        id = ""; if (match($0, /"tool_use_id":"[^"]*"/)) id = substr($0, RSTART + 16, RLENGTH - 17)
        ids[++m] = id
      }
    }
    END {
      if (n == 0) exit
      fails = 0
      for (i = 1; i <= m; i++) if (ids[i] != "" && res[ids[i]] == "err") fails++
      seen[cur] = 1
      na = 0; for (k in seen) na++

      # THE EDIT FILTER IS CONDITIONAL, and this is the whole point of GH-69.
      # For calls that SUCCEEDED, a write between the repeats means the world
      # changed, so the same call is no longer the same question -- dismiss.
      # For calls that FAILED, the edit means an ATTEMPT was made and the call
      # failed again: that is the fix-break cycle, and dismissing it is how the
      # commonest logical loop stayed invisible. scripts/session-events.sh has
      # always had this right -- repeated-tool-call carries the intervening-edits
      # filter and error-retry-loop deliberately does not -- and the thresholds
      # below mirror its retry_min:2 against minrep:3 for the same reason it
      # gives: two failures of one call is already a retry loop, three is the bar
      # for calls that worked.
      if (fails + 0 >= retry) {
        printf "%s %d %d\n", "error-retry", fails, na
        exit
      }
      if (changed > first) exit
      if (n + 1 >= thr) { printf "%s %d %d\n", (na > 1 ? "fanout" : "loop"), n + 1, na }
    }
