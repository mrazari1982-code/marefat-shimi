# Clean Rebuild V6 — RLS / Security Policy Blueprint — Stage 8

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Security-policy and RLS blueprint only. No SQL execution, no migration execution, no live database changes, no RLS policy creation, no deployment, and no Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 8 of Clean Rebuild V6 for the Marefat Exam System. It defines the security-policy blueprint for Supabase/PostgreSQL: exposed-schema strategy, GRANT vs RLS responsibilities, authorization-policy families, relationship-scoped access, sensitive command boundaries, view safety, JWT trust boundaries, system operations, audit expectations, and the testing principles required before RLS implementation.

Stages 1–7 remain authoritative. The frozen Question Bank design, Exam Construction design, Question Bank ↔ Exam Construction Crosswalk, lifecycle model, and authorization model are not reopened here.

Finance / Tuition remains a Protected External Context and is not modified by this stage.

## 2. Security Architecture

V6 uses a hybrid defense-in-depth model:

```text
Browser / Mobile App
        |
        v
Supabase Auth
        |
        v
Publishable client credentials + JWT
        |
        +--> Safe Data API operations --> GRANT --> RLS
        |
        +--> Sensitive Domain Commands --> Trusted Backend/RPC --> Domain validation --> Database
```

RLS protects rows reachable through the Data API. GRANT determines whether a database role may invoke an operation at all. Domain commands enforce state transitions and business rules that should not be represented as unrestricted CRUD.

Neither GRANT nor RLS replaces Stage 7 authorization rules or Stage 6 lifecycle validation.

## 3. Foundational Principles

1. **Deny by default.** Missing or incomplete authorization is denied.
2. **`TO authenticated` is authentication, not authorization.** Every exposed operation still requires an ownership, organization, or relationship predicate.
3. **GRANT and RLS are both least-privilege controls.**
4. **Organization isolation is absolute by default.**
5. **Client-supplied identifiers are not trusted as proof of ownership or scope.**
6. **Dynamic authorization relationships are resolved from authoritative database data.**
7. **Sensitive business transitions use trusted commands rather than direct client status updates.**
8. **RLS does not override domain invariants; domain invariants do not replace RLS.**

## 4. Schema Exposure Strategy

Stage 5 defined the logical physical schemas:

```text
auth
core
exam
finance
```

Stage 8 does not require that every schema be exposed through Supabase Data API.

Principles:

- expose only schemas/tables required by client use cases;
- if a schema/table is exposed, enable RLS before granting client access;
- keep internal helper objects and privileged functions in a non-exposed schema when practical;
- Finance schema exposure and policies are explicitly outside this stage.

A future internal schema such as `private` may host carefully reviewed helper functions or internal objects. Stage 8 does not create it.

## 5. Policy Families

V6 groups RLS policy intent into four families:

```text
SELF
RELATIONSHIP_SCOPED
ORGANIZATION_SCOPED_STAFF
INTERNAL_SYSTEM
```

### 5.1 SELF

Used for Student and Independent User data, including own attempts, own answers, and own visible results.

### 5.2 RELATIONSHIP_SCOPED

Used for Teacher, Guardian, and Counselor access where scope derives from authoritative relationships such as Teaching Assignment, Guardian↔Student relationship, or future Counselor Assignment.

### 5.3 ORGANIZATION_SCOPED_STAFF

Used for Admin and Deputy organization-wide operations, still constrained to their active organization membership and applicable permissions.

### 5.4 INTERNAL_SYSTEM

Used for trusted backend/system operations such as auto-submit, result regeneration, and analytics refresh. The client can never claim SYSTEM identity or receive service-role credentials.

## 6. Identity and Membership Resolution

`auth.uid()` identifies the authenticated platform user, but is not sufficient for school-domain authorization.

School access resolves through authoritative data such as:

```text
auth.uid()
  -> active core.memberships
  -> organization
  -> role/permission assignments
  -> profile/domain relationship
```

An `organization_id` supplied by a client is treated only as a request parameter and must be validated against active membership and resource ownership.

## 7. Student Policies

Student scope is `SELF`.

