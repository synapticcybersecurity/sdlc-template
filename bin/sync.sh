#!/usr/bin/env bash
# bin/sync.sh — bootstrap projects from this template and detect drift.
#
# Subcommands:
#   init <project-path> --stack=<typescript|python|go> [--force]
#       Copy .github/ and the chosen stack template into the project.
#       Writes .sdlc-template-version with the current template repo HEAD.
#
#   check <project-path> [--diff]
#       Compare a project's templated files against the template repo at
#       (a) the SHA it was bootstrapped from, and (b) the current HEAD.
#       Reports local drift (project changed templated files), upstream
#       drift (template moved on since bootstrap), and files deleted from
#       the template upstream that the project still carries.
#
#   update <project-path> [--force]
#       Re-sync a bootstrapped project to the current template HEAD.
#       Files with no local edits are updated in place; files the project
#       has edited are left untouched and reported for manual merge unless
#       --force is given. Files deleted upstream are removed (if unedited).
#       Rewrites .sdlc-template-version to the new HEAD.
#
# Notes:
# - "Templated files" means everything under .github/ and docs/, plus the
#   project's CLAUDE.md (compared against the stack template recorded at
#   bootstrap). Consumer-owned paths (docs/prds/, docs/adrs/) are never
#   touched.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand> [args]

Subcommands:
  init <project-path> --stack=<typescript|python|go> [--force]
      Bootstrap a project from this template.

  check <project-path> [--diff]
      Compare a bootstrapped project against the template. Exit non-zero
      if any drift is found. Use --diff to print unified diffs.

  update <project-path> [--force]
      Re-sync a bootstrapped project to the current template HEAD.
      Locally-edited files are skipped (reported) unless --force.

Examples:
  $(basename "$0") init ~/Projects/myapp --stack=typescript
  $(basename "$0") check ~/Projects/myapp --diff
  $(basename "$0") update ~/Projects/myapp
EOF
}

die() { echo "error: $*" >&2; exit 1; }

require_clean_template_repo() {
  if ! git -C "$REPO_ROOT" diff --quiet HEAD 2>/dev/null; then
    echo "warning: template repo has uncommitted changes — the recorded SHA will not reflect the actual bootstrap content" >&2
  fi
}

# Echo the repo-relative paths of every templated file present at a git ref:
# everything under .github/ and docs/, plus the stack template at repo root.
# Usage: templated_files_at_ref <ref> <stack_template_rel>
templated_files_at_ref() {
  local ref="$1" stack_rel="$2"
  git -C "$REPO_ROOT" ls-tree -r --name-only "$ref" -- .github docs | sort
  if git -C "$REPO_ROOT" cat-file -e "$ref:$stack_rel" 2>/dev/null; then
    echo "$stack_rel"
  fi
}

# Map a template-repo-relative path to its path inside a bootstrapped project.
# The stack template lands as CLAUDE.md; everything else keeps its path.
# Usage: project_rel_path <repo_rel_path> <stack_template_rel>
project_rel_path() {
  if [[ "$1" == "$2" ]]; then echo "CLAUDE.md"; else echo "$1"; fi
}

# True if <needle> appears in the remaining args (exact line match).
# Usage: list_contains <needle> "${list[@]}"
list_contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

