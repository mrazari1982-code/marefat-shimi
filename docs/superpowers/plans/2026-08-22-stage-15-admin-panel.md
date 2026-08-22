# Stage 15 Admin Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a secure administrator entry point and first dashboard for managing V5 exams and the question bank.

**Architecture:** Keep the student flow in `index.html`. Add a separate `admin.html` using Supabase Auth and staff-only RPC/view access. Reuse existing server-side admin functions rather than exposing table writes directly to the browser.

**Tech Stack:** Static HTML/CSS/JavaScript, Supabase JS v2, Supabase Auth, existing PostgreSQL RPCs/views, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-08-22-stage-15-admin-panel-design.md`

## Global Constraints

- Student exam flow must remain functional.
- Never expose a Supabase service-role key in browser code.
- Admin actions must remain protected by server-side staff checks.
- Use the existing V5 database model and RPCs.

---

### Task 1: Admin entry and authentication

**Files:**
- Create: `admin.html`

**Interfaces:**
- Consumes: Supabase Auth session and `v5_is_staff()`.
- Produces: authenticated admin dashboard shell.

- [ ] Add email/password sign-in form.
- [ ] Restore an existing session on load.
- [ ] Call `v5_is_staff()` after authentication.
- [ ] Hide dashboard for unauthenticated/non-staff users.
- [ ] Add sign-out.

### Task 2: Dashboard data

**Files:**
- Modify: `admin.html`

**Interfaces:**
- Consumes: `v5_exam_builder_view`, `v5_question_bank_admin_view`.
- Produces: exam and question-bank lists.

- [ ] Load exam list after staff verification.
- [ ] Load question-bank summary/list.
- [ ] Add refresh controls.
- [ ] Display useful empty/error states.

### Task 3: Verify without touching student flow

- [ ] Open admin page while logged out and confirm data is hidden.
- [ ] Verify staff gate.
- [ ] Open student page and run the existing test path.
- [ ] Commit the tested stage.
