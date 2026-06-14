# hooks/guards/gh_auth_switch.sh — block `gh auth switch`.
#
# `gh`'s active account is global, shared state across all concurrent sessions.
# Switching it to fix a push breaks whichever other session needed the previous
# account. The correct pattern is a per-command scoped token (see personal
# CLAUDE addendum). Requires lib/common.sh sourced first.

guard_gh_auth_switch() {
  [ "$(config_get '.gh_auth_switch.enabled' 'true')" = "true" ] || return 0

  local cmd; cmd="$(hook_field '.tool_input.command')"
  [ -z "$cmd" ] && return 0
  printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+auth[[:space:]]+switch([[:space:]]|$|;|&)' || return 0

  local bypass; bypass="$(config_get '.gh_auth_switch.bypass_env' 'CLAUDE_ALLOW_GH_SWITCH')"
  bypassed "$bypass" && return 0

  deny "Refusing to run 'gh auth switch' — it flips the global gh account that all concurrent sessions share, and breaks whichever session relied on the previous account. Authenticate the single operation with a scoped token instead, e.g.:

    git -c credential.helper='!f() { test \"\$1\" = get && printf \"username=x-access-token\\npassword=%s\\n\" \"\$(gh auth token -u <owner>)\"; }; f' push origin <branch>
    # or for read-only gh:  GH_TOKEN=\"\$(gh auth token -u <owner>)\" gh <cmd>

To override for this session, set ${bypass}=1."
}
