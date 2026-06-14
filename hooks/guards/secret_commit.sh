# hooks/guards/secret_commit.sh — block committing secret files.
#
# When the Bash command is a `git commit`, scan the files it would record and
# refuse if any matches a secret glob (and isn't an allow-listed example file).
# Belt-and-suspenders over .gitignore. Requires lib/common.sh sourced first.
#
# Note: an ansible-vault `vault.yml` is ENCRYPTED and intentionally committed,
# so it is deliberately NOT in the default deny set.

guard_secret_commit() {
  [ "$(config_get '.secret_commit.enabled' 'true')" = "true" ] || return 0

  local cmd; cmd="$(hook_field '.tool_input.command')"
  [ -z "$cmd" ] && return 0
  is_git_commit "$cmd" || return 0

  local bypass; bypass="$(config_get '.secret_commit.bypass_env' 'CLAUDE_ALLOW_SECRET_COMMIT')"
  bypassed "$bypass" && return 0

  local cwd; cwd="$(hook_field '.cwd')"
  [ -z "$cwd" ] && return 0
  # Honor `git -C <dir>` so we scan the repo the commit actually targets.
  local gdir; gdir="$(git_effective_dir "$cmd" "$cwd")"
  gdir="$(deepest_existing_dir "$gdir/.")"
  git -C "$gdir" rev-parse --git-dir >/dev/null 2>&1 || return 0

  # Files this commit would record: staged, plus tracked modifications when -a/--all.
  local files; files="$(git -C "$gdir" diff --cached --name-only 2>/dev/null)"
  if has_commit_all_flag "$cmd"; then
    files="$files
$(git -C "$gdir" diff --name-only 2>/dev/null)"
  fi
  [ -z "${files//[[:space:]]/}" ] && return 0

  # Load deny/allow globs (fall back to sensible defaults if config absent).
  local -a deny_globs=() allow_globs=()
  local g
  while IFS= read -r g; do [ -n "$g" ] && deny_globs+=("$g"); done < <(config_array '.secret_commit.deny_globs')
  while IFS= read -r g; do [ -n "$g" ] && allow_globs+=("$g"); done < <(config_array '.secret_commit.allow_globs')
  if [ "${#deny_globs[@]}" -eq 0 ]; then
    deny_globs=(".env" ".env.*" "*.pem" "*.key" "credentials.json" "id_rsa" "id_dsa" "*.p12" "*.pfx")
  fi
  if [ "${#allow_globs[@]}" -eq 0 ]; then
    allow_globs=(".env.example" ".env.sample" ".env.template")
  fi

  local f base offenders=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    base="$(basename "$f")"
    local allowed=0 p
    for p in "${allow_globs[@]}"; do glob_match "$base" "$p" && { allowed=1; break; }; done
    [ "$allowed" -eq 1 ] && continue
    for p in "${deny_globs[@]}"; do
      if glob_match "$base" "$p"; then offenders="$offenders$f
"; break; fi
    done
  done <<< "$files"

  if [ -n "$offenders" ]; then
    local bypass2; bypass2="$(config_get '.secret_commit.bypass_env' 'CLAUDE_ALLOW_SECRET_COMMIT')"
    deny "Refusing to commit — these staged files look like secrets:

$(printf '%s' "$offenders" | sed 's/^/    /')
Secrets must never be committed (use .gitignore / a vault). If a match is a false positive (e.g. an encrypted vault), add it to .secret_commit.allow_globs in the hooks config, or set ${bypass2}=1 to override this session."
  fi
  return 0
}
