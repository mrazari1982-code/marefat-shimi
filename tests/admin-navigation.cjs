const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const ROOT = path.resolve(__dirname, '..');
const PUBLIC = path.join(ROOT, 'public');
const readPublic = (name) => fs.readFileSync(path.join(PUBLIC, name), 'utf8');

const requiredPanelRoutes = [
  'students.html',
  'admin-student-import.html',
  'admin-student-password.html',
  'admin-question-bank.html',
  'admin-exam-builder.html',
  'exam-questions-v3.html',
  'admin-exam-publish.html',
  'admin-exam-lifecycle.html',
  'admin-exam-links.html',
  'results.html',
  'admin-report.html',
  'admin-analytics.html',
  'admin-descriptive-grading.html',
];

const activeStaffPages = [
  'admin-analytics.html',
  'admin-descriptive-grading.html',
  'admin-exam-builder.html',
  'admin-exam-lifecycle.html',
  'admin-exam-links.html',
  'admin-exam-publish.html',
  'admin-question-bank.html',
  'admin-report.html',
  'admin-student-import.html',
  'admin-student-password.html',
  'students.html',
  'results.html',
  'analytics.html',
  'exam-builder.html',
  'exam-questions-v3.html',
  'exam-questions.html',
];

test('canonical panel reaches every current staff capability in grouped menus', () => {
  const panel = readPublic('admin-panel.html');
  const panelNavigation = panel + readPublic('admin-nav.js');
  const missing = requiredPanelRoutes.filter((route) => {
    const escaped = route.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return !new RegExp(`(?:href=["']|["'])${escaped}["']`).test(panelNavigation);
  });
  assert.deepEqual(missing, [], `missing canonical panel routes: ${missing.join(', ')}`);

  for (const heading of ['دانش‌آموزان', 'بانک سؤال', 'آزمون‌ها', 'گزارش‌ها']) {
    assert.match(panel, new RegExp(`<h[2-6][^>]*>\\s*${heading}\\s*</h[2-6]>`));
  }

  // The navigation rewrite must not replace the panel's data views.
  for (const id of ['examCount', 'questionCount', 'attemptCount', 'avgScore', 'results', 'exams']) {
    assert.match(panel, new RegExp(`id=["']${id}["']`));
  }
  assert.match(panel, /v5_is_staff/);
});

