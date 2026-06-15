#!/usr/bin/env bash
# hooks/pre-bash.sh — PreToolUse hook for Bash.
# Runs the Bash-facing guards in order; the first to deny wins. See README.
#
# Fail-open: never block on an internal error.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"

read_input
require_jq || { echo "[sdlc-hooks] jq not found; allowing" >&2; allow; }

source "$HERE/guards/ssh.sh"
source "$HERE/guards/gh_auth_switch.sh"
source "$HERE/guards/secret_commit.sh"
source "$HERE/guards/worktree.sh"

guard_ssh                   # block raw `ssh` (use Ansible/ap instead)
guard_gh_auth_switch        # block global gh account flip
guard_commit_in_main        # block `git commit` from a shared main checkout
guard_secret_commit         # block committing secret files

allow