cmd_init() {
  local target="" stack="" force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack=*) stack="${1#--stack=}";;
      --force)   force=1;;
      -h|--help) usage; exit 0;;
      -*)        die "unknown flag: $1";;
      *)         if [[ -z "$target" ]]; then target="$1"; else die "unexpected argument: $1"; fi;;
    esac
    shift
  done

  [[ -n "$target" ]] || die "init requires a project path"
  [[ -n "$stack"  ]] || die "init requires --stack=<typescript|python|go>"
  [[ -d "$target" ]] || die "target directory does not exist: $target"

  local stack_template="$REPO_ROOT/project-claude-template-${stack}.md"
  [[ -f "$stack_template" ]] || die "no template for stack '$stack' (expected $stack_template)"

  if [[ "$force" -eq 0 ]]; then
    [[ -e "$target/.github" ]]                && die "$target/.github exists (use --force to overwrite, or run 'check')"
    [[ -e "$target/CLAUDE.md" ]]              && die "$target/CLAUDE.md exists (use --force to overwrite)"
    [[ -e "$target/.sdlc-template-version" ]] && die "$target/.sdlc-template-version exists — project is already bootstrapped (use --force to re-bootstrap)"
    while IFS= read -r f; do
      [[ -e "$target/$f" ]] && die "$target/$f exists (use --force to overwrite)"
    done < <(git -C "$REPO_ROOT" ls-tree -r --name-only HEAD -- docs)
  fi

  require_clean_template_repo

  echo "Copying .github/ -> $target/.github/"
  rm -rf "$target/.github"
  cp -R "$REPO_ROOT/.github" "$target/.github"

  echo "Copying $(basename "$stack_template") -> $target/CLAUDE.md"
  cp "$stack_template" "$target/CLAUDE.md"

  echo "Copying docs scaffolding -> $target/docs/"
  # Enumerate every docs/ path committed at HEAD and copy each into the
  # project. Consumer-owned dirs like docs/prds/ and docs/adrs/ are not in
  # HEAD's docs/ tree, so they are never touched — even on --force.
  while IFS= read -r f; do
    rm -f "$target/$f"
    mkdir -p "$(dirname "$target/$f")"
    cp "$REPO_ROOT/$f" "$target/$f"
  done < <(git -C "$REPO_ROOT" ls-tree -r --name-only HEAD -- docs)

  local sha
  sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  cat > "$target/.sdlc-template-version" <<EOF
# Generated by sdlc_template/bin/sync.sh — do not edit by hand.
# Re-run 'sync.sh init --force' to re-bootstrap.
stack=$stack
sha=$sha
EOF

  echo
  echo "Bootstrapped $target from sdlc_template @ ${sha:0:7} (stack=$stack)"
  echo "Next: edit $target/CLAUDE.md and fill in the Project Architecture section."
}

