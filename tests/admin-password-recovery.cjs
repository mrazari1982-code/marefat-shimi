const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');

const publicDir = path.join(__dirname, '..', 'public');

function readPage(name) {
  const file = path.join(publicDir, name);
  assert.ok(fs.existsSync(file), `${name} must exist`);
  return fs.readFileSync(file, 'utf8');
}

function inlineScript(html) {
  const matches = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
  assert.equal(matches.length, 1, 'page must have one inline script');
  return matches[0][1];
}

class Element {
  constructor() {
    this.value = '';
    this.textContent = '';
    this.className = '';
    this.disabled = false;
    this.listeners = {};
  }
  addEventListener(name, handler) { this.listeners[name] = handler; }
  dispatch(name, event = {}) {
    return this.listeners[name]?.({preventDefault() {}, ...event});
  }
}

function recoveryHarness(options = {}) {
  const html = readPage('admin-password-recovery.html');
  const elements = new Map([
    ['form', new Element()],
    ['email', new Element()],
    ['submit', new Element()],
    ['message', new Element()]
  ]);
  const calls = [];
  const context = vm.createContext({
    window: null,
    document: {getElementById: id => elements.get(id) || null},
    location: {origin: 'https://example.test'},
    supabase: {createClient: () => ({auth: {
      resetPasswordForEmail: async (email, config) => {
        calls.push([email, JSON.parse(JSON.stringify(config))]);
        return options.error ? {error: new Error(options.error)} : {error: null};
      }
    }})}
  });
  context.window = context;
  vm.runInContext(inlineScript(html), context);
  return {elements, calls};
}

function updateHarness(options = {}) {
  const html = readPage('admin-password-update.html');
  const elements = new Map([
    ['form', new Element()],
    ['password', new Element()],
    ['confirmPassword', new Element()],
    ['submit', new Element()],
    ['message', new Element()]
  ]);
  const calls = [];
  const operations = [];
  const authHandlers = [];
  let redirect = null;
  let session = options.session ? {user: {id: 'admin'}} : null;
  const context = vm.createContext({
    window: null,
    document: {getElementById: id => elements.get(id) || null},
    location: {
      replace(value) { redirect = value; }
    },
    setTimeout: fn => { fn(); return 1; },
    supabase: {createClient: () => ({auth: {
      getSession: async () => ({data: {session}}),
      onAuthStateChange: handler => { authHandlers.push(handler); return {data: {subscription: {unsubscribe() {}}}}; },
      updateUser: async payload => {
        operations.push('updateUser');
        calls.push(JSON.parse(JSON.stringify(payload)));
        return options.error ? {error: new Error(options.error)} : {error: null};
      },
      signOut: async () => {
        operations.push('signOut');
        if(options.signOutError)return {error: new Error(options.signOutError)};
        session=null;
        return {error: null};
      }
    }})}
  });
  context.window = context;
  vm.runInContext(inlineScript(html), context);
  return {
    elements,calls,operations,authHandlers,redirect:()=>redirect,
    emitRecovery(){session={user:{id:'admin'}};authHandlers.forEach(handler=>handler('PASSWORD_RECOVERY',session));},
    emitSignedIn(){session={user:{id:'admin'}};authHandlers.forEach(handler=>handler('SIGNED_IN',session));}
  };
}

test('admin login offers a password recovery route', () => {
  assert.match(readPage('admin-login-v2.html'), /href="admin-password-recovery\.html"/);
});

test('recovery sends a one-time email to the production update page', async () => {
  const h = recoveryHarness();
  h.elements.get('email').value = ' Admin@Example.com ';
  await h.elements.get('form').dispatch('submit');
  assert.deepEqual(h.calls, [[
    'admin@example.com',
    {redirectTo: 'https://marefat-shimi.m-r-azari-1982.workers.dev/admin-password-update.html'}
  ]]);
  assert.match(h.elements.get('message').textContent, /ایمیل بازیابی ارسال شد/);
});

test('update page rejects a short password and a mismatched confirmation', async () => {
  const short = updateHarness();
  short.elements.get('password').value = '1234567';
  short.elements.get('confirmPassword').value = '1234567';
  await short.elements.get('form').dispatch('submit');
  assert.deepEqual(short.calls, []);
  assert.match(short.elements.get('message').textContent, /حداقل ۸ کاراکتر/);

  const mismatch = updateHarness();
  mismatch.elements.get('password').value = 'new-secure-password';
  mismatch.elements.get('confirmPassword').value = 'different-password';
  await mismatch.elements.get('form').dispatch('submit');
  assert.deepEqual(mismatch.calls, []);
  assert.match(mismatch.elements.get('message').textContent, /یکسان نیست/);
});

test('update page rejects an ordinary signed-in session without a recovery event', async () => {
  const h = updateHarness({session: true});
  h.emitSignedIn();
  h.elements.get('password').value = 'new-secure-password';
  h.elements.get('confirmPassword').value = 'new-secure-password';
  await h.elements.get('form').dispatch('submit');
  assert.deepEqual(h.calls, []);
  assert.equal(h.redirect(), null);
  assert.match(h.elements.get('message').textContent, /لینک بازیابی/);
});

test('recovery event permits update, sign-out, then return to login in order', async () => {
  const h = updateHarness();
  h.emitRecovery();
  h.elements.get('password').value = 'new-secure-password';
  h.elements.get('confirmPassword').value = 'new-secure-password';
  await h.elements.get('form').dispatch('submit');
  assert.deepEqual(h.calls, [{password: 'new-secure-password'}]);
  assert.deepEqual(h.operations, ['updateUser', 'signOut']);
  assert.equal(h.redirect(), 'admin-login-v2.html?password=updated');
});

test('failed sign-out leaves the user on the update page with a clear warning', async () => {
  const h = updateHarness({signOutError: 'network error'});
  h.emitRecovery();
  h.elements.get('password').value = 'new-secure-password';
  h.elements.get('confirmPassword').value = 'new-secure-password';
  await h.elements.get('form').dispatch('submit');
  assert.deepEqual(h.operations, ['updateUser', 'signOut']);
  assert.equal(h.redirect(), null);
  assert.match(h.elements.get('message').textContent, /رمز تغییر کرد.*خروج امن انجام نشد/);
});
