# Timer Auto-Submit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalize and grade already-saved answers atomically when an exam reaches its server deadline instead of expiring the attempt.

**Architecture:** Keep `v5_student_submit_attempt(uuid,text)` as the single finalization boundary. The function continues to lock and authorize the owned attempt, but a reached deadline no longer bypasses grading; save RPCs remain responsible for rejecting any answer mutation after the deadline. The browser distinguishes timer-driven submission from manual submission only for the success message.

**Tech Stack:** PostgreSQL 17 / Supabase RPC, static HTML/JavaScript, Node test runner, Python unittest.

**Spec:** `docs/superpowers/specs/2026-08-31-descriptive-answer-grading-design.md`, plus the user-approved timer-finalization addendum from 2026-09-02.

## Global Constraints

- Student ownership must be derived from the authenticated session token.
- Answer writes remain forbidden after the server deadline.
- Finalization must grade only persisted answers and be atomic under the attempt row lock.
- Descriptive answers continue to enter `pending_manual`; provisional totals remain hidden.
- Existing `expired` attempts are not rewritten by the migration.
- RPC grants and fixed `search_path` remain least-privilege.

---

### Task 1: Submission contract and database behavior

**Files:**
- Create: `supabase/migrations/20260902150000_auto_submit_at_deadline.sql`
- Modify: `tests/descriptive-grading-db-contract.test.js`
- Modify: `tests/descriptive-grading-db.sql`

**Interfaces:**
- Consumes: `v5_student_submit_attempt(p_attempt_id uuid, p_session_token text) returns jsonb`
- Produces: the same RPC contract, with `status='submitted'` for a locked `started` attempt even when its deadline has just passed.

- [ ] **Step 1: Write failing contract and SQL integration tests**

Add tests that require deadline finalization to persist `submitted_at`, objective correctness, score, counters, and `grading_status`, while preserving rejection of attempts already marked `expired` and foreign attempts.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `node --test tests/descriptive-grading-db-contract.test.js`

Expected: failure because the new migration does not exist.

- [ ] **Step 3: Implement the minimal migration**

Create a replacement for `v5_student_submit_attempt` based on the latest objective-consistency implementation. Remove only the branch that converts a `started` attempt to `expired` after deadline; retain the row lock, ownership check, objective grading, descriptive pending state, result visibility, fixed search path, revoke, and grants.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `node --test tests/descriptive-grading-db-contract.test.js`

- [ ] **Step 5: Commit the database task**

Commit message: `fix: finalize saved answers at exam deadline`

### Task 2: Timer-driven success message

**Files:**
- Modify: `public/exam.html`
- Modify: `tests/exam-lifecycle.cjs`

**Interfaces:**
- Consumes: `submitExam(force, automatic)` and the unchanged RPC response.
- Produces: timer expiry invokes automatic finalization once and reports that saved answers were submitted automatically.

- [ ] **Step 1: Write a failing browser behavior test**

Require the zero-time timer path to call the submit RPC once, lock controls, and render the Persian automatic-submission success message after a submitted response.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node tests/exam-lifecycle.cjs`

Expected: failure because timer and manual submission currently share the same message.

- [ ] **Step 3: Implement the minimal UI distinction**

Pass an explicit automatic flag from `startTimer` to `submitExam`; on successful finalization, render `زمان آزمون پایان یافت و پاسخ‌های ذخیره‌شده به‌صورت خودکار ثبت نهایی شدند.` without changing result-visibility rules.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node tests/exam-lifecycle.cjs`

- [ ] **Step 5: Commit the UI task**

Commit message: `fix: confirm automatic timer submission`

### Task 3: Verification and release

**Files:**
- Verify only; no additional production behavior.

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: reviewed PR, applied production migration, deployed public assets, and a fresh end-to-end timer test.

- [ ] **Step 1: Run all local verification**

Run: `node --test tests/*.cjs tests/*.js && python -m unittest tests/deployment-safety.py`

- [ ] **Step 2: Review the diff and security boundaries**

Confirm no answer-write deadline checks, auth ownership checks, result-visibility checks, or grants were weakened.

- [ ] **Step 3: Create the PR and verify its checks**

Push `fix/timer-auto-submit`, create a PR against `main`, and merge only when mergeable and checks pass.

- [ ] **Step 4: Apply and verify production**

Apply the migration, deploy the exact merged public tree, then query the RPC definition and deployment URL to confirm both layers match the merged revision.

- [ ] **Step 5: Run a fresh one-minute end-to-end test**

Create a new isolated test exam and link for `MRFT-TEST-12`, save one correct answer, let time expire, verify `submitted` plus score and `submitted_at`, then close the temporary exam and deactivate its link without deleting evidence.