cmd_check() {
  local target="" diff_mode=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --diff)    diff_mode=1;;
      -h|--help) usage; exit 0;;
      -*)        die "unknown flag: $1";;
      *)         if [[ -z "$target" ]]; then target="$1"; else die "unexpected argument: $1"; fi;;
    esac
    shift
  done

  [[ -n "$target" ]] || die "check requires a project path"
  [[ -d "$target" ]] || die "target directory does not exist: $target"

  local version_file="$target/.sdlc-template-version"
  [[ -f "$version_file" ]] || die "$target has no .sdlc-template-version (was it bootstrapped from this template?)"

  local stack bootstrap_sha
  stack="$(grep '^stack=' "$version_file" | head -1 | cut -d= -f2-)"
  bootstrap_sha="$(grep '^sha=' "$version_file" | head -1 | cut -d= -f2-)"
  [[ -n "$stack" && -n "$bootstrap_sha" ]] || die "could not parse stack/sha from $version_file"

  local current_sha
  current_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"

  echo "Project:           $target"
  echo "Stack:             $stack"
  echo "Bootstrapped from: ${bootstrap_sha:0:7}"
  echo "Template HEAD:     ${current_sha:0:7}"
  echo

  local stack_template_rel="project-claude-template-${stack}.md"
  local exit_code=0

  # Templated files at the current HEAD and at the bootstrap SHA (committed
  # states only). Consumer-owned paths (docs/prds/, docs/adrs/, anything
  # outside .github/ and docs/) are not enumerated, so never checked.
  local current_files=() bootstrap_files=()
  while IFS= read -r f; do [[ -n "$f" ]] && current_files+=("$f"); done \
    < <(templated_files_at_ref "$current_sha" "$stack_template_rel")
  while IFS= read -r f; do [[ -n "$f" ]] && bootstrap_files+=("$f"); done \
    < <(templated_files_at_ref "$bootstrap_sha" "$stack_template_rel")

  local f rel_in_project tmpl_blob_current tmpl_blob_bootstrap proj_path proj_content
  for f in "${current_files[@]}"; do
    rel_in_project="$(project_rel_path "$f" "$stack_template_rel")"
    proj_path="$target/$rel_in_project"

    if [[ ! -e "$proj_path" ]]; then
      printf '%-16s %s\n' "MISSING" "$rel_in_project (template has it; project does not)"
      exit_code=1
      continue
    fi

    if git -C "$REPO_ROOT" cat-file -e "$bootstrap_sha:$f" 2>/dev/null; then
      tmpl_blob_bootstrap="$(git -C "$REPO_ROOT" show "$bootstrap_sha:$f")"
    else
      tmpl_blob_bootstrap=""   # file added upstream after this project bootstrapped
    fi
    tmpl_blob_current="$(git -C "$REPO_ROOT" show "$current_sha:$f")"
    proj_content="$(cat "$proj_path")"

    local local_drift=0 upstream_drift=0
    [[ "$proj_content" != "$tmpl_blob_bootstrap" ]] && local_drift=1
    [[ "$tmpl_blob_current" != "$tmpl_blob_bootstrap" ]] && upstream_drift=1

    if [[ $local_drift -eq 0 && $upstream_drift -eq 0 ]]; then
      printf '%-16s %s\n' "OK" "$rel_in_project"
    else
      local tags=""
      [[ $local_drift -eq 1 ]]    && tags+=" local-edits"
      [[ $upstream_drift -eq 1 ]] && tags+=" upstream-newer"
      printf '%-16s %s\n' "DRIFT" "$rel_in_project --$tags"
      exit_code=1
      if [[ $diff_mode -eq 1 ]]; then
        if [[ $local_drift -eq 1 ]]; then
          echo "  --- local edits since bootstrap (template@bootstrap vs project) ---"
          diff -u <(printf '%s' "$tmpl_blob_bootstrap") "$proj_path" || true
        fi
        if [[ $upstream_drift -eq 1 ]]; then
          echo "  --- upstream changes since bootstrap (template@bootstrap vs template@HEAD) ---"
          diff -u <(printf '%s' "$tmpl_blob_bootstrap") <(printf '%s' "$tmpl_blob_current") || true
        fi
      fi
    fi
  done

  # Upstream deletions: files present at bootstrap but gone at HEAD. If the
  # project still carries its copy, surface it so the consumer can decide
  # whether to drop it too.
  local b
  for b in "${bootstrap_files[@]}"; do
    list_contains "$b" "${current_files[@]}" && continue
    rel_in_project="$(project_rel_path "$b" "$stack_template_rel")"
    if [[ -e "$target/$rel_in_project" ]]; then
      printf '%-16s %s\n' "REMOVED-UPSTREAM" "$rel_in_project (template deleted it; project still has it)"
      exit_code=1
    fi
  done

  exit "$exit_code"
}

