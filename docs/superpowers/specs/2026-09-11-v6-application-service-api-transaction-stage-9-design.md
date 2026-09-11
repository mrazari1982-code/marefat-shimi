# Clean Rebuild V6 — Application Service / API / Transaction Blueprint — Stage 9

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Application-service, API-contract, command/query, transaction-boundary, concurrency, idempotency, and orchestration blueprint only. No Function/RPC/Edge Function implementation, no SQL execution, no migration execution, no live database changes, no deployment, and no Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 9 of Clean Rebuild V6 for the Marefat Exam System. It defines how clients interact with V6 through safe query paths and trusted domain-command paths, how application services are separated by bounded context, where transaction boundaries sit, which operations must be idempotent, how concurrency is controlled conceptually, which operations are synchronous versus asynchronous, and how downstream effects such as analytics, notifications, AI, and file processing remain outside critical database transactions.

Stages 1–8 remain authoritative. The frozen Question Bank design, Exam Construction design, Question Bank ↔ Exam Construction Crosswalk, lifecycle model, authorization model, and RLS/security blueprint are not reopened here.

Finance / Tuition remains a Protected External Context and is not modified by this stage.

## 2. Architectural Choice

V6 uses a hybrid Application Service architecture:

```text
Safe Queries / Low-risk CRUD
        -> Supabase Data API / safe views
        -> GRANT + RLS

Sensitive Domain Operations
        -> Application Service / Domain Command
        -> Authentication + Authorization
        -> Domain State Validation
        -> Business Validation
        -> Atomic Database Transaction
        -> Domain Audit
        -> Commit
        -> Optional Post-commit Effects
```

V6 does not route every read through a custom backend, and it does not allow sensitive state transitions through arbitrary client CRUD.

## 3. Command / Query Separation

V6 distinguishes:

- **Query** — reads state and does not change authoritative domain state.
- **Command** — expresses a business action that changes domain state or enforces multi-entity invariants.

Examples:

```text
GetMyAssignments   -> Query
GetAttemptDelivery -> Query
GetResult          -> Query

StartAttempt               -> Command
SubmitAttempt              -> Command
PublishExam                -> Command
ApproveQuestionVersion     -> Command
CompleteGrading            -> Command
CompleteRegrading          -> Command
```

This is pragmatic command/query separation, not full CQRS infrastructure.

## 4. When Direct CRUD Is Allowed

Direct Data API CRUD is allowed only when all applicable conditions are true:

1. the operation is low-risk;
2. RLS and constraints can fully protect the operation;
3. no sensitive lifecycle transition is involved;
4. no multi-aggregate or multi-table invariant must be atomically enforced;
5. no privileged server-generated fields must be trusted from the client.

Draft metadata editing and safe read models may qualify.

Sensitive lifecycle transitions do not qualify.

## 5. Mandatory Domain Commands

The following operations are command-oriented and must not be represented as unrestricted client status updates:

### Question Bank
- `SubmitQuestionForReview`
- `ApproveQuestionVersion`
- `RequestQuestionRevision`
- `RetireQuestionVersion`

### Exam
- `PublishExam`
- `RetireExamVersion`

### Assignment
- `EnableAssignment`
- `CloseAssignment`
- `CancelAssignment`

### Attempt
- `StartAttempt`
- `SaveAnswer`
- `SubmitAttempt`
- internal `AutoSubmitAttempt`

### Grading
- `BeginGrading` where required
- `SaveGrade`
- `CompleteGrading`
- `StartRegrading`
- `CompleteRegrading`

### Result
- internal `GenerateResult` / `RefreshResult`
- `ReleaseResult` where manual visibility release is configured

## 6. Standard Command Pipeline

A sensitive command conceptually follows this sequence:

```text
Authenticate
-> Resolve Actor
-> Resolve Organization / Independent Context
-> Resolve Target Resource
-> Enforce Tenant Boundary
-> Authorize Permission + Scope
-> Validate Current Lifecycle State
-> Validate Business Rules
-> Open / enter transaction boundary
-> Apply authoritative mutations
-> Record domain audit
-> Commit
-> Trigger non-critical post-commit effects
-> Return compact command result
```

No client-provided role, actor, organization membership, timestamp, or ownership claim is trusted without server-side resolution.

## 7. Transaction Boundary Principle

A business operation that must be observed as one consistent outcome must execute within one database transaction.

Critical truth is either fully committed or not committed.

Examples of invalid partial outcomes:

