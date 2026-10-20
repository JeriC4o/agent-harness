# The three classes of check-plan-convergence.py whose findings are a REPORT
# rather than a hold: provenance, reference and pairing. The payload beside this
# file owns the plan pair, the segmentation, the numeral readers, the excuse
# route and the report; this carries these three classes and nothing else.
#
# WHY IT IS A THIRD FILE AT ALL. The single payload reached 1,447 lines against
# this repository's hard thousand-line limit, and no documented exemption fits a
# hand-written script. The seam is the one the check already states as data --
# which classes HOLD a plan and which only report -- rather than a cut chosen to
# make files of similar size: a caller refuses on the holding count, so the
# three classes OUTSIDE that count are the group with a reason to travel
# together.
#
# THE TWO GROUPS HAVE NO EDGE BETWEEN THEM, and that is what made the seam free.
# Every helper here is called only by a class here. The three relation patterns
# the provenance class reads are the one exception and they stayed in the core,
# because the arithmetic class reads them too and either sibling holding them
# would make the other depend on it. Measured after the split rather than
# assumed.
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
import os
import re


def run(ctx):
    """The three reporting classes, and the record one of them compares against.

    A preflight that could not read its comparand returns without running a
    class, because a sweep against nothing must not report what it found as
    arrivals it established. The core re-tests its own block between the two
    groups for that reason.
    """
    global finding, blocked, norm, read_rel, spot_of
    global masked, figures, clause_at
    global EQUATION, TOTAL_WORD, TOTAL_PHRASE, TICK_SPAN
    global HEADING_LINE, FENCE, QUOTE_MARK, ROOT
    finding = ctx['finding']
    blocked = ctx['blocked']
    norm = ctx['norm']
    read_rel = ctx['read_rel']
    spot_of = ctx['spot_of']
    masked = ctx['masked']
    figures = ctx['figures']
    clause_at = ctx['clause_at']
    EQUATION = ctx['EQUATION']
    TOTAL_WORD = ctx['TOTAL_WORD']
    TOTAL_PHRASE = ctx['TOTAL_PHRASE']
    TICK_SPAN = ctx['TICK_SPAN']
    HEADING_LINE = ctx['HEADING_LINE']
    FENCE = ctx['FENCE']
    QUOTE_MARK = ctx['QUOTE_MARK']
    ROOT = ctx['ROOT']

    paths = ctx['tracked_paths']
    record = recorded_positions(paths)
    if record is None:
        return
    for doc, body, units in ctx['documents']:
        provenance(doc, body, units, ctx['built'])
    reference(paths, record)
    pairing([(doc, units) for doc, _b, units in ctx['documents']], paths)


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
                finding('provenance', spot_of(doc, statement), literal,
                        '%s states [%s] in a clause naming neither which kind of number it is nor how it was obtained: %s'
                        % (doc, literal, norm(statement)[:200]))
            for path in built:
                if '`%s`' % path in raw_clause:
                    finding('provenance', spot_of(doc, statement), '%s in %s' % (literal, path),
                            '%s states [%s] in the same clause as `%s`, a path this plan creates, so the figure could only come from measuring the artefact the document describes: %s'
                            % (doc, literal, path, norm(statement)[:200]))
                    break


