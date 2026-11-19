#!/usr/bin/env bash
#
# Does a name the glossary lists as an other name or a retired name appear in
# the harness's own files, and does the glossary itself hold together?
#
# Run:  check-vocabulary.sh [--root <dir>]
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-vocabulary.sh
#
# WHY NO EXEMPTION FOR QUOTING. In text for a person a quoted name is a mention.
# In these files every appearance counts: the glossary is where an old name lives
# on, and a sweep's leftovers would otherwise hide behind backticks.
#
# WHY SCRIPT WORDS ARE SKIPPED BY KIND, NOT BY FILE. A script keeps the names it
# gives its own variables and functions, the bracketed ids its comments carry for
# a document to cite, and lines under an internals mark. A per-file allowance
# would also hide a message the same script prints for a person. Python is read
# through its tokenizer, keeping only strings and comments; shell, awk and jq
# have their identifiers masked, since only comments and strings in them are
# words a person reads -- and unquoted shell text is one of those.
#
# ONE LIST. The names come from the glossary through the shared reader beside the
# hooks, so this check and the hook reading text for a person cannot disagree.
#
# TRACKED AND UNTRACKED. A covered file written but not yet staged is read too,
# as the method-purity check does.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "${HERE}/.." && pwd)
READER="${HERE}/../hooks/lib/glossary-names.sh"

while [ $# -gt 0 ]; do
  case $1 in
    --root)
      [ -d "${2:-}" ] || { printf 'check-vocabulary: no such directory: %s\n' "${2:-}" >&2; exit 2; }
      ROOT=$(cd -- "$2" && pwd); shift 2 ;;
    *) printf 'check-vocabulary: usage: check-vocabulary.sh [--root <dir>]\n' >&2; exit 2 ;;
  esac
done

for t in git python3 awk; do
  command -v "$t" >/dev/null 2>&1 \
    || { printf 'check-vocabulary: cannot run -- %s is not on PATH. A missing tool is not a pass.\n' "$t" >&2; exit 2; }
done
[ -r "$READER" ] || { printf 'check-vocabulary: cannot run -- the glossary reader %s is not readable\n' "$READER" >&2; exit 2; }
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
  || { printf 'check-vocabulary: cannot run -- %s is not a git working tree\n' "$ROOT" >&2; exit 2; }

