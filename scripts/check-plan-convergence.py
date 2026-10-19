# The logic half of check-plan-convergence.sh: the plan pair, the classes that
# read it and the report. Invoked as
# `python3 check-plan-convergence.py <root> <spec> <design>` by the wrapper
# beside it, which owns the flags, the preflights and the exit convention.
#
# Tests: scripts/test-check-plan-convergence.sh
#
# THIS FILE HOLDS NO SECTION NAME OF A SPEC OR A DESIGN AS A LITERAL, and that
# is a condition on which the check stays OUT of the edit-time refusal's page
# set rather than a stylistic preference. A page joins that set by defining or
# by enforcing a required element, so a script carrying a section token beside a
# presence word reads as enforcing one -- and a check that had to be authorised
# before every edit could not be grown. The names it needs are derived from the
# required-element record at run time, the way the propagation gate derives its
# path classes from the table beside them.
#
# WHAT IT NEVER REPORTS, for the same reason: that a derived section is ABSENT
# from the document under examination. A finding naming the section would assert
# the section's presence, which is the shape that makes a page protected, and a
# cannot-run would let this check hold a plan on a missing heading. The region
# is empty, the examined count prints as zero, and a reader weighs the zero.
import os
import re
import subprocess
import sys

ROOT = sys.argv[1]
SPEC = sys.argv[2]
DESIGN = sys.argv[3]

findings = []
cannot = []

# Which classes HOLD a plan and which only report. Stated once here so every
# enumeration in the output agrees with it: the three mechanical classes hold,
# the three whose findings are a report travel in the author's hand-back and
# into the review instead. A caller refuses on the holding count, never on the
# total, which is why the verdict carries both.
HOLDING = ('completeness', 'isolation', 'arithmetic')


def finding(cls, text):
    findings.append('finding %s: %s' % (cls, text))


def blocked(text):
    cannot.append('cannot run: %s' % text)


