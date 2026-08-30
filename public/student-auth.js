(function (global) {
  'use strict';

  const STORAGE_KEY = 'marefat.student.session.v1';
  const TOKEN_PATTERN = /^[a-f0-9]{64}$/;
  const protectedPages = new Set(['student-dashboard.html', 'exam.html', 'student-result.html']);
  const SAFE_PARAM_LENGTH = 512;
  const rpcMap = {
    v5_dashboard: ['v5_student_dashboard', (args, token) => ({p_limit: Math.min(100, Math.max(0, Number(args.p_limit ?? 100))), p_session_token: token})],
    v5_resume_attempt: ['v5_student_resume_attempt', (args, token) => ({p_attempt_id: args.p_attempt_id, p_session_token: token})],
    v5_start_exam: ['v5_student_start_exam', (args, token) => ({p_exam_token: args.p_token, p_session_token: token})],
    v5_get_attempt_state: ['v5_student_get_attempt_state', (args, token) => ({p_attempt_id: args.p_attempt_id, p_session_token: token})],
    v5_get_exam_questions: ['v5_student_get_exam_questions', (args, token) => ({p_attempt_id: args.p_attempt_id, p_session_token: token})],
    v5_get_saved_answers: ['v5_student_get_saved_answers', (args, token) => ({p_attempt_id: args.p_attempt_id, p_session_token: token})],
    v5_save_answer: ['v5_student_save_answer', (args, token) => ({p_attempt_id: args.p_attempt_id, p_exam_question_id: args.p_exam_question_id, p_selected_option_id: args.p_selected_option_id, p_session_token: token})],
    v5_save_answers: ['v5_student_save_answers', (args, token) => ({p_attempt_id: args.p_attempt_id, p_answers: args.p_answers, p_session_token: token})],
    v5_submit_attempt: ['v5_student_submit_attempt', (args, token) => ({p_attempt_id: args.p_attempt_id, p_session_token: token})],
    v5_get_student_result: ['v5_student_get_result', (args, token) => ({p_attempt_id: args.p_attempt_id, p_session_token: token})]
  };
  let lastRawRpc = null;

  function clearSession() {
    global.sessionStorage.removeItem(STORAGE_KEY);
  }

  function getSession() {
    let session;
    try {
      session = JSON.parse(global.sessionStorage.getItem(STORAGE_KEY));
    } catch (_) {
      clearSession();
      return null;
    }
    const expiresAt = session && Date.parse(session.expires_at);
    if (!session || !TOKEN_PATTERN.test(session.token || '') || !Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
      clearSession();
      return null;
    }
    return session;
  }

  function currentPage() {
    return (global.location.pathname.split('/').pop() || '').toLowerCase();
  }

  function requireSession() {
    const session = getSession();
    if (!session && currentPage() !== 'student-login.html') {
      const page = currentPage() || 'index.html';
      const target = safeReturn(page + (global.location.search || ''));
      global.location.replace('student-login.html?return=' + encodeURIComponent(target));
    }
    return session;
  }

  async function login(username, password) {
    if (!lastRawRpc) throw new Error('سامانهٔ ورود هنوز آماده نشده است.');
    const response = await lastRawRpc('v5_student_login', {
      p_username: String(username || '').trim(),
      p_password: String(password || '')
    });
    const data = response && response.data;
    if (response.error || !data || !TOKEN_PATTERN.test(data.token || '')) {
      throw new Error('نام کاربری یا رمز عبور نادرست است.');
    }
    const session = {
      token: data.token,
      expires_at: data.expires_at,
      student_id: data.student_id,
      student_code: data.student_code,
      student_name: data.student_name
    };
    global.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));
    return session;
  }

  async function logout() {
    const session = getSession();
    try {
      if (session && lastRawRpc) await lastRawRpc('v5_student_logout', {p_session_token: session.token});
    } finally {
      clearSession();
    }
  }

  function hasUnsafeEncodedSeparator(value) {
    return /%(?:23|26|2f|3d|3f|5c)/i.test(String(value || ''));
  }

  function normalizeSafeParamValue(value) {
    const raw = String(value || '');
    if (!raw || raw.length > SAFE_PARAM_LENGTH || /[#&?=\/\\]/.test(raw) || hasUnsafeEncodedSeparator(raw)) return null;
    try {
      const decoded = decodeURIComponent(raw);
      if (!decoded || decoded.length > SAFE_PARAM_LENGTH || /[%#&?=\/\\]/.test(decoded)) return null;
      return encodeURIComponent(decoded);
    } catch (_) {
      return null;
    }
  }

  function parseQuery(query) {
    return String(query || '').split('&').filter(Boolean).map(part => {
      const index = part.indexOf('=');
      return {
        key: (index === -1 ? part : part.slice(0, index)).toLowerCase(),
        value: index === -1 ? '' : part.slice(index + 1)
      };
    });
  }

  function canonicalTarget(page, query) {
    const params = parseQuery(query);
    if (page === 'student-dashboard.html') {
      const tokenEntry = params.find(entry => entry.key === 'token');
      const token = normalizeSafeParamValue(tokenEntry && tokenEntry.value);
      return token ? page + '?token=' + token : page;
    }
    if (page === 'exam.html') {
      const attemptEntry = params.find(entry => entry.key === 'attempt');
      const tokenEntry = params.find(entry => entry.key === 'token');
      const attempt = normalizeSafeParamValue(attemptEntry && attemptEntry.value);
      if (attempt) return page + '?attempt=' + attempt;
      const token = normalizeSafeParamValue(tokenEntry && tokenEntry.value);
      return token ? page + '?token=' + token : 'student-dashboard.html';
    }
    if (page === 'student-result.html') {
      const attemptEntry = params.find(entry => entry.key === 'attempt');
      const attempt = normalizeSafeParamValue(attemptEntry && attemptEntry.value);
      return attempt ? page + '?attempt=' + attempt : 'student-dashboard.html';
    }
    return 'student-dashboard.html';
  }

  function safeReturn(value) {
    const candidate = String(value || '').trim();
    if (!candidate || candidate.includes('#') || candidate.startsWith('http://') || candidate.startsWith('https://') || candidate.startsWith('//')) {
      return 'student-dashboard.html';
    }
    const queryIndex = candidate.indexOf('?');
    const rawPage = queryIndex === -1 ? candidate : candidate.slice(0, queryIndex);
    const query = queryIndex === -1 ? '' : candidate.slice(queryIndex + 1);
    if (!rawPage || /[#\/\\]/.test(rawPage) || /%2f|%5c|%23/i.test(rawPage)) return 'student-dashboard.html';
    const page = rawPage.toLowerCase();
    if (!protectedPages.has(page)) return 'student-dashboard.html';
    return queryIndex === -1 ? page : canonicalTarget(page, query);
  }

  if (global.supabase && typeof global.supabase.createClient === 'function') {
    const originalCreateClient = global.supabase.createClient.bind(global.supabase);
    global.supabase.createClient = function () {
      const client = originalCreateClient.apply(null, arguments);
      const rawRpc = client.rpc.bind(client);
      lastRawRpc = rawRpc;
      client.rpc = function (name, args) {
        const mapping = rpcMap[name];
        if (!mapping) return rawRpc(name, args);
        const session = getSession();
        if (!session) {
          requireSession();
          return Promise.resolve({data: null, error: {message: 'UNAUTHORIZED'}});
        }
        return rawRpc(mapping[0], mapping[1](args || {}, session.token));
      };
      return client;
    };
  }

  global.MarefatStudentAuth = {login, logout, getSession, requireSession, safeReturn};
  if (protectedPages.has(currentPage())) requireSession();
})(globalThis);
