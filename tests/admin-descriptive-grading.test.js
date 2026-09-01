const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const pagePath = path.join(__dirname, '../public/admin-descriptive-grading.html');
const scriptPath = path.join(__dirname, '../public/admin-descriptive-grading.js');

test('manual grading page uses canonical staff guard and RPCs', () => {
  const page = fs.readFileSync(pagePath, 'utf8');
  const script = fs.readFileSync(scriptPath, 'utf8');
  assert.match(page, /admin-nav\.js/);
  assert.match(page, /admin-panel\.html/);
  assert.match(script, /v5_is_staff/);
  assert.match(script, /admin-login-v2\.html/);
  assert.match(script, /v5_admin_pending_descriptive_answers/);
  assert.match(script, /v5_admin_grade_descriptive_answer/);
});

test('manual grading page renders untrusted content with textContent', () => {
  const script = fs.readFileSync(scriptPath, 'utf8');
  assert.match(script, /textContent/);
  assert.doesNotMatch(script, /innerHTML/);
  assert.match(script, /max_score/);
  assert.match(script, /grading_feedback/);
});
