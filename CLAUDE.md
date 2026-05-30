# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines conventions specific to **this repo** — the SDLC template factory. It only covers what changes behavior here; everything in the global standards still applies and is not repeated.

This repo is bash + markdown. Its outputs are *other repos'* instructions: the shared global standards, per-stack `CLAUDE.md` templates, and the `.github/`/`docs/` scaffolding that `bin/sync.sh` copies into bootstrapped projects.

---

## Propagation Trap (read first)

`bin/sync.sh` copies **everything committed under `.github/` and `docs/`** — plus the chosen `project-claude-template-<stack>.md` (as the consumer's `CLAUDE.md`) — into every bootstrapped project. The file list is git-ref-driven (`git ls-tree`), so it captures *all* tracked paths under those directories, not a curated subset.

**Consequence:** anything you add under `.github/` or `docs/` lands in every downstream project.

- **Repo-only tooling must NOT live under `.github/` or `docs/`.** The obvious trap is CI: a workflow under `.github/workflows/` would propagate to every consumer. Keep repo-internal tooling at the root, in `bin/`, or in `test/`.
- `examples/` is reference material and is deliberately **not** propagated — don't move its contents under `docs/`.
- Consumer-owned paths `docs/prds/` and `docs/adrs/` are never touched by `sync.sh` (even with `--force`); don't add template content there.

---

## Editing the Standards

- **`global-claude.md` is the live source** of the global standards, imported by `~/.claude/CLAUDE.md`. Editing it changes behavior in **every project on the machine**, not just this repo — treat changes as high blast radius and surface them.
- **Stack templates are the artifact, edited in place** (`project-claude-template-{typescript,python,go,rust,ansible}.md`). A change that applies to more than one stack usually needs mirroring across them — cross-template drift is a known failure mode. Keep the shared **Work Tracking** block identical across templates, and keep each template's commented **Project Architecture** placeholder intact.
- **Editorial bar (from the README Design Principles):** every line in a standards/template file must either redirect Claude's default behavior or supply project-specific context it can't discover on its own. If global already covers it, or it's aspirational, leave it out. This applies when editing `global-claude.md`, the stack templates, and the docs scaffolding.

---

## Running Tests

`bin/sync.sh` is the only executable logic; it has a [bats](https://github.com/bats-core/bats-core) suite under `test/`, with bats-core vendored as a git submodule.

```bash
git submodule update --init   # one-time: fetches test/bats
make test                     # or: ./test/bats/bin/bats test/
```

If the submodule isn't initialized, the runner is absent — don't conclude "there are no tests." **Update `test/sync.bats` whenever you change `sync.sh`** (Definition of Done). Each test builds a throwaway template repo, so the suite never touches real history.

---

## sync.sh Invariants

When modifying `bin/sync.sh`, preserve these:

- `set -euo pipefail`; written to stay portable to macOS bash 3.2 (guard `"${arr[@]}"` on possibly-empty arrays).
- **Committed-state only:** the templated file set and all comparisons read from git refs, so uncommitted template edits won't sync — the script warns on a dirty repo rather than silently using working-tree content.
- **`.sdlc-template-version` format** (`stack=` / `sha=` lines) is parsed by both `check` and `update` and asserted by the bats fixtures — don't change the format without updating all three.
- `init` refuses to overwrite an existing bootstrap without `--force`; `update` skips locally-edited files unless `--force`. Keep these safety defaults.

---

## Project Architecture

**Application type:** SDLC template/standards repo (bash tooling + markdown templates). No application runtime.

**Key directories:**
- `global-claude.md` — shared standards, imported live into every project
- `project-claude-template-<stack>.md` — per-stack project `CLAUDE.md` templates (typescript, python, go, rust, ansible)
- `bin/sync.sh` — bootstrap (`init`), drift detection (`check`), and re-sync (`update`)
- `test/` — bats suite (`sync.bats`) + vendored `test/bats` submodule
- `.github/`, `docs/` — scaffolding **propagated** into consumer projects (see Propagation Trap)
- `examples/` — reference PRD/ADR worked example, not propagated

**Key decisions:**
- Loading is `@import`-based: consumers' `~/.claude/CLAUDE.md` imports `global-claude.md` by path, so updates flow via `git pull` with no copying.
- `sync.sh` is git-ref-driven and data-driven over the `.github/`+`docs/` trees rather than a hardcoded file list.
- No CI in-repo yet (would need to live outside `.github/` to avoid propagation) — tracked as follow-up.
