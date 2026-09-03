# Exam Creation V5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** پیاده‌سازی پنج مسیر ساخت آزمون V5 با هسته مشترک پیش‌نویس، Snapshot، زمان‌بندی، تخصیص، فایل/پاسخ‌برگ، آزمون حضوری، نسخه حرفه‌ای، AI و کپی آزمون قبلی؛ بدون شکستن مسیرهای فعلی آزمون و انتشار.

**Architecture:** معماری موجود حفظ می‌شود و زیرسامانه ساخت آزمون به یک «هسته مشترک آزمون» و چند ورودی تخصصی تقسیم می‌شود. منطق حساس در Supabase RPC/SQL قرار می‌گیرد و صفحات HTML/JS صرفاً رابط و orchestration هستند. تغییرات به‌صورت migrationهای افزایشی و غیرتخریبی اجرا می‌شوند؛ production تا پایان تست staging تغییر نمی‌کند.

**Tech Stack:** Supabase PostgreSQL/RLS/RPC، HTML/CSS/Vanilla JS، Supabase JS v2، Cloudflare deployment، GitHub.

**Spec:** `docs/superpowers/specs/2026-09-03-exam-creation-v5-design.md`

## Global Constraints

- پنج روش ساخت آزمون در صفحه ورودی هم‌اندازه و هم‌وزن بصری باشند.
- ترتیب روش‌ها: فایل/برگه، سریع، حرفه‌ای، AI، آزمون قبلی.
- OCR/AI در مسیر «اصل فایل» هرگز وابستگی مسدودکننده نباشد.
- هیچ سؤال AI/OCR بدون تأیید دبیر نهایی یا وارد بانک مدرسه نشود.
- آزمون منتشر/برگزارش‌شده Snapshot تاریخی ثابت داشته باشد.
- Autosave، وضعیت ذخیره، قطع اینترنت و تعارض چند تب برای همه روش‌ها مشترک باشد.
- Hard errors فقط خطاهای ساختاری واقعی را مسدود کنند؛ هشدارهای کیفیت قابل عبور باشند.
- آزمون جبرانی یک آزمون جدیدِ مرتبط است؛ آزمون اصلی تغییر نمی‌کند.
- نتیجه و نمایش پاسخ صحیح دو تنظیم مستقل هستند.
- PDF، DOCX، XLSX، JPG/JPEG و PNG در نسخه اصلی پشتیبانی شوند.
- OMR/تشخیص خودکار پاسخ‌برگ چاپی و Excel نامنظم در طرح توسعه بمانند.
- همه migrationها ابتدا staging اجرا و تست شوند؛ production فقط با تأیید جداگانه.

---

## File Map

### Existing files to modify
- `admin-exam-builder.html` — از سازنده تک‌مسیره بانک سؤال به نقطه ورود یا redirect سازگار با سازنده جدید تبدیل می‌شود.
- `admin-exam-publish.html` — نمایش checklist انتشار و پیام‌های hard error/warning را می‌گیرد.
- `admin-panel.html` — لینک «ساخت آزمون جدید»، «آزمون‌های در انتظار طراحی» و پیش‌نویس‌ها را به مسیر جدید متصل می‌کند.
- `admin-question-bank.html` — نمایش منشأ سؤال، نسخه مشتق‌شده و وضعیت بانک شخصی/مدرسه را اضافه می‌کند.
- `index.html` — در بخش آزمون دانش‌آموز، نمایش اصل فایل/پاسخ‌برگ و autosave/offline را پشتیبانی می‌کند.
- `supabase/migrations/*` — migrationهای جدید فقط افزایشی هستند و migrationهای قبلی بازنویسی نمی‌شوند.

