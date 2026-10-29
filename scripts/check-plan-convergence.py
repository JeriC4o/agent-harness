# The logic half of check-plan-convergence.sh: the plan pair, what every class
# reads, the excuse route and the report. Invoked as
# `python3 check-plan-convergence.py <method-root> <method-indexed> <project-root>
# <spec> <design> [<excuse-key> <grounds>]` by the wrapper beside it, which owns
# the flags, the preflights, the root resolution and the exit convention.
#
# There are three payload files: this one, check-plan-convergence-holding.py
# with the two classes that HOLD a plan, and
# check-plan-convergence-reporting.py with the four whose findings are a
# report. This file loads both -- see THE TWO PAYLOAD SIBLINGS below for what
# stays here and why.
#
# Tests: scripts/test-check-plan-convergence.sh
#
# THIS FILE HOLDS NO SECTION NAME OF A SPEC OR A DESIGN AS A LITERAL, and that
# is a condition on which the check stays OUT of the edit-time refusal's page
# set rather than a stylistic preference. A page joins that set by defining or
# by enforcing a required element, so a script carrying a section token beside a
# presence word reads as enforcing one -- and a check in that set has any edit
# that changes its section data put to the author during a learning pass. The
# names it needs are derived from the
# required-element record at run time, the way the propagation gate derives its
# path classes from the table beside them.
#
# WHAT IT NEVER REPORTS, for the same reason: that a derived section is ABSENT
# from the document under examination. A finding naming the section would assert
# the section's presence, which is the shape that makes a page protected, and a
# cannot-run would let this check hold a plan on a missing heading. The region
# is empty, the examined count prints as zero, and a reader weighs the zero.
import importlib.util
import os
import re
import subprocess
import sys

METHOD_ROOT = sys.argv[1]
METHOD_INDEXED = sys.argv[2] == '1'
PROJECT_ROOT = sys.argv[3]
SPEC = sys.argv[4]
DESIGN = sys.argv[5]
# Empty on an ordinary run. Non-empty only on the grant act, which is the one
# route that writes the excuse record -- see THE GRANT ACT below.
GRANT_KEY = sys.argv[6] if len(sys.argv) > 6 else ''
GRANT_GROUNDS = sys.argv[7] if len(sys.argv) > 7 else ''

findings = []
excused = []
cannot = []

# Which classes HOLD a plan and which only report. Stated once here so every
# enumeration in the output agrees with it: the two whose findings a plan cannot
# carry hold, and the four whose findings are a report travel in the author's
# hand-back and into the review instead. A caller refuses on the holding count,
# never on the total, which is why the verdict carries both. Isolation was the
# third holding class and reports now -- its sibling states why.
HOLDING = ('completeness', 'arithmetic')

# ---------------------------------------------------------------------------
# The excuse route.
# ---------------------------------------------------------------------------
# THE KEY IS CLASS, SPOT AND SUBJECT, and every part of that is chosen against
# one requirement: editing the passage a finding is about must not revoke the
# excuse, and the same fault returning at that spot must come back excused. So
# the statement's own text is NOT in the key. The spot NAMES AN ENTITY -- a
# document and the heading its statement sits under, or the file a tree-wide
# finding is in -- because a position in the key would be the very anti-pattern
# the class beside this one reports, and because a position moves when the
# passage is edited, which is the case the requirement rules out by name.
#
# WHERE THE SUBJECT IS THE PASSAGE ITSELF the bound is reached and is stated
# rather than hidden: a repeated SPAN has no smaller subject than the span, so
# rewriting it does change the key and the excuse lapses. That is the honest
# answer rather than a gap -- once one of the two sites is rewritten the two
# sites no longer say the same thing, so the excuse is about a fault that is no
# longer there.
#
# THE RECORD IS PER-PLAN AND ITS ABSENCE IS THE EMPTY STATE, which is a third
# polarity beside the two records above it. Most plans excuse nothing, so an
# absent record means nothing is excused and the run proceeds. What is NOT
# tolerated is a record that exists while being invisible to every other clone,
# or one this check cannot read: the first makes this run quieter than everyone
# else's and the second leaves it guessing what is excused, so both take the
# cannot-run branch.
#
# THE GRANT ACT IS THE ONLY ROUTE THAT WRITES IT. An ordinary run reports an
# excused finding as excused and writes nothing at all. The act takes a key off
# a finding line, runs every class with excusing suspended so the finding is
# still there to be seen, PRINTS IT IN FULL, and only then appends the row --
# which is what "shows the finding it is about to excuse before excusing it"
# asks for. Removing a row is the same kind of act done by hand, which is why
# the record is a table a reader can find a row in rather than a digest.
EXCUSE_FIELD = '|'
SPEC_SUFFIX = '.spec.md'
EXCUSE_SUFFIX = '.excuses.md'

