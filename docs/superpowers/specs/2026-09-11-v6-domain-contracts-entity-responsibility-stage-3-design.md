# Clean Rebuild V6 — Domain Contracts / Entity Responsibility Map — Stage 3

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Domain contracts, entity ownership, conceptual invariants, and cross-context responsibilities only. No physical database tables, columns, foreign keys, SQL, Supabase schema, API endpoints, RLS, UI, migration, deployment, or Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 3 of Clean Rebuild V6 for the Marefat Exam System. Stage 3 refines the frozen Stage 1 Master Architecture and Stage 2 Domain Map into explicit entity responsibilities, ownership rules, invariants, and conceptual cross-context contracts.

The previously frozen Question Bank design, Exam Construction design, and Question Bank ↔ Exam Construction Crosswalk remain authoritative and are not reopened here.

Finance / Tuition remains a Protected External Context and is not modified by this stage.

## 2. Design Method

Each conceptual entity or aggregate is evaluated using the following model:

- Owner Context
- Owns
- References
- May Change
- Must Not Change
- Invariants

Cross-context contracts are conceptual contracts only. They do not define physical API endpoints or database access mechanisms.

## 3. Platform Foundation Responsibilities

### 3.1 P1 — User Account

Owner: **P1 Identity & Access**

Owns:

- Account identity
- Authentication state
- Account status
- Login identity
- Session/authentication concerns
- Permission infrastructure foundation

References:

- Organization Membership
- Optional School Profile linkage

Must not own:

- Student educational data
- Teacher educational data
- Class
- Enrollment
- Exam Attempt
- Exam Result
- Tuition or Finance data

Invariant:

`User Account != Student Profile`

`User Account != Teacher Profile`

`User Account != Guardian Profile`

A User Account may exist without a school-domain profile, and a school-domain profile may exist before a User Account is provisioned.

### 3.2 P2 — Organization

Owner: **P2 Organization & Membership**

Owns:

- Organization identity
- School identity at platform level
- Organization lifecycle

Must not own class, curriculum, enrollment, exam, or finance business state.

Invariant: Membership must always belong to a valid Organization.

### 3.3 P2 — Membership

Owner: **P2 Organization & Membership**

Owns:

- User ↔ Organization relationship
- Membership status
- Organization-level role assignment foundation

References:

- User Account
- Organization

Must not own:

- Teacher-Class assignment
- Student Enrollment
- Detailed Exam authorization logic

## 4. School Core Responsibilities

### 4.1 S1 — Student Profile

Owner: **S1 People & School Profiles**

Owns:

- School-domain student identity/profile
- Student code
- Stable school-specific profile information

References:

- Optional User Account

Must not own:

- Current Class
- Current Grade
- Academic Year placement
- Exam Result
- Tuition

Invariant:

Student Profile is stable across academic years. Year-specific placement belongs to Enrollment.

### 4.2 S1 — Teacher Profile

Owner: **S1 People & School Profiles**

Owns stable school-domain teacher identity/profile.

References optional User Account.

Must not own:

- Current year's classes
- Current year's courses
- Academic Year
- Question Bank ownership
- Exam ownership by virtue of profile alone

Teaching responsibility is expressed through Teaching Assignment.

### 4.3 S1 — Guardian Profile

Owner: **S1 People & School Profiles**

Guardian is a distinct profile. Guardian-to-Student relationship is modeled conceptually as a separate relationship and must not be embedded as duplicated guardian data inside Student Profile.

This supports one guardian with multiple students and multiple guardians per student.

### 4.4 S2 — Academic Year

Owner: **S2 Academic Structure**

Owns the canonical Academic Year concept.

Conceptual lifecycle may include planned, active, and closed states; exact state names are deferred to the physical data model.

Invariant: historical records must not be rewritten merely because the current academic year changes.

### 4.5 S2 — Grade

Owner: **S2 Academic Structure**

Examples: دهم، یازدهم، دوازدهم.

Exam Core references Grade but does not define competing authoritative Grade records.

### 4.6 S2 — Field

Owner: **S2 Academic Structure**

Examples: تجربی، ریاضی، انسانی.

Exam Core and Question Bank must not define parallel authoritative Field records.

### 4.7 S2 — Class

Owner: **S2 Academic Structure**

References conceptually:

- Academic Year
- Grade
- Field

Class does not own an embedded authoritative student list. Membership is expressed through S3 Enrollment.

### 4.8 S3 — Student Enrollment