### New UI files
- `exam-create.html` — صفحه مرکزی پنج روش + آزمون‌های در انتظار طراحی + پیش‌نویس‌ها.
- `exam-create-quick.html` — ساخت سریع.
- `exam-create-file.html` — فایل/برگه سؤال.
- `exam-create-professional.html` — ساخت حرفه‌ای section-based.
- `exam-create-ai.html` — ساخت با AI و بازبین دوم.
- `exam-create-copy.html` — کپی کامل/ساختار از آزمون قبلی.
- `exam-draft-core.js` — autosave، optimistic revision، offline queue، conflict detection.
- `exam-create-common.js` — احراز staff، بارگذاری metadata، validation مشترک، navigation و draft bootstrap.
- `exam-file-viewer.js` — نمایش responsive فایل، page mapping و fullscreen/zoom orchestration.
- `exam-upload-answers.js` — صف بارگذاری پاسخ دست‌نویس و وضعیت هر صفحه.

### New test/support files
- `tests/exam-creation-db.sql` — contract tests دیتابیس و RPCها.
- `tests/exam-creation-browser.md` — سناریوهای پذیرش مرورگر/موبایل برای اجرای دستی یا Playwright آینده.
- `tests/fixtures/marefat-question-template.xlsx` — fixture استاندارد XLSX پس از تولید template واقعی.

---

### Task 1: Foundation schema for drafts, creation modes, revisions and shared settings

**Files:**
- Create: `supabase/migrations/20260903180000_exam_creation_core.sql`
- Create: `tests/exam-creation-db.sql`

**Interfaces:**
- Produces: `v5_exam_creation_mode`, `v5_exam_timing_mode`, draft revision columns, shared result/answer-key settings, source exam relation, and RPCs `v5_get_exam_draft`, `v5_save_exam_draft`.
- Consumes: existing `v5_exams`, `v5_exam_questions`, staff helpers and RLS conventions.

- [ ] **Step 1: Write failing DB contract tests**

```sql
begin;

select 'creation_mode column exists' as test,
       exists (
         select 1 from information_schema.columns
         where table_schema='public' and table_name='v5_exams' and column_name='creation_mode'
       ) as passed;

select 'draft revision exists' as test,
       exists (
         select 1 from information_schema.columns
         where table_schema='public' and table_name='v5_exams' and column_name='draft_revision'
       ) as passed;

select 'save draft rpc exists' as test,
       to_regprocedure('public.v5_save_exam_draft(bigint,bigint,jsonb)') is not null as passed;

rollback;
```

- [ ] **Step 2: Run contract tests on staging and confirm failure**

Run through the existing Supabase SQL execution path against staging.
Expected: at least the new-column and new-RPC checks return `false`.

- [ ] **Step 3: Add non-destructive schema**

Migration must add, without dropping old columns:

```sql
create type public.v5_exam_creation_mode as enum
  ('file','quick','professional','ai','copy');

create type public.v5_exam_timing_mode as enum
  ('flexible','hard_end');

alter table public.v5_exams
  add column if not exists creation_mode public.v5_exam_creation_mode,
  add column if not exists draft_revision bigint not null default 0,
  add column if not exists timing_mode public.v5_exam_timing_mode not null default 'flexible',
  add column if not exists start_window_at timestamptz,
  add column if not exists hard_end_at timestamptz,
  add column if not exists show_result_mode text not null default 'after_full_grading',
  add column if not exists show_answer_key boolean not null default false,
  add column if not exists source_exam_id bigint references public.v5_exams(id),
  add column if not exists makeup_of_exam_id bigint references public.v5_exams(id);
```

`v5_save_exam_draft(p_exam_id bigint, p_expected_revision bigint, p_patch jsonb)` must reject stale revisions with a stable conflict code/message and increment `draft_revision` atomically.

- [ ] **Step 4: Re-run DB contract tests**

