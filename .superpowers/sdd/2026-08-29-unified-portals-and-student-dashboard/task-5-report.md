## Task 5 report

Status: complete

Round 1 review fixes: complete

Scope verified:

- `public/exam.html`
- `public/student-result.html`
- `tests/student-journey-browser.cjs`
- `tests/exam-lifecycle.cjs`

What Task 5 now does:

- Exam bootstrap supports either `?attempt=<owned-id>` resume or `?token=<public-token>` start.
- Attempt operations (`resume`, `questions`, `state`, `save`, `submit`) use `p_attempt_id` only; no student code is sent.
- Submission results always include a dashboard return action and only include `مشاهده کارنامه` when result visibility allows it.
- Immediate post-submit result visibility is fail-closed: score output and the result action render only when `result_visible === true`, or when that newer flag is absent and legacy `show_result === true`.
- Result page auto-loads from the `attempt` query string, removes the manual attempt workflow, always keeps owner metadata visible to the owner, hides summary until `result_visible === true`, and hides details unless `detail_visible === true` with non-empty `details`.
- Detail rendering uses DOM text nodes so untrusted result content is not injected as HTML.
- An expired attempt state returned during initialization is handled before rendering the exam UI and falls back to a safe final/dashboard state.
- Timer, autosave, reopen, expiry auto-submit, and hidden-result regressions remain covered.

Binding review cases now covered:

- Missing, `null`, string, and conflicting submit visibility flags all fail closed.
- Visible submit fixtures are explicit about `show_result: true` and `result_visible: true`.
- Resume precedence prefers `?attempt=` over `?token=` and supports encoded attempt IDs in the result link.
- Data-shaped resume denial (`available:false`) is covered, not only RPC errors.
- Hidden submit results retain the dashboard action and omit the result action.
- Result summary/detail visibility remains strict for malformed flags, empty details, and non-array details.
- The lifecycle suite now exercises a real expired state between question and state fetch.

Verification run on resumed state:

1. `node --test tests/student-journey-browser.cjs` → PASS (18/18)
2. `node --test tests/exam-lifecycle.cjs` → PASS (18/18)
3. `node tests/student-auth-browser.cjs` → PASS
4. `node tests/html-script-syntax.cjs` → PASS
5. `node tests/student-dashboard-browser.cjs` → PASS (18/18)
6. `node tests/student-import-browser.cjs` → PASS
7. `node tests/student-import-page.cjs` → PASS
8. `node tests/student-import-workbook.cjs` → PASS
9. `node tests/question-manager-selection.js` → PASS
10. `python3 tests/deployment-safety.py` → PASS

Notes:

- The resumed worktree already contained the base Task 5 implementation, but the accepted review exposed two remaining policy/lifecycle gaps.
- Round 1 re-established RED with new failing journey/lifecycle cases before the `public/exam.html` fix.
- No DB, deploy, or production configuration changes were made.

Concerns:

- None from the verified task scope.