- Attempt exists without stable exam-version binding;
- Attempt is submitted without `submitted_at`;
- Exam is marked published while validation/audit failed;
- Grading is completed while the current Result is missing or inconsistent;
- Regrade changes score without revision history.

External notifications, AI work, analytics rebuilds, and file processing are not critical truth and do not belong inside these critical transactions.

## 8. StartAttempt Transaction

`StartAttempt` is one of the most sensitive transactions.

Within one atomic operation it must conceptually:

1. resolve authenticated participant;
2. resolve Assignment;
3. verify Assignment state and computed availability;
4. verify audience eligibility;
5. verify participant/account/profile validity;
6. verify attempt policy and current attempt count;
7. protect against concurrent duplicate starts;
8. bind the stable Published Exam Version;
9. set authoritative `started_at`;
10. calculate authoritative `deadline_at`;
11. create the Attempt;
12. record required domain audit/event metadata;
13. commit.

A failed check produces no partially created Attempt.

## 9. Attempt Concurrency

V6 must prevent double creation caused by double-click, network retry, or multiple tabs.

The implementation may use a suitable combination of:

- uniqueness constraints;
- row locking;
- advisory or equivalent locking where justified;
- transactional attempt-count enforcement;
- idempotency keys;
- application-level conflict handling.

The exact SQL mechanism is deferred to implementation planning, but the invariant is frozen:

> Concurrent StartAttempt requests must not violate the Assignment attempt policy.

Global SERIALIZABLE isolation is not required by default.

## 10. StartAttempt Idempotency

`StartAttempt` must be retry-safe.

If a client times out after the server successfully created an Attempt, retrying the same logical start must not create an extra Attempt contrary to policy.

Implementation may use an idempotency key and/or domain uniqueness that maps repeated equivalent starts to the existing valid Attempt.

## 11. SaveAnswer

Answer saves are short independent transactions rather than one transaction covering the entire exam session.

A save must validate at minimum:

- participant owns/is authorized for the Attempt;
- Attempt is `IN_PROGRESS`;
- authoritative server time has not crossed `deadline_at`;
- `exam_question_entry_id` belongs to the Attempt's fixed Exam Version;
- a selected option, if supplied, belongs to the correct Question Version;
- submitted/finalized Attempts cannot be mutated by the participant.

This design supports intermittent connectivity and resume behavior.

## 12. SubmitAttempt Transaction

`SubmitAttempt` conceptually:

1. loads Attempt;
2. resolves/validates participant authorization;
3. verifies current state;
4. handles deadline/finalization rules;
5. preserves valid saved answers;
6. sets authoritative `submitted_at`;
7. records submission type/reason server-side;
8. performs `IN_PROGRESS -> SUBMITTED`;
9. establishes downstream grading work as required;
10. writes domain audit;
11. commits.

The participant cannot directly write submission timestamps, submission type, final score, or grading state.

## 13. Submit Idempotency

`SubmitAttempt` is safe to retry.

First valid call:

```text
IN_PROGRESS -> SUBMITTED
```

A retry after a successful commit does not create a second submission or corrupt the Attempt. It should return the already-finalized valid outcome or an equivalent idempotent response.

## 14. Manual and Automatic Submission

Manual submission and deadline auto-submit share the same core finalization semantics.

```text
FinalizeAttempt
  -> manual participant trigger
  -> system deadline trigger
```

They differ through trusted metadata such as submission reason/type, not through divergent final-state logic.

`AutoSubmitAttempt` is internal/system-only and is not exposed to the client as a callable privileged operation.

## 15. PublishExam Transaction

`PublishExam` conceptually:

1. loads the target Exam Version;
2. checks `DRAFT` state;
3. verifies `exam.publish` authorization and scope;
4. validates exam identity and required metadata;
5. validates at least one valid exam question entry;
6. validates stable approved/usable Question Version references;
7. validates ordering, sections, and exam-specific scores;
8. validates total score consistency and frozen construction rules;
9. freezes the published configuration;
10. performs `DRAFT -> PUBLISHED`;
11. sets trusted publish actor/time metadata;
12. writes domain audit;
13. commits.

Published content is not edited in place after commit.

## 16. Question Approval Transaction

`ApproveQuestionVersion` conceptually:

1. loads Question Version;
2. verifies `IN_REVIEW`;
3. checks reviewer permission and scope;
4. enforces self-approval restriction required by the frozen Question Bank workflow;
5. validates question integrity and required metadata;
6. performs `IN_REVIEW -> APPROVED`;
7. records reviewer/action audit;
8. commits.

