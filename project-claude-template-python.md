# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

---

## Stack

Python 3.12+, uv (package management), Docker Compose.

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

## Validation Commands

```bash
docker compose exec app uv run ruff check src/ tests/
docker compose exec app uv run ruff format --check src/ tests/
docker compose exec app uv run mypy src/
docker compose exec app uv run pytest
```

---

## Python-Specific Rules

- **No bare `except:`** — always catch specific exceptions
- **No `os.system()` or `subprocess` with `shell=True`** for untrusted input
- **Prefer standard library** where it's clear and sufficient — do not add dependencies for things Python handles well
- **Use `uv add`** to add dependencies (updates `pyproject.toml` and lockfile together)

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
