# Glossary

One entry per concept of the harness, in a fixed form a program reads. **Canonical name**: the one name
the harness uses. **Other names**: names in use for the same concept, which the harness's files no longer
write. **What it is** and **What it does**: the entry's plain description, naming no file, command,
section or other entry. **Defined at**: the page, named from the plugin's root, and the section defining
the concept, or `planned` for a concept the harness does not have yet. **Retired names**, at the foot,
named concepts that no longer exist. An other name or a retired name is a listed name. A new concept
arrives with its entry in the same change.

## Text for a person

Text for a person is anything an agent writes that a person reads: a chat reply, a question, a hand-back
the person sees, a design put up for approval, a pull request's description, an issue text, a comment.
Text one agent writes for another, such as a brief or a report, is not.

1. A harness concept's meaning is carried by its entry's plain description, in the person's language. The
   canonical name may follow as an untranslated aside in parentheses; the sentence still works without it.
2. No name is translated word for word and used as a term, and no name is invented for a concept.
3. A listed name is not used.
4. A concept with no entry is described by what it is and does, without a name. Its proposed entry, in the
   form below, goes to the owner's items at the end of the task or into the pull request's description
   under "Proposed glossary entries"; the work does not stop for it.
5. A name inside double quotation marks, guillemets or code marks, written to talk about the name itself,
   is a mention, not a use.

## Words a script must keep

A listed name appears in the harness's files only on this page and where a script must keep it: its own
variable or function names, a bracketed id in a comment, and lines under the internals mark, kept because
older files still carry the word or a test plants a copy. The mark is a comment holding
`vocabulary-internal:` and why the word stays; alone on its line, it covers the lines below it up to the
next blank line.

## Workflow and agents

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| main agent | "main thread" | The agent a person talks to directly in a session. | It reads the person's messages, starts every other agent and writes the replies the person sees. | `docs/glossary.md` § Workflow and agents |
| orchestrator | — | The agent the person talks to, while it runs a workflow of several steps. | It starts the helper agents, hands each its part of the work and keeps the task's notes current. | `docs/glossary.md` § Workflow and agents |
| subagent | — | An agent started by another agent for one job, in a fresh context. | It does that job and ends by handing a report back to the agent that started it. | `docs/glossary.md` § Workflow and agents |
| skill | — | A named workflow, started by a slash command the person types or by an agent. | It puts its steps into the agent's context, and the agent follows them. | `docs/glossary.md` § Workflow and agents |
| spec workflow | "spec flow", "task workflow" | The ordered steps a task runs today, from questions to the owner to a pull request. | It writes the requirements and the approach, has both reviewed, builds the change and reviews it before it is pushed. | `skills/task/reference.md` § Gate checklist |
| interview | — | The questions put to the owner, a few at a time, while a task's requirements are drafted. | Each round's answers settle open choices until nothing is left to ask. | `skills/interview/SKILL.md` § Architecture |
| spec writer | — | The agent that drafts a task's requirements from the owner's answers. | It decides each round's questions. | `agents/spec-writer.md` § Spec Writer Subagent |
| design author | "design subagent" | The agent that writes a task's chosen approach and its table of subtasks. | It also records which statements of the requirements and the approach must change together. | `agents/design.md` § Design author |
| fix scout | — | The agent that plans the fixes for a review's open problems, in a fresh context. | It writes at least one row per problem, one per file the fix touches: what to change, where, how much. | `agents/fix-scout.md` § Why this role exists |
| fix-apply agent | — | The agent that carries out a table of fixes after it was checked. | It makes only the table's fixes, then reruns the checks the table names. | `agents/fix-apply.md` § Fix Apply Subagent |
| finding | — | One problem a review or a check reports. | It is fixed, objected to with a reason, or kept as it stands with a reason. | `agents/self-review.md` § Findings format (written to progress file) |
| session inspection | — | A look back over a finished session for wasted effort. | A script counts loops, repeated checks and review rounds that ran out; an agent judges what it found. | `skills/inspect/SKILL.md` § Step 2: Judge — spawn the inspector |