Expected: all Task 1 checks return `true`; stale revision test fails with the documented conflict response while current revision saves.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260903180000_exam_creation_core.sql tests/exam-creation-db.sql
git commit -m "feat: add shared exam creation draft model"
```

---

### Task 2: Central exam creation landing page and shared draft client

**Files:**
- Create: `exam-create.html`
- Create: `exam-create-common.js`
- Create: `exam-draft-core.js`
- Modify: `admin-panel.html`
- Modify: `admin-exam-builder.html`

**Interfaces:**
- Consumes: `v5_get_exam_draft`, `v5_save_exam_draft`.
- Produces: `ExamDraft.open(examId)`, `ExamDraft.patch(patch)`, `ExamDraft.flush()`, conflict event `exam-draft-conflict`.

- [ ] **Step 1: Add browser acceptance cases**

Append to `tests/exam-creation-browser.md`:

```text
LANDING-01: five creation cards are visible, equal width/visual weight.
LANDING-02: order is File, Quick, Professional, AI, Copy.
DRAFT-01: editing a title shows «در حال ذخیره» then «ذخیره شد».
DRAFT-02: simulated offline mode keeps patch locally and shows offline state.
DRAFT-03: stale revision from second tab produces conflict UI, never silent overwrite.
```

- [ ] **Step 2: Verify current UI fails these cases**

Open `admin-exam-builder.html`; expected: only one bank-based flow exists and no common draft state/conflict UI is present.

- [ ] **Step 3: Implement landing page**

`exam-create.html` must render three areas in this order:

```html
<section id="plannedExams"></section>
<section id="recentDrafts"></section>
<section class="creation-grid">
  <a data-mode="file">ساخت آزمون از فایل یا برگه سؤال</a>
  <a data-mode="quick">ساخت سریع آزمون</a>
  <a data-mode="professional">ساخت حرفه‌ای آزمون</a>
  <a data-mode="ai">ساخت آزمون با هوش مصنوعی</a>
  <a data-mode="copy">ساخت آزمون از آزمون قبلی</a>
