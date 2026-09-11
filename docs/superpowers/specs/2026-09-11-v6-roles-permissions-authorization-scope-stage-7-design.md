# Clean Rebuild V6 — Roles / Permissions / Authorization Scope — Stage 7

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Authorization model only. No RLS implementation, no SQL/migration execution, no API implementation, no live database changes, no deployment, and no Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 7 of Clean Rebuild V6 for the Marefat Exam System. It defines the authorization decision model, organization-scoped roles, action-based permissions, relationship-derived scopes, resource-state checks, denial rules, independent-user support, and the security boundaries needed before RLS/API design.

Stages 1–6 remain authoritative. The frozen Question Bank design, Exam Construction design, and Question Bank ↔ Exam Construction Crosswalk remain authoritative and are not reopened here.

Finance / Tuition remains a Protected External Context and is not modified by this stage.

## 2. Authorization Principle

Role alone is never sufficient authorization.

Authorization is resolved from:

```text
Authenticated User
+ Active Organization Membership (or explicit independent-user mode)
+ Role/Profile
+ Explicit Permission
+ Domain Relationship / Scope
+ Target Resource Ownership / Organization
+ Resource Lifecycle State
+ Visibility / Business Policy
= Allow or Deny
```

Unknown or incomplete authorization resolves to **deny by default**.

## 3. Core Concepts

V6 keeps the following concepts distinct:

- **Identity** — authenticated platform user (`auth.users`).
- **Membership** — user membership in an Organization/School.
- **Profile / Role** — Student, Teacher, Guardian, Counselor, Deputy, Admin, or approved independent mode.
- **Permission** — an explicit domain action such as `exam.publish` or `grading.regrade`.
- **Scope** — which resources the action may apply to.
- **Domain relationship** — e.g. Teaching Assignment or Guardian↔Student link.
- **Resource state** — current lifecycle state from Stage 6.
- **Visibility/business policy** — e.g. result visibility.

Permission cannot override domain invariants or lifecycle rules.

## 4. MVP Roles

School roles:

- `ADMIN`
- `DEPUTY`
- `TEACHER`
- `STUDENT`
- `GUARDIAN`
- `COUNSELOR`

Independent modes:

- `INDEPENDENT_TEACHER`
- `INDEPENDENT_LEARNER`

A platform-global `SUPER_ADMIN` is intentionally not part of the school MVP. If needed later, it belongs to a separate Platform Administration design.

## 5. Organization Scoping

Roles are organization-scoped, not global user properties.

A user may have different roles in different organizations, for example:

```text
School A -> TEACHER
School B -> GUARDIAN
```

Cross-organization access is denied by default. A school-level role never grants access to another school.

## 6. Multiple Roles

A user may hold multiple roles simultaneously, for example Teacher + Guardian. Authorization must not assume a single role field on the user.

## 7. Scope Vocabulary

Shared authorization scope concepts:

- `SELF`
- `LINKED_STUDENTS`
- `ASSIGNED_STUDENTS`
- `ASSIGNED_CLASS`
- `ASSIGNED_COURSE`
- `OWN_RESOURCES`
- `ORGANIZATION`

A future `PLATFORM` scope is intentionally deferred.

Scope is relationship-driven; it is not trusted merely because a client or JWT claims a scope string.

## 8. Permission Naming

Permissions use action-oriented naming:

```text
resource.action
```

Examples:

```text
question.view
question.create
question.edit
question.review
question.approve
question.retire

exam.view
exam.create
exam.edit
exam.publish
exam.retire

assignment.create
assignment.edit
assignment.enable
assignment.close
assignment.cancel

attempt.start
attempt.view
attempt.submit

answer.write
attempt.answer.view

grading.view
grading.perform
grading.complete
grading.regrade

result.view
result.release

analytics.view
```

Permissions should be granular enough to represent meaningful domain actions, but not split into trivial field-level actions unless a real requirement appears.

## 9. Admin

Admin scope is `ORGANIZATION`.

Default responsibilities include organization-level school structure, people, membership/security administration, question-bank administration, exam administration, grading oversight, results, and analytics.

Admin is not platform-global and cannot bypass domain invariants. Examples of forbidden bypasses:

