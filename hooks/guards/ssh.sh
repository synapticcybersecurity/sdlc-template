# hooks/guards/ssh.sh — prompt on raw `ssh` (prefer Ansible).
#
# Preference: reach managed hosts through Ansible (the `ap` wrapper), not raw
# ssh — raw ssh bypasses the project-local ssh_config + automation identity and
# trips the Bitwarden agent (e.g. `ssh -i <pubkey> root@host`). This guard does
# NOT hard-block; it asks (surfaces a permission prompt) so the user approves
# genuine ssh and waves off the reflexive case. Requires lib/common.sh first.
#
# Command-position matching: fires only when `ssh` is actually INVOKED — at the
# start of the command or after a separator (; & | && ||). So `ssh host …`,
# `foo && ssh host`, `… | ssh host` prompt; but `echo "use ssh"`, `grep ssh f`,
# `man ssh`, `ssh-keygen`, `~/.ssh/...` do NOT. (Trade-off: `/usr/bin/ssh`,
# `sudo ssh`, `sshpass … ssh` aren't matched — acceptable for a soft prompt.)

guard_ssh() {
  [ "$(config_get '.ssh_guard.enabled' 'true')" = "true" ] || return 0

  local cmd; cmd="$(hook_field '.tool_input.command')"
  [ -z "$cmd" ] && return 0
  printf '%s' "$cmd" | grep -Eq '(^|[;&|])[[:space:]]*ssh[[:space:]]' || return 0

  local bypass; bypass="$(config_get '.ssh_guard.bypass_env' 'CLAUDE_ALLOW_SSH')"
  bypassed "$bypass" && return 0

  ask "Raw 'ssh' — this project prefers Ansible. Reach managed hosts via:

    ansible/bin/ap <domain> <env> ping.yml --limit <host>
    ansible/bin/ap <domain> <env> <playbook> --limit <host> [--check --diff]

Raw ssh bypasses the project ssh_config + automation identity and trips the Bitwarden agent. Approve only if Ansible genuinely can't do this. (To skip this prompt for a session: ${bypass}=1.)"
}
