# The tier-1 loop detector. Driven by hooks/lib/loop-index.sh on every tool call
# and driven DIRECTLY by scripts/test-loop-corpus.sh: the ledger stores a djb2
# hash of the arguments and never the arguments, so no synthetic payload can
# reproduce a recorded fp and a replay of real rows cannot go in through the
# hook. One shared file is what stops the gate and the hook from measuring two
# different rules.
#
# Signature, which awk gives no other place to state --
#   -v want_fp -v want_tool -v thr -v retry -v cur -v want_calls -v chunk,
#   ledger lines on stdin. Prints "<kind> <count> <agents> <span>" on one line,
#   or the bare token RETRY, or nothing. RETRY means the chunk was too narrow to
#   hold want_calls calls and may have been cut short by the request rather than
#   by the file: the caller widens `chunk` and runs it again.
#
# NO SHELL GATE REACHES THIS FILE: `bash -n` and shellcheck both skip *.awk, so
# its only syntax check is the `awk -f <prog> </dev/null` case in
# hooks/lib/test-loop-index.sh.
    # THE WINDOW IS A COUNT OF CALLS, AND ONLY THIS PROGRAM CAN APPLY IT. The
    # shell can bound a tail by LINES; it cannot tell a call row from the result
    # and verdict rows interleaved with it, and that gap IS the defect -- a
    # 20-line tail was 20 steps while the ledger carried calls only, and is
    # roughly 8 now that loop-result.sh writes a row per call. So the shell
    # sizes a CHUNK as a performance hint and the window is bound here, over the
    # buffered chunk, where a call row is distinguishable from everything else.
    BEGIN { n = 0; changed = 0; m = 0; calls = 0 }
    { line[NR] = $0
      if (match($0, /"kind":"[^"]*"/) && substr($0, RSTART + 8, RLENGTH - 9) == "call") {
        call_nr[++calls] = NR
      }
    }
    END {
      # NR == chunk means tail returned exactly as many lines as it was ASKED
      # for, so the file may hold more and a short call count is evidence of
      # nothing yet. NR < chunk means tail ran out of FILE: there is nothing
      # further back and what was seen is the whole window there is. The retry
      # loop is therefore bounded by the file and needs no iteration cap.
      # RETRY outranks an emittable verdict because a wider chunk can change
      # both the count and the agent set, and so the arm itself.
      if (calls < want_calls && NR == chunk) { print "RETRY"; exit }

      # The scan starts at the want_calls-th most recent CALL row. Rows older
      # than it are never read -- their result rows included, which is why the
      # outcome map is built in this pass rather than on the way past.
      start = (calls > want_calls) ? call_nr[calls - want_calls + 1] : 1
      # What the AGENT is told it was judged against, and it is NOT want_calls:
      # on a young ledger the window that existed is smaller than the one
      # requested, and quoting the request there is the defect this file is
      # fixing, relocated into the sentence the agent reads.
      #
      # THE + 1 IS THE CALL BEING JUDGED, and removing it makes the commonest
      # firing of all FALSE. The ledger holds PRIOR calls only; `count` is
      # n + 1 because the current call is added explicitly. So on a fresh ledger
      # with two prior repeats -- the modal firing, and the shape of this file's
      # own threshold case -- the counted prior span is 2 while the count is 3,
      # and "has run 3 times within the last 2 steps" cannot be true of
      # anything. With the + 1 the span is the span of the JUDGEMENT: prior
      # calls examined, plus the one being asked about. count <= span then holds
      # always, because n is at most min(calls, want_calls).
      span = ((calls < want_calls) ? calls : want_calls) + 1

      for (nr = start; nr <= NR; nr++) {
        $0 = line[nr]
        # A result row carries the OUTCOME of an earlier call, joined by
        # tool_use_id. It is collected on the way past and resolved after the
        # loop, because it is written after the call it describes.
        if (match($0, /"kind":"result"/)) {
          id = ""; if (match($0, /"tool_use_id":"[^"]*"/)) id = substr($0, RSTART + 16, RLENGTH - 17)
          if (id != "") res[id] = ($0 ~ /"ok":true/) ? "ok" : "err"
          continue
        }
        # FIVE RECORD CLASSES SHARE THIS FILE -- call, result, turn, verdict and
        # agent-mark -- so every reader must filter on kind.
        # A verdict line carries "tool" and "fp" too: counted as a call it would
        # inflate the very count that produced it, and each firing would make the
        # next one more likely. Strict, not tolerant -- a line whose kind this
        # build does not know is skipped rather than guessed at, so a future kind
        # cannot silently enter the count. The cost is that a ledger written by a
        # build with no kind field is ignored, i.e. a session in flight across an
        # upgrade restarts its window. That is the safe direction.
        k = ""
        if (match($0, /"kind":"[^"]*"/))     { k = substr($0, RSTART + 8,  RLENGTH - 9)  }
        if (k != "call") continue
        t = ""; f = ""; a = ""
        if (match($0, /"tool":"[^"]*"/))     { t = substr($0, RSTART + 8,  RLENGTH - 9)  }
        if (match($0, /"fp":"[^"]*"/))       { f = substr($0, RSTART + 6,  RLENGTH - 7)  }
        if (match($0, /"agent_id":"[^"]*"/)) { a = substr($0, RSTART + 12, RLENGTH - 13) }
        # STATE qualifier, free because EVERY step is in the ledger, not only the
        # matched ones: a write between the repeats means the world changed, so
        # the same call is not the same question.
        if (t == "Edit" || t == "Write" || t == "NotebookEdit") { changed = nr }
        if (t == want_tool && f == want_fp) {
          n++; seen[a] = 1
          id = ""; if (match($0, /"tool_use_id":"[^"]*"/)) id = substr($0, RSTART + 16, RLENGTH - 17)
          ids[++m] = id
          pos[m] = nr
        }
      }

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
        printf "%s %d %d %d\n", "error-retry", fails, na, span
        exit
      }
      # THE DISMISSAL IS ANCHORED ON THE EVIDENCE THAT WOULD FIRE, not on the
      # oldest match in the window. A firing needs the current call plus thr - 1
      # prior matches, and those are the most RECENT thr - 1, so the mutation
      # that disqualifies them is one landing after the OLDEST OF THOSE --
      # m_{n-(thr-2)}. Anchored on m_1 instead, widening the window silenced the
      # detector: a wider window admits an older match, which drags the anchor
      # back past a mutation that was never between the repeats that would fire,
      # and the measured consequence was unbounded -> 0 firings on a real ledger.
      #
      # Re-anchored, NOT removed: for n == 2, the commonest case, m_{n-1} is m_1
      # and the rule is identical to the old one, which is why the existing
      # intervening-write cases are unchanged.
      #
      # Monotonic by construction: widening admits only OLDER rows, so it cannot
      # move m_n or m_{n-1} and cannot raise `changed` (a maximum over mutation
      # positions); and a mutation newly admitted is necessarily older than the
      # anchor match, or the narrower window held it too.
      ai = n - (thr - 2)
      anchor = (ai >= 1) ? pos[ai] : pos[1]
      if (changed > anchor) exit
      if (n + 1 >= thr) { printf "%s %d %d %d\n", (na > 1 ? "fanout" : "loop"), n + 1, na, span }
    }
