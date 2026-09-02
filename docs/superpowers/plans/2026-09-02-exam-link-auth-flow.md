# Exam Link Authentication Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route public exam links through authenticated student login and show an already-submitted outcome without opening the exam page or creating another attempt.

**Architecture:** Keep `exam-access.html` as a public link validator, then send the token through the existing safe login-return pipeline to `student-dashboard.html`. Let the authenticated dashboard call the existing session-bound start RPC; branch on its returned status and render a safe result action from the refreshed, server-filtered dashboard payload.

**Tech Stack:** Static HTML/JavaScript, Supabase RPC wrapper, Node `vm` browser-contract tests, Python deployment-safety tests.

**Spec:** User-approved conversation design: link → student login → preserved token → submitted-attempt message/result action → no second attempt.

## Global Constraints

- Do not restore student-code-only exam access.
- Preserve the existing bounded and canonicalized token return path.
- Never expose a result action unless the refreshed dashboard marks `result_visible === true`.
- Render server-derived content with DOM text APIs, not HTML interpolation.
- No database migration is required; the production RPC already returns the existing submitted attempt without inserting another row.

---

### Task 1: Public exam-link entry

**Files:**
- Modify: `public/exam-access.html`
- Create: `tests/exam-access-browser.cjs`

**Interfaces:**
- Consumes: `MarefatStudentAuth.getSession()` and the existing `student-login.html?return=...` contract.
- Produces: a canonical `student-dashboard.html?token=<encoded token>` destination.

- [x] Write browser-contract tests proving guests go to login, signed-in students go to the dashboard, invalid links stay on the page, and no student-code field remains.
- [x] Run `node --test tests/exam-access-browser.cjs` and verify the current page fails those assertions.
- [x] Replace the legacy student-code form with session-aware routing after successful link validation.
- [x] Run `node --test tests/exam-access-browser.cjs` and verify it passes.

### Task 2: Submitted-attempt outcome

**Files:**
- Modify: `public/student-dashboard.js`
- Modify: `public/student-dashboard.html`
- Modify: `tests/student-dashboard-browser.cjs`

**Interfaces:**
- Consumes: `v5_start_exam` result `{status, attempt_id}` and refreshed `v5_dashboard` attempt visibility.
- Produces: a localized prior-submission message and, only when allowed, `student-result.html?attempt=<encoded id>` action.

- [x] Add tests proving `submitted` never navigates to `exam.html`, refreshes owned history, displays the prior-submission message, and exposes a result action only for a visible result.
- [x] Run `node tests/student-dashboard-browser.cjs` and verify the current implementation fails.
- [x] Add a dedicated start-outcome container and status-aware start handling using safe DOM construction.
- [x] Run `node tests/student-dashboard-browser.cjs` and verify all dashboard tests pass.

### Task 3: Verification and delivery

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-exam-link-auth-flow.md`

**Interfaces:**
- Consumes: completed Tasks 1–2.
- Produces: reviewed commit, PR, and production verification evidence.

- [x] Run `node --test tests/*.cjs tests/*.js`.
- [x] Run `python3 tests/deployment-safety.py`.
- [x] Verify all inline public scripts parse.
- [x] Review the diff for token leakage, open redirects, result-visibility bypass, and unsafe DOM sinks.
- [ ] Commit, request independent code review, push the branch, create a PR, merge after checks, and verify the live assets.
