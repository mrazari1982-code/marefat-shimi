# Student Password Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution or superpowers:subagent-driven-development if the user selects delegation. Execute task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Replace student-code-only access with school-issued username/password accounts without losing examination records.

**Architecture:** Supabase Auth owns password hashing and authentication. A student-account Edge Function manages username mapping, temporary-password workflows and approved sessions; database authorization independently enforces ownership, account state and session revocation. Existing static pages use a separate student session and retain the current examination timer and scoring behavior.

**Tech Stack:** Static HTML/JavaScript, Supabase Auth/Postgres/RLS/Edge Functions, Deno tests, existing Node/Python tests; Cloudflare static hosting.

**Spec:** ../specs/2026-08-28-student-password-auth-design.md

## Global Constraints

- Username is the existing student_code, matched using lower(trim(code)); do not rewrite stored codes.
- No phone, SMS, email collection, public student signup or custom password hashing.
- Initial/reset password: 16 cryptographically random characters. Chosen password: minimum 12 characters. Never trim or case-fold passwords.
- Forced first password change, active account, approved session and credential_version checks apply in RPC and direct RLS access.
- Five failed attempts per code per 15 minutes; 60 gateway login requests per trusted client IP per minute.
- Student storage is sessionStorage with a key separate from the admin client; no password, student code or access/refresh token in URLs.
- Counter retention 24 hours; account audit retention 90 days; neither stores credentials or request bodies.
- Only active admin/deputy can provision/reset accounts; teacher cannot.
- Keep existing student, attempt, answer and result identifiers and values.
- Only public/ assets are published. Do not put migrations, tests or server code there.
- Never apply this plan to production without a separate approval.
- Production rollback closes student access; it never restores insecure code-only access.
- Never print secrets or submit real credentials into tests, commits, reports or chat.

## Known baseline and execution boundary

Read-only verification: staging project yyqeymyopawhaniyemqo is ACTIVE_HEALTHY and has no Edge Functions. Production rbqlblryxcaodvyrnfuo has 11 students, 11 normalized distinct codes and zero linked user_id values.
Local baseline: exam-lifecycle.cjs 12/12; deployment-safety.py 2/2; question-manager-selection.js passed.
These are existing tests only, not authentication acceptance evidence.

The current local frontend-fix directory is a partial source copy, not a git checkout. At execution, use using-git-worktrees to obtain an isolated checkout based on the design branch docs/student-password-auth-design. Fetch complete tracked files and applicable AGENTS.md instructions first. Do not initialize the partial copy and treat it as the complete repository.

## File map

Existing files to modify:
- public/index.html: require student session before starting exam.
- public/exam.html: authenticated RPC calls, remove student_code URL dependency; preserve timing logic.
- public/student-result.html: require session, remove code-based authorization form.
- public/students.html: provision/reset buttons with admin/deputy permission.
- tests/exam-lifecycle.cjs: extend existing harness with authenticated-session fixture.
- tests/deployment-safety.py: extend existing public-only checks for new server files.
- CLOUDFLARE-DEPLOY.md: staging/production cutover and fail-closed rollback instructions.

New focused files:
- public/student-login.html; public/student-password.html: two forms.
- public/student-auth.js: one shared client/session helper, no privileged credentials.
- supabase/functions/student-account/index.ts: HTTP routing and authentication boundary.
- supabase/functions/student-account/service.ts: account workflow and operation-state transitions.
- supabase/functions/student-account/provider.ts: Supabase Auth adapter.
- supabase/functions/student-account/store.ts: private account/rate/session RPC adapter.
- supabase/functions/student-account/service_test.ts: workflow, failure and concurrency tests.
- supabase/functions/student-account/http_test.ts: request validation/auth/error/logging tests.
- supabase/functions/student-account/deno.json and deno.lock: exact tested dependencies.
- tests/student-auth-browser.cjs: login/password/session UI contract tests.
- tests/student-auth-integration.mjs: live staging tests with synthetic users only.
- tests/sql/student-auth.sql: transactional database authorization tests.
- docs/security/student-auth-preflight.md: capabilities, exact versions and blockers, no secrets.
- docs/security/student-auth-verification.md: evidence and limitations.
- Three migration files generated by Supabase CLI: student_auth_state, student_auth_workflows, student_auth_authorization. Use CLI-generated timestamp paths; never guess timestamps.

