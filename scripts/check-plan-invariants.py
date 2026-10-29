# The logic half of check-plan-invariants.sh: the corpus, the three legs and
# the report. Invoked as `python3 check-plan-invariants.py <root>` by the
# wrapper beside it, which owns the flags, the preflights and the exit
# convention's documentation.
#
# There are two payload siblings: this one, and check-plan-invariants-refusal.py
# beside it, which holds leg 3 and which this file loads. The pinned
# expectations -- the principles and the one severity spelling -- are literals
# below: the data that remains does not earn a file of its own.
#
# Tests: scripts/test-check-plan-invariants.sh
import importlib.util
import os
import re
import subprocess
import sys

ROOT = sys.argv[1]

findings = []
cannot = []
RED_SURFACES = set()


# A finding NAMES the surface it belongs to rather than being matched back to
# one by its text. A finding quotes text, and text names other files: measured,
# a finding whose own text contained `AGENTS.md` put the profile surface in the
# red set under a roster built by searching finding text.
#
# PASSING IT IS A SEPARATE ACT FROM COMPUTING IT, and that is where this came
# apart once: a call site that computes a surface and interpolates it reads as
# correct at a glance, so the omission is invisible in the text of the finding
# it produces -- only the roster shows it.
def finding(leg, text, surf=None):
    findings.append('finding %s: %s' % (leg, text))
    if surf is not None:
        RED_SURFACES.add(surf)


def blocked(text):
    cannot.append('cannot run: %s' % text)


# THE GUARD WRAPS THE MODULE EXECUTION, NOT THE SPEC LOOKUP, and that is
# measured. Uncaught, `FileNotFoundError` for an absent sibling and
# `SyntaxError` for an unparseable one both come out of `exec_module` and exit
# 1, the FINDINGS code, so a check that could not load half of itself would read
# as a check that found problems. An earlier variant here guarded
# `spec_from_file_location` returning `None` or yielding a `None` loader, and on
# a three-case probe -- sibling absent, unparseable, good -- BOTH of those tests
# were false in all three. That hole is why the design preferred one file, and
# closing it is the condition on which this split is defensible.
#
# `except Exception` is deliberately broad: what matters is not which exception
# a sibling raises but that none of them reaches the interpreter's exit path.
# The entry point catches absent and unreadable more cheaply, before python3
# starts; this catches unparseable, which no shell test can see. The filename is
# hyphenated and so not importable by `import`, hence a path off `__file__`.
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
        blocked('the payload sibling %s could not be loaded (%s: %s), so the leg it carries never ran -- which is a cannot-run and not a clean leg'
                % (path, type(exc).__name__, exc))
        return None


# A DECODE FAILURE IS AN UNREADABLE FILE, not a crash. The corpus admits every
# tracked file under five surface roots, so one committed image is enough to
# reach this -- and an uncaught UnicodeDecodeError exits with the FINDINGS code,
# which is the one outcome a run that could not complete may not report.
def read(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding='utf-8') as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def norm(text):
    return re.sub(r'\s+', ' ', text).strip()


