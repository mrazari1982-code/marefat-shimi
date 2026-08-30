# Unified Portals and Student Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public role-selection landing page, a secure private student dashboard with history/resume/results, and one canonical administrator/deputy portal without breaking existing exam links or deleting data.

**Architecture:** Keep the existing static HTML/JavaScript frontend and opaque student-session model. Add narrowly scoped `SECURITY DEFINER` RPCs that resolve the student from the session token, then expose them through `student-auth.js`; build the dashboard and compatibility routes on top. Consolidate staff navigation only after all existing capabilities are linked and tested.

**Tech Stack:** Static RTL HTML/CSS/JavaScript, Supabase JavaScript v2, PostgreSQL/Supabase migrations, Node.js built-in test runner and VM harnesses, SQL transaction tests, Python `unittest`, Cloudflare Workers static assets.

**Spec:** `docs/superpowers/specs/2026-08-29-unified-portals-and-student-dashboard-design.md`

## Global Constraints

- Do not delete, rewrite, or migrate existing students, exams, attempts, answers, or results.
- Dedicated teacher and parent portals, SMS login, scheduled/manual result release, and grade/field/class eligibility remain out of scope.
- Student identity must come only from `v5_auth_private.student_for_token(p_session_token)`; a browser-supplied student code is never an authorization input.
- Hidden results must return `null` score fields and must not influence any summary aggregate.
- Detailed answers and correct-answer information are available only when the summary is visible and the exam status is `closed`.
- Privileged functions must use a fixed `search_path`, avoid dynamic SQL, revoke execution from `public`, and grant only the documented roles.
- No direct table grants may be added for attempts, answers, credentials, or private sessions.
- Student history is newest first and limited to at most 100 rows.
- Student UI is Persian, RTL, keyboard accessible, and usable at 320px width.
- Existing token links and deployed HTML routes remain compatible; no HTML file is deleted.
- Apply database changes to staging first. Production migration/deployment requires explicit user approval after all acceptance checks pass.

## File Structure

- `supabase/migrations/20260830085333_student_dashboard_and_resume.sql`: dashboard, resume, and policy-safe result RPCs plus exact ACLs.
- `tests/student-dashboard-db.sql`: transactional authorization, visibility, aggregation, expiry, inactive-account, limit, and resume tests.
- `public/student-auth.js`: protected-route list, safe-return allowlist, and session-token RPC mappings.
- `tests/student-auth-browser.cjs`: unit coverage for new mappings and redirects.
- `public/student-dashboard.html`: semantic RTL dashboard shell.
- `public/student-dashboard.js`: dashboard loading, rendering, retry, exam-token start, resume, result, trend, and logout behavior.
- `tests/student-dashboard-browser.cjs`: DOM/VM behavior tests for dashboard states and safe output.
- `public/exam.html`: support owned resume through `?attempt=<uuid>` and return-to-dashboard actions.
- `public/student-result.html`: automatic attempt loading, visibility states, post-close details, and dashboard return.
- `tests/student-journey-browser.cjs`: resume/result route and policy rendering regression tests.
- `public/index.html`: public role-selection landing and old token-link compatibility.
- `public/student-login.html`: default post-login dashboard route and token-preserving return.
- `tests/landing-routes.cjs`: landing and login route tests.
- `public/admin-nav.js`: presentation-only canonical panel/back/logout navigation helper.
- `public/admin-panel.html`: complete canonical administration menu.
- `public/admin.html`: session-preserving compatibility redirect.
- `public/admin-*.html`, `public/students.html`, `public/results.html`, `public/analytics.html`, `public/exam-builder.html`, `public/exam-questions*.html`: consistent canonical navigation hook where each page is active.
- `tests/admin-navigation.cjs`: canonical link coverage and compatibility redirect tests.
- `tests/deployment-safety.py`: required-route and deploy-asset allowlist updates.
- `test-checklist.md`: staging and production acceptance sequence.

---

