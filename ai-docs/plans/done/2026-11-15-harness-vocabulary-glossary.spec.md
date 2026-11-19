# One vocabulary for the harness: a glossary of plain descriptions, a refusal of retired and duplicate names, and a check on what the agent writes to a person

**Source:** ticket GH-166
**Date:** 2026-11-15
**Tracked in:** GH-166

## Scope

**Today.** The harness has no fixed vocabulary. In the files it ships, one concept often carries several
names (the Learning Log is also called "corrections log"; the record of convergence findings accepted as
they stand is called "record of excused findings", "excuse record" and "waiver"), and one name often names
several things ("fold" names the Learning Log's merge of per-branch entry files into its archive, working
the plan review's notes into the design, and an archived spec that a since-removed last step cut down). A
name whose concept was removed survives when nothing lists it as removed: the last step of a task, removed
by an earlier ticket, still has its name in a message a script prints. In conversation the agent renders
internal labels word for word into the owner's language or coins a fresh name, and the owner cannot follow:
"a folded spec" rendered into Russian, "card" used for three different documents. The method already
forbids agent-internal vocabulary in anything addressed to a person, and the rule did not hold, because it
names no words, leaves the agent to notice its own coinage, and nothing reads what reaches the person.

**What this task delivers.**

1. **One glossary page among the files the plugin ships to every project.** One entry per concept, each
   carrying the canonical name, the concept's other names, one sentence on what the thing is, one sentence
   on what it does written for a person who has never opened the harness's files, and where the concept is
   defined by page and section name. Retired names are listed with what they used to name.
2. **One name per concept and one concept per name.** Every other name on the covered surfaces is replaced
   with the canonical name in one sweep; every name that named several things keeps at most one of them.
   Pages, scripts, commands, flags and the files the harness names for a task, when named with an other
   name or a retired name, are renamed, with every reference to them moved; script internals keep their
   words.
3. **A refusal of every listed other name and retired name on the covered surfaces**, deterministic, run
   with this repository's other checks.
4. **A rule for everything the agent writes to a person**: the meaning is carried by the entry's plain
   description in the person's language, never by a translation of the label; no new name is coined; a
   concept with no entry is described by what it does, and an entry is proposed for it.
5. **The glossary's descriptions are in the agent's context from session start**, so the rule names the
   words rather than leaving the agent to recall them.
6. **A check on the text the agent writes to a person**, in every project using the harness: the listed
   names are matched against it, and a model reads it for a breach of the rule. A question to the person
   and a text posted to the review surface or the tracker are read before they reach the person and are
   refused on a finding; chat text cannot be held back, so it is read when the agent ends its turn, and on
   a finding the agent restates the affected sentences in plain words, once.
7. **The knowledge-base ticket's concepts get their names here**, so that ticket's spec, which waits for
   this one, uses them rather than coining its own.

**Concepts that get an entry.**

- The three concepts found under several names: the Learning Log; the record of convergence findings
  accepted as they stand, and each entry in it; the AI reviewer that reads the spec and the design for
  contradictions.
- Each sense of every name that names several things — at least *fold* (the Learning Log's merge, working
  the plan review's notes into the design, and an archived spec the removed last step cut down, which the
  checks still recognise), *card* (the section the harness writes into the PR description; the task's own
  document; the summary built for the owner's approval after the interview; the command that builds the PR
  description's section), *arm*, *baseline* and *freeze* (today's commit at the plan review's approval; the
  commit recording the interview approval in the knowledge-base plan). Each sense gets its own entry.
- The concepts that reach the owner most: the spec and the design, the freeze, the convergence check and
  its classes, the review rounds and their verdicts, the steps of a review-fix round, the propagation sync
  groups, the Learning Log and its fold.
- The things named by coinages in recorded conversations: one setup among those compared in a measurement;
  the version of the files the next review compares against; the helper agent that records which spec and
  design statements must change together.
- The knowledge-base ticket's concepts: the section the harness writes into the PR description; the
  interview summary built for the owner's approval; the task document; today's spec workflow and the
  knowledge-base workflow; the required CI check; report-only; blocking only the conflicts a branch brings;
  the list of removed statements; the list of defaults the owner confirms in one answer; the commit
  recording the interview approval; the command that builds the PR description's section; the knowledge
  base itself.
- Every harness term in a message a hook or a script prints for a person.

**Covered surfaces** — what the sweep rewrites and the refusal reads:

- every file the plugin ships to every project — method pages, skills, agents, rules, hooks and scripts:
  their prose, their comments and the messages they print for a person;
- this repository's own project files: its agent rules file, its project context page and the Learning
  Log's contract page;
- the scaffolding every new project receives;
- the harness's user-facing description: its read-me and the description shown when the plugin is
  installed.

**Checked texts** — what the check on text for a person reads:

- a question the agent puts to the person, before the person sees it;
- a text the agent posts to the review surface or the tracker — a PR description, an issue text, a comment
  — before it is posted;
- the text the main agent writes in chat during a turn, when it ends that turn.

**Terms.** *Canonical name* — the one name an entry fixes for its concept. *Other name* — a name in use for
a concept that is not its canonical name. *Retired name* — a name whose concept no longer exists in the
harness. *Listed name* — an other name or a retired name the glossary lists. *Plain description* — an
entry's two sentences, what the thing is and what it does, naming no file, script, command, section or
other entry. *Text for a person* — anything the agent writes that a person reads: a chat reply, a question,
a hand-back, a design put up for approval, a PR description, an issue text. *Mention* — a name written as a
quotation, inside quotation marks or code marks, to talk about the name itself. *Script internals* — a
script's variable names, function names and the ids marking them, and any text a script must match because
files written before the task carry it — an old file name it still reads, a retired word it refuses in a
document — together with a test's planted input for that match. *The owner* — the person who runs the
harness and approves its plans.

## Out of scope

- **Archived plans.** History, never edited.
- **The Learning Log's entries and promotion candidates**, archive and per-branch files alike. The log is
  append-only; old names stay in old entries. The log's contract page is covered.
- **Frozen fixtures** — recorded real-world inputs a check replays.
- **Issue texts and PR descriptions already posted.** Not rewritten.
- **Plan documents of a task**, active or archived, are read by neither the refusal nor the check on text
  for a person: a plan about a vocabulary change quotes the names it retires. The rule for text for a
  person still binds the design's prose, and review holds it there.
- **The knowledge-base ticket's spec draft in this repository.** That ticket's own next requirements round
  rewrites it with the glossary's names; this task does not edit another task's spec.
- **Text one agent writes for another** — a brief, a subagent's report. It is not text for a person. What
  the main agent relays from it to the person is chat text, and is checked there.
- **Script internals.** They keep their words; the refusal does not read them. Renaming a function or a
  variable changes nothing a person reads, and renaming a matched text would change what the script does
  with files written before the task.
- **Projects already using the harness.** Their own files are theirs and scaffolding never overwrites an
  existing file; they receive the new words through the plugin's own files and through any file they
  scaffold afresh. The check on text for a person reaches them, as every hook the plugin ships does.
- **Any change to what an existing mechanism does.** This task renames and describes; its only new
  mechanisms are the glossary, the refusal, the rule and the check on text for a person.
- **How the harness behaves in auto mode**, and what an agent may decide there without asking. A separate
  ticket.
- **The method's short list of the owner's own phrases** ("submit / push to PR", "wtf?"). It glosses the
  owner's words, not the harness's, and stays where it is.

## Deferred

| What | Why | Separate ticket needed? |
|---|---|---|
| A refusal a consuming project runs over its own files | Not asked for; a consuming project's own files hold its own vocabulary, and the harness's words in them come from a scaffold that never overwrites | Yes, if wanted |

## Key decisions

| Question | Decision |
|---|---|
| Is this the terminology ticket, and when does it run? | This ticket is the terminology ticket, extended rather than replaced. It goes first; the knowledge-base ticket waits and its spec uses this ticket's names. (Owner, 2026-11-11, repeated 2026-11-13.) |
| Auto mode | A separate ticket; nothing here depends on it. (Owner, 2026-11-11.) |
| Language of the glossary | English, like every file. Toward a person the agent translates the description, never the label, so the method stays language-neutral. (Ticket; the method's English-for-files rule.) |
| May the canonical name appear in text for a person? | Only as an untranslated parenthetical after the plain description; the description carries the meaning, so the sentence still works with the name deleted. (Default taken here, from the owner's standing rule that an identifier is at most a parenthetical for someone who wants to verify.) |
| A concept with no entry | Described by what it does, with no new name; the proposed entry goes to the list of owner items at the end of the task or in the PR description. Work does not stop for it and the owner is not asked mid-task. (Ticket; the owner's standing rule against a confirmation that stops the work.) |
| A new concept introduced in a covered file | Arrives with its entry in the same change. Held by the written rule and by code review: the refusal recognises only the names it lists, so it cannot see a brand-new synonym. (Default taken here.) |
| Where the glossary loads | Its plain descriptions are in the context of the main agent, and of every agent that writes text for a person, from session start, without the agent deciding to open a page — reached only by link, it would be shut exactly when the agent fails to notice its own coinage, which is the failure. The method page cannot hold it: it stands at 34,186 characters against the 35,000 early warning (measured by character count on this branch, 2026-11-15; the warning is a threshold the method hands down). A page of its own fits: at about 410 characters an entry — name 30, other names 50, two sentences 250, location 60, markup 20, an estimate from the entry's fields — the page stays below the warning up to about 85 entries (35,000 divided by 410), and the list under § Scope comes to about 42 by this spec's count, taking the convergence check's six classes as the task workflow's reference page enumerates them and estimating the verdicts at two entries and the review-fix round's steps at three, before the terms in printed messages are counted. The size rule applies to it as to every file loaded whole. (Default taken here.) |
| Which concepts get an entry | The list under § Scope. (Ticket's starting list, its table of plain names already in use, its recorded coinages, and the known names with several senses; default taken here.) |
| How a canonical name is chosen | The plain name already most used for the concept, unless it also names another concept or misleads; a name that named several things keeps at most one. The owner sees every canonical name and its other names when approving the design, before the sweep. (Default taken here.) |
| Is "folded spec" a retired name? | No. The step that cut archived specs down is removed, but the checks still recognise such a spec and skip it, so the thing exists and gets an entry; "folded spec" becomes one of its other names. The retired names are the removed step's own: closing fold, redline fold, redline log, correction log, and redline. (Read in the convergence and link checks' code on this branch, 2026-11-15: both still recognise such a spec and skip it.) |
| Which surfaces the sweep and the refusal cover | Those under § Scope, with history, fixtures and plan documents out. (The ticket's proposal, which the owner has not confirmed; taken as the default because each covered surface is one the agent reads or a person sees, and the owner may narrow it at the requirements' approval. The read-me and the installed description are added here as the harness's user-facing text.) |
| Does the refusal block? | Yes: a listed name on a covered surface fails this repository's checks, which the agent fixes before the push. It never waits on the owner. (Ticket.) |
| Retired names | Listed in the glossary with what they named, and refused like other names. (Ticket: a retired name outlives its concept when nothing lists it.) |
| Entries for concepts the harness does not have yet | The knowledge-base ticket's concepts get full entries now; their location says the concept is planned and not yet part of the harness, and is filled when that ticket lands. (Ticket.) |
| The knowledge-base ticket's own planning documents, kept outside this repository | Rewritten with the glossary's canonical names when this task closes, so that ticket starts from them. (Default taken here; the owner may move it to that ticket's start.) |
| Are files, scripts, commands and code names renamed too? | Pages, scripts, commands, flags and the files the harness names for a task, when named with a listed name, are renamed, with every reference moved; script internals keep their words, and the refusal does not read them. (Owner, 2026-11-15, the recommended option of three: files and commands but not code internals, over renaming code internals too and over renaming nothing.) |
| A file a project already holds under an old name | A per-task file the harness writes and later reads by name — the record of convergence findings accepted as they stand is one, named after "excuse" — is written under its new name from now on, and a record written under the old name before the update is still read, so a task in progress when the plugin updates keeps the findings it accepted. The old name stays only as matched text inside the script. (Default taken here: not reading it would change what an existing mechanism does on the same input, which is out of scope. No such record exists in this repository, measured by a search of the tracked tree on this branch, 2026-11-15.) |
| Does anything mechanical read the text the agent writes to a person? | Yes, both the name list and a model reading, over the checked texts under § Scope. (Owner, 2026-11-15, the recommended option of three, over the name list alone and over files only.) |
| What the model looks for | Three kinds of breach of the rule: a name translated word for word and used as a term; a name the agent invented for a concept; a harness name carrying the meaning with no plain description beside it. The first two are what the owner was offered; the third is the rule's own first clause, and is taken here because the recorded failure — a label the person could not decode — is that kind as often as the other two. (Default taken here; the owner may drop the third at the requirements' approval.) |
| How a finding on each checked text is acted on | A question or a posted text is refused before it reaches anyone, with the finding named, and the agent rewrites it. Chat text has already been shown, so the agent continues once and restates the affected sentences in plain words; the restatement is not read again. The finding is reported to the agent and ruled on by nobody: neither the list nor the model decides whether it does harm. (Owner's answer for the reading; the mechanics follow from what each moment allows.) |
| A name quoted as a name | A mention, not a use: the name list does not match it and the model reads it as a mention. Answering the person's question about a name, or a PR description saying what this task renamed, needs one. (Default taken here; the alternative refuses this task's own PR description.) |
| The model's reading must not stop the agent reaching the person | After the model's reading alone has refused a question or a posted text in a turn, the next one in that turn is not refused on the model's reading. A listed name used as a term is refused every time, because the agent can always remove it. (Default taken here; the owner's standing rule that nothing stays red waiting.) |
| When the check cannot read | When the model is not available, its call fails, its answer cannot be read, or the name list cannot be read, the text goes through unchanged and work continues; the person is told once in that session that what the agent writes to them is not being checked, and no record reads it as a check passed. (A could-not-run is not a pass; work is never blocked on the model.) |
| Is the check on in every project? | Yes, by default in every session of every project using the harness. Its cost is one model reading per turn and per question or posted text, each carrying the glossary. (Default taken here, from the owner's choice of a model reading of each message.) |
| Are the check's findings kept? | Each finding and each could-not-run is recorded with the session's other hook records, so how often text for a person was flagged can be counted afterwards and the check's effect measured. (Default taken here, from the owner's standing rule that a mechanism is trusted only once a measurement shows its effect.) |
| The design put up for approval | Bound by the rule and held by review; the check on text for a person does not read it, because it is a plan document and a vocabulary task's design quotes the names it retires. The question asking for the approval is checked like any other. (Default taken here.) |

## Technical constraints

- **Instruction budget.** Every instruction file loaded whole at agent start stays below the method's
  35,000-character early warning (a threshold the method hands down). The method page stands at 34,186,
  this repository's project context page at 33,673 and its agent rules file at 24,197 (measured by
  character count on this branch, 2026-11-15). A glossary loaded whole joins that class.
- **Method and profile stay apart.** The glossary, the rule and the check on text for a person are method:
  they hold in every project and name no language, build tool, host, tracker, ticket prefix or project.
  Which commands post a text to the review surface or the tracker is a project fact; the method's check
  names no host or tool. Project facts stay in the profile.
- **What a hook can do at each moment.** A question tool call and a posting command can be refused before
  they run, so the person never sees the refused text. Chat text cannot be held back. A hook at the end of
  a turn can make the agent continue, and the hook inventory records that as a loop hazard, so the
  continuation runs at most once per turn. A model can already be called from a hook: the existing
  turn-end loop detector's optional model stage does so, and ends silently when no model is available.
- **A check whose judgement a model makes** is held to the method's standard for one: could-not-run is not
  a pass; it reports and rules on nothing; each class it covers has a planted case shown to be caught; its
  agreement across repeated readings of one unchanged input is measured and reported; and it never runs
  without a deterministic check beside it — here, the name list.
- **The existing turn-end hooks.** The extra turn end a restatement adds is one more stop to the loop
  detectors already wired there; none of them may read it as a repeat or a loop.
- **Archived plans are never edited; the Learning Log is append-only.** A rename that leaves a mention of
  an old name in an archived plan or a log entry leaves history, not a broken reference: the archived plans
  and the log mention the two files named after a listed name — the Learning Log's field page and the
  spec-criteria check with its test — only as quoted text, never as a link or a plugin path (measured by
  search of both on this branch, 2026-11-15).
- **The record of accounted positions.** The convergence check compares the tree against a recorded list
  of positional references that predate their prohibition, keyed by the file that holds each one, and
  reports any position the list does not account for. The spec-criteria check's test holds three such
  rows (measured on this branch, 2026-11-15), so renaming it moves those rows' file path and nothing else.
- **The refusal's limit.** It recognises the names it lists, as written; a fresh synonym or a rendering in
  another language is outside it, which is why the rule, the model reading and review hold that part. A
  word that keeps one of its senses and is also ordinary English — fold, card, arm, baseline, freeze —
  cannot be listed bare without refusing ordinary prose; which forms of it the list holds is the design's
  to choose, and the sweep and review hold the rest.
- **A could-not-run is not a pass**, and the full check list runs clean with no check's input set silently
  narrowed.
- **Every reference moves with what it names.** A renamed page, script, command or flag leaves no link,
  path or invocation on a covered surface pointing at its old name.
- **Release.** The change touches plugin-loaded content, so the plugin's version is bumped in the same pull
  request (project convention).

## Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | The plugin ships one glossary page to every project, holding an entry for every concept listed under § Scope; each entry carries the canonical name, the concept's other names, one sentence on what the thing is, one sentence on what it does that names no file, script, command, section or other entry, and where the concept is defined by page and section name — or, for a concept the harness does not have yet, that it is planned. |
| AC2 | The glossary lists every retired name with what it used to name, the names of the removed last step of a task and its log among them: closing fold, redline fold, redline log, correction log and redline. |
| AC3 | Across the glossary, no name is the canonical name of two entries, no name is listed as another name of two entries, and no canonical name is also listed as another entry's other name or as a retired name. |
| AC4 | Once the task closes, no listed name appears on any covered surface, except in the glossary itself, in the list the refusal reads, and in script internals. |
| AC5 | Every name that named several things before the task — fold, card, arm, baseline and freeze among them — names at most one concept on the covered surfaces once the task closes, and each other thing it named is called by its own entry's canonical name. |
| AC6 | When a change adds a listed name to a covered surface — in prose, in a comment, or in a message a hook or a script prints for a person — this repository's full check list fails, naming the file and the name found, and it never asks the owner anything to pass; a listed name in script internals is not refused. |
| AC7 | When the refusal cannot read its list or a covered surface, it reports that it could not run, which never reads as a pass, and every report it gives names the surfaces it examined. |
| AC8 | In every session of a project using the harness, from session start, every entry's plain description is in the context of the main agent and of every agent that writes text for a person, without the agent having to decide to open a page. |
| AC9 | When the agent writes text for a person and refers to a concept that has an entry, the meaning is carried by the entry's plain description in that person's language; the canonical name appears at most as an untranslated parenthetical, and no translation of a name is used as a term. |
| AC10 | When the agent writes text for a person and needs a concept that has no entry, it describes what the thing is and does without giving it a name, and a proposed entry appears in the owner's items at the end of the task or in the PR description; the work does not stop for it. |
| AC11 | No page, script, command, flag or file the harness names for a task carries a listed name in its own name, every reference on a covered surface to a renamed one resolves to its new name, and script internals keep their words. |
| AC12 | Apart from the glossary, the refusal, the rule and the check on text for a person, every hook, check and workflow step gives the same outcome on the same input as before the task — a renamed page, script, command or flag called by its new name, and a per-task file written under its old name before the update still read — differing only in the names and words it uses; the extra turn end a restatement adds changes no verdict an existing turn-end hook reaches. |
| AC13 | No archived plan, Learning Log entry, promotion candidate or frozen fixture is changed by the task, except that where a renamed file holds positions the record of accounted positions lists, those rows change their file path to the new name and nothing else. |
| AC14 | Every instruction file loaded whole at agent start stays below the early-warning size, the glossary included. |
| AC15 | When the task closes, the knowledge-base ticket's planning documents kept outside this repository use the glossary's canonical names and no listed name. |
| AC16 | When the agent puts a question to the person and the question uses a listed name as a term, or the model reads in it a name translated word for word, an invented name, or a harness name carrying the meaning with no plain description, the question is refused before the person sees it, the refusal names what was found, and the agent can rewrite it and ask again. |
| AC17 | When the agent posts a text to the review surface or the tracker — a PR description, an issue text, a comment — and the text has a finding of the kinds in AC16, the post is refused before anything is posted, the refusal names what was found, and the agent can rewrite it and post again. |
| AC18 | When the main agent ends a turn and the text it wrote in chat during that turn has a finding of the kinds in AC16, the agent continues once and, before the turn ends, restates each affected sentence in plain words in the person's language, asking the person nothing; the restatement is not read again, so a turn has at most one. |
| AC19 | A listed name or a harness name written as a mention — inside quotation marks or code marks — is not a finding of the name list, and the model reads it as a mention rather than a use. |
| AC20 | After the model's reading alone has refused a question or a posted text in a turn, the next question or posted text in that turn is not refused on the model's reading; a listed name used as a term is refused every time. |
| AC21 | When the model is not available, its call fails, its answer cannot be read, or the name list cannot be read, the checked text goes through unchanged, the work continues, and the person is told once in that session that what the agent writes to them is not being checked; nothing records that text as having passed the check. |
| AC22 | Each kind of finding the model looks for is shown to catch a planted case of that kind, the model's agreement across repeated readings of one unchanged text is measured and reported, and the model never reads a text without the name list being matched against the same text. |
| AC23 | Every finding of the check on text for a person, and every time it could not read, is recorded with the session's other hook records, naming the kind of text, the kind of finding and the words found. |

## Open questions

- None.