cmd_update() {
  local target="" force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)   force=1;;
      -h|--help) usage; exit 0;;
      -*)        die "unknown flag: $1";;
      *)         if [[ -z "$target" ]]; then target="$1"; else die "unexpected argument: $1"; fi;;
    esac
    shift
  done

  [[ -n "$target" ]] || die "update requires a project path"
  [[ -d "$target" ]] || die "target directory does not exist: $target"

  local version_file="$target/.sdlc-template-version"
  [[ -f "$version_file" ]] || die "$target has no .sdlc-template-version (run 'init' first)"

  local stack bootstrap_sha
  stack="$(grep '^stack=' "$version_file" | head -1 | cut -d= -f2-)"
  bootstrap_sha="$(grep '^sha=' "$version_file" | head -1 | cut -d= -f2-)"
  [[ -n "$stack" && -n "$bootstrap_sha" ]] || die "could not parse stack/sha from $version_file"

  require_clean_template_repo

  local current_sha
  current_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  local stack_template_rel="project-claude-template-${stack}.md"

  if [[ "$bootstrap_sha" == "$current_sha" ]]; then
    echo "Already at template HEAD (${current_sha:0:7}); nothing to update."
    return 0
  fi

  echo "Updating $target"
  echo "  stack: $stack"
  echo "  from:  ${bootstrap_sha:0:7}"
  echo "  to:    ${current_sha:0:7}"
  echo

  local current_files=() bootstrap_files=()
  while IFS= read -r f; do [[ -n "$f" ]] && current_files+=("$f"); done \
    < <(templated_files_at_ref "$current_sha" "$stack_template_rel")
  while IFS= read -r f; do [[ -n "$f" ]] && bootstrap_files+=("$f"); done \
    < <(templated_files_at_ref "$bootstrap_sha" "$stack_template_rel")

  local skipped=()
  local f rel_in_project proj_path tmpl_blob_bootstrap tmpl_blob_current proj_content

  for f in "${current_files[@]}"; do
    rel_in_project="$(project_rel_path "$f" "$stack_template_rel")"
    proj_path="$target/$rel_in_project"
    tmpl_blob_current="$(git -C "$REPO_ROOT" show "$current_sha:$f")"

    if [[ ! -e "$proj_path" ]]; then
      mkdir -p "$(dirname "$proj_path")"
      git -C "$REPO_ROOT" show "$current_sha:$f" > "$proj_path"
      printf '%-14s %s\n' "ADDED" "$rel_in_project"
      continue
    fi

    if git -C "$REPO_ROOT" cat-file -e "$bootstrap_sha:$f" 2>/dev/null; then
      tmpl_blob_bootstrap="$(git -C "$REPO_ROOT" show "$bootstrap_sha:$f")"
    else
      tmpl_blob_bootstrap=""
    fi
    proj_content="$(cat "$proj_path")"

    local local_drift=0 upstream_drift=0
    [[ "$proj_content" != "$tmpl_blob_bootstrap" ]] && local_drift=1
    [[ "$tmpl_blob_current" != "$tmpl_blob_bootstrap" ]] && upstream_drift=1

    if [[ $upstream_drift -eq 0 ]]; then
      printf '%-14s %s\n' "UNCHANGED" "$rel_in_project"
      continue
    fi

    if [[ $local_drift -eq 1 && $force -eq 0 ]]; then
      printf '%-14s %s\n' "SKIPPED" "$rel_in_project (local edits — merge upstream changes manually)"
      skipped+=("$rel_in_project")
      continue
    fi

    git -C "$REPO_ROOT" show "$current_sha:$f" > "$proj_path"
    if [[ $local_drift -eq 1 ]]; then
      printf '%-14s %s\n' "OVERWRITTEN" "$rel_in_project (had local edits; --force)"
    else
      printf '%-14s %s\n' "UPDATED" "$rel_in_project"
    fi
  done

  # Upstream deletions: remove the project's copy if it is unedited (or --force).
  local b
  for b in "${bootstrap_files[@]}"; do
    list_contains "$b" "${current_files[@]}" && continue
    rel_in_project="$(project_rel_path "$b" "$stack_template_rel")"
    proj_path="$target/$rel_in_project"
    [[ -e "$proj_path" ]] || continue
    tmpl_blob_bootstrap="$(git -C "$REPO_ROOT" show "$bootstrap_sha:$b")"
    proj_content="$(cat "$proj_path")"
    if [[ "$proj_content" == "$tmpl_blob_bootstrap" || $force -eq 1 ]]; then
      rm -f "$proj_path"
      printf '%-14s %s\n' "REMOVED" "$rel_in_project (deleted upstream)"
    else
      printf '%-14s %s\n' "KEPT" "$rel_in_project (deleted upstream but has local edits; remove manually or use --force)"
      skipped+=("$rel_in_project")
    fi
  done

  cat > "$version_file" <<EOF
# Generated by sdlc_template/bin/sync.sh — do not edit by hand.
# Re-run 'sync.sh init --force' to re-bootstrap.
stack=$stack
sha=$current_sha
EOF

  echo
  echo "Updated $target to ${current_sha:0:7} (stack=$stack)"
  if [[ ${#skipped[@]} -gt 0 ]]; then
    echo
    echo "WARNING: ${#skipped[@]} file(s) had local edits and were not fully synced:"
    local s
    for s in "${skipped[@]}"; do echo "  - $s"; done
    echo "Merge upstream changes for these manually, or re-run with --force to overwrite."
  fi
  echo "Review changes with 'git -C \"$target\" diff' before committing."
}

main() {
  [[ $# -gt 0 ]] || { usage; exit 1; }
  local sub="$1"; shift
  case "$sub" in
    init)           cmd_init   "$@" ;;
    check)          cmd_check  "$@" ;;
    update)         cmd_update "$@" ;;
    -h|--help|help) usage; exit 0 ;;
    *)              die "unknown subcommand: $sub (try --help)" ;;
  esac
}

main "$@"
