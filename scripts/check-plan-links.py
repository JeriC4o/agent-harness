# THIS FILE HOLDS NO SECTION NAME OF A SPEC OR A DESIGN AS A LITERAL: a script
# carrying one beside a presence word reads as enforcing a required element.
# The sections a folded spec keeps are borrowed through the holding sibling.
import importlib.util
import os
import re
import subprocess
import sys

METHOD_ROOT, PROJECT_ROOT, SPEC, DESIGN = sys.argv[1:5]

SPEC_SUFFIX = '.spec.md'
LINKS_SUFFIX = '.links.md'
COLUMNS = ('Id', 'End A', 'Quote A', 'End B', 'Quote B', 'Grounds')
STATES = ('silent', 'moved', 're-confirm', 'ambiguous', 'skipped')

# Copied from check-plan-convergence.py under the names it gives them, so a
# search for either copy finds both.
HEADING_LINE = re.compile(r'^(#{1,6})\s+(\S.*?)\s*$')
FENCE = re.compile(r'^\s*(?:```|~~~)')
QUOTE_MARK = re.compile(r'^\s*(?:>\s?)+')

MARKER = re.compile(r'\[REDLINE [A-Za-z0-9][A-Za-z0-9._-]*\]')
UNESCAPED_PIPE = re.compile(r'(?<!\\)\|')
SEPARATOR_CELL = re.compile(r'^:?-+:?$')
END = re.compile(r'^(spec|design)\s+§\s+(\S.*)$')

cannot = []


def blocked(text):
    cannot.append('cannot run: %s' % text)


def norm(text):
    return re.sub(r'\s+', ' ', text).strip()


def normalise(text):
    return norm(MARKER.sub('', text.replace('\\|', '|')).replace('*', ''))


