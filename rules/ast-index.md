# Code-search hierarchy

On-demand rules for any code-search action. Subagents inherit the verbatim block at the bottom of this file (the orchestrator embeds it in spawn prompts).

## Hierarchy

1. **The `Grep` tool** (ripgrep under the hood) — the default for a content search inside this repo. It respects `.gitignore`, returns `file:line:content`, and takes a path filter (`glob`) and an output mode. Prefer it over shelling out: it is scoped, fast, and its results are already structured.
2. **`rg <pattern> -n --glob '<filter>' <path>`** via Bash — reach for it when you need ripgrep flags the tool does not expose (`-A`/`-B` context asymmetry, `--multiline`, `-o`, `--type-add`). **Carry a path filter by default** (`--glob '*.{kt,java}'` when hunting code) — see § Forbidden for why an unfiltered repo-wide content search is not a neutral act.
3. **`git grep -n <pattern>`** — when the question is specifically about a *committed* state (`git grep -n <pattern> <rev>`), or when you want ripgrep-free behaviour that follows the index rather than the working tree. Note the inverse of `rg`: `git grep` searches tracked files only, so a brand-new untracked file is invisible to it.
4. **Scoped `grep -rn` / `find`** — fine inside a known small directory. Never from `/` or `$HOME`.
5. **Read with offset/limit** — for files >500 lines, run a heading scan first (`grep -nE '^(class|func|fun|def|type|interface|##) ' <file>`) to locate the section, then Read only the targeted slice.

> **Hidden directories are skipped by default.** `rg` and the `Grep` tool ignore dot-directories, so a sweep over the instruction surface that does not pass `--hidden` (or name `.claude/` explicitly as a path) silently returns zero hits for strings that plainly sit in `.claude/**`. A silent zero reads as "no sister files reference this keyword" — i.e. as permission to skip propagation. Always name `.claude/` explicitly, or pass `--hidden -g '!.git'`.

## Forbidden

- `find /`, or `find` / `grep -r` over `$HOME` (`~`). NEVER `run_in_background` a filesystem scan — a backgrounded `find` leaks a long-running process.
- `grep -r` from the filesystem root or from `$HOME`. For an installed CLI/binary use `type` / `command -v` / `which`, not a tree scan.
- **Never** search or `Read` under build-output directories (`target/`, `build/`, `dist/`, `node_modules/`, `.gradle/`) — they hold artefacts, never source, and they are on the read blacklist via `.gitignore`.
- Any repo-wide content search whose file filter can match an **ASK-gated deployed-config file** (`application*.properties` and friends) — that is a gated read (AGENTS.md § Permissions) regardless of the tool. Exclude it or ask first, and **mind the spelling per tool**: plain `grep -r` takes a glob (`--exclude=application*.properties`); ripgrep takes a negated glob (`-g '!application*.properties'`); a tool whose exclude flag takes a **regex** needs `application.*\.properties$` — passing the glob spelling to a regex flag silently misses `application-<profile>.properties`, the file that actually carries the deployed overrides. Drop the filter only when the PATTERN ITSELF cannot occur in a config file — a code symbol, an annotation, a class name. That is a property of the pattern's syntax, decidable before you run anything; it is NOT a guess about what the results will contain. Never reason "this probably won't hit a config file" — you cannot know a gated path is in the result set until it is already in context, at which point the gate has been breached.
- Reading files > 2000 lines without an offset/limit.
- **Backticks inside a double-quoted search pattern** — the shell runs them as command substitution before the tool ever sees the pattern. Backticked test names collide with this constantly: use SINGLE quotes for the whole pattern, or drop the backticks from the pattern entirely.
- **Free-form prose passed to a CLI through single quotes** — an apostrophe CLOSES the string and the shell re-parses the remainder, so the CLI still runs and posts a **truncated** payload with rc=0. Apostrophes, contractions and Markdown backticks all trip it, and the mangled artefact is visible to other people before it is visible to you. Build every prose payload with a quoted heredoc — `VAR=$(cat <<'EOF' … EOF)` — and pass `"$VAR"`. After any write to a shared surface (PR comment, PR description, issue comment), read the artefact back and check its LENGTH and TAIL: the send returns exit 0 with a summary line even when two thirds of the message is missing.
- **An unquoted `$var` adjacent to shell-significant punctuation** — in zsh, `$B:path/f` parses `:a` as the absolute-path parameter modifier and silently corrupts the value; and an unquoted `$FILES` is **not** word-split, so a multi-file tool call receives one argument, matches nothing, and exits 0. Always brace-and-quote: `"${rev}:${path}"`, `"${arr[@]}"`. Treat any unquoted `$var` next to `:` `;` `&` `|` as a defect on sight.
- **Feeding one command's path output back into another's pathspec without checking the path space.** Paths printed relative to the repo root and paths interpreted relative to CWD are different spaces, and the mismatch fails **silently** — `git diff --name-only main -- <path-from-a-subdir>` returns EMPTY at rc=0, which reads as "nothing changed". Positive-control any pathspec filter with a path you KNOW is in the unfiltered output; the control must come back NON-EMPTY. Removing the filter and seeing output is not that control — it proves the command works, not that the filter matched.

## Propagation sweep

The canonical form for an instruction-file propagation sweep (AGENTS.md § Propagation Rule). One command, three requirements:

```bash
rg -n --hidden -g '!.git' "<changed-keyword>" AGENTS.md CLAUDE.md skills/ agents/ rules/ docs/ ai-docs/
```

1. **Name every instruction directory.** The operand list above is the HARNESS-REPO surface (where method files are edited). Inside a consuming project the surface is only `AGENTS.md CLAUDE.md ai-docs/` — the harness itself is installed read-only under `${CLAUDE_PLUGIN_ROOT}` and is swept in its own repo, not here. Scoping to one directory leaves a rule's prose copy uncovered.
2. **Pass `--hidden`** — a project surface includes dot-directories (`.claude/settings.json`), and without the flag they are skipped and the sweep false-passes.
3. **Run a positive control before trusting an empty result.** Sweep a keyword you KNOW is present (e.g. `Propagation Rule`) and confirm it returns hits. A silent zero from a typo'd keyword is indistinguishable from "no sister files", and it reads as permission to skip propagation.

To check the **committed** tree as well — useful when reconciling against a branch you have not merged — add:

```bash
git grep -n "<changed-keyword>" -- AGENTS.md CLAUDE.md skills agents rules docs ai-docs
```

`git grep` sees tracked files only, so it misses a brand-new untracked instruction file; `rg` over the working tree sees both. Use `git grep` as a supplement, never as the sweep itself.

## Subagent-inherited block (verbatim — embed in `Agent(...)` prompts)

```
Use the Grep tool (ripgrep) for code search; shell out to `rg` only for flags the tool does not expose.

  Grep(pattern, glob: "*.{kt,java}", output_mode: "content")   — default; respects .gitignore
  rg -n -g '*.{kt,java}' "<pattern>" <path>                    — when you need raw ripgrep flags
  rg -n --hidden -g '!.git' "<pattern>" .                      — to include dot-dirs (skipped otherwise)
  git grep -n "<pattern>" <rev>                                — to ask about a COMMITTED state
  grep -rn "<pattern>" <small-dir>                             — fine inside a known small directory

ALWAYS carry a path filter unless the pattern's own syntax cannot occur in a config file.

HIDDEN DIRS ARE SKIPPED BY DEFAULT. A sweep over the instruction surface without `--hidden`
(or without naming the dot-directory as an explicit path) returns zero hits for strings that are plainly
there. A silent zero reads as "nothing references this" — always positive-control an empty result
with a keyword you know is present.

NEVER `find` / `grep -r` over `/` or `$HOME`. For an installed binary use `type` / `command -v`.
Never `run_in_background` a filesystem scan.

ASK-GATED CONTENT: deployed-config files (`application*.properties` and friends) are ASK-gated
(AGENTS.md § Permissions). The gate binds on ANY tool that surfaces the file's CONTENTS — a content
search IS a read of it, and an allow-listed search tool will NOT prompt. Constrain the filter so a
gated path cannot be in the result set, or ask first. For a setting's DEFAULT, read the typed config
binder class in source — ungated, and the actual default (a deployed file only ever shows an override).

NEVER put backticks inside a DOUBLE-quoted pattern — the shell runs them as command substitution
before the tool sees them. Use SINGLE quotes for the whole pattern, or drop the backticks.

SINGLE quotes are NOT a safe wrapper for free-form PROSE. An apostrophe closes the string and the
shell re-parses the remainder, so the CLI still runs and posts a TRUNCATED payload at rc=0. Build any
prose payload with a quoted heredoc — VAR=$(cat <<'EOF' … EOF) — pass "$VAR", then read the artefact
back and check its LENGTH and TAIL.

BRACE-AND-QUOTE every `$var` next to shell-significant punctuation. In zsh `$B:path/f` parses `:a` as
the absolute-path modifier and silently corrupts the value; an unquoted `$FILES` is NOT word-split, so
a multi-file tool call gets ONE argument, matches nothing, and exits 0. Write "${rev}:${path}", "${arr[@]}".

Before Reading any file over 500 lines, FIRST run a heading scan:
  grep -nE '^(class|func|fun|def|type|interface|##) ' <file>
to get its structure, then Read only the targeted slice via offset/limit. Never bulk-read large files.

A `file:line` anchor is authoritative output, never a derivation. NEVER compute a post-edit line
number by adding a delta to a pre-edit one — run `grep -n '<the actual token>' <file>` and cite what
it prints. An "it removed N lines" claim is itself unverified: confirm the net with
`git diff --stat -- <file>` (a hunk replacing a span with an equal-length span is net zero), and note
that the arithmetic only holds at all if every hunk sits ABOVE the anchor. Cite the executable
statement, not the doc-comment that describes it. If an anchor you were HANDED post-dates an edit,
treat it as "re-derive, do not trust" — re-run the grep before acting on it.
```

## Why the hierarchy matters

The `Grep` tool and `rg` read the working tree, so they see uncommitted edits — which is what a propagation sweep and a pre-commit review both need. `git grep` reads the index/a revision, so it answers a different question ("what does the committed tree say?") and misses untracked files. A `grep -r` from the filesystem root scans serially and orders of magnitude slower, with no `.gitignore` awareness, so it drowns the result set in build artefacts.

## Cross-references

- AGENTS.md `## Search` block.
- `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` PreToolUse(Bash) hook — `$HOME`-scan blocker.
