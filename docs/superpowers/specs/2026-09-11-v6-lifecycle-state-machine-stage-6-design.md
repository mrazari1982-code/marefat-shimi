# Clean Rebuild V6 — Lifecycle / State Machine Design — Stage 6

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Domain lifecycle and state-machine design only. No migration execution, no live database changes, no RLS implementation, no API implementation, no deployment, and no Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 6 of Clean Rebuild V6 for the Marefat Exam System. It defines persisted lifecycle states, computed operational states, legal/illegal transitions, transition triggers, immutability boundaries, concurrency expectations, audit expectations, and end-to-end behavior for Question Bank, Exam Construction, Assignment, Attempt, Grading, Result, and selected School Core lifecycles.

Stages 1–5 remain authoritative. The frozen Question Bank design, Exam Construction design, and Question Bank ↔ Exam Construction Crosswalk remain authoritative and are not reopened here.

Finance / Tuition remains a Protected External Context and is not modified by this stage.

## 2. Core State-Machine Principles

V6 separates three concepts:

- Persisted lifecycle state
- Computed operational state
- Business events / transition triggers

State changes occur only through explicit domain transitions. UI or clients must not freely assign arbitrary status values.

Examples:

- `PublishExam` may perform `DRAFT -> PUBLISHED` after validation.
- A published version must not be reverted in place to `DRAFT`.
- A time window such as `UPCOMING / OPEN / ENDED` may be computed from timestamps rather than persisted and constantly updated.

Server time is authoritative for deadline-sensitive exam behavior.

## 3. Question Aggregate Lifecycle

Question identity has a simple lifecycle:

`ACTIVE -> ARCHIVED`

Archive means the question should not be selected for new use, but historical identity, versions, exam references, grading evidence, and results remain valid.

Archive is not destructive delete.

## 4. Question Version Lifecycle

Canonical lifecycle:

```text
DRAFT
  |
  v
IN_REVIEW
  |----------------------> REVISION_REQUESTED
  |                              |
  |                              v
  |                            DRAFT
  |
  v
APPROVED
  |
  v
RETIRED
```

### 4.1 DRAFT

Editable version content may include question text, options, answer key, explanation, difficulty, curriculum classification, source/rights metadata, and other version-specific fields defined by the frozen Question Bank design.

### 4.2 IN_REVIEW

The version is under review. Author-side content editing should be locked or otherwise controlled so the reviewer evaluates a stable candidate.

Allowed outcomes:

- `IN_REVIEW -> APPROVED`
- `IN_REVIEW -> REVISION_REQUESTED`

### 4.3 REVISION_REQUESTED

The version requires correction and may return to draft:

`REVISION_REQUESTED -> DRAFT`

### 4.4 APPROVED

An approved Question Version is immutable in place for historical integrity.

Corrections produce a new Question Version rather than rewriting the approved one.

### 4.5 RETIRED

A retired Question Version is unavailable for new selection but remains valid for published exams and historical evidence.

### 4.6 Illegal examples

- `APPROVED -> DRAFT` is forbidden.
- `RETIRED -> DRAFT` is forbidden.
- Review approval must respect authorization; the author cannot bypass required review by directly assigning `APPROVED`.

## 5. Exam Aggregate Lifecycle

Exam identity is stable and may use a simple high-level lifecycle such as:

`ACTIVE -> ARCHIVED`

Detailed construction lifecycle is owned by Exam Version.

## 6. Exam Version Lifecycle

MVP lifecycle:

`DRAFT -> PUBLISHED -> RETIRED`

### 6.1 Publish preconditions

Publication requires validation including, at minimum:

- valid exam identity/title;
- at least one valid exam question entry;
- usable/approved Question Versions;
- valid question order;
- valid scoring;
- consistent total score;
- required construction review/approval from the frozen Exam Construction workflow.

### 6.2 Published immutability

Publishing makes the Exam Version a stable snapshot.

A published version must not silently change:

- question list;
- Question Version references;
- ordering;
- exam-specific scores;
- section placement;
- other content-critical published configuration.

Corrections require a new Exam Version.

### 6.3 Retirement

`PUBLISHED -> RETIRED`

Retirement prevents new use but preserves existing Assignment/Attempt/Result history.

A Published Exam Version with active Assignments should not be retired without first resolving/closing those Assignments.

## 7. Assignment Lifecycle

Persisted lifecycle:

```text
DRAFT -> ENABLED -> CLOSED
   \        \
    \        -> CANCELLED
     -> CANCELLED
```

### 7.1 DRAFT

Audience, availability window, attempt policy, result visibility policy, and related assignment configuration may be edited.

Attempts cannot start.

### 7.2 ENABLED

The assignment is administratively active, but its time-based availability is computed separately.