## Plans

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| spec | — | A task's requirements: what the system must do, seen from outside, with numbered criteria. | The owner approves it before an approach is chosen, and every later step is checked against it. | `agents/spec-writer.md` § What a spec IS, and what it may not contain |
| design | "design doc" | The document stating the approach chosen for a task. | The owner approves it before code is written, and the finished change is checked against it. | `agents/design.md` § Artifact format |
| plan | "plan pair", "spec/design pair" | A task's requirements and its chosen approach, taken together. | Reviews and checks read the two side by side for gaps and contradictions. | `docs/plan-invariants.md` § The base principles |
| progress file | "progress record", "working record" | A task's working notes, kept on the owner's machine and never committed. | It records where the task stands, its decisions and its review results, so work resumes after a break. | `docs/templates/progress-format.md` § Template |
| plan freeze | — | The commit made when the review of a task's approach approves it. | Every later change to the requirements or the approach is measured from it. | `docs/workflow.md` § The plan freeze |
| spec amendment | — | A change to a task's requirements while the task runs. | The owner approves it, and the approach is reviewed again when it changes too. | `skills/task/reference.md` § Spec Amendment recipe (re-entrant — triggered from a Step 7 verdict) |
| design amendment | — | A rewrite of a task's chosen approach that changes what was approved, while the task runs. | The rewrite goes through review and approval again. | `skills/task/reference.md` § Design Amendment recipe (re-entrant — triggered from Step 8 or Step 11) |
| earlier-shape design | — | An approach document written before the table of subtasks moved into the task's notes. | It carries its own table of subtasks, and the length limit does not bind it. | `agents/design.md` § Rules |
| length cap | — | The soft limit the owner set on the length of an approach document. | A document over it is reported with its length; nothing is refused. | `agents/design.md` § Rules |
| working plan | — | The table of a task's subtasks and their groups, kept in the task's notes. | The implementation runs from it group by group, two at once only where it shows them independent. | `docs/templates/progress-format.md` § `Working plan` |
| in-place correction | "correction pass", "correction beat" | Rewriting one item of an approved approach so it states what was built. | The approach stays as approved; a change that breaks it goes back for review instead. | `agents/design.md` § Correcting the design in place |
| working in the review notes | "fold-in", "folded in", "unfolded note" | Putting a reviewer's remarks into the approach or the table of subtasks before approval is recorded. | Every remark is answered in the text, so none is lost when the review closes. | `skills/task/reference.md` § Step 7 — the freeze |
| cut-down spec | "folded spec", "collapsed spec" | An archived requirements document that a since-removed closing step cut down to three sections. | The checks still recognise it, and the commit that made it, and skip both. | `docs/declared-links.md` § The check |
| deliberate absence | — | What a task's requirements record as left out on purpose: out of scope, deferred, or decided. | A review reads it, so a deliberate omission is not reported as a gap. | `docs/plan-invariants.md` § The required elements of a spec and of a design |
| plan archive | — | The folder where finished tasks' requirements and approaches are kept. | A listing of it tells a review of a whole branch what earlier tasks decided. | `docs/agent-docs-index.md` § `ai-docs/plans/done/` |

