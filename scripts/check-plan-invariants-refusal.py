# Leg 4 of check-plan-invariants.py: refusal agreement. The payload beside this
# file owns the corpus, the other three legs and the report; this holds leg 4 and
# nothing else.
#
# THE COVERED SET IS READ FROM THE GUARD'S DATA **AND** FROM ITS REGISTRATION.
# The page list is data inside the guard, so the covered set comes from there --
# but an UNREGISTERED guard's list would otherwise read as coverage, which is
# what makes a removed registration a finding rather than a silence.
#
# WHY IT IS A SECOND FILE AT ALL. The payload crossed this repository's hard
# 1000-line limit and no documented exemption fits a hand-written script, so one
# leg moves out. This span was measured the cheapest of the three candidates: it
# is a pure SINK. Of the nine names it defines, not one is read anywhere else in
# the payload -- context in, findings appended, nothing exported -- where leg 3
# exports two names and leg 2 four over 381 lines.
#
# WHAT A BROKEN SIBLING COSTS, and where that is guarded. A sibling that exists
# but cannot be EXECUTED is the failure mode the design named when it chose one
# file: `FileNotFoundError` and `SyntaxError` come out of `exec_module` and exit
# 1, which is the FINDINGS code, so a check that could not load half of itself
# would read as a check that found problems. Guarding the spec lookup does not
# catch it -- measured across three cases, sibling absent, unparseable and good,
# a `None` spec and a `None` loader are both absent in all three. The guard
# therefore wraps the execution and lives in the payload's loader, beside the
# entry point's own existence and readability preflights.
#
# Tests: scripts/test-check-plan-invariants.sh
import re


