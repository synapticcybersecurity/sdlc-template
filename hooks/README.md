# sdlc hooks — harness-enforced engineering directives

`PreToolUse` hooks that turn the *mechanizable* CLAUDE.md directives from
"documented" into "the harness blocks it." Hooks are run by Claude Code itself
(not the model), so a denial is real enforcement, not a suggestion.

The logic lives here (version-controlled, bats-tested). Each machine wires it
in once at **user scope** (`~/.claude/settings.json`) and supplies its own
parameters via `~/.claude/sdlc-hooks.config.json`.

## What it enforces

| Guard | Tool(s) | Action |
|-------|---------|--------|
| **worktree** | Edit/Write/NotebookEdit | **deny** — editing a repo's **main checkout** under `projects_root`; use a linked `git worktree`. |
| **commit-in-main** | Bash | **deny** — `git commit` from a **main checkout** (so work can't land on the shared tree's branch; the 2026-06-14 incident). |
| **gh-auth-switch** | Bash | **deny** — `gh auth switch` (flips the global, session-shared gh account). Use a scoped token. |
| **ssh** | Bash | **ask** — raw `ssh` prompts to prefer Ansible (the `ap` wrapper); approve genuine ssh. |
| **secret-commit** | Bash | **deny** — `git commit` recording `.env` / `*.pem` / `*.key` / `credentials.json` / … |

Not enforced here (already native or not mechanizable): no-AI-attribution is
handled by settings.json `attribution`; process directives (one-concern-per-
change, finish-the-unit, run-tests-before-done, …) stay as prose in CLAUDE.md.

## How a guard decides "main checkout vs worktree"

By git's own truth, not directory naming: in a repo's **main** worktree the
absolute git dir equals the common git dir; in a **linked** worktree they
differ. So any `git worktree add` sibling is allowed and the primary checkout
is blocked — no dependence on a `<repo>-<task>` naming convention.

For the **commit-in-main** guard the target directory is read from the command
before it runs: a leading `cd <dir> &&|;` and the last `git -C <dir>` are both
honored (so `cd ~/repo-wt && git commit` and `git -C ~/repo-wt commit` resolve
to the worktree). A `$VAR` or `~user` path can't be expanded by a static
pre-exec parser, so it falls back to the cwd-based decision (conservative — may
deny); the deny message says to re-run with a **literal** path in that case.
Prefer a literal absolute path (or `~/…`) over a shell variable when committing
from a worktree.

## Design guarantees

- **Fail-open.** Missing `jq`, unreadable config, or any git error → the tool
  call is allowed. A guard bug must never brick a session.
- **Bypass per guard.** Set the guard's `bypass_env` (e.g. `CLAUDE_ALLOW_MAIN_EDITS=1`)
  before launching Claude, or add it to settings.json `env`, to override.
- **Scoped matchers.** Bash guards never run on edit events and vice-versa.

## Install (per machine)

1. Copy the config and edit `projects_root`:
   ```bash
   cp ~/Projects/sdlc_template/hooks/hooks.config.example.json ~/.claude/sdlc-hooks.config.json
   # edit projects_root to your home Projects dir
   ```
2. Add to `~/.claude/settings.json` (merges with existing `permissions`/`attribution`):
   ```json
   {
     "hooks": {
       "PreToolUse": [
         { "matcher": "Edit|Write|NotebookEdit",
           "hooks": [{ "type": "command", "command": "/ABS/PATH/sdlc_template/hooks/pre-edit.sh" }] },
         { "matcher": "Bash",
           "hooks": [{ "type": "command", "command": "/ABS/PATH/sdlc_template/hooks/pre-bash.sh" }] }
       ]
     },
     "env": { "OBJC_DISABLE_INITIALIZE_FORK_SAFETY": "YES", "no_proxy": "*" }
   }
   ```
   The `command` field needs an **absolute** path (no `~` expansion). The `env`
   block is the macOS Ansible/Pulumi fork-safety fix — drop it on Linux, and
   note `no_proxy=*` only matters behind a proxy.

## Scoping the worktree guard

Most people run concurrent sessions in only a few checkouts, so the guard
supports an **allowlist**:

- `worktree_guard.shared_repos` **non-empty** → only those repos are guarded
  (match by basename or absolute path). Recommended: list just the checkouts
  you actually share (e.g. `["Infra"]`). Every other repo stays frictionless.
- `shared_repos` **empty** → broad mode: every repo under `projects_root` is
  guarded, minus `exempt_repos`.

The guard (and the friction of working in worktrees) only buys safety where
concurrent sessions share a tree — so prefer the allowlist unless you genuinely
run parallel sessions everywhere.

## Companion launcher

`bin/cw` creates a per-task worktree off a guarded repo **and** gives the new
Claude session its own `GH_CONFIG_DIR`, so `gh auth switch` can't leak across
sessions. It makes the compliant path the easy path:

    cw feature/42-thing          # from inside the repo; opens Claude in <repo>-thing

Worktrees aren't auto-removed — a finished task's sibling dir lingers and
clutters `projects_root` until you clean it up. When a branch is merged:

    git -C <repo> worktree remove <repo>-<task>   # drop the dir
    git -C <repo> worktree prune                  # clear stale admin entries

`worktree remove` refuses if the tree is dirty; commit/stash or `--force` first.

## Config reference

See `hooks.config.example.json`. Keys: `worktree_guard.{enabled,projects_root,
shared_repos[],exempt_repos[],block_commits_in_main,bypass_env}`,
`gh_auth_switch.{enabled,bypass_env}`, `ssh_guard.{enabled,bypass_env}`,
`secret_commit.{enabled,deny_globs[],allow_globs[],bypass_env}`.

## Known gaps

- Edit guard covers Edit/Write/NotebookEdit, not arbitrary Bash file writes
  (`sed -i`, `>`). Defense-in-depth, not airtight.
- Secret guard catches Claude's commits, not a human's manual `git commit`
  (a git-native `core.hooksPath` pre-commit would; future hardening).

## Tests

`cd ~/Projects/sdlc_template && ./test/bats/bin/bats test/hooks.bats`