### Task 1: Secure Student Dashboard Data Contract

**Files:**
- Create: `supabase/migrations/20260830085333_student_dashboard_and_resume.sql`
- Create: `tests/student-dashboard-db.sql`

**Interfaces:**
- Consumes: `v5_auth_private.student_for_token(text) returns public.v5_students`; tables `v5_students`, `v5_grades`, `v5_fields`, `v5_classes`, `v5_attempts`, and `v5_exams`.
- Produces: `public.v5_student_dashboard(p_session_token text, p_limit integer default 100) returns jsonb` executable by `anon, authenticated`.

- [ ] **Step 1: Write the failing dashboard SQL contract test**

Create a transaction test that logs in as both staging students, derives their attempt IDs, and asserts the response shape and isolation. Include explicit assertions equivalent to:

```sql
begin;
set local role anon;
do $$
declare
  login_a jsonb := public.v5_student_login('STAGING-STUDENT-001','ownership-test-password-a');
  token_a text;
  dashboard jsonb;
begin
  token_a := login_a->>'token';
  dashboard := public.v5_student_dashboard(token_a,100);
  if dashboard->'profile'->>'student_code' <> 'STAGING-STUDENT-001' then
    raise exception 'DASHBOARD_PROFILE_LEAK';
  end if;
  if exists (
    select 1 from jsonb_array_elements(dashboard->'attempts') x
    where (x->>'attempt_id')::uuid in (
      select a.id from public.v5_attempts a
      join public.v5_students s on s.id=a.student_id
      where s.student_code='STAGING-STUDENT-002'
    )
  ) then raise exception 'DASHBOARD_ATTEMPT_LEAK'; end if;
  if jsonb_array_length(public.v5_student_dashboard(token_a,0)->'attempts') <> 0 then
    raise exception 'LIMIT_ZERO_NOT_HONORED';
  end if;
end $$;
reset role;
rollback;
```

In the same test transaction, temporarily toggle an owned exam's `show_result_to_student` to false and assert every score/count field is JSON null and the hidden attempt does not change `average_percentage`, `correct_count`, `wrong_count`, or `blank_count`. Add cases for an expired session, an inactive student, newest-first ordering, negative limit rejection, and `p_limit > 100` clamping.

- [ ] **Step 2: Run the test and verify the function is missing**

Run against staging using the already configured Supabase test connection:

```bash
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-dashboard-db.sql
```

Expected: failure with `function public.v5_student_dashboard(text, integer) does not exist`.

- [ ] **Step 3: Implement the minimal dashboard RPC**

In the migration, validate the limit and resolve the session before reading rows:

```sql
create or replace function public.v5_student_dashboard(
  p_session_token text,
  p_limit integer default 100
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_limit integer;
  v_profile jsonb;
  v_summary jsonb;
  v_attempts jsonb;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  if p_limit is null or p_limit < 0 then raise exception 'INVALID_LIMIT'; end if;
  v_limit := least(p_limit,100);
  return jsonb_build_object('profile',v_profile,'summary',v_summary,'attempts',v_attempts);
end $$;

revoke all on function public.v5_student_dashboard(text,integer) from public;
grant execute on function public.v5_student_dashboard(text,integer) to anon,authenticated;
```

Before the return, populate `v_profile` with `v_student` plus `LEFT JOIN` lookups to `v5_grades`, `v5_fields`, and `v5_classes`. Populate both `v_summary` and `v_attempts` from an ownership-scoped source whose first predicate is `a.student_id = v_student.id`. Use these exact policy expressions:

```sql
(a.status = 'submitted' and e.show_result_to_student is true) as result_visible,
case when a.status = 'submitted' and e.show_result_to_student is true
     then a.percentage else null end as visible_percentage,
case when a.status = 'submitted' and e.show_result_to_student is true
     then a.correct_count else null end as visible_correct_count
```

