# Coarse normalisation of a tool call into a "bin" -- the SHAPE of the command
# rather than its exact text. GH-67.
#
# The exact fingerprint (djb2 over the whole tool input) catches byte-identical
# repetition and nothing else. An agent that is stuck usually is not repeating
# bytes: it retries the same intent with another path, another pattern, another
# flag. That produces a different exact fingerprint every time, which is why
# counting DISTINCT fingerprints cannot separate circling from ordinary varied
# work -- measured, both are "all distinct".
#
# A coarse bin collides where the intent is the same shape, so repetition becomes
# countable again. Measured over one real session, per turn: 11x grep, 5x sed,
# 4x, 3x, 2x -- a spread, where session-wide concentration was 98.7% for every
# turn and told nothing.
#
# `scripts/session-events.sh` carries its own copy of this logic, deliberately
# not refactored here: it is a large file with a large suite, and the risk of
# touching it outweighs the duplication. `scripts/test-bin-of.jq.sh` pins the two
# against the same fixtures instead, so a drift fails loudly rather than making
# /inspect and the loop index quietly disagree about what a repeat is.

# Hosts whose first argument carries the real verb. `gh` alone cannot tell
# filing a ticket from reading one, and that ambiguity once blocked the very
# measurement the label existed for.
def subcmd_hosts:
  [ "git", "gh", "make", "cargo", "npm", "yarn", "pnpm", "go", "docker", "jq" ];

def subcmds:
  [ "status", "commit", "push", "pull", "fetch", "merge", "rebase", "checkout",
    "switch", "branch", "diff", "log", "add", "show", "stash", "tag", "remote",
    "init", "clone", "restore", "worktree", "revert", "cherry-pick", "blame",
    "issue", "pr", "repo", "api", "release", "run", "auth", "workflow",
    "create", "list", "view", "edit", "close", "reopen", "comment", "ready",
    "build", "test", "lint", "fmt", "check", "install", "start", "publish",
    "clippy", "doc", "bench", "update", "upgrade", "clean", "compose" ];

# Input: the command STRING. Output: the bin.
#
# A leading VAR=value assignment is stripped rather than taken as the binary --
# otherwise `FOO=1 pytest` bins as `FOO=1` and never groups with `pytest`. The
# character-class test keeps a path, a quote or a pipeline fragment from becoming
# a bin of its own: anything that does not look like a plain command name is
# `(other)`, which groups the unclassifiable together instead of scattering it
# into singletons that can never reach a threshold.
def bin_of:
  ( (. // "") | split(" ") | map(select(length > 0))
    | ( reduce .[] as $tok ({done: false, rest: []};
          if .done then .rest += [$tok]
          elif ($tok | test("^[A-Za-z_][A-Za-z0-9_]*=")) then .
          else .done = true | .rest += [$tok] end ) ).rest ) as $toks
  | ( ($toks[0] // "") | sub("^\\./"; "") ) as $cmd
  | if ($cmd | test("^[A-Za-z0-9][A-Za-z0-9._+-]{0,23}$") | not) then "(other)"
    elif ($cmd | IN(subcmd_hosts[])) then
      ( [ $cmd ] + ( $toks[1:3] | map(select(IN(subcmds[]))) ) ) | join(" ")
    else $cmd end;

# A non-Bash tool has no command line, so its own name IS its shape: two Reads
# of different files are the same kind of act, which is exactly what the coarse
# stage wants to count.
def bin_for(toolname):
  if toolname == "Bash" then ((.command // "") | bin_of)
  elif toolname == "Agent" then ("Agent " + (.subagent_type // "default"))
  elif toolname == "Skill" then ("Skill " + (.skill // "?"))
  else toolname end;