- editing an approved Question Version in place;
- editing a Published Exam Version in place;
- editing submitted participant answers as if still in progress;
- manually overriding Result score outside the Grading/Regrading flow.

## 10. Deputy

Deputy generally has organization-wide educational/operational scope but is more restricted than Admin for top-level security and ownership management.

Typical Deputy capabilities:

- manage academic structure and operational student/class data;
- manage Question Bank and Exam operations when permitted;
- manage Assignments and grading oversight;
- view organization Results and Analytics.

Deputy should not automatically control organization ownership or highest-level administrator/security configuration.

## 11. Teacher

Teacher access is relationship-scoped through active Teaching Assignment(s):

```text
Teacher
  -> Academic Year
  -> Class
  -> Course
```

Teacher must not receive unrestricted organization-wide data access merely because the user is a teacher.

### 11.1 Question Bank

A Teacher may receive permissions such as:

- `question.view`
- `question.create`
- `question.edit` for own editable drafts
- submit-for-review action

within relevant curriculum/teaching scope.

Approved Questions are not edited in place; correction produces a new version.

Review/approval permissions are separate from ordinary Teacher authoring permissions.

### 11.2 Reviewer Separation

`TEACHER` does not automatically imply Question Reviewer.

Permissions such as:

- `question.review`
- `question.approve`

must be granted explicitly.

Where the Question workflow requires review, author self-approval is forbidden. The stricter previously frozen Question Bank review rules remain authoritative.

### 11.3 Exam Construction

Teacher may create/edit draft Exams in assigned educational scope when permitted.

`exam.create` and `exam.publish` are separate permissions.

Publish is a high-impact immutable transition and is never implied simply by the ability to create/edit an Exam.

### 11.4 Exam Assignment

Teacher may assign Exams only within authorized Teaching Assignment scope. Access to one course/class does not authorize assignment to unrelated classes/courses.

### 11.5 Grading

Teacher grading requires:

- active Teacher profile;
- explicit grading permission;
- relevant Teaching Assignment scope;
- relevant Exam/Assignment resource;
- Attempt in a gradeable submitted state.

`grading.regrade` is a separate, stronger permission from initial grading.

## 12. Student

Student scope is `SELF`.

Typical permissions:

- view own eligible Assignments;
- start own Attempt when eligible;
- view own Attempt;
- write own Answers while the Attempt is editable;
- submit own Attempt;
- view own Result when visibility policy allows;
- view own allowed analytics.

Student cannot view or mutate another student's Attempts, Answers, Results, or grading data.

Student permission does not override eligibility or lifecycle state.

## 13. Guardian

Guardian scope is `LINKED_STUDENTS`, resolved through authoritative Guardian↔Student relationships.

Potential MVP capabilities:

- view linked student's exam history;
- view linked student's Result when guardian visibility policy allows;
- view linked student's summary analytics when permitted.

Guardian cannot:

- start an Attempt on behalf of a Student;
- submit Student Answers;
- grade;
- edit Exam or Question content;
- mutate academic truth.

Student visibility and Guardian visibility are conceptually separable policies even if MVP initially uses a simpler shared configuration.

## 14. Counselor

Counselor should have relationship-based scope such as assigned Students/Classes, not default unrestricted Organization access.

Typical permissions:

- view assigned Students' exam history;
- view assigned Results;
- view assigned Analytics.

By default Counselor does not receive Question authoring, Exam publish, or Grading permissions.

If a formal Counselor Assignment entity is not yet implemented, broad Counselor access must not be granted as a shortcut.

## 15. Independent Learner

Independent Learner is a Platform User without fabricated School Membership, Student Profile, Enrollment, or Class.

Scope: `SELF`.

Potential capabilities:

- discover eligible independent Exams;
- start own Attempt;
- write/submit own Answers;
- view own Result under product policy.

Independent Learner has no access to school Students, Classes, Question Bank, or school analytics.

## 16. Independent Teacher

Independent Teacher is a Platform User without fabricated school Teacher Profile or Teaching Assignment.

Scope: `OWN_RESOURCES`.

Potential capabilities under product policy:

- create own Questions;
- create own Exams;
- publish/use own resources where permitted.

Independent Teacher has no implicit access to school Students, Classes, Question Banks, or school Assignments.