</section>
```

All five cards use the same CSS class; no featured/primary card variant.

- [ ] **Step 4: Implement draft client**

`exam-draft-core.js` owns local key `marefat:exam-draft:<examId>`, expected revision, debounce save, online/offline listeners and conflict callback. It must never call publish RPCs.

- [ ] **Step 5: Wire navigation**

`admin-panel.html` links «ساخت آزمون جدید» to `exam-create.html`. `admin-exam-builder.html` keeps backward compatibility by linking/redirecting to quick or professional bank selection rather than disappearing abruptly.

- [ ] **Step 6: Run acceptance cases**

Expected: LANDING-01/02 and DRAFT-01/02/03 pass in desktop and 390px mobile width.

- [ ] **Step 7: Commit**

```bash
git add exam-create.html exam-create-common.js exam-draft-core.js admin-panel.html admin-exam-builder.html tests/exam-creation-browser.md
git commit -m "feat: add exam creation hub and resilient drafts"
```

---

### Task 3: Quick exam creation

**Files:**
- Create: `exam-create-quick.html`
- Create: `supabase/migrations/20260903181000_quick_exam_builder.sql`
- Modify: `tests/exam-creation-db.sql`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces: RPC `v5_staff_create_quick_exam(jsonb)` and `v5_staff_update_quick_exam(bigint,jsonb)`.
- Consumes: question bank RPC, shared draft/timing/result settings.

- [ ] **Step 1: Add failing tests**

Test mixed MCQ/descriptive creation, auto score distribution, manual score override, class assignment, selected-student assignment, shuffle flags, global negative-mark toggle, and score-total mismatch warning.

- [ ] **Step 2: Verify failure on staging**

Expected: quick-builder RPC absent and UI route unavailable.

- [ ] **Step 3: Implement minimal quick-builder RPCs**

Input JSON contract:

```json
{
  "title":"آزمون شیمی دهم",
  "exam_code":"CHEM-10-01",
  "duration_minutes":30,
  "total_score":20,
  "timing_mode":"flexible",
  "show_result_mode":"after_full_grading",
  "show_answer_key":false,
  "shuffle_questions":true,
  "shuffle_options":true,
  "negative_marking":false,
  "assignments":{"class_ids":[1],"student_ids":[],"exclude_student_ids":[]}
}
```

- [ ] **Step 4: Implement quick UI flow**

Order must be exactly:
`درس و کلاس → مشخصات آزمون → سؤال‌ها → نمره و زمان → تنظیم نتیجه → بررسی نهایی → انتشار`.
Question addition buttons are only `سؤال جدید` and `انتخاب از بانک سؤال`.

- [ ] **Step 5: Run quick acceptance suite**

Expected: mixed exam draft can be created and previewed; mismatched total shows warning but does not hard-block draft save.

- [ ] **Step 6: Commit**

```bash
git add exam-create-quick.html supabase/migrations/20260903181000_quick_exam_builder.sql tests/exam-creation-db.sql tests/exam-creation-browser.md
git commit -m "feat: add quick exam creation flow"
```

---

### Task 4: File/original-paper model, upload metadata and digital answer sheet

**Files:**
- Create: `supabase/migrations/20260903182000_exam_file_sources.sql`
- Create: `exam-create-file.html`
- Create: `exam-file-viewer.js`
- Modify: `tests/exam-creation-db.sql`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces tables for exam source files/pages and answer-sheet definition; RPCs `v5_staff_attach_exam_source`, `v5_staff_save_answer_sheet_definition`.
- Consumes shared draft exam id.

- [ ] **Step 1: Add failing DB/browser contracts**

Cover two top-level modes `convert_online` and `original_file`, supported format validation, page order, page-to-question mapping, and non-blocking quality warnings.

- [ ] **Step 2: Implement source metadata schema**

Store object/storage references and metadata, not raw file bytes in `v5_exams`. Required concepts:

```text
v5_exam_sources: exam_id, source_kind, file_name, mime_type, storage_path, page_count, is_answer_key
v5_exam_source_pages: source_id, page_number, sort_order, quality_state, quality_notes
v5_exam_answer_sheet_items: exam_id, question_number, response_type, max_score, source_page_number
```

- [ ] **Step 3: Implement file creation UI**

First decision appears before processing:

```text
[تبدیل به آزمون آنلاین]   [استفاده از اصل فایل/برگه سؤال]
```

Original-file path must enable `ادامه` as soon as the upload itself is valid; OCR/AI state cannot disable that button.

- [ ] **Step 4: Implement viewer behavior**

Desktop: source and response pane side-by-side. Mobile: vertical layout. Provide zoom, previous/next page, fullscreen, and `question_number -> source_page_number` navigation.

- [ ] **Step 5: Verify supported formats**

Acceptance includes PDF, DOCX, XLSX, JPG/JPEG, PNG; corrupt/password-protected/empty/unsupported files are hard errors, while blur/skew/crop warnings are bypassable.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260903182000_exam_file_sources.sql exam-create-file.html exam-file-viewer.js tests/exam-creation-db.sql tests/exam-creation-browser.md
git commit -m "feat: add original-file exams and digital answer sheets"
```

---

### Task 5: File conversion review, XLSX template import and bank destination

**Files:**
- Create: `supabase/migrations/20260903183000_exam_file_conversion.sql`
- Modify: `exam-create-file.html`
- Create: `marefat-question-template.xlsx` during implementation using the spreadsheet tool/script committed as binary fixture if repository policy permits
- Modify: `admin-question-bank.html`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces conversion-review records with states `confident`, `needs_review`, `incomplete` and RPC `v5_staff_confirm_extracted_questions`.
- Consumes question bank and Snapshot creation.

- [ ] **Step 1: Add acceptance cases**

Cases include split/merge extracted questions, edit answer/options/score, side-by-side crop, add missing question, separate answer-key file mismatch warning, descriptive suggested rubric, duplicate warning and destination selection.

- [ ] **Step 2: Implement review-state schema and confirmation transaction**

No extracted record may enter `v5_questions` until the confirm RPC is called by staff. Destination enum/field supports `exam_only`, `teacher_bank`, `school_bank`.

- [ ] **Step 3: Implement standard XLSX mapping**

Version-1 columns are fixed and documented:

```text
question_text | option_a | option_b | option_c | option_d | correct_answer | score | difficulty | chapter | topic
```

Missing optional columns warn; missing `question_text` is row-level hard error. Unstructured intelligent column mapping is explicitly not implemented here.