The client never directly sets `status = APPROVED`.

## 17. Assignment Commands

Draft Assignment data may be edited through safe controlled CRUD where appropriate.

`EnableAssignment` is a command because it activates the possibility of new Attempts and must validate:

- referenced Exam Version is Published and usable;
- audience definition is valid;
- availability window is valid;
- attempt policy is valid;
- result visibility configuration is valid;
- actor authorization and scope are valid.

`CloseAssignment` prevents new Attempts and does not destroy existing active Attempts.

`CancelAssignment` must evaluate existing Attempts. If real Attempts have already started, cancellation may be denied and Close may be the valid operation according to Stage 6.

## 18. Grading Transactions

Grading belongs to Grading Service and never mutates Result directly from the client.

### SaveGrade

A grade save validates:

- grading permission;
- grader scope;
- submitted Attempt;
- valid Grading Case;
- Answer belongs to that case/Attempt;
- awarded score is within allowed bounds;
- concurrency/revision expectations.

### CompleteGrading

`CompleteGrading` conceptually:

1. verifies required Answer Grades are complete;
2. computes authoritative grading totals;
3. transitions Grading Case to `COMPLETED`;
4. generates or refreshes the current Result consistently;
5. writes audit;
6. commits.

For MVP, Result generation is synchronous inside the critical grading-completion transaction so the system does not expose `Grading COMPLETED` with a missing current Result.

## 19. Regrading

Regrading is revision-aware.

```text
StartRegrading
-> create/open Grading Revision
-> record revised grade items
-> CompleteRegrading
-> close revision
-> recompute/refresh Result
-> audit
```

Direct manual editing of `exam.results` remains forbidden.

## 20. Result Service

Result is derived from Grading truth.

Result Service does not accept client-supplied final score as authoritative input.

`ReleaseResult`, when manual visibility release exists, changes result visibility/release state or policy outcome only. It does not edit the score.

The invariant remains:

> One current Result projection per Attempt, backed by completed grading truth.

## 21. Analytics Boundary

Analytics is downstream and non-authoritative.

```text
Attempt / Grading / Result truth
-> analytics projections / queries
```

Analytics refresh must not extend the critical Submit/Grading transaction.

A failed analytics refresh does not invalidate a successful Attempt submission, completed grading, or Result.

Analytics may be marked stale and rebuilt asynchronously.

## 22. Synchronous vs Asynchronous Work

### Synchronous operations

Used when the user needs an immediate authoritative outcome, such as:

- StartAttempt;
- SaveAnswer;
- SubmitAttempt;
- PublishExam;
- ApproveQuestionVersion;
- EnableAssignment;
- SaveGrade;
- CompleteGrading.

### Asynchronous / post-commit work

Appropriate for:

- large document/image imports;
- AI extraction/generation;
- notifications;
- report exports;
- analytics rebuilds;
- non-critical integrations.

No long-running external work should hold an open database transaction.

## 23. External Side Effects and Outbox

External calls such as email/SMS/AI/webhooks do not execute inside the critical database transaction.

Where delivery reliability matters, V6 may use a transactional Outbox pattern:

```text
Domain mutation
+ Outbox event record
= one DB transaction

commit
-> background processor
-> external side effect
```

Possible events include:

- `EXAM_PUBLISHED`
- `ASSIGNMENT_ENABLED`
- `ATTEMPT_SUBMITTED`
- `RESULT_FINALIZED`

V6 is not Event Sourcing. Current relational/domain state remains source of truth.

## 24. Database Function vs Edge Function

### Database Function / RPC candidate

Preferred when work is:

- data-intensive;
- strongly transactional;
- close to PostgreSQL state;
- atomic across multiple tables;
- not dependent on slow external services.

Candidate examples include StartAttempt, SubmitAttempt, and grading finalization.

### Edge Function candidate

Preferred when work requires:

- external APIs;
- AI services;
- file/document processing orchestration;
- notifications;
- webhooks;
- multi-service coordination;
- explicit rate limiting or public API orchestration.

The exact split is deferred to implementation planning and may evolve without changing the frozen domain contracts.

## 25. Function Security

`SECURITY INVOKER` is the default preference for callable database functions.

`SECURITY DEFINER` is exceptional and requires explicit security justification, carefully controlled search path, minimal execution grants, non-exposed placement where practical, and explicit actor/authorization checks where privileged access is involved.

A privileged function must not become an accidental bypass of Stage 7 authorization or Stage 8 RLS boundaries.

## 26. Application Service Boundaries

