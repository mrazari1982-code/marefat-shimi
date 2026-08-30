# Unified Portals and Student Dashboard Design

**Date:** 2026-08-29
**Status:** Approved by the user on 2026-08-29
**System:** Marefat Online Exam V5

## 1. Goal

Replace the current ambiguous entry flow and overlapping administration hubs with:

1. a clear public landing page;
2. a useful, private student dashboard;
3. one canonical administration portal for active administrators and deputies;
4. backward-compatible redirects for existing bookmarks and exam links.

The change must preserve all existing students, exams, attempts, answers, results, and working URLs throughout rollout.

## 2. Current Problems

- `index.html` is the exam-token page, although visitors reasonably expect it to be the public home page.
- A student can sign in and take an exam, but cannot list prior attempts, see personal activity totals, inspect visible results, or resume an attempt from a personal home page.
- The result page requires an attempt identifier and does not provide a discoverable history.
- `admin-panel.html` and `admin.html` are two overlapping administration hubs with partially different menus and login behavior.
- Several administration features have two similarly named page families, and some pages are not linked from the canonical navigation.
- Result visibility is currently represented by the existing `show_result_to_student` boolean; the system does not need a more complex release workflow in this phase.

## 3. Scope

### 3.1 Included

- New role-selection landing page at `index.html`.
- New `student-dashboard.html` as the authenticated student home.
- Student profile, activity summary, attempt history, visible-result trend, token entry, resume action, result action, and logout.
- A secure dashboard RPC that derives the student exclusively from the custom student session token.
- Secure resume-by-attempt behavior without exposing or requiring the public exam token again.
- Result-summary visibility based on the existing exam setting.
- Detailed answers and correct answers only after an exam is closed.
- `admin-panel.html` as the sole canonical administration hub.
- Shared administration navigation and links to every active administration feature.
- Backward-compatible routing from `admin.html` and old student entry URLs.
- Persian empty, loading, retry, expired-session, hidden-result, and unavailable-resume states.
- Automated browser, SQL, authorization, deployment-safety, and live-route verification.

### 3.2 Deferred

- Scheduled or manual result release modes.
- Separate controls for score visibility and correct-answer visibility.
- Descriptive-question manual marking.
- Dedicated teacher or parent portals.
- SMS login.
- Deleting duplicate or historical HTML files.
- Assigning exams by class, grade, or field; this remains the next independent feature.

## 4. Canonical Routes

| Purpose | Canonical route | Access |
|---|---|---|
| Public landing | `index.html` | Public |
| Student login | `student-login.html` | Public |
| Student home | `student-dashboard.html` | Valid student session |
| Exam access compatibility | `exam-access.html` | Student session plus valid exam link |
| Exam runner | `exam.html` | Owning student session |
| Student result | `student-result.html` | Owning student session |
| Staff login | `admin-login-v2.html` | Public |
| Staff home | `admin-panel.html` | Active admin/deputy Supabase user |

`admin.html` becomes a compatibility redirect to `admin-panel.html`. Existing feature pages remain deployed in this phase.

## 5. User Flows

### 5.1 Public Landing

`index.html` presents two primary choices:

- **Student:** go to `student-login.html`, or directly to `student-dashboard.html` when a valid student session already exists.
- **Administrator / Deputy:** go to `admin-login-v2.html`, or directly to `admin-panel.html` when a valid active staff session already exists.

If an old link opens `index.html?token=...`, the token is preserved in a safe same-origin return route through student login to the student dashboard.

### 5.2 Student

1. Student signs in with the school-issued username and password.
2. Successful login lands on `student-dashboard.html`.
3. The dashboard loads profile, summary, history, visible trend, and resumable attempts from one secure RPC.
4. Student may enter a new exam token.
5. Student may resume an owned in-progress attempt directly by attempt ID.
6. Student may open an owned result when result visibility permits.
7. Returning from the result page returns to the dashboard.
8. Logout invalidates the server-side student session and clears browser session data.

### 5.3 Administrator / Deputy

1. Staff member signs in at `admin-login-v2.html`.
2. Active `admin` and `deputy` roles enter `admin-panel.html`.
3. The panel links to students, bulk import, passwords, question bank, exam building, question management, publishing, lifecycle, links, results, reports, and analytics.
4. Every administration feature provides a consistent route back to the canonical panel.
5. Old `admin.html` bookmarks redirect to the canonical staff entry without discarding an existing Supabase session.