## Checking a plan

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| convergence check | "deterministic half" | A script reading a task's requirements and approach for six kinds of defect. | Two kinds stop the approach being approved; the other four are reported and stop nothing. | `skills/task/reference.md` § Step 7 — the two convergence halves (detail) |
| completeness | — | The defect where a document leaves a loose end, such as a criterion no subtask delivers. | A problem of this kind stops the approach being approved. | `agents/design.md` § Rules |
| arithmetic | — | The defect where a calculation the document writes out does not hold. | A problem of this kind stops the approach being approved. | `docs/glossary.md` § Checking a plan |
| provenance | — | The defect where a number does not say where it came from. | A problem of this kind is reported and stops nothing. | `agents/design.md` § Rules |
| reference | — | The defect where a statement points at a line number or another position that goes stale. | Only positions the project's committed list does not hold are reported; nothing is stopped. | `docs/entity-references.md` § A reference names an entity |
| pairing | — | The defect where an id a document cites does not match the id beside the code, either way round. | A problem of this kind is reported and stops nothing. | `docs/entity-references.md` § The id that joins a statement to its entity |
| isolation | — | The defect where one fact is repeated word for word in several places. | A problem of this kind is reported and stops nothing. | `docs/glossary.md` § Checking a plan |
| holding class | — | A kind of defect whose problems stop an approach being handed back or approved. | Only a problem kept with a recorded reason lets the approach through. | `skills/task/reference.md` § Step 7 — the two convergence halves (detail) |
| report-only | "advisory mode", "shadow mode" | A check, or one kind of problem a check reports, that is shown and stops nothing. | Its results inform a reviewer or the owner, who decides what to do. | `skills/task/reference.md` § Step 7 — the two convergence halves (detail) |
| contradiction reader | "plan-convergence reader", "convergence reader", "whole-pair reader", "judgement half", "judgement class" | An AI reviewer reading a task's requirements and approach for contradictions. | It reports statements contradicting each other or existing files, over three readings, and rules on nothing. | `agents/contradiction-reader.md` § Contradiction reader |
| record of accepted findings | "record of excused findings", "excuse record", "excused convergence findings", "excuse route" | A committed list of the defects a task's requirements and approach keep as they stand. | The script that found them reads it and reports those defects as kept, not open. | `docs/templates/progress-format.md` § The record of accepted findings (committed) |
| accepted finding | "excused finding", "waived finding" | One defect kept as it stands, written down with the reason it does no harm. | It stays visible in every report, marked as kept, and no longer stops approval. | `docs/templates/progress-format.md` § The record of accepted findings (committed) |
| accepting act | "grant act" | The one way a defect is recorded as kept. | A script run with the defect and the grounds shows the defect first, then writes the row. | `docs/templates/progress-format.md` § The record of accepted findings (committed) |
| record of declared links | "link record" | A committed list of statement pairs in a task's requirements and approach that must change together. | The agent writing the approach adds a pair whenever it restates or relies on a requirement. | `docs/templates/progress-format.md` § The record of declared links (committed) |
| declared link | — | One pair of statements that must change together, both quoted, with the reason. | When one statement changes and the other does not, a script reports the pair. | `docs/declared-links.md` § What a link is |
| link check | — | A script comparing each recorded statement pair with the current text. | For each pair it says whether both still stand, one moved, or the pair needs confirming again. | `docs/declared-links.md` § The check |
| record of accounted positions | "baseline record", "positional baseline" | A project's committed list of accepted pointers to line numbers, mostly ones written before such pointers were banned. | The check reports only the pointers this list does not hold. | `docs/glossary.md` § Checking a plan |
| plan invariants | — | The fixed rules on what a requirements or approach document is and must contain, with the pages stating them. | A check compares those pages with its own copy and reports a change made on one side alone. | `docs/plan-invariants.md` § The base principles |
| base principle | — | One numbered rule about what a requirements or approach document is. | It changes only by an edit to the page stating it and to the check's own copy together. | `docs/plan-invariants.md` § The base principles |
| required element | — | A section a requirements or approach document must carry. | A check derives the list from the pages demanding one and compares it with the published list both ways. | `docs/plan-invariants.md` § The required elements of a spec and of a design |
| protected page | — | A page that makes a section of a requirements or approach document required. | An edit to its headings or required section names asks first, in a session that ran a workflow turning recorded mistakes into rules. | `docs/plan-invariants.md` § The protected page set |
| near miss | — | A page close to those whose edits ask first, deliberately left outside them. | Each is listed with the reason it is outside, so the choice stays visible. | `docs/plan-invariants.md` § The near misses |
| plan-invariants guard | "edit-time refusal" | A guard over edits to the pages that make a section required. | It asks before some of those edits, and only in a session that ran a workflow turning recorded mistakes into rules. | `docs/plan-invariants.md` § The protected page set |
| learning mode | — | The state of a session that ran a workflow turning recorded mistakes into rules. | In it, the guard on pages defining required sections is switched on. | `docs/plan-invariants.md` § The protected page set |

