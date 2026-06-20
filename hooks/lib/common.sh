# hooks/lib/common.sh — shared helpers for the sdlc PreToolUse hooks.
#
# Sourced by hooks/pre-edit.sh and hooks/pre-bash.sh. Provides stdin/JSON
# parsing, machine-config lookup, and the allow()/deny() verdict helpers.
#
# DESIGN: fail open. Any internal problem (missing jq, unreadable config,
# git errors) must let the tool call through, never block it. The guards are
# belt-and-suspenders over .gitignore + good behavior, not a security boundary.
# So callers run WITHOUT `set -e`, and helpers default to "allow / no opinion".

# Machine-specific config. Overridable for tests via SDLC_HOOKS_CONFIG.
CONFIG_FILE="${SDLC_HOOKS_CONFIG:-$HOME/.claude/sdlc-hooks.config.json}"

# Read the hook's stdin JSON once into $INPUT.
read_input() { INPUT="$(cat)"; }

require_jq() { command -v jq >/dev/null 2>&1; }

# hook_field <jq-path> — echo a field from the hook stdin JSON, or empty.
hook_field() { printf '%s' "${INPUT:-}" | jq -r "$1 // empty" 2>/dev/null; }

# config_get <jq-path> <default> — scalar from the machine config, or default.
# Uses an explicit null check (NOT `// default`) so a legitimate `false` value
# is returned as "false" rather than being treated as absent.
config_get() {
  local v=""
  if [ -f "$CONFIG_FILE" ]; then
    v="$(jq -r "if ($1) == null then \"\" else ($1) end" "$CONFIG_FILE" 2>/dev/null)"
  fi
  if [ -z "$v" ]; then printf '%s' "$2"; else printf '%s' "$v"; fi
}

# config_array <jq-path> — newline-separated array elements (empty if none).
config_array() {
  [ -f "$CONFIG_FILE" ] && jq -r "$1[]? // empty" "$CONFIG_FILE" 2>/dev/null
}

# bypassed <env-var-name> — true if that env var is set non-empty in the
# hook's environment (the per-session escape hatch).
bypassed() {
  local name="$1"
  [ -n "$name" ] && [ -n "${!name:-}" ]
}

# allow — exit cleanly with no verdict (lets the tool call proceed).
allow() { exit 0; }

# deny <reason> — block the tool call. Emits the PreToolUse deny JSON; the
# reason is shown to the model so it can adapt.
deny() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# ask <reason> — surface the normal permission prompt for this tool call, so
# the user approves or denies it. Softer than deny(): the reason states the
# preference; the user decides per-instance.
ask() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

# deepest_existing_dir <path> — nearest existing ancestor directory of a path
# (the file itself may not exist yet, e.g. a Write to a new file).
deepest_existing_dir() {
  local p; p="$(dirname "$1")"
  while [ ! -d "$p" ] && [ "$p" != "/" ]; do p="$(dirname "$p")"; done
  printf '%s' "$p"
}

