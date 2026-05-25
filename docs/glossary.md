# Work Tracking Glossary

Defines the work-item hierarchy, the templates that go with each level, and the labels that identify them in GitHub. Every project bootstrapped from `sdlc_template` gets this file — edit it locally if your project's conventions diverge, but expect `sync.sh check` to flag the drift.

## Hierarchy

| Level | Scope | Typical duration | Has PRD? | Issue template |
|---|---|---|---|---|
| **Initiative** | Multi-quarter strategic direction | Quarters | Always | `.github/ISSUE_TEMPLATE/initiative.md` (+ `docs/prds/<slug>.md`) |
| **Epic** | Multi-week deliverable laddering into an Initiative | 2–8 weeks | Sometimes | `.github/ISSUE_TEMPLATE/epic.md` |
| **Story** | A user-visible change, shippable as a unit | 1–5 days | No | `.github/ISSUE_TEMPLATE/story.md` |
| **Task** | Subordinate work under a Story, or a standalone chore | Hours–1 day | No | `.github/ISSUE_TEMPLATE/task.md` |

The existing **Bug**, **Refactor**, and **Security** templates are orthogonal to this hierarchy — any of them can be sized as a Story or a Task. Use the dedicated templates (`bug_report.md`, `refactor.md`, `security.md`) when those types apply.

## Relationships

```
Initiative ──┬── Epic ──┬── Story ──── Task
             │          ├── Story ──── Task
             │          └── Story
             └── Epic ──── Story ──── Task
```

Parent–child links are created in GitHub using sub-issues (the **+ Add sub-issue** button on an issue). Tasks may also be standalone (chores, infrastructure work) without a Story parent.

## Labels

| Label | When to apply |
|---|---|
| `type:initiative` | On every Initiative |
| `type:epic` | On every Epic |
| `type:story` | On every Story |
| `type:task` | On every Task |
| `bug` | Defect or regression (orthogonal — applies in addition to a hierarchy label) |
| `enhancement` | New capability |
| `refactor` | Internal change with no behavior change |
| `security` | Security-sensitive change |

The `type:*` labels are mutually exclusive: an issue is exactly one of Initiative / Epic / Story / Task. Domain labels (`bug`, `security`, etc.) are independent and can stack with the hierarchy label.

## Lifecycle

```
Idea
  └─► Discovery (Q&A — see docs/discovery-qa.md)
        └─► Draft PRD (docs/prds/<slug>.md)
              └─► PRD review (via PR)
                    └─► Initiative issue created, links the PRD
                          └─► Decomposition (Claude proposes Epics + Stories)
                                └─► Human review of proposed issues
                                      └─► Issues filed via gh
                                            └─► Stories enter normal commit/PR pipeline
```

For ideas small enough to fit in a single Epic, the Initiative + multi-Epic structure may be overkill — but you should still write a short PRD. The Q&A playbook can produce a lighter PRD when the idea is small.

## Artifacts

| Artifact | Location | Source template |
|---|---|---|
| Discovery Q&A playbook | `docs/discovery-qa.md` | Same — copied in from sdlc_template, generic across projects |
| PRDs | `docs/prds/<slug>.md` | `docs/templates/prd-template.md` |
| ADRs (Architecture Decision Records) | `docs/adrs/NNN-<slug>.md` | `docs/templates/adr-template.md` |

ADRs capture significant technical decisions made during implementation — they are the engineering-side complement to PRDs (product-side). Number them sequentially starting at `001`.