def read_path(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def read_method(rel, unreadable):
    body = read_path(os.path.join(METHOD_ROOT, rel))
    if body is None:
        blocked('%s could not be read, %s' % (rel, unreadable))
    return body


# The guard wraps the module execution: uncaught, an absent or unparseable
# sibling exits 1, which is this check's findings code.
def load_holding():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'check-plan-convergence-holding.py')
    try:
        spec = importlib.util.spec_from_file_location('check_plan_convergence_holding', path)
        if spec is None or spec.loader is None:
            raise ImportError('no loader for %s' % path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    except Exception as exc:
        blocked('the payload sibling %s could not be loaded (%s: %s), so whether the spec is folded is unknown'
                % (path, type(exc).__name__, exc))
        return None


def sections(body):
    out = [('', [])]
    in_fence = False
    for line in body.split('\n'):
        plain = QUOTE_MARK.sub('', line)
        if FENCE.match(plain):
            in_fence = not in_fence
        elif not in_fence:
            head = HEADING_LINE.match(plain.lstrip())
            if head is not None:
                out.append((norm(head.group(2)), []))
                continue
        out[-1][1].append(plain)
    return [(heading, normalise('\n'.join(lines))) for heading, lines in out]


def cells_of(line):
    text = line.strip()[1:]
    if text.endswith('|') and not text.endswith('\\|'):
        text = text[:-1]
    return [cell.strip() for cell in UNESCAPED_PIPE.split(text)]


def staged(path):
    rel = os.path.relpath(os.path.realpath(path), os.path.realpath(PROJECT_ROOT))
    try:
        out = subprocess.run(['git', '--literal-pathspecs', '-C', PROJECT_ROOT, 'ls-files', '-z', '--', rel],
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        blocked('the index of %s could not be read (%s)' % (PROJECT_ROOT, exc))
        return False
    return rel in out.decode('utf-8', 'replace').split('\0')


def parse_record(path, body):
    rows = []
    header = False
    for line in body.split('\n'):
        if not line.lstrip().startswith('|'):
            continue
        cells = cells_of(line)
        if not header:
            header = tuple(cells) == COLUMNS
            continue
        if all(SEPARATOR_CELL.match(cell) for cell in cells):
            continue
        name = 'row %s' % (cells[0] or norm(line)[:80])
        if len(cells) != len(COLUMNS):
            blocked('%s, %s: %d cells where a link has %d -- a literal pipe inside a quote is written \\|'
                    % (path, name, len(cells), len(COLUMNS)))
            continue
        if not all(cells):
            blocked('%s, %s: an empty cell, and every cell of a link is required' % (path, name))
            continue
        ends = []
        for end, quote in ((cells[1], cells[2]), (cells[3], cells[4])):
            m = END.match(end)
            if m is None:
                blocked('%s, %s: the end [%s] names neither the spec nor the design and a heading'
                        % (path, name, end))
                break
            if not normalise(quote):
                blocked('%s, %s: the quote [%s] normalises to nothing' % (path, name, quote))
                break
            ends.append((m.group(1), norm(m.group(2)), normalise(quote)))
        if len(ends) == 2:
            rows.append((cells[0], ends))
    if not header:
        blocked('%s carries no table header [| %s |], so no link could be read'
                % (path, ' | '.join(COLUMNS)))
    return rows


def found_under(where):
    if not where:
        return 'found nowhere'
    headings = ', '.join('§ %s' % (h or '(no heading above it)') for h in dict.fromkeys(where))
    if len(where) == 1:
        return 'found under %s' % headings
    return 'found %d times, under %s' % (len(where), headings)


bodies = {'spec': read_path(SPEC), 'design': read_path(DESIGN)}
for doc, path in (('spec', SPEC), ('design', DESIGN)):
    if bodies[doc] is None:
        blocked('the %s at %s could not be read' % (doc, path))

RECORD = None
RECORD_SHOWN = '-'
if not SPEC.endswith(SPEC_SUFFIX):
    blocked('the spec at %s does not end in %s, so the record beside it cannot be named'
            % (SPEC, SPEC_SUFFIX))
else:
    RECORD = SPEC[:-len(SPEC_SUFFIX)] + LINKS_SUFFIX
    RECORD_SHOWN = RECORD

FOLDED = None
if not cannot:
    holding = load_holding()
    if holding is not None:
        FOLDED = holding.folded_spec(
            {'norm': norm, 'read_method': read_method, 'blocked': blocked,
             'HEADING_LINE': HEADING_LINE, 'FENCE': FENCE, 'QUOTE_MARK': QUOTE_MARK},
            bodies['spec'])
        if FOLDED is None and not cannot:
            blocked('the sections a folded spec keeps could not be borrowed, so a folded spec could not be told from any other')

ROWS = []
if not cannot:
    if not os.path.exists(RECORD):
        RECORD_SHOWN = '%s (absent)' % RECORD
        if not FOLDED:
            blocked('%s does not exist, and an absent record declares nothing -- a pair with no link is declared by a record with no row'
                    % RECORD)
    elif staged(RECORD):
        body = read_path(RECORD)
        if body is None:
            blocked('%s could not be read' % RECORD)
        else:
            ROWS = parse_record(RECORD, body)
    elif not cannot:
        blocked('%s exists and is not in the index, so this run reads a record no other clone has -- stage it'
                % RECORD)

COUNTS = dict((state, 0) for state in STATES)
REPORT = []
if not cannot:
    split = dict((doc, sections(bodies[doc])) for doc in bodies)
    for link_id, ends in ROWS:
        if FOLDED and any(doc == 'spec' for doc, _h, _q in ends):
            COUNTS['skipped'] += 1
            REPORT.append('skipped %s -- it has a spec end and the spec is folded, so it was not examined'
                          % link_id)
            continue
        where = [[h for h, text in split[doc] for _ in range(text.count(quote))]
                 for doc, _h, quote in ends]
        if any(len(w) > 1 for w in where):
            state, why = 'ambiguous', 'a quote is found more than once, so the row cannot say which occurrence it means'
        elif all(len(w) == 1 for w in where):
            COUNTS['silent'] += 1
            continue
        elif not any(where):
            state, why = 're-confirm', 'both quotes are found nowhere'
        else:
            gone, kept = (0, 1) if not where[0] else (1, 0)
            state = 'moved'
            why = 'end %s (%s) changed; end %s (%s) was not re-confirmed' % (
                'AB'[gone], ends[gone][0], 'AB'[kept], ends[kept][0])
        COUNTS[state] += 1
        REPORT.append('%s %s -- %s' % (state, link_id, why))
        for label, (doc, heading, _q), w in zip('AB', ends, where):
            REPORT.append('  end %s: %s § %s, recorded there; %s' % (label, doc, heading, found_under(w)))

TALLY = 'record=%s links=%d %s' % (
    RECORD_SHOWN, len(ROWS), ' '.join('%s=%d' % (state, COUNTS[state]) for state in STATES))

if cannot:
    for line in cannot:
        print(line)
    print('check-plan-links: CANNOT RUN -- which is not a pass | %s' % TALLY)
    sys.exit(2)

for line in REPORT:
    print(line)
FINDINGS = COUNTS['moved'] + COUNTS['re-confirm'] + COUNTS['ambiguous']
if FINDINGS:
    print('check-plan-links: %d findings | %s' % (FINDINGS, TALLY))
    sys.exit(1)
if FOLDED:
    print('check-plan-links: skipped -- the spec is folded, which is not a pass | %s' % TALLY)
    sys.exit(2)
print('check-plan-links: clean | %s' % TALLY)
sys.exit(0)
