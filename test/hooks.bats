#!/usr/bin/env bats
#
# Tests for hooks/pre-edit.sh and hooks/pre-bash.sh. Each test builds a
# throwaway projects_root containing a real git repo plus a linked worktree,
# and points SDLC_HOOKS_CONFIG at a test config, so the guards exercise real
# git plumbing without touching anything outside BATS_TEST_TMPDIR.
#
# Hooks always exit 0; a DENY is signalled by non-empty stdout (the PreToolUse
# deny JSON). So tests assert on $output, not $status.

setup() {
  HOOKS="$BATS_TEST_DIRNAME/../hooks"
  ROOT="$BATS_TEST_TMPDIR/p"                      # the configured projects_root
  export SDLC_HOOKS_CONFIG="$BATS_TEST_TMPDIR/cfg.json"
  mkdir -p "$ROOT" "$BATS_TEST_TMPDIR/elsewhere"

  cat > "$SDLC_HOOKS_CONFIG" <<JSON
{
  "worktree_guard": { "enabled": true, "projects_root": "$ROOT",
    "exempt_repos": ["exempt-repo"], "block_commits_in_main": true,
    "bypass_env": "CLAUDE_ALLOW_MAIN_EDITS" },
  "gh_auth_switch": { "enabled": true, "bypass_env": "CLAUDE_ALLOW_GH_SWITCH" },
  "secret_commit": { "enabled": true,
    "deny_globs": [".env", ".env.*", "*.pem", "*.key", "credentials.json"],
    "allow_globs": [".env.example"], "bypass_env": "CLAUDE_ALLOW_SECRET_COMMIT" }
}
JSON

  REPO="$ROOT/repo"; WT="$ROOT/repo-wt"
  newrepo "$REPO"
  git -C "$REPO" worktree add -q "$WT" -b wt
}

newrepo() {
  git init -q "$1"
  git -C "$1" config user.email t@t
  git -C "$1" config user.name "Test"
  git -C "$1" commit -qm init --allow-empty
}

edit_json() { jq -nc --arg p "$1" '{tool_name:"Edit",tool_input:{file_path:$p}}'; }
bash_json() { jq -nc --arg c "$1" --arg w "$2" '{tool_name:"Bash",tool_input:{command:$c},cwd:$w}'; }

# run a hook with the given JSON on stdin
edit() { printf '%s' "$(edit_json "$1")" | "$HOOKS/pre-edit.sh"; }
cmd()  { printf '%s' "$(bash_json "$1" "$2")" | "$HOOKS/pre-bash.sh"; }

# ---------------------------------------------------------------------------
# worktree guard — edits
# ---------------------------------------------------------------------------

@test "edit in a main checkout is denied" {
  run edit "$REPO/foo.txt"
  [[ -n "$output" ]]
  [[ "$output" == *'"permissionDecision":"deny"'* ]]
  [[ "$output" == *"MAIN checkout"* ]]
}

@test "edit in a linked worktree is allowed" {
  run edit "$WT/foo.txt"
  [ -z "$output" ]
}

@test "edit of a not-yet-existing file in a main checkout is denied" {
  run edit "$REPO/does/not/exist/yet.txt"
  [[ -n "$output" ]]
}

@test "edit outside projects_root is allowed" {
  run edit "$BATS_TEST_TMPDIR/elsewhere/foo.txt"
  [ -z "$output" ]
}

@test "edit in a non-git dir under projects_root is allowed" {
  mkdir -p "$ROOT/plain"
  run edit "$ROOT/plain/foo.txt"
  [ -z "$output" ]
}

@test "edit in an exempt repo is allowed" {
  newrepo "$ROOT/exempt-repo"
  run edit "$ROOT/exempt-repo/foo.txt"
  [ -z "$output" ]
}

@test "bypass env allows editing a main checkout" {
  CLAUDE_ALLOW_MAIN_EDITS=1 run edit "$REPO/foo.txt"
  [ -z "$output" ]
}

@test "NotebookEdit on a main checkout is denied" {
  run bash -c 'printf "%s" "$(jq -nc --arg p "$1" "{tool_name:\"NotebookEdit\",tool_input:{notebook_path:\$p}}")" | "$2/pre-edit.sh"' _ "$REPO/nb.ipynb" "$HOOKS"
  [[ -n "$output" ]]
}