## Shared contracts

Gateway POST /functions/v1/student-account accepts a discriminated JSON body:
- login: {action:"login", username:string, password:string}
- status: {action:"status"} with a verified bearer token
- change-password: {action:"change-password", currentPassword:string, newPassword:string} with verified bearer token
- logout: {action:"logout"} with verified bearer token
- provision: {action:"provision", studentId:number, operationId:string} with verified admin/deputy bearer token
- reset: {action:"reset", studentId:number, operationId:string} with verified admin/deputy bearer token

login success: {access_token, refresh_token, expires_at, must_change_password}.
status success: {student_id, student_code, must_change_password}.
change-password/logout success: {reauthenticate:true}.
provision/reset success: {student_id, username, temporary_password}; no persisted plaintext replay.
Errors: {error:"INVALID_CREDENTIALS"|"RATE_LIMITED"|"UNAUTHORIZED"|"FORBIDDEN"|"PASSWORD_POLICY"|"OPERATION_IN_PROGRESS"|"SERVICE_UNAVAILABLE", retry_after?:number}.
Use 401/429/401/403/400/409/503 respectively. Nonexistent, inactive and wrong-password login all use INVALID_CREDENTIALS.
Only POST and OPTIONS accepted. Bound JSON body to 8 KiB; username to 128 and password to 1024 Unicode code points; reject extra privileged fields. CORS origin allowlist is not authentication.
All responses: Cache-Control:no-store. Never log body, Authorization or returned tokens.
Authenticated browser requests use bearer JWTs; do not use ambient cookies as the gateway authentication mechanism.

Private SQL interfaces consumed by the store:
- begin_account_operation(student_id bigint, operation_id uuid, actor_id uuid, operation text) -> jsonb
- finish_account_operation(operation_id uuid, auth_user_id uuid) -> jsonb
- fail_account_operation(operation_id uuid, reason_code text) -> void
- approve_student_session(auth_user_id uuid, session_id uuid, expected_version bigint) -> boolean
- revoke_student_session(auth_user_id uuid, session_id uuid) -> void
- lookup_student_login(normalized_code text) -> jsonb (server only)
- consume_login_budget(normalized_code text, trusted_ip text) -> jsonb
- record_login_outcome(normalized_code text, trusted_ip text, succeeded boolean) -> void
- current_student_id(require_password_changed boolean default true) -> bigint
- assert_attempt_owner(attempt_id uuid) -> bigint

Private functions live in v5_private with locked search_path and explicit grants. If PostgREST wrappers are needed, expose narrow service-role-only wrappers with PUBLIC/anon/authenticated EXECUTE revoked. The browser must never be able to call administrative wrappers.
Database policies/RPCs call current_student_id internally; there is no browser argument for session_id or credential_version.

## Task 1: Prove prerequisites before building account flows

**Files:** docs/security/student-auth-preflight.md; tests/student-auth-integration.mjs (initial environment checks).
**Consumes:** staging project identifier.
**Produces:** recorded feasible provisioning/auth/session/rate-limit mechanism and a strictly staging-only test harness.

- [ ] Read full checkout instructions, current Supabase Auth/Edge docs and relevant changelog. Record exact runtime/SDK versions; do not copy a floating @2 import into new code.
- [ ] Read Auth settings through supported tools without exposing secrets. Verify existing admin email behavior, signup controls, Edge deployment and secret injection. Document the result rather than assuming an installed tool implies deployment permission.
- [ ] Add the integration harness project guard before any user creation:

```js
import assert from "node:assert/strict";
const stagingRef = "yyqeymyopawhaniyemqo";
const url = new URL(process.env.STUDENT_AUTH_TEST_URL);
assert.equal(url.hostname, stagingRef + ".supabase.co");
assert.equal(process.env.STUDENT_AUTH_TEST_WRITE, "synthetic-only");
```

