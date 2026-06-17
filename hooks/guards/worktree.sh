# hooks/guards/worktree.sh — enforce worktree-per-task on shared checkouts.
#
# guard_worktree:        blocks Edit/Write/NotebookEdit to a guarded repo's
#                        MAIN checkout (use a linked worktree).
# guard_commit_in_main:  blocks `git commit` run against a guarded repo's MAIN
#                        checkout (so work can't land on the shared tree's
#                        branch). The 2026-06-14 incident — feature commits
#                        swept onto main in the shared ~/Projects/Infra
#                        checkout — is exactly this.
#
# "Guarded" = under projects_root AND in scope per repo_in_scope() (which
# honors .worktree_guard.shared_repos allowlist / exempt_repos). Requires
# lib/common.sh sourced first.

# Recipe shown in deny reasons.
_wt_recipe() {
  local repo="$1"
  printf 'git -C %q worktree add %q-<task> -b <type>/<name> origin/main' "$repo" "$repo"
}

guard_worktree() {
  [ "$(config_get '.worktree_guard.enabled' 'true')" = "true" ] || return 0

  local fp; fp="$(hook_field '.tool_input.file_path')"
  [ -z "$fp" ] && fp="$(hook_field '.tool_input.notebook_path')"
  [ -z "$fp" ] && return 0
  case "$fp" in /*) : ;; *) return 0 ;; esac   # only reason about absolute paths

  local bypass; bypass="$(config_get '.worktree_guard.bypass_env' 'CLAUDE_ALLOW_MAIN_EDITS')"
  bypassed "$bypass" && return 0

  local root; root="$(config_get '.worktree_guard.projects_root' "$HOME/Projects")"
  under_root "$fp" "$root" || return 0

  local dir; dir="$(deepest_existing_dir "$fp")"
  local repo; repo="$(repo_toplevel "$dir")"
  [ -z "$repo" ] && return 0                    # not a git repo → can't worktree it
  repo_in_scope "$repo" || return 0

  if git_main_worktree "$dir"; then
    deny "Refusing to edit '$fp' in the MAIN checkout of $repo. This checkout can be shared by concurrent sessions; edit in a dedicated git worktree instead:

    $(_wt_recipe "$repo")
    # then edit via the worktree path: ${repo}-<task>/...

To override for this session, set ${bypass}=1 before launching Claude (or in settings.json env)."
  fi
  return 0
}

guard_commit_in_main() {
  [ "$(config_get '.worktree_guard.enabled' 'true')" = "true" ] || return 0
  [ "$(config_get '.worktree_guard.block_commits_in_main' 'true')" = "true" ] || return 0

  local cmd; cmd="$(hook_field '.tool_input.command')"
  [ -z "$cmd" ] && return 0
  is_git_commit "$cmd" || return 0

  local bypass; bypass="$(config_get '.worktree_guard.bypass_env' 'CLAUDE_ALLOW_MAIN_EDITS')"
  bypassed "$bypass" && return 0

  local cwd; cwd="$(hook_field '.cwd')"
  [ -z "$cwd" ] && return 0
  case "$cwd" in /*) : ;; *) return 0 ;; esac

  # Honor `git -C <dir>` — the commit may target a repo other than cwd.
  local gdir; gdir="$(git_effective_dir "$cmd" "$cwd")"
  gdir="$(deepest_existing_dir "$gdir/.")"

  local root; root="$(config_get '.worktree_guard.projects_root' "$HOME/Projects")"
  under_root "$gdir" "$root" || return 0

  local repo; repo="$(repo_toplevel "$gdir")"
  [ -z "$repo" ] && return 0
  repo_in_scope "$repo" || return 0

  if git_main_worktree "$gdir"; then
    local hint=""
    if git_dir_arg_unexpandable "$cmd"; then
      hint="

Note: the commit's directory argument used a shell variable or ~user (e.g. \`git -C \"\$WT\"\` or \`cd \"\$WT\" &&\`), which this guard cannot expand before the command runs — so it fell back to THIS checkout. If you are in fact committing in a worktree, re-run with a literal absolute path (or ~/path), e.g. \`git -C ${repo}-<task> commit ...\`."
    fi
    deny "Refusing to 'git commit' into the MAIN checkout of $repo. Commit from a dedicated worktree so work can't land on the shared tree's branch:

    $(_wt_recipe "$repo")${hint}

To override, set ${bypass}=1 before launching Claude (or in settings.json env), or disable .worktree_guard.block_commits_in_main in the hooks config."
  fi
  return 0
}