### 7.1 Assignment visibility

A Student may read an Assignment only if all applicable conditions are satisfied, including:

- the assignment belongs to the Student's organization;
- the Student is in the assignment audience directly or through current class/grade/field targeting;
- the assignment is permitted to be visible to the participant.

### 7.2 Attempt access

A Student may read only the Student's own attempts.

Direct client INSERT into `exam.attempts` is not the V6 start mechanism. `StartAttempt` is a trusted command because it must atomically validate eligibility, attempt limits, assignment state, participant identity, fixed published exam version, `started_at`, and `deadline_at`.

### 7.3 Answer access

A Student may read/write answers only for the Student's own `IN_PROGRESS` Attempt while the server-authoritative deadline has not passed.

After submission, participant mutation is denied.

### 7.4 Result access

A Student may read only the Student's own result when the result is valid/final enough for viewing and the result-visibility policy permits Student visibility.

Ownership alone does not bypass visibility policy.

## 8. Teacher Policies

Teacher scope is relationship-derived from `core.teaching_assignments` and the Stage 7 permission model.

A Teacher role alone never grants organization-wide access.

### 8.1 Question Bank

Teacher access may include:

- own draft questions/versions;
- approved shared questions allowed by school Question Bank policy;
- curriculum/course-scoped question discovery tied to Teaching Assignment;
- review/approval only when explicit review permissions and frozen Question Bank workflow allow it.

`SELECT` permission does not imply `UPDATE` permission.

### 8.2 Question Version updates

A Teacher may update only authorized draft content. Approved Question Versions are immutable in place.

Question approval is command-based rather than a raw client status update because it requires review authorization, self-approval prevention, lifecycle validation, and audit.

### 8.3 Exam drafts

A Teacher may access own/scoped Exam drafts as allowed by Stage 7 permissions.

Published Exam Version content is not client-updateable in place.

### 8.4 Publish Exam

`PublishExam` is a trusted domain command. Direct client updates that set publication state are not allowed.

The command must validate permission, Teaching Assignment scope, organization, current Exam Version state, and publication preconditions.

### 8.5 Attempts and grading

Teacher read/grading access is limited to relevant assignment/course/class scope and explicit permissions.

Raw answers are treated as more sensitive than aggregate result visibility.

## 9. Guardian Policies

Guardian scope derives from the authoritative Student↔Guardian relationship.

Conceptually:

```text
auth.uid()
 -> Guardian profile
 -> core.student_guardians
 -> linked Student
 -> eligible result/history projection
```

Default Guardian permissions do not include:

- starting an Attempt for the Student;
- writing or submitting answers;
- grading;
- raw-answer access.

Guardian Result and summary-analytics visibility remain subject to product visibility policy.

## 10. Counselor Policies

Counselor access must be relationship-scoped.

Until an authoritative Counselor Assignment model exists, a Counselor does **not** receive organization-wide Student/Result/Analytics access by default.

The default future pattern is read-oriented access to assigned Students/classes and their permitted result/analytics summaries, without Question/Exam publishing or grading capabilities unless separately authorized by another role.

## 11. Admin and Deputy Policies

Admin and Deputy are organization-scoped staff roles.

Authorization requires that resource organization and active membership organization match.

Admin may receive broader organization/security administration permissions than Deputy, but neither role receives platform-global cross-organization access.

Even Admin cannot use RLS or role privileges to break Stage 6 invariants such as editing Published Exam Version content in place, mutating submitted participant answers, or directly changing final Result scores.

## 12. Cross-Tenant Isolation

For every organization-owned table exposed to client access, organization isolation is a mandatory predicate.

Conceptually:

```text
resource.organization_id
  must resolve to an active organization membership of current actor
```

Where a child table does not carry `organization_id`, scope is derived safely through its parent relationship.

Client-provided `organization_id` is never proof of access.

## 13. Independent Users

Independent Learner and Independent Teacher flows do not create fake School Membership, Student Enrollment, Class, or Teaching Assignment records.

Independent access uses explicit independent-user mode and own-resource/self scope.

School-owned resources remain inaccessible without an explicit future invitation/collaboration contract.

