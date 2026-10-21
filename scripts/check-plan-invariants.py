# The logic half of check-plan-invariants.sh: the corpus, the four legs and the
# report. Invoked as `python3 check-plan-invariants.py <root> <mode> <record>`
# by the wrapper beside it, which owns the flags, the preflights, the record's
# path and the exit convention's documentation.
#
# There are two payload siblings: this one, and check-plan-invariants-refusal.py
# beside it, which holds leg 4 and which this file loads. The pinned
# expectations -- the principles and the one severity spelling -- are literals
# below, because the second leg no longer measures a sentence against a
# vocabulary and the data that remains does not earn a file of its own.
#
# Tests: scripts/test-check-plan-invariants.sh
import collections
import difflib
import importlib.util
import os
import re
import subprocess
import sys

ROOT = sys.argv[1]
MODE = sys.argv[2]
RECORD = sys.argv[3]

findings = []
cannot = []
report_lines = []
RED_SURFACES = set()


# A finding NAMES the surface it belongs to rather than being matched back to
# one by its text. The report quotes whole statements, and a statement names
# other files: measured, the departure report for one method page quoted text
# containing `AGENTS.md`, and a roster built by searching finding text reported
# the profile surface as carrying findings of its own.
#
# PASSING IT IS A SEPARATE ACT FROM COMPUTING IT, and the comparison leg is
# where that came apart: it had the surface, put it in the line, and called this
# with two arguments. A call site that computes a surface and interpolates it
# reads as correct at a glance, so the omission is invisible in the text of the
# finding it produces -- only the roster shows it.
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
# THE RECORD ITSELF FALLS THROUGH THIS RULE AND BELONGS TO NO SURFACE, which is
# structural rather than arranged: the profile surface is a three-name
# enumeration, so no other file under the project-data root can reach a surface.
# A record inside its own corpus could not be brought level without changing the
# thing it records.
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
    # The committed data beside the inventory is NAMED file by file rather than reached by a prefix on the fixtures root: the inventory itself is skipped above, before any rule runs, so a prefix would leave two mechanisms claiming one file. The cost of that choice is that every further record under the root is owed its own name here, which is what the planted-fault control below is.
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
        # A file that cannot be read is a file whose statements are not compared,
        # and a run that completed having compared fewer statements than the
        # corpus holds is this approach's own false green. The roster still
        # reports the surface as not-examined, which is why that block prints on
        # this path too.
        UNREADABLE.append((_s, _p))
        blocked('%s is in the corpus and could not be read, so its statements were never compared'
                % _p)
        continue
    SURFACE_FILES[_s].append(_p)
    CORPUS.append((_p, _body))

if not CORPUS:
    blocked('the detection corpus came back empty, and an empty corpus must not read as a clean sweep')

# Every tracked file with no surface is assigned to exactly one exclusion, and
# whatever an exclusion does not claim is UNACCOUNTED and counted on the verdict
# line. The record is accounted for here and not by a named exclusion: it is one
# file rather than a class, the paragraph above states why it can belong to no
# surface, and a roster line for it would read as a fourth excluded surface.
EXCLUDED_FILES = dict((name, []) for name, _why, _rule in EXCLUDED_SURFACES)
UNACCOUNTED = []
for _p in TRACKED:
    if surface_of(_p) is not None or _p == RECORD:
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
# list because they are on the verification surface and therefore ARE corpus;
# the record is checked separately and differently, two paragraphs down.
for _needed in ('docs/plan-invariants.md', 'hooks/lib/plan-invariants-guard.sh',
                'agents/spec-writer.md', 'agents/design.md', 'agents/design-review.md',
                'scripts/check-redline.sh', 'hooks/hooks.json',
                'scripts/check-plan-invariants.py',
                'scripts/check-plan-invariants-refusal.py'):
    if _needed not in CORPUS_PATHS:
        blocked('%s is read for its data but the tracked corpus does not carry it, so its own text is never swept -- stage it before trusting this run'
                % _needed)

