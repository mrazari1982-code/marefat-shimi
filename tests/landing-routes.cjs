const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');

const landingHtml = fs.readFileSync(path.join(__dirname, '../public/index.html'), 'utf8');
const loginHtml = fs.readFileSync(path.join(__dirname, '../public/student-login.html'), 'utf8');
const studentAuthSource = fs.readFileSync(path.join(__dirname, '../public/student-auth.js'), 'utf8');

function inlineScript(html) {
  const match = html.match(/<script>\s*([\s\S]*?)<\/script>/);
  assert.ok(match, 'inline page script is required');
  return match[1];
}

class Element {
  constructor(tag = 'div') {
    this.tagName = tag.toUpperCase();
    this.textContent = '';
    this.innerHTML = '';
    this.className = '';
    this.hidden = false;
    this.disabled = false;
    this.value = '';
    this.href = '';
    this.listeners = {};
  }
  addEventListener(name, handler) {
    this.listeners[name] = handler;
  }
  dispatch(name, event = {}) {
    return this.listeners[name]?.({preventDefault() {}, ...event});
  }
}

function landingHarness(options = {}) {
  const elements = new Map([
    ['student-entry', new Element('a')],
    ['student-dashboard-link', new Element('a')],
    ['staff-entry', new Element('a')],
    ['student-note', new Element('p')],
    ['staff-note', new Element('p')],
    ['page-status', new Element('p')]
  ]);
  let redirect = null;
  let staffChecks = 0;
  let requireCalls = 0;
  let source = inlineScript(landingHtml).replace(/\binit\(\);\s*$/, '');
  const url = new URL(options.url || 'https://example.test/index.html');
  const context = vm.createContext({
    window: null,
    document: {
      getElementById(id) { return elements.get(id) || null; }
    },
    location: {
      pathname: url.pathname,
      search: url.search,
      replace(value) { redirect = value; }
    },
    URLSearchParams,
    supabase: {
      createClient: () => ({
        auth: {
          getSession: async () => ({
            data: {
              session: options.staffSession ? {user: {email: 'staff@example.test'}} : null
            }
          })
        },
        rpc: async name => {
          staffChecks++;
          return name === 'v5_is_staff'
            ? {data: options.staffSession === true}
            : {data: null};
        }
      })
    },
    MarefatStudentAuth: {
      getSession: () => (options.studentSession ? {token: 'student'} : null),
      requireSession: () => { requireCalls++; return null; },
      safeReturn: value => String(value || '').startsWith('student-dashboard.html')
        ? String(value)
        : 'student-dashboard.html'
    }
  });
  context.window = context;
  vm.runInContext(source, context);
  return {
    context,
    elements,
    init: () => vm.runInContext('init()', context),
    redirect: () => redirect,
    requireCalls: () => requireCalls,
    staffChecks: () => staffChecks
  };
}

function loginHarness(options = {}) {
  const elements = new Map([
    ['form', new Element('form')],
    ['submit', new Element('button')],
    ['message', new Element('p')],
    ['username', new Element('input')],
    ['password', new Element('input')]
  ]);
  let redirect = null;
  const url = new URL(options.url || 'https://example.test/student-login.html');
  let saved = options.session ? JSON.stringify(options.session) : null;
  const calls = [];
  const raw = {
    rpc: async (name, args) => {
      calls.push([name, JSON.parse(JSON.stringify(args))]);
      if (name === 'v5_student_login') {
        return {data: {token: 'a'.repeat(64), expires_at: '2099-01-01T00:00:00Z', student_id: 1, student_code: 'S-1', student_name: 'Test Student'}};
      }
      return {data: {ok: true}};
    }
  };
  const context = vm.createContext({
    globalThis: null,
    document: {
      getElementById(id) { return elements.get(id) || null; }
    },
    sessionStorage: {
      getItem() { return saved; },
      setItem(_key, value) { saved = value; },
      removeItem() { saved = null; }
    },
    Date,
    location: {
      pathname: url.pathname,
      search: url.search,
      replace(value) { redirect = value; }
    },
    URLSearchParams,
    supabase: {createClient: () => raw}
  });
  context.globalThis = context;
  vm.runInContext(studentAuthSource, context);
  vm.runInContext(inlineScript(loginHtml), context);
  return {
    elements,
    calls,
    redirect: () => redirect,
    saved: () => saved
  };
}

function studentAuthHarness() {
  let saved = null;
  let redirect = null;
  const context = vm.createContext({
    globalThis: null,
    sessionStorage: {
      getItem() { return saved; },
      setItem(_key, value) { saved = value; },
      removeItem() { saved = null; }
    },
    Date,
    URLSearchParams,
    location: {pathname: '/index.html', search: '', replace(value) { redirect = value; }},
    document: {addEventListener() {}, getElementById() { return null; }},
    supabase: {createClient: () => ({rpc: async () => ({data: {}})})}
  });
  context.globalThis = context;
  vm.runInContext(studentAuthSource, context);
  return {api: context.MarefatStudentAuth, redirect: () => redirect};
}

