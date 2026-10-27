# The two classes of check-plan-convergence.py that HOLD a plan: arithmetic and
# completeness. The payload beside this file owns the plan pair, the
# segmentation, the numeral readers, the excuse route and the report; this
# carries these two classes.
#
# THE ISOLATION CLASS USED TO BE THE THIRD, and it moved to the reporting
# sibling when it stopped holding. It flags a fact stated twice inside one
# document, which is not the event that does harm -- a one-sided edit to one of
# two linked sites is -- and its whole record held no drift catch, only waived
# noise. It is a report the reviewer weighs now.
#
# WHY IT IS A SECOND FILE AT ALL. The single payload reached 1,447 lines against
# this repository's hard thousand-line limit, whose two documented exemptions --
# auto-generated code and single large expressions -- fit no hand-written
# script; the per-file route the verification payload took is recorded as the
# Thousand-line exemption row in ai-docs/context.md. The seam is the one the
# check already states as data -- which classes HOLD a plan and which only
# report -- rather than a cut chosen to make two files of similar size: a caller
# refuses on the holding count, so the classes behind that count are the group
# with a reason to travel together.
#
# THE TWO GROUPS HAVE NO EDGE BETWEEN THEM, and that is what made the seam free.
# Every helper here is called only by a class here, except `folded_spec`, the
# one helper reached from outside a class here: the declared-link check asks it
# whether a spec is folded, so the rule the completeness class applies is stated
# once. The three patterns the
# arithmetic class and the provenance class BOTH read stayed in the core for
# that reason: either sibling holding them would make the other depend on it.
# Measured after the split rather than assumed.
#
# EVERY NAME THE CORE OWNS ARRIVES THROUGH `run` and is installed as a module
# global there, so the class bodies below are the text they were while all six
# classes shared one file. The alternative -- threading a context mapping
# through six signatures -- is the transposed-argument hazard the verification's
# own payload sibling states as its reason for taking a mapping at all.
#
# THIS FILE HOLDS NO SECTION NAME OF A SPEC OR A DESIGN AS A LITERAL, on the
# condition its core states: a script carrying a section token beside a presence
# word reads as enforcing a required element, and a check that had to be
# authorised before every edit could not be grown.
#
# Tests: scripts/test-check-plan-convergence.sh
import re

ENTERED = set()