Owner: **S3 Enrollment & Teaching Assignment**

Purpose: represent one student's time-bound academic placement.

References:

- Student
- Academic Year
- Grade
- Field
- Class

Invariant: a student must not have contradictory concurrent primary enrollments for the same academic period unless a future explicit transfer model permits and records that condition.

### 4.9 S3 — Teaching Assignment

Owner: **S3 Enrollment & Teaching Assignment**

Purpose: represent a teacher's time-bound academic responsibility.

References:

- Teacher
- Academic Year
- Class
- Course

Invariant: Teacher Profile does not itself imply authorization over all courses/classes. Assignment is the relationship that establishes teaching responsibility.

### 4.10 S4 — Course / Book

Owner: **S4 Curriculum Catalog**

Owns the canonical definition of a school course/book.

Question Bank and Exam Core reference Course but do not own its canonical definition.

### 4.11 S4 — Curriculum Node

Owner: **S4 Curriculum Catalog**

Canonical hierarchy:

`Course -> Chapter -> Topic -> Subtopic`

Invariant: canonical curriculum nodes are created and changed only by School Core. Exam/Question Bank may reference but not redefine them.

## 5. Exam Core Responsibilities

### 5.1 E1 — Question

Owner: **E1 Question Bank**

Question represents the logical identity of a question across versions.

It is distinct from Question Version.

### 5.2 E1 — Question Version

Owner: **E1 Question Bank**

Owns version-specific content, including conceptually:

- Question text
- Options where applicable
- Correct answer data
- Explanation
- Difficulty
- Default scoring metadata
- Version-specific metadata

Invariant: content used by a published exam must not be silently overwritten by later Question Bank edits. Editing versioned content creates a new version rather than mutating historical evidence.

### 5.3 E1 — Question Option

Owner: **E1 Question Bank**

Question Option belongs conceptually to Question Version, not merely to the abstract Question identity, because option changes are content-version changes.

### 5.4 E1 — Question Curriculum Reference

Owner of the reference: **E1 Question Bank**

Provider of canonical curriculum truth: **S4 Curriculum Catalog**

Question may reference Course / Chapter / Topic / Subtopic but does not own those definitions.

### 5.5 E1 — Question Source / Rights

Owner: **E1 Question Bank** for question provenance and rights metadata associated with a question.

Any future platform-wide source catalog may be referenced, but Stage 3 does not create such a catalog.

### 5.6 E1 — Question Family / Relations

Owner: **E1 Question Bank**

Purpose includes conceptual relationships such as variants, converted forms, and related questions.

Invariant: related/family questions retain distinct identities and must not overwrite each other.

### 5.7 E2 — Exam

Owner: **E2 Exam Design & Construction**

Owns:

- Exam identity
- Title/purpose
- Exam lifecycle
- Sections
- Question composition
- Score composition

Exam does not own Student, Class, Enrollment, or Curriculum truth.

### 5.8 E2 — Exam Draft

Owner: **E2 Exam Design & Construction**

Before publication, the draft may conceptually allow adding/removing questions, ordering changes, score allocation changes, and section changes subject to the frozen Exam Construction design.

### 5.9 E2 — Published Exam Snapshot

Owner: **E2 Exam Design & Construction**

Publication produces a stable exam version/snapshot.

Invariant:

Once a published exam version is the basis of an Attempt, its content must not be changed in place. Changes require a new published exam version.

Conceptual lifecycle:

`Exam Draft -> Publish -> Published Exam Snapshot`

### 5.10 E2 — Exam Question Entry

Owner: **E2 Exam Design & Construction**

Purpose: represent a question's placement inside a specific exam version.

Owns conceptually:

- Question order
- Exam-specific score allocation
- Section placement
- Reference to a stable Question Version

Invariant: exam-specific score allocation may differ from Question Bank default score metadata.

### 5.11 E3 — Exam Assignment

Owner: **E3 Exam Assignment & Scheduling**

Purpose: bind a Published Exam to an Audience and participation rules.

Owns conceptually:

- Audience linkage
- Availability rules
- Attempt policy
- Access conditions

Must not mutate Published Exam content or School Core truth.

### 5.12 E3 — Audience

Owner: **E3 Exam Assignment & Scheduling** for the assignment reference/definition.

Audience may reference:

- Student
- Class
- Grade
- Field
- Selected Group
- Independent User

Invariant: Audience references do not transfer ownership of Student/Class/Grade/Field to Exam Core.