Repeat the guarded `CASE` for wrong and blank counts. Use `avg(visible_percentage) filter (where result_visible)` and filtered sums, so hidden rows cannot affect aggregates. Set `can_resume=true` only for `started` attempts whose exam is still `published` and whose authoritative deadline has not elapsed. Compute the deadline as the earlier non-null value of `v5_exams.end_at` and `v5_attempts.started_at + duration_minutes * interval '1 minute'`. Return stable `resume_reason` values: `submitted`, `expired`, `exam_closed`, `deadline_passed`, or `null`.

- [ ] **Step 4: Verify dashboard tests and function ACLs**

Run:

```bash
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260830085333_student_dashboard_and_resume.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-dashboard-db.sql
```

Expected: `PASS: student dashboard contract, masking, ownership and limits` and no direct table privileges added.

- [ ] **Step 5: Commit the dashboard contract**

```bash
git add supabase/migrations/20260830085333_student_dashboard_and_resume.sql tests/student-dashboard-db.sql
git commit -m "feat: add secure student dashboard RPC"
```

### Task 2: Resume and Result-Visibility Security Contracts

**Files:**
- Modify: `supabase/migrations/20260830085333_student_dashboard_and_resume.sql`
- Modify: `tests/student-dashboard-db.sql`

**Interfaces:**
- Consumes: the session and deadline rules from Task 1.
- Produces: `public.v5_student_resume_attempt(p_attempt_id uuid,p_session_token text) returns jsonb`; a policy-safe replacement for `public.v5_student_get_result(uuid,text) returns jsonb`.

- [ ] **Step 1: Add failing resume and result-policy tests**

Add assertions that an owned active attempt returns only `attempt_id`, `exam_id`, `title`, `student_name`, `status`, `duration_minutes`, `started_at`, `deadline_at`, and `server_now`. Assert another student's attempt is denied, and submitted/expired/closed/deadline-passed attempts raise stable codes. For results, toggle exam state and visibility and assert:

```sql
if (hidden_result ? 'percentage') is not null
   or (hidden_result ? 'details') is not null then
  raise exception 'HIDDEN_RESULT_DISCLOSED';
end if;
if jsonb_array_length((published_result->'details')) <> 0 then
  raise exception 'PRE_CLOSE_DETAILS_DISCLOSED';
end if;
if jsonb_array_length((closed_result->'details')) = 0 then
  raise exception 'POST_CLOSE_DETAILS_MISSING';
end if;
```

- [ ] **Step 2: Run the targeted SQL test and confirm failure**

Run:

```bash
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-dashboard-db.sql
```

Expected: failure because `v5_student_resume_attempt` is missing or the current result wrapper exposes details too early.

- [ ] **Step 3: Implement resume with authoritative ownership and time checks**

Add the exact signature below. Its first statement after declarations must call `student_for_token`; its attempt query must include `a.id=p_attempt_id and a.student_id=v_student.id for update`. Compute `v_deadline` with the same earlier-non-null rule as Task 1. Apply checks in this order: missing owned row → `ATTEMPT_NOT_FOUND`; submitted → `ATTEMPT_SUBMITTED`; already expired → `ATTEMPT_EXPIRED`; exam not `published` → `EXAM_CLOSED`. For an elapsed deadline, persist `status='expired'` and return `{"available":false,"reason":"deadline_passed"}` instead of raising after the update, because a raised exception would roll the status update back. A successful response is restricted to `available`, `attempt_id`, `exam_id`, `title`, `student_name`, `status`, `duration_minutes`, `started_at`, `deadline_at`, and `server_now`:

```sql
create or replace function public.v5_student_resume_attempt(
  p_attempt_id uuid,
  p_session_token text
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype;
  v_deadline timestamptz;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt from public.v5_attempts a
   where a.id=p_attempt_id and a.student_id=v_student.id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  if v_attempt.status = 'submitted' then raise exception 'ATTEMPT_SUBMITTED'; end if;
  if v_attempt.status = 'expired' then raise exception 'ATTEMPT_EXPIRED'; end if;
  if v_exam.status <> 'published' then raise exception 'EXAM_CLOSED'; end if;
  v_deadline := case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at + v_exam.duration_minutes * interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at + v_exam.duration_minutes * interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp() >= v_deadline then
    update public.v5_attempts set status='expired' where id=v_attempt.id;
    return jsonb_build_object('available',false,'reason','deadline_passed');
  end if;
  return jsonb_build_object(
    'available',true,'attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,
    'student_name',v_student.full_name,'status',v_attempt.status,
    'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at,
    'deadline_at',v_deadline,'server_now',clock_timestamp()
  );
end
$$;
```

- [ ] **Step 4: Replace the student result wrapper with policy-safe output**

Keep the existing signature so browser mapping remains compatible. Resolve the student from the token, select only the owned finalized attempt, and construct the JSON directly. Return title/date/status for hidden results with score fields and `details` set to JSON null. When visible but the exam is not `closed`, return visible summary values and `details: []`. Only for `closed` exams build details; correct-answer text/key must come from server-side option joins and must never be returned earlier.

End the migration with:

```sql
revoke all on function public.v5_student_resume_attempt(uuid,text) from public;
grant execute on function public.v5_student_resume_attempt(uuid,text) to anon,authenticated;
revoke all on function public.v5_student_get_result(uuid,text) from public;
grant execute on function public.v5_student_get_result(uuid,text) to anon,authenticated;
```

- [ ] **Step 5: Run SQL security tests and commit**

Run:

```bash
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260830085333_student_dashboard_and_resume.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-dashboard-db.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-auth-ownership.sql
```

Expected: all three scripts print PASS and cross-student IDs remain denied.

```bash
git add supabase/migrations/20260830085333_student_dashboard_and_resume.sql tests/student-dashboard-db.sql
git commit -m "feat: secure attempt resume and result release"
```

### Task 3: Student Session Adapter and Safe Routes

**Files:**
- Modify: `public/student-auth.js`
- Modify: `tests/student-auth-browser.cjs`

**Interfaces:**
- Consumes: `v5_student_dashboard`, `v5_student_resume_attempt`, and `v5_student_get_result` from Tasks 1–2.
- Produces: mapped browser calls `v5_dashboard`, `v5_resume_attempt`; safe returns to `student-dashboard.html`, `exam.html`, and `student-result.html`.

- [ ] **Step 1: Add failing adapter tests**

Extend the harness location with query-string support and assert:

```js
await h.client.rpc('v5_dashboard',{p_limit:25});
assert.deepEqual(h.calls.at(-1),['v5_student_dashboard',{
  p_limit:25,p_session_token:'a'.repeat(64)
}]);
await h.client.rpc('v5_resume_attempt',{p_attempt_id:'attempt-a'});
assert.deepEqual(h.calls.at(-1),['v5_student_resume_attempt',{
  p_attempt_id:'attempt-a',p_session_token:'a'.repeat(64)
}]);
assert.equal(h.api.safeReturn('student-dashboard.html'),'student-dashboard.html');
assert.equal(h.api.safeReturn('student-dashboard.html?token=abc'),'student-dashboard.html?token=abc');
assert.equal(h.api.safeReturn('admin-panel.html'),'student-dashboard.html');
```

Also assert that `student-dashboard.html` redirects to login when no session exists, while `index.html` no longer does.

- [ ] **Step 2: Run the test and verify failure**

```bash
node tests/student-auth-browser.cjs
```

Expected: failure on the missing RPC mapping and old protected-page/default-return rules.

- [ ] **Step 3: Implement mappings and route policy**

Change `protectedPages` to `student-dashboard.html`, `exam.html`, and `student-result.html`. Add:

