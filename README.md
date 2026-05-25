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

Use `bin/sync.sh init` to bootstrap a project. It copies in the GitHub workflow templates, the chosen stack `CLAUDE.md`, and the docs scaffolding (glossary, PRD/ADR templates, discovery Q&A playbook), then records a version stamp so drift can be detected later.

```bash
~/Projects/sdlc_template/bin/sync.sh init /path/to/your-project --stack=typescript
# stacks: typescript | python | go
```

After bootstrap, the project contains:

```
<project>/
├── .github/ISSUE_TEMPLATE/      # bug, feature, refactor, security, initiative, epic, story, task
├── .github/pull_request_template.md
├── .sdlc-template-version       # records the template SHA at bootstrap
├── CLAUDE.md                    # the chosen stack template
└── docs/
    ├── glossary.md              # work-tracking vocabulary + labels
    ├── discovery-qa.md          # playbook Claude follows when you bring a new idea
    ├── getting-started.md       # human orientation — read this first in a new project
    └── templates/
        ├── prd-template.md
        └── adr-template.md
```

`init` refuses to overwrite an existing `.github/`, `CLAUDE.md`, `.sdlc-template-version`, or any of the templated `docs/` paths unless you pass `--force`. Consumer-owned directories like `docs/prds/` and `docs/adrs/` are never touched, even on `--force`.

After bootstrap, edit the project's `CLAUDE.md` and fill in the **Project Architecture** section at the bottom — application type, key directories, ports, and key decisions.

### Detecting Drift in a Bootstrapped Project

`bin/sync.sh check` compares a project's templated files against the template at the SHA it was bootstrapped from and against current HEAD. It reports local edits and upstream changes separately, exits non-zero on any drift, and accepts `--diff` to show unified diffs.

```bash
~/Projects/sdlc_template/bin/sync.sh check /path/to/your-project
~/Projects/sdlc_template/bin/sync.sh check /path/to/your-project --diff
```

Output tags:
- `OK` — file matches both the bootstrap baseline and current HEAD
- `DRIFT … local-edits` — project changed the file since bootstrap
- `DRIFT … upstream-newer` — template changed the file since bootstrap (you may want to update)
- `MISSING` — template has the file, project does not

Limitation: files deleted from the template upstream are not currently flagged.

## What's in This Repo

| File | Purpose |
|---|---|
| `global-claude.md` | Shared engineering standards. Imported live by `~/.claude/CLAUDE.md` — do not copy. |
| `project-claude-template-typescript.md` | Per-project template for TypeScript + Prisma + Better Auth + Docker projects |
| `project-claude-template-python.md` | Per-project template for Python + uv + Docker projects |
| `project-claude-template-go.md` | Per-project template for Go + Docker projects |
| `.github/ISSUE_TEMPLATE/` | GitHub issue templates (bug, feature, refactor, security, initiative, epic, story, task) |
| `.github/pull_request_template.md` | GitHub PR template |
| `docs/glossary.md` | Work-tracking vocabulary (Initiative / Epic / Story / Task) and label conventions |
| `docs/discovery-qa.md` | Playbook Claude follows to turn a product idea into a draft PRD |
| `docs/getting-started.md` | Human-facing orientation for someone in a bootstrapped project — decision tree, edge cases, FAQ |
| `docs/templates/prd-template.md` | PRD scaffolding (filed into `docs/prds/` per project) |
| `docs/templates/adr-template.md` | ADR scaffolding (filed into `docs/adrs/` per project) |
| `bin/sync.sh` | Bootstrap projects from this template and detect drift |

`~/.claude/personal-claude.md` is referenced by the import setup but lives only on your machine — it is not in this repo by design.

## Work Tracking

Each bootstrapped project gets a four-level hierarchy for tracking work:

- **Initiative** — multi-quarter direction, backed by a PRD
- **Epic** — multi-week deliverable that ladders into an Initiative
- **Story** — user-visible change shippable in 1–5 days
- **Task** — subordinate work under a Story, or a standalone chore

Each level has a GitHub issue template under `.github/ISSUE_TEMPLATE/`. Parent–child relationships use GitHub's native **+ Add sub-issue** UI. See `docs/glossary.md` for the full definitions and label conventions.

### The Flow

```
Idea → Discovery Q&A → Draft PRD → PRD review → Initiative issue
                                                  ↓
                                       Decomposition (proposed Epics + Stories)
                                                  ↓
                                       Human review of proposed issues
                                                  ↓
                                       Issues filed via gh
                                                  ↓
                                       Normal commit/PR pipeline
```

When you bring a new product or feature idea to Claude in a bootstrapped project, it follows `docs/discovery-qa.md` — a structured Q&A that produces a draft PRD at `docs/prds/<slug>.md`. After you approve the PRD, Claude proposes Epics and initial Stories as a draft list, then creates them as GitHub issues only after you sign off.

PRDs and ADRs live in the project's own `docs/prds/` and `docs/adrs/` directories — generated per project from `docs/templates/`. Those generated docs may contain pre-launch business context; if your project is public, you may want to gitignore them.

## Design Principles

These templates were built by comparing Claude's built-in behavior against desired behavior and keeping **only the rules that actually redirect Claude**:

- If Claude already does it by default, it's not in the file
- If it's aspirational but not actionable, it's not in the file
- Every line either changes a behavior or provides project-specific context Claude can't discover on its own

Project-level instructions override global when they conflict. The global file contains only rules that change Claude's default behavior — no redundant instructions.