EXCUSES = {}
EXCUSE_PATH = None
SUSPEND_EXCUSES = bool(GRANT_KEY)

EXCUSE_HEADER = """# Excused convergence findings: %s

Each row waives ONE finding of `check-plan-convergence.sh` for this plan and no other. Granted by
`check-plan-convergence.sh --excuse '<class>%s<spot>%s<subject>' --grounds '<why>'`, which prints the
finding before writing the row. Removed by deleting its row, which is an act of the same kind. The
format is `${CLAUDE_PLUGIN_ROOT}/docs/templates/progress-format.md` § The record of excused findings
(committed).

| Class | Spot | Subject | Grounds |
|---|---|---|---|
"""


def key_of(cls, spot, subject):
    # A field separator inside a part would split the key where it is parsed, so
    # it collapses to a space. The collision that admits is between two subjects
    # differing only in that character.
    return EXCUSE_FIELD.join(
        norm(part).replace(EXCUSE_FIELD, ' ')[:80] for part in (cls, spot, subject))


def finding(cls, spot, subject, text):
    key = key_of(cls, spot, subject)
    line = 'finding %s [excuse: %s]: %s' % (cls, key, text)
    if not SUSPEND_EXCUSES and key in EXCUSES:
        excused.append((cls, 'excused %s [%s]: %s -- on the grounds: %s'
                        % (cls, key, text, EXCUSES[key])))
        return
    findings.append((cls, line))


def blocked(text):
    cannot.append('cannot run: %s' % text)


def read_rel(rel):
    return read_path(os.path.join(PROJECT_ROOT, rel))


