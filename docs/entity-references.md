# Entity references and the id that pairs them

What a durable reference may name, how a statement and the source entity it leans on are joined by a
shared id, and the one carve-out that still admits a position inside a file. Pointed at from
[`${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md` § Tooling](${CLAUDE_PLUGIN_ROOT}/docs/agents-method.md#tooling),
which keeps the rule that a line number is stale the moment anyone edits the file and points here for the
form a reference takes instead. This page is pure reference: it states no rule about what any document must
contain, and nothing on it makes any part of any document required.

## A reference names an entity

A reference identifies its target by name, inside a file it names:

- **In source** — a method, a class or a variable.
- **In prose** — a heading, or a numbered item. Both are already declared identities.

**A position within a file is not a form of reference.** It is forbidden wherever that position outlives
the task it was taken in, or wherever a reader may trust it without having re-derived it — which reaches an
always-loaded instruction page, a party's contract, an enforcement script and a template alike. A plan
document is one place the prohibition bites, not the extent of it, and a position is never what either side
of a pair points at.

**The property an entity reference buys is detectability, not stability.** Both forms go stale when the
file moves under them. The difference is what happens next: a stale entity name resolves to nothing and
announces itself, while a stale position resolves to whatever now sits there — in the worst case to
something of the same kind and the same shape that states the opposite of what the citing statement
promised.

## The carve-out is two conditions together

A position inside a file stays admissible in output satisfying **both** of the conditions below. This
enumeration is the definition of the carve-out rather than a count taken from anywhere else:

1. **The output outlives no task.** It is written inside the one it serves and is discarded with it.
2. **Every position in it is re-derived** against the file at the moment the row carrying that position is
   written or touched.

Either condition alone is not the carve-out. The first without the second leaves a later reader — spawned
fresh, never having opened the file — trusting a position somebody else wrote earlier in the same task.
The second without the first stores a re-derived position somewhere the next reader has no reason to
re-derive it again.

**The carve-out is a property of the output, never the identity of the file holding it.** Output failing
either condition carries no admissible position wherever it sits, and a file that is the usual home for
admissible output does not make the next thing written into it admissible.

## The id that joins a statement to its entity

A statement that leans on a source entity carries an id, and the same id appears in a comment on that
entity. The statement names the entity for the reader; the id is what a check reads.

**Spelling.** A bracketed marker whose payload is a lowercase slug of alphanumerics and dashes. That
spelling is the shape filter, and **it binds both sides** — a statement's id and the mark on an entity are
recognised by the same rule. A page explaining the convention writes its templates with angle brackets,
which are not slug characters, so explaining the mechanism does not turn a document into a marked one.

**Where the entity is prose**, its heading or numbered item is already a declared identity and carries the
id without a comment.

**An id's mark sits inside one of the files the claiming statement names.** A statement claiming an id
while naming no file is itself reported, because nothing then bounds where the mark may be.

**The limit of the guarantee, stated rather than left to be inferred.** A statement naming one entity whose
mark sits on a different entity inside the same named file pairs cleanly. So the pairing proves colocation
with a file and an author's intent; it never proves that the marked entity is the named one. What it does
prove is the thing a position cannot: a vanished entity takes its comment with it, so the id stops
resolving.

## How the two sides are compared

- **By equality over whole ids, never by containment.** A containment search reports a short id as
  accounted for because some longer id contains it.
- **In both directions.** An id a statement names that no marked entity carries is reported; an id marked
  on an entity that no statement names is reported. Each report names the id and which side was missing.
- **With the number of pairs actually compared printed beside the verdict**, so a document carrying no ids
  and a source carrying none do not read as agreement.

## Uniqueness is reported, not engineered

An id resolves to exactly one entity. The same id marked on two entities, or claimed by two statements, is
reported as ambiguous in both directions rather than passing in either.

No namespace prefix is imposed to guarantee it. A prefix cannot survive a careless copy, the ambiguity
report is owed anyway, and standing up two mechanisms for one property is itself the kind of duplication a
plan is held against.

## Where a comment cannot exist, the obligation narrows in one direction

Some entities live in a file whose language admits no comment at all — a line added as one stops the file
being readable by whatever consumes it. For such an entity the obligation narrows, and says so:

- The statement names the entity, as everywhere else.
- The resolution runs in **one direction only** — from the statement to the file it names, which must
  exist.
- **No reverse pairing is asserted** for it. The guarantee holding in both directions does not cover those
  entities.

The narrowing is a property of the language, not a list of the files that have it today. A rule that
silently lost a guarantee would be worse than one stating where it stops, which is why the limit is written
here rather than inferred.

## An id comment is a directive, not narration

The comment carrying an id exists for an instrument to read. Deleting it breaks the pairing in one
direction and leaves the statement claiming an id that resolves to nothing — so removing one is a finding
and never a cleanup. The rule admitting such a comment, and the membership test deciding what counts as a
directive at all, live on
[`${CLAUDE_PLUGIN_ROOT}/docs/code-style.md` § Comments](${CLAUDE_PLUGIN_ROOT}/docs/code-style.md#comments):
this page states what an id is, and that page states which comments survive a sweep.
