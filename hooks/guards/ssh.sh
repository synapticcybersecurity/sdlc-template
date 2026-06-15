# hooks/guards/ssh.sh — block raw `ssh` (manual remote access).
#
# Contract: reach managed hosts through Ansible (the `ap` wrapper), NEVER raw
# ssh. Raw ssh bypasses the project-local ssh_config + automation identity and
# trips the Bitwarden SSH agent (e.g. `ssh -i <pubkey> root@host`, which can't
# work and just spawns auth prompts). Requires lib/common.sh sourced first.
#
# Matches the `ssh` binary as a command word; does NOT match ssh-keygen /
# ssh-add / ssh-keyscan (those have no space after `ssh`), nor `~/.ssh/...`
# paths (no trailing space). `sshpass … ssh host` and `/usr/bin/ssh host` DO
# match (they are still ssh).

guard_ssh() {
  [ "$(config_get '.ssh_guard.enabled' 'true')" = "true" ] || return 0

  local cmd; cmd="$(hook_field '.tool_input.command')"
  [ -z "$cmd" ] && return 0
  printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_.-])ssh[[:space:]]' || return 0

  local bypass; bypass="$(config_get '.ssh_guard.bypass_env' 'CLAUDE_ALLOW_SSH')"
  bypassed "$bypass" && return 0

  deny "Refusing a raw 'ssh' command — manual SSH is disabled. Reach managed hosts through Ansible instead:

    ansible/bin/ap <domain> <env> ping.yml --limit <host>
    ansible/bin/ap <domain> <env> <playbook> --limit <host> [--check --diff]

Raw ssh bypasses the project-local ssh_config + automation identity and trips the Bitwarden agent. If you genuinely need a one-off interactive shell, ask the user to run it themselves via '! ssh ...'. Override for this session: ${bypass}=1."
}
