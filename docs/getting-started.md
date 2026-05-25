# Getting Started in This Project

You've landed in a project bootstrapped from the `sdlc_template` scaffolding — Initiative / Epic / Story / Task hierarchy, PRDs for substantial work, ADRs for technical decisions. This doc is the practical "what do I do next" companion.

For the reference material (definitions, label conventions, lifecycle diagram), see `docs/glossary.md`. For worked examples of a real PRD and ADR, see the [`examples/`](https://github.com/synapticcybersecurity/sdlc-template/tree/main/examples) directory in the `sdlc_template` repo.

## 30-second orientation

```
.
├── .github/
│   ├── ISSUE_TEMPLATE/      ← templates for filing work
│   └── pull_request_template.md
├── CLAUDE.md                ← project-specific Claude instructions
├── docs/
│   ├── glossary.md          ← work-tracking vocabulary + labels + lifecycle
│   ├── discovery-qa.md      ← Claude's playbook for turning ideas into PRDs
│   ├── getting-started.md   ← this file
│   ├── templates/
│   │   ├── prd-template.md  ← copy when starting a new PRD
│   │   └── adr-template.md  ← copy when writing a new ADR
│   ├── prds/                ← your actual PRDs (created over time)
│   └── adrs/                ← your actual ADRs (NNN-<slug>.md)
└── ... (your code)
```

When you open a Claude Code session in this project, `CLAUDE.md` loads automatically. Claude knows about the work-tracking system and will reach for the right docs based on what you're trying to do.

## What do you want to do today?

### "I have a new product or feature idea"

Just tell Claude what you're thinking — vague is fine. Claude will recognize the cue and walk you through `docs/discovery-qa.md`, a structured Q&A that produces a draft PRD at `docs/prds/<slug>.md`.

After you review and approve the PRD, Claude proposes Epics and initial Stories as a markdown draft. You edit. You sign off. Then Claude files them as GitHub issues with `gh issue create`.

You don't have to memorize the flow — Claude drives it.

### "I have a clear feature in mind, ~1–5 days of work"

Skip discovery. Say "let's file a Story for X" and Claude will use the Story template (`.github/ISSUE_TEMPLATE/story.md`).

### "I have a bug to fix"

Say "there's a bug: ..." — Claude will use `bug_report.md`, not the Story template.

### "Refactor, cleanup, or dependency upgrade"

Use `refactor.md` for internal-only changes that don't alter behavior. Use `task.md` for chores like dependency upgrades, build-system maintenance, or small infra work.

### "Security concern"

Use `security.md`. **Sensitive details should not go in a public issue body** — file with the minimum needed to track the work, and link to a private channel if more context is needed.

### "I'm partway through implementation and need to make a real technical decision"

Stop and write an ADR. Copy `docs/templates/adr-template.md` to `docs/adrs/NNN-<slug>.md`, where `NNN` is the next sequential number. If you describe the decision and the alternatives to Claude, they'll offer to draft it for you.

### "I want to understand the hierarchy or labels"

Read `docs/glossary.md`.

## Edge cases

**My idea is bigger than a Story but smaller than an Initiative.**  
Then it's an Epic. Epics don't require a PRD — file an Epic directly and break it into Stories. If you find yourself adding more Epics around the same theme, promote it to an Initiative and write a PRD at that point.

**I started discovery but realized this is just a Story.**  
Tell Claude. The discovery flow can be abandoned at any point.

**I want to write an ADR after the fact.**  
Fine — ADRs document decisions whenever they're made. If a decision is already in code, writing the ADR is even more valuable: future-you doesn't have to reverse-engineer the reasoning.

**I want to override one of the templates for this project.**  
Edit the file directly in `docs/` or `.github/ISSUE_TEMPLATE/`. The next time you run `<path-to-sdlc_template>/bin/sync.sh check .`, the script will report local drift on that file — that's expected, and means your project's conventions diverge from the template baseline.

**I changed my mind about an Epic after issues were filed.**  
Use `gh issue edit` or close affected issues and create new ones. The PRD is the source of truth; issues are the workflow representation of the PRD at a point in time.

**An Initiative is done.**  
Close it on GitHub. Its child Epics should already be closed. The PRD stays in `docs/prds/` as a historical record.

**The PRDs might contain pre-launch business context I don't want public.**  
If your project's repo is public, consider adding `docs/prds/` (and possibly `docs/adrs/`) to `.gitignore`. Or keep PRDs in a private companion repo. The templates and the playbook (`docs/discovery-qa.md`, `docs/templates/`) are generic and safe to publish.

## Working with Claude

Claude knows about this system because `CLAUDE.md` tells them. You don't have to invoke the playbook by name — describe what you're trying to do, and Claude will pick the right path. If Claude picks wrong, redirect them: *"actually let's skip discovery and just file a Story."*

Two things Claude will not do without your sign-off:

1. **Create GitHub issues** — Claude proposes them as a markdown draft first, you approve, then Claude files them.
2. **Make destructive changes** (force-pushes, branch deletions, schema drops) — see the global rules in `~/.claude/CLAUDE.md`.

If you want to bypass discovery for a one-off prototype or quick experiment, say so once at the start of the session and Claude will skip ahead.

## Staying in sync with the template

This project was bootstrapped from `sdlc_template`. The version is recorded in `.sdlc-template-version`.

To check whether the template has changes you might want to pull in:

```bash
<path-to-sdlc_template>/bin/sync.sh check .
```

It compares your project's templated files against the template at the bootstrap SHA and at current HEAD, reporting:

- `OK` — file matches the template
- `DRIFT … local-edits` — you've edited this file locally (expected for project-specific overrides)
- `DRIFT … upstream-newer` — the template has updated this file (consider syncing)
- `MISSING` — the template has a file your project doesn't (likely a new scaffolding addition)

Use `--diff` to see the actual changes. Reconcile by hand — or, if you want to start fresh from the template, `sync.sh init --force`. Consumer-owned dirs (`docs/prds/`, `docs/adrs/`) are never touched by `--force`.