- [ ] Run with production URL and assert rejection before network calls. Run with staging URL and explicit synthetic-only flag; only then allow fixture creation.
- [ ] On staging only, create a disposable synthetic account through supported Admin API using a random internal alias, confirm it without sending mail, authenticate, verify session_id claim and supported global signout behavior; delete/revoke fixtures afterward. Never manipulate auth.users password columns with SQL.
- [ ] Verify acceptance of the reserved internal alias domain. If rejected, stop and amend the design; do not invent a real email or change production email settings.
- [ ] Verify per-account throttling against direct Auth, not only the gateway. Check Password Verification Hook availability and current billing. If the agreed protection requires unavailable permission or a paid feature, stop and explain the exact gate; do not silently reduce protection.
- [ ] Verify a trustworthy client-IP source in the deployed gateway. A client-supplied forwarding header is not evidence. If unavailable, stop this gate and propose an ingress adjustment.
- [ ] Commit only redacted preflight evidence and the guarded harness. No migration or production write in this task.

**Pass condition:** all capability gates are recorded as proven or execution stops with a specific blocker. A skipped gate is not a pass.

## Task 2: Account/session state and database authorization primitive

**Files:** generated student_auth_state migration; tests/sql/student-auth.sql.
**Consumes:** Task 1 capability evidence.
**Produces:** private tables and current_student_id/assert_attempt_owner primitives.

- [ ] Inventory all v5 RPC signatures, ACLs, RLS policies and views; export definitions to the isolated checkout without data or credentials.
- [ ] Write SQL tests for anon, valid unlinked user, inactive student, temporary-password account, stale version and approved current account. Use SET LOCAL ROLE plus request.jwt.claims fixtures in a rollback transaction:

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"00000000-0000-4000-8000-000000000002"}',
 true);
-- The fixture user must not resolve to a usable student.
do $$ begin
  begin
    perform v5_private.current_student_id(true);
    raise exception 'TEST_EXPECTED_DENIAL';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