def read_path(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def norm(text):
    return re.sub(r'\s+', ' ', text).strip()


def tracked(root):
    try:
        out = subprocess.run(['git', '-C', root, 'ls-files', '-z'],
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        blocked('the tracked file list could not be read from %s (%s)' % (root, exc))
        return []
    return [p for p in out.decode('utf-8', 'replace').split('\0') if p]


TRACKED_PATHS = tracked(PROJECT_ROOT)
if not METHOD_INDEXED:
    METHOD_TRACKED = None
elif METHOD_ROOT == PROJECT_ROOT:
    METHOD_TRACKED = set(TRACKED_PATHS)
else:
    METHOD_TRACKED = set(tracked(METHOD_ROOT))


def read_method(rel, unreadable):
    """An untracked method input is read here and absent from every other clone,
    which makes the local run green and every other one a cannot-run -- the same
    shape as a gate whose input set narrows without saying so. Where the method
    root has no index of its own there is nothing to consult, and presence is the
    whole requirement."""
    path = os.path.join(METHOD_ROOT, rel)
    if METHOD_TRACKED is not None and os.path.exists(path) and rel not in METHOD_TRACKED:
        blocked('%s is a method input this run reads and is not in the index, so this run reads a file no other clone has -- stage it'
                % rel)
        return None
    body = read_path(path)
    if body is None:
        blocked('%s could not be read, %s' % (rel, unreadable))
    return body


# ---------------------------------------------------------------------------
# The derivation: section names read from the record rather than carried.
# ---------------------------------------------------------------------------
RECORD_DOC = 'docs/plan-invariants.md'
RECORD_HEADING = '## The required elements of a spec and of a design'

RECORDED = {'spec': [], 'design': []}
_record_body = read_method(RECORD_DOC, 'so no section name could be derived and nothing located')
if _record_body is not None:
    _parts = _record_body.split(RECORD_HEADING, 1)
    if len(_parts) < 2:
        blocked('%s carries no required-element record under the heading this check reads, so the derivation has no source'
                % RECORD_DOC)
    else:
        _slice = _parts[1].split('\n## ', 1)[0]
        for _row in re.finditer(r'(?m)^\|\s*(spec|design)\s*\|\s*`([^`]+)`\s*\|', _slice):
            _tok = _row.group(2).strip()
            if _tok not in RECORDED[_row.group(1)]:
                RECORDED[_row.group(1)].append(_tok)
        # An empty extraction is a cannot-run and never an agreement: a pattern
        # that stopped matching reports nothing, and nothing is what a clean
        # derivation looks like from the outside.
        if not RECORDED['spec'] and not RECORDED['design']:
            blocked('the section-name derivation came back empty against %s, and an empty derivation must not read as a located document'
                    % RECORD_DOC)

HEADING_LINE = re.compile(r'^(#{1,6})\s+(\S.*?)\s*$')


def region(body, token):
    """The slice of `body` under the heading whose whole text is `token`.

    Empty when the document carries no such heading, which is not a finding:
    see the file header. The end is the next heading at the same depth or
    shallower, so a subsection stays inside the region it belongs to.
    """
    want = HEADING_LINE.match(token)
    if want is None:
        return ''
    depth, text = len(want.group(1)), want.group(2)
    keep, taking = [], False
    for line in body.split('\n'):
        got = HEADING_LINE.match(line)
        if got is not None:
            if not taking and got.group(2) == text and len(got.group(1)) == depth:
                taking = True
                continue
            if taking and len(got.group(1)) <= depth:
                break
        if taking:
            keep.append(line)
    return '\n'.join(keep)


# ---------------------------------------------------------------------------
# Statements.
#
# A fenced block is DROPPED, because a template or a command is not something
# this check rules on. And a semicolon does not cut a unit, because the
# provenance obligation is written as "in the same sentence" and a clause after
# a semicolon is still that sentence -- cutting there would report a figure
# whose own sentence named its kind.
# ---------------------------------------------------------------------------
# The heading each statement sits under, which is the entity half of an excuse
# key. The segmenter is the only pass that knows it, so it records it here as it
# goes rather than a second walk recovering it.
SECTION_OF = {}

FENCE = re.compile(r'^\s*(?:```|~~~)')
QUOTE_MARK = re.compile(r'^\s*(?:>\s?)+')
LIST_HEAD = re.compile(r'^\s*(?:[-*+]|\d+[.)])\s+')
UNIT_TAIL = '*_`)]"\''


def split_sentences(text):
    units, start, i, tick = [], 0, 0, False
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == '`':
            tick = not tick
            i += 1
            continue
        if not tick and ch in '.!?' and i > start:
            j = i + 1
            # A terminator inside closing markup still ends its sentence:
            # `artefact.**` is this corpus's commonest sentence end.
            while j < n and text[j] in UNIT_TAIL:
                j += 1
            if (j >= n or text[j] == ' ') and (text[i - 1].isalnum() or text[i - 1] in UNIT_TAIL):
                units.append(text[start:j])
                start = i = j
                continue
        i += 1
    units.append(text[start:])
    return [norm(u) for u in units if norm(u)]


def statements(body):
    out, buf = [], []
    section = ''

    def flush():
        if buf:
            for unit in split_sentences(' '.join(buf)):
                out.append(unit)
                SECTION_OF.setdefault(unit, section)
            del buf[:]

    in_fence = False
    at_block_start = True
    in_list = False
    for raw in body.split('\n'):
        plain = QUOTE_MARK.sub('', raw)
        if FENCE.match(plain):
            flush()
            in_fence = not in_fence
            at_block_start = True
            in_list = False
            continue
        if in_fence:
            continue
        text = norm(raw)
        if not text:
            flush()
            at_block_start = True
            continue
        stripped = plain.lstrip()
        head = HEADING_LINE.match(stripped)
        if head is not None or stripped.startswith('|'):
            flush()
            if head is not None:
                section = norm(head.group(2))
            out.append(text)
            SECTION_OF.setdefault(text, section)
            at_block_start = True
            in_list = False
            continue
        # A LIST ITEM IS RECOGNISED ONLY WHERE A LIST CAN BEGIN -- after a blank
        # line, a heading, a fence or a table row, or while one is already
        # running. A re-wrap can put a numeral and a period at the start of a
        # line mid-paragraph, and a rule trusting the line start would read half
        # a sentence as a new item.
        if LIST_HEAD.match(stripped) and (at_block_start or in_list):
            flush()
            # THE MARKER IS STRUCTURE AND LEAVES WITH THE LINE. An ordinal
            # marker kept in the text is read twice over: once as a figure the
            # item states, and once as a sentence end, because the period after
            # a digit satisfies every test a sentence terminator has to pass.
            buf.append(LIST_HEAD.sub('', text, count=1))
            in_list = True
            at_block_start = False
            continue
        if at_block_start:
            in_list = False
        buf.append(text)
        at_block_start = False
    flush()
    return out


def spot_of(doc, statement):
    section = SECTION_OF.get(norm(statement), '')
    return '%s %s' % (doc, ('\u00a7 ' + section) if section else '(no heading above it)')


# ---------------------------------------------------------------------------
# Numerals: which of them a document STATES as a figure.
# ---------------------------------------------------------------------------
NUMERAL = re.compile(
    r'(?<![\w#$.,:/–—-])(\d+(?:,\d{3})*(?:\.\d+)?)(?![\w])(?!\.{1,2}\d)(?!-\d)')
TICK_SPAN = re.compile(r'`[^`]*`')
IDENTITY_CELL = re.compile(r'^[\s\d,;.&/–—-]*$')
PREV_WORD = re.compile(r'([A-Za-z][A-Za-z-]*)[^A-Za-z]*$')
ENUMERATION_GAP = re.compile(r'^[\s,]*(?:and|or|&|to|through|[–—-])?[\s,]*$')
# A TABLE CELL AND A SEMICOLON CLAUSE ONLY. An em dash in this house style opens
# a parenthetical rather than a new clause -- measured on the live pair, where
# splitting on it moved a figure out of the sentence that named the command
# producing it and reported a provenance the document plainly carried.
CLAUSE_SPLIT = re.compile(r'[|;]')

# A NUMERAL A SEQUENCE NOUN INTRODUCES NAMES A POSITION, NOT A QUANTITY. The set
# is this check's reading of the vocabulary these documents use for an ordinal
# reference, taken from the live pair rather than imagined -- `item`,
# `decision`, `subtask` and `row` are the four that actually occur there -- and
# widened to the siblings the same documents reach for. Widening it further is a
# decision, not a tidy-up: every entry added stops a class of figure being read
# as one.
SEQUENCE_NOUNS = frozenset((
    'item', 'items', 'decision', 'decisions', 'subtask', 'subtasks', 'row', 'rows',
    'step', 'steps', 'round', 'rounds', 'leg', 'legs', 'principle', 'principles',
    'criterion', 'criteria', 'class', 'classes', 'group', 'groups', 'note', 'notes',
    'point', 'points', 'arm', 'arms', 'shape', 'shapes', 'question', 'questions',
    'column', 'columns', 'entry', 'entries', 'phase', 'phases', 'verb', 'verbs',
    'pass', 'passes', 'mode', 'modes', 'window', 'windows', 'checklist', 'section',
    'sections', 'bullet', 'bullets', 'angle', 'angles', 'half', 'halves',
))

IDENTITIES = 0


def masked(statement):
    """The statement with every identity SPAN blanked to the same width.

    Two spans are an identity rather than a figure. A backtick span: the
    statement NAMES a token there -- a path, a flag, a key form, a verdict line
    quoted from a gate -- and naming one is not stating a figure. And, in a
    table row, a cell whose whole content is numerals and separators: a row's
    own ordinal and its dependency list are structure. Blanking to the same
    width keeps every offset usable for the preceding-word test.
    """
    text = TICK_SPAN.sub(lambda m: ' ' * len(m.group(0)), statement)
    if text.lstrip().startswith('|'):
        text = '|'.join(' ' * len(cell) if IDENTITY_CELL.match(cell) else cell
                        for cell in text.split('|'))
    return text


def figures(statement):
    """(value, offset) for each numeral the statement states as a figure.

    Beyond the two blanked spans above, two joins are an identity: a numeral
    welded to a word, a hash, a currency mark or an adjacent dash is an
    identifier, a date or a version, and the weld is what makes it one; and a
    numeral a sequence noun introduces names a position.
    """
    global IDENTITIES
    text = masked(statement)
    out = []
    prev_end, prev_was_ordinal = -1, False
    for m in NUMERAL.finditer(text):
        word = PREV_WORD.search(text[:m.start()])
        ordinal = word is not None and word.group(1).lower() in SEQUENCE_NOUNS
        # AN ENUMERATION INHERITS THE NOUN THAT INTRODUCED IT. "Items 1, 2 and
        # 5" names three positions, and only the first sits next to the noun --
        # a rule reading each numeral alone reported the third as a quantity.
        if not ordinal and prev_was_ordinal and prev_end >= 0 \
                and ENUMERATION_GAP.match(text[prev_end:m.start()]):
            ordinal = True
        prev_end, prev_was_ordinal = m.end(), ordinal
        if ordinal:
            IDENTITIES += 1
            continue
        out.append((m.group(1), m.start()))
    return out


def value_of(literal):
    return float(literal.replace(',', ''))


def clause_at(text, offset):
    """The run of `text` around `offset` that no clause separator crosses.

    The provenance obligation and the arithmetic relation are both properties of
    one clause, and a table row is a statement whose cells are unrelated: the
    file cell naming a path the task creates sits beside a task cell measuring
    files that already exist, and a rule reading the whole row would report the
    second because of the first.
    """
    start, end = 0, len(text)
    for sep in CLAUSE_SPLIT.finditer(text):
        if sep.end() <= offset:
            start = sep.end()
        elif sep.start() > offset:
            end = sep.start()
            break
    return text[start:end]



# THE THREE RELATION PATTERNS ARE HERE BECAUSE BOTH GROUPS READ THEM. The
# arithmetic class evaluates what they match; the provenance class reads the
# same three to decide that a derivation shown in place answers the provenance
# obligation without a word for it. One holding class and one reporting class,
# so a pattern held in either sibling would make the other sibling depend on
# it -- the same reason the built-path marking below is not in a sibling.
#
# TWO SPELLINGS, and the arithmetic class's own header states the bound they
# reach: an operator chain closed by an equals sign, and a list of addends
# closed by a stated total.
EQUATION = re.compile(r'(\d[\d,.]*(?:\s*[-+*/×÷]\s*\d[\d,.]*)+)\s*=\s*(\d[\d,.]*)')
TOTAL_WORD = re.compile(r'(\d[\d,.]*)\s+(?:together|in total|in all|all told|between them)\b')
TOTAL_PHRASE = re.compile(r'\b(?:summing to|for a total of|which totals?|adding up to)\s+(\d[\d,.]*)')

# ---------------------------------------------------------------------------
# The built-path marking. Shared, which is why it is here.
#
# THE DISPATCH IS ITS CALL SITE AND BOTH GROUPS CONSUME THE RESULT: the
# provenance class reads it to reach a figure only a measurement of the artefact
# this plan describes could have produced, and the completeness class reads it
# as half of its object set. One reporting class and one holding class, so
# holding it in either sibling would make that sibling a dependency of the
# other.
# ---------------------------------------------------------------------------
BUILT_PATH = re.compile(r'`([^`]+)`\s*\*\(new\)\*')


def built_paths(body, tokens):
    """The paths a decomposition row marks as created by the task.

    THE MARKING IS DECLARATIVE AND THAT IS THE WHOLE POINT. A test asking
    whether the path exists yet answers differently before and after the work,
    and the direction it moves loses a finding: a built path would stop being
    one the moment the file appeared. A marking in the cell is read from the
    cell and cannot move when the file comes into existence.
    """
    out = []
    for token in tokens:
        # LINE BY LINE, because a backtick span matched across a hard wrap is
        # not a path: run over the whole region, the pattern opened on one
        # path's closing backtick and closed three paragraphs later, and the
        # sixty-character "path" it produced was reported as an object with no
        # place, no reason and no cases.
        for line in region(body, token).split('\n'):
            for m in BUILT_PATH.finditer(norm(line)):
                path = m.group(1).strip()
                if path and path not in out:
                    out.append(path)
    return out


# ---------------------------------------------------------------------------
# The excuse record's persistence: where it lives, how a run reads it, and the
# one act that writes it. It belongs to the excuse route stated at the top of
# this file, and it is here rather than in a sibling for that reason -- a
# boundary drawn at the next banner rather than at the route would have put it
# inside the pairing class, which neither reads nor writes it.
# ---------------------------------------------------------------------------
SEPARATOR_CELL = re.compile(r'^[-: ]+$')


def excuse_path():
    """Derived from the spec's own path, so the record moves into the archive with
    the pair and a later run over the archived pair still finds it."""
    if not SPEC.endswith(SPEC_SUFFIX):
        blocked('the spec at %s does not end in %s, so the record beside it cannot be named and this run cannot know what is excused'
                % (SPEC, SPEC_SUFFIX))
        return None
    return SPEC[:-len(SPEC_SUFFIX)] + EXCUSE_SUFFIX


def read_excuses(paths):
    global EXCUSE_PATH
    EXCUSE_PATH = excuse_path()
    if EXCUSE_PATH is None or not os.path.exists(EXCUSE_PATH):
        return
    # BOTH SIDES THROUGH realpath, because the root arrives already resolved
    # while a path given on the command line does not: under a temporary
    # directory behind a symlink the two disagree, the relative path comes out
    # full of parent steps, and a staged record read as untracked.
    rel = os.path.relpath(os.path.realpath(EXCUSE_PATH), os.path.realpath(PROJECT_ROOT))
    if rel not in set(paths):
        blocked('%s exists and is not in the index, so this run is quieter than every other clone of this repository -- stage it'
                % EXCUSE_PATH)
        return
    body = read_path(EXCUSE_PATH)
    if body is None:
        blocked('%s could not be read, so this run cannot know which of its findings are excused'
                % EXCUSE_PATH)
        return
    for line in body.split('\n'):
        if not line.lstrip().startswith('|'):
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) < 4 or cells[0].lower() == 'class' or SEPARATOR_CELL.match(cells[0]):
            continue
        # A row this check cannot read leaves it guessing, and a guess in either
        # direction is wrong: ignoring the row raises a finding the author
        # believes is excused, and admitting it excuses something nobody stated.
        if not all(cells[:4]):
            blocked('%s carries a row with an empty cell -- class, spot, subject and grounds are all required, and a row short of one excuses nothing checkably: %s'
                    % (EXCUSE_PATH, norm(line)[:160]))
            continue
        EXCUSES[key_of(cells[0], cells[1], cells[2])] = cells[3]


def grant():
    """Show the finding, then excuse it. The only route that writes the record."""
    parts = GRANT_KEY.split(EXCUSE_FIELD)
    if len(parts) != 3 or not all(part.strip() for part in parts):
        print('check-plan-convergence: cannot run -- an excuse key is class%sspot%ssubject, copied off a finding line, and this one is not: %s'
              % (EXCUSE_FIELD, EXCUSE_FIELD, GRANT_KEY))
        sys.exit(2)
    if GRANT_KEY in EXCUSES:
        print('check-plan-convergence: ALREADY EXCUSED -- %s carries this key and nothing was written: %s'
              % (EXCUSE_PATH, GRANT_KEY))
        sys.exit(0)
    hits = [line for _cls, line in findings if ('[excuse: %s]' % GRANT_KEY) in line]
    if not hits:
        print('check-plan-convergence: cannot run -- no finding of this run carries that key, and an excuse for a finding nobody can see excuses nothing: %s'
              % GRANT_KEY)
        sys.exit(2)
    print('check-plan-convergence: the finding this act is about to excuse, in full:')
    for line in hits:
        print('  %s' % line)
    row = '| %s |\n' % ' | '.join(part.strip() for part in parts + [norm(GRANT_GROUNDS)])
    fresh = not os.path.exists(EXCUSE_PATH)
    try:
        with open(EXCUSE_PATH, 'a', encoding='utf-8') as fh:
            if fresh:
                fh.write(EXCUSE_HEADER % (os.path.basename(SPEC), EXCUSE_FIELD, EXCUSE_FIELD))
            fh.write(row)
    except OSError as exc:
        print('check-plan-convergence: cannot run -- %s could not be written, so nothing was excused (%s)'
              % (EXCUSE_PATH, exc))
        sys.exit(2)
    print('check-plan-convergence: EXCUSED -- the row above is now recorded at %s' % EXCUSE_PATH)
    if fresh:
        print('  it is a COMMITTED record and this run did not stage it: git add %s' % EXCUSE_PATH)
    sys.exit(0)


# ---------------------------------------------------------------------------
# The two payload siblings.
# ---------------------------------------------------------------------------
# WHAT STAYS HERE AND WHY. The single payload reached 1,447 lines against this
# repository's hard thousand-line limit, so the six classes move out in the two
# groups this check already states as data -- the ones that HOLD a plan into
# one sibling, the ones that report into the other. What this file keeps is
# what BOTH groups read: the section-name derivation, the segmenter, the numeral
# readers, the three relation patterns, the built-path marking, the excuse route
# and the report. No helper of any class is called from any other class, which
# is what let the seam be drawn at the groups at all.
#
# THE GUARD WRAPS THE MODULE EXECUTION, NOT THE SPEC LOOKUP, copied with its
# reason from the verification payload's own loader beside this check: uncaught,
# `FileNotFoundError` for an absent sibling and `SyntaxError` for an unparseable
# one both come out of `exec_module` and exit 1, the FINDINGS code, so a check
# that could not load a third of itself would read as a check that found
# problems. The entry point catches absent and unreadable more cheaply, before
# python3 starts, and names which path it was; this catches unparseable, which
# no shell test can see. `except Exception` is deliberately broad: what matters
# is not which exception a sibling raises but that none of them reaches the
# interpreter's exit path. The filename is hyphenated and so not importable by
# `import`, hence a path off `__file__`.
# [load-sibling]
def load_sibling(name):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), name)
    try:
        spec = importlib.util.spec_from_file_location(name[:-3].replace('-', '_'), path)
        if spec is None or spec.loader is None:
            raise ImportError('no loader for %s' % path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    except Exception as exc:
        blocked('the payload sibling %s could not be loaded (%s: %s), so the classes it carries never ran -- which is a cannot-run and not a clean sweep'
                % (path, type(exc).__name__, exc))
        return None


# A FIGURE A SIBLING OWNS IS READ THROUGH HERE, never off the module handle,
# because the report prints on the cannot-run branch as well and a sibling that
# never loaded has no attribute to read. The absent value is the figure's own
# empty state rather than a zero for everything, which is why the delivery
# column passes its own.
def tally(module, name, absent=0):
    return getattr(module, name, absent) if module is not None else absent


# ---------------------------------------------------------------------------
# The run.
# ---------------------------------------------------------------------------
SPEC_BODY = read_path(SPEC)
DESIGN_BODY = read_path(DESIGN)
if SPEC_BODY is None:
    blocked('the spec at %s could not be read, so none of its statements was examined' % SPEC)
if DESIGN_BODY is None:
    blocked('the design at %s could not be read, so none of its statements was examined' % DESIGN)

DOCUMENTS = []
if SPEC_BODY is not None:
    DOCUMENTS.append(('spec', SPEC_BODY, RECORDED['spec']))
if DESIGN_BODY is not None:
    DOCUMENTS.append(('design', DESIGN_BODY, RECORDED['design']))

HOLDING_CLASSES = load_sibling('check-plan-convergence-holding.py')
REPORTING_CLASSES = load_sibling('check-plan-convergence-reporting.py')

REGIONS_PRESENT = 0
REGIONS_DERIVED = 0
STATEMENTS = 0
BUILT = []
CONTEXT = {}

# THE RECORD IS READ BEFORE ANY CLASS RUNS, and that order is the whole of what
# makes a waiver effective: `finding` consults EXCUSES as each finding is made,
# so a class running ahead of this would report what the record waives.
if not cannot:
    read_excuses(TRACKED_PATHS)

if not cannot:
    BUILT = built_paths(DESIGN_BODY, RECORDED['design'])
    all_units = {}
    for _kind, _body, _tokens in DOCUMENTS:
        REGIONS_DERIVED += len(_tokens)
        REGIONS_PRESENT += sum(1 for _t in _tokens if region(_body, _t).strip())
        _units = statements(_body)
        all_units[_kind] = _units
        STATEMENTS += len(_units)
    # ONE MAPPING FOR BOTH SIBLINGS, each unpacking the names it reads. A
    # positional signature this wide is one transposed argument away from a
    # silent defect, which is the class of mistake this whole check exists to
    # make loud -- the same reason the verification's own sibling takes one.
    CONTEXT = {
        'finding': finding, 'blocked': blocked, 'norm': norm, 'read_rel': read_rel,
        'read_method': read_method,
        'region': region, 'statements': statements, 'spot_of': spot_of,
        'masked': masked, 'figures': figures, 'value_of': value_of,
        'clause_at': clause_at, 'CLAUSE_SPLIT': CLAUSE_SPLIT,
        'EQUATION': EQUATION, 'TOTAL_WORD': TOTAL_WORD, 'TOTAL_PHRASE': TOTAL_PHRASE,
        'HEADING_LINE': HEADING_LINE, 'FENCE': FENCE, 'QUOTE_MARK': QUOTE_MARK,
        'TICK_SPAN': TICK_SPAN, 'PROJECT_ROOT': PROJECT_ROOT, 'built': BUILT,
        'documents': [(_k, _b, all_units[_k]) for _k, _b, _t in DOCUMENTS],
        'bodies': dict((_k, _b) for _k, _b, _t in DOCUMENTS),
        'tokens': dict((_k, _t) for _k, _b, _t in DOCUMENTS),
        'tracked_paths': TRACKED_PATHS,
    }

# EACH GROUP IS ASKED IN TURN AND THE BLOCK IS RE-TESTED BETWEEN THEM, because
# each group preflights an input it BORROWS rather than chooses -- the holding
# group the sections a folded spec keeps, the reporting group the baseline
# record and the minimum fragment length --
# and a preflight that could not read its source must stop the classes behind it
# instead of letting them report against a bound nobody established.
if not cannot and HOLDING_CLASSES is not None:
    HOLDING_CLASSES.run(CONTEXT)
if not cannot and REPORTING_CLASSES is not None:
    REPORTING_CLASSES.run(CONTEXT)

if GRANT_KEY and not cannot:
    grant()


def counts():
    held = sum(1 for cls, _line in findings if cls in HOLDING)
    # SPLIT BY WHETHER THE CLASS HOLDS, because one mixed figure cannot say
    # whether ten excuses waived ten holds or quieted ten reports: the first is
    # a plan proceeding over ten findings, the second is noise management.
    waived = sum(1 for cls, _line in excused if cls in HOLDING)
    minimum = tally(REPORTING_CLASSES, 'MINIMUM', None)
    own_refs = tally(HOLDING_CLASSES, 'SECTION_REFS')
    return ('documents=%d statements=%d regions=%d/%d numbers=%d identities=%d '
            'relations=%d not-evaluable=%d built=%d objects=%d criteria=%d '
            'delivery-column=%s section-refs=%d/%d fragment-min=%s repeats=%d '
            'swept=%d positions=%d accounted=%d undecodable=%d '
            'claims=%d marks=%d pairs=%d excused-holding=%d excused-reporting=%d '
            'holding=%d reporting=%d findings=%d'
            % (len(DOCUMENTS), STATEMENTS, REGIONS_PRESENT, REGIONS_DERIVED,
               tally(REPORTING_CLASSES, 'NUMBERS'), IDENTITIES,
               tally(HOLDING_CLASSES, 'RELATIONS'),
               tally(HOLDING_CLASSES, 'NOT_EVALUABLE'),
               len(BUILT),
               tally(HOLDING_CLASSES, 'OBJECTS'),
               tally(HOLDING_CLASSES, 'CRITERIA'),
               tally(HOLDING_CLASSES, 'DELIVERY_COLUMN', 'absent'),
               own_refs, own_refs + tally(HOLDING_CLASSES, 'QUALIFIED_REFS'),
               minimum if minimum is not None else '-',
               tally(REPORTING_CLASSES, 'REPEATS'),
               tally(REPORTING_CLASSES, 'SWEPT'),
               tally(REPORTING_CLASSES, 'POSITIONS'),
               tally(REPORTING_CLASSES, 'ACCOUNTED'),
               tally(REPORTING_CLASSES, 'UNDECODABLE'),
               tally(REPORTING_CLASSES, 'CLAIMS'),
               tally(REPORTING_CLASSES, 'MARKS'),
               tally(REPORTING_CLASSES, 'PAIRS'),
               waived, len(excused) - waived,
               held, len(findings) - held, len(findings)))


def criteria_reach():
    """A folded spec states no criterion by construction, and a zero beside it
    would read as a spec that forgot them."""
    if tally(HOLDING_CLASSES, 'FOLDED', False):
        return 'criteria not examined (the spec is folded: it carries only the sections the closing fold keeps)'
    return '%d criteria' % tally(HOLDING_CLASSES, 'CRITERIA')


def roster():
    """What each class examined, so a run that narrowed its own input set is
    distinguishable from a clean one. A zero where a non-zero is expected is a
    report about the run and never a clean verdict."""
    minimum = tally(REPORTING_CLASSES, 'MINIMUM', None)
    entered = tally(HOLDING_CLASSES, 'ENTERED', set()) | tally(REPORTING_CLASSES, 'ENTERED', set())
    skipped = tally(REPORTING_CLASSES, 'SKIPPED', {})
    for cls, examined in (('provenance', '%d numbers in %d documents'
                           % (tally(REPORTING_CLASSES, 'NUMBERS'), len(DOCUMENTS))),
                          ('arithmetic', '%d relations, %d of them not evaluable'
                           % (tally(HOLDING_CLASSES, 'RELATIONS'),
                              tally(HOLDING_CLASSES, 'NOT_EVALUABLE'))),
                          ('completeness', '%d objects, %s, %d own-document section references'
                           % (tally(HOLDING_CLASSES, 'OBJECTS'),
                              criteria_reach(),
                              tally(HOLDING_CLASSES, 'SECTION_REFS'))),
                          ('isolation', '%d repeated literals at or above %s characters'
                           % (tally(REPORTING_CLASSES, 'REPEATS'),
                              minimum if minimum is not None else '-')),
                          ('reference', '%d positions in %d swept files, %d of them accounted for'
                           % (tally(REPORTING_CLASSES, 'POSITIONS'),
                              tally(REPORTING_CLASSES, 'SWEPT'),
                              tally(REPORTING_CLASSES, 'ACCOUNTED'))),
                          ('pairing', '%d claimed ids against %d marks, %d pairs compared'
                           % (tally(REPORTING_CLASSES, 'CLAIMS'),
                              tally(REPORTING_CLASSES, 'MARKS'),
                              tally(REPORTING_CLASSES, 'PAIRS')))):
        mine = [line for got, line in findings if got == cls]
        waived = [line for got, line in excused if got == cls]
        if cls in skipped:
            state = 'not-examined (%s)' % skipped[cls]
        elif cls not in entered:
            state = 'not-examined (the run stopped before it)'
        else:
            state = 'examined-with-findings (%d)' % len(mine) if mine else 'examined-clean'
        if waived:
            state += ', %d excused' % len(waived)
        print('  class %-13s %s -- %s%s'
              % (cls, examined, state, '  HOLDS' if cls in HOLDING else '  reports'))


for _cls, line in findings:
    print(line)
# AN EXCUSED FINDING IS REPORTED RATHER THAN OMITTED, so a plan carrying ten of
# them cannot read as a clean one.
for _cls, line in excused:
    print(line)

if cannot:
    for line in cannot:
        print(line)
    print('check-plan-convergence: CANNOT RUN -- which is not a pass | %s' % counts())
    roster()
    sys.exit(2)

# THE WORD `clean` IS RESERVED FOR A RUN THAT WAIVED NOTHING. A plan whose every
# finding is excused exits 0, because the caller refuses on the unexcused
# holding count and there is none -- but it must not READ as clean, which is
# what the requirement behind the waived count asks for and what a fourth
# verdict word delivers where a count beside `clean` would not.
if findings and excused:
    STATE = '%d findings and %d excused' % (len(findings), len(excused))
elif findings:
    STATE = '%d findings' % len(findings)
elif excused:
    STATE = 'no unexcused finding, proceeding over %d excused' % len(excused)
else:
    STATE = 'clean'

print('check-plan-convergence: %s | %s' % (STATE, counts()))
roster()
sys.exit(1 if findings else 0)
