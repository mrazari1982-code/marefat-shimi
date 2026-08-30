const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const source = fs.readFileSync(path.join(__dirname, '../public/student-dashboard.js'), 'utf8');

class Element {
  constructor(tag = 'div') { this.tagName = tag.toUpperCase(); this.children = []; this.dataset = {}; this.hidden = false; this.disabled = false; this.className = ''; this.value = ''; this.type = ''; this._text = ''; this.listeners = {}; }
  append(...nodes) { nodes.forEach(node => { if (node) { node.parentNode = this; this.children.push(node); } }); }
  replaceChildren(...nodes) { this.children = []; this._text = ''; this.append(...nodes); }
  addEventListener(name, handler) { this.listeners[name] = handler; }
  click() { return this.listeners.click?.({preventDefault() {}}) || this.onclick?.({preventDefault() {}}); }
  submit() { return this.listeners.submit?.({preventDefault() {}}); }
  set textContent(value) { this._text = String(value ?? ''); this.children = []; }
  get textContent() { return this._text + this.children.map(child => child.textContent).join(''); }
  set innerHTML(value) { throw new Error('dashboard must not use innerHTML'); }
  get innerHTML() { return ''; }
}

function selectorMatch(element, selector) {
  const match = selector.match(/^\[data-([\w-]+)="([^"]+)"\]$/);
  if (match) return element.dataset[match[1].replace(/-([a-z])/g, (_, c) => c.toUpperCase())] === match[2];
  return false;
}

function descendants(element) { return element.children.flatMap(child => [child, ...descendants(child)]); }
function ownedPayload() { return {profile: {full_name: 'دانش‌آموز آزمون', student_code: 'S-1', grade_name: 'دهم'}, summary: {attempt_count: 2, submitted_count: 1, in_progress_count: 1, visible_result_count: 1, average_percentage: 75, correct_count: 6, wrong_count: 2, blank_count: 0}, attempts: [
  {attempt_id: 'attempt-a', exam_title: 'آزمون فعال', status: 'started', started_at: '2026-08-28T10:00:00Z', result_visible: false, can_resume: true},
  {attempt_id: 'attempt-b', exam_title: 'آزمون نتیجه', status: 'submitted', submitted_at: '2026-08-27T10:00:00Z', result_visible: true, percentage: 75, correct_count: 6, wrong_count: 2, blank_count: 0, can_resume: false}
]}; }

function harness(payload, options = {}) {
  const elements = new Map(['profile', 'summary', 'history', 'trend', 'dashboard-message', 'token-form', 'exam-token', 'start-exam', 'retry', 'logout'].map(id => [id, new Element(id === 'exam-token' ? 'input' : id === 'token-form' ? 'form' : 'div')]));
  elements.get('retry').hidden = true;
  let location = null, calls = [], failures = options.failures || 0;
  const doc = {
    getElementById(id) { return elements.get(id) || null; },
    createElement(tag) { return new Element(tag); },
    querySelector(selector) { return [...elements.values(), ...[...elements.values()].flatMap(descendants)].find(el => selectorMatch(el, selector)) || null; },
    querySelectorAll(selector) { return [...elements.values(), ...[...elements.values()].flatMap(descendants)].filter(el => selectorMatch(el, selector)); }
  };
  const rpc = async (name, args) => {
    calls.push([name, args]);
    if (name === 'v5_dashboard' && options.dashboardResult) return options.dashboardResult;
    if (name === 'v5_dashboard' && failures-- > 0) return {error: {message: 'Network unavailable'}};
    if (name === 'v5_start_exam') return options.startResult || {data: {attempt_id: 'new-attempt'}};
    if (name === 'v5_resume_attempt') return options.resumeResult || {data: {available: true, attempt_id: args.p_attempt_id}};
    return {data: payload};
  };
  const auth = {requireSession: options.requireSession || (() => ({student_name: 'دانش‌آموز آزمون'})), logout: async () => { calls.push(['logout']); if (options.logoutReject) throw new Error('Network unavailable'); }, getSession: () => ({})};
  const params = new URLSearchParams(options.search || '');
  const ctx = vm.createContext({console, document: doc, URLSearchParams, location: {search: options.search || '', assign: value => { location = value; }, replace: value => { location = value; }, set href(value) { location = value; }, get href() { return location; }},
    supabase: {createClient: () => ({rpc})}, MarefatStudentAuth: auth, __STUDENT_DASHBOARD_TEST__: true, globalThis: null});
  ctx.globalThis = ctx;
  vm.runInContext(source, ctx);
  return {init: () => ctx.initDashboard(), click: selector => doc.querySelector(selector)?.click(), submitToken: () => elements.get('token-form').submit(), text: id => elements.get(id).textContent, elements, calls, get location() { return location; }, get token() { return elements.get('exam-token').value; }, ctx, params};
}