```js
v5_dashboard: ['v5_student_dashboard',(args,token)=>({
  p_limit:Math.min(100,Math.max(0,Number(args.p_limit??100))),
  p_session_token:token
})],
v5_resume_attempt: ['v5_student_resume_attempt',(args,token)=>({
  p_attempt_id:args.p_attempt_id,p_session_token:token
})]
```

Make `safeReturn` accept only the three student routes and default to `student-dashboard.html`. Preserve query strings but reject fragments, absolute URLs, protocol-relative URLs, encoded path separators, and unknown pages.

- [ ] **Step 4: Run adapter and syntax tests**

```bash
node tests/student-auth-browser.cjs
node tests/html-script-syntax.cjs
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add public/student-auth.js tests/student-auth-browser.cjs
git commit -m "feat: route student sessions through dashboard APIs"
```

### Task 4: Student Dashboard UI

**Files:**
- Create: `public/student-dashboard.html`
- Create: `public/student-dashboard.js`
- Create: `tests/student-dashboard-browser.cjs`
- Modify: `tests/deployment-safety.py`

**Interfaces:**
- Consumes: `MarefatStudentAuth`, `sb.rpc('v5_dashboard',{p_limit:100})`, and `sb.rpc('v5_start_exam',{p_token})`.
- Produces: dashboard DOM IDs `profile`, `summary`, `history`, `trend`, `dashboard-message`, `exam-token`, `start-exam`, `retry`, and `logout`; navigation to `exam.html?attempt=<uuid>` and `student-result.html?attempt=<uuid>`.

- [ ] **Step 1: Write failing dashboard rendering tests**

Create a VM/DOM harness with representative payloads and assert:

```js
test('hidden attempt never renders score text',async()=>{
  const h=harness({attempts:[{
    attempt_id:'a',exam_title:'آزمون پنهان',status:'submitted',
    result_visible:false,percentage:null,correct_count:null,
    wrong_count:null,blank_count:null,can_resume:false
  }]});
  await h.init();
  assert.match(h.text('history'),/در انتظار انتشار/);
  assert.doesNotMatch(h.text('history'),/%|صحیح|غلط/);
});
test('resume and result actions use attempt id only',async()=>{
  const h=harness(ownedPayload);
  await h.init();
  h.click('[data-resume="attempt-a"]');
  assert.equal(h.location,'exam.html?attempt=attempt-a');
});
```

Add cases for empty history, retry after network error, fewer than two visible results hiding the trend, chronological trend order, logout, and text escaping through DOM `textContent`/element creation rather than HTML interpolation.

- [ ] **Step 2: Run the dashboard test and verify missing files fail**

```bash
node --test tests/student-dashboard-browser.cjs
```

Expected: failure because `public/student-dashboard.js` does not exist.

- [ ] **Step 3: Build the semantic dashboard shell**

Create `student-dashboard.html` with `dir="rtl"`, a skip-friendly `<main>`, headings, live status region, token form, profile/summary/history sections, retry button, and logout button. Use responsive grid rules that collapse at `max-width:480px`, keep controls at least 44px high, and avoid horizontal scrolling at 320px. Load scripts in this order: Supabase v2, `student-auth.js`, then `student-dashboard.js`.

- [ ] **Step 4: Implement rendering and actions without unsafe HTML**

In `student-dashboard.js`, implement and export for tests:

```js
function renderDashboard(payload) {}
function renderProfile(profile) {}
function renderSummary(summary) {}
function renderAttempts(attempts) {}
function renderTrend(attempts) {}
function friendlyError(message) {}
async function loadDashboard() {}
async function startExam(token) {}
```

Build student-derived content with `createElement` and `textContent`. On start success, navigate to `exam.html?attempt=` plus the returned `attempt_id`; never append a student code. On resume, navigate with the owned attempt ID. On denied resume, localize the reason, refresh the dashboard, and keep the token form usable. On `UNAUTHORIZED`, clear the local session through the existing auth flow and redirect to login.

- [ ] **Step 5: Add the route to deployment safety and run tests**

