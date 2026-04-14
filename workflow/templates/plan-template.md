# Plan

This plan turns the research brief into a phased execution contract. Keep each phase small enough to finish, verify, and review on its own.

## Plan Controls

- Status values: `Not started`, `In progress`, `Ready for review`, `Blocked`, `Done`.
- Every phase and subtask must have a current status.
- A phase can move to `Ready for review` only after implementation, verification, and deviation logging are complete.
- A phase can move to `Done` only after independent review passes and blocking findings are resolved.
- If there are no deviations, write `None`.

## Status Overview

| Phase | Status | Primary role | Depends on | Exit gate |
| --- | --- | --- | --- | --- |
| Phase 1 - <name> | Not started | Coder + Reviewer | <dependency> | <what makes this phase reviewable> |
| Phase 2 - <name> | Not started | Coder + Reviewer | <dependency> | <what makes this phase reviewable> |

## Phase <N> - <Phase Name>

Status: <Not started | In progress | Ready for review | Blocked | Done>

Objective:
<What this phase is intended to accomplish.>

Inputs:
- <Artifact or dependency>
- <Artifact or dependency>

Scope:
- <In-scope item>
- <In-scope item>

Out of scope:
- <Explicitly excluded item>

Deliverables:
- <Deliverable>
- <Deliverable>

Acceptance criteria:
- <Concrete success condition>
- <Concrete success condition>

Verification:
- <How to self-check the phase>
- <Any review-facing validation>

Subtasks:
| Subtask | Status | Notes |
| --- | --- | --- |
| <Subtask 1> | Not started | <Notes> |
| <Subtask 2> | Not started | <Notes> |

Deviations / notes:
None

## Next Phase Placeholder

Copy the phase block above for each additional phase and keep the status table in sync.