## 14. GRANT Strategy

RLS does not compensate for overly broad SQL privileges.

Client roles should receive only required operations, table by table and operation by operation.

Avoid broad assumptions such as granting `SELECT, INSERT, UPDATE, DELETE` to `authenticated` across all Exam/Core tables.

Historical and sensitive tables generally should not receive client DELETE grants.

## 15. Sensitive Domain Commands

The following operations are command-based rather than unrestricted client CRUD:

- `StartAttempt`
- `SubmitAttempt`
- `AutoSubmitAttempt`
- `ApproveQuestionVersion`
- `PublishExam`
- `EnableAssignment`
- `CloseAssignment`
- `CancelAssignment`
- `CompleteGrading`
- `StartRegrade` / `CompleteRegrade`
- `GenerateResult` / result regeneration

The trusted command layer must re-check authorization, scope, resource state, and business validation atomically where required.

## 16. Attempt and Answer Safety

### 16.1 Attempt creation

The browser must not directly construct authoritative Attempt fields such as participant identity, fixed Exam Version, `started_at`, or `deadline_at`.

### 16.2 Submission

Direct client mutation such as `status = 'submitted'` is not the submission workflow. `SubmitAttempt` owns the state transition and server timestamps.

### 16.3 Auto-submit

Only trusted System/Internal execution may mark submission as automatic deadline submission.

### 16.4 Answer immutability

Participant answer mutations are denied after Attempt submission or after deadline finalization.

## 17. Grading and Result Safety

Grading writes require explicit grading permission, valid assignment scope, a submitted Attempt, and a valid Grading Case state.

Regrading is always command-based and audited.

`exam.results` is a derived projection from Grading and is not directly score-editable by client roles.

## 18. Sensitive Column Exposure

RLS controls rows, not all column-sensitivity concerns.

Sensitive fields such as:

- answer correctness / answer key;
- internal review notes;
- audit metadata;
- privileged moderation fields;

must also be protected through GRANT strategy, safe views/projections, or trusted server-side queries.

Student delivery must never expose answer-key fields such as `question_options.is_correct`.

## 19. Safe Exam Delivery Projection

Student clients should receive a delivery-safe representation containing only the fields required to take the exam, e.g. question text, allowed option text/key/order, and public instructions.

Correctness flags, grading keys, review metadata, source-rights internal fields, and unrelated Question Bank management fields are excluded.

## 20. Views

Any View exposed to client access must be designed so it does not bypass the intended row protections.

Preferred patterns:

- `security_invoker = true` where supported and appropriate;
- otherwise keep privileged views outside exposed schemas or revoke client access;
- Analytics views must never widen access beyond underlying identifiable Result/Student scope.

## 21. JWT Trust Boundary

Authorization never relies on user-editable metadata.

`user_metadata` / user-controlled metadata is not trusted for role, permission, organization, or relationship authorization.

If `app_metadata` or JWT claims are used as an optimization, they are not the sole source of truth for dynamic relationships such as:

- Membership status;
- Teaching Assignment;
- Guardian↔Student relation;
- mutable authorization scope.

JWT staleness must not create continuing authorization after authoritative relationships are revoked.

## 22. Helper Functions

Implementation may use carefully designed helper functions such as conceptually:

```text
is_active_member(org_id)
has_permission(org_id, permission)
is_teacher_for_class_course(...)
is_guardian_of(student_id)
is_attempt_owner(attempt_id)
```

Stage 8 does not create these functions.

Helper requirements:

- minimal and explicit;
- authorization-focused;
- efficient and index-assisted;
- nonrecursive where possible;
- tested against privilege escalation;
- documented if privileged execution is required.

## 23. SECURITY DEFINER Rules

`SECURITY DEFINER` is not the default mechanism for solving RLS problems.

If it becomes genuinely necessary:

- keep the function out of exposed schemas where practical;
- restrict `EXECUTE` privileges;
- use a controlled `search_path`;
- perform explicit identity/authorization validation;
- review for RLS bypass implications;
- test with negative cases.

No privileged helper is approved merely because a policy is difficult to express.

