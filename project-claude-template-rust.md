# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

---

## Stack

Rust (latest stable, edition 2021+), Cargo workspace, Docker Compose.

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

- **All commands run inside containers** — never run cargo directly on the host. Most Rust projects wrap cargo behind a `Makefile` target; prefer it when present.
  ```bash
  docker compose exec app cargo test --workspace
  docker compose exec app cargo build --release
  # or, if a Makefile wraps these:
  docker compose exec app make test
  ```
- **No host bind mounts by default** — code lives in Docker images. After code changes, rebuild before testing:
  ```bash
  docker compose up -d --build
  ```
- Rust rebuilds are slow; if the project uses a bind mount + `cargo watch` (or `cargo-chef`/sccache for layer caching) for dev iteration, it will be noted in the Project Architecture section below.

---

## Code Style

- **Formatting:** `rustfmt` (non-negotiable — code that isn't `cargo fmt`'d is wrong; CI enforces it via `cargo fmt --all -- --check`)
- **Linting:** `cargo clippy --all-targets -- -D warnings` — clippy warnings are errors; do not merge with clippy lints outstanding
- **Naming:** Rust conventions — `snake_case` for functions, modules, variables; `PascalCase` for types, traits, enums, and variants; `SCREAMING_SNAKE_CASE` for consts and statics
- **Edition:** pin the edition in `Cargo.toml` (`edition = "2021"` or later); don't mix editions across workspace crates without reason

---

## Project Layout

Use a Cargo workspace with one crate per concern:
```
Cargo.toml                 # workspace manifest ([workspace] members)
Cargo.lock                 # committed (this is an application/workspace, not a published lib)
crates/
  <name>-core/             # library crate — domain logic, no I/O entry point
    src/lib.rs
  <name>-server/           # binary crate — HTTP/service entry point
    src/main.rs
  <name>-cli/              # binary crate — CLI entry point
    src/main.rs
migrations/                # SQL migrations if applicable
tests/                     # workspace-level integration tests (per crate)
Dockerfile
docker-compose.yml
Makefile
deny.toml                  # cargo-deny config (see Dependency Management)
```

- **Library logic lives in a `*-core` crate** with no binary entry point, so it's unit-testable and reusable across the server/CLI binaries.
- **One binary per `*-server` / `*-cli` crate** (`src/main.rs`); keep `main` thin — parse args/config, build the app, hand off to library code.
- **Commit `Cargo.lock`** — for applications and workspaces the lockfile is part of the build contract. (Only published libraries omit it.)

---

## HTTP / API

- **Prefer `axum`** (with `tower`/`hyper`) for HTTP services unless the project already uses something else. It's the mainstream, well-supported choice and composes with the Tokio ecosystem.
- **Generate OpenAPI with `utoipa`** when the service exposes a documented API.
- **Handlers should be thin** — extract/validate input, call a service function in the `*-core` crate, map the result to a response. Business logic does not belong in handlers.
- **Use `serde` / `serde_json`** for (de)serialization. Derive `Serialize`/`Deserialize` rather than hand-writing impls.

---

## Error Handling

Rust makes error handling explicit. These rules prevent the common mistakes:

- **Library crates use `thiserror`** to define typed, matchable error enums. Callers should be able to handle specific variants.
- **Binary crates use `anyhow`** (or `eyre`) for top-level error propagation with context: `.context("failed to load config")?`.
- **Propagate with `?`** — don't write manual match-and-return when `?` suffices.
- **No `.unwrap()`, `.expect()`, or `panic!` in library/service code.** A panic in a library aborts the caller's process. Return a `Result` instead. `unwrap`/`expect` are acceptable only in tests, in `main()` for genuinely-fatal startup errors (with a descriptive message), and where an invariant is provably impossible (document why).

---

## Async / Concurrency

- **Tokio is the default runtime.** Don't mix async runtimes within a workspace.
- **Spawned tasks must have an owner.** If you `tokio::spawn`, keep the `JoinHandle` and await or abort it — no fire-and-forget tasks whose panics/errors vanish. (Direct analog of "every goroutine needs an owner.")
- **Don't block the async executor** — never call blocking I/O or long CPU work directly in an async fn; use `tokio::task::spawn_blocking`.
- **Prefer message passing (`tokio::sync::mpsc`/`broadcast`) or `Arc<Mutex<…>>`** for shared state; reach for `unsafe`/`Send`+`Sync` hacks never.

---

## Security

> **Work product never leaves this machine or our repositories.** Do not upload or publish
> anything to a hosted third-party surface — including **Claude Code Artifacts**, which
> publish to Anthropic's servers. Private, unlisted or operator-owned destinations are
> still off-limits; the objection is to the off-machine copy existing at all. Deliver
> documents as files in the repo (Markdown in `docs/`, or a generated PDF) instead.
> Pushing to our own git remote is normal workflow and is not affected. See §5 of the
> global standards.

