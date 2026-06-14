# Global Development Standards

Default conventions for all projects. Project-level CLAUDE.md files override these where they differ.

---

## 1. Operating Rules

Every change is part of an engineering workflow. These rules apply to all work:

- **Orient to the project:** At the start of a session, if you haven't worked in this repository before, read the project's CLAUDE.md, README.md, and package.json (or pyproject.toml) before making changes. Understand the stack, structure, and conventions before acting.
- **Orient before editing:** Before modifying any file, read it in full. Before changing a function's signature or behavior, grep for its callers and read at least one. Before adding a new pattern, check whether the repository already has one for this purpose. If the change touches more than ~3 files or crosses module boundaries, state your plan before executing it.
- **One concern per change:** Do not mix unrelated features, refactors, or formatting in the same branch or PR.
- **No silent architecture changes:** Before changing module boundaries, data flow, or system interfaces, surface the decision and get confirmation.
- **Finish the unit of work:** Code, tests, documentation, and validation are one delivery — not separate tasks to defer.
- **Offer documentation updates proactively:** After adding something new (a role, module, playbook, feature, command, configuration knob) or making a significant change to existing items (architecture shift, renamed convention, behavior change, new constraint, dropped capability), explicitly offer to update relevant documentation — don't wait to be asked. Concrete candidates to consider every time: the project README, design docs in `docs/`, role/module READMEs, deferred-work or migration trackers, ADRs, inline CLAUDE.md files, and architectural memory entries. Surface specific update proposals (e.g. "the IPv6 explanation in `roles/foo/README.md` is now inaccurate; want me to fix it?") rather than open-ended "anything else?" prompts, so the user can accept or reject quickly.
- **Don't volunteer stopping points:** Do not propose "good stopping point", "let's call it for the night", "stop here?" etc. unprompted, even after wrapping a substantial chunk of work. Summarize what happened and wait for the next instruction. The user will say when to stop.

---

## 2. Work Intake and Planning

All substantial changes should map to a tracked work item (GitHub Issue, Jira, Linear, or equivalent).

**Before starting work:**
1. Check for existing issues (e.g., `gh issue list --state open` for GitHub)
2. Create one if none exists
3. Reference the issue in all commits and PRs

**Before making significant changes, assess:**
- Which files or modules are likely to change
- Whether the change affects architecture or only local implementation
- Whether user-visible behavior, schemas, APIs, or contracts change
- Whether tests, documentation, or configuration must be updated
- Whether security, secrets, or deployment behavior is involved
- What can fail and how: the error conditions to handle, and what happens if an external dependency is slow, rate-limited, or down
- Whether the operation is long-running and should be backgrounded rather than blocking a request

---

## 3. Git and Branching

**Branching:**
- `main` should remain releasable; direct commits discouraged
- Use feature branches + PRs for non-trivial changes
- Branch naming: `feature/<issue-id>-<short-name>`, `fix/...`, `refactor/...`, `chore/...`, `docs/...`

**Commits:**
```
<type>: <short summary>

Types: feat, fix, refactor, docs, test, chore, build, ci, security, perf
```
- Reference issues: `feat: Add email notifications (#10)`
- Use `Closes #X` in commit body to auto-close issues
- Keep commits logically grouped; avoid mixing unrelated edits
- No AI attribution: never add `Co-Authored-By`, "Generated with Claude Code", or similar attribution lines to commits or PRs

**Enforced by tooling** (where the sdlc hooks are installed — see `hooks/README.md`):
- Editing or running `git commit` in a repo's **main checkout** under your projects root is blocked; work in a per-task `git worktree`. Per-session override: `CLAUDE_ALLOW_MAIN_EDITS=1`.
- `gh auth switch` is blocked (it flips the global, session-shared account) — use a scoped token instead.
- No-AI-attribution is enforced natively by the `attribution` setting in `settings.json`.

**Pull Requests must include:**
- What changed and why
- Linked issue or task
- Key implementation notes
- Tests run or added
- Risks or tradeoffs
- Documentation updates
- Migration or operational notes if applicable

---

## 4. Testing

Testing is part of implementation, not an optional extra. Every new code path, branch condition, and error case should have a corresponding test. When modifying existing code, check for existing tests and update them — do not leave broken tests behind.

**When a change affects behavior, evaluate whether to add:**
- Unit tests for business logic and utility behavior
- Integration tests for persistence and service boundaries
- End-to-end tests for critical workflows

Use the test runner already in the project. For new projects, prefer Vitest (unit/integration) and Playwright (E2E).

If tests cannot be added or run, say so explicitly rather than implying full validation.

**Run the full test suite before marking work complete.**

---

## 5. Security

**Never commit:** `.env` files, API keys, secrets, passwords, `*.pem`, `*.key`, `credentials.json`. Where the sdlc hooks are installed this is **enforced**: a `git commit` staging such files is blocked (override `CLAUDE_ALLOW_SECRET_COMMIT=1`).

**Non-default security rules:**
- Use least-privilege scopes for integrations, service accounts, and OAuth tokens — not admin/wildcard defaults
- When a change involves sensitive actions (auth changes, permission changes, data access), add audit logging
- If a requested change creates a material security tradeoff, surface the tradeoff and get confirmation — do not silently pick the "safer" option

---

## 6. Operational Verification

**After any backend changes in Docker projects:**
1. Check container status: `docker compose ps` — look for "unhealthy" or "restarting"
2. Test the health endpoint (typically `/health`)
3. Check recent logs: `docker compose logs <service> --tail 50`
4. **Never report a task complete if the application is unhealthy**

Do not stop at feature logic when the change clearly affects production operation.

---

## 7. Definition of Done

A task is not complete until:
- [ ] Tests added or updated for all new/changed behavior
- [ ] All tests pass (run the suite, don't assume)
- [ ] Documentation updated if setup, config, APIs, or behavior changed
- [ ] Limitations stated explicitly if anything couldn't be validated
- [ ] Follow-up items identified if anything was intentionally deferred

---

## 8. Instruction Priority Order

Resolve conflicts in this order:
1. Direct user instructions (chat, CLI)
2. Project-level CLAUDE.md (overrides global for that project)
3. This global `~/.claude/CLAUDE.md`
4. Repository conventions discoverable from code and docs
5. General defaults

When conflicts cannot be resolved from this order, ask the user which takes priority.

---

## Third-Party Integrations

When code calls an external API or service:

- **Set a timeout on every outbound call** — never let a request hang indefinitely.
- **Retry transient failures with exponential backoff**, and **handle rate limiting (HTTP 429)** explicitly rather than treating it as a generic error.
- **Degrade gracefully** — a non-critical dependency being slow or down should not fail the whole operation. Cache responses where appropriate.
- **Validate required API keys and configuration at startup**, not on first use, so misconfiguration fails fast and visibly.
- **Log outbound calls** (never the secrets) for debugging, and monitor cost/usage for metered APIs.

---

## Code Deletion Safety

- Verify usage before deleting any code (grep for function names, check imports)
- Check for import aliases and indirect references
- Delete incrementally (one function/file at a time), verify health between deletions
- Get explicit approval before bulk deletions