## Reviews

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| design review | "plan review" | The sceptical review of a task's chosen approach before any code, by an agent of its own. | It approves the approach, sends it back for rework, or rejects it. | `agents/design-review.md` § Design Review Subagent |
| design review verdict | — | The outcome of reviewing a chosen approach: GO, ITERATE or STOP. | GO approves it, ITERATE sends it back for rework, STOP rejects the approach. | `agents/design-review.md` § Verdict format |
| self-review | — | The review of a finished change against its requirements, its approach and the rules, by an agent of its own. | It must approve the change before it is pushed. | `agents/self-review.md` § Self-Review Agent |
| self-review verdict | — | The outcome of reviewing a finished change: APPROVE or REJECT. | APPROVE means ready to push; REJECT means problems remain and are fixed first. | `docs/agents-method.md` § Workflow |
| whole-repository review | "whole-branch review", "codebase review", "whole-codebase review" | A review of all the code on a branch rather than of one change. | It lists problems across the code, which are then fixed and reviewed again. | `agents/review-findings.md` § Review Findings Subagent |
| checklist ledger | "review ledger" | The table ending each round of reviewing a finished change, fingerprinting each file and rule reviewed. | The next round reads it and reviews again only what changed since. | `docs/converging-review.md` § The ledger |
| review-fix round | "review-and-fix round", "scouted fix", "scouted-plan", "scouted flow" | The procedure run, in the ordered workflow building from approved requirements and approach, after its review rejects the change. | The fixes are planned and checked before any is made. | `docs/review-fix-round.md` § Step 11 — the review-fix round (recipe) |
| round baseline | — | A snapshot of the files taken when a round of fixes starts. | The fixes applied in that round are measured against it. | `docs/review-fix-round.md` § Step 11 — the review-fix round (recipe) |
| fix plan | — | A table of planned fixes, at least one row per open problem and one per file its fix touches. | It is checked before any fix is made, and the applied change is compared with it. | `agents/fix-scout.md` § The plan format |
| fix-plan check | — | A script deciding whether a table of planned fixes may be applied. | A fixed set of tests passes the table, sends it back, routes it to a change of requirements or approach, or puts it to the owner when the change is over a set size, each test printing its own line. | `docs/review-fix-round.md` § Step 11 — the review-fix round (recipe) |
| amendment trigger | — | Two tests on a problem: Arm A, closing it would leave a requirement or approach sentence untrue; Arm B, its fix edits one of those documents. | A changed requirement or a break with the agreed approach then needs an approved change of the documents; a smaller departure, in a task's own rounds, is fixed in code and the approach reworded to match. | `docs/workflow.md` § Spec-Amendment group |
| correction row | — | A row of a fix table saying the built code departs from the approved approach without breaking it. | It sends that item to be rewritten in the approach document rather than changed in code. | `agents/fix-scout.md` § The disposition vocabulary — closed |
| post-apply micro-loop | — | One question asked once fixes are applied: does the change match what was planned? | On a mismatch it allows three re-fixes, then the owner decides; review follows either way. | `docs/review-fix-round.md` § Step 11 — the review-fix round (recipe) |
| human finding | — | A review comment from a person, or a fix pushed after a pull request opened. | It is counted to see what the automatic reviews missed. | `skills/inspect/SKILL.md` § Step 1c: Findings a human raised on the session's pull request |
| post-push fix round | "post-push round", "post-push fix loop" | A round of fixes once a pull request is open, for failing checks or reviewer comments. | Each of its fixes is reviewed again before it is pushed, whichever workflow runs the round. | `docs/workflow.md` § Post-push fix commits get self-review too |