## 6. Student Dashboard Data Contract

Create the session-bound RPC:

```sql
public.v5_student_dashboard(p_session_token text, p_limit integer default 100) returns jsonb
```

The response shape is:

```json
{
  "profile": {
    "student_code": "...",
    "full_name": "...",
    "grade_name": "...",
    "field_name": "...",
    "class_name": "..."
  },
  "summary": {
    "attempt_count": 0,
    "submitted_count": 0,
    "in_progress_count": 0,
    "visible_result_count": 0,
    "average_percentage": null,
    "correct_count": 0,
    "wrong_count": 0,
    "blank_count": 0
  },
  "attempts": [
    {
      "attempt_id": "uuid",
      "exam_code": "...",
      "exam_title": "...",
      "status": "started|submitted|expired",
      "started_at": "timestamptz",
      "submitted_at": "timestamptz|null",
      "result_visible": true,
      "detail_visible": false,
      "percentage": 75.0,
      "correct_count": 6,
      "wrong_count": 2,
      "blank_count": 0,
      "can_resume": false,
      "resume_reason": null
    }
  ]
}
```

### 6.1 Summary Rules

- `attempt_count` includes every owned attempt.
- `submitted_count` includes submitted attempts whether or not results are visible.
- `in_progress_count` includes attempts still in `started` state.
- Percentage and answer counts contribute only when `result_visible=true`.
- Started, expired, and hidden-result attempts never affect the visible average.
- Empty averages return `null`, not zero.
- Attempt history is newest first and limited to 100 rows in this phase.

## 7. Result Visibility

This phase keeps the existing `v5_exams.show_result_to_student` setting.

- Attempt title, date, and status are always visible to the owner.
- Score, percentage, correct, wrong, and blank counts are visible only when `show_result_to_student=true` and the attempt is finalized.
- If a result is not visible, all score fields are returned as `null`, and the UI shows `در انتظار انتشار`.
- Detailed selected answers, correctness, awarded score, and correct-answer information are returned only when:
  1. the result summary is visible; and
  2. the exam status is `closed`.
- Existing exam-creation pages continue to default result display to enabled.

No aggregate may include hidden scores, because an average change could indirectly disclose a hidden result.

## 8. Resume Contract

Create the session-bound RPC:

```sql
public.v5_student_resume_attempt(p_attempt_id uuid, p_session_token text) returns jsonb
```

It must:

1. validate the student session;
2. require an active student account;
3. require that the attempt belongs to that student;
4. apply the authoritative server deadline check;
5. return only the attempt metadata needed by `exam.html`;
6. refuse submitted, expired, closed, or otherwise unavailable attempts with a stable reason code.

`exam.html?attempt=<uuid>` uses the student-session RPC mappings and never accepts a student code for this flow. Existing token-based links remain compatible.

## 9. Security Model

Student authentication remains the existing custom opaque-session model.

- Raw session tokens are not stored in the database; only token hashes are stored.
- Dashboard, resume, and result RPCs accept a session token and resolve the student inside the database.
- Browser-supplied student codes are not authorization inputs.
- Every attempt operation verifies `attempt.student_id` against the student resolved from the session.
- Active-session expiry and active-student checks occur on every RPC call.
- Privileged functions use a fixed `search_path`, explicitly locked ACLs, and no dynamic SQL.
- RPCs return only the minimum fields required by the page.
- No new direct `SELECT` grant is added to attempts, answers, credentials, or private session tables.
- `SECURITY DEFINER` functions explicitly recheck ownership before reading data.
- Cross-student attempt-ID tests are mandatory.
- Hidden-result and pre-close detail tests are mandatory.

The custom session RPCs remain callable through the anonymous API role because students are not Supabase Auth users; possession of a valid opaque token is necessary but not sufficient, because ownership is revalidated in each function.

## 10. Student Dashboard UI

The dashboard is Persian, RTL, responsive, and usable at 320px width.

### 10.1 Header

- Student name and code
- Grade, field, and class when present
- Logout action

### 10.2 Start Exam