# THE RECORD TAKES THE INDEX TEST, NEVER THE CORPUS TEST, and the two are
# deliberately different shapes. Corpus membership requires a surface and the
# record has none by design, so "present in the examined corpus" is a test it
# could never pass. What matters about it is the same thing: an untracked record
# is read here and absent from every other clone, which makes the local run
# green and every other one a cannot-run. An acceptance run is exempt, because
# the first one creates the file.
if MODE != 'accept' and RECORD not in set(TRACKED):
    blocked('%s is read as the comparison record but is not in the index, so this run is reading a file no other clone has -- stage it'
            % RECORD)

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

PINNED = [
    "**One writer per artefact.** The orchestrator writes neither a spec nor a design; each is written only by its owning subagent. *Because a party that both writes a document and reports on it can close a finding by editing the evidence.*",
    "**A spec is a behaviour contract, not an implementation plan.** A criterion may not spell a command, script, tool or test identifier. *Because a criterion naming its instrument asserts which instrument ran, not what the system does, and cannot survive a change of instrument.*",
    "**A design says NOTHING about tests**, and the furthest it goes is naming the cases each object it builds is used in. *Because every sentence a design could write about a test is a promise about something that does not exist when the document is authored, and each narrowed version of this rule regrew — first a per-criterion command, then an intent line, then a suite total.*",
    "**The design is frozen at the design-review GO verdict.** After it, a divergence that does not break the agreed approach is a marker plus a log row, never a rewrite. *Because re-verifying an unchanged document every round is the cost this replaced.*",
    "**A changed requirement goes to the spec; a changed artefact goes to the log; nothing is recorded in both places.** *Because two records of one fact is the drift the mechanism exists to reduce.*",
    "**Neither document carries a record of superseded material, and no verdict may require one.** *Because every such passage is read in full by every later whole-repository review and none of it describes the system.*",
    "**The closing fold runs once, after approval.** It applies the correction log's rows to the design items that diverged, collapses the spec to its record of deliberate absence, and leaves the rest of the frozen document alone. *Because an untouched sentence is now either caught mechanically — a number whose provenance is gone, an identity that no longer pairs in either direction — or it is prose stating neither, which is accepted as unnoticed rather than re-derived against the chance that it rotted.*",
    "**A required element of a spec or a design must be knowable at the time the document is authored, and so must the origin of every number either document states.** An element whose content is only determined later is forbidden. A stated number names, in the same sentence, which kind it is — a threshold the task handed down, an estimate derived in place with its derivation shown, or a measurement of something that already exists — and how it was obtained; a figure whose only honest origin would be a measurement of the artefact the document describes is forbidden with it, that measurement being one nobody can take while the document is still being written. *Because it guarantees two failures at once: invented content at authoring time, and a review loop at the end that cannot converge — the document is corrected against reality, reality moves on, and the correction reopens.*",
    "**A question left open must be one whose answer would change neither the chosen approach, nor the requirements, nor how the work breaks up.** A gap failing that test is closed before the plan is agreed; a gap passing it that later turns out to have changed any of the three re-enters the full design-and-review cycle rather than being patched in place. *Because the gap is paid for either way, and the cheaper-looking price — note it and carry on — is the one that falls due as a rewrite of an agreed plan at the moment the work is most committed to it.*",
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
# Leg 2. The inventory comparison.
#
# IT READS NO SENTENCE AND RULES ON NOTHING. The corpus is a closed set of
# surfaces, so the statements it carries are an inventory: this leg records that
# inventory and compares the tree against it, reporting every statement that
# arrived, departed, changed or -- in a file taking the code spelling -- MOVED,
# each with its own text, its surface, and on a change what it said before.
# NOTHING IS SET ASIDE -- there is no class of passage treated as harmless, so a
# change can be absent from the report only by not having happened. What a
# reported change MEANS is the reader's judgement.
#
# FOUR ANSWERS, AND THE FOURTH IS NARROWER ON PURPOSE. A relocation is reported
# for the code spelling and not for prose, because in a script a line's POSITION
# is semantic -- measured, moving the payload's exec above the entry point's
# three cannot-run guards makes all three unreachable with an identical line
# multiset -- while a moved paragraph is a re-wrap or a re-order and not a
# change. Positional prose was tried and rejected as breaking: it reports every
# re-ordering, and the 59 markdown files here are measured re-wrap-stable at
# three widths, which is the property that would be lost. A line's INDENTATION
# is semantic in the same way, so it is read as part of the statement rather
# than compared separately: a block de-indented out of its conditional does
# something different with every word unchanged, and stripping it made that
# whole class of change report as nothing.
#
# THE RECORD NAMES ITS COMPARAND INSTEAD OF COPYING IT. One row per corpus file:
# surface, blob sha, path. A record carrying each statement's text measures
# 2.52 MB against this one's ten kilobytes, and every accepted change would
# appear twice in the same diff -- once in the edited file and once in the
# record -- in a repository where nearly every commit edits instruction
# material. The repository is a git repository, so the sha names the exact
# previous text, recoverable byte-for-byte with nothing duplicated. A row
# carries nothing derivable from that blob: a statement count beside it would be
# a second record of one fact and could only come to disagree with it.
# ---------------------------------------------------------------------------
THRESHOLD = 0.6

# The two spellings of a statement, which are part of the contract rather than
# an implementation detail. Both collapse the INTERNAL runs of whitespace,
# because these documents hard-wrap and a unit evaluated line by line is
# evaluated on a wrap fragment. The LEADING whitespace is where they differ:
# the code spelling keeps it inside the statement, because an indent in a
# script is scope rather than layout, while prose carries no structure in its
# indent and a re-wrap moves it -- so the prose spelling drops it.
#
# MARKDOWN TAKES THE PROSE SPELLING AND EVERYTHING ELSE THE CODE SPELLING, and
# that split was measured rather than assumed: of the 122 corpus files 53 are
# markdown, and the five non-markdown files on the three prose surfaces are a
# settings manifest, three empty placeholders and a gitignore fragment -- all
# line-oriented data, none of it prose. A line is the authored unit of a script,
# as a sentence is of prose; applying the sentence rule to a shell script yields
# deterministic nonsense, and extracting only the prose a script emits would
# require deciding which lines are instruction material, which is the judgement
# this approach exists not to make.
FENCE = re.compile(r'^\s*(?:```|~~~)')
QUOTE_MARK = re.compile(r'^\s*(?:>\s?)+')
LIST_HEAD = re.compile(r'^(?:[-*+]\s+|\d+[.)]\s+)')
# A HEADING NEEDS THE SPACE AFTER ITS HASHES, which is what the markup itself
# requires, and reading `#` loosely costs a residual form: measured, re-wrapping
# this corpus at 72 columns puts `#89):` from a wrapped `PR #89)` at the head of
# a line, and a rule keyed on a bare `#` reads that as a heading -- which breaks
# its paragraph in two and reports a change, an arrival and a departure for a
# reflow that changed no words.
HEADING = re.compile(r'^#{1,6}(?:\s|$)')
UNIT_TAIL = '*_`)]"\''


def split_units(text):
    """One sentence, one list item, or one clause the author separated with a
    semicolon. Backtick spans are opaque, so a path, a flag or a code span
    carrying either terminator does not cut the sentence it sits in."""
    units = []
    start = 0
    i = 0
    tick = False
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == '`':
            tick = not tick
            i += 1
            continue
        if not tick and ch in ';.!?' and i > start:
            j = i + 1
            # A terminator inside closing markup still ends its sentence:
            # `artefact.**` is the corpus's own commonest sentence end.
            while j < n and text[j] in UNIT_TAIL:
                j += 1
            if (j >= n or text[j] == ' ') and (ch == ';' or text[i - 1].isalnum()
                                               or text[i - 1] in UNIT_TAIL):
                units.append(text[start:j])
                start = j
                i = j
                continue
        i += 1
    units.append(text[start:])
    return [norm(u) for u in units if norm(u)]


def segment_prose(body):
    """Paragraphs joined across their hard-wrapped lines, then split into units.
    Four shapes are line-oriented instead, because each is its own authored unit
    and none of them wraps: a heading, a table row, a line inside a fenced
    block, and a line inside the YAML front matter at the head of a file."""
    out = []
    buf = []

    def flush():
        if buf:
            out.extend(split_units(' '.join(buf)))
            del buf[:]

    lines = body.split('\n')
    in_fence = False
    in_front = bool(lines) and lines[0].strip() == '---'
    at_block_start = True
    in_list = False
    for idx, raw in enumerate(lines):
        t = norm(raw)
        if in_front:
            if t:
                out.append(t)
            if idx > 0 and raw.strip() == '---':
                in_front = False
                at_block_start = True
            continue
        # Classified on the line with its blockquote markers stripped, while the
        # statement keeps the text as authored: this corpus states whole tables
        # and fenced blocks inside a quote, and a rule reading the raw line
        # would join those rows into one paragraph.
        plain = QUOTE_MARK.sub('', raw)
        if FENCE.match(plain):
            flush()
            in_fence = not in_fence
            if t:
                out.append(t)
            at_block_start = True
            in_list = False
            continue
        if in_fence:
            if t:
                out.append(t)
            continue
        if not t:
            flush()
            at_block_start = True
            continue
        if HEADING.match(plain.lstrip()) or plain.lstrip().startswith('|'):
            flush()
            out.append(t)
            at_block_start = True
            in_list = False
            continue
        # A LIST ITEM IS RECOGNISED ONLY WHERE A LIST CAN BEGIN -- after a blank
        # line, a heading, a fence or a table row, or while one is already
        # running. Never mid-paragraph: a re-wrap can put a number-and-period at
        # the start of a line, and a rule that trusted the line start would then
        # read half a sentence as a new item. This rule is what makes every one
        # of the 59 markdown files re-wrap-stable.
        if LIST_HEAD.match(plain.lstrip()) and (at_block_start or in_list):
            flush()
            buf.append(t)
            in_list = True
            at_block_start = False
            continue
        if at_block_start:
            in_list = False
        buf.append(t)
        at_block_start = False
    flush()
    return out


def segment_code(body):
    # THE INDENT IS PART OF THE STATEMENT, and only the internal runs collapse.
    # Returning `norm(line)` discarded the leading whitespace before both the
    # multiset and the order were built, so a block de-indented out of a
    # conditional, a loop or a function body reached this leg as the same
    # statement and was reported as nothing at all.
    out = []
    for line in body.split('\n'):
        text = norm(line)
        if text:
            indent = line[:len(line) - len(line.lstrip())]
            out.append(indent + text)
    return out


def segment(path, body):
    return segment_prose(body) if path.endswith('.md') else segment_code(body)


def current_shas(paths, write):
    """One process for the whole corpus. Hashing costs an order of magnitude
    less than segmenting -- measured 0.011-0.012 s against 0.142-0.166 s -- and
    what the equality buys is not the segmentation, which happens either way,
    but the object fetch, the difference and the only super-linear step."""
    if not paths:
        return {}
    cmd = ['git', '-C', ROOT, 'hash-object', '--stdin-paths']
    if write:
        cmd.insert(4, '-w')
    try:
        out = subprocess.run(cmd, input='\n'.join(paths).encode('utf-8'),
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        blocked('the corpus could not be hashed, so nothing could be compared against the record (%s)' % exc)
        return {}
    shas = out.decode('ascii', 'replace').split()
    if len(shas) != len(paths):
        blocked('hashing returned %d names for %d corpus files, so the comparison would read a shifted record'
                % (len(shas), len(paths)))
        return {}
    return dict(zip(paths, shas))


def blobs(shas):
    """`git cat-file --batch` in one process. A sha the repository cannot
    produce comes back as a miss rather than as empty text, because empty text
    would read as a file whose every statement departed."""
    if not shas:
        return {}
    try:
        proc = subprocess.run(['git', '-C', ROOT, 'cat-file', '--batch'],
                              input='\n'.join(shas).encode('ascii'),
                              capture_output=True, check=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        blocked('the recorded blobs could not be read from the object store (%s)' % exc)
        return {}
    out = proc.stdout
    got = {}
    pos = 0
    while pos < len(out):
        nl = out.find(b'\n', pos)
        if nl < 0:
            break
        header = out[pos:nl].decode('ascii', 'replace').split()
        pos = nl + 1
        if len(header) >= 2 and header[1] == 'blob':
            size = int(header[2])
            got[header[0]] = out[pos:pos + size].decode('utf-8', 'replace')
            pos += size + 1
        else:
            got[header[0]] = None
    return got


def align(arrivals, departures):
    """Exact match has already run, by construction: the multiset difference is
    complete before anything here looks at the leftovers. Each arrival is paired
    with the remaining departure it most resembles, by token overlap over the
    normalised words, within the same file, each departure claimed at most once.

    THE SIMILARITY JUDGEMENT MAY ONLY ALIGN. It cannot change the verdict --
    every leftover is reported either way, and the only difference is whether
    two lines are presented as one. That is a structural property of where this
    sits, not a promise about a threshold. Each statement's word set is built
    ONCE: measured on the largest corpus file rewritten whole, 1,464 against
    1,464 is 4.54 s with the sets rebuilt per comparison and 1.05 s with them
    hoisted, which is why the hoist is part of the design rather than a later
    optimisation -- and why a second on the worst file the corpus holds needs no
    bound above which the pairing stops."""
    if not arrivals or not departures:
        return [], list(arrivals), list(departures)
    aw = [set(a.split()) for a in arrivals]
    dw = [set(d.split()) for d in departures]
    claimed = [False] * len(departures)
    pairs = []
    rest_a = []
    for i, text in enumerate(arrivals):
        best = -1
        best_ratio = 0.0
        for j in range(len(departures)):
            if claimed[j]:
                continue
            union = len(aw[i] | dw[j])
            if not union:
                continue
            ratio = len(aw[i] & dw[j]) / union
            if ratio > best_ratio:
                best_ratio = ratio
                best = j
        if best >= 0 and best_ratio >= THRESHOLD:
            claimed[best] = True
            pairs.append((text, departures[best], best_ratio))
        else:
            rest_a.append(text)
    return pairs, rest_a, [d for j, d in enumerate(departures) if not claimed[j]]


def moved(was, now):
    """Which statements changed POSITION, for a file whose statement multiset
    did not. Reached only in that case, so the sequences are permutations and
    every statement leaving one region has a counterpart arriving in another;
    the pairing is by text, the only identity a statement has here.

    `autojunk=False` is load-bearing. The default treats any element in more
    than 1% of a sequence longer than 200 as junk, and the commonest statements
    in these scripts -- a bare `else:`, a closing brace, `fi` -- are exactly
    that: under it they stop anchoring the alignment and a one-line move is
    reported as a hundred."""
    gone = []
    came = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, was, now,
                                                       autojunk=False).get_opcodes():
        if tag == 'equal':
            continue
        gone += [(i, was[i]) for i in range(i1, i2)]
        came += [(j, now[j]) for j in range(j1, j2)]
    out = []
    for j, text in came:
        for k, (i, old) in enumerate(gone):
            if old == text:
                out.append((text, i + 1, j + 1))
                del gone[k]
                break
    return sorted(out, key=lambda t: t[2])


def parse_record(body):
    rows = {}
    for no, line in enumerate(body.split('\n'), 1):
        if not line.strip():
            continue
        cells = line.split('\t')
        if len(cells) != 3 or not re.fullmatch(r'[0-9a-f]{40}', cells[1]) or not cells[2]:
            blocked('%s line %d is not a `<surface><TAB><blob sha><TAB><path>` row, so the comparison has no expectation to read: %r'
                    % (RECORD, no, line[:120]))
            return None
        rows[cells[2]] = (cells[0], cells[1])
    if not rows:
        blocked('%s carries no row, and an empty record must not read as a tree with nothing in it' % RECORD)
        return None
    return rows


def record_body(paths, shas):
    return ''.join('%s\t%s\t%s\n' % (surface_of(p), shas[p], p) for p in sorted(paths))


SEGMENTS = {}
STATEMENTS = 0
# EVERY CORPUS FILE IS SEGMENTED ON EVERY RUN, and that is not an optimisation
# question. AC12's false green is a run that silently compared fewer statements
# than the corpus holds, so a run that skipped segmentation for unchanged files
# would have no total to report in exactly the clean case the figure exists for.
for _path, _body in CORPUS:
    SEGMENTS[_path] = segment(_path, _body)
    STATEMENTS += len(SEGMENTS[_path])

CUR_SHAS = current_shas(sorted(CORPUS_PATHS), MODE == 'accept')
_record_text = read(RECORD)
RECORDED = parse_record(_record_text) if _record_text is not None else None
if RECORDED is None and MODE != 'accept' and not cannot:
    blocked('%s is unreadable, so there is no inventory to compare the tree against -- an acceptance run creates it'
            % RECORD)

# Rule names, so every reported line is traceable to the rule that produced it.
EXACT = 'exact match'
WHOLE_NEW = 'exact match, and the file has no row in the record, so every statement in it arrived'
WHOLE_GONE = 'exact match, and the record names a path the corpus no longer carries, so every statement in it departed'
NO_PREVIOUS = 'previous text unavailable -- the recorded blob could not be produced'
RELOCATED = 'the statement multiset is unchanged and the ORDER is not, which in a file taking the code spelling is a move and not a text change'

TAKEN_IN = 0
if RECORDED is not None and CUR_SHAS:
    stale = [p for p in sorted(CORPUS_PATHS)
             if p in RECORDED and RECORDED[p][1] != CUR_SHAS.get(p)]
    gone = sorted(set(RECORDED) - CORPUS_PATHS)
    want = [RECORDED[p][1] for p in stale] + [RECORDED[p][1] for p in gone]
    PREVIOUS = blobs(want)

    def previous_of(path):
        sha = RECORDED[path][1]
        text = PREVIOUS.get(sha)
        if text is None:
            # The ordinary verification cannot compare against text it cannot
            # fetch, and a row it cannot resolve is not a clean row. An
            # acceptance run DEGRADES instead: previous text is what a report
            # needs, not what a rewrite needs, and that asymmetry is the only
            # exit from this state that the state cannot block.
            if MODE == 'accept':
                report_lines.append('  %s %s: %s (recorded sha %s)'
                                    % (RECORDED[path][0], path, NO_PREVIOUS, sha))
                return None
            blocked('the record names blob %s for %s and the repository cannot produce it, so there is no previous text to compare against -- an acceptance run clears this'
                    % (sha, path))
            return None
        return text

    def report(leg, surf, path, verb, rule, text, before=None):
        global TAKEN_IN
        TAKEN_IN += 1
        line = '%s %s: a statement %s [%s]\n    %s' % (surf, path, verb, rule, text)
        if before is not None:
            line += '\n    previously: %s' % before
        # SURF GOES TO `finding` AS WELL AS INTO THE LINE. Interpolating it and
        # stopping there is the defect this comparison shipped with: every
        # leg-2 finding read as text alone, so the roster called the surface
        # carrying them examined-clean. For a departed path `surf` is the
        # RECORDED surface rather than `surface_of`, which is the only label
        # available once the path is gone and is the right one to redden.
        finding(leg, line, surf)

    for path in sorted(CORPUS_PATHS):
        surf = surface_of(path)
        if path not in RECORDED:
            for text in SEGMENTS[path]:
                report('leg2-arrival', surf, path, 'ARRIVED', WHOLE_NEW, text)
            continue
        if RECORDED[path][1] == CUR_SHAS.get(path):
            continue
        prev_text = previous_of(path)
        if prev_text is None:
            continue
        # A MULTISET, NOT A SET. Measured: 111 of the 122 files carry a repeated
        # normalised statement, so under set semantics the removal of one of
        # three identical lines would be invisible.
        now_units = SEGMENTS[path]
        was_units = segment(path, prev_text)
        now = collections.Counter(now_units)
        was = collections.Counter(was_units)
        arrivals = list((now - was).elements())
        departures = list((was - now).elements())
        # AND ORDER AS WELL, FOR THE CODE SPELLING -- the banner above carries
        # why. A statement that merely MOVED is in both multisets, so both lists
        # come back empty while the sha still differs, which is the exact state
        # this branch tests for.
        if not arrivals and not departures and not path.endswith('.md'):
            for text, was_at, now_at in moved(was_units, now_units):
                # Statement ordinals, not file line numbers: the code spelling
                # drops blank lines, so the two do not coincide and printing one
                # as the other sends a reader to the wrong place.
                report('leg2-relocation', surf, path,
                       'MOVED from statement %d to statement %d' % (was_at, now_at),
                       RELOCATED, text)
            continue
        pairs, arrivals, departures = align(arrivals, departures)
        for text, before, ratio in pairs:
            report('leg2-change', surf, path, 'CHANGED',
                   'aligned at a token overlap of %.2f' % ratio, text, before)
        for text in arrivals:
            report('leg2-arrival', surf, path, 'ARRIVED', EXACT, text)
        for text in departures:
            report('leg2-departure', surf, path, 'DEPARTED', EXACT, text)

    for path in gone:
        prev_text = previous_of(path)
        if prev_text is None:
            continue
        for text in segment(path, prev_text):
            report('leg2-departure', RECORDED[path][0], path, 'DEPARTED', WHOLE_GONE, text)

# ---------------------------------------------------------------------------
# Leg 3. The required-element set, derived and compared in both directions.
#
# ROUTE 1 IS PATH-ANCHORED TO THE TWO WRITER CONTRACTS, and that is a
# requirement rather than a convenience: the bare section line inside a fence is
# not a rare spelling here, and a corpus-wide derivation of it hands the
# comparison tens of tokens against a record of thirteen elements. The cost is
# stated -- a third writer contract would carry elements this route cannot see
# -- and the comparison above is what reports such a contract's arrival.
#
# ROUTE 2 IS THE QUIETER ROUTE. A line in the review contract carrying both an
# element-shaped token and a severity verdict makes that element mandatory with
# no template changing anywhere. The corpus spells a severity verdict three
# disjoint ways, so the arm reads ANY spelling rather than an enumeration of
# the three: an enumeration has to be re-measured every time the corpus acquires
# a fourth way of saying it, and a missing spelling is silent.
#
# ROUTE 3 READS THE ENFORCER'S PINNED DATA, because it carries element lists as
# data where a sweep of prose cannot see them. It has TWO targets now: one is a
# requirement list and one is a PROHIBITION read on its own arm -- both of that
# list's entries happen also to be template elements today, which is coincidence
# rather than structure, so merging it into the element set would agree by
# accident. There were three until the per-criterion verification line stopped
# being an element; the assignment that carried it, and the verb that asserted
# it, were deleted from that file together. The reason the count is recorded
# here rather than left implicit: a route that silently reads fewer targets than
# the enforcer holds derives fewer elements and reports no arrival for the ones
# it stopped seeing.
#
# THIS LEG STAYS ITS OWN LEG rather than folding into the comparison. It is a
# derivation measured against a record in two directions, it reads no sentence,
# and folding it in would lose the direction in which a widened record alone is
# reported.
# ---------------------------------------------------------------------------
SPEC_CONTRACT = 'agents/spec-writer.md'
DESIGN_CONTRACT = 'agents/design.md'
REVIEW_CONTRACT = 'agents/design-review.md'
ENFORCER = 'scripts/check-redline.sh'
# [severity]
SEVERITY = r'(?:is a `(?:major|minor|blocker)` finding|=\s*`(?:major|minor|blocker)`|is `(?:major|minor|blocker)`)'

DERIVED = set()
PROHIBITED_HEADINGS = set()


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

_enf = read(ENFORCER)
if _enf is None:
    blocked('%s is unreadable, so route 3 cannot be read' % ENFORCER)
else:
    m = re.search(r"(?ms)^RETAINED='(.*?)'", _enf)
    if not m or not m.group(1).strip():
        blocked("%s carries no readable RETAINED assignment, which is a cannot-run rather than an empty requirement set" % ENFORCER)
    else:
        for t in [x.strip() for x in m.group(1).split('\n') if x.strip()]:
            DERIVED.add(('spec', t))
    # ROUTE 3 DERIVES SPEC ELEMENTS ONLY, and that is now the whole of it. It
    # used to read a per-criterion verification line out of this enforcer as its
    # one DESIGN element. That line is gone from the design contract and from
    # this enforcer: a design says nothing about tests, so there is no
    # per-criterion verification to assert the presence of. A design element
    # arriving by this route again would mean a mechanical check had started
    # asserting one, which is the thing the route exists to notice -- so the
    # absence is recorded here rather than left as a silent gap.
    m = re.search(r"(?m)^RESIDUE_HEADINGS='(.*?)'", _enf)
    if not m or not m.group(1).strip():
        blocked("%s carries no readable RESIDUE_HEADINGS assignment, so the fold's prohibition arm cannot be read" % ENFORCER)
    else:
        for t in m.group(1).split('|'):
            t = t.strip().lstrip('^')
            if t:
                PROHIBITED_HEADINGS.add(t)

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
    finding('leg3-arrival',
            'a page mandates the %s element `%s`, which the record in %s does not carry -- an element has ARRIVED'
            % (doc, tok, PRINCIPLES_DOC), surface_of(PRINCIPLES_DOC))
for doc, tok in sorted(RECORDED_ELEMENTS - DERIVED):
    finding('leg3-departure',
            'the record in %s carries the %s element `%s`, which no page mandates -- an element has DEPARTED, or the record was widened on its own'
            % (PRINCIPLES_DOC, doc, tok), surface_of(PRINCIPLES_DOC))

for h in sorted(PROHIBITED_HEADINGS):
    if not any(t == h for _d, t in DERIVED):
        finding('leg3-prohibition',
                'the fold is now required to REMOVE `%s`, which no template mandates -- that is a prohibition ARRIVING and it is reported as one rather than joining the element set'
                % h, surface_of(ENFORCER))

# ---------------------------------------------------------------------------
# Leg 4. Refusal agreement -- the live covered set of the edit-time refusal
# against the protected-page table, in both directions. It is a SIBLING rather
# than a span, for the reason its own header gives; of the four legs it was the
# only pure SINK, so the seam is one call and a context mapping with nothing
# read back.
# ---------------------------------------------------------------------------
REFUSAL = load_sibling('check-plan-invariants-refusal.py')
if REFUSAL is not None:
    REFUSAL.run({
        'read': read, 'blocked': blocked, 'finding': finding, 'norm': norm,
        'surface_of': surface_of, 'doc_body': doc_body,
        'PRINCIPLES_DOC': PRINCIPLES_DOC, 'RECORD': RECORD,
        'PLAN_TOKENS': PLAN_TOKENS, 'CORPUS': CORPUS,
    })

# ---------------------------------------------------------------------------
# Report. The verdict carries the six input counts beside the findings count,
# because a run that silently examined fewer than the full set is otherwise
# indistinguishable from a clean one -- and `statements` is the figure that
# surfaces this approach's own false green, a run that compared fewer statements
# than the corpus holds.
#
# `unaccounted` IS THE SIXTH AND READS THE OTHER WAY from the five beside it:
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
    return ('principles=%d elements=%d surfaces=%d pages=%d statements=%d unaccounted=%d findings=%d'
            % (PRINCIPLE_COUNT, ELEMENT_COUNT, len(SURFACE_ORDER), PAGES, STATEMENTS,
               len(UNACCOUNTED), len(findings)))


for line in report_lines:
    print(line)
for line in findings:
    print(line)

if cannot:
    for line in cannot:
        print(line)
    print('check-plan-invariants: CANNOT RUN -- which is not a pass | %s' % counts())
    roster()
    sys.exit(2)

if MODE == 'accept':
    # ACCEPTANCE IS A DELIBERATE ACT AND NOTHING ELSE'S SIDE EFFECT. No other
    # command and no part of an ordinary gate run advances the record; the
    # report above is printed BEFORE the rewrite, so the author reads what they
    # are accepting in the same output. The rewrite also WRITES each blob it
    # names, so the object exists from this moment and becomes permanently
    # reachable when the accepted content is committed.
    target = os.path.join(ROOT, RECORD)
    try:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, 'w', encoding='utf-8') as fh:
            fh.write(record_body(CORPUS_PATHS, CUR_SHAS))
    except OSError as exc:
        print('cannot run: the record at %s could not be written (%s)' % (RECORD, exc))
        print('check-plan-invariants: CANNOT RUN -- which is not a pass | %s' % counts())
        roster()
        sys.exit(2)
    print('check-plan-invariants: ACCEPTED -- the record now names this tree | rows=%d taken-in=%d %s'
          % (len(CORPUS_PATHS), TAKEN_IN, counts()))
    roster()
    sys.exit(0)

verdict = 'clean' if not findings else '%d findings' % len(findings)
print('check-plan-invariants: %s | %s' % (verdict, counts()))
roster()
sys.exit(1 if findings else 0)
