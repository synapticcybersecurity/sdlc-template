# SDLC Template

Reusable standards and templates for Claude Code projects. Contains the shared global Claude instructions, per-project templates for multiple stacks, and GitHub workflow templates.

## Quickstart

Three commands and you're running:

```bash
# 1. Clone this repo (one time, somewhere stable)
git clone https://github.com/synapticcybersecurity/sdlc-template.git ~/Projects/sdlc_template

# 2. Wire your global Claude instructions to import from it
mkdir -p ~/.claude
cat > ~/.claude/CLAUDE.md <<'EOF'
# Global instructions
@~/Projects/sdlc_template/global-claude.md
EOF

# 3. Bootstrap a new project
mkdir ~/Projects/myapp && cd ~/Projects/myapp && git init
~/Projects/sdlc_template/bin/sync.sh init . --stack=typescript
```

Now open Claude Code in `~/Projects/myapp` and describe an idea: *"I want to build a tool that..."*. Claude will follow `docs/discovery-qa.md` to turn it into a draft PRD, then propose Epics and Stories.

For the day-to-day "what do I do for X" guide, see [`docs/getting-started.md`](docs/getting-started.md). For a worked example of a real PRD and ADR, see [`examples/`](examples/).

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
# stacks: typescript | python | go | rust | ansible
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

### Adopting in an Existing Project

`init` is for greenfield projects — it refuses to overwrite existing files. For a project that already exists (and already has its own `CLAUDE.md` you want to keep), use `adopt` instead:

```bash
~/Projects/sdlc_template/bin/sync.sh adopt /path/to/existing-project --stack=typescript
```

`adopt` is **additive and non-destructive**:

- Copies the `.github/` issue+PR templates and `docs/` scaffolding, but **keeps any file the project already has** (reported `KEPT`); only missing files are `ADDED`. Pass `--force` to overwrite existing scaffolding files.
- **Never overwrites the project's `CLAUDE.md`** — even with `--force`. If the project has no `CLAUDE.md`, one is created from the stack template; otherwise the bespoke file is left untouched.
- Writes `.sdlc-template-version`, so `check` and `update` work afterward.

After adopting, the project's `CLAUDE.md` will show as `local-edits` under `check` (expected — it's your own file). To make forks use the work-tracking system, add a Work Tracking section to it pointing at the new `docs/` scaffolding.

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
- `REMOVED-UPSTREAM` — template deleted the file since bootstrap, but the project still carries it

### Updating a Bootstrapped Project

`bin/sync.sh update` re-syncs a project to the current template HEAD. Files with no local edits are updated in place; files the project has edited (almost always `CLAUDE.md`, which carries the Project Architecture section) are left untouched and reported for manual merge. Files deleted upstream are removed if the project hasn't edited them. The `.sdlc-template-version` stamp is rewritten to the new HEAD.

```bash
~/Projects/sdlc_template/bin/sync.sh update /path/to/your-project
~/Projects/sdlc_template/bin/sync.sh update /path/to/your-project --force   # overwrite local edits too
```

Per-file actions are printed: `UPDATED`, `ADDED`, `REMOVED`, `UNCHANGED`, `SKIPPED` (local edits, left alone), `OVERWRITTEN` (`--force`), `KEPT` (upstream-deleted but locally edited). Run `git diff` in the project afterward to review before committing. A typical loop is `check` to see what drifted, then `update` to pull it in.

## What's in This Repo

| File | Purpose |
|---|---|
| `global-claude.md` | Shared engineering standards. Imported live by `~/.claude/CLAUDE.md` — do not copy. |
| `project-claude-template-typescript.md` | Per-project template for TypeScript + Prisma + Better Auth + Docker projects |
| `project-claude-template-python.md` | Per-project template for Python + uv + Docker projects |
| `project-claude-template-go.md` | Per-project template for Go + Docker projects |
| `project-claude-template-rust.md` | Per-project template for Rust (Cargo workspace) + Docker projects |
| `project-claude-template-ansible.md` | Per-project template for Ansible / infrastructure repos (overrides global testing + ops-verification rules) |
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

## Examples

The [`examples/`](examples/) directory contains a worked example of a small product running through the full flow:

- [`examples/prds/standup-digest.md`](examples/prds/standup-digest.md) — a PRD for a toy product: a CLI tool that summarizes your daily GitHub state for standup
- [`examples/adrs/001-use-flat-file-cache.md`](examples/adrs/001-use-flat-file-cache.md) — the first ADR written during implementation: flat JSON file vs SQLite for the cache

These are deliberately *not* copied into bootstrapped projects (`sync.sh` ignores anything outside `.github/` and `docs/`). They live here as reference material for someone learning the system. The PRD is a complete fill-in of `docs/templates/prd-template.md`; the ADR is a complete fill-in of `docs/templates/adr-template.md`.

## Development

The only executable logic in this repo is `bin/sync.sh`, which has a [bats](https://github.com/bats-core/bats-core) test suite under `test/`. bats-core is vendored as a git submodule, so after cloning:

```bash
git submodule update --init   # fetches test/bats
make test                     # or: ./test/bats/bin/bats test/
```

Each test builds a self-contained throwaway template repo, so the suite never touches your real history. If you change `sync.sh`, add or update the corresponding tests before committing.

## Design Principles

These templates were built by comparing Claude's built-in behavior against desired behavior and keeping **only the rules that actually redirect Claude**:

- If Claude already does it by default, it's not in the file
- If it's aspirational but not actionable, it's not in the file
- Every line either changes a behavior or provides project-specific context Claude can't discover on its own

Project-level instructions override global when they conflict. The global file contains only rules that change Claude's default behavior — no redundant instructions.