## Keeping files in step

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| Propagation Rule | — | The rule that editing one file of rules means updating the files that describe the same thing. | The updates land in the same pull request, so no file is left describing the old behaviour. | `docs/propagation.md` § Propagation Rule |
| sync group | — | A named set of files describing one mechanism, which change together. | Editing any member means checking and updating the others before the pull request opens. | `docs/propagation.md` § Propagation Rule |
| propagation reminder | — | A guard firing when the agent edits a file that belongs to such a set. | It names where the sets are listed and how to search for the files to update. | `docs/hook-inventory.md` § The hooks |
| path pattern | "propagation arm", "reminder arm", "pre-fix arm" | One file-path pattern that the reminder about keeping files in step matches. | A check derives the patterns needed from the list of file sets and confirms the reminder has them. | `docs/hook-inventory.md` § The hooks |

## Learning Log

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| Learning Log | "corrections log", "corrections-log", "instruction-violation log", "learning record" | The record of each instruction an agent broke, and the rule drawn from it. | Entries are only ever added, and recurring ones are turned into rules. | `docs/agents-method.md` § Learning Log |
| Learning Log archive | "learnings archive" | The file of older entries, into which merged branches' entry files are moved. | With the entry files not yet moved, it makes up the one history the audits read. | `docs/templates/learnings-entry-format.md` § Target file |
| Learning Log fold | — | Moving merged branches' entry files into the archive unchanged, then deleting them. | It runs first in the workflow that turns recorded mistakes into rules. | `skills/improve/SKILL.md` § Fold — run this FIRST, before the spawn below |
| promotion candidate | — | A lesson about the shared rules, stripped of any one project's names. | It is kept for a later sweep that may add it to the rules every project receives. | `skills/improve/SKILL.md` § Step 5b: Promotion candidates (optional, asks first) |
| redaction gate | — | A check on a lesson or a report before it leaves the project. | It refuses one naming the project's own material. | `skills/improve/SKILL.md` § Step 5b: Promotion candidates (optional, asks first) |