```

- [ ] Run before migration; confirm failure is missing authorization primitive, not a broken SQL runner.
- [ ] Generate migration using discovered CLI help. Add accounts, approved_sessions, account_operations, login_budgets and account_audit tables under v5_private. Enable RLS and revoke all public/browser table privileges. Add unique non-null v5_students.user_id index after duplicate check.
- [ ] Implement the primitive with this decision order:

```text
Read auth.uid() and JWT session_id; reject absent values.
Resolve one active student and ready private account for that uid.
Require approved session belonging to uid, not revoked, current credential_version.
Reject when require_password_changed and must_change_password.
Return existing student id; never accept a caller-supplied student code.
assert_attempt_owner calls this primitive, then checks attempt.student_id before side effects.
```

- [ ] Implement explicit 42501 denials, locked search_path, qualified names and least-privilege grants. No grants to private helpers merely for browser convenience.
- [ ] Run positive and negative SQL tests and advisor checks. Save migration with the CLI-supported workflow and commit.

## Task 3: Provision/reset/change operation state and abuse controls

**Files:** generated student_auth_workflows migration; service.ts; store.ts; service_test.ts.
**Consumes:** private tables and primitives.
**Produces:** all store contracts above; createAccountService(deps) with provision/reset/changePassword methods.

- [ ] Add Deno tests with in-memory fake provider/store adapters. Each adapter implements the shared contracts, records calls, and can fail before/after its side effect. Assert state rather than merely expecting a mock call.
- [ ] Test reset failure explicitly:

```ts
Deno.test("failed provider reset never re-enables old sessions", async () => {
  const state = {version: 1, blocked: false};
  const reset = async () => {
    state.version++;
    state.blocked = true;
    throw new Error("provider unavailable");
  };
  await reset().catch(() => {});
  if (state.version !== 2 || !state.blocked) throw new Error("unsafe reset");
});
```

Replace this characterization with the actual createAccountService.reset call using the same assertions when service exists; do not count a test of the illustrative closure as feature coverage.

- [ ] Implement operation reservation with row locking and operationId uniqueness. Store target expected version and stable generated auth id; repeat provision attaches the same account or reports in progress rather than creating another.
- [ ] Reset/change first acquire operation state, increment version and block access. Reauthenticate current password for student change, then call supported Auth API, then finalize only if operation/version still matches. On any failure retain restricted state and allow an explicit retry.
- [ ] Never hold a SQL transaction across a network call. A durable operation row owns the workflow; stale workers cannot complete over a newer operation.
- [ ] Generate temporary passwords with crypto.getRandomValues and an unbiased 64-character alphabet; exactly 16 characters. Do not persist plaintext. Lost success response requires reset, not replay from storage.
- [ ] Add atomic budget reservation/outcome accounting, including concurrent requests, nonexistent codes and failed transport cleanup. Add retention cleanup for 24-hour budgets and 90-day audit events.
- [ ] Configure the proven Task 1 direct-Auth mechanism and test the same user through direct Auth and gateway; existing student sessions must not be forcibly logged out by an attacker's failed-password flood.
- [ ] Run `deno test supabase/functions/student-account/service_test.ts` plus SQL tests. Commit only after failure/race cases pass.

## Task 4: Gateway and provider integration

**Files:** index.ts; provider.ts; http_test.ts; deno.json; deno.lock.
**Consumes:** Task 3 service and store.
**Produces:** HTTP contract; get verified identity and register approved Supabase session.

- [ ] Create HTTP tests using Request/Response and injected service; test missing bearer, forged JWT, teacher reset, wrong method, oversized body, generic login errors and redaction:

```ts
const req = new Request("https://example.invalid/student-account", {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({action:"reset",studentId:1,operationId:crypto.randomUUID()})
});
// With no bearer token the real handler must return 401 and never call reset.
```

- [ ] Implement handler validation and explicit action dispatch. For protected actions validate the JWT with supported Auth verification, not decode-only. Lookup active admin/deputy role from the database.
- [ ] Keep a stateless privileged client for Admin API and a separate per-request password-auth client; never let a signIn call replace the privileged client's session.
- [ ] Login performs budget check, normalized private lookup, password verification and version-checked approval of the returned session_id. If reset races with login, approval fails and tokens are revoked, not returned.
- [ ] For initial password change, authenticate/approve a restricted session; gateway permits status/change/logout only, database still enforces the restriction.
- [ ] Provider errors map to the documented contract; never return internal aliases, raw provider errors or secret keys. Return access/refresh tokens only on successful login with no-store.
- [ ] Because login has no existing JWT, deployment gateway verification can only be disabled after tests confirm custom authentication for every protected action. Record this exception; never expose unauthenticated admin actions.
- [ ] Deploy staging only, using platform secrets rather than secret files. Verify actual HTTP status/response, CORS allowlist and rejection without credentials.
- [ ] Run Deno tests and synthetic integration login/reset/logout tests; commit.

## Task 5: Protect every existing examination data path

**Files:** generated student_auth_authorization migration; tests/sql/student-auth.sql; tests/student-auth-integration.mjs.
**Consumes:** approved account sessions.
**Produces:** existing examination RPC names with enforced session ownership; no code-only bypass.

- [ ] Extend live synthetic fixtures to two students A/B, two sessions, one started and one submitted attempt each. Keep all fixture IDs in memory and cleanup all after tests.
- [ ] Before changing functions, prove A can use the legacy code route against B's synthetic result; record as expected failing security assertion, never use a real student's records.
- [ ] Modify every overload of the eight student RPCs listed in the spec. Retain parameter names temporarily for client compatibility but never treat student_code as authority. Derive own student id in start; assert owner first in every attempt operation.
- [ ] Revoke anon/PUBLIC execution and allow authenticated only. Audit helpers and default EXECUTE grants so renamed/internal functions are not new public bypasses.
- [ ] Tighten direct RLS for student-visible tables/views; revoke student access to raw scored answers where necessary and return safe saved selections only through RPC. Preserve explicit staff report permissions.
- [ ] Test request matrix for anon/A/B/expired/revoked/temporary/unregistered sessions, including direct REST tables/views and every overload. Example actual assertion in the integration runner:

```js
const response = await fetch(url + "/rest/v1/rpc/v5_get_student_result", {
  method:"POST",
  headers:{apikey:publishableKey,Authorization:"Bearer " + sessionA.access_token,
    "Content-Type":"application/json"},
  body:JSON.stringify({p_attempt_id:attemptB,p_student_code:codeB})
});
assert.equal(response.ok, false);
```

Here url/publishableKey are staging harness configuration; sessionA, attemptB and codeB are values created by the synthetic fixture setup in this task, never hand-copied real records.

- [ ] Assert score/correct-option fields absent from all pre-submit responses, not just hidden by UI. Re-run time/resume/post-submit regressions.
- [ ] Compare existing attempt/answer count and hashes before/after excluding synthetic fixtures. Run advisors; commit verified migration.

## Task 6: Student and administrator UI

**Files:** public/student-auth.js; public/student-login.html; public/student-password.html; existing index/exam/student-result/students pages; browser and lifecycle tests.
**Consumes:** gateway and protected RPCs.
**Produces:** window.StudentAuth API: requireReady(), login(username,password), changePassword(current,new), logout(), getClient().

- [ ] Write browser-contract tests for absent session redirect, restricted session password page, local return path, credential-free URLs and separate storage key.
- [ ] Implement helper using a pinned tested Supabase SDK; student storage key marefat-v5-student-auth, sessionStorage, detectSessionInUrl:false. Keep admin's existing storage untouched.
- [ ] Validate login return destination against a local allowlist of index.html/exam.html/student-result.html, retaining only exam token or attempt id. Reject external/protocol-relative return URLs.
- [ ] Forms have username/current-password/new-password autocomplete, masked passwords, paste support, disabled duplicate submit and accessible Persian errors. On error clear password input; never persist its value.
- [ ] requireReady verifies gateway status and returns the authenticated client; no protected RPC executes before it resolves. After password change/reset-required response, clear student session and require fresh login.
- [ ] Remove student-code input from exam start and result access; remove student_code URL construction. Existing links containing it must discard the field, not authenticate from it.
- [ ] Admin students page shows provision/reset only for active admin/deputy; reauthentication/confirmation precedes reset. Display temporary password only from the successful operation response with a private-delivery notice.
- [ ] Extend existing lifecycle harness with StudentAuth.requireReady fake. Keep all 12 existing behavioral assertions and add unauthenticated/no-RPC and re-login/no-timer-reset cases.
- [ ] Run:

```sh
node tests/student-auth-browser.cjs
node tests/exam-lifecycle.cjs
node tests/question-manager-selection.js
python3 tests/deployment-safety.py
```

- [ ] Test actual staging browser on mobile and desktop layouts with two synthetic accounts. Commit; do not publish production.

## Task 7: Acceptance evidence and production approval packet

**Files:** docs/security/student-auth-verification.md; CLOUDFLARE-DEPLOY.md; deployment-safety.py.
**Consumes:** all previous tasks.
**Produces:** reviewed release candidate; no automatic production deployment.

- [ ] Extend deployment safety tests to reject server directories/secrets in public and verify staging frontend is not configured for production.
- [ ] Run all unit, SQL, browser and live integration suites; annotate each of the spec's 12 acceptance items with command/result/evidence. Distinguish tested, blocked and not run.
- [ ] Confirm reset revokes old approved JWT access immediately, not merely after JWT expiration; confirm inactive accounts and direct-auth unregistered sessions fail all data routes.
- [ ] Test failure injection and two concurrent provisioning/reset requests. Verify no orphan usable account, no duplicate student and no old session accepted after version change.
- [ ] Re-run advisors and manually examine new warnings; do not equate zero warnings with full security.
- [ ] Review code and diff, document deployment prerequisites and any remaining limitations. Requesting-code-review and verification-before-completion skills apply.
- [ ] Prepare cutover outside active examinations: snapshot definitions/counts/hashes, provision only approved student roster, deploy coordinated frontend/backend, verify real URLs using synthetic accounts.
- [ ] Write fail-closed rollback: maintain secure DB gates, disable student entry, preserve accounts/answers, restore only compatible frontend; never restore code-only authorization.
- [ ] Present evidence and ask separate production approval. Do not merge into auto-deploy main, change production Auth settings or issue real credentials at this checkpoint.

## Coverage review

- Spec 1–3: Tasks 1, 4, 6.
- Spec 4–5: Tasks 2, 3, 4, 6.
- Spec 6: Tasks 2, 5.
- Spec 7: Tasks 1, 3, 4.
- Spec 8: Tasks 3, 7.
- Spec 9–10: Tasks 5–7.
- Spec 11 capability limits: Task 1 hard gates.

## Execution status

Planning only. No new account, migration, gateway or frontend auth implementation has been applied.
Direct-Auth throttle availability, trusted IP provenance and internal alias provisioning are mandatory first-task checks, not assumed successes.

References: [Supabase password auth](https://supabase.com/docs/guides/auth/passwords), [password verification hook](https://supabase.com/docs/guides/auth/auth-hooks/password-verification-hook), [Edge secrets](https://supabase.com/docs/guides/functions/secrets), [rate limits](https://supabase.com/docs/guides/auth/rate-limits).