### 7.3 Computed availability

For an enabled assignment:

- `UPCOMING` when `now < available_from`
- `OPEN` when `available_from <= now < available_until`
- `ENDED` when `now >= available_until`

These are computed operational states and do not require scheduled status updates.

### 7.4 CLOSED

Closing prevents new Attempts. Existing in-progress Attempts are not destroyed automatically and continue according to their own deadline unless a future separately approved forced-termination workflow is added.

### 7.5 CANCELLED

Cancellation is appropriate when an Assignment should not proceed. If real Attempts have already started, cancellation should be restricted; closing is generally safer for MVP.

## 8. Eligibility Decision

Eligibility is computed when a participant requests `StartAttempt`; it is not a durable Student/Assignment status.

Checks may include:

- assignment enabled;
- current computed availability is open;
- participant belongs to audience;
- participant/account/student state is valid;
- attempt limit not reached;
- assignment not closed/cancelled.

Decision output may include:

- `ELIGIBLE`
- `NOT_ELIGIBLE` plus a reason such as `NOT_IN_AUDIENCE`, `NOT_OPEN_YET`, `WINDOW_ENDED`, `ATTEMPT_LIMIT_REACHED`, or `ASSIGNMENT_CLOSED`.

## 9. Attempt Lifecycle

MVP persisted lifecycle:

`IN_PROGRESS -> SUBMITTED`

`STARTED`, `RESUMED`, network interruption, and `AUTO_SUBMITTED` are events/metadata, not separate primary persisted states.

### 9.1 StartAttempt

Conceptual transition:

`NO_ATTEMPT -> IN_PROGRESS`

StartAttempt must be atomic:

1. resolve eligibility;
2. enforce attempt policy/limit;
3. bind stable Published Exam Version;
4. set `started_at`;
5. calculate/set `deadline_at`;
6. create the Attempt.

### 9.2 Deadline

A candidate rule is:

`deadline_at = min(started_at + duration, assignment.available_until)`

when assignment policy requires that the participant cannot continue beyond the assignment window. Exact policy details are finalized in policy/service design, but `deadline_at` must be server-authoritative and stable for the Attempt once started.

### 9.3 Network interruption and resume

Disconnect does not change Attempt state.

If the participant reconnects before deadline, the same `IN_PROGRESS` Attempt is resumed.

If server time has reached/exceeded deadline, the server finalizes auto-submit before accepting further answer mutations.

### 9.4 Manual submit

`IN_PROGRESS -> SUBMITTED`

with submission metadata identifying manual participant submission.

### 9.5 Auto-submit

Deadline triggers the same final state:

`IN_PROGRESS -> SUBMITTED`

with submission metadata identifying automatic deadline submission.

V6 intentionally does not use `EXPIRED` as the terminal Attempt state. Deadline expiry finalizes the Attempt into a gradeable submitted state.

### 9.6 Submitted immutability

After `SUBMITTED`, participant answers are immutable unless a future separately approved exceptional recovery workflow is designed.

### 9.7 Idempotency

Submitting an already submitted Attempt must be safe and must not duplicate grading/results. Submit and auto-submit should be safe to retry.

## 10. Answer Lifecycle

Answer does not require a complex enum lifecycle for MVP.

Answer mutations are allowed only while:

- Attempt is `IN_PROGRESS`; and
- server time is before `deadline_at`.

After Attempt submission, participant answer writes are rejected.

Absence of an answer or explicitly blank content may represent blank response; exact physical representation is deferred to implementation.

## 11. Grading Lifecycle

Base lifecycle:

```text
PENDING -> IN_PROGRESS -> COMPLETED
   \---------------------> COMPLETED
```

The direct path supports fully objective automatic grading.

Mixed/descriptive exams generally use:

`PENDING -> IN_PROGRESS -> COMPLETED`

Grading begins only after Attempt is submitted.

A final Result must not be considered valid until required grading is completed.

## 12. Regrading Lifecycle

Regrading extends the grading lifecycle:

`COMPLETED -> REGRADING -> COMPLETED`

StartRegrade requires:

- authorized actor;
- reason;
- revision/audit evidence.

Regrading must not silently overwrite prior grading evidence.

When regrading completes, Result is recomputed/refreshed and downstream analytics is refreshed/rebuilt as needed.

## 13. Result Lifecycle

Conceptually:

`NO_FINAL_RESULT/PENDING -> FINAL`

During regrading:

`FINAL -> RECALCULATING -> FINAL`

Result is derived from Grading. Direct score editing at Result level is forbidden.

If a score must change, the change originates through Grading/Regrading and the Result is regenerated.

Result finality is distinct from Result visibility.

A valid condition is:

- Result state = FINAL
- student visibility = hidden
- staff visibility = allowed

## 14. Result Visibility

Visibility is a policy, not the score lifecycle itself.

MVP policy may support concepts such as:

- hidden;
- visible;
- immediately after grading;
- manual release;
- never shown to participant.

Exact values are finalized in authorization/policy design.

## 15. Analytics Lifecycle

Analytics has no authoritative exam-business state machine.

Analytics projections may be generated, refreshed, invalidated, and rebuilt.

Analytics failure must not invalidate Attempt, Grading, or Result truth.

Analytics never mutates operational exam source-of-truth records.

## 16. Academic Year Lifecycle

Recommended lifecycle:

`PLANNED -> ACTIVE -> CLOSED`

Closing an Academic Year preserves all historical records.

## 17. Enrollment Lifecycle

Recommended MVP lifecycle:

`ACTIVE -> COMPLETED`

or

`ACTIVE -> WITHDRAWN`

For transfer scenarios, MVP may end the old Enrollment and create a new one rather than introducing a complex transfer state machine prematurely.

## 18. Teaching Assignment Lifecycle

Recommended simple lifecycle:

`ACTIVE -> ENDED`

Draft/error correction behavior may use deactivation/archive where needed.

## 19. Immutable-State Rule

In-place destructive mutation is forbidden for critical historical states including:

- approved Question Versions;
- Published Exam Versions;
- submitted Attempts/participant Answers;
- completed grading revisions/history;
- finalized result evidence.

Corrections use versioning, regrading, or explicit follow-on records.

## 20. Audit of State Transitions

Sensitive transitions must be auditable with, at minimum:

- entity;
- from_state;
- to_state;
- actor;
- timestamp;
- reason where applicable.

High-priority examples include:

- Question approval/retirement;
- Exam publication/retirement;
- Assignment close/cancel;
- Attempt manual submit;
- Attempt auto-submit;
- regrade start/complete;
- Result visibility-policy changes.

Transition actor may be a User, System, or scheduled/system process.

## 21. Server Authority and Transactions

Server time is authoritative for deadline-sensitive operations.

Critical transitions should execute atomically where consistency requires it, including:

- StartAttempt;
- SubmitAttempt;
- AutoSubmitAttempt;
- PublishExam;
- CompleteGrading;
- CompleteRegrading / refresh Result.

A multi-step transition must not leave invalid half-states.

Downstream failures should be recoverable. For example, a valid Attempt submission remains valid even if asynchronous grading/result/analytics work must retry.

## 22. Concurrency Rules

Concurrent operations must not create contradictory states.

Example:

- Tab A successfully commits Submit;
- Tab B later attempts SaveAnswer;
- SaveAnswer must fail because Attempt is already submitted.

Implementation may later use transactions, locking, optimistic version checks, or equivalent mechanisms.

## 23. Idempotent Commands

At minimum, these commands should be designed as idempotent or safely retryable:

- SubmitAttempt;
- AutoSubmitAttempt;
- automatic grading completion;
- Generate/Refresh Result.

## 24. Illegal Transition Examples

The following are explicitly invalid:

- `Question Version APPROVED -> DRAFT`
- `Exam Version PUBLISHED -> DRAFT`
- `Attempt SUBMITTED -> IN_PROGRESS`
- participant Answer update after submission
- Grading completion before Attempt submission
- FINAL Result before required grading completion
- Analytics modifying Result/Attempt/Question truth

## 25. End-to-End Exam Lifecycle

```text
Question Version
DRAFT
  -> IN_REVIEW
  -> APPROVED

Exam Version
DRAFT
  -> PUBLISHED

Assignment
DRAFT
  -> ENABLED
  -> [UPCOMING / OPEN / ENDED computed]

Eligibility Check
  -> ELIGIBLE

Attempt
IN_PROGRESS
  -> SUBMITTED

Grading
PENDING
  -> IN_PROGRESS when needed
  -> COMPLETED

Result
  -> FINAL

Analytics
  -> derived/read models
```

## 26. Deadline / Auto-Submit Flow

```text
Attempt IN_PROGRESS
        |
        | server_now >= deadline_at
        v
Stop accepting answer mutations
        |
        v
Finalize saved answers
        |
        v
Attempt SUBMITTED
submission_type = automatic_deadline
        |
        v
Grading may begin
```

## 27. Important Edge Cases

### Network interruption

Before deadline: resume same Attempt.

After deadline: server auto-finalizes; no further participant answer changes.

### Second attempt

Attempt-policy validation occurs before creating a new Attempt. If limit is reached, StartAttempt is rejected rather than creating and deleting an invalid Attempt.

### New Exam Version during active Attempt

Active Attempt remains bound to its original Published Exam Version.