V6 avoids a single mega-service.

Logical services include:

- QuestionBankService
- ExamConstructionService
- AssignmentService
- AttemptService
- GradingService
- ResultService
- AnalyticsService

School Core has its own services such as:

- MembershipService
- EnrollmentService
- TeachingAssignmentService

Exam services may read Core truth through defined contracts but must not mutate Core-owned Student, Enrollment, Class, Teaching Assignment, or Curriculum truth.

## 27. Finance Boundary

Exam application services do not write Finance tables, invoke Finance mutation services, or participate in shared Exam+Finance database transactions.

Finance/Tuition remains unchanged and independently authorized.

Shared Core identity/membership does not merge Exam and Finance business operations.

## 28. Public API Contract Philosophy

Frontend contracts express business intent rather than physical database updates.

Bad conceptual API:

```text
update exam.attempts set status='submitted'
```

Preferred conceptual API:

```text
SubmitAttempt(attempt_id)
```

Command endpoint naming may be HTTP-action-oriented or RPC-based in implementation. Stage 9 freezes behavior, not transport syntax.

## 29. Query Contracts

Queries are resource/read-model oriented and may be served through safe Data API queries, security-invoker views, or Query Services.

Examples:

- `ListEligibleAssignments`
- `GetAttempt`
- `GetAttemptDelivery`
- `GetResult`
- `ListPendingGradings`
- Student Dashboard read model
- Teacher Dashboard read model
- Admin Exam Overview read model

Read projections are not source of truth and must preserve Stage 7/8 scope rules.

## 30. Minimal Client Input

Clients send only values they genuinely control.

### StartAttempt

Client may provide:

```text
assignment_id
optional idempotency_key
```

Server resolves:

- participant/student/user identity;
- organization context validation;
- Exam Version;
- attempt number/limit;
- `started_at`;
- `deadline_at`.

### SubmitAttempt

Client provides Attempt identity and optional idempotency token. Server resolves submission time/type and current state.

### PublishExam

Client identifies Exam Version. Server resolves actor, organization, publish time, validation, and resulting state.

Fields such as `created_by`, `graded_by`, `published_by`, `is_admin`, `organization_id` proof, and system timestamps are never trusted solely because the client supplied them.

## 31. DTO / Projection Boundary

Domain entities are not automatically exposed as frontend payloads.

Examples:

### Student Exam Delivery DTO

May include:

- exam title;
- current server/attempt timing data;
- question text;
- answer options safe for participant;
- existing saved answer;
- order/section information needed for delivery.

Must not include:

- `is_correct`;
- answer key;
- reviewer metadata;
- internal rights/audit details;
- hidden authoring metadata.

### Teacher Grading DTO

May include participant identity needed for grading, question, submitted answer, max score, current awarded score, and feedback fields according to scope.

DTO design must not broaden authorization beyond underlying source data.

## 32. Standard Error Contract

Application services use stable machine-readable error codes, for example:

- `UNAUTHENTICATED`
- `PERMISSION_DENIED`
- `OUTSIDE_SCOPE`
- `RESOURCE_NOT_FOUND`
- `INVALID_STATE`
- `VALIDATION_FAILED`
- `CONFLICT`
- `ATTEMPT_LIMIT_REACHED`
- `EXAM_NOT_OPEN`
- `DEADLINE_PASSED`
- `ALREADY_SUBMITTED`

Internal errors may be more specific than user-facing messages.

Where useful for information-disclosure resistance, an unauthorized cross-tenant resource may be presented to the client as generic `NOT_FOUND` while the security/audit logs retain the real denial reason.

## 33. Command Result Envelope

A command response should be compact and authoritative.

Candidate success fields:

```text
success
resource_id
new_state
server_time
request_id
```

Candidate failure fields:

```text
success=false
error_code
message
request_id
```

The exact transport schema is deferred.

## 34. Server Time

Server time is authoritative for deadline-sensitive behavior.

Responses may include `server_time` to help clients display a more accurate countdown, but client clocks never determine validity of SaveAnswer, SubmitAttempt, Assignment availability, or auto-submit.

## 35. Optimistic Concurrency

Mutable drafts and collaborative operational data may use optimistic concurrency tokens such as `updated_at` or an explicit revision/version token.

Silent last-write-wins should be avoided where concurrent edits can lose another user's changes.

Published/Approved content does not rely on optimistic edit concurrency because it is immutable and changes through new versions.

Grading writes should also protect against uncontrolled simultaneous overwrites.

## 36. Long-running Imports and AI