- One exam-token input
- Primary `شروع آزمون` action
- Friendly messages for invalid, not-started, closed, expired, and max-attempt errors

### 10.3 Summary

- Total attempts
- Completed attempts
- In-progress attempts
- Average of visible results
- Totals for correct, wrong, and blank answers

### 10.4 History

Each history row shows title, date, status, and one applicable action:

- `ادامه آزمون`
- `مشاهده کارنامه`
- `در انتظار انتشار`
- unavailable reason

### 10.5 Trend

A small, accessible chronological percentage trend uses only visible finalized results. It is omitted when fewer than two visible results exist.

## 11. Canonical Administration Portal

`admin-panel.html` becomes the only administration hub and includes links to:

- student list;
- bulk Excel import;
- student password management;
- question bank;
- exam creation;
- per-exam question management;
- publication and scheduling;
- exam lifecycle and links;
- results and detailed reports;
- analytics;
- logout.

A small shared navigation script may be used to keep `پنل اصلی` and logout behavior consistent across active administration pages. It must not contain authorization logic; every page and RPC retains its own staff authorization check.

The current `admin.html` functionality is not deleted before equivalent actions are reachable and tested from the canonical panel.

## 12. Compatibility and Redirects

- `admin.html` redirects to `admin-panel.html` after canonical-panel acceptance tests pass.
- Old `index.html?token=...` links preserve the token through student authentication.
- `student-login.html?return=...` accepts only an explicit same-origin allowlist including `student-dashboard.html`, `exam.html`, and `student-result.html`.
- Existing `exam-access.html` links continue to function.
- Duplicate feature pages remain deployed but are removed from canonical menus.
- No HTML file is deleted in this phase.

## 13. Error and Empty States

| Condition | Behavior |
|---|---|
| Missing/expired student session | Clear local session and redirect to student login |
| Inactive student | Deny access and require school contact |
| Dashboard network error | Preserve page shell and show retry action |
| No attempts | Show a clear empty state and token-entry action |
| Hidden result | Show participation and `در انتظار انتشار`; expose no score |
| Resume denied | Show localized reason and refresh dashboard |
| Staff session missing | Redirect to `admin-login-v2.html` |
| Non-staff Supabase user | Sign out and deny administration access |
| One dashboard panel fails | Other successfully loaded information remains usable when possible |

## 14. Rollout Sequence

1. Add SQL tests for dashboard ownership, visibility masking, detail timing, session expiry, inactive students, pagination, and resume authorization.
2. Implement and apply RPCs in staging.
3. Run staging database tests and security/performance advisors.
4. Add browser tests for route protection, safe return URLs, dashboard rendering, hidden values, retry, and resume navigation.
5. Build `student-dashboard.html` while keeping the current `index.html` flow available.
6. Perform mobile and desktop staging acceptance tests.
7. Replace `index.html` with the role-selection landing page and add token-preserving compatibility behavior.
8. Consolidate administration navigation and verify every canonical link.
9. Add `admin.html` compatibility redirect only after feature parity is verified.
10. Run all existing regression tests and deployment allowlist checks.
11. Perform a focused independent security review.
12. Obtain explicit production approval.
13. Apply the compatible migration, merge via GitHub PR, wait for hosting deployment, and verify live routes and ACLs.

## 15. Acceptance Criteria

- A visitor at the root can clearly choose student or staff entry.
- A logged-in student lands on the personal dashboard.
- The student sees only owned profile and attempt data.
- Completed, in-progress, expired, hidden-result, and empty-history states render correctly.
- Hidden scores cannot be inferred from summary totals.
- A student cannot list, resume, or view another student's attempt by changing an ID.
- Correct-answer details are unavailable before the exam is closed.
- An owned in-progress attempt can be resumed without re-entering the public exam token.
- Existing token links continue to work.
- Active administrators and deputies reach every current management feature from one canonical panel.
- Old `admin.html` bookmarks reach the canonical panel.
- No production record is deleted or rewritten by rollout.
- All browser, SQL, syntax, deployment, and live verification tests pass.

## 16. Non-Goals and Next Feature

After this work is accepted, the next independent feature is exam eligibility and assignment by grade, field, and class. It must not be mixed into this implementation because it changes who may start an exam and requires its own authorization design.