- [ ] **Step 4: Add school-bank moderation hook**

When moderation is enabled, `school_bank` saves as pending review instead of immediately active.

- [ ] **Step 5: Run acceptance suite and commit**

```bash
git add supabase/migrations/20260903183000_exam_file_conversion.sql exam-create-file.html admin-question-bank.html tests/exam-creation-browser.md
git commit -m "feat: add reviewed file conversion and xlsx import"
```

---

### Task 6: Handwritten upload, upload grace period and incomplete delivery recovery

**Files:**
- Create: `supabase/migrations/20260903184000_handwritten_exam_answers.sql`
- Create: `exam-upload-answers.js`
- Modify: `index.html`
- Modify: `tests/exam-creation-db.sql`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces per-page upload records, upload-only grace deadline and staff reopen-upload RPC.
- Consumes student attempt/session ownership logic.

- [ ] **Step 1: Add failing contracts**

Verify page-by-page statuses, no-file double confirmation, optional teacher-controlled upload grace period, upload-only restriction after answer time, and incomplete submission state.

- [ ] **Step 2: Add schema/RPCs**

Required RPC behavior:

```text
v5_student_register_answer_upload(attempt_id, page_no, storage_path, session_token)
v5_staff_reopen_answer_upload(attempt_id, new_deadline)
```

The reopen RPC changes only upload permission/deadline; it must not restore question editing or exam timer.

- [ ] **Step 3: Implement student upload queue**

Each page has `pending/uploading/uploaded/failed`; ordering, delete, replace and add-page are supported before final submission.

- [ ] **Step 4: Implement deadline behavior**

If main time ends and teacher configured grace, UI switches to upload-only mode. If all time ends with pending failed pages, preserve uploaded pages and mark attempt `submission_incomplete`/review-required rather than deleting the attempt.

- [ ] **Step 5: Run offline/reconnect scenarios and commit**

```bash
git add supabase/migrations/20260903184000_handwritten_exam_answers.sql exam-upload-answers.js index.html tests/exam-creation-db.sql tests/exam-creation-browser.md
git commit -m "feat: add handwritten answer upload workflow"
```

---

### Task 7: In-person exam entry and printable answer sheet

**Files:**
- Create: `supabase/migrations/20260903185000_in_person_exam_results.sql`
- Create: `admin-in-person-results.html`
- Modify: `exam-create-file.html`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces final-score entry and optional question-level result entry; printable answer-sheet definition uses existing digital answer-sheet items.

- [ ] **Step 1: Add failing acceptance cases**

Cover table-like score entry, absence status, comments, XLSX bulk grade import, question-by-question analytical mode, and printable answer-sheet generation.

- [ ] **Step 2: Implement result RPCs**

`v5_staff_upsert_in_person_result` validates score range and enrollment; `v5_staff_upsert_in_person_item_result` stores per-question correctness/partial score when analytical mode is used.

- [ ] **Step 3: Implement grade table UI**

Columns: student, attendance/status, score, note. Add import preview that reports invalid rows before commit.

- [ ] **Step 4: Implement print view**

Generate a deterministic printable answer sheet from answer-sheet definition. Do not add scan/OMR recognition.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260903185000_in_person_exam_results.sql admin-in-person-results.html exam-create-file.html tests/exam-creation-browser.md
git commit -m "feat: add in-person results and printable answer sheet"
```

---

### Task 8: Professional section-based builder, budgeting and anti-repeat

**Files:**
- Create: `supabase/migrations/20260903190000_professional_exam_builder.sql`
- Create: `exam-create-professional.html`
- Modify: `tests/exam-creation-db.sql`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces section/blueprint schema and RPCs `v5_staff_preview_section_pool`, `v5_staff_generate_exam_sections`.
- Consumes question bank metadata and source/usage history.

- [ ] **Step 1: Add failing tests**

Cover multiple sections, one primary budget mode per exam (`count`, `percentage`, `score`), available-vs-requested counts, explicit shortage choices, filters and anti-repeat rules.

- [ ] **Step 2: Add section schema**

Each section stores title, order, selection mode, filters JSON, budget mode/value, difficulty distribution and question-type rules.

- [ ] **Step 3: Implement pool preview**

Return `{requested, available, shortage}` without silently relaxing filters.

- [ ] **Step 4: Implement shortage actions**

UI offers exactly: `تغییر شرایط`, `استفاده از تعداد موجود`, `تکمیل کمبود با سؤال جدید`.

- [ ] **Step 5: Implement anti-repeat**

Support previous exam, last N exams, and current academic year exclusions. Do not hide shortage caused by exclusions.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260903190000_professional_exam_builder.sql exam-create-professional.html tests/exam-creation-db.sql tests/exam-creation-browser.md
git commit -m "feat: add professional section-based exam builder"
```