## Checks and hooks

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| hook | — | A script the host runs on its own at a fixed moment, such as a session's start or before a tool call. | Through it the plugin acts on the agent's work without being asked. | `docs/hook-inventory.md` § The hooks |
| gate | — | A check whose result decides whether work goes on. | Work stops when it fails, and a run that measured nothing never counts as its pass. | `docs/gate-outcomes.md` § The three outcomes this page defines |
| could-not-run | — | A check's result when it measured nothing. | It is reported on its own and never read as a pass. | `docs/gate-outcomes.md` § The three outcomes this page defines |
| positive control | — | A fault planted on purpose where a check should catch it. | Showing the check catches it proves the check is not passing by accident. | `docs/gate-outcomes.md` § A gate whose judgement a model makes |
| check list | "gate list" | A project's whole set of checks, run together. | It must pass, unchanged files and all, before the work is pushed. | `docs/check-scope.md` § The single full run |
| check-list member | — | One named check in that set. | It reports its own result, and a run can select members by name. | `AGENTS.md` § Build & Test |
| check runner | "gate runner" | A script running, in one call, every check of the plugin's own files except the three testing delivery to a project. | It prints one result per check and fails when any failed or could not run. | `AGENTS.md` § Build & Test |
| structural check | — | A check of the plugin's own files. | It tests what the files say, as against whether they reach a project. | `AGENTS.md` § Build & Test |
| verdict line | — | The line stating a check's result, clean, problems found or could not run, and how much it examined. | Reading it, not just the exit status, shows a run that read too little. | `docs/gate-outcomes.md` § The three outcomes this page defines |
| spec-criteria check | — | A script reading requirements and review instructions for two kinds of overreach. | It refuses a criterion naming how it is tested, and a review taking leave to skip a problem on any ground but a finished task's requirements. | `agents/spec-writer.md` § What a spec IS, and what it may not contain |
| plan-invariants check | — | A script comparing the fixed rules for requirements and approach documents with the pages stating them. | It reports a rule reworded on one side, a required section added or dropped on one side, and a guard out of step with its page list. | `docs/plan-invariants.md` § Two surfaces, deliberately different in width |
| touched-scope run | — | Running, inside a loop, only the checks the changed files select. | It keeps each round short; the whole set still runs once at the end. | `docs/check-scope.md` § Selection inside the loop |
| full run | — | Running the whole set of checks once, after review approves. | Its pass on unchanged files is what lets the work be pushed. | `docs/check-scope.md` § The single full run |
| delivery gate | — | A check that what the plugin ships reaches a project. | Three test one step each: that the plugin installs and loads, that a shipped change raised its version, that the documented upgrade works. | `AGENTS.md` § Build & Test |
| result masking | "gate-pipe-guard" | Hiding a check's failure behind another command's success, such as by piping it into a filter. | A guard refuses its common shapes before the command runs. | `docs/agents-method.md` § Tooling |
| gate record | — | A guard recording runs of known checks, with the state of the files they ran on. | It tells the agent when a check repeats on unchanged files or contradicts an earlier run. | `docs/check-scope.md` § What the gate record reports along the way |
| tree digest | — | A fingerprint of the files as version control sees them. | Two runs with the same fingerprint ran on the same files. | `docs/check-scope.md` § The tree-unchanged condition |
| fixture | "frozen fixture" | A recorded real input a check replays, with the results it must reproduce. | It is never refreshed casually, since a refresh can hide the change it exists to catch. | `docs/agent-docs-index.md` § `ai-docs/fixtures/` |
| loop ledger | — | The per-session file where the plugin's guards record each tool call and what they noticed. | The guards and later reviews of the session read it to find loops and repeated work. | `docs/loop-ledger.md` § The loop ledger |
| loop detector | — | The guards flagging a repeated call, or one kind of call repeated within a turn. | They ask before a repeat runs, or note a loop when a turn ends, and never block the turn. | `docs/hook-inventory.md` § The hooks |
| measurement setup | "measurement arm" | One of the setups a measurement compares. | Each is run the same way, so the difference between them is the effect measured. | `docs/glossary.md` § Checks and hooks |
| payload sibling | — | A program in another language that a shell script loads. | Callers always run the shell script, never the program itself. | `AGENTS.md` § Language profile |

## The harness and a project

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| harness | — | The plugin itself: the shared rules, workflows, agents, guards and checks it ships to every project. | It is installed for a user or for one project. | `docs/agents-method.md` § Agent Rules — method |
| consuming project | — | A project using the plugin. | It keeps its own commands and facts, and takes the shared rules from the installed plugin. | `docs/workflow.md` § Installed method half |
| scaffolding | — | The starting files the plugin writes into a project when it is set up there. | It never overwrites a file the project already has. | `skills/harness-init/SKILL.md` § Step 1: Scaffold (dry run first) |
| method | — | The half of the plugin's rules that holds in every project. | It names no language, build tool or project fact; those live in each project's own half. | `docs/agents-method.md` § Agent Rules — method |
| profile | — | A project's own half of the rules: its commands, language, permissions and facts. | It also says which commands post text to the review surface or the tracker, and wins on a project fact. | `docs/agents-method.md` § Agent Rules — method |
| project registry | — | The list of projects set up with the plugin, kept in the user's home folder. | It holds paths and labels only, and says which projects share lessons with the others. | `skills/harness-init/SKILL.md` § Registry |
| deployed configuration | — | Files holding the settings of one environment, such as a deployed server's. | The agent reads them only after asking. | `docs/agents-method.md` § Permissions |
| instruction file | — | A file of rules the agents read. | Those loaded whole when a session, agent or workflow starts are capped in size, since each start pays for them. | `docs/agents-method.md` § Build & Test |
| instruction size cap | — | The limit on the size of a file loaded whole when a session, agent or workflow starts, with an early warning below it. | A file past the early warning is reported, so the next task still has room to add a rule. | `docs/agents-method.md` § Build & Test |
| AXIOM | — | A rule the shared rules mark as binding with no exception. | It is written as one short rule followed by a table of the cases it decides. | `docs/agent-writing-style.md` § 2. Fail-loud AXIOMs for stick rules |
| defect report | — | A report a project files back to the plugin's maintainers about a defect in the plugin. | It is checked for the project's own material before it is filed. | `skills/report-defect/SKILL.md` § Step 2: Draft the report |

