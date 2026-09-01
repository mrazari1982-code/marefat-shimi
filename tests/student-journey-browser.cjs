const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');

const examHtml = fs.readFileSync(path.join(__dirname, '../public/exam.html'), 'utf8');
const resultHtml = fs.readFileSync(path.join(__dirname, '../public/student-result.html'), 'utf8');

function inlineScript(html) {
  const match = html.match(/<script>\s*([\s\S]*?)<\/script>/);
  assert.ok(match, 'inline page script is required');
  return match[1];
}

class ExamElement {
  constructor() { this.textContent = ''; this.innerHTML = ''; this.hidden = true; this.disabled = false; this.className = ''; this.value = ''; this.listeners = {}; }
  addEventListener(name, handler) { this.listeners[name] = handler; }
}

function defaultExamRpc(name) {
  if (name === 'v5_resume_attempt') return {data: {available: true, attempt_id: 'owned-id', title: 'آزمون مالک', student_name: 'دانش‌آموز مالک', status: 'started', duration_minutes: null, deadline_at: null}};
  if (name === 'v5_start_exam') return {data: {attempt_id: 'started-id', title: 'آزمون توکن', student_name: 'دانش‌آموز مالک', status: 'started', duration_minutes: null, deadline_at: null}};
  if (name === 'v5_get_exam_questions') return {data: [{id: 1, question_order: 1, question_text: 'دو بعلاوه دو؟', option_id: 10, option_key: 'الف', option_text: 'چهار', sort_order: 1}]};
  if (name === 'v5_get_attempt_state') return {data: {status: 'started', answers: [], duration_minutes: null, deadline_at: null}};
  if (name === 'v5_submit_attempt') return {data: {status: 'submitted', show_result: true, result_visible: true, correct_answers: 1, wrong_answers: 0, unanswered_questions: 0, total_score: 1, max_score: 1, percentage: 100}};
  return {data: {saved: true, status: 'started'}};
}

function harness(url, rpc = defaultExamRpc) {
  const elements = new Map(['loading', 'msg', 'exam', 'title', 'student', 'timer', 'progress', 'save', 'questions', 'submit', 'result', 'resultText'].map(id => [id, new ExamElement()]));
  elements.get('loading').hidden = false;
  const calls = [];
  const document = {
    getElementById(id) { return elements.get(id); },
    querySelector() { return null; },
    querySelectorAll() { return []; }
  };
  let source = inlineScript(examHtml).replace("init().catch(e=>setmsg('خطای سامانه: '+e.message,'err'));", '');
  const context = vm.createContext({
    document,
    location: {search: new URL(url, 'https://example.test').search},
    URLSearchParams,
    Date,
    performance: {now: () => 0},
    confirm: () => true,
    setInterval: () => 1,
    clearInterval() {},
    supabase: {createClient: () => ({rpc: async (name, args) => { calls.push([name, JSON.parse(JSON.stringify(args))]); return rpc(name, args); }})}
  });
  vm.runInContext(source, context);
  return {
    calls,
    elements,
    init: () => vm.runInContext('init()', context),
    submit: () => vm.runInContext('submitExam(true)', context),
    resultHtml: () => elements.get('resultText').innerHTML,
    examHidden: () => elements.get('exam').hidden !== false,
    resultHidden: () => elements.get('result').hidden !== false
  };
}

class ResultElement {
  constructor(tag = 'div') { this.tagName = tag.toUpperCase(); this.children = []; this.hidden = false; this.disabled = false; this.className = ''; this.value = ''; this._text = ''; this.attributes = {}; }
  append(...nodes) { for (const node of nodes) if (node !== null && node !== undefined) this.children.push(typeof node === 'string' ? new ResultText(node) : node); }
  replaceChildren(...nodes) { this.children = []; this._text = ''; this.append(...nodes); }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  addEventListener() {}
  set textContent(value) { this._text = String(value ?? ''); this.children = []; }
  get textContent() { return this._text + this.children.map(node => node.textContent).join(''); }
  set innerHTML(_) { throw new Error('result page must render untrusted data with DOM text nodes'); }
  get innerHTML() { return ''; }
}
class ResultText extends ResultElement { constructor(text) { super('#text'); this._text = text; } }