For code handling auth, crypto, secrets, or untrusted input:

- **Treat integer overflow as a bug.** Use checked/saturating/wrapping arithmetic deliberately on any value derived from input; keep debug overflow checks enabled.
- **Compare secrets in constant time.** Tokens, MACs, auth tags, and password-hash outputs go through `subtle`'s `ConstantTimeEq` — never `==`.
- **Zero sensitive memory.** Wrap keys, passwords, and derived key material in `zeroize` / `ZeroizeOnDrop`; avoid leaving plaintext behind `String`/`Vec` reallocations.
- **Never hand-roll crypto.** Use vetted crates; draw randomness from a CSPRNG (`getrandom` / `OsRng`); never reuse a nonce; bind context with AAD where the primitive supports it.
- **Validate and bound untrusted input at the boundary** — sizes, counts, lengths, recursion depth — to resist DoS and resource exhaustion.
- **Never log secrets or plaintext**, and keep them out of error messages.
- **No panics on untrusted-input paths.** Beyond the Error Handling rule, also avoid `unreachable!`/`todo!` and bare slice indexing on anything input-influenced — return a `Result`.

> Related rules elsewhere in this file: **Error Handling** (no `unwrap`/`expect`/`panic!` in library code), **Rust-Specific Rules** (`#![forbid(unsafe_code)]`), and **Validation Commands** (the `clippy -D warnings` / `fmt --check` / `cargo deny` / `cargo audit` gates — wire them into CI, not ad hoc).

---

## Testing

- **Framework:** built-in `cargo test`. Add `cargo-nextest` only if the project already uses it (faster runner, nicer output).
- **Unit tests** live in-module under `#[cfg(test)] mod tests { … }`, next to the code they exercise.
- **Integration tests** live in each crate's `tests/` directory and exercise the public API only.
- **Doctests** — code examples in `///` doc comments are run by `cargo test`; keep them compiling.
- **Async tests** use `#[tokio::test]`.

```bash
docker compose exec app cargo test --workspace
docker compose exec app cargo test --workspace --doc
```

---

## Dependency Management

- **`Cargo.toml` + `Cargo.lock`** — both committed (application/workspace).
- **Minimal dependencies** — the ecosystem is large but every dep is supply-chain surface. Don't pull a crate for something `std` already does well.
- **`cargo-deny`** with a committed `deny.toml` gates licenses and security advisories (`cargo deny check`). Run it in CI and before adding a new dependency.
- **`cargo update` discipline** — update deliberately, not incidentally inside an unrelated change; review lockfile diffs.
- **Feature flags** — keep default features lean; gate optional functionality (e.g. a `postgres` vs `sqlite` backend) behind features rather than separate code paths.

---

## Validation Commands

```bash
docker compose exec app cargo fmt --all -- --check
docker compose exec app cargo clippy --workspace --all-targets -- -D warnings
docker compose exec app cargo test --workspace
docker compose exec app cargo build --release
docker compose exec app cargo deny check         # if deny.toml is present
```

All must pass before marking work complete.

---

## Rust-Specific Rules

- **`unsafe` is opt-in and rare** — avoid it; if genuinely required, isolate it in the smallest possible block with a `// SAFETY:` comment justifying the invariants. Prefer `#![forbid(unsafe_code)]` in crates that don't need it.
- **Structured logging via `tracing`** — not `println!`/`eprintln!` for application output. Instrument async spans where it aids debugging.
- **Derive, don't hand-roll** — `#[derive(Debug, Clone, …)]` for data types; implement traits manually only when the derive is wrong.
- **Prefer borrowing over cloning** — reach for `.clone()` deliberately, not to silence the borrow checker; take `&str`/`&[T]` in function signatures over owned `String`/`Vec` when you only read.
- **Newtypes over primitives** for domain identifiers (`struct UserId(Uuid)`) to get compile-time safety.

---

## Project Architecture

<!-- Update this section when you start a new project -->

**Application type:** <!-- e.g., HTTP API, CLI tool, background worker, WASM library -->

**Key crates / directories:**
<!-- e.g.,
- crates/app-core/ — domain logic, error types, persistence traits
- crates/app-server/ — axum HTTP server (src/main.rs)
- crates/app-cli/ — CLI entry point
- migrations/ — SQL migrations (sqlx)
-->

**Ports:**
<!-- e.g.,
| Service  | Port |
|----------|------|
| Server   | 8080 |
| Postgres | 5432 |
-->

**Key decisions:**
<!-- e.g.,
- DB access: sqlx (compile-time-checked queries), AnyPool for SQLite/Postgres
- Runtime: Tokio multi-threaded
- HTTP: axum + tower
- Config: figment / envy
- Crypto / sensitive subsystems: link the design + threat-model docs here and require reading them before changes
-->
