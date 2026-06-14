#!/usr/bin/env bash
# hooks/pre-edit.sh — PreToolUse hook for Edit|Write|NotebookEdit.
# Enforces worktree-per-task: blocks edits to a repo's main checkout under
# the configured projects_root. See hooks/README.md.
#
# Fail-open: never block on an internal error.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"

read_input
require_jq || { echo "[sdlc-hooks] jq not found; allowing" >&2; allow; }

source "$HERE/guards/worktree.sh"
guard_worktree

allow
