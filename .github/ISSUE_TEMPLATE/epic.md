---
name: Epic
about: A multi-week deliverable that ladders into an Initiative
title: "[Epic] "
labels: ["type:epic"]
assignees: []
---

# Summary

One- or two-paragraph description of this Epic.

## Parent Initiative

#<initiative-issue-number> — link to the parent Initiative. Required unless this Epic is genuinely standalone (rare — flag it for discussion if so).

## Linked PRD

`docs/prds/<slug>.md` — optional. Inherit from parent unless this Epic has its own PRD.

## Outcome

What is observably true once this Epic is complete? Describe the changed state of the world, not the work performed.

## Scope

The user-visible outcomes or capabilities included in this Epic.

- Outcome 1
- Outcome 2

## Out of Scope

Explicitly excluded from this Epic — even if related.

- Excluded 1
- Excluded 2

## Acceptance Criteria

Observable, testable conditions that must all be true to mark this Epic complete.

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All child Stories closed

## Child Stories

Use GitHub's **+ Add sub-issue** button to link Stories here as they are filed.

## Dependencies

- Depends on: <issue, ADR, external decision>
- Blocks: <issue>

## Notes

Anything that doesn't fit elsewhere: links to design docs, ADRs in progress, prior art.
