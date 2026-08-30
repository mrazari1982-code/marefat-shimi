# Flutter Student Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Persian RTL Flutter student demo for Marefat Online Exam V5 that runs on Web and Android, connects only to the `marefat-school-test` Supabase project, and supports login, dashboard, exam start/resume, answer saving, submission, and result viewing.

**Architecture:** The app lives in `apps/flutter_student_demo/`, uses `supabase_flutter`, and receives staging URL/publishable key via `--dart-define`. Student authorization uses only the existing session-bound `v5_student_*` RPCs. Widgets depend on a focused `StudentApi` repository and typed models rather than direct table access.

**Tech Stack:** Flutter stable, Dart 3, `supabase_flutter` 2.x, `flutter_secure_storage` 9.x, `flutter_test`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-30-flutter-student-demo-design.md`

## Global Constraints
- Staging only: `marefat-school-test` (`yyqeymyopawhaniyemqo`).
- Never embed a service-role/secret key.
- Use only publishable client configuration.
- Persian RTL, mobile-first, responsive to 320 px.
- Preserve the existing opaque student-session authorization model.
- Do not expose correct answers before server-authorized result detail.
- One codebase must build for Web and Android.

---

### Task 1: Scaffold and configuration
- [ ] Add `pubspec.yaml`, config helper, app bootstrap, initial tests, and CI workflow.
- [ ] RED: config/model tests fail before production classes exist.
- [ ] GREEN: implement minimal classes and rerun tests.

### Task 2: Data layer
- [ ] Add secure session store, typed models, and `StudentApi` RPC repository.
- [ ] Cover representative login/dashboard/attempt/question/result payload parsing.

### Task 3: Login and dashboard
- [ ] Add Persian RTL login, session restore, dashboard summary/history, exam-token entry, resume, retry, and logout.
- [ ] Add widget tests for labels/loading/error behavior.

### Task 4: Exam runner
- [ ] Load attempt/questions/saved answers, show progress/countdown, navigate questions, and save each selected option through `v5_student_save_answer`.
- [ ] Add widget tests for selection/navigation.

### Task 5: Submit and result
- [ ] Confirm submit through `v5_student_submit_attempt` and render `v5_student_get_result` without inventing hidden details.
- [ ] Add result widget tests.

### Task 6: CI and staging verification
- [ ] In GitHub Actions generate missing Web/Android platform scaffolding with `flutter create . --platforms=web,android`.
- [ ] Run `flutter test` and `flutter analyze`.
- [ ] Build Web and Android APK with staging `--dart-define` values.
- [ ] Upload `flutter-web-demo` and `flutter-apk-demo` artifacts.
- [ ] Add README and a verification report.