def run(ctx):
    """One entry, taking the eleven names this leg reads from the payload as a
    mapping rather than as a parameter list. Ten of them come through `ctx` and
    `re` is imported above; a positional signature of that width is one
    transposed argument away from a silent defect, which is the class of mistake
    this whole check exists to make loud."""
    read = ctx['read']
    blocked = ctx['blocked']
    finding = ctx['finding']
    norm = ctx['norm']
    surface_of = ctx['surface_of']
    doc_body = ctx['doc_body']
    PRINCIPLES_DOC = ctx['PRINCIPLES_DOC']
    RECORD = ctx['RECORD']
    PLAN_TOKENS = ctx['PLAN_TOKENS']
    CORPUS = ctx['CORPUS']

    GUARD = 'hooks/lib/plan-invariants-guard.sh'
    REGISTRY = 'hooks/hooks.json'
    COVERED = set()
    _g = read(GUARD)
    if _g is None:
        blocked('%s is unreadable, so the covered set cannot be read' % GUARD)
    else:
        m = re.search(r"(?ms)^PROTECTED='(.*?)'", _g)
        if not m or not m.group(1).strip():
            blocked('%s carries no readable PROTECTED assignment, and a failed extraction is a cannot-run rather than an empty agreement'
                    % GUARD)
        else:
            COVERED = set(x.strip() for x in m.group(1).split('\n') if x.strip())
        # The guard's SECOND list, read separately and deliberately kept out of
        # COVERED: the record defines no required element, so the protected-page
        # comparison below would report it as a surplus interruption -- correctly.
        # Its own agreement is this one, in both directions, following the
        # derived-arms precedent: the path this check reads as the record must be
        # the path the guard guards. One side alone is satisfiable by a guard that
        # guards nothing, and the other by a guard that guards the wrong file.
        m = re.search(r"(?ms)^GUARDED_RECORD='(.*?)'", _g)
        if not m or not m.group(1).strip():
            blocked('%s carries no readable GUARDED_RECORD assignment, so whether the record is guarded at all cannot be read'
                    % GUARD)
        else:
            guarded_record = set(x.strip() for x in m.group(1).split('\n') if x.strip())
            for p in sorted(guarded_record - {RECORD}):
                finding('leg4-record-surplus',
                        'the refusal guards %s as the comparison record, which is not the path this check reads (%s) -- the guard is protecting a file nothing compares against'
                        % (p, RECORD), surface_of(GUARD))
            for p in sorted({RECORD} - guarded_record):
                finding('leg4-record-unguarded',
                        'this check reads %s as the comparison record and the refusal does not guard it -- an edit could level the record in the same pass as the change it would have reported'
                        % p, surface_of(GUARD))

    _reg = read(REGISTRY)
    if _reg is None:
        blocked('%s is unreadable, so the registration cannot be confirmed' % REGISTRY)
    else:
        for matcher in ('Edit|Write', 'Bash'):
            pat = r'"matcher":\s*"%s".*?(?=\{\s*"matcher"|\],\s*"PostToolUse"|\Z)' % re.escape(matcher)
            grp = re.search(pat, _reg, re.S)
            if grp is None or 'hooks/lib/plan-invariants-guard.sh' not in grp.group(0):
                finding('leg4-registration',
                        'the refusal is not registered on the %s matcher in %s, so its page list is not coverage at all'
                        % (matcher, REGISTRY), surface_of(REGISTRY))

    TABLE = set()
    if doc_body is not None:
        sec = doc_body.split('## The protected page set', 1)
        if len(sec) < 2:
            blocked('%s carries no protected-page table to compare the live guard against' % PRINCIPLES_DOC)
        else:
            for row in sec[1].split('\n## ', 1)[0].split('\n'):
                if not row.startswith('|'):
                    continue
                cells = [c.strip() for c in row.strip('|').split('|')]
                if len(cells) < 2 or not cells[1] or cells[1].startswith('---'):
                    continue
                for p in re.findall(r'`\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)`', cells[0]):
                    TABLE.add(p)
            if not TABLE:
                blocked('%s § The protected page set yielded no path, and an empty table must not read as agreement'
                        % PRINCIPLES_DOC)

    # The near-miss controls, read from the same page as the table so the two cannot
    # be edited apart. A page in the near-miss table that is ALSO covered is a
    # contradiction the set comparison above cannot see: covered and tabled agree,
    # while the page is simultaneously documented as deliberately out.
    NEAR_MISSES = set()
    if doc_body is not None:
        sec = doc_body.split('## The near misses', 1)
        if len(sec) < 2:
            blocked('%s carries no near-miss table, so the controls that keep the refusal from widening have nothing to read'
                    % PRINCIPLES_DOC)
        else:
            for row in sec[1].split('\n## ', 1)[0].split('\n'):
                if not row.startswith('|'):
                    continue
                cells = [c.strip() for c in row.strip('|').split('|')]
                if len(cells) < 2 or not cells[1] or cells[1].startswith('---'):
                    continue
                for q in re.findall(r'`\$\{CLAUDE_PLUGIN_ROOT\}/([^`]+)`', cells[0]):
                    NEAR_MISSES.add(q.rstrip('/'))
            if not NEAR_MISSES:
                blocked('%s § The near misses yielded no path, and an empty control set must not read as agreement'
                        % PRINCIPLES_DOC)

    for p in sorted(NEAR_MISSES & COVERED):
        finding('leg4-near-miss',
                '%s is documented as a deliberate near miss in %s and the refusal covers it anyway -- the covered-versus-table comparison cannot see this, because both of those agree'
                % (p, PRINCIPLES_DOC), surface_of(p))
    for p in sorted(NEAR_MISSES & TABLE):
        finding('leg4-near-miss',
                '%s is in BOTH the protected-page table and the near-miss table in %s, so the page set contradicts itself'
                % (p, PRINCIPLES_DOC), surface_of(p))

    for p in sorted(COVERED - TABLE):
        finding('leg4-surplus',
                'the refusal covers %s, which the protected-page table in %s does not name -- every surplus member is a recurring interruption'
                % (p, PRINCIPLES_DOC), surface_of(p))
    for p in sorted(TABLE - COVERED):
        finding('leg4-uncovered',
                'the protected-page table names %s, which the refusal does not cover -- an UNGUARDED ROUTE'
                % p, surface_of(p))

    # Every table member is asserted to actually carry an element-defining locus, so
    # a covered page that carries no such rule is reported as a surplus
    # interruption rather than sitting there costing a prompt per edit. A page
    # carrying such a locus and absent from the table is an unguarded route.
    # An element-defining locus is read from the page itself, in the three SHAPES
    # the derivation routes have, so a page acquiring such a rule joins the set
    # rather than becoming the unguarded route -- and a page that is in the table on
    # a capability it no longer exercises is reported as a surplus interruption.
    #
    # THE SHAPE TEST REQUIRES A PRESENCE, ABSENCE OR RETENTION WORD, and a severity
    # verdict on its own is deliberately NOT enough. That is the one distinction
    # that separates a rule REQUIRING an element from a rule about the COVERAGE of
    # an element already required: measured on the live tree, the post-merge
    # repository pass assigns a severity to a use case no test covers and says
    # nothing about any element being absent, while the design reviewer's contract
    # spells `missing` and `present?` beside its own severities. (That pass's
    # predicate was rewritten when a design stopped saying anything about tests;
    # the measurement survives the rewrite because what it turns on is unchanged
    # -- the pass scores COVERAGE of a section the template already mandates.) Dropping the
    # requirement reports the first page as an unguarded route, which it is not.
    # [presence-shape]
    PRESENCE_SHAPE = re.compile(
        r'(?:missing|absent|present\b|presence|must exist|exists?\b|retained|retains|byte-identical|surviv\w+|binding)',
        re.I)


    # [defines-element]
    def defines_element(path, body):
        for block in re.findall(r'(?ms)^```markdown\n(.*?)^```', body):
            for t in re.findall(r'(?m)^(##\s+\S.*?)\s*$', block):
                if norm(t) in PLAN_TOKENS:
                    return True
        for m in re.finditer(r"(?ms)^([A-Z_]+)='(.*?)'", body):
            entries = [x.strip().lstrip('^') for x in re.split(r'[\n|]', m.group(2)) if x.strip()]
            if any(e in PLAN_TOKENS for e in entries):
                return True
        for line in body.split('\n'):
            toks = [t.strip() for t in re.findall(r'`([^`]+)`', line)]
            if not any(t in PLAN_TOKENS for t in toks):
                continue
            if PRESENCE_SHAPE.search(line):
                return True
        return False


    # Two exclusions, each with its reason. The principles document RECORDS the
    # enumeration and mandates nothing -- the record is pinned to the templates in
    # both directions, so it cannot be the route by which an element becomes
    # required, which is why it stays out of the refusal. A suite reproduces both
    # documents' section names as FIXTURE text, and a fixture asserts nothing about
    # what a real document must contain.
    for path, body in CORPUS:
        if path in (PRINCIPLES_DOC, GUARD):
            continue
        if re.search(r'(^|/)test-[A-Za-z0-9._-]*\.sh$', path):
            continue
        has = defines_element(path, body)
        if has and path not in TABLE:
            finding('leg4-unguarded',
                    '%s carries an element-defining locus and the refusal does not cover it -- an unguarded route'
                    % path, surface_of(path))
        if not has and path in TABLE:
            finding('leg4-no-locus',
                    '%s is in the protected-page table but carries no element-defining locus any more, so it is a surplus interruption'
                    % path, surface_of(path))