# ---------------------------------------------------------------------------
# The reference class. Reports.
# ---------------------------------------------------------------------------
# THREE SHAPES AND THE SET IS CLOSED. A token joining a file to a digit run with
# a colon, optionally a digit range; a prose reference naming a line or a line
# range; and a line-addressed slice of a file a command names. Nothing else, and
# the exclusions carry their reason: a position a command PRODUCES is not a
# reference to one, so `grep -n` is outside the class, and a count taken from
# one end of a stream addresses no line of the file's content, so a prefix or a
# suffix length is not a position either.
#
# THE HOUSE IDIOM IS CARVED OUT BY ITS TARGET RATHER THAN BY ITS SHAPE. A script
# printing its own header as help slices the file it is running from, where the
# slice is re-derived by every run and outlives nothing -- which is the carve-out
# the reference rule already states, met in its commonest form.
#
# THE ADMISSIBLE EXTENSIONS ARE DERIVED FROM THE TRACKED TREE RATHER THAN
# LISTED, and the first shape is ambiguous without that bound: a version string
# followed by a colon and a digit run has exactly the same shape, and so does a
# host with a port. A reference can only name a kind of file this repository
# holds, so the tree's own extension set is the honest bound -- and it says out
# loud that a reference to a kind of file nothing here carries is outside the
# sweep, where a list would have said nothing and drifted as well.
#
# THE BASELINE IS THE COMPARAND AND AN ARRIVAL IS WHAT GETS REPORTED. Sweeping
# the positions that predate the rule is outside this work by the requirements'
# own boundary, and a class reporting all of them on its first run would ship a
# gate that is red on arrival. One row per accounted position -- shape, path and
# the token itself -- so swapping one anchor for another is an arrival rather
# than a wash, which a per-file count could not have seen.
#
# AN EMPTY RECORD IS LEGITIMATE WHERE AN ABSENT ONE IS NOT, which is the
# OPPOSITE polarity from the statement inventory's record, and the comparison is
# the reason. Empty here means nothing is accounted for, so every position is an
# arrival and the failure direction is loud. Absent means the comparand could
# not be read at all, and a sweep against nothing must not report what it found
# as arrivals it established.
#
# THE RECORD IS SKIPPED BY THE SWEEP THAT READS IT. Every row carries the token
# it accounts for, so a record inside its own input set would justify each of
# its rows by holding it.
#
# WHAT LEVELS THE RECORD IS NOT HERE, and that is a gap rather than a choice.
# The design behind this class gives the record an explicit act that prints what
# it is about to take in, the way the statement inventory's acceptance does, and
# no row of the plan that builds this check delivers one. So the record moves by
# a hand edit today, and every arrival finding prints the row that would account
# for it, which is what keeps that edit from needing a second derivation.
BASELINE_RECORD = 'ai-docs/fixtures/positional-references.baseline'

PATH_LINE = re.compile(r'(?<![\w/])([A-Za-z0-9_][\w./-]*\.([A-Za-z0-9]{1,10})):(\d+(?:-\d+)?)(?![\w])')
PROSE_LINE = re.compile(r'(?<![\w-])lines?[ \t]+\d+(?:[ \t]*[-–—][ \t]*\d+)?', re.I)
SLICE_SED = re.compile(
    r'''sed[ \t]+(?:-[A-Za-z]+[ \t]*)*-n[ \t]*(?P<q>['"]?)'''
    r'''(?P<script>\d+(?:,(?:\d+|\$|/[^/]*/))?[pdq])(?P=q)[ \t]+(?P<target>[^\s|;)&]+)''')
SLICE_AWK = re.compile(
    r'''awk[ \t]+(?P<q>['"])(?P<script>[^'"]*(?:FNR|NR)[ \t]*'''
    r'''(?:==|>=|<=|>|<)[ \t]*\d+[^'"]*)(?P=q)[ \t]+(?P<target>[^\s|;)&]+)''')
# The running script in every spelling the house style uses for it.
RUNNING_SCRIPT = ('"$0"', "'$0'", '$0')

SWEPT = 0
POSITIONS = 0
ACCOUNTED = 0
UNDECODABLE = 0


def tree_extensions(paths):
    out = set()
    for path in paths:
        base = path.rsplit('/', 1)[-1]
        if '.' in base[1:]:
            out.add(base.rsplit('.', 1)[1].lower())
    return out


def positions_in(body, exts):
    """(shape, token) for every position the text claims, in the three shapes."""
    out = []
    for m in PATH_LINE.finditer(body):
        if m.group(2).lower() in exts:
            out.append(('path-line', m.group(0)))
    for m in PROSE_LINE.finditer(body):
        out.append(('prose-line', norm(m.group(0))))
    # LINE BY LINE for the command shape, because a quoted script matched across
    # a hard wrap is not a command: the target would be read from whatever word
    # opened the next line.
    for line in body.split('\n'):
        for pattern in (SLICE_SED, SLICE_AWK):
            for m in pattern.finditer(line):
                # Whatever closes the construct AROUND the command comes with
                # the target, which is the match's tail -- in prose a backtick
                # and the sentence's own full stop, and the carve-out keyed on
                # the bare spelling missed every quoted command on a page. A
                # quote character is NOT stripped here: it is how the running
                # script is spelled.
                if m.group('target').rstrip('`).,;:') not in RUNNING_SCRIPT:
                    # The target is the match's tail, so whatever closes the
                    # construct around it comes with it. Stripping that keeps the
                    # recorded token from moving when the quoting around an
                    # unchanged command does.
                    out.append(('command-slice', norm(m.group(0)).rstrip('"\'`)')))
    return out