### 5.13 E3 — Eligibility Rule

Owner: **E3 Exam Assignment & Scheduling**

Purpose: decide whether a participant is allowed to take an exam under assignment and availability rules.

Invariant: eligibility checks may consume School Core data but must not modify Enrollment, Class, or Student truth.

### 5.14 E3 — Attempt Policy

Owner: **E3 Exam Assignment & Scheduling**

Owns participation rules such as maximum attempts, one-attempt-only policy, and availability restrictions.

Actual attempts belong to E4.

### 5.15 E4 — Attempt

Owner: **E4 Exam Delivery & Attempts**

Owns:

- Participant reference
- Published Exam reference
- Start state/time
- Deadline
- Submission state
- Attempt lifecycle

Invariant: each Attempt is permanently bound to exactly one Published Exam Version and must not switch versions after start.

### 5.16 E4 — Answer

Owner: **E4 Exam Delivery & Attempts**

References:

- Attempt
- Exam Question Entry
- Stable Question Version evidence as needed

Owns:

- Participant response
- Saved state
- Answered timestamp

Invariant: Answer must not mutate Question Bank content.

### 5.17 E4 — Submission

Owner: **E4 Exam Delivery & Attempts**

Submission is a domain state transition from active/in-progress attempt to a submitted state suitable for grading.

Invariant: after submission, participant answers are immutable from the participant's perspective unless a future separately approved recovery workflow explicitly allows otherwise.

### 5.18 E4 — Auto Submit

Owner: **E4 Exam Delivery & Attempts**

Auto-submit and manual submit are different triggers for the same valid domain outcome: a submitted Attempt suitable for grading.

### 5.19 E5 — Grading Case

Owner: **E5 Grading**

References:

- Attempt
- Submitted Answers
- Exam scoring rules
- Stable Question Version evidence

Owns:

- Grading state
- Grader reference
- Awarded scores
- Feedback
- Manual review state

### 5.20 E5 — Answer Grade

Owner: **E5 Grading**

Owns the awarded score and grading feedback for one answer.

Awarded scores do not belong to Question Bank.

### 5.21 E5 — Regrading

Owner: **E5 Grading**

Invariant: regrading must be auditable and must not silently overwrite historical grading evidence without trace.

Exact history storage is deferred to the physical data model.

### 5.22 E6 — Exam Result

Owner: **E6 Exam Results**

Owns the finalized result projection for one graded Attempt, including conceptually:

- Final score
- Percentage
- Correct count
- Wrong count
- Blank count
- Result state
- Summary feedback

Invariant: Result is derived from completed Grading. Result is not an independent manual scoring source.

If a score changes, the change originates through a grading/regrading flow and Result is then refreshed/recomputed.

### 5.23 E6 — Result Visibility Policy

Owner: **E6 Exam Results** for exam-result visibility behavior.

Invariant: existence of a Result and permission to view that Result are distinct concepts.

A valid state may be:

- Result exists
- Teacher/Admin may view
- Student visibility remains disabled until policy allows it

### 5.24 E7 — Analytics Projection

Owner: **E7 Exam Analytics**

Owns derived analytical projections such as:

- Student performance
- Class performance
- Question performance
- Topic weakness/strength
- Monthly trends

Invariant: Analytics data is derived and rebuildable from authoritative operational sources. Deleting or rebuilding analytics must not destroy exam operational truth.

Analytics must not mutate Question, Attempt, Grading, or Result truth.

## 6. Conceptual Cross-Context Contracts

These contracts describe allowed conceptual interactions. They are not API endpoint definitions.

### C1 — Resolve User Identity

Provider: P1 Identity & Access

Consumers may ask who the authenticated User is and obtain identity/account state needed for authorization.

Consumers must not directly mutate P1-owned account truth.

### C2 — Resolve School Membership

Provider: P2 Organization & Membership

Consumers may ask whether a User is an active member of a School/Organization and obtain relevant membership context.

### C3 — Resolve Student Profile

Provider: S1 People & School Profiles

Exam Core may resolve Student identity/profile data but must not directly update Student truth.

### C4 — Resolve Enrollment

Provider: S3 Enrollment & Teaching Assignment

Example query concept:

`Which students belong to Class X in Academic Year Y?`

Exam Core consumes the answer but must not create a competing authoritative class membership list.

### C5 — Resolve Teaching Assignment

Provider: S3 Enrollment & Teaching Assignment

Example query concept:

`Is Teacher T assigned to Course C / Class K in Academic Year Y?`