def run(ctx):
    """The two holding classes, and the one input this group borrows.

    A preflight that could not read its source returns without running a class,
    because a class reporting against a bound nobody established is exactly the
    false green this check exists to catch. The core re-tests its own block
    between the two groups for that reason.
    """
    global RETAINED
    global finding, blocked, norm, read_method, region, statements, spot_of
    global masked, value_of
    global CLAUSE_SPLIT, EQUATION, TOTAL_WORD, TOTAL_PHRASE
    global HEADING_LINE, FENCE, QUOTE_MARK
    finding = ctx['finding']
    blocked = ctx['blocked']
    norm = ctx['norm']
    read_method = ctx['read_method']
    region = ctx['region']
    statements = ctx['statements']
    spot_of = ctx['spot_of']
    masked = ctx['masked']
    value_of = ctx['value_of']
    CLAUSE_SPLIT = ctx['CLAUSE_SPLIT']
    EQUATION = ctx['EQUATION']
    TOTAL_WORD = ctx['TOTAL_WORD']
    TOTAL_PHRASE = ctx['TOTAL_PHRASE']
    HEADING_LINE = ctx['HEADING_LINE']
    FENCE = ctx['FENCE']
    QUOTE_MARK = ctx['QUOTE_MARK']

    RETAINED = retained_sections()
    if RETAINED is None:
        return
    documents = ctx['documents']
    ENTERED.add('arithmetic')
    for doc, body, units in documents:
        arithmetic(doc, body, units)
    # The pair, never one document: the class compares a spec against a design,
    # and one of the two missing is a cannot-run the core has already reported.
    if len(documents) == 2:
        ENTERED.add('completeness')
        bodies = ctx['bodies']
        tokens = ctx['tokens']
        units_of = dict((doc, units) for doc, _b, units in documents)
        completeness(bodies['spec'], bodies['design'], tokens['spec'], tokens['design'],
                     ctx['built'], units_of['design'])


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
#
# THE TWO SPELLINGS' PATTERNS LIVE IN THE CORE rather than here. The provenance
# class reads the same three to decide that a derivation shown in place answers
# its obligation without a word for it, so a pattern held in either sibling
# would make the other sibling depend on it.
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
                    finding('arithmetic', spot_of(doc, statement), norm(m.group(0)),
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
                    finding('arithmetic', spot_of(doc, statement), norm(hit.group(0)),
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

# A FOLDED SPEC IS RECOGNISED, NOT REPORTED. The closing fold collapses the spec
# to its record of deliberate absence, so no criterion survives for a delivery
# cell to name, and every row of a correctly-folded plan read as claiming a
# requirement the spec does not state. The criterion leg has nothing to check in
# that state and says so in the roster instead. The sign is the spec's own
# headings at the depth the fold keeps: exactly the kept set, every kept one
# present and nothing else. A spec carrying any other heading at that depth, or
# missing a kept one, is read as a plan however few criteria it has. Requiring
# every kept section costs no correctly folded plan, because the fold's own gate
# reports a missing one; it is what keeps a draft that so far holds only one of
# them from reading as folded.
#
# THE KEPT SECTIONS ARE BORROWED, NOT NAMED, from the assignment the fold's own
# gate states them in -- the same list the plan-invariants check derives from
# there. Naming them here would put section tokens in this file, which the
# header rules out, and an unreadable source is a cannot-run, because falling
# back to a default IS choosing one.
RETAINED_SOURCE = 'scripts/check-redline.sh'
RETAINED_NAME = 'RETAINED'
RETAINED = None
FOLDED = False


# [retained-sections]
def retained_sections():
    body = read_method(RETAINED_SOURCE,
                       'and the sections a folded spec keeps are borrowed from it rather than named here')
    if body is None:
        return None
    m = re.search(r"(?ms)^%s='(.*?)'" % RETAINED_NAME, body)
    kept = [norm(t) for t in m.group(1).split('\n') if t.strip()] if m is not None else []
    if not kept:
        blocked('%s no longer states %s, so a folded spec could not be told from an incomplete one and guessing is the thing this class refuses'
                % (RETAINED_SOURCE, RETAINED_NAME))
        return None
    return kept


def heading_tokens(body):
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
            out.append('%s %s' % (got.group(1), norm(got.group(2))))
    return out


# [is-folded]
def is_folded(spec_body, kept):
    depths = set(t.split(' ', 1)[0] for t in kept)
    at_depth = [t for t in heading_tokens(spec_body) if t.split(' ', 1)[0] in depths]
    return set(at_depth) == set(kept)


# [folded-spec]
def folded_spec(ctx, spec_body):
    global norm, read_method, blocked, HEADING_LINE, FENCE, QUOTE_MARK
    norm = ctx['norm']
    read_method = ctx['read_method']
    blocked = ctx['blocked']
    HEADING_LINE = ctx['HEADING_LINE']
    FENCE = ctx['FENCE']
    QUOTE_MARK = ctx['QUOTE_MARK']
    kept = retained_sections()
    if kept is None:
        return None
    return is_folded(spec_body, kept)


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
    global OBJECTS, CRITERIA, SECTION_REFS, QUALIFIED_REFS, FOLDED
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
            finding('completeness', 'design', obj,
                    'the object `%s` has %s' % (obj, '; '.join(lacks)))

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
    FOLDED = is_folded(spec_body, RETAINED)
    if not FOLDED:
        for crit in sorted(stated - delivered, key=lambda c: int(c[2:])):
            finding('completeness', 'design', crit,
                    'the requirement %s is stated in the spec and no decomposition row delivers it' % crit)
        for crit in sorted(delivered - stated, key=lambda c: int(c[2:])):
            finding('completeness', 'design', crit,
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
                    finding('completeness', spot_of(doc, statement), want,
                            '%s refers to a section [%s] that no heading in it resolves to: %s'
                            % (doc, want, norm(statement)[:160]))
