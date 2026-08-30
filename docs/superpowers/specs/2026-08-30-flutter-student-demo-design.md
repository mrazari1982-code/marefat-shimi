# Flutter Student Demo Design

**Date:** 2026-08-30
**Status:** Approved in principle by the user on 2026-08-30; written spec pending review
**System:** Marefat Online Exam V5

## 1. Goal

Build a safe Flutter demo for the Marefat V5 exam system that proves the student mobile flow against the existing V5 backend without changing production data.

The first demo must be usable as Flutter Web for fast browser testing and must remain compatible with Android/iOS builds from the same Flutter codebase.

## 2. Environment and Safety

- Repository: `mrazari1982-code/marefat-shimi`.
- Feature branch: `feat/flutter-student-demo`.
- Backend for the demo: Supabase project `marefat-school-test` (`yyqeymyopawhaniyemqo`).
- Production Supabase project `marefat-school` is not modified by this demo phase.
- The demo uses only test students, test attempts, test questions and test exams.
- No service-role key, admin credential or other server secret is embedded in Flutter.
- Client configuration uses only public client-safe values and the existing secure RPC/session model.

## 3. Scope

### Included

1. New Flutter application under `apps/flutter_student_demo/`.
2. Persian RTL responsive UI.
3. Student login using the existing V5 student authentication/session contract where available.
4. Student home/dashboard.
5. Exam list or token-entry launch based on the current test backend contract.
6. Exam runner for multiple-choice V5 questions.
7. Per-question selection and locally retained in-session state.
8. Server-backed answer persistence using existing safe RPCs/endpoints where available.
9. Final exam submission using the existing V5 submission contract.
10. Result view showing permitted summary fields.
11. Loading, empty, invalid-session, network-error and retry states.
12. Flutter Web verification and automated Dart/widget/unit tests that do not mutate production.
13. Configuration documentation for test and future production targets.

### Deferred

- Teacher/admin Flutter portals.
- Parent portal.
- Push notifications.
- Offline multi-day synchronization.
- App Store / Play Store publishing.
- Production backend switch.
- Descriptive/manual-marking workflows.
- Advanced analytics charts.

## 4. Architecture

The Flutter app is a presentation client over the existing V5 backend. It does not duplicate exam business rules in a second database.

Layers:

- `app/`: bootstrap, routing, theme and RTL configuration.
- `core/`: environment configuration, Supabase client, error mapping, shared utilities.
- `features/auth/`: student login/session/logout.
- `features/dashboard/`: student profile and attempt/exam entry points.
- `features/exam/`: exam loading, question navigation, answer save and submit.
- `features/result/`: permitted student result display.

Data repositories hide Supabase/RPC details from widgets. UI widgets consume typed models and controllers only.

## 5. Backend Contract

The Flutter demo should reuse the secure session-bound backend work already defined for the web student portal rather than adding direct table access where private ownership data is involved.

Preferred contracts:

- student login RPC/session creation already used by the web app;
- `v5_student_dashboard(p_session_token, ...)` for private dashboard data if deployed in test;
- secure exam-access/resume RPCs already used by `exam.html`;
- safe answer-save RPC already used by the web runner;
- final submission RPC for the V5 attempt;
- secure student result RPC already used by the web result page.

If the test project is missing one of these already-approved web contracts, the implementation may port the matching migration from the current repository into the **test project only**. No new authorization model is introduced for the Flutter demo.

## 6. Initial User Flow

1. App opens in Persian RTL.
2. Existing valid student session is restored if possible; otherwise login is shown.
3. Student signs in using the same school-issued credentials as the web student portal.
4. Dashboard displays student identity and available/history information allowed by the backend.
5. Student enters or selects the test exam.
6. App loads exam metadata, ordered questions and answer choices without exposing correct-answer flags.
7. Student selects answers and navigates between questions.
8. Answer state is persisted safely through the existing answer-save contract.
9. Student submits the attempt.
10. Backend performs authoritative calculation/finalization.
11. Result screen displays only fields permitted by the backend result-visibility rules.

## 7. Demo Data Target

The current `marefat-school-test` project already contains V5 demo data, including one V5 exam, V5 questions/options, students, attempts and saved student answers. The Flutter demo will use these existing test records instead of copying production records.

The implementation must discover the exact current exam/student test identifiers from the test database rather than hard-coding stale historical IDs into business logic. A default demo exam/token may be offered only as configuration for convenient testing.

## 8. Configuration

Flutter receives environment values through `--dart-define` or equivalent build-time configuration:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- optional `DEMO_EXAM_TOKEN`

Secrets must not be committed. A checked-in `.env.example`/README-style template contains placeholders only.

## 9. UX

- Language: Persian.
- Direction: RTL.
- Mobile-first, responsive to desktop Flutter Web.
- Large touch targets.
- Clear primary action for starting/resuming an exam.
- Persistent exam progress indicator.
- Confirmation before final submission.
- No correct-answer indication before submission/visibility permission.
- Network failures show retry without silently discarding the current local selection.

## 10. Error Handling

The repository layer converts backend/network failures into stable app-level failures such as:

- invalid credentials;
- expired session;
- exam unavailable;
- attempt not owned;
- attempt already finalized;
- answer-save failure;
- submit failure;
- network unavailable.

The UI must not display raw database errors or stack traces to students.

## 11. Testing

Minimum verification for the demo:

- `flutter analyze` passes.
- Dart/unit tests cover model parsing and repository error mapping.
- Widget tests cover login, dashboard loading/error state, selecting an answer, submission confirmation and result rendering.
- A backend smoke test is performed only against `marefat-school-test`.
- No test operation targets `marefat-school` production.
- Flutter Web build succeeds.

If Flutter tooling is unavailable in the execution environment, source-level/static validation is performed here and CI is added so GitHub can run the authoritative Flutter checks.

## 12. Delivery

The feature remains isolated on `feat/flutter-student-demo` until verification is complete. Deliverables are:

- Flutter project source;
- test configuration instructions;
- automated tests;
- CI workflow for analyze/test/web build when useful;
- verification report;
- pull request for review.

Production merge/deployment is not part of this demo approval.