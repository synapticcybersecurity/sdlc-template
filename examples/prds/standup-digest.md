---
title: Standup Digest
status: approved
owner: hhoffman
created: 2026-05-25
last_updated: 2026-05-25
linked_initiative: # would point to an Initiative issue once filed
---

# PRD: Standup Digest

> **This is a sample PRD.** It exists in the sdlc_template repo as a worked example for someone learning the system. The "product" — a CLI that summarizes your daily GitHub state for standup — is real-sized and plausible, but no actual implementation work is tied to this doc.

## Summary

A command-line tool, `standup`, that produces a short text summary of the user's active engineering work — open PRs they've authored, PRs awaiting their review, issues assigned to them, and explicitly flagged blocked items — formatted for use in a daily standup. Single-user, local-only, no server component.

## Problem

Before standup each morning the user cobbles together "what I'm working on" by clicking through GitHub's UI: PRs in one tab, issues in another, mentions in a third. It takes 3–5 minutes and they routinely miss things — usually a stalled PR they forgot about or an issue assigned overnight. Standup itself is then 30 seconds of useful update preceded by 30 seconds of "let me check one more thing."

The unmet need is a low-effort, complete pre-standup snapshot — not just "what I'm working on" (the user knows that) but specifically the things they're likely to have *forgotten*: stalled PRs, overnight assignments, broken checks on yesterday's work.

## Users / Personas

Solo engineers and small-team contributors who already work in GitHub day-to-day. Specifically: someone with 3–10 active PRs across one or two repos at any given time, who participates in a daily standup (synchronous or async). Not aimed at managers, EM-as-coach roles, or non-engineering stakeholders.

## Why now

Two reasons. (1) The user has been late to standup three days running this sprint because they're context-gathering when they should already be ready. (2) GitHub's `gh` CLI recently shipped solid GraphQL support, which makes this kind of cross-cutting query trivial — it's an evening of work, not a weekend.

## Success metrics

- **Time to ready:** ≤ 10 seconds from `$ standup` to a usable summary. Baseline: ~3 minutes manually.
- **Coverage accuracy:** Zero "I forgot to mention" moments in standup over a two-week measurement window. Baseline: ~1 such moment/week (informal observation).
- **Adherence:** Tool is run before standup on ≥ 80% of working days in the first month after ship. Baseline: n/a (new behavior).

## Scope

- Pull open PRs authored by the current user
- Pull PRs where the current user is a requested reviewer (and hasn't reviewed yet)
- Pull issues assigned to the current user, with their current status
- Surface "blocked" items separately: PRs with failing required checks; issues tagged `blocked`
- Print plain text to stdout, terminal-friendly (no required color)
- Read GitHub credentials from `gh` CLI's existing auth — no separate config or token handling

## Non-goals

- **Multi-user or team rollups.** Single user only. A team digest is a different product.
- **Server component, daemon, or scheduled runs.** Run on-demand via the CLI.
- **Posting to Slack / email / web.** Pure terminal output. Pipe to other tools if needed.
- **Notifications or alerts.** No push behavior — the tool is silent unless invoked.
- **Configuration UI or interactive setup.** Zero-config; relies on `gh` auth.
- **Windows support.** macOS / Linux only.

## Constraints

- Solo evening project. Total budget ~ 6 hours of work.
- Must reuse `gh` CLI's existing auth — no new credential handling code paths.
- Single binary, single file, no external services beyond the GitHub API.
- Must degrade gracefully offline (show last cached result with a staleness indicator).

## Risks

- **GitHub API rate limits.** Likelihood: low — single user, infrequent invocation. Mitigation: one GraphQL round-trip per invocation; 5-minute cache.
- **Scope creep into "standup-as-a-service".** Likelihood: medium. Mitigation: explicit Non-goals above; reject feature requests outside listed Scope until v1 ships.
- **Format becomes opinionated and personally idiosyncratic.** Likelihood: low (and accepted — this is a single-user tool).

## Open questions

- Should "blocked" include PRs marked Draft? Leaning yes, but want to use the tool for a week before deciding.
- Cache location: `~/.cache/standup/` or `/tmp/standup-<user>`? Decide on first implementation pass.

## Stakeholders

- Owner / DRI: Harry
- Consulted: none (solo project)
- Informed: none

## Proposed approach

Go binary using the `gh` CLI as a subprocess for the GraphQL query — sidesteps GitHub auth entirely (we shell out to `gh api graphql ...`). One round-trip returns PRs, review requests, and assigned issues. Format with `text/template` from the standard library. Cache the most recent fetch to a single JSON file with a timestamp; check the timestamp on each invocation and use cached output if fresh (or if offline).

Detailed design choices belong in ADRs (see `docs/adrs/`).

## Decomposition hint

- **Epic 1:** Core data model + GraphQL query (fetch and decode)
- **Epic 2:** Output formatting + CLI scaffolding (`standup` command, flags)
- **Epic 3:** Caching + offline handling

Given the small scope, the entire product fits inside one Initiative with three Epics. A larger product would typically have more.

## Related docs

- ADRs: `examples/adrs/001-use-flat-file-cache.md`
- External research: `gh api graphql` docs, GitHub GraphQL `viewer` field