Bulk Word/PDF/Image/AI workflows are not implemented as one long HTTP request holding a database transaction.

Frozen flow remains:

```text
Create Import Batch
-> upload/analyze/extract
-> staging items
-> validation/review
-> accepted-item canonical commit
```

AI-generated content always enters staging/draft/review flow and never writes directly to Approved canonical Question content.

## 37. Transaction Isolation Strategy

V6 does not mandate one global isolation level for every operation.

Most ordinary work may use normal PostgreSQL transaction semantics, while concurrency-sensitive operations use the narrowest necessary locking/constraint strategy.

Attempt-limit enforcement, publish transitions, grading completion, and other state-sensitive operations must be concurrency-safe.

The exact implementation mechanism is deferred to the implementation plan and tests.

## 38. Database Constraints Remain Authoritative Guardrails

Application services do not replace database constraints.

Constraints continue to enforce structural invariants such as:

- foreign-key integrity;
- unique business keys;
- one valid answer per Attempt + Exam Question Entry where applicable;
- one current Result per Attempt;
- unique question order within an Exam Version;
- valid nonnegative/range-constrained scores where appropriate.

Application validation exists alongside database constraints to provide domain-aware behavior and useful errors.

## 39. No Frontend-orchestrated Transactions

The client must not simulate an atomic domain operation through a sequence such as:

```text
insert Attempt
update Assignment
insert audit
update state
```

and assume all-or-nothing behavior.

The authoritative transaction begins and ends in the trusted service/database command boundary.

## 40. Logging and Audit

Technical logging and Domain Audit remain distinct.

### Technical request logging may include

- request/correlation ID;
- actor user ID;
- organization context;
- command/query name;
- target resource ID;
- result/error code;
- duration.

Sensitive tokens, passwords, answer keys, and unnecessary raw answer content are excluded from technical logs.

### Domain Audit records business facts such as

- Question Version approved;
- Exam Version published;
- Assignment enabled/closed;
- Attempt submitted;
- Grading completed;
- Regrade completed;
- Result released.

Critical domain audit should commit in the same transaction as the state transition it describes.

## 41. Internal vs Client-callable Operations

Every operation is internal by default unless explicitly exposed.

Examples normally internal:

- AutoSubmitAttempt;
- GenerateResult/RefreshResult when invoked from Grading;
- analytics refresh;
- outbox dispatch;
- system maintenance.

The browser/mobile client cannot claim SYSTEM identity or directly invoke privileged internal operations unless a separately approved public contract exists.

## 42. Rate Limiting

RLS is not rate limiting.

Public/server-facing operations such as login-adjacent actions, StartAttempt, SubmitAttempt, AI generation, file processing, and other abuse-sensitive endpoints may require rate limiting at the Application/API/Edge boundary.

Rate-limit implementation details are deferred.

## 43. Independent Users

Independent users reuse the same domain commands where behavior is the same.

For example, an Independent Learner may still use `StartAttempt`; the authorization resolver follows independent-user scope instead of School Membership/Enrollment.

V6 avoids duplicating services solely because the actor is school-based versus independent.

## 44. Dependency Direction

Exam services consume School Core read contracts such as:

- Membership resolution;
- Student Profile;
- Enrollment;
- Teaching Assignment;
- Curriculum.

Exam does not mutate Core truth.

Conceptually:

```text
School Core -> provides truth/contracts -> Exam Services
```

School Core remains operationally independent of Exam Core.

## 45. MVP Public Command Set

Recommended client-callable command surface for MVP:

### Question Bank
- SubmitQuestionForReview
- ApproveQuestionVersion
- RequestQuestionRevision

### Exam
- PublishExam

### Assignment
- EnableAssignment
- CloseAssignment
- CancelAssignment

### Attempt
- StartAttempt
- SaveAnswer
- SubmitAttempt

### Grading
- SaveGrade
- CompleteGrading
- StartRegrading
- CompleteRegrading

### Result
- ReleaseResult where the configured visibility workflow requires it

Internal-only examples:

- AutoSubmitAttempt
- GenerateResult/RefreshResult
- analytics rebuild/refresh
- background outbox processing

This surface may later be narrowed further during implementation if direct CRUD plus RLS can safely handle specific draft operations.

## 46. Non-goals of Stage 9

Stage 9 does not define or implement:

- exact HTTP URLs;
- exact RPC/function names;
- PL/pgSQL or TypeScript code;
- Edge Function file structure;
- request JSON schema details;
- concrete PostgreSQL locking syntax;
- indexes;
- retry counts/timeouts;
- deployment topology;
- live Supabase configuration;
- Finance/Tuition service changes.