def recorded_positions(paths):
    """The rows of the baseline record, or None when it could not be read.

    Untracked is a cannot-run for the reason the element record's own check
    gives: a record read here and absent from every other clone makes this run
    green and every other one a cannot-run.
    """
    if BASELINE_RECORD not in set(paths):
        blocked('%s is the comparand for every position this class reports and is not in the index, so this run compares against a file no other clone has -- stage it'
                % BASELINE_RECORD)
        return None
    body = read_rel(BASELINE_RECORD)
    if body is None:
        blocked('%s could not be read, and a sweep with no comparand must not report what it found as arrivals it established'
                % BASELINE_RECORD)
        return None
    rows = set()
    for line in body.split('\n'):
        if not line.strip() or line.startswith('#'):
            continue
        rows.add(line.rstrip('\n'))
    return rows


def reference(paths, record):
    global SWEPT, POSITIONS, ACCOUNTED, UNDECODABLE
    exts = tree_extensions(paths)
    for path in paths:
        if path == BASELINE_RECORD:
            continue
        try:
            with open(os.path.join(ROOT, path), encoding='utf-8') as fh:
                body = fh.read()
        except UnicodeDecodeError:
            # A file that is not text carries no reference anyone reads, so it is
            # counted rather than blocking the run. A file that cannot be OPENED
            # is the other case and takes the branch below.
            UNDECODABLE += 1
            continue
        except OSError as exc:
            blocked('%s is in the tracked tree and could not be opened, so the positions it carries were never swept (%s)'
                    % (path, exc))
            continue
        SWEPT += 1
        for shape, token in positions_in(body, exts):
            POSITIONS += 1
            row = '%s\t%s\t%s' % (shape, path, token)
            if row in record:
                ACCOUNTED += 1
                continue
            finding('reference', path, token,
                    '%s carries a position the baseline does not account for -- [%s]; a reader may trust it without re-deriving it, and the record row that would account for it is: %s'
                    % (path, token, row))


# ---------------------------------------------------------------------------
# The pairing class. Reports.
# ---------------------------------------------------------------------------
# THE SHAPE FILTER BINDS BOTH SIDES, which is what the reference rule asks of it
# and the first of the three hazards the shipped keyed pairing already paid for.
# One expression recognises a statement's claim and an entity's mark, so a
# document explaining the convention in angle brackets carries neither.
#
# TWO LOCI, DECIDED BY THE LANGUAGE AND NOT BY A FILE LIST. A mark on a source
# entity sits in a comment; a mark on a prose entity rides its heading or its
# numbered item, which are already declared identities. Every language in this
# tree spells a line comment the same way, and a language that does not is a
# widening this class would have to learn rather than one it silently covers.
#
# A BRACKETED TOKEN INSIDE A BACKTICK SPAN IS A TOKEN BEING NAMED, never a claim
# or a mark, and the same goes for one inside a fenced block. Measured: without
# the first rule a character class quoted in a regular expression read as a
# claim, and without the second a template placeholder in a fenced example read
# as a mark on five separate pages.
#
# THE MARK SIDE IS THE FILES THE PLAN NAMES, and that is the bound the reference
# rule itself states -- a mark sits inside one of the files the claiming
# statement names, because nothing else bounds where it may be. The sweep still
# reads the tree rather than the plan, which is why this class reports and does
# not hold: a mark can arrive in a named file from a commit the plan under
# review never touched. Measured on this tree, the alternative reading is what
# decided it: a sweep over every tracked file finds six bracketed tokens that no
# plan claims, every one of them an optional argument in a usage synopsis, and
# all six would be reported against every plan forever.
#
# WHERE A LANGUAGE ADMITS NO COMMENT the obligation narrows and says so: the
# claim resolves in one direction only, from the statement to the file it names,
# which must exist, and no reverse pairing is asserted for it.
ID_SHAPE = re.compile(r'(?<![\w\]])\[([a-z0-9][a-z0-9-]*)\](?![(\[:])')
COMMENTLESS = ('.json',)
PROSE_FILE = ('.md',)
COMMENT_LINE = re.compile(r'^[ \t]*#')
NUMBERED_ITEM = re.compile(r'^[ \t]*\d+[.)][ \t]')