## 24. UPDATE Safety

Every client UPDATE design must protect both:

- which existing rows the actor may update (`USING` intent);
- what the row may become after update (`WITH CHECK` intent).

Client-updateable rows must not allow silent reassignment of ownership/scope fields such as:

- `organization_id`
- `student_id`
- `attempt_id`
- `exam_version_id`
- `created_by`

## 25. DELETE Strategy

Client-side hard DELETE is not the normal workflow for historical business records.

Examples that should not be freely client-deletable include:

- Published Exam Versions;
- Approved Question Versions;
- submitted Attempts;
- answers tied to submitted history;
- grading revisions;
- Results;
- Audit history.

Stage 5 archive/restrict rules remain authoritative.

## 26. Audit

Clients do not write arbitrary audit records.

Trusted operations generate audit evidence for sensitive actions such as:

- role/permission changes;
- Question approval;
- Exam publication;
- Assignment activation/closure/cancellation;
- grading completion;
- regrading;
- result release/visibility changes.

Audit records include actor, organization, operation, target, and time; reason is included when the domain action requires it.

## 27. System Timestamps

Sensitive timestamps are server-authoritative, including at minimum:

- `started_at`
- `deadline_at`
- `submitted_at`
- `graded_at`
- `published_at`

Client timestamps may be collected as telemetry if needed but do not define authoritative lifecycle timing.

## 28. service_role Boundary

`service_role` or equivalent privileged server credentials are never exposed to browser/mobile clients.

Internal operations may use privileged credentials only inside trusted backend execution, with explicit domain checks and narrow operational responsibility.

## 29. Policy Performance

RLS design must remain performant.

Columns used heavily for policy filtering and relationship joins require appropriate indexing, including as relevant:

- `organization_id`
- `user_id`
- `student_id`
- `teacher_id`
- membership/assignment relationship FKs
- Attempt/Assignment relation keys

Authorization helpers should prefer set-based/index-assisted resolution rather than repeated unbounded scans.

## 30. RLS Testing Requirements

RLS is not considered implementation-complete until positive and negative database-level tests pass.

Required negative scenarios include at minimum:

- Student A cannot read/update Student B Attempt/Answer/Result.
- Teacher A cannot access an unrelated class/course.
- School A cannot access School B resources.
- Guardian can access only linked Student data allowed by policy.
- Counselor cannot receive organization-wide access without authoritative assignment.
- inactive Membership is denied.
- submitted Answer cannot be mutated by participant.
- hidden Result cannot be read by Student/Guardian when policy denies visibility.
- client cannot expose answer-key correctness fields.
- direct status mutation cannot replace command-based transitions.

Negative authorization tests are mandatory, not optional.

## 31. Policy Ownership Matrix

| Resource family | Student | Teacher | Guardian | Counselor | Admin / Deputy |
| --- | --- | --- | --- | --- | --- |
| Student profile | Self-limited | Assigned read | Linked read | Assigned read | Organization |
| Enrollment | Self read | Assigned read | Linked read | Assigned read | Organization |
| Question Bank | No authoring access | Scoped | None | None | Organization |
| Exam draft | None | Own/scoped | None | None | Organization |
| Published delivery | Eligible only | Scoped management | None | None | Organization |
| Assignment | Eligible read | Scoped | Linked summary if policy allows | Assigned summary | Organization |
| Attempt | Self | Assigned read | None | Restricted/none | Organization, operational need |
| Answers | Self while mutable | Assigned grading/read | None | None | Restricted operational access |
| Grading | None | Assigned | None | None | Organization |
| Result | Self if visible | Assigned | Linked if visible | Assigned | Organization |
| Analytics | Self | Assigned | Linked summary | Assigned | Organization |

This matrix is conceptual and remains subordinate to Stage 7 permissions and Stage 6 lifecycle rules.

## 32. Security Layer Order

Conceptual evaluation stack:

```text
Authentication
   |
   v
GRANT
Can this DB role invoke this operation?
   |
   v
RLS
Can this actor touch this row?
   |
   v
Domain Authorization
Does explicit permission + scope allow the action?
   |
   v
Lifecycle State
Is the transition legal now?
   |
   v
Business Validation
Are all domain preconditions satisfied?
```