const tests = [];
const test = (name, fn) => tests.push([name, fn]);

test('hidden attempt never renders score text', async () => {
  const h = harness({profile: {}, summary: {}, attempts: [{attempt_id: 'a', exam_title: 'آزمون پنهان', status: 'submitted', result_visible: false, percentage: null, correct_count: null, wrong_count: null, blank_count: null, can_resume: false}]});
  await h.init();
  assert.match(h.text('history'), /در انتظار انتشار/);
  assert.doesNotMatch(h.text('history'), /%|صحیح|غلط/);
  assert.equal(h.ctx.document.querySelector('[data-result="a"]'), null);
});
test('resume and result actions use attempt id only', async () => {
  const h = harness(ownedPayload()); await h.init(); h.click('[data-resume="attempt-a"]'); await new Promise(setImmediate);
  assert.equal(h.location, 'exam.html?attempt=attempt-a');
  h.click('[data-result="attempt-b"]'); assert.equal(h.location, 'student-result.html?attempt=attempt-b');
});
test('denied resume explains the reason and refreshes the owned history', async () => {
  const h = harness(ownedPayload(), {resumeResult: {data: {available: false, reason: 'deadline_passed'}}});
  await h.init(); h.click('[data-resume="attempt-a"]'); await new Promise(setImmediate);
  assert.match(h.text('dashboard-message'), /مهلت ادامه/);
  assert.equal(h.calls.filter(([name]) => name === 'v5_dashboard').length, 2);
  assert.equal(h.elements.get('exam-token').disabled, false);
});
test('every error-shaped resume denial refreshes and retains its localized reason', async () => {
  const denials = [['ATTEMPT_SUBMITTED', /قبلاً ثبت شده/], ['ATTEMPT_EXPIRED', /مهلت ادامه/], ['EXAM_CLOSED', /به پایان رسیده/]];
  for (const [message, expected] of denials) {
    const h = harness(ownedPayload(), {resumeResult: {error: {message}}});
    await h.init(); await h.click('[data-resume="attempt-a"]');
    assert.match(h.text('dashboard-message'), expected, message);
    assert.equal(h.calls.filter(([name]) => name === 'v5_dashboard').length, 2, message);
  }
});
test('summary renders the server-filtered answer aggregates', async () => {
  const h = harness(ownedPayload()); await h.init();
  assert.match(h.text('summary'), /صحیح.*۶/);
  assert.match(h.text('summary'), /غلط.*۲/);
  assert.match(h.text('summary'), /بی‌پاسخ.*۰/);
});
test('empty history has an accessible empty state', async () => {
  const h = harness({profile: {}, summary: {}, attempts: []}); await h.init(); assert.match(h.text('history'), /سابقه‌ای/);
});
test('retry reloads dashboard after a network error', async () => {
  const h = harness(ownedPayload(), {failures: 1}); await h.init(); assert.match(h.text('dashboard-message'), /Network unavailable/); assert.equal(h.elements.get('retry').hidden, false); h.elements.get('retry').click(); await new Promise(setImmediate); assert.equal(h.calls.filter(([name]) => name === 'v5_dashboard').length, 2);
});
test('fewer than two visible results hide trend', async () => {
  const h = harness(ownedPayload()); await h.init(); assert.equal(h.elements.get('trend').hidden, true);
});
test('trend follows chronological visible result order', async () => {
  const p = ownedPayload(); p.attempts.push({attempt_id: 'attempt-c', exam_title: 'قدیمی', status: 'submitted', submitted_at: '2026-08-20T10:00:00Z', result_visible: true, percentage: 40, correct_count: 1, wrong_count: 2, blank_count: 0, can_resume: false});
  const h = harness(p); await h.init(); assert.match(h.text('trend'), /قدیمی[\s\S]*۴۰[\s\S]*آزمون نتیجه[\s\S]*۷۵/);
});
test('logout clears session then routes to login', async () => {
  const h = harness(ownedPayload()); await h.init(); h.elements.get('logout').click(); await new Promise(setImmediate); assert.deepEqual(h.calls.at(-1), ['logout']); assert.equal(h.location, 'student-login.html');
});
test('logout rejection still routes to login', async () => {
  const h = harness(ownedPayload(), {logoutReject: true}); await h.init();
  await h.elements.get('logout').click().catch(() => {});
  assert.deepEqual(h.calls.at(-1), ['logout']); assert.equal(h.location, 'student-login.html');
});
test('student content is rendered as text rather than HTML interpolation', async () => {
  const h = harness({profile: {full_name: '<img src=x onerror=alert(1)>'}, summary: {}, attempts: []}); await h.init(); assert.match(h.text('profile'), /<img src=x onerror=alert\(1\)>/);
});
test('token compatibility starts safely without student code', async () => {
  const h = harness(ownedPayload(), {search: '?token=approved-token'}); await h.init(); assert.equal(h.token, 'approved-token'); await h.submitToken(); assert.deepEqual(JSON.parse(JSON.stringify(h.calls.find(([name]) => name === 'v5_start_exam'))), ['v5_start_exam', {p_token: 'approved-token'}]); assert.equal(h.location, 'exam.html?attempt=new-attempt');
});
test('token form submission starts the exam without a mouse click', async () => {
  const h = harness(ownedPayload()); await h.init(); h.elements.get('exam-token').value = 'keyboard-token'; await h.submitToken();
  assert.deepEqual(JSON.parse(JSON.stringify(h.calls.find(([name]) => name === 'v5_start_exam'))), ['v5_start_exam', {p_token: 'keyboard-token'}]);
});
test('missing and expired sessions do not request or render private dashboard data', async () => {
  for (const state of ['missing', 'expired']) {
    const h = harness(ownedPayload(), {requireSession: () => null}); await h.init();
    assert.equal(h.calls.filter(([name]) => name === 'v5_dashboard').length, 0, state);
    assert.equal(h.text('profile'), '', state);
  }
});
test('unauthorized dashboard response logs out and routes to login', async () => {
  const h = harness(ownedPayload(), {dashboardResult: {error: {message: 'UNAUTHORIZED'}}}); await h.init();
  assert.deepEqual(h.calls.at(-1), ['logout']); assert.equal(h.location, 'student-login.html');
});
test('HTML shell preserves semantic dashboard structure and dependency order', () => {
  const html = fs.readFileSync(path.join(__dirname, '../public/student-dashboard.html'), 'utf8');
  assert.match(html, /<html[^>]*dir="rtl"/); assert.match(html, /<main[^>]*id="dashboard-main"/); assert.match(html, /id="dashboard-message"[^>]*role="status"[^>]*aria-live="polite"/);
  assert.match(html, /<label[^>]*for="exam-token"/); assert.match(html, /<form[^>]*id="token-form"/); assert.match(html, /id="start-exam"[^>]*type="submit"/);
  for (const id of ['profile', 'summary', 'history', 'trend', 'dashboard-message', 'exam-token', 'start-exam', 'retry', 'logout']) assert.match(html, new RegExp(`id="${id}"`));
  assert.ok(html.indexOf('supabase-js@2') < html.indexOf('student-auth.js') && html.indexOf('student-auth.js') < html.indexOf('student-dashboard.js'));
  assert.match(html, /min-height:44px/);
});
test('HTML structural CSS keeps long dynamic values inside a 320px layout', () => {
  const html = fs.readFileSync(path.join(__dirname, '../public/student-dashboard.html'), 'utf8');
  assert.match(html, /overflow-wrap:anywhere/); assert.match(html, /@media\(max-width:480px\).*grid\{grid-template-columns:1fr/s);
});

(async () => { let failed = 0; for (const [name, fn] of tests) { try { await fn(); console.log(`PASS ${name}`); } catch (error) { failed++; console.log(`FAIL ${name}\n${error.stack}`); } } console.log(`${tests.length - failed}/${tests.length} passed`); if (failed) process.exitCode = 1; })();