# ---------------------------------------------------------------------------
# The corpus. Five surfaces, named exactly as the design's surface table names
# them, so the selection is reproducible from that table rather than from a
# file list. Three surfaces are deliberately OUT and are reported as
# not-examined, which is a distinct state from examined-and-clean.
#
# EACH EXCLUSION CARRIES A MEMBERSHIP RULE AND NOT ONLY A NAME, so the roster's
# three lines partition the surfaceless tracked files instead of labelling three
# of them beside an unexamined remainder. Names alone is what let eight tracked
# files sit in neither a surface nor an exclusion with the report silent on all
# eight -- measured: a mandate appended to README.md gave a clean verdict with
# README.md appearing nowhere in the output. Hence `unaccounted` on the verdict
# line: a file outside both sets is a figure a reader can see.
#
# NONE OF THE THREE RULES IS A CATCH-ALL, deliberately. A final rule taking
# whatever was left would hold `unaccounted` at zero by construction, which is
# this approach's own false green wearing the shape of a measurement.
# ---------------------------------------------------------------------------
PROFILE_FILES = ('AGENTS.md', 'CLAUDE.md', 'ai-docs/context.md')
SURFACE_ORDER = ('profile', 'method', 'scaffolding', 'enforcement', 'verification')
# [excluded-surfaces]
EXCLUDED_SURFACES = (
    ('plan-documents', 'the artefacts under these rules, which quote principle text by construction',
     lambda p: p.startswith('ai-docs/plans/')),
    # The Log is the union of the index file and the directory of entries, so
    # both spellings belong to this one exclusion; `ai-docs/learnings.md` is a
    # file rather than a directory and no prefix reaches it.
    ('learning-record', 'an entry there is a proposal rather than a rule, and the composition class is routed away from escalation',
     lambda p: p == 'ai-docs/learnings.md' or p.startswith('ai-docs/learnings/')),
    # REPOSITORY MECHANICS. Three of these eight ARE read under an explicit
    # method instruction -- session start reads .gitignore, the permissions step
    # reads .claude/settings.json, and the profile points at README.md's release
    # procedure, which a delivery gate executes -- so the honest ground for
    # excluding them is not that nobody reads them. It is that none of them
    # states a rule a spec or a design is held to. A mandate planted in one is
    # outside this detection, which is what naming the exclusion says out loud.
    # The committed data under the fixtures root is NAMED file by file rather than reached by a prefix on that root: a prefix widens what the exclusion claims. The cost of that choice is that every further record under the root is owed its own name here, which is what the planted-fault control below is.
    ('repository-mechanics', 'they configure or declare the repository, or are committed measurement data, so none of them states a rule a spec or a design is held to -- read by an agent in three cases, but never as instruction material',
     lambda p: (p.startswith(('.claude-plugin/', '.claude/', 'ai-docs/fixtures/loop-corpus/'))
                or p in ('.gitignore', 'README.md', 'ai-docs/fixtures/positional-references.baseline', 'ai-docs/fixtures/plan-convergence-planted.md'))),
)


def surface_of(path):
    if path in PROFILE_FILES:
        return 'profile'
    if path.startswith('templates/'):
        return 'scaffolding'
    if path.startswith('hooks/'):
        return 'enforcement'
    if path.startswith('scripts/') or re.match(r'^skills/[^/]+/scripts/', path):
        return 'verification'
    if path.startswith(('docs/', 'agents/', 'skills/', 'rules/')):
        return 'method'
    return None


