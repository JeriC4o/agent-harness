# Planted faults — the positive control for the judgement reader

This document is read on every run of the `plan-convergence` reader, beside the plan pair it was
spawned on, and it is the reader's own positive control. It holds **one deliberately planted fault
per class the reader covers**, and the reader prints, per class, whether that fault came back. A
class whose planted fault is not reported is printed as **uncovered** rather than counted as
covered.

**It is committed, and it is not a plan.** Nothing authors it as part of a task and no plan points
at it as its own spec or design; it is frozen measurement data, like every other file beside it. A
reader that finds its faults is demonstrating coverage of the classes, not reporting on a document
anybody has to fix.

**Three things may NOT be planted here, and each exclusion has a mechanism behind it.** A broken
markdown link or an unresolvable anchor would redden the reference-resolution gate, which walks
every markdown file it finds on disk — so the fault would be reported by the wrong mechanism and
this control would prove nothing. A reference to a position inside a file would be reported by the
deterministic reference class against its committed baseline, for the same reason. And a bracketed
lowercase-slug token outside a backtick span or a fenced block would read as an identity claim to
the deterministic pairing class, which sweeps the files a plan names and would find a mark nothing
claims.

**Each fault below is self-contained.** Everything needed to see that it is a fault is inside this
document or inside the artefact the fault names, so the reader needs no third input and the control
cannot rot through a missing comparand.

## The plan under examination — its requirements half

- The plan's record of waived findings is removed by the closing pass, together with the correction
  log, and anything retaining either afterwards is reported.
- Every member of the structural check list reports its own verdict, and the runner that invokes
  them all reports one verdict per member.

## The plan under examination — its approach half

The work adds a waiver record beside the plan and a closing pass that consumes the correction log.

**The waiver record survives the closing pass and is what the post-merge reading list reads to
recover why the plan proceeded over its findings.** It is committed for exactly that reason: the
pass removes the correction log, and the waiver record is deliberately left in place so a later
reader can still see which findings were waived.

**The gate runner `scripts/run-checks.sh` exits 0 whichever way its members land**, so a caller
reads the per-member verdicts and never the exit status, and a failing member cannot stop a caller
that only looks at how the run ended.

## What each planted fault is, and which class owns it

| Class | The planted fault | Why it is a fault |
|---|---|---|
| `self-contradiction` | The requirements half says the waiver record is removed by the closing pass and that anything retaining it is reported; the approach half says the record survives that pass and is read afterwards | Both halves are statements of this one plan about one object, and they cannot both hold: a record that is removed cannot be read later, and a pass that both removes it and leaves it has no behaviour a reader can act on |
| `artefact-contradiction` | The approach half says the gate runner exits 0 whichever way its members land | The artefact says otherwise: the runner exits 0 only when every member passed, 1 on any failure or list drift, and 2 when it could not run at all — so the plan's claim about a thing that already exists is false of it, and the advice it carries (read the members, never the status) rests on a property the runner does not have |

**The second fault is deliberately a claim about something that ALREADY EXISTS**, because that is
the half a reader can check and the half a plan gets wrong without noticing: nothing inside the
document disagrees with it, and only opening the artefact does.