No layer substitutes for the others.

## 33. Finance / Tuition Protection

Stage 8 makes no change to `finance.*`, Finance RLS, Finance permissions, Finance roles, Finance APIs, Finance migrations, or Finance workflows.

Shared Core Membership concepts do not merge Exam permissions with Finance permissions.

There is no direct Exam↔Finance RLS dependency.

## 34. Freeze Rules

The following rules are frozen for Stage 8:

1. RLS is a core Data API defense but not the only security layer.
2. GRANT and RLS both follow least privilege.
3. `TO authenticated` alone is never sufficient authorization.
4. Cross-organization access is denied by default.
5. Student scope is SELF.
6. Teacher scope resolves from authoritative Teaching Assignment.
7. Guardian scope resolves from authoritative Guardian↔Student relation.
8. Counselor receives no organization-wide scope without authoritative assignment.
9. Admin/Deputy remain organization-scoped, not platform-global.
10. Client-supplied `organization_id` is not trusted as proof of access.
11. Client-supplied role/profile claims are not trusted as proof of authorization.
12. Dynamic relationships are resolved from authoritative database data.
13. `StartAttempt` is command-based.
14. `SubmitAttempt` is command-based.
15. Auto-submit is internal-only.
16. Question approval is command-based.
17. Exam publication is command-based.
18. Assignment enable/close/cancel transitions are command-based.
19. Grading completion and regrading are command-based.
20. Results are not directly score-updateable by clients.
21. Submitted participant Answers are immutable.
22. Approved Question Versions are immutable in place.
23. Published Exam Versions are immutable in place.
24. Sensitive ownership/scope columns are not freely client-updateable.
25. Answer-key correctness fields are never exposed to Student delivery clients.
26. Raw Answer access is more restrictive than Result access.
27. Client-exposed Views must preserve intended row security.
28. `security_invoker` views are preferred where appropriate.
29. `SECURITY DEFINER` is an exceptional reviewed mechanism, not the default solution.
30. `service_role` is never exposed to public clients.
31. User-controlled metadata is never used for authorization.
32. JWT claims do not replace authoritative dynamic relationships.
33. Policies are designed per operation rather than relying on broad generic `FOR ALL` access.
34. Client DELETE is generally denied for historical business data.
35. Audit is not client-writeable arbitrary data.
36. Sensitive lifecycle timestamps are server-authoritative.
37. RLS join/filter columns require appropriate indexes.
38. Negative authorization tests are mandatory before production.
39. RLS implementation is not considered frozen until staging verification succeeds.
40. Finance/Tuition security configuration is unchanged by Stage 8.

## 35. Mental Map

```text
                 CLIENT
                   |
                   v
                AUTH
                   |
                   v
               GRANTS
                   |
                   v
                  RLS
          +--------+--------+
          |        |        |
        SELF   RELATION   ORG STAFF
          |        |        |
       Student   Teacher   Admin
       Indep.    Guardian  Deputy
                  Counselor
          |        |        |
          +--------+--------+
                   |
                   v
              DOMAIN COMMAND
           for sensitive actions
                   |
                   v
             STATE MACHINE
                   |
                   v
            BUSINESS RULES
                   |
                   v
                DATABASE

Sensitive Commands:
- StartAttempt
- SubmitAttempt
- AutoSubmit
- ApproveQuestionVersion
- PublishExam
- Enable/Close/Cancel Assignment
- CompleteGrading
- Regrade
- GenerateResult

Finance / Tuition
     |
PROTECTED — NO CHANGE
```

## 36. Stage Boundary

Stage 8 freezes security-policy intent only.

It does **not** create:

- SQL RLS policies;
- migrations;
- helper functions;
- grants;
- views;
- RPCs/Edge Functions;
- backend services;
- live Supabase configuration;
- staging/production changes;
- Finance changes.

The next architecture stage should define Application Service / API / Transaction boundaries, including which operations are safe CRUD and which are authoritative commands.
