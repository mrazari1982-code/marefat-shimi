# Descriptive Answer Grading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** نمایش و ذخیره پاسخ تشریحی، نگه‌داشتن نتیجه در وضعیت در انتظار تصحیح، و فراهم‌کردن تصحیح امن توسط کادر مدرسه.

**Architecture:** یک Migration افزایشی قراردادهای session-aware دانش‌آموز و RPCهای staff را ایجاد می‌کند و همه محاسبات نمره را در دیتابیس نگه می‌دارد. رابط‌های مستقل دانش‌آموز و مدیر فقط قرارداد JSON/RPC را مصرف می‌کنند و هیچ پاسخ کلیدی در مسیر دانش‌آموز افشا نمی‌شود.

**Tech Stack:** PostgreSQL/Supabase RPC و RLS، HTML/CSS/JavaScript بدون build، Node.js test runner، Python deployment safety checks.

**Spec:** `docs/superpowers/specs/2026-08-31-descriptive-answer-grading-design.md`

## Global Constraints

- متن پاسخ پس از trim حداکثر ۱۰٬۰۰۰ نویسه است و متن خالی پاسخ را پاک می‌کند.
- سؤال تستی خودکار و سؤال تشریحی فقط با RPC کادر مدرسه تصحیح می‌شود.
- تا پایان تصحیح تمام پاسخ‌های تشریحی، `grading_status = pending_manual` و درصد نهایی پنهان است.
- RPC دانش‌آموز هیچ answer key، rubric یا گزینه صحیحی برنمی‌گرداند.
- RPCهای `SECURITY DEFINER` دارای `search_path` ثابت، کنترل مالکیت/نقش و مجوز حداقلی هستند.
- attempt معیوب فعلی حذف یا بازنویسی نمی‌شود.

---

### Task 1: Database contract, snapshot, and student answer storage

**Files:**
- Create: `supabase/migrations/20260831210000_descriptive_answer_grading.sql`
- Create: `tests/descriptive-grading-db-contract.test.js`
- Create: `tests/descriptive-grading-db.sql`

**Interfaces:**
- Produces: `v5_student_get_exam_questions(uuid,text)` including `question_type`; `v5_student_get_attempt_state(uuid,text)` including saved `answer_text`; `v5_student_save_descriptive_answer(uuid,bigint,text,text) -> jsonb`.
- Consumes: `v5_auth_private.student_for_token(text)`, existing attempts, exam questions, question snapshots, and student answers.

- [ ] **Step 1: Write failing contract tests** asserting `LEFT JOIN`, `question_type`, 10,000-character validation, fixed `search_path`, ownership/status/deadline checks, grants, audit columns, and absence of answer-key fields from the student question RPC.
- [ ] **Step 2: Run `node --test tests/descriptive-grading-db-contract.test.js`** and verify failure because the Migration is absent.
- [ ] **Step 3: Add the minimal Migration** with additive columns, contract replacements, text-answer upsert/delete behavior, and least-privilege grants.
- [ ] **Step 4: Run the contract test** and verify it passes.
- [ ] **Step 5: Add executable SQL acceptance cases** covering ownership denial, descriptive type enforcement, trim/delete, length rejection, and Snapshot stability.
- [ ] **Step 6: Commit** with `feat: add descriptive answer database contract`.

### Task 2: Student descriptive-answer interface

**Files:**
- Modify: `public/student-auth.js`
- Modify: `public/exam.html`
- Modify: `tests/student-auth-browser.cjs`
- Modify: `tests/student-journey-browser.cjs`
- Modify: `tests/exam-lifecycle.cjs`

**Interfaces:**
- Consumes: `v5_save_descriptive_answer` mapped to `v5_student_save_descriptive_answer`; question rows with nullable options and `question_type`; saved answers containing `answer_text`.
- Produces: textarea per descriptive question, explicit save button, change autosave, 10,000-character counter, and mixed-type progress.