---

### Task 9: Versions, templates, preview and quality report

**Files:**
- Create: `supabase/migrations/20260903191000_exam_versions_templates_quality.sql`
- Modify: `exam-create-professional.html`
- Create: `exam-preview.html`
- Modify: `admin-exam-publish.html`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces same-question and equated version definitions, teacher/school templates, preview generation and quality-report RPC.

- [ ] **Step 1: Add failing acceptance cases**

Verify A/B/C/D same-question versions, equated-version insufficiency warning, teacher/school templates storing structure not attempts/results, preview with regenerate option, and quality report categories.

- [ ] **Step 2: Implement version generation**

Same-question versions may reorder questions/options. Equated versions use the same blueprint and must refuse generation when pool sufficiency cannot be met without relaxing teacher constraints.

- [ ] **Step 3: Implement templates**

Template copies settings/sections/rules only; no student attempts/results. School template write is restricted to authorized staff.

- [ ] **Step 4: Implement student-view preview**

Preview creates no real attempt/statistics. Random/equated exams include `تولید پیش‌نمایش دیگر`.

- [ ] **Step 5: Implement quality report**

Report coverage, difficulty, type distribution, score consistency, estimated response time, recent duplicates and uncovered planned topics. Classify findings as `hard_error` or `warning`.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260903191000_exam_versions_templates_quality.sql exam-create-professional.html exam-preview.html admin-exam-publish.html tests/exam-creation-browser.md
git commit -m "feat: add exam versions templates preview and quality checks"
```

---

### Task 10: Copy previous exam with immutable history

**Files:**
- Create: `supabase/migrations/20260903192000_copy_previous_exam.sql`
- Create: `exam-create-copy.html`
- Modify: `tests/exam-creation-db.sql`

**Interfaces:**
- Produces `v5_staff_copy_exam(p_source_exam_id bigint, p_copy_mode text)` returning new draft id.

- [ ] **Step 1: Add failing DB tests**

Full copy includes questions/settings but not attempts/answers/results. Structure copy includes sections/settings but no old questions. New dates are unset. `source_exam_id` is recorded.

- [ ] **Step 2: Implement immutable-copy RPC**

Historical source Snapshot rows are never updated. Editing copied question offers exam-only edit or save-as-new-bank-question.

- [ ] **Step 3: Add validation warnings**

Warn on old academic year, inactive class, inactive bank source and missing new date/time.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260903192000_copy_previous_exam.sql exam-create-copy.html tests/exam-creation-db.sql
git commit -m "feat: add safe exam copy modes"
```

---

### Task 11: AI creation and second-review boundary

**Files:**
- Create: `supabase/migrations/20260903193000_ai_exam_proposals.sql`
- Create: `exam-create-ai.html`
- Modify: `exam-create-professional.html`
- Modify: `admin-question-bank.html`
- Modify: `tests/exam-creation-db.sql`
- Modify: `tests/exam-creation-browser.md`

**Interfaces:**
- Produces proposal/audit storage and confirmation RPCs. External model invocation is isolated behind a server-side/edge boundary available at implementation time; browser never receives private AI credentials.

- [ ] **Step 1: Add boundary tests**

Verify AI output starts as proposal, cannot directly publish, cannot directly activate school-bank item, derivative relation can point to source question, and teacher confirmation is required.

