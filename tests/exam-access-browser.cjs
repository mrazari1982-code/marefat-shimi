const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const html = fs.readFileSync(path.join(__dirname, '../public/exam-access.html'), 'utf8');

function inlineScript(source) {
  const scripts = [...source.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
  const body = scripts.map(match => match[1]).find(value => value.trim());
  assert.ok(body, 'exam access inline script is required');
  return body;
}

class Element {
  constructor() {
    this.textContent = '';
    this.className = '';
    this.hidden = false;
  }
}

async function harness({session = null, link = {exam_title: 'آزمون تست', exam_code: 'T-1', duration_minutes: 30}} = {}) {
  const elements = new Map([['examInfo', new Element()], ['msg', new Element()]]);
  let redirect = null;
  const context = vm.createContext({
    URLSearchParams,
    location: {
      search: '?token=' + encodeURIComponent('exam token'),
      replace(value) { redirect = value; }
    },
    document: {getElementById(id) { return elements.get(id) || null; }},
    MarefatStudentAuth: {
      getSession: () => session,
      safeReturn: value => value === 'student-dashboard.html?token=exam%20token'
        ? value
        : 'student-dashboard.html'
    },
    supabase: {createClient: () => ({rpc: async () => ({data: link, error: null})})}
  });
  vm.runInContext(inlineScript(html).replace(/init\(\)\.catch[\s\S]*$/, ''), context);
  await vm.runInContext('init()', context);
  return {redirect, elements};
}

test('exam access uses the shared student authentication layer and removes student-code-only entry', () => {
  assert.ok(html.indexOf('supabase-js@2') < html.indexOf('student-auth.js'));
  assert.doesNotMatch(html, /id="studentCode"|student_code=/);
});

test('valid exam link sends a guest through login while preserving one canonical token', async () => {
  const result = await harness();
  assert.equal(
    result.redirect,
    'student-login.html?return=' + encodeURIComponent('student-dashboard.html?token=exam%20token')
  );
});

test('valid exam link sends an authenticated student directly to the tokenized dashboard', async () => {
  const result = await harness({session: {token: 'student-session'}});
  assert.equal(result.redirect, 'student-dashboard.html?token=exam%20token');
});

test('invalid exam link remains on the public page with a clear error', async () => {
  const result = await harness({link: null});
  assert.equal(result.redirect, null);
  assert.match(result.elements.get('examInfo').textContent, /فعال یا معتبر نیست/);
});