## 17. Question Bank Visibility Rules

Suggested baseline:

- Admin: organization Question Bank.
- Deputy: organization Question Bank according to permissions.
- Teacher: own drafts + permitted approved shared Questions + assigned curriculum scope.
- Student/Guardian/Counselor: no authoring access by default.

Approved shared Question visibility does not imply edit rights.

Draft visibility is restricted to author, assigned reviewer(s), and authorized management staff.

## 18. Exam Visibility Rules

Draft Exam visibility is generally restricted to creator/authorized staff/collaborators if collaboration is later added.

Published Exam definition access for staff is distinct from participant delivery access.

Students receive only the delivery-safe published content required for their Attempt; answer keys and privileged metadata are not implied by Exam visibility.

## 19. Attempt and Raw Answer Access

- Student: own Attempt only.
- Teacher: Attempts in authorized assignment/teaching scope.
- Deputy/Admin: organization scope according to permission.
- Guardian: Result/history by policy; raw Answer access is not granted by default.
- Counselor: Result/Analytics by assigned scope; raw Answer access is not granted by default.

`attempt.answer.view` is intentionally separate from `result.view`.

## 20. Result Authorization

Result authorization combines:

- permission;
- relationship/scope;
- Result existence/finality as required;
- visibility policy.

Examples:

- Student: `SELF` + result visibility.
- Guardian: linked Student + guardian visibility.
- Teacher: assigned teaching scope.
- Counselor: assigned Student/Class scope.
- Deputy/Admin: organization scope.

`result.release` controls visibility policy, not score editing.

## 21. Analytics Authorization

Analytics access must never widen access to underlying identifiable operational data.

Examples:

- Teacher: assigned class/course.
- Counselor: assigned Students/Classes.
- Student: own allowed analytics.
- Guardian: linked-student summary where permitted.
- Deputy/Admin: organization scope.

Aggregated/de-identified analytics may be given broader scope later, but that is deferred.

## 22. School Core Authorization Boundary

Core permissions may include:

```text
student.view
student.create
student.edit
teacher.view
teacher.manage
class.view
class.manage
enrollment.view
enrollment.manage
curriculum.view
curriculum.manage
```

Exam access to Student/Class/Curriculum does not authorize mutation of School Core truth.

Teacher use of Class/Student/Curriculum for Exam purposes does not grant permission to change Enrollment, move Students, or alter canonical Curriculum.

## 23. Organization Ownership of Resources

Questions and Exams created by Teachers are organizational resources when created inside a school organization.

`created_by` records authorship/audit but does not make the resource private property that disappears when the Teacher leaves.

## 24. Authorization Evaluation Order

Recommended evaluation sequence:

1. Authenticate User.
2. Resolve Organization context or explicit independent mode.
3. Validate active Membership when organization-scoped.
4. Resolve active Profiles/Roles.
5. Check explicit Permission.
6. Resolve relationship-driven Scope.
7. Validate target Resource organization/ownership.
8. Validate Resource lifecycle/state.
9. Apply eligibility/visibility/business policy.
10. Allow or deny.

A failure at any required step denies the operation.

## 25. Example: Teacher Publishes Exam

Required conditions may include:

- authenticated user;
- active school membership;
- active Teacher profile;
- `exam.publish` permission;
- relevant Teaching Assignment scope;
- Exam belongs to same Organization;
- Exam Version is `DRAFT`;
- Publish validation succeeds.

Only then may `DRAFT -> PUBLISHED` occur.

## 26. Example: Student Starts Attempt

Required conditions may include:

- authenticated participant;
- valid active participant state;
- `attempt.start` permission for self;
- Assignment targets participant;
- Assignment lifecycle permits start;
- computed availability is open;
- attempt policy/limit permits another Attempt.

Authorization and eligibility are both required.

## 27. Example: Teacher Grades Attempt

Required conditions may include:

- authenticated active Teacher;
- `grading.perform` permission;
- Assignment/Exam in Teacher scope;
- Attempt `SUBMITTED`;
- valid Grading Case/lifecycle state.

## 28. Example: Guardian Views Result

Required conditions may include:

- authenticated active Guardian;
- authoritative Guardian↔Student link;
- result-view permission for linked Student;
- Result in valid viewable state;
- guardian visibility policy allows access.

