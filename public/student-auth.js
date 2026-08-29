(function (global) {
  'use strict';

  const STORAGE_KEY = 'marefat.student.session.v1';
  const TOKEN_PATTERN = /^[a-f0-9]{64}$/;
  const protectedPages = new Set(['', 'index.html', 'exam.html', 'student-result.html']);
  const rpcMap = {
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
      global.location.replace('student-login.html?return=' + encodeURIComponent(page + (global.location.search || '')));
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

  function safeReturn(value) {
    const candidate = String(value || '');
    return /^(index|exam|student-result)\.html(?:\?[^#]*)?$/.test(candidate) ? candidate : 'index.html';
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