Add `student-dashboard.html` to `test_required_routes_exist` and `student-dashboard.js` to the root public-file allowlist.

```bash
node --test tests/student-dashboard-browser.cjs
node tests/html-script-syntax.cjs
python3 tests/deployment-safety.py
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add public/student-dashboard.html public/student-dashboard.js tests/student-dashboard-browser.cjs tests/deployment-safety.py
git commit -m "feat: add private student dashboard"
```

### Task 5: Resume-Aware Exam Runner and Policy-Aware Result Page

**Files:**
- Modify: `public/exam.html`
- Modify: `public/student-result.html`
- Create: `tests/student-journey-browser.cjs`
- Modify: `tests/exam-lifecycle.cjs`

**Interfaces:**
- Consumes: `sb.rpc('v5_resume_attempt',{p_attempt_id})`, existing mapped question/state/save/submit RPCs, and policy-safe `v5_get_student_result`.
- Produces: exam initialization from either a new token or an owned attempt ID; result rendering with `result_visible` and `detail_visible` states.

- [ ] **Step 1: Add failing journey tests**

Test these exact branches:

```js
test('attempt query resumes without public token',async()=>{
  const h=harness('/exam.html?attempt=owned-id');
  await h.init();
  assert.equal(h.calls[0][0],'v5_resume_attempt');
  assert.deepEqual(h.calls[0][1],{p_attempt_id:'owned-id'});
  assert.equal(h.calls.some(([,args])=>'p_student_code' in (args||{})),false);
});
test('visible result before close hides details',async()=>{
  const h=harnessResult({result_visible:true,detail_visible:false,percentage:62.5,details:[]});
  await h.load();
  assert.match(h.summaryText(),/62.50/);
  assert.equal(h.detailHidden(),true);
});
```

Add hidden-result, closed-detail, automatic loading from query string, missing/invalid attempt, and back-to-dashboard cases.

- [ ] **Step 2: Run and verify the current flow fails**

```bash
node --test tests/student-journey-browser.cjs
```

Expected: failure because `exam.html` still requires token/student code and the result page exposes its manual attempt form/details unconditionally.

- [ ] **Step 3: Refactor exam initialization into two explicit paths**

Parse `attempt` and `token`. If `attempt` exists, call `v5_resume_attempt` and then load questions/state. If only `token` exists, call `v5_start_exam`; its session adapter supplies identity. Remove the hidden student-code input/parameter dependency. Preserve timer, autosave, final submission, and existing public token compatibility. After submission, show a `مشاهده کارنامه` action when visible and always show `بازگشت به پنل دانش‌آموز`.

- [ ] **Step 4: Make result rendering follow server visibility flags**

Automatically load the `attempt` query parameter. Remove the visible manual attempt-ID workflow. Always show title/date/status returned for the owner. Render summary only when `result_visible===true`; otherwise display `در انتظار انتشار`. Render the details section only when `detail_visible===true` and `details` is a non-empty array. Add a canonical dashboard return link.

- [ ] **Step 5: Run lifecycle, journey, and syntax regressions**

```bash
node --test tests/student-journey-browser.cjs
node --test tests/exam-lifecycle.cjs
node tests/student-auth-browser.cjs
node tests/html-script-syntax.cjs
```

Expected: all PASS, including expiry auto-submit and hidden-result regression.

- [ ] **Step 6: Commit**

```bash
git add public/exam.html public/student-result.html tests/student-journey-browser.cjs tests/exam-lifecycle.cjs
git commit -m "feat: resume exams and enforce result visibility"
```

### Task 6: Public Landing and Token-Preserving Login

**Files:**
- Modify: `public/index.html`
- Modify: `public/student-login.html`
- Create: `tests/landing-routes.cjs`

**Interfaces:**
- Consumes: `MarefatStudentAuth.getSession()` and `safeReturn()`.
- Produces: public student/staff role choices; safe compatibility from `index.html?token=...` to authenticated dashboard/exam flow.