@test "disabled worktree_guard allows a main-checkout edit" {
  jq '.worktree_guard.enabled = false' "$SDLC_HOOKS_CONFIG" > "$SDLC_HOOKS_CONFIG.t" && mv "$SDLC_HOOKS_CONFIG.t" "$SDLC_HOOKS_CONFIG"
  run edit "$REPO/foo.txt"
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# worktree guard — commits
# ---------------------------------------------------------------------------

@test "git commit from a main checkout is denied" {
  run cmd "git commit -m x" "$REPO"
  [[ -n "$output" ]]
  [[ "$output" == *"MAIN checkout"* ]]
}

@test "git -C <main> commit from elsewhere is denied (honors -C)" {
  run cmd "git -C $REPO commit -m x" "$ROOT"
  [[ -n "$output" ]]
}

@test "git commit from a linked worktree is allowed" {
  run cmd "git commit -m x" "$WT"
  [ -z "$output" ]
}

@test "git -C <worktree> commit is allowed" {
  run cmd "git -C $WT commit -m x" "$BATS_TEST_TMPDIR/elsewhere"
  [ -z "$output" ]
}

@test "git log from a main checkout is allowed (not a commit)" {
  run cmd "git log --oneline" "$REPO"
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# gh auth switch guard
# ---------------------------------------------------------------------------

@test "gh auth switch is denied" {
  run cmd "gh auth switch -u someone" "$WT"
  [[ -n "$output" ]]
  [[ "$output" == *"gh auth switch"* ]]
}

@test "gh auth status is allowed" {
  run cmd "gh auth status" "$WT"
  [ -z "$output" ]
}

@test "gh auth switch with bypass env is allowed" {
  CLAUDE_ALLOW_GH_SWITCH=1 run cmd "gh auth switch -u someone" "$WT"
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# secret-commit guard (committed from a worktree so the wt-guard allows it)
# ---------------------------------------------------------------------------

@test "committing a staged .env is denied" {
  printf 'SECRET=1\n' > "$WT/.env"; git -C "$WT" add -f .env
  run cmd "git commit -m x" "$WT"
  [[ -n "$output" ]]
  [[ "$output" == *".env"* ]]
}

@test "committing a staged *.pem is denied" {
  printf 'KEY\n' > "$WT/server.pem"; git -C "$WT" add -f server.pem
  run cmd "git commit -m x" "$WT"
  [[ -n "$output" ]]
}

@test "committing only .env.example is allowed" {
  printf 'EXAMPLE=1\n' > "$WT/.env.example"; git -C "$WT" add -f .env.example
  run cmd "git commit -m x" "$WT"
  [ -z "$output" ]
}

@test "committing an encrypted vault.yml is allowed (not in deny set)" {
  printf '\$ANSIBLE_VAULT;1.1;AES256\n' > "$WT/vault.yml"; git -C "$WT" add -f vault.yml
  run cmd "git commit -m x" "$WT"
  [ -z "$output" ]
}

@test "secret commit with bypass env is allowed" {
  printf 'SECRET=1\n' > "$WT/.env"; git -C "$WT" add -f .env
  CLAUDE_ALLOW_SECRET_COMMIT=1 run cmd "git commit -m x" "$WT"
  [ -z "$output" ]
}

@test "allowlist mode: a repo NOT in shared_repos is allowed in its main checkout" {
  jq '.worktree_guard.shared_repos = ["some-other-repo"]' "$SDLC_HOOKS_CONFIG" > "$SDLC_HOOKS_CONFIG.t" && mv "$SDLC_HOOKS_CONFIG.t" "$SDLC_HOOKS_CONFIG"
  run edit "$REPO/foo.txt"
  [ -z "$output" ]
}

@test "allowlist mode: a repo IN shared_repos is denied in its main checkout" {
  jq '.worktree_guard.shared_repos = ["repo"]' "$SDLC_HOOKS_CONFIG" > "$SDLC_HOOKS_CONFIG.t" && mv "$SDLC_HOOKS_CONFIG.t" "$SDLC_HOOKS_CONFIG"
  run edit "$REPO/foo.txt"
  [[ -n "$output" ]]
}

# ---------------------------------------------------------------------------
# git-native pre-commit (catches a human's manual commit too)
# ---------------------------------------------------------------------------

@test "git pre-commit blocks a staged secret" {
  printf 'SECRET=1\n' > "$WT/.env"; git -C "$WT" add -f .env
  run bash -c 'cd "$1" && "$2/git/pre-commit"' _ "$WT" "$HOOKS"
  [ "$status" -eq 1 ]
  [[ "$output" == *".env"* ]]
}

@test "git pre-commit allows a clean commit" {
  printf 'ok\n' > "$WT/notes.txt"; git -C "$WT" add notes.txt
  run bash -c 'cd "$1" && "$2/git/pre-commit"' _ "$WT" "$HOOKS"
  [ "$status" -eq 0 ]
}

@test "git pre-commit allows a secret with the bypass env" {
  printf 'SECRET=1\n' > "$WT/.env"; git -C "$WT" add -f .env
  run bash -c 'cd "$1" && CLAUDE_ALLOW_SECRET_COMMIT=1 "$2/git/pre-commit"' _ "$WT" "$HOOKS"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# fail-open
# ---------------------------------------------------------------------------

@test "missing config does not crash and allows (defaults out of test root)" {
  rm -f "$SDLC_HOOKS_CONFIG"
  run edit "$BATS_TEST_TMPDIR/elsewhere/foo.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "malformed config does not crash the hook" {
  printf 'not json {{{' > "$SDLC_HOOKS_CONFIG"
  run cmd "gh auth status" "$WT"
  [ "$status" -eq 0 ]
}
