# SDLC Template

Reusable standards and templates for Claude Code projects. Contains the shared global Claude instructions, per-project templates for multiple stacks, and GitHub workflow templates.

## How Loading Works

Claude Code loads instructions from two levels:

1. **Global** (`~/.claude/CLAUDE.md`) — loaded into every session.
2. **Project** (`<project>/CLAUDE.md`) — loaded when working in that project. Overrides global on conflict.

Claude Code supports `@path` imports inside CLAUDE.md files. That means `~/.claude/CLAUDE.md` doesn't need to be a copy of the shared standards — it can just import them by path. Edit the source file in this repo, and the next session picks up the change automatically. No copying, no drift.

## Setup

### New Machine

1. Clone this repo somewhere stable (the path is referenced from `~/.claude/CLAUDE.md`):
   ```bash
   git clone <repo-url> ~/Projects/sdlc_template
   ```

2. Create `~/.claude/CLAUDE.md` as a thin file that imports the shared standards and (optionally) a personal addendum:
   ```markdown
   # Global instructions

   @~/Projects/sdlc_template/global-claude.md
   @~/.claude/personal-claude.md
   ```
   Adjust the first path if you cloned somewhere else.

3. (Optional) Create `~/.claude/personal-claude.md` for machine-specific or personal instructions that should not live in a shared repo — things like local credential setup, hardware quirks, or anything that's *yours* rather than the team's. Skip this file entirely if you don't need it (remove the second `@import` line as well).

To pick up updates to the shared standards, just `git pull` in the repo. The next Claude session will see the new content.

### New Project

1. Copy the GitHub templates into your project:
   ```bash
   cp -r .github/ /path/to/your-project/.github/
   ```

2. Copy the appropriate stack template as your project's Claude instructions:
   ```bash
   # TypeScript + Prisma + Better Auth
   cp project-claude-template-typescript.md /path/to/your-project/CLAUDE.md

   # Python + uv
   cp project-claude-template-python.md /path/to/your-project/CLAUDE.md

   # Go
   cp project-claude-template-go.md /path/to/your-project/CLAUDE.md
   ```

3. Edit the `CLAUDE.md` in your project and fill in the **Project Architecture** section at the bottom — application type, key directories, ports, and key decisions.

> A per-project `bin/sync.sh` to handle bootstrap and drift detection is planned. For now, project setup is still copy-based.

## What's in This Repo

| File | Purpose |
|---|---|
| `global-claude.md` | Shared engineering standards. Imported live by `~/.claude/CLAUDE.md` — do not copy. |
| `project-claude-template-typescript.md` | Per-project template for TypeScript + Prisma + Better Auth + Docker projects |
| `project-claude-template-python.md` | Per-project template for Python + uv + Docker projects |
| `project-claude-template-go.md` | Per-project template for Go + Docker projects |
| `.github/ISSUE_TEMPLATE/` | GitHub issue templates (bug, feature, refactor, security) |
| `.github/pull_request_template.md` | GitHub PR template |

`~/.claude/personal-claude.md` is referenced by the import setup but lives only on your machine — it is not in this repo by design.

## Design Principles

These templates were built by comparing Claude's built-in behavior against desired behavior and keeping **only the rules that actually redirect Claude**:

- If Claude already does it by default, it's not in the file
- If it's aspirational but not actionable, it's not in the file
- Every line either changes a behavior or provides project-specific context Claude can't discover on its own

Project-level instructions override global when they conflict. The global file contains only rules that change Claude's default behavior — no redundant instructions.
