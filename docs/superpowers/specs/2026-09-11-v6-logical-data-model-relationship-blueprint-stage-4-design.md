# Clean Rebuild V6 — Logical Data Model / Relationship Blueprint — Stage 4

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Logical data relationships only — no physical table names, column definitions, foreign keys, indexes, SQL, Supabase schema, RLS, migrations, UI, deployment, or Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 4 of Clean Rebuild V6 for the Marefat Exam System. It translates the frozen Stage 1–3 architecture, bounded contexts, ownership rules, invariants, and conceptual contracts into a logical relationship blueprint.

The previously frozen Question Bank design, Exam Construction design, and Question Bank ↔ Exam Construction Crosswalk remain authoritative and are not reopened here.

Finance / Tuition remains a Protected External Context and is not modified by this stage.

## 2. Design Principle

Stage 4 defines:

- Logical entities and relationship cardinalities
- Aggregate boundaries
- Required vs optional references
- Historical snapshot references
- Derived references
- Conceptual identity separation

Stage 4 does **not** define physical database implementation.

## 3. Platform Foundation Relationships

### 3.1 User Account ↔ Organization through Membership

Logical cardinality:

`User Account 1 -> N Membership`

`Organization 1 -> N Membership`

Therefore User ↔ Organization is conceptually many-to-many through Membership.

Membership is the authoritative relationship for platform-level organization participation.

### 3.2 User Account ↔ School Profiles

School-domain profiles are optional relative to the User Account.

Valid logical relationships include:

- User Account 0..1 ↔ 0..1 Student Profile
- User Account 0..1 ↔ 0..1 Teacher Profile
- User Account 0..1 ↔ 0..1 Guardian Profile
- User Account 0..1 ↔ 0..1 Counselor Profile

A profile may exist before a User Account is provisioned.

A single User may hold more than one domain profile where legitimate, for example Teacher + Guardian.

Rule: `one user = exactly one school role` is explicitly rejected.

## 4. School People Relationships

### 4.1 Student Profile ↔ Enrollment

`Student Profile 1 -> N Enrollment`

A Student Profile remains stable across academic years; yearly placement is represented by Enrollment.

### 4.2 Teacher Profile ↔ Teaching Assignment

`Teacher Profile 1 -> N Teaching Assignment`

A teacher may have multiple assignments across years, classes, and courses.

### 4.3 Guardian ↔ Student

Guardian-to-Student is logically many-to-many through a relationship entity.

`Guardian 1 -> N Guardian-Student Relationship`

`Student 1 -> N Guardian-Student Relationship`

This supports multiple students per guardian and multiple guardians per student.

## 5. Academic Structure Relationships

### 5.1 Academic Year ↔ Class

`Academic Year 1 -> N Class`

Every Class belongs to one Academic Year.

### 5.2 Grade ↔ Class

`Grade 1 -> N Class`

Every Class belongs to one Grade.

### 5.3 Field ↔ Class

`Field 1 -> N Class`, with the Class-side Field reference optional where the educational structure does not require a field/major.

Therefore:

- Class -> Academic Year: required
- Class -> Grade: required
- Class -> Field: optional

## 6. Enrollment Blueprint

Student Enrollment is the authoritative yearly placement relationship.

Logical references:

- Enrollment -> Student: required
- Enrollment -> Academic Year: required
- Enrollment -> Grade: required
- Enrollment -> Field: optional
- Enrollment -> Class: required

Cardinality:

`Student 1 -> N Enrollment`

Invariant: contradictory concurrent primary enrollments for the same Student + Academic Year are not allowed unless a future explicit transfer model records that condition.

## 7. Teaching Assignment Blueprint

Teaching Assignment represents time-bound teaching responsibility.

Logical references:

- Teaching Assignment -> Teacher: required
- Teaching Assignment -> Academic Year: required
- Teaching Assignment -> Class: required
- Teaching Assignment -> Course: required

Cardinality:

`Teacher 1 -> N Teaching Assignment`

Teaching Assignment is distinct from Course Offering.

