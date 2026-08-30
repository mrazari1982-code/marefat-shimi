(function (global) {
  'use strict';

  const $ = id => global.document.getElementById(id);
  const sb = global.supabase.createClient('https://rbqlblryxcaodvyrnfuo.supabase.co', 'sb_publishable_iJkwgMHRaBQjFhk_0QSU1w_aSKWG1mU');
  let lastPayload = null;

  function element(tag, text) {
    const node = global.document.createElement(tag);
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }
  function appendLine(parent, label, value) {
    const row = element('p');
    const title = element('strong', label + ': ');
    row.append(title, element('span', value === null || value === undefined || value === '' ? '—' : String(value)));
    parent.append(row);
  }
  function number(value) { return Number(value || 0).toLocaleString('fa-IR'); }
  function percentage(value) { return Number(value || 0).toLocaleString('fa-IR', {maximumFractionDigits: 2}) + '٪'; }
  function date(value) { if (!value) return '—'; const d = new Date(value); return Number.isNaN(d.valueOf()) ? '—' : d.toLocaleString('fa-IR'); }
  function setMessage(text, kind) { const node = $('dashboard-message'); node.className = 'status ' + (kind || 'muted'); node.textContent = text; }
  function navigate(path) { global.location.href = path; }

  function friendlyError(message) {
    const value = String(message || '');
    if (value.includes('UNAUTHORIZED')) return 'نشست شما منقضی شده است. لطفاً دوباره وارد شوید.';
    if (value.includes('INVALID_EXAM_LINK')) return 'لینک آزمون معتبر نیست یا منقضی شده است.';
    if (value.includes('EXAM_NOT_PUBLISHED')) return 'این آزمون هنوز منتشر نشده است.';
    if (value.includes('EXAM_NOT_STARTED')) return 'زمان شروع آزمون هنوز فرا نرسیده است.';
    if (value.includes('EXAM_CLOSED')) return 'زمان این آزمون به پایان رسیده است.';
    if (value.includes('MAX_ATTEMPTS_REACHED')) return 'سقف مجاز شرکت در این آزمون تکمیل شده است.';
    if (value.includes('ATTEMPT_SUBMITTED')) return 'این آزمون قبلاً ثبت شده است.';
    if (value.includes('ATTEMPT_EXPIRED') || value.includes('deadline_passed')) return 'مهلت ادامه این آزمون به پایان رسیده است.';
    if (value.includes('exam_closed')) return 'این آزمون دیگر برای ادامه فعال نیست.';
    return value || 'خطای نامشخص در سامانه.';
  }

  function renderProfile(profile) {
    const target = $('profile'); target.replaceChildren();
    const value = profile || {};
    appendLine(target, 'نام', value.full_name);
    appendLine(target, 'کد دانش‌آموزی', value.student_code);
    appendLine(target, 'پایه', value.grade_name);
    appendLine(target, 'رشته', value.field_name);
    appendLine(target, 'کلاس', value.class_name);
  }

  function renderSummary(summary) {
    const target = $('summary'); target.replaceChildren();
    const value = summary || {};
    appendLine(target, 'کل تلاش‌ها', number(value.attempt_count));
    appendLine(target, 'ثبت‌شده', number(value.submitted_count));
    appendLine(target, 'در حال انجام', number(value.in_progress_count));
    appendLine(target, 'نتایج منتشرشده', number(value.visible_result_count));
    appendLine(target, 'میانگین نتایج منتشرشده', value.average_percentage === null || value.average_percentage === undefined ? '—' : percentage(value.average_percentage));
    appendLine(target, 'صحیح', number(value.correct_count));
    appendLine(target, 'غلط', number(value.wrong_count));
    appendLine(target, 'بی‌پاسخ', number(value.blank_count));
  }

  async function resumeAttempt(attempt) {
    const result = await sb.rpc('v5_resume_attempt', {p_attempt_id: attempt.attempt_id});
    if (result.error) {
      const message = String(result.error.message || '');
      if (['ATTEMPT_SUBMITTED', 'ATTEMPT_EXPIRED', 'EXAM_CLOSED'].some(code => message.includes(code))) {
        const reason = friendlyError(message);
        await loadDashboard();
        setMessage(reason, 'err');
        return;
      }
      throw result.error;
    }
    const data = Array.isArray(result.data) ? result.data[0] : result.data;
    if (data && data.available) { navigate('exam.html?attempt=' + encodeURIComponent(attempt.attempt_id)); return; }
    const reason = friendlyError(data && data.reason);
    await loadDashboard();
    setMessage(reason, 'err');
  }

  function renderAttempts(attempts) {
    const target = $('history'); target.replaceChildren();
    const rows = Array.isArray(attempts) ? attempts : [];
    if (!rows.length) { target.append(element('p', 'هنوز سابقه‌ای از آزمون‌ها ندارید.')); return; }
    rows.forEach(attempt => {
      const card = element('article'); card.className = 'attempt';
      card.append(element('h3', attempt.exam_title || 'آزمون'));
      appendLine(card, 'وضعیت', attempt.status === 'started' ? 'در حال انجام' : attempt.status === 'submitted' ? 'ثبت‌شده' : attempt.status === 'expired' ? 'منقضی شده' : attempt.status || '—');
      appendLine(card, 'تاریخ', date(attempt.submitted_at || attempt.started_at));
      if (attempt.result_visible === true) {
        appendLine(card, 'درصد', percentage(attempt.percentage));
        appendLine(card, 'صحیح', number(attempt.correct_count));
        appendLine(card, 'غلط', number(attempt.wrong_count));
        appendLine(card, 'بی‌پاسخ', number(attempt.blank_count));
      } else if (attempt.status === 'submitted') card.append(element('p', 'در انتظار انتشار نتیجه'));
      const actions = element('div'); actions.className = 'actions';
      if (attempt.can_resume) { const resume = element('button', 'ادامه آزمون'); resume.type = 'button'; resume.className = 'btn'; resume.dataset.resume = String(attempt.attempt_id); resume.addEventListener('click', () => resumeAttempt(attempt).catch(handleError)); actions.append(resume); }
      if (attempt.status === 'submitted' && attempt.result_visible === true) { const result = element('button', 'مشاهده نتیجه'); result.type = 'button'; result.className = 'btn secondary'; result.dataset.result = String(attempt.attempt_id); result.addEventListener('click', () => navigate('student-result.html?attempt=' + encodeURIComponent(attempt.attempt_id))); actions.append(result); }
      if (actions.children.length) card.append(actions);
      target.append(card);
    });
  }

  function renderTrend(attempts) {
    const target = $('trend');
    const visible = (Array.isArray(attempts) ? attempts : []).filter(attempt => attempt.result_visible === true && Number.isFinite(Number(attempt.percentage))).sort((a, b) => new Date(a.submitted_at || a.started_at).valueOf() - new Date(b.submitted_at || b.started_at).valueOf());
    target.replaceChildren();
    if (visible.length < 2) { target.hidden = true; return; }
    target.hidden = false;
    target.append(element('h2', 'روند نتایج منتشرشده'));
    const list = element('ol'); list.className = 'trend-list';
    visible.forEach(attempt => list.append(element('li', (attempt.exam_title || 'آزمون') + ' — ' + percentage(attempt.percentage))));
    target.append(list);
  }

  function renderDashboard(payload) {
    lastPayload = payload || {};
    renderProfile(lastPayload.profile);
    renderSummary(lastPayload.summary);
    renderAttempts(lastPayload.attempts);
    renderTrend(lastPayload.attempts);
  }

  async function clearUnauthorized() {
    try { await global.MarefatStudentAuth.logout(); } catch (_) { /* redirect is still required */ }
    global.location.replace('student-login.html');
  }
  async function handleError(error) {
    const message = error && error.message ? error.message : error;
    if (String(message || '').includes('UNAUTHORIZED')) { await clearUnauthorized(); return; }
    setMessage(friendlyError(message), 'err');
    $('retry').hidden = false;
  }
  async function loadDashboard() {
    $('retry').hidden = true;
    setMessage('در حال دریافت اطلاعات…', 'muted');
    try {
      if (!global.MarefatStudentAuth.requireSession()) return;
      const result = await sb.rpc('v5_dashboard', {p_limit: 100});
      if (result.error) throw result.error;
      renderDashboard(Array.isArray(result.data) ? result.data[0] : result.data);
      setMessage('اطلاعات شما به‌روز است.', 'ok');
    } catch (error) { await handleError(error); }
  }
  async function startExam(token) {
    const value = String(token || '').trim();
    if (!value) { setMessage('توکن لینک آزمون را وارد کنید.', 'err'); return; }
    const button = $('start-exam'); button.disabled = true; setMessage('در حال شروع آزمون…', 'muted');
    try {
      const result = await sb.rpc('v5_start_exam', {p_token: value});
      if (result.error) throw result.error;
      const attempt = Array.isArray(result.data) ? result.data[0] : result.data;
      if (!attempt || !attempt.attempt_id) throw new Error('شروع آزمون انجام نشد.');
      navigate('exam.html?attempt=' + encodeURIComponent(attempt.attempt_id));
    } catch (error) { await handleError(error); } finally { button.disabled = false; }
  }
  function init() {
    const token = new URLSearchParams(global.location.search || '').get('token');
    if (token) $('exam-token').value = token;
    $('token-form').addEventListener('submit', event => { event.preventDefault(); return startExam($('exam-token').value); });
    $('retry').addEventListener('click', loadDashboard);
    $('logout').addEventListener('click', async () => { try { await global.MarefatStudentAuth.logout(); } catch (_) { /* local logout cleanup still redirects */ } finally { global.location.replace('student-login.html'); } });
    return loadDashboard();
  }

  global.StudentDashboard = {renderDashboard, renderProfile, renderSummary, renderAttempts, renderTrend, friendlyError, loadDashboard, startExam};
  global.initDashboard = init;
  global.renderDashboard = renderDashboard; global.renderProfile = renderProfile; global.renderSummary = renderSummary; global.renderAttempts = renderAttempts; global.renderTrend = renderTrend; global.friendlyError = friendlyError; global.loadDashboard = loadDashboard; global.startExam = startExam;
  if (!global.__STUDENT_DASHBOARD_TEST__) init();
})(globalThis);