This contract later supports authorization decisions without granting all teachers unrestricted access.

### C6 — Resolve Curriculum

Provider: S4 Curriculum Catalog

Consumers may resolve Course / Chapter / Topic / Subtopic.

Canonical curriculum creation/change remains exclusively in School Core.

### C7 — Provide Approved Question Version

Provider: E1 Question Bank

Consumer: E2 Exam Design & Construction

Conceptual payload includes stable question/version identity, approved content evidence, scoring metadata, and curriculum references needed by Exam Construction.

E2 must not edit E1-owned Question Version in place.

Any teacher edit to bank content must follow the frozen Question Bank versioning workflow. Any exam-local adjustment is allowed only if the already-frozen Exam Construction design explicitly supports it.

### C8 — Publish Exam

Provider/Owner: E2 Exam Design & Construction

Publication produces a stable Published Exam Snapshot containing the exam version, stable Question Version references, exam-specific scoring, ordering, and sections.

E4 depends on this stable published contract.

### C9 — Check Eligibility

Provider: E3 Exam Assignment & Scheduling

Consumer: E4 Exam Delivery & Attempts

Before creating an Attempt, E4 may ask whether the participant is eligible, whether the exam is currently available, and which attempt policy applies.

E4 must not duplicate or redefine eligibility logic.

### C10 — Start Attempt

Owner: E4 Exam Delivery & Attempts

After eligibility succeeds, E4 creates an Attempt and binds it permanently to one Published Exam Version.

### C11 — Submit Attempt

Owner: E4 Exam Delivery & Attempts

Conceptual submission outcome includes:

- Submitted Attempt state
- Submission timestamp
- Submission reason/trigger
- Manual or auto-submit origin

This outcome makes the Attempt eligible for E5 Grading.

### C12 — Produce Grading Outcome

Provider: E5 Grading

Consumer: E6 Exam Results

Conceptual output includes graded answers, total awarded score, grading completion state, and feedback needed to derive the Result.

### C13 — Produce Result

Provider: E6 Exam Results

Consumers such as E7 Exam Analytics may consume the Result as a stable exam-result projection.

Analytics must not modify it.

## 7. Ownership vs Reference Rule

Critical rule:

**Having a reference to another context's entity does not transfer ownership.**

For example, Exam Core may hold references to:

- Student
- Class
- Academic Year
- Course
- Topic

but authoritative ownership remains:

- Student -> S1
- Class / Academic Year -> S2
- Enrollment -> S3
- Curriculum -> S4

## 8. Live Reference vs Snapshot Reference

Stage 3 distinguishes two conceptual reference types.

### Live Reference

Used when current authoritative state should be reflected.

Examples:

- Current Student profile display
- Current Teacher profile display
- Current school membership/enrollment checks

### Snapshot Reference

Used when historical evidence must remain stable despite future edits.

Examples:

- Published Exam
- Question Version used by a Published Exam
- Attempt exam content
- Grading evidence
- Result basis

Invariant: future Question Bank edits must not change the historical basis of a past Attempt or Result.

## 9. Archive / Deactivation Principle

Entities with historical educational or assessment significance should not be casually hard-deleted.

Examples include:

- Questions used by exams
- Published Exams
- Attempts
- Grading records
- Results
- Historical Enrollment

Conceptual lifecycle should prefer archive/deactivate/close/retire semantics where history must remain recoverable.

Exact lifecycle status values are deferred.

## 10. Audit Boundary

Stage 3 distinguishes:

### Platform Audit

Owned by P3 Shared Platform Services.

Purpose: record generic who-did-what-when activity evidence.

### Domain History

Owned by the relevant business context.

Examples:

- E1 Question Version history
- E5 Regrading history

Platform Audit and Domain History are complementary, not substitutes.

## 11. Authorization Contract

Detailed permission matrix is deferred, but Stage 3 freezes the conceptual authorization equation:

`Role/Profile + Membership + Domain Relationship + Module Permission = Authorization Decision`

Example:

A Teacher profile alone must not automatically grant access to all classes or exams. Authorization may require:

- Teacher profile
- Active school membership
- Relevant Teaching Assignment
- Required module permission

## 12. Finance / Tuition Protection

Finance / Tuition remains a Protected External Context.

No Exam entity owns or writes Finance data, and no Finance entity owns or writes Exam data through this project.

Conceptual relationship remains:

```text
       School Core
       /        \
      /          \
 Exam Core     Finance Core
```