## 8. Curriculum Blueprint

Canonical hierarchy:

`Course / Book 1 -> N Chapter`

`Chapter 1 -> N Topic`

`Topic 1 -> N Subtopic`

For the current MVP, explicit educational levels are preferred over a fully generic recursive tree because they are clearer for school UI, reporting, and analytics.

## 9. Course Offering

Course definition must not be permanently locked to exactly one Grade/Field when a course may be shared across programs.

Logical relationship:

`Course 1 -> N Course Offering`

Each Course Offering references:

- Grade: required
- Field: optional

This allows one shared Course/Book to be offered across multiple grades/fields where valid.

Course Offering answers: "This course is offered for this academic program."

Teaching Assignment answers: "This teacher teaches this course to this class in this academic year."

They are distinct concepts.

## 10. Question Bank Blueprint

### 10.1 Question ↔ Question Version

`Question 1 -> N Question Version`

Question is stable logical identity; Question Version owns version-specific content.

### 10.2 Question Version ↔ Question Option

`Question Version 1 -> N Question Option`

Options belong to Question Version, not only to abstract Question identity.

### 10.3 Question Version ↔ Curriculum

Question classification may be many-to-many with curriculum nodes because one question may cover more than one educational concept.

Logical model:

`Question Version N <-> N Curriculum Node` through Question Curriculum Link.

The model must support one Primary Curriculum Classification plus optional secondary classifications for analysis.

Question Bank references curriculum; it does not own canonical curriculum definitions.

### 10.4 Question Source / Rights

`Question 1 -> N Question Source Reference`

This allows a question to retain multiple provenance/source references where necessary.

### 10.5 Question Family / Relations

Question relationships are self-referencing many-to-many:

`Question N <-> N Question` through Question Relation.

Relationship semantics continue to follow the already-frozen Question Bank design and may represent variants, derived forms, converted forms, similar/related questions, and other approved relation types.

Each related Question keeps a distinct identity.

## 11. Exam Blueprint

### 11.1 Exam ↔ Exam Version

`Exam 1 -> N Exam Version`

Exam is stable logical identity; draft/published content belongs to versions.

This allows a single Exam identity to have multiple historical published versions and future drafts without rewriting previous evidence.

### 11.2 Exam Version ↔ Exam Section

`Exam Version 1 -> N Exam Section`

A no-section exam may be represented conceptually by a default section if required by the later physical model.

### 11.3 Exam Version ↔ Question Version via Exam Question Entry

`Exam Version 1 -> N Exam Question Entry`

`Question Version 1 -> N Exam Question Entry`

Exam Question Entry owns exam-local placement metadata such as:

- Question order
- Exam-specific score allocation
- Section placement
- Stable reference to Question Version

Published exams therefore depend on stable Question Version identity rather than mutable live Question content.

Exam-specific score may differ from Question Bank default score metadata.

## 12. Published Exam Version

A published exam version is a stable historical snapshot used by Assignment and Attempt.

Once it becomes the basis of an Attempt, it must not be modified in place. Content changes require a new Exam Version.

## 13. Exam Assignment Blueprint

`Published Exam Version 1 -> N Exam Assignment`

One published exam version may have multiple assignments for different classes, students, groups, schedules, or policies.

## 14. Audience / Assignment Target

Audience targeting is modeled through Assignment Target rather than multiple nullable target fields inside Assignment.

`Exam Assignment 1 -> N Assignment Target`

An Assignment Target may reference conceptually:

- Student
- Class
- Grade
- Field
- Selected Group
- Independent User

Assignment Target references these entities but does not own them.

For MVP, reusable Selected Group is not introduced unless there is a concrete requirement. Multiple direct Assignment Targets are sufficient for exam-specific groups.

## 15. Attempt Policy

Attempt Policy is treated conceptually as part of the Exam Assignment aggregate rather than a separate aggregate because it has no independent business lifecycle in the current scope.

It may govern rules such as maximum attempts, one-attempt-only behavior, and availability constraints.

## 16. Attempt Blueprint