- [ ] **Step 1: Write failing landing-route tests**

Parse the pages and assert two visible primary links, no automatic student-session requirement on the root, and these behaviors:

```js
assert.equal(landingDestination({studentSession:true}),'student-dashboard.html');
assert.equal(landingDestination({staffSession:true}),'admin-panel.html');
assert.equal(studentTokenDestination('valid token',false),
  'student-login.html?return='+encodeURIComponent('student-dashboard.html?token=valid%20token'));
assert.equal(studentTokenDestination('valid token',true),
  'student-dashboard.html?token=valid%20token');
```

Assert arbitrary return URLs remain rejected by `safeReturn`.

- [ ] **Step 2: Run the test and verify the current token page fails it**

```bash
node --test tests/landing-routes.cjs
```

Expected: failure because root is still the protected exam-token page and login defaults to `index.html`.

- [ ] **Step 3: Build the role-selection landing**

Replace root content with a Persian public home page containing `ورود دانش‌آموز` and `ورود مدیر / معاون`. A valid student session changes the student destination to the dashboard; an active Supabase staff session changes the staff destination to the canonical panel. Do not expose role/profile data before the user chooses staff entry.

If `?token=` exists, validate it as a non-empty bounded string, encode it once, and route it through `student-dashboard.html?token=...`, directly for a valid student session or via the safe login return otherwise.

- [ ] **Step 4: Change successful login default and preserve safe token return**

In `student-login.html`, redirect an already logged-in student and a successful login with no return parameter to `student-dashboard.html`. Continue using `MarefatStudentAuth.safeReturn` for any supplied return value.

- [ ] **Step 5: Run route and regression tests**

```bash
node --test tests/landing-routes.cjs
node tests/student-auth-browser.cjs
node tests/html-script-syntax.cjs
python3 tests/deployment-safety.py
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add public/index.html public/student-login.html tests/landing-routes.cjs
git commit -m "feat: add public role-selection landing"
```

### Task 7: Canonical Administration Navigation and Compatibility Redirect

**Files:**
- Create: `public/admin-nav.js`
- Modify: `public/admin-panel.html`
- Modify: `public/admin.html`
- Modify: active staff feature pages listed in File Structure
- Create: `tests/admin-navigation.cjs`
- Modify: `tests/deployment-safety.py`

**Interfaces:**
- Consumes: existing Supabase staff session checks on every page.
- Produces: presentation-only `MarefatAdminNav.mount({client,backTarget:'admin-panel.html'})`; canonical links to every current staff capability; session-preserving redirect from `admin.html`.

- [ ] **Step 1: Write the failing canonical navigation test**

Define the required canonical destinations and assert each occurs in `admin-panel.html`:

