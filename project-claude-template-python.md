# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

---

## Stack

Python 3.12+, uv (package management), Docker Compose.

---

## Work Tracking

This project uses a hierarchy of Initiative → Epic → Story → Task. The vocabulary, label conventions, and lifecycle diagram are in `docs/glossary.md`. The discovery Q&A playbook is at `docs/discovery-qa.md`. Read both at the start of any session where work-tracking decisions might arise.

**Critical behaviors:**

- When the user describes a new product or feature idea, follow `docs/discovery-qa.md`. The playbook produces a draft PRD at `docs/prds/<slug>.md` via structured Q&A.
- After PRD approval, propose Epics and initial Stories as a markdown draft for user review **before** filing GitHub issues. Use `gh issue create --template <template>.md` only after the user signs off on the proposal.
- When making a non-trivial technical decision during implementation (database choice, framework, schema design, integration approach, deployment model), write an ADR using `docs/templates/adr-template.md` to `docs/adrs/NNN-<slug>.md`. Number sequentially.

Skip discovery for tactical work — bugs, refactors, security fixes, focused stories, or single tasks. Use the appropriate `.github/ISSUE_TEMPLATE/` directly.

If the scope is unclear, ask the user once: *"Is this a focused fix/feature or a multi-week effort that deserves a PRD?"* Then proceed accordingly.

---

## Docker-First Development

- **All commands run inside containers** — never run python/uv/pytest directly on the host.
  ```bash
  docker compose exec app uv run pytest
  docker compose exec app uv run python -m app_name
  ```
- **No host bind mounts by default** — code lives in Docker images. After code changes, rebuild before testing:
  ```bash
  docker compose up -d --build
  ```
- If the project uses bind mounts for dev hot-reload, it will be noted in the Project Architecture section below.

---

## Code Style

- **Formatting and linting:** Ruff (handles both — do not add Black or flake8 separately)
- **Type checking:** mypy with strict mode on new code
- **Naming:** snake_case for functions/variables/modules, PascalCase for classes, UPPER_SNAKE for constants
- **Imports:** sorted by Ruff, stdlib → third-party → local (enforced by `ruff check --select I`)

---

## Type Checking

Python type hints are not enforced at runtime. **Passing tests does NOT mean types are correct.**

Before marking any change complete:
```bash
docker compose exec app uv run mypy src/
```
Must exit 0. If there are pre-existing errors in files you did not touch, flag them to the user.

---

## Project Configuration

- **All config in `pyproject.toml`** — dependencies, tool settings (Ruff, mypy, pytest), build config. Do not scatter config across `setup.cfg`, `mypy.ini`, `.flake8`, etc.
- **Use `src/` layout** — package lives under `src/app_name/`, not at the repo root
- **Centralized settings module** — read environment variables once in `config.py`, validate with Pydantic Settings or dataclasses, export typed config. Do not scatter `os.environ` calls throughout the codebase.

---

## Error Handling

- **Catch specific exceptions** — never a bare `except:` (it swallows `KeyboardInterrupt`/`SystemExit`) and avoid a blanket `except Exception` unless you re-raise. Catch the narrowest type that you can actually handle.
- **Never swallow** — `except ...: pass` (or logging and continuing) hides failures. If you can't handle it, don't catch it; let it propagate.
- **Preserve the chain** — when re-raising as a different type, use `raise DomainError(...) from err` so the original traceback survives. Bare `raise` inside an `except` re-raises the current exception unchanged.
- **Define domain exception types** for errors callers need to distinguish; a shared base class per package lets a boundary handler catch the family.
- **Handle at the boundary** — let exceptions propagate to one place (request handler, task runner, `main`) that logs and maps them to a response/exit code, rather than catching everywhere.

---

## Security

For code handling auth, crypto, secrets, or untrusted input:

- **Parameterize every query.** Pass values as driver parameters (`cur.execute("SELECT … WHERE id = %s", (id,))`) or via the ORM — never build SQL with f-strings, `%`, `.format()`, or concatenation from input.
- **Tokens from `secrets`, never `random`.** `random` is a PRNG, not cryptographically secure; use `secrets.token_urlsafe()` / `secrets.token_bytes()` for tokens, keys, and one-time codes.
- **Compare secrets in constant time.** Use `hmac.compare_digest` for tokens and signatures — never `==`.
- **Never deserialize untrusted input unsafely.** No `pickle.loads`, no `yaml.load` (use `yaml.safe_load`), no `eval`/`exec` on anything input-derived — this extends the Python-Specific ban on `shell=True`.
- **Hash passwords with a vetted KDF** (`argon2-cffi` or `bcrypt`) — never a bare `hashlib` digest.
- **Validate untrusted input at the boundary** with Pydantic, and bound sizes/counts to resist resource exhaustion.
- **Never log secrets** and keep them out of exception messages.

> Related rules elsewhere in this file: **Error Handling** (catch specific exceptions; don't swallow), **Python-Specific Rules** (no `subprocess(shell=True)` on untrusted input), and **Project Configuration** (read secrets from env once in a centralized, validated settings module).

---

## Testing

- **Framework:** pytest (with `uv run pytest`)
- **Test location:** `tests/` directory (not alongside source)
  ```
  tests/
  ├── unit/
  ├── integration/
  └── conftest.py
  ```
- Use fixtures deliberately — prefer explicit setup over deep fixture chains

---

## Dependency Management

- **`pyproject.toml` + `uv.lock`** — both committed; the lockfile pins the resolved graph for reproducible installs.
- **Use `uv add` / `uv remove`** — they update `pyproject.toml` and `uv.lock` together. Don't hand-edit dependency pins.
- **Minimal dependencies** — Python's standard library is broad; don't add a package for something `pathlib`, `datetime`, `json`, `itertools`, or `secrets` already handles well. Every dep is supply-chain surface.
- **Update deliberately** — `uv lock --upgrade` (or a single package) as its own change, and review the `uv.lock` diff; don't let dependency bumps ride along inside an unrelated change.
- **`uv sync --frozen`** in Docker/CI so a build fails on lockfile drift instead of silently resolving new versions.

---

## Validation Commands

```bash
docker compose exec app uv run ruff check src/ tests/
docker compose exec app uv run ruff format --check src/ tests/
docker compose exec app uv run mypy src/
docker compose exec app uv run pytest
```

---

## Python-Specific Rules

- **No `os.system()` or `subprocess` with `shell=True`** for untrusted input
- **Prefer explicit over implicit** — no `import *`; return early over deep nesting; name what a value is, not its type

---

## Project Architecture

<!-- Update this section when you start a new project -->

**Application type:** <!-- e.g., REST API, CLI tool, worker service, automation -->

**Web framework:** <!-- e.g., FastAPI, Flask, none -->

**Key directories:**
<!-- e.g.,
- src/app_name/api/ — route handlers
- src/app_name/services/ — business logic
- src/app_name/models/ — data models
- src/app_name/config.py — settings
-->

**Ports:**
<!-- e.g.,
| Service  | Port |
|----------|------|
| App      | 8000 |
| Postgres | 5432 |
| Redis    | 6379 |
-->

**Key decisions:**
<!-- e.g.,
- Database: PostgreSQL via SQLAlchemy async
- Migrations: Alembic
- Task queue: Celery + Redis
-->