## 29. Denial Reason Categories

Internal/domain authorization may use reason categories such as:

- `UNAUTHENTICATED`
- `MEMBERSHIP_INACTIVE`
- `PERMISSION_DENIED`
- `OUTSIDE_SCOPE`
- `WRONG_ORGANIZATION`
- `RESOURCE_STATE_INVALID`
- `RESULT_NOT_VISIBLE`
- `NOT_LINKED_GUARDIAN`
- `NOT_ASSIGNED_TEACHER`

External/client messages may map these to safer UX-specific wording.

## 30. Membership and Profile Status

Inactive/suspended/ended Membership must block new organization operations even if stale role assignments still exist.

Inactive Teacher/Student/Guardian/Counselor profiles may further restrict operational permissions.

Ended Teaching Assignment does not create scope for new Teacher operations. Historical read access is policy-controlled and should not be granted forever merely because an old assignment existed.

## 31. Authorization vs Domain Validation

Authorization answers whether an actor is allowed to attempt an action.

Domain validation answers whether the action is valid for the current resource/state/data.

Example: a Teacher may have `exam.publish`, but publication still fails if the Exam has no valid questions or violates Stage 6 publish preconditions.

## 32. Authorization vs Eligibility

A Student may have feature permission to start an Attempt but still be ineligible for a specific Assignment because it is not open, not targeted to the Student, or the attempt limit is exhausted.

## 33. JWT and Dynamic Authorization

JWT is primarily identity/session evidence. Dynamic authorization truth such as:

- Membership status;
- Teaching Assignment;
- Guardian relation;
- current scope;

must be resolved from authoritative data rather than trusted indefinitely from stale client/JWT claims.

Role summaries in trusted application metadata may be used as an optimization, but do not replace authoritative scope checks.

## 34. System Actor

Internal system operations include:

- deadline auto-submit;
- objective auto-grading;
- Result regeneration;
- Analytics refresh.

Clients cannot impersonate a `SYSTEM` actor. Privileged internal operations remain backend/internal and must not expose service-level credentials to public clients.

## 35. Audit Requirements

Security-sensitive and high-impact operations should be auditable, including:

- role assignment/removal;
- permission changes;
- Question approval;
- Exam publication;
- Assignment enable/close/cancel;
- grading completion;
- Regrading;
- Result release/visibility changes.

Audit should record actor, organization, action, target, timestamp, and reason when applicable.

## 36. Separation of Duties

The main MVP separation-of-duties rule is Question author vs required reviewer/approver.

Exam creator and publisher are not forced to be different users in MVP unless a later school policy explicitly requires it.

## 37. Forbidden Shortcuts

The following patterns are forbidden:

```text
if authenticated -> allow
if role == teacher -> allow all school data
if role == admin -> bypass domain state
trust client-supplied organization_id as ownership proof
trust client-supplied student_id as ownership proof
```

Authorization is always resource- and relationship-aware.

## 38. RLS Preparation Families

This model is intentionally shaped so later RLS can map into four major families:

- self/ownership policies;
- relationship-scope policies;
- organization-wide authorized staff policies;
- internal/system operations.

Stage 7 does not implement those policies.

## 39. MVP Permission Matrix

| Operation | Admin | Deputy | Teacher | Student | Guardian | Counselor |
|---|---:|---:|---:|---:|---:|---:|
| Manage school structure | Yes | Yes | No | No | No | No |
| Manage membership/security | Yes | Limited | No | No | No | No |
| View Question Bank | Org | Org | Assigned scope | No | No | No |
| Create Question | Org | Org | Assigned scope | No | No | No |
| Approve Question | Explicit permission | Explicit permission | Reviewer only | No | No | No |
| Create Exam | Org | Org | Assigned scope | No | No | No |
| Publish Exam | Org | Org | Explicit permission + scope | No | No | No |
| Create Assignment | Org | Org | Assigned scope | No | No | No |
| Start Attempt | No | No | No | Self | No | No |
| Submit Attempt | No | No | No | Self | No | No |
| Grade | Org | Org | Assigned scope | No | No | No |
| Regrade | Explicit | Explicit | Explicit + scope | No | No | No |
| View Result | Org | Org | Assigned | Self | Linked | Assigned |
| View Analytics | Org | Org | Assigned | Self | Linked summary | Assigned |