```js
const required=[
  'students.html','admin-student-import.html','admin-student-password.html',
  'admin-question-bank.html','admin-exam-builder.html','exam-questions-v3.html',
  'admin-exam-publish.html','admin-exam-lifecycle.html','admin-exam-links.html',
  'results.html','admin-report.html','admin-analytics.html'
];
for(const route of required) assert.match(panel,new RegExp(`href=["']${route}["']`));
assert.match(adminCompat,/location\.replace\(['"]admin-panel\.html['"]\)/);
```

Also assert every active staff feature page either loads `admin-nav.js` or contains a direct `admin-panel.html` link, and none uses `admin.html` as its back/login route.

- [ ] **Step 2: Run the test and confirm missing links/old routes**

```bash
node --test tests/admin-navigation.cjs
```

Expected: failure listing currently unreachable features and pages that point back to `admin.html`.

- [ ] **Step 3: Complete the canonical panel menu**

Group links under دانش‌آموزان, بانک سؤال, آزمون‌ها, and گزارش‌ها. Preserve the existing summary and result tables. Keep the existing active admin/deputy authorization check before showing data.

- [ ] **Step 4: Add shared navigation without centralizing authorization**

Implement `admin-nav.js` only to render a `پنل اصلی` link and bind logout when matching placeholders exist. It must not decide whether the current user is staff. Update active pages so missing/non-staff sessions go to `admin-login-v2.html`, and their back links go to `admin-panel.html`.

- [ ] **Step 5: Convert `admin.html` to a compatibility redirect**

Use a minimal page with `location.replace('admin-panel.html')`. Do not sign out, clear storage, or add query parameters, so an existing Supabase session survives.

- [ ] **Step 6: Update deploy allowlist and run navigation regressions**

Add `admin-nav.js` to the permitted root JavaScript files.

```bash
node --test tests/admin-navigation.cjs
node tests/html-script-syntax.cjs
python3 tests/deployment-safety.py
```

Expected: all PASS and every required destination exists under `public/`.

- [ ] **Step 7: Commit**

```bash
git add public/admin-nav.js public/admin-panel.html public/admin.html public/*.html tests/admin-navigation.cjs tests/deployment-safety.py
git commit -m "feat: unify administration navigation"
```

Before committing, inspect `git diff --cached --name-only` and unstage any unrelated HTML file; the broad add command is only for the explicitly changed active staff pages.

### Task 8: Full Staging Acceptance, Security Review, and Production Gate

**Files:**
- Modify: `test-checklist.md`
- Modify only if a test exposes a defect: files owned by Tasks 1–7.

**Interfaces:**
- Consumes: all prior task deliverables.
- Produces: a reviewable, staging-verified branch and an explicit production approval checkpoint; it does not deploy production by itself.

- [ ] **Step 1: Run every local automated test**

```bash
node --test tests/*.cjs
node tests/question-manager-selection.js
python3 tests/deployment-safety.py
```

Expected: zero failures and successful HTML script parsing.

- [ ] **Step 2: Reapply migration idempotently and run all staging SQL suites**

```bash
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260830085333_student_dashboard_and_resume.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/simple-student-auth.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-auth-ownership.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-dashboard-db.sql
psql "$STAGING_DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/student-import-db.sql
```

Expected: all suites PASS and a second migration application produces no error.

- [ ] **Step 3: Run Supabase security and performance advisors on staging**

Verify no new `SECURITY DEFINER` function has a mutable search path, no function is executable by `public`, private auth tables remain inaccessible, and no new unindexed ownership/deadline query warning is introduced. Record exact advisor output in the working report; fix any finding attributable to this branch before continuing.

- [ ] **Step 4: Perform browser acceptance at desktop and 320px width**

Verify: public role selection; student login; token start; empty/history/hidden/visible states; owned resume; cross-student resume denial; result detail hidden before close and visible after close; logout; admin/deputy entry; every canonical admin link; and old `admin.html`, `exam-access.html`, and `index.html?token=...` compatibility.

- [ ] **Step 5: Update the checklist with evidence**

Add a dated section to `test-checklist.md` containing commands, PASS counts, tested viewport widths, staging route results, advisor status, and explicit confirmation that no production data or schema was changed.

- [ ] **Step 6: Run an independent code review**

Use `superpowers:requesting-code-review`. Require review of the approved spec, both SQL functions, ACLs, hidden-score inference, cross-student IDs, safe-return parsing, DOM escaping, old-link compatibility, and admin feature parity. Address findings through `superpowers:receiving-code-review`, rerunning the affected tests after each accepted correction.

- [ ] **Step 7: Run final verification and commit acceptance evidence**

Use `superpowers:verification-before-completion`, then rerun:

```bash
git status --short
node --test tests/*.cjs
python3 tests/deployment-safety.py
```

```bash
git add test-checklist.md
git commit -m "test: verify unified portals on staging"
```

- [ ] **Step 8: Stop at the production approval gate**

Present the staging evidence, changed routes, migration name, rollback considerations, and review findings to the user. Ask for explicit approval before applying the migration to production, merging the GitHub PR, or triggering the production deployment.
