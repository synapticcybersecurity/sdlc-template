---
name: Story
about: A user-visible change shippable in 1–5 days
title: "[Story] "
labels: ["type:story"]
assignees: []
---

# Summary

One-paragraph description of the user-visible change.

## Parent Epic

#<epic-issue-number> — link to the parent Epic. Stories without a parent Epic are rare; flag if so.

## User-visible Outcome

After this Story ships, what can a user (or operator, or downstream system) do that they couldn't before? Write it from the user's perspective.

## Acceptance Criteria

Observable conditions that must be true to mark this Story complete. These drive the test plan.

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Tests added or updated
- [ ] Documentation updated if behavior or setup changed

## Validation Plan

How will success be verified? Reference automated tests, manual steps, or operational checks.

## Notes

Implementation hints, design references, links to relevant ADRs. Do not put detailed design here — that belongs in an ADR or design doc.

## Dependencies

- Depends on: <issue, ADR, external decision>
- Blocks: <issue>