CLAIMS = 0
MARKS = 0
PAIRS = 0


def ids_in(text):
    return [m.group(1) for m in ID_SHAPE.finditer(TICK_SPAN.sub(
        lambda m: ' ' * len(m.group(0)), text))]


def named_files(statement, known):
    out = []
    for m in TICK_SPAN.finditer(statement):
        token = m.group(0).strip('`').strip()
        if token in known and token not in out:
            out.append(token)
    return out


def marks_in(path, body):
    """The ids marked in `path`, each with the line that carries the mark.

    A path the plan has yet to create is not in the tree, so no mark can sit in
    one -- which is why a claim bounded only by such a path is reported below
    rather than resolved here.
    """
    out = []
    if path.endswith(COMMENTLESS):
        return out
    prose = path.endswith(PROSE_FILE)
    in_fence = False
    for line in body.split('\n'):
        plain = QUOTE_MARK.sub('', line)
        if FENCE.match(plain):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        locus = (HEADING_LINE.match(plain.lstrip()) or NUMBERED_ITEM.match(plain)) \
            if prose else COMMENT_LINE.match(plain)
        if not locus:
            continue
        for slug in ids_in(line):
            out.append((slug, norm(line)))
    return out


def pairing(units, paths):
    global CLAIMS, MARKS, PAIRS
    known = set(paths)
    named = []
    claims = []
    for doc, doc_units in units:
        for statement in doc_units:
            files = named_files(statement, known)
            for path in files:
                if path not in named:
                    named.append(path)
            for slug in ids_in(statement):
                claims.append((slug, doc, statement, files))
    CLAIMS = len(claims)

    marks = {}
    for path in named:
        body = read_rel(path)
        if body is None:
            continue
        for slug, line in marks_in(path, body):
            marks.setdefault(slug, []).append((path, line))
            MARKS += 1

    claimed_by = {}
    for slug, doc, statement, _files in claims:
        claimed_by.setdefault(slug, []).append((doc, statement))

    for slug, where in sorted(claimed_by.items()):
        if len(where) > 1:
            finding('pairing', 'the plan pair', slug,
                    'the id [%s] is claimed by %d statements, so it resolves to more than one of them: %s'
                    % (slug, len(where), ' || '.join(norm(s)[:80] for _d, s in where[:3])))
    for slug, sites in sorted(marks.items()):
        if len(sites) > 1:
            finding('pairing', sites[0][0], slug,
                    'the id [%s] is marked at %d sites, so it resolves to more than one entity: %s'
                    % (slug, len(sites), ' || '.join('%s -- %s' % (p, l[:60]) for p, l in sites[:3])))

    for slug, doc, statement, files in claims:
        if not files:
            finding('pairing', spot_of(doc, statement), slug,
                    '%s claims the id [%s] while naming no file in the tree, so nothing bounds where its mark may sit: %s'
                    % (doc, slug, norm(statement)[:160]))
            continue
        where = [p for p, _l in marks.get(slug, []) if p in files]
        if where:
            PAIRS += 1
            continue
        if all(p.endswith(COMMENTLESS) for p in files):
            # The one-direction narrowing: the named file exists, which is the
            # whole of what resolves here, and no reverse pairing is asserted.
            PAIRS += 1
            continue
        finding('pairing', spot_of(doc, statement), slug,
                '%s claims the id [%s] that no mark carries in any file it names (%s), so the reference resolves to nothing: %s'
                % (doc, slug, ', '.join(files[:4]), norm(statement)[:160]))

    for slug, sites in sorted(marks.items()):
        if slug in claimed_by:
            continue
        finding('pairing', sites[0][0], slug,
                'the id [%s] is marked in %s and no statement of this plan claims it: %s'
                % (slug, sites[0][0], sites[0][1][:120]))


