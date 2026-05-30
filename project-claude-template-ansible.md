# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

> **This is an infrastructure repo, not an application repo.** Several global rules assume application code and a running service; this template deliberately overrides them:
> - **Testing (global §4):** there is no Vitest/Playwright suite. The equivalents are `ansible-lint`, `--syntax-check`, a mandatory `--check --diff` dry-run, and idempotency. See **Testing & Verification** below.
> - **Operational Verification (global §6):** there is no Docker `/health` endpoint. "Did it work?" is answered by a clean converge, per-role state facts, and the run log. See **Testing & Verification** below.
> - **Orientation (global §1):** there is no `package.json`/`pyproject.toml`. Orient from `ansible/docs/*`, `ansible.cfg`, and the inventory.

---

## Stack

Ansible (core 2.16+), targeting remote hosts over SSH. Secrets via Ansible Vault.

---

## Work Tracking

This project uses a hierarchy of Initiative → Epic → Story → Task. The vocabulary, label conventions, and lifecycle diagram are in `docs/glossary.md`. The discovery Q&A playbook is at `docs/discovery-qa.md`. Read both at the start of any session where work-tracking decisions might arise.

**Critical behaviors:**

- When the user describes a new product or feature idea, follow `docs/discovery-qa.md`. The playbook produces a draft PRD at `docs/prds/<slug>.md` via structured Q&A.
- After PRD approval, propose Epics and initial Stories as a markdown draft for user review **before** filing GitHub issues. Use `gh issue create --template <template>.md` only after the user signs off on the proposal.
- When making a non-trivial technical decision during implementation (topology change, role interface, secret-management approach, deployment model), write an ADR using `docs/templates/adr-template.md` to `docs/adrs/NNN-<slug>.md`. Number sequentially.

Skip discovery for tactical work — bugs, refactors, security fixes, focused stories, or single tasks. Use the appropriate `.github/ISSUE_TEMPLATE/` directly.

If the scope is unclear, ask the user once: *"Is this a focused fix/feature or a multi-week effort that deserves a PRD?"* Then proceed accordingly.

---

## Running Playbooks

- **Always scope the inventory explicitly.** Pass `-i` pointed at exactly one inventory (one environment); never run against the inventory root or "all hosts" by accident. A misscoped run can configure the wrong fleet.
- **Prefer the project's run wrapper** if one exists (commonly a script like `ap` / `agent-run.sh`) — it sets `ANSIBLE_CONFIG`, resolves the right inventory, and loads the vault password. Use it rather than raw `ansible-playbook` so config/secret resolution is consistent.
- **Dry-run before every apply.** Run `--check --diff` first, read the diff, and only then apply for real. This is the closest thing to a test in an infra repo — treat skipping it the way you'd treat skipping tests.
  ```bash
  ansible-playbook -i inventories/<env> site.yml --check --diff
  ansible-playbook -i inventories/<env> site.yml          # apply once the diff looks right
  ```
- **Use `--limit`** to constrain blast radius to specific hosts when iterating.

---

## Code Style

- **Lint:** `ansible-lint` (config in `.ansible-lint`) and `yamllint` — both must be clean.
- **Use FQCN** for modules — `ansible.builtin.copy`, not `copy`. Short names are ambiguous and lint-flagged.
- **Prefer modules over `shell`/`command`.** Reach for `shell`/`command` only when no module exists; when you do, set `changed_when`/`creates`/`removes` so the task is idempotent and reports change state honestly.
- **Naming:** roles, tasks, and variables in `snake_case`. Name every task with a clear, action-describing string. Prefix role variables with the role name (`nginx_port`, not `port`) to avoid collisions.
- **No secrets in plaintext** — values that are sensitive live in Vault (see Variables & Secrets) and tasks handling them set `no_log: true`.

---

## Project Layout

```
ansible.cfg
inventories/
  <env>/                   # one directory per environment (and/or domain)
    hosts.yml              # inventory for this environment
    group_vars/
      all/                 # fleet-wide vars for this env
      <group>/
    host_vars/
      <fqdn>/
playbooks/
  host_tasks/<fqdn>/       # one-off, host-specific tasks (pre-role)
roles/
  <role>/                  # reusable unit: tasks/, handlers/, defaults/, templates/, vars/
site.yml                   # top-level composition — includes the apply-* playbooks
apply-<area>.yml           # area playbooks gated by <area>_enabled
docs/                      # architecture, topology, runbooks (orientation lives here)
```

There are **three scopes for where behavior belongs** — choose deliberately:
- **`roles/`** — reusable behavior applied to many hosts. The default home for anything non-trivial.
- **`host_vars/` & `group_vars/`** — data/configuration, not behavior.
- **`playbooks/host_tasks/<fqdn>/`** — genuinely one-off, single-host tasks. **Promote to a role once ≥2 hosts need it.**