## Knowledge base (planned, not yet part of the harness)

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| knowledge base | — | A project's store of its current requirements, constraints and deliberate non-goals, one file per area. | Tasks will read and update it instead of each keeping its own requirements. | planned |
| knowledge-base workflow | "card flow" | The planned way of running a task, writing its requirements into the project's store of requirements. | It replaces a task's own requirements document with edits to that store. | planned |
| task document | "task card" | The short committed document holding what a task does not leave in the project's store of requirements. | It carries the task's goal, what it leaves out or defers, one-off duties, the requirements it changes and where the owner's answers are kept. | planned |
| interview summary | "interview card" | What the owner approves after the questions, before the approach is written. | It states the task's requirements as edits to the store, for one approval. | planned |
| knowledge-base section | "merge card", "PR card" | The section the plugin writes into a pull request's description. | It lists the requirements the pull request adds, changes or removes in the store. | planned |
| summary command | — | The command building the owner's summary after the questions, and the section for a pull request's description. | It reads the task's edits to the store and writes both texts. | planned |
| interview approval commit | "interview freeze" | The commit recording that the owner approved the summary after the questions. | Every later change to the task's requirements is measured from it. | planned |
| required CI check | "merge gate" | The check a pull request must pass before it can merge. | It runs on the review surface, not on the agent's machine. | planned |
| new-conflicts-only blocking | "ratchet mode" | A promoted check refusing only the conflicts a branch itself brings. | Conflicts already there are reported and do not block. | planned |
| list of removed statements | "removed registry" | The record of statements taken out of the project's store, with the reasons. | No agent reads it; the tool shows the owner any new requirement matching it, with the earlier reason. | planned |
| defaults list | "the one block" | A ticket's open choices, each with a recommended default, confirmed by the owner in one answer. | It replaces one question per choice with a single confirmation. | planned |

## This vocabulary

| Canonical name | Other names | What it is | What it does | Defined at |
|---|---|---|---|---|
| glossary | — | This page: one entry per concept of the plugin, opening with the rule for text written to a person. | It is put into the context of the agent a person talks to and into the briefs of some agents that agent starts; the checks read its names from it. | `docs/glossary.md` § Glossary |
| listed name | — | A name this page lists as an other name or a retired name. | Text for a person may not use it as a term; the plugin's files carry it only here and where a script must. | `docs/glossary.md` § Glossary |
| vocabulary check | — | A check failing when a name this page lists appears in the plugin's own files. | It names the file, the line and the name, and reports how many files it read per group. | `AGENTS.md` § Build & Test |
| plain-words check | — | The guards checking what the agent writes to a person against this page's rules. | They can hold back a question or a post, or have chat restated; every reading is recorded. | `docs/hook-inventory.md` § The hooks |
| internals mark | — | A comment on a script line whose word must stay as it is. | The check for names this page lists skips that line. | `docs/glossary.md` § Words a script must keep |
| model-call marker | — | A setting a guard of the plugin puts in the environment of a model it calls. | The guards that load this page or read text for a person do nothing inside that call, so it starts no further calls. | `docs/hook-inventory.md` § The hooks |

## Retired names

| Retired name | What it named |
|---|---|
| closing fold | The removed last step of a task, which applied the logged changes to the approach document and cut the requirements down. |
| redline fold | The same removed step. |
| redline log | The log of approach changes that step applied, removed with it. |
| correction log | The same removed log. |
| redline | That log, and anything named after it. |