# git_main_worktree <dir> — exit 0 if <dir> is inside the MAIN worktree of a
# git repo, 1 if inside a LINKED worktree, 2 if not a git repo / on error.
# Distinguishes via git's own truth: in the main worktree the absolute git dir
# equals the common git dir; in a linked worktree they differ.
git_main_worktree() {
  local dir="$1" gd gcd
  gd="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)" || return 2
  [ -n "$gd" ] || return 2
  gcd="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 2
  case "$gcd" in
    /*) : ;;                                   # already absolute
    *)  gcd="$(cd "$dir" && cd "$gcd" 2>/dev/null && pwd -P)" || return 2 ;;
  esac
  # Canonicalize both to physical paths so a symlinked ancestor (e.g. macOS
  # /var -> /private/var) doesn't make a main checkout look like a linked one.
  gd="$(cd "$gd" 2>/dev/null && pwd -P)" || return 2
  case "$gcd" in
    /*) gcd="$(cd "$gcd" 2>/dev/null && pwd -P)" || return 2 ;;
  esac
  [ "$gd" = "$gcd" ]
}

# repo_toplevel <dir> — absolute repo root for <dir>, or empty if not a repo.
repo_toplevel() { git -C "$1" rev-parse --show-toplevel 2>/dev/null; }

# under_root <path> <root> — true if <path> is <root> or below it.
under_root() {
  local p="$1" root="${2%/}"
  [ "$p" = "$root" ] || case "$p" in "$root"/*) return 0 ;; *) return 1 ;; esac
}

# glob_match <basename> <pattern> — true if basename matches the (unquoted) glob.
glob_match() {
  local base="$1" pat="$2"
  [[ "$base" == $pat ]]
}

# repo_in_scope <repo-toplevel> — true if the worktree guard should apply to
# this repo. Scoping model:
#   - .worktree_guard.exempt_repos always wins (never guarded).
#   - if .worktree_guard.shared_repos is NON-EMPTY, only those repos are guarded
#     (allowlist mode — match by basename OR absolute path).
#   - otherwise, ALL repos under projects_root are guarded (broad mode).
# Match a repo by its basename or its absolute toplevel path.
repo_in_scope() {
  local repo="$1" name; name="$(basename "$repo")"
  local item
  while IFS= read -r item; do
    [ -n "$item" ] && { [ "$item" = "$name" ] || [ "$item" = "$repo" ]; } && return 1
  done < <(config_array '.worktree_guard.exempt_repos')

  local has_shared=0
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    has_shared=1
    { [ "$item" = "$name" ] || [ "$item" = "$repo" ]; } && return 0
  done < <(config_array '.worktree_guard.shared_repos')

  [ "$has_shared" -eq 1 ] && return 1   # allowlist given, this repo not in it
  return 0                              # broad mode: all repos in scope
}

# is_git_commit <command> — true if the command runs `git ... commit` (commit
# as the git subcommand). Handles `git commit`, `git -C dir commit`, flags, etc.
# Avoids false positives like `git log` or `git commitfoo`.
is_git_commit() {
  printf '%s' "$1" | grep -Eq '(^|[^[:alnum:]_/.-])git[[:space:]]+([^|;&]*[[:space:]])?commit([[:space:]]|$|[;|&])'
}

# has_commit_all_flag <command> — true if a `-a`/`--all` style flag is present
# (so `git commit` would also record tracked-but-unstaged changes).
has_commit_all_flag() {
  printf '%s' "$1" | grep -Eq '[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)'
}

# expand_tilde <path> — echo <path> with a leading `~` / `~/` expanded to
# $HOME. `~user` and `$VAR` forms are left untouched by design — a static
# parser can't expand them — so callers fall through to the conservative
# cwd-based decision.
expand_tilde() {
  case "$1" in
    "~")   printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *)     printf '%s' "$1" ;;
  esac
}

# git_effective_dir <command> <cwd> — the directory git would operate in:
# a leading `cd <dir> &&|;` shifts the working directory before git runs, and
# the last `-C <dir>` argument (resolved against that cwd if relative) wins on
# top. Falls back to cwd otherwise. Handles unquoted, "double"-, and
# 'single'-quoted paths; ~ expands, $VAR / ~user stay conservative.
git_effective_dir() {
  local cmd="$1" cwd="$2" cddir cdir

  # A *leading* `cd <dir> &&|;` becomes git's working directory (so a natural
  # `cd ~/repo-wt && git commit`, with no -C, isn't read against the original
  # cwd and false-denied). Only the leading position matters — a cd after the
  # git command can't affect it. An absolute / ~-expanded target replaces cwd;
  # a relative one resolves under cwd; $VAR / ~user stay conservative.
  cddir="$(printf '%s' "$cmd" \
    | grep -oE '^[[:space:]]*cd[[:space:]]+("[^"]+"|'\''[^'\'']+'\''|[^[:space:]]+)[[:space:]]*(&&|;)' \
    | head -1 \
    | sed -E 's/^[[:space:]]*cd[[:space:]]+//; s/[[:space:]]*(&&|;)[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')"
  if [ -n "$cddir" ]; then
    cddir="$(expand_tilde "$cddir")"
    case "$cddir" in /*) cwd="$cddir" ;; *) cwd="$cwd/$cddir" ;; esac
  fi

  cdir="$(printf '%s' "$cmd" \
    | grep -oE '(^|[[:space:]])-C[[:space:]]+("[^"]+"|'\''[^'\'']+'\''|[^[:space:]]+)' \
    | tail -1 \
    | sed -E 's/^[[:space:]]*-C[[:space:]]+//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')"
  if [ -n "$cdir" ]; then
    # Expand a leading ~ / ~/ so a natural `git -C ~/path commit` resolves to
    # the real (worktree) path instead of being read as a dir under cwd and
    # false-denied. ~user / $VAR stay conservative (see expand_tilde).
    cdir="$(expand_tilde "$cdir")"
    case "$cdir" in /*) printf '%s' "$cdir" ;; *) printf '%s/%s' "$cwd" "$cdir" ;; esac
  else
    printf '%s' "$cwd"
  fi
}

# git_dir_arg_unexpandable <command> — true if a `-C` or leading `cd`
# directory argument contains a shell variable ($VAR) or a ~user form that a
# static parser can't expand. In that case git_effective_dir falls back to the
# cwd-based decision, so a worktree-targeted commit may be denied; the deny
# message uses this to tell the operator to re-run with a literal path.
git_dir_arg_unexpandable() {
  printf '%s' "$1" \
    | grep -Eq "(^|[[:space:]])(-C|cd)[[:space:]]+[\"']?(\\\$|~[^/[:space:]\"'])"
}