---

## Roles & Composition

- **Thin playbooks, fat roles.** Playbooks compose and order roles; the actual work lives in roles.
- **`site.yml` composes `apply-<area>.yml` playbooks**, each gated by an `<area>_enabled` flag so a run only touches enabled areas. Use `meta: end_host` to cleanly skip a host when its area is disabled.
- **Each role sets a `<role>_state` fact** at the end of its run (e.g. `configured`/`skipped`) so other roles, playbooks, and agents can introspect what happened.
- **Roles must be idempotent** — a second consecutive run should report zero changes. This is the core correctness property of Ansible; a role that isn't idempotent is a bug.
- **`defaults/main.yml`** holds overridable defaults; **`vars/main.yml`** holds role-internal constants that shouldn't be overridden.

---

## Variables & Secrets

- **Variable precedence is a footgun** — keep it simple: fleet-wide defaults in `group_vars/all/`, per-environment identity (e.g. `domain_name`, `deployment_environment`) in environment `group_vars`, host specifics in `host_vars/<fqdn>/`. Use directory-form `group_vars/<group>/` (split files) over one giant file.
- **Before renaming a variable or changing a role's interface**, grep for its use across `group_vars/`, `host_vars/`, and `roles/` (and any `apply-*`/`site.yml` references) — the Ansible analog of "grep for callers before changing a signature."
- **Secrets live in Ansible Vault** (`vault.yml` per scope), never in plaintext vars or in the repo.
- **The vault password file lives outside the repo** (e.g. under `~/.config/ansible/`), is referenced via config, and is backstopped by `.gitignore`. Never commit a vault password or pass a secret on the command line where it lands in shell history/process list.

---

## ansible.cfg Baseline

These defaults are deliberate — don't weaken them to work around a failure; fix the underlying issue:
- **`host_key_checking = True`** — leave host-key checking on. If a host key fails, investigate; don't disable the check.
- **`become = False` by default** — escalate privilege explicitly per-task/play with `become: true`, rather than running everything as root.
- **`gathering = smart`** with a fact cache (e.g. ~1h) to speed reruns.
- **`pipelining = True`** (requires `requiretty` disabled in sudoers) for faster execution.

---

## Testing & Verification

This replaces global §4 (Testing) and §6 (Operational Verification) for this repo.

**Before applying any change:**
```bash
ansible-playbook -i inventories/<env> site.yml --syntax-check
ansible-lint
yamllint .
ansible-playbook -i inventories/<env> site.yml --check --diff   # mandatory dry-run
```

**To confirm a change actually worked (the "is it healthy?" gate):**
- The real apply converges with the expected changed/ok counts and **no failures**.
- A **second run is idempotent** — re-running reports `changed=0`. Non-idempotent output means the role is wrong.
- Inspect the relevant `<role>_state` facts.
- Check the run log (commonly `logs/<env>/ansible.log` or as configured) for warnings.

**Optional:** `molecule` for role-level test scenarios if the project adopts it.

Never report a task complete on a failed converge or a non-idempotent role.

---

## Ansible-Specific Rules

- **Idempotency is non-negotiable** — every task must be safe to run repeatedly. Use `creates`/`removes`/`changed_when` on commands; prefer state-declarative modules.
- **`no_log: true`** on any task that handles secrets, so they don't leak into output or logs.
- **Decommissioning a host: comment it out, don't delete it.** Keeping decommissioned hosts commented in inventory preserves history and intent (overrides the global "delete dead code" leaning for inventory).
- **Flag destructive scaffolding.** Scripts that (re)create directory structures or reset state can be destructive on a populated host — note them, and prefer manual/targeted steps over re-running them blindly.
- **Handlers for restarts** — notify a handler rather than restarting a service inline, so restarts coalesce and only fire on actual change.

---

## Project Architecture

<!-- Update this section when you start a new project -->

**What this fleet manages:** <!-- e.g., web/app servers, DNS, mail, monitoring across N hosts -->

**Environments / domains:**
<!-- e.g., the inventory is keyed by <domain>/<env>; which combinations are live vs planned -->

**Key roles:**
<!-- e.g.,
- roles/common/ — base hardening, users, packages
- roles/docker/ — container runtime
- roles/traefik/ — reverse proxy
-->

**Targets & access:**
<!-- e.g., which hosts are live, SSH/jump-host model, where the vault password lives -->

**Key decisions:**
<!-- e.g.,
- Inventory keyed by <domain>/<env>
- Secrets: Ansible Vault, password file at ~/.config/ansible/...
- Composition: site.yml -> apply-*.yml gated by <area>_enabled
- No CI yet / runs are operator-driven via the `ap` wrapper
-->
