# Clean Rebuild V6 — Domain Map / Bounded Context Map — Stage 2

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Domain architecture only — no physical database tables, SQL, Supabase schema, API implementation, UI, migration, deployment, or Finance/Tuition changes.

## 1. Purpose

This document freezes Stage 2 of Clean Rebuild V6 for the Marefat Exam System. It refines the Stage 1 master architecture into explicit bounded contexts, ownership rules, allowed dependencies, forbidden dependencies, and conceptual aggregates.

The previously frozen Question Bank design, Exam Construction design, and Question Bank ↔ Exam Construction Crosswalk remain authoritative and are not reopened here.

Finance / Tuition is explicitly protected from change by this stage.

## 2. Architectural Style

V6 remains a **Modular Monolith with explicit Bounded Contexts**.

The system is organized into three primary top-level areas:

1. **Platform Foundation**
2. **School Core**
3. **Exam Core**

A fourth category, **External / Protected Contexts**, is used to describe modules that must remain outside the scope of this Clean Rebuild stage.

## 3. Domain Map

```text
MAREFAT EDUCATION PLATFORM
│
├── PLATFORM FOUNDATION
│   ├── P1. Identity & Access
│   ├── P2. Organization & Membership
│   └── P3. Shared Platform Services
│
├── SCHOOL CORE
│   ├── S1. People & School Profiles
│   ├── S2. Academic Structure
│   ├── S3. Enrollment & Teaching Assignment
│   └── S4. Curriculum Catalog
│
├── EXAM CORE
│   ├── E1. Question Bank
│   ├── E2. Exam Design & Construction
│   ├── E3. Exam Assignment & Scheduling
│   ├── E4. Exam Delivery & Attempts
│   ├── E5. Grading
│   ├── E6. Exam Results
│   └── E7. Exam Analytics
│
└── EXTERNAL / PROTECTED CONTEXTS
    └── Finance / Tuition
        └── Out of scope and protected from change
```

## 4. Platform Foundation Contexts

### P1 — Identity & Access

Purpose: own platform-level user identity, authentication, account state, and permission infrastructure.

Primary owned concepts:

- User Account
- Authentication Identity
- Login Credentials
- Session
- Account Status
- Permission foundation

Critical rule:

`User Account != Student Profile`

`User Account != Teacher Profile`

`User Account != Guardian Profile`

A school profile may exist before a login account exists. This supports bulk school-data import and later account provisioning.

### P2 — Organization & Membership

Purpose: own organization/school membership at the platform level.

Primary owned concepts:

- Organization
- School identity
- Membership
- Membership Status
- Organization Role Assignment foundation

This context does not own teacher-course assignments, class assignments, or student enrollment. Those belong to School Core.

### P3 — Shared Platform Services

Purpose: provide truly cross-domain technical capabilities.

Primary responsibilities:

- File / Attachment foundation
- Storage abstraction
- Audit Trail infrastructure
- Activity Logging infrastructure
- Shared system settings where genuinely cross-domain
- Notification foundation

Guardrail: P3 must not become a generic dumping ground for module-specific settings.

Examples:

- Exam duration belongs to Exam Core.
- Tuition configuration belongs to Finance.

## 5. School Core Contexts

### S1 — People & School Profiles

Purpose: own the school-domain identity/profile of people.

Primary owned concepts:

- Student Profile
- Teacher Profile
- Guardian Profile
- Counselor Profile

A school profile is distinct from the user's login account and distinct from yearly academic placement.

### S2 — Academic Structure

Purpose: own the canonical academic structure of the school.

Primary owned concepts:

- Academic Year
- Grade
- Field / رشته
- Class

Exam Core must reference this structure rather than create competing authoritative copies.

### S3 — Enrollment & Teaching Assignment

Purpose: own time-bound academic participation and assignment relationships.

Primary owned concepts:

- Student Enrollment
- Class Membership
- Teacher Assignment
- Teacher ↔ Class assignment
- Teacher ↔ Course assignment
- Academic-year participation

Example conceptual flow:

`Student Profile -> Enrollment for Academic Year -> Grade / Field / Class`

Exam Core may consume this information for audience targeting but may not change enrollment.

### S4 — Curriculum Catalog

Purpose: own the canonical school curriculum hierarchy.

Canonical conceptual hierarchy:

`Grade -> Field -> Course/Book -> Chapter -> Topic -> Subtopic`

Question Bank references curriculum nodes but does not own their canonical definitions.

The curriculum catalog is designed for reuse by exams, educational content, lesson planning, assignments, counseling, and future analytics.

## 6. Exam Core Contexts

### E1 — Question Bank

Purpose: own the complete question lifecycle.

Primary owned concepts:

- Question
- Question Version
- Question Option
- Question Family
- Question Relations
- Question Review
- Duplicate handling
- Question Source
- Source / Rights metadata
- Question History / Audit specific to question lifecycle
- Import / extraction flows
- AI-assisted question creation flows

The previously frozen Question Bank design remains authoritative.

Boundary rule:

**Question Bank owns questions, not curriculum.**

It references School Core curriculum nodes.

### E2 — Exam Design & Construction

Purpose: own the definition and composition of an exam before delivery.

Primary owned concepts:

- Exam Definition
- Exam Draft
- Exam Section
- Exam-Question Composition
- Question Order
- Score Allocation
- Construction Method
- Exam Version
- Published Exam Form

The previously frozen Exam Construction design and Crosswalk remain authoritative.

#### Published Exam Snapshot rule

A published exam must reference stable/versioned question content so that later edits to Question Bank do not silently mutate an already published exam.

Conceptually:

`Question Version -> Exam Construction -> Publish -> Immutable Exam Snapshot`

This clarifies execution boundaries without reopening the frozen Question Bank or Exam Construction functional designs.

### E3 — Exam Assignment & Scheduling

Purpose: own who may take an exam, when, and under what participation rules.

Primary owned concepts:

- Exam Assignment
- Audience
- Availability Window
- Start Time
- End Time
- Eligibility
- Attempt Policy
- Access Rule

Possible audiences include:

- Individual student
- Class
- Multiple classes
- Grade
- Field
- Selected group
- Independent user

For school audiences, E3 consumes S2/S3 data and does not own or mutate it.

### E4 — Exam Delivery & Attempts

Purpose: own the active exam-taking lifecycle.

Primary owned concepts:

- Attempt
- Attempt State
- Started At
- Deadline
- Answer
- Save Progress
- Resume
- Submit
- Auto-submit
- Expired Attempt
- Second-attempt prevention

Canonical lifecycle examples:

`eligible -> started -> in_progress -> submitted`

or

`started -> time expired -> auto-submit`

### E5 — Grading

Purpose: own assessment of submitted answers.

Primary owned concepts:

- Objective Grading
- Manual Grading
- Descriptive Grading
- Score Award
- Grading Status
- Teacher Feedback
- Regrading
- Grading Completion

This context explicitly separates answer capture from answer evaluation.

### E6 — Exam Results

Purpose: own the finalized result of one exam participation.

Primary owned concepts:

- Exam Result
- Total Score
- Percentage
- Correct Count
- Wrong Count
- Blank Count
- Result Status
- Exam Feedback Summary

Critical boundary:

`Exam Result != Official School Report Card`

The official school report card belongs to a future school academic-records domain.

### E7 — Exam Analytics

Purpose: analyze exam-derived data without becoming the source of truth for operational exam state.

Primary responsibilities:

- Student exam-performance analysis
- Class performance analysis
- Exam analysis
- Question analysis
- Correct / wrong / blank rates
- Weak / strong topics
- Monthly trends
- Comparison across exams
- Rank / relative metrics where applicable
- Chapter / Topic / Subtopic analysis

Critical rule:

**Analytics may read and derive; it must not mutate Question, Attempt, Grading, or Result truth.**

## 7. Lifecycle Map

The canonical exam-domain lifecycle is:

```text
Question
   ↓
Exam Construction
   ↓
Assignment
   ↓
Delivery / Attempt
   ↓
Grading
   ↓
Result
   ↓
Analytics
```

This lifecycle is a domain responsibility map, not a physical API or database workflow.

## 8. Consumer / Provider Rules

The following convention is used in this section:

`Consumer -> Provider` means the left-side context consumes information or services owned by the right-side context.