- [ ] **Step 2: Add proposal schema**

Store prompt/source references, proposal JSON, status, reviewer, confirmation time and optional `derived_from_question_id`.

- [ ] **Step 3: Implement UI modes**

Support source-grounded question generation, edit-assistant actions, whole-exam blueprint proposal and second-review findings.

- [ ] **Step 4: Enforce source insufficiency behavior**

If selected source is insufficient, UI must show insufficiency rather than silently presenting invented material as source-grounded.

- [ ] **Step 5: Implement second reviewer as warnings**

Ambiguity, weak distractors, suspicious key, duplicates, score/difficulty mismatch and timing concerns are suggestions/warnings. Only structural hard errors block publication.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260903193000_ai_exam_proposals.sql exam-create-ai.html exam-create-professional.html admin-question-bank.html tests/exam-creation-db.sql tests/exam-creation-browser.md
git commit -m "feat: add teacher-controlled ai exam proposals"
```

---

### Task 12: Planned exams, final publish checklist and end-to-end staging verification

**Files:**
- Create: `supabase/migrations/20260903194000_planned_exam_design_queue.sql`
- Modify: `exam-create.html`
- Modify: `admin-exam-publish.html`
- Modify: `tests/exam-creation-db.sql`
- Modify: `tests/exam-creation-browser.md`
- Create: `docs/operations/exam-creation-v5-staging-checklist.md`

**Interfaces:**
- Produces planned-exam queue read/start-design RPCs and final publication checklist.
- Consumes all prior tasks.

- [ ] **Step 1: Add planned-exam queue tests**

Starting design from a planned exam creates/opens a professional draft with known grade/subject/content/date fields prefilled; planned exams are not a sixth creation mode.

- [ ] **Step 2: Add final publish gate**

Publication must block on structural failures such as no questions, no target assignment, invalid timing and corrupt required source; warnings remain overridable.

- [ ] **Step 3: Run full DB contract suite on staging**

Expected: all `tests/exam-creation-db.sql` checks pass and existing descriptive/attempt/publish RPC contracts remain functional.

- [ ] **Step 4: Run browser matrix**

Minimum matrix:

```text
Desktop Chrome: all five creation modes
390px mobile: landing, file viewer, handwritten upload, student original-file exam
Offline/reconnect: draft save and student response save
Two tabs: stale-revision conflict
Hard-end timer: auto-submit preserves saved answers
Descriptive mixed exam: pending manual grading behavior remains intact
Copy previous: no historical mutation
```

- [ ] **Step 5: Write staging evidence**

`docs/operations/exam-creation-v5-staging-checklist.md` records migration list, test date, tester, pass/fail evidence, known warnings and rollback notes.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260903194000_planned_exam_design_queue.sql exam-create.html admin-exam-publish.html tests/exam-creation-db.sql tests/exam-creation-browser.md docs/operations/exam-creation-v5-staging-checklist.md
git commit -m "test: complete exam creation v5 staging acceptance"
```

---

## Integration and release gate

After Task 12, do not apply production migrations automatically. First run code review and verification. The release sequence is:

```text
feature implementation branch
→ tests green
→ code review
→ PR
→ staging migration + browser acceptance
→ explicit user approval
→ production migration
→ frontend deploy
→ production smoke test
```

Rollback must prefer forward-fix migrations; destructive rollback of newly populated production data is not a default strategy.

## Self-review result

- Spec coverage: all five creation modes, file/original-paper path, handwritten/in-person flows, professional sections, AI, copy, Snapshot, autosave/offline/conflict, timing, result policy, planned exams, quality report and release safety map to explicit tasks.
- Scope: large but sequential; each task ends in an independently reviewable working slice. AI provider-specific integration is intentionally isolated because provider choice is not part of the approved product design.
- Placeholder scan: no implementation task depends on an unspecified behavior; deferred features are explicitly outside version-1 scope.
- Type/interface consistency: draft revision, source exam relation, answer-sheet definition and proposal boundaries are introduced before dependent tasks use them.
