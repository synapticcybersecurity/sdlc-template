# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

---

## Stack

Go 1.22+, Docker Compose.

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

- **All commands run inside containers** — never run go/make directly on the host.
  ```bash
  docker compose exec app go test ./...
  docker compose exec app go build ./cmd/server
  ```
- **No host bind mounts by default** — code lives in Docker images. After code changes, rebuild before testing:
  ```bash
  docker compose up -d --build
  ```
- If the project uses bind mounts for dev hot-reload (e.g., with Air), it will be noted in the Project Architecture section below.

---

## Code Style

- **Formatting:** `gofmt` (non-negotiable in Go — code that isn't gofmt'd is wrong)
- **Linting:** golangci-lint with a `.golangci.yml` config
- **Naming:** Go conventions — exported names are PascalCase, unexported are camelCase, acronyms stay uppercase (`HTTPClient`, not `HttpClient`)
- **Package names:** short, lowercase, no underscores — the package name is part of the call site (`http.Get`, not `httputil.HTTPGet`)

---

## Project Layout

Follow the standard Go project structure:
```
cmd/
  server/main.go          # or cli/main.go — one directory per binary
internal/                  # private application code (not importable by other modules)
  handler/                 # HTTP handlers
  service/                 # business logic
  store/                   # database/persistence
  config/                  # configuration loading
pkg/                       # public library code (only if other repos need to import it)
migrations/                # SQL migrations if applicable
Dockerfile
docker-compose.yml
go.mod
go.sum
Makefile
```

- **`internal/` is enforced by the Go compiler** — code here cannot be imported outside this module. Use it for all application code by default.
- **`pkg/` is optional** — only create it if you're building a library other projects will import. Most applications don't need it.
- **One `main.go` per binary** under `cmd/`.

---

## HTTP / API

- **Prefer `net/http` (standard library)** for routing and handlers. Go 1.22+ supports method matching and path parameters: `mux.HandleFunc("GET /users/{id}", handler)`.
- **Use Chi** only if you need middleware chaining or route grouping beyond what the stdlib provides. Do not use Gin or Echo unless the project already does.
- **Handlers should be thin** — parse request, call a service, write response. Business logic belongs in `internal/service/`.
- **Use `encoding/json`** for JSON marshaling. Do not add a third-party JSON library unless benchmarks justify it.

---

## Error Handling

Go has explicit error handling. These rules prevent common mistakes:

- **Always check returned errors** — never use `_` to discard an error unless you document why
- **Wrap errors with context:** `fmt.Errorf("failed to create user: %w", err)` — bare `return err` loses context
- **Do not `log.Fatal` or `os.Exit` in library/service code** — only in `main()`. Return errors up the stack.
- **Use sentinel errors or custom types** for errors callers need to match on (`errors.Is`, `errors.As`). For everything else, `fmt.Errorf` with `%w` is fine.

---

## Testing

- **Framework:** `go test` (standard library). Do not add testify unless the project already uses it.
- **Test files:** alongside source — `handler.go` → `handler_test.go`
- **Table-driven tests** for functions with multiple input/output cases
- **Use `t.Helper()`** in test helper functions so failures report the caller's line number
- **`-race` flag:** run `go test -race ./...` — race conditions are common in Go and this catches them at test time

```bash
docker compose exec app go test -race ./...
docker compose exec app go test -cover ./...
```

---

## Dependency Management

- **Go modules** (`go.mod` / `go.sum`) — always committed
- **Minimal dependencies** — Go's standard library is strong. Do not add a library for something `net/http`, `encoding/json`, `os`, `flag`, or `log/slog` already handles.
- `go mod tidy` after adding or removing dependencies

---

## Validation Commands

```bash
docker compose exec app gofmt -l .
docker compose exec app go vet ./...
docker compose exec app golangci-lint run
docker compose exec app go test -race ./...
docker compose exec app go build ./cmd/...
```

All must pass before marking work complete.

---

## Go-Specific Rules

- **No `init()` functions** unless absolutely necessary (they create hidden global state and make testing harder)
- **No global mutable state** — pass dependencies explicitly (constructor injection or function parameters)
- **Use `context.Context`** as the first parameter for functions that do I/O, and propagate cancellation
- **Use `log/slog`** (Go 1.21+) for structured logging — not `log` or `fmt.Println`
- **Goroutines must have an owner** — if you `go func()`, something must wait for it to finish and handle its errors. No fire-and-forget goroutines.

---

## Project Architecture

<!-- Update this section when you start a new project -->

**Application type:** <!-- e.g., REST API, CLI tool, gRPC service, worker -->

**Key directories:**
<!-- e.g.,
- cmd/server/ — HTTP server entry point
- internal/handler/ — HTTP handlers
- internal/service/ — business logic
- internal/store/ — PostgreSQL persistence
- internal/config/ — environment config
- migrations/ — SQL migrations
-->

**Ports:**
<!-- e.g.,
| Service  | Port |
|----------|------|
| App      | 8080 |
| Postgres | 5432 |
| Redis    | 6379 |
-->

**Key decisions:**
<!-- e.g.,
- Database: PostgreSQL via pgx (no ORM)
- Migrations: golang-migrate
- Router: net/http stdlib
- Config: envconfig or viper
-->
