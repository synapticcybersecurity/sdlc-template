# Discovery Q&A Playbook

This file is a prompt for **Claude**, not a document for humans to fill in. When the user describes a new product or feature idea at session start, Claude follows this playbook to turn the idea into a draft PRD.

## When to run this

Run this playbook when:

- The user is starting a new project from scratch in this repo, **or**
- The user has an idea for a significant new capability and there's no PRD yet, **or**
- The user explicitly says "let's do discovery" / "walk me through the questions" / similar.

Do **not** run this playbook for small bug fixes, refactors, or tactical work — those go directly to a Story or Task issue. If the scope is unclear, ask the user once: *"Is this a focused feature/fix, or a multi-week effort that deserves a PRD?"*

## Operating rules during discovery

1. **One question at a time.** Discovery questions are layered — the user's answer to question N often reframes question N+1. Do not batch.
2. **Acknowledge briefly, then move on.** No long summaries between questions. The user is here to think, not to read your notes.
3. **Probe when the answer is generic.** If the user says "to help users", ask *which users, doing what, today.* If they say "make it faster", ask *faster than what, measured how.*
4. **Do not steer toward implementation.** This is about problem and outcome, not architecture. If the user starts discussing tech stack mid-discovery, gently note it ("good — I'll capture that as a constraint") and return to the problem space.
5. **Take notes silently.** Track answers in your working memory; do not show running notes back to the user mid-Q&A.
6. **Stop when you have enough.** Not every question is mandatory. If by question 5 the picture is already clear, skip ahead to synthesis and confirm with the user.

## Question sequence

Ask roughly in this order, adapting to what's already been answered.

1. **The seed.** *"Describe the idea in your own words — what would exist after this work that doesn't exist today?"*
2. **The problem.** *"What specific problem does this solve? For whom?"*
3. **Why now.** *"What triggered this — what made it occur to you now, rather than six months ago or six months from now?"*
4. **The users.** *"Who has this problem? Name one or two real people or teams who'd benefit, and what they're trying to do when they hit it."*
5. **Today's workaround.** *"How do they solve this today, even badly? Spreadsheet, manual process, someone else's tool, nothing?"*
6. **Success.** *"In six months, how would you know it worked? What metric or outcome would be visibly different?"*
7. **Non-goals.** *"What should this explicitly NOT do? What's tempting to include but you'd cut?"*
8. **Constraints.** *"What's the ceiling — time, budget, team size, regulatory, compatibility?"*
9. **Stakeholders.** *"Who else needs to weigh in, approve, or be informed?"*
10. **Sizing.** *"Rough order of magnitude: weekend project, month, quarter, multi-quarter?"*
11. **Open questions.** *"What do you not yet know, that you'd want to find out before committing?"*

## After Q&A: synthesize into a draft PRD

When the Q&A is complete (or the user calls it):

1. Determine the slug: a kebab-case short name derived from the seed answer. Confirm with the user.
2. Create `docs/prds/<slug>.md` from `docs/templates/prd-template.md`.
3. Fill in every section using the answers, marking sections with `_TBD_` where the user hasn't given enough to fill them in.
4. **Show the draft to the user** before any further action. Ask them to review and edit. Offer to make specific changes they call out.
5. Do not proceed to decomposition (creating Epics/Stories) until the user explicitly approves the PRD or accepts it as "good enough for now".

## After PRD approval: decomposition

Once the PRD is approved:

1. Propose Epics that cover the PRD's scope. For each Epic, give: short title, outcome, scope summary, rough Story list.
2. Present the proposal as a **draft markdown list** (not as GitHub issues yet).
3. Get user review and edits.
4. Once approved, create the GitHub issues:
   - One Initiative issue (links the PRD).
   - One Epic issue per proposed Epic (sub-issue of the Initiative).
   - Initial Stories per Epic (sub-issues of their Epic).
5. Use `gh issue create` with the appropriate template (`--template initiative.md` etc.) and labels.
6. Report back with the created issue numbers and links.

## Boundary: when discovery becomes design

If during Q&A the user starts answering implementation questions (database choice, framework, deployment target), capture those answers but do **not** put them in the PRD. They belong in ADRs once implementation begins. Tell the user: *"I'll note that as a likely ADR — let's keep the PRD focused on problem and outcome."*
