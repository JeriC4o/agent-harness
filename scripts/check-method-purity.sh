#!/usr/bin/env bash
#
# Does the shipped method half stay free of one project's stack, and does the
# tree stay free of identifiers taken from another real codebase?
#
# Run:  check-method-purity.sh [--root <dir>]
# Exit: 0 clean, 1 findings, 2 cannot run -- which is NOT a pass.
#
# Tests: scripts/test-check-method-purity.sh
#
# WHY THIS GATE EXISTS. AGENTS.md calls a method file that acquires a project
# fact a `major` finding, and nothing enforced it: language names, one stack's
# syntax and another codebase's class names accumulated in the review contracts
# every consuming project applies, and survived two clean-up requests.
#
# TWO LEGS, TWO SURFACES.
#   stack    -- `*.md` under docs/ skills/ agents/ rules/. A language,
#               framework, build tool or doc tool by name, or one language's
#               syntax used as the rule's own example. The harness's own
#               tooling (jq, awk, python3 as an interpreter it runs) is not a
#               project fact and is not on the list.
#
# TRACKED AND UNTRACKED. The index alone would pass a method file written but
# not yet staged -- the likeliest way drift comes back -- so untracked files
# that .gitignore does not exclude are read too.
#   foreign  -- every text file. A known identifier from another real
#               codebase, matched as a case-insensitive substring of any token.
#
# WHY THE FOREIGN STEMS ARE HASHED. Spelling them out here would put the very
# material this leg refuses back into the tree. Each stem is stored as its length
# and the first 16 hex digits of its sha256; a token is tested by hashing each of
# its substrings of those lengths. METHOD_PURITY_EXTRA_STEMS (space-separated,
# plain text) adds stems for a run -- the suite uses it with invented names.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)

while [ $# -gt 0 ]; do
  case $1 in
    --root)
      [ -d "${2:-}" ] || { printf 'check-method-purity: no such directory: %s\n' "${2:-}" >&2; exit 2; }
      ROOT=$(cd -- "$2" && pwd); shift 2 ;;
    *) printf 'check-method-purity: usage: check-method-purity.sh [--root <dir>]\n' >&2; exit 2 ;;
  esac
done

for t in git python3; do
  command -v "$t" >/dev/null 2>&1 \
    || { printf 'check-method-purity: cannot run -- %s is not on PATH. A missing tool is not a pass.\n' "$t" >&2; exit 2; }
done
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
  || { printf 'check-method-purity: cannot run -- %s is not a git working tree\n' "$ROOT" >&2; exit 2; }