def tracked():
    try:
        out = subprocess.run(['git', '-C', ROOT, 'ls-files', '-z'],
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        blocked('the tracked file list could not be read from %s (%s)' % (ROOT, exc))
        return []
    return [p for p in out.decode('utf-8', 'replace').split('\0') if p]


TRACKED = tracked()
CORPUS = []
UNREADABLE = []
SURFACE_FILES = dict((s, []) for s in SURFACE_ORDER)
for _p in TRACKED:
    _s = surface_of(_p)
    if _s is None:
        continue
    _body = read(_p)
    if _body is None:
        # A file that cannot be read is a file no leg swept, and a run that
        # completed having examined fewer files than the corpus holds is this
        # approach's own false green. The roster still reports the surface as
        # not-examined, which is why that block prints on this path too.
        UNREADABLE.append((_s, _p))
        blocked('%s is in the corpus and could not be read, so it was never swept' % _p)
        continue
    SURFACE_FILES[_s].append(_p)
    CORPUS.append((_p, _body))

if not CORPUS:
    blocked('the detection corpus came back empty, and an empty corpus must not read as a clean sweep')

# Every tracked file with no surface is assigned to exactly one exclusion, and
# whatever an exclusion does not claim is UNACCOUNTED and counted on the verdict
# line.
EXCLUDED_FILES = dict((name, []) for name, _why, _rule in EXCLUDED_SURFACES)
UNACCOUNTED = []
for _p in TRACKED:
    if surface_of(_p) is not None:
        continue
    _claimed = [name for name, _why, rule in EXCLUDED_SURFACES if rule(_p)]
    if _claimed:
        for _name in _claimed:
            EXCLUDED_FILES[_name].append(_p)
    else:
        UNACCOUNTED.append(_p)

CORPUS_PATHS = set(p for p, _b in CORPUS)
# A file this check reads DIRECTLY is still only swept if the tracked corpus
# carries it. An untracked one is read for its data and never compared, so the
# sweep's green would be a statement about a narrower input set than the one
# reported -- the quietest false green there is. Both payload files are in this
# list because they are on the verification surface and therefore ARE corpus.
for _needed in ('docs/plan-invariants.md', 'hooks/lib/plan-invariants-guard.sh',
                'agents/spec-writer.md', 'agents/design.md', 'agents/design-review.md',
                'scripts/deliberate-absence.sh', 'hooks/hooks.json',
                'scripts/check-plan-invariants.py',
                'scripts/check-plan-invariants-refusal.py'):
    if _needed not in CORPUS_PATHS:
        blocked('%s is read for its data but the tracked corpus does not carry it, so its own text is never swept -- stage it before trusting this run'
                % _needed)

# ---------------------------------------------------------------------------
# Leg 1. The principles, pinned sentence by sentence.
#
# WHY A SECOND COPY. A document compared only against itself cannot detect its
# own rewording. PINNED is an EXPECTATION WITH PROVENANCE, not a second
# authority: docs/plan-invariants.md governs the wording, and this copy exists
# only so a divergence is loud. The consequence is stated rather than hidden --
# an edit that changes the document AND this copy together passes, which is the
# authorisation route, because a deliberate change to a principle is then two
# co-ordinated edits whose diff a human reads.
# ---------------------------------------------------------------------------
PRINCIPLES_DOC = 'docs/plan-invariants.md'

# [pinned-principles]
PINNED = [
    "**One writer per artefact.** The orchestrator writes neither a spec nor a design; each is written only by its owning subagent. *Because a party that both writes a document and reports on it can close a finding by editing the evidence.*",
    "**A spec is a behaviour contract, not an implementation plan.** A criterion may not spell a command, script, tool or test identifier. *Because a criterion naming its instrument asserts which instrument ran, not what the system does, and cannot survive a change of instrument.*",
    "**A design says NOTHING about tests**, and the furthest it goes is naming the cases each object it builds is used in. *Because every sentence a design could write about a test is a promise about something that does not exist when the document is authored, and each narrowed version of this rule regrew — first a per-criterion command, then an intent line, then a suite total.*",
    "**The design is frozen by a commit at the design-review GO verdict and corrected in place after it.** A divergence that does not break the agreed approach is corrected in the item it falsifies, after the code it describes exists and only as far as the shipped work needs; one that breaks the approach is a new design, a new review and a new freeze. *Because the change since the freeze is then computed from the repository rather than reported by the party that made it, so every edit to the agreed plan, an unintended one included, reaches the review that rules on it.*",
    "**A changed requirement goes to the spec; a changed artefact goes to the design; nothing is recorded in both places.** *Because two records of one fact is the drift the mechanism exists to reduce.*",
    "**Neither document carries a record of superseded material, and no verdict may require one.** *Because every later reader of the document pays for every such passage — the record of deliberate absence and the use cases on every whole-repository review, the rest whenever the document is opened — and none of it describes the system.*",
    "**A plan is archived as it stands, and nothing rewrites it on its task's behalf after the merge.** The spec keeps every section and the design keeps every section, its process sections included. *Because a pass after the merge lands as a change of its own with a review of its own, and until it lands the archive says one thing while the record of its correction says another.*",
    "**A required element of a spec or a design must be knowable at the time the document is authored, and so must the origin of every number either document states.** An element whose content is only determined later is forbidden. A stated number names, in the same sentence, which kind it is — a threshold the task handed down, an estimate derived in place with its derivation shown, or a measurement of something that already exists — and how it was obtained; a figure whose only honest origin would be a measurement of the artefact the document describes is forbidden with it, that measurement being one nobody can take while the document is still being written. *Because it guarantees two failures at once: invented content at authoring time, and a review loop at the end that cannot converge — the document is corrected against reality, reality moves on, and the correction reopens.*",
    "**A question left open must be one whose answer would change neither the chosen approach, nor the requirements, nor how the work breaks up.** A gap failing that test is closed before the plan is agreed; a gap passing it that later turns out to have changed any of the three re-enters the full design-and-review cycle rather than being patched in place. *Because the gap is paid for either way, and the cheaper-looking price — note it and carry on — is the one that falls due as a rewrite of an agreed plan at the moment the work is most committed to it.*",
    "**A spec broader than its design is not a contradiction, and only a genuine conflict changes the spec.** A genuine conflict is a design that does what the spec explicitly rules out, or drops a behaviour an acceptance criterion requires, with no other sentence of the same spec requiring it; a spec that is general or silent where the design is specific is breadth, and a departure another sentence of the spec requires is stated once, among the design's risks, and is not a spec finding either. *Because a spec narrowed to match its design states the design's detail a second time and costs an approval and a fresh planning round, and the archived spec then keeps that detail for good, so every later correction of the design leaves the spec to be amended with it.*",
]

PRINCIPLE_COUNT = 0
doc_body = read(PRINCIPLES_DOC)
if doc_body is None:
    blocked('%s is unreadable, so there is no authority on the wording to compare against' % PRINCIPLES_DOC)
else:
    section = doc_body.split('## The base principles', 1)
    if len(section) < 2:
        blocked('%s carries no "## The base principles" section, and an empty extraction must not read as agreement'
                % PRINCIPLES_DOC)
        doc_items = {}
    else:
        body = section[1].split('\n## ', 1)[0]
        doc_items = {}
        for m in re.finditer(r'(?m)^(\d+)\. (.*?)(?=^\d+\. |^\S|\Z)', body, re.S):
            doc_items[int(m.group(1))] = norm(m.group(2))
        if not doc_items:
            blocked('%s § The base principles yielded no numbered sentence' % PRINCIPLES_DOC)
    for idx, want in enumerate(PINNED, 1):
        lead = want.split('**')[1] if '**' in want else want[:40]
        got = doc_items.get(idx)
        if got is None:
            finding('leg1-absence',
                    'principle %d is ABSENT from %s -- a vanished principle protects nothing. Expected lead: "%s"'
                    % (idx, PRINCIPLES_DOC, lead), surface_of(PRINCIPLES_DOC))
            continue
        if '*Because' not in got:
            finding('leg1-reason',
                    'principle %d in %s carries no one-clause reason, so it is not counted as present: "%s"'
                    % (idx, PRINCIPLES_DOC, lead), surface_of(PRINCIPLES_DOC))
            continue
        PRINCIPLE_COUNT += 1
        if norm(got) != norm(want):
            finding('leg1-wording',
                    'principle %d ("%s") differs in WORDING from the pinned sentence -- it still says something, which is why this is not reported as an absence.\n    pinned: %s\n    found:  %s'
                    % (idx, lead, norm(want), norm(got)), surface_of(PRINCIPLES_DOC))

# ---------------------------------------------------------------------------
# Leg 2. The required-element set, derived and compared in both directions.
#
# ROUTE 1 IS PATH-ANCHORED TO THE TWO WRITER CONTRACTS, and that is a
# requirement rather than a convenience: the bare section line inside a fence is
# not a rare spelling here, and a corpus-wide derivation of it hands the
# comparison tens of tokens against a record of thirteen elements. The cost is
# stated: a third writer contract would carry elements this route cannot see.
#
# ROUTE 2 IS THE QUIETER ROUTE. A line in the review contract carrying both an
# element-shaped token and a severity verdict makes that element mandatory with
# no template changing anywhere. The corpus spells a severity verdict three
# disjoint ways, so the arm reads ANY spelling rather than an enumeration of
# the three: an enumeration has to be re-measured every time the corpus acquires
# a fourth way of saying it, and a missing spelling is silent.
#
# ROUTE 3 READS PINNED SCRIPT DATA, because element lists held as data are
# where a sweep of prose cannot see them. Its one target is the record of
# deliberate absence, a requirement list. There were three until the
# per-criterion verification line stopped being an element, and two until the
# closing fold's removal list went with the fold. The reason the count is
# recorded here rather than left implicit: a route that silently reads fewer
# targets than its files hold derives fewer elements and reports no arrival for
# the ones it stopped seeing.
# ---------------------------------------------------------------------------
SPEC_CONTRACT = 'agents/spec-writer.md'
DESIGN_CONTRACT = 'agents/design.md'
REVIEW_CONTRACT = 'agents/design-review.md'
ABSENCE_RECORD = 'scripts/deliberate-absence.sh'
# [severity]
SEVERITY = r'(?:is a `(?:major|minor|blocker)` finding|=\s*`(?:major|minor|blocker)`|is `(?:major|minor|blocker)`)'

DERIVED = set()


def fenced_sections(rel):
    body = read(rel)
    if body is None:
        blocked('%s is unreadable, so route 1 has no template to derive from' % rel)
        return []
    toks = []
    for block in re.findall(r'(?ms)^```markdown\n(.*?)^```', body):
        toks += re.findall(r'(?m)^(##\s+\S.*?)\s*$', block)
    if not toks:
        blocked('%s yielded no bare section line inside a markdown-tagged fence, which covers a template that MOVED rather than reading as agreement'
                % rel)
    return toks


for _t in fenced_sections(SPEC_CONTRACT):
    DERIVED.add(('spec', _t))
for _t in fenced_sections(DESIGN_CONTRACT):
    DERIVED.add(('design', _t))

# ONE BRANCH, and it used to be two. The second matched a per-criterion
# verification line (`AC<N> ... :`), which stopped being an element; a design
# says nothing about tests, so the review contract carries no such token and the
# branch could only ever manufacture a spurious ARRIVAL against the record.
# Removed rather than left harmless: a derivation arm with no possible subject
# is indistinguishable from one whose subject has not been written yet.
# [element-token]
ELEMENT_TOKEN = re.compile(r'^##\s+\S.*$')
_rev = read(REVIEW_CONTRACT)
if _rev is None:
    blocked('%s is unreadable, so route 2 cannot be read' % REVIEW_CONTRACT)
else:
    route2 = 0
    for line in _rev.split('\n'):
        if not re.search(SEVERITY, line):
            continue
        for tok in re.findall(r'`([^`]+)`', line):
            if ELEMENT_TOKEN.match(tok.strip()):
                DERIVED.add(('design', tok.strip()))
                route2 += 1
    if route2 == 0:
        blocked('%s yielded no line carrying both an element-shaped token and a severity verdict, and an empty extraction must not read as agreement'
                % REVIEW_CONTRACT)

# ROUTE 3 DERIVES SPEC ELEMENTS ONLY, and that is now the whole of it. It used
# to read a per-criterion verification line out of a check script as its one
# DESIGN element. That line is gone from the design contract and from that
# script: a design says nothing about tests, so there is no per-criterion
# verification to assert the presence of. A design element arriving by this
# route again would mean a mechanical check had started asserting one, which is
# the thing the route exists to notice -- so the absence is recorded here rather
# than left as a silent gap.
_abs = read(ABSENCE_RECORD)
if _abs is None:
    blocked('%s is unreadable, so route 3 cannot read the record of deliberate absence' % ABSENCE_RECORD)
else:
    m = re.search(r"(?ms)^RETAINED='(.*?)'", _abs)
    if not m or not m.group(1).strip():
        blocked("%s carries no readable RETAINED assignment, which is a cannot-run rather than an empty requirement set" % ABSENCE_RECORD)
    else:
        for t in [x.strip() for x in m.group(1).split('\n') if x.strip()]:
            DERIVED.add(('spec', t))

# The record on the principles document, read as a set and compared in BOTH
# directions. Widening the record alone names an element no page mandates;
# widening a template alone names an element the record does not carry. That is
# what keeps the record from being the route by which an element becomes
# required.
RECORDED_ELEMENTS = set()
if doc_body is not None:
    sec = doc_body.split('## The required elements of a spec and of a design', 1)
    if len(sec) < 2:
        blocked('%s carries no required-element record to compare the derivation against' % PRINCIPLES_DOC)
    else:
        for row in re.finditer(r'(?m)^\|\s*(spec|design)\s*\|\s*`([^`]+)`\s*\|', sec[1].split('\n## ', 1)[0]):
            RECORDED_ELEMENTS.add((row.group(1), row.group(2).strip()))
        if not RECORDED_ELEMENTS:
            blocked('%s § The required elements table yielded no row, and an empty record must not read as agreement'
                    % PRINCIPLES_DOC)

ELEMENTS = sorted(RECORDED_ELEMENTS | DERIVED)
ELEMENT_COUNT = len(RECORDED_ELEMENTS)
PLAN_TOKENS = set(t for _d, t in ELEMENTS)

for doc, tok in sorted(DERIVED - RECORDED_ELEMENTS):
    finding('leg2-arrival',
            'a page mandates the %s element `%s`, which the record in %s does not carry -- an element has ARRIVED'
            % (doc, tok, PRINCIPLES_DOC), surface_of(PRINCIPLES_DOC))
for doc, tok in sorted(RECORDED_ELEMENTS - DERIVED):
    finding('leg2-departure',
            'the record in %s carries the %s element `%s`, which no page mandates -- an element has DEPARTED, or the record was widened on its own'
            % (PRINCIPLES_DOC, doc, tok), surface_of(PRINCIPLES_DOC))

# ---------------------------------------------------------------------------
# Leg 3. Refusal agreement -- the live covered set of the edit-time refusal
# against the protected-page table, in both directions. It is a SIBLING rather
# than a span, for the reason its own header gives; of the spans that could have
# moved it was the only pure SINK, so the seam is one call and a context mapping
# with nothing read back.
# ---------------------------------------------------------------------------
REFUSAL = load_sibling('check-plan-invariants-refusal.py')
if REFUSAL is not None:
    REFUSAL.run({
        'read': read, 'blocked': blocked, 'finding': finding, 'norm': norm,
        'surface_of': surface_of, 'doc_body': doc_body,
        'PRINCIPLES_DOC': PRINCIPLES_DOC,
        'PLAN_TOKENS': PLAN_TOKENS, 'CORPUS': CORPUS,
    })

# ---------------------------------------------------------------------------
# Report. The verdict carries the five input counts beside the findings count,
# because a run that silently examined fewer than the full set is otherwise
# indistinguishable from a clean one.
#
# `unaccounted` IS THE FIFTH AND READS THE OTHER WAY from the four beside it:
# those should be large, this should be zero. A non-zero value names tracked
# files in no surface and in no named exclusion -- the state eight of them sat
# in, silently, until it was counted.
#
# THE SURFACE ROSTER PRINTS ON EVERY PATH, the cannot-run included: it is what
# tells a surface that was NOT examined apart from one examined and found clean,
# and a cannot-run is exactly the outcome where that distinction is live.
# ---------------------------------------------------------------------------
PAGES = sum(len(SURFACE_FILES[s]) for s in SURFACE_ORDER)


def roster():
    for s in SURFACE_ORDER:
        unread = [p for lay, p in UNREADABLE if lay == s]
        if unread:
            print('  surface %-12s not-examined (%d of its files could not be read: %s)'
                  % (s, len(unread), ', '.join(sorted(unread)[:3])))
        elif s in RED_SURFACES:
            print('  surface %-12s examined-with-findings (%d files)' % (s, len(SURFACE_FILES[s])))
        else:
            print('  surface %-12s examined-clean (%d files)' % (s, len(SURFACE_FILES[s])))
    for name, why, _rule in EXCLUDED_SURFACES:
        print('  surface %-12s not-examined (%d files, excluded by design -- %s)'
              % (name, len(EXCLUDED_FILES[name]), why))
    # The paths and not only the figure, because a count of files nothing in the
    # report mentions is a reader's dead end: the remedy is either a surface or
    # an exclusion, and both decisions need the names.
    if UNACCOUNTED:
        print('  UNACCOUNTED  %d tracked files are in no surface and in no named exclusion, so this report says nothing about them: %s'
              % (len(UNACCOUNTED), ', '.join(sorted(UNACCOUNTED))))


def counts():
    return ('principles=%d elements=%d surfaces=%d pages=%d unaccounted=%d findings=%d'
            % (PRINCIPLE_COUNT, ELEMENT_COUNT, len(SURFACE_ORDER), PAGES,
               len(UNACCOUNTED), len(findings)))


for line in findings:
    print(line)

if cannot:
    for line in cannot:
        print(line)
    print('check-plan-invariants: CANNOT RUN -- which is not a pass | %s' % counts())
    roster()
    sys.exit(2)

verdict = 'clean' if not findings else '%d findings' % len(findings)
print('check-plan-invariants: %s | %s' % (verdict, counts()))
roster()
sys.exit(1 if findings else 0)