`Exam Assignment 1 -> N Attempt`

Each Attempt references:

- One Exam Assignment
- One Published Exam Version
- One Participant

Participant may be a school Student Profile or an Independent User according to the approved architecture.

Invariant: an Attempt is permanently bound to exactly one Published Exam Version and never switches versions after start.

## 17. Attempt ↔ Answer

`Attempt 1 -> N Answer`

Each Answer references exactly one Exam Question Entry.

Evidence chain:

`Attempt -> Answer -> Exam Question Entry -> Question Version`

This preserves the exact content basis of an answer even if Question Bank later changes.

## 18. Composite / Multi-part Questions

The logical model must not block the already-frozen support for composite/multi-part questions.

Conceptually:

`Question Version -> Question Part(s)`

and where required:

`Answer -> Answer Part(s)`

Exact modeling remains subordinate to the frozen Question Bank design and will be detailed later in the physical model.

## 19. Submission

Submission is modeled as a domain state transition/event on Attempt rather than a separate aggregate for the current MVP.

The logical model must preserve at least:

- Submission timestamp
- Submission trigger/reason
- Manual vs auto-submit origin

Manual submit and auto-submit result in the same valid submitted Attempt state.

## 20. Grading Blueprint

### 20.1 Attempt ↔ Grading Case

`Attempt 1 -> 0..1 Grading Case`

Before submission, no grading case is required. After a gradeable submission, one grading case may exist.

### 20.2 Grading Case ↔ Answer Grade

`Grading Case 1 -> N Answer Grade`

Each Answer Grade references one Answer.

Answer Grade owns awarded score and grading feedback.

### 20.3 Regrading

Regrading must be historical/auditable rather than destructive overwrite.

Preferred logical model:

`Grading Case 1 -> N Grading Revision`

A Grading Revision may affect one or more Answer Grades.

The precise physical history structure is deferred.

## 21. Result Blueprint

`Attempt 1 -> 0..1 Exam Result`

Each Exam Result is based on one Grading Case when grading is required.

An Attempt has at most one current Result projection, while score history is preserved through grading/regrading history.

Result remains derived from Grading, not an independent manual scoring source.

## 22. Result Visibility

Result existence and Result visibility remain separate concepts.

Default visibility policy should be attached logically at Exam Version and/or Exam Assignment level and then govern presentation of generated results.

Per-result manual overrides are not introduced unless a later requirement requires them.

## 23. Analytics Blueprint

Analytics relationships are read/derive oriented only.

Analytics Projection may derive from:

- Result
- Attempt
- Answer
- Question Version
- Curriculum
- Enrollment
- Class

No operational aggregate depends on Analytics.

There is no logical reverse dependency from Attempt, Result, Question, or Grading into Analytics.

Analytics must be rebuildable without destroying operational exam truth.

## 24. Aggregate Boundaries

Primary logical aggregate roots:

| Aggregate Root | Main child concepts |
|---|---|
| User Account | auth/account state |
| Organization | Membership |
| Student Profile | profile + guardian relation references |
| Teacher Profile | profile |
| Academic Year | structural state |
| Class | class structure |
| Enrollment | yearly placement |
| Teaching Assignment | teacher-course-class relationship |
| Course | Chapters / Topics / Subtopics |
| Question | Versions / Options / Relations |
| Exam | Versions / Sections / Exam Question Entries |
| Exam Assignment | Targets / Attempt Policy |
| Attempt | Answers / submission state |
| Grading Case | Answer Grades / Grading Revisions |
| Exam Result | current result projection |
| Analytics Projection | derived analytical state |

Cross-aggregate rule: one aggregate may reference another but must not directly mutate another aggregate's owned state.

## 25. Reference Categories

Stage 4 defines four logical reference categories:

1. **Required Reference** — relationship must exist.
2. **Optional Reference** — relationship may be absent.
3. **Historical Snapshot Reference** — historical evidence must remain bound to the original referenced identity/version.
4. **Derived Reference** — used for projections/analytics and not ownership.

Examples:

| Relationship | Category |
|---|---|
| Enrollment -> Student | Required |
| Student -> User Account | Optional |
| Class -> Field | Optional |
| Exam Question Entry -> Question Version | Historical Snapshot |
| Attempt -> Published Exam Version | Required + Historical Snapshot |
| Analytics -> Result | Derived |

## 26. Historical Retention / Delete Behavior

Entities referenced by historical educational/exam records must retain identity and must not be destructively removed in a way that breaks history.

Examples include:

- Question Version used by a published exam
- Published Exam Version
- Enrollment used as historical context
- Attempt
- Grading evidence
- Result

Logical preference:

`Archive / Deactivate / Close / Retire` rather than destructive delete where history exists.

### 26.1 Student departure

A Student leaving the school must not break historical Attempts or Results.

The Student becomes inactive/archived while historical references remain valid.

### 26.2 Question retirement

A Question may be archived, but any Question Version used by a published exam must remain historically referenceable.

## 27. Identity Strategy

Every aggregate root requires a stable internal identity.

Business codes are separate logical identifiers, for example:

- Student internal identity + student code
- Exam internal identity + exam code
- Question internal identity + question code

Business codes must not replace internal identity because codes may be corrected or their formatting rules may change.

Candidate natural keys may include:

- Student code within Organization
- Exam code within Organization
- Academic year identifier
- Question code within question-bank scope

Physical unique constraints are deferred.

## 28. Organization Scope

School and Exam data must be attributable to an Organization/School scope where appropriate.

Examples include:

- Student
- Class
- Enrollment
- Course Offering
- Exam
- Question-bank scope

Stage 4 does not require a direct Organization reference on every logical entity. The later physical model will decide where scope must be stored directly versus derived from the aggregate parent.

## 29. Independent User Edge Case

Independent exam users must not require fake School, Class, or Enrollment records.

School-user flow:

`User Account -> optional Student Profile -> Enrollment -> Assignment eligibility -> Attempt`

Independent-user flow:

`User Account -> Independent Participant -> Assignment Target -> Attempt`

Both converge at Exam Delivery without fabricating school-domain truth.

## 30. Exam Scope vs Audience

Exam educational scope and participant audience are distinct.

Example:

- Exam Scope: Chemistry Grade 10 / Chapter 1
- Audience: Class 101

Scope comes from curriculum/exam design. Audience comes from Exam Assignment.

These must not be merged.

## 31. Relationship Matrix

| From | To | Cardinality |
|---|---|---|
| User | Membership | 1:N |
| Organization | Membership | 1:N |
| Student | Enrollment | 1:N |
| Teacher | Teaching Assignment | 1:N |
| Guardian | Student | M:N via relationship |
| Academic Year | Class | 1:N |
| Grade | Class | 1:N |
| Field | Class | 1:N, optional on Class |
| Course | Course Offering | 1:N |
| Course | Chapter | 1:N |
| Chapter | Topic | 1:N |
| Topic | Subtopic | 1:N |
| Question | Question Version | 1:N |
| Question Version | Option | 1:N |
| Question | Question | M:N via relation |
| Question Version | Curriculum | M:N via link |
| Exam | Exam Version | 1:N |
| Exam Version | Section | 1:N |
| Exam Version | Exam Question Entry | 1:N |
| Question Version | Exam Question Entry | 1:N |
| Published Exam Version | Exam Assignment | 1:N |
| Exam Assignment | Assignment Target | 1:N |
| Exam Assignment | Attempt | 1:N |
| Attempt | Answer | 1:N |
| Answer | Exam Question Entry | N:1 |
| Attempt | Grading Case | 1:0..1 |
| Grading Case | Answer Grade | 1:N |
| Grading Case | Grading Revision | 1:N |
| Attempt | Exam Result | 1:0..1 |

## 32. Finance / Tuition Protection Guardrail

Finance / Tuition remains a **Protected External Context**.

This Stage creates no direct Exam ↔ Finance relationship and performs no Finance schema, data-model, API, workflow, migration, UI, or implementation change.