not a direct ownership relationship between Exam and Finance.

This Stage does not define or implement any Finance contract, Finance migration, Finance schema change, Finance UI change, Finance workflow change, or Finance API change.

## 13. Entity Responsibility Matrix

| Entity / Concept | Owner | Key References | External mutation allowed? |
|---|---|---|---|
| User Account | P1 | Membership / profile links | No |
| Membership | P2 | User, Organization | No |
| Student Profile | S1 | optional User | No |
| Teacher Profile | S1 | optional User | No |
| Guardian Profile | S1 | Student relationship | No |
| Academic Year | S2 | — | No |
| Grade | S2 | — | No |
| Field | S2 | — | No |
| Class | S2 | Year / Grade / Field | No |
| Student Enrollment | S3 | Student / Class / Year | No |
| Teaching Assignment | S3 | Teacher / Class / Course | No |
| Course | S4 | Grade / Field context | No |
| Curriculum Node | S4 | Course / parent node | No |
| Question | E1 | Curriculum references | E1 only |
| Question Version | E1 | Question | E1 only |
| Exam | E2 | Curriculum / Question refs | E2 only |
| Published Exam Snapshot | E2 | Question Versions | E2 only |
| Exam Assignment | E3 | Published Exam / Audience | E3 only |
| Attempt | E4 | Assignment / Published Exam / participant | E4 only |
| Answer | E4 | Attempt / Exam Question Entry | E4 only |
| Grading Case | E5 | Attempt | E5 only |
| Answer Grade | E5 | Answer | E5 only |
| Exam Result | E6 | Attempt / Grading | E6 only |
| Analytics Projection | E7 | Result / Attempt / Curriculum | E7 only |

## 14. Frozen Invariants

Approval of Stage 3 freezes the following conceptual invariants:

1. Every business truth has exactly one authoritative owner.
2. Student Profile, Teacher Profile, and Guardian Profile are distinct from User Account.
3. Student Profile is not recreated per academic year.
4. Student Enrollment carries year-specific academic placement.
5. Teaching Assignment carries year-specific teaching responsibility.
6. Curriculum is owned only by School Core.
7. Question Bank references curriculum and does not create canonical curriculum truth.
8. Question content is versioned.
9. Published Exams reference stable Question Versions.
10. An Attempt is permanently bound to one Published Exam Version.
11. Answers belong to Attempt / Delivery context, not Question Bank.
12. Grading owns awarded scores and grading feedback.
13. Result is derived from completed grading and is not an independent manual scoring source.
14. Analytics is derived/read-oriented and must not rewrite operational exam truth.
15. Historical assessment evidence is not silently altered by later edits.
16. Cross-context references do not transfer ownership.
17. Contexts may consume other contexts through explicit contracts but may not directly mutate another context's authoritative truth.
18. Existence of an Exam Result and permission to view that Result are separate concepts.
19. Published exam content used by an Attempt is immutable in place; changes require a new published version.
20. Regrading must be auditable and must not silently erase grading history.
21. Live references and snapshot references serve different purposes and must not be conflated.
22. Historically significant entities should favor archive/deactivate/close/retire semantics over casual hard deletion.
23. Platform Audit and Domain History are distinct but complementary concerns.
24. Teacher profile alone does not imply unrestricted class/course/exam access; authorization considers membership, domain relationship, and module permission.
25. Finance / Tuition remains outside Exam ownership and receives no changes from this project without separate Finance approval.

## 15. Explicit Non-Goals of Stage 3

Stage 3 does not define or implement:

- Physical table names
- Column definitions
- Foreign keys
- Database indexes
- PostgreSQL schemas
- Supabase RLS
- RPCs
- API endpoints
- Backend implementation
- Frontend pages
- Dashboards
- Navigation
- Folder/code structure
- SQL migrations
- Cloudflare configuration
- V5 data migration
- Production or staging deployment
- Detailed authorization matrix
- Finance/Tuition schema, API, UI, migration, workflow, or domain changes

## 16. Stage 3 Freeze Summary

Stage 3 establishes the authoritative answer to:

**Who owns each core business fact, who may reference it, what may change it, and what must remain invariant across context boundaries?**

This contract layer is the bridge between the frozen domain architecture and later physical data-model design. It reduces the risk of duplicated student/class/curriculum truth, mutable historical exam evidence, direct cross-context writes, and Exam/Finance entanglement.

No implementation begins as part of Stage 3.