test('every active staff page has a canonical back route and no admin.html route', () => {
  const missingCanonicalNavigation = [];
  const staleAdminRoutes = [];

  for (const page of activeStaffPages) {
    const html = readPublic(page);
    const loadsSharedNav = /<script\b[^>]*\bsrc=["']admin-nav\.js["'][^>]*>/i.test(html);
    const linksPanel = /href=["']admin-panel\.html["']/i.test(html);
    if (!loadsSharedNav && !linksPanel) missingCanonicalNavigation.push(page);
    if (/(?:href|location(?:\.href)?)\s*=\s*["']admin\.html["']/i.test(html)) {
      staleAdminRoutes.push(page);
    }
  }

  assert.deepEqual(
    missingCanonicalNavigation,
    [],
    `pages without canonical navigation: ${missingCanonicalNavigation.join(', ')}`,
  );
  assert.deepEqual(staleAdminRoutes, [], `pages still routing to admin.html: ${staleAdminRoutes.join(', ')}`);
});

test('active pages with their own authorization route denied sessions to staff login', () => {
  const authorizationPages = activeStaffPages.filter((page) => page !== 'admin-report.html');
  const missingLoginRoute = authorizationPages.filter(
    (page) => {
      const html = readPublic(page);
      const scripts = [...html.matchAll(/<script\b[^>]*\bsrc=["']([^"']+\.js)["'][^>]*>/gi)]
        .map((match) => fs.existsSync(path.join(PUBLIC, match[1])) ? readPublic(match[1]) : '')
        .join('\n');
      return !/admin-login-v2\.html/.test(html + scripts);
    },
  );
  assert.deepEqual(
    missingLoginRoute,
    [],
    `pages without the canonical staff login route: ${missingLoginRoute.join(', ')}`,
  );
});

test('shared admin navigation only renders presentation and handles logout', async () => {
  const navNodes = [{ children: [], replaceChildren(...nodes) { this.children = nodes; } }, { children: [], replaceChildren(...nodes) { this.children = nodes; } }];
  const logoutHandlers = [];
  const logoutNodes = [
    { addEventListener(type, handler) { logoutHandlers.push([type, handler]); } },
  ];
  const location = { href: 'feature.html' };
  let signOutCalls = 0;
  const client = {
    auth: {
      async signOut() { signOutCalls += 1; },
    },
  };
  const context = {
    document: {
      createElement(tagName) {
        return { tagName, className: '', href: '', textContent: '' };
      },
      querySelectorAll(selector) {
        if (selector === '[data-admin-nav]') return navNodes;
        if (selector === '[data-admin-logout]') return logoutNodes;
        return [];
      },
    },
    location,
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(readPublic('admin-nav.js'), context, { filename: 'admin-nav.js' });

  assert.equal(typeof context.MarefatAdminNav?.mount, 'function');
  context.MarefatAdminNav.mount({ client, backTarget: 'admin-panel.html' });
  for (const node of navNodes) {
    assert.equal(node.children.length, 1);
    assert.equal(node.children[0].tagName, 'a');
    assert.equal(node.children[0].href, 'admin-panel.html');
    assert.equal(node.children[0].textContent, 'پنل اصلی');
  }
  assert.equal(logoutHandlers.length, 1);
  assert.equal(logoutHandlers[0][0], 'click');

  await logoutHandlers[0][1]({ preventDefault() {} });
  assert.equal(signOutCalls, 1);
  assert.equal(location.href, 'admin-login-v2.html');
});

test('shared navigation rejects an unsafe back target without using an HTML sink', () => {
  const navNode = { children: [], replaceChildren(...nodes) { this.children = nodes; } };
  const context = {
    document: {
      createElement(tagName) { return { tagName, className: '', href: '', textContent: '' }; },
      querySelectorAll(selector) { return selector === '[data-admin-nav]' ? [navNode] : []; },
    },
    location: { href: '' },
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(readPublic('admin-nav.js'), context, { filename: 'admin-nav.js' });
  context.MarefatAdminNav.mount({ backTarget: 'javascript:alert(1)' });
  assert.equal(navNode.children[0].href, 'admin-panel.html');
  assert.equal(navNode.children[0].textContent, 'پنل اصلی');
});

test('password management lets valid staff load and blocks a denied save RPC', async () => {
  const elements = new Map();
  const element = (id) => {
    if (!elements.has(id)) elements.set(id, {
      id, value: '', textContent: '', className: '', disabled: false, innerHTML: '',
      listeners: {}, options: [],
      addEventListener(type, handler) { this.listeners[type] = handler; },
      replaceChildren(...nodes) { this.options = nodes; },
      add(node) { this.options.push(node); },
    });
    return elements.get(id);
  };
  const rpcCalls = [];
  let allowed = true;
  const sb = {
    auth: {
      async getUser() { return allowed ? { data: { user: { id: 'staff-1' } }, error: null } : { data: { user: null }, error: null }; },
      async signOut() {},
    },
    from() { return { select() { return this; }, eq() { return this; }, async maybeSingle() { return { data: { role: 'admin', is_active: true }, error: null }; } }; },
    async rpc(name) { rpcCalls.push(name); return { data: name === 'v5_admin_list_students' ? [] : null, error: null }; },
  };
  const context = {
    supabase: { createClient() { return sb; } },
    document: { getElementById: element },
    location: { href: '' },
    Option: function Option(text, value) { this.text = text; this.value = value; },
    TextEncoder,
  };
  context.window = context;
  vm.createContext(context);
  const script = [...readPublic('admin-student-password.html').matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].at(-1)[1];
  vm.runInContext(script, context, { filename: 'admin-student-password.html' });
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(rpcCalls, ['v5_admin_list_students']);

  allowed = false;
  element('student').value = '42';
  element('password').value = 'password-123';
  element('confirm').value = 'password-123';
  await element('save').listeners.click();
  assert.deepEqual(rpcCalls, ['v5_admin_list_students']);
  assert.equal(context.location.href, 'admin-login-v2.html');
});

test('results logout signs out and routes to the canonical staff login', async () => {
  const elements = new Map();
  const element = (id) => {
    if (!elements.has(id)) elements.set(id, { id, value: '', textContent: '', className: '', disabled: false, onclick: null, onchange: null, classList: { add() {}, remove() {} }, querySelector() { return { innerHTML: '' }; } });
    return elements.get(id);
  };
  let signOutCalls = 0;
  const sb = { auth: { async signOut() { signOutCalls += 1; }, getSession() { return new Promise(() => {}); } } };
  const context = {
    supabase: { createClient() { return sb; } }, document: { getElementById: element },
    location: { href: 'results.html' }, Map, Date, Promise, encodeURIComponent,
  };
  context.window = context;
  vm.createContext(context);
  const script = [...readPublic('results.html').matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].at(-1)[1];
  vm.runInContext(script, context, { filename: 'results.html' });
  await element('logoutBtn').onclick();
  assert.equal(signOutCalls, 1);
  assert.equal(context.location.href, 'admin-login-v2.html');
});

test('report route sends a missing staff session to login before reading report data', async () => {
  const elements = new Map();
  const element = (id) => {
    if (!elements.has(id)) elements.set(id, { id, textContent: '', className: '', onclick: null, classList: { add() {}, remove() {} } });
    return elements.get(id);
  };
  const sb = { auth: { getSession: async () => ({ data: { session: null } }), async signOut() {} } };
  const context = {
    supabase: { createClient() { return sb; } }, document: { getElementById: element },
    location: { href: 'report.html', search: '?attempt_id=attempt-1' }, URLSearchParams, Map, Date, Promise,
  };
  context.window = context;
  vm.createContext(context);
  const script = [...readPublic('report.html').matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].at(-1)[1];
  vm.runInContext(script, context, { filename: 'report.html' });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(context.location.href, 'admin-login-v2.html');
});

test('legacy report wrapper authenticates before preserving and forwarding the attempt id', async () => {
  const replacements = [];
  const sb = { auth: { async getUser() { return { data: { user: null }, error: null }; } } };
  const context = {
    supabase: { createClient() { return sb; } },
    document: { getElementById() { return { className: '', textContent: '' }; } },
    location: {
      search: '?attempt=%3Cunsafe%3E',
      replace(target) { replacements.push(target); },
    },
    URLSearchParams, encodeURIComponent,
  };
  context.window = context;
  vm.createContext(context);
  const script = [...readPublic('admin-report.html').matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].at(-1)[1];
  vm.runInContext(script, context, { filename: 'admin-report.html' });
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(replacements, ['admin-login-v2.html']);
});

test('admin.html is a minimal session-preserving compatibility redirect', () => {
  const compat = readPublic('admin.html');
  assert.match(compat, /location\.replace\(["']admin-panel\.html["']\)/);
  assert.doesNotMatch(compat, /signOut|localStorage|sessionStorage|removeItem|clear\s*\(|location\.search|URLSearchParams/);
});

test('every canonical destination is present in the deployed public tree', () => {
  for (const route of requiredPanelRoutes) {
    assert.equal(fs.existsSync(path.join(PUBLIC, route)), true, route);
  }
});
