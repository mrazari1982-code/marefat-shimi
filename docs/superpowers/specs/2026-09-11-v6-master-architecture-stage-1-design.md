# Clean Rebuild V6 — Master Architecture Stage 1

Status: **FROZEN / Approved**  
Date: 2026-09-11  
Scope: Architecture only — no implementation, database schema, API, UI, migration, or deployment.

## 1. Purpose

This document freezes the Stage 1 master architecture for the Clean Rebuild V6 of the Marefat Exam System. The previously frozen Question Bank ↔ Exam Construction Crosswalk remains the official input contract and is not reopened by this document.

The objective is to define durable domain boundaries so the exam system can be delivered quickly now while remaining a clean module of the future Marefat Education Platform.

## 2. Chosen Architecture

V6 adopts a **Modular Monolith with explicit Bounded Contexts**.

The top-level architecture has three primary areas:

1. **Platform Foundation** — shared technical and identity capabilities.
2. **School Core** — shared school and academic truth.
3. **Exam Core** — exam-specific business capabilities.

Microservices are explicitly out of scope for the current phase. Internal boundaries must nevertheless be designed so future extraction is possible without redefining ownership.

## 3. Architectural Principles

### 3.1 Single source of truth

Each business fact has exactly one authoritative owner. Other modules reference or consume that fact; they do not create competing authoritative copies.

### 3.2 Exam Core does not own school identity or academic structure

Exam Core must not be the authoritative owner of students, teachers, classes, academic years, grades, fields, enrollments, or curriculum hierarchy.

### 3.3 Dependency direction

Exam Core may consume School Core contracts. School Core must not require Exam Core for its core operation.

Conceptually:

`School Core -> Exam Core`

This arrow means School Core exposes academic truth for use by Exam Core; it does not mean School Core depends on Exam Core.

### 3.4 Contracts over internal coupling

Even when V6 initially uses a shared Supabase/PostgreSQL backend, cross-context access must be designed through explicit contracts and ownership rules rather than uncontrolled table coupling.

### 3.5 YAGNI

Future modules may be reserved conceptually in the architecture, but no table, endpoint, page, workflow, or code is created for a future module until the current Exam MVP or a necessary architectural dependency requires it.

## 4. Platform Foundation

Platform Foundation owns shared capabilities that are neither specifically school-domain nor exam-domain concerns.

Primary responsibilities:

- Authentication
- User account identity
- Organization / school identity
- Membership foundation
- Role assignment foundation
- Permission infrastructure
- File/storage abstraction
- Audit/activity infrastructure
- Shared system settings where truly cross-domain

A user account is not the same concept as a student or teacher profile.

Conceptual identity chain:

`User -> Organization Membership -> Domain Profile / Role`

This separation allows future support for school users and independent users without corrupting school-domain records.

## 5. School Core

School Core owns the authoritative academic and organizational truth used by multiple modules.

Primary owned concepts include:

- Academic Year
- Grade
- Field / رشته
- Class
- Student profile
- Teacher profile
- Guardian profile
- Counselor profile
- Enrollment
- Teacher-Class / Teacher-Course assignment
- Subject / Course / Book
- Curriculum hierarchy
- Chapter
- Topic
- Subtopic

School Core represents the educational reality of the school. It is not responsible for question-bank lifecycle, exam attempts, grading, or exam results.

## 6. Exam Core

Exam Core owns the assessment lifecycle.

Primary subdomains:

### 6.1 Question Bank

- Question
- Question Version
- Question Option
- Question source metadata
- Source / rights information related to question provenance
- Question family and relationships
- Review workflow
- Duplicate handling
- Audit/history specific to question lifecycle
- Import/extraction/AI-assisted creation flows previously frozen in Question Bank design

### 6.2 Exam Construction

- Exam definition
- Exam sections
- Exam-question composition
- Construction methods frozen in the official Crosswalk
- Assignment/targeting of exams to eligible audiences

### 6.3 Exam Delivery

- Availability rules
- Start/continue/submit lifecycle
- Timing and deadline behavior
- Attempt control
- Answer capture

### 6.4 Grading and Results

- Objective grading
- Descriptive/manual grading
- Exam result
- Exam-specific feedback

### 6.5 Exam Analytics

- Correct/wrong/blank analysis
- Topic-level exam performance
- Trend across exams
- Question analysis
- Rank/relative exam metrics where applicable

Exam Analytics is not the future cross-platform Educational Analytics domain.

## 7. Curriculum Ownership

Curriculum hierarchy belongs to School Core, not to Question Bank.

Canonical conceptual hierarchy:

`Grade -> Field -> Course/Book -> Chapter -> Topic -> Subtopic`

Questions reference curriculum nodes. They do not own the canonical definitions of those nodes.

This permits the same curriculum structure to be reused by exams, educational content, lesson planning, counseling, assignments, and future analytics.