Role bundles do not bypass Scope, Resource State, or Domain Validation.

## 40. Independent User Matrix

| Operation | Independent Learner | Independent Teacher |
|---|---:|---:|
| Take eligible Exam | Self | If participant policy allows |
| View own Result | Yes | Yes |
| Create own Questions | No | Yes |
| Create own Exam | No | Yes |
| Publish own Exam | No | Product-policy controlled |
| Access school Students/Classes | No | No |
| Access school Question Bank | No | No, unless a future explicit invitation model exists |

## 41. Finance / Tuition Protected Boundary

Stage 7 defines no Finance permissions, roles, or scopes.

Exam authorization must not imply Finance authorization, and Finance roles must not imply Exam authorization.

Conceptually:

```text
Core Membership
   ├── Exam Permissions
   └── Finance Permissions
```

These remain independent permission domains.

No Exam→Finance or Finance→Exam authorization dependency is introduced.

## 42. Frozen Rules

1. Role alone is not final authorization.
2. Authorization combines Identity, Membership, Role/Profile, Permission, Scope, Resource, State, and Policy.
3. Roles are organization-scoped.
4. One User may hold multiple Roles and Memberships.
5. Admin is organization-level, not platform-global.
6. Deputy is broad educational/operational staff but more limited than Admin for top-level security/ownership.
7. Teacher Scope derives from active Teaching Assignment.
8. Teacher has no unrestricted organization-wide access by default.
9. Student Scope is `SELF`.
10. Guardian Scope is `LINKED_STUDENTS`.
11. Counselor Scope is assigned Students/Classes rather than unrestricted organization scope.
12. Independent Learner/Teacher are supported without fabricated School Profiles/Enrollment/Class.
13. Permissions are action-based.
14. Create and Publish are separate permissions.
15. Grade and Regrade are separate permissions.
16. Question authoring and review/approval are separate capabilities.
17. Required Question review forbids author self-approval.
18. Approved Question Version cannot be edited in place.
19. Published Exam Version cannot be edited in place.
20. Admin cannot bypass Domain invariants.
21. Student manages only own Attempt/Answer/Result subject to state/policy.
22. Result visibility requires both authorization and visibility policy.
23. Guardian cannot start/submit an Attempt on behalf of Student.
24. Counselor has no default create/publish/grade permission.
25. Raw Answer access is distinct from Result access.
26. Analytics authorization cannot widen identifiable underlying Result/Attempt access.
27. Inactive Membership blocks organization operations.
28. Ended Teaching Assignment does not authorize new Teacher operations.
29. Cross-organization access is denied by default.
30. Deny-by-default is the base rule.
31. System actions are backend/internal only.
32. Clients cannot impersonate privileged/system actors.
33. JWT is not the sole authorization source.
34. Dynamic relationships are resolved from authoritative data.
35. Sensitive permission and lifecycle operations are audited.
36. Permission cannot bypass State Machine or Domain Validation.
37. Exam and Finance permission domains remain independent.
38. Stage 7 makes no Finance/Tuition role, permission, scope, schema, migration, or workflow change.

## 43. Authorization Map

```text
USER
  |
  v
IDENTITY / SESSION
  |
  v
MEMBERSHIP or INDEPENDENT MODE
  |
  +--> ROLE / PROFILE
  |       |
  |       v
  |   PERMISSIONS
  |
  +--> DOMAIN RELATIONSHIPS
          |
          +--> Teaching Assignment
          +--> Guardian-Student Link
          +--> Student Self
          +--> Counselor Assignment
          |
          v
        SCOPE
          |
          v
       RESOURCE
          |
          v
   LIFECYCLE STATE / POLICY
          |
          v
      ALLOW / DENY

FINANCE / TUITION
Protected external authorization domain — no change
```

## 44. Non-Goals

Stage 7 intentionally does not define or implement:

- SQL tables for authorization;
- RLS policies;
- helper functions/RPCs;
- triggers;
- JWT custom-claim implementation;
- API middleware;
- UI permission rendering;
- migration files;
- staging or production changes;
- Finance/Tuition authorization changes.
