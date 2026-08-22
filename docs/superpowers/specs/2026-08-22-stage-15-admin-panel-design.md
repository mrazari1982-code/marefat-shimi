# Stage 15 Admin Panel Design

## Goal
Build a secure administrator entry point and first working dashboard for the V5 exam system without changing the already-working student exam flow.

## Scope
Stage 15 is split into independently testable parts:
1. Admin authentication and staff-role gate.
2. Dashboard with exam list and question-bank list.
3. Exam creation and question selection.
4. Exam publishing and link management.

This first implementation delivers parts 1-2 and establishes the UI structure for parts 3-4.

## Security
- Use Supabase Auth for administrator sign-in.
- Require an authenticated session and `public.v5_is_staff()` before exposing admin data/actions.
- Keep student RPCs and student pages unchanged.
- Do not put service-role keys in browser code.

## Existing backend interfaces
- `v5_is_staff()` -> boolean
- `v5_has_role(required_role v5_user_role)` -> boolean
- `v5_admin_create_exam(...)`
- `v5_admin_create_question(...)`
- `v5_admin_add_bank_question_to_exam(...)`
- `v5_admin_publish_exam(...)`
- `v5_create_exam_link(...)`
- `v5_question_bank_admin_view`
- `v5_exam_builder_view`

## UI
Create a separate `admin.html` on the same GitHub Pages branch. The page has:
- email/password login
- session-aware sign out
- staff verification
- dashboard cards
- exam list
- question-bank list
- clear error messages

## Acceptance criteria
- Non-authenticated users cannot see admin data.
- Authenticated non-staff users are denied.
- Staff users can load exams and bank questions.
- Student exam URL remains unchanged and continues to work.