test('landing page shows two visible primary choices and keeps the root public', async () => {
  assert.match(landingHtml, /ورود دانش‌آموز/);
  assert.match(landingHtml, /ورود مدیر \/ معاون/);
  assert.match(landingHtml, /id="student-entry"/);
  assert.match(landingHtml, /id="staff-entry"/);

  const h = landingHarness();
  await h.init();

  assert.equal(h.redirect(), null);
  assert.equal(h.requireCalls(), 0);
  assert.equal(h.elements.get('student-entry').href, 'student-login.html?return=student-dashboard.html');
  assert.equal(h.elements.get('student-dashboard-link').href, 'student-login.html?return=student-dashboard.html');
  assert.equal(h.elements.get('staff-entry').href, 'admin-login-v2.html');
  assert.equal(h.staffChecks(), 0);
});

test('landing helper routes student and checked staff sessions to canonical portals', async () => {
  const h = landingHarness({studentSession: true, staffSession: true});

  assert.equal(h.context.landingDestination({studentSession: true}), 'student-dashboard.html');
  assert.equal(h.context.landingDestination({staffSession: true}), 'admin-panel.html');

  await h.init();
  assert.equal(h.elements.get('student-entry').href, 'student-dashboard.html');
  assert.equal(h.elements.get('student-dashboard-link').href, 'student-dashboard.html');
  assert.equal(h.elements.get('staff-entry').href, 'admin-panel.html');
  assert.equal(h.staffChecks(), 1);
});

test('token helper preserves one encoded bounded token through login return or direct dashboard', () => {
  const h = landingHarness();

  assert.equal(
    h.context.studentTokenDestination('valid token', false),
    'student-login.html?return=' + encodeURIComponent('student-dashboard.html?token=valid%20token')
  );
  assert.equal(
    h.context.studentTokenDestination('valid token', true),
    'student-dashboard.html?token=valid%20token'
  );
  assert.equal(h.context.studentTokenDestination('', false), 'student-login.html?return=student-dashboard.html');
  assert.equal(h.context.studentTokenDestination('x'.repeat(513), false), 'student-login.html?return=student-dashboard.html');
});

test('all visible student links share the same token-preserving destination', async () => {
  const guest = landingHarness({url: 'https://example.test/index.html?token=valid%20token'});
  await guest.init();
  const guestExpected = 'student-login.html?return=' + encodeURIComponent('student-dashboard.html?token=valid%20token');
  assert.equal(guest.elements.get('student-entry').href, guestExpected);
  assert.equal(guest.elements.get('student-dashboard-link').href, guestExpected);

  const session = landingHarness({studentSession: true, url: 'https://example.test/index.html?token=valid%20token'});
  await session.init();
  assert.equal(session.elements.get('student-entry').href, 'student-dashboard.html?token=valid%20token');
  assert.equal(session.elements.get('student-dashboard-link').href, 'student-dashboard.html?token=valid%20token');
});

test('safeReturn still rejects arbitrary return URLs', () => {
  const h = studentAuthHarness();
  assert.equal(h.api.safeReturn('https://evil.example'), 'student-dashboard.html');
  assert.equal(h.api.safeReturn('//evil.example'), 'student-dashboard.html');
  assert.equal(h.api.safeReturn('admin-panel.html'), 'student-dashboard.html');
  assert.equal(h.redirect(), null);
});

test('student login redirects an existing session to the dashboard', () => {
  const h = loginHarness({session: {token: 'a'.repeat(64), expires_at: '2099-01-01T00:00:00Z'}});
  assert.equal(h.redirect(), 'student-dashboard.html');
});

test('student login form success without return defaults to the dashboard', async () => {
  const h = loginHarness();
  h.elements.get('username').value = 'student-1';
  h.elements.get('password').value = 'secret';
  await h.elements.get('form').dispatch('submit');
  assert.deepEqual(h.calls, [['v5_student_login', {p_username: 'student-1', p_password: 'secret'}]]);
  assert.equal(h.redirect(), 'student-dashboard.html');
  assert.match(h.saved() || '', /"token":"a{64}"/);
});

test('student login form preserves a tokenized return exactly once', async () => {
  const h = loginHarness({url: 'https://example.test/student-login.html?return=' + encodeURIComponent('student-dashboard.html?token=valid%20token')});
  h.elements.get('username').value = 'student-1';
  h.elements.get('password').value = 'secret';
  await h.elements.get('form').dispatch('submit');
  assert.equal(h.redirect(), 'student-dashboard.html?token=valid%20token');
});
