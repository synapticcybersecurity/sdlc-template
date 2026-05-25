---
number: 001
title: Use a flat JSON file for cache, not SQLite
status: accepted
date: 2026-05-25
deciders: hhoffman
related: examples/prds/standup-digest.md
---

# ADR-001: Use a flat JSON file for cache, not SQLite

> **This is a sample ADR.** It exists in the sdlc_template repo as a worked example, paired with `examples/prds/standup-digest.md`. The decision below would be a real call during implementation of that toy product.

## Context

The Standup Digest tool needs to cache the most recent fetch from GitHub so that:

- Repeated invocations within a short window don't re-hit the API (rate-limit hygiene).
- The tool degrades gracefully when offline — the user can still see *something* before standup if their network is down.

The cache must:

- Store a single record (the most recent fetch) per user.
- Persist between invocations.
- Be readable on macOS and Linux.
- Be inspectable by a human in a pinch ("what did standup see this morning?").
- Be cheap to write — the tool is invoked interactively and latency matters.

The tool itself is a single Go binary, ships with no external dependencies beyond the standard library where possible, and is meant to be installable with `go install` or a one-line `curl | sh` script. Whatever we choose has to fit that distribution model.

## Decision

Cache as a single JSON file at `~/.cache/standup/state.json`. No embedded database. Writes are made atomic by writing to `state.json.tmp` and then `rename(2)`-ing over the target.

## Consequences

**Positive:**

- Zero external dependencies — uses only `encoding/json` from the Go standard library. Cross-compilation stays trivial.
- Cache is human-readable. When standup behavior surprises the user, they can `cat ~/.cache/standup/state.json` and see exactly what was last fetched.
- Atomic write semantics on POSIX filesystems via `rename(2)` — no half-written cache on a crashed process.
- Trivial to reset: `rm ~/.cache/standup/state.json` and re-invoke.

**Negative:**

- Single-record model. If the product ever wants history ("what did my queue look like last Tuesday?"), we have to redesign — that's a new ADR.
- No structured query. To answer "all PRs that ever had failing checks" we'd parse the file in code. Acceptable today; we don't have that need.

**Neutral:**

- The on-disk format will change as the data model evolves. Older cache files become unreadable on schema changes — the tool detects this, logs once, and re-fetches. The cost of a stale-format detection is one extra network call on the first invocation after upgrade.

## Considered alternatives

### Alternative 1: SQLite (via `mattn/go-sqlite3`)

A real embedded database. Would handle multi-record history, schema migrations via `golang-migrate`, and structured queries.

Why not chosen: `mattn/go-sqlite3` requires CGO, which complicates cross-compilation and the `go install` story. The capability gain (history, structured query) isn't tied to any success metric in the PRD. SQLite is the right call once we *want* history; today it's premature complexity.

### Alternative 2: `encoding/gob`

Faster to encode/decode than JSON; smaller on-disk footprint. Used in similar-scope tools.

Why not chosen: not human-readable. A core property of the chosen design is that the user can `cat` the cache when surprised. `gob` removes that affordance for marginal performance gains in a tool invoked once per workday.

### Alternative 3: No cache — always live-fetch

Simplest possible implementation. Run the GraphQL query on every invocation.

Why not chosen: violates the PRD's offline-graceful constraint, and pushes against the "≤ 10 seconds to ready" success metric when the network is slow. A cache also reduces API rate-limit exposure on heavy days.

## Notes

If we later add the history feature this ADR predicts ("what did standup look like last Tuesday?"), file a new ADR that supersedes this one and migrate to SQLite (or DuckDB, if the read patterns warrant it). The migration is straightforward: scan the existing flat-file cache (likely 1 record), seed the new store, point new writes at it. The user-facing CLI doesn't change.