Shared school truth continues to follow the approved conceptual relationship:

`School Core -> Exam`

`School Core -> Finance`

not direct Exam ↔ Finance ownership/coupling.

## 33. Freeze Decisions

Approval of Stage 4 freezes the following logical decisions:

1. User ↔ Organization is modeled through Membership.
2. Student/Teacher/Guardian profiles remain independent from User Account.
3. Student ↔ Academic Year placement is modeled through Enrollment.
4. Teacher ↔ Class/Course responsibility is modeled through Teaching Assignment.
5. Guardian ↔ Student is many-to-many through a relationship concept.
6. Class references Academic Year and Grade, with Field optional where applicable.
7. Course ↔ Grade/Field is modeled through Course Offering.
8. Curriculum remains Course -> Chapter -> Topic -> Subtopic for the current MVP.
9. Question -> Question Version is 1:N.
10. Question Option belongs to Question Version.
11. Question Version ↔ Curriculum supports M:N classification with a Primary classification concept.
12. Question Relations are self-referencing and preserve distinct Question identities.
13. Exam -> Exam Version is 1:N.
14. Published exams depend on stable Question Versions.
15. Exam Question Entry connects Exam Version to Question Version and owns order/score/section placement.
16. Published Exam Version -> Exam Assignment is 1:N.
17. Exam Assignment -> Assignment Target is 1:N.
18. Attempt belongs to an Assignment and one immutable Published Exam Version.
19. Answer belongs to Attempt and references Exam Question Entry.
20. Composite/multi-part questions remain supported at the logical level.
21. Submission remains an Attempt state transition/event for MVP.
22. Attempt -> Grading Case is 1:0..1.
23. Grading Case owns Answer Grades and auditable Regrading history.
24. Attempt -> current Exam Result is 1:0..1.
25. Result is derived from Grading.
26. Analytics remains derived/read-oriented with no reverse operational dependency.
27. Historical references must remain valid; archive/deactivate is preferred over destructive delete where history exists.
28. Stable internal identity is distinct from business code.
29. Independent users are supported without fake School/Class/Enrollment records.
30. Exam educational scope and participant audience remain separate.
31. Finance/Tuition remains protected and receives no direct Exam dependency or change.

## 34. Explicit Non-Goals of Stage 4

Stage 4 does not define or implement:

- Physical table names
- Column names/types
- Primary key technology
- Foreign-key constraints
- Indexes
- Unique constraints
- PostgreSQL/Supabase schemas
- RLS policies
- RPCs
- API endpoints
- Backend code
- Frontend pages
- Navigation
- SQL migrations
- V5 data migration
- Deployment
- Any Finance/Tuition change

## 35. Mental Map

```text
PLATFORM
User
 ├──< Membership >── Organization
 └── optional School Profiles

SCHOOL
Student ──< Enrollment >── Academic Year / Grade / Field? / Class
Teacher ──< Teaching Assignment >── Class / Course / Academic Year
Guardian ──< Guardian-Student Relationship >── Student
Course ──< Course Offering >── Grade / Field?
Course ──< Chapter ──< Topic ──< Subtopic

QUESTION BANK
Question ──< Question Version ──< Option
Question ──< Question Relation >── Question
Question Version ──< Curriculum Link >── Curriculum

EXAM
Exam ──< Exam Version
Exam Version ──< Section
Exam Version ──< Exam Question Entry >── Question Version
Published Exam Version ──< Exam Assignment ──< Assignment Target
Exam Assignment ──< Attempt ──< Answer
Attempt ──0..1 Grading Case ──< Answer Grade / Grading Revision
Attempt ──0..1 Exam Result
Operational truth ──> Analytics Projection

Finance / Tuition = Protected External Context / No Change
```

## 36. Next Design Stage

After approval and review of this frozen Stage 4 document, the next logical stage is to define the **Physical Data Model / Schema Blueprint V6**: concrete logical-to-physical mapping, schema boundaries, table names, keys, constraints, deletion behavior, and organization scoping — still as design first, before any migration or implementation.