| Consumer | Provider | Purpose |
|---|---|---|
| S1 | P1/P2 | Optional link between school profile and platform account/membership |
| S3 | S1 | Student / Teacher identity |
| S3 | S2 | Academic Year / Grade / Field / Class |
| S3 | S4 | Course assignment where applicable |
| E1 | S4 | Curriculum classification of questions |
| E2 | E1 | Selection of approved/versioned questions |
| E2 | S4 | Educational scope of an exam |
| E3 | E2 | Published exam definition/snapshot |
| E3 | S2/S3 | School audience eligibility |
| E3 | P1/P2 | Platform identity / membership access |
| E4 | E3 | Participation authorization and rules |
| E4 | E2 | Published exam snapshot |
| E5 | E4 | Submitted answers |
| E5 | E2/E1 | Scoring rules / approved question version data |
| E6 | E5 | Grading completion and scores |
| E6 | E4 | Attempt state |
| E7 | E4/E5/E6 | Performance data |
| E7 | S4 | Curriculum hierarchy for analysis |
| E7 | S2/S3 | Grade / class / enrollment dimensions |

## 9. Forbidden Dependencies

### 9.1 School independence from Exam

School Core must not require Exam Core to perform its core school responsibilities.

Forbidden conceptual dependency:

`School Core -X-> Exam Core`

### 9.2 Foundation independence

Platform Foundation must not depend on School Core or Exam Core.

Forbidden:

`Platform Foundation -X-> School Core`

`Platform Foundation -X-> Exam Core`

### 9.3 Question Bank isolation from attempts/results

Question Bank must not know which student answered a question or what result they received.

Forbidden:

`Question Bank -X-> Attempt`

`Question Bank -X-> Result`

### 9.4 Analytics is read/derive only

Forbidden:

`Analytics -X-> Change Result`

`Analytics -X-> Change Attempt`

`Analytics -X-> Change Question`

### 9.5 Exam / Finance isolation

For current V6 Clean Rebuild scope there is no direct dependency between Exam Core and Finance/Tuition.

Forbidden:

`Exam Core -X-> Finance`

`Finance -X-> Exam Core`

Any future cross-module integration must use shared platform/school truth and an explicit contract, not direct schema entanglement.

## 10. Finance / Tuition Protection Guardrail

Finance / Tuition is classified as a **Protected External Context** for this Clean Rebuild V6 Exam work.

The following are explicitly prohibited in this stage and in subsequent Exam work unless separately approved in the Finance project:

- Finance schema changes
- Finance table changes
- Finance API changes
- Finance migrations
- Finance workflow changes
- Finance UI changes
- Adding exam-owned fields inside Finance
- Adding finance-owned fields inside Exam

Conceptual relationship:

```text
          School Core
         /           \
        /             \
   Exam Core       Finance Core
```

Not:

`Exam Core <-> Finance Core`

## 11. Shared Student Rule

Exam and Finance must not each create their own authoritative student truth.

Target architecture:

```text
School Core
   Student
    /   \
   /     \
Exam    Finance
```

However, this stage does not implement any Finance integration or migration.

## 12. Student Profile vs User Account

A Student Profile may exist without a User Account.

Valid state:

`Student Profile exists; User Account not yet provisioned.`

Later the school profile may be linked to a platform User Account.

The same pattern can be used for Teacher and Guardian profiles.

## 13. Independent Users

The architecture must support future independent users without fake school structures.

Conceptually:

```text
Platform User
   ├── Independent Learner -> permitted Exam Core capabilities
   └── Independent Teacher -> permitted Question Bank / Exam capabilities
```

The system must not require fake School, Class, or Enrollment records for these users.

No independent-user implementation is part of Stage 2.

## 14. Question Bank / Exam Construction Boundary

Canonical boundary:

```text
Question Bank
    │
    │ supplies approved/versioned questions
    ▼
Exam Construction
```

After publication:

```text
Exam Construction
    │
    │ produces stable published exam snapshot
    ▼
Exam Delivery
```

Therefore Delivery must not depend on mutable live Question Bank state for a previously published exam.

## 15. Answer / Grading / Result / Analytics Boundary

Canonical direction:

`Answer -> Grading -> Result -> Analytics`

Forbidden conceptual reverse effects include:

- Analytics determining or rewriting a grade
- Result mutating student answers
- Analytics changing question truth

## 16. Roles vs Permissions

School-domain role/profile and module permissions are different concepts.

Examples of role/profile:

- Teacher
- Student
- Guardian
- Counselor
- Deputy
- Admin

Examples of module permissions:

- `question.create`
- `question.review`
- `exam.create`
- `exam.publish`
- `grading.perform`
- `result.view_class`

This avoids creating excessive compound roles such as `teacher_reviewer_exam_creator`.

Detailed authorization design is deferred.

## 17. Conceptual Aggregates

These are conceptual ownership units, not physical tables.

| Context | Primary conceptual aggregate(s) |
|---|---|
| P1 | User Account |
| P2 | Organization / Membership |
| S1 | Student / Teacher / Guardian / Counselor |
| S2 | Academic Year / Class |
| S3 | Enrollment / Teaching Assignment |
| S4 | Curriculum Node / Course |
| E1 | Question |
| E2 | Exam |
| E3 | Exam Assignment |
| E4 | Attempt |
| E5 | Grading Case |
| E6 | Exam Result |
| E7 | Analytics Projection |

## 18. Explicit Non-Goals of Stage 2

Stage 2 does not define or implement:

- Physical table names
- Column definitions
- Foreign keys
- PostgreSQL schemas
- Supabase RLS
- RPC functions
- API endpoints
- Backend implementation
- Folder/code structure
- Pages
- Dashboards
- Navigation
- Frontend implementation
- SQL migrations
- Cloudflare configuration
- V5 migration
- Production deployment
- Any Finance/Tuition change

## 19. Freeze Decisions

Approval of Stage 2 freezes the following decisions:

1. V6 retains the Stage 1 top-level boundaries: Platform Foundation, School Core, Exam Core.
2. Platform Foundation is divided into P1 Identity & Access, P2 Organization & Membership, and P3 Shared Platform Services.
3. School Core is divided into S1 People & School Profiles, S2 Academic Structure, S3 Enrollment & Teaching Assignment, and S4 Curriculum Catalog.
4. Exam Core is divided into E1 Question Bank, E2 Exam Design & Construction, E3 Exam Assignment & Scheduling, E4 Exam Delivery & Attempts, E5 Grading, E6 Exam Results, and E7 Exam Analytics.
5. Frozen Question Bank design belongs to E1 and is not redesigned here.
6. Frozen Exam Construction design and Crosswalk belong to E2 and are not redesigned here.
7. The canonical exam lifecycle is Question -> Construction -> Assignment -> Delivery -> Grading -> Result -> Analytics.
8. Published exams use stable/versioned question content so later Question Bank edits do not silently change published exam content.
9. Student/Teacher/Guardian profiles are distinct from login User Accounts.
10. Curriculum is owned only by School Core and referenced by Exam Core.
11. School Core must not depend on Exam Core for its core operation.
12. Platform Foundation must not depend on School Core or Exam Core.
13. Analytics is read/derive oriented and must not mutate operational Exam truth.
14. Finance/Tuition is a Protected External Context for Clean Rebuild V6 Exam work.
15. Exam and Finance have no direct dependency in current scope.
16. No Finance schema, table, API, migration, UI, workflow, or domain field may be changed from this Exam project without separate approval in the Finance project.
17. Physical data model, API design, pages, code structure, migrations, and implementation remain deferred.

## 20. Stage 2 Mind Map

```text
                         MAREFAT V6
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
       PLATFORM           SCHOOL              EXAM
          │                  │                  │
   ┌──────┼──────┐      ┌────┼────┬────┐       │
   │      │      │      │    │    │    │       │
Identity Org   Shared People Acad Enroll Curriculum
                                               │
                                               ▼
                                         Question Bank
                                               │
                                               ▼
                                      Exam Construction
                                               │
                                               ▼
                                         Assignment
                                               │
                                               ▼
                                          Delivery
                                               │
                                               ▼
                                           Grading
                                               │
                                               ▼
                                           Results
                                               │
                                               ▼
                                          Analytics

                     Finance / Tuition
                           │
                   PROTECTED CONTEXT
                           │
                    NO CHANGE HERE
```

## 21. Next Design Stage

The next stage must continue design only and must not start implementation automatically.

A recommended next stage is to define **Domain Contracts / Entity Responsibility Map V6**: the precise conceptual responsibilities, ownership references, lifecycle invariants, and allowed cross-context contracts for each major entity before physical database modeling begins.