- [ ] **Step 1: Add failing browser tests** for grouping a descriptive row without options, safe text rendering, restoring saved text, RPC payloads, empty-answer deletion, progress, locking controls, and save errors.
- [ ] **Step 2: Run the focused browser tests** and verify failures reflect missing descriptive UI/RPC mapping.
- [ ] **Step 3: Implement the minimal RPC mapping and descriptive controls** without using untrusted HTML for answer text.
- [ ] **Step 4: Run focused and existing student journey/lifecycle tests** and verify all pass.
- [ ] **Step 5: Commit** with `feat: support descriptive answers in student exam`.

### Task 3: Submission and pending-result semantics

**Files:**
- Modify: `supabase/migrations/20260831210000_descriptive_answer_grading.sql`
- Modify: `public/exam.html`
- Modify: `public/student-result.html`
- Modify: `public/student-dashboard.js`
- Modify: `tests/descriptive-grading-db-contract.test.js`
- Modify: `tests/student-journey-browser.cjs`
- Modify: `tests/student-dashboard-browser.cjs`

**Interfaces:**
- Produces: submit/result/dashboard payload fields `grading_status` and `pending_manual_count`; percentage and result link hidden until `graded`.
- Consumes: saved descriptive answers and audit columns from Task 1.

- [ ] **Step 1: Add failing tests** for answered-vs-blank descriptive counts, `pending_manual`, null percentage, no premature result link, and the Persian waiting message.
- [ ] **Step 2: Run focused tests** and verify expected failures.
- [ ] **Step 3: Implement transactional recalculation** and fail-closed UI handling for pending results.
- [ ] **Step 4: Run focused and regression tests** and verify all pass.
- [ ] **Step 5: Commit** with `feat: hold descriptive results for manual grading`.

### Task 4: Staff manual-grading workflow

**Files:**
- Modify: `supabase/migrations/20260831210000_descriptive_answer_grading.sql`
- Create: `public/admin-descriptive-grading.html`
- Create: `public/admin-descriptive-grading.js`
- Modify: `public/admin-panel.html`
- Create: `tests/admin-descriptive-grading.test.js`
- Modify: `tests/admin-navigation.cjs`
- Modify: `tests/descriptive-grading-db-contract.test.js`

**Interfaces:**
- Produces: `v5_admin_pending_descriptive_answers()` and `v5_admin_grade_descriptive_answer(bigint,numeric,text) -> jsonb`; admin page with score/feedback controls.
- Consumes: staff Supabase auth, Snapshot answer key/rubric, answer audit fields, and recalculation routine.

- [ ] **Step 1: Add failing DB and browser tests** for staff-only access, pending listing, score bounds, full/zero/partial correctness, grader audit, feedback, safe rendering, and panel navigation.
- [ ] **Step 2: Run focused tests** and verify expected failures.
- [ ] **Step 3: Implement minimal staff RPCs and the grading page** using DOM text nodes for untrusted content.
- [ ] **Step 4: Run focused and navigation/security regressions** and verify all pass.
- [ ] **Step 5: Commit** with `feat: add staff descriptive grading workflow`.

### Task 5: Deployment and acceptance gate

**Files:**
- Modify: `tests/deployment-safety.py`
- Modify: `docs/operations/production-readiness-2026-08-31.md`

**Interfaces:**
- Consumes: all deliverables from Tasks 1–4.
- Produces: allowlisted deploy routes and a staging acceptance checklist using a fresh attempt.

- [ ] **Step 1: Add the new admin route to deployment/navigation tests** and verify the safety test initially fails.
- [ ] **Step 2: Update the allowlist and acceptance document** with Migration-first deployment, fresh-attempt mixed exam, pending result, staff grade, and final percentage checks.
- [ ] **Step 3: Run `node --test tests/*.test.js tests/*.cjs`, `python3 tests/deployment-safety.py`, JavaScript syntax checks, SQL contract tests, and `npx wrangler deploy --dry-run --config wrangler.jsonc`**.
- [ ] **Step 4: Review the diff against every section of the design spec** and record any production-only acceptance item as not yet executed.
- [ ] **Step 5: Commit** with `test: gate descriptive grading deployment`.
