# Review Checklist

Use this checklist for an independent review. Base the review on `research.md`, `plan.md`, and the changed files only. Do not rely on the coder's narration to decide whether the phase is correct.

## Scope and Traceability
- The change matches the current phase in `plan.md`.
- The deliverables in the phase are present and scoped to the phase.
- The implementation does not drift into out-of-scope work.

## Correctness and Completeness
- The change is complete enough to stand on its own.
- Edge cases and obvious failure paths are handled or explicitly deferred.
- Naming, structure, and interfaces are understandable and stable.

## Verification
- The phase's verification steps were performed or their absence is justified.
- Any tests or checks that should exist are present, or there is a clear reason they are not.
- The result can be validated without asking the coder what they meant.

## Plan and Status Hygiene
- The phase status is accurate.
- Each subtask has a real status.
- Deviations or notes are recorded, or `None` is stated.
- If the phase is not ready to advance, the blocker is explicit.

## Output
- If findings exist, list them with clear actions.
- If no findings exist, state that the phase is ready for the next gate.
