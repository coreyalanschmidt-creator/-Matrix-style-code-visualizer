# Workflow Contract

This is the canonical contract for how work moves through this scaffold. If anything else is ambiguous, read this file first, then `research.md`, then `plan.md`.

## Canonical Artifact Trail

| Artifact | Canonical location | Purpose |
| --- | --- | --- |
| Research brief | `research.md` | Stable problem framing, constraints, risks, and non-goals |
| Execution plan | `plan.md` | Live phase-by-phase contract with status, scope, acceptance criteria, verification, and deviations |
| Workflow contract | `workflow/WORKFLOW.md` | Canonical role boundaries, review rules, status scheme, and deviation format |

Artifact trail:
`research.md` -> `plan.md` -> implement one phase -> independent review -> update `plan.md` -> next phase or revision.

## Role Contract

### Research

- Clarify the problem space, constraints, risks, and decision points.
- Write or refresh `research.md`.
- Stay implementation-light and avoid turning the brief into a plan or code notebook.

### Planner

- Turn `research.md` into a phased execution plan in `plan.md`.
- Define objective, scope, inputs, outputs, acceptance criteria, verification, out-of-scope, and per-phase status.
- Keep phases small enough to finish and review independently.

### Coder

- Implement exactly one phase, or a tightly bounded subset of it, at a time.
- Keep changes scoped to the current phase and report deviations immediately in `plan.md`.
- Mark a phase `Ready for review` only after implementation, self-verification, and deviation logging are complete.

### Reviewer

- Review artifacts and changed files independently of the coder's self-assessment.
- Check correctness, regression risk, plan adherence, and missing tests or docs.
- Produce actionable findings or confirmation that the phase is ready to advance.

## Independent Review Rule

- Reviewer judgment must be based on artifacts and changed files, not on coder narration.
- Coder explanations are advisory only and do not count as evidence.
- A phase cannot be marked `Done` until an independent review pass is complete and blocking findings are resolved.

## Phase Status Scheme

Use the same status values for phases and subtasks in `plan.md`.

- `Not started`: no work has begun.
- `In progress`: active work is underway, but the item is not complete.
- `Ready for review`: implementation, verification, and deviation logging are complete; waiting on independent review.
- `Blocked`: work cannot continue because of an external dependency or unresolved issue.
- `Done`: independent review has passed and any blocking findings are resolved.

## Deviation Log Format

Record deviations in the active phase's `Deviations / notes:` section in `plan.md`.

Use this format for each deviation:

```text
- What changed: ...
  Why: ...
  Impact: ...
  Follow-up: ...
  Decision: ...
```

- `What changed` names the plan item, design choice, or scope shift.
- `Why` explains the constraint, bug, or discovery that forced the change.
- `Impact` states what is affected now and what remains to be adjusted.
- `Follow-up` states whether the plan, tests, or research need revision.
- `Decision` records whether the change is accepted, deferred, or requires further action.

If there were no deviations, write `None`.
