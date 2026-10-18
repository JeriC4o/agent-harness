# Gate outcomes

What a gate's result may be, and what a reader is entitled to conclude from it. Pointed at from
[`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Build & Test](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#build--test),
which keeps the obligation to resolve a project's own commands and points here for the convention their
results are read under. This page is pure reference. It states no rule about what any document must
contain, and the convention below is about a gate's verdict and never about a document's sections.

## The three outcomes this page defines

A gate reports one of three outcomes, and this enumeration is the definition rather than a count taken
from anywhere else:

| Outcome | What it says | What a reader may conclude |
|---|---|---|
| **clean** | the gate ran over the whole input set it names, and found nothing | the property the gate measures holds, over that input and no wider |
| **findings** | the gate ran and found something | the property does not hold, and the report names where |
| **could-not-run** | the gate did not get far enough to measure anything | **nothing at all** — and in particular not that the property holds |

**A could-not-run is not a pass, and it is reported distinctly from both of the others.** A tool the gate
needs and cannot find, an input it cannot read, an input set that came back empty, a record it compares
against that is not there — each ends a run without measuring the thing the gate exists to measure. A gate
that reported any of them as clean would be silent in exactly the circumstances where silence is least
warranted. The distinction is mechanical rather than editorial: the three outcomes carry three different
exit statuses, and the status meaning could-not-run is never the status meaning clean.

**The verdict line is read, not only the exit status.** A gate that reports the size of the input set it
examined says something a status cannot, because a run that silently narrowed its own input reads exactly
like a clean one. So a gate reports what it examined beside what it found, and a reader who read only the
status has not read the result.

**An absent gate is reported as absent and never as clean.** Where a gate cannot run on a machine, the
honest report is that it did not run. A gate that is honestly absent is better than one that falsely
reports success, and a gate that cannot run and says so is better than one whose failure to run looks like
agreement.

## A gate whose judgement a model makes

The convention above was written for a gate whose answer is a function of its input. A check whose
judgement is made by a model carries no such guarantee, and it is held to a stated standard rather than
excused from one. Five obligations, enumerated here as the definition of that standard, the first of them
being the convention above carried over unchanged:

1. **The three outcomes still hold, and a could-not-run is still not a pass.** Nothing about a judgement
   class makes an unfinished run readable as a clean one.
2. **It reports, and rules on nothing.** A finding names what was found and where it sits; whether it does
   harm is the reader's call. A judgement check that also ruled on consequence would fold two decisions
   into one output and leave the reader nothing to overturn.
3. **Every class it covers carries a positive control.** A deliberately planted fault of that class is
   shown to be caught by it. A class with no such demonstration is not a check, and is reported as
   uncovered rather than counted as covered.
4. **Its agreement across repeated runs over one unchanged input is measured and printed.** Not assumed,
   and not held to a threshold: the figure is a result in its own right, and what a healthy figure would
   look like is stated before the first run, so a low one reads as a measurement rather than as an
   unfinished mechanism.
5. **It is never the only check standing.** A judgement result is produced beside the deterministic
   results in the same pass, so no run exists in which it answers alone.

## Why a gate-specific restatement of this convention stays where it is

An instruction that states this convention for one named gate carries reasoning this page cannot hold:
which exit status means what for that one check, why its polarity runs the way it does, what its own input
set is and how a reader tells a narrowed one. Such a restatement is the convention applied to a case,
while this page is the convention. It is therefore not a duplicate of this page, and turning one into a
pointer would lose the argument it carries rather than removing a repetition.

## Three ways a command fails to be a gate at all

A gate is a claim about a command, and the claim is only worth something once the command has been shown
able to FAIL. Run it once against input engineered to make it fail; if you cannot make it fail, it is not
a gate. Three shapes recur, and all three read as a pass:

1. **An unrecognised argument answered with EMPTY OUTPUT and rc=0** rather than with an error. Every gate
   built on that command is a silent pass, and nothing in its output says so.
2. **A tool that exits 0 when it matched NO files** — the classic cause is an unquoted shell scalar where
   a list was meant. Indistinguishable from "all clean", and the narrower the input set silently becomes,
   the greener it looks.
3. **A pattern over markup whose fields are not the fields it assumes** — a delimiter inside a cell is
   escaped, so a row-splitting expression silently reads one field as another. Normalise first, and prove
   the check fires in BOTH directions before trusting either.

**Never accept "the structure makes it machine-checked" as an argument.** That is a claim about a
pattern, and it is exactly where this reasoning fails: the structure guarantees nothing the pattern does
not actually match.

**This page is where that knowledge lives because no plan document states a gate.** It arrived here from
the design-review contract, which used to carry it as a duty to execute the commands a design pinned; a
design pins none, so the duty had no subject left while the knowledge remained worth keeping.