def read_rel(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding='utf-8') as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def read_path(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def norm(text):
    return re.sub(r'\s+', ' ', text).strip()


def tracked():
    try:
        out = subprocess.run(['git', '-C', ROOT, 'ls-files', '-z'],
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        blocked('the tracked file list could not be read from %s (%s)' % (ROOT, exc))
        return []
    return [p for p in out.decode('utf-8', 'replace').split('\0') if p]


# ---------------------------------------------------------------------------
# The derivation: section names read from the record rather than carried.
# ---------------------------------------------------------------------------
RECORD_DOC = 'docs/plan-invariants.md'
RECORD_HEADING = '## The required elements of a spec and of a design'

# An untracked record would be read here and absent from every other clone,
# which makes the local run green and every other one a cannot-run -- the same
# shape as a gate whose input set narrows without saying so.
if RECORD_DOC not in set(tracked()):
    blocked('%s is read as the source of the section names and is not in the index, so this run reads a file no other clone has -- stage it'
            % RECORD_DOC)

RECORDED = {'spec': [], 'design': []}
_record_body = read_rel(RECORD_DOC)
if _record_body is None:
    blocked('%s could not be read, so no section name could be derived and nothing located' % RECORD_DOC)
else:
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
# NOT THE STATEMENT INVENTORY'S SEGMENTER, and the two differences are the
# reason rather than an oversight. A fenced block is DROPPED here, because a
# template or a command is not something this check rules on, while the
# inventory must compare it as a unit. And a semicolon does not cut a unit here,
# because the provenance obligation is written as "in the same sentence" and a
# clause after a semicolon is still that sentence -- cutting there would report
# a figure whose own sentence named its kind. Two consumers with opposite
# dispositions do not share one function; a third would be worth extracting for.
# ---------------------------------------------------------------------------
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

    def flush():
        if buf:
            out.extend(split_sentences(' '.join(buf)))
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
        if HEADING_LINE.match(stripped) or stripped.startswith('|'):
            flush()
            out.append(text)
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


# ---------------------------------------------------------------------------
# The arithmetic class. Holds.
# ---------------------------------------------------------------------------
# ITS BOUND, stated because every other check in this tree states its own: the
# class reaches a relation whose operands AND result are all literal in one
# clause, in two spellings -- an operator chain closed by an equals sign, and a
# list of addends closed by a stated total. A relation written in prose with no
# second figure to check it against is not a relation this class can evaluate,
# and a rate stated once has no arithmetic to fail. A candidate it recognises
# and cannot evaluate is COUNTED beside the verdict rather than dropped, because
# a class that silently skipped what it could not read would report a clean
# arithmetic over a document full of it.
#
# THE NOT-EVALUABLE SET IS CLOSED to three shapes, and that is deliberate rather
# than thrifty: an earlier version counted any clause carrying an operator
# between two tokens, which matched every hyphenated word in both documents and
# reported 255 relations where there are none. A counter that over-counts is as
# useless as one that under-counts, and worse, because it reads as coverage.
EQUATION = re.compile(r'(\d[\d,.]*(?:\s*[-+*/×÷]\s*\d[\d,.]*)+)\s*=\s*(\d[\d,.]*)')
TOTAL_WORD = re.compile(r'(\d[\d,.]*)\s+(?:together|in total|in all|all told|between them)\b')
TOTAL_PHRASE = re.compile(r'\b(?:summing to|for a total of|which totals?|adding up to)\s+(\d[\d,.]*)')
SPACED_EQUALS = re.compile(r'\s=\s')
NOT_EVALUABLE = 0
RELATIONS = 0


def evaluate(chain):
    """A left-to-right walk with the two multiplicative operators taken first."""
    tokens = re.findall(r'\d[\d,.]*|[-+*/×÷]', chain)
    if not tokens or len(tokens) % 2 == 0:
        return None
    try:
        values = [value_of(tokens[0])]
        ops = []
        for i in range(1, len(tokens), 2):
            op, rhs = tokens[i], value_of(tokens[i + 1])
            if op in ('*', '×'):
                values[-1] *= rhs
            elif op in ('/', '÷'):
                if rhs == 0:
                    return None
                values[-1] /= rhs
            else:
                ops.append(op)
                values.append(rhs)
        total = values[0]
        for op, rhs in zip(ops, values[1:]):
            total = total + rhs if op == '+' else total - rhs
        return total
    except (ValueError, IndexError):
        return None


def same(a, b):
    return abs(a - b) < 1e-9


def show(value):
    return '%d' % round(value) if same(value, round(value)) else ('%g' % value)


def arithmetic(doc, body, units):
    global NOT_EVALUABLE, RELATIONS
    for statement in units:
        text = masked(statement)
        for clause in CLAUSE_SPLIT.split(text):
            equations = 0
            for m in EQUATION.finditer(clause):
                equations += 1
                RELATIONS += 1
                computed = evaluate(m.group(1))
                written = value_of(m.group(2))
                if computed is None:
                    NOT_EVALUABLE += 1
                elif not same(computed, written):
                    finding('arithmetic',
                            '%s states [%s] where the operands compute to %s: %s'
                            % (doc, norm(m.group(0)), show(computed), norm(statement)[:200]))
            hit = TOTAL_WORD.search(clause) or TOTAL_PHRASE.search(clause)
            if hit is not None:
                RELATIONS += 1
                total = value_of(hit.group(1))
                addends = [value_of(v) for v in re.findall(r'(?<![\w.,-])(\d[\d,.]*)', clause[:hit.start(1)])]
                if len(addends) < 2:
                    NOT_EVALUABLE += 1
                elif not same(sum(addends), total):
                    finding('arithmetic',
                            '%s states a total of %s over the addends %s, which sum to %s: %s'
                            % (doc, show(total), ' + '.join(show(a) for a in addends),
                               show(sum(addends)), norm(statement)[:200]))
            # A clause asserting an equality whose sides this class cannot read
            # as literals is the third not-evaluable shape, and the one that
            # answers "a relation with a non-literal operand is counted rather
            # than silently skipped".
            if equations == 0 and SPACED_EQUALS.search(clause):
                RELATIONS += 1
                NOT_EVALUABLE += 1


# ---------------------------------------------------------------------------
# The provenance class. Reports.
# ---------------------------------------------------------------------------
# THE THREE ADMISSIBLE KINDS ARE THE BASE PRINCIPLE'S, and this vocabulary
# recognises that a clause NAMES one. It never rules on whether the provenance
# it names is true: that is a reading, and a reading belongs to the judgement
# class. So a clean provenance verdict means no figure's clause is silent about
# its origin, never that every stated origin is honest.
#
# THE UNIT IS THE CLAUSE INSIDE THE SENTENCE, because the obligation is written
# as "in the same sentence ... and not in a later paragraph a reader has to
# find". The consequence is worth stating rather than discovering: a bullet
# naming its provenance in a lead sentence and its figures in the next is
# reported, and the remedy the principle names is to carry the provenance into
# the sentence stating the figure, never to delete the figure.
PROVENANCE = (
    ('threshold', re.compile(
        r'\bthreshold\b|\bhanded down\b|\bset by the\b|\bby instruction\b|\bthe cap\b'
        r'|\bthe ceiling\b|\bthe limit\b|\brefuses\b|\bforbids\b|\bmandat\w+', re.I)),
    ('derivation', re.compile(r'\bderiv\w+|\bestimat\w+|\barithmetic\b', re.I)),
    ('measurement', re.compile(
        r'\bmeasur\w+|\bread (?:from|off|out of)\b|\breported by\b|\bcounted\b|\bcount of\b'
        r'|\bobserved\b|\breproduc\w+|\bcensus\b|\breports\b|\bby `|\bwith `|\bfrom `', re.I)),
)
NUMBERS = 0


def provenance(doc, body, units, built):
    global NUMBERS
    for statement in units:
        text = masked(statement)
        for literal, offset in figures(statement):
            NUMBERS += 1
            # Both substitutions in `masked` preserve length, so one offset
            # addresses the blanked text and the authored text alike -- the
            # first for the provenance vocabulary, the second because a path is
            # only visible where its backticks survive.
            clause = clause_at(text, offset)
            raw_clause = clause_at(statement, offset)
            named = [kind for kind, pat in PROVENANCE if pat.search(clause)]
            # An equation or a stated total in the same clause IS the derivation
            # shown in place, so it answers the obligation without a word for it.
            if not named and (EQUATION.search(clause) or TOTAL_WORD.search(clause)
                              or TOTAL_PHRASE.search(clause)):
                named = ['derivation']
            if not named:
                finding('provenance',
                        '%s states [%s] in a clause naming neither which kind of number it is nor how it was obtained: %s'
                        % (doc, literal, norm(statement)[:200]))
            for path in built:
                if '`%s`' % path in raw_clause:
                    finding('provenance',
                            '%s states [%s] in the same clause as `%s`, a path this plan creates, so the figure could only come from measuring the artefact the document describes: %s'
                            % (doc, literal, path, norm(statement)[:200]))
                    break


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
# The completeness class. Holds.
#
# EVERY REGION THIS CLASS READS IS FOUND BY SHAPE, NEVER BY SECTION NAME, and
# that is the same constraint the file header states rather than a second one: a
# decomposition row is a table row whose first cell is a bare ordinal, a
# use-case bullet is a list item opening with a backticked item and a dash, and
# a criterion row is a table row whose first cell is a criterion token. The
# derived element list says WHICH slices of the document to look in; the shapes
# say what to look for inside them. So renaming a section moves what is
# examined, which the region census shows, and never what this class believes a
# document must contain.
#
# ITS BOUND. Place, cases and the criterion link are structural questions with
# structural answers. REASON is the one that is not, and the mechanical reading
# shipped here is narrower than the words it serves: the class asks whether the
# document mentions the object somewhere other than the row that schedules it
# and the bullet that lists its uses, never whether what it says there is a
# reason. A clause that names a case while saying nothing about what the object
# does in it is a judgement too, and belongs to the judgement class.
#
# THE MENTION IS SOUGHT DOCUMENT-WIDE RATHER THAN IN THE APPROACH ALONE, which
# is WIDER than the locus the plan behind this class names, and the reason is
# the condition in the file header: reading one named section means locating it,
# and this file may hold no section name as a literal. The only other route is
# the record's row ORDER, which would make the locus silently wrong the first
# time a row moved. So the reading loses the case of an object mentioned outside
# the approach and nowhere inside it, and the loss is disclosed here rather than
# left to be discovered.
# ---------------------------------------------------------------------------
DECOMP_ROW = re.compile(r'^\|\s*(\d+)\s*\|')
USE_CASE_BULLET = re.compile(r'^[-*+]\s+`([^`]+)`\s*[—–-]\s*(\S.*)$')
CRITERION_ROW = re.compile(r'^\|\s*(AC\d+)\s*\|')
CRITERION_TOKEN = re.compile(r'\bAC\d+\b')
SECTION_REF = re.compile(r'§\s+([^,.;:|)"—]+)')
# The header cell that names which requirements a row delivers. The design
# contract's own decomposition template is the authority on the spelling; this
# set is what a document is RECOGNISED by, and a document whose table carries
# none of them is read whole and said to have been, rather than read as
# delivering nothing.
DELIVERY_HEADERS = frozenset(('delivers', 'delivered', 'delivering', 'criteria', 'requirements'))

OBJECTS = 0
CRITERIA = 0
SECTION_REFS = 0
QUALIFIED_REFS = 0
DELIVERY_COLUMN = 'absent'


def rows_of(body, tokens, pattern):
    out = []
    for token in tokens:
        for line in region(body, token).split('\n'):
            text = norm(line)
            if pattern.match(text):
                out.append(text)
    return out


def use_case_bullets(body, tokens):
    """{leading item: the clauses after it} for every use-case-shaped bullet."""
    out = {}
    for token in tokens:
        buf = ''
        for line in region(body, token).split('\n'):
            text = norm(line)
            if USE_CASE_BULLET.match(text):
                if buf:
                    m = USE_CASE_BULLET.match(buf)
                    out.setdefault(m.group(1).strip(), m.group(2))
                buf = text
            elif buf and text and not text.startswith(('|', '#')) \
                    and not re.match(r'^[-*+]\s', text):
                buf = buf + ' ' + text
            else:
                if buf:
                    m = USE_CASE_BULLET.match(buf)
                    out.setdefault(m.group(1).strip(), m.group(2))
                buf = ''
        if buf:
            m = USE_CASE_BULLET.match(buf)
            out.setdefault(m.group(1).strip(), m.group(2))
    return out


def delivery_cells(body, tokens):
    """The criterion tokens each decomposition row claims to deliver."""
    global DELIVERY_COLUMN
    out = []
    for token in tokens:
        index = None
        for line in region(body, token).split('\n'):
            text = norm(line)
            if text.startswith('|') and not DECOMP_ROW.match(text):
                cells = [c.strip().lower() for c in text.strip('|').split('|')]
                for i, cell in enumerate(cells):
                    if cell in DELIVERY_HEADERS:
                        index = i
                        DELIVERY_COLUMN = cell
                        break
                continue
            if not DECOMP_ROW.match(text):
                continue
            cells = text.strip('|').split('|')
            cell = cells[index] if index is not None and index < len(cells) else text
            out.append(set(CRITERION_TOKEN.findall(cell)))
    return out


def resolves(want, known):
    """Does a section reference name a heading the document carries?

    COMPARED ON LEADING WORDS, because a reference has no closing delimiter: the
    sentence runs on past the heading's name, so neither string is a prefix of
    the other -- measured, a live reference to a numbered decision was reported
    as dangling because the five words of sentence after it were taken as part
    of the name. Two shared leading words resolve it, or one when that is the
    whole reference, which keeps a one-word heading reachable without letting a
    single shared article resolve anything.
    """
    wanted = want.lower().split()
    if not wanted:
        return True
    for heading in known:
        got = heading.lower().split()
        shared = 0
        for a, b in zip(wanted, got):
            if a != b:
                break
            shared += 1
        if shared >= 2 or (shared >= 1 and shared == len(wanted)):
            return True
    return False


def headings_of(body):
    out = []
    in_fence = False
    for line in body.split('\n'):
        plain = QUOTE_MARK.sub('', line)
        if FENCE.match(plain):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        got = HEADING_LINE.match(plain.lstrip())
        if got is not None:
            out.append(norm(got.group(2)))
    return out


def completeness(spec_body, design_body, spec_tokens, design_tokens, built, units):
    global OBJECTS, CRITERIA, SECTION_REFS, QUALIFIED_REFS
    rows = rows_of(design_body, design_tokens, DECOMP_ROW)
    bullets = use_case_bullets(design_body, design_tokens)
    objects = list(built)
    for item in bullets:
        if item not in objects:
            objects.append(item)
    OBJECTS = len(objects)
    row_text = ' '.join(rows)

    for obj in objects:
        marked = '`%s`' % obj
        lacks = []
        if marked not in row_text:
            lacks.append('no stated place -- no decomposition row names it')
        # The bullet is excluded by its CONTENT and not by its marker: the
        # segmentation strips a list marker before splitting, so a rule keyed on
        # the marker matched nothing and every object's own bullet counted as a
        # mention elsewhere -- the finding-losing direction, and silent.
        own_bullet = re.compile(r'^(?:[-*+]\s+)?%s\s*[—–-]' % re.escape(marked))
        elsewhere = [s for s in units
                     if marked in s and not DECOMP_ROW.match(s)
                     and not own_bullet.match(s)]
        if not elsewhere:
            lacks.append('no stated reason -- the document names it only in its row and its bullet')
        if obj not in bullets:
            lacks.append('no stated cases and no stated behaviour -- it has no use-case bullet')
        elif not bullets[obj].strip():
            lacks.append('no stated cases and no stated behaviour -- its bullet carries no clause')
        if lacks:
            finding('completeness', 'the object `%s` has %s' % (obj, '; '.join(lacks)))

    # The other direction: a bullet whose leading item is an object no row names
    # at all is caught by the place test above, which is why this class needs no
    # second pass over the bullets.
    stated = set()
    for crit in rows_of(spec_body, spec_tokens, CRITERION_ROW):
        stated.add(CRITERION_ROW.match(crit).group(1))
    CRITERIA = len(stated)
    delivered = set()
    for cell in delivery_cells(design_body, design_tokens):
        delivered |= cell
    for crit in sorted(stated - delivered, key=lambda c: int(c[2:])):
        finding('completeness',
                'the requirement %s is stated in the spec and no decomposition row delivers it' % crit)
    for crit in sorted(delivered - stated, key=lambda c: int(c[2:])):
        finding('completeness',
                'a decomposition row claims to deliver %s, which the spec does not state' % crit)

    for doc, body in (('spec', spec_body), ('design', design_body)):
        known = headings_of(body)
        for statement in statements(body):
            for m in SECTION_REF.finditer(statement):
                want = norm(m.group(1))
                if not want:
                    continue
                # A reference QUALIFIED by a file name points outside this
                # document, and resolving it means reading the tree -- which is
                # another class's input set. Counted, so the figure beside the
                # verdict says how much of the reference load this class did not
                # carry.
                before = statement[:m.start()].rstrip()
                if before.endswith('`') or before.endswith('.md') or before.endswith(')'):
                    QUALIFIED_REFS += 1
                    continue
                SECTION_REFS += 1
                if not resolves(want, known):
                    finding('completeness',
                            '%s refers to a section [%s] that no heading in it resolves to: %s'
                            % (doc, want, norm(statement)[:160]))


# ---------------------------------------------------------------------------
# The isolation class. Holds.
#
# THE MINIMUM FRAGMENT LENGTH IS BORROWED, NOT CHOSEN, and the borrowing is
# load-bearing twice over: a second stated length would be the duplicated fact
# this class exists to report, and a value invented here would be a number whose
# provenance the class beside it would refuse. An unreadable source is a
# cannot-run for that reason -- falling back to a default IS choosing one.
#
# ITS BOUND, AND THE UNIT IS WHERE THE WHOLE COST SITS. The reach is a repeated
# LITERAL: the same figure at two sites, or a whole statement or table cell of at
# least that length repeated at two sites. The unit is deliberately NOT a sliding
# window over the text: measured on one real plan pair, a 24-character window
# found 438 repeats, almost every one a fragment of shared English phrasing
# inside two different sentences -- and this class HOLDS, so an over-counting
# unit does not merely add noise, it stops every plan. A repeated statement or
# cell is the same FACT in two places, which is what the requirement asks for; a
# repeated phrase inside two different claims is not. A paraphrase is the
# judgement class's subject either way.
#
# It still over-fires where a document legitimately restates a whole short
# clause, and a single harmless finding is what the excuse route is for.
# ---------------------------------------------------------------------------
FRAGMENT_SOURCE = 'skills/task/scripts/check-fix-plan.sh'
FRAGMENT_NAME = 'ARMA_QUOTE_MIN'
REPEATS = 0


def fragment_minimum():
    body = read_rel(FRAGMENT_SOURCE)
    if body is None:
        blocked('%s could not be read, and the minimum fragment length is borrowed from it rather than chosen here'
                % FRAGMENT_SOURCE)
        return None
    m = re.search(r'(?m)^\s*%s=(\d+)' % FRAGMENT_NAME, body)
    if m is None:
        blocked('%s no longer states %s, so the minimum fragment length could not be borrowed and inventing one is the thing this class refuses'
                % (FRAGMENT_SOURCE, FRAGMENT_NAME))
        return None
    return int(m.group(1))


def isolation(doc, units, minimum):
    global REPEATS
    # A SITE IS A STATEMENT, not an occurrence. The same literal twice inside one
    # sentence cannot drift apart -- one edit moves both -- and counting
    # occurrences reported `20 + 20 = 41` as a duplicated fact against itself.
    sites = {}
    for statement in units:
        for literal in set(lit for lit, _off in figures(statement)):
            sites.setdefault(literal, []).append(statement)
    for literal, where in sorted(sites.items()):
        if len(where) < 2:
            continue
        REPEATS += 1
        finding('isolation',
                '%s states the figure [%s] at %d sites that can drift apart: %s'
                % (doc, literal, len(where),
                   ' || '.join(norm(s)[:90] for s in where[:3])))

    spans = {}
    for statement in units:
        text = norm(statement)
        pieces = [c.strip() for c in text.strip('|').split('|')] if text.startswith('|') else [text]
        for piece in pieces:
            if len(piece) >= minimum:
                spans.setdefault(piece, []).append(text)
    for span, where in sorted(spans.items()):
        if len(where) < 2:
            continue
        REPEATS += 1
        # BOTH SITES ARE NAMED, and a repeated table CELL is the case where the
        # span does not name them by itself: there the span is the cell and the
        # sites are two different rows. A repeated whole statement IS its own
        # site, so the surrounding text is printed only where it adds one.
        shown = [norm(s)[:90] for s in where[:3] if norm(s) != span]
        finding('isolation',
                '%s states the same span at %d sites that can drift apart -- [%s]%s'
                % (doc, len(where), span[:160],
                   (': ' + ' || '.join(shown)) if shown else ''))


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

REGIONS_PRESENT = 0
REGIONS_DERIVED = 0
STATEMENTS = 0
BUILT = []

MINIMUM = None
if not cannot:
    MINIMUM = fragment_minimum()

if not cannot:
    BUILT = built_paths(DESIGN_BODY, RECORDED['design'])
    all_units = {}
    for _kind, _body, _tokens in DOCUMENTS:
        REGIONS_DERIVED += len(_tokens)
        REGIONS_PRESENT += sum(1 for _t in _tokens if region(_body, _t).strip())
        _units = statements(_body)
        all_units[_kind] = _units
        STATEMENTS += len(_units)
        provenance(_kind, _body, _units, BUILT)
        arithmetic(_kind, _body, _units)
        isolation(_kind, _units, MINIMUM)
    if len(DOCUMENTS) == 2:
        completeness(SPEC_BODY, DESIGN_BODY, RECORDED['spec'], RECORDED['design'],
                     BUILT, all_units['design'])


def counts():
    held = sum(1 for f in findings if f.split(':', 1)[0].split()[1] in HOLDING)
    return ('documents=%d statements=%d regions=%d/%d numbers=%d identities=%d '
            'relations=%d not-evaluable=%d built=%d objects=%d criteria=%d '
            'delivery-column=%s section-refs=%d/%d fragment-min=%s repeats=%d '
            'holding=%d reporting=%d findings=%d'
            % (len(DOCUMENTS), STATEMENTS, REGIONS_PRESENT, REGIONS_DERIVED, NUMBERS,
               IDENTITIES, RELATIONS, NOT_EVALUABLE, len(BUILT), OBJECTS, CRITERIA,
               DELIVERY_COLUMN, SECTION_REFS, SECTION_REFS + QUALIFIED_REFS,
               MINIMUM if MINIMUM is not None else '-', REPEATS,
               held, len(findings) - held, len(findings)))


def roster():
    """What each class examined, so a run that narrowed its own input set is
    distinguishable from a clean one. A zero where a non-zero is expected is a
    report about the run and never a clean verdict."""
    for cls, examined in (('provenance', '%d numbers in %d documents' % (NUMBERS, len(DOCUMENTS))),
                          ('arithmetic', '%d relations, %d of them not evaluable'
                           % (RELATIONS, NOT_EVALUABLE)),
                          ('completeness', '%d objects, %d criteria, %d own-document section references'
                           % (OBJECTS, CRITERIA, SECTION_REFS)),
                          ('isolation', '%d repeated literals at or above %s characters'
                           % (REPEATS, MINIMUM if MINIMUM is not None else '-'))):
        mine = [f for f in findings if f.startswith('finding %s:' % cls)]
        state = 'examined-with-findings (%d)' % len(mine) if mine else 'examined-clean'
        print('  class %-13s %s -- %s%s'
              % (cls, examined, state, '  HOLDS' if cls in HOLDING else '  reports'))


for line in findings:
    print(line)

if cannot:
    for line in cannot:
        print(line)
    print('check-plan-convergence: CANNOT RUN -- which is not a pass | %s' % counts())
    roster()
    sys.exit(2)

print('check-plan-convergence: %s | %s'
      % ('clean' if not findings else '%d findings' % len(findings), counts()))
roster()
sys.exit(1 if findings else 0)