function idsIn(html) {
  return [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
}

function resultFixture(overrides = {}) {
  return {
    attempt_id: 'result-id',
    student_name: 'دانش‌آموز مالک',
    student_code: 'S-1',
    exam_title: 'آزمون نتیجه',
    exam_code: 'EX-1',
    status: 'submitted',
    submitted_at: '2026-08-29T12:00:00Z',
    result_visible: true,
    detail_visible: false,
    percentage: 62.5,
    correct_count: 5,
    wrong_count: 2,
    blank_count: 1,
    total_score: 5,
    details: [],
    ...overrides
  };
}

function harnessResult(payload, options = {}) {
  const elements = new Map(idsIn(resultHtml).map(id => [id, new ResultElement(id === 'rows' ? 'tbody' : 'div')]));
  const calls = [];
  const search = options.search === undefined ? '?attempt=result-id' : options.search;
  let source = inlineScript(resultHtml);
  if (!options.auto) source = source.replace(/\binit\(\);\s*$/, '');
  const document = {
    getElementById(id) { return elements.get(id) || null; },
    createElement(tag) { return new ResultElement(tag); },
    createTextNode(text) { return new ResultText(String(text)); }
  };
  const rpc = options.rpc || (async () => ({data: payload}));
  const context = vm.createContext({
    document,
    location: {search},
    URLSearchParams,
    Date,
    supabase: {createClient: () => ({rpc: async (name, args) => { calls.push([name, JSON.parse(JSON.stringify(args))]); return rpc(name, args); }})}
  });
  vm.runInContext(source, context);
  const text = id => elements.get(id)?.textContent || '';
  return {
    calls,
    load: () => vm.runInContext('load()', context),
    settle: async () => { await new Promise(setImmediate); await new Promise(setImmediate); },
    summaryText: () => [text('pct'), text('correct'), text('wrong'), text('blank')].join(' '),
    ownerText: () => text('owner'),
    messageText: () => text('msg'),
    rowsText: () => text('rows'),
    summaryHidden: () => elements.get('summary')?.hidden !== false,
    detailHidden: () => elements.get('detail')?.hidden !== false,
    ownerHidden: () => elements.get('owner')?.hidden !== false,
    manualControlsPresent: () => elements.has('id') || elements.has('load') || elements.has('code')
  };
}

test('attempt query resumes without public token', async () => {
  const h = harness('/exam.html?attempt=owned-id');
  await h.init();
  assert.equal(h.calls[0][0], 'v5_resume_attempt');
  assert.deepEqual(h.calls[0][1], {p_attempt_id: 'owned-id'});
  assert.equal(h.calls.some(([, args]) => 'p_student_code' in (args || {})), false);
});

test('token query starts an owned attempt and then uses attempt-only calls', async () => {
  const h = harness('/exam.html?token=public-token');
  await h.init();
  assert.deepEqual(h.calls.map(([name]) => name), ['v5_start_exam', 'v5_get_exam_questions', 'v5_get_attempt_state']);
  assert.deepEqual(h.calls[0][1], {p_token: 'public-token'});
  assert.equal(h.calls.every(([, args]) => !('p_student_code' in (args || {}))), true);
});

test('attempt query takes precedence when attempt and token are both present', async () => {
  const h = harness('/exam.html?attempt=owned-id&token=public-token');
  await h.init();
  assert.equal(h.calls[0][0], 'v5_resume_attempt');
  assert.deepEqual(h.calls[0][1], {p_attempt_id: 'owned-id'});
  assert.equal(h.calls.some(([name]) => name === 'v5_start_exam'), false);
});

test('missing exam query reports an error without an RPC', async () => {
  const h = harness('/exam.html');
  await h.init();
  assert.equal(h.calls.length, 0);
  assert.equal(h.elements.get('msg').className, 'err');
  assert.match(h.elements.get('msg').textContent, /لینک|پنل|شناسه/);
});

test('invalid owned attempt stops before questions', async () => {
  const h = harness('/exam.html?attempt=missing', async name => name === 'v5_resume_attempt' ? {error: {message: 'ATTEMPT_NOT_FOUND'}} : defaultExamRpc(name));
  await h.init();
  assert.deepEqual(h.calls.map(([name]) => name), ['v5_resume_attempt']);
  assert.equal(h.elements.get('msg').className, 'err');
  assert.match(h.elements.get('msg').textContent, /ATTEMPT_NOT_FOUND|پیدا/);
});

test('data-shaped resume denial stops before rendering questions', async () => {
  const h = harness('/exam.html?attempt=owned-id', async name => name === 'v5_resume_attempt'
    ? {data: {available: false, reason: 'deadline_passed', attempt_id: 'owned-id', title: 'آزمون مالک'}}
    : defaultExamRpc(name));
  await h.init();
  assert.deepEqual(h.calls.map(([name]) => name), ['v5_resume_attempt']);
  assert.equal(h.examHidden(), true);
  assert.equal(h.resultHidden(), true);
  assert.match(h.elements.get('msg').textContent, /deadline_passed|قابل ادامه نیست/);
});

test('submitted exam offers dashboard and encoded visible-result action', async () => {
  const h = harness('/exam.html?attempt=owned%20id%2Fplus%3F%26', async (name, args) => {
    if (name === 'v5_resume_attempt') return {data: {available: true, attempt_id: args.p_attempt_id, title: 'آزمون مالک', student_name: 'دانش‌آموز مالک', status: 'started', duration_minutes: null, deadline_at: null}};
    return defaultExamRpc(name, args);
  });
  await h.init();
  await h.submit();
  assert.match(h.resultHtml(), /student-dashboard\.html/);
  assert.match(h.resultHtml(), /student-result\.html\?attempt=owned%20id%2Fplus%3F%26/);
  assert.match(h.resultHtml(), /مشاهده کارنامه/);
});

test('hidden post-submit keeps dashboard action but omits result action', async () => {
  const h = harness('/exam.html?attempt=owned-id', async name => name === 'v5_submit_attempt'
    ? {data: {status: 'submitted', show_result: false, result_visible: false}}
    : defaultExamRpc(name));
  await h.init();
  await h.submit();
  assert.match(h.resultHtml(), /student-dashboard\.html/);
  assert.doesNotMatch(h.resultHtml(), /student-result\.html\?attempt=/);
  assert.doesNotMatch(h.resultHtml(), /مشاهده کارنامه/);
});

test('visible result before close hides details', async () => {
  const h = harnessResult(resultFixture({result_visible: true, detail_visible: false, percentage: 62.5, details: []}));
  await h.load();
  assert.match(h.summaryText(), /62\.50/);
  assert.equal(h.detailHidden(), true);
});

test('pending manual result hides summary and explains grading state', async () => {
  const h = harnessResult(resultFixture({grading_status: 'pending_manual', pending_manual_count: 1, result_visible: false, detail_visible: false, percentage: null, correct_count: null, wrong_count: null, blank_count: null, details: null}));
  await h.load();
  assert.equal(h.summaryHidden(), true);
  assert.equal(h.detailHidden(), true);
  assert.match(h.messageText(), /در انتظار تصحیح/);
  assert.doesNotMatch(h.summaryText(), /0\.00|62\.50/);
});

test('hidden result shows owner metadata and waiting state only', async () => {
  const h = harnessResult(resultFixture({result_visible: false, detail_visible: false, percentage: null, correct_count: null, wrong_count: null, blank_count: null, details: null}));
  await h.load();
  assert.equal(h.ownerHidden(), false);
  assert.match(h.ownerText(), /آزمون نتیجه/);
  assert.match(h.ownerText(), /ثبت‌شده/);
  assert.match(h.ownerText(), /۱۴۰۵|2026/);
  assert.equal(h.summaryHidden(), true);
  assert.equal(h.detailHidden(), true);
  assert.match(h.messageText(), /در انتظار انتشار/);
  assert.doesNotMatch(h.summaryText(), /0\.00|62\.50/);
});

test('closed result shows non-empty allowed details with safe text rendering', async () => {
  const details = [{question_order: 1, question_text: '<img src=x onerror=alert(1)>', answer_text: 'چهار', is_correct: true, score_awarded: 1, correct_option_key: 'الف', correct_option_text: 'چهار'}];
  const h = harnessResult(resultFixture({detail_visible: true, details}));
  await h.load();
  assert.equal(h.detailHidden(), false);
  assert.match(h.rowsText(), /<img src=x onerror=alert\(1\)>/);
  assert.match(h.rowsText(), /چهار/);
});

test('truthy non-boolean result visibility does not reveal summary', async () => {
  const h = harnessResult(resultFixture({result_visible: 'true', detail_visible: false}));
  await h.load();
  assert.equal(h.summaryHidden(), true);
  assert.match(h.messageText(), /در انتظار انتشار/);
});

test('truthy non-boolean detail visibility does not reveal details', async () => {
  const details = [{question_order: 1, question_text: 'سؤال', answer_text: 'پاسخ', is_correct: true, score_awarded: 1}];
  const h = harnessResult(resultFixture({result_visible: true, detail_visible: 'true', details}));
  await h.load();
  assert.equal(h.detailHidden(), true);
});

test('detail visibility requires a non-empty array', async () => {
  const emptyDetails = harnessResult(resultFixture({result_visible: true, detail_visible: true, details: []}));
  await emptyDetails.load();
  assert.equal(emptyDetails.detailHidden(), true);

  const objectDetails = harnessResult(resultFixture({result_visible: true, detail_visible: true, details: {question_order: 1}}));
  await objectDetails.load();
  assert.equal(objectDetails.detailHidden(), true);
});

test('result page loads attempt from query automatically without student code', async () => {
  const h = harnessResult(resultFixture(), {auto: true, search: '?attempt=auto-id'});
  await h.settle();
  assert.deepEqual(h.calls, [['v5_get_student_result', {p_attempt_id: 'auto-id'}]]);
});

test('missing result attempt has no manual ID workflow and reports an error', async () => {
  const h = harnessResult(resultFixture(), {auto: true, search: ''});
  await h.settle();
  assert.equal(h.calls.length, 0);
  assert.equal(h.manualControlsPresent(), false);
  assert.match(h.messageText(), /شناسه|پنل/);
});

test('invalid result attempt stays hidden and reports the RPC error', async () => {
  const h = harnessResult(resultFixture(), {rpc: async () => ({error: {message: 'RESULT_NOT_FOUND'}})});
  await h.load();
  assert.equal(h.summaryHidden(), true);
  assert.equal(h.detailHidden(), true);
  assert.match(h.messageText(), /RESULT_NOT_FOUND|پیدا/);
});

test('result page has a canonical dashboard return', () => {
  assert.match(resultHtml, /id="dashboard-link"[^>]*href="student-dashboard\.html"/);
  assert.match(resultHtml, /بازگشت به پنل دانش‌آموز/);
});