OUT=$(python3 -B -c '
import fnmatch, hashlib, os, re, subprocess, sys

root = sys.argv[1]
def listed(*extra):
    raw = subprocess.run(["git", "-C", root, "ls-files", "-z"] + list(extra),
                         capture_output=True, check=True).stdout
    return [p for p in raw.decode("utf-8", "replace").split("\0") if p]
tracked = listed()
paths = tracked + listed("-o", "--exclude-standard")

DENY = {(7, "724d2d2cd4ec219e"), (13, "a01969836d4acf19"),
        (7, "8d239f1bb5df7444"), (7, "3259138318d8d440")}
for s in os.environ.get("METHOD_PURITY_EXTRA_STEMS", "").split():
    s = s.lower()
    DENY.add((len(s), hashlib.sha256(s.encode()).hexdigest()[:16]))
LENGTHS = sorted({n for n, _ in DENY})

# Case-insensitive names, then names that are also ordinary English and so
# count only capitalised, then spellings no word boundary can bracket.
# [purity-words]
WORDS = ("kotlin java jvm jdk javap typescript javascript scala php golang csharp dotnet nodejs "
         "django postgres postgresql mysql sqlite gradle maven npm cargo kdoc javadoc jsdoc "
         "rustdoc godoc doxygen sphinx mermaid pytest junit\\d* mockito mockk ktlint detekt").split()
CAPITAL = "Python Ruby Swift Rust Spring".split()
EDGE = r"(?<![A-Za-z0-9_-])(%s)(?![A-Za-z0-9_])"
STACK = [(re.compile("(?i)" + EDGE % "|".join(WORDS)), "stack name"),
         (re.compile(EDGE % "|".join(CAPITAL)), "stack name"),
         (re.compile(r"(?<![A-Za-z0-9])(?:C#|\.NET|[Nn]ode\.js)(?![A-Za-z0-9])"), "stack name"),
         (re.compile(r"\boverride fun\b|`fun`|\bfun [a-z]\w*\("), "language syntax"),
         (re.compile(r"@Suppress\w*|@Test\b|\bIllegal\w*Exception\b|`(?:require|check)\("), "language syntax"),
         (re.compile(r"(?<![\w./*-])[\w./*-]+\.(?:kts?|java|scala|rb|rs|py|go|tsx?|jsx?|cs|swift|php)\b"), "source path")]

# A path naming a file this tree itself holds, or a glob rooted in one of its
# directories that matches such a file, is harness tooling (a python payload,
# say), not the source of a consuming project. A bare `*.ext` glob is never
# exempt: it names a language, whatever the tree happens to hold.
def own(token):
    token = token.lstrip("./")
    if "*" in token:
        lead = token[:token.index("*")]
        if "/" not in lead:
            return False
        base = lead.rsplit("/", 1)[0] + "/"
        return any(p.startswith(base) and fnmatch.fnmatchcase(p, token) for p in tracked)
    return any(p == token or p.endswith("/" + token) for p in tracked)

def is_method(p):
    return p.endswith(".md") and p.split("/", 1)[0] in ("docs", "skills", "agents", "rules")

def read_lines(p):
    try:
        with open(os.path.join(root, p), "rb") as fh:
            data = fh.read()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return []
    return data.decode("utf-8", "replace").splitlines()

seen = {}
def foreign(tok):
    low = tok.lower()
    hit = seen.get(low)
    if hit is None:
        hit = False
        for n in LENGTHS:
            for i in range(len(low) - n + 1):
                if (n, hashlib.sha256(low[i:i + n].encode()).hexdigest()[:16]) in DENY:
                    hit = True
                    break
            if hit:
                break
        seen[low] = hit
    return hit

findings, method_files, text_files, unreadable = [], 0, 0, []
for p in paths:
    lines = read_lines(p)
    if lines is None:
        unreadable.append(p)
        continue
    if not lines:
        continue
    text_files += 1
    method = is_method(p)
    method_files += method
    for no, line in enumerate(lines, 1):
        if method:
            for rx, label in STACK:
                for m in rx.finditer(line):
                    if label == "source path" and own(m.group(0)):
                        continue
                    findings.append("%s:%d: %s: %s" % (p, no, label, m.group(0)))
        for tok in set(re.findall(r"[A-Za-z0-9]+", line)):
            if len(tok) >= LENGTHS[0] and foreign(tok):
                findings.append("%s:%d: foreign identifier: %s" % (p, no, tok))

for f in findings:
    print(f)
for p in unreadable:
    print("check-method-purity: cannot read listed file %s" % p, file=sys.stderr)
stack = sum(": foreign identifier: " not in f for f in findings)
verdict = "cannot-run" if (unreadable or method_files == 0) else ("findings" if findings else "clean")
print("check-method-purity: verdict=%s method_files=%d text_files=%d stack_hits=%d foreign_hits=%d"
      % (verdict, method_files, text_files, stack, len(findings) - stack))
sys.exit(2 if verdict == "cannot-run" else 1 if findings else 0)
' "$ROOT")
rc=$?
[ -n "$OUT" ] && printf '%s\n' "$OUT"
# A crash in the body also exits 1; without its verdict line that is a
# cannot-run, never a finding.
case $OUT in *'check-method-purity: verdict='*) exit "$rc" ;; esac
printf 'check-method-purity: cannot run -- the scan ended (rc %s) without a verdict\n' "$rc" >&2
exit 2