OUT=$(python3 -B -c '
import io, os, re, subprocess, sys, tokenize

root, reader = sys.argv[1], sys.argv[2]
GLOSSARY = "docs/glossary.md"

def verdict(word, names=0, entries=0, files=0, findings=0):
    print("check-vocabulary: verdict=%s names=%d entries=%d files=%d findings=%d"
          % (word, names, entries, files, findings))

r = subprocess.run(["bash", reader, os.path.join(root, GLOSSARY)], capture_output=True, text=True)
if r.returncode != 0:
    print("check-vocabulary: cannot run -- " + (r.stderr.strip() or "the reader exited %d" % r.returncode),
          file=sys.stderr)
    verdict("cannot-run")
    sys.exit(2)
rows = [line.split("\t") for line in r.stdout.splitlines() if line]

findings = []
def norm(name):
    return re.sub(r"[\s-]+", " ", name.lower()).strip()

ROLE = {"canonical": "a canonical name", "other": "an other name of \"%s\"", "retired": "a retired name"}
roles = {}
for row in rows:
    if row[0] in ROLE:
        roles.setdefault(norm(row[1]), set()).add((int(row[3]), row[0], row[2]))
for name, held in sorted(roles.items()):
    if len(held) > 1:
        parts = ["%s (line %d)" % (ROLE[kind] % canon if kind == "other" else ROLE[kind], line)
                 for line, kind, canon in sorted(held)]
        findings.append((GLOSSARY, max(held)[0], "name collision: \"%s\" is %s" % (name, " and ".join(parts))))

heads = {}
def headings(rel):
    if rel not in heads:
        found, fence = set(), False
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if line.startswith("```"):
                    fence = not fence
                m = re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", line)
                if m and not fence:
                    found.add(m.group(1))
        heads[rel] = found
    return heads[rel]
for row in rows:
    if row[0] != "defined":
        continue
    canon, rel, line, head = row[1], row[2], int(row[3]), row[4]
    if not os.path.isfile(os.path.join(root, rel)):
        findings.append((GLOSSARY, line, "defined at: \"%s\" names %s, which does not exist" % (canon, rel)))
    elif head not in headings(rel):
        findings.append((GLOSSARY, line, "defined at: \"%s\" names %s section \"%s\", which it does not have"
                         % (canon, rel, head)))

listed = [(row[1], row[2] if row[0] == "other" else None) for row in rows if row[0] in ("other", "retired")]
entries = sum(row[0] == "canonical" for row in rows)
if not listed:
    print("check-vocabulary: cannot run -- the glossary lists no other or retired name", file=sys.stderr)
    verdict("cannot-run", 0, entries)
    sys.exit(2)

SEP = r"(?:-|[ \t]+|[ \t]*\n[ \t>#]*)"
alts, which = [], {}
for i, (name, canon) in enumerate(sorted(listed, key=lambda nc: -len(nc[0]))):
    words = [re.escape(w) for w in re.split(r"[\s-]+", name.lower()) if w]
    alts.append("(?P<n%d>%s(?:s|es|ed|d|ing|\x27s)?)" % (i, SEP.join(words)))
    which["n%d" % i] = (name, canon)
NAMES = re.compile(r"(?<![A-Za-z0-9_])(?:%s)(?![A-Za-z0-9_])" % "|".join(alts), re.I)

ID = re.compile(r"\[[a-z0-9]+(?:-[a-z0-9]+)*\](?!\()")
SHELL_NAMES = [re.compile(r"\$\{?[#!]?([A-Za-z_][A-Za-z0-9_]*)"),
               re.compile(r"(?m)(?<![^\s;({&|])([A-Za-z_][A-Za-z0-9_]*)(?=\+?=)"),
               re.compile(r"(?m)^[ \t]*(?:function[ \t]+)?([A-Za-z_][A-Za-z0-9_:.-]*)[ \t]*\(\)"),
               re.compile(r"\b(?:function|def)[ \t]+([A-Za-z_][A-Za-z0-9_]*)")]
MARK = re.compile(r"#\s*vocabulary-internal:(.*)$")
KIND = {".sh": "shell", ".bash": "shell", ".awk": "shell", ".jq": "shell", ".py": "python"}

def blanked(text, spans):
    chars = list(text)
    for a, b in spans:
        for k in range(a, b):
            if chars[k] != "\n":
                chars[k] = " "
    return "".join(chars)

def python_words(text):
    keep = {tokenize.STRING, tokenize.COMMENT, getattr(tokenize, "FSTRING_MIDDLE", -1)}
    starts = [0]
    for line in text.split("\n"):
        starts.append(starts[-1] + len(line) + 1)
    spans, last = [], 0
    for tok in tokenize.generate_tokens(io.StringIO(text).readline):
        if tok.type == tokenize.ERRORTOKEN and tok.string.strip():
            raise SyntaxError("unexpected %r at line %d" % (tok.string, tok.start[0]))
        if tok.type in keep:
            a = starts[tok.start[0] - 1] + tok.start[1]
            spans.append((last, a))
            last = starts[tok.end[0] - 1] + tok.end[1]
    spans.append((last, len(text)))
    return blanked(text, spans)

def shell_words(text):
    return blanked(text, [m.span(1) for rx in SHELL_NAMES for m in rx.finditer(text)])

def marked_lines(rel, lines):
    out, block = set(), False
    for no, line in enumerate(lines, 1):
        if not line.strip():
            block = False
        m = MARK.search(line)
        if m:
            out.add(no)
            if not m.group(1).strip():
                findings.append((rel, no, "internals mark gives no reason"))
            block = line.lstrip().startswith("#")
        elif block:
            out.add(no)
    return out

SURFACES = [("method",      lambda p: p.split("/", 1)[0] in ("docs", "skills", "agents", "rules")),
            ("hooks",       lambda p: p.startswith("hooks/")),
            ("scripts",     lambda p: p.startswith("scripts/")),
            ("profile",     lambda p: p in ("AGENTS.md", "ai-docs/context.md", "ai-docs/learnings/README.md")),
            ("scaffolding", lambda p: p.startswith("templates/project/")),
            ("user-facing", lambda p: p in ("README.md", ".claude-plugin/plugin.json",
                                            ".claude-plugin/marketplace.json"))]

def listed_paths(*extra):
    raw = subprocess.run(["git", "-C", root, "ls-files", "-z"] + list(extra), capture_output=True, check=True).stdout
    return [p for p in raw.decode("utf-8", "replace").split("\0") if p]
paths = sorted(set(listed_paths() + listed_paths("-o", "--exclude-standard")))

counts, unreadable, read = {name: 0 for name, _ in SURFACES}, [], 0
for rel in paths:
    if rel == GLOSSARY:
        continue
    surface = next((name for name, test in SURFACES if test(rel)), None)
    if surface is None or not os.path.isfile(os.path.join(root, rel)):
        continue
    try:
        with open(os.path.join(root, rel), "rb") as fh:
            data = fh.read()
    except OSError as e:
        unreadable.append("%s: %s" % (rel, e))
        continue
    if b"\0" in data[:8192]:
        continue
    text = data.decode("utf-8", "replace")
    kind = KIND.get(os.path.splitext(rel)[1])
    try:
        words = python_words(text) if kind == "python" else shell_words(text) if kind else text
    except (tokenize.TokenError, SyntaxError) as e:
        unreadable.append("%s: the tokenizer refused it (%s)" % (rel, e))
        continue
    words = blanked(words, [m.span() for m in ID.finditer(words)])
    exempt = marked_lines(rel, text.split("\n")) if kind else set()
    counts[surface] += 1
    read += 1
    for m in NAMES.finditer(words):
        no = words.count("\n", 0, m.start()) + 1
        if no in exempt:
            continue
        name, canon = which[m.lastgroup]
        role = "other name of \"%s\"" % canon if canon else "retired name"
        findings.append((rel, no, "listed name \"%s\" (%s) found as \"%s\""
                         % (name, role, re.sub(r"[\s>#]+", " ", m.group(0)))))

for problem in unreadable:
    print("check-vocabulary: cannot read %s" % problem, file=sys.stderr)
word = "cannot-run" if (unreadable or read == 0) else "findings" if findings else "clean"
verdict(word, len(listed), entries, read, len(findings))
for name, _ in SURFACES:
    print("  surface %-12s read (%d files)" % (name, counts[name]))
print("  excluded %-11s %s -- the one page that writes listed names" % ("glossary", GLOSSARY))
for rel, no, what in sorted(findings):
    print("%s:%d: %s" % (rel, no, what))
sys.exit(2 if word == "cannot-run" else 1 if findings else 0)
' "$ROOT" "$READER")
rc=$?
[ -n "$OUT" ] && printf '%s\n' "$OUT"
# A crash in the body also exits 1; without its verdict line that is a
# cannot-run, never a finding.
case $OUT in *'check-vocabulary: verdict='*) exit "$rc" ;; esac
printf 'check-vocabulary: cannot run -- the scan ended (rc %s) without a verdict\n' "$rc" >&2
exit 2
