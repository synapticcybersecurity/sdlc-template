---
title: <Short product/feature name>
status: draft  # draft | review | approved | superseded
owner: <name or GitHub handle>
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
linked_initiative: # GitHub issue link, filled in after the Initiative is created
---

# PRD: <Short product/feature name>

> A PRD describes **what** we are building and **why**. It is not a design document — implementation choices belong in ADRs (`docs/adrs/`) and design docs (`docs/design/`).

## Summary

One or two paragraphs. Someone with no context should understand the shape of the work from this section alone.

## Problem

What problem are we solving? Be specific about who is hurting and how. Avoid solution-language here ("we should add X") — describe the unmet need.

## Users / Personas

Who has this problem? Name one or two concrete examples (real users, real teams, real personas — not generic "users"). Note their context: what they're trying to do when they hit this problem.

## Why now

What changed that makes this the right time? A new constraint, a new opportunity, a recent incident, a market shift, a regulatory deadline. If nothing changed, say so — that's a signal worth surfacing.

## Success metrics

How will we know it worked, in 3–6 months? Each metric should be (a) observable and (b) tied to the problem above. Avoid vanity metrics.

- Metric 1: <observable, with baseline and target>
- Metric 2: <observable, with baseline and target>

## Scope

What is included. List the user-visible outcomes, not the implementation steps.

- Outcome 1
- Outcome 2

## Non-goals

What this explicitly does **not** do. This section is as important as Scope — it's how you prevent scope creep mid-implementation.

- Non-goal 1
- Non-goal 2

## Constraints

Time, budget, team size, regulatory, compatibility, performance budget, etc. Anything that bounds the solution space.

## Risks

What could break or go wrong. For each, note the likelihood and the mitigation (or "accepted").

- Risk 1: <description> — likelihood: <low/med/high> — mitigation: <plan or "accepted">

## Open questions

Things we don't yet know and need to answer before or during implementation. Track them here until resolved (then update or move to a decision log).

- Question 1
- Question 2

## Stakeholders

Who needs to be informed, consulted, or have decision authority. Use the RACI shorthand if useful.

- <name / role> — <responsible / accountable / consulted / informed>

## Proposed approach

High-level direction only — not a design. Identify the major moving pieces, integration points, and any architectural choices that shape the solution space. Detailed design belongs in ADRs.

## Decomposition hint

If you already have a sense of how the work decomposes into Epics, list them here. This becomes the starting point for the decomposition step (after PRD approval), where Claude proposes the actual Epic and Story issues.

- Epic 1: <short name>
- Epic 2: <short name>

## Related docs

- ADRs: <link or `docs/adrs/NNN-...`>
- Design docs: <link>
- Prior PRDs: <link>
- External research: <link>