These are derived later from the frozen blueprints, Validation Matrix, and Final Implementation Plan.

## 47. Freeze Rules

1. V6 uses hybrid Query/Command architecture.
2. Safe reads and low-risk CRUD may use Data API + RLS.
3. Sensitive lifecycle transitions use trusted Domain Commands.
4. Client may not directly assign sensitive lifecycle statuses.
5. Query and Command intent remain distinct.
6. Transaction boundary follows the atomic business operation.
7. Atomic commands commit all critical truth together or none.
8. StartAttempt is atomic.
9. Attempt-limit concurrency is enforced by transaction/constraint strategy.
10. StartAttempt is retry-safe/idempotent.
11. SubmitAttempt is retry-safe/idempotent.
12. Manual and auto-submit share core finalization semantics.
13. Auto-submit is system/internal only.
14. Answer Save uses short independent transactions.
15. Server time controls deadlines and sensitive timestamps.
16. PublishExam is atomic and revalidates the draft at publish time.
17. Question Approval is atomic and respects self-approval restrictions.
18. EnableAssignment is a Domain Command.
19. CloseAssignment does not destroy active Attempts.
20. CancelAssignment is controlled when Attempts exist.
21. CompleteGrading produces/refreshes consistent Result truth.
22. Regrading always uses revision history.
23. Result is not directly editable.
24. Analytics remains outside critical domain transactions.
25. External calls do not execute inside critical DB transactions.
26. Important side effects may use transactional Outbox.
27. V6 is not Event Sourcing.
28. Database Functions/RPC are preferred candidates for close-to-DB transactional operations.
29. Edge Functions are preferred candidates for external orchestration/integration.
30. SECURITY INVOKER is the default function-security preference.
31. SECURITY DEFINER is exceptional and security-reviewed.
32. RPC/functions do not bypass Stage 7 authorization rules.
33. Application Services align with Bounded Contexts, not actor-specific duplicate services.
34. Exam services may read but not mutate School Core truth.
35. Exam and Finance never share a business transaction in Stage 9.
36. Public Command APIs are action-oriented.
37. Query contracts are resource/read-model oriented.
38. Client inputs are minimal and untrusted for ownership/actor/system metadata.
39. Actor, organization validation, and sensitive timestamps are server-resolved.
40. Domain entities are not automatically frontend DTOs.
41. Student delivery never exposes answer keys/correctness metadata.
42. Services use stable machine-readable error contracts.
43. Concurrency conflicts are explicitly handled.
44. Draft editing uses optimistic concurrency where useful.
45. Long-running import/AI work does not hold long DB transactions.
46. AI output enters staging/draft/review before canonical approval.
47. Database constraints remain alongside Application validation.
48. Frontend does not orchestrate pseudo-transactions across multiple requests.
49. Sensitive commands use structured technical logging.
50. Domain audit is separate from technical logging.
51. Critical audit commits with the corresponding state transition.
52. Client-callable operations are allowlisted; internal operations are private by default.
53. RLS does not replace rate limiting.
54. Independent users reuse the same domain commands where behavior is shared.
55. Finance/Tuition receives no service, API, transaction, or schema changes in Stage 9.

## 48. Mental Map

```text
                          V6 CLIENT
                              |
                    +---------+---------+
                    |                   |
                  QUERY               COMMAND
                    |                   |
                    v                   v
             Data API / View      Application Service
                    |                   |
                   RLS            Authentication
                                        |
                                        v
                                  Authorization
                                        |
                                        v
                                  Domain State
                                        |
                                        v
                                   Validation
                                        |
                                        v
                                   TRANSACTION
                              +---------+---------+
                              |         |         |
                           Mutation   Audit    Constraints
                              |         |         |
                              +---------+---------+
                                        |
                                      COMMIT
                                        |
                            +-----------+-----------+
                            |                       |
                         Response               Post-commit
                                                Analytics
                                                Notification
                                                Export
                                                AI/File Work
```

End-to-end exam flow:

```text
Question Bank
    -> Approved Question Version
    -> Exam Draft
    -> PublishExam
    -> Published Exam Version
    -> EnableAssignment
    -> StartAttempt
    -> SaveAnswer
    -> Submit / AutoSubmit
    -> Grading
    -> CompleteGrading
    -> Result
    -> Analytics

School Core -> Exam read contracts only
Finance / Tuition -> Protected / No Change
```