### Closing Assignment during active Attempt

Closing prevents new Attempts but does not destroy already-started Attempts. Existing Attempt uses its own deadline.

### Retiring Question Version

Retirement blocks new use but does not break published/historical exam references.

### Regrading

Regrading produces revision evidence, refreshes Result, and invalidates/refreshes analytics without making Analytics authoritative.

## 28. State Ownership by Context

Each context changes only its own lifecycle state:

- E1 Question Bank -> Question / Question Version lifecycle
- E2 Exam Construction -> Exam / Exam Version lifecycle
- E3 Assignment -> Assignment lifecycle / eligibility decisions
- E4 Delivery -> Attempt / Answer lifecycle
- E5 Grading -> Grading/Regrading lifecycle
- E6 Results -> Result lifecycle / visibility behavior
- E7 Analytics -> analytics projection lifecycle only

One context must not directly mutate another context's authoritative state.

## 29. Finance / Tuition Boundary

Stage 6 introduces no state or transition coupling between Exam and Finance.

Examples intentionally excluded:

- Tuition payment directly changing Attempt state;
- Exam Result changing Finance status;
- Finance workflow controlling Question/Exam/Grading lifecycle.

Finance / Tuition remains a Protected External Context and is unchanged.

## 30. Frozen Decisions

The following decisions are frozen by Stage 6:

1. Persisted lifecycle state is separated from computed time/operational state.
2. State changes occur only through defined domain transitions.
3. Approved Question Version is immutable in place.
4. Changes to approved questions create a new Question Version.
5. Published Exam Version is immutable in place.
6. Changes to published exams create a new Exam Version.
7. Assignment lifecycle is `DRAFT -> ENABLED -> CLOSED/CANCELLED`.
8. Assignment `UPCOMING/OPEN/ENDED` is computed from time.
9. Eligibility is computed at StartAttempt time, not stored as permanent participant state.
10. Attempt lifecycle is primarily `IN_PROGRESS -> SUBMITTED`.
11. Start is an event, not a separate persisted primary state.
12. Resume is not a new state.
13. Network disconnect does not change Attempt state.
14. Deadline produces valid auto-submit.
15. V6 does not use `EXPIRED` as the terminal Attempt state; deadline finalizes to `SUBMITTED`.
16. Manual and automatic submit produce the same final Attempt state with different submission metadata.
17. Participant answers are immutable after submission.
18. Grading starts only after submission.
19. Objective-only grading may complete automatically without manual `IN_PROGRESS` phase.
20. Mixed/descriptive grading supports `PENDING -> IN_PROGRESS -> COMPLETED`.
21. Regrading is revision-aware and audited.
22. Result derives only from Grading.
23. Direct Result score editing is forbidden.
24. Result visibility is separate from result finality.
25. Closing Assignment blocks new Attempts but does not automatically destroy active Attempts.
26. Published Exam Version with active Assignments cannot be retired without resolving those Assignments.
27. Retired Question Version remains valid for historical references.
28. Server time is authoritative for deadlines.
29. Submit, auto-submit, grading completion, and Result generation are designed to be safe to retry/idempotent.
30. Sensitive lifecycle transitions are audited.
31. Each bounded context changes only the lifecycle state it owns.
32. Analytics does not mutate operational Exam truth.
33. Finance/Tuition receives no new Exam lifecycle dependency or transition.

## 31. Explicit Non-Goals

Stage 6 does not implement:

- PostgreSQL enums;
- SQL constraints/triggers/functions;
- APIs/RPCs;
- RLS policies;
- service code;
- cron/schedulers;
- migration files;
- staging or production changes;
- Finance/Tuition changes.

## 32. Mental Map

```text
QUESTION BANK
Question: ACTIVE -> ARCHIVED

Question Version:
DRAFT -> IN_REVIEW -> APPROVED -> RETIRED
             |
             -> REVISION_REQUESTED -> DRAFT

EXAM
Exam Version:
DRAFT -> PUBLISHED -> RETIRED

ASSIGNMENT
DRAFT -> ENABLED -> CLOSED/CANCELLED
         |
         -> time-derived UPCOMING -> OPEN -> ENDED

ATTEMPT
NO ATTEMPT -> IN_PROGRESS -> SUBMITTED
                          /        \
                    manual       deadline/auto

GRADING
PENDING -> IN_PROGRESS -> COMPLETED
                   \------> COMPLETED for fully automatic objective grading
COMPLETED -> REGRADING -> COMPLETED

RESULT
NO FINAL/PENDING -> FINAL
FINAL -> RECALCULATING -> FINAL

ANALYTICS
derived / refreshable / rebuildable

FINANCE / TUITION
PROTECTED — NO CHANGE
```
