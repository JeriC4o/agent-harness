# The three classes of check-plan-convergence.py that HOLD a plan: arithmetic,
# completeness and isolation. The payload beside this file owns the plan pair,
# the segmentation, the numeral readers, the excuse route and the report; this
# carries these three classes and nothing else.
#
# WHY IT IS A SECOND FILE AT ALL. The single payload reached 1,447 lines against
# this repository's hard thousand-line limit, whose two documented exemptions --
# auto-generated code and single large expressions -- fit no hand-written
# script; the per-file route the verification payload took is recorded as the
# Thousand-line exemption row in ai-docs/context.md. The seam is the one the
# check already states as data -- which classes HOLD a plan and which only
# report -- rather than a cut chosen to make two files of similar size: a caller
# refuses on the holding count, so the three classes behind that count are the
# group with a reason to travel together.
#
# THE TWO GROUPS HAVE NO EDGE BETWEEN THEM, and that is what made the seam free.
# Every helper here is called only by a class here. The three patterns the
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

# The borrowed fragment length, exposed for the report beside this group's
# findings: a zero where a non-zero is expected is a report about the run.
MINIMUM = None
ENTERED = set()


def run(ctx):
    """The three holding classes, and the one input this group borrows.

    A preflight that could not read its source returns without running a class,
    because a class reporting against a bound nobody established is exactly the
    false green this check exists to catch. The core re-tests its own block
    between the two groups for that reason.
    """
    global MINIMUM
    global finding, blocked, norm, read_method, region, statements, spot_of
    global masked, figures, value_of
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
    figures = ctx['figures']
    value_of = ctx['value_of']
    CLAUSE_SPLIT = ctx['CLAUSE_SPLIT']
    EQUATION = ctx['EQUATION']
    TOTAL_WORD = ctx['TOTAL_WORD']
    TOTAL_PHRASE = ctx['TOTAL_PHRASE']
    HEADING_LINE = ctx['HEADING_LINE']
    FENCE = ctx['FENCE']
    QUOTE_MARK = ctx['QUOTE_MARK']

    MINIMUM = fragment_minimum()
    if MINIMUM is None:
        return
    documents = ctx['documents']
    ENTERED.update(('arithmetic', 'isolation'))
    for doc, body, units in documents:
        arithmetic(doc, body, units)
        isolation(doc, units, MINIMUM)
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
    body = read_method(FRAGMENT_SOURCE,
                       'and the minimum fragment length is borrowed from it rather than chosen here')
    if body is None:
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
        finding('isolation', doc, literal,
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
        finding('isolation', doc, span,
                '%s states the same span at %d sites that can drift apart -- [%s]%s'
                % (doc, len(where), span[:160],
                   (': ' + ' || '.join(shown)) if shown else ''))


