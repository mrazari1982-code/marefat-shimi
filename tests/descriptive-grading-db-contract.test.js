const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const migrationPath = path.join(__dirname, '../supabase/migrations/20260831210000_descriptive_answer_grading.sql');
const hardeningPath = path.join(__dirname, '../supabase/migrations/20260901173934_harden_descriptive_submission.sql');
const objectiveConsistencyPath = path.join(__dirname, '../supabase/migrations/20260901190000_fix_objective_grading_consistency.sql');

function migration() {
  return fs.readFileSync(migrationPath, 'utf8').toLowerCase();
}

function hardeningMigration() {
  return fs.readFileSync(hardeningPath, 'utf8').toLowerCase();
}

function objectiveConsistencyMigration() {
  return fs.readFileSync(objectiveConsistencyPath, 'utf8').toLowerCase();
}

test('student question contract preserves descriptive rows without exposing grading secrets', () => {
  const sql = migration();
  assert.match(sql, /v5_student_get_exam_questions\s*\(/);
  assert.match(sql, /question_type/);
  assert.match(sql, /left join\s+public\.v5_question_options/);
  const questionFunction = sql.match(/create or replace function public\.v5_student_get_exam_questions[\s\S]*?\$\$;/)?.[0] || '';
  assert.doesNotMatch(questionFunction, /answer_key|grading_rubric|expected_keywords|is_correct/);
});

test('descriptive save contract validates ownership, state, type, deadline, and length', () => {
  const sql = migration();
  const save = sql.match(/create or replace function public\.v5_student_save_descriptive_answer[\s\S]*?\$\$;/)?.[0] || '';
  assert.match(save, /student_for_token/);
  assert.match(save, /student_id\s*=\s*v_student\.id/);
  assert.match(save, /status\s*=\s*'started'/);
  assert.match(save, /question_type\s*<>\s*'descriptive'/);
  assert.match(save, /char_length\(v_answer\)\s*>\s*10000/);
  assert.match(save, /deadline/);
  assert.match(save, /on conflict\s*\(attempt_id,exam_question_id\)/);
  assert.match(save, /delete from public\.v5_student_answers/);
  assert.doesNotMatch(save, /insert into public\.v5_student_answers\([\s\S]*?question_order/);
});

test('migration adds grading state and immutable audit columns', () => {
  const sql = migration();
  for (const column of ['grading_status', 'graded_by', 'graded_at', 'grading_feedback']) {
    assert.match(sql, new RegExp(`add column if not exists ${column}`));
  }
});

test('security definer functions use fixed search paths and least privilege grants', () => {
  const sql = migration();
  assert.match(sql, /security definer\s+set search_path\s*=\s*pg_catalog,\s*public,\s*v5_auth_private/);
  assert.match(sql, /revoke all on function public\.v5_student_save_descriptive_answer\(uuid,bigint,text,text\) from public/);
  assert.match(sql, /grant execute on function public\.v5_student_save_descriptive_answer\(uuid,bigint,text,text\) to anon,authenticated/);
});

test('submission marks answered descriptive questions pending and withholds percentage', () => {
  const sql = migration();
  const submit = sql.match(/create or replace function public\.v5_student_submit_attempt[\s\S]*?\$\$;/)?.[0] || '';
  assert.match(submit, /pending_manual_count/);
  assert.match(submit, /grading_status/);
  assert.match(submit, /pending_manual/);
  assert.match(submit, /answer_text/);
  assert.match(submit, /percentage',case when v_pending_manual_count>0 then null/);
});

test('hardened submission rejects non-started and expired attempts', () => {
  const sql = hardeningMigration();
  assert.match(sql, /v_attempt\.status\s*<>\s*'started'/);
  assert.match(sql, /attempt_not_started/);
  assert.match(sql, /v_deadline\s+is\s+not\s+null/);
  assert.match(sql, /clock_timestamp\(\)\s*>\s*v_deadline/);
  assert.match(sql, /attempt_expired/);
});

test('pending manual submission response withholds all provisional result fields', () => {
  const sql = hardeningMigration();
  assert.match(sql, /'result_visible'\s*,\s*case\s+when\s+v_pending_manual_count\s*>\s*0\s+then\s+false/);
  for (const field of ['correct_answers', 'wrong_answers', 'unanswered_questions', 'total_score', 'max_score']) {
    assert.match(sql, new RegExp(`'${field}'\\s*,\\s*case\\s+when\\s+v_pending_manual_count\\s*>\\s*0\\s+then\\s+null`));
  }
});

test('submission persists objective correctness and awarded score before aggregating', () => {
  const sql = objectiveConsistencyMigration();
  const submit = sql.match(/create or replace function public\.v5_student_submit_attempt[\s\S]*?\$\$;/)?.[0] || '';
  assert.match(submit, /update public\.v5_student_answers sa set/);
  assert.match(submit, /qo\.question_id=eq\.question_id/);
  assert.match(submit, /is_correct=exists/);
  assert.match(submit, /score_awarded=case when exists/);
  assert.match(submit, /count\(\*\) filter \(where q\.question_type<>'descriptive'.*sa\.is_correct is true\)/);
  assert.match(submit, /coalesce\(sum\(sa\.score_awarded\),0\)/);
});

test('manual grading repairs objective counters while preserving least privilege', () => {
  const sql = objectiveConsistencyMigration();
  const grade = sql.match(/create or replace function public\.v5_admin_grade_descriptive_answer[\s\S]*?\$\$;/)?.[0] || '';
  assert.match(grade, /correct_count=v_correct,wrong_count=v_wrong,blank_count=v_blank/);
  assert.match(grade, /q\.question_type<>'descriptive'.*sa\.is_correct is false/);
  assert.match(grade, /security definer\s+set search_path\s*=\s*pg_catalog,\s*public/);
  assert.match(sql, /revoke all on function public\.v5_admin_grade_descriptive_answer\(bigint,numeric,text\) from public,anon/);
  assert.match(sql, /grant execute on function public\.v5_admin_grade_descriptive_answer\(bigint,numeric,text\) to authenticated/);
});

test('staff grading contract enforces role, score bounds, audit, and recalculation', () => {
  const sql = migration();
  assert.match(sql, /v5_admin_pending_descriptive_answers/);
  const grade = sql.match(/create or replace function public\.v5_admin_grade_descriptive_answer[\s\S]*?\$\$;/)?.[0] || '';
  assert.match(grade, /v5_is_staff/);
  assert.match(grade, /p_score\s*<\s*0/);
  assert.match(grade, /p_score\s*>\s*v_max_score/);
  assert.match(grade, /graded_by\s*=\s*auth\.uid\(\)/);
  assert.match(grade, /graded_at\s*=\s*clock_timestamp\(\)/);
  assert.match(grade, /grading_status/);
  assert.match(grade, /when q\.question_type<>'descriptive' and qo\.is_correct then eq\.score/);
  assert.match(sql, /grant execute on function public\.v5_admin_grade_descriptive_answer\(bigint,numeric,text\) to authenticated/);
  assert.doesNotMatch(sql, /grant execute on function public\.v5_admin_grade_descriptive_answer\(bigint,numeric,text\) to anon/);
});

test('student dashboard and result contracts hide pending manual grades', () => {
  const sql = migration();
  for (const name of ['v5_student_dashboard_v2', 'v5_student_get_result_v2']) {
    const fn = sql.match(new RegExp(`create or replace function public\\.${name}[\\s\\S]*?\\$\\$;`))?.[0] || '';
    assert.match(fn, /grading_status/);
    assert.match(fn, /pending_manual/);
    assert.match(fn, /result_visible/);
    assert.match(fn, /percentage/);
  }
  assert.match(sql, /grant execute on function public\.v5_student_dashboard_v2\(text,integer\) to anon,authenticated/);
  assert.match(sql, /grant execute on function public\.v5_student_get_result_v2\(uuid,text\) to anon,authenticated/);
});