## 8. Role Model Boundary

V6 distinguishes platform identity, organization membership, domain profiles, and module permissions.

School roles may include:

- Student
- Teacher
- Guardian
- Counselor
- Deputy
- Admin

Module permissions are separate from role names, for example:

- `Exam.create`
- `Question.create`
- `Question.review`
- `Result.grade`

Detailed permission design is not part of Stage 1.

## 9. Independent Users

The architecture must not require every exam-system user to belong to a school.

Future independent learner and independent teacher scenarios are supported conceptually through Platform Foundation identities that can use permitted Exam Core capabilities without requiring a fabricated School Core membership.

No independent-user implementation is included in Stage 1.

## 10. Results vs School Report Card

**Exam Result** belongs to Exam Core.

A future **official school report card / academic record** belongs to a separate school academic-records concern and may consume Exam Core results.

These concepts must not be merged.

## 11. Exam Analytics vs Educational Analytics

Exam Core owns analysis derived from exams and question responses.

A future Educational Analytics capability may combine exams with attendance, assignments, counseling, lesson plans, teaching performance, and other modules.

Therefore Exam Analytics must remain a bounded assessment capability and must not become a catch-all analytics domain.

## 12. Crosswalk Placement

The previously frozen Question Bank ↔ Exam Construction Crosswalk remains authoritative.

Both sides of that Crosswalk are placed inside Exam Core:

- Question Bank
- Exam Construction

Stage 1 changes their architectural location only; it does not change their frozen functional contracts.

## 13. Data Ownership Matrix

| Concept | Authoritative owner |
|---|---|
| User account | Platform Foundation |
| Organization / school | Platform Foundation |
| Academic year | School Core |
| Grade / field | School Core |
| Class | School Core |
| Student / teacher / guardian / counselor profile | School Core |
| Enrollment / teaching assignment | School Core |
| Curriculum hierarchy | School Core |
| Question / option / version / family | Exam Core |
| Exam / section / exam-question composition | Exam Core |
| Exam assignment | Exam Core |
| Attempt / answer | Exam Core |
| Grading / exam result | Exam Core |
| Exam analytics | Exam Core |
| Official school report card | Future school academic-records domain |
| Cross-module educational analytics | Future educational-analytics domain |

## 14. Explicit Non-Goals of Stage 1

Stage 1 does **not** define or implement:

- Physical PostgreSQL tables
- Supabase schemas
- RLS policies
- API endpoints
- RPC functions
- UI pages
- Navigation
- File/folder code structure
- Migrations
- Production or staging deployment
- Legacy V5 data migration
- Tuition, counseling, attendance, lesson-plan, content/video, or other future modules

## 15. Freeze Decisions

The following decisions are frozen by approval of Stage 1:

1. V6 uses a Modular Monolith with explicit bounded contexts.
2. Platform Foundation, School Core, and Exam Core are the primary top-level boundaries.
3. School Core owns school and curriculum truth.
4. Exam Core owns Question Bank and the complete assessment lifecycle.
5. Exam Core must not create authoritative duplicate Student, Teacher, Class, Academic Year, or Curriculum data.
6. Every business fact has one authoritative owner.
7. Cross-context interaction must respect contracts and ownership boundaries, even on a shared database.
8. The frozen Question Bank ↔ Exam Construction Crosswalk remains authoritative and both areas belong to Exam Core.
9. Exam Result is distinct from the future official school report card.
10. Exam Analytics is distinct from future cross-module Educational Analytics.
11. Future modules are architecture-aware but implementation-free until required.
12. Database schema, API, page design, code structure, migration, and deployment are deferred to later stages.

## 16. Stage 1 Architecture Map

```text
MAREFAT EDUCATION PLATFORM
│
├── PLATFORM FOUNDATION
│   ├── Identity / Authentication
│   ├── Organization
│   ├── Membership / Access foundation
│   ├── Permissions infrastructure
│   ├── Files
│   └── Audit
│
├── SCHOOL CORE
│   ├── Academic Years
│   ├── Grades / Fields
│   ├── Classes
│   ├── Students / Teachers / Guardians / Counselors
│   ├── Enrollments / Teaching Assignments
│   └── Curriculum
│       └── Course/Book -> Chapter -> Topic -> Subtopic
│
└── EXAM CORE
    ├── Question Bank
    ├── Exam Construction
    ├── Exam Delivery
    ├── Attempts / Answers
    ├── Grading
    ├── Results
    └── Exam Analytics
```

## 17. Next Design Stage

The next stage, after review of this frozen document, is:

**Stage 2 — Domain Map / Bounded Context Map V6**

Its purpose is to enumerate domain entities and responsibilities context by context, define boundary contracts and forbidden dependencies more precisely, and identify aggregates/concepts without yet designing physical database tables or writing code.
