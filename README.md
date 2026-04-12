# SDLC Template

Reusable standards and templates for Claude Code projects. This repo contains the global Claude instructions, per-project templates for multiple stacks, and GitHub workflow templates.

## Setup

### New Machine

Copy the global Claude instructions:

```bash
cp global-claude.md ~/.claude/CLAUDE.md
```

This file loads into every Claude Code session and defines stack-agnostic engineering rules (work intake, git conventions, testing discipline, operational verification, etc.).

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

## What's in This Repo

| File | Purpose |
|---|---|
| `global-claude.md` | Source of truth for `~/.claude/CLAUDE.md` — global rules for all projects |
| `project-claude-template-typescript.md` | Per-project template for TypeScript + Prisma + Better Auth + Docker projects |
| `project-claude-template-python.md` | Per-project template for Python + uv + Docker projects |
| `project-claude-template-go.md` | Per-project template for Go + Docker projects |
| `.github/ISSUE_TEMPLATE/` | GitHub issue templates (bug, feature, refactor, security) |
| `.github/pull_request_template.md` | GitHub PR template |

## How It Works

Claude Code loads instructions from two levels:

1. **Global** (`~/.claude/CLAUDE.md`) — process rules that apply to every project: orient before editing, one concern per change, testing discipline, definition of done, etc.
2. **Project** (`<project>/CLAUDE.md`) — stack and project-specific config: Docker commands, tooling, framework conventions, architecture overview, etc.

Project-level instructions override global when they conflict. The global file contains only rules that change Claude's default behavior — no redundant instructions.

## Design Principles

These templates were built by comparing Claude's built-in behavior against desired behavior and keeping **only the rules that actually redirect Claude**:

- If Claude already does it by default, it's not in the file
- If it's aspirational but not actionable, it's not in the file
- Every line either changes a behavior or provides project-specific context Claude can't discover on its own
